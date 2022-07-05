local Translator = require "lang.transpile.translator"
local Buffer = require "utils.buffer"
local Rule = require "lang.lex.rule"
local Token = require "lang.lex.token"
local list = require "utils.list"

--- @class Transpiler
--- @field buffer Buffer String buffer for the resulting lua text
--- @field depth number Indentation depth for new lines
local Transpiler = {}
Transpiler.__index = Transpiler

--- @return Transpiler
function Transpiler:new()
	local o = {
		buffer = Buffer:new(),
		depth = 0
	}

	setmetatable(o, self)

	return o
end

--- Write the string into the buffer
--- @param text string
function Transpiler:write(text)
	if #self.buffer == 0 or self.buffer:at(-1) == "\n" then
		self.buffer:push(table.concat(list{" "}:repeated(self.depth):table()))
	end

	self.buffer:push(text)
end

--- Move to the next line
function Transpiler:line()
	self:write("\n")
end

--- Increase indenation depth
function Transpiler:push()
	self.depth = self.depth + 1
end

-- Decrease indentation depth
function Transpiler:pop()
	self.depth = self.depth - 1

	if self.depth < 0 then
		error("Transpilation depth fell below 0...")
	end
end

--- Translate the node and write it into the buffer
--- @param node Node Node to translate
function Transpiler:append(node)
	if not node.symbol.name then
		error("Only pattern tokens and named rules may be directly appended!")
	elseif getmetatable(node.symbol) == Token then
		--- @type TokenNode
		local tokenNode = node

		--- @type TokenTranslation
		local translator = Translator:get(node.symbol.name)
		translator(self, tokenNode.token.text)
	elseif getmetatable(node.symbol) == Rule then
		--- @type RuleNode
		local ruleNode = node
		local branch, entries = next(ruleNode.branches)
		local requirements = ruleNode.symbol.rsets[branch].requirements

		--- @type RuleTranslation
		local translator = Translator:get(node.symbol.name, branch)
		translator(self, list(entries):map(function(entry, index)
			local requirement = requirements[index]

			if requirement:isSingular() then
				return entry[1] or false
			else
				return entry
			end
		end):unpack())
	end
end

--- Returns the current Lua source
--- @return string
function Transpiler:result()
	return tostring(self.buffer)
end

return Transpiler