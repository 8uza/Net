--[[
	Net.Tests.TestKit
	Minimal describe/it test harness.

	Deliberately dependency free: the whole suite runs by pressing Play in Studio
	with nothing installed. If this ever needs to move to a real runner, only the
	spec files change - they already describe themselves as functions taking this
	table.
]]

local TestKit = {}

local state

function TestKit.reset()
	state = { passed = 0, failed = 0, failures = {}, suite = "?" }
end

function TestKit.describe(name, body)
	local previous = state.suite
	state.suite = name

	local ok, err = pcall(body)

	if not ok then
		TestKit.fail(("  FAIL %s (suite body threw) -> %s"):format(name, tostring(err)))
	end

	state.suite = previous
end

function TestKit.fail(message)
	state.failed += 1
	table.insert(state.failures, message)
	print("  FAIL " .. message)
end

function TestKit.it(name, body)
	local label = ("%s > %s"):format(state.suite, name)

	local ok, err = pcall(body)

	if ok then
		state.passed += 1
		print("  ok   " .. label)
	else
		TestKit.fail(("%s -> %s"):format(label, tostring(err)))
	end
end

local function describeValue(value)
	if type(value) == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

function TestKit.expectEqual(actual, expected, message)
	if actual ~= expected then
		error(
			("%s: expected %s, got %s"):format(message or "values differ", describeValue(expected), describeValue(actual)),
			2
		)
	end
end

function TestKit.expectTrue(value, message)
	if value ~= true then
		error(("%s: expected true, got %s"):format(message or "expected true", describeValue(value)), 2)
	end
end

function TestKit.expectFalse(value, message)
	if value ~= false then
		error(("%s: expected false, got %s"):format(message or "expected false", describeValue(value)), 2)
	end
end

function TestKit.expectNil(value, message)
	if value ~= nil then
		error(("%s: expected nil, got %s"):format(message or "expected nil", describeValue(value)), 2)
	end
end

function TestKit.expectError(body, message)
	local ok = pcall(body)

	if ok then
		error(("%s: expected the call to throw"):format(message or "expected an error"), 2)
	end
end

function TestKit.run(specs)
	TestKit.reset()

	print(("[Net] running test suite (%d spec files)"):format(#specs))

	for _, spec in ipairs(specs) do
		local ok, err = pcall(spec, TestKit)

		if not ok then
			TestKit.fail(("spec file threw: %s"):format(tostring(err)))
		end
	end

	print(("[Net] %d passed, %d failed"):format(state.passed, state.failed))

	return state.passed, state.failed
end

return TestKit
