local matte = require "matte.matte"
local status = require "matter.utils.status"

local reserved = {}

--- @param p Program
--- @param text string
matte.translator:define("Name", function(p, text)
	if reserved[text] then
		status:except{"Word '%s' is reserved by Lua", fmt={text}}
	else
		p:write(text)
	end
end)

reserved["and"] = true
reserved["break"] = true
reserved["do"] = true
reserved["else"] = true
reserved["elseif"] = true
reserved["end"] = true
reserved["false"] = true
reserved["for"] = true
reserved["function"] = true
reserved["if"] = true
reserved["in"] = true
reserved["local"] = true
reserved["nil"] = true
reserved["not"] = true
reserved["or"] = true
reserved["repeat"] = true
reserved["return"] = true
reserved["then"] = true
reserved["true"] = true
reserved["until"] = true
reserved["while"] = true

reserved["_G"] = true
reserved["_ENV"] = true
reserved["_VERSION"] = true