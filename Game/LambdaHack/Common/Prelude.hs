-- | Client monad for interacting with a human through UI.
module Game.LambdaHack.Common.Prelude
  ( module Prelude.Compat

  , module Control.Monad.Compat
  , module Data.List.Compat
  , module Data.Maybe
  , module Data.Monoid.Compat

  , module Control.Exception.Assert.Sugar

  , Text, (<+>), tshow, divUp, (<$$>)

  , (***), (&&&), first, second
  ) where

import Prelude ()

import Prelude.Compat hiding (appendFile, readFile, writeFile)

import Control.Arrow (first, second, (&&&), (***))
import Control.Monad.Compat
import Data.List.Compat
import Data.Maybe
import Data.Monoid.Compat

import Control.Exception.Assert.Sugar

import Data.Text (Text)

import qualified Data.Text as T (pack)
import qualified NLP.Miniutter.English as MU ((<+>))

infixr 6 <+>
(<+>) :: Text -> Text -> Text
(<+>) = (MU.<+>)

-- | Show and pack the result.
tshow :: Show a => a -> Text
tshow x = T.pack $ show x

infixl 7 `divUp`
-- | Integer division, rounding up.
divUp :: Integral a => a -> a -> a
{-# INLINE divUp #-}
divUp n k = (n + k - 1) `div` k

infixl 4 <$$>
(<$$>) :: (Functor f, Functor g) => (a -> b) -> f (g a) -> f (g b)
h <$$> m = fmap h <$> m
