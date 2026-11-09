local ADDON, NS = ...

local V = NS.Value
local views = {}
local current = "market"

local BLUE = { 0.42, 0.66, 0.98 }

local PICK = {
  ah = { "Auction", NS.COL.up },
  vendor = { "Vendor", NS.COL.gold },
  close = { "Close call", NS.COL.title2 },
  none = { "\226\128\147", NS.COL.muted },
}

local function tipLine(l, r, c)
  c = c or NS.COL.ink2
  if r then GameTooltip:AddDoubleLine(l, r, c[1], c[2], c[3], 1, 1, 1) else GameTooltip:AddLine(l, c[1], c[2], c[3], true) end
end

local function box(parent, title)
  local b = CreateFrame("Frame", nil, parent)
  NS.fill(b, 0, 0, 0, 0.3):SetAllPoints()
  NS.border(b, { 1, 1, 1 }, 0.06)
  b.title = NS.text(b, 14, NS.COL.title2, true)
  b.title:SetPoint("TOPLEFT", 12, -10)
  b.title:SetText(title)
  return b
end

local function makeList(parent, cols, rowH, onRow)
  local L = CreateFrame("Frame", nil, parent)
  L.cols, L.rowH, L.rows = cols, rowH or 28, {}
  local head = CreateFrame("Frame", nil, L)
  head:SetPoint("TOPLEFT")
  head:SetPoint("TOPRIGHT")
  head:SetHeight(22)
  NS.fill(head, 0, 0, 0, 0.3):SetAllPoints()
  L.heads = {}
  for i, c in ipairs(cols) do
    local b = CreateFrame("Button", nil, head)
    b:SetHeight(22)
    b:SetPoint("LEFT", c.x, 0)
    b:SetWidth(c.w)
    b.t = NS.text(b, 10, NS.COL.muted)
    b.t:SetAllPoints()
    b.t:SetJustifyH(c.right and "RIGHT" or "LEFT")
    b.t:SetText(c.title)
    if c.sort then
      b:SetScript("OnClick", function()
        if L.sortKey == c.sort then L.sortDesc = not L.sortDesc else L.sortKey, L.sortDesc = c.sort, c.desc ~= false end
        if L.onSort then L.onSort() end
      end)
      b:SetScript("OnEnter", function(self) self.t:SetTextColor(NS.COL.ink[1], NS.COL.ink[2], NS.COL.ink[3]) end)
      b:SetScript("OnLeave", function(self) local cc = L.sortKey == c.sort and NS.COL.gold or NS.COL.muted self.t:SetTextColor(cc[1], cc[2], cc[3]) end)
    end
    b.col = c
    L.heads[i] = b
  end
  local sf = CreateFrame("ScrollFrame", nil, L)
  sf:SetPoint("TOPLEFT", 0, -24)
  sf:SetPoint("BOTTOMRIGHT", -6, 0)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(10, 10)
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
    self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * L.rowH * 2)))
    updBar()
  end)
  L.empty = NS.text(L, 12, NS.COL.muted)
  L.empty:SetPoint("TOP", 0, -48)
  L.empty:SetWidth(460)
  L.empty:SetWordWrap(true)
  L.empty:SetJustifyH("CENTER")
  function L:Row(i)
    local r = self.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, child)
    r:SetHeight(self.rowH)
    r.bg = NS.fill(r, 1, 1, 1, 0)
    r.bg:SetAllPoints()
    r.cells = {}
    for k, c in ipairs(self.cols) do
      if c.icon then
        r.ic = NS.iconBox(r, self.rowH - 8)
        r.ic:SetPoint("LEFT", c.x, 0)
        local t = NS.text(r, 12, NS.COL.ink)
        t:SetPoint("LEFT", c.x + self.rowH, 0)
        t:SetWidth(c.w - self.rowH)
        t:SetWordWrap(false)
        r.cells[k] = t
      else
        local t = NS.text(r, c.size or 12, NS.COL.ink)
        t:SetPoint("LEFT", c.x, 0)
        t:SetWidth(c.w)
        t:SetJustifyH(c.right and "RIGHT" or "LEFT")
        t:SetWordWrap(false)
        r.cells[k] = t
      end
    end
    r:SetScript("OnEnter", function(self) self.bg:SetColorTexture(1, 1, 1, 0.05) if L.onEnter then L.onEnter(self) end end)
    r:SetScript("OnLeave", function(self) self.bg:SetColorTexture(1, 1, 1, 0) GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self) if onRow and self.data then onRow(self.data) end end)
    self.rows[i] = r
    return r
  end
  function L:Paint(data, fill, emptyText)
    child:SetWidth(sf:GetWidth())
    for _, r in ipairs(self.rows) do r:Hide() end
    for i, d in ipairs(data) do
      local r = self:Row(i)
      r:SetPoint("TOPLEFT", 0, -(i - 1) * self.rowH)
      r:SetPoint("RIGHT", child, "RIGHT")
      r.data = d
      fill(r, d)
      r:Show()
    end
    child:SetHeight(math.max(10, #data * self.rowH))
    local max = math.max(0, child:GetHeight() - sf:GetHeight())
    if sf:GetVerticalScroll() > max then sf:SetVerticalScroll(max) end
    updBar()
    self.empty:SetText(#data == 0 and (emptyText or "") or "")
    for _, b in ipairs(self.heads) do
      local on = b.col.sort and self.sortKey == b.col.sort
      local cc = on and NS.COL.gold or NS.COL.muted
      b.t:SetTextColor(cc[1], cc[2], cc[3])
      b.t:SetText(b.col.title .. (on and (self.sortDesc and " |TInterface\\Buttons\\Arrow-Down-Up:11:11:0:-1|t" or " |TInterface\\Buttons\\Arrow-Up-Up:11:11:0:1|t") or ""))
    end
  end
  return L
end

local function sortBy(list, key, desc)
  table.sort(list, function(a, b)
    local x, y = a[key], b[key]
    if type(x) == "string" or type(y) == "string" then
      x, y = tostring(x or ""), tostring(y or "")
      if desc then return x > y end
      return x < y
    end
    x, y = x or -math.huge, y or -math.huge
    if x == y then return (a.name or "") < (b.name or "") end
    if desc then return x > y end
    return x < y
  end)
end

local function pct(v)
  if not v then return NS.color(NS.COL.muted, "\226\128\147") end
  return NS.pctColored(v)
end

local function itemTip(row)
  local r = row.data
  if not r then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  local qc = NS.QC[r.q] or NS.COL.ink
  GameTooltip:AddLine(r.name or ("Item " .. r.id), qc[1], qc[2], qc[3])
  if r.net then tipLine("Sells for, after the AH cut", NS.coin(math.floor(r.net))) end
  tipLine("Vendor pays", r.vendor > 0 and NS.coin(r.vendor) or "nothing")
  if r.perDay then tipLine(r.sales and "Sold per day" or "Left the AH per day", NS.fmt(math.floor(r.perDay + 0.5))) end
  local g, u = NS.COL.up, NS.COL.gold
  if r.pick == "ah" then
    GameTooltip:AddLine("Auction it: about " .. NS.coin(math.floor(r.gain)) .. " more than vendoring.", g[1], g[2], g[3], true)
  elseif not r.net then
    GameTooltip:AddLine(r.vendor > 0 and "Vendor it: nobody lists it on your auction house." or "Not on your auction house lately.", u[1], u[2], u[3], true)
  elseif r.chance == 0 then
    GameTooltip:AddLine("Vendor it: nobody has bought it lately.", u[1], u[2], u[3], true)
  else
    GameTooltip:AddLine("Vendor it: the AH isn't likely to pay more.", u[1], u[2], u[3], true)
  end
  if r.pick == "ah" and r.vsUsual and math.abs(r.vsUsual) >= 1 then
    local m = NS.COL.muted
    GameTooltip:AddLine((r.vsUsual > 0 and "Above" or "Below") .. " its usual price right now (" .. NS.pctText(r.vsUsual) .. ").", m[1], m[2], m[3], true)
  end
  GameTooltip:Show()
end

local function buildItems(parent)
  local v = CreateFrame("Frame", nil, parent)
  v:SetPoint("TOPLEFT", 16, -112)
  v:SetPoint("BOTTOMRIGHT", -16, 16)
  v.where = NS.segmented(v, { "Bags", "Bank", "Both" }, function(k) NS.db.itemsWhere = k NS.PaintViews() end, 64)
  v.where:SetPoint("TOPLEFT", 0, 0)
  v.who = NS.segmented(v, { "Me", "All" }, function(k) NS.db.itemsWho = k NS.PaintViews() end, 84)
  v.who:SetPoint("LEFT", v.where, "RIGHT", 8, 0)
  v.who.buttons[1].label:SetText("This character")
  v.who.buttons[2].label:SetText("All characters")
  v.junk = NS.segmented(v, { "hide" }, function()
    NS.db.showJunk = not NS.db.showJunk
    NS.PaintViews()
  end, 96)
  v.junk:SetPoint("LEFT", v.who, "RIGHT", 8, 0)
  v.junk.buttons[1].label:SetText("Hide junk")
  v.sum = NS.text(v, 12, NS.COL.ink2)
  v.sum:SetPoint("RIGHT", v, "TOPRIGHT", 0, -13)
  v.sum:SetJustifyH("RIGHT")
  local W = 1028
  local cols = {
    { title = "ITEM", x = 8, w = 320, icon = true, sort = "name", desc = false },
    { title = "QTY", x = 336, w = 48, right = true, sort = "n" },
    { title = "SELLS FOR", x = 392, w = 100, right = true, sort = "net" },
    { title = "VENDOR", x = 500, w = 92, right = true, sort = "vendor" },
    { title = "SOLD/DAY", x = 600, w = 80, right = true, sort = "perDay" },
    { title = "WORTH", x = 688, w = 110, right = true, sort = "total" },
    { title = "GAIN VS VENDOR", x = 806, w = 120, right = true, sort = "gain" },
    { title = "BEST", x = W - 92, w = 80, sort = "pickN" },
  }
  v.list = makeList(v, cols, 30, function(d) NS.OpenItem(d.id) end)
  v.list:SetPoint("TOPLEFT", 0, -38)
  v.list:SetPoint("BOTTOMRIGHT", 0, 22)
  v.list.sortKey, v.list.sortDesc = "gain", true
  v.list.onSort = function() NS.PaintViews() end
  v.list.onEnter = itemTip
  v.foot = NS.text(v, 11, NS.COL.muted)
  v.foot:SetPoint("BOTTOMLEFT", 0, 2)
  v.foot:SetPoint("BOTTOMRIGHT", 0, 2)
  v.foot:SetJustifyH("LEFT")
  return v
end

local PICK_ORDER = { ah = 3, close = 2, vendor = 1, none = 0 }

local function paintItems(v)
  local where = NS.db.itemsWhere or "Both"
  local who = NS.db.itemsWho or "Me"
  v.where:Select(where)
  v.who:Select(who)
  local scope = { bags = where ~= "Bank", bank = where ~= "Bags", all = who == "All" }
  local all = V.holdings(scope)
  v.junk:Select(not NS.db.showJunk and "hide" or nil)
  local list, hidden = {}, 0
  for _, r in ipairs(all) do
    if NS.db.showJunk or r.q ~= 0 then list[#list + 1] = r else hidden = hidden + 1 end
  end
  local worth, gain, ahN = 0, 0, 0
  for _, r in ipairs(list) do
    r.pickN = PICK_ORDER[r.pick] or 0
    r.name = r.name or ""
    worth = worth + r.total
    if r.pick == "ah" then
      ahN = ahN + 1
      gain = gain + r.gain
    end
  end
  local salesKnown = false
  for _, r in ipairs(list) do if r.sales then salesKnown = true break end end
  v.list.heads[5].col.title = salesKnown and "SOLD/DAY" or "LEFT AH/DAY"
  v.salesKnown = salesKnown
  sortBy(list, v.list.sortKey, v.list.sortDesc)
  v.sum:SetText("Worth " .. NS.color(NS.COL.ink, NS.coin(math.floor(worth))) .. "   \194\183   auctioning " .. ahN .. (ahN == 1 and " item" or " items") .. " adds " .. NS.color(NS.COL.up, NS.coin(math.floor(gain))) .. " over vendoring")
  local c, me = NS.Ledger.me()
  local empty
  if where ~= "Bags" and who == "Me" and c and not c.bankT then
    empty = "Open your bank once on this character and it will show up here."
  else
    empty = "Nothing to show yet."
  end
  v.list:Paint(list, function(row, r)
    local cl = row.cells
    row.ic.icon:SetTexture(NS.itemIcon(r.id))
    row.ic:SetQuality(r.q)
    local qc = NS.QC[r.q] or NS.COL.ink
    cl[1]:SetTextColor(qc[1], qc[2], qc[3])
    cl[1]:SetText(r.name ~= "" and r.name or ("Item " .. r.id))
    cl[2]:SetText(NS.fmt(r.n))
    local dash = NS.color(NS.COL.muted, "\226\128\147")
    cl[3]:SetText(r.net and NS.coin(math.floor(r.net)) or NS.color(NS.COL.muted, "not listed"))
    cl[4]:SetText(r.vendor > 0 and NS.coin(r.vendor) or dash)
    cl[5]:SetText(r.perDay and NS.fmt(math.floor(r.perDay + 0.5)) or dash)
    cl[6]:SetText(r.total > 0 and NS.coin(math.floor(r.total)) or dash)
    cl[7]:SetText(r.gain >= 1 and NS.color(NS.COL.up, "+" .. NS.coin(math.floor(r.gain))) or dash)
    local p = PICK[r.pick] or PICK.none
    cl[8]:SetText(NS.color(p[2], p[1]))
  end, empty)
  local parts = {}
  if c then
    parts[#parts + 1] = "Bags read " .. (c.bagsT and NS.ago(c.bagsT) or "never")
    parts[#parts + 1] = "bank " .. (c.bankT and NS.ago(c.bankT) or "not opened yet")
  end
  if not V.depRate() then parts[#parts + 1] = "deposits are learned next time you open the auction house" end
  parts[#parts + 1] = "soulbound items are left out"
  if hidden > 0 then parts[#parts + 1] = hidden .. " junk " .. (hidden == 1 and "item" or "items") .. " hidden" end
  if not v.salesKnown and #list > 0 then parts[#parts + 1] = "update the companion app to count real sales" end
  v.foot:SetText(table.concat(parts, "  \194\183  ") .. ".")
end

local function statBox(parent, label)
  local s = CreateFrame("Frame", nil, parent)
  NS.fill(s, 0, 0, 0, 0.3):SetAllPoints()
  NS.border(s, { 1, 1, 1 }, 0.06)
  s.k = NS.text(s, 10, NS.COL.muted)
  s.k:SetPoint("TOPLEFT", 12, -10)
  s.k:SetText(label)
  s.v = NS.text(s, 15, { 1, 0.949, 0.812 })
  s.v:SetPoint("BOTTOMLEFT", 12, 10)
  return s
end

local function buildPort(parent)
  local v = CreateFrame("Frame", nil, parent)
  v:SetPoint("TOPLEFT", 16, -112)
  v:SetPoint("BOTTOMRIGHT", -16, 16)
  local gold = box(v, "Net worth")
  gold:SetPoint("TOPLEFT")
  gold:SetSize(620, 228)
  gold.who = NS.segmented(gold, { "Me", "All" }, function(k) NS.db.goldWho = k NS.PaintViews() end, 84)
  gold.who:SetPoint("TOPRIGHT", -8, -6)
  gold.who.buttons[1].label:SetText("This character")
  gold.who.buttons[2].label:SetText("All characters")
  gold.now = NS.text(gold, 12, NS.COL.ink2)
  gold.now:SetPoint("TOPLEFT", 12, -32)
  gold.chart = NS.Chart.New(gold)
  gold.chart:SetPoint("TOPLEFT", gold, "TOPLEFT", 8, -54)
  gold.chart:SetPoint("BOTTOMRIGHT", gold, "BOTTOMRIGHT", -8, 8)
  v.gold = gold
  local stats = CreateFrame("Frame", nil, v)
  stats:SetPoint("TOPLEFT", gold, "TOPRIGHT", 12, 0)
  stats:SetPoint("TOPRIGHT", 0, 0)
  stats:SetHeight(228)
  v.st = {}
  local labels = { "SOLD ON THE AH", "DEPOSITS LOST", "NET FROM SELLING", "BOUGHT ON THE AH" }
  for i, lb in ipairs(labels) do
    local s = statBox(stats, lb)
    local col, rowI = (i - 1) % 2, math.floor((i - 1) / 2)
    s:SetPoint("TOPLEFT", stats, "TOPLEFT", col * 202, -rowI * 116)
    s:SetSize(196, 110)
    v.st[i] = s
  end
  local cols = {
    { title = "YOUR AUCTIONS", x = 8, w = 300, icon = true, sort = "name", desc = false },
    { title = "POSTED", x = 316, w = 64, right = true, sort = "posts" },
    { title = "SOLD", x = 388, w = 56, right = true, sort = "sales" },
    { title = "UNSOLD", x = 452, w = 64, right = true, sort = "unsold" },
    { title = "SOLD FOR", x = 524, w = 116, right = true, sort = "sold" },
    { title = "DEPOSITS LOST", x = 648, w = 116, right = true, sort = "lostDeps" },
    { title = "NET", x = 772, w = 116, right = true, sort = "net" },
    { title = "", x = 904, w = 120 },
  }
  v.auc = makeList(v, cols, 28, function(d) if d.id then NS.OpenItem(d.id) end end)
  v.auc:SetPoint("TOPLEFT", gold, "BOTTOMLEFT", 0, -12)
  v.auc:SetPoint("BOTTOMRIGHT")
  v.auc.sortKey, v.auc.sortDesc = "net", true
  v.auc.onSort = function() NS.PaintViews() end
  v.auc.onEnter = function(row)
    local s = row.data
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(s.name or "?", NS.COL.title[1], NS.COL.title[2], NS.COL.title[3])
    tipLine("Times posted", NS.fmt(s.posts))
    tipLine("Sales", s.sales .. " (" .. NS.fmt(s.soldN) .. " items)")
    tipLine("Came back unsold", NS.fmt(s.unsold))
    tipLine("Gold from sales, after the AH cut", NS.coin(math.floor(s.sold)))
    tipLine("Deposits lost", NS.coin(math.floor(s.lostDeps)))
    if s.loser then GameTooltip:AddLine("Posted more than once and never sold: probably better to vendor.", NS.COL.dn[1], NS.COL.dn[2], NS.COL.dn[3], true) end
    GameTooltip:Show()
  end
  return v
end

local function paintPort(v)
  local who = NS.db.goldWho or "All"
  v.gold.who:Select(who)
  local t, net, liquid = V.worthSeries(who == "All")
  local nowN, nowG = net[#net], liquid[#liquid]
  local function back(sec)
    local cut = time() - sec
    local r
    for i = 1, #t do if t[i] <= cut then r = net[i] else break end end
    return r
  end
  local dash = "\226\128\147"
  local txt = NS.color(NS.COL.gold, "Net worth ") .. NS.color(NS.COL.ink, nowN and NS.coin(nowN) or dash)
    .. "   " .. NS.color(BLUE, "Gold ") .. NS.color(NS.COL.ink, nowG and NS.coin(nowG) or dash)
  for _, p in ipairs({ { 86400, "24h" }, { 7 * 86400, "7d" } }) do
    local b = back(p[1])
    if b and nowN then
      local d = nowN - b
      local c = d >= 0 and NS.COL.up or NS.COL.dn
      txt = txt .. "   " .. NS.color(NS.COL.muted, p[2]) .. " " .. NS.color(c, (d >= 0 and "+" or "-") .. NS.coin(math.abs(d)))
    end
  end
  v.gold.now:SetText(txt)
  local function steps(vals)
    local tt, vv = {}, {}
    for i = 1, #t do
      if i > 1 then tt[#tt + 1] = t[i] - 1 vv[#vv + 1] = vals[i - 1] end
      tt[#tt + 1] = t[i]
      vv[#vv + 1] = vals[i]
    end
    if #tt > 0 then tt[#tt + 1] = time() vv[#vv + 1] = vals[#vals] end
    return tt, vv
  end
  local nt, nv = steps(net)
  local gt, gv = steps(liquid)
  local series = {}
  if #nt > 1 then
    series[1] = { name = "Net worth", t = nt, v = nv, unit = "coin", color = NS.COL.gold }
    series[2] = { name = "Gold", t = gt, v = gv, unit = "coin", color = BLUE }
  end
  v.gold.chart:Draw(series, { span = 0, abs = true, fill = true, emptyText = "Your gold and items are saved from now on. Check back after you play a bit." })
  local list, tot = V.stats()
  v.st[1].v:SetText(NS.coin(math.floor(tot.sold)))
  v.st[2].v:SetText(NS.coin(math.floor(tot.lost)))
  local net = tot.sold - tot.lost
  v.st[3].v:SetText(NS.color(net >= 0 and NS.COL.up or NS.COL.dn, (net < 0 and "-" or "") .. NS.coin(math.floor(math.abs(net)))))
  v.st[4].v:SetText(NS.coin(math.floor(tot.bought)))
  local D = NS.Ensure()
  for _, s in ipairs(list) do s.name = s.name or "?" end
  sortBy(list, v.auc.sortKey, v.auc.sortDesc)
  v.auc:Paint(list, function(row, s)
    local cl = row.cells
    local cat = s.id and D and D.cat[s.id]
    row.ic.icon:SetTexture(s.id and NS.itemIcon(s.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.ic:SetQuality(cat and cat[2])
    local qc = cat and NS.QC[cat[2]] or NS.COL.ink
    cl[1]:SetTextColor(qc[1], qc[2], qc[3])
    cl[1]:SetText(s.name)
    cl[2]:SetText(NS.fmt(s.posts))
    cl[3]:SetText(NS.fmt(s.sales))
    cl[4]:SetText(s.unsold > 0 and NS.color(NS.COL.title2, NS.fmt(s.unsold)) or "0")
    cl[5]:SetText(NS.coin(math.floor(s.sold)))
    cl[6]:SetText(s.lostDeps > 0 and NS.color(NS.COL.dn, NS.coin(math.floor(s.lostDeps))) or NS.coin(0))
    cl[7]:SetText(NS.color(s.net >= 0 and NS.COL.ink or NS.COL.dn, (s.net < 0 and "-" or "") .. NS.coin(math.floor(math.abs(s.net)))))
    local status
    if s.loser then status = NS.color(NS.COL.dn, "Vendor it")
    elseif s.sales > 0 and s.unsold == 0 then status = NS.color(NS.COL.up, "Sells")
    elseif s.sales > 0 then status = NS.color(NS.COL.title2, "Sells sometimes")
    elseif s.unsold > 0 then status = NS.color(NS.COL.title2, "Unsold once")
    else status = NS.color(NS.COL.muted, "Listed") end
    cl[8]:SetText(status)
  end, "Your auctions show up here once you post on the AH or collect auction mail: sales, items that came back, and deposits lost.")
end

local function buildMovers(side)
  local mv = CreateFrame("Frame", nil, side)
  mv:SetPoint("TOPLEFT", 0, -36)
  mv:SetPoint("BOTTOMRIGHT")
  mv.dir = NS.segmented(mv, { "Up", "Down" }, function(k) NS.db.moversDir = k NS.Refresh() end, 80)
  mv.dir:SetPoint("TOPLEFT", 0, 0)
  mv.dir.buttons[1].label:SetText("Rising")
  mv.dir.buttons[2].label:SetText("Falling")
  mv.note = NS.text(mv, 10, NS.COL.muted)
  mv.note:SetPoint("LEFT", mv.dir, "RIGHT", 10, 0)
  mv.note:SetWidth(160)
  mv.note:SetJustifyH("LEFT")
  mv.note:SetText("Now vs the same time yesterday")
  local mcols = {
    { title = "ITEM", x = 8, w = 172, icon = true, sort = "rank", desc = false },
    { title = "PRICE", x = 184, w = 76, right = true, sort = "cur" },
    { title = "CHANGE", x = 264, w = 64, right = true, sort = "absCh" },
  }
  mv.list = makeList(mv, mcols, 27, function(d) NS.OpenItem(d.id) end)
  mv.list:SetPoint("TOPLEFT", 0, -36)
  mv.list:SetPoint("BOTTOMRIGHT", 0, 0)
  mv.list.sortKey, mv.list.sortDesc = "rank", false
  mv.list.onSort = function() NS.Refresh() end
  mv.list.heads[1].col.title = "ITEM"
  mv.list.onEnter = function(row)
    local d = row.data
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(NS.itemName(d.id) or "?", NS.COL.title[1], NS.COL.title[2], NS.COL.title[3])
    tipLine("Now", NS.coin(math.floor(d.cur)))
    tipLine("Same time yesterday", NS.coin(math.floor(d.prev)))
    tipLine("Change", NS.pctColored(d.ch))
    tipLine(d.sales and "Sold per day" or "Left the AH per day", NS.fmt(math.floor(d.perDay + 0.5)))
    tipLine(d.sales and "Gold sold per day" or "Gold leaving per day", NS.coin(math.floor(d.valDay)))
    tipLine("Listed now", NS.fmt(d.listed))
    GameTooltip:AddLine("Ranked by the size of the move times how much gold trades in it each day, so busy markets beat odd one-off listings.", NS.COL.muted[1], NS.COL.muted[2], NS.COL.muted[3], true)
    GameTooltip:AddLine("Click for price history.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end
  return mv
end

function NS.PaintMovers(side, show)
  if not side.movers then
    if not show then return end
    side.movers = buildMovers(side)
  end
  local mv = side.movers
  mv:SetShown(show)
  if not show then return end
  local dir = NS.db.moversDir or "Up"
  mv.dir:Select(dir)
  local up, dn = V.movers()
  local src = dir == "Up" and up or dn
  local top = {}
  for i = 1, math.min(50, #src) do
    local d = src[i]
    d.rank = i
    d.absCh = math.abs(d.ch)
    top[i] = d
  end
  sortBy(top, mv.list.sortKey, mv.list.sortDesc)
  mv.shown = top
  local D = NS.Ensure()
  mv.list:Paint(top, function(row, d)
    local cl = row.cells
    local cat = D and D.cat[d.id]
    row.ic.icon:SetTexture(NS.itemIcon(d.id))
    row.ic:SetQuality(cat and cat[2])
    local qc = cat and NS.QC[cat[2]] or NS.COL.ink
    cl[1]:SetTextColor(qc[1], qc[2], qc[3])
    cl[1]:SetText(cat and cat[1] or ("Item " .. d.id))
    cl[2]:SetText(NS.coin(math.floor(d.cur)))
    cl[3]:SetText(NS.pctColored(d.ch))
  end, "Not enough price history for this auction house yet.")
end

function NS.MoverSeries()
  local f = NS.Main()
  local mv = f and f.side and f.side.movers
  if not mv or not mv.shown then return nil end
  local out = {}
  for i = 1, math.min(5, #mv.shown) do
    local d = mv.shown[i]
    out[i] = { kind = "item", id = d.id, base = d.prev, now = d.cur, ch = d.ch }
  end
  return out
end

function NS.BuildViews(f)
  local tabs = NS.segmented(f, { "market", "items", "port" }, function(k) NS.SetView(k) end, 100)
  tabs:SetPoint("TOPLEFT", 250, -26)
  tabs.buttons[1].label:SetText("Market")
  tabs.buttons[2].label:SetText("Your items")
  tabs.buttons[3].label:SetText("Portfolio")
  f.tabs = tabs
  views.items = buildItems(f.body)
  views.port = buildPort(f.body)
  views.items:Hide()
  views.port:Hide()
end

function NS.SetView(k)
  current = k
  NS.db.view = k
  if NS.CloseItem then NS.CloseItem() end
  NS.Refresh()
end

function NS.PaintViews()
  local f = NS.Main()
  if not f or not f.tabs or not f:IsShown() then return end
  current = NS.db.view or current
  if not views[current] then current = "market" end
  f.tabs:Select(current)
  f.side:SetShown(current == "market")
  f.right:SetShown(current == "market")
  for k, v in pairs(views) do v:SetShown(k == current) end
  if not LOA_DATA then return end
  if current == "items" then paintItems(views.items) elseif current == "port" then paintPort(views.port) end
end

local queued = false
local bankLine

local function bankItems()
  local c = NS.Ledger.me()
  local out, ah, vend = {}, 0, 0
  if not LOA_DATA or not c or not c.bank then return out, ah, vend end
  for id, e in pairs(c.bank) do
    local free = e[1] or 0
    if free > 0 then
      local r = V.item(id, free)
      if r and r.total > 0 then
        out[#out + 1] = r
        if r.pick == "ah" then ah = ah + r.total else vend = vend + r.total end
      end
    end
  end
  table.sort(out, function(a, b) return a.total > b.total end)
  return out, ah, vend
end

local function paintBank()
  if not bankLine or not bankLine:IsVisible() then return end
  local list, ah, vend = bankItems()
  if not LOA_DATA then bankLine:Hide() return end
  bankLine.list, bankLine.ah, bankLine.vend = list, ah, vend
  bankLine.text:SetText(NS.color(NS.COL.title2, "Bank worth") .. "   " .. NS.color(NS.COL.ink, NS.coin(math.floor(ah + vend))))
  bankLine:SetWidth(bankLine.text:GetStringWidth() + 28)
end

local function bankTip(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:AddLine("Life on Azeroth \194\183 bank worth", NS.COL.title[1], NS.COL.title[2], NS.COL.title[3])
  tipLine("Selling on the AH, after the " .. math.floor(V.cut() * 100 + 0.5) .. "% cut", NS.coin(math.floor(self.ah or 0)))
  tipLine("Selling the rest to a vendor", NS.coin(math.floor(self.vend or 0)))
  local list = self.list or {}
  if #list > 0 then GameTooltip:AddLine(" ") end
  for i = 1, math.min(8, #list) do
    local r = list[i]
    local qc = NS.QC[r.q] or NS.COL.ink
    GameTooltip:AddDoubleLine((r.name or "?") .. NS.color(NS.COL.muted, " x" .. r.n), NS.coin(math.floor(r.total)), qc[1], qc[2], qc[3], 1, 1, 1)
  end
  GameTooltip:AddLine("Soulbound items aren't counted. /market for the full list.", NS.COL.muted[1], NS.COL.muted[2], NS.COL.muted[3], true)
  GameTooltip:Show()
end

local function buildBankLine()
  local bf = _G.BankFrame
  if bankLine or not bf then return end
  bankLine = CreateFrame("Button", nil, bf)
  bankLine:SetHeight(26)
  bankLine:SetPoint("TOPLEFT", bf, "BOTTOMLEFT", 0, -2)
  NS.fill(bankLine, 0.071, 0.055, 0.035, 0.95):SetAllPoints()
  NS.border(bankLine, NS.COL.frame, 1)
  bankLine.text = NS.text(bankLine, 12, NS.COL.ink)
  bankLine.text:SetPoint("LEFT", 14, 0)
  bankLine:SetScript("OnShow", paintBank)
  bankLine:SetScript("OnEnter", bankTip)
  bankLine:SetScript("OnLeave", function() GameTooltip:Hide() end)
  bankLine:SetScript("OnClick", function() NS.db.view = "items" NS.db.itemsWhere = "Bank" if not NS.Main() or not NS.Main():IsShown() then NS.Toggle() else NS.Refresh() end end)
end

local bankEv = CreateFrame("Frame")
bankEv:RegisterEvent("BANKFRAME_OPENED")
bankEv:SetScript("OnEvent", function()
  pcall(buildBankLine)
  C_Timer.After(0.8, function() pcall(paintBank) end)
end)

function NS.OnLedgerChanged()
  pcall(paintBank)
  if queued then return end
  queued = true
  C_Timer.After(1, function()
    queued = false
    local f = NS.Main()
    if f and f:IsShown() and current ~= "market" then pcall(NS.PaintViews) end
  end)
end

local load = NS.OnLoad
NS.OnLoad = function()
  if load then load() end
  NS.Ledger.Init()
end
