![PokeSurvive Logo](PokeSurvive%20Logo.png)

# PokeSurvive

**PokeSurvive v1.0** is a survival/roguelike gameplay overhaul for classic Pokémon, supporting **Pokémon Red** and **Pokémon Gold** through their respective recompilation projects.

PokeSurvive transforms a normal Pokémon playthrough into a much more unpredictable journey built around survival, resource management, randomized worlds, Pokémon personalities, camping, exploration events, and permanent consequences.

Rather than simply shuffling Pokémon encounters, PokeSurvive is designed to make each seed feel like its own strange alternate version of the Pokémon world, where the journey between Gyms can matter just as much as the battles themselves.

## 🔴 Pokémon Red + 🟡 Pokémon Gold

Beginning with **PokeSurvive v1.0.0**, Red and Gold are distributed together as a **single unified mod**.

You do not need separate PokeSurvive installations.

Install PokeSurvive once and the mod automatically loads the appropriate implementation for the Pokémon game you're playing.

Both games share the core PokeSurvive experience, while certain systems remain game-specific where the underlying games provide meaningfully different mechanics.

### 🔴 Pokémon Red

The original PokeSurvive experience, built for **Gen1Recomp**.

Red includes the complete core survival, Personality, Adventure Event, Camping, Morale, randomizer, and run-management experience.

### 🟡 Pokémon Gold

Gold brings the PokeSurvive experience into Generation II and adds systems designed around Gold's expanded mechanics, including:

- Step-driven Game Time
- Day/night integration
- Randomized breeding and Eggs
- Randomized Gift Eggs
- Friendship integration
- Pokégear and Mail-based Emergent Encounters
- Generation II Survival Tools
- Held-item trade evolution alternatives

## 🌲 Core Features

### Survival

- Sustenance and Energy survival meters
- Morale ranging from positive values into negative values
- Temporary Mood system
- Passive positive-Morale drift toward neutral
- Camping and camp activities
- Food and supply management
- Survival Tools
- Depleted collapse after prolonged starvation/exhaustion
- Optional Permadeath

### Pokémon Personalities

Every eligible Pokémon can develop its own Personality:

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

Personalities influence Pokémon behavior throughout the journey.

They can affect:

- Checkups
- Adventure Events
- Camping
- Interactions with other party members
- Flavor events
- Mechanical outcomes

This gives individual Pokémon an identity beyond their species and battle statistics.

### Pokémon Checkups

**CHECKUP** allows you to interact directly with individual Pokémon from the party menu.

A Pokémon's response depends on its Personality, and interactions can produce different dialogue, Morale changes, and occasional additional effects.

Pokémon may be affectionate, stubborn, mischievous, curious, lazy, aggressive, or simply uninterested in whatever you're trying to do.

Eggs do not participate in Checkups until they hatch.

### Adventure Events

Exploration can trigger contextual events involving your Pokémon.

Events can react to environments including:

- Routes
- Forests
- Caves
- Towns and cities
- Indoor locations
- Surfing
- Other special situations

Adventure Events may involve a single Pokémon or interactions between multiple party members.

Personality, environment, survival condition, party composition, and other circumstances can influence what happens.

Outcomes can be beneficial, harmful, or purely flavorful and may affect:

- Sustenance
- Energy
- Morale
- Pokémon HP or status
- Supplies
- Money
- Items
- Other aspects of the run

### Camping

Camping provides a way to rest and interact with the survival system outside normal Pokémon Centers.

Depending on available options and equipment, players can perform activities such as resting, foraging, cooking, training, spending time with Pokémon, tending to injuries, or preparing for the journey ahead.

Camping can also trigger:

- Positive events
- Negative events
- Personality-specific events
- Multi-Pokémon interactions
- Survival-related events
- Flavor encounters

Camping restores Energy but consumes time and resources, making when and how you camp part of the survival loop.

### ❤️ Morale

Morale represents the overall emotional state of the journey.

**0 Morale is neutral**, not a failure state.

Morale can rise through positive experiences and fall into negative values following genuine setbacks.

Positive Morale can be earned through activities such as:

- Pokémon interactions
- Camping
- Adventure Events
- Trainer victories
- Other meaningful PokeSurvive systems

Wild Pokémon victories do **not** provide Morale, preventing low-level encounters from becoming an infinite Morale source.

Positive Morale gradually drifts back toward 0 as you travel. Very high values fade more quickly, while lower positive Morale lasts longer.

Passive drift stops at 0 and cannot make Morale negative.

## 🧭 SURVIVE Interface

Selecting **SURVIVE** from the pause menu opens a compact dashboard displaying:

- Sustenance
- Energy
- Morale
- Current Mood

Quick access is provided to:

- MENU
- CAMP
- SUPPLIES

The full PokeSurvive menu provides access to additional information and systems including Personalities, Mood effects, survival information, and the Journal.

## 🎲 Seeded Randomized Worlds

PokeSurvive uses a run seed to create randomized worlds that remain internally consistent throughout a playthrough.

Depending on the selected run settings, a seed can determine:

- Wild Pokémon
- Starter Pokémon
- Pokémon types
- Dual-type combinations
- Type-based Pokémon colors
- Stats and stat distributions
- Learnsets
- Move progression
- TM/HM compatibility
- Individual Trainer parties
- Gym teams and specialties
- Major Trainer rosters
- Gift Pokémon
- Breeding outcomes in Gold
- Other randomized gameplay systems

Trainer Pokémon are randomized individually rather than globally replacing every instance of a vanilla species.

The active seed can be viewed from the in-game Journal, allowing interesting worlds to be shared and replayed.

## 🎨 Randomized Pokémon

PokeSurvive's randomizer goes substantially beyond replacing one species with another.

Pokémon can receive:

- Randomized species
- One or two randomized types
- Type-based color palettes
- Randomized stat distributions
- Type-aware randomized learnsets
- Unusual coverage moves
- Randomized TM/HM compatibility

Evolution families preserve logical progression rather than completely rerolling a Pokémon's identity at each stage.

Pokémon can gain a secondary type through evolution while retaining continuity with their earlier form.

Starter Pokémon receive additional protection against unusable early-game movesets.

HM moves are excluded from naturally generated level-up learnsets.

## ⚔️ Randomized Trainers

Trainer parties can be randomized independently.

This includes:

- Ordinary Trainers
- Rivals
- Gym Trainers
- Gym Leaders
- Other major battles

Randomized parties preserve appropriate levels and party sizes while allowing each Trainer to receive an independently generated team.

Important tutorial or scripted battles may receive special handling when necessary.

## 🔄 Trade-Free Evolutions

PokeSurvive removes link-trading roadblocks for Pokémon evolution.

Pokémon that normally evolve through a basic trade can use PokeSurvive's **Level 40 evolution alternative**.

In Pokémon Gold, Pokémon that normally require being traded while holding a particular evolution item can evolve at **Level 40 or higher while holding that item**.

The required held item is consumed when the evolution succeeds.

Everstone continues to prevent evolution normally.

## 🟡 Pokémon Gold Features

Gold contains several additional systems built specifically around Generation II.

### 🕐 Step-Driven Game Time

With **Game Time** enabled, Gold's clock progresses through exploration rather than being tied entirely to real-world time.

- 10 steps = 1 in-game minute
- 600 steps = 1 in-game hour
- Camping advances time by 8 hours
- Gold's normal morning, day, and night systems respond to the resulting time

Traveling and resting can therefore determine what time of day you reach the next area.

### 🥚 Expanded Breeding Randomizer

Pokémon breeding participates in PokeSurvive's randomizer.

Breeding families remain compatible with their normal families, but offspring can inherit and recombine characteristics from their parents.

Depending on the parents and run seed, offspring can:

- Be either compatible parent species
- Inherit one or two types drawn from their parents
- Produce new combinations of inherited types
- Receive an individualized palette
- Generate a type-aware randomized learnset
- Receive randomized TM/HM compatibility
- Inherit appropriate moves

This allows offspring to be meaningfully different from both their parents and other members of the same species.

Egg identities remain hidden from Personality, Checkup, Camping, and Adventure Event systems until they hatch.

### 🎁 Randomized Gift Eggs

Scripted NPC Eggs participate in the randomizer independently.

After hatching, a Gift Egg Pokémon can have its own:

- Species
- Typing
- Palette
- Stats
- Stat distribution
- Learnset
- TM/HM compatibility
- Personality

A Pokémon encountered in the wild can therefore be very different from the same species obtained through a special Egg.

### ✉️ Emergent Encounters

Gold's **Emergent Encounters** create optional miniature journeys while exploring Johto.

A traveler may contact you through the **Pokégear**, or one of your Pokémon may discover a strange piece of **Mail**.

The message provides a destination where someone wants to meet you.

Emergent Encounters can:

- Send you several areas away
- Expire if you take too long
- Dynamically place a traveler at the destination
- Feature different traveler archetypes
- Use different dialogue and situations
- Give Pokémon actual readable held Mail
- Use multiple Mail stationery designs
- Provide randomized rewards

Possible rewards include:

- Money
- Morale
- Valuables
- Evolution items
- Vitamins
- Held items
- Battle supplies
- Other useful finds

There is deliberately no quest marker.

Remember the destination, decide whether the detour is worth making, and reach the traveler before the opportunity disappears.

### 🧰 Survival Tools

Gold's Supplies system includes permanent Survival Tools that provide alternatives for important field abilities.

Tools correspond to:

- Cut
- Fly
- Surf
- Strength
- Flash
- Whirlpool
- Waterfall

These unlock alongside their corresponding HM/story progression.

Survival Tools do not bypass the normal progression requirements for those abilities.

## 📓 Journal

The PokeSurvive Journal records information about the current journey, including the active run seed and notable run information.

Seeds can be shared with other players to reproduce interesting randomized worlds.

## Installation

Download the latest **PokeSurvive unified release** and install the `pokesurvive` mod folder using the mod-loading system supported by the recompilation project you're playing.

The same PokeSurvive package supports both Pokémon Red and Pokémon Gold.

If upgrading from one of the older separate Red or Gold versions of PokeSurvive, a clean replacement of the old PokeSurvive installation is recommended if your launcher does not automatically replace it.

PokeSurvive does **not** include Pokémon ROMs or copyrighted game data.

Users must provide any legally required game files separately.

## Starting a Run

Start a **New Game** and proceed through the opening sequence.

Before beginning the adventure, PokeSurvive presents its run configuration screen.

Available options depend on the game and current version and can include:

- Survival Mode
- Game Time
- Permadeath
- Random Pokémon
- Random Types
- Random Stats
- Random Moves
- Random Trainers

Run options are locked once the adventure begins.

The in-game **SURVIVE** interface provides access to survival information, Camping, Supplies, Personalities, the Journal, and other PokeSurvive systems.

## Compatibility & Known Limitations

PokeSurvive is a substantial gameplay overhaul and modifies many parts of the underlying game.

Compatibility with arbitrary third-party mods cannot be guaranteed.

If you encounter a problem while using multiple mods, first try reproducing the issue with PokeSurvive enabled by itself. If the issue disappears, it is likely a mod compatibility conflict rather than a PokeSurvive-specific bug.

Because PokeSurvive's randomizer can generate combinations that would never occur during a normal Pokémon playthrough, testing every possible seed, Pokémon, Trainer, event, and mechanical interaction is effectively impossible.

Bug reports and unusual edge cases are always welcome.

Save compatibility across major future versions is not guaranteed.

## Important Notes

- Randomized Trainer teams preserve appropriate party sizes and levels.
- Trainer Pokémon are randomized individually.
- Important scripted and tutorial battles may receive special handling.
- Evolution families preserve logical randomized progression.
- Pokémon can gain a secondary type through evolution without completely rerolling their established identity.
- Starter Pokémon are protected against unusable early-game movesets.
- HM moves are excluded from naturally generated level-up learnsets.
- Gold Eggs remain Eggs for PokeSurvive interaction systems until they hatch.
- Optional Permadeath can end a run if the player's party is lost.
- Some systems intentionally differ between Red and Gold where the underlying games provide different mechanics.
- Emergent Encounters are Gold-only because they are built around the Pokégear and Mail systems.

## 🐛 Bug Reports

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

Randomizer bugs are especially helpful when accompanied by the **run seed** and the Pokémon, Trainer, Egg, or event involved.

If you're running additional mods, please mention them in the report.

## Development & Support

**PokeSurvive v1.0.0** represents the first complete unified release of PokeSurvive.

Development does not end at 1.0. Bugs will continue to be fixed, balance can continue to be refined, and future improvements may still be added.

The focus after 1.0 is stability, polish, compatibility, and responding to community feedback rather than treating the project as an unfinished beta.

Thanks to everyone who has tested PokeSurvive, reported bugs, suggested ideas, shared runs, created videos, or simply played the mod.

Have fun surviving!
