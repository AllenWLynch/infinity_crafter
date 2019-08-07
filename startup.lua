
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