![PokeSurvive Logo](PokeSurvive%20Logo.png)

# PokeSurvive

**PokeSurvive v1.1.0.1** is a survival and roguelike gameplay overhaul for classic Pokémon, supporting **Pokémon Red, Pokémon Gold, and Pokémon Crystal** through Gen1Recomp.

PokeSurvive transforms a normal Pokémon adventure into an unpredictable journey built around survival, resource management, randomized worlds, Pokémon personalities, camping, exploration events, and permanent consequences.

Rather than simply shuffling encounters, PokeSurvive is designed to make each seed feel like its own strange alternate Pokémon world, where the journey between Gyms can matter just as much as the battles themselves.

## 🔴 Red • 🟡 Gold • 💎 Crystal

PokeSurvive is distributed as **one unified mod**.

Install it once and PokeSurvive automatically loads the appropriate implementation for:

- Pokémon Red
- Pokémon Gold
- Pokémon Crystal

All three games share the core PokeSurvive experience, while Generation II includes additional mechanics built around Gold and Crystal's expanded systems.

## 🌲 Survival

Manage the journey itself, not just your Pokémon.

- **Sustenance** and **Energy** survival meters
- **Morale** that rises and falls with your experiences
- Temporary **Moods** with gameplay effects
- Camping, cooking, foraging, training, and other activities
- Food, supplies, and permanent Survival Tools
- Adventure Events while exploring
- Optional **Permadeath**
- Collapse from prolonged starvation and exhaustion

Camping restores Energy but consumes time and resources, making when and where you stop part of the survival loop.

## 🐾 Pokémon Personalities

Pokémon can develop individual Personalities such as:

**Loyal • Bold • Inquisitive • Lazy • Playful • Timid • Stubborn • Aggressive • Mischievous • Brainiac • Performer • Gentle**

Personality affects how Pokémon behave during:

- Checkups
- Camping
- Adventure Events
- Party interactions
- Flavor events
- Certain mechanical outcomes

Use **CHECKUP** from the party menu to interact directly with your Pokémon and see how they respond.

## 🗺️ Adventure Events

Exploration can trigger contextual events involving your Pokémon and surroundings.

Events can react to routes, forests, caves, towns, indoor locations, Surfing, party composition, Personality, survival conditions, and more.

Outcomes may affect:

- Sustenance and Energy
- Morale
- Pokémon HP or status
- Money and items
- Supplies
- Relationships between party members

Some events are helpful. Some are dangerous. Others just let your Pokémon be weird little guys.

## 🎲 Randomized Worlds

Every run can use a seed to create a consistent alternate Pokémon world.

Optional randomization includes:

- Wild Pokémon
- Starters
- Pokémon types
- Type-based sprite colors
- Stats and stat distributions
- Learnsets
- TM/HM compatibility
- Trainer parties
- Gym teams
- Gift Pokémon
- Gen II breeding and Eggs

Trainer Pokémon are generated individually rather than globally replacing every instance of a species.

Evolution families maintain logical progression, and evolved Pokémon can develop new secondary typings without completely losing their established identity.

### Special Pokémon Stay Special

Major unique and story Pokémon are excluded from ordinary wild randomizer pools.

You won't casually find Suicune on an early route before Crystal's Suicune storyline, for example.

Their intended encounters remain intact, but their **typing, stats, moves, and colors can still be randomized**, making those encounters unique to each run.

## ☠️ Permadeath

Permadeath can be enabled when starting a new adventure.

Fainted Pokémon are permanently lost, turning team composition, supplies, survival conditions, and difficult battles into much larger decisions.

Special protections exist where necessary to prevent scripted early-game situations from immediately destroying a run.

## 🔄 Trade-Free Evolutions

Pokémon that normally require trading can evolve without link trading.

Basic trade evolutions receive a **Level 40 evolution alternative**.

In Generation II, Pokémon that normally require trading while holding a specific item can evolve at Level 40 or higher while holding that item. The required item is consumed.

## 🕐 Generation II Features

Gold and Crystal include additional systems built around Generation II mechanics.

### Game Time

Optional **Game Time** ties the clock to exploration:

- 10 steps = 1 in-game minute
- 600 steps = 1 in-game hour
- Camping advances time by 8 hours

Morning, day, and night therefore progress as you travel and rest.

### Breeding & Eggs

Breeding participates in PokeSurvive's randomizer.

Offspring can inherit and recombine characteristics from their parents, including species compatibility, typing, moves, palettes, and other randomized traits.

Special Gift Eggs are randomized independently and can produce Pokémon unlike other members of the same species found elsewhere in the world.

### Emergent Encounters

Travelers may contact you through the **Pokégear**, or one of your Pokémon may discover strange **Mail**.

These optional encounters send you to destinations around Johto where temporary NPCs, unusual situations, and randomized rewards await.

There are no quest markers. Remember where you're going and get there before the opportunity expires.

### Survival Tools

Permanent Survival Tools provide alternatives for important field abilities corresponding to:

**Cut • Fly • Surf • Strength • Flash • Whirlpool • Waterfall**

Tools unlock alongside normal story/HM progression and do not bypass progression requirements.

## 🧭 SURVIVE Menu

Select **SURVIVE** from the pause menu to view:

- Sustenance
- Energy
- Morale
- Current Mood

The interface also provides access to Camping, Supplies, Personalities, survival information, and the Journal.

## 📓 Journal

The Journal records information about your current journey, including your active randomizer seed.

Share a seed with another player to explore the same randomized world.

## 🚀 Starting a Run

Start a **New Game** normally.

Before your adventure begins, PokeSurvive presents its run configuration options. Depending on the game and version, these can include:

- Survival Mode
- Game Time
- Permadeath
- Random Pokémon
- Random Types
- Random Stats
- Random Moves
- Random Trainers

Run settings are locked once the adventure begins.

## 📦 Installation

Download the latest unified PokeSurvive release and install the `pokesurvive` folder using the Gen1Recomp mod-loading system.

**One installation supports Pokémon Red, Gold, and Crystal.**

When upgrading from an older PokeSurvive version, replace the previous installation rather than keeping multiple versions installed simultaneously.

PokeSurvive does **not** include Pokémon ROMs or copyrighted game data. Users must provide any legally required game files separately.

## ⚠️ Compatibility

PokeSurvive modifies many parts of the underlying games, so compatibility with arbitrary third-party mods cannot be guaranteed.

If you encounter a problem while using multiple mods, try reproducing it with only PokeSurvive enabled.

Randomization can create an enormous number of Pokémon, Trainer, event, breeding, and seed combinations. Testing every possible combination is impossible, so bug reports and strange edge cases are always welcome.

Save compatibility across major future versions is not guaranteed.

PokeSurvive v1.1.1+ includes compatibility support for **[Battle Factory Remix](https://github.com/GawdMode/Battle-Factory-Remix)**, a separate Pokémon Recomp mod that adds an expanded rental-based Battle Factory experience to Pokémon Red and Pokémon Crystal.

Battle Factory Remix can be installed and played without PokeSurvive. When both mods are enabled, PokeSurvive automatically recognizes Battle Factory battles and temporary rental Pokémon so its survival and randomizer systems do not interfere with the Factory.

This includes safeguards for:

- Temporary Battle Factory rental Pokémon
- Factory trainer teams and randomized opponents
- PokeSurvive's Pokémon randomizer
- Nuzlocke/permadeath behavior
- Survival meter drain during Factory battles
- Morale and Mood consequences
- Factory-specific randomized Pokémon types and palettes

Battle Factory Remix maintains its own progression, BP economy, rental generation, and temporary Pokémon state independently from your PokeSurvive run.

**Battle Factory Remix is optional and is distributed separately.**

PokeSurvive v1.3.0+ includes compatibility support for **[Angler's Cove Aquarium](https://github.com/GawdMode/anglers-cove-aquarium)**, a separate Pokémon Recomp mod that adds a new fishing system and aquarium tank shop to Cerulean City.

Angler's Cove Aquarium can be installed and played without PokeSurvive. When both mods are enabled, PokeSurvive automatically recognizes Angler's Cove Aquarium and allows the following:

- Angler's Cove Aquarium integration for Crystal
- Randomized fishing species can be caught through Fishing 2.0 and deposited into the aquarium.
- Randomized Pokémon use Crystal menu-icon art and generic swimming profiles when they do not have a curated aquatic profile.
- Randomized type palettes carry into Fishing 2.0 and the aquarium while preserving black outlines.
- Fishing outcomes can drain PokeSurvive Energy.
- New Fishy mood integration, including its custom thought bubble, a small Fishing 2.0 attraction-radius bonus, and increased ordinary encounter pressure. Watching the aquarium or fishing can occasionally trigger the Fishy mood.

**Angler's Cove Aquarium is optional and is distributed separately.**

## 🐛 Bug Reports

Helpful reports include:

1. PokeSurvive version
2. Pokémon game: Red, Gold, or Crystal
3. Gen1Recomp version
4. Run seed
5. Enabled run settings
6. What happened and what you expected
7. Steps to reproduce
8. Screenshots, video, or logs when available

If you're using additional mods, please mention them.

## ❤️ Thanks

PokeSurvive started as an experiment in making the journey through Pokémon matter as much as the battles. It has since grown into a unified survival overhaul spanning three classic Pokémon games.

Thanks to everyone who has played, tested, reported bugs, suggested ideas, shared runs, made videos, or otherwise helped shape the mod.

**Have fun surviving!**
