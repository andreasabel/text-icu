{-# LANGUAGE CPP, NoImplicitPrelude #-}
-- |
-- Module      : Data.Text.ICU
-- Copyright   : (c) 2010 Bryan O'Sullivan
--
-- License     : BSD-style
-- Maintainer  : bos@serpentine.com
-- Stability   : experimental
-- Portability : GHC
--
-- Commonly used functions for Unicode, implemented as bindings to the
-- International Components for Unicode (ICU) libraries.
--
-- This module contains only the most commonly used types and
-- functions.  Other modules in this package expose richer interfaces.
module Data.Text.ICU
    (
    -- * Data representation
    -- $data

    -- * Types
      LocaleName(..)
    -- * Locales
    , availableLocales
    -- * Boundary analysis
    -- $break
    , Breaker
    , Break
    , brkPrefix
    , brkBreak
    , brkSuffix
    , brkStatus
    , Line(..)
    , Word(..)
    , breakCharacter
    , breakLine
    , breakSentence
    , breakWord
    , breaks
    , breaksRight
    -- * Case mapping
    , toCaseFold
    , toLower
    , toUpper
    -- * Iteration
    , CharIterator
    , fromString
    , fromText
    , fromUtf8
    -- * Normalization
    -- $compat
    -- ** Normalize unicode strings
    , nfc, nfd, nfkc, nfkd, nfkcCasefold
    -- ** Checks for normalization
    , quickCheck, isNormalized
    -- * String comparison
    -- ** Normalization-sensitive string comparison
    , CompareOption(..)
    , compareUnicode
    -- ** Locale-sensitive string collation
    -- $collate
    , Collator
    , collator
    , collatorWith
    , collate
    , collateIter
    , sortKey
    , uca
    -- * Regular expressions
    , MatchOption(..)
    , ParseError(errError, errLine, errOffset)
    , Match
    , Regex
    , Regular
    -- ** Construction
    , regex
    , regex'
    -- ** Inspection
    , pattern
    -- ** Searching
    , find
    , findAll
    -- ** Match groups
    -- $group
    , groupCount
    , unfold
    , span
    , group
    , prefix
    , suffix
    -- * Spoof checking
    -- $spoof
    , Spoof
    , SpoofParams(..)
    , S.SpoofCheck(..)
    , S.RestrictionLevel(..)
    , S.SpoofCheckResult(..)
    -- ** Construction
    , spoof
    , spoofWithParams
    , spoofFromSource
    , spoofFromSerialized
    -- ** String checking
    , areConfusable
    , spoofCheck
    , getSkeleton
    -- ** Configuration
    , getChecks
    , getAllowedLocales
    , getRestrictionLevel
    -- ** Persistence
    , serialize
    -- * Calendars
    , Calendar, CalendarType(..), SystemTimeZoneType(..), CalendarField(..),
    -- ** Construction
    calendar,
    -- ** Operations on calendars
    roll, add, set1, set, get,
    -- * Number formatting
    NumberFormatter, numberFormatter, formatIntegral, formatIntegral', formatDouble, formatDouble',
    -- * Date formatting
    DateFormatter, FormatStyle(..), DateFormatSymbolType(..), standardDateFormatter, patternDateFormatter, dateSymbols, formatCalendar,
    ) where

import Data.Text.ICU.Break.Pure
import Data.Text.ICU.Calendar
import Data.Text.ICU.Collate.Pure
import Data.Text.ICU.DateFormatter
import Data.Text.ICU.Internal
import Data.Text.ICU.Iterator
import Data.Text.ICU.Locale
import Data.Text.ICU.Normalize2
import Data.Text.ICU.NumberFormatter
import Data.Text.ICU.Regex.Pure
import qualified Data.Text.ICU.Spoof as S
import Data.Text.ICU.Spoof.Pure
import Data.Text.ICU.Text
#if defined(__HADDOCK__)
import Data.Text.Foreign
import Data.Text (Text)
#endif

-- $data
--
-- The Haskell 'Text' type is implemented as an array in the Haskell
-- heap.  This means that its location is not pinned; it may be copied
-- during a garbage collection pass.  ICU, on the other hand, works
-- with strings that are allocated in the normal system heap and have
-- a fixed address.
--
-- To accommodate this need, these bindings use the functions from
-- "Data.Text.Foreign" to copy data between the Haskell heap and the
-- system heap.  The copied strings are still managed automatically,
-- but the need to duplicate data does add some performance and memory
-- overhead.

-- $break
--
-- Text boundary analysis is the process of locating linguistic
-- boundaries while formatting and handling text. Examples of this
-- process include:
--
-- * Locating appropriate points to word-wrap text to fit within
--   specific margins while displaying or printing.
--
-- * Counting characters, words, sentences, or paragraphs.
--
-- * Making a list of the unique words in a document.
--
-- * Figuring out if a given range of text contains only whole words.
--
-- * Capitalizing the first letter of each word.
--
-- * Locating a particular unit of the text (For example, finding the
--   third word in the document).
--
-- The 'Breaker' type was designed to support these kinds of
-- tasks.
--
-- For the impure boundary analysis API (which is richer, but less
-- easy to use than the pure API), see the "Data.Text.ICU.Break"
-- module.  The impure API supports some uses that may be less
-- efficient via the pure API, including:
--
-- * Locating the beginning of a word that the user has selected.
--
-- * Determining how far to move the text cursor when the user hits an
--   arrow key (Some characters require more than one position in the
--   text store and some characters in the text store do not display
--   at all).

-- $collate
--
-- For the impure collation API (which is richer, but less easy to
-- use than the pure API), see the "Data.Text.ICU.Collate"
-- module.

-- $group
--
-- Capturing groups are numbered starting from zero.  Group zero is
-- always the entire matching text.  Groups greater than zero contain
-- the text matching each capturing group in a regular expression.

-- $spoof
--
-- The 'Spoof' type performs security checks on visually confusable
-- (spoof) strings.  For the impure spoof checking API (which is
-- richer, but less easy to use than the pure API), see the
-- "Data.Text.ICU.Spoof" module.
--
-- See <http://unicode.org/reports/tr36/ UTR #36> and
-- <http://unicode.org/reports/tr39/ UTS #39> for detailed information
-- about the underlying algorithms and databases used by these functions.

-- $formatting
--
-- You create a 'NumberFormat' with 'numberFormatter' according to a locale
-- and a choice of pre-defined formats. A 'NumberFormat' provides a formatting
-- facility that 'format's numbers
-- according to the chosen locale. Alternatively create and apply a 'NumberFormat'
-- in a single step with 'formatNumber'' (it may be faster to re-use a NumberFormat though).
-- See the section \"Patterns\" at <https://unicode-org.github.io/icu-docs/apidoc/released/icu4c/classDecimalFormat.html#Patterns>
-- for further details regarding pattern strings.

-- $compat
-- See module 'Data.Text.ICU.Normalization2' for the full interface which provides some compatibility with the former API.
