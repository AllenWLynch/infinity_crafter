

craftsystem.fields = {
    __missing_resources = {},
    __machine_processes = {},
    __current_step = 'None',
    __current_order = 'Idle',
}

assert(_G.infinity_crafter.path, 'Could not load path to infinity_crafter directory from startup file.')

utils = dofile(_G.infinity_crafter.path..'/utils.lua')

assert(_G.infinity_crafter.settings ~= nil, 'Could not access infinity crafter settings')
settings = _G.infinity_crafter.settings

craftsystem = {}

craftsystem.inventory_sides = {'front','back','bottom', 'top'}

craftsystem.reversed_directions = {
    EAST = 'WEST',
    WEST = 'EAST',
    NORTH = 'SOUTH',
    SOUTH = 'NORTH',
    DOWN = 'UP',
    UP = 'DOWN'
}
craftsystem.interaction_directions = {
    front = settings.direction,
    top = 'UP',
    bottom = 'DOWN',
    back = craftsystem.reversed_directions
}

craftsystem.Recipe = {}
function craftsystem.Recipe:new(slotdata)
    local recipe = slotdata
    setmetatable(recipe, self)
    self.__index = self
    self.type = recipe
    self.__tostring = function (table) return textutils.serialize(table) end
    return recipe
end

function craftsystem.Recipe:scale(scalar)
    cp = craftsystem.Recipe:new(utils.copy(self))
    for slotnum, data in pairs(cp) do
        cp[slotnum].quantity = data.quantity * scalar
    end
    return cp
end

function craftsystem.Recipe:get_slot(slotnum)
    if self[slotnum] == nil then return 'None', 0 end
    return self[slotnum].item, self[slotnum].quantity
end

function craftsystem.Recipe:recipe_is_perfect(inv_data)
    return self:matches(inv_data) and inv_data:matches(self)
end

function craftsystem.Recipe:matches(inv_data)
    for slotnum, slotset in pairs(self) do
        inv_item, inv_quantity = inv_data:get_slot(slotnum)
        if inv_item ~= slotset.item or inv_quantity ~= slotset.quantity then
            return false
        end
    end
    return true
end

function craftsystem.Recipe:get_needed_resources()
    counter = utils.Counter()
    for slotnum, slotset in pairs(self) do
        counter[slotset.item] = counter[slotset.item] + slotset.quantity
    end
    return counter
end

function craftsystem.Recipe:slotsets()
    return function(recipe, key)
        nextSlotnum, slotset = next(recipe, key)
        if nextSlotnum == nil then return nil else
            return nextSlotnum, slotset.item, slotset.quantity
        end
    end, self, nil
end

function craftsystem.Recipe:item_in_recipe(item)
    in_recipe = 0
    for slotnum, slotset in pairs(self) do
        if slotset.item == item then
            in_recipe = in_recipe + slotset.quantity
        end
    end
    return in_recipe > 0, in_recipe
end

function craftsystem.Recipe:collect_items(is_crafted)
    for slotnum, item, quantity in self:slotsets() do
        local into_slot = slotnum + math.floor(slotnum/3.1)
        if not is_crafted then
            into_slot = nil
        end
        if not craftsystem.getItem(item, quantity, into_slot) then return false end
    end
    return true
end

function craftsystem.get_inventory_direction(side)
    assert(utils.listContains(craftsystem.inventory_sides, side), 'Inventory must not be on left or right side or turtle.')
    if side ~= 'back' then
        return craftsystem.interaction_directions[side]
    else
        return craftsystem.interaction_directions[side][settings.direction]
    end
end

function craftsystem.getInventories() 
    local inventories = {}
    for _, side in pairs(craftsystem.inventory_sides) do  
        if peripheral.isPresent(side) and peripheral.getMethods(side)[1] == 'getInventoryName' then
            inventories[craftsystem.reversed_directions[craftsystem.get_inventory_direction(side)]] = peripheral.wrap(side)
        elseif side == 'top' then
            error('Cannot detect top inventory. This is necessary for outputting items')
        end
    end
    return inventories
end

function craftsystem.getResourcesInInventory(inv_peripheral)
    local items = utils.Counter()
    for interaction_direction, inv_peripheral in pairs(craftsystem.getInventories()) do
        for slotnum, wrapper in pairs(inv_peripheral.getAllStacks()) do
            slotdata = wrapper.all()
            items[slotdata.id] = items[slotdata.id] + slotdata.qty
        end
    end
    return items
end

-- changed: no
function craftsystem.getAllResources(inventories)
    local items = utils.Counter()
    for side, inv_peripheral in pairs(inventories or craftsystem.getInventories()) do
        items = items + craftsystem.getResourcesInInventory(inv_peripheral)
    end
    -- get resources in its own inventory
    for i = 1, 16 do
        if turtle.getItemCount(i) > 0 then
            slot_details = turtle.getItemDetail(i)
            items[slot_details.name] = items[slot_details.name] + slot_details.count
        end
    end
    return items
end

-- changed: yes
function craftsystem.ejectItem(slot, quantity)
    quantity = quantity or turtle.getItemCount(slot)
    for direction, inv_peripheral in pairs(craftsystem.getInventories()) do
        quantity = quantity - inv_peripheral.pullItemIntoSlot(direction, slot, quantity)
        if quantity <= 0 then return true end
    end
    return false
end

function craftsystem.ejectAllItems()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 and not craftsystem.ejectItem(slot) then 
            return false 
        end
    end
    return true
end

-- changed: yes
function craftsystem.getItem(item_name, quantity, into_slot)
    for interaction_direction, inv_peripheral in pairs(craftsystem.getInventories()) do
        for slotnum, slotdata in pairs(inv_peripheral.getAllStacks()) do
            if slotdata.all().id == item_name then
                quantity = quantity - inv_peripheral.pushItemIntoSlot(interaction_direction, slotnum, quantity, into_slot)
                if quantity <= 0 then return true end
            end
        end
    end
    return false
end

function craftsystem.repeat_task_until_true(task, output_stream, message, ...)
    local errored = false
    while not task(table.unpack({...})) do
        if not errored then output_stream:message(message) end
    end
    if errored then output_stream:hide_message() end
end

local Machine_Queue = {}

function Machine_Queue.new_machine_step(product_name, initial, quantity, last_craft)
    return {
        product_name = product_name,
        initial = initial,
        quantity = quantity,
        last_craft = last_craft,
        progress = 0,
    }
end

function Machine_Queue.getExpectedResources(queueTable, available_resources)
    local expected = utils.Counter()
    for _, step in pairs(queueTable) do
        expected.increment(step.product_name, step.quantity - available_resources[step.product_name] + step.initial)
    end
    return expected
end

function Machine_Queue.fullfillRequests(queueTable, available_resources)
    local i = 0
    while i < #queueTable do
        step = queueTable[i]
        if available_resources[step.product_name] - step.initial >= step.quantity then
            table.remove(queueTable, i)
            -- update the API
		else
            step.progress = math.max(0, (availableResources[step.product_name] - step.initial)/step.quantity)
            -- update the API
        end
        i = i + 1
    end
end

function Machine_Queue.adjustInitialValues(queueTable, used_resources)
    for _, step in pairs(queueTable) do
        step.initial = step.initial - used_resources[step.product_name]
    end
end

--enqueue(machine_queue_instance, product_name, quantity, items, quantity, last_craft)
function Machine_Queue.enqueue(queueTable, product_name, quantity, items, last_craft)
    initial = items[product_name] + Machine_Queue.getExpectedResources(queueTable,items)[product_name]
    table.insert(queueTable, Machine_Queue.new_machine_step(product_name, initial, quantity, last_craft))
end

function craftsystem.set_up_inventory(scaled_slotdata, is_crafted, output_stream)
    
    craftsystem.repeat_task_until_true(craftsystem.ejectAllItems, output_stream, 'ERROR: Cannot eject items. Clear space in inventories.')
    turtle.select(1)
    
    return scaled_slotdata:collect_items(is_crafted)
        
end

function turtle_is_empty(exclude_slots)
    for i = 1, 16 do
        if turtle.getItemCount(i) > 0 then
            return false
        end
    end
    return true
end

function craftsystem.craft(last_craft)
    turtle.select(4)
    repeat
        assert(turtle.craft, 'Crafting turtle does not have a crafting table attachment.')

        while not turtle.craft() do 
            input_args = {coroutine.yield('user_interaction','choice','Crafting failed. Fix recipe manually.','Cancel','Retry')}
            if input_args[1] == 'COMMAND' and input_args[2] == 'CHOICE' and input_args[3] == 'CANCEL' then
                error('Crafting canceled by user')
            end
        end
        
        while not turtle.dropUp() do
            corotuine.yield('user_interaction','message','Cannot eject product. Clear space in upper inventory.')
        end

    until turtle_is_empty()
    return true
end

function craftsystem.machine(machine_queue_instance, output_item, quantity, items, machine_options, last_craft)
    
    if _G.infinity_crafter.settings.use_modem then
        --_G.infinity_crafter.settings.modem_channel
    else
        --output_stream:message('Machine items with:\n'..utils.join('\n', machine_options))
    end
    
    Machine_Queue.enqueue(machine_queue_instance, product_name, quantity, items, quantity, last_craft)
    while not turtle_is_empty() do coroutine.yeild() end
    --output_stream:hide_message()
end

function craftsystem.execute(request_name, order_quantity)
 
    assert(http, 'Enable http api in computercraft configs to use this program.')
    
    local completed_request = false
    local url_request_name = string.gsub(request_name, ' ', '+')

    -- instantiate some form of machineserver
    local machine_queue_instance = {}

    local prev_items = {}
    local last_craft = false
    local crafting_info = nil

    local input_args = {}

    crafting_coro = coroutine.create(function () return end)
    coroutine.resume(crafting_coro)

    repeat
        -- get all the resoures in the inventory
        local items = craftsystem.getAllResources()

        -- fullfill machine requests on machine server
        Machine_Queue.fullfillRequests(machine_queue_instance, items)

        -- add resources expected from machine requests to the resource pool
        local expected_items = Machine_Queue.getExpectedResources(machine_queue_instance, items) + items

        -- get crafting tree from server, 
            -- this returns the missing resources, the craftqueue itself, and the used resources
        if not (expected_items == prev_items) then
            local instructions_url = settings.server_url .. 'instructions?for=' .. url_request_name ..'&quantity=' .. tostring(order_quantity)
            local response = http.get(instructions_url, {inventory = utils.luadict_to_json(expected_items)})
            assert(response, 'Could not connect to server')      
            assert(response.getResponseCode() == 200, 'Server Error. Check server\'s status')
            crafting_info = textutils.unserialize(response.readAll())
            crafting_info.machine_processes = Machine_Queue.get_summary()
            coroutine.yield('crafting_info',crafting_info)
        end

        if not coroutine.status(crafting_coro) == 'dead' then
           
            -- change this
            --assert(coroutine.resume(crafting_coro))
            status = {coroutine.resume(crafting_coro, table.unpack(input_args))}
            assert(status[1], status[2])
            if startus[2] == 'user_interaction' then
                coroutine.yeild('user_interaction', table.unpack(utils.slice(status, 3)))
            end

        elseif len(crafting_info.craft_queue) > 0 then

            local next_recipe_id = crafting_info.craft_queue[1].id    
            local quantity = crafting_info.craft_queue[1].quantity
            
            local response = http.get(settings.server_url.."recipes/"..tostring(next_recipe_id))
            assert(response, 'Could not connect to server')
            assert(response.getResponseCode() == 200, 'Server Error. Check server\'s status.')
            recipe = textutils.unserialize(response.readAll())
            
            slotdata = craftsystem.Recipe:new(recipe.slotdata)

            --self.current_step = tostring(quantity)..'x'..recipe.display_name

            craft_quantity = math.min(quantity, recipe.min_maxstack)
            scaled_slotdata = slotdata:scale(craft_quantity)

            last_craft = recipe.display_name == request_name and quantity <= craft_quantity

            if items:contains( scaled_slotdata:get_needed_resources() ) and craftsystem.set_up_inventory(scaled_slotdata, recipe.is_crafted, self.output_stream) then
                coroutine.yield('current_step', tostring(quantity)..'x'..recipe.display_name)
                if recipe.is_crafted then
                    crafting_coro = coroutine.create(craftsystem.craft)
                    assert(coroutine.resume(crafting_coro, last_craft, output_stream))
                else
                    crafting_coro = coroutine.create(craftsystem.machine)
                    assert(coroutine.resume(crafting_coro, machine_queue_instance, recipe.recipe_name, craft_quantity * recipe.makes, expected_items, recipe.machine_with, last_craft, self.output_stream))
                end
            end
        else
            if #machine_queue_instance > 0 then
                self.current_step = 'Waiting for machine processing.'
            else
                self.current_step = 'Waiting for missing resources.'
            end
        end
        prev_items = expected_items
        input_args = {coroutine.yield('wait_for_input')}
    until coroutine.status(crafting_coro) == 'dead' and last_craft
    return true
end