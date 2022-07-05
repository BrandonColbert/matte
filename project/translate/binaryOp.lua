local Translator = require "lang.transpile.translator"

--- @param t Transpiler
--- @param algebraOp RuleNode
Translator:define("binary_op", 1, function(t, algebraOp)
	t:append(algebraOp)
end)