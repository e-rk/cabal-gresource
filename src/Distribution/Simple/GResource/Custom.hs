-- | Integration for @build-type: Custom@ builds.
module Distribution.Simple.GResource.Custom (gResourceUserHooks) where

import Distribution.PackageDescription
  ( Benchmark (benchmarkName),
    Executable (exeName),
    PackageDescription (benchmarks, executables, testSuites),
    TestSuite (testName),
    benchmarkBuildInfo,
    buildInfo,
    testBuildInfo,
  )
import Distribution.Simple (UserHooks, buildHook)
import Distribution.Simple.GResource.Internal
  ( GResourceCmd (..),
    GResourceConfig (..),
    addCSources,
    generatedCFile,
    parseGResourceConfig,
    runGResourceCmd,
  )
import Distribution.Simple.LocalBuildInfo
  ( LocalBuildInfo (withPrograms),
    buildDir,
    mbWorkDirLBI,
  )
import Distribution.Simple.Program (requireProgram, simpleProgram)
import Distribution.Simple.Setup (buildVerbosity, fromFlagOrDefault)
import Distribution.Types.BuildInfo (BuildInfo (customFieldsBI))
import Distribution.Types.UnqualComponentName (unUnqualComponentName)
import Distribution.Utils.Path (Build, FileOrDir (Dir), Pkg, SymbolicPath)
import Distribution.Verbosity (VerbosityFlags, defaultVerbosityHandles, mkVerbosity, normal)

-- | 'UserHooks' for building GResource files with @build-type: Custom@.
-- Use in @Setup.hs@ to integrate into the build process.
--
-- @
-- import Distribution.Simple
-- import Distribution.Simple.GResource
--
-- main :: IO ()
-- main = defaultMainWithHooks (gResourceUserHooks simpleUserHooks)
-- @
--
-- Add @cabal-gresource@ to @setup-depends@:
--
-- @
-- build-type: Custom
--
-- custom-setup
--   setup-depends:
--     base,
--     Cabal,
--     cabal-gresource
--
-- executable application:
--   ...
--   x-gresource-xml-file: resource/resource.xml
--   x-gresource-source-dir: resources
-- @
--
-- @since 0.1.0.0
gResourceUserHooks :: UserHooks -> UserHooks
gResourceUserHooks uh =
  uh
    { buildHook = \pd lbi hooks flags -> do
        let verbosityFlags = fromFlagOrDefault normal (buildVerbosity flags)
        pd' <- addGResources verbosityFlags lbi pd
        buildHook uh pd' lbi hooks flags
    }

addGResources :: VerbosityFlags -> LocalBuildInfo -> PackageDescription -> IO PackageDescription
addGResources verbosity lbi pd = do
  exes' <-
    traverse
      (onComponent (unUnqualComponentName . exeName) buildInfo (\e bi -> e {buildInfo = bi}))
      (executables pd)
  tests' <-
    traverse
      (onComponent (unUnqualComponentName . testName) testBuildInfo (\t bi -> t {testBuildInfo = bi}))
      (testSuites pd)
  benchs' <-
    traverse
      (onComponent (unUnqualComponentName . benchmarkName) benchmarkBuildInfo (\b bi -> b {benchmarkBuildInfo = bi}))
      (benchmarks pd)
  pure pd {executables = exes', testSuites = tests', benchmarks = benchs'}
  where
    bdir = buildDir lbi
    onComponent ::
      (c -> String) ->
      (c -> BuildInfo) ->
      (c -> BuildInfo -> c) ->
      c ->
      IO c
    onComponent nameOf getBI setBI c = do
      bi' <- processComponent verbosity lbi bdir (nameOf c) (getBI c)
      pure (setBI c bi')

processComponent ::
  VerbosityFlags ->
  LocalBuildInfo ->
  SymbolicPath Pkg (Dir Build) ->
  String ->
  BuildInfo ->
  IO BuildInfo
processComponent verbosityFlags lbi bdir name bi =
  case parseGResourceConfig (customFieldsBI bi) of
    Nothing -> pure bi
    Just cfg -> do
      (prog, _) <-
        requireProgram verbosity (simpleProgram "glib-compile-resources") (withPrograms lbi)
      let xml = gresourceXml cfg
      let targetAbs = generatedCFile bdir name xml
      runGResourceCmd
        GResourceCmd
          { gcProgram = prog,
            gcPkgDirectory = pkgDir,
            gcSourceDir = gresourceSource cfg,
            gcTarget = targetAbs,
            gcXmlFile = xml,
            gcVerbosity = verbosityFlags
          }
      pure (addCSources [targetAbs] bi)
  where
    pkgDir = mbWorkDirLBI lbi
    verbosity = mkVerbosity defaultVerbosityHandles verbosityFlags
