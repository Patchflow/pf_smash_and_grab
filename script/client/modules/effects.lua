local Effects = {}

---@param vehicle number
---@param windowIndex number 0=front-left, 1=front-right, 2=rear-left, 3=rear-right
function Effects.SmashWindow(vehicle, windowIndex)
  if not DoesEntityExist(vehicle) then return end
  SmashVehicleWindow(vehicle, windowIndex)
end

---@param vehicle number
function Effects.TriggerAlarm(vehicle)
  if not DoesEntityExist(vehicle) then return end
  SetVehicleAlarm(vehicle, true)
  StartVehicleAlarm(vehicle)
end

return Effects
