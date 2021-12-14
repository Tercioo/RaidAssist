
local RA = _G.RaidAssist
local L = LibStub("AceLocale-3.0"):GetLocale("RaidAssistAddon")
local LibGroupInSpecT = LibStub:GetLibrary("LibGroupInSpecT-1.1")
local default_priority = 9
local _

local LibWindow = LibStub("LibWindow-1.1")
local SharedMedia = _G.LibStub:GetLibrary("LibSharedMedia-3.0")
local debugMode = false

local GetUnitName = GetUnitName
local Ambiguate = Ambiguate
local UnitExists = UnitExists

local default_config = {
	enabled = true,
	menu_priority = 1,
	cooldowns_enabled = {},
	cooldowns_panels = {},

	--> general config
	locked = false,
	text_font = "Friz Quadrata TT",
	text_size = 11,
	text_color = {r=1, g=1, b=1, a=1},
	text_shadow = false,
	bar_class_color = true,
	bar_fixed_color = {r=.7, g=.7, b=.7, a=1},
	bar_grow_inverse = false,
	bar_height = 20,
	bar_texture = "Iskar Serenity",

	panel_background_color = {r=0, g=0, b=0, a=0.1},
	panel_background_border_color = {r=0, g=0, b=0, a=0.3},
	panel_width = 200,
	panel_positions = {},

	only_in_group = true,
	only_inside_instances = false,
	only_in_raid_group = true,
	only_in_combat = false,
	only_in_raid_encounter = false,

	roster_cache = {},
	tracking_spells_cache = {},
	units_in_the_group = {},
}

--> check for new cooldowns
for spellId, cooldownTable in pairs(LIB_OPEN_RAID_COOLDOWNS_INFO) do
	if (default_config.cooldowns_enabled[spellId] == nil) then
		if (cooldownTable.type == 3 or cooldownTable.type == 4) then
			default_config.cooldowns_enabled[spellId] = true
		end
	end
end

local icon_texcoord = {l=0, r=32/512, t=0, b=1}
local text_color_enabled = {r=1, g=1, b=1, a=1}
local text_color_disabled = {r=0.5, g=0.5, b=0.5, a=1}
local icon_texture = "Interface\\AddOns\\RaidAssist\\media\\plugin_icons"

local Cooldowns = {version = "v0.1", pluginname = "Cooldowns", pluginId = "CDCL", displayName = "Cooldowns"}
_G ["RaidAssistCooldowns"] = Cooldowns
Cooldowns.IsDisabled = true

Cooldowns.ScreenPanels = {}
Cooldowns.Roster = {}
Cooldowns.Deaths = {}
Cooldowns.CooldownSchedules = {}
Cooldowns.RosterIsEnabled = false
Cooldowns.InstanceType = "none"

local trackingSpells = {}
local unitsInTheGroup = {}

--> store the time where the unit last casted a cooldown, this avoid triggering multiple cooldowns when a channel spell spam cast_success
Cooldowns.UnitLastCast = {}

--> when the plugin finishes load and are ready to use
Cooldowns.OnInstall = function (plugin)
	Cooldowns.db.menu_priority = default_priority

	Cooldowns:RegisterForEnterRaidGroup (Cooldowns.OnEnterRaidGroup)
	Cooldowns:RegisterForLeaveRaidGroup (Cooldowns.OnLeaveRaidGroup)

	Cooldowns:RegisterForEnterPartyGroup (Cooldowns.OnEnterPartyGroup)
	Cooldowns:RegisterForLeavePartyGroup (Cooldowns.OnLeavePartyGroup)

	Cooldowns:RegisterEvent ("ZONE_CHANGED_NEW_AREA")
	Cooldowns:RegisterEvent ("PLAYER_REGEN_DISABLED")
	Cooldowns:RegisterEvent ("PLAYER_REGEN_ENABLED")
	Cooldowns:RegisterEvent ("ENCOUNTER_START")
	Cooldowns:RegisterEvent ("ENCOUNTER_END")
	Cooldowns:RegisterEvent ("PLAYER_LOGOUT")

	Cooldowns:RegisterEvent ("UNIT_SPELLCAST_SUCCEEDED", Cooldowns.HandleSpellCast)
end



local getUnitName = function (unitid)
	local name = GetUnitName(unitid, true)
	if (name) then
		return Ambiguate(name, "none")
	else
		return ""
	end
end

--> build the spell list from the framework
local spellList = {}

for specId, cooldowns in pairs (LIB_OPEN_RAID_COOLDOWNS_BY_SPEC) do
	for spellId, cooldownType in pairs(cooldowns) do
		if (cooldownType == 3 or cooldownType == 4) then

			local cooldownInfo = LIB_OPEN_RAID_COOLDOWNS_INFO[spellId]
			if (cooldownInfo) then
				local classTable = spellList[cooldownInfo.class] or {}
				spellList[cooldownInfo.class] = classTable
				
				local specTable = classTable[specId] or {}
				classTable [specId] = specTable
			
				specTable[spellId] = {
					cooldown = cooldownInfo.cooldown,
					need_talent = cooldownInfo.talent,
					type = cooldownType,
					duration = cooldownInfo.duration,
					charges = cooldownInfo.charges,
				}
			end
		end
	end
end

Cooldowns.spellList = spellList

Cooldowns.menu_text = function (plugin)
	if (Cooldowns.db.enabled) then
		return icon_texture, icon_texcoord, "Cooldown Monitor", text_color_enabled
	else
		return icon_texture, icon_texcoord, "Cooldown Monitor", text_color_disabled
	end
end

Cooldowns.menu_popup_show = function (plugin, ct_frame, param1, param2)
	RA:AnchorMyPopupFrame (Cooldowns)
end

Cooldowns.menu_popup_hide = function (plugin, ct_frame, param1, param2)
	Cooldowns.popup_frame:Hide()
end

Cooldowns.menu_on_click = function (plugin)
	RA.OpenMainOptions (Cooldowns)
end

Cooldowns.OnEnable = function (plugin)
	--enabled from the options panel.
end

Cooldowns.OnDisable = function (plugin)
	--disabled from the options panel.
end

Cooldowns.OnProfileChanged = function (plugin)
	if (plugin.db.enabled) then
		Cooldowns.OnEnable (plugin)
		Cooldowns.UpdatePanels()
	else
		Cooldowns.OnDisable (plugin)
	end
	
	if (plugin.options_built) then
		--plugin.main_frame:RefreshOptions()
	end
end

--> check if can show cooldown panels in the user interface
function Cooldowns.CheckForShowPanels (event)

	event = event or "EVENT_STARTUP"

	local show = false

	if (not Cooldowns.OptionsFrame or not Cooldowns.OptionsFrame:IsShown() or not Cooldowns.OptionsFrame:GetParent():IsShown()) then

		local isInInstance = GetInstanceInfo()
		if (Cooldowns.db.only_inside_instances and (Cooldowns.in_instance or isInInstance)) then
			if (debugMode) then print ("show because", 1) end
			show = true
		end

		if (Cooldowns.db.only_in_raid_group and IsInRaid()) then
			if (debugMode) then print ("show because", 2) end
			show = true
		end

		if (Cooldowns.db.only_in_group and IsInGroup()) then
			if (debugMode) then print ("show because", 3) end
			show = true
		end

		if (Cooldowns.db.only_in_combat and (Cooldowns.in_combat or InCombatLockdown() or UnitAffectingCombat ("player"))) then
			if (debugMode) then print ("show because", 4) end
			show = true
		end

		if (Cooldowns.db.only_in_raid_encounter and Cooldowns.in_raid_encounter) then
			if (debugMode) then print ("show because", 5) end
			show = true
		end

	else
		if (debugMode) then print ("show because", "forcing to show") end
		show = true
	end

	for index, panel in ipairs (Cooldowns.db.cooldowns_panels) do
		if (not panel.enabled or not show) then
			Cooldowns.ShowPanelInScreen (panel, false, event)
		else
			Cooldowns.ShowPanelInScreen (panel, true, event)
		end
	end
end

function Cooldowns.OnEnterRaidGroup()
	Cooldowns.in_raid = true
	Cooldowns.CheckForShowPanels ("ENTER_RAID_GROUP")
end

function Cooldowns.OnLeaveRaidGroup()
	if (not IsInGroup()) then
		Cooldowns.playerIsInParty = false
	end

	wipe(trackingSpells)
	wipe(unitsInTheGroup)

	Cooldowns.in_raid = false
	Cooldowns.ResetRoster()
	Cooldowns.CheckForShowPanels ("LEFT_RAID_GROUP")
end

function Cooldowns.OnEnterPartyGroup()
	Cooldowns.playerIsInParty = true
	Cooldowns.CheckForShowPanels ("ENTER_PARTY_GROUP")
end

function Cooldowns.OnLeavePartyGroup()
	Cooldowns.playerIsInParty = false
	if (not IsInRaid()) then
		Cooldowns.in_raid = false
	end
	Cooldowns.ResetRoster()
	Cooldowns.CheckForShowPanels ("LEFT_PARTY_GROUP")
end

function Cooldowns:ZONE_CHANGED_NEW_AREA()
	Cooldowns.in_instance = IsInInstance()
	Cooldowns.CheckForShowPanels ("ZONE_CHANGED")
end

function Cooldowns:PLAYER_REGEN_DISABLED()
	Cooldowns.in_combat = true
	Cooldowns.CheckForShowPanels ("ENTERED_COMBAT")
	Cooldowns.ResetDeathTable()
end

function Cooldowns:PLAYER_REGEN_ENABLED()
	Cooldowns.in_combat = false
	Cooldowns.CheckForShowPanels ("LEFT_COMBAT")
	Cooldowns.ResetDeathTable()
end

function Cooldowns:ENCOUNTER_START()
	Cooldowns.in_raid_encounter = true
	Cooldowns.CheckForShowPanels ("ENCOUNTER_START")
end

function Cooldowns:PLAYER_LOGOUT()
	--cleanup schedules objects

	for i = 1, 12 do --12 classes
		local classTable = Cooldowns.Roster[i]
		for playerName, _ in pairs (classTable) do
			local player = classTable [playerName]
			if (player) then
				local playerSpells = player.spells
				for spellId, spellTable in pairs(playerSpells) do
					spellTable.schedule = nil
				end
			end
		end
	end
end

function Cooldowns:ENCOUNTER_END()
	if (IsInRaid()) then
		--cancel all schedules
		for playerId, schedule in pairs(Cooldowns.CooldownSchedules) do
			Cooldowns:CancelTimer(schedule)
			Cooldowns.CooldownSchedules[playerId] = nil
		end

		--cancel bar timers
		for id, panel in pairs(Cooldowns.ScreenPanels) do
			for _, bar in ipairs(panel.Bars) do
				bar:StopTimer()
				bar.player_spellid = nil
				bar:Hide()
			end
		end
	end

	Cooldowns.RosterUpdate()
	Cooldowns.in_raid_encounter = false
	Cooldowns.CheckForShowPanels("ENCOUNTER_END")
end

Cooldowns.PLAYER_LOGIN = function()
	for i = 1, 12 do --12 classes
		Cooldowns.Roster[i] = {}
	end

	if (IsInGroup()) then
		--copy the roster from previous session into this session
		DetailsFramework.table.deploy(Cooldowns.Roster, Cooldowns.db.roster_cache)
		Cooldowns.db.roster_cache = Cooldowns.Roster

		DetailsFramework.table.deploy(trackingSpells, Cooldowns.db.tracking_spells_cache)
		Cooldowns.db.tracking_spells_cache = trackingSpells

		DetailsFramework.table.deploy(unitsInTheGroup, Cooldowns.db.units_in_the_group)
		Cooldowns.db.units_in_the_group = unitsInTheGroup

	else
		--wipe caches
		wipe(Cooldowns.db.tracking_spells_cache)
		Cooldowns.db.tracking_spells_cache = trackingSpells

		wipe(Cooldowns.db.units_in_the_group)
		Cooldowns.db.units_in_the_group = unitsInTheGroup

		wipe(Cooldowns.db.roster_cache)
		Cooldowns.db.roster_cache = Cooldowns.Roster
		Cooldowns.ResetRoster()
	end

	C_Timer.After (1, Cooldowns.CheckForShowPanels)

	C_Timer.After (2, function() Cooldowns.RosterUpdate() end)
	C_Timer.After (8, function() Cooldowns.RosterUpdate() end)
	C_Timer.After (10, function() Cooldowns.RosterUpdate() end)
end

local panel_prototype = {
	enabled = false,
	cooldowns_raid = true,
	cooldowns_external = true,
}

function Cooldowns.CheckValues (panel)
	Cooldowns.table.deploy (panel, panel_prototype)
end

function Cooldowns:LibGroupInSpecT_UpdateReceived()
	Cooldowns.RosterUpdate()
end

function Cooldowns.ResetRoster()
	--reset roster
	wipe (Cooldowns.Roster)

	for i = 1, 12 do --12 classes
		Cooldowns.Roster [i] = {}
	end

	--cancel all schedules
	for playerId, schedule in pairs (Cooldowns.CooldownSchedules) do
		Cooldowns:CancelTimer (schedule)
		Cooldowns.CooldownSchedules [playerId] = nil
	end

	--cancel bar timers
	for id, panel in pairs (Cooldowns.ScreenPanels) do
		for _, bar in ipairs (panel.Bars) do
			--bar:CancelTimerBar()
			bar.player_spellid = nil
			bar:Hide()
		end
	end
end

function Cooldowns.CheckForRosterReset (event)
	if (event == "ZONE_CHANGED") then
		local _, instanceType = GetInstanceInfo()
		if (instanceType ~= Cooldowns.InstanceType) then
			if (instanceType == "pvp" or instanceType == "arena") then
				--player entered into an battleground or arena
				Cooldowns.RosterUpdate()
			end
		end
		Cooldowns.InstanceType = instanceType

	elseif (event == "ENCOUNTER_END" or event == "PANEL_OPTIONS_UPDATE") then
		Cooldowns.RosterUpdate()
	end
end

local receivedRosterEvent = function()
	return Cooldowns.RosterUpdate()
end

function Cooldowns.CheckUnitCooldowns (unitID, groupType, groupIndex)
	local guid = UnitGUID(unitID)
	local info = LibGroupInSpecT:GetCachedInfo (guid)

	if (not info and guid) then
		--get information from Details!
		if (Details) then
			local talents = Details.cached_talents[guid]
			local specId = Details.cached_specs[guid]

			if (talents and specId) then
				local _, class, classId = UnitClass(unitID)
				local talents2 = {} --transform details talents in cooldowns talents
				for i, talentId in ipairs(talents) do
					talents2[talentId] = true
				end
				info = {class_id = classId, global_spec_id = specId, class = class, talents = talents2}
			end
		end
	end

	if (info and info.class_id and info.global_spec_id and info.global_spec_id > 0) then
		local name = getUnitName(unitID)
		local unitTable = Cooldowns.Roster [info.class_id] [name]
		local _, class = UnitClass(unitID)
		local unitSpells = spellList [info.class or class] and spellList [info.class or class] [info.global_spec_id]
		
		local spellsAdded = {}

		for spellId, spelltable in pairs (unitSpells or {}) do
			local canAdd = true

			--check if a talent is required
			if (spelltable.need_talent and not info.talents [spelltable.need_talent]) then
				canAdd = false
			end

			if (canAdd) then
				if (not unitTable) then
					Cooldowns.Roster [info.class_id] [name] = {}
					unitTable = Cooldowns.Roster [info.class_id] [name]
				end

				unitTable.spells = unitTable.spells or {}

				unitTable.spells [spellId] = unitTable.spells [spellId] or {}
				local amtCharges = spelltable.charges or 1
				if (spelltable.extra_charge_talent and info.talents [spelltable.extra_charge_talent]) then
					amtCharges = amtCharges + (spelltable.charges_extra or 1)
				end

				unitTable.spells[spellId].charges_amt = unitTable.spells [spellId].charges_amt or amtCharges
				unitTable.spells[spellId].charges_max = unitTable.spells [spellId].charges_max or amtCharges
				unitTable.spells[spellId].charges_next = unitTable.spells [spellId].charges_next or 0
				
				unitTable.spells[spellId].type = spelltable.type
				unitTable.spells[spellId].spellid = spellId
				
				spellsAdded [spellId] = true
				trackingSpells [spellId] = true
			end
		end

		if (unitTable and next (unitTable.spells)) then
			unitTable.class = info.class
			unitTable.spec = info.global_spec_id
			unitTable.connected = UnitIsConnected (unitID)
			unitTable.alive = UnitHealth (unitID) > 1

			if (groupType == DF_COOLDOWN_RAID) then
				local _, _, subgroup = GetRaidRosterInfo (groupIndex)
				unitTable.raidgroup = subgroup
			else
				unitTable.raidgroup = 1
			end

			if (not unitTable.alive) then
				Cooldowns.Deaths [name] = true
			else
				Cooldowns.Deaths [name] = nil
			end
			unitTable.name = name

			--> clean up spells not used any more (spec changed)
			for spellId, spell in pairs (unitTable.spells) do
				if (not spellsAdded [spellId]) then
					--> check for schedules for this spell
					local playerId = Cooldowns.GetPlayerSpellId (unitTable, spell)
					local has_schedule = Cooldowns.CooldownSchedules [playerId]
					if (has_schedule) then
						Cooldowns:CancelTimer (has_schedule)
						Cooldowns.CooldownSchedules [playerId] = nil
					end
					--> remove it
					unitTable.spells [spellId] = nil
				end
			end

			unitsInTheGroup[name] = true
		end
	end
end

function Cooldowns.RosterUpdate(needReset)
	if (needReset) then
		Cooldowns.ResetRoster()
	end

	--wipe(unitsInTheGroup)
	--wipe(trackingSpells)

	if (IsInRaid() or IsInGroup()) then
		local GroupId
		if (IsInRaid()) then
			GroupId = "raid"
		else
			GroupId = "party"
		end

		--quick clean up removing players that isn't in the group anymore
		for i = 1, 12 do --12 classes
			local classTable = Cooldowns.Roster[i]
			if (classTable) then
				for playerName, _ in pairs (classTable) do
					if (not UnitInRaid(playerName)) then
						--remove the player from the roster
						classTable[playerName] = nil
						unitsInTheGroup[playerName] = nil
					end
				end
			end
		end

		--built the spell list for each player
		if (GroupId == "party") then
			for i = 1, GetNumGroupMembers()-1 do
				local unitid = GroupId .. i
				Cooldowns.CheckUnitCooldowns (unitid, GroupId, i)
			end
		else
			for i = 1, GetNumGroupMembers() do
				local unitid = GroupId .. i
				Cooldowns.CheckUnitCooldowns (unitid, GroupId, i)
			end
		end

		if (GroupId == "party") then
			Cooldowns.CheckUnitCooldowns("player", 1)
		end

		--check what players isn't on the raid anymore
		for index, classIdTable in pairs (Cooldowns.Roster) do
			for name, _ in pairs (classIdTable) do
				if (not unitsInTheGroup[name]) then
					--check for schedules for this player
					for playerId, schedule in pairs (Cooldowns.CooldownSchedules) do
						local playername = Cooldowns.UnpackPlayerSpellId(playerId)
						if (playername == name) then
							Cooldowns:CancelTimer (schedule)
							Cooldowns.CooldownSchedules [playerId] = nil
						end
					end
					wipe(Cooldowns.Roster[index][name])
					Cooldowns.Roster[index][name] = nil
				end
			end
		end

		Cooldowns.BarControl("roster_update")
	end
end

function Cooldowns.CheckIfNoPanel()
	if (#Cooldowns.db.cooldowns_panels == 0) then
		--create the first panel
		local firstPanel = Cooldowns.CreateNewPanel()
		firstPanel.cooldowns_raid = true
		firstPanel.cooldowns_external = true
	end
end

function Cooldowns.CreateNewPanel()
	local inUse, panelNumber = {}, 1
	for i = 1, #Cooldowns.db.cooldowns_panels do
		local panel = Cooldowns.db.cooldowns_panels [i]
		inUse [tonumber (panel.name:match ("%d+"))] = true
	end
	for i = 1, 999 do
		if (not inUse [i]) then
			panelNumber = i
			break
		end
	end

	local newPanel = Cooldowns.table.copy ({}, panel_prototype)
	tinsert(Cooldowns.db.cooldowns_panels, newPanel)
	newPanel.name = "Panel" .. panelNumber
	newPanel.id = panelNumber
	return newPanel
end

local iconTable = {"", {5/64, 59/64, 5/64, 59/64}}
local setupPlayerBar = function (self, panel, player, spell, bar_index)
	local spellicon = GetSpellTexture(spell.spellid)
	iconTable[1] = spellicon
	self:SetIcon(spellicon, .1, .9, .1, .9)

	self:SetLeftText(Cooldowns:RemoveRealName(player.name))
	self:SetRightText(spell.charges_amt > 1 and spell.charges_amt or "")

	self.spellid = spell.spellid
	self.playername = player.name
	self.player = player

	if (Cooldowns.db.bar_class_color) then
		self:SetStatusBarColor(Cooldowns:ParseColors(player.class))
	else
		self:SetStatusBarColor(Cooldowns:ParseColors(Cooldowns.db.bar_fixed_color))
	end

	local playerSpellid = Cooldowns.GetPlayerSpellId(player, spell)
	panel.PlayerCache [playerSpellid] = bar_index

	--check if this is a new bar for this spell
	if (playerSpellid ~= self.player_spellid) then
		if (spell.charges_amt < 1) then
			--if the charges are charging, set the timer
			--print(playerSpellid)
			--print("time:", spell.charges_next - spell.charges_start_time, " ", select(1, GetSpellInfo(spell.spellid)))
			self:SetTimer (spell.charges_next - spell.charges_start_time)
			--print("3", spell.charges_start_time, spell.charges_next, "dunno, starting cooldown?")
		else
			self:StopTimer()
			--if the spell has charges, set it to full
			self.value = 100
		end
		self.player_spellid = playerSpellid
	end

	if (not player.alive or not player.connected) then
		self:PlayerEnabled (false)
	else
		self:PlayerEnabled (true)
	end
end

local playerBarEnabled = function (self, on)
	if (on) then
		self:SetAlpha (1)
		self.icon_death:Hide()
		self.icon_offline:Hide()
	else
		self:SetAlpha (0.3)
		if (not self.player.alive) then
			self.icon_death:Show()
		end
		if (not self.player.connected) then
			self.icon_offline:Show()
		end
	end
end

local refreshBarSettings = function(self)
	--text font
	local textfont = Cooldowns.db.text_font
	local textsize = Cooldowns.db.text_size
	local textcolor = Cooldowns.db.text_color
	local shadow = Cooldowns.db.text_shadow
	self:SetFont(textfont, textsize, textcolor, shadow)

	--bar settings
	local height = Cooldowns.db.bar_height
	self.height = height
	self.width = self:GetParent():GetWidth()

	self.BarIsInverse = not Cooldowns.db.bar_grow_inverse
	if (not Cooldowns.db.bar_class_color) then
		self.color = Cooldowns.db.bar_fixed_color
	end
	
	self:SetIconSize(height-1, height-1)
	self.icon_death:SetSize (height, height)
	self.icon_offline:SetSize (height, height)

	local texture = SharedMedia:Fetch("statusbar", Cooldowns.db.bar_texture)
	self:SetTexture(texture)

	PixelUtil.SetPoint (self, "topleft", self:GetParent(), "topleft", 2, (-(self.MyIndex-1)*(Cooldowns.db.bar_height+1)) + (-2))
	PixelUtil.SetPoint (self, "topright", self:GetParent(), "topright", -2, (-(self.MyIndex-1)*(Cooldowns.db.bar_height+1)) + (-2))
	
	self:EnableMouse (false)
end

local panelGetBar = function (self, barIndex)
	if (type (barIndex) == "string") then
		barIndex = self.PlayerCache[barIndex]

	else
		if (not self.Bars [barIndex]) then
			--local bar = Cooldowns:CreateBar (self, nil, self:GetWidth(), Cooldowns.db.bar_height, 100, nil, "$parentBar" .. barIndex)
			local bar = DetailsFramework:CreateTimeBar(self, [[Interface\AddOns\Details\images\bar_serenity]], self:GetWidth(), Cooldowns.db.bar_height, 100, nil, "$parentBar" .. barIndex)

			bar:SetFrameLevel(self:GetFrameLevel()+1)
			bar.RightTextIsTimer = true
			bar.BarIsInverse = true
			bar.MyIndex = barIndex
			bar.SetupPlayer = setupPlayerBar
			bar.PlayerEnabled = playerBarEnabled
			bar:EnableMouse(false)

			bar.backgroundInUse = bar:CreateTexture(nil, "background")
			bar.backgroundInUse:SetColorTexture(1, .1, .1, .4)
			bar.backgroundInUse:SetAllPoints()

			bar.icon_death = self.support_frame:CreateTexture (nil, "overlay")
			bar.icon_death:SetTexture ([[Interface\WorldStateFrame\SkullBones]])
			bar.icon_death:SetTexCoord (3/64, 29/64, 3/64, 30/64)
			bar.icon_death:SetPoint ("right", bar.widget, -2, 0)
			bar.icon_death:SetAlpha (0.8)
			bar.icon_death:Hide()
			bar.icon_offline = self.support_frame:CreateTexture (nil, "overlay")
			bar.icon_offline:SetTexture ([[Interface\CHARACTERFRAME\Disconnect-Icon]])
			bar.icon_offline:SetTexCoord (12/64, 52/64, 12/64, 52/64)
			bar.icon_offline:SetAlpha (0.8)
			bar.icon_offline:SetPoint ("right", bar.icon_death, "left", 0, 0)
			bar.icon_offline:Hide()

			--bar.cooldownUpBar = Cooldowns:CreateBar(bar, [[Interface\AddOns\RaidAssist\media\bar_serenity]], bar:GetWidth(), Cooldowns.db.bar_height, 100)
			bar.cooldownUpBar = DetailsFramework:CreateTimeBar(bar, [[Interface\AddOns\Details\images\bar_serenity]], bar:GetWidth(), Cooldowns.db.bar_height, 100, nil, "RaidAssistCDInUseBar" .. barIndex)
			bar.cooldownUpBar:SetStatusBarColor(0, 1, 0)
			bar.cooldownUpBar:SetTexture([[Interface\AddOns\RaidAssist\media\bar_serenity]])
			bar.cooldownUpBar:SetAllPoints()
			bar.cooldownUpBar:Hide()

			bar.cooldownUpBar:SetHook("OnTimerEnd", function(statusBar)
				bar.cooldownUpBar:Hide()
			end)

			--bar:SetHook ("OnTimerEnd", Cooldowns.OnEndBarTimer)
			bar.UpdateSettings = refreshBarSettings
			bar:UpdateSettings()
			self.Bars [barIndex] = bar
		end
	end
	return self.Bars [barIndex]
end

local panelCleanupBars = function (self, barIndex)
	--hide bars from index to #
	for i = 1, barIndex-1 do
		self.Bars[i]:Show()
	end
	for i = barIndex, #self.Bars do
		self.Bars[i]:Hide()
		self.Bars[i].icon_death:Hide()
		self.Bars[i].icon_offline:Hide()
	end
end

function Cooldowns.GetPanelInScreen (id)
	if (not Cooldowns.ScreenPanels [id]) then
		local newScreenPanel = CreateFrame ("frame", "CooldownsScreenFrame" .. id, UIParent, "BackdropTemplate")
		newScreenPanel:EnableMouse (true)
		newScreenPanel:Hide()

		newScreenPanel.Background = newScreenPanel:CreateTexture (nil, "background")
		newScreenPanel.Background:SetPoint ("topleft")
		newScreenPanel.Background:SetPoint ("topright")

		newScreenPanel:SetSize (200, 20)
		newScreenPanel.DontRightClickClose = true
		newScreenPanel.Bars = {}
		newScreenPanel.Spells = {}
		newScreenPanel.PlayerCache = {}
		newScreenPanel.GetBar = panelGetBar
		newScreenPanel.CleanUp = panelCleanupBars

		newScreenPanel.support_frame = CreateFrame ("frame", "CooldownsScreenFrame" .. id .. "Support", newScreenPanel, "BackdropTemplate")
		newScreenPanel.support_frame:SetFrameLevel (newScreenPanel:GetFrameLevel()+2)

		newScreenPanel.AlertFrame = CreateFrame ("frame", "CooldownsScreenFrame" .. id .. "Alert", newScreenPanel, "ActionBarButtonSpellActivationAlert")
		newScreenPanel.AlertFrame:SetFrameStrata ("FULLSCREEN")
		newScreenPanel.AlertFrame:SetPoint ("topleft", newScreenPanel, "topleft", -60, 46)
		newScreenPanel.AlertFrame:SetPoint ("bottomright", newScreenPanel, "bottomright", 60, -46)
		newScreenPanel.AlertFrame:SetAlpha (0.2)
		newScreenPanel.AlertFrame:Hide()

		local debug_title = Cooldowns:CreateLabel (newScreenPanel, "cooldown panel " .. id .. "")
		debug_title:SetPoint ("center", newScreenPanel, "center")
		debug_title:SetPoint ("top", newScreenPanel, "top", 0, -4)
		newScreenPanel.debug_title = debug_title

		newScreenPanel:SetScript ("OnShow", function()
			if (Cooldowns.OptionsFrame and Cooldowns.OptionsFrame:IsShown()) then
				newScreenPanel.AlertFrame.animOut:Stop()
				newScreenPanel.AlertFrame.animIn:Play()
				C_Timer.After (0.5, function() newScreenPanel.AlertFrame.animIn:Stop(); newScreenPanel.AlertFrame.animOut:Play() end)
			end
		end)

		--window position
		local panelOptions = Cooldowns.db.panel_positions ["p" .. id]
		if (not panelOptions) then
			Cooldowns.db.panel_positions ["p" .. id] = {}
			panelOptions = Cooldowns.db.panel_positions ["p" .. id]
		end

		--remove 1px frame move functions
		newScreenPanel:SetScript ("OnMouseDown", nil)
		newScreenPanel:SetScript ("OnMouseUp", nil)

		--use libwindow for positioning
		LibWindow.RegisterConfig (newScreenPanel, panelOptions)
		LibWindow.MakeDraggable (newScreenPanel)
		LibWindow.RestorePosition (newScreenPanel)

		Cooldowns.ScreenPanels [id] = newScreenPanel
		Cooldowns.UpdatePanels()
	end
	
	return Cooldowns.ScreenPanels [id]
end

function Cooldowns.BarControlUnitDisable (name)
	for _, panel in pairs (Cooldowns.ScreenPanels) do
		for _, bar in ipairs (panel.Bars) do
			if (bar.playername == name) then
				bar:PlayerEnabled (false)
			end
		end
	end
end

function Cooldowns.BarControlUnitEnable (name)
	for _, panel in pairs (Cooldowns.ScreenPanels) do
		for _, bar in ipairs (panel.Bars) do
			if (bar.playername == name) then
				bar:PlayerEnabled (true)
			end
		end
	end
end

local playerHealthCheck = function()
	if (IsInRaid()) then
		for i = 1, GetNumGroupMembers() do
			local unit = "raid" .. i
			local health = UnitHealth(unit)
			local name = getUnitName(unit)

			if (health) then
				if (health > 2) then
					if (Cooldowns.Deaths [name]) then
						--> player is alive
						local _, _, classNumber = UnitClass (unit)
						if (classNumber) then
							local player = Cooldowns.Roster [classNumber] [name]
							if (player) then
								player.alive = true
								Cooldowns.BarControlUnitEnable (name)
								Cooldowns.Deaths [name] = nil
							end
						end
					end
				end
			end
		end

	elseif (IsInGroup()) then
		for i = 1, GetNumGroupMembers()-1 do
			local unit = "party" .. i
			local health = UnitHealth(unit)
			local name = getUnitName(unit)

			if (health) then
				if (health > 2) then
					if (Cooldowns.Deaths[name]) then
						--player is alive
						local _, _, classNumber = UnitClass (unit)
						if (classNumber) then
							local player = Cooldowns.Roster [classNumber] [name]
							if (player) then
								player.alive = true
								Cooldowns.BarControlUnitEnable (name)
								Cooldowns.Deaths [name] = nil
							end
						end
					end
				end
			end
		end

		local unit = "player"
		local health = UnitHealth(unit)
		local name = getUnitName(unit)

		if (health) then
			if (health > 2) then
				if (Cooldowns.Deaths[name]) then
					--player is alive
					local _, _, classNumber = UnitClass (unit)
					if (classNumber) then
						local player = Cooldowns.Roster [classNumber] [name]
						if (player) then
							player.alive = true
							Cooldowns.BarControlUnitEnable (name)
							Cooldowns.Deaths [name] = nil
						end
					end
				end
			end
		end
	end
end

local playerHealthEvent = function (event, unit)
	if (not UnitExists (unit)) then
		return
	end

	local health = UnitHealth (unit)
	local name = getUnitName (unit)

	if (health and health < 2) then
		if (not Cooldowns.Deaths [name]) then
			--player just died
			local _, _, classNumber = UnitClass (unit)
			if (classNumber) then
				local player = Cooldowns.Roster [classNumber] [name]
				if (player) then
					player.alive = false
					Cooldowns.BarControlUnitDisable (name)
					Cooldowns.Deaths [name] = true
				end
			end
		end
	else
		if (Cooldowns.Deaths [name]) then
			--player got res
			local _, _, classNumber = UnitClass (unit)
			if (classNumber) then
				local player = Cooldowns.Roster [classNumber] [name]
				if (player) then
					player.alive = true
					Cooldowns.BarControlUnitEnable (name)
					Cooldowns.Deaths [name] = nil
				end
			end
		end
	end
end

local playerConnectedEvent = function (event, unit)
	local name = getUnitName (unit)
	local _, _, classNumber = UnitClass (unit)
	if (classNumber) then
		local player = Cooldowns.Roster [classNumber] [name]
		if (player) then
			player.connected = UnitIsConnected (unit)
			if (player.connected) then
				Cooldowns.BarControlUnitEnable (name)
			else
				Cooldowns.BarControlUnitDisable (name)
			end
		end
	end
end

function Cooldowns.ResetDeathTable()
	wipe (Cooldowns.Deaths)
end

function Cooldowns.ShowPanelInScreen (panel, show, event)
	if (show) then
		if (not Cooldowns.RosterIsEnabled) then
			Cooldowns.RosterIsEnabled = true

			LibGroupInSpecT.RegisterCallback(Cooldowns, "GroupInSpecT_Update", "LibGroupInSpecT_UpdateReceived")
			Cooldowns:RegisterEvent("GROUP_ROSTER_UPDATE", receivedRosterEvent)
			Cooldowns:RegisterEvent("PARTY_MEMBER_DISABLE", playerConnectedEvent)
			Cooldowns:RegisterEvent("PARTY_MEMBER_ENABLE", playerConnectedEvent)
			Cooldowns:RegisterEvent("UNIT_CONNECTION", playerConnectedEvent)
			Cooldowns:RegisterEvent("UNIT_HEALTH", playerHealthEvent)

			Cooldowns.HealthCheck = C_Timer.NewTicker(2, playerHealthCheck)

			Cooldowns.RosterUpdate()
			local _, instanceType = GetInstanceInfo()
			Cooldowns.InstanceType = instanceType
		else
			Cooldowns.CheckForRosterReset(event)
		end

		local myPanel = Cooldowns.GetPanelInScreen (panel.id)
		C_Timer.After(0, function() myPanel:Show() end)

		if (not Cooldowns.OptionsFrame or not Cooldowns.OptionsFrame:IsShown() or not Cooldowns.OptionsFrame:GetParent():IsShown()) then
			if (myPanel.debug_title:IsShown()) then
				myPanel.debug_title:Hide()
			end
		else
			myPanel.debug_title:Show()
		end

		Cooldowns.UpdatePanels()
	else
		if (Cooldowns.ScreenPanels [panel.id]) then
			Cooldowns.ScreenPanels [panel.id]:Hide()
		end
		if (Cooldowns.RosterIsEnabled) then
			local canTurnOff = true
			for _, panel in pairs (Cooldowns.ScreenPanels) do
				if (panel:IsShown()) then
					canTurnOff = nil
					break
				end
			end
			if (canTurnOff) then
				Cooldowns:UnregisterEvent("GROUP_ROSTER_UPDATE")
				LibGroupInSpecT.UnregisterCallback (Cooldowns, "GroupInSpecT_Update")
				Cooldowns.RosterIsEnabled = false
				if (Cooldowns.HealthCheck) then
					Cooldowns.HealthCheck:Cancel()
				end
			end
		end
	end
end

-- ~panel ~frame ~updatepanel
function Cooldowns.UpdatePanels()
	local frameColor = Cooldowns.db.panel_background_color
	for id, panel in pairs (Cooldowns.ScreenPanels) do
		--a texture is used now as the backdrop
		panel.Background:SetColorTexture (frameColor.r, frameColor.g, frameColor.b, frameColor.a)

		--bars
		for _, bar in ipairs (panel.Bars) do
			bar:UpdateSettings()
		end

		if (Cooldowns.db.locked) then
			panel:EnableMouse (false)
			panel:RegisterForDrag()
		else
			panel:EnableMouse (true)
			panel:RegisterForDrag ("LeftButton")
		end

		panel:SetWidth (Cooldowns.db.panel_width)
	end
end

function Cooldowns.HandleSpellCast (event, unit, castGUID, spellID)
	if (trackingSpells [spellID]) then

		--check for cast_success spam from channel spells
		local unitCastCooldown = Cooldowns.UnitLastCast [UnitGUID (unit)]
		if (not unitCastCooldown) then
			unitCastCooldown = {}
			Cooldowns.UnitLastCast [UnitGUID (unit)] = unitCastCooldown
		end

		if (not unitCastCooldown [spellID] or unitCastCooldown [spellID]+5 < GetTime()) then
			unitCastCooldown [spellID] = GetTime()
			--trigger a cooldown usage
			Cooldowns.BarControl ("spell_cast", unit, spellID)
		end
	end
end

function Cooldowns.BarControlCleanUpCache (panel)
	wipe (panel.PlayerCache)
end

function Cooldowns.BarControlUpdatePanelSpells (panel, cooldownRaid, cooldown_external)
	--reset spells
	for spellid, value in pairs (panel.Spells) do
		panel.Spells [spellid] = nil
	end

	--build spells the panel can show
	local cd_enabled = Cooldowns.db.cooldowns_enabled
	for class, classtable in pairs (spellList) do
		for specid, spectable in pairs (classtable) do
			for spellid, spelltable in pairs (spectable) do
				if (cd_enabled [spellid] and (cooldownRaid and spelltable.type == DF_COOLDOWN_RAID) or (cooldown_external and spelltable.type == DF_COOLDOWN_EXTERNAL)) then
					panel.Spells [spellid] = true
				end
			end
		end
	end
end

local sort_alphabetical = function (a, b)
	return b.name < a.name
end
local sort_ascending = function (n1, n2)
	return n1 < n2
end

function Cooldowns.OnEndBarTimer (widget, bar)
	bar.div_timer:Hide() --spark
	return true
end

function Cooldowns.GetPlayerSpellId (player, spell)
	return player.name .. "_" .. spell.spellid
end

function Cooldowns.UnpackPlayerSpellId (playerId)
	local playername, spellid = strsplit ("_", playerId)
	spellid = tonumber (spellid)
	return playername, spellid
end

function Cooldowns.SetBarRightText (bar, charges)
	bar.righttext = charges > 1 and charges or ""
end

function Cooldowns:CooldownReady (param)
	local player, spell, cooldown = unpack(param)

	--checking if the actor already is on max charges due to external resets
	if (spell.charges_amt < spell.charges_max) then
		spell.charges_amt = spell.charges_amt + 1
	end

	Cooldowns.CooldownSchedules [Cooldowns.GetPlayerSpellId(player, spell)] = nil

	if (spell.charges_amt < spell.charges_max) then
		--there is more charges to recharge
		Cooldowns.TriggerCooldown (player, spell, cooldown)
	else
		--we're done with recharges
		spell.charges_next = 0
	end

	for id, panel in pairs (Cooldowns.ScreenPanels) do
		if (panel.Spells [spell.spellid]) then --> this panel is allowed to show this spell
			local bar = panel:GetBar (Cooldowns.GetPlayerSpellId(player, spell))
			if (bar) then
				bar.value = 100
				Cooldowns.SetBarRightText (bar, spell.charges_amt)
				bar:Show()
			end
		end
	end
end

function Cooldowns.TriggerCooldown (player, spell, cooldown)
	spell.charges_next = GetTime() + cooldown
	spell.charges_start_time = GetTime()
	local schedule = Cooldowns:ScheduleTimer ("CooldownReady", cooldown - 0.1, {player, spell, cooldown})
	spell.schedule = schedule
	Cooldowns.CooldownSchedules [Cooldowns.GetPlayerSpellId (player, spell)] = schedule
end

function Cooldowns.BarControl (updateType, unitid, spellid)

	if (updateType == "spell_cast") then
		local name = getUnitName (unitid)
		local _, className, classNumber = UnitClass (unitid)
		local player = Cooldowns.Roster [classNumber] [name]

		if (not player) then
			return
		end
		local spell = player.spells [spellid]

		if (spell and (not spell.latest_usage or spell.latest_usage+0.5 < GetTime())) then
			spell.latest_usage = GetTime()

			--> use one charge
			if (spell.charges_amt == 0) then
				--cooldown ingame got ready before our recharge here in the addon
				--may happen if latency get too high
				local schedule = Cooldowns.CooldownSchedules [Cooldowns.GetPlayerSpellId (player, spell)]
				if (schedule) then
					--canceling the call of CooldownReady() for this spell
					--since it already ready to use
					Cooldowns:CancelTimer (schedule)
				end
				Cooldowns.CooldownSchedules [Cooldowns.GetPlayerSpellId (player, spell)] = nil

				--flag it as free of recharge progress, so we can start a new recharge from zero
				spell.charges_next = 0
			else
				spell.charges_amt = spell.charges_amt - 1
			end

			local spell_blueprint = spellList [className] [player.spec] [spellid]
			local cooldown = spell_blueprint.cooldown

			--if not zero, means a charge is already loading up and we doesn't need trigger a cooldown
			if (spell.charges_next == 0) then
				--no cooldown in progress, start one
				Cooldowns.TriggerCooldown (player, spell, cooldown)
			end

			--if we still have charges, only decrease the charges number on the bar
			if (spell.charges_amt > 0) then
				for id, panel in pairs (Cooldowns.ScreenPanels) do
					if (panel.Spells [spellid]) then --> this panel is allowed to show this spell
						local bar = panel:GetBar (Cooldowns.GetPlayerSpellId (player, spell))
						Cooldowns.SetBarRightText (bar, spell.charges_amt)

						local spellInfo = DetailsFramework.CooldownsInfo[spellid]
						if (spellInfo and type(spellInfo.duration) == "number") then
							bar.cooldownUpBar:SetTimer(spellInfo.duration)
							bar.cooldownUpBar:Show()
							local spellName, _, spellIcon = GetSpellInfo(spellid)
							bar.cooldownUpBar.lefttext = Cooldowns:RemoveRealName(name)
							bar.cooldownUpBar.icon = spellIcon
							bar.cooldownUpBar._icon:SetTexCoord(12/64, 52/64, 12/64, 52/64)
							C_Timer.After(spellInfo.duration, function() bar.cooldownUpBar:Hide() end)

							print("1", spellInfo.duration, spellName)
						end
					end
				end
			else
				--we have zero charges, the bar needs to be shown and trigger an animation
				for id, panel in pairs (Cooldowns.ScreenPanels) do
					if (panel.Spells [spellid]) then --> this panel is allowed to show this spell
						local bar = panel:GetBar(Cooldowns.GetPlayerSpellId(player, spell))
						if (not bar) then
							return
						end
						bar:SetTimer (spell.charges_next - GetTime() - 0.1)
						print("2", spell.charges_next - GetTime() - 0.1, "not known")

						local spellInfo = DetailsFramework.CooldownsInfo[spellid]

						--trigger the upbar with the cooldown effect duration
						if (spellInfo and type(spellInfo.duration) == "number") then
							bar.cooldownUpBar:SetTimer(spellInfo.duration)
							bar.cooldownUpBar:Show()

							local spellIcon = GetSpellTexture(spellid)
							bar.cooldownUpBar:SetLeftText(DetailsFramework:RemoveRealName(name))
							bar.cooldownUpBar:SetIcon(spellIcon, 12/64, 52/64, 12/64, 52/64)
							bar.cooldownUpBar:SetIconSize(bar.cooldownUpBar:GetHeight()-1, bar.cooldownUpBar:GetHeight()-1)
							C_Timer.After(spellInfo.duration, function() bar.cooldownUpBar:Hide() end)
						end
					end
				end
			end
		end

	elseif (updateType == "roster_update") then
		for id, panel in pairs (Cooldowns.ScreenPanels) do
			local cooldownRaid = Cooldowns.db.cooldowns_panels [id].cooldowns_raid
			local cooldown_external = Cooldowns.db.cooldowns_panels [id].cooldowns_external

			--update allowed spells in this panel
			Cooldowns.BarControlUpdatePanelSpells (panel, cooldownRaid, cooldown_external)
			Cooldowns.BarControlCleanUpCache (panel)

			local bar_index = 1

			--get members
			for index, classIdTable in pairs (Cooldowns.Roster) do
				--construct spells
				local players, spells, spellsAdded = {}, {}, {}

				for name, player in pairs (classIdTable) do
					if (player.raidgroup <= 6) then
						local canAdd = false
						for spellid, spelltable in pairs (player.spells) do
							--panel.Spells is empty
							if (panel.Spells [spellid]) then
								if (not spellsAdded [spellid]) then
									tinsert (spells, spellid)
									spellsAdded [spellid] = true
								end
								canAdd = true
							end
						end
						if (canAdd) then
							tinsert (players, player)
						end
					end
				end

				table.sort (players, sort_alphabetical)
				table.sort (spells, sort_ascending)

				--display on the bar
				for i, spellid in ipairs (spells) do
					for _, player in ipairs (players) do
						local bar = panel:GetBar (bar_index)
						local spell = player.spells[spellid]
						--the loop doesn't know the player spec, so this
						--player can be a holy priest and the loop iterating through vampiric embrace from a shadow priest.
						if (spell) then
							bar:SetupPlayer (panel, player, spell, bar_index)
							bar_index = bar_index + 1
						end
					end
				end
			end

			--set panel height
			panel.Background:SetHeight (max ( ((bar_index-1) * (Cooldowns.db.bar_height+1)) + 3, 20))
			panel:CleanUp (bar_index)
		end
	end
end

function Cooldowns.OnShowOnOptionsPanel()
	local OptionsPanel = Cooldowns.OptionsPanel
	Cooldowns.BuildOptions (OptionsPanel)
end

local showScreenPanelAnchor = function()
	Cooldowns.CheckForShowPanels ("ON_OPTIONS_SHOW")
	--show the panel while the options is shown
	for _, screenPanel in pairs (Cooldowns.ScreenPanels) do
		screenPanel:SetBackdrop ({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
		screenPanel:SetBackdropColor (0, 0, 0, 0.84)
		screenPanel:SetBackdropBorderColor (0, 0, 0, 1)
	end
end

local hideScreenPanelAnchor = function()
	C_Timer.After (0.13, Cooldowns.CheckForShowPanels)
	--hide the panels when the options panel is hided
	for _, screenPanel in pairs (Cooldowns.ScreenPanels) do
		screenPanel:SetBackdropColor (0, 0, 0, 0)
		screenPanel:SetBackdropBorderColor (0, 0, 0, 0)
		screenPanel:SetBackdrop (nil)
	end
end


function Cooldowns.BuildOptions (frame)
	if (Cooldowns.OptionsIsBuilt) then
		return
	end
	Cooldowns.OptionsIsBuilt = true

	local main_frame = frame
	main_frame:SetSize (822, 480)
	Cooldowns.OptionsFrame = frame

	Cooldowns.OptionsFrame:SetScript ("OnShow", showScreenPanelAnchor)
	Cooldowns.OptionsFrame:SetScript ("OnHide", hideScreenPanelAnchor)

	Cooldowns.CheckIfNoPanel()

	local currentEditingPanel = Cooldowns.db.cooldowns_panels [1]
	local currentEditingIndex = 1

	--panel dropdown
	local labelCooldownPanel = Cooldowns:CreateLabel (main_frame, "Cooldown Panel:", Cooldowns:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))

	local update_panels_config = function()
		CooldownsOptionsHolder1:RefreshOptions()
		Cooldowns.CheckForShowPanels ("PANEL_OPTIONS_UPDATE")
	end

	function Cooldowns.SelectPanel (_, _, selectedValue)
		currentEditingPanel = Cooldowns.db.cooldowns_panels [selectedValue]
		currentEditingIndex = selectedValue
		update_panels_config()
		Cooldowns.RefreshMainDropdown()
	end

	local buildPanelList = function()
		local t = {}
		for index, panel in ipairs (Cooldowns.db.cooldowns_panels) do
			t [#t+1] = {label = panel.name, value = index, onclick = Cooldowns.SelectPanel}
		end
		return t
	end

	local dropdownCooldownPanel = Cooldowns:CreateDropDown (main_frame, buildPanelList, 1, 140, 20, "dropdownCooldownPanel", _, Cooldowns:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
	labelCooldownPanel:SetPoint (0, 0)
	dropdownCooldownPanel:SetPoint ("left", labelCooldownPanel, "right", 2, 0)

	--new button
	local createFunc = function()
		Cooldowns.CreateNewPanel()
		currentEditingPanel = Cooldowns.db.cooldowns_panels [#Cooldowns.db.cooldowns_panels]
		currentEditingIndex = #Cooldowns.db.cooldowns_panels
		update_panels_config()
		Cooldowns.RefreshMainDropdown()
	end

	local buttonCreatePanel = Cooldowns:CreateButton (main_frame, createFunc, 80, 20, "New Panel", _, _, _, "button_create", _, _, Cooldowns:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Cooldowns:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	buttonCreatePanel:SetPoint ("left", dropdownCooldownPanel, "right", 10 , 0)
	buttonCreatePanel:SetIcon ([[Interface\BUTTONS\UI-CheckBox-Up]], 16, 16, "overlay", {3/32, 28/32, 4/32, 27/32}, {1, 1, 1}, 2, 1, 0)

	--delete button
	function Cooldowns.DeletePanel (self, button, param1)
		tremove (Cooldowns.db.cooldowns_panels, currentEditingIndex)
		Cooldowns.CheckIfNoPanel()

		currentEditingPanel = Cooldowns.db.cooldowns_panels [#Cooldowns.db.cooldowns_panels]
		currentEditingIndex = #Cooldowns.db.cooldowns_panels

		update_panels_config()
		Cooldowns.RefreshMainDropdown()
	end

	local buttonDeletePanel = Cooldowns:CreateButton (main_frame, Cooldowns.DeletePanel, 80, 20, "Remove", _, _, _, "button_delete", _, _, Cooldowns:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Cooldowns:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	buttonDeletePanel:SetPoint ("left", buttonCreatePanel, "right", 10 , 0)
	buttonDeletePanel:SetIcon ([[Interface\BUTTONS\UI-StopButton]], 14, 14, "overlay", {0, 1, 0, 1}, {1, 1, 1}, 2, 1, 0)

	local f = CreateFrame ("frame", "CooldownsOptionsHolder1", main_frame, "BackdropTemplate")
	f:SetSize (1, 1)
	f:SetPoint ("topleft", 0, 0)

	local singleOptions = {
		{
			type = "toggle",
			get = function() return currentEditingPanel.enabled end,
			set = function (self, fixedparam, value)
				currentEditingPanel.enabled = value
				Cooldowns.CheckForShowPanels("PANEL_ENABLED_TOGGLE")
				update_panels_config()
				if (value) then
					C_Timer.After (0.150, showScreenPanelAnchor)
				end
			end,
			name = L["S_ENABLED"],
		},
		{
			type = "toggle",
			get = function() return currentEditingPanel.cooldowns_raid end,
			set = function (self, fixedparam, value) currentEditingPanel.cooldowns_raid = value; Cooldowns.CheckForShowPanels ("TOGGLE_OPTIONS"); update_panels_config() end,
			name = L["S_PLUGIN_COOLDOWNS_RAID_CDS"],
		},
		{
			type = "toggle",
			get = function() return currentEditingPanel.cooldowns_external end,
			set = function (self, fixedparam, value) currentEditingPanel.cooldowns_external = value; Cooldowns.CheckForShowPanels ("TOGGLE_OPTIONS"); update_panels_config() end,
			name = L["S_PLUGIN_COOLDOWNS_EXTERNAL_CDS"],
		},
	}
	
	local options_text_template = Cooldowns:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE")
	local options_dropdown_template = Cooldowns:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
	local options_switch_template = Cooldowns:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE")
	local options_slider_template = Cooldowns:GetTemplate ("slider", "OPTIONS_SLIDER_TEMPLATE")
	local options_button_template = Cooldowns:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE")
	
	RA:BuildMenu (f, singleOptions, 0, -25, 480, true, options_text_template, options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template)	

	local on_select_text_font = function (self, fixed_value, value)
		Cooldowns.db.text_font = value
		Cooldowns.UpdatePanels()
	end

	local set_bar_texture = function (_, _, value) 
		Cooldowns.db.bar_texture = value
		Cooldowns.UpdatePanels()
		update_panels_config()
	end

	local SharedMedia = LibStub:GetLibrary ("LibSharedMedia-3.0")
	local textures = SharedMedia:HashTable ("statusbar")
	local texTable = {}
	for name, texturePath in pairs (textures) do 
		texTable[#texTable+1] = {value = name, label = name, statusbar = texturePath, onclick = set_bar_texture}
	end
	table.sort (texTable, function (t1, t2) return t1.label < t2.label end)

	local advise_panel = CreateFrame ("frame", nil, f, "BackdropTemplate")
	advise_panel:SetPoint ("topleft", f, "topleft", 120, -22)
	advise_panel:SetSize (260, 58)
--	advise_panel:SetBackdrop ({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
--	advise_panel:SetBackdropColor (0, 0, 0, .3)
--	advise_panel:SetBackdropBorderColor (.3, .3, .3, .3)
	local advise_panel_text = advise_panel:CreateFontString (nil, "overlay", "GameFontNormal")
	advise_panel_text:SetPoint ("center", advise_panel, "center")
	advise_panel_text:SetText ("You may create a new panel if you want\nseparate Raid Cooldowns and\nExternal Cooldowns in two panels.")
	DetailsFramework:SetFontColor(advise_panel_text, "silver")
	Cooldowns:SetFontSize (advise_panel_text, 10)

	--> options:
	local options_list = {
		{type = "label", get = function() return "Frame:" end, text_template = Cooldowns:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},
		--background color
		{
			type = "color",
			get = function() local color = Cooldowns.db.panel_background_color; return {color.r, color.g, color.b, color.a} end,
			set = function (self, r, g, b, a) 	
				local color = Cooldowns.db.panel_background_color
				color.r, color.g, color.b, color.a = r, g, b, a
				Cooldowns.UpdatePanels()
			end,
			name = L["S_PLUGIN_FRAME_BACKDROP_COLOR"],
		},
		{
			type = "toggle",
			get = function() return Cooldowns.db.locked end,
			set = function (self, fixedparam, value) Cooldowns.db.locked = value; Cooldowns.UpdatePanels(); end,
			name = L["S_PLUGIN_FRAME_LOCKED"],
		},
		{
			type = "range",
			get = function() return Cooldowns.db.panel_width end,
			set = function (self, fixedparam, value) 
				Cooldowns.db.panel_width = value
				Cooldowns.UpdatePanels()
			end,
			min = 50,
			max = 500,
			step = 1,
			name = "Width",
		},

		{type = "blank"},
		{type = "label", get = function() return "Show Cooldown Panels When:" end, text_template = Cooldowns:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},

		{
			type = "toggle",
			get = function() return Cooldowns.db.only_in_group end,
			set = function (self, fixedparam, value) Cooldowns.db.only_in_group = value; Cooldowns.CheckForShowPanels ("TOGGLE_OPTIONS") end,
			name = L["S_ANCHOR_ONLY_IN_GROUP"],
		},
		{
			type = "toggle",
			get = function() return Cooldowns.db.only_in_raid_group end,
			set = function (self, fixedparam, value) Cooldowns.db.only_in_raid_group = value; Cooldowns.CheckForShowPanels ("TOGGLE_OPTIONS") end,
			name = L["S_ANCHOR_ONLY_IN_RAID"],
		},
		{
			type = "toggle",
			get = function() return Cooldowns.db.only_inside_instances end,
			set = function (self, fixedparam, value) Cooldowns.db.only_inside_instances = value; Cooldowns.CheckForShowPanels ("TOGGLE_OPTIONS") end,
			name = L["S_ANCHOR_ONLY_IN_INSTANCES"],
		},
		{
			type = "toggle",
			get = function() return Cooldowns.db.only_in_combat end,
			set = function (self, fixedparam, value) Cooldowns.db.only_in_combat = value; Cooldowns.CheckForShowPanels ("TOGGLE_OPTIONS") end,
			name = L["S_ANCHOR_ONLY_IN_COMBAT"],
		},
		{
			type = "toggle",
			get = function() return Cooldowns.db.only_in_raid_encounter end,
			set = function (self, fixedparam, value) Cooldowns.db.only_in_raid_encounter = value; Cooldowns.CheckForShowPanels ("TOGGLE_OPTIONS") end,
			name = L["S_ANCHOR_ONLY_IN_ENCOUNTER"],
		},
		
		{type = "label", get = function() return "Text:" end, text_template = Cooldowns:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},
		
		{
			type = "select",
			get = function() return Cooldowns.db.text_font end,
			values = function() return RA:BuildDropDownFontList (on_select_text_font) end,
			name = L["S_PLUGIN_TEXT_FONT"],
		},
		{
			type = "range",
			get = function() return Cooldowns.db.text_size end,
			set = function (self, fixedparam, value) 
				Cooldowns.db.text_size = value
				Cooldowns.UpdatePanels()
			end,
			min = 4,
			max = 32,
			step = 1,
			name = L["S_PLUGIN_TEXT_SIZE"],
		},
		{
			type = "color",
			get = function() 
				return {Cooldowns.db.text_color.r, Cooldowns.db.text_color.g, Cooldowns.db.text_color.b, Cooldowns.db.text_color.a} 
			end,
			set = function (self, r, g, b, a) 
				local color = Cooldowns.db.text_color
				color.r, color.g, color.b, color.a = r, g, b, a
				Cooldowns.UpdatePanels()
			end,
			name = L["S_PLUGIN_TEXT_COLOR"],
		},
		{
			type = "toggle",
			get = function() return Cooldowns.db.text_shadow end,
			set = function (self, fixedparam, value) 
				Cooldowns.db.text_shadow = value
				Cooldowns.UpdatePanels()
			end,
			name = L["S_PLUGIN_TEXT_SHADOW"],
		},

		{type = "label", get = function() return "Bar:" end, text_template = Cooldowns:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},

		{
			type = "toggle",
			get = function() return Cooldowns.db.bar_grow_inverse end,
			set = function (self, fixedparam, value) 
				Cooldowns.db.bar_grow_inverse = value
				Cooldowns.UpdatePanels()
				update_panels_config()
			end,
			name = L["S_GROW_INVERSE"],
		},
		{
			type = "range",
			get = function() return Cooldowns.db.bar_height end,
			set = function (self, fixedparam, value) 
				Cooldowns.db.bar_height = value
				Cooldowns.UpdatePanels()
				update_panels_config()
			end,
			min = 4,
			max = 32,
			step = 1,
			name = L["S_HEIGHT"],
		},
		{
			type = "select",
			get = function() return Cooldowns.db.bar_texture end,
			values = function() return texTable end,
			name = "Texture",
		},

		{
			type = "toggle",
			get = function() return Cooldowns.db.bar_class_color end,
			set = function (self, fixedparam, value) 
				Cooldowns.db.bar_class_color = value
				Cooldowns.UpdatePanels()
				update_panels_config()
			end,
			name = L["S_PLUGIN_COLOR_CLASS"],
		},
		{
			type = "color",
			get = function() 
				return {Cooldowns.db.bar_fixed_color.r, Cooldowns.db.bar_fixed_color.g, Cooldowns.db.bar_fixed_color.b, Cooldowns.db.bar_fixed_color.a} 
			end,
			set = function (self, r, g, b, a) 
				local color = Cooldowns.db.bar_fixed_color
				color.r, color.g, color.b, color.a = r, g, b, a
				Cooldowns.UpdatePanels()
				update_panels_config()
			end,
			name = L["S_COLOR"],
		},
	}

	RA:BuildMenu (main_frame, options_list, 0, -110, 500, true, options_text_template, options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template)

	--refresh widgets
	function Cooldowns.RefreshMainDropdown()
		dropdownCooldownPanel:Select (currentEditingIndex, true)
	end
	Cooldowns.RefreshMainDropdown()

---------- Cooldowns -----------
-- ~cooldowns ~list

	local cooldowns_raid = {}
	local cooldowns_external = {}

	for spellId, _ in pairs (DetailsFramework.CooldownsExternals) do
		local spellName = GetSpellInfo (spellId)
		if (spellName) then
			tinsert (cooldowns_external, {spellId, spellName})
		end
	end

	for spellId, _ in pairs (DetailsFramework.CooldownsRaid) do
		local spellName = GetSpellInfo (spellId)
		if (spellName) then
			tinsert (cooldowns_raid, {spellId, spellName})
		end
	end

	table.sort (cooldowns_external, DetailsFramework.SortOrder2R)
	table.sort (cooldowns_raid, DetailsFramework.SortOrder2R)

	--raid wide
	local index = 1
	local x = 420
	local build_menu_raid = {}
	local backdrop_table = {bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true}
	local frame_level = main_frame:GetFrameLevel()

	local on_enter = function (self) 
		self:SetBackdropColor (.3, .3, .3, 0.5) 
		GameTooltip:SetOwner (self, "ANCHOR_RIGHT")
		GameTooltip:SetSpellByID (self.spellid)
		GameTooltip:Show()
	end

	local on_leave = function (self) 
		if (self.BackgroundColor) then
			local r, g, b = unpack (self.BackgroundColor)
			self:SetBackdropColor (r, g, b, 0.4)
		else
			self:SetBackdropColor (.1, .1, .1, 0.4)
		end
		GameTooltip:Hide()
	end

	local labelRaidCooldowns = Cooldowns:CreateLabel (main_frame, L["S_PLUGIN_COOLDOWNS_RAID_CDS"], Cooldowns:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
	local labelExternalCooldowns = Cooldowns:CreateLabel (main_frame, L["S_PLUGIN_COOLDOWNS_EXTERNAL_CDS"], Cooldowns:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
	labelRaidCooldowns:SetPoint ("topleft", main_frame, "topleft", 10+x, -0)
	labelExternalCooldowns:SetPoint ("topleft", main_frame, "topleft", 10+x+180, -0)

	for _, spellTable in ipairs (cooldowns_raid) do
		local spellid = spellTable [1]
		local spellname, _, spellicon = GetSpellInfo (spellid)

		if (spellname) then
			local background = CreateFrame ("frame", nil, main_frame, "BackdropTemplate")
			background:SetBackdrop (backdrop_table)
			background:SetFrameLevel (frame_level+1)
			background:SetBackdropColor (.1, .1, .1, 0.4)

			local class = DetailsFramework:FindClassForCooldown (spellid)
			if (class) then
				local classColor = RAID_CLASS_COLORS [class]
				if (classColor) then
					background:SetBackdropColor (classColor.r, classColor.g, classColor.b, 0.4)
					background.BackgroundColor = {classColor.r, classColor.g, classColor.b}
				end
			end

			background:SetSize (166, 18)
			background:SetScript ("OnEnter", on_enter)
			background:SetScript ("OnLeave", on_leave)
			background.spellid = spellid

			local func = function (self, fixedparam, value) Cooldowns.db.cooldowns_enabled [spellid] = value; Cooldowns.BarControl ("roster_update") end
			local checkbox, label = Cooldowns:CreateSwitch (main_frame, func, Cooldowns.db.cooldowns_enabled [spellid], _, _, _, _, _, "CooldownsDropdown" .. spellid .. "RaidWide", _, _, _, "|T" .. spellicon .. ":14:14:0:0:64:64:5:59:5:59|t " .. spellname, Cooldowns:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Cooldowns:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
			checkbox:SetAsCheckBox()
			checkbox.tooltip = format (L["S_PLUGIN_COOLDOWNS_SPELLNAME"], spellname)
			checkbox:ClearAllPoints(); label:ClearAllPoints()
			checkbox:SetFrameLevel (frame_level+2)

			background:SetPoint ("topleft", main_frame, "topleft", 5+x, -20 + ((index-1) * -20))
			label:SetPoint ("topleft", main_frame, "topleft", 10+x, -23 + ((index-1) * -20))
			checkbox:SetPoint ("topleft", main_frame, "topleft", 150+x, -20 + ((index-1) * -20))

			index = index + 1
		end
	end

	--external cooldowns
	local x = 600
	index = 1

	for _, spellTable in ipairs (cooldowns_external) do

		local spellid = spellTable [1]

		local spellname, _, spellicon = GetSpellInfo (spellid)
		if (spellname) then
			local background = CreateFrame ("frame", nil, main_frame, "BackdropTemplate")
			background:SetBackdrop (backdrop_table)
			background:SetFrameLevel (frame_level+1)

			background:SetBackdropColor (.1, .1, .1, 0.4)

			local class = DetailsFramework:FindClassForCooldown (spellid)
			if (class) then
				local classColor = RAID_CLASS_COLORS [class]
				if (classColor) then
					background:SetBackdropColor (classColor.r, classColor.g, classColor.b, 0.4)
					background.BackgroundColor = {classColor.r, classColor.g, classColor.b}
				end
			end

			background:SetSize (166, 18)
			background:SetScript ("OnEnter", on_enter)
			background:SetScript ("OnLeave", on_leave)
			background.spellid = spellid

			local func = function (self, fixedparam, value) Cooldowns.db.cooldowns_enabled [spellid] = value; Cooldowns.BarControl ("roster_update") end
			local checkbox, label = Cooldowns:CreateSwitch (main_frame, func, Cooldowns.db.cooldowns_enabled [spellid], _, _, _, _, _, "CooldownsDropdown" .. spellid .. "External", _, _, _, "|T" .. spellicon .. ":14:14:0:0:64:64:5:59:5:59|t " .. spellname, Cooldowns:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Cooldowns:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
			checkbox:SetAsCheckBox()
			checkbox.tooltip = format (L["S_PLUGIN_COOLDOWNS_SPELLNAME"], spellname)
			checkbox:ClearAllPoints(); label:ClearAllPoints()
			checkbox:SetFrameLevel (frame_level+2)

			background:SetPoint ("topleft", main_frame, "topleft", 5+x, -20 + ((index-1) * -20))
			label:SetPoint ("topleft", main_frame, "topleft", 10+x, -23 + ((index-1) * -20))
			checkbox:SetPoint ("topleft", main_frame, "topleft", 150+x, -20 + ((index-1) * -20))

			index = index + 1
		end
	end

	main_frame:Show()
end

RA:InstallPlugin (Cooldowns.displayName, "RACooldowns", Cooldowns, default_config)
