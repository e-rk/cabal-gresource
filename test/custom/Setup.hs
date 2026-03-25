import Distribution.Simple
import Distribution.Simple.GResource

main :: IO ()
main = defaultMainWithHooks (gResourceUserHooks simpleUserHooks)
