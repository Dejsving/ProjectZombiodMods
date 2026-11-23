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

local efficiency = 0.75
local targetAlcohol = 0.40
local minimumHeat = 1.6
local alembicType = "AlembicDistilling.Alembic_CopperPortable"

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

--- Проверяет, можно ли перегнать содержимое выбранного нагретого аламбика.
function RecipeCodeOnTest.alembicDistill(item, character)
    if not item or item:getFullType() ~= alembicType then
        return true
    end

    return item:getItemHeat() > minimumHeat and getAllowedFluid(item:getFluidContainer()) ~= nil
end

--- Заменяет содержимое аламбика рассчитанным объёмом водки крепостью 40%.
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
    if not sourceFluid then
        return
    end

    local sourceAmount = container:getAmount()
    local alcoholStrength = sourceFluid:getProperties():getAlcohol()
    local vodkaAmount = sourceAmount * alcoholStrength * efficiency / targetAlcohol

    container:Empty()
    container:addFluid(Fluid.Get("Vodka"), vodkaAmount)
    alembic:sendSyncEntity(nil)
end