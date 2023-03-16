local Grammar = require "matter.lang.grammar"
local Symbol = require "matter.lang.syntax.symbol"
local Rule = require "matter.lang.syntax.rule"
local Token = require "matter.lang.syntax.token"
local list = require "matter.utils.list"
local status = require "matter.utils.status"

--- Defines how code is converted from one language into another
--- @class Translator
--- @field registry table<string, TokenTranslation | table<number, RuleTranslation>>
--- @field grammar Grammar
local Translator = {}
Translator.__index = Translator

--- @param grammar Grammar
function Translator:new(grammar)
	local o = {registry={}, grammar=grammar}
	return setmetatable(o, self)
end

--- Defines the default translation for the given symbols or all symbols if none specified
--- @param ... string Names of the symbols to receive the default translation
function Translator:defineDefault(...)
	local names = list{...} --[[@as List<string>]]

	if #names == 0 then
		for name in pairs(self.grammar.symbols) do
			self:define(name)
		end
	else
		for name in names:values() do
			self:define(name)
		end
	end
end

--- Defines a new translation for a symbol.
---
--- If branches is left unspecified for a rule translation, all nameless branches will be considered
--- @param symbolName string Name of the symbol to receive a translation
--- @param branches number|string|(number|string)[] Rule branches to translate
--- @param translation? RuleTranslation Translation function. If none is specified, default translation occurs
--- @overload fun(symbolName: string, translation?: RuleTranslation|TokenTranslation)
function Translator:define(symbolName, branches, translation)
	local symbol = self.grammar:get(symbolName)

	if getmetatable(symbol) == Token then --- @cast symbol Token
		translation, branches = branches, nil
		self.registry[symbolName] = translation or true
	elseif getmetatable(symbol) == Rule then --- @cast symbol Rule
		local translations = self.registry[symbolName]

		if not translations then
			translations = {}
			self.registry[symbolName] = translations
		end

		if not branches or type(branches) == "function" then
			translation, branches = branches, nil

			-- Find all unnamed branches
			for index, branch in ipairs(symbol.branches) do
				if not branch.name then
					self:define(symbolName, index, translation)
				end
			end
		elseif type(branches) == "number" then
			--- @type number
			local branch = nil
			branches, branch = branch, branches

			translations[branch] = translation or true
		elseif type(branches) == "string" then
			--- @type string
			local branchName = nil
			branches, branchName = branchName, branches

			-- Find the branch with the matching name
			local branchIndex = list(symbol.branches):findIndex(function(branch)
				--- @cast branch Rule.Requirement.List
				return branch.name == branchName
			end)

			if branchIndex then
				translations[branchIndex] = translation or true
			else
				status:except{
					"Unable to find branch with name '%s' for rule '%s'",
					fmt={branchName, symbol},
					cat="translate"
				}
			end
		elseif type(branches) == "table" then
			for branch in list(branches) do
				self:define(symbolName, branch, translation)
			end
		else
			status:except{
				"Expected a string, number, or array of either for branch indicator, but received '%s'",
				fmt={type(branches)},
				cat="translate"
			}
		end
	else
		status:except{
			"Symbol with name '%s' is invalid for translation",
			fmt={symbol},
			cat="translate"
		}
	end
end

--- Returns the translation function for the symbol
--- @param symbolName string Symbol name
--- @param branch number Rule branch
--- @return RuleTranslation
--- @overload fun(symbolName: string): TokenTranslation
function Translator:get(symbolName, branch)
	local symbol = self.grammar:get(symbolName)

	if getmetatable(symbol) == Token then
		-- Find corresponding token translation
		local translation = self.registry[symbolName]

		if translation then
			return translation
		end
	elseif getmetatable(symbol) == Rule then --- @cast symbol Rule
		if not branch then
			status:except{
				"No branch given to find translation of rule '%s'",
				fmt={symbolName},
				cat="translate"
			}
		end

		-- Find translation for the given branch within the set of translations
		local translations = self.registry[symbolName]

		if translations then
			local translation = translations[branch]

			if translation then
				return translation
			end

			status:except{
				"Unable to find translation for branch '%s' of rule '%s'",
				fmt={symbol.branches[branch].name or branch, symbolName},
				cat="translate"
			}
		end
	end

	status:except{
		"Unable to find translation for symbol '%s'",
		fmt={symbol},
		cat="translate"
	}
end

--- @alias TokenTranslation fun(program: Program, text: string) | true
--- @alias RuleTranslation fun(program: Program, ...: Node[]|Node) | true

return Translator