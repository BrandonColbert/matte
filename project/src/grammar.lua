local Symbol = require "lang.symbols.symbol"
local Rule = require "lang.symbols.rule"

--- Returns the direct token with the corresponding name
--- @param name string Token name
--- @return Token
local function t(name) return Symbol("<" .. name .. ">") end

--- Returns a new anonymous rule with the specified requirements
--- @param firstEntry Symbol First entry
--- @param ... Symbol | string Remaining entries
--- @return Rule
local function r(firstEntry, ...) return Rule:new(firstEntry, ...) end

-- Tokens
local integer = Symbol("Integer", "%-?%d+")
local float = Symbol("Float", "%-?%d+%.%d+")
local name = Symbol("Name", "[%a_][%a%d_]*")
local string = Symbol("String", "\".-[^\\]\"")
local algebraOp = Symbol("AlgebraOp", "[%+%-%*/%%]", "%*%*")
local conditionOp = Symbol("ConditionOp", "&&", "||", "%?%?")
local logicOp = Symbol("LogicOp", "&", "|", "%^", "<<", ">>")
local relationOp = Symbol("RelationOp", "[<>]", "<=", ">=", "==", "!=", "in", "!in")
local keyword = Symbol("Keyword",
	"true", "false", "nan", "infinity", "none", "any",
	"let", "fn",
	"new", "as",
	"for", "while", "switch",
	"continue", "break", "return", "default",
	"from", "import"
)

-- Rules
local stat = Symbol("stat")
local exp = Symbol("exp")
local assignable = Symbol("assignable")
local block = Symbol("block")
local perform = Symbol("perform")
local fn = Symbol("fn")
local ifElseStatement = Symbol("ifElse")
local rtype = Symbol("type")
local import = Symbol("import")

local unaryOp = Symbol("unaryOp"
	, t"!"
	| t"~"
	| t"++" -- Increment
	| t"--" -- Decrement
	| t"..." -- Spread
	| t"+"
	| t"-"
)

local binaryOp = Symbol("binaryOp"
	, algebraOp
	| relationOp
	| conditionOp
	| logicOp
	| t".." -- Range
)

local number = Symbol("number"
	, integer
	| float
)

local constant = Symbol("constant"
	, number
	| t"nan"
	| t"infinity"
	| t"true"
	| t"false"
	| string
	| t"none"
)

local entry = Symbol("entry", import, '*', stat, '*')
local arguments = Symbol("arguments", exp, r(t",", exp), '*')
local typedName = Symbol("typedName", name, r(t":", rtype), '?')
local names = Symbol("names", typedName, r(t",", typedName), '*')
local signature = Symbol("signature", t"(", names, '?', t")", r(t":", rtype), '?')

rtype:addRequirementSet(
	name
	| t"any"
	| t"none"
	| r(rtype, t"[]") -- Array of type
)

exp:addRequirementSet(
	constant
	| name
	| r(exp, binaryOp, exp)
	| r(unaryOp, exp)
	| r(t"(", exp, t")") -- Grouping
	| t"[]" -- Empty array creation
	| r(t"[", arguments, '?', t"]") -- Array creation
	| r(exp, t"(", arguments, '?', t")") -- Function call
	| r(exp, t".", name) -- Member access
	| r(exp, t"[", exp, t"]") -- Indexer access
	| r(exp, t"if", exp, t"else", exp) -- Ternary
	| r(t"new", exp) -- Instantiation
	| r(signature, t"=>", stat) -- Lambda (anonymous function)
)

assignable:addRequirementSet(
	typedName
	| r(t"[", names, t"]") -- Array destructure
	| r(t"{", names, t"}") -- Object destructure
)

ifElseStatement:addRequirementSet(t"if", exp, perform, r(t"else", perform | ifElseStatement), '?')

stat:addRequirementSet(
	block
	| exp
	| fn
	| r(t"let", assignable, t"=", exp) -- Declaration
	| r(assignable, algebraOp | logicOp | conditionOp, '?', t"=", exp) -- Assignment
	| ifElseStatement -- If-Else statement
	| r(t"for", name, t"in", exp, perform) -- For loop
	| r(t"while", exp, perform) -- While loop
	| t"continue" | t"break" -- Loop control
	| r(t"switch", exp, t"{", r(exp | r(name, t"if", exp), perform), '*', r(t"default", perform), '?', t"}") -- Switch statement
	| r(t"return", exp, '?') -- Return statement
)

block:addRequirementSet(
	t"{", stat, '*', t"}"
)

perform:addRequirementSet(
	block
	| r(t"=>", stat)
)

fn:addRequirementSet(t"fn", name, signature, perform)

local importItem = Symbol("importItem", name, r(t"as", name), '?')
local importItems = Symbol("importItems", importItem, r(t",", importItem), '*')

import:addRequirementSet(
	r(t"from", string, t"import", importItems)
	| r(t"from", name, t"import", importItems)
)