local Translator = require "lang.transpile.translator"

--- @param t Transpiler
--- @param text string
Translator:define("String", function(t, text)
	if text:sub(1, 1) == "f" then
		error()
	elseif text:sub(1, 1) == "l" then
		text = text:sub(3, #text - 1)
		text = text:gsub("\\", "")

		local level = ""

		while text:find("]" .. level .. "]", 1, true) do
			level = level .. "="
		end

		t:write(string.format("[%s[%s]%s]", level, text, level))
	else
		t:write(text)
	end
end)