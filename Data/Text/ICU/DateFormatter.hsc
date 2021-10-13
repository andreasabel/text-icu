{-# LANGUAGE EmptyDataDecls, BlockArguments, ImportQualifiedPost, RankNTypes, BangPatterns, ForeignFunctionInterface, RecordWildCards #-}
-- |
-- Module      : Data.Text.ICU.DateFormatter
-- Copyright   : (c) 2021 Torsten Kemps-Benedix
--
-- License     : BSD-style
-- Maintainer  : bos@serpentine.com
-- Stability   : experimental
-- Portability : GHC
--
-- Calendar formatter implemented as bindings to
-- the International Components for Unicode (ICU) libraries.

module Data.Text.ICU.DateFormatter
    (DateFormatter, FormatStyle(..), DateFormatSymbolType(..), standardDateFormatter, patternDateFormatter, dateSymbols, formatCalendar
    ) where

#include <unicode/udat.h>

import Control.Monad (forM)
import Data.Int (Int32)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Foreign (useAsPtr, fromPtr)
import Data.Text.ICU.Error.Internal (UErrorCode, handleError, handleOverflowError)
import Data.Text.ICU.Internal (LocaleName(..), UChar, withLocaleName)
import Data.Text.ICU.Calendar
import Foreign.C.String (CString)
import Foreign.C.Types (CInt(..))
import Foreign.ForeignPtr (newForeignPtr, withForeignPtr, ForeignPtr)
import Foreign.Ptr (FunPtr, Ptr, castPtr, nullPtr)
import Prelude hiding (last)
import System.IO.Unsafe (unsafePerformIO)

-- | The possible date/time format styles.
data FormatStyle =
       FullFormatStyle -- ^ Full style. 
       | LongFormatStyle -- ^ Long style.
       | MediumFormatStyle -- ^ Medium style.
       | ShortFormatStyle -- ^ Short style.
       | DefaultFormatStyle -- ^ Default style
       | RelativeFormatStyle -- ^ Relative style.
       | NoFormatStyle -- ^ No style.
  deriving (Eq, Enum, Show)

toUDateFormatStyle :: FormatStyle -> CInt
toUDateFormatStyle FullFormatStyle = #const UDAT_FULL
toUDateFormatStyle LongFormatStyle = #const UDAT_LONG
toUDateFormatStyle MediumFormatStyle = #const UDAT_MEDIUM
toUDateFormatStyle ShortFormatStyle = #const UDAT_SHORT
toUDateFormatStyle DefaultFormatStyle = #const UDAT_DEFAULT
toUDateFormatStyle RelativeFormatStyle = #const UDAT_RELATIVE
toUDateFormatStyle NoFormatStyle = #const UDAT_NONE

-- | The possible types of date format symbols.
data DateFormatSymbolType =
        Eras -- ^  The era names, for example AD.
        | Months -- ^  The month names, for example February.
        | ShortMonths -- ^  The short month names, for example Feb.
        | Weekdays -- ^  The CLDR-style format "wide" weekday names, for example Monday.
        | ShortWeekdays -- ^  The CLDR-style format "abbreviated" (not "short") weekday names, for example "Mon." For the CLDR-style format "short" weekday names, use UDAT_SHORTER_WEEKDAYS.
        | AmPms -- ^  The AM/PM names, for example AM.
        | LocalizedChars -- ^  The localized characters.
        | EraNames -- ^  The long era names, for example Anno Domini.
        | NarrowMonths -- ^  The narrow month names, for example F.
        | NarrowWeekdays -- ^  The CLDR-style format "narrow" weekday names, for example "M".
        | StandaloneMonths -- ^  Standalone context versions of months.
        | StandaloneWeekdays -- ^  The CLDR-style stand-alone "wide" weekday names.
        | StandaoneShortWeekdays -- ^  The CLDR-style stand-alone "abbreviated" (not "short") weekday names. For the CLDR-style stand-alone "short" weekday names, use UDAT_STANDALONE_SHORTER_WEEKDAYS.
        | StandaloneNarrowWeekdays -- ^  The CLDR-style stand-alone "narrow" weekday names.
        | Quarters -- ^  The quarters, for example 1st Quarter.
        | ShortQuarters -- ^  The short quarter names, for example Q1.
        | StandaloneQuarters -- ^  Standalone context versions of quarters.
        | ShorterWeekdays -- ^  The CLDR-style short weekday names, e.g. "Su", Mo", etc. These are named "SHORTER" to contrast with the constants using SHORT above, which actually get the CLDR-style abbreviated versions of the corresponding names.
        | StandaloneShorterWeekdays -- ^  Standalone version of UDAT_SHORTER_WEEKDAYS.
        | CyclicYearsWide -- ^  Cyclic year names (only supported for some calendars, and only for FORMAT usage; udat_setSymbols not supported for UDAT_CYCLIC_YEARS_WIDE)
        | CyclicYearsAbbreviated -- ^  Cyclic year names (only supported for some calendars, and only for FORMAT usage)
        | CyclicYearsNarrow -- ^  Cyclic year names (only supported for some calendars, and only for FORMAT usage; udat_setSymbols not supported for UDAT_CYCLIC_YEARS_NARROW)
        | ZodiacNamesWide -- ^  Calendar zodiac names (only supported for some calendars, and only for FORMAT usage; udat_setSymbols not supported for UDAT_ZODIAC_NAMES_WIDE)
        | ZodiacNamesAbbreviated -- ^ Calendar zodiac names (only supported for some calendars, and only for FORMAT usage)
        | ZodiacNamesNarrow -- ^  Calendar zodiac names (only supported for some calendars, and only for FORMAT usage; udat_setSymbols not supported for UDAT_ZODIAC_NAMES_NARROW)

toUDateFormatSymbolType :: DateFormatSymbolType -> CInt
toUDateFormatSymbolType Eras = #const UDAT_ERAS
toUDateFormatSymbolType Months = #const UDAT_MONTHS
toUDateFormatSymbolType ShortMonths = #const UDAT_SHORT_MONTHS
toUDateFormatSymbolType Weekdays = #const UDAT_WEEKDAYS
toUDateFormatSymbolType ShortWeekdays = #const UDAT_SHORT_WEEKDAYS
toUDateFormatSymbolType AmPms = #const UDAT_AM_PMS
toUDateFormatSymbolType LocalizedChars = #const UDAT_LOCALIZED_CHARS
toUDateFormatSymbolType EraNames = #const UDAT_ERA_NAMES
toUDateFormatSymbolType NarrowMonths = #const UDAT_NARROW_MONTHS
toUDateFormatSymbolType NarrowWeekdays = #const UDAT_NARROW_WEEKDAYS
toUDateFormatSymbolType StandaloneMonths = #const UDAT_STANDALONE_MONTHS
toUDateFormatSymbolType StandaloneWeekdays = #const UDAT_STANDALONE_WEEKDAYS
toUDateFormatSymbolType StandaoneShortWeekdays = #const UDAT_STANDALONE_SHORT_WEEKDAYS
toUDateFormatSymbolType StandaloneNarrowWeekdays = #const UDAT_STANDALONE_NARROW_WEEKDAYS
toUDateFormatSymbolType Quarters = #const UDAT_QUARTERS
toUDateFormatSymbolType ShortQuarters = #const UDAT_SHORT_QUARTERS
toUDateFormatSymbolType StandaloneQuarters = #const UDAT_STANDALONE_QUARTERS
toUDateFormatSymbolType ShorterWeekdays = #const UDAT_SHORTER_WEEKDAYS
toUDateFormatSymbolType StandaloneShorterWeekdays = #const UDAT_STANDALONE_SHORTER_WEEKDAYS
toUDateFormatSymbolType CyclicYearsWide = #const UDAT_CYCLIC_YEARS_WIDE
toUDateFormatSymbolType CyclicYearsAbbreviated = #const UDAT_CYCLIC_YEARS_ABBREVIATED
toUDateFormatSymbolType CyclicYearsNarrow = #const UDAT_CYCLIC_YEARS_NARROW
toUDateFormatSymbolType ZodiacNamesWide = #const UDAT_ZODIAC_NAMES_WIDE
toUDateFormatSymbolType ZodiacNamesAbbreviated = #const UDAT_ZODIAC_NAMES_ABBREVIATED
toUDateFormatSymbolType ZodiacNamesNarrow = #const UDAT_ZODIAC_NAMES_NARROW

type UDateFormatStyle = CInt
type UFieldPosition = CInt
type UDateFormatSymbolType = CInt

data UDateFormat

-- | Abstract data type holding a foreign pointer to the ICU date format object.
newtype DateFormatter = DateFormatter (ForeignPtr UDateFormat)

-- | Create a new 'DateFormatter' from the standard styles.
--
-- >>> import Data.Text
-- >>> dfDe <- standardDateFormatter LongFormatStyle LongFormatStyle (Locale "de_DE") (pack "CET")
standardDateFormatter :: FormatStyle -> FormatStyle -> LocaleName -> Text -> IO DateFormatter
standardDateFormatter timeStyle dateStyle loc timeZoneId =
  withLocaleName loc $ \locale ->
    useAsPtr timeZoneId $ \tzPtr tzLen -> do
      df <- handleError $ udat_open (toUDateFormatStyle timeStyle) (toUDateFormatStyle dateStyle) locale tzPtr (fromIntegral tzLen) nullPtr (0 :: Int32)
      dfPtr <- newForeignPtr udat_close df
      pure $ DateFormatter dfPtr

-- | Create a new 'DateFormatter' using a custom pattern as described at 
-- https://unicode-org.github.io/icu/userguide/format_parse/datetime/#datetime-format-syntax. For examples
-- the pattern "yyyy.MM.dd G 'at' HH:mm:ss zzz" produces “1996.07.10 AD at 15:08:56 PDT” in English for
-- the PDT time zone.
patternDateFormatter :: Text -> LocaleName -> Text -> IO DateFormatter
patternDateFormatter pattern loc timeZoneId =
  withLocaleName loc $ \locale ->
    useAsPtr timeZoneId $ \tzPtr tzLen -> do
      useAsPtr pattern $ \patPtr patLen -> do
        df <- handleError $ udat_open (fromIntegral ((#const UDAT_PATTERN) :: Int32)) (fromIntegral ((#const UDAT_PATTERN) :: Int32)) locale tzPtr (fromIntegral tzLen) patPtr (fromIntegral patLen)
        dfPtr <- newForeignPtr udat_close df
        pure $ DateFormatter dfPtr

-- | Get relevant date related symbols, e.g. month and weekday names.
--
-- >>> import Data.Text
-- >>> dfDe <- standardDateFormatter LongFormatStyle LongFormatStyle (Locale "de_DE") (pack "CET")
-- >>> dateSymbols dfDe Months
-- ["Januar","Februar","M\228rz","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"]
-- >>> dfAt <- standardDateFormatter LongFormatStyle LongFormatStyle (Locale "de_AT") (pack "CET")
-- >>> dateSymbols dfAt Months
-- ["J\228nner","Februar","M\228rz","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"]
dateSymbols :: DateFormatter -> DateFormatSymbolType -> [Text]
dateSymbols (DateFormatter df) symType = unsafePerformIO do
  withForeignPtr df $ \dfPtr -> do
    n <- udat_countSymbols dfPtr (toUDateFormatSymbolType symType)
    syms <- forM [0..(n-1)] \i -> do
      handleOverflowError (fromIntegral (64 :: Int))
        (\dptr dlen -> udat_getSymbols dfPtr (toUDateFormatSymbolType symType) (fromIntegral i) dptr dlen)
        (\dptr dlen -> fromPtr (castPtr dptr) (fromIntegral dlen))
    pure $ filter (not . T.null) syms

-- | Format a 'Calendar' using a 'DateFormatter'.
--
-- >>> import Data.Text
-- >>> dfDe <- standardDateFormatter LongFormatStyle LongFormatStyle (Locale "de_DE") (pack "CET")
-- >>> c <- calendar (pack "CET") (Locale "de_DE") TraditionalCalendarType
-- >>> formatCalendar dfDe c
-- "13. Oktober 2021 um 12:44:09 GMT+2"
formatCalendar :: DateFormatter -> Calendar -> Text
formatCalendar (DateFormatter df) (Calendar cal) = unsafePerformIO $
  withForeignPtr df $ \dfPtr -> do
    withForeignPtr cal $ \calPtr -> do
      handleOverflowError (fromIntegral (64 :: Int))
        (\dptr dlen -> udat_formatCalendar dfPtr calPtr dptr dlen nullPtr)
        (\dptr dlen -> fromPtr (castPtr dptr) (fromIntegral dlen))

foreign import ccall unsafe "hs_text_icu.h __hs_udat_open" udat_open
    :: UDateFormatStyle -> UDateFormatStyle 
    -> CString 
    -> Ptr UChar -> Int32 
    -> Ptr UChar -> Int32 
    -> Ptr UErrorCode 
    -> IO (Ptr UDateFormat)
foreign import ccall unsafe "hs_text_icu.h &__hs_udat_close" udat_close
    :: FunPtr (Ptr UDateFormat -> IO ())
foreign import ccall unsafe "hs_text_icu.h __hs_udat_formatCalendar" udat_formatCalendar
    :: Ptr UDateFormat 
    -> Ptr UCalendar 
    -> Ptr UChar -> Int32 
    -> Ptr UFieldPosition 
    -> Ptr UErrorCode 
    -> IO Int32
foreign import ccall unsafe "hs_text_icu.h __hs_udat_getSymbols" udat_getSymbols
    :: Ptr UDateFormat -> UDateFormatSymbolType -> Int32 -> Ptr UChar -> Int32 -> Ptr UErrorCode -> IO Int32
foreign import ccall unsafe "hs_text_icu.h __hs_udat_countSymbols" udat_countSymbols
    :: Ptr UDateFormat -> UDateFormatSymbolType -> IO Int32
