local Symbol = require "matter.lang.syntax.symbol"
local Token = require "matter.lang.syntax.token"
local list = require "matter.utils.list"
local status = require "matter.utils.status"

--- @class Rule: Symbol
--- @field branches Rule.Requirement.List[]
--- @operator len:number
--- @operator bor(Symbol):Rule
--- @operator shl(Rule.Tags):Rule
--- Denotes multiple variations of a symbol sequence as a discrete structure.
local Rule = {}
Rule.__index = Rule
setmetatable(Rule, Symbol)

--- Generates an ordered set of requirements for this rule based on the given entries.
--- Each entry is a token, rule, or quantifier.
---
--- A quantifier may only be placed directly after a token, rule, or another quantifier.
---
--- Quantifiers may be any of the following.
--- * `? - Optional`
--- * `+ - Repeats 1 or more times`
--- * `* - Repeats 0 or more times`
--- @param firstEntry? Symbol First entry if existent
--- @param ... Symbol|string Remaining entries
--- @return Rule
function Rule:new(firstEntry, ...)
	local o = Symbol:new() --[[@as Rule]]
	o.branches = {}

	-- If entries are given, create the first branch
	if firstEntry then
		table.insert(o.branches, Rule.Requirement.List:new(firstEntry, ...))
	end

	return setmetatable(o, self)
end

--- Incorporates the specified rules as additional branches
--- @param ... Rule Rules to assimilate
function Rule:assimilate(...)
	for rule in list{...} do --- @cast rule Rule
		local branchCount = #self.branches

		if rule.label then
			-- Add the named rule as a branch
			table.insert(self.branches, Rule.Requirement.List:new(rule))
		else
			-- Copy anonymous rule's branches
			for branch in list(rule.branches) do --- @cast branch Rule.Requirement.List
				local requirementList = Rule.Requirement.List:new()
				requirementList.requirements = branch.requirements
				requirementList.name = branch.name
				requirementList.assoc = branch.assoc

				table.insert(self.branches, requirementList)
			end
		end
	end
end

--- @return number
function Rule:__len()
	return math.max(0, list(self.branches):map(function(branch)
		return #branch
	end):unpack())
end

--- @param lhs Rule
--- @param rhs Symbol
--- @return Rule
function Rule.__bor(lhs, rhs)
	if getmetatable(lhs) == Rule then
		if getmetatable(rhs) == Token then
			-- Coerce right side into rule from token
			rhs = Rule:new(rhs)
		elseif getmetatable(rhs) ~= Rule then
			status:except{"Right hand side must be a rule or token: %s | %s", fmt={lhs, rhs}, cat="rule"}
		end

		-- Create unified rule
		local rule = Rule:new()
		rule:assimilate(lhs, rhs)

		return rule
	else
		status:except{"Left hand side must be a rule: %s | %s", fmt={lhs, rhs}, cat="rule"}
	end
end

--- @class Rule.Tags: Symbol.Tags
--- @field assoc? "left"|"right" Whether the rule is left or right associative
--- @param tags Rule.Tags
--- @return Rule
function Rule:__shl(tags)
	if self.label then
		local rule = Rule:new()
		rule:assimilate(self)

		return rule << tags
	end

	-- Consume branch tag as the name for the list of requirements
	if tags.branch then
		for _, branch in pairs(self.branches) do
			if branch.name then
				branch.name = string.format("%s.%s", tags.branch, branch.name)
			else
				branch.name = tags.branch
			end
		end
	end

	-- Assign all branch associations
	if tags.assoc then
		for _, branch in pairs(self.branches) do
			branch.assoc = tags.assoc
		end
	end

	return self --[[@as Rule]]
end

--- @return string
function Rule:__tostring()
	return self.label or table.concat(list(self.branches):map(function(branch)
		local text = tostring(branch)

		if text:match("%s") then
			return string.format("(%s)", text)
		else
			return text
		end
	end):table(), " | ")
end

--- A single requirement in a rule's branch
--- @class Rule.Requirement
--- @field symbol Symbol Required symbol
--- @field quantifier string Indicates required number of appearances for the symbol. Empty corresponds to a single instance
local Requirement = {}
Rule.Requirement = Requirement
Rule.Requirement.__index = Rule.Requirement

--- @param symbol Symbol Required symbol
--- @param quantifier? string Indicates required number of appearances for the symbol
--- @return Rule.Requirement
function Requirement:new(symbol, quantifier)
	local o = {
		symbol = symbol,
		quantifier = quantifier or ""
	}

	return setmetatable(o, self)
end

--- Returns whether the requirement may be complete with 0 nodes
--- @return boolean
function Requirement:isOptional()
	return self.quantifier == '?' or self.quantifier == '*'
end

--- Returns whether the requirement is limited to a maximum of 1 node
--- @return boolean
function Requirement:isSingular()
	return #self.quantifier == 0 or self.quantifier == '?'
end

function Requirement:__tostring()
	local text = tostring(self.symbol)

	if text:match("%s") then
		return string.format("(%s)%s", text, self.quantifier)
	else
		return text .. self.quantifier
	end
end

--- Represents a sequence of requirements that must be fulfilled for this branch to be considered complete
--- @class Rule.Requirement.List
--- @field requirements Rule.Requirement[] Sequence of requirements
--- @field assoc "left"|"right" Whether the requirements are left or right associative
--- @field name? string Name of this List
local List = {}
Rule.Requirement.List = List
Rule.Requirement.List.__index = Rule.Requirement.List

--- @param ... Symbol | string Entries defining each requirement
--- @return Rule.Requirement.List
function List:new(...)
	local requirements = list{...}:reduce(function(t, entry) --- @cast t Rule.Requirement[]
		if getmetatable(entry) == Token or getmetatable(entry) == Rule then -- Symbol
			-- Add new requirement
			table.insert(t, Rule.Requirement:new(entry))
		elseif type(entry) == "string" then -- Quantifier
			-- Modify previous requirement to contain the new quantifier
			local requirement = t[#t]
			requirement.quantifier = requirement.quantifier .. entry
		else
			status:except{
				"Token, rule, or quantifier expected, but received '%s' with value '%s'",
				fmt={type(entry), entry},
				cat="rule"
			}
		end

		return t
	end, {})

	local o = {
		requirements = requirements,
		assoc = "left"
	}

	return setmetatable(o, self)
end

--- @return number
function List:__len()
	return #self.requirements
end

--- @return string
function List:__tostring()
	local sections = list(self.requirements):map(function(requirement)
		return tostring(requirement)
	end)

	if #sections == 0 then
		sections:push("---")
	end

	if self.name then
		sections:push(string.format("$%s", self.name))
	end

	return table.concat(sections:table(), " ")
end

return Rule