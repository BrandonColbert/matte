local Token = require "lang.symbols.token"
local Rule = require "lang.symbols.rule"
local TokenNode = require "lang.nodes.tokenNode"
local RuleNode = require "lang.nodes.ruleNode"

--- @class Parser
--- @field root Node Syntax tree root node
local Parser = {}
Parser.__index = Parser

--- @param entry Symbol Entry point
--- @return Parser
function Parser:new(entry)
	local o = {}

	if getmetatable(entry) == Token then
		o.root = TokenNode:new(entry)
	elseif getmetatable(entry) == Rule then
		o.root = RuleNode:new(entry)
	else
		error("Entry point must be a symbol!")
	end

	setmetatable(o, self)

	return o
end

--- Returns whether the the token could be integrated into the syntax tree
--- @param token Lexer.Section Token to integrate
--- @return boolean
function Parser:integrate(token)
	-- Always succeed for tokens that may be ignored
	if token then
		for t in pairs(token.tokens) do
			if t.comment then
				return true
			end
		end
	end

	return self.root:integrate(token)
end

--- Returns the root node of the syntax tree
--- @return Node
function Parser:getTree()
	return self.root
end

--- Returns the number of tokens in the tree
--- @return number
function Parser:__len()
	return #self.root
end

return Parser