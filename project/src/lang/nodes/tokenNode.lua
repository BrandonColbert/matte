local Node = require "src.lang.nodes.node"

--[[
	symbol: Token
		Token being realized
	token: Lexer.Token
		Signifies the token value used to fulfill the requirement
]]
local TokenNode = {}
TokenNode.__index = TokenNode
setmetatable(TokenNode, Node)

--[[
	token: Token
		Token being realized
	depth?: number
		Current depth in the syntax tree
]]
function TokenNode:new(token, depth)
	local o = Node:new(token, depth)
	o.token = nil

	setmetatable(o, self)

	return o
end

function TokenNode:getTokens()
	if self.token then
		return {self.token}
	end

	return Node.getTokens(self)
end

function TokenNode:clone()
	local node = TokenNode:new(self.symbol, self.depth)
	node.token = self.token

	return node
end

function TokenNode:complete()
	if self.token then
		return true
	end

	return Node.complete(self)
end

function TokenNode:integrate(token)
	if token then
		self:log(tostring(self.symbol) .. " <- " .. tostring(token))

		if not self:complete() and token:has(self.symbol) then
			self.token = token
			return true
		end
	else
		return true
	end

	return Node.integrate(self, token)
end

function TokenNode.__len(o)
	return Node.__len(o)
end

function TokenNode.__tostring(o)
	if o.token then
		return string.format(
			[[{"symbol":"%s","value":"%s"}]],
			tostring(o.symbol),
			tostring(o.token.value)
		)
	end

	return Node.__tostring(o)
end

return TokenNode