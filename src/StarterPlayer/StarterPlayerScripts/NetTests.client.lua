local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tests = ReplicatedStorage:WaitForChild("Net"):WaitForChild("Tests")
local TestKit = require(tests:WaitForChild("TestKit"))

local specs = {
	require(tests:WaitForChild("RateLimiter.spec")),
	require(tests:WaitForChild("Schema.spec")),
	require(tests:WaitForChild("Router.spec")),
}

local passed, failed = TestKit.run(specs)

if failed > 0 then
	warn(("[Net] %d test(s) failed"):format(failed))
else
	print(("[Net] all %d tests passed"):format(passed))
end
