-- Good Neighbours (FS25) - neighbours on the map: a round photo icon where each neighbour lives
-- Author: billiD

local GN = GoodNeighbours

GNMapHotspot = {}
local GNMapHotspot_mt = Class(GNMapHotspot, MapHotspot)

GNMapHotspot.SIZE = 24        -- px on the big map (like the game's own place icons)
GNMapHotspot.SIZE_SMALL = 16  -- px on the minimap

function GNMapHotspot.new(nid, name, x, z)
	local self = MapHotspot.new(GNMapHotspot_mt)
	self.gnNid = nid
	self.gnName = name
	local w, h = getNormalizedScreenValues(GNMapHotspot.SIZE, GNMapHotspot.SIZE)
	local sw, sh = getNormalizedScreenValues(GNMapHotspot.SIZE_SMALL, GNMapHotspot.SIZE_SMALL)
	self.gnW, self.gnH, self.gnSW, self.gnSH = w, h, sw, sh
	self.width, self.height = w, h
	self.gnIcon = g_overlayManager:createOverlay("gnMapIcons.n" .. tostring(nid), 0, 0, w, h)
	self.forceNoRotation = true
	self:setWorldPosition(x, z)
	return self
end

function GNMapHotspot:delete()
	if self.gnIcon ~= nil then
		self.gnIcon:delete()
		self.gnIcon = nil
	end
	GNMapHotspot:superClass().delete(self)
end

function GNMapHotspot:getName()
	return self.gnName
end

function GNMapHotspot:getCategory()
	return MapHotspot.CATEGORY_OTHER or MapHotspot.CATEGORY_DEFAULT or 1
end

--- Not persistent: outside the minimap the icon is simply not drawn (persistent hotspots are pinned to the
--- minimap edge like a navigation target, pointing the way).
function GNMapHotspot:getIsPersistent()
	return false
end

function GNMapHotspot:getRenderLast()
	return false
end

function GNMapHotspot:getWidth()
	return self.width or 0
end

function GNMapHotspot:getHeight()
	return self.height or 0
end

function GNMapHotspot:getDimension()
	return self.width or 0, self.height or 0
end

function GNMapHotspot:setScale(scale)
end

function GNMapHotspot:render(x, y, rotation, small)
	local icon = self.gnIcon
	if icon == nil then
		return
	end
	local w, h = self.gnW, self.gnH
	if small then
		w, h = self.gnSW, self.gnSH
	end
	icon:setDimension(w, h)
	icon:setPosition(x, y)
	icon:setColor(1, 1, 1, 1) -- always fully visible (the map's blinking alpha is not used)
	icon:render()
end

-- ---------------------------------------------------------------------------
-- Keeping the icons in line with the homes sent by the server
-- ---------------------------------------------------------------------------

GN.MapIcons = GN.MapIcons or {}
local MI = GN.MapIcons
MI.hotspots = MI.hotspots or {}

function MI.registerTexture()
	if MI._registered or g_overlayManager == nil then
		return
	end
	MI._registered = true
	local path = Utils.getFilename("gui/gnMapIcons.xml", GN.dir)
	if fileExists(path) then
		g_overlayManager:addTextureConfigFile(path, "gnMapIcons")
	end
end

function MI.update(homes)
	if not GN.hasUI() or g_currentMission == nil or MapHotspot == nil then
		return
	end
	MI.registerTexture()
	local seen = {}
	for _, h in ipairs(homes or {}) do
		local nid = tonumber(h.nid)
		local n = GN.getNeighbour(nid)
		if n ~= nil and h.x ~= nil and h.z ~= nil then
			seen[nid] = true
			local hs = MI.hotspots[nid]
			if hs == nil then
				local ok, created = GN.try(GNMapHotspot.new, nid, n.name, h.x, h.z)
				if ok and created ~= nil then
					g_currentMission:addMapHotspot(created)
					MI.hotspots[nid] = created
				else
					GN.logThrottled("hotspot|" .. nid, 300, "could not create the map icon of %s: %s", n.name, tostring(created))
				end
			else
				hs:setWorldPosition(h.x, h.z)
			end
		end
	end
	for nid, hs in pairs(MI.hotspots) do
		if not seen[nid] then
			MI.remove(nid)
		end
	end
end

--- Icons show where the neighbour is right now: in his tractor while he works, otherwise at home.
function MI.updatePositions(dt)
	MI.timer = (MI.timer or 0) + (dt or 0)
	if MI.timer < 500 then
		return
	end
	MI.timer = 0
	for nid, hs in pairs(MI.hotspots) do
		local x, z
		local d = GN.Work.clientDrivers ~= nil and GN.Work.clientDrivers[nid] or nil
		local v = d ~= nil and d.vehicle or nil
		if v ~= nil and not v.isDeleted and v.rootNode ~= nil and entityExists(v.rootNode) then
			x, _, z = getWorldTranslation(v.rootNode)
		else
			local e = GN.Characters.models[nid]
			if e ~= nil and e.x ~= nil then
				x, z = e.x, e.z
			end
		end
		if x ~= nil and (hs.gnLastX == nil or math.abs(hs.gnLastX - x) > 0.5 or math.abs(hs.gnLastZ - z) > 0.5) then
			hs.gnLastX, hs.gnLastZ = x, z
			hs:setWorldPosition(x, z)
		end
	end
end

function MI.remove(nid)
	local hs = MI.hotspots[nid]
	if hs == nil then
		return
	end
	MI.hotspots[nid] = nil
	if g_currentMission ~= nil and g_currentMission.removeMapHotspot ~= nil then
		GN.try(g_currentMission.removeMapHotspot, g_currentMission, hs)
	end
	GN.try(hs.delete, hs)
end

function MI.removeAll()
	for nid in pairs(MI.hotspots) do
		MI.remove(nid)
	end
end
