local Symbol = require "lang.symbols.symbol"
local Token = require "lang.symbols.token"
local list = require "utils.list"

--- Denotes multiple variations of a symbol sequence as a discrete structure.
--- @class Rule: Symbol
--- @field rsets Rule.Requirement.Set[] Requirements sets that may be fulfilled.
local Rule = {}
Rule.__index = Rule
setmetatable(Rule, Symbol)

--- Creates a new rule with the given name and an optional singular set of requirements.
---
--- If no name is specified, the rule will be considered anonymous
--- @overload fun(name: string, firstEntry?: Symbol, ...: Symbol | string): Rule
--- @overload fun(firstEntry?: Symbol, ...: Symbol | string): Rule
--- @return Rule
function Rule:new(...)
	local name, args = nil, {...}

	-- Get name if specified
	if #args >= 1 and type(args[1]) == "string" then
		name = table.remove(args, 1)
	end

	-- Create the rule
	local o = Symbol:new(name)
	o.rsets = {}
	setmetatable(o, self)

	-- Add base requirements
	o:addRequirementSet(table.unpack(args))

	return o
end

--- Adds a set of requirements to this rule based on the given entries.
--- Each entry is a token, rule, or quantifier.
---
--- A quantifier may only be placed directly after a token, rule, or another quantifier.
---
--- Quantifiers may be any of the following.
--- * `? - Optional`
--- * `+ - Repeats 1 or more times`
--- * `* - Repeats 0 or more times`
---
--- If the entries consist of a single anonymous rule, all of the anonymous rule's requirement sets will be copied directly.
--- @param ... Symbol | string Entries for the requirement set
function Rule:addRequirementSet(...)
	local entries = {...}

	if #entries == 0 then -- Ignore if no entries provided
		return
	elseif -- Copy requirements if single anonymous rule given
		#entries == 1
		and getmetatable(entries[1]) == Rule
		and not entries[1].name
	then
		local rule = entries[1]

		for rset in list(rule.rsets):values() do
			table.insert(self.rsets, rset)
		end
	else -- Create a requirement set from the entries
		table.insert(self.rsets, Rule.Requirement.Set:new(...))
	end
end

--- Returns a new rule with the requirements of all the specified rules
--- @param ... Rule Rules to unify
--- @return Rule
function Rule.unify(...)
	local result = Rule:new()

	for rule in list{...}:values() do
		if rule.name then
			-- Add named rules as a requirement set
			table.insert(result.rsets, Rule.Requirement.Set:new(rule))
		else
			-- Copy requirement sets from anonymous rules
			for rset in list(rule.rsets):values() do
				table.insert(result.rsets, rset)
			end
		end
	end

	return result
end

function Rule:__len()
	return math.max(0, list(self.rsets)
		:map(function(rset)
			return #rset
		end)
		:unpack()
	)
end

--- @param lhs Rule
--- @param rhs Symbol
--- @return Rule
function Rule.__bor(lhs, rhs)
	-- Confirm left side is rule
	if not (type(lhs) == "table" and getmetatable(lhs) == Rule) then
		error(string.format("Left hand side must be a rule: %s | %s", lhs, rhs))
	end

	-- Coerce right side into rule
	if type(rhs) == "table" and getmetatable(rhs) == Token then
		rhs = Rule:new(rhs)
	elseif getmetatable(rhs) ~= Rule then
		error(string.format("Right hand side must be a token or rule: %s | %s", lhs, rhs))
	end

	return Rule.unify(lhs, rhs)
end

function Rule:__tostring()
	local text = Symbol.__tostring(self)

	if not text then
		if #self.rsets > 0 then
			local textRequirementSets = list(self.rsets)
				:map(function(rset)
					return string.format("(%s)", rset)
				end)
				:table()

			text = table.concat(textRequirementSets, " | ")
		else
			text = "(---)"
		end
	end

	return text
end

--- A single requirement in one of a rule's requirement sets
--- @class Rule.Requirement
--- @field symbol Symbol Required symbol
--- @field quantifier string Indicates required number of appearances for the symbol. If empty, one is required.
local Requirement = {}
Rule.Requirement = Requirement
Rule.Requirement.__index = Rule.Requirement

--- @param symbol Symbol Required symbol
--- @param quantifier? string Indicates required number of appearances for the symbol
--- @return Rule.Requirement
function Rule.Requirement:new(symbol, quantifier)
	local o = {
		symbol = symbol,
		quantifier = quantifier or ""
	}

	setmetatable(o, self)

	return o
end

--- Returns whether the requirement may be complete with 0 nodes
--- @return boolean
function Rule.Requirement:isOptional()
	return self.quantifier == '?' or self.quantifier == '+'
end

function Rule.Requirement:__tostring()
	if #self.quantifier > 0 and #self.symbol.rsets > 1 then
		return string.format("(%s)%s", self.symbol, self.quantifier)
	end

	return string.format("%s%s", self.symbol, self.quantifier)
end

--- Represents a sequence of requirements that must be fulfilled for this set to be considered complete
--- @class Rule.Requirement.Set
--- @field requirements Rule.Requirement[] Sequence of requirements
local Set = {}
Rule.Requirement.Set = Set
Rule.Requirement.Set.__index = Rule.Requirement.Set

--- @param ... Symbol | string Entries for this set
--- @return Rule.Requirement.Set
function Rule.Requirement.Set:new(...)
	local o = {
		requirements = list{...}
			:reduce(function(t, entry)
				if type(entry) == "table" then -- Symbol
					-- Add new requirement
					if getmetatable(entry) == Token or getmetatable(entry) == Rule then
						table.insert(t, Rule.Requirement:new(entry))
					else
						error(string.format("Token or rule expected, but received '%s'", entry))
					end
				elseif type(entry) == "string" then -- Quantifier
					-- Modify previous requirement to contain the new quantifier
					local requirement = t[#t]
					requirement.quantifier = requirement.quantifier .. entry
				else
					error(string.format(
						"Token, rule, or quantifier expected, but received '%s' with value '%s'",
						type(entry),
						entry
					))
				end

				return t
			end, {})
	}

	setmetatable(o, self)

	return o
end

function Rule.Requirement.Set:__len()
	return #self.requirements
end

function Rule.Requirement.Set:__tostring()
	if #self.requirements > 0 then
		local textRequirements = list(self.requirements)
			:map(function(requirement)
				return tostring(requirement)
			end)
			:table()

		return table.concat(textRequirements, ", ")
	end

	return "---"
end

return Rule