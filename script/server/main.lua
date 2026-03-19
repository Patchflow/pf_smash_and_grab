local Config = lib.require("script.shared.config")
local LootManager = lib.require("script.server.modules.lootManager")
local Dispatch = lib.require("script.server.custom.dispatch")

local playerCooldowns = {}
local knownVehicles = {}
local dispatchCooldowns = {}

local blacklistSet, whitelistSet, classSet = {}, {}, {}
for _, hash in ipairs(Config.VehicleFilter.modelBlacklist) do
  blacklistSet[hash] = true
end
for _, hash in ipairs(Config.VehicleFilter.modelWhitelist) do
  whitelistSet[hash] = true
end
for _, class in ipairs(Config.VehicleFilter.allowedClasses) do
  classSet[class] = true
end

local filterMode = Config.VehicleFilter.mode

local function isVehicleEligible(entity, vehClass)
  local modelHash = GetEntityModel(entity)
  if filterMode == "whitelist" then
    return whitelistSet[modelHash] == true
  end
  if blacklistSet[modelHash] then return false end
  if vehClass and not classSet[vehClass] then return false end
  return true
end

local evaluateBuckets = {}
local EVALUATE_LIMIT = 10
local EVALUATE_WINDOW = 5

RegisterNetEvent("pf_smash_and_grab:server:evaluateVehicle", function(netId, vehClass)
  local src = source
  if type(netId) ~= "number" or type(vehClass) ~= "number" then return end
  if knownVehicles[netId] then return end
  if LootManager.IsFull() then return end

  local now = os.time()
  local bucket = evaluateBuckets[src]
  if not bucket or (now - bucket.start) >= EVALUATE_WINDOW then
    evaluateBuckets[src] = { start = now, count = 1 }
  elseif bucket.count >= EVALUATE_LIMIT then
    return
  else
    bucket.count = bucket.count + 1
  end

  local entity = NetworkGetEntityFromNetworkId(netId)
  if not DoesEntityExist(entity) then return end

  local playerPed = GetPlayerPed(src)
  if playerPed == 0 then return end

  local playerCoords = GetEntityCoords(playerPed)
  local vehicleCoords = GetEntityCoords(entity)
  if #(playerCoords - vehicleCoords) > 75.0 then return end

  if not isVehicleEligible(entity, vehClass) then return end

  if math.random(1, 100) > Config.SpawnChance then
    knownVehicles[netId] = true
    return
  end

  if GetEntityPopulationType(entity) ~= 2 then
    knownVehicles[netId] = true
    return
  end

  local available = {}
  for i = 1, #Config.SeatBones do
    available[i] = i
  end

  for i = #available, 2, -1 do
    local j = math.random(1, i)
    available[i], available[j] = available[j], available[i]
  end

  local numProps = math.random(1, math.min(Config.Props.maxPerVehicle, #available))
  local propSeats = {}
  for i = 1, numProps do
    propSeats[i] = available[i]
  end

  if LootManager.AssignLoot(netId, propSeats) then
    knownVehicles[netId] = true
    Entity(entity).state.sagLoot = { propSeats = propSeats }
  end
end)

RegisterNetEvent("pf_smash_and_grab:server:recoverVehicle", function(netId)
  local src = source
  if type(netId) ~= "number" then return end
  if LootManager.HasLoot(netId) then
    knownVehicles[netId] = true
    return
  end

  local entity = NetworkGetEntityFromNetworkId(netId)
  if not DoesEntityExist(entity) then return end

  local playerPed = GetPlayerPed(src)
  if playerPed == 0 then return end

  local playerCoords = GetEntityCoords(playerPed)
  local vehicleCoords = GetEntityCoords(entity)
  if #(playerCoords - vehicleCoords) > 75.0 then return end

  local state = Entity(entity).state.sagLoot
  if not state or not state.propSeats then return end

  if LootManager.AssignLoot(netId, state.propSeats) then
    knownVehicles[netId] = true
  else
    Entity(entity).state.sagLoot = nil
  end
end)

local cleanupTimers = {}

CreateThread(function()
  while true do
    Wait(10000)
    local now = os.time()
    for netId in pairs(knownVehicles) do
      local entity = NetworkGetEntityFromNetworkId(netId)
      if entity == 0 or not DoesEntityExist(entity) then
        if not cleanupTimers[netId] then
          cleanupTimers[netId] = now
        elseif now - cleanupTimers[netId] >= 60 then
          LootManager.Remove(netId)
          knownVehicles[netId] = nil
          cleanupTimers[netId] = nil
        end
      else
        cleanupTimers[netId] = nil
      end
    end
  end
end)

local function tryDispatch(source, netId)
  local now = os.time()
  if dispatchCooldowns[source] and (now - dispatchCooldowns[source]) < 30 then return end

  if math.random(1, 100) > Config.DispatchChance then return end

  dispatchCooldowns[source] = now

  local playerPed = GetPlayerPed(source)
  local playerCoords = GetEntityCoords(playerPed)

  Dispatch.Alert({
    source = source,
    coords = playerCoords,
    netId = netId,
  })
end

lib.callback.register("pf_smash_and_grab:server:smashFailed", function(source, netId)
  if type(netId) ~= "number" then return end
  local entity = NetworkGetEntityFromNetworkId(netId)
  if not DoesEntityExist(entity) then return end

  local playerPed = GetPlayerPed(source)
  local playerCoords = GetEntityCoords(playerPed)
  local vehicleCoords = GetEntityCoords(entity)
  if #(playerCoords - vehicleCoords) > 5.0 then return end

  if math.random(1, 100) <= Config.AlarmChance then
    tryDispatch(source, netId)
    return true
  end

  return false
end)

local function getCooldownRemaining(source)
  local lastSmash = playerCooldowns[source]
  if not lastSmash then return 0 end
  local remaining = Config.Cooldown - (os.time() - lastSmash)
  return remaining > 0 and math.ceil(remaining) or 0
end

lib.callback.register("pf_smash_and_grab:server:checkCooldown", function(source)
  local remaining = getCooldownRemaining(source)
  if remaining > 0 then
    return { onCooldown = true, remaining = remaining }
  end
  return { onCooldown = false }
end)

lib.callback.register("pf_smash_and_grab:server:claimLoot", function(source, netId)
  if type(netId) ~= "number" then return end
  local remaining = getCooldownRemaining(source)
  if remaining > 0 then
    return { success = false, reason = "cooldown", remaining = remaining }
  end

  if not LootManager.HasLoot(netId) then
    return { success = false, reason = "no_loot" }
  end

  local data = LootManager.GetLoot(netId)
  if not data then
    return { success = false, reason = "no_loot" }
  end

  local entity = NetworkGetEntityFromNetworkId(netId)
  if not DoesEntityExist(entity) then
    return { success = false, reason = "no_loot" }
  end

  local playerPed = GetPlayerPed(source)
  local playerCoords = GetEntityCoords(playerPed)
  local vehicleCoords = GetEntityCoords(entity)
  if #(playerCoords - vehicleCoords) > 5.0 then
    return { success = false, reason = "too_far" }
  end

  LootManager.MarkLooted(netId)

  local added = exports.ox_inventory:AddItem(source, data.loot.item, data.loot.count)
  if not added then
    LootManager.RestoreLoot(netId)
    return { success = false, reason = "inventory_full" }
  end

  playerCooldowns[source] = os.time()

  Entity(entity).state.sagLoot = false

  tryDispatch(source, netId)

  return { success = true, item = data.loot.item, count = data.loot.count }
end)

if Config.Debug then
  lib.callback.register("pf_smash_and_grab:server:debugSpawn", function(netId)
    if netId == 0 then return false end

    local propSeats = {}
    for i = 1, math.min(Config.Props.maxPerVehicle, #Config.SeatBones) do
      propSeats[i] = i
    end

    if not LootManager.AssignLoot(netId, propSeats) then return false end

    knownVehicles[netId] = true

    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
      Entity(entity).state.sagLoot = { propSeats = propSeats }
    end

    return true
  end)
end

AddEventHandler("playerDropped", function()
  playerCooldowns[source] = nil
  dispatchCooldowns[source] = nil
  evaluateBuckets[source] = nil
end)
