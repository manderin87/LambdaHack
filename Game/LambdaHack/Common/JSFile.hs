-- | Saving/loading with serialization and compression.
module Game.LambdaHack.Common.JSFile
  ( encodeEOF, strictDecodeEOF
  , tryCreateDir, doesFileExist, tryWriteFile, readFile
  ) where

import Prelude ()

import Game.LambdaHack.Common.Prelude

import Data.Binary
import qualified Data.ByteString.Lazy.Char8 as LBS
import qualified Data.Text as T
import Data.Text.Encoding (decodeLatin1)
import GHCJS.DOM (currentWindow)
import GHCJS.DOM.Storage (getItem, setItem)
import GHCJS.DOM.Types (runDOM)
import GHCJS.DOM.Window (getLocalStorageUnchecked)

-- | Serialize and save data with an EOF marker. In JS, compression
-- is probably performed by the browser and we don't have access
-- to the zlib library anyway, so we don't compress here.
-- The @OK@ is used as an EOF marker to ensure any apparent problems with
-- corrupted files are reported to the user ASAP.
encodeEOF :: Binary a => FilePath -> a -> IO ()
encodeEOF path a = flip runDOM undefined $ do
  Just win <- currentWindow
  storage <- getLocalStorageUnchecked win
  setItem storage path $ decodeLatin1 $ LBS.toStrict
                       $ encode (a, "OK" :: String)

-- | Read and deserialize data with an EOF marker.
-- The @OK@ EOF marker ensures any easily detectable file corruption
-- is discovered and reported before the function returns.
strictDecodeEOF :: Binary a => FilePath -> IO a
strictDecodeEOF path = flip runDOM undefined $ do
  Just win <- currentWindow
  storage <- getLocalStorageUnchecked win
  Just item <- getItem storage path
  let (a, n) = decode $ LBS.pack $ T.unpack item
  if n == ("OK" :: String)
    then return $! a
    else error $ "Fatal error: corrupted file " ++ path

-- | Try to create a directory; not needed with local storage in JS.
tryCreateDir :: FilePath -> IO ()
tryCreateDir _dir = return ()

doesFileExist :: FilePath -> IO Bool
doesFileExist path = flip runDOM undefined $ do
  Just win <- currentWindow
  storage <- getLocalStorageUnchecked win
  mitem <- getItem storage path
  let fileExists = isJust (mitem :: Maybe String)
  return $! fileExists

-- | Try to write a file, given content, if the file not already there.
tryWriteFile :: FilePath -> String -> IO ()
tryWriteFile path content = flip runDOM undefined $ do
  Just win <- currentWindow
  storage <- getLocalStorageUnchecked win
  mitem <- getItem storage path
  let fileExists = isJust (mitem :: Maybe String)
  unless fileExists $
    setItem storage path content

readFile :: FilePath -> IO String
readFile path = flip runDOM undefined $ do
  Just win <- currentWindow
  storage <- getLocalStorageUnchecked win
  mitem <- getItem storage path
  case mitem of
    Nothing -> error $ "Fatal error: no file " ++ path
    Just item -> return item
