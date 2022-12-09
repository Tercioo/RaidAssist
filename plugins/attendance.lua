
local RA = _G.RaidAssist
local L = LibStub ("AceLocale-3.0"):GetLocale ("RaidAssistAddon")
local _
local default_priority = 10
local GetUnitName = GetUnitName
local GetGuildInfo = GetGuildInfo

local default_config = {
	raidschedules = {},
	playerids = {},
	menu_priority = 2,
	sorting_by = 1,
}

local Attendance = {version = "v0.1", pluginname = "Attendance", pluginId = "ATTE", displayName = L["S_PLUGIN_ATTENDANCE_NAME"]}
_G ["RaidAssistAttendance"] = Attendance
local RaidSchedule

Attendance.debug = false
--Attendance.debug = true

--const settings
local iconTexCoord = {l=50/512, r=86/512, t=362/512, b=406/512}
local iconTexture = [[Interface\Scenarios\ScenariosParts]]
local textColorEnabled = {r=1, g=1, b=1, a=1}
local textColorDisabled = {r=0.5, g=0.5, b=0.5, a=1}

local week1, week2, week3, week4, week5, week6, week7 = "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"
local emptyFunc = function()end

Attendance.menu_text = function (plugin)
	if (Attendance.db.enabled) then
		return iconTexture, iconTexCoord, L["S_PLUGIN_ATTENDANCE_NAME"], textColorEnabled
	else
		return iconTexture, iconTexCoord, L["S_PLUGIN_ATTENDANCE_NAME"], textColorDisabled
	end
end

Attendance.menu_popup_hide = function(plugin, ct_frame, param1, param2)
	local popupFrame = Attendance.popup_frame
	popupFrame:Hide()
end

Attendance.menu_on_click = function (plugin)
	--if (not Attendance.options_built) then
	--	Attendance.BuildOptions()
	--	Attendance.options_built = true
	--end
	--Attendance.main_frame:Show()

	RA.OpenMainOptions(Attendance)
end

Attendance.StartUp = function()
	Attendance.player_name = GetUnitName("player")

	if (not Attendance.player_name) then
		C_Timer.After(0.5, function() Attendance.StartUp() end)
		return
	end

	RaidSchedule = _G["RaidAssistRaidSchedule"]
	if (not RaidSchedule) then
		C_Timer.After(0.5, function() Attendance.StartUp() end)
		return
	end

	Attendance:CheckForNextEvent()
	Attendance.need_popup_update = true
end

Attendance.OnInstall = function (plugin)
	local popupFrame = Attendance.popup_frame
	popupFrame.label_no_data = RA:CreateLabel(popupFrame, L["S_PLUGIN_ATTENDANCE_NO_DATA"], Attendance:GetTemplate("font", "ORANGE_FONT_TEMPLATE"))
	popupFrame.label_no_data:SetPoint ("center", popupFrame, "center")
	popupFrame.label_no_data.width = 130
	popupFrame.label_no_data.height = 40

	Attendance.db.menu_priority = default_priority

	C_Timer.After(2, Attendance.StartUp)
end

function Attendance:CheckOldTables()
	local removed = 0
	for id, attendanceTable in pairs(Attendance.db.raidschedules) do
		for day, dayTable in pairs(attendanceTable) do
			if (dayTable.t + 2592000 < time()) then
				attendanceTable[day] = nil
				removed = removed + 1
			end
		end
	end
end

Attendance.OnEnable = function (plugin)
end

Attendance.OnDisable = function (plugin)
end

Attendance.OnProfileChanged = function (plugin)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Attendance:GetAttendanceTable(index)
	return Attendance.db.raidschedules[index]
end

function Attendance:OnFinishCapture()
	Attendance:Msg("raid time ended.")
	Attendance.need_popup_update = true
end

function Attendance:Msg(...)
	if (Attendance.debug) then
		print("|cFFFFDD00Attendance|r:", ...)
	end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Attendance.OnShowOnOptionsPanel()
	local OptionsPanel = Attendance.OptionsPanel
	Attendance.BuildOptions(OptionsPanel)
end

function Attendance.BuildOptions(frame)
	if (frame.FirstRun) then
		Attendance.update_attendance()
		return
	end

	frame.FirstRun = true

	local sortByAlphabetical = function(a, b) return a[1] < b[1] end
	local sortByBigger = function(a, b) return a[2] > b[2] end

	local fillPanel = Attendance:CreateFillPanel(frame, {}, 790, 400, false, false, false, {rowheight = 16}, "FillPanel", "AttendanceFillPanel")
	fillPanel:SetPoint("topleft", frame, "topleft", 10, -30)

	local advisePanel = CreateFrame("frame", nil, frame, "BackdropTemplate")
	advisePanel:SetPoint("center", frame, "center", 790/2, -400/2)
	advisePanel:SetSize(460, 68)
	advisePanel:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
	advisePanel:SetBackdropColor(1, 1, 1, .5)
	advisePanel:SetBackdropBorderColor(0, 0, 0, 1)

	local advisePanelText = advisePanel:CreateFontString(nil, "overlay", "GameFontNormal")
	advisePanelText:SetPoint("center", advisePanel, "center")
	Attendance:SetFontSize(advisePanelText, 11)

	--box with the attendance tables
	Attendance.update_attendance = function()
		local scheduleId = frame.dropdown_schedule_list:GetValue()
		local currentDB = Attendance.db.raidschedules [scheduleId] -- Attendance.db.raidschedules = scheduleId - days table
		--local _, current_db = next(Attendance.db.raidschedules) -- Attendance.db.raidschedules = scheduleId - days table

		if (currentDB) then
			--short from oldest to newer
			local alphabeticalMonths = {}
			for key, table in pairs(currentDB) do
				local month, day = key:match("(%d+)-(%d+)")
				if (string.len(day) == 1) then
					day = "0" .. day
				end
				local value = tonumber(month .. day)
				tinsert(alphabeticalMonths, {key, table, value})
			end

			table.sort(alphabeticalMonths, function (t1, t2) return t2[3] < t1[3] end)

			--add the two initial headers for player name and total attendance
			local header = {{name = "Player Name", type = "text", width = 120}, {name = "ATT", type = "text", width = 60}}
			local players = {}
			local playersIndex = {}
			local daysAmount = 0
			local sort = table.sort

			local maxDays = 20

			for i, table in ipairs(alphabeticalMonths) do
				local month = table[1]
				local attendanceTable = table[2]

				daysAmount = daysAmount + 1
				if (daysAmount > maxDays) then
					break
				end

				--add the header for this vertical row
				local timeAt = date("%a", attendanceTable.t)

				tinsert(header, {name = table[1] .. "\n" .. timeAt .. "", type = "text", width = 30, textsize = 9, textalign = "center", header_textsize = 9, header_textalign = "center"})

				for playerId, playerPoints in pairs(attendanceTable.players) do
					local index = playersIndex[playerId]
					local player

					if (not index) then
						local playerName = Attendance:GetPlayerNameFromId(playerId)

						--first match for this player, fill the previous days with "-"
						player = {playerName, 0}
						for o = 1, i-1 do
							tinsert(player, "-")
						end

						tinsert(player, playerPoints)
						player[2] = player[2] + playerPoints

						tinsert(players, player)
						playersIndex[playerId] = #players
					else
						player = players[index]

						--fill the player table if he missed some days
						for o = #player+1, i-1 do
							tinsert(player, "-")
						end

						player[2] = player[2] + playerPoints
						tinsert(player, playerPoints)
					end
				end
			end

			--fill the player table is he missed all days until the end
			for index, playerTable in ipairs(players) do
				for i = #playerTable - 1, daysAmount do
					tinsert(playerTable, "-")
				end
			end

			if (not Attendance.db.sorting_by or Attendance.db.sorting_by == 1) then
				sort(players, sortByAlphabetical)

			elseif (Attendance.db.sorting_by == 2) then
				sort(players, sortByBigger)
			end

			frame.FillPanel:SetFillFunction(function(index) return players[index] end)
			frame.FillPanel:SetTotalFunction(function() return #players end)

			frame:SetSize(math.min(GetScreenWidth()-200, (#header*60) + 60), 425)
			frame.FillPanel:SetSize(math.min(GetScreenWidth()-200, (#header*60) + 60), 425)
			frame.FillPanel:UpdateRows(header)
			frame.FillPanel:Refresh()
			frame.FillPanel:Show()

			advisePanel:Hide()
		else
			if (RaidSchedule and next(RaidSchedule.db.cores)) then
				advisePanelText:SetText("No attendance has been recorded yet.")
			else
				advisePanelText:SetText("No attendance has been recorded yet, make sure to create a Raid Schedule.\nAttendance is automatically captured during your raid once a schedule is set.")
			end

			advisePanel:Show()
			frame.FillPanel:Hide()
		end
	end

	local onSelectScheduleCallback = function(_, _, scheduleId)
		Attendance.update_attendance()
	end

	local buildScheduleList = function()
		local listOfSchedules = {}
		for raidScheduleIndex, scheduleTable in pairs(Attendance.db.raidschedules) do
			local schedule = RaidSchedule:GetRaidScheduleTable(raidScheduleIndex)
			if (schedule) then
				tinsert(listOfSchedules, {value = raidScheduleIndex, label = schedule.core_name, onclick = onSelectScheduleCallback})
			end
		end
		return listOfSchedules
	end

	local labelRaidSchedule = Attendance:CreateLabel(frame, "Schedule" .. ": ", Attendance:GetTemplate("font", "OPTIONS_FONT_TEMPLATE"))
	local dropdownRaidSchedule = Attendance:CreateDropDown(frame, buildScheduleList, 1, 160, 20, "dropdown_schedule_list", _, Attendance:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
	dropdownRaidSchedule:SetPoint("left", labelRaidSchedule, "right", 2, 0)
	labelRaidSchedule:SetPoint(10, -10)
	dropdownRaidSchedule:Refresh()
	dropdownRaidSchedule:Select(1, true)

	local confirmResetCallback = function(text)
		local scheduleId = frame.dropdown_schedule_list:GetValue()
		if (not scheduleId) then
			return
		end

		local currentDB = Attendance.db.raidschedules[scheduleId]
		if (currentDB) then
			for key, table in pairs(currentDB) do
				currentDB[key] = nil
			end
		end

		Attendance.update_attendance()
	end

	local resetCallback = function()
		Attendance:ShowPromptPanel("Are you sure you want to reset?", confirmResetCallback, emptyFunc)
		--Attendance:ShowTextPromptPanel("Are you sure you want to reset?(type 'yes')", reset_func_callback)
	end

	local resetButton =  Attendance:CreateButton(frame, resetCallback, 80, 20, "Reset", _, _, _, "button_reset", _, _, Attendance:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Attendance:GetTemplate("font", "OPTIONS_FONT_TEMPLATE"))
	resetButton:SetPoint("left", dropdownRaidSchedule, "right", 10, 0)
	resetButton:SetIcon([[Interface\BUTTONS\UI-StopButton]], 14, 14, "overlay", {0, 1, 0, 1}, {1, 1, 1}, 2, 1, 0)

	local sort1Button =  Attendance:CreateButton(frame, function() Attendance.db.sorting_by = 1; Attendance.update_attendance() end, 80, 20, "Sort A-Z", _, _, _, "button_sort1", _, _, Attendance:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Attendance:GetTemplate("font", "OPTIONS_FONT_TEMPLATE"))
	sort1Button:SetPoint("left", resetButton, "right", 2, 0)
	sort1Button:SetIcon([[Interface\BUTTONS\UI-StopButton]], 14, 14, "overlay", {0, 1, 0, 1}, {1, 1, 1}, 2, 1, 0)

	local sort2Button =  Attendance:CreateButton(frame, function() Attendance.db.sorting_by = 2; Attendance.update_attendance() end, 80, 20, "Sort ATT", _, _, _, "button_sort2", _, _, Attendance:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Attendance:GetTemplate("font", "OPTIONS_FONT_TEMPLATE"))
	sort2Button:SetPoint("left", sort1Button, "right", 2, 0)
	sort2Button:SetIcon([[Interface\BUTTONS\UI-StopButton]], 14, 14, "overlay", {0, 1, 0, 1}, {1, 1, 1}, 2, 1, 0)

	frame:SetScript("OnShow", function()
		Attendance.update_attendance()
		dropdownRaidSchedule:Refresh()
		--dropdown_raidschedule:Select (1, true)
	end)

	Attendance.update_attendance()
end

RA:InstallPlugin(Attendance.displayName, "RAAttendance", Attendance, default_config)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Attendance:CheckForNextEvent()
	local nestEventIn, startTime, endTime, day, monthNumber, monthDay, index = RaidSchedule:GetNextEventTime()
	if (nestEventIn) then
		Attendance:Msg("Attendance Next Event:", nestEventIn)

		local now = time()
		if (now < nestEventIn) then
			C_Timer.After(nestEventIn+1, Attendance.CheckForNextEvent)
			Attendance:Msg("Nop, next event is too far away.")

		elseif (nestEventIn == 0) then --return 0 if time() is bigger than the start time
			if (Attendance.is_capturing) then
				Attendance:Msg("Is already capturing.")
				return
			else
				Attendance:Msg("Need to start capturing.")
				Attendance:StartNewCapture(startTime, endTime, now, day, monthNumber, monthDay, index)
			end
		end
	else
		C_Timer.After(60, Attendance.CheckForNextEvent)
	end
end

function Attendance:CaptureIsOver()
	--clean up
	Attendance.capture_ticker = nil
	Attendance.is_capturing = nil
	Attendance.db_table = nil
	Attendance.player_table = nil
	Attendance.guild_name = nil

	--on finish
	Attendance:OnFinishCapture()

	--check next event
	C_Timer.After(5, Attendance.CheckForNextEvent)
end

function Attendance:GetPlayerID(unitid)
	local guid = UnitGUID(unitid)
	if (guid) then
		return guid:gsub("^.*-", "")
	end
end

function Attendance:GetPlayerNameFromId(id)
	return Attendance.db.playerids[id] or id
end

function Attendance:StartNewCapture(startTime, endTime, now, day, monthNumber, monthDay, raidScheduleIndex)
	--get the raidschedule table from the database
	local db = Attendance.db.raidschedules[raidScheduleIndex]
	if (not db) then
		Attendance.db.raidschedules[raidScheduleIndex] = {}
		db = Attendance.db.raidschedules[raidScheduleIndex]
	end

	--get 'todays' key id
	local key = "" .. monthNumber .. "-" .. monthDay

	--get the GUID table with the 'todays' attendance
	local ctable = db[key]
	if (not ctable) then
		db[key] = {t = time(), players = {}}
		ctable = db[key]
	end

	Attendance.is_capturing = true
	Attendance.db_table = db
	Attendance.player_table = ctable
	Attendance.guild_name = GetGuildInfo("player")

	local ticks = math.floor((endTime - time()) / 60) --usava 'start_time' ao inv�s de time(), mas se der /reload ou entrar na j� em andamento vai zuar o tempo total da captura.
	Attendance:StartCapture(ticks)
	Attendance:Msg("Raid time started.", ticks)
end

local doCaptureTick = function(tickObject)
	local playerAmount = 0

	if (IsInRaid()) then
		local guildName = Attendance.guild_name --string guild name
		local playerTable = Attendance.player_table.players --holds [player id] = number
		local namePool = Attendance.db.playerids

		for i = 1, GetNumGroupMembers() do
			local playerGuild = GetGuildInfo("raid" .. i)
			if (playerGuild == Attendance.guild_name) then
				local id = Attendance:GetPlayerID("raid" .. i)
				if (id) then
					playerTable[id] = (playerTable[id] or 0) + 1
					playerAmount = playerAmount + 1
					if (not namePool[id]) then
						namePool[id] = GetUnitName("raid" .. i, true)
					end
				end
			end
		end
	end

	Attendance:Msg("Tick", playerAmount, "counted.")
	Attendance.capture_ticker.iterations = Attendance.capture_ticker.iterations - 1

	if (Attendance.capture_ticker.iterations <= 0) then
		--it's over
		Attendance:CaptureIsOver()
	end
end

function Attendance:StartCapture(ticks)
	-- cancel any tick ongoing
	if (Attendance.capture_ticker and not Attendance.capture_ticker._cancelled) then
		Attendance.capture_ticker:Cancel()
		Attendance:Msg("Capture ticker is true, cancelling and starting a new one.")
	end

	-- start the ticker
	Attendance.capture_ticker = C_Timer.NewTicker(60, doCaptureTick, ticks-1)
	Attendance.capture_ticker.iterations = ticks-1
	Attendance:Msg("Capture ticker has been started.")
end
