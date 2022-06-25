local Node = require "lang.nodes.node"
local TokenNode = require "lang.nodes.tokenNode"
local Rule = require "lang.symbols.rule"
local Token = require "lang.symbols.token"
local Escape = require "utils.escape"
local list = require "utils.list"

--- A node correlated with a particular rule
--- @class RuleNode: Node
--- @field symbol Rule Rule being realized
--- @field branches table<number, Node[][]> Each branch consists of a key that is the associated requirement set index and a value that is a list of entries where each entry is a homogeneous list of nodes that fulfills the corresponding requirement.
--- @field meta Node Self referential node for left recursive rules
local RuleNode = {}
RuleNode.__index = RuleNode
setmetatable(RuleNode, Node)

--- @param rule Rule Rule being realized
--- @param depth? number Current depth in the syntax tree
--- @return RuleNode
function RuleNode:new(rule, depth)
	local o = Node:new(rule, depth)
	o.branches = {}
	setmetatable(o, self)

	-- Create a branch for each requirement set
	for i = 1, #rule.rsets do
		local entries = {}
		o.branches[i] = entries

		-- If the set's first requirement is the same as the rule, the set is recursive
		local requirement = rule.rsets[i].requirements[1]

		if requirement.symbol == rule then
			if requirement:isOptional() then
				error("First requirement of a left recursive rule may not be optional.")
			end

			-- Prepare set for recursion
			local entry = {o}
			table.insert(entries, entry)
		end
	end

	return o
end

--- Adjust depth for this node and every child
--- @param delta number
function RuleNode:adjustDepth(delta)
	-- Adjust depth for children
	for _, entries in pairs(self.branches) do
		for entry in list(entries):values() do
			for node in list(entry):values() do
				if node ~= self then
					node:adjustDepth(delta)
				end
			end
		end
	end

	-- Adjust own depth
	Node.adjustDepth(self, delta)
end

--- @return Lexer.Section[]
function RuleNode:getTokens()
	-- Meta override
	if self.meta and self.meta ~= self then
		return self.meta:getTokens()
	end

	-- Get tokens from the first encountered branch
	for i, entries in pairs(self.branches) do
		if not (
			#entries == 1
			and #entries[1] == 1
			and entries[1][1] == self
		) then
			local tokens = {}

			-- Conglomerate tokens from each child node
			for entry in list(entries):values() do
				for node in list(entry):values() do
					for subtoken in list(node:getTokens()):values() do
						table.insert(tokens, subtokens)
					end
				end
			end
	
			return tokens
		end
	end

	return Node.getTokens(self)
end

--- @return RuleNode
function RuleNode:clone()
	local clone = RuleNode:new(self.symbol, self.depth)
	clone.branches = {}

	-- Create meta branch
	if self.meta then
		if self.meta == self then
			clone.meta = clone
		else
			clone.meta = self.meta:clone()
		end
	end

	-- Create and assign copies of each branch
	for i, entries in pairs(self.branches) do
		clone.branches[i] = list(entries)
			:map(function(entry)
				return list(entry)
					:map(function(node)
						if node == self then -- Return the root node if recursive
							return clone
						else -- Return a copy otherwise
							return node:clone()
						end
					end)
					:table()
			end)
			:table()
	end

	return clone
end

--- @return number
function RuleNode:__len()
	return Node.__len(self)
end

--- @return string
function RuleNode:__tostring()
	--- @param node Node
	--- @return string
	local function nts(node)
		if node == self then
			return [["self"]]
		else
			return tostring(node)
		end
	end

	local textBranches = {}

	-- Convert meta node into a string for branch 0
	if self.meta then
		table.insert(textBranches, string.format(
			[=["0":{"reqs":"%s","entries":[[%s]]}]=],
			Escape.json(tostring(self.meta.symbol)),
			nts(self.meta)
		))
	end

	-- Convert branches into strings
	for index, entries in pairs(self.branches) do
		table.insert(textBranches, string.format(
			[=["%d":{"reqs":"%s","entries":[%s]}]=],
			index,
			Escape.json(tostring(self.symbol.rsets[index])),
			table.concat(list(entries)
				:map(function(entry) -- Convert entries into strings
					return string.format("[%s]", table.concat(list(entry)
						:map(nts) -- Convert nodes into strings
						:table(),
					","))
				end)
				:table(),
			",")
		))
	end

	return string.format(
		[[{"symbol":"%s","branches":{%s}}]],
		Escape.json(tostring(self.symbol)),
		table.concat(textBranches, ",")
	)
end

--- @param branchIndex? number Branch to check for fulfillment
--- @param requirementIndex? number Requirement to check for fulfillment
--- @return boolean
function RuleNode:complete(branchIndex, requirementIndex)
	if branchIndex then
		local rset = self.symbol.rsets[branchIndex]
		local entries = self.branches[branchIndex]

		if requirementIndex then
			local requirement = rset.requirements[requirementIndex]
			local entry = entries[requirementIndex]

			-- The entry must be present even if it accepts 0 instances
			if not entry then
				return false
			end

			if #requirement.quantifier == 0 then
				if #entry == 0 then -- Empty quantifier requires one entry
					return false
				elseif #entry == 1 then -- Ensure the entry is complete
					if entry[1] == self or not entry[1]:complete() then
						return false
					end
				else
					error(string.format("'%s' only accepts 1 node at requirement %d", self.symbol, requirementIndex))
				end
			elseif requirement.quantifier == "?" then
				if #entry == 1 then -- If an entry exists, ensure it is complete
					if entry[1] == self or not entry[1]:complete() then
						return false
					end
				elseif #entry > 1 then
					error(string.format("'%s' only accepts up to 1 node at requirement %d", self.symbol, requirementIndex))
				end
			elseif requirement.quantifier == "+" then
				if #entry == 0 then -- Requires at least one entry
					return false
				else -- Ensure all entries are complete
					for j = 1, #entry do
						if entry[j] == self or not entry[j]:complete() then
							return false
						end
					end
				end
			elseif requirement.quantifier == "*" then
				for j = 1, #entry do -- Ensure all entries are complete
					if entry[j] == self or not entry[j]:complete() then
						return false
					end
				end
			end

			return true
		else
			-- Return true if all the requirements of the specified branch are complete
			for i = 1, #rset.requirements do
				if not self:complete(branchIndex, i) then
					return false
				end
			end

			return true
		end
	else
		-- Meta override
		if self.meta and self.meta ~= self then
			return self.meta:complete()
		end

		-- Return true if at least one branch is complete
		for i in pairs(self.branches) do
			if self:complete(i) then
				return true
			end
		end
	end

	return Node.complete(self)
end

--- @param token? Lexer.Section
--- @param branchIndex? number Branch to integrate the token into
--- @param entryIndex? number Entry to integrate the token into
--- @param nodeIndex? number Node to integrate the token into
--- @return boolean
function RuleNode:integrate(token, branchIndex, entryIndex, nodeIndex)
	if token then
		if branchIndex then
			local entries = self.branches[branchIndex]
			local rset = self.symbol.rsets[branchIndex]

			if entryIndex then
				-- Create the entry if it did not exist
				if not entries[entryIndex] then
					entries[entryIndex] = {}
				end

				local entry = entries[entryIndex]
				local requirement = rset.requirements[entryIndex]

				if nodeIndex then
					local node = entry[nodeIndex]

					-- Create the node if it does not exist
					if not node then
						if getmetatable(requirement.symbol) == Token then
							node = TokenNode:new(requirement.symbol, self.depth + 1)
						elseif getmetatable(requirement.symbol) == Rule then
							node = RuleNode:new(requirement.symbol, self.depth + 1)
						end
					end

					-- Automatically fail for the first node of a recursive requirement entry
					if
						entryIndex == 1
						and nodeIndex == 1
						and node == self
					then
						return false
					end

					-- Attempt to integrate the token, adding the node if successful
					if node:integrate(token) then
						if not entry[nodeIndex] then
							entry[nodeIndex] = node
						end

						return true
					end
				else
					if
						#requirement.quantifier == 0
						or requirement.quantifier == "?"
					then -- Single and optional quantifiers may only have one node in their entry
						return self:integrate(token, branchIndex, entryIndex, 1)
					elseif
						requirement.quantifier == "+"
						or requirement.quantifier == "*"
					then -- Attempt to integrate into the latest incomplete node in the entry
						nodeIndex = math.max(1, #entry)

						if self:integrate(token, branchIndex, entryIndex, nodeIndex) then
							return true
						elseif
							entry[nodeIndex]
							and entry[nodeIndex]:complete()
						then
							return self:integrate(token, branchIndex, entryIndex, nodeIndex + 1)
						end
					else
						error("Unknown quantifier '" .. requirement.quantifier .. "'")
					end
				end
			else
				-- Attempt to integrate into the next incomplete entry as long as the prior entry was complete
				for i = math.max(1, #entries), #rset do
					if self:integrate(token, branchIndex, i) then
						return true
					elseif self:complete(branchIndex, i) then
						-- Remove incomplete branches in entry nodes since requirement index is advancing
						for node in list(self.branches[branchIndex][i]):values() do
							node:integrate()
						end
					else
						break
					end
				end
			end
		else
			self:log(string.format("%s <- %s", self.symbol, token))

			local indices = {
				valid = {},
				invalid = {},
				recursive = {}
			}

			-- Attempt to integrate the token into every branch, keeping track of the outcomes
			for i in pairs(self.branches) do
				if self:integrate(token, i) then
					table.insert(indices.valid, i)
				elseif
					#self.branches[i] == 1
					and #self.branches[i][1] == 1
					and self.branches[i][1][1] == self
				then
					table.insert(indices.recursive, i)
				else
					table.insert(indices.invalid, i)
				end
			end

			-- Since all branches except recursive ones were invalidated, attempt to solve recursion
			if #indices.valid == 0 and #indices.recursive > 0 then
				-- Integrate the token into the existing meta branch if possible
				local success = self.meta and self.meta:integrate(token)

				-- Recreate the meta branch since the current one no longer works
				if not success then
					local node = self:clone()
					node:integrate()

					-- Meta branch may only be created if this node is complete
					if node:complete() then
						-- Create the meta branch
						local meta = self:clone()
						meta.meta = node
	
						for v in list(indices.invalid):values() do
							meta.branches[v] = nil
						end
	
						for v in list(indices.recursive):values() do
							meta.branches[v][1][1] = node:clone()
						end
	
						-- Try new meta branch integration
						if meta:integrate(token) then
							-- If integration worked, the meta branch is saved
							success = true
							meta.meta = nil
							self.meta = meta
						else
							-- If not, further recursion is impossible and the meta branch must be actualized
							success = false
							self.branches = meta.meta.branches
						end
					end
				end

				-- Evaluate the validity of the recursive based on success of the meta branch
				for v in list(indices.recursive):values() do
					if success then
						table.insert(indices.valid, v)
					else
						table.insert(indices.invalid, v)
					end
				end
			end

			-- Return true and cull invalid branches as long as one branch integrated successfully.
			if #indices.valid > 0 then
				for v in list(indices.invalid):values() do
					self.branches[v] = nil
				end

				return true
			end
		end
	else
		-- Meta override
		if self.meta then
			local result = self.meta:integrate()
			self.branches = self.meta.branches
			self.meta = nil

			return result
		end

		-- Remove incomplete branches when no token is specified
		if self:complete() then
			local incomplete = {}

			-- Gather incomplete branches
			for i in pairs(self.branches) do
				if not self:complete(i) then
					table.insert(incomplete, i)
				end
			end

			-- Remove incomplete branches
			for v in list(incomplete):values() do
				self.branches[v] = nil
			end

			-- Do the same for each child node
			for _, entries in pairs(self.branches) do
				for entry in list(entries):values() do
					for node in list(entry):values() do
						if not node:integrate() then
							return false
						end
					end
				end
			end
		end

		return true
	end

	return Node.integrate(self, token)
end

return RuleNode