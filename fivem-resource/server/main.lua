-- ============================================
--      ADMIN WEB PANEL - SERVER SIDE
--      يشتغل على HTTP API على بورت السيرفر
-- ============================================

local frozenPlayers = {}
local godModePlayers = {}

-- ====== تحقق من المفتاح ======
local function checkAuth(req)
    local key = req.headers['x-api-key'] or ""
    return key == Config.ApiKey
end

-- ====== تحقق من وجود اللاعب ======
local function getPlayerByServerId(id)
    local src = tonumber(id)
    if src and GetPlayerName(src) then
        return src
    end
    return nil
end

-- ====== لوج العمليات ======
local function log(action, target, admin)
    if Config.Logging then
        print(string.format("[AdminPanel] %s => Player: %s | By: %s", action, tostring(target), tostring(admin)))
    end
end

-- ====== العثور على سورس الأدمن المتصل بالخادم حالياً ======
local function getOnlineAdminSource()
    for _, src in ipairs(GetPlayers()) do
        for _, adminIdentifier in ipairs(Config.Admins) do
            for i = 0, GetNumPlayerIdentifiers(src) - 1 do
                local playerIdentifier = GetPlayerIdentifier(src, i)
                if playerIdentifier == adminIdentifier then
                    return tonumber(src)
                end
            end
        end
    end
    return nil
end

-- ====== تنسيق معرفات اللاعب ======
local function getPlayerIdentifiersFormatted(src)
    local formatted = { steam = "N/A", license = "N/A", discord = "N/A", live = "N/A", ip = "N/A" }
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if string.match(id, "steam:") then
            formatted.steam = id
        elseif string.match(id, "license:") then
            formatted.license = id
        elseif string.match(id, "discord:") then
            formatted.discord = string.gsub(id, "discord:", "")
        elseif string.match(id, "live:") then
            formatted.live = id
        elseif string.match(id, "ip:") then
            formatted.ip = string.gsub(id, "ip:", "")
        end
    end
    return formatted
end

-- ====== اجمع بيانات اللاعبين ======
local function getAllPlayers()
    local players = {}
    for _, src in ipairs(GetPlayers()) do
        local id = tonumber(src)
        local identifiers = {}
        for i = 0, GetNumPlayerIdentifiers(src) - 1 do
            table.insert(identifiers, GetPlayerIdentifier(src, i))
        end
        
        local ping = GetPlayerPing(src)
        local name = GetPlayerName(src) or "Unknown"
        local detailedIds = getPlayerIdentifiersFormatted(src)
        
        table.insert(players, {
            id = id,
            name = name,
            ping = ping,
            identifiers = identifiers,
            detailedIds = detailedIds,
            frozen = frozenPlayers[id] or false,
            godMode = godModePlayers[id] or false
        })
    end
    return players
end

-- ====== إرجاع JSON ======
local function sendJSON(res, data, status)
    res.writeHead(status or 200, {
        ['Content-Type'] = 'application/json',
        ['Access-Control-Allow-Origin'] = '*',
        ['Access-Control-Allow-Headers'] = 'Content-Type, x-api-key',
        ['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    })
    res.send(json.encode(data))
end

-- ====== HTTP Handler الرئيسي ======
SetHttpHandler(function(req, res)
    local path = req.path
    local method = req.method

    -- OPTIONS (CORS Preflight)
    if method == 'OPTIONS' then
        res.writeHead(200, {
            ['Access-Control-Allow-Origin'] = '*',
            ['Access-Control-Allow-Headers'] = 'Content-Type, x-api-key',
            ['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        })
        res.send('')
        return
    end

    -- تحقق من المفتاح
    if not checkAuth(req) then
        sendJSON(res, { success = false, error = "Unauthorized - Wrong API Key" }, 401)
        return
    end

    -- ====== GET /players - قائمة اللاعبين ======
    if path == '/players' and method == 'GET' then
        local players = getAllPlayers()
        sendJSON(res, {
            success = true,
            count = #players,
            players = players,
            serverTime = os.time()
        })

    -- ====== GET /info - معلومات السيرفر ======
    elseif path == '/info' and method == 'GET' then
        sendJSON(res, {
            success = true,
            playerCount = #GetPlayers(),
            maxPlayers = GetConvarInt('sv_maxclients', 32),
            serverName = GetConvar('sv_hostname', 'FiveM Server'),
            uptime = GetGameTimer()
        })

    -- ====== POST /kick - كيك لاعب ======
    elseif path == '/kick' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            local reason = data.reason or "Kicked by Admin"
            
            if not src then
                sendJSON(res, { success = false, error = "Player not found" })
                return
            end
            
            log("KICK", data.id, "WebPanel")
            DropPlayer(src, "[Admin Panel] " .. reason)
            sendJSON(res, { success = true, message = "Player kicked: " .. reason })
        end)

    -- ====== POST /ban - باند لاعب ======
    elseif path == '/ban' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            local reason = data.reason or "Banned by Admin"
            
            if not src then
                sendJSON(res, { success = false, error = "Player not found" })
                return
            end
            
            log("BAN", data.id, "WebPanel")
            -- تنفيذ البان مع اليوزر إيدي
            TriggerEvent('adminpanel:banPlayer', src, reason)
            DropPlayer(src, "[Admin Panel] Banned: " .. reason)
            sendJSON(res, { success = true, message = "Player banned: " .. reason })
        end)

    -- ====== POST /freeze - فريز لاعب ======
    elseif path == '/freeze' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            
            if not src then
                sendJSON(res, { success = false, error = "Player not found" })
                return
            end
            
            local state = data.state  -- true = freeze, false = unfreeze
            frozenPlayers[src] = state
            TriggerClientEvent('adminpanel:freeze', src, state)
            log("FREEZE:" .. tostring(state), data.id, "WebPanel")
            sendJSON(res, { success = true, frozen = state })
        end)

    -- ====== POST /godmode - مود الآلهة ======
    elseif path == '/godmode' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            
            if not src then
                sendJSON(res, { success = false, error = "Player not found" })
                return
            end
            
            local state = data.state
            godModePlayers[src] = state
            TriggerClientEvent('adminpanel:godMode', src, state)
            log("GODMODE:" .. tostring(state), data.id, "WebPanel")
            sendJSON(res, { success = true, godMode = state })
        end)

    -- ====== POST /teleport - تيليبورت لاعب ======
    elseif path == '/teleport' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            local targetSrc = getPlayerByServerId(data.targetId)
            
            if not src then
                sendJSON(res, { success = false, error = "Player not found" })
                return
            end
            
            -- تيليبورت لإحداثيات معينة
            if data.coords then
                TriggerClientEvent('adminpanel:teleport', src, data.coords.x, data.coords.y, data.coords.z)
                log("TELEPORT to coords", data.id, "WebPanel")
                sendJSON(res, { success = true, message = "Player teleported to coordinates" })
            -- تيليبورت لعند لاعب آخر
            elseif targetSrc then
                local ped = GetPlayerPed(targetSrc)
                local pos = GetEntityCoords(ped)
                TriggerClientEvent('adminpanel:teleport', src, pos.x + 2.0, pos.y, pos.z)
                log("TELEPORT to player", data.id, "WebPanel")
                sendJSON(res, { success = true, message = "Player teleported to target" })
            else
                sendJSON(res, { success = false, error = "No coords or target provided" })
            end
        end)

    -- ====== POST /bring - استدعاء لاعب إليك ======
    elseif path == '/bring' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            local adminSrc = getPlayerByServerId(data.adminId)
            
            if not src or not adminSrc then
                sendJSON(res, { success = false, error = "Player not found" })
                return
            end
            
            local adminPed = GetPlayerPed(adminSrc)
            local pos = GetEntityCoords(adminPed)
            TriggerClientEvent('adminpanel:teleport', src, pos.x + 2.0, pos.y, pos.z)
            log("BRING", data.id, "WebPanel")
            sendJSON(res, { success = true, message = "Player brought to admin" })
        end)

    -- ====== POST /setHealth - تعيين الصحة ======
    elseif path == '/setHealth' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            local health = tonumber(data.health) or 200
            
            if not src then
                sendJSON(res, { success = false, error = "Player not found" })
                return
            end
            
            health = math.min(math.max(health, 0), 200)
            TriggerClientEvent('adminpanel:setHealth', src, health)
            log("SET HEALTH:" .. health, data.id, "WebPanel")
            sendJSON(res, { success = true, health = health })
        end)

    -- ====== POST /setArmor - تعيين الدرع ======
    elseif path == '/setArmor' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            local armor = tonumber(data.armor) or 100
            
            if not src then
                sendJSON(res, { success = false, error = "Player not found" })
                return
            end
            
            armor = math.min(math.max(armor, 0), 100)
            TriggerClientEvent('adminpanel:setArmor', src, armor)
            log("SET ARMOR:" .. armor, data.id, "WebPanel")
            sendJSON(res, { success = true, armor = armor })
        end)

    -- ====== POST /giveMoney - إعطاء فلوس ======
    elseif path == '/giveMoney' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            local amount = tonumber(data.amount) or 0
            local moneyType = data.type or "cash"
            
            if not src then
                sendJSON(res, { success = false, error = "Player not found" })
                return
            end
            
            -- ESX Support
            if Config.Framework == "esx" then
                TriggerEvent('esx:getSharedObject', function(ESX)
                    local xPlayer = ESX.GetPlayerFromId(src)
                    if xPlayer then
                        xPlayer.addMoney(amount)
                    end
                end)
            -- QBCore Support
            elseif Config.Framework == "qbcore" then
                local QBCore = exports['qb-core']:GetCoreObject()
                local Player = QBCore.Functions.GetPlayer(src)
                if Player then
                    Player.Functions.AddMoney(moneyType, amount)
                end
            end
            
            log("GIVE MONEY:" .. amount, data.id, "WebPanel")
            sendJSON(res, { success = true, amount = amount })
        end)

    -- ====== POST /sendMessage - رسالة للاعب ======
    elseif path == '/sendMessage' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            local message = data.message or ""
            local msgType = data.msgType or "all" -- "all" or "specific"
            
            if msgType == "all" then
                TriggerClientEvent('adminpanel:notify', -1, message, "info")
                log("BROADCAST MESSAGE", "all", "WebPanel")
                sendJSON(res, { success = true, message = "Broadcast sent" })
            elseif src then
                TriggerClientEvent('adminpanel:notify', src, message, "info")
                log("SEND MESSAGE", data.id, "WebPanel")
                sendJSON(res, { success = true, message = "Message sent" })
            else
                sendJSON(res, { success = false, error = "Player not found" })
            end
        end)

    -- ====== POST /killPlayer - قتل لاعب ======
    elseif path == '/kill' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            
            if not src then
                sendJSON(res, { success = false, error = "Player not found" })
                return
            end
            
            TriggerClientEvent('adminpanel:setHealth', src, 0)
            log("KILL", data.id, "WebPanel")
            sendJSON(res, { success = true, message = "Player killed" })
        end)

    -- ====== POST /heal - شفاء لاعب ======
    elseif path == '/heal' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            
            if not src then
                sendJSON(res, { success = false, error = "Player not found" })
                return
            end
            
            TriggerClientEvent('adminpanel:setHealth', src, 200)
            TriggerClientEvent('adminpanel:setArmor', src, 100)
            log("HEAL", data.id, "WebPanel")
            sendJSON(res, { success = true, message = "Player healed" })
        end)

    -- ====== POST /spectate - مراقبة لاعب ======
    elseif path == '/spectate' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local src = getPlayerByServerId(data.id)
            
            if not src then
                sendJSON(res, { success = false, error = "Player not found" })
                return
            end
            
            local adminSrc = getOnlineAdminSource()
            if not adminSrc then
                sendJSON(res, { success = false, error = "يجب أن تكون متصلاً بالسيرفر بنفس حساب Steam لتفعيل المراقبة" })
                return
            end
            
            local ped = GetPlayerPed(src)
            local pos = GetEntityCoords(ped)
            local coords = { x = pos.x, y = pos.y, z = pos.z }
            
            TriggerClientEvent('adminpanel:spectate', adminSrc, src, coords)
            log("SPECTATE Toggle", data.id, adminSrc)
            sendJSON(res, { success = true, message = "Spectating toggled" })
        end)

    -- ====== POST /runCommand - تشغيل أمر كونسول ======
    elseif path == '/runCommand' and method == 'POST' then
        req.setDataHandler(function(body)
            local data = json.decode(body) or {}
            local command = data.command
            
            if not command or command == "" then
                sendJSON(res, { success = false, error = "أدخل الأمر أولاً" })
                return
            end
            
            log("RUN COMMAND: " .. command, "WebPanel", "System")
            ExecuteCommand(command)
            sendJSON(res, { success = true, message = "تم تنفيذ الأمر بنجاح" })
        end)

    -- ====== Not Found ======
    else
        sendJSON(res, { success = false, error = "Endpoint not found: " .. path }, 404)
    end
end)

-- نظّف البيانات لما لاعب يطلع
AddEventHandler('playerDropped', function()
    local src = source
    frozenPlayers[src] = nil
    godModePlayers[src] = nil
end)

-- طباعة رابط لوحة التحكم عند بدء التشغيل
local serverPort = GetConvar('web_port', '30120')
print("[AdminPanel] ✅ Server started! API is ready.")
print("[AdminPanel] 🛡️ Web panel is ready! Open this link in your browser to manage your server:")
print("[AdminPanel] 🔗 http://YOUR_SERVER_IP:" .. serverPort .. "/" .. GetCurrentResourceName() .. "/web/index.html")
