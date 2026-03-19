local Config = lib.require("script.shared.config")

local PropManager = {}

---@type table<number, table<number, number>> netId -> { seatIndex -> prop handle }
local spawnedProps = {}

---@param netId number
---@param propSeats number[]
function PropManager.SpawnProps(netId, propSeats)
  if spawnedProps[netId] then return end

  local vehicle = NetworkGetEntityFromNetworkId(netId)
  if not DoesEntityExist(vehicle) then return end

  local vehCoords = GetEntityCoords(vehicle)
  local propsBySeat = {}
  local count = 0

  for _, seatIndex in ipairs(propSeats) do
    local boneName = Config.SeatBones[seatIndex]
    if not boneName then goto continue end

    local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
    if boneIndex == -1 then goto continue end

    local modelIndex = ((netId + seatIndex) % #Config.Props.models) + 1
    local propModel = Config.Props.models[modelIndex]
    lib.requestModel(propModel)
    local prop = CreateObject(propModel, vehCoords.x, vehCoords.y, vehCoords.z, false, false, false)

    if not DoesEntityExist(prop) then goto continue end

    SetEntityCollision(prop, false, false)
    SetEntityAsMissionEntity(prop, true, true)

    local offsets = Config.Props.offsets[propModel] or { 0.0, 0.0, 0.25, 0.0, 0.0, 0.0 }

    AttachEntityToEntity(
      prop, vehicle, boneIndex,
      offsets[1], offsets[2], offsets[3],
      offsets[4], offsets[5], offsets[6],
      false, true, false, false, 0, true
    )
    SetModelAsNoLongerNeeded(propModel)

    propsBySeat[seatIndex] = prop
    count = count + 1

    ::continue::
  end

  spawnedProps[netId] = propsBySeat
end

---@param netId number
function PropManager.DeleteProps(netId)
  local props = spawnedProps[netId]
  if not props then return end

  for _, prop in pairs(props) do
    if DoesEntityExist(prop) then
      SetEntityAsMissionEntity(prop, true, true)
      DetachEntity(prop, false, false)
      DeleteEntity(prop)
    end
  end

  spawnedProps[netId] = nil
end

function PropManager.CleanupAll()
  local netIds = {}
  for netId in pairs(spawnedProps) do
    netIds[#netIds + 1] = netId
  end

  for _, netId in ipairs(netIds) do
    PropManager.DeleteProps(netId)
  end
end

---@param netId number
---@return boolean
function PropManager.HasProps(netId)
  return spawnedProps[netId] ~= nil
end

---@param netId number
---@return table<number, number>|nil seatIndex -> prop handle
function PropManager.GetProps(netId)
  return spawnedProps[netId]
end

return PropManager
