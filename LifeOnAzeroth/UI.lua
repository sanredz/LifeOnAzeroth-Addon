local ADDON, NS = ...

local W, H = 1060, 640
local SIDE_W = 340
local st = { series = { { kind = "idx", key = "F100" } } }
NS.st = st

local main

local function D() return NS.Ensure() end

function NS.seriesData(s)
  local d = D()
  if s.kind == "idx" then
    local def = NS.def(s.key)
    return { name = def and def[2] or s.key, t = d.t, v = NS.idx(s.key) or {}, unit = "idx", icon = def and NS.iconPath(def[4]) }
  end
  local h = NS.hist(s.id)
  return { name = NS.itemName(s.id), t = d.ht, v = h and h.med or {}, unit = "coin", icon = NS.itemIcon(s.id) }
end

local function windowFrame(f)
  NS.fill(f, 0.071, 0.055, 0.035, 0.97, "BACKGROUND", -8):SetAllPoints()
  local glow = f:CreateTexture(nil, "BACKGROUND", nil, -7)
  glow:SetTexture("Interface\\Buttons\\WHITE8X8")
  glow:SetPoint("TOPLEFT")
  glow:SetPoint("TOPRIGHT")
  glow:SetHeight(140)
  glow:SetGradient("VERTICAL", CreateColor(1, 0.78, 0.31, 0), CreateColor(1, 0.78, 0.31, 0.07))
  NS.border(f, { 0.478, 0.353, 0.102 }, 1)
  local inner = CreateFrame("Frame", nil, f)
  inner:SetAllPoints()
  NS.border(inner, { 0, 0, 0 }, 0.9, 1)
  local inner2 = CreateFrame("Frame", nil, f)
  inner2:SetAllPoints()
  NS.border(inner2, { 0.388, 0.282, 0.086 }, 0.55, 3)
end

local function rule(parent, y)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetTexture("Interface\\Buttons\\WHITE8X8")
  t:SetPoint("TOPLEFT", 14, y)
  t:SetPoint("TOPRIGHT", -14, y)
  t:SetHeight(1)
  t:SetGradient("HORIZONTAL", CreateColor(0.973, 0.827, 0.42, 0.45), CreateColor(0.973, 0.827, 0.42, 0.05))
  return t
end

local function spark(row, v)
  local sp = row.spark
  sp.lines = sp.lines or {}
  for _, l in ipairs(sp.lines) do l:Hide() end
  local pts = {}
  for i = 1, #v do if v[i] then pts[#pts + 1] = { i, v[i] } end end
  if #pts < 2 then return end
  local n = #v - 1
  if n < 1 then n = 1 end
  local lo, hi = math.huge, -math.huge
  for _, p in ipairs(pts) do lo = math.min(lo, p[2]) hi = math.max(hi, p[2]) end
  local w, h = sp:GetWidth(), sp:GetHeight()
  local step = math.max(1, math.ceil(#pts / 24))
  local draw = {}
  for i = 1, #pts, step do draw[#draw + 1] = pts[i] end
  if draw[#draw] ~= pts[#pts] then draw[#draw + 1] = pts[#pts] end
  local up = pts[#pts][2] >= pts[1][2]
  local c = up and NS.COL.sparkUp or NS.COL.sparkDn
  local function xy(p) return 1 + (p[1] - 1) / n * (w - 2), 2 + (hi > lo and (p[2] - lo) / (hi - lo) or 0.5) * (h - 4) end
  for i = 1, #draw - 1 do
    local l = sp.lines[i]
    if not l then l = sp:CreateLine(nil, "ARTWORK") l:SetThickness(1.4) sp.lines[i] = l end
    l:SetColorTexture(c[1], c[2], c[3], 1)
    local x1, y1 = xy(draw[i])
    local x2, y2 = xy(draw[i + 1])
    l:SetStartPoint("BOTTOMLEFT", sp, x1, y1)
    l:SetEndPoint("BOTTOMLEFT", sp, x2, y2)
    l:Show()
  end
end

local function seriesIndex(kind, key)
  for i, s in ipairs(st.series) do
    if s.kind == kind and (s.key == key or s.id == key) then return i end
  end
end

function NS.AddSeries(s)
  if s.kind == "item" and seriesIndex("item", s.id) then return end
  if #st.series < 5 then st.series[#st.series + 1] = s else st.series[5] = s end
  NS.Refresh()
end

local function toggleIndex(key)
  local at = seriesIndex("idx", key)
  if at then
    if #st.series > 1 then table.remove(st.series, at) end
  else
    NS.AddSeries({ kind = "idx", key = key })
    return
  end
  NS.Refresh()
end

local function buildSide(f)
  local side = CreateFrame("Frame", nil, f)
  side:SetPoint("TOPLEFT", 16, -112)
  side:SetPoint("BOTTOMLEFT", 16, 16)
  side:SetWidth(SIDE_W)
  side.per = NS.text(side, 12, NS.COL.ink2)
  side.per:SetPoint("TOPLEFT", 4, 0)
  side.perSub = NS.text(side, 10, NS.COL.muted)
  side.perSub:SetPoint("TOPLEFT", 4, -16)
  side.perSub:SetText("Follows the chart's time range")
  local head = CreateFrame("Frame", nil, side)
  head:SetPoint("TOPLEFT", 0, -36)
  head:SetPoint("TOPRIGHT", 0, -36)
  head:SetHeight(22)
  NS.fill(head, 0, 0, 0, 0.3):SetAllPoints()
  local function hcol(txt, x, w, just)
    local t = NS.text(head, 10, NS.COL.muted)
    t:SetPoint("LEFT", x, 0)
    t:SetWidth(w)
    t:SetJustifyH(just or "LEFT")
    t:SetText(txt)
    return t
  end
  hcol("INDEX", 34, 100)
  hcol("TREND", SIDE_W - 160, 50)
  hcol("VALUE", SIDE_W - 110, 46, "RIGHT")
  side.hch = hcol("ALL TIME", SIDE_W - 62, 54, "RIGHT")
  local sf = CreateFrame("ScrollFrame", nil, side)
  sf:SetPoint("TOPLEFT", 0, -60)
  sf:SetPoint("BOTTOMRIGHT", -6, 0)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(SIDE_W - 8, 10)
  sf:SetScrollChild(child)
  sf:EnableMouseWheel(true)
  local bar = sf:CreateTexture(nil, "OVERLAY")
  bar:SetColorTexture(0.353, 0.275, 0.125, 0.9)
  bar:SetWidth(3)
  local function updBar()
    local vis, tot = sf:GetHeight(), child:GetHeight()
    if tot <= vis + 1 then bar:Hide() return end
    local h = math.max(24, vis * vis / tot)
    local off = sf:GetVerticalScroll() / (tot - vis) * (vis - h)
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 5, -off)
    bar:SetHeight(h)
    bar:Show()
  end
  sf:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 48)))
    updBar()
  end)
  side.sf, side.child, side.rows, side.heads, side.updBar = sf, child, {}, {}, updBar
  return side
end

local function indexRow(side, i)
  local r = side.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, side.child)
  r:SetSize(SIDE_W - 8, 26)
  r.bg = NS.fill(r, 1, 1, 1, 0)
  r.bg:SetAllPoints()
  r.sw = r:CreateTexture(nil, "ARTWORK")
  r.sw:SetSize(3, 18)
  r.sw:SetPoint("LEFT", 2, 0)
  r.ic = NS.iconBox(r, 20)
  r.ic:SetPoint("LEFT", 10, 0)
  r.nm = NS.text(r, 12, NS.COL.ink)
  r.nm:SetPoint("LEFT", 36, 0)
  r.nm:SetWidth(SIDE_W - 36 - 168)
  r.spark = CreateFrame("Frame", nil, r)
  r.spark:SetSize(48, 18)
  r.spark:SetPoint("LEFT", SIDE_W - 168, 0)
  r.vl = NS.text(r, 12, { 1, 0.949, 0.812 })
  r.vl:SetPoint("RIGHT", -62, 0)
  r.vl:SetWidth(46)
  r.vl:SetJustifyH("RIGHT")
  r.ch = NS.text(r, 11, NS.COL.ink2)
  r.ch:SetPoint("RIGHT", -6, 0)
  r.ch:SetWidth(54)
  r.ch:SetJustifyH("RIGHT")
  r:SetScript("OnEnter", function(self)
    if not self.on then self.bg:SetColorTexture(1, 1, 1, 0.04) end
    if self.def then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.def[2], NS.COL.title[1], NS.COL.title[2], NS.COL.title[3])
      if self.def[5] and self.def[5] ~= "" then GameTooltip:AddLine(self.def[5], NS.COL.ink2[1], NS.COL.ink2[2], NS.COL.ink2[3], true) end
      local cnt = LOA_DATA.counts and LOA_DATA.counts[self.def[1]]
      if cnt then GameTooltip:AddLine(NS.fmt(cnt) .. " items.", NS.COL.muted[1], NS.COL.muted[2], NS.COL.muted[3]) end
      GameTooltip:AddLine("Click to add to the chart.", 0.6, 0.6, 0.6)
      GameTooltip:Show()
    end
  end)
  r:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.973, 0.827, 0.42, self.on and 0.07 or 0) GameTooltip:Hide() end)
  r:SetScript("OnClick", function(self) toggleIndex(self.def[1]) end)
  side.rows[i] = r
  return r
end

local function paintSide()
  local side = main.side
  local d = D()
  local span = NS.rangeSpan(NS.db.range)
  local per = ({ ["6H"] = "last 6 hours", ["1D"] = "last 24 hours", ["1W"] = "last 7 days", ["1M"] = "last 30 days", ALL = "since tracking began" })[NS.db.range]
  local short = ({ ["6H"] = "6H", ["1D"] = "24H", ["1W"] = "7D", ["1M"] = "30D", ALL = "ALL TIME" })[NS.db.range]
  side.per:SetText("Change over the " .. NS.color(NS.COL.gold, per))
  side.hch:SetText(short)
  for _, r in ipairs(side.rows) do r:Hide() end
  for _, h in ipairs(side.heads) do h:Hide() end
  local y, n, hn, lastG = 0, 0, 0, nil
  for _, def in ipairs(d.defs) do
    local v = NS.idx(def[1])
    if v then
      if def[3] ~= lastG then
        lastG = def[3]
        hn = hn + 1
        local h = side.heads[hn]
        if not h then h = NS.text(side.child, 14, NS.COL.title2, true) side.heads[hn] = h end
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 2, -y - (hn > 1 and 8 or 2))
        h:SetText(def[3])
        h:Show()
        y = y + (hn > 1 and 30 or 24)
      end
      n = n + 1
      local r = indexRow(side, n)
      r.def = def
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, -y)
      r:Show()
      y = y + 27
      local on = seriesIndex("idx", def[1])
      r.on = on and true or false
      r.bg:SetColorTexture(0.973, 0.827, 0.42, on and 0.07 or 0)
      local sc = on and NS.SERIES[on]
      r.sw:SetColorTexture(sc and sc[1] or 0, sc and sc[2] or 0, sc and sc[3] or 0, sc and 1 or 0)
      r.ic.icon:SetTexture(NS.iconPath(def[4]))
      r.nm:SetText(NS.shortName(def[2]))
      local _, lv = NS.lastVal(v)
      r.vl:SetText(lv and string.format("%.1f", lv) or "\226\128\147")
      r.ch:SetText(NS.pctColored(NS.change(d.t, v, span)))
      spark(r, v)
    end
  end
  side.child:SetHeight(math.max(10, y))
  local max = math.max(0, y - side.sf:GetHeight())
  if side.sf:GetVerticalScroll() > max then side.sf:SetVerticalScroll(max) end
  side.updBar()
end

local function chip(parent, i)
  local c = parent.chips[i]
  if c then return c end
  c = CreateFrame("Frame", nil, parent)
  c:SetHeight(26)
  NS.fill(c, 0, 0, 0, 0.35):SetAllPoints()
  NS.border(c, { 1, 1, 1 }, 0.07)
  c.dot = c:CreateTexture(nil, "ARTWORK")
  c.dot:SetSize(9, 9)
  c.dot:SetPoint("LEFT", 8, 0)
  c.ic = NS.iconBox(c, 18)
  c.ic:SetPoint("LEFT", 22, 0)
  c.nm = NS.text(c, 12, NS.COL.ink)
  c.nm:SetPoint("LEFT", 46, 0)
  c.ch = NS.text(c, 11, NS.COL.ink2)
  c.ch:SetPoint("LEFT", c.nm, "RIGHT", 8, 0)
  c.x = CreateFrame("Button", nil, c)
  c.x:SetSize(16, 16)
  c.x:SetPoint("RIGHT", -4, 0)
  c.x.t = NS.text(c.x, 14, NS.COL.muted)
  c.x.t:SetPoint("CENTER", 0, 1)
  c.x.t:SetText("\195\151")
  c.x:SetScript("OnEnter", function(self) self.t:SetTextColor(NS.COL.ink[1], NS.COL.ink[2], NS.COL.ink[3]) end)
  c.x:SetScript("OnLeave", function(self) self.t:SetTextColor(NS.COL.muted[1], NS.COL.muted[2], NS.COL.muted[3]) end)
  c.x:SetScript("OnClick", function(self)
    table.remove(st.series, self.idx)
    NS.Refresh()
  end)
  parent.chips[i] = c
  return c
end

local function paintChart()
  local area = main.right
  local d = D()
  local span = NS.rangeSpan(NS.db.range)
  local list = {}
  for k, s in ipairs(st.series) do
    local x = NS.seriesData(s)
    x.color = NS.SERIES[k]
    list[k] = x
  end
  for _, c in ipairs(area.chips) do c:Hide() end
  local maxW = area:GetWidth() - main.ranges:GetWidth() - 16
  local x, y = 0, 0
  for k, s in ipairs(list) do
    local c = chip(area, k)
    local col = NS.SERIES[k]
    c.dot:SetColorTexture(col[1], col[2], col[3], 1)
    c.ic.icon:SetTexture(s.icon)
    local it = st.series[k]
    if it.kind == "item" then
      local cat = d.cat[it.id]
      c.ic:SetQuality(cat and cat[2])
      local q = cat and NS.QC[cat[2]] or NS.COL.ink
      c.nm:SetTextColor(q[1], q[2], q[3])
    else
      c.ic:SetQuality(nil)
      c.nm:SetTextColor(NS.COL.ink[1], NS.COL.ink[2], NS.COL.ink[3])
    end
    c.nm:SetText(s.name)
    c.ch:SetText(NS.pctColored(NS.change(s.t, s.v, span)))
    c.x.idx = k
    local multi = #list > 1
    c.x:SetShown(multi)
    local w = 46 + c.nm:GetStringWidth() + 8 + c.ch:GetStringWidth() + (multi and 26 or 10)
    c:SetWidth(w)
    if x > 0 and x + w > maxW then x, y = 0, y + 32 end
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", x, -y)
    c:Show()
    x = x + w + 6
  end
  if #list < 5 then
    area.hint:ClearAllPoints()
    if x > 0 and x + area.hint:GetStringWidth() + 8 > maxW then x, y = 0, y + 32 end
    area.hint:SetPoint("TOPLEFT", x + 4, -y - 7)
    area.hint:Show()
  else
    area.hint:Hide()
  end
  area.chart:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -y - 40)
  area.foot:SetText(#list > 1 and "Compared as % change from the start of the range." or "Index value; every index starts at 100 when its history begins.")
  if #list == 1 and st.series[1].kind == "item" then area.foot:SetText("Typical price each hour.") end
  area.chart:Draw(list, { span = span })
end

local function paintHeader()
  local d = D()
  local rn = NS.REGION_NAME[d.region] or string.upper(d.region or "")
  main.note:SetText(rn .. " \194\183 " .. #d.t .. " hourly snapshots")
  main.fresh:SetText("Prices " .. NS.ago(d.built) .. " \194\183 " .. date("%b %d, %H:%M", d.built))
  local old = time() - (d.built or 0) > 3 * 3600
  local c = old and NS.COL.dn or NS.COL.muted
  main.fresh:SetTextColor(c[1], c[2], c[3])
end

function NS.Refresh()
  if not main or not main:IsShown() then return end
  if not D() then
    main.emptyState:Show()
    main.body:Hide()
    return
  end
  main.emptyState:Hide()
  main.body:Show()
  main.ranges:Select(NS.db.range)
  paintHeader()
  paintSide()
  paintChart()
end

local function searchHits(q)
  local d = D()
  local words = {}
  for w in string.gmatch(string.lower(q), "%S+") do words[#words + 1] = w end
  if #words == 0 then return {} end
  local ql = string.lower(strtrim and strtrim(q) or q)
  local hits = {}
  for id, c in pairs(d.cat) do
    local n = string.lower(c[1])
    local ok = true
    for _, w in ipairs(words) do
      if not string.find(n, w, 1, true) then ok = false break end
    end
    if ok then
      local rank = n == ql and 0 or string.sub(n, 1, #ql) == ql and 1 or (string.find(" " .. n, " " .. words[1], 1, true) and 2) or 3
      local l = NS.latest(d.region, id)
      hits[#hits + 1] = { id, c, l, rank, l and l[4] or 0 }
    end
  end
  table.sort(hits, function(a, b) if a[4] ~= b[4] then return a[4] < b[4] end if a[5] ~= b[5] then return a[5] > b[5] end return a[2][1] < b[2][1] end)
  local out = {}
  for i = 1, math.min(8, #hits) do out[i] = hits[i] end
  return out
end

local function buildSearch(f)
  local box = CreateFrame("EditBox", nil, f)
  box:SetSize(470, 34)
  box:SetPoint("TOPLEFT", 16, -64)
  box:SetAutoFocus(false)
  box:SetFont(NS.FONT, 13, "")
  box:SetTextColor(NS.COL.ink[1], NS.COL.ink[2], NS.COL.ink[3])
  box:SetTextInsets(34, 10, 0, 0)
  box:SetMaxLetters(60)
  NS.fill(box, 0, 0, 0, 0.55):SetAllPoints()
  NS.border(box, { 0.353, 0.275, 0.125 }, 1)
  local mag = box:CreateTexture(nil, "OVERLAY")
  mag:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
  mag:SetSize(14, 14)
  mag:SetPoint("LEFT", 12, -1)
  mag:SetVertexColor(0.973, 0.827, 0.42)
  local ph = NS.text(box, 13, NS.COL.muted)
  ph:SetPoint("LEFT", 34, 0)
  ph:SetText("Search any item: Copper Ore, Linen Bag, Thunderfury\226\128\166")
  local res = CreateFrame("Frame", nil, f)
  res:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)
  res:SetWidth(470)
  res:SetFrameLevel(f:GetFrameLevel() + 40)
  NS.fill(res, 0.055, 0.043, 0.027, 0.98):SetAllPoints()
  NS.border(res, { 0.353, 0.275, 0.125 }, 1)
  res.rows = {}
  res.none = NS.text(res, 12, NS.COL.muted)
  res.none:SetPoint("TOPLEFT", 12, -12)
  res.none:SetText("No item by that name on the auction house.")
  res:Hide()
  local function row(i)
    local r = res.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, res)
    r:SetSize(468, 36)
    r:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 36)
    r.bg = NS.fill(r, 0.973, 0.827, 0.42, 0)
    r.bg:SetAllPoints()
    r.ic = NS.iconBox(r, 26)
    r.ic:SetPoint("LEFT", 10, 0)
    r.nm = NS.text(r, 13, NS.COL.ink)
    r.nm:SetPoint("LEFT", 46, 0)
    r.nm:SetWidth(220)
    r.pr = NS.text(r, 12, NS.COL.ink)
    r.pr:SetPoint("RIGHT", -70, 0)
    r.pr:SetJustifyH("RIGHT")
    r.ch = NS.text(r, 11, NS.COL.ink2)
    r.ch:SetPoint("RIGHT", -12, 0)
    r.ch:SetWidth(54)
    r.ch:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.973, 0.827, 0.42, 0.08) end)
    r:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.973, 0.827, 0.42, 0) end)
    r:SetScript("OnClick", function(self)
      box:SetText("")
      box:ClearFocus()
      res:Hide()
      NS.OpenItem(self.id)
    end)
    res.rows[i] = r
    return r
  end
  local function show()
    local q = box:GetText() or ""
    ph:SetShown(q == "")
    if not D() or q:gsub("%s", "") == "" then res:Hide() return end
    local hits = searchHits(q)
    for _, r in ipairs(res.rows) do r:Hide() end
    res.first = hits[1] and hits[1][1]
    if #hits == 0 then
      res.none:Show()
      res:SetHeight(38)
    else
      res.none:Hide()
      for i, h in ipairs(hits) do
        local r = row(i)
        r.id = h[1]
        r.ic.icon:SetTexture(NS.itemIcon(h[1]))
        r.ic:SetQuality(h[2][2])
        local qc = NS.QC[h[2][2]] or NS.COL.ink
        r.nm:SetTextColor(qc[1], qc[2], qc[3])
        r.nm:SetText(h[2][1])
        r.pr:SetText(h[3] and NS.coin(h[3][1]) or NS.color(NS.COL.muted, "not listed now"))
        r.ch:SetText(h[3] and h[3][5] and NS.pctColored(h[3][5]) or "")
        r:Show()
      end
      res:SetHeight(#hits * 36 + 2)
    end
    res:Show()
  end
  box:SetScript("OnTextChanged", show)
  box:SetScript("OnEditFocusGained", function(self) NS.setBorderColor(self, NS.COL.gold, 0.8) show() end)
  box:SetScript("OnEditFocusLost", function(self) NS.setBorderColor(self, { 0.353, 0.275, 0.125 }, 1) C_Timer.After(0.15, function() if not box:HasFocus() then res:Hide() end end) end)
  box:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() res:Hide() end)
  box:SetScript("OnEnterPressed", function(self)
    if res:IsShown() and res.first then
      local id = res.first
      self:SetText("")
      self:ClearFocus()
      res:Hide()
      NS.OpenItem(id)
    end
  end)
  f.search, f.results = box, res
end

local function buildEmpty(f)
  local e = CreateFrame("Frame", nil, f)
  e:SetPoint("TOPLEFT", 16, -64)
  e:SetPoint("BOTTOMRIGHT", -16, 16)
  NS.fill(e, 0, 0, 0, 0.3):SetAllPoints()
  NS.border(e, { 1, 1, 1 }, 0.06)
  local ic = NS.iconBox(e, 56)
  ic.icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
  ic:SetPoint("CENTER", 0, 70)
  local h = NS.text(e, 26, NS.COL.title, true)
  h:SetPoint("TOP", ic, "BOTTOM", 0, -16)
  h:SetText("No prices yet")
  local p = NS.text(e, 13, NS.COL.ink2)
  p:SetPoint("TOP", h, "BOTTOM", 0, -12)
  p:SetWidth(520)
  p:SetWordWrap(true)
  p:SetJustifyH("CENTER")
  p:SetText("Start the Life on Azeroth companion app on your computer. It downloads the latest auction house prices every hour.\n\nWhen it says new prices are ready, type " .. NS.color(NS.COL.gold, "/reload") .. " or shift-click the coin by your minimap to load them.")
  e:Hide()
  f.emptyState = e
end

local function build()
  local f = CreateFrame("Frame", "LifeOnAzerothMarketFrame", UIParent)
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    NS.db.pos = { p, rp, x, y }
  end)
  if NS.db.pos then
    f:ClearAllPoints()
    f:SetPoint(NS.db.pos[1], UIParent, NS.db.pos[2], NS.db.pos[3], NS.db.pos[4])
  end
  windowFrame(f)
  local kick = NS.text(f, 10, NS.COL.title2)
  kick:SetPoint("TOPLEFT", 18, -12)
  kick:SetText("LIFE ON AZEROTH \194\183 AUCTION HOUSE")
  local title = NS.text(f, 28, NS.COL.title, true)
  title:SetPoint("TOPLEFT", 16, -24)
  title:SetText("The Market")
  rule(f, -56)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() f:Hide() end)
  f.note = NS.text(f, 12, NS.COL.muted)
  f.note:SetPoint("TOPRIGHT", -44, -22)
  f.note:SetJustifyH("RIGHT")
  f.fresh = NS.text(f, 10, NS.COL.muted)
  f.fresh:SetPoint("TOPRIGHT", -44, -38)
  f.fresh:SetJustifyH("RIGHT")
  local rl = CreateFrame("Button", nil, f)
  rl:SetSize(64, 20)
  rl:SetPoint("RIGHT", f.fresh, "LEFT", -10, 0)
  NS.fill(rl, 0.973, 0.827, 0.42, 0.1):SetAllPoints()
  NS.border(rl, NS.COL.gold, 0.35)
  rl.t = NS.text(rl, 10, NS.COL.gold)
  rl.t:SetPoint("CENTER")
  rl.t:SetText("Reload")
  rl:SetScript("OnClick", function() ReloadUI() end)
  rl:SetScript("OnEnter", function(self)
    NS.setBorderColor(self, NS.COL.gold, 0.9)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Reload the interface", NS.COL.title[1], NS.COL.title[2], NS.COL.title[3])
    GameTooltip:AddLine("Loads the newest prices the companion app has downloaded. Same as typing /reload.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  rl:SetScript("OnLeave", function(self) NS.setBorderColor(self, NS.COL.gold, 0.35) GameTooltip:Hide() end)
  buildEmpty(f)
  local body = CreateFrame("Frame", nil, f)
  body:SetAllPoints()
  f.body = body
  buildSearch(body)
  main = f
  f.side = buildSide(body)
  local right = CreateFrame("Frame", nil, body)
  right:SetPoint("TOPLEFT", f.side, "TOPRIGHT", 18, 0)
  right:SetPoint("BOTTOMRIGHT", -16, 16)
  right.chips = {}
  right.hint = NS.text(right, 11, NS.COL.muted)
  right.hint:SetText("Click indexes on the left, or search an item, to compare up to 5.")
  f.ranges = NS.segmented(right, { "6H", "1D", "1W", "1M", "ALL" }, function(k) NS.db.range = k NS.Refresh() end, 36)
  f.ranges:SetPoint("TOPRIGHT", 0, 0)
  right.chart = NS.Chart.New(right)
  right.chart:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 20)
  right.chart:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -40)
  right.foot = NS.text(right, 11, NS.COL.muted)
  right.foot:SetPoint("BOTTOMLEFT", 0, 0)
  f.right = right
  tinsert(UISpecialFrames, "LifeOnAzerothMarketFrame")
  f:SetScript("OnShow", function() NS.Refresh() end)
  f:SetScript("OnHide", function() if NS.CloseItem then NS.CloseItem() end end)
  f:Hide()
  return f
end

function NS.Toggle()
  if not main then build() end
  if main:IsShown() then main:Hide() else main:Show() end
end

function NS.Main() return main end

local function minimapButton()
  local b = CreateFrame("Button", "LifeOnAzerothMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local ov = b:CreateTexture(nil, "OVERLAY")
  ov:SetSize(53, 53)
  ov:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  ov:SetPoint("TOPLEFT")
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)
  local ic = b:CreateTexture(nil, "ARTWORK")
  ic:SetSize(18, 18)
  ic:SetTexture("Interface\\Icons\\INV_Misc_Coin_17")
  ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  ic:SetPoint("TOPLEFT", 7, -6)
  local mask = b:CreateMaskTexture()
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(ic)
  ic:AddMaskTexture(mask)
  local function place()
    local a = math.rad(NS.db.minimap.angle or 200)
    local r = (Minimap:GetWidth() / 2) + 5
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
  end
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      NS.db.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnClick", function() if IsShiftKeyDown() then ReloadUI() else NS.Toggle() end end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Life on Azeroth", NS.COL.title[1], NS.COL.title[2], NS.COL.title[3])
    GameTooltip:AddLine("Click to open The Market.", 1, 1, 1)
    GameTooltip:AddLine("Shift-click to reload and load new prices.", 1, 1, 1)
    local d = LOA_DATA
    if d and d.built then
      GameTooltip:AddLine("Prices " .. NS.ago(d.built) .. ".", NS.COL.muted[1], NS.COL.muted[2], NS.COL.muted[3])
    else
      GameTooltip:AddLine("No prices yet: run the companion app.", NS.COL.muted[1], NS.COL.muted[2], NS.COL.muted[3])
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  place()
  b:SetShown(not NS.db.minimap.hide)
  NS.minimapButton = b
end

function NS.OnLoad()
  minimapButton()
end

SLASH_LIFEONAZEROTH1 = "/market"
SLASH_LIFEONAZEROTH2 = "/loa"
SlashCmdList.LIFEONAZEROTH = function(msg)
  msg = string.lower(msg or "")
  if msg == "minimap" then
    NS.db.minimap.hide = not NS.db.minimap.hide
    if NS.minimapButton then NS.minimapButton:SetShown(not NS.db.minimap.hide) end
    return
  end
  NS.Toggle()
end
