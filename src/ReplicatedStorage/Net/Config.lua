--[[
	Net.Config
	Everything the framework needs to know about your remotes. This is the only
	file a game has to edit to declare a new remote.

	An argument spec is either a bare type name ("number") or a table with
	optional bounds:

		{ Type = "string", MaxLength = 20 }
		{ Type = "number", Min = 0, Max = 1000 }

	Bounds are enforced on the server, which is the only place they mean
	anything. Anything a client checks can be skipped by editing the client.
]]

local Config = {
	-- Folder under ReplicatedStorage.Net that holds the generated remotes.
	RemoteFolderName = "Remotes",

	-- Applied to any remote that does not declare its own Limit.
	DefaultLimit = { Burst = 10, Refill = 5 },

	-- Outgoing client limiter. Deliberately looser than the server's: it exists
	-- to surface accidental spam in game code, not to enforce anything.
	ClientLimit = { Burst = 20, Refill = 10 },

	-- Seconds Client:Invoke waits for the server before returning "timeout".
	InvokeTimeout = 5,

	-- How many rejected calls the log keeps in memory.
	LogCapacity = 100,

	Remotes = {
		AddGold = {
			Kind = "Fire",
			Args = {
				{ Name = "Amount", Type = "number", Min = 1, Max = 1000 },
			},
		},

		SetDisplayName = {
			Kind = "Fire",
			Args = {
				{ Name = "Name", Type = "string", MaxLength = 20 },
			},
			Limit = { Burst = 2, Refill = 1 },
		},

		GetRank = {
			Kind = "Invoke",
			Args = {},
			Returns = { "number" },
			Limit = { Burst = 5, Refill = 2 },
		},
	},
}

return Config
