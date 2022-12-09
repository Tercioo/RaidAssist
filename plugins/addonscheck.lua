
local RA = _G.RaidAssist
local L = LibStub ("AceLocale-3.0"):GetLocale ("RaidAssistAddon")
local _
local default_priority = 24
local DF = DetailsFramework

local default_config = {
	enabled = true,
	menu_priority = 1,
	tracking_addons = {
		["BigWigs"] = true,
		["DBM-Core"] = true,
		["Details"] = true,
	},
}

--create the addon object
local AddonsCheck = {version = "v0.1", pluginname = "CheckAddons", pluginId = "ADCK", displayName = "Check Addons"}
_G ["RaidAssistAddonsCheck"] = AddonsCheck

--const settings
local fillpanel_width = 862
local fillpanel_height = 624
local text_color_enabled = {r=1, g=1, b=1, a=1}
local text_color_disabled = {r=0.5, g=0.5, b=0.5, a=1}
local toolbar_icon = [[Interface\CHATFRAME\UI-ChatIcon-Share]]
local icon_texcoord = {l=0, r=1, t=0, b=1}

local COMM_SYNC_RECEIVED = "ACR" --when someone receives a sync response
local COMM_SYNC_REQUEST = "ACS" --the raid leader requested the sync from all users

local RESPONSE_TYPE_HAVE = 1
local RESPONSE_TYPE_NOT_HAVE = 0
local RESPONSE_TYPE_WAITING = -2
local RESPONSE_TYPE_OFFLINE = -3

--store ["playerName"] = addonsTable {0, 1, 0, 1, 1, 0}
AddonsCheck.PlayerUsingAddons = {}
--store the addonsTable names = {"DBM-Core", "BigWigs", etc}
AddonsCheck.LatestSyncAddonNames = {}

AddonsCheck.AddonsList = {
	["BigWigs"] = "Big Wigs",
	["DBM-Core"] = "Deadly Boss Mods",
	["WeakAuras"] = "WeakAuras 2",
	["AngryAssignments"] = "Angry Assignments",
	["RCLootCouncil"] = "RC Loot Council",
	["GTFO"] = "GTFO",
	["oRA3"] = "oRA 3",
	["Details"] = "Details! Damage Meter",
}

AddonsCheck.menu_text = function (plugin)
	if (AddonsCheck.db.enabled) then
		return toolbar_icon, icon_texcoord, "Addons Check", text_color_enabled
	else
		return toolbar_icon, icon_texcoord, "Addons Check", text_color_disabled
	end
end

AddonsCheck.menu_popup_show = function (plugin, ct_frame, param1, param2)

end

AddonsCheck.menu_popup_hide = function (plugin, ct_frame, param1, param2)

end

AddonsCheck.menu_on_click = function (plugin)

end

AddonsCheck.OnInstall = function (plugin)
	AddonsCheck.db.menu_priority = default_priority

	AddonsCheck:RegisterPluginComm (COMM_SYNC_RECEIVED, AddonsCheck.PluginCommReceived)
	AddonsCheck:RegisterPluginComm (COMM_SYNC_REQUEST, AddonsCheck.PluginCommReceived)

	if (AddonsCheck.db.enabled) then
		AddonsCheck.OnEnable (AddonsCheck)
	end
end

AddonsCheck.OnEnable = function (plugin)

end

AddonsCheck.OnDisable = function (plugin)

end

AddonsCheck.OnProfileChanged = function (plugin)

end

function AddonsCheck.manageAddOns()

end

function AddonsCheck.OnShowOnOptionsPanel()
	local OptionsPanel = AddonsCheck.OptionsPanel
	AddonsCheck.BuildOptions (OptionsPanel)
end

function AddonsCheck.BuildOptions (frame)

	if (frame.FirstRun) then
		return
	end
	frame.FirstRun = true

	local fillPanel = AddonsCheck:CreateFillPanel(frame, {}, fillpanel_width, fillpanel_height, false, false, false, {rowheight = 16}, _, "OPAddOnsCheckFP")
	fillPanel:SetPoint ("topleft", frame, "topleft", 0, -30)
	AddonsCheck.fillPanel = fillPanel

	local gradientBelowTheLine = DF:CreateTexture(fillPanel, {gradient = "vertical", fromColor = {0, 0, 0, 0.3}, toColor = "transparent"}, 1, 100, "artwork", {0, 1, 0, 1}, "gradientBelowTheLine")
	gradientBelowTheLine:SetPoint("bottoms", fillPanel, 1, 1)

	DetailsFramework:ApplyStandardBackdrop(fillPanel)
	fillPanel:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))

	local WelcomeLabel = AddonsCheck:CreateLabel(fillPanel, "Check for use of mandatory addons.\n\nSelect which addons you want to check on 'Add AddOn' button.\nClick on Check Addons to see the results.")
	WelcomeLabel:SetPoint ("bottomleft", RaidAssistOptionsPanel, "bottomleft", 225, 40)
	WelcomeLabel.align = "left"
	AddonsCheck:SetFontSize (WelcomeLabel, 14)
	AddonsCheck:SetFontColor (WelcomeLabel, "gray")
	frame.welcomeLabel = WelcomeLabel
	fillPanel.WelcomeLabel = WelcomeLabel

	local dummy = CreateFrame ("frame", nil, frame, "BackdropTemplate")
	dummy:SetScript ("OnShow", function()
		fillPanel:Show()
	end)
	dummy:SetScript ("OnHide", function()
		fillPanel:Hide()
	end)

	function AddonsCheck.UpdateFillPanel()
		--> alphabetical order
		local alphabetical_players = {}
		for playername, table in pairs (AddonsCheck.PlayerUsingAddons) do
			tinsert (alphabetical_players, {playername, table})
		end
		table.sort (alphabetical_players, function (t1, t2) return t2[1] < t1[1] end)

		if (#alphabetical_players > 0) then
			fillPanel.WelcomeLabel:Hide()
		else
			fillPanel.WelcomeLabel:Show()
		end

		--> build the player name and addon name header
		local header = {
			{name = "Player Name", type = "text", width = 120},
		}

		for index, addonName in ipairs (AddonsCheck.LatestSyncAddonNames) do
			local text = addonName
			while (#text > 12) do
				text = text:sub (1, -2)
			end
			addonName = text
			tinsert (header, {name = addonName, type = "text", width = 80})
		end

		fillPanel:SetFillFunction (function (index)
			local name = Ambiguate (alphabetical_players [index][1], "none")
			local t = alphabetical_players [index][2]
			return {name, unpack (t)}
		end)

		fillPanel:SetTotalFunction(function() return #alphabetical_players end)
		fillPanel:SetSize(fillpanel_width, fillpanel_height)
		fillPanel:UpdateRows(header)
		fillPanel:Refresh()
	end

	--Sync Button
	local sync_func = function()
		WelcomeLabel:Hide()
		AddonsCheck.ManageAddOnsFrame:Hide()
		fillPanel:Show()
		frame.button_add.text = "Add AddOn"
		AddonsCheck.RequestData()
	end

	local sync_button = AddonsCheck:CreateButton(frame, sync_func, 100, 18, "Check Addons", _, _, _, "button_sync", _, _, AddonsCheck:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), AddonsCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	sync_button:SetPoint("topleft", frame, "topleft", 0, 5)
	sync_button:SetIcon([[Interface\BUTTONS\UI-CheckBox-Check]], 16, 16, "overlay", {0, 1, 0, 28/32}, {1, 1, 1}, 2, 1, 0)

	--open add addon button
	local add_func = function()
		if (AddonsCheck.ManageAddOnsFrame:IsShown()) then
			AddonsCheck.ManageAddOnsFrame:Hide()
			frame.button_add.text = "Add AddOn"
			return
		end
		AddonsCheck.ManageAddOnsFrame:Show()
		frame.welcomeLabel:Hide()
		frame.button_add.text = "Done"
	end

	local addaddons_button = AddonsCheck:CreateButton(frame, add_func, 100, 18, "Add AddOn", _, _, _, "button_add", _, _, AddonsCheck:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), AddonsCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	addaddons_button:SetPoint("left", sync_button, "right", 2, 0)
	addaddons_button:SetIcon([[Interface\BUTTONS\UI-GuildButton-PublicNote-Up]], 14, 14, "overlay", {0, 1, 0, 1}, {1, 1, 1}, 2, 1, 0)

	--current tracking addons string
	local addons_string = AddonsCheck:CreateLabel(frame, "Tracking:", AddonsCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	addons_string:SetPoint("left", addaddons_button, "right", 2, 0)
	addons_string:Hide()
	frame.addons_string = addons_string

	--statusbar
	local statusBar = AddonsCheck:CreateBar(frame, LibStub:GetLibrary("LibSharedMedia-3.0"):Fetch("statusbar", "Iskar Serenity"), 658, 16, 100, "statusBarWorking", "AddonCheckerStatusBar")
	statusBar:SetPoint ("left", addaddons_button, "right", 2, 0)
	statusBar.RightTextIsTimer = true
	statusBar.BarIsInverse = true
	statusBar.fontsize = 11
	statusBar.fontface = "Accidental Presidency"
	statusBar.fontcolor = "darkorange"
	statusBar.color = "gray"
	statusBar.texture = "Iskar Serenity"
	statusBar.lefttext = "Ready!"
	statusBar:SetHook ("OnTimerEnd", function()
		statusBar.lefttext = "Ready!"
		statusBar.value = 100
		statusBar.shown = true
		statusBar.div_timer:Hide()
		return true
	end)
	AddonsCheck.StatusBar = statusBar

	function AddonsCheck.UpdateAddonsString()
		local s = "Tracking: "
		for addonName, IsTracking in pairs (AddonsCheck.db.tracking_addons) do
			local name = AddonsCheck.AddonsList [addonName]
			s = s .. (name or addonName) .. ", "
		end
		addons_string.text = s
	end

	AddonsCheck.UpdateAddonsString()

	--add more addons panel
	local manage_panel = CreateFrame("frame", nil, frame, "BackdropTemplate")
	manage_panel:SetPoint("topleft", frame, "topleft", 0, -30)
	manage_panel:SetSize(fillpanel_width, fillpanel_height)

	DetailsFramework:ApplyStandardBackdrop(manage_panel)
	manage_panel:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))
	manage_panel:Hide()

	manage_panel.tracking_frames = {}
	manage_panel.add_frames = {}

	local remove_addon = function (self, button, index)
		if (not AddonsCheck.db.tracking_addons [self.MyObject.label.text]) then
			AddonsCheck.db.tracking_addons [self.MyObject.label.text2] = nil
		else
			AddonsCheck.db.tracking_addons [self.MyObject.label.text] = nil
		end

		wipe (AddonsCheck.PlayerUsingAddons)
		wipe (AddonsCheck.LatestSyncAddonNames)

		manage_panel:UpdateCheckingAddOns()
		AddonsCheck.UpdateAddonsString()

		AddonsCheck.UpdateFillPanel()
	end

	local current_tracking_label = AddonsCheck:CreateLabel (manage_panel, "Tracking:", AddonsCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	current_tracking_label:SetPoint ("topleft", manage_panel, "topleft", 10, -10)

	for i = 1, 20 do
		local f = CreateFrame("frame", nil, manage_panel, "BackdropTemplate")
		f:SetSize(80, 20)
		f:SetPoint("topleft", manage_panel, "topleft", 10, i*21*-1 + (-18))

		local addonExclude = AddonsCheck:CreateButton(f, remove_addon, 10, 17, "X", i, _, _, "button_remove" .. i, _, _, AddonsCheck:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), AddonsCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		local addonName = AddonsCheck:CreateLabel(f, "", AddonsCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		addonName.fontsize = 10
		addonName.fontcolor = "yellow"

		addonExclude:SetPoint("left", f, "left", 2, 0)
		addonName:SetPoint("left", addonExclude, "right", 4, 0)

		f:Hide()
		f.label = addonName
		f.button = addonExclude
		addonExclude.label = addonName
		tinsert(manage_panel.tracking_frames, f)
	end

	function manage_panel:UpdateCheckingAddOns()
		for _, f in ipairs (manage_panel.tracking_frames) do
			f:Hide()
		end
		local i = 1
		for addonName, IsTracking in pairs (AddonsCheck.db.tracking_addons) do
			local name = AddonsCheck.AddonsList [addonName]
			local f = manage_panel.tracking_frames [i]
			f.label.text = name or addonName
			f.label.text2 = addonName
			f:Show()
			i = i + 1
		end
	end

	local your_addons_installed_label = AddonsCheck:CreateLabel (manage_panel, "Add AddOns:", AddonsCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	your_addons_installed_label:SetPoint ("topleft", manage_panel, "topleft", 175, -10)

	local addAddon = function(self, button, addonName)
		AddonsCheck.db.tracking_addons[addonName] = true
		manage_panel:UpdateCheckingAddOns()
		AddonsCheck.UpdateAddonsString()
	end

	local x, y = 170, -38
	local lastAddon = "NOADDONNAME"
	local lastAddon2 = "NOADDONNAME"
	local index = 1

	for i = 1, GetNumAddOns() do
		local addonName = GetAddOnInfo(i)

		--> check for not addin plugins of the same addon
		if ((not addonName:lower():find(lastAddon)) and (not addonName:lower():find(lastAddon2))) then
			local newAddonSelectionFrame = CreateFrame("frame", nil, manage_panel, "BackdropTemplate")
			newAddonSelectionFrame:SetSize(150, 21)
			newAddonSelectionFrame:SetPoint("topleft", manage_panel, "topleft", x, y)

			local addonAdd = AddonsCheck:CreateButton(newAddonSelectionFrame, addAddon, 150, 21, addonName, addonName, _, _, "button_add" .. index, _, 1, AddonsCheck:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), AddonsCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
			addonAdd:SetPoint("left", newAddonSelectionFrame, "left", 2, 0)
			newAddonSelectionFrame.button = addonAdd
			addonAdd.textalign = "left"
			addonAdd.textcolor = "orange"
			addonAdd.textsize = 11
			addonAdd.button.text:SetPoint("left", addonAdd.button, "left", 4, 0)
			DetailsFramework:ApplyStandardBackdrop(addonAdd)
			addonAdd:SetIcon([[Interface\PaperDollInfoFrame\Character-Plus]], 10, 10, "overlay", nil, "orange", 4)
			addonAdd.icon:SetBlendMode("ADD")
			addonAdd.icon:SetAlpha(0.7)

			addonAdd.onenter_backdrop = {.3, .3, .3, .3}
			addonAdd.onleave_backdrop = {0, 0, 0, 0.2}

			lastAddon = addonName:lower()
			lastAddon = lastAddon:gsub ("%_", "")
			lastAddon2 = lastAddon:gsub ("%-.*", "")
			lastAddon2 = lastAddon2:gsub ("_.*", "")

			if (index % 26 == 0) then
				x = x + 170
				y = -38
			else
				y = y - 22
			end
			index = index + 1
		end
	end

	AddonsCheck.ManageAddOnsFrame = manage_panel
	AddonsCheck.ManageAddOnsFrame:SetScript ("OnShow", function()
		manage_panel:UpdateCheckingAddOns()
		fillPanel:Hide()
	end)
	AddonsCheck.ManageAddOnsFrame:SetScript ("OnHide", function()
		fillPanel:Show()
		frame.button_add.text = "Addon AddOn"
	end)

	frame:SetScript ("OnShow", function()
		AddonsCheck.UpdateFillPanel()
	end)
end

RA:InstallPlugin(AddonsCheck.displayName, "RAAddonsCheck", AddonsCheck, default_config)

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- AddonsCheck.RaidAddonsList

AddonsCheck.last_data_sent = 0
AddonsCheck.last_data_request = 0

-- raid leader apertou o botao de sync, envia um pedido para os jogadores mandarem seus addons
function AddonsCheck.RequestData()
	if (not RA:UnitHasAssist("player")) then
		AddonsCheck:Msg("you need to be a assistant or leader.")
		return

	elseif (AddonsCheck.last_data_request + 2 > time()) then
		AddonsCheck:Msg("a check still ongoing, please wait.")
		return
	end

	AddonsCheck.last_data_request = time()

	local addonsNames = {}
	for addonName, IsTracking in pairs(AddonsCheck.db.tracking_addons) do
		tinsert(addonsNames, addonName)
	end

	AddonsCheck.StatusBar.lefttext = "working..."
	AddonsCheck.StatusBar:SetTimer(2)

	--send a numeric table, the users answer with a numeric table with 1 or 0
	AddonsCheck:SendPluginCommMessage(COMM_SYNC_REQUEST, AddonsCheck.GetChannel(), _, _, AddonsCheck:GetPlayerNameWithRealm(), addonsNames)

	--pre fill the result table
	wipe (AddonsCheck.PlayerUsingAddons)

	AddonsCheck.LatestSyncAddonNames = addonsNames

	local myName = UnitName("player") .. "-" .. GetRealmName()

	if (IsInRaid()) then
		for i = 1, GetNumGroupMembers() do
			local playerName, realmName = UnitFullName ("raid" .. i)
			if (realmName == "" or realmName == nil) then
				realmName = GetRealmName()
			end
			playerName = playerName .. "-" .. realmName

			--build the table
			AddonsCheck.PlayerUsingAddons [playerName] = AddonsCheck.PlayerUsingAddons [playerName] or {}

			--fill it
			for index, addonName in ipairs (addonsNames) do
				if (myName == playerName) then
					AddonsCheck.PlayerUsingAddons [playerName] [index] = RESPONSE_TYPE_HAVE
				else
					if (UnitIsConnected ("raid" .. i)) then
						AddonsCheck.PlayerUsingAddons [playerName] [index] = RESPONSE_TYPE_WAITING
					else
						AddonsCheck.PlayerUsingAddons [playerName] [index] = RESPONSE_TYPE_OFFLINE
					end
				end
			end

			--format
			AddonsCheck.PlayerUsingAddons[playerName] = AddonsCheck.FormatReceivedList(AddonsCheck.PlayerUsingAddons [playerName])
		end

	elseif (IsInGroup()) then
		for i = 1, GetNumGroupMembers() - 1 do
			local playerName, realmName = UnitFullName ("party" .. i)
			if (realmName == "" or realmName == nil) then
				realmName = GetRealmName()
			end
			playerName = playerName .. "-" .. realmName

			--build the table
			AddonsCheck.PlayerUsingAddons [playerName] = AddonsCheck.PlayerUsingAddons [playerName] or {}

			--fill it
			for index, addonName in ipairs (addonsNames) do
				if (myName == playerName) then
					AddonsCheck.PlayerUsingAddons [playerName] [index] = RESPONSE_TYPE_HAVE
				else
					if (UnitIsConnected ("party" .. i)) then
						AddonsCheck.PlayerUsingAddons [playerName] [index] = RESPONSE_TYPE_WAITING
					else
						AddonsCheck.PlayerUsingAddons [playerName] [index] = RESPONSE_TYPE_OFFLINE
					end
				end
			end

			--format
			AddonsCheck.PlayerUsingAddons [playerName] = AddonsCheck.FormatReceivedList(AddonsCheck.PlayerUsingAddons [playerName])
		end
	end

	AddonsCheck.UpdateFillPanel()
end

function AddonsCheck.BuildAddonList()
	local addonsList = AddonsCheck.LatestSyncAddonNames --tabela numerica com os nomes dos addons
	local addonsInstalled = {} --tabela hash com os nomes dos addons e se esta instalado ou n�o
	for i = 1, GetNumAddOns() do
		local name, title, notes, loadable, reason, security, newVersion = GetAddOnInfo (i)
		addonsInstalled [name] = loadable and RESPONSE_TYPE_HAVE or RESPONSE_TYPE_NOT_HAVE
	end

	local returnTable = {}
	--insere o resultado em uma tabela numera para enviar
	for index, addonName in ipairs (addonsList) do
		tinsert (returnTable, addonsInstalled [addonName] or RESPONSE_TYPE_NOT_HAVE)
	end

	return returnTable
end

function AddonsCheck.GetChannel()
	if (IsInRaid()) then
		return "RAID-NOINSTANCE"
	elseif (IsInGroup()) then
		return "PARTY-NOINSTANCE"
	else
		return "RAID-NOINSTANCE"
	end
end

local postpone_send_data = function()
	if (not AddonsCheck.PostponeTicker or AddonsCheck.PostponeTicker._cancelled) then
		AddonsCheck.PostponeTicker = C_Timer.NewTicker (10, AddonsCheck.PostponeSendData)
	end
end

function AddonsCheck:PostponeSendData()
	if (not InCombatLockdown() and (IsInRaid (LE_PARTY_CATEGORY_HOME) or IsInGroup (LE_PARTY_CATEGORY_HOME))) then
		AddonsCheck:SendData()
		if (AddonsCheck.PostponeTicker and not AddonsCheck.PostponeTicker._cancelled) then
			AddonsCheck.PostponeTicker:Cancel()
		end
	elseif (not IsInRaid (LE_PARTY_CATEGORY_HOME) and not IsInGroup (LE_PARTY_CATEGORY_HOME)) then
		if (AddonsCheck.PostponeTicker and not AddonsCheck.PostponeTicker._cancelled) then
			AddonsCheck.PostponeTicker:Cancel()
		end
	end
end

function AddonsCheck:SendData()
	if (AddonsCheck.last_data_sent + 5 < time()) then
		local data = AddonsCheck.BuildAddonList()
		AddonsCheck:SendPluginCommMessage (COMM_SYNC_RECEIVED, AddonsCheck.GetChannel(), _, _, AddonsCheck:GetPlayerNameWithRealm(), data)
		AddonsCheck.last_data_sent = time()
	else
		postpone_send_data()
	end
end

function AddonsCheck.FormatReceivedList (addonsList)
	for i = 1, #addonsList do
		addonsList [i] = (addonsList [i] == RESPONSE_TYPE_HAVE and "|cFF55FF55ok|r") or  --have
					(addonsList [i] == RESPONSE_TYPE_NOT_HAVE and "|cFFFF5555-|r") or --not have
					(addonsList [i] == RESPONSE_TYPE_WAITING and "|cFF888888?|r") or --still waiting the user answer
					(addonsList [i] == RESPONSE_TYPE_OFFLINE and "|cFFFF0000offline|r") --the user is offline
	end
	return addonsList
end

function AddonsCheck.PluginCommReceived(sourceName, prefix, sourcePluginVersion, playerName, addonsList)
	playerName = sourceName

	if (type (playerName) ~= "string" or type (addonsList) ~= "table") then
		return
	end

	--received a list of addons used by the player
	if (prefix == COMM_SYNC_RECEIVED) then
		AddonsCheck.PlayerUsingAddons [playerName] = AddonsCheck.PlayerUsingAddons [playerName] or {}
		wipe (AddonsCheck.PlayerUsingAddons [playerName])
		AddonsCheck.PlayerUsingAddons [playerName] = AddonsCheck.FormatReceivedList (addonsList)
		if (AddonsCheck.fillPanel and AddonsCheck.fillPanel:IsShown()) then
			AddonsCheck.UpdateFillPanel()
		end

	--leader request a full list addon request
	elseif (prefix == COMM_SYNC_REQUEST) then
		--check if is raid leader
		if (RA:UnitHasAssist(playerName)) then
			--check if the sender isnt 'me'
			if (Ambiguate(playerName, "none") == UnitName("player")) then
				--return
			end

			AddonsCheck.LatestSyncAddonNames = addonsList
			wipe(AddonsCheck.PlayerUsingAddons)
			C_Timer.After(0.3, AddonsCheck.SendData)
		end
	end
end