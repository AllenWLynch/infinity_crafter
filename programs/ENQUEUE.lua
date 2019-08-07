local args = {...}
assert(#args == 1, 'Too many args passed to function ENQUEUE')
assert(type(args[1]) == 'string', 'argument for ENQUEUE must be string: NxItem')
fields.__queue[#fields.__queue + 1] = args[1]