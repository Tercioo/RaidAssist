
local RA = _G.RaidAssist
local L = LibStub ("AceLocale-3.0"):GetLocale ("RaidAssistAddon")
local DF = DetailsFramework
local _
local defaultPriority = 119

local PlayerCheck = {
	last_data_sent = 0,
	player_data = {},
	version = "v0.1",
	pluginname = "PlayerCheck",
	pluginId = "PLCK",
	displayName = "Check Players",
}
_G ["RaidAssistPlayerCheck"] = PlayerCheck

local canInstall = true

local default_config = {
	cache = {},
}

local icon_texcoord = {l=0, r=1, t=0, b=1}
local icon_texture = [[Interface\CURSOR\thumbsup]]
local text_color_enabled = {r=1, g=1, b=1, a=1}
local text_color_disabled = {r=0.5, g=0.5, b=0.5, a=1}

local GetSpellInfo = GetSpellInfo

if (C_Spell and C_Spell.GetSpellInfo) then
    GetSpellInfo = function(...)
        local result = C_Spell.GetSpellInfo(...)
        if result then
            return result.name, 1, result.iconID
        end
    end
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
PlayerCheck.menu_text = function (plugin)
	return icon_texture, icon_texcoord, "Player Check", text_color_enabled
end

PlayerCheck.menu_popup_show = function (plugin, ct_frame, param1, param2)
	RA:AnchorMyPopupFrame (PlayerCheck)
end

PlayerCheck.menu_popup_hide = function (plugin, ct_frame, param1, param2)
	PlayerCheck.popup_frame:Hide()
end

PlayerCheck.menu_on_click = function (plugin)
	RA.OpenMainOptions (PlayerCheck)
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

PlayerCheck.OnInstall = function (plugin)
	PlayerCheck.db.menu_priority = defaultPriority

	local mainFrame = PlayerCheck.main_frame

	mainFrame:RegisterEvent ("GROUP_ROSTER_UPDATE")
	mainFrame:SetScript ("OnEvent", function (self, event, ...)
		if (event == "GROUP_ROSTER_UPDATE") then
			PlayerCheck:GroupUpdate()
		end
	end)
	PlayerCheck:GroupUpdate()
end

--on group roster update
function PlayerCheck:GroupUpdate()
	if (IsInRaid(LE_PARTY_CATEGORY_HOME)) then
		if (not PlayerCheck.InGroup) then
			--in group now
			PlayerCheck.InGroup = true
		end
	else
		if (PlayerCheck.InGroup) then
			PlayerCheck.InGroup = false
		end
	end

	if (not IsInGroup()) then
		wipe(PlayerCheck.db.cache)
	end
end

PlayerCheck.OnEnable = function (plugin)
	--enabled from the options panel
	PlayerCheck.OnInstall(plugin)
end

PlayerCheck.OnDisable = function (plugin)
	PlayerCheck.main_frame:UnregisterEvent("GROUP_ROSTER_UPDATE")
end

PlayerCheck.OnProfileChanged = function (plugin)
	if (plugin.db.enabled) then
		PlayerCheck.OnEnable(plugin)
	else
		PlayerCheck.OnDisable(plugin)
	end

	if (plugin.options_built) then
		plugin.main_frame:RefreshOptions()
	end
end

--[=[]]
		if (RaidAssistOptionsPanelPlayerCheck) then
			if (RaidAssistOptionsPanelPlayerCheck.playerInfoScroll and RaidAssistOptionsPanelPlayerCheck.playerInfoScroll:IsShown()) then
				RaidAssistOptionsPanelPlayerCheck.playerInfoScroll.RefreshData()
			end
		end
--]=]

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function PlayerCheck.OnShowOnOptionsPanel()
	local OptionsPanel = PlayerCheck.OptionsPanel
	PlayerCheck.BuildOptions(OptionsPanel)
end

function PlayerCheck.BuildOptions(frame)
	local openRaidLib = LibStub:GetLibrary("LibOpenRaid-1.0")

	if (frame.FirstRun) then
		if (IsInGroup()) then
			openRaidLib.RequestAllData()
		end
		return
	end

	frame.FirstRun = true
	openRaidLib.RequestAllData()

	--> register callback on lib Open Raid
		function PlayerCheck.RefreshScrollData()
			if (frame.playerInfoScroll) then
				if (frame.playerInfoScroll:IsShown()) then
					frame.playerInfoScroll.RefreshData()
				end
			end
		end
		openRaidLib.RegisterCallback(PlayerCheck, "PlayerUpdate", "RefreshScrollData")
		openRaidLib.RegisterCallback(PlayerCheck, "TalentUpdate", "RefreshScrollData")
		openRaidLib.RegisterCallback(PlayerCheck, "OnPlayerRess", "RefreshScrollData")
		openRaidLib.RegisterCallback(PlayerCheck, "GearListWiped", "RefreshScrollData")
		openRaidLib.RegisterCallback(PlayerCheck, "GearUpdate", "RefreshScrollData")
		openRaidLib.RegisterCallback(PlayerCheck, "GearDurabilityUpdate", "RefreshScrollData")

	RaidAssistClassTalentFrame = CreateFrame("frame", "RaidAssistClassTalentFrame", frame)
	RaidAssistClassTalentFrame:ClearAllPoints()
	RaidAssistClassTalentFrame:SetParent(frame)
	RaidAssistClassTalentFrame:SetPoint("topleft", frame, "topleft", 450, -20)
	RaidAssistClassTalentFrame:Hide()

	--spell scroll options
	local scroll_width = 848
	local scroll_height = 620
	local scroll_line_height = 20
	local scroll_lines = floor(scroll_height / scroll_line_height) - 1
	local lineSeparatorHeight = scroll_height + 20
	local lineSeparatorWidth = 1

	local backdrop_color = {.2, .2, .2, 0.2}
	local backdrop_color_on_enter = {.8, .8, .8, 0.4}
	local y = 0
	local headerY = y - 0
	local scrollY = headerY - 20
	local line_colors = {{1, 1, 1, .1}, {1, 1, 1, 0}}

	local headerSizeSmall = 50
	local headerSizeMedium = 75
	local headerSizeBig = 120
	local headerSizeBigPlus = 140
	local headerSizeTalents = 387

	local defaultTextColor = {.89, .89, .89, .89}

	--header
	local columnAlign = "left"
	local columnAlignOffset = 0

	--create the header and the scroll frame
	local headerTable = {
		{text = "Spec", width = 40, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC", selected = true},
		{text = "Name", width = headerSizeBig, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
		{text = "iLevel", width = headerSizeSmall, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
		{text = "Repair", width = headerSizeSmall, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
		{text = "No Enchant", width = headerSizeBig, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
		{text = "No Gems", width = headerSizeMedium, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
		--{text = "Talents", width = headerSizeTalents, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = false, order = "DESC"},
		--{text = "Renown", width = headerSizeSmall, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
		--{text = "Conduit", width = 195, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = false, order = "DESC"},
	}

	local headerOnClickCallback = function(headerFrame, columnHeader)
		--need to change this to make a refresh in the scroll frame
		local frameName = frame:GetName() .. "playerInfoScroll"
		local scrollFrame = _G[frameName]
		if (scrollFrame and scrollFrame.RefreshData) then
			scrollFrame.RefreshData()
		end
	end

	local headerOptions = {
		padding = 1,
		header_backdrop_color = {.3, .3, .3, .8},
		header_backdrop_color_selected = {.5, .5, .5, 0.8},
		use_line_separators = true,
		line_separator_color = {.1, .1, .1, .9},
		line_separator_width = lineSeparatorWidth,
		line_separator_height = lineSeparatorHeight,
		line_separator_gap_align = true,
		header_click_callback = headerOnClickCallback,
	}

	local header = DF:CreateHeader(frame, headerTable, headerOptions, "RaidAssistPlayerCheckHeader")
	header:SetPoint("topleft", frame, "topleft", 0, headerY)

	C_Timer.After(0, function()
		RaidAssistPlayerCheckHeaderHeaderIndex2:Click()
		RaidAssistPlayerCheckHeaderHeaderIndex2:Click()
	end)

	local currentSelectedColumn = 1

	local line_onenter = function(self)
		self:SetBackdropColor(unpack (backdrop_color_on_enter))
	end

	local line_onleave = function(self)
		self:SetBackdropColor(unpack (self.BackgroundColor))
	end

	local talentIconOnEnter = function(self)
		local talentId = self.talentId
		if (talentId) then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			--GameTooltip:SetTalent(talentId) --, false, self
			GameTooltip:SetSpellByID(talentId)
			--self.UpdateTooltip = PlayerTalentFrameTalent_OnEnter
			GameTooltip:Show()
			self.icon:SetBlendMode("ADD")
		end
	end

	local talentIconOnLeave = function(self)
		GameTooltip:Hide()
		self.icon:SetBlendMode("BLEND")
	end

	--[[
	local conduitIconOnEnter = function(self)
		if (self.spellId) then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetSpellByID(self.spellId)
			GameTooltip:Show()
			self.icon:SetBlendMode("ADD")
		end
	end

	local conduitIconOnLeave = function(self)
		GameTooltip:Hide()
		self.icon:SetBlendMode("BLEND")
	end
	--]]

	local headerFontSize = 11

	--create line for the spell scroll
	local scroll_createline = function (self, index)
		local line = CreateFrame("button", "$parentLine" .. index, self, "BackdropTemplate")
		line:SetPoint("topleft", self, "topleft", 1, -((index-1) * (scroll_line_height+1)) - 1)
		line:SetSize(scroll_width-2, scroll_line_height)
		line.id = index

		line:SetScript("OnEnter", line_onenter)
		line:SetScript("OnLeave", line_onleave)

		line:SetBackdrop({bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
		line:SetBackdropColor(unpack (backdrop_color))

		if (index % 2 == 0) then
			line:SetBackdropColor (unpack (line_colors [1]))
			line.BackgroundColor = line_colors [1]
		else
			line:SetBackdropColor (unpack (line_colors [2]))
			line.BackgroundColor = line_colors [2]
		end

		DF:Mixin(line, DF.HeaderFunctions)

		local playerNameFrame = CreateFrame("frame", nil, line, "BackdropTemplate")
		playerNameFrame:SetSize (headerTable [1].width + columnAlignOffset, header.options.header_height)
		playerNameFrame:EnableMouse (false)

		--player information

			--spec icon
			local specIcon = DF:CreateImage(line, "", line:GetHeight() - 2, line:GetHeight() - 2)
			specIcon.texcoord = {.1, .9, .1, .9}
			--specIcon:SetPoint ("left", 0, 0)
			specIcon:SetColorTexture(1, 1, 1, 1)
			specIcon.originalWidth = specIcon.width
			specIcon.originalHeight = specIcon.height
			specIcon.hoverWidth = specIcon.width * 1.15
			specIcon.hoverHeight = specIcon.height * 1.15

			--[[
			local covenantIcon = DF:CreateImage(line, "", line:GetHeight() - 2, line:GetHeight() - 2)
			covenantIcon.texcoord = {.1, .9, .1, .9}
			covenantIcon.originalWidth = covenantIcon.width
			covenantIcon.originalHeight = covenantIcon.height
			covenantIcon.hoverWidth = covenantIcon.width * 1.15
			covenantIcon.hoverHeight = covenantIcon.height * 1.15
			covenantIcon:SetPoint("left", specIcon, "right", 2, 0)
			--]]

			--player name
			local playerName = DF:CreateLabel(line)
			playerName:SetText("player name here")
			playerName.alpha = 1
			playerName.fontsize = headerFontSize

			--ilevel
			local itemLevel = DF:CreateLabel(line)
			itemLevel.fontsize = headerFontSize
			itemLevel.alpha = 1

			--repair
			local repairPct = DF:CreateLabel(line)
			repairPct.fontsize = headerFontSize
			repairPct.alpha = 1

			--enchant missing
			local enchantMissing = DF:CreateLabel(line)

			--gems missing
			local gemMissing = DF:CreateLabel(line)

			--talents
			local talentsFrame = CreateFrame("frame", "$parentTalents", line)
			talentsFrame:SetSize(headerSizeBig, line:GetHeight() - 2)
			talentsFrame.frames = {}
			for i = 1, 70 do
				local talentFrame = CreateFrame("frame", "$parentTalent" .. i, talentsFrame)
				talentFrame:SetPoint("left", talentsFrame, "left", (i-1)*scroll_line_height, 0)
				tinsert(talentsFrame.frames, talentFrame)
				talentFrame:SetSize(scroll_line_height - 2, scroll_line_height - 2)
				local talentIcon = talentFrame:CreateTexture(nil, "artwork")
				talentIcon:SetAllPoints()
				talentFrame.icon = talentIcon
				talentFrame:Hide()
				talentFrame:SetScript("OnEnter", talentIconOnEnter)
				talentFrame:SetScript("OnLeave", talentIconOnLeave)
			end

			--renown
			--[[ shadowlands only
			local renownLevel = DF:CreateLabel(line)
			renownLevel.fontsize = headerFontSize
			renownLevel.alpha = 1
			]]

			--conduits
			--[[ shadowlands only
			local conduitsFrame = CreateFrame("frame", "$parentConduits", line)
			conduitsFrame:SetSize(headerSizeBig, line:GetHeight() - 2)
			conduitsFrame.frames = {}
			for i = 1, 16 do
				local conduitFrame = CreateFrame("frame", "$parentConduit" .. i, conduitsFrame)
				conduitFrame:SetPoint("left", conduitsFrame, "left", (i-1)*(scroll_line_height-2), 0)
				tinsert(conduitsFrame.frames, conduitFrame)
				conduitFrame:SetSize(scroll_line_height - 4, scroll_line_height - 2)
				local conduitIcon = conduitFrame:CreateTexture(nil, "artwork")
				conduitIcon:SetAllPoints()
				conduitFrame.icon = conduitIcon
				conduitFrame:Hide()
				conduitFrame:SetScript("OnEnter", conduitIconOnEnter)
				conduitFrame:SetScript("OnLeave", conduitIconOnLeave)
			end
			--]]

		--store the labels into the line object
		line.specIcon = specIcon
		--line.covenantIcon = covenantIcon
		line.playerName = playerName
		line.itemLevel = itemLevel
		line.repairPct = repairPct
		line.enchantMissing = enchantMissing
		line.gemMissing = gemMissing
		line.talentsFrame = talentsFrame
		--line.renownLevel = renownLevel
		--line.conduitsFrame = conduitsFrame

		line.playerName.fontcolor = defaultTextColor
		line.itemLevel.fontcolor = defaultTextColor
		line.repairPct.fontcolor = defaultTextColor
		line.enchantMissing.fontcolor = defaultTextColor
		line.gemMissing.fontcolor = defaultTextColor
		line.talentsFrame.fontcolor = defaultTextColor
		--line.renownLevel.fontcolor = defaultTextColor
		--line.conduitsFrame.fontcolor = defaultTextColor

		--align with the header
		line:AddFrameToHeaderAlignment(specIcon)
		line:AddFrameToHeaderAlignment(playerName)
		line:AddFrameToHeaderAlignment(itemLevel)
		line:AddFrameToHeaderAlignment(repairPct)
		line:AddFrameToHeaderAlignment(enchantMissing)
		line:AddFrameToHeaderAlignment(gemMissing)
		line:AddFrameToHeaderAlignment(talentsFrame)
		--line:AddFrameToHeaderAlignment(renownLevel)
		--line:AddFrameToHeaderAlignment(conduitsFrame)

		line:AlignWithHeader(header, "left")

		return line
	end

	--refresh player list
	local refreshPlayerInfoScroll = function (self, data, offset, totalLines) --~refresh
		for i = 1, totalLines do
			local index = i + offset
			local dataTable = data[index]

			if (dataTable) then
				local line = self:GetLine(i)
				line.index = index

				local specId = dataTable[7]
				if (specId and specId > 0) then
					local _, _, _, specIcon = GetSpecializationInfoByID(specId)
					line.specIcon:SetTexture(specIcon)
				else
					--todo: try to get the class icon
					line.specIcon:SetTexture("")
				end

				--[[
				local covenantId = dataTable[11]
				if (covenantId > 0) then
					line.covenantIcon:SetTexture(LIB_OPEN_RAID_COVENANT_ICONS[covenantId])
				else
					line.covenantIcon:SetTexture("")
				end
				--]]

				--player name
				line.playerName:SetText(DF:RemoveRealmName(dataTable[1]))
				local _, class = UnitClass(dataTable[1])
				if (class) then
					line.playerName.textcolor = class
				else
					line.playerName.textcolor = "white"
				end

				--item level
				line.itemLevel:SetText(dataTable[3])
				line.itemLevel.fontcolor = "white"

				--repair
				line.repairPct:SetText(dataTable[2] .. "%")

				if (dataTable[2] < 25) then
					line.repairPct.fontcolor = "red"
				elseif (dataTable[2] < 50) then
					line.repairPct.fontcolor = "yellow"
				else
					line.repairPct.fontcolor = "white"
				end

				--enchant missing
				local missingEnchants = dataTable[6]
				if (#missingEnchants == 0) then
					line.enchantMissing:SetText("")
				else
					local s = ""
					for i = 1, #missingEnchants do
						local equipSlotIcon = DF:GetArmorIconByArmorSlot(missingEnchants[i])
						local iconString = "|T" .. equipSlotIcon .. ":" .. (scroll_line_height-2) .. ":" .. (scroll_line_height-2) .. ":0:0:64:64:" .. 0.1*64 .. ":" .. 0.9*64 .. ":" .. 0.1*64 .. ":" .. 0.9*64 .. "|t"
						s = s .. iconString
					end
					line.enchantMissing:SetText(s)
				end

				--gem missing
				local missingGems = dataTable[5]
				if (#missingGems == 0) then
					line.gemMissing:SetText("")
				else
					local s = ""
					for i = 1, #missingGems do
						local equipSlotIcon = DF:GetArmorIconByArmorSlot(missingGems[i])
						local iconString = "|T" .. equipSlotIcon .. ":" .. (scroll_line_height-2) .. ":" .. (scroll_line_height-2) .. ":0:0:64:64:" .. 0.1*64 .. ":" .. 0.9*64 .. ":" .. 0.1*64 .. ":" .. 0.9*64 .. "|t"
						s = s .. iconString
					end
					line.gemMissing:SetText(s)
				end

				--talents
				local talents = dataTable[9] or {}
				if (#talents == 0) then
					for i = 1, #line.talentsFrame.frames do
						line.talentsFrame.frames[i]:Hide()
					end
				else
					for i = 1, #line.talentsFrame.frames do
						local talentId = talents[i]
						local talentWidget = line.talentsFrame.frames[i]
						if (talentId) then
							talentWidget:Show()

							--need a new call here
							--local a, b, texture = GetTalentInfoByID(talentId)
							local talentName, _, talentIcon = GetSpellInfo(talentId)
							
							talentWidget.icon:SetTexture(talentIcon)
							talentWidget.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
							talentWidget.talentId = talentId
						else
							talentWidget:Hide()
						end
					end
				end

				--renown
				--[[
				line.renownLevel:SetText(dataTable[8])
				line.renownLevel.fontcolor = "white"
				--]]

				--conduits
				--[[
				--line.conduitsFrame = conduitsFrame
				local conduits = dataTable[10] or {}
				for i = 1, #line.conduitsFrame.frames do
					line.conduitsFrame.frames[i]:Hide()
				end

				if (#conduits > 0) then
					local conduitIndex = 1
					for i = 1, #conduits, 2 do
						local conduitSpellId = conduits[i]
						local conduitItemLevel = conduits[i+1]

						local conduitWidget = line.conduitsFrame.frames[conduitIndex]
						if (conduitSpellId) then
							conduitWidget:Show()
							local texture = GetSpellTexture(conduitSpellId)
							conduitWidget.icon:SetTexture(texture)
							conduitWidget.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
							conduitWidget.spellId = conduitSpellId
						else
							conduitWidget:Hide()
						end

						conduitIndex = conduitIndex + 1
					end
				end
				--]]
			end
		end
	end

	--create the player info scroll
	local playerInfoScroll = DF:CreateScrollBox(frame, "$parentplayerInfoScroll", refreshPlayerInfoScroll, {}, scroll_width, scroll_height, scroll_lines, scroll_line_height)
	DF:ReskinSlider(playerInfoScroll)
	playerInfoScroll:SetPoint("topleft", frame, "topleft", 0, scrollY)
	playerInfoScroll:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))

	local gradientBelowTheLine = DF:CreateTexture(playerInfoScroll, {gradient = "vertical", fromColor = {0, 0, 0, 0.3}, toColor = "transparent"}, 1, 100, "artwork", {0, 1, 0, 1}, "gradientBelowTheLine")
	gradientBelowTheLine:SetPoint("bottoms", playerInfoScroll, 1, 1)

	--create lines for the spell scroll
	for i = 1, scroll_lines do
		playerInfoScroll:CreateLine(scroll_createline)
	end
	--store the scroll within the frame tab
	frame.playerInfoScroll = playerInfoScroll

	function playerInfoScroll.RefreshData()
		--get the information needed
		local openRaidLib = LibStub:GetLibrary("LibOpenRaid-1.0")
		local allPlayersGear = openRaidLib.GetAllUnitsGear()
		local allPlayersInfo = openRaidLib.GetAllUnitsInfo()

		--get which column is currently selected and the sort order
		local columnIndex, order = RaidAssistPlayerCheckHeader:GetSelectedColumn()
		local result = PlayerCheck.db.cache

		--remove from the cache all players not found in the group
		if (IsInRaid()) then
			for i = #result, 1, -1 do
				local isInRaid = UnitInRaid(result[i][1])
				if (not isInRaid) then
					tremove(result, i)
				end
			end

		elseif (IsInGroup()) then
			for i = #result, 1, -1 do
				local isInRaid = UnitInParty(result[i][1])
				if (not isInRaid) then
					tremove(result, i)
				end
			end
		end

		--create a list with player indexes from the cache
		--make a list of player names in the cache
		local allPlayersCached = {}
		for i = 1, #result do
			--hold the index of the player
			allPlayersCached[result[i][1]] = i
		end

		local sortByIndex = 1

		for playerName, gearTable in pairs(allPlayersGear) do
			local durability =  gearTable.durability
			local iLevel = gearTable.ilevel
			local weaponEnchant = gearTable.weaponEnchant
			local noGems = gearTable.noGems
			local noEnchants = gearTable.noEnchants

			local needToAdd = false
			local thisResult = result[allPlayersCached[playerName]]
			if (not thisResult) then
				thisResult = {}
				needToAdd = true
			end

			thisResult[1] = playerName
			thisResult[2] = durability
			thisResult[3] = iLevel
			thisResult[4] = weaponEnchant
			thisResult[5] = noGems
			thisResult[6] = noEnchants

			local playerGeneralInfo = allPlayersInfo[playerName] or {}
			local specId = playerGeneralInfo.specId or 0
			local renown = playerGeneralInfo.renown or 1
			local talents = playerGeneralInfo.talents or {}
			local conduits = playerGeneralInfo.conduits or {}
			local covenantId = playerGeneralInfo.covenantId or 0

			local specSortToken = (((specId) + 700) ^ 4) + tonumber(string.byte(playerName, 1) .. string.byte(playerName, 2))
			--print(playerName, specSortToken, specId, type(specSortToken))

			thisResult[7] = specId
			thisResult[8] = renown
			thisResult[9] = talents
			thisResult[10] = conduits
			thisResult[11] = covenantId

			--sort id for spec
			thisResult[12] = specSortToken

			if (needToAdd) then
				result[#result+1] = thisResult
			end
		end

		for i = 1, #result do
			local thisResult = result[i]
			if (not thisResult[12]) then
				thisResult[12] = thisResult[7] or 0
			end
		end

		--sort by spec
		if (columnIndex == 1) then
			sortByIndex = 7

		--player name
		elseif (columnIndex == 2) then
			sortByIndex = 1

		--item level
		elseif (columnIndex == 3) then
			sortByIndex = 3

		--durability
		elseif (columnIndex == 4) then
			sortByIndex = 2

		--renown
		elseif (columnIndex == 8) then
			sortByIndex = 8

		end

		if (order == "DESC") then
			table.sort (result, function (t1, t2) return t1[sortByIndex] > t2[sortByIndex] end)
		else
			table.sort (result, function (t1, t2) return t1[sortByIndex] < t2[sortByIndex] end)
		end

		PlayerCheck.db.cache = result

		playerInfoScroll:SetData(result)
		playerInfoScroll:Refresh()
	end

	C_Timer.After(0.5, function()
		playerInfoScroll.RefreshData()
	end)

	frame:SetScript("OnShow", function()
		playerInfoScroll.RefreshData()
	end)
end

if (canInstall) then
	RA:InstallPlugin(PlayerCheck.displayName, "OPPlayerCheck", PlayerCheck, default_config)
end