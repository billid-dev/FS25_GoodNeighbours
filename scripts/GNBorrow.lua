-- Good Neighbours (FS25) - lent machines and the neighbour's supplies
--
-- Lending (server):
--   stage "pickup" : the machine waits on the neighbour's parking place
--   stage "field"  : the player has hitched it - now work the contract fields
--   stage "return" : all contracts are over - bring the machine back to its parking place and unhitch it there
--   done           : the neighbour thanks you (a few relationship points); not brought back within a day -> he
--                    fetches it himself and is a bit annoyed
-- Navigation (client): the current stage is a blinking green circle on the map (and the GPS target), the next
-- stage a red circle.
-- Supplies (server): a farm with a running contract of a neighbour fills seeds / fertilizer / herbicide / lime for
-- free at that neighbour's yard (around his home and machine parking).
-- Author: billiD

local GN = GoodNeighbours

GN.Borrow = GN.Borrow or {}
local B = GN.Borrow

B.RETURN_RADIUS = 12
B.SUPPLY_RADIUS = 30
B.RETURN_POINTS = 20
B.LATE_POINTS = -40

-- fill types a contract needs, by job
B.JOB_FILL = {
	sow = { "SEEDS" },
	fertilize = { "FERTILIZER", "LIQUIDFERTILIZER" },
	spray = { "HERBICIDE" },
	lime = { "LIME" },
}

function B.reset()
	B.sessions = {}   -- key "farm|nid" -> session
	B.timer = 0
	B.supplyTimer = 0
	B.supplyNotified = {}
end

local function key(farmId, nid)
	return tostring(farmId) .. "|" .. tostring(nid)
end

local function dist2(x1, z1, x2, z2)
	return (x1 - x2) ^ 2 + (z1 - z2) ^ 2
end

local function fieldCenter(field)
	if field == nil then
		return nil
	end
	if field.getCenterOfFieldWorldPosition ~= nil then
		local ok, x, z = GN.try(field.getCenterOfFieldWorldPosition, field)
		if ok and x ~= nil then
			return x, z
		end
	end
	return field.posX, field.posZ
end

-- ---------------------------------------------------------------------------
-- Server: sessions
-- ---------------------------------------------------------------------------

function B.start(nid, tool, farmId, missions, job)
	local x, _, z, ry = GN.Work.toolParkPose(nid, tool)
	if x == nil and tool ~= nil and tool.rootNode ~= nil then
		x, _, z = getWorldTranslation(tool.rootNode)
		ry = 0
	end
	local fields = {}
	for _, m in ipairs(missions or {}) do
		local fx, fz = fieldCenter(m.field)
		if fx ~= nil then
			local r = 40
			if m.field ~= nil and m.field.getAreaHa ~= nil then
				local ok, ha = GN.try(m.field.getAreaHa, m.field)
				if ok and ha ~= nil and ha > 0 then
					r = math.max(20, math.min(120, math.sqrt(ha * 10000) * 0.55))
				end
			end
			table.insert(fields, { x = fx, z = fz, r = r })
		end
	end
	local s = { nid = nid, farmId = farmId, tool = tool, stage = "pickup", fields = fields, job = job,
		ret = { x = x, z = z, ry = ry }, returnDay = nil }
	B.sessions[key(farmId, nid)] = s
	B.sendStage(s)
	return s
end

function B.sendStage(s)
	GN.sendToFarm(s.farmId, "borrowStage", {
		nid = s.nid, stage = s.stage, fields = s.fields, ret = s.ret, job = s.job,
		vehicle = GN.Work.vehicleName(s.tool),
	})
end

--- Client asked for its sessions (joined / reloaded).
function B.sendAllTo(connection, farmId)
	for _, s in pairs(B.sessions) do
		if s.farmId == farmId then
			GN.sendToConnection(connection, "borrowStage", {
				nid = s.nid, stage = s.stage, fields = s.fields, ret = s.ret, job = s.job,
				vehicle = GN.Work.vehicleName(s.tool),
			})
		end
	end
end

--- All contracts with the lent machine are over: now it has to be brought back.
function B.onContractsDone(nid, farmId)
	local s = B.sessions[key(farmId, nid)]
	if s == nil then
		GN.Work.returnLent(nid, farmId)
		return
	end
	s.stage = "return"
	s.returnDay = GN.getDay()
	s.fields = {}
	B.sendStage(s)
	GN.log("borrow: farm %d has to bring %s back to %s", farmId, GN.Work.vehicleName(s.tool), GN.getNeighbour(nid).name)
end

function B.finish(s, late)
	B.sessions[key(s.farmId, s.nid)] = nil
	GN.Work.returnLent(s.nid, s.farmId)
	-- now the finished contracts count (paid by the game, the neighbour's bonus)
	GN.safeCall("contracts count", GN.Server.releaseAwaiting, s.nid, s.farmId)
	GN.sendToFarm(s.farmId, "borrowStage", { nid = s.nid, stage = "done" })
	if late then
		GN.Server.addPoints(s.farmId, s.nid, B.LATE_POINTS)
		GN.sendToFarm(s.farmId, "borrowLate", { nid = s.nid })
	else
		GN.Server.addPoints(s.farmId, s.nid, B.RETURN_POINTS)
		GN.sendToFarm(s.farmId, "borrowThanks", { nid = s.nid })
	end
end

function B.update(dt)
	B.timer = B.timer + (dt or 0)
	if B.timer >= 2000 then
		B.timer = 0
		for k, s in pairs(B.sessions) do
			local tool = s.tool
			if not GN.Work.isAlive(tool) then
				B.sessions[k] = nil
			elseif s.stage == "pickup" then
				if tool.getAttacherVehicle ~= nil and tool:getAttacherVehicle() ~= nil then
					s.stage = "field"
					B.sendStage(s)
				end
			elseif s.stage == "return" then
				local attached = tool.getAttacherVehicle ~= nil and tool:getAttacherVehicle() ~= nil
				local x, _, z = getWorldTranslation(tool.rootNode)
				if not attached and dist2(x, z, s.ret.x, s.ret.z) < B.RETURN_RADIUS ^ 2 then
					GN.log("borrow: farm %d brought %s back", s.farmId, GN.Work.vehicleName(tool))
					B.finish(s, false)
				elseif s.returnDay ~= nil and GN.getDay() > s.returnDay and GN.getDayMinutes() > 8 * 60 then
					GN.log("borrow: farm %d did not bring %s back - %s fetched it", s.farmId, GN.Work.vehicleName(tool), GN.getNeighbour(s.nid).name)
					B.finish(s, true)
				end
			end
		end
	end
	B.supplyTimer = B.supplyTimer + (dt or 0)
	if B.supplyTimer >= 3000 then
		B.supplyTimer = 0
		GN.safeCall("supplies", B.updateSupplies)
	end
end

-- ---------------------------------------------------------------------------
-- Server: supplies at the neighbour's yard
-- ---------------------------------------------------------------------------

--- farm -> nid -> { fill types } of the running contracts.
local function neededSupplies()
	local out = {}
	for _, t in ipairs(GN.Server.tracked) do
		local job = t.mission ~= nil and GN.Server.missionJob(t.mission) or nil
		local fills = job ~= nil and B.JOB_FILL[job] or nil
		if fills ~= nil then
			out[t.farmId] = out[t.farmId] or {}
			out[t.farmId][t.nid] = fills
		end
	end
	return out
end

local function yardPoints(nid)
	local pts = {}
	local h = GN.Server.home[nid]
	if h ~= nil then
		table.insert(pts, h)
	end
	local p = GN.Server.parking[nid]
	if p ~= nil then
		table.insert(pts, p)
	end
	-- silo / supply places set with the construction tool
	for _, s in ipairs(GN.Server.slots[nid] or {}) do
		if s.size == "silo" then
			table.insert(pts, s)
		end
	end
	return pts
end

function B.updateSupplies()
	local need = neededSupplies()
	if next(need) == nil or g_fillTypeManager == nil then
		return
	end
	local vehicles = g_currentMission.vehicleSystem ~= nil and g_currentMission.vehicleSystem.vehicles or {}
	for _, v in pairs(vehicles) do
		local farmId = v.getOwnerFarmId ~= nil and v:getOwnerFarmId() or nil
		if v.gnBorrowFarm ~= nil then
			farmId = v.gnBorrowFarm
		end
		local byNid = farmId ~= nil and need[farmId] or nil
		if byNid ~= nil and v.getFillUnits ~= nil and v.rootNode ~= nil then
			local x, _, z = getWorldTranslation(v.rootNode)
			for nid, fills in pairs(byNid) do
				local near = false
				for _, pt in ipairs(yardPoints(nid)) do
					if dist2(x, z, pt.x, pt.z) < B.SUPPLY_RADIUS ^ 2 then
						near = true
					end
				end
				if near then
					local filled = false
					for _, ftName in ipairs(fills) do
						local ft = g_fillTypeManager:getFillTypeIndexByName(ftName)
						if ft ~= nil then
							for idx in ipairs(v:getFillUnits() or {}) do
								if v:getFillUnitSupportsFillType(idx, ft) then
									local cur = v:getFillUnitFillType(idx)
									local cap = v:getFillUnitCapacity(idx) or 0
									local level = v:getFillUnitFillLevel(idx) or 0
									if (cur == ft or level < 1) and cap - level > 1 then
										GN.try(v.addFillUnitFillLevel, v, farmId, idx, cap - level, ft, ToolType ~= nil and ToolType.UNDEFINED or nil, nil)
										filled = true
									end
								end
							end
						end
					end
					if filled then
						local k = key(farmId, nid) .. "|" .. tostring(v.id or v.rootNode)
						local now = g_time or 0
						if B.supplyNotified[k] == nil or now - B.supplyNotified[k] > 60000 then
							B.supplyNotified[k] = now
							GN.sendToFarm(farmId, "supplied", { nid = nid, vehicle = GN.Work.vehicleName(v) })
							GN.log("supplies: %s filled %s of farm %d", GN.getNeighbour(nid).name, GN.Work.vehicleName(v), farmId)
						end
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Save / load (part of goodNeighbours.xml)
-- ---------------------------------------------------------------------------

function B.saveToXML(xml)
	local i = 0
	for _, s in pairs(B.sessions) do
		if GN.Work.isAlive(s.tool) and s.tool.uniqueId ~= nil then
			local k = string.format("goodNeighbours.borrows.borrow(%d)", i)
			setXMLInt(xml, k .. "#farm", s.farmId)
			setXMLInt(xml, k .. "#neighbour", s.nid)
			setXMLString(xml, k .. "#vehicle", s.tool.uniqueId)
			setXMLString(xml, k .. "#stage", s.stage)
			setXMLString(xml, k .. "#job", s.job or "")
			setXMLFloat(xml, k .. "#retX", s.ret.x)
			setXMLFloat(xml, k .. "#retZ", s.ret.z)
			setXMLFloat(xml, k .. "#retRy", s.ret.ry or 0)
			setXMLInt(xml, k .. "#returnDay", s.returnDay or -1)
			for j, f in ipairs(s.fields) do
				local fk = string.format("%s.field(%d)", k, j - 1)
				setXMLFloat(xml, fk .. "#x", f.x)
				setXMLFloat(xml, fk .. "#z", f.z)
				setXMLFloat(xml, fk .. "#r", f.r or 40)
			end
			i = i + 1
		end
	end
end

function B.loadFromXML(xml)
	B.pending = {}
	local i = 0
	while true do
		local k = string.format("goodNeighbours.borrows.borrow(%d)", i)
		if not hasXMLProperty(xml, k) then break end
		local s = {
			farmId = getXMLInt(xml, k .. "#farm"), nid = getXMLInt(xml, k .. "#neighbour"),
			uid = getXMLString(xml, k .. "#vehicle"), stage = getXMLString(xml, k .. "#stage") or "pickup",
			job = getXMLString(xml, k .. "#job"),
			ret = { x = getXMLFloat(xml, k .. "#retX") or 0, z = getXMLFloat(xml, k .. "#retZ") or 0, ry = getXMLFloat(xml, k .. "#retRy") or 0 },
			fields = {},
		}
		local rd = getXMLInt(xml, k .. "#returnDay")
		s.returnDay = (rd ~= nil and rd >= 0) and rd or nil
		local j = 0
		while true do
			local fk = string.format("%s.field(%d)", k, j)
			if not hasXMLProperty(xml, fk) then break end
			table.insert(s.fields, { x = getXMLFloat(xml, fk .. "#x"), z = getXMLFloat(xml, fk .. "#z"), r = getXMLFloat(xml, fk .. "#r") })
			j = j + 1
		end
		table.insert(B.pending, s)
		i = i + 1
	end
end

--- After the vehicles are loaded: find the lent machines again.
function B.matchPending()
	if B.pending == nil or #B.pending == 0 then
		return
	end
	local byUid = {}
	for _, v in pairs(g_currentMission.vehicleSystem ~= nil and g_currentMission.vehicleSystem.vehicles or {}) do
		if v.uniqueId ~= nil then
			byUid[v.uniqueId] = v
		end
	end
	for _, s in ipairs(B.pending) do
		local tool = byUid[s.uid]
		if tool ~= nil then
			s.tool = tool
			s.uid = nil
			B.sessions[key(s.farmId, s.nid)] = s
		end
	end
	B.pending = nil
end

-- ---------------------------------------------------------------------------
-- Client: navigation circles on the map
-- ---------------------------------------------------------------------------

GNCircleHotspot = {}
local GNCircleHotspot_mt = Class(GNCircleHotspot, MapHotspot)

GNCircleHotspot.GREEN = { 0.1, 0.85, 0.2, 1 }
GNCircleHotspot.RED = { 0.85, 0.05, 0.05, 1 }

function GNCircleHotspot.new(x, z, radius, color, blink)
	local self = MapHotspot.new(GNCircleHotspot_mt)
	local w, h = getNormalizedScreenValues(46, 46)
	self.width, self.height = w, h
	self.circle = g_overlayManager:createOverlay("mapHotspots.circle", 0, 0, w, h)
	self.color = color
	self.blink = blink
	self.worldRadius = radius or 40
	self.forceNoRotation = true
	self:setWorldPosition(x, z)
	return self
end

function GNCircleHotspot:delete()
	if self.circle ~= nil then
		self.circle:delete()
		self.circle = nil
	end
	GNCircleHotspot:superClass().delete(self)
end

function GNCircleHotspot:getCategory()
	return MapHotspot.CATEGORY_MISSION or MapHotspot.CATEGORY_OTHER or 1
end

function GNCircleHotspot:getIsPersistent()
	return true
end

function GNCircleHotspot:getRenderLast()
	return true
end

function GNCircleHotspot:getWidth()
	return self.width or 0
end

function GNCircleHotspot:getHeight()
	return self.height or 0
end

function GNCircleHotspot:getDimension()
	return self.width or 0, self.height or 0
end

function GNCircleHotspot:setScale(scale)
end

function GNCircleHotspot:render(x, y, rotation, small)
	local c = self.circle
	if c == nil then
		return
	end
	-- size follows the zoom of the map (a circle of worldRadius metres)
	local map = g_currentMission ~= nil and g_currentMission.hud ~= nil and g_currentMission.hud.getIngameMap ~= nil and g_currentMission.hud:getIngameMap() or nil
	if map ~= nil and map.layout ~= nil and map.worldSizeX ~= nil then
		local mw, mh = map.layout:getMapSize()
		local w = math.max(self.width * 0.6, self.worldRadius / map.worldSizeX * mw)
		local h = math.max(self.height * 0.6, self.worldRadius / map.worldSizeZ * mh)
		c:setDimension(w, h)
	end
	local alpha = 1
	if self.blink then
		alpha = 0.35 + 0.65 * math.abs(math.sin((g_time or 0) / 400))
	end
	c:setColor(self.color[1], self.color[2], self.color[3], alpha)
	c:setPosition(x, y)
	c:render()
end

B.clientSessions = B.clientSessions or {}
B.hotspots = B.hotspots or {}

function B.clientOnStage(data)
	local nid = tonumber(data.nid)
	if data.stage == "done" then
		B.clientSessions[nid] = nil
	else
		B.clientSessions[nid] = data
	end
	B.clientRebuild()
	local n = GN.getNeighbour(nid)
	local name = n ~= nil and n.name or "?"
	if data.stage == "field" then
		GN.Client.notify(string.format(GN.text("gn_nav_field"), tostring(data.vehicle)), "ok")
	elseif data.stage == "return" then
		GN.Client.notify(string.format(GN.text("gn_nav_return"), tostring(data.vehicle), name))
	end
end

local function myLentTool(nid)
	local farmId = GN.getLocalFarmId()
	for _, v in pairs(g_currentMission.vehicleSystem ~= nil and g_currentMission.vehicleSystem.vehicles or {}) do
		if v.gnNid == nid and v.gnBorrowFarm == farmId and v.rootNode ~= nil then
			return v
		end
	end
	return nil
end

function B.clientClear()
	for _, h in ipairs(B.hotspots) do
		if g_currentMission ~= nil and g_currentMission.removeMapHotspot ~= nil then
			GN.try(g_currentMission.removeMapHotspot, g_currentMission, h.hotspot)
		end
		GN.try(h.hotspot.delete, h.hotspot)
	end
	B.hotspots = {}
end

local function addSpot(x, z, current, radius, follow)
	if x == nil or z == nil or MapHotspot == nil then
		return nil
	end
	local ok, h = GN.try(GNCircleHotspot.new, x, z, radius, current and GNCircleHotspot.GREEN or GNCircleHotspot.RED, current)
	if not ok or h == nil then
		return nil
	end
	g_currentMission:addMapHotspot(h)
	table.insert(B.hotspots, { hotspot = h, follow = follow })
	return h
end

--- Circles for every lent machine: current stage green (blinking, GPS target), next stage red.
function B.clientRebuild()
	if not GN.hasUI() or g_currentMission == nil then
		return
	end
	B.clientClear()
	local target = nil
	for nid, s in pairs(B.clientSessions) do
		local fieldSpots = function(current)
			for _, f in ipairs(s.fields or {}) do
				local h = addSpot(f.x, f.z, current, f.r or 40)
				target = target or (current and h or nil)
			end
		end
		if s.stage == "pickup" then
			local tool = myLentTool(nid)
			local x, z = s.ret.x, s.ret.z
			if tool ~= nil then
				x, _, z = getWorldTranslation(tool.rootNode)
			end
			target = target or addSpot(x, z, true, 15, nid)
			fieldSpots(false)
		elseif s.stage == "field" then
			fieldSpots(true)
			addSpot(s.ret.x, s.ret.z, false, 15)
		elseif s.stage == "return" then
			target = target or addSpot(s.ret.x, s.ret.z, true, 15)
		end
	end
	if target ~= nil and g_currentMission.setMapTargetHotspot ~= nil then
		GN.try(g_currentMission.setMapTargetHotspot, g_currentMission, target)
	end
end

--- The pickup circle follows the machine.
function B.clientUpdate(dt)
	B.followTimer = (B.followTimer or 0) + (dt or 0)
	if B.followTimer < 1000 then
		return
	end
	B.followTimer = 0
	for _, h in ipairs(B.hotspots) do
		if h.follow ~= nil then
			local tool = myLentTool(h.follow)
			if tool ~= nil then
				local x, _, z = getWorldTranslation(tool.rootNode)
				h.hotspot:setWorldPosition(x, z)
			end
		end
	end
end

B.reset()
