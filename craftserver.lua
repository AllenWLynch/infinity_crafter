
assert(_G.infinity_crafter.path, 'Could not load path to infinity_crafter directory from startup file.')

utils = dofile(_G.infinity_crafter.path..'/utils.lua')

assert(_G.infinity_crafter.settings ~= nil, 'Could not access infinity crafter settings')
settings = _G.infinity_crafter.settings

craftsystem = dofile(_G.infinity_crafter.path ..'craftsystem.lua')

craftserver = {}
function craftserver.execute(executeStr)
    assert(type(executeStr) == 'string', 'Execute command must be comma-delinated string')
    terms = utils.splitString(executeStr, ',')
    program_name = terms[1]..'.lua'
    params = {}
    if #terms > 1 then
        params = utils.slice(terms, 2)
    end

    assert(utils.listContains( fs.list(PATH_TO_FILES), program_name), 'Invalid command: '..program_name)
    local run_func = assert(loadfile(PATH_TO_FILES .. program_name), 'Failed to load file: ' .. PATH_TO_FILES .. program_name)
    local fields_table = {fields = craftsystem.fields}
    fields_table.queue = craftserver.queue
    new_global = setmetatable(fields_table, {__index = _G})
    setfenv(run_func, new_global)
    return run_func(table.unpack(params))
end

craftserver.OutputStream = {}


function craftserver.OutputStream:new()
    local o = setmetatable({
            streams = {},
    }, self)
    self.__index = self
    return o
end

function craftserver.OutputStream:addStream(stream)
    for _, method in pairs({'prompt','hide_prompt','choices','hide_choices','message','hide_message'}) do
        assert(stream[method], 'Stream does not contain method: ' .. method)
    end
    self.streams[#self.streams + 1] = stream
end

function craftserver.OutputStream:message(message)
    for _, stream in pairs(self.streams) do
        stream:message(message)
    end
end

craftserver.queue = {}

function craftserver.run(...)

    output = craftserver.OutputStream:new()
    for _, stream in pairs({...}) do
        outptut:addStream(stream)
    end

    local order_coro = coroutine.create(function () return end)
    order_coro.resume()

    while true do
        if not order_coro.status() == 'dead' then
            order_coro.resume()
        elseif order_coro.status() == 'dead' and #craftserver.queue > 0 then
            dequeued_order = table.remove(craftserver.queue, 1)
            order_coro = coroutine.create(craftsystem.direct_order)
            order_coro.resume(dequeued_order.request_name, dequeued_order.quantity, output)
        end
        os.pullEvent()
    end

end




