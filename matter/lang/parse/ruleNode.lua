local Node = require "matter.lang.parse.node"
local TokenNode = require "matter.lang.parse.tokenNode"
local Rule = require "matter.lang.syntax.rule"
local Token = require "matter.lang.syntax.token"
local Escape = require "matter.utils.escape"
local list = require "matter.utils.list"
local status = require "matter.utils.status"

--- A node correlated with a particular rule
--- @class RuleNode: Node
--- @field symbol Rule Rule being realized
--- @field branches table<number, Node[][]> Each branch consists of a key that is the associated branch index and a value that is a list of entries. Each entry is a homogeneous list of nodes that fulfills the corresponding requirement
local RuleNode = {}
RuleNode.__index = RuleNode
setmetatable(RuleNode, Node)

--- @param rule Rule Rule being realized
--- @return RuleNode
function RuleNode:new(rule)
	local o = Node:new(rule) --[[@as RuleNode]]
	o.branches = {}

	-- Create a branch of entries for each branch of requirements
	for i, branch in pairs(rule.branches) do
		o.branches[i] = {}
	end

	return setmetatable(o, self)
end

--- @param delta number
function RuleNode:adjustDepth(delta)
	Node.adjustDepth(self, delta)

	for _, entries in pairs(self.branches) do --- @cast entries Node[][]
		for entry in list(entries) do --- @cast entry Node[]
			for node in list(entry) do --- @cast node Node
				if node ~= self then
					node:adjustDepth(delta)
				end
			end
		end
	end
end

--- @return RuleNode
function RuleNode:clone()
	local root = RuleNode:new(self.symbol)
	root.branches = {}

	for i, entries in pairs(self.branches) do
		root.branches[i] = list(entries):map(function(entry)
			return list(entry):map(function(node) --- @cast node Node
				if node == self then
					-- Return the root node if recursive
					return root
				else
					-- Return a copy otherwise
					local node = node:clone()
					node:adjustDepth(1)

					return node
				end
			end):table()
		end):table()
	end

	return root
end

--- @return string
function RuleNode:__tostring()
	-- Convert branches into strings
	local textBranches = {}

	for index, entries in pairs(self.branches) do
		table.insert(textBranches, string.format(
			[=["%d":{"reqs":"%s","entries":[%s]}]=],
			index,
			Escape.json(tostring(self.symbol.branches[index])),
			-- Convert entries into strings
			table.concat(list(entries):map(function(entry)
				-- Convert nodes into strings
				return string.format("[%s]", table.concat(list(entry):map(function(node)
					if node == self then
						return [["self"]]
					else
						return tostring(node)
					end
				end):table(), ","))
			end):table(), ",")
		))
	end

	return string.format(
		[[{"symbol":"%s","branches":{%s}}]],
		Escape.json(tostring(self.symbol)),
		table.concat(textBranches, ",")
	)
end

--- Returns the first complete branch of requirements for this node if it exists
--- @return number? branchIndex
--- @return Rule.Requirement.List? requirements
--- @return Node[][]? entries
function RuleNode:getMainBranch()
	for i = 1, #self.symbol.branches do
		if self:complete(i) then
			return i, self.symbol.branches[i], self.branches[i]
		end
	end

	return nil
end

--- Removes incomplete branches (matching the predicate if specified) from this node.
---
--- Returns whether any branches remain
--- @param predicate? fun(node: RuleNode, index: number, entries: Node[][]):boolean Whether to remove the incomplete branch at the specified index with the specified entries
--- @return boolean
function RuleNode:cull(predicate)
	--- @type {[number]: boolean}
	local indices = {}

	-- Find incomplete branches
	for i, entries in pairs(self.branches) do
		if not self:complete(i) and (not predicate or predicate(self, i, entries)) then
			indices[i] = true
		end
	end

	-- Remove incomplete branches
	for k, v in pairs(indices) do
		if v then
			self.branches[k] = nil
		end
	end

	return next(self.branches) ~= nil
end

--- Returns all the integrated tokens
--- @return TokenNode[]
function RuleNode:getTokens()
	-- Get tokens from the first encountered branch
	for _, entries in pairs(self.branches) do
		local tokens = {}

		-- Conglomerate tokens from each node
		for entry in list(entries) do
			for node in list(entry) do --- @cast node Node
				if getmetatable(node) == RuleNode then --- @cast node RuleNode
					for token in list(node:getTokens()) do
						table.insert(tokens, token)
					end
				elseif getmetatable(node) == TokenNode then --- @cast node TokenNode
					table.insert(tokens, node)
				end
			end
		end

		return tokens
	end

	return {}
end

--- Returns the number of integrated tokens
--- @return number
function RuleNode:__len()
	return #self:getTokens()
end

--- Returns whether the specified branch or a particular requirement of it has been satisfied.
---
--- If no requirement or branch is specified, return whether at least one branch has been satisifed
--- @param branchIndex? number Branch to check for fulfillment
--- @param requirementIndex? number Requirement to check for fulfillment
--- @return boolean
function RuleNode:complete(branchIndex, requirementIndex)
	if branchIndex then
		local requirements = self.symbol.branches[branchIndex].requirements
		local entries = self.branches[branchIndex] or {}

		if requirementIndex then
			local requirement = requirements[requirementIndex]
			local entry = entries[requirementIndex] or {}

			if #entry == 0 then
				return requirement:isOptional()
			elseif getmetatable(requirement.symbol) == Token then
				return true
			elseif getmetatable(requirement.symbol) == Rule then
				if requirement:isSingular() then
					return entry[1] ~= self and entry[1]:complete()
				else
					-- Ensure all nodes in the entry are complete
					for node in list(entry) do --- @cast node RuleNode
						if node == self or not node:complete() then
							return false
						end
					end
	
					return true
				end
			end
		else
			-- Return true if all the requirements of the specified branch are complete
			for i = 1, #requirements do
				if not self:complete(branchIndex, i) then
					return false
				end
			end

			return true
		end
	else
		-- Return true if at least one branch is complete
		for i in pairs(self.branches) do
			if self:complete(i) then
				return true
			end
		end
	end

	return false
end

--- Attempts to use the token to fulfill this node's requirements.
---
--- Returns whether the token could be integrated or not
--- @param token TokenNode A lexed token
--- @param branchIndex? number Branch to integrate the token into
--- @param requirementIndex? number Requirement to integrate the token for
--- @param entryIndex? number Position in the entry for the requirement to integrate the token into
--- @return boolean
function RuleNode:integrate(token, branchIndex, requirementIndex, entryIndex)
	if branchIndex then
		local branch = self.symbol.branches[branchIndex]
		local requirements = branch.requirements
		local entries = self.branches[branchIndex]

		if requirementIndex then
			local requirement = requirements[requirementIndex]
			local entry = entries[requirementIndex]

			-- Create the entry if it did not exist
			if not entry then
				entry = {}
				entries[requirementIndex] = entry
			end

			if entryIndex then
				if getmetatable(requirement.symbol) == Token then
					-- Add the token if valid
					if not entry[entryIndex] and token.symbol == requirement.symbol then
						token:adjustDepth(self.depth + 1)
						entry[entryIndex] = token

						return true
					end
				elseif getmetatable(requirement.symbol) == Rule then
					local node = entry[entryIndex] --[[@as RuleNode]]

					if not node then
						-- Fail on recursive requirement
						if
							requirement.symbol == self.symbol
							and (requirementIndex == 1 or requirementIndex == #requirements)
							-- and requirement:isSingular()
						then
							return false
						else
							node = RuleNode:new(requirement.symbol --[[@as Rule]])
						end
					elseif node == self then
						return false
					end

					-- Attempt to integrate the token, adding the node if successful
					if node:integrate(token) then
						if not entry[entryIndex] then
							node:adjustDepth(self.depth + 1)
							entry[entryIndex] = node
						end

						return true
					end
				end
			else
				if requirement:isSingular() then
					-- Singular requirements may only have one node in their entry
					return self:integrate(token, branchIndex, requirementIndex, 1)
				else
					entryIndex = math.max(1, #entry)

					-- Attempt to integrate into the next incomplete entry position
					while not self:integrate(token, branchIndex, requirementIndex, entryIndex) do
						local node = entry[entryIndex]

						if node and node:complete() then
							-- Remove incomplete branches since no further integration will be done
							if getmetatable(node) == RuleNode then --- @cast node RuleNode
								node:cull()
							end

							entryIndex = entryIndex + 1
						else
							return false
						end
					end

					return true
				end
			end
		else
			-- Attempt to integrate into the next available requirement
			for i = math.max(1, #entries), #requirements do
				if self:integrate(token, branchIndex, i) then
					return true
				elseif not self:complete(branchIndex, i) then
					break
				end

				-- Remove incomplete branches on last node in the requirement since no further integration will be done
				local entry = entries[i]
				local node = entry[#entry]

				if getmetatable(node) == RuleNode then --- @cast node RuleNode
					node:cull()
				end
			end
		end
	else
		local indices = {
			valid = {},
			invalid = {},
			recursive = {}
		}

		-- Attempt to integrate the token into every branch, keeping track of the outcomes
		for i in pairs(self.branches) do
			if self:integrate(token, i) then
				indices.valid[i] = true
			else
				local requirements = self.symbol.branches[i].requirements
				local entries = self.branches[i]

				-- Categorize recursive branches
				if
					requirements[#entries].symbol == self.symbol
					and (#entries == 1 or #entries == #requirements)
				then
					indices.recursive[i] = true
				else
					indices.invalid[i] = true
				end
			end
		end

		-- Since all branches except recursive ones were invalidated, attempt to solve recursion
		if not next(indices.valid) and next(indices.recursive) then
			local root = self:clone()

			for i in pairs(indices.recursive) do --- @cast i number
				local branch = self.symbol.branches[i]
				local requirements = branch.requirements
				local entries = self.branches[i]
				local entry = entries[#entries]

				if #entries == #requirements and #entry == 0 then -- Handle right recursion
					local right = RuleNode:new(self.symbol)
					entry[1] = right

					-- Prevent further left recursion from branches with lower or equal precedence
					right:cull(function(node, rightBranchIndex, rightEntries)
						local rightBranch = node.symbol.branches[rightBranchIndex]
						local rightRequirements = rightBranch.requirements

						return (
							#rightEntries == 0
							and rightBranchIndex >= i
							and (
								(
									rightBranch.assoc == "left"
									and rightRequirements[1].symbol == self.symbol
								) or (
									rightBranch.assoc == "right"
									and branch.assoc == "right"
									and rightRequirements[#rightRequirements].symbol == self.symbol
								)
							)
						)
					end)

					-- Apply new right side if valid
					if self:integrate(token, i) then
						indices.valid[i] = true
					else
						entry[1] = nil
					end
				else -- Handle left recursion
					-- Move self into first requirement entry
					local left = root:clone()
					self.branches[i] = {{left}, {}}

					-- Prevent further recursion
					left:cull()

					-- Check if movement was valid, otherwise reset branch
					if self:integrate(token, i) then
						indices.valid[i] = true
					else
						self.branches[i] = entries
					end
				end
			end
		end

		-- Return true as long as one branch integrated successfully
		if next(indices.valid) then
			-- Cull invalid branches
			for i in pairs(indices.invalid) do
				self.branches[i] = nil
			end

			-- Reset invalid recursive branches
			for i in pairs(indices.recursive) do
				if not indices.valid[i] then
					self.branches[i] = {}
				end
			end

			return true
		end
	end

	return false
end

return RuleNode