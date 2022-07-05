local Translator = require "lang.transpile.translator"

--- @param t Transpiler
--- @param expression RuleNode
Translator:define("stat", 1, function(t, expression)
	t:append(expression)
end)

--- @param t Transpiler
--- @param expression RuleNode
Translator:define("stat", 4, function(t, _, declarable, _, expression)
	t:write("local ")
	t:append(declarable)
	t:write(" = ")
	t:append(expression)
end)