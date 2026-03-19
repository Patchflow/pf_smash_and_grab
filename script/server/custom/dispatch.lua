local Dispatch = {}

---Called when a player successfully smashes a vehicle and grabs loot.
---Add your dispatch integration here.
---@param data { source: number, coords: vector3, netId: number, item: string, count: number }
function Dispatch.Alert(data)
  -- Example: lb-tablet (server export)
  -- exports["lb-tablet"]:AddDispatch({
  --   priority = "medium",
  --   code = "10-62",
  --   title = "Vehicle Break-In",
  --   description = "A vehicle break-in has been reported.",
  --   job = "police",
  --   time = 5,
  --   location = {
  --     label = "Vehicle Break-In",
  --     coords = vec2(data.coords.x, data.coords.y),
  --   },
  --   blip = {
  --     sprite = 326,
  --     color = 1,
  --     size = 1.2,
  --     label = "10-62 - Vehicle Break-In",
  --   },
  -- })
end

return Dispatch
