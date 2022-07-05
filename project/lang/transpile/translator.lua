local Symbol = require "lang.lex.symbol"

--- @alias TokenTranslation fun(t: Transpiler, text: string)
--- @alias RuleTranslation fun(t: Transpiler, ...: Node[])
--- @class Translator
--- @field registry table<string, TokenTranslation | table<number, RuleTranslation>>
local Translator = {registry={}}
Translator.__index = Translator


--- Defines a new translation for a symbol
--- @overload fun(symbol: string, translation: TokenTranslation)
--- @param symbol string Symbol to receive a translation
--- @param branch number Branch to translate if the symbol is a rule
--- @param translation RuleTranslation Translation method
function Translator:define(symbol, branch, translation)
	if Symbol.Name.isToken(symbol) then
		translation = branch
		branch = nil

		self.registry[symbol] = translation
	elseif Symbol.Name.isRule(symbol) then
		if type(branch) ~= "number" then
			translation = branch
			branch = 1
		end

		local branches = self.registry[symbol]

		if not branches then
			branches = {}
			self.registry[symbol] = branches
		end

		branches[branch] = translation
	end
end

--- Returns the translation function for the symbol (and branch if a rule)
--- @param symbol string Symbol name
--- @param branch number Rule branch
--- @return TokenTranslation | RuleTranslation
function Translator:get(symbol, branch)
	if branch then
		local translator = (self.registry[symbol] or {})[branch]

		if not translator then
			error(string.format("Unable to find translation for branch %d of rule '%s'",
				branch,
				symbol
			))
		end

		return translator
	else
		local translator = self.registry[symbol]

		if not translator then
			error(string.format("Unable to find translation for token '%s'", symbol))
		end

		return translator
	end
end

return Translator