-- Good Neighbours (FS25) - neighbours work their own fields with their own machines
--
-- Server:
--   * a farm for the neighbours (they own their machines; it is not a player farm)
--   * every farming neighbour gets a tractor and a set of implements from the shop, parked at home
--   * an open contract on a neighbour's field that no player took is done by the neighbour himself:
--     the implement is attached, filled, and the AI helper drives out and works the field; afterwards
--     the machines are parked at home again and the contract disappears
-- Clients:
--   * the driver in a working neighbour's tractor looks like the neighbour (outfit from the phone)
--
-- Everything here is protected: when something fails, the neighbour simply does not drive and the
-- rest of the mod keeps working. All steps are logged with "work:".
-- Author: billiD

local GN = GoodNeighbours

GN.Work = GN.Work or {}
local W = GN.Work

W.NPC_FARM_ID = 15
W.LAST_START_MINUTE = 19 * 60     -- no new field work after 19:00 (the start time changes every day)
W.END_MINUTE = 22 * 60           -- nobody works the fields after 22:00
W.STUCK_MS = 120000               -- not moved for 2 minutes: stuck
W.CHECK_MS = 10000
W.MAX_WORK_MS = 3 * 3600 * 1000  -- real time safety limit for one job
W.PARK_SPACING = 9

-- jobs the neighbours can do themselves: job key -> shop categories of the implement + fill type
W.JOBS = {
	cultivate = { categories = { "CULTIVATORS", "DISCHARROWS" } },
	plow      = { categories = { "PLOWS" } },
	sow       = { categories = { "SEEDERS", "PLANTERS" }, fill = "SEEDS" },
	fertilize = { categories = { "FERTILIZERSPREADERS" }, fill = "FERTILIZER" },
	spray     = { categories = { "SPRAYERS" }, fill = "HERBICIDE" },
	weed      = { categories = { "WEEDERS" } },
	roll      = { categories = { "ROLLERS" } },
	lime      = { categories = { "FERTILIZERSPREADERS" }, fill = "LIME" },
	mow       = { categories = { "MOWERS" } },
	tedd      = { categories = { "TEDDERS" } },
	bale      = { categories = { "BALERS" } },
	-- harvest: the header goes on the neighbour's combine; the grain tank is emptied while he drives
	-- (as if a trailer took it away), so no unloading trailer is needed
	harvest   = { categories = { "CUTTERS" }, puller = "combine" },
}
W.COMBINE_CATEGORIES = { "HARVESTERS" }
W.HARVEST_DRAIN_SHARE = 0.6
W.TRACTOR_CATEGORIES = { "TRACTORSL", "TRACTORSM" }

function W.reset()
	GN.safeCall("fleets", W.loadFleets)
	W.fleets = {}        -- nid -> { tractor = vehicle, tools = { [job] = vehicle }, spawning = n }
	W.savedIds = {}      -- nid -> { tractor = uniqueId, tools = { [job] = uniqueId } } from the savegame
	W.active = {}        -- nid -> { mission, job, tool, tractor, farmlandId, ownerBefore, started, seenActive }
	W.timer = 0
	W.enabled = true
	W.fleetFailed = {}
	W.pendingOwnership = nil
	W.drivers = {}
	W.failedToday = setmetatable({}, { __mode = "k" })
end

-- ---------------------------------------------------------------------------
-- The neighbours' farm
-- ---------------------------------------------------------------------------

function W.ensureFarm()
	if g_farmManager == nil then
		return false
	end
	local farm = g_farmManager:getFarmById(W.NPC_FARM_ID)
	if farm == nil then
		local password = tostring(math.random(100000000, 999999999))
		local ok, err = GN.try(g_farmManager.createFarm, g_farmManager, GN.text("gn_npc_farm", "Neighbours"), 6, password, W.NPC_FARM_ID)
		farm = g_farmManager:getFarmById(W.NPC_FARM_ID)
		GN.log("work: neighbours' farm %d created: %s%s", W.NPC_FARM_ID, tostring(farm ~= nil), ok and "" or (" (" .. tostring(err) .. ")"))
	end
	if farm ~= nil and farm.getBalance ~= nil then
		local okB, balance = GN.try(farm.getBalance, farm)
		-- practically unlimited: the game never takes anything away from the neighbours for lack of money
		if okB and (balance or 0) < 50000000 and g_currentMission.addMoney ~= nil then
			GN.try(g_currentMission.addMoney, g_currentMission, 100000000, W.NPC_FARM_ID, MoneyType ~= nil and MoneyType.OTHER or nil, false)
		end
	end
	return farm ~= nil
end

-- ---------------------------------------------------------------------------
-- Choosing machines from the shop
-- ---------------------------------------------------------------------------

local function inList(list, v)
	for _, x in ipairs(list) do
		if x == v then
			return true
		end
	end
	return false
end

local function storeItemsIn(categories)
	local out = {}
	for _, item in ipairs(g_storeManager ~= nil and g_storeManager:getItems() or {}) do
		local cat = item.categoryName ~= nil and string.upper(tostring(item.categoryName)) or ""
		-- base game machines only (mods may be missing on other servers)
		if inList(categories, cat) and item.customEnvironment == nil and item.xmlFilename ~= nil
			and item.showInStore ~= false and (item.price or 0) > 0 then
			table.insert(out, item)
		end
	end
	table.sort(out, function(a, b) return (a.price or 0) < (b.price or 0) end)
	return out
end

local function powerOf(item)
	local s = item.specs
	return tonumber(s ~= nil and (s.power or s.maxPower) or nil)
end

local function neededPowerOf(item)
	local s = item.specs
	return tonumber(s ~= nil and s.neededPower or nil)
end

-- ---------------------------------------------------------------------------
-- Fixed machines per neighbour (data/fleets.xml)
-- ---------------------------------------------------------------------------

function W.loadFleets()
	W.FLEETS = {}
	local path = Utils.getFilename("data/fleets.xml", GN.dir)
	if path == nil or not fileExists(path) then
		return
	end
	local xml = loadXMLFile("gnFleets", path)
	if xml == nil or xml == 0 then
		return
	end
	local i = 0
	while true do
		local k = string.format("fleets.fleet(%d)", i)
		if not hasXMLProperty(xml, k) then break end
		local nid = getXMLInt(xml, k .. "#neighbour")
		local list = {}
		local j = 0
		while true do
			local vk = string.format("%s.vehicle(%d)", k, j)
			if not hasXMLProperty(xml, vk) then break end
			table.insert(list, { role = getXMLString(xml, vk .. "#role") or "extra", job = getXMLString(xml, vk .. "#job"),
				size = getXMLString(xml, vk .. "#size") or "attach", file = getXMLString(xml, vk .. "#file") })
			j = j + 1
		end
		if nid ~= nil then
			W.FLEETS[nid] = list
		end
		i = i + 1
	end
	delete(xml)
end

--- Shop item of a game vehicle file (letter case of the folders may differ).
function W.storeItemByFile(file)
	if file == nil or g_storeManager == nil then
		return nil
	end
	local item = g_storeManager.getItemByXMLFilename ~= nil and g_storeManager:getItemByXMLFilename(file) or nil
	if item ~= nil then
		return item
	end
	W._lowerItems = W._lowerItems or {}
	if next(W._lowerItems) == nil then
		for _, it in ipairs(g_storeManager:getItems() or {}) do
			if it.xmlFilename ~= nil then
				W._lowerItems[string.lower(it.xmlFilename)] = it
			end
		end
	end
	local want = string.lower(file)
	for f, it in pairs(W._lowerItems) do
		if f == want or string.sub(f, -#want) == want then
			return it
		end
	end
	return nil
end

--- The implement for a job (liming is done with the fertilizer spreader).
function W.toolFor(fleet, job)
	if fleet == nil then
		return nil
	end
	return fleet.tools[job] or (job == "lime" and fleet.tools.fertilize or nil)
end

--- Fixed machines: tractor, tools by job, combine, extras { item, size } (car comes with GN.Situ).
local function chooseFixedFleet(nid)
	local list = W.FLEETS ~= nil and W.FLEETS[nid] or nil
	if list == nil then
		return nil
	end
	local tractor, combine, tools, extras = nil, nil, {}, {}
	for _, e in ipairs(list) do
		local item = W.storeItemByFile(e.file)
		if item == nil then
			GN.log("work: %s is not in the shop", tostring(e.file))
		elseif e.role == "tractor" then
			tractor = item
		elseif e.role == "combine" then
			combine = item
		elseif e.role == "tool" and e.job ~= nil and W.JOBS[e.job] ~= nil then
			tools[e.job] = item
		elseif e.role == "extra" then
			table.insert(extras, { item = item, size = e.size })
		end
	end
	return tractor, tools, combine, extras
end
W.chooseFixedFleet = chooseFixedFleet

--- Pick a mid-range tractor and, for every job, a cheap-to-mid implement it can pull.
--- Different neighbours get different machines (offset by their id).
function W.chooseFleet(nid)
	if W.FLEETS ~= nil and W.FLEETS[nid] ~= nil then
		return chooseFixedFleet(nid)
	end
	local tractors = storeItemsIn(W.TRACTOR_CATEGORIES)
	if #tractors == 0 then
		return nil
	end
	local good = {}
	for _, t in ipairs(tractors) do
		local p = powerOf(t)
		if p == nil or (p >= 150 and p <= 320) then
			table.insert(good, t)
		end
	end
	if #good == 0 then
		good = tractors
	end
	local tractor = good[((nid - 1) % #good) + 1]
	local hp = powerOf(tractor) or 200
	local tools = {}
	local combine = nil
	local combines = storeItemsIn(W.COMBINE_CATEGORIES)
	if #combines > 0 then
		local half = math.max(1, math.ceil(#combines / 2))
		combine = combines[((nid - 1) % half) + 1]
	end
	for job, def in pairs(W.JOBS) do
		if def.puller == "combine" then
			-- grain header, same brand as the combine when there is one (headers fit their own combines)
			if combine ~= nil then
				local same, any = nil, nil
				for _, it in ipairs(storeItemsIn(def.categories)) do
					local f = string.lower(tostring(it.xmlFilename))
					local isGrain = not (string.find(f, "corn", 1, true) or string.find(f, "maize", 1, true) or string.find(f, "mais", 1, true)
						or string.find(f, "sunflower", 1, true) or string.find(f, "potato", 1, true) or string.find(f, "beet", 1, true))
					if isGrain then
						any = any or it
						if same == nil and it.brandIndex ~= nil and it.brandIndex == combine.brandIndex then
							same = it
						end
					end
				end
				tools[job] = same or any
			end
		else
		local fit = {}
		for _, it in ipairs(storeItemsIn(def.categories)) do
			local need = neededPowerOf(it)
			if need == nil or need <= hp then
				table.insert(fit, it)
			end
		end
		if #fit > 0 then
			local half = math.max(1, math.ceil(#fit / 2))
			tools[job] = fit[((nid - 1) % half) + 1]
		end
		end
	end
	return tractor, tools, combine
end

-- ---------------------------------------------------------------------------
-- Spawning and parking
-- ---------------------------------------------------------------------------

--- Fallback pose number <slot> when no fitting machine place was set with the construction tool:
--- the admin parking row, else a row next to the home.
local function rowPose(nid, slot)
	local x, z, ry
	local p = GN.Server.parking[nid]
	if p ~= nil then
		-- admin-set parking: machines side by side to the right, all facing the same way
		ry = p.ry or 0
		local rx, rz = math.cos(ry), -math.sin(ry)
		x = p.x + rx * slot * W.PARK_SPACING
		z = p.z + rz * slot * W.PARK_SPACING
	else
		local h = GN.Server.home[nid]
		if h == nil then
			return nil
		end
		x, z, ry = h.x + 12 + slot * W.PARK_SPACING, h.z + 12, 0
	end
	local y = g_terrainNode ~= nil and getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z) or 0
	return x, y + 0.3, z, ry
end

local function sortedJobs(tools)
	local jobs = {}
	for job in pairs(tools or {}) do
		table.insert(jobs, job)
	end
	table.sort(jobs)
	return jobs
end

--- Which place every machine of the neighbour stands on.
--- Places are set with the construction tool in sizes: the combine takes an oversize place, the tractor a vehicle
--- place, the implements vehicle+attachment places; a machine without a fitting place goes to the fallback row.
--- Returns role -> { x, y, z, ry }; roles: "tractor", "combine", "tool:<job>".
function W.assignPoses(nid, jobs, hasCombine, hasCar, extras, strict)
	local free = { vehicle = {}, attach = {}, oversize = {} }
	for _, p in ipairs(GN.Server.slots[nid] or {}) do
		local list = free[p.size or "attach"]
		if list ~= nil then
			table.insert(list, p)
		end
	end
	local function take(order)
		for _, k in ipairs(order) do
			if #free[k] > 0 then
				return table.remove(free[k], 1)
			end
		end
		return nil
	end
	local roles = {}
	if hasCombine then
		table.insert(roles, { key = "combine", order = { "oversize", "attach" } })
	end
	table.insert(roles, { key = "tractor", order = { "vehicle", "attach", "oversize" } })
	if hasCar ~= false then
		table.insert(roles, { key = "car", order = { "vehicle", "attach", "oversize" } })
	end
	for _, job in ipairs(jobs or {}) do
		table.insert(roles, { key = "tool:" .. job, order = { "attach", "oversize", "vehicle" } })
	end
	if extras == nil then
		local f = W.fleets[nid]
		extras = {}
		for i, e in ipairs(f ~= nil and f.extras or {}) do
			extras[i] = e.size
		end
	end
	for i, size in ipairs(extras) do
		local order = size == "oversize" and { "oversize", "attach" } or size == "vehicle" and { "vehicle", "attach", "oversize" } or { "attach", "oversize", "vehicle" }
		table.insert(roles, { key = "extra:" .. i, order = order })
	end
	local out, row = {}, 0
	for _, r in ipairs(roles) do
		local p = take(r.order)
		if p ~= nil then
			-- the machine stands in the middle of its place box (the place point is the front of the box)
			local ry = p.ry or 0
			local box = GN.Tools ~= nil and GN.Tools.BOX ~= nil and GN.Tools.BOX[p.size or "attach"] or nil
			local mid = box ~= nil and ((GN.Tools.FRONT or 3) - box.len / 2) or 0
			local x, z = p.x + mid * math.sin(ry), p.z + mid * math.cos(ry)
			local y = g_terrainNode ~= nil and getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z) or 0
			out[r.key] = { x = x, y = y + 0.3, z = z, ry = ry }
		elseif not strict then
			local x, y, z, ry = rowPose(nid, row)
			row = row + 1
			if x ~= nil then
				out[r.key] = { x = x, y = y, z = z, ry = ry }
			end
		end
	end
	return out
end

--- Places the neighbour needs per size (shown in the construction view as "set / needed").
function W.requiredPlaces(nid)
	local n = GN.getNeighbour(nid)
	if n == nil then
		return { home = 1, vehicle = 0, attach = 0, oversize = 0, silo = 0 }
	end
	if not n.contracts and (W.FLEETS == nil or W.FLEETS[nid] == nil) then
		return { home = 1, vehicle = 1, attach = 0, oversize = 0, silo = 0 } -- his car
	end
	local list = W.FLEETS ~= nil and W.FLEETS[nid] or nil
	if list ~= nil then
		local r = { home = 1, vehicle = 0, attach = 0, oversize = 0, silo = n.contracts and 1 or 0 }
		for _, e in ipairs(list) do
			r[e.size] = (r[e.size] or 0) + 1
		end
		return r
	end
	local fleet = W.fleets[nid]
	local tools, combine = 0, 1
	if fleet ~= nil and fleet.tractor ~= nil then
		for _ in pairs(fleet.tools) do
			tools = tools + 1
		end
		combine = fleet.combine ~= nil and 1 or 0
	else
		for _ in pairs(W.JOBS) do
			tools = tools + 1
		end
	end
	return { home = 1, vehicle = 2, attach = tools, oversize = combine, silo = 1 } -- tractor + car
end

W.storeItemsIn = function(c) return storeItemsIn(c) end
W.sortedJobs = sortedJobs

local function vehicleName(v)
	if v ~= nil and v.getName ~= nil then
		local ok, n = GN.try(v.getName, v)
		if ok and n ~= nil then
			return n
		end
	end
	return "?"
end

local function isAlive(v)
	return v ~= nil and not v.isDeleted and v.rootNode ~= nil and entityExists(v.rootNode)
end
W.isAlive = isAlive
W.vehicleName = vehicleName

local function spawnVehicle(xmlFilename, x, y, z, ry, callback)
	if VehicleLoadingData == nil then
		callback(nil)
		return
	end
	local data = VehicleLoadingData.new()
	data:setFilename(xmlFilename)
	data:setPosition(x, y, z)
	data:setRotation(0, ry or 0, 0)
	data:setOwnerFarmId(W.NPC_FARM_ID)
	if data.setPropertyState ~= nil and VehiclePropertyState ~= nil then
		GN.try(data.setPropertyState, data, VehiclePropertyState.OWNED)
	end
	data:load(function(_, vehicles, loadingState)
		local v = vehicles ~= nil and vehicles[1] or nil
		if loadingState ~= nil and VehicleLoadingState ~= nil and loadingState ~= VehicleLoadingState.OK then
			v = nil
		end
		if v ~= nil then
			-- put it down on the ground again (no flying machines when it appeared a bit too high or touching another)
			W.teleport(v, x, y, z, ry)
		end
		callback(v)
	end)
end

W.spawnVehicle = function(...) return spawnVehicle(...) end
W.isAlive = function(v) return isAlive(v) end

function W.teleport(v, x, y, z, ry)
	if not isAlive(v) then
		return
	end
	GN.try(function()
		if v.isAddedToPhysics ~= false and v.removeFromPhysics ~= nil then
			v:removeFromPhysics()
		end
		v:setRelativePosition(x, 0.5, z, ry or 0, true)
		v:addToPhysics()
		if v.raiseActive ~= nil then
			v:raiseActive()
		end
	end)
	-- a moment later: still out of physics (hanging in the air)? put it in again
	W.physicsCheck = W.physicsCheck or {}
	W.physicsCheck[v] = { at = (g_time or 0) + 2500, x = x, z = z, ry = ry or 0, tries = 0 }
end

--- Machines that were moved: are they standing on the ground (in physics)? (every frame, cheap)
function W.checkPhysics()
	if W.physicsCheck == nil then
		return
	end
	local now = g_time or 0
	for v, c in pairs(W.physicsCheck) do
		if not isAlive(v) then
			W.physicsCheck[v] = nil
		elseif now >= c.at then
			W.physicsCheck[v] = nil
			local floating = v.isAddedToPhysics == false
			if not floating and v.rootNode ~= nil and g_terrainNode ~= nil then
				local px, py, pz = getWorldTranslation(v.rootNode)
				local ty = getTerrainHeightAtWorldPos(g_terrainNode, px, 0, pz)
				-- not attached to anything and far above the ground: hanging
				local attached = v.getAttacherVehicle ~= nil and v:getAttacherVehicle() ~= nil
				floating = not attached and py - ty > 3.5
			end
			if floating and c.tries < 3 then
				GN.try(function()
					if v.isAddedToPhysics ~= false then
						v:removeFromPhysics()
					end
					v:setRelativePosition(c.x, 0.2, c.z, c.ry, true)
					v:addToPhysics()
					if v.raiseActive ~= nil then
						v:raiseActive()
					end
				end)
				W.physicsCheck[v] = { at = now + 2500, x = c.x, z = c.z, ry = c.ry, tries = c.tries + 1 }
				GN.log("work: %s was hanging in the air - put down again", vehicleName(v))
			end
		end
	end
end

--- Role key -> machine of a fleet (roles: tractor, combine, tool:<job>, extra:<i>).
local function roleGet(fleet, role)
	if role == "tractor" then
		return fleet.tractor
	elseif role == "combine" then
		return fleet.combine
	elseif string.sub(role, 1, 5) == "tool:" then
		return fleet.tools[string.sub(role, 6)]
	elseif string.sub(role, 1, 6) == "extra:" then
		local e = fleet.extras[tonumber(string.sub(role, 7))]
		return e ~= nil and e.v or nil
	end
	return nil
end

local function roleSet(fleet, role, v)
	if role == "tractor" then
		fleet.tractor = v
	elseif role == "combine" then
		fleet.combine = v
	elseif string.sub(role, 1, 5) == "tool:" then
		fleet.tools[string.sub(role, 6)] = v
	elseif string.sub(role, 1, 6) == "extra:" then
		local i = tonumber(string.sub(role, 7))
		fleet.extras[i] = fleet.extras[i] or { size = "attach" }
		fleet.extras[i].v = v
	end
end

--- Shop item of every role of the neighbour's fleet.
local function fleetItems(nid)
	local tractor, tools, combine, extras = W.chooseFleet(nid)
	local items = { roles = {}, jobs = sortedJobs(tools), hasCombine = combine ~= nil, extraSizes = {} }
	if tractor ~= nil then
		items.roles.tractor = tractor
	end
	if combine ~= nil then
		items.roles.combine = combine
	end
	for job, it in pairs(tools or {}) do
		items.roles["tool:" .. job] = it
	end
	for i, e in ipairs(extras or {}) do
		items.roles["extra:" .. i] = e.item
		items.extraSizes[i] = e.size or "attach"
	end
	return items, tractor, tools, combine
end

--- The machine is in use and must not be moved or removed now.
local function inUse(v)
	if not isAlive(v) then
		return false
	end
	if v.gnBorrowFarm ~= nil or v.gnAway then
		return true
	end
	if v.getIsAIActive ~= nil and v:getIsAIActive() then
		return true
	end
	if v.getIsControlled ~= nil and v:getIsControlled() then
		return true
	end
	local holder = v.getAttacherVehicle ~= nil and v:getAttacherVehicle() or nil
	if holder ~= nil and holder.gnNid == nil then
		return true -- hitched by a player
	end
	return false
end
W.inUse = inUse

--- Every machine stands on its own place: a place without its machine gets it (bought / spawned now),
--- a machine without a place is taken away, a machine away from its place drives home (teleport).
function W.syncPlaces(nid)
	local fleet = W.fleets[nid]
	if fleet == nil or fleet.items == nil then
		return
	end
	if W.active[nid] ~= nil then
		fleet.syncLater = true
		return
	end
	fleet.syncLater = nil
	local n = GN.getNeighbour(nid)
	local items = fleet.items
	local poses = W.assignPoses(nid, items.jobs, items.hasCombine, true, items.extraSizes, true)
	local changed = false
	for role, item in pairs(items.roles) do
		local v = roleGet(fleet, role)
		local pose = poses[role]
		if pose == nil then
			if isAlive(v) and not inUse(v) then
				-- his place was taken away: the machine goes with it
				local holder = v.getAttacherVehicle ~= nil and v:getAttacherVehicle() or nil
				if holder ~= nil then
					GN.try(holder.detachImplementByObject, holder, v)
				end
				GN.log("work: %s's %s left with its place", n.name, vehicleName(v))
				GN.try(v.delete, v)
				roleSet(fleet, role, nil)
				changed = true
			elseif v ~= nil and not isAlive(v) then
				roleSet(fleet, role, nil)
			end
		elseif not isAlive(v) then
			if not (fleet.spawningRole or {})[role] then
				fleet.spawningRole = fleet.spawningRole or {}
				fleet.spawningRole[role] = true
				fleet.spawning = (fleet.spawning or 0) + 1
				spawnVehicle(item.xmlFilename, pose.x, pose.y, pose.z, pose.ry, function(nv)
					fleet.spawningRole[role] = nil
					fleet.spawning = fleet.spawning - 1
					if nv ~= nil then
						if W.fleets[nid] ~= fleet then
							GN.try(nv.delete, nv)
							return
						end
						roleSet(fleet, role, nv)
						GN.World.setVehicleState(nv, nid, nil)
						GN.log("work: %s got %s", n.name, vehicleName(nv))
					else
						GN.log("work: could not buy %s for %s", tostring(item.xmlFilename), n.name)
					end
					if fleet.spawning == 0 then
						GN.safeCall("places update", function() GN.sendToAll("homes", GN.Server.worldMsg()) end)
					end
				end)
			end
		elseif not inUse(v) and v.rootNode ~= nil and not (v.getAttacherVehicle ~= nil and v:getAttacherVehicle() ~= nil) then
			-- (a machine hitched to his own puller - the header on the combine - goes with it)
			local x, _, z = getWorldTranslation(v.rootNode)
			if (x - pose.x) ^ 2 + (z - pose.z) ^ 2 > 2.5 * 2.5 then
				-- a combine with its header: uncouple, move, couple again in front (no stretched joints)
				local header = nil
				if role == "combine" and v.getAttachedImplements ~= nil then
					for _, impl in ipairs(v:getAttachedImplements() or {}) do
						if impl.object ~= nil and impl.object.gnBorrowFarm == nil then
							header = impl.object
							GN.try(v.detachImplementByObject, v, header)
						end
					end
				end
				W.teleport(v, pose.x, pose.y, pose.z, pose.ry)
				if header ~= nil then
					W.attach(v, header, true)
				end
			end
		end
	end
	if changed then
		GN.safeCall("places update", function() GN.sendToAll("homes", GN.Server.worldMsg()) end)
	end
end

--- Places changed (construction tool): all neighbours who are not working right now follow at once.
function W.syncAll()
	for nid in pairs(W.fleets) do
		GN.safeCall("sync places", W.syncPlaces, nid)
	end
end

function W.ensureFleet(nid)
	if W.fleets[nid] ~= nil or W.fleetFailed[nid] or GN.Server.home[nid] == nil then
		return
	end
	-- buy the machines only when the yard is set up (otherwise they would stand in the field)
	if GN.Auto ~= nil and not GN.Auto.done then
		return
	end
	local fleet = { tools = {}, extras = {}, spawning = 0 }
	local n = GN.getNeighbour(nid)
	local items, tractor, tools, combine = fleetItems(nid)
	if next(items.roles) == nil then
		W.fleetFailed[nid] = true
		if n.contracts then
			GN.log("work: no machines found in the shop for %s", n.name)
		end
		return
	end
	W.fleets[nid] = fleet
	fleet.items = items
	for i, size in ipairs(items.extraSizes) do
		fleet.extras[i] = { size = size }
	end
	-- machines from the savegame
	local saved = W.savedIds[nid]
	if saved ~= nil then
		local byUid = {}
		for _, v in pairs(g_currentMission.vehicleSystem ~= nil and g_currentMission.vehicleSystem.vehicles or {}) do
			if v.uniqueId ~= nil then
				byUid[v.uniqueId] = v
			end
		end
		local found = 0
		local function adopt(role, uid, lentTo)
			local v = uid ~= nil and byUid[uid] or nil
			if v ~= nil then
				if items.roles[role] ~= nil then
					roleSet(fleet, role, v)
					GN.World.setVehicleState(v, nid, lentTo)
					found = found + 1
				else
					GN.try(v.delete, v) -- not part of his machines any more
				end
			end
		end
		adopt("tractor", saved.tractor)
		adopt("combine", saved.combine)
		for job, uid in pairs(saved.tools or {}) do
			adopt("tool:" .. job, uid, saved.lent ~= nil and saved.lent[job] or nil)
		end
		for i, e in pairs(saved.extras or {}) do
			adopt("extra:" .. i, e.uid)
		end
		GN.log("work: %d of %s's machines found in the savegame", found, n.name)
	else
		local chosen = {}
		for job, it in pairs(tools or {}) do
			table.insert(chosen, job .. "=" .. tostring(it.xmlFilename))
		end
		table.sort(chosen)
		GN.log("work: machines for %s: tractor=%s combine=%s %s", n.name, tostring(tractor ~= nil and tractor.xmlFilename or "none"),
			tostring(combine ~= nil and combine.xmlFilename or "none"), table.concat(chosen, " "))
	end
	-- loading the game: every machine to its place in the yard (like a fresh morning); places without
	-- their machine get it now
	W.syncPlaces(nid)
end

--- The machine that pulls / carries the implement of a job (tractor, or the combine for the header).
function W.pullerFor(fleet, job)
	if fleet == nil then
		return nil
	end
	local def = W.JOBS[job]
	if def ~= nil and def.puller == "combine" then
		return fleet.combine
	end
	return fleet.tractor
end

--- Fold an implement for transport / parking (and switch it off).
function W.foldUp(tool)
	local folding = false
	GN.try(function()
		if tool.getIsTurnedOn ~= nil and tool:getIsTurnedOn() and tool.setIsTurnedOn ~= nil then
			tool:setIsTurnedOn(false)
		end
	end)
	GN.try(function()
		local spec = tool.spec_foldable
		if spec ~= nil and tool.setFoldState ~= nil and tool.getIsUnfolded ~= nil and tool:getIsUnfolded()
			and spec.foldingParts ~= nil and #spec.foldingParts > 0 then
			-- the direction the game itself would toggle to (from unfolded: folding up)
			local dir = nil
			if tool.getToggledFoldDirection ~= nil then
				dir = tool:getToggledFoldDirection()
			end
			if dir == nil or dir == 0 then
				dir = -(spec.turnOnFoldDirection or -1)
			end
			if tool.getIsFoldAllowed == nil or tool:getIsFoldAllowed(dir, false) then
				tool:setFoldState(dir, false)
				folding = true
			end
		end
	end)
	return folding
end

function W.parkAll(nid)
	local fleet = W.fleets[nid]
	if fleet == nil then
		return
	end
	-- fold everything up first (still hitched, so it folds properly), then uncouple, then every machine
	-- to its own place
	local folding = false
	for _, puller in ipairs({ fleet.tractor, fleet.combine }) do
		if isAlive(puller) and puller.getAttachedImplements ~= nil then
			for _, impl in ipairs(puller:getAttachedImplements() or {}) do
				if impl.object ~= nil and impl.object.gnBorrowFarm == nil then
					if W.foldUp(impl.object) then
						folding = true
					end
				end
			end
		end
	end
	for _, v in pairs(fleet.tools) do
		if isAlive(v) and v.gnBorrowFarm == nil and W.foldUp(v) then
			folding = true
		end
	end
	W.parkAt = W.parkAt or {}
	W.parkAt[nid] = (g_time or 0) + (folding and 9000 or 300)
	W.detachAt = W.detachAt or {}
	W.detachAt[nid] = (g_time or 0) + (folding and 8000 or 0)
end

local function detachAll(nid)
	local fleet = W.fleets[nid]
	if fleet == nil or W.active[nid] ~= nil then
		return
	end
	-- the header stays on the combine (a header alone has nothing to stand on)
	for _, puller in ipairs({ fleet.tractor }) do
		if isAlive(puller) and puller.getAttachedImplements ~= nil then
			for _, impl in ipairs(puller:getAttachedImplements() or {}) do
				if impl.object ~= nil and impl.object.gnBorrowFarm == nil then
					GN.try(puller.detachImplementByObject, puller, impl.object)
				end
			end
		end
	end
end

--- Every frame: delayed parking and the physics check.
function W.fastUpdate(dt)
	W.checkPhysics()
	if W.detachAt ~= nil then
		local now = g_time or 0
		for nid, at in pairs(W.detachAt) do
			if now >= at then
				W.detachAt[nid] = nil
				GN.safeCall("uncouple", detachAll, nid)
			end
		end
	end
	if W.parkAt ~= nil then
		local now = g_time or 0
		for nid, at in pairs(W.parkAt) do
			if now >= at then
				W.parkAt[nid] = nil
				GN.safeCall("park", W.syncPlaces, nid)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Attaching and filling
-- ---------------------------------------------------------------------------

local function findJointPair(tractor, tool, front)
	local aj = tractor.spec_attacherJoints
	local att = tool.spec_attachable
	if aj == nil or att == nil or aj.attacherJoints == nil or att.inputAttacherJoints == nil then
		return nil
	end
	for jIndex, joint in ipairs(aj.attacherJoints) do
		local free = tractor.getImplementFromAttacherJointIndex == nil or tractor:getImplementFromAttacherJointIndex(jIndex) == nil
		local isRear = true
		if joint.jointTransform ~= nil then
			local _, _, lz = localToLocal(joint.jointTransform, tractor.rootNode, 0, 0, 0)
			isRear = lz < 0
		end
		if free and (front and not isRear or not front and isRear) then
			for iIndex, input in ipairs(att.inputAttacherJoints) do
				if input.jointType == joint.jointType then
					return iIndex, jIndex, input, joint
				end
			end
		end
	end
	return nil
end

--- Move the implement so its hitch point sits on the tractor's joint, both facing the same way.
function W.alignToJoint(tractor, tool, joint, input)
	GN.try(function()
		local jx, _, jz = getWorldTranslation(joint.jointTransform)
		local dx, _, dz = localDirectionToWorld(tractor.rootNode, 0, 0, 1)
		local ry = MathUtil.getYRotationFromDirection(dx, dz)
		-- where the implement's hitch is, seen from its own root (does not depend on where it stands now)
		local lx, _, lz = worldToLocal(tool.rootNode, getWorldTranslation(input.node))
		local s, c = math.sin(ry), math.cos(ry)
		local ox, oz = lx * c + lz * s, -lx * s + lz * c
		W.teleport(tool, jx - ox, 0, jz - oz, ry)
	end)
end

function W.attach(tractor, tool, front)
	if not isAlive(tractor) or not isAlive(tool) then
		return false
	end
	if tool.getAttacherVehicle ~= nil and tool:getAttacherVehicle() == tractor then
		return true
	end
	if tool.getAttacherVehicle ~= nil and tool:getAttacherVehicle() ~= nil then
		local holder = tool:getAttacherVehicle()
		GN.try(holder.detachImplementByObject, holder, tool)
	end
	if tractor.getAttachedImplements ~= nil then
		for _, impl in ipairs(tractor:getAttachedImplements() or {}) do
			if impl.object ~= nil then
				GN.try(tractor.detachImplementByObject, tractor, impl.object)
			end
		end
	end
	local iIndex, jIndex, input, joint = findJointPair(tractor, tool, front)
	if iIndex == nil then
		GN.log("work: %s cannot pull %s (no matching hitch)", vehicleName(tractor), vehicleName(tool))
		return false
	end
	-- put the implement exactly at the hitch, facing like the tractor, then couple
	-- (otherwise the joint pulls it over and the PTO shaft stretches through the machine)
	W.alignToJoint(tractor, tool, joint, input)
	-- mods like ManualAttach must not disconnect the PTO / hoses of a neighbour's machine
	GN.try(function()
		if tool.spec_manualAttachPowerTakeOff ~= nil then
			tool.spec_manualAttachPowerTakeOff.isBlockingInitialPtoDetach = true
		end
		if tool.spec_manualAttachConnectionHoses ~= nil then
			tool.spec_manualAttachConnectionHoses.isBlockingInitialHoseDetach = true
		end
	end)
	local ok, err = GN.try(tractor.attachImplement, tractor, tool, iIndex, jIndex, false, nil, nil, false)
	if not ok then
		GN.log("work: attaching %s to %s failed: %s", vehicleName(tool), vehicleName(tractor), tostring(err))
		return false
	end
	return true
end

--- Fill every fill unit of the machine that takes this fill type (seeds, fertilizer ...). Returns litres in it.
function W.fill(tool, fillTypeName, alt)
	if fillTypeName == nil or not isAlive(tool) or tool.getFillUnits == nil or g_fillTypeManager == nil then
		return 0
	end
	local total = 0
	for _, name in ipairs({ fillTypeName, alt }) do
		local ft = g_fillTypeManager:getFillTypeIndexByName(name)
		if ft ~= nil then
			for idx in ipairs(tool:getFillUnits() or {}) do
				local okS, supports = GN.try(tool.getFillUnitSupportsFillType, tool, idx, ft)
				if okS and supports then
					local cap = tool:getFillUnitCapacity(idx) or 0
					local level = tool:getFillUnitFillLevel(idx) or 0
					local cur = tool.getFillUnitFillType ~= nil and tool:getFillUnitFillType(idx) or nil
					if level > 0 and cur ~= nil and cur ~= ft then
						GN.try(tool.addFillUnitFillLevel, tool, W.NPC_FARM_ID, idx, -level, cur, ToolType ~= nil and ToolType.UNDEFINED or nil, nil)
						level = 0
					end
					if cap - level > 1 then
						GN.try(tool.addFillUnitFillLevel, tool, W.NPC_FARM_ID, idx, cap - level, ft, ToolType ~= nil and ToolType.UNDEFINED or nil, nil)
					end
					total = total + (tool:getFillUnitFillLevel(idx) or 0)
				end
			end
			if total > 0 then
				return total
			end
		end
	end
	return total
end

--- Unfold the implement (headers, wide seeders ...) so it can work.
function W.unfold(tool)
	GN.try(function()
		local spec = tool.spec_foldable
		if spec ~= nil and tool.setFoldState ~= nil and tool.getIsUnfolded ~= nil and not tool:getIsUnfolded() then
			local dir = spec.turnOnFoldDirection
			if dir == nil or dir == 0 then
				dir = -1
			end
			tool:setFoldState(dir, false)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Starting / watching the work
-- ---------------------------------------------------------------------------

--- A player works a contract on this farmland: the neighbour must not take the land over meanwhile.
function W.farmlandHasPlayerContract(fl)
	if fl == nil then
		return true
	end
	for _, m in ipairs(g_missionManager ~= nil and g_missionManager.missions or {}) do
		local f = m.field
		if f ~= nil and f.farmland ~= nil and f.farmland.id == fl and m.farmId ~= nil and m.farmId ~= 0
			and (MissionStatus == nil or m.status ~= MissionStatus.CREATED) then
			return true
		end
	end
	return false
end

--- Land the neighbours hold while they work (counted: two neighbours may need the same strip of land).
W.locks = W.locks or {}

local function setOwner(fl, farmId)
	GN.try(g_farmlandManager.setLandOwnership, g_farmlandManager, fl, farmId)
	GN.try(function()
		local farmland = g_farmlandManager:getFarmlandById(fl)
		if farmland ~= nil and farmland.setOwnerFarmId ~= nil then
			farmland:setOwnerFarmId(farmId)
		end
	end)
end

function W.lockLand(fl)
	local l = W.locks[fl]
	if l ~= nil then
		l.count = l.count + 1
		return true
	end
	local owner = g_farmlandManager:getFarmlandOwner(fl) or 0
	if owner ~= 0 and owner ~= W.NPC_FARM_ID then
		return false -- a player's land
	end
	W.locks[fl] = { count = 1, ownerBefore = owner == W.NPC_FARM_ID and 0 or owner }
	setOwner(fl, W.NPC_FARM_ID)
	return true
end

function W.unlockLand(fl)
	local l = W.locks[fl]
	if l == nil then
		return
	end
	l.count = l.count - 1
	if l.count <= 0 then
		W.locks[fl] = nil
		if (g_farmlandManager:getFarmlandOwner(fl) or 0) == W.NPC_FARM_ID then
			setOwner(fl, l.ownerBefore or 0)
		end
	end
end

--- A neighbour's machine (or one hitched to it) on land he holds for his work: it may work there.
function W.mayWorkAt(vehicle, farmId, x, z)
	if W.locks == nil or next(W.locks) == nil or g_farmlandManager == nil then
		return false
	end
	local root = vehicle
	if root.getRootVehicle ~= nil then
		root = root:getRootVehicle() or vehicle
	end
	if vehicle.gnNid == nil and root.gnNid == nil and farmId ~= W.NPC_FARM_ID then
		return false
	end
	local fl = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
	return fl ~= nil and W.locks[fl] ~= nil
end

--- Once per job: is the implement really working? (log for testing)
function W.diagnose(a)
	local t, tr = a.tool, a.tractor
	local info = {}
	local function add(k, fn)
		local ok, v = GN.try(fn)
		table.insert(info, k .. "=" .. (ok and tostring(v) or "err"))
	end
	add("activeFarm", function() return t:getActiveFarm() end)
	add("tractorFarm", function() return tr:getActiveFarm() end)
	add("turnedOn", function() return t.getIsTurnedOn ~= nil and t:getIsTurnedOn() or "n/a" end)
	add("lowered", function() return t.getIsLowered ~= nil and t:getIsLowered() or "n/a" end)
	add("unfolded", function() return t.getIsUnfolded ~= nil and t:getIsUnfolded() or "n/a" end)
	add("fill", function()
		local l = {}
		for i in ipairs(t:getFillUnits() or {}) do
			table.insert(l, math.floor(t:getFillUnitFillLevel(i) or 0))
		end
		return table.concat(l, "/")
	end)
	add("access", function()
		local x, _, z = getWorldTranslation(t.rootNode)
		return t:getIsAccessibleAtWorldPosition(t:getActiveFarm(), x, z)
	end)
	add("owned15", function()
		local x, _, z = getWorldTranslation(t.rootNode)
		return g_farmlandManager:getIsOwnedByFarmAtWorldPosition(W.NPC_FARM_ID, x, z)
	end)
	add("areas", function()
		local n, act = 0, 0
		for _, wa in ipairs(t.spec_workArea ~= nil and t.spec_workArea.workAreas or {}) do
			n = n + 1
			if t:getIsWorkAreaActive(wa) then
				act = act + 1
			end
		end
		return act .. "/" .. n
	end)
	GN.log("work: check %s: %s", vehicleName(t), table.concat(info, " "))
end

--- Corner points of a field (world x, z).
function W.fieldPolygon(field)
	local pts = {}
	for _, node in ipairs(field ~= nil and field.polygonPoints or {}) do
		if node ~= nil and entityExists(node) then
			local x, _, z = getWorldTranslation(node)
			table.insert(pts, { x, z })
		end
	end
	return pts
end

local function insidePoly(pts, x, z)
	local inside = false
	local j = #pts
	for i = 1, #pts do
		local xi, zi, xj, zj = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
		if ((zi > z) ~= (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi + 1e-9) + xi) then
			inside = not inside
		end
		j = i
	end
	return inside
end

--- Where the neighbour starts: inside the field, near its entrance, facing into the field.
function W.fieldStart(field, cx, cz)
	local pts = W.fieldPolygon(field)
	local ex, ez = field.posX or cx, field.posZ or cz
	if #pts < 3 then
		return ex, ez, (math.atan2 or math.atan)(cx - ex, cz - ez)
	end
	local mx, mz = 0, 0
	for _, p in ipairs(pts) do
		mx, mz = mx + p[1], mz + p[2]
	end
	mx, mz = mx / #pts, mz / #pts
	if not insidePoly(pts, mx, mz) then
		mx, mz = cx, cz
	end
	-- nearest corner to the entrance, then 25 m towards the middle
	local best, bestD = pts[1], math.huge
	for _, p in ipairs(pts) do
		local d = (p[1] - ex) ^ 2 + (p[2] - ez) ^ 2
		if d < bestD then
			best, bestD = p, d
		end
	end
	local dx, dz = mx - best[1], mz - best[2]
	local len = math.sqrt(dx * dx + dz * dz)
	for _, step in ipairs({ 25, 15, 40, 8 }) do
		if len > 1 then
			local f = math.min(0.8, step / len)
			local sx, sz = best[1] + dx * f, best[2] + dz * f
			if insidePoly(pts, sx, sz) then
				return sx, sz, (math.atan2 or math.atan)(mx - sx, mz - sz)
			end
		end
	end
	return mx, mz, 0
end

--- Farmlands of the field and the strips around it (headlands, turns) that nobody else owns.
function W.landsAround(field, fl)
	local out, seen = { fl }, { [fl] = true }
	local pts = W.fieldPolygon(field)
	if #pts < 3 or g_farmlandManager.getFarmlandIdAtWorldPosition == nil then
		return out
	end
	local mx, mz = 0, 0
	for _, p in ipairs(pts) do
		mx, mz = mx + p[1], mz + p[2]
	end
	mx, mz = mx / #pts, mz / #pts
	local function probe(x, z)
		local ok, id = GN.try(g_farmlandManager.getFarmlandIdAtWorldPosition, g_farmlandManager, x, z)
		if ok and id ~= nil and id ~= 0 and not seen[id] then
			seen[id] = true
			table.insert(out, id)
		end
	end
	for i, p in ipairs(pts) do
		local q = pts[(i % #pts) + 1]
		for _, t in ipairs({ 0, 0.5 }) do
			local x, z = p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t
			local dx, dz = x - mx, z - mz
			local len = math.max(1, math.sqrt(dx * dx + dz * dz))
			for _, out_m in ipairs({ 4, 12 }) do
				probe(x + dx / len * out_m, z + dz / len * out_m)
			end
		end
	end
	return out
end

local function missionFarmland(m)
	local f = m ~= nil and m.field or nil
	if f ~= nil and f.farmland ~= nil then
		return f.farmland.id
	end
	return nil
end

--- The neighbour holds his field and the land around it while he works (the helper checks the owner
--- of every spot it drives on). Returns the list of locked farmlands.
function W.lockForWork(field, fl)
	local locked = {}
	for _, id in ipairs(W.landsAround(field, fl)) do
		if id == fl or not W.farmlandHasPlayerContract(id) then
			if W.lockLand(id) then
				table.insert(locked, id)
			end
		end
	end
	local fieldOwnerBefore = nil
	GN.try(function()
		if field ~= nil and field.fieldState ~= nil then
			fieldOwnerBefore = field.fieldState.ownerFarmId
			field.fieldState.ownerFarmId = W.NPC_FARM_ID
		end
	end)
	return locked, fieldOwnerBefore
end

function W.unlockAfterWork(field, locked, fieldOwnerBefore)
	for _, id in ipairs(locked or {}) do
		W.unlockLand(id)
	end
	GN.try(function()
		if field ~= nil and field.fieldState ~= nil then
			field.fieldState.ownerFarmId = fieldOwnerBefore or 0
		end
	end)
end

function W.startWork(nid, mission, job)
	local fleet = W.fleets[nid]
	local n = GN.getNeighbour(nid)
	local tool = W.toolFor(fleet, job)
	local tractor = W.pullerFor(fleet, job)
	if not isAlive(tractor) or not isAlive(tool) or inUse(tractor) then
		return false
	end
	-- the helper only starts with everything in transport position: fold up first, start on the next check
	local folding = W.foldUp(tractor)
	if W.foldUp(tool) then
		folding = true
	end
	for _, impl in ipairs(tractor.getAttachedImplements ~= nil and tractor:getAttachedImplements() or {}) do
		if impl.object ~= nil and impl.object ~= tool and W.foldUp(impl.object) then
			folding = true
		end
	end
	-- one wait for folding, then he goes anyway (some machines never report folded)
	W.foldWaits = W.foldWaits or {}
	if folding and (W.foldWaits[nid] or 0) < 1 then
		W.foldWaits[nid] = (W.foldWaits[nid] or 0) + 1
		GN.log("work: %s folds up his machines first", n.name)
		return "wait"
	end
	W.foldWaits[nid] = nil
	local field = mission.field
	local fl = missionFarmland(mission)
	local x, z
	if field.getCenterOfFieldWorldPosition ~= nil then
		local ok, cx, cz = GN.try(field.getCenterOfFieldWorldPosition, field)
		if ok then
			x, z = cx, cz
		end
	end
	x, z = x or field.posX, z or field.posZ
	if x == nil or fl == nil then
		return false
	end
	-- the AI may only work land of its own farm: the neighbour holds the field (and its edges) while he works
	local locked, fieldOwnerBefore = W.lockForWork(field, fl)
	-- he starts right on the field (teleport), inside it, the implement coupled properly there
	local sx, sz, ry = W.fieldStart(field, x, z)
	for _, impl in ipairs(tractor.getAttachedImplements ~= nil and tractor:getAttachedImplements() or {}) do
		if impl.object ~= nil then
			GN.try(tractor.detachImplementByObject, tractor, impl.object)
		end
	end
	W.teleport(tractor, sx, 0, sz, ry)
	if not W.attach(tractor, tool, W.JOBS[job].puller == "combine") then
		W.unlockAfterWork(field, locked, fieldOwnerBefore)
		W.parkAll(nid)
		return false
	end
	local def = W.JOBS[job]
	if def.fill ~= nil then
		local litres = W.fill(tool, def.fill, def.fill == "FERTILIZER" and "LIQUIDFERTILIZER" or nil)
		GN.log("work: %s filled %s with %d l %s", n.name, vehicleName(tool), math.floor(litres or 0), def.fill)
	end
	local startedJob = nil
	local okJob, err = GN.try(function()
		local aiJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.FIELDWORK)
		aiJob:resetTasks()
		aiJob.vehicleParameter:setVehicle(tractor)
		if aiJob.fieldPositionParameter ~= nil then
			aiJob.fieldPositionParameter:setPosition(x, z)
		end
		aiJob:applyCurrentState(tractor, g_currentMission, W.NPC_FARM_ID, false)
		aiJob:setValues()
		local valid, msg = aiJob:validate(W.NPC_FARM_ID)
		if not valid then
			error("not valid: " .. tostring(msg))
		end
		startedJob = aiJob
		g_currentMission.aiSystem:startJob(aiJob, W.NPC_FARM_ID)
	end)
	if not okJob then
		W.unlockAfterWork(field, locked, fieldOwnerBefore)
		W.parkAll(nid)
		GN.log("work: %s could not start %s on farmland %s: %s", n.name, job, tostring(fl), tostring(err))
		return false
	end
	local tx, _, tz = getWorldTranslation(tractor.rootNode)
	W.active[nid] = { mission = mission, job = job, tool = tool, tractor = tractor, farmlandId = fl, locked = locked,
		field = field, fieldOwnerBefore = fieldOwnerBefore, fruit = field.fieldState ~= nil and field.fieldState.fruitTypeIndex or nil,
		started = g_time or 0, seenActive = false, aiJob = startedJob, lastX = tx, lastZ = tz, lastMove = g_time or 0 }
	GN.log("work: %s drives out to farmland %s (%s with %s + %s, %d farmland(s) held)", n.name, tostring(fl), job,
		vehicleName(tractor), vehicleName(tool), #locked)
	W.sendDriver(nid, tractor)
	return true
end

-- ---------------------------------------------------------------------------
-- The result on the field (as in FoS: what the neighbour did is on the field afterwards, for sure)
-- ---------------------------------------------------------------------------

local function sprayTypeValue(name)
	if FieldSprayType ~= nil and FieldSprayType[name] ~= nil and FieldSprayType.getValueByType ~= nil then
		local ok, v = GN.try(FieldSprayType.getValueByType, FieldSprayType[name])
		if ok and v ~= nil then
			return v
		end
	end
	return nil
end

--- Field state after the job, for the whole field.
function W.completeField(field, job, mission, fruitBefore)
	if field == nil or FieldUpdateTask == nil or FieldUpdateTask.new == nil then
		return false
	end
	local fs = field.fieldState or {}
	local task = FieldUpdateTask.new()
	task:setField(field)
	if field.getDensityMapPolygon ~= nil then
		task:setArea(field:getDensityMapPolygon())
	end
	local missionInfo = g_currentMission.missionInfo
	local any = false
	if job == "harvest" then
		local fruit = fruitBefore or fs.fruitTypeIndex
		local desc = fruit ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fruit) or nil
		if desc == nil then
			return false
		end
		task:setFruit(fruit, (desc.cutState ~= nil and desc.cutState > 0) and desc.cutState or 1)
		task:setWeedState(0)
		task:setSprayLevel(0)
		task:clearHeight()
		any = true
	elseif job == "sow" then
		local fruit = mission ~= nil and (mission.fruitTypeIndex or mission.fruitType) or nil
		if type(fruit) == "table" then
			fruit = fruit.index
		end
		if fruit == nil then
			return false
		end
		task:setFruit(fruit, 1)
		if FieldGroundType ~= nil and FieldGroundType.SOWN ~= nil then
			task:setGroundType(FieldGroundType.SOWN)
		end
		task:setWeedState((missionInfo ~= nil and missionInfo.weedsEnabled) and 1 or 0)
		any = true
	elseif job == "cultivate" or job == "plow" then
		task:setFruit(FruitType ~= nil and FruitType.UNKNOWN or 0, 1)
		local g = FieldGroundType ~= nil and (job == "plow" and FieldGroundType.PLOWED or FieldGroundType.CULTIVATED) or nil
		if g ~= nil then
			task:setGroundType(g)
		end
		task:setWeedState(0)
		if task.setStubbleShredLevel ~= nil then
			task:setStubbleShredLevel(0)
		end
		any = true
	elseif job == "fertilize" then
		task:setSprayLevel(math.min(2, (fs.sprayLevel or 0) + 1))
		local st = sprayTypeValue("FERTILIZER")
		if st ~= nil then
			task:setSprayType(st)
		end
		any = true
	elseif job == "lime" then
		task:setLimeLevel(g_fieldManager ~= nil and g_fieldManager.limeLevelMaxValue or 1)
		any = true
	elseif job == "spray" then
		task:setWeedState((missionInfo ~= nil and missionInfo.weedsEnabled) and 7 or 0)
		any = true
	elseif job == "weed" then
		task:setWeedState(0)
		any = true
	elseif job == "roll" and task.setRollerLevel ~= nil then
		task:setRollerLevel(0)
		any = true
	end
	if not any then
		return false
	end
	if task.resetDisplacement ~= nil then
		task:resetDisplacement()
	end
	task:enqueue(true)
	return true
end

function W.finishWork(nid, reason, complete)
	local a = W.active[nid]
	if a == nil then
		return
	end
	W.active[nid] = nil
	local n = GN.getNeighbour(nid)
	if isAlive(a.tractor) and a.tractor.getIsAIActive ~= nil and a.tractor:getIsAIActive() and a.tractor.stopCurrentAIJob ~= nil and AIMessageSuccessStoppedByUser ~= nil then
		GN.try(a.tractor.stopCurrentAIJob, a.tractor, AIMessageSuccessStoppedByUser.new())
	end
	-- whatever he did: when he really worked, the field is done afterwards
	if complete then
		local ok, res = GN.try(W.completeField, a.field, a.job, a.mission, a.fruit)
		GN.log("work: %s's field %s: %s", n.name, tostring(a.farmlandId), (ok and res) and "done" or ("not changed " .. tostring(res)))
	end
	W.unlockAfterWork(a.field, a.locked, a.fieldOwnerBefore)
	-- the contract on this field was done by the neighbour: remove it from the list
	local m = a.mission
	local stillOpen = m ~= nil and (m.farmId == nil or m.farmId == 0) and (MissionStatus == nil or m.status == MissionStatus.CREATED)
	if stillOpen and complete then
		for _, fn in ipairs({ "deleteMission", "removeMission" }) do
			if g_missionManager[fn] ~= nil and GN.try(g_missionManager[fn], g_missionManager, m) then
				break
			end
		end
	end
	if isAlive(a.tractor) and a.job == "harvest" then
		GN.try(W.drainCombine, a.tractor, true)
	end
	W.drivers[nid] = nil
	GN.sendToAll("driver", { nid = nid, clear = true })
	-- he drives home: every machine back on its place
	W.parkAll(nid)
	GN.log("work: %s is back home (%s, %s)", n.name, a.job, reason)
end

--- Why did a neighbour's helper stop? (logged, and such a field is not tried again the same day)
function W.installAIHook()
	if W._aiHooked or AISystem == nil or AISystem.stopJobInternal == nil then
		return
	end
	W._aiHooked = true
	AISystem.stopJobInternal = Utils.appendedFunction(AISystem.stopJobInternal, function(_, job, aiMessage)
		for _, a in pairs(W.active) do
			if a.aiJob ~= nil and a.aiJob == job then
				local text = "?"
				if aiMessage ~= nil then
					local ok, t = GN.try(aiMessage.getMessage, aiMessage, job)
					text = (ok and t ~= nil and t ~= "") and t or tostring(aiMessage.name or aiMessage.className or aiMessage)
					if ClassUtil ~= nil and ClassUtil.getClassNameByObject ~= nil then
						local okN, cn = GN.try(ClassUtil.getClassNameByObject, aiMessage)
						if okN and cn ~= nil then
							text = tostring(cn) .. " (" .. text .. ")"
						end
					end
				end
				a.stopMsg = text
				a.stoppedAt = g_time or 0
			end
		end
	end)
end

function W.update(dt)
	if g_currentMission == nil or g_currentMission.aiSystem == nil then
		return
	end
	GN.safeCall("work fast", W.fastUpdate, dt)
	W.timer = W.timer + (dt or 0)
	if W.timer < W.CHECK_MS then
		return
	end
	W.timer = 0
	if W.pendingOwnership ~= nil then
		GN.safeCall("restore ownership", W.restoreOwnership)
	end
	W.enabled = GN.Server.settings.npcWork ~= false
	if not W.enabled then
		for nid in pairs(W.active) do
			W.finishWork(nid, "turned off by an admin", false)
		end
		return
	end
	if not W.ensureFarm() then
		return
	end
	W.installAIHook()
	if g_currentMission.maxNumHirables ~= nil and g_currentMission.maxNumHirables < 30 then
		g_currentMission.maxNumHirables = 30
	end
	local now = GN.getDayMinutes()
	for _, n in ipairs(GN.neighbours) do
		if not n.contracts and W.FLEETS ~= nil and W.FLEETS[n.id] ~= nil then
			GN.safeCall("work fleet", W.ensureFleet, n.id) -- truck, trailer ... of the trader and others
		end
		if n.contracts then
			GN.safeCall("work fleet", W.ensureFleet, n.id)
			local a = W.active[n.id]
			if a ~= nil then
				local active = isAlive(a.tractor) and a.tractor.getIsAIActive ~= nil and a.tractor:getIsAIActive()
				if not active and a.aiJob ~= nil and a.stopMsg == nil then
					for _, j in ipairs(g_currentMission.aiSystem.activeJobs or {}) do
						if j == a.aiJob then
							active = true
						end
					end
				end
				local t = g_time or 0
				if active then
					a.seenActive = true
					-- always full while he works (seeds, fertilizer, herbicide ...)
					local def = W.JOBS[a.job]
					if def ~= nil and def.fill ~= nil and isAlive(a.tool) then
						GN.safeCall("refill", W.fill, a.tool, def.fill, def.fill == "FERTILIZER" and "LIQUIDFERTILIZER" or nil)
					end
					if not a.diagnosed and t - a.started > 30000 then
						a.diagnosed = true
						GN.safeCall("work check", W.diagnose, a)
					end
					if a.job == "harvest" then
						GN.safeCall("grain tank", W.harvestTick, a)
					end
					-- is he moving? (stuck on a road / in a ditch -> he gives up and finishes the field later)
					if isAlive(a.tractor) then
						local x, _, z = getWorldTranslation(a.tractor.rootNode)
						if (x - (a.lastX or x)) ^ 2 + (z - (a.lastZ or z)) ^ 2 > 16 then
							a.lastX, a.lastZ, a.lastMove = x, z, t
						end
					end
				end
				local evening = now >= W.END_MINUTE or now < 4 * 60
				if W.farmlandHasPlayerContract(a.farmlandId) then
					-- a player took a contract on this land: the neighbour gives it back at once
					W.finishWork(n.id, "a player works a contract on this farmland", false)
				elseif a.stopMsg ~= nil and t - (a.stoppedAt or 0) < 120000 and t - a.started < 120000 then
					-- the helper gave up right away (field not ready, wrong crop ...): not this field again today
					W.failedToday[a.mission] = GN.getDay()
					W.finishWork(n.id, "the helper stopped: " .. tostring(a.stopMsg), false)
				elseif a.seenActive and not active then
					W.finishWork(n.id, a.stopMsg ~= nil and ("done: " .. tostring(a.stopMsg)) or "done", true)
				elseif not a.seenActive and t - a.started > 60000 then
					W.failedToday[a.mission] = GN.getDay()
					W.finishWork(n.id, "the helper did not start", false)
				elseif evening then
					W.finishWork(n.id, "end of the working day (22:00)", a.seenActive)
				elseif a.seenActive and t - (a.lastMove or t) > W.STUCK_MS then
					W.finishWork(n.id, "stuck - he finished the field by hand", true)
				elseif t - a.started > W.MAX_WORK_MS then
					W.finishWork(n.id, "took too long", true)
				end
			elseif now >= (GN.Server.workStart[n.id] or 24 * 60) and now <= W.LAST_START_MINUTE then
				-- his own working day: everything on his fields except the contracts kept for today's call
				local callRunning = GN.Server.call ~= nil and GN.Server.call.nid == n.id
				local fleet = W.fleets[n.id]
				local away = GN.Situ ~= nil and GN.Situ.isAway(n.id, fleet ~= nil and fleet.tractor or nil)
				if not callRunning and not away and fleet ~= nil and (fleet.spawning or 0) == 0 then
					for _, m in ipairs(GN.Server.getOpenMissions(n.id)) do
						local job = GN.Server.missionJob(m)
						if W.JOBS[job] ~= nil and W.toolFor(fleet, job) ~= nil and W.toolFor(fleet, job).gnBorrowFarm == nil
							and not GN.Server.isReserved(n.id, m) and W.failedToday[m] ~= GN.getDay()
							and not W.farmlandHasPlayerContract(missionFarmland(m)) then
							local res = W.startWork(n.id, m, job)
							if res == true or res == "wait" then
								break
							end
							-- the helper refused this field (e.g. a crop his header cannot cut): not again today
							W.failedToday[m] = GN.getDay()
						end
					end
				end
			end
		end
	end
end

--- Harvest: the grain tank fills while he drives and is emptied at 60 % (as if a trailer took it away).
function W.harvestTick(a)
	local combine = a.tractor
	local spec = combine.spec_combine
	local idx = spec ~= nil and spec.fillUnitIndex or nil
	if idx == nil then
		return
	end
	local cap = combine:getFillUnitCapacity(idx) or 0
	local level = combine:getFillUnitFillLevel(idx) or 0
	if cap <= 0 then
		return
	end
	if level / cap >= W.HARVEST_DRAIN_SHARE then
		W.drainCombine(combine, true)
		return
	end
	local ft = combine:getFillUnitFillType(idx)
	if (ft == nil or ft == 0 or (FillType ~= nil and ft == FillType.UNKNOWN)) and a.fruit ~= nil and g_fruitTypeManager ~= nil then
		ft = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(a.fruit)
	end
	if ft ~= nil and ft ~= 0 then
		GN.try(combine.addFillUnitFillLevel, combine, W.NPC_FARM_ID, idx, cap * 0.08, ft, ToolType ~= nil and ToolType.UNDEFINED or nil, nil)
	end
end

function W.drainCombine(combine, all)
	local spec = combine.spec_combine
	local idx = spec ~= nil and spec.fillUnitIndex or nil
	if idx == nil then
		return
	end
	local cap = combine:getFillUnitCapacity(idx) or 0
	local level = combine:getFillUnitFillLevel(idx) or 0
	if level > 0 and (all or (cap > 0 and level / cap > W.HARVEST_DRAIN_SHARE)) then
		local ft = combine:getFillUnitFillType(idx)
		combine:addFillUnitFillLevel(W.NPC_FARM_ID, idx, -level, ft, ToolType ~= nil and ToolType.UNDEFINED or nil, nil)
	end
end

-- ---------------------------------------------------------------------------
-- Lending a machine to a player farm (asked for in a phone call)
-- ---------------------------------------------------------------------------

--- The neighbour's own implement for this job, if it is at home and free.
function W.getLendableTool(nid, job)
	local fleet = W.fleets[nid]
	if job == nil or fleet == nil or W.JOBS[job] == nil or W.JOBS[job].puller == "combine" then
		return nil -- a header without the combine is no help
	end
	local tool = W.toolFor(fleet, job)
	if not isAlive(tool) or tool.gnBorrowFarm ~= nil then
		return nil
	end
	local a = W.active[nid]
	if a ~= nil and a.tool == tool then
		return nil
	end
	return tool
end

--- How many machines (tractor + implements) the neighbour has or will get = places he needs.
function W.machineCount(nid)
	local r = W.requiredPlaces(nid)
	return r.vehicle + r.attach + r.oversize
end

--- Parking pose of one machine of the neighbour (where it is picked up and has to be brought back).
function W.toolParkPose(nid, tool)
	local fleet = W.fleets[nid]
	if fleet == nil then
		return nil
	end
	local role = nil
	if tool == fleet.tractor then
		role = "tractor"
	elseif tool == fleet.combine then
		role = "combine"
	else
		for job, v in pairs(fleet.tools) do
			if v == tool then
				role = "tool:" .. job
			end
		end
	end
	local it = fleet.items
	local pose = role ~= nil and (it ~= nil and W.assignPoses(nid, it.jobs, it.hasCombine, true, it.extraSizes, true)
		or W.assignPoses(nid, sortedJobs(fleet.tools), fleet.combine ~= nil))[role] or nil
	if pose == nil then
		return nil
	end
	return pose.x, pose.y, pose.z, pose.ry
end

function W.lendTool(nid, tool, farmId, missions, job)
	if not isAlive(tool) then
		return
	end
	local n = GN.getNeighbour(nid)
	-- make sure it is not on the neighbour's tractor and is ready to go
	if tool.getAttacherVehicle ~= nil and tool:getAttacherVehicle() ~= nil then
		local holder = tool:getAttacherVehicle()
		GN.try(holder.detachImplementByObject, holder, tool)
	end
	for job, v in pairs(W.fleets[nid] ~= nil and W.fleets[nid].tools or {}) do
		if v == tool then
			W.fill(tool, W.JOBS[job].fill)
		end
	end
	GN.World.setVehicleState(tool, nid, farmId)
	GN.sendToFarm(farmId, "lent", { nid = nid, vehicle = vehicleName(tool) })
	GN.Borrow.start(nid, tool, farmId, missions, job)
	GN.log("work: %s lends %s to farm %d", n.name, vehicleName(tool), farmId)
end

--- All contracts with the lent machine are over: it goes back to the neighbour's yard.
function W.returnLent(nid, farmId)
	local fleet = W.fleets[nid]
	if fleet == nil then
		return
	end
	for _, tool in pairs(fleet.tools) do
		if isAlive(tool) and tool.gnBorrowFarm == farmId then
			if tool.getAttacherVehicle ~= nil and tool:getAttacherVehicle() ~= nil then
				local holder = tool:getAttacherVehicle()
				GN.try(holder.detachImplementByObject, holder, tool)
			end
			GN.World.setVehicleState(tool, nid, nil)
			GN.sendToFarm(farmId, "returned", { nid = nid, vehicle = vehicleName(tool) })
			GN.log("work: %s got %s back from farm %d", GN.getNeighbour(nid).name, vehicleName(tool), farmId)
		end
	end
	if W.active[nid] == nil then
		W.parkAll(nid)
	end
end

-- ---------------------------------------------------------------------------
-- Driver looks like the neighbour (clients)
-- ---------------------------------------------------------------------------

GNDriverEvent = {}
local GNDriverEvent_mt = Class(GNDriverEvent, Event)
InitEventClass(GNDriverEvent, "GNDriverEvent")

function GNDriverEvent.emptyNew()
	return Event.new(GNDriverEvent_mt)
end
function GNDriverEvent.new(nid, vehicle)
	local self = GNDriverEvent.emptyNew()
	self.nid = nid
	self.vehicle = vehicle
	return self
end
function GNDriverEvent:writeStream(streamId, connection)
	streamWriteUInt8(streamId, self.nid)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
end
function GNDriverEvent:readStream(streamId, connection)
	self.nid = streamReadUInt8(streamId)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self:run(connection)
end
function GNDriverEvent:run(connection)
	if connection ~= nil and connection:getIsServer() then
		GN.safeCall("driver", W.clientSetDriver, self.nid, self.vehicle)
	end
end

function W.sendDriver(nid, vehicle)
	W.drivers[nid] = vehicle
	for _, p in ipairs(GN.getPlayers()) do
		if p == g_localPlayer and GN.hasUI() then
			W.clientSetDriver(nid, vehicle)
		elseif p.connection ~= nil and p.connection.gnReady == true then
			p.connection:sendEvent(GNDriverEvent.new(nid, vehicle))
		end
	end
end

--- Server: a player joined - tell him who drives which tractor.
function W.sendDriversTo(connection)
	for nid, v in pairs(W.drivers) do
		if W.active[nid] ~= nil and isAlive(v) and connection ~= nil and connection ~= GN.LOCAL then
			connection:sendEvent(GNDriverEvent.new(nid, v))
		end
	end
end

W.clientDrivers = W.clientDrivers or {}

function W.clientSetDriver(nid, vehicle)
	if vehicle == nil then
		return
	end
	W.clientDrivers[nid] = { vehicle = vehicle, applied = false, tries = 0, wait = 0 }
end

--- Clients: the PTO shaft of a neighbour's implement is updated; when it is still stretched (attached by the
--- server while the machine was moved), it is taken off - only the look, the machine works the same.
W.PTO_MAX_LENGTH = 6
function W.clientFixPto(dt)
	W._ptoTimer = (W._ptoTimer or 0) + (dt or 0)
	if W._ptoTimer < 250 then
		return
	end
	W._ptoTimer = 0
	local vs = g_currentMission ~= nil and g_currentMission.vehicleSystem or nil
	for _, v in pairs(vs ~= nil and vs.vehicles or {}) do
		local spec = v.spec_powerTakeOffs
		local own = v.gnNid ~= nil or (v.getOwnerFarmId ~= nil and v:getOwnerFarmId() == W.NPC_FARM_ID)
		if own and spec ~= nil and spec.inputPowerTakeOffs ~= nil then
			for _, input in pairs(spec.inputPowerTakeOffs) do
				local attacher = input.connectedVehicle
				if attacher ~= nil and input.linkNode ~= nil and input.startNode ~= nil then
					if v.updatePowerTakeOff ~= nil then
						GN.try(v.updatePowerTakeOff, v, input, 0)
					end
					local ok, len = GN.try(calcDistanceFrom, input.linkNode, input.startNode)
					if ok and len ~= nil and len > W.PTO_MAX_LENGTH and attacher.getAttachedImplements ~= nil and attacher.detachPowerTakeOff ~= nil then
						for _, entry in pairs(attacher:getAttachedImplements() or {}) do
							if entry ~= nil and entry.object == v then
								GN.try(attacher.detachPowerTakeOff, attacher, attacher, entry)
								GN.logThrottled("pto|" .. tostring(v.id), 300, "work: stretched PTO shaft of %s taken off (%.1f m)", vehicleName(v), len)
							end
						end
					end
				end
			end
		end
	end
end

function W.clientUpdate(dt)
	GN.safeCall("pto", W.clientFixPto, dt)
	for nid, d in pairs(W.clientDrivers) do
		local v = d.vehicle
		d.wait = d.wait + (dt or 0)
		if not isAlive(v) then
			W.clientDrivers[nid] = nil
		elseif not d.applied and d.tries < 10 and d.wait > 1500 then
			-- a moment after the helper starts (the game puts its own helper in first)
			d.wait = 0
			d.tries = d.tries + 1
			local n = GN.getNeighbour(nid)
			local outfit = GN.Client.styles ~= nil and GN.Client.styles[nid] or nil
			local style = GN.Characters.buildStyle(n.gender, outfit, true, n.wear)
			local enterable = v.spec_enterable
			if style ~= nil and v.setVehicleCharacter ~= nil and not (enterable ~= nil and enterable.isEntered) then
				local ok, err = GN.try(v.setVehicleCharacter, v, style)
				d.applied = ok
				if ok then
					GN.log("work: the driver of %s now looks like %s", vehicleName(v), n.name)
				else
					GN.logThrottled("driverErr|" .. nid, 60, "work: driver look for %s failed: %s", n.name, tostring(err))
				end
			end
		end
	end
end

function W.clientOnMessage(data)
	if data.clear then
		W.clientDrivers[tonumber(data.nid) or -1] = nil
	end
end

-- ---------------------------------------------------------------------------
-- Save / load (part of goodNeighbours.xml)
-- ---------------------------------------------------------------------------

function W.saveToXML(xml)
	local a = 0
	for fl, l in pairs(W.locks or {}) do
		local k = string.format("goodNeighbours.working.field(%d)", a)
		setXMLInt(xml, k .. "#farmland", fl)
		setXMLInt(xml, k .. "#owner", l.ownerBefore or 0)
		a = a + 1
	end
	local i = 0
	for nid, fleet in pairs(W.fleets) do
		local hasExtras = false
		for _, e in ipairs(fleet.extras or {}) do
			if isAlive(e.v) then
				hasExtras = true
			end
		end
		if (isAlive(fleet.tractor) and fleet.tractor.uniqueId ~= nil) or hasExtras then
			local k = string.format("goodNeighbours.fleets.fleet(%d)", i)
			setXMLInt(xml, k .. "#neighbour", nid)
			if isAlive(fleet.tractor) and fleet.tractor.uniqueId ~= nil then
				setXMLString(xml, k .. "#tractor", fleet.tractor.uniqueId)
			end
			local x = 0
			for ei, e in ipairs(fleet.extras or {}) do
				if isAlive(e.v) and e.v.uniqueId ~= nil then
					local ek = string.format("%s.extra(%d)", k, x)
					setXMLInt(xml, ek .. "#index", ei)
					setXMLString(xml, ek .. "#vehicle", e.v.uniqueId)
					setXMLString(xml, ek .. "#size", e.size or "attach")
					x = x + 1
				end
			end
			if isAlive(fleet.combine) and fleet.combine.uniqueId ~= nil then
				setXMLString(xml, k .. "#combine", fleet.combine.uniqueId)
			end
			local j = 0
			for job, v in pairs(fleet.tools) do
				if isAlive(v) and v.uniqueId ~= nil then
					local tk = string.format("%s.tool(%d)", k, j)
					setXMLString(xml, tk .. "#job", job)
					setXMLString(xml, tk .. "#vehicle", v.uniqueId)
					if v.gnBorrowFarm ~= nil then
						setXMLInt(xml, tk .. "#lentTo", v.gnBorrowFarm)
					end
					j = j + 1
				end
			end
			i = i + 1
		end
	end
end

function W.loadFromXML(xml)
	W.pendingOwnership = {}
	local a = 0
	while true do
		local k = string.format("goodNeighbours.working.field(%d)", a)
		if not hasXMLProperty(xml, k) then break end
		table.insert(W.pendingOwnership, { farmland = getXMLInt(xml, k .. "#farmland"), owner = getXMLInt(xml, k .. "#owner") or 0 })
		a = a + 1
	end
	local i = 0
	while true do
		local k = string.format("goodNeighbours.fleets.fleet(%d)", i)
		if not hasXMLProperty(xml, k) then break end
		local nid = getXMLInt(xml, k .. "#neighbour")
		if nid ~= nil then
			local saved = { tractor = getXMLString(xml, k .. "#tractor"), combine = getXMLString(xml, k .. "#combine"), tools = {}, lent = {}, extras = {} }
			local x = 0
			while true do
				local ek = string.format("%s.extra(%d)", k, x)
				if not hasXMLProperty(xml, ek) then break end
				local idx = getXMLInt(xml, ek .. "#index") or (x + 1)
				saved.extras[idx] = { uid = getXMLString(xml, ek .. "#vehicle"), size = getXMLString(xml, ek .. "#size") }
				x = x + 1
			end
			local j = 0
			while true do
				local tk = string.format("%s.tool(%d)", k, j)
				if not hasXMLProperty(xml, tk) then break end
				local job, uid = getXMLString(xml, tk .. "#job"), getXMLString(xml, tk .. "#vehicle")
				if job ~= nil and uid ~= nil then
					saved.tools[job] = uid
					saved.lent[job] = getXMLInt(xml, tk .. "#lentTo")
				end
				j = j + 1
			end
			W.savedIds[nid] = saved
		end
		i = i + 1
	end
end

--- Fields a neighbour was working when the game was saved go back to their owner after loading.
function W.restoreOwnership()
	for _, e in ipairs(W.pendingOwnership or {}) do
		if e.farmland ~= nil and g_farmlandManager:getFarmlandOwner(e.farmland) == W.NPC_FARM_ID then
			GN.try(g_farmlandManager.setLandOwnership, g_farmlandManager, e.farmland, e.owner or 0)
			GN.log("work: farmland %d given back to its owner after loading", e.farmland)
		end
	end
	W.pendingOwnership = nil
end

W.reset()
