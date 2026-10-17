--[[
	Net.Router
	The decision layer: schema lookup, rate limiting, validation and handler
	dispatch.

	It knows nothing about RemoteEvent, RemoteFunction or Player objects - it
	takes whatever is passed as a player and keys off it. That is what makes it
	testable: the server script is a thin adapter on top of this.
]]

local Log = require(script.Parent.Log)
local RateLimiter = require(script.Parent.RateLimiter)
local Schema = require(script.Parent.Schema)

local Router = {}
Router.__index = Router

local function playerKey(player)
	if type(player) == "table" then
		return player.UserId or player.Name or tostring(player)
	end
	return tostring(player)
end

function Router.new(config)
	return setmetatable({
		config = config,
		handlers = {},
		limiters = {},
		log = Log,
	}, Router)
end

function Router:Handle(name, handler)
	assert(type(name) == "string", "remote name must be a string")
	assert(type(handler) == "function", "handler must be a function")

	self.handlers[name] = handler
	return self
end

function Router:GetLimiter(player, name, spec)
	local key = playerKey(player)
	local store = self.limiters[key]

	if store == nil then
		store = {}
		self.limiters[key] = store
	end

	local limiter = store[name]

	if limiter == nil then
		local limit = spec.Limit or self.config.DefaultLimit
		limiter = RateLimiter.new(limit.Burst or 10, limit.Refill or 5)
		store[name] = limiter
	end

	return limiter
end

function Router:Forget(player)
	self.limiters[playerKey(player)] = nil
end

function Router:reject(player, name, reason, packed, detail)
	return self.log.Record({
		Remote = name,
		Reason = reason,
		Detail = detail,
		UserId = type(player) == "table" and player.UserId or nil,
		PlayerName = type(player) == "table" and player.Name or nil,
		ArgCount = packed and packed.n or 0,
	})
end

function Router:Dispatch(player, name, packed, now, expectedKind)
	local spec = self.config.Remotes[name]

	if spec == nil then
		self:reject(player, name, "unknown-remote", packed)
		return false, "unknown-remote"
	end

	if expectedKind ~= nil and (spec.Kind or "Fire") ~= expectedKind then
		self:reject(player, name, "wrong-kind", packed)
		return false, "wrong-kind"
	end

	local limiter = self:GetLimiter(player, name, spec)

	if not limiter:Take(now) then
		self:reject(player, name, "rate-limited", packed)
		return false, "rate-limited"
	end

	local success, valid, reason = pcall(Schema.CheckArgs, spec.Args or {}, packed)

	if not success then
		self:reject(player, name, "schema-error", packed)
		return false, "schema-error"
	end

	if not valid then
		self:reject(player, name, reason, packed)
		return false, reason
	end

	local handler = self.handlers[name]

	if handler == nil then
		self:reject(player, name, "no-handler", packed)
		return false, "no-handler"
	end

	local results = table.pack(pcall(handler, player, table.unpack(packed, 1, packed.n)))

	if not results[1] then
		self:reject(player, name, "handler-error", packed, tostring(results[2]))
		return false, "handler-error"
	end

	return true, table.pack(table.unpack(results, 2, results.n))
end

function Router:CheckReturns(name, results)
	local spec = self.config.Remotes[name]

	if spec == nil then
		return false
	end

	return Schema.CheckReturns(spec.Returns, results)
end

return Router
