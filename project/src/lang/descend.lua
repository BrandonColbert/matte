local Lexer = require "lang.lexer"
local Parser = require "lang.parser"
local Symbol = require "lang.symbols.symbol"

--- @class Descend
local Descend = {}
Descend.__index = Descend

--- Creates a syntax tree for the source and returns the root node
--- @param src string Source code
--- @param entry? string | Symbol Entry point
--- @return Node
function Descend.parse(src, entry)
	-- Create parser for the entry
	--- @type Parser
	local parser

	if not entry then
		parser = Parser:new(Symbol("entry"))
	elseif type(entry) == "string" then
		parser = Parser:new(Symbol(entry))
	elseif type(entry) == "table" then
		parser = Parser:new(entry)
	else
		error(string.format("Unable to construct parser from '%s'", entry))
	end

	-- Create lexer for source
	local lexer = Lexer:new(src .. "\n")

	-- Lex tokens from source and integrate them into the tree
	while #lexer > 0 do
		local token = lexer:next()

		if token and not parser:integrate(token) then
			-- Stop parsing if the next token could not be integrated
			io.stderr:write(string.format("\nFailed to parse %s\n", token))

			return parser:getTree()
		end
	end

	-- Indicate no more tokens
	if not parser:integrate() then
		io.stderr:write("\nFailed to complete integration...\n")
	end

	-- Return root node
	return parser:getTree()
end

return Descend