local Symbol = require "matter.lang.syntax.symbol"
local Token = require "matter.lang.syntax.token"
local Rule = require "matter.lang.syntax.rule"
local status = require "matter.utils.status"

--- Defines a language's syntax
--- @class Grammar
--- @field symbols {[string]: Symbol} Map of names to symbols
--- @field names {rules: string[], tokens: string[]} Symbol names by reference order
local Grammar = {}
Grammar.__index = Grammar

--- @return Grammar
function Grammar:new()
	local o = {
		symbols = {},
		names = {
			rules = {},
			tokens = {}
		}
	}

	return setmetatable(o, self)
end

--- @class GrammarDefEnv
--- @field r fun(firstEntry: Symbol, ...: Symbol | string): Rule
--- @field t fun(...: string): Token
--- @field T fun(text: string): Token
--- @field s fun(name: string): Symbol

--- Defines tokens and rules
--- @param fn fun(_ENV: GrammarDefEnv) Uses variables to define symbols with values made by the given functions
function Grammar:define(fn)
	local defenv, mt = {_G=_G}, {}

	--- Returns a new rule with the specified requirements
	--- @param firstEntry Symbol First requirement entry
	--- @param ... Symbol | string Remaining requirement entries
	--- @return Rule
	function defenv.r(firstEntry, ...)
		return Rule:new(firstEntry, ...)
	end

	--- Returns a new token which matches against the given patterns
	--- @param ... string Patterns to match against
	--- @return Token
	function defenv.t(...)
		return Token:new(...)
	end

	--- Returns the token which matches against the literal text (aka no patterns)
	--- @param text string Text to match against
	--- @return Token
	function defenv.T(text)
		local name = "<" .. text .. ">"
		local token = self:get(name) --[[@as Token]]

		-- Create token if it doesn't exist
		if not token then			
			token = Token:new(text)
			token.literal = true
			token.label = name
			self.symbols[name] = token

			table.insert(self.names.tokens, name)
		end

		return token
	end

	--- Returns the symbol with the corresponding name if it exists, creating it otherwise
	--- @param name string Symbol name
	--- @return Symbol
	function defenv.s(name)
		local symbol = self:get(name)

		-- Create the symbol if it does not exist
		if not symbol then
			-- Determine symbol type based on name
			if Symbol.Name.isRule(name) then
				symbol = Rule:new()
				table.insert(self.names.rules, name)
			elseif Symbol.Name.isToken(name) then
				symbol = Token:new()
				table.insert(self.names.tokens, name)
			else
				status:except{"Attempted to find a symbol with the invalid name '%s'", fmt={name}, cat="grammar"}
			end

			symbol.label = name
			self.symbols[name] = symbol
		end

		return symbol
	end

	--- @param t table
	--- @param key string
	--- @return Symbol
	function mt.__index(t, key)
		return defenv.s(key)
	end

	--- @param t table
	--- @param key string
	--- @param value Symbol
	function mt.__newindex(t, key, value)
		local symbol = self.symbols[key]

		if not symbol then
			-- Register the new symbol
			if Symbol.Name.isToken(key) and getmetatable(value) == Token then
				symbol = value
				table.insert(self.names.tokens, key)
			elseif Symbol.Name.isRule(key) then
				if getmetatable(value) == Token then
					-- Automatically convert token into rule
					symbol = Rule:new(value)
				elseif getmetatable(value) == Rule then --[[@cast value Rule]]
					symbol = Rule:new()
					symbol:assimilate(value)
				else
					status:except{"Unable to define symbol '%s'", fmt={key}, cat="grammar"}
				end

				table.insert(self.names.rules, key)
			else
				status:except{"Invalid symbol name '%s'", fmt={key}, cat="grammar"}
			end

			-- Create the symbol
			symbol.label = key
			self.symbols[key] = symbol
		elseif getmetatable(symbol) == Rule then --[[@cast symbol Rule]]
			-- Unify requirements
			if getmetatable(value) == Rule then --[[@cast value Rule]]
				symbol:assimilate(value)
			elseif getmetatable(value) == Token then --[[@cast value Token]]
				-- Automatically convert token into rule
				symbol:assimilate(Rule:new(value))
			end
		elseif getmetatable(symbol) == Token then --[[@cast symbol Token]]
			--- Overwrite existing token's attributes
			if getmetatable(value) == Token then --[[@cast value Token]]
				symbol:assume(value)
			else
				status:except{"Unable to overwrite token '%s'", fmt={key}, cat="grammar"}
			end
		else
			status:except{"Unable to redefine symbol '%s'", fmt={key}, cat="grammar"}
		end
	end
	
	fn(setmetatable(defenv, mt))
end

--- Gets the symbol associated with the given name
--- @param name string name
--- @return Symbol
function Grammar:get(name)
	return self.symbols[name]
end

function Grammar:__tostring()
	local s = "Grammar["

	local names = {}

	for _, v in pairs(self.symbols) do
		table.insert(names, string.format("\t%s", v))
	end

	if #names > 0 then
		table.sort(names)
		s = string.format("%s\n%s\n", s, table.concat(names, "\n"))
	end

	return s .. "]"
end

return Grammar