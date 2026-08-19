![PokeSurvive Logo](PokeSurvive%20Logo.png)

# PokeSurvive

PokeSurvive is a survival/roguelike gameplay overhaul for classic Pokémon, currently supporting **Pokémon Red** and **Pokémon Gold** through their respective recompilation projects.

It transforms a normal Pokémon playthrough into a much more unpredictable journey built around survival, resource management, randomized runs, Pokémon personalities, camping, exploration events, and permanent consequences.

Rather than simply shuffling Pokémon encounters, PokeSurvive is designed to make each seed feel like its own strange alternate version of the Pokémon world.

## Supported Games

### 🔴 Pokémon Red
The original PokeSurvive experience, built for **Gen1Recomp**.

### 🟡 Pokémon Gold
**Now available in Beta!**

Pokémon Gold brings the core PokeSurvive experience into Generation II while expanding it with new systems including step-driven game time, breeding randomization, randomized eggs, and mechanics built around Gold's day/night cycle.

Features and implementation may differ slightly between games as development continues.

## Current Features

- Sustenance and Energy survival meters
- Morale and temporary Mood system
- Pokémon Personalities with unique behavioral traits
- Pokémon Checkups with personality-based interactions
- Context-aware Adventure Events involving individual Pokémon or multiple party members
- Location-aware events for routes, forests, caves, towns, buildings, surfing, and other environments
- Camping with positive, negative, personality-driven, and flavor events
- Survival supplies and food management
- Depleted collapse after prolonged starvation/exhaustion
- Optional permadeath
- Seeded randomized Pokémon
- Randomized starters and wild encounters
- Individually randomized trainer parties
- Randomized Gym Leader and major trainer teams
- Randomized Pokémon types and dual-type combinations
- Type-based Pokémon color palettes
- Randomized stats and stat distributions
- Randomized learnsets and move progression
- Type-aware move generation with occasional unusual coverage
- Randomized TM/HM compatibility
- Personality and Mood effects that influence combat and exploration
- Pokémon portrait presentation during Checkups and Adventure Events
- Run seed tracking for sharing and replaying randomized worlds

## 🟡 Pokémon Gold Beta

The Pokémon Gold version of PokeSurvive brings the survival framework established in Pokémon Red into Generation II while taking advantage of Gold's expanded mechanics.

Alongside the core survival and randomizer systems, Gold introduces several major additions unique to this version.

### 🧠 Pokémon Personalities & Checkups

Every hatched Pokémon can develop its own personality, influencing how it behaves during your journey.

Personalities include traits such as:

- Loyal
- Bold
- Inquisitive
- Lazy
- Playful
- Timid
- Stubborn
- Aggressive
- Mischievous
- Brainiac
- Performer
- Gentle

These personalities can affect Pokémon behavior, Checkup interactions, Camping, and Adventure Events.

From the party menu, **CHECKUP** allows you to spend a little time interacting directly with a Pokémon. Their reactions depend on their personality, giving party members more identity beyond their battle statistics.

Eggs do not receive personalities or participate in Checkups or Pokémon Adventure Events until they hatch.

### 🌲 Adventure Events

Exploration can trigger contextual events involving your Pokémon.

Events can react to where you currently are, including:

- Routes
- Forests
- Caves
- Towns and cities
- Indoor locations
- Surfing
- Other environmental situations

Events may involve a single Pokémon or interactions between multiple members of your party.

A Pokémon's personality can influence what happens, turning the party into active participants in the journey rather than creatures that only appear during battle.

Adventure Events can have beneficial, harmful, or purely flavorful outcomes.

### 🕐 Step-Driven Game Time

With **Game Time** enabled, Gold's clock progresses as you explore rather than being tied entirely to real-world time.

- Walking advances the in-game clock
- 10 steps = 1 in-game minute
- 600 steps = 1 in-game hour
- Camping advances time by 8 hours
- Gold's normal morning, day, and night systems continue to respond to the resulting game time

This allows the day/night cycle to become part of the survival and exploration loop. Traveling, resting, and camping can determine what time of day you reach the next area.

### 🥚 Expanded Breeding Randomizer

Pokémon breeding has been integrated into PokeSurvive's randomizer.

Breeding families remain compatible with their normal Pokémon families, but offspring can inherit and recombine traits from their parents in unusual ways.

Depending on the parents and seed, offspring can:

- Be either compatible parent species
- Inherit one or two types drawn from their parents
- Produce new combinations of those inherited types
- Receive an individualized palette matching their resulting typing
- Generate a type-aware randomized learnset
- Receive randomized TM/HM compatibility appropriate to their new typing

This means two Pokémon can potentially produce offspring that are meaningfully different from both their parents and from other members of the same species.

The contents of an egg remain hidden from PokeSurvive's personality, Checkup, Camping, and Adventure Event systems until it actually hatches.

### 🎁 Randomized Gift Eggs

Pokémon received through scripted NPC eggs participate in the randomizer as well.

Gift eggs can contain their own independently randomized Pokémon rather than simply reproducing the randomized version of that species found elsewhere in the world.

After hatching, these Pokémon can have their own:

- Species
- Typing
- Palette
- Stats and stat distribution
- Type-aware randomized learnset
- TM/HM compatibility
- Personality

A species encountered in the wild may therefore be very different from one hatched from a special egg.

Until an egg hatches, its randomized identity remains concealed from PokeSurvive's Pokémon interaction systems.

## 🌎 Seeded Randomized Worlds

PokeSurvive uses a run seed to keep randomized worlds consistent while still allowing enormous variation between playthroughs.

A seed can determine things such as:

- Pokémon encountered in the wild
- Pokémon types
- Pokémon stats
- Pokémon colors
- Learnsets
- Trainer teams
- Gym specialties
- Major battle rosters
- Breeding outcomes
- Gift Pokémon
- Other randomized gameplay systems

The active seed can be viewed from the in-game Journal, allowing players to share interesting worlds with other players.

## Beta Status

PokeSurvive is currently in **BETA**.

Expect bugs, balance issues, strange edge cases, awkward event combinations, and systems that will continue to evolve.

Because the randomizer can create combinations that would never exist during a normal Pokémon playthrough, testing every possible interaction is effectively impossible. Community bug reports are extremely valuable.

New runs are strongly recommended when moving between major beta versions. Do not assume saves from older alpha, development, or beta builds will remain fully compatible.

## Installation

Download the PokeSurvive version intended for the Pokémon game you are playing and install the `pokesurvive` mod folder using the mod-loading system supported by that game's recompilation project.

PokeSurvive does **not** include Pokémon ROMs or copyrighted game data.

Users must provide any legally required game files separately.

## Starting a Run

Start a **New Game** and proceed through the game's opening sequence.

Before beginning the adventure, PokeSurvive presents its run configuration screen. Available options depend on the game and current PokeSurvive version, but can include:

- Survival Mode
- Game Time
- Permadeath
- Random Pokémon
- Random Types
- Random Stats
- Random Moves
- Random Trainers

Run options are locked once the adventure begins.

The in-game **SURVIVE** menu provides access to PokeSurvive systems such as survival status, supplies, personalities, camping, and the Journal.

## Important Beta Notes

- Randomized trainer teams preserve appropriate party sizes and levels.
- Trainer Pokémon are randomized individually rather than globally replacing every instance of a particular vanilla Pokémon.
- Important scripted and tutorial battles may receive special handling.
- Randomized evolution families preserve logical progression while allowing typing to evolve in controlled ways.
- Pokémon can gain a secondary type through evolution without completely rerolling their established identity.
- Starter Pokémon are protected from receiving unusable early-game movesets.
- HM moves are excluded from naturally generated level-up learnsets.
- Gold's eggs remain eggs for PokeSurvive interaction systems until they hatch.
- Optional permadeath can end a run if the player's party is lost.
- Some systems differ between the Red and Gold versions while features are developed and audited for each game.

## Bug Reports

When reporting a problem, please include:

1. PokeSurvive version
2. Pokémon game (Red or Gold)
3. Recomp version/build
4. Whether the save began on the current PokeSurvive version
5. Run seed, if using randomized features
6. Enabled run settings
7. What you expected to happen
8. What actually happened
9. Steps to reproduce, if known
10. Screenshots/video and logs when available

Randomizer bugs are especially helpful when accompanied by the **run seed** and the Pokémon, trainer, egg, or event involved.

## Development

PokeSurvive is in active **beta development**.

Pokémon Red established the original survival framework, while Pokémon Gold expands those ideas into Generation II mechanics such as breeding, eggs, Pokémon personalities, contextual party interactions, and a dynamic day/night cycle.

Future development will continue improving balance, survival mechanics, personalities, events, randomization, game-specific systems, and compatibility across supported Pokémon recompilation projects.
