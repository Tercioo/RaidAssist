
local RA = _G.RaidAssist
local L = LibStub("AceLocale-3.0"):GetLocale ("RaidAssistAddon")
local _
local default_priority = 26

local default_config = {
	enabled = true,
	menu_priority = 1,
	only_from_guild = false,
	auto_install_from_trusted = false,
	installed_history = {},
}

local text_color_enabled = {r=1, g=1, b=1, a=1}
local text_color_disabled = {r=0.5, g=0.5, b=0.5, a=1}

local aura_scroll_x_pos = 669
local top_statusbar_width = 463
local fillpanel_width = 665
local fillpanel_height = 630

local toolbar_icon = [[Interface\CHATFRAME\UI-ChatIcon-Share]]
local icon_texcoord = {l=0, r=1, t=0, b=1}

if (_G ["RaidAssistAuraCheck"]) then
	return
end
local AuraCheck = {version = "v0.1", pluginname = "AuraCheck", pluginId = "AUCK", displayName = "Aura Check"}
_G ["RaidAssistAuraCheck"] = AuraCheck

local COMM_AURA_CHECKREQUEST = "WAC" --check aura - the raid leader requested an aura check
local COMM_AURA_CHECKRECEIVED = "WAR" --a user sent an aura check response
local COMM_AURA_INSTALLREQUEST = "WAI" --install - the raid leader requested the user to install an aura

local RESPONSE_TYPE_NOSAMEGUILD = 4
local RESPONSE_TYPE_DECLINED_ALREADYHAVE = 3
local RESPONSE_TYPE_DECLINED = 2
local RESPONSE_TYPE_HAVE = 1
local RESPONSE_TYPE_NOT_HAVE = 0
local RESPONSE_TYPE_NOWA = -1
local RESPONSE_TYPE_WAITING = -2
local RESPONSE_TYPE_OFFLINE = -3

local CONST_RESULTAURALIST_ROWS = 30
local CONST_AURALIST_ROWS = 20
local CONST_AURALIST_ROW_HEIGHT = 30

local valid_results = {
	[RESPONSE_TYPE_NOSAMEGUILD] = true,
	[RESPONSE_TYPE_DECLINED_ALREADYHAVE] = true,
	[RESPONSE_TYPE_DECLINED] = true,
	[RESPONSE_TYPE_HAVE] = true,
	[RESPONSE_TYPE_NOT_HAVE] = true,
	[RESPONSE_TYPE_NOWA] = true,
}

AuraCheck.AuraState = {} --hold aura state received from other users
--structure:
-- AuraState [ PLAYER NAME ] = { [AURANAME] = AURASTATE}

AuraCheck.menu_text = function (plugin)
	if (AuraCheck.db.enabled) then
		return toolbar_icon, icon_texcoord, "Aura Check & Share", text_color_enabled
	else
		return toolbar_icon, icon_texcoord, "Aura Check & Share", text_color_disabled
	end
end

AuraCheck.menu_popup_show = function (plugin, ct_frame, param1, param2)

end

AuraCheck.menu_popup_hide = function (plugin, ct_frame, param1, param2)

end

AuraCheck.menu_on_click = function (plugin)

end

AuraCheck.OnInstall = function (plugin)
	AuraCheck.db.menu_priority = default_priority

	AuraCheck:RegisterPluginComm (COMM_AURA_CHECKREQUEST, AuraCheck.PluginCommReceived)
	AuraCheck:RegisterPluginComm (COMM_AURA_CHECKRECEIVED, AuraCheck.PluginCommReceived)	
	AuraCheck:RegisterPluginComm (COMM_AURA_INSTALLREQUEST, AuraCheck.PluginCommReceived)	

	if (AuraCheck.db.enabled) then
		AuraCheck.OnEnable (AuraCheck)
	end
end

AuraCheck.OnEnable = function (plugin)

end

AuraCheck.OnDisable = function (plugin)

end

AuraCheck.OnProfileChanged = function (plugin)

end

local lower = string.lower
local sortFunction = function (t1, t2) return t2[1] < t1[1] end

function AuraCheck.UpdateAurasFillPanel(fillPanel)
	fillPanel = fillPanel or (AuraCheckerAurasFrame and AuraCheckerAurasFrame.fillPanel)
	if (not fillPanel) then
		return
	end

	local alphabeticalPlayers = {}
	local auraNames = {}
	local panelHeader = {}

	--alphabetical order
	for playerName, auraStateTable in pairs(AuraCheck.AuraState) do
		tinsert (alphabeticalPlayers, {playerName, auraStateTable})
		for auraName, _ in pairs (auraStateTable) do
			auraNames [auraName] = true
		end
	end
	table.sort (alphabeticalPlayers, sortFunction)

	if (#alphabeticalPlayers > 0) then
		fillPanel.NoAuraLabel:Hide()
		fillPanel.ResultInfoLabel:Hide()
	else
		fillPanel.NoAuraLabel:Show()
		fillPanel.ResultInfoLabel:Show()
	end

	tinsert (panelHeader, {name = "Player Name", type = "text", width = 120})

	for auraName, _ in pairs (auraNames) do
		tinsert (panelHeader, {name = auraName, type = "text", width = 120})
	end

	fillPanel:SetFillFunction (function(index)
		local playerName = Ambiguate(alphabeticalPlayers [index][1], "none")
		local stateTable = alphabeticalPlayers [index][2]

		local temp = {}
		for auraName, _ in pairs(auraNames) do
			tinsert (temp,
					(stateTable [auraName] == RESPONSE_TYPE_NOSAMEGUILD and "|cFFFF0000guild|r") or --is not from the same guild
					(stateTable [auraName] == RESPONSE_TYPE_DECLINED_ALREADYHAVE and "|cFFFFFF00ok|r") or --refused but already has one installed
					(stateTable [auraName] == RESPONSE_TYPE_DECLINED and "|cFFFF0000declined|r") or --refused to install
					(stateTable [auraName] == RESPONSE_TYPE_HAVE and "|cFF55FF55ok|r") or  --have
					(stateTable [auraName] == RESPONSE_TYPE_NOT_HAVE and "|cFFFF5555-|r") or --not have
					(stateTable [auraName] == RESPONSE_TYPE_NOWA and "|cFFFF5555NO WA|r") or --no wa installed
					(stateTable [auraName] == RESPONSE_TYPE_WAITING and "|cFF888888?|r") or --still waiting the user answer
					(stateTable [auraName] == RESPONSE_TYPE_OFFLINE and "|cFFFF0000offline|r") --the user is offline
				)
		end

		local _, class = UnitClass(playerName)
		if (class) then
			local originalPlayerName = playerName
			playerName = DetailsFramework:AddClassColorToText(playerName, class)
			playerName = DetailsFramework:AddClassIconToText(playerName, originalPlayerName, class, true, 20)
		end

		return {playerName, unpack(temp)}
	end)

	fillPanel:SetTotalFunction(function() return #alphabeticalPlayers end)
	fillPanel:SetSize(fillpanel_width, fillpanel_height)
	fillPanel:UpdateRows(panelHeader)
	fillPanel:Refresh()

	--update received auras scroll
	AuraCheckerHistoryFrameHistoryScroll.Update()
end

function AuraCheck.OnShowOnOptionsPanel()
	local OptionsPanel = AuraCheck.OptionsPanel
	AuraCheck.BuildOptions(OptionsPanel)
end

function AuraCheck.BuildOptions (frame)
	if (frame.FirstRun) then
		return
	end
	frame.FirstRun = true

	local framesSize = {800, 600}
	local framesPoint = {"topleft", frame, "topleft", 0, -30}
	local backdrop = {bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true}
	local backdropColor = {0, 0, 0, 0.5}

	function AuraCheck.ShowAurasPanel()
		AuraCheckerAurasFrame:Show()
		AuraCheckerHistoryFrame:Hide()
		frame.showMainFrameButton:SetBackdropBorderColor(1, 1, 0)
		frame.showHistoryFrameButton:SetBackdropBorderColor(0, 0, 0)
		frame.ShowingPanel = 1
	end
	function AuraCheck.ShowHistoryPanel()
		AuraCheckerAurasFrame:Hide()
		AuraCheckerHistoryFrame:Show()
		frame.showMainFrameButton:SetBackdropBorderColor(0, 0, 0)
		frame.showHistoryFrameButton:SetBackdropBorderColor(1, 1, 0)
		frame.ShowingPanel = 2
	end

	--on main frame
		local mainButtonTemplate = {
			backdrop = {edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true},
			backdropcolor = {1, 1, 1, .5},
			onentercolor = {1, 1, 1, .5},
		}
	
		--button - show auras
		local showMainFrameButton = AuraCheck:CreateButton (frame, AuraCheck.ShowAurasPanel, 100, 18, "Results", _, _, _, "showMainFrameButton", _, _, mainButtonTemplate, AuraCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		showMainFrameButton:SetPoint ("topleft", frame, "topleft", 0, 5)
		showMainFrameButton:SetIcon ([[Interface\BUTTONS\UI-GuildButton-PublicNote-Up]], 14, 14, "overlay", {0, 1, 0, 1}, {1, 1, 1}, 2, 1, 0)
	
		--button - show history
		local showHistoryFrameButton = AuraCheck:CreateButton (frame, AuraCheck.ShowHistoryPanel, 100, 18, "Received Auras", _, _, _, "showHistoryFrameButton", _, _, mainButtonTemplate, AuraCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		showHistoryFrameButton:SetPoint ("left", showMainFrameButton, "right", 2, 0)
		showHistoryFrameButton:SetIcon ([[Interface\BUTTONS\JumpUpArrow]], 14, 12, "overlay", {0, 1, 1, 0}, {1, .5, 1}, 2, 1, 0)
	
		showMainFrameButton:SetBackdropBorderColor (1, 1, 0)
		frame.ShowingPanel = 1
	
	--auras frame
	
		local aurasFrame = CreateFrame ("frame", "AuraCheckerAurasFrame", frame, "BackdropTemplate")
		aurasFrame:SetPoint (unpack (framesPoint))
		aurasFrame:SetSize (unpack (framesSize))

		--fillpanel - auras panel
		local fillPanel = AuraCheck:CreateFillPanel (aurasFrame, {}, fillpanel_width, fillpanel_height, false, false, false, {rowheight = 19}, _, "AuraCheckerAurasFrameFillPanel")
		fillPanel:SetPoint ("topleft", aurasFrame, "topleft", 0, 0)
		aurasFrame.fillPanel = fillPanel
		DetailsFramework:ApplyStandardBackdrop(fillPanel)
		fillPanel:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))

		local NoAuraLabel = AuraCheck:CreateLabel (fillPanel, "Select a weakaura on the right scroll box.\nClick on 'Check Aura', to see users who has it in the raid.\nClick on 'Share Aura' to send the aura to all raid members.\nRaid members also must have 'Raid Assist' addon.")
		NoAuraLabel:SetPoint ("bottomleft", RaidAssistOptionsPanel, "bottomleft", 225, 40)
		NoAuraLabel.align = "left"
		AuraCheck:SetFontSize (NoAuraLabel, 14)
		AuraCheck:SetFontColor (NoAuraLabel, "gray")
		
		local ResultInfoLabel = AuraCheck:CreateLabel (fillPanel, "When checking or sharing an aura, results can be:\n\n|cFFFF0000guild|r: is not from the same guild\n|cFFFFFF00ok|r: refused but already has the aura installed\n|cFFFF0000declined|r: the user declined the aura\n|cFF55FF55ok|r: the user accepted or already have the aura\n|cFFFF5555-|r: the user DO NOT have the aura\n|cFFFF5555NO WA|r: the user DO NOT have weakauras installed\n|cFF888888?|r: waiting the answer from the raid member\n|cFFFF0000offline|r: the raid member is offline")
		ResultInfoLabel:SetPoint ("bottomleft", RaidAssistOptionsPanel, "bottomleft", 225, 120)
		ResultInfoLabel.align = "left"
		AuraCheck:SetFontSize (ResultInfoLabel, 14)
		AuraCheck:SetFontColor (ResultInfoLabel, "gray")
		fillPanel.NoAuraLabel = NoAuraLabel
		fillPanel.ResultInfoLabel = ResultInfoLabel

		local refreshAuraScroll = function(self, data, offset, totalLines)
			local auras = data

			if (self.SearchingFor ~= "") then
				local search = lower(self.SearchingFor)
				for i = #auras, 1, -1 do
					local auraName = lower(auras[i][1])
					if (not auraName:find(search)) then
						tremove(auras, i)
					end
				end
			end

			--FauxScrollFrame_Update (self, #auras, CONST_AURALIST_ROWS, CONST_AURALIST_ROW_HEIGHT) --self, amt, amt frames, height of each frame
			--local offset = FauxScrollFrame_GetOffset(self)

			for i = 1, totalLines do
				local index = i + offset
				--local button = self.Frames[i]
				local data = auras[index]
				
				if (data) then
					local button = self:GetLine(i)
					if (button) then
						local auraName = data[1]
						--local auraIcon = data[2]

						--button.Icon:SetTexture(auraIcon)
						button.Label:SetText(auraName)
						--DetailsFramework:TruncateText(button.Label, button:GetWidth()-4)

						if (auraName == self.CurrentAuraSelected) then
							button:SetBackdropColor(DetailsFramework:ParseColors("gray"))
						else
							button:SetBackdropColor(unpack (backdropColor))
						end
						button:Show()
					end
				else
					local button = self:GetLine(i)
					button.Label:SetText("")
					button:Hide()
				end
			end
		end

		local auraScroll = DetailsFramework:CreateScrollBox(frame, "AuraCheckerAurasFrameAuraScroll", refreshAuraScroll, {}, 180, CONST_AURALIST_ROWS*(CONST_AURALIST_ROW_HEIGHT+1), CONST_AURALIST_ROWS, CONST_AURALIST_ROW_HEIGHT)
		auraScroll:SetPoint("topleft", aurasFrame, "topleft", aura_scroll_x_pos, -5)

		auraScroll.CurrentAuraSelected = "-none-"
		auraScroll.SearchingFor = ""

		function auraScroll.RefreshMe()
			local auras = AuraCheck:GetAllWeakAurasNamesAndIcons()
			if (auras) then
				auraScroll:SetData(auras)
				auraScroll:Refresh()
			else
				auraScroll:SetData({})
			end
		end

		DetailsFramework:ReskinSlider(auraScroll)
		DetailsFramework:ApplyStandardBackdrop(auraScroll)

		local on_mousedown = function(self)
			if (self.Label:GetText() ~= "") then
				auraScroll.CurrentAuraSelected = self.Label:GetText()
				auraScroll.RefreshMe()

				local now = GetTime()
				if (self.LastClick + 0.22 > now) then
					if (WeakAuras and WeakAuras.IsOptionsOpen) then
						if (WeakAuras.IsOptionsOpen()) then
							WeakAurasFilterInput:SetText (self.Label:GetText())
						else
							WeakAuras.OpenOptions (self.Label:GetText())
							WeakAurasFilterInput:SetText (self.Label:GetText())
						end
					end
				end

				self.LastClick = now
			end
		end

		local aura_on_enter = function (self)
			if (auraScroll.CurrentAuraSelected ~= self.Label:GetText()) then
				self:SetBackdropColor(.3, .3, .3, .75)
			end
		end

		local aura_on_leave = function (self)
			if (auraScroll.CurrentAuraSelected ~= self.Label:GetText()) then
				self:SetBackdropColor(unpack (backdropColor))
			end
		end
		
		--> aura selection
		local createAuraLine = function(self, i)
		--for i = 1, CONST_AURALIST_ROWS do
			local f = CreateFrame ("frame", "AuraCheckerAurasFrameAuraScroll_Button" .. i, self, "BackdropTemplate")
			f:SetPoint ("topleft", auraScroll, "topleft", 1, -(i-1)* (CONST_AURALIST_ROW_HEIGHT+1))
			f:SetScript ("OnMouseUp", on_mousedown)
			f:SetScript ("OnEnter", aura_on_enter)
			f:SetScript ("OnLeave", aura_on_leave)
			f:SetSize (178, CONST_AURALIST_ROW_HEIGHT)
			f:SetBackdrop (backdrop)
			f:SetBackdropColor (unpack (backdropColor))
			f.LastClick = 0

			local auraIcon = f:CreateTexture(nil, "overlay")
			auraIcon:SetSize(CONST_AURALIST_ROW_HEIGHT-4, CONST_AURALIST_ROW_HEIGHT-4)
			auraIcon:SetTexCoord(.1, .9, .1, .9)
			auraIcon:SetPoint ("left", f, "left", 2, 0)

			local label = f:CreateFontString (nil, "overlay", "GameFontNormal")
			--label:SetPoint("topleft", auraIcon, "topright", 2, -4)
			label:SetPoint("left", f, "left", 2, 0)

			local timeToShare = f:CreateFontString (nil, "overlay", "GameFontNormal")
			timeToShare:SetPoint("topleft", label, "bottomleft", 0, -4)

			AuraCheck:SetFontSize (label, 10)
			AuraCheck:SetFontColor (label, "white")
			f.Label = label
			f.Icon = auraIcon
			f.timeToShare = timeToShare

			return f
		end

		--create the scrollbox lines
		for i = 1, CONST_AURALIST_ROWS do
			auraScroll:CreateLine(createAuraLine, i)
		end

		auraScroll.RefreshMe()

		--textbox - search aura
		local onTextChanged = function()
			local text = frame.searchBox:GetText()
			auraScroll.SearchingFor = text
			auraScroll.RefreshMe()
		end

		local searchBox = AuraCheck:CreateTextEntry (frame, function()end, 160, 20, "searchBox", _, _, AuraCheck:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		searchBox:SetPoint ("bottomleft", auraScroll, "topleft", 0, 2)
		searchBox:SetSize (160, 18)
		searchBox:SetHook ("OnTextChanged", onTextChanged)
		
		local mglass = AuraCheck:CreateImage (searchBox, [[Interface\MINIMAP\TRACKING\None]], 18, 18)
		mglass:SetPoint ("left", searchBox, "left", 2, 0)

		local clearSearchBoxFunc = function()
			frame.searchBox:SetText ("")
			
		end
		local clearSearchBox = AuraCheck:CreateButton (frame, clearSearchBoxFunc, 12, 18, "", _, _, _, "clearSearchBox")
		clearSearchBox:SetPoint ("left", searchBox, "right", 2, 0)
		clearSearchBox:SetIcon ([[Interface\Glues\LOGIN\Glues-CheckBox-Check]])
		
		--button - share and check aura
		
		AuraCheck.last_data_request = 0
		
		local checkAuraFunc = function()
		
			NoAuraLabel:Hide()
			ResultInfoLabel:Hide()
		
			--get the selected aura
			local auraSelected = auraScroll.CurrentAuraSelected
			if (auraSelected == "" or auraSelected == "-none-") then
				return AuraCheck:Msg ("you need to select an aura before.")
			end
			
			local auraName = auraSelected
			
			--get the aura object
			local auraTable = AuraCheck:GetWeakAuraTable (auraName)
			if (not auraTable) then
				return AuraCheck:Msg ("aura not found.")
			end
			
			--am i the raid leader and can i send the request?
			if (not IsInRaid (LE_PARTY_CATEGORY_HOME) and not IsInGroup (LE_PARTY_CATEGORY_HOME)) then
				return AuraCheck:Msg ("you aren't in a local raid group.")
				
			elseif (not AuraCheck:UnitIsRaidLeader (UnitName ("player")) and not RA:UnitHasAssist ("player")) then
				return AuraCheck:Msg ("you aren't the raid leader or assistant.")
				
			elseif (AuraCheck.last_data_request + 2 > time()) then
				return AuraCheck:Msg ("another task still ongoing, please wait.")
				
			end
			
			--send the request
			AuraCheck:SendPluginCommMessage (COMM_AURA_CHECKREQUEST, AuraCheck.GetChannel(), _, _, AuraCheck:GetPlayerNameWithRealm(), auraName)
			
			--fill the result table
			local myName = GetUnitName("player", true)

			if (IsInRaid()) then
				for i = 1, GetNumGroupMembers() do
					local unitId = "raid" .. i
					local playerName = GetUnitName(unitId, true)

					if (myName ~= playerName) then
						AuraCheck.AuraState[playerName] = AuraCheck.AuraState[playerName] or {}

						if (UnitIsConnected(unitId)) then
							AuraCheck.AuraState[playerName][auraName] = RESPONSE_TYPE_WAITING
						else
							AuraCheck.AuraState[playerName][auraName] = RESPONSE_TYPE_OFFLINE
						end
					end
				end

			elseif (IsInGroup()) then
				for i = 1, GetNumGroupMembers() - 1 do
					local unitId = "party" .. i
					local playerName = GetUnitName(unitId, true)

					AuraCheck.AuraState [playerName] = AuraCheck.AuraState [playerName] or {}

					if (myName ~= playerName) then
						AuraCheck.AuraState [playerName] = AuraCheck.AuraState [playerName] or {}

						if (UnitIsConnected(unitId)) then
							AuraCheck.AuraState[playerName][auraName] = RESPONSE_TYPE_WAITING
						else
							AuraCheck.AuraState[playerName][auraName] = RESPONSE_TYPE_OFFLINE
						end
					end
				end
			end

			--wait the results
			AuraCheck.last_data_request = time()
			--statusBar
			frame.statusBarWorking.lefttext = "working..."
			frame.statusBarWorking:SetTimer(2)

			AuraCheck.UpdateAurasFillPanel()
		end

		--accordingly to weakauras, these keys shall be ignored when transmiting data
		local excludedKeys = {
			["controlledChildren"] = true,
			["parent"] = true,
			["authorMode"] = true,
			["skipWagoUpdate"] = true,
			["ignoreWagoUpdate"] = true,
			["preferToUpdate"] = true,
		}

		--using DetailsFramework.table.copytocompress
		AuraCheck.copyAuraToCompress = function(t1, t2)
			for key, value in pairs (t2) do
				if (key ~= "__index" and type(value) ~= "function") then
					if (type(value) == "table") then
						if (not value.GetObjectType) then
							if (not excludedKeys[key]) then
								t1 [key] = t1 [key] or {}
								AuraCheck.copyAuraToCompress(t1 [key], t2 [key])
							end
						end
					else
						if (not excludedKeys[key]) then
							t1 [key] = value
						end
					end
				end
			end
			return t1
		end

		local compressAuraData = function(auraId)
			local auraData = WeakAuras.GetData(auraId)

			if (auraData) then
				--indexed table, first index is the main aura, subsequent indexes are children
				local dataToSend = {}

				--make a copy of the aura
				local auraCopy = AuraCheck.copyAuraToCompress({}, auraData)
				if (auraCopy) then
					dataToSend[1] = auraCopy

					--identify children and compress them too
					local children = auraData.controlledChildren

					if (children and type(children) == "table") then
						for _, childAuraId in pairs(children) do
							local childData = WeakAuras.GetData(childAuraId)
							if (childData) then
								--create a copy of the aura
								local childCopy = AuraCheck.copyAuraToCompress({}, childData)
								if (childCopy) then
									--add the child into the send data table
									dataToSend[#dataToSend+1] = childCopy
								end
							end
						end
					end

					--serialize the data
					local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0")
					if (LibAceSerializer) then
						local dataSerialized = LibAceSerializer:Serialize(dataToSend)
						if (dataSerialized) then
							local LibDeflate = LibStub:GetLibrary ("LibDeflate")
							local dataCompressed = LibDeflate:CompressDeflate(dataSerialized, {level = 9})
							if (dataCompressed) then
								local dataEncoded = LibDeflate:EncodeForWoWAddonChannel(dataCompressed)
								return dataEncoded
							end
						end
					end
				end
			end
		end

		local shareAuraFunc = function()
			NoAuraLabel:Hide()
			ResultInfoLabel:Hide()
		
			local auraSelected = auraScroll.CurrentAuraSelected
			if (auraSelected == "" or auraSelected == "-none-") then
				return AuraCheck:Msg ("you need to select an aura before.")
			end
			
			--am i the raid leader and can i send the request?
			if (not IsInRaid (LE_PARTY_CATEGORY_HOME) and not IsInGroup (LE_PARTY_CATEGORY_HOME)) then
				return AuraCheck:Msg ("you aren't in a local raid group.")

			elseif (not AuraCheck:UnitIsRaidLeader (UnitName ("player")) and not RA:UnitHasAssist ("player")) then
				return AuraCheck:Msg ("you aren't the raid leader or assistant.")

			elseif (AuraCheck.last_data_request + 2 > time()) then
				return AuraCheck:Msg ("another task still ongoing, please wait.")
			end

			local auraName = auraSelected
			local dataCompressed = compressAuraData(auraName)

			local dataSize = #dataCompressed
			if (dataSize > 2000) then
				local estimatedSeconds = dataSize / 850
				local timeString = DetailsFramework:IntegerToTimer(estimatedSeconds)
				AuraCheck:Msg("To share this aura will take", timeString, ".")
			end

			if (not dataCompressed or type (dataCompressed) ~= "string") then
				return AuraCheck:Msg ("failed to export the aura from WeakAuras.")
			end

			--send the aura
			AuraCheck:SendPluginCommMessage(COMM_AURA_INSTALLREQUEST, AuraCheck.GetChannel(), _, _, AuraCheck:GetPlayerNameWithRealm(), auraName, false, dataCompressed)

			--fill the result table
			local myName = UnitName ("player") .. "-" .. GetRealmName()

			if (IsInRaid()) then
				for i = 1, GetNumGroupMembers() do
					local playerName, realmName = UnitFullName ("raid" .. i)
					if (realmName == "" or realmName == nil) then
						realmName = GetRealmName()
					end
					playerName = playerName .. "-" .. realmName

					AuraCheck.AuraState [playerName] = AuraCheck.AuraState [playerName] or {}
					if (myName == playerName) then
						AuraCheck.AuraState [playerName] [auraName] = RESPONSE_TYPE_HAVE
					else
						if (UnitIsConnected ("raid" .. i)) then
							AuraCheck.AuraState [playerName] [auraName] = RESPONSE_TYPE_WAITING
						else
							AuraCheck.AuraState [playerName] [auraName] = RESPONSE_TYPE_OFFLINE
						end
					end
				end

			elseif (IsInGroup()) then
				for i = 1, GetNumGroupMembers() - 1 do
					local playerName, realmName = UnitFullName ("party" .. i)
					if (realmName == "" or realmName == nil) then
						realmName = GetRealmName()
					end
					playerName = playerName .. "-" .. realmName
					
					AuraCheck.AuraState [playerName] = AuraCheck.AuraState [playerName] or {}
					if (myName == playerName) then
						AuraCheck.AuraState [playerName] [auraName] = RESPONSE_TYPE_HAVE
					else
						if (UnitIsConnected ("party" .. i)) then
							AuraCheck.AuraState [playerName] [auraName] = RESPONSE_TYPE_WAITING
						else
							AuraCheck.AuraState [playerName] [auraName] = RESPONSE_TYPE_OFFLINE
						end
					end
				end
			end
			
			--wait the results
			AuraCheck.last_data_request = time()
			--statusBar
			frame.statusBarWorking.lefttext = "sending..."
			frame.statusBarWorking:SetTimer(2)
			
			AuraCheck.UpdateAurasFillPanel()
		end

		local checkAuraButton = AuraCheck:CreateButton (frame, checkAuraFunc, 98, 18, "Check Aura", _, _, _, "checkAuraButton", _, _, AuraCheck:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), AuraCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		local shareAuraButton = AuraCheck:CreateButton (frame, shareAuraFunc, 98, 18, "Share Aura", _, _, _, "shareAuraButton", _, _, AuraCheck:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), AuraCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		
		checkAuraButton:SetPoint ("bottomleft", searchBox, "topleft", 0, 2)
		shareAuraButton:SetPoint ("left", checkAuraButton, "right", 2, 0)
		
		checkAuraButton:SetIcon ([[Interface\BUTTONS\UI-CheckBox-Check]], 16, 16, "overlay", {0, 1, 0, 28/32}, {1, 1, 1}, 2, 1, 0)
		shareAuraButton:SetIcon ([[Interface\BUTTONS\JumpUpArrow]], 14, 12, "overlay", {0, 1, 0, 32/32}, {1, 1, 1}, 2, 1, 0)
		
		checkAuraButton.tooltip = "Verifies if raid memebers has the selected aura installed."
		shareAuraButton.tooltip = "Send the selected aura to raid members.\nThey can accept the aura or decline.\nThe result is shown on the panel."
		
		local statusBar = AuraCheck:CreateBar (frame, LibStub:GetLibrary ("LibSharedMedia-3.0"):Fetch ("statusbar", "Iskar Serenity"), top_statusbar_width, 16, 100, "statusBarWorking", "AuraCheckerStatusBar")
		--statusBar:SetPoint ("topleft", frame, "topleft", 2, -431)
		statusBar:SetPoint ("left", showHistoryFrameButton, "right", 2, 0)
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

	--history frame
		local historyFrame = CreateFrame("frame", "AuraCheckerHistoryFrame", frame, "BackdropTemplate")
		historyFrame:SetPoint (unpack (framesPoint))
		historyFrame:SetSize (unpack (framesSize))
	
		--received auras scrollbar
		local uninstall_func = function (self, button, auraName)
--			print (self, button, auraName)
			
			if (not _G.WeakAuras) then
				return AuraCheck:Msg ("WeakAuras not found. AddOn is disabled?")
			end
			if (not WeakAuras.IsOptionsOpen) then
				return AuraCheck:Msg ("WeakAuras options not found. WeakAuras options is disabled?")
			end
			
			if (WeakAuras.IsOptionsOpen()) then
				WeakAurasFilterInput:SetText (auraName)
			else
				WeakAuras.OpenOptions (auraName)
			end
		end
		
		local updateHistoryList = function (self)
			self = self or AuraCheckerHistoryFrameHistoryScroll
			local auras = AuraCheck.db.installed_history
			if (not auras) then
				return
			end
			
			--> clean up auras
			for i = #auras, 1, -1 do
				local auraName = auras [i][1]
				if (not AuraCheck:GetWeakAuraTable (auraName)) then
					tremove (auras, i)
				end
			end

			--> update the scroll
			FauxScrollFrame_Update (self, #auras, 20, 19) --self, amt, amt frames, height of each frame
			local offset = FauxScrollFrame_GetOffset (self)

			for i = 1, 20 do
				local index = i + offset
				local button = self.Frames [i]
				local data = auras [index]

				if (data) then
					button.auraName:SetText (data [1])
					button.auraFrom:SetText (data [2])
					button.auraDate:SetText (date ("%m/%d/%y %H:%M:%S", data [3]))
					button.uninstallButton:SetClickFunction (uninstall_func, data [1])
					button:Show()
				else
					button:Hide()
				end
			end
		end

		local historyScroll = CreateFrame ("scrollframe", "AuraCheckerHistoryFrameHistoryScroll", historyFrame, "FauxScrollFrameTemplate, BackdropTemplate")
		historyScroll:SetPoint ("topleft", historyFrame, "topleft", 0, 0)
		historyScroll:SetSize (767, 503)
		DetailsFramework:ReskinSlider (historyScroll)

		historyScroll:SetScript ("OnVerticalScroll", function (self, offset) 
			FauxScrollFrame_OnVerticalScroll (self, offset, 20, updateHistoryList)
		end)
		
		function historyScroll.Update()
			updateHistoryList (historyScroll)
		end
		historyFrame:SetScript ("OnShow", function()
			updateHistoryList (historyScroll)
			historyScroll:Show()
		end)
		
		historyScroll.Frames = {}

		for i = 1, CONST_RESULTAURALIST_ROWS do
			local f = CreateFrame ("frame", "AuraCheckerHistoryFrameHistoryScroll_Button" .. i, historyScroll, "BackdropTemplate")
			f:SetPoint ("topleft", historyScroll, "topleft", 2, -(i-1)*19)
			f:SetSize (571, 18)
			f:SetBackdrop (backdrop)
			f:SetBackdropColor (unpack (backdropColor))
			
			local uninstallButton = AuraCheck:CreateButton (f, uninstall_func, 12, 18)
			uninstallButton:SetIcon ([[Interface\Glues\LOGIN\Glues-CheckBox-Check]])
			
			local auraName = f:CreateFontString (nil, "overlay", "GameFontNormal")
			local auraFrom = f:CreateFontString (nil, "overlay", "GameFontNormal")
			local auraDate = f:CreateFontString (nil, "overlay", "GameFontNormal")
			AuraCheck:SetFontSize (auraName, 10)
			AuraCheck:SetFontColor (auraName, "white")
			AuraCheck:SetFontSize (auraFrom, 10)
			AuraCheck:SetFontColor (auraFrom, "white")
			AuraCheck:SetFontSize (auraDate, 10)
			AuraCheck:SetFontColor (auraDate, "white")

			uninstallButton:SetPoint ("left", f, "left", 2, 0)
			auraName:SetPoint ("left", f, "left", 26, 0)
			auraFrom:SetPoint ("left", f, "left", 190, 0)
			auraDate:SetPoint ("left", f, "left", 360, 0)
			
			f.auraName = auraName
			f.auraFrom = auraFrom
			f.auraDate = auraDate
			f.uninstallButton = uninstallButton
			tinsert (historyScroll.Frames, f)
		end
	
	
	--all frames built
	AuraCheck.ShowAurasPanel()
	
	AuraCheck.UpdateAurasFillPanel (fillPanel)
	auraScroll.RefreshMe()
	updateHistoryList (historyScroll)
	
	frame:SetScript("OnShow", function()
		AuraCheck.UpdateAurasFillPanel(fillPanel)
	end)
	
end

RA:InstallPlugin(AuraCheck.displayName, "RAAuraCheck", AuraCheck, default_config)

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function AuraCheck.SendAuraStatus(auraName)
	--> get weakauras global
	local WeakAuras_Object, WeakAuras_SavedVar = AuraCheck:GetWeakAuras2Object()
	if (WeakAuras_Object) then --> the user has weakauras installed
		local isInstalled = AuraCheck:GetWeakAuraTable(auraName)
		if (isInstalled) then
			local semver = isInstalled.semver
			if (semver) then
				local removeDots = semver:gsub("%.", "")
				if (removeDots and removeDots ~= "0") then
					semver = tonumber(removeDots)
				end
			end
			AuraCheck:SendPluginCommMessage(COMM_AURA_CHECKRECEIVED, AuraCheck.GetChannel(), _, _, AuraCheck:GetPlayerNameWithRealm(), auraName, 1)
		else
			AuraCheck:SendPluginCommMessage(COMM_AURA_CHECKRECEIVED, AuraCheck.GetChannel(), _, _, AuraCheck:GetPlayerNameWithRealm(), auraName, 0)
		end
	else
		--> the user don't have weakauras installed
		AuraCheck:SendPluginCommMessage(COMM_AURA_CHECKRECEIVED, AuraCheck.GetChannel(), _, _, AuraCheck:GetPlayerNameWithRealm(), auraName, -1)
	end
end

function AuraCheck.IsValidResultIndex (index)
	if (valid_results [index]) then
		return true
	end
end

function AuraCheck.GetChannel()
	if (IsInRaid()) then
		return "RAID-NOINSTANCE"
	elseif (IsInGroup()) then
		return "PARTY-NOINSTANCE"
	else
		return "RAID-NOINSTANCE"
	end
end

function AuraCheck.PluginCommReceived(sourceName, prefix, sourcePluginVersion, playerName, auraName, auraState, auraString)
	--print ("COMM", prefix, playerName, auraName, auraState, auraString)
	playerName = sourceName

	if (type(playerName) ~= "string" or type(auraName) ~= "string") then
		return
	end

	--leader is requesting an aura check
	if (prefix == COMM_AURA_CHECKREQUEST) then
		--check if who sent is indeed the leader or assistant
		if (AuraCheck:UnitIsRaidLeader(playerName) or RA:UnitHasAssist(playerName)) then
			--send the aura state
			AuraCheck.SendAuraStatus(auraName)
		end

	--some raid member sent the aura status
	elseif (prefix == COMM_AURA_CHECKRECEIVED) then
		--is a valid result?
		if (type (auraState) == "number") then
			if (AuraCheck.IsValidResultIndex(auraState)) then
				--add the user to the result list
				AuraCheck.AuraState [playerName] = AuraCheck.AuraState [playerName] or {}
				AuraCheck.AuraState [playerName] [auraName] = auraState
				--update the panel if it is already created and is shown
				AuraCheck.UpdateAurasFillPanel()
			end
		end

	--leader is requesting an aura install
	elseif (prefix == COMM_AURA_INSTALLREQUEST) then
		--check if who sent is indeed the leader
		if (not AuraCheck:UnitIsRaidLeader (playerName) and not RA:UnitHasAssist (playerName)) then
			return
		end

		--check if the sender isnt 'me'
		if (UnitIsUnit(sourceName, "player")) then
			AuraCheck:SendPluginCommMessage(COMM_AURA_CHECKRECEIVED, AuraCheck.GetChannel(), _, _, AuraCheck:GetPlayerNameWithRealm(), auraName, 1)
			return
		end

		--disabling this
		if (false and AuraCheck.db.only_from_guild) then
			if (not IsInGuild()) then
				--send a packet notifying about the no guild
				AuraCheck:SendPluginCommMessage (COMM_AURA_CHECKRECEIVED, AuraCheck.GetChannel(), _, _, AuraCheck:GetPlayerNameWithRealm(), auraName, RESPONSE_TYPE_NOSAMEGUILD)
				return
			end
			if (not AuraCheck:IsGuildFriend (playerName)) then
				--send a packet notify isnt from the same guild
 				AuraCheck:SendPluginCommMessage (COMM_AURA_CHECKRECEIVED, AuraCheck.GetChannel(), _, _, AuraCheck:GetPlayerNameWithRealm(), auraName, RESPONSE_TYPE_NOSAMEGUILD)
				return
			end
		end

		if (type(auraString) == "string") then
			--check for trusted - auto install if trusted
			if (AuraCheck.db.auto_install_from_trusted) then
				if (AuraCheck.IsTrusted(playerName)) then
					AuraCheck.InstallAura(auraName, playerName, auraString, time())
					return
				end
			end

			--ask to install
			AuraCheck.WaitingAnswer = AuraCheck.WaitingAnswer or {}
			tinsert(AuraCheck.WaitingAnswer, {auraName, playerName, auraString, time()})

			AuraCheck.AskToInstall()
		end
	end
end

function AuraCheck.InstallAura(auraName, playerName, auraString, time)
	local auraTable

	--decompress the aura table
	local LibDeflate = LibStub:GetLibrary("LibDeflate")
	local dataCompressed = LibDeflate:DecodeForWoWAddonChannel(auraString)
	if (dataCompressed) then
		local dataSerialized = LibDeflate:DecompressDeflate(dataCompressed)
		if (dataSerialized) then
			local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0")
			local okay, data = LibAceSerializer:Deserialize(dataSerialized)
			if (okay) then
				auraTable = data
			end
		end
	end

	if (auraTable) then
		--rebuild the aura
		local mainAura = tremove(auraTable, 1)
		local childrenTable = auraTable

		--list of icons of the children
		local icons = {}

		--check if there's children
		if (#childrenTable >= 1) then
			for i = 1, #childrenTable do
				local child = childrenTable[i]
				icons[i] = child.displayIcon
			end
		else
			childrenTable = nil
			icons = nil
		end

		--delete auras which already exists
		--note: this is too dangerous, need to have another way to override duplications
		local alreayHaveAura = WeakAuras.GetData(auraName)
		if (alreayHaveAura) then
			--check for children first
			--[=
			if (childrenTable and #childrenTable >= 1) then
				for i = 1, #childrenTable do
					local child = childrenTable[i]
					local childId = child.id
					local childExists = WeakAuras.GetData(childId)
					if (childExists) then
						local copy = DetailsFramework.table.copytocompress({}, childExists)
						WeakAuras.Delete(copy)
					end
				end
			end

			local copy = DetailsFramework.table.copytocompress({}, mainAura)
			copy.controlledChildren = nil
			WeakAuras.Delete(copy)
			--]=]
		end

		local auraObject = {
			d = mainAura, --d = data
			c = childrenTable, --c = children
			i = mainAura.displayIcon, --i = icon
			a = icons, --a = icons
			v = mainAura.internalVersion, --v = version
		}

		WeakAuras.Import(auraObject)
		WeakAurasTooltipImportButton:Click()

		tinsert(AuraCheck.db.installed_history, {auraName, playerName, time})
		AuraCheck:SendPluginCommMessage(COMM_AURA_CHECKRECEIVED, AuraCheck.GetChannel(), _, _, AuraCheck:GetPlayerNameWithRealm(), auraName, 1)
	end
end

function AuraCheck.DeclineAura(auraName, playerName, auraString, time)
	--> check if already is installed
	if (AuraCheck:GetWeakAuraTable (auraName)) then
		AuraCheck:SendPluginCommMessage (COMM_AURA_CHECKRECEIVED, AuraCheck.GetChannel(), _, _, AuraCheck:GetPlayerNameWithRealm(), auraName, 3)
	else
		AuraCheck:SendPluginCommMessage (COMM_AURA_CHECKRECEIVED, AuraCheck.GetChannel(), _, _, AuraCheck:GetPlayerNameWithRealm(), auraName, 2)
	end
end

function AuraCheck.CreateFlash(frame, duration, amount, r, g, b)
	--defaults
	duration = duration or 0.15
	amount = amount or 1
	
	if (not r) then
		r, g, b = 1, 1, 1
	else
		r, g, b = RA:ParseColors (r, g, b)
	end

	--create the flash frame
	local f = CreateFrame("frame", "RaidAssistAuraCheckFlashAnimationFrame".. math.random (1, 100000000), frame, "BackdropTemplate")
	f:SetFrameLevel(frame:GetFrameLevel()+1)
	f:SetAllPoints()
	f:Hide()

	--create the flash texture
	local t = f:CreateTexture("RaidAssistAuraCheckFlashAnimationTexture".. math.random (1, 100000000), "artwork")
	t:SetColorTexture (r, g, b)
	t:SetAllPoints()
	t:SetBlendMode("ADD")
	t:Hide()
	
	local OnPlayCustomFlashAnimation = function (animationHub)
		animationHub:GetParent():Show()
		animationHub.Texture:Show()
	end
	local OnStopCustomFlashAnimation = function (animationHub)
		animationHub:GetParent():Hide()
		animationHub.Texture:Hide()
	end
	
	--create the flash animation
	local animationHub = RA:CreateAnimationHub (f, OnPlayCustomFlashAnimation, OnStopCustomFlashAnimation)
	animationHub.AllAnimations = {}
	animationHub.Parent = f
	animationHub.Texture = t
	animationHub.Amount = amount
	
	for i = 1, amount * 2, 2 do
		local fadeIn = RA:CreateAnimation (animationHub, "ALPHA", i, duration, 0, 1)
		local fadeOut = RA:CreateAnimation (animationHub, "ALPHA", i + 1, duration, 1, 0)
		tinsert (animationHub.AllAnimations, fadeIn)
		tinsert (animationHub.AllAnimations, fadeOut)
	end
	
	return animationHub
end

function AuraCheck.AskToInstall()
	if (not AuraCheck.AskFrame) then
		AuraCheck.AskFrame = RA:CreateSimplePanel(UIParent, 380, 130, "Raid Assist: WA Sharer", "RaidAssistWAConfirmation")
		AuraCheck.AskFrame:SetSize (380, 100)
		AuraCheck.AskFrame.DontRightClickClose = true
		AuraCheck.AskFrame:Hide()

		AuraCheck.AskFrame.accept_text = AuraCheck:CreateLabel (AuraCheck.AskFrame, "", AuraCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		AuraCheck.AskFrame.accept_text:SetPoint (16, -28)

		AuraCheck.AskFrame.aura_name = AuraCheck:CreateLabel (AuraCheck.AskFrame, "", AuraCheck:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		AuraCheck.AskFrame.aura_name:SetPoint (16, -46)

		local accept_aura = function (self, button, t)
			AuraCheck.InstallAura (unpack (t))
			AuraCheck.AskFrame:Hide()
			AuraCheck.AskToInstall()
		end
		local decline_aura = function (self, button, t)
			AuraCheck.DeclineAura (unpack (t))
			AuraCheck.AskFrame:Hide()
			AuraCheck.AskToInstall()
		end

		AuraCheck.AskFrame.Close:HookScript("OnClick", function(self)
			decline_aura(_, _, self.param1)
		end)

		AuraCheck.AskFrame.accept_button = AuraCheck:CreateButton (AuraCheck.AskFrame, accept_aura, 100, 20, "Accept", -1, nil, nil, nil, nil, nil, RA:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE"))
		AuraCheck.AskFrame.decline_button = AuraCheck:CreateButton (AuraCheck.AskFrame, decline_aura, 100, 20, "Decline", -1, nil, nil, nil, nil, nil, RA:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE"))

		AuraCheck.AskFrame.accept_button:SetPoint ("bottomright", AuraCheck.AskFrame, "bottomright", -14, 11)
		AuraCheck.AskFrame.decline_button:SetPoint ("bottomleft", AuraCheck.AskFrame, "bottomleft", 14, 11)

		AuraCheck.AskFrame.Flash = AuraCheck.CreateFlash (AuraCheck.AskFrame)
	end

	if (AuraCheck.AskFrame:IsShown()) then
		return
	end

	local nextAura = tremove (AuraCheck.WaitingAnswer)

	if (nextAura) then
		rawset (AuraCheck.AskFrame.accept_button, "param1", nextAura)
		rawset (AuraCheck.AskFrame.decline_button, "param1", nextAura)

		AuraCheck.AskFrame.aura_name.text = nextAura [1]
		AuraCheck.AskFrame.accept_text.text = "|cFFFFAA00" .. nextAura [2] .. " sent an aura:|r"

		AuraCheck.AskFrame.Close.param1 = nextAura

		AuraCheck.AskFrame:SetPoint ("center", UIParent, "center", 0, 150)

		AuraCheck.AskFrame:Show()
		AuraCheck.AskFrame.Flash:Play()
	end
end

function AuraCheck.IsTrusted(playerName)
	--is on a guild?
	if (not IsInGuild()) then
		return
	end

	--> is inside a raid?
	local _, instanceType = IsInInstance()
	if (instanceType ~= "raid") then
		return
	end

	--> who sent is the raid leader or assistant?
	if (not AuraCheck:UnitIsRaidLeader(playerName) and not RA:UnitHasAssist(playerName)) then
		return
	end

	if (not RA:IsGuildFriend(playerName)) then
		return
	end

	return true
end