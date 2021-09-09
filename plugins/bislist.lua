
local RA = _G.RaidAssist
local L = LibStub ("AceLocale-3.0"):GetLocale ("RaidAssistAddon")
local _
local default_priority = 13

--battle res default config
local default_config = {
	enabled = true,
	menu_priority = 1,
	characters = {},
}

local icon_texture = [[Interface\GUILDFRAME\GuildLogo-NoLogo]]
local icon_texcoord = {l=10/64, r=54/64, t=10/64, b=54/64}
local text_color_enabled = {r=1, g=1, b=1, a=1}
local text_color_disabled = {r=0.5, g=0.5, b=0.5, a=1}

local BisList = {version = "v0.1", pluginname = "BisList", pluginId = "BISL", displayName = "Bis List"}
_G ["RaidAssistBisList"] = BisList

BisList.IsDisabled = true
--BisList.IsDisabled = false

local can_install = false
local can_install = true

BisList.menu_text = function (plugin)
	if (BisList.db.enabled) then
		return icon_texture, icon_texcoord, "Loot (My Bis List)", text_color_enabled
	else
		return icon_texture, icon_texcoord, "Loot (My Bis List)", text_color_disabled
	end
end

BisList.menu_popup_show = function (plugin, ct_frame, param1, param2)
	RA:AnchorMyPopupFrame (BisList)
end

BisList.menu_popup_hide = function (plugin, ct_frame, param1, param2)
	BisList.popup_frame:Hide()
end

BisList.menu_on_click = function (plugin)
	RA.OpenMainOptions (BisList)
end

BisList.OnInstall = function (plugin)
	--C_Timer.After (5, BisList.menu_on_click)
	BisList.db.menu_priority = default_priority
end

BisList.OnEnable = function (plugin)
	-- enabled from the options panel.
end

BisList.OnDisable = function (plugin)
	-- disabled from the options panel.
end

BisList.OnProfileChanged = function (plugin)
	if (plugin.db.enabled) then
		BisList.OnEnable (plugin)
	else
		BisList.OnDisable (plugin)
	end
	
	if (plugin.options_built) then
		plugin.main_frame:RefreshOptions()
	end
end

function BisList:GetCharacterItemList()
	local guid = UnitGUID ("player")
	local db = BisList.db.characters [guid]
	
	if (not db) then
		BisList.db.characters [guid] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
		db = BisList.db.characters [guid]
	end
	
	return db
end

local get_current_equiped_itemid = function (equip_slot)
	local current_equiped = GetInventoryItemLink ("player", equip_slot)
	if (current_equiped) then
		local _, item_id, _, _, _, _, _, _, _, _, _, _, instanceDifficultyID = strsplit (":", current_equiped)
		item_id, instanceDifficultyID = tonumber (item_id), tonumber (instanceDifficultyID)
		return item_id or 0, instanceDifficultyID or 0
	end
	return 0, 0
end

BisList.LostList = {
	[INVSLOT_HEAD] = 1,
	[INVSLOT_NECK ] = 2,
	[INVSLOT_SHOULDER] = 3,
	[INVSLOT_CHEST] = 4,
	[INVSLOT_WAIST] = 5,
	[INVSLOT_LEGS] = 6,
	[INVSLOT_FEET] = 7,
	[INVSLOT_WRIST] = 8,
	[INVSLOT_HAND] = 9,
	[INVSLOT_FINGER1] = 10,
	[INVSLOT_FINGER2] = 11,
	[INVSLOT_TRINKET1] = 12,
	[INVSLOT_TRINKET2] = 13,
	[INVSLOT_BACK] = 14,
	[INVSLOT_MAINHAND] = 15,
	[INVSLOT_OFFHAND] = 16,
}

function BisList:GetMyItems()
	local IHave = {}
	local list = BisList:GetCharacterItemList()
	
	--head 1
	local item_id, diff = get_current_equiped_itemid (INVSLOT_HEAD)
	IHave [BisList.LostList [INVSLOT_HEAD]] = "" .. (list [BisList.LostList [INVSLOT_HEAD]] == item_id and "1" or "0") .. ":" .. diff
	--neck 2
	local item_id, diff = get_current_equiped_itemid (INVSLOT_NECK)
	IHave [BisList.LostList [INVSLOT_NECK]] = "" .. (list [BisList.LostList [INVSLOT_NECK]] == item_id and "1" or "0") .. ":" .. diff
	--shoulder 3
	local item_id, diff = get_current_equiped_itemid (INVSLOT_SHOULDER)
	IHave [BisList.LostList [INVSLOT_SHOULDER]] = "" .. (list [BisList.LostList [INVSLOT_SHOULDER]] == item_id and "1" or "0") .. ":" .. diff
	--chest 4
	local item_id, diff = get_current_equiped_itemid (INVSLOT_CHEST)
	IHave [BisList.LostList [INVSLOT_CHEST]] = "" .. (list [BisList.LostList [INVSLOT_CHEST]] == item_id and "1" or "0") .. ":" .. diff
	--waist 5
	local item_id, diff = get_current_equiped_itemid (INVSLOT_WAIST)
	IHave [BisList.LostList [INVSLOT_WAIST]] = "" .. (list [BisList.LostList [INVSLOT_WAIST]] == item_id and "1" or "0") .. ":" .. diff
	--legs 6
	local item_id, diff = get_current_equiped_itemid (INVSLOT_LEGS)
	IHave [BisList.LostList [INVSLOT_LEGS]] = "" .. (list [BisList.LostList [INVSLOT_LEGS]] == item_id and "1" or "0") .. ":" .. diff
	--feet 7
	local item_id, diff = get_current_equiped_itemid (INVSLOT_FEET)
	IHave [BisList.LostList [INVSLOT_FEET]] = "" .. (list [BisList.LostList [INVSLOT_FEET]] == item_id and "1" or "0") .. ":" .. diff
	--wrist 8
	local item_id, diff = get_current_equiped_itemid (INVSLOT_WRIST)
	IHave [BisList.LostList [INVSLOT_WRIST]] = "" .. (list [BisList.LostList [INVSLOT_WRIST]] == item_id and "1" or "0") .. ":" .. diff
	
	--hands 9
	local item_id, diff = get_current_equiped_itemid (INVSLOT_HAND)
	IHave [BisList.LostList [INVSLOT_HAND]] = "" .. (list [BisList.LostList [INVSLOT_HAND]] == item_id and "1" or "0") .. ":" .. diff
	
	--finger1 10
	local item_id, diff = get_current_equiped_itemid (INVSLOT_FINGER1)
	IHave [BisList.LostList [INVSLOT_FINGER1]] = "" .. (list [BisList.LostList [INVSLOT_FINGER1]] == item_id and "1" or "0") .. ":" .. diff
	--finger2 11
	local item_id, diff = get_current_equiped_itemid (INVSLOT_FINGER2)
	IHave [BisList.LostList [INVSLOT_FINGER2]] = "" .. (list [BisList.LostList [INVSLOT_FINGER2]] == item_id and "1" or "0") .. ":" .. diff
	--trinket1 12
	local item_id, diff = get_current_equiped_itemid (INVSLOT_TRINKET1)
	IHave [BisList.LostList [INVSLOT_TRINKET1]] = "" .. (list [BisList.LostList [INVSLOT_TRINKET1]] == item_id and "1" or "0") .. ":" .. diff
	--trinket2 13
	local item_id, diff = get_current_equiped_itemid (INVSLOT_TRINKET2)
	IHave [BisList.LostList [INVSLOT_TRINKET2]] = "" .. (list [BisList.LostList [INVSLOT_TRINKET2]] == item_id and "1" or "0") .. ":" .. diff
	--cloak 14
	local item_id, diff = get_current_equiped_itemid (INVSLOT_BACK)
	IHave [BisList.LostList [INVSLOT_BACK]] = "" .. (list [BisList.LostList [INVSLOT_BACK]] == item_id and "1" or "0") .. ":" .. diff
	--weapon1
	local item_id, diff = get_current_equiped_itemid (INVSLOT_MAINHAND)
	IHave [BisList.LostList [INVSLOT_MAINHAND]] = "" .. (list [BisList.LostList [INVSLOT_MAINHAND]] == item_id and "1" or "0") .. ":" .. diff
	--weapon2
	local item_id, diff = get_current_equiped_itemid (INVSLOT_OFFHAND)
	IHave [BisList.LostList [INVSLOT_OFFHAND]] = "" .. (list [BisList.LostList [INVSLOT_OFFHAND]] == item_id and "1" or "0") .. ":" .. diff
	
	return IHave
end

local GetPlayerArmorType = function()	
	local _, cloth, lether, mail, plate = GetAuctionItemSubClasses (2)
	local armor = {[cloth] = true, [lether] = true, [mail] = true, [plate] = true}
	--print (cloth, lether, mail, plate)
	for i = 1, 3 do
		local link = GetInventoryItemLink ("player", i)
		if (link) then
			GameTooltip:SetOwner (UIParent)
			GameTooltip:SetHyperlink (link)
			for o = 1, 10 do
				local text = _G ["GameTooltipTextRight" .. o] and _G ["GameTooltipTextRight" .. o]:GetText()
				GameTooltip:Hide()
				if (text and armor [text]) then
					return text, armor
				end
			end
		end
	end
	return false, armor
end

function BisList.OnShowOnOptionsPanel()
	local OptionsPanel = BisList.OptionsPanel
	BisList.BuildOptions (OptionsPanel)
end

function BisList.BuildOptions (frame)
	
	if (frame.FirstRun) then
		return
	end
	frame.FirstRun = true
	
	--window object
	local main_frame = frame
	BisList.main_frame = frame
	main_frame:SetSize (422, 385)
	
	--get this character bislist or create one
	local list = BisList:GetCharacterItemList()
	local no_border = {5/64, 59/64, 5/64, 59/64}
	
	--build the panel
	local slot_list = {
		L["S_EQUIPSLOT_1"],--1
		L["S_EQUIPSLOT_2"],--2
		L["S_EQUIPSLOT_3"],--3
		L["S_EQUIPSLOT_5"],--4
		L["S_EQUIPSLOT_6"],--5
		L["S_EQUIPSLOT_7"],--6
		L["S_EQUIPSLOT_8"],--7
		L["S_EQUIPSLOT_9"],--8
		L["S_EQUIPSLOT_10"],--9
		L["S_EQUIPSLOT_11"],--10
		L["S_EQUIPSLOT_11"],--11
		L["S_EQUIPSLOT_13"],--12
		L["S_EQUIPSLOT_13"],--13
		L["S_EQUIPSLOT_15"],--14
		"Relic", 
		"Relic", 
		"Relic", 
		--L["S_EQUIPSLOT_16"],--15
		--L["S_EQUIPSLOT_16"],--16
	}
	local slot_indexes = {1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 11, 13, 13, 15, 16, 16, 16, 18, 19, 20, 20, 20} --16, 16
	local armor_slots = {[1]=true, [3]=true, [5]=true, [6]=true, [7]=true, [8]=true, [9]=true, [10]=true}
	local player_armor_type, armor_types = GetPlayerArmorType()
	
	local get_item_encounterid = function (item_id, item_equip_slot)
		for _, item in ipairs (RA.LootList [item_equip_slot]) do
			if (item[1] == item_id) then
				return item[2]
			end
		end
	end
	
	local select_item_frame = BisList:CreateCleanFrame (BisList, "BLSelectItemFrame")
	select_item_frame:SetParent (main_frame)
	select_item_frame:SetFrameLevel (main_frame:GetFrameLevel()+4)
	
	select_item_frame.buttons = {}
	local item_selected = function (self, button, itemid)
		list [select_item_frame.current_slotid] = itemid
		select_item_frame:Hide()
		main_frame:Refresh()
	end
	function select_item_frame:Reset()
		for _, button in ipairs (select_item_frame.buttons) do
			button:Hide()
		end
	end
	select_item_frame:Hide()

	local waiting = {}
	local wait_for_item_info = function()
		BisList.select_item (waiting.button, nil, waiting.id, waiting.slot, true)
	end
	
	local PRESET_LABEL_SELECT_PANEL = {color = "white", size = 12, font = "Accidental Presidency"}
	local PRESET_BUTTON_SELECT_PANEL = {	
		backdrop = {bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true},
		backdropcolor = {1, 1, 1, .1},
		onentercolor = {1, 1, 1, .5},
	}
	
	local button_select_panel_on_enter = function (self, capsule)
		GameTooltip:SetOwner (self)
		GameTooltip:SetHyperlink (capsule.itemLink)
		GameTooltip:Show()
		GameTooltip:ClearAllPoints()
		GameTooltip:SetPoint ("left", self, "right", 2, 0)
	end
	local button_select_panel_on_leave = function (self, capsule)
		GameTooltip:Hide()
	end
	
	BisList.select_item = function (self, _, slotid, slotindex, queued)
	
		local item_list = BisList.LootList [slotindex]
		local showing, width = 0, 0
		
		if (not queued and select_item_frame:IsShown() and slotid == select_item_frame.current_slotid) then
			return select_item_frame:Hide()
		end
		
		select_item_frame.current_slotid = slotid
		select_item_frame.current_slotindex = slotindex
		select_item_frame:Reset()
		
		local button_index = 1
		for i, loot in ipairs (item_list) do
			
			local itemid, encounterid = unpack (loot)
			waiting.id, waiting.slot, waiting.button = slotid, slotindex, self
			
			local itemName, itemLink, _, itemLevel, _, itemType, itemSubType, _, _, itemTexture = GetItemInfo (itemid)
			if (itemName) then
				if (not player_armor_type or not armor_types [itemSubType] or (player_armor_type and player_armor_type == itemSubType)) then
					local button = select_item_frame.buttons [button_index]
					if (not button) then
						button = BisList:CreateButton (select_item_frame, item_selected, 20, 20, nil, nil, nil, nil, nil, nil, nil, PRESET_BUTTON_SELECT_PANEL, PRESET_LABEL_SELECT_PANEL)
						select_item_frame.buttons [button_index] = button
						button:SetPoint ("topleft", select_item_frame, "topleft", 2, -(button_index-1)*21)
						button:SetPoint ("topright", select_item_frame, "topright", -2, -(button_index-1)*21)
						button:SetHook ("OnEnter", button_select_panel_on_enter)
						button:SetHook ("OnLeave", button_select_panel_on_leave)
					end

					local encounter_name = BisList:GetEncounterName (encounterid)
					button:SetText (itemName .. " (|cFFFFDD22" .. encounter_name .. "|r)")
					button:SetIcon (itemTexture, 18, 18, "overlay", no_border, nil, 4, 2)
					button:SetClickFunction (item_selected, itemid)
					button.itemLink = itemLink
					button:Show()
					
					showing = showing + 1
					button_index = button_index + 1
					
					local w = button.widget.text:GetStringWidth() + 36
					if (w > width) then
						width = w
					end
				end
			else
				C_Timer.After (0.1, wait_for_item_info)
			end
		end
		
		select_item_frame:SetSize (width, showing * 21)
		select_item_frame:ClearAllPoints()
		select_item_frame:SetPoint ("left", self, "right", 2, 0)
		select_item_frame:Show()
	end
	
	local panel_itemlabels = {}
	local panel_encounterlabels = {}
	local panel_itembuttons = {}
	local panel_backgrounds = {}
	
	local item_name_on_enter = function (self)
		local color = BAG_ITEM_QUALITY_COLORS [LE_ITEM_QUALITY_EPIC]
		self.label:SetTextColor (color.r+0.1, color.g+0.1, 1)
		if (self.link) then
			GameTooltip:SetOwner (self, "ANCHOR_TOP")
			GameTooltip:SetHyperlink (self.link)
			GameTooltip:Show()
		end
	end
	local item_name_on_leave = function (self)
		local color = BAG_ITEM_QUALITY_COLORS [LE_ITEM_QUALITY_EPIC]
		self.label:SetTextColor (color.r, color.g, color.b)
		GameTooltip:Hide()
	end
	
	local backdrop_table = {bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true}
	for i = 1, 16 do
		local label_slot_name =  BisList:CreateLabel (main_frame, slot_list [i] .. ":", BisList:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
		local button_select_item = BisList:CreateButton (main_frame, BisList.select_item, 60, 20, "select", i, slot_indexes[i], _, _, _, _, BisList:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		local background = CreateFrame ("frame", nil, main_frame)
		background:SetFrameLevel (main_frame:GetFrameLevel()+1)
		background:SetBackdrop (backdrop_table)
		background:SetBackdropColor (1, 1, 1, 0.1)
		local label_item_name = BisList:CreateLabel (background, "", BisList:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
		local label_encounter_name = BisList:CreateLabel (background, "", BisList:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
		
		local y = (-i * 21) - 15
		
		label_slot_name:SetPoint ("topleft", main_frame, "topleft", 10, y)
		label_item_name:SetPoint ("topleft", main_frame, "topleft", 75, y)
		label_encounter_name:SetPoint ("left", label_item_name, "right", 0, 0)
		button_select_item:SetPoint ("topleft", main_frame, "topleft", 350, y)
		
		background:SetPoint ("topleft", main_frame, "topleft", 60, y)
		background:SetPoint ("bottomright", button_select_item.widget, "bottomleft", -2, 0)
		background.label = label_item_name
		background:SetScript ("OnEnter", item_name_on_enter)
		background:SetScript ("OnLeave", item_name_on_leave)
		
		BisList:SetFontSize (label_slot_name, 14)
		BisList:SetFontSize (label_item_name, 14)
		BisList:SetFontSize (label_encounter_name, 14)
		
		tinsert (panel_itemlabels, label_item_name)
		tinsert (panel_encounterlabels, label_encounter_name)
		tinsert (panel_itembuttons, button_select_item)
		tinsert (panel_backgrounds, background)
	end
	
	function main_frame:Refresh()
	
		local itemlist = BisList:GetCharacterItemList()
		local myitems = BisList:GetMyItems()
		
		if (itemlist) then
			for index, label in ipairs (panel_itemlabels) do
			
				local item_id = itemlist [index]
				if (item_id > 0) then
					local itemName, itemLink, _, itemLevel, _, _, _, _, _, itemTexture = GetItemInfo (item_id)
					
					if (not itemName) then
						C_Timer.After (0.1, main_frame.Refresh)
						break
					else
						local equip_slot = slot_indexes [index] --equip slot
						local encounter_id = get_item_encounterid (item_id, equip_slot)
						local encounter_name = BisList:GetEncounterName (encounter_id)
						label:SetText ("[" .. itemName .. "]")
						local color = BAG_ITEM_QUALITY_COLORS [LE_ITEM_QUALITY_EPIC]
						label:SetTextColor (color.r, color.g, color.b)
						panel_encounterlabels[index]:SetText (" " .. encounter_name .. "")
						panel_backgrounds[index].link = itemLink
						
						if (myitems [index]:gsub (":.*", "") == "1") then
							panel_backgrounds[index]:SetBackdropColor (0, 1, 0, 0.2)
						else
							panel_backgrounds[index]:SetBackdropColor (0, 0, 0, 0)
						end
						
					end
				else
					label:SetText ("")
				end
			end
		else
			C_Timer.After (0.5, main_frame.Refresh)
		end
	end
	
	main_frame:Refresh()

end

if (can_install) then
	RA:InstallPlugin (BisList.displayName, "RABisList", BisList, default_config)
end


