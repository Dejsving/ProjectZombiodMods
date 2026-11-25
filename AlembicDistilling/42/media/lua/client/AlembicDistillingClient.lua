require "TimedActions/ISBaseTimedAction"

--- Восстанавливает повреждённый прежний визуал зарегистрированным мировым спрайтом.
local function repairStationSprite(object)
    if not object then
        return
    end

    object = object:getMasterObject()
    if not AlembicDistilling.isStationaryDistillery(object) then
        return
    end

    local sprite = object:getSprite()
    local spriteName = sprite and sprite:getName()
    if not spriteName then
        object:setSprite(getSprite("alembic_tier3_0"))
    end

    object:setName(getText("IGUI_AlembicDistilling_StationaryName"))
end

--- Подготавливает куб до штатного Java-кода построения меню жидкости.
local function onPreFillWorldObjectContextMenu(playerNumber, context, worldObjects)
    for _, object in ipairs(worldObjects) do
        repairStationSprite(object)
        local master = object:getMasterObject()
        if AlembicDistilling.isStationaryDistillery(master) then
            context.dontShowLiquidOption = true
        end
    end
end

--- Восстанавливает повреждённый куб после его появления в мире.
local function onObjectAdded(object)
    repairStationSprite(object)
end

--- Проверяет рядом с персонажем старые объекты, сохранённые с пустым именем спрайта.
local function onPlayerMove(player)
    local currentSquare = player:getCurrentSquare()
    if not currentSquare then
        return
    end

    for offsetY = -1, 1 do
        for offsetX = -1, 1 do
            local square = getCell():getGridSquare(
                currentSquare:getX() + offsetX,
                currentSquare:getY() + offsetY,
                currentSquare:getZ()
            )
            if square then
                local objects = square:getObjects()
                for index = 0, objects:size() - 1 do
                    repairStationSprite(objects:get(index))
                end
            end
        end
    end
end

--- Возвращает стационарный перегонный аппарат среди выбранных мировых объектов.
local function getStation(worldObjects)
    for _, object in ipairs(worldObjects) do
        object = object:getMasterObject()
        if AlembicDistilling.isStationaryDistillery(object) then
            return object
        end
    end
    return nil
end

--- Собирает подходящие приёмники дистиллята из всего инвентаря персонажа.
local function getReceivers(character, vodkaAmount)
    return character:getInventory():getAllEvalRecurse(function(item)
        return AlembicDistilling.isValidReceiver(item, vodkaAmount)
    end, ArrayList.new())
end

--- Создаёт контролируемое сервером действие перегонки в стационарном кубе.
local stationaryDistillAction = ISBaseTimedAction:derive("ISAlembicDistillation")

--- Проверяет сохранность куба, нагрева, сырья и приёмника во время действия.
function stationaryDistillAction:isValid()
    if self.station:getObjectIndex() == -1 or not self.station:isLit() then
        return false
    end

    if isClient() then
        self.receiver = self.character:getInventory():getItemWithID(self.receiverId)
    end

    local amount = AlembicDistilling.getVodkaAmount(self.station:getFluidContainer(), self.character)
    return amount > 0
        and self.receiver ~= nil
        and AlembicDistilling.isValidReceiver(self.receiver, amount)
end

--- Разворачивает персонажа к аппарату перед началом перегонки.
function stationaryDistillAction:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

--- Поддерживает анимацию и индикатор прогресса на выбранном приёмнике.
function stationaryDistillAction:update()
    self.character:faceThisObject(self.station)
    self.receiver:setJobDelta(self:getJobDelta())
end

--- Запускает визуальное действие персонажа у топки стационарного куба.
function stationaryDistillAction:start()
    self.receiver:setJobType(getText("IGUI_AlembicDistilling_Distilling"))
    self.receiver:setJobDelta(0)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

--- Сбрасывает индикатор прогресса при отмене действия.
function stationaryDistillAction:stop()
    self.receiver:setJobDelta(0)
    ISBaseTimedAction.stop(self)
end

--- Передаёт завершение перегонки серверу либо выполняет его в одиночной игре.
function stationaryDistillAction:perform()
    self.receiver:setJobDelta(0)
    if isClient() then
        sendClientCommandV(
            self.character,
            "AlembicDistilling",
            "distillStation",
            "x", self.station:getX(),
            "y", self.station:getY(),
            "z", self.station:getZ(),
            "index", self.station:getObjectIndex(),
            "receiverId", self.receiverId
        )
    else
        AlembicDistilling.processStationaryDistillation(self.character, self.station, self.receiver)
    end
    ISBaseTimedAction.perform(self)
end

--- Создаёт действие перегонки для стационарного аппарата и выбранного приёмника.
function stationaryDistillAction:new(character, station, receiver)
    local action = ISBaseTimedAction.new(self, character)
    action.station = station
    action.receiver = receiver
    action.receiverId = receiver:getID()
    action.maxTime = character:isTimedActionInstant() and 1 or 600
    return action
end

--- Запускает действие перегонки, предварительно подойдя вплотную к стационарному кубу.
local function startDistillation(worldObjects, playerNumber, station, receiver)
    local character = getSpecificPlayer(playerNumber)
    if not luautils.walkAdjObject(character, station, true) then
        return
    end

    ISTimedActionQueue.add(stationaryDistillAction:new(character, station, receiver))
end

--- Добавляет интерфейс жидкости и запуска перегонки в контекстное меню стационарного куба.
--- Удаляет ванильные отдельные меню печи и жидкости для этого стационарного аппарата.
local function removeDefaultStationMenus(context, station)
    local duplicateNames = {
        station:getTileName(),
        station:getName(),
        station:getFluidUiName(),
        ISWorldObjectContextMenu.getMoveableDisplayName(station),
    }

    for _, duplicateName in ipairs(duplicateNames) do
        if duplicateName then
            context:removeOptionByName(duplicateName)
        end
    end
end

--- Добавляет в подменю топлива штатные действия загрузки, розжига и тушения.
local function addFuelMenu(menu, worldObjects, playerNumber, station)
    local character = getSpecificPlayer(playerNumber)
    local fuelOption = menu:addOption(getText("IGUI_AlembicDistilling_Fuel"))
    local fuelMenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(fuelOption, fuelMenu)

    local fireState
    if station:isLit() then
        fireState = getText("IGUI_Fireplace_Burning")
    elseif station:isSmouldering() then
        fireState = getText("IGUI_Fireplace_Smouldering")
    else
        fireState = getText("IGUI_Fireplace_Unlit")
    end

    local fuelAmount = getText(
        "IGUI_AlembicDistilling_FuelAmount",
        ISCampingMenu.timeString(station:getFuelAmount()),
        fireState
    )
    fuelMenu:addOption(fuelAmount, worldObjects, ISBBQMenu.onDisplayInfo, playerNumber, station)

    local fuelInfo = ISCampingMenu.getNearbyFuelInfo(character)
    ISCampingMenu.doAddFuelOption(
        fuelMenu,
        worldObjects,
        station:getFuelAmount(),
        fuelInfo,
        station,
        ISBBQAddFuel
    )

    if station:isLit() then
        fuelMenu:addOption(
            campingText.putOutCampfire,
            worldObjects,
            ISBBQMenu.onExtinguish,
            playerNumber,
            station
        )
    else
        ISCampingMenu.doLightFireOption(
            character,
            fuelMenu,
            worldObjects,
            station:hasFuel(),
            fuelInfo,
            station,
            ISBBQLightFromPetrol,
            ISBBQLightFromLiterature,
            ISBBQLightFromKindle
        )
    end
end

--- Добавляет жидкости из инвентаря в открытый резервуар стационарного аппарата.
local function addFluidFromItemOption(menu, worldObjects, character, station)
    local option = menu:addOption(getText("ContextMenu_AddFluidFromItem"))
    local sourceMenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(option, sourceMenu)
    local sources = character:getInventory():getAllEvalRecurse(function(item)
        local container = item:getFluidContainer()
        return container
            and item:canStoreWater()
            and station:canTransferFluidFrom(container)
            and container:canPlayerEmpty()
            and not container:isEmpty()
    end, ArrayList.new())

    if sources:size() == 0 then
        option.notAvailable = true
        return
    end

    for index = 0, sources:size() - 1 do
        local source = sources:get(index)
        sourceMenu:addOption(
            source:getName(),
            worldObjects,
            ISWorldObjectContextMenu.onAddFluidFromItem,
            station,
            source,
            character
        )
    end
end

--- Добавляет debug-выбор жидкости для тестирования резервуара аппарата.
local function addDebugFluidOption(menu, station)
    if not getDebug() then
        return
    end

    local option = menu:addDebugOption(getText("ContextMenu_AddFluid"))
    local fluidMenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(option, fluidMenu)
    local fluidNames = FluidType.getAllFluidName()
    local container = station:getFluidContainer()
    for index = 0, fluidNames:size() - 1 do
        fluidMenu:addOption(
            fluidNames:get(index),
            container,
            ISFluidContainerMenu.addDebugFluid,
            fluidNames:get(index),
            nil
        )
    end
end

--- Собирает единое меню топлива, жидкости и перегонки стационарного аппарата.
local function fillStationContextMenu(playerNumber, context, worldObjects)
    local station = getStation(worldObjects)
    if not station then
        return
    end

    local character = getSpecificPlayer(playerNumber)
    local fluidContainer = station:getFluidContainer()
    removeDefaultStationMenus(context, station)
    local rootOption = context:addOption(getText("IGUI_AlembicDistilling_StationaryName"))
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(rootOption, menu)

    addFuelMenu(menu, worldObjects, playerNumber, station)

    local liquidOption = menu:addOption(getText("ContextMenu_AlembicDistilling_Liquid"))
    local liquidMenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(liquidOption, liquidMenu)
    liquidMenu:addOption(getText("Fluid_Show_Info"), playerNumber, ISWorldObjectContextMenu.onFluidInfo, fluidContainer)
    liquidMenu:addOption(getText("Fluid_Transfer_Fluids"), playerNumber, ISWorldObjectContextMenu.onFluidTransfer, fluidContainer)
    addDebugFluidOption(liquidMenu, station)
    addFluidFromItemOption(liquidMenu, worldObjects, character, station)

    local vodkaAmount = AlembicDistilling.getVodkaAmount(fluidContainer, character)
    local receivers = getReceivers(character, vodkaAmount)
    local distillOption = menu:addOption(getText("IGUI_AlembicDistilling_Start"))
    local ready = AlembicDistilling.canStartStationaryDistillation(station, character)
        and receivers:size() > 0

    if not ready then
        distillOption.notAvailable = true
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText("IGUI_AlembicDistilling_StationaryRequirements")
        distillOption.toolTip = tooltip
        return
    end

    local receiverMenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(distillOption, receiverMenu)
    for index = 0, receivers:size() - 1 do
        local receiver = receivers:get(index)
        local freeAmount = FluidUtil.getAmountFormatted(receiver:getFluidContainer():getFreeCapacity())
        local label = receiver:getDisplayName() .. " (" .. freeAmount .. ")"
        receiverMenu:addOption(label, worldObjects, startDistillation, playerNumber, station, receiver)
    end
end

Events.OnObjectAdded.Add(onObjectAdded)
Events.OnPlayerMove.Add(onPlayerMove)
Events.OnPreFillWorldObjectContextMenu.Add(onPreFillWorldObjectContextMenu)
Events.OnFillWorldObjectContextMenu.Add(fillStationContextMenu)