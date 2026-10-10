-- Good Neighbours (FS25) - client side: state from the server, phone ringing, messages, personal settings
-- Runs where a player sees the game (singleplayer, host, multiplayer client).
-- Author: billiD

local GN = GoodNeighbours

GN.Client = GN.Client or {}
local C = GN.Client

C.WALLPAPERS = { "none", "deere", "claas", "silage", "krone" }
C.VOLUMES = { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0 }

function C.reset()
	C.synced = false
	C.helloTimer = 0
	C.helloSent = false
	C.rel = {}          -- nid -> { level, points, need }
	C.farmlands = {}    -- nid -> { farmlands, ha }
	C.settings = { callsPerDay = 3, fieldsPerCall = 3, npcWork = true }
	C.workStart = {}
	C.sms = {}          -- today's messages: { nid, minute, fields } or { nid, minute, kind = "missed"/"thanks"/... }
	C.day = nil
	C.call = nil        -- incoming call info from the server
	C.callState = nil   -- "ringing" / "talking"
	C.admin = false
	C.homes = {}
	C.parking = {}
	C.slots = {}
	C.places = {}
	C.need = {}
	C.styles = {}
	C.ringSample = nil
	C.personal = C.personal or { wallpaper = 2, volume = 7, muted = false, sms = true }
end

-- ---------------------------------------------------------------------------
-- Personal settings (modSettings/FS25_GoodNeighbours/settings.xml, per computer)
-- ---------------------------------------------------------------------------

local function personalPath()
	local dir = (g_modSettingsDirectory or "") .. "FS25_GoodNeighbours/"
	if folderExists ~= nil and not folderExists(dir) and createFolder ~= nil then
		createFolder(dir)
	end
	return dir .. "settings.xml"
end

function C.loadPersonal()
	local path = personalPath()
	if not fileExists(path) then
		return
	end
	local xml = loadXMLFile("gnSettings", path)
	if xml == nil or xml == 0 then
		return
	end
	local p = C.personal
	p.wallpaper = getXMLInt(xml, "settings.phone#wallpaper") or p.wallpaper
	p.volume = getXMLInt(xml, "settings.phone#volume") or p.volume
	local m = getXMLBool(xml, "settings.phone#muted")
	if m ~= nil then p.muted = m end
	local s = getXMLBool(xml, "settings.phone#sms")
	if s ~= nil then p.sms = s end
	p.seen = {}
	for id in string.gmatch(getXMLString(xml, "settings.talk#seen") or "", "[^,]+") do
		table.insert(p.seen, id)
	end
	delete(xml)
	p.wallpaper = math.max(1, math.min(#C.WALLPAPERS, p.wallpaper))
	p.volume = math.max(1, math.min(#C.VOLUMES, p.volume))
end

function C.savePersonal()
	local xml = createXMLFile("gnSettings", personalPath(), "settings")
	if xml == nil or xml == 0 then
		return
	end
	local p = C.personal
	setXMLInt(xml, "settings.phone#wallpaper", p.wallpaper)
	setXMLInt(xml, "settings.phone#volume", p.volume)
	setXMLBool(xml, "settings.phone#muted", p.muted == true)
	setXMLBool(xml, "settings.phone#sms", p.sms ~= false)
	setXMLString(xml, "settings.talk#seen", table.concat(p.seen or {}, ","))
	saveXMLFile(xml)
	delete(xml)
end

function C.getVolume()
	if C.personal.muted then
		return 0
	end
	return C.VOLUMES[C.personal.volume] or 0.7
end

-- ---------------------------------------------------------------------------
-- Sounds
-- ---------------------------------------------------------------------------

local function newSample(name, rel)
	local file = Utils.getFilename(rel, GN.dir)
	if file == nil or not fileExists(file) then
		return nil
	end
	local sample = createSample(name)
	if sample ~= nil and sample ~= 0 and loadSample(sample, file, false) then
		return sample
	end
	if sample ~= nil and sample ~= 0 then
		delete(sample)
	end
	return nil
end

function C.playTone(rel)
	local vol = C.getVolume()
	if vol <= 0 then
		return
	end
	if C.toneSample ~= nil then
		delete(C.toneSample)
		C.toneSample = nil
	end
	C.toneSample = newSample("gnTone", rel)
	if C.toneSample ~= nil then
		playSample(C.toneSample, 1, vol, 0, 0, 0)
	end
end

function C.startRing()
	C.stopRing()
	local vol = C.getVolume()
	if vol <= 0 then
		return
	end
	C.ringSample = newSample("gnRing", "sounds/ring.ogg")
	if C.ringSample ~= nil then
		playSample(C.ringSample, 0, vol, 0, 0, 0) -- 0 = loop until stopped
	end
end

function C.stopRing()
	if C.ringSample ~= nil then
		stopSample(C.ringSample, 0, 0)
		delete(C.ringSample)
		C.ringSample = nil
	end
end

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------

function C.notify(text, kind)
	if g_currentMission == nil or g_currentMission.addIngameNotification == nil or FSBaseMission == nil then
		return
	end
	local t = FSBaseMission.INGAME_NOTIFICATION_INFO
	if kind == "ok" then
		t = FSBaseMission.INGAME_NOTIFICATION_OK or t
	elseif kind == "bad" then
		t = FSBaseMission.INGAME_NOTIFICATION_CRITICAL or t
	end
	g_currentMission:addIngameNotification(t, text)
end

local function M_key()
	return GN.Main ~= nil and GN.Main.getPhoneKeyText ~= nil and GN.Main.getPhoneKeyText() or "Shift+N"
end

local function nname(nid)
	local n = GN.getNeighbour(nid)
	return n ~= nil and n.name or "?"
end

local function smsKey(e)
	return table.concat({ tostring(e.day), tostring(e.nid), tostring(e.minute), tostring(e.kind) }, "|")
end

--- Messages the player marked as read do not come back (also not with the next sync).
C.readSms = C.readSms or {}
function C.markAllRead()
	for _, e in ipairs(C.sms) do
		C.readSms[smsKey(e)] = true
	end
	C.sms = {}
	GN.Phone.refreshIfOpen()
end

local function addMessage(e)
	if C.personal.sms == false or C.readSms[smsKey(e)] then
		return
	end
	table.insert(C.sms, e)
	table.sort(C.sms, function(a, b) return (a.minute or 0) < (b.minute or 0) end)
	GN.Phone.refreshIfOpen()
end

-- ---------------------------------------------------------------------------
-- Messages from the server
-- ---------------------------------------------------------------------------

function C.onMessage(kind, data)
	if kind == "sync" then
		C.synced = true
		C.admin = data.admin == true
		C.settings = data.settings or C.settings
		C.airplane = data.airplane == true
		C.day = data.day
		C.rel = {}
		for _, r in ipairs(data.rel or {}) do
			C.rel[r.nid] = r
		end
		for _, n in ipairs(data.neighbours or {}) do
			C.farmlands[n.id] = n
		end
		C.sms = {}
		for _, e in ipairs(data.sms or {}) do
			addMessage(e)
		end
		C.homes = data.homes or {}
		C.parking = data.parking or {}
		C.slots = data.slots or {}
		C.places = data.places or {}
		C.need = data.need or {}
		C.setWorkStart(data.workStart)
		C.styles = C.numberKeys(data.styles)
		if g_server == nil then
			local assign = {}
			for _, e in ipairs(data.assign or {}) do
				assign[e.fl] = e.nid
			end
			C.assign = assign
			GN.safeCall("field owners", GN.World.applyFarmlandNpcs, assign)
		end
		GN.safeCall("map icons", GN.MapIcons.update, C.homes)
		GN.safeCall("characters", GN.Characters.sync, C.homes, C.styles)
		if data.call ~= nil then
			C.onMessage("call", data.call)
		end
		GN.Phone.refreshIfOpen()
	elseif kind == "sms" then
		if C.day ~= data.day then
			C.sms = {}
			C.day = data.day
		end
		addMessage(data)
		if C.personal.sms ~= false then
			C.playTone("sounds/sms.ogg")
			C.notify(string.format(GN.text("gn_notify_sms"), nname(data.nid)))
		end
	elseif kind == "call" then
		C.call = data
		C.callState = "ringing"
		C.startRing()
		C.notify(string.format(GN.text("gn_notify_call"), nname(data.nid), GN.Main.getPhoneKeyText()))
		GN.Phone.refreshIfOpen()
	elseif kind == "callEnd" then
		if C.call ~= nil and C.call.callId == data.callId then
			if C.callState == "talking" or C.callState == "answered" then
				C.playTone("sounds/hangup.ogg")
			end
			if data.reason == "taken" and C.callState == "ringing" then
				C.notify(string.format(GN.text("gn_notify_taken"), nname(C.call.nid)))
			end
			C.call = nil
			C.callState = nil
			C.stopRing()
			GN.Phone.onCallEnded()
		end
	elseif kind == "airplane" then
		C.airplane = data.on == true
		C.notify(C.airplane and GN.text("gn_notify_airplane_on") or GN.text("gn_notify_airplane_off"))
		GN.Phone.refreshIfOpen()
	elseif kind == "callTaken" then
		-- another player of the farm picked up: this phone stops ringing at once
		if C.call ~= nil and C.call.callId == data.callId and C.callState == "ringing" then
			C.stopRing()
			C.notify(string.format(GN.text("gn_notify_taken"), nname(C.call.nid)))
			C.call = nil
			C.callState = nil
			GN.Phone.onCallEnded()
		end
	elseif kind == "talkResult" then
		GN.Talk.onResult(data)
	elseif kind == "smsClear" then
		for i = #C.sms, 1, -1 do
			if C.sms[i].nid == data.nid and C.sms[i].kind == nil then
				table.remove(C.sms, i)
			end
		end
		GN.Phone.refreshIfOpen()
	elseif kind == "missed" then
		C.stopRing()
		addMessage({ nid = data.nid, minute = data.minute, kind = "missed", day = C.day })
		C.notify(string.format(GN.text("gn_notify_missed"), nname(data.nid)), "bad")
	elseif kind == "accepted" then
		if (data.started or 0) > 0 then
			C.notify(string.format(GN.text("gn_notify_accepted"), data.started, nname(data.nid)), "ok")
			if data.days ~= nil then
				C.notify(string.format(GN.text("gn_notify_deadline"), data.days), "info")
			end
		end
		if (data.failed or 0) > 0 then
			C.notify(string.format(GN.text("gn_notify_not_started"), data.failed), "bad")
		end
	elseif kind == "thanks" then
		local text = string.format(GN.text("gn_notify_thanks"), nname(data.nid), data.points or 0)
		if (data.bonus or 0) + (data.refund or 0) > 0 then
			text = text .. " " .. string.format(GN.text("gn_notify_bonus"), GN.formatMoney((data.bonus or 0) + (data.refund or 0)))
		end
		C.notify(text, "ok")
		C.playTone("sounds/success.ogg")
	elseif kind == "failed" then
		C.notify(string.format(GN.text("gn_notify_failed"), nname(data.nid)), "bad")
		C.playTone("sounds/failed.ogg")
	elseif kind == "rel" then
		C.rel[data.nid] = data
		if data.levelUp then
			C.notify(string.format(GN.text("gn_notify_levelup"), nname(data.nid), data.level), "ok")
			C.playTone("sounds/levelup.ogg")
		end
		GN.Phone.refreshIfOpen()
	elseif kind == "borrowStage" then
		GN.Borrow.clientOnStage(data)
	elseif kind == "borrowThanks" then
		C.notify(string.format(GN.text("gn_notify_borrow_thanks"), nname(data.nid)), "ok")
		C.playTone("sounds/success.ogg")
	elseif kind == "borrowLate" then
		C.notify(string.format(GN.text("gn_notify_borrow_late"), nname(data.nid)), "bad")
		C.playTone("sounds/failed.ogg")
	elseif kind == "supplied" then
		C.notify(string.format(GN.text("gn_notify_supplied"), nname(data.nid), tostring(data.vehicle)), "ok")
	elseif kind == "workPlan" then
		C.setWorkStart(data.workStart)
		GN.Phone.refreshIfOpen()
	elseif kind == "toolPlaced" then
		if data.action == "home" and data.size ~= nil and data.size ~= "home" then
			local text = string.format(GN.text("gn_notify_slot_set"), nname(data.nid), GN.text("gn_size_" .. tostring(data.size)), data.count or 0, data.need or 0)
			if data.overlap then
				text = text .. " " .. GN.text("gn_notify_slot_overlap")
				C.notify(text, "bad")
			else
				C.notify(text, "ok")
			end
			GN.Tools.flash(text)
		elseif data.action == "home" then
			C.notify(string.format(GN.text("gn_notify_home_set"), nname(data.nid)), "ok")
			GN.Tools.flash(string.format(GN.text("gn_notify_home_set"), nname(data.nid)))
		elseif data.action == "auto" then
			GN.Tools.flash(GN.text("gn_tool_auto_started"))
		elseif data.action == "bulk" then
			local text = string.format(GN.text("gn_notify_bulk_removed"), data.count or 0)
			C.notify(text, "ok")
			GN.Tools.flash(text)
		elseif data.action == "parking" then
			C.notify(string.format(GN.text("gn_notify_parking_set"), nname(data.nid)), "ok")
		elseif data.action == "slot" then
			C.notify(string.format(GN.text("gn_notify_slot_set"), nname(data.nid), data.count or 0, data.need or 0), "ok")
		elseif data.action == "remove" then
			local text = data.what == "none" and GN.text("gn_notify_removed_none") or GN.text("gn_notify_removed")
			C.notify(text)
			GN.Tools.flash(text)
		else
			C.notify(string.format(GN.text("gn_notify_place_set"), GN.text("gn_place_" .. string.sub(tostring(data.action), 7))), "ok")
		end
	elseif kind == "homes" then
		C.homes = data.homes or {}
		C.parking = data.parking or C.parking or {}
		C.slots = data.slots or C.slots or {}
		C.places = data.places or C.places or {}
		C.need = data.need or C.need or {}
		GN.safeCall("map icons", GN.MapIcons.update, C.homes)
		GN.safeCall("characters", GN.Characters.sync, C.homes, C.styles)
	elseif kind == "supplyReady" then
		C.notify(string.format(GN.text("gn_notify_supply_ready"), nname(data.nid), GN.text("gn_fill_" .. tostring(data.fillType), tostring(data.fillType)), data.amount or 0), "ok")
	elseif kind == "assign" then
		local assign = {}
		for _, e in ipairs(data.assign or {}) do
			assign[e.fl] = e.nid
		end
		-- farmlands no longer his: back to no neighbour
		if g_farmlandManager ~= nil and C.assign ~= nil then
			for fl in pairs(C.assign) do
				if assign[fl] == nil then
					local f = g_farmlandManager:getFarmlandById(fl)
					if f ~= nil then
						f.npcIndex = f.gnOrigNpcIndex or f.npcIndex
					end
				end
			end
		end
		C.assign = assign
		GN.safeCall("field owners", GN.World.applyFarmlandNpcs, assign)
	elseif kind == "visitor" then
		C.notify(string.format(GN.text("gn_notify_visitor"), nname(data.nid), M_key()), "ok")
	elseif kind == "styles" then
		C.styles = C.numberKeys(data.styles)
		GN.safeCall("characters", GN.Characters.sync, C.homes, C.styles)
		GN.Phone.refreshIfOpen()
	elseif kind == "lent" then
		C.notify(string.format(GN.text("gn_notify_lent"), nname(data.nid), tostring(data.vehicle)), "ok")
	elseif kind == "returned" then
		C.notify(string.format(GN.text("gn_notify_returned"), tostring(data.vehicle), nname(data.nid)))
	elseif kind == "driver" then
		GN.Work.clientOnMessage(data)
	elseif kind == "settings" then
		C.settings = data
		GN.Phone.refreshIfOpen()
		GN.safeCall("settings menu", GN.SettingsMenu.refresh)
	end
end

-- ---------------------------------------------------------------------------
-- Player actions
-- ---------------------------------------------------------------------------

function C.answer()
	if C.call == nil or C.callState ~= "ringing" then
		return
	end
	C.callState = "talking"
	C.stopRing()
	GN.sendToServer("answer", { callId = C.call.callId })
end

function C.reply(choice)
	if C.call == nil then
		return
	end
	if C.callState == "ringing" then
		C.answer()
	end
	GN.sendToServer("reply", { callId = C.call.callId, choice = choice })
	C.call = nil
	C.callState = nil
end

function C.setWorkStart(list)
	C.workStart = {}
	for _, e in ipairs(list or {}) do
		C.workStart[tonumber(e.nid)] = e.minute
	end
end

function C.numberKeys(t)
	local out = {}
	for k, v in pairs(t or {}) do
		local n = tonumber(k)
		if n ~= nil then
			out[n] = v
		end
	end
	return out
end

--- Admin: the neighbour wears what the local player wears now.
function C.saveMyOutfitFor(nid)
	local outfit = GN.Characters.captureLocalStyle()
	if outfit == nil then
		C.notify(GN.text("gn_notify_outfit_failed"), "bad")
		return
	end
	GN.sendToServer("setStyle", { nid = nid, outfit = outfit })
	C.notify(string.format(GN.text("gn_notify_outfit_saved"), GN.getNeighbour(nid).name), "ok")
end

--- Position and facing (camera direction) of the local player, or nil.
function C.getPlayerPose()
	local player = g_localPlayer
	if player == nil then
		return nil
	end
	local x, z
	local vehicle
	if player.getCurrentVehicle ~= nil then
		local ok, v = GN.try(player.getCurrentVehicle, player)
		vehicle = ok and v or nil
	end
	if vehicle ~= nil and vehicle.rootNode ~= nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
	elseif player.getPosition ~= nil then
		local ok, px, _, pz = GN.try(player.getPosition, player)
		if ok then
			x, z = px, pz
		end
	end
	if x == nil then
		return nil
	end
	local ry = 0
	local cam = getCamera ~= nil and getCamera() or nil
	if cam ~= nil and cam ~= 0 then
		local dx, _, dz = localDirectionToWorld(cam, 0, 0, -1)
		ry = (math.atan2 or math.atan)(dx, dz)
	end
	return x, z, ry
end

--- Admin: the neighbour parks his machines here, in a row to the right, facing where the player looks.
function C.setParkingHere(nid)
	local x, z, ry = C.getPlayerPose()
	if x == nil then
		return
	end
	GN.sendToServer("setParking", { nid = nid, x = x, z = z, ry = ry })
	C.notify(string.format(GN.text("gn_notify_parking_set"), GN.getNeighbour(nid).name), "ok")
end

--- Admin: the neighbour lives where the local player stands now.
function C.setHomeHere(nid)
	local player = g_localPlayer
	if player == nil then
		return
	end
	local x, z
	local vehicle
	if player.getCurrentVehicle ~= nil then
		local ok, v = GN.try(player.getCurrentVehicle, player)
		vehicle = ok and v or nil
	end
	if vehicle ~= nil and vehicle.rootNode ~= nil then
		local vx, _, vz = getWorldTranslation(vehicle.rootNode)
		x, z = vx, vz
	elseif player.getPosition ~= nil then
		local ok, px, _, pz = GN.try(player.getPosition, player)
		if ok then
			x, z = px, pz
		end
	end
	if x == nil or z == nil then
		return
	end
	GN.sendToServer("setHome", { nid = nid, x = x, z = z })
	C.notify(string.format(GN.text("gn_notify_home_set"), GN.getNeighbour(nid).name), "ok")
end

function C.setAdminSetting(key, value)
	local s = { callsPerDay = C.settings.callsPerDay, fieldsPerCall = C.settings.fieldsPerCall, npcWork = C.settings.npcWork ~= false }
	s[key] = value
	GN.sendToServer("setSettings", s)
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------

function C.update(dt)
	if not C.helloSent then
		if g_currentMission ~= nil and g_currentMission.isMissionStarted ~= false and g_localPlayer ~= nil then
			C.helloTimer = C.helloTimer + (dt or 0)
			if C.helloTimer > 3000 then
				C.helloSent = true
				GN.sendToServer("hello", {})
			end
		end
	end
	-- the farm of the local player changed (joined a farm): ask for the data again
	local farmId = GN.getLocalFarmId()
	if C.helloSent and farmId ~= C.lastFarmId then
		if C.lastFarmId ~= nil then
			GN.sendToServer("hello", {})
		end
		C.lastFarmId = farmId
	end
end

C.reset()
