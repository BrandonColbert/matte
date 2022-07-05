local Translator = require "lang.transpile.translator"

--- @param t Transpiler
--- @param constant RuleNode
Translator:define("exp", 1, function(t, constant)
	t:append(constant)
end)

--- @param t Transpiler
--- @param name TokenNode
Translator:define("exp", 2, function(t, name)
	t:append(name)
end)

--- @param t Transpiler
--- @param lhs RuleNode
--- @param op RuleNode
--- @param rhs RuleNode
Translator:define("exp", 6, function(t, lhs, op, rhs)
	t:append(lhs)
	t:write(" ")
	t:append(op)
	t:write(" ")
	t:append(rhs)
end)

--- @param t Transpiler
--- @param exp RuleNode
--- @param genericArgs? RuleNode
--- @param args RuleNode
Translator:define("exp", 11, function(t, exp, genericArgs, args)
	t:append(exp)

	if genericArgs then
		error()
	end

	t:append(args)
end)