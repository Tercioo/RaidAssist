
local RA = _G.RaidAssist
local L = LibStub ("AceLocale-3.0"):GetLocale("RaidAssistAddon")
local defaultPriority = 14
local DF = DetailsFramework
local _

--battle res default config
local default_config = {
	enabled = true,
	menu_priority = 1,
	saved_lists = {},
	latest_raid_map = 1448,
	latest_menu_option_boss_selected = 0,
	player_loot_selection = {},
}

local scrollBossWidth = 200
local scrollBossHeight = 659
local bossLinesHeight = 40
local amoutBossLines = math.floor(scrollBossHeight / bossLinesHeight)

--raid leader query for a single user
local COMM_QUERY_USERLIST = "BISU"
--raid leader query the entire raid
local COMM_QUERY_RAIDLIST = "BISR"
--a user sent the list
local COMM_RECEIVED_LIST = "BISL"

local icon_texture = [[Interface\PaperDollInfoFrame\UI-EquipmentManager-Toggle]]
local icon_texcoord = {l=0.078125, r=0.921875, t=0.078125, b=0.921875}
local text_color_enabled = {r=1, g=1, b=1, a=1}
local text_color_disabled = {r=0.5, g=0.5, b=0.5, a=1}
local scrollbox_line_backdrop_color = {.1, .10, .10, 0.5}
local scrollbox_line_backdrop_color_hightlight = {.4, .4, .4, 0.6}

local BisListRaid = {version = "v0.1", pluginname = "BisListRaid", pluginId = "BILR", displayName = "Raid Bis List"}
BisListRaid.IsDisabled = false
local canInstallPlugin = true
BisListRaid.last_data_request = 0
BisListRaid.last_data_sent = 0

BisListRaid.OnEnable = function(plugin)
	--enabled from the options panel.
end

BisListRaid.OnDisable = function(plugin)
	--disabled from the options panel.
end

BisListRaid.OnProfileChanged = function(plugin)
	if (plugin.db.enabled) then
		BisListRaid.OnEnable(plugin)
	else
		BisListRaid.OnDisable(plugin)
	end

	if (plugin.options_built) then
		plugin.main_frame:RefreshOptions()
	end
end

BisListRaid.menu_text = function(plugin)
	if (BisListRaid.db.enabled) then
		return icon_texture, icon_texcoord, "Loot (Raid List)", text_color_enabled
	else
		return icon_texture, icon_texcoord, "Loot (Raid List)", text_color_disabled
	end
end

BisListRaid.menu_popup_show = function(plugin, ct_frame, param1, param2)
	RA:AnchorMyPopupFrame(BisListRaid)
end

BisListRaid.menu_popup_hide = function(plugin, ct_frame, param1, param2)
	BisListRaid.popup_frame:Hide()
end

BisListRaid.menu_on_click = function(plugin)
	RA.OpenMainOptions(BisListRaid)
end

local onUpdateCallback = function(self, deltaTime) --õnupdate ~onupdate
	if (GameTooltip:IsShown()) then
		local focusedFrame = GetMouseFocus()
		if (focusedFrame ~= WorldFrame and not focusedFrame.bBisListFrame) then
			local tooltipData = GameTooltip:GetTooltipData()
			if (tooltipData) then
				if ((tooltipData.guid and tooltipData.guid:find("^Item")) or tooltipData.hyperlink) then
					if (type(tooltipData.id) == "number") then
						local lootInfo = BisListRaid.AllAvailableRaidLoot[tooltipData.id]
						if (lootInfo) then
							if (BisListRaid.main_frame.filter ~= tooltipData.id) then
								BisListRaid.main_frame.filter = tooltipData.id
								BisListRaid.main_frame.lootListScrollBox:RefreshMe()
							end
							return
						end
					end
				end
			end
		end
	end

	if (BisListRaid.main_frame.filter) then
		BisListRaid.main_frame.filter = nil
		BisListRaid.main_frame.lootListScrollBox:RefreshMe()
	end
end

local onShowOptionsFrameCallback = function()
	BisListRaid.QueryData()
	local openRaidLib = LibStub:GetLibrary("LibOpenRaid-1.0")

	if (time() > BisListRaid.GearRequestCooldown) then
		--todo: replace this with request all gear data
		openRaidLib.RequestAllData()
		BisListRaid.GearRequestCooldown = time() + 10
	end

	BisListRaid.main_frame:SetScript("OnUpdate", onUpdateCallback)
end

function BisListRaid.OnShowOnOptionsPanel()
	local OptionsPanel = BisListRaid.OptionsPanel
	BisListRaid.BuildOptions(OptionsPanel)

	BisListRaid.main_frame:SetScript("OnShow", onShowOptionsFrameCallback)

	BisListRaid.main_frame:SetScript("OnHide", function()
		BisListRaid.main_frame:SetScript("OnUpdate", nil)
	end)
end

-----------------

function BisListRaid.OnEnterRaidGroup()
	BisListRaid.QueryData()
end

BisListRaid.OnInstall = function(plugin)
	BisListRaid.db.menu_priority = defaultPriority
	RA:RegisterForEnterRaidGroup(BisListRaid.OnEnterRaidGroup)
	BisListRaid.GearRequestCooldown = 0
end

function BisListRaid.QueryData()
	if (not IsInRaid()) then
		return
	end

	if (not BisListRaid:UnitHasAssist("player")) then
		return
	end

	if (BisListRaid.last_data_request+5 > time()) then
		return
	end

	BisListRaid:SendPluginCommMessage("BLR", "RAID", _, _, BisListRaid:GetPlayerNameWithRealm())
	BisListRaid.last_data_request = time()
end

--[playername] = {ilvl = 0, items = {[itemId] = ilevel}, specId = 0}
local getRaidSelectedLoot = function()
	return BisListRaid.db.player_loot_selection
end

function BisListRaid.OnReceiveComm(sourceName, prefix, sourcePluginVersion, data)
	if (prefix == COMM_RECEIVED_LIST) then
		--local playerItemLevel = data.ilvl
		--local itemList = data.items = map[itemId] = array{encounterId, itemQuality, thisItemAlreadyOwnItemLevel, upgradePercent}
		--local specId = data.specId

		local myGuildName = GetGuildInfo("player")
		local sourceGuildName = GetGuildInfo(sourceName)

		--don't accept bis list from players outside the guild
		if (myGuildName ~= sourceGuildName) then
			return
		end

		local raidBisList = getRaidSelectedLoot()
		raidBisList[sourceName] = data

		if (BisListRaid.main_frame and BisListRaid.main_frame.lootListScrollBox) then
			if (BisListRaid.main_frame.lootListScrollBox:IsShown()) then
				BisListRaid.main_frame.lootListScrollBox:RefreshMe()
			end
		end
	end
end

--getRaidSelectedLoot()[PlayerName].items {array indexes}
local CONST_INDEX_BOSSID = 1
local CONST_INDEX_QUALITYCOLOR = 2
local CONST_INDEX_ITEMLEVEL = 3
local CONST_INDEX_UPGRADE_PERCENT = 4
local CONST_INDEX_IS_OFFSPEC = 5
local CONST_INDEX_NOTE_TEXT = 6

--array indexes for the data created by getItemListForBossID()
--non present indexes uses the same as above
local CONST_INDEX_PLAYERNAME = 1
local CONST_INDEX_ITEMID = 4
local CONST_INDEX_PLAYERLIST = 5
local CONST_INDEX_PLAYERITEMLEVEL = 6
local CONST_INDEX_PLAYERSPEC = 7
local CONST_INDEX_UPGRADE_PERCENT2 = 8 --on the table built by getItemListForBossID(), upgrade percent has 8th index
local CONST_INDEX_IS_OFFSPEC2 = 9 --on the table built by getItemListForBossID(), upgrade percent has 9th index
local CONST_INDEX_NOTE_TEXT2 = 10

local buildRaidPlayersList = function()
	local playersTable = {}
	if (IsInRaid()) then
		for i = 1, GetNumGroupMembers() do
			local unitId = "raid" .. i
			if (UnitIsInMyGuild(unitId)) then
				local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i)
				playersTable[name] = {fileName, subgroup, online, combatRole, unitId}
			end
		end
	end
	return playersTable
end

--build data to be use when refreshing the item list for the boss
local getItemListForBossID = function(bossId)
	local raidBisList = getRaidSelectedLoot() --map[playerName] = map[playerTable] = map[.items = array{encounterId, itemQuality, thisItemAlreadyOwnItemLevel, upgradePercent}, .specId = number, .ilvl = number]
	local playerList = buildRaidPlayersList() --map[playerName] = indexed{class, subGroup, isOnline, role}
	local itemsForBoss = {}

	for playerName, playerTable in pairs(raidBisList) do
		for itemId, itemTable in pairs(playerTable.items) do
			if (itemTable[CONST_INDEX_BOSSID] == bossId) then
				local qualityColor = itemTable[CONST_INDEX_QUALITYCOLOR]
				local itemLevel = itemTable[CONST_INDEX_ITEMLEVEL] or 0
				local upgradePercent = itemTable[CONST_INDEX_UPGRADE_PERCENT] or 0
				local isOffSpec = itemTable[CONST_INDEX_IS_OFFSPEC] == 1
				local noteText = itemTable[CONST_INDEX_NOTE_TEXT] or false

				itemsForBoss[#itemsForBoss+1] = {playerName, qualityColor, itemLevel, itemId, playerList[playerName] or {}, playerTable.ilvl, playerTable.specId, upgradePercent, isOffSpec, noteText}
			end
		end
	end

	table.sort(itemsForBoss, function(t1, t2)
		return t1[CONST_INDEX_ITEMLEVEL] < t2[CONST_INDEX_ITEMLEVEL]
	end)
	return itemsForBoss
end

local getCurrentBossSelected = function()
	return BisListRaid.db.latest_menu_option_boss_selected
end

local setCurrentBossSelected = function(bossId)
	BisListRaid.db.latest_menu_option_boss_selected = bossId
end

RA:RegisterPluginComm(COMM_QUERY_USERLIST, BisListRaid.OnReceiveComm)
RA:RegisterPluginComm(COMM_QUERY_RAIDLIST, BisListRaid.OnReceiveComm)
RA:RegisterPluginComm(COMM_RECEIVED_LIST, BisListRaid.OnReceiveComm)

function BisListRaid.BuildOptions(frame)
	if (frame.FirstRun) then
		return
	end

	local CONST_LOOT_SELECTIONFRAME_WIDTH = 635
	local CONST_LOOT_BUTTON_WIDTH = 200
	local CONST_LOOT_BUTTON_HEIGHT = 50

	local lootSpaceWidth = CONST_LOOT_BUTTON_WIDTH + 10
	local lootSpaceHeight = CONST_LOOT_BUTTON_HEIGHT + 10
	local lootIconSize = CONST_LOOT_BUTTON_HEIGHT - 5
	local lootButtonPerRow = math.floor(CONST_LOOT_SELECTIONFRAME_WIDTH / lootSpaceWidth)

	local CONST_LOOT_LIST_FRAME_WIDTH = 635
	local scrollLootListFrameHeight = 20
	local amountLootLines = 30
	local lootLineHeight = 20

	local startOffsetX = 5
	local startOffsetY = -5

	local lootNameFontSize = 10
	local lootSlotFontSize = 10

	frame.FirstRun = true

	--window object
	local mainFrame = frame
	BisListRaid.main_frame = frame
	mainFrame:SetSize(722, 385)

	--left boss selection scroll frame functions
	local refreshBossList = function(self, data, offset, totalLines)
		--update boss scroll
		for i = 1, totalLines do
			local index = i + offset
			local thisData = data[index]
			if (thisData) then
				local line = self:GetLine(i)
				local bossName = thisData.bossName
				local bossRaidName = thisData.bossRaidName
				local bossIcon = thisData.bossIcon
				local bossId = thisData.journalEncounterID

				--update the line
				line.bossName:SetText(bossName)
				line.bossName:SetPoint("left", line.bossIcon, "right", -8, 6)
				DF:TruncateText(line.bossName, 130)
				line.bossRaidName:SetText(bossRaidName)
				DF:TruncateText(line.bossRaidName, 130)

				line.bossIcon:SetTexture(bossIcon)
				line.bossIcon:SetTexCoord(unpack(thisData.bossIconCoords))
				line.bossIcon:SetSize(thisData.bossIconSize[1], thisData.bossIconSize[2])

				line.bossIcon:SetPoint("left", line, "left", 2, 0)
				line.bossName:Show()
				line.bossRaidName:Show()

				line.bossId = bossId
				line:Show()
			end
		end
	end

	--create the boss selector
	local bUseClassId = false
	local arrayOfBosses, bossInfoData, lootInfoData = RA:GetExpansionBossList(bUseClassId)
	BisListRaid.AllAvailableRaidLoot = {}

	--build map[itemId] = lootInfo of all items available in raids
	for encounterId, lootTable in pairs(lootInfoData) do
		for i = 1, #lootTable do
			local lootInfo = lootTable[i]
			BisListRaid.AllAvailableRaidLoot[lootInfo.itemID] = lootInfo
		end
	end

	local bossScrollFrame = DF:CreateScrollBox(mainFrame, "$parentBossScrollBox", refreshBossList, arrayOfBosses, scrollBossWidth, scrollBossHeight, amoutBossLines, bossLinesHeight)
	mainFrame.bossScrollFrame = bossScrollFrame

	function BisListRaid.GetBossScrollFrame()
		return bossScrollFrame
	end

	local selectBoss = function(bossId, bossButton)
		setCurrentBossSelected(bossId)

		--update the boss button selected indicator
		bossButton.selectedInidicator:Show()
		for lineIndex, line in pairs(bossScrollFrame:GetLines()) do
			if (line.bossId ~= bossId) then
				line.selectedInidicator:Hide()
			end
		end

		--refresh the loot list for this boss
		mainFrame.lootListScrollBox:RefreshMe()
	end

	local onClickBossButton = function(self)
		local bossId = self.bossId
		selectBoss(bossId, self)
	end

	local onEnterBossLine = function(self)
		self:SetBackdropColor(unpack(scrollbox_line_backdrop_color_hightlight))
	end

	local onLeaveBossLine = function(self)
		self:SetBackdropColor(unpack(scrollbox_line_backdrop_color))
	end

	local createdBossLine = function(self, index)
		local line = CreateFrame("button", "$parentLine" .. index, self, "BackdropTemplate")
		line:SetPoint("topleft", self, "topleft", 1, -((index-1) * (bossLinesHeight+1)) - 1)
		line:SetSize(scrollBossWidth-2, bossLinesHeight)
		line:RegisterForClicks("LeftButtonDown", "RightButtonDown")
		DF:ApplyStandardBackdrop(line)

		line:SetScript("OnEnter", onEnterBossLine)
		line:SetScript("OnLeave", onLeaveBossLine)
		line:SetScript("OnClick", onClickBossButton)

		line.index = index

		local selectedInidicator = line:CreateTexture(nil, "border")
		selectedInidicator:SetAllPoints()
		selectedInidicator:SetColorTexture(1, 1, 1, 0.4)
		selectedInidicator:Hide()
		line.selectedInidicator = selectedInidicator

		--boss icon
		local bossIcon = line:CreateTexture("$parentIcon", "overlay")
		bossIcon:SetSize(bossLinesHeight + 30, bossLinesHeight-4)
		bossIcon:SetPoint("left", line, "left", 2, 0)
		line.bossIcon = bossIcon

		local bossName = line:CreateFontString(nil, "overlay", "GameFontNormal")
		local bossRaid = line:CreateFontString(nil, "overlay", "GameFontNormal")
		bossName:SetPoint("left", bossIcon, "right", -8, 6)
		bossRaid:SetPoint("topleft", bossName, "bottomleft", 0, -2)
		DF:SetFontSize(bossName, 10)
		DF:SetFontSize(bossRaid, 9)
		DF:SetFontColor(bossRaid, "silver")

		line.bossName = bossName
		line.bossRaidName = bossRaid

		return line
	end

	--create the scrollbox lines
	for i = 1, amoutBossLines do
		bossScrollFrame:CreateLine(createdBossLine, i)
	end

	DF:ReskinSlider(bossScrollFrame)
	DF:ApplyStandardBackdrop(bossScrollFrame)

	mainFrame.BossSelectionBox = bossScrollFrame
	bossScrollFrame:SetPoint("topleft", mainFrame, "topleft", 0, 5)

	frame.bossScrollFrame:Refresh()

----------------------------------------------------------------------------------------------------------------------------

	local lootListFrame = CreateFrame("frame", nil, mainFrame, "BackdropTemplate")
	lootListFrame:SetPoint("topleft", bossScrollFrame, "topright", 26, 0)
	lootListFrame:SetPoint("bottomleft", bossScrollFrame, "bottomright", 26, 0)
	lootListFrame:SetWidth(CONST_LOOT_LIST_FRAME_WIDTH)
	mainFrame.lootListFrame = lootListFrame
	DF:ApplyStandardBackdrop(lootListFrame)

	--header
	local columnAlign = "left"
	local columnAlignOffset = 0
	local headerSizeSmall = 50
	local headerSizeMedium = 75
	local headerSizeBig = 150
	local headerSizeBigPlus = 140
	local headerSizeTalents = 387
	local lineSeparatorWidth = 1
	local defaultTextColor = {.89, .89, .89, .89}
	local headerFontSize = 11

	--create the header and the scroll frame
	local headerTable = {
		{text = "", width = 22, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC", selected = true},
		{text = "Name", width = 80, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
		{text = "Player ILvL", width = 60, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
		{text = "Item", width = 240, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
		{text = "Have The Item", width = 80, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
		{text = "Upgrade %", width = 70, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
		{text = "Off Spec", width = 50, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
		{text = "Note", width = 50, align = columnAlign, offset = columnAlignOffset, dataType = "number", canSort = true, order = "DESC"},
	}

	local refreshLootList = function(self, data, offset, totalLines) --~refresh ~update
		--update boss scroll
		local libOpenRaid = LibStub:GetLibrary("LibOpenRaid-1.0")

		--sort by itemId and then sort by upgrade level
		table.sort(data, function(t1, t2)
			if (t1[4] ~= t2[4]) then
				return t1[4] < t2[4]
			else
				return t1[8] > t2[8]
			end
		end)

		local lastestItemId = 0
		local alpha1 = 0.3
		local alpha2 = 0.8
		local alphaState = true

		local lineIndex = 1
		for i = 1, totalLines do
			local index = i + offset
			local thisData = data[index] --this data is created on getItemListForBossID()
			local passFilter = true

			if (thisData) then
				if (BisListRaid.main_frame.filter) then
					passFilter = false
					if (thisData[CONST_INDEX_ITEMID] == BisListRaid.main_frame.filter) then
						passFilter = true
					end
				end
			end

			if (thisData and passFilter) then
				local line = self:GetLine(lineIndex)
				lineIndex = lineIndex + 1
				local playerName = thisData[CONST_INDEX_PLAYERNAME]
				local playerNameOrig = playerName
				playerName = DF:RemoveRealmName(playerName)

				local qualityColor = thisData[CONST_INDEX_QUALITYCOLOR]
				local currentItemLevel = thisData[CONST_INDEX_ITEMLEVEL]
				local itemId = thisData[CONST_INDEX_ITEMID]
				local playerInfo = thisData[CONST_INDEX_PLAYERLIST]
				local playerSpecId = thisData[CONST_INDEX_PLAYERSPEC]
				local playerItemLevel = thisData[CONST_INDEX_PLAYERITEMLEVEL]
				local upgradePercent = thisData[CONST_INDEX_UPGRADE_PERCENT2]
				local isOffSpec = thisData[CONST_INDEX_IS_OFFSPEC2]
				local noteText = thisData[CONST_INDEX_NOTE_TEXT2]

				local classFileName, subgroup, online, combatRole, unitId = unpack(playerInfo)
				local unitInfo = libOpenRaid.GetUnitInfo(unitId or playerNameOrig or "none")
				local specId = playerSpecId or (unitInfo and unitInfo.specId)

				local playerGear = libOpenRaid.GetUnitGear(unitId or playerNameOrig or "none")
				local characterItemLevel = playerItemLevel or (playerGear and playerGear.ilevel) or ""
				local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemId)

				if (lastestItemId == itemId) then
					local alphaAmount = alphaState and alpha1 or alpha2
					line.lineBackground:SetAlpha(alphaAmount)
					line.lineBackground.defaultAlpha = alphaAmount
				else
					alphaState = not alphaState
					local alphaAmount = alphaState and alpha1 or alpha2
					line.lineBackground.defaultAlpha = alphaAmount
					line.lineBackground:SetAlpha(alphaAmount)
					lastestItemId = itemId
				end

				if (specId) then
					local left, right, top, bottom = RA:GetTexCoordForSpecId(specId)
					line.specIcon:SetTexture([[Interface/AddOns/RaidAssist/media/spec_icons_normal]])
					line.specIcon:SetTexCoord(left, right, top, bottom)
				else
					line.specIcon:SetTexture("")
				end

				if (classFileName) then
					playerName = DF:AddClassColorToText(playerName, classFileName)

				elseif (unitInfo and unitInfo.class) then
					playerName = DF:AddClassColorToText(playerName, unitInfo.class)
				end

				line.playerName:SetText(playerName)
				line.itemLevel:SetText(format("%.1f", characterItemLevel))

				local equipSlotId = C_Item.GetItemInventoryTypeByID(itemLink) + 1 --return slotId starting from zero
				local equipSlotIcon = DF:GetArmorIconByArmorSlot(equipSlotId)
				local slotIconString = "|T" .. equipSlotIcon .. ":" .. (lootLineHeight-4) .. ":" .. (lootLineHeight-4) .. ":0:0:64:64:" .. 0.1*64 .. ":" .. 0.9*64 .. ":" .. 0.1*64 .. ":" .. 0.9*64 .. "|t"
				local itemIconString = "|T" .. itemTexture .. ":" .. (lootLineHeight-4) .. ":" .. (lootLineHeight-4) .. ":0:0:64:64:" .. 0.1*64 .. ":" .. 0.9*64 .. ":" .. 0.1*64 .. ":" .. 0.9*64 .. "|t"

				local whiteItemLink = itemLink
				whiteItemLink = whiteItemLink:gsub("|c%x%x%x%x%x%x%x%x", "|cffffffff")
				line.itemString:SetText(slotIconString .. " " .. itemIconString .. " " .. whiteItemLink)

				line.itemLink = itemLink

				line.alreadyHaveIlevelString:SetText(currentItemLevel)
				if (currentItemLevel > 0) then
					line.HasItemIndicator:Show()
					--check if the item is equipped by the player
					if (playerGear and playerGear.equippedGear) then
						for tableIndex = 1, #playerGear.equippedGear do
							local equippedItemInfo = playerGear.equippedGear[tableIndex]
							if (equippedItemInfo.itemId == itemId) then
								line.alreadyHaveIlevelString:SetText(currentItemLevel .. " equipped")
							end
						end
					end
				else
					line.HasItemIndicator:Hide()
				end

				line.upgradePercentString:SetText(upgradePercent and upgradePercent .. "%" or "0%")

				if (upgradePercent < 4) then
					DF:SetFontColor(line.upgradePercentString, "forestgreen")
				elseif (upgradePercent < 8) then
					DF:SetFontColor(line.upgradePercentString, "limegreen")
				else
					DF:SetFontColor(line.upgradePercentString, "lawngreen")
				end

				line.offSpecIndicator:SetShown(isOffSpec)

				line.noteFrame:SetShown(noteText and noteText ~= "" and true)
				line.noteFrame.Text = noteText
			end
		end
	end

	--loot list frame
	local lootListScrollBox = DF:CreateScrollBox(lootListFrame, "$parentLootListScrollBox", refreshLootList, {}, CONST_LOOT_LIST_FRAME_WIDTH, scrollBossHeight, amountLootLines, lootLineHeight)
	mainFrame.lootListScrollBox = lootListScrollBox
	lootListScrollBox:SetAllPoints()

	local gradientBelowTheLine = DF:CreateTexture(lootListScrollBox, {gradient = "vertical", fromColor = {0, 0, 0, 0.3}, toColor = "transparent"}, 1, 100, "artwork", {0, 1, 0, 1}, "gradientBelowTheLine")
	gradientBelowTheLine:SetPoint("bottoms", lootListScrollBox, 1, 1)

	_G[lootListScrollBox:GetName() .. "ScrollBar"]:Hide()

	function lootListScrollBox:RefreshMe()
		--build an array for the loot list scroll update the list
		local currentBossSelected = getCurrentBossSelected()
		local lootListForSelectedBoss = getItemListForBossID(currentBossSelected)

		lootListScrollBox:SetData(lootListForSelectedBoss)
		lootListScrollBox:Refresh()
	end

	local onEnterLine = function(line)
		line.lineBackground:SetAlpha(Saturate(line.lineBackground.defaultAlpha + 0.6))
	end

	local onLeaveLine = function(line)
		line.lineBackground:SetAlpha(line.lineBackground.defaultAlpha)
	end

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
		line_separator_height = lootListScrollBox:GetHeight() + 20,
		line_separator_gap_align = true,
		header_click_callback = headerOnClickCallback,
	}

	local header = DF:CreateHeader(lootListFrame, headerTable, headerOptions, "RaidAssistBisListRaidHeader")
	header:SetPoint("topleft", lootListFrame, "topleft", 0, 0)

	local itemFrameOnEnter = function(itemFrame)
		local line = itemFrame:GetParent()
		GameTooltip:SetOwner(line, "ANCHOR_TOPRIGHT")
		GameTooltip:SetHyperlink(line.itemLink)
		GameTooltip:Show()

		onEnterLine(line)
	end

	local itemFrameOnLeave = function(itemFrame)
		GameTooltip:Hide()
		onLeaveLine(itemFrame:GetParent())
	end

	local noteFrameOnEnter = function(noteFrame)
		GameCooltip:Preset(2)
		GameCooltip:AddLine(noteFrame.Text)
		GameCooltip:Show(noteFrame)
	end

	local noteFrameOnLeave = function(noteFrame)
		GameCooltip:Hide()
	end

	local createLineForLootScroll = function(self, index) --~create
		local line = CreateFrame("button", "$parentLine" .. index, self, "BackdropTemplate")
		line.bBisListFrame = true

		line:SetPoint("topleft", self, "topleft", 2, -((index-0) * (lootLineHeight+1)) - 1)
		line:SetSize(CONST_LOOT_LIST_FRAME_WIDTH-3, lootLineHeight)
		line.id = index

		line:SetScript("OnEnter", onEnterLine)
		line:SetScript("OnLeave", onLeaveLine)

		DF:Mixin(line, DF.HeaderFunctions)

		local lineBackground = line:CreateTexture(nil, "border", nil, -3)
		lineBackground:SetAllPoints()
		lineBackground.defaultAlpha = 0.2
		lineBackground:SetColorTexture(.2, .2, .2)
		lineBackground:SetAlpha(lineBackground.defaultAlpha)
		line.lineBackground = lineBackground

		local playerNameFrame = CreateFrame("frame", nil, line, "BackdropTemplate")
		playerNameFrame:SetSize(headerTable[1].width + columnAlignOffset, header.options.header_height)
		playerNameFrame:EnableMouse(false)
		playerNameFrame.bBisListFrame = true

		--player information
		--spec icon
		local specIcon = DF:CreateImage(line, "", line:GetHeight() - 2, line:GetHeight() - 2)
		specIcon.texcoord = {.1, .9, .1, .9}
		specIcon:SetColorTexture(1, 1, 1, 1)
		specIcon.originalWidth = specIcon.width
		specIcon.originalHeight = specIcon.height
		specIcon.hoverWidth = specIcon.width * 1.15
		specIcon.hoverHeight = specIcon.height * 1.15

		--player name
		local playerName = DF:CreateLabel(line)
		playerName:SetText("player name here")
		playerName.alpha = 1
		playerName.fontsize = headerFontSize

		--have the item indicator
		line.HasItemIndicator = DetailsFramework:CreateTexture(line, {gradient = "horizontal", fromColor = {0, 0, 0, 0}, toColor = {.2, .9, .2, 0.1}}, CONST_LOOT_LIST_FRAME_WIDTH, 1, "border", {0, 1, 0, 1})
		line.HasItemIndicator:SetPoint("rights", line, -1)

		--ilevel
		local itemLevel = DF:CreateLabel(line)
		itemLevel.fontsize = headerFontSize
		itemLevel.alpha = 1

		--item string
		local itemFrame = CreateFrame("frame", nil, line)
		itemFrame:SetScript("OnEnter", itemFrameOnEnter)
		itemFrame:SetScript("OnLeave", itemFrameOnLeave)
		itemFrame:SetSize(headerTable[4].width, lootLineHeight - 2)
		itemFrame.bBisListFrame = true

		local itemString = DF:CreateLabel(itemFrame)
		itemString:SetPoint("left", itemFrame, "left", 2, 0)
		itemString.fontsize = headerFontSize
		itemString.alpha = 1

		--already have item level string
		local alreadyHaveIlevelString = DF:CreateLabel(line)
		alreadyHaveIlevelString.fontsize = headerFontSize
		alreadyHaveIlevelString.alpha = 1

		--upgrade arrow
		local arrowUp = line:CreateTexture(nil, "artwork")
		arrowUp:SetTexture([[Interface\BUTTONS\UI-MicroStream-Green]])
		arrowUp:SetTexCoord(0, 1, 1, 0)
		arrowUp:SetSize(16, 16)

		--upgrade percent string
		local upgradePercentString = DF:CreateLabel(line)
		upgradePercentString.fontsize = headerFontSize
		upgradePercentString.alpha = 1
		upgradePercentString:SetPoint("left", arrowUp, "right", -2, 0)

		--offspec checkmask
		local offSpecIndicator = line:CreateTexture(nil, "artwork")
		offSpecIndicator:SetTexture([[Interface\BUTTONS\UI-CheckBox-Check]])
		offSpecIndicator:SetSize(20, 20)

		--note icon
		local noteFrame = CreateFrame("frame", nil, line)
		noteFrame:SetSize(20, 20)
		noteFrame:SetScript("OnEnter", noteFrameOnEnter)
		noteFrame:SetScript("OnLeave", noteFrameOnLeave)
		noteFrame.bBisListFrame = true

		local noteIcon = noteFrame:CreateTexture(nil, "artwork")
		noteIcon:SetPoint("center", 0, 0)
		noteIcon:SetTexture([[Interface\BUTTONS\UI-GuildButton-OfficerNote-Up]])

		--store the labels into the line object
		line.specIcon = specIcon
		line.playerName = playerName
		line.itemLevel = itemLevel
		line.itemString = itemString
		line.alreadyHaveIlevelString = alreadyHaveIlevelString
		line.upgradePercentString = upgradePercentString
		line.offSpecIndicator = offSpecIndicator
		line.noteFrame = noteFrame

		line.playerName.fontcolor = defaultTextColor
		line.itemLevel.fontcolor = defaultTextColor
		line.itemString.fontcolor = defaultTextColor
		line.alreadyHaveIlevelString.fontcolor = defaultTextColor
		line.upgradePercentString.fontcolor = defaultTextColor

		--align with the header
		line:AddFrameToHeaderAlignment(specIcon)
		line:AddFrameToHeaderAlignment(playerName)
		line:AddFrameToHeaderAlignment(itemLevel)
		line:AddFrameToHeaderAlignment(itemFrame)
		line:AddFrameToHeaderAlignment(alreadyHaveIlevelString)
		line:AddFrameToHeaderAlignment(arrowUp)
		line:AddFrameToHeaderAlignment(offSpecIndicator)
		line:AddFrameToHeaderAlignment(noteFrame)

		line:AlignWithHeader(header, "left")

		return line
	end

	for i = 1, amountLootLines do
		lootListScrollBox:CreateLine(createLineForLootScroll, i)
	end

	--select the first boss in the list
	bossScrollFrame:GetLines()[1]:Click()
end

if (canInstallPlugin) then
	RA:InstallPlugin(BisListRaid.displayName, "OPBisListRaid", BisListRaid, default_config)
end




--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


