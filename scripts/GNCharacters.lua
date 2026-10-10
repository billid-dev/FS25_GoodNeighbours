-- Good Neighbours (FS25) - neighbours standing at their homes, dressed like their photos
-- Client side only: every player builds the characters locally from the homes and outfits the server sends.
-- Author: billiD

local GN = GoodNeighbours

GN.Characters = GN.Characters or {}
local CH = GN.Characters

CH.models = CH.models or {}    -- nid -> { model, nid, x, z, rot, ready, styleKey }
CH.TURN_DISTANCE = 12          -- m: the neighbour turns towards a player this close
CH.TURN_SPEED = 2.5            -- rad/s

local function styleXml(gender)
	if gender == "female" then
		return "dataS/character/playerF/playerF.xml"
	end
	return "dataS/character/playerM/playerM.xml"
end

-- ---------------------------------------------------------------------------
-- Outfit: read from the local player / apply to a style
-- ---------------------------------------------------------------------------

--- Outfit of the local player as a plain table { [config] = { item, color } }.
function CH.captureLocalStyle()
	local p = g_localPlayer
	local style = p ~= nil and p.graphicsComponent ~= nil and p.graphicsComponent.style or nil
	if style == nil or style.configs == nil then
		return nil
	end
	local out = {}
	for key, cfg in pairs(style.configs) do
		if type(key) == "string" and type(cfg) == "table" and cfg.selectedItemIndex ~= nil then
			out[key] = { item = tonumber(cfg.selectedItemIndex) or 0, color = tonumber(cfg.selectedColorIndex) or 1 }
		end
	end
	-- remember whose body the outfit was made for (face, hair and beard only fit the same body)
	local file = string.lower(tostring(style.xmlFilename or ""))
	out._body = { item = string.find(file, "playerf", 1, true) ~= nil and 2 or 1, color = 1 }
	return out
end

--- Same outfit -> same text (keys sorted), used to notice outfit changes.
function CH.outfitKey(outfit)
	if outfit == nil then
		return ""
	end
	local keys = {}
	for k in pairs(outfit) do
		table.insert(keys, tostring(k))
	end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do
		local v = outfit[k]
		table.insert(parts, k .. "=" .. tostring(v.item) .. "/" .. tostring(v.color))
	end
	return table.concat(parts, ",")
end

local templates = {}
local function getTemplate(gender)
	local key = gender == "female" and "female" or "male"
	if templates[key] == nil and PlayerStyle ~= nil then
		local t = PlayerStyle.new()
		t:loadConfigurationXML(styleXml(gender))
		templates[key] = t
	end
	return templates[key]
end

--- Readable name of a wardrobe item (used for the catalogue in the log and for default outfits).
local function itemLabel(item)
	if type(item) ~= "table" then
		return tostring(item)
	end
	for _, k in ipairs({ "name", "uniqueName", "title", "filename", "xmlFilename", "nodeName", "uuid" }) do
		local v = item[k]
		if type(v) == "string" and v ~= "" then
			return v
		end
	end
	return "?"
end
CH.itemLabel = itemLabel

--- Default outfit from data/neighbours.xml (<wear config="top" match="flannel" color="2"/>):
--- the first item of that config whose name contains the text.
local function outfitFromWear(style, wear)
	local out = {}
	for _, w in ipairs(wear or {}) do
		local cfg = style.configs ~= nil and style.configs[w.config] or nil
		if cfg ~= nil and cfg.items ~= nil then
			if w.match == "none" then
				out[w.config] = { item = 0, color = 1 }
			else
				for i, item in ipairs(cfg.items) do
					if string.find(string.lower(itemLabel(item)), string.lower(w.match), 1, true) then
						out[w.config] = { item = i, color = w.color or 1 }
						break
					end
				end
			end
		end
	end
	return out
end

--- Server/host: write every wardrobe item to the log once (used to set the default outfits).
function CH.logCatalogue()
	if CH._catalogueLogged or PlayerStyle == nil then
		return
	end
	CH._catalogueLogged = true
	for _, gender in ipairs({ "male", "female" }) do
		local t = getTemplate(gender)
		if t ~= nil and t.configs ~= nil then
			local keys = {}
			for key in pairs(t.configs) do
				table.insert(keys, key)
			end
			table.sort(keys)
			for _, key in ipairs(keys) do
				local cfg = t.configs[key]
				local parts = {}
				for i, item in ipairs(cfg.items or {}) do
					local colors = item.colors ~= nil and #item.colors or (item.numColors or "")
					table.insert(parts, i .. "=" .. itemLabel(item) .. (colors ~= "" and ("(" .. tostring(colors) .. ")") or ""))
				end
				-- long lists in chunks of 25 so a log line stays readable
				for c = 1, math.max(1, math.ceil(#parts / 25)) do
					local chunk = {}
					for i = (c - 1) * 25 + 1, math.min(#parts, c * 25) do
						table.insert(chunk, parts[i])
					end
					GN.log("wardrobe %s %s [%d]: %s", gender, key, c, table.concat(chunk, ", "))
				end
			end
			local first = t.configs.top ~= nil and t.configs.top.items ~= nil and t.configs.top.items[1] or nil
			if type(first) == "table" then
				local fields = {}
				for k, v in pairs(first) do
					table.insert(fields, tostring(k) .. ":" .. type(v))
				end
				table.sort(fields)
				GN.log("wardrobe item fields: %s", table.concat(fields, " "))
			end
		end
	end
end

local function buildStyle(gender, outfit, forCabin, wear)
	local template = getTemplate(gender)
	if template == nil then
		return nil
	end
	local style = PlayerStyle.new()
	style:copyConfigurationFrom(template)
	style.xmlFilename = style.xmlFilename or styleXml(gender)
	if outfit == nil and wear ~= nil and style.configs ~= nil then
		outfit = outfitFromWear(style, wear)
	end
	if outfit ~= nil and style.configs ~= nil then
		local body = outfit._body ~= nil and (outfit._body.item == 2 and "female" or "male") or nil
		local sameBody = body == nil or body == (gender == "female" and "female" or "male")
		for key, v in pairs(outfit) do
			local cfg = style.configs[key]
			local bodyPart = key == "face" or key == "hairStyle" or key == "beard"
			if cfg ~= nil and type(v) == "table" and (sameBody or not bodyPart) then
				local item = tonumber(v.item) or 0
				if item == 0 or (cfg.items ~= nil and cfg.items[item] ~= nil) then
					cfg.selectedItemIndex = item
					cfg.selectedColorIndex = tonumber(v.color) or 1
				end
			end
		end
	end
	CH.sanitize(style)
	return style
end

CH.buildStyle = buildStyle

--- Make a style safe to load: every slot points to an existing item, a one-piece clears shirt and trousers,
--- otherwise shirt, trousers and shoes are always worn (an empty slot leaves the body cut open),
--- colours only where the item can be coloured, and a valid hair style under a hat.
function CH.sanitize(style)
	local cfg = style ~= nil and style.configs or nil
	if cfg == nil then
		return
	end
	local function valid(slot, idx)
		return slot ~= nil and slot.items ~= nil and slot.items[idx] ~= nil
	end
	local always = { face = true }
	for key, slot in pairs(cfg) do
		if type(slot) == "table" and slot.items ~= nil then
			local idx = tonumber(slot.selectedItemIndex) or 0
			if idx ~= 0 and not valid(slot, idx) then
				idx = always[key] and 1 or 0
			end
			slot.selectedItemIndex = idx
			local item = slot.items[idx]
			local c = tonumber(slot.selectedColorIndex) or 1
			if item == nil or (item.colorableSlots or 0) <= 0 or c < 1 then
				c = 1
			elseif item.possibleColors ~= nil and #item.possibleColors > 0 and c > #item.possibleColors then
				c = 1
			end
			slot.selectedColorIndex = c
		end
	end
	local onepiece = cfg.onepiece ~= nil and (cfg.onepiece.selectedItemIndex or 0) or 0
	if onepiece > 0 then
		if cfg.top ~= nil then cfg.top.selectedItemIndex, cfg.top.selectedColorIndex = 0, 1 end
		if cfg.bottom ~= nil then cfg.bottom.selectedItemIndex, cfg.bottom.selectedColorIndex = 0, 1 end
	else
		for _, key in ipairs({ "top", "bottom" }) do
			local slot = cfg[key]
			if slot ~= nil and slot.items ~= nil then
				local item = slot.items[slot.selectedItemIndex or 0]
				-- nothing worn at all: the plain first item (the outfit itself is kept exactly as saved)
				if item == nil then
					if slot.items[1] ~= nil then
						slot.selectedItemIndex, slot.selectedColorIndex = 1, 1
					end
				end
			end
		end
	end
	for _, key in ipairs({ "face" }) do
		local slot = cfg[key]
		if slot ~= nil and slot.items ~= nil and slot.items[slot.selectedItemIndex or 0] == nil and slot.items[1] ~= nil then
			slot.selectedItemIndex, slot.selectedColorIndex = 1, 1
		end
	end
	-- hair under a hat must be a hat hair style
	local hair = cfg.hairStyle ~= nil and cfg.hairStyle.items or nil
	if hair ~= nil then
		local h = style.hatHairstyleIndex
		if h == nil or hair[h] == nil or hair[h].forHat ~= true then
			for i = #hair, 1, -1 do
				if hair[i] ~= nil and hair[i].forHat then
					style.hatHairstyleIndex = i
					break
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Idle animation
-- ---------------------------------------------------------------------------

local function findCharSet(node)
	if node == nil or node == 0 then
		return 0
	end
	local cs = getAnimCharacterSet(node)
	if cs ~= nil and cs ~= 0 then
		return cs
	end
	for i = 0, getNumOfChildren(node) - 1 do
		cs = findCharSet(getChildAt(node, i))
		if cs ~= 0 then
			return cs
		end
	end
	return 0
end

local function playLoop(charSet, names)
	for _, name in ipairs(names) do
		local ix = getAnimClipIndex(charSet, name)
		if ix ~= nil and ix >= 0 then
			assignAnimTrackClip(charSet, 0, ix)
			setAnimTrackLoopState(charSet, 0, true)
			enableAnimTrack(charSet, 0)
			return true
		end
	end
	return false
end

local function startIdle(e, gender)
	local model = e.model
	if model == nil or model.rootNode == nil then
		return false
	end
	local names = gender == "female"
		and { "idle1FemaleSource", "NPCFemaleIdle01Source", "idle1Source" }
		or { "idle1Source", "NPCMaleIdle01Source", "NPCMaleIdle02Source" }
	local charSet = findCharSet(model.rootNode)
	if charSet == 0 and model.skeleton ~= nil and g_animCache ~= nil and AnimationCache ~= nil and AnimationCache.CHARACTER ~= nil then
		local animNode = g_animCache:getNode(AnimationCache.CHARACTER)
		if animNode ~= nil and animNode ~= 0 then
			local animRoot = getNumOfChildren(animNode) > 0 and getChildAt(animNode, 0) or animNode
			cloneAnimCharacterSet(animRoot, model.skeleton)
			charSet = findCharSet(model.skeleton)
		end
	end
	if charSet == 0 then
		return false
	end
	playLoop(charSet, names)
	return true
end

-- ---------------------------------------------------------------------------
-- Creating / placing
-- ---------------------------------------------------------------------------

local function groundY(x, z)
	if g_terrainNode ~= nil then
		return getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z)
	end
	return 0
end

function CH.place(e)
	if e.model == nil or e.model.rootNode == nil or e.x == nil then
		return
	end
	setWorldTranslation(e.model.rootNode, e.x, groundY(e.x, e.z), e.z)
	setWorldRotation(e.model.rootNode, 0, e.rot or 0, 0)
end

function CH.showSubtree(node)
	if node == nil or node == 0 or not entityExists(node) then
		return
	end
	setVisibility(node, true)
	for i = 0, getNumOfChildren(node) - 1 do
		CH.showSubtree(getChildAt(node, i))
	end
end

function CH.onStyleLoaded(e, loadingState)
	if e.deleted then
		return
	end
	if HumanModelLoadingState ~= nil and loadingState ~= HumanModelLoadingState.OK then
		GN.log("could not dress %s (state %s)", tostring(GN.getNeighbour(e.nid).name), tostring(loadingState))
	end
	e.ready = true
	if e.model.setVisibility ~= nil then
		e.model:setVisibility(true)
	end
	-- the clothes are loaded hidden: show the whole character (otherwise only the cut body is visible)
	if e.model.rootNode ~= nil then
		CH.showSubtree(e.model.rootNode)
	end
	CH.place(e)
	e.idleOk = startIdle(e, GN.getNeighbour(e.nid).gender)
end

function CH.onBaseLoaded(e, loadingState)
	if e.deleted or e.model == nil then
		return
	end
	if HumanModelLoadingState ~= nil and loadingState ~= HumanModelLoadingState.OK then
		GN.log("could not load the character of %s (state %s)", tostring(GN.getNeighbour(e.nid).name), tostring(loadingState))
		return
	end
	link(getRootNode(), e.model.rootNode)
	CH.place(e)
	local n = GN.getNeighbour(e.nid)
	local style = buildStyle(n.gender, e.outfit, false, n.wear)
	if style == nil then
		CH.onStyleLoaded(e, HumanModelLoadingState ~= nil and HumanModelLoadingState.OK or nil)
		return
	end
	e.style = style
	e.model:loadFromStyleAsync(style, CH.onStyleLoaded, e)
end

function CH.create(nid, x, z, outfit, styleKey)
	local n = GN.getNeighbour(nid)
	if n == nil or HumanModel == nil then
		return
	end
	local e = { nid = nid, x = x, z = z, rot = math.random() * 2 * math.pi, outfit = outfit, styleKey = styleKey }
	CH.models[nid] = e
	local model = HumanModel.new()
	model.initIKChains = false
	e.model = model
	model:load(styleXml(n.gender), false, false, true, CH.onBaseLoaded, e)
end

function CH.destroy(nid)
	local e = CH.models[nid]
	if e == nil then
		return
	end
	CH.models[nid] = nil
	e.deleted = true
	if e.model ~= nil and e.model.delete ~= nil then
		GN.try(e.model.delete, e.model)
	end
end

function CH.destroyAll()
	for nid in pairs(CH.models) do
		CH.destroy(nid)
	end
end

--- Bring the characters in line with the homes and outfits from the server.
function CH.sync(homes, styles)
	if not GN.hasUI() or g_currentMission == nil then
		return
	end
	local seen = {}
	for _, h in ipairs(homes or {}) do
		local nid = tonumber(h.nid)
		if nid ~= nil and h.x ~= nil then
			seen[nid] = true
			local outfit = styles ~= nil and styles[nid] or nil
			local key = CH.outfitKey(outfit)
			local e = CH.models[nid]
			if e ~= nil and e.styleKey ~= key then
				CH.destroy(nid) -- new outfit: build again
				e = nil
			end
			-- stand a few metres beside the home point so the map icon does not cover the character
			local x, z = h.x + 1.5, h.z + 1.5
			if e == nil then
				CH.create(nid, x, z, outfit, key)
				CH.models[nid].homeX, CH.models[nid].homeZ = x, z
			else
				e.homeX, e.homeZ = x, z
			end
		end
	end
	for nid in pairs(CH.models) do
		if not seen[nid] then
			CH.destroy(nid)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Update: turn towards a nearby player
-- ---------------------------------------------------------------------------

--- Neighbour standing closest to the local player within maxDist metres (or nil).
function CH.nearest(maxDist)
	local p = g_localPlayer
	if p == nil or p.getPosition == nil then
		return nil
	end
	if p.getCurrentVehicle ~= nil then
		local okV, v = GN.try(p.getCurrentVehicle, p)
		if okV and v ~= nil then
			return nil
		end
	end
	local ok, px, _, pz = GN.try(p.getPosition, p)
	if not ok or px == nil then
		return nil
	end
	local best, bestD = nil, maxDist * maxDist
	for nid, e in pairs(CH.models) do
		if e.ready and e.x ~= nil and e.shown ~= false then
			local d = (px - e.x) ^ 2 + (pz - e.z) ^ 2
			if d < bestD then
				best, bestD = nid, d
			end
		end
	end
	return best
end

function CH.update(dt)
	local p = g_localPlayer
	if p == nil or p.getPosition == nil then
		return
	end
	local ok, px, _, pz = GN.try(p.getPosition, p)
	if not ok or px == nil then
		return
	end
	for nid, e in pairs(CH.models) do
		if e.ready and e.model ~= nil and e.model.rootNode ~= nil then
			-- daily plan: asleep / away -> not there; driving his tractor -> not standing at home
			local cur = GN.Plan.current(nid)
			local driving = GN.Work.clientDrivers ~= nil and GN.Work.clientDrivers[nid] ~= nil
			-- where he is now: a place from his day plan, otherwise at home
			local tx, tz = GN.Plan.position(nid, GN.Client.places)
			if tx == nil then
				tx, tz = e.homeX, e.homeZ
			end
			if tx ~= nil and (math.abs(tx - e.x) > 0.1 or math.abs(tz - e.z) > 0.1) then
				e.x, e.z = tx, tz
				CH.place(e)
			end
			local shown = (cur == nil or cur.visible) and not driving
			if shown ~= e.shown then
				e.shown = shown
				if e.model.setVisibility ~= nil then
					GN.try(e.model.setVisibility, e.model, shown)
				end
				setVisibility(e.model.rootNode, shown)
			end
			local dx, dz = px - e.x, pz - e.z
			if dx * dx + dz * dz < CH.TURN_DISTANCE * CH.TURN_DISTANCE then
				local target = (math.atan2 or math.atan)(dx, dz)
				local diff = (target - e.rot + math.pi) % (2 * math.pi) - math.pi
				local step = CH.TURN_SPEED * (dt or 0) / 1000
				if math.abs(diff) <= step then
					e.rot = target
				else
					e.rot = e.rot + (diff > 0 and step or -step)
				end
				setWorldRotation(e.model.rootNode, 0, e.rot, 0)
			end
			if not e.idleOk and (e.idleTries or 0) < 5 then
				e.idleTries = (e.idleTries or 0) + 1
				e.idleOk = startIdle(e, GN.getNeighbour(e.nid).gender)
			end
		end
	end
end
