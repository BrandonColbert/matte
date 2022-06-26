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

-- TOKENS
local name = Symbol("Name", "[%a_][%a%d_]*")
local string = Symbol("String", "\".-[^\\]\"")
local boolean = Symbol("Boolean", "true", "false")
local number = Symbol("Number",
	"%-?%d+", -- Integer
	"%-?%d+%.%d+", -- Float
	"infinity",
	"nan" -- Not a number
)

local algebraOp = Symbol("AlgebraOp",
	"[%+%-%*/%%]", -- Addition, subtraction, multiplication, division, modulus
	"%*%*" -- Exponentiation
)

local conditionOp = Symbol("ConditionOp",
	"&&", -- Logical and
	"||", -- Logical or
	"%?%?" -- Null coalescing
)

local relationOp = Symbol("RelationOp",
	"[<>]", "<=", ">=", -- Less/greater than (or equal to)
	"==", "!=", -- Equivalence
	"in", "!in" -- Set membership
)

local visibility = Symbol("Visibility",
	"public", -- Anywhere
	"protected", -- Subclasses
	"private" -- Original class only
)

local primitive = Symbol("Primitive",
	"boolean", -- Boolean type
	"number", -- Numeric type
	"string", -- String type
	"object", -- Table type
	"any", -- Encompasses all other types
	"none" -- Represents no type or no value
)

-- Additional non-contextual keywords
local keyword = Symbol("Keyword",
	"if", "else", "switch", "for", "while", -- Flow control
	"continue", "break", "return", -- Flow directives
	"from", "import", -- Modules
	"let", "fn", "op", -- Declaration
	"class", "implement", -- Structures
	"new", "as", "static", "extends", "default"
)

Symbol("Comment",
	"//.-\r\n", "//.-\n", --Single line comment
	"/%*.-%*/" -- Multiline comment
):setComment(true)

-- RULES
local constant = Symbol("constant"
	, number
	| string
	| boolean
	| t"none"
)

local bitwiseOp = Symbol("bitwise_op"
	, t"&" -- Bitwise and
	| t"|" -- Bitwise or
	| t"^" -- Bitwise xor
	| r(t"<", t"<") -- Left shift
	| r(t">", t">") -- Right shift
)

local binaryOp = Symbol("binary_op"
	, algebraOp
	| conditionOp
	| relationOp
	| bitwiseOp
	| t".." -- Range
)

local unaryOp = Symbol("unary_op"
	, t"!" -- Logical negation
	| t"~" -- Bitwise negation
	| t"+" | t"-" -- Numeric identity/negation
	| t"++" | t"--" -- Increment/decrement
	| t"..." -- Spread
)

-- Entry
local import = Symbol("import")
local stat = Symbol("stat")
local entry = Symbol("entry", import, '*', stat, '*')

-- Import
local importItems = Symbol("import_items")
import:requires(
	r(t"from", string, t"import", importItems) -- Import from file
	| r(t"from", name, t"import", importItems) -- Import destructuring
)

-- Import Items
local importItem = Symbol("importItem")
importItems:requires(importItem, r(t",", importItem), '*')

-- Import Item
importItem:requires(name | t"*", r(t"as", name), '?')

-- Statement
local block = Symbol("block")
local exp = Symbol("exp")
local lambda = Symbol("lambda")
local assignable = Symbol("assignable")
local ifElseStat = Symbol("if_else")
local switchStat = Symbol("switch")
local forLoop = Symbol("for")
local whileLoop = Symbol("while")
local structure = Symbol("structure")
stat:requires(
	block
	| exp
	| r(t"fn", name, lambda) -- Function declaration
	| r(t"let", assignable, t"=", exp) -- Variable declaration
	| r(assignable, algebraOp | bitwiseOp | conditionOp, '?', t"=", exp) -- Variable assignment
	| ifElseStat | switchStat
	| forLoop | whileLoop
	| t"continue" | t"break" -- Loop control
	| r(t"return", exp, '?') -- Return statement
	| structure
)

-- Block
block:requires(t"{", stat, '*', t"}")

-- Expresion
local arguments = Symbol("arguments")
local genericArguments = Symbol("generic_arguments")
exp:requires(
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
	| lambda -- Anonymous function
)

-- Arguments
arguments:requires(exp, r(t",", exp), '*')

-- Generic Arguments
local typename = Symbol("type")
genericArguments:requires(t"<", typename, r(t",", typename), '*', t">")

-- Typename
typename:requires(
	primitive
	| r(name, genericArguments, '?')
	| r(typename, t"[", t"]") -- Array of type
	| r(t"[", typename, r(t',', typename), '*', t"]") -- Tuple of types
	| r(t"...", typename) -- Rest of type
)

-- Lambda
local signature = Symbol("signature")
local perform = Symbol("perform")
lambda:requires(signature, perform)

-- Signature
local genericParameters = Symbol("generic_parameters")
local parameters = Symbol("parameters")
signature:requires(genericParameters, '?', parameters, r(t":", typename), '?')

-- Generic Parameters
local generic = Symbol("generic")
genericParameters:requires(t"<", generic, r(t",", generic), '*', t">")

-- Generic
generic:requires(name, r(t":", typename, r(t"+", typename), '*'), '?')

-- Parameters
local variables = Symbol("variables")
parameters:requires(t"(", variables, '?', t")")

-- Variables
local variable = Symbol("variable")
variables:requires(variable, r(t",", variable), '*')

-- Variable
variable:requires(name, r(t":", typename), '?')

-- Perform
perform:requires(
	block
	| r(t"=>", stat)
)

-- Assignable
assignable:requires(
	variable
	| r(t"[", variables, t"]") -- Array destructure
	| r(t"{", variables, t"}") -- Object destructure
)

-- If-Else Statement
local ifStat = Symbol("if")
local elseStat = Symbol("else")
ifElseStat:requires(ifStat, elseStat, '?')

-- If Statement
ifStat:requires(t"if", exp, perform)

-- Else Statement
elseStat:requires(t"else", perform | ifElseStat)

-- Switch Statement
local switchCaseStat = Symbol("switch_case")
local switchDefaultStat = Symbol("switch_default")
switchStat:requires(t"switch", exp, t"{", switchCaseStat, '*', switchDefaultStat, '?', t"}")

-- Switch Case Statement
switchCaseStat:requires(exp | r(name, t"if", exp), perform)

-- Switch Default Statement
switchDefaultStat:requires(t"default", perform)

-- For Loop
forLoop:requires(t"for", name, t"in", exp, perform)

-- While Loop
whileLoop:requires(t"while", exp, perform)

-- Structure
local class = Symbol("class")
local implementation = Symbol("implementation")
structure:requires(
	class
	| implementation
)

-- Class
local classBody = Symbol("class_body")
class:requires(
	t"class", name, -- Name
	genericParameters, '?', -- Generics
	r(t"extends", typename), '?', -- Superclass
	classBody
)

-- Class Body
local classMember = Symbol("class_member")
classBody:requires(t"{", classMember, '*', t"}")

-- Class Member
local constructor = Symbol("constructor")
local method = Symbol("method")
local property = Symbol("property")
local opMethod = Symbol("op_method")
local implementationBody = Symbol("implementation_body")
classMember:requires(
	r(visibility, '?', t"static", '?', constructor | method | property) -- Constructor, method, property
	| opMethod -- Operator overload
	| r(t"implement", typename, r(t",", typename), '*') -- Interface requirement
	| r(t"implement", typename, implementationBody) -- Interface implementation
	| structure -- Nested structure
)

-- Constructor
constructor:requires(t"new", parameters, perform, '?')

-- Method
method:requires(t"fn", name, signature, perform, '?')

-- Property
local accessors = Symbol("accessors")
local get = Symbol("get")
property:requires(variable, accessors | get, '?')

-- Accessors
local getter = Symbol("getter")
local setter = Symbol("setter")
accessors:requires(
	r(t"{", getter, setter, '?', t"}"), '?', -- Getter with optional setter
	r(t"=", exp), '?' -- Optional initial value
)

-- Getter
getter:requires(t"get", r(signature, '?', perform), '?')

-- Setter
setter:requires(visibility, '?', t"set", r(signature, '?', perform), '?')

-- Get
get:requires(t"=>", stat)

-- Operator method
opMethod:requires(t"op", name, signature, perform, '?')

-- Implementation Body
local implementationMember = Symbol("implementation_member")
implementationBody:requires(t"{", implementationMember, '*', t"}")

-- Implementation Member
implementationMember:requires(
	method
	| property
	| opMethod
)

-- Implementation
implementation:requires(
	t"implement", name, -- Interface to implement
	genericParameters, '?', -- Interface generics
	t"for", typename, -- Class to implement on
	implementationBody
)