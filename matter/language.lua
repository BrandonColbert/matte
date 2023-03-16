local Lexer = require "matter.lang.lexer"
local Grammar = require "matter.lang.grammar"
local Translator = require "matter.lang.translator"
local Program = require "matter.lang.program"
local RuleNode = require "matter.lang.parse.ruleNode"
local Rule = require "matter.lang.syntax.rule"
local Token = require "matter.lang.syntax.token"
local status = require "matter.utils.status"
local scope = require "matter.utils.scope"

--- Derives programs from source based on a grammar and translations
--- @class Language
--- @field grammar Grammar
--- @field translator Translator
--- @field env table
local Language = {}
Language.__index = Language

--- @param env? table Runtime environment (defaults to global environment)
--- @return Language
function Language:new(env)
	local o = {}
	o.grammar = Grammar:new()
	o.translator = Translator:new(o.grammar)
	o.env = env or _G

	return setmetatable(o, self)
end

--- Creates a syntax tree for the source and returns the root node
--- @param src string Source adhering to this language's grammar
--- @param entry? string Name of the symbol to use as an entrypoint (defaults to "entry")
--- @return RuleNode
function Language:parse(src, entry)
	-- Acquire entrypoint
	local symbol = self.grammar:get(entry or "entry")

	if getmetatable(symbol) == Token then
		symbol = Rule:new(symbol)
	elseif getmetatable(symbol) ~= Rule then
		status:except{"Specified entry '%s' is not a token or rule", fmt={entry}, cat="parse"}
	end

	-- Create lexer and syntax tree root node
	local lexer = Lexer:new(self.grammar, src)
	local root = RuleNode:new(symbol --[[@as Rule]])

	-- Lex tokens from source and integrate them into the tree
	while #lexer > 0 do
		local token = lexer:next()

		if token then
			if not token.symbol.ignore then
				if not root:integrate(token) and token.symbol.blocking then
					-- Stop parsing if the next token could not be integrated
					status:warn{"Failed to parse: %s\n", fmt={token}}

					return root
				end
			end
		else
			-- Stop parsing if text remains, but no token be acquired
			status:warn{
				"Failed to tokenize [%d-%d] '%s'\n",
				fmt={
					lexer.initialSize - #lexer,
					lexer.initialSize,
					lexer.content:sub(1, 15)
				}
			}

			return root
		end
	end

	return root
end

--- Returns the generated program
--- @param root RuleNode Root node of the syntax tree
--- @return Program
function Language:transpile(root)
	local program = Program:new(self.translator)
	program:translate(root)

	return program
end

--- Runs the code with the specified arguments
--- @param program Program to run
--- @param ... string Command line arguments
--- @return ...
function Language:run(program, ...)
	local f, err = load(tostring(program), nil, nil, scope(self.env))

	if not f then
		status:warn{err}
		return
	end

	return f(...)
end

--- Process standard input based on command line arguments
--- @param input? string Substitute for the result of standard input
--- @return ...
function Language:process(input)
	--- @return string
	local function getInput()
		return input or io.read("*a")
	end

	-- Acquire command line arguments
	--- @class CLParameters
	--- @field mode "run"|"transpile"|"parse" Execution mode
	--- @field module string Run the specified module when in run mode
	--- @field entry string Symbol to use as an entry point when parsing
	--- @field args string Command line arguments when running
	local options = list(arg):reduce(function(o, entry)
		-- Key only argument
		local key = entry:match("^-(%w+)$")

		if key then
			o[key] = true
		else
			-- Key-value argument
			local key, value = entry:match("^-(%w+)=(.*)$")

			if key and value then
				o[key] = value
			else
				status:warn{"Unrecognized parameter: '%s'", fmt={entry}, cat="cli"}
			end
		end

		return o
	end, {}) --[[@as CLParameters]]

	-- Execute based on options
	if not options.mode or options.mode == "run" then
		local args = list()

		-- Get program arguments
		if options.args then
			for arg in string.gmatch(options.args, "[^%s]+") do
				args:push(arg)
			end
		end

		if options.module then
			-- #TODO
			print("MODULE", options.module)
		else
			local src = getInput()
			local ast = self:parse(src, options.entry)
			local program = self:transpile(ast)

			return self:run(program, args:unpack())
		end
	elseif options.mode == "transpile" then
		local src = getInput()
		local ast = self:parse(src, options.entry)
		local program = self:transpile(ast)

		io.stdout:write(tostring(program))

		return program
	elseif options.mode == "parse" then
		local src = getInput()
		local ast = self:parse(src, options.entry)

		io.stdout:write(tostring(ast))

		return ast
	else
		status:except{"Unknown mode '%s'", fmt={options.mode}, cat="cli"}
	end
end

return Language