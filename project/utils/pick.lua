--- Returns the value at the key in the table or the default if no value exists
--- @param key string Table key
--- @param table table Nullable table potentially containing the key-value pair
--- @param default? T
--- @return T
function pick(key, table, default)
	if table then
		local value = table[key]
		
		if value ~= nil then
			return value
		end
	end

	return default
end

return pick