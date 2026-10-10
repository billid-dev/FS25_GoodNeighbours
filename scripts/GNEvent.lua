-- Good Neighbours (FS25) - one network event for every message (kind + encoded table)
-- Author: billiD

local GN = GoodNeighbours

GNEvent = {}
local GNEvent_mt = Class(GNEvent, Event)
InitEventClass(GNEvent, "GNEvent")

function GNEvent.emptyNew()
	return Event.new(GNEvent_mt)
end

function GNEvent.new(kind, data)
	local self = GNEvent.emptyNew()
	self.kind = tostring(kind or "")
	self.payload = GN.encode(data or {})
	return self
end

function GNEvent:writeStream(streamId, connection)
	streamWriteString(streamId, self.kind)
	streamWriteString(streamId, self.payload)
end

function GNEvent:readStream(streamId, connection)
	self.kind = streamReadString(streamId)
	self.payload = streamReadString(streamId)
	self:run(connection)
end

function GNEvent:run(connection)
	local data = GN.decode(self.payload) or {}
	if connection ~= nil and connection:getIsServer() then
		-- we are a client, message from the server
		GN.safeCall("client message " .. self.kind, GN.Client.onMessage, self.kind, data)
	else
		-- we are the server, message from a client
		GN.safeCall("server message " .. self.kind, GN.Server.onMessage, self.kind, data, connection)
	end
end

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------

--- Client -> server (singleplayer / host: handled directly).
function GN.sendToServer(kind, data)
	if g_server ~= nil then
		GN.safeCall("server message " .. tostring(kind), GN.Server.onMessage, kind, data or {}, GN.LOCAL)
		return
	end
	if g_client ~= nil and g_client.getServerConnection ~= nil then
		g_client:getServerConnection():sendEvent(GNEvent.new(kind, data))
	end
end

--- Server -> one client connection (GN.LOCAL: handled directly).
function GN.sendToConnection(connection, kind, data)
	if connection == nil then
		return
	end
	if connection == GN.LOCAL then
		GN.safeCall("client message " .. tostring(kind), GN.Client.onMessage, kind, data or {})
		return
	end
	if connection.gnReady ~= true then
		return -- still loading; it asks for a full sync when it is in the game
	end
	connection:sendEvent(GNEvent.new(kind, data))
end

function GN.sendToFarm(farmId, kind, data)
	for _, c in ipairs(GN.getFarmConnections(farmId)) do
		GN.sendToConnection(c, kind, data)
	end
end

function GN.sendToAll(kind, data)
	local seen = {}
	for _, p in ipairs(GN.getPlayers()) do
		local c
		if p == g_localPlayer and GN.hasUI() then
			c = GN.LOCAL
		else
			c = p.connection
		end
		if c ~= nil and not seen[c] then
			seen[c] = true
			GN.sendToConnection(c, kind, data)
		end
	end
end
