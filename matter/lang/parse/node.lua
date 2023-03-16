local Escape = require "matter.utils.escape"

--- Basic building block of a syntax tree
--- @class Node
--- @field symbol Symbol Symbol being realized
--- @field depth number Current depth in the syntax tree
local Node = {}
Node.__index = Node

--- @param symbol Symbol Symbol being realized
--- @return Node
function Node:new(symbol)
	local o = {symbol=symbol, depth=0}
	return setmetatable(o, self)
end

--- Adjust depth for this node
--- @param delta number
function Node:adjustDepth(delta)
	self.depth = self.depth + delta
end

--- Returns a deep copy of this node at depth 0
--- @return Node
function Node:clone()
	return Node:new(self.symbol)
end

--- Returns whether the requirements have been satisfied
--- @return boolean
function Node:complete()
	return false
end

--- Returns this node formatted as a JSON string
--- @return string
function Node:__tostring()
	return string.format(
		[[{"symbol":"%s"}]],
		Escape.json(tostring(self.symbol))
	)
end

return Node