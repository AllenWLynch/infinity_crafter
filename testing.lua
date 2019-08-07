
require './utils'

tab = {
    key1 = 1,
    otherkey = 'stuff',
    subtab = {
        subkey = 'sub',
        key2 = 'yeet'
    }
}

--print(utils.serialize_to_element_assignments(tab))

c = coroutine.create(function (x) print(x) end)

coroutine.resume(c, 'hi')
