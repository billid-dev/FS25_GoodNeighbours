-- Good Neighbours (FS25) - the phone: messages, contacts, incoming calls, settings
-- Author: billiD

local GN = GoodNeighbours

GNPhoneDialog = {}
local GNPhoneDialog_mt = Class(GNPhoneDialog, DialogElement)

GN.Phone = GN.Phone or {}
local P = GN.Phone

P.GUI_NAME = "GNPhoneDialog"
P.WALLPAPER_FILES = {
	deere = "images/phone/wallpaper_deere.xml", claas = "images/phone/wallpaper_claas.xml",
	silage = "images/phone/wallpaper_silage.xml", krone = "images/phone/wallpaper_krone.xml",
}
P.PORTRAIT_FILES = {
	silhouette = "images/portraits/silhouette.xml",
	henryk_wolski = "images/portraits/henryk_wolski.xml",
	sarah_mitchell = "images/portraits/sarah_mitchell.xml",
	jonas_becker = "images/portraits/jonas_becker.xml",
	teresa_nowak = "images/portraits/teresa_nowak.xml",
	richard_hale = "images/portraits/richard_hale.xml",
	monika_zielinska = "images/portraits/monika_zielinska.xml",
	frank_weber = "images/portraits/frank_weber.xml",
}
P.WALLPAPER_IDS = { deere = "wallpaper_deere", claas = "wallpaper_claas", silage = "wallpaper_silage", krone = "wallpaper_krone" }

function GNPhoneDialog.new(target, customMt)
	local self = DialogElement.new(target, customMt or GNPhoneDialog_mt)
	self.screen = "home"
	self.contactIndex = 1
	return self
end

-- ---------------------------------------------------------------------------
-- Loading / opening
-- ---------------------------------------------------------------------------

--- Texture atlases must exist before the GUI XML is loaded (profiles look up their image slices on load).
function P.registerTextures()
	if P._texturesRegistered or g_overlayManager == nil then
		return
	end
	P._texturesRegistered = true
	local function add(rel, prefix)
		local path = Utils.getFilename(rel, GN.dir)
		if path ~= nil and fileExists(path) then
			g_overlayManager:addTextureConfigFile(path, prefix)
		else
			GN.log("missing texture config %s", tostring(rel))
		end
	end
	add("gui/gnIcons.xml", "gnIcons")
	add("gui/gnPhoneFrame.xml", "gnPhoneFrame")
	for w, file in pairs(P.WALLPAPER_FILES) do
		add(file, "gnWp_" .. w)
	end
	for portrait, file in pairs(P.PORTRAIT_FILES) do
		add(file, "gnPortrait_" .. portrait)
	end
end

function P.ensureLoaded()
	if g_gui == nil then
		return false
	end
	if g_gui.guis ~= nil and g_gui.guis[P.GUI_NAME] ~= nil then
		return true
	end
	P.registerTextures()
	P.dialog = GNPhoneDialog.new(g_gui)
	g_gui:loadGui(Utils.getFilename("gui/GNPhoneDialog.xml", GN.dir), P.GUI_NAME, P.dialog)
	return g_gui.guis ~= nil and g_gui.guis[P.GUI_NAME] ~= nil
end

function P.open()
	if not P.ensureLoaded() then
		return
	end
	if P.dialog ~= nil and P.dialog.isOpen then
		return
	end
	g_gui:showDialog(P.GUI_NAME)
end

function P.close()
	if g_gui == nil then
		return
	end
	-- the game closes dialogs by name; the other calls are fallbacks for older game versions
	if g_gui.closeDialogByName ~= nil then
		g_gui:closeDialogByName(P.GUI_NAME)
	elseif P.dialog ~= nil and P.dialog.close ~= nil then
		P.dialog:close()
	elseif g_gui.guis ~= nil and g_gui.guis[P.GUI_NAME] ~= nil then
		g_gui:closeDialog(g_gui.guis[P.GUI_NAME])
	end
	if P.dialog ~= nil and P.dialog.isOpen then
		-- still open (the call above did not close it): close through the dialog itself
		if P.dialog.close ~= nil then
			GN.try(P.dialog.close, P.dialog)
		end
	end
end

--- Open the phone on a neighbour's contact card (face-to-face chat shows a greeting).
function P.openContact(nid, greeting)
	if not P.ensureLoaded() then
		return
	end
	for i, n in ipairs(GN.neighbours) do
		if n.id == nid then
			P.pendingContact = i
		end
	end
	P.pendingGreeting = greeting and nid or nil
	if P.dialog ~= nil and P.dialog.isOpen then
		P.dialog:onOpenPending()
	else
		g_gui:showDialog(P.GUI_NAME)
	end
end

function P.toggle()
	if P.dialog ~= nil and P.dialog.isOpen then
		P.close()
	else
		P.open()
	end
end

function P.refreshIfOpen()
	if P.dialog ~= nil and P.dialog.isOpen then
		P.dialog:refresh()
	end
end

function P.onCallEnded()
	if P.dialog ~= nil and P.dialog.isOpen then
		if P.dialog.screen == "ring" or P.dialog.screen == "talk" then
			P.dialog.screen = "home"
		end
		P.dialog:refresh()
	end
end

function GNPhoneDialog:onOpen()
	GNPhoneDialog:superClass().onOpen(self)
	self.isOpen = true
	if GN.Client.call ~= nil then
		self.screen = GN.Client.callState == "talking" and "talk" or "ring"
		GN.Client.stopRing()
	else
		self.screen = "home"
	end
	self:onOpenPending()
end

function GNPhoneDialog:onOpenPending()
	if P.pendingContact ~= nil and GN.Client.call == nil then
		self.screen = "contacts"
		self.contactIndex = P.pendingContact
		self.greetingNid = P.pendingGreeting
		self.greetingLine = math.random(1, 3)
	else
		self.greetingNid = nil
	end
	P.pendingContact = nil
	P.pendingGreeting = nil
	self:refresh()
end

function GNPhoneDialog:onClose()
	self.isOpen = false
	-- a call that was not answered keeps ringing until it is answered or missed
	if GN.Client.call ~= nil and GN.Client.callState == "ringing" then
		GN.Client.startRing()
	end
	GNPhoneDialog:superClass().onClose(self)
end

--- Esc: one step back, or close.
function GNPhoneDialog:onClickBack()
	if self.screen == "contacts" or self.screen == "settings" then
		self.screen = "home"
		self:refresh()
		return false
	end
	if self.screen == "talk" then
		self:onClickDecline()
		return false
	end
	P.close()
	return false
end

-- ---------------------------------------------------------------------------
-- Drawing the screens
-- ---------------------------------------------------------------------------

local function vis(el, v)
	if el ~= nil and el.setVisible ~= nil then
		el:setVisible(v == true)
	end
end

local function txt(el, t)
	if el ~= nil and el.setText ~= nil then
		el:setText(t or "")
	end
end

function GNPhoneDialog:setWallpaper()
	local key = GN.Client.WALLPAPERS[GN.Client.personal.wallpaper] or "none"
	for w, id in pairs(P.WALLPAPER_IDS) do
		vis(self[id], w == key)
	end
	vis(self.shadeElement, key ~= "none")
end

function GNPhoneDialog:showPortrait(nid)
	for _, n in ipairs(GN.neighbours) do
		vis(self["portrait" .. n.id], n.id == nid)
	end
end

function GNPhoneDialog:setTexts(title, body, withPhoto)
	vis(self.titleTop, not withPhoto)
	vis(self.bodyTop, not withPhoto)
	vis(self.titleLow, withPhoto)
	vis(self.bodyLow, withPhoto)
	if withPhoto then
		txt(self.titleLow, title)
		txt(self.bodyLow, body)
	else
		txt(self.titleTop, title)
		txt(self.bodyTop, body)
	end
end

local ALL_BUTTONS = {
	"wallpaperButton", "volumeButton", "muteButton", "smsButton", "airplaneButton", "readButton", "callsButton", "fieldsButton",
	"answerButton", "acceptButton", "borrowButton", "declineButton", "labelLeft", "labelCenter", "labelRight",
	"contactsButton", "backButton", "closeButton", "settingsButton", "prevButton", "nextButton", "adminTitle", "homeButton", "outfitButton", "workButton", "parkingButton",
}

function GNPhoneDialog:showOnly(list)
	local on = {}
	for _, id in ipairs(list) do
		on[id] = true
	end
	for _, id in ipairs(ALL_BUTTONS) do
		vis(self[id], on[id] == true)
	end
end

local function neighbourName(nid)
	local n = GN.getNeighbour(nid)
	return n ~= nil and n.name or "?"
end

function GNPhoneDialog:refresh()
	self:setWallpaper()
	local C = GN.Client
	if C.call ~= nil and (self.screen == "ring" or self.screen == "talk" or self.screen == "home") then
		self.screen = C.callState == "talking" and "talk" or "ring"
	end
	if self.screen == "ring" then
		self:drawRing()
	elseif self.screen == "talk" then
		self:drawTalk()
	elseif self.screen == "contacts" then
		self:drawContacts()
	elseif self.screen == "settings" then
		self:drawSettings()
	else
		self:drawHome()
	end
end

function GNPhoneDialog:drawHome()
	self:showPortrait(nil)
	local C = GN.Client
	local lines = {}
	if C.personal.sms == false then
		table.insert(lines, GN.text("gn_sms_off"))
	end
	for _, e in ipairs(C.sms) do
		local name = neighbourName(e.nid)
		if e.kind == "missed" then
			table.insert(lines, string.format(GN.text("gn_sms_missed"), GN.formatClock(e.minute), name))
		elseif e.kind == "busy" then
			local nb = GN.getNeighbour(e.nid)
			local female = nb ~= nil and nb.gender == "female"
			table.insert(lines, name .. ":\n" .. GN.text(female and "gn_sms_busy_f" or "gn_sms_busy"))
		else
			table.insert(lines, name .. ":\n" .. GN.formatSmsBody(e))
		end
	end
	if #lines == 0 then
		table.insert(lines, GN.text("gn_sms_none"))
	end
	self:setTexts(GN.text("gn_title_messages"), table.concat(lines, "\n\n"), false)
	local buttons = { "contactsButton", "closeButton", "settingsButton" }
	if #C.sms > 0 then
		table.insert(buttons, "readButton")
		txt(self.readButton, string.format(GN.text("gn_sms_mark_read"), #C.sms))
	end
	self:showOnly(buttons)
end

function GN.formatSmsBody(e)
	local n = tonumber(e.fields) or 1
	local key
	if n == 1 then
		key = "gn_sms_body_one"
	elseif n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20) then
		key = "gn_sms_body_few"
	else
		key = "gn_sms_body_many"
	end
	return string.format(GN.text(key), GN.formatClock(e.minute), n)
end

function GNPhoneDialog:drawRing()
	local call = GN.Client.call
	self:showPortrait(call.nid)
	self:setTexts(neighbourName(call.nid), GN.text("gn_calling"), true)
	self:showOnly({ "answerButton", "declineButton" })
end

function GN.formatOffer(call)
	local lines = {}
	local opening = GN.text(string.format("gn_line_%s_%d", tostring(call.lines), tonumber(call.line) or 1), "")
	if opening ~= "" then
		table.insert(lines, opening)
		table.insert(lines, "")
	end
	for _, j in ipairs(call.jobs or {}) do
		table.insert(lines, string.format(GN.text("gn_offer_job"), tostring(j.field), GN.text("gn_job_" .. tostring(j.job)), tostring(j.ha), GN.formatMoney(j.reward)))
	end
	table.insert(lines, "")
	table.insert(lines, string.format(GN.text("gn_offer_total"), GN.formatMoney(call.total)))
	if (call.bonus or 0) > 0 then
		table.insert(lines, string.format(GN.text("gn_offer_bonus"), math.floor(call.bonus * 100 + 0.5), GN.formatMoney(call.bonusMoney)))
	end
	if call.supplies then
		table.insert(lines, GN.text("gn_offer_supplies"))
	end
	if call.lendName ~= nil then
		table.insert(lines, string.format(GN.text("gn_offer_lend"), tostring(call.lendName)))
	end
	return table.concat(lines, "\n")
end

function GNPhoneDialog:drawTalk()
	local call = GN.Client.call
	self:showPortrait(call.nid)
	self:setTexts(neighbourName(call.nid), GN.formatOffer(call), true)
	-- borrowing only when the neighbour has his own machine for this job (no leased machines)
	if call.lendName ~= nil then
		self:showOnly({ "acceptButton", "borrowButton", "declineButton", "labelLeft", "labelCenter", "labelRight" })
		txt(self.labelCenter, GN.text("gn_choice_borrow_own"))
	else
		self:showOnly({ "acceptButton", "declineButton", "labelLeft", "labelRight" })
	end
	txt(self.labelLeft, GN.text("gn_choice_accept"))
	txt(self.labelRight, GN.text("gn_choice_decline"))
end

function GN.formatBenefits(nid, level)
	local n = GN.getNeighbour(nid)
	if n == nil or not n.contracts then
		return GN.text("gn_benefits_none")
	end
	local S = GN.Server
	local pct = function(v) return math.floor(v * 100 + 0.5) end
	local bonus = math.min(S.PAY_BONUS_MAX, math.max(0, (level - 1) * S.PAY_BONUS_PER_LEVEL))
	local refund = math.min(S.LEASE_REFUND_MAX, math.max(0, (level - 1) * S.LEASE_REFUND_PER_LEVEL))
	local lines = {
		string.format(GN.text("gn_benefit_pay"), pct(bonus)),
	}
	if bonus < S.PAY_BONUS_MAX then
		table.insert(lines, string.format(GN.text("gn_benefit_next"), pct(math.min(S.PAY_BONUS_MAX, level * S.PAY_BONUS_PER_LEVEL))))
	end
	if GN.isMultiplayer() then
		table.insert(lines, GN.text("gn_benefit_calls"))
	end
	return table.concat(lines, "\n")
end

function GNPhoneDialog:drawContacts()
	local list = GN.neighbours
	if #list == 0 then
		self:drawHome()
		return
	end
	self.contactIndex = ((self.contactIndex - 1) % #list) + 1
	local n = list[self.contactIndex]
	local C = GN.Client
	local r = C.rel[n.id] or { level = 1, points = 0, need = GN.Server.pointsForNextLevel(1) }
	local lines = {}
	if self.greetingNid == n.id then
		table.insert(lines, "\"" .. GN.text("gn_greet_" .. tostring(self.greetingLine or 1)) .. "\"")
		table.insert(lines, "")
	end
	for _, l in ipairs({
		GN.text("gn_role_" .. n.role),
		"",
		string.format(GN.text("gn_contact_level"), r.level or 1, r.points or 0, r.need or 0),
	}) do
		table.insert(lines, l)
	end
	local fl = C.farmlands[n.id]
	if n.contracts and fl ~= nil and (fl.farmlands or 0) > 0 then
		table.insert(lines, string.format(GN.text("gn_contact_fields"), fl.farmlands, tostring(fl.ha)))
	end
	local cur = GN.Plan.current(n.id)
	if cur ~= nil then
		table.insert(lines, string.format(GN.text("gn_plan_now"), GN.text("gn_plan_" .. cur.key, cur.key)))
	end
	if n.contracts and C.workStart[n.id] ~= nil then
		table.insert(lines, string.format(GN.text("gn_plan_field_today"), GN.formatClock(C.workStart[n.id])))
	end
	table.insert(lines, "")
	table.insert(lines, GN.text("gn_benefits_title"))
	table.insert(lines, GN.formatBenefits(n.id, r.level or 1))
	table.insert(lines, "")
	table.insert(lines, GN.text("gn_plan_title"))
	table.insert(lines, GN.Plan.format(n.id))
	self:showPortrait(n.id)
	self:setTexts(n.name, table.concat(lines, "\n"), true)
	local buttons = { "backButton", "prevButton", "nextButton" }
	if GN.isLocalAdmin() then
		table.insert(buttons, "homeButton")
		txt(self.homeButton, GN.text("gn_set_home_here"))
		table.insert(buttons, "outfitButton")
		txt(self.outfitButton, GN.text("gn_set_outfit"))
		if n.contracts then
			table.insert(buttons, "parkingButton")
			txt(self.parkingButton, GN.text("gn_set_parking_here"))
		end
	end
	self:showOnly(buttons)
end

local function settingLabel(v)
	if tonumber(v) == -1 then
		return GN.text("gn_unlimited")
	end
	return tostring(v)
end

function GNPhoneDialog:drawSettings()
	self:showPortrait(nil)
	local C = GN.Client
	local p = C.personal
	local lines = {
		string.format(GN.text("gn_set_wallpaper"), GN.text("gn_wallpaper_" .. (C.WALLPAPERS[p.wallpaper] or "none"))),
		string.format(GN.text("gn_set_volume"), math.floor((C.VOLUMES[p.volume] or 0.7) * 100 + 0.5)),
		p.muted and GN.text("gn_set_muted") or GN.text("gn_set_sound_on"),
		p.sms ~= false and GN.text("gn_set_sms_on") or GN.text("gn_set_sms_off"),
	}
	local buttons = { "wallpaperButton", "volumeButton", "muteButton", "smsButton", "airplaneButton", "backButton" }
	-- airplane mode: for the whole farm, no more calls from the neighbours until it is turned off
	txt(self.airplaneButton, C.airplane and GN.text("gn_set_airplane_on") or GN.text("gn_set_airplane_off"))
	table.insert(lines, C.airplane and GN.text("gn_set_airplane_info_on") or GN.text("gn_set_airplane_info_off"))
	local admin = GN.isLocalAdmin()
	if admin then
		table.insert(buttons, "callsButton")
		table.insert(buttons, "fieldsButton")
		table.insert(buttons, "adminTitle")
		table.insert(buttons, "workButton")
		txt(self.workButton, C.settings.npcWork ~= false and GN.text("gn_set_work_on") or GN.text("gn_set_work_off"))
		txt(self.adminTitle, GN.text("gn_set_admin_title"))
		txt(self.callsButton, string.format(GN.text("gn_set_calls"), settingLabel(C.settings.callsPerDay)))
		txt(self.fieldsButton, string.format(GN.text("gn_set_fields"), settingLabel(C.settings.fieldsPerCall)))
	end
	self:setTexts(GN.text("gn_title_settings"), table.concat(lines, "\n"), false)
	self:showOnly(buttons)
end

-- ---------------------------------------------------------------------------
-- Buttons
-- ---------------------------------------------------------------------------

function GNPhoneDialog:onClickClose()
	P.close()
end

function GNPhoneDialog:onClickContacts()
	self.screen = "contacts"
	self:refresh()
end

function GNPhoneDialog:onClickSettings()
	self.screen = "settings"
	self:refresh()
end

function GNPhoneDialog:onClickBackButton()
	self.screen = "home"
	self:refresh()
end

function GNPhoneDialog:onClickHomeHere()
	local n = GN.neighbours[self.contactIndex]
	if n ~= nil and GN.isLocalAdmin() then
		GN.Client.setHomeHere(n.id)
	end
end

function GNPhoneDialog:onClickParkingHere()
	local n = GN.neighbours[self.contactIndex]
	if n ~= nil and GN.isLocalAdmin() then
		GN.Client.setParkingHere(n.id)
	end
end

function GNPhoneDialog:onClickOutfit()
	local n = GN.neighbours[self.contactIndex]
	if n ~= nil and GN.isLocalAdmin() then
		GN.Client.saveMyOutfitFor(n.id)
	end
end

function GNPhoneDialog:onClickPrev()
	self.greetingNid = nil
	self.contactIndex = self.contactIndex - 1
	self:refresh()
end

function GNPhoneDialog:onClickNext()
	self.greetingNid = nil
	self.contactIndex = self.contactIndex + 1
	self:refresh()
end

function GNPhoneDialog:onClickAnswer()
	GN.Client.answer()
	self.screen = "talk"
	self:refresh()
end

function GNPhoneDialog:onClickAccept()
	GN.Client.reply("accept")
	self.screen = "home"
	self:refresh()
end

function GNPhoneDialog:onClickBorrow()
	local call = GN.Client.call
	if call ~= nil and call.lendName == nil then
		return
	end
	GN.Client.reply("borrow")
	self.screen = "home"
	self:refresh()
end

function GNPhoneDialog:onClickDecline()
	if GN.Client.call ~= nil then
		GN.Client.reply("decline")
	end
	self.screen = "home"
	self:refresh()
end

function GNPhoneDialog:onClickWallpaper()
	local C = GN.Client
	C.personal.wallpaper = (C.personal.wallpaper % #C.WALLPAPERS) + 1
	C.savePersonal()
	self:refresh()
end

function GNPhoneDialog:onClickVolume()
	local C = GN.Client
	C.personal.volume = (C.personal.volume % #C.VOLUMES) + 1
	C.personal.muted = false
	C.savePersonal()
	C.playTone("sounds/sms.ogg")
	self:refresh()
end

function GNPhoneDialog:onClickMute()
	local C = GN.Client
	C.personal.muted = not C.personal.muted
	C.savePersonal()
	self:refresh()
end

function GNPhoneDialog:onClickRead()
	GN.Client.markAllRead()
end

function GNPhoneDialog:onClickAirplane()
	GN.sendToServer("airplane", { on = not GN.Client.airplane })
end

function GNPhoneDialog:onClickSms()
	local C = GN.Client
	C.personal.sms = C.personal.sms == false
	C.savePersonal()
	self:refresh()
end

local function nextIn(list, v)
	for i, x in ipairs(list) do
		if x == v then
			return list[(i % #list) + 1]
		end
	end
	return list[1]
end

function GNPhoneDialog:onClickCallsPerDay()
	if not GN.isLocalAdmin() then
		return
	end
	GN.Client.setAdminSetting("callsPerDay", nextIn(GN.Server.CALLS_PER_DAY_VALUES, tonumber(GN.Client.settings.callsPerDay)))
end

function GNPhoneDialog:onClickNpcWork()
	if not GN.isLocalAdmin() then
		return
	end
	GN.Client.setAdminSetting("npcWork", GN.Client.settings.npcWork == false)
end

function GNPhoneDialog:onClickFieldsPerCall()
	if not GN.isLocalAdmin() then
		return
	end
	GN.Client.setAdminSetting("fieldsPerCall", nextIn(GN.Server.FIELDS_PER_CALL_VALUES, tonumber(GN.Client.settings.fieldsPerCall)))
end
