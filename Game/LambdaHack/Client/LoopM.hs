{-# LANGUAGE FlexibleContexts #-}
-- | The main loop of the client, processing human and computer player
-- moves turn by turn.
module Game.LambdaHack.Client.LoopM
  ( loopUI
  ) where

import Prelude ()

import Game.LambdaHack.Common.Prelude

import qualified Data.Text as T

import Game.LambdaHack.Atomic
import Game.LambdaHack.Client.HandleResponseM
import Game.LambdaHack.Client.MonadClient
import Game.LambdaHack.Client.State
import Game.LambdaHack.Client.UI
import Game.LambdaHack.Client.UI.Config
import Game.LambdaHack.Client.UI.KeyBindings
import Game.LambdaHack.Client.UI.MonadClientUI
import Game.LambdaHack.Client.UI.SessionUI
import Game.LambdaHack.Common.ClientOptions
import Game.LambdaHack.Common.Faction
import Game.LambdaHack.Common.MonadStateRead
import Game.LambdaHack.Common.Response
import Game.LambdaHack.Common.State
import Game.LambdaHack.Common.Vector

initAI :: MonadClient m => DebugModeCli -> m ()
initAI sdebugCli = do
  modifyClient $ \cli -> cli {sdebugCli}
  side <- getsClient sside
  debugPossiblyPrint $ "AI client" <+> tshow side <+> "initializing."

initUI :: MonadClientUI m => KeyKind -> Config -> DebugModeCli -> m ()
initUI copsClient sconfig sdebugCli = do
  modifyClient $ \cli -> cli {sdebugCli}
  side <- getsClient sside
  debugPossiblyPrint $ "UI client" <+> tshow side <+> "initializing."
  -- Start the frontend.
  schanF <- chanFrontend sdebugCli
  let !sbinding = stdBinding copsClient sconfig  -- evaluate to check for errors
      sess = emptySessionUI sconfig
  putSession sess { schanF
                  , sbinding
                  , sxhair = TVector $ Vector 1 1 }
                      -- a step south-east, less alarming

-- | The main game loop for an AI or UI client.
loopUI :: ( MonadClientSetup m
          , MonadClientUI m
          , MonadAtomic m
          , MonadClientReadResponse m
          , MonadClientWriteRequest m )
       => KeyKind -> Config -> DebugModeCli -> m ()
loopUI copsClient sconfig sdebugCli = do
  hasUI <- clientHasUI
  if not hasUI then initAI sdebugCli else initUI copsClient sconfig sdebugCli
  -- Warning: state and client state are invalid here, e.g., sdungeon
  -- and sper are empty.
  cops <- getsState scops
  restoredG <- tryRestore
  restored <- case restoredG of
    Just (s, cli, msess) | not $ snewGameCli sdebugCli -> do
      -- Restore game.
      let sCops = updateCOps (const cops) s
      handleResponse $ RespUpdAtomic $ UpdResumeServer sCops
      schanF <- getsSession schanF
      sbinding <- getsSession sbinding
      maybe (return ()) (\sess ->
        putSession sess {schanF, sbinding, sconfig}) msess
      putClient cli {sdebugCli}
      return True
    Just (_, _, msessR) -> do
      -- Preserve previous history, if any (--newGame).
      maybe (return ()) (\sessR -> modifySession $ \sess ->
        sess {shistory = shistory sessR}) msessR
      return False
    _ -> return False
  side <- getsClient sside
  cmd1 <- receiveResponse
  case (restored, cmd1) of
    (True, RespUpdAtomic UpdResume{}) -> return ()
    (True, RespUpdAtomic UpdRestart{}) ->
      when hasUI $ msgAdd $
        "Ignoring an old savefile and starting a new game."
    (False, RespUpdAtomic UpdResume{}) -> do
      removeServerSave
      error $ T.unpack $
        "Savefile of client" <+> tshow side
        <+> "not usable. Removing server savefile. Please restart now."
    (False, RespUpdAtomic UpdRestart{}) -> return ()
    _ -> assert `failure` "unexpected command" `twith` (side, restored, cmd1)
  handleResponse cmd1
  -- State and client state now valid.
  debugPossiblyPrint $ "UI client" <+> tshow side <+> "started."
  loop
  debugPossiblyPrint $ "UI client" <+> tshow side <+> "stopped."
 where
  loop = do
    cmd <- receiveResponse
    handleResponse cmd
    quit <- getsClient squit
    unless quit loop
