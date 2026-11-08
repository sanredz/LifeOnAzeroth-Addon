local ADDON, NS = ...

NS.FONT = "Fonts\\FRIZQT__.TTF"
NS.TITLE_FONT = "Fonts\\MORPHEUS.TTF"

NS.COL = {
  bg = { 0.071, 0.055, 0.035 },
  panel = { 0, 0, 0, 0.35 },
  frame = { 0.478, 0.353, 0.102 },
  frameDim = { 0.35, 0.27, 0.13 },
  gold = { 0.973, 0.827, 0.42 },
  title = { 1, 0.878, 0.541 },
  title2 = { 0.851, 0.663, 0.251 },
  ink = { 0.953, 0.906, 0.812 },
  ink2 = { 0.788, 0.725, 0.604 },
  muted = { 0.561, 0.506, 0.439 },
  up = { 0.49, 0.863, 0.541 },
  dn = { 0.937, 0.49, 0.427 },
  sparkUp = { 0.373, 0.78, 0.478 },
  sparkDn = { 0.878, 0.392, 0.353 },
}

NS.SERIES = {
  { 0.224, 0.529, 0.898 },
  { 0.851, 0.349, 0.149 },
  { 0.098, 0.62, 0.439 },
  { 0.788, 0.522, 0 },
  { 0.835, 0.318, 0.506 },
}

NS.QC = {
  [0] = { 0.616, 0.616, 0.616 },
  [1] = { 1, 1, 1 },
  [2] = { 0.118, 1, 0 },
  [3] = { 0.227, 0.584, 0.961 },
  [4] = { 0.725, 0.298, 0.969 },
  [5] = { 1, 0.502, 0 },
}

NS.CLASS = { [0] = "Consumable", [1] = "Bag", [2] = "Weapon", [3] = "Gem", [4] = "Armour", [5] = "Reagent", [6] = "Ammo", [7] = "Trade good", [9] = "Recipe", [11] = "Quiver", [12] = "Quest item", [13] = "Key", [15] = "Miscellaneous" }
NS.REGION_NAME = { us = "Americas", eu = "Europe", kr = "Korea", tw = "Taiwan" }
NS.REGIONS = { "us", "eu", "kr", "tw" }
NS.RANGES = { { "6H", 6 * 3600 }, { "1D", 86400 }, { "1W", 7 * 86400 }, { "1M", 30 * 86400 }, { "ALL", 0 } }

function NS.hex(c)
  return string.format("ff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

function NS.color(c, s)
  return "|c" .. NS.hex(c) .. s .. "|r"
end

function NS.rangeSpan(key)
  for _, r in ipairs(NS.RANGES) do
    if r[1] == key then return r[2] end
  end
  return 0
end

local function splitFields(s, sep)
  local out, n = {}, 0
  if not s or s == "" then return out, 0 end
  local from = 1
  while true do
    local a = string.find(s, sep, from, true)
    n = n + 1
    if a then
      out[n] = string.sub(s, from, a - 1)
      from = a + 1
    else
      out[n] = string.sub(s, from)
      break
    end
  end
  return out, n
end
NS.split = splitFields

function NS.decodeNums(s, base)
  local f, n = splitFields(s, ",")
  local out = {}
  for i = 1, n do
    local v = f[i] ~= "" and tonumber(f[i], base) or nil
    out[i] = v or false
  end
  return out, n
end

function NS.Ensure()
  local D = LOA_DATA
  if not D or D.ready then return D end
  D.cat = {}
  for line in string.gmatch((D.catS or "") .. "\n", "([^\n]*)\n") do
    if line ~= "" then
      local f = splitFields(line, "\t")
      local id = tonumber(f[1])
      if id then
        D.cat[id] = { f[2], tonumber(f[3]) or 1, tonumber(f[4]) or 0, tonumber(f[5]) or 15, tonumber(f[6]) or 0, tonumber(f[7]) or 0, tonumber(f[8]) or 0, tonumber(f[9]) or 0 }
      end
    end
  end
  D.lat = {}
  for rg, s in pairs(D.latS or {}) do
    local L = {}
    for line in string.gmatch(s .. "\n", "([^\n]*)\n") do
      if line ~= "" then
        local f = splitFields(line, ",")
        local id = tonumber(f[1])
        if id then L[id] = { tonumber(f[2]) or 0, tonumber(f[3]) or 0, tonumber(f[4]) or 0, tonumber(f[5]) or 0, tonumber(f[6]) } end
      end
    end
    D.lat[rg] = L
  end
  D.catS, D.latS = nil, nil
  D.ready = true
  return D
end

local idxCache = {}
function NS.idx(key)
  local D = LOA_DATA
  if not D or not D.idx or not D.idx[key] then return nil end
  local c = idxCache[key]
  if c and c.src == D.idx[key] then return c.v end
  local v = NS.decodeNums(D.idx[key], 10)
  idxCache[key] = { src = D.idx[key], v = v }
  return v
end

local histCache = {}
function NS.hist(id)
  local D = LOA_DATA
  local s = D and D.hist and D.hist[id]
  if not s then return nil end
  local c = histCache[id]
  if c and c.src == s then return c.h end
  local parts = splitFields(s, ";")
  local h = { med = NS.decodeNums(parts[1] or "", 36), min = NS.decodeNums(parts[2] or "", 36), qty = NS.decodeNums(parts[3] or "", 36) }
  histCache[id] = { src = s, h = h }
  return h
end

function NS.def(key)
  local D = LOA_DATA
  if not D then return nil end
  for _, d in ipairs(D.defs) do
    if d[1] == key then return d end
  end
end

function NS.shortName(n)
  n = n:gsub("^Green gear (%d+)\226\128\147(%d+)$", "Green, lvl %1\226\128\147%2")
  n = n:gsub(" patterns$", "")
  n = n:gsub("^Blue gear$", "Blue and up")
  n = n:gsub(" and ", " & ", 1)
  return n
end

function NS.itemName(id)
  local c = LOA_DATA and LOA_DATA.cat and LOA_DATA.cat[id]
  return c and c[1] or ("Item " .. id)
end

function NS.itemIcon(id)
  local c = LOA_DATA and LOA_DATA.cat and LOA_DATA.cat[id]
  if c and c[3] and c[3] ~= 0 then return c[3] end
  local get = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
  local ok, ic = pcall(get, id)
  if ok and ic then return ic end
  return 134400
end

function NS.iconPath(name)
  return "Interface\\Icons\\" .. name
end

function NS.latest(rg, id)
  local L = LOA_DATA and LOA_DATA.lat and LOA_DATA.lat[rg]
  return L and L[id]
end

function NS.lastVal(v)
  for i = #v, 1, -1 do
    if v[i] then return i, v[i] end
  end
  return nil, nil
end

function NS.change(t, v, span)
  local li, lv = NS.lastVal(v)
  if not li then return nil end
  local bi
  for i = 1, #v do
    if v[i] and (not span or span == 0 or t[i] >= t[li] - span) then bi = i break end
  end
  if not bi or bi == li or v[bi] == 0 then return nil end
  return 100 * (lv / v[bi] - 1)
end

function NS.pctText(v)
  if not v then return "\226\128\147" end
  local s = math.abs(v) < 10 and string.format("%.1f", v) or string.format("%.0f", v)
  return (v > 0 and "+" or "") .. s .. "%"
end

function NS.pctColored(v)
  if not v then return NS.color(NS.COL.muted, "\226\128\147") end
  local c = v > 0 and NS.COL.up or v < 0 and NS.COL.dn or NS.COL.ink2
  return NS.color(c, NS.pctText(v))
end

function NS.fmt(n)
  n = math.floor((n or 0) + 0.5)
  local s = tostring(n)
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  if out:sub(1, 1) == "," then out = out:sub(2) end
  return out
end

local GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t"

function NS.coin(c)
  c = math.floor((c or 0) + 0.5)
  local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  local out = {}
  if g > 0 then out[#out + 1] = NS.fmt(g) .. GOLD end
  if s > 0 and g < 1000 then out[#out + 1] = s .. SILVER end
  if (k > 0 and g < 10) or c == 0 then out[#out + 1] = k .. COPPER end
  return table.concat(out, " ")
end

function NS.coinShort(c)
  c = math.max(0, c or 0)
  if c >= 1000000 then return string.format("%.0fg", c / 10000) end
  if c >= 10000 then
    local g = c / 10000
    return (g < 10 and string.format("%.1fg", g) or string.format("%.0fg", g)):gsub("%.0g$", "g")
  end
  if c >= 100 then return string.format("%.0fs", c / 100) end
  return string.format("%.0fc", c)
end

function NS.ago(t)
  if not t then return "" end
  local s = time() - t
  if s < 90 then return "just now" end
  if s < 3600 then return math.floor(s / 60 + 0.5) .. " min ago" end
  if s < 86400 then
    local h = math.floor(s / 3600 + 0.5)
    return h .. (h == 1 and " hour ago" or " hours ago")
  end
  local d = math.floor(s / 86400 + 0.5)
  return d .. (d == 1 and " day ago" or " days ago")
end

function NS.fmtTime(t, span)
  if span > 3 * 86400 then return date("%b %d", t) end
  if span > 18 * 3600 then return date("%b %d, %H:%M", t) end
  return date("%H:%M", t)
end

function NS.font(fs, size, flags, title)
  fs:SetFont(title and NS.TITLE_FONT or NS.FONT, size, flags or "")
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
  return fs
end

function NS.text(parent, size, col, title, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  NS.font(fs, size, nil, title)
  local c = col or NS.COL.ink
  fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  return fs
end

function NS.fill(parent, r, g, b, a, layer, sub)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

function NS.border(f, c, a, inset)
  inset = inset or 0
  local r, g, b = c[1], c[2], c[3]
  local edges = {}
  for i = 1, 4 do
    local t = f:CreateTexture(nil, "BORDER", nil, 7)
    t:SetColorTexture(r, g, b, a or 1)
    edges[i] = t
  end
  edges[1]:SetPoint("TOPLEFT", inset, -inset) edges[1]:SetPoint("TOPRIGHT", -inset, -inset) edges[1]:SetHeight(1)
  edges[2]:SetPoint("BOTTOMLEFT", inset, inset) edges[2]:SetPoint("BOTTOMRIGHT", -inset, inset) edges[2]:SetHeight(1)
  edges[3]:SetPoint("TOPLEFT", inset, -inset) edges[3]:SetPoint("BOTTOMLEFT", inset, inset) edges[3]:SetWidth(1)
  edges[4]:SetPoint("TOPRIGHT", -inset, -inset) edges[4]:SetPoint("BOTTOMRIGHT", -inset, inset) edges[4]:SetWidth(1)
  f.edges = edges
  return edges
end

function NS.setBorderColor(f, c, a)
  for _, t in ipairs(f.edges or {}) do t:SetColorTexture(c[1], c[2], c[3], a or 1) end
end

function NS.panel(parent, a)
  local f = CreateFrame("Frame", nil, parent)
  NS.fill(f, 0, 0, 0, a or 0.35):SetAllPoints()
  NS.border(f, { 1, 1, 1 }, 0.06)
  return f
end

function NS.iconBox(parent, size, q)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size, size)
  local bd = f:CreateTexture(nil, "BACKGROUND")
  bd:SetAllPoints()
  bd:SetColorTexture(0, 0, 0, 1)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetPoint("TOPLEFT", 1, -1)
  f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  NS.border(f, NS.COL.frameDim, 1)
  function f:SetQuality(qq)
    local c = qq and NS.QC[qq] or NS.COL.frameDim
    NS.setBorderColor(self, c, qq and 0.9 or 1)
  end
  if q then f:SetQuality(q) end
  return f
end

function NS.button(parent, w, h, label, size)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  b.bg = NS.fill(b, 0, 0, 0, 0)
  b.bg:SetAllPoints()
  b.label = NS.text(b, size or 12, NS.COL.muted)
  b.label:SetPoint("CENTER")
  b.label:SetText(label)
  b:SetScript("OnEnter", function(self) if not self.on then self.label:SetTextColor(NS.COL.ink[1], NS.COL.ink[2], NS.COL.ink[3]) self.bg:SetColorTexture(1, 1, 1, 0.05) end end)
  b:SetScript("OnLeave", function(self) self:SetOn(self.on) end)
  function b:SetOn(on)
    self.on = on
    local c = on and NS.COL.gold or NS.COL.muted
    self.label:SetTextColor(c[1], c[2], c[3])
    self.bg:SetColorTexture(0.973, 0.827, 0.42, on and 0.16 or 0)
  end
  return b
end

function NS.segmented(parent, keys, onPick, w)
  local f = NS.panel(parent, 0.4)
  local bw = w or 34
  f:SetSize(#keys * bw + 6, 26)
  f.buttons = {}
  for i, k in ipairs(keys) do
    local b = NS.button(f, bw, 20, k, 11)
    b:SetPoint("LEFT", 3 + (i - 1) * bw, 0)
    b.key = k
    b:SetScript("OnClick", function() onPick(k) end)
    f.buttons[i] = b
  end
  function f:Select(key)
    for _, b in ipairs(self.buttons) do b:SetOn(b.key == key) end
  end
  return f
end

NS.events = CreateFrame("Frame")
NS.events:RegisterEvent("ADDON_LOADED")
NS.events:SetScript("OnEvent", function(self, ev, name)
  if ev == "ADDON_LOADED" and name == ADDON then
    LifeOnAzerothDB = LifeOnAzerothDB or {}
    local db = LifeOnAzerothDB
    db.range = db.range or "ALL"
    db.minimap = db.minimap or { angle = 200, hide = false }
    NS.db = db
    if NS.OnLoad then NS.OnLoad() end
    self:UnregisterEvent("ADDON_LOADED")
  end
end)
