local ADDON, NS = ...

local card, cur

local function box(parent, title)
  local b = CreateFrame("Frame", nil, parent)
  NS.fill(b, 0, 0, 0, 0.3):SetAllPoints()
  NS.border(b, { 1, 1, 1 }, 0.06)
  b.title = NS.text(b, 14, NS.COL.title2, true)
  b.title:SetPoint("TOPLEFT", 12, -10)
  b.title:SetText(title)
  return b
end

local function stat(parent, icon, label)
  local s = CreateFrame("Frame", nil, parent)
  s:SetHeight(52)
  NS.fill(s, 0, 0, 0, 0.3):SetAllPoints()
  NS.border(s, { 1, 1, 1 }, 0.06)
  s.ic = NS.iconBox(s, 30)
  s.ic.icon:SetTexture("Interface\\Icons\\" .. icon)
  s.ic:SetPoint("LEFT", 12, 0)
  s.k = NS.text(s, 10, NS.COL.muted)
  s.k:SetPoint("TOPLEFT", 52, -11)
  s.k:SetText(label)
  s.v = NS.text(s, 14, { 1, 0.949, 0.812 })
  s.v:SetPoint("BOTTOMLEFT", 52, 11)
  return s
end

local function listRow(parent, h)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(h or 30)
  r.bg = NS.fill(r, 1, 1, 1, 0)
  r.bg:SetAllPoints()
  r:SetScript("OnEnter", function(self) if not self.cur then self.bg:SetColorTexture(1, 1, 1, 0.05) end end)
  r:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.973, 0.827, 0.42, self.cur and 0.1 or 0) end)
  return r
end

local made, usedBy

local function recipes()
  if made then return end
  made, usedBy = {}, {}
  for _, s in ipairs(NS.RECIPES or {}) do
    local item, spell, p, skill, icon, rg = string.match(s, "^(%d+) (%d+) (%d+) (%d+) (%d+) (.+)$")
    if item then
      local r = { item = tonumber(item), spell = tonumber(spell), prof = NS.PROFS[tonumber(p) + 1] or "", skill = tonumber(skill), icon = tonumber(icon), reag = {} }
      for rid, n in string.gmatch(rg, "(%d+):(%d+)") do
        rid = tonumber(rid)
        r.reag[#r.reag + 1] = { rid, tonumber(n) }
        usedBy[rid] = usedBy[rid] or {}
        table.insert(usedBy[rid], r)
      end
      if r.item > 0 and (not made[r.item] or r.skill < made[r.item].skill) then made[r.item] = r end
    end
  end
  for _, list in pairs(usedBy) do
    table.sort(list, function(a, b) if a.skill ~= b.skill then return a.skill < b.skill end return a.spell < b.spell end)
  end
end

local function recipeIcon(r)
  if r.item > 0 then return NS.itemIcon(r.item) end
  if r.icon > 0 then return r.icon end
  local get = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
  local ok, ic = pcall(get, r.spell)
  return ok and ic or 134400
end

local function recipeName(r)
  if r.item > 0 then
    local ok, n = pcall(C_Item and C_Item.GetItemNameByID or GetItemInfo, r.item)
    if ok and n then return n end
    return NS.itemName and NS.itemName(r.item) or ("Item " .. r.item)
  end
  local ok, n = pcall(function() return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(r.spell) or GetSpellInfo(r.spell) end)
  return ok and n or ("Recipe " .. r.spell)
end

local function usedTip(owner, list, from)
  local m = NS.COL.muted
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine("Used in", NS.COL.title[1], NS.COL.title[2], NS.COL.title[3])
  local shown = 0
  for i = from or 1, #list do
    if shown == 20 then
      GameTooltip:AddLine("+" .. (#list - i + 1) .. " more", m[1], m[2], m[3])
      break
    end
    local r = list[i]
    GameTooltip:AddDoubleLine(recipeName(r), r.prof .. " " .. r.skill, 1, 1, 1, m[1], m[2], m[3])
    shown = shown + 1
  end
  GameTooltip:Show()
end

local function craftIcon(parent, withCount)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(26, 26)
  b.ic = NS.iconBox(b, 26)
  b.ic:SetAllPoints()
  if withCount then
    b.n = NS.text(b, 10, NS.COL.ink)
    b.n:SetPoint("BOTTOMRIGHT", -1, 2)
    b.n:SetJustifyH("RIGHT")
  end
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local r = self.r
    if r then
      if r.item > 0 then GameTooltip:SetItemByID(r.item) else GameTooltip:SetSpellByID(r.spell) end
      local m = NS.COL.muted
      GameTooltip:AddLine(r.prof .. ", skill " .. r.skill, m[1], m[2], m[3])
    else
      GameTooltip:SetItemByID(self.id)
      if self.price then GameTooltip:AddLine(self.count .. " for " .. NS.coin(self.price), 1, 1, 1) end
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnClick", function(self)
    local id = self.r and self.r.item or self.id
    if id and id > 0 and LOA_DATA and LOA_DATA.cat[id] then NS.OpenItem(id, cur and cur.rg) end
  end)
  return b
end

local GOLD = { 0.788, 0.635, 0.29 }

local function bar(parent)
  local b = CreateFrame("Frame", nil, parent)
  b:SetHeight(5)
  NS.fill(b, 1, 1, 1, 0.07):SetAllPoints()
  b.f = b:CreateTexture(nil, "ARTWORK")
  b.f:SetPoint("TOPLEFT")
  b.f:SetPoint("BOTTOMLEFT")
  b.f:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
  b.p = 0
  function b:Set(p)
    self.p = p or 0
    local w = self:GetWidth()
    if self.p <= 0 or w <= 0 then self.f:Hide() return end
    self.f:SetWidth(math.max(1, w * self.p))
    self.f:Show()
  end
  b:SetScript("OnSizeChanged", function(self) self:Set(self.p) end)
  return b
end

function NS.SellBox(parent)
  local b = box(parent, "Does it sell?")
  b.sub = NS.text(b, 10, NS.COL.muted)
  b.sub:SetPoint("LEFT", b.title, "RIGHT", 6, -1)
  b.sub:SetText("last 7 days")
  b.ovL = NS.text(b, 12, NS.COL.ink)
  b.ovL:SetPoint("TOPLEFT", 12, -34)
  b.ovL:SetText("Overall")
  b.ovP = NS.text(b, 13, NS.COL.ink)
  b.ovP:SetPoint("TOPRIGHT", -12, -33)
  b.ovB = bar(b)
  b.ovB:SetPoint("TOPLEFT", 12, -50)
  b.ovB:SetPoint("TOPRIGHT", -12, -50)
  b.ovN = NS.text(b, 10, NS.COL.muted)
  b.ovN:SetPoint("TOPLEFT", 12, -60)
  b.hL = NS.text(b, 9, NS.COL.muted)
  b.hL:SetPoint("TOPLEFT", 12, -80)
  b.hL:SetText("LISTED AT")
  b.hR = NS.text(b, 9, NS.COL.muted)
  b.hR:SetPoint("TOPRIGHT", -12, -80)
  b.hR:SetText("SOLD")
  b.rows = {}
  for k = 1, #NS.STEPN do
    local y = -94 - (k - 1) * 16
    local r = { y = y }
    r.l = NS.text(b, 11, NS.COL.ink)
    r.l:SetPoint("TOPLEFT", 12, y)
    r.b = bar(b)
    r.p = NS.text(b, 11, NS.COL.ink)
    r.p:SetPoint("TOPRIGHT", -62, y)
    r.p:SetJustifyH("RIGHT")
    r.n = NS.text(b, 10, NS.COL.muted)
    r.n:SetPoint("TOPRIGHT", -12, y)
    r.n:SetJustifyH("RIGHT")
    b.rows[k] = r
  end
  b.mid = NS.text(b, 11, NS.COL.ink)
  b.mid:SetWordWrap(true)
  b.mid:SetJustifyV("TOP")
  b.none = NS.text(b, 11, NS.COL.muted)
  b.none:SetPoint("TOPLEFT", 12, -36)
  b.none:SetPoint("RIGHT", -12, 0)
  b.none:SetWordWrap(true)
  b.none:SetText("No auctions of this have ended here yet.")
  b:SetHeight(94 + #NS.STEPN * 16 + 34)
  function b:Fill(sc, mine)
    local S = #NS.STEPN
    local n = sc and (sc[1] + sc[2] + sc[3] + sc[4]) or 0
    for _, x in ipairs({ self.ovL, self.ovP, self.ovB, self.ovN, self.hL, self.hR, self.mid }) do x:SetShown(n > 0) end
    self.none:SetShown(n == 0)
    for _, r in ipairs(self.rows) do r.l:Hide() r.b:Hide() r.p:Hide() r.n:Hide() end
    if n == 0 then return end
    local s0 = sc[1] + sc[2]
    self.ovP:SetText(math.floor(100 * s0 / n + 0.5) .. "%")
    self.ovB:Set(s0 / n)
    self.ovN:SetText(NS.fmt(s0) .. " of " .. NS.fmt(n) .. " sold")
    local ladder = 0
    for k = 1, 2 * S do ladder = ladder + (sc[4 + k] or 0) end
    local lines = {}
    if ladder > 0 then
      for k = 1, S do lines[k] = { NS.STEPN[k], sc[4 + k] or 0, sc[4 + S + k] or 0, k == mine } end
    else
      lines = { { "At or below typical", sc[1], sc[3], mine ~= nil and mine <= 3 }, { "Above typical", sc[2], sc[4], mine ~= nil and mine > 3 } }
    end
    local lw = ladder > 0 and 74 or 130
    for k, ln in ipairs(lines) do
      local r = self.rows[k]
      local m = ln[2] + ln[3]
      local c = ln[4] and NS.COL.title or (m > 0 and NS.COL.ink or NS.COL.muted)
      r.l:SetText(ln[1])
      r.l:SetTextColor(c[1], c[2], c[3])
      r.b:ClearAllPoints()
      r.b:SetPoint("TOPLEFT", 12 + lw, r.y - 4)
      r.b:SetPoint("TOPRIGHT", -104, r.y - 4)
      r.b:Set(m > 0 and ln[2] / m or 0)
      r.p:SetText(m > 0 and (math.floor(100 * ln[2] / m + 0.5) .. "%") or "\226\128\147")
      r.n:SetText(m > 0 and (NS.fmt(ln[2]) .. "/" .. NS.fmt(m)) or "")
      r.l:Show() r.b:Show() r.p:Show() r.n:Show()
    end
    self.hL:SetShown(ladder > 0)
    self.hR:SetShown(ladder > 0)
    local nA, nB = sc[1] + sc[3], sc[2] + sc[4]
    if nA > 0 and nB > 0 then
      local pa, pb = math.floor(100 * sc[1] / nA + 0.5), math.floor(100 * sc[2] / nB + 0.5)
      local d = pa - pb
      self.mid:SetText("Priced above typical, it sells " .. NS.color(NS.COL.title, d > 0 and (d .. " points less often") or "just as often") .. " (" .. pb .. "% vs " .. pa .. "%).")
      self.mid:ClearAllPoints()
      self.mid:SetPoint("TOPLEFT", 12, -94 - #lines * 16 - 2)
      self.mid:SetPoint("TOPRIGHT", -12, -94 - #lines * 16 - 2)
      self.mid:Show()
    else
      self.mid:Hide()
    end
  end
  return b
end

local function build()
  local main = NS.Main()
  local ov = CreateFrame("Button", nil, main)
  ov:SetAllPoints()
  ov:SetFrameLevel(main:GetFrameLevel() + 60)
  NS.fill(ov, 0.02, 0.016, 0.008, 0.82):SetAllPoints()
  ov:SetScript("OnClick", function() NS.CloseItem() end)
  local c = CreateFrame("Frame", nil, ov)
  c:SetPoint("TOPLEFT", 26, -26)
  c:SetPoint("BOTTOMRIGHT", -26, 26)
  c:EnableMouse(true)
  NS.fill(c, 0.078, 0.06, 0.039, 1, "BACKGROUND", -8):SetAllPoints()
  NS.border(c, { 0.478, 0.353, 0.102 }, 1)
  local close = CreateFrame("Button", nil, c, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() NS.CloseItem() end)

  local hero = CreateFrame("Frame", nil, c)
  hero:SetPoint("TOPLEFT")
  hero:SetPoint("TOPRIGHT")
  hero:SetHeight(112)
  c.heroGlow = hero:CreateTexture(nil, "BACKGROUND")
  c.heroGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
  c.heroGlow:SetAllPoints()
  c.heroLine = hero:CreateTexture(nil, "ARTWORK")
  c.heroLine:SetTexture("Interface\\Buttons\\WHITE8X8")
  c.heroLine:SetPoint("BOTTOMLEFT")
  c.heroLine:SetPoint("BOTTOMRIGHT")
  c.heroLine:SetHeight(2)
  local frameIc = CreateFrame("Button", nil, hero)
  frameIc:SetSize(76, 76)
  frameIc:SetPoint("LEFT", 22, 0)
  local g = frameIc:CreateTexture(nil, "BACKGROUND")
  g:SetTexture("Interface\\Buttons\\WHITE8X8")
  g:SetAllPoints()
  g:SetGradient("VERTICAL", CreateColor(0.165, 0.118, 0.043, 1), CreateColor(0.902, 0.753, 0.416, 1))
  c.icon = NS.iconBox(frameIc, 70)
  c.icon:SetPoint("CENTER")
  frameIc:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(cur.id)
    GameTooltip:Show()
  end)
  frameIc:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frameIc:SetScript("OnClick", function()
    if IsModifiedClick("CHATLINK") then
      local _, link = GetItemInfo(cur.id)
      if link then ChatEdit_InsertLink(link) end
    end
  end)
  c.name = NS.text(hero, 22, NS.COL.ink)
  c.name:SetPoint("TOPLEFT", frameIc, "TOPRIGHT", 18, -10)
  c.name:SetWidth(480)
  c.chips = {}
  for i = 1, 3 do
    local ch = CreateFrame("Frame", nil, hero)
    ch:SetHeight(22)
    NS.fill(ch, 0, 0, 0, 0.4):SetAllPoints()
    NS.border(ch, { 1, 1, 1 }, 0.08)
    ch.t = NS.text(ch, 11, NS.COL.ink2)
    ch.t:SetPoint("CENTER")
    c.chips[i] = ch
  end
  c.pxLabel = NS.text(hero, 10, NS.COL.muted)
  c.pxLabel:SetPoint("TOPRIGHT", -54, -18)
  c.pxLabel:SetJustifyH("RIGHT")
  local hint = CreateFrame("Frame", nil, hero)
  hint:SetPoint("TOPRIGHT", -54, -14)
  hint:SetSize(240, 40)
  hint:EnableMouse(true)
  hint:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine("Typical price", NS.COL.title[1], NS.COL.title[2], NS.COL.title[3])
    GameTooltip:AddLine("The middle price per item of everything listed right now: half the listings are cheaper, half are dearer. A few silly prices barely move it.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  hint:SetScript("OnLeave", function() GameTooltip:Hide() end)
  c.px = NS.text(hero, 20, { 1, 0.949, 0.812 })
  c.px:SetPoint("TOPRIGHT", -54, -36)
  c.px:SetJustifyH("RIGHT")
  c.pill = NS.text(hero, 11, NS.COL.ink2)
  c.pill:SetPoint("TOPRIGHT", -54, -62)
  c.pill:SetJustifyH("RIGHT")
  local add = CreateFrame("Button", nil, hero)
  add:SetSize(118, 24)
  add:SetPoint("TOPRIGHT", -54, -80)
  NS.fill(add, 0.973, 0.827, 0.42, 0.14):SetAllPoints()
  NS.border(add, NS.COL.gold, 0.45)
  add.t = NS.text(add, 11, NS.COL.gold)
  add.t:SetPoint("CENTER")
  add.t:SetText("+ Add to chart")
  add:SetScript("OnEnter", function(self) NS.setBorderColor(self, NS.COL.gold, 0.9) end)
  add:SetScript("OnLeave", function(self) NS.setBorderColor(self, NS.COL.gold, 0.45) end)
  add:SetScript("OnClick", function()
    local id = cur.id
    NS.CloseItem()
    NS.AddSeries({ kind = "item", id = id })
  end)
  c.add = add

  local stats = CreateFrame("Frame", nil, c)
  stats:SetPoint("TOPLEFT", 20, -126)
  stats:SetPoint("TOPRIGHT", -20, -126)
  stats:SetHeight(52)
  c.stats = {
    stat(stats, "INV_Misc_Coin_02", "Cheapest now"),
    stat(stats, "INV_Misc_Ticket_Tarot_Stack_01", "Auctions"),
    stat(stats, "INV_Misc_Bag_10", "Items for sale"),
    stat(stats, "INV_Misc_Coin_17", "Vendor pays"),
    stat(stats, "INV_Misc_PocketWatch_01", "Sold per day"),
  }
  stats:SetScript("OnSizeChanged", function(self, w)
    local sw = (w - 10 * (#c.stats - 1)) / #c.stats
    for i, s in ipairs(c.stats) do
      s:ClearAllPoints()
      s:SetPoint("TOPLEFT", (i - 1) * (sw + 10), 0)
      s:SetWidth(sw)
    end
  end)

  local left = CreateFrame("Frame", nil, c)
  left:SetPoint("TOPLEFT", 20, -192)
  left:SetPoint("BOTTOMRIGHT", -350, 18)
  local ht = NS.text(left, 16, NS.COL.title2, true)
  ht:SetPoint("TOPLEFT", 0, 0)
  ht:SetText("Price history")
  c.ranges = NS.segmented(left, { "6H", "1D", "1W", "1M", "ALL" }, function(k) NS.db.range = k NS.DrawItem() end, 34)
  c.ranges:SetPoint("TOPRIGHT", 0, 2)
  local k1 = left:CreateTexture(nil, "ARTWORK")
  k1:SetSize(10, 3)
  k1:SetPoint("TOPLEFT", 2, -30)
  c.k1 = k1
  local k1t = NS.text(left, 11, NS.COL.ink2)
  k1t:SetPoint("LEFT", k1, "RIGHT", 6, 0)
  k1t:SetText("Typical price")
  local k2 = left:CreateTexture(nil, "ARTWORK")
  k2:SetSize(10, 3)
  k2:SetPoint("LEFT", k1t, "RIGHT", 16, 0)
  k2:SetColorTexture(0.604, 0.639, 0.678, 1)
  local k2t = NS.text(left, 11, NS.COL.ink2)
  k2t:SetPoint("LEFT", k2, "RIGHT", 6, 0)
  k2t:SetText("Cheapest listing")
  c.chart = NS.Chart.New(left)
  c.chart:SetPoint("TOPLEFT", 0, -42)
  c.chart:SetPoint("BOTTOMRIGHT", 0, 78)
  local vl = NS.text(left, 10, NS.COL.muted)
  vl:SetPoint("BOTTOMLEFT", 0, 62)
  vl:SetText("Items for sale each hour")
  c.vol = CreateFrame("Frame", nil, left)
  c.vol:SetPoint("BOTTOMLEFT", 8, 4)
  c.vol:SetPoint("BOTTOMRIGHT", -64, 4)
  c.vol:SetHeight(54)
  c.vol.bars = {}
  c.vol.peak = NS.text(c.vol, 9, NS.COL.ink2)

  local right = CreateFrame("Frame", nil, c)
  right:SetPoint("TOPLEFT", c, "TOPRIGHT", -330, -192)
  right:SetPoint("BOTTOMRIGHT", -20, 18)
  local sellBox = NS.SellBox(right)
  sellBox:SetPoint("TOPLEFT")
  sellBox:SetPoint("TOPRIGHT")
  c.sell = sellBox
  local craft = box(right, "")
  craft:SetPoint("TOPLEFT", sellBox, "BOTTOMLEFT", 0, -12)
  craft:SetPoint("BOTTOMRIGHT")
  craft.title:SetPoint("TOPRIGHT", -12, -10)
  craft.reag = {}
  for i = 1, 9 do craft.reag[i] = craftIcon(craft, true) end
  craft.mat = NS.text(craft, 11, NS.COL.ink2)
  craft.mat:SetPoint("TOPLEFT", 12, -66)
  craft.profit = NS.text(craft, 11, NS.COL.ink2)
  craft.profit:SetPoint("TOPRIGHT", -12, -66)
  craft.profit:SetJustifyH("RIGHT")
  craft.uhead = CreateFrame("Frame", nil, craft)
  craft.uhead:SetHeight(20)
  craft.uhead:EnableMouse(true)
  craft.uhead:SetPoint("LEFT", 12, 0)
  craft.uhead:SetPoint("RIGHT", -12, 0)
  craft.ut = NS.text(craft.uhead, 14, NS.COL.title2, true)
  craft.ut:SetPoint("LEFT")
  craft.us = NS.text(craft.uhead, 10, NS.COL.muted)
  craft.us:SetPoint("LEFT", craft.ut, "RIGHT", 6, -1)
  craft.us:SetPoint("RIGHT")
  craft.uhead:SetScript("OnEnter", function(self) if self.list then usedTip(self, self.list, 1) end end)
  craft.uhead:SetScript("OnLeave", function() GameTooltip:Hide() end)
  craft.used = {}
  for i = 1, 27 do craft.used[i] = craftIcon(craft) end
  craft.more = CreateFrame("Frame", nil, craft)
  craft.more:SetSize(26, 26)
  craft.more:EnableMouse(true)
  NS.fill(craft.more, 1, 1, 1, 0.06):SetAllPoints()
  NS.border(craft.more, NS.COL.frameDim, 1)
  craft.more.t = NS.text(craft.more, 11, NS.COL.ink2)
  craft.more.t:SetPoint("CENTER")
  craft.more:SetScript("OnEnter", function(self) usedTip(self, self.list, self.from) end)
  craft.more:SetScript("OnLeave", function() GameTooltip:Hide() end)
  c.craft = craft
  local kin = box(right, "Similar on the auction house")
  kin:SetPoint("TOPLEFT", sellBox, "BOTTOMLEFT", 0, -12)
  kin:SetPoint("BOTTOMRIGHT")
  kin.rows = {}
  for i = 1, 6 do
    local r = listRow(kin, 30)
    r:SetPoint("TOPLEFT", 6, -32 - (i - 1) * 31)
    r:SetPoint("TOPRIGHT", -6, -32 - (i - 1) * 31)
    r.ic = NS.iconBox(r, 22)
    r.ic:SetPoint("LEFT", 6, 0)
    r.nm = NS.text(r, 12, NS.COL.ink)
    r.nm:SetPoint("LEFT", 36, 0)
    r.nm:SetWidth(160)
    r.pr = NS.text(r, 11, NS.COL.ink)
    r.pr:SetPoint("RIGHT", -8, 0)
    r.pr:SetJustifyH("RIGHT")
    r:SetScript("OnClick", function(self) NS.OpenItem(self.id, cur.rg) end)
    kin.rows[i] = r
  end
  kin.none = NS.text(kin, 11, NS.COL.muted)
  kin.none:SetPoint("TOPLEFT", 12, -36)
  kin.none:SetText("Nothing similar listed right now.")
  c.kin = kin
  card = ov
  card.c = c
  ov:Hide()
end

function NS.DrawItem()
  if not cur or not card then return end
  local c = card.c
  local h = NS.hist(cur.id)
  local cat = LOA_DATA.cat[cur.id]
  local qc = cat and cat[2] >= 2 and NS.QC[cat[2]] or NS.COL.gold
  local span = NS.rangeSpan(NS.db.range)
  c.ranges:Select(NS.db.range)
  c.k1:SetColorTexture(qc[1], qc[2], qc[3], 1)
  local t = LOA_DATA.ht or {}
  local _, rs = NS.view()
  local list = {}
  local function count(v) local n = 0 for i = 1, #v do if v[i] then n = n + 1 end end return n end
  if h and count(h.med) >= 2 then list[#list + 1] = { name = "Typical price", t = t, v = h.med, unit = "coin", color = qc } end
  local mins = {}
  if h then
    for i = 1, #h.min do
      local mn, md = h.min[i], h.med[i]
      mins[i] = (mn and md and mn > md) and md or mn
    end
  end
  if h and count(mins) >= 2 then list[#list + 1] = { name = "Cheapest", t = t, v = mins, unit = "coin", color = { 0.604, 0.639, 0.678 } } end
  local V = NS.view()
  if cur.rg ~= LOA_DATA.region then
    list = {}
  end
  local empty
  if cur.rg ~= LOA_DATA.region then
    empty = "Price history is downloaded for " .. (NS.REGION_NAME[LOA_DATA.region] or "your region") .. " only. Pick another region in the companion app to see its history."
  elseif rs and V.nohist then
    empty = "Price history for the " .. NS.houseName(rs) .. " auction house is only downloaded for houses you play on. Log in there and it is added with the next update."
  end
  c.chart:Draw(list, { span = span, abs = true, fill = true, emptyText = empty })
  local vol = c.vol
  for _, b in ipairs(vol.bars) do b:Hide() end
  vol.peak:Hide()
  local q = h and cur.rg == LOA_DATA.region and h.qty or {}
  local tmax = t[#t] or 0
  local pts = {}
  for i = 1, #q do
    if t[i] and t[i] >= tmax - (span == 0 and 30 * 86400 or math.min(span, 30 * 86400)) then pts[#pts + 1] = q[i] or 0 end
  end
  if #pts > 0 then
    local mx, pk = 1, 1
    for i, x in ipairs(pts) do if x > mx then mx, pk = x, i end end
    local w = vol:GetWidth()
    local bw = w / #pts
    for i, x in ipairs(pts) do
      local b = vol.bars[i]
      if not b then b = vol:CreateTexture(nil, "ARTWORK") vol.bars[i] = b end
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", (i - 1) * bw, 0)
      b:SetSize(math.max(1, bw - (bw > 3 and 1 or 0)), math.max(2, 54 * x / mx))
      if i == pk then b:SetColorTexture(0.973, 0.827, 0.42, 0.85) else b:SetColorTexture(0.788, 0.725, 0.604, 0.35) end
      b:Show()
    end
    vol.peak:ClearAllPoints()
    vol.peak:SetPoint("BOTTOM", vol, "BOTTOMLEFT", (pk - 0.5) * bw, math.max(2, 54 * mx / mx) + 2)
    vol.peak:SetText(NS.fmt(mx))
    vol.peak:Show()
  end
end

function NS.OpenItem(id, rg)
  if not LOA_DATA or not LOA_DATA.cat[id] then return end
  if not card then build() end
  rg = rg or LOA_DATA.region
  cur = { id = id, rg = rg }
  local c = card.c
  local cat = LOA_DATA.cat[id]
  local q = cat[2] or 1
  local qc = NS.QC[q] or NS.QC[1]
  c.heroGlow:SetGradient("HORIZONTAL", CreateColor(qc[1], qc[2], qc[3], 0.1), CreateColor(qc[1], qc[2], qc[3], 0))
  c.heroLine:SetGradient("HORIZONTAL", CreateColor(qc[1], qc[2], qc[3], 0.7), CreateColor(qc[1], qc[2], qc[3], 0))
  c.icon.icon:SetTexture(NS.itemIcon(id))
  c.icon:SetQuality(q)
  c.name:SetText(cat[1])
  c.name:SetTextColor(qc[1], qc[2], qc[3])
  local chips = { NS.CLASS[cat[4]] or "Item" }
  if cat[8] and cat[8] > 0 then chips[#chips + 1] = "Item level " .. cat[8] end
  if cat[6] and cat[6] > 0 then chips[#chips + 1] = "Requires level " .. cat[6] end
  local x = 0
  for i, ch in ipairs(c.chips) do
    if chips[i] then
      ch.t:SetText(chips[i])
      ch:SetWidth(ch.t:GetStringWidth() + 18)
      ch:ClearAllPoints()
      ch:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", x, -10)
      x = x + ch:GetWidth() + 6
      ch:Show()
    else
      ch:Hide()
    end
  end
  local l = NS.latest(rg, id)
  local _, rsName = NS.view()
  c.pxLabel:SetText("Typical price \194\183 " .. (rsName and rg == LOA_DATA.region and (NS.houseName(rsName) .. " auction house") or (NS.REGION_NAME[rg] or rg)))
  c.px:SetText(l and NS.coin(l[1]) or NS.color(NS.COL.muted, "Not listed right now"))
  c.pill:SetText(l and l[5] and (NS.pctColored(l[5]) .. NS.color(NS.COL.muted, "  24h")) or "")
  c.add:SetShown(rg == LOA_DATA.region and NS.hist(id) ~= nil)
  c.stats[1].v:SetText(l and NS.coin(math.min(l[2] > 0 and l[2] or l[1], l[1])) or "\226\128\147")
  c.stats[2].v:SetText(l and NS.fmt(l[4]) or "0")
  c.stats[3].v:SetText(l and NS.fmt(l[3]) or "0")
  local okS, _, _, _, _, _, _, _, _, _, _, sell = pcall(GetItemInfo, id)
  if not okS or type(sell) ~= "number" then sell = cat[7] end
  c.stats[4].v:SetText(sell and sell > 0 and NS.coin(sell) or "\226\128\147")
  local okF, perDay, _, sales = false
  if rg == LOA_DATA.region then okF, perDay, _, sales = pcall(NS.Value.flow, id) end
  if not okF then perDay = nil end
  c.stats[5].k:SetText(perDay and not sales and "Left the AH per day" or "Sold per day")
  c.stats[5].v:SetText(perDay and (perDay >= 10 and NS.fmt(math.floor(perDay + 0.5)) or string.format("%.1f", perDay)) or "\226\128\147")
  local sc = rg == LOA_DATA.region and NS.sellCounts(id) or nil
  local mine
  if l and l[1] > 0 then mine = NS.stepOf(math.min(l[2] > 0 and l[2] or l[1], l[1]) / l[1]) end
  c.sell.sub:SetText(rg == LOA_DATA.region and "last 7 days" or ("downloaded for " .. (NS.REGION_NAME[LOA_DATA.region] or "your region") .. " only"))
  c.sell:Fill(sc, mine)

  card:Show()
  recipes()
  local cr = c.craft
  local mk, ul = made[id], usedBy[id]
  local y = 0
  for _, b in ipairs(cr.reag) do b:Hide() end
  for _, b in ipairs(cr.used) do b:Hide() end
  cr.more:Hide()
  cr.mat:SetShown(mk ~= nil)
  cr.profit:SetShown(mk ~= nil)
  cr.title:SetShown(mk ~= nil)
  if mk then
    cr.title:SetText("Made by " .. mk.prof .. "  " .. NS.color(NS.COL.muted, "skill " .. mk.skill))
    local cost, known = 0, true
    for i, g in ipairs(mk.reag) do
      local b = cr.reag[i]
      if b then
        local gl = NS.latest(rg, g[1])
        b.id, b.r, b.count = g[1], nil, g[2]
        b.price = gl and gl[1] > 0 and gl[1] * g[2] or nil
        b.ic.icon:SetTexture(NS.itemIcon(g[1]))
        local gc = LOA_DATA.cat[g[1]]
        b.ic:SetQuality(gc and gc[2])
        b.n:SetText(g[2] > 1 and g[2] or "")
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 12 + (i - 1) * 30, -32)
        b:Show()
      end
      if b and b.price then cost = cost + b.price else known = false end
    end
    cr.mat:SetText("Materials  " .. (known and NS.coin(cost) or NS.color(NS.COL.muted, "some not listed")))
    local margin = l and l[1] > 0 and known and (l[1] - cost) or nil
    if margin then
      local col = margin >= 0 and NS.COL.up or NS.COL.dn
      cr.profit:SetText(NS.color(col, margin >= 0 and "Profit " or "Loss ") .. NS.coin(math.abs(margin)))
    else
      cr.profit:SetText("")
    end
    y = 80
  end
  cr.uhead:SetShown(ul ~= nil)
  cr.uhead.list = ul
  if ul then
    local profs, order = {}, {}
    for _, r in ipairs(ul) do
      if not profs[r.prof] then profs[r.prof] = 0 order[#order + 1] = r.prof end
      profs[r.prof] = profs[r.prof] + 1
    end
    table.sort(order, function(a, b) return profs[a] > profs[b] end)
    local parts = {}
    for _, p in ipairs(order) do parts[#parts + 1] = p .. " " .. profs[p] end
    cr.ut:SetText("Used in " .. #ul .. (#ul == 1 and " recipe" or " recipes"))
    cr.us:SetText(table.concat(parts, " \194\183 "))
    cr.uhead:ClearAllPoints()
    cr.uhead:SetPoint("TOPLEFT", 12, -y - 8)
    cr.uhead:SetPoint("TOPRIGHT", -12, -y - 8)
    card:Show()
    local rows = math.floor((cr:GetHeight() - y - 32 - 6 + 4) / 30)
    local slots = math.max(0, math.min(rows * 9, #cr.used))
    local n = #ul > slots and slots - 1 or #ul
    for i = 1, math.max(0, n) do
      local b, r = cr.used[i], ul[i]
      b.r, b.id, b.price = r, nil, nil
      b.ic.icon:SetTexture(recipeIcon(r))
      local rc = r.item > 0 and LOA_DATA.cat[r.item]
      b.ic:SetQuality(rc and rc[2])
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 12 + ((i - 1) % 9) * 30, -y - 32 - math.floor((i - 1) / 9) * 30)
      b:Show()
    end
    if #ul > slots and slots > 0 then
      cr.more.list, cr.more.from = ul, n + 1
      cr.more.t:SetText("+" .. (#ul - n))
      cr.more:ClearAllPoints()
      cr.more:SetPoint("TOPLEFT", 12 + (n % 9) * 30, -y - 32 - math.floor(n / 9) * 30)
      cr.more:Show()
    end
  end
  cr:SetShown(mk ~= nil or ul ~= nil)

  local L = (rg == LOA_DATA.region and NS.view().lat) or LOA_DATA.lat[rg] or {}
  local kin = {}
  for oid, oc in pairs(LOA_DATA.cat) do
    if oid ~= id and oc[4] == cat[4] and oc[5] == cat[5] and L[oid] then
      kin[#kin + 1] = { oid, oc, math.abs((oc[8] or 0) - (cat[8] or 0)) * 1000 - (L[oid][4] or 0) }
    end
  end
  table.sort(kin, function(a, b) if a[3] ~= b[3] then return a[3] < b[3] end return a[1] < b[1] end)
  card:Show()
  local fit = math.floor((c.kin:GetHeight() - 38) / 31)
  c.kin:SetShown(fit >= 1 and not c.craft:IsShown())
  for j, row in ipairs(c.kin.rows) do
    local k = j <= fit and not c.craft:IsShown() and kin[j]
    if k then
      row.id = k[1]
      row.ic.icon:SetTexture(NS.itemIcon(k[1]))
      row.ic:SetQuality(k[2][2])
      local kc = NS.QC[k[2][2]] or NS.COL.ink
      row.nm:SetTextColor(kc[1], kc[2], kc[3])
      row.nm:SetText(k[2][1])
      row.pr:SetText(NS.coin(L[k[1]][1]))
      row:Show()
    else
      row:Hide()
    end
  end
  c.kin.none:SetShown(#kin == 0)
  NS.DrawItem()
end

function NS.CloseItem()
  if card then card:Hide() end
  cur = nil
end
