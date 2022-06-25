--- @class Escape
local Escape = {}
Escape.__index = Escape

--- Returns the escaped pattern string
--- @param text string
--- @return string
function Escape.pattern(text)
	return text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

--- Returns the escaped JSON string
--- @param text string
--- @return string
function Escape.json(text)
	return text
		:gsub("([\"\\])", "\\%1")
		:gsub("\r\n", "\\n")
		:gsub("\n", "\\n")
		:gsub("\t", "\\t")
end

-- Returns the escaped CLI parameter string
--- @param text string
--- @return string
function Escape.cli(text)
	return text
		:gsub("\\r\\n", "\n")
		:gsub("\\n", "\n")
		:gsub("\\t", "\t")
end

return Escape