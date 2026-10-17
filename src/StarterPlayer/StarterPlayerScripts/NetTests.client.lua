local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tests = ReplicatedStorage:WaitForChild("Net"):WaitForChild("Tests")
local kitInstance = tests:WaitForChild("TestKit")
local TestKit = require(kitInstance)

local specs = {}

for _, child in ipairs(tests:GetChildren()) do
	if child:IsA("ModuleScript") and child ~= kitInstance then
		table.insert(specs, { name = child.Name, run = require(child) })
	end
end

table.sort(specs, function(a, b)
	return a.name < b.name
end)

for index, spec in ipairs(specs) do
	specs[index] = spec.run
end

local passed, failed = TestKit.run(specs)

if failed > 0 then
	warn(("[Net] %d test(s) failed"):format(failed))
else
	print(("[Net] all %d tests passed"):format(passed))
end
