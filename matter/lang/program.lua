local TokenNode = require "matter.lang.parse.tokenNode"
local RuleNode = require "matter.lang.parse.ruleNode"
local Buffer = require "matter.utils.buffer"
local list = require "matter.utils.list"
local status = require "matter.utils.status"

--- Creates a program by translating nodes into text
--- @class Program
--- @field translator Translator
--- @field buffer Buffer String buffer for the resulting lua text
--- @field depth number Indentation depth for new lines
local Program = {}
Program.__index = Program

--- @param translator Translator
function Program:new(translator)
	local o = {
		translator = translator,
		buffer = Buffer:new(),
		depth = 0
	}

	return setmetatable(o, self)
end

--- Translate the node and write it into the buffer
--- @param node Node Node to translate
function Program:translate(node)
	if not node.symbol.label then
		status:except{"Unable to translate node with anonymous symbol '%s'", fmt={node.symbol}, cat="program"}
	end

	if getmetatable(node) == TokenNode then --- @cast node TokenNode
		local translation = self.translator:get(node.symbol.label)

		if translation == true then
			-- Write the node's value by default
			self:write(node.value)
		else --- @cast translation TokenTranslation
			-- Call token translation
			translation(self, node.value)
		end
	elseif getmetatable(node) == RuleNode then --- @cast node RuleNode
		-- No translation exists if the node is incomplete
		if not node:complete() then
			return
		end

		local branchIndex, branch, entries = node:getMainBranch()
		local translation = self.translator:get(node.symbol.label, branchIndex)

		if translation == true then
			-- Translate each node by default
			for entry in list(entries) do
				for node in list(entry) do
					self:translate(node)
				end
			end
		else
			-- Call rule translation
			translation(self, list(branch.requirements):map(function(requirement, requirementIndex)
				--- @cast requirement Rule.Requirement
				if requirement:isSingular() then
					return entries[requirementIndex][1] or false
				else
					return entries[requirementIndex]
				end
			end):unpack())
		end
	else
		status:except{"Only token or rule nodes may be translated!"}
	end
end

--- Write the string into the buffer
--- @param text string
function Program:write(text)
	if #self.buffer == 0 or self.buffer:at(-1) == "\n" then
		self.buffer:push(string.rep("\t", self.depth))
	end

	self.buffer:push(text)
end

--- Write the string into the buffer and move to the next line
--- @param text? string
function Program:line(text)
	if text then
		self:write(text)
	end

	self:write("\n")
end

function Program:space()
	self:write(" ")
end

--- Increase indenation depth
function Program:push()
	self.depth = self.depth + 1
end

-- Decrease indentation depth
function Program:pop()
	self.depth = self.depth - 1

	if self.depth < 0 then
		status:except{"Transpilation depth fell below 0..."}
	end
end

--- Write the text then increase indentation depth
--- @param text string
function Program:pushWrite(text)
	self:write(text)
	self:push()
end

--- Decrease indentation depth then write the text
--- @param text string
function Program:popWrite(text)
	self:pop()
	self:write(text)
end

--- Write the line then increase indentation depth
--- @param text? string
function Program:pushLine(text)
	self:line(text)
	self:push()
end

--- Decrease indentation depth then write the line
--- @param text? string
function Program:popLine(text)
	self:pop()
	self:line(text)
end

--- Returns the current program text
--- @return string
function Program:__tostring()
	return tostring(self.buffer)
end

return Program