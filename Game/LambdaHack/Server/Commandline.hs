-- | Parsing of commandline arguments.
module Game.LambdaHack.Server.Commandline
  ( debugArgs
  ) where

import Prelude ()

import Game.LambdaHack.Common.Prelude

import qualified Data.Text as T

import Game.LambdaHack.Common.ClientOptions
import Game.LambdaHack.Common.Faction
import Game.LambdaHack.Common.Misc
import Game.LambdaHack.Server.State

-- | Parse server debug parameters from commandline arguments.
debugArgs :: [String] -> IO DebugModeSer
debugArgs args = do
  let usage =
        [ "Configure debug options here, gameplay options in config.rules.ini."
        , "  --knowMap  reveal map for all clients in the next game"
        , "  --knowEvents  show all events in the next game (needs --knowMap)"
        , "  --knowItems  auto-identify all items in the next game (needs --knowEvents)"
        , "  --sniffIn  display all incoming commands on console "
        , "  --sniffOut  display all outgoing commands on console "
        , "  --allClear  let all map tiles be translucent"
        , "  --boostRandomItem  pick a random item and make it very common"
        , "  --gameMode m  start next game in the given mode"
        , "  --automateAll  give control of all UI teams to computer"
        , "  --keepAutomated  keep factions automated after game over"
        , "  --newGame n  start a new game, overwriting the save file,"
        , "               with difficulty for all UI players set to n"
        , "  --stopAfterSeconds n  exit game session after around n seconds"
        , "  --stopAfterFrames n  exit game session after around n frames"
        , "  --benchmark  restrict file IO, print stats"
        , "  --setDungeonRng s  set dungeon generation RNG seed to string s"
        , "  --setMainRng s  set the main game RNG seed to string s"
        , "  --dumpInitRngs  dump RNG states from the start of the game"
        , "  --dbgMsgSer  let the server emit its internal debug messages"
        , "  --gtkFontFamily s  use the given font family for the main game window in GTK"
        , "  --sdlFontFile s  use the given font file for the main game window in SDL2"
        , "  --sdlTtfSizeAdd s  enlarge map cells over scalable font max height in SDL2"
        , "  --sdlFonSizeAdd s  enlarge map cells on top of .fon font max height in SDL2"
        , "  --fontSize s  use the given font size for the main game window"
        , "  --noColorIsBold  refrain from making some bright color characters bolder"
        , "  --maxFps n  display at most n frames per second"
        , "  --disableAutoYes  never auto-answer all prompts"
        , "  --noAnim  don't show any animations"
        , "  --savePrefix  prepend the text to all savefile names"
        , "  --frontendTeletype  use the line terminal frontend (for tests)"
        , "  --frontendNull  use frontend with no display (for benchmarks)"
        , "  --frontendLazy  use frontend that not even computes frames (for benchmarks)"
        , "  --dbgMsgCli  let clients emit their internal debug messages"
        ]
      parseArgs [] = defDebugModeSer
      parseArgs ("--knowMap" : rest) =
        (parseArgs rest) {sknowMap = True}
      parseArgs ("--knowEvents" : rest) =
        (parseArgs rest) {sknowEvents = True}
      parseArgs ("--knowItems" : rest) =
        (parseArgs rest) {sknowItems = True}
      parseArgs ("--sniffIn" : rest) =
        (parseArgs rest) {sniffIn = True}
      parseArgs ("--sniffOut" : rest) =
        (parseArgs rest) {sniffOut = True}
      parseArgs ("--allClear" : rest) =
        (parseArgs rest) {sallClear = True}
      parseArgs ("--boostRandomItem" : rest) =
        (parseArgs rest) {sboostRandomItem = True}
      parseArgs ("--gameMode" : s : rest) =
        (parseArgs rest) {sgameMode = Just $ toGroupName (T.pack s)}
      parseArgs ("--automateAll" : rest) =
        (parseArgs rest) {sautomateAll = True}
      parseArgs ("--keepAutomated" : rest) =
        (parseArgs rest) {skeepAutomated = True}
      parseArgs ("--newGame" : s : rest) =
        let debugSer = parseArgs rest
            cdiff = read s
        in debugSer { scurChalSer = (scurChalSer debugSer) {cdiff}
                    , snewGameSer = True
                    , sdebugCli = (sdebugCli debugSer) {snewGameCli = True}}
      parseArgs ("--stopAfterSeconds" : s : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli =
             (sdebugCli debugSer) {sstopAfterSeconds = Just $ read s}}
      parseArgs ("--stopAfterFrames" : s : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli =
             (sdebugCli debugSer) {sstopAfterFrames = Just $ read s}}
      parseArgs ("--benchmark" : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli = (sdebugCli debugSer) {sbenchmark = True}}
      parseArgs ("--setDungeonRng" : s : rest) =
        (parseArgs rest) {sdungeonRng = Just $ read s}
      parseArgs ("--setMainRng" : s : rest) =
        (parseArgs rest) {smainRng = Just $ read s}
      parseArgs ("--dumpInitRngs" : rest) =
        (parseArgs rest) {sdumpInitRngs = True}
      parseArgs ("--dbgMsgSer" : rest) =
        (parseArgs rest) {sdbgMsgSer = True}
      parseArgs ("--gtkFontFamily" : s : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli = (sdebugCli debugSer) {sgtkFontFamily =
                                                         Just $ T.pack s}}
      parseArgs ("--sdlFontFile" : s : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli = (sdebugCli debugSer) {sdlFontFile =
                                                         Just $ T.pack s}}
      parseArgs ("--sdlTtfSizeAdd" : s : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli = (sdebugCli debugSer) {sdlTtfSizeAdd =
                                                         Just $ read s}}
      parseArgs ("--sdlFonSizeAdd" : s : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli = (sdebugCli debugSer) {sdlFonSizeAdd =
                                                         Just $ read s}}
      parseArgs ("--fontSize" : s : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli = (sdebugCli debugSer) {sfontSize =
                                                         Just $ read s}}
      parseArgs ("--noColorIsBold" : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli =
                       (sdebugCli debugSer) {scolorIsBold = Just False}}
      parseArgs ("--maxFps" : n : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli =
                       (sdebugCli debugSer) {smaxFps = Just $ max 1 $ read n}}
      parseArgs ("--disableAutoYes" : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli = (sdebugCli debugSer) {sdisableAutoYes = True}}
      parseArgs ("--noAnim" : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli = (sdebugCli debugSer) {snoAnim = Just True}}
      parseArgs ("--savePrefix" : s : rest) =
        let debugSer = parseArgs rest
        in debugSer { ssavePrefixSer = s
                    , sdebugCli =
                        (sdebugCli debugSer) {ssavePrefixCli = s}}
      parseArgs ("--frontendTeletype" : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli = (sdebugCli debugSer)
                                    {sfrontendTeletype = True}}
      parseArgs ("--frontendNull" : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli = (sdebugCli debugSer) {sfrontendNull = True}}
      parseArgs ("--frontendLazy" : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli = (sdebugCli debugSer) {sfrontendLazy = True}}
      parseArgs ("--dbgMsgCli" : rest) =
        let debugSer = parseArgs rest
        in debugSer {sdebugCli = (sdebugCli debugSer) {sdbgMsgCli = True}}
      parseArgs (wrong : _rest) =
        error $ "Unrecognized: " ++ wrong ++ "\n" ++ unlines usage
  return $! parseArgs args
