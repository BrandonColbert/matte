local status = require "matter.utils.status"

--- @class Symbol
--- @field label? string Name of this symbol according to the grammar
--- @operator len:number
--- @operator bor(Symbol):Symbol
--- @operator shl(Symbol.Tags):Symbol
--- Foundation for the tokens and rules that compose a language
local Symbol = {}
Symbol.__index = Symbol

--- @return Symbol
function Symbol:new()
	return setmetatable({}, self)
end

-- Returns the size of largest branch of requirements
--- @return number
function Symbol:__len()
	return 0
end

--- Creates a new symbol with a union of both symbols' branches
--- @param lhs Symbol
--- @param rhs Symbol
--- @return Symbol
function Symbol.__bor(lhs, rhs)
	status:except{}
end

--- @class Symbol.Tags
--- @field branch? string Consumable branch name to be applied when unified
--- Updates this symbol's tags if anonymous or creates a new symbol with the tags if named
--- @param tags Symbol.Tags
--- @return Symbol
function Symbol:__shl(tags)
	status:except{}
end

--- @return string
function Symbol:__tostring()
	return self.label or "?"
end

--- @class Symbol.Name
local Name = {
	patterns = {
		token = {
			direct = "^<([%w%p%s]+)>$",
			pattern = "^(%u[%w_]*)$"
		},
		rule = "^(%l[%w_]*)$"
	}
}

Symbol.Name = Name
Symbol.Name.__index = Symbol.Name

--- Returns whether the symbol name corresponds to a token using literal matches
--- @param name string Symbol name
--- @return string
function Name.isLiteralToken(name)
	return name:match(Symbol.Name.patterns.token.direct)
end

--- Returns whether the symbol name corresponds to a token using pattern matches
--- @param name string Symbol name
--- @return string
function Name.isPatternToken(name)
	return name:match(Symbol.Name.patterns.token.pattern)
end

--- Returns whether the symbol name corresponds to a token
--- @param name string Symbol name
--- @return string
function Name.isToken(name)
	return Symbol.Name.isLiteralToken(name) or Symbol.Name.isPatternToken(name)
end

--- Returns whether the symbol name corresponds to a rule
--- @param name string Symbol name
--- @return string
function Name.isRule(name)
	return name:match(Symbol.Name.patterns.rule)
end

return Symbol