function testFunc2()
    error('error message')
end

function testFunc()
    print('here')
    return testFunc2()
end

function testCoro()
    while true do
        print('here')
        local ret = coroutine.yield()
        if ret == 'stop' then
            print('errored')
            error('error message STOPPED')
        end
    end
end

function coro_wrapper(x)
    local c = coroutine.create(testCoro)
    for i = 1, x do
        coroutine.resume(c, 'dont stop')
    end
    local ret, msg = coroutine.resume(c, 'stop')
    
    print('ret: ',ret, '\nmsg: ',msg)
    print('finished')
    print(c.status())
end


--print(pcall(testFunc))
coro_wrapper(3)

