local Config = lib.require("script.shared.config")

local LootTable = {}

local totalWeight = 0
for _, entry in ipairs(Config.LootTables) do
  totalWeight = totalWeight + entry.weight
end

---@return { item: string, count: number }
function LootTable.Roll()
  local roll = math.random() * totalWeight
  local cumulative = 0

  for _, entry in ipairs(Config.LootTables) do
    cumulative = cumulative + entry.weight
    if roll <= cumulative then
      local count = math.random(entry.minCount, entry.maxCount)
      return { item = entry.item, count = count }
    end
  end

  local fallback = Config.LootTables[1]
  return { item = fallback.item, count = fallback.minCount }
end

return LootTable
