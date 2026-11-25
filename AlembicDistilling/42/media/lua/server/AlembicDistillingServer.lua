--- Находит стационарный куб по координатам и индексу для серверной команды.
local function findStation(args)
    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square or args.index < 0 or args.index >= square:getObjects():size() then
        return nil
    end

    local object = square:getObjects():get(args.index)
    if AlembicDistilling.isStationaryDistillery(object) then
        return object
    end
    return nil
end

--- Принимает подтверждённое клиентом завершение перегонки и повторно проверяет данные на сервере.
local function onClientCommand(module, command, character, args)
    if module ~= "AlembicDistilling" or command ~= "distillStation" or not character then
        return
    end

    local station = findStation(args)
    local receiver = character:getInventory():getItemWithID(args.receiverId)
    if not station or not receiver then
        return
    end

    local distanceX = character:getX() - (station:getX() + 0.5)
    local distanceY = character:getY() - (station:getY() + 0.5)
    if character:getZ() ~= station:getZ() or distanceX * distanceX + distanceY * distanceY > 9 then
        return
    end

    AlembicDistilling.processStationaryDistillation(character, station, receiver)
end

Events.OnClientCommand.Add(onClientCommand)