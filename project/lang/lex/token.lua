local Symbol = require "lang.lex.symbol"
local Escape = require "utils.escape"

--- Represents a category which text may fall under.
--- @class Token.Options
--- @field ignore boolean Whether this token should be ignored by the parser
--- @field blocking boolean Whether the parser may continue if integration fails
--- @class Token: Symbol
--- @field name string Token name
--- @field patterns (string | fun(content: string): content)[] Patterns used to find matches
--- @field options Token.Options
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
	o.options = {
		ignore = false,
		blocking = true
	}

	setmetatable(o, self)

	return o
end

--- @param state boolean
--- @return Token
function Token:setIgnore(state)
	self.options.ignore = state
	return self
end

--- @param state boolean
--- @return Token
function Token:setBlocking(state)
	self.options.blocking = state
	return self
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
	local Rule = require "lang.lex.rule"

	-- Coerce left side into rule from token
	if type(lhs) == "table" and getmetatable(lhs) == Token then
		lhs = Rule:new(lhs)
	else
		error(string.format("Left hand side must be a token: %s | %s", lhs, rhs))
	end

	return Rule.__bor(lhs, rhs)
end

return Token