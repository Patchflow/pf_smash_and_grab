# pf_smash_and_grab

A smash and grab system for FiveM servers built by [Patchflow](https://patchflow.md/). Players break into parked NPC vehicles and steal loot through skill checks and timed interactions.

## Features

- **Skill Check Smashing** — Players must pass configurable skill checks to break vehicle windows
- **Weighted Loot Tables** — Configurable items with weight-based random rolls, min/max counts
- **Visual Loot Props** — Bags and boxes attached to vehicle seat bones indicate lootable vehicles
- **Car Alarm & Dispatch** — Failed skill checks can trigger car alarms and police dispatch alerts
- **Vehicle Filtering** — Blacklist or whitelist vehicles by model hash or vehicle class
- **Spawn Chance** — Configurable percentage chance for NPC vehicles to contain loot
- **Cooldown System** — Per-player cooldown between smash attempts
- **Max Active Vehicles** — Cap on simultaneous lootable vehicles to control density
- **Custom Dispatch** — Stub file for easy integration with any dispatch system (lb-tablet example included)
- **State Bag Sync** — Loot state synced across clients via FiveM state bags

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [ox_inventory](https://github.com/overextended/ox_inventory)

## Installation

1. Download the latest release
2. Place `pf_smash_and_grab` in your resources folder
3. Add `ensure pf_smash_and_grab` to your server.cfg (after dependencies)
4. Configure `script/shared/config.lua`
5. Restart your server

## Configuration

```lua
-- script/shared/config.lua
{
  Debug = false,                   -- Enable debug mode (ox_target debug zones, console prints)
  SpawnChance = 20,                -- Percentage chance a spawned vehicle gets loot (1-100)
  Cooldown = 120,                  -- Seconds a player must wait between smashes
  AlarmChance = 75,                -- Percentage chance car alarm triggers on failed skillcheck (1-100)
  DispatchChance = 50,             -- Percentage chance police are dispatched (1-100)
  MaxLootedVehicles = 50,          -- Maximum vehicles with active loot at once
  TargetDistance = 0.6,            -- Max distance to interact with a window target

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
    mode = "blacklist",            -- "blacklist" or "whitelist"
    allowedClasses = { 0, 1, 2, 3, 4, 5, 6, 7, 9, 12 },
    modelBlacklist = { ... },      -- Emergency vehicles excluded by default
    modelWhitelist = {},
  },

  LootTables = {
    { item = "phone", minCount = 1, maxCount = 1, weight = 30 },
    { item = "money", minCount = 50, maxCount = 200, weight = 50 },
  },

  Props = {
    models = { ... },              -- Prop models to attach to seats
    maxPerVehicle = 1,             -- Max props per vehicle
    offsets = { ... },             -- Per-model attachment offsets
  },
}
```

## Usage

1. Players approach a parked NPC vehicle with loot (indicated by visible props on seats)
2. Interact with the ox_target zone on the vehicle window
3. Pass the skill check to smash the window
4. Loot the vehicle through a timed progress bar
5. Items are added directly to the player's inventory via ox_inventory

## Dispatch Integration

Customize `script/server/custom/dispatch.lua` to integrate with your dispatch system. An example using lb-tablet is included as a comment.

```lua
-- script/server/custom/dispatch.lua
function Dispatch.Alert(data)
  -- data.source: player server id
  -- data.coords: player coordinates
  -- data.netId: vehicle network id
end
```

## Links

- [Patchflow](https://patchflow.md/)
- [Support & Issues](https://patchflow.md/)
- [Docs](https://docs.patchflow.md/PFSmashAndGrab)

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
