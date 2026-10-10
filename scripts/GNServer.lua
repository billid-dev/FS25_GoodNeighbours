-- Good Neighbours (FS25) - server side: fields of the neighbours, daily calls, contracts, relationships
-- Runs on the server only (singleplayer, host or dedicated server).
-- Author: billiD

local GN = GoodNeighbours

GN.Server = GN.Server or {}
local S = GN.Server

S.SAVE_FILE = "goodNeighbours.xml"

-- tuning
S.CALL_FIRST_MINUTE = 6 * 60 + 30   -- neighbours call in the morning, before they drive out
S.CALL_LAST_MINUTE = 10 * 60 + 30
S.RING_SECONDS = 45            -- real seconds a call rings before it is missed
S.TALK_SECONDS = 180           -- real seconds to choose an option after answering
S.PAUSE_BETWEEN_CALLS = 60     -- real seconds between two calls
S.RETRY_MINUTES = 30           -- in-game minutes before a neighbour tries again after a missed call
S.MAX_ATTEMPTS = 2             -- second missed call: "I see you are busy, I will do it myself" (SMS)

S.PAY_BONUS_PER_LEVEL = 0.05
S.PAY_BONUS_MAX = 0.30
S.LEASE_REFUND_PER_LEVEL = 0.10
S.LEASE_REFUND_MAX = 0.50

S.CALLS_PER_DAY_VALUES = { 0, 1, 2, 3, 4, 6, -1 }   -- -1 = no limit

-- contractor pay per hectare (common FS25 contractor rates), scaled by the economic difficulty:
-- easy x1.2, normal x1.1, hard x1.0; a neighbour never pays less than the game's own contract reward
S.RATE_PER_HA = {
	plow = 2800, cultivate = 2300, sow = 2000, fertilize = 1500, spray = 1500, weed = 1500, harvest = 2500,
	mow = 2500, tedd = 1200, roll = 1200, stones = 2200, lime = 1500, mulch = 2000, harrow = 1800,
}
S.FIELDS_PER_CALL_VALUES = { 1, 2, 3, 4, 5 }

function S.reset()
	S.loaded = false
	S.assign = {}          -- farmlandId -> neighbour id
	S.home = {}            -- neighbour id -> { x, z }
	S.styles = {}          -- neighbour id -> { [config] = { item, color } }
	S.parking = {}         -- neighbour id -> { x, z, ry } first parking slot of his machines (row)
	S.slots = {}           -- neighbour id -> list of { x, z, ry, size }: machine / silo places (construction tool)
	S.toolSize = {}        -- farmId -> size chosen for the neighbour tool in the construction menu
	S.farmBuildings = {}   -- nid -> { silo = id, shed = id } buildings put up for him
	S.buildingAreas = {}   -- { x, z, ry, len, side } ground taken by those buildings
	S.places = {}          -- list of { type, x, z, ry }: places in the world the neighbours visit
	S.rel = {}             -- farmId -> { [nid] = { level, points } }
	S.settings = { callsPerDay = 3, fieldsPerCall = 3, npcWork = true }
	S.airplane = {}        -- farmId -> true: airplane mode, no calls
	S.workStart = {}       -- nid -> minute of the day the neighbour starts field work today (changes every day)
	S.reserved = {}        -- nid -> { [mission] = true } contracts kept free for today's phone call
	S.talked = {}          -- "farm|nid" -> day: a chat face to face counts once per day
	S.day = nil
	S.plans = {}           -- nid -> { minute, smsSent, done, attempts }
	S.callsToday = {}      -- farmId -> number
	S.sms = {}             -- list of { nid, minute, fields } for today
	S.call = nil
	S.lastCallEnd = -1e9
	S.tracked = {}         -- list of { mission, nid, farmId, bonus, refund, fieldId }
	S.pendingTracked = {}  -- from the savegame, matched to running missions after loading
	S.callSeq = 0
	S.timer = 0
end

-- ---------------------------------------------------------------------------
-- Fields and missions
-- ---------------------------------------------------------------------------

local function fieldFarmlandId(field)
	if field == nil then
		return nil
	end
	if field.farmland ~= nil then
		return field.farmland.id
	end
	if field.getFarmlandId ~= nil then
		local ok, id = GN.try(field.getFarmlandId, field)
		if ok then
			return id
		end
	end
	return nil
end

local function fieldId(field)
	if field == nil then
		return nil
	end
	if field.getId ~= nil then
		local ok, id = GN.try(field.getId, field)
		if ok and id ~= nil then
			return id
		end
	end
	return field.fieldId
end

local function fieldArea(field)
	if field ~= nil and field.getAreaHa ~= nil then
		local ok, a = GN.try(field.getAreaHa, field)
		if ok and a ~= nil then
			return a
		end
	end
	return 0
end

local function fieldPos(field)
	if field == nil then
		return nil
	end
	if field.getCenterOfFieldWorldPosition ~= nil then
		local ok, x, z = GN.try(field.getCenterOfFieldWorldPosition, field)
		if ok and x ~= nil and z ~= nil then
			return x, z
		end
	end
	return field.posX, field.posZ
end

local function farmlandOwner(farmlandId)
	if g_farmlandManager == nil or farmlandId == nil then
		return nil
	end
	return g_farmlandManager:getFarmlandOwner(farmlandId)
end

local function isNpcFarmland(farmlandId)
	local owner = farmlandOwner(farmlandId)
	return owner == nil or owner == 0 or (FarmlandManager ~= nil and owner == FarmlandManager.NO_OWNER_FARM_ID)
		or (GN.Work ~= nil and owner == GN.Work.NPC_FARM_ID) -- a neighbour works it right now
end

--- Every field nobody owns belongs to one of the farming neighbours: new free land (sold by a player,
--- not handed out yet) goes to the nearest neighbour with the fewest fields; land a player bought leaves.
function S.refreshAssign()
	local farmers = {}
	for _, n in ipairs(GN.neighbours) do
		if n.contracts and S.home[n.id] ~= nil then
			table.insert(farmers, n)
		end
	end
	if #farmers == 0 or g_fieldManager == nil then
		return
	end
	local count, changed = {}, false
	for fl, nid in pairs(S.assign) do
		if not isNpcFarmland(fl) then
			S.assign[fl] = nil
			changed = true
			local f = g_farmlandManager:getFarmlandById(fl)
			if f ~= nil then
				f.npcIndex = f.gnOrigNpcIndex or f.npcIndex
			end
		else
			count[nid] = (count[nid] or 0) + 1
		end
	end
	local total, assigned = 0, 0
	local seen = {}
	for _, field in pairs(g_fieldManager:getFields() or {}) do
		local fl = fieldFarmlandId(field)
		if fl ~= nil and not seen[fl] and isNpcFarmland(fl) then
			seen[fl] = true
			total = total + 1
			if S.assign[fl] == nil then
				local x, z = fieldPos(field)
				if x ~= nil then
					-- nearest neighbour, but the one with clearly fewer fields wins
					local best, bestScore = nil, math.huge
					for _, n in ipairs(farmers) do
						local h = S.home[n.id]
						local d = math.sqrt((h.x - x) ^ 2 + (h.z - z) ^ 2)
						local score = d + (count[n.id] or 0) * 60
						if score < bestScore then
							best, bestScore = n, score
						end
					end
					S.assign[fl] = best.id
					count[best.id] = (count[best.id] or 0) + 1
					changed = true
				end
			end
			if S.assign[fl] ~= nil then
				assigned = assigned + 1
			end
		end
	end
	if changed then
		local _, c = GN.safeCall("field owners", GN.World.applyFarmlandNpcs, S.assign)
		GN.log("field owners updated: %d of %d free farmlands with fields belong to a neighbour (%s shown)", assigned, total, tostring(c))
		GN.sendToAll("assign", { assign = S.assignList() })
	end
end

--- Job of a vanilla mission as a short key (used for texts).
function S.missionJob(mission)
	local name = ""
	if mission ~= nil and mission.type ~= nil and mission.type.name ~= nil then
		name = string.lower(tostring(mission.type.name))
	end
	local map = {
		{ "harvest", "harvest" }, { "plow", "plow" }, { "cultivat", "cultivate" }, { "sow", "sow" },
		{ "fertiliz", "fertilize" }, { "herbicide", "spray" }, { "spray", "spray" }, { "weed", "weed" },
		{ "hoe", "weed" }, { "mow", "mow" }, { "tedd", "tedd" }, { "baleWrap", "wrap" }, { "bale", "bale" },
		{ "roll", "roll" }, { "stone", "stones" }, { "lime", "lime" }, { "mulch", "mulch" },
	}
	for _, e in ipairs(map) do
		if string.find(name, string.lower(e[1]), 1, true) then
			return e[2]
		end
	end
	return "fieldwork"
end

local function missionReward(mission)
	if mission.getReward ~= nil then
		local ok, r = GN.try(mission.getReward, mission)
		if ok and tonumber(r) ~= nil then
			return tonumber(r)
		end
	end
	return tonumber(mission.reward) or 0
end

local function missionLeaseCost(mission)
	for _, fn in ipairs({ "getVehicleCosts", "getVehicleCost" }) do
		if mission[fn] ~= nil then
			local ok, c = GN.try(mission[fn], mission)
			if ok and tonumber(c) ~= nil then
				return tonumber(c)
			end
		end
	end
	return tonumber(mission.vehicleUseCost) or 0
end

--- Economic difficulty multiplier, the same as the Invoices mod (and the game's contracts): 1.3 - 0.1 * difficulty.
function S.difficultyFactor()
	local d = 2
	if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
		d = tonumber(g_currentMission.missionInfo.economicDifficulty) or 2
	end
	return 1.3 - 0.1 * d
end

-- prices per hectare of the Invoices mod (FS25_Invoices, work types), by crop where it lists one
S.INVOICE_HARVEST = {
	POTATO = 3400, SUGARBEET = 3400, SUGARCANE = 4500, COTTON = 3200, GRAPE = 3000, OLIVE = 3400, RICE = 3600,
	LONGGRAINRICE = 3600, SPINACH = 3400, PEA = 3400, PEAS = 3400, GREENBEAN = 3400, GREENBEANS = 3400,
	ONION = 3400, CARROT = 3400, PARSNIP = 3400, RED_BEET = 3400, REDBEET = 3400, BEETROOT = 3400,
}
S.INVOICE_SOW = {
	POTATO = 2800, SUGARCANE = 2800, RICE = 2200, LONGGRAINRICE = 2200,
	SUGARBEET = 2400, CARROT = 2400, PARSNIP = 2400, RED_BEET = 2400, REDBEET = 2400, BEETROOT = 2400, ONION = 2400,
}

local function fruitName(index)
	if index == nil or g_fruitTypeManager == nil then
		return nil
	end
	local f = g_fruitTypeManager:getFruitTypeByIndex(index)
	return f ~= nil and f.name ~= nil and string.upper(f.name) or nil
end

--- Price per hectare of the job of a contract, as in the Invoices mod.
function S.invoiceRate(m)
	local job = S.missionJob(m)
	local rate = S.RATE_PER_HA[job]
	if job == "harvest" then
		local fs = m.field ~= nil and m.field.fieldState or nil
		local name = fruitName(fs ~= nil and fs.fruitTypeIndex or nil)
		rate = (name ~= nil and S.INVOICE_HARVEST[name]) or rate
	elseif job == "sow" then
		local fi = m.fruitTypeIndex or m.fruitType
		if type(fi) == "table" then
			fi = fi.index
		end
		local name = fruitName(fi)
		rate = (name ~= nil and S.INVOICE_SOW[name]) or rate
	end
	return rate
end

--- What the neighbour pays for a contract (before the relationship bonus): the Invoices mod price,
--- hectares x price per hectare x difficulty.
function S.contractPay(m)
	local rate = S.invoiceRate(m)
	if rate == nil then
		return missionReward(m)
	end
	return math.floor(rate * fieldArea(m.field) * S.difficultyFactor() + 0.5)
end

local function isOpenMission(m)
	if m == nil or m.field == nil or m.farmId ~= nil and m.farmId ~= 0 then
		return false
	end
	if MissionStatus ~= nil and m.status ~= nil and m.status ~= MissionStatus.CREATED then
		return false
	end
	return true
end

--- Open vanilla field contracts on the fields of a neighbour, best paid first.
function S.getOpenMissions(nid)
	local out = {}
	for _, m in ipairs(g_missionManager ~= nil and g_missionManager.missions or {}) do
		if isOpenMission(m) then
			local fl = fieldFarmlandId(m.field)
			if fl ~= nil and S.assign[fl] == nid and isNpcFarmland(fl) then
				table.insert(out, m)
			end
		end
	end
	table.sort(out, function(a, b)
		return missionReward(a) > missionReward(b)
	end)
	return out
end

-- ---------------------------------------------------------------------------
-- Which fields belong to which neighbour
-- ---------------------------------------------------------------------------

--- Splits the NPC farmlands of the map between the farming neighbours (done once per savegame).
function S.assignFarmlands()
	local farmers = {}
	for _, n in ipairs(GN.neighbours) do
		if n.contracts then
			table.insert(farmers, n)
		end
	end
	if #farmers == 0 or g_fieldManager == nil then
		return
	end
	local lands = {}
	local seen = {}
	for _, field in pairs(g_fieldManager:getFields() or {}) do
		local fl = fieldFarmlandId(field)
		local x, z = fieldPos(field)
		if fl ~= nil and x ~= nil and isNpcFarmland(fl) then
			if seen[fl] == nil then
				seen[fl] = { id = fl, x = x, z = z, area = 0 }
				table.insert(lands, seen[fl])
			end
			seen[fl].area = seen[fl].area + fieldArea(field)
		end
	end
	if #lands == 0 then
		GN.log("no NPC fields found on this map - neighbours have no fields")
		return
	end
	-- homes: set ones (map preset / construction tool) when every farmer has one, else spread over the map:
	-- start with the biggest farmland, then always the one farthest from the homes chosen so far
	table.sort(lands, function(a, b) return a.area > b.area end)
	local homes = {}
	local allSet = true
	for _, n in ipairs(farmers) do
		local h = S.home[n.id]
		if h == nil or h.auto then
			allSet = false
		end
	end
	if allSet then
		for _, n in ipairs(farmers) do
			table.insert(homes, { x = S.home[n.id].x, z = S.home[n.id].z, keep = true })
		end
	else
		homes = { lands[1] }
	end
	while #homes < math.min(#farmers, #lands) do
		local best, bestD = nil, -1
		for _, l in ipairs(lands) do
			local d = math.huge
			for _, h in ipairs(homes) do
				d = math.min(d, (l.x - h.x) ^ 2 + (l.z - h.z) ^ 2)
			end
			if d > bestD then
				best, bestD = l, d
			end
		end
		table.insert(homes, best)
	end
	S.assign = {}
	if not allSet then
		for i, h in ipairs(homes) do
			S.home[farmers[i].id] = { x = h.x, z = h.z, auto = true } -- field centre: moved to the yard by GN.Auto
		end
	end
	-- every farmland goes to the nearest home that still has room, so the neighbours get a similar share
	local counts = {}
	local cap = math.ceil(#lands / #homes) + 1
	local function dist(l, h)
		return (l.x - h.x) ^ 2 + (l.z - h.z) ^ 2
	end
	local order = {}
	for _, l in ipairs(lands) do
		local best = math.huge
		for _, h in ipairs(homes) do
			best = math.min(best, dist(l, h))
		end
		table.insert(order, { land = l, d = best })
	end
	table.sort(order, function(a, b) return a.d < b.d end)
	for _, e in ipairs(order) do
		local l = e.land
		local bestI, bestD = nil, math.huge
		for i, h in ipairs(homes) do
			local d = dist(l, h)
			if d < bestD and (counts[farmers[i].id] or 0) < cap then
				bestI, bestD = i, d
			end
		end
		bestI = bestI or 1
		local nid = farmers[bestI].id
		S.assign[l.id] = nid
		counts[nid] = (counts[nid] or 0) + 1
	end
	for _, n in ipairs(farmers) do
		GN.log("%s farms %d farmland(s)", n.name, counts[n.id] or 0)
	end
end

--- Default home of a farmer: the centre of the biggest field on his farmlands.
function S.computeMissingHomes()
	for _, n in ipairs(GN.neighbours) do
		if n.contracts and S.home[n.id] == nil then
			local best, bestA = nil, -1
			for _, field in pairs(g_fieldManager ~= nil and g_fieldManager:getFields() or {}) do
				local fl = fieldFarmlandId(field)
				if fl ~= nil and S.assign[fl] == n.id then
					local a = fieldArea(field)
					if a > bestA then
						best, bestA = field, a
					end
				end
			end
			if best ~= nil then
				local x, z = fieldPos(best)
				if x ~= nil then
					S.home[n.id] = { x = x, z = z, auto = true }
				end
			end
		end
	end
end

function S.homeList()
	local out = {}
	for nid, h in pairs(S.home) do
		table.insert(out, { nid = nid, x = h.x, z = h.z, ry = h.ry })
	end
	return out
end

function S.onSetHome(data, connection)
	if not GN.isConnectionAdmin(connection) then
		return
	end
	local nid, x, z = tonumber(data.nid), tonumber(data.x), tonumber(data.z)
	if GN.getNeighbour(nid) == nil or x == nil or z == nil then
		return
	end
	S.home[nid] = { x = x, z = z }
	GN.log("home of %s moved to (%.0f, %.0f) by an admin", GN.getNeighbour(nid).name, x, z)
	GN.sendToAll("homes", S.worldMsg())
end

S.PLACE_TYPES = { "gas", "shop", "public", "church", "townhall", "workshop", "trade", "relax", "walk" }
-- sizes of the neighbour tool: home = where he stands (character), the others are places for his machines
S.TOOL_SIZES = { "home", "vehicle", "attach", "oversize", "silo" }

local function validSize(size)
	for _, v in ipairs(S.TOOL_SIZES) do
		if v == size then
			return v
		end
	end
	return nil
end

local function countSlots(nid, size)
	local c = 0
	for _, p in ipairs(S.slots[nid] or {}) do
		if (p.size or "attach") == size then
			c = c + 1
		end
	end
	return c
end

--- After machine places changed: every neighbour who is not working parks his machines again.
local function reparkAll()
	for _, nb in ipairs(GN.neighbours) do
		if nb.contracts and GN.Work.active[nb.id] == nil then
			GN.safeCall("park", GN.Work.parkAll, nb.id)
		end
	end
end

--- A construction menu tool was placed: take its position, then remove the tool.
--- action: home (neighbour tool, size chosen with the size key), place_<type>, remove (+ old parking / slot)
function S.onTool(action, nid, x, z, ry, placeable)
	local n = GN.getNeighbour(nid)
	S.ensureLoaded()
	local msg = nil
	local overlap = nil
	local farmId = placeable ~= nil and placeable.getOwnerFarmId ~= nil and placeable:getOwnerFarmId() or nil
	local size = action == "home" and (S.toolSize[farmId or -1] or "home") or nil
	if action == "slot" then
		action, size = "home", "attach"
	end
	if x ~= nil then
		if action == "home" and n ~= nil then
			if size == "home" or not n.contracts then
				S.home[nid] = { x = x, z = z, ry = ry or 0 }
				size = "home"
			else
				S.slots[nid] = S.slots[nid] or {}
				local slot = { x = x, z = z, ry = ry or 0, size = size }
				-- overlapping another machine place: the machines would stand in each other
				for _, list in pairs(S.slots) do
					for _, q in ipairs(list) do
						if overlap == nil and GN.Auto.boxesOverlap(slot, q) then
							overlap = true
						end
					end
				end
				table.insert(S.slots[nid], slot)
			end
			local req = GN.Work.requiredPlaces(nid)
			msg = { nid = nid, action = "home", size = size, count = size == "home" and 1 or countSlots(nid, size), need = req[size] or 0, overlap = overlap }
		elseif action == "parking" and n ~= nil then
			S.parking[nid] = { x = x, z = z, ry = ry or 0 }
			msg = { nid = nid, action = action }
		elseif action == "place_myfarm" then
			-- a player's farm yard: the neighbours visit this farm here (one place per farm)
			if GN.isPlayerFarm(farmId) then
				for i = #S.places, 1, -1 do
					if S.places[i].type == "myfarm" and S.places[i].farmId == farmId then
						table.remove(S.places, i)
					end
				end
				table.insert(S.places, { type = "myfarm", farmId = farmId, x = x, z = z, ry = ry or 0 })
				msg = { action = action }
			end
		elseif string.sub(tostring(action), 1, 6) == "place_" then
			table.insert(S.places, { type = string.sub(action, 7), x = x, z = z, ry = ry or 0 })
			msg = { action = action }
		elseif action == "remove" then
			local what = S.removeNearest(x, z)
			msg = { action = "remove", what = what }
		end
		if msg ~= nil then
			GN.log("construction tool %s%s%s at (%.0f, %.0f)", tostring(action), size ~= nil and ("/" .. size) or "",
				n ~= nil and (" for " .. n.name) or "", x, z)
			-- everybody sees the new places at once
			GN.sendToAll("homes", S.worldMsg())
			GN.sendToAll("toolPlaced", msg)
			-- machines (and the silo) appear / disappear together with their places
			GN.safeCall("machines to places", GN.Work.syncAll)
			GN.safeCall("silos", GN.Silo.sync)
		end
	end
	S.toolsToRemove = S.toolsToRemove or {}
	table.insert(S.toolsToRemove, { placeable = placeable, at = (g_time or 0) + 1500 })
end

--- The player picked another size for the neighbour tool (sent by the client, remembered per farm).
function S.onToolSize(data, connection)
	local size = validSize(data.size)
	if size ~= nil then
		S.toolSize[GN.getConnectionFarmId(connection) or -1] = size
	end
end

--- Remove all places of the selected tool (admin, with a confirmation in the construction menu).
function S.onBulkRemove(data, connection)
	if not GN.isConnectionAdmin(connection) then
		return
	end
	S.ensureLoaded()
	local removed = 0
	local action, nid, size = tostring(data.action), tonumber(data.nid), validSize(data.size)
	if action == "home" and nid ~= nil and size ~= nil and size ~= "home" then
		local keep = {}
		for _, p in ipairs(S.slots[nid] or {}) do
			if (p.size or "attach") == size then
				removed = removed + 1
			else
				table.insert(keep, p)
			end
		end
		S.slots[nid] = keep
	elseif action == "home" and nid ~= nil and size == nil then
		removed = #(S.slots[nid] or {})
		S.slots[nid] = {}
	elseif string.sub(action, 1, 6) == "place_" then
		local t, keep = string.sub(action, 7), {}
		for _, p in ipairs(S.places) do
			if p.type == t then
				removed = removed + 1
			else
				table.insert(keep, p)
			end
		end
		S.places = keep
	end
	GN.log("bulk remove %s %s %s: %d place(s)", action, tostring(nid), tostring(size), removed)
	GN.sendToAll("homes", S.worldMsg())
	GN.safeCall("machines to places", GN.Work.syncAll)
	GN.safeCall("silos", GN.Silo.sync)
	GN.sendToConnection(connection, "toolPlaced", { action = "bulk", count = removed })
end

--- Removes the nearest machine place / visit place / parking row within 30 m.
function S.removeNearest(x, z)
	local best, bestD = nil, 30 * 30
	local function check(d, fn, label)
		if d < bestD then
			best, bestD = { fn = fn, label = label }, d
		end
	end
	for nid, list in pairs(S.slots) do
		for i, p in ipairs(list) do
			check((p.x - x) ^ 2 + (p.z - z) ^ 2, function() table.remove(list, i) end, "slot_" .. tostring(p.size or "attach"))
		end
	end
	for i, p in ipairs(S.places) do
		check((p.x - x) ^ 2 + (p.z - z) ^ 2, function() table.remove(S.places, i) end, "place_" .. tostring(p.type))
	end
	for nid, p in pairs(S.parking) do
		check((p.x - x) ^ 2 + (p.z - z) ^ 2, function() S.parking[nid] = nil end, "parking")
	end
	if best == nil then
		return "none"
	end
	best.fn()
	return best.label
end

function S.slotList()
	local out = {}
	for nid, list in pairs(S.slots) do
		for _, p in ipairs(list) do
			table.insert(out, { nid = nid, x = p.x, z = p.z, ry = p.ry, size = p.size or "attach" })
		end
	end
	return out
end

function S.worldMsg()
	local need = {}
	for _, n in ipairs(GN.neighbours) do
		local req = GN.Work.requiredPlaces(n.id)
		req.nid = n.id
		table.insert(need, req)
	end
	return { homes = S.homeList(), parking = S.parkingList(), slots = S.slotList(), places = S.places, need = need }
end

function S.parkingList()
	local out = {}
	for nid, p in pairs(S.parking) do
		table.insert(out, { nid = nid, x = p.x, z = p.z, ry = p.ry })
	end
	return out
end

function S.removePlacedTools()
	if S.toolsToRemove == nil then
		return
	end
	for i = #S.toolsToRemove, 1, -1 do
		local e = S.toolsToRemove[i]
		if (g_time or 0) >= e.at then
			table.remove(S.toolsToRemove, i)
			local p = e.placeable
			if p ~= nil and not p.isDeleted then
				local ok, err = GN.try(p.delete, p)
				if not ok then
					GN.log("could not remove a placed tool: %s", tostring(err))
				end
			end
		end
	end
end

function S.onSetParking(data, connection)
	if not GN.isConnectionAdmin(connection) then
		return
	end
	local nid, x, z, ry = tonumber(data.nid), tonumber(data.x), tonumber(data.z), tonumber(data.ry) or 0
	local n = GN.getNeighbour(nid)
	if n == nil or x == nil or z == nil then
		return
	end
	S.parking[nid] = { x = x, z = z, ry = ry }
	GN.log("machine parking of %s moved to (%.0f, %.0f) by an admin", n.name, x, z)
	GN.sendToAll("homes", S.worldMsg())
	if GN.Work.active[nid] == nil then
		GN.safeCall("park", GN.Work.parkAll, nid)
	end
end

function S.onSetStyle(data, connection)
	if not GN.isConnectionAdmin(connection) then
		return
	end
	local nid = tonumber(data.nid)
	if GN.getNeighbour(nid) == nil or type(data.outfit) ~= "table" then
		return
	end
	local clean, count = {}, 0
	for k, v in pairs(data.outfit) do
		if type(k) == "string" and type(v) == "table" and count < 40 then
			clean[k] = { item = math.floor(tonumber(v.item) or 0), color = math.floor(tonumber(v.color) or 1) }
			count = count + 1
		end
	end
	S.styles[nid] = clean
	GN.log("outfit of %s saved by an admin (%d items)", GN.getNeighbour(nid).name, count)
	S.logOutfit(nid)
	GN.sendToAll("styles", { styles = S.styles })
end

--- A player talked to a neighbour face to face: a few points, once per in-game day.
--- The outfit as a line for data/outfits.xml (the mod's default outfits are taken from the log).
function S.logOutfit(nid)
	local outfit = S.styles[nid]
	if outfit == nil then
		return
	end
	local keys = {}
	for k in pairs(outfit) do
		table.insert(keys, k)
	end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do
		table.insert(parts, string.format('<item config="%s" item="%d" color="%d"/>', k, outfit[k].item or 0, outfit[k].color or 1))
	end
	GN.log('outfit-xml: <style neighbour="%d">%s</style>', nid, table.concat(parts))
end

--- Default outfits of the mod (data/outfits.xml), for neighbours an admin did not dress yet.
function S.loadDefaultOutfits()
	local path = Utils.getFilename("data/outfits.xml", GN.dir)
	if path == nil or not fileExists(path) then
		return
	end
	local xml = loadXMLFile("gnOutfits", path)
	if xml == nil or xml == 0 then
		return
	end
	local i, used = 0, 0
	while true do
		local k = string.format("outfits.style(%d)", i)
		if not hasXMLProperty(xml, k) then break end
		local nid = getXMLInt(xml, k .. "#neighbour")
		local outfit, j = {}, 0
		while true do
			local ik = string.format("%s.item(%d)", k, j)
			if not hasXMLProperty(xml, ik) then break end
			local key = getXMLString(xml, ik .. "#config")
			if key ~= nil then
				outfit[key] = { item = getXMLInt(xml, ik .. "#item") or 0, color = getXMLInt(xml, ik .. "#color") or 1 }
			end
			j = j + 1
		end
		if nid ~= nil and S.styles[nid] == nil and next(outfit) ~= nil then
			S.styles[nid] = outfit
			used = used + 1
		end
		i = i + 1
	end
	delete(xml)
	GN.log("default outfits of the mod used for %d neighbour(s)", used)
end

function S.onTalk(data, connection)
	local nid = tonumber(data.nid)
	local farmId = GN.getConnectionFarmId(connection)
	if GN.getNeighbour(nid) == nil or not GN.isPlayerFarm(farmId) then
		return
	end
	local key = tostring(farmId) .. "|" .. tostring(nid)
	if S.talked[key] == S.day then
		return
	end
	-- the points come with the end of the conversation (S.onTalkDone)
end

--- A face to face conversation is over: points count once a day per farm and neighbour.
S.TALK_BASE_POINTS = 8
--- Airplane mode of a farm (phone settings): no more calls for that farm until it is turned off.
function S.onAirplane(data, connection)
	local farmId = GN.getConnectionFarmId(connection)
	if not GN.isPlayerFarm(farmId) then
		return
	end
	S.airplane = S.airplane or {}
	S.airplane[farmId] = data.on == true or nil
	GN.log("farm %d: airplane mode %s", farmId, data.on == true and "on" or "off")
	-- a call ringing at this farm ends
	if data.on == true and S.call ~= nil and S.call.farmId == farmId and not S.call.answered then
		S.endCall("airplane")
	end
	GN.sendToFarm(farmId, "airplane", { on = data.on == true })
	GN.safeCall("plan calls", S.planCalls, GN.getDayMinutes())
end

--- A face to face conversation is over: once a day per farm and neighbour it changes the relationship by
--- 40 to 80 points: good answers add, bad answers take away (read what you pick).
S.TALK_MIN_POINTS = 40
S.TALK_MAX_POINTS = 80
function S.onTalkDone(data, connection)
	local nid = tonumber(data.nid)
	local farmId = GN.getConnectionFarmId(connection)
	if GN.getNeighbour(nid) == nil or not GN.isPlayerFarm(farmId) then
		return
	end
	local key = tostring(farmId) .. "|" .. tostring(nid)
	if S.talked[key] == S.day then
		GN.sendToConnection(connection, "talkResult", { nid = nid, already = true })
		return
	end
	S.talked[key] = S.day
	-- where the answers lie between the worst and the best possible: good half +40..+80, bad half -40..-80
	local got = tonumber(data.points) or 0
	local best = tonumber(data.max) or 0
	local worst = tonumber(data.min) or 0
	local q = 0.5
	if best > worst then
		q = math.max(0, math.min(1, (got - worst) / (best - worst)))
	elseif got > 0 then
		q = 1
	elseif got < 0 then
		q = 0
	end
	local span = S.TALK_MAX_POINTS - S.TALK_MIN_POINTS
	local award
	if q >= 0.5 then
		award = math.floor(S.TALK_MIN_POINTS + span * (q - 0.5) * 2 + 0.5)
	else
		award = -math.floor(S.TALK_MIN_POINTS + span * (0.5 - q) * 2 + 0.5)
	end
	S.addPoints(farmId, nid, award)
	GN.sendToConnection(connection, "talkResult", { nid = nid, points = award, quality = q })
end

function S.countFarmlands(nid)
	local c, ha = 0, 0
	local areas = {}
	for _, field in pairs(g_fieldManager ~= nil and g_fieldManager:getFields() or {}) do
		local fl = fieldFarmlandId(field)
		if fl ~= nil and S.assign[fl] == nid and isNpcFarmland(fl) then
			areas[fl] = (areas[fl] or 0) + fieldArea(field)
		end
	end
	for _, a in pairs(areas) do
		c = c + 1
		ha = ha + a
	end
	return c, ha
end

-- ---------------------------------------------------------------------------
-- Relationships
-- ---------------------------------------------------------------------------

function S.getRel(farmId, nid)
	S.rel[farmId] = S.rel[farmId] or {}
	local r = S.rel[farmId][nid]
	if r == nil then
		r = { level = 1, points = 0 }
		S.rel[farmId][nid] = r
	end
	return r
end

function S.pointsForNextLevel(level)
	return 200 + 150 * (tonumber(level) or 1)
end

function S.payBonus(level)
	return math.min(S.PAY_BONUS_MAX, math.max(0, ((tonumber(level) or 1) - 1) * S.PAY_BONUS_PER_LEVEL))
end

function S.leaseRefund(level)
	return math.min(S.LEASE_REFUND_MAX, math.max(0, ((tonumber(level) or 1) - 1) * S.LEASE_REFUND_PER_LEVEL))
end

function S.relInfo(farmId, nid)
	local r = S.getRel(farmId, nid)
	return { nid = nid, level = r.level, points = r.points, need = S.pointsForNextLevel(r.level) }
end

function S.addPoints(farmId, nid, amount)
	if not GN.isPlayerFarm(farmId) or amount == 0 then
		return
	end
	local r = S.getRel(farmId, nid)
	local levelUp = false
	r.points = math.max(0, r.points + amount)
	while amount > 0 and r.points >= S.pointsForNextLevel(r.level) do
		r.points = r.points - S.pointsForNextLevel(r.level)
		r.level = r.level + 1
		levelUp = true
	end
	local n = GN.getNeighbour(nid)
	GN.log("relationship: farm %d with %s is now level %d (%d/%d points, %+d)", farmId, n ~= nil and n.name or "?",
		r.level, r.points, S.pointsForNextLevel(r.level), amount)
	local info = S.relInfo(farmId, nid)
	info.change = amount
	info.levelUp = levelUp
	GN.sendToFarm(farmId, "rel", info)
end

-- ---------------------------------------------------------------------------
-- Daily plan, SMS, calls
-- ---------------------------------------------------------------------------

function S.callLimit()
	return tonumber(S.settings.callsPerDay) or 2
end

function S.farmCanBeCalled(farmId)
	if S.airplane ~= nil and S.airplane[farmId] then
		return false
	end
	local limit = S.callLimit()
	if limit < 0 then
		return true
	end
	return (S.callsToday[farmId] or 0) < limit
end

function S.newDay(day)
	S.day = day
	S.callsToday = {}
	S.plans = {}
	S.sms = {}
	S.workStart = {}
	S.reserved = {}
	local now = GN.getDayMinutes()
	for _, n in ipairs(GN.neighbours) do
		if n.contracts then
			-- every day a different time to drive out (6:00 - 14:00)
			local ws = math.random(6 * 4, 14 * 4) * 15
			if ws < now then
				ws = now + math.random(1, 8) * 15
			end
			S.workStart[n.id] = ws
		end
	end
	-- the phone calls of the day: as many as set in the settings
	S.planCalls(now)
	for _, n in ipairs(GN.neighbours) do
		if n.contracts then
			GN.log("%s drives out at %s today", n.name, GN.formatClock(S.workStart[n.id]))
		end
	end
	GN.sendToAll("workPlan", { workStart = S.workStartList() })
end

function S.workStartList()
	local out = {}
	for nid, m in pairs(S.workStart) do
		table.insert(out, { nid = nid, minute = m })
	end
	return out
end

--- Is this contract kept for one of today's phone calls of the neighbour?
function S.isReserved(nid, mission)
	for _, plan in ipairs(S.plans or {}) do
		if plan.nid == nid and not plan.done and plan.reserved ~= nil and plan.reserved[mission] then
			return true
		end
	end
	return false
end

--- How many calls a day: the setting per farm (unlimited = 6), times the farms playing.
function S.callsWanted()
	local limit = S.callLimit()
	if limit == 0 then
		return 0
	end
	if limit < 0 then
		limit = 6
	end
	local farms, online = 0, 0
	for _, f in ipairs(GN.getOnlineFarms ~= nil and GN.getOnlineFarms() or {}) do
		online = online + 1
		if not (S.airplane ~= nil and S.airplane[f]) then
			farms = farms + 1
		end
	end
	if online > 0 and farms == 0 then
		return 0 -- every farm in airplane mode
	end
	return limit * math.max(1, farms)
end

--- Today's calls follow the setting at once: missing calls are planned (spread over the rest of the day,
--- morning first), calls too many are dropped. Each call keeps its fields free until it is over.
function S.planCalls(now)
	if S.plans == nil then
		S.plans = {}
	end
	now = now or GN.getDayMinutes()
	local want = S.callsWanted()
	-- too many (the setting was lowered): drop the ones still waiting, the latest first
	local count = 0
	for _, plan in ipairs(S.plans) do
		if not plan.dropped then
			count = count + 1
		end
	end
	for i = #S.plans, 1, -1 do
		if count <= want then
			break
		end
		local plan = S.plans[i]
		if not plan.done and not plan.dropped and not (S.call ~= nil and S.call.plan == plan) then
			plan.done = true
			plan.dropped = true
			S.clearSmsFor(plan)
			count = count - 1
		end
	end
	local active = 0
	for _, plan in ipairs(S.plans) do
		if not plan.dropped then
			active = active + 1
		end
	end
	if active >= want or now >= 20 * 60 then
		return
	end
	-- farmers with fields still free for a call, the one with the fewest calls today first
	local function freeMissions(nid)
		local out = {}
		for _, m in ipairs(S.getOpenMissions(nid)) do
			if not S.isReserved(nid, m) then
				table.insert(out, m)
			end
		end
		return out
	end
	local made = 0
	for _ = 1, want - active do
		local best, bestCount, bestFree = nil, math.huge, nil
		for _, n in ipairs(GN.neighbours) do
			if n.contracts then
				local free = freeMissions(n.id)
				if #free > 0 then
					local c = 0
					for _, plan in ipairs(S.plans) do
						if plan.nid == n.id and not plan.dropped then
							c = c + 1
						end
					end
					c = c + math.random() * 0.5
					if c < bestCount then
						best, bestCount, bestFree = n, c, free
					end
				end
			end
		end
		if best == nil then
			break
		end
		-- the time: morning calls first (6:30 - 10:30), more calls later in the day, never before now
		local planned = 0
		for _, plan in ipairs(S.plans) do
			if not plan.dropped then
				planned = planned + 1
			end
		end
		local from = S.CALL_FIRST_MINUTE + planned * 150
		local to = from + 150
		if planned == 0 then
			to = S.CALL_LAST_MINUTE
		end
		if from < now + 15 then
			from = now + 15
			to = math.max(to, from + 90)
		end
		local minute = math.min(20 * 60, math.random(from, math.max(from, to)))
		minute = minute - (minute % 5)
		local job = S.missionJob(bestFree[1])
		local res, k = {}, 0
		for _, m in ipairs(bestFree) do
			if k < (tonumber(S.settings.fieldsPerCall) or 3) and S.missionJob(m) == job then
				res[m] = true
				k = k + 1
			end
		end
		local plan = { nid = best.id, minute = minute, smsSent = false, done = false, attempts = 0, reserved = res }
		table.insert(S.plans, plan)
		table.sort(S.plans, function(a, b) return a.minute < b.minute end)
		-- he waits for his first call before he drives out himself
		local ws = S.workStart[best.id]
		if ws ~= nil and ws < minute + 60 and ws > now then
			local first = true
			for _, p in ipairs(S.plans) do
				if p.nid == best.id and p ~= plan and not p.dropped and p.minute < minute then
					first = false
				end
			end
			if first then
				S.workStart[best.id] = minute + 60 - ((minute + 60) % 15)
			end
		end
		made = made + 1
		GN.log("%s plans to call at %s (%d field(s))", best.name, GN.formatClock(minute), k)
	end
	if made > 0 then
		GN.sendToAll("workPlan", { workStart = S.workStartList() })
	end
end

--- A planned call that will not happen: its message leaves the phone.
function S.clearSmsFor(plan)
	if plan.smsSent then
		S.clearSms(plan.nid)
	end
end

--- The neighbour called (or will not call any more): his "I will call you" message leaves the phone.
function S.clearSms(nid)
	for i = #S.sms, 1, -1 do
		if S.sms[i].nid == nid and S.sms[i].kind == nil then
			table.remove(S.sms, i)
		end
	end
	GN.sendToAll("smsClear", { nid = nid })
end

function S.sendDueSms(now)
	for _, plan in ipairs(S.plans) do
		if not plan.smsSent and not plan.done and now <= plan.minute and (now >= 6 * 60 or plan.minute - now < 120) and plan.minute < 22 * 60 then
			plan.smsSent = true
			local nFields = 0
			for m in pairs(plan.reserved or {}) do
				nFields = nFields + 1
			end
			if nFields > 0 then
				local e = { nid = plan.nid, minute = plan.minute, fields = nFields, day = S.day }
				table.insert(S.sms, e)
				GN.sendToAll("sms", e)
			end
		end
	end
end

--- Pick one of the farms that may be called; a farm the neighbour knows better is picked more often.
function S.pickFarm(nid)
	local farms = {}
	for _, f in ipairs(GN.getOnlineFarms()) do
		if S.farmCanBeCalled(f) and #GN.getFarmConnections(f) > 0 then
			table.insert(farms, f)
		end
	end
	if #farms == 0 then
		return nil
	end
	local total, weights = 0, {}
	for i, f in ipairs(farms) do
		weights[i] = S.getRel(f, nid).level
		total = total + weights[i]
	end
	local r = math.random() * total
	for i, f in ipairs(farms) do
		r = r - weights[i]
		if r <= 0 then
			return f
		end
	end
	return farms[#farms]
end

function S.buildOffer(nid, farmId, plan)
	local n = GN.getNeighbour(nid)
	local open = {}
	-- the fields kept for this call first, then any other free field of his
	for _, m in ipairs(S.getOpenMissions(nid)) do
		if plan ~= nil and plan.reserved ~= nil and plan.reserved[m] then
			table.insert(open, m)
		end
	end
	if #open == 0 then
		for _, m in ipairs(S.getOpenMissions(nid)) do
			if not S.isReserved(nid, m) then
				table.insert(open, m)
			end
		end
	end
	local maxFields = tonumber(S.settings.fieldsPerCall) or 3
	local missions, jobs = {}, {}
	local total, lease, ha = 0, 0, 0
	local level = S.getRel(farmId, nid).level
	local bonus = S.payBonus(level)
	-- one kind of work per call (like a real neighbour asking: "can you plough three fields for me?")
	local job = open[1] ~= nil and S.missionJob(open[1]) or nil
	local lendTool = GN.Work.getLendableTool(nid, job)
	for _, m in ipairs(open) do
		if #missions >= maxFields then
			break
		end
		if S.missionJob(m) == job then
			table.insert(missions, m)
			local reward = S.contractPay(m)
			local area = fieldArea(m.field)
			total = total + reward
			lease = lease + missionLeaseCost(m)
			ha = ha + area
			table.insert(jobs, { job = job, field = fieldId(m.field) or 0, ha = math.floor(area * 100 + 0.5) / 100, reward = math.floor(reward) })
		end
	end
	if #missions == 0 then
		return nil
	end
	return {
		missions = missions,
		lendTool = lendTool,
		info = {
			nid = nid, name = n.name, lines = n.lines,
			jobs = jobs, total = math.floor(total), bonus = bonus, bonusMoney = math.floor(total * bonus),
			lease = math.floor(lease), leaseRefund = S.leaseRefund(level), ha = math.floor(ha * 10 + 0.5) / 10,
			level = level, line = math.random(1, 3),
			lendName = lendTool ~= nil and GN.Work.vehicleName(lendTool) or nil,
			supplies = GN.Borrow.JOB_FILL[job] ~= nil or nil,
		},
	}
end

function S.startCall(nid, plan, now)
	-- a second try goes to the same farm (it does not count as a new call)
	local farmId = nil
	if plan.farmId ~= nil and not (S.airplane ~= nil and S.airplane[plan.farmId]) and #GN.getFarmConnections(plan.farmId) > 0 then
		farmId = plan.farmId
	else
		farmId = S.pickFarm(nid)
	end
	if farmId == nil then
		GN.logThrottled("nofarm|" .. nid, 300, "%s wants to call, but no farm can take a call now", GN.getNeighbour(nid).name)
		return
	end
	local offer = S.buildOffer(nid, farmId, plan)
	if offer == nil then
		plan.done = true
		S.clearSms(nid)
		GN.log("%s has no open contracts any more, no call", GN.getNeighbour(nid).name)
		return
	end
	S.clearSms(nid)
	S.callSeq = (S.callSeq % 60000) + 1
	S.call = {
		id = S.callSeq, nid = nid, farmId = farmId, plan = plan, missions = offer.missions, info = offer.info, lendTool = offer.lendTool,
		started = g_time or 0, answered = false,
	}
	if not plan.counted then
		plan.counted = true
		plan.farmId = farmId
		S.callsToday[farmId] = (S.callsToday[farmId] or 0) + 1
	end
	offer.info.callId = S.call.id
	GN.log("%s calls farm %d (%d field(s), %s)", GN.getNeighbour(nid).name, farmId, #offer.missions, GN.formatMoney(offer.info.total))
	GN.sendToFarm(farmId, "call", offer.info)
end

function S.endCall(reason)
	local c = S.call
	if c == nil then
		return
	end
	if c.plan ~= nil and c.plan.done then
		c.plan.reserved = nil -- whatever was not taken, he does himself
	end
	S.call = nil
	S.lastCallEnd = g_time or 0
	GN.sendToFarm(c.farmId, "callEnd", { callId = c.id, reason = reason })
end

function S.updateCalls(now)
	local c = S.call
	local t = g_time or 0
	if c ~= nil then
		if not c.answered and t - c.started > S.RING_SECONDS * 1000 then
			local n = GN.getNeighbour(c.nid)
			GN.log("%s: farm %d did not answer", n.name, c.farmId)
			c.plan.attempts = c.plan.attempts + 1
			local missed = { nid = c.nid, minute = now, kind = "missed", day = S.day, farmId = c.farmId }
			table.insert(S.sms, missed)
			GN.sendToFarm(c.farmId, "missed", { nid = c.nid, minute = now })
			if c.plan.attempts >= S.MAX_ATTEMPTS then
				-- he gives up and does the fields himself
				c.plan.done = true
				c.plan.reserved = nil
				local e = { nid = c.nid, minute = now, kind = "busy", day = S.day, farmId = c.farmId }
				table.insert(S.sms, e)
				GN.sendToFarm(c.farmId, "sms", e)
				GN.log("%s: farm %d did not answer twice - he does it himself", n.name, c.farmId)
			else
				c.plan.minute = now + S.RETRY_MINUTES
				c.plan.farmId = c.farmId
			end
			S.endCall("missed")
		elseif c.answered and t - c.answeredAt > S.TALK_SECONDS * 1000 then
			S.endCall("timeout")
		end
		return
	end
	if t - S.lastCallEnd < S.PAUSE_BETWEEN_CALLS * 1000 then
		return
	end
	for _, plan in ipairs(S.plans) do
		if not plan.done and now >= plan.minute and now < 22 * 60 then
			S.startCall(plan.nid, plan, now)
			if S.call ~= nil then
				return
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Answers from the players
-- ---------------------------------------------------------------------------

function S.onAnswer(data, connection)
	local c = S.call
	if c == nil or c.id ~= data.callId or c.answered then
		GN.sendToConnection(connection, "callEnd", { callId = data.callId, reason = "taken" })
		return
	end
	if GN.getConnectionFarmId(connection) ~= c.farmId then
		return
	end
	c.answered = true
	c.answeredAt = g_time or 0
	c.answeredBy = connection
	-- every other phone of the farm stops ringing (sent to all players; only that call's phones react)
	for _, p in ipairs(GN.getPlayers()) do
		local pc = (p == g_localPlayer and GN.hasUI()) and GN.LOCAL or p.connection
		if pc ~= nil and pc ~= connection then
			GN.sendToConnection(pc, "callTaken", { callId = c.id })
		end
	end
	-- the other players of the farm stop ringing
	for _, other in ipairs(GN.getFarmConnections(c.farmId)) do
		if other ~= connection then
			GN.sendToConnection(other, "callEnd", { callId = c.id, reason = "taken" })
		end
	end
end

function S.onReply(data, connection)
	local c = S.call
	if c == nil or c.id ~= data.callId or c.answeredBy ~= connection then
		return
	end
	local n = GN.getNeighbour(c.nid)
	local choice = tostring(data.choice)
	c.plan.done = true
	if choice ~= "accept" and choice ~= "borrow" then
		GN.log("%s: farm %d declined", n.name, c.farmId)
		S.endCall("declined")
		return
	end
	local borrow = choice == "borrow"
	-- "borrow": the neighbour lends his own machine when he has one for this job, otherwise the game's lease
	-- only his own machine is lent; without one the player works with his own machines (no leasing)
	local lend = borrow and c.lendTool ~= nil and GN.Work.isAlive(c.lendTool) and c.lendTool.gnBorrowFarm == nil
	local lease = false
	local level = S.getRel(c.farmId, c.nid).level
	local started, failed = 0, 0
	local deadlineDays = nil
	local startedMissions = {}
	for _, m in ipairs(c.missions) do
		if isOpenMission(m) then
			-- like every contract: it has to be done in time (bigger fields get more days)
			local oldEnd = m.endDate
			local days = S.contractDays(m)
			if m.setEndDateByOffset ~= nil then
				GN.try(m.setEndDateByOffset, m, days * 24 * 60 * 60 * 1000)
			end
			-- the game pays the Invoices price for it (the rest is evened out when it is finished)
			GN.try(function()
				local rate = S.invoiceRate(m)
				if rate ~= nil then
					if m.rewardPerHa ~= nil then
						m.rewardPerHa = rate
					end
					m.reward = S.contractPay(m)
				end
			end)
			local ok, res = GN.try(g_missionManager.startMission, g_missionManager, m, c.farmId, lease)
			local good = ok and (res == nil or res == true or (MissionStartState ~= nil and res == MissionStartState.OK))
			if not good then
				m.endDate = oldEnd
			end
			if good and MissionStatus ~= nil and m.status == MissionStatus.PREPARING and m.getIsPrepared ~= nil and m.finishedPreparing ~= nil then
				-- no vehicles to wait for: running at once, so the next contract of this call can start too
				GN.try(function()
					if m:getIsPrepared() then
						m:finishedPreparing()
					end
				end)
			end
			if good then
				started = started + 1
				deadlineDays = math.max(deadlineDays or 0, days)
				table.insert(startedMissions, m)
				-- the deadline counts from now to the end of the last day (the game sets its own date when starting)
				local deadline = (GN.getDay() + days) * 24 * 60 + 23 * 60 + 59
				if m.setEndDateByOffset ~= nil then
					GN.try(m.setEndDateByOffset, m, (deadline - S.absMinutes()) * 60 * 1000)
				end
				local t = { mission = m, nid = c.nid, farmId = c.farmId, bonus = S.payBonus(level),
					refund = lease and S.leaseRefund(level) or 0, fieldId = fieldId(m.field), lent = lend or nil, deadline = deadline,
					pay = S.contractPay(m) }
				table.insert(S.tracked, t)
				S.guardMission(t)
			else
				failed = failed + 1
				GN.log("could not start a contract on field %s for farm %d: %s", tostring(fieldId(m.field)), c.farmId, tostring(res))
			end
		else
			failed = failed + 1
		end
	end
	if lend and started > 0 then
		GN.Work.lendTool(c.nid, c.lendTool, c.farmId, startedMissions, c.info.jobs ~= nil and c.info.jobs[1] ~= nil and c.info.jobs[1].job or nil)
	end
	GN.log("%s: farm %d accepted (%s), %d contract(s) started, %d not possible", n.name, c.farmId,
		lend and "with his own machine" or (lease and "with leased machines" or "own machines"), started, failed)
	if started > 0 then
		-- seeds / fertilizer / herbicide / lime for his contracts at his silo place
		GN.safeCall("supplies", GN.Supply.deliver, c.nid, c.farmId, startedMissions, c.info.jobs ~= nil and c.info.jobs[1] ~= nil and c.info.jobs[1].job or nil)
	end
	GN.sendToFarm(c.farmId, "accepted", { nid = c.nid, started = started, failed = failed, days = deadlineDays })
	S.endCall("accepted")
end

-- ---------------------------------------------------------------------------
-- Finished contracts: relationship points and the neighbour's bonus
-- ---------------------------------------------------------------------------

--- Days to finish a phone contract (after today): 2 days up to 5 ha, 3 days up to 15 ha, then 4.
function S.contractDays(m)
	local ha = 0
	if m ~= nil and m.field ~= nil and m.field.getAreaHa ~= nil then
		local ok, a = GN.try(m.field.getAreaHa, m.field)
		ha = ok and a or 0
	end
	if ha <= 5 then
		return 2
	elseif ha <= 15 then
		return 3
	end
	return 4
end

--- In-game minutes since day 0.
function S.absMinutes()
	return GN.getDay() * 24 * 60 + GN.getDayMinutes()
end

--- A phone contract of a neighbour:
---   * it does not time out before our deadline (the game's own date may be the end of today)
---   * with a lent machine it counts only when the machine is back on its place (as in FoS): the finished
---     contract waits, the player brings the machine back and unhitches it there, then it is paid
function S.guardMission(t)
	local m = t.mission
	if m == nil or m.gnGuard == t then
		return
	end
	m.gnGuard = t
	local classFinish = getmetatable(m) ~= nil and m.finish or nil
	if classFinish == nil then
		return
	end
	m.finish = function(self, state, ...)
		local FS = MissionFinishState
		local timedOut = FS ~= nil and state == FS.TIMED_OUT
		local success = FS ~= nil and state == FS.SUCCESS
		if timedOut and t.deadline ~= nil and S.absMinutes() < t.deadline then
			if self.setEndDateByOffset ~= nil then
				GN.try(self.setEndDateByOffset, self, (t.deadline - S.absMinutes()) * 60 * 1000)
			end
			return
		end
		if timedOut and t.awaiting then
			return -- the work is done, only the machine is not back yet
		end
		if success and t.lent and not t.released then
			if not t.awaiting then
				t.awaiting = true
				GN.log("contract on field %s for %s done by farm %d - waits for the machine to come back", tostring(t.fieldId),
					GN.getNeighbour(t.nid).name, t.farmId)
				if not S.lentStillWorking(t.nid, t.farmId) then
					GN.safeCall("lent machine back", GN.Borrow.onContractsDone, t.nid, t.farmId)
				end
			end
			return
		end
		self.finish = nil
		return classFinish(self, state, ...)
	end
end

--- Lent machine still needed for work (a contract with it that is not done yet)?
function S.lentStillWorking(nid, farmId)
	for _, t in ipairs(S.tracked) do
		if t.lent and t.nid == nid and t.farmId == farmId and not t.awaiting then
			return true
		end
	end
	for _, t in ipairs(S.pendingTracked) do
		if t.lent and t.nid == nid and t.farmId == farmId then
			return true
		end
	end
	return false
end

--- The lent machine is back (or fetched by the neighbour): the waiting contracts are finished now.
function S.releaseAwaiting(nid, farmId)
	local list = {}
	for _, t in ipairs(S.tracked) do
		if t.nid == nid and t.farmId == farmId and t.awaiting and not t.released then
			table.insert(list, t)
		end
	end
	for _, t in ipairs(list) do
		t.released = true
		if t.mission ~= nil and t.mission.finish ~= nil and MissionFinishState ~= nil then
			local ok, err = GN.try(t.mission.finish, t.mission, MissionFinishState.SUCCESS)
			if not ok then
				GN.log("could not finish the contract on field %s: %s", tostring(t.fieldId), tostring(err))
			end
		end
	end
	return #list
end

--- Any of this neighbour's phone contracts still running for this farm?
function S.contractsRunning(nid, farmId)
	for _, list in ipairs({ S.tracked, S.pendingTracked }) do
		for _, t in ipairs(list) do
			if t.nid == nid and t.farmId == farmId then
				return true
			end
		end
	end
	return false
end

function S.lentStillNeeded(nid, farmId)
	for _, t in ipairs(S.tracked) do
		if t.lent and t.nid == nid and t.farmId == farmId then
			return true
		end
	end
	for _, t in ipairs(S.pendingTracked) do
		if t.lent and t.nid == nid and t.farmId == farmId then
			return true
		end
	end
	return false
end

function S.onMissionFinished(mission, finishState)
	for i = #S.tracked, 1, -1 do
		local t = S.tracked[i]
		if t.mission == mission then
			table.remove(S.tracked, i)
			if t.lent and not S.lentStillNeeded(t.nid, t.farmId) then
				GN.safeCall("lent machine back", GN.Borrow.onContractsDone, t.nid, t.farmId)
			end
			if not S.contractsRunning(t.nid, t.farmId) then
				GN.safeCall("supplies back", GN.Supply.clear, t.nid, t.farmId)
			end
			local success = MissionFinishState == nil or finishState == MissionFinishState.SUCCESS
			local n = GN.getNeighbour(t.nid)
			if success then
				local gameReward = missionReward(mission)
				local reward = t.pay or S.contractPay(mission)
				local adjust = reward - gameReward   -- evens the game's pay out to the Invoices price
				local bonus = math.floor(reward * (t.bonus or 0) + 0.5)
				local refund = math.floor(missionLeaseCost(mission) * (t.refund or 0) + 0.5)
				local money = bonus + refund + adjust
				if money ~= 0 and g_currentMission ~= nil and g_currentMission.addMoney ~= nil then
					local moneyType = MoneyType ~= nil and (MoneyType.MISSIONS or MoneyType.OTHER) or nil
					GN.try(g_currentMission.addMoney, g_currentMission, money, t.farmId, moneyType, true)
				end
				GN.log("contract pay (Invoices price): %d, game paid %d, difference %d", reward, gameReward, adjust)
				local points = math.max(25, math.min(150, math.floor(reward / 200)))
				GN.sendToFarm(t.farmId, "thanks", { nid = t.nid, bonus = bonus, refund = refund, points = points })
				S.addPoints(t.farmId, t.nid, points)
				GN.log("contract for %s on field %s done by farm %d: bonus %d, lease refund %d", n.name, tostring(t.fieldId), t.farmId, bonus, refund)
			else
				GN.sendToFarm(t.farmId, "failed", { nid = t.nid })
				S.addPoints(t.farmId, t.nid, -50)
				GN.log("contract for %s on field %s by farm %d ended without success (%s)", n.name, tostring(t.fieldId), t.farmId, tostring(finishState))
			end
			return
		end
	end
end

function S.matchPendingTracked()
	if #S.pendingTracked == 0 or g_missionManager == nil then
		return
	end
	for i = #S.pendingTracked, 1, -1 do
		local p = S.pendingTracked[i]
		for _, m in ipairs(g_missionManager.missions or {}) do
			if m.field ~= nil and m.farmId == p.farmId and fieldId(m.field) == p.fieldId then
				p.mission = m
				table.insert(S.tracked, p)
				S.guardMission(p)
				table.remove(S.pendingTracked, i)
				break
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Settings (admin)
-- ---------------------------------------------------------------------------

local function valueIn(list, v)
	for _, x in ipairs(list) do
		if x == v then
			return true
		end
	end
	return false
end

function S.onSetSettings(data, connection)
	if not GN.isConnectionAdmin(connection) then
		GN.log("settings change refused: not an admin")
		GN.sendToConnection(connection, "settings", S.settings)
		return
	end
	local calls = tonumber(data.callsPerDay)
	local fields = tonumber(data.fieldsPerCall)
	if calls ~= nil and valueIn(S.CALLS_PER_DAY_VALUES, calls) then
		S.settings.callsPerDay = calls
	end
	if fields ~= nil and valueIn(S.FIELDS_PER_CALL_VALUES, fields) then
		S.settings.fieldsPerCall = fields
	end
	if type(data.npcWork) == "boolean" then
		S.settings.npcWork = data.npcWork
	end
	GN.log("settings: calls per day %d, fields per call %d", S.settings.callsPerDay, S.settings.fieldsPerCall)
	GN.sendToAll("settings", S.settings)
	-- today's calls follow the new setting at once
	GN.safeCall("plan calls", S.planCalls, GN.getDayMinutes())
end

-- ---------------------------------------------------------------------------
-- Messages from clients
-- ---------------------------------------------------------------------------

function S.buildSync(connection)
	local farmId = GN.getConnectionFarmId(connection)
	local neighbours = {}
	for _, n in ipairs(GN.neighbours) do
		local fl, ha = 0, 0
		if n.contracts then
			fl, ha = S.countFarmlands(n.id)
		end
		table.insert(neighbours, { id = n.id, farmlands = fl, ha = math.floor(ha * 10 + 0.5) / 10 })
	end
	local rel = {}
	if GN.isPlayerFarm(farmId) then
		for _, n in ipairs(GN.neighbours) do
			table.insert(rel, S.relInfo(farmId, n.id))
		end
	end
	local sms = {}
	for _, e in ipairs(S.sms) do
		if e.farmId == nil or e.farmId == farmId then
			table.insert(sms, e)
		end
	end
	local data = { neighbours = neighbours, rel = rel, settings = S.settings, sms = sms, day = S.day,
		admin = GN.isConnectionAdmin(connection), airplane = S.airplane[GN.getConnectionFarmId(connection) or -1] == true,
		homes = S.homeList(), parking = S.parkingList(), slots = S.slotList(), places = S.places, styles = S.styles,
		assign = S.assignList(),
		workStart = S.workStartList(), need = S.worldMsg().need }
	if S.call ~= nil and not S.call.answered and S.call.farmId == farmId then
		data.call = S.call.info
	end
	return data
end

function S.onMessage(kind, data, connection)
	if kind == "hello" then
		if connection ~= GN.LOCAL and connection ~= nil then
			connection.gnReady = true
		end
		S.ensureLoaded()
		GN.sendToConnection(connection, "sync", S.buildSync(connection))
		if connection ~= GN.LOCAL then
			GN.safeCall("drivers", GN.Work.sendDriversTo, connection)
		end
		GN.safeCall("borrows", GN.Borrow.sendAllTo, connection, GN.getConnectionFarmId(connection))
	elseif kind == "answer" then
		S.onAnswer(data, connection)
	elseif kind == "reply" then
		S.onReply(data, connection)
	elseif kind == "setSettings" then
		S.onSetSettings(data, connection)
	elseif kind == "setHome" then
		S.onSetHome(data, connection)
	elseif kind == "setStyle" then
		S.onSetStyle(data, connection)
	elseif kind == "setParking" then
		S.onSetParking(data, connection)
	elseif kind == "talk" then
		S.onTalk(data, connection)
	elseif kind == "autoPlaces" then
		GN.Auto.onRequest(data, connection)
	elseif kind == "talkDone" then
		S.onTalkDone(data, connection)
	elseif kind == "airplane" then
		S.onAirplane(data, connection)
	elseif kind == "toolSize" then
		S.onToolSize(data, connection)
	elseif kind == "bulkRemove" then
		S.onBulkRemove(data, connection)
	end
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------

function S.update(dt)
	if g_currentMission == nil or g_missionManager == nil then
		return
	end
	if S.loaded then
		S.assignTimer = (S.assignTimer or 0) + (dt or 0)
		if S.assignTimer > 60000 or not S.assignChecked then
			S.assignTimer = 0
			S.assignChecked = true
			GN.safeCall("field owners", S.refreshAssign)
		end
	end
	S.timer = S.timer + (dt or 0)
	if S.timer < 1000 then
		return
	end
	S.timer = 0
	S.ensureLoaded()
	GN.safeCall("borrows", GN.Borrow.matchPending)
	S.removePlacedTools()
	S.matchPendingTracked()
	local day = GN.getDay()
	if S.day ~= day then
		S.newDay(day)
	end
	local now = GN.getDayMinutes()
	S.sendDueSms(now)
	S.updateCalls(now)
	-- every in-game half hour: today's calls follow the setting (new free fields, more farms online)
	local slot = math.floor(now / 30)
	if S.planSlot ~= slot then
		S.planSlot = slot
		GN.safeCall("plan calls", S.planCalls, now)
	end
	-- late evening: calls that did not happen are over, he does those fields himself
	if now >= 21 * 60 and S.call == nil then
		for _, plan in ipairs(S.plans) do
			if not plan.done then
				plan.done = true
				plan.reserved = nil
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Save / load (<savegame>/goodNeighbours.xml)
-- ---------------------------------------------------------------------------

local function savePath(missionInfo)
	local mi = missionInfo or (g_currentMission ~= nil and g_currentMission.missionInfo or nil)
	local dir = mi ~= nil and mi.savegameDirectory or nil
	if dir == nil or dir == "" then
		return nil
	end
	return dir .. "/" .. S.SAVE_FILE
end

--- Name of the map for map presets ("MapUS", "MapEU", "MapAS", or a mod map's id), safe as a file name.
function S.mapKey()
	local mi = g_currentMission ~= nil and g_currentMission.missionInfo or nil
	local id = mi ~= nil and (mi.mapId or (mi.map ~= nil and mi.map.id)) or nil
	if id == nil then
		return nil
	end
	return (string.gsub(tostring(id), "[^%w_]", "_"))
end

-- the mod's presets for the base game maps
S.MAP_PRESETS = { MapUS = "data/maps/MapUS.xml", MapEU = "data/maps/MapEU.xml", MapAS = "data/maps/MapAS.xml" }

--- Places made for this map: the mod's own preset (data/maps/<map>.xml) or one in modSettings.
function S.findPreset()
	local key = S.mapKey()
	if key == nil then
		return nil
	end
	local candidates = {
		(g_modSettingsDirectory or "") .. "FS25_GoodNeighbours/maps/" .. key .. ".xml",
	}
	if S.MAP_PRESETS[key] ~= nil then
		table.insert(candidates, Utils.getFilename(S.MAP_PRESETS[key], GN.dir))
	end
	for _, p in ipairs(candidates) do
		if p ~= nil and fileExists(p) then
			return p
		end
	end
	return nil
end

--- Every save also writes the places of this map as a preset next to the savegame
--- (goodNeighbours_<map>.xml): put it into the mod (data/maps) and every new game on this map starts with them.
function S.savePreset(missionInfo)
	local mi = missionInfo or (g_currentMission ~= nil and g_currentMission.missionInfo or nil)
	local dir = mi ~= nil and mi.savegameDirectory or nil
	local key = S.mapKey()
	if dir == nil or dir == "" or key == nil then
		return
	end
	local xml = createXMLFile("gnPreset", dir .. "/goodNeighbours_" .. key .. ".xml", "goodNeighbours")
	if xml == nil or xml == 0 then
		return
	end
	setXMLString(xml, "goodNeighbours#map", key)
	setXMLBool(xml, "goodNeighbours#preset", true)
	local i = 0
	local ids = {}
	for id in pairs(S.assign) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local k = string.format("goodNeighbours.farmlands.farmland(%d)", i)
		setXMLInt(xml, k .. "#id", id)
		setXMLInt(xml, k .. "#neighbour", S.assign[id])
		i = i + 1
	end
	i = 0
	for nid, h in pairs(S.home) do
		local k = string.format("goodNeighbours.homes.home(%d)", i)
		setXMLInt(xml, k .. "#neighbour", nid)
		setXMLFloat(xml, k .. "#x", h.x)
		setXMLFloat(xml, k .. "#z", h.z)
		setXMLFloat(xml, k .. "#ry", h.ry or 0)
		i = i + 1
	end
	i = 0
	for nid, list in pairs(S.slots) do
		for _, p in ipairs(list) do
			local k = string.format("goodNeighbours.slots.slot(%d)", i)
			setXMLInt(xml, k .. "#neighbour", nid)
			setXMLFloat(xml, k .. "#x", p.x)
			setXMLFloat(xml, k .. "#z", p.z)
			setXMLFloat(xml, k .. "#ry", p.ry or 0)
			setXMLString(xml, k .. "#size", p.size or "attach")
			i = i + 1
		end
	end
	i = 0
	for _, p in ipairs(S.places) do
		if p.type ~= "myfarm" then
			local k = string.format("goodNeighbours.places.place(%d)", i)
			setXMLString(xml, k .. "#type", p.type)
			setXMLFloat(xml, k .. "#x", p.x)
			setXMLFloat(xml, k .. "#z", p.z)
			setXMLFloat(xml, k .. "#ry", p.ry or 0)
			i = i + 1
		end
	end
	saveXMLFile(xml)
	delete(xml)
end

--- Places of a map preset replace the places of a running game (once per savegame, when the mod brings a preset).
function S.applyPresetFile(path)
	local xml = loadXMLFile("gnPresetLoad", path)
	if xml == nil or xml == 0 then
		return false
	end
	local homes, slots, places = {}, {}, {}
	local i = 0
	while true do
		local k = string.format("goodNeighbours.homes.home(%d)", i)
		if not hasXMLProperty(xml, k) then break end
		local nid = getXMLInt(xml, k .. "#neighbour")
		if nid ~= nil then
			homes[nid] = { x = getXMLFloat(xml, k .. "#x") or 0, z = getXMLFloat(xml, k .. "#z") or 0, ry = getXMLFloat(xml, k .. "#ry") or 0 }
		end
		i = i + 1
	end
	i = 0
	while true do
		local k = string.format("goodNeighbours.slots.slot(%d)", i)
		if not hasXMLProperty(xml, k) then break end
		local nid = getXMLInt(xml, k .. "#neighbour")
		if nid ~= nil then
			slots[nid] = slots[nid] or {}
			table.insert(slots[nid], { x = getXMLFloat(xml, k .. "#x") or 0, z = getXMLFloat(xml, k .. "#z") or 0, ry = getXMLFloat(xml, k .. "#ry") or 0,
				size = getXMLString(xml, k .. "#size") or "attach" })
		end
		i = i + 1
	end
	i = 0
	while true do
		local k = string.format("goodNeighbours.places.place(%d)", i)
		if not hasXMLProperty(xml, k) then break end
		table.insert(places, { type = getXMLString(xml, k .. "#type") or "public", x = getXMLFloat(xml, k .. "#x") or 0,
			z = getXMLFloat(xml, k .. "#z") or 0, ry = getXMLFloat(xml, k .. "#ry") or 0 })
		i = i + 1
	end
	delete(xml)
	if next(homes) == nil then
		return false
	end
	for nid, h in pairs(homes) do
		S.home[nid] = h
	end
	S.slots = slots
	S.places = places
	S.buildingAreas = {}
	return true
end

function S.ensureLoaded()
	if S.loaded then
		return
	end
	S.loaded = true
	local path = savePath()
	if path == nil or not fileExists(path) then
		-- first start on this savegame: the places made for this map, when there are some
		local preset = S.findPreset()
		if preset ~= nil then
			GN.log("map preset %s used for the places", preset)
			path = preset
		end
	end
	local hasAssign = false
	if path ~= nil and fileExists(path) then
		local xml = loadXMLFile("goodNeighbours", path)
		if xml ~= nil and xml ~= 0 then
			S.settings.callsPerDay = getXMLInt(xml, "goodNeighbours.settings#callsPerDay") or S.settings.callsPerDay
			for f in string.gmatch(getXMLString(xml, "goodNeighbours.settings#airplane") or "", "%d+") do
				S.airplane[tonumber(f)] = true
			end
			S.settings.fieldsPerCall = getXMLInt(xml, "goodNeighbours.settings#fieldsPerCall") or S.settings.fieldsPerCall
			S.presetApplied = getXMLBool(xml, "goodNeighbours#presetApplied") == true or getXMLBool(xml, "goodNeighbours#preset") == true
			local w = getXMLBool(xml, "goodNeighbours.settings#npcWork")
			if w ~= nil then S.settings.npcWork = w end
			GN.safeCall("load fleets", GN.Work.loadFromXML, xml)
			GN.safeCall("load borrows", GN.Borrow.loadFromXML, xml)
			GN.safeCall("load cars", GN.Situ.loadFromXML, xml)
			GN.safeCall("load supplies", GN.Supply.loadFromXML, xml)
			local i = 0
			while true do
				local k = string.format("goodNeighbours.farmlands.farmland(%d)", i)
				if not hasXMLProperty(xml, k) then break end
				local id, nid = getXMLInt(xml, k .. "#id"), getXMLInt(xml, k .. "#neighbour")
				if id ~= nil and nid ~= nil then
					S.assign[id] = nid
					hasAssign = true
				end
				i = i + 1
			end
			i = 0
			while true do
				local k = string.format("goodNeighbours.homes.home(%d)", i)
				if not hasXMLProperty(xml, k) then break end
				local nid = getXMLInt(xml, k .. "#neighbour")
				local x, z = getXMLFloat(xml, k .. "#x"), getXMLFloat(xml, k .. "#z")
				if nid ~= nil and x ~= nil and z ~= nil then
					S.home[nid] = { x = x, z = z, ry = getXMLFloat(xml, k .. "#ry") or 0, auto = getXMLBool(xml, k .. "#auto") == true }
				end
				i = i + 1
			end
			i = 0
			while true do
				local k = string.format("goodNeighbours.slots.slot(%d)", i)
				if not hasXMLProperty(xml, k) then break end
				local nid = getXMLInt(xml, k .. "#neighbour")
				if nid ~= nil then
					S.slots[nid] = S.slots[nid] or {}
					table.insert(S.slots[nid], { x = getXMLFloat(xml, k .. "#x") or 0, z = getXMLFloat(xml, k .. "#z") or 0, ry = getXMLFloat(xml, k .. "#ry") or 0,
						size = validSize(getXMLString(xml, k .. "#size")) or "attach", auto = getXMLBool(xml, k .. "#auto") == true })
				end
				i = i + 1
			end
			i = 0
			while true do
				local k = string.format("goodNeighbours.buildings.neighbour(%d)", i)
				if not hasXMLProperty(xml, k) then break end
				local nid = getXMLInt(xml, k .. "#id")
				if nid ~= nil then
					local silo, shed = getXMLString(xml, k .. "#silo"), getXMLString(xml, k .. "#shed")
					S.farmBuildings[nid] = { silo = (silo ~= nil and silo ~= "") and silo or nil, shed = (shed ~= nil and shed ~= "") and shed or nil }
				end
				i = i + 1
			end
			i = 0
			while true do
				local k = string.format("goodNeighbours.buildingAreas.area(%d)", i)
				if not hasXMLProperty(xml, k) then break end
				table.insert(S.buildingAreas, { x = getXMLFloat(xml, k .. "#x") or 0, z = getXMLFloat(xml, k .. "#z") or 0, ry = getXMLFloat(xml, k .. "#ry") or 0,
					len = getXMLFloat(xml, k .. "#len") or 10, side = getXMLFloat(xml, k .. "#side") or 5 })
				i = i + 1
			end
			i = 0
			while true do
				local k = string.format("goodNeighbours.places.place(%d)", i)
				if not hasXMLProperty(xml, k) then break end
				table.insert(S.places, { type = getXMLString(xml, k .. "#type") or "public", x = getXMLFloat(xml, k .. "#x") or 0,
					z = getXMLFloat(xml, k .. "#z") or 0, ry = getXMLFloat(xml, k .. "#ry") or 0, auto = getXMLBool(xml, k .. "#auto") == true,
					farmId = getXMLInt(xml, k .. "#farm") })
				i = i + 1
			end
			i = 0
			while true do
				local k = string.format("goodNeighbours.parking.place(%d)", i)
				if not hasXMLProperty(xml, k) then break end
				local nid = getXMLInt(xml, k .. "#neighbour")
				local x, z = getXMLFloat(xml, k .. "#x"), getXMLFloat(xml, k .. "#z")
				if nid ~= nil and x ~= nil and z ~= nil then
					S.parking[nid] = { x = x, z = z, ry = getXMLFloat(xml, k .. "#ry") or 0 }
				end
				i = i + 1
			end
			i = 0
			while true do
				local k = string.format("goodNeighbours.styles.style(%d)", i)
				if not hasXMLProperty(xml, k) then break end
				local nid = getXMLInt(xml, k .. "#neighbour")
				local outfit = {}
				local j = 0
				while true do
					local ik = string.format("%s.item(%d)", k, j)
					if not hasXMLProperty(xml, ik) then break end
					local key = getXMLString(xml, ik .. "#config")
					if key ~= nil then
						outfit[key] = { item = getXMLInt(xml, ik .. "#item") or 0, color = getXMLInt(xml, ik .. "#color") or 1 }
					end
					j = j + 1
				end
				if nid ~= nil then
					S.styles[nid] = outfit
				end
				i = i + 1
			end
			i = 0
			while true do
				local k = string.format("goodNeighbours.relations.relation(%d)", i)
				if not hasXMLProperty(xml, k) then break end
				local farmId, nid = getXMLInt(xml, k .. "#farm"), getXMLInt(xml, k .. "#neighbour")
				if farmId ~= nil and nid ~= nil then
					local r = S.getRel(farmId, nid)
					r.level = math.max(1, getXMLInt(xml, k .. "#level") or 1)
					r.points = math.max(0, getXMLInt(xml, k .. "#points") or 0)
				end
				i = i + 1
			end
			i = 0
			while true do
				local k = string.format("goodNeighbours.contracts.contract(%d)", i)
				if not hasXMLProperty(xml, k) then break end
				table.insert(S.pendingTracked, {
					fieldId = getXMLInt(xml, k .. "#field"), farmId = getXMLInt(xml, k .. "#farm"),
					nid = getXMLInt(xml, k .. "#neighbour"), bonus = getXMLFloat(xml, k .. "#bonus") or 0,
					refund = getXMLFloat(xml, k .. "#refund") or 0,
					lent = getXMLBool(xml, k .. "#lent") == true or nil,
					deadline = getXMLInt(xml, k .. "#deadline"),
					awaiting = getXMLBool(xml, k .. "#awaiting") == true or nil,
					pay = getXMLInt(xml, k .. "#pay"),
				})
				i = i + 1
			end
			delete(xml)
			GN.log("loaded from the savegame")
		end
	end
	if not hasAssign then
		S.assignFarmlands()
	end
	GN.safeCall("default outfits", S.loadDefaultOutfits)
	for nid in pairs(S.styles) do
		S.logOutfit(nid)
	end
	if not S.presetApplied then
		local preset = S.findPreset()
		if preset ~= nil and S.applyPresetFile(preset) then
			S.presetApplied = true
			-- the fields are shared out again around the homes of the preset
			S.assignFarmlands()
			GN.log("map preset %s: homes, machine places and visit places taken over", preset)
		end
	end
	S.computeMissingHomes()
	local _, c = GN.safeCall("field owners", GN.World.applyFarmlandNpcs, S.assign)
	GN.log("%s farmlands show their neighbour as the owner", tostring(c))
end

function S.assignList()
	local out = {}
	for fl, nid in pairs(S.assign) do
		table.insert(out, { fl = fl, nid = nid })
	end
	return out
end

function S.save(missionInfo)
	local path = savePath(missionInfo)
	if path == nil or not S.loaded then
		return
	end
	local xml = createXMLFile("goodNeighbours", path, "goodNeighbours")
	if xml == nil or xml == 0 then
		return
	end
	GN.safeCall("map preset", S.savePreset, missionInfo)
	setXMLString(xml, "goodNeighbours#version", tostring(GN.version or "1"))
	setXMLBool(xml, "goodNeighbours#presetApplied", S.presetApplied == true)
	setXMLInt(xml, "goodNeighbours.settings#callsPerDay", S.settings.callsPerDay)
	do
		local list = {}
		for f in pairs(S.airplane or {}) do
			table.insert(list, tostring(f))
		end
		setXMLString(xml, "goodNeighbours.settings#airplane", table.concat(list, ","))
	end
	setXMLInt(xml, "goodNeighbours.settings#fieldsPerCall", S.settings.fieldsPerCall)
	setXMLBool(xml, "goodNeighbours.settings#npcWork", S.settings.npcWork ~= false)
	GN.safeCall("save fleets", GN.Work.saveToXML, xml)
	GN.safeCall("save borrows", GN.Borrow.saveToXML, xml)
	GN.safeCall("save cars", GN.Situ.saveToXML, xml)
	GN.safeCall("save supplies", GN.Supply.saveToXML, xml)
	local ids = {}
	for id in pairs(S.assign) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for i, id in ipairs(ids) do
		local k = string.format("goodNeighbours.farmlands.farmland(%d)", i - 1)
		setXMLInt(xml, k .. "#id", id)
		setXMLInt(xml, k .. "#neighbour", S.assign[id])
	end
	local i = 0
	for nid, h in pairs(S.home) do
		local k = string.format("goodNeighbours.homes.home(%d)", i)
		setXMLInt(xml, k .. "#neighbour", nid)
		setXMLFloat(xml, k .. "#x", h.x)
		setXMLFloat(xml, k .. "#z", h.z)
		setXMLFloat(xml, k .. "#ry", h.ry or 0)
		setXMLBool(xml, k .. "#auto", h.auto == true)
		i = i + 1
	end
	i = 0
	for nid, list in pairs(S.slots) do
		for _, p in ipairs(list) do
			local k = string.format("goodNeighbours.slots.slot(%d)", i)
			setXMLInt(xml, k .. "#neighbour", nid)
			setXMLFloat(xml, k .. "#x", p.x)
			setXMLFloat(xml, k .. "#z", p.z)
			setXMLFloat(xml, k .. "#ry", p.ry or 0)
			setXMLString(xml, k .. "#size", p.size or "attach")
			setXMLBool(xml, k .. "#auto", p.auto == true)
			i = i + 1
		end
	end
	i = 0
	for nid, rec in pairs(S.farmBuildings) do
		local k = string.format("goodNeighbours.buildings.neighbour(%d)", i)
		setXMLInt(xml, k .. "#id", nid)
		setXMLString(xml, k .. "#silo", tostring(rec.silo or ""))
		setXMLString(xml, k .. "#shed", tostring(rec.shed or ""))
		i = i + 1
	end
	i = 0
	for _, b in ipairs(S.buildingAreas) do
		local k = string.format("goodNeighbours.buildingAreas.area(%d)", i)
		setXMLFloat(xml, k .. "#x", b.x)
		setXMLFloat(xml, k .. "#z", b.z)
		setXMLFloat(xml, k .. "#ry", b.ry or 0)
		setXMLFloat(xml, k .. "#len", b.len)
		setXMLFloat(xml, k .. "#side", b.side)
		i = i + 1
	end
	i = 0
	for _, p in ipairs(S.places) do
		local k = string.format("goodNeighbours.places.place(%d)", i)
		setXMLString(xml, k .. "#type", p.type)
		setXMLFloat(xml, k .. "#x", p.x)
		setXMLFloat(xml, k .. "#z", p.z)
		setXMLFloat(xml, k .. "#ry", p.ry or 0)
		setXMLBool(xml, k .. "#auto", p.auto == true)
		if p.farmId ~= nil then
			setXMLInt(xml, k .. "#farm", p.farmId)
		end
		i = i + 1
	end
	i = 0
	for nid, p in pairs(S.parking) do
		local k = string.format("goodNeighbours.parking.place(%d)", i)
		setXMLInt(xml, k .. "#neighbour", nid)
		setXMLFloat(xml, k .. "#x", p.x)
		setXMLFloat(xml, k .. "#z", p.z)
		setXMLFloat(xml, k .. "#ry", p.ry or 0)
		i = i + 1
	end
	i = 0
	for nid, outfit in pairs(S.styles) do
		local k = string.format("goodNeighbours.styles.style(%d)", i)
		setXMLInt(xml, k .. "#neighbour", nid)
		local j = 0
		for key, v in pairs(outfit) do
			local ik = string.format("%s.item(%d)", k, j)
			setXMLString(xml, ik .. "#config", key)
			setXMLInt(xml, ik .. "#item", v.item or 0)
			setXMLInt(xml, ik .. "#color", v.color or 1)
			j = j + 1
		end
		i = i + 1
	end
	i = 0
	for farmId, list in pairs(S.rel) do
		for nid, r in pairs(list) do
			local k = string.format("goodNeighbours.relations.relation(%d)", i)
			setXMLInt(xml, k .. "#farm", farmId)
			setXMLInt(xml, k .. "#neighbour", nid)
			setXMLInt(xml, k .. "#level", r.level)
			setXMLInt(xml, k .. "#points", r.points)
			i = i + 1
		end
	end
	i = 0
	local function saveTracked(t)
		if t.fieldId == nil then return end
		local k = string.format("goodNeighbours.contracts.contract(%d)", i)
		setXMLInt(xml, k .. "#field", t.fieldId)
		setXMLInt(xml, k .. "#farm", t.farmId)
		setXMLInt(xml, k .. "#neighbour", t.nid)
		setXMLFloat(xml, k .. "#bonus", t.bonus or 0)
		setXMLFloat(xml, k .. "#refund", t.refund or 0)
		setXMLBool(xml, k .. "#lent", t.lent == true)
		if t.deadline ~= nil then
			setXMLInt(xml, k .. "#deadline", t.deadline)
		end
		setXMLBool(xml, k .. "#awaiting", t.awaiting == true)
		if t.pay ~= nil then
			setXMLInt(xml, k .. "#pay", t.pay)
		end
		i = i + 1
	end
	for _, t in ipairs(S.tracked) do saveTracked(t) end
	for _, t in ipairs(S.pendingTracked) do saveTracked(t) end
	saveXMLFile(xml)
	delete(xml)
end

S.reset()
