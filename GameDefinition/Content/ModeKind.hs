-- | Game mode definitions.
module Content.ModeKind
  ( cdefs
  ) where

import Prelude ()

import Game.LambdaHack.Common.Prelude

import qualified Data.IntMap.Strict as IM

import Content.ModeKindPlayer
import Game.LambdaHack.Common.ContentDef
import Game.LambdaHack.Common.Dice
import Game.LambdaHack.Content.ModeKind

cdefs :: ContentDef ModeKind
cdefs = ContentDef
  { getSymbol = msymbol
  , getName = mname
  , getFreq = mfreq
  , validateSingle = validateSingleModeKind
  , validateAll = validateAllModeKind
  , content = contentFromList
      [raid, brawl, shootout, escape, zoo, ambush, exploration, safari, safariSurvival, battle, battleSurvival, defense, screensaverSafari, screensaverRaid, screensaverBrawl, screensaverAmbush]
  }
raid,        brawl, shootout, escape, zoo, ambush, exploration, safari, safariSurvival, battle, battleSurvival, defense, screensaverSafari, screensaverRaid, screensaverBrawl, screensaverAmbush :: ModeKind

-- What other symmetric (two only-one-moves factions) and asymmetric vs crowd
-- scenarios make sense (e.g., are good for a tutorial or for standalone
-- extreme fun or are impossible as part of a crawl)?
-- sparse melee at night: no, shade ambush in brawl is enough
-- dense melee: no, keeping big party together is a chore and big enemy
--   party is less fun than huge enemy party
-- crowd melee in daylight: no, possible in crawl and at night is more fun
-- sparse ranged at night: no, less fun than dense and if no reaction fire,
--   just a camp fest or firing blindly
-- dense ranged in daylight: no, less fun than at night with flares
-- crowd ranged: no, fish in a barel, less predictable and more fun inside
--   crawl, even without reaction fire

raid = ModeKind  -- mini-crawl
  { msymbol = 'r'
  , mname   = "raid"
  , mfreq   = [("raid", 1), ("campaign scenario", 1)]
  , mroster = rosterRaid
  , mcaves  = cavesRaid
  , mdesc   = "An incredibly advanced typing machine worth 100 gold is buried at the exit of this maze. Be the first to claim it and fund a research team that makes typing accurate and dependable forever."
  }

brawl = ModeKind  -- sparse melee in daylight, with shade for melee ambush
  { msymbol = 'k'
  , mname   = "brawl"
  , mfreq   = [("brawl", 1), ("campaign scenario", 1)]
  , mroster = rosterBrawl
  , mcaves  = cavesBrawl
  , mdesc   = "Your engineering team disagreed over a drink with some gentlemen scientists about premises of a relative completeness theorem and there's only one way to settle that. Remember to keep together so that neither team is tempted to gang upon a solitary disputant."
  }

-- The trajectory tip is important because of tactics of scout looking from
-- behind a bush and others hiding in mist. If no suitable bushes,
-- fire once and flee into mist or behind cover. Then whomever is out of LOS
-- range or inside mist can shoot at the last seen enemy locations,
-- adjusting and according to ounds and incoming missile trajectories.
-- If the scount can't find bushes or glass building to set a lookout,
-- the other team member are more spotters and guardians than snipers
-- and that's their only role, so a small party makes sense.
shootout = ModeKind  -- sparse ranged in daylight
  { msymbol = 's'
  , mname   = "shootout"
  , mfreq   = [("shootout", 1), ("campaign scenario", 1)]
  , mroster = rosterShootout
  , mcaves  = cavesShootout
  , mdesc   = "Whose arguments are most striking and whose ideas fly fastest? Let's scatter up, attack the problems from different angles and find out. To display the trajectory of any soaring entity, point it with the crosshair in aiming mode."
  }

escape = ModeKind  -- asymmetric ranged and stealth race at night
  { msymbol = 'e'
  , mname   = "escape"
  , mfreq   = [("escape", 1), ("campaign scenario", 1)]
  , mroster = rosterEscape
  , mcaves  = cavesEscape
  , mdesc   = "Dwelling into dark matters is dangerous. Avoid the crowd of firebrand disputants, catch any gems of thought, find a way out and bring back a larger team to shed new light on the field."
  }

zoo = ModeKind  -- asymmetric crowd melee at night
  { msymbol = 'b'
  , mname   = "zoo"
  , mfreq   = [("zoo", 1), ("campaign scenario", 1)]
  , mroster = rosterZoo
  , mcaves  = cavesZoo
  , mdesc   = "The heat of the dispute reached the nearby Wonders of Science and Nature exhibition, igniting greenery, nets and cages. Crazed animals must be prevented from ruining precious scentific equipment and setting back the fruitful exchange of ideas."
  }

-- The tactic is to sneak in the dark, highlight enemy with thrown torches
-- (and douse thrown enemy torches with blankets) and only if this fails,
-- actually scout using extended noctovision.
-- With reaction fire, larger team is more fun.
--
-- For now, while we have no shooters with timeout, massive ranged battles
-- without reaction fire don't make sense, because then usually only one hero
-- shoots (and often also scouts) and others just gather ammo.
ambush = ModeKind  -- dense ranged with reaction fire at night
  { msymbol = 'm'
  , mname   = "ambush"
  , mfreq   = [("ambush", 1), ("campaign scenario", 1)]
  , mroster = rosterAmbush
  , mcaves  = cavesAmbush
  , mdesc   = "Prevent highjacking of your ideas at all cost! Be stealthy, be aggresive. Fast execution is what makes or breaks a creative team."
  }

exploration = ModeKind
  { msymbol = 'c'
  , mname   = "crawl (long)"
  , mfreq   = [ ("crawl (long)", 1), ("exploration", 1)
              , ("campaign scenario", 1) ]
  , mroster = rosterExploration
  , mcaves  = cavesExploration
  , mdesc   = "Don't let wanton curiosity, greed and the creeping abstraction madness keep you down there for too long!"
  }

safari = ModeKind  -- easter egg available only via screensaver
  { msymbol = 'f'
  , mname   = "safari"
  , mfreq   = [("safari", 1)]
  , mroster = rosterSafari
  , mcaves  = cavesSafari
  , mdesc   = "\"In this simulation you'll discover the joys of hunting the most exquisite of Earth's flora and fauna, both animal and semi-intelligent. Exit at the bottommost level.\" This is a VR recording recovered from a monster nest debris."
  }

-- * Testing modes

safariSurvival = ModeKind  -- testing scenario
  { msymbol = 'u'
  , mname   = "safari survival"
  , mfreq   = [("safari survival", 1)]
  , mroster = rosterSafariSurvival
  , mcaves  = cavesSafari
  , mdesc   = "In this simulation you'll discover the joys of being hunted among the most exquisite of Earth's flora and fauna, both animal and semi-intelligent."
  }

battle = ModeKind  -- testing scenario
  { msymbol = 'b'
  , mname   = "battle"
  , mfreq   = [("battle", 1)]
  , mroster = rosterBattle
  , mcaves  = cavesBattle
  , mdesc   = "Odds are stacked against those that unleash the horrors of abstraction."
  }

battleSurvival = ModeKind  -- testing scenario
  { msymbol = 'i'
  , mname   = "battle survival"
  , mfreq   = [("battle survival", 1)]
  , mroster = rosterBattleSurvival
  , mcaves  = cavesBattle
  , mdesc   = "Odds are stacked for those that breathe mathematics."
  }

defense = ModeKind  -- testing scenario; perhaps real scenario in the future
  { msymbol = 'e'
  , mname   = "defense"
  , mfreq   = [("defense", 1)]
  , mroster = rosterDefense
  , mcaves  = cavesExploration
  , mdesc   = "Don't let human interlopers defile your abstract secrets and flee unpunished!"
  }

-- * Screensaver modes

screensave :: AutoLeader -> Roster -> Roster
screensave auto r =
  let f [] = []
      f ((player, initial) : rest) =
        (player {fleaderMode = LeaderAI auto}, initial) : rest
  in r {rosterList = f $ rosterList r}

screensaverSafari = safari
  { mname   = "auto-safari"
  , mfreq   = [("starting", 1), ("no confirms", 1)]
  , mroster = -- changing leader by client needed, because of TFollow
              screensave (AutoLeader False True) rosterSafari
  }

screensaverRaid = raid
  { mname   = "auto-raid"
  , mfreq   = [("starting", 1), ("starting JS", 1), ("no confirms", 1)]
  , mroster = screensave (AutoLeader False False) rosterRaid
  }

screensaverBrawl = brawl
  { mname   = "auto-brawl"
  , mfreq   = [("starting", 1), ("starting JS", 1), ("no confirms", 1)]
  , mroster = screensave (AutoLeader False False) rosterBrawl
  }

screensaverAmbush = ambush
  { mname   = "auto-ambush"
  , mfreq   = [("starting", 1), ("starting JS", 1), ("no confirms", 1)]
  , mroster = screensave (AutoLeader False False) rosterAmbush
  }


rosterRaid, rosterBrawl, rosterShootout, rosterEscape, rosterZoo, rosterAmbush, rosterExploration, rosterSafari, rosterSafariSurvival, rosterBattle, rosterBattleSurvival, rosterDefense :: Roster

rosterRaid = Roster
  { rosterList = [ ( playerHero {fhiCondPoly = hiRaid}
                   , [(-2, 1, "hero")] )
                 , ( playerAntiHero { fname = "Indigo Founder"
                                    , fhiCondPoly = hiRaid }
                   , [(-2, 1, "hero")] )
                 , ( playerAnimal  -- starting over escape
                   , [(-2, 2, "animal")] )
                 , (playerHorror, []) ]  -- for summoned monsters
  , rosterEnemy = [ ("Explorer Party", "Animal Kingdom")
                  , ("Indigo Founder", "Animal Kingdom")
                  , ("Explorer Party", "Horror Den")
                  , ("Indigo Founder", "Horror Den") ]
  , rosterAlly = [] }

rosterBrawl = Roster
  { rosterList = [ ( playerHero { fcanEscape = False
                                , fhiCondPoly = hiDweller }
                   , [(-3, 3, "hero")] )
                 , ( playerAntiHero { fname = "Indigo Research"
                                    , fcanEscape = False
                                    , fhiCondPoly = hiDweller }
                   , [(-3, 3, "hero")] )
                 , (playerHorror, []) ]
  , rosterEnemy = [ ("Explorer Party", "Indigo Research")
                  , ("Explorer Party", "Horror Den")
                  , ("Indigo Research", "Horror Den") ]
  , rosterAlly = [] }

-- Exactly one scout gets a sight boost, to help the aggressor, because he uses
-- the scout for initial attack, while camper (on big enough maps)
-- can't guess where the attack would come and so can't position his single
-- scout to counter the stealthy advance.
rosterShootout = Roster
  { rosterList = [ ( playerHero { fcanEscape = False
                                , fhiCondPoly = hiDweller }
                   , [(-5, 1, "scout hero"), (-5, 2, "ranger hero")] )
                 , ( playerAntiHero { fname = "Indigo Research"
                                    , fcanEscape = False
                                    , fhiCondPoly = hiDweller }
                   , [(-5, 1, "scout hero"), (-5, 2, "ranger hero")] )
                 , (playerHorror, []) ]
  , rosterEnemy = [ ("Explorer Party", "Indigo Research")
                  , ("Explorer Party", "Horror Den")
                  , ("Indigo Research", "Horror Den") ]
  , rosterAlly = [] }

rosterEscape = Roster
  { rosterList = [ ( playerHero {fhiCondPoly = hiEscapist}
                   , [(-7, 1, "scout hero"), (-7, 2, "escapist hero")] )
                 , ( playerAntiHero { fname = "Indigo Research"
                                    , fcanEscape = False  -- start on escape
                                    , fhiCondPoly = hiDweller }
                   , [(-7, 1, "scout hero"), (-7, 7, "ambusher hero")] )
                 , (playerHorror, []) ]
  , rosterEnemy = [ ("Explorer Party", "Indigo Research")
                  , ("Explorer Party", "Horror Den")
                  , ("Indigo Research", "Horror Den") ]
  , rosterAlly = [] }

rosterZoo = Roster
  { rosterList = [ ( playerHero { fcanEscape = False
                                , fhiCondPoly = hiDweller }
                   , [(-8, 5, "soldier hero")] )
                 , ( playerAnimal {fneverEmpty = True}
                   , [(-8, 100, "mobile animal")] )
                 , (playerHorror, []) ]  -- for summoned monsters
  , rosterEnemy = [ ("Explorer Party", "Animal Kingdom")
                  , ("Explorer Party", "Horror Den") ]
  , rosterAlly = [] }

rosterAmbush = Roster
  { rosterList = [ ( playerHero { fcanEscape = False
                                , fhiCondPoly = hiDweller }
                   , [(-9, 1, "scout hero"), (-9, 5, "ambusher hero")] )
                 , ( playerAntiHero { fname = "Indigo Research"
                                    , fcanEscape = False
                                    , fhiCondPoly = hiDweller }
                   , [(-9, 1, "scout hero"), (-9, 5, "ambusher hero")] )
                 , (playerHorror, []) ]
  , rosterEnemy = [ ("Explorer Party", "Indigo Research")
                  , ("Explorer Party", "Horror Den")
                  , ("Indigo Research", "Horror Den") ]
  , rosterAlly = [] }

rosterExploration = Roster
  { rosterList = [ ( playerHero
                   , [(-1, 3, "hero")] )
                 , ( playerMonster
                   , [(-4, 1, "scout monster"), (-4, 3, "monster")] )
                 , ( playerAnimal
                   , -- Fun from the start to avoid empty initial level:
                     [ (-1, 1 + d 2, "animal")
                     -- Huge battle at the end:
                     , (-10, 100, "mobile animal") ] ) ]
  , rosterEnemy = [ ("Explorer Party", "Monster Hive")
                  , ("Explorer Party", "Animal Kingdom") ]
  , rosterAlly = [("Monster Hive", "Animal Kingdom")] }

-- No horrors faction needed, because spawned heroes land in civilian faction.
rosterSafari = Roster
  { rosterList = [ ( playerMonsterTourist
                   , [(-4, 15, "monster")] )
                 , ( playerHunamConvict
                   , [(-4, 3, "civilian")] )
                 , ( playerAnimalMagnificent
                   , [(-7, 20, "mobile animal")] )
                 , ( playerAnimalExquisite  -- start on escape
                   , [(-10, 30, "mobile animal")] ) ]
  , rosterEnemy = [ ("Monster Tourist Office", "Hunam Convict Pack")
                  , ( "Monster Tourist Office"
                    , "Animal Magnificent Specimen Variety" )
                  , ( "Monster Tourist Office"
                    , "Animal Exquisite Herds and Packs" ) ]
  , rosterAlly = [ ( "Animal Magnificent Specimen Variety"
                   , "Animal Exquisite Herds and Packs" )
                 , ( "Animal Magnificent Specimen Variety"
                   , "Hunam Convict Pack" )
                 , ( "Hunam Convict Pack"
                   , "Animal Exquisite Herds and Packs" ) ] }

rosterSafariSurvival = rosterSafari
  { rosterList = [ ( playerMonsterTourist
                       { fleaderMode = LeaderAI $ AutoLeader True True
                       , fhasUI = False }
                   , [(-4, 15, "monster")] )
                 , ( playerHunamConvict
                   , [(-4, 3, "civilian")] )
                 , ( playerAnimalMagnificent
                     { fleaderMode = LeaderUI $ AutoLeader True False
                     , fhasUI = True }
                   , [(-7, 20, "mobile animal")] )
                 , ( playerAnimalExquisite
                   , [(-10, 30, "mobile animal")] ) ] }

rosterBattle = Roster
  { rosterList = [ ( playerHero { fcanEscape = False
                                , fhiCondPoly = hiDweller }
                   , [(-5, 5, "soldier hero")] )
                 , ( playerMonster {fneverEmpty = True}
                   , [(-5, 35, "mobile monster")] )
                 , ( playerAnimal {fneverEmpty = True}
                   , [(-5, 30, "mobile animal")] ) ]
  , rosterEnemy = [ ("Explorer Party", "Monster Hive")
                  , ("Explorer Party", "Animal Kingdom") ]
  , rosterAlly = [("Monster Hive", "Animal Kingdom")] }

rosterBattleSurvival = rosterBattle
  { rosterList = [ ( playerHero { fcanEscape = False
                                , fhiCondPoly = hiDweller
                                , fleaderMode =
                                    LeaderAI $ AutoLeader False False
                                , fhasUI = False }
                   , [(-5, 5, "soldier hero")] )
                 , ( playerMonster {fneverEmpty = True}
                   , [(-5, 35, "mobile monster")] )
                 , ( playerAnimal { fneverEmpty = True
                                  , fhasUI = True }
                   , [(-5, 30, "mobile animal")] ) ] }

rosterDefense = rosterExploration
  { rosterList = [ ( playerAntiHero
                   , [(-1, 3, "hero")] )
                 , ( playerAntiMonster
                   , [(-4, 1, "scout monster"), (-4, 3, "monster")] )
                 , ( playerAnimal
                   , [ (-1, 1 + d 2, "animal")
                     , (-10, 100, "mobile animal") ] ) ] }

cavesRaid, cavesBrawl, cavesShootout, cavesEscape, cavesZoo, cavesAmbush, cavesExploration, cavesSafari, cavesBattle :: Caves

cavesRaid = IM.fromList [(-2, "caveRaid")]

cavesBrawl = IM.fromList [(-3, "caveBrawl")]

cavesShootout = IM.fromList [(-5, "caveShootout")]

cavesEscape = IM.fromList [(-7, "caveEscape")]

cavesZoo = IM.fromList [(-8, "caveZoo")]

cavesAmbush = IM.fromList [(-9, "caveAmbush")]

cavesExploration = IM.fromList $
  [ (-1, "shallow random 1")
  , (-2, "caveRogue")
  , (-3, "caveEmpty") ]
  ++ zip [-4, -5..(-9)] (repeat "default random")
  ++ [(-10, "caveNoise")]

cavesSafari = IM.fromList [ (-4, "caveSafari1")
                          , (-7, "caveSafari2")
                          , (-10, "caveSafari3") ]

cavesBattle = IM.fromList [(-5, "caveBattle")]
