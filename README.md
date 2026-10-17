# Net

Remotes without the ceremony.

You normally make a `RemoteEvent`, drop it in `ReplicatedStorage`, then
`WaitForChild` it from every script that needs it. Net replaces that with one
table. You declare your remotes, and then call them by name:

```lua
-- server
local Net = require(ReplicatedStorage.Net.Server.Server)

Net:Handle("AddGold", function(player, amount)
	print(player.Name, "asked for", amount, "gold")
end)
```

```lua
-- client
local Net = require(ReplicatedStorage.Net.Client.Client)

Net:Fire("AddGold", 25)
local ok, rank = Net:Invoke("GetRank")
```

The win isn't shorter call sites. It's that every remote's arguments are
described in one place and checked on the server before your handler runs, so
nobody has to remember to validate.

## Install

There's no Rojo file in here, so copy things by hand. The paths matter, the
modules `WaitForChild` on each other.

```
src/ReplicatedStorage/Net/          ->  ReplicatedStorage > Net
src/ServerScriptService/            ->  ServerScriptService
src/StarterPlayer/                  ->  StarterPlayer > StarterPlayerScripts
```

That covers everything:

| File | Goes in | Type |
| --- | --- | --- |
| `Net/Config.lua` | `ReplicatedStorage > Net` | ModuleScript |
| `Net/Schema.lua` | `ReplicatedStorage > Net` | ModuleScript |
| `Net/RateLimiter.lua` | `ReplicatedStorage > Net` | ModuleScript |
| `Net/Log.lua` | `ReplicatedStorage > Net` | ModuleScript |
| `Net/Router.lua` | `ReplicatedStorage > Net` | ModuleScript |
| `Net/Server/Server.lua` | `ReplicatedStorage > Net > Server` | ModuleScript |
| `Net/Client/Client.lua` | `ReplicatedStorage > Net > Client` | ModuleScript |
| `Net/Tests/TestKit.lua` | `ReplicatedStorage > Net > Tests` | ModuleScript |
| `Net/Tests/*.spec.lua` | `ReplicatedStorage > Net > Tests` | ModuleScript |
| `NetBootstrap.server.lua` | `ServerScriptService` | Script |
| `NetBootstrap.client.lua` | `StarterPlayerScripts` | LocalScript |
| `NetTests.client.lua` | `StarterPlayerScripts` | LocalScript |

Press play afterwards. You should see `29 passed, 0 failed`, and a
`Net > Remotes` folder appear with `NetFire` and `NetInvoke` in it. Net creates
those two for you, you don't add them yourself.

## Declaring remotes

Everything lives in `Net/Config.lua`:

```lua
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
```

`Fire` is one way. `Invoke` sends back a value, and gives up after
`Config.InvokeTimeout` seconds instead of hanging forever if the server never
replies.

Arg specs take `Type` plus whatever bounds apply to it: `Min` and `Max` for
numbers, `MaxLength` for strings. A bare `"number"` is shorthand when you don't
need bounds.

`Limit` is a token bucket. `Burst` is how many calls back to back, `Refill` is
how many per second after that. Remotes without one use `Config.DefaultLimit`.

## When a call gets rejected

Rejections come back as a reason string you can log, and land in `Net.Log`:

```lua
local Log = require(ReplicatedStorage.Net.Log)

for _, entry in Log.Recent(10) do
	print(entry.PlayerName, entry.Remote, entry.Reason)
end
```

| Reason | |
| --- | --- |
| `unknown-remote` | not in the config |
| `wrong-kind` | `Fire` on an `Invoke` remote |
| `rate-limited` | out of tokens for that player |
| `expected-*` | argument was the wrong type |
| `arg*-too-long` | over `MaxLength` |
| `arg*-below-min` / `arg*-above-max` | out of bounds |
| `expected-N-args` | wrong number of arguments |
| `no-handler` | declared but you never called `Handle` |
| `handler-error` | your handler threw, message is in `Detail` |
| `bad-returns` | handler returned the wrong shape |

`NaN` and `math.huge` both fail as `number`. Worth knowing before you find out
the hard way, since a single `NaN` in a stored value makes every later
comparison against it false.

The log is capped at `Config.LogCapacity` entries and holds argument *counts*,
never argument values. Payloads on this path come from people actively trying
to break something, so there's no reason to keep them.

## Tests

`NetTests.client.lua` picks up every ModuleScript in `Net/Tests` and runs it, so
you can add a spec file and forget about it. Output looks like:

```
[Net] running test suite (3 spec files)
  ok   RateLimiter > allows a full burst at t=0
  ...
[Net] 29 passed, 0 failed
```

No TestEZ, no install, just press play.

## Where it stops

Worth being clear about these, since a framework like this is easy to
over-trust:

- **The client-side limiter is not security.** `ClientLimit` exists to catch
  `Fire` inside a `while true` in your own code. Someone attacking you edits
  the client and deletes it. Only the server side refuses anything.
- **Schema checks are shape, not meaning.** Net knows `Amount` is a number
  between 1 and 1000. It has no idea whether the player earned it. If your
  handler grants an item based on a price the client sent, that exploit is in
  your handler.
- **Limits are per session.** Buckets live in one server's memory. Leaving and
  rejoining resets them, so it's not a substitute for anything that needs to
  survive a rejoin.
- **`Log` is a shared singleton.** Fine for one Router, two would write to the
  same buffer.
- **`Handle` will happily overwrite.** Registering the same remote name twice
  is silent, last one wins.
- **Not tested at scale.** Session locking, teleport handoff and shutdown
  ordering aren't handled here.

## Tests vs reality

The unit tests pass plain tables where the game passes real `Player` objects,
and nothing in them crosses a network boundary. That gap is real: two bugs got
past all 29 of them, a `type(player) == "table"` check that never matched a
`Player` (that's an Instance, `type` returns `"Instance"`), and an `Invoke` that
dropped the server's return value on the floor. Both showed up the first time
something was actually run. Worth assuming your integration bugs are still out
there.

## License

MIT, see [LICENSE](LICENSE). Use it, sell it, change it, just leave the notice.

You can copy this into a place and use it without Net being published at all.
If you want a Rojo file, the tree in `src/` maps to the DataModel directly.