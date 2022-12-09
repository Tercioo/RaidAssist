
local RA = _G.RaidAssist
local L = LibStub ("AceLocale-3.0"):GetLocale("RaidAssistAddon")
local _
local defaultPriority = 3
local DF = DetailsFramework

local defaultConfig = {
	enabled = false,
	menu_priority = 1,
	frame_scale = 1,
	frame_orientation = "V",
	reverse_order = false,
	pull_timer = 15,
	readycheck_timer = 35,
	hide_in_combat = false,
	hide_not_in_group = true,
}

local textColorEnabled = {r=1, g=1, b=1, a=1}
local textColorDisabled = {r=0.5, g=0.5, b=0.5, a=1}

local raidMarkersIcon = [[Interface\TARGETINGFRAME\UI-RaidTargetingIcons]]
local raidMarkersTexCoord = {l=0, r=0.5, t=0, b=0.5}

local RaidMarkersPlugin = {version = "v0.1", pluginname = "LeaderToolbar", pluginId = "TOBR", displayName = "Raid Markers"}

RaidMarkersPlugin.menu_text = function(plugin)
	if (RaidMarkersPlugin.db.enabled) then
		return raidMarkersIcon, raidMarkersTexCoord, "Raid Markers", textColorEnabled
	else
		return raidMarkersIcon, raidMarkersTexCoord, "Raid Markers", textColorDisabled
	end
end

RaidMarkersPlugin.menu_popup_show = function(plugin, ct_frame, param1, param2)
end

RaidMarkersPlugin.menu_popup_hide = function(plugin, ct_frame, param1, param2)
end

RaidMarkersPlugin.menu_on_click = function(plugin)
end

RaidMarkersPlugin.OnInstall = function(plugin)
	RaidMarkersPlugin.db.menu_priority = defaultPriority
	if (RaidMarkersPlugin.db.enabled) then
		RaidMarkersPlugin.OnEnable(RaidMarkersPlugin)
	end
end

function RaidMarkersPlugin.CanShow()
	local canShow = true

	if (not RaidMarkersPlugin.db.enabled) then
		canShow = false
	end
	if (RaidMarkersPlugin.db.hide_in_combat) then
		if (UnitAffectingCombat("player")) then
			canShow = false
		end
	end
	if (RaidMarkersPlugin.db.hide_not_in_group) then
		if (not IsInGroup()) then
			canShow = false
		end
	end

	--we can't hide or show this frame while the interface is Lockdown
	if (not InCombatLockdown()) then
		if (not canShow) then
			if (RaidMarkersPlugin.ScreenPanel) then
				if (RaidMarkersPlugin.ScreenPanel:IsShown()) then
					RaidMarkersPlugin.ScreenPanel:Hide()
				end
			end
		else
			if (RaidMarkersPlugin.ScreenPanel) then
				if (not RaidMarkersPlugin.ScreenPanel:IsShown()) then
					RaidMarkersPlugin.ScreenPanel:Show()
				end
			end
		end
	end

	return canShow
end

function RaidMarkersPlugin:PLAYER_REGEN_DISABLED()
	if (RaidMarkersPlugin.db.hide_in_combat) then
		RaidMarkersPlugin.CanShow()
	end
end

function RaidMarkersPlugin:PLAYER_REGEN_ENABLED()
	if (RaidMarkersPlugin.db.hide_in_combat) then
		RaidMarkersPlugin.CanShow()
	end
end

function RaidMarkersPlugin:GROUP_ROSTER_UPDATE()
	if (RaidMarkersPlugin.db.hide_not_in_group) then
		RaidMarkersPlugin.CanShow()
	end
end

RaidMarkersPlugin.OnEnable = function(plugin)
	RaidMarkersPlugin:RegisterEvent("PLAYER_REGEN_DISABLED")
	RaidMarkersPlugin:RegisterEvent("PLAYER_REGEN_ENABLED")
	RaidMarkersPlugin:RegisterEvent("GROUP_ROSTER_UPDATE")

	if (not RaidMarkersPlugin.ScreenPanel) then
		RaidMarkersPlugin.CreateScreenPanel()
	end

	RaidMarkersPlugin.CanShow()
end

RaidMarkersPlugin.OnDisable = function(plugin)
	RaidMarkersPlugin:UnregisterEvent("PLAYER_REGEN_DISABLED")
	RaidMarkersPlugin:UnregisterEvent("PLAYER_REGEN_ENABLED")
	RaidMarkersPlugin:UnregisterEvent("GROUP_ROSTER_UPDATE")

	if (RaidMarkersPlugin.ScreenPanel) then
		if (RaidMarkersPlugin.ScreenPanel:IsShown()) then
			RaidMarkersPlugin.ScreenPanel:Hide()
		end
	end
end

RaidMarkersPlugin.OnProfileChanged = function(plugin)
end

function RaidMarkersPlugin.OnShowOnOptionsPanel()
	local OptionsPanel = RaidMarkersPlugin.OptionsPanel
	RaidMarkersPlugin.BuildOptions(OptionsPanel)
end

local alignRaidMarkers = function()
	local ScreenPanel = RaidMarkersScreenFrameRA

	if (ScreenPanel and RaidMarkersPlugin.MarkersButtons) then
		if (RaidMarkersPlugin.db.reverse_order) then
			local o = 1
			for i = 8, 1, -1 do
				local button = RaidMarkersPlugin.MarkersButtons[i]
				button:ClearAllPoints()
				button:SetPoint("topleft", ScreenPanel.reset_markers_button, "topright", 3 + ((o-1) * 21), ScreenPanel.reset_markers_button:GetHeight())
				o = o + 1
			end
		else
			for i = 1, 8 do
				local button = RaidMarkersPlugin.MarkersButtons[i]
				button:ClearAllPoints()
				button:SetPoint("topleft", ScreenPanel.reset_markers_button2, "topright", 3 + ((i-1) * 21), ScreenPanel.reset_markers_button:GetHeight())
			end
		end
	end
end

local adjust_scale = function()
	local ScreenPanel = RaidMarkersScreenFrameRA
	if (ScreenPanel and RaidMarkersPlugin.MarkersButtons) then
		ScreenPanel:SetScale(RaidMarkersPlugin.db.frame_scale)
	end
end

function RaidMarkersPlugin.CreateScreenPanel()
	local ScreenPanel = RaidMarkersPlugin:CreateCleanFrame(RaidMarkersPlugin, "RaidMarkersScreenFrameRA")
	ScreenPanel:SetSize(294, 46)
	RaidMarkersPlugin.ScreenPanel = ScreenPanel
	DetailsFramework:ApplyStandardBackdrop(ScreenPanel)

	local hook_on_mousedown = function(self, mousebutton, capsule)
	end

	local hook_on_mouseup = function(self, mousebutton, capsule)
		if (mousebutton == "LeftButton") then
			SetRaidTargetIcon("target", capsule.IconIndex)
		elseif (mousebutton == "RightButton") then
			SetRaidTargetIcon("target", 0)
		end
	end

	RaidMarkersPlugin.MarkersButtons = {}
	RaidMarkersPlugin.WorldMarkersButtons = {}

	local button_template = {
		backdrop = {edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true},
		backdropcolor = {0, 0, 0, .5},
		backdropbordercolor = {0, 0, 0, 1},
		onentercolor = {1, 1, 1, .5},
		onenterbordercolor = {1, 1, 1, 1},
	}

	local iconIdleColor = {.7, .7, .7}
	local iconActiveColor = {1, 1, 1}

	local buttonOnEnter = function(self)
		self:SetBackdropBorderColor(unpack(button_template.onenterbordercolor))
		self.MyIcon:SetVertexColor(unpack(iconActiveColor))
	end

	local buttonOnLeave = function(self)
		self:SetBackdropBorderColor(unpack(button_template.backdropbordercolor))
		self.MyIcon:SetVertexColor(unpack(iconIdleColor))
	end

	local hookOnEnter = function(self, capsule)
		capsule.MyIcon:SetVertexColor(unpack(iconActiveColor))
	end

	local hookOnLeave = function(self, capsule)
		capsule.MyIcon:SetVertexColor(unpack(iconIdleColor))
	end

	local worldMarkersColors = {
		[1] = 5,
		[2] = 6,
		[3] = 3,
		[4] = 2,
		[5] = 7,
		[6] = 1,
		[7] = 4,
		[8] = 8,
	}

	--buttons for the 8 markers (icons and world markers)
	for i = 1, 8 do
		local button = RaidMarkersPlugin:CreateButton(ScreenPanel, function()end, 20, 20, "", i, _, _, "button" .. i, _, _, button_template)
		button:SetHook("OnMouseDown", hook_on_mousedown)
		button:SetHook("OnMouseUp", hook_on_mouseup)
		button:SetHook("OnEnter", hookOnEnter)
		button:SetHook("OnLeave", hookOnLeave)
		button.IconIndex = i
		button:EnableMouse(true)
		button:SetScript("OnClick", function(self) SetRaidTargetIcon("target", i) end)

		local raidTargetIcon = RaidMarkersPlugin:CreateImage(button, "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_" .. i , 19, 19, "overlay")
		raidTargetIcon:SetPoint("center", button, "center")
		raidTargetIcon:SetVertexColor(unpack(iconIdleColor))
		button.MyIcon = raidTargetIcon
		RaidMarkersPlugin.MarkersButtons[i] = button

		local raidMarkerButton = CreateFrame("button", "LeaderToolbarRaidGroundIcon" .. i, ScreenPanel, "SecureActionButtonTemplate, BackdropTemplate")
		raidMarkerButton:SetAttribute("type1", "macro")
		raidMarkerButton:SetAttribute("type2", "macro")
		raidMarkerButton:SetSize(20, 20)
		raidMarkerButton:RegisterForClicks("AnyDown")
		raidMarkerButton:SetAttribute("macrotext1", "/wm " .. worldMarkersColors [i] .. "")
		raidMarkerButton:SetAttribute("macrotext2", "/cwm " .. worldMarkersColors [i] .. "")
		raidMarkerButton:SetPoint("top", button.widget, "bottom", 0, -0)

		raidMarkerButton:SetScript("OnEnter", buttonOnEnter)
		raidMarkerButton:SetScript("OnLeave", buttonOnLeave)

		raidMarkerButton:SetBackdrop(button_template.backdrop)
		raidMarkerButton:SetBackdropColor(unpack(button_template.backdropcolor))
		raidMarkerButton:SetBackdropBorderColor(unpack(button_template.backdropbordercolor))

		local raidMarkerIcon = RaidMarkersPlugin:CreateImage(button, [[Interface\AddOns\RaidAssist\media\world_markers_icons]] , 18, 18, "overlay")
		raidMarkerIcon:SetTexCoord(((i-1) * 20) / 256, ((i) * 20) / 256, 0, 20/32)
		raidMarkerIcon:SetPoint("center", raidMarkerButton, "center", 0, 0)
		raidMarkerIcon:SetVertexColor(unpack(iconIdleColor))
		raidMarkerButton.MyIcon = raidMarkerIcon
		RaidMarkersPlugin.WorldMarkersButtons [i] = raidMarkerButton
	end

	local openRaidStatusCallback = function()
		RA.OpenMainOptionsByPluginIndex(2)
	end

	local statusButton = RaidMarkersPlugin:CreateButton(ScreenPanel, openRaidStatusCallback, 50, 20, "Status", _, _, _, "statusButton", _, "none", button_template)
	statusButton:SetPoint("topleft", ScreenPanel, "topleft", 3, -3)

	--manage groups
	local openRaidGroupsCallback = function()
		RA.OpenMainOptionsByPluginIndex(3)
	end
	local raidGroupsButton = RaidMarkersPlugin:CreateButton(ScreenPanel, openRaidGroupsCallback, 50, 20, "Groups", _, _, _, "raidGroupsButton", _, "none", button_template)
	raidGroupsButton:SetPoint("topleft", ScreenPanel, "topleft", 3, -23)

	--readycheck and pull
	local doReadyCheckCallback = function()
		DoReadyCheck()
	end
	local readyCheckButton = RaidMarkersPlugin:CreateButton(ScreenPanel, doReadyCheckCallback, 50, 20, "Check", _, _, _, "readyCheckButton", _, "none", button_template)
	readyCheckButton:SetPoint("left", statusButton, "right", 2, 0)

	local function dopull()
		C_PartyInfo.DoCountdown(RaidMarkersPlugin.db.pull_timer)
	end

	local pullButton = RaidMarkersPlugin:CreateButton(ScreenPanel, dopull, 50, 20, "Pull", _, _, _, "pullButton", _, "none", button_template)
	pullButton:SetPoint("left", raidGroupsButton, "right", 2, 0)

	--reset buttons
	RaidMarkersPlugin.remove_self_mark = function(self, deltaTime)
		SetRaidTargetIcon("player", 0)
		local icon = GetRaidTargetIndex("player")
		if (icon) then
			C_Timer.After(0.1, RaidMarkersPlugin.remove_self_mark)
		end
	end

	local resetMarksCallback = function (self)
		for i = 8, 1, -1 do
			SetRaidTargetIcon("player", i)
		end
		C_Timer.After(0.5, RaidMarkersPlugin.remove_self_mark)
	end

	local resetButton = RaidMarkersPlugin:CreateButton(ScreenPanel, resetMarksCallback, 14, 20, "X", _, _, _, "reset_markers_button", _, "none", button_template)
	--resetButton:SetPoint("topleft", ScreenPanel, "topleft", 3 + (8*21), -3)
	resetButton:SetPoint("left", readyCheckButton, "right", 2, 0)

	local resetButton2 = RaidMarkersPlugin:CreateButton(ScreenPanel, ClearRaidMarker, 14, 20, "X", _, _, _, "reset_markers_button2", _, "none", button_template)
	--resetButton2:SetPoint("topleft", ScreenPanel, "topleft", 3 + (8*21), -23)
	resetButton2:SetPoint("left", pullButton, "right", 2, 0)

	--post process
	alignRaidMarkers()
	adjust_scale()
	ScreenPanel:Show()
end

function RaidMarkersPlugin.BuildOptions(frame)
	if (frame.FirstRun) then
		return
	end
	frame.FirstRun = true

	if (RaidMarkersPlugin.db.enabled) then
		if (not RaidMarkersPlugin.ScreenPanel) then
			RaidMarkersPlugin.CreateScreenPanel()
		end
	end

	local on_select_orientation = function (self, fixed_value, value)
		RaidMarkersPlugin.db.frame_orientation = value

	end
	local orientation_options = {
		{value = "H", label = "Horizontal", onclick = on_select_orientation},
		{value = "V", label = "Vertical", onclick = on_select_orientation},
	}

	local options_list = {
		{type = "label", get = function() return "General Options:" end, text_template = RaidMarkersPlugin:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},
		{
			type = "toggle",
			get = function() return RaidMarkersPlugin.db.enabled end,
			set = function (self, fixedparam, value)
				RaidMarkersPlugin.db.enabled = value
				if (value) then
					RaidMarkersPlugin.OnEnable()
				else
					RaidMarkersPlugin.OnDisable()
				end
			end,
			name = "Enabled",
		},

		{type = "blank"},

		{
			type = "toggle",
			get = function() return RaidMarkersPlugin.db.reverse_order end,
			set = function (self, fixedparam, value)
				RaidMarkersPlugin.db.reverse_order = value
				alignRaidMarkers()
			end,
			name = "Reverse Icons",
		},

		{
			type = "toggle",
			get = function() return RaidMarkersPlugin.db.hide_in_combat end,
			set = function (self, fixedparam, value)
				RaidMarkersPlugin.db.hide_in_combat = value
				RaidMarkersPlugin.CanShow()
			end,
			name = "Hide in Combat",
		},
		{
			type = "toggle",
			get = function() return RaidMarkersPlugin.db.hide_not_in_group end,
			set = function (self, fixedparam, value)
				RaidMarkersPlugin.db.hide_not_in_group = value
				RaidMarkersPlugin.CanShow()
			end,
			name = "Hide When not in Group",
		},

		{type = "blank"},

		{
			type = "range",
			get = function() return RaidMarkersPlugin.db.frame_scale end,
			set = function (self, fixedparam, value)
				RaidMarkersPlugin.db.frame_scale = value
				adjust_scale()
			end,
			min = 0.65,
			max = 1.5,
			step = 0.02,
			name = "Scale",
			usedecimals = true
		},
		{
			type = "range",
			get = function() return RaidMarkersPlugin.db.pull_timer end,
			set = function (self, fixedparam, value)
				RaidMarkersPlugin.db.pull_timer = value
			end,
			min = 3,
			max = 20,
			step = 1,
			name = "Pull Timer",
			desc = "How much time the pull time should be.",
		},
	}

	local options_text_template = RaidMarkersPlugin:GetTemplate("font", "OPTIONS_FONT_TEMPLATE")
	local options_dropdown_template = RaidMarkersPlugin:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
	local options_switch_template = RaidMarkersPlugin:GetTemplate("switch", "OPTIONS_CHECKBOX_TEMPLATE")
	local options_slider_template = RaidMarkersPlugin:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE")
	local options_button_template = RaidMarkersPlugin:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE")

	RaidMarkersPlugin:SetAsOptionsPanel(frame)
	options_list.always_boxfirst = true
	RaidMarkersPlugin:BuildMenu(frame, options_list, 0, 0, 300, false, options_text_template, options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template)
end

RA:InstallTrivialPlugin(RaidMarkersPlugin.displayName, "RALeaderToolbar", RaidMarkersPlugin, defaultConfig)