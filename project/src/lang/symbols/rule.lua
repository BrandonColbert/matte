local Symbol = require "src.lang.symbols.symbol"
local Token = require "src.lang.symbols.token"

--[[
	Denotes groups of tokens and rules as a discrete structure

	rsets: Requirement.Set[]
		List of requirement sets that may be fulfilled.
]]
local Rule = {}
Rule.__index = Rule
setmetatable(Rule, Symbol)

--[[
	Creates and registers a named rule

	name: string
		Rule name
	...entries: (Symbol | string)[]
		Sequence of symbol with quantifiers that must be present for this rule to be fulfilled.

		If this consists of a single rule, the requirement sets will be copied.

	Creates a nameless rule

	...entries: (Symbol | string)[]
		Sequence of symbol with quantifiers that must be present for this rule to be fulfilled.

		If this consists of a single rule, the requirement sets will be copied.
]]
function Rule:new(...)
	local name
	local args = {...}

	if #args >= 1 and type(args[1]) == "string" then -- Named
		name = table.remove(args, 1)
	else -- Nameless
		name = nil
	end

	local o = Symbol:new(name)
	o.rsets = {}
	setmetatable(o, self)

	o:addRequirementSet(table.unpack(args))

	return o
end

--[[
	Adds a base requirement set for this rule.

	...entries: (Symbol | string)[]
		The tokens and rules that must appear to match sequentially to match to this rule

		Each symbol may be proceeded by the following quantifier
			? - Optional
			+ - Repeats 1 or more times
			* - Repeats 0 or more times
]]
function Rule:addRequirementSet(...)
	local entries = {...}

	if #entries == 0 then
		return
	elseif
		#entries == 1
		and getmetatable(entries[1]) == Rule
		and not entries[1].name
	then
		local rule = entries[1]

		for _, rset in ipairs(rule.rsets) do
			table.insert(self.rsets, rset)
		end
	else
		table.insert(self.rsets, Rule.Requirement.Set:new(...))
	end
end

--[[
	lhs: Rule
	rhs: Rule

	Returns the union between the given rules
]]
function Rule.unify(lhs, rhs)
	local function addRule(base, rule)
		if rule.name then
			table.insert(base.rsets, Rule.Requirement.Set:new(rule))
		else
			for _, rset in ipairs(rule.rsets) do
				table.insert(base.rsets, rset)
			end
		end
	end

	local rule = Rule:new()
	addRule(rule, lhs)
	addRule(rule, rhs)

	return rule
end

function Rule.__len(o)
	local maxSize = 0

	for _, rset in ipairs(o.rsets) do
		maxSize = math.max(#rset, maxSize)
	end

	return maxSize
end

function Rule.__bor(lhs, rhs)
	-- Create rule from left side rule
	if not (type(lhs) == "table" and getmetatable(lhs) == Rule) then
		error("Left hand side must be a rule: " .. tostring(lhs) .. " | " .. tostring(rhs))
	end

	-- Coerce right side into table for use as alternative
	if type(rhs) == "table" then
		if getmetatable(rhs) == Token then
			rhs = Rule:new(rhs)
		elseif getmetatable(rhs) ~= Rule then
			error("Right hand side must be a token or rule: " .. tostring(lhs) .. " | " .. tostring(rhs))
		end
	else
		error("Right hand side must be a table: " .. tostring(lhs) .. " | " .. tostring(rhs))
	end

	return Rule.unify(lhs, rhs)
end

function Rule.__tostring(o)
	local text = Symbol.__tostring(o)

	if not text then
		if #o.rsets > 0 then
			text = "(" .. tostring(o.rsets[1]) .. ")"

			for i = 2, #o.rsets do
				text = text .. " | (" .. tostring(o.rsets[i]) .. ")"
			end
		else
			text = "(---)"
		end
	end

	return text
end

Rule.Requirement = {}
Rule.Requirement.__index = Rule.Requirement

--[[
	A symbol with a quantifier.

	symbol: Symbol
	quantifier?: string
]]
function Rule.Requirement:new(symbol, quantifier)
	local o = {
		symbol = symbol,
		quantifier = quantifier or ""
	}

	setmetatable(o, self)

	return o
end

function Rule.Requirement.__tostring(o)
	if #o.quantifier > 0 then
		if #o.symbol.rsets > 1 then
			return string.format("(%s)%s", o.symbol, o.quantifier)
		end

		return tostring(o.symbol) .. o.quantifier
	end

	return tostring(o.symbol)
end

--[[
	A sequence of requirements that must be present to be fulfilled.

	requirements: Requirement[]
]]
Rule.Requirement.Set = {}
Rule.Requirement.Set.__index = Rule.Requirement.Set

--[[
	...entries: (Symbol | string)[]
]]
function Rule.Requirement.Set:new(...)
	local requirements = {}
	local entries = {...}

	for i = 1, #entries do
		local entry = entries[i]

		if type(entry) == "table" then
			if getmetatable(entry) == Token or getmetatable(entry) == Rule then -- Symbol
				table.insert(requirements, Rule.Requirement:new(entry))
			else
				error("Token or rule expected, but received '" .. tostring(entry) .. "'")
			end
		elseif type(entry) == "string" then -- Quantifier
			local requirement = requirements[#requirements]
			requirement.quantifier = requirement.quantifier .. entry
		else
			error("Token, rule, or quantifier expected, but received '" .. tostring(entry) .. "' of type '" .. type(entry) .. "'")
		end
	end

	local o = {requirements = requirements}
	setmetatable(o, self)

	return o
end

function Rule.Requirement.Set.__len(o)
	return #o.requirements
end

function Rule.Requirement.Set.__tostring(o)
	if #o.requirements > 0 then
		local text = tostring(o.requirements[1])

		for i = 2, #o.requirements do
			text = text .. ", " .. tostring(o.requirements[i])
		end

		return text
	end

	return "---"
end

return Rule