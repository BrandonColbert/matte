local status = require "matter.utils.status"
local scope = require "matter.utils.scope"

--- @class Assert
local Assert = {}
Assert.__index = {}

--- Raises an error if the actual value if different from the expected
--- @param expected any Expected value
--- @param actual any Actual value
function Assert.equal(expected, actual)
	if expected ~= actual then
		Assert.raise("Expected %s, got %s", expected, actual)
	end
end

--- Raises an error if the actual value if different from the expected
--- @param expected any Expected value
--- @param actual any Actual value
function Assert.notEqual(expected, actual)
	if expected == actual then
		Assert.raise("Expected %s, got %s", expected, actual)
	end
end

--- Raises an error if the actual number differs from the expected number by more than n decimalss
--- @param expected number Expected number
--- @param actual number Actual number
--- @param n number Significant digits
function Assert.nearly(expected, actual, n)
	n = n or 10

	local specifier = string.format("%%.%dg", n)
	expected = tonumber(string.format(specifier, expected))
	actual = tonumber(string.format(specifier, actual))

	if expected ~= actual then
		Assert.raise("Expected %s, got %s", expected, actual)
	end
end

--- Raises an error if value is nil or false
--- @param value any
function Assert.ok(value)
	if not value then
		Assert.raise("Value is nil or false")
	end
end

--- Raises an error message with the specified formatting
--- @param msg string Message to be formatted
--- @param ... any Format arguments
function Assert.raise(msg, ...)
	error(string.format(msg, ...), 0)
end

--- @param name string
--- @param fn fun(_ENV: Env)
--- @return boolean
--- @alias Env {assert: Assert}|_G
function test(name, fn, depth)
	depth = depth or 0

	local subtests = list()
	local info --- @cast info debuginfo
	local reason --- @cast reason string

	--- @param msg string
	local function onError(msg)
		info = debug.getinfo(4)
		reason = msg
	end

	--- @param name string
	--- @param fn fun(_ENV: Env)
	local function createSubtest(name, fn)
		subtests:push({name, fn})
	end

	if xpcall(fn, onError, scope({assert=Assert, test=createSubtest}, _G)) then
		status:print{"%s%s", fmt={string.rep("\t", depth), name}}

		local result = true

		for subtest in subtests:values() do
			local name, fn = table.unpack(subtest)
			result = result and test(name, fn, depth + 1)
		end

		return result
	else
		if reason:match("[\n\r]") then
			status:print{
				"%s%s failed (%s:%d)",
				fmt = {
					string.rep("\t", depth),
					name,
					info.source,
					info.currentline
				}
			}

			for line in reason:gmatch("[^\n\r]+") do
				status:print{"%s%s", fmt={string.rep("\t", depth + 1), line}}
			end
		else
			status:print{
				"%s%s failed at line %d: %s",
				fmt = {
					string.rep("\t", depth),
					name,
					info.currentline,
					reason
				}
			}
		end

		return false
	end
end

return test