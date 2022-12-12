
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

--return the item level of the item the player currently possesses
local getCurrentOwnItem = function(itemLink)
	local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent = GetItemInfo(itemLink)
	local effectiveILvl, isPreview, baseILvl = GetDetailedItemLevelInfo(itemLink)
	itemLevel = effectiveILvl or itemLevel

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

local parseUpgradeString = function(textString)

end

local getUpgradePercentText = function(lootButton)
	local lootInfo = lootButton.LootInfo
	local bisList = getBisListForPlayer()

	if (bisList) then
		if (bisList[lootInfo.itemID]) then
			return bisList[lootInfo.itemID].upgradePercent or 0
		end
	end

	return ""
end

local getNoteText = function(lootButton)
	local lootInfo = lootButton.LootInfo
	local bisList = getBisListForPlayer()

	if (bisList) then
		if (bisList[lootInfo.itemID]) then
			return bisList[lootInfo.itemID].noteText or ""
		end
	end

	return ""
end

local sendListScheduled

--send the bis list to raid leader
function BisList.SendBisList(isDebug)
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
				lootInfo.upgradePercent or 0,
				lootInfo.offspec and 1 or 0,
				lootInfo.noteText,
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

	elseif (isDebug) then
		if (IsInGroup()) then
			BisList:SendPluginCommMessage(COMM_RECEIVED_LIST, "PARTY", nil, nil, listToSend)
		end
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

local getItemLootInfo = function(lootInfo)
	local bisList = getBisListForPlayer()
	local itemLootInfo = bisList[lootInfo.itemID]

	if (not itemLootInfo) then
		itemLootInfo = {}
		itemLootInfo.enabled = false
		--store the entire lootInfo
		DF.table.deploy(itemLootInfo, lootInfo)
		bisList[lootInfo.itemID] = itemLootInfo
	end

	return itemLootInfo
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

	local lootNameFontSize = 11
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

	--ver o que tem equipado (gear inteira) - LibOpenRaid()
	--adicionar: note para o item

	local lootButtonOnEnter = function(lootButton)
		if (lootButton.showTooltipCooldown > GetTime()) then
			C_Timer.After(lootButton.showTooltipCooldown - GetTime() + 0.01, function()
				if (GetMouseFocus() == lootButton) then
					lootButton:GetScript("OnEnter")(lootButton)
				end
			end)
			return
		end

		local lootInfo = lootButton.LootInfo
		GameTooltip:SetOwner(lootButton, "ANCHOR_TOPRIGHT")
		GameTooltip:SetHyperlink(lootInfo.link)
		GameTooltip:Show()
	end

	local lootButtonOnLeave = function(lootButton)
		GameTooltip:Hide()
	end

	local lootButonRefresh = function(lootButton)
		local lootInfo = lootButton.LootInfo
		local bisList = getBisListForPlayer()

		if (bisList[lootInfo.itemID]) then
			--border color
			if (bisList[lootInfo.itemID].enabled) then
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

			--is offspec toggle
			lootButton.IsOffSpecCheckBox:SetValue(bisList[lootInfo.itemID].offspec)

			--percent text
			if (bisList[lootInfo.itemID].upgradePercent and bisList[lootInfo.itemID].upgradePercent > 0) then
				lootButton.upgradePercentString:SetText(bisList[lootInfo.itemID].upgradePercent .. "%")
				DF:SetFontColor(lootButton.upgradePercentString, "limegreen")
			else
				lootButton.upgradePercentString:SetText("%")
				DF:SetFontColor(lootButton.upgradePercentString, "green")
			end
		else
			lootButton.IsOffSpecCheckBox:SetValue(false)
			lootButton.upgradePercentString:SetText("%")
			DF:SetFontColor(lootButton.upgradePercentString, "green")
		end
	end

	local lootButtonOnClick = function(lootButton)
		local lootInfo = lootButton.LootInfo
		local itemLootInfo = getItemLootInfo(lootInfo)

		itemLootInfo.enabled = not itemLootInfo.enabled
		lootButonRefresh(lootButton)

		if (IsInRaid()) then
			BisList.SendBisList()
		end
	end

	local lootButttonOnToggleIsOffSpec = function(self, FixedValue, value)
		local lootButton = self:GetParent()
		local lootInfo = lootButton.LootInfo
		local itemLootInfo = getItemLootInfo(lootInfo)
		itemLootInfo.offspec = value
		lootButonRefresh(lootButton)

		if (IsInRaid()) then
			BisList.SendBisList()
		end
	end

	local lootButtonOnSelectUpgradePercent = function(object, fixedValue, lootButton, upgradePercent)
		upgradePercent = tonumber(upgradePercent)

		local lootInfo = lootButton.LootInfo
		local itemLootInfo = getItemLootInfo(lootInfo)
		itemLootInfo.upgradePercent = upgradePercent
		lootButonRefresh(lootButton)

		--BisList.SendBisList(true) print("sending (debug)...")

		if (IsInRaid()) then
			BisList.SendBisList()
		end

		GameCooltip:Hide()
	end

	local upgradeFrameOnClick = function(upgradeFrame)
		local lootButton = upgradeFrame:GetParent()
		lootButton.PercentTextEntry:Show()
		lootButton.PercentTextEntry:SetText(getUpgradePercentText(lootButton))
		lootButton.PercentTextEntry:SetFocus(true)
		lootButton.PercentTextEntry:HighlightText(0)
	end

	local lootButtonOnSetNoteText = function(lootButton, text)
		local lootInfo = lootButton.LootInfo
		local itemLootInfo = getItemLootInfo(lootInfo)
		itemLootInfo.noteText = text
		lootButonRefresh(lootButton)

		--BisList.SendBisList(true) print("sending (debug)...")

		if (IsInRaid()) then
			BisList.SendBisList()
		end
	end

	local noteFrameOnClick = function(noteFrame)
		local lootButton = noteFrame:GetParent()
		lootButton.NoteTextEntry:Show()
		lootButton.NoteTextEntry:SetText(getNoteText(lootButton))
		lootButton.NoteTextEntry:SetFocus(true)
		lootButton.NoteTextEntry:HighlightText(0)
	end

	local createLootButton = function(buttonIndex) --~create
		local lootButton = CreateFrame("button", nil, lootSelectionFrame, "BackdropTemplate")
		DF:ApplyStandardBackdrop(lootButton)
		lootButton.showTooltipCooldown = 0

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
		lootButton.ItemNameString:SetPoint("topleft", lootButton.Icon, "topright", 5, -1)
		DF:SetFontSize(lootButton.ItemNameString, lootNameFontSize)

		lootButton.ItemSlotString = lootButton:CreateFontString(nil, "artwork", "GameFontNormal")
		lootButton.ItemSlotString:SetPoint("topleft", lootButton.ItemNameString, "bottomleft", 0, -2)
		DF:SetFontSize(lootButton.ItemSlotString, lootSlotFontSize)

		lootButton.ItemLevelString = lootButton:CreateFontString(nil, "artwork", "GameFontNormal")
		lootButton.ItemLevelString:SetPoint("bottomright", lootButton, "bottomright", -4, 5)
		DF:SetFontSize(lootButton.ItemLevelString, lootSlotFontSize)

		local isOffSpecCheckBox, offSpecString = DF:CreateSwitch(lootButton, lootButttonOnToggleIsOffSpec, false, 12, 12, nil, nil, nil, nil, nil, nil, nil, "Off Spec", DF:GetTemplate("switch", "OPTIONS_CHECKBOX_TEMPLATE"), DF:GetTemplate("font", "OPTIONS_FONT_TEMPLATE"))
		isOffSpecCheckBox:SetAsCheckBox()
		isOffSpecCheckBox:ClearAllPoints()
		offSpecString:ClearAllPoints()
		isOffSpecCheckBox:SetSize(12, 12)
		isOffSpecCheckBox:SetPoint("bottomleft", lootButton.Icon, "bottomright", 5, 2)
		offSpecString:SetPoint("left", isOffSpecCheckBox, "right", 2, 0)
		lootButton.IsOffSpecCheckBox = isOffSpecCheckBox

		--upgrade percent
			local upgradeFrame = CreateFrame("button", nil, lootButton)
			upgradeFrame:SetPoint("left", offSpecString.widget, "right", 10, 0)
			upgradeFrame:SetSize(50, 16)
			upgradeFrame:SetScript("OnClick", upgradeFrameOnClick)

			local buildPercentMenu = function()
				GameCooltip:Preset(2)
				GameCooltip:AddLine("click to set the upgrade %", "", 1, {.4, 1, .4, 0.8})
			end

			upgradeFrame.CoolTip = {
				Type = "tooltip",
				BuildFunc = buildPercentMenu,
				OnEnterFunc = function()end,
				OnLeaveFunc = function() lootButton.showTooltipCooldown = GetTime() + 0.097 end,
				FixedValue = "none",
				ShowSpeed = 0.05,
				HideSpeed = 0.0,
				Options = function()
					GameCooltip:SetOption("FixedWidth", 175)
				end,
			}

			GameCooltip:CoolTipInject(upgradeFrame)

			local arrowUp = upgradeFrame:CreateTexture(nil, "artwork")
			arrowUp:SetTexture([[Interface\BUTTONS\UI-MicroStream-Green]])
			arrowUp:SetTexCoord(0, 1, 1, 0)
			arrowUp:SetPoint("left", offSpecString.widget, "right", 10, 0)
			arrowUp:SetSize(16, 16)

			local percentString = upgradeFrame:CreateFontString(nil, "artwork", "GameFontNormal")
			percentString:SetText("%")
			percentString:SetPoint("left", arrowUp, "right", -2, 0)
			DF:SetFontSize(percentString, 14)
			DF:SetFontColor(percentString, "green")

			local flashAnimationTexture = upgradeFrame:CreateTexture(nil, "border")
			flashAnimationTexture:SetColorTexture(1, 1, 1, 1)
			flashAnimationTexture:SetAllPoints()
			flashAnimationTexture:SetAlpha(0)

			flashAnimationTexture.FlashAnimation = DF:CreateAnimationHub(flashAnimationTexture)
			DF:CreateAnimation(flashAnimationTexture.FlashAnimation, "alpha", 1, 0.1, 0, 1)
			DF:CreateAnimation(flashAnimationTexture.FlashAnimation, "alpha", 2, 0.4, 1, 0)

			lootButton.upgradePercentString = percentString

			lootButton.PercentTextEntry = DF:CreateTextEntry(upgradeFrame, function(_, _, text) flashAnimationTexture.FlashAnimation:Play() lootButtonOnSelectUpgradePercent(GameCooltip, "none", lootButton, tonumber(text)) end, upgradeFrame:GetWidth(), upgradeFrame:GetHeight() + 5)
			lootButton.PercentTextEntry:SetAutoFocus(false)
			lootButton.PercentTextEntry:SetAllPoints()
			lootButton.PercentTextEntry:Hide()
			DF:SetFontSize(lootButton.PercentTextEntry, 14)
			DF:SetFontColor(lootButton.PercentTextEntry, "limegreen")
			do
				local left, right, top, bottom = lootButton.PercentTextEntry:GetTextInsets()
				lootButton.PercentTextEntry:SetTextInsets(left, right, top, bottom + 3)
			end

			lootButton.PercentTextEntry:SetHook("OnEscapePressed", function()
				lootButton.PercentTextEntry:Hide()
			end)

			lootButton.PercentTextEntry:SetHook("OnEditFocusLost", function()
				lootButton.PercentTextEntry:Hide()
			end)

		--set note button
			local noteFrame = CreateFrame("button", nil, lootButton)
			noteFrame:SetSize(20, 20)
			noteFrame:SetScript("OnClick", noteFrameOnClick)
			noteFrame:SetPoint("bottomright", lootButton, "bottomright", -2, 2)

			local noteIcon = noteFrame:CreateTexture(nil, "artwork")
			noteIcon:SetPoint("center", 0, 0)
			noteIcon:SetTexture([[Interface\BUTTONS\UI-GuildButton-OfficerNote-Up]])

			lootButton.NoteTextEntry = DF:CreateTextEntry(upgradeFrame, function(_, _, text) end, upgradeFrame:GetWidth(), upgradeFrame:GetHeight() + 5)
			lootButton.NoteTextEntry:SetAutoFocus(false)
			lootButton.NoteTextEntry:SetPoint("topleft", lootButton, "topleft", 1, -1)
			lootButton.NoteTextEntry:SetPoint("bottomright", lootButton, "bottomright", -1, 1)
			lootButton.NoteTextEntry:SetJustifyH("left")
			lootButton.NoteTextEntry:Hide()
			DF:SetFontSize(lootButton.NoteTextEntry, 14)
			DF:SetFontColor(lootButton.NoteTextEntry, "limegreen")
			do
				local left, right, top, bottom = lootButton.NoteTextEntry:GetTextInsets()
				lootButton.NoteTextEntry:SetTextInsets(left, right, top, bottom)
			end

			lootButton.NoteTextEntry:SetHook("OnEscapePressed", function()
				lootButton.NoteTextEntry:Hide()
			end)

			lootButton.NoteTextEntry:SetHook("OnEditFocusLost", function()
				lootButton.NoteTextEntry:Hide()
			end)

			lootButton.NoteTextEntry:SetHook("OnEnterPressed", function(_, _, text)
				lootButtonOnSetNoteText(lootButton, text)
				lootButton.NoteTextEntry:Hide()
			end)

		lootButton.HightlightTexture = lootButton:CreateTexture(nil, "highlight")
		lootButton.HightlightTexture:SetPoint("topleft", lootButton, "topleft", 1, -1)
		lootButton.HightlightTexture:SetPoint("bottomright", lootButton, "bottomright", -1, 1)
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

	local parseImportedUpgradeValues = function(text)
		local lines = DF:SplitTextInLines(text)

		for i = 1, #lines do
			--
		end
	end

	local importTextField = DF:NewSpecialLuaEditorEntry(lootSelectionFrame, 1, 1, nil, "BisListImportTextEntry", true)
	importTextField:SetPoint("topleft", lootSelectionFrame, "topleft", 1, -1)
	importTextField:SetPoint("bottomright", lootSelectionFrame, "bottomright", -1, 25)
	importTextField:SetFrameLevel(lootSelectionFrame:GetFrameLevel() + 10)
	_G["BisListImportTextEntryScrollBar"]:Hide()
	DF:ApplyStandardBackdrop(importTextField)
	importTextField:Hide()

	importTextField.backgroundTexture = importTextField:CreateTexture(nil, "background")
	importTextField.backgroundTexture:SetColorTexture(DF:GetDefaultBackdropColor())
	importTextField.backgroundTexture:SetAllPoints()

	local importButtonCallback = function()
		if (not importTextField:IsShown()) then
			importTextField:Show()
			importTextField:SetText("")
			importTextField:SetFocus(true)
			lootSelectionFrame.importPercentButton:SetText("Import!")
		else
			importTextField:SetFocus(false)
			lootSelectionFrame.importPercentButton:SetText("Import Upgrade Percent")
			importTextField:Hide()
			local importText = importTextField:GetText()
			parseImportedUpgradeValues(importText)
		end
	end

	local importPercentButton = DF:CreateButton(lootSelectionFrame, importButtonCallback, 120, 20, "Import Upgrade Percent")
	importPercentButton:SetTemplate(DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))
	importPercentButton:SetIcon([[Interface\BUTTONS\UI-MicroStream-Green]])
	importPercentButton:SetPoint("bottomright", lootSelectionFrame, "bottomright", -2, 2)
	lootSelectionFrame.importPercentButton = importPercentButton
	importPercentButton:Disable()

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

	local selectBoss = function(bossId, bossButton) --~selectedboss ~clickboss
		--reset loot buttons
		lootSelectionFrame:ResetLootButtons()

		--get all loot this boss has for the player class
		local bossLootTable = mainFrame.LootInfoData[bossId] --array

		--store all items available for the player from this boss
		local availableLootItemsFromBoss = {}

		for i = 1, #bossLootTable do --refresh loot
			local thisLoot = bossLootTable[i]

			if (thisLoot.slot == "") then
				thisLoot.filterType = 50
			end

			availableLootItemsFromBoss[thisLoot.itemID] = true

			--thisLoot.weaponTypeError = thisLoot.weaponTypeError and 0 or 1
			thisLoot.equipSort = IsEquippableItem(thisLoot.link) and thisLoot.filterType or thisLoot.filterType + 25
		end

		--if an item gets removed from the player class by a game hotfix, need to remove that item from the player bislist
		local bisList = getBisListForPlayer()
		for itemId, lootInfo in pairs(bisList) do
			if (lootInfo.encounterID == bossId) then
				if (not availableLootItemsFromBoss[itemId]) then
					local itemName = GetItemInfo(itemId)
					print(itemName, "removed from your bis list: the item isn't for your class anymore.")
					bisList[itemId] = nil
				end
			end
		end

		table.sort(bossLootTable, function(t1, t2) return t1.equipSort < t2.equipSort end)

		--update the loot for this boss
		for i = 1, #bossLootTable do --~refresh ~update loot
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

			if (thisLoot.displayAsVeryRare) then

			elseif (thisLoot.displayAsExtremelyRare) then

			end

			--refresh the selected state, note state, offspec state
			lootButonRefresh(lootButton)
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
		selectedInidicator:SetPoint("topleft", line, "topleft", 1, -1)
		selectedInidicator:SetPoint("bottomright", line, "bottomright", -1, 1)
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

