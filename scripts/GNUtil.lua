-- Good Neighbours (FS25) - helpers: logging, roles, players, table serializer
-- Author: billiD

GoodNeighbours = GoodNeighbours or {}
local GN = GoodNeighbours

GN.LOG_PREFIX = "[GoodNeighbours] "

local unpackArgs = unpack or table.unpack

local function packArgs(...)
	return { n = select("#", ...), ... }
end

--- Errors caught by GN.try are written to the log (never hidden), at most once a minute per error.
GN._tryErrors = GN._tryErrors or {}
function GN.tryError(err)
	local key = tostring(err)
	local now = (g_time or 0) / 1000
	local last = GN._tryErrors[key]
	if last == nil or now - last > 60 then
		GN._tryErrors[key] = now
		print(GN.LOG_PREFIX .. "caught error: " .. key)
	end
	return err
end

--- Protected call that logs the error: returns ok, results... like a protected call of Lua.
function GN.try(fn, ...)
	local args = packArgs(...)
	local r = packArgs(xpcall(function()
		return fn(unpackArgs(args, 1, args.n))
	end, GN.tryError))
	return unpackArgs(r, 1, r.n)
end

function GN.log(fmt, ...)
	local ok, msg = GN.try(string.format, tostring(fmt), ...)
	print(GN.LOG_PREFIX .. (ok and msg or tostring(fmt)))
end

GN._logOnce = GN._logOnce or {}
--- Log at most once per `key` every `seconds` of real time.
function GN.logThrottled(key, seconds, fmt, ...)
	local now = (g_time or 0) / 1000
	local last = GN._logOnce[key]
	if last ~= nil and now - last < (seconds or 60) then
		return
	end
	GN._logOnce[key] = now
	GN.log(fmt, ...)
end

function GN.safeCall(label, fn, ...)
	if fn == nil then
		return false
	end
	local ok, a, b, c = GN.try(fn, ...)
	if not ok then
		GN.logThrottled("err|" .. tostring(label), 30, "error in %s: %s", tostring(label), tostring(a))
		return false
	end
	return true, a, b, c
end

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------

function GN.isServer()
	return g_server ~= nil
end

--- True when this machine shows the game to a player (singleplayer, host or client; not a dedicated server).
function GN.hasUI()
	return g_client ~= nil and g_dedicatedServer == nil and g_dedicatedServerInfo == nil
end

function GN.isMultiplayer()
	return g_currentMission ~= nil and g_currentMission.missionDynamicInfo ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer == true
end

function GN.isPlayerFarm(farmId)
	farmId = tonumber(farmId)
	if farmId == nil or farmId <= 0 then
		return false
	end
	if FarmManager ~= nil and FarmManager.SPECTATOR_FARM_ID ~= nil and farmId == FarmManager.SPECTATOR_FARM_ID then
		return false
	end
	if GN.Work ~= nil and farmId == GN.Work.NPC_FARM_ID then
		return false -- the neighbours' own farm
	end
	if g_farmManager ~= nil and g_farmManager.getFarmById ~= nil then
		return g_farmManager:getFarmById(farmId) ~= nil
	end
	return true
end

--- Farm of the local player (client side).
function GN.getLocalFarmId()
	if g_localPlayer ~= nil and g_localPlayer.farmId ~= nil then
		return g_localPlayer.farmId
	end
	if g_currentMission ~= nil and g_currentMission.getFarmId ~= nil then
		local ok, f = GN.try(g_currentMission.getFarmId, g_currentMission)
		if ok then
			return f
		end
	end
	return nil
end

function GN.isLocalAdmin()
	if not GN.isMultiplayer() then
		return true
	end
	if g_server ~= nil then
		return true -- host
	end
	return g_currentMission ~= nil and g_currentMission.isMasterUser == true
end

--- Server: all player objects in the game.
function GN.getPlayers()
	local out = {}
	local ps = g_currentMission ~= nil and g_currentMission.playerSystem or nil
	if ps ~= nil and type(ps.players) == "table" then
		for _, p in pairs(ps.players) do
			if p ~= nil then
				table.insert(out, p)
			end
		end
	end
	if #out == 0 and g_localPlayer ~= nil then
		table.insert(out, g_localPlayer)
	end
	return out
end

GN.LOCAL = "local" -- pseudo connection for the host's / singleplayer's own player

--- Server: connections (or GN.LOCAL) of the players of a farm that are ready to receive events.
function GN.getFarmConnections(farmId)
	local out, seen = {}, {}
	for _, p in ipairs(GN.getPlayers()) do
		if p.farmId == farmId then
			local c
			if p == g_localPlayer and GN.hasUI() then
				c = GN.LOCAL
			elseif p.connection ~= nil and p.connection.gnReady == true then
				c = p.connection
			end
			if c ~= nil and not seen[c] then
				seen[c] = true
				table.insert(out, c)
			end
		end
	end
	return out
end

--- Server: player farms with at least one player online.
function GN.getOnlineFarms()
	local farms, seen = {}, {}
	for _, p in ipairs(GN.getPlayers()) do
		local f = p.farmId
		if GN.isPlayerFarm(f) and not seen[f] then
			seen[f] = true
			table.insert(farms, f)
		end
	end
	table.sort(farms)
	return farms
end

function GN.isConnectionAdmin(connection)
	if connection == nil or connection == GN.LOCAL then
		return true
	end
	local um = g_currentMission ~= nil and g_currentMission.userManager or nil
	if um == nil or um.getUserByConnection == nil then
		return false
	end
	local ok, user = GN.try(um.getUserByConnection, um, connection)
	if not ok or user == nil or user.getIsMasterUser == nil then
		return false
	end
	local okM, isMaster = GN.try(user.getIsMasterUser, user)
	return okM and isMaster == true
end

--- Server: farm of the player behind a connection.
function GN.getConnectionFarmId(connection)
	if connection == nil or connection == GN.LOCAL then
		return GN.getLocalFarmId()
	end
	for _, p in ipairs(GN.getPlayers()) do
		if p.connection == connection then
			return p.farmId
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------

function GN.text(key, fallback)
	if g_i18n ~= nil and key ~= nil and g_i18n:hasText(key) then
		return g_i18n:getText(key)
	end
	return fallback or tostring(key)
end

function GN.formatMoney(v)
	v = math.floor((tonumber(v) or 0) + 0.5)
	if g_i18n ~= nil and g_i18n.formatMoney ~= nil then
		local ok, s = GN.try(g_i18n.formatMoney, g_i18n, v, 0, true, true)
		if ok and s ~= nil then
			return s
		end
	end
	return tostring(v)
end

-- ---------------------------------------------------------------------------
-- Serializer: plain Lua tables (string/number/boolean keys and values) <-> string
-- No code is ever executed when reading.
-- ---------------------------------------------------------------------------

local function encodeValue(v, out)
	local t = type(v)
	if t == "string" then
		table.insert(out, "s" .. #v .. ":" .. v)
	elseif t == "number" then
		local s = tostring(v)
		table.insert(out, "n" .. #s .. ":" .. s)
	elseif t == "boolean" then
		table.insert(out, v and "T" or "F")
	elseif t == "table" then
		table.insert(out, "{")
		for k, val in pairs(v) do
			local kt = type(k)
			local vt = type(val)
			if (kt == "string" or kt == "number") and (vt == "string" or vt == "number" or vt == "boolean" or vt == "table") then
				encodeValue(k, out)
				encodeValue(val, out)
			end
		end
		table.insert(out, "}")
	else
		table.insert(out, "N")
	end
end

function GN.encode(v)
	local out = {}
	encodeValue(v, out)
	return table.concat(out)
end

local function decodeValue(s, i, depth)
	if depth > 20 then
		error("too deep")
	end
	local c = string.sub(s, i, i)
	if c == "s" or c == "n" then
		local colon = string.find(s, ":", i, true)
		local len = tonumber(string.sub(s, i + 1, colon - 1))
		if len == nil or len < 0 then
			error("bad length")
		end
		local str = string.sub(s, colon + 1, colon + len)
		if c == "n" then
			return tonumber(str) or 0, colon + len + 1
		end
		return str, colon + len + 1
	elseif c == "T" then
		return true, i + 1
	elseif c == "F" then
		return false, i + 1
	elseif c == "N" then
		return nil, i + 1
	elseif c == "{" then
		local tbl = {}
		i = i + 1
		while string.sub(s, i, i) ~= "}" do
			if i > #s then
				error("unterminated table")
			end
			local k, v
			k, i = decodeValue(s, i, depth + 1)
			v, i = decodeValue(s, i, depth + 1)
			if k ~= nil then
				tbl[k] = v
			end
		end
		return tbl, i + 1
	end
	error("bad token '" .. tostring(c) .. "' at " .. tostring(i))
end

function GN.decode(s)
	if type(s) ~= "string" or s == "" then
		return nil
	end
	local ok, v = GN.try(decodeValue, s, 1, 0)
	if ok then
		return v
	end
	GN.log("could not read a network message: %s", tostring(v))
	return nil
end

-- ---------------------------------------------------------------------------
-- Time
-- ---------------------------------------------------------------------------

function GN.getDay()
	local env = g_currentMission ~= nil and g_currentMission.environment or nil
	if env == nil then
		return 0
	end
	return tonumber(env.currentMonotonicDay) or tonumber(env.currentDay) or 0
end

--- Minutes since midnight of the in-game clock.
function GN.getDayMinutes()
	local env = g_currentMission ~= nil and g_currentMission.environment or nil
	if env == nil then
		return 0
	end
	if env.dayTime ~= nil then
		return math.floor(env.dayTime / 60000)
	end
	return (tonumber(env.currentHour) or 0) * 60 + (tonumber(env.currentMinute) or 0)
end

function GN.formatClock(minutes)
	minutes = math.floor(tonumber(minutes) or 0)
	return string.format("%02d:%02d", math.floor(minutes / 60) % 24, minutes % 60)
end
