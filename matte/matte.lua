local list = require "matter.utils.list"
local status = require "matter.utils.status"
local scope = require "matter.utils.scope"
local Language = require "matter.language"

local language = Language:new{}

--- @diagnostic disable: global-in-nil-env, lowercase-global, param-type-mismatch
language.grammar:define(function(_ENV)
	-- Layout
	entry -- Describes the contents of a script
		= r(import, '*', statement, '*')

	-- Imports
	import
		= r(T"import", import_module, r(T",", import_module), '*') -- Import a module
		| r(T"from", location, T"import", import_item, r(T",", import_item), '*') -- Destructure an import by name or a module by location
	import_module
		= r(location, import_alias, '?')
	import_item
		= r(Name, import_alias, '?')
	import_alias
		= r(T"as", Name)
	location -- The location of a module/submodule
		= path
		| modpath
	path -- A local submodule
		= r(Name, r(T".", Name), '*')
	modpath -- An external module or its submodule
		= r(Name, T":", path, '?')

	-- Statement
	statement
		= block
		| T"break"
		| T"continue"
		-- | r(T"return", expression, '?')                   << {assoc="right"}
		-- | r(T"yield", T"return", '?', expression, '?')    << {assoc="right"}
		| r(T"let", declarable, T"=", expression)         << {branch="DeclareVar", assoc="right"}
		| r(assignable, assign_op, '?', T"=", expression) << {branch="AssignVar", assoc="right"}
		-- | r(T"fn", Name, signature, perform)              << {branch="DeclareFn"}
		| expression << {filter="Call"}
		-- | r(expression, generic_arguments, '?', arguments) << {branch="Call"}
		-- | r(T"new", expression)   << {branch="New"}
		-- | if_else_stat
		-- | for_loop
	block -- An isolated list of statements
		= r(T"{", statement, '*', T"}")

	-- Expressions
	expression
		= constant
		| Name
		| Pattern
		| lambda
		| r(T"(", expression, T")")       << {branch="Group"}
		| r(T"[", expressions, '?', T"]") << {branch="Array"}
		| r(expression, generic_arguments, '?', arguments) << {branch="Call"}
		| r(T"new", expression)   << {branch="New"}
		| r(unary_op, expression) << {branch="Unary"}
		| r(expression, pow_op, expression)      << {branch="Pow"}
		| r(expression, prod_op, expression)     << {branch="MulDivRem"}
		| r(expression, sum_op, expression)      << {branch="AddSub"}
		| r(expression, shift_op, expression)    << {branch="Shift"}
		| r(expression, band_op, expression)     << {branch="BitAnd"}
		| r(expression, bxor_op, expression)     << {branch="BitXor"}
		| r(expression, bor_op, expression)      << {branch="BitOr"}
		| r(expression, relation_op, expression) << {branch="Relation"}
		| r(expression, and_op, expression)      << {branch="LogicAnd"}
		| r(expression, or_op, expression)       << {branch="LogicOr"}
		| r(expression, coal_op, expression)     << {branch="NullCoalesce"}
		| r(expression, range_op, expression)    << {branch="Range"}
		-- | r(expression, T"if", expression, T"else", expression) << {branch="Ternary"}
	expressions
		= r(expression, r(T",", expression), '*')
	argument
		= expression -- Positional argument
		| r(Name, T":", expression) -- Named argument
	arguments
		= r(T"(", r(argument, r(T",", argument), '*'), '?', T")")

	-- Flow control
	if_else_stat
		= r(if_stat, else_stat, '?')
	if_stat
		= r(T"if", expression, perform)
	else_stat
		= r(T"else", perform | if_else_stat)
	for_loop
		= r(T"for", variable, T"in", expression, perform)

	-- Functions
	lambda -- Anonymous function
		= r(Name, T"=>", statement) << {branch="Single"}
		| r(signature, perform)     << {branch="Multi"}
	signature -- Function signature with optional return type
		= r(generic_parameters, '?', parameters, r(T":", typename), '?')
	perform -- Function body
		= block
		| r(T"=>", statement)
	parameters
		= r(T"(", r(parameter, r(T",", parameter), '*'), '?', T")")
	parameter -- Named parameter with optional necessity, type, or default value
		= r(Name, T"?", '?', r(T":", typename), '?', r(T"=", expression), '?')
	generic_parameters
		= r(T"<", generic, r(T",", generic), '*', T">")
	generic_parameter -- Named generic parameter with type inheritance and optional default
		= r(Name, r(T":", typename, r(T"+", typename), '*'), '?', r(T"=", typename), '?')

	-- Types
	typename
		= primitive
		| r(T"...", typename) -- Rest of type
		| r(typename, T"[", T"]") -- Array of type
		| r(T"[", r(typename, r(T",", typename), '*'), '?', T"]") -- Tuple of types
		| r(Name, generic_arguments, '?', r(T"from", String), '?') -- Type with generic
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
	variable -- Variable with optional type
		= r(Name, r(T":", typename), '?')
	declarable
		= r(variable, r(T"as", declarable), '?')
		| r(T"[", declarable, r(T",", declarable), '*', T"]") << {branch="ArrayDestruct"}
		| r(T"{", declarable, r(T",", declarable), '*', T"}") << {branch="ObjectDestruct"}
	assignable
		= Name
		| r(assignable, T".", Name)             << {branch="Member"}
		| r(assignable, T"[", expression, T"]") << {branch="Index"}
	assign_op
		= algebra_op
		| bitwise_op
		| condition_op

	-- Values
	constant
		= boolean
		| number
		| string
		| T"none" << {branch="None"}
	boolean -- Indicates logical truth
		= T"true"
		| T"false"
	number
		= Integer
		| Float
		| T"infinity" << {branch="Infinity"} -- Represents numerical infinity
		| T"nan"      << {branch="NaN"} -- Represents undefined numbers or those with indeterminate forms
	string
		= String
		| FString

	-- Operators
	unary_op
		= T"!"   << {branch="LogicNegate"}
		| T"~"   << {branch="BitNegate"}
		| T"+"   << {branch="Positive"}
		| T"-"   << {branch="Negative"}
		| T"++"  << {branch="Increment"}
		| T"--"  << {branch="Decrement"}
		| T"..." << {branch="Spread"}
	binary_op
		= algebra_op
		| bitwise_op
		| condition_op
		| range_op
		| convert_op
	algebra_op
		= pow_op
		| prod_op
		| sum_op
	bitwise_op
		= shift_op
		| band_op
		| bxor_op
		| bor_op
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
	condition_op
		= and_op
		| or_op
		| coal_op
	sum_op
		= T"+"
		| T"-"
	prod_op
		= T"*"
		| T"/"
		| T"%"
	pow_op
		= r(T"*", T"*")
	shift_op
		= r(T"<", T"<") << {branch="Left"}
		| r(T">", T">") << {branch="Right"}
	band_op
		= T"&"
	bxor_op
		= T"^"
	bor_op
		= T"|"
	and_op
		= T"&&"
	or_op
		= T"||"
	coal_op
		= T"%?%?"
	range_op
		= T".."
	convert_op
		= T"as"

	-- Prevent new lines from blocking
	Endline = t("\n%s*", "\r\n%s*") << {ignore=true}

	-- Ignore all whitespace
	Whitespace = t("(%s+)[^\n\r]", "%s+$") << {ignore=true}

	-- Ignore comments
	Comment = t(
		"//.-\n", "//.-\r\n", "//[^\n\r]-$", --Single line comment
		"/%*.-%*/" -- Multiline comment
	) << {ignore=true}

	-- Indicates where a structure's member be referenced from
	Visibility = t(
		"public", -- Anywhere
		"protected", -- Sub-structures
		"private" -- Original structure only
	)

	-- Integer with optional exponent
	Integer = t("%-?%d+", "%-?%d+[eE]%-?%d+")

	-- Float with optional exponent
	Float = t("%-?%d+%.%d+", "%-?%d+%.%d+[eE]%-?%d+")

	-- Refers to some entity
	Name = t"[%a_][%a%d_]*"

	-- Literal representing a Lua pattern
	Pattern = t"/[^/*].-[^\\]/"

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
					local i, j, value = text:find("[^\\]([{}\"])", pos)
	
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
					return text:sub(1, pos)
				end
			end
	
			return nil
		end
	)
end)

language.env.inf = math.huge
language.env.nan = 0/0

return language