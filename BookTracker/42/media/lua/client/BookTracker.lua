-- BookTracker

local PREFIX = "[!!] "   -- BookTracker

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

local function isTracked(item)
    if not item or not instanceof(item, "Literature") then return false end
    -- book on a skill
    if item.getSkillTrained then
        local skill = item:getSkillTrained()
        if skill and skill ~= "" then return true end
    end
    -- magazine with recipes (method name differs between builds, so check which one exists)
    if item.getLearnedRecipes and listSize(item:getLearnedRecipes()) > 0 then return true end
    if item.getTeachedRecipes and listSize(item:getTeachedRecipes()) > 0 then return true end
    return false
end

local function getData(playerObj)
    local md = playerObj:getModData()
    md.BT_owned = md.BT_owned or {}
    return md
end

local function refreshUI(playerNum)
    pcall(function() getPlayerInventory(playerNum):refreshBackpacks() end)
    pcall(function() getPlayerLoot(playerNum):refreshBackpacks() end)
end

-- BookTracker
local function scanContainer(playerObj, playerNum, container)
    local md = getData(playerObj)
    local items = container:getItems()
    local added = 0
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if isTracked(it) and not md.BT_owned[it:getFullType()] then
            md.BT_owned[it:getFullType()] = true
            added = added + 1
        end
    end
    md.BT_init = true
    local total = 0
    for _ in pairs(md.BT_owned) do total = total + 1 end
    playerObj:Say(tr("IGUI_BT_Learned", "Remembered new: %1 (total %2)", added, total))
    refreshUI(playerNum)
end

local function resetList(playerObj, playerNum)
    local md = getData(playerObj)
    md.BT_owned = {}
    md.BT_init = false
    playerObj:Say(tr("IGUI_BT_Reset", "Book list reset"))
    refreshUI(playerNum)
end

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldObjects)
    local playerObj = getSpecificPlayer(playerNum)
    for _, obj in ipairs(worldObjects) do
        if obj.getContainerCount and obj:getContainerCount() > 0 then
            for i = 0, obj:getContainerCount() - 1 do
                local c = obj:getContainerByIndex(i)
                context:addOption(tr("ContextMenu_BT_Scan", "Remember books/magazines"), playerObj, scanContainer, playerNum, c)
            end
            context:addOption(tr("ContextMenu_BT_Reset", "Reset book list"), playerObj, resetList, playerNum)
            break
        end
    end
end)

-- BookTracker
local function updateMarks(pane)
    local inv = pane.inventory
    if not inv then return end
    local playerObj = getSpecificPlayer(pane.player)
    if not playerObj then return end
    local md = getData(playerObj)
    if not md.BT_init then return end  -- BookTracker

    local own = false
    pcall(function() own = inv:isInCharacterInventory(playerObj) end)

    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if isTracked(it) then
            local name = it:getName()
            local marked = string.sub(name, 1, #PREFIX) == PREFIX
            local need = (not own) and (not md.BT_owned[it:getFullType()])
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
