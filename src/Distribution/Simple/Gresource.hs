module Distribution.Simple.Gresource (cabalGresourceHooks) where

import Data.Foldable
import Data.Maybe (fromMaybe)
import Distribution.PackageDescription
import Distribution.Simple
import Distribution.Simple.LocalBuildInfo
import Distribution.Simple.Setup
import Distribution.Simple.Utils (die')
import Distribution.Verbosity
import System.Exit
import System.FilePath
import System.Process

-- | Hooks for building and installing gresource files
cabalGresourceHooks ::
  -- | initial user hooks
  UserHooks ->
  -- | patched user hooks
  UserHooks
cabalGresourceHooks uh =
  uh
    { buildHook = \pd lbi _uh bflags -> do
        buildHook uh pd lbi _uh bflags
        buildGresource (fromFlagOrDefault maxBound (buildVerbosity bflags)) lbi,
      instHook = \pd lbi _uh iflags -> do
        _pd <- gresourcePD lbi pd
        instHook uh pd lbi _uh iflags,
      copyHook = \pd lbi _uh cflags -> do
        _pd <- gresourcePD lbi pd
        copyHook uh _pd lbi _uh cflags
    }

gresourcePD :: LocalBuildInfo -> PackageDescription -> IO PackageDescription
gresourcePD lbi pd = do
  let xmlFiles = getGresourceXmlFiles lbi
  let resourceFiles = map compiledFilePath xmlFiles
  return $ pd {dataFiles = resourceFiles ++ dataFiles pd}

compiledFilePath :: FilePath -> FilePath
compiledFilePath p = dir </> basename <.> ".gresource"
  where
    dir = takeDirectory p
    basename = takeBaseName p

buildGresource :: Verbosity -> LocalBuildInfo -> IO ()
buildGresource verbosity lbi = do
  let xmlFiles = getGresourceXmlFiles lbi
  let sourceDir = getGresourceSourceDir lbi
  let build file = do
        let targetFile = compiledFilePath file
        ph <-
          runProcess
            "glib-compile-resources"
            ["--target=" ++ targetFile, "--sourcedir=" ++ sourceDir, file]
            Nothing
            Nothing
            Nothing
            Nothing
            Nothing
        ec <- waitForProcess ph
        case ec of
          ExitSuccess -> return ()
          ExitFailure n -> die' verbosity ("'glib-compile-resources' exited with non-zero status (rc = " ++ show n ++ ")")
  traverse_ build xmlFiles

getCustomFields :: LocalBuildInfo -> [(String, String)]
getCustomFields = customFieldsPD . localPkgDescr

findInParametersDefault :: [(String, String)] -> String -> String -> String
findInParametersDefault al name def = (fromMaybe def . lookup name) al

getGresourceXmlStrings :: String -> [(String, String)] -> String
getGresourceXmlStrings d al = findInParametersDefault al "x-gresource-xml-files" d

getGresourceSourceDirString :: String -> [(String, String)] -> String
getGresourceSourceDirString d al = findInParametersDefault al "x-gresource-source-dir" d

getGresourceXmlFiles :: LocalBuildInfo -> [FilePath]
getGresourceXmlFiles = pure . getGresourceXmlStrings "" . getCustomFields

getGresourceSourceDir :: LocalBuildInfo -> FilePath
getGresourceSourceDir = getGresourceSourceDirString "" . getCustomFields
