local Translator = require "lang.transpile.translator"
local list = require "utils.list"

--- @param t Transpiler
--- @param firstExp RuleNode
--- @param restExp RuleNode[]
Translator:define("expressions", function(t, firstExp, restExp)
	t:append(firstExp)

	for node in list(restExp):values() do
		t:write(", ")

		local exp = node:getNode(2)
		t:append(exp)
	end
end)