--[[
	Net.Client
	Thin client API:

		Net:Fire("AddGold", 25)
		local ok, rank = Net:Invoke("GetRank")

	Outgoing calls are limited locally, but only to surface accidental spam in
	game code early. None of it is a security boundary - a client that wants to
	send a million calls will send a million calls, and only the server side of
	this framework can actually refuse them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetRoot = script.Parent.Parent

local Config = require(NetRoot:WaitForChild("Config"))
local RateLimiter = require(NetRoot:WaitForChild("RateLimiter"))

local Client = {}

local remotes = NetRoot:WaitForChild(Config.RemoteFolderName)
local fireRemote = remotes:WaitForChild("NetFire")
local invokeRemote = remotes:WaitForChild("NetInvoke")

local limiter = RateLimiter.new(Config.ClientLimit.Burst, Config.ClientLimit.Refill)

function Client:Fire(name, ...)
	if not limiter:Take() then
		warn(("[Net] client rate limit hit on %q - is something calling it in a loop?"):format(tostring(name)))
		return false
	end

	fireRemote:FireServer(name, ...)
	return true
end

function Client:Invoke(name, timeout, ...)
	timeout = timeout or Config.InvokeTimeout

	if not limiter:Take() then
		return false, "client-rate-limited"
	end

	local args = table.pack(...)
	local signal = Instance.new("BindableEvent")
	local done = false
	local success, payload

	task.spawn(function()
		success, payload = pcall(invokeRemote.InvokeServer, invokeRemote, name, table.unpack(args, 1, args.n))
		done = true

		if signal then
			pcall(function()
				signal:Fire()
			end)
		end
	end)

	local finished = signal.Event:Wait(timeout)
	local completed = done

	signal:Destroy()
	signal = nil

	if not finished or not completed then
		return false, "timeout"
	end

	return success, payload
end

return Client
