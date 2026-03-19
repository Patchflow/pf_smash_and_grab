local Config = lib.require("script.shared.config")
local PropManager = lib.require("script.client.modules.propManager")
local Interaction = lib.require("script.client.modules.interaction")

---@type table<number, number> netId -> entity handle
local activeVehicles = {}

---@type table<number, number> netId -> entity handle
local discoveredVehicles = {}

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

local function isVehicleEligible(vehicle)
  if GetEntityPopulationType(vehicle) ~= 2 then return false end
  local modelHash = GetEntityModel(vehicle)
  if filterMode == "whitelist" then
    return whitelistSet[modelHash] == true
  end
  if blacklistSet[modelHash] then return false end
  if not classSet[GetVehicleClass(vehicle)] then return false end
  return true
end

---@param vehicle number
---@param propSeats number[]
---@return number[]
local function filterValidSeats(vehicle, propSeats)
  local valid = {}
  for _, seatIndex in ipairs(propSeats) do
    local boneName = Config.SeatBones[seatIndex]
    if boneName and GetEntityBoneIndexByName(vehicle, boneName) ~= -1 then
      valid[#valid + 1] = seatIndex
    end
  end

  if #valid > 0 then return valid end

  for i, boneName in ipairs(Config.SeatBones) do
    if GetEntityBoneIndexByName(vehicle, boneName) ~= -1 then
      return { i }
    end
  end

  return valid
end

---@param netId number
---@param vehicle number
---@param propSeats number[]
local function setupVehicle(netId, vehicle, propSeats)
  if not DoesEntityExist(vehicle) then return false end

  local validSeats = filterValidSeats(vehicle, propSeats)
  if #validSeats == 0 then return false end

  SetEntityAsMissionEntity(vehicle, true, true)
  PropManager.SpawnProps(netId, validSeats)
  local props = PropManager.GetProps(netId)
  if not props then return false end
  Interaction.AddTarget(netId, vehicle, props)
  return true
end

---@param netId number
local function cleanupVehicle(netId)
  Interaction.RemoveTarget(netId)
  PropManager.DeleteProps(netId)
  activeVehicles[netId] = nil
end

---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler("sagLoot", nil, function(bagName, _, value)
  local entity = GetEntityFromStateBagName(bagName)

  if entity == 0 then return end

  local timeout = 40
  while not HasCollisionLoadedAroundEntity(entity) do
    if not DoesEntityExist(entity) then return end
    timeout = timeout - 1
    if timeout <= 0 then return end
    Wait(250)
  end

  if not DoesEntityExist(entity) then return end
  if GetEntityType(entity) ~= 2 then return end

  local netId = NetworkGetNetworkIdFromEntity(entity)
  if netId == 0 then return end

  if not value then
    if activeVehicles[netId] then
      cleanupVehicle(netId)
    end
    return
  end

  if activeVehicles[netId] then return end

  if setupVehicle(netId, entity, value.propSeats) then
    activeVehicles[netId] = entity
  end
end)

CreateThread(function()
  while true do
    Wait(2000)

    local playerCoords = GetEntityCoords(cache.ped)
    local vehicles = GetGamePool("CVehicle")

    local candidates = {}
    for _, vehicle in ipairs(vehicles) do
      if #(playerCoords - GetEntityCoords(vehicle)) >= 50.0 then goto continue end
      if not NetworkGetEntityIsNetworked(vehicle) then goto continue end

      local netId = NetworkGetNetworkIdFromEntity(vehicle)
      if netId == 0 then goto continue end
      if activeVehicles[netId] then goto continue end

      if not discoveredVehicles[netId] then
        local state = Entity(vehicle).state.sagLoot
        if state and state.propSeats then
          discoveredVehicles[netId] = vehicle
          TriggerServerEvent("pf_smash_and_grab:server:recoverVehicle", netId)
          if setupVehicle(netId, vehicle, state.propSeats) then
            activeVehicles[netId] = vehicle
          end
          goto continue
        end
      end

      if discoveredVehicles[netId] then goto continue end
      if not isVehicleEligible(vehicle) then goto continue end

      candidates[#candidates + 1] = { netId = netId, entity = vehicle, vehClass = GetVehicleClass(vehicle) }

      ::continue::
    end

    for _, candidate in ipairs(candidates) do
      discoveredVehicles[candidate.netId] = candidate.entity
      TriggerServerEvent("pf_smash_and_grab:server:evaluateVehicle", candidate.netId, candidate.vehClass)
    end

    for netId, entity in pairs(activeVehicles) do
      if not DoesEntityExist(entity) then
        cleanupVehicle(netId)
        discoveredVehicles[netId] = nil
      end
    end

    for netId, entity in pairs(discoveredVehicles) do
      if not activeVehicles[netId] and not DoesEntityExist(entity) then
        discoveredVehicles[netId] = nil
      end
    end
  end
end)

AddEventHandler("onResourceStop", function(resourceName)
  if resourceName ~= cache.resource then return end
  PropManager.CleanupAll()
  Interaction.CleanupAll()
end)
