-- HGDKP
-- craz, 2020

-----------------------------
-- Variables
-----------------------------

local _G = getfenv(0)
_G.NRT = AceLibrary("AceAddon-2.0"):new(
	"AceEvent-2.0",
	"AceDB-2.0",
	"AceConsole-2.0",
	"FuBarPlugin-2.0"
)
local addon = _G.NRT
local tablet = AceLibrary("Tablet-2.0")
addon.revision = tonumber(("$Revision: 151 $"):sub(12, -3))
addon.version = (addon.version or "4") .. addon.revision
local updateUIColumnList = true

local an, ns = ...
local guildRanks = {}
local memberRanks = {}
local guildMemberList = {}
local formatters = {}
local outputFormatters = {}

ns.an = {}

local L = setmetatable({}, {__index =
	function(self, key)
		self[key] = key
		return key
	end
})

local attendanceColumns = { "Date", "Zone", "Kills", "Completed" }

local columnTextFunctions = {
	attendance = {
		Date = function(input) return date("%d/%m %H:%M", input.date) end,
		Zone = function(input) return input.zone end,
		Kills = function(input) 
      counter = 0
      for k, v in pairs(input.bosskills) do
        counter = counter +1
      end
      return counter
    end,
    Completed = function(input) 
      if input.completed then
        return "|cff00ff00YES|r"
      end
      return "|cffff1100NO|r"
    end,
	},
}

local table_sort = table.sort
local table_insert = table.insert
local createTrackerFrame = nil
local trackerFrame = nil

-- Lower priority columns are to the left side of the tooltip, higher priority
-- columns are to the right.
local columnPriority = setmetatable({
	Date = 1,
	Zone = 2,
	Kills = 3,
  Completed = 4,
},{__index = function(self, key)
		local max = 0
		for k, v in pairs(self) do
			if v > max then max = v end
		end
		self[key] = max + 1
		return self[key]
	end
})

-- RGB table colors from 0 to 1. i.e. {1,0,0} is fully red.
-- If you don't fill in a color for a column, the default yellow color is used.
-- Note that if two colums have the same name for both the attendance and loot
-- lists, they must have the same color. Like the Date and Note columns.
local columnColors = {
	Date = {1, 1, 0},
	Zone = {1, 1, 1},
	Kills = {1, 1, 1},
	Completed = {1, 1, 1},
}


local frame = CreateFrame("FRAME");
frame:RegisterEvent("ADDON_LOADED");


function frame:OnEvent(event, arg1)
  if event == "ADDON_LOADED" then
    print("HGDKP loaded!")
  end
end

local function startInvites() 
  inviteMessage = "<HGDKP>: Starting raid invites! /w 'hginv' to me if you miss it"
  addon.db.profile.guildInvites = true
  ns.an.sendGuildMessage(inviteMessage)
  ns.an.inviteGuild();
end

-- Initialization

addon.hasIcon = "Interface\\AddOns\\HiGoatDKP\\icons\\goat.tga"

local function set(key, val)
	addon.db.profile[key] = val
end
local function get(key)
	return addon.db.profile[key]
end

local options
options = {
	type = "group",
	args = {
		attendance = {
			type = "header",
			name = L["Attendance"],
			order = 100,
		},
		announce = {
			type = "group",
			name = L["Announce"],
			desc = L["Options for attendance announcements."],
			order = 101,
			args = {
				enable = {
					type = "toggle",
					name = L["Enable"],
					desc = L["Enable or disable auto-announcing when taking attendance.\n\nNote that if this option is disabled, people will not be able to whisper you to be added."],
					get = get,
					set = set,
					passValue = "announceAttendance",
					order = 1,
				},
      },
    },
		announceTimeout = {
			type = "range",
			name = L["Timeout"],
			desc = L["How long, in minutes, the timeout should be from when you take attendance until people can no longer whisper you."],
			order = 102,
			min = 1,
			max = 10,
			step = 1,
			get = get,
			set = set,
			passValue = "announceTimeout",
			disabled = function() return not addon.db.profile.announceAttendance end,
		},
		announceRepeat = {
			type = "range",
			name = L["Repeat Interval"],
			desc = L["How often, in seconds, should the announcement be repeated. 0 means do not repeat."],
			order = 103,
			min = 0,
			max = 600,
			step = 5,
			get = get,
			set = set,
			passValue = "announceRepeat",
			disabled = function() return not addon.db.profile.announceAttendance end,
		},
		gc = {
			type = "header",
			name = L["Guild control"],
			order = 200,
		},
		invite = {
			type = "group",
			name = L["Invites"],
			desc = L["Options for guild invites."],
			order = 201,
			args = {
				enable = {
					type = "toggle",
					name = L["Enable whispers"],
					desc = L["Enable or disable guild invites.\n\nNote that if this option is disabled, people will not be able to whisper you to be invited."],
					get = get,
					set = set,
					passValue = "guildInvites",
				},
				start = {
					type = "execute",
					name = L["Start invites"],
					desc = L["Start invites and enable the whisper function to be invited"],
          func = startInvites,
				},
      },
    },
  },
}

function addon:OnInitialize()
  self.attendanceEnabled = false
  self.currentRaid = nil
  self.currentBoss = nil
	self:RegisterDB("HGDB")
	self:RegisterDefaults("profile", {
		raids = {},
		guildAttendance = true,
		announceAttendance = true,
		guildInvites = false,
		bossKill = true,
		trackerFrameWidth = 300,
		trackerFrameHeight = 420,
		formatter = "higoat",
		dbFormat = 2,
		announceTimeout = 2,
		announceRepeat = 0,
	})
	self.clickableTooltip = true
	self.hasNoColor = true
	self.hideMenuTitle = true
	self.independentProfile = true
	self.OnMenuRequest = options
  self.db.profile.guildInvites = false
	self:RegisterChatCommand("/hgdkp", options, "HGDKP")

  table.insert(UISpecialFrames, "HGDKPTrackerFrame")
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end
	
do
	local tabletData = {
		attendance = {
			category = {},
			functions = {},
		},
	}
	local function columnSorter(a, b)
		if columnPriority[a] < columnPriority[b] then return true
		else return false end
	end
	local function insert(tbl, ...)
		for i = 1, select("#", ...) do
			tbl[#tbl + 1] = select(i, ...)
		end
	end
	local function refixColumns(tbl, func)
		wipe(tabletData[tbl].category)
		wipe(tabletData[tbl].functions)
    local cols={}
		local my_cols = {
      Date = true,
      Zone = true,
      Kills = true,
      Completed = true,
    }
		for k, v in pairs(my_cols) do
			if v then cols[#cols + 1] = k end
		end
		if #cols > 0 then
			table_sort(cols, columnSorter)
			insert(tabletData[tbl].category, "columns", #cols, "showWithoutChildren", false, "child_func", func)
			for i = 1, #cols do
				local n = i == 1 and "" or tostring(i)
				insert(tabletData[tbl].functions, "text" .. n, columnTextFunctions[tbl][cols[i]])
				insert(tabletData[tbl].category, "text" .. n, L[cols[i]])
				if columnColors[cols[i]] then
					insert(
						tabletData[tbl].category,
						"child_text"..n.."R", columnColors[cols[i]][1],
						"child_text"..n.."G", columnColors[cols[i]][2],
						"child_text"..n.."B", columnColors[cols[i]][3]
					)
				end
			end
			wipe(cols)
		end
	end

	function addon:OnDoubleClick()
		self:TakeAttendance()
	end

	function addon:OnTextUpdate()
		if grouped then
			self:SetText("|cff00ff00NRT|r")
		else
			self:SetText("|cffff0000NRT|r")
		end
	end

	-- XXX Hopefully I can optimize this at a later point.
	local tmp = {}
	local function callUnpack(input, ...)
		wipe(tmp)
		for i = 1, select("#", ...) do
			local x = select(i, ...)
			if type(x) == "function" then
				--table_insert(tmp, x(input))
				table_insert(tmp, x(input))
			else
				tmp[#tmp + 1] = x
			end
		end
		return unpack(tmp)
	end

local currentTrack = nil
local trackNoteText = L["Set note for track ID %d."]

local function trackerClickFunc(trackId)
	if type(trackId) ~= "number" then return end
	if IsShiftKeyDown() then
    if addon.db.profile.raids[trackId] then
      table.remove(addon.db.profile.raids, trackId)
    end
	elseif IsControlKeyDown() then
    addon.db.profile.raids[trackId].completed = not addon.db.profile.raids[trackId].completed
	else
		-- Show the text area with the details from this track
		addon:ShowTrackerForRaidIndex(trackId)
	end
end

  function addon:OnTooltipUpdate()
    if updateUIColumnList then
      refixColumns("attendance", trackerClickFunc)
      updateUIColumnList = nil
    end
    if tablelength(addon.db.profile.raids) > 0 then
      local d = tabletData.attendance
      if #d.category > 0 then
        local cat = tablet:AddCategory(unpack(d.category))
        local raidCounter = 1
        for i, v in next, addon.db.profile.raids do
          cat:AddLine("arg1", raidCounter, callUnpack(v, unpack(d.functions)))
          raidCounter = raidCounter + 1
        end
      end
    end
    tablet:SetHint(L["|cffeda55fClick|r a raid to get output for website. |cffeda55fShift-Click|r to remove. |cffeda55fCtrl-Click|r to complete"])
  end
end

function addon:OnEnable(first)
	local popup = _G.StaticPopupDialogs
	if type(popup) ~= "table" then
		popup = {}
	end

	self:RegisterEvent("GUILD_ROSTER_UPDATE")

	if IsInGuild() then GuildRoster() end
end

function addon:GUILD_ROSTER_UPDATE()
	wipe(guildRanks)
	for i = 1, GuildControlGetNumRanks() do
		guildRanks[#guildRanks + 1] = GuildControlGetRankName(i)
	end
	for i = 1, GetNumGuildMembers(true) do
		local name, rank, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
		if name then
			guildMemberList[name] = class
			memberRanks[name] = rank
		end
	end
end

function addon:ShowTrackerForRaidIndex(index)
	createTrackerFrame()

	local raid = addon.db.profile.raids[index]
	if not raid then return end
	if not raid["completed"] then
		self:Print(L["The raid has not yet been completed"])
		return
	end

	local formatter = formatters[self.db.profile.formatter]
	if not formatter then
		self:Print(L["The formatter %s isn't registered."]:format(self.db.profile.formatter))
		return
	end
	local text = formatter(raid, self.db.profile.loot, killedBosses)
	if not text then
		self:Print(L["The formatter %s didn't return any text for the raid ID %d."]:format(self.db.profile.formatter, index))
		return
	end

	setText(text)
	setFrameHeader(date("%d/%m %H:%M", raid.date) .. " " .. raid.zone)
	trackerFrame.trackingId = index
	trackerFrame:Show()
	NRTEditBox:SetFocus()
	NRTEditBox:HighlightText()
end

function createTrackerFrame()
	if trackerFrame then return end

	trackerFrame = CreateFrame("Frame", "HGDKPTrackerFrame", UIParent)
	trackerFrame:Hide()
  table.insert(UISpecialFrames, "HGDKPTrackerFrame")
	local scroll = CreateFrame("ScrollFrame", "NRTScrollFrame", trackerFrame, "UIPanelScrollFrameTemplate")
	local textField = CreateFrame("EditBox", "NRTEditBox", scroll)

	trackerFrame:SetWidth(addon.db.profile.trackerFrameWidth)
	trackerFrame:SetHeight(addon.db.profile.trackerFrameHeight)
  trackerFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
        edgeFile = "Interface\\AddOns\\HiGoatDKP\\textures\\BorderSquare1", edgeSize = 10,
	insets = {left = 2, right = 2, top = 2, bottom = 2},
    })
    trackerFrame:SetBackdropColor(24/255, 24/255, 24/255)
    trackerFrame:SetBackdropBorderColor(100/255, 100/255, 100/255)
    trackerFrame:ClearAllPoints()
    trackerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    trackerFrame:EnableMouse(true)
    trackerFrame:RegisterForDrag("LeftButton")
    trackerFrame:SetMovable(true)
    trackerFrame:SetResizable(true)
    trackerFrame:SetMinResize(280,300)
    trackerFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
	trackerFrame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local s = self:GetEffectiveScale()

		addon.db.profile.posX = self:GetLeft() * s
		addon.db.profile.posY = self:GetTop() * s
	end)
	trackerFrame:SetScript("OnSizeChanged", function(self)
		addon.db.profile.trackerFrameWidth = self:GetWidth()
		addon.db.profile.trackerFrameHeight = self:GetHeight()
	  textField:SetWidth(addon.db.profile.trackerFrameWidth * 0.8)
	end)

	local cheader = trackerFrame:CreateFontString(nil,"OVERLAY")
	cheader:ClearAllPoints()
	cheader:SetWidth(240)
	cheader:SetHeight(15)
	cheader:SetPoint("TOPLEFT", trackerFrame, "TOPLEFT", 7, -14)
	cheader:SetPoint("TOPRIGHT", trackerFrame, "TOPRIGHT", -28, -14)
	cheader:SetFont("Fonts\\FRIZQT__.TTF", 12)
	cheader:SetJustifyH("LEFT")
	setFrameHeader = function(text)
		cheader:SetText(text)
	end
	cheader:SetText("Tracker")
	cheader:SetShadowOffset(.8, -.8)
	cheader:SetShadowColor(0, 0, 0, 1)

	local closebutton = CreateFrame("Button", nil, trackerFrame, "UIPanelCloseButton")
	closebutton:SetSize(30, 30)
	closebutton:SetPoint("TOPRIGHT", -11, -8)
	closebutton:SetScript("OnClick", function()
		trackerFrame:Hide()
		trackerFrame.trackingId = nil
	end)

	scroll:SetPoint("TOPLEFT", trackerFrame, "TOPLEFT", 20, -40)
	scroll:SetPoint("RIGHT", trackerFrame, "RIGHT", -40, 0)
	scroll:SetPoint("BOTTOM", trackerFrame, 0, 20)

	textField:SetFontObject(ChatFontNormal)
	textField:SetMultiLine(true)
	textField:SetWidth(addon.db.profile.trackerFrameWidth * 0.8)
	textField:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	textField:SetScript("OnTextChanged", function() scroll:UpdateScrollChildRect() end)
	textField:SetText("")
	setText = function(text)
		textField:SetText(text)
	end
	textField:SetAutoFocus(false)
	scroll:SetScrollChild(textField)

	-- drag handle, thanks to ammo
	local draghandle = CreateFrame("Frame", nil, trackerFrame)
	draghandle:Hide()
	draghandle:SetFrameLevel(trackerFrame:GetFrameLevel() + 10)
	draghandle:SetWidth(16)
	draghandle:SetHeight(16)
	draghandle:SetPoint("BOTTOMRIGHT", trackerFrame, "BOTTOMRIGHT", -1, 1)
	draghandle:EnableMouse(true)
	draghandle:SetScript("OnMouseDown", function()
		trackerFrame:StartSizing("BOTTOMRIGHT")
	end)
	draghandle:SetScript("OnMouseUp", function()
		trackerFrame:StopMovingOrSizing()
	end)
	draghandle:SetScript("OnEnter", function()
		addon:CancelScheduledEvent("NRTHideDrag")
	end)
	draghandle:SetScript("OnLeave", function(self)
		self:Hide()
	end)

	local texture = draghandle:CreateTexture(nil,"BACKGROUND")
	texture:SetTexture("Interface\\AddOns\\HiGoatDKP\\textures\\draghandle")
	texture:SetWidth(16)
	texture:SetHeight(16)
	texture:SetBlendMode("ADD")
	texture:SetPoint("CENTER", draghandle, "CENTER", 0, 0)

	trackerFrame:SetScript("OnEnter", function()
		draghandle:Show()
	end)
	local function hideHandle()
		draghandle:Hide()
	end
	trackerFrame:SetScript("OnLeave", function()
		addon:ScheduleEvent("NRTHideDrag", hideHandle, 1)
	end)

	local x = addon.db.profile.posX
	local y = addon.db.profile.posY
	if x and y then
		local s = trackerFrame:GetEffectiveScale()
		trackerFrame:ClearAllPoints()
		trackerFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
	end
end

function addon:RegisterOutputFormatter(name, formatter)
	if type(name) ~= "string" or type(formatter) ~= "function" then
		error(("Invalid arguments to :RegisterOutputFormatter, tried registering a formatter without a proper name (%q) or function (%q)."):format(type(name), type(formatter)), 2)
	end
	if formatters[name] then
		error(("Invalid argument to :RegisterOutputFormatter, there's already an output formatter named %q registered."):format(name), 2)
	end
	table_insert(outputFormatters, name)
	formatters[name] = formatter
end

-- Default formatter
addon:RegisterOutputFormatter("higoat", function(raid)
  local kills = {}
  for k, v in pairs(raid.bosskills) do
    local attendance = {}
    for i, name in pairs(v.attendance) do
      table.insert(attendance, '"' .. name .. '"')
    end 
    local kill = L['{"name": "%s", "kill_time": %d, "attendance": [%s]}']:format(k, v.killTime, table.concat(attendance, ","))
    table.insert(kills, kill)
  end
  local output = L['{"date": %d, "zone": "%s", "bosskills": [%s]}']:format(raid.date, raid.zone, table.concat(kills, ","))
  return output
end)



ns.an.addon = addon
ns.an.memberRanks = memberRanks
ns.an.guildMemberList = guildMemberList
ns.an.L = L
