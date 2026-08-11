![PokeSurvive Logo](PokeSurvive%20Logo.png)

# PokeSurvive

**Public Alpha — v0.1.0-alpha.1**

PokeSurvive is a survival/roguelike gameplay overhaul for Pokémon Red running
through Gen1Recomp. It turns a normal playthrough into a more unpredictable
journey built around resource management, randomized runs, party personalities,
camping, and permanent consequences.

## Current Features

- Hunger and Energy survival meters
- Morale and temporary mood system
- Pokémon personalities with solo and party interaction events
- Context-aware Adventure Events for routes, forests, caves, towns, buildings,
  and surfing
- Camping with positive, negative, and flavor events
- Event-only Red and Blue Berries with run-randomized good/bad effects
- Depleted collapse after prolonged starvation/exhaustion
- Optional permadeath
- Seeded randomized starters, wild Pokémon, trainer parties, Gym Leaders,
  Elite Four, types, stats, learnsets, and catch rates
- Personality/mood effects that influence combat and exploration
- Pokémon portrait presentation for party Adventure Events

## Alpha Status

This build is a release candidate for the first public alpha. Expect bugs,
balance issues, awkward event combinations, and systems that will continue to
change.

New runs are strongly recommended when moving between major alpha versions.
Do not assume saves from development or older alpha builds will remain fully
compatible.

## Installation

PokeSurvive requires a working Gen1Recomp setup. Install the `pokesurvive`
folder as a Gen1Recomp mod using the mod-loading method supported by your
Gen1Recomp build.

This repository/package does **not** include a Pokémon Red ROM or copyrighted
game data. Users must provide any legally required game files separately.

## Starting a Run

Start a new game and complete Professor Oak's opening sequence. PokeSurvive
will present its run configuration before normal play begins.

The in-game **SURVIVE** menu shows Hunger, Energy, Mood, Morale, Pokémon
personalities, food, camping, and the run's locked configuration.

## Important Alpha Notes

- Randomized trainer teams preserve their original party sizes and levels.
- The opening Oak rival battle keeps special starter/tutorial handling.
- Red and Blue Berries are found through events rather than shops. One color is
  beneficial and the other harmful; which is which is randomized per run.
- Remaining fully Depleted for 250 walking steps causes a collapse and rescue
  near the most recently visited Pokémon Center.
- Optional permadeath can end a run if the party is lost.

## Bug Reports

When reporting a problem, please include:

1. PokeSurvive version
2. Gen1Recomp version/build
3. Whether the save began on the current PokeSurvive version
4. Enabled run settings
5. What you expected to happen
6. What actually happened
7. Steps to reproduce, if known
8. Screenshot/video and logs when available

## Development

PokeSurvive is currently in active alpha development. Balance, event frequency,
dialogue, randomization rules, and save compatibility may change substantially
before a stable release.
