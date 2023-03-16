local Language = require "matter.language"

-- Language descriptor for matte
local language = Language:new()

-- -- Additional non-contextual keywords
-- Keyword = t(
-- 	"infinity", "nan", -- Numeric constants
-- 	"in", "is", -- Relational operators
-- 	"if", "else", "switch", "for", "while", -- Flow control
-- 	"default", "continue", "break", "return", "yield", -- Flow directives
-- 	"from", "import", -- Modules
-- 	"let", "fn", "op", -- Declaration
-- 	"class", "implement", "interface", "enum", "@interface", -- Structures
-- 	"static", "extends", -- Structure modifiers
-- 	"this", "This", "super", -- Local scope reference
-- 	"new", -- Instantiation
-- 	"as" -- Aliasing/casting
-- )

-- Create grammar
language.grammar:define(function(_ENV)
	-- Indicates where a structure's member be referenced from
	Visibility = t(
		"public", -- Anywhere
		"protected", -- Sub-structures
		"private" -- Original structure only
	)

	-- Indicates logical truth
	Boolean = t("true", "false")

	-- Literal representing a Lua pattern
	Pattern = t"/[^/].-[^\\]/"

	-- Refers to some entity
	Name = t"[%a_][%a%d_]*"

	-- Integer with optional exponent
	Integer = t("%-?%d+", "%-?%d+[eE]%-?%d+")

	-- Float with optional exponent
	Float = t("%-?%d+%.%d+", "%-?%d+%.%d+[eE]%-?%d+")

	-- A sequence of characters that may be taken literally
	String = t(
		[[l?""]], -- Empty string
		[[l?"[^"\]"]], -- Single-character string
		[[l?"[^"].-[^\]"]] -- Multi-character string
	)

	-- A string with placeholders for expression substitution
	FString = t(
		[[f""]], -- Empty string
		function(text) -- Formatted string
			-- Check if format string begins
			if text:match("^f\"") then
				local depth = 0
				local pos = 2
	
				-- Evaluate balance
				repeat
					-- Find the next interpolation item or potential end quote
					local i, j, value = string.find(text, "[^\\]([{}\"])", pos)
	
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
				if depth == 0 and text:sub(pos, pos) == "\"" then
					return string.sub(text, 1, pos)
				end
			end
	
			return nil
		end
	)

	-- Ignore all new lines
	Endline = t("\n%s*", "\r\n%s*") << {ignore=true}

	-- Ignore all whitespace
	Whitespace = t("(%s+)[^\n\r]", "%s+$") << {ignore=true}

	-- Ignore comments
	Comment = t(
		"//.-\n", "//.-\r\n", --Single line comment
		"/%*.-%*/" -- Multiline comment
	) << {ignore=true}

	-- Values
	number
		= Integer
		| Float
		| T"infinity"  << {branch="Infinity"} -- Represents numerical infinity
		| T"nan"       << {branch="NaN"} -- Represents undefined numbers or those with indeterminate forms
	string
		= String
		| FString
	constant
		= number
		| string
		| Boolean
		| T"none" << {branch="None"}

	-- Operators
	algebra_op
		= T"+"          << {branch="Add"}
		| T"-"          << {branch="Subtracs"}
		| T"*"          << {branch="Multiply"}
		| T"/"          << {branch="Divide"}
		| r(T"*", T"*") << {branch="Exponentiate"}
	condition_op
		= T"&&"   << {branch="LogicAnd"}
		| T"||"   << {branch="LogicOr"}
		| T"%?%?" << {branch="NullCoalesce"}
	relation_op
		= T"<=>" << {branch="Compare"}
		| T"<"   << {branch="Lesser"}
		| T">"   << {branch="Greater"}
		| T"<="  << {branch="LesserEqual"}
		| T">="  << {branch="GreaterEqual"}
		| T"=="  << {branch="Equal"} -- Equivalence
		| T"!="  << {branch="NotEqual"}
		| T"in"  << {branch="In"} -- Set membership
		| T"!in" << {branch="NotIn"}
		| T"is"  << {branch="Is"} -- Type compatibility
		| T"!is" << {branch="IsNot"}
	bitwise_op
		= T"&"          << {branch="BitAnd"}
		| T"|"          << {branch="BitOr"}
		| T"^"          << {branch="BitXor"}
		| r(T"<", T"<") << {branch="ShiftLeft"}
		| r(T">", T">") << {branch="ShiftRight"}
	binary_op
		= algebra_op
		| condition_op
		| relation_op
		| bitwise_op
		| T".." << {branch="Range"}
		| T"as" << {branch="Convert"} -- Type conversion
	unary_op
		= T"!"   << {branch="LogicNegate"}
		| T"~"   << {branch="BitNegate"}
		| T"+"   << {branch="Positive"}
		| T"-"   << {branch="Negative"}
		| T"++"  << {branch="Increment"}
		| T"--"  << {branch="Decrement"}
		| T"..." << {branch="Spread"}

	-- Layout
	entry
		= r(import, '*', stat, '*')
	import
		= r(T"import", import_items)                  << {branch="Local"} -- Import file from same directory
		| r(T"from", String, T"import", import_items) << {branch="Relative"} -- Import from relative file
		| r(T"from", Name, T"import", import_items)   << {branch="Destructure"} -- Import destructuring
	import_items
		= r(import_item, r(t",", import_item), '*')
	import_item
		= r(Name | t"*", r(t"as", Name), '?')
	stat
		= exp
		| block                                                                 << {branch="Block"}
		| if_else_stat
		| switch_stat
		| for_loop
		| while_loop
		| r(annotate, '*', T"fn", Name, signature, perform)                     << {branch="DeclareFunction"}
		| r(T"let", declarable, T"=", exp)                                      << {branch="DeclareVariable"}
		| r(assignable, algebra_op | bitwise_op | condition_op, '?', T"=", exp) << {branch="AssignVariable"}
		| T"continue"                                                           << {branch="Continue"}
		| T"break"                                                              << {branch="Break"}
		| r(T"return", exp, '?')                                                << {branch="Return"}
		| r(T"yield", exp, '?')                                                 << {branch="Yield"}
		| r(T"lua", String)                                                     << {branch="Lua"} -- Direct translation
		| structure
		| implementation
	block
		= r(T"{", stat, '*', T"}")

	-- Expressions
	exp
		= constant
		| Name
		| Pattern
		| object_literal
		| lambda
		| T"this"                                   << {branch="This"}
		| T"super"                                  << {branch="Super"}
		| r(unary_op, exp)                          << {branch="UnaryExp"}
		| r(T"(", exp, T")")                        << {branch="Group"}
		| r(T"[", expressions, '?', T"]")           << {branch="ArrayLiteral"}
		| r(T"new", exp)                            << {branch="Instantiate"}
		| r(exp, binary_op, exp)                    << {branch="BinaryExp"}
		| r(exp, generic_arguments, '?', arguments) << {branch="Call"}
		| r(exp, T"?", '?', T"." | T"->", Name)     << {branch="Access"}
		| r(exp, T"[", exp, T"]")                   << {branch="Index"}
		| r(exp, T"if", exp, T"else", exp)          << {branch="Ternary"}
	expressions
		= r(exp, r(T",", exp), '*')
	named_expressions
		= r(named_expression, r(T",", named_expression), '*')
	named_expression
		= r(Name, T":", exp)
	arguments
		= r(T"(", expressions | named_expressions, '?', T")")

	-- Objects
	object_literal
		= r(T"{", object_literal_members, '?', T"}")
	object_literal_members
		= r(object_literal_member, r(T",", object_literal_member), '*')
	object_literal_member
		= r(Name | string, T":", exp)

	-- Anonymous functions
	lambda
		= r(Name, T"=>", stat)  << {branch="SingleVar"}
		| r(signature, perform) << {branch="MultiVar"}
	perform
		= block
		| r(T"=>", stat) << {branch="Arrow"}
	signature
		= r(generic_parameters, '?', parameters, r(T":", typename), '?')
	parameters
		= r(T"(", r(parameter, r(T",", parameter), '*'), '?', T")")
	parameter
		= r(
			Name,
			T"?", '?', -- Optionality
			r(T":", typename), '?', -- Type
			r(T"=", exp), '?' -- Default value
		)
	generic_parameters
		= r(T"<", generic, r(T",", generic), '*', T">")
	generic
		= r(
			Name,
			r(T":", typename, r(T"+", typename), '*'), '?', -- Inheritance
			r(T"=", typename), '?' -- Default
		)

	-- Types
	typename
		= primitive
		| typenames -- Tuple of types
		| T"This"                                                  << {branch="This"} -- Self type
		| r(Name, generic_arguments, '?', r(T"from", String), '?') << {branch="Reference"}
		| r(typename, T"[", T"]")                                  << {branch="Array"} -- Array of type
		| r(T"...", typename)                                      << {branch="Rest"} -- Rest of type
	typenames
		= r(T"[", r(typename, r(t',', typename), '*'), '?', T"]")
	generic_arguments
		= r(T"<", typename, r(T",", typename), '*', T">")
	primitive -- Primitive type aliases
		= T"bool"   << {branch="Boolean"}
		| T"number" << {branch="Number"} -- Numeric type
		| T"string" << {branch="String"}
		| T"object" << {branch="Object"} -- Table type
		| T"any"    << {branch="Any"} -- Encompasses all other types
		| T"none"   << {branch="None"} -- Represents no type or no value

	-- Variable declaration and assignment
	variable
		= r(Name, r(T":", typename), '?')
	variables
		= r(variable, r(T",", variable), '*')
	aliased_variables
		= r(aliased_variable, r(T",", aliased_variable), '*')
	aliased_variable
		= r(variable, r(T"as", declarable), '?')
	declarable
		= variable
		| r(T"[", variables, T"]")         << {branch="ArrayDestruct"}
		| r(T"{", aliased_variables, T"}") << {branch="ObjectDestruct"}
	assignable
		= Name
		| r(assignable, T".", Name)      << {branch="Member"}
		| r(assignable, T"[", exp, T"]") << {branch="Index"}
		| r(T"this", T".", Name)         << {branch="ThisMember"}
		| r(T"this", T"[", exp, T"]")    << {branch="ThisIndex"}
		| r(T"super", T".", Name)        << {branch="SuperMember"}
		| r(T"super", T"[", exp, T"]")   << {branch="SuperIndex"}

	-- Flow control
	if_else_stat
		= r(if_stat, else_stat, '?')
	if_stat
		= r(T"if", exp, perform)
	else_stat
		= r(T"else", perform | if_else_stat)
	switch_stat
		= r(T"switch", exp, T"{", switch_case_stat, '*', switch_default_stat, '?', T"}")
	switch_case_stat
		= r(exp | r(Name, T"if", exp), perform)
	switch_default_stat
		= r(T"default", perform)
	for_loop
		= r(T"for", Name, T"in", exp, perform)
	while_loop
		= r(T"while", exp, perform)

	-- Structure
	structure
		= r(annotate, '*', Visibility, '?', archetype)
	archetype
		= class
		| interface
		| enum
		| annotation

	-- Class
	class
		= r(
			T"class", Name, -- Name
			generic_parameters, '?', -- Generics
			r(T"extends", typename), '?', -- Superclass
			class_body, '?'
		)
	class_body
		= r(T"{", class_member, '*', T"}")
	class_member
		= r(annotate, '*', class_attribute | op_method)  << {branch="Element"}
		| r(T"implement", typename, implementation_body) << {branch="InterfaceImpl"} -- Local interface implementation
		| interface_requirement
		| structure -- Nested structure
	class_attribute
		= r(Visibility, '?', T"static", '?', constructor | method | property)
	constructor
		= r(T"new", parameters, perform, '?')
	method
		= r(T"fn", Name, signature, perform, '?')
	property
		= r(variable, accessors | get, '?')
	accessors
		= r(
			r(T"{", getter, setter, '*', T"}"), '?', -- Getter with optional setters
			r(T"=", exp), '?' -- Optional initial value
		)
	getter
		= r(T"get", r(signature, '?', perform), '?')
	setter
		= r(Visibility, '?', T"set", r(signature, '?', perform), '?')
	get
		= r(T"=>", stat)
	op_method
		= r(T"op", Name, signature, perform, '?')

	-- Interface
	interface
		= r(
			T"interface", Name, -- Name
			generic_parameters, '?', -- Generics
			interface_body
		)
	interface_body
		= r(T"{", interface_member, '*', T"}")
	interface_member
		= interface_requirement
		| r(annotate, '*', interface_attribute) << {branch="Element"}
		| structure -- Nested structure
	interface_attribute
		= method
		| property
		| op_method
	interface_requirement
		= r(T"implement", typename, r(T",", typename), '*')

	-- Enum
	enum
		= r(
			T"enum", Name,
			T"{", enum_member, '*', T"}"
		)
	enum_member
		= r(annotate, '*', enum_attribute)
	enum_attribute
		= property
		| enum_value
		| constructor
	enum_value
		= r(Name, r(T"=", number), '?') << {branch="Numeric"}
		| r(Name, arguments)            << {branch="Constructed"}

	-- Annotation
	annotate
		= r(T"@", Name, arguments, '?')
	annotation
		= r(
			T"@interface", Name,
			T"{", annotation_member, '*', T"}"
		)
	annotation_member
		= r(annotate, '*', annotation_attribute)
	annotation_attribute
		= property
		| constructor
		| enum

	-- Implementation
	implementation
		= r(
			T"implement", Name, -- Interface to implement
			generic_parameters, '?', -- Interface generics
			T"for", typename, -- Class to implement on
			implementation_body
		)
	implementation_body
		= r(T"{", implementation_member, '*', T"}")
	implementation_member
		= r(annotate, '*', implementation_attribute)
	implementation_attribute
		= method
		| property
		| op_method
end)

return language