local ADDON, NS = ...

local L = {}
NS.Ledger = L

local MAIL_DAYS = 30

local function now() return time() end

local function charKey()
  local n = UnitName and UnitName("player")
  local r = GetRealmName and GetRealmName()
  if not n or not r then return nil end
  return n .. "-" .. r
end

function L.db()
  local db = NS.db
  if not db then return nil end
  db.chars = db.chars or {}
  db.ledger = db.ledger or {}
  db.mailSeen = db.mailSeen or {}
  db.depRate = db.depRate or {}
  return db
end

function L.me()
  local db, k = L.db(), charKey()
  if not db or not k then return nil end
  local c = db.chars[k]
  if not c then
    c = { gold = {} }
    db.chars[k] = c
  end
  c.gold = c.gold or {}
  if NS.myHouse then c.house = NS.myHouse() or c.house end
  return c, k
end

local function money()
  local ok, m = pcall(GetMoney)
  return ok and type(m) == "number" and m or nil
end

function L.RecordWorth(all)
  local db = L.db()
  if not db or not NS.Value or not LOA_DATA then return end
  local _, me = L.me()
  for key, c in pairs(db.chars) do
    if all or key == me then
      local items, extra = NS.Value.charWorth(c)
      if items then
        c.worth = c.worth or {}
        local last = c.worth[#c.worth]
        if not last or last[2] ~= items or (last[3] or 0) ~= extra then c.worth[#c.worth + 1] = { now(), items, extra } end
      end
    end
  end
end

function L.RecordGold()
  local c = L.me()
  local m = money()
  if not c or not m then return end
  local g = c.gold
  local last = g[#g]
  if last and last[2] == m then return end
  g[#g + 1] = { now(), m }
end

local function info(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local ok, i = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(i) == "table" and i.itemID then return i.itemID, i.stackCount or 1, i.isBound and true or false end
    return nil
  end
end

local function slots(bag)
  if C_Container and C_Container.GetContainerNumSlots then
    local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
    return ok and n or 0
  end
  return 0
end

local function scan(bags)
  local out = {}
  for _, bag in ipairs(bags) do
    for s = 1, slots(bag) do
      local id, n, bound = info(bag, s)
      if id then
        local e = out[id]
        if not e then e = { 0, 0 } out[id] = e end
        if bound then e[2] = e[2] + n else e[1] = e[1] + n end
      end
    end
  end
  return out
end

local function bagIds()
  local t = {}
  for b = 0, (NUM_BAG_SLOTS or 4) do t[#t + 1] = b end
  return t
end

local function bankIds()
  local t = { BANK_CONTAINER or -1 }
  local first = (NUM_BAG_SLOTS or 4) + 1
  for b = first, first + (NUM_BANKBAGSLOTS or 6) - 1 do t[#t + 1] = b end
  return t
end

local bankOpen = false

function L.ScanBags()
  local c = L.me()
  if not c then return end
  c.bags = scan(bagIds())
  c.bagsT = now()
  if bankOpen then
    c.bank = scan(bankIds())
    c.bankT = now()
  end
  pcall(L.RecordWorth)
  if NS.OnLedgerChanged then NS.OnLedgerChanged() end
end

local function rec(e)
  local db = L.db()
  local _, k = L.me()
  if not db or not k then return end
  e.c = k
  db.ledger[#db.ledger + 1] = e
  if NS.OnLedgerChanged then NS.OnLedgerChanged() end
end

local nameToId
function L.IdByName(name)
  if not name then return nil end
  local D = NS.Ensure and NS.Ensure()
  if not D or not D.cat then return nil end
  if not nameToId then
    nameToId = {}
    for id, c in pairs(D.cat) do nameToId[c[1]] = id end
  end
  return nameToId[name]
end

local function vendorOf(id)
  local D = NS.Ensure and NS.Ensure()
  local c = D and D.cat and D.cat[id]
  if c and c[7] and c[7] > 0 then return c[7] end
  local ok, _, _, _, _, _, _, _, _, _, _, sell = pcall(GetItemInfo, id)
  return ok and sell or nil
end

local function itemIdAt(loc)
  if not loc or not C_Item or not C_Item.GetItemID then return nil end
  local ok, id = pcall(C_Item.GetItemID, loc)
  return ok and id or nil
end

local function learnRate(id, duration, quantity, dep)
  if not dep or dep <= 0 or not duration then return end
  local v = vendorOf(id)
  if not v or v <= 0 or not quantity or quantity <= 0 then return end
  local db = L.db()
  if db then db.depRate[duration] = dep / (v * quantity) end
end

local function onPost(kind, loc, duration, quantity, unitPrice)
  local id = itemIdAt(loc)
  if not id then return end
  local dep
  if C_AuctionHouse then
    local ok, d
    if kind == "commodity" and C_AuctionHouse.CalculateCommodityDeposit then
      ok, d = pcall(C_AuctionHouse.CalculateCommodityDeposit, id, duration, quantity)
    elseif C_AuctionHouse.CalculateItemDeposit then
      ok, d = pcall(C_AuctionHouse.CalculateItemDeposit, loc, duration, quantity)
    end
    if ok and type(d) == "number" then dep = d end
  end
  learnRate(id, duration, quantity, dep)
  rec({ k = "post", t = now(), id = id, n = quantity or 1, p = unitPrice, d = dep, dur = duration, h = NS.myHouse and NS.myHouse() })
end

local function learnAtAH()
  if not C_AuctionHouse then return end
  for _, bag in ipairs(bagIds()) do
    for sl = 1, slots(bag) do
      local id, n = info(bag, sl)
      local v = id and vendorOf(id)
      if v and v > 0 then
        local done = false
        for dur = 1, 3 do
          local ok, d
          if C_AuctionHouse.CalculateCommodityDeposit then ok, d = pcall(C_AuctionHouse.CalculateCommodityDeposit, id, dur, 1) end
          if (not ok or type(d) ~= "number" or d <= 0) and C_AuctionHouse.CalculateItemDeposit and ItemLocation then
            local okL, loc = pcall(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, sl)
            if okL and loc then ok, d = pcall(C_AuctionHouse.CalculateItemDeposit, loc, dur, 1) end
          end
          if ok and type(d) == "number" and d > 0 then
            learnRate(id, dur, 1, d)
            done = true
          end
        end
        if done then return end
      end
    end
  end
end

local function hookPosts()
  if not L.mailHooked and SendMail then
    L.mailHooked = true
    hooksecurefunc("SendMail", function(to) if L.onSendMail then pcall(L.onSendMail, to) end end)
  end
  if not C_AuctionHouse or L.hooked then return end
  L.hooked = true
  if C_AuctionHouse.PostCommodity then
    hooksecurefunc(C_AuctionHouse, "PostCommodity", function(loc, duration, quantity, unitPrice)
      pcall(onPost, "commodity", loc, duration, quantity, unitPrice)
    end)
  end
  if C_AuctionHouse.PostItem then
    hooksecurefunc(C_AuctionHouse, "PostItem", function(loc, duration, quantity, bid, buyout)
      local unit = buyout or bid
      if unit and quantity and quantity > 0 then unit = math.floor(unit / quantity) end
      pcall(onPost, "item", loc, duration, quantity, unit)
    end)
  end
end

local function subjectPattern(fmt)
  if type(fmt) ~= "string" then return nil end
  local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)")
  return "^" .. p .. "$"
end

local function scanMailbox()
  local c = L.me()
  if not c or not GetInboxNumItems then return end
  local okN, n = pcall(GetInboxNumItems)
  if not okN or not n then return end
  local items, gold = {}, 0
  for i = 1, n do
    local ok, _, _, _, _, mny, cod, _, itemCount = pcall(GetInboxHeaderInfo, i)
    if ok then
      if (cod or 0) == 0 then gold = gold + (mny or 0) end
      for a = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
        local okI, _, id, _, count = pcall(GetInboxItem, i, a)
        if okI and id then items[id] = (items[id] or 0) + (count or 1) end
      end
    end
  end
  c.mail, c.mailGold, c.mailT, c.transit = items, gold, now(), nil
  pcall(L.RecordWorth)
end

local function onSendMail(to)
  local db = L.db()
  local c, me = L.me()
  if not db or not c or type(to) ~= "string" or to == "" then return end
  local key = to:find("-", 1, true) and to or (to .. "-" .. (GetRealmName and GetRealmName() or ""))
  local r
  for k, v in pairs(db.chars) do
    if k ~= me and string.lower(k) == string.lower(key) then r = v break end
  end
  if not r then return end
  local okM, mny = pcall(GetSendMailMoney)
  local tr = { t = now(), from = me, g = okM and mny or 0, items = {} }
  for a = 1, (ATTACHMENTS_MAX_SEND or 12) do
    local okI, _, id, _, count = pcall(GetSendMailItem, a)
    if okI and id then tr.items[id] = (tr.items[id] or 0) + (count or 1) end
  end
  r.transit = r.transit or {}
  table.insert(r.transit, tr)
  C_Timer.After(1, function() pcall(L.RecordWorth, true) end)
end

L.onSendMail = onSendMail

local function scanMail()
  local db = L.db()
  if not db or not GetInboxNumItems then return end
  pcall(scanMailbox)
  local okN, n = pcall(GetInboxNumItems)
  if not okN or not n then return end
  local expired = subjectPattern(AUCTION_EXPIRED_MAIL_SUBJECT)
  local removed = subjectPattern(AUCTION_REMOVED_MAIL_SUBJECT)
  local t0 = now()
  local found = {}
  for i = 1, n do
    local ok, _, _, sender, subject, mny, _, daysLeft = pcall(GetInboxHeaderInfo, i)
    if ok and subject and daysLeft then
      local arrived = t0 - math.floor((MAIL_DAYS - daysLeft) * 86400)
      local hour = math.floor(arrived / 3600)
      local okI, invType, itemName, who, bid, buyout, deposit, consignment, _, _, _, count = pcall(GetInboxInvoiceInfo, i)
      local e
      if okI and invType == "seller" and itemName then
        e = { k = "sold", name = itemName, id = L.IdByName(itemName), n = count or 1, g = bid or 0, d = deposit or 0, cut = consignment or 0, who = who }
      elseif okI and invType == "buyer" and itemName then
        e = { k = "bought", name = itemName, id = L.IdByName(itemName), n = count or 1, g = bid or buyout or 0, who = who }
      else
        local nm = expired and subject:match(expired)
        local kind = nm and "expired"
        if not nm and removed then nm = subject:match(removed) kind = nm and "cancelled" end
        if nm then
          local okG, gname, gid, _, gcount = pcall(GetInboxItem, i, 1)
          e = { k = kind, name = gname or nm, id = (okG and gid) or L.IdByName(nm), n = (okG and gcount) or 1 }
        end
      end
      if e then
        e.t = arrived
        local key = table.concat({ e.k, e.name or "", e.n or 0, e.g or 0, mny or 0, sender or "" }, "|")
        local g = found[key]
        if not g then g = {} found[key] = g end
        g[#g + 1] = { hour, e }
      end
    end
  end
  for key, list in pairs(found) do
    local seen = db.mailSeen[key] or {}
    local used = {}
    for _, item in ipairs(list) do
      local match
      for si, h in ipairs(seen) do
        if not used[si] and math.abs(h - item[1]) <= 1 then match = si break end
      end
      if match then
        used[match] = true
      else
        seen[#seen + 1] = item[1]
        used[#seen] = true
        rec(item[2])
      end
    end
    db.mailSeen[key] = seen
  end
end

local function pruneMail()
  local db = L.db()
  if not db then return end
  local cut = math.floor((now() - (MAIL_DAYS + 5) * 86400) / 3600)
  for k, hs in pairs(db.mailSeen) do
    for i = #hs, 1, -1 do if hs[i] < cut then table.remove(hs, i) end end
    if #hs == 0 then db.mailSeen[k] = nil end
  end
end

local f = CreateFrame("Frame")
local pending = false
local function later(fn)
  if pending then return end
  pending = true
  C_Timer.After(0.5, function() pending = false pcall(fn) end)
end

function L.Init()
  L.RecordGold()
  C_Timer.After(3, function() pcall(L.RecordWorth, true) end)
  pruneMail()
  hookPosts()
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_MONEY")
  f:RegisterEvent("BAG_UPDATE_DELAYED")
  f:RegisterEvent("BANKFRAME_OPENED")
  f:RegisterEvent("BANKFRAME_CLOSED")
  f:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
  f:RegisterEvent("MAIL_INBOX_UPDATE")
  f:RegisterEvent("ADDON_LOADED")
  f:RegisterEvent("AUCTION_HOUSE_SHOW")
  f:SetScript("OnEvent", function(_, ev, a1)
    if ev == "PLAYER_MONEY" then pcall(L.RecordGold)
    elseif ev == "PLAYER_ENTERING_WORLD" then pcall(L.RecordGold) later(L.ScanBags)
    elseif ev == "BANKFRAME_OPENED" then bankOpen = true later(L.ScanBags)
    elseif ev == "BANKFRAME_CLOSED" then bankOpen = false
    elseif ev == "BAG_UPDATE_DELAYED" or ev == "PLAYERBANKSLOTS_CHANGED" then later(L.ScanBags)
    elseif ev == "MAIL_INBOX_UPDATE" then pcall(scanMail)
    elseif ev == "ADDON_LOADED" then hookPosts()
    elseif ev == "AUCTION_HOUSE_SHOW" then C_Timer.After(1, function() pcall(learnAtAH) end)
    end
  end)
end
