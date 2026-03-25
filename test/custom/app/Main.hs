module Main (main) where

import Data.Maybe (fromJust)
import Data.Text qualified as T
import Data.Text.Encoding qualified as T
import GI.GLib.Structs.Bytes qualified as GLib
import GI.Gio qualified as Gio

main :: IO ()
main = do
  text1_data <- fromJust <$> (Gio.resourcesLookupData (T.pack "/io/github/e_rk/cabal_gresource/text1.txt") [Gio.ResourceLookupFlagsNone] >>= GLib.bytesGetData)
  let text1 = T.strip $ T.decodeUtf8Lenient text1_data
  if text1 == T.pack "Text1" then print text1 else fail ("Unexpected content: " <> show text1)
