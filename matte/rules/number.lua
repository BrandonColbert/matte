local matte = require "matte.matte"

matte.translator:define("Integer")
matte.translator:define("Float")
matte.translator:define("number")

matte.translator:define("number", "Infinity", function(p)
	p:write("math.huge")
end)

matte.translator:define("number", "NaN", function(p)
	p:write("0/0")
end)