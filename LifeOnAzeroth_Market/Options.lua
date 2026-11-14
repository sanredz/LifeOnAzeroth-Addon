local ADDON, NS = ...

NS.ITEM_COLS = {
  { key = "qty", label = "QTY" },
  { key = "net", label = "SELLS FOR" },
  { key = "vendor", label = "VENDOR" },
  { key = "perDay", label = "SOLD/DAY" },
  { key = "sellRate", label = "SELL CHANCE" },
  { key = "total", label = "WORTH" },
  { key = "gain", label = "GAIN VS VENDOR" },
  { key = "pick", label = "BEST" },
}

local COLBY = {}
for _, c in ipairs(NS.ITEM_COLS) do COLBY[c.key] = c end

function NS.colConf()
  local c = NS.db.itemCols
  if type(c) ~= "table" then c = {} NS.db.itemCols = c end
  c.off = type(c.off) == "table" and c.off or {}
  local seen, order = {}, {}
  for _, k in ipairs(type(c.order) == "table" and c.order or {}) do
    if COLBY[k] and not seen[k] then seen[k] = true order[#order + 1] = k end
  end
  for _, x in ipairs(NS.ITEM_COLS) do
    if not seen[x.key] then order[#order + 1] = x.key end
  end
  c.order = order
  return c
end

function NS.LayoutItemCols(L, showOn, W)
  local conf = NS.colConf()
  local by = {}
  for _, c in ipairs(L.cols) do
    c.base = c.base or c.w
    by[c.key] = c
  end
  local gap = 6
  local item, on = by.item, by.on
  on.hidden = not showOn
  local seq = {}
  for _, k in ipairs(conf.order) do
    local c = by[k]
    if c then
      c.hidden = conf.off[k] and true or false
      if not c.hidden then seq[#seq + 1] = c end
    end
  end
  local need = 0
  for _, c in ipairs(seq) do need = need + c.base + gap end
  if showOn then need = need + on.base + gap end
  local itemW = math.max(item.base, math.min(item.base + 220, W - 20 - need))
  item.x, item.w = 8, itemW
  local x = 8 + itemW + gap
  if showOn then
    on.x, on.w = x, on.base
    x = x + on.base + gap
  end
  for _, c in ipairs(seq) do
    c.x, c.w = x, c.base
    x = x + c.base + gap
  end
  L:Layout()
end

local function changed(what)
  if what == "cols" and NS.PaintViews and NS.Main and NS.Main() and NS.Main():IsShown() then pcall(NS.PaintViews) end
  for _, p in ipairs(NS.custPanels or {}) do
    if p:IsVisible() then p:Repaint(what) end
  end
end

local function check(parent, size)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size or 16, size or 16)
  NS.fill(b, 0, 0, 0, 0.5):SetAllPoints()
  NS.border(b, NS.COL.frame, 1)
  b.mark = b:CreateTexture(nil, "OVERLAY")
  b.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  b.mark:SetPoint("CENTER", 1, 0)
  b.mark:SetSize((size or 16) + 6, (size or 16) + 6)
  function b:SetOn(on)
    self.mark:SetShown(on)
    NS.setBorderColor(self, on and NS.COL.gold or NS.COL.frame, on and 0.8 or 1)
  end
  return b
end

local function grip(parent)
  local g = CreateFrame("Frame", nil, parent)
  g:SetSize(10, 12)
  for i = 0, 2 do
    for j = 0, 1 do
      local t = g:CreateTexture(nil, "ARTWORK")
      t:SetColorTexture(NS.COL.muted[1], NS.COL.muted[2], NS.COL.muted[3], 0.9)
      t:SetSize(2, 2)
      t:SetPoint("TOPLEFT", j * 5 + 1, -i * 5 - 1)
    end
  end
  return g
end

local function cursorIn(frame)
  local cx, cy = GetCursorPosition()
  local s = frame:GetEffectiveScale()
  return cx / s - frame:GetLeft(), frame:GetTop() - cy / s
end

local function sorter(parent, opt)
  local S = CreateFrame("Frame", nil, parent)
  S.items, S.gap, S.rowGap = {}, opt.gap or 6, opt.rowGap or 6
  local function flow(order, dragKey, dragAt)
    local list = {}
    for _, k in ipairs(order) do if k ~= dragKey then list[#list + 1] = k end end
    if dragKey then table.insert(list, math.min(dragAt, #list + 1), dragKey) end
    local maxW = S:GetWidth()
    local x, y, lineH, pos = 0, 0, 0, {}
    for _, k in ipairs(list) do
      local it = S.items[k]
      local w, h = it:GetWidth(), it:GetHeight()
      if x > 0 and x + w > maxW then x, y, lineH = 0, y + lineH + S.rowGap, 0 end
      pos[k] = { x, y }
      x = x + w + S.gap
      lineH = math.max(lineH, h)
    end
    return pos, y + lineH
  end
  local function animate()
    S:SetScript("OnUpdate", function(self, el)
      local busy = false
      local f = math.min(1, el * 16)
      for k, it in pairs(self.items) do
        if k ~= self.dragKey and it.tx then
          local nx, ny = it.cx + (it.tx - it.cx) * f, it.cy + (it.ty - it.cy) * f
          if math.abs(it.tx - nx) < 0.5 and math.abs(it.ty - ny) < 0.5 then nx, ny = it.tx, it.ty else busy = true end
          it.cx, it.cy = nx, ny
          it:ClearAllPoints()
          it:SetPoint("TOPLEFT", nx, -ny)
        end
      end
      if self.dragKey then
        local it = self.items[self.dragKey]
        local mx, my = cursorIn(self)
        local px, py = mx - it.grabX, my - it.grabY
        it:ClearAllPoints()
        it:SetPoint("TOPLEFT", px, -py)
        local best, bestD = self.dragAt, math.huge
        for t = 1, #self.order do
          local pos = flow(self.order, self.dragKey, t)
          local p = pos[self.dragKey]
          local d = (p[1] - px) ^ 2 + (p[2] - py) ^ 2
          if d < bestD then best, bestD = t, d end
        end
        if best ~= self.dragAt then
          self.dragAt = best
          local pos = flow(self.order, self.dragKey, best)
          for k, q in pairs(pos) do self.items[k].tx, self.items[k].ty = q[1], q[2] end
          local ph = pos[self.dragKey]
          self.slot:ClearAllPoints()
          self.slot:SetPoint("TOPLEFT", ph[1], -ph[2])
        end
        busy = true
      end
      if not busy then self:SetScript("OnUpdate", nil) end
    end)
  end
  function S:Place(snap)
    local pos, h = flow(self.order)
    for k, p in pairs(pos) do
      local it = self.items[k]
      it.tx, it.ty = p[1], p[2]
      if snap or not it.cx then
        it.cx, it.cy = p[1], p[2]
        it:ClearAllPoints()
        it:SetPoint("TOPLEFT", p[1], -p[2])
      end
    end
    self:SetHeight(math.max(1, h))
    if not snap then animate() end
  end
  S.slot = CreateFrame("Frame", nil, S)
  NS.fill(S.slot, NS.COL.gold[1], NS.COL.gold[2], NS.COL.gold[3], 0.08):SetAllPoints()
  NS.border(S.slot, NS.COL.gold, 0.5)
  S.slot:Hide()
  function S:Build(defs)
    for _, d in ipairs(defs) do
      local it = opt.make(self, d)
      it.key = d.key
      it:RegisterForDrag("LeftButton")
      it:SetScript("OnDragStart", function(b)
        local mx, my = cursorIn(self)
        b.grabX, b.grabY = mx - (b.cx or 0), my - (b.cy or 0)
        b.dragging = true
        self.dragKey, self.dragAt = b.key, 1
        for i, k in ipairs(self.order) do if k == b.key then self.dragAt = i end end
        b:SetFrameLevel(self:GetFrameLevel() + 20)
        self.slot:SetSize(b:GetWidth(), b:GetHeight())
        self.slot:ClearAllPoints()
        self.slot:SetPoint("TOPLEFT", b.cx or 0, -(b.cy or 0))
        self.slot:Show()
        if b.lift then b:lift(true) end
        animate()
      end)
      it:SetScript("OnDragStop", function(b)
        local list = {}
        for _, k in ipairs(self.order) do if k ~= b.key then list[#list + 1] = k end end
        table.insert(list, math.min(self.dragAt, #list + 1), b.key)
        self.dragKey = nil
        self.slot:Hide()
        b:SetFrameLevel(self:GetFrameLevel() + 2)
        b.cx, b.cy = select(4, b:GetPoint())
        b.cy = -(b.cy or 0)
        b.justDragged = GetTime()
        b.dragging = nil
        if b.lift then b:lift(false) end
        opt.onMove(list)
      end)
      self.items[d.key] = it
    end
  end
  return S
end

local function rowItem(S, d)
  local b = CreateFrame("Button", nil, S)
  b:SetSize(S:GetWidth(), 28)
  b:SetFrameLevel(S:GetFrameLevel() + 2)
  b.bg = NS.fill(b, 0.12, 0.09, 0.05, 0.95)
  b.bg:SetAllPoints()
  NS.border(b, { 1, 1, 1 }, 0.08)
  b.grip = grip(b)
  b.grip:SetPoint("LEFT", 8, 0)
  b.box = check(b, 14)
  b.box:SetPoint("LEFT", 26, 0)
  b.box:EnableMouse(false)
  b.label = NS.text(b, 12, NS.COL.ink)
  b.label:SetPoint("LEFT", 50, 0)
  b.label:SetText(d.label)
  b.val = NS.text(b, 11, NS.COL.muted)
  b.val:SetPoint("RIGHT", -10, 0)
  b.val:SetJustifyH("RIGHT")
  b.val:SetText(d.sample or "")
  b.label:SetPoint("RIGHT", b.val, "LEFT", -8, 0)
  b.def = d
  function b:SetOn(on)
    self.on = on
    self.box:SetOn(on)
    local c = on and NS.COL.ink or NS.COL.muted
    self.label:SetTextColor(c[1], c[2], c[3])
    self:SetAlpha(on and 1 or 0.7)
  end
  function b:lift(up)
    NS.setBorderColor(self, up and NS.COL.gold or { 1, 1, 1 }, up and 0.8 or 0.08)
    self.bg:SetColorTexture(up and 0.2 or 0.12, up and 0.15 or 0.09, up and 0.07 or 0.05, 0.98)
  end
  b:SetScript("OnEnter", function(self)
    if not self.dragging then NS.setBorderColor(self, NS.COL.gold, 0.4) end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(d.label, NS.COL.title[1], NS.COL.title[2], NS.COL.title[3])
    if d.note then GameTooltip:AddLine(d.note, 1, 1, 1, true) end
    GameTooltip:AddLine(d.fixed and "Click to show or hide." or "Click to show or hide. Drag to move.", NS.COL.muted[1], NS.COL.muted[2], NS.COL.muted[3], true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self) NS.setBorderColor(self, { 1, 1, 1 }, 0.08) GameTooltip:Hide() end)
  return b
end

local function chipItem(S, d)
  local b = CreateFrame("Button", nil, S)
  b:SetFrameLevel(S:GetFrameLevel() + 2)
  b.bg = NS.fill(b, 0, 0, 0, 0.45)
  b.bg:SetAllPoints()
  NS.border(b, NS.COL.frame, 1)
  b.box = check(b, 11)
  b.box:SetPoint("LEFT", 7, 0)
  b.box:EnableMouse(false)
  b.label = NS.text(b, 10, NS.COL.ink)
  b.label:SetPoint("LEFT", 24, 0)
  b.label:SetText(d.label)
  b:SetSize(b.label:GetStringWidth() + 34, 26)
  function b:SetOn(on)
    self.on = on
    self.box:SetOn(on)
    local c = on and NS.COL.gold or NS.COL.muted
    self.label:SetTextColor(c[1], c[2], c[3])
    self.bg:SetColorTexture(on and 0.973 or 0, on and 0.827 or 0, on and 0.42 or 0, on and 0.1 or 0.45)
  end
  function b:lift(up)
    NS.setBorderColor(self, up and NS.COL.gold or NS.COL.frame, 1)
  end
  b:SetScript("OnEnter", function(self) NS.setBorderColor(self, NS.COL.gold, 0.8) end)
  b:SetScript("OnLeave", function(self) if not self.dragging then NS.setBorderColor(self, NS.COL.frame, 1) end end)
  return b
end

local function smallButton(parent, label, w)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w or 70, 22)
  NS.fill(b, 0.973, 0.827, 0.42, 0.06):SetAllPoints()
  NS.border(b, NS.COL.gold, 0.3)
  b.t = NS.text(b, 11, NS.COL.gold)
  b.t:SetPoint("CENTER")
  b.t:SetText(label)
  b:SetScript("OnEnter", function(self) NS.setBorderColor(self, NS.COL.gold, 0.9) end)
  b:SetScript("OnLeave", function(self) NS.setBorderColor(self, NS.COL.gold, 0.3) end)
  return b
end

local function heading(parent, text, y)
  local t = NS.text(parent, 16, NS.COL.title, true)
  t:SetPoint("TOPLEFT", 0, y)
  t:SetText(text)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(NS.COL.frame[1], NS.COL.frame[2], NS.COL.frame[3], 0.5)
  line:SetHeight(1)
  line:SetPoint("LEFT", t, "RIGHT", 10, 0)
  line:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
  return t
end

local function toggleRow(parent, label, get, set)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(18)
  b.box = check(b, 14)
  b.box:SetPoint("LEFT")
  b.box:EnableMouse(false)
  b.t = NS.text(b, 12, NS.COL.ink2)
  b.t:SetPoint("LEFT", 22, 0)
  b.t:SetText(label)
  b:SetWidth(b.t:GetStringWidth() + 26)
  function b:Sync() self.box:SetOn(get()) end
  b:SetScript("OnClick", function(self) set(not get()) self:Sync() end)
  b:SetScript("OnEnter", function(self) self.t:SetTextColor(NS.COL.ink[1], NS.COL.ink[2], NS.COL.ink[3]) end)
  b:SetScript("OnLeave", function(self) self.t:SetTextColor(NS.COL.ink2[1], NS.COL.ink2[2], NS.COL.ink2[3]) end)
  return b
end

local SAMPLES = { 2589, 2770, 2592, 2318, 2771, 4306, 2772, 3575 }

local function sampleItem()
  local D = NS.Ensure()
  if not D or not D.cat then return end
  local own = NS.myHouse()
  local rs = own and D.houses and D.houses[own] and own or NS.ruleset()
  local H = rs and D.houses and D.houses[rs]
  local function priced(id)
    if not id or not D.cat[id] then return false end
    local l = H and H.lat and H.lat[id] or (not H and NS.latest(D.region, id))
    return l and l[1] and l[1] > 0
  end
  for _, id in ipairs(SAMPLES) do if priced(id) then return id end end
  for id in pairs(H and H.lat or {}) do return id end
end

local function whenLoaded(id, fn)
  if C_Item and C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(id) then return fn() end
  if Item and Item.CreateFromItemID then
    local it = Item:CreateFromItemID(id)
    if it and it.ContinueOnItemLoad then it:ContinueOnItemLoad(fn) return end
  end
  fn()
end

function NS.BuildCustomize(host)
  local P = CreateFrame("Frame", nil, host)
  P:SetPoint("TOPLEFT", 16, -16)
  P:SetPoint("BOTTOMRIGHT", -16, 16)
  local title = NS.text(P, 24, NS.COL.title, true)
  title:SetPoint("TOPLEFT", 0, 0)
  title:SetText("Life on Azeroth Market")
  local sub = NS.text(P, 12, NS.COL.muted)
  sub:SetPoint("TOPLEFT", 1, -30)
  sub:SetText("Choose what you see. Changes show up right away.")

  heading(P, "Item tooltip", -62)
  local master = toggleRow(P, "Show Life on Azeroth prices in item tooltips", function() return NS.db.tooltip ~= false end, function(v) NS.db.tooltip = v and true or false changed("tip") end)
  master:SetPoint("TOPLEFT", 0, -92)
  local tipHint = NS.text(P, 11, NS.COL.muted)
  tipHint:SetPoint("TOPLEFT", 0, -116)
  tipHint:SetText("Click to show or hide \194\183 drag to move")

  local titleRow = rowItem(P, { key = "title", label = "Heading", sample = "house and 24h change", fixed = true, note = "The Life on Azeroth line above the prices, with your auction house and the 24 hour price change." })
  titleRow:SetWidth(300)
  titleRow:SetPoint("TOPLEFT", 0, -136)
  titleRow.grip:Hide()
  titleRow:SetScript("OnClick", function()
    NS.db.tipTitle = not NS.tipLineOn("title")
    changed("tip")
  end)

  local tl = sorter(P, { gap = 0, rowGap = 4, onMove = function(order) NS.tipConf().order = order changed("tip") end, make = rowItem })
  tl:SetWidth(300)
  tl:SetPoint("TOPLEFT", 0, -168)
  tl:Build(NS.TIP_LINES)
  for k, it in pairs(tl.items) do
    it:SetScript("OnClick", function(self)
      if self.justDragged and GetTime() - self.justDragged < 0.25 then return end
      local c = NS.tipConf()
      c.off[k] = NS.tipLineOn(k) and true or false
      changed("tip")
    end)
  end

  local tipReset = smallButton(P, "Reset", 60)
  tipReset:SetScript("OnClick", function() NS.db.tipLines = nil NS.db.tipTitle = nil NS.db.tooltip = nil changed("tip") end)

  local prevBox = CreateFrame("Frame", nil, P)
  prevBox:SetPoint("TOPLEFT", 320, -92)
  prevBox:SetPoint("RIGHT", P, "RIGHT", 0, 0)
  prevBox:SetHeight(190)
  local pl = NS.text(prevBox, 10, NS.COL.muted)
  pl:SetPoint("TOPLEFT", 4, 0)
  pl:SetText("PREVIEW")
  local tipName = "LifeOnAzerothPreviewTip" .. (#(NS.custPanels or {}) + 1)
  local prev = CreateFrame("GameTooltip", tipName, prevBox, "GameTooltipTemplate")
  NS.MarkPreviewTip(prev)
  local prevNone = NS.text(prevBox, 12, NS.COL.muted)
  prevNone:SetPoint("TOPLEFT", 4, -22)
  prevNone:SetWidth(240)
  prevNone:SetWordWrap(true)
  prevNone:SetText("No prices loaded yet. Run the companion app, then type /reload.")

  local function showPreview()
    if not P:IsVisible() then return end
    local id = sampleItem()
    NS.MarkPreviewTip(prev)
    prev:SetOwner(prevBox, "ANCHOR_NONE")
    prev:ClearAllPoints()
    prev:SetPoint("TOPLEFT", prevBox, "TOPLEFT", 0, -16)
    if id then
      prevNone:Hide()
      whenLoaded(id, function()
        if not P:IsVisible() then return end
        prev:SetOwner(prevBox, "ANCHOR_NONE")
        prev:ClearAllPoints()
        prev:SetPoint("TOPLEFT", prevBox, "TOPLEFT", 0, -16)
        prev:SetItemByID(id)
        prev:Show()
      end)
    else
      prev:Hide()
      prevNone:Show()
    end
  end

  local colsHead = heading(P, "Your Items table", -312)
  local colHint = NS.text(P, 11, NS.COL.muted)
  colHint:SetPoint("TOPLEFT", 0, -340)
  colHint:SetText("Click to show or hide \194\183 drag to move")
  local itemChip = chipItem(P, { key = "item", label = "ITEM" })
  itemChip:SetPoint("TOPLEFT", 0, -362)
  itemChip:SetOn(true)
  itemChip:SetAlpha(0.6)
  itemChip:EnableMouse(false)
  local cl = sorter(P, { gap = 6, rowGap = 6, onMove = function(order) NS.colConf().order = order changed("cols") end, make = chipItem })
  cl:SetPoint("TOPLEFT", itemChip, "TOPRIGHT", 6, 0)
  cl:SetPoint("RIGHT", P, "RIGHT", 0, 0)
  cl:Build(NS.ITEM_COLS)
  for k, it in pairs(cl.items) do
    it:SetScript("OnClick", function(self)
      if self.justDragged and GetTime() - self.justDragged < 0.25 then return end
      local c = NS.colConf()
      c.off[k] = not c.off[k] or nil
      changed("cols")
    end)
  end
  local colReset = smallButton(P, "Reset", 60)
  colReset:SetPoint("TOPRIGHT", 0, -336)
  colReset:SetScript("OnClick", function() NS.db.itemCols = nil changed("cols") end)

  local accHead = heading(P, "Opening the Market", -440)
  local mm = toggleRow(P, "Show the coin button on the minimap", function() return not NS.db.minimap.hide end, function(v)
    NS.db.minimap.hide = not v
    if NS.minimapButton then NS.minimapButton:SetShown(v) end
  end)
  mm:SetPoint("TOPLEFT", 0, -468)
  local acc = NS.text(P, 11, NS.COL.muted)
  acc:SetPoint("TOPLEFT", 0, -492)
  acc:SetPoint("RIGHT", P, "RIGHT", 0, 0)
  acc:SetWordWrap(true)
  acc:SetJustifyH("LEFT")

  function P:Repaint(what)
    master:Sync()
    mm:Sync()
    local tipOn = NS.db.tooltip ~= false
    titleRow:SetOn(NS.tipLineOn("title"))
    titleRow:SetAlpha(tipOn and (NS.tipLineOn("title") and 1 or 0.7) or 0.35)
    local c = NS.tipConf()
    tl.order = c.order
    for k, it in pairs(tl.items) do
      it:SetOn(NS.tipLineOn(k))
      if not tipOn then it:SetAlpha(0.35) end
    end
    tl:Place(what ~= "tip")
    tipReset:ClearAllPoints()
    tipReset:SetPoint("TOPRIGHT", P, "TOPLEFT", 300, -112)
    local cc = NS.colConf()
    cl.order = cc.order
    for k, it in pairs(cl.items) do it:SetOn(not cc.off[k]) end
    cl:Place(what ~= "cols")
    local ways = { NS.color(NS.COL.gold, "/market") }
    if AddonCompartmentFrame then ways[#ways + 1] = "the AddOns button by the minimap" end
    if NS.ldb then ways[#ways + 1] = "data bars like ElvUI and Titan Panel" end
    acc:SetText("Also opens from " .. table.concat(ways, ", ") .. ". Right-click any of them to come back here.")
    showPreview()
  end
  P:SetScript("OnShow", function(self) self:Repaint() end)
  NS.custPanels = NS.custPanels or {}
  NS.custPanels[#NS.custPanels + 1] = P
  return P
end

local win
function NS.ToggleCustomize(show)
  if not win then
    win = CreateFrame("Frame", "LifeOnAzerothCustomizeFrame", UIParent)
    win:SetSize(660, 580)
    win:SetPoint("CENTER", 0, 20)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    NS.fill(win, NS.COL.bg[1], NS.COL.bg[2], NS.COL.bg[3], 0.98):SetAllPoints()
    NS.border(win, NS.COL.frame, 1)
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() win:Hide() end)
    local inner = CreateFrame("Frame", nil, win)
    inner:SetPoint("TOPLEFT", 8, -8)
    inner:SetPoint("BOTTOMRIGHT", -8, 8)
    win.panel = NS.BuildCustomize(inner)
    win.panel:SetPoint("TOPRIGHT", -30, -16)
    tinsert(UISpecialFrames, "LifeOnAzerothCustomizeFrame")
    win:Hide()
  end
  if show == nil then show = not win:IsShown() end
  win:SetShown(show)
end

local function openerTip(tt)
  tt:AddLine("Life on Azeroth Market", NS.COL.title[1], NS.COL.title[2], NS.COL.title[3])
  tt:AddLine("Click to open the Market.", 1, 1, 1)
  tt:AddLine("Right-click to customize the tooltip and table.", 1, 1, 1)
  local d = LOA_DATA
  if d and d.built then tt:AddLine("Prices " .. NS.ago(d.built) .. ".", NS.COL.muted[1], NS.COL.muted[2], NS.COL.muted[3]) end
end

local function opener(btn)
  if btn == "RightButton" then NS.ToggleCustomize() else NS.Toggle() end
end

function LifeOnAzerothMarket_OnCompartmentClick(_, btn)
  opener(btn)
end

function LifeOnAzerothMarket_OnCompartmentEnter(_, frame)
  GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
  openerTip(GameTooltip)
  GameTooltip:Show()
end

function LifeOnAzerothMarket_OnCompartmentLeave()
  GameTooltip:Hide()
end

function NS.SetupOptions()
  local panel = CreateFrame("Frame")
  panel.name = "Life on Azeroth Market"
  panel:SetScript("OnShow", function(self)
    if not self.built then
      self.built = NS.BuildCustomize(self)
      self.built:Repaint()
    end
  end)
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(cat)
    NS.settingsCategory = cat
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
  local login = CreateFrame("Frame")
  login:RegisterEvent("PLAYER_LOGIN")
  login:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if C_Item and C_Item.RequestLoadItemDataByID then
      for _, id in ipairs(SAMPLES) do pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if LDB and not NS.ldb then
      NS.ldb = LDB:NewDataObject("LifeOnAzerothMarket", {
        type = "launcher",
        label = "Market",
        text = "Market",
        icon = "Interface\\Icons\\INV_Misc_Coin_17",
        OnClick = function(_, btn) opener(btn) end,
        OnTooltipShow = function(tt) openerTip(tt) end,
      })
    end
  end)
end
