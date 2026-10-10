-- Good Neighbours (FS25) - face to face conversations
-- data/conversations/n<id>.xml: conversations per neighbour, picked by what he is doing right now
-- (his day plan), the relationship level and the season. Answers change the relationship.
-- Author: billiD

local GN = GoodNeighbours

GNTalkDialog = {}
local GNTalkDialog_mt = Class(GNTalkDialog, DialogElement)

GN.Talk = GN.Talk or {}
local T = GN.Talk

T.GUI_NAME = "GNTalkDialog"
T.SEEN_KEEP = 60

-- ---------------------------------------------------------------------------
-- Loading the conversations
-- ---------------------------------------------------------------------------

--- Language of the game (the mod's own l10n file says which one is loaded; FS25 has no g_languageShortName).
local function lang()
	local l = nil
	if g_i18n ~= nil and g_i18n.hasText ~= nil and g_i18n:hasText("gn_lang_code") then
		l = g_i18n:getText("gn_lang_code")
	end
	l = l or g_languageShort or g_languageShortName or "en"
	l = string.lower(tostring(l))
	if l ~= "pl" and l ~= "de" then
		l = "en"
	end
	return l
end
T.lang = lang

local function readText(xml, key)
	local l = lang()
	return getXMLString(xml, key .. "#" .. l) or getXMLString(xml, key .. "#en") or ""
end

--- Elements in order: { t = "npc"|"player", text } / { t = "choices", list = { { text, points, items } } }
local function readItems(xml, key, depth)
	local items = {}
	if depth > 5 then
		return items
	end
	local i = 0
	while true do
		local ik = string.format("%s.item(%d)", key, i)
		if not hasXMLProperty(xml, ik) then
			break
		end
		local t = getXMLString(xml, ik .. "#t") or "npc"
		if t == "choices" then
			local list = {}
			local j = 0
			while true do
				local chk = string.format("%s.choice(%d)", ik, j)
				if not hasXMLProperty(xml, chk) then
					break
				end
				table.insert(list, { text = readText(xml, chk), points = getXMLInt(xml, chk .. "#points") or 0, items = readItems(xml, chk, depth + 1) })
				j = j + 1
			end
			if #list > 0 then
				table.insert(items, { t = "choices", list = list })
			end
		else
			table.insert(items, { t = t == "player" and "player" or "npc", text = readText(xml, ik) })
		end
		i = i + 1
	end
	return items
end

function T.load()
	if T.loaded then
		return
	end
	T.loaded = true
	T.byNid = {}
	local total = 0
	for _, n in ipairs(GN.neighbours) do
		local list = {}
		for _, suffix in ipairs({ "", "_b", "_c" }) do
		local path = Utils.getFilename(string.format("data/conversations/n%d%s.xml", n.id, suffix), GN.dir)
		if fileExists(path) then
			local xml = loadXMLFile("gnTalk", path)
			if xml ~= nil and xml ~= 0 then
				local i = 0
				while true do
					local k = string.format("conversations.conversation(%d)", i)
					if not hasXMLProperty(xml, k) then
						break
					end
					table.insert(list, {
						id = getXMLString(xml, k .. "#id") or ("c" .. suffix .. i),
						situation = getXMLString(xml, k .. "#situation") or "any",
						minLevel = getXMLInt(xml, k .. "#minLevel") or 1,
						maxLevel = (getXMLInt(xml, k .. "#maxLevel") or 99) >= 10 and 99 or getXMLInt(xml, k .. "#maxLevel"),
						season = getXMLString(xml, k .. "#season"),
						items = readItems(xml, k, 1),
					})
					i = i + 1
				end
				delete(xml)
			end
		end
		end
		T.byNid[n.id] = list
		total = total + #list
	end
	GN.log("conversations loaded: %d", total)
end

-- ---------------------------------------------------------------------------
-- Picking a conversation
-- ---------------------------------------------------------------------------

function T.season()
	local env = g_currentMission ~= nil and g_currentMission.environment or nil
	local p = env ~= nil and env.currentPeriod or nil
	if p == nil then
		return nil
	end
	-- periods 1..12, 1 = early spring
	return ({ "spring", "spring", "spring", "summer", "summer", "summer", "autumn", "autumn", "autumn", "winter", "winter", "winter" })[p]
end

--- What the neighbour is doing right now as a conversation situation key.
function T.situationOf(nid)
	local cur = GN.Plan.current(nid)
	if cur == nil then
		return "any"
	end
	if cur.place ~= nil and GN.Plan.position(nid, GN.Client.places) ~= nil then
		return cur.place
	end
	return cur.key or "any"
end

local function isSeen(id)
	for _, s in ipairs(GN.Client.personal.seen or {}) do
		if s == id then
			return true
		end
	end
	return false
end

local function markSeen(id)
	local p = GN.Client.personal
	p.seen = p.seen or {}
	for i = #p.seen, 1, -1 do
		if p.seen[i] == id then
			table.remove(p.seen, i)
		end
	end
	table.insert(p.seen, id)
	while #p.seen > T.SEEN_KEEP do
		table.remove(p.seen, 1)
	end
	GN.Client.savePersonal()
end

function T.pick(nid)
	T.load()
	local list = T.byNid[nid] or {}
	local r = GN.Client.rel[nid]
	local level = r ~= nil and r.level or 1
	local sit, season = T.situationOf(nid), T.season()
	local function fits(c)
		return level >= c.minLevel and level <= c.maxLevel and (c.season == nil or c.season == season)
	end
	-- best: this situation and not heard yet; then any situation not heard; then anything that fits
	local groups = { {}, {}, {}, {} }
	for _, c in ipairs(list) do
		if fits(c) then
			local seen = isSeen(c.id)
			if c.situation == sit then
				table.insert(groups[seen and 3 or 1], c)
			elseif c.situation == "any" then
				table.insert(groups[seen and 4 or 2], c)
			end
		end
	end
	for _, g in ipairs(groups) do
		if #g > 0 then
			-- the oldest heard first when all were heard: prefer the one earliest in the seen list
			return g[math.random(1, #g)], sit
		end
	end
	return nil, sit
end

-- ---------------------------------------------------------------------------
-- Running a conversation
-- ---------------------------------------------------------------------------

local function playerName()
	local name = nil
	if g_currentMission ~= nil then
		name = g_currentMission.playerNickname
		if (name == nil or name == "") and g_currentMission.userManager ~= nil and g_currentMission.playerUserId ~= nil then
			local ok, u = GN.try(g_currentMission.userManager.getUserByUserId, g_currentMission.userManager, g_currentMission.playerUserId)
			if ok and u ~= nil and u.getNickname ~= nil then
				name = u:getNickname()
			end
		end
	end
	if (name == nil or name == "") and g_localPlayer ~= nil and g_localPlayer.getNickname ~= nil then
		local ok, nn = GN.try(g_localPlayer.getNickname, g_localPlayer)
		if ok then
			name = nn
		end
	end
	if name == nil or name == "" then
		name = GN.text("gn_talk_you", "neighbour")
	end
	return name
end

function T.format(text)
	return (string.gsub(text or "", "{player}", playerName()))
end

--- Start talking with a neighbour (on foot, next to him).
function T.start(nid)
	local n = GN.getNeighbour(nid)
	if n == nil or not T.ensureLoaded() then
		return
	end
	local conv, sit = T.pick(nid)
	T.state = { nid = nid, conv = conv, situation = sit, points = 0, stack = {}, finished = false, sent = false }
	if conv ~= nil then
		table.insert(T.state.stack, { items = conv.items, i = 1 })
		markSeen(conv.id)
	end
	if T.dialog ~= nil and T.dialog.isOpen then
		T.dialog:begin()
	else
		g_gui:showDialog(T.GUI_NAME)
	end
end

--- Next element of the conversation (nil at the end); moves the cursor.
function T.nextItem()
	local st = T.state
	while st ~= nil and #st.stack > 0 do
		local top = st.stack[#st.stack]
		if top.i <= #top.items then
			local it = top.items[top.i]
			top.i = top.i + 1
			return it
		end
		table.remove(st.stack)
	end
	return nil
end

--- Next element without moving the cursor.
function T.peekItem()
	local st = T.state
	if st == nil then
		return nil
	end
	for k = #st.stack, 1, -1 do
		local top = st.stack[k]
		if top.i <= #top.items then
			return top.items[top.i]
		end
	end
	return nil
end

--- An answer was picked: a good or a bad sound (the points come at the end of the conversation).
function T.onChoicePoints(nid, points)
	if points > 0 then
		GN.Client.playTone("sounds/success.ogg")
	elseif points < 0 then
		GN.Client.playTone("sounds/failed.ogg")
	end
end

--- The server's answer after the conversation: relationship points (once a day per neighbour).
function T.onResult(data)
	local n = GN.getNeighbour(tonumber(data.nid))
	local name = n ~= nil and n.name or "?"
	if data.already then
		GN.Client.notify(string.format(GN.text("gn_talk_points_today"), name))
		return
	end
	local pts = tonumber(data.points) or 0
	if pts >= 0 then
		GN.Client.playTone("sounds/success.ogg")
		GN.Client.notify(string.format(GN.text("gn_talk_points_plus"), name, pts), "ok")
	else
		GN.Client.playTone("sounds/failed.ogg")
		GN.Client.notify(string.format(GN.text("gn_talk_points_minus"), name, -pts), "bad")
	end
	if T.dialog ~= nil and T.dialog.isOpen and T.dialog.showPoints ~= nil then
		GN.try(T.dialog.showPoints, T.dialog, pts)
	end
end

--- The conversation is over: the server counts the talk itself once a day per farm and neighbour.
function T.finish()
	local st = T.state
	if st == nil or st.sent then
		return
	end
	st.sent = true
	if st.conv ~= nil then
		GN.sendToServer("talkDone", { nid = st.nid, points = st.points, max = st.maxPoints or 0, min = st.minPoints or 0, id = st.conv.id })
	else
		GN.sendToServer("talkDone", { nid = st.nid, points = 0 })
	end
end

function T.ensureLoaded()
	if g_gui == nil then
		return false
	end
	if g_gui.guis ~= nil and g_gui.guis[T.GUI_NAME] ~= nil then
		return true
	end
	GN.Phone.registerTextures()
	T.dialog = GNTalkDialog.new(g_gui)
	g_gui:loadGui(Utils.getFilename("gui/GNTalkDialog.xml", GN.dir), T.GUI_NAME, T.dialog)
	return g_gui.guis ~= nil and g_gui.guis[T.GUI_NAME] ~= nil
end

function T.close()
	if g_gui ~= nil and g_gui.closeDialogByName ~= nil then
		g_gui:closeDialogByName(T.GUI_NAME)
	elseif T.dialog ~= nil and T.dialog.close ~= nil then
		GN.try(T.dialog.close, T.dialog)
	end
end

function T.isOpen()
	return T.dialog ~= nil and T.dialog.isOpen == true
end

-- ---------------------------------------------------------------------------
-- The dialog
-- ---------------------------------------------------------------------------

function GNTalkDialog.new(target, customMt)
	local self = DialogElement.new(target, customMt or GNTalkDialog_mt)
	self.buttons = {}
	return self
end

function GNTalkDialog:onOpen()
	GNTalkDialog:superClass().onOpen(self)
	self:begin()
end

function GNTalkDialog:onClose()
	T.finish()
	GNTalkDialog:superClass().onClose(self)
end

function GNTalkDialog:onClickBack()
	T.close()
	return false
end

function GNTalkDialog:showPortrait(nid)
	for i = 1, 7 do
		local p = self["portrait" .. i]
		if p ~= nil then
			p:setVisible(i == nid)
		end
	end
end

function GNTalkDialog:begin()
	local st = T.state
	if st == nil then
		return
	end
	local n = GN.getNeighbour(st.nid)
	self:showPortrait(st.nid)
	self.nameText:setText(n ~= nil and n.name or "?")
	local r = GN.Client.rel[st.nid]
	local cur = GN.Plan.current(st.nid)
	local doing = cur ~= nil and GN.text("gn_plan_" .. tostring(cur.key), cur.key) or ""
	if cur ~= nil and cur.place ~= nil and st.situation == cur.place then
		doing = doing .. " (" .. GN.text("gn_place_" .. cur.place, cur.place) .. ")"
	end
	self.baseInfo = string.format(GN.text("gn_talk_info"), r ~= nil and r.level or 1, doing)
	self.infoText:setText(self.baseInfo)
	GN.try(function()
		if self.infoText.textColor ~= nil and self.infoText.setTextColor ~= nil then
			self.origInfoColor = self.origInfoColor or { self.infoText.textColor[1], self.infoText.textColor[2], self.infoText.textColor[3], self.infoText.textColor[4] }
			self.infoText:setTextColor(self.origInfoColor[1], self.origInfoColor[2], self.origInfoColor[3], self.origInfoColor[4])
		end
	end)
	if st.conv == nil then
		self:say(T.format(GN.text("gn_talk_fallback_" .. tostring((st.nid % 3) + 1))))
		self:showEndMenu()
		return
	end
	self:advance()
end

--- The answer changed the relationship: shown next to the level (green / red).
function GNTalkDialog:showPoints(points)
	local txt = string.format(points > 0 and GN.text("gn_talk_points_short_plus") or GN.text("gn_talk_points_short_minus"), math.abs(points))
	self.infoText:setText((self.baseInfo or "") .. "   " .. txt)
	if self.infoText.setTextColor ~= nil then
		if points > 0 then
			self.infoText:setTextColor(0.45, 0.95, 0.45, 1)
		else
			self.infoText:setTextColor(1, 0.4, 0.35, 1)
		end
	end
end

function GNTalkDialog:say(text)
	self.npcText:setText(text)
end

--- Set the buttons: list of { text, fn }.
function GNTalkDialog:setButtons(list)
	self.buttonActions = {}
	for i = 1, 3 do
		local b = self["choice" .. i]
		local e = list[i]
		if b ~= nil then
			if e ~= nil then
				b:setText(e.text)
				b:setVisible(true)
				b:setDisabled(false)
				self.buttonActions[i] = e.fn
			else
				b:setVisible(false)
			end
		end
	end
	if FocusManager ~= nil and self.choice1 ~= nil and self.choice1:getIsVisible() then
		GN.try(FocusManager.setFocus, FocusManager, self.choice1)
	end
end

--- Run elements until something needs the player: shows the npc line and the buttons for what comes next.
function GNTalkDialog:advance()
	local it = T.nextItem()
	while it ~= nil and it.t ~= "npc" do
		-- a player line or choices without an npc line before: show them under the last text
		if it.t == "player" or it.t == "choices" then
			self:offer(it)
			return
		end
		it = T.nextItem()
	end
	if it == nil then
		self:showEndMenu()
		return
	end
	self:say(T.format(it.text))
	local nxt = T.peekItem()
	if nxt == nil then
		T.state.finished = true
		T.finish()
		self:showEndMenu()
	elseif nxt.t == "npc" then
		self:setButtons({ { text = GN.text("gn_talk_continue"), fn = function() self:advance() end } })
	else
		T.nextItem()
		self:offer(nxt)
	end
end

function GNTalkDialog:offer(it)
	if it.t == "player" then
		self:setButtons({ { text = T.format(it.text), fn = function() self:advance() end } })
		return
	end
	local buttons = {}
	local best, worst = nil, nil
	for _, c in ipairs(it.list) do
		best = math.max(best or -99, c.points or 0)
		worst = math.min(worst or 99, c.points or 0)
	end
	T.state.maxPoints = (T.state.maxPoints or 0) + (best or 0)
	T.state.minPoints = (T.state.minPoints or 0) + (worst or 0)
	for _, c in ipairs(it.list) do
		table.insert(buttons, { text = T.format(c.text), fn = function()
			T.state.points = T.state.points + (c.points or 0)
			T.onChoicePoints(T.state.nid, c.points or 0)
			table.insert(T.state.stack, { items = c.items, i = 1 })
			self:advance()
		end })
	end
	self:setButtons(buttons)
end

--- After the conversation: what he does today, his phone contact, goodbye.
function GNTalkDialog:showEndMenu()
	local nid = T.state ~= nil and T.state.nid or nil
	self:setButtons({
		{ text = GN.text("gn_talk_ask_plan"), fn = function()
			local cur = GN.Plan.current(nid)
			local ws = GN.Client.workStart ~= nil and GN.Client.workStart[nid] or nil
			local text = GN.Plan.format(nid)
			if ws ~= nil and GN.getNeighbour(nid) ~= nil and GN.getNeighbour(nid).contracts then
				text = string.format(GN.text("gn_talk_work_start"), GN.formatClock(ws)) .. "\n" .. text
			end
			self:say(text)
			self:showEndMenu()
		end },
		{ text = GN.text("gn_talk_open_contact"), fn = function()
			T.close()
			GN.Phone.openContact(nid, false)
		end },
		{ text = GN.text("gn_talk_bye"), fn = function() T.close() end },
	})
end

function GNTalkDialog:runButton(i)
	local fn = self.buttonActions ~= nil and self.buttonActions[i] or nil
	if fn ~= nil then
		GN.safeCall("conversation", fn)
	end
end

function GNTalkDialog:onClickChoice1() self:runButton(1) end
function GNTalkDialog:onClickChoice2() self:runButton(2) end
function GNTalkDialog:onClickChoice3() self:runButton(3) end
function GNTalkDialog:onClickClose() T.close() end
