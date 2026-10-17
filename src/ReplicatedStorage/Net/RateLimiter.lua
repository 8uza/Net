--[[
	Net.RateLimiter
	Token bucket.

	Take() accepts an explicit timestamp so the bucket is fully deterministic and
	testable without sleeping. Pass nil to use os.clock().
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(burst, refillPerSecond)
	assert(type(burst) == "number" and burst > 0, "burst must be a positive number")
	assert(type(refillPerSecond) == "number" and refillPerSecond > 0, "refill must be a positive number")

	return setmetatable({
		capacity = burst,
		rate = refillPerSecond,
		tokens = burst,
		stamp = 0,
	}, RateLimiter)
end

function RateLimiter:Take(now)
	now = now or os.clock()

	local elapsed = now - self.stamp

	if elapsed > 0 then
		self.stamp = now
		self.tokens = math.min(self.capacity, self.tokens + elapsed * self.rate)
	end

	if self.tokens < 1 then
		return false
	end

	self.tokens -= 1
	return true
end

function RateLimiter:Available(now)
	now = now or os.clock()
	return math.min(self.capacity, self.tokens + math.max(0, now - self.stamp) * self.rate)
end

return RateLimiter
