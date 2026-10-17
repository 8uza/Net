local Log = require(script.Parent.Parent:WaitForChild("Log"))
local Router = require(script.Parent.Parent:WaitForChild("Router"))

local function makeRouter()
	return Router.new({
		DefaultLimit = { Burst = 2, Refill = 1 },

		Remotes = {
			Ping = { Kind = "Fire", Args = {} },
			AddGold = {
				Kind = "Invoke",
				Args = { { Type = "number", Min = 0, Max = 100 } },
				Returns = { "number" },
			},
		},
	})
end

local ALICE = { UserId = 1, Name = "Alice" }
local BOB = { UserId = 2, Name = "Bob" }

return function(T)
	T.describe("Router dispatch", function()
		T.it("rejects an undeclared remote", function()
			local router = makeRouter()

			local ok, reason = router:Dispatch(ALICE, "NotAThing", table.pack(), 0, "Fire")
			T.expectFalse(ok)
			T.expectEqual(reason, "unknown-remote")
		end)

		T.it("rejects a remote used as the wrong kind", function()
			local router = makeRouter()
			router:Handle("Ping", function() end)

			local ok, reason = router:Dispatch(ALICE, "Ping", table.pack(), 0, "Invoke")
			T.expectFalse(ok)
			T.expectEqual(reason, "wrong-kind")
		end)

		T.it("passes validated arguments to the handler", function()
			local router = makeRouter()
			local received

			router:Handle("AddGold", function(player, amount)
				received = { player = player, amount = amount }
				return amount * 2
			end)

			local ok, results = router:Dispatch(ALICE, "AddGold", table.pack(25), 0, "Invoke")

			T.expectTrue(ok)
			T.expectEqual(received.amount, 25)
			T.expectEqual(received.player, ALICE)
			T.expectEqual(results[1], 50)
		end)

		T.it("rejects out of range arguments before the handler runs", function()
			local router = makeRouter()
			local ran = false

			router:Handle("AddGold", function()
				ran = true
			end)

			local ok, reason = router:Dispatch(ALICE, "AddGold", table.pack(5000), 0, "Invoke")

			T.expectFalse(ok)
			T.expectEqual(reason, "arg1-above-max")
			T.expectFalse(ran, "handler must not run")
		end)

		T.it("rejects a missing handler", function()
			local router = makeRouter()

			local ok, reason = router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire")
			T.expectFalse(ok)
			T.expectEqual(reason, "no-handler")
		end)

		T.it("isolates a throwing handler", function()
			local router = makeRouter()

			router:Handle("Ping", function()
				error("boom")
			end)

			router:Handle("AddGold", function()
				return 1
			end)

			local ok, reason = router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire")

			T.expectFalse(ok)
			T.expectEqual(reason, "handler-error")

			local stillOk, results = router:Dispatch(BOB, "AddGold", table.pack(1), 0, "Invoke")
			T.expectTrue(stillOk, "one bad handler must not poison the router")
			T.expectEqual(results[1], 1)
		end)

		T.it("validates handler return values", function()
			local router = makeRouter()

			router:Handle("AddGold", function()
				return "not a number"
			end)

			local _, results = router:Dispatch(ALICE, "AddGold", table.pack(1), 0, "Invoke")
			local ok, reason = router:CheckReturns("AddGold", results)

			T.expectFalse(ok)
			T.expectEqual(reason, "return1-expected-number")
		end)
	end)

	T.describe("Router rate limiting", function()
		T.it("limits each player independently", function()
			local router = makeRouter()
			router:Handle("Ping", function() end)

			T.expectTrue(router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire"))
			T.expectTrue(router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire"))
			T.expectFalse(router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire"))

			T.expectTrue(router:Dispatch(BOB, "Ping", table.pack(), 0, "Fire"), "Alice must not spend Bob's budget")
		end)

		T.it("limits each remote independently", function()
			local router = makeRouter()
			router:Handle("Ping", function() end)
			router:Handle("AddGold", function() end)

			T.expectTrue(router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire"))
			T.expectTrue(router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire"))
			T.expectFalse(router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire"))

			T.expectTrue(router:Dispatch(ALICE, "AddGold", table.pack(1), 0, "Invoke"), "separate bucket per remote")
		end)

		T.it("recovers as the bucket refills", function()
			local router = makeRouter()
			router:Handle("Ping", function() end)

			router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire")
			router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire")
			T.expectFalse(router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire"))

			T.expectTrue(router:Dispatch(ALICE, "Ping", table.pack(), 1, "Fire"), "one second later")
		end)

		T.it("clears per player state on Forget", function()
			local router = makeRouter()
			router:Handle("Ping", function() end)

			router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire")
			router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire")
			T.expectFalse(router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire"))

			router:Forget(ALICE)

			T.expectTrue(router:Dispatch(ALICE, "Ping", table.pack(), 0, "Fire"), "fresh bucket after Forget")
		end)
	end)

	T.describe("Router logging", function()
		T.it("records every rejection without storing arguments", function()
			local router = makeRouter()
			local before = Log.Total

			router:Dispatch(ALICE, "NotAThing", table.pack("secret", 1), 0, "Fire")

			T.expectEqual(Log.Total, before + 1)

			local recent = Log.Recent(1)
			local entry = recent[1]

			T.expectEqual(entry.Remote, "NotAThing")
			T.expectEqual(entry.Reason, "unknown-remote")
			T.expectEqual(entry.UserId, ALICE.UserId)
			T.expectEqual(entry.ArgCount, 2)
			T.expectNil(entry.Args, "argument values are never logged")
		end)

		T.it("counts rejections per player", function()
			Log.Clear()

			local router = makeRouter()
			router:Dispatch(ALICE, "NotAThing", table.pack(), 0, "Fire")
			router:Dispatch(ALICE, "NotAThing", table.pack(), 0, "Fire")
			router:Dispatch(BOB, "NotAThing", table.pack(), 0, "Fire")

			T.expectEqual(Log.CountFor(ALICE.UserId), 2)
			T.expectEqual(Log.CountFor(BOB.UserId), 1)

			Log.Clear()
		end)
	end)
end
