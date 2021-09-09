
local RA = _G.RaidAssist
local DF = DetailsFramework
local _

local plugin_frame_backdrop = {edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true}
local plugin_frame_backdrop_color = {0, 0, 0, 0.8}
local plugin_frame_backdrop_border_color = {0, 0, 0, 1}

DF:InstallTemplate("button", "RAIDASSIST_BUTTON_DISABLED", {backdropcolor = {.4, .4, .4, .3}, backdropbordercolor = {0, 0, 0, .5}}, "OPTIONS_BUTTON_TEMPLATE")
DF:InstallTemplate("button", "RAIDASSIST_BUTTON_SELECTED", {backdropbordercolor = {1, .7, .1, 1},}, "OPTIONS_BUTTON_TEMPLATE")

function RA:CreatePopUpFrame(plugin, frame_name)
	local f = CreateFrame ("frame", frame_name, UIParent, "BackdropTemplate")
	f:SetSize (100, 80)
	
	f:SetBackdrop (plugin_frame_backdrop)
	f:SetBackdropColor (unpack (plugin_frame_backdrop_color))
	f:SetBackdropBorderColor (unpack (plugin_frame_backdrop_border_color))
	
	f:Hide()
	return f
end

function RA:CreateStandardFrame (parent, width, heigh, frameTitle, frame_name, db)
	local f = RA:Create1PxPanel (parent or UIParent, width or 300, heigh or 150, frameTitle, frame_name, db, _, false)
	if (not f:HasPosition()) then
		f:SetPoint ("center", UIParent, "center")
		f:SavePosition()
	end
	
	f:SetBackdrop (plugin_frame_backdrop)
	f:SetBackdropColor (unpack (plugin_frame_backdrop_color))
	f:SetBackdropBorderColor (unpack (plugin_frame_backdrop_border_color))
	
	local titleBar = CreateFrame ("frame", frame_name .. "TitleBar", f, "BackdropTemplate")
	titleBar:SetPoint ("topleft", f, "topleft", 2, -3)
	titleBar:SetPoint ("topright", f, "topright", -2, -3)
	titleBar:SetHeight (20)
	titleBar:SetBackdrop (plugin_frame_backdrop)
	titleBar:SetBackdropColor (.2, .2, .2, 1)
	titleBar:SetBackdropBorderColor (0, 0, 0, 1)
	
	f.Title:ClearAllPoints()
	f.Title:SetParent (titleBar)
	f.Title:SetPoint ("center", titleBar, "center")
	f.Close:ClearAllPoints()
	f.Close:SetPoint ("right", titleBar, "right", -2, 0)
	f.Lock:ClearAllPoints()
	f.Lock:SetPoint ("right", f.Close, "left", 1, 0)

	return f
end

function RA:CreatePluginFrame (plugin, frameName, frameTitle)
	if (not frameName) then
		assert (type (frameName) == "string", "CreatePluginFrame expects a string on parameter 2.")
	end

	plugin.db [frameName] = plugin.db [frameName] or {}

	local f = RA:Create1PxPanel (UIParent, 100, 80, frameTitle, frameName, plugin.db [frameName], _, false)
	if (not f:HasPosition()) then
		f:SetPoint ("center", UIParent, "center")
		f:SavePosition()
	end

	f:SetBackdrop (plugin_frame_backdrop)
	f:SetBackdropColor (unpack (plugin_frame_backdrop_color))
	f:SetBackdropBorderColor (unpack (plugin_frame_backdrop_border_color))

	local titleBar = CreateFrame ("frame", frameName .. "TitleBar", f, "BackdropTemplate")
	titleBar:SetPoint ("topleft", f, "topleft", 2, -3)
	titleBar:SetPoint ("topright", f, "topright", -2, -3)
	titleBar:SetHeight (20)
	titleBar:SetBackdrop (plugin_frame_backdrop)
	titleBar:SetBackdropColor (.2, .2, .2, 1)
	titleBar:SetBackdropBorderColor (0, 0, 0, 1)

	f.Title:ClearAllPoints()
	f.Title:SetParent (titleBar)
	f.Title:SetPoint ("center", titleBar, "center")
	f.Close:ClearAllPoints()
	f.Close:SetPoint ("right", titleBar, "right", -2, 0)
	f.Lock:ClearAllPoints()
	f.Lock:SetPoint ("right", f.Close, "left", 1, 0)

	f:Hide()
	return f
end

function RA:CreateCleanFrame(plugin, frameName)
	if (not frameName) then
		assert (type (frameName) == "string", "CreateCleanFrame expects a string on parameter 2.")
	end

	plugin.db[frameName] = plugin.db[frameName] or {}

	local f = RA:Create1PxPanel (UIParent, 100, 80, "", frameName, plugin.db [frameName], _, true)
	if (not f:HasPosition()) then
		f:SetPoint ("center", UIParent, "center")
		f:SavePosition()
	end

	f:SetBackdrop (plugin_frame_backdrop)
	f:SetBackdropColor (unpack (plugin_frame_backdrop_color))
	f:SetBackdropBorderColor (unpack (plugin_frame_backdrop_border_color))

	f.Title:Hide()
	f.Close:Hide()
	f.Lock:Hide()

	f:Hide()
	return f
end