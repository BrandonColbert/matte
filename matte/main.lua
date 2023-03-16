local Symbol = require "matter.lang.syntax.symbol"
local matte = require "matte.matte"
local list = require "matter.utils.list"

-- Initialize translations
local tokens = list(matte.grammar.names.tokens)
	:filter(function(name)
		return Symbol.Name.isPatternToken(name)
	end)
	:map(function(name)
		return string.format("tokens.%s", name:gsub("^%u", string.lower))
	end)

local rules = list(matte.grammar.names.rules)
	:map(function(name)
		return string.format("rules.%s", name:gsub("_(%a)", string.upper))
	end)

local symbols = (tokens + rules)
	:map(function(filename)
		return string.format("matte.%s", filename)
	end)
	:filter(function(path)
		if package.loaded[path] then
			return true
		end

		for searcher in list(package.searchers) do
			if type(searcher(path)) == "function" then
				return true
			end
		end

		return false
	end)

for path in symbols:values() do
	-- require(path)
end

return matte:process()