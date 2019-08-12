

utils = {}

local counter_mt = {   
    __index = setmetatable({
        increment = function (table, key, steps) 
                        steps = steps or 1
                        assert(type(steps) == 'number', 'Cannot increment counter by a non-number value')
                        table[key] = table[key] + steps 
                        return table[key] end,
        decrement = function (table, key, steps) 
                        steps = steps or 1
                        assert(type(steps) == 'number', 'Cannot increment counter by a non-number value')
                        table[key] = table[key] - steps 
                        return table[key] end,
        contains = function (table, subset)
                        for item, quantity in pairs(subset) do
                            if table[item] < quantity then
                                return false
                            end
                        end
                        return true
                    end,
        merge = function (table, other, inplace)
                    inplace = inplace or true
                    for item, quantity in pairs(other) do
                        table[item] = table[item] + quantity
                    end
                    if not inplace then
                        return table
                    end
                end,
        invert = function (table)
                    copy = utils.Counter(utils.copy(table))
                    for item, quantity in pairs(copy) do
                        copy[item] = -1 * quantity
                    end
                    return copy
                end,
        },
        {
            __index = function (table, key) return 0 end
        }
    ),
    __newindex= function (table, key, value)
                    assert(type(value) == 'number', 'Cannot increment counter by a non-number value')
                    mt = getmetatable(table).__index
                    rawset(table, key, value)
                end,
    __add = function (thisCounter, otherCounter)
                copy = utils.Counter(utils.copy(thisCounter))
                for key, value in pairs(otherCounter) do
                    copy[key] = copy[key] + value
                end
                return copy
            end,
    __mul = function (table, scalar)
                for key, value in pairs(table) do
                    table[key] = value * scalar
                end
                return table
            end,
    __tostring = function (table) 
                    outputStr = ''
                    for item, quantity in pairs(table) do
                        outputStr = outputStr ..tostring(quantity)..'x'..tostring(item)..'\n'
                    end
                    return outputStr
                end,
    __eq = function (table, other)
                for item, quantity in pairs(table) do
                    if not other[item] == quantity then return false end
                end
                for item, quantity in pairs(other) do
                    if not table[item] == quantity then return false end
                end
                return true
            end,
}
-- Counter construct
function utils.Counter(dict)
    return setmetatable(dict or {}, counter_mt)
end

function utils.splitString(inputStr, splitChar)
    sep = sep or "%s"
    local t={}
    for str in string.gmatch(inputStr, "([^"..splitChar.."]+)") do
            table.insert(t, str)
    end
    return t
end

function utils.join(sep, list)
    local firstElement = true
    outputStr = ''
    for _, value in ipairs(list) do
        if not firstElement then
            outputStr = outputStr .. sep
        end
        outputStr = outputStr .. tostring(value)
        firstElement = false
    end
    return outputStr
end

function utils.slice(list, start, finish, increment)
    start = start or 1
    finish = finish or #list
    increment = increment or 1
    returnTable = {}
    for i = start, finish, increment do
        assert(list[i] ~= nil, 'List is not structured like an array, cannot be sliced')
        returnTable[#returnTable + 1] = list[i]
    end
    return returnTable
end

function utils.listContains(list, value)
    for key, __value in pairs(list) do
        if value == __value then
            return true
        end
    end
    return false
end

local function copyTable(toTable, fromTable)
	for index, stuff in pairs(fromTable) do
		if type(stuff) == "table" then
			toTable[index] = {}
			copyTable(toTable[index], stuff)
		else
			toTable[index] = stuff
		end
	end
end

function utils.copy(fromTable)
	local copy = {}
	copyTable(copy, fromTable)
	return copy
end

function utils.luadict_to_json(input)
    if type(input) == 'string' then
        return '\"' .. tostring(input) .. '"'
    elseif type(input) == 'number' then
        return tostring(input)
    elseif type(input) == 'boolean' then
        return string.lower(tostring(input))
    else
        cumm_str = '{'
        num_entries = 0
        for key, value in pairs(input) do
            if num_entries >= 1 then
                cumm_str = cumm_str .. ', '
            end
            cumm_str = cumm_str .. '"' .. tostring(key) .. '": ' .. utils.luadict_to_json(value) 
            num_entries = num_entries + 1
        end
        cumm_str = cumm_str .. '}'
        if num_entries == 0 then
            return '{}'
        else
            return cumm_str
        end
    end
end

function elements_recurse(prev_str, element)
    if type(element) == 'table' then
        local to_elements = {[1] = prev_str .. ' = {}'}
        for key, value in pairs(element) do
            to_elements[#to_elements + 1] = elements_recurse(prev_str .. '.' .. tostring(key), value)
        end
        return utils.join('\n\n', to_elements)
    elseif type(element) == 'number' then
        return prev_str .. ' = ' .. tostring(element)
    elseif type(element) == 'string' then
        return prev_str .. ' = "' .. tostring(element) ..'"'
    else
        error('function does not support type: ' .. type(element))
    end
end

function utils.serialize_to_element_assignments(table)
    return elements_recurse('settings', table)
end

utils.coro_wrapper = {}
function utils.coro_wrapper:new(func, ...)
    local o = setmetatable({
        routine = coroutine.create(func),
        params = {...},
        instantiated = false,
    },self)
    self.__index = self
    return o
end

function utils.coro_wrapper:resume(...)
    if not self.instantiated then
        self.instantiated = true
        return coroutine.resume(self.routine, table.unpack(self.params))
    else
        return coroutine.resume(self.routine, table.unpack({...}))
    end
end

function utils.coro_wrapper:status() return coroutine.status(self.routine) end

return utils


