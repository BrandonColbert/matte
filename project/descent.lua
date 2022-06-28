local Descend = require "lang.descend"
require "grammar"

--- @class Descent
local Descent = {}
Descent.__index = Descent
setmetatable(Descent, Descend)

--- Returns the Lua code for the Descent code
--- @param src string Descent source code
--- @return string
function Descent.transpile(src)
	local ast = Descent.parse(src)

	error("Not implemented!")
end

--- Runs the given Descent code with the specified CLI arguments
--- @param src string Descent source code
--- @param ... string[] Command line arguments
--- @return ...
function Descent.run(src, ...)
	local result = Descent.transpile(ast)
	local program, err = load(result)

	if not program then
		error(err)
	end

	return program({...})
end

return Descent