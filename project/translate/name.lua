local Translator = require "lang.transpile.translator"

--- @param t Transpiler
--- @param text string
Translator:define("Name", function(t, text)
	t:write(text)
end)