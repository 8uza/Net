local Schema = require(script.Parent.Parent:WaitForChild("Schema"))

return function(T)
	T.describe("Schema.CheckValue", function()
		T.it("accepts matching primitives", function()
			T.expectTrue(Schema.CheckValue("string", "hello"))
			T.expectTrue(Schema.CheckValue("number", 12.5))
			T.expectTrue(Schema.CheckValue("boolean", false))
			T.expectTrue(Schema.CheckValue("table", {}))
		end)

		T.it("rejects mismatched types", function()
			local _, reason = Schema.CheckValue("string", 5)
			T.expectEqual(reason, "expected-string")

			local _, boolReason = Schema.CheckValue("boolean", "true")
			T.expectEqual(boolReason, "expected-boolean")
		end)

		T.it("rejects NaN", function()
			local nan = 0 / 0
			local ok, reason = Schema.CheckValue("number", nan)

			T.expectFalse(ok)
			T.expectEqual(reason, "expected-number")
		end)

		T.it("rejects infinity", function()
			local ok, reason = Schema.CheckValue("number", math.huge)
			T.expectFalse(ok)
			T.expectEqual(reason, "expected-number")
		end)

		T.it("enforces numeric bounds", function()
			local spec = { Type = "number", Min = 1, Max = 10 }

			T.expectTrue(Schema.CheckValue(spec, 1))
			T.expectTrue(Schema.CheckValue(spec, 10))

			local _, lowReason = Schema.CheckValue(spec, 0)
			T.expectEqual(lowReason, "below-min")

			local _, highReason = Schema.CheckValue(spec, 11)
			T.expectEqual(highReason, "above-max")
		end)

		T.it("enforces string length", function()
			local spec = { Type = "string", MaxLength = 3 }

			T.expectTrue(Schema.CheckValue(spec, "abc"))

			local _, reason = Schema.CheckValue(spec, "abcd")
			T.expectEqual(reason, "too-long")
		end)

		T.it("rejects unknown and malformed specs", function()
			local _, unknownReason = Schema.CheckValue("function", print)
			T.expectEqual(unknownReason, "unknown-type")

			local _, malformedReason = Schema.CheckValue(42, "hello")
			T.expectEqual(malformedReason, "malformed-spec")
		end)
	end)

	T.describe("Schema.CheckArgs", function()
		T.it("accepts an exact match", function()
			local ok, reason = Schema.CheckArgs({ "number", "string" }, table.pack(1, "a"))

			T.expectTrue(ok)
			T.expectNil(reason)
		end)

		T.it("rejects a wrong argument count", function()
			local ok, reason = Schema.CheckArgs({ "number", "string" }, table.pack(1))
			T.expectFalse(ok)
			T.expectEqual(reason, "expected-2-args")

			local tooManyOk, tooManyReason = Schema.CheckArgs({ "number" }, table.pack(1, 2))
			T.expectFalse(tooManyOk)
			T.expectEqual(tooManyReason, "expected-1-args")
		end)

		T.it("names the offending argument", function()
			local _, reason = Schema.CheckArgs({ "number", "string" }, table.pack(1, 2))
			T.expectEqual(reason, "arg2-expected-string")
		end)
	end)
end
