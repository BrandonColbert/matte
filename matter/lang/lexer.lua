local Token = require "matter.lang.syntax.token"
local TokenNode = require "matter.lang.parse.tokenNode"
local Escape = require "matter.utils.escape"
local list = require "matter.utils.list"
local status = require "matter.utils.status"

--- Uses a gramamr to extract tokens from source
--- @class Lexer
--- @field grammar Grammar
--- @field content string Remaining characters to be tokenized
--- @field initialSize number
local Lexer = {}
Lexer.__index = Lexer

--- @param grammar Grammar Grammar to evaluate source with
--- @param src string Source code to derive tokens from
function Lexer:new(grammar, src)
	local o = {grammar=grammar, content=src, initialSize=#src}
	return setmetatable(o, self)
end

--- Returns the next token from the source
--- @return TokenNode
function Lexer:next()
	-- If there are no characters, no more tokens may be extracted
	if #self.content == 0 then
		return nil
	end

	-- Generate all possible tokens
	local candidates = list()

	for index, name in ipairs(self.grammar.names.tokens) do
		--- @type Token
		local token = self.grammar:get(name)

		for selector in list(token.selectors) do
			--- @type string
			local value

			-- Use selector to select text from content
			if type(selector) == "string" then
				if token.literal then
					selector = Escape.pattern(selector)
				end

				value = self.content:match("^" .. selector)
			elseif type(selector) == "function" then
				value = selector(self.content)
			else
				status:except{"Selector must be string or function, not '%s'", fmt={type(selector)}, cat="lex"}
			end

			-- Add candidate
			if value then
				candidates:push({value, token, index})
			end
		end
	end

	-- Sort to find the token with the longest match. Resolve overlap by using the literal token if it exists or that which was defined earliest
	candidates = candidates:sort(function(left, right)
		local leftValue, leftToken, leftIndex = table.unpack(left)
		--- @cast leftValue string
		--- @cast leftToken Token
		--- @cast leftIndex number

		local rightValue, rightToken, rightIndex = table.unpack(right)
		--- @cast rightValue string
		--- @cast rightToken Token
		--- @cast rightIndex number

		if leftValue == rightValue then
			-- Literal tokens always precede pattern tokens
			if leftToken.literal then
				return not rightToken.literal
			end

			return leftIndex < rightIndex
		end

		return leftValue > rightValue
	end)

	-- Return nothing since tokenization failed
	if #candidates == 0 then
		return nil
	end

	-- Return resulting token node and remove the corresponding text from content
	local value, token = table.unpack(candidates:at(1))
	--- @cast value string
	--- @cast token Token

	self.content = self.content:sub(1 + #value)

	return TokenNode:new(token, value)
end

--- Returns the number of characters remaining to be tokenized
--- @return number
function Lexer:__len()
	return #self.content
end

return Lexer