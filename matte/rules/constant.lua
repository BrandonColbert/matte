local matte = require "matte.matte"

matte.translator:define("constant")

matte.translator:define("constant", "None", function(p)
	p:write("none")
end)