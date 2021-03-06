Playing LambdaHack
==================

LambdaHack is a small dungeon crawler illustrating the roguelike game engine
of the same name. Playing the game involves exploring spooky dungeons,
alone or in a party of fearless explorers, setting up ambushes
for unwary creatures, hiding in shadows, bumping into unspeakable horrors,
hidden passages and gorgeous magical treasure and making creative use
of it all. The madness-inspiring abominations that multiply in the depths
perform the same feats, due to their aberrant, abstract hyper-intelligence,
while tirelessly chasing the elusive heroes by sight, sound and smell.

Once the few basic command keys and on-screen symbols are learned,
mastery and enjoyment of the game is the matter of tactical skill
and literary imagination. To be honest, a lot of imagination is required
for this rudimentary set of scenarios, even though they are playable
and winnable. Contributions are welcome.


Heroes
------

The heroes are marked on the map with symbols `@` and `1` through `9`.
Their goal is to explore the dungeon, battle the horrors within,
gather as much gold and gems as possible, and escape to tell the tale.

The currently chosen party leader is highlighted on the map
and his attributes are displayed at the bottommost status line,
which in its most complex form looks as follows.

    *@12        4d1+5% Calm: 20/60 HP: 33/50 Target: basilisk  [**__]

The line starts with the list of party members, with the leader highlighed.
Most commands involve only the leader, including movement with keyboard's
keypad or `LMB` (left mouse button). If more heroes are selected, e.g.,
by clicking on the list with `RMB` (right mouse button), they run together
whenever `:` or `RMB` over map area is pressed.

Next on the status line is the damage of the highest damage dice weapon
the leader can use, then his current and maximum Calm (morale, composure,
focus, attentiveness), then his current and maximum HP (hit points, health).
At the end, the personal target of the leader is described, in this case
a basilisk monster, with hit points drawn as a bar.

Instead of a monster, the target area may describe a recently spotted
item on the floor or an item in equipment selected for further action or,
if none are available, just display the current leader name. Weapon damage
and other item stats are displayed using the dice notation `XdY`,
which means `X` rolls of `Y`-sided dice. A variant denoted `XdlY`
is additionally scaled by the level depth in proportion to the maximal
dungeon depth. Section [Monsters](#monsters) below describes combat
resolution in detail.

The second, upper status line describes the current level in relation
to the party.

    5  Lofty hall   [33% seen] X-hair: exact spot (71,12)  p15 l10

First comes the depth of the current level and its name.
Then the percentage of its explorable tiles already seen by the heroes.
The `X-hair` (aiming crosshair) is the common focus of the whole party,
marked on the map and manipulated with mouse or movement keys in aiming mode.
At the end of the status line comes the length of the shortest
path from the leader to the x-hair position and the straight-line distance
between the two points.


Dungeon
-------

The dungeon of any particular scenario may consist of one or many
levels and each level consists of a large number of tiles.
The game world is persistent, i.e., every time the player visits a level
during a single game, its layout is the same.
The basic tile kinds are as follows.

    dungeon terrain type                   on-screen symbol
    wall (horizontal and vertical)         - and |
    tree or rock or man-made pillar        O
    rubble                                 ;
    bush                                   &
    closed door                            +
    open door (horizontal and vertical)    | and -
    corridor, smoke or fog                 #
    ground                                 .
    stairs or exit up                      <
    stairs or exit down                    >
    bedrock                                blank

So, for example, the following map shows a room with a closed door
connected by a corridor with a room with an open door, a pillar,
staircase down and rubble that obscures one of the corners.

    ----       ----
    |..|       |..;;
    |..+#######-.O.>;|
    |..|       |.....|
    ----       -------


Basic Commands
--------------

This section is a copy of the first two screens of in-game help,
automatically generated based on a game's keybinding content and
on overrides in the player's config file.

You walk throughout a level with mouse or numeric keypad (left diagram below)
or its compact laptop replacement (middle) or the Vi text editor keys (right,
enabled in config.ui.ini). Run, until disturbed, by adding Shift or Control.
Go-to with LMB (left mouse button). Run collectively with RMB.

               7 8 9          7 8 9          y k u
                \|/            \|/            \|/
               4-5-6          u-i-o          h-.-l
                /|\            /|\            /|\
               1 2 3          j k l          b j n

In aiming mode, the same keys (and mouse) move the x-hair (aiming crosshair).
Press 'KP_5' ('5' on keypad, if present) to wait, bracing for impact,
which reduces any damage taken and prevents displacing by foes. Press
'C-KP_5' (the same key with Control) to wait 0.1 of a turn, without bracing.
You displace enemies by running into them with Shift/Control or RMB. Search,
open, descend and attack by bumping into walls, doors, stairs and enemies.
The best item to attack with is automatically chosen from among
weapons in your personal equipment and your unwounded organs.

The following commands, joined with the basic set above, let you accomplish
anything in the game, though not necessarily with the fewest keystrokes.
You can also play the game exclusively with a mouse, or both mouse and
keyboard. See the ending in-game help screens for mouse commands.
Lastly, you can select a command with arrows or mouse directly from a help
screen and execute it on the spot.

    keys         command
    g or ,       grab item(s)
    c            close door
    P            manage item pack of the leader
    KP_* or !    cycle x-hair among enemies
    +            swerve the aiming line
    ESC          cancel aiming/open Main Menu
    RET or INS   accept target/open Help
    SPACE        clear messages/display history
    S-TAB        cycle among all party members
    =            select (or deselect) party member


Advanced Commands
-----------------

For ranged attacks, setting the aiming crosshair beforehand is not mandatory,
because x-hair is set automatically as soon as a monster comes into view
and can still be adjusted for as long as the missile to fling is not chosen.
However, sometimes you want to examine the level map tile by tile
or assign persistent personal targets to party members.
The latter is essential in the rare cases when your henchmen
(non-leader characters) can move autonomously or fire opportunistically
(via innate skills or rare equipment). Also, if your henchman is adjacent
to more than one enemy, setting his target is makes him melee a particular foe.

You can enter the detailed aiming mode with the `*` keypad key that selects
enemies or the `/` keypad key that cycles among items on the floor
and marks a tile underneath an item. You can move x-hair with direction keys
and assign a personal target to the leader with `RET` key (Return, Enter).
The details of the shared x-hair position and of the personal target
are described in the status lines at the bottom of the screen,
as explained in section [Heroes](#heroes) above.

Commands for saving and exiting the current game, starting a new game,
setting options and changing henchmen tactics, etc.,
are listed in the Main Menu, brought up by the `ESC` key.
Game difficulty setting affects hitpoints at birth for any actors
of any UI-using faction. For a person new to roguelikes, the `raid` scenario
offers a gentle introduction. The subsequent game scenarios gradually
introduce squad combat, stealth, opportunity fire, asymmetric battles and more.


Monsters
--------

Heroes are not alone in the dungeon. Monstrosities, natural
and out of this world, roam the dark caves and crawl from damp holes
day and night. While heroes pay attention to all other party members
and take care to move one at a time, monsters don't care about each other
and all move at once, sometimes brutally colliding by accident.

When the hero bumps into a monster or a monster attacks the hero,
melee combat occurs. Heroes and monsters running into one another
(with the `Shift` or `Control` key) do not inflict damage, but change places.
This gives the opponent a free blow, but can improve the tactical situation
or aid escape. In some circumstances actors are immune to the displacing,
e.g., when both parties form a continuous front-line.

In melee combat, the best equipped weapon (or the best fighting organ)
of each opponent is taken into account for determining the damage
and any extra effects of the blow. If a recharged weapon with an effect
is in the equipment, it is preferred for combat. Otherwise combat
involves the weapon with the highest raw damage dice (the same as displayed
at bottommost status line).

To determine the damage dealt, the outcome of the weapon's damage dice roll
is multiplied by a percentage bonus. The bonus is calculated by taking
the damage bonus (summed from the equipped items of the attacker,
capped at 200%) minus the melee armor modifier of the defender
(capped at 200% as well), with the outcome bounded between -99% and 99%,
which means that at least 1% of damage always gets through
and the damage is never higher than twice the dice roll.
The current leader's melee bonus, armor modifier and other detailed
stats can be viewed via the `#` command.

In ranged combat, the missile is assumed to be attacking the defender
in melee, using itself as the weapon, with the usual dice and damage bonus.
This time, the ranged armor stat of the defender is taken into account
and, additionally, the speed of the missile (based on shape and weight)
figures in the calculation. You may propel any item from your inventory
(by default you are offered only the appropriate items; press `?`to cycle
item menu modes). Only items of a few kinds inflict any damage, but some
have other effects, beneficial, detrimental or mixed.

In-game detailed item descriptions contain melee and ranged damage estimates.
They do not take into account damage from effects and, if bonuses are not
known, they are guessed based on average bonuses for that kind of item.
The displayed figures are rounded, but the game internally keeps track
of minute fractions of HP.

Whenever the monster's or hero's hit points reach zero, the combatant dies.
When the last hero dies, the scenario ends in defeat.


On Winning and Dying
--------------------

You win the scenario if you escape the dungeon alive or, in scenarios with
no exit locations, if you eliminate all opposition. In the former case,
your score is based predominantly on the gold and precious gems you've
plundered. In the latter case, your score is most affected by the number
of turns you spent overcoming your foes (the quicker the victory, the better;
the slower the demise, the better). Bonus points, based on the number
of heroes lost, are awarded only if you win.

When all your heroes fall, you are going to invariably see a new foolhardy
party of adventurers clamoring to be led into the dungeon. They start
their conquest from a new entrance, with no experience and no equipment,
and new, undaunted enemies bar their way. Lead the new hopeful explorers
with wisdom and fortitude!
