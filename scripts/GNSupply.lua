-- Good Neighbours (FS25) - the neighbour's material for his contracts (server)
-- When a player takes a neighbour's sowing / fertilizing / spraying / liming contract by phone, the neighbour puts
-- the material at his silo place: big bags / tanks of the game's shop, filled, usable by that farm
-- (like his lent machines). When all his contracts of that farm are over, what is left goes back to him.
-- Author: billiD

local GN = GoodNeighbours

GN.Supply = GN.Supply or {}
local SP = GN.Supply

-- job -> fill type the player needs
SP.JOB_FILL = { sow = "SEEDS", fertilize = "FERTILIZER", spray = "HERBICIDE", lime = "LIME" }
-- litres per hectare he puts out (generous, the rest is taken back)
SP.PER_HA = { SEEDS = 260, FERTILIZER = 450, HERBICIDE = 180, LIME = 2600, LIQUIDFERTILIZER = 400 }
SP.MAX_UNITS = 10
-- shop file names -> fill type
SP.KEYWORDS = {
	{ "liquidfertilizer", "LIQUIDFERTILIZER" },
	{ "herbicide", "HERBICIDE" },
	{ "seed", "SEEDS" },
	{ "lime", "LIME" },
	{ "fertilizer", "FERTILIZER" },
}

function SP.reset()
	SP.deliveries = {}   -- "farm|nid" -> { farmId, nid, fillType, vehicles = {} }
	SP.saved = {}
	SP.catalogue = nil
end

local function key(farmId, nid)
	return tostring(farmId) .. "|" .. tostring(nid)
end

--- Shop items that hold a fill type: big bags, pallets, tanks (base game only).
function SP.items()
	if SP.catalogue ~= nil then
		return SP.catalogue
	end
	SP.catalogue = {}
	local names = {}
	for _, item in ipairs(g_storeManager ~= nil and g_storeManager:getItems() or {}) do
		local cat = string.upper(tostring(item.categoryName or ""))
		local file = string.lower(tostring(item.xmlFilename or ""))
		if item.customEnvironment == nil and (string.find(cat, "BIGBAG", 1, true) or string.find(cat, "PALLET", 1, true)
			or string.find(cat, "TANK", 1, true) or string.find(file, "bigbag", 1, true) or string.find(file, "pallet", 1, true)) then
			for _, kw in ipairs(SP.KEYWORDS) do
				if string.find(file, kw[1], 1, true) then
					SP.catalogue[kw[2]] = SP.catalogue[kw[2]] or {}
					table.insert(SP.catalogue[kw[2]], item)
					table.insert(names, kw[2] .. "=" .. (string.match(file, "([^/]+)%.xml$") or file))
					break
				end
			end
		end
	end
	GN.log("supplies: shop items %s", table.concat(names, ", "))
	return SP.catalogue
end

local function siloPose(nid)
	for _, p in ipairs(GN.Server.slots[nid] or {}) do
		if p.size == "silo" then
			return p.x, p.z, p.ry or 0
		end
	end
	local h = GN.Server.home[nid]
	if h ~= nil then
		return h.x + 8, h.z + 8, 0
	end
	return nil
end

local function fieldHa(m)
	local f = m ~= nil and m.field or nil
	if f ~= nil and f.getAreaHa ~= nil then
		local ok, a = GN.try(f.getAreaHa, f)
		if ok and a ~= nil then
			return a
		end
	end
	return 2
end

--- Put the material out for a farm (called when the contracts were started).
function SP.deliver(nid, farmId, missions, job)
	local ftName = SP.JOB_FILL[job or ""]
	if ftName == nil or g_fillTypeManager == nil or SP.deliveries[key(farmId, nid)] ~= nil then
		return
	end
	local list = SP.items()[ftName]
	if (list == nil or #list == 0) and ftName == "FERTILIZER" then
		ftName = "LIQUIDFERTILIZER"
		list = SP.items()[ftName]
	end
	if list == nil or #list == 0 then
		GN.log("supplies: no shop item for %s", ftName)
		return
	end
	local ft = g_fillTypeManager:getFillTypeIndexByName(ftName)
	local x, z, ry = siloPose(nid)
	if ft == nil or x == nil then
		return
	end
	local ha = 0
	for _, m in ipairs(missions or {}) do
		ha = ha + fieldHa(m)
	end
	local need = math.max(1, ha) * (SP.PER_HA[ftName] or 400)
	local item = list[1]
	local d = { farmId = farmId, nid = nid, fillType = ftName, vehicles = {}, need = need, given = 0 }
	SP.deliveries[key(farmId, nid)] = d
	local n = GN.getNeighbour(nid)
	local count = 0
	local function spawnNext()
		if d.given >= need or count >= SP.MAX_UNITS or SP.deliveries[key(farmId, nid)] ~= d then
			GN.sendToFarm(farmId, "supplyReady", { nid = nid, fillType = ftName, amount = math.floor(d.given) })
			GN.log("supplies: %s put out %d l %s for farm %d", n.name, math.floor(d.given), ftName, farmId)
			return
		end
		-- a small grid at the silo place
		local col, row = count % 3, math.floor(count / 3)
		local s, c = math.sin(ry), math.cos(ry)
		local lx, lz = 6.5 + col * 2.4, -row * 2.4 -- beside the silo building
		local px, pz = x + lx * c + lz * s, z - lx * s + lz * c
		local py = (g_terrainNode ~= nil and getTerrainHeightAtWorldPos(g_terrainNode, px, 0, pz) or 0) + 0.2
		count = count + 1
		GN.Work.spawnVehicle(item.xmlFilename, px, py, pz, ry, function(v)
			if v ~= nil then
				local cap, level = 0, 0
				GN.try(function()
					cap = v:getFillUnitCapacity(1) or 0
					level = v:getFillUnitFillLevel(1) or 0
					if level < cap then
						v:addFillUnitFillLevel(GN.Work.NPC_FARM_ID, 1, cap - level, ft, ToolType ~= nil and ToolType.UNDEFINED or nil, nil)
					end
					level = v:getFillUnitFillLevel(1) or cap
				end)
				d.given = d.given + math.max(level, 500)
				table.insert(d.vehicles, v)
				GN.World.setVehicleState(v, nid, farmId)
			else
				d.given = need -- the item cannot be bought: stop
			end
			spawnNext()
		end)
	end
	spawnNext()
end

--- All his contracts of this farm are over: what is left goes back to him.
function SP.clear(nid, farmId)
	local d = SP.deliveries[key(farmId, nid)]
	if d == nil then
		return
	end
	SP.deliveries[key(farmId, nid)] = nil
	for _, v in ipairs(d.vehicles) do
		if GN.Work.isAlive(v) then
			GN.try(v.delete, v)
		end
	end
	GN.log("supplies: %s took his material back from farm %d", tostring(GN.getNeighbour(nid) ~= nil and GN.getNeighbour(nid).name), farmId)
end

-- ---------------------------------------------------------------------------
-- Savegame
-- ---------------------------------------------------------------------------

function SP.saveToXML(xml)
	local i = 0
	for _, d in pairs(SP.deliveries) do
		for _, v in ipairs(d.vehicles) do
			if GN.Work.isAlive(v) and v.uniqueId ~= nil then
				local k = string.format("goodNeighbours.supplies.unit(%d)", i)
				setXMLInt(xml, k .. "#farm", d.farmId)
				setXMLInt(xml, k .. "#neighbour", d.nid)
				setXMLString(xml, k .. "#vehicle", v.uniqueId)
				i = i + 1
			end
		end
	end
end

function SP.loadFromXML(xml)
	local i = 0
	while true do
		local k = string.format("goodNeighbours.supplies.unit(%d)", i)
		if not hasXMLProperty(xml, k) then
			break
		end
		table.insert(SP.saved, { farmId = getXMLInt(xml, k .. "#farm"), nid = getXMLInt(xml, k .. "#neighbour"), uid = getXMLString(xml, k .. "#vehicle") })
		i = i + 1
	end
end

--- After loading: find the saved units again (the vehicles exist only once the mission runs).
function SP.update(dt)
	if #SP.saved == 0 or g_currentMission == nil or g_currentMission.vehicleSystem == nil then
		return
	end
	SP.waited = (SP.waited or 0) + (dt or 0)
	if SP.waited < 15000 then
		return
	end
	local byUid = {}
	for _, v in pairs(g_currentMission.vehicleSystem.vehicles or {}) do
		if v.uniqueId ~= nil then
			byUid[v.uniqueId] = v
		end
	end
	for _, s in ipairs(SP.saved) do
		local v = byUid[s.uid]
		if v ~= nil and s.farmId ~= nil and s.nid ~= nil then
			local k = key(s.farmId, s.nid)
			SP.deliveries[k] = SP.deliveries[k] or { farmId = s.farmId, nid = s.nid, vehicles = {}, given = 0, need = 0 }
			table.insert(SP.deliveries[k].vehicles, v)
			GN.World.setVehicleState(v, s.nid, s.farmId)
		end
	end
	SP.saved = {}
	-- deliveries without a running contract any more: take back
	for _, d in pairs(SP.deliveries) do
		if not GN.Server.contractsRunning(d.nid, d.farmId) then
			SP.clear(d.nid, d.farmId)
		end
	end
end

SP.reset()
