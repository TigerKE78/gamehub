-- MazxhubModules/loader.lua
-- Bootstrap loader สำหรับ Mazxhub แบบแยก module
--
-- ใช้งาน:
-- 1) อัปโหลดโฟลเดอร์ MazxhubModules ขึ้น GitHub
-- 2) แก้ DEFAULT_BASE ให้เป็น raw GitHub URL ของโฟลเดอร์นี้
-- 3) หรือ override โดย:
--      getgenv().MAZX_BASE = "https://raw.githubusercontent.com/USER/REPO/main/MazxhubModules/"
-- 4) รัน loader.lua

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local ENV = type(getgenv) == "function" and getgenv() or _G

local DEFAULT_BASE =
    "https://raw.githubusercontent.com/TigerKE78/gamehub/master/MazxhubModules/"

local BOOT_RETRIES = 3
local BOOT_RETRY_DELAY = 0.35

local MODULES = {
    { Key = "Farm",     File = "farm.lua" },
    { Key = "Boss",     File = "boss.lua" },
    { Key = "Combat",   File = "combat.lua" },
    { Key = "Skill",    File = "skill.lua" },
    { Key = "Player",   File = "player.lua" },
    { Key = "Teleport", File = "teleport.lua" },
    { Key = "Quest",    File = "quest.lua" },
    { Key = "Dungeon",  File = "dungeon.lua" },
    { Key = "Raid",     File = "raid.lua" },
    { Key = "Loot",     File = "loot.lua" },
    { Key = "World",    File = "world.lua" },
    { Key = "Visuals",  File = "visuals.lua" },
    { Key = "Aimbot",   File = "aimbot.lua" },
    { Key = "Settings", File = "settings.lua" },
    { Key = "UI",       File = "ui.lua" },
}

-- Init ให้ dependency พร้อมก่อน:
-- Farm -> Boss -> Combat -> Skill -> UI
local INIT_ORDER = {
    "Farm",
    "Boss",
    "Combat",
    "Skill",
    "Player",
    "Teleport",
    "Quest",
    "Dungeon",
    "Raid",
    "Loot",
    "World",
    "Visuals",
    "Aimbot",
    "Settings",
    "UI",
}

-- Start เฉพาะระบบที่มี runtime/scheduler
-- UI ไว้ท้ายสุด เพื่อให้ปุ่มทั้งหมดเจอ module พร้อมแล้ว
local START_ORDER = {
    "Farm",
    "Boss",
    "Combat",
    "Skill",
    "Player",
    "Quest",
    "Dungeon",
    "Raid",
    "Loot",
    "World",
    "Visuals",
    "Aimbot",
    "Settings",
    "UI",
}

local function traceback(message)
    if debug and debug.traceback then
        return debug.traceback(tostring(message), 2)
    end
    return tostring(message)
end

local function normalizeBase(url)
    if type(url) ~= "string" then return nil end

    url = url:gsub("^%s+", ""):gsub("%s+$", "")
    if url == "" then return nil end

    -- BASE ต้องชี้ไปยังโฟลเดอร์ที่มี config.lua/core.lua/module ต่าง ๆ
    if url:sub(-1) ~= "/" then
        url = url .. "/"
    end

    return url
end

local function isPlaceholderBase(url)
    if type(url) ~= "string" then return true end
    return url:find("YOUR_NAME", 1, true) ~= nil
        or url:find("YOUR_REPO", 1, true) ~= nil
end

local function httpGet(url, retries, retryDelay)
    retries = math.max(1, math.floor(tonumber(retries) or BOOT_RETRIES))
    retryDelay = math.max(0, tonumber(retryDelay) or BOOT_RETRY_DELAY)

    local lastError

    for attempt = 1, retries do
        local ok, result = pcall(function()
            return game:HttpGet(url)
        end)

        if ok and type(result) == "string" and #result > 0 then
            return result
        end

        lastError = ok and "empty response" or tostring(result)

        if attempt < retries and retryDelay > 0 then
            task.wait(retryDelay)
        end
    end

    return nil, string.format(
        "HTTP failed after %d attempt(s): %s",
        retries,
        tostring(lastError)
    )
end

local function compile(name, source)
    if type(loadstring) ~= "function" then
        return nil, "loadstring is not available in this runtime"
    end

    local ok, chunk, compileError = pcall(
        loadstring,
        source,
        "@Mazxhub/" .. tostring(name)
    )

    if not ok then
        return nil, tostring(chunk)
    end

    if type(chunk) ~= "function" then
        return nil, tostring(compileError or "unknown compile error")
    end

    return chunk
end

local function loadRemote(base, name, retries, retryDelay)
    local url = base .. name

    local source, httpError = httpGet(url, retries, retryDelay)
    if not source then
        return nil, string.format(
            "[%s] download failed\nURL: %s\n%s",
            tostring(name),
            tostring(url),
            tostring(httpError)
        )
    end

    local chunk, compileError = compile(name, source)
    if not chunk then
        return nil, string.format(
            "[%s] compile failed\n%s",
            tostring(name),
            tostring(compileError)
        )
    end

    local ok, result = xpcall(chunk, traceback)
    if not ok then
        return nil, string.format(
            "[%s] execution failed\n%s",
            tostring(name),
            tostring(result)
        )
    end

    return result
end

local function contains(list, wanted)
    if type(list) ~= "table" then return false end

    for _, value in ipairs(list) do
        if tonumber(value) == tonumber(wanted) then
            return true
        end
    end

    return false
end

local function getCreatorId()
    local ok, value = pcall(function()
        return game.CreatorId
    end)

    if ok then
        return tonumber(value) or 0
    end

    return 0
end

local function checkGame(config)
    local rules = type(config) == "table" and config.Game or nil
    if type(rules) ~= "table" then
        return true
    end

    local placeId = tonumber(game.PlaceId) or 0
    local gameId = tonumber(game.GameId) or 0
    local creatorId = getCreatorId()

    local hasRules =
        (type(rules.PlaceIds) == "table" and #rules.PlaceIds > 0)
        or (type(rules.GameIds) == "table" and #rules.GameIds > 0)
        or (type(rules.CreatorIds) == "table" and #rules.CreatorIds > 0)

    if not hasRules then
        if rules.Strict == true then
            return false,
                "Game.Strict = true แต่ยังไม่ได้ใส่ PlaceIds / GameIds / CreatorIds"
        end

        return true
    end

    local matched =
        contains(rules.PlaceIds, placeId)
        or contains(rules.GameIds, gameId)
        or contains(rules.CreatorIds, creatorId)

    if matched then
        return true
    end

    local message = string.format(
        "เกมนี้ไม่ตรงกับรายการที่รองรับ • PlaceId=%s • GameId=%s • CreatorId=%s",
        tostring(placeId),
        tostring(gameId),
        tostring(creatorId)
    )

    if rules.Strict == true then
        return false, message
    end

    warn("[Mazxhub/Loader] " .. message .. " • Strict=false จึงอนุญาตให้รันต่อ")
    return true
end

local function validateModule(name, module)
    if type(module) ~= "table" then
        return false, string.format(
            "%s must return a table, got %s",
            tostring(name),
            typeof(module)
        )
    end

    return true
end

local function safeShutdown(ctx)
    if type(ctx) ~= "table" then return end
    if type(ctx.Shutdown) ~= "function" then return end

    pcall(function()
        ctx:Shutdown()
    end)
end

local function bootstrap()
    local bootstrapBase = normalizeBase(ENV.MAZX_BASE or DEFAULT_BASE)

    if not bootstrapBase or isPlaceholderBase(bootstrapBase) then
        error(
            "ยังไม่ได้ตั้ง GitHub BASE\n"
            .. "แก้ DEFAULT_BASE ใน loader.lua หรือกำหนด getgenv().MAZX_BASE ก่อนรัน"
        )
    end

    warn("[Mazxhub/Loader] BASE = " .. bootstrapBase)

    -- config ต้องโหลดก่อน เพื่อเอาค่า retry / game check / optional BaseURL
    local config, configError = loadRemote(
        bootstrapBase,
        "config.lua",
        BOOT_RETRIES,
        BOOT_RETRY_DELAY
    )

    if not config then
        error(configError)
    end

    if type(config) ~= "table" then
        error("config.lua must return a table")
    end

    -- ถ้าไม่ได้ override ผ่าน MAZX_BASE สามารถให้ config เปลี่ยน BASE ได้
    local base = bootstrapBase
    if ENV.MAZX_BASE == nil then
        local configuredBase = normalizeBase(config.BaseURL)
        if configuredBase and not isPlaceholderBase(configuredBase) then
            base = configuredBase
        end
    end

    local loaderConfig = type(config.Loader) == "table" and config.Loader or {}
    local retries = math.max(
        1,
        math.floor(tonumber(loaderConfig.Retries) or BOOT_RETRIES)
    )
    local retryDelay = math.max(
        0,
        tonumber(loaderConfig.RetryDelay) or BOOT_RETRY_DELAY
    )

    -- ถ้า config redirect ไปอีก BASE ให้โหลด config ตัวจริงจาก BASE นั้นอีกรอบ
    if base ~= bootstrapBase then
        local redirectedConfig, redirectedError = loadRemote(
            base,
            "config.lua",
            retries,
            retryDelay
        )

        if not redirectedConfig then
            error(redirectedError)
        end

        if type(redirectedConfig) ~= "table" then
            error("redirected config.lua must return a table")
        end

        config = redirectedConfig
        loaderConfig = type(config.Loader) == "table" and config.Loader or {}
        retries = math.max(
            1,
            math.floor(tonumber(loaderConfig.Retries) or retries)
        )
        retryDelay = math.max(
            0,
            tonumber(loaderConfig.RetryDelay) or retryDelay
        )
    end

    local gameOK, gameError = checkGame(config)
    if not gameOK then
        error(gameError)
    end

    -- Core มาก่อน เพราะเป็นตัวสร้าง context/scheduler
    local core, coreError = loadRemote(
        base,
        "core.lua",
        retries,
        retryDelay
    )

    if not core then
        error(coreError)
    end

    if type(core) ~= "table" or type(core.Create) ~= "function" then
        error("core.lua must return a table with Core:Create(config)")
    end

    -- Preload module ทั้งหมดก่อน เพื่อไม่ปิด Mazxhub ตัวเก่าถ้าไฟล์ใหม่เสีย
    local loadedModules = {}

    for _, spec in ipairs(MODULES) do
        warn("[Mazxhub/Loader] loading " .. spec.File)

        local module, moduleError = loadRemote(
            base,
            spec.File,
            retries,
            retryDelay
        )

        if not module then
            error(moduleError)
        end

        local valid, validationError = validateModule(spec.Key, module)
        if not valid then
            error(validationError)
        end

        loadedModules[spec.Key] = module
    end

    local ctx
    local createOK, createResult = xpcall(function()
        return core:Create(config)
    end, traceback)

    if not createOK then
        error("Core:Create failed\n" .. tostring(createResult))
    end

    ctx = createResult

    if type(ctx) ~= "table" then
        error("Core:Create(config) did not return a context table")
    end

    ctx.BaseURL = base
    ctx.LoaderVersion = "1.0.0"

    -- ใส่ module ทุกตัวเข้า ctx ก่อน Init
    -- ทำให้ Boss/Farm/UI สามารถอ้างกันได้ตั้งแต่ Init
    for key, module in pairs(loadedModules) do
        ctx.Modules[key] = module
    end

    local initOK, initError = xpcall(function()
        for _, key in ipairs(INIT_ORDER) do
            local module = ctx.Modules[key]

            if module and type(module.Init) == "function" then
                warn("[Mazxhub/Loader] init " .. key)
                module:Init(ctx)
            end
        end
    end, traceback)

    if not initOK then
        safeShutdown(ctx)
        error("Module Init failed\n" .. tostring(initError))
    end

    -- Start ตัวใหม่ก่อน ตัวเก่ายังไม่ถูกปิดจนกว่าจะมั่นใจว่า Start ผ่าน
    local startOK, startError = xpcall(function()
        for _, key in ipairs(START_ORDER) do
            local module = ctx.Modules[key]

            if module and type(module.Start) == "function" then
                warn("[Mazxhub/Loader] start " .. key)
                module:Start()
            end
        end
    end, traceback)

    if not startOK then
        safeShutdown(ctx)
        error("Module Start failed\n" .. tostring(startError))
    end

    -- ตัวใหม่พร้อมแล้ว ค่อยปิด instance เดิม
    local old = ENV.Mazxhub
    if old and old ~= ctx then
        safeShutdown(old)
    end

    ENV.Mazxhub = ctx

    warn(string.format(
        "[Mazxhub] READY • v%s • PlaceId=%s",
        tostring(config.Version or "?"),
        tostring(game.PlaceId)
    ))

    return ctx
end

local ok, result = xpcall(bootstrap, traceback)

if not ok then
    warn("[Mazxhub/Loader] FAILED\n" .. tostring(result))
    return nil
end

return result
