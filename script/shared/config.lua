return {
  -- Enable debug mode (draws ox_target debug, prints to console)
  Debug = false,

  -- Percentage chance a spawned vehicle gets loot (1-100)
  SpawnChance = 20,

  -- Seconds a player must wait between smashes
  Cooldown = 120,

  -- Percentage chance the car alarm triggers on failed skillcheck (1-100)
  AlarmChance = 75,

  -- Percentage chance police are dispatched (1-100)
  -- Rolls on failed skillcheck (only if alarm triggered) and on successful smash
  DispatchChance = 50,

  -- Maximum number of vehicles with active loot at once
  MaxLootedVehicles = 50,

  -- Max distance to interact with a window target
  TargetDistance = 0.6,

  SkillCheck = {
    difficulty = { "easy", "easy", "medium" },
    inputs = { "w", "a", "s", "d" },
  },

  SmashAnimation = {
    duration = 800,
    label = "Breaking window...",
    anim = {
      dict = "veh@break_in@0h@p_m_zero@",
      clip = "std_force_entry_ds",
    },
  },

  LootAnimation = {
    duration = 4000,
    label = "Grabbing items...",
    anim = {
      dict = "mini@repair",
      clip = "fixing_a_player",
    },
  },

  VehicleFilter = {
    -- "blacklist" = all classes allowed except modelBlacklist
    -- "whitelist" = only modelWhitelist models allowed
    mode = "blacklist",

    -- Vehicle classes allowed for loot (ignored in whitelist mode)
    -- 0=Compacts, 1=Sedans, 2=SUVs, 3=Coupes, 4=Muscle,
    -- 5=Sports Classics, 6=Sports, 7=Super, 9=Off-road, 12=Vans
    allowedClasses = { 0, 1, 2, 3, 4, 5, 6, 7, 9, 12 },

    -- Models that never get loot (blacklist mode)
    modelBlacklist = {
      `police`, `police2`, `police3`, `police4`,
      `policeb`, `policet`, `sheriff`, `sheriff2`,
      `ambulance`, `firetruk`, `fbi`, `fbi2`,
      `riot`, `pranger`,
    },

    -- Models that exclusively get loot (whitelist mode)
    modelWhitelist = {},
  },

  LootTables = {
    {
      item = "phone",
      minCount = 1,
      maxCount = 1,
      weight = 30,
    },
    {
      item = "money",
      minCount = 50,
      maxCount = 200,
      weight = 50,
    },
  },

  Props = {
    models = {
      `prop_cs_heist_bag_01`,
      `hei_prop_heist_box`,
      `prop_ld_case_01`,
    },
    maxPerVehicle = 1,
    -- Per-model attachment offsets { x, y, z, rx, ry, rz }
    offsets = {
      [`prop_cs_heist_bag_01`] = { 0.0, 0.0, 0.25, 0.0, 0.0, 0.0 },
      [`hei_prop_heist_box`] = { 0.0, 0.0, 0.2, 0.0, 0.0, 0.0 },
      [`prop_ld_case_01`] = { 0.0, 0.05, 0.2, 0.0, 0.0, 90.0 },
    },
  },

  -- Seat bone names for prop placement
  SeatBones = {
    "seat_pside_f",
    "seat_dside_r",
    "seat_pside_r",
  },

  -- Window indices corresponding to seat bones (for SmashVehicleWindow)
  WindowIndices = {
    seat_dside_f = 0,
    seat_pside_f = 1,
    seat_dside_r = 2,
    seat_pside_r = 3,
  },
}
