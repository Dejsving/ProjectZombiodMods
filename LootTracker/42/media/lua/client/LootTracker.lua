-- Loot Tracker

local PREFIX = "[!!] "
local TOOL_CATEGORIES = {
    Tool = true,
    ToolWeapon = true,
    VehicleMaintenance = true,
    VehicleMaintenanceWeapon = true,
}

-- getText with English fallback (shows text even if translation files are not picked up)
local function tr(key, fallback, a, b)
    local s = getText(key, a, b)
    if s == nil or s == key then
        s = fallback
        if a ~= nil then s = string.gsub(s, "%%1", tostring(a)) end
        if b ~= nil then s = string.gsub(s, "%%2", tostring(b)) end
    end
    return s
end

local function listSize(list)
    if not list then return 0 end
    local n = 0
    pcall(function() n = list:size() end)
    return n
end

-- Возвращает название списка, в который следует сохранить предмет.
local function getTrackingCategory(item)
    if not item then return nil end
    if item.isRecordedMedia and item:isRecordedMedia() then return "media" end

    if instanceof(item, "Literature") then
        local itemType = item:getType()
        if itemType == "Book" or itemType == "Paperback"
            or string.sub(itemType, 1, 5) == "Book_"
            or string.sub(itemType, 1, 10) == "Paperback_" then
            return "literature"
        end

        if item.getSkillTrained then
            local skill = item:getSkillTrained()
            if skill and skill ~= "" then return "literature" end
        end
        if item.getLearnedRecipes and listSize(item:getLearnedRecipes()) > 0 then return "literature" end
        if item.getTeachedRecipes and listSize(item:getTeachedRecipes()) > 0 then return "literature" end
    end

    if item.getDisplayCategory and TOOL_CATEGORIES[item:getDisplayCategory()] then return "tools" end
    return nil
end

-- Возвращает ключ предмета, отдельно учитывая каждую запись на VHS и CD.
local function getTrackingKey(item)
    local fullType = item:getFullType()
    if not item.isRecordedMedia or not item:isRecordedMedia() then return fullType end

    local mediaData = item:getMediaData()
    if not mediaData then return fullType end
    if mediaData.getId then
        local mediaId = mediaData:getId()
        if mediaId ~= nil then return fullType .. ":" .. tostring(mediaId) end
    end

    return fullType .. ":" .. tostring(mediaData:getTitleEN() or "")
        .. ":" .. tostring(mediaData:getSubtitleEN() or "")
        .. ":" .. tostring(mediaData:getAuthorEN() or "")
end

local function getData(playerObj)
    local md = playerObj:getModData()
    if not md.LT_owned then
        local owned = {
            literature = {},
            media = {},
            tools = {},
        }
        for key, value in pairs(md.BT_owned or {}) do
            if type(key) == "string" and value then
                local fullType = string.match(key, "^([^:]+)")
                local category = "literature"
                if string.find(key, ":", 1, true)
                    or fullType == "Base.Disc_Retail"
                    or fullType == "Base.VHS_Retail"
                    or fullType == "Base.VHS_Home" then
                    category = "media"
                end
                owned[category][key] = true
            end
        end
        md.LT_owned = owned
        md.LT_init = md.BT_init == true
        md.BT_owned = nil
        md.BT_init = nil
    else
        md.LT_owned.literature = md.LT_owned.literature or {}
        md.LT_owned.media = md.LT_owned.media or {}
        md.LT_owned.tools = md.LT_owned.tools or {}
        if md.LT_init == nil then md.LT_init = md.BT_init == true end
    end
    return md
end

local function refreshUI(playerNum)
    pcall(function() getPlayerInventory(playerNum):refreshBackpacks() end)
    pcall(function() getPlayerLoot(playerNum):refreshBackpacks() end)
end

-- Loot Tracker
local function scanContainer(playerObj, playerNum, container)
    local md = getData(playerObj)
    local items = container:getItems()
    local added = 0
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local category = getTrackingCategory(it)
        if category then
            local worn = false
            if category == "tools" and it.getCondition and it.getConditionMax then
                local conditionMax = it:getConditionMax()
                -- Изношенный инструмент не считаем запасом: он остается помеченным как нужный.
                worn = conditionMax > 0 and it:getCondition() < conditionMax
            end
            local key = getTrackingKey(it)
            if not worn and not md.LT_owned[category][key] then
                md.LT_owned[category][key] = true
                added = added + 1
            end
        end
    end
    md.LT_init = true
    local total = 0
    for _, list in pairs(md.LT_owned) do
        for _ in pairs(list) do total = total + 1 end
    end
    playerObj:Say(tr("IGUI_BT_Learned", "Remembered new: %1 (total %2)", added, total))
    refreshUI(playerNum)
end

local function resetList(playerObj, playerNum)
    local md = getData(playerObj)
    md.LT_owned = {
        literature = {},
        media = {},
        tools = {},
    }
    md.LT_init = false
    playerObj:Say(tr("IGUI_BT_Reset", "Tracked item list reset"))
    refreshUI(playerNum)
end

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldObjects)
    local playerObj = getSpecificPlayer(playerNum)
    for _, obj in ipairs(worldObjects) do
        if obj.getContainerCount and obj:getContainerCount() > 0 then
            for i = 0, obj:getContainerCount() - 1 do
                local c = obj:getContainerByIndex(i)
                context:addOption(tr("ContextMenu_BT_Scan", "Remember literature, media and tools"), playerObj, scanContainer, playerNum, c)
            end
            context:addOption(tr("ContextMenu_BT_Reset", "Reset tracked items"), playerObj, resetList, playerNum)
            break
        end
    end
end)

-- Loot Tracker
local function updateMarks(pane)
    local inv = pane.inventory
    if not inv then return end
    local playerObj = getSpecificPlayer(pane.player)
    if not playerObj then return end
    local md = getData(playerObj)
    if not md.LT_init then return end

    local own = false
    pcall(function() own = inv:isInCharacterInventory(playerObj) end)

    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local category = getTrackingCategory(it)
        if category then
            local name = it:getName()
            local marked = string.sub(name, 1, #PREFIX) == PREFIX
            local need = (not own) and (not md.LT_owned[category][getTrackingKey(it)])
            if need and not marked then
                it:setName(PREFIX .. name)
                pcall(function() it:setCustomName(true) end)
            elseif marked and not need then
                it:setName(string.sub(name, #PREFIX + 1))
            end
        end
    end
end

local function hook()
    if not ISInventoryPane or ISInventoryPane.BT_hooked then return end
    ISInventoryPane.BT_hooked = true
    local orig = ISInventoryPane.refreshContainer
    function ISInventoryPane:refreshContainer()
        pcall(updateMarks, self)
        return orig(self)
    end
end

Events.OnGameStart.Add(hook)
