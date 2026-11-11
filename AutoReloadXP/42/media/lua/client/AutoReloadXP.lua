local active = false

local function findMag(inv)
    local items = inv:getAllTypeRecurse("Base.9mmClip")
    if items and items:size() > 0 then return items:get(0) end
    return nil
end

local function step(player)
    if ISTimedActionQueue.isPlayerDoingAction(player) then return end
    local inv = player:getInventory()
    local mag = findMag(inv)
    if not mag then return end

    if mag:getCurrentAmmoCount() <= 0 then
        ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(player, mag, mag:getMaxAmmo()))
    else
        ISTimedActionQueue.add(ISUnloadBulletsFromMagazine:new(player, mag))
    end
end

Events.OnPlayerUpdate.Add(function(p)
    if active and p:isLocalPlayer() then step(p) end
end)

Events.OnKeyPressed.Add(function(key)
    if key == Keyboard.KEY_F9 then
        active = not active
        getPlayer():Say(active and "Авто: ВКЛ" or "Авто: ВЫКЛ")
    end
end)