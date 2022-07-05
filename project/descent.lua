local Descend = require "lang.descend"
local Transpiler = require "lang.transpiler"
require "grammar"
require "translation"

--- @class Descent: Descend
local Descent = {}
Descent.__index = Descent
setmetatable(Descent, Descend)

--- Returns the Lua code for the Descent code
--- @param src string Descent source code
--- @return string
function Descent:transpile(src)
	local root = self:parse(src)

	local transpiler = Transpiler:new()
	transpiler:append(root)

	return transpiler:result()
end

--- Runs the given Descent code with the specified CLI arguments
--- @param src string Descent source code
--- @param ... string[] Command line arguments
--- @return ...
function Descent:run(src, ...)
	local result = self:transpile(src)
	local program, err = load(result)

	if not program then
		io.stderr:write(err)
		return
	end

	return program(...)
end

return Descent