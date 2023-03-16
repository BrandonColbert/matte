local matte = require "matte.matte"
require "matte.main"

local Program = require "matter.lang.program"
local RuleNode = require "matter.lang.parse.ruleNode"
local TokenNode = require "matter.lang.parse.tokenNode"
local Symbol = require "matter.lang.syntax.symbol"
local Rule = require "matter.lang.syntax.rule"
local Token = require "matter.lang.syntax.token"
local Language = require "matter.language"
local list = require "matter.utils.list"

--- @param rule Rule
--- @param explored table<string, boolean>
--- @param depth number
function expand(rule, explored, depth)
	explored = explored or {}
	depth = depth or 0

	print(string.format("%s%s[%d]", string.rep("\t", depth), rule, #rule.branches))

	if #rule.branches == 0 then
		error("NO BRANCHES")
	end

	if rule.label then
		explored[rule.label] = true
	end

	for index, branch in ipairs(rule.branches) do --- @cast branch Rule.Requirement.List
		print(string.format("%s%d: %s", string.rep("\t", 1 + depth), index, branch))

		for _, requirement in ipairs(branch.requirements) do
			if getmetatable(requirement.symbol) == Rule then
				local rule = requirement.symbol

				if not rule.label or not explored[rule.label] then
					expand(rule, explored, depth + 1)
				end
			end
		end
	end
end

-- expand(matte.grammar:get("constant"))

-- local result = matte:parse("1.3e5", "constant")
-- print("========")
-- print(result)

-- local program = matte:transpile([[0.5]], "constant")
-- print("========")
-- print(program)

-- local result = matte:run{
-- 	[[print("Hello world!")]],
-- 	entry="entry",
-- 	args={"first", "second", "third"}
-- }

-- local root = RuleNode:new(matte.grammar:get("constant"))
-- root.branches[1] = nil
-- root.branches[2] = {}
-- root.branches[3] = {{TokenNode:new(matte.grammar:get("Boolean"), "true")}}
-- root.branches[4] = {{TokenNode:new(matte.grammar:get("<none>"), "none")}}

-- print(root:getMainBranch())

-- local program = Program:new(matte.translator)
-- program:translate(root)

-- print(program)