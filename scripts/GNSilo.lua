-- Good Neighbours (FS25) - the farmer's silo building on his silo place (server)
-- As in FoS: when the silo place of a farmer is set with the construction tool, a farm silo of the game stands
-- there at once (owned by the neighbours' farm); when the place is removed, the silo goes too.
-- The silo is not written to the savegame: it is built again on every load from the silo place.
-- Author: billiD

local GN = GoodNeighbours

GN.Silo = GN.Silo or {}
local SI = GN.Silo

-- base game farm silos, first one found in the shop is used
SI.FILES = {
	"data/placeables/unia/farma/farma400/farma400.xml",
	"data/placeables/mapUS/farmSilo/farmSilo.xml",
	"data/placeables/mapEU/farmSilo/farmSilo.xml",
}
SI.CHECK_MS = 3000
SI.BOX_LEN = 7 -- length of the silo place box (GN.Tools.BOX.silo)

function SI.reset()
	SI.timer = 0
	SI.list = {}   -- { place = slot table, nid, placeable, loading }
	SI.item = nil
	SI.noItem = false
end

function SI.storeItem()
	if SI.item ~= nil or SI.noItem then
		return SI.item
	end
	for _, f in ipairs(SI.FILES) do
		local it = GN.Work.storeItemByFile(f)
		if it ~= nil then
			SI.item = it
			break
		end
	end
	if SI.item == nil then
		-- any base game silo, the cheapest
		local best = nil
		for _, it in ipairs(g_storeManager ~= nil and g_storeManager:getItems() or {}) do
			local cat = string.upper(tostring(it.categoryName or ""))
			if (cat == "SILOS" or cat == "SILO") and it.customEnvironment == nil and (it.price or 0) > 0
				and not string.find(string.lower(tostring(it.xmlFilename)), "extension", 1, true) then
				if best == nil or (it.price or 0) < (best.price or 0) then
					best = it
				end
			end
		end
		SI.item = best
	end
	SI.noItem = SI.item == nil
	GN.log("silos: building %s", tostring(SI.item ~= nil and SI.item.xmlFilename or "none in the shop"))
	return SI.item
end

local function alive(p)
	return p ~= nil and not p.isDeleted and (p.rootNode == nil or entityExists(p.rootNode))
end

local function entryFor(place)
	for _, e in ipairs(SI.list) do
		if e.place == place then
			return e
		end
	end
	return nil
end

--- Silo already standing there (e.g. saved by an older version)? Then it is used.
local function existingAt(x, z)
	local ps = g_currentMission.placeableSystem
	for _, p in ipairs(ps ~= nil and ps.placeables or {}) do
		if alive(p) and p.spec_silo ~= nil and p.rootNode ~= nil and p.getOwnerFarmId ~= nil and p:getOwnerFarmId() == GN.Work.NPC_FARM_ID then
			local px, _, pz = getWorldTranslation(p.rootNode)
			if (px - x) ^ 2 + (pz - z) ^ 2 < 6 * 6 then
				return p
			end
		end
	end
	return nil
end

--- Middle of the silo place box (the place point is its front).
function SI.centre(place)
	local ry = place.ry or 0
	local mid = -SI.BOX_LEN / 2 + (GN.Tools ~= nil and GN.Tools.FRONT or 3)
	return place.x + mid * math.sin(ry), place.z + mid * math.cos(ry), ry
end

function SI.build(e)
	local item = SI.storeItem()
	if item == nil or PlaceableLoadingData == nil then
		e.failed = true
		return
	end
	local x, z, ry = SI.centre(e.place)
	local found = existingAt(x, z)
	if found ~= nil then
		e.placeable = found
		return
	end
	e.loading = true
	local ok, err = GN.try(function()
		local data = PlaceableLoadingData.new()
		data:setStoreItem(item)
		data:setPosition(x, g_terrainNode ~= nil and getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z) or 0, z)
		data:setRotation(0, ry, 0)
		data:setOwnerFarmId(GN.Work.NPC_FARM_ID)
		if data.setIsSaved ~= nil then
			data:setIsSaved(false)
		end
		data:load(function(_, placeable, loadingState)
			e.loading = false
			if placeable ~= nil and (PlaceableLoadingState == nil or loadingState == nil or loadingState == PlaceableLoadingState.OK) then
				GN.try(placeable.finalizePlacement, placeable)
				if e.removed then
					GN.try(placeable.delete, placeable)
				else
					e.placeable = placeable
					GN.log("silos: %s's silo stands at (%.0f, %.0f)", tostring(GN.getNeighbour(e.nid) ~= nil and GN.getNeighbour(e.nid).name), x, z)
				end
			else
				e.failed = true
				GN.log("silos: could not build the silo of %s (%s)", tostring(e.nid), tostring(loadingState))
			end
		end)
	end)
	if not ok then
		e.loading = false
		e.failed = true
		GN.log("silos: could not build: %s", tostring(err))
	end
end

function SI.remove(e)
	e.removed = true
	if alive(e.placeable) then
		GN.try(e.placeable.delete, e.placeable)
		GN.log("silos: silo of %s taken away with its place", tostring(GN.getNeighbour(e.nid) ~= nil and GN.getNeighbour(e.nid).name))
	end
	e.placeable = nil
end

--- Silo places <-> silo buildings.
function SI.sync()
	if g_currentMission == nil or not GN.Server.loaded then
		return
	end
	local want = {}
	for nid, list in pairs(GN.Server.slots) do
		local n = GN.getNeighbour(nid)
		if n ~= nil and n.contracts then
			for _, p in ipairs(list) do
				if p.size == "silo" then
					want[p] = nid
				end
			end
		end
	end
	for i = #SI.list, 1, -1 do
		local e = SI.list[i]
		if want[e.place] == nil then
			SI.remove(e)
			table.remove(SI.list, i)
		end
	end
	for place, nid in pairs(want) do
		local e = entryFor(place)
		if e == nil then
			e = { place = place, nid = nid }
			table.insert(SI.list, e)
		end
		if not e.loading and not e.failed and not alive(e.placeable) then
			SI.build(e)
		end
	end
end

function SI.update(dt)
	SI.timer = SI.timer + (dt or 0)
	if SI.timer < SI.CHECK_MS then
		return
	end
	SI.timer = 0
	if GN.Auto ~= nil and not GN.Auto.done then
		return
	end
	if g_currentMission.isMissionStarted == false then
		return
	end
	SI.sync()
end

--- The silo of a neighbour (for the supplies), or nil.
function SI.of(nid)
	for _, e in ipairs(SI.list) do
		if e.nid == nid and alive(e.placeable) then
			return e.placeable, e.place
		end
	end
	return nil
end

function SI.deleteAll()
	for _, e in ipairs(SI.list or {}) do
		SI.remove(e)
	end
	SI.list = {}
end

SI.reset()
