{-# LANGUAGE DeriveDataTypeable, EmptyDataDecls, ForeignFunctionInterface #-}
-- |
-- Module      : Data.Text.ICU.Collate.Internal
-- Copyright   : (c) 2010 Bryan O'Sullivan
--
-- License     : BSD-style
-- Maintainer  : bos@serpentine.com
-- Stability   : experimental
-- Portability : GHC
--
-- Internals of the string collation infrastructure.

module Data.Text.ICU.Collate.Internal
    (
    -- * Unicode collation API
      MCollator(..)
    , Collator(..)
    , UCollator
    , withCollator
    , wrap
    ) where

import Control.Exception (mask_)
import Data.Typeable (Typeable)
import Foreign.ForeignPtr (ForeignPtr, newForeignPtr, withForeignPtr)
import Foreign.Ptr (FunPtr, Ptr)

-- $api
--

data UCollator

-- | String collator type.
data MCollator = MCollator {-# UNPACK #-} !(ForeignPtr UCollator)
                 deriving (Typeable)

-- | String collator type.
newtype Collator = C MCollator
    deriving (Typeable)

withCollator :: MCollator -> (Ptr UCollator -> IO a) -> IO a
withCollator (MCollator col) action = withForeignPtr col action
{-# INLINE withCollator #-}

wrap :: IO (Ptr UCollator) -> IO MCollator
wrap a = mask_ $ fmap MCollator $ newForeignPtr ucol_close =<< a
{-# INLINE wrap #-}

foreign import ccall unsafe "hs_text_icu.h &__hs_ucol_close" ucol_close
    :: FunPtr (Ptr UCollator -> IO ())
