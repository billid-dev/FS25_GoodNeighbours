-- Good Neighbours (FS25) - start-up, game hooks, key binding
-- Author: billiD

local GN = GoodNeighbours

GN.dir = g_currentModDirectory
GN.modName = g_currentModName
GN.version = "1.9.8.2"

GN.Main = GN.Main or {}
local M = GN.Main

-- the neighbours' machines get the GNVehicle specialization (owner name, lending); must happen at mod load
GN.World.registerSpecialization()

-- ---------------------------------------------------------------------------
-- Characters (data/neighbours.xml)
-- ---------------------------------------------------------------------------

GN.neighbours = {}
GN.neighbourById = {}

function GN.loadNeighbours()
	GN.neighbours = {}
	GN.neighbourById = {}
	local path = Utils.getFilename("data/neighbours.xml", GN.dir)
	local xml = loadXMLFile("gnNeighbours", path)
	if xml == nil or xml == 0 then
		GN.log("could not load %s", tostring(path))
		return
	end
	local i = 0
	while true do
		local k = string.format("neighbours.neighbour(%d)", i)
		if not hasXMLProperty(xml, k) then
			break
		end
		local n = {
			id = getXMLInt(xml, k .. "#id"),
			name = getXMLString(xml, k .. "#name") or "?",
			gender = getXMLString(xml, k .. "#gender") or "male",
			role = getXMLString(xml, k .. "#role") or "farmer",
			contracts = getXMLBool(xml, k .. "#contracts") == true,
			portrait = getXMLString(xml, k .. "#portrait") or "silhouette",
			lines = getXMLString(xml, k .. "#lines") or "",
			wear = {},
		}
		local j = 0
		while true do
			local wk = string.format("%s.wear(%d)", k, j)
			if not hasXMLProperty(xml, wk) then
				break
			end
			local config, match = getXMLString(xml, wk .. "#config"), getXMLString(xml, wk .. "#match")
			if config ~= nil and match ~= nil then
				table.insert(n.wear, { config = config, match = match, color = getXMLInt(xml, wk .. "#color") })
			end
			j = j + 1
		end
		if n.id ~= nil then
			table.insert(GN.neighbours, n)
			GN.neighbourById[n.id] = n
		end
		i = i + 1
	end
	delete(xml)
end

function GN.getNeighbour(id)
	return GN.neighbourById[tonumber(id) or -1]
end

-- ---------------------------------------------------------------------------
-- Key binding: open the phone (also answers a ringing call)
-- ---------------------------------------------------------------------------

M.actionEventIds = {}

function M.onPhoneAction()
	if g_gui ~= nil and g_gui:getIsGuiVisible() and not (GN.Phone.dialog ~= nil and GN.Phone.dialog.isOpen) then
		return -- another menu is open
	end
	local near = GN.Client.call == nil and GN.Characters.nearest(3) or nil
	if near ~= nil and not (GN.Phone.dialog ~= nil and GN.Phone.dialog.isOpen) then
		GN.Talk.start(near)
		return
	end
	GN.Phone.toggle()
end

--- Text of the key in the help window: answer a ringing phone / start a talk next to a neighbour / phone.
function M.updateKeyText()
	local text, prio
	if GN.Client.call ~= nil then
		text, prio = GN.text("gn_input_answer", "Answer the phone"), GS_PRIO_VERY_HIGH
	else
		local near = GN.Characters.nearest(3)
		if near ~= nil and GN.getNeighbour(near) ~= nil then
			text, prio = string.format(GN.text("gn_input_talk", "Start a conversation with %s"), GN.getNeighbour(near).name), GS_PRIO_VERY_HIGH
		else
			text, prio = GN.text("input_GN_PHONE", "Phone"), GS_PRIO_LOW
		end
	end
	local n = #M.actionEventIds
	if text == M._lastText and n == M._lastCount then
		return
	end
	M._lastText, M._lastCount = text, n
	for _, id in ipairs(M.actionEventIds) do
		GN.try(function()
			g_inputBinding:setActionEventTextVisibility(id, true)
			g_inputBinding:setActionEventText(id, text)
			g_inputBinding:setActionEventTextPriority(id, prio)
		end)
	end
end

function M.getPhoneKeyText()
	return GN.text("gn_key_hint", "Shift+N")
end

local function registerPhoneAction(target)
	if g_inputBinding == nil or InputAction == nil or InputAction.GN_PHONE == nil then
		return
	end
	local ok, id = g_inputBinding:registerActionEvent(InputAction.GN_PHONE, target, M.onPhoneAction, false, true, false, true)
	if ok and id ~= nil then
		g_inputBinding:setActionEventText(id, M._lastText or GN.text("input_GN_PHONE", "Phone"))
		g_inputBinding:setActionEventTextPriority(id, GS_PRIO_LOW)
		g_inputBinding:setActionEventTextVisibility(id, true)
		table.insert(M.actionEventIds, id)
		M._lastCount = nil -- set the right text again
	end
end

function M.installInputHooks()
	if M._inputHooked then
		return
	end
	M._inputHooked = true
	if PlayerInputComponent ~= nil and PlayerInputComponent.registerGlobalPlayerActionEvents ~= nil then
		PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.overwrittenFunction(
			PlayerInputComponent.registerGlobalPlayerActionEvents, function(self, superFunc, ...)
				superFunc(self, ...)
				registerPhoneAction(self)
			end)
	end
	if Vehicle ~= nil and Vehicle.registerActionEvents ~= nil then
		Vehicle.registerActionEvents = Utils.overwrittenFunction(Vehicle.registerActionEvents, function(self, superFunc, ...)
			superFunc(self, ...)
			if self.getIsEntered ~= nil and self:getIsEntered() then
				registerPhoneAction(self)
			end
		end)
	end
end

--- Pages in the game's help (ESC - Help).
function M.loadHelp()
	if M._helpLoaded or g_helpLineManager == nil or g_helpLineManager.loadFromXML == nil then
		return
	end
	M._helpLoaded = true
	local path = Utils.getFilename("help/helpLine.xml", GN.dir)
	local ok = GN.try(g_helpLineManager.loadFromXML, g_helpLineManager, path, GN.modName)
	if not ok then
		ok = GN.try(g_helpLineManager.loadFromXML, g_helpLineManager, path)
	end
	GN.log("help pages %s", ok and "added" or "could not be added")
end

-- ---------------------------------------------------------------------------
-- Game hooks
-- ---------------------------------------------------------------------------

function M.installGameHooks()
	if M._gameHooked then
		return
	end
	M._gameHooked = true
	-- finished contracts (server)
	if AbstractMission ~= nil and AbstractMission.finish ~= nil then
		AbstractMission.finish = Utils.appendedFunction(AbstractMission.finish, function(mission, finishState)
			if g_server ~= nil then
				GN.safeCall("onMissionFinished", GN.Server.onMissionFinished, mission, finishState)
			end
		end)
	else
		GN.log("AbstractMission.finish not found - contract bonuses are not paid")
	end
	-- savegame
	if FSCareerMissionInfo ~= nil and FSCareerMissionInfo.saveToXMLFile ~= nil then
		FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function(missionInfo)
			if g_server ~= nil then
				GN.safeCall("save", GN.Server.save, missionInfo)
			end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Mod event listener
-- ---------------------------------------------------------------------------

local listener = {}

function listener:loadMap(name)
	GN.loadNeighbours()
	GN.Server.reset()
	GN.Client.reset()
	GN.Work.reset()
	GN.Borrow.reset()
	GN.Auto.reset()
	GN.Situ.reset()
	GN.Supply.reset()
	GN.Silo.reset()
	M.installGameHooks()
	GN.safeCall("access hook", GN.World.installAccessHook)
	GN.safeCall("npc list", GN.World.registerNpcs)
	if GN.hasUI() then
		GN.Client.loadPersonal()
		M.installInputHooks()
		GN.safeCall("menu page", GN.SettingsMenu.install)
		GN.safeCall("construction textures", GN.Tools.registerTexture)
		GN.safeCall("construction hooks", GN.Tools.installHooks)
		GN.safeCall("help pages", M.loadHelp)
		GN.safeCall("conversations", GN.Talk.load)
		GN.safeCall("phone textures", GN.Phone.registerTextures)
		GN.safeCall("map icon texture", GN.MapIcons.registerTexture)
	end
	GN.log("version %s loaded (%d characters, server=%s, ui=%s)", GN.version, #GN.neighbours, tostring(GN.isServer()), tostring(GN.hasUI()))
end

function listener:update(dt)
	if g_currentMission == nil then
		return
	end
	if g_server ~= nil then
		if not M._catalogue and g_currentMission.isMissionStarted ~= false then
			M._catalogue = true
			GN.safeCall("wardrobe catalogue", GN.Characters.logCatalogue)
		end
		GN.safeCall("server update", GN.Server.update, dt)
		GN.safeCall("work update", GN.Work.update, dt)
		GN.safeCall("borrow update", GN.Borrow.update, dt)
		GN.safeCall("auto places", GN.Auto.serverUpdate, dt)
		GN.safeCall("situations", GN.Situ.update, dt)
		GN.safeCall("supplies", GN.Supply.update, dt)
		GN.safeCall("silos", GN.Silo.update, dt)
	end
	if GN.hasUI() then
		GN.safeCall("client update", GN.Client.update, dt)
		GN.safeCall("characters update", GN.Characters.update, dt)
		GN.safeCall("drivers update", GN.Work.clientUpdate, dt)
		GN.safeCall("navigation", GN.Borrow.clientUpdate, dt)
		GN.safeCall("map icon positions", GN.MapIcons.updatePositions, dt)
		GN.safeCall("construction tools", GN.Tools.update, dt)
		M.updateKeyText()
	end
end

function listener:draw()
	if GN.hasUI() then
		GN.safeCall("construction panel", GN.Tools.draw) -- normally drawn with the HUD; here if the HUD is not drawn
	end
end

function listener:deleteMap()
	GN.Client.stopRing()
	GN.safeCall("map icons", GN.MapIcons.removeAll)
	GN.Silo.list = {}
	GN.safeCall("characters", GN.Characters.destroyAll)
	GN.safeCall("navigation", GN.Borrow.clientClear)
	if GN.Phone.dialog ~= nil and GN.Phone.dialog.isOpen then
		GN.Phone.close()
	end
end

addModEventListener(listener)
