# Intro

The package provides build integration with GLib GResources.
It allows for automatically building GResources with Haskell programs.
The resource is linked into the binary and automatically registered at startup.

# Quick start

## Cabal

Install with your package manager a package containing the `glib-compile-resources` program and ensure it is available from your `PATH`.

Add the following fields to your `cabal` file.

```cabal
build-type: Hooks

custom-setup
  setup-depends:
    base,
    Cabal-hooks
    cabal-gresource,

executable application:
    x-gresource-xml-file: resource/resource.xml
    x-gresource-source-dir: resource
```

* `x-gresource-xml-file`: Path to the XML file describing the GResource
* `x-gresource-source-dir`: The base path from which relative paths in the XML file will be resolved.

Remember to add the files to `extra-source-files` in order to be included in sdist.

## Build integration

There are two ways to integrate `cabal-gresource` depending on your package's `build-type`, one for `Custom` second for `Hooks`.

### build-type: Hooks
Set the `build-type: Hooks` and create `SetupHooks.hs` file.

```haskell
module SetupHooks (setupHooks) where

import Distribution.Simple.GResource.Hooks (gResourceSetupHooks)
import Distribution.Simple.SetupHooks (SetupHooks)

setupHooks :: SetupHooks
setupHooks = gResourceSetupHooks
```

### build-type: Custom
Set the `build-type: Custom` and create `Setup.hs` file.

```haskell
import Distribution.Simple
import Distribution.Simple.GResource

main = defaultMainWithHooks $ gResourceUserHooks simpleUserHooks
```

## Runtime

During runtime, the GResource is automatically registered. You can access the data as shown below:

```haskell
import Data.Maybe (fromJust)
import Data.Text qualified as T
import GI.GLib.Structs.Bytes qualified as GLib
import GI.Gio qualified as Gio

main :: IO ()
main = do
  gresdata <- fromJust <$> (Gio.resourcesLookupData (T.pack "/path/to/your/data.txt") [Gio.ResourceLookupFlagsNone] >>= GLib.bytesGetData)
```

Refer to [gi-gio][1] and [gi-glib][2] packages from [haskell-gi][3] project for details about GResource API.

# Short on how it works

The XML describing the GResource file is compiled with `glib-compile-resources` to a C source file.
The C source file is then compiled and linked with the Haskell program by GHC during build.
The C source contains a constructor that is automatically called by the C runtime during program startup.

Thanks to this the GResource is automatically registered with Gio.

[1]: https://hackage.haskell.org/package/gi-gio
[2]: https://hackage.haskell.org/package/gi-glib
[3]: https://hackage.haskell.org/package/haskell-gi
