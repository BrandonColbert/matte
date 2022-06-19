local Descent = require "src.descent"
local list = require "src.utils.list"

-- Acquire command line arguments
local options = list(arg):reduce(function(o, entry)
	-- Key only argument
	local key = entry:match("^-(%w+)$")

	if key then
		o[key] = true
	else
		-- Key-value argument
		local key, value = entry:match("^-(%w+)=(.+)$")

		if key and value then
			o[key] = value
		else
			print(string.format("Unrecognized parameter: '%s'", arg[i]))
		end
	end

	return o
end, {})

-- Get source code with correct formatting
local src = (options["src"] or "")
	:gsub("\\r\\n", "\n")
	:gsub("\\n", "\n")
	:gsub("\\t", "\t")

if options["parse"] then
	local entry = options["entry"]
	local result = Descent.parse(src, entry)

	print(result)
elseif options["transpile"] then
	local result = Descent.transpile(src)

	print(result)
elseif options["run"] then
	local args = options["args"] or {}

	return Descent.run(src, table.unpack(args))
else -- Show help if no valid modes were specified
	local clip = {
		{"parse <src> [entry]", "Enter parser mode."},
		{"transpile <src>", "Enter transpilation mode."},
		{"run <src> [args]", "Enter execution mode."},
		{"src=<val>", "Source code to operate on."},
		{"entry=<val>", "Rule to use as an entry point when parsing."},
		{"args=<val>", "Command line arguments when running."}
	}

	local width = math.max(
		list(clip)
			:map(function(item)
				return #item[1]
			end)
			:unpack()
	)

	for i = 1, #clip do
		local name, desc = table.unpack(clip[i])
		print(string.format("-%-" .. tostring(width) .. "s\t%s", name, desc))
	end
end