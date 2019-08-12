
_G.infinity_crafter = {}

assert(turtle, 'This application must run on a turtle.')

-- Edit so that path points to program folder for the infinity_crafter
-- if program is in folder called 'infinity_crafter' in the root directory, do not change:
_G.infinity_crafter.path = './infinity_crafter'

assert(fs.exists(_G.infinity_crafter.path), 'Path to infinity_crafter directory is invalid. Change path on line 6 of startup to point to infinity_crafter root directory.')

_G.infinity_crafter.settings = dofile(_G.infinity_crafter.path .. '/settings.lua')
local craftsystem = dofile(_G.infinity_crafter.path .. '/craftsystem.lua')

_G.infinity_crafter.fields = {
    queue = {},
    user_input_queue = {},
}

local fields = _G.infinity_crafter.fields

function _G.infinity_crafter.execute(executeStr) 
    assert(type(executeStr) == 'string', 'Execute command must be comma-delinated string')
    local terms = utils.splitString(executeStr, ',')
    local program_name = terms[1]..'.lua'
    local params = {}
    if #terms > 1 then
        params = utils.slice(terms, 2)
    end

    assert(utils.listContains( fs.list(PATH_TO_FILES), program_name), 'Invalid command: '..program_name)
    local run_func = assert(loadfile(PATH_TO_FILES .. program_name), 'Failed to load file: ' .. PATH_TO_FILES .. program_name)
    local fields_table = {fields = _G.infinity_crafter.fields}
    new_global = setmetatable(fields_table, {__index = _G})
    setfenv(run_func, new_global)
    return run_func(table.unpack(params))
end

local prev_text = ''

local coro = utils.coro_wrapper:new(craftsystem.execute,'Furnace',1)

while not (coro:status() == 'dead') do
    
    local evt = {os.pullEvent()}

    local stats = {coro:resume(table.unpack(next_resume))}
    next_resume = {}

    assert(stats[1], stats[2])
    --print(stats[2])
    local method = stats[2]
    if method == 'GET_REQUEST' then
        next_resume = {http.get(stats[3], stats[4])}
    elseif method == 'CRAFTING_INFO' then
        --print('recieved crafting info')
    elseif method == 'CURRENT_STEP' then

    elseif method == 'USER_INTERACTION' then
        os.queueEvent(table.unpack(utils.slice(stats, 2)))
        local new_text = '\n> '
        if stats[3] == 'CHOICE' then
            new_text = new_text .. stats[4] ..'\nOptions: ' .. stats[5] .. '/' .. stats[6]
        elseif stats[3] == 'MESSAGE' or stats[3] == 'PROMPT' then
            new_text = new_text ..stats[4]
        end
        if not (new_text == prev_text) then
            local numlines = 3
            prev_text = new_text
            print(new_text)
        end
        active_user_interface = true
        if fields.user_input_queue > 0 then
            next_resume = {table.remove(fields.user_input_queue,1)}
        end
    elseif method == 'RESOLVE_INTERACTION' then
        active_user_interface = false
        fields.user_input_queue = {}
    end
end




