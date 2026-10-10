-- Good Neighbours (FS25) - the neighbours in the game world:
--   * NPC entries in the game's NPC list, so fields show "Owned by: <neighbour>" and contracts show who gives them
--   * owner / lent state of the neighbours' machines (vehicle specialization GNVehicle + one event)
--   * access for a farm to a machine lent to it
-- Author: billiD

local GN = GoodNeighbours

GN.World = GN.World or {}
local WO = GN.World

-- ---------------------------------------------------------------------------
-- Vehicle specialization (registered at mod load, added to all vehicle types)
-- ---------------------------------------------------------------------------

WO.SPEC_NAME = string.format("%s.gnVehicle", tostring(g_currentModName))

function WO.registerSpecialization()
	if g_specializationManager == nil then
		return
	end
	if g_specializationManager:getSpecializationObjectByName(WO.SPEC_NAME) == nil then
		g_specializationManager:addSpecialization("gnVehicle", "GNVehicle", Utils.getFilename("scripts/GNVehicle.lua", GN.dir), nil)
	end
	if WO._typesHooked or TypeManager == nil or TypeManager.validateTypes == nil then
		return
	end
	WO._typesHooked = true
	TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, function(typeManager)
		if typeManager.typeName ~= "vehicle" then
			return
		end
		local spec = g_specializationManager:getSpecializationObjectByName(WO.SPEC_NAME)
		if spec == nil then
			return
		end
		for typeName, typeEntry in pairs(typeManager:getTypes()) do
			if spec.prerequisitesPresent(typeEntry.specializations) then
				typeManager:addSpecialization(typeName, WO.SPEC_NAME)
			end
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Gates: a farm working a contract of a neighbour may open the gates of his yard
-- ---------------------------------------------------------------------------

WO.GATE_RADIUS = 150

local function isGate(object)
	if type(object) ~= "table" or AnimatedObject == nil then
		return false
	end
	local ok, res = GN.try(function()
		return object.isa ~= nil and object:isa(AnimatedObject)
	end)
	return ok and res == true
end

--- Neighbours with a running contract of this farm (server and clients know the missions and the field owners).
function WO.contractNeighbours(farmId)
	local now = g_time or 0
	WO._gateCache = WO._gateCache or {}
	local c = WO._gateCache[farmId]
	if c ~= nil and now - c.at < 2000 then
		return c.set
	end
	local set = {}
	local assign = g_server ~= nil and GN.Server.assign or (GN.Client.assign or {})
	for _, m in ipairs(g_missionManager ~= nil and g_missionManager.missions or {}) do
		local running = MissionStatus == nil or m.status == MissionStatus.RUNNING or m.status == MissionStatus.PREPARING
		if m.farmId == farmId and running and m.field ~= nil and m.field.farmland ~= nil then
			local nid = assign[m.field.farmland.id]
			if nid ~= nil then
				set[nid] = true
			end
		end
	end
	WO._gateCache[farmId] = { at = now, set = set }
	return set
end

local function yardPoints(nid)
	local pts = {}
	if g_server ~= nil then
		if GN.Server.home[nid] ~= nil then
			table.insert(pts, GN.Server.home[nid])
		end
		for _, p in ipairs(GN.Server.slots[nid] or {}) do
			table.insert(pts, p)
		end
	else
		for _, h in ipairs(GN.Client.homes or {}) do
			if h.nid == nid then
				table.insert(pts, h)
			end
		end
		for _, p in ipairs(GN.Client.slots or {}) do
			if p.nid == nid then
				table.insert(pts, p)
			end
		end
	end
	return pts
end

function WO.gateAllowed(farmId, object)
	if farmId == nil or farmId == 0 or not isGate(object) then
		return false
	end
	local nids = WO.contractNeighbours(farmId)
	if next(nids) == nil then
		return false
	end
	local node = object.nodeId or object.rootNode
	if node == nil or not entityExists(node) then
		return false
	end
	local x, _, z = getWorldTranslation(node)
	for nid in pairs(nids) do
		for _, p in ipairs(yardPoints(nid)) do
			if (p.x - x) ^ 2 + (p.z - z) ^ 2 < WO.GATE_RADIUS ^ 2 then
				return true
			end
		end
	end
	return false
end

function WO.installAccessHook()
	if WO._accessHooked or AccessHandler == nil or AccessHandler.canFarmAccess == nil then
		return
	end
	WO._accessHooked = true
	AccessHandler.canFarmAccess = Utils.overwrittenFunction(AccessHandler.canFarmAccess, function(handler, superFunc, farmId, object, ...)
		if object ~= nil and type(object) == "table" and object.gnBorrowFarm ~= nil and object.gnBorrowFarm == farmId then
			return true
		end
		local res = superFunc(handler, farmId, object, ...)
		if not res then
			local ok, allowed = GN.try(WO.gateAllowed, farmId, object)
			if ok and allowed then
				return true
			end
		end
		return res
	end)
end

-- ---------------------------------------------------------------------------
-- Vehicle state event (server -> clients)
-- ---------------------------------------------------------------------------

GNVehicleStateEvent = {}
local GNVehicleStateEvent_mt = Class(GNVehicleStateEvent, Event)
InitEventClass(GNVehicleStateEvent, "GNVehicleStateEvent")

function GNVehicleStateEvent.emptyNew()
	return Event.new(GNVehicleStateEvent_mt)
end
function GNVehicleStateEvent.new(vehicle)
	local self = GNVehicleStateEvent.emptyNew()
	self.vehicle = vehicle
	self.nid = vehicle.gnNid or 0
	self.borrowFarm = vehicle.gnBorrowFarm or 0
	return self
end
function GNVehicleStateEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteUInt8(streamId, math.max(0, math.min(255, self.nid)))
	streamWriteUInt8(streamId, math.max(0, math.min(255, self.borrowFarm)))
end
function GNVehicleStateEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.nid = streamReadUInt8(streamId)
	self.borrowFarm = streamReadUInt8(streamId)
	self:run(connection)
end
function GNVehicleStateEvent:run(connection)
	if self.vehicle ~= nil and connection ~= nil and connection:getIsServer() then
		self.vehicle.gnNid = self.nid > 0 and self.nid or nil
		self.vehicle.gnBorrowFarm = self.borrowFarm > 0 and self.borrowFarm or nil
	end
end

--- Server: set owner neighbour / lent farm of a machine and tell every player.
function WO.setVehicleState(vehicle, nid, borrowFarm)
	if vehicle == nil or vehicle.isDeleted then
		return
	end
	vehicle.gnNid = nid
	vehicle.gnBorrowFarm = borrowFarm
	for _, p in ipairs(GN.getPlayers()) do
		if p.connection ~= nil and p.connection.gnReady == true and not (p == g_localPlayer and GN.hasUI()) then
			p.connection:sendEvent(GNVehicleStateEvent.new(vehicle))
		end
	end
end

-- ---------------------------------------------------------------------------
-- NPC entries: "Owned by" on fields and the contract giver
-- ---------------------------------------------------------------------------

function WO.registerNpcs()
	if WO._npcsRegistered or g_npcManager == nil or g_npcManager.npcs == nil or NPC == nil then
		return
	end
	WO._npcsRegistered = true
	local last = 0
	for i in pairs(g_npcManager.npcs) do
		if type(i) == "number" and i > last then
			last = i
		end
	end
	local count = 0
	for _, n in ipairs(GN.neighbours) do
		if n.contracts then
			local index = last + count + 1
			local key = "GOODNEIGHBOURS_" .. tostring(n.id)
			local ok, npc = GN.try(function()
				local obj = NPC.new()
				obj:load("dataS2/npc/farmer/farmer.xml", key, n.name)
				obj.index = index
				obj.name = key
				obj.title = n.name
				obj.imageFilename = Utils.getFilename("images/portraits/" .. n.portrait .. ".dds", GN.dir)
				return obj
			end)
			if ok and npc ~= nil then
				g_npcManager.npcs[index] = npc
				if g_npcManager.nameToNPC ~= nil then
					g_npcManager.nameToNPC[key] = npc
				end
				n.npcIndex = index
				count = count + 1
			else
				GN.log("could not add %s to the game's NPC list: %s", n.name, tostring(npc))
			end
		end
	end
	GN.log("%d neighbours added to the game's NPC list", count)
end

--- Fields of a neighbour show him as the owner (farmland.npcIndex).
function WO.applyFarmlandNpcs(assign)
	if g_farmlandManager == nil then
		return
	end
	local count = 0
	for flId, nid in pairs(assign or {}) do
		local n = GN.getNeighbour(nid)
		local fl = g_farmlandManager:getFarmlandById(tonumber(flId))
		if n ~= nil and n.npcIndex ~= nil and fl ~= nil then
			if fl.gnOrigNpcIndex == nil then
				fl.gnOrigNpcIndex = fl.npcIndex
			end
			fl.npcIndex = n.npcIndex
			count = count + 1
		end
	end
	return count
end

-- ---------------------------------------------------------------------------
-- The neighbours' farm stays invisible for the players (multiplayer clients):
-- not in the farm list, and a field they work shows no owner on the map
-- ---------------------------------------------------------------------------

local function isPureClient()
	return g_server == nil and g_client ~= nil
end

local function npcFarm(farmId)
	return farmId ~= nil and GN.Work ~= nil and farmId == GN.Work.NPC_FARM_ID
end

function WO.installClientMasks()
	if WO._masks then
		return
	end
	WO._masks = true
	if FarmManager ~= nil and type(FarmManager.getFarms) == "function" then
		local orig = FarmManager.getFarms
		FarmManager.getFarms = function(self, ...)
			local farms = orig(self, ...)
			if not isPureClient() or type(farms) ~= "table" then
				return farms
			end
			local out, hidden = {}, false
			for _, f in ipairs(farms) do
				if f ~= nil and npcFarm(f.farmId) then
					hidden = true
				else
					table.insert(out, f)
				end
			end
			return hidden and out or farms
		end
	end
	if FarmlandManager ~= nil and FarmlandManager.setLandOwnership ~= nil then
		local orig = FarmlandManager.setLandOwnership
		FarmlandManager.setLandOwnership = function(self, farmlandId, farmId, ...)
			if isPureClient() and npcFarm(farmId) then
				farmId = FarmlandManager.NO_OWNER_FARM_ID or 0
			end
			return orig(self, farmlandId, farmId, ...)
		end
	end
	if Farmland ~= nil and Farmland.setOwnerFarmId ~= nil then
		local orig = Farmland.setOwnerFarmId
		Farmland.setOwnerFarmId = function(self, farmId, ...)
			if isPureClient() and npcFarm(farmId) then
				farmId = FarmlandManager ~= nil and FarmlandManager.NO_OWNER_FARM_ID or 0
			end
			return orig(self, farmId, ...)
		end
	end
end

WO.installClientMasks()
