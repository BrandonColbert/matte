local list = require "matter.utils.list"

--- String buffer from [Lua manual](https://www.lua.org/pil/11.6.html)
--- @class Buffer
--- @field data string[]
local Buffer = {}
Buffer.__index = Buffer

--- @return Buffer
function Buffer:new()
	local o = {data={}}
	setmetatable(o, self)

	return o
end

--- @param text string
function Buffer:push(text)
	table.insert(self.data, text)

	for i = #self.data - 1, 1, -1 do
		if #self.data[i] > #self.data[i + 1] then
			break
		end

		self.data[i] = self.data[i] .. table.remove(self.data)
	end
end

function Buffer:at(index)
	if index < 0 then
		index = 1 + #self + index
	end

	for section in list(self.data) do
		if index < 1 then
			break
		elseif index <= #section then
			return section:sub(index, index)
		else
			index = index - #section
		end
	end

	return nil
end

function Buffer:__len()
	return list(self.data):reduce(function(count, text)
		return count + #text
	end, 0)
end

function Buffer:__tostring()
	return table.concat(self.data)
end

return Buffer