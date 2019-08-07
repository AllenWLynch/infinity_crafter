
_G.infinity_crafter = {}

-- Edit so that path points to program folder for the infinity_crafter
-- if program is in folder called 'infinity_crafter' in the root directory, do not change:
_G.infinity_crafter.path = './infinity_crafter'

assert(fs.exists(_G.infinity_crafter.path), 'Path to infinity_crafter directory is invalid. Change path on line 6 of startup to point to infinity_crafter root directory.')

_G.infinity_crafter.settings = dofile(_G.infinity_crafter.path .. '/settings.lua')
craftsystem = dofile(_G.infinity_crafter.path .. '/craftsystem.lua')


stick_slotdata = {
    [1] = {item = 'minecraft:planks', quantity = 1},
    [4] = {item = 'minecraft:planks', quantity = 1}
}
not_stick = {
    [1] = {item = 'minecraft:planks', quantity = 1},
    [4] = {item = 'minecraft:planks', quantity = 1},
    --[5] = {item = 'minecraft:planks', quantity = 1}
}

furnace = {}
for i = 1, 9 do
    if i ~= 5 then
        furnace[i] = {item = 'minecraft:cobblestone', quantity = 1}
    end
end
furnace_recipe = craftsystem.Recipe:new(furnace)

new_recipe = craftsystem.Recipe:new(stick_slotdata)
other_recipe = craftsystem.Recipe:new(not_stick)

--[[
print(new_recipe:matches(other_recipe), other_recipe:matches(new_recipe), new_recipe:recipe_is_perfect(other_recipe))

scaled_recipe = new_recipe:scale(5)
print(tostring(scaled_recipe))

print(tostring(scaled_recipe:get_needed_resources()))

need1 = scaled_recipe:get_needed_resources()
need2 = new_recipe:get_needed_resources()
print(tostring(need1 + need2), tostring(need1),tostring(need2))

print(need1:contains(need2))

for slotnum, item, quantity in new_recipe:slotsets() do
    print(slotnum, item, quantity)
end
]]

local output_stream = {}
function output_stream.prompt(message, prompt)
    print(message)
    print(prompt .. ' (hit enter to continue)')
    os.pullEvent('key')
end

function output_stream.unprompt()
    return
end

function output_stream.message(message)
    print(message)
end
function output_stream.hide_message()
    return
end

function output_stream.choice(message, choice1, choice2)
    print(message)
    print('1: ' .. choice1)
    print('2: '..choice2)
    local userinput = ''
    repeat
        userinput = read()
    until userinput == '1' or userinput == '2'
    if userinput == '1' then return choice1
    else return choice2 end
end

--print(stick_slotdata:collect_items('Crafter'))
--print(craftsystem.craft(furnace_recipe:scale(1), 'Crafter', false, {}, output_stream))

--print(craftsystem.directOrder('Test Item',2,output_stream))

--print(tostring(craftsystem.getAllResources()))

c1 = utils.Counter()
c2 = utils.Counter()

c1['one'] = 1
c2['one'] = 1

print(c1['two'])
c2['two'] = 1
print(tostring(c1), tostring(c2))
print(c1 == c2)