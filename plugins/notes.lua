

local RA = _G.RaidAssist
local L = _G.LibStub ("AceLocale-3.0"):GetLocale ("RaidAssistAddon")
local _
local default_priority = 120
local DF = DetailsFramework

if (_G ["RaidAssistNotepad"]) then
	return
end
local Notepad = {version = 1, pluginname = "Notes"}
_G ["RaidAssistNotepad"] = Notepad

local default_config = {
	notes = {},
	currently_shown = false,
	currently_shown_time = 0,
	text_size = 12,
	text_face = "Friz Quadrata TT",
	text_justify = "left",
	text_shadow = false,
	framestrata = "LOW",
	locked = false,
	background = {r=0, g=0, b=0, a=0.3, show = true},
	hide_on_combat = false,
	auto_format = true,
	auto_complete = true,
	editing_boss_id = 0,
	boss_notes = {}
}

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

local isRaidLeader = function (sourceUnit)
	if (type (sourceUnit) == "string") then
		return UnitIsGroupLeader(sourceUnit) or UnitIsGroupLeader(sourceUnit:gsub ("%-.*", "")) or Notepad:UnitHasAssist(sourceUnit) or Notepad:UnitHasAssist(sourceUnit:gsub ("%-.*", ""))
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
		local bossId, shownAt = Notepad:GetCurrentlyShownBoss()
		if (bossId and shownAt) then
			if (shownAt+60 > time()) then
				Notepad:ShowNoteOnScreen(bossId)
			else
				Notepad:UnshowNoteOnScreen()
			end
		end
	end)
end

Notepad.OnInstall = function (plugin)
	Notepad.db.menu_priority = default_priority

	--frame shown in the screen
	local screenFrame = RA:CreateCleanFrame(Notepad, "NotepadScreenFrame")
	Notepad.screenFrame = screenFrame
	screenFrame:SetSize(250, 20)
	screenFrame:SetClampedToScreen(true)
	screenFrame:Hide()

	local title_text = screenFrame:CreateFontString (nil, "overlay", "GameFontNormal")
	title_text:SetText ("Raid Assist")
	title_text:SetTextColor (.8, .8, .8, 1)
	title_text:SetPoint ("center", screenFrame, "center")
	screenFrame.title_text = title_text

	-- editbox (screen frame)
	local editboxNotes = Notepad:NewSpecialLuaEditorEntry(screenFrame, 250, 200, "editboxNotes", "RaidAssignmentsNoteEditboxScreen", true)
	editboxNotes:SetPoint ("topleft", screenFrame, "bottomleft", 0, 0)
	editboxNotes:SetPoint ("topright", screenFrame, "bottomright", 0, 0)
	editboxNotes:SetBackdrop (nil)
	editboxNotes:SetFrameLevel (screenFrame:GetFrameLevel()+1)
	editboxNotes:SetResizable (true)
	editboxNotes:SetMaxResize (600, 1024)
	editboxNotes:SetMinResize (150, 50)

	screenFrame.text = editboxNotes

	editboxNotes.editbox:SetTextInsets (2, 2, 3, 3)
	editboxNotes.scroll:ClearAllPoints()
	editboxNotes.scroll:SetPoint ("topleft", editboxNotes, "topleft", 0, 0)
	editboxNotes.scroll:SetPoint ("bottomright", editboxNotes, "bottomright", -26, 0)
	local f, h, fl = editboxNotes.editbox:GetFont()
	editboxNotes.editbox:SetFont (f, 12, fl)

	-- background
	local background = editboxNotes:CreateTexture (nil, "background")
	background:SetPoint ("topleft", editboxNotes, "topleft", 0, 0)
	background:SetPoint ("bottomright", editboxNotes, "bottomright", 0, -5)
	screenFrame.background = background

	-- resize button
	local resize_button = CreateFrame ("button", nil, screenFrame, "BackdropTemplate")
	resize_button:SetPoint ("topleft", editboxNotes, "bottomleft")
	resize_button:SetPoint ("topright", editboxNotes, "bottomright")
	resize_button:SetHeight (16)
	resize_button:SetFrameLevel (screenFrame:GetFrameLevel()+5)
	resize_button:SetBackdrop ({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
	resize_button:SetBackdropColor (0, 0, 0, 0.6)
	resize_button:SetBackdropBorderColor (0, 0, 0, 0)
	screenFrame.resize_button = resize_button

	local resize_texture = resize_button:CreateTexture (nil, "overlay")
	resize_texture:SetTexture ([[Interface\CHATFRAME\UI-ChatIM-SizeGrabber-Down]])
	resize_texture:SetPoint ("topleft", resize_button, "topleft", 0, 0)
	resize_texture:SetSize (16, 16)
	resize_texture:SetTexCoord (1, 0, 0, 1)
	screenFrame.resize_texture = resize_texture

	resize_button:SetScript ("OnMouseDown", function()
		editboxNotes:StartSizing ("bottomleft")
	end)
	resize_button:SetScript ("OnMouseUp", function()
		editboxNotes:StopMovingOrSizing()
		screenFrame:SetWidth (editboxNotes:GetWidth())
		editboxNotes:SetPoint ("topleft", screenFrame, "bottomleft", 0, 0)
		editboxNotes:SetPoint ("topright", screenFrame, "bottomright", 0, 0)
	end)

	resize_button:SetScript ("OnSizeChanged", function()
		screenFrame:SetWidth (editboxNotes:GetWidth())
		editboxNotes:SetPoint ("topleft", screenFrame, "bottomleft", 0, 0)
		editboxNotes:SetPoint ("topright", screenFrame, "bottomright", 0, 0)
		Notepad.updateScrollBar()
	end)

	local RaidAssignmentsNoteEditboxScreenScrollBarThumbTexture = _G.RaidAssignmentsNoteEditboxScreenScrollBarThumbTexture
	RaidAssignmentsNoteEditboxScreenScrollBarThumbTexture:SetTexture (0, 0, 0, 0.4)
	RaidAssignmentsNoteEditboxScreenScrollBarThumbTexture:SetSize (14, 17)

	local RaidAssignmentsNoteEditboxScreenScrollBarScrollUpButton = _G.RaidAssignmentsNoteEditboxScreenScrollBarScrollUpButton
	RaidAssignmentsNoteEditboxScreenScrollBarScrollUpButton:SetNormalTexture ([[Interface\Buttons\Arrow-Up-Up]])
	RaidAssignmentsNoteEditboxScreenScrollBarScrollUpButton:SetHighlightTexture ([[Interface\Buttons\Arrow-Up-Up]])
	RaidAssignmentsNoteEditboxScreenScrollBarScrollUpButton:SetPushedTexture ([[Interface\Buttons\Arrow-Up-Down]])
	RaidAssignmentsNoteEditboxScreenScrollBarScrollUpButton:SetDisabledTexture ([[Interface\Buttons\Arrow-Up-Disabled]])

	local RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton = _G.RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton
	RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton:SetNormalTexture ([[Interface\Buttons\Arrow-Down-Up]])
	RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton:SetHighlightTexture ([[Interface\Buttons\Arrow-Down-Up]])
	RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton:SetPushedTexture ([[Interface\Buttons\Arrow-Down-Down]])
	RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton:SetDisabledTexture ([[Interface\Buttons\Arrow-Down-Disabled]])

	RaidAssignmentsNoteEditboxScreenScrollBarScrollUpButton.Normal:SetTexCoord (0, 1, 0, 1)
	RaidAssignmentsNoteEditboxScreenScrollBarScrollUpButton.Disabled:SetTexCoord (0, 1, 0, 1)
	RaidAssignmentsNoteEditboxScreenScrollBarScrollUpButton.Highlight:SetTexCoord (0, 1, 0, 1)
	RaidAssignmentsNoteEditboxScreenScrollBarScrollUpButton.Pushed:SetTexCoord (0, 1, 0, 1)
	RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton.Normal:SetTexCoord (0, 1, 0, 1)
	RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton.Disabled:SetTexCoord (0, 1, 0, 1)
	RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton.Highlight:SetTexCoord (0, 1, 0, 1)
	RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton.Pushed:SetTexCoord (0, 1, 0, 1)

	-------

	local lock = CreateFrame("button", "NotepadScreenFrameLockButton", screenFrame, "BackdropTemplate")
	lock:SetSize(16, 16)
	lock:SetNormalTexture([[Interface\LFGFRAME\UI-LFG-ICON-LOCK]])
	lock:SetHighlightTexture([[Interface\LFGFRAME\UI-LFG-ICON-LOCK]])
	lock:SetPushedTexture([[Interface\LFGFRAME\UI-LFG-ICON-LOCK]])
	lock:GetPushedTexture():SetDesaturated(true)
	lock:GetNormalTexture():SetDesaturated(true)
	lock:GetHighlightTexture():SetDesaturated(true)

	lock:SetAlpha (0.7)
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
	t:SetColorTexture (1, 1, 1, 0.25)
	t:SetAllPoints()
	t:SetBlendMode ("ADD")
	local animation = t:CreateAnimationGroup()
	local anim1 = animation:CreateAnimation ("Alpha")
	local anim2 = animation:CreateAnimation ("Alpha")
	local anim3 = animation:CreateAnimation ("Alpha")
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
		f_anim:Show()
		f_anim:SetParent (block)
		f_anim:SetPoint ("topleft", editboxNotes, "topleft")
		f_anim:SetPoint ("bottomright", editboxNotes, "bottomright")
		animation:Play()

		if (Notepad.PlayerAFKTicker and Notepad.MouseCursorX and Notepad.MouseCursorY) then
			local x, y = GetCursorPosition()
			if (Notepad.MouseCursorX ~= x or Notepad.MouseCursorY ~= y) then
				if (Notepad.PlayerAFKTicker) then
					Notepad.PlayerAFKTicker:Cancel()
					Notepad.PlayerAFKTicker = nil
				end
			end
		end
	end

	Notepad:UpdateScreenFrameSettings()

	Notepad.playerIsInGroup = IsInGroup()

	local _, instanceType = GetInstanceInfo()
	Notepad.current_instanceType = instanceType

	Notepad:RegisterEvent("GROUP_ROSTER_UPDATE")
	Notepad:RegisterEvent("PLAYER_REGEN_DISABLED")
	Notepad:RegisterEvent("PLAYER_REGEN_ENABLED")
	Notepad:RegisterEvent("PLAYER_LOGOUT")

	if (Notepad:GetCurrentlyShownBoss()) then
		Notepad:ValidateNoteCurrentlyShown() --only removes, zone_changed has been removed
	end

	C_Timer.After (10, function()
		local _, instanceType, DifficultyID = GetInstanceInfo()
		if (instanceType == "raid" and Notepad.playerIsInGroup and DifficultyID ~= 17) then
			Notepad:AskForEnabledNote()
		end
	end)
end --end of OnInstall


function Notepad:UpdateScreenFrameBackground()
	local bg = Notepad.db.background
	if (bg.show) then
		Notepad.screenFrame.background:SetColorTexture (bg.r, bg.g, bg.b, bg.a)
		Notepad.screenFrame.background:SetHeight (Notepad.screenFrame.text:GetHeight())
	else
		Notepad.screenFrame.background:SetColorTexture (0, 0, 0, 0)
	end
end

function Notepad:UpdateScreenFrameSettings()
	--font face
	local SharedMedia = LibStub:GetLibrary("LibSharedMedia-3.0")
	local font = SharedMedia:Fetch ("font", Notepad.db.text_font)
	Notepad:SetFontFace (Notepad.screenFrame.text.editbox, font)

	--font size
	Notepad:SetFontSize (Notepad.screenFrame.text.editbox, Notepad.db.text_size)

	-- font shadow
	Notepad:SetFontOutline (Notepad.screenFrame.text.editbox, Notepad.db.text_shadow)

	--frame strata
	Notepad.screenFrame:SetFrameStrata (Notepad.db.framestrata)

	--background show
	Notepad:UpdateScreenFrameBackground()

	--frame locked
	if (Notepad.db.locked) then
		Notepad.screenFrame:EnableMouse (false)
		Notepad.screenFrame.lock:SetAlpha (0.15)
		Notepad.screenFrame.close:SetAlpha (0.15)
		Notepad.screenFrame:SetBackdrop (nil)
		Notepad.screenFrame.resize_button:Hide()
		Notepad.screenFrame.resize_texture:Hide()
		Notepad.screenFrame.title_text:SetTextColor (.8, .8, .8, 0.15)

	else
		Notepad.screenFrame:EnableMouse (true)
		Notepad.screenFrame.lock:SetAlpha (1)
		Notepad.screenFrame.close:SetAlpha (1)
		Notepad.screenFrame:SetBackdrop ({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
		Notepad.screenFrame:SetBackdropColor (0, 0, 0, 0.8)
		Notepad.screenFrame:SetBackdropBorderColor (unpack(RA.BackdropBorderColor))
		Notepad.screenFrame.resize_button:Show()
		Notepad.screenFrame.resize_texture:Show()

		Notepad.screenFrame.title_text:SetTextColor (.8, .8, .8, 1)
	end

	--text justify and lock butotn
	Notepad.screenFrame.text.editbox:SetJustifyH (Notepad.db.text_justify)
	Notepad.screenFrame.text:ClearAllPoints()
	Notepad.screenFrame.lock:ClearAllPoints()
	Notepad.screenFrame.close:ClearAllPoints()

	if (Notepad.db.text_justify == "left") then
		Notepad.screenFrame.lock:SetPoint ("left", Notepad.screenFrame, "left", 4, -2)
		Notepad.screenFrame.close:SetPoint ("left", Notepad.screenFrame.lock, "right", -3, 1)
		Notepad.screenFrame.text:SetPoint ("topleft", Notepad.screenFrame, "bottomleft", 0, 0)

	elseif (Notepad.db.text_justify == "right") then
		Notepad.screenFrame.lock:SetPoint ("right", Notepad.screenFrame, "right", 0, 0)
		Notepad.screenFrame.close:SetPoint ("right", Notepad.screenFrame.lock, "left", 2, 0)
		Notepad.screenFrame.text:SetPoint ("topright", Notepad.screenFrame, "bottomright", -0, 0)
	end

	Notepad.screenFrame.text:EnableMouse (false)
	Notepad.screenFrame.text.editbox:EnableMouse (false)
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

function Notepad:GetNote(bossId)
	local bossNote = Notepad.db.boss_notes[bossId]
	if (not bossNote) then
		bossNote = ""
		Notepad.db.boss_notes[bossId] = bossNote
	end
	return bossNote
end

function Notepad:SaveNote(note, bossId)
	if (not note or not bossId) then
		return
	end
	Notepad.db.boss_notes[bossId] = note
end

function Notepad:GetCurrentlyShownBoss()
	return Notepad.db.currently_shown, Notepad.db.currently_shown_time
end

function Notepad:SetCurrentlyShownBoss(bossId)
	Notepad.db.currently_shown = bossId
	Notepad.db.currently_shown_time = time()
end

function Notepad:SaveCurrentEditingNote()
	local currentBossId = Notepad:GetCurrentEditingBossId()
	if (currentBossId and currentBossId ~= 0) then
		Notepad:SaveNote(Notepad.mainFrame.editboxNotes:GetText(), currentBossId)
	end
end

function Notepad:GetCurrentEditingNote()
	local currentBossId = Notepad:GetCurrentEditingBossId()
	return Notepad:GetNote(currentBossId)
end

function Notepad:GetNoteList()
	return Notepad.db.boss_notes
end

function Notepad:BuildBossList()
	local bossTable = {}
	Notepad.bossListHashTable = {} --carry a list of bosses of the current expansion where the boss index is key
	Notepad.bossListTable = bossTable --carry a indexed list of bosses

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
	return Notepad.db.editing_boss_id
end

function Notepad:SetCurrentEditingBossId(bossId)
	Notepad.db.editing_boss_id = bossId
	local mainFrame = Notepad.mainFrame

	mainFrame.BossSelectionBox:Refresh()

	--open the boss to change the text
	mainFrame.buttonCancel:Enable()
	mainFrame.buttonClear:Enable()
	mainFrame.buttonSave:Enable()
	mainFrame.buttonSave2:Enable()
	mainFrame.editboxNotes:Enable()
	mainFrame.editboxNotes:SetFocus()

	local note = Notepad:GetNote(bossId)
	mainFrame.editboxNotes:SetText(note)
	Notepad:FormatText()

	mainFrame.editboxNotes:Show()
	mainFrame.userScreenPanelOptions:Hide()

	--is empty?
	if (#note == 0) then
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

local updateScrollBar = function()
	if (RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton:IsEnabled()) then
		RaidAssignmentsNoteEditboxScreenScrollBar:Show()
	else
		RaidAssignmentsNoteEditboxScreenScrollBar:Hide()
	end
	RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton:SetScript ("OnUpdate", nil)
end
Notepad.updateScrollBar = updateScrollBar

local track_mouse_position = function()
	local x, y = GetCursorPosition()
	if (Notepad.MouseCursorX == x and Notepad.MouseCursorY == y) then
		--> player afk?
		if (not Notepad.PlayerAFKTicker) then
			Notepad.PlayerAFKTicker = C_Timer.NewTicker(5, Notepad.DoFlashAnim, 10)
		end
	end
end

function Notepad:ShowNoteOnScreen(bossId)
	local note = Notepad:GetNote(bossId)
	if (note) then
		--currently shown in the screen
		Notepad:SetCurrentlyShownBoss(bossId)

		if (Notepad.UpdateFrameShownOnOptions) then
			Notepad:UpdateFrameShownOnOptions()
		end

		Notepad.screenFrame:Show()

		local formatedText = Notepad:FormatText(note)
		local playerName = UnitName("player")

		local locclass, class = UnitClass("player")
		local unitclasscolor = RAID_CLASS_COLORS[class] and RAID_CLASS_COLORS[class].colorStr
		if (unitclasscolor) then
			formatedText = formatedText:gsub (playerName, "|cFFFFFF00[|r|c" .. unitclasscolor .. string.upper (playerName) .. "|r|cFFFFFF00]|r")
			formatedText = formatedText:gsub (string.lower (playerName), "|cFFFFFF00[|r|c" .. unitclasscolor .. string.upper (playerName) .. "|r|cFFFFFF00]|r")
		end

		Notepad.screenFrame.text:SetText(formatedText)

		RaidAssignmentsNoteEditboxScreenScrollBarScrollDownButton:SetScript("OnUpdate", updateScrollBar)
		C_Timer.After (0.5, updateScrollBar)

		RaidAssignmentsNoteEditboxScreenScrollBar:SetValue (0)

		Notepad.DoFlashAnim()

		Notepad.MouseCursorX, Notepad.MouseCursorY = GetCursorPosition()

		C_Timer.After(3, track_mouse_position)

		Notepad:UpdateScreenFrameBackground()
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

		if (from_close_button and type (from_close_button) == "boolean") then
			if (isRaidLeader("player")) then
				RA:ShowPromptPanel("Close it on All Raid Members as Well?", function() Notepad:SendHideShownNote() end, function() end)
			end
		end
	end
end

function Notepad:ValidateNoteCurrentlyShown()
	if (not IsInRaid()) then
		return Notepad.UnshowNoteOnScreen()
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
end

function Notepad:PLAYER_REGEN_DISABLED()
	if (Notepad.db.hide_on_combat and (InCombatLockdown() or UnitAffectingCombat ("player")) and Notepad:GetCurrentlyShownBoss() and not Notepad.mainFrame:IsShown()) then
		Notepad.screenFrame.on_combat = true
		Notepad.screenFrame:Hide()
	end
end

function Notepad:PLAYER_REGEN_ENABLED()
	if (Notepad:GetCurrentlyShownBoss() and Notepad.screenFrame.on_combat) then
		Notepad.screenFrame:Show()
		Notepad.screenFrame.on_combat = nil
	end
end

function Notepad:PLAYER_LOGOUT()
	--if there's a boss shown in the screen, dave it again to refresh when it was set in the screen
	--when the player logon again, check if the logout was not long time ago and show again to the screen
	local bossId = Notepad:GetCurrentlyShownBoss()
	if (bossId) then
		Notepad:SetCurrentlyShownBoss(bossId)
	end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Notepad.OnShowOnOptionsPanel()
	local OptionsPanel = Notepad.OptionsPanel
	Notepad.BuildOptions (OptionsPanel)
end

function Notepad.BuildOptions(frame)
	if (frame.FirstRun) then
		return
	end
	frame.FirstRun = true

	local mainFrame = frame
	mainFrame:SetSize (840, 680)
	Notepad.mainFrame = mainFrame

	mainFrame:SetScript ("OnShow", function()
		if (Notepad:GetCurrentlyShownBoss()) then
			Notepad:UpdateFrameShownOnOptions()
			if (Notepad.screenFrame.on_combat) then
				Notepad.screenFrame:Show()
			end
		else
			mainFrame.frameNoteShown:Hide()
		end
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
	
		{type = "label", get = function() return "Text:" end, text_template = Notepad:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},
		
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
		
		--
		{
			type = "blank",
		},
		--
		{type = "label", get = function() return "Frame:" end, text_template = Notepad:GetTemplate ("font", "ORANGE_FONT_TEMPLATE")},
		--
		{
			type = "select",
			get = function() return Notepad.db.framestrata end,
			values = function() return strataTable end,
			name = "Frame Strata"
		},
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
			name = "Frame Background",
			
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
			name = "Background Color",
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
			name = "Hide in Combat",
		},
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
		if (lastBossSelected == 0) then
			lastBossSelected = data[#data].bossId
		end

		--update boss scroll
		for i = 1, totalLines do
			local index = i + offset
			local bossData = data[index]
			if (bossData) then
				--get the data
				local bossName = bossData.bossName
				local bossRaidName = bossData.bossRaidName
				local bossIcon = bossData.bossIcon
				local bossId = bossData.bossId

				--update the line
				local line = self:GetLine(i)
				line.bossName:SetText(bossName)
				DF:TruncateText(line.bossName, 130)
				line.bossRaidName:SetText(bossRaidName)
				DF:TruncateText(line.bossRaidName, 130)

				line.bossIcon:SetTexture(bossIcon)
				line.bossIcon:SetTexCoord(0, 1, 0, .95)

				if (bossId == lastBossSelected) then
					line:SetBackdropColor(unpack(scrollbox_line_backdrop_color_selected))
				else
					line:SetBackdropColor(unpack(scrollbox_line_backdrop_color))
				end

				line.bossId = bossId

				line:Show()
			end
		end
	end

	local onClickBossLine = function(self)
		local bossId = self.bossId
		Notepad:SetCurrentEditingBossId(bossId)
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

	--create the boss data table
	local bossData = Notepad:GetBossList()

	--create the left scroll to select which boss to edit
	local bossScrollFrame = DF:CreateScrollBox(mainFrame, "$parentBossScrollBox", refreshBossList, bossData, scrollBossWidth, scrollBossHeight, amoutBossLines, bossLinesHeight)

	--create the scrollbox lines
	for i = 1, amoutBossLines do
		bossScrollFrame:CreateLine(createdBossLine, i)
	end

	DF:ReskinSlider(bossScrollFrame)
	DF:ApplyStandardBackdrop(bossScrollFrame)
	mainFrame.BossSelectionBox = bossScrollFrame
	bossScrollFrame:SetPoint("topleft", mainFrame, "topleft", 0, 5)
	mainFrame.BossSelectionBox:Refresh()

	bossScrollFrame:Refresh()
	bossScrollFrame:Show()

	bossScrollFrame:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))

	--block showing the current boss in the screen
	local frameNoteShown = CreateFrame("frame", nil, mainFrame, "BackdropTemplate")
	frameNoteShown:SetPoint("bottomright", mainFrame, "bottomright", 26, 45)
	frameNoteShown:SetSize(190, 43)
	frameNoteShown:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
	frameNoteShown:SetBackdropColor(1, 1, 1, .5)
	frameNoteShown:SetBackdropBorderColor(unpack(RA.BackdropBorderColor))
	frameNoteShown:Hide()

	mainFrame.frameNoteShown = frameNoteShown

	--> currently showing note
	local labelNoteShown1 = Notepad:CreateLabel (frameNoteShown, "Showing on screen" .. ":", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"), _, _, "label_note_show1")
	local labelNoteShown2 = Notepad:CreateLabel (frameNoteShown, "", Notepad:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"), _, _, "label_note_show2")
	labelNoteShown1:SetPoint (5, -5)
	labelNoteShown2:SetPoint (5, -25)

	local unsendButton = Notepad:CreateButton (frameNoteShown, Notepad.UnshowNoteOnScreen, 40, 40, "X", _, _, _, "button_unsend", _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	unsendButton:SetSize(24, 24)
	unsendButton:SetPoint("right", frameNoteShown, "right", -8, 0)

	function Notepad:UpdateFrameShownOnOptions()
		local bossId = Notepad:GetCurrentEditingBossId()
		local note = Notepad:GetNote(bossId)
		local bossInfo = Notepad:GetBossInfo(bossId)

		if (note) then
			mainFrame.frameNoteShown:Show()
			mainFrame.frameNoteShown.label_note_show2.text = bossInfo.bossName
		else
			mainFrame.frameNoteShown:Hide()
		end
	end

	--> multi line editbox for edit the note
	local editboxNotes = Notepad:NewSpecialLuaEditorEntry (mainFrame, 446, 585, "editboxNotes", "RaidAssignmentsNoteEditbox", true)
	editboxNotes:SetPoint("topleft", mainFrame, "topleft", 225, -14)
	editboxNotes:SetTemplate(Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))

	editboxNotes:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, tileSize = 64, tile = true, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]]})
	editboxNotes:SetBackdropBorderColor(0, 0, 0, 0)
	DetailsFramework:ReskinSlider(editboxNotes.scroll)

	editboxNotes.editbox:SetTextInsets(3, 3, 3, 3)
	editboxNotes.scroll:ClearAllPoints()
	editboxNotes.scroll:SetPoint("topleft", editboxNotes, "topleft", 1, -1)
	editboxNotes.scroll:SetPoint("bottomright", editboxNotes, "bottomright", -1, 0)
	local f, h, fl = editboxNotes.editbox:GetFont()
	editboxNotes.editbox:SetFont(f, 12, fl)

	RaidAssignmentsNoteEditboxScrollBar:SetPoint("topleft", editboxNotes, "topright", -20, -16)
	RaidAssignmentsNoteEditboxScrollBar:SetPoint("bottomleft", editboxNotes, "bottomright", -20, 16)

	editboxNotes:Hide()

	local clearEditbox = function()
		editboxNotes:SetText ("")
	end

	local saveChanges = function()
		Notepad:SaveCurrentEditingNote()
		local bossId = Notepad:GetCurrentEditingBossId()
		Notepad:ShowNoteOnScreen(bossId)
		Notepad:SendNote(bossId)
		return true
	end

	local saveChangesAndSend = function()
		local hasSent = saveChanges()
		if (not hasSent) then
			local bossId = Notepad:GetCurrentEditingBossId()
			Notepad:ShowNoteOnScreen(bossId)
			Notepad:SendNote(bossId)
		end
	end

	local saveChangesAndClose = function()
		saveChanges()
		Notepad:CancelNoteEditing()
	end

	local buttonWidth = 100

	--clear "Clear"
	local clearButton =  Notepad:CreateButton (mainFrame, clearEditbox, buttonWidth, 20, "Clear Text", _, _, _, "buttonClear", _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	clearButton:SetIcon ([[Interface\Glues\LOGIN\Glues-CheckBox-Check]])
	clearButton.widget.texture_disabled:SetTexture ([[Interface\Tooltips\UI-Tooltip-Background]])
	clearButton.widget.texture_disabled:SetVertexColor (0, 0, 0)
	clearButton.widget.texture_disabled:SetAlpha (.5)
	mainFrame.buttonClear = clearButton

	--save "Save"
	local saveButton =  Notepad:CreateButton (mainFrame, saveChanges, buttonWidth, 20, "Save", _, _, _, "buttonSave", _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	saveButton:SetIcon ([[Interface\BUTTONS\UI-CheckBox-Check]], 16, 16, "overlay", {0, 1, 0, 28/32}, {1, 1, 1}, 2, 1, 0)
	saveButton.widget.texture_disabled:SetTexture ([[Interface\Tooltips\UI-Tooltip-Background]])
	saveButton.widget.texture_disabled:SetVertexColor (0, 0, 0)
	saveButton.widget.texture_disabled:SetAlpha (.5)
	mainFrame.buttonSave = saveButton

	--save and send "Send"
	local save2Button =  Notepad:CreateButton (mainFrame, saveChangesAndSend, buttonWidth, 20, "Send", _, _, _, "buttonSave2", _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	save2Button:SetIcon ([[Interface\BUTTONS\JumpUpArrow]], 14, 12, "overlay", {0, 1, 0, 32/32}, {1, 1, 1}, 2, 1, 0)
	save2Button.widget.texture_disabled:SetTexture ([[Interface\Tooltips\UI-Tooltip-Background]])
	save2Button.widget.texture_disabled:SetVertexColor (0, 0, 0)
	save2Button.widget.texture_disabled:SetAlpha (.5)
	mainFrame.buttonSave2 = save2Button

	--cancel edition "Done"
	local cancelButton = Notepad:CreateButton (mainFrame, saveChangesAndClose, buttonWidth, 20, "Done", _, _, _, "buttonCancel", _, _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	mainFrame.doneButton = cancelButton
	cancelButton:SetIcon ([[Interface\BUTTONS\UI-CheckBox-Check]], 16, 16, "overlay", {0, 1, 0, 28/32}, {1, 0.8, 0}, 2, 1, 0)
	cancelButton.widget.texture_disabled:SetTexture ([[Interface\Tooltips\UI-Tooltip-Background]])
	cancelButton.widget.texture_disabled:SetVertexColor (0, 0, 0)
	cancelButton.widget.texture_disabled:SetAlpha (.5)
	mainFrame.buttonCancel = cancelButton

	--set points
	do
		local buttons_y = -615
		cancelButton:SetPoint ("topleft", mainFrame, "topleft", 573 , buttons_y)
		save2Button:SetPoint ("right", cancelButton, "left", -16 , 0)
		saveButton:SetPoint ("right", save2Button, "left", -16 , 0)
		clearButton:SetPoint ("right", saveButton, "left", -16 , 0)
	end

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

	local label_colors = Notepad:CreateLabel (colors_panel, "Color" .. ":", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
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

	local dropdown_colors = Notepad:CreateDropDown (colors_panel, build_color_list, 1, 186, 20, "dropdown_colors", _, Notepad:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))
	label_colors:SetPoint ("topleft", editboxNotes, "topright", startX, 16)
	dropdown_colors:SetPoint ("topleft", label_colors, "bottomleft", 0, -3)

	local index = 1
	local colors = {"white", "silver", "gray", "HUNTER", "WARLOCK", "PRIEST", "PALADIN", "MAGE", "ROGUE", "DRUID", "SHAMAN", "WARRIOR", "DEATHKNIGHT", "MONK", --14
	"darkseagreen", "green", "lime", "yellow", "gold", "orange", "orangered", "red", "magenta", "pink", "deeppink", "violet", "mistyrose", "blue", "darkcyan", "cyan", "lightskyblue", "maroon",
	"peru", "plum", "tan", "wheat"} --4
	for o = 1, 4 do
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
	
	--~colors
	local current_color = Notepad:CreateLabel (colors_panel, "A", 14, "white", nil, "current_font")
	current_color:SetPoint ("bottomright", dropdown_colors, "topright")
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

	--raid targets
	local labelRaidTargets = Notepad:CreateLabel (colors_panel, "Targets" .. ":", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	labelRaidTargets:SetPoint ("topleft", editboxNotes, "topright", startX, -100)
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
			raidtarget:SetPoint ("topleft", editboxNotes, "topright", startX + ((i-1)*24), -91 + (o*23*-1))
			local color_texture = raidtarget:CreateTexture (nil, "overlay")
			color_texture:SetTexture ("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_" .. index)
			color_texture:SetAlpha(0.8)
			color_texture:SetPoint("center", 0, 0)
			color_texture:SetSize(20, 20)
			index = index + 1
		end
	end

	--cooldowns
	local cooldownAbilitiesX = 6
	local cooldownAbilitiesY = -138
	local iconWidth = 24

	local labelIconcooldowns = Notepad:CreateLabel (colors_panel, "Cooldowns" .. ":", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	labelIconcooldowns:SetPoint("topleft", editboxNotes, "topright", cooldownAbilitiesX, -147)

	local cooldown_icon_path = [[|TICONPATH:0|t]]
	local onSpellcooldownSelection = function (self, button, spellid)
		local cursorPos = mainFrame.editboxNotes.editbox:GetCursorPosition()
		local spellname, _, iconpath = GetSpellInfo (spellid)
		local  textToInsert = cooldown_icon_path:gsub([[ICONPATH]], iconpath) .. " " .. spellname .. " (  ) "
		mainFrame.editboxNotes.editbox:Insert(textToInsert)
		mainFrame.editboxNotes.editbox:SetFocus(true)
		mainFrame.editboxNotes.editbox:SetCursorPosition(cursorPos + #textToInsert - 3)
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
	for spellId, cooldownTable in pairs(LIB_RAID_STATUS_COOLDOWNS_INFO) do
		cooldownList[#cooldownList+1] = {spellId, cooldownTable.type, cooldownTable.class, cooldownTable}
	end

	table.sort(cooldownList, function(t1, t2) return t1[3] > t2[3] end)
	table.sort(cooldownList, function(t1, t2) return t1[2] > t2[2] end)

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

	--boss spells
	local bossAbilitiesY = -268
	local bossAbilitiesX = 6
	local iconWidth = 26

	local label_iconbossspells = Notepad:CreateLabel(colors_panel, "Boss Abilities" .. ":", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	label_iconbossspells:SetPoint("topleft", editboxNotes, "topright", bossAbilitiesX, bossAbilitiesY - 12)

	local bossspell_icon_path = [[|TICONPATH:0|t]]
	local bossspell_icon_path_noformat = [[||TICONPATH:0||t]]
	local on_bossspell_selection = function (self, button)
		local cursorPos = mainFrame.editboxNotes.editbox:GetCursorPosition()

		local spellname, _, iconpath = GetSpellInfo (self.MyObject.spellid)
		if (Notepad.db.auto_format) then
			local textToInsert = bossspell_icon_path:gsub([[ICONPATH]], iconpath) .. " " .. spellname .. " "
			mainFrame.editboxNotes.editbox:Insert(textToInsert)
			mainFrame.editboxNotes.editbox:SetFocus(true)
			mainFrame.editboxNotes.editbox:SetCursorPosition(cursorPos + #textToInsert)

		else
			local textToInsert = bossspell_icon_path_noformat:gsub([[ICONPATH]], iconpath) .. " " .. spellname .. " "
			mainFrame.editboxNotes.editbox:Insert(textToInsert)
			mainFrame.editboxNotes.editbox:SetFocus(true)
			mainFrame.editboxNotes.editbox:SetCursorPosition(cursorPos + #textToInsert)
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
		local bossId = Notepad:GetCurrentEditingBossId()
		local raidInfo = Notepad:GetBossInfo(bossId)
		local instanceId = raidInfo.instanceId

		if (bossId) then
			local spells = DetailsFramework:GetSpellsForEncounterFromJournal(instanceId, bossId)

			if (spells) then
				local button_index = 1
				local i, o = 1, 1
				local alreadyAdded = {}

				for index, spellid in ipairs(spells) do
					local spellname, _, spellicon = GetSpellInfo (spellid)
					if (spellname and not alreadyAdded [spellname]) then
						alreadyAdded[spellname] = true

						local button = bossAbilitiesButtons[button_index]
						if (not button) then
							button = Notepad:CreateButton(colors_panel, on_bossspell_selection, iconWidth, iconWidth, "", spellid, _, _, "button_bossspell" .. button_index)
							button.spellTexture = button:CreateTexture(nil, "artwork")
							bossAbilitiesButtons[button_index] = button
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

						button_index = button_index + 1
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

	--keywords
	local labelKeywords = Notepad:CreateLabel (colors_panel, "Keywords" .. ":", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	labelKeywords:SetPoint ("topleft", editboxNotes, "topright", 8, -470)

	local localizedKeywords = {"Cooldowns", "Phase ", "Dispell", "Interrupt", "Adds", "Sequence", "Second Pot At", "Tanks", "Dps", "Healers", "Transition"}

	if (UnitFactionGroup("player") == "Horde") then
		tinsert (localizedKeywords, "Bloodlust At")
	else
		tinsert (localizedKeywords, "Heroism")
	end

	local on_keyword_selection = function (self, button, keyword)
		local cursorPos = mainFrame.editboxNotes.editbox:GetCursorPosition()
		local textToInsert = keyword .. ":\n"
		mainFrame.editboxNotes.editbox:Insert(textToInsert)
		mainFrame.editboxNotes.editbox:SetFocus(true)
		mainFrame.editboxNotes.editbox:SetCursorPosition(cursorPos + #textToInsert)
	end

	local i, o, index = 1, 1, 1
	local button_keyword_backdrop = {edgeSize = 1, tileSize = 64, tile = true, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]]}

	local on_enter_keyword = function (self)
		local button = self.MyObject
		button.textcolor = "orange"
	end

	local on_leave_keyword = function (self)
		local button = self.MyObject
		button.textcolor = "white"
	end

	for index, keyword in pairs (localizedKeywords) do
		local keyword_button =  Notepad:CreateButton (colors_panel, on_keyword_selection, 92, 12, keyword, keyword, _, _, "button_keyword" .. index, nil, 1) --short method 1
		keyword_button:SetBackdrop (button_keyword_backdrop)
		keyword_button:SetBackdropColor (0, 0, 0, 0.4)
		keyword_button:SetPoint ("topleft", editboxNotes, "topright", 6 + ((i-1)*97), -470 + (o*13*-1))
		keyword_button:SetHook ("OnEnter", on_enter_keyword)
		keyword_button:SetHook ("OnLeave", on_leave_keyword)
		keyword_button.textsize = 10
		keyword_button.textface = "Friz Quadrata TT"
		keyword_button.textcolor = "white"
		keyword_button.textalign = "<"
		keyword_button.keyword = keyword

		index = index + 1
		i = i +1
		if (i == 3) then
			i = 1
			o = o + 1
		end
	end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	local func = function (self, fixedparam, value)
		Notepad.db.auto_format = value
		Notepad:FormatText()
	end

	local checkbox = Notepad:CreateSwitch (colors_panel, func, Notepad.db.auto_format, _, _, _, _, _, "NotepadFormatCheckBox", _, _, _, _, Notepad:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	checkbox:SetAsCheckBox()
	checkbox.tooltip = "auto format text"
	checkbox:SetPoint ("bottomleft", editboxNotes, "topleft", 0, 2)
	checkbox:SetValue (Notepad.db.auto_format)

	local labelAutoformat = Notepad:CreateLabel (colors_panel, "Auto Format Text (|cFFC0C0C0can't copy/paste icons|r)", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	labelAutoformat:SetPoint ("left", checkbox, "right", 2, 0)

	local func = function (self, fixedparam, value)
		Notepad.db.auto_complete = value
	end

	local checkbox2 = Notepad:CreateSwitch (colors_panel, func, Notepad.db.auto_complete, _, _, _, _, _, "NotepadAutoCompleteCheckBox", _, _, _, _, Notepad:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE"), Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	checkbox2:SetAsCheckBox()
	checkbox2.tooltip = "auto format text"
	checkbox2:SetPoint ("bottomleft", editboxNotes, "topleft", 250, 2)
	checkbox2:SetValue (Notepad.db.auto_complete)

	local labelAutocomplete = Notepad:CreateLabel (colors_panel, "Auto Complete Player Names", Notepad:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE"))
	labelAutocomplete:SetPoint ("left", checkbox2, "right", 2, 0)

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	editboxNotes:SetScript("OnShow", function()
		colors_panel:SetScript("OnUpdate", do_text_format)
		Notepad:UpdateBossAbilities()
	end)
	editboxNotes:SetScript("OnHide", function()
		colors_panel:SetScript("OnUpdate", nil)
	end)
	
	local lastword, characters_count = "", 0

	local get_last_word = function()
		lastword = ""
		local cursor_pos = mainFrame.editboxNotes.editbox:GetCursorPosition()
		local text = mainFrame.editboxNotes.editbox:GetText()
		for i = cursor_pos, 1, -1 do
			local character = text:sub (i, i)
			if (character:match ("%a")) then
				lastword = character .. lastword
			else
				break
			end
		end
	end
	
	editboxNotes.editbox:SetScript ("OnTextChanged", function (self)
		local chars_now = mainFrame.editboxNotes.editbox:GetText():len()
		--> backspace
		if (chars_now == characters_count -1) then
			lastword = lastword:sub (1, lastword:len()-1)
		--> delete lots of text
		elseif (chars_now < characters_count) then
			mainFrame.editboxNotes.editbox.end_selection = nil
			get_last_word()
		end
		characters_count = chars_now
	end)
	
	editboxNotes.editbox:SetScript ("OnSpacePressed", function (self)
		mainFrame.editboxNotes.editbox.end_selection = nil
	end)
	editboxNotes.editbox:HookScript ("OnEscapePressed", function (self) 
		mainFrame.editboxNotes.editbox.end_selection = nil
	end)
	
	editboxNotes.editbox:SetScript ("OnEnterPressed", function (self) 
		if (mainFrame.editboxNotes.editbox.end_selection) then
			mainFrame.editboxNotes.editbox:SetCursorPosition (mainFrame.editboxNotes.editbox.end_selection)
			mainFrame.editboxNotes.editbox:HighlightText (0, 0)
			mainFrame.editboxNotes.editbox.end_selection = nil
			mainFrame.editboxNotes.editbox:Insert (" ")
		else
			mainFrame.editboxNotes.editbox:Insert ("\n")
		end
		
		lastword = ""
	end)
	
	editboxNotes.editbox:SetScript ("OnEditFocusGained", function (self) 
		get_last_word()
		mainFrame.editboxNotes.editbox.end_selection = nil
		characters_count = mainFrame.editboxNotes.editbox:GetText():len()
	end)

	editboxNotes.editbox:SetScript ("OnChar", function (self, char) 
		mainFrame.editboxNotes.editbox.end_selection = nil
	
		if (mainFrame.editboxNotes.editbox.ignore_input) then
			return
		end
		if (char:match ("%a")) then
			lastword = lastword .. char
		else
			lastword = ""
		end
		
		mainFrame.editboxNotes.editbox.ignore_input = true
		if (lastword:len() >= 2 and Notepad.db.auto_complete) then
			for i = 1, GetNumGroupMembers() do
				local name = UnitName ("raid" .. i) or UnitName ("party" .. i)
				--print (name, string.find ("keyspell", "^key"))
				if (name and (name:find ("^" .. lastword) or name:lower():find ("^" .. lastword))) then
					local rest = name:gsub (lastword, "")
					rest = rest:lower():gsub (lastword, "")
					local cursor_pos = self:GetCursorPosition()
					mainFrame.editboxNotes.editbox:Insert (rest)
					mainFrame.editboxNotes.editbox:HighlightText (cursor_pos, cursor_pos + rest:len())
					mainFrame.editboxNotes.editbox:SetCursorPosition (cursor_pos)
					mainFrame.editboxNotes.editbox.end_selection = cursor_pos + rest:len()
					break
				end
			end
		end
		mainFrame.editboxNotes.editbox.ignore_input = false
	end)
end

function Notepad:FormatText(mytext)
	local text = mytext
	if (not text) then
		text = Notepad.mainFrame.editboxNotes.editbox:GetText()
	end

	if (Notepad.db.auto_format or mytext) then
		-- format the text, show icons
		text = text:gsub ("{Star}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_1:0|t]])
		text = text:gsub ("{Circle}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_2:0|t]])
		text = text:gsub ("{Diamond}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_3:0|t]])
		text = text:gsub ("{Triangle}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_4:0|t]])
		text = text:gsub ("{Moon}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_5:0|t]])
		text = text:gsub ("{Square}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_6:0|t]])
		text = text:gsub ("{Cross}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_7:0|t]])
		text = text:gsub ("{Skull}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_8:0|t]])
		text = text:gsub ("{rt1}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_1:0|t]])
		text = text:gsub ("{rt2}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_2:0|t]])
		text = text:gsub ("{rt3}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_3:0|t]])
		text = text:gsub ("{rt4}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_4:0|t]])
		text = text:gsub ("{rt5}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_5:0|t]])
		text = text:gsub ("{rt6}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_6:0|t]])
		text = text:gsub ("{rt7}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_7:0|t]])
		text = text:gsub ("{rt8}", [[|TInterface\TargetingFrame\UI-RaidTargetingIcon_8:0|t]])
		
		text = text:gsub ("||c", "|c")
		text = text:gsub ("||r", "|r")
		text = text:gsub ("||t", "|t")
		text = text:gsub ("||T", "|T")
		
	else
		--> show plain text
		--> replace the raid target icons:
		text = text:gsub ([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_1:0|t]], "{Star}")
		text = text:gsub ([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_2:0|t]], "{Circle}")
		text = text:gsub ([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_3:0|t]], "{Diamond}")
		text = text:gsub ([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_4:0|t]], "{Triangle}")
		text = text:gsub ([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_5:0|t]], "{Moon}")
		text = text:gsub ([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_6:0|t]], "{Square}")
		text = text:gsub ([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_7:0|t]], "{Cross}")
		text = text:gsub ([[|TInterface\TargetingFrame\UI%-RaidTargetingIcon_8:0|t]], "{Skull}")

		--> escape sequences
		text = text:gsub ("|c", "||c")
		text = text:gsub ("|r", "||r")
		text = text:gsub ("|t", "||t")
		text = text:gsub ("|T", "||T")
	end

	--> passed a text, so just return a formated text
	if (mytext) then
		return text
	else
		Notepad.mainFrame.editboxNotes.editbox:SetText (text)
	end
end

local install_status = RA:InstallPlugin ("Raid Assignments", "RANotepad", Notepad, default_config)

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
function Notepad.OnReceiveComm(sourceName, prefix, sourcePluginVersion, sourceUnit, fullNote, bossId)
	sourceUnit = sourceName

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

			--save the note
			Notepad:SaveNote(fullNote, bossId)
			--show the note
			Notepad:ShowNoteOnScreen(bossId)

			--if options window is opened, update the scroll frame and the editor
			if (Notepad.mainFrame and Notepad.mainFrame:IsShown()) then
				Notepad:SetCurrentEditingBossId(bossId)
			end

	--> Requested Note - the user requested the note to the raid leader
		elseif (prefix == COMM_QUERY_NOTE or prefix == COMM_QUERY_SEED) then --"NOQN" "NOQI"
			--check if I'm the raid leader
			if ((not IsInRaid() and not IsInGroup()) or not isRaidLeader ("player")) then
				return
			end

			if (isConnected(sourceUnit)) then
				local currentBoss = Notepad:GetCurrentlyShownBoss()
				if (currentBoss) then
					local note = Notepad:GetNote(currentBoss)
					Notepad:SendPluginCommWhisperMessage(COMM_RECEIVED_FULLNOTE, sourceUnit, nil, nil, Notepad:GetPlayerNameWithRealm(), note, currentBoss)
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
function Notepad:SendNote(bossId)
	--is raid leader?
	if (isRaidLeader("player") and (IsInRaid() or IsInGroup())) then
		local ZoneName, InstanceType, DifficultyID, _, _, _, _, ZoneMapID = GetInstanceInfo()
		if (DifficultyID and DifficultyID == 17) then
			--ignore raid finder
			return
		end

		--send the note
		local note = Notepad:GetNote(bossId)
		if (note) then
			if (IsInRaid()) then
				Notepad:SendPluginCommMessage (COMM_RECEIVED_FULLNOTE, "RAID", nil, nil, Notepad:GetPlayerNameWithRealm(), note, bossId)
			else
				Notepad:SendPluginCommMessage (COMM_RECEIVED_FULLNOTE, "PARTY", nil, nil, Notepad:GetPlayerNameWithRealm(), note, bossId)
			end
		end
	end
end