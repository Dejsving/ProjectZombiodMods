require "ISUI/ISInventoryPaneContextMenu"
require "TimedActions/ISEjectMagazine"
require "TimedActions/ISLoadBulletsInMagazine"
require "TimedActions/ISReloadWeaponAction"
require "TimedActions/ISRackFirearm"
require "TimedActions/ISUnloadBulletsFromFirearm"
require "TimedActions/ISUnloadBulletsFromMagazine"

local active = false
local selected = nil
local pending = nil
local nextUpdate = 0
local UPDATE_INTERVAL = 500

-- Возвращает перевод или английский текст, если перевод недоступен.
local function tr(key, fallback, ...)
    local text = getText(key, ...)
    if not text or text == key then
        return string.format(fallback, ...)
    end
    return text
end

-- Останавливает автоматизацию и сообщает причину игроку.
local function stop(player, key, fallback)
    active = false
    selected = nil
    pending = nil
    player:Say(tr(key, fallback))
    print("[AutoReloadXP] " .. tr(key, fallback))
end

-- Отбирает оружие, магазины и отдельные патроны во вложенных контейнерах.
local function isReloadItem(item)
    return (instanceof(item, "HandWeapon") and item:isRanged())
        or item:hasTag(ItemTag.AMMO)
        or (not instanceof(item, "HandWeapon") and item:getAmmoType() ~= nil and item:getMaxAmmo() > 0)
end

-- Учитывает патрон в патроннике только тогда, когда его можно извлечь.
local function chamberedRound(gun)
    return gun:haveChamber() and gun:isRoundChambered()
end

-- Собирает предметы и подсчитывает отдельные патроны по полному типу.
local function collectInventoryData(player)
    local items = player:getInventory():getAllEvalRecurse(isReloadItem)
    local weapons, magazines, ammo = {}, {}, {}
    local ammoTypes = 0
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if instanceof(item, "HandWeapon") and item:isRanged() then
            table.insert(weapons, item)
        elseif item:getAmmoType() and item:getMaxAmmo() > 0 then
            table.insert(magazines, item)
        elseif item:hasTag(ItemTag.AMMO) then
            local itemType = item:getFullType()
            if not ammo[itemType] then
                ammo[itemType] = 0
                ammoTypes = ammoTypes + 1
            end
            ammo[itemType] = ammo[itemType] + 1
        end
    end
    print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogCounts", "weapons: %d, magazines: %d, ammo types: %d",
        #weapons, #magazines, ammoTypes))
    return weapons, magazines
end

-- Проверяет магазин и обновляет лучший комплект по вместимости.
local function considerMagazine(best, gun, magazine, ammoKey, loose, eject, existing)
    local name = magazine:getDisplayName()
    local ammoType = magazine:getAmmoType()
    local capacity = magazine:getMaxAmmo()
    if magazine:getCondition() <= 0 then
        print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogMagazineDamaged", "Excluded magazine %s: damaged", name))
    elseif not ammoType or ammoType:getItemKey() ~= ammoKey then
        print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogMagazineAmmo", "Excluded magazine %s: incompatible ammo", name))
    elseif capacity <= 0 then
        print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogMagazineCapacity", "Excluded magazine %s: zero capacity", name))
    elseif not best or capacity > best.capacity or (capacity == best.capacity and loose > best.loose) then
        if eject then magazine = nil end
        return { gun = gun, magazine = magazine, capacity = capacity,
            ammoKey = ammoKey, loose = loose, eject = eject, existing = existing,
            magazineName = name }
    end
    return best
end

-- Выбирает пригодную связку с наибольшей вместимостью.
local function findBest(player)
    local inventory = player:getInventory()
    local weapons, magazines = collectInventoryData(player)
    local best = nil
    for _, gun in ipairs(weapons) do
        local name = gun:getDisplayName()
        local magazineType = gun:getMagazineType()
        if magazineType == "" then magazineType = nil end
        local ammoType = gun:getAmmoType()
        local ammoKey = ammoType and ammoType:getItemKey()
        local loose = ammoKey and inventory:getItemCountRecurse(ammoKey) or 0
        local capacity = gun:getMaxAmmo()
        if magazineType then
            print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogDetachable", "%s: detachable magazine, capacity determined by magazine", name))
        else
            print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogInternal", "%s: internal magazine, capacity: %d", name, capacity))
        end
        if gun:getCondition() <= 0 then
            print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogWeaponBroken", "Excluded %s: broken", name))
        elseif gun:isJammed() then
            print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogWeaponJammed", "Excluded %s: jammed", name))
        elseif not ammoKey then
            print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogWeaponUnknownAmmo", "Excluded %s: unknown ammo type", name))
        elseif loose <= 0 then
            print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogWeaponNoAmmo", "Excluded %s: no loose ammo %s", name, tostring(ammoKey)))
        elseif not magazineType then
            if capacity <= 0 then
                print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogWeaponCapacity", "Excluded %s: zero capacity", name))
            elseif not best or capacity > best.capacity or (capacity == best.capacity and loose > best.loose) then
                best = { gun = gun, capacity = capacity, ammoKey = ammoKey, loose = loose }
            end
        else
            local found = false
            local existing = {}
            for _, magazine in ipairs(magazines) do
                if magazine:getFullType() == magazineType then
                    found = true
                    existing[magazine:getID()] = true
                    print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogMagazine", "%s: magazine %s, capacity: %d",
                        name, magazine:getDisplayName(), magazine:getMaxAmmo()))
                    best = considerMagazine(best, gun, magazine, ammoKey, loose, false, nil)
                end
            end
            if gun:isContainsClip() then
                local magazine = instanceItem(magazineType)
                if magazine then
                    found = true
                    print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogInstalledMagazine", "%s: installed magazine %s, capacity: %d",
                        name, magazine:getDisplayName(), magazine:getMaxAmmo()))
                    best = considerMagazine(best, gun, magazine, ammoKey, loose, true, existing)
                else
                    print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogUnknownMagazine", "Excluded installed magazine: unknown type %s", magazineType))
                end
            end
            if not found then
                print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogNoMagazine", "Excluded %s: no compatible magazine %s", name, magazineType))
            end
        end
    end
    if best then
        print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogSelected", "selected: %s, %s, ammo %s (%d), capacity %d",
            best.gun:getDisplayName(), best.magazineName or tr("IGUI_AutoReloadXP_LogNoMagazineLabel", "no magazine"),
            tostring(best.ammoKey), best.loose, best.capacity))
    else
        print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogNoSelection", "No suitable combination found"))
    end
    return best
end

-- Запускает диагностику из игровой консоли без изменения инвентаря.
function AutoReloadDebug()
    local player = getPlayer()
    if not player then
        print("[AutoReloadXP] " .. tr("IGUI_AutoReloadXP_LogNoPlayer", "Player not found"))
        return
    end
    findBest(player)
end

-- Готовит магазин либо берёт оружие со встроенным магазином в руки.
local function prepare(player)
    local gun = selected.gun
    if selected.eject then
        -- Штатное действие игры требует оружие в основной руке.
        ISInventoryPaneContextMenu.equipWeapon(gun, true, false, player:getPlayerNum())
        ISTimedActionQueue.add(ISEjectMagazine:new(player, gun))
    elseif selected.magazine then
        ISInventoryPaneContextMenu.transferIfNeeded(player, selected.magazine)
    else
        ISInventoryPaneContextMenu.equipWeapon(gun, true, false, player:getPlayerNum())
    end
    pending = { kind = "prepare" }
end

-- Находит магазин, созданный штатным действием извлечения.
local function findEjectedMagazine(player)
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getFullType() == selected.gun:getMagazineType() and not selected.existing[item:getID()] then
            return item
        end
    end
end

-- Проверяет результат предыдущего действия и не повторяет прерванные действия.
local function finishPending(player)
    if not pending then return true end
    local gun = selected.gun
    local kind = pending.kind
    if kind == "prepare" then
        if selected.eject then
            if gun:isContainsClip() then return false end
            selected.magazine = findEjectedMagazine(player)
            if not selected.magazine then return false end
            selected.eject = false
            selected.existing = nil
        elseif not selected.magazine and player:getPrimaryHandItem() ~= gun then
            return false
        end
        if selected.magazine and not player:getInventory():contains(selected.magazine) then
            return false
        end
    else
        local item = selected.magazine or gun
        local current = item:getCurrentAmmoCount()
        if kind == "load" and current <= pending.count and chamberedRound(gun) == pending.chambered then
            return false
        elseif kind == "unload" and current >= pending.count then
            return false
        elseif kind == "rack" and chamberedRound(gun) then
            return false
        end
    end
    pending = nil
    return true
end

-- Запускает очередное штатное действие загрузки или извлечения патронов.
local function step(player)
    if ISTimedActionQueue.isPlayerDoingAction(player) then return end
    if not selected then
        selected = findBest(player)
        if not selected then
            stop(player, "IGUI_AutoReloadXP_NoSuitableWeapon", "Auto reload: no suitable weapon, magazine or ammunition")
            return
        end
        prepare(player)
        return
    end
    if not finishPending(player) then
        stop(player, "IGUI_AutoReloadXP_ActionInterrupted", "Auto reload: action interrupted or item unavailable")
        return
    end

    local gun = selected.gun
    local item = selected.magazine or gun
    local inventory = player:getInventory()
    if not inventory:containsRecursive(gun) or not inventory:contains(item)
        or (not selected.magazine and player:getPrimaryHandItem() ~= gun)
        or gun:getCondition() <= 0 or gun:isJammed() then
        stop(player, "IGUI_AutoReloadXP_ItemUnavailable", "Auto reload: weapon or magazine unavailable")
        return
    end

    local count = item:getCurrentAmmoCount()
    if count > 0 then
        pending = { kind = "unload", count = count }
        if selected.magazine then
            ISTimedActionQueue.add(ISUnloadBulletsFromMagazine:new(player, item))
        else
            ISTimedActionQueue.add(ISUnloadBulletsFromFirearm:new(player, gun))
        end
        return
    end

    local ammoType = item:getAmmoType()
    local ammoCount = inventory:getItemCountRecurse(ammoType:getItemKey())
    if ammoCount > 0 then
        local toLoad = ISInventoryPaneContextMenu.transferBullets(player, ammoType:getItemKey(), 0, item:getMaxAmmo())
        pending = { kind = "load", count = count, chambered = chamberedRound(gun) }
        if selected.magazine then
            ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(player, item, toLoad))
        else
            ISTimedActionQueue.add(ISReloadWeaponAction:new(player, gun))
        end
    elseif not selected.magazine and chamberedRound(gun) and not gun:isContainsClip() then
        pending = { kind = "rack" }
        ISTimedActionQueue.add(ISRackFirearm:new(player, gun))
    else
        stop(player, "IGUI_AutoReloadXP_NoAmmo", "Auto reload: out of ammunition")
    end
end

-- Проверяет очередь не чаще двух раз в секунду для локального игрока.
local function onPlayerUpdate(player)
    if not active or not player:isLocalPlayer() or player ~= getPlayer() then return end
    local now = getTimestampMs()
    if now < nextUpdate then return end
    nextUpdate = now + UPDATE_INTERVAL
    step(player)
end

-- Включает и выключает автоматизацию клавишей F9.
local function onKeyPressed(key)
    if key ~= Keyboard.KEY_F9 then return end
    local player = getPlayer()
    if not player then return end
    if active then
        stop(player, "IGUI_AutoReloadXP_Off", "Auto reload: OFF")
    else
        active = true
        selected = nil
        pending = nil
        nextUpdate = 0
        player:Say(tr("IGUI_AutoReloadXP_On", "Auto reload: ON"))
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnKeyPressed.Add(onKeyPressed)
