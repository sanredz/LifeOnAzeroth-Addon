local ADDON, NS = ...

local SKIP = {}

local function stackCount(tooltip)
  local ok, owner = pcall(tooltip.GetOwner, tooltip)
  if not ok or type(owner) ~= "table" then return 1 end
  local n = rawget(owner, "count")
  if type(n) == "number" and n > 1 and n < 10000 then return n end
  return 1
end

NS.TIP_LINES = {
  { key = "typical", label = "Typical price", sample = "1s 20c", on = true },
  { key = "stack", label = "Stack price", sample = "24s", on = true, note = "Only when the item is a stack" },
  { key = "perDay", label = "Sold per day", sample = "312", on = true },
  { key = "chance", label = "Sell rate", sample = "87%", on = false, note = "Share of finished auctions that sold, last 7 days" },
}

local BY = {}
for _, l in ipairs(NS.TIP_LINES) do BY[l.key] = l end

function NS.tipConf()
  local c = NS.db.tipLines
  if type(c) ~= "table" then c = {} NS.db.tipLines = c end
  c.off = type(c.off) == "table" and c.off or {}
  local seen, order = {}, {}
  for _, k in ipairs(type(c.order) == "table" and c.order or {}) do
    if BY[k] and not seen[k] then seen[k] = true order[#order + 1] = k end
  end
  for _, l in ipairs(NS.TIP_LINES) do
    if not seen[l.key] then order[#order + 1] = l.key end
  end
  c.order = order
  return c
end

function NS.tipLineOn(key)
  if key == "title" then return NS.db.tipTitle ~= false end
  local c = NS.tipConf()
  local v = c.off[key]
  if v == nil then return BY[key].on end
  return not v
end

local function fmtDay(perDay)
  return perDay >= 10 and NS.fmt(math.floor(perDay + 0.5)) or string.format("%.1f", perDay)
end

local ROW = {
  typical = function(tooltip, x)
    tooltip:AddDoubleLine("Typical price", NS.coin(x.l[1]), x.gd[1], x.gd[2], x.gd[3], 1, 1, 1)
  end,
  stack = function(tooltip, x)
    if x.n > 1 then tooltip:AddDoubleLine("Stack of " .. x.n, NS.coin(x.l[1] * x.n), x.gd[1], x.gd[2], x.gd[3], 1, 1, 1) end
  end,
  perDay = function(tooltip, x)
    local okF, perDay, _, sales = pcall(NS.Value.flow, x.id, x.rs)
    if okF and perDay then tooltip:AddDoubleLine(sales and "Sold per day" or "Left the AH per day", fmtDay(perDay), x.gd[1], x.gd[2], x.gd[3], 1, 1, 1) end
  end,
  chance = function(tooltip, x)
    local sc = x.rs and NS.sellCounts(x.id, x.rs)
    if not sc then return end
    local s, n = (sc[1] or 0) + (sc[2] or 0), (sc[1] or 0) + (sc[2] or 0) + (sc[3] or 0) + (sc[4] or 0)
    if n <= 0 then return end
    local p = s / n
    tooltip:AddDoubleLine("Sell rate", NS.color(NS.chanceColor(p), math.floor(p * 100 + 0.5) .. "%"), x.gd[1], x.gd[2], x.gd[3], 1, 1, 1)
  end,
}

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
  local g, gd = NS.COL.title2, NS.COL.ink2
  local x = { id = id, rs = rs, l = l, gd = gd, n = stackCount(tooltip) }
  if NS.previewTips and NS.previewTips[tooltip] then x.n = 20 end
  local conf = NS.tipConf()
  local any = false
  for _, k in ipairs(conf.order) do if NS.tipLineOn(k) then any = true break end end
  local title = NS.tipLineOn("title")
  if not any and not title then return end
  tooltip:AddLine(" ")
  if title then
    local where = rs and NS.houseName(rs, true) or NS.REGION_NAME[D.region] or string.upper(D.region or "")
    tooltip:AddDoubleLine("Life on Azeroth \194\183 " .. where, l[5] and (NS.pctColored(l[5]) .. NS.color(NS.COL.muted, " 24h")) or "", g[1], g[2], g[3], 1, 1, 1)
  end
  for _, k in ipairs(conf.order) do
    if NS.tipLineOn(k) then pcall(ROW[k], tooltip, x) end
  end
  tooltip:Show()
end

function NS.MarkPreviewTip(tip)
  NS.previewTips = NS.previewTips or {}
  NS.previewTips[tip] = true
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
