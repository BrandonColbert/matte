local Node = require "matter.lang.parse.node"
local Escape = require "matter.utils.escape"

--- A node correlated with a particular token
--- @class TokenNode: Node
--- @field symbol Token Token being realized
--- @field value string Text matching the token
local TokenNode = {}
TokenNode.__index = TokenNode
setmetatable(TokenNode, Node)

--- @param token Token Token being realized
--- @param value string Text matching the token
--- @return TokenNode
function TokenNode:new(token, value)
	local o = Node:new(token) --[[@as TokenNode]]
	o.value = value

	return setmetatable(o, self)
end

--- @return Node
function TokenNode:clone()
	return TokenNode:new(self.symbol, self.value)
end

--- @return boolean
function TokenNode:complete()
	return true
end

--- @return string
function TokenNode:__tostring()
	return string.format(
		[[{"symbol":"%s","value":"%s"}]],
		Escape.json(tostring(self.symbol)),
		Escape.json(self.value)
	)
end

return TokenNode