
local RA = _G.RaidAssist
local L = LibStub ("AceLocale-3.0"):GetLocale ("RaidAssistAddon")
local DF = DetailsFramework
local _

local default_priority = 1
local default_config = {
	enabled = true,
	menu_priority = 1,

	show_window_after = 0.9,
	text_size = 10,
	text_face = "Friz Quadrata TT",
	text_shadow = false,

	buff_indicator_size = 20,

	buff_indicator_stamina = true,
	buff_indicator_intellect = true,
	buff_indicator_attackpower = true,
	buff_indicator_flask = true,
	buff_indicator_oil = true,
	buff_indicator_rune = true,
	buff_indicator_food = true,
}

local UnitAura = UnitAura

local icon_texcoord = {l=0.078125, r=0.921875, t=0.078125, b=0.921875}
local text_color_enabled = {r=1, g=1, b=1, a=1}
local text_color_disabled = {r=0.5, g=0.5, b=0.5, a=1}

--store what buffs the ready check will check
local raidBuffs = {
	{name = "Stamina", spellId = {[21562] = true}, texture = "spell_holy_wordfortitude", class = "PRIEST", enabled = true, db = "buff_indicator_stamina"},
	{name = "Intellect", spellId = {[1459] = true}, texture = "spell_holy_magicalsentry", class = "MAGE", enabled = true, db = "buff_indicator_intellect"},
	{name = "Attack Power", spellId = {[6673] = true}, texture = "ability_warrior_battleshout", class = "WARRIOR", enabled = true, db = "buff_indicator_attackpower"},
	{name = "Flask", spellId = DetailsFramework.FlaskIDs, texture = "inv_alchemy_90_flask_green", enabled = true, db = "buff_indicator_flask"},
	{name = "Oil", spellId = DetailsFramework.WeaponEnchantIds, texture = "inv_misc_potionseta", enabled = true, db = "buff_indicator_oil", weaponEnchant = true},
	{name = "Rune", spellId = DetailsFramework.RuneIDs, texture = "inv_misc_gem_azuredraenite_01", enabled = true, db = "buff_indicator_rune"},
	{name = "Food", spellId = DetailsFramework.FoodIDs, texture = "INV_Misc_Food_100_HardCheese", enabled = true, db = "buff_indicator_food"},
}

--[Surprisingly Palatable Feast] [Feast of Gluttonous Hedonism]

local raidBuffsClass = {
	["PRIEST"] = 1,
	["MAGE"] = 2,
	["WARRIOR"] = 3,
}


local ReadyCheck = {version = "v0.1", pluginname = "ReadyCheck", pluginId = "RECK", displayName = "Ready Check"}
_G ["RaidAssistReadyCheck"] = ReadyCheck

ReadyCheck.debug = false

ReadyCheck.menu_text = function (plugin)
	if (ReadyCheck.db.enabled) then
		return [[Interface\Scenarios\ScenarioIcon-Check]], icon_texcoord, "Ready Check", text_color_enabled
	else
		return [[Interface\Scenarios\ScenarioIcon-Check]], icon_texcoord, "Ready Check", text_color_disabled
	end
end

ReadyCheck.menu_popup_show = function (plugin, ct_frame, param1, param2)
	RA:AnchorMyPopupFrame (ReadyCheck)
end

ReadyCheck.menu_popup_hide = function (plugin, ct_frame, param1, param2)
	ReadyCheck.popup_frame:Hide()
end

ReadyCheck.menu_on_click = function (plugin)

end

ReadyCheck.OnInstall = function (plugin)
	ReadyCheck.db.menu_priority = default_priority
	
	if (ReadyCheck.db.enabled) then
		ReadyCheck.BuildScreenFrames()
	end
end

ReadyCheck.OnEnable = function (plugin)
	-- enabled from the options panel.
	if (not ReadyCheck.ScreenPanel) then
		ReadyCheck.BuildScreenFrames()
	end
	
	ReadyCheck:RegisterEvent ("READY_CHECK")
	ReadyCheck:RegisterEvent ("READY_CHECK_CONFIRM")
	ReadyCheck:RegisterEvent ("READY_CHECK_FINISHED")
	ReadyCheck:RegisterEvent ("ENCOUNTER_START")
	ReadyCheck:RegisterEvent ("PLAYER_REGEN_DISABLED")
end

ReadyCheck.OnDisable = function (plugin)
	-- disabled from the options panel.
	if (ReadyCheck.ScreenPanel) then
		ReadyCheck.ScreenPanel:Hide()
		ReadyCheck:UnregisterEvent ("READY_CHECK")
		ReadyCheck:UnregisterEvent ("READY_CHECK_CONFIRM")
		ReadyCheck:UnregisterEvent ("READY_CHECK_FINISHED")
		ReadyCheck:UnregisterEvent ("ENCOUNTER_START")
		ReadyCheck:UnregisterEvent ("PLAYER_REGEN_DISABLED")
	end
end

ReadyCheck.OnProfileChanged = function (plugin)
	if (plugin.db.enabled) then
		ReadyCheck.OnEnable (plugin)
	else
		ReadyCheck.OnDisable (plugin)
	end
	
	if (plugin.options_built) then
		
	end
end

function ReadyCheck.BuildScreenFrames()
	local ScreenPanel = ReadyCheck:CreateCleanFrame(ReadyCheck, "ReadyCheckScreenFrame")
	ScreenPanel:SetSize(300, 240)

	--title bar
	ScreenPanel.titleBar = DetailsFramework:CreateTitleBar(ScreenPanel)
	ScreenPanel.titleBar:SetHeight(14)
	ScreenPanel.titleBar.CloseButton:SetSize(14, 14)

	ScreenPanel.titleBar.Title = DF:CreateLabel(ScreenPanel.titleBar, "")
	ScreenPanel.titleBar.Title:SetPoint("left", ScreenPanel.titleBar, "left", 2, 0)
	ScreenPanel.titleBar.Title.text = "Ready Check"

	--right click to close
	local labelClose = DetailsFramework:CreateRightClickToClose(ScreenPanel, 0, -4, "gray") --, fontSize)

	--create the player list
	ReadyCheck.PlayerList = {}
	local x = 5
	local y = -30
	for i = 1, 40 do
		local Cross = ReadyCheck:CreateImage(ScreenPanel, "Interface\\Glues\\LOGIN\\Glues-CheckBox-Check", 16, 16, "overlay")
		local Label = ReadyCheck:CreateLabel(ScreenPanel, "Player Name")
		Label:SetPoint("left", Cross, "right", 2, 1)
		Cross.Label = Label
		Cross:SetPoint("topleft", ScreenPanel, "topleft", x, y)

		if (i % 2 == 0) then
			x = 10
			y = y - 16
		else
			x = 140
		end

		Cross:Hide()
		tinsert(ReadyCheck.PlayerList, Cross)
	end

	--missing indicators
	ScreenPanel.indicators = {}
	ScreenPanel.indicatorAnchor = CreateFrame("frame", nil, ScreenPanel)
	ScreenPanel.indicatorAnchor:SetPoint("center", ScreenPanel, "bottom", 0, 20)

	local onEnterFunc = function(self)
		--players which has the aura of this indicator
		local playerHasAura = self.playersWithByBuff

		GameCooltip2:Preset(2)
		local shouldShowTooltip = false

		for playerName in pairs(ReadyCheck.AnswerTable) do
			if (not playerHasAura[playerName]) then
				local _, playerClass = UnitClass(playerName)
				if (playerClass) then
					playerName = DetailsFramework:AddClassColorToText(playerName, playerClass)
					GameCooltip2:AddLine(playerName)
					local iconTexCoord = CLASS_ICON_TCOORDS[playerClass]
					local l, r, t, b = unpack(iconTexCoord)
					GameCooltip2:AddIcon([[Interface\GLUES\CHARACTERCREATE\UI-CharacterCreate-Classes]], 1, 1, 16, 16, l+0.014, r-0.014, t+0.014, b-0.014)
				else
					GameCooltip2:AddLine(playerName)
				end

				shouldShowTooltip = true
			end
		end

		if (shouldShowTooltip) then
			GameCooltip2:Show(self)
		end
	end

	local onLeaveFunc = function(self)
		GameCooltip2:Hide()
	end

	for i = 1, #raidBuffs do
		local indicator = CreateFrame("frame", "$parentIndicator" .. i, ScreenPanel.indicatorAnchor)
		local texture = indicator:CreateTexture(nil, "border")
		texture:SetAllPoints()

		indicator:SetScript("OnEnter", onEnterFunc)
		indicator:SetScript("OnLeave", onLeaveFunc)

		local numberBackgroud = indicator:CreateTexture(nil, "artwork")
		numberBackgroud:SetSize(12, 12)
		numberBackgroud:SetPoint("topright", indicator, "topright", 0, 0)
		numberBackgroud:SetColorTexture(1, .2, .1)

		local number = indicator:CreateFontString(nil, "overlay", "GameFontNormal")
		number:SetPoint("center", numberBackgroud, "center", 0, 0)

		indicator.texture = texture
		indicator.redBackground = numberBackgroud
		indicator.number = number
		indicator.index = i

		tinsert(ScreenPanel.indicators, indicator)
	end

	ReadyCheck.UpdateTextSettings()
	ReadyCheck.UpdateIndicators()

	ReadyCheck.ScreenPanel = ScreenPanel
	ScreenPanel:Hide()

	--ready check events
	ReadyCheck:RegisterEvent("READY_CHECK")
	ReadyCheck:RegisterEvent("READY_CHECK_CONFIRM")
	ReadyCheck:RegisterEvent("READY_CHECK_FINISHED")
	ReadyCheck:RegisterEvent("ENCOUNTER_START")
	ReadyCheck:RegisterEvent("PLAYER_REGEN_DISABLED")
end

function ReadyCheck.UpdateIndicators()
	if (ReadyCheckScreenFrame) then
		local amountShown = 0

		for i = 1, #raidBuffs do
			local raidBuff = raidBuffs[i]
			raidBuff.enabled = ReadyCheck.db[raidBuff.db]
			local indicatorFrame = ReadyCheckScreenFrame.indicators[i]

			if (raidBuff.enabled) then
				amountShown = amountShown + 1

				indicatorFrame:Show()

				indicatorFrame:SetPoint("left", ReadyCheckScreenFrame.indicatorAnchor, "left", (amountShown-1) * (ReadyCheck.db.buff_indicator_size+2), 0)

				indicatorFrame.texture:SetTexture("Interface\\ICONS\\" .. raidBuff.texture)
				indicatorFrame.texture:SetTexCoord(.1, .9, .1, .9)

				indicatorFrame.spellName = GetSpellInfo(raidBuffs.spellId)
				indicatorFrame.class = raidBuffs.class

				indicatorFrame:SetSize(ReadyCheck.db.buff_indicator_size, ReadyCheck.db.buff_indicator_size)
				indicatorFrame.redBackground:SetSize(ReadyCheck.db.buff_indicator_size*0.3, ReadyCheck.db.buff_indicator_size*0.3) --30% of the indicator size

				ReadyCheck:SetFontFace(indicatorFrame.number, ReadyCheck.db.text_face)
				ReadyCheck:SetFontSize(indicatorFrame.number, ReadyCheck.db.text_size)
				ReadyCheck:SetFontOutline(indicatorFrame.number, ReadyCheck.db.text_shadow)

			else
				indicatorFrame:Hide()
			end
		end

		ReadyCheckScreenFrame.indicatorAnchor:SetSize(amountShown * ReadyCheck.db.buff_indicator_size, ReadyCheck.db.buff_indicator_size)
	end
end

function ReadyCheck.OnShowOnOptionsPanel()
	local OptionsPanel = ReadyCheck.OptionsPanel
	ReadyCheck.BuildOptions(OptionsPanel)
end

function ReadyCheck.UpdateTextSettings()
	if (ReadyCheckScreenFrame) then
		local SharedMedia = LibStub:GetLibrary("LibSharedMedia-3.0")
		local db = ReadyCheck.db

		local font = SharedMedia:Fetch("font", db.text_font)
		local size = db.text_size
		local shadow = db.text_shadow

		for index, Player in ipairs(ReadyCheck.PlayerList or {}) do
			ReadyCheck:SetFontFace(Player.Label, font)
			ReadyCheck:SetFontSize(Player.Label, size)
			ReadyCheck:SetFontOutline(Player.Label, shadow)
		end
	end
end

local hideScreenPanel = function()
	if (ReadyCheck.ScreenPanel and ReadyCheck.ScreenPanel:IsShown()) then
		ReadyCheck.ScreenPanel:Hide()
	end
end

local playerHasAura = function(unitId, spellId)
	for buffIndex = 1, 40 do
		local name, texture, count, debuffType, duration, expirationTime, caster, canStealOrPurge, nameplateShowPersonal, buffSpellId = UnitAura(unitId, buffIndex, "HELPFUL")
		if (name) then
			if (spellId == buffSpellId) then
				return true
			end
		else
			return false
		end
	end
end

local timeToScamBuffs = 0
local playerTotal = 0
local intervalToCheckBuffs = 0.8

local onUpdate = function(self, deltaTime) --~update ~onupdate õnupdate
	if (not ReadyCheck.db.enabled) then
		return
	end

	ReadyCheck.timeout = ReadyCheck.timeout - deltaTime

	-- true = answered
	-- false = did answered 'not ready'
	-- "afk" = no answer from the start of the check
	-- "offline" = offline at the start of the check

	local index = 1
	local updatedAuras = false

	timeToScamBuffs = timeToScamBuffs - deltaTime

	if (timeToScamBuffs < 0) then
		timeToScamBuffs = intervalToCheckBuffs
		playerTotal = 0
		ReadyCheck.ScreenPanel.titleBar.Title.text = ReadyCheck.ScreenPanel.titleBar.Title.originalText .. " | " .. max(floor(ReadyCheck.timeout), 0)

		for _, Player in ipairs(ReadyCheck.PlayerList) do
			Player:Hide()
			Player.Label:Hide()
		end

		--get weapon enchants data
		local openRaidLib = LibStub:GetLibrary("LibOpenRaid-1.0")
		local allPlayersGear = openRaidLib.GetAllUnitsGear()
		--local debugTime = {stage1 = 0, stage2 = 0, stage3 = 0, stage4 = 0}
		local Ambiguate = Ambiguate

		local playerBuffsSpellIds = {}
		--build a buff table with all buffs of all players
		for player, answer in pairs(ReadyCheck.AnswerTable) do
			playerBuffsSpellIds[player] = {}
			local playerBuffTable = playerBuffsSpellIds[player]

			for buffIndex = 1, 40 do
				local name, texture, count, debuffType, duration, expirationTime, caster, canStealOrPurge, nameplateShowPersonal, buffSpellId = UnitAura(player, buffIndex, "HELPFUL")
				if (name) then
					playerBuffTable[buffSpellId] = true
				else
					break
				end
			end
		end

		for player, answer in pairs(ReadyCheck.AnswerTable) do
			local _, class = UnitClass(player)
			playerTotal = playerTotal + 1

			--local s = debugprofilestop() --performance debug
			local playerBuffTable = playerBuffsSpellIds[player]

			--check raid buffs on this player (e.g. fortitude)
			for buffIndex, buffTable in pairs(ReadyCheck.BuffsAvailable) do
				if (not buffTable[player]) then
					local raidBuff = raidBuffs[buffIndex]
					local spellIds = raidBuff.spellId

					for spellId in pairs(spellIds) do
						if (playerBuffTable[spellId]) then
							buffTable[player] = true
							ReadyCheck.BuffCounter[buffIndex] = (ReadyCheck.BuffCounter[buffIndex] or 0) + 1
						end
					end
				end
			end

			--debugTime.stage1 = debugTime.stage1 + (debugprofilestop() - s)

			--check individual buffs on this player (e.g. food buff)
			for buffIndex, buffTable in pairs(ReadyCheck.IndividualBuffs) do --4 5 6 7 iguais a tabelas vazias
				if (not buffTable[player]) then
					local raidBuff = raidBuffs[buffIndex]
					local spellIds = raidBuff.spellId --table with many spellIds
					local isWeaponEnchant  = raidBuff.weaponEnchant

					if (isWeaponEnchant) then
						local playerName = Ambiguate(player, "none")
						local playerGear = allPlayersGear[playerName]
						if (playerGear) then
							local weaponEnchant = playerGear.weaponEnchant
							if (weaponEnchant == 1) then
								buffTable[player] = true
								ReadyCheck.BuffCounter[buffIndex] = (ReadyCheck.BuffCounter[buffIndex] or 0) + 1
							end
						end
					else
						local playerBuffTable = playerBuffsSpellIds[player]
						for spellId in pairs(spellIds) do
							if (playerBuffTable[spellId]) then
								buffTable[player] = true
								ReadyCheck.BuffCounter[buffIndex] = (ReadyCheck.BuffCounter[buffIndex] or 0) + 1
								break
							end
						end
					end
				end
			end

			--debugTime.stage2 = debugTime.stage2 + (debugprofilestop() - s)

			if (answer == "offline") then
				ReadyCheck.PlayerList[index]:Show()
				ReadyCheck.PlayerList[index].Label:Show()

				ReadyCheck.PlayerList[index]:SetTexture([[Interface\CHARACTERFRAME\Disconnect-Icon]])
				ReadyCheck.PlayerList[index]:SetTexCoord(18/64, (64-18)/64, 14/64, (64-14)/64)

				local color = class and RAID_CLASS_COLORS[class] and RAID_CLASS_COLORS[class].colorStr or "ffffffff"
				ReadyCheck.PlayerList[index].Label:SetText("|c" .. color .. ReadyCheck:RemoveRealName (player) .. "|r" .. " (|cFFFF3300offline|r)")
				index = index + 1

			elseif (answer == "afk") then
				if (GetTime() > ReadyCheck.ScreenPanel.EndAt - ReadyCheck.ScreenPanel.ShowAFKPlayersAt) then
					ReadyCheck.PlayerList[index]:Show()
					ReadyCheck.PlayerList[index].Label:Show()

					ReadyCheck.PlayerList[index]:SetTexture([[Interface\FriendsFrame\StatusIcon-Away]])
					ReadyCheck.PlayerList[index]:SetTexCoord(0, 1, 0, 1)

					local color = class and RAID_CLASS_COLORS[class] and RAID_CLASS_COLORS[class].colorStr or "ffffffff"
					ReadyCheck.PlayerList[index].Label:SetText("|c" .. color .. ReadyCheck:RemoveRealName (player) .. "|r" .. " (|cFFFF3300afk|r)")

					index = index + 1
				end

			elseif (answer == false) then
				ReadyCheck.PlayerList[index]:Show()
				ReadyCheck.PlayerList[index].Label:Show()

				ReadyCheck.PlayerList[index]:SetTexture("Interface\\Glues\\LOGIN\\Glues-CheckBox-Check")
				ReadyCheck.PlayerList[index]:SetTexCoord(0, 1, 0, 1)

				local color = class and RAID_CLASS_COLORS[class] and RAID_CLASS_COLORS[class].colorStr or "ffffffff"
				ReadyCheck.PlayerList[index].Label:SetText("|c" .. color .. ReadyCheck:RemoveRealName (player) .. "|r" .. " (|cFFFFAA00not ready|r)")
				index = index + 1
			end

			--debugTime.stage3 = debugTime.stage3 + (debugprofilestop() - s)
		end

		--raid buffs
		--get the table with indicator frames
		local indicatorFrames = ReadyCheck.ScreenPanel.indicators

		--local s = debugprofilestop()

		for indicatorIndex = 1, #raidBuffs do
			local indicator = indicatorFrames[indicatorIndex]

			--print("amountWithBuffs", indicatorIndex, ReadyCheck.BuffCounter[indicatorIndex])
			local amountWithBuffs = ReadyCheck.BuffCounter[indicatorIndex] or 0

			if (amountWithBuffs < playerTotal) then
				--somebody is missing this buff, need to show the icon
				--all indicators are refreshed here, their can be hide and show, update the counter text
				indicator:SetAlpha(0.9)
				indicator.texture:SetDesaturated(false)
				indicator.redBackground:Show()
				indicator.number:Show()
				indicator.number:SetText(playerTotal - amountWithBuffs)
			else
				indicator:SetAlpha(0.5)
				indicator.texture:SetDesaturated(true)
				indicator.redBackground:Hide()
				indicator.number:Hide()
			end

			--make a list of people without the buff for tooltips
			indicator.playersWithByBuff = ReadyCheck.BuffsAvailable[indicatorIndex] or ReadyCheck.IndividualBuffs[indicatorIndex]
		end

		--debugTime.stage4 = debugTime.stage4 + (debugprofilestop() - s)

		index = index - 1
		ReadyCheck.ScreenPanel:SetHeight(90 + (math.ceil(index / 2) * 17))

		--print("Performance Results:")
		--for stageName, seconds in pairs(debugTime) do
		--	print(stageName, seconds)
		--end
	end
end

--a ready check has started
function ReadyCheck:READY_CHECK(event, player, timeout)
	--ready check started
	if (ReadyCheck.db.enabled) then
		ReadyCheck.AnswerTable = ReadyCheck.AnswerTable or {}
		wipe(ReadyCheck.AnswerTable)

		local openRaidLib = LibStub:GetLibrary("LibOpenRaid-1.0")
		openRaidLib.RequestAllData()

		local instanceName, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID = GetInstanceInfo()
		local isMythicRaid = difficultyID == 16
		local isNormalOrHeroic = difficultyID == 14 or difficultyID == 15

		--store indexes of the buffs from the raidBuffs table and these tables store player names which do not have the buff
		ReadyCheck.BuffsAvailable = {}
		ReadyCheck.IndividualBuffs = {}
		ReadyCheck.BuffCounter = {}

		--build raid buffs table
		for i = 1, #raidBuffs do
			local raidBuff = raidBuffs[i]

			if (raidBuff.enabled) then
				if (raidBuff.class) then
					ReadyCheck.BuffsAvailable[i] = {}
				else
					ReadyCheck.IndividualBuffs[i] = {}
				end
			end
		end

		local amt = 0
		local GetRaidRosterInfo = GetRaidRosterInfo

		for i = 1, GetNumGroupMembers() do
			local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i)
			name = Ambiguate(name, "none")

			if (not isMythicRaid or (isMythicRaid and subgroup <= 4)) then --mythic raid check
				if (not isNormalOrHeroic or (isNormalOrHeroic and subgroup <= 6)) then --heroic normal raid check
					if (player ~= name) then
						ReadyCheck.AnswerTable[name] = "afk"
					else
						ReadyCheck.AnswerTable[name] = true
					end

					amt = amt + 1
				end
			end
		end

		ReadyCheck.ScreenPanel:Show()
		ReadyCheck.Waiting = amt

		local _, playerClass = UnitClass(player)
		if (playerClass) then
			local playerName = DetailsFramework:AddClassColorToText(player, playerClass)
			ReadyCheck.ScreenPanel.titleBar.Title.text = "Ready Check | From: " .. playerName
		else
			ReadyCheck.ScreenPanel.titleBar.Title.text = "Ready Check | From: " .. player
		end

		ReadyCheck.ScreenPanel.titleBar.Title.originalText = ReadyCheck.ScreenPanel.titleBar.Title.text
		ReadyCheck.timeout = timeout

		local _, class = UnitClass(player)
		if (class) then
			local color = RAID_CLASS_COLORS [class]
			if (color) then
				print ("|cFFFFDD00RaidAssist (/raa):|cFFFFFF00 ready check from |c" .. color.colorStr .. player .. "|r|cFFFFFF00 at " .. date ("%H:%M") .. "|r")
			else
				print ("|cFFFFDD00RaidAssist (/raa):|cFFFFFF00 ready check from " .. player .. " at " .. date ("%H:%M") .. "|r")
			end
		else
			print ("|cFFFFDD00RaidAssist (/raa):|cFFFFFF00 ready check from " .. player .. " at " .. date ("%H:%M") .. "|r")
		end

		for index, Player in ipairs(ReadyCheck.PlayerList) do
			Player:Hide()
			Player.Label:Hide()
		end

		ReadyCheck.ScreenPanel:SetHeight(90)
		ReadyCheck.ScreenPanel.ShowAFKPlayersAt = timeout * ReadyCheck.db.show_window_after
		ReadyCheck.ScreenPanel.StartAt = GetTime()
		ReadyCheck.ScreenPanel.EndAt = GetTime() + timeout
		ReadyCheck.ScreenPanel:SetScript("OnUpdate", onUpdate)
	end
end

--player sent an answer
function ReadyCheck:READY_CHECK_CONFIRM(event, player, status, arg4, arg5)
	--print (event, player, UnitName (player), status, arg4, arg5)

	if (ReadyCheck.db.enabled and ReadyCheck.AnswerTable and ReadyCheck.ScreenPanel) then
		local PlayerName = GetUnitName(player, true)

		if (PlayerName and ReadyCheck.AnswerTable [PlayerName] ~= nil) then
			if (not status and ReadyCheck.ScreenPanel.StartAt and ReadyCheck.ScreenPanel.StartAt + 0.3 and not UnitIsConnected(player)) then
				ReadyCheck.AnswerTable [PlayerName] = "offline"

			elseif (ReadyCheck.AnswerTable [PlayerName] ~= "offline") then
				if (ReadyCheck.AnswerTable [PlayerName] == false and status == false) then
					ReadyCheck.AnswerTable [PlayerName] = status
				else
					ReadyCheck.AnswerTable [PlayerName] = status
				end
			end
		end
	end
end

local finished_func = function()
	if (ReadyCheck.ScreenPanel) then
		ReadyCheck.ScreenPanel:SetScript("OnUpdate", nil)
		if (ReadyCheck.ScreenPanel:IsShown()) then
			C_Timer.After(4, hideScreenPanel)
		end
	end
end

--ready check finished
function ReadyCheck:READY_CHECK_FINISHED (event, arg2, arg3)
	C_Timer.After(1, finished_func)
end

--player entered in combat, hide the ready check panel
local combat_start = function()
	C_Timer.After(1, finished_func)
end

function ReadyCheck:PLAYER_REGEN_DISABLED()
	combat_start()
end
function ReadyCheck:ENCOUNTER_START()
	combat_start()
end



function ReadyCheck.BuildOptions(frame)
	if (frame.FirstRun) then
		return
	end

	frame.FirstRun = true

	local leftOptionsPanelFrame = CreateFrame("frame", "ReadyCheckOptionsPanel", frame, "BackdropTemplate")
	frame.leftOptionsPanelFrame = leftOptionsPanelFrame
	leftOptionsPanelFrame:SetSize(280, 615)
	leftOptionsPanelFrame:SetPoint("topleft", frame, "topleft", 5, 5)

	leftOptionsPanelFrame:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
	leftOptionsPanelFrame:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))
	leftOptionsPanelFrame:SetBackdropColor(.1, .1, .1, 1)

	local on_select_text_font = function (self, fixed_value, value)
		ReadyCheck.db.text_font = value
		ReadyCheck.UpdateTextSettings()
		ReadyCheck.UpdateIndicators()
	end

	-- options panel
	local options_list = {
		{type = "label", get = function() return "General Options:" end, text_template = ReadyCheck:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},
		{
			type = "toggle",
			get = function() return ReadyCheck.db.enabled end,
			set = function (self, fixedparam, value)
				ReadyCheck.db.enabled = value
				if (not value) then
					if (ReadyCheck.ScreenPanel) then
						ReadyCheck.ScreenPanel:SetScript ("OnUpdate", nil)
						if (ReadyCheck.ScreenPanel:IsShown()) then
							ReadyCheck.ScreenPanel:Hide()
						end
					end
				end
			end,
			name = "Enabled",
		},

		{type = "blank"},
		--{type = "label", get = function() return "Text Settings:" end, text_template = ReadyCheck:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},

		{
			type = "range",
			get = function() return ReadyCheck.db.text_size end,
			set = function (self, fixedparam, value)
				ReadyCheck.db.text_size = value
				ReadyCheck.UpdateTextSettings()
				ReadyCheck.UpdateIndicators()
			end,
			min = 4,
			max = 32,
			step = 1,
			name = L["S_PLUGIN_TEXT_SIZE"],
		},
		{
			type = "select",
			get = function() return ReadyCheck.db.text_font end,
			values = function() 
				return ReadyCheck:BuildDropDownFontList (on_select_text_font)
			end,
			name = L["S_PLUGIN_TEXT_FONT"],
		},
		{
			type = "toggle",
			get = function() return ReadyCheck.db.text_shadow end,
			set = function (self, fixedparam, value)
				ReadyCheck.db.text_shadow = value
				ReadyCheck.UpdateTextSettings()
				ReadyCheck.UpdateIndicators()
			end,
			name = L["S_PLUGIN_TEXT_SHADOW"],
		},

		{type = "blank"},

		{
			type = "range",
			get = function() return ReadyCheck.db.buff_indicator_size end,
			set = function (self, fixedparam, value)
				ReadyCheck.db.buff_indicator_size = value
				ReadyCheck.UpdateIndicators()
			end,
			min = 12,
			max = 32,
			step = 1,
			name = "Buff Indicator Size",
		},

		{type = "blank"},
		{type = "label", get = function() return "Buff Indicators:" end, text_template = ReadyCheck:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},
	}

	for i = 1, #raidBuffs do
		local raidBuff = raidBuffs[i]

		local nameString = "|TInterface\\ICONS\\" .. raidBuff.texture .. ":16:16:0:0:64:64:6:58:6:58|t " ..  raidBuff.name

		local thisOption = {
			type = "toggle",
			get = function() return ReadyCheck.db[raidBuff.db] end,
			set = function (self, fixedparam, value)
				ReadyCheck.db[raidBuff.db] = value
				raidBuff.enabled = value
				ReadyCheck.UpdateIndicators()
			end,
			name = nameString,
		}

		tinsert(options_list, thisOption)
	end

	local options_text_template = ReadyCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE")
	local options_dropdown_template = ReadyCheck:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
	local options_switch_template = ReadyCheck:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE")
	local options_slider_template = ReadyCheck:GetTemplate ("slider", "OPTIONS_SLIDER_TEMPLATE")
	local options_button_template = ReadyCheck:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE")

	ReadyCheck:SetAsOptionsPanel(leftOptionsPanelFrame)
	ReadyCheck:BuildMenu(leftOptionsPanelFrame, options_list, 5, -5, 500, true, options_text_template, options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template)
end

RA:InstallPlugin(ReadyCheck.displayName, "RAReadyCheck", ReadyCheck, default_config)
