# Net — a secure remote layer for Roblox

A drop-in replacement for hand-rolled `RemoteEvent` wiring. Declare your remotes
once with a type schema, and every call gets validated, rate limited and logged
on the server before your handler ever sees it.

```lua
-- server
local Net = require(ReplicatedStorage.Net.Server.Server)
Net:Handle("AddGold", function(player, amount)
	print(player.Name, "asked for", amount, "gold")
end)

-- client
local Net = require(ReplicatedStorage.Net.Client.Client)
Net:Fire("AddGold", 25)
local ok, rank = Net:Invoke("GetRank")
```

## Why

A `RemoteEvent` has no idea what it is supposed to carry. `AddGold` and `SetName`
are both "RemoteEvent, FireServer, some numbers", and nothing stops a client
firing either one a thousand times a second with `math.huge` where a small
integer was expected. The usual result is a handler that trusts its arguments
and a leaderboard full of NaN.

This puts a schema and a rate limit in between, on the server, where they can
actually be enforced.

## What it does

- **Declared schemas.** Every remote declares its arguments as types, with
  optional `Min` / `Max` / `MaxLength`. Validated server-side before dispatch.
- **Token bucket rate limiting.** Per player *and* per remote, so one chatty
  remote cannot starve the others, and one player cannot exhaust the budget for
  everyone else.
- **`Fire` and `Invoke`.** Fire is one-way. Invoke returns a value with a
  configurable timeout, so a server handler that forgets to return cannot hang
  the calling thread forever.
- **Rejection log.** Unknown remotes, bad arguments, rate limited calls and
  throwing handlers are all recorded with a reason, in a bounded ring buffer.
- **Error isolation.** A handler that throws is caught, logged, and does not take
  down the connection or the other remotes.
- **Non-destructive.** Rejections never partially apply: argument validation runs
  before the handler, not after.

## Install

Copy these into your place, keeping the exact paths — the modules `WaitForChild`
on each other.

| From                                              | To                                                     |
| ------------------------------------------------- | ------------------------------------------------------ |
| `src/ReplicatedStorage/Net/Config.lua`            | `ReplicatedStorage > Net > Config` (ModuleScript)      |
| `src/ReplicatedStorage/Net/Schema.lua`            | `ReplicatedStorage > Net > Schema` (ModuleScript)      |
| `src/ReplicatedStorage/Net/RateLimiter.lua`       | `ReplicatedStorage > Net > RateLimiter` (ModuleScript) |
| `src/ReplicatedStorage/Net/Log.lua`               | `ReplicatedStorage > Net > Log` (ModuleScript)         |
| `src/ReplicatedStorage/Net/Router.lua`            | `ReplicatedStorage > Net > Router` (ModuleScript)      |
| `src/ReplicatedStorage/Net/Server/Server.lua`     | `ReplicatedStorage > Net > Server > Server` (ModuleScript) |
| `src/ReplicatedStorage/Net/Client/Client.lua`     | `ReplicatedStorage > Net > Client > Client` (ModuleScript) |
| `src/ReplicatedStorage/Net/Tests/TestKit.lua`     | `ReplicatedStorage > Net > Tests > TestKit` (ModuleScript) |
| `src/ReplicatedStorage/Net/Tests/RateLimiter.spec.lua` | `ReplicatedStorage > Net > Tests > RateLimiter.spec` (ModuleScript) |
| `src/ReplicatedStorage/Net/Tests/Schema.spec.lua` | `ReplicatedStorage > Net > Tests > Schema.spec` (ModuleScript) |
| `src/ReplicatedStorage/Net/Tests/Router.spec.lua` | `ReplicatedStorage > Net > Tests > Router.spec` (ModuleScript) |
| `src/ServerScriptService/NetBootstrap.server.lua` | `ServerScriptService > NetBootstrap` (Script)          |
| `src/StarterPlayer/StarterPlayerScripts/NetBootstrap.client.lua` | `StarterPlayer > StarterPlayerScripts > NetBootstrap` (LocalScript) |
| `src/StarterPlayer/StarterPlayerScripts/NetTests.client.lua` | `StarterPlayer > StarterPlayerScripts > NetTests` (LocalScript) |

The spec files are named `RateLimiter.spec` in Studio but end in `.spec.lua` on
disk so editors highlight them as Lua. Rename them on import.

You do not have to create the `Remotes` folder or the two remotes inside it —
`Server.lua` creates them on boot. You will see `ReplicatedStorage > Net >
Remotes > NetFire` / `NetInvoke` appear when the server starts.

## Usage

Declare a remote in `Config.lua`:

```lua
Remotes = {
	BuyItem = {
		Kind = "Fire",
		Args = {
			{ Name = "ItemId", Type = "string", MaxLength = 32 },
			{ Name = "Quantity", Type = "number", Min = 1, Max = 99 },
		},
		Limit = { Burst = 3, Refill = 1 },
	},

	GetBalance = {
		Kind = "Invoke",
		Args = {},
		Returns = { "number" },
	},
}
```

Then register a server handler and call from the client:

```lua
Net:Handle("BuyItem", function(player, itemId, quantity)
	-- quantity is guaranteed to be a number in [1, 99] here
end)

Net:Handle("GetBalance", function(player)
	return 100
end)
```

```lua
Net:Fire("BuyItem", "sword_01", 2)

local ok, balance = Net:Invoke("GetBalance", 2)
if not ok then
	warn("failed: " .. tostring(balance))
end
```

### Types and bounds

| Spec                                | Accepts                        |
| ----------------------------------- | ------------------------------ |
| `"string"`                           | any string                     |
| `{ Type = "string", MaxLength = 20 }` | string up to 20 characters     |
| `"number"`                           | any finite number              |
| `{ Type = "number", Min = 0, Max = 100 }` | number in range          |
| `"boolean"` / `"table"`              | matching type                  |

`NaN` and `math.huge` are rejected as `"number"`. That is deliberate: `NaN` is the
classic way to permanently corrupt a stored currency value, since every later
comparison against it is false.

### Rejection reasons

`Log.Recent()` returns entries with a `Reason` of:

| Reason            | Meaning                                                |
| ----------------- | ------------------------------------------------------ |
| `unknown-remote`  | name is not in the schema                              |
| `wrong-kind`      | `Fire` used on an `Invoke` remote, or the reverse       |
| `rate-limited`    | the player's bucket for that remote was empty          |
| `expected-*`      | argument type mismatch                                 |
| `arg*-too-long` / `arg*-below-min` / `arg*-above-max` | bound violation      |
| `expected-N-args` | wrong number of arguments                              |
| `no-handler`      | declared in Config but no `Handle` call on the server  |
| `handler-error`   | the handler threw; the message is in `Detail`          |
| `schema-error`    | the spec itself is malformed                           |

```lua
local Log = require(ReplicatedStorage.Net.Log)

for _, entry in Log.Recent(10) do
	print(entry.PlayerName, entry.Remote, entry.Reason)
end
```

## Config reference

| Setting            | Default | Meaning                                                       |
| ------------------ | ------- | ------------------------------------------------------------- |
| `RemoteFolderName` | `Remotes` | folder the generated remotes live in                       |
| `DefaultLimit`     | `{ Burst = 10, Refill = 5 }` | used by any remote without its own `Limit` |
| `ClientLimit`      | `{ Burst = 20, Refill = 10 }` | outgoing client limiter                       |
| `InvokeTimeout`    | `5`     | seconds before `Invoke` gives up                             |
| `LogCapacity`      | `100`   | rejections kept in memory                                    |

`Burst` is how many calls are allowed back to back; `Refill` is how many per
second the bucket recovers.

## Tests

Press **Play** and read the Output window:

```
[Net] running test suite
  ok   RateLimiter > allows a full burst at t=0
  ...
[Net] 29 passed, 0 failed
[Net] all 29 tests passed
```

`Router` takes a plain table as the player and knows nothing about remotes or
Roblox services, so the whole decision layer is testable without a server, a
client, or a running place.

## What this does not do

Being straight about the limits, since a framework like this invites
over-trusting:

- **The client-side limiter is not security.** `ClientLimit` only catches
  accidental spam in your own game code. A real attacker edits the client and
  removes it. Only the server side can refuse anything.
- **It does not make handlers safe.** It validates *shape*. If
  `Net:Handle("BuyItem")` grants an item based on a client-supplied price, the
  exploit is in your handler, not in the transport. Keep authoritative values on
  the server.
- **No cross-server rate limiting.** Buckets live in one server's memory and
  reset when it closes. Someone who can leave and rejoin resets their budget.
- **The log is in-memory only.** It is lost when the server closes, and it is a
  debugging aid, not an audit trail. Pipe it somewhere durable if you need one.
- **`Log` is a shared singleton.** Fine for a single Router, but two independent
  routers would write to the same buffer.
- **Not battle-tested at scale.** Session locking, teleport handoff and shutdown
  ordering — the things that actually bite in production — are not handled here.

## License

[MIT](LICENSE) — free to use, modify, redistribute and sell, including as part of
a paid package or game. The only requirements are that the copyright notice
stays with copies of the code, and that the software is provided without
warranty.

Change the name in `LICENSE` before publishing if it should not be yours.