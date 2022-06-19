--- Used to perform list operations
--- @class List
--- @field items any[]
local List = {}
List.__index = List

--- @param items any[]
function List:new(items)
	local o = {items=items}
	setmetatable(o, self)

	return o
end

--- Returns an iterator for the key-value pairs of the list
function List:entries()
	return ipairs(self.items)
end

--- Returns an iterator for the list's keys
--- @return fun(): integer
function List:keys()
	local i = 0

	return function()
		if i < #self then
			i = i + 1

			return i
		end
	end
end

--- Returns an iterator for the list's values
--- @return fun(): any
function List:values()
	local i = 0

	return function()
		if i < #self then
			i = i + 1

			return self.items[i]
		end
	end
end

--- Returns the item at the index
--- @param index number Item index
--- @return any
function List:at(index)
	if index < 0 then
		index = 1 + #self + index
	end

	return self.items[index]
end

--- Returns whether every item passed the test
--- @param predicate fun(item: any, index?: number): boolean Test function
--- @return boolean
function List:every(predicate)
	for key, value in self:entries() do
		if not predicate(value, key) then
			return false
		end
	end

	return true
end

--- Returns whether at least one item passed the test
--- @param predicate fun(item: any, index?: number): boolean Test function
--- @return boolean
function List:some(predicate)
	for key, value in self:entries() do
		if predicate(value, key) then
			return true
		end
	end

	return false
end

--- Returns a new list with the items that passed the test
--- @param predicate fun(item: any, index?: number): boolean Test function
--- @return List
function List:filter(predicate)
	local items = {}

	for key, value in self:entries() do
		if predicate(value, key) then
			table.insert(items, value)
		end
	end

	return List:new(items)
end

--- Returns a new list with items resulting from the transformation
--- @param selector fun(item: any, index?: number): any Transformation function
--- @return List
function List:map(selector)
	local items = {}

	for key, value in self:entries() do
		table.insert(items, selector(value, key))
	end

	return List:new(items)
end

--- Returns the first element that passes the test
--- @param predicate fun(item: any, index?: number): boolean Test function
--- @return any
function List:find(predicate)
	for key, value in self:entries() do
		if predicate(value, key) then
			return value
		end
	end

	return nil
end

--- Returns the index of the first element that passes the test
--- @param predicate fun(item: any, index?: number): boolean Test function
--- @return any
function List:findIndex(predicate)
	for key, value in self:entries() do
		if predicate(value, key) then
			return key
		end
	end

	return nil
end

--- Adds, removes, or replaces items in-place.
--- @param startIndex number Position to begin splicing
--- @param deleteCount number Items to remove after the start index
--- @param ... any Items to add after deleting
--- @return List List containg the deleted items
function List:splice(startIndex, deleteCount, ...)
	local removed = {}
	local added = {...}

	for i = 1, deleteCount do
		table.insert(removed, table.remove(self.items, startIndex))
	end

	for i = #added, 1, -1 do
		table.insert(self.items, startIndex, added[i])
	end

	return List:new(removed)
end

--- Adds items to the end of the list
--- @param ... any Items to add
function List:push(...)
	self:splice(#self + 1, 0, ...)
end

--- Removes and returns the last item of the list
--- @return any
function List:pop()
	return self:splice(#self, 1):at(1)
end

--- Adds items to the start of the list
--- @param ... any Items to add
function List:unshift(...)
	self:splice(1, 0, ...)
end

--- Removes and return the first item of the list
--- @return any
function List:shift(...)
	return self:splice(1, 1):at(1)
end

--- Returns the result of reducing the list
--- @param reducer fun(previous: any, current: any): any
--- @param initialValue any
--- @return any
function List:reduce(reducer, initialValue)
	local result, start
	
	if initialValue then
		result = initialValue
		start = 1
	else
		result = self.items[1]
		start = 2
	end

	for i = start, #self do
		result = reducer(result, self.items[i])
	end

	return result
end

--- Returns a new list with the same items in reverse order
--- @return List
function List:reverse()
	local reversed = {}

	for i = #self, 1, -1 do
		table.insert(reversed, self.items[i])
	end

	return List:new(reversed)
end

--- Returns a new list with a shallow copied portion of the original items
--- @param startIndex number Start index or first index if unspecified
--- @param endIndex number End index or last index if unspecified
--- @return List
function List:slice(startIndex, endIndex)
	if not startIndex then
		startIndex = 1
	elseif startIndex < 0 then
		startIndex = 1 + #self + startIndex
	end

	if not endIndex then
		endIndex = #self
	elseif endIndex < 0 then
		endIndex = 1 + #self + endIndex
	end

	local items = {}

	for i = startIndex, endIndex do
		table.insert(items, self.items[i])
	end

	return List:new(items)
end

--- Returns a new list with items in the specified order
--- @param comparator fun(a: any, b: any): boolean Whether the first item should come first
--- @return List
function List:sort(comparator)
	local items = {table.unpack(self.items)}
	table.sort(items, comparator)

	return List:new(items)
end

--- Returns the items of the list
--- @return any 
function List:unpack()
	return table.unpack(self.items)
end

--- @param other List
function List:__eq(other)
	if not (getmetatable(other) == getmetatable(self) and #self == #other) then
		return false
	end

	for i = 1, #self do
		if self:at(i) ~= other:at(i) then
			return false
		end
	end

	return true
end

function List:__len()
	return #self.items
end

function List:__tostring()
	local items = self:map(function(item)
		return tostring(item)
	end).items

	return string.format("[%s]", table.concat(items, ", "))
end

--- Returns list with the given items
--- @param items any[]
--- @return List
function list(items)
	return List:new(items)
end

return list