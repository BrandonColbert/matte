local matte = require "matte.matte"

--- @param p Program
--- @param text string
matte.translator:define("String", function(p, text)
	if text:sub(1, 1) == "l" then
		text = text:sub(3, #text - 1)
		text = text:gsub("\\", "")

		local level = ""

		while text:find("]" .. level .. "]", 1, true) do
			level = level .. "="
		end

		p:write(string.format("[%s[%s]%s]", level, text, level))
	else
		p:write(text)
	end
end)

matte.translator:define("string")