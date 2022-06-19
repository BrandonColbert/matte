local Symbol = require "src.lang.symbols.symbol"

--[[
	Denotes sections of text as having specific meanings

	name: string
		Token name
	patterns: string[]
		Patterns used to classify text as this Token
]]
local Token = {}
Token.__index = Token
setmetatable(Token, Symbol)

--[[
	Creates and registers a named token.

	name: string
		Token name
	...patterns: string[]
		Should a string match any of the patterns, it may be classified as this Token

	-OR-

	Creates a token that matches the content directly. Should this token already be registered, it will return the existing one rather than creating a new one.

	content: string
		Should a string match this content, it may be classified as this Token

]]
function Token:new(...)
	local name, patterns
	local args = {...}

	if #args == 1 then -- Direct
		name = "<" .. args[1] .. ">"

		local escapedPattern = args[1]:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
		patterns = {escapedPattern}
	else -- Pattern
		name = table.remove(args, 1)
		patterns = args
	end

	local o = Symbol:new(name)
	o.patterns = patterns
	setmetatable(o, self)

	return o
end

function Token.__len(o)
	return 1
end

function Token.__bor(lhs, rhs)
	local Rule = require "src.lang.symbols.rule"

	-- Coerce left side into rule
	if type(lhs) == "table" and getmetatable(lhs) == Token then
		lhs = Rule:new(lhs)
	else
		error(
			"Left hand side must be a token: "
			.. tostring(lhs) .. " | " .. tostring(rhs)
		)
	end

	-- Coerce right side into rule to use as alternative
	if type(rhs) == "table" then
		if getmetatable(rhs) == Token then
			rhs = Rule:new(rhs)
		elseif getmetatable(rhs) ~= Rule then
			error(
				"Right hand side must be a token or rule: "
				.. tostring(lhs) .. " | " .. tostring(rhs)
			)
		end
	else
		error(
			"Right hand side must be a table: "
			.. tostring(lhs) .. " | " .. tostring(rhs)
		)
	end

	return Rule.unify(lhs, rhs)
end

function Token.__tostring(o)
	return Symbol.__tostring(o)
end

return Token