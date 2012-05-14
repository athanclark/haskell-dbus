-- Copyright (C) 2009-2012 John Millikin <jmillikin@gmail.com>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

module DBus.Util
	( hexToInt
	, maybeIndex
	, readUntil
	, dropEnd
	, void
	, untilM
	, parseBytes
	, readPortNumber
	, randomUUID
	) where

import           Control.Monad (replicateM)
import qualified Data.ByteString.Char8 as Char8
import           Data.Char (digitToInt)
import           Data.List (isPrefixOf)
import           Data.Word (Word16)
import           Network.Socket (PortNumber)
import           System.Random (randomRIO)
import           Text.Printf (printf)

import           Text.ParserCombinators.Parsec (Parser, runParser)

hexToInt :: String -> Int
hexToInt = foldl ((+) . (16 *)) 0 . map digitToInt

maybeIndex :: [a] -> Int -> Maybe a
maybeIndex (x:_ ) 0         = Just x
maybeIndex (_:xs) n | n > 0 = maybeIndex xs (n - 1)
maybeIndex _ _ = Nothing

-- | Read values from a monad until a guard value is read; return all
-- values, including the guard.
--
readUntil :: (Monad m, Eq a) => [a] -> m a -> m [a]
readUntil guard getx = readUntil' [] where
	guard' = reverse guard
	step xs | isPrefixOf guard' xs = return . reverse $ xs
	        | otherwise            = readUntil' xs
	readUntil' xs = do
		x <- getx
		step $ x:xs

-- | Drop /n/ items from the end of a list
dropEnd :: Int -> [a] -> [a]
dropEnd n xs = take (length xs - n) xs

void :: Monad m => m a -> m ()
void m = m >> return ()

untilM :: Monad m => m Bool -> m a -> m [a]
untilM test comp = do
	done <- test
	if done
		then return []
		else do
			x <- comp
			xs <- untilM test comp
			return (x:xs)

parseBytes :: Parser a -> Char8.ByteString -> Maybe a
parseBytes p bytes = case runParser p () "" (Char8.unpack bytes) of
	Left _ -> Nothing
	Right a -> Just a

readPortNumber :: String -> Maybe PortNumber
readPortNumber s = do
	case dropWhile (\c -> c >= '0' && c <= '9') s of
		[] -> return ()
		_ -> Nothing
	let word = read s :: Integer
	if word > 0 && word <= 65535
		then Just (fromInteger word)
		else Nothing

-- | Generate a UUID, which is 128 bits of random data hex-encoded.
randomUUID :: IO String
randomUUID = do
	-- The version of System.Random bundled with ghc < 7.2 doesn't define
	-- instances for any of the fixed-length word types, so we imitate
	-- them using the instance for Int.
	--
	-- 128 bits is 8 16-bit integers. We use chunks of 16 instead of 32
	-- because Int is not guaranteed to be able to store a Word32.
	let hexInt16 i = printf "%04X" (i :: Int)
	int16s <- replicateM 8 (randomRIO (0, fromIntegral (maxBound :: Word16)))
	return (concatMap hexInt16 int16s)
