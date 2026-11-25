local DebugMenu = {}

DebugMenu.GIFTS = {
    Firewood = {
        label = "ContextMenu_AlembicDistilling_Debug_Firewood",
        items = {
            { fullType = "Base.Firewood", count = 10 },
        },
    },
    Lighter = {
        label = "ContextMenu_AlembicDistilling_Debug_Lighter",
        items = {
            { fullType = "Base.Lighter", count = 1 },
        },
    },
    Splinters = {
        label = "ContextMenu_AlembicDistilling_Debug_Splinters",
        items = {
            { fullType = "Base.Splinters", count = 1 },
        },
    },
    PortableKit = {
        label = "ContextMenu_AlembicDistilling_Debug_PortableKit",
        items = {
            { fullType = "Base.Kettle", count = 1 },
            { fullType = "Base.RubberHose", count = 1 },
            { fullType = "Base.MetalPipe", count = 1 },
            { fullType = "Base.Funnel", count = 1 },
            { fullType = "Base.Pliers", count = 1 },
            { fullType = "Base.Screwdriver", count = 1 },
        },
    },
    StationaryKit = {
        label = "ContextMenu_AlembicDistilling_Debug_StationaryKit",
        items = {
            { fullType = "Base.BucketEmpty", count = 1 },
            { fullType = "Base.SmallCopperSheet", count = 4 },
            { fullType = "Base.MetalPipe", count = 2 },
            { fullType = "Base.BlowTorch", count = 1 },
            { fullType = "Base.WeldingRods", count = 1 },
            { fullType = "Base.WeldingMask", count = 1 },
        },
    },
    Hammer = {
        label = "ContextMenu_AlembicDistilling_Debug_Hammer",
        items = {
            { fullType = "Base.Hammer", count = 1 },
        },
    },
    Buckets = {
        label = "ContextMenu_AlembicDistilling_Debug_Buckets",
        items = {
            { fullType = "Base.BucketEmpty", count = 3 },
        },
    },
}

--- Выдаёт перечисленные предметы персонажу в одиночной игре или через серверную команду администратора.
local function giveItems(player, items)
    for _, entry in ipairs(items) do
        if isClient() then
            SendCommandToServer(
                '/additem "' .. player:getUsername() .. '" "' .. entry.fullType .. '" ' .. entry.count
            )
        else
            for _ = 1, entry.count do
                player:getInventory():AddItem(entry.fullType)
            end
        end
    end
end

--- Объединяет все отдельные наборы в один набор без дублирования одинаковых предметов.
local function getTestKit()
    local itemCounts = {}
    local itemOrder = {}

    for _, giftName in ipairs({
        "Firewood",
        "Lighter",
        "Splinters",
        "PortableKit",
        "StationaryKit",
        "Hammer",
        "Buckets",
    }) do
        for _, entry in ipairs(DebugMenu.GIFTS[giftName].items) do
            if not itemCounts[entry.fullType] then
                itemCounts[entry.fullType] = 0
                itemOrder[#itemOrder + 1] = entry.fullType
            end
            itemCounts[entry.fullType] = itemCounts[entry.fullType] + entry.count
        end
    end

    local kit = {}
    for _, fullType in ipairs(itemOrder) do
        kit[#kit + 1] = {
            fullType = fullType,
            count = itemCounts[fullType],
        }
    end
    return kit
end

--- Создаёт видимое только в debug-режиме меню выдачи тестовых материалов мода.
function DebugMenu.fill(playerNumber, context, worldObjects, test)
    if test or not isDebugEnabled() then
        return
    end

    local player = getSpecificPlayer(playerNumber)
    if not player then
        return
    end

    local root = context:addOption(getText("ContextMenu_AlembicDistilling_Debug"))
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    menu:addOption(
        getText("ContextMenu_AlembicDistilling_Debug_TestKit"),
        player,
        giveItems,
        getTestKit()
    )

    for _, giftName in ipairs({
        "Firewood",
        "Lighter",
        "Splinters",
        "PortableKit",
        "StationaryKit",
        "Hammer",
        "Buckets",
    }) do
        local gift = DebugMenu.GIFTS[giftName]
        menu:addOption(getText(gift.label), player, giveItems, gift.items)
    end
end

Events.OnFillWorldObjectContextMenu.Add(DebugMenu.fill)

return DebugMenu
