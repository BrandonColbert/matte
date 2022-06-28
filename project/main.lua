local Descent = require "descent"
local Escape = require "utils.escape"
local list = require "utils.list"

-- Acquire command line arguments
local options = list(arg):reduce(function(o, entry)
	-- Key only argument
	local key = entry:match("^-(%w+)$")

	if key then
		o[key] = true
	else
		-- Key-value argument
		local key, value = entry:match("^-(%w+)=(.*)$")

		if key and value then
			o[key] = value
		else
			print(string.format("Unrecognized parameter: '%s'", arg[i]))
		end
	end

	return o
end, {})

local src, result

-- Get input
if options.src then
	src = Escape.cli(options.src or "")
elseif options.input then
	local f = assert(io.open(options.input, "r"))
	src = f:read("*all")
	f:close()
else
	error("No source provided.")
end

-- Enter mode
if options.parse then
	result = Descent.parse(src, options.entry)
elseif options.transpile then
	result = Descent.transpile(src)
elseif options.run then
	return Descent.run(src, table.unpack(options.args or {}))
else -- Show help if no valid modes were specified
	local clip = {
		{"parse <src|input> [output] [entry]", "Enter parser mode."},
		{"transpile <src|input> [output]", "Enter transpilation mode."},
		{"run <src|input> [args]", "Enter execution mode."},
		{"src=<val>", "Source to operate on."},
		{"input=<val>", "Path to the file containing the source."},
		{"output=<val>", "Path to save the result to."},
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

-- Handle output
if options.output then
	local f = assert(io.open(options.output, "w"))
	f:write(tostring(result))
	f:close()
else
	print(result)
end