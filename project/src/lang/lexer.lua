local Symbol = require "src.lang.symbols.symbol"
local list = require "src.utils.list"

--- Acquires tokens from source code.
--- @class Lexer
--- @field content string Remaining characters to be tokenized
local Lexer = {}
Lexer.__index = Lexer

--- @param src string Source code to convert into tokens
function Lexer:new(src)
	local o = {content=src}
	setmetatable(o, self)

	return o
end

--- Returns the next token from the source
--- @return Lexer.Token
function Lexer:nextToken()
	-- Ensure first character is non-whitespace
	if #self.content > 0 then
		self.content = self.content:gsub("^%s+", "")
	end

	-- If there are no characters there is no token
	if #self.content == 0 then
		return nil
	end

	-- Find token symbols which match the longest amount remaining text
	local matches = {}
	local value = nil
	local token = nil

	-- Check token symbols in insertion order
	for symbol in Symbol.getTokens() do
		for pattern in list(symbol.patterns):values() do
			local text = self.content:match("^" .. pattern)
			
			-- Add to matches if the matched text is longer than or equal to the current longest remaining text
			if text and (not value or #text >= #value) then
				table.insert(matches, {text, symbol})
				value = text
			end
		end
	end

	-- Create the token if there was text that could be matched
	if value and #value > 0 then
		local directSymbols = {}
		local patternSymbols = {}

		-- Find and separate the direct and pattern matches
		for match in list(matches):values() do
			local text = match[1]
			local symbol = match[2]

			if #text == #value then
				if Symbol.isDirectTokenName(symbol.name) then
					table.insert(directSymbols, symbol)
				elseif Symbol.isPatternTokenName(symbol.name) then
					table.insert(patternSymbols, symbol)
				end
			end
		end

		-- Create the token with the longest matched text
		token = Lexer.Token:new(value)

		-- If it exists, attribute the pattern matched symbol which was most recently defined to the token
		if #patternSymbols > 0 then
			token.symbols[list(patternSymbols):at(-1)] = true
		end

		-- Attribute the valid direct symbol to the token
		for symbol in list(directSymbols):values() do
			token.symbols[symbol] = true
		end
	end

	-- Consume the next character if no matching token symbol exists
	if not token then
		token = Lexer.Token:new(self.content:sub(1, 1))
	end

	-- Remove token value from content
	self.content = self.content:sub(1 + #token.value)

	return token
end

--- Returns the number of characters remaining to be tokenized
--- @return number
function Lexer:__len()
	return #self.content
end

--- @class Lexer.Token
--- @field value string Value the token contains
--- @field symbols Token[] Token symbols which the token matches
local Token = {}
Lexer.Token = Token
Lexer.Token.__index = Lexer.Token

--- @param value string Value the token contains
function Lexer.Token:new(value)
	local o = {
		value = value,
		symbols = {}
	}

	setmetatable(o, self)

	return o
end

--- Returns whether the token symbol matches this token
--- @param symbol Token
--- @return boolean
function Lexer.Token:has(symbol)
	return self.symbols[symbol] == true
end

function Lexer.Token:__tostring()
	local textSymbols = {}

	for symbol in pairs(self.symbols) do
		table.insert(textSymbols, tostring(symbol))
	end

	if #textSymbols > 0 then
		return "(" .. table.concat(textSymbols, ", ") .. " '" .. self.value .. "')"
	else
		return "('" .. self.value .. "')"
	end
end

return Lexer