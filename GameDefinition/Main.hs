-- | The main source code file of LambdaHack the game.
-- Module "TieKnot" is separated to make it usable in tests.
module Main
  ( main
  ) where

import Prelude ()

import Game.LambdaHack.Common.Prelude

import Control.Concurrent.Async
import System.Environment (getArgs)

import TieKnot

-- | Tie the LambdaHack engine client, server and frontend code
-- with the game-specific content definitions, and run the game.
main :: IO ()
main = do
  args <- getArgs
  -- Avoid the bound thread that would slow down the communication.
  a <- async $ tieKnot args
  wait a
