{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE StaticPointers #-}

-- | Integration for @build-type: Hooks@ builds.
module Distribution.Simple.GResource.Hooks
  ( gResourceSetupHooks,
  )
where

import Control.Monad (void)
import Control.Monad.IO.Class (liftIO)
import qualified Data.List.NonEmpty as NE
import Data.String (fromString)
import Distribution.Simple.GResource.Internal
  ( GResourceCmd (..),
    GResourceConfig (..),
    GResourceDependenciesCmd (..),
    gResourceCName,
    parseGResourceConfig,
    runGResourceCmd,
    runGresourceGenerateDependencies,
  )
import Distribution.Simple.Program (requireProgram)
import Distribution.Simple.SetupHooks
import Distribution.Types.LocalBuildInfo (buildDirPBD)
import Distribution.Types.UnqualComponentName (unUnqualComponentName)
import Distribution.Utils.Path
  ( FileOrDir (Dir),
    SymbolicPath,
  )
import Distribution.Types.ComponentName (componentNameString)

-- | Hook for building the GResource files with @build-type: Hooks@.
-- Use in @SetupHooks.hs@ to integrate into the build process.
--
-- @
-- module SetupHooks (setupHooks) where
--
-- import Distribution.Simple.GResource.Hooks (gResourceSetupHooks)
-- import Distribution.Simple.SetupHooks (SetupHooks)
--
-- setupHooks :: SetupHooks
-- setupHooks = gResourceSetupHooks
-- @
--
-- Add @cabal-gresource@ to @setup-depends@:
--
-- @
-- build-type: Hooks
--
-- custom-setup
--   setup-depends:
--     base,
--     Cabal-hooks,
--     cabal-gresource
--
-- executable application:
--   ...
--   x-gresource-xml-file: resource/resource.xml
--   x-gresource-source-dir: resource
-- @
--
-- @since 0.1.0.0
gResourceSetupHooks :: SetupHooks
gResourceSetupHooks =
  noSetupHooks
    { configureHooks =
        noConfigureHooks {preConfComponentHook = Just gResourcePreConf},
      buildHooks =
        noBuildHooks {preBuildComponentRules = Just (rules (static ()) gResourceRules)}
    }

gResourceComponent :: Component -> Maybe (String, GResourceConfig)
gResourceComponent comp = do
  name <- compName comp
  cfg <- parseGResourceConfig (customFieldsBI (componentBuildInfo comp))
  pure (name, cfg)

compName :: Component -> Maybe String
compName comp = unUnqualComponentName <$> (componentNameString . componentName) comp

autogenDirPBD :: PackageBuildDescr -> String -> SymbolicPath Pkg (Dir b)
autogenDirPBD pbd name =
  buildDirPBD pbd </> makeRelativePathEx name </> makeRelativePathEx "autogen"

gResourcePreConf :: PreConfComponentInputs -> IO PreConfComponentOutputs
gResourcePreConf inputs@(PreConfComponentInputs _lbc pbd comp) =
  case gResourceComponent comp of
    Nothing -> pure (noPreConfComponentOutputs inputs)
    Just (name, cfg) ->
      let cFilePath = autogenDirPBD pbd name </> gResourceCName (gresourceXml cfg)
       in pure . PreConfComponentOutputs $
            buildInfoComponentDiff
              (componentName comp)
              (emptyBuildInfo {cSources = [cFilePath]})

gResourceRules :: PreBuildComponentInputs -> RulesM ()
gResourceRules (PreBuildComponentInputs what lbi tgt) =
  case gResourceComponent comp of
    Nothing -> pure ()
    Just (name, cfg) -> do
      (prog, _) <-
        liftIO $
          requireProgram verbosity (simpleProgram "glib-compile-resources") (withPrograms lbi)
      let autogenDir = autogenComponentModulesDir lbi clbi
          xml = gresourceXml cfg
          srcDir = gresourceSource cfg
          cName = gResourceCName xml
          depsArgs =
            GResourceDependenciesCmd
              { gdcProgram = prog,
                gdcPkgDirectory = pkgDir,
                gdcSourceDir = gresourceSource cfg,
                gdcXmlFile = xml,
                gdcVerbosity = verbosityFlags
              }
          genArgs =
            GResourceCmd
              { gcProgram = prog,
                gcPkgDirectory = pkgDir,
                gcSourceDir = gresourceSource cfg,
                gcTarget = autogenDir </> cName,
                gcXmlFile = xml,
                gcVerbosity = verbosityFlags
              }

          dependencyAction :: GResourceDependenciesCmd -> IO ([Dependency], ())
          dependencyAction cmd = do
            dependencies <- runGresourceGenerateDependencies cmd
            pure ([FileDependency $ Location sameDirectory dep | dep <- dependencies], ())

          generateAction :: GResourceCmd -> () -> IO ()
          generateAction cmd () = runGResourceCmd cmd

          depsCmd = mkCommand (static Dict) (static dependencyAction) depsArgs
          genCmd = mkCommand (static Dict) (static generateAction) genArgs
          manifestDep = FileDependency (Location sameDirectory xml)
          output = Location autogenDir cName
      addRuleMonitors
        [ monitorFileOrDirectory (getSymbolicPath xml),
          monitorDirectory (getSymbolicPath srcDir)
        ]
      void $
        registerRule
          (fromString ("gresource-" ++ name))
          (dynamicRule (static Dict) depsCmd genCmd [manifestDep] (output NE.:| []))
  where
    comp = targetComponent tgt
    clbi = targetCLBI tgt
    verbosityFlags = buildingWhatVerbosity what
    verbosity = mkVerbosity defaultVerbosityHandles verbosityFlags
    pkgDir = mbWorkDirLBI lbi
