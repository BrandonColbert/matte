local list = require "utils.list"

--- Foundation for the tokens and rules that compose the language
--- @class Symbol
--- @field name? string Symbol name
--- @type fun(name: string, ...: Symbol | string): Token | Rule
local Symbol = {}
Symbol.__index = Symbol

--- @param name? string Symbol name
--- @return Symbol
function Symbol:new(name)
	local o = {name=name}
	setmetatable(o, self)

	return o
end

-- Returns the number of requirements
--- @return number
function Symbol:__len()
	return 0
end

--- Combines both symbol's requirements into a new anonymous rule
--- @param lhs Symbol
--- @param rhs Symbol
--- @return Rule
function Symbol.__bor(lhs, rhs)
	return nil
end

function Symbol:__tostring()
	return self.name
end

--- @class Metatable
local Metatable = {}
setmetatable(Symbol, Metatable)

--- Returns the registered symbol with the corresponding name if it exists.
--- If the symbol does not exist, it will be defined using the given parameters and registered under the specified name.
--- @overload fun(name: string): Token | Rule
--- @overload fun(name: string, ...: string): Token
--- @overload fun(name: string, firstEntry?: Symbol, ...: Symbol | string): Rule
--- @param name string Symbol name
--- @return Token | Rule
function Metatable:__call(name, ...)
	local Token = require "lang.lex.token"
	local Rule = require "lang.lex.rule"

	if Symbol.Name.isToken(name) then -- Token symbol
		--- @type Token
		local token = Symbol.Registry.tokens[name]

		-- If token does not exist, create and register it
		if not token then
			if Symbol.Name.isPatternToken(name) then
				token = Token:new(name, ...)
			elseif Symbol.Name.isDirectToken(name) then
				name = name:match(Symbol.Name.patterns.token.direct)
				token = Token:new(name)
			end

			Symbol.Registry.register(token)
		end

		return token
	elseif Symbol.Name.isRule(name) then -- Rule symbol
		--- @type Rule
		local rule = Symbol.Registry.rules[name]

		-- If rule does not exist, create and register it
		if not rule then
			rule = Rule:new(name, ...)
			Symbol.Registry.register(rule)
		end

		return rule
	else
		error(string.format("Invalid symbol name '%s'", name))
	end
end

--- Symbol registry for rules and tokens mapped by name
--- @class Symbol.Registry
--- @field rules table<string, Rule>
--- @field tokens table<string, Token>
--- @field names {rules: string[], tokens: string[]}
local Registry = {
	rules = {},
	tokens = {},
	names = {
		rules = {},
		tokens = {}
	}
}

Symbol.Registry = Registry
Symbol.Registry.__index = Symbol.Registry

--- Registers a new rule or token
--- @param symbol Symbol Symbol to register
function Symbol.Registry.register(symbol)
	local Token = require "lang.lex.token"
	local Rule = require "lang.lex.rule"

	if symbol.name then
		if getmetatable(symbol) == Token then
			if Symbol.Registry.tokens[symbol.name] ~= nil then
				error(string.format("Token '%s' already exists", symbol.name))
			end
	
			Symbol.Registry.tokens[symbol.name] = symbol
			table.insert(Symbol.Registry.names.tokens, symbol.name)
		elseif getmetatable(symbol) == Rule then
			if Symbol.Registry.rules[symbol.name] ~= nil then
				error(string.format("Rule '%s' already exists", symbol.name))
			end
	
			Symbol.Registry.rules[symbol.name] = symbol
			table.insert(Symbol.Registry.names.rules, symbol.name)
		else
			error("Only Token or Rule symbols may be registered.")
		end
	else
		error("Unable to register anonymous symbol.")
	end
end

--- Returns all token symbols in registration order
--- @return Token[]
function Symbol.Registry.getTokens()
	return list(Symbol.Registry.names.tokens)
		:map(function(name)
			return Symbol.Registry.tokens[name]
		end)
		:table()
end

--- Returns all rule symbols in registration order
--- @return Rule[]
function Symbol.Registry.getRules()
	return list(Symbol.Registry.names.rules)
		:map(function(name)
			return Symbol.Registry.rules[name]
		end)
		:table()
end

--- @class Symbol.Name
local Name = {
	patterns = {
		token = {
			direct = "^<([%w%p]+)>$",
			pattern = "^(%u[%w_]*)$"
		},
		rule = "^(%l[%w_]*)$"
	}
}

Symbol.Name = Name
Symbol.Name.__index = Symbol.Name

--- Returns whether the symbol name corresponds to a token using direct matches
--- @param name string Symbol name
--- @return string
function Symbol.Name.isDirectToken(name)
	return name:match(Symbol.Name.patterns.token.direct)
end

--- Returns whether the symbol name corresponds to a token using pattern matches
--- @param name string Symbol name
--- @return string
function Symbol.Name.isPatternToken(name)
	return name:match(Symbol.Name.patterns.token.pattern)
end

--- Returns whether the symbol name corresponds to a token
--- @param name string Symbol name
--- @return string
function Symbol.Name.isToken(name)
	return Symbol.Name.isDirectToken(name) or Symbol.Name.isPatternToken(name)
end

--- Returns whether the symbol name corresponds to a rule
--- @param name string Symbol name
--- @return string
function Symbol.Name.isRule(name)
	return name:match(Symbol.Name.patterns.rule)
end

return Symbol