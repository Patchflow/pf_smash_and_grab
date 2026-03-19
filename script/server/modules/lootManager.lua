local Config = lib.require("script.shared.config")
local LootTable = lib.require("script.server.modules.lootTable")

local LootManager = {}

---@type table<number, { loot: { item: string, count: number }, propSeats: number[], looted: boolean }>
local vehicleLoot = {}
local activeCount = 0

---@return boolean
function LootManager.IsFull()
  return activeCount >= Config.MaxLootedVehicles
end

---@param netId number
---@param propSeats number[]
---@return boolean success
function LootManager.AssignLoot(netId, propSeats)
  if activeCount >= Config.MaxLootedVehicles then return false end
  if vehicleLoot[netId] then return false end

  vehicleLoot[netId] = {
    loot = LootTable.Roll(),
    propSeats = propSeats,
    looted = false,
  }

  activeCount = activeCount + 1
  return true
end

---@param netId number
---@return { loot: { item: string, count: number }, propSeats: number[], looted: boolean }?
function LootManager.GetLoot(netId)
  return vehicleLoot[netId]
end

---@param netId number
---@return boolean
function LootManager.HasLoot(netId)
  local data = vehicleLoot[netId]
  return data ~= nil and not data.looted
end

---@param netId number
function LootManager.MarkLooted(netId)
  local data = vehicleLoot[netId]
  if data and not data.looted then
    data.looted = true
    activeCount = activeCount - 1
  end
end

---@param netId number
function LootManager.RestoreLoot(netId)
  local data = vehicleLoot[netId]
  if data and data.looted then
    data.looted = false
    activeCount = activeCount + 1
  end
end

---@param netId number
function LootManager.Remove(netId)
  local data = vehicleLoot[netId]
  if data then
    if not data.looted then
      activeCount = activeCount - 1
    end
    vehicleLoot[netId] = nil
  end
end

---@return table<number, { loot: { item: string, count: number }, propSeats: number[], looted: boolean }>
function LootManager.GetAll()
  local result = {}
  for netId, data in pairs(vehicleLoot) do
    if not data.looted then
      result[netId] = data
    end
  end
  return result
end

return LootManager
