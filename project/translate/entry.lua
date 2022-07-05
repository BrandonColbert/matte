local Translator = require "lang.transpile.translator"
local list = require "utils.list"

--- @param t Transpiler
--- @param imports RuleNode[]
--- @param statements RuleNode[]
Translator:define("entry", function(t, imports, statements)
	-- for node in list(imports):values() do
	-- 	t:append(node)
	-- 	t:write("\n")
	-- end

	t:write("\n")

	for node in list(statements):values() do
		t:append(node)
		t:write("\n")
	end
end)