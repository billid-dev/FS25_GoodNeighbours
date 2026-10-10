-- Good Neighbours (FS25) - construction menu: own category with the neighbour tools,
-- place sizes (Shift+Q), removing all places of a kind (Shift+Del), boxes and icons over every place
-- and the "set / needed" panel in the bottom right corner.
-- Author: billiD

local GN = GoodNeighbours

GN.Tools = GN.Tools or {}
local T = GN.Tools

T.CATEGORY = "GOODNEIGHBOURS"
T.SIZES = { "home", "vehicle", "attach", "oversize", "silo" }
-- box of a place: length (front 3 m + rest behind the point), half width; home / visit places are a circle
T.FRONT = 3
T.BOX = {
	vehicle  = { len = 9,  side = 1.8 },
	attach   = { len = 18, side = 2.4 },  -- vehicle + attachment: the long place
	oversize = { len = 14, side = 4.5 },  -- combine with its header
	silo     = { len = 7,  side = 3.5 },
}
T.COLOR = {
	home = { 1, 1, 1 }, vehicle = { 0.15, 0.55, 1 }, attach = { 0.1, 0.9, 0.3 }, oversize = { 1, 0.55, 0.1 },
	silo = { 0.95, 0.85, 0.15 }, place = { 0.85, 0.4, 1 }, remove = { 1, 0.1, 0.1 }, dim = { 0.45, 0.45, 0.45 },
}
T.HUD_MET = { 0.10, 0.65, 1.00 }
T.HUD_BELOW = { 1.00, 0.60, 0.05 }
T.HUD_HEAD = { 0.70, 0.88, 1.00 }
T.REMOVE_RADIUS = 30
T.MARKER_RANGE = 450

T.sizeIndex = 1

-- ---------------------------------------------------------------------------
-- Which tool is selected
-- ---------------------------------------------------------------------------

--- Tool of a store item: { action = "home", nid } / { action = "place_<type>" } / { action = "remove" } or nil.
function T.toolFromStoreItem(storeItem)
	if storeItem == nil then
		return nil
	end
	local path = string.lower(tostring(storeItem.rawXMLFilename or storeItem.xmlFilename or "")):gsub("\\", "/")
	local nid = string.match(path, "placeables/gn_home_(%d+)%.xml")
	if nid ~= nil then
		return { action = "home", nid = tonumber(nid) }
	end
	local t = string.match(path, "placeables/gn_place_(%w+)%.xml")
	if t ~= nil then
		return { action = "place_" .. t, place = t }
	end
	if string.find(path, "placeables/gn_remove.xml", 1, true) ~= nil then
		return { action = "remove" }
	end
	return nil
end

function T.isOpen()
	return g_constructionScreen ~= nil and g_constructionScreen.isOpen == true
end

function T.selected()
	if not T.isOpen() then
		return nil
	end
	local brush = g_constructionScreen.brush
	if brush == nil or brush.placeable == nil then
		return nil -- nothing in hand (the store item of the last brush stays set after ESC)
	end
	return T.toolFromStoreItem(brush.storeItem)
end

--- Sizes the tool offers: the neighbour tool of a farmer has all of them, the others only one.
function T.sizesFor(tool)
	if tool == nil or tool.action ~= "home" then
		return { "home" }
	end
	local n = GN.getNeighbour(tool.nid)
	if n == nil or not n.contracts then
		return { "home" }
	end
	return T.SIZES
end

function T.currentSize(tool)
	local sizes = T.sizesFor(tool)
	return sizes[math.max(1, math.min(#sizes, T.sizeIndex))] or "home", sizes
end

function T.sendSize(tool)
	local size = T.currentSize(tool)
	if size ~= T.sentSize then
		T.sentSize = size
		GN.sendToServer("toolSize", { size = size })
	end
end

function T.cycleSize()
	local tool = T.selected()
	if tool == nil then
		return
	end
	local sizes = T.sizesFor(tool)
	T.sizeIndex = (math.max(1, math.min(#sizes, T.sizeIndex)) % #sizes) + 1
	T.sendSize(tool)
	T.flash(string.format(GN.text("gn_tool_size_now"), GN.text("gn_size_" .. T.currentSize(tool))))
end

function T.flash(text)
	T.flashText = text
	T.flashUntil = (g_time or 0) + 4000
end

--- Shift+Del: remove all places of the selected kind; asks once (press again within 4 s).
function T.bulkRemove()
	local tool = T.selected()
	if tool == nil or tool.action == "remove" then
		return
	end
	if not GN.isLocalAdmin() then
		T.flash(GN.text("gn_tool_admin_only"))
		return
	end
	local size = T.currentSize(tool)
	if tool.action == "home" and size == "home" then
		T.flash(GN.text("gn_tool_home_no_bulk"))
		return
	end
	local key = tool.action .. "|" .. tostring(tool.nid) .. "|" .. size
	local now = g_time or 0
	if T.bulkArmed == key and now < (T.bulkArmedUntil or 0) then
		T.bulkArmed = nil
		GN.sendToServer("bulkRemove", { action = tool.action, nid = tool.nid, size = tool.action == "home" and size or nil })
		return
	end
	T.bulkArmed, T.bulkArmedUntil = key, now + 4000
	local what
	if tool.action == "home" then
		local n = GN.getNeighbour(tool.nid)
		what = string.format("%s - %s", n ~= nil and n.name or "?", GN.text("gn_size_" .. size))
	else
		what = GN.text("gn_place_" .. tool.place, tool.place)
	end
	T.flash(string.format(GN.text("gn_tool_bulk_confirm"), what))
end

--- Shift+G: the server fills in every missing place by itself; pressed twice within 4 s: redo all automatic places.
function T.autoPlaces()
	if not GN.isLocalAdmin() then
		T.flash(GN.text("gn_tool_admin_only"))
		return
	end
	local now = g_time or 0
	local reset = T.autoArmedUntil ~= nil and now < T.autoArmedUntil
	T.autoArmedUntil = reset and nil or now + 4000
	GN.sendToServer("autoPlaces", { reset = reset })
	T.flash(GN.text(reset and "gn_tool_auto_redo" or "gn_tool_auto_fill"))
end

-- ---------------------------------------------------------------------------
-- Key bindings while the construction menu is open
-- ---------------------------------------------------------------------------

local function eventStillRegistered(id)
	local me = g_constructionScreen ~= nil and g_constructionScreen.menuEvents or nil
	if me == nil then
		return true
	end
	for _, e in ipairs(me) do
		if e == id then
			return true
		end
	end
	return false
end

local function removeEvent(id)
	if id == nil or g_inputBinding == nil then
		return
	end
	g_inputBinding:removeActionEvent(id)
	local me = g_constructionScreen ~= nil and g_constructionScreen.menuEvents or nil
	if me ~= nil then
		for i = #me, 1, -1 do
			if me[i] == id then
				table.remove(me, i)
			end
		end
	end
end

local function registerEvent(action, fn, textKey)
	if InputAction == nil or InputAction[action] == nil or g_inputBinding == nil then
		return nil
	end
	local _, id = g_inputBinding:registerActionEvent(InputAction[action], g_constructionScreen, fn, false, true, false, true)
	if id ~= nil then
		g_inputBinding:setActionEventTextPriority(id, GS_PRIO_VERY_HIGH)
		g_inputBinding:setActionEventTextVisibility(id, true)
		g_inputBinding:setActionEventText(id, GN.text(textKey))
		g_constructionScreen.menuEvents = g_constructionScreen.menuEvents or {}
		table.insert(g_constructionScreen.menuEvents, id)
	end
	return id
end

function T.updateKeys(tool)
	if not T.isOpen() then
		removeEvent(T.sizeEvent)
		removeEvent(T.bulkEvent)
		removeEvent(T.autoEvent)
		T.sizeEvent, T.bulkEvent, T.autoEvent = nil, nil, nil
		return
	end
	if T.autoEvent ~= nil and not eventStillRegistered(T.autoEvent) then
		removeEvent(T.autoEvent)
		T.autoEvent = nil
	end
	if T.autoEvent == nil then
		T.autoEvent = registerEvent("GN_PLACE_AUTO", function() GN.safeCall("auto places", T.autoPlaces) end, "input_GN_PLACE_AUTO")
	end
	if T.autoEvent ~= nil then
		g_inputBinding:setActionEventActive(T.autoEvent, tool ~= nil)
	end
	if T.sizeEvent ~= nil and not eventStillRegistered(T.sizeEvent) then
		removeEvent(T.sizeEvent)
		T.sizeEvent = nil
	end
	if T.bulkEvent ~= nil and not eventStillRegistered(T.bulkEvent) then
		removeEvent(T.bulkEvent)
		T.bulkEvent = nil
	end
	if T.sizeEvent == nil then
		T.sizeEvent = registerEvent("GN_PLACE_SIZE", function() GN.safeCall("place size", T.cycleSize) end, "input_GN_PLACE_SIZE")
	end
	if T.bulkEvent == nil then
		T.bulkEvent = registerEvent("GN_PLACE_BULK_REMOVE", function() GN.safeCall("bulk remove", T.bulkRemove) end, "input_GN_PLACE_BULK_REMOVE")
	end
	local sizes = T.sizesFor(tool)
	if T.sizeEvent ~= nil then
		g_inputBinding:setActionEventActive(T.sizeEvent, tool ~= nil and #sizes > 1)
	end
	if T.bulkEvent ~= nil then
		g_inputBinding:setActionEventActive(T.bulkEvent, tool ~= nil and tool.action ~= "remove")
	end
end

-- ---------------------------------------------------------------------------
-- Own category in the construction menu (admins): tab 1 places, tab 2 the neighbours
-- ---------------------------------------------------------------------------

function T.getCategory()
	if g_storeManager == nil or g_storeManager.getConstructionCategoryByName == nil then
		return nil
	end
	return g_storeManager:getConstructionCategoryByName(T.CATEGORY)
end

function T.fillCategory(screen)
	if screen == nil or screen.items == nil or g_storeManager == nil or not GN.isLocalAdmin() then
		return
	end
	local cat = T.getCategory()
	if cat == nil then
		g_storeManager:addConstructionCategory(T.CATEGORY, GN.text("gn_settings_section"), nil, nil, "", "gnPlaceIcons.menu")
		cat = T.getCategory()
		if cat == nil then
			return
		end
	end
	cat.tabs = {
		{ name = "GN_PLACES", title = GN.text("gn_tab_places"), index = 1 },
		{ name = "GN_NEIGHBOURS", title = GN.text("gn_tab_neighbours"), index = 2 },
	}
	local places, homes, removeItem, seen, count = {}, {}, nil, {}, 0
	for ci, tabs in pairs(screen.items) do
		if ci ~= cat.index and type(tabs) == "table" then
			for _, list in pairs(tabs) do
				for _, item in ipairs(type(list) == "table" and list or {}) do
					local tool = item ~= nil and T.toolFromStoreItem(item.storeItem) or nil
					local key = tool ~= nil and tostring(item.storeItem.xmlFilename) or nil
					if tool ~= nil and not seen[key] then
						seen[key] = true
						local clone = {}
						for k, v in pairs(item) do
							clone[k] = v
						end
						count = count + 1
						clone.uniqueIndex = count
						clone.gnTool = tool
						if tool.action == "remove" then
							removeItem = clone
						elseif tool.action == "home" then
							table.insert(homes, clone)
						else
							table.insert(places, clone)
						end
					end
				end
			end
		end
	end
	table.sort(homes, function(a, b) return (a.gnTool.nid or 0) < (b.gnTool.nid or 0) end)
	if removeItem ~= nil then
		table.insert(places, 1, removeItem)
		local copy = {}
		for k, v in pairs(removeItem) do
			copy[k] = v
		end
		table.insert(homes, 1, copy)
	end
	screen.categories = g_storeManager:getConstructionCategories()
	screen.items[cat.index] = { places, homes }
	if screen.categorySelector ~= nil and screen.categorySelector.reloadData ~= nil then
		screen.categorySelector:reloadData()
	end
end

function T.installHooks()
	if T._hooked or ConstructionScreen == nil then
		return
	end
	T._hooked = true
	if ConstructionScreen.rebuildData ~= nil then
		ConstructionScreen.rebuildData = Utils.appendedFunction(ConstructionScreen.rebuildData, function(screen)
			GN.safeCall("construction category", T.fillCategory, screen)
		end)
	end
	if ConstructionScreen.setCurrentCategory ~= nil then
		ConstructionScreen.setCurrentCategory = Utils.appendedFunction(ConstructionScreen.setCurrentCategory, function(screen, index)
			local cat = T.getCategory()
			if cat ~= nil and index == cat.index then
				screen.currentTab = screen.currentTab or 1
			end
		end)
	end
	-- the panel and the icons: drawn with the HUD (it is drawn while the construction menu is open)
	if GameInfoDisplay ~= nil and GameInfoDisplay.draw ~= nil then
		GameInfoDisplay.draw = Utils.appendedFunction(GameInfoDisplay.draw, function(display)
			GN.safeCall("construction panel", T.draw, display)
		end)
	end
end

function T.registerTexture()
	if T._texture or g_overlayManager == nil then
		return
	end
	T._texture = true
	local path = Utils.getFilename("gui/gnPlaceIcons.xml", GN.dir)
	if fileExists(path) then
		g_overlayManager:addTextureConfigFile(path, "gnPlaceIcons")
	end
end

-- ---------------------------------------------------------------------------
-- Places as the client knows them (sent by the server)
-- ---------------------------------------------------------------------------

--- All places: { kind = "home"|"slot"|"place"|"parking", size, nid, type, x, z, ry, no }.
function T.allPlaces()
	local C = GN.Client
	local out = {}
	for _, h in ipairs(C.homes or {}) do
		table.insert(out, { kind = "home", size = "home", nid = h.nid, x = h.x, z = h.z, ry = h.ry or 0 })
	end
	local no = {}
	for _, p in ipairs(C.slots or {}) do
		local size = p.size or "attach"
		local k = tostring(p.nid) .. size
		no[k] = (no[k] or 0) + 1
		table.insert(out, { kind = "slot", size = size, nid = p.nid, x = p.x, z = p.z, ry = p.ry or 0, no = no[k] })
	end
	for _, p in ipairs(C.parking or {}) do
		table.insert(out, { kind = "parking", size = "vehicle", nid = p.nid, x = p.x, z = p.z, ry = p.ry or 0 })
	end
	for _, p in ipairs(C.places or {}) do
		table.insert(out, { kind = "place", size = "place", type = p.type, x = p.x, z = p.z, ry = p.ry or 0 })
	end
	return out
end

--- Set / needed per size for one neighbour.
function T.counts(nid)
	local C = GN.Client
	local act = { home = 0, vehicle = 0, attach = 0, oversize = 0, silo = 0 }
	for _, h in ipairs(C.homes or {}) do
		if h.nid == nid then
			act.home = 1
		end
	end
	for _, p in ipairs(C.slots or {}) do
		if p.nid == nid then
			local s = p.size or "attach"
			act[s] = (act[s] or 0) + 1
		end
	end
	local req = { home = 1, vehicle = 0, attach = 0, oversize = 0, silo = 0 }
	for _, e in ipairs(C.need or {}) do
		if e.nid == nid then
			for _, s in ipairs(T.SIZES) do
				req[s] = tonumber(e[s]) or req[s]
			end
		end
	end
	return act, req
end

-- ---------------------------------------------------------------------------
-- 3D: boxes on the ground (debug lines, every frame from update)
-- ---------------------------------------------------------------------------

local function groundY(x, z)
	return (g_terrainNode ~= nil and getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z) or 0) + 0.35
end

local function line(x1, z1, x2, z2, c)
	if drawDebugLine == nil then
		return
	end
	local d = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
	local steps = math.max(1, math.ceil(d / 3))
	local px, pz, py = x1, z1, groundY(x1, z1)
	for i = 1, steps do
		local nx, nz = x1 + (x2 - x1) * i / steps, z1 + (z2 - z1) * i / steps
		local ny = groundY(nx, nz)
		drawDebugLine(px, py, pz, c[1], c[2], c[3], nx, ny, nz, c[1], c[2], c[3])
		px, pz, py = nx, nz, ny
	end
end

local function offset(x, z, ry, lx, lz)
	-- local +z is the front, local +x the right side
	local s, c = math.sin(ry), math.cos(ry)
	return x + lx * c + lz * s, z - lx * s + lz * c
end

function T.drawBox(x, z, ry, size, c)
	local b = T.BOX[size]
	if b == nil then
		-- home / visit place: a circle with an arrow
		local r = size == "remove" and 1.5 or 1.2
		local px, pz = x + r, z
		for i = 1, 16 do
			local a = i / 16 * 2 * math.pi
			local nx, nz = x + math.cos(a) * r, z + math.sin(a) * r
			line(px, pz, nx, nz, c)
			px, pz = nx, nz
		end
		local tx, tz = offset(x, z, ry, 0, 2.5)
		line(x, z, tx, tz, c)
		return
	end
	local back = b.len - T.FRONT
	local flx, flz = offset(x, z, ry, -b.side, T.FRONT)
	local frx, frz = offset(x, z, ry, b.side, T.FRONT)
	local brx, brz = offset(x, z, ry, b.side, -back)
	local blx, blz = offset(x, z, ry, -b.side, -back)
	line(flx, flz, frx, frz, c)
	line(frx, frz, brx, brz, c)
	line(brx, brz, blx, blz, c)
	line(blx, blz, flx, flz, c)
	-- arrow: where the machine faces
	local tx, tz = offset(x, z, ry, 0, T.FRONT + 3)
	local lx, lz = offset(x, z, ry, -0.7, T.FRONT + 1.8)
	local rx, rz = offset(x, z, ry, 0.7, T.FRONT + 1.8)
	line(x, z, tx, tz, c)
	line(tx, tz, lx, lz, c)
	line(tx, tz, rx, rz, c)
end

local function isHighlighted(p, tool)
	if tool == nil then
		return true
	end
	if tool.action == "home" then
		return p.nid == tool.nid
	elseif tool.action == "remove" then
		return true
	end
	return p.kind == "place" and p.type == tool.place
end

function T.nearestToCursor(x, z)
	local best, bestD = nil, T.REMOVE_RADIUS ^ 2
	for _, p in ipairs(T.allPlaces()) do
		if p.kind ~= "home" then
			local d = (p.x - x) ^ 2 + (p.z - z) ^ 2
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

function T.cursorPos()
	local cursor = g_constructionScreen ~= nil and g_constructionScreen.cursor or nil
	if cursor == nil or cursor.currentHitX == nil or cursor.currentHitZ == nil then
		return nil
	end
	return cursor.currentHitX, cursor.currentHitZ, cursor.targetRotation or 0
end

function T.drawWorld(tool)
	local cx, cy, cz = 0, 0, 0
	local cam = getCamera ~= nil and getCamera() or nil
	if cam ~= nil and cam ~= 0 then
		cx, cy, cz = getWorldTranslation(cam)
	end
	local removeTarget = nil
	local hx, hz, hry = T.cursorPos()
	if tool.action == "remove" and hx ~= nil then
		removeTarget = T.nearestToCursor(hx, hz)
	end
	for _, p in ipairs(T.allPlaces()) do
		if (p.x - cx) ^ 2 + (p.z - cz) ^ 2 < T.MARKER_RANGE ^ 2 then
			local c
			if p == removeTarget then
				c = T.COLOR.remove
			elseif isHighlighted(p, tool) then
				c = T.COLOR[p.size] or T.COLOR.place
			else
				c = T.COLOR.dim
			end
			T.drawBox(p.x, p.z, p.ry or 0, p.size, c)
		end
	end
	-- preview at the cursor
	if hx ~= nil then
		if tool.action == "remove" then
			T.drawBox(hx, hz, 0, "remove", T.COLOR.remove)
			local r = T.REMOVE_RADIUS
			local px, pz = hx + r, hz
			for i = 1, 40 do
				local a = i / 40 * 2 * math.pi
				local nx, nz = hx + math.cos(a) * r, hz + math.sin(a) * r
				line(px, pz, nx, nz, T.COLOR.remove)
				px, pz = nx, nz
			end
		else
			local size = tool.action == "home" and T.currentSize(tool) or "place"
			local col = { 0, 1, 0 }
			-- red when the new machine place would overlap another one
			if T.BOX[size] ~= nil and GN.Auto ~= nil and GN.Auto.boxesOverlap ~= nil then
				local me = { x = hx, z = hz, ry = hry, size = size }
				for _, q in ipairs(GN.Client.slots or {}) do
					local ok, hit = GN.try(GN.Auto.boxesOverlap, me, q)
					if ok and hit then
						col = { 1, 0.15, 0.15 }
						break
					end
				end
			end
			T.drawBox(hx, hz, hry, size, col)
		end
	end
end

function T.update(dt)
	local tool = T.selected()
	GN.safeCall("construction keys", T.updateKeys, tool)
	if not T.isOpen() then
		T.sentSize = nil
		return
	end
	if tool ~= nil then
		if tool.action == "home" then
			T.sendSize(tool)
		end
		T.drawWorld(tool)
	end
end

-- ---------------------------------------------------------------------------
-- 2D: icons over the places and the panel in the bottom right corner (drawn with the HUD)
-- ---------------------------------------------------------------------------

local function overlay(slice)
	T.overlays = T.overlays or {}
	local o = T.overlays[slice]
	if o == nil and g_overlayManager ~= nil then
		o = g_overlayManager:createOverlay(slice, 0, 0, 0.02, 0.02)
		T.overlays[slice] = o or false
	end
	return o or nil
end

local function iconSlice(p)
	if p.kind == "place" then
		return "gnPlaceIcons." .. tostring(p.type)
	end
	return "gnPlaceIcons." .. tostring(p.size)
end

function T.placeLabel(p)
	if p.kind == "place" then
		return GN.text("gn_place_" .. tostring(p.type), p.type)
	end
	local n = GN.getNeighbour(p.nid)
	local name = n ~= nil and n.name or "?"
	if p.kind == "home" then
		return string.format(GN.text("gn_label_home"), name)
	elseif p.kind == "parking" then
		return string.format(GN.text("gn_label_parking"), name)
	end
	return string.format("%s - %s %d", name, GN.text("gn_size_" .. p.size), p.no or 1)
end

function T.drawIcons(tool)
	if project == nil or getCamera == nil then
		return
	end
	local cam = getCamera()
	if cam == nil or cam == 0 then
		return
	end
	local cx, _, cz = getWorldTranslation(cam)
	local pw, ph = getNormalizedScreenValues(34, 34)
	local bw, bh = getNormalizedScreenValues(18, 18)
	local size = getCorrectTextSize(0.011)
	setTextAlignment(RenderText.ALIGN_CENTER)
	for _, p in ipairs(T.allPlaces()) do
		if (p.x - cx) ^ 2 + (p.z - cz) ^ 2 < T.MARKER_RANGE ^ 2 then
			local y = groundY(p.x, p.z) + 3
			local sx, sy, sz = project(p.x, y, p.z)
			if sx ~= nil and sz ~= nil and sz >= 0 and sz <= 1 and sx > -0.05 and sx < 1.05 and sy > -0.05 and sy < 1.05 then
				local bright = isHighlighted(p, tool)
				local a = bright and 1 or 0.55
				if p.nid ~= nil then
					-- neighbour photo with a small badge of the place size
					local portrait = overlay("gnMapIcons.n" .. tostring(p.nid))
					if portrait ~= nil then
						portrait:setDimension(pw, ph)
						portrait:setPosition(sx - pw / 2, sy)
						portrait:setColor(1, 1, 1, a)
						portrait:render()
					end
					local badge = overlay(iconSlice(p))
					if badge ~= nil then
						badge:setDimension(bw, bh)
						badge:setPosition(sx + pw / 2 - bw * 0.6, sy - bh * 0.25)
						badge:setColor(1, 1, 1, a)
						badge:render()
					end
				else
					local icon = overlay(iconSlice(p))
					if icon ~= nil then
						icon:setDimension(pw, ph)
						icon:setPosition(sx - pw / 2, sy)
						icon:setColor(1, 1, 1, a)
						icon:render()
					end
				end
				if bright then
					setTextColor(1, 1, 1, 1)
					setTextBold(false)
					renderText(sx, sy - size * 1.2, size, T.placeLabel(p))
				end
			end
		end
	end
	setTextAlignment(RenderText.ALIGN_LEFT)
end

-- panel rows: { text, right, color, bold, indent }
function T.buildPanel(tool)
	local rows = {}
	local function add(text, right, color, bold, indent)
		table.insert(rows, { text = text, right = right, color = color, bold = bold, indent = indent })
	end
	local function status(act, req)
		return string.format("%d/%d", act, req), act >= req and T.HUD_MET or T.HUD_BELOW
	end
	add(GN.text("gn_settings_section"), nil, T.HUD_HEAD, true)
	add(GN.text("gn_tool_keys_hint"), nil, T.HUD_HEAD, false)
	add(GN.text("gn_tool_keys_hint2"), nil, T.HUD_HEAD, false)
	if tool.action == "home" then
		local n = GN.getNeighbour(tool.nid)
		local act, req = T.counts(tool.nid)
		local cur, sizes = T.currentSize(tool)
		add(n ~= nil and n.name or "?", nil, { 1, 1, 1 }, true)
		add(GN.text("gn_tool_place_size"), nil, { 1, 1, 1 }, false)
		for _, s in ipairs(sizes) do
			local txt, col = status(act[s] or 0, req[s] or 0)
			add((s == cur and "> " or "   ") .. GN.text("gn_size_" .. s), txt, col, s == cur, true)
		end
	elseif tool.action == "remove" then
		add(GN.text("gn_tool_remove_hint"), nil, { 1, 1, 1 }, true)
	else
		local c = 0
		for _, p in ipairs(GN.Client.places or {}) do
			if p.type == tool.place then
				c = c + 1
			end
		end
		if tool.place == "myfarm" then
			c = 0
			for _, p in ipairs(GN.Client.places or {}) do
				if p.type == "myfarm" and p.farmId == GN.getLocalFarmId() then
					c = c + 1
				end
			end
		end
		local txt, col = status(c, GN.Auto.PLACE_MIN[tool.place] or 1)
		add(GN.text("gn_place_" .. tool.place, tool.place), txt, col, true)
	end
	-- overall
	add(GN.text("gn_tool_overall"), nil, T.HUD_HEAD, true)
	for _, n in ipairs(GN.neighbours) do
		local act, req = T.counts(n.id)
		local a, r, ok = 0, 0, true
		for _, s in ipairs(T.SIZES) do
			a = a + math.min(act[s] or 0, req[s] or 0)
			r = r + (req[s] or 0)
			if (act[s] or 0) < (req[s] or 0) then
				ok = false
			end
		end
		add(n.name, string.format("%d/%d  %s", a, r, ok and GN.text("gn_tool_complete") or GN.text("gn_tool_missing")),
			ok and T.HUD_MET or T.HUD_BELOW, false, true)
	end
	local byType = {}
	for _, p in ipairs(GN.Client.places or {}) do
		byType[p.type] = (byType[p.type] or 0) + 1
	end
	for _, t in ipairs(GN.Server.PLACE_TYPES) do
		local c = byType[t] or 0
		local m = GN.Auto.PLACE_MIN[t] or 1
		add(GN.text("gn_place_" .. t, t), string.format("%d/%d", c, m), c >= m and T.HUD_MET or T.HUD_BELOW, false, true)
	end
	if T.flashText ~= nil and (g_time or 0) < (T.flashUntil or 0) then
		add(T.flashText, nil, { 1, 0.85, 0.3 }, true)
	end
	return rows
end

function T.drawPanel(tool)
	local rows = T.buildPanel(tool)
	local size = getCorrectTextSize(0.0115)
	local lineH = size * 1.32
	local w = 0.25
	local padX = 0.008
	local h = #rows * lineH + 0.016
	local x = 0.995 - w
	local y = 0.105
	if drawFilledRect ~= nil then
		drawFilledRect(x, y, w, h, 0, 0, 0, 0.72)
	end
	local ty = y + h - 0.008 - size
	for _, r in ipairs(rows) do
		local c = r.color or { 1, 1, 1 }
		setTextBold(r.bold == true)
		setTextColor(c[1], c[2], c[3], 1)
		setTextAlignment(RenderText.ALIGN_LEFT)
		local tx = x + padX + (r.indent and 0.008 or 0)
		local text = r.text
		local maxW = w - padX * 2 - (r.right ~= nil and 0.07 or 0)
		if getTextWidth(size, text) > maxW then
			while #text > 3 and getTextWidth(size, text .. "...") > maxW do
				text = string.sub(text, 1, #text - 1)
			end
			text = text .. "..."
		end
		renderText(tx, ty, size, text)
		if r.right ~= nil then
			setTextAlignment(RenderText.ALIGN_RIGHT)
			renderText(x + w - padX, ty, size, r.right)
		end
		ty = ty - lineH
	end
	setTextBold(false)
	setTextAlignment(RenderText.ALIGN_LEFT)
	setTextColor(1, 1, 1, 1)
end

function T.draw()
	local tool = T.selected()
	if tool == nil then
		return
	end
	if T.lastDraw == g_time then
		return -- already drawn this frame
	end
	T.lastDraw = g_time
	T.drawIcons(tool)
	T.drawPanel(tool)
end
