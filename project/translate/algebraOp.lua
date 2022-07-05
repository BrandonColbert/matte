local Translator = require "lang.transpile.translator"

--- @param t Transpiler
--- @param text string
Translator:define("AlgebraOp", function(t, text)
	if text == "**" then
		t:write("^")
	else
		t:write(text)
	end
end)