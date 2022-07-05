local Translator = require "lang.transpile.translator"

--- @param t Transpiler
--- @param par2? RuleNode
Translator:define("arguments", function(t, _, par2, _)
	t:write("(")
	t:append(par2:getNode(1))
	t:write(")")
end)