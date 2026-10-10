-- Good Neighbours (FS25) - "Good Neighbours" section in ESC -> Settings
--   server (admin only, the same for every player): neighbour calls per day, fields per call, neighbours work themselves
--   phone (every player for himself): wallpaper, ring volume, mute, messages
-- Author: billiD

local GN = GoodNeighbours

GN.SettingsMenu = GN.SettingsMenu or {}
local SM = GN.SettingsMenu

-- ---------------------------------------------------------------------------
-- Option rows
-- ---------------------------------------------------------------------------

local function numberTexts(values)
	local out = {}
	for _, v in ipairs(values) do
		table.insert(out, v == -1 and GN.text("gn_unlimited") or tostring(v))
	end
	return out
end

local function indexOf(list, v, default)
	for i, x in ipairs(list) do
		if x == v then
			return i
		end
	end
	return default or 1
end

local function onOff()
	return { GN.text("gn_on"), GN.text("gn_off") }
end

--- Every option: section, title, info, texts(), state(), apply(state), admin
function SM.definitions()
	local S, C = GN.Server, GN.Client
	return {
		{ section = "gn_menu_section_server" },
		{ key = "calls", admin = true, title = "gn_settings_calls_title", info = "gn_settings_calls_info",
			texts = function() return numberTexts(S.CALLS_PER_DAY_VALUES) end,
			state = function() return indexOf(S.CALLS_PER_DAY_VALUES, tonumber(C.settings.callsPerDay), 4) end,
			apply = function(st) C.setAdminSetting("callsPerDay", S.CALLS_PER_DAY_VALUES[st]) end },
		{ key = "fields", admin = true, title = "gn_settings_fields_title", info = "gn_settings_fields_info",
			texts = function() return numberTexts(S.FIELDS_PER_CALL_VALUES) end,
			state = function() return indexOf(S.FIELDS_PER_CALL_VALUES, tonumber(C.settings.fieldsPerCall), 3) end,
			apply = function(st) C.setAdminSetting("fieldsPerCall", S.FIELDS_PER_CALL_VALUES[st]) end },
		{ key = "work", admin = true, title = "gn_settings_work_title", info = "gn_settings_work_info",
			texts = onOff,
			state = function() return C.settings.npcWork == false and 2 or 1 end,
			apply = function(st) C.setAdminSetting("npcWork", st == 1) end },
		{ section = "gn_menu_section_phone" },
		{ key = "wallpaper", title = "gn_menu_wallpaper", info = "gn_menu_wallpaper_info",
			texts = function()
				local out = {}
				for _, w in ipairs(C.WALLPAPERS) do
					table.insert(out, GN.text("gn_wallpaper_" .. w, w))
				end
				return out
			end,
			state = function() return C.personal.wallpaper end,
			apply = function(st) C.personal.wallpaper = st; C.savePersonal(); GN.Phone.refreshIfOpen() end },
		{ key = "volume", title = "gn_menu_volume", info = "gn_menu_volume_info",
			texts = function()
				local out = {}
				for _, v in ipairs(C.VOLUMES) do
					table.insert(out, string.format("%d %%", math.floor(v * 100 + 0.5)))
				end
				return out
			end,
			state = function() return C.personal.volume end,
			apply = function(st) C.personal.volume = st; C.savePersonal(); C.playTone("sounds/sms.ogg") end },
		{ key = "muted", title = "gn_menu_muted", info = "gn_menu_muted_info",
			texts = function() return { GN.text("gn_off"), GN.text("gn_on") } end,
			state = function() return C.personal.muted and 2 or 1 end,
			apply = function(st) C.personal.muted = st == 2; C.savePersonal() end },
		{ key = "sms", title = "gn_menu_sms", info = "gn_menu_sms_info",
			texts = onOff,
			state = function() return C.personal.sms == false and 2 or 1 end,
			apply = function(st) C.personal.sms = st == 1; C.savePersonal() end },
	}
end

local function assignFocusIds(element)
	if element == nil or FocusManager == nil or FocusManager.serveAutoFocusId == nil then
		return
	end
	element.focusId = FocusManager:serveAutoFocusId()
	for _, child in pairs(element.elements or {}) do
		assignFocusIds(child)
	end
end

local function settingsPage()
	local screen = g_gui ~= nil and g_gui.screenControllers ~= nil and InGameMenu ~= nil and g_gui.screenControllers[InGameMenu] or nil
	return screen ~= nil and screen.pageSettings or nil
end

--- A section title: a copy of the game's own one (or built from its profile).
local function makeHeader(layout, text)
	local page = settingsPage()
	if page ~= nil and page.gameSettingsLayout ~= nil then
		for _, e in ipairs(page.gameSettingsLayout.elements) do
			if e.name == "sectionHeader" then
				local h = e:clone(layout)
				h:setText(text)
				assignFocusIds(h)
				return h
			end
		end
	end
	local h = TextElement.new()
	h.name = "sectionHeader"
	h:loadProfile(g_gui:getProfile("fs25_settingsSectionHeader"), true)
	h:setText(text)
	layout:addElement(h)
	h:onGuiSetupFinished()
	return h
end

--- An option row: a copy of the game's own option row (or built from its profiles).
local function makeRow(layout, title, info)
	local page = settingsPage()
	if page ~= nil and page.multiVolumeVoiceBox ~= nil then
		local box = page.multiVolumeVoiceBox:clone(layout)
		assignFocusIds(box)
		local option = box.elements[1]
		box.elements[2]:setText(title)
		if option.elements ~= nil and option.elements[1] ~= nil and option.elements[1].setText ~= nil then
			option.elements[1]:setText(info)
		end
		return box, option
	end
	local box = BitmapElement.new()
	box:loadProfile(g_gui:getProfile("fs25_multiTextOptionContainer"), true)
	local option = MultiTextOptionElement.new()
	option:loadProfile(g_gui:getProfile("fs25_settingsMultiTextOption"), true)
	local label = TextElement.new()
	label:loadProfile(g_gui:getProfile("fs25_settingsMultiTextOptionTitle"), true)
	label:setText(title)
	local tip = TextElement.new()
	tip.name = "ignore"
	tip:loadProfile(g_gui:getProfile("fs25_multiTextOptionTooltip"), true)
	tip:setText(info)
	option:addElement(tip)
	box:addElement(option)
	box:addElement(label)
	option:onGuiSetupFinished()
	label:onGuiSetupFinished()
	tip:onGuiSetupFinished()
	layout:addElement(box)
	box:onGuiSetupFinished()
	return box, option
end

--- Builds the rows into a layout; target receives the callbacks (gnOpt_<key>).
function SM.buildRows(layout, target)
	local rows = {}
	for _, d in ipairs(SM.definitions()) do
		if d.section ~= nil then
			table.insert(rows, { header = makeHeader(layout, GN.text(d.section)) })
		else
			local box, option = makeRow(layout, GN.text(d.title), GN.text(d.info))
			option.id = "gn_" .. d.key
			option.target = target
			option:setCallback("onClickCallback", "gnOpt_" .. d.key)
			option:setDisabled(false)
			option:setTexts(d.texts())
			table.insert(rows, { box = box, option = option, def = d })
		end
	end
	if layout.invalidateLayout ~= nil then
		layout:invalidateLayout()
	end
	return rows
end

function SM.refreshRows(rows)
	local admin = GN.isLocalAdmin()
	for _, r in ipairs(rows or {}) do
		if r.option ~= nil then
			r.option:setTexts(r.def.texts())
			r.option:setState(r.def.state())
			r.option:setDisabled(r.def.admin == true and not admin)
		end
	end
end

function SM.onOption(key, state)
	for _, d in ipairs(SM.definitions()) do
		if d.key == key then
			if d.admin and not GN.isLocalAdmin() then
				SM.refresh()
				return
			end
			GN.safeCall("option " .. key, d.apply, state)
		end
	end
end

-- callbacks (on the frame class and on the fallback target)
SM.target = { name = "" }
for _, key in ipairs({ "calls", "fields", "work", "wallpaper", "volume", "muted", "sms" }) do
	SM.target["gnOpt_" .. key] = function(_, state)
		SM.onOption(key, state)
	end
end

-- ---------------------------------------------------------------------------
-- Section "Good Neighbours" in ESC -> Settings
-- ---------------------------------------------------------------------------

function SM.buildSection()
	if SM.sectionRows ~= nil then
		return true
	end
	local page = settingsPage()
	if page == nil or page.gameSettingsLayout == nil then
		return false
	end
	SM.target.name = page.name
	SM.sectionRows = SM.buildRows(page.gameSettingsLayout, SM.target)
	for _, r in ipairs(SM.sectionRows) do
		table.insert(page.controlsList, r.box or r.header)
	end
	-- the focus manager has to know the new rows
	if FocusManager ~= nil and FocusManager.setGui ~= nil then
		FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function()
			for _, r in ipairs(SM.sectionRows or {}) do
				local e = r.box or r.header
				if e ~= nil and (e.focusId == nil or FocusManager.currentFocusData == nil
					or not FocusManager.currentFocusData.idToElementMapping[e.focusId]) then
					GN.try(FocusManager.loadElementFromCustomValues, FocusManager, e, nil, nil, false, false)
				end
			end
		end)
	end
	if InGameMenuSettingsFrame ~= nil and InGameMenuSettingsFrame.onFrameOpen ~= nil then
		InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
			GN.safeCall("settings menu", SM.refresh)
		end)
	end
	GN.log("settings section added to ESC -> Settings")
	return true
end

function SM.refresh()
	SM.refreshRows(SM.sectionRows)
end

function SM.install()
	if SM._installed or InGameMenu == nil then
		return
	end
	SM._installed = true
	if InGameMenu.onMenuOpened ~= nil then
		InGameMenu.onMenuOpened = Utils.appendedFunction(InGameMenu.onMenuOpened, function()
			GN.safeCall("settings menu", function()
				SM.buildSection()
				SM.refresh()
			end)
		end)
	end
end
