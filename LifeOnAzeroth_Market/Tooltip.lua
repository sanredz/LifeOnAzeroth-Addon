local ADDON, NS = ...

local SKIP = {}

local function stackCount(tooltip)
  local ok, owner = pcall(tooltip.GetOwner, tooltip)
  if not ok or type(owner) ~= "table" then return 1 end
  local n = rawget(owner, "count")
  if type(n) == "number" and n > 1 and n < 10000 then return n end
  return 1
end

local function addLines(tooltip, data)
  if not NS.db or NS.db.tooltip == false or SKIP[tooltip] then return end
  if not LOA_DATA or type(data) ~= "table" then return end
  local ok, id = pcall(function() return data.id end)
  if not ok or type(id) ~= "number" then return end
  local D = NS.Ensure()
  if not D or not D.cat or not D.cat[id] then return end
  local own = NS.myHouse()
  local rs = own and D.houses and D.houses[own] and own or NS.ruleset()
  local H = rs and D.houses and D.houses[rs]
  local l = H and H.lat and H.lat[id] or (not H and NS.latest(D.region, id))
  if not l or not l[1] or l[1] <= 0 then return end
  local where = rs and NS.houseName(rs, true) or NS.REGION_NAME[D.region] or string.upper(D.region or "")
  local g, gd = NS.COL.title2, NS.COL.ink2
  tooltip:AddLine(" ")
  tooltip:AddDoubleLine("Life on Azeroth \194\183 " .. where, l[5] and (NS.pctColored(l[5]) .. NS.color(NS.COL.muted, " 24h")) or "", g[1], g[2], g[3], 1, 1, 1)
  tooltip:AddDoubleLine("Typical price", NS.coin(l[1]), gd[1], gd[2], gd[3], 1, 1, 1)
  local n = stackCount(tooltip)
  if n > 1 then
    tooltip:AddDoubleLine("Stack of " .. n, NS.coin(l[1] * n), gd[1], gd[2], gd[3], 1, 1, 1)
  end
  local okF, perDay, _, sales = pcall(NS.Value.flow, id, rs)
  if okF and perDay then
    tooltip:AddDoubleLine(sales and "Sold per day" or "Left the AH per day", perDay >= 10 and NS.fmt(math.floor(perDay + 0.5)) or string.format("%.1f", perDay), gd[1], gd[2], gd[3], 1, 1, 1)
  end
  tooltip:Show()
end

function NS.SetupTooltips()
  if ShoppingTooltip1 then SKIP[ShoppingTooltip1] = true end
  if ShoppingTooltip2 then SKIP[ShoppingTooltip2] = true end
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
      pcall(addLines, tooltip, data)
    end)
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(4, function() pcall(NS.Ensure) end)
  end
end
