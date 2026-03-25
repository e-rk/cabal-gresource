-- |
-- Module      : cabal-gresource
-- Description : Build integration hooks for GResource files
-- Copyright   : (c) Rafał Kuźnia, 2026
-- License     : BSD3
-- Maintainer  : rafal.kuznia@protonmail.com
-- Stability   : experimental
-- Portability : POSIX
--
-- Hook for @build-type: Hooks@ builds.
--
-- There are two ways to integrate the module into your package's build,
-- one for @build-type: Hooks@, second one for @build-type: Custom@.
-- Unless you are constrained to use the @Custom@ build type,
-- using @Hooks@ is the recommended approach.
--
-- To build and link a GResource file with your application, add @x-gresource-xml-file@
-- and optionally @x-gresource-source-dir@ to your executable stanza.
-- The @x-gresource-xml-file@ points to the XML manifest describing the GResource file content,
-- while @x-gresource-source-dir@ is the base path from which relative paths in the XML file
-- will be resolved.
module Distribution.Simple.GResource
  ( -- * Integration hooks
    gResourceSetupHooks,
    gResourceUserHooks,
  )
where

import Distribution.Simple.GResource.Custom
  ( gResourceUserHooks,
  )
import Distribution.Simple.GResource.Hooks
  ( gResourceSetupHooks,
  )
