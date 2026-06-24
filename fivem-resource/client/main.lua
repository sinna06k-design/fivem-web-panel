-- ============================================
--      ADMIN WEB PANEL - CLIENT SIDE
--      ينفذ الأوامر على جهاز اللاعب
-- ============================================

-- ====== فريز اللاعب ======
RegisterNetEvent('adminpanel:freeze')
AddEventHandler('adminpanel:freeze', function(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state)
end)

-- ====== مود الآلهة ======
RegisterNetEvent('adminpanel:godMode')
AddEventHandler('adminpanel:godMode', function(state)
    local ped = PlayerPedId()
    SetEntityInvincible(ped, state)
end)

-- ====== تيليبورت ======
RegisterNetEvent('adminpanel:teleport')
AddEventHandler('adminpanel:teleport', function(x, y, z)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, z, false, false, false, false)
end)

-- ====== تعيين الصحة ======
RegisterNetEvent('adminpanel:setHealth')
AddEventHandler('adminpanel:setHealth', function(health)
    local ped = PlayerPedId()
    if health <= 0 then
        SetEntityHealth(ped, 0)
    else
        SetEntityHealth(ped, health)
    end
end)

-- ====== تعيين الدرع ======
RegisterNetEvent('adminpanel:setArmor')
AddEventHandler('adminpanel:setArmor', function(armor)
    local ped = PlayerPedId()
    SetPedArmour(ped, armor)
end)

-- ====== إشعار للاعب ======
RegisterNetEvent('adminpanel:notify')
AddEventHandler('adminpanel:notify', function(message, notifType)
    ShowNotification(message, notifType)
end)

-- ====== دالة الإشعارات ======
function ShowNotification(msg, notifType)
    local formattedMsg = msg
    if notifType == "success" and not string.find(msg, "~") then
        formattedMsg = "~g~[نجاح] ~w~" .. msg
    elseif notifType == "error" and not string.find(msg, "~") then
        formattedMsg = "~r~[خطأ] ~w~" .. msg
    elseif (notifType == "warning" or notifType == "warn") and not string.find(msg, "~") then
        formattedMsg = "~y~[تنبيه] ~w~" .. msg
    elseif notifType == "info" and not string.find(msg, "~") then
        formattedMsg = "~b~[معلومة] ~w~" .. msg
    end

    -- ESX notification
    if GetResourceState('es_extended') == 'started' then
        TriggerEvent('esx:showNotification', formattedMsg)
    -- QBCore notification
    elseif GetResourceState('qb-core') == 'started' then
        TriggerEvent('QBCore:Notify', msg, notifType or 'primary', 5000)
    -- Default FiveM notification
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(formattedMsg)
        DrawNotification(false, false)
    end
end

-- ====== مراقبة اللاعب (Spectate) ======
local isSpectating = false
local spectateTarget = nil
local lastCoords = nil

RegisterNetEvent('adminpanel:spectate')
AddEventHandler('adminpanel:spectate', function(targetServerId, targetCoords)
    local localPed = PlayerPedId()
    
    if isSpectating then
        -- إيقاف المراقبة
        isSpectating = false
        spectateTarget = nil
        
        NetworkSetInSpectatorMode(false, localPed)
        SetEntityVisible(localPed, true, true)
        SetEntityInvincible(localPed, false)
        SetEntityCollision(localPed, true, true)
        FreezeEntityPosition(localPed, false)
        
        if lastCoords then
            SetEntityCoords(localPed, lastCoords.x, lastCoords.y, lastCoords.z, false, false, false, false)
            lastCoords = nil
        end
        ShowNotification("~r~تم إيقاف المراقبة", "info")
    else
        -- بدء المراقبة
        isSpectating = true
        spectateTarget = targetServerId
        lastCoords = GetEntityCoords(localPed)
        
        -- إخفاء وتجميد الأدمن لمنع السقوط أو إزعاج اللاعبين
        SetEntityVisible(localPed, false, false)
        SetEntityInvincible(localPed, true)
        SetEntityCollision(localPed, false, false)
        FreezeEntityPosition(localPed, true)
        
        -- الانتقال لموقع الهدف حتى يتحمل البيد الخاص به
        if targetCoords then
            SetEntityCoords(localPed, targetCoords.x, targetCoords.y, targetCoords.z - 15.0, false, false, false, false)
        end
        
        Citizen.CreateThread(function()
            local attempts = 0
            local targetPlayer = GetPlayerFromServerId(targetServerId)
            local targetPed = GetPlayerPed(targetPlayer)
            
            -- انتظار تحميل البيد للاعب الهدف
            while (not targetPed or targetPed == 0 or targetPlayer == -1) and attempts < 50 do
                Citizen.Wait(100)
                targetPlayer = GetPlayerFromServerId(targetServerId)
                targetPed = GetPlayerPed(targetPlayer)
                attempts = attempts + 1
            end
            
            if targetPed and targetPed ~= 0 and targetPlayer ~= -1 then
                NetworkSetInSpectatorMode(true, targetPed)
                ShowNotification("~g~بدأت مراقبة اللاعب حالياً", "success")
                
                -- إبقاء الأدمن قريباً من الهدف لمنع الاختفاء
                while isSpectating do
                    Citizen.Wait(1000)
                    local currentTargetPlayer = GetPlayerFromServerId(spectateTarget)
                    local currentTargetPed = GetPlayerPed(currentTargetPlayer)
                    if currentTargetPed and currentTargetPed ~= 0 and currentTargetPlayer ~= -1 then
                        local coords = GetEntityCoords(currentTargetPed)
                        SetEntityCoords(localPed, coords.x, coords.y, coords.z - 15.0, false, false, false, false)
                    else
                        -- فقدان الهدف
                        isSpectating = false
                        NetworkSetInSpectatorMode(false, localPed)
                        SetEntityVisible(localPed, true, true)
                        SetEntityInvincible(localPed, false)
                        SetEntityCollision(localPed, true, true)
                        FreezeEntityPosition(localPed, false)
                        if lastCoords then
                            SetEntityCoords(localPed, lastCoords.x, lastCoords.y, lastCoords.z, false, false, false, false)
                            lastCoords = nil
                        end
                        ShowNotification("~r~تم إيقاف المراقبة - غادر اللاعب أو لم يعد متاحاً", "error")
                    end
                end
            else
                -- فشل
                isSpectating = false
                SetEntityVisible(localPed, true, true)
                SetEntityInvincible(localPed, false)
                SetEntityCollision(localPed, true, true)
                FreezeEntityPosition(localPed, false)
                if lastCoords then
                    SetEntityCoords(localPed, lastCoords.x, lastCoords.y, lastCoords.z, false, false, false, false)
                    lastCoords = nil
                end
                ShowNotification("~r~تعذر العثور على اللاعب لمراقبته", "error")
            end
        end)
    end
end)

print("[AdminPanel] ✅ Client script loaded!")
