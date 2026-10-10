-- Good Neighbours (FS25) - daily plan of every neighbour
-- The same on every computer (worked out from the neighbour and the day), so nothing has to be sent.
-- Author: billiD

local GN = GoodNeighbours

GN.Plan = GN.Plan or {}
local PL = GN.Plan

-- activity: visible = stands at home, false = not around (asleep / away)
-- place: where the neighbour is during the activity (a type of place set with the construction tools,
-- or a list of types - one is picked per day); no place / no such place on the map = at home
-- a list of places = one is picked per day ("home" = he stays at home that day); "visit" = a player's farm yard
PL.TEMPLATES = {
	farmer = {
		{ from = 5 * 60 + 30, key = "chores", visible = true },
		{ from = 7 * 60, key = "work", visible = true },
		{ from = 12 * 60, key = "lunch", visible = true },
		{ from = 13 * 60, key = "work", visible = true },
		{ from = 16 * 60 + 30, key = "errands", visible = true, place = { "shop", "gas", "workshop", "trade", "visit", "church", "gas", "public", "trade" } },
		{ from = 17 * 60 + 30, key = "work", visible = true },
		{ from = 18 * 60 + 30, key = "evening", visible = true, place = { "home", "relax", "walk", "home", "visit", "walk" } },
		{ from = 21 * 60 + 30, key = "sleep", visible = false },
	},
	mayor = {
		{ from = 7 * 60, key = "morning", visible = true },
		{ from = 8 * 60, key = "office", visible = true, place = "townhall" },
		{ from = 12 * 60, key = "lunch", visible = true, place = { "public", "shop" } },
		{ from = 13 * 60, key = "office", visible = true, place = "townhall" },
		{ from = 15 * 60 + 30, key = "town", visible = true, place = { "public", "visit", "shop", "church", "walk", "visit" } },
		{ from = 18 * 60 + 30, key = "evening", visible = true, place = { "home", "relax", "walk" } },
		{ from = 22 * 60, key = "sleep", visible = false },
	},
	trader = {
		{ from = 6 * 60 + 30, key = "morning", visible = true },
		{ from = 8 * 60, key = "trading", visible = true, place = "trade" },
		{ from = 12 * 60, key = "lunch", visible = true, place = { "shop", "public" } },
		{ from = 13 * 60, key = "trading", visible = true, place = "trade" },
		{ from = 16 * 60 + 30, key = "errands", visible = true, place = { "visit", "shop", "public", "relax", "visit" } },
		{ from = 18 * 60, key = "evening", visible = true, place = { "home", "relax" } },
		{ from = 22 * 60, key = "sleep", visible = false },
	},
	dealer = {
		{ from = 6 * 60 + 30, key = "morning", visible = true },
		{ from = 7 * 60 + 30, key = "workshop", visible = true, place = "workshop" },
		{ from = 12 * 60, key = "lunch", visible = true, place = { "gas", "shop" } },
		{ from = 12 * 60 + 45, key = "workshop", visible = true, place = "workshop" },
		{ from = 16 * 60, key = "errands", visible = true, place = { "visit", "workshop", "gas", "visit", "shop" } },
		{ from = 18 * 60, key = "evening", visible = true, place = { "home", "relax", "walk" } },
		{ from = 22 * 60 + 30, key = "sleep", visible = false },
	},
}

--- Personal shift of the day plan (minutes), the same every day: every neighbour gets up a bit differently.
local function shift(nid)
	return ((tonumber(nid) or 1) * 17) % 41 - 20
end

--- Plan of one neighbour: list of { from, to, key, visible }, sorted, covering the whole day.
function PL.get(nid)
	local n = GN.getNeighbour(nid)
	if n == nil then
		return {}
	end
	local tpl = PL.TEMPLATES[n.role] or PL.TEMPLATES.farmer
	local s = shift(nid)
	local out = {}
	for i, e in ipairs(tpl) do
		local nextFrom = tpl[i + 1] ~= nil and tpl[i + 1].from or (tpl[1].from + 24 * 60)
		local place = e.place
		if type(place) == "table" then
			place = place[((GN.getDay() * 3 + (tonumber(nid) or 0) * 5 + i) % #place) + 1]
		end
		if place == "home" then
			place = nil
		end
		table.insert(out, { from = (e.from + s) % (24 * 60), to = (nextFrom + s) % (24 * 60), key = e.key, visible = e.visible, place = place })
	end
	return out
end

--- What the neighbour is doing at a time of day (minutes); default: now.
function PL.current(nid, minute)
	minute = minute or GN.getDayMinutes()
	local plan = PL.get(nid)
	for _, e in ipairs(plan) do
		if e.from <= e.to then
			if minute >= e.from and minute < e.to then
				return e
			end
		elseif minute >= e.from or minute < e.to then
			return e -- runs over midnight
		end
	end
	return plan[#plan]
end

--- Where the neighbour is now: x, z (a place of the right type, else nil = at home).
--- Players' farm yards the neighbours visit: farmhouses (else any building) of player farms, same order everywhere.
function PL.visitTargets()
	local out = {}
	local ps = g_currentMission ~= nil and g_currentMission.placeableSystem ~= nil and g_currentMission.placeableSystem.placeables or {}
	local byFarm = {}
	for _, p in ipairs(ps) do
		local farmId = p.getOwnerFarmId ~= nil and p:getOwnerFarmId() or 0
		if GN.isPlayerFarm(farmId) and p.rootNode ~= nil and entityExists(p.rootNode) and p.spec_gnTool == nil then
			local isHouse = p.spec_farmhouse ~= nil
			local cur = byFarm[farmId]
			if cur == nil or (isHouse and not cur.house) then
				local x, _, z = getWorldTranslation(p.rootNode)
				byFarm[farmId] = { farmId = farmId, x = x, z = z, house = isHouse }
			end
		end
	end
	-- a farm that set "my farm" in the construction menu is visited there
	local places = g_server ~= nil and GN.Server.places or (GN.Client.places or {})
	for _, p in ipairs(places) do
		if p.type == "myfarm" and p.farmId ~= nil and GN.isPlayerFarm(p.farmId) then
			byFarm[p.farmId] = { farmId = p.farmId, x = p.x, z = p.z, house = true, set = true }
		end
	end
	for _, e in pairs(byFarm) do
		table.insert(out, e)
	end
	table.sort(out, function(a, b) return a.farmId < b.farmId end)
	return out
end

--- The farm yard the neighbour visits today (or nil).
function PL.visitTarget(nid)
	local t = PL.visitTargets()
	if #t == 0 then
		return nil
	end
	return t[((GN.getDay() + (tonumber(nid) or 0)) % #t) + 1]
end

function PL.position(nid, places)
	local cur = PL.current(nid)
	if cur == nil or cur.place == nil then
		return nil
	end
	if cur.place == "visit" then
		local v = PL.visitTarget(nid)
		if v == nil then
			return nil
		end
		-- in front of the house, next to each other when several come
		local a = (tonumber(nid) or 0) * 0.9
		return v.x + 12 + math.cos(a) * 3, v.z + 4 + math.sin(a) * 3
	end
	local list = {}
	for _, p in ipairs(places or {}) do
		if p.type == cur.place then
			table.insert(list, p)
		end
	end
	if #list == 0 then
		return nil
	end
	local p = list[((GN.getDay() + (tonumber(nid) or 0)) % #list) + 1]
	-- several neighbours at one place stand around it, not in one spot
	local a = (tonumber(nid) or 0) * 1.3
	return p.x + math.cos(a) * 2.5, p.z + math.sin(a) * 2.5
end

--- Text for the contact card.
function PL.format(nid)
	local cur = PL.current(nid)
	local lines = {}
	for _, e in ipairs(PL.get(nid)) do
		local mark = (cur ~= nil and cur.from == e.from) and "> " or "   "
		local where = ""
		if e.place ~= nil then
			where = " (" .. GN.text("gn_place_" .. e.place, e.place) .. ")"
		end
		table.insert(lines, mark .. GN.formatClock(e.from) .. "  " .. GN.text("gn_plan_" .. e.key, e.key) .. where)
	end
	return table.concat(lines, "\n")
end
