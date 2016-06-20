{-# LANGUAGE CPP #-}
-- | Field Of View scanning with a variety of algorithms.
-- See <https://github.com/LambdaHack/LambdaHack/wiki/Fov-and-los>
-- for discussion.
module Game.LambdaHack.Common.Fov
  ( dungeonPerception, fidLidPerception, fidLidUsingReachable
  , clearInDungeon, lightInDungeon, fovCacheInDungeon
#ifdef EXPOSE_INTERNAL
    -- * Internal operations
  , PerceptionDynamicLit(..)
#endif
  ) where

import Prelude ()

import Game.LambdaHack.Common.Prelude

import qualified Data.EnumMap.Lazy as EML
import qualified Data.EnumMap.Strict as EM
import qualified Data.EnumSet as ES

import Game.LambdaHack.Common.Actor
import Game.LambdaHack.Common.Faction
import Game.LambdaHack.Common.FovDigital
import Game.LambdaHack.Common.Item
import qualified Game.LambdaHack.Common.Kind as Kind
import Game.LambdaHack.Common.Level
import Game.LambdaHack.Common.Perception
import Game.LambdaHack.Common.Point
import qualified Game.LambdaHack.Common.PointArray as PointArray
import Game.LambdaHack.Common.State
import qualified Game.LambdaHack.Common.Tile as Tile
import Game.LambdaHack.Common.Vector

-- | All positions lit by dynamic lights on a level. Shared by all factions.
-- The list may contain (many) repetitions.
newtype PerceptionDynamicLit = PerceptionDynamicLit
    {pdynamicLit :: [Point]}
  deriving Show

-- | Calculate faction's perception of a level.
levelPerception :: PerceptionReachable -> [(Actor, FovCache3)]
                -> PointArray.Array Bool -> PointArray.Array Bool -> Level
                -> Perception
levelPerception reachable actorEqpBody clearPs litPs Level{lxsize, lysize} =
  let -- All non-projectile actors feel adjacent positions,
      -- even dark (for easy exploration). Projectiles rely on cameras.
      pAndVicinity p = p : vicinity lxsize lysize p
      gatherVicinities = concatMap (pAndVicinity . bpos . fst)
      nocteurs = filter (not . bproj . fst) actorEqpBody
      nocto = gatherVicinities nocteurs
      psight = visibleOnLevel reachable litPs nocto
      -- TODO: handle smell radius < 2, that is only under the actor
      -- Projectiles can potentially smell, too.
      canSmellAround FovCache3{fovSmell} = fovSmell >= 2
      smellers = filter (canSmellAround . snd) actorEqpBody
      smells = gatherVicinities smellers
      -- No smell stored in walls and under other actors.
      canHoldSmell p = clearPs PointArray.! p
      psmell = PerceptionVisible $ ES.fromList $ filter canHoldSmell smells
  in Perception psight psmell

-- | Calculate faction's perception of a level based on the lit tiles cache.
fidLidPerception :: PersLit -> FactionId -> LevelId -> Level
                 -> (Perception, PerceptionReachable)
fidLidPerception (persFovCache, persLight, persClear) fid lid lvl =
  let bodyMap = filter (\(b, _) -> bfid b == fid && blid b == lid)
                $ EM.elems persFovCache
      litPs = persLight EML.! lid
      clearPs = persClear EML.! lid
      -- Dying actors included, to let them see their own demise.
      ourR = reachableFromActor clearPs
      reachable = PerceptionReachable $ ES.unions $ map ourR bodyMap
  in (levelPerception reachable bodyMap clearPs litPs lvl, reachable)

fidLidUsingReachable :: EM.EnumMap FactionId ServerPers
                     -> PersLit -> FactionId -> LevelId -> Level
                     -> (Perception, PerceptionReachable)
fidLidUsingReachable pserver (persFovCache, persLight, persClear) fid lid lvl =
  let bodyMap = filter (\(b, _) -> bfid b == fid && blid b == lid)
                $ EM.elems persFovCache
      litPs = persLight EML.! lid
      clearPs = persClear EML.! lid
      reachable = pserver EM.! fid EM.! lid
  in (levelPerception reachable bodyMap clearPs litPs lvl, reachable)

-- | Calculate perception of a faction.
factionPerception :: PersLit -> FactionId -> State -> (FactionPers, ServerPers)
factionPerception persLit fid s =
  let em = EM.mapWithKey (fidLidPerception persLit fid) $ sdungeon s
  in (EM.map fst em, EM.map snd em)

-- | Calculate the perception of the whole dungeon.
dungeonPerception :: State -> EM.EnumMap ItemId FovCache3 -> (PersLit, Pers)
dungeonPerception s sItemFovCache =
  let persClear = clearInDungeon s
      persFovCache = fovCacheInDungeon s sItemFovCache
      persLight = lightInDungeon persFovCache persClear s sItemFovCache
      persLit = (persFovCache, persLight, persClear)
      f fid _ = factionPerception persLit fid s
      em = EM.mapWithKey f $ sfactionD s
  in (persLit, Pers (EM.map fst em) (EM.map snd em))

-- | Compute positions visible (reachable and seen) by the party.
-- A position can be directly lit by an ambient shine or by a weak, portable
-- light source, e.g,, carried by an actor. A reachable and lit position
-- is visible. Additionally, positions directly adjacent to an actor are
-- assumed to be visible to him (through sound, touch, noctovision, whatever).
visibleOnLevel :: PerceptionReachable -> PointArray.Array Bool -> [Point]
               -> PerceptionVisible
visibleOnLevel PerceptionReachable{preachable} litPs nocto =
  let isVisible = (litPs PointArray.!)
  in PerceptionVisible $
       ES.fromList nocto `ES.union` ES.filter isVisible preachable

-- | Compute positions reachable by the actor. Reachable are all fields
-- on a visually unblocked path from the actor position.
reachableFromActor :: PointArray.Array Bool
                   -> (Actor, FovCache3)
                   -> ES.EnumSet Point
reachableFromActor clearPs (body, FovCache3{fovSight}) =
  let radius = min (fromIntegral $ bcalm body `div` (5 * oneM)) fovSight
  in fullscan clearPs radius (bpos body)

-- | Compute all dynamically lit positions on a level, whether lit by actors
-- or floor items. Note that an actor can be blind, in which case he doesn't see
-- his own light (but others, from his or other factions, possibly do).
litByItems :: PointArray.Array Bool -> [(Point, Int)]
           -> PerceptionDynamicLit
litByItems clearPs allItems =
  let litPos :: (Point, Int) -> [Point]
      litPos (p, light) = ES.toList $ fullscan clearPs light p
  in PerceptionDynamicLit $ concatMap litPos allItems

clearInDungeon :: State -> PersClear
clearInDungeon s =
  let Kind.COps{cotile} = scops s
      clearLvl (lid, Level{ltile}) =
        let clearTiles = PointArray.mapA (Tile.isClear cotile) ltile
        in (lid, clearTiles)
  in EML.fromDistinctAscList $ map clearLvl $ EM.assocs $ sdungeon s

lightInDungeon :: PersFovCache -> PersClear -> State
               -> EM.EnumMap ItemId FovCache3
               -> PersLight
lightInDungeon persFovCache persClear s sItemFovCache =
  let Kind.COps{cotile} = scops s
      processIid lightAcc (iid, (k, _)) =
        let FovCache3{fovLight} =
              EM.findWithDefault emptyFovCache3 iid  sItemFovCache
        in k * fovLight + lightAcc
      processBag bag acc = foldl' processIid acc $ EM.assocs bag
      lightOnFloor :: Level -> [(Point, Int)]
      lightOnFloor lvl =
        let processPos (p, bag) = (p, processBag bag 0)
        in map processPos $ EM.assocs $ lfloor lvl  -- lembed are hidden
      -- Note that an actor can be blind,
      -- in which case he doesn't see his own light
      -- (but others, from his or other factions, possibly do).
      litOnLevel :: LevelId -> Level -> PointArray.Array Bool
      litOnLevel lid lvl@Level{ltile} =
        let lvlBodies = filter ((== lid) . blid . fst) $ EM.elems persFovCache
            -- TODO: keep it in server state and update when tiles change.
            -- Actually, do this for PersLit.
            litTiles = PointArray.mapA (Tile.isLit cotile) ltile
            actorLights = map (\(b, FovCache3{fovLight}) -> (bpos b, fovLight))
                              lvlBodies
            floorLights = lightOnFloor lvl
            -- If there is light both on the floor and carried by actor,
            -- only the stronger light is taken into account.
            -- This is rare, so no point optimizing away the double computation.
            allLights = floorLights ++ actorLights
            litDynamic = pdynamicLit
                         $ litByItems (persClear EML.! lid) allLights
        in litTiles PointArray.// map (\p -> (p, True)) litDynamic
      litLvl (lid, lvl) = (lid, litOnLevel lid lvl)
  in EML.fromDistinctAscList $ map litLvl $ EM.assocs $ sdungeon s

fovCacheInDungeon :: State -> EM.EnumMap ItemId FovCache3 -> PersFovCache
fovCacheInDungeon s sItemFovCache =
  let processIid3 (FovCache3 sightAcc smellAcc lightAcc) (iid, (k, _)) =
        let FovCache3{..} =
              EM.findWithDefault emptyFovCache3 iid sItemFovCache
        in FovCache3 (k * fovSight + sightAcc)
                     (k * fovSmell + smellAcc)
                     (k * fovLight + lightAcc)
      processBag3 bag acc = foldl' processIid3 acc $ EM.assocs bag
      processActor b =
        let sslOrgan = processBag3 (borgan b) emptyFovCache3
            ssl = processBag3 (beqp b) sslOrgan
        in (b, ssl)
  in EM.map processActor $ sactorD s

-- | Perform a full scan for a given position. Returns the positions
-- that are currently in the field of view. The Field of View
-- algorithm to use is passed in the second argument.
-- The actor's own position is considred reachable by him.
fullscan :: PointArray.Array Bool  -- ^ the array with clear points
         -> Int        -- ^ scanning radius
         -> Point      -- ^ position of the spectator
         -> ES.EnumSet Point
fullscan clearPs radius spectatorPos =
  if | radius <= 0 -> ES.empty
     | radius == 1 -> ES.singleton spectatorPos
     | otherwise -> ES.insert spectatorPos
       $ mapTr (\B{..} -> trV   bx  (-by))  -- quadrant I
       $ mapTr (\B{..} -> trV   by    bx)   -- II (we rotate counter-clockwise)
       $ mapTr (\B{..} -> trV (-bx)   by)   -- III
       $ mapTr (\B{..} -> trV (-by) (-bx))  -- IV
       $ ES.empty
 where
  mapTr :: (Bump -> Point) -> ES.EnumSet Point -> ES.EnumSet Point
  {-# INLINE mapTr #-}
  mapTr tr es1 = foldl' (flip $ ES.insert . tr) es1 $ scan (radius - 1) (isCl . tr)

  isCl :: Point -> Bool
  {-# INLINE isCl #-}
  isCl = (clearPs PointArray.!)

  -- This function is cheap, so no problem it's called twice
  -- for each point: once with @isCl@, once via @concatMap@.
  trV :: X -> Y -> Point
  {-# INLINE trV #-}
  trV x y = shift spectatorPos $ Vector x y
