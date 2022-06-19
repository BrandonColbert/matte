--[[
	Foundation for the tokens and rules that compose the language

	static registry: {
		rules: {[key: string]: Symbol},
		tokens: {[key: string]: Symbol}
	}
		Symbol registry for rules and tokens mapped by name

	name?: string
		Symbol name
]]
local Symbol = {
	registry = {
		rules = {},
		tokens = {},
		names = {
			rules = {},
			tokens = {}
		}
	}
}

Symbol.__index = Symbol

--[[
	name?: string
		Symbol name
]]
function Symbol:new(name)
	local o = {name = name}
	setmetatable(o, self)

	if name ~= nil then -- Named symbol
		if Symbol.isPatternTokenName(name)  then -- Token name
			if self.registry.tokens[name] ~= nil then
				error("Token '" .. name .. "' already exists")
			end

			self.registry.tokens[name] = o
			table.insert(self.registry.names.tokens, name)
		elseif Symbol.isDirectTokenName(name) then -- Direct token name
			if self.registry.tokens[name] ~= nil then
				error("Token '" .. name .. "' already exists")
			end

			self.registry.tokens[name] = o
			table.insert(self.registry.names.tokens, name)
		elseif name:match("^%l%a*$") then -- Rule name
			if self.registry.rules[name] ~= nil then
				error("Rule '" .. name .. "' already exists")
			end

			self.registry.rules[name] = o
			table.insert(self.registry.names.rules, name)
		else
			error("Invalid symbol name '" .. name .. "'")
		end
	end

	return o
end

--[[
	name: string
		Symbol name

	Returns the symbol instance with the associated name
]]
function Symbol.get(name)
	if Symbol.isTokenName(name) then -- Token name
		return Symbol.registry.tokens[name]
	elseif Symbol.isRuleName(name) then -- Rule name
		return Symbol.registry.rules[name]
	else
		return nil
	end
end

function Symbol.isDirectTokenName(name)
	return name:match("<[%w%p]+>")
end

function Symbol.isPatternTokenName(name)
	return name:match("^%u%a*$")
end

function Symbol.isTokenName(name)
	return Symbol.isDirectTokenName(name) or Symbol.isPatternTokenName(name)
end

function Symbol.isRuleName(name)
	return name:match("^%l%a*$")
end

--[[
	Returns an iterator for tokens in insertion order
]]
function Symbol.getTokens()
	local i = 0
	local length = #Symbol.registry.names.tokens

	return function()
		i = i + 1

		if i <= length then
			local name = Symbol.registry.names.tokens[i]
			local symbol = Symbol.registry.tokens[name]

			return symbol
		end
	end
end

--[[
	Returns an iterator for rules in insertion order
]]
function Symbol.getRules()
	local i = 0
	local length = #Symbol.registry.names.rules

	return function()
		i = i + 1

		if i <= length then
			local name = Symbol.registry.names.rules[i]
			local symbol = Symbol.registry.rules[name]

			return symbol
		end
	end
end

-- Number of requirements
function Symbol.__len(o)
	return 0
end

-- Combines the symbols into a rule union
function Symbol.__bor(lhs, rhs)
	return nil
end

function Symbol.__tostring(o)
	if o.name then
		return o.name
	end

	return nil
end

return Symbol