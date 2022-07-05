local Translator = require "lang.transpile.translator"

--- @param t Transpiler
--- @param text string
Translator:define("Number", function(t, text)
	if text == "infinity" then
		t:write("math.huge")
	elseif text == "nan" then
		t:write("0/0")
	else
		t:write(text)
	end
end)

return Number