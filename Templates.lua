

local RA = RaidAssist
local _

if (_G.RaidAssistLoadDeny) then
	return
end

local plugin_frame_backdrop = {edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true}
local plugin_title_backdrop = {edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\DialogFrame\UI-DialogBox-Background-Dark]], tileSize = 64, tile = true}
local plugin_frame_backdrop_color = {0, 0, 0, 0.8}
local plugin_frame_backdrop_border_color = {0, 0, 0, 1}

function RA:CreatePopUpFrame (plugin, frame_name)
	local f = CreateFrame ("frame", frame_name, UIParent)
	f:SetSize (100, 80)
	
	f:SetBackdrop (plugin_frame_backdrop)
	f:SetBackdropColor (unpack (plugin_frame_backdrop_color))
	f:SetBackdropBorderColor (unpack (plugin_frame_backdrop_border_color))
	
	f:Hide()
	return f
end

function RA:CreateStandardFrame (parent, width, heigh, frame_title, frame_name, db)
	local f = RA:Create1PxPanel (parent or UIParent, width or 300, heigh or 150, frame_title, frame_name, db, _, false)
	if (not f:HasPosition()) then
		f:SetPoint ("center", UIParent, "center")
		f:SavePosition()
	end
	
	f:SetBackdrop (plugin_frame_backdrop)
	f:SetBackdropColor (unpack (plugin_frame_backdrop_color))
	f:SetBackdropBorderColor (unpack (plugin_frame_backdrop_border_color))
	
	local title_bar = CreateFrame ("frame", frame_name .. "TitleBar", f)
	title_bar:SetPoint ("topleft", f, "topleft", 2, -3)
	title_bar:SetPoint ("topright", f, "topright", -2, -3)
	title_bar:SetHeight (20)
	title_bar:SetBackdrop (plugin_frame_backdrop)
	title_bar:SetBackdropColor (.2, .2, .2, 1)
	title_bar:SetBackdropBorderColor (0, 0, 0, 1)
	
	f.Title:ClearAllPoints()
	f.Title:SetParent (title_bar)
	f.Title:SetPoint ("center", title_bar, "center")
	f.Close:ClearAllPoints()
	f.Close:SetPoint ("right", title_bar, "right", -2, 0)
	f.Lock:ClearAllPoints()
	f.Lock:SetPoint ("right", f.Close, "left", 1, 0)

	return f
end

function RA:CreatePluginFrame (plugin, frame_name, frame_title)

	if (not frame_name) then
		assert (type (frame_name) == "string", "CreatePluginFrame expects a string on parameter 2.")
	end

	plugin.db [frame_name] = plugin.db [frame_name] or {}
	
	local f = RA:Create1PxPanel (UIParent, 100, 80, frame_title, frame_name, plugin.db [frame_name], _, false)
	if (not f:HasPosition()) then
		f:SetPoint ("center", UIParent, "center")
		f:SavePosition()
	end
	
	f:SetBackdrop (plugin_frame_backdrop)
	f:SetBackdropColor (unpack (plugin_frame_backdrop_color))
	f:SetBackdropBorderColor (unpack (plugin_frame_backdrop_border_color))
	
	local title_bar = CreateFrame ("frame", frame_name .. "TitleBar", f)
	title_bar:SetPoint ("topleft", f, "topleft", 2, -3)
	title_bar:SetPoint ("topright", f, "topright", -2, -3)
	title_bar:SetHeight (20)
	title_bar:SetBackdrop (plugin_frame_backdrop)
	title_bar:SetBackdropColor (.2, .2, .2, 1)
	title_bar:SetBackdropBorderColor (0, 0, 0, 1)
	
	f.Title:ClearAllPoints()
	f.Title:SetParent (title_bar)
	f.Title:SetPoint ("center", title_bar, "center")
	f.Close:ClearAllPoints()
	f.Close:SetPoint ("right", title_bar, "right", -2, 0)
	f.Lock:ClearAllPoints()
	f.Lock:SetPoint ("right", f.Close, "left", 1, 0)
	
	f:Hide()
	return f
end

function RA:CreateCleanFrame (plugin, frame_name)
	if (not frame_name) then
		assert (type (frame_name) == "string", "CreateCleanFrame expects a string on parameter 2.")
	end

	plugin.db [frame_name] = plugin.db [frame_name] or {}
	
	local f = RA:Create1PxPanel (UIParent, 100, 80, "", frame_name, plugin.db [frame_name], _, true)
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