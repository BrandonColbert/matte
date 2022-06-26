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
local relationOp = Symbol("RelationOp", "[<>]", "<=", ">=", "==", "!=", "in", "!in")
local visibility = Symbol("Visibility", "public", "protected", "private")

local keyword = Symbol("Keyword",
	"boolean", "number", "string", "object", "any", -- Primitive types
	"true", "false", "infinity", "nan", -- Primitive values
	"none", -- Primitive type/value combos
	"new", "as", -- Transformers
	"let", "fn", -- Creators
	"if", "else", "switch", "for", "while", -- Flow control
	"continue", "break", "default", "return", -- Control directives
	"from", "import", -- Modules
	"class", -- Archetypes
	"static", "abstract", "extends", "implement"
)

Symbol("Comment",
	"//.-\r\n", "//.-\n", --Single line comment
	"/%*.-%*/" -- Multiline comment
):setComment(true)

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
local archetype = Symbol("archetype")
local classBody = Symbol("classBody")
local classMember = Symbol("classMember")

local unaryOp = Symbol("unaryOp"
	, t"!"
	| t"~"
	| t"++" -- Increment
	| t"--" -- Decrement
	| t"..." -- Spread
	| t"+"
	| t"-"
)

local logicOp = Symbol("logicOp",
	t"&"
	| t"|"
	| t"^"
	| r(t"<", t"<") -- Left shift
	| r(t">", t">") -- Right shift
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

local generic = Symbol("generic", name, r(t"extends", rtype), '?')
local generics = Symbol("generics", t"<", generic, r(t",", generic), '*', t">")

local entry = Symbol("entry", import, '*', stat, '*')
local arguments = Symbol("arguments", exp, r(t",", exp), '*')
local typedName = Symbol("typedName", name, r(t":", rtype), '?')
local names = Symbol("names", typedName, r(t",", typedName), '*')

local signature = Symbol("signature"
	, generics, '?', t"(", names, '?', t")", r(t":", rtype), '?'
)

local genericArguments = Symbol("genericArguments", t"<", rtype, r(t",", rtype), '*', t">")

rtype:addRequirementSet(
	r(name, genericArguments, '?')
	| t"boolean" | t"number" | t"string" | t"object" | t"any" | t"none" -- Primitive type
	| r(rtype, t"[", t"]") -- Array of type
	| r(t"...", rtype) -- Rest of type
)

exp:addRequirementSet(
	constant
	| name
	| r(exp, binaryOp, exp)
	| r(unaryOp, exp)
	| r(t"(", exp, t")") -- Grouping
	| r(t"[", arguments, '?', t"]") -- Array creation
	| r(exp, genericArguments, '?', t"(", arguments, '?', t")") -- Function call
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
	| archetype
)

block:addRequirementSet(
	t"{", stat, '*', t"}"
)

perform:addRequirementSet(
	block
	| r(t"=>", stat)
)

fn:addRequirementSet(t"fn", name, signature, perform)

local importItem = Symbol("importItem", name | t"*", r(t"as", name), '?')
local importItems = Symbol("importItems", importItem, r(t",", importItem), '*')

import:addRequirementSet(
	r(t"from", string, t"import", importItems) -- Import from file
	| r(t"from", name, t"import", importItems) -- Import destructuring
)

local propertyGetter = Symbol("propertyGetter"
	, t"abstract", '?', t"get", r(signature, '?', perform), '?'
)

local propertySetter = Symbol("propertySetter"
	, visibility, '?', t"abstract", '?', t"set", r(signature, '?', perform), '?'
)

local propertyBody = Symbol("propertyBody"
	, r(t"=", exp) -- Initial value
	| r(t"=>", stat) -- Getter
	| r(t"{", propertyGetter, propertySetter, '?', t"}", r(t"=", exp), '?') -- Getter/setter
)

local property = Symbol("property", typedName, propertyBody, '?')

local method = Symbol("method", t"fn", name, signature, perform, '?')

classMember:addRequirementSet(
	r(visibility, '?', t"static", '?', property | method) -- Property/method
	| r(visibility, '?', t"new", t"(", names, '?', t")", perform) -- Constructor
	| r(t"static", t"new", t"(", t")", perform) -- Static constructor
	| r(t"op", name, signature, perform, '?') -- Operator overload
	| r(t"implement", rtype, classBody, '?') -- Interface implementation
)

classBody:addRequirementSet(t"{", classMember, '*', t"}")

local classStructure = Symbol("class",
	t"class", name,
	generics, '?',
	r(t"extends", rtype), '?',
	classBody
)

local implementation = Symbol("implementation",
	t"implement", rtype,
	t"for", rtype,
	classBody
)

archetype:addRequirementSet(
	classStructure
	| implementation
)