local Translator = require "lang.transpile.translator"

--- @param t Transpiler
--- @param text string
Translator:define("ConditionOp", function(t, text)
	if text == "&&" then
		t:write("and")
	elseif text == "||" then
		t:write("or")
	elseif text == "??" then
		error()
	end
end)