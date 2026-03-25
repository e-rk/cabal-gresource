{-# LANGUAGE DerivingStrategies #-}

-- | Internal utilities
module Distribution.Simple.GResource.Internal
  ( GResourceConfig (..),
    GResourceDependenciesCmd (..),
    GResourceCmd (..),
    GResource,
    xmlFilesField,
    sourceDirField,
    parseGResourceConfig,
    generatedCFile,
    gResourceCName,
    addCSources,
    runGResourceCmd,
    runGresourceGenerateDependencies,
  )
where

import Data.Maybe (fromMaybe)
import Distribution.Compat.Binary
import Distribution.Simple.Program (ConfiguredProgram, getProgramInvocationOutput, runProgramInvocation)
import Distribution.Simple.Program.Run (programInvocationCwd)
import Distribution.Simple.Utils (createDirectoryIfMissingVerbose)
import Distribution.Types.BuildInfo (BuildInfo (..))
import Distribution.Utils.Path
  ( CWD,
    FileOrDir (Dir, File),
    Pkg,
    Source,
    RelativePath,
    SymbolicPath,
    interpretSymbolicPath,
    interpretSymbolicPathCWD,
    makeRelativePathEx,
    makeSymbolicPath,
    takeDirectorySymbolicPath,
    (</>), replaceExtensionSymbolicPath, Build, getSymbolicPath,
  )
import Distribution.Verbosity (VerbosityFlags, defaultVerbosityHandles, mkVerbosity)
import GHC.Generics (Generic)
import qualified System.FilePath as FilePath

-- | Key for GResource XML manifest.
xmlFilesField :: String
xmlFilesField = "x-gresource-xml-file"

-- | Key for GResource source directory
sourceDirField :: String
sourceDirField = "x-gresource-source-dir"

-- | GResource configuration.
data GResourceConfig = GResourceConfig
  { -- | XML manifest path.
    gresourceXml :: RelativePath Source File,
    -- | The @--sourcedir@ passed to @glib-compile-resources@.
    gresourceSource :: SymbolicPath Pkg (Dir GResource)
  }

-- | Find custom fields and construct t'GResourceConfig'
parseGResourceConfig :: [(String, String)] -> Maybe GResourceConfig
parseGResourceConfig fields = do
  xmlFile <- makeRelativePathEx <$> lookup xmlFilesField fields
  let srcDir = fromMaybe "" (lookup sourceDirField fields)
  pure
    GResourceConfig
      { gresourceXml = xmlFile,
        gresourceSource = makeSymbolicPath srcDir
      }

generatedCFile ::
  SymbolicPath Pkg (Dir Build) ->
  String ->
  RelativePath Source File ->
  SymbolicPath Pkg File
generatedCFile baseDir componentName xml =
  baseDir </> generatedCRel
  where
    cFileName = gResourceCName xml
    generatedCRel = makeRelativePathEx componentName </> makeRelativePathEx "autogen" </> cFileName

gResourceCName :: RelativePath Source File -> RelativePath Source File
gResourceCName xml = makeRelativePathEx $ FilePath.takeFileName $ getSymbolicPath $ xml `replaceExtensionSymbolicPath` "c"

addCSources :: [SymbolicPath Pkg File] -> BuildInfo -> BuildInfo
addCSources generated bi = bi {cSources = generated ++ cSources bi}

-- | Run parameters and environment for @glib-compile-resources@.
data GResourceCmd = GResourceCmd
  { -- | Resolved @glib-compile-resources@ executable.
    gcProgram :: ConfiguredProgram,
    -- | Symbolic path to Pkg directory from CWD
    gcPkgDirectory :: Maybe (SymbolicPath CWD (Dir Pkg)),
    -- | Symbolic path to directory passed as @--sourcedir@ parameter.
    gcSourceDir :: SymbolicPath Pkg (Dir GResource),
    -- | Symbolic path to @autogen@ directory.
    gcTarget :: SymbolicPath Pkg File,
    -- | Symbolic path to XML manifest file.
    gcXmlFile :: RelativePath Source File,
    -- | Verbosity flags for logging
    gcVerbosity :: VerbosityFlags
  }
  deriving stock (Show, Generic)
  deriving anyclass (Binary)

-- | Run t`GResourceCmd.
runGResourceCmd :: GResourceCmd -> IO ()
runGResourceCmd cmd = do
  let verbosity = mkVerbosity defaultVerbosityHandles cmd.gcVerbosity
  createDirectoryIfMissingVerbose
    verbosity
    True
    (interpretSymbolicPath cmd.gcPkgDirectory (takeDirectorySymbolicPath cmd.gcTarget))
  runProgramInvocation verbosity $
    programInvocationCwd
      cmd.gcPkgDirectory
      (gcProgram cmd)
      [ "--generate-source",
        "--target=" ++ interpretSymbolicPathCWD cmd.gcTarget,
        "--sourcedir=" ++ interpretSymbolicPathCWD cmd.gcSourceDir,
        interpretSymbolicPathCWD cmd.gcXmlFile
      ]

-- | Dependency query command parameters and environment for @glib-compile-resources@
data GResourceDependenciesCmd = GResourceDependenciesCmd
  { -- | Configured @glib-compile-resources@ executable.
    gdcProgram :: ConfiguredProgram,
    -- | Symbolic path to Pkg directory from CWD
    gdcPkgDirectory :: Maybe (SymbolicPath CWD (Dir Pkg)),
    -- | Symbolic path to directory passed as @--sourcedir@ parameter.
    gdcSourceDir :: SymbolicPath Pkg (Dir GResource),
    -- | Relative path to the XML manifest file.
    gdcXmlFile :: RelativePath Source File,
    -- | Verbosity flags for logging
    gdcVerbosity :: VerbosityFlags
  }
  deriving stock (Show, Generic)
  deriving anyclass (Binary)

-- | Run t'GResourceDependenciesCmd'
runGresourceGenerateDependencies :: GResourceDependenciesCmd -> IO [RelativePath Pkg File]
runGresourceGenerateDependencies cmd = do
  let verbosity = mkVerbosity defaultVerbosityHandles cmd.gdcVerbosity
  dependencies <-
    getProgramInvocationOutput verbosity $
      programInvocationCwd
        cmd.gdcPkgDirectory
        cmd.gdcProgram
        [ "--generate-dependencies",
          "--sourcedir=" ++ interpretSymbolicPathCWD cmd.gdcSourceDir,
          interpretSymbolicPathCWD cmd.gdcXmlFile
        ]
  pure (map makeRelativePathEx (lines dependencies))

--------------------------------------------------------------------------------
-- Abstract directory locations.

-- | Abstract directory: GResource source directory.
data GResource
