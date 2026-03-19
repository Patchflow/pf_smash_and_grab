local Config = lib.require("script.shared.config")
local Effects = lib.require("script.client.modules.effects")
local PropManager = lib.require("script.client.modules.propManager")

local Interaction = {}

---@class TargetData
---@field zoneIds number[]
---@field vehicle number
---@field variant "smash"|"loot"
---@field props table<number, number>?
---@field prop number?
---@field lastPos vector3

---@type table<number, TargetData>
local activeTargets = {}

---@param vehicle number
---@return boolean
local function isVehicleAccessible(vehicle)
  if not DoesEntityExist(vehicle) then return false end
  if IsPedInAnyVehicle(cache.ped, false) then return false end
  if GetPedInVehicleSeat(vehicle, -1) ~= 0 then return false end
  if not IsVehicleStopped(vehicle) then return false end
  return true
end

---@param netId number
local function attemptLoot(netId)
  local completed = lib.progressBar({
    duration = Config.LootAnimation.duration,
    label = Config.LootAnimation.label,
    useWhileDead = false,
    canCancel = true,
    disable = { car = true, move = true, combat = true },
    anim = Config.LootAnimation.anim,
  })

  if not completed then
    lib.notify({ title = "Smash & Grab", description = "Cancelled!", type = "error" })
    return
  end

  local result = lib.callback.await("pf_smash_and_grab:server:claimLoot", false, netId)
  if not result then return end

  if result.success then
    lib.notify({
      title = "Smash & Grab",
      description = ("Got %dx %s"):format(result.count, result.item),
      type = "success",
    })
    Interaction.RemoveTarget(netId)
    PropManager.DeleteProps(netId)
    return
  end

  local messages = {
    cooldown = ("Wait %d seconds"):format(result.remaining or 0),
    inventory_full = "Inventory full!",
  }

  lib.notify({
    title = "Smash & Grab",
    description = messages[result.reason] or "Nothing here...",
    type = "error",
  })
end

---@param prop number
---@return vector3|nil
local function getPropCoords(prop)
  if not DoesEntityExist(prop) then return nil end
  local coords = GetEntityCoords(prop)
  if coords.x == 0.0 and coords.y == 0.0 and coords.z == 0.0 then return nil end
  return coords
end

local function createSmashZones(netId, vehicle, props)
  local zoneIds = {}

  for seatIndex, prop in pairs(props) do
    local coords = getPropCoords(prop)
    if not coords then goto continue end

    local seatBone = Config.SeatBones[seatIndex]
    if not seatBone then goto continue end

    local windowIndex = Config.WindowIndices[seatBone]
    if not windowIndex then goto continue end

    local zoneId = exports.ox_target:addSphereZone({
      coords = coords,
      radius = Config.TargetDistance,
      debug = Config.Debug,
      options = {
        {
          name = "pf_smash_and_grab:" .. netId .. ":" .. seatIndex,
          label = "Smash Window",
          icon = "fas fa-hand-fist",
          canInteract = function()
            return isVehicleAccessible(vehicle)
          end,
          onSelect = function()
            Interaction.AttemptSmash(netId, vehicle, windowIndex, prop)
          end,
        },
      },
    })

    zoneIds[#zoneIds + 1] = zoneId

    ::continue::
  end

  return zoneIds
end

local function createLootZone(netId, vehicle, prop)
  local coords = getPropCoords(prop)
  if not coords then return {} end

  local zoneId = exports.ox_target:addSphereZone({
    coords = coords,
    radius = Config.TargetDistance,
    debug = Config.Debug,
    options = {
      {
        name = "pf_smash_loot:" .. netId,
        label = "Loot",
        icon = "fas fa-bag-shopping",
        canInteract = function()
          return isVehicleAccessible(vehicle)
        end,
        onSelect = function()
          attemptLoot(netId)
        end,
      },
    },
  })

  return { zoneId }
end

function Interaction.AttemptSmash(netId, vehicle, windowIndex, prop)
  local cd = lib.callback.await("pf_smash_and_grab:server:checkCooldown", false)
  if cd and cd.onCooldown then
    lib.notify({ title = "Smash & Grab", description = ("Wait %d seconds"):format(cd.remaining), type = "error" })
    return
  end

  local passed = lib.skillCheck(Config.SkillCheck.difficulty, Config.SkillCheck.inputs)
  if not passed then
    local alarmTriggered = lib.callback.await("pf_smash_and_grab:server:smashFailed", false, netId)
    if alarmTriggered then
      Effects.TriggerAlarm(vehicle)
    end
    lib.notify({ title = "Smash & Grab", description = "Failed to break the window!", type = "error" })
    return
  end

  local completed = lib.progressBar({
    duration = Config.SmashAnimation.duration,
    label = Config.SmashAnimation.label,
    useWhileDead = false,
    canCancel = true,
    disable = { car = true, move = true, combat = true },
    anim = Config.SmashAnimation.anim,
  })

  if not completed then
    lib.notify({ title = "Smash & Grab", description = "Cancelled!", type = "error" })
    return
  end

  Effects.SmashWindow(vehicle, windowIndex)
  Effects.TriggerAlarm(vehicle)

  Interaction.RemoveTarget(netId)

  local zoneIds = createLootZone(netId, vehicle, prop)
  if #zoneIds == 0 then return end

  activeTargets[netId] = {
    zoneIds = zoneIds,
    vehicle = vehicle,
    variant = "loot",
    prop = prop,
    lastPos = GetEntityCoords(vehicle),
  }
end

local function removeZones(data)
  for _, zoneId in ipairs(data.zoneIds) do
    exports.ox_target:removeZone(zoneId)
  end
  data.zoneIds = {}
end

local function restoreZones(netId, data, pos)
  if data.variant == "smash" then
    data.zoneIds = createSmashZones(netId, data.vehicle, data.props)
  else
    data.zoneIds = createLootZone(netId, data.vehicle, data.prop)
  end
  data.lastPos = pos or GetEntityCoords(data.vehicle)
end

local function refreshZones(netId, data)
  if not DoesEntityExist(data.vehicle) then return end

  local newPos = GetEntityCoords(data.vehicle)
  if #(newPos - data.lastPos) < 0.5 then return end

  removeZones(data)
  restoreZones(netId, data, newPos)
end

function Interaction.AddTarget(netId, vehicle, props)
  if activeTargets[netId] then return end

  local zoneIds = createSmashZones(netId, vehicle, props)
  if #zoneIds == 0 then return end

  activeTargets[netId] = {
    zoneIds = zoneIds,
    vehicle = vehicle,
    variant = "smash",
    props = props,
    lastPos = GetEntityCoords(vehicle),
  }
end

function Interaction.RemoveTarget(netId)
  local data = activeTargets[netId]
  if not data then return end

  removeZones(data)
  activeTargets[netId] = nil
end

function Interaction.CleanupAll()
  local netIds = {}
  for netId in pairs(activeTargets) do
    netIds[#netIds + 1] = netId
  end

  for _, netId in ipairs(netIds) do
    Interaction.RemoveTarget(netId)
  end
end

CreateThread(function()
  while true do
    Wait(1000)

    if not next(activeTargets) then goto continue end

    local playerCoords = GetEntityCoords(cache.ped)
    local nearby = lib.getNearbyVehicles(playerCoords, 25.0, true)
    local nearbySet = {}

    for _, vehData in ipairs(nearby) do
      if not NetworkGetEntityIsNetworked(vehData.vehicle) then goto skip end
      local netId = NetworkGetNetworkIdFromEntity(vehData.vehicle)
      if netId ~= 0 and activeTargets[netId] then
        nearbySet[netId] = true
        if #activeTargets[netId].zoneIds == 0 then
          restoreZones(netId, activeTargets[netId])
        else
          refreshZones(netId, activeTargets[netId])
        end
      end
      ::skip::
    end
    for netId, data in pairs(activeTargets) do
      if nearbySet[netId] then goto skipCleanup end

      if not DoesEntityExist(data.vehicle) then
        Interaction.RemoveTarget(netId)
        goto skipCleanup
      end

      if #data.zoneIds > 0 and #(GetEntityCoords(data.vehicle) - playerCoords) > 25.0 then
        removeZones(data)
      end

      ::skipCleanup::
    end

    ::continue::
  end
end)

return Interaction
