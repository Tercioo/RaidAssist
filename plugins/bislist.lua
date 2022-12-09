
local RA = _G.RaidAssist
local L = LibStub ("AceLocale-3.0"):GetLocale ("RaidAssistAddon")
local _
local defaultPriority = 13
local DF = DetailsFramework

--fazer o lance de mandar os items para a raid

--battle res default config
local defaultPluginConfig = {
	enabled = true,
	menu_priority = 1,
	player_bis_list = {},
	editing_boss_id = 0,
}

local icon_texture = [[Interface\GUILDFRAME\GuildLogo-NoLogo]]
local icon_texcoord = {l=10/64, r=54/64, t=10/64, b=54/64}
local text_color_enabled = {r=1, g=1, b=1, a=1}
local text_color_disabled = {r=0.5, g=0.5, b=0.5, a=1}
local scrollbox_line_backdrop_color = {.1, .10, .10, 0.5}
local scrollbox_line_backdrop_color_hightlight = {.4, .4, .4, 0.6}
local scrollbox_line_backdrop_color_selected = {.7, .7, .7, 0.9}

local BisList = {version = "v0.1", pluginname = "BisList", pluginId = "BISL", displayName = "Bis List"}
_G["RaidAssistBisList"] = BisList

BisList.IsDisabled = false
local canInstall = true

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

BisList.menu_text = function(plugin)
	if (BisList.db.enabled) then
		return icon_texture, icon_texcoord, "Loot (My Bis List)", text_color_enabled
	else
		return icon_texture, icon_texcoord, "Loot (My Bis List)", text_color_disabled
	end
end

BisList.menu_popup_show = function(plugin, ct_frame, param1, param2)
	RA:AnchorMyPopupFrame(BisList)
end

BisList.menu_popup_hide = function(plugin, ct_frame, param1, param2)
	BisList.popup_frame:Hide()
end

BisList.menu_on_click = function(plugin)
	RA.OpenMainOptions(BisList)
end

BisList.OnInstall = function(plugin)
	--C_Timer.After (5, BisList.menu_on_click)
	BisList.db.menu_priority = defaultPriority
end

BisList.OnEnable = function(plugin)
	--enabled from the options panel.
end

BisList.OnDisable = function(plugin)
	--disabled from the options panel.
end

function BisList.OnShowOnOptionsPanel()
	local OptionsPanel = BisList.OptionsPanel
	BisList.BuildOptions(OptionsPanel)
end

local buildPlayerItemList = function()
	local equipmentList = {}
	for i = 1, 18 do
		local itemLink = GetInventoryItemLink("player", i)
		if (itemLink) then
			local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent = GetItemInfo(itemLink)
			if (itemName) then
				local itemId = itemLink:match("|Hitem%:(%d+)%:")
				print(itemName, itemId, itemLink)
				equipmentList[i] = {itemId, itemLink}
			end
		end
	end
	BisList.PlayerEquipmentList = equipmentList
end

--return the item level of the item the player currently possesses
local getCurrentOwnItem = function(itemLink)
	local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent = GetItemInfo(itemLink)

	for id = 0, 17 do
		local hasEquippedItemLink = GetInventoryItemLink("player", id)
		if (hasEquippedItemLink) then
			local thisItemName, thisItemLink, thisItemQuality, thisItemLevel = GetItemInfo(hasEquippedItemLink)
			if (thisItemName and thisItemLink and thisItemQuality and thisItemLevel) then
				if (itemName == thisItemName) then
					local itemId = itemLink:match("|Hitem%:(%d+)%:")
					itemId = tonumber(itemId) or 0
					return itemLevel, itemLink, itemId
				end
			end
		end
	end

	for bagId = 1, 6 do
		local numSlots = C_Container.GetContainerNumSlots(bagId)
		if (numSlots > 0) then
			for slotId = 1, numSlots do
				local itemLink = C_Container.GetContainerItemLink(bagId, slotId)
				if (itemLink) then
					local thisItemName, thisItemLink, thisItemQuality, thisItemLevel = GetItemInfo(itemLink)
					if (thisItemName and thisItemLink and thisItemQuality and thisItemLevel) then
						if (itemName == thisItemName) then
							local itemId = itemLink:match("|Hitem%:(%d+)%:")
							itemId = tonumber(itemId) or 0
							return itemLevel, itemLink, itemId
						end
					end
				end
			end
		end
	end
end

local getItemIDFromItemLink = function(itemLink)
	local itemId = itemLink:match("|Hitem%:(%d+)%:")
	itemId = tonumber(itemId) or 0
	return itemId
end

local getBisListForPlayer = function()
	local bisListDB = BisList.db.player_bis_list
	local playerGUID = UnitGUID("player")

	local bisList = bisListDB[playerGUID]
	if (not bisList) then
		bisList = {}
		bisListDB[playerGUID] = bisList
	end

	return bisList
end

local sendListScheduled

--send the bis list to raid leader
function BisList.SendBisList()
	--get the bis list of the player
	local bisList = getBisListForPlayer()
	local maxItemlevel, currentItemLevel = GetAverageItemLevel()

	local listToSend = {
		ilvl = currentItemLevel,
		items = {},
		specId = PlayerUtil.GetCurrentSpecID(),
	}

	for itemId, lootInfo in pairs(bisList) do
		if (lootInfo.enabled) then
			local itemTable = {
				lootInfo.encounterID,
				lootInfo.itemQuality,
				getCurrentOwnItem(lootInfo.link) or 0,
			}
			listToSend.items[itemId] = itemTable
		end
	end

	--send the comm
	if (IsInRaid()) then
		if (sendListScheduled and not sendListScheduled:IsCancelled()) then
			return
		end

		local callback = function()
			BisList:SendPluginCommMessage(COMM_RECEIVED_LIST, "RAID", nil, nil, listToSend)
			sendListScheduled = nil
		end

		sendListScheduled = DF.Schedules.NewTimer(0.1 + math.random() * 4, callback)
	end
end

RA:RegisterForEnterRaidGroup(function()
	C_Timer.After(0.5, function()
		BisList.SendBisList()
	end)
end)

function BisList.OnReceiveComm(sourceName, prefix, sourcePluginVersion, sourceUnit, data1, data2, data3)
	if (prefix == COMM_QUERY_RAIDLIST) then
		BisList.SendBisList()
	end
end

--RA:RegisterPluginComm(COMM_QUERY_USERLIST, BisList.OnReceiveComm)
RA:RegisterPluginComm(COMM_QUERY_RAIDLIST, BisList.OnReceiveComm)
--RA:RegisterPluginComm(COMM_RECEIVED_LIST, BisList.OnReceiveComm)

local GetLootTable = function(thisClassId)
	local className, classFileName, classId = UnitClass("player")
	BisList.LootFilterClassId = thisClassId or BisList.LootFilterClassId or classId

	--create the boss selector
	local arrayOfBosses, bossInfoData, lootInfoData = RA:GetExpansionBossList(BisList.LootFilterClassId)
	BisList.main_frame.BossData = arrayOfBosses --array of bosses
	BisList.main_frame.BossInfoData = bossInfoData --map[journalEncounterID] = bossInfo
	BisList.main_frame.LootInfoData = lootInfoData --map[journalEncounterID] = lootInfo

	return arrayOfBosses, bossInfoData, lootInfoData
end

function BisList.BuildOptions(frame)
	if (frame.bBuiltFrames) then
		--frame.bossScrollFrame:Refresh()
		return
	end

	frame.bBuiltFrames = true

	local mainFrame = frame
	mainFrame:SetSize(422, 385)
	BisList.main_frame = mainFrame

	--left boss selection scroll frame functions
	local refreshBossList = function(self, data, offset, totalLines)
		local lastBossSelected = BisList.db.editing_boss_id

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

	local CONST_LOOT_SELECTIONFRAME_WIDTH = 635
	local CONST_LOOT_BUTTON_WIDTH = 200
	local CONST_LOOT_BUTTON_HEIGHT = 50

	local lootSpaceWidth = CONST_LOOT_BUTTON_WIDTH + 10
	local lootSpaceHeight = CONST_LOOT_BUTTON_HEIGHT + 10
	local lootIconSize = CONST_LOOT_BUTTON_HEIGHT - 5
	local lootButtonPerRow = math.floor(CONST_LOOT_SELECTIONFRAME_WIDTH / lootSpaceWidth)

	local startOffsetX = 5
	local startOffsetY = -5

	local lootNameFontSize = 10
	local lootSlotFontSize = 10

	local className, classFileName, classId = UnitClass("player")
	local arrayOfBosses, bossInfoData, lootInfoData = GetLootTable(classId)

	local bossScrollFrame = DF:CreateScrollBox(mainFrame, "$parentBossScrollBox", refreshBossList, arrayOfBosses, scrollBossWidth, scrollBossHeight, amoutBossLines, bossLinesHeight)
	mainFrame.bossScrollFrame = bossScrollFrame
	bossScrollFrame.isMaximized = true

	local lootSelectionFrame = CreateFrame("frame", nil, mainFrame, "BackdropTemplate")
	lootSelectionFrame:SetPoint("topleft", bossScrollFrame, "topright", 26, 0)
	lootSelectionFrame:SetPoint("bottomleft", bossScrollFrame, "bottomright", 26, 0)
	lootSelectionFrame:SetWidth(CONST_LOOT_SELECTIONFRAME_WIDTH)
	DF:ApplyStandardBackdrop(lootSelectionFrame)
	lootSelectionFrame.LootButtons = {}
	lootSelectionFrame.NextLootButton = 1
	lootSelectionFrame.NextOffsetX = startOffsetX
	lootSelectionFrame.NextOffsetY = startOffsetY

	local selectLootString = lootSelectionFrame:CreateFontString(nil, "overlay", "GameFontNormal")
	selectLootString:SetText("Select The Items You Desire From Each Boss")
	selectLootString:SetPoint("bottom", lootSelectionFrame, "bottom", 0, 2)

	local r, g, b = DF:ParseColors("black")

	local gradientBelowTheLine = DF:CreateTexture(lootSelectionFrame, {gradient = "vertical", fromColor = {r, g, b, 0.3}, toColor = "transparent"}, 1, 100, "artwork", {0, 1, 0, 1}, "gradientBelowTheLine")
	gradientBelowTheLine:SetPoint("bottoms", lootSelectionFrame, 1, 1)

	function lootSelectionFrame:ResetLootButtons()
		for buttonIndex, lootButton in ipairs(lootSelectionFrame.LootButtons) do
			lootButton:Hide()
		end
		lootSelectionFrame.NextLootButton = 1
		lootSelectionFrame.NextOffsetX = startOffsetX
		lootSelectionFrame.NextOffsetY = startOffsetY
	end

	local lootButtonOnEnter = function(lootButton)
		local lootInfo = lootButton.LootInfo
		GameTooltip:SetOwner(lootButton, "ANCHOR_TOPRIGHT")
		GameTooltip:SetHyperlink(lootInfo.link)
		GameTooltip:Show()
	end

	local lootButtonOnLeave = function(lootButton)
		GameTooltip:Hide()
	end

	local lootButonRefreshBorderColor = function(lootButton)
		local lootInfo = lootButton.LootInfo
		local bisList = getBisListForPlayer()

		if (bisList[lootInfo.itemID] and bisList[lootInfo.itemID].enabled) then
			local r, g, b, a = lootButton:GetBackdropColor()
			local backdropTable = lootButton:GetBackdrop()
			backdropTable.edgeSize = 3
			lootButton:SetBackdrop(backdropTable)
			lootButton:SetBackdropBorderColor(1, 1, 0, 1)
			lootButton:SetBackdropColor(r, g, b, a)
		else
			local r, g, b, a = lootButton:GetBackdropColor()
			local backdropTable = lootButton:GetBackdrop()
			backdropTable.edgeSize = 1
			lootButton:SetBackdrop(backdropTable)
			lootButton:SetBackdropBorderColor(0, 0, 0, 1)
			lootButton:SetBackdropColor(r, g, b, a)
		end
	end

	local lootButtonOnClick = function(lootButton)
		local lootInfo = lootButton.LootInfo
		local bisList = getBisListForPlayer()
		local thisLootInfo = bisList[lootInfo.itemID]

		if (not thisLootInfo) then
			thisLootInfo = {}
			thisLootInfo.enabled = false

			--store the entire lootInfo
			DF.table.deploy(thisLootInfo, lootInfo)
			bisList[lootInfo.itemID] = thisLootInfo
		end

		thisLootInfo.enabled = not thisLootInfo.enabled
		lootButonRefreshBorderColor(lootButton)

		if (IsInRaid()) then
			BisList.SendBisList()
		end
	end

	local createLootButton = function(buttonIndex)
		local lootButton = CreateFrame("button", nil, lootSelectionFrame, "BackdropTemplate")
		DF:ApplyStandardBackdrop(lootButton)

		lootButton:SetScript("OnEnter", lootButtonOnEnter)
		lootButton:SetScript("OnLeave", lootButtonOnLeave)
		lootButton:SetScript("OnClick", lootButtonOnClick)

		lootButton.Icon = lootButton:CreateTexture(nil, "artwork")
		lootButton.Icon:SetSize(lootIconSize, lootIconSize)
		lootButton.Icon:SetPoint("left", lootButton, "left", 5, 0)

		lootButton.IconBorder = lootButton:CreateTexture(nil, "overlay")
		lootButton.IconBorder:SetAllPoints(lootButton.Icon)
		lootButton.IconBorder:SetTexture(651080)

		lootButton.HasItemIndicator = DetailsFramework:CreateTexture(lootButton, {gradient = "horizontal", fromColor = {0, 0, 0, 0}, toColor = {.2, .9, .2, 0.3}}, 120, 1, "border", {0, 1, 0, 1})
		lootButton.HasItemIndicator:SetPoint("rights", lootButton, -1)

		lootButton.ItemNameString = lootButton:CreateFontString(nil, "artwork", "GameFontNormal")
		lootButton.ItemNameString:SetPoint("topleft", lootButton.Icon, "topright", 10, -5)
		DF:SetFontSize(lootButton.ItemNameString, lootNameFontSize)

		lootButton.ItemSlotString = lootButton:CreateFontString(nil, "artwork", "GameFontNormal")
		lootButton.ItemSlotString:SetPoint("bottomleft", lootButton.Icon, "bottomright", 10, 5)
		DF:SetFontSize(lootButton.ItemSlotString, lootSlotFontSize)

		lootButton.ItemLevelString = lootButton:CreateFontString(nil, "artwork", "GameFontNormal")
		lootButton.ItemLevelString:SetPoint("bottomright", lootButton, "bottomright", -4, 5)
		DF:SetFontSize(lootButton.ItemLevelString, lootSlotFontSize)

		lootButton.HightlightTexture = lootButton:CreateTexture(nil, "highlight")
		lootButton.HightlightTexture:SetAllPoints()
		lootButton.HightlightTexture:SetColorTexture(1, 1, 1, .1)

		lootButton:SetSize(CONST_LOOT_BUTTON_WIDTH, CONST_LOOT_BUTTON_HEIGHT)
		lootButton:SetPoint("topleft", lootSelectionFrame, "topleft", lootSelectionFrame.NextOffsetX, lootSelectionFrame.NextOffsetY)
		lootSelectionFrame.NextOffsetX = lootSelectionFrame.NextOffsetX + lootSpaceWidth

		if (buttonIndex % lootButtonPerRow == 0) then
			lootSelectionFrame.NextOffsetX = startOffsetX
			lootSelectionFrame.NextOffsetY = lootSelectionFrame.NextOffsetY - lootSpaceHeight
		end

		lootSelectionFrame.LootButtons[buttonIndex] = lootButton
	end

	for i = 1, 27 do
		createLootButton(i)
	end

	function lootSelectionFrame:GetLootButton()
		local buttonIndex = lootSelectionFrame.NextLootButton
		local lootButton = lootSelectionFrame.LootButtons[buttonIndex]
		lootSelectionFrame.NextLootButton = buttonIndex + 1
		lootButton:Show()
		return lootButton
	end

	--bossIndex: are the index of the table results from 
	lootSelectionFrame.SetLootListForBossIndex = function(bossId)

	end

	function BisList.GetBossScrollFrame()
		return bossScrollFrame
	end

--[[
	["armorType"] = "Mail",
	["handError"] = false,
	["weaponTypeError"] = false,
	["slot"] = "Legs",
	["enabled"] = true,
	["itemID"] = 195522,
	["filterType"] = 8,
	["displayAsExtremelyRare"] = false,
	["displayAsVeryRare"] = false,
	["name"] = "Tassets of the Tarasek Legion",
	["link"] = "[Tassets of the Tarasek Legion]",
	["encounterID"] = 2493,
	["displayAsPerPlayerLoot"] = false,
	["icon"] = 4567908,
	["itemQuality"] = "ffa335ee",
	
	["armorType"] = "Tecido",
	["slot"] = "Pés",
	["weaponTypeError"] = 1,
	["handError"] = false,
	["filterType"] = 9,
	["encounterID"] = 2499,
	["displayAsExtremelyRare"] = false,
	["displayAsVeryRare"] = false,
	["itemID"] = 195532,
	["link"] = "[Sandálias da Soberana Selvagem]",
	["name"] = "Sandálias da Soberana Selvagem",
	["displayAsPerPlayerLoot"] = false,
	["icon"] = 4392920,
	["itemQuality"] = "ffa335ee",

	["armorType"] = "",
	["slot"] = "",
	["weaponTypeError"] = false,
	["handError"] = false,
	["filterType"] = 14,
	["encounterID"] = 2499,
	["displayAsExtremelyRare"] = false,
	["displayAsVeryRare"] = false,
	["itemID"] = 196590,
	["link"] = "[Dreadful Topaz Forgestone]",
	["name"] = "Dreadful Topaz Forgestone",
	["displayAsPerPlayerLoot"] = false,
	["icon"] = 4555633,
	["itemQuality"] = "ffa335ee",
]]

	local selectBoss = function(bossId, bossButton)
		--reset loot buttons
		lootSelectionFrame:ResetLootButtons()

		local bossLootTable = mainFrame.LootInfoData[bossId] --array

		for i = 1, #bossLootTable do --refresh loot
			local thisLoot = bossLootTable[i]
			if (thisLoot.name:find("Dreadful")) then
				dumpt(thisLoot)
			end

			if (thisLoot.slot == "") then
				thisLoot.filterType = 50
			end

			--thisLoot.weaponTypeError = thisLoot.weaponTypeError and 0 or 1
			thisLoot.equipSort = IsEquippableItem(thisLoot.link) and thisLoot.filterType or thisLoot.filterType + 25
			--thisLoot.filterType = thisLoot.filterType or 20
		end

		--table.sort(bossLootTable, function(t1, t2) return t1.filterType < t2.filterType end) --heads first, trinkets last
		table.sort(bossLootTable, function(t1, t2) return t1.equipSort < t2.equipSort end)

		--update the loot for this boss
		for i = 1, #bossLootTable do --refresh loot
			local thisLoot = bossLootTable[i]

			--need to check if the player can wear the gear
			local lootButton = lootSelectionFrame:GetLootButton()

			lootButton.Icon:SetTexture(thisLoot.icon)
			lootButton.ItemNameString:SetText(thisLoot.name)
			DF:TruncateTextSafe(lootButton.ItemNameString, CONST_LOOT_BUTTON_WIDTH - CONST_LOOT_BUTTON_HEIGHT - 10)

			lootButton.ItemSlotString:SetText(thisLoot.slot)
			lootButton.LootInfo = thisLoot
			local r, g, b, a = DF:ParseColors("#" .. thisLoot.itemQuality)
			DF:SetFontColor(lootButton.ItemNameString, r, g, b, a)
			lootButton.IconBorder:SetVertexColor(r, g, b, a)

			local itemLevel, itemLink, itemId = getCurrentOwnItem(thisLoot.link)
			lootButton.ItemLevelString:SetText(itemLevel or "")
			if (itemLevel) then
				lootButton.ItemLevelString:SetText(itemLevel)
				lootButton.HasItemIndicator:Show()
			else
				lootButton.ItemLevelString:SetText("")
				lootButton.HasItemIndicator:Hide()
			end

			--dumpt(thisLoot)

			if (thisLoot.displayAsVeryRare) then

			elseif (thisLoot.displayAsExtremelyRare) then

			end

			lootButonRefreshBorderColor(lootButton)
		end

		--update the boss button selected indicator
		BisList.db.editing_boss_id = bossId
		bossButton.selectedInidicator:Show()
		for lineIndex, line in pairs(bossScrollFrame:GetLines()) do
			if (line.bossId ~= bossId) then
				line.selectedInidicator:Hide()
			end
		end
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

	--select the first boss in the list
	bossScrollFrame:GetLines()[1]:Click()
end

if (canInstall) then
	RA:InstallPlugin(BisList.displayName, "RABisList", BisList, defaultPluginConfig)
end

