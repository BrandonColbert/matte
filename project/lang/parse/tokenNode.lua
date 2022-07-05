local Node = require "lang.parse.node"
local Escape = require "utils.escape"

--- A node correlated with a particular token
--- @class TokenNode: Node
--- @field symbol Token Token being realized
--- @field token Lexer.Section Signifies the token used to fulfill the requirement
local TokenNode = {}
TokenNode.__index = TokenNode
setmetatable(TokenNode, Node)

--- @param token Token Token being realized
--- @param depth? number Current depth in the syntax tree
--- @return TokenNode
function TokenNode:new(token, depth)
	local o = Node:new(token, depth)
	o.token = nil

	setmetatable(o, self)

	return o
end

--- @return Lexer.Section[]
function TokenNode:getTokens()
	if self.token then
		return {self.token}
	end

	return Node.getTokens(self)
end

--- @return TokenNode
function TokenNode:clone()
	local node = TokenNode:new(self.symbol, self.depth)
	node.token = self.token

	return node
end

--- @return boolean
function TokenNode:complete()
	if self.token then
		return true
	end

	return Node.complete(self)
end

--- @param token? Lexer.Section
--- @return boolean
function TokenNode:integrate(token)
	if token then
		-- If no token already exists and the token is applicable, use it
		if not self:complete() and token:is(self.symbol) then
			self.token = token
			return true
		end
	else
		return true
	end

	return Node.integrate(self, token)
end

--- @return number
function TokenNode:__len()
	return Node.__len(self)
end

--- @return string
function TokenNode:__tostring()
	if self.token then
		return string.format(
			[[{"symbol":"%s","value":"%s"}]],
			Escape.json(tostring(self.symbol)),
			Escape.json(self.token.text)
		)
	end

	return Node.__tostring(self)
end

return TokenNode