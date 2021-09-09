
local RA = _G.RaidAssist
local L = LibStub ("AceLocale-3.0"):GetLocale ("RaidAssistAddon")
local _
local default_priority = 90
local DF = DetailsFramework

local Invite = {version = "v0.1", pluginname = "Invites", pluginId = "INVI", displayName = "Invites"}
_G ["RaidAssistInvite"] = Invite

local default_config = {
	presets = {},
	invite_msg = "[RaidAssist]: invites in 5 seconds.",
	invite_msg_repeats = true,
	auto_invite = true,
	auto_invite_limited = true,
	auto_invite_keywords = {},
	auto_accept_invites = false,
	auto_accept_invites_limited = true,
	invite_interval = 60,
}

local icon_texcoord = {l=1, r=0, t=0, b=1}
local text_color_enabled = {r=1, g=1, b=1, a=1}
local text_color_disabled = {r=0.5, g=0.5, b=0.5, a=1}
local icon_texture = [[Interface\CURSOR\Cast]]

Invite.menu_text = function (plugin)
	if (Invite.db.enabled) then
		return icon_texture, icon_texcoord, "Invites", text_color_enabled
	else
		return icon_texture, icon_texcoord, "Invites", text_color_disabled
	end
end

Invite.menu_popup_show = function (plugin, ct_frame, param1, param2)
	RA:AnchorMyPopupFrame (Invite)
end

Invite.menu_popup_hide = function (plugin, ct_frame, param1, param2)
	Invite.popup_frame:Hide()
end


Invite.menu_on_click = function (plugin)
	--if (not Invite.options_built) then
	--	Invite.BuildOptions()
	--	Invite.options_built = true
	--end
	--Invite.main_frame:Show()
	
	RA.OpenMainOptions (Invite)
	Invite.main_frame:RefreshPresetButtons()
	
	--C_Timer.After (0.1, Invite.create_new_preset)
end

Invite.OnInstall = function (plugin)

	Invite.db.menu_priority = default_priority

	if (not Invite.db.first_run) then
		tinsert (Invite.db.auto_invite_keywords, "inv")
		tinsert (Invite.db.auto_invite_keywords, "invite")
		Invite.db.first_run = true
	end

	local popup_frame = Invite.popup_frame
	
	Invite:RegisterEvent ("PARTY_INVITE_REQUEST")
	Invite:RegisterEvent ("CHAT_MSG_WHISPER")
	Invite:RegisterEvent ("CHAT_MSG_BN_WHISPER")

	--C_Timer.After (20, Invite.CheckForAutoInvites)
	C_Timer.After (20, Invite.CheckForAutoInvites)

	--Invite.db.auto_invite = false
	--Invite.db.auto_accept_invites = false

	--debug
	--C_Timer.After (1, Invite.menu_on_click)
end

Invite.OnEnable = function (plugin)
	-- enabled from the options panel.
	
end

Invite.OnDisable = function (plugin)
	-- disabled from the options panel.
	
end

Invite.OnProfileChanged = function (plugin)
	if (plugin.db.enabled) then
		Invite.OnEnable (plugin)
	else
		Invite.OnDisable (plugin)
	end
	
	if (plugin.options_built) then
		--plugin.main_frame:RefreshOptions()
	end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> track whispers

local handle_inv_text = function (message, from)
	if (GetNumGroupMembers() >= 4) then
		if (not IsInRaid()) then
			local in_instance, instance_type = IsInInstance()
			if (instance_type ~= "party") then
				C_PartyInfo.ConvertToRaid()
			else
				return
			end
		end
	end

	if (not UnitIsUnit(from, "player")) then
		C_Timer.After(1, function()
			C_PartyInfo.InviteUnit(from)
		end)
	end
end

local invite_guild_friend = function(timerObject)
	if (timerObject.friendName) then
		local is_showing_all = GetGuildRosterShowOffline()

		for i = 1, select(is_showing_all and 1 or 3, GetNumGuildMembers()) do
			local name, rankName, rankIndex, level, classDisplayName, zone, _, _, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding, GUID = GetGuildRosterInfo(i) --, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding

			name = Ambiguate(name, "none")

			if (isOnline and not isMobile and timerObject.friendName == name) then
				if (not UnitIsUnit(name, "player")) then
					C_PartyInfo.InviteUnit(name)
					break
				end
			end
		end
	end
end

local handle_inv_whisper = function(message, from)
	if (not from) then
		return
	end

	local foundMatch = false
	for i = 1, #Invite.db.auto_invite_keywords do
		local lowMessage, lowKeyword = string.lower(message), string.lower(Invite.db.auto_invite_keywords[i])
		if (lowMessage == lowKeyword) then
			foundMatch = true
		end
	end

	if (not foundMatch) then
		return
	end

	from = Ambiguate(from, "none")

	if (Invite.db.auto_invite) then
		if (Invite:IsInQueue()) then
			return

		elseif (Invite.db.auto_invite_limited) then
			if (Invite:IsBnetFriend(from) or Invite:IsFriend(from)) then
				handle_inv_text(message, from)
			else
				C_GuildInfo.GuildRoster()
				local inviteTimer = C_Timer.NewTimer(2, invite_guild_friend)
				inviteTimer.message = message
				inviteTimer.friendName = from
			end
		else
			handle_inv_text(message, from)
		end
	end
end

function Invite:CHAT_MSG_WHISPER(event, message, sender, language, channelString, target, flags, unknown, channelNumber, channelName, unknown, counter, guid)
	return handle_inv_whisper(message, sender)
end

function Invite:CHAT_MSG_BN_WHISPER(event, message, sender)
	local _, bnet_friends_amt = BNGetNumFriends()
	for i = 1, bnet_friends_amt do

		local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
		if (accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline and accountInfo.gameAccountInfo.characterName) then
			if (accountInfo.gameAccountInfo.characterName == sender) then
				return handle_inv_whisper(message, sender)
			end
		end
	end
	return handle_inv_whisper(message, sender)
end


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> auto accept invites

local accept_group = function(from, source)
	AcceptGroup()
	StaticPopup_Hide("PARTY_INVITE")
	StaticPopup_Hide("PARTY_INVITE_XREALM")
end

function Invite:PARTY_INVITE_REQUEST(event, from)
	if (not Invite.db.auto_accept_invites) then
		return
	end

	if (Invite:IsInQueue()) then
		return
	end

	if (not Invite.db.auto_accept_invites_limited) then
		return accept_group(from, 1)
	end

	if (Invite:IsBnetFriend(from)) then
		return accept_group(from, 2)

	elseif (Invite:IsFriend(from)) then
		return accept_group(from, 3)
	end

	Invite:IsGuildFriend(from, function(from, isInGuild)
		if (isInGuild) then
			return accept_group(from, 4)
		end
	end)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Invite:GetAllPresets()
	return Invite.db.presets
end

function Invite:GetPreset (preset_number)
	return Invite.db.presets [preset_number]
end

function Invite:DeletePreset (preset_number)
	tremove (Invite.db.presets, preset_number)
	
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Invite:GetScheduleCores()
	local RaidSchedule = _G ["RaidAssistRaidSchedule"]
	if (RaidSchedule) then
		return RaidSchedule.db.cores
	else
		return {}
	end
end

local empty_func = function()end

function Invite.OnShowOnOptionsPanel()
	local OptionsPanel = Invite.OptionsPanel
	Invite.BuildOptions (OptionsPanel)
end

function Invite.BuildOptions (frame)

	if (frame.FirstRun) then
		return
	end
	frame.FirstRun = true

	local main_frame = frame
	Invite.main_frame = frame
	main_frame:SetSize (400, 500)

	--- create panel precisa ser passado para dentro da janela, ficaria no lado esquerdo
	function Invite:CleanNewInviteFrames()
	
	end

	----------create new invite frames
		local presetSetupFrame = CreateFrame("frame", main_frame:GetName() .. "PresetSetupBG", main_frame, "BackdropTemplate")
		presetSetupFrame:SetSize(380, 601)
		presetSetupFrame:SetPoint("topleft", main_frame, "topleft", 0, 0)
		presetSetupFrame:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
		presetSetupFrame:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))
		presetSetupFrame:SetBackdropColor(.1, .1, .1, 1)

		local panel = main_frame
		
		--preset name
		local label_preset_name = DF:CreateLabel (presetSetupFrame, "Preset Name" .. ": ", Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		local editbox_preset_name = DF:CreateTextEntry (presetSetupFrame, empty_func, 160, 20, "editbox_preset_name", _, _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		panel.editbox_preset_name = editbox_preset_name

		label_preset_name:SetPoint ("topleft", presetSetupFrame, "topleft", 10, -10)
		editbox_preset_name:SetPoint ("left", label_preset_name, "right", 2, 0)

		--guild rank to invite
		local welcome_text_create1 = DF:CreateLabel (presetSetupFrame, "Select which ranks will be invited", Invite:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
		welcome_text_create1:SetPoint ("topleft", panel, "topleft", 10, -42)
		welcome_text_create1.fontsize = 14
		
		local switchers = {}
		function Invite:UpdateRanksOnProfileCreation()
			local ranks = Invite:GetGuildRanks()
			--dos
			
			for i = 1, #switchers do
				local s = switchers[i]
				s:Hide()
				s.rank_label:Hide()
			end
			
			local x, y, b, i = 10, -62, 3, 1
			for rank_index, rank_name in pairs (ranks) do
			
				local switch = switchers [i]
			
				if (not switch) then
					local s, l = DF:CreateSwitch (panel, empty_func, false, 20, 26, _, _, "switch_rank" .. i, _, _, _, _, ranks [i], Invite:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
					l:ClearAllPoints()
					s:ClearAllPoints()
					s.rank_label = l
					l:SetPoint ("left", s, "right", 2, 0)
					switch = s
					switch:SetAsCheckBox()
					switch:SetPoint ("topleft", panel, "topleft", x, y)
					if (i > b) then
						y = y - 20
						x = 10
						b = b+4
					else
						x = x + 92
					end
					switchers [i] = switch
				end
				
				switch:Show()
				switch.rank_label:Show()
				switch.rank = rank_index
				switch.rank_label.text = rank_name
				
				i = i + 1
			end
		end
		
		--raid difficult
		local difficulty_table = {
			{value = 14, label = "Normal", onclick = empty_func},
			{value = 15, label = "Heroic", onclick = empty_func},
			{value = 16, label = "Mythic", onclick = empty_func},
		}
		local dropdown_diff_fill = function()
			return difficulty_table
		end
		local label_diff = DF:CreateLabel (presetSetupFrame, "Raid Difficulty" .. ": ", Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		local dropdown_diff = DF:CreateDropDown (presetSetupFrame, dropdown_diff_fill, 1, 160, 20, "dropdown_diff_preset", _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		panel.dropdown_diff_preset = dropdown_diff
		dropdown_diff:SetPoint ("left", label_diff, "right", 2, 0)
		label_diff:SetPoint (10, -130)
		
		--master loot
		local label_masterloot_name = DF:CreateLabel (presetSetupFrame, "Assistants" .. ": ", Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		local editbox_masterloot_name = DF:CreateTextEntry (presetSetupFrame, empty_func, 200, 20, "editbox_masterloot_name", _, _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		panel.editbox_masterloot_name =  editbox_masterloot_name

		editbox_masterloot_name:SetJustifyH ("left")
		editbox_masterloot_name.tooltip = "Separate player names with a space.\n\nIf the player is from a different realm, add the realm name too, example: Tercioo-Azralon."
		label_masterloot_name:SetPoint ("topleft", panel, "topleft", 10, -155)
		editbox_masterloot_name:SetPoint ("left", label_masterloot_name, "right", 2, 0)

		--raid leader
		local label_raidleader_name = DF:CreateLabel (presetSetupFrame, "Raid Leader" .. ": ", Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		local editbox_raidleader_name = DF:CreateTextEntry (presetSetupFrame, empty_func, 160, 20, "editbox_raidleader_name", _, _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		panel.editbox_raidleader_name = editbox_raidleader_name
		editbox_raidleader_name:SetJustifyH ("left")
		label_raidleader_name:SetPoint ("topleft", panel, "topleft", 10, -180)
		editbox_raidleader_name:SetPoint ("left", label_raidleader_name, "right", 2, 0)
		
		--keep auto inviting for X minutes
		local welcome_text_create2 = DF:CreateLabel (presetSetupFrame, "Auto Invite Settings:", Invite:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
		welcome_text_create2:SetPoint ("topleft", panel, "topleft", 10, -215)
		
		local keep_auto_invite_table = {{value = 0, label = "disabled", onclick = empty_func}}
		for i = 2, 30 do
			keep_auto_invite_table [#keep_auto_invite_table+1] = {value = i, label = i .. " minutes", onclick = empty_func}
		end
		local keep_auto_invite_fill = function()
			return keep_auto_invite_table
		end
		local label_keep_auto_invite = DF:CreateLabel (presetSetupFrame, "Keep Inviting For" .. ": ", Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		local dropdown_keep_auto_invite = DF:CreateDropDown (presetSetupFrame, keep_auto_invite_fill, 1, 160, 20, "dropdown_keep_invites", _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		panel.dropdown_keep_invites = dropdown_keep_auto_invite
		dropdown_keep_auto_invite:SetPoint ("left", label_keep_auto_invite, "right", 2, 0)
		label_keep_auto_invite:SetPoint (10, -250)

		--auto start inviting
		local auto_invite_switch, auto_invite_label = DF:CreateSwitch (presetSetupFrame, empty_func, false, _, _, _, _, "switch_auto_invite", _, _, _, _, "Auto Start Invites", Invite:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		panel.switch_auto_invite = auto_invite_switch
		auto_invite_switch:SetAsCheckBox()
		auto_invite_label:SetPoint ("topleft", panel, "topleft", 10, -285)

		local schedule_fill = function()
			local t = {}
			if (_G ["RaidAssistRaidSchedule"]) then
				local all_cores = Invite:GetScheduleCores()
				for i, core in pairs (all_cores) do
					t [#t+1] = {value = i, label = core.core_name, onclick = empty_func}
				end
			end
			return t
		end

		local label_schedule_select = DF:CreateLabel (presetSetupFrame, "Using this Raid Schedule" .. ": ", Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		local dropdown_schedule_select = DF:CreateDropDown (presetSetupFrame, schedule_fill, 1, 160, 20, "dropdown_schedule", _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		panel.dropdown_schedule = dropdown_schedule_select
		dropdown_schedule_select:SetPoint ("left", label_schedule_select, "right", 2, 0)
		label_schedule_select:SetPoint (10, -305)
		dropdown_schedule_select:SetScript("OnShow", function()
			dropdown_schedule_select:Refresh()
		end)

		--raid leader
		local msgToSendToPlayers = DF:CreateLabel (presetSetupFrame, "Msg to players: ", Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		local msgToSendToPlayersEditbox = DF:CreateTextEntry (presetSetupFrame, empty_func, 220, 20, "msgToSendToPlayersEditbox", _, _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		panel.msgToSendToPlayersEditbox = msgToSendToPlayersEditbox
		msgToSendToPlayersEditbox:SetJustifyH ("left")
		msgToSendToPlayers:SetPoint ("topleft", label_schedule_select, "bottomleft", 0, -10)
		msgToSendToPlayersEditbox:SetPoint ("left", msgToSendToPlayers, "right", 2, 0)

		function Invite:ResetNewPresetPanel()
			editbox_preset_name.text = ""
			for i = 1, #switchers do
				local switch = switchers[i]
				switch:SetValue(false)
			end
			dropdown_diff:Select(1, true)
			editbox_masterloot_name.text = ""

			dropdown_keep_auto_invite:Select(0)
			auto_invite_switch:SetValue(false)
			dropdown_schedule_select:Select(1, true)

			panel.button_create_preset:SetText("Create")
		end

		function Invite:ShowPreset(preset)
			editbox_preset_name.text = preset.name

			for i = 1, #switchers do
				local switch = switchers [i]
				switch:SetValue(false)
			end
			for this_rank, _ in pairs(preset.ranks) do
				for i = 1, #switchers do
					local switch = switchers [i]
					if (switch.rank == this_rank) then
						switch:SetValue(true)
						break
					end
				end
			end

			dropdown_diff:Select (preset.difficulty)
			editbox_masterloot_name.text = preset.masterloot or ""
			editbox_raidleader_name.text = preset.raidleader or ""

			dropdown_keep_auto_invite:Select(preset.keepinvites)
			auto_invite_switch:SetValue(preset.autostart)
			dropdown_schedule_select:Select(preset.autostartcore)
		end
		
		function Invite:EditPreset (preset)
			editbox_preset_name.text = preset.name
			
			for i = 1, #switchers do
				local switch = switchers [i]
				switch:SetValue (false)
			end
			for this_rank, _ in pairs (preset.ranks) do
				for i = 1, #switchers do
					local switch = switchers [i]
					if (switch.rank == this_rank) then
						switch:SetValue (true)
						break
					end
				end
			end
			
			dropdown_diff:Select (preset.difficulty)
			editbox_masterloot_name.text = preset.masterloot or ""
			editbox_raidleader_name.text = preset.raidleader or ""
			
			dropdown_keep_auto_invite:Select (preset.keepinvites)
			auto_invite_switch:SetValue (preset.autostart)
			dropdown_schedule_select:Select (preset.autostartcore)
			msgToSendToPlayersEditbox:SetText(Invite.db.invite_msg)

			panel.button_create_preset:SetText ("Save")
			panel:Show()
		end
		
		function Invite.create_or_edit_preset()
			
			local preset_name = editbox_preset_name.text ~= "" and editbox_preset_name.text or " --no name--"
			local ranks = {}
			local raid_difficulty = dropdown_diff:GetValue()
			local master_loot = editbox_masterloot_name.text
			local raid_leader = editbox_raidleader_name.text
			local keep_inviting = dropdown_keep_auto_invite:GetValue()
			local auto_start_invites = auto_invite_switch:GetValue()
			local auto_start_core
			
			if (_G ["RaidAssistRaidSchedule"]) then
				local cores = Invite:GetScheduleCores()
				local dropdown_value = dropdown_schedule_select:GetValue()
				local coreTable = cores [dropdown_value]
				local coreName = coreTable and coreTable.core_name
				auto_start_core = coreName
			end

			local got_rank_selected
			for i = 1, #switchers do
				local switch = switchers[i]
				if (switch:GetValue()) then
					ranks[switch.rank] = GuildControlGetRankName(switch.rank)
					got_rank_selected = true
				end
			end

			if (not got_rank_selected) then
				return RA:Msg("At least one guild rank need to be selected.")
			end

			if (Invite.is_editing) then
				local preset = Invite.is_editing_table
				preset.name = preset_name
				preset.ranks = ranks
				preset.difficulty = raid_difficulty
				preset.masterloot = master_loot
				preset.raidleader = raid_leader
				preset.keepinvites = keep_inviting
				preset.autostart = auto_start_invites
				preset.autostartcore = auto_start_core
				Invite.db.invite_msg = main_frame.msgToSendToPlayersEditbox:GetText()
			else
				local preset = {}
				preset.name = preset_name
				preset.ranks = ranks
				preset.difficulty = raid_difficulty
				preset.masterloot = master_loot
				preset.raidleader = raid_leader
				preset.keepinvites = keep_inviting
				preset.autostart = auto_start_invites
				preset.autostartcore = auto_start_core
				
				tinsert (Invite.db.presets, preset)
			end
			
			Invite.is_editing = nil
			Invite.is_editing_table = nil

			Invite:DisableCreatePanel()
			Invite:EnableInviteButtons()
			
			main_frame:RefreshPresetButtons()
		end

		--create button (confirm) // edit button is 'save'
		local create_button = RA:CreateButton(panel, Invite.create_or_edit_preset, 160, 20, "Create Preset", _, _, _, "button_create_preset", _, _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		create_button.widget.texture_disabled:SetTexture([[Interface\Tooltips\UI-Tooltip-Background]])
		create_button.widget.texture_disabled:SetVertexColor(0, 0, 0)
		create_button.widget.texture_disabled:SetAlpha(.5)
		create_button:SetPoint("topleft", panel, "topleft", 10 , -375)

	------------------------ end


	Invite.create_new_preset = function()
		if (not Invite.create_preset_panel_built) then
			Invite:CleanNewInviteFrames()
			Invite.create_preset_panel_built = true
		end
		
		Invite.is_editing = nil
		Invite.is_editing_table = nil
		
		Invite:ResetNewPresetPanel()
		Invite:UpdateRanksOnProfileCreation()
		
		Invite:EnableCreatePanel()
		Invite:DisableInviteButtons()
	end
	
	local edit_preset = function()
		local dropdown_value = main_frame.dropdown_edit_preset:GetValue()
		if (type (dropdown_value) == "number" and Invite:GetPreset (dropdown_value)) then
			Invite.is_editing = true
			Invite.is_editing_table = Invite:GetPreset (dropdown_value)
			
			if (not Invite.EditPreset) then
				Invite:CleanNewInviteFrames()
			end
			Invite:UpdateRanksOnProfileCreation()
			
			Invite:EnableCreatePanel()
			Invite:EditPreset (Invite.is_editing_table)
			Invite:DisableInviteButtons()
		end
	end
	
	
	-------- Main widgets frames
		local x_start = 400

		--top right frame
		local profilesBackgroupFrame = CreateFrame("frame", main_frame:GetName() .. "PresetSelectBG", main_frame, "BackdropTemplate")
		profilesBackgroupFrame:SetSize(400, 250)
		profilesBackgroupFrame:SetPoint("topleft", main_frame, "topright", -5, 0)
		profilesBackgroupFrame:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
		profilesBackgroupFrame:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))
		profilesBackgroupFrame:SetBackdropColor(.1, .1, .1, 1)

		--> welcome text
		local welcome_text1 = DF:CreateLabel (profilesBackgroupFrame, "Select an Invite Preset to start inviting", Invite:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
		welcome_text1:SetPoint ("topleft", main_frame, "topleft", x_start, -5)
		welcome_text1.fontsize = 14
		
		--> hold all preset buttons created
		local preset_buttons = {}
		
		--> no preset created yet
		local no_preset_text1 = DF:CreateLabel (profilesBackgroupFrame, "There is no preset created yet", Invite:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
		no_preset_text1.color = "red"
		no_preset_text1:SetPoint ("topleft", main_frame, "topleft", x_start, -30)
		
		local select_preset_start_inviting = function (_, _, preset_number)
			Invite:StartInvites(preset_number)
		end

		--> update preset buttons when on frame show()
		function main_frame:RefreshPresetButtons()
			for i = 1, #preset_buttons do
				preset_buttons[i]:Hide()
			end
			
			local got_one
			local x, y = x_start, -30
			
			for i = 1, #Invite.db.presets do
				local preset = Invite.db.presets[i]
				local button = preset_buttons[i]
				if (not button) then
					button = DF:CreateButton(profilesBackgroupFrame, select_preset_start_inviting, 110, 20, "", _, _, _, _, _, _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
					preset_buttons[i] = button
				end
				button:Show()
				button:SetText(preset.name)
				button:SetClickFunction(select_preset_start_inviting, i)
				
				button:ClearAllPoints()
				button:SetPoint ("topleft", main_frame, "topleft", x, y)
				x = x + 120
				if (i == 3 or i == 6) then
					y = y - 25
					x = x_start
				end
				
				got_one = true
			end
			
			if (got_one) then
				no_preset_text1:Hide()
			else
				no_preset_text1:Show()
			end
			
			main_frame.dropdown_edit_preset:Refresh()
			main_frame.dropdown_edit_preset:Select (1, true)
			main_frame.dropdown_remove_preset:Refresh()
			main_frame.dropdown_remove_preset:Select (1, true)
			main_frame.msgToSendToPlayersEditbox:SetText(Invite.db.invite_msg)
		end

		--> create, edit or remove a preset
		local welcome_text2 = DF:CreateLabel(profilesBackgroupFrame, "Create, edit or remove a preset", Invite:GetTemplate("font", "ORANGE_FONT_TEMPLATE"))
		welcome_text2:SetPoint("topleft", main_frame, "topleft", x_start, -120) --POINT
		welcome_text2.fontsize = 14

		local create_button = DF:CreateButton(profilesBackgroupFrame, Invite.create_new_preset, 160, 20, "Create Preset", _, _, _, _, _, _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		create_button:SetIcon("Interface\\AddOns\\" .. RA.InstallDir .. "\\media\\plus", 10, 10, "overlay", {0, 1, 0, 1}, {1, 1, 1}, 3, 1, 0)
		create_button:SetPoint("topleft", main_frame, "topleft", x_start, -145) --POINT

		--> edit dropdown
		local on_edit_select = function (_, _, preset)
			Invite:ShowPreset (Invite:GetPreset (preset))
			Invite:DisableCreatePanel()
		end
		local dropdown_edit_fill = function()
			local t = {}
			for i, preset in ipairs (Invite.db.presets) do
				t [#t+1] = {value = i, label = preset.name, onclick = on_edit_select}
			end
			return t
		end

		local label_edit = DF:CreateLabel (profilesBackgroupFrame, "Edit" .. ": ", Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		local dropdown_edit = DF:CreateDropDown (profilesBackgroupFrame, dropdown_edit_fill, _, 160, 20, "dropdown_edit_preset", _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		main_frame.dropdown_edit_preset = dropdown_edit
		dropdown_edit:SetPoint ("left", label_edit, "right", 2, 0)
		label_edit:SetPoint("topleft", main_frame, "topleft", x_start, -170) --POINT

		local button_edit = DF:CreateButton (profilesBackgroupFrame, edit_preset, 80, 18, "Edit", _, _, _, _, _, _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		button_edit:SetPoint ("left", dropdown_edit, "right", 2, 0)
		button_edit:SetIcon ([[Interface\BUTTONS\UI-OptionsButton]], 12, 12, "overlay", {0, 1, 0, 1}, {1, 1, 1}, 2, 1, 0)

		--> remove dropdown
		local dropdown_remove_fill = function()
			local t = {}
			for i, preset in ipairs (Invite.db.presets) do
				t [#t+1] = {value = i, label = preset.name, onclick = empty_func}
			end
			return t
		end

		local label_remove = DF:CreateLabel(profilesBackgroupFrame, "Remove" .. ": ", Invite:GetTemplate("font", "OPTIONS_FONT_TEMPLATE"))
		local dropdown_remove = DF:CreateDropDown(profilesBackgroupFrame, dropdown_remove_fill, _, 160, 20, "dropdown_remove_preset", _, Invite:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		main_frame.dropdown_remove_preset = dropdown_remove
		dropdown_remove:SetPoint("left", label_remove, "right", 2, 0)
		label_remove:SetPoint("topleft", main_frame, "topleft", x_start, -190) --POINT

		local remove_preset_table = function()
			local preset_number = dropdown_remove.value
			if (preset_number) then
				local preset = Invite:GetPreset (preset_number)
				if (preset) then
					if (Invite.is_editing and Invite.is_editing_table == preset) then
						--InviteNewProfileFrame:Hide()
						Invite.is_editing = nil
						Invite.is_editing_table = nil
					end
					Invite:DeletePreset (preset_number)
					main_frame:RefreshPresetButtons()
					dropdown_remove:Refresh()
					dropdown_remove:Select (1, true)
					dropdown_edit:Refresh()
					dropdown_edit:Select (1, true)
				end
			end
		end

		local button_remove = DF:CreateButton (profilesBackgroupFrame, remove_preset_table, 80, 18, "Remove", _, _, _, _, _, _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		button_remove:SetPoint ("left", dropdown_remove, "right", 2, 0)
		button_remove:SetIcon ([[Interface\BUTTONS\UI-StopButton]], 14, 14, "overlay", {0, 1, 0, 1}, {1, 1, 1}, 2, 1, 0)




		--bottom right frame
		local profilesConfigBgFrame = CreateFrame("frame", main_frame:GetName() .. "PresetConfigBG", main_frame, "BackdropTemplate")
		profilesConfigBgFrame:SetSize(400, 320)
		profilesConfigBgFrame:SetPoint("topleft", profilesBackgroupFrame, "bottomleft", 0, -30)
		profilesConfigBgFrame:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
		profilesConfigBgFrame:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))
		profilesConfigBgFrame:SetBackdropColor(.1, .1, .1, 1)

		local configXStart = 5

		--> auto invite on whisper
		--> welcome msg
		local welcome_text3 = DF:CreateLabel (profilesConfigBgFrame, "On receiving a whisper with keyword, auto invite the person?", Invite:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
		welcome_text3:SetPoint("topleft", profilesConfigBgFrame, "topleft", configXStart, -10) --POINT
		welcome_text3.fontsize = 14

		--> enabled
		local on_auto_invite_switch = function (_, _, value)
			Invite.db.auto_invite = value
		end
		local auto_invite_switch, auto_invite_label = DF:CreateSwitch (profilesConfigBgFrame, on_auto_invite_switch, Invite.db.auto_invite, _, _, _, _, "switch_auto_invite2", _, _, _, _, "Enabled", Invite:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		main_frame.switch_auto_invite2 = auto_invite_switch
		auto_invite_switch:SetAsCheckBox()
		auto_invite_label:SetPoint("topleft", profilesConfigBgFrame, "topleft", configXStart, -30) --POINT
		
		--> only from guild
		local on_auto_invite_guild_switch = function (_, _, value)
			Invite.db.auto_invite_limited = value
		end
		local auto_invite_guild_switch, auto_invite_guild_label = DF:CreateSwitch (profilesConfigBgFrame, on_auto_invite_guild_switch, Invite.db.auto_invite_limited, _, _, _, _, "switch_auto_invite_guild", _, _, _, _, "Only Guild and Friends", Invite:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		main_frame.switch_auto_invite_guild = auto_invite_guild_switch
		auto_invite_guild_switch:SetAsCheckBox()
		auto_invite_guild_label:SetPoint("topleft", profilesConfigBgFrame, "topleft", configXStart, -50) --POINT
		
		--> key words
		--add
		local editbox_add_keyword, label_add_keyword = DF:CreateTextEntry (profilesConfigBgFrame, empty_func, 120, 20, "entry_add_keyword", _, "Add Keyword", Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		label_add_keyword:SetPoint("topleft", profilesConfigBgFrame, "topleft", configXStart, -70) --POINT
		main_frame.entry_add_keyword = editbox_add_keyword
		
		local add_key_word_func = function()
			local keyword = editbox_add_keyword.text
			if (keyword ~= "") then
				tinsert (Invite.db.auto_invite_keywords, keyword)
			end
			editbox_add_keyword.text = ""
			editbox_add_keyword:ClearFocus()
			main_frame.dropdown_keyword_remove:Refresh()
			main_frame.dropdown_keyword_remove:Select (1, true)
		end
		local button_add_keyword = DF:CreateButton (profilesConfigBgFrame, add_key_word_func, 60, 18, "Add", _, _, _, _, _, _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		button_add_keyword:SetPoint ("left", editbox_add_keyword, "right", 2, 0)
		button_add_keyword:SetIcon ("Interface\\AddOns\\" .. RA.InstallDir .. "\\media\\plus", 10, 10, "overlay", {0, 1, 0, 1}, {1, 1, 1}, 3, 1, 0)
		
		--remove
		local dropdown_keyword_erase_fill = function()
			local t = {}
			for i, keyword in ipairs (Invite.db.auto_invite_keywords) do
				t [#t+1] = {value = i, label = keyword, onclick = empty_func}
			end
			return t
		end
		local label_keyword_remove = DF:CreateLabel (profilesConfigBgFrame, "Erase Keyword" .. ": ", Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		local dropdown_keyword_remove = DF:CreateDropDown (profilesConfigBgFrame, dropdown_keyword_erase_fill, _, 160, 20, "dropdown_keyword_remove", _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		dropdown_keyword_remove:SetPoint ("left", label_keyword_remove, "right", 2, 0)
		main_frame.dropdown_keyword_remove = dropdown_keyword_remove

		local keyword_remove = function()
			local value = dropdown_keyword_remove.value
			tremove (Invite.db.auto_invite_keywords, value)
			dropdown_keyword_remove:Refresh()
			dropdown_keyword_remove:Select (1, true)
		end
		local button_keyword_remove = DF:CreateButton (profilesConfigBgFrame, keyword_remove, 60, 18, "Remove", _, _, _, _, _, _, Invite:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		button_keyword_remove:SetPoint ("left", dropdown_keyword_remove, "right", 2, 0)
		button_keyword_remove:SetIcon ([[Interface\BUTTONS\UI-StopButton]], 14, 14, "overlay", {0, 1, 0, 1}, {1, 1, 1}, 2, 1, 0)
		label_keyword_remove:SetPoint("topleft", profilesConfigBgFrame, "topleft", configXStart, -90) --POINT
		
		--> auto accept invites
		
		--> welcome msg
		local welcome_text4 = DF:CreateLabel (profilesConfigBgFrame, "When a friend or guild member send an invite, auto accept it?", Invite:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
		welcome_text4:SetPoint("topleft", profilesConfigBgFrame, "topleft", configXStart, -130) --POINT
		welcome_text4.fontsize = 14

		--> enabled
		local on_auto_ainvite_switch = function (_, _, value)
			Invite.db.auto_accept_invites = value
		end
		local auto_ainvite_switch, auto_ainvite_label = DF:CreateSwitch (profilesConfigBgFrame, on_auto_ainvite_switch, Invite.db.auto_accept_invites, _, _, _, _, "switch_auto_ainvite", _, _, _, _, "Enabled", Invite:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		main_frame.switch_auto_ainvite = auto_ainvite_switch
		auto_ainvite_switch:SetAsCheckBox()
		auto_ainvite_label:SetPoint("topleft", profilesConfigBgFrame, "topleft", configXStart, -150) --POINT
		
		--> only from guild
		local on_auto_ainvite_guild_switch = function (_, _, value)
			Invite.db.auto_accept_invites_limited = value
		end
		local auto_ainvite_guild_switch, auto_ainvite_guild_label = DF:CreateSwitch (profilesConfigBgFrame, on_auto_ainvite_guild_switch, Invite.db.auto_accept_invites_limited, _, _, _, _, "switch_auto_ainvite_guild", _, _, _, _, "Only From Guild and Friends", Invite:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		main_frame.switch_auto_ainvite_guild = auto_ainvite_guild_switch
		auto_ainvite_guild_switch:SetAsCheckBox()
		auto_ainvite_guild_label:SetPoint("topleft", profilesConfigBgFrame, "topleft", configXStart, -170) --POINT

        --> invite message repeats
		--> welcome msg
		local welcome_text5 = DF:CreateLabel (profilesConfigBgFrame, "Repeat the invite announcement with each wave?", Invite:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
		welcome_text5:SetPoint("topleft", profilesConfigBgFrame, "topleft", configXStart, -210)
		welcome_text5.fontsize = 14

		--> enabled
		local on_invite_msg_repeats_switch = function (_, _, value)
		    Invite.db.invite_msg_repeats = value
		end
		local invite_msg_repeats_switch, invite_msg_repeats_label = DF:CreateSwitch (profilesConfigBgFrame, on_invite_msg_repeats_switch, Invite.db.invite_msg_repeats, _, _, _, _, "switch_invite_msg_repeats", _, _, _, _, "Enabled", Invite:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		main_frame.switch_invite_msg_repeats = invite_msg_repeats_switch
		invite_msg_repeats_switch:SetAsCheckBox()
		invite_msg_repeats_label:SetPoint("topleft", profilesConfigBgFrame, "topleft", configXStart, -230) --POINT

	--> interval between each wave
		--> welcome msg
		local welcome_text6 = DF:CreateLabel (profilesConfigBgFrame, "Interval in seconds between each invite wave.", Invite:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
		welcome_text6:SetPoint("topleft", profilesConfigBgFrame, "topleft", configXStart, -270) --POINT
		welcome_text6.fontsize = 14

		local invite_interval_slider, invite_interval_label = DF:CreateSlider(profilesConfigBgFrame, 180, 20, 20, 180, 1, Invite.db.invite_interval, _, "InviteInterval", _, "Inverval", Invite:GetTemplate ("slider", "OPTIONS_SLIDER_TEMPLATE"), Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		invite_interval_label:SetPoint("topleft", profilesConfigBgFrame, "topleft", configXStart, -290) --POINT
		invite_interval_slider.OnValueChanged = function (_, _, value)
			Invite.db.invite_interval = value
		end
		invite_interval_slider.thumb:SetWidth(22)


	-------------- end
	
	------- functions
	
	--> create panel
	function Invite:DisableCreatePanel()
		panel.button_create_preset:Disable()
		editbox_preset_name:Disable()
		dropdown_diff:Disable()
		editbox_masterloot_name:Disable()
		editbox_raidleader_name:Disable()
		
		dropdown_keep_auto_invite:Disable()
		panel.switch_auto_invite:Disable()
		dropdown_schedule_select:Disable()
		
		for _, switch in ipairs (switchers) do
			switch:Disable()
		end

		panel.msgToSendToPlayersEditbox:Disable()
	end
	
	function Invite:EnableCreatePanel()
		panel.button_create_preset:Enable()
		editbox_preset_name:Enable()
		dropdown_diff:Enable()
		editbox_masterloot_name:Enable()
		editbox_raidleader_name:Enable()
		
		dropdown_keep_auto_invite:Enable()
		panel.switch_auto_invite:Enable()
		dropdown_schedule_select:Enable()
		
		for _, switch in ipairs (switchers) do
			switch:Enable()
		end
		
		panel.msgToSendToPlayersEditbox:Enable()
		panel.dropdown_schedule:Refresh()
	end
	
	function Invite:DisableInviteButtons()
		for i = 1, #preset_buttons do
			--preset_buttons[i]:Disable()
		end
		create_button:Disable()
		button_edit:Disable()
		button_remove:Disable()
		dropdown_edit:Disable()
		dropdown_remove:Disable()
	end
	
	function Invite:EnableInviteButtons()
		for i = 1, #preset_buttons do
			preset_buttons[i]:Enable()
		end
		create_button:Enable()
		button_edit:Enable()
		button_remove:Enable()
		dropdown_edit:Enable()
		dropdown_remove:Enable()
	end	
	
	--disable the create panel at menu creation
	Invite:DisableCreatePanel()
	main_frame:RefreshPresetButtons()
	
end


RA:InstallPlugin(Invite.displayName, "RAInvite", Invite, default_config)

local check_lootandleader = function()
	if (Invite.auto_invite_preset or Invite.invite_preset) then
		Invite:CheckMasterLootForPreset (Invite.auto_invite_preset or Invite.invite_preset)
		Invite:CheckRaidLeaderForPreset (Invite.auto_invite_preset or Invite.invite_preset)
	end
end

function Invite:SetRaidDifficultyForPreset (preset)
	local diff = preset.difficulty
	if (diff == "mythic" or diff == 16) then
		SetRaidDifficultyID (16)
	elseif (diff == "heroic" or diff == 15) then
		SetRaidDifficultyID (15)
	elseif (diff == "normal" or diff == 14) then
		SetRaidDifficultyID (14)
	end
end

function Invite:CheckRaidLeaderForPreset (preset)
	if (preset.raidleader and preset.raidleader ~= "") then
		local ImLeader = UnitIsGroupLeader ("player")
		if (ImLeader and UnitInRaid (preset.raidleader)) then
			PromoteToLeader (preset.raidleader)
			print ("Promoting ", preset.raidleader, "to leader.")
		end
	end
end

function Invite:CheckMasterLootForPreset (preset)
	if (preset.masterloot and preset.masterloot ~= "" and UnitIsGroupLeader ("player")) then
		--split the names of people in the raid
		local allAssistants = {}
		local splitBySpace = {strsplit (" ", preset.masterloot)}

		for _, playerName in ipairs (splitBySpace) do
			local masterloot_name = Ambiguate (playerName, "none")
			if (UnitInRaid (masterloot_name)) then

				if (not RA:UnitHasAssist (masterloot_name)) then
					PromoteToAssistant (masterloot_name)
					print ("|cFFFFDD00RaidAssist (/raa):|cFFFFFF00 " .. masterloot_name .. " now has assist.|r")
				end
				
				--[=[ let's preserve the master loot code just in case...
				local lootmethod, masterlooterPartyID, masterlooterRaidID = GetLootMethod()
				if (lootmethod ~= master) then
					SetLootMethod ("master", masterloot_name)
				else
					local masterloot = UnitName ("raid" .. masterlooterRaidID)
					if (not masterloot or masterloot ~= Ambiguate (preset.masterloot, "none")) then
						SetLootMethod ("master", masterloot_name)
					end
				end
				--]=]
			end
		end
	end
end

local redo_invites = function()
	Invite.DoInvitesForPreset(Invite.invite_preset)
end

function Invite:GROUP_ROSTER_UPDATE()
	if (not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_HOME)) then
		if (GetNumGroupMembers() > 1) then

			Invite:UnregisterEvent("GROUP_ROSTER_UPDATE")
			C_PartyInfo.ConvertToRaid()

			Invite:SetRaidDifficultyForPreset(Invite.invite_preset)

			if (Invite.CanRedoInvites) then
				Invite.CanReroInvites = nil
				--print ("Converted to raid, redoing invites.")
				C_Timer.After(10, check_lootandleader)
				C_Timer.After(2, redo_invites)
			end
		end
	elseif (IsInRaid(LE_PARTY_CATEGORY_HOME)) then
		Invite:UnregisterEvent("GROUP_ROSTER_UPDATE")
	end
end

local doDelayedInvite = function(timerObject)
	local playerName = timerObject.playerName
	C_PartyInfo.InviteUnit(playerName)
end

function Invite.DoInvitesForPreset(preset)
	if (not preset) then
		Invite:Msg ("Invite thread is invalid, please cancel and re-start.")
		return
	end

	local guildRosterIsShowingAll = GetGuildRosterShowOffline()
	local inRaid, playerIsInGroup = IsInRaid(LE_PARTY_CATEGORY_HOME), IsInGroup(LE_PARTY_CATEGORY_HOME)
	if (not inRaid) then
		Invite:RegisterEvent("GROUP_ROSTER_UPDATE")
	end

	local invitesSent = 0

	if (not inRaid) then
		--> we should invite few guys, convert on raid and invite everyone else after that		
		for i = 1, select(guildRosterIsShowingAll and 1 or 3, GetNumGuildMembers()) do
			local name, rankName, rankIndex, level, classDisplayName, zone, _, _, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding, GUID = GetGuildRosterInfo(i)
			name = Ambiguate(name, "none")

			if (preset.ranks[rankIndex+1] and isOnline and not isMobile) then
				if ((inRaid and not UnitInRaid(name)) or (playerIsInGroup and not UnitInParty(name)) or (not inRaid and not playerIsInGroup)) then
					if (not UnitIsUnit(name, "player")) then
						invitesSent = invitesSent + 1

						local delay = invitesSent*500/1000
						local newTimer = C_Timer.NewTimer(delay, doDelayedInvite)
						newTimer.playerName = name

						if (invitesSent >= 4) then
							break
						end
					end
				end
			end
		end

		Invite.CanRedoInvites = true
	else
		for i = 1, select (guildRosterIsShowingAll and 1 or 3, GetNumGuildMembers()) do
			local name, rankName, rankIndex, level, classDisplayName, zone, _, _, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding, GUID = GetGuildRosterInfo(i)
			name = Ambiguate(name, "none")

			if (preset.ranks [rankIndex+1] and isOnline and not isMobile) then
				if ((inRaid and not UnitInRaid(name)) or (playerIsInGroup and not UnitInParty(name)) or (not inRaid and not playerIsInGroup)) then
					if (not UnitIsUnit(name, "player")) then
						invitesSent = invitesSent + 1
						local newTimer = C_Timer.NewTimer(invitesSent*500/1000, doDelayedInvite)
						newTimer.playerName = name
					end
				end
			end
		end
	end
end

function Invite.AutoInviteTick()
	Invite.auto_invite_wave_time = Invite.auto_invite_wave_time - 1
	Invite.auto_invite_ticks = Invite.auto_invite_ticks - 1
	
	if (Invite.auto_invite_wave_time == 15) then
		C_GuildInfo.GuildRoster()
		
	--elseif (Invite.auto_invite_wave_time == 5) then
	elseif (Invite.db.invite_msg_repeats and Invite.auto_invite_wave_time == 5) then
		Invite:SendInviteAnnouncementMsg()
		
	elseif (Invite.auto_invite_wave_time == 0) then
		Invite.auto_invite_frame.statusbar:SetTimer (Invite.db.invite_interval + 1)
		Invite.auto_invite_wave_number = Invite.auto_invite_wave_number + 1
		
		Invite.auto_invite_frame.statusbar.lefttext = "next wave (" .. Invite.auto_invite_wave_number .. ") in:"
		Invite.auto_invite_wave_time = Invite.db.invite_interval - 1
		
		Invite.DoInvitesForPreset (Invite.auto_invite_preset)
		
		Invite:CheckMasterLootForPreset (Invite.auto_invite_preset)
		Invite:CheckRaidLeaderForPreset (Invite.auto_invite_preset)
		C_Timer.After (10, check_lootandleader)
		
		if (Invite.auto_invite_ticks < 0) then
			Invite:StopAutoInvites()
		end
	end
end

function Invite:StopAutoInvites()
	Invite.auto_invite_ticket:Cancel()
	Invite.auto_invite_ticket = nil
	Invite.invites_in_progress = nil
	Invite.auto_invite_preset = nil
	Invite.invite_preset = nil
	Invite.auto_invite_frame:Hide()
	Invite:UnregisterEvent ("GROUP_ROSTER_UPDATE")
	
	--> check first in case the options panel isn't loaded yet
	if (Invite.EnableInviteButtons) then
		Invite:EnableInviteButtons()
	end
end

local do_first_wave = function()
	Invite.DoInvitesForPreset(Invite.invite_preset)
end

function Invite:StartInvitesAuto(preset, remaining)
	if (Invite.invites_in_progress) then
		RA:Msg("There's an invite already in progress.")
		return
	end

	C_GuildInfo.GuildRoster()

	if (not Invite.auto_invite_frame) then
		Invite.auto_invite_frame = RA:CreateCleanFrame (Invite, "AutoInviteFrame")
		Invite.auto_invite_frame:SetSize (205, 58)
		
		Invite.auto_invite_frame.preset_name = Invite:CreateLabel (Invite.auto_invite_frame, "", Invite:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		Invite.auto_invite_frame.preset_name:SetPoint (10, -10)
		
		Invite.auto_invite_frame.statusbar = Invite:CreateBar (Invite.auto_invite_frame, LibStub:GetLibrary ("LibSharedMedia-3.0"):Fetch ("statusbar", "Iskar Serenity"), 167, 16, 50)
		Invite.auto_invite_frame.statusbar:SetPoint (10, -25)
		Invite.auto_invite_frame.statusbar.fontsize = 11
		Invite.auto_invite_frame.statusbar.fontface = "Accidental Presidency"
		Invite.auto_invite_frame.statusbar.fontcolor = "darkorange"
		Invite.auto_invite_frame.statusbar.color = "gray"
		Invite.auto_invite_frame.statusbar.texture = "Iskar Serenity"
		
		Invite.auto_invite_frame.cancel = Invite:CreateButton (Invite.auto_invite_frame, Invite.StopAutoInvites, 16, 16, "", _, _, [[Interface\Buttons\UI-GroupLoot-Pass-Down]])
		Invite.auto_invite_frame.cancel:SetPoint ("left", Invite.auto_invite_frame.statusbar, "right", 2, 0)
	end
	
	Invite.invites_in_progress = true
	Invite.auto_invite_frame.preset_name.text = "Invites in Progress: " .. preset.name
	
	Invite.invite_preset = preset
	Invite.auto_invite_preset = preset
	Invite.auto_invite_wave_number = 2
	Invite.auto_invite_wave_time = Invite.db.invite_interval - 1
	Invite.auto_invite_ticks = remaining
	
	Invite.auto_invite_frame.statusbar:SetTimer (Invite.db.invite_interval + 1)
	Invite.auto_invite_frame.statusbar.lefttext = "next wave (" .. Invite.auto_invite_wave_number .. ") in:"
	
	Invite:SetRaidDifficultyForPreset (preset)
	
	Invite.auto_invite_frame:Show()
	Invite.auto_invite_ticket = C_Timer.NewTicker (1, Invite.AutoInviteTick)

	--wait to guild roster
	Invite:SendInviteAnnouncementMsg()
	C_Timer.After (5, do_first_wave)
end

local finish_invite_wave = function()
	Invite.invite_preset = nil
	Invite.invites_in_progress = nil

	--> check first in case the options panel isn't loaded yet
	if (Invite.EnableInviteButtons) then
		Invite:EnableInviteButtons()
	end
end

function Invite:StartInvites(preset_number)
	if (Invite.invites_in_progress) then
		RA:Msg("There's an invite already in progress.")
		return
	end

	local preset = Invite:GetPreset(preset_number)
	if (preset) then
		--Invite:DisableInviteButtons()

		if (preset.keepinvites and preset.keepinvites > 0) then
			local invite_time = preset.keepinvites * 60
			return Invite:StartInvitesAuto(preset, invite_time)

		else
			C_GuildInfo.GuildRoster()
			Invite.invites_in_progress = true
			Invite.invite_preset = preset
			Invite:SendInviteAnnouncementMsg()
			C_Timer.After(4, do_first_wave)
			C_Timer.After(60, finish_invite_wave)
		end
	end
end

function Invite.CheckForAutoInvites()
	if (not IsInGuild()) then
		return
	end
	
	--get the raid schedule plugin
	local RaidSchedule = _G ["RaidAssistRaidSchedule"]
	if (RaidSchedule) then
		local now = time()
		for index, preset in ipairs (Invite:GetAllPresets()) do 
			--this invite preset has a schedule?
			if (preset.autostart) then
				
				local core, index = RaidSchedule:GetRaidScheduleTableByName (preset.autostartcore)
				
				if (core) then
					local next_event_in, start_time, end_time, day, month_number, month_day = RaidSchedule:GetNextEventTime (index)
					local keep_invites = preset.keepinvites or 15

					if (next_event_in <= (keep_invites*60) and next_event_in > 1) then --problem here, next_event_in is nil
						local invite_time = (keep_invites and keep_invites > 0 and keep_invites * 60 or false) or (next_event_in > 121 and next_event_in or 121)
						print ("|cFFFFDD00RaidAssist (/raa):|cFFFFFF00 starting auto invites.|r")
						return Invite:StartInvitesAuto (preset, invite_time)
						
					elseif (next_event_in > (keep_invites*60)) then
						Invite.NextCheckTimer = C_Timer.NewTimer (next_event_in - ((keep_invites*60)-1), Invite.CheckForAutoInvites)
					end

					--return Invite:StartInvitesAuto (preset, 180) --debug
				end
			end
		end
	end
end

function Invite:SendInviteAnnouncementMsg()
	SendChatMessage (Invite.db.invite_msg, "GUILD")
end
