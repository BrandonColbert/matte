local Token = require "src.lang.symbols.token"
local Rule = require "src.lang.symbols.rule"
local TokenNode = require "src.lang.nodes.tokenNode"
local RuleNode = require "src.lang.nodes.ruleNode"

--- @class Parser
--- @field root Node Syntax tree root node
local Parser = {}
Parser.__index = Parser

--- @param entry Symbol Entry point
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
--- @param token Lexer.Token Token to integrate
--- @return boolean
function Parser:integrate(token)
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