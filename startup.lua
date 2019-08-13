
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
    missing_resources = {},
    machine_processes = {},
    current_step = 'None',
    current_build = 'None',
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

local input_queue = {}

local coro = utils.coro_wrapper:new(craftsystem.execute,'Furnace',1)

local crafting_coro = utils.coro_wrapper:new(function () return end)

local next_resume = {}

while not (coro:status() == 'dead') do

    local execution_status = {coro:resume(table.unpack(next_resume))}

    next_resume = nil
    
    assert(execution_status[1], execution_status[2])

    if not (execution_status[2] == nil) then
        print(utils.join(' ', utils.slice(execution_status, 2)))
    end

    if execution_status[2] == 'USER_INTERACTION' then
        
        if #input_queue > 0 then
            next_resume = {table.remove(input_queue, 1)}
        else
            next_resume = {}
        end
        os.queueEvent(table.unpack(utils.slice(execution_status, 3)))

    elseif execution_status[2] == 'RESOLVED' then
        input_queue = {}
        next_resume = {}
    elseif execution_status[2] == 'GET_REQUEST' then
        next_resume = {http.get(execution_status[3], execution_status[4])}
    elseif execution_status[2] == 'CRAFTING_INFO' then
        --print(textutils.serialize(execution_status[3]))
        next_resume = {}
    elseif execution_status[2] == 'PUSH_ITEM' then
        next_resume = {execution_status[3].pushItemIntoSlot(table.unpack(utils.slice(execution_status,4)))}
    elseif execution_status[2] == 'PULL_ITEM' then
        next_resume = {execution_status[3].pullItemIntoSlot(table.unpack(utils.slice(execution_status,4)))}
    elseif execution_status[2] == 'RUN' then
        next_resume = {execution_status[3](table.unpack(utils.slice(execution_status, 4)))}
    end

    if next_resume == nil then next_resume = {os.pullEvent()} end

end