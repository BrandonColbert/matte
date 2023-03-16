test = require "matter.utils.test"
local list = require "matter.utils.list"
local status = require "matter.utils.status"
local scope = require "matter.utils.scope"
local Language = require "matter.language"

local language = Language:new{}

--- @diagnostic disable: global-in-nil-env, lowercase-global
language.grammar:define(function(_ENV)
	Whitespace = t("(%s+)[^\n\r]", "%s+$") << {ignore=true}
	Comment = t("//.-\n", "//.-\r\n", "//[^\n\r]-$", "/%*.-%*/") << {ignore=true}

	Integer = t"%-?%d+"
	Float = t"%-?%d+%.%d+"
	Variable = t("[%a]", "[%a]_[%w]+")

	sum_op
		= T"+"
		| T"-"
	prod_op
		= T"*"
		| T"/"
	pow_op
		= T"^"
	number
		= Integer
		| Float
		| T"inf"
		| T"nan"
	exp
		= number
		| Variable
		| r(T"(", exp, T")")
		| r(T"|", exp, T"|") << {branch="Abs"}
		| r(sum_op, exp) << {assoc="right"}
		| r(exp, pow_op, exp) << {assoc="right"}
		| r(exp, prod_op, exp)
		| r(exp, sum_op, exp)
		| r(exp, T"!") << {branch="Factorial", assoc="right"}
		| r(T"sqrt", T"(", exp, T")")
		| r(T"log" | T"ln", number, '?', r(T"^", number), '?', T"(", exp, T")") << {branch="Log"}
		| r(T"sum" | T"prod", exp, T"from", Variable, T"=", Integer, T"..", Integer) << {branch="Seq"}
	entry
		= r(exp, r(T",", Variable, T"=", number), '*')
end)

language.translator:defineDefault()

--- @param p Program
--- @param exp RuleNode
language.translator:define("exp", "Abs", function(p, _, exp, _)
	p:write("abs(")
	p:translate(exp)
	p:write(")")
end)

--- @param p Program
--- @param exp RuleNode
language.translator:define("exp", "Factorial", function(p, exp, _)
	p:write("fact(")
	p:translate(exp)
	p:write(")")
end)

--- @param p Program
--- @param name RuleNode
--- @param base? RuleNode
--- @param exponent? RuleNode
--- @param exp RuleNode
language.translator:define("exp", "Log", function(p, name, base, exponent, _, exp, _)
	if base or name:getMainBranch() == 1 then
		p:write("log")
	elseif name:getMainBranch() == 2 then
		p:write("ln")
	end	

	p:write("(")
	p:translate(exp)

	p:write(",")

	if base then
		p:translate(base)
	else
		p:write("nil")
	end

	p:write(",")

	if exponent then
		local _, _, exponentEntries = exponent:getMainBranch()
		p:translate(exponentEntries[2][1])
	else
		p:write("nil")
	end

	p:write(")")
end)

--- @param p Program
--- @param name RuleNode
--- @param term RuleNode
--- @param variable TokenNode
--- @param lower TokenNode
--- @param upper TokenNode
language.translator:define("exp", "Seq", function(p, name, term, _, variable, _, lower, _, upper)
	if name:getMainBranch() == 1 then
		p:write("sum")
	elseif name:getMainBranch() == 2 then
		p:write("prod")
	end	

	p:write("(")
	p:translate(lower)
	p:write(",")
	p:translate(upper)
	p:write(",\"")
	p:translate(variable)
	p:write("\",_ENV,")
	p:pushLine("function(_ENV)")
		p:pushLine("return(")
			p:translate(term)
			p:line()
		p:popLine(")")
	p:popWrite("end)")
end)

--- @param p Program
--- @param exp RuleNode
--- @param variables RuleNode[]
language.translator:define("entry", function(p, exp, variables)
	for variable in list(variables) do
		local _, _, entries = variable:getMainBranch()

		p:translate(entries[2][1])
		p:write("=")
		p:translate(entries[4][1])
		p:line()
	end

	p:pushLine("return(")
		p:translate(exp)
		p:line()
	p:popWrite(")")
end)

language.env.inf = math.huge
language.env.nan = 0/0
language.env.abs = math.abs

function language.env.sqrt(x)
	return math.sqrt(x)
end

function language.env.log(x, base, exponent)
	return math.log(x, base or 10)^(exponent or 1)
end

function language.env.ln(x, exponent)
	return math.log(x)^(exponent or 1)
end

function language.env.seq(lower, upper, variable, env, fn)
	return list{0}
		:repeated(1 + upper - lower)
		:map(function(_, index)
			return lower + index - 1
		end)
		:map(function(item)
			return fn(scope({[variable]=item}, env))
		end)
end

function language.env.sum(lower, upper, variable, env, fn)
	return language.env.seq(lower, upper, variable, env, fn):reduce(function(total, next)
		return total + next
	end, 0)
end

function language.env.prod(lower, upper, variable, env, fn)
	return language.env.seq(lower, upper, variable, env, fn):reduce(function(product, next)
		return product * next
	end, 1)
end

function language.env.fact(x)
	function gamma(z)
		return 1/z * language.env.prod(1, 1000, "n", language.env, function(_ENV)
			return (1 + 1/n)^z / (1 + z/n)
		end)
	end

	return x * gamma(x)
end

--- @param src string
--- @return ...
function run(src)
	local ast = language:parse(src)
	local program = language:transpile(ast)
	return language:run(program)
end

test("calculator", function(_ENV)
	assert.nearly(3, run("1 + 2"))
	assert.nearly(8, run("|1 - 3|^3"))
	assert.nearly(-1.763e27, run("1 - 2^3^4 * 3^6 + (5+1)^6 / 8"), 4)
	assert.nearly(1.1, run("ln(3)"), 3)
	assert.nearly(0.477, run("log(3)"), 3)
	assert.nearly(0.396, run("log16(3)"), 3)
	assert.nearly(35, run("sum 2*i + 1 from i=1..5"))
	assert.nearly(120, run("prod i+1 from i=1..4"))
	assert.nearly(-170, run("sum 2 * sum j/2 - i from j=-2..7 + 1 from i=1..5"))
	assert.nearly(24, run("4!"), 2)
	assert.nearly(1.329, run("1.5!"), 4)
	assert.nearly(
		math.sin(0.75),
		run("sum (-1)^n / (2 * n + 1)! * x^(2 * n + 1) from n=0..100, x=0.75"),
		2
	)
	-- 0.5
	-- 1.3e5
	-- 1 + 2.0 + 3 + 4.5 + 5
	-- (1)
	-- 1+(2+3)
	-- 1 + 2^3^4 + 5^6
	-- 1 + 2^3^(4+2)^6 + 5^6
	-- 1 + 2 * 3
	-- 1 + 2 * 3 + 4 * 6 * 7
	-- 1 - 2^3^4 * 3^6 + (5+1)^6 / 8
	-- 1 + 2**3^4
	-- 1 + 2**3^4^5**6^7
	-- 1 - ++2^6
	-- |1 - 3|^3
	-- log2^4(3)
end)

local src = io.read("*a")
local ast = language:parse(src)
local program = language:transpile(ast)

status:write{program or "none"}
status:print{" -> %s", fmt={language:run(program) or "?"}}

return language:process(src)