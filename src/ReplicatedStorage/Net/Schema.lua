--[[
	Net.Schema
	Argument validation. Pure functions, no side effects, no Roblox services, so
	it can be unit tested directly and reused anywhere.
]]

local Schema = {}

local CHECKS = {
	string = function(value)
		return type(value) == "string"
	end,

	number = function(value)
		if type(value) ~= "number" then
			return false
		end
		-- NaN fails every comparison including itself, and infinity is a fine
		-- value to send right before someone's currency becomes NaN.
		return value == value and value > -math.huge and value < math.huge
	end,

	boolean = function(value)
		return type(value) == "boolean"
	end,

	table = function(value)
		return type(value) == "table"
	end,
}

function Schema.Normalize(arg)
	if type(arg) == "string" then
		return { Type = arg }
	end
	return arg
end

function Schema.CheckValue(arg, value)
	local spec = Schema.Normalize(arg)

	if type(spec) ~= "table" or type(spec.Type) ~= "string" then
		return false, "malformed-spec"
	end

	local check = CHECKS[spec.Type]

	if check == nil then
		return false, "unknown-type"
	end

	if not check(value) then
		return false, "expected-" .. spec.Type
	end

	if spec.Type == "string" and spec.MaxLength and #value > spec.MaxLength then
		return false, "too-long"
	end

	if spec.Type == "number" then
		if spec.Min and value < spec.Min then
			return false, "below-min"
		end
		if spec.Max and value > spec.Max then
			return false, "above-max"
		end
	end

	return true
end

function Schema.CheckArgs(specs, packed)
	local count = #specs

	if packed.n ~= count then
		return false, ("expected-%d-args"):format(count)
	end

	for index = 1, count do
		local ok, reason = Schema.CheckValue(specs[index], packed[index])

		if not ok then
			return false, ("arg%d-%s"):format(index, reason)
		end
	end

	return true
end

function Schema.CheckReturns(specs, packed)
	local returns = specs or {}

	if packed.n ~= #returns then
		return false, ("expected-%d-returns"):format(#returns)
	end

	for index = 1, #returns do
		local ok, reason = Schema.CheckValue(returns[index], packed[index])

		if not ok then
			return false, ("return%d-%s"):format(index, reason)
		end
	end

	return true
end

return Schema
