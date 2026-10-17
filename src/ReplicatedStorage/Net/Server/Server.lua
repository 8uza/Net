--[[
	Net.Server
	Owns the generated remotes and adapts them onto a Router. Game code only ever
	touches this module:

		local Net = require(ReplicatedStorage.Net.Server.Server)
		Net:Handle("AddGold", function(player, amount)
			-- server side truth, the client only ever suggested a number
		end)
]]

local Players = game:GetService("Players")

local NetRoot = script.Parent.Parent

local Config = require(NetRoot:WaitForChild("Config"))
local Log = require(NetRoot:WaitForChild("Log"))
local Router = require(NetRoot:WaitForChild("Router"))

local Server = {}

local function ensureRemotes()
	local folder = NetRoot:FindFirstChild(Config.RemoteFolderName)

	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = Config.RemoteFolderName
		folder.Parent = NetRoot
	end

	local fire = folder:FindFirstChild("NetFire")

	if fire == nil then
		fire = Instance.new("RemoteEvent")
		fire.Name = "NetFire"
		fire.Parent = folder
	end

	local invoke = folder:FindFirstChild("NetInvoke")

	if invoke == nil then
		invoke = Instance.new("RemoteFunction")
		invoke.Name = "NetInvoke"
		invoke.Parent = folder
	end

	return fire, invoke
end

local router = Router.new(Config)

Log.SetCapacity(Config.LogCapacity)

local fireRemote, invokeRemote = ensureRemotes()

fireRemote.OnServerEvent:Connect(function(player, name, ...)
	router:Dispatch(player, name, table.pack(...), nil, "Fire")
end)

invokeRemote.OnServerInvoke = function(player, name, ...)
	local ok, payload = router:Dispatch(player, name, table.pack(...), nil, "Invoke")

	if not ok then
		return false, payload
	end

	local returnsOk, returnsReason = router:CheckReturns(name, payload)

	if not returnsOk then
		Log.Record({
			Remote = name,
			Reason = "bad-returns",
			Detail = returnsReason,
			UserId = player.UserId,
			PlayerName = player.Name,
		})
	end

	return true, table.unpack(payload, 1, payload.n)
end

Players.PlayerRemoving:Connect(function(player)
	router:Forget(player)
end)

function Server:Handle(name, handler)
	return router:Handle(name, handler)
end

function Server:Router()
	return router
end

return Server
