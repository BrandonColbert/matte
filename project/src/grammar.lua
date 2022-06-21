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
local string = Symbol("String", "\"[%a%d_ ]*\"")
local algebraOp = Symbol("AlgebraOp", "[%+%-%*/%%]", "%*%*")
local conditionOp = Symbol("ConditionOp", "&&", "||", "%?%?")
local logicOp = Symbol("LogicOp", "&", "|", "%^", "<<", ">>")
local relationOp = Symbol("RelationOp", "[<>]", "<=", ">=", "==", "!=", "in", "!in")
local keyword = Symbol("Keyword",
	"true", "false", "nan", "infinity", "none",
	"let", "fn", "for", "while", "switch",
	"continue", "break", "return", "default"
)

-- Rules
local stat = Symbol("stat")
local exp = Symbol("exp")
local assignable = Symbol("assignable")
local block = Symbol("block")
local perform = Symbol("perform")
local fn = Symbol("fn")

local unaryOp = Symbol("unaryOp"
	, t'!'
	| t'~'
	| t'++'
	| t'--'
	| t'...'
	| t'+'
	| t'-'
)

local binaryOp = Symbol("binaryOp"
	, algebraOp
	| relationOp
	| conditionOp
	| logicOp
	| t".."
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

exp:addRequirementSet(
	constant
	| name
	| r(exp, binaryOp, exp)
	| r(unaryOp, exp)
	| r(t"(", exp, t")")
	| r(t"[", r(exp, r(t",", exp), '*'), '?', t"]") -- Array creation
)

assignable:addRequirementSet(
	name
	| r(t"[", name, r(t",", name), '*', t"]") -- Array destructure
	| r(t"{", name, r(t",", name), '*', t"}") -- Object destructure
)

local ifElseStatement = Symbol("ifElse")
ifElseStatement:addRequirementSet(t"if", exp, perform, r(t"else", perform | ifElseStatement), '?')

stat:addRequirementSet(
	block
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
	| r(t"=>", exp | stat)
)

local signature = Symbol("signature", t"(", r(name, r(t",", name), '*'), '?', t")")
fn:addRequirementSet(t"fn", name, signature, perform)

local entry = Symbol("entry", stat)