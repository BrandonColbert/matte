--- Returns a new environment inheriting from the given environments
--- @param ... table Ordered environments to inherit from
--- @return table
function scope(...)
	local envs = {...}
	local base = {}

	if #envs == 0 then
		return base
	elseif #envs == 1 then
		return setmetatable(base, {__index = envs[1]})
	else
		return setmetatable(base, {
			__index = function(self, key)
				for i = 1, #envs do
					local value = envs[i][key]

					if value then
						return value
					end
				end
			end
		})
	end
end

return scope