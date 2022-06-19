local Rule = require "src.lang.symbols.rule"
local Token = require "src.lang.symbols.token"

--[[
	symbol: Symbol
		Token or rule being realized
	depth: number
		Current depth in the syntax tree
]]
local Node = {}
Node.__index = Node

--[[
	symol: Symbol
		Token or rule being realized
	depth?: number
		Current depth in the syntaxt tree (defaults to 0)
]]
function Node:new(symbol, depth)
	local o = {
		symbol = symbol,
		depth = depth or 0
	}

	setmetatable(o, self)

	return o
end

--[[
	Returns: Lexer.Token[]
		All the integrated tokens
]]
function Node:getTokens()
	return {}
end

function Node:clone()
	return Node:new(self.symbol, self.depth)
end

--[[
	Returns true if any requirement set has been satisfied, false otherwise
]]
function Node:complete()
	return false
end

--[[
	Attempts to use the token to fulfill this node's requirements.

	token: Lexer.Token
		A lexed token value

	Returns whether the token could be integrated or not
]]
function Node:integrate(token)
	return false
end

function Node:log(msg)
	local indent = ""

	for i = 1, self.depth do
		indent = indent .. " "
	end

	print(indent .. self.depth .. ") " .. msg)
end

--[[
	Returns the number of integrated tokens
]]
function Node.__len(o)
	return #o:getTokens()
end

--[[
	Returns the node formatted as a JSON string
]]
function Node.__tostring(o)
	return string.format(
		[[{"symbol":"%s"}]],
		tostring(o.symbol)
	)
end

return Node