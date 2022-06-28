local Symbol = require "lang.symbols.symbol"
local list = require "utils.list"
local pick = require "utils.pick"

--- Acquires tokens from source code.
--- @class Lexer
--- @field content string Remaining characters to be tokenized
local Lexer = {}
Lexer.__index = Lexer

--- @param src string Source code to convert into tokens
--- @param options? Lexer.Options
--- @return Lexer
function Lexer:new(src, options)
	--- @type Lexer
	local o = {content = src}
	setmetatable(o, self)

	return o
end

--- Returns the next section from the source
--- @return Lexer.Section
function Lexer:next()
	-- If there are no characters, there is no section
	if #self.content == 0 then
		return nil
	end

	-- Find tokens which match the longest amount remaining text
	local matches = {}
	local text, section

	-- Check tokens in insertion order
	for token in list(Symbol.Registry.getTokens()):values() do
		for pattern in list(token.patterns):values() do
			local value

			if type(pattern) == "string" then -- String patterns use lua patterns
				value = self.content:match("^" .. pattern)
			elseif type(pattern) == "function" then -- Function patterns accept content and return match
				value = pattern(self.content)
			else
				error(string.format("Unknown pattern type '%s'", type(pattern)))
			end
			
			-- Add to matches if the matched text is longer than or equal to the current longest remaining text
			if value and (not text or #value >= #text) then
				table.insert(matches, {value, token})
				text = value
			end
		end
	end

	-- Create the section if there was text that could be matched
	if text and #text > 0 then
		local directToken, patternToken

		-- Find the most recently defined direct and pattern tokens that match
		for match in list(matches):values() do
			local value = match[1]
			local token = match[2]

			if #value == #text then
				if Symbol.Name.isDirectToken(token.name) then
					directToken = token
				elseif Symbol.Name.isPatternToken(token.name) then
					patternToken = token
				end
			end
		end

		-- Create the token with the longest matched text
		section = Lexer.Section:new(text)

		-- Add valid tokens
		if patternToken then
			section.tokens[patternToken] = true
		end

		if directToken then
			section.tokens[directToken] = true
		end
	end

	-- Return nothing since tokenization failed
	if not section then
		return nil
	end

	-- Remove section text from content
	self.content = self.content:sub(1 + #section.text)

	return section
end

--- Returns the number of characters remaining to be tokenized
--- @return number
function Lexer:__len()
	return #self.content
end

--- Section of text from the source code matching a set of tokens
--- @class Lexer.Section
--- @field text string Text composing this section
--- @field tokens table<Token, boolean> Tokens which this section matches
local Section = {}
Lexer.Section = Section
Lexer.Section.__index = Lexer.Section

--- @param text string Text composing this section
function Lexer.Section:new(text)
	local o = {text=text, tokens={}}
	setmetatable(o, self)

	return o
end

--- Returns whether this section matches the specified token
--- @param token Token Token to check if matching
--- @return boolean
function Lexer.Section:is(token)
	return self.tokens[token] == true
end

function Lexer.Section:__tostring()
	local textTokens = {}
	
	for token in pairs(self.tokens) do
		table.insert(textTokens, tostring(token))
	end

	if #textTokens > 0 then
		return string.format("(%s '%s')", table.concat(textTokens, ", "), self.text)
	else
		return string.format("('%s')", self.text)
	end
end

return Lexer