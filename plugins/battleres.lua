
local RA = _G.RaidAssist
local L = LibStub ("AceLocale-3.0"):GetLocale ("RaidAssistAddon")
local _ 
local default_priority = 10

--battle res default config
local default_config = {
	enabled = false,
	menu_priority = 3,
	panel_show_res = true,
	panel_locked = false,
	panel_width = 130,
	panel_height = 30,
	text_font = "Accidental Presidency",
	text_size = 10,
	text_color = {r=1, g=1, b=1, a=1},
	text_anchor = "center",
	background_color = {r=0, g=0, b=0, a=0.3},
	background_border_color = {r=0, g=0, b=0, a=0.3},
}

local icon_texcoord = {l=0, r=32/64, t=0, b=33/64}
local text_color_enabled = {r=1, g=1, b=1, a=1}
local text_color_disabled = {r=0.5, g=0.5, b=0.5, a=1}
local rebirth_spellid = 20484

local BattleRes = {version = "v0.1", pluginname = "BattleRes", pluginId = "BTRS", displayName = L["S_PLUGIN_BRES_NAME"]}
_G ["RaidAssistBattleRes"] = BattleRes

BattleRes.menu_text = function (plugin)
	if (BattleRes.db.enabled) then
		return [[Interface\WorldStateFrame\SkullBones]], icon_texcoord, L["S_PLUGIN_BRES_NAME"], text_color_enabled
	else
		return [[Interface\WorldStateFrame\SkullBones]], icon_texcoord, L["S_PLUGIN_BRES_NAME"], text_color_disabled
	end
end

BattleRes.menu_popup_show = function (plugin, ct_frame, param1, param2)
	RA:AnchorMyPopupFrame (BattleRes)
end

BattleRes.menu_popup_hide = function (plugin, ct_frame, param1, param2)
	BattleRes.popup_frame:Hide()
end

BattleRes.menu_on_click = function (plugin)
	RA.OpenMainOptions (BattleRes)
end

BattleRes.OnInstall = function (plugin)
	--popup frame -- this is the frame shown when hover over the battle res button on Raid Assist menu.
	local popup_frame = BattleRes.popup_frame
	popup_frame:SetSize (RA.default_small_popup_width, RA.default_small_popup_height)
	local label = RA:CreateLabel (popup_frame, L["S_PLUGIN_BRES_POPUP_DESC"], BattleRes:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
	label:SetPoint ("center", popup_frame, "center")
	label.width = 130
	label.height = 30
	
	BattleRes.db.menu_priority = default_priority

	--options frame
	local options_frame = BattleRes.main_frame
	RA:SetAsOptionsPanel (options_frame)
	options_frame:SetSize (470, 200)
	
	BattleRes.ResRecently = {}

	-- res frame for the encounter
	local bres_frame = RA:CreateCleanFrame (BattleRes, "BattleResResFrame")
	BattleRes.bres_frame = bres_frame
	bres_frame:SetSize (BattleRes.db.panel_width, BattleRes.db.panel_height)

	BattleRes.available_res_label = RA:CreateLabel (bres_frame, "0", BattleRes:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
	BattleRes.done_res_label = RA:CreateLabel (bres_frame)

	local add_ress = function (who_name, target_name)
		BattleRes.ResRecently [target_name] = nil
	
		local text = BattleRes.done_res_label:GetText()
		local _, resser_class = UnitClass (who_name)
		local _, target_class = UnitClass (target_name)
		BattleRes.done_res_label:SetText ("" .. (text or "") .. "|c" .. (RAID_CLASS_COLORS [resser_class] and RAID_CLASS_COLORS [resser_class].colorStr or "FFFFFFFF") .. RA:RemoveRealName (who_name) .. "|r -> " .. "|c" .. (RAID_CLASS_COLORS [target_class] and RAID_CLASS_COLORS [target_class].colorStr or "FFFFFFFF") .. RA:RemoveRealName (target_name) .. "|r\n")
		
		local h = bres_frame: GetHeight()
		bres_frame:SetHeight (h+BattleRes.db.text_size+3)
		BattleRes.done_res_label:SetHeight (200)
		BattleRes.done_res_label:SetWidth (150)	
	end
	
	local on_ress = function (time, token, hidding, who_serial, who_name, who_flags, who_flags2, target_serial, target_name, target_flags, target_flags2, spellid, spellname)
		if (not BattleRes.ResRecently [target_name]) then
			BattleRes.ResRecently [target_name] = who_name
		end
	end
	
	local tick = function()
		-- /dump GetSpellCharges (20484)
		local charges, maxCharges, started, duration = GetSpellCharges (rebirth_spellid)
		if (charges) then
			local next_charge = duration - (GetTime() - started)
			local m, s = math.floor (next_charge/60), math.floor (next_charge%60)
			if (s < 10) then
				s = "0" .. s
			end
			if (charges > 0) then
				BattleRes.available_res_label.text = "|cFF55FF55" .. charges .. "|r    (0" .. m .. ":" .. s .. ")"
			else
				BattleRes.available_res_label.text = "|cFFFF5555" .. charges .. "|r    (0" .. m .. ":" .. s .. ")"
			end
			
			for target_name, who_name in pairs (BattleRes.ResRecently) do
				if (UnitHealth (target_name) > 1) then
					add_ress (who_name, target_name)
				end
			end
		else
			BattleRes.available_res_label.text = "--x--x--"
		end
	end --doo
	
	function BattleRes.OnEncounterStart()
		bres_frame:Show()
		BattleRes.done_res_label.text = ""
		bres_frame:SetSize (BattleRes.db.panel_width, BattleRes.db.panel_height)
		bres_frame:SetSize (130, 20)
		
		bres_frame.timer = C_Timer.NewTicker (1, tick)
		BattleRes:RegisterForCLEUEvent ("SPELL_RESURRECT", on_ress)
		tick()
	end
	function BattleRes.OnEncounterEnd()
		bres_frame:Hide()
		BattleRes.done_res_label.text = ""
		BattleRes:UnregisterForCLEUEvent ("SPELL_RESURRECT", on_ress)
		if (bres_frame.timer) then
			bres_frame.timer:Cancel()
		end
	end
	
	bres_frame:RegisterEvent ("ENCOUNTER_START")
	bres_frame:RegisterEvent ("ENCOUNTER_END")
	bres_frame:RegisterEvent ("PLAYER_REGEN_DISABLED") --debug
	bres_frame:RegisterEvent ("PLAYER_REGEN_ENABLED") --debug
	
	bres_frame:SetScript ("OnEvent", function (self, event, ...)
		if (event == "ENCOUNTER_START") then -- or event == "PLAYER_REGEN_DISABLED"
			if (BattleRes.db.enabled) then
				BattleRes.OnEncounter = true
				wipe (BattleRes.ResRecently)
				BattleRes.OnEncounterStart()
			end
		elseif (event == "ENCOUNTER_END") then -- or event == "PLAYER_REGEN_ENABLED"
			BattleRes.OnEncounter = nil
			BattleRes.OnEncounterEnd()
		end
	end)
	
	BattleRes:RefreshResFrame()
end

BattleRes.OnEnable = function (plugin)
	-- enabled from the options panel.
	BattleRes:RefreshResFrame()
end

BattleRes.OnDisable = function (plugin)
	-- disabled from the options panel.
	plugin.bres_frame:Hide()
end

BattleRes.OnProfileChanged = function (plugin)
	if (plugin.db.enabled) then
		BattleRes.OnEnable (plugin)
		BattleRes:RefreshResFrame()
	else
		BattleRes.OnDisable (plugin)
	end
	
	if (plugin.options_built) then
		plugin.main_frame:RefreshOptions()
	end
end

function BattleRes:RefreshResFrame()
	local db = BattleRes.db
	
	-- show res history
	if (db.panel_show_res) then
		BattleRes.done_res_label:Show()
	else
		BattleRes.done_res_label:Hide()
	end
	
	-- frame lock
	if (db.panel_locked) then
		BattleRes.bres_frame:SetLocked (true)
	else
		BattleRes.bres_frame:SetLocked (false)
	end
	
	-- font face
	local SharedMedia = LibStub:GetLibrary ("LibSharedMedia-3.0")
	local font = SharedMedia:Fetch ("font", db.text_font)
	RA:SetFontFace (BattleRes.available_res_label, font)
	RA:SetFontFace (BattleRes.done_res_label, font)
	
	-- font size
	RA:SetFontSize (BattleRes.available_res_label, db.text_size)
	RA:SetFontSize (BattleRes.done_res_label, db.text_size)
	
	-- font color
	RA:SetFontColor (BattleRes.available_res_label, db.text_color.r, db.text_color.g, db.text_color.b, db.text_color.a)
	RA:SetFontColor (BattleRes.done_res_label, db.text_color.r, db.text_color.g, db.text_color.b, db.text_color.a)
	
	-- text anchor
	BattleRes.available_res_label:ClearAllPoints()
	BattleRes.done_res_label:ClearAllPoints()

	BattleRes.done_res_label:SetJustifyV ("top")
	
	if (db.text_anchor == "left") then
		BattleRes.available_res_label:SetPoint ("topleft", BattleRes.bres_frame, "topleft", 5, -3)
		BattleRes.available_res_label:SetJustifyH ("left")
		BattleRes.done_res_label:SetPoint ("topleft", BattleRes.bres_frame, "topleft", 5, -16)
		BattleRes.done_res_label:SetJustifyH ("left")
	elseif (db.text_anchor == "center") then
		BattleRes.available_res_label:SetPoint ("center", BattleRes.bres_frame, "center", 0, 0)
		BattleRes.available_res_label:SetPoint ("top", BattleRes.bres_frame, "top", 0, -3)
		BattleRes.available_res_label:SetJustifyH ("center")
		BattleRes.done_res_label:SetPoint ("center", BattleRes.bres_frame, "center", 0, 0)
		BattleRes.done_res_label:SetPoint ("top", BattleRes.bres_frame, "top", 0, -16)
		BattleRes.done_res_label:SetJustifyH ("center")
	elseif (db.text_anchor == "right") then
		BattleRes.available_res_label:SetPoint ("topright", BattleRes.bres_frame, "topright", -5, -3)
		BattleRes.available_res_label:SetJustifyH ("right")
		BattleRes.done_res_label:SetPoint ("topright", BattleRes.bres_frame, "topright", -5, -16)
		BattleRes.done_res_label:SetJustifyH ("right")
	end
	
	-- background color
	BattleRes.bres_frame:SetBackdropColor (db.background_color.r, db.background_color.g, db.background_color.b, db.background_color.a)
	BattleRes.bres_frame:SetBackdropBorderColor (db.background_border_color.r, db.background_border_color.g, db.background_border_color.b, db.background_border_color.a)
	
end

--> called then its options is opened on the main options panel
function BattleRes.OnShowOnOptionsPanel()
	local OptionsPanel = BattleRes.OptionsPanel
	BattleRes.BuildOptions (OptionsPanel)
end

function BattleRes.BuildOptions (frame)

	if (not frame.FirstRun) then
		frame.FirstRun = true
		frame:SetScript ("OnShow", function()
			if (not BattleRes.OnEncounter) then
				BattleRes.OnEncounterStart()
				
				if (not BattleRes.AlertFrame) then
					BattleRes.AlertFrame = CreateFrame ("frame", "RaidAssistBattleResAlert", BattleRes.bres_frame, "ActionBarButtonSpellActivationAlert")
					BattleRes.AlertFrame:SetFrameStrata ("FULLSCREEN")
					BattleRes.AlertFrame:Hide()
					BattleRes.AlertFrame:SetPoint ("topleft", BattleRes.bres_frame, "topleft", -60, 6)
					BattleRes.AlertFrame:SetPoint ("bottomright", BattleRes.bres_frame, "bottomright", 40, -6)
					BattleRes.AlertFrame:SetAlpha (0.2)
				end
				
				BattleRes.AlertFrame.animOut:Stop()
				BattleRes.AlertFrame.animIn:Play()
				C_Timer.After (0.5, function() BattleRes.AlertFrame.animIn:Stop(); BattleRes.AlertFrame.animOut:Play() end)
			end
		end)
		frame:SetScript ("OnHide", function()
			if (not BattleRes.OnEncounter) then
				BattleRes.OnEncounterEnd()
				
			end
		end)

		local on_select_text_font = function (self, fixed_value, value)
			BattleRes.db.text_font = value
			BattleRes:RefreshResFrame()
		end
		
		local on_select_text_anchor = function (self, fixed_value, value)
			BattleRes.db.text_anchor = value
			BattleRes:RefreshResFrame()
		end
		local text_anchor_options = {
			{value = "left", label = L["S_ANCHOR_LEFT"], onclick = on_select_text_anchor},
			{value = "center", label = L["S_ANCHOR_CENTER"], onclick = on_select_text_anchor},
			{value = "right", label = L["S_ANCHOR_RIGHT"], onclick = on_select_text_anchor},
		}

		local options_text_template = BattleRes:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE")
		
		local options_list = {
			{type = "label", get = function() return "General Options:" end, text_template = BattleRes:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},
			{
				type = "toggle",
				get = function() return BattleRes.db.enabled end,
				set = function (self, fixedparam, value) 
					if (not value) then
						RA:DisablePlugin (L["S_PLUGIN_BRES_NAME"])
					else
						RA:EnablePlugin (L["S_PLUGIN_BRES_NAME"])
					end
				end,
				desc = L["S_PLUGIN_ENABLED_DESC"],
				name = L["S_PLUGIN_ENABLED"],
				text_template = options_text_template,
			},
			{
				type = "toggle",
				get = function() return BattleRes.db.panel_show_res end,
				set = function (self, fixedparam, value) 
					BattleRes.db.panel_show_res = value
					BattleRes:RefreshResFrame()
				end,
				desc = L["S_PLUGIN_BRES_SHOW_HISTORY_DESC"],
				name = L["S_PLUGIN_BRES_SHOW_HISTORY"],
				text_template = options_text_template,
			},
			{
				type = "toggle",
				get = function() return BattleRes.db.panel_locked end,
				set = function (self, fixedparam, value) 
					BattleRes.db.panel_locked = value
					BattleRes:RefreshResFrame()
				end,
				desc = L["S_PLUGIN_FRAME_LOCKED_DESC"],
				name = L["S_PLUGIN_FRAME_LOCKED"],
				text_template = options_text_template,
			},
			{
				type = "select",
				get = function() return BattleRes.db.text_font end,
				values = function() return RA:BuildDropDownFontList (on_select_text_font) end,
				name = L["S_PLUGIN_TEXT_FONT"],
				text_template = options_text_template,
			},
			{
				type = "range",
				get = function() return BattleRes.db.text_size end,
				set = function (self, fixedparam, value) 
					BattleRes.db.text_size = value
					BattleRes:RefreshResFrame() 
				end,
				min = 4,
				max = 32,
				step = 1,
				name = L["S_PLUGIN_TEXT_SIZE"],
				text_template = options_text_template,
			},
			{
				type = "color",
				get = function() 
					return {BattleRes.db.text_color.r, BattleRes.db.text_color.g, BattleRes.db.text_color.b, BattleRes.db.text_color.a} 
				end,
				set = function (self, r, g, b, a) 
					local color = BattleRes.db.text_color
					color.r, color.g, color.b, color.a = r, g, b, a
					BattleRes:RefreshResFrame()
				end,
				name = L["S_PLUGIN_TEXT_COLOR"],
				text_template = options_text_template,
			},
			{
				type = "select",
				get = function() return BattleRes.db.text_anchor end,
				values = function() return text_anchor_options end,
				name = L["S_PLUGIN_TEXT_ANCHOR"],
				text_template = options_text_template,
			},
			{
				type = "color",
				get = function() return {BattleRes.db.background_color.r, BattleRes.db.background_color.g, BattleRes.db.background_color.b, BattleRes.db.background_color.a} end,
				set = function (self, r, g, b, a) 
					local color = BattleRes.db.background_color
					color.r, color.g, color.b, color.a = r, g, b, a
					BattleRes:RefreshResFrame()
				end,
				name = L["S_PLUGIN_FRAME_BACKDROP_COLOR"],
				text_template = options_text_template,
			},
			{
				type = "color",
				get = function() return {BattleRes.db.background_border_color.r, BattleRes.db.background_border_color.g, BattleRes.db.background_border_color.b, BattleRes.db.background_border_color.a} end,
				set = function (self, r, g, b, a) 
					local color = BattleRes.db.background_border_color
					color.r, color.g, color.b, color.a = r, g, b, a
					BattleRes:RefreshResFrame()
				end,
				name = L["S_PLUGIN_FRAME_BORDER_COLOR"],
				text_template = options_text_template,
			},
		}
		
		local options_text_template = BattleRes:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE")
		local options_dropdown_template = BattleRes:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
		local options_switch_template = BattleRes:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE")
		local options_slider_template = BattleRes:GetTemplate ("slider", "OPTIONS_SLIDER_TEMPLATE")
		local options_button_template = BattleRes:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE")
		
		RA:BuildMenu (frame, options_list, 0, 0, 500, true, options_text_template, options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template)
	end
end

-- plugin will be installed only after the raid assist core load its saved variables.
-- install_status may be 'successful' or 'scheduled'.
RA:InstallPlugin(BattleRes.displayName, "RABattleRes", BattleRes, default_config)











