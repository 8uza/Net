--[[
	Net.Log
	Fixed size ring buffer of rejected calls.

	Argument values are deliberately never stored. The payloads here come from
	clients that are actively trying to break things, and logging them wholesale
	is how a log turns into an unbounded sink (or into the vulnerability itself).
	Argument counts are enough to debug a rejection.
]]

local Log = {}

Log.Capacity = 100
Log.Entries = {}
Log.Total = 0

function Log.SetCapacity(capacity)
	Log.Capacity = math.max(1, capacity)

	while #Log.Entries > Log.Capacity do
		table.remove(Log.Entries, 1)
	end
end

function Log.Record(entry)
	Log.Total += 1
	entry.Time = entry.Time or os.time()

	Log.Entries[#Log.Entries + 1] = entry

	while #Log.Entries > Log.Capacity do
		table.remove(Log.Entries, 1)
	end

	return entry
end

function Log.Recent(count)
	count = count or #Log.Entries

	local out = {}
	local first = math.max(1, #Log.Entries - count + 1)

	for index = first, #Log.Entries do
		out[#out + 1] = Log.Entries[index]
	end

	return out
end

function Log.CountFor(userId)
	local total = 0

	for _, entry in Log.Entries do
		if entry.UserId == userId then
			total += 1
		end
	end

	return total
end

function Log.Clear()
	table.clear(Log.Entries)
	Log.Total = 0
end

return Log
