local Translator = require "lang.transpile.translator"

--- @param t Transpiler
--- @param number TokenNode
Translator:define("constant", 1, function(t, number)
	t:append(number)
end)

--- @param t Transpiler
--- @param string TokenNode
Translator:define("constant", 2, function(t, string)
	t:append(string)
end)