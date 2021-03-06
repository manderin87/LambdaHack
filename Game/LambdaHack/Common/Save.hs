-- | Saving and restoring server game state.
module Game.LambdaHack.Common.Save
  ( ChanSave, saveToChan, wrapInSaves, restoreGame
#ifdef EXPOSE_INTERNAL
    -- * Internal operations
  , loopSave
#endif
  ) where

import Prelude ()

import Game.LambdaHack.Common.Prelude

import Control.Concurrent
import Control.Concurrent.Async
import qualified Control.Exception as Ex hiding (handle)
import Data.Binary
import qualified Data.Text as T
import qualified Data.Text.IO as T
import System.FilePath
import System.IO (hFlush, stdout)
import qualified System.Random as R

import Game.LambdaHack.Common.File
import Game.LambdaHack.Common.Misc (appDataDir)

type ChanSave a = MVar (Maybe a)

saveToChan :: ChanSave a -> a -> IO ()
saveToChan toSave s = do
  -- Wipe out previous candidates for saving.
  void $ tryTakeMVar toSave
  putMVar toSave $ Just s

-- | Repeatedly save a simple serialized version of the current state.
loopSave :: Binary a => (a -> FilePath) -> ChanSave a -> IO ()
loopSave saveFile toSave =
  loop
 where
  loop = do
    -- Wait until anyting to save.
    ms <- takeMVar toSave
    case ms of
      Just s -> do
        dataDir <- appDataDir
        tryCreateDir (dataDir </> "saves")
        encodeEOF (dataDir </> "saves" </> saveFile s) s
        -- Wait until the save finished. During that time, the mvar
        -- is continually updated to newest state values.
        loop
      Nothing -> return ()  -- exit

wrapInSaves :: Binary a => (a -> FilePath) -> (ChanSave a -> IO ()) -> IO ()
{-# INLINE wrapInSaves #-}
wrapInSaves saveFile exe = do
  -- We don't merge this with the other calls to waitForChildren,
  -- because, e.g., for server, we don't want to wait for clients to exit,
  -- if the server crashes (but we wait for the save to finish).
  toSave <- newEmptyMVar
  a <- async $ loopSave saveFile toSave
  link a
  let fin = do
        -- Wait until the last save (if any) starts
        -- and tell the save thread to end.
        putMVar toSave Nothing
        -- Wait 0.5s to flush debug and then until the save thread ends.
        threadDelay 500000
        wait a
  exe toSave `Ex.finally` fin
  -- The creation of, e.g., the initial client state, is outside the 'finally'
  -- clause, but this is OK, since no saves are ordered until 'runActionCli'.
  -- We save often, not only in the 'finally' section, in case of
  -- power outages, kill -9, GHC runtime crashes, etc. For internal game
  -- crashes, C-c, etc., the finalizer would be enough.
  -- If we implement incremental saves, saving often will help
  -- to spread the cost, to avoid a long pause at game exit.

-- | Restore a saved game, if it exists. Initialize directory structure
-- and copy over data files, if needed.
restoreGame :: Binary a => String -> IO (Maybe a)
restoreGame name = do
  -- Create user data directory and copy files, if not already there.
  dataDir <- appDataDir
  tryCreateDir dataDir
  let saveFile = dataDir </> "saves" </> name
  saveExists <- doesFileExist saveFile
  -- If the savefile exists but we get IO or decoding errors,
  -- we show them and start a new game. If the savefile was randomly
  -- corrupted or made read-only, that should solve the problem.
  -- OTOH, serious IO problems (e.g. failure to create a user data directory)
  -- terminate the program with an exception.
  res <- Ex.try $
    if saveExists then do
      s <- strictDecodeEOF saveFile
      return $ Just s
    else return Nothing
  let handler :: Ex.SomeException -> IO (Maybe a)
      handler e = do
        let msg = "Restore failed. The error message is:"
                  <+> (T.unwords . T.lines) (tshow e)
        delayPrint msg
        return Nothing
  either handler return res

delayPrint :: Text -> IO ()
delayPrint t = do
  delay <- R.randomRIO (0, 1000000)
  threadDelay delay  -- try not to interleave saves with other clients
  T.hPutStrLn stdout t
  hFlush stdout
