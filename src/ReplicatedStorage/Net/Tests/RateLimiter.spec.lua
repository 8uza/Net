local RateLimiter = require(script.Parent.Parent:WaitForChild("RateLimiter"))

return function(T)
	T.describe("RateLimiter", function()
		T.it("allows a full burst at t=0", function()
			local limiter = RateLimiter.new(3, 1)

			T.expectTrue(limiter:Take(0))
			T.expectTrue(limiter:Take(0))
			T.expectTrue(limiter:Take(0))
			T.expectFalse(limiter:Take(0), "fourth call in the same instant")
		end)

		T.it("refills in proportion to elapsed time", function()
			local limiter = RateLimiter.new(2, 1)

			limiter:Take(0)
			limiter:Take(0)
			T.expectFalse(limiter:Take(0))

			T.expectTrue(limiter:Take(1), "one second at 1/s earns one token")
		end)

		T.it("refills fractionally", function()
			local limiter = RateLimiter.new(1, 10)

			T.expectTrue(limiter:Take(0))
			T.expectFalse(limiter:Take(0))

			T.expectFalse(limiter:Take(0.05), "half a token is not a token")
			T.expectTrue(limiter:Take(0.1))
		end)

		T.it("never refills past capacity", function()
			local limiter = RateLimiter.new(2, 100)

			T.expectTrue(limiter:Take(0))
			T.expectTrue(limiter:Take(0))
			T.expectFalse(limiter:Take(0))

			T.expectTrue(limiter:Take(5), "five seconds at 100/s, capped at 2")
			T.expectTrue(limiter:Take(5))
			T.expectFalse(limiter:Take(5))
		end)

		T.it("ignores time going backwards", function()
			local limiter = RateLimiter.new(2, 1)

			limiter:Take(10)
			limiter:Take(10)
			T.expectFalse(limiter:Take(5), "a stale timestamp must not refill")
		end)

		T.it("refuses a non positive configuration", function()
			T.expectError(function()
				RateLimiter.new(0, 1)
			end, "zero burst")

			T.expectError(function()
				RateLimiter.new(1, 0)
			end, "zero refill")
		end)
	end)
end
