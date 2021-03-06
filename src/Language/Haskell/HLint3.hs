{-# LANGUAGE TupleSections, PatternGuards #-}

-- | /WARNING: This module represents the evolving second version of the HLint API./
--   /It will be renamed to drop the "3" in the next major version./
--
--   This module provides a way to apply HLint hints. As an example of approximating the @hlint@ experience:
--
-- @
-- (flags, classify, hint) <- 'autoSettings'
-- Right m <- 'parseModuleEx' flags \"MyFile.hs\" Nothing
-- print $ 'applyHints' classify hint [m]
-- @
module Language.Haskell.HLint3(
    applyHints,
    -- * Idea data type
    Idea(..), Severity(..), Note(..),
    -- * Settings
    Classify(..),
    getHLintDataDir, autoSettings,
    findSettings, readSettingsFile,
    -- * Hints
    HintBuiltin(..), HintRule(..),
    Hint(..), resolveHints,
    -- * Scopes
    Scope, scopeCreate, scopeMatch, scopeMove,
    -- * Haskell-src-exts
    parseModuleEx, defaultParseFlags, parseFlagsAddFixities, ParseError(..), ParseFlags(..), CppFlags(..)
    ) where

import Settings hiding (findSettings)
import Idea
import Apply
import Hint.Type
import Hint.All
import CmdLine
import Paths_hlint

import Data.List.Extra
import Data.Maybe
import System.FilePath


-- | Get the Cabal configured data directory of HLint.
getHLintDataDir :: IO FilePath
getHLintDataDir = getDataDir


-- | The function produces a tuple containg 'ParseFlags' (for 'parseModuleEx'),
--   and 'Classify' and 'Hint' for 'applyHints'.
--   It approximates the normal HLint configuration steps, roughly:
--
-- 1. Use 'findSettings' with 'readSettingsFile' to find and load the HLint settings files.
--
-- 1. Use 'parseFlagsAddFixities' and 'resolveHints' to transform the outputs of 'findSettings'.
--
--   If you want to do anything custom (e.g. using a different data directory, storing intermediate outputs,
--   loading hints from a database) you are expected to copy and paste this function, then change it to your needs.
autoSettings :: IO (ParseFlags, [Classify], Hint)
autoSettings = do
    (fixities, classify, hints) <- findSettings (readSettingsFile Nothing) Nothing
    return (parseFlagsAddFixities fixities defaultParseFlags, classify, resolveHints hints)


-- | Given a directory (or 'Nothing' to imply 'getHLintDataDir'), and a mdoule name
--   (e.g. @HLint.Default@), find the settings file associated with it, returning the
--   name of the file, and (optionally) the contents.
--
--   This function looks for all settings files starting with @HLint.@ in the directory
--   argument, and all other files relative to the current directory.
readSettingsFile :: Maybe FilePath -> String -> IO (FilePath, Maybe String)
readSettingsFile dir x
    | Just x <- "HLint." `stripPrefix` x = do
        dir <- maybe getHLintDataDir return dir
        return (dir </> x <.> "hs", Nothing)
    | otherwise = return (x <.> "hs", Nothing)


-- | Given a function to load a module (typically 'readSettingsFile'), and a module to start from
--   (defaults to @HLint.HLint@) find the information from all settings files.
findSettings :: (String -> IO (FilePath, Maybe String)) -> Maybe String -> IO ([Fixity], [Classify], [Either HintBuiltin HintRule])
findSettings load start = do
    (file,contents) <- load $ fromMaybe "HLint.HLint" start
    let flags = addInfix defaultParseFlags
    res <- parseModuleEx flags file contents
    case res of
        Left (ParseError sl msg err) ->
            error $ "Settings parse failure at " ++ showSrcLoc sl ++ ": " ++ msg ++ "\n" ++ err
        Right (m, _) -> do
            imported <- sequence [f $ fromNamed $ importModule i | i <- moduleImports m, importPkg i `elem` [Just "hint", Just "hlint"]]
            let (classify, rules) = Settings.readSettings m
            let fixities = getFixity =<< moduleDecls m
            return $ concatUnzip3 $ (fixities,classify,map Right rules) : imported
    where
        builtins =  [(drop 4 $ show h, h :: HintBuiltin) | h <- [minBound .. maxBound]]

        f x | x == "HLint.Builtin.All" = return ([], [], map Left [minBound..maxBound])
        f x | Just x <- "HLint.Builtin." `stripPrefix` x = case lookup x builtins of
                Just x -> return ([], [], [Left x])
                Nothing -> error $ "Unknown builtin hints: HLint.Builtin." ++ x
            | otherwise = findSettings load (Just x)


-- | Snippet from the documentation, if this changes, update the documentation
_docs :: IO ()
_docs = do
    (flags, classify, hint) <- autoSettings
    Right m <- parseModuleEx flags "MyFile.hs" Nothing
    print $ applyHints classify hint [m]
