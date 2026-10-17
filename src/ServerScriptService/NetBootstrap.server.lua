local ReplicatedStorage = game:GetService("ReplicatedStorage")

local netRoot = ReplicatedStorage:WaitForChild("Net")
local module = netRoot:WaitForChild("Server"):WaitForChild("Server")

local ok, err = pcall(require, module)

if not ok then
	warn("[Net] server module failed to load: " .. tostring(err))
end
