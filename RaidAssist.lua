
local DF = _G ["DetailsFramework"]
if (not DF) then
	print ("|cFFFFAA00Please restart your client to finish update some AddOns.|r")
	return
end

local DATABASE = "RADataBase"
local FOLDERPATH = "RaidAssist"
local _

local unpack = unpack

local SharedMedia = LibStub:GetLibrary ("LibSharedMedia-3.0")
SharedMedia:Register ("font", "Accidental Presidency", [[Interface\Addons\RaidAssist\fonts\Accidental Presidency.ttf]])

SharedMedia:Register ("statusbar", "Iskar Serenity", [[Interface\Addons\RaidAssist\media\bar_serenity]])
SharedMedia:Register ("statusbar", "DGround", [[Interface\AddOns\RaidAssist\media\bar_background]])
SharedMedia:Register ("statusbar", "Details D'ictum", [[Interface\AddOns\RaidAssist\media\bar4]])
SharedMedia:Register ("statusbar", "Details Vidro", [[Interface\AddOns\RaidAssist\media\bar4_vidro]])
SharedMedia:Register ("statusbar", "Details D'ictum (reverse)", [[Interface\AddOns\RaidAssist\media\bar4_reverse]])
SharedMedia:Register ("statusbar", "Details Serenity", [[Interface\AddOns\RaidAssist\media\bar_serenity]])
SharedMedia:Register ("statusbar", "BantoBar", [[Interface\AddOns\RaidAssist\media\BantoBar]])
SharedMedia:Register ("statusbar", "Skyline", [[Interface\AddOns\RaidAssist\media\bar_skyline]])
SharedMedia:Register ("statusbar", "WorldState Score", [[Interface\WorldStateFrame\WORLDSTATEFINALSCORE-HIGHLIGHT]])
SharedMedia:Register ("statusbar", "Details Flat", [[Interface\AddOns\RaidAssist\media\bar_background]])
SharedMedia:Register ("statusbar", "PlaterBackground", [[Interface\AddOns\RaidAssist\media\platebackground]])
SharedMedia:Register ("statusbar", "PlaterTexture", [[Interface\AddOns\RaidAssist\media\platetexture]])
SharedMedia:Register ("statusbar", "PlaterHighlight", [[Interface\AddOns\RaidAssist\media\plateselected]])
SharedMedia:Register ("statusbar", "PlaterFocus", [[Interface\AddOns\RaidAssist\media\overlay_indicator_1]])
SharedMedia:Register ("statusbar", "PlaterHealth", [[Interface\AddOns\RaidAssist\media\nameplate_health_texture]])
SharedMedia:Register ("statusbar", "You Are Beautiful!", [[Interface\AddOns\RaidAssist\media\regular_white]])
SharedMedia:Register ("statusbar", "PlaterBackground 2", [[Interface\AddOns\RaidAssist\media\noise_background]])

--default configs
local defaultConfig = {
	profile = {
		addon = {
			enabled = true,
			show_only_in_raid = false,
			anchor_side = "left",
			anchor_size = 50,
			anchor_color = {r = 0.5, g = 0.5, b = 0.5, a = 1},
			show_shortcuts = true,

			scale_bar = {scale = 1},

			--when on vertical (left or right)
			anchor_y = -100,
			--when in horizontal (top or bottom)
			anchor_x = 0,
		},
		mergedFromRA = false,
		plugins = {},
	}
}

--raid assist options
local options_table = {
	name = "Raid Assist",
	type = "group",
	args = {
		IsEnabled = {
			type = "toggle",
			name = "Is Enabled",
			desc = "Is Enabled",
			order = 1,
			get = function() return _G.RaidAssist.db.profile.addon.enabled end,
			set = function (self, val)
				_G.RaidAssist.db.profile.addon.enabled = not _G.RaidAssist.db.profile.addon.enabled;
			end,
		},
	}
}


--create the raid assist addon
DF:CreateAddOn("RaidAssist", DATABASE, defaultConfig, options_table)
local RA = _G.RaidAssist

do
	local libSerialize = LibStub("AceSerializer-3.0")
	libSerialize:Embed(RA)
end

RA.__index = RA
RA.version = "v1.0"

--store all plugins isntalled
RA.plugins = {}
RA.pluginsTrivial = {}

--store plugin Ids
RA.pluginIds = {}
RA.pluginsTrivialIds = {}

--plugins that have been schedule to install
RA.schedule_install = {}
RA.schedule_install_trivial = {}

--this is the small frame menu to select an option without using /raa
RA.default_small_popup_width = 150
RA.default_small_popup_height = 40

--default backdrop
RA.BackdropBorderColor = {.3, .3, .3, .3}

RA.InstallDir = FOLDERPATH

--plugin database are stored within the raid assist database
function RA:LoadPluginDB(pluginName, bIsInstall)
	local plugin = RA.plugins[pluginName] or RA.pluginsTrivial[pluginName]
	if (not plugin) then
		return
	end

	---@type table
	local pluginSavedConfig = RA.db.profile.plugins[pluginName]

	if (pluginSavedConfig) then
		RA.table.deploy(pluginSavedConfig, plugin.db_default)
	else
		--create a table to save the plugin database
		RA.db.profile.plugins[pluginName] = RA.table.copy({}, plugin.db_default)
	end

	--ensure the plugin has a enabled and menu_priority
	if (plugin.db.enabled == nil) then
		plugin.db.enabled = true
	end
	if (plugin.db.menu_priority == nil) then
		plugin.db.menu_priority = 1
	end

	plugin.db = RA.db.profile.plugins[pluginName]

	if (not bIsInstall) then
		if (plugin.OnProfileChanged) then
			xpcall(plugin.OnProfileChanged, geterrorhandler(), plugin)
		end
	end
end

--make the reload process all over again in case of a profile change
function RA:ReloadPluginDB()
	for pluginName, plugin in pairs(RA.plugins) do
		RA:LoadPluginDB(pluginName)
	end
end

--do the profile thing
function RA:ProfileChanged()
	RA:RefreshMainAnchor()
	if (RaidAssistAnchorOptionsPanel) then
		RaidAssistAnchorOptionsPanel:RefreshOptions()
	end
	RA:ReloadPluginDB()
end

--plugin is loaded, do the initialization
function RA.OnInit()
	RA.InitTime = GetTime()

	--register callbacks
	RA.db.RegisterCallback(RA, "OnProfileChanged", "ProfileChanged")
	RA.db.RegisterCallback(RA, "OnProfileCopied", "ProfileChanged")
	RA.db.RegisterCallback(RA, "OnProfileReset", "ProfileChanged")

	RA.DATABASE = _G[DATABASE]

	for _, pluginTable in ipairs(RA.schedule_install) do
		local pluginName, frameName, pluginObject, pluginDefaultConfig = unpack(pluginTable)
		RA:InstallPlugin(pluginName, frameName, pluginObject, pluginDefaultConfig)
	end

	for _, pluginTable in ipairs(RA.schedule_install_trivial) do
		local pluginName, frameName, pluginObject, pluginDefaultConfig = unpack(pluginTable)
		RA:InstallTrivialPlugin(pluginName, frameName, pluginObject, pluginDefaultConfig)
	end

	RA.mainAnchor = CreateFrame("frame", "RaidAssistUIAnchor", UIParent, "BackdropTemplate")

	RA.mainAnchor:SetScript("OnMouseDown", function(self, button)
		if (button == "LeftButton") then
			RA:OpenAnchorOptionsPanel()
		end
	end)

	local priorityOrder = {}

	--which menus go first
	local priorityFunc = function (plugin1, plugin2)
		if (plugin1.db.enabled and plugin2.db.enabled) then
			return plugin1.db.menu_priority > plugin2.db.menu_priority

		elseif (plugin1.db.enabled) then
			return true

		elseif (plugin2.db.enabled) then
			return false
		end
	end

	--cooltip
	local gameCooltip = GameCooltip
	local iconSize = 14
	local emptyTable = {}
	local firstFrame = 1
	local cooltipBackdrop = {
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Buttons\WHITE8X8]],
		tile = true,
		edgeSize = 1,
		tileSize = 64,
	}

	local cooltipBackdropColor = {0, 0, 0, 0.8}
	local cooltipBackdropBorderColor = {0, 0, 0, 1}

	function RA:GetSortedPluginsInPriorityOrder()
		local pluginListByPriority = {}
		for pluginName, pluginObject in pairs(RA:GetPluginList()) do
			pluginListByPriority [#pluginListByPriority+1] = pluginObject
		end

		table.sort (pluginListByPriority, priorityFunc)
		return pluginListByPriority
	end

	--when the anchor is hovered over, create a menu using cooltip
	RA.mainAnchor:SetScript("OnEnter", function(self)
		table.wipe(priorityOrder)

		for pluginName, pluginObject in pairs (RA:GetPluginList()) do
			priorityOrder[#priorityOrder+1] = pluginObject
		end

		table.sort(priorityOrder, priorityFunc)

		local anchorSide = RA.db.profile.addon.anchor_side
		local anchor1, anchor2, x, y

		if (anchorSide == "left") then
			anchor1, anchor2, x, y = "bottomleft", "bottomright", 0, 0

		elseif (anchorSide == "right") then
			anchor1, anchor2, x, y = "bottomright", "bottomleft", 0, 0

		elseif (anchorSide == "top") then
			anchor1, anchor2, x, y = "topleft", "bottomleft", 0, 0

		elseif (anchorSide == "bottom") then
			anchor1, anchor2, x, y = "bottomleft", "topleft", 0, 0
		end

		gameCooltip:Reset()
		gameCooltip:SetBackdrop(firstFrame, cooltipBackdrop, cooltipBackdropColor, cooltipBackdropBorderColor)

		for index, pluginObject in ipairs(priorityOrder) do
			local iconTexture, iconTexCoord, text, textColor = pluginObject.menu_text(pluginObject)
			local popupFrameShow = pluginObject.menu_popup_show
			local popupFrameHide = pluginObject.menu_popup_hide
			local onClick = pluginObject.menu_on_click

			textColor = textColor or emptyTable
			iconTexCoord = iconTexCoord or emptyTable

			gameCooltip:AddLine(text, _, _, textColor.r, textColor.g, textColor.b, textColor.a, _, _, _, _, 10, "Accidental Presidency")
			gameCooltip:AddIcon(iconTexture, firstFrame, _, iconSize, iconSize, iconTexCoord.l, iconTexCoord.r, iconTexCoord.t, iconTexCoord.b)
			gameCooltip:AddMenu("main", onClick, pluginObject)
			gameCooltip:AddPopUpFrame(popupFrameShow, popupFrameHide, pluginObject)
		end

		gameCooltip:SetType("menu")
		gameCooltip:SetOwner(self, anchor1, anchor2, x, y)
		gameCooltip:Show()

		--need to create the support on cooltip for the extra panel being attached on the menu
		--the plugin fills the panel if it has.
		--fill the click function.
	end)

	local hideCooltip = function()
		if (not GameCooltip2.had_interaction) then
			GameCooltip2:Hide()
		end
	end

	RA.mainAnchor:SetScript("OnLeave", function(self)
		C_Timer.After(1, hideCooltip)
	end)

	RA:RefreshMainAnchor()

	--I don't remember what patch_71 was
	C_Timer.After(10, function()
		if (RA.db and not RA.db.profile.patch_71) then
			RA.db.profile.patch_71 = true
			if (_G["RaidAssistReadyCheck"] and _G["RaidAssistReadyCheck"].db) then
				_G["RaidAssistReadyCheck"].db.enabled = true
			end
		end
	end)
end

--macro to open the /raa panel
local redoRefreshMacros = function()
	RA:RefreshMacros()
end

function RA.GetPluginDB()
	local pluginKeybinds = RA.DATABASE.PluginKeybinds
	if (not pluginKeybinds) then
		pluginKeybinds = {}
		RA.DATABASE.PluginKeybinds = pluginKeybinds
	end
	return pluginKeybinds
end

function RA.GetKeybindForPlugin(pluginId)
	local pluginKeybinds = RA.DATABASE.PluginKeybinds
	return pluginKeybinds[pluginId]
end

function RA.RegisterPluginKeybind(pluginId, keybind)
	local pluginKeybinds = RA.GetPluginDB()
	pluginKeybinds[pluginId] = keybind
end

function RA:RefreshMacros()
	--can't run while in combat
	if (InCombatLockdown()) then
		return C_Timer.After(1, redoRefreshMacros)
	end

	local pluginKeybinds = RA.GetPluginDB()

	for pluginId, keybind in pairs(pluginKeybinds) do
		local doesMacroExists = GetMacroInfo(pluginId)
		if (not doesMacroExists) then
			CreateMacro(pluginId, "WoW_Store", "/raa " .. pluginId) --WoW_Store = icon
		end
		SetBinding(keybind, "MACRO " .. pluginId)
	end
end

function RA.PLAYER_LOGIN()
	if (not RA.RegisteredMacrosOnInit) then
		C_Timer.After(1, RA.RefreshMacros)
		RA.RegisteredMacrosOnInit = true
	end
end

--config the anchor for the floating frame in the UIParent
function RA:RefreshMainAnchor()
	RA.mainAnchor:ClearAllPoints()

	local anchorSide = RA.db.profile.addon.anchor_side

	if (anchorSide == "left" or anchorSide == "right") then
		RA.mainAnchor:SetPoint(anchorSide, UIParent, anchorSide, 0, RA.db.profile.addon.anchor_y)
		RA.mainAnchor:SetSize(2, RA.db.profile.addon.anchor_size)

	elseif (anchorSide == "top" or anchorSide == "bottom") then
		RA.mainAnchor:SetPoint(anchorSide, UIParent, anchorSide, RA.db.profile.addon.anchor_x, 0)
		RA.mainAnchor:SetSize(RA.db.profile.addon.anchor_size, 2)
	end

	RA.mainAnchor:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 64})
	local color = RA.db.profile.addon.anchor_color
	RA.mainAnchor:SetBackdropColor(color.r, color.g, color.b, color.a)

	if (RA.db.profile.addon.show_only_in_raid) then
		if (IsInRaid()) then
			RA.mainAnchor:Show()
		else
			RA.mainAnchor:Hide()
		end
	else
		RA.mainAnchor:Show()
	end

	--won't show in alpha versions
	RA.mainAnchor:Hide()
end


--group managind
RA.playerIsInRaid = false
RA.playerIsInParty = false

RA.playerEnteredInRaidGroup = {}
RA.playerLeftRaidGroup = {}
RA.playerEnteredInPartyGroup = {}
RA.playerLeftPartyGroup = {}

--group roster changed
local groupHandleFrame = CreateFrame("frame")
groupHandleFrame:RegisterEvent ("GROUP_ROSTER_UPDATE")

groupHandleFrame:SetScript("OnEvent", function()
	--check if player entered or left the raid
	if (RA.playerIsInRaid and not IsInRaid()) then
		RA.playerIsInRaid = false
		RA.RaidStateChanged()

	elseif (not RA.playerIsInRaid and IsInRaid()) then
		RA.playerIsInRaid = true
		RA.RaidStateChanged()
	end

	--check if player entered or left a party
	if (RA.playerIsInParty and not IsInGroup()) then
		RA.playerIsInParty = false
		RA.PartyStateChanged()

	elseif (not RA.playerIsInParty and IsInGroup()) then
		RA.playerIsInParty = true
		RA.PartyStateChanged()
	end
end)

--handle when the player enters or leave a raid group
--some plugins registered a callback to know when the player enter or leave a group
function RA.RaidStateChanged()
	if (RA.db.profile.addon.show_only_in_raid) then
		RA:RefreshMainAnchor()
	end

	if (RA.playerIsInRaid) then
		for _, func in ipairs(RA.playerEnteredInRaidGroup) do
			local okey, errortext = pcall(func, true)
			if (not okey) then
				print("error on EnterRaidGroup func:", errortext)
			end
		end
	else
		for _, func in ipairs(RA.playerLeftRaidGroup) do
			local okey, errortext = pcall(func, false)
			if (not okey) then
				print("error on LeaveRaidGroup func:", errortext)
			end
		end
	end
end

--handle when the player enters or leave a party group
function RA.PartyStateChanged()
	if (RA.playerIsInParty) then
		for _, func in ipairs(RA.playerEnteredInPartyGroup) do
			local okey, errortext = pcall(func, true)
			if (not okey) then
				print ("error on EnterPartyGroup func:", errortext)
			end
		end
	else
		for _, func in ipairs(RA.playerEnteredInPartyGroup) do
			local okey, errortext = pcall(func, false)
			if (not okey) then
				print ("error on LeavePartyGroup func:", errortext)
			end
		end
	end
end

--comunication
RA.comm = {}
RA.commPrefix = "RAST"

function RA:CommReceived(commPrefix, data, channel, sourceName)
	--plugin prefix
	local prefix = select(2, RA:Deserialize(data))
	local func = RA.comm[prefix]
	if (func) then
		local values = {RA:Deserialize(data)}
		if (values[1]) then
			table.remove(values, 1) --remove the Deserialize state
			local state, errortext = pcall(func, sourceName, unpack(values)) --move to xp call
			if (not state) then
				RA:Msg ("error on CommPCall: " .. errortext)
			end
		end
	end
end

RA:RegisterComm(RA.commPrefix, "CommReceived")

--combat log event events
local CLEU_Frame = CreateFrame("frame")
CLEU_Frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

RA.CLEU_readEvents = {}
RA.CLEU_registeredEvents = {}

--cahe for fast reading
local isEventRegistered = RA.CLEU_readEvents

CLEU_Frame:SetScript ("OnEvent", function()
	local time, token, hidding, sourceGUID, sourceName, sourceFlag, sourceFlag2, targetGUID, targetName, targetFlag, targetFlag2, spellID, spellName, spellType, amount, overKill, school, resisted, blocked, absorbed, isCritical = CombatLogGetCurrentEventInfo()
	if (isEventRegistered[token]) then
		for _, func in ipairs(RA.CLEU_registeredEvents[token]) do
			pcall(func, time, token, hidding, sourceGUID, sourceName, sourceFlag, sourceFlag2, targetGUID, targetName, targetFlag, targetFlag2, spellID, spellName, spellType, amount, overKill, school, resisted, blocked, absorbed, isCritical)
		end
	end
end)

--events frame
local eventsFrame = CreateFrame("frame")
eventsFrame:RegisterEvent("PLAYER_LOGIN")

eventsFrame:SetScript("OnEvent", function(self, event, ...)
	if (RA[event]) then
		RA[event](...)
	end
end)

--register chat command
SLASH_RaidAssist1 = "/raa"
SLASH_RaidAssist2 = "/raa"
SLASH_RaidAssist3 = "/raidassist"
function SlashCmdList.RaidAssist(msg, editbox)
	RA.HandleSlashCommand(msg)
end

function RA.HandleSlashCommand(text)
	local cmd, value = text:match("(%W)%s(%W)")
	if (cmd and value) then
		RA.OpenMainOptions(cmd, value)
	else
		local command = text
		RA.OpenMainOptions(command)
	end
end