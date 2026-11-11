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
local function tr(key, fallback)
    local text = getText(key)
    if not text or text == key then
        return fallback
    end
    return text
end

-- Останавливает автоматизацию и сообщает причину игроку.
local function stop(player, key, fallback)
    active = false
    selected = nil
    pending = nil
    player:Say(tr(key, fallback))
end

-- Находит оружие и магазины во всех контейнерах инвентаря.
local function isReloadItem(item)
    return instanceof(item, "HandWeapon") and item:isRanged()
        or instanceof(item, "InventoryItem") and item:getAmmoType() ~= nil
end

-- Учитывает патрон в патроннике только тогда, когда его можно извлечь.
local function chamberedRound(gun)
    return gun:haveChamber() and gun:isRoundChambered()
end

-- Выбирает доступный комплект с наибольшей вместимостью.
local function findBest(player)
    local inventory = player:getInventory()
    local items = inventory:getAllEvalRecurse(isReloadItem)
    local best = nil

    for i = 0, items:size() - 1 do
        local gun = items:get(i)
        if instanceof(gun, "HandWeapon") and gun:isRanged() and not gun:isJammed() then
            local ammoType = gun:getAmmoType()
            local capacity = gun:getMaxAmmo()
            if ammoType and capacity > 0 then
                local loose = inventory:getItemCountRecurse(ammoType:getItemKey())
                local magazineType = gun:getMagazineType()
                if not magazineType then
                    if gun:getCurrentAmmoCount() > 0 or loose > 0 or chamberedRound(gun) then
                        if not best or capacity > best.capacity then
                            best = { gun = gun, capacity = capacity }
                        end
                    end
                else
                    if gun:isContainsClip()
                        and (gun:getCurrentAmmoCount() > 0 or loose > 0 or chamberedRound(gun))
                        and (not best or capacity > best.capacity) then
                        local existing = {}
                        for j = 0, items:size() - 1 do
                            local item = items:get(j)
                            if item:getFullType() == magazineType then
                                existing[item:getID()] = true
                            end
                        end
                        best = { gun = gun, capacity = capacity, eject = true, existing = existing }
                    end
                    for j = 0, items:size() - 1 do
                        local magazine = items:get(j)
                        if magazine:getFullType() == magazineType and magazine:getAmmoType()
                            and magazine:getAmmoType():getItemKey() == ammoType:getItemKey() then
                            local magCapacity = magazine:getMaxAmmo()
                            if magCapacity > 0
                                and (magazine:getCurrentAmmoCount() > 0 or loose > 0)
                                and (not best or magCapacity > best.capacity) then
                                best = { gun = gun, magazine = magazine, capacity = magCapacity }
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- Готовит выбранное оружие и при необходимости извлекает установленный магазин.
local function prepare(player)
    local gun = selected.gun
    if player:getPrimaryHandItem() ~= gun then
        ISInventoryPaneContextMenu.equipWeapon(gun, true, false, player:getPlayerNum())
    end
    if selected.eject then
        ISTimedActionQueue.add(ISEjectMagazine:new(player, gun))
    elseif selected.magazine then
        ISInventoryPaneContextMenu.transferIfNeeded(player, selected.magazine)
    end
    pending = { kind = "prepare" }
end

-- Определяет магазин, созданный игровым действием извлечения.
local function findEjectedMagazine(player)
    local magazineType = selected.gun:getMagazineType()
    local items = player:getInventory():getAllEvalRecurse(isReloadItem)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getFullType() == magazineType and not selected.existing[item:getID()] then
            return item
        end
    end
end

-- Проверяет результат предыдущего действия, не запуская бесконечные повторы при ошибке.
local function finishPending(player)
    if not pending then return true end
    local gun = selected.gun
    local kind = pending.kind
    if kind == "prepare" then
        if player:getPrimaryHandItem() ~= gun then return false end
        if selected.eject then
            if gun:isContainsClip() then return false end
            selected.magazine = findEjectedMagazine(player)
            if not selected.magazine then return false end
            selected.eject = false
            selected.existing = nil
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
    if not inventory:contains(gun) or not inventory:contains(item)
        or player:getPrimaryHandItem() ~= gun or gun:isJammed() then
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
    elseif chamberedRound(gun) and not gun:isContainsClip() then
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
