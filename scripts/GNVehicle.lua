-- Good Neighbours (FS25) - vehicle specialization for the neighbours' machines
--   * info box: "Owned by: <neighbour>"
--   * neighbours' machines cannot be sold, and have no map icon (unless lent to a player)
--   * a machine lent to a player farm can be used and attached by that farm
-- State per vehicle: gnNid (owner neighbour id, 0 = none), gnBorrowFarm (farm id it is lent to, 0 = none).
-- Loaded through g_specializationManager:addSpecialization (see GNMain.lua).
-- Author: billiD

GNVehicle = {}

GNVehicle.MOD_NAME = g_currentModName

function GNVehicle.prerequisitesPresent(specializations)
	if Locomotive ~= nil and SpecializationUtil.hasSpecialization(Locomotive, specializations) then
		return false
	end
	if SpecializationUtil.hasSpecialization(Attachable, specializations) then
		return true
	end
	return SpecializationUtil.hasSpecialization(Enterable, specializations)
		and SpecializationUtil.hasSpecialization(Motorized, specializations)
end

function GNVehicle.initSpecialization()
end

function GNVehicle.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", GNVehicle)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", GNVehicle)
end

function GNVehicle.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "showInfo", GNVehicle.showInfo)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeSold", GNVehicle.getCanBeSold)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsMapHotspotVisible", GNVehicle.getIsMapHotspotVisible)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "isAttachAllowed", GNVehicle.isAttachAllowed)
	-- the neighbours' implements really work the land they hold while working (spraying, sowing, harvesting)
	if vehicleType.functions ~= nil and vehicleType.functions.getIsAccessibleAtWorldPosition ~= nil then
		SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsAccessibleAtWorldPosition", GNVehicle.getIsAccessibleAtWorldPosition)
	end
end

function GNVehicle:getIsAccessibleAtWorldPosition(superFunc, farmId, x, z, ...)
	local r1, r2, r3 = superFunc(self, farmId, x, z, ...)
	if r1 then
		return r1, r2, r3
	end
	local GN = GoodNeighbours
	if self.gnBorrowFarm == nil and GN ~= nil and GN.Work ~= nil and GN.Work.mayWorkAt ~= nil then
		local ok, may = GoodNeighbours.try(GN.Work.mayWorkAt, self, farmId, x, z)
		if ok and may then
			return true
		end
	end
	return r1, r2, r3
end

-- joining players get the state with the vehicle itself
function GNVehicle:onWriteStream(streamId, connection)
	streamWriteUInt8(streamId, math.max(0, math.min(255, tonumber(self.gnNid) or 0)))
	streamWriteUInt8(streamId, math.max(0, math.min(255, tonumber(self.gnBorrowFarm) or 0)))
end

function GNVehicle:onReadStream(streamId, connection)
	local nid = streamReadUInt8(streamId)
	local farm = streamReadUInt8(streamId)
	self.gnNid = nid > 0 and nid or nil
	self.gnBorrowFarm = farm > 0 and farm or nil
end

local function ownerName(vehicle)
	if vehicle.gnNid == nil or GoodNeighbours == nil or GoodNeighbours.getNeighbour == nil then
		return nil
	end
	local n = GoodNeighbours.getNeighbour(vehicle.gnNid)
	return n ~= nil and n.name or nil
end

function GNVehicle:showInfo(superFunc, box, ...)
	local name = ownerName(self)
	if name == nil or box == nil or box.addLine == nil then
		return superFunc(self, box, ...)
	end
	local label = "Owner"
	if g_i18n ~= nil and g_i18n:hasText("fieldInfo_ownedBy") then
		label = g_i18n:getText("fieldInfo_ownedBy")
	end
	-- the game may add its own owner line (the neighbours' farm): show the neighbour's name in it instead
	local replaced = false
	local orig = box.addLine
	local hadField = rawget(box, "addLine") ~= nil
	box.addLine = function(b, key, value, ...)
		if not replaced and key == label then
			replaced = true
			return orig(b, key, name, ...)
		end
		return orig(b, key, value, ...)
	end
	local ok, err = GoodNeighbours.try(superFunc, self, box, ...)
	if hadField then
		box.addLine = orig
	else
		box.addLine = nil
	end
	if not ok then
		print("[GoodNeighbours] showInfo error: " .. tostring(err))
	end
	if not replaced then
		box:addLine(label, name)
	end
	if self.gnBorrowFarm ~= nil and GoodNeighbours ~= nil then
		box:addLine(GoodNeighbours.text("gn_info_lent", "Lent to you"), GoodNeighbours.text("gn_info_lent_value", "until the contract ends"))
	end
end

function GNVehicle:getCanBeSold(superFunc, ...)
	if self.gnNid ~= nil then
		return false
	end
	return superFunc(self, ...)
end

function GNVehicle:getIsMapHotspotVisible(superFunc, ...)
	if self.gnNid ~= nil and self.gnBorrowFarm == nil then
		return false
	end
	return superFunc(self, ...)
end

function GNVehicle:isAttachAllowed(superFunc, farmId, attacherVehicle, ...)
	if self.gnBorrowFarm ~= nil and self.gnBorrowFarm == farmId then
		return true, nil
	end
	return superFunc(self, farmId, attacherVehicle, ...)
end
