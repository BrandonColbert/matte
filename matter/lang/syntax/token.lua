local Symbol = require "matter.lang.syntax.symbol"
local list = require "matter.utils.list"

--- @alias Token.Selector
--- | string
--- | fun(text: string): boolean
--- @class Token: Symbol
--- @field literal boolean Whether to interpret string selectors literally or as patterns
--- @field ignore boolean Whether this token should be ignored by the parser
--- @field blocking boolean Whether the parser is stopped if integration fails
--- @field selectors Token.Selector[] Selectors used to find matches
--- @operator len:number
--- @operator bor(Symbol):Rule
--- @operator shl(Token.Tags):Token
--- Represents a category which text may fall under.
local Token = {}
Token.__index = Token
setmetatable(Token, Symbol)

--- @param ... Token.Selector Text selectors
--- @return Token
function Token:new(...)
	local o = Symbol:new() --[[@as Token]]
	o.selectors = {...}
	o.literal = false
	o.ignore = false
	o.blocking = true

	return setmetatable(o, self)
end

--- Copy the specified token's attributes
--- @param token Token Token to mirror
function Token:assume(token)
	-- Copy name
	self.label = token.label

	-- Copy selectors
	self.selectors = list(token.selectors):table()

	-- Copy options
	self.literal = token.literal
	self.ignore = token.ignore
	self.blocking = token.blocking
end

--- @return number
function Token:__len()
	return 1
end

--- @param lhs Token
--- @param rhs Symbol
--- @return Rule
function Token.__bor(lhs, rhs)
	local Rule = require "matter.lang.syntax.rule"

	-- Coerce left side into rule
	local left = Rule:new(lhs)

	return left:__bor(rhs)
end

--- @class Token.Tags: Symbol.Tags
--- @field literal? boolean
--- @field ignore? boolean
--- @field blocking? boolean
--- @param tags Token.Tags
--- @return Token|Rule
function Token:__shl(tags)
	local Rule = require "matter.lang.syntax.rule"

	-- Create an anonymous copy if this token has a name
	if self.label then
		local t = Token:new()
		t:assume(self)

		return t << tags
	end

	-- Apply option tags
	if tags.literal ~= nil then
		self.literal = tags.literal
	end

	if tags.ignore ~= nil then
		self.ignore = tags.ignore
	end

	if tags.blocking ~= nil then
		self.blocking = tags.blocking
	end

	-- Apply branch name
	if tags.branch then
		-- Convert to rule and assign branch name to the sole requirement branch
		local rule = Rule:new(self)
		rule.branches[1].name = tags.branch

		return rule
	else
		return self
	end
end

--- @return string
function Token:__tostring()
	return Symbol.__tostring(self)
end

return Token