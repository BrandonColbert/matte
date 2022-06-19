local Symbol = require "src.lang.symbols.symbol"
local Token = require "src.lang.symbols.token"
local Rule = require "src.lang.symbols.rule"

--- Returns the direct token for the content
--- @param content string Content to match
--- @return Token
local function t(content) return Symbol.get("<" .. content .. ">") or Token:new(content) end

--- Returns a new anonymous rule with the specified requirements
--- @param ... (Symbol | string)[] Rule requirements
--- @return Rule
local function r(...) return Rule:new(...) end

-- Tokens
local integer = Token:new("Integer", "%-?%d+")
local float = Token:new("Float", "%-?%d+%.%d+")
local name = Token:new("Name", "[%a_][%a%d_]*")
local string = Token:new("String", "\"[%a%d_ ]*\"")
local algebraOp = Token:new("AlgebraOp", "[%+%-%*/%%]", "%*%*")
local conditionOp = Token:new("ConditionOp", "&&", "||", "%?%?")
local logicOp = Token:new("LogicOp", "&", "|", "%^", "<<", ">>")
local relationOp = Token:new("RelationOp", "[<>]", "<=", ">=", "==", "!=", "in", "!in")
local keyword = Token:new("Keyword",
	"true", "false", "nan", "infinity", "none",
	"let", "fn", "for", "while", "switch",
	"continue", "break", "return", "default"
)

-- Rules
local stat = Rule:new("stat")
local exp = Rule:new("exp")
local assignable = Rule:new("assignable")
local block = Rule:new("block")
local perform = Rule:new("perform")
local fn = Rule:new("fn")

local unaryOp = Rule:new("unaryOp"
	, t'!'
	| t'~'
	| t'++'
	| t'--'
	| t'...'
	| t'+'
	| t'-'
)

local binaryOp = Rule:new("binaryOp"
	, algebraOp
	| relationOp
	| conditionOp
	| logicOp
	| t".."
)

local number = Rule:new("number"
	, integer
	| float
)

local constant = Rule:new("constant"
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

local ifElseStatement = Rule:new("ifElse")
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

local signature = Rule:new("signature", t"(", r(name, r(t",", name), '*'), '?', t")")
fn:addRequirementSet(t"fn", name, signature, perform)

local entry = Rule:new("entry", stat)