local Rule = require "lang.symbols.rule"
local Token = require "lang.symbols.token"
local Escape = require "utils.escape"

--- Basic building block of a syntax tree
--- @class Node
--- @field symbol Symbol Token or rule being realized
--- @field depth number Current depth in the syntax tree
local Node = {}
Node.__index = Node

--- @param symbol Symbol Token or rule being realized
--- @param depth? number Current depth in the syntaxt tree or 0 if unspecified
--- @return Node
function Node:new(symbol, depth)
	local o = {
		symbol = symbol,
		depth = depth or 1
	}

	setmetatable(o, self)

	return o
end

--- Returns all the integrated tokens
--- @return Lexer.Section[]
function Node:getTokens()
	return {}
end

--- Returns a new node with deep copied requirement entries (not the tokens themselves, but their containers)
--- @return Node
function Node:clone()
	return Node:new(self.symbol, self.depth)
end

--- Returns whether any requirement set has been satisfied
--- @return boolean
function Node:complete()
	return false
end

--- Attempts to use the token to fulfill this node's requirements.
---
--- Returns whether the token could be integrated or not
--- @param token? Lexer.Section A lexed token
--- @return boolean
function Node:integrate(token)
	return false
end

--- Prints a message with indentation corresponding to depth in the syntax tree
--- @param ... string Messages to join with a tab
function Node:log(...)
	print(string.format("%s%d) %s",
		table.concat(list{" "}:repeated(self.depth):table()),
		self.depth,
		table.concat({...}, "\t")
	))
end

--- Adjust depth for this node and every child
--- @param delta number
function Node:adjustDepth(delta)
	self.depth = self.depth + delta
end

--- Returns the number of integrated tokens
--- @return number
function Node:__len()
	return #self:getTokens()
end

--- Returns the node formatted as a JSON string
--- @return string
function Node:__tostring()
	return string.format(
		[[{"symbol":"%s"}]],
		Escape.json(tostring(self.symbol))
	)
end

return Node