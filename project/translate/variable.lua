local Translator = require "lang.transpile.translator"

--- @param t Transpiler
--- @param name TokenNode
--- @param type? RuleNode
Translator:define("variable", function(t, name, type)
	t:append(name)

	if type then
		
	end
end)