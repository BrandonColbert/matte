--- Function helper
local funhel = {}
funhel.__index = funhel

--- Returns the table of named parameters followed by each positional parameter
--- @param t table consisting of positional and named entries
--- @return table, ...
function funhel:decompose(t)
	local positional, named = {}, {}

	for k, v in pairs(t) do
		if type(k) == "number" then
			positional[k] = v
		else
			named[k] = v
		end
	end

	return named, table.unpack(positional)
end

return funhel