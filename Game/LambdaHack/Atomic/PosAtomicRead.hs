-- | Semantics of atomic commands shared by client and server.
-- See
-- <https://github.com/LambdaHack/LambdaHack/wiki/Client-server-architecture>.
module Game.LambdaHack.Atomic.PosAtomicRead
  ( PosAtomic(..), posUpdAtomic, posSfxAtomic
  , breakUpdAtomic, loudUpdAtomic
  , seenAtomicCli, seenAtomicSer, generalMoveItem, posProjBody
  ) where

import Prelude ()

import Game.LambdaHack.Common.Prelude

import qualified Data.EnumMap.Strict as EM
import qualified Data.EnumSet as ES
import qualified NLP.Miniutter.English as MU

import Game.LambdaHack.Atomic.CmdAtomic
import Game.LambdaHack.Common.Actor
import Game.LambdaHack.Common.ActorState
import Game.LambdaHack.Common.Faction
import Game.LambdaHack.Common.Item
import qualified Game.LambdaHack.Common.Kind as Kind
import Game.LambdaHack.Common.Level
import Game.LambdaHack.Common.Misc
import Game.LambdaHack.Common.MonadStateRead
import Game.LambdaHack.Common.Perception
import Game.LambdaHack.Common.Point
import Game.LambdaHack.Common.State
import qualified Game.LambdaHack.Common.Tile as Tile

-- All functions here that take an atomic action are executed
-- in the state just before the action is executed.

-- | The type representing visibility of atomic commands to factions,
-- based on the position of the command, etc. Note that the server
-- sees and smells all positions.
data PosAtomic =
    PosSight !LevelId ![Point]  -- ^ whomever sees all the positions, notices
  | PosFidAndSight ![FactionId] !LevelId ![Point]
                                -- ^ observers and the faction notice
  | PosSmell !LevelId ![Point]  -- ^ whomever smells all the positions, notices
  | PosFid !FactionId           -- ^ only the faction notices
  | PosFidAndSer !(Maybe LevelId) !FactionId  -- ^ faction and server notices
  | PosSer                      -- ^ only the server notices
  | PosAll                      -- ^ everybody notices
  | PosNone                     -- ^ never broadcasted, but sent manually
  deriving (Show, Eq)

-- | Produce the positions where the atomic update takes place.
--
-- The goal of the mechanics is to ensure the commands don't carry
-- significantly more information than their corresponding state diffs would.
-- In other words, the atomic commands involving the positions seen by a client
-- should convey similar information as the client would get by directly
-- observing the changes the commands enact on the visible portion of server
-- game state. The client is then free to change its copy of game state
-- accordingly or not --- it only partially reflects reality anyway.
--
-- E.g., @UpdDisplaceActor@ in a black room,
-- with one actor carrying a 0-radius light would not be
-- distinguishable by looking at the state (or the screen) from @UpdMoveActor@
-- of the illuminated actor, hence such @UpdDisplaceActor@ should not be
-- observable, but @UpdMoveActor@ should be (or the former should be perceived
-- as the latter). However, to simplify, we assign as strict visibility
-- requirements to @UpdMoveActor@ as to @UpdDisplaceActor@ and fall back
-- to @UpdSpotActor@ (which provides minimal information that does not
-- contradict state) if the visibility is lower.
posUpdAtomic :: MonadStateRead m => UpdAtomic -> m PosAtomic
{-# INLINABLE posUpdAtomic #-}
posUpdAtomic cmd = case cmd of
  UpdCreateActor _ body _ -> return $! posProjBody body
  UpdDestroyActor _ body _ -> return $! posProjBody body
  UpdCreateItem _ _ _ c -> singleContainer c
  UpdDestroyItem _ _ _ c -> singleContainer c
  UpdSpotActor _ body _ -> return $! posProjBody body
  UpdLoseActor _ body _ -> return $! posProjBody body
  UpdSpotItem _ _ _ c -> singleContainer c
  UpdLoseItem _ _ _ c -> singleContainer c
  UpdMoveActor aid fromP toP -> do
    b <- getsState $ getActorBody aid
    -- Non-projectile actors are never totally isolated from envirnoment;
    -- they hear, feel air movement, etc.
    return $! if bproj b
              then PosSight (blid b) [fromP, toP]
              else PosFidAndSight [bfid b] (blid b) [fromP, toP]
  UpdWaitActor aid _ -> singleAid aid
  UpdDisplaceActor source target -> doubleAid source target
  UpdMoveItem _ _ _ _ CSha -> assert `failure` cmd  -- shared stash is private
  UpdMoveItem _ _ _ CSha _ ->  assert `failure` cmd
  UpdMoveItem _ _ aid _ _ -> singleAid aid
  UpdRefillHP aid _ -> singleAid aid
  UpdRefillCalm aid _ -> singleAid aid
  UpdFidImpressedActor aid _ _ -> singleAid aid
  UpdTrajectory aid _ _ -> singleAid aid
  UpdColorActor aid _ _ -> singleAid aid
  UpdQuitFaction{} -> return PosAll
  UpdLeadFaction fid _ _ -> return $ PosFidAndSer Nothing fid
  UpdDiplFaction{} -> return PosAll
  UpdTacticFaction fid _ _ -> return $! PosFidAndSer Nothing fid
  UpdAutoFaction{} -> return PosAll
  UpdRecordKill aid _ _ -> singleAid aid
  UpdAlterTile lid p _ _ -> return $! PosSight lid [p]
  UpdAlterClear{} -> return PosAll
  UpdSearchTile aid p _ _ -> do
    b <- getsState $ getActorBody aid
    return $! PosFidAndSight [bfid b] (blid b) [bpos b, p]
  UpdLearnSecrets aid _ _ -> singleAid aid
  UpdSpotTile lid ts -> do
    let ps = map fst ts
    return $! PosSight lid ps
  UpdLoseTile lid ts -> do
    let ps = map fst ts
    return $! PosSight lid ps
  UpdAlterSmell lid p _ _ -> return $! PosSmell lid [p]
  UpdSpotSmell lid sms -> do
    let ps = map fst sms
    return $! PosSmell lid ps
  UpdLoseSmell lid sms -> do
    let ps = map fst sms
    return $! PosSmell lid ps
  UpdTimeItem _ c _ _ -> singleContainer c
  UpdAgeGame _ -> return PosAll
  UpdUnAgeGame _ -> return PosAll
  UpdDiscover c _ _ _ _ -> singleContainer c
  UpdCover c _ _ _ _ -> singleContainer c
  UpdDiscoverKind c _ _ -> singleContainer c
  UpdCoverKind c _ _ -> singleContainer c
  UpdDiscoverSeed c _ _ _ -> singleContainer c
  UpdCoverSeed c _ _ _ -> singleContainer c
  UpdPerception{} -> return PosNone
  UpdRestart _ _ _ _ _ _ -> return PosNone
  UpdRestartServer _ -> return PosSer
  UpdResume _ _ -> return PosNone
  UpdResumeServer _ -> return PosSer
  UpdKillExit fid -> return $! PosFid fid
  UpdWriteSave -> return PosAll
  UpdMsgAll{} -> return PosAll
  UpdRecordHistory fid -> return $! PosFid fid

-- | Produce the positions where the atomic special effect takes place.
posSfxAtomic :: MonadStateRead m => SfxAtomic -> m PosAtomic
{-# INLINABLE posSfxAtomic #-}
posSfxAtomic cmd = case cmd of
  SfxStrike _ _ _ CSha _ ->  -- shared stash is private
    return PosNone  -- TODO: PosSerAndFidIfSight; but probably never used
  SfxStrike _ target _ _ _ -> singleAid target
  SfxRecoil _ _ _ CSha _ ->  -- shared stash is private
    return PosNone  -- TODO: PosSerAndFidIfSight; but probably never used
  SfxRecoil _ target _ _ _ -> singleAid target
  SfxProject aid _ cstore -> singleContainer $ CActor aid cstore
  SfxCatch aid _ cstore -> singleContainer $ CActor aid cstore
  SfxApply aid _ cstore -> singleContainer $ CActor aid cstore
  SfxCheck aid _ cstore -> singleContainer $ CActor aid cstore
  SfxTrigger aid p _ -> do
    body <- getsState $ getActorBody aid
    if bproj body
    then return $! PosSight (blid body) [bpos body, p]
    else return $! PosFidAndSight [bfid body] (blid body) [bpos body, p]
  SfxShun aid p _ -> do
    body <- getsState $ getActorBody aid
    if bproj body
    then return $! PosSight (blid body) [bpos body, p]
    else return $! PosFidAndSight [bfid body] (blid body) [bpos body, p]
  SfxEffect _ aid _ _ -> singleAid aid  -- sometimes we don't see source, OK
  SfxMsgFid fid _ -> return $! PosFid fid
  SfxMsgAll _ -> return PosAll

posProjBody :: Actor -> PosAtomic
posProjBody body =
  if bproj body
  then PosSight (blid body) [bpos body]
  else PosFidAndSight [bfid body] (blid body) [bpos body]

singleAid :: MonadStateRead m => ActorId -> m PosAtomic
{-# INLINABLE singleAid #-}
singleAid aid = do
  body <- getsState $ getActorBody aid
  return $! posProjBody body

doubleAid :: MonadStateRead m => ActorId -> ActorId -> m PosAtomic
{-# INLINABLE doubleAid #-}
doubleAid source target = do
  sb <- getsState $ getActorBody source
  tb <- getsState $ getActorBody target
  -- No @PosFidAndSight@ instead of @PosSight@, because both positions
  -- need to be seen to have the enemy actor in client's state.
  return $! assert (blid sb == blid tb) $ PosSight (blid sb) [bpos sb, bpos tb]

singleContainer :: MonadStateRead m => Container -> m PosAtomic
{-# INLINABLE singleContainer #-}
singleContainer (CFloor lid p) = return $! PosSight lid [p]
singleContainer (CEmbed lid p) = return $! PosSight lid [p]
singleContainer (CActor aid CSha) = do  -- shared stash is private
  b <- getsState $ getActorBody aid
  return $! PosFidAndSer (Just $ blid b) (bfid b)
singleContainer (CActor aid _) = singleAid aid
singleContainer (CTrunk fid lid p) =
  return $! PosFidAndSight [fid] lid [p]

-- | Decompose an atomic action. The decomposed actions give reduced
-- information that still modifies client's state to match the server state
-- wrt the current FOV and the subset of @posUpdAtomic@ that is visible.
-- The original actions give more information not only due to spanning
-- potentially more positions than those visible. E.g., @UpdMoveActor@
-- informs about the continued existence of the actor between
-- moves, v.s., popping out of existence and then back in.
breakUpdAtomic :: MonadStateRead m => UpdAtomic -> m [UpdAtomic]
{-# INLINABLE breakUpdAtomic #-}
breakUpdAtomic cmd = case cmd of
  UpdMoveActor aid _ toP -> do
    -- We assume other factions don't see leaders and we know the actor's
    -- faction always sees the atomic command, so the leader doesn't
    -- need to be updated (or the actor is a projectile, hence not a leader).
    b <- getsState $ getActorBody aid
    ais <- getsState $ getCarriedAssocs b
    return [ UpdLoseActor aid b ais
           , UpdSpotActor aid b {bpos = toP, boldpos = Just $ bpos b} ais ]
  UpdDisplaceActor source target -> do
    sb <- getsState $ getActorBody source
    sais <- getsState $ getCarriedAssocs sb
    tb <- getsState $ getActorBody target
    tais <- getsState $ getCarriedAssocs tb
    return [ UpdLoseActor source sb sais
           , UpdSpotActor source sb { bpos = bpos tb
                                    , boldpos = Just $ bpos sb } sais
           , UpdLoseActor target tb tais
           , UpdSpotActor target tb { bpos = bpos sb
                                    , boldpos = Just $ bpos tb } tais
           ]
  _ -> return []

-- | Messages for some unseen game object creation/destruction/alteration.
loudUpdAtomic :: MonadStateRead m
              => Bool -> FactionId -> UpdAtomic -> m (Maybe Text)
{-# INLINABLE loudUpdAtomic #-}
loudUpdAtomic local fid cmd = do
  msound <- case cmd of
    UpdDestroyActor _ body _
      -- Death of a party member does not need to be heard,
      -- because it's seen.
      | not $ fid == bfid body || bproj body -> return $ Just "shriek"
    UpdCreateItem _ _ _ (CActor _ CGround) -> return $ Just "clatter"
    UpdAlterTile _ _ fromTile _ -> do
      Kind.COps{coTileSpeedup} <- getsState scops
      if Tile.isDoor coTileSpeedup fromTile
        then return $ Just "creaking sound"
        else return $ Just "rumble"
    _ -> return Nothing
  let distant = if local then [] else ["distant"]
      hear sound = makeSentence [ "you hear"
                                , MU.AW $ MU.Phrase $ distant ++ [sound] ]
  return $! hear <$> msound

-- | Given the client, it's perception and an atomic command, determine
-- if the client notices the command.
seenAtomicCli :: Bool -> FactionId -> Perception -> PosAtomic -> Bool
seenAtomicCli knowEvents fid per posAtomic =
  case posAtomic of
    PosSight _ ps -> all (`ES.member` totalVisible per) ps || knowEvents
    PosFidAndSight fids _ ps ->
      fid `elem` fids || all (`ES.member` totalVisible per) ps || knowEvents
    PosSmell _ ps -> all (`ES.member` totalSmelled per) ps || knowEvents
    PosFid fid2 -> fid == fid2
    PosFidAndSer _ fid2 -> fid == fid2
    PosSer -> False
    PosAll -> True
    PosNone -> assert `failure` "no position possible" `twith` fid

-- Not needed ATM, but may be a coincidence.
seenAtomicSer :: PosAtomic -> Bool
seenAtomicSer posAtomic =
  case posAtomic of
    PosFid _ -> False
    PosNone -> assert `failure` "no position possible" `twith` posAtomic
    _ -> True

-- | Generate the atomic updates that jointly perform a given item move.
generalMoveItem :: MonadStateRead m
                => ItemId -> Int -> Container -> Container
                -> m [UpdAtomic]
{-# INLINABLE generalMoveItem #-}
generalMoveItem iid k c1 c2 =
  case (c1, c2) of
    (CActor aid1 cstore1, CActor aid2 cstore2) | aid1 == aid2
                                                 && cstore1 /= CSha
                                                 && cstore2 /= CSha ->
      return [UpdMoveItem iid k aid1 cstore1 cstore2]
    _ -> containerMoveItem iid k c1 c2

containerMoveItem :: MonadStateRead m
                  => ItemId -> Int -> Container -> Container
                  -> m [UpdAtomic]
{-# INLINABLE containerMoveItem #-}
containerMoveItem iid k c1 c2 = do
  bag <- getsState $ getContainerBag c1
  case iid `EM.lookup` bag of
    Nothing -> assert `failure` (iid, k, c1, c2)
    Just (_, it) -> do
      item <- getsState $ getItemBody iid
      return [ UpdLoseItem iid item (k, take k it) c1
             , UpdSpotItem iid item (k, take k it) c2 ]
