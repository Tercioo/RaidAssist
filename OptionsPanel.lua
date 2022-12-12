
local RA = _G.RaidAssist
local _
local DF = DetailsFramework

--/run RaidAssist.OpenMainOptions()

local CONST_OPTIONS_FRAME_WIDTH = 1080
local CONST_OPTIONS_FRAME_HEIGHT = 720

local CONST_MENU_SCROLL_WIDTH = 170
local CONST_MENU_SCROLL_HEIGHT = 616
local CONST_MENU_BUTTON_WIDTH = 166
local CONST_MENU_BUTTON_HEIGHT = 30

local CONST_MENU_MAX_BUTTONS = 25
local CONST_MENU_STARTPOS_X = 5
local CONST_MENU_STARTPOS_Y = -30

local CONST_OPTIONSPANEL_STARTPOS_X = 208
local CONST_OPTIONSPANEL_STARTPOS_Y = -36

local CONST_MENU_FONT_SIZE = 12

local allButtons = {}
local pluginIdToIndex = {}
local pluginIndexToObject = {}

function RA.OpenMainOptionsByPluginIndex(pluginIndex)
	if (not allButtons[1]) then
		RA.OpenMainOptions()
	end

	RA.OpenMainOptions()
	allButtons[pluginIndex]:Click()
	RA.UpdateKeybindToPlugin(pluginIndexToObject[pluginIndex])
end

function RA.OpenMainOptions(command, value)

	local plugin = command

	--if a plugin object has been passed, open the options panel for it
	if (_G.RaidAssistOptionsPanel) then
		if (plugin) then

			if (type(plugin) == "string") then
				local pluginIndex = pluginIdToIndex[plugin]
				if (pluginIndex) then
					RA.OpenMainOptionsByPluginIndex(pluginIndex)
					RaidAssistOptionsPanel:Show()
					return
				end
			else
				RA.OpenMainOptionsForPlugin(plugin)
				RaidAssistOptionsPanel:Show()
				return
			end
		end

		RaidAssistOptionsPanel:Show()
		return
	end

	if (type(plugin) == "string") then
		plugin = nil
	end

	RA.db.profile.options_panel = RA.db.profile.options_panel or {}
	RA.db.profile.options_panel.libwindow = RA.db.profile.options_panel.libwindow or {}

	local f = RA:CreateStandardFrame(UIParent, CONST_OPTIONS_FRAME_WIDTH, CONST_OPTIONS_FRAME_HEIGHT, "Raid Assist (|cFFFFAA00/raa|r)", "RaidAssistOptionsPanel")
	f:SetBackdropBorderColor(1, .7, 0, .8)
	f:SetBackdropColor(0, 0, 0, 1)
	DetailsFramework:ApplyStandardBackdrop(f, 0.9)
	f:SetScript("OnMouseDown", nil)
	f:SetScript("OnMouseUp", nil)

	DF:CreateScaleBar(f, RA.db.profile.addon.scale_bar)
	--f:SetScale(RA.db.profile.addon.scale_bar.scale)
	DF:CreateRightClickToClose(f)

	local LibWindow = LibStub("LibWindow-1.1")
	LibWindow.RegisterConfig(f, RA.db.profile.options_panel.libwindow)
	LibWindow.RestorePosition(f)
	LibWindow.MakeDraggable(f)

	f.AllOptionsButtons = {}
	f.AllOptionsPanels = {}
	f.TrivialPluginsButton = {}

	--create the footer and attach it into the bottom of the main frame
		local statusBar = CreateFrame ("frame", nil, f, "BackdropTemplate")
		statusBar:SetPoint ("bottomleft", f, "bottomleft")
		statusBar:SetPoint ("bottomright", f, "bottomright")
		statusBar:SetHeight (20)
		DetailsFramework:ApplyStandardBackdrop (statusBar)
		statusBar:SetAlpha (0.8)
		DetailsFramework:BuildStatusbarAuthorInfo (statusBar)

	--keybind to open the panel
		RA.CreateHotkeyFrame(f)

	--create the left menu
		--when the player select a plugin in the plugin scroll
		local onSelectPlugin =  function (button, mouse, plugin)
			--reset
			f:ResetButtonsAndPanels()

			--make the button change its text color
			plugin.textcolor = "orange"

			--show the panel for the plugin
			if (plugin.OnShowOnOptionsPanel) then
				plugin.OnShowOnOptionsPanel()
				plugin.OptionsPanel:Show()
			end

			for i, thisButton in ipairs(allButtons) do
				DetailsFramework:ApplyStandardBackdrop(thisButton)
			end

			for i, thisButton in ipairs(allButtons) do
				DetailsFramework:ApplyStandardBackdrop(thisButton)
			end

			button:SetBackdropColor(.75, .75, .75, .9)

			RA.UpdateKeybindToPlugin(plugin)
		end

		--change the selected plugin from inside plugins
		RA.OpenMainOptionsForPlugin = function (plugin)
			return onSelectPlugin (nil, nil, plugin)
		end

	--hide all panels for all addons
		function f:ResetButtonsAndPanels()
			for _, panel in pairs(f.AllOptionsPanels) do
				panel:Hide()
			end

			for _, button in pairs(f.AllOptionsButtons) do
				button.textcolor = "white"
			end

			for _, button in pairs(f.TrivialPluginsButton) do
				button.textcolor = {.9, .9, .9, .6}
			end
		end

	--load the plugins
		local plugins_list = RA:GetSortedPluginsInPriorityOrder()
		local plugins_sorted_list = {}
		local bossmods_sorted_list = {}

		--build a table to hold plugins
		for _, plugin in pairs (plugins_list) do
			if (not plugin.IsBossMod) then
				plugin.db.menu_priority = plugin.db.menu_priority or 1
				tinsert(plugins_sorted_list, plugin)

			elseif (plugin.IsBossMod) then
				plugin.db.menu_priority = plugin.db.menu_priority or 1
				tinsert(bossmods_sorted_list, plugin)
			end
		end

		table.sort(plugins_sorted_list, function (plugin1, plugin2) return ( (plugin1 and plugin1.db.menu_priority) or 1) > ( (plugin2 and plugin2.db.menu_priority) or 1) end)
		table.sort(bossmods_sorted_list, function (plugin1, plugin2) return ( (plugin1 and plugin1.db.menu_priority) or 1) > ( (plugin2 and plugin2.db.menu_priority) or 1) end)

	--create the menu scroll box
		--this function refreshes the scroll options
		local refreshLeftMenuScrollBox = function(self, data, offset, totalLines)
			--update the scroll
			for i = 1, totalLines do
				local index = i + offset
				local pluginObject = data [index]
				if (pluginObject) then
					--get the data
					local iconTexture, iconTexcoord, text, overlayColor = pluginObject.menu_text(pluginObject)

					local r, g, b, a = DF:ParseColors(overlayColor or "white")

					--update the line
					local button = self:GetLine(i)
					button:SetText (text)

					pluginIdToIndex[pluginObject.pluginId] = index
					pluginIndexToObject[index] = pluginObject

					button:SetClickFunction(onSelectPlugin, pluginObject)

					if (iconTexcoord) then
						button:SetIcon(iconTexture, 18, 18, "overlay", {iconTexcoord.l, iconTexcoord.r, iconTexcoord.t, iconTexcoord.b}, {r, g, b, a}, 5, 2)
					else
						button:SetIcon(iconTexture, 18, 18, "overlay", {0, 1, 0, 1}, {r, g, b, a}, 4, 2)
					end

					if (pluginObject.IsDisabled) then
						button:Disable()
					else
						button:Enable()
					end

					button:Show()
				end
			end

			RA.RefreshTrivialPluginsMenu()
		end

		--create the left menu scroll
		local createMenuScrollBoxLine = function (parent, index)
			local newButton = RA:CreateButton (parent, onSelectPlugin, CONST_MENU_BUTTON_WIDTH, CONST_MENU_BUTTON_HEIGHT, "", 0, nil, nil, nil, nil, 1, button_template, button_text_template)
			DetailsFramework:ApplyStandardBackdrop(newButton)
			newButton.textsize = CONST_MENU_FONT_SIZE
			newButton:SetPoint("topleft", parent, "topleft", 2, -1 + ((index - 1) * -CONST_MENU_BUTTON_HEIGHT))
			allButtons[#allButtons+1] = newButton
			return newButton
		end

		--add all plugins registered into the all plugins list
		--this list will be used to update the left menu
		local allPlugin = {}
		for _, plugin in pairs (plugins_sorted_list) do
			allPlugin[ #allPlugin + 1] = plugin
		end

		for _, plugin in pairs (bossmods_sorted_list) do
			allPlugin[ #allPlugin + 1] = plugin
		end

	--create the options frame for each plugin
		for i = 1, #allPlugin do
			local plugin = allPlugin[i]

			local optionsFrame = CreateFrame("frame", "RaidAssistOptionsPanel" .. (plugin.pluginname or math.random (1, 1000000)), f, "BackdropTemplate")
			optionsFrame:Hide()
			optionsFrame:SetSize (1, 1)
			optionsFrame:SetPoint ("topleft", f, "topleft", CONST_OPTIONSPANEL_STARTPOS_X, CONST_OPTIONSPANEL_STARTPOS_Y)

			plugin.OptionsPanel = optionsFrame
			f.AllOptionsPanels[ #f.AllOptionsPanels + 1 ] = optionsFrame
		end

		local menuScrollBox = DF:CreateScrollBox(f, "$parentScrollBox", refreshLeftMenuScrollBox, allPlugin, CONST_MENU_SCROLL_WIDTH, CONST_MENU_SCROLL_HEIGHT, CONST_MENU_MAX_BUTTONS, CONST_MENU_BUTTON_HEIGHT)
		DF:ReskinSlider(menuScrollBox)
		menuScrollBox:SetPoint("topleft", f, "topleft", CONST_MENU_STARTPOS_X, CONST_MENU_STARTPOS_Y)

		--create the scrollbox lines
		for i = 1, CONST_MENU_MAX_BUTTONS do
			menuScrollBox:CreateLine(createMenuScrollBoxLine)
		end

		--create trivial plugins menu
		for i = 1, 5 do
			local newButton = RA:CreateButton(menuScrollBox, onSelectPlugin, CONST_MENU_BUTTON_WIDTH, CONST_MENU_BUTTON_HEIGHT, "", 0, nil, nil, nil, nil, 1)
			DetailsFramework:ApplyStandardBackdrop(newButton)
			newButton.textsize = CONST_MENU_FONT_SIZE
			newButton:SetPoint("bottomleft", menuScrollBox, "bottomleft", 1, ((i - 1) * CONST_MENU_BUTTON_HEIGHT))
			f.TrivialPluginsButton[#f.TrivialPluginsButton+1] = newButton
			allButtons[#allButtons+1] = newButton
		end

		local createOptionsFrameForTrivialPlugin = function(plugin)
			local optionsFrame = CreateFrame("frame", "RaidAssistOptionsPanel" .. (plugin.pluginname or math.random (1, 1000000)), f, "BackdropTemplate")
			optionsFrame:Hide()
			optionsFrame:SetSize(1, 1)
			optionsFrame:SetPoint("topleft", f, "topleft", CONST_OPTIONSPANEL_STARTPOS_X, CONST_OPTIONSPANEL_STARTPOS_Y)

			plugin.OptionsPanel = optionsFrame
			f.AllOptionsPanels[#f.AllOptionsPanels + 1] = optionsFrame
		end

		function RA.RefreshTrivialPluginsMenu()
			local pluginsArray = {}
			for pluginName, pluginObject in pairs(RA.pluginsTrivial) do
				pluginsArray[#pluginsArray+1] = {pluginName, pluginObject}
				if (not pluginObject.OptionsPanel) then
					createOptionsFrameForTrivialPlugin(pluginObject)
				end
			end

			table.sort(pluginsArray, function(t1, t2) return t1[1] < t2[1] end)

			for i = 1, 5 do
				local button = f.TrivialPluginsButton[i]
				button:Hide()
			end

			for i = 1, #pluginsArray do
				local index = i
				local pluginTable = pluginsArray[index]

				local pluginName = pluginTable[1]
				local pluginObject = pluginTable[2]

				if (pluginObject) then
					--get the data
					local iconTexture, iconTexcoord, text, textColor = pluginObject.menu_text(pluginObject)

					--update the line
					local button = f.TrivialPluginsButton[i]
					button:Show()
					button:SetText(text)

					--pluginIdToIndex[pluginObject.pluginId] = index
					--pluginIndexToObject[index] = pluginObject

					button:SetClickFunction(onSelectPlugin, pluginObject)

					if (iconTexcoord) then
						button:SetIcon(iconTexture, 18, 18, "overlay", {iconTexcoord.l, iconTexcoord.r, iconTexcoord.t, iconTexcoord.b}, nil, 5, 2)
					else
						button:SetIcon(iconTexture, 18, 18, "overlay", {0, 1, 0, 1}, nil, 4, 2)
					end

					if (pluginObject.IsDisabled) then
						button:Disable()
					else
						button:Enable()
					end

					button:Show()
				end
			end
		end

		menuScrollBox:Refresh()

	--reset everything to start
		f:ResetButtonsAndPanels()

		--if a plugin requested to open its options
		if (plugin) then
			onSelectPlugin(nil, nil, plugin)
		end

		if (command) then
			local pluginIndex = pluginIdToIndex[command]
			if (pluginIndex) then
				RA.OpenMainOptionsByPluginIndex(pluginIndex)
				return
			end
		end

		--auto open a plugin after /raa
		local openAtSection = 1
		allButtons[openAtSection]:Click()
		RA.UpdateKeybindToPlugin(pluginIndexToObject[openAtSection])
end

function RA.CreateHotkeyFrame(f)
	local currentKeyBind = RA.DATABASE.OptionsKeybind

	local keyBindListener = CreateFrame ("frame", "RaidAssistBindListenerFrame", f, "BackdropTemplate")
	keyBindListener.IsListening = false

	local enterKeybindFrame = CreateFrame ("frame", nil, keyBindListener, "BackdropTemplate")
	enterKeybindFrame:SetFrameStrata ("tooltip")
	enterKeybindFrame:SetSize (200, 60)
	enterKeybindFrame:SetBackdrop ({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1})
	enterKeybindFrame:SetBackdropColor (0, 0, 0, 1)
	enterKeybindFrame:SetBackdropBorderColor (1, 1, 1, 1)
	enterKeybindFrame.text = RA:CreateLabel (enterKeybindFrame, "- Press a keyboard key to bind.\n- Press escape to clear.\n- Click again to cancel.", 11, "orange")
	enterKeybindFrame.text:SetPoint ("center", enterKeybindFrame, "center")
	enterKeybindFrame:Hide()

	local ignoredKeys = {
		["LSHIFT"] = true,
		["RSHIFT"] = true,
		["LCTRL"] = true,
		["RCTRL"] = true,
		["LALT"] = true,
		["RALT"] = true,
		["UNKNOWN"] = true,
	}

	local mouseKeys = {
		["LeftButton"] = "type1",
		["RightButton"] = "type2",
		["MiddleButton"] = "type3",
		["Button4"] = "type4",
		["Button5"] = "type5",
	}

	local keysToMouse = {
		["type1"] = "LeftButton",
		["type2"] = "RightButton",
		["type3"] = "MiddleButton",
		["type4"] = "Button4",
		["type5"] = "Button5",
	}

	local registerKeybind = function (self, key)

		local pluginId = enterKeybindFrame.pluginObject.pluginId

		if (ignoredKeys [key]) then
			return

		elseif (key == "ESCAPE" ) then
			--reset the key
			enterKeybindFrame:Hide()
			keyBindListener.IsListening = false
			keyBindListener:SetScript("OnKeyDown", nil)

			local currentKeybindForPlugin = RA.GetKeybindForPlugin(pluginId)
			if (currentKeybindForPlugin) then
				SetBinding(currentKeybindForPlugin)
				RA:Msg("do a /reload if this bind was an override.")
			end

			RA.RegisterPluginKeybind(pluginId)
			RA:RefreshMacros()

			f.SetKeybindButton.text = "- click to set -"
			return

		elseif (mouseKeys[key] or keysToMouse[key]) then
			enterKeybindFrame:Hide()
			keyBindListener.IsListening = false
			keyBindListener:SetScript("OnKeyDown", nil)
			return
		end

		local bind = (IsShiftKeyDown() and "SHIFT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsAltKeyDown() and "ALT-" or "")
		bind = bind .. key

		RA.RegisterPluginKeybind(pluginId, bind)
		RA:RefreshMacros()

		f.SetKeybindButton.text = bind

		keyBindListener.IsListening = false
		keyBindListener:SetScript ("OnKeyDown", nil)
		enterKeybindFrame:Hide()
	end

	local setKeybind = function(self, button, keybindIndex)
		if (keyBindListener.IsListening) then
			local key = mouseKeys [button] or button
			return registerKeybind(keyBindListener, key)
		end

		keyBindListener.IsListening = true
		keyBindListener.keybindIndex = keybindIndex
		keyBindListener:SetScript("OnKeyDown", registerKeybind)
		GameCooltip:Hide()

		enterKeybindFrame:Show()
		enterKeybindFrame:SetPoint ("bottom", self, "top")
	end

	local setKeybindButton = RA:CreateButton(f, setKeybind, CONST_MENU_BUTTON_WIDTH, CONST_MENU_BUTTON_HEIGHT, "", _, _, _, "SetKeybindButton", _, 0, RA:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE"), RA:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	setKeybindButton:SetPoint("bottomleft", f, "bottomleft", 5, 25)
	setKeybindButton:SetClickFunction(setKeybind, nil, nil, "left")
	setKeybindButton:SetClickFunction(setKeybind, nil, nil, "right")
	setKeybindButton.text = currentKeyBind and currentKeyBind ~= "" and currentKeyBind or "- click to set -"
	setKeybindButton.tooltip = "Set up a keybind to open the options panel."

	local keybindText = RA:CreateLabel(f, "Open Options Keybind:")
	keybindText:SetPoint("bottomleft", setKeybindButton, "topleft", 0, 2)
	keybindText:SetJustifyH("left")
	keybindText.fontsize = 11

	function RA.UpdateKeybindToPlugin(pluginObject)
		keybindText.text = "Open " .. pluginObject.displayName

		local pluginKeybinds = RA.DATABASE.PluginKeybinds
		if (not pluginKeybinds) then
			pluginKeybinds = {}
			RA.DATABASE.PluginKeybinds = pluginKeybinds
		end

		local currentKeybind = pluginKeybinds[pluginObject.pluginId]
		if (not currentKeybind) then
			setKeybindButton.text = "Set Keybind"
			setKeybindButton.fontsize = 16
			setKeybindButton.fontcolor = "silver"

		else
			setKeybindButton.text = currentKeybind
			setKeybindButton.fontsize = 16
			setKeybindButton.fontcolor = "yellow"
		end

		enterKeybindFrame.pluginObject = pluginObject
	end
end