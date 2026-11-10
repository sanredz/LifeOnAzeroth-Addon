local ADDON, NS = ...

local V = {}
NS.Value = V

local DAY = 86400
local LISTING_DAYS = 2

local function median(t)
  if #t == 0 then return nil end
  table.sort(t)
  local m = math.floor((#t + 1) / 2)
  if #t % 2 == 1 then return t[m] end
  return (t[m] + t[m + 1]) / 2
end

function V.cut(hk)
  local rs = hk
  if not rs then
    local _
    _, rs = NS.view()
  end
  if rs and string.sub(rs, 2, 2) == "B" then return 0.15 end
  return 0.05
end

function V.depRate()
  local db = NS.db
  local best
  for dur, r in pairs(db and db.depRate or {}) do
    if type(dur) == "number" and type(r) == "number" and (not best or dur < best[1]) then best = { dur, r } end
  end
  return best and best[2] or nil
end

function V.usual(id, hk)
  local h = NS.hist(id, hk)
  local D = LOA_DATA
  if not h or not D or not D.ht then return nil end
  local t = D.ht
  local tmax = t[#t]
  if not tmax then return nil end
  local vals, first = {}, nil
  for i = 1, #t do
    local v = h.med[i]
    if v and v > 0 and t[i] >= tmax - 14 * DAY then
      vals[#vals + 1] = v
      first = first or t[i]
    end
  end
  return median(vals), first and (tmax - first) / DAY or 0
end

local function windowMedian(h, t, from, to)
  local vals = {}
  for i = 1, #t do
    if t[i] > from and t[i] <= to and h.med[i] and h.med[i] > 0 then vals[#vals + 1] = h.med[i] end
  end
  return median(vals)
end

function V.change24(id, now)
  local h = NS.hist(id)
  local D = LOA_DATA
  if not h or not D or not D.ht then return nil end
  local t = D.ht
  local tmax = t[#t]
  if not tmax then return nil end
  local cur = now
  for i = #t, 1, -1 do
    if cur then break end
    if h.med[i] and h.med[i] > 0 then
      if t[i] >= tmax - 2 * 3600 then cur = h.med[i] end
      break
    end
  end
  local prev = windowMedian(h, t, tmax - DAY - 6 * 3600, tmax - DAY)
  if not cur or not prev or prev <= 0 then return nil end
  return (cur / prev - 1) * 100, cur, prev
end

local startCache = {}
function V.salesStart(hk)
  local Vw, rs
  if hk then Vw, rs = LOA_DATA and LOA_DATA.houses and LOA_DATA.houses[hk], hk else Vw, rs = NS.view() end
  local ck = tostring(rs) .. "|" .. tostring(LOA_DATA and LOA_DATA.built)
  local c = startCache[ck]
  if c then return c.v end
  local first
  for id in pairs(Vw and Vw.hist or {}) do
    local h = NS.hist(id, rs)
    local so = h and h.sold
    if so then
      for i = 1, (first or #so + 1) - 1 do
        if so[i] then first = i break end
      end
    end
  end
  startCache[ck] = { v = first }
  return first
end

function V.flow(id, hk)
  local h = NS.hist(id, hk)
  local D = LOA_DATA
  if not h or not D or not D.ht then return nil end
  local t, q, mn, md = D.ht, h.qty, h.min, h.med
  local tmax = t[#t]
  if not tmax then return nil end
  local out, value, hours = 0, 0, 0
  local so = h.sold
  local start = so and V.salesStart(hk)
  if so and start then
    for i = math.max(2, start), #t do
      if t[i] >= tmax - 3 * DAY and t[i - 1] and t[i] - t[i - 1] <= 2 * 3600 then
        hours = hours + (t[i] - t[i - 1]) / 3600
        local n = so[i] or 0
        if q[i] and q[i - 1] then n = math.min(n, math.max(0, q[i - 1] - q[i])) end
        if n > 0 then
          out = out + n
          local p = (mn[i - 1] and mn[i - 1] > 0) and mn[i - 1] or (md[i - 1] and md[i - 1] > 0 and md[i - 1]) or 0
          value = value + n * p
        end
      end
    end
    if hours < 1 then return nil end
    return out / hours * 24, value / hours * 24, true
  end
  for i = 2, #t do
    if t[i] >= tmax - 3 * DAY and t[i - 1] and t[i] - t[i - 1] <= 2 * 3600 and q[i] and q[i - 1] then
      hours = hours + (t[i] - t[i - 1]) / 3600
      if q[i] < q[i - 1] then
        local d = q[i - 1] - q[i]
        out = out + d
        local p = (mn[i - 1] and mn[i - 1] > 0) and mn[i - 1] or md[i - 1] or 0
        value = value + d * p
      end
    end
  end
  if hours < 1 then return nil end
  return out / hours * 24, value / hours * 24
end

local sellCache = {}
local function clientSell(id)
  local v = sellCache[id]
  if v ~= nil then return v or nil end
  local ok, _, _, _, _, _, _, _, _, _, _, sell = pcall(GetItemInfo, id)
  if ok and type(sell) == "number" then
    sellCache[id] = sell
    return sell
  end
  return nil
end

function V.item(id, count, hk)
  local D = NS.Ensure()
  if not D then return nil end
  local cat = D.cat and D.cat[id]
  local r = { id = id, n = count or 1, name = cat and cat[1], q = cat and cat[2], vendor = clientSell(id) or (cat and cat[7]) or 0 }
  local l
  if hk then
    local H = D.houses and D.houses[hk]
    l = H and H.lat and H.lat[id]
  else
    l = NS.latest(D.region, id)
  end
  if l and l[1] and l[1] > 0 then
    r.typical, r.cheapest, r.listed, r.auctions, r.ch24 = l[1], (l[2] and l[2] > 0) and l[2] or nil, l[3] or 0, l[4] or 0, l[5]
  end
  local rate = V.depRate()
  r.depUnit = rate and r.vendor > 0 and math.floor(r.vendor * rate + 0.5) or nil
  r.ev = r.vendor
  if r.typical then
    r.price = r.cheapest and math.min(r.cheapest, r.typical) or r.typical
    r.net = r.price * (1 - V.cut(hk))
    r.usual, r.usualDays = V.usual(id, hk)
    if r.usual and r.usual > 0 then r.vsUsual = (r.typical / r.usual - 1) * 100 end
    local _, sales
    r.perDay, _, sales = V.flow(id, hk)
    r.sales = sales and true or false
    local ahead = sales and (r.auctions + 1) or (r.listed + r.n)
    r.chance = (r.perDay and r.perDay > 0) and math.min(1, r.perDay * LISTING_DAYS / ahead) or 0
    local ifUnsold = r.vendor - (r.depUnit or 0)
    r.ahEv = r.chance * r.net + (1 - r.chance) * ifUnsold
    if r.ahEv > r.vendor then
      r.pick = "ah"
      r.ev = r.ahEv
    else
      r.pick = r.vendor > 0 and "vendor" or "none"
    end
  else
    r.pick = r.vendor > 0 and "vendor" or "none"
  end
  r.total = r.ev * r.n
  r.gain = (r.ev - r.vendor) * r.n
  return r
end

function V.holdings(scope)
  local db = NS.db
  local out, me = {}, NS.Ledger and select(2, NS.Ledger.me())
  local sum = {}
  for key, c in pairs(db and db.chars or {}) do
    if scope.all or key == me then
      for _, where in ipairs({ "bags", "bank" }) do
        if scope[where] and c[where] then
          for id, e in pairs(c[where]) do
            local free = e[1] or 0
            if free > 0 then
              local s = sum[id]
              if not s then s = { n = 0, where = {}, on = {} } sum[id] = s end
              s.n = s.n + free
              s.where[where] = true
              local nm = c.name or key:match("^([^-]+)") or "?"
              s.on[nm] = (s.on[nm] or 0) + free
              s.cls = s.cls or {}
              s.cls[nm] = c.class
            end
          end
        end
      end
    end
  end
  for id, s in pairs(sum) do
    local r = V.item(id, s.n)
    if r then
      r.where = s.where
      local on = {}
      for nm, n in pairs(s.on) do on[#on + 1] = { nm, n, s.cls and s.cls[nm] } end
      table.sort(on, function(a, b) return a[2] > b[2] end)
      r.on = on
      r.onName = on[1] and on[1][1] or ""
      out[#out + 1] = r
    end
  end
  return out
end

function V.stats()
  local db = NS.db
  local by = {}
  local tot = { sold = 0, deps = 0, lost = 0, bought = 0, posts = 0, sales = 0 }
  for _, e in ipairs(db and db.ledger or {}) do
    local id = e.id or (NS.Ledger and NS.Ledger.IdByName(e.name))
    local key = id or e.name
    if key then
      local s = by[key]
      if not s then s = { id = id, name = e.name, posts = 0, posted = 0, deps = 0, sold = 0, soldN = 0, sales = 0, expired = 0, cancelled = 0, bought = 0, boughtN = 0, last = 0 } by[key] = s end
      s.last = math.max(s.last, e.t or 0)
      if e.k == "post" then
        s.posts = s.posts + 1
        s.posted = s.posted + (e.n or 1)
        s.deps = s.deps + (e.d or 0)
        tot.posts = tot.posts + 1
        tot.deps = tot.deps + (e.d or 0)
      elseif e.k == "sold" then
        local net = (e.g or 0) - (e.cut or 0)
        s.sold = s.sold + net
        s.soldN = s.soldN + (e.n or 1)
        s.sales = s.sales + 1
        tot.sold = tot.sold + net
        tot.sales = tot.sales + 1
      elseif e.k == "expired" then
        s.expired = s.expired + 1
      elseif e.k == "cancelled" then
        s.cancelled = s.cancelled + 1
      elseif e.k == "bought" then
        s.bought = s.bought + (e.g or 0)
        s.boughtN = s.boughtN + (e.n or 1)
        tot.bought = tot.bought + (e.g or 0)
      end
    end
  end
  local list = {}
  for _, s in pairs(by) do
    s.unsold = s.expired + s.cancelled
    s.lostDeps = s.posts > 0 and (s.deps / s.posts) * math.min(s.unsold, s.posts) or 0
    tot.lost = tot.lost + s.lostDeps
    s.net = s.sold - s.lostDeps
    s.loser = s.unsold >= 2 and s.sales == 0
    if not s.name and s.id then
      local D = NS.Ensure()
      s.name = D and D.cat[s.id] and D.cat[s.id][1]
    end
    if s.posts + s.sales + s.unsold > 0 then list[#list + 1] = s end
  end
  return list, tot
end

local moverCache = {}
function V.movers()
  local Vw, rs = NS.view()
  local ck = tostring(rs) .. "|" .. tostring(LOA_DATA and LOA_DATA.built)
  if moverCache.key == ck then return moverCache.up, moverCache.dn end
  local up, dn = {}, {}
  for id, l in pairs(Vw and Vw.lat or {}) do
    if Vw.hist and Vw.hist[id] and l[1] and l[1] > 0 then
      local ch, cur, prev = V.change24(id, l[1])
      local perDay, valDay, sales
      if ch then perDay, valDay, sales = V.flow(id) end
      if ch and perDay and perDay > 0 and valDay and valDay > 0 and cur > 0 then
        local moved = math.log(cur / prev) * valDay
        local e = { id = id, typical = l[1], ch = ch, listed = l[3] or 0, perDay = perDay, valDay = valDay, sales = sales, moved = moved, cur = cur, prev = prev }
        if moved > 0 then up[#up + 1] = e elseif moved < 0 then dn[#dn + 1] = e end
      end
    end
  end
  table.sort(up, function(a, b) return a.moved > b.moved end)
  table.sort(dn, function(a, b) return a.moved < b.moved end)
  moverCache.key, moverCache.up, moverCache.dn = ck, up, dn
  return up, dn
end

function V.goldSeries(all)
  local db = NS.db
  local me = NS.Ledger and select(2, NS.Ledger.me())
  local ev = {}
  for key, c in pairs(db and db.chars or {}) do
    if all or key == me then
      for _, g in ipairs(c.gold or {}) do ev[#ev + 1] = { g[1], key, g[2] } end
    end
  end
  table.sort(ev, function(a, b) return a[1] < b[1] end)
  local last, total, t, v = {}, 0, {}, {}
  for _, e in ipairs(ev) do
    total = total - (last[e[2]] or 0) + e[3]
    last[e[2]] = e[3]
    if #t > 0 and t[#t] == e[1] then v[#v] = total else t[#t + 1] = e[1] v[#v + 1] = total end
  end
  return t, v
end

function V.charItems(c)
  local sum = {}
  for _, where in ipairs({ "bags", "bank", "mail" }) do
    for id, e in pairs(c[where] or {}) do
      local free = type(e) == "table" and (e[1] or 0) or e
      if free > 0 then sum[id] = (sum[id] or 0) + free end
    end
  end
  for _, tr in ipairs(c.transit or {}) do
    for id, n in pairs(tr.items or {}) do sum[id] = (sum[id] or 0) + n end
  end
  return sum
end

function V.charWorth(c)
  local D = NS.Ensure()
  if not D then return nil end
  local hk = c.house
  if hk and not (D.houses and D.houses[hk]) then hk = nil end
  local total = 0
  for id, n in pairs(V.charItems(c)) do
    local r = V.item(id, n, hk)
    if r then total = total + r.total end
  end
  local extra = c.mailGold or 0
  for _, tr in ipairs(c.transit or {}) do extra = extra + (tr.g or 0) end
  return math.floor(total + 0.5), extra
end

function V.worthSeries(all)
  local db = NS.db
  local me = NS.Ledger and select(2, NS.Ledger.me())
  local ev = {}
  for key, c in pairs(db and db.chars or {}) do
    if all or key == me then
      for i, g in ipairs(c.gold or {}) do ev[#ev + 1] = { g[1], key, "g", g[2], nil, i } end
      for i, w in ipairs(c.worth or {}) do ev[#ev + 1] = { w[1], key, "w", w[2], w[3], i } end
    end
  end
  table.sort(ev, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[6] < b[6] end)
  local G, I, X = {}, {}, {}
  local t, net, liquid = {}, {}, {}
  for _, e in ipairs(ev) do
    if e[3] == "g" then G[e[2]] = e[4] else I[e[2]] = e[4] X[e[2]] = e[5] or 0 end
    local g, i = 0, 0
    for k, v in pairs(G) do g = g + v + (X[k] or 0) end
    for k, v in pairs(X) do if G[k] == nil then g = g + v end end
    for _, v in pairs(I) do i = i + v end
    if #t > 0 and t[#t] == e[1] then
      net[#net], liquid[#liquid] = g + i, g
    else
      t[#t + 1], net[#net + 1], liquid[#liquid + 1] = e[1], g + i, g
    end
  end
  return t, net, liquid
end
