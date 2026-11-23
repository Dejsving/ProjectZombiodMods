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
local cookingXpPerLitre = 2
local alembicType = "AlembicDistilling.Alembic_Portable"

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
    local alcoholStrength = sourceFluid:getProperties():getAlcohol()
    local efficiency = getDistillationEfficiency(character)
    local vodkaAmount = sourceAmount * alcoholStrength * efficiency / targetAlcohol

    container:Empty()
    container:addFluid(Fluid.Get("Vodka"), vodkaAmount)
    alembic:sendSyncEntity(nil)
    addXp(character, Perks.Cooking, getCookingXp(sourceAmount))
end