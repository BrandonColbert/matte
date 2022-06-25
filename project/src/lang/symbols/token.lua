local Symbol = require "lang.symbols.symbol"
local Escape = require "utils.escape"

--- Represents a category which text may fall under.
--- @class Token: Symbol
--- @field name string Token name
--- @field patterns string[] Patterns used to find matches
local Token = {}
Token.__index = Token
setmetatable(Token, Symbol)

--- Creates a new token with the specified name.
---
--- If patterns are specified, the text will be pattern matched.
---
--- If no patterns are specified, the text will be directly matched to the name
--- @overload fun(name: string, ...: string): Token
--- @overload fun(name: string): Token
--- @return Token
function Token:new(...)
	local args = {...}
	local name, patterns

	if #args == 1 then -- Direct
		name = "<" .. args[1] .. ">"

		local escapedPattern = Escape.pattern(args[1])
		patterns = {escapedPattern}
	else -- Pattern
		name = table.remove(args, 1)
		patterns = args
	end

	local o = Symbol:new(name)
	o.patterns = patterns
	setmetatable(o, self)

	return o
end

function Token:__tostring()
	return Symbol.__tostring(self)
end

function Token:__len()
	return 1
end

--- @param lhs Token
--- @param rhs Symbol
--- @return Rule
function Token.__bor(lhs, rhs)
	local Rule = require "lang.symbols.rule"

	-- Coerce left side into rule from token
	if type(lhs) == "table" and getmetatable(lhs) == Token then
		lhs = Rule:new(lhs)
	else
		error(string.format("Left hand side must be a token: %s | %s", lhs, rhs))
	end

	return Rule.__bor(lhs, rhs)
end

return Token