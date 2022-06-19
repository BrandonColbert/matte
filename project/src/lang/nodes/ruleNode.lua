local Node = require "src.lang.nodes.node"
local TokenNode = require "src.lang.nodes.tokenNode"
local Token = require "src.lang.symbols.token"
local Rule = require "src.lang.symbols.rule"

--[[
	symbol: Rule
		Rule being realized
	branches: {[number]: Node[][]}
		Each branch consists of a key that is the associated requirement set index and a value that is a list of entries where each entry is a homogeneous list of nodes.

		Signifies the nodes used to fulfill each requirement in the rule.
		Each entry is a group of nodes.
		A single requirement may be fulfilled with multiple or zero nodes based on its associated quantifier.
]]
local RuleNode = {}
RuleNode.__index = RuleNode
setmetatable(RuleNode, Node)

--[[
	rule: Rule
	depth?: number
]]
function RuleNode:new(rule, depth)
	local o = Node:new(rule, depth)
	o.branches = {}
	setmetatable(o, self)

	for i = 1, #rule.rsets do
		o.branches[i] = {}
	end

	return o
end

function RuleNode:getTokens()
	local _, branch = next(self.branches)

	if branch then
		local tokens = {}

		for i = 1, #branch do
			for j = 1, #branch[i] do
				local subtokens = branch[i][j]:getTokens()

				for k = 1, #subtokens do
					table.insert(tokens, subtokens[k])
				end
			end
		end

		return tokens
	end

	return Node.getTokens(self)
end

function RuleNode:clone()
	local clone = RuleNode:new(self.symbol, self.depth)
	clone.branches = {}

	for i, entries in pairs(self.branches) do
		local clonedEntries = {}

		for _, entry in ipairs(entries) do
			local clonedEntry = {}

			for _, node in ipairs(entry) do
				if node == self then
					table.insert(clonedEntry, clone)
				else
					table.insert(clonedEntry, node:clone())
				end
			end

			table.insert(clonedEntries, clonedEntry)
		end

		clone.branches[i] = clonedEntries
	end

	return clone
end

function RuleNode.__len(o)
	return Node.__len(o)
end

function RuleNode.__tostring(o)
	local textBranches = {}

	for index, entries in pairs(o.branches) do
		local textEntries = {}

		for _, entry in ipairs(entries) do
			local textNodes = {}

			for _, node in ipairs(entry) do
				if node == o then
					table.insert(textNodes, [["self"]])
				else
					table.insert(textNodes, tostring(node))
				end
			end

			table.insert(textEntries, string.format(
				"[%s]",
				table.concat(textNodes, ",")
			))
		end

		table.insert(textBranches, string.format(
			[=["%d":{"reqs":"%s","entries":[%s]}]=],
			index,
			o.symbol.rsets[index],
			table.concat(textEntries, ",")
		))
	end

	return string.format(
		[[{"symbol":"%s","branches":{%s}}]],
		tostring(o.symbol),
		table.concat(textBranches, ",")
	)
end

function RuleNode:complete(branchIndex, requirementIndex)
	if branchIndex then
		local rset = self.symbol.rsets[branchIndex]
		local entries = self.branches[branchIndex]

		if requirementIndex then
			local requirement = rset.requirements[requirementIndex]
			local entry = entries[requirementIndex]

			if not entry then
				return false
			else
				for _, node in ipairs(entry) do
					if node == self then
						return false
					end
				end
			end

			if #requirement.quantifier == 0 then
				if #entry == 0 then
					return false
				elseif #entry == 1 then
					if not entry[1]:complete() then
						return false
					end
				else
					error("'" .. tostring(self.symbol) .. "' only accepts 1 node at requirement " .. requirementIndex)
				end
			elseif requirement.quantifier == "?" then
				if #entry == 1 then
					if not entry[1]:complete() then
						return false
					end
				elseif #entry > 1 then
					error("'" .. tostring(self.symbol) .. "' only accepts up to 1 node at requirement " .. requirementIndex)
				end
			elseif requirement.quantifier == "+" then
				if #entry == 0 then
					return false
				else
					for j = 1, #entry do
						if not entry[j]:complete() then
							return false
						end
					end
				end
			elseif requirement.quantifier == "*" then
				for j = 1, #entry do
					if not entry[j]:complete() then
						return false
					end
				end
			end

			return true
		else
			for i = 1, #rset.requirements do
				if not self:complete(branchIndex, i) then
					return false
				end
			end

			return true
		end
	else
		for i in pairs(self.branches) do
			if self:complete(i) then
				return true
			end
		end
	end

	return Node.complete(self)
end

function RuleNode:integrate(token, branchIndex, entryIndex, nodeIndex)
	if token then
		if branchIndex then
			local entries = self.branches[branchIndex]
			local rset = self.symbol.rsets[branchIndex]

			if entryIndex then
				if not entries[entryIndex] then
					entries[entryIndex] = {}
				end

				local entry = entries[entryIndex]
				local requirement = rset.requirements[entryIndex]

				if nodeIndex then
					local node = entry[nodeIndex]

					if not node then
						if getmetatable(requirement.symbol) == Token then
							node = TokenNode:new(requirement.symbol, self.depth + 1)
						elseif getmetatable(requirement.symbol) == Rule then
							node = RuleNode:new(requirement.symbol, self.depth + 1)
						end
					end

					-- Recursive
					if
						entryIndex == 1
						and nodeIndex == 1
						and node.symbol == self.symbol
					then
						if not entry[nodeIndex] then
							entry[nodeIndex] = self
						end

						return false
					end

					-- Terminal
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
					then
						return self:integrate(token, branchIndex, entryIndex, 1)
					elseif
						requirement.quantifier == "+"
						or requirement.quantifier == "*"
					then
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
				for i = math.max(1, #entries), #rset do
					if self:integrate(token, branchIndex, i) then
						return true
					elseif not self:complete(branchIndex, i) then
						break
					end
				end
			end
		else
			self:log(tostring(self.symbol) .. " <- " .. tostring(token))

			local indices = {
				valid = {},
				invalid = {},
				recursive = {}
			}

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
			
			if #indices.valid == 0 then
				local anyComplete = false

				for _, v in ipairs(indices.invalid) do
					if self:complete(v) then
						anyComplete = true
						break
					end
				end

				if anyComplete then
					for _, v in ipairs(indices.recursive) do
						self.branches[v][1][1] = self:clone()

						if self:integrate(token, v) then
							table.insert(indices.valid, v)
						else
							table.insert(indices.invalid, v)
						end
					end
				end
			end

			if #indices.valid > 0 then
				for _, v in ipairs(indices.invalid) do
					self.branches[v] = nil
				end

				return true
			end
		end
	else
		if self:complete() then
			local incomplete = {}

			for i in pairs(self.branches) do
				if not self:complete(i) then
					table.insert(incomplete, i)
				end
			end

			for _, v in ipairs(incomplete) do
				self.branches[v] = nil
			end

			for _, entries in pairs(self.branches) do
				for _, entry in ipairs(entries) do
					for _, node in ipairs(entry) do
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