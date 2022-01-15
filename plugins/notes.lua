
local RA = _G.RaidAssist
local L = _G.LibStub ("AceLocale-3.0"):GetLocale ("RaidAssistAddon")
local _
local default_priority = 120
local DF = DetailsFramework
local DetailsFramework = DF

local Notepad = {version = 1, pluginname = "Notes", pluginId = "NOTE", displayName = "Raid Assignments"}
_G ["RaidAssistNotepad"] = Notepad
_G ["RANotes"] = Notepad

local default_config = {
	notes = {},
	currently_shown = false,
	currently_shown_time = 0,
	currently_shown_noteId = 0,
	text_size = 12,
	text_face = "Friz Quadrata TT",
	text_justify = "left",
	text_shadow = false,
	framestrata = "LOW",
	locked = false,
	background = {r=0, g=0, b=0, a=0.8, show = true},
	hide_on_combat = false,
	auto_format = true,
	auto_complete = true,
	editing_boss_id = 0,
	editing_boss_note_id = 0,
	boss_notes2 = {},
	latest_menu_option_boss_selected = 0,
	latest_menu_option_note_selected = 0,
	can_scroll_to_phase = true,
	dbm_boss_timers = {},
	bw_boss_timers = {},
	bar_texture = "You Are Beautiful!",
	editor_alpha = 0.5,
}

local CONST_MACRO_INDEXNAME = 1
local CONST_MACRO_INDEXVALUE = 2
local CONST_PROGRESSBAR_DEFAULT_TIME = 7
local CONST_EDITBOX_WIDTH = 446
local CONST_EDITBOX_HEIGHT = 615
local CONST_EDITBOX_WIDTH_MAX = 610
local CONST_EDITBOX_HEIGHT_MAX = 615
local CONST_EDITBOX_COLOR = {.6, .6, .6, .5}

local allRoles = {"DAMAGER", "TANK", "HEALER"}

local icon_texture
local icon_texcoord = {l=4/32, r=28/32, t=4/32, b=28/32}
local text_color_enabled = {r=1, g=1, b=1, a=1}
local text_color_disabled = {r=0.5, g=0.5, b=0.5, a=1}

local COMM_QUERY_SEED = "NOQI"
local COMM_QUERY_NOTE = "NOQN"
local COMM_RECEIVED_SEED = "NORI"
local COMM_RECEIVED_FULLNOTE = "NOFN"

local scrollBossWidth = 200
local scrollBossHeight = 659
local bossLinesHeight = 40
local amoutBossLines = floor(scrollBossHeight / bossLinesHeight)

local scrollbox_line_backdrop_color = {0, 0, 0, 0.5}
local scrollbox_line_backdrop_color_hightlight = {.4, .4, .4, 0.6}
local scrollbox_line_backdrop_color_selected = {.7, .7, .7, 0.8}

local unitInGroup = function(unitToken)
	return UnitInParty(unitToken) or UnitInRaid(unitToken)
end

local isRaidLeader = function (sourceUnit)
	if (type (sourceUnit) == "string") then
		return Notepad:UnitHasAssist(sourceUnit)
	end
end

local isConnected = function (sourceUnit)
	if (type (sourceUnit) == "string") then
		return UnitIsConnected (sourceUnit) or UnitIsConnected (sourceUnit:gsub ("%-.*", ""))
	end
end

if (UnitFactionGroup("player") == "Horde") then
	icon_texture = [[Interface\WorldStateFrame\HordeFlag]]
else
	icon_texture = [[Interface\WorldStateFrame\AllianceFlag]]
end

Notepad.menu_text = function (plugin)
	if (Notepad.db.enabled) then
		return icon_texture, icon_texcoord, "Raid Assignments", text_color_enabled
	else
		return icon_texture, icon_texcoord, "Raid Assignments", text_color_disabled
	end
end

Notepad.menu_popup_show = function (plugin, ct_frame, param1, param2)
	RA:AnchorMyPopupFrame (Notepad)
end

Notepad.menu_popup_hide = function (plugin, ct_frame, param1, param2)
	Notepad.popup_frame:Hide()
end

Notepad.menu_on_click = function (plugin)
	RA.OpenMainOptions (Notepad)
end

Notepad.PLAYER_LOGIN = function()
	--need to wait till encounter journal is loaded
	Notepad:BuildBossList()
	C_Timer.After(1, function()
		Notepad:BuildBossList()
	end)
	C_Timer.After(3, function()
		Notepad:BuildBossList()
	end)

	--check if it was showing a note on screen
	C_Timer.After(5, function()
		local bossId, shownAt, noteId = Notepad:GetCurrentlyShownBoss()
		if (bossId and shownAt) then
			if (shownAt+60 > time()) then
				Notepad:ShowNoteOnScreen(bossId, noteId)
			else
				Notepad:UnshowNoteOnScreen()
			end
		end
	end)
end

function Notepad.InstallBossModsHandlers()
	--dbm
    if (_G.DBM) then
        local DBMCallbackPhase = function(event, msg, ...)
            if (event == "DBM_Announce") then
                if (msg:find("Stage")) then
					local currentPhase = Notepad.GetCurrentEncounterData().phase

					if (currentPhase) then
						msg = msg:gsub("%a", "")
						msg = msg:gsub("%s+", "")
						local phase = tonumber(msg)

						if (phase and type(phase) == "number") then
							if (currentPhase ~= phase) then
								--phase has been changed
								local oldPhase = currentPhase
								Notepad.OnPhaseChanged(oldPhase, phase)
							end
						end
					end
                end
            end
        end

        DBM:RegisterCallback("DBM_Announce", DBMCallbackPhase)

		if (_G.DBM) then
			local DBMCallbackTimer = function(bar_type, id, msg, timer, icon, bartype, spellId, colorId, modid)
				local spell = tostring(spellId)
				local encounterData = Notepad.GetCurrentEncounterData()
				if (encounterData) then
					local encounterIdCL = encounterData.encounterIdCL
					local encounterIdEJ = encounterData.encounterIdEJ
					--store the timer in the database
					Notepad.db.dbm_boss_timers[spell] = {encounterIdCL, encounterIdEJ, spell, id, msg, timer, icon, bartype, spellId, colorId, modid}
					--send the new timer to the bar manager
				end
			end
			DBM:RegisterCallback("DBM_TimerStart", DBMCallbackTimer)
		end
    end

    if (BigWigsLoader and not _G.DBM) then
		--bigwigs
        function Notepad:BigWigs_SetStage(event, module, phase)
            phase = tonumber(phase)
			local currentPhase = Notepad.GetCurrentEncounterData().phase

            if (phase and type(phase) == "number" and currentPhase and currentPhase ~= phase) then
				--phase has been changed
				local oldPhase = currentPhase
				Notepad.OnPhaseChanged(oldPhase, phase)
            end
        end

		function Notepad:BigWigs_StartBar(event, module, spellid, bar_text, time, icon, ...)
			spellid = tostring(spellid)
			local encounterIdCL = Notepad.GetCurrentEncounterData() and Notepad.GetCurrentEncounterData().encounterIdCL
			local encounterIdEJ = Notepad.GetCurrentEncounterData() and Notepad.GetCurrentEncounterData().encounterIdEJ

			if (encounterIdCL and encounterIdEJ) then
				--may the encounter start event triggering first on bw than here
				C_Timer.After(1, function()
					Notepad.db.bw_boss_timers[spellid] = {encounterIdCL, encounterIdEJ, (type(module) == "string" and module) or (module and module.moduleName) or "", spellid or "", bar_text or "", time or 0, icon or ""}
				end)
			end
		end

		function Notepad:BigWigs_Message(messageType, module, message, whichStage, unknown, color, bool1, bool2)
			if (message == "stages") then
				local phase = whichStage:match("(%d)")
				phase = tonumber(phase)

				if (phase) then
					local currentPhase = Notepad.GetCurrentEncounterData().phase
					if (phase and type(phase) == "number" and currentPhase and currentPhase ~= phase) then
						--phase has been changed
						local oldPhase = currentPhase
						Notepad.OnPhaseChanged(oldPhase, phase)
					end
				end
			end
		end

        if (BigWigsLoader.RegisterMessage) then
            BigWigsLoader.RegisterMessage(Notepad, "BigWigs_SetStage")
			BigWigsLoader.RegisterMessage(Notepad, "BigWigs_StartBar")
			BigWigsLoader.RegisterMessage(Notepad, "BigWigs_Message")
        end
    end
end

function Notepad.GetNumBarLines()
	return #_G.NotepadScreenFrame.lineFrame.barLines
end

function Notepad.GetAllBarLines()
	return _G.NotepadScreenFrame.lineFrame.barLines
end

function Notepad.GetBarLine(barLineId)
	return _G.NotepadScreenFrame.lineFrame.barLines[barLineId]
end

function Notepad.GetScrollBarLinesOffset()
	return Notepad.screenFrame.lineFrame.virtualScrollPosition
end

function Notepad.SetScrollBarLinesOffset(newOffset)
	Notepad.screenFrame.lineFrame.virtualScrollPosition = newOffset
end

Notepad.OnInstall = function (plugin)
	Notepad.db.menu_priority = default_priority

	C_Timer.After(5, Notepad.InstallBossModsHandlers)


	--C_Timer.After(10, Notepad.OnEncounterStart)

	--frame shown in the screen
	local screenFrame = RA:CreateCleanFrame(Notepad, "NotepadScreenFrame") --~screenframe ~screenpanel
	Notepad.screenFrame = screenFrame
	screenFrame:SetSize(250, 200)
	screenFrame:SetClampedToScreen(true)
	screenFrame:SetResizable(true)
	screenFrame:SetMaxResize(600, 1024)
	screenFrame:SetMinResize(150, 50)
	screenFrame:Hide()

	local title_text = screenFrame:CreateFontString(nil, "overlay", "GameFontNormal")
	title_text:SetText("Raid Assist")
	title_text:SetTextColor(.8, .8, .8, 1)
	title_text:SetPoint("top", screenFrame, "top", 0, -8)
	screenFrame.title_text = title_text

	--line frame
	local f = CreateFrame("frame", "RaidAssignmentsNoteEditboxScreen", screenFrame, "BackdropTemplate")
	f:SetPoint("topleft", screenFrame, "topleft", 0, -20)
	f:SetPoint("topright", screenFrame, "topright", 0, -20)
	f:SetPoint("bottomleft", screenFrame, "bottomleft", 0, 0)
	f:SetPoint("bottomright", screenFrame, "bottomright", 0, 0)
    f:SetResizable(true)
    --DetailsFramework:ApplyStandardBackdrop(f)
	f:SetFrameLevel(screenFrame:GetFrameLevel()+1)
	screenFrame.text = f
	screenFrame.lineFrame = f

	--background
	local background = f:CreateTexture(nil, "background")
	background:SetPoint("topleft", f, "topleft", 0, 0)
	background:SetPoint("bottomright", f, "bottomright", 0, 0)
	screenFrame.background = background

	f.virtualScrollPosition = 1
	f.lineHeight = 16
	f.fontSize = 12
	f.barLines = {}

	local onTimerEndHook = function(progressBar)
		progressBar:SetScript("OnUpdate", nil)
		progressBar:SetMinMaxValues(0, 100)
		progressBar:SetValue(0)
		progressBar.rightText:SetText("")
		progressBar.spark:Hide()
		progressBar:Hide()

		local lineBar = progressBar:GetParent()
		local lineProps = lineBar.lineProps

		if (lineProps.cleuEventCanReset and lineProps.cleuEventTriggered) then
			lineProps.progressBarResetTime = GetTime()
			lineProps.cleuEventTriggered = false
			lineProps.timerStarted =  false
			print("combatlog OnTimerEndHook barLine:", lineBar.barLineId, "line:", lineBar.lineId, lineProps.progressBarResetTime)
		end

		return true
	end

    function f.CreateNewLine(lineId) --~bar ~progressbar ~createbar
        local line = CreateFrame("frame", "$parentLine" .. lineId, f, "BackdropTemplate")
		local xPosition = (lineId-1) * (f.lineHeight) * -1
		line.barLineId = lineId

        line:SetPoint("topleft", f, "topleft", 2, xPosition)
        line:SetSize(f:GetWidth(), f.lineHeight)

		local progressBar = DetailsFramework:CreateTimeBar(line, [[Interface\AddOns\RaidAssist\media\bar_skyline]], line:GetWidth(), line:GetHeight(), 0)
		progressBar:SetPoint("topleft", line, "topleft", 0, 0)
		progressBar:SetPoint("bottomright", line, "bottomright", -1, 0)
		progressBar:SetFrameLevel(line:GetFrameLevel() - 1)
		progressBar:EnableMouse(false)
		progressBar:SetHook("OnTimerEnd", onTimerEndHook)
		progressBar:Hide()
		progressBar.statusBar.backgroundTexture:Hide()
		progressBar:SetColor(.6, .6, .6, .8)
		line.progressBar = progressBar

        --create the label 1
        local label1 = DetailsFramework:CreateLabel(line)
        label1:SetPoint("left", line, "left", 0, 0)
        label1:SetJustifyH("right")
        label1.fontsize = f.fontSize
        line.text1 = label1

        --create the label 2
        local label2 = DetailsFramework:CreateLabel(line)
        label2:SetPoint("left", line, "left", 36, 0)
        label2.fontsize = f.fontSize
        line.text2 = label2

        label1:SetText("=====================")

        --store the line in the line table
        tinsert(f.barLines, line)
    end

    function f.UpdateBars()
        --calc the frame size
        local frameHeight = f:GetHeight()
        local amountToUse = ceil(frameHeight / f.lineHeight)
        local amtLinesCreated = #f.barLines

        if (amtLinesCreated < amountToUse) then
            for i = amtLinesCreated, amountToUse do
                --create new lines
                f.CreateNewLine(i+1)
            end

        elseif (amtLinesCreated > amountToUse) then
            for i = amtLinesCreated, amountToUse, -1 do
                --hide exceded lines
                f.barLines[i].text1.text = ""
                f.barLines[i].text2.text = ""
                f.barLines[i]:Hide()
            end
        end

        --update the created amount
        amtLinesCreated = #f.barLines

        for i = 1, amountToUse do
            local barLine = f.barLines[i]
            barLine:Show()
            barLine.text1.text = ""
            barLine.text2.text = ""
        end

		Notepad:UpdateScreenFrameSettings()

        if (screenFrame:IsShown()) then
			--call the update text
			Notepad.ParseNoteTextAndCreatePlayback()
		end
    end
	--end of line frame

	local commandLineText = f:CreateFontString(nil, "overlay", "GameFontNormal")
	commandLineText:SetText("/RAA")
	commandLineText:SetTextColor(.9, .9, .9, 0.1)
	DetailsFramework:SetFontOutline(commandLineText, true)
	commandLineText:SetPoint("topright", screenFrame, "topright", -2, -25)

	local updateDelay = 0

	do
		local resize_button = CreateFrame("button", nil, screenFrame, "BackdropTemplate")
		resize_button:SetPoint("bottomleft", screenFrame, "bottomleft")
		resize_button:SetSize(16, 16)
		resize_button:SetAlpha(0.6)
		screenFrame.resize_button = resize_button
		resize_button:SetFrameLevel(screenFrame:GetFrameLevel() + 6)

		local resize_texture = resize_button:CreateTexture(nil, "overlay")
		resize_texture:SetTexture([[Interface\CHATFRAME\UI-ChatIM-SizeGrabber-Down]])
		resize_texture:SetPoint("topleft", resize_button, "topleft", 0, 0)
		resize_texture:SetSize(16, 16)
		resize_texture:SetTexCoord(1, 0, 0, 1)
		screenFrame.resize_texture = resize_texture

		resize_button:SetScript("OnMouseDown", function()
			screenFrame:StartSizing("bottomleft")
		end)

		resize_button:SetScript("OnMouseUp", function()
			screenFrame:StopMovingOrSizing()
			f.UpdateBars()
		end)

		screenFrame:SetScript("OnSizeChanged", function()
			if (updateDelay < GetTime()) then
				f.UpdateBars()
				updateDelay = GetTime() + 0.2
			end
		end)
	end

	do
		local resize_button = CreateFrame("button", nil, screenFrame, "BackdropTemplate")
		resize_button:SetPoint("bottomright", screenFrame, "bottomright")
		resize_button:SetSize(16, 16)
		resize_button:SetAlpha(0.6)
		screenFrame.resize_button2 = resize_button
		resize_button:SetFrameLevel(screenFrame:GetFrameLevel() + 6)

		local resize_texture = resize_button:CreateTexture(nil, "overlay")
		resize_texture:SetTexture([[Interface\CHATFRAME\UI-ChatIM-SizeGrabber-Down]])
		resize_texture:SetPoint("topleft", resize_button, "topleft", 0, 0)
		resize_texture:SetSize(16, 16)
		resize_texture:SetTexCoord(0, 1, 0, 1)
		screenFrame.resize_texture = resize_texture

		resize_button:SetScript("OnMouseDown", function()
			screenFrame:StartSizing("bottomright")
		end)

		resize_button:SetScript("OnMouseUp", function()
			screenFrame:StopMovingOrSizing()
			f.UpdateBars()
		end)

		screenFrame:SetScript("OnSizeChanged", function()
			if (updateDelay < GetTime()) then
				f.UpdateBars()
				updateDelay = GetTime() + 0.2
			end
		end)
	end

	local lock = CreateFrame("button", "NotepadScreenFrameLockButton", screenFrame, "BackdropTemplate")
	lock:SetSize(60, 12)
	lock:SetAlpha(0.910)
	lock:SetPoint("bottomright", f, "topright", 0, 0)

	local lockLabel = DF:CreateLabel(lock, "|cFFFFAA00[|cFFFFFF00" .. L["S_LOCK"] .. "|r]", 12)
	lockLabel:SetPoint("bottomright", lock, "bottomright")

	lock:SetScript ("OnClick", function()
		if (screenFrame:IsMouseEnabled()) then
			Notepad.db.locked = true
			Notepad:UpdateScreenFrameSettings()
		else
			Notepad.db.locked = false
			Notepad:UpdateScreenFrameSettings()
		end
	end)

	screenFrame.lock = lock

	--
	local settingsButton = CreateFrame("button", "NotepadScreenFrameSettingsButton", screenFrame, "BackdropTemplate")
	settingsButton:SetSize(60, 12)
	settingsButton:SetAlpha(0.910)
	settingsButton:SetPoint("bottomleft", f, "topleft", 0, 0)
	local settingsLabel = DF:CreateLabel(settingsButton, "|cFFFFAA00[|cFFFFFF00"  .. L["S_SETTINGS"] .. "|r]", 12)
	settingsLabel:SetPoint("bottomleft", settingsButton, "bottomleft")

	settingsButton:SetScript("OnClick", function()
		RA.OpenMainOptionsByPluginIndex(1)
	end)

	screenFrame.settingsButton = settingsButton

	local close = CreateFrame ("button", "NotepadScreenFrameCloseButton", screenFrame, "BackdropTemplate")
	close:SetSize (18, 18)
	close:SetNormalTexture ([[Interface\GLUES\LOGIN\Glues-CheckBox-Check]])
	close:SetHighlightTexture ([[Interface\GLUES\LOGIN\Glues-CheckBox-Check]])
	close:SetPushedTexture ([[Interface\GLUES\LOGIN\Glues-CheckBox-Check]])
	close:SetAlpha(0.7)
	close:GetPushedTexture():SetDesaturated(true)
	close:GetNormalTexture():SetDesaturated(true)
	close:GetHighlightTexture():SetDesaturated(true)

	close:SetScript ("OnClick", function()
		Notepad.UnshowNoteOnScreen (true)
	end)

	screenFrame.close = close

	---------------

	local f_anim = CreateFrame ("frame", nil, screenFrame, "BackdropTemplate")
	local t = f_anim:CreateTexture (nil, "overlay")
	t:SetColorTexture (1, 1, 1, 0.20)
	t:SetAllPoints()
	t:SetBlendMode ("ADD")
	local animation = t:CreateAnimationGroup()
	local anim1 = animation:CreateAnimation ("Alpha")
	local anim4 = animation:CreateAnimation ("Alpha")
	local anim5 = animation:CreateAnimation ("Alpha")

	anim1:SetOrder (1)
	anim1:SetFromAlpha (1)
	anim1:SetToAlpha (0)
	anim1:SetDuration (0.0)

	anim4:SetOrder (2)
	anim4:SetFromAlpha (0)
	anim4:SetToAlpha (1)
	anim4:SetDuration (0.2)

	anim5:SetOrder (3)
	anim5:SetFromAlpha (1)
	anim5:SetToAlpha (0)
	anim5:SetDuration (3)

	animation:SetScript ("OnFinished", function (self)
		f_anim:Hide()
	end)

	Notepad.DoFlashAnim = function()

		if (Notepad.PlayerAFKTicker and Notepad.MouseCursorX and Notepad.MouseCursorY) then
			local x, y = GetCursorPosition()
			if (Notepad.MouseCursorX ~= x or Notepad.MouseCursorY ~= y) then
				if (Notepad.PlayerAFKTicker) then
					Notepad.PlayerAFKTicker:Cancel()
					Notepad.PlayerAFKTicker = nil
					return
				end
			end
		end

		f_anim:Show()
		f_anim:SetParent(f)
		f_anim:SetPoint("topleft", f, "topleft")
		f_anim:SetPoint("bottomright", f, "bottomright")
		animation:Play()
	end

	Notepad:UpdateScreenFrameSettings()

	Notepad.playerIsInGroup = IsInGroup()

	local _, instanceType = GetInstanceInfo()
	Notepad.current_instanceType = instanceType

	Notepad:RegisterEvent("GROUP_ROSTER_UPDATE")
	Notepad:RegisterEvent("PLAYER_REGEN_DISABLED")
	Notepad:RegisterEvent("PLAYER_REGEN_ENABLED")
	Notepad:RegisterEvent("PLAYER_LOGOUT")
	Notepad:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	Notepad:RegisterEvent("ENCOUNTER_START")
	Notepad:RegisterEvent("ENCOUNTER_END")

	if (Notepad:GetCurrentlyShownBoss()) then
		Notepad:ValidateNoteCurrentlyShown() --only removes, zone_changed has been removed
	end

	C_Timer.After(10, function()
		local _, instanceType, DifficultyID = GetInstanceInfo()
		if (instanceType == "raid" and IsInGroup() and DifficultyID ~= 17) then
			Notepad:AskForEnabledNote()
		end
	end)
end --end of OnInstall

function Notepad:UpdateScreenFrameBackground()
	local bg = Notepad.db.background
	if (bg.show) then
		Notepad.screenFrame.background:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
	else
		Notepad.screenFrame.background:SetColorTexture(0, 0, 0, 0)
	end
end

function Notepad:UpdateScreenFrameSettings()
	local SharedMedia = LibStub:GetLibrary("LibSharedMedia-3.0")
	local font = SharedMedia:Fetch("font", Notepad.db.text_font)
	local textSize = Notepad.db.text_size
	local textShadow = Notepad.db.text_shadow
	local textJustify = Notepad.db.text_justify
	local barTexture = SharedMedia:Fetch("statusbar", Notepad.db.bar_texture)

	local lineFrame = Notepad.screenFrame.lineFrame
	for i = 1, #lineFrame.barLines do
		local line = lineFrame.barLines[i]
		--font face
		Notepad:SetFontFace(line.text1, font)
		Notepad:SetFontFace(line.text2, font)

		--font size
		Notepad:SetFontSize(line.text1, textSize)
		Notepad:SetFontSize(line.text2, textSize)

		--font shadow
		Notepad:SetFontOutline(line.text1, textShadow)
		Notepad:SetFontOutline(line.text2, textShadow)

		--text alignment
		line.text1:SetJustifyH(textJustify)
		line.text2:SetJustifyH(textJustify)

		--progress bar texture
		line.progressBar:SetTexture(barTexture)
	end

	--frame strata
	Notepad.screenFrame:SetFrameStrata(Notepad.db.framestrata)

	--background show
	Notepad:UpdateScreenFrameBackground()
	Notepad.screenFrame:SetBackdrop(nil)

	--frame locked
	if (Notepad.db.locked) then
		Notepad.screenFrame:EnableMouse(false)
		Notepad.screenFrame.lock:Hide()
		Notepad.screenFrame.close:Hide()
		Notepad.screenFrame.settingsButton:Hide()
		Notepad.screenFrame.resize_button:Hide()
		Notepad.screenFrame.resize_texture:Hide()
		Notepad.screenFrame.title_text:SetTextColor(.8, .8, .8, 0)

	else
		Notepad.screenFrame:EnableMouse(true)
		Notepad.screenFrame.lock:Show()
		Notepad.screenFrame.close:Show()
		Notepad.screenFrame.settingsButton:Show()
		Notepad.screenFrame.resize_button:Show()
		Notepad.screenFrame.resize_texture:Show()

		Notepad.screenFrame.title_text:SetTextColor (.8, .8, .8, 1)
	end

	lineFrame:EnableMouse(false)
end

Notepad.OnEnable = function (plugin)
	-- enabled from the options panel.
	
end

Notepad.OnDisable = function (plugin)
	-- disabled from the options panel.
	
end

Notepad.OnProfileChanged = function (plugin)
	if (plugin.db.enabled) then
		Notepad.OnEnable (plugin)
	else
		Notepad.OnDisable (plugin)
	end
	
	if (plugin.options_built) then
		--plugin.mainFrame:RefreshOptions()
	end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local getRandomNoteSeed = function()
	return tostring(time()) .. tostring(random(1000))
end

local createBossNoteStructure = function(bossId)
	local bossNote = {
		notes = {},
		lastInUse = 1,
		bossId = bossId,
	}

	Notepad.db.boss_notes2[bossId] = bossNote

	return bossNote
end

local createNewNote = function(bossNote)
	local newNote = {name = "default", note = "", seed = getRandomNoteSeed(), bossId = bossNote.bossId}
	bossNote.notes[#bossNote.notes+1] = newNote
	return newNote, #bossNote.notes
end

local createNewNoteWithSeed = function(bossNote, seed)
	local newNote = {name = "default", note = "", seed = seed, bossId = bossNote.bossId}
	bossNote.notes[#bossNote.notes+1] = newNote
	return newNote, #bossNote.notes
end

local getLatestNoteOnBossNote = function(bossNote)
	return bossNote.notes[#bossNote.notes]
end

function Notepad:GetNoteBySeed(bossId, seed)
	--check if the structure for this boss exists
	local bossNote = Notepad.db.boss_notes2[bossId]
	if (not bossNote) then
		bossNote = createBossNoteStructure(bossId)
	end

	local note, noteId

	--search for a note with the seed
	for i = 1, #bossNote.notes do
		local thisNote = bossNote.notes[i]
		if (thisNote.seed == seed) then
			note = thisNote
			noteId = i
			break
		end
	end

	if (not note) then
		--create a new note with the seed passed
		note, noteId = createNewNoteWithSeed(bossNote, seed)
	end

	return note, noteId
end

function Notepad:GetNote(bossId, noteId)
	--check if the structure for this boss exists
	local bossNote = Notepad.db.boss_notes2[bossId]
	if (not bossNote) then
		bossNote = createBossNoteStructure(bossId)
	end

	if (type(noteId) == "boolean" and noteId) then
		local newNote, noteId = createNewNote(bossNote)
		return newNote, noteId
	end

	noteId = noteId or 1

	local note = bossNote.notes[noteId]

	--check if the note asked exists, create one otherwise
	if (not note) then
		local newNote, noteId = createNewNote(bossNote)
		return newNote, noteId
	end

	return note, noteId
end

function Notepad:SaveNote(note, bossId, noteId)
	if (not note or not bossId or not noteId) then
		return
	end

	local thisNote = Notepad:GetNote(bossId, noteId)
	thisNote.note = note

	return thisNote
end

function Notepad:SaveNoteFromComm(note, bossId)
	if (not note or not bossId) then
		return
	end

	local thisNote, noteId = Notepad:GetNoteBySeed(bossId, note.seed)
	thisNote.note = note.note
	thisNote.name = note.name

	return thisNote, noteId
end

function Notepad:GetCurrentlyShownBoss()
	return Notepad.db.currently_shown, Notepad.db.currently_shown_time, Notepad.db.currently_shown_noteId
end

function Notepad:SetCurrentlyShownBoss(bossId, noteId)
	Notepad.db.currently_shown = bossId
	Notepad.db.currently_shown_noteId = noteId
	Notepad.db.currently_shown_time = time()
end

function Notepad:SaveCurrentEditingNote()
	local currentBossId, noteId = Notepad:GetCurrentEditingBossId()
	if (currentBossId and noteId) then
		Notepad:SaveNote(Notepad.mainFrame.editboxNotes:GetText(), currentBossId, noteId)
	end
end

function Notepad:GetCurrentEditingNote()
	local currentBossId, noteId = Notepad:GetCurrentEditingBossId()
	return Notepad:GetNote(currentBossId, noteId)
end

function Notepad:GetNoteList()
	return Notepad.db.boss_notes2
end

function Notepad:BuildBossList() --~bosslist
	local bossTable = {}
	Notepad.bossListHashTable = {} --carry a list of bosses of the current expansion where the boss index is key
	Notepad.bossListTable = bossTable --carry a indexed list of bosses

	bossTable[#bossTable+1] = {
		bossName = "General Notes",
		bossId = 0,
		bossRaidName = L["S_PLUGIN_NOTE_GENERALNOTE_DESC"],
		bossIcon = [[Interface\AddOns\RaidAssist\Media\note_icon]],
		bossIconCoords = {0, 1, 0, 1},
		bossIconSize = {bossLinesHeight+30, bossLinesHeight-4},
		instanceId = 0,
		uiMapId = 0,
		instanceIndex = 0,
		journalInstanceId = 0,
	}

	--EJ_SelectTier(7) --for older expansions

    for instanceIndex = 10, 1, -1 do
		local instanceID, zoneName = _G.EJ_GetInstanceByIndex(instanceIndex, true)
        if (instanceID) then
            for i = 20, 1, -1 do
				local name, description, bossID, rootSectionID, link, journalInstanceID, dungeonEncounterID, UiMapID = _G.EJ_GetEncounterInfoByIndex (i, instanceID)

				if (name) then
					local id, creatureName, creatureDescription, displayInfo, iconImage = EJ_GetCreatureInfo(1, bossID)
					bossTable[#bossTable+1] = {
						bossName = name,
						bossId = bossID,
						bossRaidName = zoneName,
						bossIcon = iconImage,
						bossIconCoords = {0, 1, 0, 0.95},
						bossIconSize = {bossLinesHeight + 30, bossLinesHeight - 4},
						instanceId = instanceID,
						uiMapId = UiMapID,
						instanceIndex = instanceIndex,
						journalInstanceId = journalInstanceID,
					}
					Notepad.bossListHashTable[bossID] = bossTable[#bossTable]
                end
            end
        end
	end

	return bossTable
end

function Notepad:GetBossList()
	return Notepad.bossListTable
end

function Notepad:GetBossInfo(bossId)
	return Notepad.bossListHashTable[bossId]
end

function Notepad:GetBossName(bossId)
	local bossInfo = Notepad:GetBossInfo(bossId)
	if (bossInfo) then
		return bossInfo.bossName
	else
		return ""
	end
end

function Notepad:GetCurrentEditingBossId()
	return Notepad.db.editing_boss_id, Notepad.db.editing_boss_note_id
end

function Notepad:SetCurrentEditingBossId(bossId, noteId)
	Notepad.db.editing_boss_id = bossId
	Notepad.db.editing_boss_note_id = noteId
	Notepad.db.latest_menu_option_boss_selected = bossId
	Notepad.db.latest_menu_option_note_selected = noteId

	local mainFrame = Notepad.mainFrame
	noteId = noteId or 1

	mainFrame.BossSelectionBox:RefreshMe()

	--open the boss to change the text
	mainFrame.buttonCancel:Enable()
	mainFrame.buttonClear:Enable()
	mainFrame.buttonSave:Enable()
	mainFrame.buttonSave2:Enable()
	mainFrame.editboxNotes:Enable()
	mainFrame.editboxNotes:SetFocus()

	--> deprecated????
		local note = Notepad:GetNote(bossId, noteId)
		mainFrame.editboxNotes:SetText(note.note)
		Notepad.FormatText()

	mainFrame.editboxNotes:Show()
	mainFrame.userScreenPanelOptions:Hide()

	--is empty?
	if (#note.note == 0) then
		mainFrame.editboxNotes.editbox:SetText("\n\n\n")
	end

	mainFrame.editboxNotes.editbox:SetFocus(true)
	mainFrame.editboxNotes.editbox:SetCursorPosition(0)

	Notepad:UpdateBossAbilities()
end

function Notepad:CancelNoteEditing()
	local mainFrame = Notepad.mainFrame
	mainFrame.buttonCancel:Disable()
	mainFrame.buttonClear:Disable()
	mainFrame.buttonSave:Disable()
	mainFrame.buttonSave2:Disable()

	mainFrame.editboxNotes:SetText("")
	mainFrame.editboxNotes:Disable()

	mainFrame.editboxNotes:Hide()
	mainFrame.userScreenPanelOptions:Show()
end

local trackMousePosForAFKDetection = function()
	local x, y = GetCursorPosition()
	if (Notepad.MouseCursorX == x and Notepad.MouseCursorY == y) then
		--> player afk?
		if (not Notepad.PlayerAFKTicker) then
			Notepad.PlayerAFKTicker = C_Timer.NewTicker(5, Notepad.DoFlashAnim, 10)
		end
	end
end

function Notepad.BuildListOfPlayersInRaid()
	local playerList = {
		all = {},
		all_class = {},
		all_role = {},
		all_index = {},
		class = {},
		class_index = {},
		class_healer_index = {},
		HEALER = {},
		TANK = {},
		DAMAGER = {},
		MELEE = {},
	}

	for i = 1, #CLASS_SORT_ORDER do
		playerList.class[CLASS_SORT_ORDER[i]] = {}
		playerList.class_healer_index[CLASS_SORT_ORDER[i]] = {}
		playerList.class_index[CLASS_SORT_ORDER[i]] = {}
	end

	local openRaidLib = LibStub:GetLibrary("LibOpenRaid-1.0")
	local allPlayersInfo = openRaidLib.playerInfoManager.GetAllPlayersInfo()

	if (IsInRaid()) then
		local _, _, difficultyID = GetInstanceInfo()
		local isMythicRaid = difficultyID == 16
		local isNormalOrHeroic = difficultyID == 14 or difficultyID == 15

		local amountOfPlayers = (isMythicRaid and 20) or (isNormalOrHeroic and 30) or 40

		for i = 1, amountOfPlayers do
			local name, rank, subgroup, level, class, fileName, zone, online, isDead, raidRole, isML, role = GetRaidRosterInfo(i)
			if (name) then
				name = Ambiguate(name, "none")
				playerList.all_role[name] = role
				playerList.all_class[name] = fileName

				playerList.all_index[#playerList.all_index+1] = name

				playerList.class[fileName][name] = role
				local classTable = playerList.class_index[fileName]
				classTable[#classTable+1] = name

				local roleTable = playerList[role]

				if (roleTable) then
					roleTable[#roleTable+1] = name
					if (role == "HEALER") then
						playerList.class_healer_index[fileName][#playerList.class_healer_index[fileName]+1] = name
					end
				end

				if (fileName == "ROGUE") then
					playerList.MELEE[#playerList.MELEE+1] = name
				else
					local playerInfo = allPlayersInfo[name]
					if (playerInfo) then
						local specId = playerInfo.specId
						local meleeSpecs = _G.LIB_OPEN_RAID_MELEE_SPECS
						if (meleeSpecs[specId]) then
							playerList.MELEE[#playerList.MELEE+1] = name
						end
					end
				end
			end
		end

	elseif (IsInGroup()) then
		for i = 1, GetNumGroupMembers() do
			local name, rank, subgroup, level, class, fileName, zone, online, isDead, raidRole, isML, role = GetRaidRosterInfo(i)
			if (name) then
				name = Ambiguate(name, "none")
				playerList.all_role[name] = role
				playerList.all_class[name] = fileName

				playerList.all_index[#playerList.all_index+1] = name

				playerList.class[fileName][name] = role
				local classTable = playerList.class_index[fileName]
				classTable[#classTable+1] = name

				local roleTable = playerList[role]
				if (roleTable) then
					roleTable[#roleTable+1] = name

					if (role == "HEALER") then
						playerList.class_healer_index[fileName][#playerList.class_healer_index[fileName]+1] = name
					end
				end

				if (fileName == "ROGUE") then
					playerList.MELEE[#playerList.MELEE+1] = name
				else
					local playerInfo = allPlayersInfo[name]
					if (playerInfo) then
						local specId = playerInfo.specId
						local meleeSpecs = _G.LIB_OPEN_RAID_MELEE_SPECS
						if (meleeSpecs[specId]) then
							playerList.MELEE[#playerList.MELEE+1] = name
						end
					end
				end
			end
		end
	end

	--> sort player names
		local sortFunction = function(p1, p2) return p1 < p2 end

		for i = 1, #CLASS_SORT_ORDER do
			local className = CLASS_SORT_ORDER[i]

			local healersOfClass = playerList.class_healer_index[className]
			table.sort(healersOfClass, sortFunction)

			local classTable = playerList.class_index[className]
			table.sort(classTable, sortFunction)
		end

		for i = 1, #allRoles do
			local roleName = allRoles[i]
			table.sort(playerList[roleName], sortFunction)
		end

		local meleeTable = playerList.MELEE
		table.sort(meleeTable, sortFunction)

	Notepad.playersInTheGroup = playerList
end


function Notepad.FillVariables(variables)
	local playerList = Notepad.playersInTheGroup

	--fill with players of the same class
	for i = 1, #CLASS_SORT_ORDER do
		local className = CLASS_SORT_ORDER[i]
		local players = playerList.class_index[className]
		variables["@" .. className] = players

		for o = 1, #players do
			variables["@" .. className .. o] = players[o]
		end
	end

	--fill with players of the same role
	for i = 1, #allRoles do
		local roleName = allRoles[i]
		local playersOfThisRole = playerList[roleName]
		variables["@" .. roleName] = playersOfThisRole

		for o = 1, #playersOfThisRole do
			variables["@" .. roleName .. o] = playersOfThisRole[o]
		end
	end

	local healerByClass = playerList.class_healer_index
	for className, playerTable in pairs(healerByClass) do
		variables["@" .. "H" .. className] = playerTable
		for i = 1, #playerTable do
			local playerName = playerTable[i]
			variables["@" .. "H" .. className .. i] = playerName
		end
	end

	--fill with Melee
	local melee = playerList.MELEE
	variables["@" .. "MELEE"] = melee
	for i = 1, #melee do
		local playerName = melee[i]
		variables["@" .. "MELEE" .. i] = playerName
	end
end

local convertEventToCleuEvent = function(event)
	event = event:lower()

	if (event == "caststart" or event == "cs" or event == "spell_cast_start") then
		return "SPELL_CAST_START"

	elseif (event == "castdone" or event == "castfinished" or event == "castend" or event == "castsuccess" or event == "ss" or event == "spell_cast_success") then
		return "SPELL_CAST_SUCCESS"

	elseif (event == "interrupt" or event == "i" or event == "spell_interrupt") then
		return "SPELL_INTERRUPT"

	elseif (event == "dispel" or event == "d" or event == "spell_dispel") then
		return "SPELL_DISPEL"

	elseif (event == "auraremoved" or event == "spell_aura_removed" or event == "ar") then
		return "SPELL_AURA_REMOVED"

	elseif (event == "auraapplied" or event == "spell_aura_applied" or event == "aa") then
		return "SPELL_AURA_APPLIED"

	else
		return event:upper()
	end
end


function Notepad.GetPlayers(ofClass, ofRole)
	local playerList = Notepad.playersInTheGroup

	ofClass = ofClass and ofClass:upper()
	ofRole = ofRole and ofRole:upper()

	if (ofClass and ofRole) then
		local result =  {}
		for playerName, role in pairs(playerList.all_role) do
			if (role == ofRole) then
				if (playerList.all_class[playerName] == ofClass) then
					result[#result+1] = playerName
				end
			end
		end
		return result

	elseif (ofClass) then
		return playerList.class_index[ofClass]

	elseif (ofRole) then
		return playerList[ofRole]
	end

	return playerList
end

function Notepad.ParseTimeEntry(value)
	local minutes, seconds = value:match("(%d+):(%d+)")
	if (minutes and seconds) then
		minutes = tonumber(minutes)
		seconds = tonumber(seconds)
		if (minutes and seconds) then
			return minutes*60 + seconds
		end
	else
		local timeInSeconds = tonumber(value)
		return timeInSeconds
	end
end

function Notepad.IsInsideMacro(cursorPos, text)
	for i = cursorPos, 1, -1 do
		local letter = text:sub(i, i)
		if (letter == "[") then
			return cursorPos > i
		elseif (letter == "]") then
			return
		end

		local findBreakLine = text:find("\n", i-1)
		if (findBreakLine and findBreakLine < cursorPos) then
			return
		end
	end
end

function Notepad.GetPlayback()
	return Notepad.currentPlayback
end
RANotes.GetPlayback = Notepad.GetPlayback

function Notepad:ParseTextForMacros(text) --~parsermacro ~macroparser
	--split it into lines
	local lines = DetailsFramework:SplitTextInLines(text)
	local macros = {}
	local variables = {}
	local playerLists = {}

	--macro example: --[phase=2; timer=352145; playerlist=Ditador, Jvr, Veloso, Miudo]

	--remove comment lines
	for i = #lines, 1, -1 do
		local thisLineText = lines[i]
		if (thisLineText:match("//")) then
			tremove(lines, i)
		end
	end

	for lineId, thisLine in ipairs(lines) do

		local gotPlayerListOnThisLine = false

		--store all macros from this line
		local thisLineMacros = {}
			--> detect time in the begining of the line
				local elapsedTime = thisLine:match("^(%d+)%s")

				if (elapsedTime) then
					elapsedTime = tonumber(elapsedTime)
					if (elapsedTime) then
						tinsert(thisLineMacros, {"3time", elapsedTime})
						thisLine = thisLine:gsub("^(%d+)%s", "")
					end
					lines[lineId] = thisLine
				else
					local minutes, seconds = thisLine:match("^(%d+):(%d+)%s")
					if (minutes and seconds) then
						minutes = tonumber(minutes)
						seconds = tonumber(seconds)
						if (minutes and seconds) then
							local t = minutes*60 + seconds
							tinsert(thisLineMacros, {"3time", t})
							thisLine = thisLine:gsub("^(%d+):(%d+)%s", "")
							lines[lineId] = thisLine
						end
					end
				end

		--get the macro from the line
		local macroText = thisLine:match("%[(.+)%]")
		if (macroText and type(macroText) == "string" and #macroText > 0) then
			--remove the macro text from the text which will be shown to the player
			lines[lineId] = thisLine:gsub("%[(.+)%]", "")

			--remove any scape sequence from the macro text
			macroText = macroText:gsub("|c%x%x%x%x%x%x%x%x", "")
			macroText = macroText:gsub("|r", "")

			--create a list of macros for look ahead feature
			local variableNameOfThisLine
			local macrosOnThisLine = {}

			for macro in macroText:gmatch("([^;]+)") do
				--remove spaces
				macro = macro:gsub("%s", "")

				--get variable declaration
				local variableName, value = macro:match("(%$%w+)=(.+)")
				if (variableName and value) then
					variableName = variableName:gsub("^%$", "@")
					variableName = variableName:upper()
					variables[variableName] = value

				elseif (macro:match("^%$") and not macro:match("=")) then
					variableName = macro:gsub("^%$", "@")
					variableName = variableName:upper()
					tinsert(thisLineMacros, {"print", variableName})
				else
					--convert variable token
					macro = macro:gsub("%$", "@")

					--add the macro into the list
					macrosOnThisLine[#macrosOnThisLine+1] = macro

					local isVariableName = macro:match("name=(.*)")
					if (isVariableName) then
						isVariableName = isVariableName:upper()
						isVariableName = isVariableName:gsub("^", "@")
						variableNameOfThisLine = isVariableName
					end
				end
			end

			for _, macro in ipairs(macrosOnThisLine) do
				--split command and parameters
				local token, value = macro:match("(%w+)=(.+)")
				if (not token) then
					token = macro:match("(%w+)")
				end

				if (token) then
					--parse token
					token = token:lower()
					value = value or false

					--phase
					if (token == "phase" or token == "p") then
						local phaseId = tonumber(value)
						if (phaseId) then
							tinsert(thisLineMacros, {"0phase", phaseId})

							if (variableNameOfThisLine) then
								variables[variableNameOfThisLine] = phaseId
							end
						else
							RA:Msg(L["S_PLUGIN_NOTE_MACRO_PHASE_ERROR1"])
						end

					--time
					elseif (token == "time" or token == "elapsedtime") then
						local seconds = Notepad.ParseTimeEntry(value)
						if (seconds) then
							tinsert(thisLineMacros, {"3time", seconds})

							if (variableNameOfThisLine) then
								variables[variableNameOfThisLine] = seconds
							end
						else
							RA:Msg(L["S_PLUGIN_NOTE_MACRO_TIME_ERROR1"])
						end

					--hidden
					elseif (token == "hidden" or token == "hide" or token == "nop") then
						tinsert(thisLineMacros, {"hidden", true})

					--cooldown
					elseif (token == "cooldown" or token == "cd") then
						local lineCooldowns = {}
						local noEntry = true
						local entries = {strsplit(",", not value and "" or value)}

						for i = 1, #entries, 2 do
							local spellId, playerName = entries[i], entries[i+1]

							spellId = tonumber(spellId)
							local playerIsSpellId = tonumber(playerName)

							if (spellId and playerIsSpellId) then --two spellIds in sequence
								local cooldownInfo = LIB_OPEN_RAID_COOLDOWNS_INFO[spellId]
								if (cooldownInfo) then
									lineCooldowns[#lineCooldowns+1] = {spellId, "@H" .. cooldownInfo.class}
									noEntry = false
								else
									RA:Msg(L["S_PLUGIN_NOTE_MACRO_COOLDOWN_ERROR2"] .. ":", spellId)
								end

								local cooldownInfo = LIB_OPEN_RAID_COOLDOWNS_INFO[playerIsSpellId]
								if (cooldownInfo) then
									lineCooldowns[#lineCooldowns+1] = {playerIsSpellId, "@H" .. cooldownInfo.class}
									noEntry = false
								else
									RA:Msg(L["S_PLUGIN_NOTE_MACRO_COOLDOWN_ERROR2"] .. ":", spellId)
								end

							elseif (spellId and playerName) then
								lineCooldowns[#lineCooldowns+1] = {spellId, playerName}
								noEntry = false

							elseif (spellId) then
								local cooldownInfo = LIB_OPEN_RAID_COOLDOWNS_INFO[spellId]
								if (cooldownInfo) then
									local class = cooldownInfo.class
									lineCooldowns[#lineCooldowns+1] = {spellId, "@H" .. class}
									noEntry = false
								else
									RA:Msg(L["S_PLUGIN_NOTE_MACRO_COOLDOWN_ERROR2"] .. ":", spellId)
									break
								end
							else
								break
							end
						end

						if (noEntry) then
							RA:Msg(L["S_PLUGIN_NOTE_MACRO_COOLDOWN_ERROR1"])
						end

						tinsert(thisLineMacros, {"8cooldown", lineCooldowns})

					--enemy spell
					elseif (token == "enemyspell" or token == "es") then
						local spellId = tonumber(value)
						local isSpell = GetSpellTexture(spellId or -1)

						if (spellId and isSpell) then
							tinsert(thisLineMacros, {"7enemyspell", spellId})

							if (variableNameOfThisLine) then
								variables[variableNameOfThisLine] = spellId
							end
						else
							RA:Msg(L["S_PLUGIN_NOTE_MACRO_ENEMYSPELL_ERROR1"])
						end

					--timer
					elseif (token == "countdown") then
						if (not value) then
							tinsert(thisLineMacros, {"countdown", CONST_PROGRESSBAR_DEFAULT_TIME})

						else
							local seconds = Notepad.ParseTimeEntry(value)
							if (seconds) then
								tinsert(thisLineMacros, {"countdown", seconds})
								if (variableNameOfThisLine) then
									variables[variableNameOfThisLine] = seconds
								end
							else
								RA:Msg(L["S_PLUGIN_NOTE_MACRO_COUNTDOWN_ERROR1"])
							end
						end

					elseif (token == "timer") then
						if (not value) then
							RA:Msg(L["S_PLUGIN_NOTE_MACRO_TIMER_ERROR1"])

						else
							local seconds = Notepad.ParseTimeEntry(value)
							if (seconds) then
								tinsert(thisLineMacros, {"timer", seconds})
								if (variableNameOfThisLine) then
									variables[variableNameOfThisLine] = seconds
								end
							else
								RA:Msg(L["S_PLUGIN_NOTE_MACRO_TIMER_ERROR1"])
							end
						end

					--player list
					elseif (token == "playerlist" or token == "pl") then
						if (value) then

							if (not gotPlayerListOnThisLine) then
								local listOfPlayers = {}

								for playerName in value:gmatch("([^,]+)") do
									if (playerName) then
										tinsert(listOfPlayers, playerName)
									end
								end

								playerLists[lineId] = listOfPlayers
								tinsert(thisLineMacros, {"playerlist", listOfPlayers})

								if (variableNameOfThisLine) then
									--when parsing player lists this value is replaced
									variables[variableNameOfThisLine] = listOfPlayers
								end

								gotPlayerListOnThisLine = true
							else
								RA:Msg(L["S_PLUGIN_NOTE_MACRO_PLAYERLIST_ERROR1"])
							end
						else
							RA:Msg(L["S_PLUGIN_NOTE_MACRO_PLAYERLIST_ERROR2"])
						end

					--boss timer
					elseif (token == "bosstimer" or token == "bt") then
						if (value) then
							tinsert(thisLineMacros, {"bosstimer", value})

							if (variableNameOfThisLine) then
								variables[variableNameOfThisLine] = value
							end
						else
							RA:Msg("Notepad> macro 'bosstimer' expect a boss timerId, example: bosstimer(335641)")
						end

					--if condition
					elseif (token == "if" or token == "or" or token == "ifand" or token == "ifor") then
						if (value) then
							local value1, operator, value2 = value:match("(%w+),(.+),(%w+)")
							value1 = tonumber(value1) or value1
							value2 = tonumber(value2) or value2

							if (type(value1) == "string") then
								value1 = value1:gsub("%$", "@")
							end
							if (type(value2) == "string") then
								value2 = value2:gsub("%$", "@")
							end

							if (token == "if") then
								token = "ifand"
							end
							if (token == "or") then
								token = "ifor"
							end
							tinsert(thisLineMacros, {token, value1, operator, value2})
						else
							RA:Msg("Notepad> macro 'if' expect any data to compare, example: if($phase, =, 2)")
						end

					--combat log
					elseif (token == "combatlog" or token == "cl" or token == "cleu") then
						if (value) then

							local cleuData = {}

							for data in value:gmatch("([^,]+)") do
								if (data) then
									tinsert(cleuData, data)
								end
							end

							local event, spellId, counter, reset = unpack(cleuData)
							spellId = tonumber(spellId)
							counter = tonumber(counter) or false
							reset = reset and true or false

							if (spellId and event) then
								tinsert(thisLineMacros, {"combatlog", event, spellId, counter, reset})
							else
								RA:Msg("Notepad> macro 'combatlog' argument #1 and #2 are required, combatlog = caststart, spellId, counter, reset")
							end
						else
							RA:Msg("Notepad> macro 'combatlog' argument #1 and #2 are required, combatlog = caststart, spellId, counter, reset")
						end

					--loop
					elseif (token == "loop" or token == "l") then
						tinsert(thisLineMacros, {"loop", value})

					--flash
					elseif (token == "flash" or token == "f") then
						local remainingTime = tonumber(value)
						tinsert(thisLineMacros, {"flash", remainingTime})

					--external
					elseif (token == "external" or token == "e") then
						tinsert(thisLineMacros, {"external", value})

					--add to boss mods bars
					elseif (token == "addbossmods" or token == "abm") then
						tinsert(thisLineMacros, {"addbm", value})

					--don't make text
					elseif (token == "notext") then
						tinsert(thisLineMacros, {"3notext", value})

					elseif (token == "role") then
						tinsert(thisLineMacros, {"3role", value})

					elseif (token == "stop" or token == "end") then
						tinsert(thisLineMacros, {"stop", true})

					end
				end
			end

			tinsert(macros, thisLineMacros)

		else
			tinsert(macros, thisLineMacros)
		end
	end

	return lines, macros, variables, playerLists
end


function Notepad.CreateMacroPlayback(textLines, macroList, variables, playersList)

	local macroPlayback = {
		playerList = {}, --store the result of [playerlist] in order as they show
		originalPlayerList = playersList,
		variables = variables,

		phases = {}, --store when phases start, store the phaseId has the hashkey and the lineId in the value
		linePhases = {}, --store the lineId | value is the phaseId
		linesPerPhase = {}, --store the phase | value is the amount of lines 

		macroLines = {}, --line index is the hashkey, the value is a table with all macros for the line

		textLines = {},
		originaTextlLines = textLines,

		bossTimersToWatch = {},
		conditions = {},

		phaseTime = {},
		elapsedTime = {},

		progressBarByPhase = {},
		progressBarByElapsedTime = {},

		lineProperties = {},

		progressBarPhase = {}, --store which bars has a timer enabled for the current phase
		progressBarElapsed = {}, --store which bars has a timer enabled for the encounter
	}

	local parsedPlayerList = macroPlayback.playerList
	local phasesLineIndex = macroPlayback.phases
	local parsedMacroList = macroPlayback.macroLines
	local conditions = macroPlayback.conditions
	local lineIdPhase = macroPlayback.linePhases

	--store the class of each player in the group
	local playerClasses = {}

	Notepad.BuildListOfPlayersInRaid()
	Notepad.FillVariables(variables)
	variables["@PHASE"] = 1
	macroPlayback.progressBarByPhase[1] = {}
	macroPlayback.progressBarByElapsedTime[1] = {}

	--parse list of players
	for lineId, playerTable in pairs(playersList) do --loop among all [playerlist] by line
		local thisParsedPlayerList = {}

		for o, unitToken in ipairs(playerTable) do --loop among player names within the list
			if (unitToken:match("^@")) then
				--it's a variable
				local var = unitToken:gsub("^@", "")
				local listFromVariable = variables[var]
				if (listFromVariable) then
					if (type(listFromVariable) == "table") then
						for u = 1, #listFromVariable do
							local unitToken = listFromVariable[u]
							if (unitInGroup(unitToken)) then
								tinsert(thisParsedPlayerList, unitToken)
								playerClasses[unitToken] = select(2, UnitClass(unitToken))
							end
						end

					elseif (type(listFromVariable) == "string") then
						if (unitInGroup(listFromVariable)) then
							tinsert(thisParsedPlayerList, unitToken)
							playerClasses[unitToken] = select(2, UnitClass(unitToken))
						end
					end
				end
			else
				--player name
				if (unitInGroup(unitToken)) then
					tinsert(thisParsedPlayerList, unitToken)
					playerClasses[unitToken] = select(2, UnitClass(unitToken))
				end
			end
		end

		parsedPlayerList[lineId] = thisParsedPlayerList
	end

	--phase zero make the line be permanent
	local currentPhase = 0

	--initialize lines
	for lineId = 1, #macroList do

		local thisLineText = textLines[lineId]

		--create the properties table, which stores attributes of the line
		local lineProps = {
			enemySpells = {},
			passConditions = true,
			conditions = {},
			text1 = "",
			text2 = thisLineText,
		}
		macroPlayback.lineProperties[lineId] = lineProps

		--get all macros declared on this line
		local macrosOnThisLine = macroList[lineId]

		--> sort macros within a line
			table.sort(macrosOnThisLine, function(t1, t2) return t1[1] < t2[1] end)
			for o = 1, #macrosOnThisLine do
				local thisMacro = macrosOnThisLine[o][CONST_MACRO_INDEXNAME]
				thisMacro = thisMacro:gsub("^%d", "")
				macrosOnThisLine[o][CONST_MACRO_INDEXNAME] = thisMacro
			end

		for o = 1, #macrosOnThisLine do
			local thisMacro = macrosOnThisLine[o]
			local token = thisMacro[CONST_MACRO_INDEXNAME]

			if (token == "phase") then
				local phaseId = thisMacro[CONST_MACRO_INDEXVALUE]
				currentPhase = phaseId
				phasesLineIndex[phaseId] = lineId

			elseif (token == "stop") then
				lineProps.stopHere = true

			elseif (token == "role") then
				lineProps.role = thisMacro[CONST_MACRO_INDEXVALUE]

			elseif (token == "notext") then
				lineProps.notext = true

			elseif (token == "hidden") then
				lineProps.hidden = true

			elseif (token == "time") then
				local time = thisMacro[CONST_MACRO_INDEXVALUE]
				if (currentPhase == 0) then
					tinsert(macrosOnThisLine, 1, {"elapsedtime", time})
					lineProps.timeElapsed = time
					lineProps.timeElapsedConst = time
				else
					tinsert(macrosOnThisLine, 1, {"phasetime", time})
					lineProps.phaseTime = time
					lineProps.phaseTimeConst = time
				end

			elseif (token == "enemyspell") then
				local spellId = thisMacro[CONST_MACRO_INDEXVALUE]
				tinsert(lineProps.enemySpells, spellId)
			end
		end

		lineProps.phase = currentPhase
		macroPlayback.linesPerPhase[currentPhase] = (macroPlayback.linesPerPhase[currentPhase] or 0) + 1
	end

	--clean 'time' macro
	for lineId = 1, #macroList do
		local macrosOnThisLine = macroList[lineId]
		for i = #macrosOnThisLine, 1, -1 do
			local thisMacro = macrosOnThisLine[i]
			local token = thisMacro[CONST_MACRO_INDEXNAME]
			if (token == "time") then
				tremove(macrosOnThisLine, i)
				break
			end
		end
	end

	--each line has its macros, even if it's an empty table
	for lineId = 1, #macroList do
		--add a table to hold the text for this line
		parsedMacroList[lineId] = {}

		--get all macros declared on this line
		local macrosOnThisLine = macroList[lineId]

		--get line properties
		local lineProps = macroPlayback.lineProperties[lineId]

		--parse each macro on this line
		for i = 1, #macrosOnThisLine do
			local thisMacro = macrosOnThisLine[i]
			local token = thisMacro[CONST_MACRO_INDEXNAME]

			parsedMacroList[lineId][token] = thisMacro[CONST_MACRO_INDEXVALUE]

			if (token == "print") then
				local value = thisMacro[CONST_MACRO_INDEXVALUE]
				if (value:match("^@")) then
					value = variables[value]
				end

				if (type(value) == "table") then
					value = table.concat(value, " ")
				end

				lineProps.text2 = lineProps.text2:gsub("$", value)

			elseif (token == "playerlist") then
				thisMacro[CONST_MACRO_INDEXVALUE] = parsedPlayerList[lineId]

			elseif (token == "phase") then
				if (not lineProps.notext) then
					local phaseId = thisMacro[CONST_MACRO_INDEXVALUE]
					lineProps.text2 = lineProps.text2:gsub("^", "[|cFFFF9911PHASE: " .. phaseId .. "|r]")
				end

			elseif (token == "enemyspell") then
				if (not lineProps.notext) then
					local spellId = thisMacro[CONST_MACRO_INDEXVALUE]
					local spellName, _, spellIcon = GetSpellInfo(spellId)
					local iconText = "|T" .. spellIcon .. ":12:12:0:0:64:64:5:59:5:59|t "
					lineProps.text2 = lineProps.text2:gsub("^", iconText .. "|cFFFF5511" .. spellName .. "|r ")
				end

			elseif (token == "cooldown") then
				local cooldowns = thisMacro[CONST_MACRO_INDEXVALUE]
				local generatedText = ""

				for i = 1, #cooldowns do
					local thisCooldown = cooldowns[i]
					local spellId = thisCooldown[1]
					local caster = thisCooldown[2]
					local showText = true

					--check if the player name is a variable
					local listOfPlayers = variables[caster]
					local cooldownInfo = LIB_OPEN_RAID_COOLDOWNS_INFO[spellId]

					if (listOfPlayers and type(listOfPlayers) == "table" and cooldownInfo) then
						for o = 1, #listOfPlayers do
							local playerName = listOfPlayers[o]
							local playerClass = Notepad.playersInTheGroup.all_class[playerName] or playerClasses[playerName]

							if (playerClass == cooldownInfo.class) then
								caster = playerName
								break
							end
						end

					elseif (listOfPlayers and type(listOfPlayers) == "string" and cooldownInfo) then
						local playerName = listOfPlayers
						local playerClass = Notepad.playersInTheGroup.all_class[playerName] or playerClasses[playerName]
						caster = playerName

					else
						if (listOfPlayers) then
							caster = type(listOfPlayers) == "table" and listOfPlayers[1] or listOfPlayers
							if (type(caster) == "table") then
								showText = false
							end
						end
					end

					if (not lineProps.notext and showText) then
						--cast é uma tabela?
						if (not caster:match("^@")) then
							caster = caster:gsub("%-.*$", "")
							local spellName, _, spellIcon = GetSpellInfo(spellId)
							local iconText = "|T" .. spellIcon .. ":12:12:0:0:64:64:5:59:5:59|t"
							generatedText = generatedText .. iconText .. " " .. (caster or "") .. " "
						end
					end
				end

				if (#generatedText > 0) then
					generatedText = generatedText:gsub("%s$", "")

					lineProps.text2 = lineProps.text2 .. "("
					lineProps.text2 = lineProps.text2:gsub("$", generatedText)
					lineProps.text2 = lineProps.text2 .. ")"
				end

			elseif (token == "bosstimer") then
				local bossTimerId = thisMacro[CONST_MACRO_INDEXVALUE]
				--bossTimersToWatch[bossTimerId] = lineId
				lineProps.bossTimerId = bossTimerId

			elseif (token == "ifand" or token == "ifor") then
				conditions[lineId] = conditions[lineId] or {}
				local value1, opperator, value2 = thisMacro[2], thisMacro[3], thisMacro[4]
				tinsert(lineProps.conditions, {token, value1, opperator, value2})

			elseif (token == "combatlog") then
				local event = thisMacro[2]
				local spellId = thisMacro[3]
				local counter = thisMacro[4]
				local reset = thisMacro[5]

				event = convertEventToCleuEvent(event)

				lineProps.cleuEvent = event
				lineProps.cleuSpellId = spellId
				if (counter) then
					lineProps.cleuCounter = counter
				end

				lineProps.cleuEventTriggered = false
				lineProps.cleuEventCanReset = reset
				lineProps.progressBarResetTime = 0
			end
		end

		lineIdPhase[lineId] = currentPhase
	end

	--each line has its macros, even if it's an empty table
	for lineId = 1, #macroList do
		--get all macros declared on this line
		local macrosOnThisLine = macroList[lineId]

		--get line properties
		local lineProps = macroPlayback.lineProperties[lineId]

		--parse each macro on this line
		for i = 1, #macrosOnThisLine do
			local thisMacro = macrosOnThisLine[i]
			local token = thisMacro[CONST_MACRO_INDEXNAME]

			if (token == "countdown") then
				--verify if this line has a 'phaseTime'
				if (lineProps.phaseTime) then
					local progressTime = thisMacro[CONST_MACRO_INDEXVALUE]
					local startAt = lineProps.phaseTime - progressTime
					startAt = max(startAt, 1)
					--startAt X time in the phase; progressTime for X second after the startAt has been reached
					lineProps.countdown = {startAt, progressTime}

				--verify if there's a time for encounter elapsed time
				elseif (lineProps.timeElapsed) then
					local progressTime = thisMacro[CONST_MACRO_INDEXVALUE]
					local startAt = lineProps.timeElapsed - progressTime
					startAt = max(startAt, 1)
					lineProps.countdown = {startAt, progressTime}
				end

			elseif (token == "timer") then
				if (lineProps.phaseTime) then
					local startAt = lineProps.phaseTime
					local progressTime = thisMacro[CONST_MACRO_INDEXVALUE]
					lineProps.timer = {startAt, progressTime}

				elseif (lineProps.timeElapsed) then
					local startAt = lineProps.timeElapsed
					local progressTime = thisMacro[CONST_MACRO_INDEXVALUE]
					lineProps.timer = {startAt, progressTime}

				elseif (lineProps.cleuEvent) then
					lineProps.timer = {0, thisMacro[CONST_MACRO_INDEXVALUE] or 0}
				end
			end
		end
	end

	--elseif (token == "bosstimer") then
	--
	--elseif (token == "flash") then --need to know if line has "time"

	return macroPlayback
end

--called from "ShowNoteOnScreen" and also after updating all bars/lines shown
--this function is responsible for parsing all text and create a "playback" for when the encounter start
function Notepad.ParseNoteTextAndCreatePlayback(thisNote)
	if (not thisNote) then
		thisNote = Notepad:GetNote(Notepad.db.currently_shown, Notepad.db.currently_shown_noteId)
	end

	if (thisNote) then
		--raw text of the note
		local noteText = thisNote.note

		--> parse macros on the text of the note
			local textLines, macroList, variables, playersList = Notepad:ParseTextForMacros(noteText)

		--> organize the macro list to be played when the encounter start
			--also pre-build the text shown on the note
			local playbackObject = Notepad.CreateMacroPlayback(textLines, macroList, variables, playersList)
			Notepad.currentPlayback = playbackObject

			Notepad.FormatMarkerIcons(playbackObject)
			Notepad.HighlightPlayerName(playbackObject)

		--> set the text into the lines
			Notepad.UpdateTextOnScreenFrame(playbackObject)
	end
end

--~cleu ~combatlog
local CombatLogGetCurrentEventInfo = _G.CombatLogGetCurrentEventInfo
local CLEU_Frame = CreateFrame("frame")

local onCleuEvent = function()
	local time, token, hidding, whoSerial, whoName, whoFlags, whoFlags2, targetSerial, targetName, targetFlags, targetFlags2, spellId, spellName, spellType, amount, A5, A6, A7, A8, A9, A10, A11, A12 = CombatLogGetCurrentEventInfo()
	local playbackObject = Notepad.GetPlayback()

	--check if this event is important for the playback
	if (playbackObject.cleuEventFilter[token]) then
		local event = playbackObject.spellIdToEvent[spellId]
		if (event == token) then
			local cleuTriggered = playbackObject.cleuTriggered[spellId]
			if (not cleuTriggered) then
				cleuTriggered = {}
				playbackObject.cleuTriggered[spellId] = cleuTriggered
			end
			cleuTriggered[event] = GetTime()

			local triggerCounter = playbackObject.cleuTriggerCounter[spellId]
			if (not triggerCounter) then
				triggerCounter = {}
				playbackObject.cleuTriggerCounter[spellId] = triggerCounter
			end
			triggerCounter[event] = (triggerCounter[event] or 0) + 1
		end
	end
end

function Notepad.EnableCLEU()
	CLEU_Frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	CLEU_Frame:SetScript("OnEvent", onCleuEvent)
end

function Notepad.DisableCLEU()
	CLEU_Frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	CLEU_Frame:SetScript("OnEvent", nil)
end

--
function Notepad.FormatMarkerIcons(playbackObject)
	local lineProperties = playbackObject.lineProperties
	for lineId, lineProps in ipairs(lineProperties) do
		local text2 = lineProps.text2
		local formatedText = Notepad.FormatText(text2)
		lineProps.text2 = formatedText
	end
end

--make the player name be in caps e.g. [PLAYERNAME]
--called from "ParseNoteTextAndCreatePlayback" function
function Notepad.HighlightPlayerName(playbackObject)
	local playerName = UnitName("player")
	local _, class = UnitClass("player")

	local lineProperties = playbackObject.lineProperties
	for lineId, lineProps in ipairs(lineProperties) do
		local text2 = lineProps.text2
		local unitclasscolor = RAID_CLASS_COLORS[class] and RAID_CLASS_COLORS[class].colorStr
		if (unitclasscolor) then
			text2 = text2:gsub(playerName, "|cFFFFFF00[|r|c" .. unitclasscolor .. playerName:upper() .. "|r|cFFFFFF00]|r")
			text2 = text2:gsub(playerName:lower(), "|cFFFFFF00[|r|c" .. unitclasscolor .. playerName:upper() .. "|r|cFFFFFF00]|r")
		end

		lineProps.text2 = text2
	end
end


local simpleBarLineClean = function(barLine)
	barLine.text1.text = ""
	barLine.text2.text = ""

	barLine.lineProps = nil
	barLine.permanent = nil
	barLine.lineId = nil

	barLine.text1:SetAlpha(1)
	barLine.text2:SetAlpha(1)
	barLine.progressBar:StopTimer()
end


--called from "ParseNoteTextAndCreatePlayback" and only update the text shown, uses the possition of the virtual scrollbar
--if phase is passed, only the text for the selected phase is shown
--~update
function Notepad.UpdateTextOnScreenFrame(playbackObject, phase)

	local lineProperties = playbackObject.lineProperties
	local phasesStartPoint = playbackObject.phases
	local noteLinesAmount = #lineProperties
	local isShowingFullNote = not phase
	local isShowingSinglePhase = not isShowingFullNote
	local barLines = Notepad.GetAllBarLines()
	local barLinesAmount = #barLines
	local offset = 1 --start from the first index of the playback
	local hasAssist = RA:UnitHasAssist("player")
	local playerRole = DF.UnitGroupRolesAssigned("player")

	if (isShowingFullNote) then
		for lineId = 1, #lineProperties do
			local lineProps = lineProperties[lineId]
			lineProps.ignored = nil
		end

		--which events need to be listen to
		playbackObject.cleuEventFilter = {}
		--spellids per event
		--playbackObject.spellIdToEvent[spellId] = event
		playbackObject.spellIdToEvent = {}
		--store the events which got triggered during the combat
		--cleuTriggered[spellId][event] = GetTime()
		playbackObject.cleuTriggered = {}
		--store the amount of times the trigger got executed
		--cleuTriggerCounter[spellId][event] = 0
		playbackObject.cleuTriggerCounter = {}

	elseif (isShowingSinglePhase) then
		offset = phasesStartPoint[phase]
		--check if the phase wasn't declared
		if (not offset) then
			offset = 1
		end
	end

	if (isShowingFullNote) then
		--this is a reset and shoould show all lines, || clear the text on all lines
		for i = 1, barLinesAmount do
			local barLine = barLines[i]
			simpleBarLineClean(barLine)
		end

		Notepad.screenPanelReservedLines = 0
	end

	Notepad.SetScrollBarLinesOffset(offset)

	local hasPhase = false
	local reservedLines = 0
	local barLineId = 1

	if (isShowingSinglePhase) then
		--phase lines start after the permanent lines
		if (Notepad.screenPanelReservedLines) then
			if (Notepad.screenPanelReservedLines > 0) then
				barLineId = Notepad.screenPanelReservedLines + 1

				--iterate among reserved lines to get their cleu events (when the phase changes)
				for barLineId = 1, Notepad.screenPanelReservedLines do
					local barLine = Notepad.GetBarLine(barLineId)
					local lineProps = barLine.lineProps
					if (lineProps.cleuEvent) then
						playbackObject.cleuEventFilter[lineProps.cleuEvent] = true
						playbackObject.spellIdToEvent[lineProps.cleuSpellId] = lineProps.cleuEvent
					end
				end
			end
		end

		--clean all the other lines
		for i = barLineId, barLinesAmount do
			local barLine = Notepad.GetBarLine(i)
			simpleBarLineClean(barLine)
		end
	end

	for lineId = offset, noteLinesAmount do
		local lineProps = lineProperties[lineId]

		if (isShowingSinglePhase) then
			if (lineProps.phase > phase) then
				break
			end
		end

		if (lineProps.stopHere) then
			break
		end

		local ignoreThisLine = false

		--> check for player role, ignore if the unit has assist
		if (not hasAssist and lineProps.role and lineProps.role ~= playerRole) then
			ignoreThisLine = true

		elseif (lineProps.hidden) then
			ignoreThisLine = true
		end

		if (not ignoreThisLine) then
			if (barLineId <= barLinesAmount) then
				local barLine = Notepad.GetBarLine(barLineId)
				lineProps.ignored = nil

				if (isShowingFullNote) then
					--building the entire note
					if (lineProps.phase == 0) then
						barLine.permanent = true
						reservedLines = reservedLines + 1
					else
						hasPhase = true
					end

				elseif (isShowingSinglePhase) then
					lineProps.phaseTime = lineProps.phaseTimeConst
					lineProps.countdownStarted = nil
					lineProps.timerStarted = nil
				end

				if (lineProps.cleuEvent) then
					playbackObject.cleuEventFilter[lineProps.cleuEvent] = true
					playbackObject.spellIdToEvent[lineProps.cleuSpellId] = lineProps.cleuEvent

					lineProps.cleuEventTriggered = false
					lineProps.progressBarResetTime = 0

					--entered on new phase, reset spellId counter on the global trigger counter
					for spellId, eventTable in pairs(playbackObject.cleuTriggerCounter) do
						if (spellId == lineProps.cleuSpellId) then
							for eventName in pairs(eventTable) do
								eventTable[eventName] = 0
							end
						end
					end
				end

				local text = lineProps.text2

				if (lineProps.phaseTime) then
					local timeStamp = DetailsFramework:IntegerToTimer(lineProps.phaseTime)
					barLine.text1.text = timeStamp
					barLine.text2.text = text or ""

				elseif (lineProps.timeElapsed) then
					local timeStamp = DetailsFramework:IntegerToTimer(lineProps.timeElapsed)
					barLine.text1.text = timeStamp
					barLine.text2.text = text or ""

				else
					barLine.text1.text = text or ""
					barLine.text2.text = ""
				end

				lineProps.barLine = barLineId
				barLine.lineProps = lineProps
				barLine.lineId = lineId
				barLineId = barLineId + 1
			else
				break
			end
		else
			lineProps.ignored = true
		end
	end

	if (isShowingSinglePhase) then
		for i = barLineId, barLinesAmount do
			local barLine = barLines[i]
			if (barLine.lineProps) then
				if (not barLine.permanent and barLine.lineProps.phase ~= phase) then
					barLine.text1.text = ""
					barLine.text2.text = ""
					barLine.progressBar:StopTimer()
				end
			end
		end
	end

	if (isShowingFullNote and hasPhase) then
		if (reservedLines < noteLinesAmount) then
			Notepad.screenPanelReservedLines = reservedLines
		end
	end
end

--called when the phase has changed
function Notepad.OnPhaseChanged(oldPhase, newPhase)
	--check if there's a screen panel shown
	if (Notepad:GetCurrentlyShownBoss()) then
		Notepad.GetCurrentEncounterData().phase = newPhase
		--a note is currently shown, check if can scroll the note
		if (Notepad.db.can_scroll_to_phase) then
			--call the macro control?
		end
	end
end

local macroParserTick = function()
	--data stored when the encounter started
	local encounterInfo = Notepad.GetCurrentEncounterData()
		--data stored when the text notes got parsed
	local playbackObject = Notepad.GetPlayback()

	--[=[
		bugs:

	--]=]

	local barLines = Notepad.GetAllBarLines()
	local lineProperties = playbackObject.lineProperties
	local currentPhase = encounterInfo.currentPhase

	--> update elapsed time
		local currentTime = GetTime()

		--encounter and phase time
		encounterInfo.elapsedTime = encounterInfo.elapsedTime + (currentTime - encounterInfo.latestTickTime)
		encounterInfo.phaseElapsedTime = encounterInfo.phaseElapsedTime + (currentTime - encounterInfo.latestTickTime)
		encounterInfo.latestTickTime = currentTime
		local encounterElapsedTime = floor(encounterInfo.elapsedTime)
		local phaseElapsedTime = floor(encounterInfo.phaseElapsedTime)

	--> check for new phase
		local oldPhase, phaseHasChanged = currentPhase, false
		if (currentPhase ~= encounterInfo.phase) then
			encounterInfo.currentPhase = encounterInfo.phase
			currentPhase = encounterInfo.phase
			phaseHasChanged = true
		end

	--> check if the phase has changed
		if (phaseHasChanged) then
			--reset the phase elapsed time
			encounterInfo.phaseElapsedTime = 0
			Notepad.UpdateTextOnScreenFrame(playbackObject, currentPhase)
		end

	--update lines (macro tick)
	for barLineId = 1, #barLines do
		local barLine = Notepad.GetBarLine(barLineId)
		local lineId = barLine.lineId
		local lineProps = lineProperties[lineId]

		if (lineProps) then
			if (lineProps.phase == 0 or lineProps.phase == currentPhase) then

				--calculate the time left until the line reach the time goal
				local timeLeft, elapsed

				if (lineProps.phaseTime) then
					timeLeft = lineProps.phaseTime - phaseElapsedTime
					elapsed = phaseElapsedTime

				elseif (lineProps.timeElapsed) then
					timeLeft = lineProps.timeElapsed - encounterElapsedTime
					elapsed = encounterElapsedTime
				end

				--> update the timer in the left side of the line
					if (timeLeft) then
						if (timeLeft >= 1) then
							barLine.text1.text = DetailsFramework:IntegerToTimer(timeLeft)
							barLine.text1:SetAlpha(1)
							barLine.text2:SetAlpha(1)
						else
							barLine.text1.text = "0:00"
							barLine.text1:SetAlpha(0.5)
							barLine.text2:SetAlpha(0.5)
						end
					end
--macro tick
				--> check if the cleu got a trigger
					local needCleuTrigger, cleuTriggered = false, false
					local cleuSpellName = "" --debug only
					if (lineProps.cleuEvent) then
						needCleuTrigger = true
					end

					if (needCleuTrigger) then
						local cleuSpellId = lineProps.cleuSpellId
						local cleuEvent = lineProps.cleuEvent
						--triggerTime = time of the last time cleu triggered the event with the spellId
						local triggerTime = playbackObject.cleuTriggered[cleuSpellId] and playbackObject.cleuTriggered[cleuSpellId][cleuEvent]

						if (triggerTime) then
							if (not lineProps.cleuEventTriggered) then
								--print("macro tick(1): has trigger time and can execute", triggerTime)
							end
						end

						--print("combatlog onTick barLine:", barLineId, "line:", lineId, "need cleu", cleuEvent, "trigger time:", triggerTime)

						--na barra que deveria resetar a cada execução:
						--[15:00:47] macro tick(1): has trigger time and can execute 17847.423
						--[15:00:47] macro tick(2): has trigger time for spell: Fragments of Destiny 17847.423 17868.382 false
						--parou a execução em: if (triggerTime > lineProps.progressBarResetTime) then

						if (triggerTime) then
							if (not lineProps.cleuEventTriggered) then
								local spellName = GetSpellInfo(cleuSpellId) --debug only
								--print("macro tick(2): has trigger time for spell:", spellName, triggerTime, lineProps.progressBarResetTime, triggerTime > lineProps.progressBarResetTime)
								if (triggerTime > lineProps.progressBarResetTime) then
									--print("macro tick(3): trigger time is bigger than progressBar reset time")
									--check if there's a cleu counter
									local cleuCounterMatch = true
									local cleuCounter = lineProps.cleuCounter
									if (cleuCounter) then
										cleuCounterMatch = false
										local totalTriggers = playbackObject.cleuTriggerCounter[cleuSpellId] and playbackObject.cleuTriggerCounter[cleuSpellId][cleuEvent] or 0
										if (totalTriggers == cleuCounter) then
											cleuCounterMatch = true
										end
									end

									if (cleuCounterMatch) then
										lineProps.cleuEventTriggered = true
										cleuTriggered = true
										print("macro tick(4): all good, the combatlog trigger passes!") --a execução parou aqui
										cleuSpellName = spellName
									end
								end
							end
						end
					end

				--> start a progressbar
					--if (needCleuTrigger) then print("cleuTriggered:", cleuTriggered, "for", cleuSpellName, "debug:", not needCleuTrigger or (needCleuTrigger and cleuTriggered)) end --debug

					if (not needCleuTrigger or (needCleuTrigger and cleuTriggered)) then
						if (needCleuTrigger) then
							print("macro tick(5): allowed start timer", lineProps.timer, lineProps.timerStarted, "needCleuTrigger:", needCleuTrigger)
						end

						if (lineProps.countdown and not lineProps.countdownStarted) then
							local startAt, progressTime = lineProps.countdown[1], lineProps.countdown[2]
							if (startAt <= elapsed) then
								local currentTime, startTime, endTime = GetTime(), GetTime(), GetTime() + progressTime
								barLine.progressBar:SetTimer(currentTime, startTime, endTime)
								lineProps.countdownStarted = true
							end

						elseif (lineProps.timer and not lineProps.timerStarted) then
							print("macro tick(6): lineProps.timer and not lineProps.timerStarted!") --nao esta executando para "repetir" após a barra de tempo ter terminado
							if (cleuTriggered) then
								local currentTime, startTime, endTime = GetTime(), GetTime(), GetTime() + lineProps.timer[2]
								barLine.progressBar:SetTimer(currentTime, startTime, endTime)
								lineProps.timerStarted = true
								print("macro tick(7): timer started!")
							else
								local startAt, progressTime = lineProps.timer[1], lineProps.timer[2]
								if (startAt <= elapsed) then
									local currentTime, startTime, endTime = GetTime(), GetTime(), GetTime() + progressTime
									barLine.progressBar:SetTimer(currentTime, startTime, endTime)
									lineProps.timerStarted = true
								end
							end
						end
					end
			end
		end
	end
end

function RANotes.GetVariable(variableName) --external
	local playbackObject = Notepad.GetPlayback()
	if (playbackObject) then
		return playbackObject.variables[variableName]
	end
end

function RANotes.GetPlayerList(playerListId) --external
	local playbackObject = Notepad.GetPlayback()
	if (playbackObject) then
		local playerList = playbackObject.playerList[playerListId]
		if (playerList) then
			return playerList
		end
	end

	playerListId = playerListId or 1
	local allPlayerLists = {}

	--check if there's some note shown
	local bossId, _, noteId = Notepad:GetCurrentlyShownBoss()
	if (bossId) then
		--build a list of players list
		local macros = playbackObject.macroLines --numeric table with tables inside

		for lineId = 1, #macros do
			local macroTable = macros[lineId]
			for macroIndex = 1, #macroTable do
				local thisMacro = macroTable[macroIndex]
				if (thisMacro[CONST_MACRO_INDEXNAME] == "playerlist") then
					allPlayerLists[#allPlayerLists+1] = thisMacro[2] --second index is a table with a list of players
				end
			end
		end
	end

	return allPlayerLists[playerListId]
end

function Notepad.OnEncounterStart()
	if (not Notepad:GetCurrentlyShownBoss()) then
		return
	end

	local encounterInfo = Notepad.GetCurrentEncounterData()

	--reset the virtual scroll position to line 1
	Notepad.SetScrollBarLinesOffset(1)

	--check if the note shown is a note for the encounter
	local bossId, _, noteId = Notepad:GetCurrentlyShownBoss()

	if (bossId == encounterInfo.encounterIdEJ) then
		local newTicker = DetailsFramework.Schedules.NewTicker(1, macroParserTick)
		Notepad.currentMacroTicker = newTicker
	else
		print("NO TICKER, bossId is invalid...")
		--Details:Dump(encounterInfo)
	end

	Notepad.EnableCLEU()
end

function Notepad.OnEncounterEnd(encounterID, encounterName, difficultyID, raidSize, endStatus)
	local bossId, _, noteId = Notepad:GetCurrentlyShownBoss()
	local bossKilled = false
	if (bossId) then
		local bossName = Notepad:GetBossName(bossId)
		if (bossName == encounterName) then
			if (endStatus == 1) then
				Notepad.UnshowNoteOnScreen()
				bossKilled = true
			end
		end
	end

	local currentEncounter = Notepad.GetCurrentEncounterData()
	if (currentEncounter) then
		currentEncounter.isEnded = true
	end

	--stop macro ticker
	if (Notepad.currentMacroTicker) then
		Notepad.currentMacroTicker:Cancel()
		Notepad.currentMacroTicker =  nil
	end

	local barLines = Notepad.GetAllBarLines()
	for barLineId, barLine in ipairs(barLines) do
		if (barLine.progressBar:IsShown()) then
			barLine.progressBar:StopTimer()
		end
	end

	local playbackObject = Notepad.GetPlayback()
	if (not bossKilled and playbackObject) then
		Notepad.UpdateTextOnScreenFrame(playbackObject)
	end

	Notepad.DisableCLEU()

	--clear progress bars


	--hide progress bars externals
end


function Notepad:ShowNoteOnScreen(bossId, noteId, isSelf) --~showscreen ~shownote
	local thisNote = Notepad:GetNote(bossId, noteId)
	if (thisNote) then
		--currently shown in the screen
		Notepad:SetCurrentlyShownBoss(bossId, noteId)

		if (Notepad.UpdateFrameShownOnOptions) then
			Notepad:UpdateFrameShownOnOptions()
		end

		Notepad.screenFrame:Show()
		Notepad.screenFrame.Macros = {}
		Notepad.ParseNoteTextAndCreatePlayback(thisNote)

		--play flash animation
		if (not isSelf) then
			Notepad.DoFlashAnim()
			--track mouse position to detect player afk
			Notepad.MouseCursorX, Notepad.MouseCursorY = GetCursorPosition()
			C_Timer.After(3, trackMousePosForAFKDetection)
		end
		Notepad:UpdateScreenFrameBackground()

		if (Notepad.screenFrame:GetHeight() < 5) then
			Notepad.screenFrame:SetHeight(40)
		end
	end
end

function Notepad.UnshowNoteOnScreen(from_close_button)
	if (Notepad:GetCurrentlyShownBoss()) then
		Notepad:SetCurrentlyShownBoss(false)

		if (Notepad.options_built) then
			Notepad.mainFrame.frameNoteShown:Hide()
		end

		Notepad.screenFrame:Hide()

		if (Notepad.mainFrame and Notepad.mainFrame.frameNoteShown) then
			Notepad.mainFrame.frameNoteShown:Hide()
		end

		if (from_close_button) then
			if (isRaidLeader("player")) then
				RA:ShowPromptPanel(L["S_PLUGIN_NOTE_CLOSE_ONALLPEERS"], function() Notepad:SendHideShownNote() end, function() end)
			end
		end
	end
end

function RANotes.GetNoteLines() --external
	--check if there's some note shown
	local bossId, _, noteId = Notepad:GetCurrentlyShownBoss()
	if (bossId) then
		return Notepad.GetPlayback().textLines
	end
end

function Notepad:ValidateNoteCurrentlyShown()
	if (not IsInRaid() and not IsInGroup()) then
		return Notepad.UnshowNoteOnScreen()
	end
end

function Notepad:ZONE_CHANGED_NEW_AREA()
	local _, instanceType = GetInstanceInfo()
	if (instanceType ~= "raid" and instanceType ~= "party") then
		if (Notepad:GetCurrentlyShownBoss()) then
			Notepad.UnshowNoteOnScreen()
		end
	end
end

function Notepad:GROUP_ROSTER_UPDATE()
	if (Notepad.playerIsInGroup and not IsInGroup()) then
		--left the group
		Notepad.UnshowNoteOnScreen()

	elseif (not Notepad.playerIsInGroup and IsInGroup()) then
		--joined a group
		local _, instanceType = GetInstanceInfo()
		if (instanceType and instanceType == "raid") then
			Notepad:AskForEnabledNote()
		end
	end
	Notepad.playerIsInGroup = IsInGroup()

	Notepad.BuildListOfPlayersInRaid()
end

function Notepad:PLAYER_REGEN_DISABLED()
	if (Notepad.db.hide_on_combat and (InCombatLockdown() or UnitAffectingCombat ("player")) and Notepad:GetCurrentlyShownBoss() and not Notepad.mainFrame:IsShown()) then
		Notepad.screenFrame:Hide()
	end
	Notepad.screenFrame.on_combat = true
end

function Notepad:PLAYER_REGEN_ENABLED()
	if (Notepad:GetCurrentlyShownBoss() and Notepad.screenFrame.on_combat) then
		Notepad.screenFrame:Show()
	end
	Notepad.screenFrame.on_combat = nil
end

function Notepad:PLAYER_LOGOUT()
	--if there's a boss shown in the screen, dave it again to refresh when it was set in the screen
	--when the player logon again, check if the logout was not long time ago and show again to the screen
	local bossId, _, noteId = Notepad:GetCurrentlyShownBoss()
	if (bossId) then
		Notepad:SetCurrentlyShownBoss(bossId, noteId)
	end
end

function Notepad:ENCOUNTER_START(event, ...) --~encounterstart ~start
	local encounterID, encounterName, difficultyID, raidSize = ...
	local EJID --encounter journal ID

	local mapIdFromInstance = select(8, GetInstanceInfo())
	local mapIdFromEJ = select(8, EJ_GetEncounterInfoByIndex(1))

	if (mapIdFromInstance ~= mapIdFromEJ) then
		local bestMap = C_Map.GetBestMapForUnit("player")
		if (bestMap) then
			local instanceId = EJ_GetInstanceForMap(bestMap)
			if (instanceId) then
				EJ_SelectInstance(instanceId)
			end
		end
	end

	--print("Encounter Start Payload:", encounterID, encounterName, difficultyID, raidSize) --2435, sylvanas, 17, 25

	for i = 1, 20 do
		local name, _, thisEJID, _, _, _, dungeonEncounterID = EJ_GetEncounterInfoByIndex(i)
		if (name) then
			if (encounterID == dungeonEncounterID) then
				EJID = thisEJID
				break
			end
		else
			break
		end
	end

	local newEncounterData = {
		encounterIdCL = encounterID,
		encounterIdEJ = EJID,
		encounterName = encounterName,
		startTime = GetTime(),
		isEnded = false,
		phase = 1,
		currentPhase = 0,
		elapsedTime = 0,
		phaseElapsedTime = 0,
		combatElapsedTime = 0,
		latestTickTime = GetTime(),
	}

	Notepad.SetCurrentEncounterData(newEncounterData)

	Notepad.OnEncounterStart()
end

function Notepad.GetCurrentEncounterData()
	return Notepad.SavedEncounterData
end

function Notepad.SetCurrentEncounterData(encounterData)
	Notepad.SavedEncounterData = encounterData
end

function Notepad:ENCOUNTER_END(event, ...)
	local encounterID, encounterName, difficultyID, raidSize, endStatus = ...
	Notepad.OnEncounterEnd(encounterID, encounterName, difficultyID, raidSize, endStatus)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Notepad.ShowPickFrame(whatToShow)
	if (whatToShow == "playerlist") then
		Notepad.mainFrame.pickFrame:Show()
		Notepad.mainFrame.pickFrame.selectPlayerFrame:Show()
		Notepad.mainFrame.pickFrame.selectMacroFrame:Hide()

		--update the scroll frame showing the list of players
		Notepad.mainFrame.pickFrame.selectPlayerFrame.playerSelectionScroll.UpdatePlayerList()

	elseif (whatToShow == "macros") then
		Notepad.mainFrame.pickFrame:Show()
		Notepad.mainFrame.pickFrame.selectPlayerFrame:Hide()
		Notepad.mainFrame.pickFrame.selectMacroFrame:Show()

		--update the macro list
		Notepad.mainFrame.pickFrame.selectMacroFrame.macroSelectionScroll:Refresh()
	end
end

local createPickFrame = function(mainFrame)
	local pFrame = CreateFrame("frame", "$parentPickFrame", mainFrame, "BackdropTemplate")
	pFrame:SetWidth(200)
	pFrame:SetPoint("topleft", RaidAssistOptionsPanel, "topright", 0, 0)
	pFrame:SetPoint("bottomleft", RaidAssistOptionsPanel, "bottomright", 0, 0)
	mainFrame.pickFrame = pFrame

	--> player list and macro list buttons
		local showPlayerList = function()
			Notepad.ShowPickFrame("playerlist")
			pFrame.listOfPlayersButton:SetTemplate("RAIDASSIST_BUTTON_SELECTED")
			pFrame.listOfMacrosButton:SetTemplate("RAIDASSIST_BUTTON_DISABLED")

		end
		local showMacroList = function()
			Notepad.ShowPickFrame("macros")
			pFrame.listOfPlayersButton:SetTemplate("RAIDASSIST_BUTTON_DISABLED")
			pFrame.listOfMacrosButton:SetTemplate("RAIDASSIST_BUTTON_SELECTED")
		end

		local playerListButton = Notepad:CreateButton(pFrame, showPlayerList, (pFrame:GetWidth()/2) - 4, 20, "Players", _, _, _, "listOfPlayersButton", _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		playerListButton:SetPoint("topleft", pFrame, "topleft", 2, -2)
		playerListButton:SetIcon([[Interface\FriendsFrame\Battlenet-Portrait]])
		pFrame.listOfPlayersButton:SetTemplate("RAIDASSIST_BUTTON_SELECTED")
		
		local macroListButton = Notepad:CreateButton(pFrame, showMacroList, (pFrame:GetWidth()/2) - 4, 20, "Macros", _, _, _, "listOfMacrosButton", _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		macroListButton:SetPoint("left", playerListButton, "right", 2, 0)
		macroListButton:SetIcon([[Interface\MacroFrame\MacroFrame-Icon]])
		pFrame.listOfMacrosButton:SetTemplate("RAIDASSIST_BUTTON_DISABLED")

	local playerSelectionAmoutLines = 18 --~player ~list
	local playerSelectionLinesHeight = 20

	local macroSelectionAmoutLines = 15
	local macroSelectionLinesHeight = 40

	DetailsFramework:ApplyStandardBackdrop(pFrame)

	--> select player frame
		local selectPlayerFrame = CreateFrame("frame", "$parentSelectPlayer", pFrame, "BackdropTemplate")
		selectPlayerFrame:SetAllPoints()
		pFrame.selectPlayerFrame = selectPlayerFrame

		--update scroll lines
		local refreshPlayerList = function(self, data, offset, totalLines)
			--update boss scroll
			for i = 1, totalLines do
				local index = i + offset
				local playerTable = data[index]
				if (playerTable) then

					local playerName, roleName, className = unpack(playerTable)

					local line = self:GetLine(i)
					if (line) then
						local cleanName = playerName --text without class color
						playerName = DetailsFramework:AddClassColorToText(playerName, className)

						line.PlayerName = playerName
						line.PlayerNameClean = cleanName

						local l, r, t, b, texture = DetailsFramework:GetClassTCoordsAndTexture(className)
						line.classIcon:SetTexture(texture)
						line.classIcon:SetTexCoord(l, r, t, b)

						local roleTexture, L, R, T, B = DF:GetRoleIconAndCoords(roleName)
						line.roleIcon:SetTexture(roleTexture)
						line.roleIcon:SetTexCoord(L, R, T, B)

						line.playerName:SetText(playerName)
						line:Show()
					end
				end
			end
		end

		--scroll frame
		local playerSelectionScroll = DF:CreateScrollBox(selectPlayerFrame, "$parentScroll", refreshPlayerList, {}, pFrame:GetWidth()-2, pFrame:GetHeight(), playerSelectionAmoutLines, playerSelectionLinesHeight)
		selectPlayerFrame.playerSelectionScroll = playerSelectionScroll
		DetailsFramework:ReskinSlider(playerSelectionScroll)
		playerSelectionScroll:SetAllPoints()
		playerSelectionScroll:SetPoint("topleft", selectPlayerFrame, "topleft", 0, -40)
		playerSelectionScroll:SetPoint("bottomright", selectPlayerFrame, "bottomright", -22, 0)

		function playerSelectionScroll.UpdatePlayerList()
			local listOfPlayers = {
				DAMAGER = {},
				HEALER = {},
				TANK = {},
				NONE = {},
			}

			if (IsInRaid()) then
				for i = 1, GetNumGroupMembers() do
					local name, rank, subgroup, level, class, fileName, zone, online, isDead, raidRole, isML, role = GetRaidRosterInfo(i)
					if (name) then
						local byRole = listOfPlayers[role]
						byRole[#byRole+1] = {name, role, fileName}
					end
				end

			elseif (IsInGroup()) then
				for i = 1, GetNumGroupMembers()-1 do
					local playerName = UnitName("party" .. i)
					if (playerName) then
						listOfPlayers[#listOfPlayers+1] = playerName
					end
				end
				listOfPlayers[#listOfPlayers+1] = UnitName("player")

			else
				local playerRole = DF.UnitGroupRolesAssigned("player")
				local byRole = listOfPlayers[playerRole]
				byRole[#byRole+1] = {UnitName("player"), playerRole, select(2, UnitClass("player"))}
			end

			local damagers = listOfPlayers.DAMAGER
			table.sort(damagers, function(t1, t2) return t1[1] < t2[1] end)

			local healers = listOfPlayers.HEALER
			table.sort(healers, function(t1, t2) return t1[1] < t2[1] end)

			local tanks = listOfPlayers.TANK
			table.sort(tanks, function(t1, t2) return t1[1] < t2[1] end)

			local none = listOfPlayers.NONE
			table.sort(none, function(t1, t2) return t1[1] < t2[1] end)

			local newListOfPlayers = {}
			for i, playerTable in ipairs(tanks) do
				newListOfPlayers[#newListOfPlayers+1] = playerTable
			end
			for i, playerTable in ipairs(healers) do
				newListOfPlayers[#newListOfPlayers+1] = playerTable
			end
			for i, playerTable in ipairs(damagers) do
				newListOfPlayers[#newListOfPlayers+1] = playerTable
			end
			for i, playerTable in ipairs(none) do
				newListOfPlayers[#newListOfPlayers+1] = playerTable
			end

			playerSelectionScroll:SetData(newListOfPlayers)
			playerSelectionScroll:Refresh()
		end

		local onEnterLine = function(self)
			self:SetBackdropColor(unpack(scrollbox_line_backdrop_color_hightlight))
		end

		local onLeaveLine = function(self)
			self:SetBackdropColor(unpack(scrollbox_line_backdrop_color))
		end

		local onClickLine = function(self)
			local playerName = self.PlayerName
			if (playerName) then
				Notepad.mainFrame.editboxNotes.editbox:SetFocus(true)
				local cursorPos = Notepad.mainFrame.editboxNotes.editbox:GetCursorPosition()
				Notepad.mainFrame.editboxNotes.editbox:Insert(playerName)
				Notepad.mainFrame.editboxNotes.editbox:SetCursorPosition(cursorPos + #playerName)
			end
		end

		--create scroll lines
		local createPlayerLine = function(self, index)
			local line = CreateFrame("button", "$parentLine" .. index, self, "BackdropTemplate")
			line:SetPoint("topleft", self, "topleft", 0, -((index-1) * (playerSelectionLinesHeight+1)) - 1)
			line:SetSize(self:GetWidth(), playerSelectionLinesHeight)
			line:RegisterForClicks("LeftButtonDown", "RightButtonDown")
			DetailsFramework:ApplyStandardBackdrop(line)

			line:SetScript("OnEnter", onEnterLine)
			line:SetScript("OnLeave", onLeaveLine)
			line:SetScript("OnClick", onClickLine)

			line.index = index

			--class icon
			local classIcon = line:CreateTexture("$parentIcon", "overlay")
			classIcon:SetSize(playerSelectionLinesHeight, playerSelectionLinesHeight)
			--classIcon:SetPoint("left", line, "left", 2, 0)
			line.classIcon = classIcon

			--role icon
			local roleIcon = line:CreateTexture("$parentIcon", "overlay")
			roleIcon:SetSize(playerSelectionLinesHeight-4, playerSelectionLinesHeight-4)
			--roleIcon:SetPoint("left", classIcon, "right", 2, 0)
			roleIcon:SetPoint("left", line, "left", 2, 0)
			line.roleIcon = roleIcon

			local playerName = line:CreateFontString(nil, "overlay", "GameFontNormal")
			playerName:SetPoint("left", roleIcon, "right", 3, 0)

			DetailsFramework:SetFontSize(playerName, 11)

			line.classIcon = classIcon
			line.roleIcon = roleIcon
			line.playerName = playerName

			return line
		end

		--create the scrollbox lines
		for i = 1, playerSelectionAmoutLines do
			playerSelectionScroll:CreateLine(createPlayerLine, i)
		end

	--> select macro frame
		local selectMacroFrame = CreateFrame("frame", "$parentSelectMacro", pFrame, "BackdropTemplate")
		selectMacroFrame:SetAllPoints()
		pFrame.selectMacroFrame = selectMacroFrame

		local listOfMacros = {
			{command = "time", name = "Time", example = "[time = 120], [time = 2:00]", desc = L["S_PLUGIN_NOTE_MACRO_TIME_DESC"], addtext = "[time = ]"},
			{command = "phase", name = "Phase", example = "[phase = 1], [phase = 2]", desc = L["S_PLUGIN_NOTE_MACRO_PHASE_DESC"], alias = {"p"}, addtext = "[phase = ]"},
			{command = "cooldown", name = "Cooldown", example = "[cooldown = 62618, playername]", desc = "Accept a spellId and a player name.", alias = {"cd"}, addtext = "[cooldown = ]"},
			{command = "combatlog", name = "Combat Log", example = "a simple cast start:\n[combatlog = caststart, 355540, false, false]\n\nspell interrupted with a loop of 3 interrupts:\n[combatlog = interrupt, 355540, 1, 3]\n\nusing a regular combat log event:\n[combatlog = SPELL_HEAL, 355540]\n\nstart a 10 seconds time bar after cast started:\n[combatlog = caststart, 355540; timer = 15]\n\nshow the spell name and icon:\n[cleu = caststart, 355540; enemyspell=355540]", desc = "Trigger the line upon combat log event.", args = {{"Event", "combat log token."}, {"SpellId", "spell ID."}, {"Counter", "times casted"}, {"Reset", "set counter to 1 after X amount of casts."}}, alias = {"cl", "cleu"}, addtext = "[combatlog = ]"},
			{command = "playerlist", name = "Player List", example = "[playerlist = playerName3, playerName35, playerName11]", desc = L["S_PLUGIN_NOTE_MACRO_PLAYERLIST_DESC"], alias = {"pl"}, addtext = "[playerlist = ]"},
			{command = "enemyspell", name = "Enemy Spell", example = "[enemyspell = 355540]", desc = "Show the spell icon and the spell name.", alias = {"es"}, addtext = "[enemyspell = ]"},
			{command = "hide", name = "Hide Line", example = "[hide]", desc = "Don't show this line.", alias = {"hidden", "nop"}, addtext = "[hide]"},
			{command = "countdown", name = "Countdown", example = "[countdown = 20]", desc = "Start a time bar for the line X seconds before the time in the line is reached.", addtext = "[countdown = ]"},
			{command = "timer", name = "Timer", example = "[timer = 120]", desc = "Start a time bar for the line when it reaches its time for X seconds.", addtext = "[timer = ]"},
			{command = "role", name = "Role", example = "[role = HEALER]", desc = "Show the line only for players with the role.", addtext = "[role = ]"},
			{command = "notext", name = "No Text", example = "[notext]", desc = "Don't show any text on the line", addtext = "[notext]"},
			{command = "stop", name = "Stop", example = "[stop]", desc = "Won't show text placed after the stop macro.", alias = {"end"}, addtext = "[stop]"},
			{command = "name", name = "Name", example = "[phase = 1; name = phaseone]\n[$phaseone] < shows value 1", desc = "Give a name to a macro value, the value can be accessed by using '$' and the name.", addtext = "name ="},

--			{command = "", name = "", example = "[]", desc = "", alias = "", addtext = "[]"},
--			{command = "", name = "", example = "[]", desc = "", alias = "", addtext = "[]"},
--			{command = "", name = "", example = "[]", desc = "", alias = "", addtext = "[]"},

			--"bosstimer"
			--"if"
		}

		local refreshMacroList = function(self, data, offset, totalLines)
			--update boss scroll
			for i = 1, totalLines do
				local index = i + offset
				local macroData = data[index]

				if (macroData) then
					local line = self:GetLine(i)
					if (line) then
						local macroName = macroData.name
						local macroExample = macroData.example
						local macroDesc = macroData.desc
						local macroAlias = macroData.alias
						local macroText = macroData.addtext

						line.macroName:SetText(macroData.command)
						line.macroText:SetText(macroText)
						line.macroData = macroData

						line.index = index
					end
				end
			end
		end

		--scroll frame
		local macroSelectionScroll = DF:CreateScrollBox(selectMacroFrame, "$parentScroll", refreshMacroList, listOfMacros, pFrame:GetWidth()-2, pFrame:GetHeight(), macroSelectionAmoutLines, macroSelectionLinesHeight)
		selectMacroFrame.macroSelectionScroll = macroSelectionScroll
		DetailsFramework:ReskinSlider(macroSelectionScroll)
		macroSelectionScroll:SetAllPoints()
		macroSelectionScroll:SetPoint("topleft", selectMacroFrame, "topleft", 0, -40)
		macroSelectionScroll:SetPoint("bottomright", selectMacroFrame, "bottomright", -22, 0)

		--> macro tooltip
			local macroSelectionTooltip = CreateFrame("frame", "$parentTooltip", selectMacroFrame, "BackdropTemplate")
			macroSelectionTooltip:SetSize(300, 400)
			macroSelectionTooltip:SetPoint("topright", selectMacroFrame, "topleft", -2, 0)
			DetailsFramework:ApplyStandardBackdrop(macroSelectionTooltip)
			macroSelectionTooltip:SetFrameLevel(selectMacroFrame:GetFrameLevel()+50)

			--parent, text, size, color, font, member, name, layer
			local macroName = DetailsFramework:CreateLabel(macroSelectionTooltip, "", 12, "orange")
			local macroNameText = DetailsFramework:CreateLabel(macroSelectionTooltip, "", 11)

			local macroCommand = DetailsFramework:CreateLabel(macroSelectionTooltip, "", 12, "orange")
			local macroCommandText = DetailsFramework:CreateLabel(macroSelectionTooltip, "", 11)
			local textToAdd = DetailsFramework:CreateLabel(macroSelectionTooltip, "", 11)

			local desc = DetailsFramework:CreateLabel(macroSelectionTooltip, "", 12, "orange")
			local descText = DetailsFramework:CreateLabel(macroSelectionTooltip, "", 11)
			descText:SetSize(macroSelectionTooltip:GetWidth()-10, 40)
			descText.align = "<"
			descText.valign = "^"

			local arguments = DetailsFramework:CreateLabel(macroSelectionTooltip, "", 12, "orange")
			local argumentsText = DetailsFramework:CreateLabel(macroSelectionTooltip, "", 11)
			argumentsText.align = "<"
			argumentsText.valign = "^"

			local example = DetailsFramework:CreateLabel(macroSelectionTooltip, "", 12, "orange")
			local exampleText = DetailsFramework:CreateLabel(macroSelectionTooltip, "", 11)
			exampleText:SetSize(macroSelectionTooltip:GetWidth()-10, 220)
			exampleText.align = "<"
			exampleText.valign = "^"

			local tooltipLineHeight = 12
			local tooltipMaxLineHeight = 25

			local alignObjectsInGroup = function(parent, startX, startY, space1, space2, groupOfObjects)
				local previousObject
				local y = startY

				for i = 1, #groupOfObjects do
					local thisGroup = groupOfObjects[i]
					local newGroup = true

					for o = 1, #thisGroup do
						local object = thisGroup[o]
						object:ClearAllPoints()

						if (not previousObject) then
							object:SetPoint(startX, startY)
							previousObject = object
							newGroup = false

						else
							local sizeToUse = max(1, newGroup and space2 or space1, previousObject:GetHeight())
							y = y - sizeToUse
							object:SetPoint(startX, y)
							previousObject = object
							newGroup = nil
						end
					end
				end
			end

			macroSelectionTooltip.macroName = macroName
			macroSelectionTooltip.macroNameText = macroNameText
			macroSelectionTooltip.macroCommand = macroCommand
			macroSelectionTooltip.macroCommandText = macroCommandText
			macroSelectionTooltip.textToAdd = textToAdd
			macroSelectionTooltip.desc = desc
			macroSelectionTooltip.descText = descText
			macroSelectionTooltip.arguments = arguments
			macroSelectionTooltip.argumentsText = argumentsText
			macroSelectionTooltip.example = example
			macroSelectionTooltip.exampleText = exampleText

			function macroSelectionTooltip:SetTooltip(buttonIndex)
				local macroInfo = listOfMacros[buttonIndex]
				if (macroInfo) then
					macroSelectionTooltip.macroName.text = "Macro Name:"
					macroSelectionTooltip.macroNameText.text = macroInfo.name

					macroSelectionTooltip.macroCommand.text = "Macro Command:"
					local commands = macroInfo.command
					if (macroInfo.alias) then
						for i = 1, #macroInfo.alias do
							commands = commands .. ", " .. macroInfo.alias[i]
						end
					end
					macroSelectionTooltip.macroCommandText.text = commands
					macroSelectionTooltip.textToAdd.text = macroInfo.addtext

					macroSelectionTooltip.desc.text = "Description:"
					macroSelectionTooltip.descText.text = macroInfo.desc

					macroSelectionTooltip.arguments.text = "Arguments:"
					local argumentsList = ""
					if (macroInfo.args) then
						for i = 1, #macroInfo.args do
							local argName = macroInfo.args[i][1]
							local argDesc = macroInfo.args[i][2]
							argumentsList = argumentsList .. argName .. ": " .. argDesc .. "\n"
						end
						argumentsList = argumentsList:gsub("\n$", "")
						argumentsText:SetSize(macroSelectionTooltip:GetWidth()-10, max(10, (#macroInfo.args+1) * tooltipLineHeight))
					else
						argumentsText:SetSize(macroSelectionTooltip:GetWidth()-10, 10)
					end
					macroSelectionTooltip.argumentsText.text = argumentsList

					macroSelectionTooltip.example.text = "Example:"
					macroSelectionTooltip.exampleText.text = macroInfo.example

					alignObjectsInGroup(macroSelectionTooltip, 2, -5, tooltipLineHeight, tooltipMaxLineHeight, {{macroName, macroNameText}, {macroCommand, macroCommandText, textToAdd}, {desc, descText}, {arguments, argumentsText}, {example, exampleText}})
					macroSelectionTooltip:Show()
				end
			end

			--{command = "combatlog", name = "Combat Log", example = "[combatlog = caststart, 355540, false, false]", desc = "Trigger the line upon combat log event.", arg = {"event: combat log token.", "spellId: spell ID.", "counter: times casted", "reset: set counter to 1 after X amount of casts."}, alias = "cl, cleu", addtext = "[combatlog = ]"},


		local onEnterLine = function(self)
			self:SetBackdropColor(unpack(scrollbox_line_backdrop_color_hightlight))
			if (self.index) then
				macroSelectionTooltip:SetTooltip(self.index)
			end
		end

		local onLeaveLine = function(self)
			self:SetBackdropColor(unpack(scrollbox_line_backdrop_color))
			macroSelectionTooltip:Hide()
		end

		local onClickMacroLine = function(self)
			local macroData = self.macroData
			if (macroData) then
				Notepad.mainFrame.editboxNotes.editbox:SetFocus(true)
				local cursorPos = Notepad.mainFrame.editboxNotes.editbox:GetCursorPosition()

				Notepad.ignore_text_changed = true

				Notepad.mainFrame.editboxNotes.editbox:Insert(macroData.addtext)
				Notepad.mainFrame.editboxNotes.editbox:SetCursorPosition(cursorPos + #macroData.addtext - 1)

				Notepad.ignore_text_changed = false
			end
		end

		--create scroll lines
		local createMacroLine = function(self, index)
			local line = CreateFrame("button", "$parentLine" .. index, self, "BackdropTemplate")
			line:SetPoint("topleft", self, "topleft", 0, -((index-1) * (macroSelectionLinesHeight+1)) - 2)
			line:SetSize(self:GetWidth(), macroSelectionLinesHeight)
			line:RegisterForClicks("LeftButtonDown", "RightButtonDown")
			DetailsFramework:ApplyStandardBackdrop(line)

			line:SetScript("OnEnter", onEnterLine)
			line:SetScript("OnLeave", onLeaveLine)
			line:SetScript("OnClick", onClickMacroLine)

			line.index = index

			--icon
			local icon = line:CreateTexture("$parentIcon", "overlay")
			icon:SetSize(macroSelectionLinesHeight-4, macroSelectionLinesHeight-4)
			icon:SetTexture([[Interface\MacroFrame\MacroFrame-Icon]])
			icon:SetPoint("left", line, "left", 2, 0)
			icon:SetAlpha(.7)
			line.icon = icon

			local macroName = line:CreateFontString(nil, "overlay", "GameFontNormal")
			macroName:SetPoint("left", icon, "right", 4, 7)

			local macroText = line:CreateFontString(nil, "overlay", "GameFontNormal")
			macroText:SetPoint("left", icon, "right", 4, -7)

			DetailsFramework:SetFontSize(macroName, 11)
			DetailsFramework:SetFontSize(macroText, 11)
			DetailsFramework:SetFontColor(macroText, "silver")

			line.icon = icon
			line.macroName = macroName
			line.macroText = macroText

			return line
		end

		--create the scrollbox lines
		for i = 1, macroSelectionAmoutLines do
			macroSelectionScroll:CreateLine(createMacroLine, i)
		end

end

function Notepad.OnShowOnOptionsPanel()
	local OptionsPanel = Notepad.OptionsPanel
	Notepad.BuildOptions (OptionsPanel)
end

function Notepad.BuildOptions(frame) --~options õptions
	if (frame.FirstRun) then
		Notepad.ShowPickFrame("playerlist")
		return
	end

	C_Timer.After(0, function() Notepad.ShowPickFrame("playerlist") end)

	Notepad.db.latest_menu_option_boss_selected = Notepad.db.latest_menu_option_boss_selected or 0
	Notepad.db.latest_menu_option_note_selected = Notepad.db.latest_menu_option_note_selected or 1

	frame.FirstRun = true

	local mainFrame = frame
	mainFrame:SetSize (840, 680)
	Notepad.mainFrame = mainFrame

	createPickFrame(mainFrame)

	mainFrame:SetScript("OnShow", function()
		if (Notepad:GetCurrentlyShownBoss()) then
			Notepad:UpdateFrameShownOnOptions()
			if (Notepad.screenFrame.on_combat) then
				Notepad.screenFrame:Show()
			end
		else
			mainFrame.frameNoteShown:Hide()
		end

		Notepad.BuildListOfPlayersInRaid()
	end)

	mainFrame:SetScript ("OnHide", function()
		Notepad:PLAYER_REGEN_DISABLED()
	end)

	local userScreenPanelOptions = CreateFrame("frame", "NotepadTextOptionsPanel", mainFrame, "BackdropTemplate")
	mainFrame.userScreenPanelOptions = userScreenPanelOptions
	userScreenPanelOptions:SetSize(630, 600)
	userScreenPanelOptions:SetPoint("topleft", mainFrame, "topleft", 230, 5)

	userScreenPanelOptions:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
	userScreenPanelOptions:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))
	userScreenPanelOptions:SetBackdropColor(.1, .1, .1, 1)

	local on_select_text_font = function (self, fixed_value, value)
		Notepad.db.text_font = value
		Notepad:UpdateScreenFrameSettings()
	end
	local on_select_text_anchor = function (self, fixed_value, value)
		Notepad.db.text_justify = value
		Notepad:UpdateScreenFrameSettings()
	end
	local text_anchor_options = {
		{value = "left", label = L["S_ANCHOR_LEFT"], onclick = on_select_text_anchor},
		{value = "right", label = L["S_ANCHOR_RIGHT"], onclick = on_select_text_anchor},
	}
	local set_frame_strata = function (_, _, strata)
		Notepad.db.framestrata = strata
		Notepad:UpdateScreenFrameSettings()
	end
	local strataTable = {}
	strataTable [1] = {value = "BACKGROUND", label = "BACKGROUND", onclick = set_frame_strata}
	strataTable [2] = {value = "LOW", label = "LOW", onclick = set_frame_strata}
	strataTable [3] = {value = "MEDIUM", label = "MEDIUM", onclick = set_frame_strata}
	strataTable [4] = {value = "HIGH", label = "HIGH", onclick = set_frame_strata}
	strataTable [5] = {value = "DIALOG", label = "DIALOG", onclick = set_frame_strata}
	
	local options_list = {
	
		{type = "label", get = function() return L["S_FRAME"] .. ":" end, text_template = Notepad:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},
		--
		{
			type = "toggle",
			get = function() return Notepad.db.locked end,
			set = function (self, fixedparam, value) 
				Notepad.db.locked = value
				Notepad:UpdateScreenFrameSettings()
			end,
			desc = L["S_PLUGIN_FRAME_LOCKED_DESC"],
			name = L["S_PLUGIN_FRAME_LOCKED"],
			
		},

		{
			type = "toggle",
			get = function() return Notepad.db.background.show end,
			set = function (self, fixedparam, value) 
				Notepad.db.background.show = value
				Notepad:UpdateScreenFrameSettings()
			end,
			desc = "",
			name = L["S_FRAME_BACKGROUND"],
		},

		{
			type = "color",
			get = function() 
				return {Notepad.db.background.r, Notepad.db.background.g, Notepad.db.background.b, Notepad.db.background.a} 
			end,
			set = function (self, r, g, b, a) 
				local color = Notepad.db.background
				color.r, color.g, color.b, color.a = r, g, b, a
				Notepad:UpdateScreenFrameSettings()
			end,
			name = L["S_FRAME_BACKGROUND_COLOR"],
		},

		{
			type = "select",
			get = function() return Notepad.db.framestrata end,
			values = function() return strataTable end,
			name = L["S_FRAME_STRATA"]
		},

		{type = "blank"},
		{
			type = "toggle",
			get = function() return Notepad.db.hide_on_combat end,
			set = function (self, fixedparam, value) 
				Notepad.db.hide_on_combat = value
				Notepad:UpdateScreenFrameSettings()
			end,
			desc = "",
			name = L["S_HIDE_IN_COMBAT"],
		},

		--
		{
			type = "blank",
		},
		--

		{type = "label", get = function() return L["S_TEXT"] .. ":" end, text_template = Notepad:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},
		{
			type = "range",
			get = function() return Notepad.db.text_size end,
			set = function (self, fixedparam, value) 
				Notepad.db.text_size = value
				Notepad:UpdateScreenFrameSettings()
			end,
			min = 4,
			max = 32,
			step = 1,
			name = L["S_PLUGIN_TEXT_SIZE"],
		},
		{
			type = "select",
			get = function() return Notepad.db.text_font end,
			values = function() return Notepad:BuildDropDownFontList (on_select_text_font) end,
			name = L["S_PLUGIN_TEXT_FONT"],
		},
		{
			type = "select",
			get = function() return Notepad.db.text_justify end,
			values = function() return text_anchor_options end,
			name = L["S_PLUGIN_TEXT_ANCHOR"],
		},
		{
			type = "toggle",
			get = function() return Notepad.db.text_shadow end,
			set = function (self, fixedparam, value) 
				Notepad.db.text_shadow = value
				Notepad:UpdateScreenFrameSettings()
			end,
			name = L["S_PLUGIN_TEXT_SHADOW"],
		},

		--[=[
		{type = "breakline"},
		{
			type = "toggle",
			get = function() return Notepad.db.can_scroll_to_phase end,
			set = function (self, fixedparam, value)
				Notepad.db.can_scroll_to_phase = value
			end,
			name = "Auto Scroll to Phase",
		},
		--]=]
	}

	local options_text_template = Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE")
	local options_dropdown_template = Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
	local options_switch_template = Notepad:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE")
	local options_slider_template = Notepad:GetTemplate ("slider", "OPTIONS_SLIDER_TEMPLATE")
	local options_button_template = Notepad:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE")

	--Notepad:SetAsOptionsPanel(userScreenPanelOptions)
	Notepad:BuildMenu(userScreenPanelOptions, options_list, 10, -12, 300, true, options_text_template, options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template)

	--left boss selection scroll frame functions
	local refreshBossList = function(self, data, offset, totalLines)

		local lastBossSelected = Notepad.db.editing_boss_id

		--update boss scroll
		for i = 1, totalLines do
			local index = i + offset
			local thisData = data[index]
			if (thisData) then

				local line = self:GetLine(i)

				if (thisData.newNoteButtom) then --create new note button
					local bossId = thisData.bossId
					local bossIcon = thisData.bossIcon

					--update the line
					line.noteIndicator:Show()
					line.bossName:SetText(L["S_PLUGIN_NOTE_NEWNOTE"])
					line.bossName:SetPoint("left", line.bossIcon, "right", 5, 0)
					DF:TruncateText(line.bossName, 130)
					line.bossRaidName:SetText("")
					DF:TruncateText(line.bossRaidName, 130)

					line.bossIcon:SetTexture([[Interface\PaperDollInfoFrame\Character-Plus]])
					line.bossIcon:SetTexCoord(0, 1, 0, 1)
					line.bossIcon:SetSize(16, 16)
					line.bossIcon:SetPoint("left", line, "left", 15, 0)

					line:SetBackdropColor(unpack(scrollbox_line_backdrop_color))
					--line:SetBackdropColor(.3, .3, .3, 1)

					line.deleteButton:Hide()
					line.renameButton:Hide()

					if (self.isMaximized) then
						line.bossName:Show()
						line.bossRaidName:Show()
					end

					line.bossId = bossId
					line.noteId = 1
					line.seed = nil
					line.createButton = true

				elseif (thisData.name and thisData.note) then --select note button
					local noteName = thisData.name
					local bossId = thisData.bossId
					local seed = thisData.seed
					local noteId = thisData.noteId

					--update the line
					line.noteIndicator:Show()
					line.bossName:SetText(noteName)
					line.bossName:SetPoint("left", line.bossIcon, "right", 5, 0)
					DF:TruncateText(line.bossName, 130)
					line.bossRaidName:SetText("") --seed
					DF:TruncateText(line.bossRaidName, 130)

					line.bossIcon:SetTexture([[Interface\ICONS\INV_Inscription_Parchment]])
					line.bossIcon:SetTexCoord(0.95, 0.05, 0.05, 0.95)
					line.bossIcon:SetSize(16, 16)
					line.bossIcon:SetPoint("left", line, "left", 15, 0)

					if (thisData.isSelected) then
						line:SetBackdropColor(unpack(scrollbox_line_backdrop_color_selected))
					else
						line:SetBackdropColor(unpack(scrollbox_line_backdrop_color))
					end

					if (thisData.amountNotes >= 1) then
						if (self.isMaximized) then
							line.deleteButton:Show()
							line.renameButton:Show()
						end
					else
						line.deleteButton:Hide()
						line.renameButton:Hide()
					end

					if (self.isMaximized) then
						line.bossName:Show()
						line.bossRaidName:Show()
					end

					line.bossId = bossId
					line.noteId = noteId
					line.seed = seed
					line.createButton = false

				else --select boss button
					local bossName = thisData.bossName
					local bossRaidName = thisData.bossRaidName
					local bossIcon = thisData.bossIcon
					local bossId = thisData.bossId

					--update the line
					line.noteIndicator:Hide()
					line.bossName:SetText(bossName)
					line.bossName:SetPoint("left", line.bossIcon, "right", -8, 6)
					DF:TruncateText(line.bossName, 130)
					line.bossRaidName:SetText(bossRaidName)
					DF:TruncateText(line.bossRaidName, 130)

					line.bossIcon:SetTexture(bossIcon)
					line.bossIcon:SetTexCoord(unpack(thisData.bossIconCoords))
					line.bossIcon:SetSize(thisData.bossIconSize[1], thisData.bossIconSize[2])

					if (self.isMaximized) then
						line.bossIcon:SetPoint("left", line, "left", 2, 0)
						line.bossName:Show()
						line.bossRaidName:Show()
					else
						line.bossIcon:SetPoint("left", line, "left", -2, 0)
					end

					if (bossId == lastBossSelected) then
						line:SetBackdropColor(unpack(scrollbox_line_backdrop_color_selected))
					else
						line:SetBackdropColor(unpack(scrollbox_line_backdrop_color))
					end

					line.deleteButton:Hide()
					line.renameButton:Hide()

					line.bossId = bossId
					line.seed = nil

					local notesForThisBoss = Notepad.db.boss_notes2[bossId]
					if (notesForThisBoss) then
						line.noteId = notesForThisBoss.lastInUse
					else
						line.noteId = 1
					end

					line.createButton = false
				end

				line:Show()
			end
		end
	end

	function Notepad.SelectNote(bossId, noteId)
		local notesForThisBoss = Notepad.db.boss_notes2[bossId]
		notesForThisBoss.lastInUse = noteId

		Notepad.db.latest_menu_option_boss_selected = bossId
		Notepad.db.latest_menu_option_note_selected = noteId

		Notepad:SetCurrentEditingBossId(bossId, noteId)
	end

	local onClickDeleteNote = function(self)
		local line = self:GetParent()
		local bossId = line.bossId
		local noteId = line.noteId

		local notesForThisBoss = Notepad.db.boss_notes2[bossId]
		local noteSelected = notesForThisBoss.lastInUse

		tremove(notesForThisBoss.notes, noteId)

		if (noteSelected == noteId) then
			--select note 1
			notesForThisBoss.lastInUse = 1
			Notepad:SetCurrentEditingBossId(bossId, 1)

		elseif (noteSelected > noteId) then
			notesForThisBoss.lastInUse = notesForThisBoss.lastInUse - 1
			Notepad:SetCurrentEditingBossId(bossId, notesForThisBoss.lastInUse)
		end
	end

	local onDeleteNoteMouseDown = function(self)
		self:GetNormalTexture():SetPoint("center", 1, -1)
	end

	local onDeleteNoteMouseUp = function(self)
		self:GetNormalTexture():SetPoint("center", 0, 0)
	end

	local onClickRenameNote = function(self)
		local line = self:GetParent()
		local bossId = line.bossId
		local noteId = line.noteId

		local notesForThisBoss = Notepad.db.boss_notes2[bossId]
		local thisNote = notesForThisBoss.notes[noteId]
		local noteName = thisNote.name

		line.renameEntry:Show()
		line.renameEntry:SetFocus(true)
	end

	local onRenameNoteMouseDown = function(self)
		self:GetNormalTexture():SetPoint("center", 1, -1)
	end

	local onRenameNoteMouseUp = function(self)
		self:GetNormalTexture():SetPoint("center", 0, 0)
	end

	local onClickBossLine = function(self)
		local bossId = self.bossId
		local noteId = self.noteId

		if (self.createButton) then
			--create new note
			local notesForThisBoss = Notepad.db.boss_notes2[bossId]
			local newNote, newNoteId = createNewNote(notesForThisBoss)

			Notepad.db.latest_menu_option_boss_selected = bossId
			Notepad.db.latest_menu_option_note_selected = newNote
			noteId = newNoteId

			notesForThisBoss.lastInUse = #notesForThisBoss.notes

			Notepad:SetCurrentEditingBossId(bossId, noteId)

			local menuLines = mainFrame.bossScrollFrame:GetFrames()
			for i = 1, #menuLines do
				local line = menuLines[i]
				if (line.seed == newNote.seed) then
					line.renameButton.isCreating = true
					onClickRenameNote(line.renameButton)
					break
				end
			end
		else
			Notepad.SelectNote(bossId, noteId)
			C_Timer.After(0, function()
				mainFrame.BossSelectionBox:RefreshMe()
			end)
		end
	end

	local onEnterBossLine = function(self)
		if (Notepad.db.editing_boss_id ~= self.bossId) then
			self:SetBackdropColor(unpack(scrollbox_line_backdrop_color_hightlight))
		end
	end

	local onLeaveBossLine = function(self)
		if (Notepad.db.editing_boss_id ~= self.bossId) then
			self:SetBackdropColor(unpack(scrollbox_line_backdrop_color))
		end
	end

	local createdBossLine = function(self, index)
		local line = CreateFrame("button", "$parentLine" .. index, self, "BackdropTemplate")
		line:SetPoint("topleft", self, "topleft", 1, -((index-1) * (bossLinesHeight+1)) - 1)
		line:SetSize(scrollBossWidth-2, bossLinesHeight)
		line:RegisterForClicks("LeftButtonDown", "RightButtonDown")
		DF:ApplyStandardBackdrop(line)

		line:SetScript("OnEnter", onEnterBossLine)
		line:SetScript("OnLeave", onLeaveBossLine)
		line:SetScript("OnClick", onClickBossLine)

		line.index = index

		--note indicator
		local noteIndicator = line:CreateTexture(nil, "overlay")
		noteIndicator:SetColorTexture(.7, .7, .7, .3)
		noteIndicator:SetPoint("topleft", line, "topleft", 5, -1)
		noteIndicator:SetPoint("bottomleft", line, "bottomleft", 5, 1)
		noteIndicator:SetWidth(4)

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

		--erase button
		local deleteButton = CreateFrame("button", nil, line, "BackdropTemplate")
		deleteButton:SetPoint("right", line, "right", -3, 0)
		deleteButton:SetSize(16, 16)
		deleteButton:SetScript("OnClick", onClickDeleteNote)
		deleteButton:SetScript("OnMouseDown", onDeleteNoteMouseDown)
		deleteButton:SetScript("OnMouseUp", onDeleteNoteMouseUp)

		deleteButton:SetNormalTexture([[Interface\GLUES\LOGIN\Glues-CheckBox-Check]])
		deleteButton:GetNormalTexture():ClearAllPoints()
		deleteButton:GetNormalTexture():SetPoint("center", 0, 0)

		deleteButton:SetScript("OnEnter", function()
			deleteButton:GetNormalTexture():SetBlendMode("ADD")
		end)

		deleteButton:SetScript("OnLeave", function()
			deleteButton:GetNormalTexture():SetBlendMode("BLEND")
		end)

		--edit button
		local renameButton = CreateFrame("button", nil, line, "BackdropTemplate")
		renameButton:SetPoint("right", deleteButton, "left", -2, 0)
		renameButton:SetSize(16, 16)
		renameButton:SetScript("OnClick", onClickRenameNote)
		renameButton:SetScript("OnMouseDown", onRenameNoteMouseDown)
		renameButton:SetScript("OnMouseUp", onRenameNoteMouseUp)

		renameButton:SetNormalTexture([[Interface\BUTTONS\UI-GuildButton-PublicNote-Up]])
		renameButton:GetNormalTexture():ClearAllPoints()
		renameButton:GetNormalTexture():SetPoint("center", 0, 0)

		renameButton:SetScript("OnEnter", function()
			renameButton:GetNormalTexture():SetBlendMode("ADD")
		end)

		renameButton:SetScript("OnLeave", function()
			renameButton:GetNormalTexture():SetBlendMode("BLEND")
		end)

		local onRenameCommit = function()
			local bossId = line.bossId
			local noteId = line.noteId

			local newName = line.renameEntry:GetText()
			if (#newName > 0) then
				bossName:SetText(newName)
				local notesForThisBoss = Notepad.db.boss_notes2[bossId]
				local thisNote = notesForThisBoss.notes[noteId]
				thisNote.name = newName

				if (line.renameButton.isCreating) then
					--this note just got created, select it to edit
					Notepad.SelectNote(bossId, noteId)
				end
			end

			bossName:Show()
			line.renameEntry:ClearFocus()
			line.renameEntry:Hide()

			line.renameButton.isCreating = nil
		end

		--text entry to type the new note name
		local renameEntry = DetailsFramework:CreateTextEntry(line, onRenameCommit, 120, 20, _, _, _, DetailsFramework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
		renameEntry:SetPoint("left", bossName, "left", -8, 1)
		renameEntry:SetPoint("right", renameButton, "left", -2, 1)
		renameEntry:SetJustifyH("left")
		renameEntry:SetBackdrop(nil)
		renameEntry:Hide()

		renameEntry:SetHook("OnEditFocusGained", function()
			local bossId = line.bossId
			local noteId = line.noteId

			local notesForThisBoss = Notepad.db.boss_notes2[bossId]
			local thisNote = notesForThisBoss.notes[noteId]
			local noteName = thisNote.name

			bossName:Hide()
			renameEntry:SetText(noteName)
			renameEntry:HighlightText(0)
		end)

		renameEntry:SetHook("OnEditFocusLost", function()
			bossName:Show()
			line.renameEntry:HighlightText(0, 0)
			line.renameEntry:ClearFocus()
			line.renameEntry:Hide()
			line.renameButton.isCreating = nil
		end)

		renameEntry:SetHook("OnEscapePressedHook", function()
			renameEntry:Hide()
			bossName:Show()
			line.renameButton.isCreating = nil
		end)

		line.noteIndicator = noteIndicator
		line.bossName = bossName
		line.bossRaidName = bossRaid
		line.deleteButton = deleteButton
		line.renameButton = renameButton
		line.renameEntry = renameEntry

		return line
	end

	--create the boss data table
	local bossData = Notepad:GetBossList()

	--create the left scroll to select which boss to edit ~bossframe
	local bossScrollFrame = DF:CreateScrollBox(mainFrame, "$parentBossScrollBox", refreshBossList, bossData, scrollBossWidth, scrollBossHeight, amoutBossLines, bossLinesHeight)
	mainFrame.bossScrollFrame = bossScrollFrame
	bossScrollFrame.isMaximized = true

	function Notepad.GetBossScrollFrame()
		return bossScrollFrame
	end

	--create the scrollbox lines
	for i = 1, amoutBossLines do
		bossScrollFrame:CreateLine(createdBossLine, i)
	end

	DF:ReskinSlider(bossScrollFrame)

	DF:ApplyStandardBackdrop(bossScrollFrame)
	mainFrame.BossSelectionBox = bossScrollFrame
	bossScrollFrame:SetPoint("topleft", mainFrame, "topleft", 0, 5)

	bossScrollFrame.RefreshMe = function(self)
		--always will have a boss selected
		local latestBossSelected = Notepad.db.latest_menu_option_boss_selected

		--data tem a lista de boss
		local bossData = Notepad:GetBossList()
		--local data = bossScrollFrame:GetData()
		local data = bossData
		local menuList = {}

		for i = 1, #data do
			local bossData = data[i]
			local bossId = bossData.bossId

			local notesForThisBoss = Notepad.db.boss_notes2[bossId]
			if (not notesForThisBoss) then
				notesForThisBoss = createBossNoteStructure(bossId)
			end

			menuList[#menuList+1] = bossData

			--if this is the latest selected
			if (bossId == latestBossSelected) then
				local bossNotes = notesForThisBoss.notes
				local lastNoteSelected = notesForThisBoss.lastInUse

				local amountNotes = #bossNotes

				if (amountNotes == 0) then
					createNewNote(notesForThisBoss)
				end

				for o = 1, amountNotes do
					local noteCopy = DetailsFramework.table.copy({}, bossNotes[o])
					noteCopy.noteId = o
					noteCopy.amountNotes = amountNotes
					noteCopy.isSelected = lastNoteSelected == o
					menuList[#menuList+1] = noteCopy
				end

				--create the +note button
				menuList[#menuList+1] = {newNoteButtom = true, bossId = bossId}
			end
		end

		bossScrollFrame:SetData(menuList)
		bossScrollFrame:Refresh()
	end

	bossScrollFrame:RefreshMe()
	bossScrollFrame:Show()
	bossScrollFrame:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))

	function bossScrollFrame.Minimize()
		local newSize = scrollBossWidth / 3.5
		bossScrollFrame:SetWidth(newSize)

		--restore line size
		local allScrollLines = bossScrollFrame:GetLines()
		for i = 1, #allScrollLines do
			local line = bossScrollFrame:GetLine(i)
			line:SetWidth(newSize)
			line.bossName:Hide()
			line.bossRaidName:Hide()
			line.renameEntry:Hide()
			line.deleteButton:Hide()
			line.renameButton:Hide()
		end

		bossScrollFrame.isMaximized = false

		--hide the scrollbar
		local scrollBar = _G[bossScrollFrame:GetName() .. "ScrollBar"]
		scrollBar:Hide()

		--> get the text editor and increase its size
			local editBox = Notepad.GetEditBox()
			--set the new point
			editBox:SetPoint("topleft", mainFrame, "topleft", 62, -14)
			--increase the size
			editBox:SetSize(CONST_EDITBOX_WIDTH_MAX, CONST_EDITBOX_HEIGHT_MAX)
	end

	function bossScrollFrame.Maximize()
		bossScrollFrame:SetWidth(scrollBossWidth)

		--restore line size
		local allScrollLines = bossScrollFrame:GetLines()
		for i = 1, #allScrollLines do
			local line = bossScrollFrame:GetLine(i)
			line:SetWidth(scrollBossWidth)
		end

		--show the scrollbar
		local scrollBar = _G[bossScrollFrame:GetName() .. "ScrollBar"]
		scrollBar:Show()

		--> get the text editor and return its values to default
			local editBox = Notepad.GetEditBox()
			--restore its point
			editBox:SetPoint("topleft", mainFrame, "topleft", 225, -14)
			--restore the size
			editBox:SetSize(CONST_EDITBOX_WIDTH, CONST_EDITBOX_HEIGHT)

		bossScrollFrame.isMaximized = true
		bossScrollFrame:RefreshMe()
	end

	--block showing the current boss in the screen ~showing
	local frameNoteShown = CreateFrame("frame", nil, mainFrame, "BackdropTemplate")
	frameNoteShown:SetPoint("bottomright", mainFrame, "bottomright", 26, 26)
	frameNoteShown:SetSize(190, 43)
	frameNoteShown:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
	frameNoteShown:SetBackdropColor(1, 1, 1, .5)
	frameNoteShown:SetBackdropBorderColor(0, 0, 0, 1)
	--frameNoteShown:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))
	frameNoteShown:Hide()

	mainFrame.frameNoteShown = frameNoteShown

	--> currently showing note
	local labelNoteShown1 = Notepad:CreateLabel (frameNoteShown, L["S_PLUGIN_SHOWING_ONSCREEN"] .. ":", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"), _, _, "label_note_show1")
	local labelNoteShown2 = Notepad:CreateLabel (frameNoteShown, "", Notepad:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"), _, _, "label_note_show2")
	labelNoteShown1:SetPoint (5, -5)
	labelNoteShown2:SetPoint (5, -25)

	local unsendButton = Notepad:CreateButton (frameNoteShown, Notepad.UnshowNoteOnScreen, 40, 40, "X", _, _, _, "button_unsend", _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	unsendButton:SetSize(24, 24)
	unsendButton:SetPoint("right", frameNoteShown, "right", -8, 0)

	function Notepad:UpdateFrameShownOnOptions()
		local bossId, noteId = Notepad:GetCurrentEditingBossId()
		local note = Notepad:GetNote(bossId, noteId)
		local bossInfo = Notepad:GetBossInfo(bossId)

		if (note) then
			mainFrame.frameNoteShown:Show()
			mainFrame.frameNoteShown.label_note_show2.text = bossInfo and bossInfo.bossName or note.name
			mainFrame.shiftEnterLabel:Hide()
		else
			mainFrame.frameNoteShown:Hide()
		end
	end

	--> multi line editbox for edit the note ~lua ~editbox ~editor
	local editboxNotes = Notepad:NewSpecialLuaEditorEntry (mainFrame, CONST_EDITBOX_WIDTH, CONST_EDITBOX_HEIGHT, "editboxNotes", "RaidAssignmentsNoteEditbox", true)
	editboxNotes:SetPoint("topleft", mainFrame, "topleft", 225, -14)
	editboxNotes:SetBackdrop(nil)

	DetailsFramework:ReskinSlider(editboxNotes.scroll)

	editboxNotes.scroll:ClearAllPoints()
	editboxNotes.scroll:SetPoint("topleft", editboxNotes, "topleft", 1, -1)
	editboxNotes.scroll:SetPoint("bottomright", editboxNotes, "bottomright", -1, 0)

	local f, h, fl = editboxNotes.editbox:GetFont()
	editboxNotes.editbox:SetFont(f, 12, fl)
	editboxNotes.editbox:SetAllPoints()
	editboxNotes.editbox:SetBackdrop(nil)
	editboxNotes.editbox:SetTextInsets(4, 4, 4, 4)

	local rr, gg, bb = unpack(CONST_EDITBOX_COLOR)
	local backgroundTexture1 = editboxNotes.scroll:CreateTexture(nil, "background", nil, -6)
	backgroundTexture1:SetAllPoints()
	backgroundTexture1:SetColorTexture(rr, gg, bb, Notepad.db.editor_alpha)

	local backgroundTexture2 = editboxNotes.editbox:CreateTexture(nil, "background", nil, -6)
	backgroundTexture2:SetAllPoints()
	backgroundTexture2:SetColorTexture(rr, gg, bb, Notepad.db.editor_alpha)

	local backgroundTexture3 = editboxNotes:CreateTexture(nil, "background", nil, -6)
	backgroundTexture3:SetAllPoints()
	backgroundTexture3:SetColorTexture(0, 0, 0, 1)

	editboxNotes.backgroundTexture1 = backgroundTexture1
	editboxNotes.backgroundTexture2 = backgroundTexture2

	function Notepad.GetEditBox()
		return editboxNotes
	end

	RaidAssignmentsNoteEditboxScrollBar:SetPoint("topleft", editboxNotes, "topright", -20, -16)
	RaidAssignmentsNoteEditboxScrollBar:SetPoint("bottomleft", editboxNotes, "bottomright", -20, 16)

	function Notepad.ColorPlayerNames()
		if (Notepad.db.auto_format) then
			local file = mainFrame.editboxNotes.editbox:GetText()

			local RAID_CLASS_COLORS = _G["RAID_CLASS_COLORS"]
			for playerName, playerClass in pairs(Notepad.playersCache) do
				if (playerClass and RAID_CLASS_COLORS[playerClass]) then
					--regular case
					local unitclasscolor = RAID_CLASS_COLORS[playerClass].colorStr
					file = file:gsub("|c" .. unitclasscolor .. playerName .. "|r", playerName)
					file = file:gsub(playerName, "|c" .. unitclasscolor .. playerName .. "|r")

					--lower case
					playerName = playerName:lower()
					local unitclasscolor = RAID_CLASS_COLORS[playerClass].colorStr
					file = file:gsub("|c" .. unitclasscolor .. playerName .. "|r", playerName)
					file = file:gsub(playerName, "|c" .. unitclasscolor .. playerName .. "|r")
				end
			end

			for playerName, playerClass in pairs(Notepad.playersCache) do
				local lowerName = playerName:lower()
				file = file:gsub(lowerName, playerName)

				local upperName = playerName:upper()
				file = file:gsub(upperName, playerName)
			end

			mainFrame.editboxNotes.editbox:SetText(file)
		end
	end

	editboxNotes:Hide()

	local clearEditbox = function()
		editboxNotes:SetText("")
	end

	local saveChanges = function()
		Notepad.ColorPlayerNames()
		Notepad:SaveCurrentEditingNote()
	end

	local saveChangesAndSend = function()
		saveChanges()
		local bossId, noteId = Notepad:GetCurrentEditingBossId()
		Notepad:ShowNoteOnScreen(bossId, noteId, true)
		Notepad:SendNote(bossId, noteId)
	end

	local saveChangesAndClose = function()
		saveChanges()
		Notepad:CancelNoteEditing()

		Notepad.GetBossScrollFrame():Maximize()
	end

	local buttonWidth = 100

	--clear "Clear"
	local clearButton =  Notepad:CreateButton (mainFrame, clearEditbox, buttonWidth, 20, L["S_PLUGIN_NOTE_CLEARTEXT"], _, _, _, "buttonClear", _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	clearButton:SetIcon ([[Interface\Glues\LOGIN\Glues-CheckBox-Check]])
	clearButton.widget.texture_disabled:SetTexture ([[Interface\Tooltips\UI-Tooltip-Background]])
	clearButton.widget.texture_disabled:SetVertexColor (0, 0, 0)
	clearButton.widget.texture_disabled:SetAlpha (.5)
	mainFrame.buttonClear = clearButton

	--save "Save"
	local saveButton =  Notepad:CreateButton (mainFrame, saveChanges, buttonWidth, 20, L["S_SAVE"], _, _, _, "buttonSave", _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	saveButton:SetIcon ([[Interface\BUTTONS\UI-CheckBox-Check]], 16, 16, "overlay", {0, 1, 0, 28/32}, {1, 1, 1}, 2, 1, 0)
	saveButton.widget.texture_disabled:SetTexture ([[Interface\Tooltips\UI-Tooltip-Background]])
	saveButton.widget.texture_disabled:SetVertexColor (0, 0, 0)
	saveButton.widget.texture_disabled:SetAlpha (.5)
	mainFrame.buttonSave = saveButton

	--save and send "Send"
	local save2Button =  Notepad:CreateButton (mainFrame, saveChangesAndSend, buttonWidth, 20, L["S_SEND"], _, _, _, "buttonSave2", _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	save2Button:SetIcon ([[Interface\BUTTONS\JumpUpArrow]], 14, 12, "overlay", {0, 1, 0, 32/32}, {1, 1, 1}, 2, 1, 0)
	save2Button.widget.texture_disabled:SetTexture ([[Interface\Tooltips\UI-Tooltip-Background]])
	save2Button.widget.texture_disabled:SetVertexColor (0, 0, 0)
	save2Button.widget.texture_disabled:SetAlpha (.5)
	mainFrame.buttonSave2 = save2Button

	--cancel edition "Done"
	local cancelButton = Notepad:CreateButton (mainFrame, saveChangesAndClose, buttonWidth, 20, L["S_CLOSE_EDITOR"], _, _, _, "buttonCancel", _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	mainFrame.doneButton = cancelButton
	cancelButton:SetIcon ([[Interface\BUTTONS\UI-CheckBox-Check]], 16, 16, "overlay", {0, 1, 0, 28/32}, {1, 0.8, 0}, 2, 1, 0)
	cancelButton.widget.texture_disabled:SetTexture ([[Interface\Tooltips\UI-Tooltip-Background]])
	cancelButton.widget.texture_disabled:SetVertexColor (0, 0, 0)
	cancelButton.widget.texture_disabled:SetAlpha (.5)
	mainFrame.buttonCancel = cancelButton

	--create the shift + enter text
	local shiftEnterLabel = Notepad:CreateLabel(mainFrame, L["S_PLUGIN_SEND_SHORTCUT"])
	shiftEnterLabel:SetPoint("left", clearButton, "right", 20, -1)
	shiftEnterLabel.color = "orange"
	shiftEnterLabel.fontsize = 13
	mainFrame.shiftEnterLabel = shiftEnterLabel

	--set points
	do
		local buttons_y = -635
		cancelButton:SetPoint ("topleft", mainFrame, "topleft", 572 , buttons_y)
		save2Button:SetPoint ("right", cancelButton, "left", -16 , 0)
		saveButton:SetPoint ("right", save2Button, "left", -16 , 0)
		clearButton:SetPoint ("topleft", mainFrame, "topleft", 62 , buttons_y)
	end

	mainFrame.buttonCancel:Hide()
	mainFrame.buttonClear:Hide()
	mainFrame.buttonSave:Hide()
	mainFrame.buttonSave2:Hide()

	mainFrame.buttonCancel:Disable()
	mainFrame.buttonClear:Disable()
	mainFrame.buttonSave:Disable()
	mainFrame.buttonSave2:Disable()
	mainFrame.editboxNotes:Disable()

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> text format

	--color
	local colors_panel = CreateFrame ("frame", nil, editboxNotes, "BackdropTemplate")
	local get_color_hash = function (t)
		local r = RA:Hex (floor (t[1]*255))
		local g = RA:Hex (floor (t[2]*255))
		local b = RA:Hex (floor (t[3]*255))
		return r .. g .. b
	end
	
	local color_pool

	-- code author Saiket from  http://www.wowinterface.com/forums/showpost.php?p=245759&postcount=6
	--- @return StartPos, EndPos of highlight in this editbox.
	local function GetTextHighlight ( self )
		local Text, Cursor = self:GetText(), self:GetCursorPosition();
		self:Insert( "" ); -- Delete selected text
		local TextNew, CursorNew = self:GetText(), self:GetCursorPosition();
		-- Restore previous text
		self:SetText( Text );
		self:SetCursorPosition( Cursor );
		local Start, End = CursorNew, #Text - ( #TextNew - CursorNew );
		self:HighlightText( Start, End );
		return Start, End;
	end
	local StripColors;
	do
		local CursorPosition, CursorDelta;
		--- Callback for gsub to remove unescaped codes.
		local function StripCodeGsub ( Escapes, Code, End )
			if ( #Escapes % 2 == 0 ) then -- Doesn't escape Code
				if ( CursorPosition and CursorPosition >= End - 1 ) then
					CursorDelta = CursorDelta - #Code;
				end
				return Escapes;
			end
		end
		--- Removes a single escape sequence.
		local function StripCode ( Pattern, Text, OldCursor )
			CursorPosition, CursorDelta = OldCursor, 0;
			return Text:gsub( Pattern, StripCodeGsub ), OldCursor and CursorPosition + CursorDelta;
		end
		--- Strips Text of all color escape sequences.
		-- @param Cursor  Optional cursor position to keep track of.
		-- @return Stripped text, and the updated cursor position if Cursor was given.
		function StripColors ( Text, Cursor )
			Text, Cursor = StripCode( "(|*)(|c%x%x%x%x%x%x%x%x)()", Text, Cursor );
			return StripCode( "(|*)(|r)()", Text, Cursor );
		end
	end
	
	local COLOR_END = "|r";
	--- Wraps this editbox's selected text with the given color.
	local function ColorSelection ( self, ColorCode )
		local Start, End = GetTextHighlight( self );
		local Text, Cursor = self:GetText(), self:GetCursorPosition();
		if ( Start == End ) then -- Nothing selected
			--Start, End = Cursor, Cursor; -- Wrap around cursor
			return; -- Wrapping the cursor in a color code and hitting backspace crashes the client!
		end
		-- Find active color code at the end of the selection
		local ActiveColor;
		if ( End < #Text ) then -- There is text to color after the selection
			local ActiveEnd;
			local CodeEnd, _, Escapes, Color = 0;
			while ( true ) do
				_, CodeEnd, Escapes, Color = Text:find( "(|*)(|c%x%x%x%x%x%x%x%x)", CodeEnd + 1 );
				if ( not CodeEnd or CodeEnd > End ) then
					break;
				end
				if ( #Escapes % 2 == 0 ) then -- Doesn't escape Code
					ActiveColor, ActiveEnd = Color, CodeEnd;
				end
			end
       
			if ( ActiveColor ) then
				-- Check if color gets terminated before selection ends
				CodeEnd = 0;
				while ( true ) do
					_, CodeEnd, Escapes = Text:find( "(|*)|r", CodeEnd + 1 );
					if ( not CodeEnd or CodeEnd > End ) then
						break;
					end
					if ( CodeEnd > ActiveEnd and #Escapes % 2 == 0 ) then -- Terminates ActiveColor
						ActiveColor = nil;
						break;
					end
				end
			end
		end
     
		local Selection = Text:sub( Start + 1, End );
		-- Remove color codes from the selection
		local Replacement, CursorReplacement = StripColors( Selection, Cursor - Start );
     
		self:SetText( ( "" ):join(
			Text:sub( 1, Start ),
			ColorCode, Replacement, COLOR_END,
			ActiveColor or "", Text:sub( End + 1 )
		) );
     
		-- Restore cursor and highlight, adjusting for wrapper text
		Cursor = Start + CursorReplacement;
		if ( CursorReplacement > 0 ) then -- Cursor beyond start of color code
			Cursor = Cursor + #ColorCode;
		end
		if ( CursorReplacement >= #Replacement ) then -- Cursor beyond end of color
			Cursor = Cursor + #COLOR_END;
		end
		
		self:SetCursorPosition( Cursor );
		-- Highlight selection and wrapper
		self:HighlightText( Start, #ColorCode + ( #Replacement - #Selection ) + #COLOR_END + End );
	end

------------------------------------------------------------------------------------------

	local startX = 6

	local label_colors = Notepad:CreateLabel (colors_panel, L["S_COLOR"] .. ":", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	local on_color_selection = function (self, fixed_value, color_name)
		local DF = _G ["DetailsFramework"]
		local color_table = DF.alias_text_colors [color_name]
		if (color_table) then

			local startpos, endpos = GetTextHighlight ( mainFrame.editboxNotes.editbox )
		
			local color = "|cFF" .. get_color_hash (color_table)
			local endcolor = "|r"
			
			if (startpos == endpos) then
				--> no selection
				--ColorSelection ( mainFrame.editboxNotes.editbox, color )
				mainFrame.editboxNotes.editbox:Insert (color .. endcolor)
				mainFrame.editboxNotes.editbox:SetCursorPosition (startpos + 10)
			else
				--> has selection
				ColorSelection ( mainFrame.editboxNotes.editbox, color )
				
			end
		end
	end
	
	local build_color_list = function()
		if (not color_pool) then
			color_pool = {}
			local DF = _G ["DetailsFramework"]
			for color_name, color_table in pairs (DF.alias_text_colors) do
				color_pool [#color_pool+1] = {color_name, color_table}
			end
			table.sort (color_pool, function (t1, t2)
				return t1[1] < t2[1]
			end)
			tinsert (color_pool, 1, {"Default Color", {1, 1, 1}})
		end
	
		local t = {}
		for index, color_table in ipairs (color_pool) do
			local color_name, color = unpack (color_table)
			t [#t+1] = {label = "|cFF" .. get_color_hash (color) .. color_name .. "|r", value = color_name, onclick = on_color_selection}
		end
		return t
	end

	local dropdownColors = Notepad:CreateDropDown (colors_panel, build_color_list, 1, 186, 20, "dropdownColors", _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
	label_colors:SetPoint ("topleft", editboxNotes, "topright", startX, 16)
	dropdownColors:SetPoint ("topleft", label_colors, "bottomleft", 0, -3)

	local index = 1
	local colors = {"white", "silver", "gray", "HUNTER", "WARLOCK", "PALADIN", "MAGE", "ROGUE", "DRUID", "SHAMAN", "WARRIOR", "DEATHKNIGHT", "MONK", --14
	"darkseagreen", "green", "lime", "yellow", "gold", "orange", "orangered", "red", "magenta", "pink", "deeppink", "violet", "mistyrose"} --4
	for o = 1, 2 do
		for i = 1, 11 do
			local color_button =  Notepad:CreateButton (colors_panel, on_color_selection, 16, 16, "", colors [index], _, _, "button_color" .. index, _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
			color_button:SetPoint ("topleft", editboxNotes, "topright", startX + ((i-1)*17), -10 + (o*17*-1))
			local color_texture = color_button:CreateTexture (nil, "background")
			color_texture:SetColorTexture(Notepad:ParseColors(colors[index]))
			color_texture:SetAlpha (0.7)
			color_texture:SetAllPoints()
			index = index + 1
		end
	end
	
	--> ~colors
		local current_color = Notepad:CreateLabel (colors_panel, "A", 14, "white", nil, "current_font")
		current_color:SetPoint ("bottomright", dropdownColors, "topright")
		local do_text_format = function (self, elapsed)
		
			--> color
			local pos = mainFrame.editboxNotes.editbox:GetCursorPosition()
			local text = mainFrame.editboxNotes.editbox:GetText()

			local cutoff = text:sub (-text:len(), -(text:len() - pos))
			if (cutoff) then
				local i = 0
				local find_color
				local find_end
				while (find_color == nil and find_end == nil and i > -cutoff:len()) do
					i = i - 1
					find_color = cutoff:find ("|cFF", i)
					find_end = cutoff:find ("|r", i)
				end
				
				if (find_end or not find_color) then
					current_color:SetText ("|cFFFFFFFFA|r")
				else
					local color = cutoff:match(".*cFF(.*)")
					if (color) then
						color = color:match("%x%x%x%x%x%x")
						if (color) then
							current_color:SetText("|cFF" .. color .. "A|r")
						end
					else
						current_color:SetText ("|cFFFFFFFFA|r")
					end
				end
			else
				current_color:SetText ("|cFFFFFFFFA|r")
			end
		end

	--> raid targets
		local labelRaidTargets = Notepad:CreateLabel (colors_panel, L["S_TARGETS"] .. ":", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		labelRaidTargets:SetPoint ("topleft", editboxNotes, "topright", startX, -70)
		local icon_path = [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_ICONINDEX:0|t]]

		local on_raidtarget_selection = function (self, button, iconIndex)
			local cursorPos = mainFrame.editboxNotes.editbox:GetCursorPosition()
			local icon = icon_path:gsub([[ICONINDEX]], iconIndex)
			mainFrame.editboxNotes.editbox:Insert(icon .. " ")
			mainFrame.editboxNotes.editbox:SetFocus(true)
			mainFrame.editboxNotes.editbox:SetCursorPosition(cursorPos + 2)
		end

		local index = 1
		for o = 1, 1 do
			for i = 1, 8 do
				local raidtarget =  Notepad:CreateButton (colors_panel, on_raidtarget_selection, 22, 22, "", index, _, _, "button_raidtarget" .. index, _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
				raidtarget:SetPoint ("topleft", editboxNotes, "topright", startX + ((i-1)*24), -61 + (o*23*-1))
				local color_texture = raidtarget:CreateTexture (nil, "overlay")
				color_texture:SetTexture ("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_" .. index)
				color_texture:SetAlpha(0.8)
				color_texture:SetPoint("center", 0, 0)
				color_texture:SetSize(20, 20)
				index = index + 1
			end
		end

	--> ~cooldowns
		local cooldownAbilitiesX = 6
		local cooldownAbilitiesY = -108
		local iconWidth = 24

		local labelIconcooldowns = Notepad:CreateLabel (colors_panel, L["S_COOLDOWNS"] .. ":", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		labelIconcooldowns:SetPoint("topleft", editboxNotes, "topright", cooldownAbilitiesX, -117)

		local cooldown_icon_path = [[|TICONPATH:12:12:0:0:64:64:5:59:5:59|t]]
		local onSpellcooldownSelection = function (self, button, spellId)
			local spellName, _, spellIcon = GetSpellInfo(spellId)
			local text = mainFrame.editboxNotes.editbox:GetText()
			local cursorPos = mainFrame.editboxNotes.editbox:GetCursorPosition()

			if (Notepad.IsInsideMacro(cursorPos, text)) then
				mainFrame.editboxNotes.editbox:Insert(spellId)
				mainFrame.editboxNotes.editbox:SetFocus(true)
				mainFrame.editboxNotes.editbox:SetCursorPosition(cursorPos + #tostring(spellId))

			else
				local  textToInsert = cooldown_icon_path:gsub([[ICONPATH]], spellIcon) .. " " .. " (  ) " --not showing the spellName
				mainFrame.editboxNotes.editbox:Insert(textToInsert)
				mainFrame.editboxNotes.editbox:SetFocus(true)
				mainFrame.editboxNotes.editbox:SetCursorPosition(cursorPos + #textToInsert - 3)
			end
		end

		local i, o = 1, 1
		local spellAdded = {} --can be repeated

		local on_enter_cooldown = function (self)
			local button = self.MyObject
			GameTooltip:SetOwner (self, "ANCHOR_RIGHT")
			GameTooltip:SetSpellByID (button.spellid)
			GameTooltip:Show()
		end

		local on_leave_cooldown = function (self)
			GameTooltip:Hide()
		end

		local cooldownList = {}
		for spellId, cooldownTable in pairs(LIB_OPEN_RAID_COOLDOWNS_INFO) do
			cooldownList[#cooldownList+1] = {spellId, cooldownTable.type, cooldownTable.class, cooldownTable}
		end

		table.sort(cooldownList, function(t1, t2) return t1[3] > t2[3] end)
		--table.sort(cooldownList, function(t1, t2) return t1[2] > t2[2] end)

		tinsert(cooldownList, {6262, 3, "PRIEST", {type = 3}})
		tinsert(cooldownList, {307192, 3, "PRIEST", {type = 3}})

		for index, sortedCooldownTable in pairs(cooldownList) do
			local cooldownTable = sortedCooldownTable[4]
			local spellId = sortedCooldownTable[1]

			if (cooldownTable.type == 3 or cooldownTable.type == 4) then
				if (not spellAdded [spellId]) then
					local spellName, _, spellIcon = GetSpellInfo(spellId)
					local spellButton = Notepad:CreateButton(colors_panel, onSpellcooldownSelection, iconWidth, iconWidth, "", spellId, _, _, "button_cooldown" .. index)
					spellButton.spellid = spellId
					spellButton:SetPoint("topleft", editboxNotes, "topright", cooldownAbilitiesX + ((i-1)*(iconWidth-1)), cooldownAbilitiesY + (o*(iconWidth+1)*-1))
					spellButton:SetHook("OnEnter", on_enter_cooldown)
					spellButton:SetHook("OnLeave", on_leave_cooldown)

					local spellTexture = spellButton:CreateTexture (nil, "background")
					spellTexture:SetTexture(spellIcon)
					spellTexture:SetTexCoord(5/65, 59/64, 5/65, 59/64)
					spellTexture:SetAlpha(0.85)
					spellTexture:SetAllPoints()

					index = index + 1
					i = i +1
					if (i == 9) then
						i = 1
						o = o + 1
					end
					spellAdded [spellId] = true
				end
			end
		end

	--> ~bossspells ~enemyspells ~spells
		local bossAbilitiesY = -258
		local bossAbilitiesX = 6
		local iconWidth = 26

		local label_iconbossspells = Notepad:CreateLabel(colors_panel, L["S_BOSS_ABILITIES"] .. ":", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
		label_iconbossspells:SetPoint("topleft", editboxNotes, "topright", bossAbilitiesX, bossAbilitiesY - 12)

		local bossspell_icon_path = [[|TICONPATH:0|t]]
		local bossspell_icon_path_noformat = [[||TICONPATH:0||t]]
		local on_bossspell_selection = function (self, button)
			local cursorPos = mainFrame.editboxNotes.editbox:GetCursorPosition()
			local spellId = self.MyObject.spellid
			local spellName, _, spellIcon = GetSpellInfo(spellId)

			--need to detect if the insert is inside a macro
			local text = mainFrame.editboxNotes.editbox:GetText()

			if (Notepad.IsInsideMacro(cursorPos, text)) then
				local textAdded = "enemyspell=" .. spellId
				mainFrame.editboxNotes.editbox:Insert(textAdded)
				mainFrame.editboxNotes.editbox:SetFocus(true)
				mainFrame.editboxNotes.editbox:SetCursorPosition(cursorPos + #textAdded)
			else
				if (Notepad.db.auto_format) then
					local textToInsert = bossspell_icon_path:gsub([[ICONPATH]], spellIcon) .. " " .. spellName .. " "
					mainFrame.editboxNotes.editbox:Insert(textToInsert)
					mainFrame.editboxNotes.editbox:SetFocus(true)
					mainFrame.editboxNotes.editbox:SetCursorPosition(cursorPos + #textToInsert)

				else
					local textToInsert = bossspell_icon_path_noformat:gsub([[ICONPATH]], spellIcon) .. " " .. spellName .. " "
					mainFrame.editboxNotes.editbox:Insert(textToInsert)
					mainFrame.editboxNotes.editbox:SetFocus(true)
					mainFrame.editboxNotes.editbox:SetCursorPosition(cursorPos + #textToInsert)
				end
			end
		end

		local on_enter_bossspell = function (self)
			local button = self.MyObject
			button.spellTexture:SetBlendMode("ADD")
			GameTooltip:SetOwner (self, "ANCHOR_RIGHT")
			GameTooltip:SetSpellByID (button.spellid)
			GameTooltip:Show()
		end

		local on_leave_bossspell = function (self)
			GameTooltip:Hide()
			local button = self.MyObject
			button.spellTexture:SetBlendMode("BLEND")
		end

		local bossAbilitiesButtons = {}
		function Notepad:UpdateBossAbilities()
			for buttonid, button in ipairs (bossAbilitiesButtons) do
				button:Hide()
			end
			local bossId, noteId = Notepad:GetCurrentEditingBossId()
			local raidInfo = Notepad:GetBossInfo(bossId)

			if (raidInfo) then
				local instanceId = raidInfo.instanceId

				if (bossId) then
					local spells = DetailsFramework:GetSpellsForEncounterFromJournal(instanceId, bossId)

					if (spells) then

						local spellList = {}
						for i = 1, #spells do
							local spellName, _, spellIcon = GetSpellInfo(spells[i])
							spellList[#spellList+1] = {spellName, spells[i], spellIcon}
						end

						table.sort(spellList, function(t1, t2)
							return t1[1] < t2[1]
						end)

						local buttonIndex = 1
						local i, o = 1, 1
						local alreadyAdded = {}

						for index, spellTable in ipairs(spellList) do

							local spellname, spellid, spellicon = spellTable[1], spellTable[2], spellTable[3]
							if (spellname and not alreadyAdded [spellname]) then
								alreadyAdded[spellname] = true

								local button = bossAbilitiesButtons[buttonIndex]
								if (not button) then
									button = Notepad:CreateButton(colors_panel, on_bossspell_selection, iconWidth, iconWidth, "", spellid, _, _, "button_bossspell" .. buttonIndex)
									button.spellTexture = button:CreateTexture(nil, "artwork")
									bossAbilitiesButtons[buttonIndex] = button
									button:SetHook("OnEnter", on_enter_bossspell)
									button:SetHook("OnLeave", on_leave_bossspell)
									button:SetPoint("topleft", editboxNotes, "topright", bossAbilitiesX + ((i-1)*(iconWidth+1)), bossAbilitiesY + (o*(iconWidth+1)*-1))
								end

								button.spellid = spellid

								button.spellTexture:SetTexture(spellicon)
								button.spellTexture:SetTexCoord(5/65, 59/64, 5/65, 59/64)
								button.spellTexture:SetAlpha(0.85)
								button.spellTexture:SetAllPoints()

								button:Show()

								buttonIndex = buttonIndex + 1
								i = i + 1
								if (i == 8) then
									i = 1
									o = o + 1
								end
							end
						end
					end
				end
			end
		end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	local formatTextCheckboxFunc = function(self, fixedparam, value)
		Notepad.db.auto_format = value
		Notepad.FormatText()
	end

	local checkbox = Notepad:CreateSwitch (colors_panel, formatTextCheckboxFunc, Notepad.db.auto_format, _, _, _, _, _, "NotepadFormatCheckBox", _, _, _, _, Notepad:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	checkbox:SetAsCheckBox()
	--checkbox.tooltip = L["S_PLUGIN_NOTE_AUTOFORMAT"]
	checkbox:SetPoint ("bottomleft", editboxNotes, "topleft", 0, 2)
	checkbox:SetValue (Notepad.db.auto_format)

	local labelAutoformat = Notepad:CreateLabel (colors_panel, L["S_PLUGIN_NOTE_AUTOFORMAT"], Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	labelAutoformat:SetPoint ("left", checkbox, "right", 2, 0)

	local autoCompleteCheckBoxFunc = function(self, fixedparam, value)
		Notepad.db.auto_complete = value
	end

	local checkbox2 = Notepad:CreateSwitch (colors_panel, autoCompleteCheckBoxFunc, Notepad.db.auto_complete, _, _, _, _, _, "NotepadAutoCompleteCheckBox", _, _, _, _, Notepad:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	checkbox2:SetAsCheckBox()
	checkbox2.tooltip = L["S_PLUGIN_NOTE_AUTONAMES"]
	checkbox2:SetPoint ("bottomleft", editboxNotes, "topleft", 250, 2)
	checkbox2:SetValue (Notepad.db.auto_complete)

	local labelAutocomplete = Notepad:CreateLabel (colors_panel, L["S_PLUGIN_NOTE_AUTONAMES_DESC"], Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	labelAutocomplete:SetPoint ("left", checkbox2, "right", 2, 0)

	local brightnessSlider, brightnessText = Notepad:CreateSlider(colors_panel, 120, 18, 0, 1, 0.05, Notepad.db.editor_alpha, true, _, "NotepadBrightnessAdjustment", L["S_BRIGHTNESS"], Notepad:GetTemplate ("slider", "OPTIONS_SLIDER_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	brightnessSlider:ClearAllPoints()
	brightnessSlider:SetPoint("bottomright", editboxNotes, "topright", 0, 2)
	brightnessText:SetPoint("right", brightnessSlider, "left", -2, 0)

	brightnessSlider.OnValueChanged = function (_, _, value)
		--adjust the editor brightness
		Notepad.db.editor_alpha = value
		local r, g, b = unpack(CONST_EDITBOX_COLOR)
		local editBox = Notepad.GetEditBox()
		editBox.backgroundTexture1:SetColorTexture(r, g, b, value)
		editBox.backgroundTexture2:SetColorTexture(r, g, b, value)
	end

	brightnessSlider.thumb:SetWidth(24)

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	editboxNotes:SetScript("OnShow", function()
		colors_panel:SetScript("OnUpdate", do_text_format)
		editboxNotes:SetScript("OnUpdate", Notepad.OnUpdate)
		Notepad:UpdateBossAbilities()
		mainFrame.buttonClear:Show()
		mainFrame.buttonSave:Show()
		mainFrame.buttonSave2:Show()
		mainFrame.buttonCancel:Show()
	end)
	editboxNotes:SetScript("OnHide", function()
		colors_panel:SetScript("OnUpdate", nil)
		editboxNotes:SetScript("OnUpdate", nil)
		mainFrame.buttonClear:Hide()
		mainFrame.buttonSave:Hide()
		mainFrame.buttonSave2:Hide()
		mainFrame.buttonCancel:Hide()
	end)
	
	Notepad.currentWord = ""
	local characters_count = "", 0

	local get_last_word = function()
		Notepad.currentWord = ""
		local cursor_pos = mainFrame.editboxNotes.editbox:GetCursorPosition()
		local text = mainFrame.editboxNotes.editbox:GetText()
		for i = cursor_pos, 1, -1 do
			local character = text:sub (i, i)
			if (character:match ("%a")) then
				Notepad.currentWord = character .. Notepad.currentWord
			else
				break
			end
		end
	end

	local getLatestWord = function()
		local cursorPos = mainFrame.editboxNotes.editbox:GetCursorPosition()
		local text = mainFrame.editboxNotes.editbox:GetText()

		local latestWord = ""

		for o = cursorPos-1, 1, -1 do
			local character = text:sub(o, o)
			if (character:match("%a")) then
				latestWord = character .. latestWord
			else
				return latestWord
			end
		end
	end
	
	editboxNotes.editbox:SetScript ("OnTextChanged", function (self)
		if (not Notepad.ignore_text_changed) then
			local chars_now = mainFrame.editboxNotes.editbox:GetText():len()
			--> backspace
			if (chars_now == characters_count -1) then
				Notepad.currentWord = Notepad.currentWord:sub (1, Notepad.currentWord:len()-1)
			--> delete lots of text
			elseif (chars_now < characters_count) then
				mainFrame.editboxNotes.editbox.end_selection = nil
				get_last_word()
			end
			characters_count = chars_now
		end
	end)
	
	editboxNotes.editbox:SetScript ("OnSpacePressed", function (self)
		mainFrame.editboxNotes.editbox.end_selection = nil
	end)
	editboxNotes.editbox:HookScript ("OnEscapePressed", function (self) 
		mainFrame.editboxNotes.editbox.end_selection = nil
	end)
	
	--
	local save_feedback_texture = mainFrame.buttonSave2:CreateTexture (nil, "overlay")
	save_feedback_texture:SetColorTexture (1, 1, 1)
	save_feedback_texture:SetAllPoints()
	save_feedback_texture:SetDrawLayer ("overlay", 7)
	save_feedback_texture:SetAlpha (0)
	
	local save_button_flash_animation = DF:CreateAnimationHub (save_feedback_texture)
	DF:CreateAnimation (save_button_flash_animation, "alpha", 1, 0.08, 0, 0.2)
	DF:CreateAnimation (save_button_flash_animation, "alpha", 2, 0.08, 0.4, 0)
	
	local save_button_feedback_animation = DF:CreateAnimationHub (mainFrame.buttonSave2, function() save_button_flash_animation:Play() end)
	local speed = 0.06
	local rotation = 0
	local translation = 7
	
	--DF:CreateAnimation (save_button_feedback_animation, "scale", 1, speed, 1, 1, 1.01, 1.01)
	DF:CreateAnimation (save_button_feedback_animation, "translation", 1, speed, 0, -translation)
	DF:CreateAnimation (save_button_feedback_animation, "rotation", 1, speed, -rotation)
	
	--DF:CreateAnimation (save_button_feedback_animation, "scale", 1, speed, 1.01, 1.01, 1, 1)
	DF:CreateAnimation (save_button_feedback_animation, "translation", 2, speed, 0, translation)
	DF:CreateAnimation (save_button_feedback_animation, "rotation", 2, speed, rotation)
	
	DF:CreateAnimation (save_button_feedback_animation, "rotation", 3, speed, rotation)
	DF:CreateAnimation (save_button_feedback_animation, "rotation", 4, speed, -rotation)
	--

	editboxNotes.editbox:SetScript("OnEnterPressed", function (self)
		--if shift is pressed when the user pressed enter, save/apply the script and don't lose the focus of the editor
		if (IsShiftKeyDown()) then
			local cursorPosition = editboxNotes.editbox:GetCursorPosition()
			mainFrame.buttonSave2()
			editboxNotes.editbox:SetFocus(true)
			C_Timer.After(0.1, function()
				editboxNotes.editbox:SetCursorPosition(cursorPosition)
			end)
			save_button_feedback_animation:Play()
			return
		end

		if (mainFrame.editboxNotes.editbox.end_selection) then
			mainFrame.editboxNotes.editbox:SetCursorPosition(mainFrame.editboxNotes.editbox.end_selection)
			mainFrame.editboxNotes.editbox:HighlightText(0, 0)
			mainFrame.editboxNotes.editbox:Insert(" ")
			mainFrame.editboxNotes.editbox.end_selection = nil
		else
			mainFrame.editboxNotes.editbox:Insert("\n")
		end

		Notepad.currentWord = ""
	end)

	editboxNotes.editbox:SetScript("OnEditFocusGained", function (self)
		Notepad.GetBossScrollFrame():Minimize()
		get_last_word()
		mainFrame.editboxNotes.editbox.end_selection = nil
		characters_count = mainFrame.editboxNotes.editbox:GetText():len()
	end)

	local playersCache = {
		["cooldown = "] = "PRIEST",
		["phase = "] = "PRIEST",
		["enemyspell = "] = "PRIEST",
		["Dispell"] = "PRIEST",
		["Interrupt"] = "PRIEST",
		["Adds"] = "PRIEST",
		["TANKS"] = "PRIEST",
		["DAMAGERS"] = "PRIEST",
		["HEALERS"] = "PRIEST",
		["Transition"] = "PRIEST",
	}

	local interval, guildInterval, updateGuildPlayers = -1, -1, false
	Notepad.playersCache = playersCache

	editboxNotes.editbox:SetScript("OnChar", function (self, char) 

		if (Notepad.ignore_text_changed) then
			return
		end

		mainFrame.editboxNotes.editbox.end_selection = nil

		if (mainFrame.editboxNotes.editbox.ignore_input) then
			return
		end

		local wordFinished = false
		if (char:match("%a") or char:match("%p")) then
			if (char == "," or char == "." or char == ";") then
				wordFinished = true
			else
				if (char ~= "[" and char ~= "]") then
					Notepad.currentWord = Notepad.currentWord .. char
				end
			end
		else
			if (char == "") then

			elseif (char:match("%s")) then
				Notepad.currentWord = ""
				wordFinished = true

			elseif (char:match("%c")) then
				Notepad.currentWord = ""
				wordFinished = true

			elseif (char == "\n") then
				Notepad.currentWord = ""
				wordFinished = true
			end
		end

		if (wordFinished) then
			local latestWord = getLatestWord()
			if (latestWord and type(latestWord) == "string" and latestWord:len() >= 2) then
				local latestWordAstyped = latestWord
				latestWord = string.gsub(" " .. latestWord, "%W%l", string.upper):sub(2)
				local playerClass = Notepad.playersCache[latestWord]

				if (playerClass) then
					local cursorPosition = editboxNotes.editbox:GetCursorPosition()
					local unitClassColor = "|c" .. RAID_CLASS_COLORS[playerClass].colorStr

					editboxNotes.editbox:HighlightText(cursorPosition - latestWord:len() - 1, cursorPosition-1)
					editboxNotes.editbox:Insert(latestWord)

					editboxNotes.editbox:HighlightText(cursorPosition - latestWord:len() - 1, cursorPosition-1)
					ColorSelection(editboxNotes.editbox, unitClassColor)
					editboxNotes.editbox:HighlightText(0, 0)
					editboxNotes.editbox:SetCursorPosition(cursorPosition + unitClassColor:len() + 2)
				end
			end
		end

		mainFrame.editboxNotes.editbox.ignore_input = true

		if (Notepad.currentWord:len() >= 2 and Notepad.db.auto_complete) then
			for playerName, class in pairs(playersCache) do
				if (playerName and (playerName:find ("^" .. Notepad.currentWord) or playerName:lower():find ("^" .. Notepad.currentWord))) then
					local rest = playerName:gsub (Notepad.currentWord, "")
					rest = rest:lower():gsub (Notepad.currentWord, "")
					local cursor_pos = self:GetCursorPosition()
					mainFrame.editboxNotes.editbox:Insert(rest)
					mainFrame.editboxNotes.editbox:HighlightText(cursor_pos, cursor_pos + rest:len())
					mainFrame.editboxNotes.editbox:SetCursorPosition(cursor_pos)
					mainFrame.editboxNotes.editbox.end_selection = cursor_pos + rest:len()
					break
				end
			end
		end

		mainFrame.editboxNotes.editbox.ignore_input = false
	end)

	function Notepad.OnUpdate(self, deltaTime)

		interval = interval - deltaTime
		guildInterval = guildInterval - deltaTime

		if (interval > 0) then
			return
		else
			interval = 0.5
		end

		if (guildInterval < 0) then
			C_GuildInfo.GuildRoster()
			guildInterval = 11
			interval = 1
			updateGuildPlayers = true

			--update raid status
			local openRaidLib = LibStub:GetLibrary("LibOpenRaid-1.0")
			openRaidLib.RequestAllPlayersInfo()
			return
		end

		if (IsInGroup()) then
			for i = 1, GetNumGroupMembers() do
				local name, rank, subgroup, level, class, fileName, zone, online, isDead, role = GetRaidRosterInfo(i)
				if (name) then
					name = Ambiguate(name, "none")
					playersCache[name] = fileName
				end
			end

			playersCache[UnitName("player")] = select(2, UnitClass("player"))
		end

		if (IsInGuild() and updateGuildPlayers) then
			local numTotalGuildMembers, numOnlineGuildMembers, numOnlineAndMobileMembers = GetNumGuildMembers()
			local showOfflineUsers = GetGuildRosterShowOffline()
			SetGuildRosterShowOffline(true)

			for i = 1, numTotalGuildMembers do
				local name, rankName, rankIndex, level, classDisplayName, zone, _, _, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSoR, repStanding, GUID = GetGuildRosterInfo(i)
				name = Ambiguate(name, "none")
				playersCache[name] = class
			end

			SetGuildRosterShowOffline(showOfflineUsers)
		end
	end
end

function Notepad.FormatText(mytext)
	local text = mytext
	if (not text) then
		text = Notepad.mainFrame.editboxNotes.editbox:GetText()
	end

	if (Notepad.db.auto_format or mytext) then
		-- format the text, show icons
		text = text:gsub("{Star}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_1:0|t]])
		text = text:gsub("{Circle}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_2:0|t]])
		text = text:gsub("{Diamond}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_3:0|t]])
		text = text:gsub("{Triangle}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_4:0|t]])
		text = text:gsub("{Moon}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_5:0|t]])
		text = text:gsub("{Square}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_6:0|t]])
		text = text:gsub("{Cross}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_7:0|t]])
		text = text:gsub("{Skull}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_8:0|t]])
		text = text:gsub("{rt1}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_1:0|t]])
		text = text:gsub("{rt2}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_2:0|t]])
		text = text:gsub("{rt3}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_3:0|t]])
		text = text:gsub("{rt4}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_4:0|t]])
		text = text:gsub("{rt5}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_5:0|t]])
		text = text:gsub("{rt6}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_6:0|t]])
		text = text:gsub("{rt7}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_7:0|t]])
		text = text:gsub("{rt8}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_8:0|t]])

		text = text:gsub("||c", "|c")
		text = text:gsub("||r", "|r")
		text = text:gsub("||t", "|t")
		text = text:gsub("||T", "|T")

	else
		--show plain text, replace the raid target icons:
		text = text:gsub([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_1:0|t]], "{Star}")
		text = text:gsub([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_2:0|t]], "{Circle}")
		text = text:gsub([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_3:0|t]], "{Diamond}")
		text = text:gsub([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_4:0|t]], "{Triangle}")
		text = text:gsub([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_5:0|t]], "{Moon}")
		text = text:gsub([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_6:0|t]], "{Square}")
		text = text:gsub([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_7:0|t]], "{Cross}")
		text = text:gsub([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_8:0|t]], "{Skull}")

		--escape sequences
		text = text:gsub("|c", "||c")
		text = text:gsub("|r", "||r")
		text = text:gsub("|t", "||t")
		text = text:gsub("|T", "||T")
	end

	--> passed a text, so just return a formated text
		if (mytext) then
			return text
		else
			Notepad.mainFrame.editboxNotes.editbox:SetText(text)
		end
end

RA:InstallPlugin(Notepad.displayName, "OPNotepad", Notepad, default_config)

--> when the user enters in the raid instance or after /reload or logon
local doAskForEnbaledNote = function()
	local raidLeader = Notepad:GetRaidLeader()
	if (raidLeader) then
		Notepad:SendPluginCommWhisperMessage(COMM_QUERY_SEED, raidLeader, nil, nil, Notepad:GetPlayerNameWithRealm())
	end
end

function Notepad:AskForEnabledNote()
	if (IsInRaid() or IsInGroup()) then
		--make it safe calling with a delay in case many users enter/connect at the same time
		C_Timer.After (math.random(3), doAskForEnbaledNote)
	end
end

--received a comm from another player in the raid, need to treat it
function Notepad.OnReceiveComm(sourceName, prefix, sourcePluginVersion, sourceUnit, fullNote, bossId, noteId)
	sourceUnit = sourceName
	sourceUnit = Ambiguate(sourceUnit, "none")

	local ZoneName, InstanceType, DifficultyID = GetInstanceInfo()
	if (DifficultyID and DifficultyID == 17) then
		return
	end

	--> Full Note - the user received a note from the Raid Leader
		if (prefix == COMM_RECEIVED_FULLNOTE) then
			--check if the sender is the raid leader

			if ((not IsInRaid() and not IsInGroup()) or not isRaidLeader(sourceUnit)) then
				return
			end

			--validade the note
			if (not fullNote) then
				--> hide any note shown in the screen (currently_shown stores the bossId)
				local currentBossShown = Notepad:GetCurrentlyShownBoss()
				if (currentBossShown) then
					Notepad.UnshowNoteOnScreen()
				end
				return
			end

			--has a valid bossId?
			if (not bossId or type(bossId) ~= "number") then
				return
			end
			--has a valid noteId?
			if (not noteId or type(noteId) ~= "number") then
				return
			end

			--save the note
			local thisNote, noteId = Notepad:SaveNoteFromComm(fullNote, bossId)
			--show the note
			Notepad:ShowNoteOnScreen(bossId, noteId)

			--if options window is opened, update the scroll frame and the editor
			if (Notepad.mainFrame and Notepad.mainFrame:IsShown()) then
				Notepad:SetCurrentEditingBossId(bossId, noteId)
			end

	--> Requested Note - the user requested the note to the raid leader
		elseif (prefix == COMM_QUERY_NOTE or prefix == COMM_QUERY_SEED) then --"NOQN" "NOQI"
			--check if I'm the raid leader
			if ((not IsInRaid() and not IsInGroup()) or not isRaidLeader ("player")) then
				return
			end

			if (isConnected(sourceUnit)) then
				local currentBoss, _, noteId = Notepad:GetCurrentlyShownBoss()
				if (currentBoss) then
					local note = Notepad:GetNote(currentBoss, noteId)
					Notepad:SendPluginCommWhisperMessage(COMM_RECEIVED_FULLNOTE, sourceUnit, nil, nil, Notepad:GetPlayerNameWithRealm(), note, currentBoss, noteId)
				else
					--no note is shown, just send an empty FULLNOTE
					Notepad:SendPluginCommWhisperMessage(COMM_RECEIVED_FULLNOTE, sourceUnit, nil, nil, Notepad:GetPlayerNameWithRealm())
				end
			end
		end
end

--> send and receive notes:
	-- Full Note - the raid leader sent a note to be shown on the screen
	
	RA:RegisterPluginComm (COMM_RECEIVED_FULLNOTE, Notepad.OnReceiveComm)
--> query a Note or ID and Time:
	-- Request Current ID - received by the raid leader, asking about the current note state (id and time)
	RA:RegisterPluginComm (COMM_QUERY_SEED, Notepad.OnReceiveComm)
	-- Received Current ID - raid leader response with the current note id and time
	RA:RegisterPluginComm (COMM_RECEIVED_SEED, Notepad.OnReceiveComm)
	-- Request Note - request a full note with a ID
	RA:RegisterPluginComm (COMM_QUERY_NOTE, Notepad.OnReceiveComm)


--> send a signal to hide the current note shown
function Notepad:SendHideShownNote()
	--is raid leader?
	if (isRaidLeader("player") and (IsInRaid() or IsInGroup())) then
		if (IsInRaid()) then
			Notepad:SendPluginCommMessage(COMM_RECEIVED_FULLNOTE, "RAID", nil, nil, Notepad:GetPlayerNameWithRealm())
		else
			Notepad:SendPluginCommMessage(COMM_RECEIVED_FULLNOTE, "PARTY", nil, nil, Notepad:GetPlayerNameWithRealm())
		end
	end
end

--> send the note for all players in the raid
function Notepad:SendNote(bossId, noteId)
	--is raid leader?
	if (isRaidLeader("player") and (IsInRaid() or IsInGroup())) then
		local ZoneName, InstanceType, DifficultyID, _, _, _, _, ZoneMapID = GetInstanceInfo()
		if (DifficultyID and DifficultyID == 17) then
			--ignore raid finder
			return
		end

		--send the note
		local note = Notepad:GetNote(bossId, noteId)
		if (note) then
			if (IsInRaid()) then
				Notepad:SendPluginCommMessage (COMM_RECEIVED_FULLNOTE, "RAID", nil, nil, Notepad:GetPlayerNameWithRealm(), note, bossId, noteId)
			else
				Notepad:SendPluginCommMessage (COMM_RECEIVED_FULLNOTE, "PARTY", nil, nil, Notepad:GetPlayerNameWithRealm(), note, bossId, noteId)
			end
		end
	end
end