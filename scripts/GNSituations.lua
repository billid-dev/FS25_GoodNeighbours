-- Good Neighbours (FS25) - what the neighbours do during the day, with their vehicles (server)
--   * every neighbour has a car; farmers also go with the tractor to the filling station, the workshop or the grain trade
--   * when the day plan sends him somewhere, his car / tractor stands there; afterwards it goes home again
--   * he visits players' farm yards: the players of that farm get a message and can talk to him
-- Author: billiD

local GN = GoodNeighbours

GN.Situ = GN.Situ or {}
local U = GN.Situ

U.CAR_CATEGORIES = { "CARS" }
U.CHECK_MS = 5000
U.TRACTOR_PLACES = { gas = true, workshop = true, trade = true }

function U.reset()
	U.cars = {}          -- nid -> vehicle
	U.carSpawning = {}
	U.carFailed = {}
	U.savedCars = {}     -- nid -> uniqueId from the savegame
	U.away = {}          -- nid -> { veh, key }
	U.visits = {}        -- nid -> "day|farm" of the last visit message
	U.timer = 0
end

-- ---------------------------------------------------------------------------
-- Cars
-- ---------------------------------------------------------------------------

local function homePoseFor(nid, role)
	local W = GN.Work
	local fleet = W.fleets[nid]
	local jobs = fleet ~= nil and W.sortedJobs(fleet.tools) or {}
	local poses = W.assignPoses(nid, jobs, fleet ~= nil and fleet.combine ~= nil, true)
	return poses[role]
end

function U.ensureCar(nid)
	local W = GN.Work
	if U.cars[nid] ~= nil or U.carSpawning[nid] or U.carFailed[nid] or GN.Server.home[nid] == nil then
		return
	end
	if GN.Auto ~= nil and not GN.Auto.done then
		return
	end
	local n = GN.getNeighbour(nid)
	local uid = U.savedCars[nid]
	if uid ~= nil then
		for _, v in pairs(g_currentMission.vehicleSystem ~= nil and g_currentMission.vehicleSystem.vehicles or {}) do
			if v.uniqueId == uid then
				U.cars[nid] = v
				GN.World.setVehicleState(v, nid, nil)
				return
			end
		end
	end
	local pick = nil
	for _, e in ipairs(W.FLEETS ~= nil and W.FLEETS[nid] or {}) do
		if e.role == "car" then
			pick = W.storeItemByFile(e.file)
		end
	end
	if pick == nil then
		local items = W.storeItemsIn(U.CAR_CATEGORIES)
		if #items == 0 then
			U.carFailed[nid] = true
			GN.log("situations: no car in the shop for %s", n.name)
			return
		end
		-- the cheaper half of the cars, a different one for everybody
		pick = items[((nid * 7) % math.max(1, math.ceil(#items / 2))) + 1]
	end
	local pose = homePoseFor(nid, "car")
	if pose == nil then
		return
	end
	U.carSpawning[nid] = true
	W.spawnVehicle(pick.xmlFilename, pose.x, pose.y, pose.z, pose.ry, function(v)
		U.carSpawning[nid] = nil
		if v ~= nil then
			U.cars[nid] = v
			GN.World.setVehicleState(v, nid, nil)
			GN.log("situations: %s got a car (%s)", n.name, tostring(pick.xmlFilename))
		else
			U.carFailed[nid] = true
			GN.log("situations: could not buy a car for %s", n.name)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Vehicles at the places of the day plan
-- ---------------------------------------------------------------------------

--- Is this vehicle (or any of the neighbour's) away from home right now?
function U.isAway(nid, vehicle)
	local a = U.away[nid]
	return a ~= nil and (vehicle == nil or a.veh == vehicle)
end

local function vehicleFor(n, place)
	if place == nil or place == "walk" then
		return nil
	end
	if n.contracts and U.TRACTOR_PLACES[place] then
		return "tractor"
	end
	return "car"
end

local function placeRotation(x, z)
	local best, bestD = 0, 30 * 30
	for _, p in ipairs(GN.Server.places) do
		local d = (p.x - x) ^ 2 + (p.z - z) ^ 2
		if d < bestD then
			best, bestD = p.ry or 0, d
		end
	end
	return best
end

local function busy(v)
	if not GN.Work.isAlive(v) or v.gnBorrowFarm ~= nil then
		return true
	end
	if v.getIsAIActive ~= nil and v:getIsAIActive() then
		return true
	end
	if v.getIsControlled ~= nil and v:getIsControlled() then
		return true -- a player sits in it
	end
	return false
end

function U.sendBack(nid)
	local a = U.away[nid]
	if a == nil then
		return
	end
	U.away[nid] = nil
	local v = a.veh
	if GN.Work.isAlive(v) then
		v.gnAway = nil
		if v == U.cars[nid] then
			local pose = homePoseFor(nid, "car")
			if pose ~= nil and not busy(v) then
				GN.Work.teleport(v, pose.x, pose.y, pose.z, pose.ry)
			end
		elseif GN.Work.active[nid] == nil then
			GN.Work.parkAll(nid)
		end
	end
end

function U.updateNeighbour(n)
	local W, S = GN.Work, GN.Server
	U.ensureCar(n.id)
	local cur = GN.Plan.current(n.id)
	local x, z = GN.Plan.position(n.id, S.places)
	local want = (cur ~= nil and cur.visible and x ~= nil) and vehicleFor(n, cur.place) or nil
	local veh = nil
	if want == "tractor" then
		local fleet = W.fleets[n.id]
		local t = fleet ~= nil and fleet.tractor or nil
		if t ~= nil and W.active[n.id] == nil and not busy(t) then
			veh = t
		else
			want = "car" -- tractor busy in the field: he comes by car
		end
	end
	if want == "car" then
		local c = U.cars[n.id]
		if c ~= nil and not busy(c) then
			veh = c
		end
	end
	local key = veh ~= nil and string.format("%s|%.0f|%.0f", tostring(cur.place), x, z) or nil
	local a = U.away[n.id]
	if veh ~= nil and (a == nil or a.key ~= key or a.veh ~= veh) then
		if a ~= nil then
			U.sendBack(n.id)
		end
		-- next to the place, a bit to the side, every neighbour on his own spot
		local ry = placeRotation(x, z)
		local side = 6 + (n.id % 3) * 4.5
		local px, pz = x + math.cos(ry) * side, z - math.sin(ry) * side
		local py = (g_terrainNode ~= nil and getTerrainHeightAtWorldPos(g_terrainNode, px, 0, pz) or 0) + 0.3
		if veh == (W.fleets[n.id] ~= nil and W.fleets[n.id].tractor or nil) and veh.getAttachedImplements ~= nil then
			for _, impl in ipairs(veh:getAttachedImplements() or {}) do
				if impl.object ~= nil and impl.object.gnBorrowFarm == nil then
					GN.try(veh.detachImplementByObject, veh, impl.object)
				end
			end
		end
		W.teleport(veh, px, py, pz, ry)
		veh.gnAway = true
		U.away[n.id] = { veh = veh, key = key }
		GN.log("situations: %s %s (%s)", n.name, tostring(cur.key), tostring(cur.place))
	elseif veh == nil and a ~= nil then
		U.sendBack(n.id)
	end
	-- a visit at a player's farm: tell that farm
	if cur ~= nil and cur.place == "visit" and x ~= nil then
		local t = GN.Plan.visitTarget(n.id)
		if t ~= nil then
			local k = tostring(GN.getDay()) .. "|" .. tostring(t.farmId) .. "|" .. tostring(cur.from)
			if U.visits[n.id] ~= k then
				U.visits[n.id] = k
				GN.sendToFarm(t.farmId, "visitor", { nid = n.id })
				GN.log("situations: %s visits farm %d", n.name, t.farmId)
			end
		end
	end
end

function U.update(dt)
	if g_currentMission == nil or not GN.Server.loaded then
		return
	end
	U.timer = U.timer + (dt or 0)
	if U.timer < U.CHECK_MS then
		return
	end
	U.timer = 0
	for _, n in ipairs(GN.neighbours) do
		if GN.Server.home[n.id] ~= nil then
			GN.safeCall("situation " .. n.name, U.updateNeighbour, n)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Savegame
-- ---------------------------------------------------------------------------

function U.saveToXML(xml)
	local i = 0
	for nid, v in pairs(U.cars) do
		if GN.Work.isAlive(v) and v.uniqueId ~= nil then
			local k = string.format("goodNeighbours.cars.car(%d)", i)
			setXMLInt(xml, k .. "#neighbour", nid)
			setXMLString(xml, k .. "#vehicle", v.uniqueId)
			i = i + 1
		end
	end
end

function U.loadFromXML(xml)
	local i = 0
	while true do
		local k = string.format("goodNeighbours.cars.car(%d)", i)
		if not hasXMLProperty(xml, k) then
			break
		end
		local nid, uid = getXMLInt(xml, k .. "#neighbour"), getXMLString(xml, k .. "#vehicle")
		if nid ~= nil and uid ~= nil then
			U.savedCars[nid] = uid
		end
		i = i + 1
	end
end

U.reset()
