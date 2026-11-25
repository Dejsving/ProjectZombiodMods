local allowedAlcohol = {
    Beer = true,
    Brandy = true,
    Champagne = true,
    Cider = true,
    CoffeeLiqueur = true,
    Curacao = true,
    Gin = true,
    Mead = true,
    Port = true,
    Rum = true,
    Scotch = true,
    Sherry = true,
    Tequila = true,
    Vermouth = true,
    Vodka = true,
    Whiskey = true,
    Wine = true,
}

local baseEfficiency = 0.70
local targetAlcohol = 0.40
local minimumHeat = 1.6
local minimumBatchAmount = 0.1
local minimumStationFuel = 30
local cookingXpPerLitre = 2
local alembicType = "AlembicDistilling.Alembic_Portable"
local stationarySprites = {
    alembic_tier3_0 = true,
    alembic_tier3_1 = true,
    alembic_tier3_2 = true,
    alembic_tier3_3 = true,
}

AlembicDistilling = AlembicDistilling or {}

--- Возвращает пригодность перегоняемой жидкости по типу и чистоте.
local function getAllowedFluid(container)
    if not container or container:isEmpty() or not container:isPureFluid(container:getPrimaryFluid()) then
        return nil
    end

    local fluid = container:getPrimaryFluid()
    if not fluid or not allowedAlcohol[fluid:getFluidTypeString()] then
        return nil
    end

    return fluid
end

--- Возвращает true, если объём жидкости достаточен для перегонки.
local function hasMinimumBatchAmount(container)
    return container and container:getAmount() >= minimumBatchAmount
end

--- Рассчитывает коэффициент перегонки по уровню навыка Cooking персонажа.
local function getDistillationEfficiency(character)
    if not character then
        return baseEfficiency
    end

    local cookingLevel = math.max(0, math.min(10, character:getPerkLevel(Perks.Cooking)))
    return baseEfficiency + cookingLevel / 100
end

--- Рассчитывает награду Cooking за объём сырья с округлением до двух знаков.
local function getCookingXp(sourceAmount)
    return math.floor(sourceAmount * cookingXpPerLitre * 100 + 0.5) / 100
end

--- Рассчитывает выход водки 40% из содержимого перегонного аппарата.
function AlembicDistilling.getVodkaAmount(container, character)
    local fluid = getAllowedFluid(container)
    if not fluid or not hasMinimumBatchAmount(container) then
        return 0
    end

    local alcoholStrength = fluid:getProperties():getAlcohol()
    return container:getAmount() * alcoholStrength * getDistillationEfficiency(character) / targetAlcohol
end

--- Возвращает true, если контейнер установленного предмета принадлежит стационарному кубу.
function AlembicDistilling.isStationaryDistillery(object)
    if not object or not instanceof(object, "IsoFireplace") then
        return false
    end

    local fluidContainer = object:getFluidContainer()
    local sprite = object:getSprite()
    return fluidContainer ~= nil
        and math.abs(fluidContainer:getCapacity() - 10) < 0.001
        and (
            object:getModData().alembicDistillingStation == true
            or sprite ~= nil and stationarySprites[sprite:getName()] == true
        )
end

--- Возвращает true, если предмет подходит для приёма рассчитанного объёма водки.
function AlembicDistilling.isValidReceiver(item, vodkaAmount)
    local container = item and item:getFluidContainer()
    if not container or container:getFreeCapacity() + 0.0001 < vodkaAmount then
        return false
    end

    if container:isEmpty() then
        return true
    end

    local primaryFluid = container:getPrimaryFluid()
    return container:isPureFluid(primaryFluid)
        and primaryFluid:getFluidTypeString() == "Vodka"
end

--- Проверяет готовность стационарного куба, топлива и сырья к перегонке.
function AlembicDistilling.canStartStationaryDistillation(object, character)
    if not AlembicDistilling.isStationaryDistillery(object)
            or not object:isLit()
            or object:getFuelAmount() < minimumStationFuel then
        return false
    end

    local container = object:getFluidContainer()
    return hasMinimumBatchAmount(container)
        and getAllowedFluid(container) ~= nil
        and AlembicDistilling.getVodkaAmount(container, character) > 0
end

--- Выполняет перегонку из стационарного куба в выбранный контейнер.
function AlembicDistilling.processStationaryDistillation(character, object, receiver)
    if not character or not AlembicDistilling.canStartStationaryDistillation(object, character) then
        return false
    end

    local sourceContainer = object:getFluidContainer()
    local sourceAmount = sourceContainer:getAmount()
    local vodkaAmount = AlembicDistilling.getVodkaAmount(sourceContainer, character)
    if not AlembicDistilling.isValidReceiver(receiver, vodkaAmount) then
        return false
    end

    sourceContainer:Empty()
    receiver:getFluidContainer():addFluid(Fluid.Get("Vodka"), vodkaAmount)
    object:sync()
    receiver:syncItemFields()
    addXp(character, Perks.Cooking, getCookingXp(sourceAmount))
    return true
end

--- Проверяет, можно ли перегнать содержимое выбранного нагретого аламбика.
function RecipeCodeOnTest.alembicDistill(item, character)
    if not item or item:getFullType() ~= alembicType then
        return true
    end

    local container = item:getFluidContainer()
    return item:getItemHeat() > minimumHeat
        and hasMinimumBatchAmount(container)
        and getAllowedFluid(container) ~= nil
end

--- Заменяет содержимое аламбика водкой 40% и начисляет XP Cooking за объём сырья.
function RecipeCodeOnCreate.alembicDistill(recipeData, character)
    local items = recipeData:getAllKeepInputItems()
    if not items or items:size() == 0 then
        return
    end

    local alembic = items:get(0)
    if not alembic or alembic:getFullType() ~= alembicType then
        return
    end

    local container = alembic:getFluidContainer()
    local sourceFluid = getAllowedFluid(container)
    if not sourceFluid or not hasMinimumBatchAmount(container) then
        return
    end

    local sourceAmount = container:getAmount()
    local vodkaAmount = AlembicDistilling.getVodkaAmount(container, character)

    container:Empty()
    container:addFluid(Fluid.Get("Vodka"), vodkaAmount)
    alembic:sendSyncEntity(nil)
    addXp(character, Perks.Cooking, getCookingXp(sourceAmount))
end