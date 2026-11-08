local ADDON, NS = ...

local Chart = {}
Chart.__index = Chart
NS.Chart = Chart

local function pool(self, kind)
  local p = self.pools[kind]
  p.n = p.n + 1
  local o = p[p.n]
  if not o then
    if kind == "line" then
      o = self.canvas:CreateLine(nil, "ARTWORK")
    elseif kind == "fill" then
      o = self.canvas:CreateTexture(nil, "BACKGROUND", nil, 2)
      o:SetTexture("Interface\\Buttons\\WHITE8X8")
    elseif kind == "grid" then
      o = self.canvas:CreateTexture(nil, "BACKGROUND", nil, 3)
    elseif kind == "dot" then
      o = self.canvas:CreateTexture(nil, "OVERLAY", nil, 2)
      o:SetTexture("Interface\\Buttons\\WHITE8X8")
      o:SetSize(8, 8)
      if not self.dotMask then
        self.dotMask = true
      end
      local m = self.canvas:CreateMaskTexture()
      m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      m:SetAllPoints(o)
      o:AddMaskTexture(m)
      o.ring = self.canvas:CreateTexture(nil, "OVERLAY", nil, 1)
      o.ring:SetTexture("Interface\\Buttons\\WHITE8X8")
      o.ring:SetVertexColor(0.08, 0.063, 0.043, 1)
      o.ring:SetPoint("CENTER", o, "CENTER")
      o.ring:SetSize(12, 12)
      local m2 = self.canvas:CreateMaskTexture()
      m2:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      m2:SetAllPoints(o.ring)
      o.ring:AddMaskTexture(m2)
    elseif kind == "text" then
      o = NS.text(self.canvas, 10, NS.COL.muted)
    end
    p[p.n] = o
  end
  o:Show()
  if o.ring then o.ring:Show() end
  return o
end

local function resetPools(self)
  for _, p in pairs(self.pools) do
    for i = 1, #p do
      p[i]:Hide()
      if p[i].ring then p[i].ring:Hide() end
    end
    p.n = 0
  end
end

function Chart.New(parent)
  local self = setmetatable({}, Chart)
  local f = CreateFrame("Frame", nil, parent)
  self.frame = f
  self.canvas = CreateFrame("Frame", nil, f)
  self.canvas:SetAllPoints()
  self.pools = { line = { n = 0 }, fill = { n = 0 }, grid = { n = 0 }, dot = { n = 0 }, text = { n = 0 } }
  self.empty = NS.text(f, 12, NS.COL.muted)
  self.empty:SetPoint("CENTER")
  self.empty:SetWidth(360)
  self.empty:SetWordWrap(true)
  self.empty:SetJustifyH("CENTER")
  self.empty:Hide()
  self.cross = f:CreateTexture(nil, "OVERLAY", nil, 3)
  self.cross:SetColorTexture(1, 1, 1, 0.3)
  self.cross:SetWidth(1)
  self.cross:Hide()
  local tt = CreateFrame("Frame", nil, f)
  tt:SetFrameLevel(f:GetFrameLevel() + 20)
  NS.fill(tt, 0.055, 0.043, 0.027, 0.96):SetAllPoints()
  NS.border(tt, { 0.353, 0.275, 0.125 }, 1)
  tt.head = NS.text(tt, 11, NS.COL.muted)
  tt.head:SetPoint("TOPLEFT", 10, -8)
  tt.rows = {}
  tt:Hide()
  self.tip = tt
  f:EnableMouse(true)
  f:SetScript("OnSizeChanged", function() if self.last then self:Draw(self.last[1], self.last[2]) end end)
  f:SetScript("OnUpdate", function() self:Hover() end)
  f:SetScript("OnLeave", function() self.cross:Hide() self.tip:Hide() end)
  return self
end

function Chart:SetPoint(...) self.frame:SetPoint(...) end
function Chart:SetHeight(h) self.frame:SetHeight(h) end

function Chart:Draw(list, opts)
  opts = opts or {}
  self.last = { list, opts }
  resetPools(self)
  self.S = nil
  self.cross:Hide()
  self.tip:Hide()
  local W, H = self.frame:GetWidth(), self.frame:GetHeight()
  if not W or W < 50 or not H or H < 50 then return end
  local P = { l = 8, r = 64, t = 12, b = 24 }
  local span = opts.span or 0
  local tmax = 0
  for _, s in ipairs(list) do
    for i = #s.t, 1, -1 do if s.v[i] then tmax = math.max(tmax, s.t[i]) break end end
  end
  local t0 = math.huge
  if span > 0 then
    t0 = tmax - span
  else
    for _, s in ipairs(list) do
      for i = 1, #s.t do if s.v[i] then t0 = math.min(t0, s.t[i]) break end end
    end
  end
  local rel = #list > 1 and not opts.abs
  local S, total = {}, 0
  for k, s in ipairs(list) do
    local pts, base = {}, nil
    for i = 1, #s.t do
      local v = s.v[i]
      if v and s.t[i] >= t0 then
        base = base or v
        local y = v
        if rel then y = base ~= 0 and 100 * (v / base - 1) or 0 end
        pts[#pts + 1] = { s.t[i], y, v }
      end
    end
    total = total + #pts
    S[k] = { name = s.name, unit = s.unit, color = s.color or NS.SERIES[k], pts = pts }
  end
  if total < 2 then
    self.empty:SetText(opts.emptyText or "Not enough history in this range yet. Prices are saved every hour, so this fills in quickly.")
    self.empty:Show()
    return
  end
  self.empty:Hide()
  local lo, hi, xa, xb = math.huge, -math.huge, math.huge, -math.huge
  for _, s in ipairs(S) do
    for _, p in ipairs(s.pts) do
      if p[2] < lo then lo = p[2] end
      if p[2] > hi then hi = p[2] end
      if p[1] < xa then xa = p[1] end
      if p[1] > xb then xb = p[1] end
    end
  end
  if hi == lo then
    local d = math.abs(hi) * 0.05
    if d == 0 then d = 1 end
    hi, lo = hi + d, lo - d
  end
  local pad = (hi - lo) * 0.08
  lo, hi = lo - pad, hi + pad
  local iw, ih = W - P.l - P.r, H - P.t - P.b
  local function X(t) return P.l + (xb > xa and (t - xa) / (xb - xa) or 0.5) * iw end
  local function Y(v) return P.b + (v - lo) / (hi - lo) * ih end
  local unit = list[1].unit
  local function label(v)
    if rel then return (v > 0 and "+" or "") .. string.format("%.1f%%", v) end
    if unit == "coin" then return NS.coinShort(v) end
    return string.format("%.1f", v)
  end
  for i = 0, 4 do
    local v = lo + (hi - lo) * i / 4
    local g = pool(self, "grid")
    g:SetColorTexture(1, 1, 1, 0.06)
    g:ClearAllPoints()
    g:SetPoint("BOTTOMLEFT", self.canvas, "BOTTOMLEFT", P.l, Y(v))
    g:SetSize(iw, 1)
    local tx = pool(self, "text")
    tx:ClearAllPoints()
    tx:SetPoint("LEFT", self.canvas, "BOTTOMLEFT", W - P.r + 6, Y(v))
    tx:SetText(label(v))
  end
  if (rel or opts.zero) and lo < 0 and hi > 0 then
    local x, y = P.l, Y(0)
    while x < P.l + iw do
      local g = pool(self, "grid")
      g:SetColorTexture(1, 1, 1, 0.22)
      g:ClearAllPoints()
      g:SetPoint("BOTTOMLEFT", self.canvas, "BOTTOMLEFT", x, y)
      g:SetSize(math.min(3, P.l + iw - x), 1)
      x = x + 6
    end
  end
  local xs = { xa, (xa + xb) / 2, xb }
  local anchors = { "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
  for i = 1, 3 do
    local tx = pool(self, "text")
    tx:ClearAllPoints()
    tx:SetPoint(anchors[i], self.canvas, "BOTTOMLEFT", X(xs[i]), 6)
    tx:SetText(NS.fmtTime(xs[i], xb - xa))
  end
  local maxSeg = math.max(20, math.floor(iw / 2))
  for k, s in ipairs(S) do
    local pts = s.pts
    if #pts > 0 then
      local c = s.color
      local step = math.max(1, math.ceil(#pts / maxSeg))
      local draw = {}
      for i = 1, #pts, step do draw[#draw + 1] = pts[i] end
      if draw[#draw] ~= pts[#pts] then draw[#draw + 1] = pts[#pts] end
      if #S == 1 or (opts.fill and k == 1) then
        local top = CreateColor(c[1], c[2], c[3], 0.3)
        local bottom = CreateColor(c[1], c[2], c[3], 0)
        for i = 1, #draw - 1 do
          local x1, x2 = X(draw[i][1]), X(draw[i + 1][1])
          local y1, y2 = Y(draw[i][2]), Y(draw[i + 1][2])
          local a, b = math.floor(x1 + 0.5), math.floor(x2 + 0.5)
          local n = math.max(1, math.ceil((b - a) / 3))
          for j = 0, n - 1 do
            local sa = a + math.floor((b - a) * j / n + 0.5)
            local sb = a + math.floor((b - a) * (j + 1) / n + 0.5)
            if sb > sa then
              local y = y1 + (y2 - y1) * ((sa + sb) / 2 - x1) / math.max(1, x2 - x1)
              local tex = pool(self, "fill")
              tex:ClearAllPoints()
              tex:SetPoint("BOTTOMLEFT", self.canvas, "BOTTOMLEFT", sa, P.b)
              tex:SetSize(sb - sa, math.max(1, y - P.b))
              tex:SetGradient("VERTICAL", bottom, top)
            end
          end
        end
      end
      for i = 1, #draw - 1 do
        local ln = pool(self, "line")
        ln:SetThickness(2)
        ln:SetColorTexture(c[1], c[2], c[3], 1)
        ln:SetStartPoint("BOTTOMLEFT", self.canvas, X(draw[i][1]), Y(draw[i][2]))
        ln:SetEndPoint("BOTTOMLEFT", self.canvas, X(draw[i + 1][1]), Y(draw[i + 1][2]))
      end
      local lp = pts[#pts]
      local d = pool(self, "dot")
      d:SetVertexColor(c[1], c[2], c[3], 1)
      d:ClearAllPoints()
      d:SetPoint("CENTER", self.canvas, "BOTTOMLEFT", X(lp[1]), Y(lp[2]))
    end
  end
  self.S, self.X, self.P, self.xa, self.xb, self.rel, self.iw = S, X, P, xa, xb, rel, iw
end

function Chart:Hover()
  local f = self.frame
  if not self.S or not f:IsMouseOver() then
    if self.cross:IsShown() then self.cross:Hide() self.tip:Hide() end
    return
  end
  local cx = GetCursorPosition() / f:GetEffectiveScale() - f:GetLeft()
  local P = self.P
  if cx < P.l or cx > P.l + self.iw then self.cross:Hide() self.tip:Hide() return end
  local tx = self.xa + (cx - P.l) / self.iw * (self.xb - self.xa)
  local best
  for _, s in ipairs(self.S) do
    for _, p in ipairs(s.pts) do
      if not best or math.abs(p[1] - tx) < math.abs(best - tx) then best = p[1] end
    end
  end
  if not best then return end
  if best == self.hoverT and self.cross:IsShown() then return end
  self.hoverT = best
  local x = self.X(best)
  self.cross:ClearAllPoints()
  self.cross:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, P.b)
  self.cross:SetHeight(f:GetHeight() - P.t - P.b)
  self.cross:Show()
  local tt = self.tip
  tt.head:SetText(date("%a %H:%M", best))
  local w = tt.head:GetStringWidth() + 20
  local n = 0
  for _, s in ipairs(self.S) do
    local p
    for _, q in ipairs(s.pts) do
      if not p or math.abs(q[1] - best) < math.abs(p[1] - best) then p = q end
    end
    if p then
      n = n + 1
      local r = tt.rows[n]
      if not r then
        r = {}
        r.dot = tt:CreateTexture(nil, "OVERLAY")
        r.dot:SetSize(7, 7)
        r.name = NS.text(tt, 11, NS.COL.ink2)
        r.val = NS.text(tt, 11, NS.COL.ink)
        r.val:SetJustifyH("RIGHT")
        tt.rows[n] = r
      end
      r.dot:SetColorTexture(s.color[1], s.color[2], s.color[3], 1)
      r.dot:ClearAllPoints()
      r.dot:SetPoint("TOPLEFT", 10, -8 - n * 16 - 3)
      r.name:ClearAllPoints()
      r.name:SetPoint("TOPLEFT", 22, -8 - n * 16)
      r.name:SetText(s.name)
      local v = s.unit == "coin" and NS.coin(p[3]) or string.format("%.1f", p[3])
      if self.rel then v = v .. "  " .. NS.pctColored(p[2]) end
      r.val:ClearAllPoints()
      r.val:SetPoint("TOPRIGHT", -10, -8 - n * 16)
      r.val:SetText(v)
      r.dot:Show() r.name:Show() r.val:Show()
      w = math.max(w, 22 + r.name:GetStringWidth() + 16 + r.val:GetStringWidth() + 10)
    end
  end
  for i = n + 1, #tt.rows do tt.rows[i].dot:Hide() tt.rows[i].name:Hide() tt.rows[i].val:Hide() end
  w = math.max(180, w)
  tt:SetSize(w, 16 + (n + 1) * 16)
  tt:ClearAllPoints()
  local left = math.min(x + 12, f:GetWidth() - w - 4)
  tt:SetPoint("TOPLEFT", f, "TOPLEFT", left, -8)
  tt:Show()
end
