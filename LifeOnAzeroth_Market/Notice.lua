local ADDON, NS = ...

local NEED = "1.0.10"
local URL = "https://github.com/sanredz/LifeOnAzeroth-Addon/releases/latest"

local function verNum(v)
  local a, b, c = string.match(type(v) == "string" and v or "", "^(%d+)%.(%d+)%.?(%d*)")
  if not a then return nil end
  return tonumber(a) * 1000000 + tonumber(b) * 1000 + (tonumber(c) or 0)
end

function NS.oldCompanion()
  local d = LOA_DATA
  if type(d) ~= "table" then return false end
  local have = type(d.app) == "table" and verNum(d.app.v)
  return not have or have < verNum(NEED)
end

local frame

local function build()
  local f = CreateFrame("Frame", "LifeOnAzerothCompanionNotice", UIParent)
  f:SetSize(460, 232)
  f:SetPoint("CENTER", 0, 120)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  NS.fill(f, 0.071, 0.055, 0.035, 0.98):SetAllPoints()
  NS.border(f, NS.COL.frame, 1)
  local ic = NS.iconBox(f, 34)
  ic.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_17")
  ic:SetPoint("TOPLEFT", 18, -16)
  local head = NS.text(f, 16, NS.COL.title, true)
  head:SetPoint("LEFT", ic, "RIGHT", 12, 0)
  head:SetText("Download the new companion app")
  local body = NS.text(f, 12, NS.COL.ink2)
  body:SetPoint("TOPLEFT", 18, -64)
  body:SetWidth(424)
  body:SetWordWrap(true)
  body:SetJustifyH("LEFT")
  body:SetSpacing(3)
  body:SetText("Windows now blocks older versions of the Life on Azeroth Companion as a virus by mistake, so your prices stop updating. Download version " .. NEED .. " or newer, quit the old app from the tray and open the new one.")
  local box = CreateFrame("EditBox", nil, f)
  box:SetPoint("BOTTOMLEFT", 18, 54)
  box:SetPoint("BOTTOMRIGHT", -18, 54)
  box:SetHeight(30)
  box:SetAutoFocus(false)
  box:SetFont(NS.FONT, 12, "")
  box:SetTextColor(NS.COL.ink[1], NS.COL.ink[2], NS.COL.ink[3])
  box:SetTextInsets(10, 10, 0, 0)
  NS.fill(box, 0, 0, 0, 0.6):SetAllPoints()
  NS.border(box, { 0.353, 0.275, 0.125 }, 1)
  box:SetText(URL)
  box:SetCursorPosition(0)
  box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(URL) self:HighlightText() end end)
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText() NS.setBorderColor(self, NS.COL.gold, 0.9) end)
  box:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) self:SetCursorPosition(0) NS.setBorderColor(self, { 0.353, 0.275, 0.125 }, 1) end)
  box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() f:Hide() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  local hint = NS.text(f, 11, NS.COL.muted)
  hint:SetPoint("BOTTOMLEFT", 18, 22)
  hint:SetText("Press " .. NS.color(NS.COL.gold, "Ctrl+C") .. " to copy the link, then paste it into your browser.")
  local ok = NS.button(f, 84, 26, "Close", 12)
  ok:SetPoint("BOTTOMRIGHT", -18, 16)
  NS.border(ok, NS.COL.frameDim, 1)
  ok:SetScript("OnClick", function() f:Hide() end)
  f.box = box
  f:Hide()
  return f
end

function NS.ShowCompanionNotice()
  frame = frame or build()
  frame:Show()
  frame.box:SetFocus()
  frame.box:HighlightText()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  if NS.oldCompanion() then C_Timer.After(3, NS.ShowCompanionNotice) end
end)
