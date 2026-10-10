-- Good Neighbours (FS25) - construction menu tools: "home of <neighbour>" / "machine parking of <neighbour>"
-- The tool is placed like any building; the server takes its position, applies it and removes the tool again.
-- Author: billiD

PlaceableGNTool = {}
PlaceableGNTool.MOD_NAME = g_currentModName

function PlaceableGNTool.prerequisitesPresent(specializations)
	return true
end

function PlaceableGNTool.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("GNTool")
	schema:register(XMLValueType.STRING, basePath .. ".gnTool#action", "home, parking, slot, place_<type> or remove")
	schema:register(XMLValueType.INT, basePath .. ".gnTool#neighbour", "neighbour id")
	schema:setXMLSpecializationType()
end

function PlaceableGNTool.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableGNTool)
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", PlaceableGNTool)
end

function PlaceableGNTool.registerOverwrittenFunctions(placeableType)
	-- can be placed anywhere (also on fields and land of others), never buys land
	SpecializationUtil.registerOverwrittenFunction(placeableType, "getIsOnOwnedFarmland", PlaceableGNTool.getIsOnOwnedFarmland)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "getIsOnFarmland", PlaceableGNTool.getIsOnFarmland)
end

function PlaceableGNTool:getIsOnOwnedFarmland(superFunc, ...)
	return true
end

function PlaceableGNTool:getIsOnFarmland(superFunc, ...)
	return false
end

function PlaceableGNTool:onLoad(savegame)
	local spec = {}
	self.spec_gnTool = spec
	spec.action = self.xmlFile:getValue("placeable.gnTool#action")
	spec.nid = self.xmlFile:getValue("placeable.gnTool#neighbour")
end

function PlaceableGNTool:onFinalizePlacement()
	local spec = self.spec_gnTool
	if spec == nil or not self.isServer or GoodNeighbours == nil or GoodNeighbours.Server == nil then
		return
	end
	local x, _, z = getWorldTranslation(self.rootNode)
	-- heading from the direction the tool faces (getWorldRotation flips the angle beyond 90 degrees)
	local dx, _, dz = localDirectionToWorld(self.rootNode, 0, 0, 1)
	local ry = math.atan2 ~= nil and math.atan2(dx, dz) or math.atan(dx, dz)
	GoodNeighbours.safeCall("construction tool", GoodNeighbours.Server.onTool, spec.action, spec.nid, x, z, ry, self)
end
