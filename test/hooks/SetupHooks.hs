module SetupHooks (setupHooks) where

import Distribution.Simple.GResource (gResourceSetupHooks)
import Distribution.Simple.SetupHooks (SetupHooks)

setupHooks :: SetupHooks
setupHooks = gResourceSetupHooks
