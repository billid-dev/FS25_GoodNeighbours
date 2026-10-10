-- Good Neighbours (FS25) - the map sets itself up (server)
--   * neighbours' homes on their farmland, off the fields, close to buildings
--   * places for their machines (by size) around the home: off the fields, flat, free of buildings and trees
--   * places they visit (shop, filling station, workshop, grain trade, square, church, town hall, resting, walks)
--     found on the map from its buildings and sell points
-- Works on any map; the admin only corrects single places with the construction tools.
-- Places made here are marked auto = true. Nothing set by a player is ever moved.
-- Author: billiD

local GN = GoodNeighbours

GN.Auto = GN.Auto or {}
local A = GN.Auto

-- how many visit places of each type the neighbours want on the map
A.PLACE_MIN = { gas = 2, shop = 2, public = 3, church = 1, townhall = 1, workshop = 1, trade = 2, relax = 2, walk = 3 }
A.STEPS_PER_TICK = 60          -- checks per update (spread over many frames)

-- keywords in the file names of map buildings
A.KEYWORDS = {
	shop = { "shop", "store", "market", "supermarket", "kiosk", "dealer" },
	gas = { "gas", "fuel", "diesel", "petrol", "tankstelle", "filling" },
	workshop = { "workshop", "garage", "repair", "mechanic", "werkstatt" },
	church = { "church", "chapel", "kirche", "kapelle", "kosciol", "cathedral" },
	townhall = { "townhall", "cityhall", "town_hall", "city_hall", "rathaus", "municipal", "administration", "office" },
	public = { "square", "parking", "plaza", "pub", "restaurant", "cafe", "bar", "hotel", "school", "bakery" },
	relax = { "bench", "picnic", "playground", "park", "pier", "lake", "pond", "fountain", "viewpoint" },
}

function A.reset()
	A.jobs = {}
	A.tasks = nil
	A.polys = nil
	A.done = false
	A.started = false
end

-- ---------------------------------------------------------------------------
-- Ground checks
-- ---------------------------------------------------------------------------

local function terrainY(x, z)
	return g_terrainNode ~= nil and getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z) or 0
end

--- Field outlines (polygons from the field's corner nodes), cached.
function A.fieldPolys()
	if A.polys ~= nil then
		return A.polys
	end
	A.polys = {}
	for _, field in pairs(g_fieldManager ~= nil and g_fieldManager:getFields() or {}) do
		local pts = {}
		for _, node in ipairs(field.polygonPoints or {}) do
			if node ~= nil and entityExists(node) then
				local x, _, z = getWorldTranslation(node)
				table.insert(pts, { x, z })
			end
		end
		if #pts >= 3 then
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, p in ipairs(pts) do
				minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
				minZ, maxZ = math.min(minZ, p[2]), math.max(maxZ, p[2])
			end
			table.insert(A.polys, { pts = pts, minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ, field = field })
		end
	end
	return A.polys
end

local function inPoly(pts, x, z)
	local inside = false
	local j = #pts
	for i = 1, #pts do
		local xi, zi, xj, zj = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
		if ((zi > z) ~= (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi) then
			inside = not inside
		end
		j = i
	end
	return inside
end

--- On a field (or closer than margin metres to one)?
function A.onField(x, z, margin)
	margin = margin or 0
	for _, p in ipairs(A.fieldPolys()) do
		if x >= p.minX - margin and x <= p.maxX + margin and z >= p.minZ - margin and z <= p.maxZ + margin then
			if inPoly(p.pts, x, z) then
				return true
			end
			if margin > 0 then
				for _, d in ipairs({ { margin, 0 }, { -margin, 0 }, { 0, margin }, { 0, -margin } }) do
					if inPoly(p.pts, x + d[1], z + d[2]) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function isUnderTerrain(node)
	local root = g_currentMission ~= nil and g_currentMission.terrainRootNode or nil
	local n, depth = node, 0
	while n ~= nil and n ~= 0 and depth < 12 do
		if n == g_terrainNode or n == root then
			return true
		end
		if not entityExists(n) then
			return false
		end
		n = getParent(n)
		depth = depth + 1
	end
	return false
end

function A:gnOverlapCallback(node)
	if node ~= nil and node ~= 0 and not isUnderTerrain(node) then
		local obj = g_currentMission ~= nil and g_currentMission.getNodeObject ~= nil and g_currentMission:getNodeObject(node) or nil
		-- vehicles move away, they do not block a place
		if obj == nil or (obj.spec_wheels == nil and obj.rootVehicle == nil) then
			A._hits = (A._hits or 0) + 1
		end
	end
	return true
end

--- Something solid (building, wall, tree, placeable) within r metres of the point?
function A.blocked(x, z, r)
	if overlapSphere == nil then
		return false
	end
	A._hits = 0
	local y = terrainY(x, z) + r + 0.3
	local ok = GN.try(overlapSphere, x, y, z, r, "gnOverlapCallback", A)
	return ok and (A._hits or 0) > 0
end

--- Number of solid things around (buildings near a home, a yard).
function A.buildingsAround(x, z, r)
	if overlapSphere == nil then
		return 0
	end
	A._hits = 0
	GN.try(overlapSphere, x, terrainY(x, z) + 3, z, r, "gnOverlapCallback", A)
	return A._hits or 0
end

-- ---------------------------------------------------------------------------
-- Place shapes
-- ---------------------------------------------------------------------------

local function offset(x, z, ry, lx, lz)
	local s, c = math.sin(ry), math.cos(ry)
	return x + lx * c + lz * s, z - lx * s + lz * c
end

--- Sample points of a place (corners, edges, centre); home / visit place = small circle.
function A.shapePoints(x, z, ry, size)
	local b = GN.Tools ~= nil and GN.Tools.BOX[size] or nil
	if b == nil then
		return { { x, z }, { x + 1.2, z }, { x - 1.2, z }, { x, z + 1.2 }, { x, z - 1.2 } }, 1.2
	end
	local front, back = GN.Tools.FRONT, -(b.len - GN.Tools.FRONT)
	local pts = {}
	for _, lz in ipairs({ front, (front + back) / 2, back }) do
		for _, lx in ipairs({ -b.side, 0, b.side }) do
			local px, pz = offset(x, z, ry, lx, lz)
			table.insert(pts, { px, pz })
		end
	end
	return pts, b.side
end

local function insideShape(px, pz, p, grow)
	local b = p.len ~= nil and p or GN.Tools.BOX[p.size]
	if b == nil then
		return (px - p.x) ^ 2 + (pz - p.z) ^ 2 < (1.5 + grow) ^ 2
	end
	-- to the place's local frame
	local s, c = math.sin(p.ry or 0), math.cos(p.ry or 0)
	local dx, dz = px - p.x, pz - p.z
	local lx = dx * c - dz * s
	local lz = dx * s + dz * c
	return math.abs(lx) <= b.side + grow and lz <= GN.Tools.FRONT + grow and lz >= -(b.len - GN.Tools.FRONT) - grow
end

--- Do two machine places overlap? (both as boxes)
function A.boxesOverlap(p, q)
	for _, a in ipairs({ { p, q }, { q, p } }) do
		local pts = A.shapePoints(a[1].x, a[1].z, a[1].ry or 0, a[1].size or "attach")
		for _, pt in ipairs(pts) do
			if insideShape(pt[1], pt[2], { x = a[2].x, z = a[2].z, ry = a[2].ry or 0, size = a[2].size or "attach" }, -0.3) then
				return true
			end
		end
	end
	return false
end

--- All places already used (homes, machine places, visit places), as shapes.
function A.usedShapes()
	local S = GN.Server
	local out = {}
	for nid, h in pairs(S.home) do
		table.insert(out, { x = h.x, z = h.z, ry = h.ry or 0, size = "home" })
	end
	for _, list in pairs(S.slots) do
		for _, p in ipairs(list) do
			table.insert(out, { x = p.x, z = p.z, ry = p.ry or 0, size = p.size or "attach" })
		end
	end
	for _, p in ipairs(S.places) do
		table.insert(out, { x = p.x, z = p.z, ry = p.ry or 0, size = "home" })
	end
	for _, b in ipairs(S.buildingAreas or {}) do
		table.insert(out, b)
	end
	return out
end

--- Can a place of this size go here? (off the fields, flat, free, not on another place)
function A.fits(x, z, ry, size, used, opts)
	opts = opts or {}
	if A.onField(x, z, opts.fieldMargin or 3) then
		return false
	end
	local pts, side = A.shapePoints(x, z, ry, size)
	local minY, maxY = math.huge, -math.huge
	for _, p in ipairs(pts) do
		if A.onField(p[1], p[2], 1) then
			return false
		end
		local y = terrainY(p[1], p[2])
		minY, maxY = math.min(minY, y), math.max(maxY, y)
		for _, u in ipairs(used) do
			if insideShape(p[1], p[2], u, 1.0) then
				return false
			end
		end
	end
	if maxY - minY > (opts.maxSlope or 1.4) then
		return false
	end
	if opts.farmlands ~= nil and g_farmlandManager ~= nil and g_farmlandManager.getFarmlandIdAtWorldPosition ~= nil then
		local fl = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
		if not opts.farmlands[fl] then
			return false
		end
	end
	-- the existing places must not lie in the new one either
	for _, u in ipairs(used) do
		if insideShape(u.x, u.z, { x = x, z = z, ry = ry, size = size }, 1.0) then
			return false
		end
	end
	-- solid things: probe along the shape
	local probes = { pts[5] or pts[1] }
	if #pts >= 9 then
		probes = { pts[1], pts[3], pts[5], pts[7], pts[9] }
	end
	for _, p in ipairs(probes) do
		if A.blocked(p[1], p[2], math.min(side or 1.2, 2.2)) then
			return false
		end
	end
	return true
end

--- A search outwards from (cx, cz) for the nearest spot that fits. The game has no coroutines for mods,
--- so the search goes on a few checks per frame: A.searchStep(search, budget) -> true when finished
--- (search.x, search.z, search.ry set when a spot was found).
function A.newSearch(cx, cz, size, opts)
	opts = opts or {}
	return { cx = cx, cz = cz, size = size, opts = opts, r = opts.minR or 6, maxR = opts.maxR or 160, step = opts.step or 4,
		i = 0, yi = 1, yaws = opts.yaws or { 0, math.pi / 2 }, used = A.usedShapes() }
end

function A.searchStep(sr, budget)
	while budget > 0 do
		if sr.r > sr.maxR then
			return true
		end
		sr.n = sr.n or math.max(8, math.floor(2 * math.pi * math.max(sr.r, 1) / sr.step))
		if sr.i >= sr.n then
			sr.r, sr.i, sr.yi, sr.n = sr.r + sr.step, 0, 1, nil
		else
			local a = sr.i / sr.n * 2 * math.pi
			local x, z = sr.cx + math.cos(a) * sr.r, sr.cz + math.sin(a) * sr.r
			local ry = sr.opts.faceCentre and (math.atan2 or math.atan)(sr.cx - x, sr.cz - z) or sr.yaws[sr.yi]
			budget = budget - 1
			if A.fits(x, z, ry, sr.size, sr.used, sr.opts) then
				sr.x, sr.z, sr.ry = x, z, ry
				return true
			end
			if sr.opts.faceCentre or sr.yi >= #sr.yaws then
				sr.i, sr.yi = sr.i + 1, 1
			else
				sr.yi = sr.yi + 1
			end
		end
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Map buildings -> visit places
-- ---------------------------------------------------------------------------

local function nameOf(p)
	return string.lower(tostring(p.configFileName or (p.storeItem ~= nil and p.storeItem.xmlFilename) or ""))
end

local function hotspotTypeNames(p)
	local out = {}
	local spec = p.spec_hotspots
	if spec ~= nil and spec.mapHotspots ~= nil and PlaceableHotspot ~= nil and PlaceableHotspot.TYPE ~= nil then
		for _, hs in ipairs(spec.mapHotspots) do
			for name, v in pairs(PlaceableHotspot.TYPE) do
				if v == hs.placeableType then
					table.insert(out, string.lower(name))
				end
			end
		end
	end
	return out
end

local function placeablePos(p)
	local spec = p.spec_hotspots
	if spec ~= nil and spec.mapHotspots ~= nil and spec.mapHotspots[1] ~= nil and spec.mapHotspots[1].getWorldPosition ~= nil then
		local ok, x, z = GN.try(spec.mapHotspots[1].getWorldPosition, spec.mapHotspots[1])
		if ok and x ~= nil then
			return x, z
		end
	end
	if p.rootNode ~= nil and entityExists(p.rootNode) then
		local x, _, z = getWorldTranslation(p.rootNode)
		return x, z
	end
	return nil
end

local function hasWord(s, words)
	for _, w in ipairs(words) do
		if string.find(s, w, 1, true) ~= nil then
			return true
		end
	end
	return false
end

--- Candidate points per place type found on the map: type -> list of { x, z, name }.
function A.scanMap()
	local found = {}
	local function add(t, x, z, name)
		if x == nil then
			return
		end
		found[t] = found[t] or {}
		for _, e in ipairs(found[t]) do
			if (e.x - x) ^ 2 + (e.z - z) ^ 2 < 40 ^ 2 then
				return -- one place per building group
			end
		end
		table.insert(found[t], { x = x, z = z, name = name })
	end
	local names = {}
	local ps = g_currentMission.placeableSystem ~= nil and g_currentMission.placeableSystem.placeables or {}
	for _, p in ipairs(ps) do
		local owner = p.getOwnerFarmId ~= nil and p:getOwnerFarmId() or 0
		if not GN.isPlayerFarm(owner) and p.spec_gnTool == nil then
			local name = nameOf(p)
			local short = string.match(name, "([^/]+)%.xml$") or name
			names[short] = true
			local x, z = placeablePos(p)
			local hs = table.concat(hotspotTypeNames(p), " ")
			if p.spec_sellingStation ~= nil then
				add("trade", x, z, short)
			end
			if p.spec_workshop ~= nil or hasWord(name, A.KEYWORDS.workshop) or string.find(hs, "workshop", 1, true) then
				add("workshop", x, z, short)
			end
			if (p.spec_buyingStation ~= nil and hasWord(name, A.KEYWORDS.gas)) or string.find(hs, "fuel", 1, true) or string.find(hs, "gas", 1, true) then
				add("gas", x, z, short)
			end
			if string.find(hs, "shop", 1, true) or hasWord(name, A.KEYWORDS.shop) then
				add("shop", x, z, short)
			end
			if p.spec_npcSpot ~= nil then
				add("public", x, z, short)
			end
			for _, t in ipairs({ "church", "townhall", "public", "relax" }) do
				if hasWord(name, A.KEYWORDS[t]) then
					add(t, x, z, short)
				end
			end
		end
	end
	-- the vehicle shop: where bought vehicles appear
	for _, sp in ipairs(g_currentMission.storeSpawnPlaces or {}) do
		if sp.startX ~= nil then
			add("shop", sp.startX, sp.startZ, "storeSpawnPlace")
		end
	end
	local list = {}
	for n in pairs(names) do
		table.insert(list, n)
	end
	table.sort(list)
	GN.log("auto places: map buildings: %s", table.concat(list, ", "))
	for t, l in pairs(found) do
		GN.log("auto places: %d candidate(s) for %s", #l, t)
	end
	return found
end

-- ---------------------------------------------------------------------------
-- The set-up run (coroutine, a few checks per frame)
-- ---------------------------------------------------------------------------

local function farmlandsOf(nid)
	local set = {}
	for fl, owner in pairs(GN.Server.assign) do
		if owner == nid then
			set[fl] = true
		end
	end
	return set
end

local function fieldCentresOf(nid)
	local out = {}
	local fls = farmlandsOf(nid)
	for _, p in ipairs(A.fieldPolys()) do
		local f = p.field
		local fl = f.farmland ~= nil and f.farmland.id or nil
		if fl ~= nil and fls[fl] then
			local x, z = (p.minX + p.maxX) / 2, (p.minZ + p.maxZ) / 2
			if f.posX ~= nil then
				x, z = f.posX, f.posZ
			end
			table.insert(out, { x = x, z = z, area = (p.maxX - p.minX) * (p.maxZ - p.minZ), fl = fl })
		end
	end
	table.sort(out, function(a, b) return a.area > b.area end)
	return out
end

--- A farmer's yard: on his farmland, off the fields, where buildings stand (the farm's houses and barns).
--- Returns a search object for A.homeStep.
function A.newHomeSearch(nid)
	local centres = fieldCentresOf(nid)
	local pts = {}
	for ci = 1, math.min(3, #centres) do
		local c = centres[ci]
		for r = 20, 420, 20 do
			local n = math.max(8, math.floor(2 * math.pi * r / 30))
			for i = 0, n - 1 do
				local a = i / n * 2 * math.pi
				table.insert(pts, { c.x + math.cos(a) * r, c.z + math.sin(a) * r, r })
			end
		end
	end
	return { pts = pts, k = 1, fls = farmlandsOf(nid), used = A.usedShapes(), bestScore = -math.huge }
end

function A.homeStep(hs, budget)
	while budget > 0 do
		local p = hs.pts[hs.k]
		if p == nil then
			return true
		end
		hs.k = hs.k + 1
		budget = budget - 1
		local x, z, r = p[1], p[2], p[3]
		local fl = g_farmlandManager ~= nil and g_farmlandManager.getFarmlandIdAtWorldPosition ~= nil and g_farmlandManager:getFarmlandIdAtWorldPosition(x, z) or nil
		if (fl == nil or hs.fls[fl]) and not A.onField(x, z, 8) then
			local b = A.buildingsAround(x, z, 30)
			local score = math.min(b, 12) * 60 - r
			if score > hs.bestScore and A.fits(x, z, 0, "home", hs.used, { fieldMargin = 8 }) then
				hs.best, hs.bestScore = { x = x, z = z, ry = 0 }, score
			end
		end
	end
	return false
end

--- The whole set-up as a list of tasks; every task gets a budget of checks per frame and says when it is done.
function A.buildTasks()
	local S, W = GN.Server, GN.Work
	local tasks = {}
	local made = { homes = 0, slots = 0, places = 0, buildings = 0 }
	A.made = made
	local function add(fn)
		table.insert(tasks, { fn = fn })
	end
	A.polys = nil
	-- auto machine places of a moved home go with it
	for nid, list in pairs(S.slots) do
		local h = S.home[nid]
		if h ~= nil and (h.auto or A.onField(h.x, h.z, 0)) then
			local keep = {}
			for _, p in ipairs(list) do
				if not p.auto then
					table.insert(keep, p)
				end
			end
			S.slots[nid] = keep
		end
	end
	-- 1. visit places from the map buildings
	local found = A.scanMap()
	local byType = {}
	for _, p in ipairs(S.places) do
		byType[p.type] = (byType[p.type] or 0) + 1
	end
	local anchor = nil
	for _, t in ipairs({ "shop", "trade", "gas", "workshop", "public" }) do
		if found[t] ~= nil and found[t][1] ~= nil then
			anchor = anchor or found[t][1]
		end
	end
	for _, t in ipairs({ "shop", "gas", "workshop", "trade", "public", "church", "townhall", "relax" }) do
		local cands = found[t] or {}
		if #cands == 0 and anchor ~= nil and (t == "church" or t == "townhall" or t == "public" or t == "relax") then
			cands = { { x = anchor.x + (t == "church" and 60 or t == "townhall" and -60 or t == "relax" and 90 or 30), z = anchor.z + (t == "relax" and 60 or 20) } }
		end
		local ci = 0
		local sr = nil
		add(function(task, budget)
			if (byType[t] or 0) >= A.PLACE_MIN[t] then
				return true
			end
			if sr == nil then
				ci = ci + 1
				local c = cands[ci]
				if c == nil then
					return true
				end
				sr = A.newSearch(c.x, c.z, "home", { minR = 4, maxR = 45, step = 3, faceCentre = true, fieldMargin = 2 })
			end
			if A.searchStep(sr, budget) then
				if sr.x ~= nil then
					table.insert(S.places, { type = t, x = sr.x, z = sr.z, ry = sr.ry, auto = true })
					byType[t] = (byType[t] or 0) + 1
					made.places = made.places + 1
				end
				sr = nil
			end
			return false
		end)
	end
	-- 2. homes
	for _, n in ipairs(GN.neighbours) do
		local cur = S.home[n.id]
		if cur ~= nil and not cur.auto and n.contracts and A.onField(cur.x, cur.z, 0) then
			cur.auto = true -- an old default home in the middle of a field: move it to the yard
		end
		if cur == nil or cur.auto then
			local hs, sr, pi = nil, nil, 0
			add(function(task, budget)
				local h = nil
				if n.contracts then
					hs = hs or A.newHomeSearch(n.id)
					if not A.homeStep(hs, budget) then
						return false
					end
					h = hs.best
				else
					local near = ({ mayor = "townhall", trader = "trade", dealer = "workshop" })[n.role]
					if sr == nil then
						repeat
							pi = pi + 1
						until S.places[pi] == nil or S.places[pi].type == near
						local p = S.places[pi]
						if p == nil then
							return true
						end
						sr = A.newSearch(p.x, p.z, "home", { minR = 6, maxR = 60, step = 3, faceCentre = true })
					end
					if not A.searchStep(sr, budget) then
						return false
					end
					if sr.x == nil then
						sr = nil
						return false -- next place of that type
					end
					h = { x = sr.x, z = sr.z, ry = sr.ry }
				end
				if h ~= nil and (S.home[n.id] == nil or S.home[n.id].auto) then
					h.auto = true
					S.home[n.id] = h
					made.homes = made.homes + 1
					GN.log("auto places: home of %s at (%.0f, %.0f)", n.name, h.x, h.z)
				end
				return true
			end)
		end
	end
	-- 3. walks between a farmer's yard and his fields
	for _, n in ipairs(GN.neighbours) do
		if n.contracts then
			local sr = nil
			add(function(task, budget)
				if (byType.walk or 0) >= A.PLACE_MIN.walk then
					return true
				end
				if sr == nil then
					local h = S.home[n.id]
					local c = fieldCentresOf(n.id)[1]
					if h == nil or c == nil then
						return true
					end
					sr = A.newSearch((h.x + c.x) / 2, (h.z + c.z) / 2, "home", { minR = 0, maxR = 80, step = 5, fieldMargin = 2 })
				end
				if not A.searchStep(sr, budget) then
					return false
				end
				if sr.x ~= nil then
					table.insert(S.places, { type = "walk", x = sr.x, z = sr.z, ry = sr.ry, auto = true })
					byType.walk = (byType.walk or 0) + 1
					made.places = made.places + 1
				end
				return true
			end)
		end
	end
	-- 4. machine places around every home: as many of each size as the neighbour needs
	for _, n in ipairs(GN.neighbours) do
		for _, size in ipairs({ "oversize", "attach", "vehicle", "silo" }) do
			local sr = nil
			add(function(task, budget)
				local h = S.home[n.id]
				if h == nil then
					return true
				end
				local have = 0
				for _, p in ipairs(S.slots[n.id] or {}) do
					if (p.size or "attach") == size then
						have = have + 1
					end
				end
				if have >= (W.requiredPlaces(n.id)[size] or 0) then
					return true
				end
				sr = sr or A.newSearch(h.x, h.z, size, { minR = 8, maxR = 180, step = 4 })
				if not A.searchStep(sr, budget) then
					return false
				end
				if sr.x == nil then
					GN.log("auto places: no room for a %s place near the home of %s", size, n.name)
					return true
				end
				S.slots[n.id] = S.slots[n.id] or {}
				table.insert(S.slots[n.id], { x = sr.x, z = sr.z, ry = sr.ry, size = size, auto = true })
				made.slots = made.slots + 1
				sr = nil
				return false -- maybe more of this size
			end)
		end
	end
	-- 5. the silo building stands on the silo place (GN.Silo builds it when the place exists)
	add(function()
		GN.log("auto places done: %d home(s), %d machine place(s), %d visit place(s), %d building(s)",
			made.homes, made.slots, made.places, made.buildings)
		return true
	end)
	return tasks
end

--- Called every frame on the server: first run after loading, then only on request.
function A.serverUpdate(dt)
	if not GN.Server.loaded then
		return
	end
	if not A.started then
		A.started = true
		if A.somethingMissing() then
			A.start("savegame loaded")
		else
			A.done = true
		end
	end
	A.update(dt)
end

--- Admin asked: fill everything that is missing (reset = also redo all automatic places).
function A.onRequest(data, connection)
	if not GN.isConnectionAdmin(connection) or A.tasks ~= nil then
		return
	end
	local S = GN.Server
	if data.reset then
		for nid, list in pairs(S.slots) do
			local keep = {}
			for _, p in ipairs(list) do
				if not p.auto then
					table.insert(keep, p)
				end
			end
			S.slots[nid] = keep
		end
		local keep = {}
		for _, p in ipairs(S.places) do
			if not p.auto then
				table.insert(keep, p)
			end
		end
		S.places = keep
	end
	A.start(data.reset and "admin: redo" or "admin: fill missing")
	GN.sendToConnection(connection, "toolPlaced", { action = "auto" })
end

-- ---------------------------------------------------------------------------
-- Neighbours' buildings (the game's own silos and sheds, owned by the neighbours' farm)
-- ---------------------------------------------------------------------------

A.BUILDING_CATEGORIES = { silo = { "SILOS", "SILO" }, shed = { "SHEDS", "SHED" } }

function A.buildingItems(kind)
	local cats = A.BUILDING_CATEGORIES[kind]
	local out = {}
	for _, item in ipairs(g_storeManager ~= nil and g_storeManager:getItems() or {}) do
		local cat = string.upper(tostring(item.categoryName or ""))
		local ok = false
		for _, c in ipairs(cats) do
			if cat == c then
				ok = true
			end
		end
		local file = string.lower(tostring(item.xmlFilename or ""))
		-- base game only; no buildings that buy land or produce things
		if ok and item.customEnvironment == nil and (item.price or 0) > 0 and not string.find(file, "extension", 1, true)
			and not string.find(file, "production", 1, true) then
			table.insert(out, item)
		end
	end
	table.sort(out, function(a, b) return (a.price or 0) < (b.price or 0) end)
	return out
end

--- A building of the game for the neighbours' farm near (x, z): search room, then build, then wait for loading.
function A.newBuilding(n, kind, x, z)
	if PlaceableLoadingData == nil then
		return nil
	end
	local items = A.buildingItems(kind)
	if #items == 0 then
		GN.log("auto places: no %s in the shop", kind)
		return nil
	end
	local item = items[(n.id % math.min(3, #items)) + 1]
	local w, l = 8, 10
	GN.try(function()
		local size = StoreItemUtil.getSizeValues(item.xmlFilename, "placeable", 0)
		if size ~= nil and size.width ~= nil and size.width > 0 then
			w, l = size.width, size.length
		end
	end)
	local boxKey = "b_" .. kind .. "_" .. tostring(n.id)
	GN.Tools.BOX[boxKey] = { len = l + 3, side = w / 2 + 1.5 }
	return { n = n, kind = kind, item = item, w = w, l = l, boxKey = boxKey, waited = 0,
		search = A.newSearch(x, z, boxKey, { minR = 8, maxR = 140, step = 5, maxSlope = 1.0, fieldMargin = 4 }) }
end

function A.buildingStep(b, budget)
	if b.state == nil then
		if not A.searchStep(b.search, budget) then
			return false
		end
		local sr = b.search
		if sr.x == nil then
			GN.log("auto places: no room for a %s of %s", b.kind, b.n.name)
			return true
		end
		local mid = -(b.l + 3) / 2 + GN.Tools.FRONT
		local cx, cz = sr.x + mid * math.sin(sr.ry), sr.z + mid * math.cos(sr.ry)
		b.state = { done = false }
		b.area = { x = sr.x, z = sr.z, ry = sr.ry, len = b.l + 3, side = b.w / 2 + 1.5 }
		local ok = GN.try(function()
			local data = PlaceableLoadingData.new()
			data:setStoreItem(b.item)
			data:setPosition(cx, (g_terrainNode ~= nil and getTerrainHeightAtWorldPos(g_terrainNode, cx, 0, cz) or 0), cz)
			data:setRotation(0, sr.ry, 0)
			data:setOwnerFarmId(GN.Work.NPC_FARM_ID)
			data:load(function(_, placeable, loadingState)
				b.state.done = true
				if placeable ~= nil and (PlaceableLoadingState == nil or loadingState == PlaceableLoadingState.OK) then
					GN.try(placeable.finalizePlacement, placeable)
					b.state.placeable = placeable
				end
			end)
		end)
		if not ok then
			return true
		end
		return false
	end
	if not b.state.done then
		b.waited = b.waited + 1
		return b.waited > 2000
	end
	local p = b.state.placeable
	if p == nil then
		GN.log("auto places: could not build a %s for %s (%s)", b.kind, b.n.name, tostring(b.item.xmlFilename))
		return true
	end
	table.insert(GN.Server.buildingAreas, b.area)
	b.uid = tostring((p.getUniqueId ~= nil and p:getUniqueId()) or p.uniqueId or "built")
	GN.log("auto places: %s got a %s (%s)", b.n.name, b.kind, tostring(b.item.xmlFilename))
	return true
end

--- Start a set-up run (server).
function A.start(reason)
	if A.tasks ~= nil or g_currentMission == nil then
		return
	end
	A.reason = reason
	local ok, res = GN.try(A.buildTasks)
	if not ok then
		GN.log("auto places failed: %s", tostring(res))
		A.done = true
		return
	end
	A.tasks = res
	A.running = true
	GN.log("auto places: started (%s), %d step(s)", tostring(reason), #A.tasks)
end

function A.update(dt)
	if A.tasks == nil then
		return
	end
	local t0 = getTimeSec ~= nil and getTimeSec() or nil
	local rounds = 0
	repeat
		local task = A.tasks[1]
		if task == nil then
			A.tasks = nil
			A.running = false
			A.done = true
			GN.sendToAll("homes", GN.Server.worldMsg())
			GN.safeCall("machines to places", GN.Work.syncAll)
			return
		end
		local ok, finished = GN.try(task.fn, task, A.STEPS_PER_TICK)
		if not ok then
			GN.log("auto places: step failed: %s", tostring(finished))
			finished = true
		end
		if finished then
			table.remove(A.tasks, 1)
		end
		rounds = rounds + 1
	until (t0 ~= nil and getTimeSec() - t0 > 0.004) or (t0 == nil and rounds >= 4)
end

--- Anything missing that the set-up could add?
function A.somethingMissing()
	local S, W = GN.Server, GN.Work
	for _, n in ipairs(GN.neighbours) do
		if S.home[n.id] == nil then
			return true
		end
		local req = W.requiredPlaces(n.id)
		local have = {}
		for _, p in ipairs(S.slots[n.id] or {}) do
			have[p.size or "attach"] = (have[p.size or "attach"] or 0) + 1
		end
		for _, size in ipairs({ "oversize", "attach", "vehicle", "silo" }) do
			if (have[size] or 0) < (req[size] or 0) then
				return true
			end
		end
	end
	local byType = {}
	for _, p in ipairs(S.places) do
		byType[p.type] = (byType[p.type] or 0) + 1
	end
	for t, m in pairs(A.PLACE_MIN) do
		if (byType[t] or 0) < m then
			return true
		end
	end
	return false
end

A.reset()
