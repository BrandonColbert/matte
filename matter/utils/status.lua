local list = require "matter.utils.list"
local funhel = require "matter.utils.funhel"

--- @class Status
local Status = {}
Status.__index = Status

--- @class Status_write: {[number]: any}
--- @field fmt? any[] String format arguments

--- @param t Status_write
function Status:write(t)
	local l = list{funhel:decompose(t)}
	local options = l:shift()

	local s = nil

	if options.fmt then
		s = string.format(l:at(-1), table.unpack(options.fmt))
	else
		s = table.concat(
			l:map(function(item, index)
				return tostring(item)
			end):table(),
			" "
		)
	end

	io.stderr:write(s)
	io.stderr:flush()
end

--- @param t Status_write
function Status:print(t)
	Status:write(t)
	Status:write{"\n"}
end

--- @param t Status_write
function Status:warn(t)
	Status:print(t)
end

--- @class Status_except: table
--- @field [1]? string Reason for exception
--- @field fmt? any[] String format arguments
--- @field cat? string Exception category

--- @param t Status_except
function Status:except(t)
	local options, reason = funhel:decompose(t)

	if reason then
		if options.fmt then
			self:except{string.format(reason, table.unpack(options.fmt))}
		else
			if options.cat then
				error(string.format("%s: %s", options.cat, reason), 2)
			else
				error(reason, 2)
			end
		end
	else
		error(2)
	end
end

return Status