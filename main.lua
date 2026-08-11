local SCREEN = "PokemonSurvivalStatus"
local FOOD_SCREEN = "PokemonSurvivalFood"
local CAMP_SCREEN = "PokemonSurvivalCamp"
local MOOD_TEST_SCREEN = "PokemonSurvivalMoodTest"
local FOOD_SHOP_SCREEN = "PokemonSurvivalFoodShop"
local RUN_SETTINGS_SCREEN = "PokemonSurvivalRunSettings"
local STAT_DEBUG_SCREEN = "PokemonSurvivalStatDebug"
local STAT_DETAIL_SCREEN = "PokemonSurvivalStatDetail"
local EVOLVE_DEBUG_SCREEN = "PokemonSurvivalEvolveDebug"
local MAX_HUNGER = 100
local MAX_ENERGY = 100
local STEPS_PER_HUNGER = 40
local STEPS_PER_ENERGY = 60
local CAMP_HUNGER_COST = 15
local MOOD_DURATIONS = {
  CONFIDENT = 800,
  RELAXED = 700,
  UNEASY = 600,
  HAPPY = 700,
  SAD = 700,
  THRIFTY = 700,
  ANGRY = 600,
  FOCUSED = 700,
  CURIOUS = 700,
}

local FOODS = {
  { id = "sandwich", label = "SANDWICH", restore = 25, price = 200 },
  { id = "trail_mix", label = "TRAIL MIX", restore = 15, price = 100 },
  { id = "camp_meal", label = "CAMP MEAL", restore = 50, price = 400 },
  { id = "red_berry", label = "RED BERRY", restore = 12, eventOnly = true, berry = "red" },
  { id = "blue_berry", label = "BLUE BERRY", restore = 12, eventOnly = true, berry = "blue" },
}

return function(mod)
  -- PokeSurvive custom Professor Oak overworld art.
  -- Gen1Recomp expects a 16x96 six-frame sheet:
  -- stand down/up/left, then walk down/up/left.
  mod.content.sprites:patch("SPRITE_OAK", {
    image = mod.path .. "/assets/oak/oak_overworld.png",
    frames = 6,
    walker = true,

    -- Preserve the PNG's own alpha channel and opaque light pixels exactly.
    -- Treating this as a normal DMG sprite caused the lightest shade to be
    -- interpreted as sprite transparency, making Oak look ghostly.
    trueColor = true,
  })

  local function hunger()
    return mod.save:get("hunger", MAX_HUNGER)
  end

  local function setHunger(value)
    value = math.max(0, math.min(MAX_HUNGER, math.floor(tonumber(value) or 0)))
    mod.save:set("hunger", value)
    return value
  end

  local function energy()
    return mod.save:get("energy", MAX_ENERGY)
  end

  local function setEnergy(value)
    value = math.max(0, math.min(MAX_ENERGY, math.floor(tonumber(value) or 0)))
    mod.save:set("energy", value)
    return value
  end

  local CAMP_TRAVEL_REQUIRED = 300
  local CAMP_EMERGENCY_ENERGY = 20

  local function campTravel()
    return math.max(0, math.floor(tonumber(
      mod.save:get("camp_travel", CAMP_TRAVEL_REQUIRED)
    ) or CAMP_TRAVEL_REQUIRED))
  end

  local function setCampTravel(value)
    mod.save:set("camp_travel", math.max(0, math.floor(tonumber(value) or 0)))
  end

  local function campRestReady()
    return campTravel() >= CAMP_TRAVEL_REQUIRED or energy() <= CAMP_EMERGENCY_ENERGY
  end

  local function energyCondition(value)
    if value <= 0 then return "EXHAUSTED" end
    if value <= 24 then return "DRAINED" end
    if value <= 49 then return "TIRED" end
    if value <= 74 then return "OKAY" end
    return "RESTED"
  end

  local function stepProgress()
    return mod.save:get("hunger_steps", 0)
  end

  local function energyStepProgress()
    return mod.save:get("energy_steps", 0)
  end

  local function condition(value)
    if value <= 0 then return "EXHAUSTED" end
    if value <= 24 then return "STARVING" end
    if value <= 49 then return "HUNGRY" end
    if value <= 74 then return "SATISFIED" end
    return "WELL FED"
  end


  local mood

  -- ================================================================
  -- Mod Manager legacy-save setup
  --
  -- These rows are STAGING controls for an existing save. They do not
  -- overwrite a configured run until APPLY TO SAVE is switched ON.
  -- New games still use Oak's in-world setup.
  -- ================================================================
  mod.options:define({
    {
      key = "legacy_pokesim",
      type = "toggle",
      label = "LEGACY SURVIVE",
      default = true,
    },
    {
      key = "legacy_random",
      type = "toggle",
      label = "LEGACY RANDOM",
      default = false,
    },
    {
      key = "legacy_permadeath",
      type = "toggle",
      label = "LEGACY PERMADEATH",
      default = false,
    },
    {
      key = "legacy_seed",
      type = "text",
      label = "LEGACY SEED",
      default = "",
    },
    {
      key = "legacy_apply",
      type = "toggle",
      label = "APPLY TO SAVE",
      default = false,
    },
  })

  -- ================================================================
  -- PokeSim Run Configuration
  -- Defaults preserve existing saves made before v0.11.
  -- ================================================================
  local function runConfigured()
    return mod.save:get("run_configured", false) == true
  end

  local function pokesimEnabled()
    if not runConfigured() then return false end
    return mod.save:get("run_pokesim", false) == true
  end

  local function randomPokemonEnabled()
    if not runConfigured() then return false end
    return mod.save:get("run_random_pokemon", false) == true
  end

  local function permadeathEnabled()
    if not runConfigured() then return false end
    return mod.save:get("run_permadeath", false) == true
  end

  local function seedHash(raw)
    raw = tostring(raw or "")
    local h = 17
    for i = 1, #raw do
      h = (h * 131 + raw:byte(i)) % 2147483647
    end
    if h <= 0 then h = 1 end
    return h
  end

  local function generateRunSeed()
    -- Combine several values so repeated new games are unlikely to collide,
    -- then hash to a stable positive integer for future deterministic RNG.
    local raw = tostring(os.time()) .. ":" ..
      tostring(math.random(1, 999999999)) .. ":" ..
      tostring(mod.save:get("camp_count", 0))
    return tostring(seedHash(raw))
  end

  local function setRunSeed(raw)
    raw = tostring(raw or "")
    if raw == "" then raw = generateRunSeed() end
    mod.save:set("run_seed_text", raw)
    mod.save:set("run_seed", seedHash(raw))
    return raw
  end

  local function runSeedText()
    local raw = tostring(mod.save:get("run_seed_text", "") or "")
    if raw == "" then raw = setRunSeed(generateRunSeed()) end
    return raw
  end

  local function runSeed()
    local n = tonumber(mod.save:get("run_seed", 0)) or 0
    if n <= 0 then
      runSeedText()
      n = tonumber(mod.save:get("run_seed", 1)) or 1
    end
    return n
  end

  -- ================================================================
  -- PokeSim World Randomizer v1
  -- Seeded starters + ordinary wild encounters.
  -- Pokémon internals (typing/stats/moves) remain vanilla in this build.
  -- ================================================================
  local RANDOM_STARTER_KEYS = {
    "CHARMANDER_BALL",
    "SQUIRTLE_BALL",
    "BULBASAUR_BALL",
  }

  local randomSpeciesPool = nil
  local randomIncomingEvos = nil

  local function buildRandomSpeciesData()
    if randomSpeciesPool and randomIncomingEvos then
      return randomSpeciesPool, randomIncomingEvos
    end

    local Game = require("src.core.Game")
    local data = Game.data
    local pool = {}
    local incoming = {}

    for id, def in pairs((data and data.pokemon) or {}) do
      local dex = tonumber(def and def.dex)
      if dex and dex >= 1 and dex <= 151 then
        table.insert(pool, {
          id = id,
          dex = dex,
          name = (def and def.name) or id,
        })
      end
    end

    for fromId, def in pairs((data and data.pokemon) or {}) do
      for _, evo in ipairs((def and def.evolutions) or {}) do
        if evo.species then
          incoming[evo.species] = incoming[evo.species] or {}
          table.insert(incoming[evo.species], {
            from = fromId,
            method = evo.method,
            level = tonumber(evo.level or 0) or 0,
          })
        end
      end
    end

    table.sort(pool, function(a, b)
      if a.dex ~= b.dex then return a.dex < b.dex end
      return tostring(a.id) < tostring(b.id)
    end)

    randomSpeciesPool = pool
    randomIncomingEvos = incoming
    return pool, incoming
  end

  local function getRandomSpeciesPool()
    local pool = buildRandomSpeciesData()
    return pool
  end

  local MIN_NONLEVEL_EVOLUTION_LEVEL = 16
  local minEncounterLevelCache = {}

  local function minimumEncounterLevel(species, visiting)
    if minEncounterLevelCache[species] then
      return minEncounterLevelCache[species]
    end

    local _, incoming = buildRandomSpeciesData()
    local parents = incoming[species]
    if not parents or #parents == 0 then
      minEncounterLevelCache[species] = 1
      return 1
    end

    visiting = visiting or {}
    if visiting[species] then return 100 end
    visiting[species] = true

    local best = 100
    for _, evo in ipairs(parents) do
      local parentMin = minimumEncounterLevel(evo.from, visiting)
      local stepMin

      if evo.method == "LEVEL" then
        stepMin = math.max(parentMin, tonumber(evo.level or 1) or 1)
      else
        -- Stone/trade forms are technically possible at any level in Gen I,
        -- but low-level evolved forms look wrong in a randomized ecosystem.
        -- Give every non-level evolution a sensible minimum floor while
        -- still respecting any earlier level evolution in its chain.
        stepMin = math.max(parentMin, MIN_NONLEVEL_EVOLUTION_LEVEL)
      end

      best = math.min(best, stepMin)
    end

    visiting[species] = nil
    minEncounterLevelCache[species] = best
    return best
  end

  local function randomSpeciesEligible(species, opts)
    opts = opts or {}
    local _, incoming = buildRandomSpeciesData()
    local parents = incoming[species]

    -- Starter balls only draw from true base/single-stage species.
    if opts.baseOnly then
      return not parents or #parents == 0
    end

    if opts.level and parents and #parents > 0 then
      return opts.level >= minimumEncounterLevel(species)
    end

    return true
  end

  local function deterministicSpecies(key, used, opts)
    local pool = getRandomSpeciesPool()
    if #pool == 0 then return nil end

    local h = seedHash(tostring(runSeed()) .. "|" .. tostring(key))
    local start = (h % #pool) + 1

    for offset = 0, #pool - 1 do
      local entry = pool[((start - 1 + offset) % #pool) + 1]
      if (not used or not used[entry.id])
         and randomSpeciesEligible(entry.id, opts) then
        return entry.id
      end
    end

    -- Defensive fallback; the Gen I pool always has eligible basic species.
    return pool[start].id
  end

  local function speciesName(game, species)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    return tostring((def and def.name) or species or "Pokémon")
  end

  local function ensureRandomStarters()
    if not randomPokemonEnabled() then
      return { "CHARMANDER", "SQUIRTLE", "BULBASAUR" }
    end

    local roster = {}
    local used = {}

    for slot = 1, 3 do
      local key = "random_starter_" .. tostring(slot)
      local species = mod.save:get(key, "")
      if species == "" then
        species = deterministicSpecies(
          "starter|" .. RANDOM_STARTER_KEYS[slot],
          used,
          { baseOnly = true }
        )
        mod.save:set(key, species or "")
      end
      if species and species ~= "" then used[species] = true end
      roster[slot] = species
    end

    return roster
  end

  -- ================================================================
  -- Random Pokémon v2: deterministic species typings
  -- ================================================================
  local GEN1_RANDOM_TYPES = {
    "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE",
    "FIGHTING", "POISON", "GROUND", "FLYING", "PSYCHIC",
    "BUG", "ROCK", "GHOST", "DRAGON",
  }

  -- ADVANCED-color palette identity for randomized primary types.
  -- Gen1Recomp species palettes are compact palette IDs; these names mirror
  -- the engine's Advanced-color palette vocabulary.
  -- Custom four-shade PokeSim palettes. Gen1Recomp's mod API lets us
  -- register arbitrary named palettes, so every Gen I type can have its own
  -- readable identity instead of sharing the stock *MON buckets.
  local POKESIM_TYPE_PALETTES = {
    -- Keep shade 1 pure white and shade 4 pure black. Gen1Recomp reuses
    -- these four shades in sprite/UI regions, so tinting either endpoint
    -- creates colored sprite rectangles or tinted interface borders.
    -- Only shades 2 and 3 carry the randomized type identity.
    NORMAL = {
      {255, 255, 255}, {210, 186, 148}, {142, 106, 72}, {0, 0, 0},
    },
    FIRE = {
      {255, 255, 255}, {255, 154, 48}, {220, 48, 24}, {0, 0, 0},
    },
    WATER = {
      {255, 255, 255}, {76, 188, 236}, {28, 92, 196}, {0, 0, 0},
    },
    ELECTRIC = {
      {255, 255, 255}, {255, 226, 44}, {214, 156, 16}, {0, 0, 0},
    },
    GRASS = {
      {255, 255, 255}, {104, 212, 92}, {34, 132, 64}, {0, 0, 0},
    },
    ICE = {
      {255, 255, 255}, {164, 236, 244}, {98, 176, 210}, {0, 0, 0},
    },
    FIGHTING = {
      {255, 255, 255}, {224, 120, 60}, {154, 48, 44}, {0, 0, 0},
    },
    POISON = {
      {255, 255, 255}, {190, 94, 220}, {112, 44, 156}, {0, 0, 0},
    },
    GROUND = {
      {255, 255, 255}, {210, 166, 92}, {150, 102, 48}, {0, 0, 0},
    },
    FLYING = {
      {255, 255, 255}, {132, 206, 244}, {68, 132, 214}, {0, 0, 0},
    },
    PSYCHIC = {
      {255, 255, 255}, {242, 112, 174}, {188, 48, 122}, {0, 0, 0},
    },
    BUG = {
      {255, 255, 255}, {166, 210, 64}, {92, 126, 36}, {0, 0, 0},
    },
    ROCK = {
      {255, 255, 255}, {168, 158, 132}, {102, 96, 84}, {0, 0, 0},
    },
    GHOST = {
      {255, 255, 255}, {136, 116, 184}, {76, 58, 132}, {0, 0, 0},
    },
    DRAGON = {
      {255, 255, 255}, {116, 112, 224}, {64, 54, 170}, {0, 0, 0},
    },
  }

  for typeName, colors in pairs(POKESIM_TYPE_PALETTES) do
    -- Palette registry expects the four RGB rows directly:
    -- { {r,g,b}, {r,g,b}, {r,g,b}, {r,g,b} }
    -- Do not wrap them in a { colors = ... } record.
    local palette = {}
    for i = 1, 4 do
      palette[i] = {
        colors[i][1],
        colors[i][2],
        colors[i][3],
      }
    end
    mod.content.palettes:register("POKESIM_" .. typeName, palette)
  end

  local TYPE_ADVANCED_PALETTES = {
    NORMAL   = "POKESIM_NORMAL",
    FIRE     = "POKESIM_FIRE",
    WATER    = "POKESIM_WATER",
    ELECTRIC = "POKESIM_ELECTRIC",
    GRASS    = "POKESIM_GRASS",
    ICE      = "POKESIM_ICE",
    FIGHTING = "POKESIM_FIGHTING",
    POISON   = "POKESIM_POISON",
    GROUND   = "POKESIM_GROUND",
    FLYING   = "POKESIM_FLYING",
    PSYCHIC  = "POKESIM_PSYCHIC",
    BUG      = "POKESIM_BUG",
    ROCK     = "POKESIM_ROCK",
    GHOST    = "POKESIM_GHOST",
    DRAGON   = "POKESIM_DRAGON",
  }

  local originalSpeciesPalettes = {}

  local randomizedTypeCache = {}

  local function deterministicTypesForSpecies(species)
    if not randomPokemonEnabled() then return nil end
    local key = tostring(runSeed()) .. "|" .. tostring(species)
    if randomizedTypeCache[key] then return randomizedTypeCache[key] end

    local h1 = seedHash(tostring(runSeed()) .. "|type1|" .. tostring(species))
    local type1 = GEN1_RANDOM_TYPES[(h1 % #GEN1_RANDOM_TYPES) + 1]
    local type2 = nil

    -- Preserve a mix of mono- and dual-type Pokémon. About 45% are dual.
    if (seedHash(tostring(runSeed()) .. "|dual|" .. tostring(species)) % 100) < 45 then
      local h2 = seedHash(tostring(runSeed()) .. "|type2|" .. tostring(species))
      local pos = (h2 % #GEN1_RANDOM_TYPES) + 1
      for offset = 0, #GEN1_RANDOM_TYPES - 1 do
        local candidate = GEN1_RANDOM_TYPES[((pos - 1 + offset) % #GEN1_RANDOM_TYPES) + 1]
        if candidate ~= type1 then
          type2 = candidate
          break
        end
      end
    end

    local result = { type1, type2 }
    randomizedTypeCache[key] = result
    return result
  end

  -- ================================================================
  -- Random Pokémon v3.1: evolution-stage BST donor pools
  --
  -- Each species borrows the BST of a DIFFERENT species occupying the same
  -- evolutionary role, then redistributes that budget across Gen I's five
  -- stats. This preserves progression without preserving species power.
  -- ================================================================
  local RANDOM_STAT_KEYS = {
    "hp", "attack", "defense", "speed", "special",
  }

  local MIN_RANDOM_BASE_STAT = 20
  local MAX_RANDOM_BASE_STAT = 190
  local randomizedStatsCache = {}
  local randomizedBSTCache = nil

  -- Gen I evolutionary-role pools. We intentionally distinguish:
  -- 3-stage base / middle / final, 2-stage base / final, and single-stage.
  -- Branching lines use the role they occupy: Eevee is a 2-stage base;
  -- its three evolutions are 2-stage finals.
  local THREE_STAGE_BASE = {
    "BULBASAUR","CHARMANDER","SQUIRTLE","CATERPIE","WEEDLE",
    "PIDGEY","NIDORAN_F","NIDORAN_M","ODDISH","POLIWAG",
    "ABRA","MACHOP","BELLSPROUT","GEODUDE","GASTLY","DRATINI",
  }
  local THREE_STAGE_MIDDLE = {
    "IVYSAUR","CHARMELEON","WARTORTLE","METAPOD","KAKUNA",
    "PIDGEOTTO","NIDORINA","NIDORINO","GLOOM","POLIWHIRL",
    "KADABRA","MACHOKE","WEEPINBELL","GRAVELER","HAUNTER","DRAGONAIR",
  }
  local THREE_STAGE_FINAL = {
    "VENUSAUR","CHARIZARD","BLASTOISE","BUTTERFREE","BEEDRILL",
    "PIDGEOT","NIDOQUEEN","NIDOKING","VILEPLUME","POLIWRATH",
    "ALAKAZAM","MACHAMP","VICTREEBEL","GOLEM","GENGAR","DRAGONITE",
  }

  local TWO_STAGE_BASE = {
    "RATTATA","SPEAROW","EKANS","PIKACHU","SANDSHREW",
    "CLEFAIRY","VULPIX","JIGGLYPUFF","ZUBAT","PARAS",
    "VENONAT","DIGLETT","MEOWTH","PSYDUCK","MANKEY",
    "GROWLITHE","TENTACOOL","PONYTA","SLOWPOKE","MAGNEMITE",
    "DODUO","SEEL","GRIMER","SHELLDER","DROWZEE",
    "KRABBY","VOLTORB","EXEGGCUTE","CUBONE","KOFFING",
    "RHYHORN","HORSEA","GOLDEEN","STARYU","OMANYTE",
    "KABUTO","EEVEE","MAGIKARP",
  }
  local TWO_STAGE_FINAL = {
    "RATICATE","FEAROW","ARBOK","RAICHU","SANDSLASH",
    "CLEFABLE","NINETALES","WIGGLYTUFF","GOLBAT","PARASECT",
    "VENOMOTH","DUGTRIO","PERSIAN","GOLDUCK","PRIMEAPE",
    "ARCANINE","TENTACRUEL","RAPIDASH","SLOWBRO","MAGNETON",
    "DODRIO","DEWGONG","MUK","CLOYSTER","HYPNO",
    "KINGLER","ELECTRODE","EXEGGUTOR","MAROWAK","WEEZING",
    "RHYDON","SEADRA","SEAKING","STARMIE","OMASTAR",
    "KABUTOPS","VAPOREON","JOLTEON","FLAREON","GYARADOS",
  }

  local SINGLE_STAGE = {
    "FARFETCHD","ONIX","LICKITUNG","CHANSEY","TANGELA",
    "KANGASKHAN","MR_MIME","SCYTHER","JYNX","ELECTABUZZ",
    "MAGMAR","PINSIR","TAUROS","HITMONLEE","HITMONCHAN",
    "LAPRAS","DITTO","PORYGON","AERODACTYL","SNORLAX",
    "ARTICUNO","ZAPDOS","MOLTRES","MEWTWO","MEW",
  }

  local function poolContains(pool, species)
    for _, id in ipairs(pool) do
      if id == species then return true end
    end
    return false
  end

  local function evolutionaryRole(species)
    if poolContains(THREE_STAGE_BASE, species) then return "3-STAGE BASE" end
    if poolContains(THREE_STAGE_MIDDLE, species) then return "3-STAGE MID" end
    if poolContains(THREE_STAGE_FINAL, species) then return "3-STAGE FINAL" end
    if poolContains(TWO_STAGE_BASE, species) then return "2-STAGE BASE" end
    if poolContains(TWO_STAGE_FINAL, species) then return "2-STAGE FINAL" end
    if poolContains(SINGLE_STAGE, species) then return "SINGLE" end
    return "UNKNOWN"
  end

  local function speciesBST(stats)
    local total = 0
    if not stats then return total end
    for _, key in ipairs(RANDOM_STAT_KEYS) do
      total = total + (tonumber(stats[key]) or 0)
    end
    return total
  end

  local function seededPermutation(pool, salt)
    local keyed = {}
    for i, species in ipairs(pool) do
      keyed[i] = {
        species = species,
        key = seedHash(
          tostring(runSeed()) .. "|" .. salt .. "|" .. tostring(species)
        ),
      }
    end
    table.sort(keyed, function(a, b)
      if a.key == b.key then return a.species < b.species end
      return a.key < b.key
    end)

    local result = {}
    for i = 1, #keyed do
      -- Rotate by one so a species cannot simply donate its own BST.
      result[keyed[i].species] = keyed[(i % #keyed) + 1].species
    end
    return result
  end

  local function buildRandomizedBSTMap(originalStats)
    local pools = {
      { "3BASE", THREE_STAGE_BASE },
      { "3MID", THREE_STAGE_MIDDLE },
      { "3FINAL", THREE_STAGE_FINAL },
      { "2BASE", TWO_STAGE_BASE },
      { "2FINAL", TWO_STAGE_FINAL },
      { "SINGLE", SINGLE_STAGE },
    }

    local donorBySpecies = {}
    for _, entry in ipairs(pools) do
      local role, pool = entry[1], entry[2]
      local perm = seededPermutation(pool, "bstpool|" .. role)
      for species, donor in pairs(perm) do
        donorBySpecies[species] = donor
      end
    end

    local result = {}
    for species, donor in pairs(donorBySpecies) do
      local donorStats = originalStats[donor]
      if donorStats then
        result[species] = {
          bst = speciesBST(donorStats),
          donor = donor,
        }
      end
    end

    return result
  end

  local function deterministicStatsForSpecies(species, original, originalStats)
    if not randomPokemonEnabled() or not original then return nil end

    local cacheKey = tostring(runSeed()) .. "|" .. tostring(species)
    if randomizedStatsCache[cacheKey] then
      return randomizedStatsCache[cacheKey]
    end

    if not randomizedBSTCache then
      randomizedBSTCache = buildRandomizedBSTMap(originalStats or {})
    end

    local assignment = randomizedBSTCache[species]
    local total = assignment and assignment.bst or speciesBST(original)
    local donor = assignment and assignment.donor or species

    local floorStat = MIN_RANDOM_BASE_STAT
    if total < floorStat * #RANDOM_STAT_KEYS then
      floorStat = math.max(1, math.floor(total / #RANDOM_STAT_KEYS))
    end

    local result = {}
    for _, key in ipairs(RANDOM_STAT_KEYS) do
      result[key] = floorStat
    end

    local remaining = total - (floorStat * #RANDOM_STAT_KEYS)
    local weights = {}
    for _, key in ipairs(RANDOM_STAT_KEYS) do
      weights[key] =
        15 + (seedHash(
          tostring(runSeed()) .. "|statweight|" ..
          tostring(species) .. "|" .. key
        ) % 86)
    end

    local point = 0
    while remaining > 0 do
      point = point + 1
      local available = {}
      local totalWeight = 0

      for _, key in ipairs(RANDOM_STAT_KEYS) do
        if result[key] < MAX_RANDOM_BASE_STAT then
          table.insert(available, key)
          totalWeight = totalWeight + weights[key]
        end
      end

      if #available == 0 or totalWeight <= 0 then break end

      local roll = seedHash(
        tostring(runSeed()) .. "|statpoint|" ..
        tostring(species) .. "|" .. tostring(point)
      ) % totalWeight

      local chosen = available[#available]
      local cursor = 0
      for _, key in ipairs(available) do
        cursor = cursor + weights[key]
        if roll < cursor then
          chosen = key
          break
        end
      end

      result[chosen] = result[chosen] + 1
      remaining = remaining - 1
    end

    result._bst = total
    result._donor = donor
    randomizedStatsCache[cacheKey] = result
    return result
  end


  -- ================================================================
  -- Random Pokémon v4: seeded learnsets + catch rates
  --
  -- Learnsets keep the species' original number of slots and learn levels,
  -- but the move occupying each slot is randomized.
  --
  -- A 40% roll prefers one of the Pokémon's randomized types, so typings
  -- meaningfully influence what it may learn without turning every learnset
  -- into pure STAB.
  --
  -- Low-level slots use a gentler power ceiling, and every species is
  -- guaranteed at least one practical damaging move by level 5 so a starter
  -- can never begin the run helpless.
  --
  -- Catch rates are donor-shuffled inside the same evolution-role pools used
  -- by the stat system.
  -- ================================================================

  local randomizedLearnsetCache = {}
  local randomizedCatchRateCache = nil

  local RANDOM_MOVE_EXCLUSIONS = {
    STRUGGLE = true,
  }

  local GUARANTEE_ATTACK_EXCLUSIONS = {
    STRUGGLE = true,
    SELFDESTRUCT = true,
    EXPLOSION = true,
    DREAM_EATER = true,
    COUNTER = true,
    BIDE = true,
    FISSURE = true,
    GUILLOTINE = true,
    HORN_DRILL = true,
  }

  local function movePowerCeiling(level)
    level = tonumber(level) or 1
    if level <= 5 then return 60 end
    if level <= 10 then return 70 end
    if level <= 20 then return 85 end
    if level <= 35 then return 100 end
    return 255
  end

  local function sortedMoveIds(data)
    local ids = {}
    for id, def in pairs((data and data.moves) or {}) do
      if def and not RANDOM_MOVE_EXCLUSIONS[id] then
        table.insert(ids, id)
      end
    end
    table.sort(ids)
    return ids
  end

  local function moveIsDamaging(def)
    if not def then return false end
    return (tonumber(def.power) or 0) > 0
      and tostring(def.category or "") ~= "status"
  end

  local function candidateMoves(data, level, wantedTypes, forceDamage)
    local all = {}
    local typed = {}
    local ceiling = movePowerCeiling(level)

    local wanted = {}
    for _, tp in ipairs(wantedTypes or {}) do
      if tp then wanted[tp] = true end
    end

    for _, id in ipairs(sortedMoveIds(data)) do
      local def = data.moves[id]
      local power = tonumber(def and def.power) or 0
      local allowed = true

      if forceDamage then
        allowed = moveIsDamaging(def)
          and not GUARANTEE_ATTACK_EXCLUSIONS[id]
          and power >= 20
          and power <= math.min(80, ceiling)
          and (tonumber(def.accuracy) or 100) >= 70
      elseif power > 0 and power > ceiling then
        allowed = false
      end

      if allowed then
        table.insert(all, id)
        if wanted[def.type] then
          table.insert(typed, id)
        end
      end
    end

    return all, typed
  end

  local function deterministicMovePick(
    data, species, slotKey, level, wantedTypes, used, forceDamage
  )
    local all, typed = candidateMoves(data, level, wantedTypes, forceDamage)
    if #all == 0 then return nil end

    local useTyped = #typed > 0 and (
      forceDamage
      or (seedHash(
        tostring(runSeed()) .. "|movetype|" ..
        tostring(species) .. "|" .. tostring(slotKey)
      ) % 100) < 40
    )

    local pool = useTyped and typed or all
    local start = (seedHash(
      tostring(runSeed()) .. "|move|" ..
      tostring(species) .. "|" .. tostring(slotKey)
    ) % #pool) + 1

    -- Walk deterministically until we find a move not already used by this
    -- species. If the pool is exhausted, duplicates are allowed as fallback.
    for offset = 0, #pool - 1 do
      local idx = ((start - 1 + offset) % #pool) + 1
      local id = pool[idx]
      if not used[id] then return id end
    end

    return pool[start]
  end

  local function hasDamageByLevel(data, level1Moves, learnset, level)
    for _, id in ipairs(level1Moves or {}) do
      if moveIsDamaging(data.moves[id]) then return true end
    end
    for _, entry in ipairs(learnset or {}) do
      if (tonumber(entry.level) or 999) <= level
        and moveIsDamaging(data.moves[entry.move]) then
        return true
      end
    end
    return false
  end

  local function deterministicLearnsetForSpecies(
    data, species, originalLevel1, originalLearnset, randomizedTypes
  )
    if not randomPokemonEnabled() then return nil end

    local cacheKey = tostring(runSeed()) .. "|" .. tostring(species)
    if randomizedLearnsetCache[cacheKey] then
      return randomizedLearnsetCache[cacheKey]
    end

    local used = {}
    local level1 = {}
    local learnset = {}

    for i = 1, #(originalLevel1 or {}) do
      local id = deterministicMovePick(
        data, species, "L1:" .. tostring(i), 1,
        randomizedTypes, used, false
      )
      if id then
        table.insert(level1, id)
        used[id] = true
      end
    end

    for i, entry in ipairs(originalLearnset or {}) do
      local level = tonumber(entry.level) or 1
      local id = deterministicMovePick(
        data, species, "LEARN:" .. tostring(i) .. ":" .. tostring(level),
        level, randomizedTypes, used, false
      )
      if id then
        table.insert(learnset, { level = level, move = id })
        used[id] = true
      end
    end

    -- Starter safety: every possible level-5 starter must have at least one
    -- practical damaging attack available by level 5.
    if not hasDamageByLevel(data, level1, learnset, 5) then
      local safe = deterministicMovePick(
        data, species, "STARTER_ATTACK", 5,
        randomizedTypes, used, true
      )

      if safe then
        if #level1 > 0 then
          used[level1[#level1]] = nil
          level1[#level1] = safe
        else
          local replaced = false
          for _, entry in ipairs(learnset) do
            if entry.level <= 5 then
              used[entry.move] = nil
              entry.move = safe
              replaced = true
              break
            end
          end
          if not replaced then
            table.insert(level1, safe)
          end
        end
        used[safe] = true
      end
    end

    local result = {
      level1Moves = level1,
      learnset = learnset,
    }
    randomizedLearnsetCache[cacheKey] = result
    return result
  end

  local function buildRandomizedCatchRateMap(originalRates)
    local pools = {
      { "3BASE", THREE_STAGE_BASE },
      { "3MID", THREE_STAGE_MIDDLE },
      { "3FINAL", THREE_STAGE_FINAL },
      { "2BASE", TWO_STAGE_BASE },
      { "2FINAL", TWO_STAGE_FINAL },
      { "SINGLE", SINGLE_STAGE },
    }

    local result = {}
    for _, entry in ipairs(pools) do
      local role, pool = entry[1], entry[2]
      local donors = seededPermutation(pool, "catchpool|" .. role)
      for species, donor in pairs(donors) do
        if originalRates[donor] ~= nil then
          result[species] = {
            rate = originalRates[donor],
            donor = donor,
          }
        end
      end
    end
    return result
  end

  local originalSpeciesTypes = {}
  local originalSpeciesStats = {}
  local originalSpeciesLevel1Moves = {}
  local originalSpeciesLearnsets = {}
  local originalSpeciesCatchRates = {}
  local lastTypeSyncSignature = nil

  local function rememberOriginalSpeciesTypes()
    local Game = require("src.core.Game")
    local data = Game.data
    if not data or not data.pokemon then return nil end

    for species, def in pairs(data.pokemon) do
      if def and def.types and not originalSpeciesTypes[species] then
        originalSpeciesTypes[species] = {
          def.types[1],
          def.types[2],
        }
      end
      if def and def.baseStats and not originalSpeciesStats[species] then
        originalSpeciesStats[species] = {
          hp = tonumber(def.baseStats.hp) or 1,
          attack = tonumber(def.baseStats.attack) or 1,
          defense = tonumber(def.baseStats.defense) or 1,
          speed = tonumber(def.baseStats.speed) or 1,
          special = tonumber(def.baseStats.special) or 1,
        }
      end
      if def and originalSpeciesLevel1Moves[species] == nil then
        originalSpeciesLevel1Moves[species] = {}
        for _, id in ipairs(def.level1Moves or {}) do
          table.insert(originalSpeciesLevel1Moves[species], id)
        end
      end

      if def and originalSpeciesLearnsets[species] == nil then
        originalSpeciesLearnsets[species] = {}
        for _, entry in ipairs(def.learnset or {}) do
          table.insert(originalSpeciesLearnsets[species], {
            level = tonumber(entry.level) or 1,
            move = entry.move,
          })
        end
      end

      if def and originalSpeciesCatchRates[species] == nil then
        originalSpeciesCatchRates[species] = tonumber(def.catchRate) or 0
      end

      if def and originalSpeciesPalettes[species] == nil then
        -- false is used to remember that the species originally had no override.
        originalSpeciesPalettes[species] = def.palette or false
      end
    end

    return data
  end

  local lastStatsSeed = nil

  local function syncRandomizedTypeDefinitions()
    local data = rememberOriginalSpeciesTypes()
    if not data then return end

    local activeStatsSeed = randomPokemonEnabled() and tostring(runSeed()) or nil
    if activeStatsSeed ~= lastStatsSeed then
      randomizedBSTCache = nil
      randomizedStatsCache = {}
      randomizedLearnsetCache = {}
      randomizedCatchRateCache = nil
      lastStatsSeed = activeStatsSeed
    end

    local PaletteFX = require("src.render.PaletteFX")
    local advancedColors = PaletteFX.mode == "redpp"

    local signature
    if randomPokemonEnabled() then
      signature = "MOVE1|ON|" .. tostring(runSeed()) .. "|" .. tostring(PaletteFX.mode)
    else
      signature = "MOVE1|OFF|" .. tostring(PaletteFX.mode)
    end

    if signature == lastTypeSyncSignature then return end

    for species, def in pairs(data.pokemon) do
      local original = originalSpeciesTypes[species]
      local originalStats = originalSpeciesStats[species]
      if def and original then
        if randomPokemonEnabled() then
          local generated = deterministicTypesForSpecies(species)
          local generatedStats =
            deterministicStatsForSpecies(species, originalStats, originalSpeciesStats)

          if generatedStats and def.baseStats then
            def.baseStats.hp = generatedStats.hp
            def.baseStats.attack = generatedStats.attack
            def.baseStats.defense = generatedStats.defense
            def.baseStats.speed = generatedStats.speed
            def.baseStats.special = generatedStats.special
          end

          local generatedMoves = deterministicLearnsetForSpecies(
            data,
            species,
            originalSpeciesLevel1Moves[species],
            originalSpeciesLearnsets[species],
            generated
          )
          if generatedMoves then
            def.level1Moves = {}
            for _, id in ipairs(generatedMoves.level1Moves) do
              table.insert(def.level1Moves, id)
            end
            def.learnset = {}
            for _, entry in ipairs(generatedMoves.learnset) do
              table.insert(def.learnset, {
                level = entry.level,
                move = entry.move,
              })
            end
          end

          if not randomizedCatchRateCache then
            randomizedCatchRateCache =
              buildRandomizedCatchRateMap(originalSpeciesCatchRates)
          end
          local catchAssignment = randomizedCatchRateCache[species]
          if catchAssignment then
            def.catchRate = catchAssignment.rate
          end

          if generated then
            def.types = generated[2]
              and { generated[1], generated[2] }
              or { generated[1] }

            -- Advanced color mode reads the species palette override for both
            -- battle and status sprites. v1 intentionally keys only from the
            -- primary randomized type; secondary-type accents come later.
            if advancedColors then
              def.palette = TYPE_ADVANCED_PALETTES[generated[1]]
                or originalSpeciesPalettes[species]
                or nil
            else
              local originalPalette = originalSpeciesPalettes[species]
              def.palette = originalPalette ~= false and originalPalette or nil
            end
          end
        else
          def.types = original[2]
            and { original[1], original[2] }
            or { original[1] }

          if originalStats and def.baseStats then
            def.baseStats.hp = originalStats.hp
            def.baseStats.attack = originalStats.attack
            def.baseStats.defense = originalStats.defense
            def.baseStats.speed = originalStats.speed
            def.baseStats.special = originalStats.special
          end

          def.level1Moves = {}
          for _, id in ipairs(originalSpeciesLevel1Moves[species] or {}) do
            table.insert(def.level1Moves, id)
          end
          def.learnset = {}
          for _, entry in ipairs(originalSpeciesLearnsets[species] or {}) do
            table.insert(def.learnset, {
              level = entry.level,
              move = entry.move,
            })
          end

          if originalSpeciesCatchRates[species] ~= nil then
            def.catchRate = originalSpeciesCatchRates[species]
          end

          local originalPalette = originalSpeciesPalettes[species]
          def.palette = originalPalette ~= false and originalPalette or nil
        end
      end
    end

    lastTypeSyncSignature = signature
    mod.log:info("Synced randomized species types/stats/palettes/moves/catch rates: %s", signature)
  end

  local function randomizedWildSpecies(mapId, terrain, species, level)
    if not randomPokemonEnabled() then return species end
    if not species then return species end

    local key = table.concat({
      "wild",
      tostring(mapId or "UNKNOWN"),
      tostring(terrain or "grass"),
      tostring(species),
      tostring(level or 0),
    }, "|")

    return deterministicSpecies(key, nil, { level = tonumber(level) or 1 })
      or species
  end

  -- Ordinary walking/surf encounters: preserve the encounter roll, slot
  -- frequency, and level. Only the species assigned to that rolled slot is
  -- transformed. Same seed + same map/slot inputs = same species.
  mod.hooks:wrap("encounter.species", function(next, enc, ctx)
    local out = next(enc, ctx)
    if not randomPokemonEnabled() or not out then return out end

    local c = {}
    for k, v in pairs(out) do c[k] = v end
    c.species = randomizedWildSpecies(
      ctx and ctx.mapId,
      ctx and ctx.terrain,
      out.species,
      out.level
    )
    return c
  end)

  -- Fishing has its own public seam rather than encounter.species.
  mod.hooks:wrap("encounter.fishing", function(next, rod, mapId, candidates)
    local enc = next(rod, mapId, candidates)
    if not randomPokemonEnabled() or not enc then return enc end

    local c = {}
    for k, v in pairs(enc) do c[k] = v end
    c.species = randomizedWildSpecies(
      mapId,
      "fishing:" .. tostring(rod),
      enc.species,
      enc.level
    )
    return c
  end)

  -- ================================================================
  -- Random Pokemon v5: trainer rosters
  --
  -- Gen1Recomp's trainer.party hook is the battle-time seam for trainer
  -- rosters. Preserve authored level + team size, replace species only.
  -- The mapping is deterministic for this run and trainer roster.
  -- ================================================================
  mod.hooks:wrap("trainer.party", function(nextParty, oppClass, partyIndex, party)
    local out = nextParty(oppClass, partyIndex, party) or party
    if not randomPokemonEnabled() or type(out) ~= "table" then return out end

    -- Keep Oak's mandatory starter rival battle tied to the randomized
    -- starter/counterpick system already handled elsewhere.
    if oppClass == "OPP_RIVAL1"
      and (tonumber(partyIndex) or 0) >= 1
      and (tonumber(partyIndex) or 0) <= 3 then
      return out
    end

    local rewritten = {}
    local used = {}

    for i, slot in ipairs(out) do
      if type(slot) == "table" and slot.species then
        local copy = {}
        for k, v in pairs(slot) do copy[k] = v end

        local level = tonumber(slot.level) or 1
        local key = table.concat({
          "trainer",
          tostring(oppClass or "UNKNOWN"),
          tostring(partyIndex or 0),
          tostring(i),
          tostring(slot.species),
        }, "|")

        local replacement = deterministicSpecies(
          key,
          used,
          { level = level }
        )

        if replacement then
          copy.species = replacement
          used[replacement] = true
          -- Never inherit a boss-specific authored moves list intended for
          -- the vanilla species. The randomized species uses its own current
          -- randomized/level-appropriate learnset instead.
          copy.moves = nil
        end

        rewritten[i] = copy
      else
        rewritten[i] = slot
      end
    end

    return rewritten
  end)

  local STARTER_BALL_INFO = {
    TEXT_OAKSLAB_CHARMANDER_POKE_BALL = {
      slot = 1, rivalSlot = 2,
    },
    TEXT_OAKSLAB_SQUIRTLE_POKE_BALL = {
      slot = 2, rivalSlot = 3,
    },
    TEXT_OAKSLAB_BULBASAUR_POKE_BALL = {
      slot = 3, rivalSlot = 1,
    },
  }

  local function cloneRows(rows)
    local out = {}
    for i, row in ipairs(rows or {}) do
      local copy = {}
      for k, v in pairs(row) do
        if type(v) == "table" then
          local nested = {}
          for nk, nv in pairs(v) do nested[nk] = nv end
          copy[k] = nested
        else
          copy[k] = v
        end
      end
      out[i] = copy
    end
    return out
  end

  local function randomizedStarterRows(game, textId)
    local MapScripts = require("src.script.MapScripts")
    local base = MapScripts.baseTalk("OAKS_LAB", textId)
    if not base then return nil end

    local info = STARTER_BALL_INFO[textId]
    if not info then return cloneRows(base) end

    local starters = ensureRandomStarters()
    local playerSpecies = starters[info.slot]
    local rivalSpecies = starters[info.rivalSlot]
    if not playerSpecies or not rivalSpecies then return cloneRows(base) end

    local rows = cloneRows(base)

    for _, row in ipairs(rows) do
      local cmd = row[1]

      if cmd == "push_screen" and row[2] == "DexEntryMenu"
         and type(row[3]) == "table" then
        row[3].species = playerSpecies

      elseif cmd == "ask" then
        row[2] = "So! You want\n" ..
          speciesName(game, playerSpecies) .. "?"

      elseif cmd == "show_text" and row[2] == "_OaksLabReceivedMonText" then
        row[3] = { RAM = playerSpecies }

      elseif cmd == "give_pokemon" then
        row[2] = playerSpecies

      elseif cmd == "show_text"
         and row[2] == "_OaksLabRivalReceivedMonText" then
        row[3] = { RAM = rivalSpecies }
      end
    end

    return rows, rivalSpecies
  end

  local function runStarterBall(textId, game, ow, npc, done)
    local MapScripts = require("src.script.MapScripts")

    if not randomPokemonEnabled() then
      local base = MapScripts.baseTalk("OAKS_LAB", textId)
      if base then
        ow.runner:run(base, { npc = npc, onDone = done })
      else
        done()
      end
      return
    end

    local rows, rivalSpecies = randomizedStarterRows(game, textId)
    if not rows then
      done()
      return
    end

    -- If the player accepts this ball, this is the Pokémon Blue takes from
    -- the counter-pick ball. If the player says NO and inspects another
    -- ball, this value is harmlessly replaced before any rival battle.
    mod.save:set("random_rival_starter", rivalSpecies or "")

    -- The mandatory first rival battle is a tutorial freebie. Keep an explicit
    -- grace flag alive through the entire post-battle Oak script so field
    -- permadeath cannot mistake the temporarily-0-HP starter for an overworld
    -- poison/field death before the vanilla heal finishes.
    mod.save:set("oak_rival_freebie_pending", true)

    ow.runner:run(rows, { npc = npc, onDone = done })
  end

  -- Override only the three starter-ball talk scripts. Oak, Blue, Pokédex,
  -- gift/item logic, movement, flags, and the rest of the lab stay vanilla.
  mod.content.map_scripts:register("OAKS_LAB", {
    priority = 200,
    talk = {
      ["TEXT_OAKSLAB_CHARMANDER_POKE_BALL"] =
        function(game, ow, npc, done)
          runStarterBall(
            "TEXT_OAKSLAB_CHARMANDER_POKE_BALL",
            game, ow, npc, done
          )
        end,

      ["TEXT_OAKSLAB_SQUIRTLE_POKE_BALL"] =
        function(game, ow, npc, done)
          runStarterBall(
            "TEXT_OAKSLAB_SQUIRTLE_POKE_BALL",
            game, ow, npc, done
          )
        end,

      ["TEXT_OAKSLAB_BULBASAUR_POKE_BALL"] =
        function(game, ow, npc, done)
          runStarterBall(
            "TEXT_OAKSLAB_BULBASAUR_POKE_BALL",
            game, ow, npc, done
          )
        end,
    },
  })

  -- Blue's first lab battle uses vanilla party slots 1-3. Replace only the
  -- starter species in those three parties so his battle Pokémon matches
  -- the randomized ball he visibly took.
  mod.hooks:wrap("trainer.party", function(next, oppClass, partyIndex, partyDef)
    local party = next(oppClass, partyIndex, partyDef)

    -- RIVAL1 party slots 1-3 are the three Oak starter matchups.
    if oppClass == "OPP_RIVAL1"
      and (tonumber(partyIndex) or 0) >= 1
      and (tonumber(partyIndex) or 0) <= 3 then
      mod.save:set("oak_rival_freebie_pending", true)
    end
    if not randomPokemonEnabled() then return party end
    if oppClass ~= "OPP_RIVAL1" then return party end
    if partyIndex < 1 or partyIndex > 3 then return party end

    local rivalSpecies = mod.save:get("random_rival_starter", "")
    if rivalSpecies == "" or type(party) ~= "table" or #party == 0 then
      return party
    end

    local copy = {}
    for i, slot in ipairs(party) do
      local s = {}
      for k, v in pairs(slot) do s[k] = v end
      copy[i] = s
    end
    copy[#copy].species = rivalSpecies
    return copy
  end)

  local function playerMoney(game)
    local save = game and game.save
    return math.max(0, math.floor(tonumber(save and save.money or 0) or 0))
  end

  local function setPlayerMoney(game, value)
    if game and game.save then
      game.save.money = math.max(0, math.floor(tonumber(value) or 0))
    end
  end

  local function foodLabel(food)
    return tostring((food and (food.label or food.name)) or "FOOD")
  end

  local function foodPrice(food)
    local price = food and food.price or 0
    if mood() == "THRIFTY" then price = math.floor(price * 0.90) end
    return math.max(0, price)
  end

  -- Mood is intentionally NOT a 0-100 meter. One named mood is displayed.
  -- Temporary moods live underneath physical override moods such as
  -- ================================================================
  -- Mood System v2
  -- Core mood is a persistent -100..100 axis:
  -- MISERABLE <- SAD <- FINE -> HAPPY -> ECSTATIC.
  -- Specific emotions (CURIOUS, ANGRY, UNEASY, etc.) are temporary
  -- overlays. Physical survival states override the display but never
  -- erase either underlying layer.
  -- ================================================================
  -- ================================================================
  -- Mood reaction bubble
  --
  -- Non-blocking visual feedback whenever the LONG-TERM core mood crosses
  -- into a different band. Numeric changes inside the same band stay quiet.
  -- ================================================================
  local moodBubbleName = nil
  local moodBubbleUntil = 0

  local function moodBandForValue(value)
    value = math.max(-100, math.min(100, math.floor(tonumber(value) or 0)))
    if value <= -61 then return "MISERABLE" end
    if value <= -21 then return "SAD" end
    if value <= 20 then return "FINE" end
    if value <= 60 then return "HAPPY" end
    return "ECSTATIC"
  end

  local function triggerMoodBubble(name)
    moodBubbleName = tostring(name or "FINE")
    local now = (love.timer and love.timer.getTime and love.timer.getTime()) or 0
    moodBubbleUntil = now + 2.0

    -- Gen1Recomp's Lt. Surge trash-puzzle switch chirp.
    -- Short, unobtrusive audio feedback to accompany the non-blocking bubble.
    local game = require("src.core.Game")
    if game and game.data then
      require("src.core.Sound").play(game.data, "Switch")
    end
  end

  local function moodValue()
    return math.max(-100, math.min(100, math.floor(
      tonumber(mod.save:get("mood_value", 0)) or 0
    )))
  end

  local function setMoodValue(value)
    local before = math.max(-100, math.min(100, math.floor(
      tonumber(mod.save:get("mood_value", 0)) or 0
    )))
    value = math.max(-100, math.min(100, math.floor(tonumber(value) or 0)))

    local oldBand = moodBandForValue(before)
    local newBand = moodBandForValue(value)

    mod.save:set("mood_value", value)

    if oldBand ~= newBand then
      triggerMoodBubble(newBand)
    end

    return value
  end

  local function adjustMood(amount)
    return setMoodValue(moodValue() + (tonumber(amount) or 0))
  end

  local function coreMood()
    return moodBandForValue(moodValue())
  end

  local function coreMoodEffectText()
    local core = coreMood()
    if core == "MISERABLE" then return "DMG -10%" end
    if core == "SAD" then return "DMG -5%" end
    if core == "HAPPY" then return "DMG +5%" end
    if core == "ECSTATIC" then return "DMG +10%" end
    return "NONE"
  end

  local function baseMood()
    return coreMood()
  end

  local function emotion()
    local value = tostring(mod.save:get("mood_emotion", "NONE") or "NONE")
    local upper = value:upper()
    if upper ~= value then
      mod.save:set("mood_emotion", upper)
    end
    return upper
  end

  local function moodStepsRemaining()
    return math.max(0, math.floor(
      tonumber(mod.save:get("mood_emotion_steps", 0)) or 0
    ))
  end

  local function physicalMood()
    if hunger() <= 0 and energy() <= 0 then return "DEPLETED" end
    if hunger() <= 0 then return "FAMISHED" end
    if energy() <= 0 then return "EXHAUSTED" end
    return nil
  end

  mood = function()
    if not pokesimEnabled() then return "FINE" end
    return physicalMood() or (emotion() ~= "NONE" and emotion()) or coreMood()
  end

  local function clearTemporaryMood()
    local before = mood()
    mod.save:set("mood_emotion", "NONE")
    mod.save:set("mood_emotion_steps", 0)
    local after = mood()
    if before ~= after then
      triggerMoodBubble(after)
    end
  end

  -- Kept under the old function name so existing camp/NPC content becomes
  -- an emotion overlay instead of overwriting the long-term mood.
  local function setTemporaryMood(name, duration)
    name = tostring(name or "FINE")
    if name == "FINE" then
      clearTemporaryMood()
      return
    end
    if name == "HAPPY" then
      adjustMood(10)
      return
    elseif name == "SAD" then
      adjustMood(-10)
      return
    end
    local steps = duration or MOOD_DURATIONS[name] or 500
    mod.save:set("mood_emotion", name)
    mod.save:set("mood_emotion_steps", math.max(1, math.floor(steps)))
    triggerMoodBubble(name)
  end

  local lastNeedMood = nil
  local function reconcileMoodAfterNeedChange()
    local current = mood()
    if lastNeedMood ~= nil and lastNeedMood ~= current then
      triggerMoodBubble(current)
    end
    lastNeedMood = current
  end

  local physicalPenaltyClock = 0
  local lowHpMoodClock = 0
  local MORALE_DRIFT_STEPS = 180

  local function tickMoodStep(game)
    -- Long-term emotions naturally settle toward neutral over time.
    -- This happens regardless of whether morale is positive or negative;
    -- ongoing good/bad events can still overpower the drift.
    local driftSteps = math.max(0, math.floor(
      tonumber(mod.save:get("morale_drift_steps", 0)) or 0
    )) + 1

    -- Hunger and Energy affect emotional resilience before either meter
    -- reaches a full survival crisis. They modify only the natural return
    -- toward neutral, so poor condition cannot directly spiral morale down.
    local function needResilience(value)
      value = math.max(0, math.min(100, tonumber(value) or 0))
      if value >= 70 then return 1.20 end
      if value >= 51 then return 1.00 end
      if value >= 31 then return 0.85 end
      if value >= 11 then return 0.70 end
      return 0.55
    end

    local resilience =
      (needResilience(hunger()) + needResilience(energy())) / 2
    local value = moodValue()
    local driftInterval = MORALE_DRIFT_STEPS

    if value > 0 then
      -- Well-fed/rested trainers hold onto good morale longer.
      driftInterval = math.max(1, math.floor(
        MORALE_DRIFT_STEPS * resilience + 0.5
      ))
    elseif value < 0 then
      -- Good physical condition also makes bad morale easier to shake off.
      driftInterval = math.max(1, math.floor(
        MORALE_DRIFT_STEPS / resilience + 0.5
      ))
    end

    if value ~= 0 and driftSteps >= driftInterval then
      driftSteps = driftSteps - driftInterval
      if value > 0 then
        setMoodValue(value - 1)
      else
        setMoodValue(value + 1)
      end
    elseif value == 0 then
      -- Don't bank hundreds of neutral steps and instantly drift after
      -- the next morale event.
      driftSteps = 0
    end

    mod.save:set("morale_drift_steps", driftSteps)

    if emotion() ~= "NONE" then
      local remaining = moodStepsRemaining() - 1
      if remaining <= 0 then clearTemporaryMood()
      else mod.save:set("mood_emotion_steps", remaining) end
    end

    -- Staying in a survival crisis gradually wears down long-term morale.
    if physicalMood() then
      physicalPenaltyClock = physicalPenaltyClock + 1
      if physicalPenaltyClock >= 240 then
        physicalPenaltyClock = 0
        adjustMood(-3)
      end
    else
      physicalPenaltyClock = 0
    end

    -- A badly hurt companion can make the trainer uneasy. Check infrequently
    -- to avoid rerolling every tile and turning the overlay into spam.
    lowHpMoodClock = lowHpMoodClock + 1
    if lowHpMoodClock >= 120 then
      lowHpMoodClock = 0
      if game and game.save and not physicalMood() and emotion() == "NONE" then
        local critical = false
        for _, mon in ipairs(game.save.party or {}) do
          local maxhp = tonumber(mon.maxhp or mon.maxHP or 0) or 0
          local hp = tonumber(mon.hp or 0) or 0
          if maxhp > 0 and hp > 0 and hp / maxhp <= 0.25 then
            critical = true
            break
          end
        end
        if critical and math.random(1, 100) <= 15 then
          setTemporaryMood("UNEASY", 300)
        end
      end
    end
  end


  local function foodKey(id)
    return "food_" .. id
  end

  local function foodCount(id)
    return math.max(0, math.floor(tonumber(mod.save:get(foodKey(id), 0)) or 0))
  end

  local function setFoodCount(id, value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    mod.save:set(foodKey(id), value)
    return value
  end

  local function giveFood(id, amount)
    return setFoodCount(id, foodCount(id) + (amount or 1))
  end

  local function eatFood(food)
    if not food or foodCount(food.id) <= 0 then return 0 end
    local before = hunger()
    local amount = tonumber(food.restore or 0) or 0
    if food.berry then
      local good = mod.save:get("berry_good_color", "")
      if good ~= "red" and good ~= "blue" then
        good = (math.random(1, 2) == 1) and "red" or "blue"
        mod.save:set("berry_good_color", good)
      end
      amount = (food.berry == good) and 12 or -8
    elseif hunger() >= MAX_HUNGER then
      return 0
    end
    setFoodCount(food.id, foodCount(food.id) - 1)
    setHunger(before + amount)
    reconcileMoodAfterNeedChange()
    return hunger() - before
  end

  local function moodDrainInterval(baseSteps)
    local core = coreMood()
    if core == "MISERABLE" then
      -- 10% faster drain: 40 -> 36 Hunger, 60 -> 54 Energy.
      return math.max(1, math.floor(baseSteps * 0.90 + 0.5))
    elseif core == "ECSTATIC" then
      -- 10% slower drain: 40 -> 44 Hunger, 60 -> 66 Energy.
      return math.max(1, math.floor(baseSteps * 1.10 + 0.5))
    end
    return baseSteps
  end

  local function recordStep(game)
    if not pokesimEnabled() then return end
    local physicalBefore = physicalMood()
    setCampTravel(math.min(CAMP_TRAVEL_REQUIRED, campTravel() + 1))

    local hungerInterval = moodDrainInterval(STEPS_PER_HUNGER)
    local hungerSteps = stepProgress() + 1
    if hungerSteps >= hungerInterval then
      hungerSteps = hungerSteps - hungerInterval
      setHunger(hunger() - 1)
    end
    mod.save:set("hunger_steps", hungerSteps)

    local energyInterval = moodDrainInterval(STEPS_PER_ENERGY)
    if hunger() <= 0 then
      -- Starvation makes ordinary travel much more exhausting without
      -- changing normal passive Energy drain for a fed trainer.
      energyInterval = math.max(1, math.floor(energyInterval * 0.50))
    end
    local energySteps = energyStepProgress() + 1
    if energySteps >= energyInterval then
      energySteps = energySteps - energyInterval
      setEnergy(energy() - 1)
    end
    mod.save:set("energy_steps", energySteps)

    local physicalAfter = physicalMood()
    if physicalBefore ~= physicalAfter then
      -- Entering Famished/Exhausted/Depleted, or recovering from one through
      -- a step-driven state change, deserves the same non-blocking feedback.
      triggerMoodBubble(mood())
    end

    tickMoodStep(game)

    if physicalMood() == "DEPLETED" then
      local depletedSteps = math.max(0, math.floor(
        tonumber(mod.save:get("depleted_collapse_steps", 0)) or 0
      )) + 1
      mod.save:set("depleted_collapse_steps", depletedSteps)

      if depletedSteps >= 250
        and mod.save:get("depleted_collapse_pending", false) ~= true then
        mod.save:set("depleted_collapse_pending", true)
      end
    else
      mod.save:set("depleted_collapse_steps", 0)
      mod.save:set("depleted_collapse_pending", false)
    end
  end

  -- Gen1Recomp emits world.stepped exactly once after a completed tile step.
  -- This is now the authoritative survival clock.
  mod.events:on("world.stepped", function(ev)
    recordStep(ev and ev.game)
  end)

  local function pacedDialogue(text)
    text = tostring(text or "")
    local TextBox = require("src.render.TextBox")
    local chunks = {}

    for section in (text .. "\f"):gmatch("(.-)\f") do
      section = section:gsub("\n", " ")
      section = section:gsub(" +", " ")
      section = section:gsub("^ +", ""):gsub(" +$", "")

      if section ~= "" then
        local pages = TextBox.paginate(section, 18)
        for _, lines in ipairs(pages) do
          local i = 1
          while i <= #lines do
            local chunk = lines[i]
            if lines[i + 1] then
              chunk = chunk .. "\n" .. lines[i + 1]
            end
            chunks[#chunks + 1] = chunk
            i = i + 2
          end
        end
      end
    end

    return table.concat(chunks, "\f")
  end

  local function say(game, text, onDone, opts)
    local top = game and game.stack and game.stack:top()
    if top and top._pokesimCampBackdrop then text = pacedDialogue(text) end
    game.stack:push(mod.ui.TextBox.new(game, text, onDone, opts))
  end

  local function returnToPokeSim(game)
    mod.ui.push(game, SCREEN)
  end


  local function addScrollArrow(menu)
    local originalDraw = menu.draw
    function menu:draw(...)
      originalDraw(self, ...)
      if (self.scroll + self.rows) < #self.items then
        love.graphics.setColor(0, 0, 0, 1)
        local Theme = require("src.ui.Theme")
        -- The game's normal more-below marker: charmap glyph $EE (▼).
        -- Same glyph/placement family used by ordinary Gen I text boxes.
        mod.ui.Font.drawCode(Theme.moreArrow or 0xEE, 144, 132)
      end
    end
    return menu
  end

  -- Mirrors Gen1Recomp's vanilla outdoor-map rule without importing
  -- private engine modules: authored maps may set def.outdoor directly;
  -- vanilla outdoor maps use the OVERWORLD tileset.
  local function campingAllowed(game)
    local ow = game and game.overworld
    local map = ow and ow.map
    local def = map and map.def
    local player = ow and ow.player
    if not def then return false, "YOU CAN'T CAMP\nHERE." end

    local outdoor = def.outdoor
    if outdoor == nil then outdoor = (def.tileset == "OVERWORLD") end

    -- Indigo Plateau / Route 23-style exterior maps use PLATEAU.
    if not outdoor and def.tileset ~= "PLATEAU" then
      return false, "YOU CAN ONLY CAMP\nOUTDOORS."
    end

    if player and player.surfing then
      return false, "YOU CAN'T SET UP\nCAMP ON WATER!"
    end

    if not campRestReady() then
      return false,
        "YOU'RE NOT READY\nTO CAMP AGAIN YET.\f" ..
        "KEEP TRAVELING\nFOR A WHILE."
    end

    return true
  end

  local function stopCampMusic()
    require("src.core.Music").stop()
  end

  local function restoreMapMusic(game)
    local ow = game and game.overworld
    if not ow or not ow.map then return end
    require("src.core.Music").playMap(
      game.data,
      ow.map.id,
      game.save and game.save.onBike,
      ow.player and ow.player.surfing
    )
  end

  local function leaveCampScene(game)
    -- TextBox has already popped itself before calling onDone, so the camp
    -- backdrop should now be the top state.
    local top = game.stack and game.stack:top()
    if top and top._pokesimCampBackdrop then
      game.stack:pop()
    end
    restoreMapMusic(game)
  end

  local function finishCamp(game, text)
    say(game, pacedDialogue(text), function()
      leaveCampScene(game)
      returnToPokeSim(game)
    end)
  end

  -- ================================================================
  -- PokeSim Scenario Engine v1
  --
  -- Scenarios are grouped by trigger ("camp" for now). Each scenario may
  -- define a weight, eligibility test, category, and run function.
  -- The same engine is intentionally reusable later for route travel,
  -- towns, caves, NPC conversations, and other living-world events.
  -- ================================================================
  local SCENARIOS = {}

  local function registerScenario(trigger, def)
    SCENARIOS[trigger] = SCENARIOS[trigger] or {}
    table.insert(SCENARIOS[trigger], def)
  end

  local function scenarioCount(id)
    return math.max(0, math.floor(
      tonumber(mod.save:get("scenario_count_" .. tostring(id), 0)) or 0
    ))
  end

  local function recordScenario(def)
    if not def or not def.id then return end
    mod.save:set(
      "scenario_count_" .. def.id,
      scenarioCount(def.id) + 1
    )
    local last1 = mod.save:get("scenario_last_id", "")
    local last2 = mod.save:get("scenario_prev_id", "")
    mod.save:set("scenario_prev2_id", last2)
    mod.save:set("scenario_prev_id", last1)
    mod.save:set("scenario_last_id", def.id)
  end

  local function leadPokemon(game)
    local party = game and game.save and game.save.party or {}
    return party and party[1] or nil
  end

  local function pokemonName(mon)
    if not mon then return "YOUR POKEMON" end
    if mon.name and mon.name ~= "" then return tostring(mon.name) end
    if mon.nickname and mon.nickname ~= "" then return tostring(mon.nickname) end
    if mon.def and mon.def.name then return tostring(mon.def.name) end
    return "YOUR POKEMON"
  end

  local function leadPokemonName(game)
    return pokemonName(leadPokemon(game))
  end

  local function totalFood()
    local n = 0
    for _, food in ipairs(FOODS) do
      n = n + foodCount(food.id)
    end
    return n
  end

  local function takeRandomFood()
    local available = {}
    for _, food in ipairs(FOODS) do
      if foodCount(food.id) > 0 then
        table.insert(available, food)
      end
    end
    if #available == 0 then return nil end

    local food = available[math.random(1, #available)]
    setFoodCount(food.id, foodCount(food.id) - 1)
    return food
  end

  local function campFoodState()
    if hunger() <= 0 then return "famished" end
    local food = totalFood()
    if food <= 0 then return "none" end
    if food <= 1 or hunger() <= 35 then return "low" end
    return "supplied"
  end

  local function randomPartyPokemon(game)
    local party = game and game.save and game.save.party or {}
    if #party == 0 then return nil end
    return party[math.random(1, #party)]
  end

  local function twoPartyPokemon(game)
    local party = game and game.save and game.save.party or {}
    if #party < 2 then return nil, nil end
    local a = math.random(1, #party)
    local b = math.random(1, #party - 1)
    if b >= a then b = b + 1 end
    return party[a], party[b]
  end

  local function damagePokemon(mon, amount)
    if not mon or type(mon.hp) ~= "number" then return 0 end
    local before = mon.hp
    mon.hp = math.max(1, mon.hp - math.max(1, math.floor(amount or 1)))
    return before - mon.hp
  end

  local function hasMajorStatus(mon)
    return mon and mon.status ~= nil and mon.status ~= false
      and mon.status ~= 0 and mon.status ~= ""
  end

  local Personality = (function()
    local API = {}
    local PERSONALITIES = {
      "LOYAL", "BOLD", "TIMID", "STUBBORN",
      "PLAYFUL", "INQUISITIVE", "LAZY", "AGGRESSIVE",
    }
    local DESC = {
      LOYAL = "PROTECTIVE AND DEVOTED",
      BOLD = "THRIVES ON DANGER",
      TIMID = "CAUTIOUS AND WATCHFUL",
      STUBBORN = "REFUSES TO BACK DOWN",
      PLAYFUL = "SOCIAL AND MISCHIEVOUS",
      INQUISITIVE = "ALWAYS INVESTIGATING",
      LAZY = "CALM AND LOW-ENERGY",
      AGGRESSIVE = "QUICK TO PICK A FIGHT",
    }
    local STEP_CHECK = 100
    local COOLDOWN = 225

    local function monName(game, mon)
      if not mon then return "POKEMON" end
      if mon.nickname and mon.nickname ~= "" then return tostring(mon.nickname) end
      local def = game and game.data and game.data.pokemon
        and game.data.pokemon[mon.species]
      return tostring((def and def.name) or mon.species or "POKEMON")
    end

    local function ensure(mon)
      if not mon then return nil end
      if not DESC[mon.pokesurvivePersonality] then
        mon.pokesurvivePersonality = PERSONALITIES[math.random(1, #PERSONALITIES)]
      end
      return mon.pokesurvivePersonality
    end

    local function ensureParty(game)
      if not game or not game.save then return end
      for _, mon in ipairs(game.save.party or {}) do ensure(mon) end
    end

    local function get(mon)
      return ensure(mon) or "UNKNOWN"
    end

    local function ready()
      return math.max(0, math.floor(
        tonumber(mod.save:get("adventure_event_cooldown", 0)) or 0
      )) <= 0
    end

    local function setCooldown(n)
      mod.save:set("adventure_event_cooldown",
        math.max(0, math.floor(tonumber(n) or COOLDOWN)))
    end

    local function livingParty(game)
      local out = {}
      for _, mon in ipairs((game and game.save and game.save.party) or {}) do
        if (tonumber(mon.hp) or 0) > 0 then out[#out + 1] = mon end
      end
      return out
    end

    local function abrasive(mon)
      local per = get(mon)
      return per == "AGGRESSIVE" or per == "STUBBORN" or per == "BOLD"
    end

    local AdventureScene = {}
    AdventureScene.__index = AdventureScene
    AdventureScene.isOpaque = false

    function AdventureScene.new(game, mons, text)
      local self = setmetatable({
        game = game,
        mons = mons or {},
        sprites = {},
        textbox = mod.ui.TextBox.new(game, text or ""),
      }, AdventureScene)

      local Sprites = require("src.pokemon.Sprites")
      for i, mon in ipairs(self.mons) do
        if mon and mon.species then
          local path, trueColor = Sprites.path(
            game.data,
            mon.species,
            "front",
            { mon = mon, kind = "overworld" }
          )
          if path then
            local ok, img = pcall(love.graphics.newImage, path)
            if ok and img then
              self.sprites[i] = {
                image = img,
                trueColor = trueColor and true or false,
              }
            end
          end
        end
      end

      return self
    end

    function AdventureScene:sgbPalettes(game)
      local P = require("src.render.PaletteFX")

      -- IMPORTANT: world and UI are separate render canvases. A full neutral
      -- UI zone does NOT recolor the overworld underneath. Without this base
      -- zone, unzoned UI pixels are discarded during the final palette blit,
      -- A neutral UI base is required so portrait frames and dialogue survive
      -- the final palette composition.
      local base = P.pal(game.data, "MEWMON") or P.ogBg()
      local zones = { P.whole(base) }

      -- Pokemon-specific zones override the neutral UI base only inside the
      -- portrait interiors.
      if #self.mons <= 1 then
        local mon = self.mons[1]
        if mon then
          zones[#zones + 1] =
            P.zone(P.monPal(game.data, mon.species), 6, 2, 12, 8)
        end
      else
        local left, right = self.mons[1], self.mons[2]
        if left then
          zones[#zones + 1] =
            P.zone(P.monPal(game.data, left.species), 1, 2, 7, 8)
        end
        if right then
          zones[#zones + 1] =
            P.zone(P.monPal(game.data, right.species), 12, 2, 18, 8)
        end
      end

      return zones
    end

    function AdventureScene:update(dt)
      -- The TextBox is embedded rather than pushed separately. Because this
      -- scene is the top state, the TextBox's normal completion pop removes
      -- the AdventureScene itself and returns directly to the overworld.
      if self.textbox and self.textbox.update then
        self.textbox:update(dt)
      end
    end

    function AdventureScene:draw()
      local Font = require("src.render.Font")
      local P = require("src.render.PaletteFX")

      -- Exact Gen I geometry:
      -- 9x9 tiles = 72x72 outer frame
      -- 1-tile border on each side = 56x56 interior
      -- which exactly matches a normal Pokemon front sprite.
      local function drawPortrait(rec, tx, ty, mirror)
        -- Font.drawBox preserves the caller's current color for its border
        -- Explicit black keeps the frame visible around the white portrait.
        love.graphics.setColor(0, 0, 0, 1)
        Font.drawBox(tx, ty, 9, 9)

        if not rec or not rec.image then return end

        local sw, sh = rec.image:getDimensions()

        -- Never scale the sprite. Standard Gen I front pics are 56x56, and
        -- smaller replacements simply center inside the 56x56 interior.
        local x = tx * 8 + 8 + math.floor((56 - sw) / 2)
        local y = ty * 8 + 8 + math.floor((56 - sh) / 2)

        love.graphics.setColor(1, 1, 1, 1)

        if mirror then
          love.graphics.draw(rec.image, x + sw, y, 0, -1, 1)
        else
          love.graphics.draw(rec.image, x, y)
        end

        if rec.trueColor then
          P.markTrueColor(x, y, sw, sh)
        end
      end

      if #self.sprites <= 1 then
        -- x=40..112, y=8..80: centered with a clean gap above dialogue.
        drawPortrait(self.sprites[1], 5, 1, false)
      else
        -- x=0..72 and x=88..160, leaving a 16px center gap.
        drawPortrait(self.sprites[1], 0, 1, true)
        drawPortrait(self.sprites[2], 11, 1, false)
      end

      -- Render the embedded TextBox manually instead of calling
      -- TextBox:draw(). TextBox:draw() registers a renderer UI anchor; that
      -- anchor path is intended for a top-level TextBox state and disappeared
      -- when embedded inside AdventureScene. We retain the real TextBox object
      -- for update/input/pagination and reproduce only its visual draw here.
      local tb = self.textbox
      if tb then
        local Theme = require("src.ui.Theme")

        love.graphics.setColor(0, 0, 0, 1)
        Font.drawBox(tb.boxTx, tb.boxTy, tb.boxTw, tb.boxTh)

        if tb.scrollPx and tb.scrollPx > 0 then
          tb.scrollPx = tb.scrollPx - 2
          if tb.scrollPx <= 0 then tb.scrollPx = nil end
        end

        local off = tb.scrollPx or 0
        local ys = { tb.line1Y, tb.line2Y }

        love.graphics.setColor(0, 0, 0, 1)
        for i, line in ipairs(tb.shown or {}) do
          local y = (ys[i] or tb.line2Y) + (i == 1 and off or 0)
          local pen = tb.textX

          for _, code in ipairs(line) do
            Font.drawCode(code, pen, y)
            pen = pen + Font.advanceOf(code)
          end
        end

        if (tb.waiting or
            (tb.done and not tb.choice and not tb.auto and not tb.stay))
          and (tb.blink or 0) < 30 then
          Font.drawCode(
            Theme.moreArrow or 0xEE,
            (tb.boxTx + tb.boxTw - 2) * 8,
            (tb.boxTy + tb.boxTh - 1) * 8 - 4
          )
        end
      end

      love.graphics.setColor(1, 1, 1, 1)
    end

    local function popup(game, text, mons)
      if not game or not game.stack or not game.overworld
        or game.stack:top() ~= game.overworld then return false end

      -- One top-level state owns portraits AND dialogue. This avoids the
      -- Keep portraits and dialogue in one state for stable draw order.
      local scene = AdventureScene.new(game, mons or {}, pacedDialogue(text))
      game.stack:push(scene)

      setCooldown()
      mod.save:set("adventure_area_counter", 0)
      mod.save:set("adventure_missed_checks", 0)
      return true
    end

    local function adventureEnvironment(game)
      local ow = game and game.overworld
      local map = ow and ow.map
      local def = map and map.def or {}
      if ow and ow.player and ow.player.surfing then return "water" end
      local ts = tostring(def.tileset or ""):upper()
      local id = tostring(map and map.id or ""):upper()
      if ts == "CAVERN" or id:find("CAVE",1,true) or id:find("TUNNEL",1,true) then return "cave" end
      if ts == "FOREST" or id:find("FOREST",1,true) then return "forest" end
      local outdoor = def.outdoor
      if outdoor == nil then outdoor = ts == "OVERWORLD" or ts == "PLATEAU" end
      if outdoor then
        if id:find("CITY",1,true) or id:find("TOWN",1,true) then return "town" end
        return "route"
      end
      return "indoors"
    end

    local function environmentEvent(game, party, env)
      local a = party[math.random(1,#party)]
      local an, ap = monName(game,a), get(a)
      local b = nil
      if #party > 1 then repeat b=party[math.random(1,#party)] until b~=a end
      local bn = b and monName(game,b) or ""
      local roll=math.random(1,100)

      if env=="route" or env=="forest" then
        -- Personality-specific discoveries still get first crack.
        if ap=="INQUISITIVE" and roll<=25 then
          local berry=(math.random(1,2)==1) and "red_berry" or "blue_berry"
          local label=(berry=="red_berry") and "Red berry" or "Blue berry"
          giveFood(berry,1)
          return popup(game,
            an.." searches the brush.\f"
              .."It returns carrying a "..label.."!\f"
              ..label.." +1",
            {a})
        end

        local options = {}

        local function addEnv(key, text, moraleChange, energyChange)
          options[#options + 1] = {
            key = key,
            text = text,
            morale = moraleChange or 0,
            energy = energyChange or 0,
          }
        end

        if b and ap=="PLAYFUL" then
          addEnv(
            "out_play_chase",
            an.." starts a chase with "..bn..".\f"
              .."The grass rustles everywhere.",
            1, -1
          )
        end

        -- Personality-specific roadbumps. These are rare within the already
        -- contextual event pool, but can have real survival consequences.
        if ap=="INQUISITIVE" and roll>=76 and roll<=84 then
          setEnergy(energy()-3)
          adjustMood(-1)
          return popup(game,
            an.." wanders out of sight while investigating something.\f"
              .."You spend a long time searching before you find it again.\f"
              .."Energy -3",
            {a})
        elseif ap=="BOLD" and roll>=85 and roll<=91 then
          local maxhp=(a.stats and (a.stats.maxhp or a.stats.hp)) or a.maxhp or 1
          local lost=damagePokemon(a,math.max(1,math.floor(maxhp*0.08)))
          adjustMood(-1)
          return popup(game,
            an.." charges into the brush after a wild Pokemon.\f"
              .."It comes back scratched up, but looking proud of itself.\f"
              ..an.." lost "..tostring(lost).." HP.",
            {a})
        elseif ap=="LAZY" and roll>=92 and roll<=96 and not a.status then
          a.status="sleep"
          setEnergy(energy()+1)
          return popup(game,
            an.." curls up in a comfortable patch of grass.\f"
              .."A minute later, it is completely asleep.\f"
              ..an.." fell asleep!",
            {a})
        end

        addEnv(
          "out_grass_watch",
          an.." stops to watch the grass move.\f"
            .."Whatever it was, it moves on."
        )
        addEnv(
          "out_breeze",
          an.." pauses as a breeze rolls through.\f"
            .."For a moment, the road feels peaceful.",
          1, 0
        )
        addEnv(
          "out_tracks",
          an.." notices fresh tracks beside the path.\f"
            .."They disappear into the distance."
        )
        addEnv(
          "out_sound",
          an.." perks up at a sound far ahead.\f"
            .."Nothing else seems to notice."
        )
        addEnv(
          "out_shade",
          an.." finds a patch of shade and lingers there.\f"
            .."You stop for a very short break.",
          0, 1
        )
        addEnv(
          "out_bug",
          an.." follows a tiny bug along the path.\f"
            .."It loses interest almost immediately."
        )
        addEnv(
          "out_scent",
          an.." catches an interesting scent on the wind.\f"
            .."It keeps sniffing as you walk."
        )
        addEnv(
          "out_clouds",
          an.." looks up at the clouds for a while.\f"
            .."You find yourself doing the same.",
          1, 0
        )
        addEnv(
          "out_stone",
          an.." nudges an oddly shaped stone with its foot.\f"
            .."Apparently it was not that interesting."
        )

        addEnv(
          "out_rest_heal",
          an.." finds a quiet place to relax for a few minutes.\f"
            .."The short rest seems to do it some good.",
          1, 1
        )
        addEnv(
          "out_thorns",
          an.." pushes through a patch of thorny brush.\f"
            .."It comes out with a few fresh scratches.",
          -1, 0
        )
        addEnv(
          "out_wild_scare",
          "A wild Pokemon bursts from cover near "..an..".\f"
            .."It vanishes before a real battle can start.",
          -1, -1
        )
        addEnv(
          "out_mud",
          an.." slips in a patch of mud.\f"
            .."Nobody is hurt, but the detour is tiring.",
          0, -1
        )
        addEnv(
          "out_water_break",
          an.." finds a clean little stream beside the path.\f"
            .."The party takes a quick breather.",
          1, 1
        )

        if env=="forest" then
          addEnv(
            "forest_canopy",
            an.." stares up into the canopy.\f"
              .."Something rustles high above."
          )
          addEnv(
            "forest_leaves",
            an.." disappears into a pile of leaves.\f"
              .."It emerges looking extremely pleased.",
            1, -1
          )
          addEnv(
            "forest_tree",
            an.." circles a large tree twice.\f"
              .."You have no idea what it was checking."
          )
        end

        local last1 = mod.save:get("adventure_env_last_1", "")
        local last2 = mod.save:get("adventure_env_last_2", "")
        local last3 = mod.save:get("adventure_env_last_3", "")
        local available = {}

        for _, event in ipairs(options) do
          if event.key ~= last1
            and event.key ~= last2
            and event.key ~= last3 then
            available[#available + 1] = event
          end
        end
        if #available == 0 then available = options end

        local event = available[math.random(1, #available)]
        mod.save:set("adventure_env_last_3", last2)
        mod.save:set("adventure_env_last_2", last1)
        mod.save:set("adventure_env_last_1", event.key)

        if event.morale ~= 0 then adjustMood(event.morale) end
        if event.energy ~= 0 then setEnergy(energy() + event.energy) end

        -- A few generic road events directly affect the participating Pokemon.
        local maxhp = (a.stats and (a.stats.maxhp or a.stats.hp)) or a.maxhp or 1
        local currenthp = (a.stats and a.stats.hp) or a.hp or maxhp

        if event.key == "out_rest_heal" or event.key == "out_water_break" then
          if currenthp > 0 then
            local heal = math.max(1, math.floor(maxhp * 0.06))
            if a.stats and a.stats.hp then
              a.stats.hp = math.min(maxhp, currenthp + heal)
            elseif a.hp then
              a.hp = math.min(maxhp, currenthp + heal)
            end
          end
        elseif event.key == "out_thorns" then
          damagePokemon(a, math.max(1, math.floor(maxhp * 0.05)))
        elseif event.key == "out_wild_scare" and math.random(1,100) <= 45 then
          damagePokemon(a, math.max(1, math.floor(maxhp * 0.06)))
        end

        return popup(game,event.text,{a})
      elseif env=="cave" then
        if ap=="BOLD" then setEnergy(energy()-1); return popup(game,an.." Wanders ahead\ninto the dark.\fIt returns before\nyou can worry.",{a}) end
        if b then return popup(game,an.." Makes a noise.\fThe echo startles\n"..bn..".",{a,b}) end
        return popup(game,an.." Studies the cave\nwall in silence.\fDrip... Drip... Drip.",{a})
      elseif env=="water" then
        if ap=="PLAYFUL" and b then adjustMood(1); return popup(game,an.." Splashes "..bn..".\f"..bn.." Splashes back.\nThis escalates.",{a,b}) end
        if ap=="TIMID" then return popup(game,an.." Keeps very still\nabove the water.\fIt does not trust\nthe waves.",{a}) end
        return popup(game,an.." Watches the water\npass below.\fSomething moves\ndeep underneath.",{a})
      elseif env=="indoors" then
        if ap=="LAZY" then return popup(game,an.." Finds the softest\nspot in the room.\fIt makes itself\nat home.",{a}) end
        if ap=="INQUISITIVE" then return popup(game,an.." Inspects every\npiece of furniture.\fNothing escapes\nits notice.",{a}) end
        return popup(game,an.." Looks around the\nunfamiliar room.\fIt stays close.",{a})
      elseif env=="town" then
        if ap=="TIMID" then return popup(game,an.." Presses closer\nin the crowd.\fThe town is a\nlittle much today.",{a}) end
        if b then return popup(game,an.." AND "..bn.."\nWatch people pass.\fPeople watch\nthem back.",{a,b}) end
      end
      return false
    end

    local function pairEvent(game, party)
      if #party < 2 then return false end

      local ai = math.random(1, #party)
      local bi = math.random(1, #party - 1)
      if bi >= ai then bi = bi + 1 end

      local a, b = party[ai], party[bi]
      local an, bn = monName(game, a), monName(game, b)
      local ap, bp = get(a), get(b)
      local hostileA = ap == "AGGRESSIVE" or ap == "STUBBORN" or ap == "BOLD"
      local hostileB = bp == "AGGRESSIVE" or bp == "STUBBORN" or bp == "BOLD"
      local gentleA = ap == "LOYAL" or ap == "TIMID" or ap == "LAZY"
      local gentleB = bp == "LOYAL" or bp == "TIMID" or bp == "LAZY"

      -- Rare physical squabble. This is deliberately uncommon and non-lethal.
      if hostileA and hostileB and math.random(1, 100) <= 10 then
        local ahp = (a.stats and a.stats.hp) or a.maxhp or 1
        local bhp = (b.stats and b.stats.hp) or b.maxhp or 1
        local da = damagePokemon(a, math.max(1, math.floor(ahp * math.random(4, 7) / 100)))
        local db = damagePokemon(b, math.max(1, math.floor(bhp * math.random(4, 7) / 100)))
        adjustMood(-2)
        setEnergy(energy() - 1)
        return popup(game,
          an .. " and " .. bn .. " start bickering.\f"
            .. "Neither one wants to back down.\f"
            .. "They lose " .. tostring(da) .. " and " .. tostring(db) .. " HP.",
          { a, b })
      end

      local choices = {}
      local function add(key, text, morale, hungerChange, energyChange)
        choices[#choices + 1] = {
          key = key, text = text,
          morale = morale or 0,
          hunger = hungerChange or 0,
          energy = energyChange or 0,
        }
      end

      if (ap == "PLAYFUL" and bp == "LAZY") or (bp == "PLAYFUL" and ap == "LAZY") then
        local playful = ap == "PLAYFUL" and an or bn
        local lazy = ap == "LAZY" and an or bn
        add("play_lazy_1", playful .. " keeps trying to play with " .. lazy .. ".\f" .. lazy .. " keeps pretending not to notice.", 1)
        add("play_lazy_2", playful .. " finally convinces " .. lazy .. " to join a short chase.\f" .. "It does not last very long.", 2, 0, -1)
        add("play_lazy_3", playful .. " drops a stick beside " .. lazy .. " and waits.\f" .. lazy .. " slowly pushes it back.", 1)
        add("play_lazy_4", lazy .. " lies down.\f" .. playful .. " decides this means climbing on top of them.", 1, 0, 1)
        add("play_lazy_5", playful .. " circles " .. lazy .. " again and again.\f" .. lazy .. " responds with an enormous yawn.", 1)
      elseif ap == "PLAYFUL" or bp == "PLAYFUL" then
        local playful = ap == "PLAYFUL" and an or bn
        local other = ap == "PLAYFUL" and bn or an
        add("play_1", playful .. " darts around " .. other .. ".\f"
          .. other .. " joins in, and a game quickly breaks out.", 1)
        add("play_2", playful .. " steals a leaf from " .. other .. ".\f" .. "A short chase breaks out.", 2, 0, -1)
        add("play_3", playful .. " trips over its own feet in front of " .. other .. ".\f"
          .. other .. " stares for a moment, then starts playing too.", 2)
        add("play_4", playful .. " nudges " .. other .. " from behind.\f"
          .. other .. " turns around while " .. playful .. " tries to look innocent.", 1)
        add("play_5", playful .. " hides behind you while " .. other .. " searches for it.\f"
          .. other .. " very clearly knows where it went.", 1, 0, -1)
      elseif ap == "INQUISITIVE" or bp == "INQUISITIVE" then
        local curious = ap == "INQUISITIVE" and an or bn
        local other = ap == "INQUISITIVE" and bn or an
        add("inq_1", curious .. " stops to examine " .. other .. ".\f" .. other .. " looks a little confused by the inspection.")
        add("inq_2", curious .. " leads " .. other .. " a short way off the path.\f" .. "They return carrying a few edible berries.", 1, 3)
        add("inq_3", curious .. " finds an odd trail in the dirt.\f" .. other .. " helps follow it for a while.", 1, 0, -1)
        add("inq_4", curious .. " becomes fascinated by " .. other .. "'s footprints.\f" .. other .. " keeps walking anyway.", 1)
        add("inq_5", curious .. " investigates a strange smell.\f" .. other .. " wisely keeps a little distance.", -1, 0, -2)
      elseif ap == "LOYAL" or bp == "LOYAL" then
        local loyal = ap == "LOYAL" and an or bn
        local other = ap == "LOYAL" and bn or an
        add("loyal_1", loyal .. " checks on " .. other .. ".\f" .. "The two walk together for a while.", 2)
        add("loyal_2", loyal .. " brushes some dirt off " .. other .. ".\f" .. other .. " seems to appreciate it.", 2)
        add("loyal_3", loyal .. " insists on a short rest beside " .. other .. ".\f" .. "The break does everyone some good.", 1, 0, 2)
        add("loyal_4", loyal .. " waits when " .. other .. " falls behind.\f" .. "Nobody gets left alone.", 1)
        add("loyal_5", loyal .. " keeps glancing back at " .. other .. ".\f" .. "Apparently a head count is necessary.", 1)
      elseif (ap == "TIMID" and hostileB) or (bp == "TIMID" and hostileA) then
        local timid = ap == "TIMID" and an or bn
        local rough = ap == "TIMID" and bn or an
        add("timid_rough_1", rough .. " gets a little too close to " .. timid .. ".\f" .. timid .. " quickly moves to your other side.", -1)
        add("timid_rough_2", timid .. " flinches when " .. rough .. " approaches.\f" .. rough .. " notices and backs off.")
        add("timid_rough_3", rough .. " stomps past " .. timid .. ".\f" .. timid .. " waits several seconds before following.")
        add("timid_rough_4", timid .. " keeps watching " .. rough .. " from a safe distance.\f" .. rough .. " pretends not to notice.")
        add("timid_rough_5", rough .. " growls at a distant noise.\f" .. timid .. " immediately presses closer to you.")
      elseif gentleA and gentleB then
        add("gentle_1", an .. " and " .. bn .. " fall into step.\f" .. "They seem comfortable traveling together.", 1)
        add("gentle_2", an .. " and " .. bn .. " stop for a quiet rest.\f" .. "You take the chance to rest too.", 1, 0, 2)
        add("gentle_3", an .. " walks close beside " .. bn .. ".\f" .. "Neither seems in any hurry.", 1)
        add("gentle_4", an .. " and " .. bn .. " exchange a quiet look.\f" .. "Whatever that meant, they seem satisfied.", 1)
        add("gentle_5", an .. " waits for " .. bn .. " to catch up.\f" .. "The party moves on together.", 1)
      elseif hostileA and hostileB then
        add("rough_1", an .. " and " .. bn .. " keep glancing at each other.\f" .. "Neither wants to look away first.")
        add("rough_2", an .. " and " .. bn .. " race for the lead.\f" .. "You have to hurry to keep up.", 1, 0, -2)
        add("rough_3", an .. " bumps into " .. bn .. ".\f" .. "For a second, the entire party goes very quiet.", -1)
        add("rough_4", an .. " and " .. bn .. " compete over who walks in front.\f" .. "Nobody wins.", 0, 0, -1)
        add("rough_5", an .. " challenges " .. bn .. " with a stare.\f" .. bn .. " answers with one of its own.")
      elseif ap == "STUBBORN" or bp == "STUBBORN" then
        local stubborn = ap == "STUBBORN" and an or bn
        local other = ap == "STUBBORN" and bn or an
        add("stub_1", stubborn .. " and " .. other .. " disagree about the path.\f" .. "Eventually, one of them gives in.")
        add("stub_2", stubborn .. " refuses to leave a good resting spot.\f" .. other .. " eventually sits down too.", 0, 0, 2)
        add("stub_3", stubborn .. " plants its feet and stares at " .. other .. ".\f" .. other .. " walks around it.", 0, 0, 1)
        add("stub_4", other .. " tries to hurry " .. stubborn .. " along.\f" .. "This has the opposite effect.")
        add("stub_5", stubborn .. " insists on taking the difficult side of the path.\f" .. other .. " follows, for some reason.", 0, 0, -1)
      elseif ap == "BOLD" or bp == "BOLD" then
        local bold = ap == "BOLD" and an or bn
        local other = ap == "BOLD" and bn or an
        add("bold_1", bold .. " races ahead.\f" .. other .. " hurries after it.", 0, 0, -1)
        add("bold_2", bold .. " takes point with " .. other .. " close behind.\f" .. "Their confidence is a little contagious.", 2)
        add("bold_3", bold .. " leaps over an obstacle just to show it can.\f" .. other .. " takes the normal route.", 1, 0, -2)
        add("bold_4", bold .. " pauses dramatically at the front of the group.\f" .. other .. " walks straight past.")
        add("bold_5", bold .. " dares " .. other .. " into a short race.\f" .. "They both look pleased afterward.", 1, 0, -1)
      elseif ap == "AGGRESSIVE" or bp == "AGGRESSIVE" then
        local rough = ap == "AGGRESSIVE" and an or bn
        local other = ap == "AGGRESSIVE" and bn or an
        add("agg_1", rough .. " shoves past " .. other .. ".\f" .. other .. " does not look impressed.", -1)
        add("agg_2", rough .. " challenges " .. other .. " to a race.\f" .. "They burn off some extra energy.", 0, 0, -2)
        add("agg_3", rough .. " growls at " .. other .. " for no obvious reason.\f" .. other .. " ignores it.", -1)
        add("agg_4", other .. " steps into " .. rough .. "'s path.\f" .. "There is a long, awkward pause.")
        add("agg_5", rough .. " kicks dirt behind itself.\f" .. other .. " very deliberately moves farther away.")
      elseif ap == "LAZY" or bp == "LAZY" then
        local lazy = ap == "LAZY" and an or bn
        local other = ap == "LAZY" and bn or an
        add("lazy_1", lazy .. " slows to a crawl.\f" .. other .. " waits patiently for it to catch up.")
        add("lazy_2", lazy .. " finds a nice place to sit.\f" .. other .. " joins it, so you rest too.", 0, 0, 2)
        add("lazy_3", other .. " keeps looking back for " .. lazy .. ".\f" .. lazy .. " is absolutely taking its time.", 0, 0, 1)
        add("lazy_4", lazy .. " stops in a patch of shade.\f" .. other .. " seems to agree with the decision.", 1, 0, 2)
        add("lazy_5", lazy .. " yawns at " .. other .. ".\f" .. "A few seconds later, " .. other .. " yawns too.")
      else
        add("neutral_1", an .. " and " .. bn .. " walk side by side.\f" .. "Nothing much happens. That's nice too.")
        add("neutral_2", an .. " and " .. bn .. " share a quiet moment.\f" .. "The party seems a little more at ease.", 1)
        add("neutral_3", an .. " falls into step behind " .. bn .. ".\f" .. "They travel like that for a while.", 1)
        add("neutral_4", an .. " and " .. bn .. " both stop at the same sound.\f" .. "Neither finds anything unusual.")
        add("neutral_5", an .. " glances at " .. bn .. ".\f" .. bn .. " glances back. That seems to settle something.")
      end

      local last1 = mod.save:get("adventure_last_pair_key", "")
      local last2 = mod.save:get("adventure_prev_pair_key", "")
      local last3 = mod.save:get("adventure_prev2_pair_key", "")

      local available = {}
      for _, event in ipairs(choices) do
        if event.key ~= last1 and event.key ~= last2 and event.key ~= last3 then
          available[#available + 1] = event
        end
      end
      if #available == 0 then
        -- If a very small eligibility pool ever exists, at minimum block the
        -- immediate repeat and relax the older-history exclusions.
        for _, event in ipairs(choices) do
          if event.key ~= last1 then available[#available + 1] = event end
        end
      end
      if #available == 0 then available = choices end

      local event = available[math.random(1, #available)]
      mod.save:set("adventure_prev2_pair_key", last2)
      mod.save:set("adventure_prev_pair_key", last1)
      mod.save:set("adventure_last_pair_key", event.key)

      if event.morale ~= 0 then adjustMood(event.morale) end
      if event.hunger ~= 0 then setHunger(hunger() + event.hunger) end
      if event.energy ~= 0 then setEnergy(energy() + event.energy) end

      -- Pair scenes should only show both portraits when both Pokemon are
      -- actually part of the written interaction. This also guards future
      -- event additions from accidental portrait photobombs.
      local shown = { a, b }
      local aNamed = tostring(event.text):find(an, 1, true) ~= nil
      local bNamed = tostring(event.text):find(bn, 1, true) ~= nil
      if aNamed and not bNamed then
        shown = { a }
      elseif bNamed and not aNamed then
        shown = { b }
      end

      return popup(game, event.text, shown)
    end

    local function walkingEvent(game, mode)
      if not ready() or not game or not game.overworld
        or game.stack:top() ~= game.overworld then return false end

      ensureParty(game)
      local party = livingParty(game)
      if #party == 0 then return false end

      -- Once an Adventure Event has triggered, relationships are now the
      -- main presentation: 60% pair scene, 40% individual personality scene.
      if mode == "pair" then
        if #party >= 2 then return pairEvent(game, party) end
      elseif mode ~= "solo" then
        local env = adventureEnvironment(game)
        if math.random(1,100) <= 45 then
          local handled = environmentEvent(game,party,env)
          if handled then return handled end
        end
        if #party >= 2 and math.random(1, 100) <= 60 then
          return pairEvent(game, party)
        end
      end

      local mon = party[math.random(1, #party)]
      local name, per = monName(game, mon), get(mon)
      local lines = {
        LOYAL = {
          name .. " stays close\nto your side.\fIt seems content\njust being there.",
          name .. " keeps glancing\nback at the party.\fIt seems to be\ncounting everyone.",
          name .. " waits for you\nat every turn.\fIt refuses to let\nyou fall behind.",
          name .. " brushes against\nyour leg.\fA quick check-in,\nthen onward.",
        },
        BOLD = {
          name .. " charges ahead\nfor a moment.\fIt returns looking\nvery pleased with itself.",
          name .. " stares down a\nnoise in the brush.\fThe noise decides\nto leave first.",
          name .. " climbs up high\nto survey the path.\fIt looks very proud\nof the view.",
          name .. " struts past a\nwild Pokemon's tracks.\fApparently it is\nnot impressed.",
        },
        TIMID = {
          name .. " suddenly stops\nand listens.\fAfter a moment, it\nrelaxes again.",
          name .. " walks a little\ncloser to you.\fSomething seems to\nhave spooked it.",
          name .. " hides behind you\nat a distant sound.\fIt peeks out after\na few seconds.",
          name .. " startles at its\nown shadow.\f...It hopes you didn't\nnotice.",
        },
        STUBBORN = {
          name .. " refuses to move\nfor a moment.\f...Then continues as\nif nothing happened.",
          name .. " takes the most\ndifficult path possible.\fOf course it does.",
          name .. " insists on walking\non the wrong side.\fYou decide this is\nnot worth the fight.",
          name .. " stops at a fork\nand picks a direction.\fIt looks at you like\nthat settles it.",
        },
        PLAYFUL = {
          name .. " darts around\nyour feet.\fIt seems to have\ninvented a game.",
          name .. " hides behind\nsomething nearby.\f...It is not very\ngood at hiding.",
          name .. " tosses a stick\ninto the air.\fThen chases it like\nsomeone else threw it.",
          name .. " circles you twice\nfor no clear reason.\fApparently that was\nvery important.",
        },
        INQUISITIVE = {
          name .. " stops to examine\nsomething tiny.\fWhatever it is, it\nseems fascinating.",
          name .. " keeps peeking into\nevery nook you pass.\fIt doesn't want to\nmiss anything.",
          name .. " taps at an odd\nmark on the ground.\fIt studies your face\nfor an explanation.",
          name .. " follows a tiny\ntrail off the path.\fIt returns looking\nvery satisfied.",
        },
        LAZY = {
          name .. " finds a sunny spot\nand flops down.\fYou wait a moment\nfor it to catch up.",
          name .. " yawns so widely\nyou have to laugh.\fIt looks ready for\na nap already.",
          name .. " sits down the second\nyou stop walking.\fIt was clearly waiting\nfor an excuse.",
          name .. " tries to nap while\nstill standing.\fThe attempt is...\nNot successful.",
        },
        AGGRESSIVE = {
          name .. " growls at something\noff the path.\fNothing takes it up\non the challenge.",
          name .. " practices attacking\na fallen branch.\fThe branch loses.",
          name .. " kicks dirt at a\ndistant noise.\fThe noise does not\nrespond.",
          name .. " paces around the\nedge of the group.\fIt looks ready for\ntrouble.",
        },
      }
      local options = lines[per] or { name .. " seems lost\nin thought." }

      local baseKey = "adventure_solo_" .. tostring(per):lower()
      local last1 = math.max(0, math.floor(tonumber(mod.save:get(baseKey .. "_1", 0)) or 0))
      local last2 = math.max(0, math.floor(tonumber(mod.save:get(baseKey .. "_2", 0)) or 0))
      local last3 = math.max(0, math.floor(tonumber(mod.save:get(baseKey .. "_3", 0)) or 0))

      local available = {}
      for i = 1, #options do
        if i ~= last1 and i ~= last2 and i ~= last3 then
          available[#available + 1] = i
        end
      end
      if #available == 0 then
        for i = 1, #options do
          if i ~= last1 then available[#available + 1] = i end
        end
      end
      if #available == 0 then available[1] = 1 end

      local pick = available[math.random(1, #available)]
      mod.save:set(baseKey .. "_3", last2)
      mod.save:set(baseKey .. "_2", last1)
      mod.save:set(baseKey .. "_1", pick)

      -- Solo personality scenes now have small consequences often enough to
      -- matter, while still leaving some pure flavor results in the pool.
      if per == "LOYAL" then
        if pick == 1 or pick == 3 or pick == 4 then adjustMood(1) end
      elseif per == "BOLD" then
        if pick == 1 or pick == 3 then setEnergy(energy() - 1) end
        if pick == 2 or pick == 4 then adjustMood(1) end
      elseif per == "TIMID" then
        if pick == 2 or pick == 3 or pick == 4 then adjustMood(-1) end
      elseif per == "STUBBORN" then
        if pick == 2 then setEnergy(energy() - 1) end
        if pick == 4 then adjustMood(1) end
      elseif per == "PLAYFUL" then
        if pick == 1 or pick == 3 or pick == 4 then adjustMood(1) end
        if pick == 1 or pick == 3 then setEnergy(energy() - 1) end
      elseif per == "INQUISITIVE" then
        if pick == 1 or pick == 2 or pick == 3 then adjustMood(1) end
        if pick == 4 then setEnergy(energy() - 1) end
      elseif per == "LAZY" then
        if pick == 1 or pick == 3 then setEnergy(energy() + 1) end
      elseif per == "AGGRESSIVE" then
        if pick == 2 or pick == 3 or pick == 4 then setEnergy(energy() - 1) end
        if pick == 1 then adjustMood(-1) end
      end

      return popup(game, options[pick], { mon })
    end

    mod.events:on("world.stepped", function(ev)
      if not pokesimEnabled() then return end

      -- Some world.stepped emissions do not carry ev.game consistently.
      -- Use the authoritative active Game singleton instead.
      local game = require("src.core.Game")
      if not game or not game.save or not game.overworld then return end
      ensureParty(game)

      local cd = math.max(0, math.floor(
        tonumber(mod.save:get("adventure_event_cooldown", 0)) or 0))
      if cd > 0 then
        cd = cd - 1
        mod.save:set("adventure_event_cooldown", cd)
      end

      local steps = math.max(0, math.floor(
        tonumber(mod.save:get("adventure_step_clock", 0)) or 0)) + 1

      if steps >= STEP_CHECK then
        steps = steps - STEP_CHECK

        local pending = mod.save:get("adventure_event_pending", false) == true
        if ready() and not pending and #(game.save.party or {}) > 0 then
          local misses = math.max(0, math.floor(
            tonumber(mod.save:get("adventure_missed_checks", 0)) or 0))
          local chances = { 35, 60, 85, 100 }
          local chance = chances[math.min(#chances, misses + 1)]

          if math.random(1, 100) <= chance then
            mod.save:set("adventure_event_pending", true)
            mod.save:set("adventure_missed_checks", 0)
          else
            mod.save:set("adventure_missed_checks", misses + 1)
          end
        end
      end

      mod.save:set("adventure_step_clock", steps)
    end, -80)

    mod.events:on("pokemon.caught", function(ev)
      if not pokesimEnabled() then return end
      local mon = ev and (ev.mon or ev.pokemon)
      if mon then ensure(mon) end
      local game = ev and (ev.game or (ev.battle and ev.battle.game))
      if game then ensureParty(game) end
    end, -80)

    API.ensure = ensure
    API.ensureParty = ensureParty
    API.get = get
    API.name = monName
    API.desc = function(per) return DESC[per] or "AN INDIVIDUAL SPIRIT." end
    API.testEvent = function(game)
      if not game or not game.save or #(game.save.party or {}) == 0 then
        return false
      end
      ensureParty(game)
      mod.save:set("adventure_event_cooldown", 0)
      mod.save:set("adventure_event_pending", false)
      return walkingEvent(game, "solo")
    end
    API.testPair = function(game)
      if not game or not game.save then return false end
      ensureParty(game)
      local party = livingParty(game)
      if #party < 2 then return false end
      mod.save:set("adventure_event_cooldown", 0)
      mod.save:set("adventure_event_pending", false)
      return pairEvent(game, party)
    end

    API.queueNatural = function()
      if not ready() then return false end
      if mod.save:get("adventure_event_pending", false) == true then
        return false
      end
      mod.save:set("adventure_event_pending", true)
      return true
    end

    API.servicePending = function(game)
      if mod.save:get("adventure_event_pending", false) ~= true then
        return false
      end
      if not game or not game.overworld or not game.stack
        or game.stack:top() ~= game.overworld then
        return false
      end

      -- Clear only after the scene successfully opens. If another engine
      -- state is temporarily above the overworld, the event remains queued.
      if walkingEvent(game) then
        mod.save:set("adventure_event_pending", false)
        return true
      end
      return false
    end
    return API
  end)()

  local function chooseScenario(trigger, ctx)
    local pool = SCENARIOS[trigger] or {}
    local choices = {}
    local totalWeight = 0
    local lastId = mod.save:get("scenario_last_id", "")
    local prevId = mod.save:get("scenario_prev_id", "")
    local prev2Id = mod.save:get("scenario_prev2_id", "")

    for _, def in ipairs(pool) do
      local eligible = (not def.eligible) or def.eligible(ctx)
      if eligible then
        local weight = tonumber(def.weight or 1) or 1

        -- Supplies, not Mood, influence the risk profile of camping.
        local fs = ctx and ctx.foodState
        if def.category == "negative" then
          if fs == "low" then weight = math.floor(weight * 1.35)
          elseif fs == "none" then weight = math.floor(weight * 1.75)
          elseif fs == "famished" then weight = math.floor(weight * 2.25) end
        elseif def.category == "positive" then
          if fs == "none" then weight = math.max(1, math.floor(weight * 0.80))
          elseif fs == "famished" then weight = math.max(1, math.floor(weight * 0.65)) end
        end

        -- CURIOUS actively pulls the trainer toward investigation-style
        -- camp events instead of functioning as a generic stat buff.
        if ctx and ctx.mood == "CURIOUS" and def.investigation then
          weight = math.max(1, math.floor(weight * 2.50))
        elseif ctx and ctx.mood == "UNEASY" then
          -- Caution favors quiet/positive nights and suppresses trouble.
          if def.category == "negative" then
            weight = math.max(1, math.floor(weight * 0.70))
          elseif def.category == "neutral" or def.category == "positive" then
            weight = math.max(1, math.floor(weight * 1.25))
          end
        elseif ctx and ctx.mood == "CONFIDENT" then
          -- Confidence makes the trainer more willing to have an eventful night.
          if def.category == "rare" then
            weight = math.max(1, math.floor(weight * 1.60))
          elseif def.category == "positive" then
            weight = math.max(1, math.floor(weight * 1.20))
          end
        elseif ctx and ctx.mood == "ANGRY" then
          -- Anger makes tense/negative camp situations more likely to bubble up.
          if def.category == "negative" then
            weight = math.max(1, math.floor(weight * 1.45))
          elseif def.category == "positive" then
            weight = math.max(1, math.floor(weight * 0.80))
          end
        end

        -- Immediate repeats are possible, but strongly discouraged so
        -- camping doesn't feel like the same textbox on loop.
        if def.id == lastId then
          weight = math.max(1, math.floor(weight * 0.03))
        elseif def.id == prevId then
          weight = math.max(1, math.floor(weight * 0.08))
        elseif def.id == prev2Id then
          weight = math.max(1, math.floor(weight * 0.15))
        end

        if weight > 0 then
          totalWeight = totalWeight + weight
          table.insert(choices, { def = def, ceiling = totalWeight })
        end
      end
    end

    if #choices == 0 or totalWeight <= 0 then return nil end

    local roll = math.random(1, totalWeight)
    for _, choice in ipairs(choices) do
      if roll <= choice.ceiling then return choice.def end
    end
    return choices[#choices].def
  end

  local function runScenario(trigger, ctx)
    local def = chooseScenario(trigger, ctx)
    if not def then
      finishCamp(ctx.game, "THE NIGHT PASSES\nWITHOUT INCIDENT.")
      return
    end

    recordScenario(def)
    def.run(ctx)
  end

  -- -------------------------- CAMP SCENARIOS -----------------------

  registerScenario("camp", {
    id = "peaceful_night",
    category = "neutral",
    weight = 12,
    run = function(ctx)
      setTemporaryMood("RELAXED")
      finishCamp(ctx.game,
        "The night passes\npeacefully.\f" ..
        "You wake feeling\nat ease.")
    end,
  })

  registerScenario("camp", {
    id = "clear_skies",
    category = "positive",
    weight = 10,
    run = function(ctx)
      setTemporaryMood("RELAXED")
      finishCamp(ctx.game,
        "The clouds part.\f" ..
        "Stars fill the\nnight sky.\f" ..
        "You watch them\nfor a while.")
    end,
  })

  registerScenario("camp", {
    id = "pokemon_companion",
    category = "positive",
    weight = 10,
    eligible = function(ctx)
      return leadPokemon(ctx.game) ~= nil
    end,
    run = function(ctx)
      local name = leadPokemonName(ctx.game)
      setTemporaryMood("HAPPY")
      finishCamp(ctx.game,
        name .. " Sits beside\nyou by the fire.\f" ..
        "You enjoy the\nquiet together.")
    end,
  })

  registerScenario("camp", {
    id = "traveler_shares_food",
    category = "positive",
    weight = 8,
    run = function(ctx)
      giveFood("sandwich", 1)
      if math.random(1, 100) <= 18 then
        setTemporaryMood("THRIFTY", 260)
      else
        setTemporaryMood("HAPPY")
      end
      finishCamp(ctx.game,
        "A traveler stops\nat your fire.\f" ..
        "You trade stories\nfor a while.\f" ..
        "Before leaving,\nthey share food.\f" ..
        "Sandwich +1")
    end,
  })

  registerScenario("camp", {
    id = "pokemon_finds_supplies",
    investigation = true,
    category = "positive",
    weight = 8,
    eligible = function(ctx)
      return leadPokemon(ctx.game) ~= nil
    end,
    run = function(ctx)
      local name = leadPokemonName(ctx.game)
      giveFood("trail_mix", 1)
      if math.random(1, 100) <= 28 then
        setTemporaryMood("THRIFTY", 320)
      else
        setTemporaryMood("CURIOUS")
      end
      finishCamp(ctx.game,
        name .. " Wanders off\nfor a moment.\f" ..
        "It returns with\nsome trail mix!\f" ..
        "Trail mix +1")
    end,
  })

  registerScenario("camp", {
    id = "rustling_brush",
    investigation = true,
    category = "neutral",
    weight = 10,
    run = function(ctx)
      local game = ctx.game
      say(game,
        "Something rustles\nin the brush.\f" ..
        "Investigate?",
        nil,
        {
          defaultNo = true,
          choice = function(yes)
            if not yes then
              setTemporaryMood("UNEASY")
              finishCamp(game,
                "You stay near\nthe fire.\f" ..
                "The noise fades,\neventually.")
              return
            end

            local roll = math.random(1, 3)
            if roll == 1 then
              giveFood("trail_mix", 1)
              setTemporaryMood("CURIOUS")
              finishCamp(game,
                "You search the\nbrush.\f" ..
                "Somebody left\nsupplies behind!\f" ..
                "Trail mix +1")
            elseif roll == 2 then
              setTemporaryMood("HAPPY")
              finishCamp(game,
                "A rattata bolts\nfrom the brush.\f" ..
                "You can't help\nbut laugh.")
            else
              setTemporaryMood("UNEASY")
              finishCamp(game,
                "Two eyes stare\nback at you.\f" ..
                "You return to\nthe fire.")
            end
          end,
        })
    end,
  })

  registerScenario("camp", {
    id = "restless_night",
    category = "negative",
    weight = 8,
    run = function(ctx)
      setEnergy(70)
      setTemporaryMood("UNEASY")
      finishCamp(ctx.game,
        "Something howls\nin the distance.\f" ..
        "You toss and turn\nthrough the night.\f" ..
        "Energy recovers\nonly to 70.")
    end,
  })

  registerScenario("camp", {
    id = "bad_dreams",
    category = "negative",
    weight = 6,
    run = function(ctx)
      setEnergy(80)
      setTemporaryMood("SAD")
      finishCamp(ctx.game,
        "Your sleep is full\nof bad dreams.\f" ..
        "Morning comes\ntoo soon.\f" ..
        "Energy recovers\nonly to 80.")
    end,
  })

  registerScenario("camp", {
    id = "missing_supplies",
    category = "negative",
    weight = 7,
    eligible = function(ctx)
      return totalFood() > 0
    end,
    run = function(ctx)
      local lost = takeRandomFood()
      setTemporaryMood("ANGRY")
      finishCamp(ctx.game,
        "Something got into\nyour supplies!\f" ..
        "ONE " .. foodLabel(lost) .. "\nIs gone.\f" ..
        "...Great.")
    end,
  })

  registerScenario("camp", {
    id = "strange_lights",
    investigation = true,
    category = "rare",
    weight = 3,
    run = function(ctx)
      local game = ctx.game
      say(game,
        "Strange lights move\nabove the trees.\f" ..
        "Keep watching?",
        nil,
        {
          choice = function(yes)
            if yes then
              setTemporaryMood("CURIOUS")
              finishCamp(game,
                "The lights drift\nacross the sky.\f" ..
                "Then they vanish.\f" ..
                "You never learn\nwhat they were.")
            else
              setTemporaryMood("UNEASY")
              finishCamp(game,
                "You turn away\nfrom the sky.\f" ..
                "Sleep doesn't\ncome easily.")
            end
          end,
        })
    end,
  })

  registerScenario("camp", {
    id = "share_camp_meal",
    category = "positive",
    weight = 6,
    eligible = function(ctx)
      return foodCount("camp_meal") > 0 and hunger() < 90
    end,
    run = function(ctx)
      local game = ctx.game
      say(game,
        "A camp meal would\nhit the spot.\f" ..
        "Eat one?",
        nil,
        {
          choice = function(yes)
            if not yes then
              finishCamp(game,
                "You save it\nfor later.")
              return
            end

            local restored = eatFood(FOODS[3])
            setTemporaryMood("HAPPY")
            finishCamp(game,
              "You eat a warm\ncamp meal.\f" ..
              "Restored " .. tostring(restored) .. "\nHunger.")
          end,
        })
    end,
  })

  registerScenario("camp", {
    id = "sudden_rain",
    category = "negative",
    weight = 7,
    run = function(ctx)
      local game = ctx.game
      say(game,
        "Rain starts falling\nhard.\f" ..
        "Stay up and secure\nthe camp?",
        nil,
        {
          choice = function(yes)
            if yes then
              setEnergy(85)
              setTemporaryMood("FOCUSED")
              finishCamp(game,
                "You keep your\ncamp dry.\f" ..
                "You lose some\nsleep doing it.\f" ..
                "Energy recovers\nonly to 85.")
            else
              setEnergy(65)
              setTemporaryMood("SAD")
              finishCamp(game,
                "You try to\nsleep through it.\f" ..
                "Everything is\ndamp by morning.\f" ..
                "Energy recovers\nonly to 65.")
            end
          end,
        })
    end,
  })

  registerScenario("camp", {
    id = "hungry_at_night",
    category = "neutral",
    weight = 8,
    eligible = function(ctx)
      return hunger() < 55 and foodCount("trail_mix") > 0
    end,
    run = function(ctx)
      local game = ctx.game
      say(game,
        "Your stomach\ngrowls.\f" ..
        "Eat some\ntrail mix?",
        nil,
        {
          choice = function(yes)
            if not yes then
              setTemporaryMood("SAD")
              finishCamp(game,
                "You decide to\nsave your food.")
              return
            end

            local restored = eatFood(FOODS[2])
            setTemporaryMood("HAPPY")
            finishCamp(game,
              "You have a\nlate-night snack.\f" ..
              "Restored " .. tostring(restored) .. "\nHunger.")
          end,
        })
    end,
  })

  registerScenario("camp", {
    id = "hungry_pokemon",
    category = "negative",
    weight = 10,
    eligible = function(ctx)
      return leadPokemon(ctx.game) ~= nil
        and (ctx.foodState == "none" or ctx.foodState == "famished")
    end,
    run = function(ctx)
      local mon = randomPartyPokemon(ctx.game)
      local name = pokemonName(mon)
      local base = tonumber(mon.maxHp or mon.hp or 10) or 10
      local lost = damagePokemon(mon, math.max(1, math.floor(base * 0.10)))
      setTemporaryMood("SAD")
      local middle
      if ctx.foodState == "famished" then
        middle = "Everyone is\nrunning on empty."
      elseif ctx.foodState == "none" then
        middle = "There wasn't\nenough food tonight."
      else
        middle = name .. " Didn't eat\nmuch tonight."
      end
      finishCamp(ctx.game,
        name .. " Can't seem\nto settle down.\f" ..
        middle .. "\f" ..
        name .. " Lost " .. tostring(lost) .. "\nHP.")
    end,
  })

  registerScenario("camp", {
    id = "desperate_hunger",
    category = "negative",
    weight = 5,
    eligible = function(ctx)
      return leadPokemon(ctx.game) ~= nil and ctx.foodState == "famished"
    end,
    run = function(ctx)
      local mon = randomPartyPokemon(ctx.game)
      local name = pokemonName(mon)
      if not hasMajorStatus(mon) then
        mon.status = "paralysis"
        setTemporaryMood("SAD")
        finishCamp(ctx.game,
          name .. " Is trembling\nfrom hunger.\f" ..
          name .. " Became\nparalyzed!")
      else
        local lost = damagePokemon(mon, 2)
        setTemporaryMood("SAD")
        finishCamp(ctx.game,
          name .. " Looks weak\nfrom hunger.\f" ..
          name .. " Lost " .. tostring(lost) .. "\nHP.")
      end
    end,
  })

  registerScenario("camp", {
    id = "pokemon_steals_food",
    category = "neutral",
    weight = 8,
    eligible = function(ctx)
      return leadPokemon(ctx.game) ~= nil and totalFood() > 0 and hunger() < 60
    end,
    run = function(ctx)
      local game = ctx.game
      local mon = randomPartyPokemon(game)
      local name = pokemonName(mon)
      local available = {}
      for _, food in ipairs(FOODS) do
        if foodCount(food.id) > 0 then table.insert(available, food) end
      end
      local food = available[math.random(1, #available)]
      say(game,
        "You wake to a\nstrange noise.\f" ..
        name .. " Is eating\nyour " .. foodLabel(food) .. "!\f" ..
        "Let it eat?",
        nil, {
          choice = function(yes)
            if yes then
              setFoodCount(food.id, foodCount(food.id) - 1)
              setHunger(hunger() + math.floor(food.restore * 0.50))
              setTemporaryMood("HAPPY")
              finishCamp(game,
                name .. " Finishes\nhappily.\f" ..
                "You share what's\nleft around.")
            else
              setTemporaryMood("SAD")
              finishCamp(game,
                "You put the food\nback away.\f" ..
                name .. " Looks\ndisappointed.")
            end
          end,
        })
    end,
  })

  registerScenario("camp", {
    id = "mystery_berries",
    investigation = true,
    category = "positive",
    weight = 6,
    eligible = function(ctx) return leadPokemon(ctx.game) ~= nil end,
    run = function(ctx)
      local mon=randomPartyPokemon(ctx.game)
      local berry=(math.random(1,2)==1) and "red_berry" or "blue_berry"
      local label=(berry=="red_berry") and "Red berry" or "Blue berry"
      giveFood(berry,1)
      finishCamp(ctx.game,pokemonName(mon).." finds some\nunusual berries.\fYou pack them away\nfor later.\f"..label.." +1")
    end,
  })

  registerScenario("camp", {
    id = "forage_when_empty",
    investigation = true,
    category = "positive",
    weight = 10,
    eligible = function(ctx) return totalFood() == 0 end,
    run = function(ctx)
      local game = ctx.game
      say(game,
        "Your food bag\nis empty.\f" ..
        "Search nearby\nfor something?",
        nil, {
          choice = function(yes)
            if not yes then
              setTemporaryMood("SAD")
              return finishCamp(game, "You decide to\nconserve energy.")
            end
            if math.random(1, 3) <= 2 then
              giveFood("trail_mix", 1)
              if math.random(1, 100) <= 35 then
                setTemporaryMood("THRIFTY", 380)
              else
                setTemporaryMood("CURIOUS")
              end
              finishCamp(game,
                "After searching,\nyou find supplies!\f" ..
                "Trail mix +1")
            else
              setEnergy(energy() - 10)
              setTemporaryMood("SAD")
              finishCamp(game,
                "You search for\na long time.\f" ..
                "You find nothing.\f" ..
                "Energy -10")
            end
          end,
        })
    end,
  })

  -- Ordinary road-bumps: these remain eligible even when the party is
  -- well supplied. Survival meters change risk; they do not monopolize it.
  registerScenario("camp", {
    id = "rough_sleep",
    category = "neutral",
    weight = 7,
    eligible = function(ctx) return leadPokemon(ctx.game) ~= nil end,
    run = function(ctx)
      local mon = randomPartyPokemon(ctx.game)
      local name = pokemonName(mon)
      local lost = damagePokemon(mon, 2)
      finishCamp(ctx.game,
        name .. " Sleeps poorly\nthrough the night.\f" ..
        "By morning, " .. name .. "\nLooks worn out.\f" ..
        name .. " Lost " .. tostring(lost) .. "\nHP.")
    end,
  })

  registerScenario("camp", {
    id = "pokemon_wanders",
    category = "neutral",
    weight = 7,
    eligible = function(ctx) return leadPokemon(ctx.game) ~= nil end,
    run = function(ctx)
      local mon = randomPartyPokemon(ctx.game)
      local name = pokemonName(mon)
      setEnergy(90)
      setTemporaryMood("UNEASY")
      finishCamp(ctx.game,
        "You wake up and\n" .. name .. " is gone!\f" ..
        "After searching,\nyou find " .. name .. " nearby.\f" ..
        "You don't get much\nsleep after that.")
    end,
  })

  registerScenario("camp", {
    id = "cold_night",
    category = "neutral",
    weight = 6,
    run = function(ctx)
      setEnergy(90)
      finishCamp(ctx.game,
        "The night turns\nunexpectedly cold.\f" ..
        "Everyone huddles\nclose for warmth.\f" ..
        "Energy recovers\nonly to 90.")
    end,
  })

  registerScenario("camp", {
    id = "playful_pair",
    category = "neutral",
    weight = 8,
    eligible = function(ctx)
      local party = ctx.game and ctx.game.save and ctx.game.save.party or {}
      return #party >= 2
    end,
    run = function(ctx)
      local a, b = twoPartyPokemon(ctx.game)
      local an, bn = pokemonName(a), pokemonName(b)
      setEnergy(85)
      setTemporaryMood("HAPPY")
      finishCamp(ctx.game,
        an .. " and " .. bn .. " spend half the night chasing each other around.\f" ..
        "They eventually settle down, but their antics cost you some sleep.\f" ..
        "Energy only recovered to 85.")
    end,
  })

  registerScenario("camp", {
    id = "share_with_friend",
    category = "positive",
    weight = 7,
    eligible = function(ctx)
      local party = ctx.game and ctx.game.save and ctx.game.save.party or {}
      return #party >= 2 and totalFood() > 0
    end,
    run = function(ctx)
      local a, b = twoPartyPokemon(ctx.game)
      local an, bn = pokemonName(a), pokemonName(b)
      setTemporaryMood("HAPPY")
      finishCamp(ctx.game,
        an .. " shares some food with " .. bn .. ".\f" ..
        bn .. " happily accepts.\f" ..
        "It is a small thing, but it is nice to see.")
    end,
  })

  registerScenario("camp", {
    id = "camp_squabble",
    category = "neutral",
    weight = 6,
    eligible = function(ctx)
      local party = ctx.game and ctx.game.save and ctx.game.save.party or {}
      return #party >= 2
    end,
    run = function(ctx)
      local a, b = twoPartyPokemon(ctx.game)
      local an, bn = pokemonName(a), pokemonName(b)
      setTemporaryMood("ANGRY")
      finishCamp(ctx.game,
        an .. " AND " .. bn .. "\nStart squabbling.\f" ..
        "You have to break\nthem apart.\f" ..
        "So much for a\nquiet evening.")
    end,
  })

  registerScenario("camp", {
    id = "fresh_tracks",
    investigation = true,
    category = "neutral",
    weight = 5,
    run = function(ctx)
      local game = ctx.game
      say(game,
        "You notice fresh\ntracks near camp.\f" ..
        "Follow them?",
        nil, {
          defaultNo = true,
          choice = function(yes)
            if not yes then
              return finishCamp(game,
                "You leave the\ntracks alone.\f" ..
                "By morning, they\nare hard to see.")
            end
            if math.random(1, 100) <= 55 then
              giveFood("trail_mix", 1)
              adjustMood(2)
              if math.random(1, 100) <= 40 then
                setTemporaryMood("THRIFTY", 420)
              end
              finishCamp(game,
                "The tracks lead\nto an old pack.\f" ..
                "There's still\nfood inside!\f" ..
                "Trail mix +1")
            else
              setEnergy(energy() - 5)
              finishCamp(game,
                "You follow them\ninto the dark...\f" ..
                "Then lose the\ntrail completely.\f" ..
                "Energy -5")
            end
          end,
        })
    end,
  })

  registerScenario("camp", {
    id = "half_buried_tin",
    investigation = true,
    category = "positive",
    weight = 4,
    run = function(ctx)
      local game = ctx.game
      say(game,
        "Something metallic\nglints nearby.\f" ..
        "Dig it up?",
        nil, {
          defaultNo = true,
          choice = function(yes)
            if not yes then
              return finishCamp(game, "You decide not to\ndisturb it.")
            end
            giveFood("sandwich", 1)
            adjustMood(3)
            if math.random(1, 100) <= 45 then
              setTemporaryMood("THRIFTY", 440)
            end
            finishCamp(game,
              "You uncover a\nsmall sealed tin.\f" ..
              "The food inside\nis still good!\f" ..
              "Sandwich +1")
          end,
        })
    end,
  })

  registerScenario("camp", {
    id = "distant_glimmer",
    investigation = true,
    category = "neutral",
    weight = 5,
    run = function(ctx)
      local game = ctx.game
      say(game,
        "A faint glimmer\nflashes in the dark.\f" ..
        "Check it out?",
        nil, {
          defaultNo = true,
          choice = function(yes)
            if not yes then
              return finishCamp(game,
                "You watch it for\na while...\f" ..
                "Then it vanishes.")
            end
            local roll = math.random(1, 3)
            if roll == 1 then
              adjustMood(4)
              finishCamp(game,
                "It's only dew on\na strange flower.\f" ..
                "Still... It's\nbeautiful.")
            elseif roll == 2 then
              local berry=(math.random(1,2)==1) and "red_berry" or "blue_berry"
              local label=(berry=="red_berry") and "Red berry" or "Blue berry"
              giveFood(berry,1)
              finishCamp(game,"You find a patch\nof ripe berries.\f"..label.." +1")
            else
              finishCamp(game,
                "You search for\nseveral minutes.\f" ..
                "Whatever it was,\nit's gone.")
            end
          end,
        })
    end,
  })

  registerScenario("camp", {
    id = "quiet_company",
    category = "positive",
    weight = 7,
    eligible = function(ctx)
      local party = ctx.game and ctx.game.save and ctx.game.save.party or {}
      return #party >= 2
    end,
    run = function(ctx)
      local a, b = twoPartyPokemon(ctx.game)
      local an, bn = pokemonName(a), pokemonName(b)
      setTemporaryMood("RELAXED")
      finishCamp(ctx.game,
        an .. " AND " .. bn .. "\nRest near the fire.\f" ..
        "For once, nobody\nneeds anything.\f" ..
        "It's peaceful.")
    end,
  })

  -- Pokemon/personality camping expansion.
  registerScenario("camp",{id="lazy_sleeps_in",category="neutral",weight=7,
    eligible=function(ctx) for _,m in ipairs(ctx.game.save.party or {}) do if Personality.get(m)=="LAZY" and not hasMajorStatus(m) then return true end end return false end,
    run=function(ctx) local c={} for _,m in ipairs(ctx.game.save.party) do if Personality.get(m)=="LAZY" and not hasMajorStatus(m) then c[#c+1]=m end end local m=c[math.random(1,#c)];m.status="sleep";finishCamp(ctx.game,pokemonName(m).." Refuses to wake\nup this morning.\fNope. Still asleep.\f"..pokemonName(m).." Fell asleep!") end})

  registerScenario("camp",{id="playful_midnight",category="neutral",weight=8,
    eligible=function(ctx) for _,m in ipairs(ctx.game.save.party or {}) do if Personality.get(m)=="PLAYFUL" then return true end end return false end,
    run=function(ctx) local c={} for _,m in ipairs(ctx.game.save.party) do if Personality.get(m)=="PLAYFUL" then c[#c+1]=m end end local m=c[math.random(1,#c)];setEnergy(82);setTemporaryMood("HAPPY");finishCamp(ctx.game,pokemonName(m).." Decides 2 am is\nplay time.\fYou eventually get\nit to settle down.\fEnergy recovers\nonly to 82.") end})

  registerScenario("camp",{id="inquisitive_find",investigation=true,category="positive",weight=8,
    eligible=function(ctx) for _,m in ipairs(ctx.game.save.party or {}) do if Personality.get(m)=="INQUISITIVE" then return true end end return false end,
    run=function(ctx) local c={} for _,m in ipairs(ctx.game.save.party) do if Personality.get(m)=="INQUISITIVE" then c[#c+1]=m end end local m=c[math.random(1,#c)];local pool={"Potion","Antidote","Poke_ball","Repel"};local id=pool[math.random(1,#pool)];local B=require("src.inventory.Bag");local d=ctx.game.data.items[id];if d and B.add(ctx.game.save,id,1,ctx.game.data) then if math.random(1,100)<=35 then setTemporaryMood("THRIFTY",360) end finishCamp(ctx.game,pokemonName(m).." digs around\nnear camp.\fIt unearths\n"..tostring(d.name or id).."!") else finishCamp(ctx.game,pokemonName(m).." Brings you a\nvery important rock.") end end})

  registerScenario("camp",{id="loyal_watch",category="positive",weight=8,
    eligible=function(ctx) for _,m in ipairs(ctx.game.save.party or {}) do if Personality.get(m)=="LOYAL" then return true end end return false end,
    run=function(ctx) local c={} for _,m in ipairs(ctx.game.save.party) do if Personality.get(m)=="LOYAL" then c[#c+1]=m end end local m=c[math.random(1,#c)];adjustMood(2);finishCamp(ctx.game,pokemonName(m).." Keeps watch\nwhile you sleep.\fBy morning it is\ncurled beside you.") end})

  registerScenario("camp",{id="bold_patrol",category="neutral",weight=7,
    eligible=function(ctx) for _,m in ipairs(ctx.game.save.party or {}) do if Personality.get(m)=="BOLD" then return true end end return false end,
    run=function(ctx) local c={} for _,m in ipairs(ctx.game.save.party) do if Personality.get(m)=="BOLD" then c[#c+1]=m end end local m=c[math.random(1,#c)];if math.random(1,100)<=30 then local b=(math.random(1,2)==1) and "red_berry" or "blue_berry";giveFood(b,1);finishCamp(ctx.game,pokemonName(m).." patrols beyond\nthe firelight.\fIt returns with\na berry.") else finishCamp(ctx.game,pokemonName(m).." patrols the edge\nof camp all night.\fNothing comes close.") end end})

  registerScenario("camp",{id="timid_noise",category="neutral",weight=7,
    eligible=function(ctx) for _,m in ipairs(ctx.game.save.party or {}) do if Personality.get(m)=="TIMID" then return true end end return false end,
    run=function(ctx) local c={} for _,m in ipairs(ctx.game.save.party) do if Personality.get(m)=="TIMID" then c[#c+1]=m end end local m=c[math.random(1,#c)];setEnergy(90);finishCamp(ctx.game,"A branch snaps in\nthe dark.\f"..pokemonName(m).." Crawls close\nand won't leave.") end})

  registerScenario("camp",{id="mischief_food_theft",category="negative",weight=5,
    eligible=function(ctx) if totalFood()<=0 then return false end for _,m in ipairs(ctx.game.save.party or {}) do local p=Personality.get(m);if p=="PLAYFUL" or p=="STUBBORN" then return true end end return false end,
    run=function(ctx) local c={} for _,m in ipairs(ctx.game.save.party) do local p=Personality.get(m);if p=="PLAYFUL" or p=="STUBBORN" then c[#c+1]=m end end local m=c[math.random(1,#c)];local lost=takeRandomFood();adjustMood(-2);finishCamp(ctx.game,"You hear rustling\nnear your bag.\f"..pokemonName(m).." Freezes with\nfood in its mouth.\fOne "..foodLabel(lost).."\nIs gone.") end})

  registerScenario("camp",{id="rare_bad_berry",category="negative",weight=2,
    eligible=function(ctx) return leadPokemon(ctx.game)~=nil end,
    run=function(ctx) local m=randomPartyPokemon(ctx.game);local n=pokemonName(m);if not hasMajorStatus(m) then m.status="poison";setTemporaryMood("UNEASY");finishCamp(ctx.game,n.." Eats berries\nbefore you can stop it.\fA minute later it\nlooks sick...\f"..n.." Was poisoned!") else finishCamp(ctx.game,n.." Sniffs some\nstrange berries.\fIt leaves them alone.") end end})

  registerScenario("camp",{id="stubborn_bed",category="neutral",weight=6,
    eligible=function(ctx) for _,m in ipairs(ctx.game.save.party or {}) do if Personality.get(m)=="STUBBORN" then return true end end return false end,
    run=function(ctx) local c={} for _,m in ipairs(ctx.game.save.party) do if Personality.get(m)=="STUBBORN" then c[#c+1]=m end end local m=c[math.random(1,#c)];finishCamp(ctx.game,pokemonName(m).." Rejects every\nsleeping spot.\fIt finally sleeps\nwhere it started.") end})

  registerScenario("camp",{id="aggressive_guard",category="neutral",weight=6,
    eligible=function(ctx) for _,m in ipairs(ctx.game.save.party or {}) do if Personality.get(m)=="AGGRESSIVE" then return true end end return false end,
    run=function(ctx) local c={} for _,m in ipairs(ctx.game.save.party) do if Personality.get(m)=="AGGRESSIVE" then c[#c+1]=m end end local m=c[math.random(1,#c)];finishCamp(ctx.game,pokemonName(m).." Growls at every\nsound beyond camp.\fEven the forest\ngets the message.") end})

  registerScenario("camp", {
    id = "careful_with_supplies",
    category = "positive",
    weight = 6,
    eligible = function(ctx)
      return totalFood() >= 2 and hunger() >= 45
    end,
    run = function(ctx)
      setTemporaryMood("THRIFTY", 420)
      finishCamp(ctx.game,
        "You take stock of your supplies before turning in.\f"
          .. "There is enough here if you are careful with it.\f"
          .. "You feel oddly pleased with yourself.")
    end,
  })

  local function runCampEvent(game)
    runScenario("camp", {
      game = game,
      trigger = "camp",
      campCount = mod.save:get("camp_count", 0),
      hunger = hunger(),
      energy = energy(),
      mood = mood(),
      foodState = campFoodState(),
      foodCount = totalFood(),
    })
  end

  local function beginCamp(game)
    local allowed, reason = campingAllowed(game)
    if not allowed then
      say(game, reason)
      return
    end

    say(game,
      "SET UP CAMP\nHERE?",
      nil,
      {
        defaultNo = true,
        choice = function(yes)
          if not yes then
            returnToPokeSim(game)
            return
          end

          setCampTravel(0)
          mod.save:set("camp_count", mod.save:get("camp_count", 0) + 1)

          -- Replace the visible overworld with a dedicated camp vignette
          -- before any camp-event dialogue is shown.
          mod.ui.push(game, CAMP_SCREEN)
          stopCampMusic()

          -- Gen1Recomp exposes the original Poké Flute melody as the
          -- "Pokeflute" sound cue. Play it once as the camp theme.
          require("src.core.Sound").play(game.data, "Pokeflute")

          -- Standard camp result: fully rested, but sleeping costs Hunger.
          setEnergy(MAX_ENERGY)
          setHunger(hunger() - CAMP_HUNGER_COST)
          mod.save:set("energy_steps", 0)

          say(game,
            "THE SUN SETS...\f" ..
            "YOU SET UP CAMP\nFOR THE NIGHT.\f" ..
            "YOUR POKEMON\nSETTLE NEARBY.",
            function()
              runCampEvent(game)
            end)
        end,
      })
  end

  mod.content.screens:register(CAMP_SCREEN, {
    new = function(game)
      local Font = mod.ui.Font
      local state = {
        game = game,
        isOpaque = true,
        _pokesimCampBackdrop = true,
        flicker = 0,
      }

      function state:update()
        -- No direct input here. Text boxes/choices are pushed above this
        -- state and own input while the player is camping.
        self.flicker = (self.flicker + 1) % 40
      end

      function state:draw()
        -- Dedicated 160x144 camp vignette. This intentionally replaces the
        -- overworld while camp dialogue is running.
        love.graphics.setColor(0.07, 0.09, 0.18, 1)
        love.graphics.rectangle("fill", 0, 0, 160, 144)

        -- Stars.
        love.graphics.setColor(0.82, 0.86, 1.0, 1)
        local stars = {
          {12, 12}, {29, 22}, {45, 9}, {67, 18}, {83, 7},
          {105, 20}, {128, 11}, {146, 26}, {21, 42}, {119, 39},
        }
        for _, p in ipairs(stars) do
          love.graphics.rectangle("fill", p[1], p[2], 2, 2)
        end

        -- Moon.
        love.graphics.setColor(0.90, 0.91, 0.78, 1)
        love.graphics.rectangle("fill", 126, 29, 12, 12)
        love.graphics.setColor(0.07, 0.09, 0.18, 1)
        love.graphics.rectangle("fill", 130, 27, 10, 10)

        -- Ground silhouette.
        love.graphics.setColor(0.10, 0.16, 0.12, 1)
        love.graphics.rectangle("fill", 0, 88, 160, 56)

        -- Tent.
        love.graphics.setColor(0.33, 0.39, 0.47, 1)
        love.graphics.polygon("fill", 19, 91, 43, 61, 67, 91)
        love.graphics.setColor(0.18, 0.22, 0.28, 1)
        love.graphics.polygon("fill", 43, 61, 43, 91, 67, 91)
        love.graphics.setColor(0.07, 0.09, 0.18, 1)
        love.graphics.polygon("fill", 35, 91, 43, 73, 51, 91)

        -- Camp fire logs.
        love.graphics.setColor(0.30, 0.19, 0.10, 1)
        love.graphics.rectangle("fill", 92, 90, 24, 3)
        love.graphics.rectangle("fill", 96, 86, 16, 3)

        -- Fire, with a tiny flicker.
        local lift = (self.flicker < 20) and 0 or 2
        love.graphics.setColor(0.94, 0.42, 0.10, 1)
        love.graphics.polygon("fill",
          104, 88,
          97, 80,
          101, 69 + lift,
          105, 75,
          109, 62 + lift,
          114, 76,
          111, 88)
        love.graphics.setColor(1.00, 0.79, 0.20, 1)
        love.graphics.polygon("fill",
          105, 87,
          101, 81,
          105, 72 + lift,
          109, 82,
          108, 87)

        love.graphics.setColor(0.88, 0.90, 1.0, 1)
        Font.draw("CAMP", 64, 18)
      end

      return state
    end,
  })

  mod.content.screens:register(FOOD_SCREEN, {
    new = function(game)
      local function backToPokeSim()
        returnToPokeSim(game)
      end

      local items = {}
      for _, food in ipairs(FOODS) do
        table.insert(items, {
          label = food.label,
          right = "x" .. tostring(foodCount(food.id)),
          food = food,
        })
      end
      table.insert(items, { label = "BACK" })

      return mod.ui.ListMenu.new(game, "FOOD", items, {
        onChoose = function(item, menu)
          if not item then return end

          if item.label == "BACK" then
            menu:close()
            backToPokeSim()
            return
          end

          if item.food then
            if hunger() >= MAX_HUNGER and not item.food.berry then
              say(game, "YOU'RE ALREADY\nFULL!")
              return
            end

            if foodCount(item.food.id) <= 0 then
              say(game, "YOU DON'T HAVE\nANY!")
              return
            end

            local restored = eatFood(item.food)
            item.right = "x" .. tostring(foodCount(item.food.id))
            if restored > 0 then
              require("src.core.Sound").play(game.data, "Heal_HP")
              say(game, "RESTORED " .. tostring(restored) .. "\nHUNGER!")
            elseif restored < 0 then
              adjustMood(-1)
              say(game, "UGH... THAT BERRY\nTASTES AWFUL!\fHUNGER " .. tostring(restored) .. ".")
            end
          end
        end,
        onCancel = backToPokeSim,
      })
    end,
  })


  local function merchantBuyPrice(def)
    local price = (def and def.price) or 0
    if mood() == "THRIFTY" then
      price = math.floor(price * 0.90)
    end
    return math.max(0, price)
  end

  local function openMerchantBuy(game, stock)
    local Bag = require("src.inventory.Bag")
    local ChoiceBox = require("src.ui.ChoiceBox")
    local ListMenu = require("src.ui.ListMenu")
    local QuantityBox = require("src.ui.QuantityBox")
    local Strings = require("src.core.Strings")

    local function txt(key, fallback)
      return game.data.text[key] or fallback
    end

    local items = {}
    for _, id in ipairs(stock or {}) do
      local def = game.data.items[id]
      if def then
        table.insert(items, {
          value = id,
          label = def.name,
          right = ("¥%d"):format(merchantBuyPrice(def)),
        })
      end
    end

    local greet = txt("_PokemartBuyingGreetingText", Strings("Take your time."))
    local notEnough = txt(
      "_PokemartNotEnoughMoneyText",
      Strings("You don't have\nenough money.")
    )

    local list
    list = ListMenu.new(game, "BUY", items, {
      dialogue = true,
      money = function() return game.save.money end,
      footer = greet,

      onChoose = function(item)
        local def = game.data.items[item.value]
        if not def then return end

        local unitPrice = merchantBuyPrice(def)
        if game.save.money < unitPrice then
          list.footer = notEnough
          return
        end

        local affordable = math.min(
          99,
          math.floor(game.save.money / math.max(1, unitPrice))
        )

        game.stack:push(QuantityBox.new(game, {
          max = affordable,
          unitPrice = unitPrice,

          onDone = function(qty)
            if not qty then
              list.footer = greet
              return
            end

            local cost = qty * unitPrice
            list.footer = Strings(
              "%s?\nThat will be\n¥%d. OK?",
              def.name,
              cost
            )

            game.stack:push(ChoiceBox.new(game, function(yes)
              if not yes then
                list.footer = greet
                return
              end

              if game.save.money < cost then
                list.footer = notEnough
                return
              end

              if not Bag.add(game.save, item.value, qty, game.data) then
                list.footer = txt(
                  "_PokemartItemBagFullText",
                  Strings("You can't carry\nany more items.")
                )
                return
              end

              require("src.core.Sound").play(game.data, "Purchase")
              game.save.money = game.save.money - cost
              boughtSomething = true
              list.footer = txt(
                "_PokemartBoughtItemText",
                Strings("Here you are!\nThank you!")
              )
            end))
          end,
        }))
      end,
    })

    game.stack:push(list)
  end

  mod.content.screens:register("ShopMenu", {
    new = function(game, stock, onQuit)
      if not pokesimEnabled() then
        return require("src.ui.ShopMenu").new(game, stock, onQuit)
      end

      local boughtSomething = false
      local function thriftyQuit()
        if not boughtSomething and math.random(1, 100) <= 10 then
          setTemporaryMood("THRIFTY", 260)
        end
        if onQuit then onQuit() end
      end

      -- Preserve vanilla SELL/QUIT, but use a PokeSim-aware BUY callback so
      -- THRIFTY can discount every normal merchant purchase too.
      local vanilla = require("src.ui.ShopMenu").new(game, stock, thriftyQuit)
      local Menu = require("src.ui.Menu")
      local Strings = require("src.core.Strings")

      local items = {
        {
          label = Strings("BUY"),
          keepOpen = true,
          onSelect = function()
            openMerchantBuy(game, stock)
          end,
        },
        vanilla.items[2], -- SELL remains fully vanilla.
        {
          label = Strings("SURVIVE FOOD"),
          keepOpen = true,
          onSelect = function()
            mod.ui.push(game, FOOD_SHOP_SCREEN, true)
          end,
        },
        vanilla.items[3], -- QUIT remains vanilla.
      }

      local menu = Menu.new(game, items, { tx = 0, ty = 0, tw = 8 })
      menu.onCancel = thriftyQuit
      return menu
    end,
  })

  mod.content.screens:register(FOOD_SHOP_SCREEN, {
    new = function(game, returnToMart)
      local QuantityBox = require("src.ui.QuantityBox")
      local ChoiceBox = require("src.ui.ChoiceBox")
      local Strings = require("src.core.Strings")

      local function txt(key, fallback)
        return game.data.text[key] or fallback
      end

      local greet = txt(
        "_PokemartBuyingGreetingText",
        Strings("Take your time.")
      )
      local notEnough = txt(
        "_PokemartNotEnoughMoneyText",
        Strings("You don't have\nenough money.")
      )

      local items = {}
      for _, food in ipairs(FOODS) do
        if not food.eventOnly then
          table.insert(items, {
            label = foodLabel(food),
            right = ("¥%d"):format(foodPrice(food)),
            food = food,
          })
        end
      end

      local list
      list = mod.ui.ListMenu.new(game, "SURVIVE FOOD", items, {
        dialogue = true,
        money = function() return playerMoney(game) end,
        footer = greet,

        onChoose = function(item)
          if not item or not item.food then return end

          local food = item.food
          local unitPrice = foodPrice(food)

          if playerMoney(game) < unitPrice then
            list.footer = notEnough
            return
          end

          local affordable = math.min(
            99,
            math.floor(playerMoney(game) / math.max(1, unitPrice))
          )

          game.stack:push(QuantityBox.new(game, {
            max = affordable,
            unitPrice = unitPrice,

            onDone = function(qty)
              if not qty then
                list.footer = greet
                return
              end

              local cost = qty * unitPrice
              list.footer = Strings(
                "%s?\nThat will be\n¥%d. OK?",
                foodLabel(food),
                cost
              )

              game.stack:push(ChoiceBox.new(game, function(yes)
                if not yes then
                  list.footer = greet
                  return
                end

                if playerMoney(game) < cost then
                  list.footer = notEnough
                  return
                end

                giveFood(food.id, qty)
                setPlayerMoney(game, playerMoney(game) - cost)
                require("src.core.Sound").play(game.data, "Purchase")

                list.footer = txt(
                  "_PokemartBoughtItemText",
                  Strings("Here you are!\nThank you!")
                )
              end))
            end,
          }))
        end,

        onCancel = function()
          -- When launched from the Mart, closing this list simply reveals
          -- the Mart menu that is still underneath it on the stack.
          if not returnToMart then
            mod.ui.push(game, SCREEN)
          end
        end,
      })

      return list
    end,
  })

  mod.content.screens:register(MOOD_TEST_SCREEN, {
    new = function(game)
      local items = {
        { label = "MISERABLE", right = "-80", coreValue = -80 },
        { label = "SAD", right = "-40", coreValue = -40 },
        { label = "FINE", right = "0", coreValue = 0 },
        { label = "HAPPY", right = "+40", coreValue = 40 },
        { label = "ECSTATIC", right = "+80", coreValue = 80 },
        { label = "CONFIDENT", right = "EMOTION", emotionName = "CONFIDENT" },
        { label = "RELAXED", right = "EMOTION", emotionName = "RELAXED" },
        { label = "UNEASY", right = "EMOTION", emotionName = "UNEASY" },
        { label = "ANGRY", right = "EMOTION", emotionName = "ANGRY" },
        { label = "FOCUSED", right = "EMOTION", emotionName = "FOCUSED" },
        { label = "CURIOUS", right = "EMOTION", emotionName = "CURIOUS" },
        { label = "CURIOUS FIND", right = "NEXT", forceCuriousFind = true },
        { label = "THRIFTY", right = "EMOTION", emotionName = "THRIFTY" },
        { label = "CLEAR EMOTION", right = "-", clearEmotion = true },
        { label = "BACK", right = "<" },
      }

      local menu = mod.ui.ListMenu.new(game, "MOOD TEST", items, {
        onChoose = function(item, list)
          if not item then return end
          if item.coreValue ~= nil then
            setMoodValue(item.coreValue)
            clearTemporaryMood()
          elseif item.emotionName then
            setTemporaryMood(item.emotionName)
          elseif item.forceCuriousFind then
            setTemporaryMood("CURIOUS", 600)
            mod.save:set("curious_force_find", true)
          elseif item.clearEmotion then
            clearTemporaryMood()
          elseif item.label == "BACK" then
            list:close()
            mod.ui.push(game, SCREEN)
            return
          else
            return
          end
          list:close()
          mod.ui.push(game, MOOD_TEST_SCREEN)
        end,
        onCancel = function()
          mod.ui.push(game, SCREEN)
        end,
      })
      return addScrollArrow(menu)
    end,
  })

  mod.content.screens:register(STAT_DETAIL_SCREEN, {
    new = function(game, args)
      local partyIndex = tonumber(args and args.partyIndex) or 1
      local mon = game.save and game.save.party and game.save.party[partyIndex]
      if not mon then
        return mod.ui.ListMenu.new(game, "STAT DEBUG", {
          { label = "NO POKEMON", right = "" },
          { label = "BACK", right = "<" },
        }, {
          onChoose = function(item, list)
            if item and item.label == "BACK" then
              list:close()
              mod.ui.push(game, STAT_DEBUG_SCREEN)
            end
          end,
          onCancel = function()
            mod.ui.push(game, STAT_DEBUG_SCREEN)
          end,
        })
      end

      local species = mon.species
      local def = require("src.core.Game").data.pokemon[species]
      local displayName = tostring((mon.nickname and mon.nickname ~= "" and mon.nickname)
        or (def and def.name) or species)

      local stats = deterministicStatsForSpecies(
        species,
        originalSpeciesStats[species],
        originalSpeciesStats
      )

      local donor = stats and stats._donor or "-"
      local donorDef = require("src.core.Game").data.pokemon[donor]
      local donorName = donorDef and donorDef.name or donor
      local assignedBST = stats and stats._bst or 0

      local items = {
        { label = "ROLE", right = evolutionaryRole(species) },
        { label = "DONOR", right = tostring(donorName) },
        { label = "BST", right = tostring(assignedBST) },
        { label = "HP", right = stats and tostring(stats.hp) or "-" },
        { label = "ATTACK", right = stats and tostring(stats.attack) or "-" },
        { label = "DEFENSE", right = stats and tostring(stats.defense) or "-" },
        { label = "SPEED", right = stats and tostring(stats.speed) or "-" },
        { label = "SPECIAL", right = stats and tostring(stats.special) or "-" },
        { label = "BACK", right = "<" },
      }

      local menu = mod.ui.ListMenu.new(game, displayName .. " STATS", items, {
        onChoose = function(item, list)
          if item and item.label == "BACK" then
            list:close()
            mod.ui.push(game, STAT_DEBUG_SCREEN)
          end
        end,
        onCancel = function()
          mod.ui.push(game, STAT_DEBUG_SCREEN)
        end,
      })
      return addScrollArrow(menu)
    end,
  })

  mod.content.screens:register(STAT_DEBUG_SCREEN, {
    new = function(game)
      local items = {}
      for i, mon in ipairs((game.save and game.save.party) or {}) do
        local def = require("src.core.Game").data.pokemon[mon.species]
        local label = tostring((mon.nickname and mon.nickname ~= "" and mon.nickname)
          or (def and def.name) or mon.species)
        table.insert(items, {
          label = label,
          right = ">",
          partyIndex = i,
        })
      end

      if #items == 0 then
        table.insert(items, { label = "NO POKEMON", right = "" })
      end
      table.insert(items, { label = "BACK", right = "<" })

      local menu = mod.ui.ListMenu.new(game, "STAT DEBUG", items, {
        onChoose = function(item, list)
          if not item then return end
          if item.label == "BACK" then
            list:close()
            mod.ui.push(game, SCREEN)
          elseif item.partyIndex then
            list:close()
            mod.ui.push(game, STAT_DETAIL_SCREEN, {
              partyIndex = item.partyIndex,
            })
          end
        end,
        onCancel = function()
          mod.ui.push(game, SCREEN)
        end,
      })
      return addScrollArrow(menu)
    end,
  })

  mod.content.screens:register(RUN_SETTINGS_SCREEN, {
    new = function(game)
      local function yn(v) return v and "ON" or "OFF" end
      local seed = randomPokemonEnabled() and runSeedText() or "-"
      if #seed > 12 then seed = seed:sub(1, 12) end

      local items = {
        { label = "SURVIVE", right = yn(pokesimEnabled()) },
        { label = "RANDOM", right = yn(randomPokemonEnabled()) },
        { label = "PERMADEATH", right = yn(permadeathEnabled()) },
        { label = "SEED", right = seed },
        { label = "BACK", right = "<" },
      }

      return mod.ui.ListMenu.new(game, "RUN SETTINGS", items, {
        onChoose = function(item, list)
          if not item then return end
          if item.label == "BACK" then
            list:close()
            mod.ui.push(game, SCREEN)
          end
        end,
        onCancel = function()
          mod.ui.push(game, SCREEN)
        end,
      })
    end,
  })

  mod.content.screens:register(SCREEN, {
    new = function(game)
      local h = hunger()
      local e = energy()
      local items = {
        { label = "HUNGER", right = tostring(h) .. "/" .. tostring(MAX_HUNGER) },
        { label = "ENERGY", right = tostring(e) .. "/" .. tostring(MAX_ENERGY) },
        { label = "MOOD", right = mood() },
        { label = "MORALE", right = tostring(moodValue()) },
        { label = "MOOD FX", right = coreMoodEffectText() },
      }

      local core = coreMood()
      if core == "MISERABLE" then
        items[#items + 1] = { label = "MOOD DRAIN", right = "+10%" }
      elseif core == "ECSTATIC" then
        items[#items + 1] = { label = "MOOD DRAIN", right = "-10%" }
      end

      items[#items + 1] = { label = "PERSONALITIES", right = ">" }
      items[#items + 1] = { label = "RUN SETTINGS", right = ">" }
      items[#items + 1] = { label = "FOOD", right = ">" }
      items[#items + 1] = { label = "CAMP", right = ">" }

      local menu = mod.ui.ListMenu.new(game, "SURVIVE", items, {
        onChoose = function(item, list)
          if not item then return end

          if item.label == "PERSONALITIES" then
            Personality.ensureParty(game)
            local pitems = {}
            for _, mon in ipairs(game.save.party or {}) do
              local monName = Personality.name(game, mon)
              local per = Personality.get(mon)

              -- Two rows prevents long Gen I names and personality labels
              -- from colliding. Three Pokemon fit naturally in one viewport.
              pitems[#pitems + 1] = {
                label = monName,
                right = "",
                mon = mon,
              }
              pitems[#pitems + 1] = {
                label = "  " .. per,
                right = "",
                mon = mon,
              }
            end
            if #pitems == 0 then
              pitems[1] = { label = "NO POKEMON", right = "" }
            end
            list:close()
            local personalityMenu
            personalityMenu = mod.ui.ListMenu.new(game, "PERSONALITIES", pitems, {
              onChoose = function(pitem, plist)
                if not pitem then return end

                if not pitem.mon then return end
                local per = Personality.get(pitem.mon)
                say(game,
                  Personality.name(game, pitem.mon) .. "\n" .. per .. "\f"
                    .. Personality.desc(per))
              end,
              onCancel = function() mod.ui.push(game, SCREEN) end,
            })
            game.stack:push(addScrollArrow(personalityMenu))

          elseif item.label == "RUN SETTINGS" then
            list:close()
            mod.ui.push(game, RUN_SETTINGS_SCREEN)

          elseif item.label == "FOOD" then
            list:close()
            mod.ui.push(game, FOOD_SCREEN)

          elseif item.label == "CAMP" then
            local allowed, reason = campingAllowed(game)
            if not allowed then
              say(game, reason)
              return
            end
            list:close()
            beginCamp(game)

          end
        end,
        onCancel = function()
          mod.ui.push(game, "StartMenu")
        end,
      })

      return addScrollArrow(menu)
    end,
  })

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    if not pokesimEnabled() then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "SURVIVE",
      onSelect = function() mod.ui.push(game, SCREEN) end,
    })
  end)

  local INTRO_DIALOGUE_WIDTH = 18

  local function wrapIntroPage(page)
    page = tostring(page or "")
    page = page:gsub("\n", " ")
    page = page:gsub("%s+", " ")
    page = page:gsub("^%s+", ""):gsub("%s+$", "")
    if page == "" then return "" end

    local lines, line = {}, ""
    for word in page:gmatch("%S+") do
      if line == "" then
        line = word
      elseif #line + 1 + #word <= INTRO_DIALOGUE_WIDTH then
        line = line .. " " .. word
      else
        table.insert(lines, line)
        line = word
      end
    end
    if line ~= "" then table.insert(lines, line) end
    return table.concat(lines, "\n")
  end

  local function wrapIntroDialogue(dialogue)
    dialogue = tostring(dialogue or "")
    local pages, start = {}, 1
    while true do
      local pos = dialogue:find("\f", start, true)
      if not pos then
        table.insert(pages, wrapIntroPage(dialogue:sub(start)))
        break
      end
      table.insert(pages, wrapIntroPage(dialogue:sub(start, pos - 1)))
      start = pos + 1
    end
    return table.concat(pages, "\f")
  end

  -- ================================================================
  -- Existing-Save Initializer
  -- Old saves never saw Oak's run setup. They remain inert until the
  -- player explicitly configures PokeSim once after loading.
  -- ================================================================
  local legacySetupRunning = false

  local function legacySaveNeedsSetup(game)
    if not game or not game.save then return false end
    if runConfigured() or legacySetupRunning then return false end

    -- Oak configures genuinely new games before normal overworld play.
    -- Therefore any save that reaches the playable overworld without our
    -- run_configured marker is an existing/legacy save, regardless of how
    -- Gen1Recomp stores the player's name internally.
    if not game.overworld or not game.stack then return false end
    return game.stack:top() == game.overworld
  end

  local function pushLegacyYesNo(game, prompt, onDone)
    local ChoiceBox = require("src.ui.ChoiceBox")
    local textBox

    textBox = mod.ui.TextBox.new(game, wrapIntroDialogue(prompt), nil, {
      stay = {
        onShown = function()
          game.stack:push(ChoiceBox.new(game, function(yes)
            if game.stack:top() == textBox then game.stack:pop() end
            onDone(yes)
          end))
        end,
      },
    })
    game.stack:push(textBox)
  end

  local function runLegacySetup(game)
    if legacySetupRunning or not legacySaveNeedsSetup(game) then return end
    legacySetupRunning = true

    say(game,
      wrapIntroDialogue(
        "Welcome to PokeSim!\fThis save was started before PokeSim was configured."
      ),
      function()
        pushLegacyYesNo(
          game,
          "Enable PokeSim survival systems?",
          function(enablePokeSim)
            pushLegacyYesNo(
              game,
              "Randomize Pokémon from this point forward?",
              function(enableRandom)
                pushLegacyYesNo(
                  game,
                  "Enable Pokémon permadeath?",
                  function(enablePermadeath)

                    local function commitLegacy(seedText)
                      mod.save:set("run_pokesim", enablePokeSim == true)
                      mod.save:set("run_random_pokemon", enableRandom == true)
                      mod.save:set("run_permadeath", enablePermadeath == true)

                      if enableRandom then
                        setRunSeed(seedText or generateRunSeed())
                      else
                        mod.save:set("run_seed_text", "")
                        mod.save:set("run_seed", 0)
                      end

                      -- Existing Pokémon are intentionally not touched.
                      setHunger(MAX_HUNGER)
                      setEnergy(MAX_ENERGY)
                      clearTemporaryMood()
                      mod.save:set("hunger_steps", 0)
                      mod.save:set("energy_steps", 0)
                      setCampTravel(CAMP_TRAVEL_REQUIRED)

                      mod.save:set("run_configured", true)
                      legacySetupRunning = false

                      say(game,
                        wrapIntroDialogue(
                          "PokeSim setup complete.\fExisting Pokémon were not changed."
                        ))
                    end

                    if not enableRandom then
                      commitLegacy(nil)
                      return
                    end

                    pushLegacyYesNo(
                      game,
                      "Use a random world seed?",
                      function(useRandomSeed)
                        if useRandomSeed then
                          commitLegacy(generateRunSeed())
                          return
                        end

                        require("src.ui.Screens").push(game, "NamingScreen", {
                          title = "WORLD SEED?",
                          presets = { "KANTO", "PIKACHU", "ADVENTURE" },
                          maxLen = 10,
                          onDone = function(seed)
                            if not seed or seed == "" then
                              seed = generateRunSeed()
                            end
                            commitLegacy(seed)
                          end,
                        })
                      end
                    )
                  end
                )
              end
            )
          end
        )
      end
    )
  end

  local function applyLegacyManagerSetup()
    local enablePokeSim = mod.options:get("legacy_pokesim") == true
    local enableRandom = mod.options:get("legacy_random") == true
    local enablePermadeath = mod.options:get("legacy_permadeath") == true
    local seedText = tostring(mod.options:get("legacy_seed") or "")

    mod.save:set("run_pokesim", enablePokeSim)
    mod.save:set("run_random_pokemon", enableRandom)
    mod.save:set("run_permadeath", enablePermadeath)

    if enableRandom then
      if seedText == "" then seedText = generateRunSeed() end
      setRunSeed(seedText)
    else
      mod.save:set("run_seed_text", "")
      mod.save:set("run_seed", 0)
    end

    -- Existing Pokémon stay exactly as they are.
    setHunger(MAX_HUNGER)
    setEnergy(MAX_ENERGY)
    clearTemporaryMood()
    mod.save:set("hunger_steps", 0)
    mod.save:set("energy_steps", 0)
    setCampTravel(CAMP_TRAVEL_REQUIRED)

    mod.save:set("run_configured", true)
    mod.save:set("legacy_manager_applied", true)
    syncRandomizedTypeDefinitions()

    mod.log:info(
      "Applied legacy setup: PokeSim=%s Random=%s Permadeath=%s Seed=%s",
      tostring(enablePokeSim),
      tostring(enableRandom),
      tostring(enablePermadeath),
      enableRandom and tostring(runSeedText()) or "(none)"
    )
  end

  mod.events:on("mod.options_changed", function(ev)
    if not ev or ev.key ~= "legacy_apply" or ev.value ~= true then
      return
    end

    applyLegacyManagerSetup()
  end)

  -- ================================================================
  -- Oak Intro: Run Setup
  -- Gen1Recomp exposes Oak's speech as a stable mod-facing step list.
  -- These choices occur immediately before Oak's final "legend" beat ends.
  -- ================================================================
  mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
    local out = next(steps, speech)
    if type(out) ~= "table" then out = steps end

    -- OakSpeech only runs for NEW GAME, so existing saves are never nagged.
    mod.ui.insertStepBefore(out, "shrink", {
      id = "pokesim_setup_intro",
      kind = "say",
      pic = "player",
      text = wrapIntroDialogue(
        "Before you go...\fHow do you want this adventure to play?"
      ),
    })

    mod.ui.insertStepBefore(out, "shrink", {
      id = "pokesim_setup_enabled",
      kind = "yesno",
      text = wrapIntroDialogue("Enable PokeSurvive systems?"),
      values = { true, false },
      saveKey = "pokesim_enabled",
    })

    mod.ui.insertStepBefore(out, "shrink", {
      id = "pokesim_setup_random",
      kind = "yesno",
      text = wrapIntroDialogue("Randomize Pokémon for this run?"),
      values = { true, false },
      saveKey = "random_pokemon",
    })

    mod.ui.insertStepBefore(out, "shrink", {
      id = "pokesim_setup_permadeath",
      kind = "yesno",
      text = wrapIntroDialogue("Permanent Pokémon loss when fainted?"),
      values = { true, false },
      saveKey = "permadeath",
    })

    mod.ui.insertStepBefore(out, "shrink", {
      id = "pokesim_setup_seed_mode",
      kind = "yesno",
      text = wrapIntroDialogue("Use a random world seed?"),
      values = { "random", "custom" },
      saveKey = "seed_mode",
    })

    mod.ui.insertStepBefore(out, "shrink", {
      id = "pokesim_setup_custom_seed",
      kind = "fn",
      run = function(s, done)
        if s.answers.seed_mode ~= "custom" then
          done()
          return
        end

        require("src.ui.Screens").push(s.game, "NamingScreen", {
          title = "WORLD SEED?",
          presets = { "KANTO", "PIKACHU", "ADVENTURE" },
          maxLen = 10,
          onDone = function(seed)
            s.answers.custom_seed = seed
            done()
          end,
        })
      end,
    })

    mod.ui.insertStepBefore(out, "shrink", {
      id = "pokesim_setup_commit",
      kind = "fn",
      run = function(s, done)
        local a = s.answers

        mod.save:set("run_pokesim", a.pokesim_enabled ~= false)
        mod.save:set("run_random_pokemon", a.random_pokemon == true)
        mod.save:set("run_permadeath", a.permadeath == true)

        local seedText
        if a.seed_mode == "custom" and a.custom_seed and a.custom_seed ~= "" then
          seedText = tostring(a.custom_seed)
        else
          seedText = generateRunSeed()
        end
        setRunSeed(seedText)
        mod.save:set("run_configured", true)
        syncRandomizedTypeDefinitions()

        local function onOff(v) return v and "ON" or "OFF" end
        local summary =
          "Run rules set!\f" ..
          "Survive: " .. onOff(pokesimEnabled()) .. " " ..
          "Random: " .. onOff(randomPokemonEnabled()) .. "\f" ..
          "Permadeath: " .. onOff(permadeathEnabled()) .. " " ..
          "Seed: " .. runSeedText()

        s:sayText(wrapIntroDialogue(summary), done)
      end,
    })

    return out
  end)

  mod.events:on("save.created", function()
    mod.save:set("run_configured", false)
    mod.save:set("run_pokesim", true)
    mod.save:set("run_random_pokemon", false)
    mod.save:set("run_permadeath", false)
    mod.save:set("run_seed_text", "")
    mod.save:set("run_seed", 0)
    mod.save:set("random_starter_1", "")
    mod.save:set("random_starter_2", "")
    mod.save:set("random_starter_3", "")
    mod.save:set("random_rival_starter", "")

    setHunger(MAX_HUNGER)
    setEnergy(MAX_ENERGY)
    mod.save:set("hunger_steps", 0)
    mod.save:set("energy_steps", 0)
    mod.save:set("camp_count", 0)
    mod.save:set("berry_good_color", "")

    -- Adventure Director state belongs to the run, not to the mod install.
    mod.save:set("adventure_event_cooldown", 0)
    mod.save:set("adventure_step_clock", 0)
    mod.save:set("adventure_missed_checks", 0)
    mod.save:set("adventure_event_pending", false)
    mod.save:set("adventure_area_counter", 0)

    mod.save:set("depleted_collapse_steps", 0)
    mod.save:set("depleted_collapse_pending", false)
    mod.save:set("permadeath_ignore_stale_field_once", false)
    mod.save:set("last_center_map", "")
    mod.save:set("last_center_x", 0)
    mod.save:set("last_center_y", 0)
    mod.save:set("last_center_facing", "down")
    mod.save:set("last_center_return_map", "")
    mod.save:set("last_center_return_x", 0)
    mod.save:set("last_center_return_y", 0)
    mod.save:set("last_center_return_facing", "down")
    mod.save:set("last_field_map", "")
    mod.save:set("last_field_x", 0)
    mod.save:set("last_field_y", 0)
    mod.save:set("last_field_facing", "down")

    mod.save:set("adventure_last_pair_key", "")
    mod.save:set("adventure_prev_pair_key", "")
    mod.save:set("adventure_prev2_pair_key", "")
    mod.save:set("adventure_env_last_1", "")
    mod.save:set("adventure_env_last_2", "")
    mod.save:set("adventure_env_last_3", "")
    for _, per in ipairs({
      "loyal", "bold", "timid", "stubborn",
      "playful", "inquisitive", "lazy", "aggressive",
    }) do
      mod.save:set("adventure_solo_" .. per .. "_1", 0)
      mod.save:set("adventure_solo_" .. per .. "_2", 0)
      mod.save:set("adventure_solo_" .. per .. "_3", 0)
    end

    mod.save:set("mood_base", "FINE")
    mod.save:set("mood_steps_remaining", 0)
    for _, food in ipairs(FOODS) do setFoodCount(food.id, 0) end
  end)


  local function shallowCopy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
  end

  -- Recreate Gen 1's crit threshold so CONFIDENT can add half of the
  -- vanilla chance after a failed vanilla roll, for a ~1.5x total rate.
  local function critThreshold(ctx)
    local attacker = ctx and ctx.attacker
    if not attacker or not attacker.def or not attacker.def.baseStats then return 0 end
    local ruleset = ctx.ruleset or {}
    local function shl(x) return math.min(255, x * 2) end
    local speed = attacker.def.baseStats.speed or 0
    local b = math.floor(speed / 2)

    if attacker.focusEnergy then
      if ruleset.focusEnergyBug then
        b = math.floor(b / 2)
      else
        b = shl(shl(shl(b)))
      end
    else
      b = shl(b)
    end

    if ctx.highCrit then
      b = shl(shl(b))
    else
      b = math.floor(b / 2)
    end
    return math.max(0, math.min(255, b))
  end

  -- Randomized base Speed can make Gen I high-crit moves effectively
  -- guaranteed. PokeSurvive keeps their identity but caps HIGH-CRIT moves at
  -- 50% for both sides. Ordinary moves retain the vanilla Gen I formula.
  -- CONFIDENT still boosts ordinary player crit chance by ~1.5x, but it does
  -- not push a high-crit move above the 50% ceiling.
  mod.hooks:wrap("battle.crit", function(next, ctx)
    local attacker = ctx and ctx.attacker
    local rng = (ctx and ctx.rng) or love.math.random

    if ctx and ctx.highCrit then
      return rng(0, 255) < 128
    end

    local vanilla = next(ctx)
    if vanilla or mood() ~= "CONFIDENT" then return vanilla end
    if not (attacker and attacker.isPlayer) then return vanilla end

    local base = critThreshold(ctx) / 256
    if base <= 0 then return false end
    local needed = math.min(1, (0.5 * base) / math.max(0.0001, 1 - base))
    return rng() < needed
  end)

  -- FOCUSED / EXHAUSTED: alter only player-side move accuracy.
  mod.hooks:wrap("battle.accuracy", function(next, ctx)
    local user = ctx and ctx.user
    if not (user and user.isPlayer and ctx.move) then return next(ctx) end

    local scale = 1
    local m = mood()
    if m == "FOCUSED" then scale = 1.25
    elseif m == "EXHAUSTED" or m == "DEPLETED" then scale = 0.75
    elseif m == "ANGRY" then scale = 0.90
    else return next(ctx) end

    local c = shallowCopy(ctx)
    c.move = shallowCopy(ctx.move)
    c.move.accuracy = math.max(1, math.min(100, (c.move.accuracy or 100) * scale))
    return next(c)
  end)

  -- ANGRY: +5% player-side damage.
  mod.hooks:wrap("battle.damage", function(next, ctx)
    local damage, info = next(ctx)
    if type(damage) ~= "number" or damage <= 0 then return damage, info end

    local userIsPlayer = ctx and ctx.user and ctx.user.isPlayer
    if not userIsPlayer then
      -- Enemy damage is intentionally untouched by core mood. A bad run should
      -- not become increasingly lethal just because morale has fallen.
      return damage, info
    end

    local mult = 1.00
    local core = coreMood()

    if core == "MISERABLE" then
      mult = mult * 0.90
    elseif core == "SAD" then
      mult = mult * 0.95
    elseif core == "HAPPY" then
      mult = mult * 1.05
    elseif core == "ECSTATIC" then
      mult = mult * 1.10
    end

    -- Temporary emotions layer over the long-term mood instead of replacing it.
    if emotion() == "ANGRY" then
      mult = mult * 1.15
    end

    if mult == 1.00 then return damage, info end
    return math.max(1, math.floor(damage * mult)), info
  end)

  -- RELAXED: +10% effective catch rate, capped at Gen 1's byte ceiling.
  mod.hooks:wrap("catch.rate", function(next, ball, mon, def, opts)
    if mood() ~= "RELAXED" then return next(ball, mon, def, opts) end
    opts = shallowCopy(opts)

    if opts.rateOverride then
      opts.rateOverride = math.min(255, math.floor(opts.rateOverride * 1.25))
      return next(ball, mon, def, opts)
    end

    local d = shallowCopy(def)
    d.catchRate = math.min(255, math.floor((def.catchRate or 0) * 1.25))
    return next(ball, mon, d, opts)
  end)

  -- UNEASY: +25% encounter rate without changing encounter species slots.
  mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
    if mood() ~= "UNEASY" then return next(encDef, ctx) end
    if not (encDef and encDef.grass) then return next(encDef, ctx) end

    local e = shallowCopy(encDef)
    e.grass = shallowCopy(encDef.grass)
    e.grass.rate = math.min(255, math.floor((e.grass.rate or 0) * 1.25))
    return next(e, ctx)
  end)

  -- UNEASY trainers are primed to retreat; ANGRY trainers are reluctant
  -- to back down. We influence the vanilla Gen I escape formula through its
  -- player-speed input rather than bolting on a second success/failure roll.
  mod.hooks:wrap("battle.run", function(next, ctx)
    if not ctx then return next(ctx) end
    local m = mood()
    if m ~= "UNEASY" and m ~= "ANGRY" then return next(ctx) end
    if ctx.battle and ctx.battle.ghost then return next(ctx) end

    local c = shallowCopy(ctx)
    if m == "UNEASY" then
      c.pSpd = math.max(1, math.floor((tonumber(ctx.pSpd) or 1) * 1.25))
    else
      c.pSpd = math.max(1, math.floor((tonumber(ctx.pSpd) or 1) * 0.85))
    end
    return next(c)
  end)


  -- CONFIDENT: a small capture edge. This modifies only the effective
  -- rate for this throw; randomized species catch rates remain unchanged.
  mod.hooks:wrap("catch.rate", function(next, ball, mon, def, opts)
    if mood() ~= "CONFIDENT" or not def then
      return next(ball, mon, def, opts)
    end
    local d = shallowCopy(def)
    d.catchRate = math.min(255, math.max(1,
      math.floor((tonumber(def.catchRate) or 1) * 1.10 + 0.5)))
    return next(ball, mon, d, opts)
  end)

  -- FAMISHED: normal commanded moves have a 25% chance to be refused.
  --
  -- Gen1Recomp 0.1.75 does not expose a dedicated obedience hook, but
  -- battle.turn_started exposes the actual selected move instance. We
  -- temporarily tag that move as the engine's harmless "bound" action:
  -- executeAction then spends the player's turn without using the move or
  -- consuming PP. The tag is removed at turn end so the move itself is
  -- never permanently altered.
  --
  -- This intentionally applies only to ordinary chosen moves. Forced
  -- continuations (Bide, trapping, recharge, Struggle, etc.) are left alone.
  local famishedRefusals = setmetatable({}, { __mode = "k" })

  mod.events:on("battle.turn_started", function(ev)
    local m = mood()
    if m ~= "FAMISHED" and m ~= "DEPLETED" then return end

    local battle = ev and ev.battle
    local action = ev and ev.playerAction
    if not battle or not action then return end
    if battle.kind == "link" or battle.demo or battle.safari or battle.ghost then return end
    if not action.id or action.special or action.struggle then return end
    if math.random(1, 100) > 25 then return end

    famishedRefusals[battle] = {
      action = action,
      special = action.special,
    }

    action.special = "bound"

    local name = battle.player and battle.player.name or "POKEMON"
    if battle.say then
      battle:say(tostring(name) .. " ignored\norders!")
    end
  end, 100)

  local function restoreFamishedAction(battle)
    local rec = battle and famishedRefusals[battle]
    if not rec then return end
    if rec.action then rec.action.special = rec.special end
    famishedRefusals[battle] = nil
  end

  mod.events:on("battle.turn_ended", function(ev)
    restoreFamishedAction(ev and ev.battle)
  end, -100)

  mod.events:on("battle.ended", function(ev)
    restoreFamishedAction(ev and ev.battle)
  end, -100)

  -- Long-term morale gains from ordinary journey progress.
  -- These hooks were lost during an earlier refactor, which left the core
  -- mood meter stuck at FINE during normal play.
  mod.events:on("pokemon.caught", function(ev)
    if not pokesimEnabled() then return end
    adjustMood(12)
    mod.save:set("mood_win_streak", 0)
  end, -25)

  mod.events:on("battle.ended", function(ev)
    if not pokesimEnabled() then return end
    local battle = ev and ev.battle
    local result = ev and ev.result
    if not battle then return end
    if battle.kind == "link" or battle.demo or battle.safari or battle.ghost then return end

    if result == "win" then
      -- Trainer victories feel a bit more meaningful than ordinary wild wins.
      adjustMood(battle.kind == "trainer" and 4 or 2)

      local streak = math.max(0, math.floor(
        tonumber(mod.save:get("mood_win_streak", 0)) or 0
      )) + 1
      mod.save:set("mood_win_streak", streak)

      -- A streak creates an opportunity for Confidence, not a guaranteed
      -- recurring ping. Whether it fires or not, the streak cycle resets.
      if streak >= 4 then
        if emotion() == "NONE" and not physicalMood()
          and math.random(1, 100) <= 35 then
          setTemporaryMood("CONFIDENT", 360)
        end
        mod.save:set("mood_win_streak", 0)
      end
    elseif result == "lose" then
      mod.save:set("mood_win_streak", 0)

      -- Normally a permadeath wipe ends the run anyway. This mostly matters
      -- with permadeath disabled. Oak's tutorial loss is deliberately neutral.
      if not oakLabPermadeathProtected(battle.game) then
        adjustMood(-8)
      end
    end
  end, -40)

  -- Small journey events keep morale/emotions feeling alive without making
  -- every interaction a major swing.

  mod.events:on("pokemon.level_up", function(ev)
    if not pokesimEnabled() then return end
    adjustMood(1)
  end, -20)

  mod.events:on("pokemon.evolved", function(ev)
    if not pokesimEnabled() then return end
    adjustMood(8)
    if emotion() == "NONE" then
      setTemporaryMood("CONFIDENT", 420)
    end
  end, -20)

  mod.events:on("pokemon.move_learned", function(ev)
    if not pokesimEnabled() then return end
    if emotion() == "NONE" and not physicalMood()
      and math.random(1, 100) <= 35 then
      setTemporaryMood("CURIOUS", 220)
    end
  end, -20)

  mod.events:on("battle.status_inflicted", function(ev)
    if not pokesimEnabled() then return end
    local target = ev and ev.target
    if target and target.isPlayer and emotion() == "NONE"
      and math.random(1, 100) <= 50 then
      setTemporaryMood("UNEASY", 280)
    end
  end, -20)

  mod.events:on("map.entered", function(ev)
    if not pokesimEnabled() then return end
    local mapId = ev and ev.mapId
    if not mapId or mapId == "" then return end

    if tostring(mapId):upper():find("POKECENTER", 1, true) then
      local game = require("src.core.Game")
      local ow = game and game.overworld
      local player = ow and ow.player

      local fieldMap = tostring(mod.save:get("last_field_map", "") or "")
      if fieldMap ~= "" and fieldMap ~= tostring(mapId) then
        mod.save:set("last_center_return_map", fieldMap)
        mod.save:set("last_center_return_x",
          tonumber(mod.save:get("last_field_x", 0)) or 0)
        mod.save:set("last_center_return_y",
          tonumber(mod.save:get("last_field_y", 0)) or 0)
        mod.save:set("last_center_return_facing",
          tostring(mod.save:get("last_field_facing", "down") or "down"))
      end

      if player then
        mod.save:set("last_center_map", tostring(mapId))
        mod.save:set("last_center_x", tonumber(player.cellX) or 0)
        mod.save:set("last_center_y", tonumber(player.cellY) or 0)
        mod.save:set("last_center_facing", tostring(player.facing or "down"))
      end
    end

    if ev.fromMapId and ev.fromMapId ~= ""
      and tostring(ev.fromMapId) ~= tostring(mapId) then

      local areaCount = math.max(0, math.floor(
        tonumber(mod.save:get("adventure_area_counter", 0)) or 0
      )) + 1
      areaCount = math.min(areaCount, 4)

      local shouldQueue = false
      if areaCount >= 4 then
        shouldQueue = true
      elseif areaCount == 3 and math.random(1, 100) <= 50 then
        shouldQueue = true
      elseif areaCount == 2 and math.random(1, 100) <= 20 then
        shouldQueue = true
      end

      if shouldQueue and Personality.queueNatural() then
        areaCount = 0
        mod.save:set("adventure_missed_checks", 0)
      end

      mod.save:set("adventure_area_counter", areaCount)
    end

    local key = "mood_visited_map_" .. tostring(mapId)
    if not mod.save:get(key, false) then
      mod.save:set(key, true)

      -- Discovery gives only a tiny long-term lift; the visible reaction is
      -- primarily CURIOUS. Starting locations are allowed to seed the visited
      -- flag without making the trainer immediately react on a loaded save.
      if ev.fromMapId and ev.fromMapId ~= "" then
        adjustMood(1)
        if emotion() == "NONE" and not physicalMood()
          and math.random(1, 100) <= 20 then
          setTemporaryMood("CURIOUS", 260)
        end
      end
    end
  end, -20)

  -- Battles consume supplies and stamina. Trainer fights are more taxing
  -- than quick wild encounters, while passive travel drain remains unchanged.
  mod.events:on("battle.ended", function(ev)
    if not pokesimEnabled() then return end
    local battle = ev and ev.battle
    if not battle then return end
    if battle.kind == "link" or battle.demo or battle.safari or battle.ghost then return end

    setHunger(hunger() - 3)
    setEnergy(energy() - (battle.kind == "trainer" and 4 or 2))
    reconcileMoodAfterNeedChange()
  end, -50)

  -- ================================================================
  -- PokeSim Permadeath v1
  -- Fainted party Pokémon permanently leave the run when the run rule is ON.
  -- The opening Oak's Lab rival fight is exempt so the game can start.
  -- ================================================================
  local permadeathFaints = setmetatable({}, { __mode = "k" })
  local pendingFieldLosses = {}
  local pendingFieldGameOver = false

  local function currentMapId(game)
    if game and game.overworld and game.overworld.map
      and game.overworld.map.id then
      return tostring(game.overworld.map.id)
    end
    if game and game.save and game.save.player
      and game.save.player.map then
      return tostring(game.save.player.map)
    end
    return ""
  end

  local function oakLabPermadeathProtected(game)
    -- There is only one battle in Oak's Lab: the mandatory starter rival fight.
    -- Protect the entire location instead of relying on transient battle metadata.
    return currentMapId(game) == "OAKS_LAB"
  end

  local function monDisplayName(game, mon)
    if not mon then return "Pokémon" end
    if mon.nickname and mon.nickname ~= "" then return tostring(mon.nickname) end
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    return tostring((def and def.name) or mon.species or "Pokémon")
  end

  local function removePartyMon(save, mon)
    for i = #save.party, 1, -1 do
      if save.party[i] == mon then
        table.remove(save.party, i)
        return true
      end
    end
    return false
  end

  local function goToTitle(game)
    while game.stack and game.stack:top() do
      game.stack:pop()
    end
    game.stack:push(game:makeTitleState())
  end

  local function showLossMessages(game, names, onDone)
    local i = 0
    local function nextMsg()
      i = i + 1
      if not names[i] then
        if onDone then onDone() end
        return
      end
      say(game, tostring(names[i]) .. " ran off...", nextMsg)
    end
    nextMsg()
  end

  mod.events:on("battle.fainted", function(ev)
    if not permadeathEnabled() then return end
    local battle = ev and ev.battle
    local battler = ev and ev.battler
    if not battle or not battler or not battler.isPlayer then return end

    -- Oak's Lab is the one tutorial-safe location. This protects the mandatory
    -- starter battle regardless of randomizer metadata or callback timing.
    if oakLabPermadeathProtected(battle.game) then
      return
    end

    -- Explicit tutorial grace is authoritative. This persists across the
    -- battle-to-overworld transition until the starter has been healed.
    if mod.save:get("oak_rival_freebie_pending", false) == true then
      return
    end

    -- The mandatory Oak starter rival fight is the ONE battle exempt from
    -- permadeath. Gen1Recomp uses OPP_RIVAL1 party slots 1-3 exclusively for
    -- the three possible Oak starter matchups. Later RIVAL1 battles use later
    -- party indices, so this identity is stable even when map state has already
    -- shifted during battle callbacks.
    if battle.oppClass == "OPP_RIVAL1"
      and (tonumber(battle.partyIndex) or 0) >= 1
      and (tonumber(battle.partyIndex) or 0) <= 3 then
      return
    end

    local list = permadeathFaints[battle]
    if not list then
      list = {}
      permadeathFaints[battle] = list
    end
    for _, mon in ipairs(list) do
      if mon == battler.mon then return end
    end
    table.insert(list, battler.mon)
  end)

  mod.events:on("battle.ended", function(ev)
    if not permadeathEnabled() then return end
    local battle = ev and ev.battle
    local lost = battle and permadeathFaints[battle]
    permadeathFaints[battle] = nil
    if not battle or not lost or #lost == 0 then return end

    if oakLabPermadeathProtected(battle.game) then
      return
    end

    if mod.save:get("oak_rival_freebie_pending", false) == true then
      return
    end

    -- Defensive second check at resolution time. Even if a future event path
    -- records the starter as fainted, never resolve permadeath for the Oak
    -- starter matchup (RIVAL1 party slots 1-3).
    if battle.oppClass == "OPP_RIVAL1"
      and (tonumber(battle.partyIndex) or 0) >= 1
      and (tonumber(battle.partyIndex) or 0) <= 3 then
      return
    end

    local game = battle.game
    Personality.ensureParty(game)

    local names = {}
    local resolved = {}

    for _, candidate in ipairs(lost) do
      local mon = nil

      for _, partyMon in ipairs(game.save.party or {}) do
        if not resolved[partyMon] and partyMon == candidate then
          mon = partyMon
          break
        end
      end

      if not mon then
        for _, partyMon in ipairs(game.save.party or {}) do
          if not resolved[partyMon]
            and partyMon.species == candidate.species
            and tostring(partyMon.nickname or "") == tostring(candidate.nickname or "")
            and (tonumber(partyMon.hp or 0) or 0) <= 0 then
            mon = partyMon
            break
          end
        end
      end

      if mon then
        resolved[mon] = true
        table.insert(names, monDisplayName(game, mon))
        removePartyMon(game.save, mon)
        adjustMood(-35)
        mod.save:set("mood_win_streak", 0)
      end
    end

    if #names == 0 then return end

    local griefMessage = nil
    if #game.save.party > 0 and math.random(1, 100) <= 35 then
      local survivor = game.save.party[math.random(1, #game.save.party)]
      local sn, sp = monDisplayName(game, survivor), Personality.get(survivor)
      if sp == "LOYAL" then griefMessage = sn .. " STAYS VERY CLOSE\nTO THE OTHERS."
      elseif sp == "BOLD" then griefMessage = sn .. " LOOKS DETERMINED\nNOT TO LET IT HAPPEN AGAIN."
      elseif sp == "TIMID" then griefMessage = sn .. " WON'T STOP\nLOOKING BEHIND IT."
      elseif sp == "AGGRESSIVE" then griefMessage = sn .. " IS VISIBLY\nFURIOUS."
      elseif sp == "PLAYFUL" then griefMessage = sn .. " IS QUIETER\nTHAN USUAL."
      elseif sp == "STUBBORN" then griefMessage = sn .. " REFUSES TO\nLEAVE THE SPOT AT FIRST."
      elseif sp == "INQUISITIVE" then griefMessage = sn .. " KEEPS SEARCHING\nFOR ITS TEAMMATE."
      else griefMessage = sn .. " SETTLES DOWN\nWITHOUT A SOUND." end
    end

    -- battle.ended fires just before BattleState captures onFinish for the
    -- return transition. Wrapping it here lets the "ran off" messages appear
    -- naturally once the battle screen has faded back to the overworld.
    local originalFinish = battle.onFinish
    local lossMessagesHandled = false

    if #game.save.party == 0 then
      battle.onFinish = function(result)
        if lossMessagesHandled then return end
        lossMessagesHandled = true
        showLossMessages(game, names, function()
          say(game, "You have no Pokémon\nleft...", function()
            mod.save:set("permadeath_ignore_stale_field_once", true)
            goToTitle(game)
          end)
        end)
      end
    else
      battle.onFinish = function(result)
        if lossMessagesHandled then
          -- If the engine calls onFinish again, never repeat PokeSurvive's
          -- run-off dialogue. Preserve vanilla completion at most once.
          return
        end
        lossMessagesHandled = true
        showLossMessages(game, names, function()
          if griefMessage then
            say(game, griefMessage, function()
              if originalFinish then originalFinish(result) end
            end)
          elseif originalFinish then
            originalFinish(result)
          end
        end)
      end
    end
  end)

  -- ================================================================
  -- CURIOUS hidden-scene discoveries
  --
  -- While CURIOUS is the active displayed mood, pressing A on otherwise
  -- non-interactive SOLID scenery gets one 5% hidden-item roll per map/tile.
  -- Existing signs, NPCs, vanilla hidden items, bookshelves, PCs, etc. resolve
  -- before world.interacted(kind="none"), so PokeSurvive never replaces them.
  -- ================================================================
  local CURIOUS_HIDDEN_CHANCE = 5
  local CURIOUS_ITEM_POOL = {
    "POTION", "POTION", "POTION",
    "ANTIDOTE", "PARLYZ_HEAL", "AWAKENING", "BURN_HEAL", "ICE_HEAL",
    "POKE_BALL", "POKE_BALL", "REPEL",
    "SUPER_POTION", "ESCAPE_ROPE",
  }

  local function curiousTileKey(mapId, x, y)
    return "curious_checked_" .. tostring(mapId)
      .. "_" .. tostring(x) .. "_" .. tostring(y)
  end

  local function curiousHiddenReward(game)
    local id = CURIOUS_ITEM_POOL[math.random(1, #CURIOUS_ITEM_POOL)]
    if not game.data.items[id] then return nil end
    return id
  end

  mod.events:on("world.interacted", function(ev)
    if not pokesimEnabled() then return end
    if mood() ~= "CURIOUS" then return end
    if not ev or ev.kind ~= "none" then return end

    local game = require("src.core.Game")
    local ow = game and game.overworld
    local map = ow and ow.map
    if not map or tostring(map.id) ~= tostring(ev.mapId) then return end

    local x, y = tonumber(ev.x), tonumber(ev.y)
    if not x or not y or not map:inBounds(x, y) then return end

    -- Solid scenery only. Water and ordinary walkable floor never qualify.
    if map:isWalkableCell(x, y) or map:isWaterCell(x, y) then return end

    local key = curiousTileKey(ev.mapId, x, y)
    if mod.save:get(key, false) then return end
    mod.save:set(key, true) -- one roll per tile, success or failure

    local forced = mod.save:get("curious_force_find", false) == true
    if forced then mod.save:set("curious_force_find", false) end
    if not forced and math.random(1, 100) > CURIOUS_HIDDEN_CHANCE then return end

    local itemId = curiousHiddenReward(game)
    if not itemId then return end

    local Bag = require("src.inventory.Bag")
    local def = game.data.items[itemId]
    local itemName = tostring((def and def.name) or itemId)

    if not Bag.add(game.save, itemId, 1, game.data) then
      say(game,
        "YOU NOTICE SOMETHING\nTUCKED AWAY...\f" ..
        "BUT YOUR BAG IS\nTOO FULL TO TAKE IT.")
      return
    end

    require("src.core.Sound").play(game.data, "Get_Item1")
    adjustMood(3)
    if math.random(1, 100) <= 35 then
      setTemporaryMood("THRIFTY", 360)
    end
    say(game,
      "YOU NOTICE SOMETHING\nHIDDEN HERE!\f" ..
      "YOU FOUND\n" .. itemName .. "!")
  end, -30)

  -- The only ordinary field mechanic that can currently faint Pokémon is
  -- out-of-battle poison. The global input hook returns after the overworld
  -- has applied that poison tick, so catch newly-zeroed party members there.
  local fieldLastHP = setmetatable({}, { __mode = "k" })

  local function snapshotFieldParty(game)
    if not game or not game.save then return end
    for _, mon in ipairs(game.save.party or {}) do
      fieldLastHP[mon] = tonumber(mon.hp or 0) or 0
    end
  end

  local function collectFieldPermadeath(game)
    if not game or not game.save then return end

    if mod.save:get("permadeath_ignore_stale_field_once", false) == true then
      mod.save:set("permadeath_ignore_stale_field_once", false)
      pendingFieldLosses = {}
      pendingFieldGameOver = false
      snapshotFieldParty(game)
      return
    end

    if oakLabPermadeathProtected(game) then
      -- Clear any stale field-death bookkeeping from the battle transition and
      -- keep refreshing HP so the 0->healed change never looks like a field faint.
      pendingFieldLosses = {}
      pendingFieldGameOver = false
      snapshotFieldParty(game)
      return
    end

    if mod.save:get("oak_rival_freebie_pending", false) == true then
      local party = game.save.party or {}
      local allHealthy = #party > 0
      for _, mon in ipairs(party) do
        if (tonumber(mon.hp or 0) or 0) <= 0 then
          allHealthy = false
          break
        end
      end

      -- Oak's post-battle script has completed its free heal. Only now does
      -- normal field permadeath resume.
      if allHealthy then
        mod.save:set("oak_rival_freebie_pending", false)
        snapshotFieldParty(game)
      end
      return
    end

    if not permadeathEnabled() then
      snapshotFieldParty(game)
      return
    end

    local newlyLost = {}
    for _, mon in ipairs(game.save.party or {}) do
      local now = tonumber(mon.hp or 0) or 0
      local before = fieldLastHP[mon]
      if before ~= nil and before > 0 and now <= 0 then
        table.insert(newlyLost, mon)
      end
      fieldLastHP[mon] = now
    end

    if #newlyLost == 0 then return end

    for _, mon in ipairs(newlyLost) do
      table.insert(pendingFieldLosses, monDisplayName(game, mon))
      removePartyMon(game.save, mon)
      adjustMood(-35)
      mod.save:set("mood_win_streak", 0)
      fieldLastHP[mon] = nil
    end

    if #game.save.party == 0 then
      pendingFieldGameOver = true
    end
  end

  local function serviceFieldPermadeath(game)
    if oakLabPermadeathProtected(game) then
      pendingFieldLosses = {}
      pendingFieldGameOver = false
      return
    end

    if mod.save:get("oak_rival_freebie_pending", false) == true then
      pendingFieldLosses = {}
      pendingFieldGameOver = false
      return
    end
    if not game or not game.stack or not game.overworld then return end
    if game.stack:top() ~= game.overworld then return end
    if #pendingFieldLosses == 0 and not pendingFieldGameOver then return end

    local names = pendingFieldLosses
    pendingFieldLosses = {}
    local gameOver = pendingFieldGameOver
    pendingFieldGameOver = false

    showLossMessages(game, names, function()
      if gameOver then
        say(game, "You have no Pokémon\nleft...", function()
          mod.save:set("permadeath_ignore_stale_field_once", true)
          goToTitle(game)
        end)
      end
    end)
  end

  -- Register this hook AFTER the local field-permadeath functions above.
  -- That guarantees Lua captures the intended locals instead of unresolved globals.
  mod.hooks:wrap("input.step", function(next, game, dt)
    syncRandomizedTypeDefinitions()

    -- Snapshot the current overworld position BEFORE the engine processes this
    -- input. If this input enters a Pokemon Center, map.entered can safely read
    -- the exact exterior tile we came from.
    if game and game.overworld and game.overworld.map
      and game.overworld.player and game.overworld.map.id then
      local currentMap = tostring(game.overworld.map.id)
      if not currentMap:upper():find("POKECENTER", 1, true) then
        mod.save:set("last_field_map", currentMap)
        mod.save:set("last_field_x",
          tonumber(game.overworld.player.cellX) or 0)
        mod.save:set("last_field_y",
          tonumber(game.overworld.player.cellY) or 0)
        mod.save:set("last_field_facing",
          tostring(game.overworld.player.facing or "down"))
      end
    end

    if mod.save:get("depleted_collapse_pending", false) == true
      and game and game.stack and game.overworld
      and game.stack:top() == game.overworld then

      local centerMap = tostring(mod.save:get("last_center_return_map", "") or "")
      local centerX = tonumber(mod.save:get("last_center_return_x", 0)) or 0
      local centerY = tonumber(mod.save:get("last_center_return_y", 0)) or 0
      local centerFacing = tostring(
        mod.save:get("last_center_return_facing", "down") or "down"
      )

      -- Safety fallback for saves created before reliable Center exterior
      -- tracking existed. Prefer the latest valid field snapshot over silently
      -- suppressing the blackout.
      if centerMap == "" then
        centerMap = tostring(mod.save:get("last_field_map", "") or "")
        centerX = tonumber(mod.save:get("last_field_x", 0)) or 0
        centerY = tonumber(mod.save:get("last_field_y", 0)) or 0
        centerFacing = tostring(
          mod.save:get("last_field_facing", "down") or "down"
        )
      end

      if centerMap ~= "" and game.data and game.data.maps
        and game.data.maps[centerMap] then

        mod.save:set("depleted_collapse_pending", false)
        mod.save:set("depleted_collapse_steps", 0)

        setHunger(25)
        setEnergy(25)
        clearTemporaryMood()
        reconcileMoodAfterNeedChange()

        say(game,
          pacedDialogue(
            "Your vision blurs and your legs give out.\f"
              .. "When you wake up, someone has brought you back outside the last Pokemon Center you visited."
          ),
          function()
            local WorldAPI = require("src.world.WorldAPI")
            local world = WorldAPI.new(game, "pokesurvive")
            world:warpTo(centerMap, centerX, centerY, centerFacing, {
              arrive = "teleport",
            })
          end
        )
        return nil
      else
        mod.save:set("depleted_collapse_pending", false)
        mod.save:set("depleted_collapse_steps", 249)
      end
    end

    if Personality.servicePending(game) then
      return nil
    end

    -- Establish pre-tick HP state. On later ticks fieldLastHP already contains
    -- the previous post-tick values, which become our comparison baseline.
    local hasBaseline = false
    if game and game.save then
      for _, mon in ipairs(game.save.party or {}) do
        if fieldLastHP[mon] ~= nil then
          hasBaseline = true
          break
        end
      end
      if not hasBaseline then snapshotFieldParty(game) end
    end

    local result = next(game, dt)

    -- Leaving Oak's Lab permanently ends the tutorial freebie. The starter
    -- should already have been healed by the vanilla lab script.
    if currentMapId(game) ~= "OAKS_LAB"
      and mod.save:get("oak_rival_freebie_pending", false) == true then
      mod.save:set("oak_rival_freebie_pending", false)
      snapshotFieldParty(game)
    end

    -- Poison/field damage occurs during the engine tick above.
    collectFieldPermadeath(game)
    serviceFieldPermadeath(game)

    return result
  end)

  -- ================================================================
  -- PokeSim NPC Conversation Engine v1
  --
  -- Safety rule: only explicitly whitelisted ambient NPC TEXT constants
  -- are overridden. Functional NPCs (gifts, story triggers, trainers,
  -- shops, healing, etc.) remain entirely vanilla unless a future
  -- integration deliberately wraps their base behavior.
  -- ================================================================
  local NPC_CHATS = {}

  local function npcSaveKey(key, field)
    return "npc_chat_" .. tostring(key) .. "_" .. tostring(field)
  end

  local function npcChatCount(key)
    return math.max(0, math.floor(
      tonumber(mod.save:get(npcSaveKey(key, "count"), 0)) or 0
    ))
  end

  local function npcMemory(key, field, fallback)
    return mod.save:get(npcSaveKey(key, field), fallback)
  end

  local function setNpcMemory(key, field, value)
    mod.save:set(npcSaveKey(key, field), value)
  end

  local function npcRelationshipStage(key)
    local count = npcChatCount(key)
    if count >= 8 then return "acquaintance" end
    if count >= 3 then return "familiar" end
    return "stranger"
  end

  local function npcSeenLead(key, leadName)
    if not leadName or leadName == "" or leadName == "YOUR POKEMON" then return false end
    return npcMemory(key, "seen_lead_" .. leadName, false) == true
  end

  local function rememberNpcLead(key, leadName)
    if not leadName or leadName == "" or leadName == "YOUR POKEMON" then return end
    setNpcMemory(key, "seen_lead_" .. leadName, true)
    setNpcMemory(key, "last_lead", leadName)
  end

  local function markNpcThread(key, thread, value)
    setNpcMemory(key, "thread_" .. thread, value == nil and true or value)
  end

  local function npcThread(key, thread, fallback)
    return npcMemory(key, "thread_" .. thread, fallback)
  end

  local function registerNpcChat(key, def)
    NPC_CHATS[key] = NPC_CHATS[key] or {}
    table.insert(NPC_CHATS[key], def)
  end

  local function chooseNpcChat(key, ctx)
    local pool = NPC_CHATS[key] or {}
    local last = npcMemory(key, "last", "")
    local choices, total = {}, 0

    for _, def in ipairs(pool) do
      if (not def.eligible) or def.eligible(ctx) then
        local weight = tonumber(def.weight or 1) or 1
        if def.id == last then
          weight = math.max(1, math.floor(weight * 0.20))
        end
        if weight > 0 then
          total = total + weight
          table.insert(choices, { def = def, ceiling = total })
        end
      end
    end

    if total <= 0 then return nil end
    local roll = math.random(1, total)
    for _, choice in ipairs(choices) do
      if roll <= choice.ceiling then return choice.def end
    end
    return choices[#choices].def
  end

  local function pushResponseMenu(game, responses, onCancel)
    local Menu = require("src.ui.Menu")
    local Strings = require("src.core.Strings")
    local Theme = require("src.ui.Theme")
    local items = {}

    for _, response in ipairs(responses or {}) do
      table.insert(items, {
        label = Strings(response.label),
        onSelect = response.onSelect,
      })
    end

    -- Match the vanilla YES/NO box position: upper-right, directly above
    -- the anchored dialogue box. Menu.new can widen leftward for longer
    -- custom response labels while keeping the same right edge.
    local box = Theme.choiceBox
    local menu = Menu.new(game, items, {
      tx = box.tx,
      ty = box.ty,
      tw = box.tw,
      anchor = "bottom",
      cancelable = onCancel ~= nil,
      onCancel = onCancel,
    })
    game.stack:push(menu)
  end

  -- Custom NPC dialogue is authored as prose and wrapped here instead
  -- of relying on hand-inserted line breaks. \f remains an intentional
  -- page break.
  local NPC_DIALOGUE_WIDTH = 18

  local function wrapNpcPage(page)
    page = tostring(page or "")
    page = page:gsub("\n", " ")
    page = page:gsub("%s+", " ")
    page = page:gsub("^%s+", ""):gsub("%s+$", "")
    if page == "" then return "" end

    local lines, line = {}, ""
    for word in page:gmatch("%S+") do
      if line == "" then
        line = word
      elseif #line + 1 + #word <= NPC_DIALOGUE_WIDTH then
        line = line .. " " .. word
      else
        table.insert(lines, line)
        line = word
      end
    end
    if line ~= "" then table.insert(lines, line) end
    return table.concat(lines, "\n")
  end

  local function wrapNpcDialogue(dialogue)
    dialogue = tostring(dialogue or "")
    local pages, start = {}, 1

    while true do
      local pos = dialogue:find("\f", start, true)
      if not pos then
        table.insert(pages, wrapNpcPage(dialogue:sub(start)))
        break
      end
      table.insert(pages, wrapNpcPage(dialogue:sub(start, pos - 1)))
      start = pos + 1
    end

    return table.concat(pages, "\f")
  end

  local function runNpcChat(key, game, ow, npc, done)
    local ctx = {
      key = key,
      game = game,
      overworld = ow,
      npc = npc,
      count = npcChatCount(key),
      lastResponse = npcMemory(key, "response", ""),
      stage = npcRelationshipStage(key),
      hunger = hunger(),
      energy = energy(),
      mood = mood(),
      food = totalFood(),
      lead = leadPokemon(game),
      leadName = leadPokemonName(game),
      lastLeadName = npcMemory(key, "last_lead", ""),
    }

    local def = chooseNpcChat(key, ctx)
    if not def then
      done()
      return
    end

    setNpcMemory(key, "last", def.id)
    mod.save:set(npcSaveKey(key, "count"), ctx.count + 1)
    rememberNpcLead(key, ctx.leadName)

    if npc and npc.facePlayer and ow and ow.player then
      npc:facePlayer(ow.player)
    end

    if def.run then
      def.run(ctx, done)
      return
    end

    local prompt = type(def.prompt) == "function" and def.prompt(ctx) or def.prompt
    prompt = wrapNpcDialogue(prompt or "...")
    local responseDefs = def.responses or {}

    if #responseDefs == 0 then
      say(game, prompt, done)
      return
    end

    -- Keep the dialogue visible while the response menu is on top, just
    -- like vanilla dialogue choices. The response menu owns input until a
    -- choice is made; then we remove the held text box before showing the
    -- NPC's reply.
    local textBox
    textBox = mod.ui.TextBox.new(game, prompt, nil, {
      stay = {
        onShown = function()
          local responses = {}
          for _, r in ipairs(responseDefs) do
            table.insert(responses, {
              label = r.label,
              onSelect = function()
                -- Menu has already popped itself. The held dialogue box is
                -- now on top and must be removed before the reply appears.
                if game.stack:top() == textBox then game.stack:pop() end

                setNpcMemory(key, "response", r.id or r.label)
                if r.mood then setTemporaryMood(r.mood) end
                if r.effect then r.effect(ctx) end

                local reply = type(r.reply) == "function" and r.reply(ctx) or r.reply
                if reply and reply ~= "" then
                  say(game, wrapNpcDialogue(reply), done)
                else
                  done()
                end
              end,
            })
          end

          pushResponseMenu(game, responses, function()
            if game.stack:top() == textBox then game.stack:pop() end
            done()
          end)
        end,
      },
    })
    game.stack:push(textBox)
  end

  local function runBaseNpcTalk(mapId, textId, ctx, done)
    -- Safe ambient wrappers can still surface the exact vanilla handler as
    -- one possible conversation without copying its logic.
    local MapScripts = require("src.script.MapScripts")
    local base = MapScripts.baseTalk(mapId, textId)
    if base then
      base(ctx.game, ctx.overworld, ctx.npc, done)
    else
      done()
    end
  end

  -- ---------------- VIRIDIAN AMBIENT NPC PROTOTYPE ----------------

  registerNpcChat("viridian_gambler", {
    id = "vanilla",
    weight = 5,
    run = function(ctx, done)
      runBaseNpcTalk("VIRIDIAN_CITY", "TEXT_VIRIDIANCITY_GAMBLER1", ctx, done)
    end,
  })

  registerNpcChat("viridian_gambler", {
    id = "road",
    weight = 8,
    prompt =
      "You've been on the\nroad a while.\f" ..
      "Still enjoying\nthe trip?",
    responses = {
      {
        id = "love_it",
        label = "Love it",
        mood = "HAPPY",
        reply = "Ha! That's the\nspirit.\fKeep at it!",
      },
      {
        id = "rough",
        label = "It's rough",
        mood = "SAD",
        reply =
          "Yeah... The road\ncan wear you down.\f" ..
          "Take care of\nyourself.",
      },
    },
  })

  registerNpcChat("viridian_gambler", {
    id = "grass",
    weight = 7,
    prompt = "Tall grass still\nmake you nervous?",
    responses = {
      {
        id = "little",
        label = "A little",
        mood = "UNEASY",
        reply =
          "Smart.\f" ..
          "You never know\nwhat's hiding there.",
      },
      {
        id = "never",
        label = "Not really",
        mood = "CONFIDENT",
        reply = "Heh. You've got\nsome nerve, kid.",
      },
    },
  })

  registerNpcChat("viridian_youngster", {
    id = "vanilla",
    weight = 5,
    run = function(ctx, done)
      runBaseNpcTalk("VIRIDIAN_CITY", "TEXT_VIRIDIANCITY_YOUNGSTER2", ctx, done)
    end,
  })

  registerNpcChat("viridian_youngster", {
    id = "partner",
    weight = 8,
    eligible = function(ctx) return ctx.lead ~= nil end,
    prompt = function(ctx)
      return ctx.leadName .. " looks like\ngood company.\f" ..
        "You two get along?"
    end,
    responses = {
      {
        id = "yes",
        label = "We do",
        mood = "HAPPY",
        reply = "That's great!\fPokémon make the\nroad less lonely.",
      },
      {
        id = "mostly",
        label = "Mostly",
        reply = "Ha! Sounds about\nright.",
      },
    },
  })

  registerNpcChat("viridian_youngster", {
    id = "trouble",
    weight = 7,
    eligible = function(ctx) return ctx.lead ~= nil end,
    prompt = function(ctx)
      return "Does " .. ctx.leadName .. "\never get into\ntrouble?"
    end,
    responses = {
      {
        id = "constant",
        label = "Constantly",
        mood = "HAPPY",
        reply = "Ha ha!\fI knew it!",
      },
      {
        id = "never",
        label = "Never",
        mood = "CONFIDENT",
        reply = "Wow.\fYou must really\nknow each other.",
      },
    },
  })

  registerNpcChat("viridian_girl", {
    id = "vanilla",
    weight = 5,
    run = function(ctx, done)
      runBaseNpcTalk("VIRIDIAN_CITY", "TEXT_VIRIDIANCITY_GIRL", ctx, done)
    end,
  })

  registerNpcChat("viridian_girl", {
    id = "unknown_road",
    weight = 8,
    prompt =
      "Viridian Forest\nchanges every day.\f" ..
      "Do you like not\nknowing what's ahead?",
    responses = {
      {
        id = "yes",
        label = "I like it",
        mood = "CURIOUS",
        reply =
          "Me too!\f" ..
          "It makes every trip\nfeel different.",
      },
      {
        id = "no",
        label = "Not really",
        mood = "UNEASY",
        reply =
          "I get that.\f" ..
          "The forest can be\na little creepy.",
      },
    },
  })

  registerNpcChat("viridian_girl", {
    id = "food_check",
    weight = 10,
    eligible = function(ctx)
      return ctx.hunger <= 45 or ctx.food <= 1
    end,
    prompt =
      "Pewter is a long\nwalk from here.\f" ..
      "You brought enough\nfood, right?",
    responses = {
      {
        id = "prepared",
        label = "I'm ready",
        mood = "FOCUSED",
        reply = "Good!\fIt's easy to forget\nwhen you're excited.",
      },
      {
        id = "not_really",
        label = "...Not really",
        mood = "SAD",
        effect = function(ctx)
          markNpcThread(ctx.key, "food_worry", true)
        end,
        reply =
          "You should stock up\nbefore you go.\f" ..
          "Your Pokémon need\nto eat too.",
      },
    },
  })

  registerNpcChat("viridian_girl", {
    id = "followup_rough",
    weight = 12,
    eligible = function(ctx)
      return ctx.count > 0 and ctx.lastResponse == "not_really"
    end,
    prompt =
      "Hey, you again!\f" ..
      "Did you ever get\nmore food?",
    responses = {
      {
        id = "got_food",
        label = "Yep",
        mood = "HAPPY",
        reply = "Good!\fI was kind of\nworried about you.",
      },
      {
        id = "still_no",
        label = "Not yet",
        mood = "SAD",
        reply = "...Seriously?\fGo to the Mart!",
      },
    },
  })


  -- ================================================================
  -- Ambient World Pass v1
  -- Additional safe flavor conversations. These are conditional and
  -- intentionally acknowledge the current journey rather than merely
  -- adding random filler.
  -- ================================================================

  local function partyCount(game)
    local party = game and game.save and game.save.party or {}
    return #party
  end

  local function injuredPartyPokemon(game)
    local party = game and game.save and game.save.party or {}
    for _, mon in ipairs(party) do
      local hp = tonumber(mon.hp or 0) or 0
      local maxHp = tonumber(mon.maxHp or hp) or hp
      if maxHp > 0 and hp > 0 and hp <= math.floor(maxHp * 0.50) then
        return mon
      end
    end
    return nil
  end

  -- More depth for the existing Viridian trio.
  registerNpcChat("viridian_gambler", {
    id = "exhausted",
    weight = 12,
    eligible = function(ctx) return ctx.energy <= 30 end,
    prompt =
      "You look exhausted.\f" ..
      "Why not stop and\nrest for a while?",
    responses = {
      {
        id = "good_idea",
        label = "Good idea",
        mood = "RELAXED",
        reply = "The road isn't\ngoing anywhere.",
      },
      {
        id = "keep_moving",
        label = "I'm fine",
        mood = "FOCUSED",
        reply = "If you say so.\fJust don't overdo it.",
      },
    },
  })

  registerNpcChat("viridian_gambler", {
    id = "mood_confident",
    weight = 9,
    eligible = function(ctx) return ctx.mood == "CONFIDENT" end,
    prompt =
      "You've got a little\nswagger today.\f" ..
      "Win a good battle?",
    responses = {
      {
        id = "sure_did",
        label = "Sure did",
        mood = "CONFIDENT",
        reply = "Ha! I thought so.",
      },
      {
        id = "maybe",
        label = "Maybe",
        mood = "HAPPY",
        reply = "Trying to play it\ncool, huh?",
      },
    },
  })

  registerNpcChat("viridian_youngster", {
    id = "big_party",
    weight = 10,
    eligible = function(ctx) return partyCount(ctx.game) >= 3 end,
    prompt =
      "Whoa! You've got a\nwhole crew now!\f" ..
      "Is traveling with\nthat many hard?",
    responses = {
      {
        id = "worth_it",
        label = "It's worth it",
        mood = "HAPPY",
        reply = "I bet!\fIt must never get\nboring.",
      },
      {
        id = "sometimes",
        label = "Sometimes",
        reply = "Yeah... feeding all\nof them sounds tough.",
      },
    },
  })

  registerNpcChat("viridian_youngster", {
    id = "injured_partner",
    weight = 14,
    eligible = function(ctx) return injuredPartyPokemon(ctx.game) ~= nil end,
    prompt = function(ctx)
      local mon = injuredPartyPokemon(ctx.game)
      return pokemonName(mon) .. " looks pretty\nworn out.\f" ..
        "Are you heading to\nthe Pokémon Center?"
    end,
    responses = {
      {
        id = "yes_center",
        label = "Yeah",
        mood = "FOCUSED",
        reply = "Good.\fTake care of your\nfriends!",
      },
      {
        id = "later_center",
        label = "Not yet",
        mood = "UNEASY",
        reply = "I'd be careful.\fIt looks tired.",
      },
    },
  })

  registerNpcChat("viridian_girl", {
    id = "famished_warning",
    weight = 18,
    eligible = function(ctx) return ctx.hunger <= 0 end,
    prompt =
      "You look starving!\f" ..
      "Your Pokémon must\nbe hungry too.",
    responses = {
      {
        id = "buy_food",
        label = "I'll get food",
        mood = "FOCUSED",
        reply = "Please do.\fThe Mart is right\nthere!",
      },
      {
        id = "manage",
        label = "We'll manage",
        mood = "UNEASY",
        reply = "I hope so...",
      },
    },
  })

  registerNpcChat("viridian_girl", {
    id = "happy_trip",
    weight = 8,
    eligible = function(ctx) return ctx.mood == "HAPPY" end,
    prompt =
      "You seem really\nhappy today.\f" ..
      "Something good\nhappen?",
    responses = {
      {
        id = "great_day",
        label = "Great day",
        mood = "HAPPY",
        reply = "That's nice!\fI hope it stays\nthat way.",
      },
      {
        id = "just_because",
        label = "Just because",
        mood = "HAPPY",
        reply = "Even better!",
      },
    },
  })

  -- Generic ambient pools for early-game maps. These keys are registered
  -- only against explicit flavor text IDs below.
  registerNpcChat("pallet_ambient", {
    id = "journey",
    weight = 8,
    prompt =
      "So you're really\nheading out?\f" ..
      "How does it feel?",
    responses = {
      {
        id = "excited",
        label = "Exciting",
        mood = "HAPPY",
        reply = "I thought you'd say\nthat.\fGood luck out there!",
      },
      {
        id = "nervous",
        label = "Nervous",
        mood = "UNEASY",
        reply = "That's probably\nnormal.\fYou'll be okay.",
      },
    },
  })

  registerNpcChat("pallet_ambient", {
    id = "partner_check",
    weight = 8,
    eligible = function(ctx) return ctx.lead ~= nil end,
    prompt = function(ctx)
      return "How's " .. ctx.leadName .. "\ndoing so far?"
    end,
    responses = {
      {
        id = "great",
        label = "Great",
        mood = "HAPPY",
        reply = "You already sound\nlike a team.",
      },
      {
        id = "learning",
        label = "We're learning",
        mood = "CURIOUS",
        reply = "That's part of the\nfun, isn't it?",
      },
    },
  })

  registerNpcChat("route1_ambient", {
    id = "road_check",
    weight = 8,
    prompt =
      "Route 1 looks easy,\nbut don't get sloppy.\f" ..
      "How are you holding\nup?",
    responses = {
      {
        id = "doing_good",
        label = "Doing good",
        mood = "CONFIDENT",
        reply = "Good!\fKeep your eyes open.",
      },
      {
        id = "tired",
        label = "Getting tired",
        mood = "UNEASY",
        reply = "No shame in taking\na break.",
      },
    },
  })

  registerNpcChat("route1_ambient", {
    id = "wildlife",
    weight = 8,
    prompt =
      "You never know what\nwill jump out of the\ngrass around here.\f" ..
      "That's half the fun,\nright?",
    responses = {
      {
        id = "route1_fun",
        label = "Definitely",
        mood = "CURIOUS",
        reply = "That's the spirit!",
      },
      {
        id = "route1_careful",
        label = "Not to me",
        mood = "UNEASY",
        reply = "Fair enough.\fStay alert out there.",
      },
    },
  })

  registerNpcChat("route1_ambient", {
    id = "pace",
    weight = 8,
    prompt =
      "Everyone rushes to\nthe next town.\f" ..
      "I like taking my\ntime out here.",
    responses = {
      {
        id = "route1_agree",
        label = "Me too",
        mood = "RELAXED",
        reply = "See? You get it.",
      },
      {
        id = "route1_places",
        label = "Places to go",
        mood = "FOCUSED",
        reply = "Ha! Then I won't\nkeep you.",
      },
    },
  })

  registerNpcChat("route1_ambient", {
    id = "partner_road",
    weight = 8,
    eligible = function(ctx) return ctx.lead ~= nil end,
    prompt = function(ctx)
      return ctx.leadName .. " getting used\nto traveling yet?"
    end,
    responses = {
      {
        id = "route1_partner_yes",
        label = "I think so",
        mood = "HAPPY",
        reply = "Good.\fYou'll learn the road\ntogether.",
      },
      {
        id = "route1_partner_no",
        label = "Not quite",
        mood = "CURIOUS",
        reply = "Give it time.\fEverything's new at\nfirst.",
      },
    },
  })

  registerNpcChat("route1_ambient", {
    id = "low_food",
    weight = 14,
    eligible = function(ctx) return ctx.food <= 1 or ctx.hunger <= 35 end,
    prompt =
      "You packed food,\nright?\f" ..
      "People always think\nthe next town is close.",
    responses = {
      {
        id = "some_food",
        label = "I've got some",
        mood = "FOCUSED",
        reply = "Good.\fBetter safe than\nhungry.",
      },
      {
        id = "oops",
        label = "Uh...",
        mood = "UNEASY",
        reply = "Yeah. That's what I\nthought.",
      },
    },
  })

  registerNpcChat("route2_ambient", {
    id = "forest_ahead",
    weight = 8,
    prompt =
      "Viridian Forest is\njust ahead.\f" ..
      "Looking forward to\nit?",
    responses = {
      {
        id = "absolutely",
        label = "Absolutely",
        mood = "CURIOUS",
        reply = "Me too!\fThere's always\nsomething new inside.",
      },
      {
        id = "not_really",
        label = "Not really",
        mood = "UNEASY",
        reply = "Stay on the path and\nyou'll be fine.",
      },
    },
  })

  registerNpcChat("route2_ambient", {
    id = "party_comment",
    weight = 8,
    eligible = function(ctx) return partyCount(ctx.game) >= 2 end,
    prompt = function(ctx)
      return "Your Pokémon seem\nused to the road.\f" ..
        "Do they get along?"
    end,
    responses = {
      {
        id = "mostly",
        label = "Mostly",
        mood = "HAPPY",
        reply = "That's a good sign.",
      },
      {
        id = "depends",
        label = "It depends",
        reply = "Ha! Sounds like a\nfamily.",
      },
    },
  })


  -- ================================================================
  -- NPC Continuity v1
  -- Selected ambient NPCs now progress through simple relationship
  -- stages and can resolve remembered conversational threads.
  -- ================================================================

  registerNpcChat("route1_ambient", {
    id = "familiar_return",
    weight = 16,
    eligible = function(ctx)
      return ctx.stage == "familiar" or ctx.stage == "acquaintance"
    end,
    prompt =
      "Hey, you're back!\f" ..
      "How's the road been\ntreating you?",
    responses = {
      {
        id = "road_good",
        label = "Pretty good",
        mood = "HAPPY",
        effect = function(ctx)
          markNpcThread(ctx.key, "road_report", "good")
        end,
        reply = "Glad to hear it.\fYou're looking more\ncomfortable out there.",
      },
      {
        id = "road_bad",
        label = "It's been rough",
        mood = "UNEASY",
        effect = function(ctx)
          markNpcThread(ctx.key, "road_report", "rough")
        end,
        reply = "Yeah... it happens.\fJust keep moving.",
      },
    },
  })

  registerNpcChat("route1_ambient", {
    id = "road_report_followup_good",
    weight = 18,
    eligible = function(ctx)
      return npcThread(ctx.key, "road_report", "") == "good"
        and ctx.count >= 4
    end,
    prompt =
      "Still having a good\nrun of it?",
    responses = {
      {
        id = "still_good",
        label = "So far",
        mood = "CONFIDENT",
        reply = "Nice.\fMaybe you're getting\nthe hang of this.",
      },
      {
        id = "jinxed_it",
        label = "You jinxed it",
        mood = "ANGRY",
        reply = "Ha!\fOkay, okay. My bad.",
      },
    },
  })

  registerNpcChat("route1_ambient", {
    id = "road_report_followup_rough",
    weight = 18,
    eligible = function(ctx)
      return npcThread(ctx.key, "road_report", "") == "rough"
        and ctx.count >= 4
    end,
    prompt =
      "Things going any\nbetter now?",
    responses = {
      {
        id = "better_now",
        label = "Much better",
        mood = "HAPPY",
        effect = function(ctx)
          markNpcThread(ctx.key, "road_report", "recovered")
        end,
        reply = "Good.\fI was hoping you'd\nsay that.",
      },
      {
        id = "still_rough",
        label = "Not really",
        mood = "SAD",
        reply = "Hang in there.\fBad stretches don't\nlast forever.",
      },
    },
  })

  registerNpcChat("route1_ambient", {
    id = "lead_changed",
    weight = 14,
    eligible = function(ctx)
      return ctx.stage ~= "stranger"
        and ctx.leadName ~= "YOUR POKEMON"
        and ctx.lastLeadName ~= ""
        and ctx.lastLeadName ~= ctx.leadName
    end,
    prompt = function(ctx)
      return "Oh! You're traveling\nwith " .. ctx.leadName .. " now?\f" ..
        "What happened to\n" .. ctx.lastLeadName .. "?"
    end,
    responses = {
      {
        id = "still_here",
        label = "Still with me",
        mood = "HAPPY",
        reply = "Ah, got it.\fJust changing who\nleads the way.",
      },
      {
        id = "long_story",
        label = "Long story",
        mood = "SAD",
        reply = "...I see.\fI won't pry.",
      },
    },
  })

  registerNpcChat("viridian_girl", {
    id = "familiar_greeting",
    weight = 14,
    eligible = function(ctx)
      return ctx.stage == "familiar" or ctx.stage == "acquaintance"
    end,
    prompt =
      "Hey! I recognize you.\f" ..
      "You made it back in\none piece.",
    responses = {
      {
        id = "barely",
        label = "Barely",
        mood = "HAPPY",
        reply = "Ha!\fThat still counts.",
      },
      {
        id = "easy",
        label = "Of course",
        mood = "CONFIDENT",
        reply = "Wow.\fSomeone's feeling\nconfident.",
      },
    },
  })

  registerNpcChat("viridian_girl", {
    id = "food_thread_resolved",
    weight = 20,
    eligible = function(ctx)
      return (ctx.lastResponse == "not_really" or npcThread(ctx.key, "food_worry", false))
        and ctx.food >= 2
        and ctx.hunger > 50
    end,
    prompt =
      "Hey, you stocked up!\f" ..
      "Feeling better about\nthe trip now?",
    responses = {
      {
        id = "prepared_now",
        label = "Much better",
        mood = "FOCUSED",
        effect = function(ctx)
          markNpcThread(ctx.key, "food_worry", false)
        end,
        reply = "Good.\fSee? Preparation\nhelps.",
      },
      {
        id = "always_ready",
        label = "I was fine",
        mood = "CONFIDENT",
        effect = function(ctx)
          markNpcThread(ctx.key, "food_worry", false)
        end,
        reply = "Sure you were.",
      },
    },
  })

  registerNpcChat("viridian_girl", {
    id = "saw_lead_before",
    weight = 12,
    eligible = function(ctx)
      return ctx.stage ~= "stranger"
        and ctx.leadName ~= "YOUR POKEMON"
        and npcSeenLead(ctx.key, ctx.leadName)
    end,
    prompt = function(ctx)
      return ctx.leadName .. " still looks\nhappy traveling with\nyou."
    end,
    responses = {
      {
        id = "glad",
        label = "I'm glad",
        mood = "HAPPY",
        reply = "You two seem close.",
      },
      {
        id = "troublemaker",
        label = "Usually",
        mood = "HAPPY",
        reply = "Ha!\fI knew there was a\nstory there.",
      },
    },
  })

  registerNpcChat("viridian_youngster", {
    id = "familiar_party_growth",
    weight = 15,
    eligible = function(ctx)
      return ctx.stage ~= "stranger" and partyCount(ctx.game) >= 2
    end,
    prompt =
      "Your team's getting\nbigger every time I\nsee you!\f" ..
      "Keeping up with them?",
    responses = {
      {
        id = "loving_it",
        label = "Loving it",
        mood = "HAPPY",
        reply = "I would too!",
      },
      {
        id = "lot_work",
        label = "It's a lot",
        mood = "FOCUSED",
        reply = "I bet.\fStill looks worth it.",
      },
    },
  })

  registerNpcChat("viridian_youngster", {
    id = "injury_followup",
    weight = 18,
    eligible = function(ctx)
      return ctx.stage ~= "stranger"
        and ctx.lastResponse == "yes_center"
        and injuredPartyPokemon(ctx.game) == nil
    end,
    prompt =
      "Your Pokémon look\nbetter now!\f" ..
      "Did the Center help?",
    responses = {
      {
        id = "center_helped",
        label = "Yep",
        mood = "HAPPY",
        reply = "Good!\fI was worried.",
      },
      {
        id = "handled_it",
        label = "We handled it",
        mood = "CONFIDENT",
        reply = "Nice!\fYou really do know\nwhat you're doing.",
      },
    },
  })

  -- Explicit whitelist: these three are flavor-only Viridian NPCs.
  -- The Fisher gift NPC, old-man tutorial, Mart clerk, trainers, and every
  -- other functional character remain vanilla.
  mod.content.map_scripts:register("VIRIDIAN_CITY", {
    priority = 100,
    talk = {
      ["TEXT_VIRIDIANCITY_GAMBLER1"] = function(game, ow, npc, done)
        if not pokesimEnabled() then
          runBaseNpcTalk("VIRIDIAN_CITY", "TEXT_VIRIDIANCITY_GAMBLER1", {
            game = game, overworld = ow, npc = npc
          }, done)
          return
        end
        runNpcChat("viridian_gambler", game, ow, npc, done)
      end,
      ["TEXT_VIRIDIANCITY_YOUNGSTER2"] = function(game, ow, npc, done)
        if not pokesimEnabled() then
          runBaseNpcTalk("VIRIDIAN_CITY", "TEXT_VIRIDIANCITY_YOUNGSTER2", {
            game = game, overworld = ow, npc = npc
          }, done)
          return
        end
        runNpcChat("viridian_youngster", game, ow, npc, done)
      end,
      ["TEXT_VIRIDIANCITY_GIRL"] = function(game, ow, npc, done)
        if not pokesimEnabled() then
          runBaseNpcTalk("VIRIDIAN_CITY", "TEXT_VIRIDIANCITY_GIRL", {
            game = game, overworld = ow, npc = npc
          }, done)
          return
        end
        runNpcChat("viridian_girl", game, ow, npc, done)
      end,
    },
  })


  -- Early-game ambient whitelist expansion. These IDs are intentionally
  -- limited to ordinary flavor NPCs; progression/event NPCs are omitted.
  --
  -- If a text ID is absent in a particular recomp revision, registration
  -- remains isolated from functional scripts.
  mod.content.map_scripts:register("PALLET_TOWN", {
    priority = 100,
    talk = {
      ["TEXT_PALLETTOWN_GIRL"] = function(game, ow, npc, done)
        if not pokesimEnabled() then
          runBaseNpcTalk("PALLET_TOWN", "TEXT_PALLETTOWN_GIRL", {
            game = game, overworld = ow, npc = npc
          }, done)
          return
        end
        runNpcChat("pallet_ambient", game, ow, npc, done)
      end,
      ["TEXT_PALLETTOWN_FISHER"] = function(game, ow, npc, done)
        if not pokesimEnabled() then
          runBaseNpcTalk("PALLET_TOWN", "TEXT_PALLETTOWN_FISHER", {
            game = game, overworld = ow, npc = npc
          }, done)
          return
        end
        runNpcChat("pallet_ambient", game, ow, npc, done)
      end,
    },
  })

  mod.content.map_scripts:register("ROUTE_1", {
    priority = 100,
    talk = {
      ["TEXT_ROUTE1_YOUNGSTER1"] = function(game, ow, npc, done)
        if not pokesimEnabled() then
          runBaseNpcTalk("ROUTE_1", "TEXT_ROUTE1_YOUNGSTER1", {
            game = game, overworld = ow, npc = npc
          }, done)
          return
        end
        runNpcChat("route1_ambient", game, ow, npc, done)
      end,
    },
  })

  mod.content.map_scripts:register("ROUTE_2", {
    priority = 100,
    talk = {
      ["TEXT_ROUTE2_YOUNGSTER1"] = function(game, ow, npc, done)
        if not pokesimEnabled() then
          runBaseNpcTalk("ROUTE_2", "TEXT_ROUTE2_YOUNGSTER1", {
            game = game, overworld = ow, npc = npc
          }, done)
          return
        end
        runNpcChat("route2_ambient", game, ow, npc, done)
      end,
      ["TEXT_ROUTE2_GIRL"] = function(game, ow, npc, done)
        if not pokesimEnabled() then
          runBaseNpcTalk("ROUTE_2", "TEXT_ROUTE2_GIRL", {
            game = game, overworld = ow, npc = npc
          }, done)
          return
        end
        runNpcChat("route2_ambient", game, ow, npc, done)
      end,
    },
  })


  -- Gen1Recomp's scripted FadeOverlay is drawn in classic 160x144 UI space.
  -- With the expanded world view, that leaves the surrounding margins
  -- visible and reads as a giant white/black rectangle. Mirror the same
  -- fade into ONLY the margins so the viewport itself is not double-faded.
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    local result = next(game, viewport)
    local ow = game and game.overworld
    local fade = ow and ow.fadeOverlay
    local alpha = fade and tonumber(fade.alpha or 0) or 0
    if not fade or alpha <= 0 or not viewport then return result end

    local shade = fade.color == "white" and 1 or 0
    love.graphics.setColor(shade, shade, shade, alpha)

    local ww, wh = viewport.width or 0, viewport.height or 0
    local x, y = viewport.gameX or 0, viewport.gameY or 0
    local w, h = viewport.gameWidth or ww, viewport.gameHeight or wh

    if x > 0 then love.graphics.rectangle("fill", 0, 0, x, wh) end
    if x + w < ww then
      love.graphics.rectangle("fill", x + w, 0, ww - (x + w), wh)
    end
    if y > 0 then love.graphics.rectangle("fill", x, 0, w, y) end
    if y + h < wh then
      love.graphics.rectangle("fill", x, y + h, w, wh - (y + h))
    end

    love.graphics.setColor(1, 1, 1, 1)
    return result
  end)

  local MOOD_ICON_DATA = {
    ANGRY = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLDLLLLLLDLLDDLLLDDLLDDLLLDDLLLLDLLDLLLLDDLLLLDLLDLLLLDDLLLLLLLLLLLLDDLLLLLLLLLLLLDDLLLDDDDDDLLLDDLLDLDLDLDDLLD.DLDLDLDLDDLD...DDDDDDDDDD.........DD............D......",
    CONFIDENT = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLLLLLLLLLLDDLLLDLLLDLLLLDDLLLLDLLDLLLLDDLLLDLLLDLLLLDDLLLLLLLLLLLLDDLLLLLLLLLLLLDDLLLLLLLLDLLLDDLLLLDDDDLLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    CURIOUS = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLLDDDDLLLLDDLLLDDLLDDLLLDDLLLLLLLDDLLLDDLLLLLDDDDLLLDDLLLLLDDLLLLLDDLLLLLLLLLLLLDDLLLLLDDLLLLLDDLLLLLDDLLLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    DEPLETED = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLDDDDDDLLLDDLLDLLLLLLDLLDDLLDLLLLLLDLLDDLLDDDLLDDDLLDDLLDLLDDLLDLLDDLLLDLLLLDLLLDDLLLDLLLLDLLLDDLLLLDDDDLLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    ECSTATIC = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLLLLLLLLLLDDLLDDLLLLDDLLDDLDLLDLLDLLDLDDLDLLDLLDLLDLDDLLLLLLLLLLLLDDLLLDLLLLDLLLDDLLLLDDDDLLLLDDLLLLLDDLLLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    EXHAUSTED = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLLLLDDDDLLDDLLLLLLLLLDLLDDLLLLLLLLDLLLDDLLDDDLLDLLLLDDLLLLDLDLLLLLDDLLLDLLDDDDLLDDLLDLLLLLLLLLDDLLDDDLLLLLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    FAMISHED = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLLDDDDLLLLDDLLLDLLLLDLLLDDLLDLLLLLLDLLDDLDDDDDDDDDDLDDLLDLLLLLLDLLDDLDDDDDDDDDDLDDLLDLLLLLLDLLDDLLLDDDDDDLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    FINE = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLLLLLLLLLLDDLLLLDLLDLLLLDDLLLLDLLDLLLLDDLLLLDLLDLLLLDDLLLLLLLLLLLLDDLLLLLLLLLLLLDDLLLDLLLLDLLLDDLLLLDDDDLLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    FOCUSED = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLLDDDLLLLLDDLLLDLLLDLLLLDDLLDLDLLLDLLLDDLLDLLLLLDLLLDDLLDLLLLLDLLLDDLLLDLLLDLLLLDDLLLLDDDLDLLLDDLLLLLLLLLDLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    HAPPY = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLLLLLLLLLLDDLLDDLLLLDDLLDDLDLLDLLDLLDLDDLDLLDLLDLLDLDDLLLLLLLLLLLLDDLLLLLLLLLLLLDDLLLDLLLLDLLLDDLLLLDDDDLLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    MISERABLE = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLDLLLLLLDLLDDLDLLLLLLLLDLDDLLDDDLLDDDLLDDLLLDLLLLDLLLDDLLLDLLLLDLLLDDLLLLLLLLLLLLDDLLLDLDDLDLLLDDLLLLLDDLLLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    RELAXED = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLLLLLLLLLLDDLLLLLLLLLLLLDDLLLLLLLLLLLLDDLLDDDLLDDDLLDDLLLLLLLLLLLLDDLLLLLLLLLLLLDDLLLDLLLLDLLLDDLLLLDDDDLLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    SAD = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLLLLLLLLLLDDLLLLDLLDLLLLDDLLLLDLLDLLLLDDLLLLDLLDLLLLDDLLLLLLLLLLLLDDLLLLLLLLLLLLDDLLLLDDDDLLLLDDLLLDLLLLDLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    THRIFTY = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLLLDDLLLLLDDLLLLDLLDLLLLDDLLLLDLLDLLLLDDLLLDDDDDDLLLDDLLDDLDDDDDLLDDLLDLDDDDDDLLDDLLDDDDDDDDLLDDLLLDDDDDDLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
    UNEASY = "..DDDDDDDDDD...DLLLLLLLLLLD.DLLLDLLLLDLLLDDLLDLLLLLLDLLDDLLLLDLLDLLLLDDLLLLDLLDLLLLDDLLLLDLLDLLLLDDLLLLLLLLLLLLDDLLLLLDDLLLLLDDLLLDDLLDDLLLD.DLLLLLLLLLLD...DDDDDDDDDD.........DD............D......",
  }

  local function drawMoodReactionBubble(game, viewport)
    if not moodBubbleName or not viewport then return end

    local now = (love.timer and love.timer.getTime and love.timer.getTime()) or 0
    if now >= moodBubbleUntil then
      moodBubbleName = nil
      return
    end

    if not game or not game.overworld or not game.stack
      or game.stack:top() ~= game.overworld then
      return
    end

    local gx = viewport.gameX or 0
    local gy = viewport.gameY or 0
    local gw = viewport.gameWidth or 160
    local gh = viewport.gameHeight or 144
    local scale = math.max(1, math.floor(math.min(gw / 160, gh / 144)))

    -- PokeSim's expanded viewport leaves the player slightly left of the
    -- geometric screen center during normal travel. Match the visible trainer
    -- position rather than the raw viewport midpoint, and bring the bubble
    -- down close enough to read as hovering over their head.
    local cx = gx + math.floor(gw * 0.5) - (8 * scale)
    local cy = gy + math.floor(gh * 0.5) - (10 * scale)

    local x = cx - 7 * scale
    local y = cy - 14 * scale

    local m = tostring(moodBubbleName or "FINE")
    local pixels = MOOD_ICON_DATA[m] or MOOD_ICON_DATA.FINE

    love.graphics.push("all")

    for py = 0, 13 do
      local rowStart = py * 14
      for px = 0, 13 do
        local ch = pixels:sub(rowStart + px + 1, rowStart + px + 1)
        if ch == "L" then
          love.graphics.setColor(248/255, 248/255, 248/255, 1)
          love.graphics.rectangle("fill", x + px*scale, y + py*scale, scale, scale)
        elseif ch == "D" then
          love.graphics.setColor(24/255, 24/255, 24/255, 1)
          love.graphics.rectangle("fill", x + px*scale, y + py*scale, scale, scale)
        end
      end
    end

    love.graphics.pop()
  end

  -- Draw after the normal HUD so the reaction is always readable, while
  -- remaining completely non-blocking.
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    local result = next(game, viewport)
    drawMoodReactionBubble(game, viewport)
    return result
  end)

  mod.exports.getRandomizedPalette = function(species)
    local generated = deterministicTypesForSpecies(species)
    return generated and TYPE_ADVANCED_PALETTES[generated[1]] or nil
  end
  mod.exports.getRandomizedStats = function(species)
    return deterministicStatsForSpecies(
      species,
      originalSpeciesStats[species],
      originalSpeciesStats
    )
  end
  mod.exports.getRandomizedLearnset = function(species)
    local data = rememberOriginalSpeciesTypes()
    if not data then return nil end
    local types = deterministicTypesForSpecies(species)
    return deterministicLearnsetForSpecies(
      data,
      species,
      originalSpeciesLevel1Moves[species],
      originalSpeciesLearnsets[species],
      types
    )
  end

  mod.exports.getRandomizedCatchRate = function(species)
    rememberOriginalSpeciesTypes()
    if not randomizedCatchRateCache then
      randomizedCatchRateCache =
        buildRandomizedCatchRateMap(originalSpeciesCatchRates)
    end
    local entry = randomizedCatchRateCache[species]
    return entry and entry.rate or originalSpeciesCatchRates[species]
  end

  mod.exports.getRandomizedTypes = deterministicTypesForSpecies
  mod.exports.syncRandomizedTypeDefinitions = syncRandomizedTypeDefinitions
  mod.exports.isRunConfigured = runConfigured
  mod.exports.isPokeSimEnabled = pokesimEnabled
  mod.exports.isRandomPokemonEnabled = randomPokemonEnabled
  mod.exports.isPermadeathEnabled = permadeathEnabled
  mod.exports.getRunSeed = runSeed
  mod.exports.getRunSeedText = runSeedText
  mod.exports.getRandomStarters = ensureRandomStarters
  mod.exports.getRandomWildSpecies = randomizedWildSpecies
  mod.exports.canCampByTravel = campRestReady
  mod.exports.getCampTravel = campTravel
  mod.exports.getCampFoodState = campFoodState
  mod.exports.registerScenario = registerScenario
  mod.exports.runScenario = runScenario
  mod.exports.getScenarioCount = scenarioCount
  mod.exports.getMood = mood
  mod.exports.getMoodEffects = moodEffects
  mod.exports.getBaseMood = baseMood
  mod.exports.setTemporaryMood = setTemporaryMood
  mod.exports.foodCount = foodCount
  mod.exports.giveFood = giveFood
  mod.exports.campCount = function()
    return mod.save:get("camp_count", 0)
  end
end
