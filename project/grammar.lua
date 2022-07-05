local Symbol = require "lang.lex.symbol"
local Rule = require "lang.lex.rule"

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
local boolean = Symbol("Boolean", "true", "false")
local pattern = Symbol("Pattern", "/[^/].-[^\\]/")

local number = Symbol("Number",
	"%-?%d+", -- Integer
	"%-?%d+[eE]%-?%d+", -- Integer with exponent
	"%-?%d+%.%d+", -- Float
	"%-?%d+%.%d+[eE]%-?%d+", -- Float with exponent
	"infinity",
	"nan" -- Not a number
)

local string = Symbol("String",
	"[fl]?\"\"", -- Empty string
	"l?\"[^\"\\]\"", -- Single character string
	"l?\"[^\"].-[^\\]\"", -- Multicharacter string
	function(content) -- Formatted string
		-- Check if format string begins
		if content:match("^f\"") then
			local depth = 0
			local pos = 2

			-- Evaluate balance
			repeat
				-- Find the next interpolation item or potential end quote
				local i, j, value = string.find(content, "[^\\]([{}\"])", pos)

				if value then
					pos = j

					-- Modify depth or end the string if needed
					if value == "{" then
						depth = depth + 1
					elseif value == "}" then
						depth = depth - 1
					elseif value == "\"" and depth == 0 then
						break
					end
				else
					break
				end
			until depth < 0

			-- If the value is balanced and ends with a quote return it
			if depth == 0 and content:sub(pos, pos) == "\"" then
				return string.sub(content, 1, pos)
			end
		end

		return nil
	end
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
	"<=>", -- Three-way comparison
	"[<>]", "<=", ">=", -- Less/greater than (or equal to)
	"==", "!=", -- Equivalence
	"in", "!in", -- Set membership
	"is", "!is" -- Type compatibility
)

local visibility = Symbol("Visibility",
	"public", -- Anywhere
	"protected", -- Subclasses
	"private" -- Original class only
)

local primitive = Symbol("Primitive",
	"bool", -- Boolean type
	"number", -- Numeric type
	"string", -- String type
	"object", -- Table type
	"any", -- Encompasses all other types
	"none" -- Represents no type or no value
)

-- Additional non-contextual keywords
local keyword = Symbol("Keyword",
	"if", "else", "switch", "for", "while", -- Flow control
	"default", "continue", "break", "return", -- Flow directives
	"from", "import", -- Modules
	"let", "fn", "op", -- Declaration
	"class", "implement", "interface", "enum", "@interface", -- Structures
	"static", "extends", -- Structure modifiers
	"this", "This", "super", -- Local scope reference
	"new", -- Instantiation
	"as" -- Aliasing/casting
)

Symbol("Whitespace", "(%s+)[^\n\r]"):setIgnore(true)

Symbol("End",
	"\n%s*",
	"\r\n%s*"
):setIgnore(true)

Symbol("Comment",
	"//.-\n", "//.-\r\n", --Single line comment
	"/%*.-%*/" -- Multiline comment
):setIgnore(true)

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
	| t"as" -- Type conversion
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
	r(t"import", importItems) -- Import file from same directory
	| r(t"from", string, t"import", importItems) -- Import from relative file
	| r(t"from", name, t"import", importItems) -- Import destructuring
)

-- Import Items
local importItem = Symbol("importItem")
importItems:requires(importItem, r(t",", importItem), '*')

-- Import Item
importItem:requires(name | t"*", r(t"as", name), '?')

-- Statement
local exp = Symbol("exp")
local block = Symbol("block")
local annotate = Symbol("annotate")
local lambda = Symbol("lambda")
local declarable = Symbol("declarable")
local assignable = Symbol("assignable")
local ifElseStat = Symbol("if_else")
local switchStat = Symbol("switch")
local forLoop = Symbol("for")
local whileLoop = Symbol("while")
local structure = Symbol("structure")
local implementation = Symbol("implementation")
stat:requires(
	exp
	| block
	| r(annotate, '*', t"fn", name, lambda) -- Function declaration
	| r(t"let", declarable, t"=", exp) -- Variable declaration
	| r(assignable, algebraOp | bitwiseOp | conditionOp, '?', t"=", exp) -- Variable assignment
	| ifElseStat | switchStat
	| forLoop | whileLoop
	| t"continue" | t"break" -- Loop control
	| r(t"return", exp, '?') -- Return statement
	| structure
	| implementation
	-- | r(t"lua", string) -- Direct translation
)

-- Expresion
local expressions = Symbol("expressions")
local arguments = Symbol("arguments")
local objectLiteral = Symbol("object_literal")
local genericArguments = Symbol("generic_arguments")
exp:requires(
	constant
	| name | t"this" | t"super"
	| pattern
	| r(exp, binaryOp, exp)
	| r(unaryOp, exp)
	| r(t"(", exp, t")") -- Grouping
	| r(t"[", expressions, '?', t"]") -- Array creation
	| objectLiteral
	| r(exp, genericArguments, '?', arguments) -- Function call
	| r(exp, t"?", '?', t"." | t"->", name) -- Member/operator access
	| r(exp, t"[", exp, t"]") -- Indexer access
	| r(exp, t"if", exp, t"else", exp) -- Ternary
	| r(t"new", exp) -- Instantiation
	| lambda -- Anonymous function
)

-- Expressions
expressions:requires(exp, r(t",", exp), '*')

-- Arguments
local namedExpressions = Symbol("named_expressions")
arguments:requires(t"(", expressions | namedExpressions, '?', t")")

-- Named Arguments
local namedExpression = Symbol("named_expression")
namedExpressions:requires(namedExpression, r(t",", namedExpression), '*')

-- Named Expression
namedExpression:requires(name, t":", exp)

-- Object Literal
local objectLiteralMembers = Symbol("object_literal_members")
objectLiteral:requires(t"{", objectLiteralMembers, '?', t"}")

-- Object Literal Members
local objectLiteralMember = Symbol("object_literal_member")
objectLiteralMembers:requires(objectLiteralMember, r(t",", objectLiteralMember), '*')

-- Object Literal Member
objectLiteralMember:requires(name | string, t":", exp)

-- Generic Arguments
local typename = Symbol("type")
genericArguments:requires(t"<", typename, r(t",", typename), '*', t">")

-- Typename
local typenames = Symbol("types")
typename:requires(
	primitive
	| t"This" -- Self type
	| r(name, genericArguments, '?')
	| r(typename, t"[", t"]") -- Array of type
	| typenames -- Tuple of types
	| r(t"...", typename) -- Rest of type
)

-- Typenames
typenames:requires(t"[", r(typename, r(t',', typename), '*'), '?', t"]")

-- Block
block:requires(t"{", stat, '*', t"}")

-- Annotate
annotate:requires(t"@", name, arguments, '?')

-- Lambda
local signature = Symbol("signature")
local perform = Symbol("perform")
lambda:requires(
	r(name, t"=>", stat)
	| r(signature, perform)
)

-- Signature
local genericParameters = Symbol("generic_parameters")
local parameters = Symbol("parameters")
signature:requires(genericParameters, '?', parameters, r(t":", typename), '?')

-- Generic Parameters
local generic = Symbol("generic")
genericParameters:requires(t"<", generic, r(t",", generic), '*', t">")

-- Generic
generic:requires(
	name,
	r(t":", typename, r(t"+", typename), '*'), '?', -- Inheritance
	r(t"=", typename), '?' -- Default
)

-- Parameters
local parameter = Symbol("parameter")
parameters:requires(t"(", r(parameter, r(t",", parameter), '*'), '?', t")")

-- Parameter
parameter:requires(
	name,
	t"?", '?', -- Optionality
	r(t":", typename), '?', -- Type
	r(t"=", exp), '?' -- Default value
)

-- Perform
perform:requires(
	block
	| r(t"=>", stat)
)

-- Declarable
local variable = Symbol("variable")
local variables = Symbol("variables")
local aliasedVariables = Symbol("aliased_variables")
declarable:requires(
	variable
	| r(t"[", variables, t"]") -- Array destructure
	| r(t"{", aliasedVariables, t"}") -- Object destructure
)

-- Variable
variable:requires(name, r(t":", typename), '?')

-- Variables
variables:requires(variable, r(t",", variable), '*')

-- Aliased Variables
local aliasedVariable = Symbol("aliased_variable")
aliasedVariables:requires(aliasedVariable, r(t",", aliasedVariable), '*')

-- Aliased Variable
aliasedVariable:requires(variable, r(t"as", declarable), '?')

-- Assignable
assignable:requires(
	name
	| r(t"this" | t"super", t".", name) -- Self member
	| r(assignable, t".", name) -- Object member
	| r(assignable, t"[", exp, t"]") -- Item at object index
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
local archetype = Symbol("archetype")
structure:requires(annotate, '*', visibility, '?', archetype)

-- Archetype
local class = Symbol("class")
local interface = Symbol("interface")
local enum = Symbol("enum")
local annotation = Symbol("annotation")
archetype:requires(
	class
	| interface
	| enum
	| annotation
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
local classAttribute = Symbol("class_attribute")
local interfaceRequirement = Symbol("interface_requirement")
local implementationBody = Symbol("implementation_body")
classMember:requires(
	r(annotate, '*', classAttribute)
	| interfaceRequirement
	| r(t"implement", typename, implementationBody) -- Local interface implementation
	| structure -- Nested structure
)

-- Class Attribute
local constructor = Symbol("constructor")
local method = Symbol("method")
local property = Symbol("property")
local opMethod = Symbol("op_method")
classAttribute:requires(
	r(visibility, '?', t"static", '?', constructor | method | property) -- Constructor, method, property
	| opMethod -- Operator overload
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

-- Interface Requirement
interfaceRequirement:requires(t"implement", typename, r(t",", typename), '*')

-- Implementation Body
local implementationMember = Symbol("implementation_member")
implementationBody:requires(t"{", implementationMember, '*', t"}")

-- Implementation Member
local implementationAttribute = Symbol("implementation_attribute")
implementationMember:requires(annotate, '*', implementationAttribute)

-- Implementation Attribute
implementationAttribute:requires(
	method
	| property
	| opMethod
)

-- Interface
local interfaceBody = Symbol("interface_body")
interface:requires(
	t"interface", name, -- Name
	genericParameters, '?', -- Generics
	interfaceBody
)

-- Interface Body
local interfaceMember = Symbol("interface_member")
interfaceBody:requires(t"{", interfaceMember, '*', t"}")

-- Interface Member
local interfaceAttribute = Symbol("interface_attribute")
interfaceMember:requires(
	interfaceRequirement
	| r(annotate, '*', interfaceAttribute)
	| structure -- Nested structure
)

-- Interface Attribute
interfaceAttribute:requires(
	method
	| property
	| opMethod
)

-- Enum
local enumMember = Symbol("enum_member")
enum:requires(
	t"enum", name,
	t"{", enumMember, '*', t"}"
)

-- Enum Member
local enumAttribute = Symbol("enum_attribute")
enumMember:requires(annotate, '*', enumAttribute)

-- Enum Attribute
local enumValue = Symbol("enum_value")
enumAttribute:requires(
	property
	| enumValue
	| constructor
)

-- Enum Value
enumValue:requires(
	name
	| r(name, t"=", number)
	| r(name, arguments)
)

-- Annotation
local annotationMember = Symbol("annotation_member")
annotation:requires(
	t"@interface", name,
	t"{", annotationMember, '*', t"}"
)

-- Annotation Member
local annotationAttribute = Symbol("annotation_attribute")
annotationMember:requires(annotate, '*', annotationAttribute)

-- Annotation Attribute
annotationAttribute:requires(
	property
	| constructor
	| enum
)

-- Implementation
implementation:requires(
	t"implement", name, -- Interface to implement
	genericParameters, '?', -- Interface generics
	t"for", typename, -- Class to implement on
	implementationBody
)