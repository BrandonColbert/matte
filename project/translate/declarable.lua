local Translator = require "lang.transpile.translator"

--- @param t Transpiler
--- @param variable RuleNode
Translator:define("declarable", 1, function(t, variable)
	t:append(variable)
end)