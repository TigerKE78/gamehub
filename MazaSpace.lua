-- MazaSpace standalone snapshot. Run this file to use the edited local modules.
-- Rebuild after changing individual modules. Does not fetch modules from GitHub.
local BUNDLED_SOURCES = {}
BUNDLED_SOURCES["config.lua"] = [====[
-- MazxhubModules/config.lua
-- ค่ากลางที่แก้ได้โดยไม่ต้องแตะ logic ของระบบ

return {
    Version = "0.1.0",

    -- เปลี่ยนเป็น raw GitHub ของคุณก่อนใช้งาน loader แบบออนไลน์
    BaseURL = "https://raw.githubusercontent.com/TigerKE78/gamehub/master/MazxhubModules/",

    -- ตรวจว่า loader กำลังรันอยู่ในเกมที่รองรับหรือไม่
    -- Strict = false = ยังอนุญาตทุกเกมระหว่างพัฒนา
    -- เมื่อพร้อมใช้งานจริงให้เปลี่ยนเป็น true แล้วใส่ ID ที่ต้องการ
    Game = {
        Strict = false,
        PlaceIds = {
            -- 136406881576517,
        },
        GameIds = {
            -- Universe ID เช่น game.GameId
        },
        CreatorIds = {
            -- Creator/User/Group ID เช่น game.CreatorId
        },
    },

    Loader = {
        Retries = 3,
        RetryDelay = 0.35,
    },

    Intervals = {
        Farm = 0.10,
        Combat = 0.02,
        Skill = 0.05,
    },

    Farm = {
        MoveAboveTarget = true,
        HeightAboveHead = 3,
        AttackRange = 12,
    },

    Skill = {
        Z = { Enabled = false, Interval = 1.0 },
        X = { Enabled = false, Interval = 1.0 },
        C = { Enabled = false, Interval = 1.0 },
        V = { Enabled = false, Interval = 1.0 },
        B = { Enabled = false, Interval = 1.0 },
        N = { Enabled = false, Interval = 1.0 },
        K = { Enabled = false, Interval = 1.0 },
    },
}
]====]
BUNDLED_SOURCES["core.lua"] = [====[
-- MazxhubModules/core.lua
-- Core กลาง: Services + State + Scheduler เพียง Heartbeat เดียว

local Core = {}

function Core:Create(config)
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local VirtualInputManager = game:GetService("VirtualInputManager")

    local ctx = {
        Config = config,
        Modules = {},
        Jobs = {},
        Connections = {},
        State = {
            Running = true,
            FarmEnabled = false,
            FarmMode = nil,
            Target = nil,
            TargetName = nil,
        },
        Services = {
            RunService = RunService,
            Players = Players,
            UserInputService = UserInputService,
            VirtualInputManager = VirtualInputManager,
        },
        Player = Players.LocalPlayer,
    }

    function ctx:RegisterJob(name, interval, callback)
        self.Jobs[name] = {
            Enabled = true,
            Interval = math.max(tonumber(interval) or 0.1, 0.01),
            NextAt = 0,
            Callback = callback,
        }
    end

    function ctx:SetJobEnabled(name, enabled)
        local job = self.Jobs[name]
        if job then
            job.Enabled = enabled == true
            if job.Enabled then job.NextAt = 0 end
        end
    end

    function ctx:RemoveJob(name)
        self.Jobs[name] = nil
    end

    function ctx:GetCharacter()
        local character = self.Player and self.Player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        return character, humanoid, root
    end

    function ctx:IsAlive(model)
        if not model or not model.Parent then return false end
        local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
        return humanoid ~= nil and humanoid.Health > 0
    end

    function ctx:Shutdown()
        self.State.Running = false
        for _, module in pairs(self.Modules) do
            if type(module) == "table" and module.Stop then
                pcall(function() module:Stop() end)
            end
        end
        for _, connection in ipairs(self.Connections) do
            pcall(function() connection:Disconnect() end)
        end
        self.Connections = {}
        self.Jobs = {}
    end

    local heartbeat = RunService.Heartbeat:Connect(function()
        if not ctx.State.Running then return end

        local now = os.clock()
        for name, job in pairs(ctx.Jobs) do
            if job.Enabled and not job.Busy and now >= job.NextAt then
                job.Busy = true
                job.NextAt = now + job.Interval
                local ok, err = xpcall(job.Callback, function(message)
                    if debug and debug.traceback then
                        return debug.traceback(tostring(message), 2)
                    end
                    return tostring(message)
                end)
                job.Busy = false
                if not ok then
                    warn("[Mazxhub/" .. tostring(name) .. "] " .. tostring(err))
                end
            end
        end
    end)

    table.insert(ctx.Connections, heartbeat)
    return ctx
end

return Core

]====]
BUNDLED_SOURCES["farm.lua"] = [====[
-- MazxhubModules/farm.lua
-- Farm จริงที่ย้ายจาก hello.txt
-- รักษาชื่อ helper เดิมไว้ให้มากที่สุด แต่ใช้ Core scheduler แทน Heartbeat แยก

local Farm = {
    Enabled = false,
    Mode = nil,
    Owner = nil,
    OnStateChanged = nil,
    MobName = nil,
    BossEnabled = false,
    BossName = "Zuko",

    Hitbox = 18,
    HeadHeight = 3,
    AttackPosition = "Above head",
    BehindDistance = 4,
    BehindHeight = 0,
    AttackRange = 12,

    AutoAttack = true,
    AutoQuest = false,
    AutoLoot = false,
    PlayerAttackHitbox = 30,
    PlayerHitboxTest = false,
    QuestKills = 0,

    AttackInterval = 0.04,
    FastAttack = true,
    AdaptiveFastAttack = false,
    BypassComboGate = true,
    NoSwingAnimation = false,
    SelectedWeapon = "ช่อง 1",

    _target = nil,
    _attackTarget = nil,
    ExternalMode = nil,
    ExternalResolver = nil,
    ExternalMover = nil,
    _conn = nil,
    _cameraConn = nil,
    _skillHeld = false,
    _skillPoseUntil = 0,
    _lastRuntimeError = nil,
    _nextScanAt = 0,

    _hitboxOriginals = setmetatable({}, { __mode = "k" }),
    _hitboxTool = nil,
    _hitboxNextAt = 0,
    _mobHitboxOriginals = setmetatable({}, { __mode = "k" }),
    _mobHitboxTarget = nil,
    _mobHitboxNextAt = 0,

    Functions = {},
}

local FARM_PATH = { "Humanoids", "Regions", "Windy Peak", "ActiveNpcs" }

local FARM_TYPES = {
    "Bandit",
    "Civilian",
    "Bear Cub",
    "Kaiden Subordinate",
    "Hoyuzo Subordinate",
    "Beast Born Demon",
    "Ice Profound Demon",
    "Fire Profound Demon",
}

local RAID_BOX_POINTS = {
    [1] = Vector3.new(331.1376953125, 1021.4044189453125, -686.1722412109375),
    [2] = Vector3.new(802.3745727539062, 1124.2423095703125, -1002.8580322265625),
    [3] = Vector3.new(942.5108032226562, 1104.9501953125, -1147.0958251953125),
    [4] = Vector3.new(538.2649536132812, 1021.5513305664062, 201.63821411132812),
    [5] = Vector3.new(1055.079833984375, 1049.7620849609375, -452.88006591796875),
    [6] = Vector3.new(-669.5108032226562, 1007.0742797851562, 1160.7030029296875),
    [7] = Vector3.new(389.7073974609375, 1124.5743408203125, -1170.9603271484375),
    [8] = Vector3.new(321.6490783691406, 1225.0743408203125, -1771.9432373046875),
    [9] = Vector3.new(-667.1080932617188, 1385.0743408203125, -2732.900390625),
    [10] = Vector3.new(-966.843505859375, 1385.07421875, -2553.394287109375),
    [11] = Vector3.new(392.162841796875, 1351.4998779296875, -2311.40966796875),
    [12] = Vector3.new(386.46990966796875, 1124.57421875, -1170.58935546875),
    [13] = Vector3.new(320.561279296875, 1225.07421875, -1771.89697265625),
    [14] = Vector3.new(390.47357177734375, 1351.499755859375, -2312.249755859375),
    [15] = Vector3.new(155.78236389160156, 1320.4747314453125, -2226.569580078125),
    [16] = Vector3.new(-964.1453857421875, 1385.07421875, -2553.462158203125),
    [17] = Vector3.new(-1230.3951416015625, 1384.384033203125, -2261.093994140625),
    [18] = Vector3.new(-1797.848388671875, 314.9781188964844, 1098.8353271484375),
    [19] = Vector3.new(-1261.2542724609375, 288.99993896484375, 746.497802734375),
    [20] = Vector3.new(-1377.419189453125, 265.0743713378906, -53.3534049987793),
    [21] = Vector3.new(-788.6260375976562, 966.8233032226562, 121.39598083496094),
    [22] = Vector3.new(918.4935302734375, 1021.5743408203125, 15.780023574829102),
    [23] = Vector3.new(1052.7286376953125, 1045.9229736328125, -481.54010009765625),
    [24] = Vector3.new(789.4100952148438, 1229.9996337890625, 420.6759033203125),
}

local BOSS_REGIONS = {
    Zuko = "Windy Peak",
    ["Mother Bear"] = "Bamboo Grove",
    Kaiden = "Bamboo Grove",
    Hoyuzo = "Bamboo Grove",
    Akazo = "Misc",
    ["Serpent Trainee"] = "Misc",
    Gyutai = "Misc",
    Datai = "Misc",
    ["Thunder Trainee"] = "Misc",
    Zentaro = "Misc",
    ["Wind Trainee"] = "Misc",
    Tengai = "Misc",
    ["Sound Trainee"] = "Misc",
    Sumari = "Misc",
    ["Flame Trainee"] = "Misc",
    Nezura = "Misc",
    Fujiko = "Misc",
    ["Insect Trainee"] = "Misc",
    ["Soryu Trainee Goki"] = "Misc",
    ["Yeti Demon"] = "Temporary",
    Rengu = "Misc",
}

local BOSS_WARP_POSITIONS = {
    Zuko = Vector3.new(-282.24, 1226.70, -1035.92),
    ["Mother Bear"] = Vector3.new(500.41, 1122.17, -995.84),
    Kaiden = Vector3.new(582.14, 1148.99, -1314.34),
    Gyutai = Vector3.new(-263.21, 1045.74, -1142.99),
    Datai = Vector3.new(-162.96, 1045.50, -1138.90),
    ["Serpent Trainee"] = Vector3.new(-271.11, 1294.50, -1536.17),
    ["Wind Trainee"] = Vector3.new(-941.91, 1383.50, -2634.24),
    Tengai = Vector3.new(-134.29, 1351.50, -2629.80),
    ["Sound Trainee"] = Vector3.new(191.50, 1351.50, -2584.06),
    Obari = Vector3.new(771.11, 1123.49, -1049.57),
    Zentaro = Vector3.new(1329.28, 823.50, -1016.46),
    ["Thunder Trainee"] = Vector3.new(2427.88, 1076.01, -553.91),
    ["Stone Trainee"] = Vector3.new(2686.55, 1075.90, -563.85),
    Gyorei = Vector3.new(2577.35, 1091.50, -740.00),
    ["Water Trainee Sabito"] = Vector3.new(813.75, 1020.62, 102.49),
    Giyen = Vector3.new(391.82, 1020.50, -86.08),
    Sumari = Vector3.new(393.49, 1020.50, -621.29),
    Yahari = Vector3.new(827.42, 1021.70, -636.29),
    Reaper = Vector3.new(97.02, 1045.48, -571.47),
    Saneri = Vector3.new(-380.61, 1095.87, -424.20),
    Shinora = Vector3.new(-450.38, 967.00, -0.95),
    Enru = Vector3.new(822.20, 798.06, 544.81),
    ["Flame Trainee"] = Vector3.new(-1131.45, 1031.55, 998.73),
    Nezura = Vector3.new(-1460.55, 278.45, 937.27),
    Fujiko = Vector3.new(-2460.92, 40.33, 1118.08),
    ["Insect Trainee"] = Vector3.new(-1394.92, 264.00, 71.03),
    ["Soryu Trainee Goki"] = Vector3.new(-425.90, 291.16, 541.26),
    Hoyuzo = Vector3.new(748.19, 1003.50, -1414.87),
    ["Yeti Demon"] = Vector3.new(-1389.28, -35.35, 503.90),
    Rengu = Vector3.new(-715.71, 967.50, 884.20),
}

local FarmCharacterState = {
    Player = nil,
    Character = nil,
    NextScanAt = 0,
    Humanoids = setmetatable({}, { __mode = "k" }),
    Parts = setmetatable({}, { __mode = "k" }),
    Cameras = setmetatable({}, { __mode = "k" }),
    SmoothHoverPosition = nil,
    LastHoverUpdate = 0,
}

local function player()
    return Farm.Ctx and Farm.Ctx.Player
end

local function getRegions()
    local humanoids = workspace:FindFirstChild("Humanoids")
    return humanoids and humanoids:FindFirstChild("Regions")
end

local function farmActiveFolder()
    local node = workspace
    for _, seg in ipairs(FARM_PATH) do
        node = node and node:FindFirstChild(seg)
        if not node then return nil end
    end
    return node
end

local function farmActiveFolderForName(name)
    local wanted = tostring(name or ""):lower()

    if wanted == "bear cub"
        or wanted == "kaiden subordinate"
        or wanted == "hoyuzo subordinate" then

        local regions = getRegions()
        local grove = regions and regions:FindFirstChild("Bamboo Grove")
        return grove and grove:FindFirstChild("ActiveNpcs")
    end

    if wanted == "beast born demon" then
        local regions = getRegions()
        local harbor = regions and regions:FindFirstChild("Mistfall Harbor")
        return harbor and harbor:FindFirstChild("ActiveNpcs")
    end

    if wanted == "ice profound demon" or wanted == "fire profound demon" then
        local regions = getRegions()
        local iceveil = regions and regions:FindFirstChild("Iceveil Valley")
        return iceveil and iceveil:FindFirstChild("ActiveNpcs")
    end

    local raidPoint = tonumber(wanted:match("^raid box point (%d+)$"))
    if raidPoint and RAID_BOX_POINTS[raidPoint] then
        local regions = getRegions()
        local temporary = regions and regions:FindFirstChild("Temporary")
        return temporary and temporary:FindFirstChild("ActiveNpcs")
    end

    return farmActiveFolder()
end

local function farmFindMobsByName(name)
    local out, seenRoots = {}, {}
    local wanted = tostring(name or ""):lower()
    local folder = farmActiveFolderForName(name)

    if wanted == "" or not folder then
        return out
    end

    local raidPoint = tonumber(wanted:match("^raid box point (%d+)$"))
    if raidPoint and RAID_BOX_POINTS[raidPoint] then
        local raidOrigin = RAID_BOX_POINTS[raidPoint]
        local raidRadius = raidPoint == 6 and 180 or 110
        local candidates = {}
        local seenModels = {}

        for _, hum in ipairs(folder:GetDescendants()) do
            if hum:IsA("Humanoid") and hum.Health > 0 then
                local model = hum.Parent

                if model and model:IsA("Model") and not seenModels[model] then
                    local root = model:FindFirstChild("HumanoidRootPart")
                        or model:FindFirstChild("HumanoidRootPart", true)

                    if root and root:IsA("BasePart") and not seenRoots[root] then
                        local distance = (root.Position - raidOrigin).Magnitude

                        if distance <= raidRadius then
                            seenModels[model] = true
                            seenRoots[root] = true
                            table.insert(candidates, {
                                Model = model,
                                Distance = distance,
                            })
                        end
                    end
                end
            end
        end

        table.sort(candidates, function(a, b)
            return a.Distance < b.Distance
        end)

        for _, candidate in ipairs(candidates) do
            table.insert(out, candidate.Model)
        end

        return out
    end

    if wanted == "kaiden subordinate"
        or wanted == "hoyuzo subordinate"
        or wanted == "beast born demon" then

        local exactName =
            wanted == "kaiden subordinate" and "Kaiden Subordinate"
            or wanted == "hoyuzo subordinate" and "Hoyuzo Subordinate"
            or "Beast Born Demon"

        for _, wrapper in ipairs(folder:GetChildren()) do
            local model

            if wrapper.Name:lower() == wanted then
                model = wrapper:FindFirstChild(exactName) or wrapper
            else
                model = wrapper:FindFirstChild(exactName)
            end

            if model then
                local root = model:FindFirstChild("HumanoidRootPart")
                    or model:FindFirstChild("HumanoidRootPart", true)
                local hum = model:FindFirstChildWhichIsA("Humanoid", true)

                if root
                    and root:IsA("BasePart")
                    and not seenRoots[root]
                    and (not hum or hum.Health > 0) then

                    seenRoots[root] = true
                    table.insert(out, model)

                    if wanted == "kaiden subordinate" and #out >= 4 then break end
                    if wanted == "beast born demon" and #out >= 3 then break end
                end
            end
        end

        return out
    end

    for _, item in ipairs(folder:GetDescendants()) do
        if item:IsA("BasePart")
            and item.Name == "HumanoidRootPart"
            and not seenRoots[item] then

            local node = item.Parent
            local matched = false

            while node and node ~= folder do
                if node.Name:lower() == wanted then
                    matched = true
                    break
                end
                node = node.Parent
            end

            if matched and wanted ~= "zuko" then
                seenRoots[item] = true
                table.insert(out, item.Parent)
            end
        end
    end

    return out
end

local function farmBossFolder(name)
    local regions = getRegions()
    if not regions then return nil end

    local wanted = tostring(name or ""):lower()
    if wanted == "" then return nil end

    for _, region in ipairs(regions:GetChildren()) do
        local active = region:FindFirstChild("ActiveNpcs")

        if active then
            local direct = active:FindFirstChild(name)
            if direct then return active end

            for _, node in ipairs(active:GetDescendants()) do
                if node.Name:lower() == wanted then
                    return active
                end
            end
        end
    end

    local region = regions:FindFirstChild(BOSS_REGIONS[name] or "Misc")
    return region and region:FindFirstChild("ActiveNpcs")
end

local function farmBossModel(name, includeDead)
    local folder = farmBossFolder(name)
    if not folder then return nil end

    local wanted = tostring(name or ""):lower()
    if wanted == "" then return nil end

    if wanted == "zentaro" or wanted == "yeti demon" then
        local exactName = wanted == "zentaro" and "Zentaro" or "Yeti Demon"
        local wrapper = folder:FindFirstChild(exactName)
        local model = wrapper and wrapper:FindFirstChild(exactName)
        local root = model and (
            model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("HumanoidRootPart", true)
        )
        local hum = model and model:FindFirstChildWhichIsA("Humanoid", true)

        if model and root and (not hum or hum.Health > 0) then
            return model
        end
        if includeDead and model and root then
            return model
        end
    end

    if wanted == "kaiden"
        or wanted == "akazo"
        or wanted == "serpent trainee"
        or wanted == "gyutai"
        or wanted == "datai"
        or wanted == "thunder trainee" then

        local exactName =
            wanted == "kaiden" and "Kaiden"
            or wanted == "akazo" and "Akazo"
            or wanted == "gyutai" and "Gyutai"
            or wanted == "datai" and "Datai"
            or wanted == "thunder trainee" and "Thunder Trainee"
            or "Serpent Trainee"

        local wrapper = folder:FindFirstChild(exactName)
        local model = wrapper and (wrapper:FindFirstChild(exactName) or wrapper)

        if model then
            local root = model:FindFirstChild("HumanoidRootPart")
                or model:FindFirstChild("HumanoidRootPart", true)
            local hum = model:FindFirstChildWhichIsA("Humanoid", true)

            if root and (not hum or hum.Health > 0) then
                return model
            end
            if includeDead and root then
                return model
            end
        end
    end

    local deadModel

    for _, item in ipairs(folder:GetDescendants()) do
        if item:IsA("BasePart") and item.Name == "HumanoidRootPart" then
            local node = item.Parent

            while node and node ~= folder do
                if node.Name:lower() == wanted then
                    local bossModel = item.Parent
                    local bossHumanoid =
                        bossModel:IsA("Model")
                        and bossModel:FindFirstChildWhichIsA("Humanoid", true)
                        or nil

                    if not bossHumanoid or bossHumanoid.Health > 0 then
                        return bossModel
                    end

                    deadModel = bossModel
                    break
                end

                node = node.Parent
            end
        end
    end

    return includeDead and deadModel or nil
end

local function farmFindBossByName(name)
    return farmBossModel(name, false)
end

local function farmFindBoss()
    return farmFindBossByName(Farm.BossName)
end

local function farmListMobTypes()
    local list = {}
    for _, name in ipairs(FARM_TYPES) do
        table.insert(list, name)
    end
    return list
end

local function farmListBossTypes()
    local boss = Farm.Ctx
        and Farm.Ctx.Modules
        and Farm.Ctx.Modules.Boss

    if boss and type(boss.Names) == "table" then
        local list = {}
        for _, name in ipairs(boss.Names) do
            table.insert(list, name)
        end
        return list
    end

    local list = {}
    for name in pairs(BOSS_WARP_POSITIONS) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

local function farmNearestByName(name, bossMode)
    if Farm.Dungeon and Farm.Dungeon.Enabled and Farm.Dungeon.FindTarget then
        return Farm.Dungeon:FindTarget()
    end

    local list

    if bossMode then
        local boss = farmFindBossByName(name)
        list = boss and { boss } or {}
    else
        list = farmFindMobsByName(name)
    end

    local plr = player()
    local hrp = plr
        and plr.Character
        and plr.Character:FindFirstChild("HumanoidRootPart")

    if not hrp then return nil end

    local best, bestD = nil, math.huge

    for _, mob in ipairs(list) do
        local mobHumanoid =
            mob:IsA("Model")
            and mob:FindFirstChildWhichIsA("Humanoid", true)
            or nil

        local alive = not mobHumanoid or mobHumanoid.Health > 0
        local pivot

        if alive and mob:IsA("Model") then
            pivot = mob:GetPivot().Position
        elseif alive and mob:IsA("BasePart") then
            pivot = mob.Position
        elseif alive then
            local part = mob:FindFirstChildWhichIsA("BasePart", true)
            if part then pivot = part.Position end
        end

        if pivot then
            local distance = (pivot - hrp.Position).Magnitude

            if distance < bestD then
                bestD = distance
                best = mob
            end
        end
    end

    return best
end

function FarmCharacterState:ReleaseHover()
    if self.HoverOrientation then
        self.HoverOrientation:Destroy()
    end
    self.HoverOrientation = nil

    if self.HoverAlign then
        self.HoverAlign:Destroy()
    end

    if self.HoverTargetAttachment then
        self.HoverTargetAttachment:Destroy()
    end

    if self.HoverAttachment then
        self.HoverAttachment:Destroy()
    end

    self.HoverTargetAttachment = nil
    self.HoverTargetPart = nil
    self.HoverAlign = nil
    self.HoverAttachment = nil
    self.HoverRoot = nil
    self.HoverTarget = nil
    self.HoverFacing = nil
    self.HoverHeadOffset = nil
    self.SmoothHoverPosition = nil
    self.LastHoverUpdate = 0
end

function FarmCharacterState:HoldPosition(root, position, rotation, targetPart)
    if self.HoverRoot ~= root
        or not self.HoverAlign
        or not self.HoverAlign.Parent
        or self.HoverTargetPart ~= targetPart
        or not self.HoverTargetAttachment
        or self.HoverTargetAttachment.Parent ~= targetPart
        or not self.HoverAttachment
        or self.HoverAttachment.Parent ~= root
        or not self.HoverOrientation
        or not self.HoverOrientation.Parent then

        self:ReleaseHover()
        self.HoverRoot = root

        local attachment = Instance.new("Attachment")
        attachment.Name = "LuminFarmHoverAttachment"
        attachment.Parent = root
        self.HoverAttachment = attachment

        local targetAttachment = Instance.new("Attachment")
        targetAttachment.Name = "LuminFarmHeadTarget"
        targetAttachment.Position = targetPart.CFrame:PointToObjectSpace(position)
        targetAttachment.Parent = targetPart

        self.HoverTargetAttachment = targetAttachment
        self.HoverTargetPart = targetPart

        local align = Instance.new("AlignPosition")
        align.Name = "LuminFarmHover"
        align.Mode = Enum.PositionAlignmentMode.TwoAttachment
        align.Attachment0 = attachment
        align.Attachment1 = targetAttachment
        align.ReactionForceEnabled = false
        align.ApplyAtCenterOfMass = true
        align.RigidityEnabled = true
        align.MaxForce = math.max(
            50000,
            root.AssemblyMass * workspace.Gravity * 6
        )
        align.MaxVelocity = 55
        align.Responsiveness = 18
        align.Parent = root
        self.HoverAlign = align

        local orientation = Instance.new("AlignOrientation")
        orientation.Name = "LuminFarmProne"
        orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
        orientation.Attachment0 = attachment
        orientation.RigidityEnabled = true
        orientation.MaxTorque = 1000000
        orientation.MaxAngularVelocity = 12
        orientation.Responsiveness = 18
        orientation.CFrame = rotation
        orientation.Parent = root
        self.HoverOrientation = orientation
    end

    self.HoverTargetAttachment.Position =
        targetPart.CFrame:PointToObjectSpace(position)

    self.HoverOrientation.CFrame = rotation
end

function FarmCharacterState:RememberHumanoid(hum)
    if self.Humanoids[hum] == nil then
        self.Humanoids[hum] = hum.AutoRotate
    end
end

function Farm:AttackPoint(mob)
    if not mob or not mob.Parent then return nil end

    local head = mob:FindFirstChild("Head", true)
    if head and head:IsA("BasePart") then
        return head.Position
    end

    local root = mob:FindFirstChild("HumanoidRootPart", true)
    if root and root:IsA("BasePart") then
        return root.Position
    end

    return nil
end

function Farm:SetAttackPosition(mode,height,distance,behindHeight)
    local valid={['Above head']=true,['Below feet']=true,['Behind']=true,['Above and behind']=true}
    if mode~=nil then
        if not valid[mode] then return false end
        self.AttackPosition=mode
    end
    local function clamp(value,low,high)
        local n=tonumber(value)
        if not n or n~=n then return nil end
        return math.clamp(n,low,high)
    end
    if height~=nil then self.HeadHeight=clamp(height,.5,20) or self.HeadHeight end
    if distance~=nil then self.BehindDistance=clamp(distance,1,30) or self.BehindDistance end
    if behindHeight~=nil then self.BehindHeight=clamp(behindHeight,-10,20) or self.BehindHeight end
    return true
end

function Farm:GetAttackPose(mob,facing)
    local root=mob and mob:FindFirstChild('HumanoidRootPart',true)
    local head=mob and mob:FindFirstChild('Head',true)
    if not root then return nil end
    if not head or not head:IsA('BasePart') then head=root end
    local mode=self.AttackPosition or 'Above head'
    local gap=math.clamp(tonumber(self.HeadHeight) or 3,.5,20)
    local distance=math.clamp(tonumber(self.BehindDistance) or 4,1,30)
    local lift=math.clamp(tonumber(self.BehindHeight) or 0,-10,20)
    local forward=root.CFrame.LookVector
    forward=Vector3.new(forward.X,0,forward.Z)
    forward=forward.Magnitude>.01 and forward.Unit or Vector3.new(0,0,-1)
    facing=facing or forward
    if mode=='Below feet' then
        local hum=mob:FindFirstChildOfClass('Humanoid')
        local feet=root.Position-Vector3.new(0,(hum and hum.HipHeight or 0)+root.Size.Y*.5,0)
        local pos=feet-Vector3.new(0,gap,0)
        return CFrame.lookAt(pos,pos+Vector3.yAxis,facing),root
    elseif mode=='Behind' or mode=='Above and behind' then
        local anchor=mode=='Behind' and root or head
        local pos=anchor.Position-forward*distance+Vector3.new(0,mode=='Behind' and lift or gap,0)
        return CFrame.lookAt(pos,head.Position),anchor
    end
    local pos=head.Position+Vector3.new(0,gap,0)
    return CFrame.lookAt(pos,pos-Vector3.yAxis,facing),head
end


local function farmMoveUnder(mob)
    Farm.Ctx.Modules.Teleport:CancelLocal()
    if not mob or not mob.Parent then
        return false
    end

    local targetRoot = mob:FindFirstChild("HumanoidRootPart", true)
    local targetPart = mob:FindFirstChild("Head", true)

    if not targetPart or not targetPart:IsA("BasePart") then
        targetPart = targetRoot
    end

    if not targetRoot
        or not targetPart
        or not targetPart:IsA("BasePart") then

        return false
    end

    local targetPosition = targetPart.Position
    local plr = player()
    local char = plr and plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not hrp or not hum or hum.Health <= 0 then
        return false
    end

    local poseKey=table.concat({Farm.AttackPosition,Farm.HeadHeight,Farm.BehindDistance,Farm.BehindHeight},"/")
    local changedTarget =
        FarmCharacterState.HoverPoseKey ~= poseKey
        or         FarmCharacterState.HoverTarget ~= mob
        or FarmCharacterState.HoverRoot ~= hrp

    local facing = FarmCharacterState.HoverFacing

    if changedTarget or not facing then
        local look = hrp.CFrame.LookVector
        facing = Vector3.new(look.X, 0, look.Z)
        facing =
            facing.Magnitude > 0.01
            and facing.Unit
            or Vector3.new(0, 0, -1)
    end

    local desired,anchor=Farm:GetAttackPose(mob,facing)
    if not desired then return false end
    targetPart=anchor
    local desiredPosition=desired.Position

    FarmCharacterState:RememberHumanoid(hum)

    if hum.AutoRotate then
        hum.AutoRotate = false
    end

    if changedTarget
        or (hrp.Position - desiredPosition).Magnitude > 3
        or Farm._skillHeld
        or os.clock() < (Farm._skillPoseUntil or 0) then

        pcall(function()
            hrp.CFrame = desired
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    FarmCharacterState:HoldPosition(
        hrp,
        desiredPosition,
        desired.Rotation,
        targetPart
    )

    FarmCharacterState.HoverPoseKey=poseKey
    FarmCharacterState.HoverTarget = mob
    FarmCharacterState.HoverFacing = facing

    if Farm.Dungeon
        and Farm.Dungeon.Enabled
        and type(Farm.ReleaseDungeonPreAttack) == "function" then

        pcall(Farm.ReleaseDungeonPreAttack)
    end

    return true
end

Farm.CameraStabilizer = {
    Bound = false,
    Camera = nil,
    Root = nil,
    Offset = nil,
    Rotation = nil,
    FOV = nil,
    SavedOffsets = setmetatable({}, { __mode = "k" }),
    RenderName = nil,
}

function Farm.CameraStabilizer:Capture(camera, root)
    if not camera or not root then return end

    self.Camera = camera
    self.Root = root
    self.Offset = camera.CFrame.Position - root.Position
    self.Rotation = camera.CFrame.Rotation
    self.FOV = camera.FieldOfView
end

function Farm.CameraStabilizer:Start()
    if self.Bound then return end

    local plr = player()
    if not plr then return end

    self.RenderName =
        self.RenderName
        or ("MazxhubFarmAntiShake_" .. tostring(plr.UserId))

    pcall(function()
        Farm.Ctx.Services.RunService:UnbindFromRenderStep(self.RenderName)
    end)

    self.Bound = true

    Farm.Ctx.Services.RunService:BindToRenderStep(
        self.RenderName,
        Enum.RenderPriority.Camera.Value + 50,
        function()
            if not self.Bound
                or not Farm.Enabled
                or not Farm.Ctx.State.Running then

                return
            end

            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local camera = workspace.CurrentCamera

            if not hum
                or hum.Health <= 0
                or not root
                or not camera then

                return
            end

            if self.SavedOffsets[hum] == nil then
                self.SavedOffsets[hum] = hum.CameraOffset
            end

            if hum.CameraOffset ~= Vector3.zero then
                hum.CameraOffset = Vector3.zero
            end

            if self.Camera ~= camera
                or self.Root ~= root
                or not self.Offset
                or not self.Rotation then

                self:Capture(camera, root)
                return
            end

            local mouseDelta =
                Farm.Ctx.Services.UserInputService:GetMouseDelta()

            if mouseDelta.Magnitude > 0.05 then
                self.Offset = camera.CFrame.Position - root.Position
                self.Rotation = camera.CFrame.Rotation
            end

            if self.FOV
                and math.abs(camera.FieldOfView - self.FOV) > 0.001 then

                camera.FieldOfView = self.FOV
            end

            camera.CFrame =
                CFrame.new(root.Position + self.Offset)
                * self.Rotation
        end
    )
end

function Farm.CameraStabilizer:Stop()
    if self.Bound and self.RenderName then
        pcall(function()
            Farm.Ctx.Services.RunService:UnbindFromRenderStep(
                self.RenderName
            )
        end)
    end

    self.Bound = false

    for hum, offset in pairs(self.SavedOffsets) do
        if hum.Parent then
            pcall(function()
                hum.CameraOffset = offset
            end)
        end
    end

    self.SavedOffsets = setmetatable({}, { __mode = "k" })
    self.Camera = nil
    self.Root = nil
    self.Offset = nil
    self.Rotation = nil
    self.FOV = nil
end

local function farmKeepCharacterVisible()
    if Farm._cameraConn then
        Farm._cameraConn:Disconnect()
        Farm._cameraConn = nil
    end

    Farm.CameraStabilizer:Start()

    local plr = player()
    if not plr then return end

    if not FarmCharacterState.Player then
        FarmCharacterState.Player = {
            Mode = plr.CameraMode,
            Min = plr.CameraMinZoomDistance,
            Max = plr.CameraMaxZoomDistance,
        }
    end

    plr.CameraMode = Enum.CameraMode.Classic
    plr.CameraMaxZoomDistance = 24
    plr.CameraMinZoomDistance = 7

    Farm._cameraConn =
        Farm.Ctx.Services.RunService.RenderStepped:Connect(function()
            if not Farm.Enabled then return end

            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local camera = workspace.CurrentCamera

            if camera and hum then
                if not FarmCharacterState.Cameras[camera] then
                    FarmCharacterState.Cameras[camera] = {
                        Subject = camera.CameraSubject,
                    }
                end

                if camera.CameraSubject ~= hum then
                    camera.CameraSubject = hum
                end
            end

            if char
                and (
                    FarmCharacterState.Character ~= char
                    or os.clock() >= FarmCharacterState.NextScanAt
                ) then

                FarmCharacterState.Character = char
                FarmCharacterState.NextScanAt = os.clock() + 1

                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart")
                        and FarmCharacterState.Parts[part] == nil then

                        FarmCharacterState.Parts[part] =
                            part.LocalTransparencyModifier
                    end
                end
            end

            for part in pairs(FarmCharacterState.Parts) do
                if part.Parent
                    and char
                    and part:IsDescendantOf(char) then

                    part.LocalTransparencyModifier = 0
                end
            end
        end)
end

local function farmRestoreCharacter()
    FarmCharacterState:ReleaseHover()
    Farm.CameraStabilizer:Stop()

    if Farm._cameraConn then
        Farm._cameraConn:Disconnect()
        Farm._cameraConn = nil
    end

    for hum, autoRotate in pairs(FarmCharacterState.Humanoids) do
        if hum.Parent then
            pcall(function()
                hum.AutoRotate = autoRotate
            end)
        end
    end

    for part, transparency in pairs(FarmCharacterState.Parts) do
        if part.Parent then
            pcall(function()
                part.LocalTransparencyModifier = transparency
            end)
        end
    end

    for camera, saved in pairs(FarmCharacterState.Cameras) do
        if camera.Parent
            and (saved.Subject == nil or saved.Subject.Parent) then

            pcall(function()
                camera.CameraSubject = saved.Subject
            end)
        end
    end

    local plr = player()
    local saved = FarmCharacterState.Player

    if plr and saved then
        plr.CameraMode = saved.Mode
        plr.CameraMinZoomDistance = 0.5
        plr.CameraMaxZoomDistance = saved.Max
        plr.CameraMinZoomDistance = saved.Min
    end

    FarmCharacterState.Player = nil
    FarmCharacterState.Character = nil
    FarmCharacterState.NextScanAt = 0
    FarmCharacterState.Humanoids =
        setmetatable({}, { __mode = "k" })
    FarmCharacterState.Parts =
        setmetatable({}, { __mode = "k" })
    FarmCharacterState.Cameras =
        setmetatable({}, { __mode = "k" })
end

local function farmRecoverCharacterControl()
    local plr = player()
    local char = plr and plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if root then
        pcall(function()
            root.Anchored = false
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude

        local excluded = { char }
        local npcs = workspace:FindFirstChild("Humanoids")

        if npcs then
            table.insert(excluded, npcs)
        end

        params.FilterDescendantsInstances = excluded
        params.RespectCanCollide = true

        local ground = workspace:Raycast(
            root.Position + Vector3.new(0, 12, 0),
            Vector3.new(0, -40, 0),
            params
        )

        if ground and hum then
            local safeY =
                ground.Position.Y
                + math.max(hum.HipHeight, 0)
                + root.Size.Y * 0.5
                + 0.5

            if root.Position.Y < safeY then
                local look = root.CFrame.LookVector
                local safePos = Vector3.new(
                    root.Position.X,
                    safeY,
                    root.Position.Z
                )

                pcall(function()
                    root.CFrame =
                        CFrame.lookAt(safePos, safePos + look)
                end)
            end
        end
    end

    if hum and hum.Health > 0 then
        pcall(function()
            hum.PlatformStand = false
            hum.Sit = false
            hum.AutoRotate = true
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)

        task.defer(function()
            if hum.Parent
                and hum.Health > 0
                and not hum.PlatformStand then

                pcall(function()
                    hum:ChangeState(
                        Enum.HumanoidStateType.Running
                    )
                end)
            end
        end)
    end
end

local function farmWarpToBossSpawn(name)
    Farm.Ctx.Modules.Teleport:CancelLocal()
    local position = BOSS_WARP_POSITIONS[name]
    if not position then
        return false, "no saved boss position"
    end

    local plr = player()
    local root = plr
        and plr.Character
        and plr.Character:FindFirstChild("HumanoidRootPart")

    if not root then
        return false, "character not ready"
    end

    pcall(function()
        root.CFrame = CFrame.new(position)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    return true
end

local function farmRestorePlayerHitbox()
    for part, original in pairs(Farm._hitboxOriginals) do
        if part and part.Parent then
            pcall(function()
                part.Size = original.Size
                part.Transparency = original.Transparency
                part.CanCollide = original.CanCollide
                part.Massless = original.Massless
                part.CanTouch = original.CanTouch
                part.CanQuery = original.CanQuery
            end)
        end
    end

    Farm._hitboxOriginals =
        setmetatable({}, { __mode = "k" })

    Farm._hitboxTool = nil
    Farm._hitboxNextAt = 0
end

local function farmRestoreMobHitbox()
    for part, original in pairs(Farm._mobHitboxOriginals) do
        if part and part.Parent then
            pcall(function()
                part.Size = original.Size
                part.Transparency = original.Transparency
                part.CanCollide = original.CanCollide
                part.Massless = original.Massless
                part.CanTouch = original.CanTouch
                part.CanQuery = original.CanQuery
            end)
        end
    end

    Farm._mobHitboxOriginals =
        setmetatable({}, { __mode = "k" })

    Farm._mobHitboxTarget = nil
    Farm._mobHitboxNextAt = 0
end

local function farmRestoreHitbox()
    farmRestorePlayerHitbox()
    farmRestoreMobHitbox()
end

local function farmExtendPlayerHitbox()
    local plr = player()
    local char = plr and plr.Character
    local tool = char and char:FindFirstChildOfClass("Tool")

    if tool ~= Farm._hitboxTool then
        farmRestorePlayerHitbox()
        Farm._hitboxTool = tool
    end

    if not tool
        or os.clock() < (Farm._hitboxNextAt or 0) then
        return
    end

    Farm._hitboxNextAt = os.clock() + 0.15

    local size =
        math.clamp(
            tonumber(Farm.PlayerAttackHitbox) or 30,
            5,
            100
        )

    for _, part in ipairs(tool:GetDescendants()) do
        if part:IsA("BasePart") then
            if not Farm._hitboxOriginals[part] then
                Farm._hitboxOriginals[part] = {
                    Size = part.Size,
                    Transparency = part.Transparency,
                    CanCollide = part.CanCollide,
                    Massless = part.Massless,
                    CanTouch = part.CanTouch,
                    CanQuery = part.CanQuery,
                }
            end

            pcall(function()
                part.Size = Vector3.new(size, size, size)
                part.Transparency =
                    Farm.PlayerHitboxTest and 0.65 or 1
                part.CanCollide = false
                part.Massless = true
                part.CanTouch = true
                part.CanQuery = true
            end)
        end
    end
end

local function farmExtendMobHitbox(mob)
    if mob ~= Farm._mobHitboxTarget then
        farmRestoreMobHitbox()
        Farm._mobHitboxTarget = mob
    end

    if not mob
        or not mob.Parent
        or os.clock() < (Farm._mobHitboxNextAt or 0) then
        return
    end

    Farm._mobHitboxNextAt = os.clock() + 0.15

    local size =
        math.clamp(
            tonumber(Farm.Hitbox) or 18,
            5,
            40
        )

    local root =
        mob:FindFirstChild("HumanoidRootPart", true)
        or mob:FindFirstChild("UpperTorso", true)
        or mob:FindFirstChild("Torso", true)
        or (mob:IsA("Model") and mob.PrimaryPart)

    if root and root:IsA("BasePart") then
        if not Farm._mobHitboxOriginals[root] then
            Farm._mobHitboxOriginals[root] = {
                Size = root.Size,
                Transparency = root.Transparency,
                CanCollide = root.CanCollide,
                Massless = root.Massless,
                CanTouch = root.CanTouch,
                CanQuery = root.CanQuery,
            }
        end

        pcall(function()
            root.Size = Vector3.new(size, size, size)
            root.Transparency = 1
            root.CanCollide = false
            root.Massless = true
            root.CanTouch = true
            root.CanQuery = true
        end)
    end
end

local function farmTargetAlive(target)
    if not target or not target.Parent then
        return false
    end

    local hum = target:FindFirstChildWhichIsA("Humanoid", true)
    local root = target:FindFirstChild("HumanoidRootPart", true)

    return hum ~= nil
        and hum.Health > 0
        and root ~= nil
        and root:IsA("BasePart")
end

local function farmResolveTarget()
    if Farm.ExternalResolver then
        local ok, target = pcall(Farm.ExternalResolver)
        if ok then
            return target
        end

        Farm._lastRuntimeError = tostring(target)
        return nil
    end

    if Farm.BossEnabled then
        local bossModule =
            Farm.Ctx
            and Farm.Ctx.Modules
            and Farm.Ctx.Modules.Boss

        if bossModule
            and bossModule.Enabled
            and type(bossModule.ResolveSelectedTarget) == "function" then

            local name, target =
                bossModule:ResolveSelectedTarget()

            if name then
                Farm.BossName = name
                Farm.Ctx.State.TargetName = name
            end

            -- Boss selector owns target selection while enabled.
            -- Never fall back to a stale BossName after all selections are removed.
            return target
        end

        return farmNearestByName(Farm.BossName, true)
    end

    return farmNearestByName(Farm.MobName, false)
end

function Farm:Step()
    if not self.Enabled then
        return
    end

    local now = os.clock()

    if self._target and not farmTargetAlive(self._target) then
        self._target = nil
        self._attackTarget = nil
        self.Ctx.State.Target = nil
        self._nextScanAt = 0
    end

    if not self._target and now >= (self._nextScanAt or 0) then
        self._nextScanAt = now + 0.25
        self._target = farmResolveTarget()
    end

    local target = self._target

    if self.PlayerHitboxTest then
        farmExtendPlayerHitbox()
    elseif not self.Enabled then
        farmRestorePlayerHitbox()
    end

    if not farmTargetAlive(target) then
        farmRestoreMobHitbox()
        self._attackTarget = nil
        self.Ctx.State.Target = nil
        return
    end

    farmExtendMobHitbox(target)

    if self.AutoAttack or self.PlayerHitboxTest then
        farmExtendPlayerHitbox()
    else
        farmRestorePlayerHitbox()
    end

    local moved

    if self.ExternalMover then
        local ok, result = pcall(self.ExternalMover, target)
        moved = ok and result == true

        if not ok then
            self._lastRuntimeError = tostring(result)
        end
    else
        moved = farmMoveUnder(target)
    end

    if moved then
        self._attackTarget = target
        self.Ctx.State.Target = target
    else
        self._attackTarget = nil
        self.Ctx.State.Target = nil
    end
end

local function farmStop()
    if not Farm.Ctx then return end

    Farm.Ctx:SetJobEnabled("Farm", false)

    Farm._target = nil
    Farm._attackTarget = nil
    Farm._nextScanAt = 0

    Farm.Ctx.State.Target = nil
    Farm.Ctx.State.TargetName = nil
    Farm.Ctx.State.FarmEnabled = false
    Farm.Ctx.State.FarmMode = nil
    Farm.Mode = nil
    Farm.Owner = nil

    FarmCharacterState:ReleaseHover()
    farmRestoreHitbox()
    farmRestoreCharacter()
    farmRecoverCharacterControl()

    local combat =
        Farm.Ctx.Modules
        and Farm.Ctx.Modules.Combat

    if combat and type(combat.Release) == "function" then
        pcall(function()
            combat:Release()
        end)
    end
end

local function farmStart()
    if not Farm.Ctx then return end

    Farm._nextScanAt = 0
    Farm.Ctx:SetJobEnabled("Farm", true)
end

local function callStopper(name)
    local fn = Farm[name]
    if type(fn) == "function" then
        pcall(fn)
    end
end

local function farmSet(on, owner)
    on = on == true

    local ownerName =
        type(owner) == "string"
        and owner
        or (owner == true and "Boss" or "Farm")

    if on and type(Farm.StopConflicts) == "function" then
        Farm:StopConflicts(ownerName)
    end

    farmStop()

    Farm.Enabled = on

    if not Farm.Ctx then
        return
    end

    Farm.Mode =
        on and (Farm.BossEnabled and "Boss" or "Mob") or nil
    Farm.Owner = on and ownerName or nil
    Farm.Ctx.State.FarmEnabled = on
    Farm.Ctx.State.FarmMode = Farm.Mode
    Farm.Ctx.State.TargetName =
        on and (Farm.BossEnabled and Farm.BossName or Farm.MobName) or nil

    if on then
        farmKeepCharacterVisible()
        farmStart()
    end

    if Farm.OnStateChanged then
        pcall(
            Farm.OnStateChanged,
            Farm.Enabled,
            Farm.Mode,
            Farm.Owner
        )
    end
end

function Farm:ClearExternalMode()
    self.ExternalMode = nil
    self.ExternalResolver = nil
    self.ExternalMover = nil
    self._target = nil
    self._attackTarget = nil
    self._nextScanAt = 0

    if self.Ctx then
        self.Ctx.State.Target = nil
    end
end

function Farm:StopConflicts(owner)
    local modules =
        self.Ctx
        and self.Ctx.Modules

    if not modules then return end

    if owner ~= "Boss" then
        local boss = modules.Boss
        if boss and boss.Enabled and type(boss.Stop) == "function" then
            pcall(function()
                boss:Stop()
            end)
        end
    end

    if owner ~= "Dungeon" then
        local dungeon = modules.Dungeon
        if dungeon
            and dungeon.Enabled
            and type(dungeon.SetEnabled) == "function" then
            pcall(function()
                dungeon:SetEnabled(false)
            end)
        end
    end

    if owner ~= "Raid" then
        local raid = modules.Raid
        if raid
            and raid.Enabled
            and type(raid.SetEnabled) == "function" then
            pcall(function()
                raid:SetEnabled(false)
            end)
        end
    end

    if owner ~= "Quest" then
        local quest = modules.Quest
        if quest
            and quest.Active
            and type(quest.StopAll) == "function" then
            pcall(function()
                quest:StopAll(nil)
            end)
        end
    end
end

function Farm:SetExternalMode(name, resolver, mover)
    self.ExternalMode = name
    self.ExternalResolver = resolver
    self.ExternalMover = mover
    self.BossEnabled = false
    self.Mode = name
    self.Owner = name

    self._target = nil
    self._attackTarget = nil
    self._nextScanAt = 0

    self.Enabled = true
    self.Ctx.State.FarmEnabled = true
    self.Ctx.State.FarmMode = name
    self.Ctx.State.Target = nil
    self.Ctx:SetJobEnabled("Farm", true)

    if self.OnStateChanged then
        pcall(
            self.OnStateChanged,
            self.Enabled,
            self.Mode,
            self.Owner
        )
    end
end

function Farm:StartMob(name, owner)
    self:ClearExternalMode()

    local boss = self.Ctx and self.Ctx.Modules and self.Ctx.Modules.Boss
    if boss then boss.Enabled = false end

    self.BossEnabled = false
    self.Mode = "Mob"
    self.MobName = name
    self._target = nil
    self._attackTarget = nil
    farmSet(true, owner or "Farm")
end

function Farm:StartBoss(name, owner)
    self:ClearExternalMode()
    self.BossEnabled = true
    self.Mode = "Boss"
    self.BossName = name or self.BossName
    self._target = nil
    self._attackTarget = nil
    farmSet(true, owner or "Boss")
end

function Farm:SetMob(name)
    self.MobName = name

    if self.Enabled and not self.BossEnabled then
        self._target = nil
        self._attackTarget = nil
        self._nextScanAt = 0
        self.Ctx.State.TargetName = name
    end
end

function Farm:SetBoss(name)
    self.BossName = name

    if self.Enabled and self.BossEnabled then
        self._target = nil
        self._attackTarget = nil
        self._nextScanAt = 0
        self.Ctx.State.TargetName = name
    end
end

function Farm:Init(ctx)
    self.Ctx = ctx

    local farmConfig =
        type(ctx.Config.Farm) == "table"
        and ctx.Config.Farm
        or {}

    self.HeadHeight =
        tonumber(farmConfig.HeightAboveHead)
        or self.HeadHeight

    self:SetAttackPosition(farmConfig.AttackPosition,farmConfig.HeightAboveHead,farmConfig.BehindDistance,farmConfig.BehindHeight)

    self.AttackRange =
        tonumber(farmConfig.AttackRange)
        or self.AttackRange

    self.TargetResolver = function(mode, name)
        if mode == "Boss" then
            return farmFindBossByName(name)
        end

        return farmNearestByName(name, false)
    end

    self.TargetMover = function(target)
        return farmMoveUnder(target)
    end

    self.RaidBoxPoints = RAID_BOX_POINTS
    self.BossRegions = BOSS_REGIONS
    self.BossWarpPositions = BOSS_WARP_POSITIONS

    self.Functions = {
        farmActiveFolder = farmActiveFolder,
        farmActiveFolderForName = farmActiveFolderForName,
        farmFindMobsByName = farmFindMobsByName,
        farmBossFolder = farmBossFolder,
        farmBossModel = farmBossModel,
        farmFindBossByName = farmFindBossByName,
        farmFindBoss = farmFindBoss,
        farmListMobTypes = farmListMobTypes,
        farmListBossTypes = farmListBossTypes,
        farmNearestByName = farmNearestByName,
        farmMoveUnder = farmMoveUnder,
        farmKeepCharacterVisible = farmKeepCharacterVisible,
        farmRestoreCharacter = farmRestoreCharacter,
        farmRecoverCharacterControl = farmRecoverCharacterControl,
        farmRestorePlayerHitbox = farmRestorePlayerHitbox,
        farmRestoreMobHitbox = farmRestoreMobHitbox,
        farmRestoreHitbox = farmRestoreHitbox,
        farmExtendPlayerHitbox = farmExtendPlayerHitbox,
        farmExtendMobHitbox = farmExtendMobHitbox,
        farmWarpToBossSpawn = farmWarpToBossSpawn,
        farmStart = farmStart,
        farmStop = farmStop,
        farmSet = farmSet,
    }

    -- aliases ให้ module ที่ย้ายมาทีหลังเรียกชื่อเดิมได้โดยตรง
    self.farmActiveFolder = farmActiveFolder
    self.farmActiveFolderForName = farmActiveFolderForName
    self.farmFindMobsByName = farmFindMobsByName
    self.farmBossFolder = farmBossFolder
    self.farmBossModel = farmBossModel
    self.farmFindBossByName = farmFindBossByName
    self.farmFindBoss = farmFindBoss
    self.farmListMobTypes = farmListMobTypes
    self.farmListBossTypes = farmListBossTypes
    self.farmNearestByName = farmNearestByName
    self.farmMoveUnder = farmMoveUnder
    self.farmKeepCharacterVisible = farmKeepCharacterVisible
    self.farmRestoreCharacter = farmRestoreCharacter
    self.farmRecoverCharacterControl = farmRecoverCharacterControl
    self.farmRestorePlayerHitbox = farmRestorePlayerHitbox
    self.farmRestoreMobHitbox = farmRestoreMobHitbox
    self.farmRestoreHitbox = farmRestoreHitbox
    self.farmExtendPlayerHitbox = farmExtendPlayerHitbox
    self.farmExtendMobHitbox = farmExtendMobHitbox
    self.farmWarpToBossSpawn = farmWarpToBossSpawn
    self.farmStart = farmStart
    self.farmStop = farmStop
    self.farmSet = farmSet

    self.GetSignal = function()
        if self._cachedSignal and self._cachedSignal.Parent then
            return self._cachedSignal
        end

        local now = os.clock()
        if now < (self._signalRetryAt or 0) then
            return nil
        end

        self._signalRetryAt = now + 0.5

        local replicatedStorage = game:GetService("ReplicatedStorage")
        local ok, signal = pcall(function()
            return replicatedStorage.Communication.ServerAndClient.Signals.SignalEvent.Event
        end)

        if not ok or not signal then
            local communication =
                replicatedStorage:FindFirstChild("Communication", true)
            local signalEvent =
                communication
                and communication:FindFirstChild("SignalEvent", true)

            signal = signalEvent and signalEvent:FindFirstChild("Event")
        end

        if signal and signal:IsA("RemoteEvent") then
            self._cachedSignal = signal
            return signal
        end

        return nil
    end

    self.InputBlocked = function()
        local input = ctx.Services.UserInputService

        if input:GetFocusedTextBox() then
            return true
        end

        local ok, menuOpen = pcall(function()
            return game:GetService("GuiService").MenuIsOpen
        end)

        return ok and menuOpen == true
    end

    self.CFrameOf = function(object)
        if not object then return nil end

        if object:IsA("Model") then
            local root =
                object:FindFirstChild("HumanoidRootPart")
                or object.PrimaryPart
                or object:FindFirstChildWhichIsA("BasePart", true)

            return root and root.CFrame or object:GetPivot()
        end

        if object:IsA("BasePart") then
            return object.CFrame
        end

        local part = object:FindFirstChildWhichIsA("BasePart", true)
        return part and part.CFrame or nil
    end

    self.ReleaseInputs = function()
        local combat = ctx.Modules.Combat
        local skill = ctx.Modules.Skill

        if combat and type(combat.Release) == "function" then
            pcall(function() combat:Release() end)
        end

        if skill and type(skill.Release) == "function" then
            pcall(function() skill:Release() end)
        end
    end
end

function Farm:SetPlayerHitboxTest(on)
    self.PlayerHitboxTest = on == true
    self._hitboxNextAt = 0

    if not self.PlayerHitboxTest
        and not self.Enabled then
        farmRestorePlayerHitbox()
    end
end

function Farm:Start()
    if not self.Ctx then
        error("Farm:Init(ctx) must be called before Farm:Start()")
    end

    local intervals =
        type(self.Ctx.Config.Intervals) == "table"
        and self.Ctx.Config.Intervals
        or {}

    local interval =
        tonumber(intervals.Farm)
        or 0.10

    self.Ctx:RegisterJob(
        "Farm",
        interval,
        function()
            local ok, err = pcall(function()
                self:Step()
            end)

            if not ok then
                self._attackTarget = nil
                self.Ctx.State.Target = nil
                self._lastRuntimeError = tostring(err)
            end
        end
    )

    self.Ctx:RegisterJob(
        "FarmHitbox",
        0.05,
        function()
            if self.PlayerHitboxTest then
                farmExtendPlayerHitbox()
            elseif not self.Enabled then
                farmRestorePlayerHitbox()
            end
        end
    )

    self.Ctx:SetJobEnabled("Farm", false)
end

function Farm:Stop()
    local wasBoss = self.Mode == "Boss"
    self.Enabled = false
    farmStop()

    self.ExternalMode = nil
    self.ExternalResolver = nil
    self.ExternalMover = nil

    if wasBoss then
        local boss = self.Ctx and self.Ctx.Modules and self.Ctx.Modules.Boss
        if boss then boss.Enabled = false end
    end

    if self.OnStateChanged then
        pcall(
            self.OnStateChanged,
            false,
            nil,
            nil
        )
    end
end

return Farm

]====]
BUNDLED_SOURCES["boss.lua"] = [====[
-- MazxhubModules/boss.lua
-- Boss selection ใช้ Farm engine เดิม ไม่สร้าง Heartbeat เพิ่ม

local Boss = {
    Enabled = false,
    Selected = {},
    Order = {},
    Index = 1,
    StatusStates = {},
    StatusIndex = 1,

    Names = {
        "Zuko", "Gyorei", "Stone Trainee", "Thunder Trainee",
        "Water Trainee Sabito", "Giyen", "Yahari", "Reaper",
        "Saneri", "Shinora", "Enru", "Gyutai", "Datai",
        "Obari", "Mother Bear", "Kaiden", "Akazo",
        "Serpent Trainee", "Hoyuzo", "Zentaro", "Wind Trainee",
        "Tengai", "Sound Trainee", "Sumari", "Flame Trainee",
        "Nezura", "Fujiko", "Insect Trainee",
        "Soryu Trainee Goki", "Yeti Demon", "Rengu",
    },
}

function Boss:Init(ctx)
    self.Ctx = ctx
end

function Boss:MarkDead(state, model)
    if state.Model ~= model or state.DeadAt then
        return
    end

    state.DeadAt = os.clock()
    state.Alive = false
end

function Boss:UpdateStatus(name)
    local farm = self.Ctx.Modules.Farm

    local state = self.StatusStates[name]

    if not state then
        state = {}
        self.StatusStates[name] = state
    end

    local folder =
        farm.farmBossFolder
        and farm.farmBossFolder(name)
        or nil

    state.FolderLoaded = folder ~= nil

    local model =
        farm.farmBossModel
        and farm.farmBossModel(name, true)
        or nil

    local hum =
        model
        and model:FindFirstChildWhichIsA(
            "Humanoid",
            true
        )

    local alive =
        model ~= nil
        and (not hum or hum.Health > 0)

    if alive then
        if not state.Alive then
            if state.DeadAt then
                state.RespawnSeconds =
                    os.clock() - state.DeadAt

                state.Samples =
                    (state.Samples or 0) + 1
            end

            state.LastSeenTime =
                os.date("%H:%M:%S")

            state.DeadAt = nil
        end

        state.Alive = true

        if state.Model ~= model
            or state.Humanoid ~= hum then

            if state.DeathConnection then
                state.DeathConnection:Disconnect()
            end

            state.Model = model
            state.Humanoid = hum

            state.DeathConnection =
                hum
                and hum.HealthChanged:Connect(
                    function(health)
                        if health <= 0 then
                            self:MarkDead(
                                state,
                                model
                            )
                        end
                    end
                )
                or nil
        end
    else
        if state.Alive
            and model == state.Model
            and hum
            and hum.Health <= 0 then

            self:MarkDead(state, model)
        end

        state.Alive = false
    end

    state.DeadVisible =
        model ~= nil
        and hum ~= nil
        and hum.Health <= 0

    return state
end

function Boss:Duration(seconds)
    seconds =
        math.max(
            0,
            math.ceil(
                tonumber(seconds) or 0
            )
        )

    return string.format(
        "%02d:%02d",
        math.floor(seconds / 60),
        seconds % 60
    )
end

function Boss:DescribeStatus(state)
    if not state then
        return "กำลังตรวจสอบ...", "ยังไม่มีข้อมูล", "Gold"
    end

    local detail =
        state.LastSeenTime
        and (
            "พบล่าสุด "
            .. state.LastSeenTime
        )
        or "ยังไม่พบในเซสชันนี้"

    if state.RespawnSeconds then
        detail =
            detail
            .. " | รอบที่วัดได้ ~"
            .. self:Duration(
                state.RespawnSeconds
            )
    end

    if state.Alive then
        return "เกิดแล้ว • พร้อมฟาร์ม", detail, "Mint"
    end

    if not state.FolderLoaded then
        return "ยังไม่พบข้อมูลโซน", detail, "Sub"
    end

    if state.DeadAt
        and state.RespawnSeconds then

        local remaining =
            state.DeadAt
            + state.RespawnSeconds
            - os.clock()

        if remaining > 0 then
            return
                "คาดว่าจะเกิดใน ~"
                    .. self:Duration(remaining),
                detail,
                "Gold"
        end

        return
            "ถึงเวลาประมาณแล้ว • รอตรวจพบบอส",
            detail,
            "Gold"
    end

    if state.DeadAt
        or state.DeadVisible then

        return
            "ตายแล้ว • ยังไม่ทราบเวลาเกิด",
            detail,
            "Sub"
    end

    return
        "ยังไม่พบ • ยังไม่ทราบเวลาเกิด",
        detail,
        "Sub"
end

function Boss:StatusStep()
    if #self.Names == 0 then return end

    self.StatusIndex =
        math.clamp(
            self.StatusIndex or 1,
            1,
            #self.Names
        )

    local name =
        self.Names[self.StatusIndex]

    self:UpdateStatus(name)

    self.StatusIndex =
        self.StatusIndex % #self.Names + 1
end

function Boss:Start()
    self.Ctx:RegisterJob(
        "BossStatus",
        0.05,
        function()
            self:StatusStep()
        end
    )
end

function Boss:StopStatus()
    for _, state in pairs(self.StatusStates) do
        if state.DeathConnection then
            state.DeathConnection:Disconnect()
            state.DeathConnection = nil
        end
    end
end

function Boss:SetSelected(name, enabled)
    if not name then return end

    if enabled then
        if not self.Selected[name] then
            self.Selected[name] = true
            table.insert(self.Order, name)
        end
    else
        self.Selected[name] = nil
        for index = #self.Order, 1, -1 do
            if self.Order[index] == name then
                table.remove(self.Order, index)
            end
        end
        if self.Index > #self.Order then self.Index = 1 end
    end

    local farm = self.Ctx
        and self.Ctx.Modules
        and self.Ctx.Modules.Farm

    if self.Enabled and farm then
        farm._target = nil
        farm._attackTarget = nil
        farm._nextScanAt = 0
        self.Ctx.State.Target = nil

        if #self.Order == 0 then
            self:Stop()
            return
        end

        self.Index = math.clamp(self.Index, 1, #self.Order)
        farm:SetBoss(self.Order[self.Index])
    end
end

function Boss:ClearSelection()
    self.Selected = {}
    self.Order = {}
    self.Index = 1

    if self.Enabled then
        self:Stop()
    end
end

function Boss:StartSelected()
    if #self.Order == 0 then
        return false, "เลือกบอสอย่างน้อย 1 ตัว"
    end

    self.Enabled = true
    self.Index = math.clamp(self.Index, 1, #self.Order)
    self.Ctx.Modules.Farm:StartBoss(self.Order[self.Index])
    return true
end

function Boss:Stop()
    self.Enabled = false

    local farm = self.Ctx
        and self.Ctx.Modules
        and self.Ctx.Modules.Farm

    if farm and (
        farm.Mode == "Boss"
        or self.Ctx.State.FarmMode == "Boss"
    ) then
        farm:Stop()
    end

    if self.Ctx
        and self.Ctx.State
        and self.Ctx.State.Running == false then
        self:StopStatus()
    end
end

function Boss:ResolveSelectedTarget()
    local farm = self.Ctx.Modules.Farm
    local count = #self.Order
    if count == 0 or not farm then return nil, nil end

    for offset = 0, count - 1 do
        local index = ((self.Index - 1 + offset) % count) + 1
        local name = self.Order[index]
        local target = farm.TargetResolver("Boss", name)

        if target and self.Ctx:IsAlive(target) then
            self.Index = index
            return name, target
        end
    end

    return self.Order[self.Index], nil
end

return Boss
]====]
BUNDLED_SOURCES["combat.lua"] = [====[
-- MazxhubModules/combat.lua
-- CombatRuntime ที่ย้ายออกจาก hello.txt
-- ใช้ Core scheduler กลาง และอ้าง Farm ผ่าน ctx.Modules.Farm

local Combat = {
    Enabled = true,
    Focused = true,
    Held = nil,
    EquipReadyAt = 0,
    EquipRetryAt = 0,
    NextAttackAt = 0,
    Character = nil,
    Humanoid = nil,
    Target = nil,
    LastHealth = nil,
    Driver = 1,
    PreferredDriver = nil,
    DriverHasDamage = false,
    AdaptiveInterval = 0.04,
    NoDamageAttempts = 0,
    State = "idle",
    Connections = {},
    HiddenTracks = setmetatable({}, { __mode = "k" }),
    BasicTurnPending = false,
    BasicTurnUntil = 0,
    PendingComboReset = false,
    PendingComboTarget = nil,
}

local SLOT_PREFIX = "ช่อง "

local function farm(self)
    return self.Ctx
        and self.Ctx.Modules
        and self.Ctx.Modules.Farm
end

local function inputBlocked(self)
    local input = self.Ctx.Services.UserInputService
    if input:GetFocusedTextBox() then
        return true
    end

    local ok, open = pcall(function()
        return game:GetService("GuiService").MenuIsOpen
    end)

    return ok and open == true
end

local function getSignal(self)
    local f = farm(self)
    if not f then return nil end

    if f._cachedSignal and f._cachedSignal.Parent then
        return f._cachedSignal
    end

    local now = os.clock()
    if now < (f._signalRetryAt or 0) then
        return nil
    end
    f._signalRetryAt = now + 0.5

    local rs = game:GetService("ReplicatedStorage")
    local ok, signal = pcall(function()
        return rs.Communication.ServerAndClient.Signals.SignalEvent.Event
    end)

    if not ok or not signal then
        local communication = rs:FindFirstChild("Communication", true)
        local signalEvent = communication
            and communication:FindFirstChild("SignalEvent", true)
        signal = signalEvent and signalEvent:FindFirstChild("Event")
    end

    if signal and signal:IsA("RemoteEvent") then
        f._cachedSignal = signal
        return signal
    end

    return nil
end

local function findTool(self)
    local player = self.Ctx.Player
    local character = player and player.Character
    local backpack = player and player:FindFirstChildOfClass("Backpack")

    local selected = farm(self).SelectedWeapon
    local selectedName =
        type(selected) == "string"
        and not selected:match("^" .. SLOT_PREFIX)
        and selected
        or nil

    for _, container in ipairs({ character, backpack }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool")
                    and (not selectedName or item.Name == selectedName) then
                    return item
                end
            end
        end
    end

    return nil
end

function Combat:SelectHotbarSlot(slot)
    local f = farm(self)
    local char = self.Ctx.Player and self.Ctx.Player.Character
    slot = math.floor(tonumber(slot) or 0)

    if not char or slot < 1 or slot > 5 then
        return false
    end

    local now = os.clock()
    if f._lastHotbarSelection == slot
        and f._lastHotbarCharacter == char then
        return now >= self.EquipReadyAt
    end

    if now < self.EquipRetryAt or f._skillHeld then
        return false
    end

    self:ReleaseAttack()

    local signal = getSignal(self)
    if not signal then
        self.EquipRetryAt = now + 1
        return false
    end

    local ok = pcall(function()
        signal:FireServer("Item_Equip", slot)
    end)

    if not ok then
        self.EquipRetryAt = now + 1
        return false
    end

    f._lastHotbarSelection = slot
    f._lastHotbarCharacter = char
    f._lastItemEquipAt = now
    self.EquipReadyAt = now + 0.08

    return false
end

function Combat:EquipSelectedWeapon()
    local f = farm(self)
    local char = self.Ctx.Player and self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not char or not hum or hum.Health <= 0 then
        return nil, false
    end

    local selectedSlot =
        type(f.SelectedWeapon) == "string"
        and tonumber(f.SelectedWeapon:match("^" .. SLOT_PREFIX .. "(%d+)"))
        or nil

    if selectedSlot then
        local ready = self:SelectHotbarSlot(selectedSlot)
        return char:FindFirstChildOfClass("Tool"), ready
    end

    local tool = findTool(self)
    if not tool then
        return nil, true
    end

    local now = os.clock()
    if tool.Parent ~= char then
        if now < self.EquipRetryAt or f._skillHeld then
            return nil, false
        end

        self:ReleaseAttack()
        self.EquipRetryAt = now + 0.25

        local ok = pcall(function()
            hum:EquipTool(tool)
        end)

        self.EquipReadyAt = now + (ok and 0.08 or 0.5)
        return tool, false
    end

    return tool, now >= self.EquipReadyAt
end

function Combat:TargetAlive(target)
    return self.Ctx:IsAlive(target)
end

function Combat:CombatReady()
    local f = farm(self)
    if not self.Enabled or not f or not f.Enabled or not f.AutoAttack then
        return false, "ฟาร์มยังไม่เปิด"
    end

    if f._questBusy or f._lootBusy then
        return false, "รอเควส / เก็บของ"
    end

    if inputBlocked(self) then
        return false, "รอปิดแชต / เมนูเกม"
    end

    if self.Guard and self.Guard.Holding then
        return false, "กำลังบล็อก"
    end

    local char = self.Ctx.Player and self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local target = f._attackTarget or self.Ctx.State.Target

    if not char or not hum or hum.Health <= 0 or not root then
        return false, "รอตัวละครพร้อม"
    end

    if not self:TargetAlive(target) then
        return false, "รอเป้าหมาย"
    end

    local point = f:AttackPoint(target)
    if not point then
        return false, "ไม่พบจุดโจมตี"
    end

    local range = tonumber(f.AttackRange) or 12
    if (point - root.Position).Magnitude > range then
        return false, "นอกระยะ"
    end

    return true
end

function Combat:ReleaseAttack()
    local held = self.Held
    if not held then return end

    self.Held = nil

    local f = farm(self)
    if f then f._sendingClick = false end

    pcall(function()
        if held.Tool then
            held.Tool:Deactivate()
        elseif held.Input then
            held.Input:SendMouseButtonEvent(
                held.X,
                held.Y,
                0,
                false,
                game,
                0
            )
        end
    end)
end

function Combat:RestoreSwingAnimations()
    for track, weight in pairs(self.HiddenTracks) do
        pcall(function()
            if track.IsPlaying then
                track:AdjustWeight(weight, 0.08)
            end
        end)
        self.HiddenTracks[track] = nil
    end
end

function Combat:IsBasicAttackTrack(track)
    if not track then return false end

    local animation = track.Animation
    local raw =
        tostring(track.Name or "")
        .. " "
        .. tostring(
            animation
            and animation.Name
            or ""
        )

    local name =
        raw:lower():gsub("[%s_%-]", "")

    for _, stem in ipairs({
        "m1",
        "attack",
        "basicattack",
        "lightattack",
        "slash",
        "swing",
        "punch",
        "melee",
    }) do
        if name:find(stem, 1, true) then
            return true
        end
    end

    return false
end

function Combat:HideSwingAnimation(track)
    local f = farm(self)

    if not f.NoSwingAnimation
        or f._skillHeld
        or not self:IsBasicAttackTrack(track) then
        return
    end

    pcall(function()
        if self.HiddenTracks[track] == nil then
            self.HiddenTracks[track] =
                track.WeightTarget
        end

        track:AdjustWeight(0, 0)
    end)
end

function Combat:RefreshHiddenTracks()
    local f = farm(self)

    if not f.NoSwingAnimation then
        if next(self.HiddenTracks) then
            self:RestoreSwingAnimations()
        end
        return
    end

    if f._skillHeld then return end

    local hum = self.Humanoid
    local animator =
        hum
        and hum:FindFirstChildOfClass("Animator")

    if not animator then return end

    for _, track in ipairs(
        animator:GetPlayingAnimationTracks()
    ) do
        if self:IsBasicAttackTrack(track) then
            self:HideSwingAnimation(track)
        end
    end

    for track in pairs(self.HiddenTracks) do
        pcall(function()
            if not track.IsPlaying then
                self.HiddenTracks[track] = nil
            elseif track.WeightTarget > 0 then
                track:AdjustWeight(0, 0)
            end
        end)
    end
end

function Combat:WatchAnimations()
    if self.AnimationConnection then
        self.AnimationConnection:Disconnect()
        self.AnimationConnection = nil
    end

    local hum = self.Humanoid
    local animator =
        hum
        and (
            hum:FindFirstChildOfClass("Animator")
            or hum:WaitForChild("Animator", 1)
        )

    if not animator then return end

    self.AnimationConnection =
        animator.AnimationPlayed:Connect(function(track)
            self:HideSwingAnimation(track)
        end)
end

function Combat:Release()
    self:ReleaseAttack()
    self:RestoreSwingAnimations()

    local skill = self.Ctx.Modules.Skill
    if skill and type(skill.Release) == "function" then
        pcall(function() skill:Release() end)
    end

    self.Guard:Release()
end

function Combat:ResetProgress()
    local f = farm(self)
    -- FastAttack ของเกมนี้ตอบสนองกับ M1 input ได้สม่ำเสมอกว่า Tool:Activate().
    self.Driver = f.FastAttack and 1 or (self.PreferredDriver or 1)
    self.DriverHasDamage = false
    self.LastHealth = nil
    self.AdaptiveInterval =
        math.clamp(tonumber(f.AttackInterval) or 0.06, 0.01, 0.2)
    self.NoDamageAttempts = 0
    self.NextAttackAt = 0
end

function Combat:Dispatch(tool)
    local f = farm(self)

    if inputBlocked(self) or f._skillHeld then
        self:ReleaseAttack()
        return false
    end

    local driver = self.Driver

    if f.FastAttack then
        driver = 1
    elseif tool and tool.Parent == self.Ctx.Player.Character then
        driver = 2
    else
        driver = 1
    end

    if driver == 1 then
        local camera = workspace.CurrentCamera
        if not camera then return false end

        local input = self.Ctx.Services.VirtualInputManager
        local held = {
            Input = input,
            X = camera.ViewportSize.X * 0.5,
            Y = camera.ViewportSize.Y * 0.5,
        }

        self.Held = held
        f._sendingClick = true

        local ok = pcall(function()
            input:SendMouseButtonEvent(
                held.X,
                held.Y,
                0,
                true,
                game,
                0
            )
        end)

        if not ok then
            self:ReleaseAttack()
            return false
        end

        task.delay(f.FastAttack and 0.004 or 0.015, function()
            if self.Held == held then
                self:ReleaseAttack()
            end
        end)

        return true
    end

    if driver == 2 then
        if not tool
            or tool.Parent ~= self.Ctx.Player.Character then
            return false
        end

        local held = { Tool = tool }
        self.Held = held

        local ok = pcall(function()
            tool:Activate()
        end)

        task.delay(f.FastAttack and 0.006 or 0.015, function()
            if self.Held == held then
                self:ReleaseAttack()
            end
        end)

        return ok
    end

    return false
end

Combat.Guard = {
    Holding = false,
    Until = 0,
    Input = nil,
}

function Combat.Guard:Begin(seconds)
    local owner = Combat
    if self.Holding then
        self.Until = math.max(self.Until, os.clock() + (seconds or 0.35))
        return
    end

    self.Input = owner.Ctx.Services.VirtualInputManager
    self.Holding = true
    self.Until = os.clock() + (seconds or 0.35)

    pcall(function()
        self.Input:SendKeyEvent(true, Enum.KeyCode.F, false, game)
    end)
end

function Combat.Guard:Release()
    if not self.Holding then return end

    self.Holding = false
    local input = self.Input
    self.Input = nil

    if input then
        pcall(function()
            input:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
    end
end

function Combat.Guard:Step()
    if self.Holding and os.clock() >= self.Until then
        self:Release()
    end
end

function Combat:UnbindGameComboGate()
    if self.ComboGateConnection then
        self.ComboGateConnection:Disconnect()
        self.ComboGateConnection = nil
    end

    self.ComboGateValue = nil
    self.PendingComboReset = false
    self.PendingComboTarget = nil
end

function Combat:BindGameComboGate()
    self:UnbindGameComboGate()

    local f = farm(self)
    if not f.FastAttack or not f.BypassComboGate then
        return
    end

    local scripts = self.Ctx.Player:FindFirstChild("PlayerScripts")
    local cu = scripts and scripts:FindFirstChild("CU")
    local combat = cu and cu:FindFirstChild("Combat")
    local combo = combat and combat:FindFirstChild("ComboValue")

    if not combo
        or not (
            combo:IsA("IntValue")
            or combo:IsA("NumberValue")
        ) then
        return
    end

    self.ComboGateValue = combo
    self.ComboGateConnection =
        combo:GetPropertyChangedSignal("Value"):Connect(function()
            local currentFarm = farm(self)
            if not currentFarm
                or not currentFarm.FastAttack
                or not currentFarm.BypassComboGate then
                return
            end

            if combo.Parent and combo.Value >= 5 then
                self.Guard:Begin(0.35)
                self.PendingComboReset = true
                self.PendingComboTarget =
                    currentFarm._attackTarget
                    or self.Ctx.State.Target
            end
        end)
end

function Combat:ConfirmComboDamage(target)
    local f = farm(self)

    if not f.FastAttack
        or not f.BypassComboGate
        or not self.PendingComboReset then
        return
    end

    if self.PendingComboTarget
        and target ~= self.PendingComboTarget then
        return
    end

    local combo = self.ComboGateValue
    if combo and combo.Parent then
        pcall(function()
            if combo.Value >= 5 then
                combo.Value = 1
            end
        end)
    end

    self.PendingComboReset = false
    self.PendingComboTarget = nil
    self.NextAttackAt = 0
end

function Combat:WatchCharacterHealth()
    if self.HealthConnection then
        self.HealthConnection:Disconnect()
        self.HealthConnection = nil
    end

    local char = self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    self.PlayerHealth = hum.Health
    self.HealthConnection = hum.HealthChanged:Connect(function(health)
        if self.PlayerHealth and health < self.PlayerHealth then
            if self.Guard.Holding then
                self.Guard.Until = math.max(
                    self.Guard.Until,
                    os.clock() + 0.65
                )
            end
        end
        self.PlayerHealth = health
    end)
end

function Combat:Step()
    self.Guard:Step()

    if self.Guard.Holding then
        self.State = "blocking"
        self:ReleaseAttack()
        return
    end

    local ready = self:CombatReady()
    if not ready then
        self.State = "waiting"
        self:ReleaseAttack()
        return
    end

    local f = farm(self)
    local now = os.clock()

    if now < self.NextAttackAt then
        return
    end

    local char = self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local target = f._attackTarget or self.Ctx.State.Target

    if char ~= self.Character or hum ~= self.Humanoid then
        self.Character = char
        self.Humanoid = hum
        self:WatchCharacterHealth()
        self:WatchAnimations()
        self:BindGameComboGate()
        self:ResetProgress()
    end

    local tool, equipped = self:EquipSelectedWeapon()
    if not equipped then
        self.State = "equipping"
        return
    end

    local targetHum =
        target and target:FindFirstChildWhichIsA("Humanoid", true)

    local serverConfirmedHit = false

    if targetHum then
        if self.Target ~= target then
            self.Target = target
            self.LastHealth = targetHum.Health
            self.PendingComboReset = false
            self.PendingComboTarget = nil
        elseif self.LastHealth
            and targetHum.Health < self.LastHealth then

            serverConfirmedHit = true
            self.DriverHasDamage = true
            self.NoDamageAttempts = 0
            self:ConfirmComboDamage(target)

            if f.FastAttack
                and f.AdaptiveFastAttack then

                self.AdaptiveInterval =
                    math.max(
                        0.01,
                        (
                            self.AdaptiveInterval
                            or f.AttackInterval
                            or 0.06
                        ) - 0.001
                    )
            end
        end

        self.LastHealth = targetHum.Health
    end

    self:RefreshHiddenTracks()

    local dispatched = self:Dispatch(tool)

    if dispatched then
        self.State = "attacking"

        if f.FastAttack
            and f.AdaptiveFastAttack
            and not serverConfirmedHit then

            self.NoDamageAttempts += 1

            if self.NoDamageAttempts >= 6 then
                self.AdaptiveInterval =
                    math.min(
                        0.08,
                        (
                            self.AdaptiveInterval
                            or f.AttackInterval
                            or 0.06
                        ) + 0.002
                    )

                self.NoDamageAttempts = 0
            end
        end
    else
        self.State = "retry"
        self.NoDamageAttempts += 1

        if not f.FastAttack
            and self.NoDamageAttempts >= 4 then

            self.Driver = self.Driver % 3 + 1
            self.NoDamageAttempts = 0
        end
    end

    local interval =
        f.FastAttack
        and f.AdaptiveFastAttack
        and self.AdaptiveInterval
        or tonumber(f.AttackInterval)
        or 0.06

    self.NextAttackAt =
        now + math.clamp(interval, 0.02, 0.2)
end

function Combat:Init(ctx)
    self.Ctx = ctx
    self:ResetProgress()

    local input = ctx.Services.UserInputService

    table.insert(
        self.Connections,
        input.WindowFocusReleased:Connect(function()
            self.Focused = false
            self:ReleaseAttack()
        end)
    )

    table.insert(
        self.Connections,
        input.WindowFocused:Connect(function()
            self.Focused = true
            self.NextAttackAt = 0
        end)
    )
end

function Combat:Start()
    local intervals =
        type(self.Ctx.Config.Intervals) == "table"
        and self.Ctx.Config.Intervals
        or {}

    self.Ctx:RegisterJob(
        "Combat",
        tonumber(intervals.Combat) or 0.03,
        function()
            self:Step()
        end
    )
end

function Combat:Stop()
    self.Enabled = false
    self:Release()
    self:UnbindGameComboGate()

    if self.HealthConnection then
        self.HealthConnection:Disconnect()
        self.HealthConnection = nil
    end

    if self.AnimationConnection then
        self.AnimationConnection:Disconnect()
        self.AnimationConnection = nil
    end

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self.Connections = {}
end

return Combat
]====]
BUNDLED_SOURCES["skill.lua"] = [====[
-- MazxhubModules/skill.lua
-- AutoSkills ที่ย้ายออกจาก hello.txt
-- ใช้ Core scheduler กลาง ไม่มี Heartbeat แยก

local Skill = {
    Enabled = false,
    Focused = true,
    Keys = { "Z", "X", "C", "V", "B", "N", "K" },
    Settings = {},
    Cursor = 0,
    Held = nil,
    Running = true,
    Connections = {},
}

local function farm(self)
    return self.Ctx
        and self.Ctx.Modules
        and self.Ctx.Modules.Farm
end

local function combat(self)
    return self.Ctx
        and self.Ctx.Modules
        and self.Ctx.Modules.Combat
end

function Skill:Release()
    local held = self.Held
    local f = farm(self)

    if not held then
        if f then f._skillHeld = false end
        return
    end

    self.Held = nil

    if f then
        f._skillHeld = false
        f._skillPoseUntil =
            math.max(
                f._skillPoseUntil or 0,
                os.clock() + 0.85
            )
        f._skillReadyAt = os.clock() + 0.1
    end

    local c = combat(self)
    if c then
        c.BasicTurnPending = true
        c.BasicTurnUntil = os.clock() + 0.5
    end

    pcall(function()
        held.Input:SendKeyEvent(
            false,
            held.Key,
            false,
            game
        )
    end)
end

function Skill:CanUse()
    if not self.Running or not self.Enabled then
        return false
    end

    local c = combat(self)
    if not c then return false end

    return c:CombatReady()
end

function Skill:Step()
    if not self:CanUse() then
        self:Release()
        return
    end

    local f = farm(self)
    local c = combat(self)

    if self.Held then
        local target =
            self.Held.Target
            or f._attackTarget
            or self.Ctx.State.Target

        if target
            and target.Parent
            and f.farmMoveUnder then

            f.farmMoveUnder(target)
        end

        return
    end

    local now = os.clock()

    if now < (f._skillReadyAt or 0) then
        return
    end

    if c.BasicTurnPending then
        if now < c.BasicTurnUntil then
            return
        end
        c.BasicTurnPending = false
    end

    local _, equipped = c:EquipSelectedWeapon()
    if not equipped then
        return
    end

    for offset = 1, #self.Keys do
        local index =
            (self.Cursor + offset - 1)
            % #self.Keys
            + 1

        local key = self.Keys[index]
        local setting = self.Settings[key]

        if setting
            and setting.Enabled
            and now >= (setting.NextAt or 0) then

            c:ReleaseAttack()

            self.Cursor = index
            setting.NextAt =
                now + math.max(
                    tonumber(setting.Interval) or 1,
                    0.1
                )

            local ok = pcall(function()
                local input =
                    self.Ctx.Services.VirtualInputManager

                local target =
                    f._attackTarget
                    or self.Ctx.State.Target

                local held = {
                    Input = input,
                    Key = Enum.KeyCode[key],
                    Name = key,
                    Target = target,
                }

                self.Held = held
                f._skillHeld = true
                f._skillPoseUntil =
                    os.clock() + 1.0

                if target
                    and target.Parent
                    and f.farmMoveUnder then

                    f.farmMoveUnder(target)
                end

                input:SendKeyEvent(
                    true,
                    held.Key,
                    false,
                    game
                )

                task.delay(0.06, function()
                    if self.Held ~= held then
                        return
                    end

                    if held.Target
                        and held.Target.Parent
                        and f.farmMoveUnder then

                        f.farmMoveUnder(held.Target)
                    end

                    self:Release()

                    if held.Target
                        and held.Target.Parent
                        and f.Enabled
                        and f.farmMoveUnder then

                        f.farmMoveUnder(held.Target)
                    end
                end)
            end)

            if not ok then
                self:Release()

                for _, entry in pairs(self.Settings) do
                    entry.NextAt = now + 2
                end

                if self.OnError then
                    pcall(self.OnError)
                end
            end

            return
        end
    end
end

function Skill:SetEnabled(on)
    self.Enabled = on == true
    self:Release()

    for _, setting in pairs(self.Settings) do
        setting.NextAt = 0
    end
end

function Skill:SetKeyEnabled(key, enabled)
    local setting = self.Settings[key]
    if not setting then return end

    setting.Enabled = enabled == true
    setting.NextAt = 0

    if not setting.Enabled
        and self.Held
        and self.Held.Name == key then

        self:Release()
    end
end

function Skill:SetInterval(key, seconds)
    local setting = self.Settings[key]
    if not setting then return end

    setting.Interval =
        math.max(tonumber(seconds) or 1, 0.1)

    setting.NextAt = 0
end

function Skill:Init(ctx)
    self.Ctx = ctx
    self.Running = true
    self.Settings = {}
    self.Cursor = 0

    local configured =
        type(ctx.Config.Skill) == "table"
        and ctx.Config.Skill
        or {}

    for _, key in ipairs(self.Keys) do
        local data =
            type(configured[key]) == "table"
            and configured[key]
            or {}

        self.Settings[key] = {
            Enabled = data.Enabled == true,
            Interval =
                math.max(
                    tonumber(data.Interval) or 1,
                    0.1
                ),
            NextAt = 0,
        }
    end

    local input = ctx.Services.UserInputService

    table.insert(
        self.Connections,
        input.WindowFocusReleased:Connect(function()
            -- เหมือน hello.txt รุ่นล่าสุด:
            -- ไม่ยกเลิก skill เมื่อ Roblox เสีย focus
            self.Focused = false
        end)
    )

    table.insert(
        self.Connections,
        input.WindowFocused:Connect(function()
            self.Focused = true
        end)
    )
end

function Skill:Start()
    local intervals =
        type(self.Ctx.Config.Intervals) == "table"
        and self.Ctx.Config.Intervals
        or {}

    self.Ctx:RegisterJob(
        "Skill",
        tonumber(intervals.Skill) or 0.05,
        function()
            self:Step()
        end
    )
end

function Skill:Stop()
    self.Running = false
    self.Enabled = false
    self:Release()

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    self.Connections = {}
    self.OnError = nil
end

return Skill
]====]
BUNDLED_SOURCES["player.lua"] = [====[
-- MazxhubModules/player.lua
-- Player movement / environment / invisible utilities migrated from hello.txt

local Player = {
    SpeedEnabled = false,
    JumpEnabled = false,
    NoClipEnabled = false,
    FlyEnabled = false,
    InvisibleEnabled = false,
    GodModeEnabled = false,
    _godForceField = nil,

    WalkSpeed = 40,
    JumpPower = 100,
    FlySpeed = 120,

    FullBrightEnabled = false,
    NoFogEnabled = false,

    _humanoid = nil,
    _originalWalkSpeed = nil,
    _originalJumpPower = nil,
    _originalJumpHeight = nil,
    _originalAutoRotate = nil,
    _originalCollisions = setmetatable({}, { __mode = "k" }),
    _invisibleParts = setmetatable({}, { __mode = "k" }),
    _invisibleVisuals = setmetatable({}, { __mode = "k" }),
    _invisibleHumanoid = nil,
    _highlight = nil,
    _nextInvisibleScan = 0,
    _fogOriginals = nil,
    _fullBrightEffect = nil,
}

local function character(self)
    local char = self.Ctx.Player and self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return char, hum, root
end

function Player:RememberHumanoid(hum)
    if not hum or self._humanoid == hum then return end
    self._humanoid = hum
    self._originalWalkSpeed = hum.WalkSpeed
    self._originalJumpPower = hum.JumpPower
    self._originalJumpHeight = hum.JumpHeight
    self._originalAutoRotate = hum.AutoRotate
end

function Player:SetSpeed(on)
    self.SpeedEnabled = on == true
    local _, hum = character(self)
    if not hum then return end

    self:RememberHumanoid(hum)

    if self.SpeedEnabled then
        pcall(function()
            hum.WalkSpeed = self.WalkSpeed
        end)
    elseif self._originalWalkSpeed ~= nil then
        pcall(function()
            hum.WalkSpeed = self._originalWalkSpeed
        end)
    end
end

function Player:SetJump(on)
    self.JumpEnabled = on == true
    local _, hum = character(self)
    if not hum then return end

    self:RememberHumanoid(hum)

    if self.JumpEnabled then
        pcall(function()
            hum.JumpPower = self.JumpPower
            hum.JumpHeight = math.max(7.2, self.JumpPower / 7)
        end)
    else
        if self._originalJumpPower ~= nil then
            pcall(function() hum.JumpPower = self._originalJumpPower end)
        end
        if self._originalJumpHeight ~= nil then
            pcall(function() hum.JumpHeight = self._originalJumpHeight end)
        end
    end
end

function Player:SetNoClip(on)
    self.NoClipEnabled = on == true

    if self.NoClipEnabled then return end

    for part, original in pairs(self._originalCollisions) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = original
            end)
        end
    end

    self._originalCollisions = setmetatable({}, { __mode = "k" })
end

function Player:SetFly(on)
    if on then self.Ctx.Modules.Teleport:Cancel() end
    self.FlyEnabled = on == true

    local _, hum, root = character(self)

    if hum then
        self:RememberHumanoid(hum)

        pcall(function()
            hum.AutoRotate = self.FlyEnabled
                and false
                or (
                    self._originalAutoRotate ~= nil
                    and self._originalAutoRotate
                    or true
                )
        end)
    end

    if root and not self.FlyEnabled then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

function Player:FlyStep()
    if not self.FlyEnabled then return end

    local farm = self.Ctx.Modules.Farm
    if farm and farm.Enabled then
        return
    end

    local _, hum, root = character(self)
    local camera = workspace.CurrentCamera

    if not hum
        or hum.Health <= 0
        or not root
        or not camera then
        return
    end

    self:RememberHumanoid(hum)
    pcall(function() hum.AutoRotate = false end)

    local input = self.Ctx.Services.UserInputService
    local look = camera.CFrame.LookVector
    local right = camera.CFrame.RightVector

    local forward = Vector3.new(look.X, 0, look.Z)
    local side = Vector3.new(right.X, 0, right.Z)

    if forward.Magnitude > 0.001 then forward = forward.Unit end
    if side.Magnitude > 0.001 then side = side.Unit end

    local move = Vector3.zero

    if input:IsKeyDown(Enum.KeyCode.W) then move += forward end
    if input:IsKeyDown(Enum.KeyCode.S) then move -= forward end
    if input:IsKeyDown(Enum.KeyCode.D) then move += side end
    if input:IsKeyDown(Enum.KeyCode.A) then move -= side end
    if input:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end

    if input:IsKeyDown(Enum.KeyCode.LeftControl)
        or input:IsKeyDown(Enum.KeyCode.RightControl) then
        move -= Vector3.yAxis
    end

    if move.Magnitude > 1 then
        move = move.Unit
    end

    pcall(function()
        root.AssemblyLinearVelocity = move * self.FlySpeed
        root.AssemblyAngularVelocity = Vector3.zero

        if forward.Magnitude > 0.001 then
            root.CFrame = CFrame.lookAt(
                root.Position,
                root.Position + forward
            )
        end
    end)
end

function Player:NoClipStep()
    if not self.NoClipEnabled then return end

    local char = self.Ctx.Player and self.Ctx.Player.Character
    if not char then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if self._originalCollisions[part] == nil then
                self._originalCollisions[part] = part.CanCollide
            end

            if part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end

function Player:MovementStep()
    local _, hum = character(self)
    if not hum then return end

    self:RememberHumanoid(hum)

    if self.SpeedEnabled then
        hum.WalkSpeed = self.WalkSpeed
    end

    if self.JumpEnabled then
        hum.JumpPower = self.JumpPower
        hum.JumpHeight = math.max(7.2, self.JumpPower / 7)
    end
end

function Player:SetFullBright(on)
    self.FullBrightEnabled = on == true
    local lighting = game:GetService("Lighting")

    if not self.FullBrightEnabled then
        local effect =
            self._fullBrightEffect
            or lighting:FindFirstChild("MazxhubFullBright")

        if effect then
            effect:Destroy()
        end

        self._fullBrightEffect = nil
        return
    end

    local effect = lighting:FindFirstChild("MazxhubFullBright")

    if effect and not effect:IsA("ColorCorrectionEffect") then
        effect:Destroy()
        effect = nil
    end

    if not effect then
        effect = Instance.new("ColorCorrectionEffect")
        effect.Name = "MazxhubFullBright"
        effect.Parent = lighting
    end

    effect.Enabled = true
    effect.Brightness = 0.22
    effect.Contrast = -0.08
    effect.Saturation = 0.02
    effect.TintColor = Color3.fromRGB(255, 255, 255)

    self._fullBrightEffect = effect
end

function Player:SetNoFog(on)
    local lighting = game:GetService("Lighting")
    self.NoFogEnabled = on == true

    if not self.NoFogEnabled then
        local originals = self._fogOriginals
        if not originals then return end

        for instance, value in pairs(originals) do
            if typeof(instance) == "Instance" and instance.Parent then
                if instance:IsA("Atmosphere") then
                    instance.Density = value
                elseif instance:IsA("Clouds") then
                    instance.Cover = value
                end
            end
        end

        if originals.FogEnd then lighting.FogEnd = originals.FogEnd end
        if originals.FogStart then lighting.FogStart = originals.FogStart end
        if originals.FogColor then lighting.FogColor = originals.FogColor end

        self._fogOriginals = nil
        return
    end

    if not self._fogOriginals then
        local originals = {}

        for _, item in ipairs(lighting:GetChildren()) do
            if item:IsA("Atmosphere") then
                originals[item] = item.Density
            elseif item:IsA("Clouds") then
                originals[item] = item.Cover
            end
        end

        originals.FogEnd = lighting.FogEnd
        originals.FogStart = lighting.FogStart
        originals.FogColor = lighting.FogColor
        self._fogOriginals = originals
    end

    for instance in pairs(self._fogOriginals) do
        if typeof(instance) == "Instance" and instance.Parent then
            if instance:IsA("Atmosphere") then
                instance.Density = 0
            elseif instance:IsA("Clouds") then
                instance.Cover = 0
            end
        end
    end

    lighting.FogEnd = 1e6
    lighting.FogStart = 1e6
    lighting.FogColor = Color3.fromRGB(255, 255, 255)
end

function Player:SetAtmosphereRemoved(on)
    local lighting = game:GetService("Lighting")

    for _, item in ipairs(lighting:GetChildren()) do
        if item:IsA("Atmosphere") then
            item.Density = on and 0 or 0.3
        end
    end
end

function Player:SetFogEnd(value)
    if self.NoFogEnabled then return end
    game:GetService("Lighting").FogEnd = value
end

function Player:RestoreInvisible()
    for part, state in pairs(self._invisibleParts) do
        if part and part.Parent then
            pcall(function()
                part.Transparency = state.Transparency
                part.CastShadow = state.CastShadow
            end)
        end
    end

    for visual, transparency in pairs(self._invisibleVisuals) do
        if visual and visual.Parent then
            pcall(function()
                visual.Transparency = transparency
            end)
        end
    end

    if self._invisibleHumanoid
        and self._invisibleHumanoid.Humanoid
        and self._invisibleHumanoid.Humanoid.Parent then

        local saved = self._invisibleHumanoid

        pcall(function()
            saved.Humanoid.NameDisplayDistance =
                saved.NameDisplayDistance
            saved.Humanoid.HealthDisplayDistance =
                saved.HealthDisplayDistance
        end)
    end

    if self._highlight then
        pcall(function() self._highlight:Destroy() end)
    end

    self._highlight = nil
    self._invisibleHumanoid = nil
    self._invisibleParts = setmetatable({}, { __mode = "k" })
    self._invisibleVisuals = setmetatable({}, { __mode = "k" })
end

function Player:InvisibleStep()
    if not self.InvisibleEnabled then return end

    local now = os.clock()
    if now < self._nextInvisibleScan then return end
    self._nextInvisibleScan = now + 0.2

    local char = self.Ctx.Player and self.Ctx.Player.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")

    if hum and not self._invisibleHumanoid then
        self._invisibleHumanoid = {
            Humanoid = hum,
            NameDisplayDistance = hum.NameDisplayDistance,
            HealthDisplayDistance = hum.HealthDisplayDistance,
        }

        hum.NameDisplayDistance = 0
        hum.HealthDisplayDistance = 0
    end

    for _, object in ipairs(char:GetDescendants()) do
        if object:IsA("BasePart") then
            if self._invisibleParts[object] == nil then
                self._invisibleParts[object] = {
                    Transparency = object.Transparency,
                    CastShadow = object.CastShadow,
                }
            end

            object.Transparency = 1
            object.CastShadow = false
        elseif object:IsA("Decal") or object:IsA("Texture") then
            if self._invisibleVisuals[object] == nil then
                self._invisibleVisuals[object] = object.Transparency
            end
            object.Transparency = 1
        end
    end

    if not self._highlight or self._highlight.Parent ~= char then
        if self._highlight then
            self._highlight:Destroy()
        end

        local highlight = Instance.new("Highlight")
        highlight.Name = "MazxhubInvisibleGhost"
        highlight.Adornee = char
        highlight.FillColor = Color3.fromRGB(180, 220, 255)
        highlight.FillTransparency = 0.72
        highlight.OutlineColor = Color3.fromRGB(215, 235, 255)
        highlight.OutlineTransparency = 0.35
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = char
        self._highlight = highlight
    end
end

function Player:SetInvisible(on)
    self.InvisibleEnabled = on == true
    self._nextInvisibleScan = 0

    if not self.InvisibleEnabled then
        self:RestoreInvisible()
    else
        self:InvisibleStep()
    end
end

function Player:SetGodMode(on)
    self.GodModeEnabled = on == true
    if not self.GodModeEnabled and self._godForceField then
        self._godForceField:Destroy()
        self._godForceField = nil
    end
    if self.GodModeEnabled then self:GodModeStep() end
end

function Player:GodModeStep()
    if not self.GodModeEnabled then return end
    local char, hum = character(self)
    if not char or not hum or hum.Health <= 0 then return end

    -- This affects local Humanoid state. Server damage rules remain authoritative.
    if hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
    end

    if not self._godForceField or self._godForceField.Parent ~= char then
        if self._godForceField then self._godForceField:Destroy() end
        local force = Instance.new("ForceField")
        force.Name = "MazaSpaceGodMode"
        force.Visible = false
        force.Parent = char
        self._godForceField = force
    end
end

function Player:Step()
    self:MovementStep()
    self:NoClipStep()
    self:FlyStep()
    self:InvisibleStep()
    self:GodModeStep()
end

function Player:Init(ctx)
    self.Ctx = ctx
end

function Player:Start()
    self.Ctx:RegisterJob("Player", 0.03, function()
        self:Step()
    end)
end

function Player:Stop()
    self.SpeedEnabled = false
    self.JumpEnabled = false
    self:SetFly(false)
    self:SetNoClip(false)
    self:SetInvisible(false)
    self:SetGodMode(false)
    self:SetFullBright(false)
    self:SetNoFog(false)

    local _, hum = character(self)
    if hum and hum == self._humanoid then
        if self._originalWalkSpeed ~= nil then
            pcall(function() hum.WalkSpeed = self._originalWalkSpeed end)
        end
        if self._originalJumpPower ~= nil then
            pcall(function() hum.JumpPower = self._originalJumpPower end)
        end
        if self._originalJumpHeight ~= nil then
            pcall(function() hum.JumpHeight = self._originalJumpHeight end)
        end
        if self._originalAutoRotate ~= nil then
            pcall(function() hum.AutoRotate = self._originalAutoRotate end)
        end
    end
end

return Player

]====]
BUNDLED_SOURCES["teleport.lua"] = [====[
-- MazxhubModules/teleport.lua
-- NPC/player teleport helpers migrated from hello.txt

local Teleport = {
    Root = { "Debree", "Regions", "Windy Peak", "StationaryNpcs" },

    RootsByNPC = {
        ["Baitmonger Nori"] = { "Debree", "Regions", "Hidden Mist Village", "StationaryNpcs" },
        ["Blacksmith Togane"] = { "Debree", "Regions", "Hidden Mist Village", "StationaryNpcs" },
        ["Betty"] = { "Debree", "Regions", "Bamboo Grove", "StationaryNpcs" },
        ["Kuro"] = { "Debree", "Regions", "Bamboo Grove", "StationaryNpcs" },
        ["Serpent Trainer Obari"] = { "Debree", "Regions", "Misc", "StationaryNpcs" },
        ["Stone Trainer Gyorei"] = { "Debree", "Regions", "Misc", "StationaryNpcs" },
        ["Thunder Trainer Zentaro"] = { "Debree", "Regions", "Misc", "StationaryNpcs" },
        ["Weaver Hatsu"] = { "Debree", "Regions", "Misc", "StationaryNpcs" },
        ["Elara"] = { "Debree", "Regions", "Mistfall Harbor", "StationaryNpcs" },
        ["Rin"] = { "Debree", "Regions", "Mistfall Harbor", "StationaryNpcs" },
        ["Refiner Hagane"] = { "Debree", "Regions", "Hidden Mist Village", "StationaryNpcs" },
        ["Stonemason Tobei"] = { "Debree", "Regions", "Hidden Mist Village", "StationaryNpcs" },
        ["Yagane"] = { "Debree", "Regions", "Hidden Mist Village", "StationaryNpcs" },
        ["Tailor Omi"] = { "Debree", "Regions", "Misc", "StationaryNpcs" },
        ["Tom"] = { "Debree", "Regions", "Bamboo Grove", "StationaryNpcs" },
        ["Chaka"] = { "Debree", "Regions", "Bamboo Grove", "StationaryNpcs" },
        ["Wagwan"] = { "Debree", "Regions", "Bamboo Grove", "StationaryNpcs" },
        ["Demon Slayer Mitsu"] = { "Debree", "Regions", "Iceveil Valley", "StationaryNpcs" },
    },

    NPCs = {
        "Kazu", "Kona", "Krue", "Lucy", "MoldySugar", "Noote", "Raze", "Rika",
        "Tailor Omi", "Tom", "Chaka", "Wagwan", "Betty", "Kuro",
        "Serpent Trainer Obari", "Stone Trainer Gyorei", "Thunder Trainer Zentaro",
        "Weaver Hatsu", "Baitmonger Nori", "Refiner Hagane", "Yagane", "Blacksmith Togane",
        "Liv", "Rin", "Elara", "Ginzo", "Estate Worker Niko", "Jugg",
        "Dock Master Sofen", "Alchemist Meku", "Angler Runo", "Shady Individual Rooyi",
        "Ren", "Shiori", "Old Trapper Retsu", "Wounded Slayer Tomoi", "Demon Delroy",
        "Winter Store Rep Lynx", "Iceveil Guard Shiro", "Shrine Messenger Akio",
        "Sound Trainer Tengai", "Demon Slayer Mitsu", "Stonemason Tobei", "Demon Mokuro",
    },

    Positions = {
        ["Weaver Hatsu"] = Vector3.new(2281.17, 812.50, 14.75),
        ["Baitmonger Nori"] = Vector3.new(1643.24, 672.25, -190.13),
        ["Refiner Hagane"] = Vector3.new(1865.27, 696.71, -434.26),
        Yagane = Vector3.new(1814.00, 661.55, -516.00),
        ["Blacksmith Togane"] = Vector3.new(1732.07, 696.53, -764.55),
        Betty = Vector3.new(714.00, 1123.70, -808.00),
        Wagwan = Vector3.new(723.76, 1021.70, -801.98),
        Liv = Vector3.new(657.36, 1021.20, 139.75),
        Rin = Vector3.new(432.25, 1020.50, 73.10),
        Elara = Vector3.new(427.82, 943.58, 507.45),
        Ginzo = Vector3.new(273.80, 944.00, 528.19),
        ["Estate Worker Niko"] = Vector3.new(260.66, 876.00, 803.78),
        Jugg = Vector3.new(487.70, 876.50, 1007.79),
        ["Dock Master Sofen"] = Vector3.new(-160.81, 798.75, 703.29),
        ["Alchemist Meku"] = Vector3.new(-138.15, 798.90, 518.74),
        ["Angler Runo"] = Vector3.new(-561.10, 798.87, 683.70),
        ["Shady Individual Rooyi"] = Vector3.new(-772.94, 967.07, -8.56),
        Ren = Vector3.new(-1609.65, 289.00, 10.49),
        Shiori = Vector3.new(-1814.34, 314.31, -101.07),
        Krue = Vector3.new(-425.49, 1243.50, -952.49),
        Rika = Vector3.new(-497.04, 1249.66, -1176.81),
        Noote = Vector3.new(-515.55, 1245.40, -1251.24),
        Kazu = Vector3.new(-626.00, 1245.00, -1138.00),
        Lucy = Vector3.new(-615.50, 1261.00, -1177.50),
        Raze = Vector3.new(-594.00, 1245.08, -1095.00),
        MoldySugar = Vector3.new(-701.60, 1245.69, -982.73),
        Kona = Vector3.new(-791.60, 1262.57, -1130.91),
        ["Serpent Trainer Obari"] = Vector3.new(36.96, 1307.50, -1179.50),
        Chaka = Vector3.new(471.00, 1148.50, -1260.00),
        Tom = Vector3.new(507.20, 1123.92, -970.30),
        ["Old Trapper Retsu"] = Vector3.new(440.00, 1179.00, -1504.01),
        ["Wounded Slayer Tomoi"] = Vector3.new(485.34, 1225.07, -1813.00),
        ["Demon Delroy"] = Vector3.new(139.61, 1256.72, -1911.30),
        ["Winter Store Rep Lynx"] = Vector3.new(-91.65, 1353.67, -2705.57),
        ["Iceveil Guard Shiro"] = Vector3.new(-106.78, 1351.50, -2498.56),
        ["Shrine Messenger Akio"] = Vector3.new(-207.07, 1352.19, -2423.00),
        ["Sound Trainer Tengai"] = Vector3.new(464.88, 1487.80, -3272.80),
        ["Demon Slayer Mitsu"] = Vector3.new(-824.30, 1384.00, -2537.85),
        Kuro = Vector3.new(667.27, 1123.70, -1100.76),
        ["Stone Trainer Gyorei"] = Vector3.new(2578.58, 1091.50, -828.40),
        ["Thunder Trainer Zentaro"] = Vector3.new(1970.18, 1662.50, -609.81),
        ["Stonemason Tobei"] = Vector3.new(1876.00, 661.55, -206.00),
        ["Demon Mokuro"] = Vector3.new(-1948.43, 30.71, 374.31),
    },
}

function Teleport:FindNPC(name)
    local node = workspace

    for _, segment in ipairs(self.RootsByNPC[name] or self.Root) do
        node = node and node:FindFirstChild(segment)
        if not node then return nil end
    end

    return node:FindFirstChild(name)
end

function Teleport:CFrameOf(object)
    if not object then return nil end

    local root = object:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root.CFrame + Vector3.new(0, 3, 0)
    end

    if object:IsA("Model") then
        return object:GetPivot() + Vector3.new(0, 3, 0)
    end

    if object:IsA("BasePart") then
        return object.CFrame + Vector3.new(0, 3, 0)
    end

    return nil
end

function Teleport:Destination(name)
    local live = self:CFrameOf(self:FindNPC(name))
    if live then return live end

    local position = self.Positions[name]
    return position
        and CFrame.new(position + Vector3.new(0, 3, 0))
        or nil
end

-- Shared Soft-Warp: one session per character, cancellable and non-yielding Heartbeat.
Teleport.HoldTime=5
Teleport.StepCount=16
Teleport.StepDelay=0.035
Teleport.SnapDistance=4

function Teleport:Cancel(owner)
    for char,s in pairs(self.Warps or {}) do
        if not owner or s.Owner==owner then
            s.Cancelled=true;s.Done=true;s.Error="warp cancelled"
            self.Warps[char]=nil
        end
    end
end

function Teleport:Request(goal,owner,key,char)
    if self.Ctx.State and self.Ctx.State.Running==false then return false,"stopped" end
    char=char or self.Ctx.Player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health<=0 then return false,"character not ready" end
    if typeof(goal)=="Vector3" then goal=CFrame.new(goal) end
    if typeof(goal)~="CFrame" then return false,"expected Vector3 or CFrame" end
    self.Warps=self.Warps or {}
    owner=owner or "Manual"
    local old=self.Warps[char]
    if key and old and old.Owner==owner and old.Key==key and old.Root==root then
        old.Goal=goal
        if old.Done then
            old.HoldLeft=self.HoldTime
            if (root.Position-goal.Position).Magnitude>self.SnapDistance then
                old.Start=root.CFrame;old.Step=0;old.Elapsed=0;old.Done=false
            end
        end
        return true,old
    end
    if old then old.Cancelled=true;old.Done=true;old.Error="superseded by another warp" end
    local s={Character=char,Root=root,Humanoid=hum,Owner=owner,Key=key,Start=root.CFrame,Goal=goal,
        Step=0,Elapsed=0,Done=false,HoldLeft=self.HoldTime,Local=char==self.Ctx.Player.Character}
    self.Warps[char]=s
    hum.Sit=false;hum.PlatformStand=false
    return true,s
end

function Teleport:WarpStep(dt)
    for char,s in pairs(self.Warps or {}) do
        if not char.Parent or not s.Root.Parent or not s.Humanoid.Parent or s.Humanoid.Health<=0
            or (s.Local and self.Ctx.Player.Character~=char) then
            s.Done=true;s.Cancelled=true;s.Error="character changed or died";self.Warps[char]=nil
        else
            local ok,err=pcall(function()
                if not s.Done then
                    s.Elapsed=s.Elapsed+dt
                    while s.Elapsed>=self.StepDelay and s.Step<self.StepCount do
                        s.Elapsed=s.Elapsed-self.StepDelay;s.Step=s.Step+1
                        local t=s.Step/self.StepCount
                        s.Root.CFrame=s.Start:Lerp(s.Goal,t*t*(3-2*t))
                    end
                    if s.Step>=self.StepCount then
                        s.Root.CFrame=s.Goal;s.Done=true;s.HoldLeft=self.HoldTime
                    end
                else
                    s.HoldLeft=s.HoldLeft-dt
                    if s.HoldLeft<=0 then self.Warps[char]=nil;return end
                    if (s.Root.Position-s.Goal.Position).Magnitude>self.SnapDistance then
                        s.Root.CFrame=s.Goal
                        s.Humanoid.PlatformStand=false
                    end
                end
                s.Root.AssemblyLinearVelocity=Vector3.zero
                s.Root.AssemblyAngularVelocity=Vector3.zero
            end)
            if not ok then s.Done=true;s.Error=tostring(err);self.Warps[char]=nil end
        end
    end
end

function Teleport:SoftGoOwned(owner,goal)
    local ok,s=self:Request(goal,owner)
    if not ok then return false,s end
    while not s.Done do task.wait() end
    return not s.Cancelled and not s.Error,s.Error
end

function Teleport:CancelLocal()
    local char=self.Ctx.Player.Character
    local s=self.Warps and self.Warps[char]
    if s then
        s.Cancelled=true;s.Done=true;s.Error="replaced by instant movement"
        self.Warps[char]=nil
    end
end

function Teleport:GoOwned(owner,cframe)
    self:CancelLocal()
    if typeof(cframe)=="Vector3" then cframe=CFrame.new(cframe) end
    local char = self.Ctx.Player and self.Ctx.Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not char or not root or not hum or not cframe then
        return false, "character not ready"
    end

    local ok, err = pcall(function()
        hum.PlatformStand = false
        hum.Sit = false
        char:PivotTo(cframe)
        root.CFrame = cframe
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end)

    if not ok then
        return false, tostring(err)
    end

    return true
end

function Teleport:Go(goal) return self:GoOwned("Manual",goal) end

function Teleport:Here()
    local char=self.Ctx.Player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false,"character not ready" end
    local ok,s=self:Request(root.CFrame,"Manual")
    if ok then s.Done=true;s.HoldLeft=self.HoldTime end
    return ok
end

function Teleport:SetHold(seconds)
    local n=tonumber(seconds)
    if not n or n~=n or n<0 or n==math.huge then return false,"invalid duration" end
    self.HoldTime=n;return true
end

function Teleport:GoNPC(name)
    local destination = self:Destination(name)
    if not destination then
        return false, "ไม่พบพิกัด " .. tostring(name)
    end
    return self:SoftGoOwned("NPC",destination)
end

function Teleport:PlayerNames()
    local names = {}

    for _, plr in ipairs(self.Ctx.Services.Players:GetPlayers()) do
        if plr ~= self.Ctx.Player then
            table.insert(names, plr.Name)
        end
    end

    table.sort(names, function(a, b)
        return a:lower() < b:lower()
    end)

    return names
end

function Teleport:GoPlayer(name)
    local target = self.Ctx.Services.Players:FindFirstChild(name)
    if not target or target == self.Ctx.Player then
        return false, "ไม่พบผู้เล่น"
    end

    local targetChar = target.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

    if not targetRoot then
        return false, "ไม่พบตัวละครผู้เล่น"
    end

    return self:Go(targetRoot.CFrame * CFrame.new(0, 2.5, 5))
end

function Teleport:BringPlayer(name)
    local target = self.Ctx.Services.Players:FindFirstChild(name)

    if not target or target == self.Ctx.Player then
        return false, "ไม่พบผู้เล่น"
    end

    local myChar = self.Ctx.Player.Character
    local myRoot =
        myChar
        and myChar:FindFirstChild("HumanoidRootPart")

    local targetChar = target.Character
    local targetRoot =
        targetChar
        and targetChar:FindFirstChild("HumanoidRootPart")

    local targetHum =
        targetChar
        and targetChar:FindFirstChildOfClass("Humanoid")

    if not myRoot then
        return false, "ตัวละครของเรายังไม่พร้อม"
    end

    if not targetChar
        or not targetRoot
        or not targetHum
        or targetHum.Health <= 0 then
        return false, "ตัวละครผู้เล่นยังไม่พร้อม"
    end

    local destination =
        myRoot.CFrame * CFrame.new(0, 0, -4)

    for _ = 1, 4 do
        if not targetChar.Parent
            or not targetRoot.Parent then
            break
        end

        pcall(function()
            targetChar:PivotTo(destination)
            targetRoot.CFrame = destination
            targetRoot.AssemblyLinearVelocity =
                Vector3.zero
            targetRoot.AssemblyAngularVelocity =
                Vector3.zero
        end)

        task.wait(0.05)
    end

    return true
end

function Teleport:Spawn()
    local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
    if not spawn then return false, "ไม่พบ Spawn" end
    return self:Go(spawn.CFrame + Vector3.new(0, 3, 0))
end

function Teleport:Sky()
    local char = self.Ctx.Player and self.Ctx.Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false, "character not ready" end
    return self:Go(root.CFrame + Vector3.new(0, 100, 0))
end

function Teleport:Ground()
    local char = self.Ctx.Player and self.Ctx.Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false, "character not ready" end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }

    local result = workspace:Raycast(
        root.Position,
        Vector3.new(0, -500, 0),
        params
    )

    if not result then return false, "ไม่พบพื้น" end

    return self:Go(CFrame.new(result.Position + Vector3.new(0, 3, 0)))
end

function Teleport:Init(ctx)
    self.Ctx = ctx
    self.Warps={}
    if self.WarpConnection then self.WarpConnection:Disconnect() end
    self.WarpConnection=ctx.Services.RunService.Heartbeat:Connect(function(dt) self:WarpStep(dt) end)
    -- Same dot-call API as the supplied Warp script.
    self.to=function(pos) return self:Go(pos) end
    self.here=function() return self:Here() end
    self.setHold=function(seconds) return self:SetHold(seconds) end
end

function Teleport:Stop()
    self:Cancel()
    if self.WarpConnection then self.WarpConnection:Disconnect();self.WarpConnection=nil end
end

return Teleport

]====]
BUNDLED_SOURCES["quest.lua"] = [====[
-- MazxhubModules/quest.lua
-- Story/collection quests migrated from hello.txt.
-- Keeps one quest active at a time and reuses Farm / Teleport / Combat modules.

local Quest = {
    Active = nil,
    Connections = {},
    Quests = {},
}

local function farm(self)
    return self.Ctx.Modules.Farm
end

local function combat(self)
    return self.Ctx.Modules.Combat
end

local function teleport(self)
    return self.Ctx.Modules.Teleport
end

local function signal(self)
    local f = farm(self)
    return f and f.GetSignal and f.GetSignal() or nil
end

local function blocked(self)
    local f = farm(self)
    return f and f.InputBlocked and f.InputBlocked() or false
end

local function aliveCharacter(self)
    local char = self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return char, hum, root
end

local function cframeOf(self, object)
    local f = farm(self)
    return f and f.CFrameOf and f.CFrameOf(object) or nil
end

local AUTO_BOSS_QUESTS = {
    Zuko = {
        Text = "Ill take the bandit boss(Lv 7)",
        RequiredKills = 1,
        TargetName = "Zuko",
        NPCName = "Krue",
    },
    ["Mother Bear"] = {
        Text = "Ill fell the Mother Bear(Lv 18)",
        RequiredKills = 1,
        TargetName = "Mother Bear",
        NPCName = "Tom",
    },
    Kaiden = {
        Text = "Ill deal with Kaiden(Lv 34)",
        RequiredKills = 1,
        TargetName = "Kaiden",
        NPCName = "Chaka",
    },
    Hoyuzo = {
        Text = "I will take care of Hoyuzo(Lv 50)",
        RequiredKills = 1,
        TargetName = "Hoyuzo",
        NPCName = "Wagwan",
    },
}

local AUTO_MOB_QUESTS = {
    ["bandit"] = {
        Text = "Ill take 3 bandits",
        RequiredKills = 3,
        TargetName = "Bandit",
        NPCName = "Krue",
    },
    ["bear cub"] = {
        Text = "Ill drive the bears back(Lv 10)",
        RequiredKills = 4,
        TargetName = "Bear Cub",
        NPCName = "Tom",
    },
    ["kaiden subordinate"] = {
        Text = "Ill clear out his subordinates(Lv 26)",
        RequiredKills = 4,
        TargetName = "Kaiden Subordinate",
        NPCName = "Chaka",
    },
    ["hoyuzo subordinate"] = {
        Text = "I will clear out his guards(Lv 40)",
        RequiredKills = 4,
        TargetName = "Hoyuzo Subordinate",
        NPCName = "Wagwan",
    },
    ["beast born demon"] = {
        Text = "Ill drive them off(Lv 47)",
        RequiredKills = 3,
        TargetName = "Beast Born Demon",
        NPCName = "Rin",
    },
    ["ice profound demon"] = {
        Text = "Ill drive back the frost(Lv 105)",
        RequiredKills = 9,
        TargetName = "Ice Profound Demon",
        NPCName = "Demon Slayer Mitsu",
    },
    ["fire profound demon"] = {
        Text = "Ill put out the blaze(Lv 115)",
        RequiredKills = 8,
        TargetName = "Fire Profound Demon",
        NPCName = "Demon Slayer Mitsu",
    },
}

local HUNTER_POSITIONS = {
    Vael = Vector3.new(-5660.24, 14.65, 2350.78),
    Rika = Vector3.new(-6999.99, 44.46, 2430.47),
    Mizuto = Vector3.new(-5722.31, 54.67, 1482.68),
    Lavato = Vector3.new(-4961.18, 40.50, 3014.45),
    Levi = Vector3.new(-5195.18, 40.50, 1006.45),
    Steve = Vector3.new(-3439.75, 41.56, 1966.10),
}

local HUNTER_VAEL_FIGHT =
    Vector3.new(-5537.75732421875, 33.781185150146484, 2526.718505859375)

local HUNTER_LOST_FIGHT =
    Vector3.new(-4954.16, -142.50, 2017.48)

local HUNTER_RETURN_POINT =
    Vector3.new(-5721.0107421875, 42.61933517456055, 1439.741455078125)

local HUNTER_DUNGEON_ROUTE = {
    { Position = Vector3.new(-5727.59521484375, 42.619346618652344, 1439.687255859375), Hold = 3 },
    { Position = Vector3.new(-120.85259246826172, 892.726318359375, 3855.791015625), Hold = 5 },
    { Position = Vector3.new(-212.2955780029297, 929.7340087890625, 3578.82275390625), Hold = 5 },
    { Position = Vector3.new(-122.9549789428711, 950.2499389648438, 3282.32470703125), Hold = 5 },
    { Position = Vector3.new(-235.82069396972656, 970.2499389648438, 3422.9482421875), Hold = 5 },
    { Position = Vector3.new(-36.726383209228516, 950.2499389648438, 3297.615234375), Hold = 5 },
    { Position = Vector3.new(490.1626892089844, 947.6620483398438, 3237.6872558593), Hold = 5 },
    { Position = Vector3.new(211.13230895996094, 1018.998779296875, 2959.263671875), Hold = 0 },
}

local HUNTER_LAVATO_PATH = {
    Vector3.new(-6617.11083984375, 40.49899673461914, 2519.365478515625),
    Vector3.new(-5499.5615234375, 40.498992919921875, 1605.9420166015625),
}

local HUNTER_LEVI_PATH = {
    Vector3.new(-3819.544921875, 40.499996185302734, 1628.1923828125),
    Vector3.new(-5190.208984375, 40.49899673461914, 1011.4854736328125),
}

local HUNTER_HAND_DEMON_CENTER =
    Vector3.new(-3430.24, 71.04, 2678.84)

function Quest:SetStatus(q, text)
    q.StatusText = text
    q.Status = text

    if q.Label and q.Label.Parent then
        q.Label.Text = text
    end

    if q.OnStatus then
        pcall(q.OnStatus, text)
    end
end

function Quest:StopAll(except)
    for name, q in pairs(self.Quests) do
        if name ~= except and q.Enabled then
            self:SetEnabled(name, false)
        end
    end
end

function Quest:GoNpc(name)
    local tp = teleport(self)
    if not tp then return false end

    local liveNpc =
        type(tp.FindNPC) == "function"
        and tp:FindNPC(name)
        or nil

    local destination =
        liveNpc
        and tp:CFrameOf(liveNpc)
        or tp:Destination(name)

    if not destination then
        return false
    end

    local ok =
        tp:SoftGoOwned("Quest",
            destination
            * CFrame.new(0, 0, -3)
        )

    if not ok then
        return false
    end

    if not liveNpc
        and type(tp.FindNPC) == "function" then

        return tp:FindNPC(name) ~= nil
    end

    return true
end

function Quest:Talk()
    local event = signal(self)
    if not event then return false end
    return pcall(function()
        event:FireServer("NpcTalking", "Ended")
    end)
end

function Quest:AddQuest(text)
    local event = signal(self)
    if not event then return false end
    return pcall(function()
        event:FireServer("AddQuest", text)
    end)
end

function Quest:PressT(seconds)
    local input = self.Ctx.Services.VirtualInputManager
    input:SendKeyEvent(true, Enum.KeyCode.T, false, game)
    task.delay(seconds or 1, function()
        pcall(function()
            input:SendKeyEvent(false, Enum.KeyCode.T, false, game)
        end)
    end)
end

function Quest:SetEnabled(name, on)
    local q = self.Quests[name]
    if not q then return false end

    on = on == true

    if q.Enabled == on then
        return true
    end

    if on then
        self:StopAll(name)

        local f = farm(self)
        if f and type(f.StopConflicts) == "function" then
            f:StopConflicts("Quest")
        end
        if f.Enabled then
            f:Stop()
        end

        local c = combat(self)
        if c and c.Release then
            c:Release()
        end

        self.Active = name
    else
        -- Dedicated quests can temporarily own Farm/Combat and death
        -- connections. Release those resources immediately when unticked.
        if q.Watch and q.Watch.Connection then
            pcall(function()
                q.Watch.Connection:Disconnect()
            end)
        end
        q.Watch = nil

        if q.BossWatch then
            pcall(function()
                q.BossWatch:Disconnect()
            end)
            q.BossWatch = nil
        end

        local f = farm(self)
        if f and (
            q.FarmOwned == true
            or f.ExternalMode == "HunterExam"
            or (
                (name == "Kazu" or name == "Bear")
                and q.Phase == "fight"
            )
        ) then
            pcall(function()
                f:Stop()
            end)
        end
        q.FarmOwned = false

        if self.Active == name then
            self.Active = nil
        end
    end

    if name=="UnlockMarket" then
        self:ReleaseMarketKey(q)
        q.Deadline=nil
    end
    if not on then teleport(self):Cancel("Quest") end
    q.Enabled = on

    if q.OnEnabled then
        pcall(q.OnEnabled, on)
    end

    q.Phase = q.StartPhase or "npc"
    q.NextAt = 0
    q.Attempts = 0
    q.Character = nil
    q.Root = nil

    if name == "Pages" then
        q.Index = 1
        q.Collected = 0
        q.Current = nil
    elseif name == "Kazu" then
        q.Kills = 0
        q.Stage = q.Stage or "new"
        q.Watch = nil
    elseif name == "Bear" then
        q.Kills = 0
        q.TomRuns = 0
        q.Watch = nil
    elseif name == "HunterExam" then
        q.Stage = 1
        q.Kills = 0
        q.ManualReady = false
        q.FarmOwned = false
        q.RouteIndex = 1
        q.PathIndex = 1
        q.SawSurvivalTarget = false
        q.BossDead = false
        q.BossDeathPosition = nil
        q.LootStarted = false
        q.RestoreLootEnabled = nil
        q.Watch = nil
        q.BossWatch = nil
    end

    self:SetStatus(
        q,
        on
            and (q.OnText or (name .. " • ON"))
            or (name .. " • OFF")
    )

    return true
end

function Quest:BettyStep(q, now)
    local _, hum, root = aliveCharacter(self)
    if not hum or hum.Health <= 0 or not root then
        self:SetStatus(q, "Betty • รอตัวละครพร้อม")
        return
    end

    if blocked(self) then return end
    if now < q.NextAt then return end

    if q.Phase == "npc" then
        if not self:GoNpc("Betty") then
            q.NextAt = now + 1
            return
        end
        q.Phase = "talk"
        q.NextAt = now + 0.4
        self:SetStatus(q, "กำลังไปหา Betty")
        return
    end

    if q.Phase == "talk" then
        if self:Talk() then
            q.Phase = "accept"
            q.NextAt = now + 0.2
        end
        return
    end

    if q.Phase == "accept" then
        if self:AddQuest("Ill look for it(Lv 10)") then
            q.Phase = "gem"
            q.NextAt = now + 0.5
            self:SetStatus(q, "ส่งคำขอเควส Betty แล้ว")
        end
        return
    end

    local gem = workspace:FindFirstChild("Gemstone1")
    local cf = gem and cframeOf(self, gem)

    if q.Phase == "gem" then
        if not cf then
            q.NextAt = now + 1
            self:SetStatus(q, "รอ Gemstone1")
            return
        end

        q.Current = gem
        teleport(self):GoOwned("Quest",
            CFrame.lookAt(
                cf.Position + Vector3.new(0, 2, 2),
                cf.Position
            )
        )
        q.Phase = "press"
        q.NextAt = now + 0.35
        return
    end

    if q.Phase == "press" then
        self:PressT(1)
        q.Attempts += 1
        q.Phase = "verify"
        q.NextAt = now + 1.2
        self:SetStatus(q, "กำลังเก็บ Gemstone1")
        return
    end

    if q.Phase == "verify" then
        if not q.Current
            or not q.Current.Parent
            or workspace:FindFirstChild("Gemstone1") ~= q.Current then

            q.Phase = "return"
            q.NextAt = now + 0.4
            return
        end

        if q.Attempts >= 3 then
            q.NextAt = now + 1
            self:SetStatus(
                q,
                "ยังยืนยันการเก็บไม่ได้ รอ Gemstone1 เปลี่ยนหรือหาย"
            )
            return
        end

        q.Phase = "press"
        q.NextAt = now + 0.4
        return
    end

    if q.Phase == "return" then
        if self:GoNpc("Betty") then
            self:Talk()
            q.Current = nil
            q.Attempts = 0
            q.Phase = "gem"
            q.NextAt = now + 1
            self:SetStatus(q, "กลับ Betty แล้ว รอ Gemstone1 ชิ้นใหม่")
        end
    end
end

function Quest:DeliveryStep(q, now)
    local _, hum = aliveCharacter(self)
    if not hum or hum.Health <= 0 then
        self:SetStatus(q, "Quest 3 • รอตัวละครพร้อม")
        return
    end

    if blocked(self) or now < q.NextAt then return end

    if q.Phase == "source" then
        if self:GoNpc("MoldySugar") then
            q.Phase = "talkSource"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "talkSource" then
        if self:Talk() then
            q.Phase = "accept"
            q.NextAt = now + 0.2
        end
        return
    end

    if q.Phase == "accept" then
        if self:AddQuest("Ill deliver the package") then
            q.Phase = "elara"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "elara" then
        if self:GoNpc("Elara") then
            q.Phase = "equip"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "equip" then
        local event = signal(self)
        if event then
            pcall(function()
                event:FireServer("Item_Equip", 2)
            end)
            q.Phase = "talkElara"
            q.NextAt = now + 0.5
        end
        return
    end

    if q.Phase == "talkElara" then
        if self:Talk() then
            q.Phase = "return"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "return" then
        if self:GoNpc("MoldySugar") then
            self:Talk()
            self:SetEnabled("Delivery", false)
            self:SetStatus(q, "กลับ MoldySugar แล้ว • DONE")
        end
    end
end

function Quest:PagesStep(q, now)
    local _, hum = aliveCharacter(self)
    if not hum or hum.Health <= 0 then
        self:SetStatus(q, "Quest 4 • รอตัวละครพร้อม")
        return
    end

    if blocked(self) or now < q.NextAt then return end

    if q.Phase == "npc" then
        if self:GoNpc("Kona") then
            q.Phase = "talk"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "talk" then
        if self:Talk() then
            q.Phase = "accept"
            q.NextAt = now + 0.2
        end
        return
    end

    if q.Phase == "accept" then
        if self:AddQuest("Ill find the pages") then
            q.Phase = "page"
            q.NextAt = now + 0.4
            self:SetStatus(q, "Quest 4 • Kona • 0/5")
        end
        return
    end

    if q.Phase == "page" then
        if q.Index > 5 then
            q.Phase = "return"
            return
        end

        local page = workspace:FindFirstChild("Lost Page" .. q.Index)
        local cf = page and cframeOf(self, page)

        if not cf then
            q.NextAt = now + 0.8
            self:SetStatus(q, "Quest 4 • รอ Lost Page" .. q.Index)
            return
        end

        q.Current = page
        teleport(self):GoOwned("Quest",
            CFrame.lookAt(
                cf.Position + Vector3.new(0, 2, 2),
                cf.Position
            )
        )
        q.Phase = "press"
        q.NextAt = now + 0.35
        return
    end

    if q.Phase == "press" then
        self:PressT(1)
        q.Attempts = (q.Attempts or 0) + 1
        q.Phase = "verify"
        q.NextAt = now + 1.2
        return
    end

    if q.Phase == "verify" then
        if not q.Current or not q.Current:IsDescendantOf(workspace) then
            q.Collected += 1
            q.Index += 1
            q.Attempts = 0
            q.Current = nil
            q.Phase = q.Index > 5 and "return" or "page"
            q.NextAt = now + 0.3

            self:SetStatus(
                q,
                "Quest 4 • Kona • "
                    .. tostring(q.Collected)
                    .. "/5"
            )
            return
        end

        if (q.Attempts or 0) >= 4 then
            local failedName = "Lost Page" .. tostring(q.Index)
            self:SetEnabled("Pages", false)
            self:SetStatus(
                q,
                "Quest 4 • ยังยืนยันการเก็บ "
                    .. failedName
                    .. " ไม่ได้"
            )
            return
        end

        q.Phase = "page"
        q.NextAt = now + 0.9
        return
    end

    if q.Phase == "return" then
        if self:GoNpc("Kona") then
            self:Talk()
            self:SetEnabled("Pages", false)
            self:SetStatus(q, "กลับ Kona แล้ว • DONE")
        end
    end
end

function Quest:WatchFarmTarget(q, required)
    local f = farm(self)
    local target = f._target or self.Ctx.State.Target

    if not target or not target.Parent then
        q.Watch = nil
        return
    end

    if q.Watch and q.Watch.Target == target then
        return
    end

    if q.Watch and q.Watch.Connection then
        q.Watch.Connection:Disconnect()
    end

    local hum = target:FindFirstChildWhichIsA("Humanoid", true)
    if not hum then return end

    local record = {
        Target = target,
        Humanoid = hum,
    }

    record.Connection = hum.Died:Connect(function()
        if not q.Enabled then return end
        q.Kills += 1
        self:SetStatus(
            q,
            tostring(q.Name or "Quest")
                .. " • "
                .. tostring(q.Kills)
                .. "/"
                .. tostring(required)
        )
    end)

    q.Watch = record
end

function Quest:KazuStep(q, now)
    if now < q.NextAt or blocked(self) then return end

    if q.Phase == "npc" then
        if self:GoNpc("Kazu") then
            q.Phase = "talk"
            q.NextAt = now + 0.35
        end
        return
    end

    if q.Phase == "talk" then
        if self:Talk() then
            self:AddQuest("Ill help clear them out")
            q.Phase = "fight"
            q.NextAt = now + 0.4
            farm(self):StartMob("*Civilian*", "Quest")
            self:SetStatus(q, "Quest 1 • *Civilian* • 0/4")
        end
        return
    end

    if q.Phase == "fight" then
        self:WatchFarmTarget(q, 4)

        if q.Kills >= 4 then
            farm(self):Stop()
            q.Phase = "noote"
            q.NextAt = now + 0.3
        end
        return
    end

    if q.Phase == "noote" then
        if self:GoNpc("Noote") then
            self:Talk()
            self:AddQuest("Ill get this letter delivered")
            q.Phase = "chaka"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "chaka" then
        if self:GoNpc("Chaka") then
            self:Talk()
            q.Phase = "return"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "return" then
        if self:GoNpc("Kazu") then
            self:Talk()
            self:SetEnabled("Kazu", false)
            self:SetStatus(q, "Quest 1 • DONE")
        end
    end
end

function Quest:BearStep(q, now)
    if now < q.NextAt or blocked(self) then return end

    if q.Phase == "lucy" then
        if self:GoNpc("Lucy") then
            self:Talk()
            self:AddQuest("Ill restock the pantry(Lv 10)")
            q.Phase = "tom"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "tom" then
        if self:GoNpc("Tom") then
            local talked = self:Talk()
            local accepted = talked
                and self:AddQuest(
                    "Ill drive the bears back(Lv 10)"
                )

            if not accepted then
                q.NextAt = now + 0.8
                return
            end

            local event = signal(self)
            if event then
                pcall(function()
                    event:FireServer(
                        "QuestProgress",
                        "Ill restock the pantry(Lv 10)",
                        "Go talk to Tom"
                    )
                end)
            end

            q.Kills = 0
            q.TomRuns += 1
            q.Phase = "fight"
            q.NextAt = now + 0.4
            farm(self):StartMob("Bear Cub", "Quest")
            self:SetStatus(
                q,
                "Quest 5 • Tom รอบ "
                    .. tostring(q.TomRuns)
                    .. " • Bear Cub 0/4"
            )
        end
        return
    end

    if q.Phase == "fight" then
        self:WatchFarmTarget(q, 4)

        if q.Kills >= 4 then
            farm(self):Stop()
            q.Phase = "returnLucy"
            q.NextAt = now + 0.3
        end
        return
    end

    if q.Phase == "returnLucy" then
        if self:GoNpc("Lucy") then
            self:Talk()

            if q.TomRuns < 2 then
                q.Phase = "tom"
                q.Kills = 0
                q.NextAt = now + 0.4
            else
                self:SetEnabled("Bear", false)
                self:SetStatus(q, "Quest 5 • DONE")
            end
        end
    end
end

function Quest:DungeonUnlockStep(q, now)
    if now < q.NextAt or blocked(self) then return end

    if q.Deadline and now >= q.Deadline then
        self:SetEnabled("DungeonUnlock", false)
        self:SetStatus(q, "หมดเวลารอ Dungeon — ลองเปิดใหม่")
        return
    end

    if q.Phase == "npc" then
        if self:GoNpc("Blacksmith Togane") then
            q.Phase = "talk"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "talk" then
        if self:Talk() then
            q.Phase = "accept"
            q.NextAt = now + 0.2
        end
        return
    end

    if q.Phase == "accept" then
        if self:AddQuest("Ill find the forge(Lv 65)") then
            q.Phase = "forge"
            q.NextAt = now + 0.5
        end
        return
    end

    if q.Phase == "forge" then
        teleport(self):GoOwned("Quest",CFrame.new(q.Forge))
        q.Phase = "press"
        q.NextAt = now + 0.6
        return
    end

    if q.Phase == "press" then
        self:PressT(1.5)
        self:SetEnabled("DungeonUnlock", false)
        self:SetStatus(q, "กด T แล้ว — ตรวจผลปลดล็อกในเกม")
    end
end

function Quest:HunterFire(...)
    local event = signal(self)
    if not event then return false end

    local args = { ... }
    return pcall(function()
        event:FireServer(table.unpack(args))
    end)
end

function Quest:HunterNpc(name)
    local debree = workspace:FindFirstChild("Debree")
    local regions = debree and debree:FindFirstChild("Regions")
    local finalSelection =
        regions and regions:FindFirstChild("Final Selection")
    local stationary =
        finalSelection and finalSelection:FindFirstChild("StationaryNpcs")

    return stationary and stationary:FindFirstChild(name) or nil
end

function Quest:HunterGoNpc(name)
    local object = self:HunterNpc(name)
    local destination = object and cframeOf(self, object)

    if not destination then
        local fallback = HUNTER_POSITIONS[name]
        destination =
            fallback
            and CFrame.new(fallback + Vector3.new(0, 3, 0))
            or nil
    end

    if not destination then return false end

    local stand =
        destination * CFrame.new(0, 0, -3)

    return teleport(self):SoftGoOwned("Quest",
        CFrame.lookAt(
            stand.Position,
            destination.Position
        )
    )
end

function Quest:HunterObject(name)
    return workspace:FindFirstChild(name, true)
end

function Quest:HunterCollect(q, name, holdTime, nextPhase, now)
    local object = self:HunterObject(name)
    local cf = object and cframeOf(self, object)

    if not cf then
        q.NextAt = now + 0.8
        self:SetStatus(q, "สอบนักล่า • รอ " .. tostring(name))
        return false
    end

    local arrived=teleport(self):GoOwned("Quest",
        CFrame.lookAt(
            cf.Position + Vector3.new(0, 2.5, 2.5),
            cf.Position
        )
    )

    if not arrived or not q.Enabled then return false end
    local seconds = math.max(tonumber(holdTime) or 1, 0.1)
    self:PressT(seconds)
    q.Phase = nextPhase
    q.NextAt = now + seconds + 0.45

    self:SetStatus(
        q,
        "สอบนักล่า • กำลังเก็บ " .. tostring(name)
    )

    return true
end

function Quest:HunterActiveFolder()
    local humanoids = workspace:FindFirstChild("Humanoids")
    local regions = humanoids and humanoids:FindFirstChild("Regions")
    local finalSelection =
        regions and regions:FindFirstChild("Final Selection")

    return finalSelection
        and finalSelection:FindFirstChild("ActiveNpcs")
        or nil
end

function Quest:HunterFindTarget(center, radius, predicate)
    local folder = self:HunterActiveFolder()
    if not folder then return nil end

    local best
    local bestDistance = math.huge
    local seen = {}

    for _, hum in ipairs(folder:GetDescendants()) do
        if hum:IsA("Humanoid") and hum.Health > 0 then
            local model = hum.Parent

            if model
                and not seen[model]
                and model:IsA("Model") then

                seen[model] = true

                local root =
                    model:FindFirstChild(
                        "HumanoidRootPart",
                        true
                    )
                    or model.PrimaryPart
                    or model:FindFirstChildWhichIsA(
                        "BasePart",
                        true
                    )

                if root and root:IsA("BasePart") then
                    local allowed =
                        predicate == nil
                        or predicate(model, hum, root) == true

                    if allowed then
                        local distance =
                            center
                            and (root.Position - center).Magnitude
                            or 0

                        if (not radius or distance <= radius)
                            and distance < bestDistance then
                            best = model
                            bestDistance = distance
                        end
                    end
                end
            end
        end
    end

    return best
end

function Quest:HunterBossTarget()
    local add =
        self:HunterFindTarget(
            HUNTER_HAND_DEMON_CENTER,
            350,
            function(model)
                return model.Name ~= "Hand Demon"
            end
        )

    if add then return add end

    return self:HunterFindTarget(
        HUNTER_HAND_DEMON_CENTER,
        450,
        function(model)
            return model.Name == "Hand Demon"
        end
    )
end

function Quest:HunterStartFarm(q, resolver, statusText)
    if q.FarmOwned then return end

    local f = farm(self)
    if not f then return end

    f.AutoAttack = true
    f:SetExternalMode(
        "HunterExam",
        resolver,
        function(target)
            return f.farmMoveUnder
                and f.farmMoveUnder(target)
                or false
        end
    )

    q.FarmOwned = true

    if statusText then
        self:SetStatus(q, statusText)
    end
end

function Quest:HunterStopFarm(q)
    local f = farm(self)

    if q.Watch and q.Watch.Connection then
        pcall(function()
            q.Watch.Connection:Disconnect()
        end)
    end
    q.Watch = nil

    if f and (
        q.FarmOwned
        or f.ExternalMode == "HunterExam"
    ) then
        pcall(function()
            f:Stop()
        end)
    end

    q.FarmOwned = false
end

function Quest:ContinueHunterExam()
    local q = self.Quests and self.Quests.HunterExam

    if not q or not q.Enabled then
        return false, "สอบนักล่ายังไม่ได้เปิด"
    end

    if q.Phase ~= "manual" then
        return false, "ตอนนี้ยังไม่ถึงช่วง Manual"
    end

    q.ManualReady = true
    q.NextAt = 0
    self:SetStatus(q, "สอบนักล่า • ทำ Manual เสร็จแล้ว • ไปต่อ")
    return true, "ไปต่อแล้ว"
end

function Quest:HunterExamEarly(q, now)
    local phase = q.Phase

    if phase == "manual" then
        if q.ManualReady then
            q.Phase = "mizuto"
            q.NextAt = 0
            self:SetStatus(q, "สอบนักล่า • ไปหา Mizuto")
        end
        return true
    end

    if phase ~= "rem"
        and phase ~= "remTalk"
        and phase ~= "fruitGrapes"
        and phase ~= "fruitApple"
        and phase ~= "fruitBanana"
        and phase ~= "remReturn"
        and phase ~= "vael"
        and phase ~= "vaelFight"
        and phase ~= "vaelReturn"
        and phase ~= "katana"
        and phase ~= "klien"
        and phase ~= "rika"
        and phase ~= "bandage"
        and phase ~= "bandageBuy"
        and phase ~= "klienTreat" then
        return false
    end

    if blocked(self) or now < (q.NextAt or 0) then
        return true
    end

    if phase == "rem" then
        if self:HunterGoNpc("Rem") then
            q.Phase = "remTalk"
            q.NextAt = now + 0.4
            self:SetStatus(q, "สอบนักล่า • Rem")
        else
            q.NextAt = now + 1
        end
        return true
    end

    if phase == "remTalk" then
        if self:Talk()
            and self:HunterFire(
                "QuestProgress",
                "Locate Rem",
                "Find Rem"
            ) then
            q.Phase = "fruitGrapes"
            q.NextAt = now + 0.25
        else
            q.NextAt = now + 0.6
        end
        return true
    end

    if phase == "fruitGrapes" then
        self:HunterCollect(
            q,
            "Grapes",
            1.2,
            "fruitApple",
            now
        )
        return true
    end

    if phase == "fruitApple" then
        self:HunterCollect(
            q,
            "Apple1",
            1.2,
            "fruitBanana",
            now
        )
        return true
    end

    if phase == "fruitBanana" then
        self:HunterCollect(
            q,
            "Banana1",
            1.2,
            "remReturn",
            now
        )
        return true
    end

    if phase == "remReturn" then
        if self:HunterGoNpc("Rem") then
            self:Talk()
            self:HunterFire(
                "QuestProgress",
                "Help Rem",
                "Return to Rem"
            )
            q.Phase = "vael"
            q.NextAt = now + 0.4
        else
            q.NextAt = now + 1
        end
        return true
    end

    if phase == "vael" then
        if self:HunterGoNpc("Vael") then
            self:Talk()
            self:HunterFire(
                "QuestProgress",
                "Find Vael",
                "Find Vael"
            )
            q.Kills = 0
            q.Phase = "vaelFight"
            q.NextAt = now + 0.35
        else
            q.NextAt = now + 1
        end
        return true
    end

    if phase == "vaelFight" then
        self:HunterStartFarm(
            q,
            function()
                return self:HunterFindTarget(
                    HUNTER_VAEL_FIGHT,
                    150
                )
            end,
            "สอบนักล่า • ฆ่ามอนรอบ Vael 0/6"
        )

        self:WatchFarmTarget(q, 6)

        if q.Kills >= 6 then
            self:HunterStopFarm(q)
            q.Phase = "vaelReturn"
            q.NextAt = now + 0.3
        end
        return true
    end

    if phase == "vaelReturn" then
        if self:HunterGoNpc("Vael") then
            q.Phase = "katana"
            q.NextAt = now + 0.35
        else
            q.NextAt = now + 1
        end
        return true
    end

    if phase == "katana" then
        self:HunterCollect(
            q,
            "Nichirin Katana1",
            1,
            "klien",
            now
        )
        return true
    end

    if phase == "klien" then
        if self:HunterGoNpc("Klien") then
            self:Talk()
            self:HunterFire(
                "QuestProgress",
                "Speak with Klien",
                "Return to Klien"
            )
            q.Phase = "rika"
            q.NextAt = now + 0.4
        else
            q.NextAt = now + 1
        end
        return true
    end

    if phase == "rika" then
        if self:HunterGoNpc("Rika") then
            self:Talk()
            self:HunterFire(
                "QuestProgress",
                "Find Rika",
                "Find Rika"
            )
            q.Phase = "bandage"
            q.NextAt = now + 0.35
        else
            q.NextAt = now + 1
        end
        return true
    end

    if phase == "bandage" then
        local rika = self:HunterNpc("Rika")
        local shop =
            rika and rika:FindFirstChild("Rika's Shop")
        local bandage =
            shop and shop:FindFirstChild("Bandage", true)
            or self:HunterObject("Bandage")
        local cf = bandage and cframeOf(self, bandage)

        if not cf then
            q.NextAt = now + 0.8
            self:SetStatus(q, "สอบนักล่า • รอ Bandage")
            return true
        end

        teleport(self):GoOwned("Quest",
            CFrame.lookAt(
                cf.Position + Vector3.new(0, 2.5, 2),
                cf.Position
            )
        )
        self:PressT(1)
        q.Phase = "bandageBuy"
        q.NextAt = now + 1.2
        return true
    end

    if phase == "bandageBuy" then
        self:Talk()
        self:HunterFire(
            "PurchaseFromShop",
            "Bandage",
            1
        )
        q.Phase = "klienTreat"
        q.NextAt = now + 0.4
        return true
    end

    if phase == "klienTreat" then
        if self:HunterGoNpc("Klien") then
            self:Talk()
            self:HunterFire(
                "QuestProgress",
                "Treat Klien",
                "Treat Klien"
            )
            q.ManualReady = false
            q.Phase = "manual"
            q.NextAt = 0
            self:SetStatus(
                q,
                "สอบนักล่า • ช่วงนี้ทำเอง • เสร็จแล้วกด Continue"
            )
        else
            q.NextAt = now + 1
        end
        return true
    end

    return true
end

function Quest:HunterExamDungeon(q, now)
    local phase = q.Phase

    if phase ~= "mizuto"
        and phase ~= "lostFight"
        and phase ~= "submergedKey"
        and phase ~= "dungeonRoute"
        and phase ~= "waitReturn"
        and phase ~= "mizutoReturn"
        and phase ~= "lavato"
        and phase ~= "lavatoPath"
        and phase ~= "lavatoReturn"
        and phase ~= "leviPath"
        and phase ~= "levi"
        and phase ~= "survivalHover"
        and phase ~= "survivalFight" then
        return false
    end

    if now < (q.NextAt or 0) then
        return true
    end

    if blocked(self) then return true end

    if phase == "mizuto" then
        if self:HunterGoNpc("Mizuto") then
            self:Talk()
            self:HunterFire(
                "QuestProgress",
                "Find Mizuto",
                "Find Mizuto"
            )
            q.Kills = 0
            q.Phase = "lostFight"
            q.NextAt = now + 0.35
        else
            q.NextAt = now + 1
        end
        return true
    end

    if phase == "lostFight" then
        self:HunterStartFarm(
            q,
            function()
                return self:HunterFindTarget(
                    HUNTER_LOST_FIGHT,
                    180,
                    function(model)
                        return model.Name == "Lost"
                    end
                )
            end,
            "สอบนักล่า • กำลังตี Lost"
        )

        self:WatchFarmTarget(q, 1)

        if q.Kills >= 1 then
            self:HunterStopFarm(q)
            q.Phase = "submergedKey"
            q.NextAt = now + 0.3
        end
        return true
    end

    if phase == "submergedKey" then
        if self:HunterCollect(
            q,
            "Submerged Key1",
            1,
            "dungeonRoute",
            now
        ) then
            q.RouteIndex = 1
        end
        return true
    end

    if phase == "dungeonRoute" then
        local entry =
            HUNTER_DUNGEON_ROUTE[
                q.RouteIndex or 1
            ]

        if not entry then
            q.Phase = "waitReturn"
            q.NextAt = 0
            self:SetStatus(
                q,
                "สอบนักล่า • รอผู้เล่นกลับมาจุด Mizuto"
            )
            return true
        end

        if not teleport(self):GoOwned("Quest",CFrame.new(entry.Position)) or not q.Enabled then return true end

        if (entry.Hold or 0) > 0 then
            self:PressT(entry.Hold)
        end

        q.RouteIndex = (q.RouteIndex or 1) + 1
        q.NextAt =
            now + math.max(entry.Hold or 0, 0.3) + 0.55
        self:SetStatus(
            q,
            "สอบนักล่า • Dungeon "
                .. tostring(q.RouteIndex - 1)
                .. "/"
                .. tostring(#HUNTER_DUNGEON_ROUTE)
        )
        return true
    end

    if phase == "waitReturn" then
        local _, hum, root = aliveCharacter(self)
        if not hum or hum.Health <= 0 or not root then
            return true
        end

        if (root.Position - HUNTER_RETURN_POINT).Magnitude <= 200 then
            q.Phase = "mizutoReturn"
            q.NextAt = now + 0.2
        else
            self:SetStatus(
                q,
                "สอบนักล่า • รอกลับ Final Selection"
            )
        end
        return true
    end

    if phase == "mizutoReturn" then
        if self:HunterGoNpc("Mizuto") then
            self:Talk()
            self:HunterFire(
                "QuestProgress",
                "The Dungeon",
                "Return to Mizuto"
            )
            q.Phase = "lavato"
            q.NextAt = now + 0.4
        else
            q.NextAt = now + 1
        end
        return true
    end

    if phase == "lavato" then
        if self:HunterGoNpc("Lavato") then
            self:Talk()
            self:HunterFire(
                "QuestProgress",
                "Find Lavato",
                "Find Lavato"
            )
            q.PathIndex = 1
            q.Phase = "lavatoPath"
            q.NextAt = now + 0.4
        else
            q.NextAt = now + 1
        end
        return true
    end

    if phase == "lavatoPath" then
        local position =
            HUNTER_LAVATO_PATH[
                q.PathIndex or 1
            ]

        if position then
            teleport(self):GoOwned("Quest",CFrame.new(position))
            q.PathIndex = (q.PathIndex or 1) + 1
            q.NextAt = now + 2
        else
            q.Phase = "lavatoReturn"
            q.NextAt = 0
        end
        return true
    end

    if phase == "lavatoReturn" then
        if self:HunterGoNpc("Lavato") then
            self:HunterFire(
                "QuestProgress",
                "Find Lavato",
                "Find Lavato"
            )
            self:Talk()
            q.PathIndex = 1
            q.Phase = "leviPath"
            q.NextAt = now + 0.4
        else
            q.NextAt = now + 1
        end
        return true
    end

    if phase == "leviPath" then
        local position =
            HUNTER_LEVI_PATH[
                q.PathIndex or 1
            ]

        if position then
            teleport(self):GoOwned("Quest",CFrame.new(position))
            q.PathIndex = (q.PathIndex or 1) + 1
            q.NextAt = now + 2
        else
            q.Phase = "levi"
            q.NextAt = 0
        end
        return true
    end

    if phase == "levi" then
        if self:HunterGoNpc("Levi") then
            self:HunterFire(
                "QuestProgress",
                "Mountain Survival",
                "Speak with Levi"
            )
            self:Talk()

            teleport(self):GoOwned("Quest",
                CFrame.new(
                    HUNTER_POSITIONS.Levi
                    + Vector3.new(0, 80, 0)
                )
            )

            q.Phase = "survivalHover"
            q.NextAt = now + 30
            self:SetStatus(
                q,
                "สอบนักล่า • Mountain Survival • รอ 30 วิ"
            )
        else
            q.NextAt = now + 1
        end
        return true
    end

    if phase == "survivalHover" then
        q.SawSurvivalTarget = false
        q.Phase = "survivalFight"
        q.NextAt = 0
        return true
    end

    if phase == "survivalFight" then
        local target =
            self:HunterFindTarget(
                HUNTER_POSITIONS.Levi,
                220
            )

        if target then
            q.SawSurvivalTarget = true
            self:HunterStartFarm(
                q,
                function()
                    return self:HunterFindTarget(
                        HUNTER_POSITIONS.Levi,
                        220
                    )
                end,
                "สอบนักล่า • Mountain Survival • กำลังเคลียร์มอน"
            )
        elseif q.SawSurvivalTarget then
            self:HunterStopFarm(q)
            q.Phase = "rescue"
            q.NextAt = now + 0.25
        else
            self:SetStatus(
                q,
                "สอบนักล่า • Mountain Survival • รอมอน"
            )
        end
        return true
    end

    return true
end

function Quest:HunterExamFinal(q, now)
    local phase = q.Phase

    if phase ~= "rescue"
        and phase ~= "rescueWait"
        and phase ~= "steve"
        and phase ~= "bossFight"
        and phase ~= "bossLoot" then
        return false
    end

    if now < (q.NextAt or 0) then
        return true
    end

    if blocked(self) then return true end

    if phase == "rescue" then
        local rescue =
            workspace:FindFirstChild(
                "RescueCivilian",
                true
            )
        local cf = rescue and cframeOf(self, rescue)

        if not cf then
            q.NextAt = now + 0.8
            self:SetStatus(
                q,
                "สอบนักล่า • รอ RescueCivilian"
            )
            return true
        end

        teleport(self):GoOwned("Quest",
            CFrame.lookAt(
                cf.Position + Vector3.new(0, 2.5, 2),
                cf.Position
            )
        )
        self:PressT(8)
        q.Phase = "rescueWait"
        q.NextAt = now + 8.5
        return true
    end

    if phase == "rescueWait" then
        teleport(self):GoOwned("Quest",
            CFrame.new(
                HUNTER_POSITIONS.Levi
                + Vector3.new(0, 3, 0)
            )
        )
        q.Phase = "steve"
        q.NextAt = now + 0.5
        return true
    end

    if phase == "steve" then
        if self:HunterGoNpc("Steve") then
            self:HunterFire(
                "QuestProgress",
                "Find Steve",
                "Find Steve"
            )
            self:Talk()
            q.BossDead = false
            q.Phase = "bossFight"
            q.NextAt = now + 0.35
        else
            q.NextAt = now + 1
        end
        return true
    end

    if phase == "bossFight" then
        local boss =
            self:HunterFindTarget(
                HUNTER_HAND_DEMON_CENTER,
                450,
                function(model)
                    return model.Name == "Hand Demon"
                end
            )

        if boss
            and not q.BossWatch
            and not q.BossDead then

            local hum =
                boss:FindFirstChildWhichIsA(
                    "Humanoid",
                    true
                )
            local root =
                boss:FindFirstChild(
                    "HumanoidRootPart",
                    true
                )

            if hum then
                q.BossWatch =
                    hum.Died:Connect(function()
                        q.BossDead = true
                        q.BossDeathPosition =
                            root
                            and root.Position
                            or HUNTER_HAND_DEMON_CENTER
                    end)
            end
        end

        self:HunterStartFarm(
            q,
            function()
                return self:HunterBossTarget()
            end,
            "สอบนักล่า • Hand Demon • เคลียร์ลูกน้องก่อนบอส"
        )

        if q.BossDead then
            self:HunterStopFarm(q)

            if q.BossWatch then
                pcall(function()
                    q.BossWatch:Disconnect()
                end)
                q.BossWatch = nil
            end

            q.Phase = "bossLoot"
            q.NextAt = now + 0.6
        end
        return true
    end

    if phase == "bossLoot" then
        local loot =
            self.Ctx.Modules
            and self.Ctx.Modules.Loot

        if not loot then
            self:SetEnabled("HunterExam", false)
            self:SetStatus(q, "สอบนักล่า • DONE")
            return true
        end

        if not q.LootStarted then
            q.RestoreLootEnabled = loot.Enabled == true

            if not loot.Enabled then
                loot:SetEnabled(true)
            end

            loot:BeginCollect(
                q.BossDeathPosition
                or HUNTER_HAND_DEMON_CENTER
            )

            q.LootStarted = true
            q.NextAt = now + 0.7
            self:SetStatus(
                q,
                "สอบนักล่า • เก็บของจาก Hand Demon"
            )
            return true
        end

        if loot.Busy then
            return true
        end

        if q.RestoreLootEnabled == false then
            loot:SetEnabled(false)
        end

        self:SetEnabled("HunterExam", false)
        self:SetStatus(q, "สอบนักล่า • DONE")
        return true
    end

    return true
end

function Quest:HunterExamStep(q, now)
    local _, hum = aliveCharacter(self)

    if not hum or hum.Health <= 0 then
        self:SetStatus(q, "สอบนักล่า • รอตัวละครพร้อม")
        return
    end

    if self:HunterExamEarly(q, now) then return end
    if self:HunterExamDungeon(q, now) then return end
    if self:HunterExamFinal(q, now) then return end

    self:SetStatus(
        q,
        "สอบนักล่า • phase ไม่รู้จัก: "
            .. tostring(q.Phase)
    )
end

function Quest:AutoQuestSpec()
    local f = farm(self)
    if not f then return nil end

    if f.BossEnabled then
        return AUTO_BOSS_QUESTS[f.BossName]
    end

    local name = type(f.MobName) == "string"
        and f.MobName:lower()
        or ""

    return AUTO_MOB_QUESTS[name]
end

function Quest:ClearAutoWatch()
    local runtime = self.AutoRuntime
    if not runtime then return end

    if runtime.WatchConnection then
        runtime.WatchConnection:Disconnect()
        runtime.WatchConnection = nil
    end

    runtime.WatchTarget = nil
    runtime.WatchHumanoid = nil
end

function Quest:ResumeAutoFarm()
    local f = farm(self)
    if f and f.Enabled and self.Ctx then
        self.Ctx:SetJobEnabled("Farm", true)
    end

    local runtime = self.AutoRuntime
    if runtime then
        runtime.PausedFarm = false
    end
end

function Quest:ResetAutoRuntime()
    self:ClearAutoWatch()

    local runtime = self.AutoRuntime
    if not runtime then return end

    runtime.Phase = "idle"
    runtime.NextAt = 0
    runtime.SpecText = nil
    runtime.PausedFarm = false
end

function Quest:SetAutoQuest(on)
    local f = farm(self)
    if not f then
        return false, "Farm module unavailable"
    end

    on = on == true

    if not on then
        self:ResumeAutoFarm()
        self:ResetAutoRuntime()
    end

    f.AutoQuest = on
    f.QuestKills = 0
    f._questBusy = false
    f._questNeeded = on
    f._acceptedQuestText = nil
    f._lastQuestAt = -math.huge
    f._questReadyAt = 0
    f._target = nil
    f._attackTarget = nil

    if on and self.AutoRuntime then
        self.AutoRuntime.Phase = "needQuest"
        self.AutoRuntime.NextAt = 0
    end

    return true
end

function Quest:AcceptOnce(npcName, questText)
    if type(npcName) ~= "string" or npcName == "" then
        return false, "NPC name missing"
    end
    if type(questText) ~= "string" or questText == "" then
        return false, "Quest text missing"
    end

    local _, hum, root = aliveCharacter(self)
    if not hum or hum.Health <= 0 or not root then
        return false, "ตัวละครยังไม่พร้อม"
    end

    local event = signal(self)
    if not event then
        return false, "ไม่พบ SignalEvent"
    end

    local tp = teleport(self)
    local destination = tp and tp:Destination(npcName)
    if not destination then
        return false, "ไม่พบ " .. npcName
    end

    local stand = destination * CFrame.new(0, 0, -3)
    local ok, err = tp:SoftGoOwned("Quest",CFrame.lookAt(stand.Position, destination.Position))
    if not ok then
        return false, tostring(err or "Teleport failed")
    end

    task.wait(0.30)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    pcall(function()
        event:FireServer("NpcTalking", "Ended")
    end)
    task.wait(0.12)

    local sent, sendErr = pcall(function()
        event:FireServer("AddQuest", questText)
    end)
    if not sent then
        return false, tostring(sendErr)
    end

    task.wait(0.12)
    pcall(function()
        event:FireServer("NpcTalking", "Ended")
    end)

    local f = farm(self)
    if f then
        f._acceptedQuestText = questText
        f._questNeeded = false
        f._lastQuestAt = os.clock()
    end

    return true
end

function Quest:SetDedicatedEnabled(name, on)
    return self:SetEnabled(name, on)
end

function Quest:WatchAutoTarget(spec)
    local runtime = self.AutoRuntime
    local f = farm(self)

    if not runtime or not f or not spec then return end

    local target = f._attackTarget or f._target or self.Ctx.State.Target
    if not target or not target.Parent then return end

    if runtime.WatchTarget == target then return end

    self:ClearAutoWatch()

    local hum = target:FindFirstChildWhichIsA("Humanoid", true)
    if not hum then return end

    runtime.WatchTarget = target
    runtime.WatchHumanoid = hum

    local counted = false
    runtime.WatchConnection = hum.Died:Connect(function()
        if counted then return end
        counted = true

        local current = self:AutoQuestSpec()
        if not current or current.Text ~= spec.Text then
            return
        end

        f.QuestKills = (tonumber(f.QuestKills) or 0) + 1

        if f.QuestKills >= (tonumber(spec.RequiredKills) or 1) then
            f.QuestKills = 0
            f._acceptedQuestText = nil
            f._questNeeded = true
            runtime.Phase = "needQuest"
            runtime.NextAt = os.clock() + 0.25
        end
    end)
end

function Quest:AutoQuestStep(now)
    local f = farm(self)
    local runtime = self.AutoRuntime

    if not f or not runtime then return end

    if not f.AutoQuest or self.Active then
        if runtime.PausedFarm then
            self:ResumeAutoFarm()
        end
        return
    end

    if not f.Enabled then
        return
    end

    local spec = self:AutoQuestSpec()
    if not spec then
        self:ClearAutoWatch()
        return
    end

    if runtime.SpecText and runtime.SpecText ~= spec.Text then
        self:ResumeAutoFarm()
        self:ClearAutoWatch()
        runtime.Phase = "needQuest"
        runtime.NextAt = 0
        f.QuestKills = 0
        f._acceptedQuestText = nil
        f._questNeeded = true
    end

    runtime.SpecText = spec.Text

    if f._acceptedQuestText == spec.Text and not f._questNeeded then
        runtime.Phase = "farming"
        self:WatchAutoTarget(spec)
        return
    end

    if blocked(self) or now < (runtime.NextAt or 0) then
        return
    end

    local _, hum = aliveCharacter(self)
    if not hum or hum.Health <= 0 then
        runtime.NextAt = now + 0.5
        return
    end

    if runtime.Phase == "idle"
        or runtime.Phase == "needQuest"
        or runtime.Phase == "farming" then

        self:ClearAutoWatch()
        runtime.PausedFarm = true
        self.Ctx:SetJobEnabled("Farm", false)

        local c = combat(self)
        if c and c.Release then
            pcall(function() c:Release() end)
        end

        if not self:GoNpc(spec.NPCName) then
            self:ResumeAutoFarm()
            runtime.Phase = "needQuest"
            runtime.NextAt = now + 1
            return
        end

        runtime.Phase = "talk"
        runtime.NextAt = now + 0.35
        f._questBusy = true
        return
    end

    if runtime.Phase == "talk" then
        if self:Talk() then
            runtime.Phase = "accept"
            runtime.NextAt = now + 0.15
        else
            runtime.NextAt = now + 0.5
        end
        return
    end

    if runtime.Phase == "accept" then
        if self:AddQuest(spec.Text) then
            task.delay(0.05, function()
                pcall(function()
                    self:Talk()
                end)
            end)

            f._acceptedQuestText = spec.Text
            f._questNeeded = false
            f._lastQuestAt = now
            f.QuestKills = 0
            f._questBusy = false

            runtime.Phase = "farming"
            runtime.NextAt = now + 0.25
            self:ResumeAutoFarm()
        else
            runtime.NextAt = now + 0.5
        end
    end
end

-- Market unlock uses the existing scheduler; no blocking sleeps or repeat remote spam.
function Quest:ReleaseMarketKey(q)
    if q and q.HoldingT then
        q.HoldingT=false
        pcall(function() self.Ctx.Services.VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.T,false,game) end)
    end
end

function Quest:MarketUnlockStep(q,now)
    if not q.Enabled then self:ReleaseMarketKey(q);return end
    local function finish(message)
        self:SetEnabled("UnlockMarket",false)
        self:SetStatus(q,message)
    end
    if not q.Deadline then q.Deadline=now+90 end
    if now>=q.Deadline then finish("Unlock Market: timed out; check the quest in game");return end
    local char,hum,root=aliveCharacter(self)
    if not root or not hum or hum.Health<=0 or (q.Character and q.Character~=char) then
        finish("Unlock Market: stopped because character changed or died");return
    end
    q.Character=char
    if now<(q.NextAt or 0) then return end
    local function advance(phase,delay,status)
        q.Phase=phase;q.NextAt=now+(delay or .4)
        if status then self:SetStatus(q,status) end
    end
    if q.Phase=="npc" then
        if teleport(self):SoftGoOwned("Quest",CFrame.new(273.80,944.00,528.19)) then
            advance("accept",.7,"Unlock Market: talking to Ginzo")
        else q.NextAt=now+1 end
    elseif q.Phase=="accept" then
        if self:HunterFire("AddQuest","Ill find the jewelry box(Lv 45)") then advance("endAccept",.25)
        else finish("Unlock Market: quest remote unavailable") end
    elseif q.Phase=="endAccept" then
        if self:Talk() then advance("box",.4,"Unlock Market: travelling to Jewelry Box1")
        else finish("Unlock Market: failed to end dialogue") end
    elseif q.Phase=="box" then
        if teleport(self):GoOwned("Quest",CFrame.new(1874.20,687.75,-729.42)) then advance("waitBox",.7)
        else q.NextAt=now+1 end
    elseif q.Phase=="waitBox" then
        local object=workspace:FindFirstChild("Jewelry Box1")
        if not object then
            self:SetStatus(q,"Unlock Market: waiting for Jewelry Box1 to load")
            q.NextAt=now+.5;return
        end
        local prompt=object:FindFirstChildWhichIsA("ProximityPrompt",true)
        q.HoldSeconds=math.max(4,prompt and prompt.HoldDuration or 0)+.25
        advance("hold",.1,"Unlock Market: collecting Jewelry Box1 (hold T)")
    elseif q.Phase=="hold" then
        q.HoldingT=true
        local ok=pcall(function() self.Ctx.Services.VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.T,false,game) end)
        if not ok then finish("Unlock Market: unable to press T");return end
        advance("release",q.HoldSeconds)
    elseif q.Phase=="release" then
        self:ReleaseMarketKey(q)
        advance("return",.6,"Unlock Market: returning to Ginzo")
    elseif q.Phase=="return" then
        if teleport(self):SoftGoOwned("Quest",CFrame.new(273.80,944.00,528.19)) then advance("submit",.7)
        else q.NextAt=now+1 end
    elseif q.Phase=="submit" then
        if self:HunterFire("QuestProgress","Ill find the jewelry box(Lv 45)","Return to Ginzo") then advance("endSubmit",.25)
        else finish("Unlock Market: submission failed") end
    elseif q.Phase=="endSubmit" then
        if self:Talk() then finish("Unlock Market: turn-in sent; check unlock confirmation in game")
        else finish("Unlock Market: turn-in sent, but dialogue did not close") end
    end
end

function Quest:Step()
    local now = os.clock()

    self:AutoQuestStep(now)

    local name = self.Active
    if not name then return end

    local q = self.Quests[name]
    if not q or not q.Enabled then return end

    if name == "Betty" then
        self:BettyStep(q, now)
    elseif name == "Kazu" then
        self:KazuStep(q, now)
    elseif name == "Delivery" then
        self:DeliveryStep(q, now)
    elseif name == "Pages" then
        self:PagesStep(q, now)
    elseif name == "Bear" then
        self:BearStep(q, now)
    elseif name == "HunterExam" then
        self:HunterExamStep(q, now)
    elseif name == "DungeonUnlock" then
        self:DungeonUnlockStep(q, now)
    elseif name == "UnlockMarket" then
        self:MarketUnlockStep(q,now)
    end
end

function Quest:Init(ctx)
    self.Ctx = ctx
    self.AutoRuntime = {
        Phase = "idle",
        NextAt = 0,
        SpecText = nil,
        PausedFarm = false,
        WatchTarget = nil,
        WatchHumanoid = nil,
        WatchConnection = nil,
    }

    self.Quests = {
        UnlockMarket = {
            Name="Unlock Market",Enabled=false,StartPhase="npc",Phase="npc",NextAt=0,
            Status="Unlock Market • OFF",StatusText="Unlock Market • OFF",
            OnText="Unlock Market: travelling to Ginzo",
        },
        Kazu = {
            Name = "Quest 1 • Kazu",
            Enabled = false,
            StartPhase = "npc",
            StatusText = "Quest 1 • OFF",
            Status = "Quest 1 • OFF",
            OnText = "Quest 1 • Kazu • 0/4",
        },

        Betty = {
            Name = "Quest 2 • Betty",
            Enabled = false,
            StartPhase = "npc",
            StatusText = "Quest 2 • OFF",
            Status = "Quest 2 • OFF",
            OnText = "Auto Quest Betty • ON",
        },

        Delivery = {
            Name = "Quest 3 • MoldySugar",
            Enabled = false,
            StartPhase = "source",
            StatusText = "Quest 3 • OFF",
            Status = "Quest 3 • OFF",
            OnText = "Quest 3 • MoldySugar",
        },

        Pages = {
            Name = "Quest 4 • Kona",
            Enabled = false,
            StartPhase = "npc",
            StatusText = "Quest 4 • OFF",
            Status = "Quest 4 • OFF",
            OnText = "Quest 4 • Kona • 0/5",
            Index = 1,
            Collected = 0,
        },

        Bear = {
            Name = "Quest 5 • Lucy / Tom",
            Enabled = false,
            StartPhase = "lucy",
            StatusText = "Quest 5 • OFF",
            Status = "Quest 5 • OFF",
            OnText = "Quest 5 • เริ่มที่ Lucy",
            Kills = 0,
            TomRuns = 0,
        },

        HunterExam = {
            Name = "สอบนักล่า",
            Enabled = false,
            StartPhase = "rem",
            StatusText = "สอบนักล่า • OFF",
            Status = "สอบนักล่า • OFF",
            OnText = "สอบนักล่า • เริ่มจาก Rem",
            Phase = "rem",
            Stage = 1,
            Kills = 0,
            ManualReady = false,
        },

        DungeonUnlock = {
            Name = "Dungeon Unlock",
            Enabled = false,
            StartPhase = "npc",
            StatusText = "Dungeon • OFF",
            Status = "Dungeon • OFF",
            OnText = "กำลังไปหา Blacksmith Togane",
            Forge = Vector3.new(
                -1604.9444580078125,
                1002.4012451171875,
                1143.3331298828125
            ),
        },
    }
end

function Quest:Start()
    self.Ctx:RegisterJob("Quest", 0.05, function()
        local ok, err = pcall(function()
            self:Step()
        end)

        if not ok then
            local q = self.Active and self.Quests[self.Active]
            if q then
                self:SetStatus(q, "ERROR: " .. tostring(err))
                self:SetEnabled(self.Active, false)
            end
        end
    end)
end

function Quest:Stop()
    self:StopAll(nil)
    self:ClearAutoWatch()
    self:ResumeAutoFarm()

    for _, q in pairs(self.Quests) do
        if q.Watch and q.Watch.Connection then
            q.Watch.Connection:Disconnect()
        end
        q.Watch = nil
    end
end

return Quest

]====]
BUNDLED_SOURCES["dungeon.lua"] = [====[
-- MazxhubModules/dungeon.lua
local Dungeon = {
    Enabled = false,
    OnEnabled = nil,
    Unlock = {
        Enabled = false,
        OnStatus = nil,
    },
    Radius = 300,
    AutoSkip = false,
    KillAura = false,
    KillAuraRadius = 20,
    ApproachSkyHeight = 60,
    ApproachDelay = 1.0,
    NextTargetDelay = 0.5,
    Current = nil,
    ApproachTarget = nil,
    ApproachReadyAt = 0,
    NextTargetAt = 0,
    NextSkipAt = 0,
    KillAuraNextAt = 0,
    Prime = setmetatable({}, { __mode = "k" }),
    RootIndex = nil,
    RootAdded = nil,
    RootRemoved = nil,
    CachedCandidate = nil,
    NextFindAt = 0,
}

local function farm(self)
    return self.Ctx.Modules.Farm
end

local function combat(self)
    return self.Ctx.Modules.Combat
end

function Dungeon:ActiveFolder()
    local humanoids = workspace:FindFirstChild("Humanoids")
    local regions = humanoids and humanoids:FindFirstChild("Regions")
    local temporary = regions and regions:FindFirstChild("Temporary")
    return temporary and temporary:FindFirstChild("ActiveNpcs")
end

function Dungeon:TargetRoot(model)
    if not model then return nil end
    local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("HumanoidRootPart", true)
    return root and root:IsA("BasePart") and root or nil
end

function Dungeon:ValidTarget(model)
    if not model or not model.Parent then return false end
    if self.Ctx.Services.Players:GetPlayerFromCharacter(model) then return false end
    local my = self.Ctx.Player.Character
    if my and (model == my or model:IsDescendantOf(my)) then return false end
    local hum = model:FindFirstChildWhichIsA("Humanoid", true)
    local root = self:TargetRoot(model)
    return hum ~= nil and hum.Health > 0 and root ~= nil
end

function Dungeon:StopTargetIndex()
    if self.RootAdded then
        self.RootAdded:Disconnect()
        self.RootAdded = nil
    end
    if self.RootRemoved then
        self.RootRemoved:Disconnect()
        self.RootRemoved = nil
    end

    self.RootIndex = nil
    self.CachedCandidate = nil
    self.NextFindAt = 0
end

function Dungeon:EnsureTargetIndex()
    if self.RootIndex then return end

    local roots = setmetatable({}, { __mode = "k" })
    self.RootIndex = roots

    local function addRoot(part)
        if part:IsA("BasePart") and part.Name == "HumanoidRootPart" then
            roots[part] = true
        end
    end

    for _, part in ipairs(workspace:GetDescendants()) do
        addRoot(part)
    end

    self.RootAdded = workspace.DescendantAdded:Connect(addRoot)
    self.RootRemoved = workspace.DescendantRemoving:Connect(function(part)
        roots[part] = nil
    end)
end

function Dungeon:FindTarget()
    local now = os.clock()

    if now < (self.NextFindAt or 0) then
        return self:ValidTarget(self.CachedCandidate)
            and self.CachedCandidate
            or nil
    end

    self.NextFindAt = now + 0.2

    local char = self.Ctx.Player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then
        self.CachedCandidate = nil
        return nil
    end

    self:EnsureTargetIndex()

    local radius = math.max(1, tonumber(self.Radius) or 300)
    local best, bestDistance = nil, radius

    for root in pairs(self.RootIndex) do
        if root and root.Parent then
            local distance = (root.Position - myRoot.Position).Magnitude

            if distance <= bestDistance then
                local model = root:FindFirstAncestorOfClass("Model")

                if self:ValidTarget(model) then
                    best = model
                    bestDistance = distance
                end
            end
        else
            self.RootIndex[root] = nil
        end
    end

    self.CachedCandidate = best
    return best
end

function Dungeon:MoveToTarget(target)
    if not self:ValidTarget(target) then return false end
    local char = self.Ctx.Player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local targetRoot = self:TargetRoot(target)
    if not myRoot or not hum or hum.Health <= 0 or not targetRoot then return false end

    local now = os.clock()
    if self.ApproachTarget ~= target then
        self.ApproachTarget = target
        self.ApproachReadyAt = now + self.ApproachDelay
        local sky = targetRoot.Position + Vector3.new(0, self.ApproachSkyHeight, 0)
        pcall(function()
            self.Ctx.Modules.Teleport:CancelLocal()
            char:PivotTo(CFrame.lookAt(sky, targetRoot.Position))
            myRoot.AssemblyLinearVelocity = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero
        end)
        return false
    end

    if now < self.ApproachReadyAt then return false end
    local f = farm(self)
    if f and f.farmMoveUnder then
        return f.farmMoveUnder(target) == true
    end
    return false
end

function Dungeon:SetEnabled(on)
    on = on == true
    if self.Enabled == on then return end
    local f = farm(self)

    if not on then
        self.Enabled = false
        if self.OnEnabled then
            pcall(self.OnEnabled, false)
        end
        self.Current = nil
        self.ApproachTarget = nil
        self.ApproachReadyAt = 0
        self.NextTargetAt = 0
        self.Prime = setmetatable({}, { __mode = "k" })
        self:StopTargetIndex()
        if f.ExternalMode == "Dungeon" then
            f:Stop()
            f:ClearExternalMode()
        end
        return
    end

    if type(f.StopConflicts) == "function" then
        f:StopConflicts("Dungeon")
    end
    if f.Enabled then f:Stop() end
    self.Enabled = true
    if self.OnEnabled then
        pcall(self.OnEnabled, true)
    end
    self.Current = nil
    self.NextTargetAt = 0
    self.ApproachTarget = nil
    self.Prime = setmetatable({}, { __mode = "k" })
    f.AutoAttack = true

    f:SetExternalMode("Dungeon",
        function()
            local now = os.clock()
            if self.Current and not self:ValidTarget(self.Current) then
                self.Current = nil
                self.ApproachTarget = nil
                self.NextTargetAt = now + math.max(tonumber(self.NextTargetDelay) or 0.5, 0)
            end
            if self.Current and self:ValidTarget(self.Current) then
                return self.Current
            end
            if now < self.NextTargetAt then return nil end
            self.Current = self:FindTarget()
            return self.Current
        end,
        function(target)
            return self:MoveToTarget(target)
        end
    )
end

function Dungeon:SetAutoSkip(on)
    self.AutoSkip = on == true
    self.NextSkipAt = 0
end

function Dungeon:SetKillAura(on)
    self.KillAura = on == true
    self.KillAuraNextAt = 0
end

function Dungeon:SetUnlockEnabled(on)
    local quest = self.Ctx.Modules.Quest
    self.Unlock.Enabled = on == true

    if quest then
        quest:SetEnabled("DungeonUnlock", on)

        local record = quest.Quests.DungeonUnlock
        if record then
            record.OnStatus = function(text)
                if self.Unlock.OnStatus then
                    pcall(self.Unlock.OnStatus, text)
                end
            end

            record.OnEnabled = function(enabled)
                self.Unlock.Enabled = enabled == true
            end
        end
    end
end

function Dungeon:StepAutoSkip()
    if not self.AutoSkip then return end
    local now = os.clock()
    if now < self.NextSkipAt then return end
    local f = farm(self)
    if f.InputBlocked and f.InputBlocked() then return end
    local event = f.GetSignal and f.GetSignal()
    if not event then self.NextSkipAt = now + 1 return end
    local ok = pcall(function()
        event:FireServer("OuwigaharaRequest", { action = "Skip" })
    end)
    self.NextSkipAt = now + (ok and 3 or 5)
end

function Dungeon:StepKillAura()
    if not self.Enabled or not self.KillAura then return end
    local f = farm(self)
    local c = combat(self)
    if not c or not c:CombatReady() then return end
    local target = self.Current or f._target
    if not self:ValidTarget(target) then return end
    local myChar = self.Ctx.Player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = self:TargetRoot(target)
    if not myRoot or not targetRoot then return end
    if (targetRoot.Position - myRoot.Position).Magnitude > (tonumber(self.KillAuraRadius) or 20) then return end

    local now = os.clock()
    if now < self.KillAuraNextAt then return end
    local event = f.GetSignal and f.GetSignal()
    if not event then self.KillAuraNextAt = now + 0.25 return end
    self.KillAuraNextAt = now + 0.05
    pcall(function()
        event:FireServer("Combat_Service", "Combat", 1, false, 0.13, false, nil)
    end)
end

function Dungeon:Init(ctx)
    self.Ctx = ctx
end

function Dungeon:Start()
    self.Ctx:RegisterJob("DungeonSkip", 0.10, function()
        self:StepAutoSkip()
    end)
    self.Ctx:RegisterJob("DungeonAura", 0.05, function()
        self:StepKillAura()
    end)
end

function Dungeon:Stop()
    self.AutoSkip = false
    self.KillAura = false
    self:SetEnabled(false)
    self:StopTargetIndex()
end

return Dungeon

]====]
BUNDLED_SOURCES["raid.lua"] = [====[
-- MazxhubModules/raid.lua
local Raid = {
    Enabled = false,
    OnEnabled = nil,
    Phase = "idle",
    PointIndex = 1,
    SeenCount = 0,
    NextAt = 0,
    CheckUntil = 0,
    CollectUntil = 0,
    LastLootAt = 0,
    HeldPrompt = nil,
    PromptUntil = 0,
    Collected = setmetatable({}, { __mode = "k" }),
    LootRecords = setmetatable({}, { __mode = "k" }),
    StatusText = "Raid Chest • OFF",
    Status = "Raid Chest • OFF",
    OnStatus = nil,
}

local function farm(self)
    return self.Ctx.Modules.Farm
end

local function teleport(self)
    return self.Ctx.Modules.Teleport
end

function Raid:SetStatus(text)
    self.StatusText = text
    self.Status = text
    if self.Label and self.Label.Parent then self.Label.Text = text end
    if self.OnStatus then
        pcall(self.OnStatus, text)
    end
end

function Raid:Points()
    return farm(self).RaidBoxPoints or {}
end

function Raid:PointCount()
    return #self:Points()
end

function Raid:SetPoint(index)
    local points = self:Points()
    if #points == 0 then return false end
    self.PointIndex = math.clamp(math.floor(tonumber(index) or 1), 1, #points)
    self.Origin = points[self.PointIndex]
    self.MobKey = "Raid Box Point " .. tostring(self.PointIndex)
    return true
end

function Raid:PromptPosition(prompt)
    if not prompt or not prompt.Parent then return nil end
    local node = prompt.Parent
    while node and node ~= workspace do
        if node:IsA("Attachment") then return node.WorldPosition end
        if node:IsA("BasePart") then return node.Position end
        if node:IsA("Model") then return node:GetPivot().Position end
        node = node.Parent
    end
    return nil
end

function Raid:PromptIsNpc(prompt)
    local node = prompt and prompt.Parent
    while node and node ~= workspace do
        if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then return true end
        local name = node.Name:lower()
        if name == "activenpcs" or name == "stationarynpcs" then return true end
        node = node.Parent
    end
    return false
end

function Raid:NearestPrompt(root, collect)
    local best, bestPos, bestDistance
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled and not self.Collected[prompt]
            and not self:PromptIsNpc(prompt) then
            local record = self.LootRecords[prompt]
            if collect and record and os.clock() < (record.NextAt or 0) then
                continue
            end

            local pos = self:PromptPosition(prompt)
            if pos then
                local fromOrigin = self.Origin and (pos - self.Origin).Magnitude or math.huge
                local maxOrigin = collect and 90 or 20
                if fromOrigin <= maxOrigin then
                    local distance = root and (pos - root.Position).Magnitude or fromOrigin
                    if not bestDistance or distance < bestDistance then
                        best, bestPos, bestDistance = prompt, pos, distance
                    end
                end
            end
        end
    end
    return best, bestPos
end

function Raid:BeginPrompt(prompt, seconds)
    if not prompt or not prompt.Parent then return false end
    if self.HeldPrompt then pcall(function() self.HeldPrompt:InputHoldEnd() end) end
    self.HeldPrompt = prompt
    self.PromptUntil = os.clock() + math.max(tonumber(seconds) or prompt.HoldDuration or 0, 0.12)
    pcall(function() prompt:InputHoldBegin() end)
    return true
end

function Raid:FinishPrompt()
    local prompt = self.HeldPrompt
    self.HeldPrompt = nil
    self.PromptUntil = 0
    if prompt then pcall(function() prompt:InputHoldEnd() end) end
    return prompt
end

function Raid:Advance(delaySeconds)
    local f = farm(self)
    if f.Enabled then f:Stop() end
    self:FinishPrompt()
    self.SeenCount = 0
    self.Collected = setmetatable({}, { __mode = "k" })
    self.LootRecords = setmetatable({}, { __mode = "k" })
    local points = self:Points()
    if #points > 0 then self:SetPoint((self.PointIndex % #points) + 1) end
    self.Phase = "checkMove"
    self.NextAt = os.clock() + (delaySeconds or 0.15)
end

function Raid:SetEnabled(on)
    if not on then teleport(self):Cancel("Raid") end
    on = on == true
    if self.Enabled == on then return end
    local f = farm(self)

    if on then
        if type(f.StopConflicts) == "function" then
            f:StopConflicts("Raid")
        end
        if f.Enabled then f:Stop() end
        if not self:SetPoint(1) then
            self:SetStatus("Raid Chest • ไม่มีพิกัด")
            if self.OnEnabled then
                pcall(self.OnEnabled, false)
            end
            return
        end
        self.Enabled = true
        if self.OnEnabled then
            pcall(self.OnEnabled, true)
        end
        self.Phase = "checkMove"
        self.NextAt = 0
        self.SeenCount = 0
        self.Collected = setmetatable({}, { __mode = "k" })
        self.LootRecords = setmetatable({}, { __mode = "k" })
        self:SetStatus("Raid Chest • ON")
    else
        self.Enabled = false
        if self.OnEnabled then
            pcall(self.OnEnabled, false)
        end
        self:FinishPrompt()
        if f.Enabled
            and (
                f.Mode == "RaidChest"
                or f.MobName == self.MobKey
            ) then
            f:Stop()
        end
        self.Phase = "idle"
        self:SetStatus("Raid Chest • OFF")
    end
end

function Raid:Step()
    if not self.Enabled then return end
    local now = os.clock()

    if self.HeldPrompt then
        if now < self.PromptUntil then return end
        local finished = self:FinishPrompt()

        if finished then
            self.LastLootAt = now

            if self.Phase == "collect" then
                local record =
                    self.LootRecords[finished]
                    or { Attempts = 0, NextAt = 0 }

                record.Attempts += 1
                record.NextAt = now + 0.45
                self.LootRecords[finished] = record

                if not finished.Parent
                    or not finished.Enabled
                    or record.Attempts >= 6 then
                    self.Collected[finished] = true
                end
            else
                self.Collected[finished] = true
            end
        end

        self.NextAt = now + 0.15
        return
    end

    if now < self.NextAt then return end

    local char = self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not root then
        self:SetStatus("Raid Chest • รอตัวละคร")
        return
    end

    local f = farm(self)
    local tp = teleport(self)

    if self.Phase == "checkMove" then
        tp:GoOwned("Raid",CFrame.new(self.Origin + Vector3.new(0, 3, 0)))
        self.CheckUntil = now + 1.4
        self.Phase = "checkWait"
        self.NextAt = now + 0.35
        self:SetStatus("Raid Chest • จุด " .. tostring(self.PointIndex) .. " • ตรวจมอน")
        return
    end

    if self.Phase == "checkWait" then
        local alive = f.farmFindMobsByName and f.farmFindMobsByName(self.MobKey) or {}
        if #alive > 0 then
            self.SeenCount = #alive
            f:StartMob(self.MobKey, "Raid")
            self.Phase = "fight"
            self.NextAt = now + 0.15
            return
        end
        if now >= self.CheckUntil then self:Advance(0.1) else self.NextAt = now + 0.2 end
        return
    end

    if self.Phase == "fight" then
        local alive = f.farmFindMobsByName and f.farmFindMobsByName(self.MobKey) or {}
        if #alive > 0 then
            self.SeenCount = math.max(self.SeenCount or 0, #alive)
            self.NextAt = now + 0.2
            self:SetStatus("Raid Chest • กำลังตี • เหลือ " .. tostring(#alive))
            return
        end
        f:Stop()
        if self.SeenCount > 0 then
            self.Phase = "chest"
            self.NextAt = now + 0.15
        else
            self:Advance(0.1)
        end
        return
    end

    if self.Phase == "chest" then
        tp:GoOwned("Raid",CFrame.new(self.Origin + Vector3.new(0, 2.5, 0)))
        local prompt = self:NearestPrompt(root, false)
        if prompt then
            self:BeginPrompt(prompt, math.max(prompt.HoldDuration, 2.2))
        else
            local input = self.Ctx.Services.VirtualInputManager
            pcall(function() input:SendKeyEvent(true, Enum.KeyCode.T, false, game) end)
            task.delay(2.25, function()
                pcall(function() input:SendKeyEvent(false, Enum.KeyCode.T, false, game) end)
            end)
        end
        self.Phase = "collect"
        self.CollectUntil = now + 60
        self.LastLootAt = now
        self.NextAt = now + 2.5
        return
    end

    if self.Phase == "collect" then
        local prompt, pos = self:NearestPrompt(root, true)
        if prompt and pos then
            tp:GoOwned("Raid",CFrame.new(pos + Vector3.new(0, 2.5, 0)))
            self:BeginPrompt(prompt, math.max(prompt.HoldDuration, 4))
            self.LastLootAt = now
            self.CollectUntil = math.max(self.CollectUntil, now + 12)
            self:SetStatus("Raid Chest • เก็บไอเทม")
            return
        end

        if now >= self.CollectUntil or now - self.LastLootAt >= 6 then
            self:Advance(0.15)
        else
            self.NextAt = now + 0.15
        end
    end
end

function Raid:Init(ctx)
    self.Ctx = ctx
end

function Raid:Start()
    self.Ctx:RegisterJob("Raid", 0.05, function()
        local ok, err = pcall(function() self:Step() end)
        if not ok then self:SetStatus("Raid Chest • ERROR: " .. tostring(err)) end
    end)
end

function Raid:Stop()
    self:SetEnabled(false)
end

return Raid

]====]
BUNDLED_SOURCES["loot.lua"] = [====[
-- MazxhubModules/loot.lua
-- Boss loot collector migrated from hello.txt

local Loot = {
    Enabled = true,
    Busy = false,
    TrackedTarget = nil,
    DeathConnection = nil,
    Origin = nil,
    CollectUntil = 0,
    LastFoundAt = 0,
    HeldPrompt = nil,
    PromptUntil = 0,
    Collected = setmetatable({}, { __mode = "k" }),
    Records = setmetatable({}, { __mode = "k" }),
    Radius = 250,
    Status = "Loot ready",
}

local function farm(self)
    return self.Ctx.Modules.Farm
end

local function combat(self)
    return self.Ctx.Modules.Combat
end

local function teleport(self)
    return self.Ctx.Modules.Teleport
end

local function character(self)
    local p = self.Ctx.Player
    local char = p and p.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return char, hum, root
end

function Loot:SetStatus(text)
    self.Status = tostring(text)
    if self.OnStatus then
        pcall(self.OnStatus, self.Status)
    end
end

function Loot:SetEnabled(on)
    if not on then teleport(self):Cancel("Loot") end
    self.Enabled = on == true
    farm(self).AutoLoot = self.Enabled

    if not self.Enabled then
        self:Reset()
        self:SetStatus("Auto Loot • OFF")
    else
        self:SetStatus("Auto Loot • ON")
    end
end

function Loot:ClearTrack()
    if self.DeathConnection then
        pcall(function()
            self.DeathConnection:Disconnect()
        end)
    end

    self.DeathConnection = nil
    self.TrackedTarget = nil
end

function Loot:PromptPosition(prompt)
    if not prompt or not prompt.Parent then
        return nil
    end

    local node = prompt.Parent

    while node and node ~= workspace do
        if node:IsA("Attachment") then
            return node.WorldPosition
        end

        if node:IsA("BasePart") then
            return node.Position
        end

        if node:IsA("Model") then
            return node:GetPivot().Position
        end

        node = node.Parent
    end

    return nil
end

function Loot:PromptIsNPC(prompt)
    local node = prompt and prompt.Parent

    while node and node ~= workspace do
        if node:IsA("Model")
            and node:FindFirstChildOfClass("Humanoid") then
            return true
        end

        local lower = node.Name:lower()

        if lower == "activenpcs"
            or lower == "stationarynpcs" then
            return true
        end

        node = node.Parent
    end

    return false
end

function Loot:Candidate(prompt)
    if not prompt
        or not prompt.Parent
        or not prompt.Enabled
        or not prompt:IsDescendantOf(workspace)
        or self:PromptIsNPC(prompt) then
        return nil
    end

    local action =
        tostring(prompt.ActionText or "")
        :lower()
        :match("^%s*(.-)%s*$")

    local claim =
        action == "claim"
        or action == "collect"
        or action == "pick up"
        or action == "pickup"
        or action == "เก็บ"
        or action == "เก็บของ"

    local open =
        action == "open"
        or action == "เปิด"

    if not claim and not open then
        return nil
    end

    local chest =
        tostring(prompt.ObjectText or "")
        :lower()
        :find("chest", 1, true) ~= nil

    local node = prompt.Parent

    while node and node ~= workspace do
        local name = node.Name:lower()

        if name:find("chest", 1, true)
            or name:find("กล่อง", 1, true)
            or name:find("หีบ", 1, true) then
            chest = true
        end

        node = node.Parent
    end

    if open and not chest then
        return nil
    end

    local position = self:PromptPosition(prompt)
    if not position or not self.Origin then
        return nil
    end

    if (position - self.Origin).Magnitude
        > (tonumber(self.Radius) or 250) then
        return nil
    end

    if prompt.MaxActivationDistance <= 0
        or prompt.HoldDuration > 5 then
        return nil
    end

    return {
        Prompt = prompt,
        Position = position,
        Kind = claim and "claim" or "open",
    }
end

function Loot:NearestPrompt(root)
    if not root or not self.Origin then
        return nil
    end

    local now = os.clock()
    local best
    local bestPosition
    local bestScore

    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt")
            and not self.Collected[prompt] then

            local candidate = self:Candidate(prompt)

            if candidate then
                local record =
                    self.Records[prompt]
                    or {
                        Attempts = 0,
                        NextAt = 0,
                        Kind = candidate.Kind,
                    }

                self.Records[prompt] = record

                if record.Attempts < 6
                    and now >= (record.NextAt or 0) then

                    local distance =
                        (
                            candidate.Position
                            - root.Position
                        ).Magnitude

                    local score =
                        distance
                        + (
                            candidate.Kind == "claim"
                            and 500
                            or 0
                        )

                    if not bestScore or score < bestScore then
                        best = prompt
                        bestPosition = candidate.Position
                        bestScore = score
                    end
                end
            end
        end
    end

    return best, bestPosition
end

function Loot:FinishPrompt()
    local prompt = self.HeldPrompt
    self.HeldPrompt = nil
    self.PromptUntil = 0

    if prompt then
        pcall(function()
            prompt:InputHoldEnd()
        end)
    end

    pcall(function()
        self.Ctx.Services.VirtualInputManager:SendKeyEvent(
            false,
            Enum.KeyCode.T,
            false,
            game
        )
    end)

    return prompt
end

function Loot:BeginPrompt(prompt)
    self:FinishPrompt()

    self.HeldPrompt = prompt
    self.PromptUntil =
        os.clock()
        + math.max(
            tonumber(prompt.HoldDuration) or 0,
            4
        )

    pcall(function()
        prompt:InputHoldBegin()
    end)

    pcall(function()
        self.Ctx.Services.VirtualInputManager:SendKeyEvent(
            true,
            Enum.KeyCode.T,
            false,
            game
        )
    end)
end

function Loot:PauseFarm()
    local f = farm(self)

    f._lootBusy = true
    f._attackTarget = nil
    f._target = nil
    f._nextScanAt = 0
    self.Ctx.State.Target = nil

    self.Ctx:SetJobEnabled("Farm", false)

    local c = combat(self)
    if c and c.Release then
        c:Release()
    end
end

function Loot:ResumeFarm()
    local f = farm(self)

    f._lootBusy = false
    f._attackTarget = nil
    f._target = nil
    f._nextScanAt = 0

    if f.Enabled then
        self.Ctx:SetJobEnabled("Farm", true)
    end
end

function Loot:BeginCollect(origin)
    if not self.Enabled then return end

    self.Busy = true
    self.Origin = origin
    self.CollectUntil = os.clock() + 45
    self.LastFoundAt = os.clock()
    self.Collected =
        setmetatable({}, { __mode = "k" })
    self.Records =
        setmetatable({}, { __mode = "k" })

    self:PauseFarm()
    self:SetStatus("Auto Loot • รอของดรอป")
end

function Loot:Track(target)
    if not self.Enabled
        or self.Busy
        or not target
        or not target.Parent then
        return
    end

    if target == self.TrackedTarget then
        return
    end

    self:ClearTrack()

    local hum =
        target:FindFirstChildWhichIsA(
            "Humanoid",
            true
        )

    local root =
        target:FindFirstChild(
            "HumanoidRootPart",
            true
        )

    if not hum or hum.Health <= 0 or not root then
        return
    end

    self.TrackedTarget = target

    local deathOrigin = root.Position

    self.DeathConnection =
        hum.Died:Connect(function()
            if self.TrackedTarget ~= target then
                return
            end

            self:ClearTrack()
            self:BeginCollect(deathOrigin)
        end)
end

function Loot:CollectStep()
    if not self.Busy then return end

    local now = os.clock()
    local _, hum, root = character(self)

    if not hum or hum.Health <= 0 or not root then
        return
    end

    if self.HeldPrompt then
        if now < self.PromptUntil then
            return
        end

        local prompt = self:FinishPrompt()

        if prompt then
            local record =
                self.Records[prompt]
                or { Attempts = 0, NextAt = 0 }

            record.Attempts += 1
            record.NextAt = now + 0.55
            self.Records[prompt] = record

            if not prompt.Parent
                or not prompt.Enabled
                or record.Attempts >= 6 then
                self.Collected[prompt] = true
            end

            self.LastFoundAt = now
        end

        return
    end

    local prompt, position =
        self:NearestPrompt(root)

    if prompt and position then
        local record =
            self.Records[prompt]
            or { Attempts = 0, NextAt = 0 }

        self.Records[prompt] = record

        local arrived=teleport(self):GoOwned("Loot",
            CFrame.new(
                position
                + Vector3.new(0, 2.5, 0)
            )
        )

        if not arrived or not self.Enabled then return end
        self:BeginPrompt(prompt)
        self.LastFoundAt = now

        self:SetStatus(
            "Auto Loot • เก็บ "
                .. tostring(prompt.ObjectText)
        )

        return
    end

    if now >= self.CollectUntil
        or now - self.LastFoundAt >= 5 then

        self.Busy = false
        self.Origin = nil
        self:FinishPrompt()
        self:ResumeFarm()
        self:SetStatus("Auto Loot • เสร็จ")
    end
end

function Loot:Step()
    local f = farm(self)

    if not self.Enabled then return end

    if self.Busy then
        self:CollectStep()
        return
    end

    local bossMode =
        f.BossEnabled
        or f.Mode == "Boss"

    if bossMode
        and f.Enabled
        and f._target then

        self:Track(f._target)
    elseif self.TrackedTarget then
        self:ClearTrack()
    end
end

function Loot:Reset()
    self:ClearTrack()
    self:FinishPrompt()

    if self.Busy then
        self.Busy = false
        self:ResumeFarm()
    end

    self.Origin = nil
    self.Collected =
        setmetatable({}, { __mode = "k" })
    self.Records =
        setmetatable({}, { __mode = "k" })
end

function Loot:Init(ctx)
    self.Ctx = ctx
    farm(self).AutoLoot = self.Enabled
end

function Loot:Start()
    self.Ctx:RegisterJob(
        "Loot",
        0.08,
        function()
            self:Step()
        end
    )
end

function Loot:Stop()
    self.Enabled = false
    self:Reset()
end

return Loot

]====]
BUNDLED_SOURCES["world.lua"] = [====[
-- MazxhubModules/world.lua
-- Cup Game / Auto Pushups / Thunder Breathing migrated from hello.txt

local World = {
    CupGame = {
        Enabled = false,
        Highlight = nil,
        Target = nil,
        NextAt = 0,
        StatusText = "Cup2 ESP • OFF",
    },

    Pushups = {
        Enabled = false,
        NextAt = 0,
        LastClickAt = 0,
        Clicks = 0,
        Progress = 0,
        StartTried = false,
        Starting = false,
        LastStartAttempt = -math.huge,
        PromptState = setmetatable({}, { __mode = "k" }),
        RingState = setmetatable({}, { __mode = "k" }),
        StatusText = "Auto Pushups • OFF",
    },

    Thunder = {
        Enabled = false,
        Phase = "trainer",
        NextAt = 0,
        Character = nil,
        Root = nil,
        TrainingPosition = Vector3.new(
            -1885.1500244140625,
            315.2499694824219,
            34.36198425292969
        ),
        Clicks = 0,
        Armed = true,
        LastClickAt = 0,
        LastSeenAt = 0,
        NextScanAt = 0,
        LastPairKey = nil,
        Progress = 0,
        StatusText = "ปราณสายฟ้า • OFF",
    },
}

local function uiGui(self)
    local ui = self.Ctx.Modules.UI
    return ui and ui.Gui
end

local function inputBlocked(self)
    local farm = self.Ctx.Modules.Farm
    return farm
        and farm.InputBlocked
        and farm.InputBlocked()
        or false
end

local function signal(self)
    local farm = self.Ctx.Modules.Farm
    return farm and farm.GetSignal and farm.GetSignal() or nil
end

local function tele(self)
    return self.Ctx.Modules.Teleport
end

function World:SetStatus(mode, text)
    mode.StatusText = text

    if mode.Label and mode.Label.Parent then
        mode.Label.Text = text
    end

    if mode.OnStatus then
        pcall(mode.OnStatus, text)
    end
end

-- Cup Game ----------------------------------------------------

function World:Cup2()
    local training = workspace:FindFirstChild("Training")
    local gameFolder = training and training:FindFirstChild("Cup Game")
    local cupgame = gameFolder and gameFolder:FindFirstChild("Cupgame1")
    local cups = cupgame and cupgame:FindFirstChild("Cups")
    return cups and cups:FindFirstChild("Cup2") or nil
end

function World:ClearCupHighlight()
    local mode = self.CupGame

    if mode.Highlight then
        pcall(function() mode.Highlight:Destroy() end)
    end

    mode.Highlight = nil
    mode.Target = nil
end

function World:SetCupGame(on)
    if not on then tele(self):Cancel("World") end
    local mode = self.CupGame
    on = on == true

    if mode.Enabled == on then return end

    mode.Enabled = on
    mode.NextAt = 0

    if not on then
        self:ClearCupHighlight()
        self:SetStatus(mode, "Cup2 ESP • OFF")
    else
        self:SetStatus(mode, "Cup2 ESP • รอ Cup2")
    end
end

function World:CupStep()
    local mode = self.CupGame
    if not mode.Enabled then return end

    local now = os.clock()
    if now < mode.NextAt then return end
    mode.NextAt = now + 0.08

    local target = self:Cup2()

    if not target then
        self:ClearCupHighlight()
        self:SetStatus(mode, "Cup2 ESP • รอ Cup2")
        return
    end

    if mode.Target ~= target
        or not mode.Highlight
        or not mode.Highlight.Parent then

        self:ClearCupHighlight()

        local highlight = Instance.new("Highlight")
        highlight.Name = "MazxCup2ESP"
        highlight.Adornee = target
        highlight.FillTransparency = 1
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = target

        mode.Highlight = highlight
        mode.Target = target
    end

    mode.Highlight.Enabled = true
    self:SetStatus(mode, "Cup2 ESP • Outline สีขาว")
end

-- Pushups -----------------------------------------------------

function World:PushupPrompt()
    local training = workspace:FindFirstChild("Training")
    local pushups = training and training:FindFirstChild("Pushups")
    local mat = pushups and pushups:FindFirstChild("PushupMat1")
    local root = mat and mat:FindFirstChild("Root")
    local prompt = root and root:FindFirstChild("ProximityPrompt")
    return prompt, root, pushups
end

function World:StartPushupTraining()
    local mode = self.Pushups

    if mode.Starting then
        return false, "starting"
    end

    mode.Starting = true
    mode.LastStartAttempt = os.clock()

    local prompt, promptRoot = self:PushupPrompt()

    if not prompt or not prompt:IsA("ProximityPrompt") then
        mode.Starting = false
        return false, "Pushup ProximityPrompt not found"
    end

    if not promptRoot or not promptRoot:IsA("BasePart") then
        mode.Starting = false
        return false, "PushupMat1.Root not found"
    end

    local tp = tele(self)

    if tp then
        if not tp:GoOwned("World",promptRoot.CFrame * CFrame.new(0, 3, -2.5)) then mode.Starting=false;return false,"warp cancelled" end
    end

    task.wait(0.25)

    local attempted = false

    pcall(function()
        if fireproximityprompt then
            attempted = true
            fireproximityprompt(prompt)
        end
    end)

    pcall(function()
        attempted = true
        prompt:InputHoldBegin()
        task.wait(
            math.max(
                0.05,
                tonumber(prompt.HoldDuration) or 0
            ) + 0.08
        )
        prompt:InputHoldEnd()
    end)

    local key = prompt.KeyboardKeyCode

    if key ~= Enum.KeyCode.Unknown then
        pcall(function()
            attempted = true
            local input = self.Ctx.Services.VirtualInputManager
            input:SendKeyEvent(true, key, false, game)
            task.wait(
                math.max(
                    0.08,
                    tonumber(prompt.HoldDuration) or 0
                ) + 0.08
            )
            input:SendKeyEvent(false, key, false, game)
        end)
    end

    mode.Starting = false

    return attempted,
        attempted
        and nil
        or "cannot trigger ProximityPrompt"
end

function World:GuiVisible(object)
    if not object
        or not object:IsA("GuiObject")
        or not object.Visible then
        return false
    end

    local ownGui = uiGui(self)

    if ownGui and object:IsDescendantOf(ownGui) then
        return false
    end

    local node = object.Parent

    while node do
        if node:IsA("GuiObject") and not node.Visible then
            return false
        end

        if node:IsA("LayerCollector") and not node.Enabled then
            return false
        end

        node = node.Parent
    end

    return object.AbsoluteSize.X > 0
        and object.AbsoluteSize.Y > 0
end

function World:GuiColor(object)
    if not object or not object:IsA("GuiObject") then
        return nil
    end

    local stroke = object:FindFirstChildOfClass("UIStroke")

    if stroke
        and stroke.Enabled
        and stroke.Transparency < 0.98 then
        return stroke.Color
    end

    if object:IsA("ImageLabel") or object:IsA("ImageButton") then
        if object.ImageTransparency < 0.98 then
            return object.ImageColor3
        end
    end

    if object.BackgroundTransparency < 0.98 then
        return object.BackgroundColor3
    end

    return nil
end

function World:IsWhite(object)
    local color = self:GuiColor(object)
    if not color then return false end

    local high = math.max(color.R, color.G, color.B)
    local low = math.min(color.R, color.G, color.B)

    return low >= 0.56
        and (high - low) <= 0.22
end

function World:IsLightTarget(object)
    local color = self:GuiColor(object)
    if not color then return false end

    local high = math.max(color.R, color.G, color.B)
    local low = math.min(color.R, color.G, color.B)

    return low >= 0.18
        and (high - low) <= 0.34
end

function World:IsRoundish(object)
    local size = object.AbsoluteSize

    if size.X < 8
        or size.Y < 8
        or size.X > 180
        or size.Y > 180 then
        return false
    end

    local ratio = size.X / math.max(size.Y, 1)

    if ratio < 0.62 or ratio > 1.38 then
        return false
    end

    return object:IsA("ImageLabel")
        or object:IsA("ImageButton")
        or object:FindFirstChildOfClass("UICorner") ~= nil
        or object:FindFirstChildOfClass("UIStroke") ~= nil
end

function World:ScanGuiObjects()
    local out = {}
    local seen = {}

    local roots = {
        self.Ctx.Player:FindFirstChildOfClass("PlayerGui"),
    }

    local _, _, pushups = self:PushupPrompt()

    if pushups then
        table.insert(roots, pushups)
    end

    if workspace.CurrentCamera then
        table.insert(roots, workspace.CurrentCamera)
    end

    local coreGui = game:GetService("CoreGui")
    if coreGui then table.insert(roots, coreGui) end

    for _, root in ipairs(roots) do
        if root then
            for _, object in ipairs(root:GetDescendants()) do
                if object:IsA("GuiObject") and not seen[object] then
                    seen[object] = true
                    table.insert(out, object)
                end
            end
        end
    end

    return out
end

function World:ReadProgress(objects)
    local best

    for _, object in ipairs(objects or self:ScanGuiObjects()) do
        if (
            object:IsA("TextLabel")
            or object:IsA("TextButton")
        ) and self:GuiVisible(object) then

            local value =
                tonumber(
                    tostring(object.Text or "")
                        :match("(%d+)%s*%%")
                )

            if value
                and value >= 0
                and value <= 100 then
                best = math.max(best or 0, value)
            end
        end
    end

    return best
end

function World:ClickObject(object)
    if not object or not object.Parent then
        return false
    end

    local position = object.AbsolutePosition
    local size = object.AbsoluteSize

    local x = math.floor(position.X + size.X * 0.5)
    local y = math.floor(position.Y + size.Y * 0.5)

    local input = self.Ctx.Services.VirtualInputManager

    return pcall(function()
        input:SendMouseMoveEvent(x, y, game)
        task.wait(0.012)
        input:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.025)
        input:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

function World:FindPushupTargets(objects)
    local camera = workspace.CurrentCamera
    if not camera then return {}, {} end

    local viewport = camera.ViewportSize
    local outers = {}
    local inners = {}
    local white = {}

    for _, object in ipairs(objects) do
        if object:IsA("GuiObject")
            and self:GuiVisible(object)
            and self:IsRoundish(object) then

            local position = object.AbsolutePosition
            local size = object.AbsoluteSize
            local cx = position.X + size.X * 0.5
            local cy = position.Y + size.Y * 0.5

            if cx >= viewport.X * 0.035
                and cx <= viewport.X * 0.965
                and cy >= viewport.Y * 0.08
                and cy <= viewport.Y * 0.88 then

                if self:IsWhite(object) then
                    table.insert(outers, object)
                    table.insert(white, object)
                end

                if self:IsLightTarget(object) then
                    table.insert(inners, object)
                end
            end
        end
    end

    local pairsFound = {}

    for _, outer in ipairs(outers) do
        local op = outer.AbsolutePosition
        local os = outer.AbsoluteSize
        local center =
            Vector2.new(
                op.X + os.X * 0.5,
                op.Y + os.Y * 0.5
            )

        local bestInner
        local bestScore

        for _, inner in ipairs(inners) do
            if inner ~= outer then
                local ip = inner.AbsolutePosition
                local isz = inner.AbsoluteSize
                local innerCenter =
                    Vector2.new(
                        ip.X + isz.X * 0.5,
                        ip.Y + isz.Y * 0.5
                    )

                local distance = (center - innerCenter).Magnitude
                local outerD = math.max(os.X, os.Y)
                local innerD = math.max(isz.X, isz.Y)
                local ratio = outerD / math.max(innerD, 1)

                if distance <= math.max(18, innerD * 0.5)
                    and ratio >= 0.65
                    and ratio <= 4.2 then

                    local score =
                        distance * 4
                        + math.abs(ratio - 1.45) * 7

                    if not bestScore or score < bestScore then
                        bestInner = inner
                        bestScore = score
                    end
                end
            end
        end

        if bestInner then
            table.insert(pairsFound, {
                Outer = outer,
                Inner = bestInner,
            })
        end
    end

    return pairsFound, white
end

function World:SetCupEnabled(on)
    return self:SetCupGame(on)
end

function World:SetPushupsEnabled(on)
    return self:SetPushups(on)
end

function World:SetThunderEnabled(on)
    return self:SetThunder(on)
end

function World:SetPushups(on)
    if not on then tele(self):Cancel("World") end
    local mode = self.Pushups
    on = on == true

    if mode.Enabled == on then return end

    mode.Enabled = on
    mode.NextAt = 0
    mode.LastClickAt = 0
    mode.Clicks = 0
    mode.Progress = 0
    mode.StartTried = false
    mode.Starting = false
    mode.LastStartAttempt = -math.huge
    mode.PromptState = setmetatable({}, { __mode = "k" })
    mode.RingState = setmetatable({}, { __mode = "k" })

    if on then
        task.defer(function()
            if not mode.Enabled or mode.StartTried then return end

            mode.StartTried = true

            local ok, err = self:StartPushupTraining()

            if mode.Enabled then
                self:SetStatus(
                    mode,
                    ok
                        and "Auto Pushups • เปิด PushupMat1 แล้ว • รอวงกลม"
                        or ("Auto Pushups • " .. tostring(err))
                )
            end
        end)
    else
        self:SetStatus(mode, "Auto Pushups • OFF")
    end
end

function World:PushupStep()
    local mode = self.Pushups
    if not mode.Enabled then return end

    local now = os.clock()

    if now < mode.NextAt then return end
    mode.NextAt = now + 0.008

    local objects = self:ScanGuiObjects()
    local progress = self:ReadProgress(objects) or mode.Progress or 0
    mode.Progress = math.max(mode.Progress or 0, progress)

    local pairsFound, white =
        self:FindPushupTargets(objects)

    local clicked = 0

    for _, pair in ipairs(pairsFound) do
        local outer = pair.Outer
        local inner = pair.Inner

        if outer.Parent and inner.Parent then
            local outerD =
                math.max(
                    outer.AbsoluteSize.X,
                    outer.AbsoluteSize.Y
                )
            local innerD =
                math.max(
                    inner.AbsoluteSize.X,
                    inner.AbsoluteSize.Y
                )
            local diff = math.abs(outerD - innerD)

            local state = mode.PromptState[outer]

            if not state then
                state = {
                    Armed = true,
                    LastDiff = math.huge,
                    ClickedAt = 0,
                }
                mode.PromptState[outer] = state
            end

            if diff >= math.max(18, innerD * 0.38)
                or diff > state.LastDiff + 5 then
                state.Armed = true
            end

            state.LastDiff = diff

            local tolerance = math.max(8, innerD * 0.24)

            if diff <= tolerance
                and state.Armed
                and now - state.ClickedAt >= 0.10 then

                if self:ClickObject(inner) then
                    state.Armed = false
                    state.ClickedAt = now
                    mode.LastClickAt = now
                    mode.Clicks += 1
                    clicked += 1
                end
            end
        end
    end

    if #pairsFound == 0 and #white == 0 then
        if progress <= 0
            and not mode.Starting
            and now - mode.LastStartAttempt >= 3 then

            task.spawn(function()
                local ok, err = self:StartPushupTraining()

                if mode.Enabled then
                    self:SetStatus(
                        mode,
                        ok
                            and "Auto Pushups • กด Prompt แล้ว • รอวงกลม"
                            or ("Auto Pushups • " .. tostring(err))
                    )
                end
            end)
        else
            self:SetStatus(
                mode,
                "Auto Pushups • "
                    .. tostring(progress)
                    .. "% • รอวง"
            )
        end

        return
    end

    self:SetStatus(
        mode,
        clicked > 0
            and (
                "Auto Pushups • "
                .. tostring(progress)
                .. "% • CLICK #"
                .. tostring(mode.Clicks)
            )
            or (
                "Auto Pushups • "
                .. tostring(progress)
                .. "% • จับจังหวะ"
            )
    )
end

-- Thunder -----------------------------------------------------

function World:SetThunder(on)
    if not on then tele(self):Cancel("World") end
    local mode = self.Thunder
    on = on == true

    if mode.Enabled == on then return end

    local f = self.Ctx.Modules.Farm
    local quest = self.Ctx.Modules.Quest
    local combat = self.Ctx.Modules.Combat

    if on then
        if quest and quest.Active then
            quest:StopAll(nil)
        end

        if f and f.Enabled then
            f:Stop()
        end

        if f then
            f._storyBusy = true
        end

        if combat and combat.Release then
            pcall(function()
                combat:Release()
            end)
        end
    elseif f then
        f._storyBusy = false
    end

    mode.Enabled = on
    mode.Phase = "trainer"
    mode.NextAt = 0
    mode.Character = nil
    mode.Root = nil
    mode.Clicks = 0
    mode.Armed = true
    mode.LastClickAt = 0
    mode.LastSeenAt = 0
    mode.NextScanAt = 0
    mode.LastPairKey = nil
    mode.Progress = 0

    self:SetStatus(
        mode,
        on
            and "ปราณสายฟ้า • ไปหา Zentaro"
            or "ปราณสายฟ้า • OFF"
    )
end

function World:FindTimingPair()
    local playerGui =
        self.Ctx.Player:FindFirstChildOfClass("PlayerGui")

    if not playerGui then return nil end

    local markers = {}
    local targets = {}

    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("GuiObject")
            and self:GuiVisible(object) then

            local color = self:GuiColor(object)

            if color then
                local size = object.AbsoluteSize
                local r, g, b = color.R, color.G, color.B

                local nearWhite =
                    r >= 0.72
                    and g >= 0.72
                    and b >= 0.72

                local yellow =
                    r >= 0.68
                    and g >= 0.52
                    and b <= 0.62
                    and r >= b + 0.10

                local blue =
                    b >= 0.58
                    and g >= 0.45
                    and b >= r + 0.04

                local cyan =
                    g >= 0.62
                    and b >= 0.62
                    and r <= math.max(g, b) - 0.04

                local markerShape =
                    size.X >= 8
                    and size.X <= 70
                    and size.Y >= 8
                    and size.Y <= 70

                if markerShape
                    and (
                        blue
                        or cyan
                        or nearWhite
                    ) then
                    table.insert(markers, object)
                end

                local thin =
                    size.X >= 1
                    and size.X <= 22
                    and size.Y >= 6
                    and size.Y <= 100

                local hitZone =
                    size.X >= 8
                    and size.X <= 150
                    and size.Y >= 4
                    and size.Y <= 45

                if (thin or hitZone)
                    and (yellow or nearWhite) then
                    table.insert(targets, object)
                end
            end
        end
    end

    local bestMarker
    local bestTarget
    local bestScore

    for _, marker in ipairs(markers) do
        local mp = marker.AbsolutePosition
        local ms = marker.AbsoluteSize
        local mx = mp.X + ms.X * 0.5
        local my = mp.Y + ms.Y * 0.5

        for _, target in ipairs(targets) do
            if target ~= marker then
                local tp = target.AbsolutePosition
                local ts = target.AbsoluteSize
                local tx = tp.X + ts.X * 0.5
                local ty = tp.Y + ts.Y * 0.5

                local dx = math.abs(mx - tx)
                local dy = math.abs(my - ty)
                local score = dy * 2 + dx * 0.004

                if dy <= math.max(38, ms.Y * 1.6)
                    and dx <= 900
                    and (
                        not bestScore
                        or score < bestScore
                    ) then
                    bestMarker = marker
                    bestTarget = target
                    bestScore = score
                end
            end
        end
    end

    return bestMarker, bestTarget
end

function World:ThunderTimingStep()
    local mode = self.Thunder
    local now = os.clock()

    if now < mode.NextScanAt then return end
    mode.NextScanAt = now + 0.008

    local progress = self:ReadProgress()
    if progress then
        mode.Progress = math.max(mode.Progress or 0, progress)
    end

    if mode.Progress >= 100 and mode.Clicks > 0 then
        self:SetThunder(false)
        self:SetStatus(mode, "ปราณสายฟ้า • 100% • DONE")
        return
    end

    local marker, target = self:FindTimingPair()

    if not marker or not target then
        if mode.LastSeenAt > 0
            and now - mode.LastSeenAt > 0.08 then

            mode.Armed = true
            mode.LastPairKey = nil
        end
        return
    end

    mode.LastSeenAt = now

    local key = tostring(marker) .. "|" .. tostring(target)

    if key ~= mode.LastPairKey then
        mode.LastPairKey = key
        mode.Armed = true
    end

    local mp = marker.AbsolutePosition
    local ms = marker.AbsoluteSize
    local tp = target.AbsolutePosition
    local ts = target.AbsoluteSize

    local markerLeft = mp.X
    local markerRight = mp.X + ms.X
    local targetLeft = tp.X
    local targetRight = tp.X + ts.X

    local tolerance =
        math.max(
            5,
            math.min(16, ms.X * 0.45)
        )

    local inside =
        markerRight >= targetLeft - tolerance
        and markerLeft <= targetRight + tolerance

    if not inside then
        mode.Armed = true
        return
    end

    if not mode.Armed
        or now - mode.LastClickAt < 0.065 then
        return
    end

    mode.Armed = false
    mode.LastClickAt = now
    mode.Clicks += 1

    self:ClickObject(target)

    self:SetStatus(
        mode,
        "ปราณสายฟ้า • "
            .. tostring(mode.Progress or 0)
            .. "% • คลิก #"
            .. tostring(mode.Clicks)
    )
end

function World:ThunderStep()
    local mode = self.Thunder
    if not mode.Enabled then return end

    local now = os.clock()

    if now < mode.NextAt then return end

    local char = self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if not root or not hum or hum.Health <= 0 then
        self:SetStatus(mode, "ปราณสายฟ้า • รอตัวละครพร้อม")
        return
    end

    if inputBlocked(self) then
        return
    end

    local tp = tele(self)

    if mode.Phase == "trainer" then
        local destination =
            tp
            and tp:Destination("Thunder Trainer Zentaro")

        if not destination then
            mode.NextAt = now + 1
            return
        end

        tp:SoftGoOwned("World",destination)
        mode.Phase = "talk"
        mode.NextAt = now + 0.45
        return
    end

    if mode.Phase == "talk" then
        local event = signal(self)

        if not event then
            mode.NextAt = now + 1
            return
        end

        event:FireServer("NpcTalking", "Ended")
        mode.Phase = "accept"
        mode.NextAt = now + 0.2
        return
    end

    if mode.Phase == "accept" then
        local event = signal(self)

        if not event then
            mode.NextAt = now + 1
            return
        end

        event:FireServer(
            "AddQuest",
            "Ill learn Thunder Breathing(Lv 25)"
        )

        mode.Phase = "training"
        mode.NextAt = now + 0.35
        return
    end

    if mode.Phase == "training" then
        local destination =
            tp
            and tp:Destination("Thunder Trainer Zentaro")

        if destination then
            tp:SoftGoOwned("World",destination * CFrame.new(0, 0, -5))
        end

        mode.Phase = "minigame"
        mode.NextAt = now + 0.55
        return
    end

    if mode.Phase == "minigame" then
        self:ThunderTimingStep()
    end
end

function World:Init(ctx)
    self.Ctx = ctx
    self.Cup = self.CupGame
end

function World:Start()
    self.Ctx:RegisterJob("WorldCup", 0.05, function()
        self:CupStep()
    end)

    self.Ctx:RegisterJob("WorldPushups", 0.01, function()
        self:PushupStep()
    end)

    self.Ctx:RegisterJob("WorldThunder", 0.01, function()
        self:ThunderStep()
    end)
end

function World:Stop()
    self:SetCupGame(false)
    self:SetPushups(false)
    self:SetThunder(false)
end

return World

]====]
BUNDLED_SOURCES["visuals.lua"] = [====[
-- MazxhubModules/visuals.lua
-- Player/NPC/Boss ESP migrated from hello.txt

local Visuals = {
    Enabled = false,
    Lines = false,
    Outlines = false,
    Color = Color3.fromRGB(139, 124, 246),
    OutlineColor = Color3.fromRGB(255, 255, 255),
    MaxDistance = 1000,
    ShowDistance = true,
    HideWhenAiming = false,
    LabelScale = 1,
    LabelLayout = "Stacked",

    Bandit = false,
    Civilian = false,
    BossEnabled = false,
    BossSelected = {},
    MonsterHitboxESP = false,
    MonsterBoxColor = Color3.fromRGB(255, 220, 75),
    MonsterBoxes = {},

    PlayerCache = {},
    NPCCache = {},
    NextScanAt = 0,
}

local NPC_REGIONS = {
    "Windy Peak",
    "Misc",
    "Bamboo Grove",
    "Temporary",
    "Mistfall Harbor",
    "Iceveil Valley",
}

local NPC_COLORS = {
    Bandit = Color3.fromRGB(255, 90, 90),
    Civilian = Color3.fromRGB(110, 231, 183),
}

local GOLD = Color3.fromRGB(198, 179, 134)

local function rootOf(model)
    return model
        and (
            model:FindFirstChild("HumanoidRootPart", true)
            or model.PrimaryPart
            or model:FindFirstChildWhichIsA("BasePart", true)
        )
end

local function headOf(model)
    return model
        and (
            model:FindFirstChild("Head", true)
            or rootOf(model)
        )
end

local function alive(model)
    if not model or not model.Parent then return false end
    local hum = model:FindFirstChildWhichIsA("Humanoid", true)
    return hum == nil or hum.Health > 0
end

function Visuals:CreateLine(color)
    local line = Instance.new("Frame")
    line.Name = "MazxESPLine"
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.BackgroundColor3 = color
    line.BorderSizePixel = 0
    line.Visible = false
    line.Active = false
    line.ZIndex = 1
    line.Parent = self.LineLayer
    return line
end

function Visuals:UpdateLine(line, root, enabled, maxDistance, camera)
    if not line then return end
    line.Visible = false

    if not enabled
        or not camera
        or not root
        or not root.Parent then
        return
    end

    local distance =
        (camera.CFrame.Position - root.Position).Magnitude

    if distance > maxDistance then return end

    local point, onScreen =
        camera:WorldToViewportPoint(root.Position)

    if not onScreen or point.Z <= 0 then return end

    local origin = Vector2.new(
        camera.ViewportSize.X * 0.5,
        camera.ViewportSize.Y - 2
    )

    local target = Vector2.new(point.X, point.Y)
    local delta = target - origin

    if delta.Magnitude < 1 then return end

    local middle = (origin + target) * 0.5

    line.Position =
        UDim2.fromOffset(middle.X, middle.Y)

    line.Size =
        UDim2.fromOffset(delta.Magnitude, 2)

    line.Rotation =
        math.deg(math.atan2(delta.Y, delta.X))

    line.Visible = true
end

function Visuals:ClearPlayer(player)
    local data = self.PlayerCache[player]
    if not data then return end

    for _, object in pairs(data) do
        if typeof(object) == "Instance" then
            pcall(function() object:Destroy() end)
        end
    end

    self.PlayerCache[player] = nil
end

function Visuals:MakePlayer(player)
    if player == self.Ctx.Player then return end

    self:ClearPlayer(player)

    if not self.Enabled
        and not self.Lines
        and not self.Outlines then
        return
    end

    local char = player.Character
    local root = rootOf(char)
    local head = headOf(char)

    if not char or not root or not head then
        return
    end

    local data = {
        Character = char,
    }

    local highlight = Instance.new("Highlight")
    highlight.Name = "MazxPlayerESP"
    highlight.Adornee = char
    highlight.FillColor = self.Color
    highlight.FillTransparency = 0.75
    highlight.OutlineColor = self.OutlineColor
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = self.Outlines
    highlight.Parent = char
    data.Highlight = highlight

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MazxPlayerESPTag"
    billboard.Adornee = head
    billboard.Size = UDim2.fromOffset(200, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = self.MaxDistance
    billboard.Enabled = self.Enabled
    billboard.Parent = char
    data.Billboard = billboard

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = self.Color
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard
    data.NameLabel = nameLabel

    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distanceLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distanceLabel.Text = ""
    distanceLabel.TextColor3 = Color3.new(1, 1, 1)
    distanceLabel.TextStrokeTransparency = 0
    distanceLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distanceLabel.TextSize = 12
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.Parent = billboard
    data.DistanceLabel = distanceLabel

    data.Line = self:CreateLine(self.Color)

    self.PlayerCache[player] = data
end

function Visuals:NPCFolder(region)
    local node = workspace

    for _, name in ipairs({
        "Humanoids",
        "Regions",
        region,
        "ActiveNpcs",
    }) do
        node = node and node:FindFirstChild(name)
        if not node then return nil end
    end

    return node
end

function Visuals:NPCType(root, folder)
    local boss = self.Ctx.Modules.Boss
    local bossNames = {}

    for _, name in ipairs(boss and boss.Names or {}) do
        bossNames[name:lower()] = name
    end

    local node = root and root.Parent

    while node and node ~= folder do
        local lower = node.Name:lower()

        if lower == "bandit" then
            return "Bandit"
        end

        if lower == "civilian" then
            return "Civilian"
        end

        if bossNames[lower] then
            return bossNames[lower]
        end

        node = node.Parent
    end

    return nil
end

function Visuals:NPCEnabled(kind)
    if kind == "Bandit" then
        return self.Bandit
    end

    if kind == "Civilian" then
        return self.Civilian
    end

    if self.BossSelected[kind] ~= nil then
        return self.BossEnabled
            and self.BossSelected[kind]
    end

    return false
end

function Visuals:ClearNPC(root)
    local data = self.NPCCache[root]
    if not data then return end

    for _, object in pairs(data) do
        if typeof(object) == "Instance" then
            pcall(function() object:Destroy() end)
        end
    end

    self.NPCCache[root] = nil
end

function Visuals:MakeNPC(root, kind)
    if not root or not root.Parent then return end
    if self.NPCCache[root] then return end

    local model =
        root.Parent:IsA("Model")
        and root.Parent
        or root

    local color =
        NPC_COLORS[kind]
        or GOLD

    local highlight = Instance.new("Highlight")
    highlight.Name = "MazxNpcESP"
    highlight.Adornee = model
    highlight.FillColor = color
    highlight.FillTransparency = 0.72
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = model

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MazxNpcESPTag"
    billboard.Adornee = root
    billboard.Size = UDim2.fromOffset(180, 42)
    billboard.StudsOffset = Vector3.new(0, 3.2, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = self.MaxDistance
    billboard.Parent = root

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.fromScale(1, 1)
    text.Text = kind
    text.TextColor3 = color
    text.TextStrokeTransparency = 0
    text.TextStrokeColor3 = Color3.new(0, 0, 0)
    text.TextSize = 14
    text.Font = Enum.Font.GothamBold
    text.Parent = billboard

    self.NPCCache[root] = {
        Kind = kind,
        Highlight = highlight,
        Billboard = billboard,
        Label = text,
        Line = self:CreateLine(color),
    }
end

function Visuals:RefreshPlayers()
    local players = self.Ctx.Services.Players

    for _, player in ipairs(players:GetPlayers()) do
        if player ~= self.Ctx.Player then
            local data = self.PlayerCache[player]

            if not data
                or data.Character ~= player.Character then
                self:MakePlayer(player)
            end
        end
    end

    for player in pairs(self.PlayerCache) do
        if not player.Parent
            or (
                not self.Enabled
                and not self.Lines
                and not self.Outlines
            ) then

            self:ClearPlayer(player)
        end
    end
end

function Visuals:RefreshNPCs()
    if not self.Bandit
        and not self.Civilian
        and not self.BossEnabled then

        for root in pairs(self.NPCCache) do
            self:ClearNPC(root)
        end
        return
    end

    local seen = {}

    for _, region in ipairs(NPC_REGIONS) do
        local folder = self:NPCFolder(region)

        if folder then
            for _, item in ipairs(folder:GetDescendants()) do
                if item:IsA("BasePart")
                    and item.Name == "HumanoidRootPart" then

                    local kind = self:NPCType(item, folder)

                    if kind then
                        seen[item] = true

                        if self:NPCEnabled(kind)
                            and alive(item.Parent) then

                            self:MakeNPC(item, kind)
                        else
                            self:ClearNPC(item)
                        end
                    end
                end
            end
        end
    end

    for root, data in pairs(self.NPCCache) do
        if not root.Parent
            or not seen[root]
            or not self:NPCEnabled(data.Kind) then

            self:ClearNPC(root)
        end
    end
end

-- Draw the actual HumanoidRootPart bounds without changing collision or damage.
function Visuals:ClearMonsterBoxes()
    for root, box in pairs(self.MonsterBoxes) do
        if box then box:Destroy() end
        self.MonsterBoxes[root] = nil
    end
end

function Visuals:RefreshMonsterBoxes()
    if not self.MonsterHitboxESP then
        self:ClearMonsterBoxes()
        return
    end

    local seen = {}
    for _, region in ipairs(NPC_REGIONS) do
        local folder = self:NPCFolder(region)
        if folder then
            for _, root in ipairs(folder:GetDescendants()) do
                if root:IsA("BasePart") and root.Name == "HumanoidRootPart" then
                    local model = root:FindFirstAncestorOfClass("Model")
                    local hum = model and model:FindFirstChildWhichIsA("Humanoid", true)
                    local lower = model and model.Name:lower() or ""
                    if hum and hum.Health > 0 and lower ~= "civilian" then
                        seen[root] = true
                        if not self.MonsterBoxes[root] then
                            local box = Instance.new("SelectionBox")
                            box.Name = "MazaMonsterHitboxBox"
                            box.Adornee = root
                            box.Color3 = self.MonsterBoxColor
                            box.SurfaceTransparency = 1
                            box.LineThickness = 0.05
                            box.Parent = root
                            self.MonsterBoxes[root] = box
                        end
                    end
                end
            end
        end
    end
    for root, box in pairs(self.MonsterBoxes) do
        if not seen[root] or not root.Parent then
            box:Destroy()
            self.MonsterBoxes[root] = nil
        end
    end
end

function Visuals:Render()
    local camera = workspace.CurrentCamera
    if not camera then return end

    local input = self.Ctx.Services.UserInputService
    local aiming =
        self.HideWhenAiming
        and input
        and input:IsMouseButtonPressed(
            Enum.UserInputType.MouseButton2
        )

    for root, box in pairs(self.MonsterBoxes) do
        if root.Parent and box.Parent then
            local distance = (camera.CFrame.Position - root.Position).Magnitude
            box.Visible = self.MonsterHitboxESP
                and distance <= self.MaxDistance
                and not aiming
            box.Color3 = self.MonsterBoxColor
        end
    end

    for player, data in pairs(self.PlayerCache) do
        local char = player.Character
        local root = rootOf(char)
        local hum =
            char
            and char:FindFirstChildOfClass("Humanoid")

        local valid =
            root ~= nil
            and char == data.Character
            and (not hum or hum.Health > 0)

        local distance =
            valid
            and (
                camera.CFrame.Position
                - root.Position
            ).Magnitude
            or math.huge

        local visible =
            valid
            and distance <= self.MaxDistance

        if data.Billboard then
            data.Billboard.Enabled =
                visible and self.Enabled and not aiming
            data.Billboard.MaxDistance =
                self.MaxDistance
        end

        if data.Highlight then
            data.Highlight.Enabled =
                visible and self.Outlines and not aiming

            data.Highlight.FillColor = self.Color
            data.Highlight.OutlineColor =
                self.OutlineColor
        end

        if data.Billboard then
            local scale = math.clamp(
                tonumber(self.LabelScale) or 1,
                0.5,
                2
            )

            if self.LabelLayout == "Inline" then
                data.Billboard.Size =
                    UDim2.fromOffset(
                        math.floor(240 * scale),
                        math.floor(28 * scale)
                    )
            elseif self.LabelLayout == "Compact" then
                data.Billboard.Size =
                    UDim2.fromOffset(
                        math.floor(170 * scale),
                        math.floor(22 * scale)
                    )
            else
                data.Billboard.Size =
                    UDim2.fromOffset(
                        math.floor(200 * scale),
                        math.floor(50 * scale)
                    )
            end
        end

        if data.NameLabel then
            local scale = math.clamp(
                tonumber(self.LabelScale) or 1,
                0.5,
                2
            )

            data.NameLabel.TextColor3 = self.Color
            data.NameLabel.TextSize =
                math.floor(
                    (self.LabelLayout == "Compact" and 11 or 14)
                    * scale
                )

            if self.LabelLayout == "Stacked" then
                data.NameLabel.Position = UDim2.new()
                data.NameLabel.Size = UDim2.new(1, 0, 0.5, 0)
                data.NameLabel.Text = player.Name
            else
                data.NameLabel.Position = UDim2.new()
                data.NameLabel.Size = UDim2.fromScale(1, 1)
                data.NameLabel.Text =
                    player.Name
                    .. (
                        self.ShowDistance
                        and visible
                        and string.format(
                            "  [%d]",
                            math.floor(distance)
                        )
                        or ""
                    )
            end
        end

        if data.DistanceLabel then
            local stacked =
                self.LabelLayout == "Stacked"

            data.DistanceLabel.Visible =
                stacked
                and self.ShowDistance
                and not aiming

            data.DistanceLabel.TextSize =
                math.floor(
                    12
                    * math.clamp(
                        tonumber(self.LabelScale) or 1,
                        0.5,
                        2
                    )
                )

            if visible
                and self.ShowDistance
                and stacked then
                data.DistanceLabel.Text =
                    string.format(
                        "[%d studs]",
                        math.floor(distance)
                    )
            end
        end

        if data.Line then
            data.Line.BackgroundColor3 = self.Color
            self:UpdateLine(
                data.Line,
                root,
                visible and self.Lines and not aiming,
                self.MaxDistance,
                camera
            )
        end
    end

    for root, data in pairs(self.NPCCache) do
        local visible = false

        if root.Parent then
            local hum =
                root.Parent:FindFirstChildWhichIsA(
                    "Humanoid",
                    true
                )

            local distance =
                (
                    camera.CFrame.Position
                    - root.Position
                ).Magnitude

            visible =
                self:NPCEnabled(data.Kind)
                and distance <= self.MaxDistance
                and (not hum or hum.Health > 0)

            if data.Label then
                data.Label.Text =
                    string.format(
                        "%s  [%d studs]",
                        data.Kind,
                        math.floor(distance)
                    )
            end
        end

        if data.Billboard then
            data.Billboard.Enabled = visible and not aiming
            data.Billboard.MaxDistance =
                self.MaxDistance
        end

        if data.Highlight then
            data.Highlight.Enabled = visible and not aiming
        end

        self:UpdateLine(
            data.Line,
            root,
            visible and self.Lines and not aiming,
            self.MaxDistance,
            camera
        )
    end
end

function Visuals:SetPlayerESP(on)
    self.Enabled = on == true
    self.NextScanAt = 0
end

function Visuals:SetMonsterHitboxESP(on)
    self.MonsterHitboxESP = on == true
    self.NextScanAt = 0
    if not self.MonsterHitboxESP then self:ClearMonsterBoxes() end
end

function Visuals:SetLines(on)
    self.Lines = on == true
    self.NextScanAt = 0

    if not self.Lines then
        for _, data in pairs(self.PlayerCache) do
            if data.Line then data.Line.Visible = false end
        end

        for _, data in pairs(self.NPCCache) do
            if data.Line then data.Line.Visible = false end
        end
    end
end

function Visuals:SetOutlines(on)
    self.Outlines = on == true
    self.NextScanAt = 0
end

function Visuals:SetBandit(on)
    self.Bandit = on == true
    self.NextScanAt = 0
end

function Visuals:SetCivilian(on)
    self.Civilian = on == true
    self.NextScanAt = 0
end

function Visuals:SetBossEnabled(on)
    self.BossEnabled = on == true
    self.NextScanAt = 0
end

function Visuals:SetBossSelected(name, on)
    self.BossSelected[name] = on == true
    self.NextScanAt = 0
end

function Visuals:SetMaxDistance(value)
    self.MaxDistance =
        math.clamp(
            tonumber(value) or 1000,
            100,
            3000
        )
end

function Visuals:SetShowDistance(on)
    self.ShowDistance = on == true
end

function Visuals:SetHideWhenAiming(on)
    self.HideWhenAiming = on == true
end

function Visuals:SetLabelScale(value)
    self.LabelScale =
        math.clamp(
            tonumber(value) or 1,
            0.5,
            2
        )
end

function Visuals:SetLabelLayout(value)
    value = tostring(value or "Stacked")

    if value ~= "Stacked"
        and value ~= "Inline"
        and value ~= "Compact" then
        value = "Stacked"
    end

    self.LabelLayout = value
end

function Visuals:Step()
    local now = os.clock()

    if now >= self.NextScanAt then
        self.NextScanAt = now + 1.0
        self:RefreshPlayers()
        self:RefreshNPCs()
        self:RefreshMonsterBoxes()
    end

    self:Render()
end

function Visuals:Init(ctx)
    self.Ctx = ctx
    self.PlayerCache = {}
    self.NPCCache = {}
    self.MonsterBoxes = {}
    self.BossSelected = {}

    local boss = ctx.Modules.Boss

    for _, name in ipairs(boss and boss.Names or {}) do
        self.BossSelected[name] = true
    end

    local playerGui =
        ctx.Player:WaitForChild("PlayerGui")

    local old =
        playerGui:FindFirstChild("MazxhubESPOverlay")

    if old then old:Destroy() end

    self.Gui = Instance.new("ScreenGui")
    self.Gui.Name = "MazxhubESPOverlay"
    self.Gui.ResetOnSpawn = false
    self.Gui.IgnoreGuiInset = true
    self.Gui.DisplayOrder = 10
    self.Gui.Parent = playerGui

    self.LineLayer = Instance.new("Frame")
    self.LineLayer.Name = "Lines"
    self.LineLayer.Size = UDim2.fromScale(1, 1)
    self.LineLayer.BackgroundTransparency = 1
    self.LineLayer.Active = false
    self.LineLayer.Parent = self.Gui
end

function Visuals:Start()
    self.Ctx:RegisterJob(
        "Visuals",
        0.03,
        function()
            self:Step()
        end
    )
end

function Visuals:Stop()
    self.Enabled = false
    self.Lines = false
    self.Outlines = false
    self.Bandit = false
    self.Civilian = false
    self.BossEnabled = false
    self.MonsterHitboxESP = false
    self:ClearMonsterBoxes()

    for player in pairs(self.PlayerCache) do
        self:ClearPlayer(player)
    end

    for root in pairs(self.NPCCache) do
        self:ClearNPC(root)
    end

    if self.Gui then
        self.Gui:Destroy()
        self.Gui = nil
    end
end

return Visuals
]====]
BUNDLED_SOURCES["aimbot.lua"] = [====[
-- MazxhubModules/aimbot.lua
-- Aimbot / FOV migrated from hello.txt

local Aimbot = {
    Enabled = false,
    SkillEnabled = false,
    ShowFOV = false,
    FOV = 180,
    TargetPlayers = true,
    TargetNPCs = true,
    AltCenter = false,
    RightMouseHeld = false,
    SkillHeld = {},
    SkillKeys = {
        Z = true,
        X = true,
        C = true,
        V = true,
        B = true,
        N = true,
        K = true,
    },
    NPCs = {},
    NextNPCScan = 0,
    Target = nil,
    Connections = {},
    FOVSegments = {},
    FOVSegmentCount = 72,
    FOVConnection = nil,
    RenderName = nil,
}

local function rootOf(model)
    if not model then return nil end

    return model:FindFirstChild("Head", true)
        or model:FindFirstChild("HumanoidRootPart", true)
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
end

local function alive(model)
    if not model or not model.Parent then return false end
    local hum = model:FindFirstChildWhichIsA("Humanoid", true)
    return hum ~= nil and hum.Health > 0
end

function Aimbot:FOVCenter(camera)
    if self.AltCenter and camera then
        return Vector2.new(
            camera.ViewportSize.X * 0.5,
            camera.ViewportSize.Y * 0.5
        )
    end

    return self.Ctx.Services.UserInputService:GetMouseLocation()
end

function Aimbot:RefreshNPCs()
    local out = {}
    local root = workspace:FindFirstChild("Humanoids")

    if root then
        for _, hum in ipairs(root:GetDescendants()) do
            if hum:IsA("Humanoid") and hum.Health > 0 then
                local model = hum.Parent
                local selfChar = self.Ctx.Player.Character
                local isSelf =
                    selfChar
                    and model
                    and (
                        model == selfChar
                        or model:IsDescendantOf(selfChar)
                        or selfChar:IsDescendantOf(model)
                    )

                local part =
                    not isSelf
                    and rootOf(model)
                    or nil

                if part and part:IsA("BasePart") then
                    table.insert(out, {
                        Model = model,
                        Humanoid = hum,
                        Part = part,
                    })
                end
            end
        end
    end

    self.NPCs = out
    self.NextNPCScan = os.clock() + 0.5
end

function Aimbot:SkillActive()
    for key in pairs(self.SkillHeld) do
        if self.SkillKeys[key] then
            return true
        end
    end

    return false
end

function Aimbot:ShouldAim()
    if self.Enabled and self.RightMouseHeld then
        return true
    end

    if self.SkillEnabled
        and self.RightMouseHeld
        and self:SkillActive() then
        return true
    end

    return false
end

function Aimbot:CandidatePart(model)
    if not model or not model.Parent then return nil end

    return model:FindFirstChild("Head", true)
        or model:FindFirstChild("HumanoidRootPart", true)
        or model:FindFirstChildWhichIsA("BasePart", true)
end

function Aimbot:FindClosestTarget(camera)
    if not camera then return nil end

    local center = self:FOVCenter(camera)
    local best
    local bestDistance = self.FOV

    if self.TargetPlayers then
        for _, player in ipairs(
            self.Ctx.Services.Players:GetPlayers()
        ) do
            if player ~= self.Ctx.Player then
                local char = player.Character
                local hum =
                    char
                    and char:FindFirstChildOfClass("Humanoid")
                local part = self:CandidatePart(char)

                if hum
                    and hum.Health > 0
                    and part then

                    local point, visible =
                        camera:WorldToViewportPoint(
                            part.Position
                        )

                    if visible and point.Z > 0 then
                        local distance =
                            (
                                Vector2.new(
                                    point.X,
                                    point.Y
                                )
                                - center
                            ).Magnitude

                        if distance <= bestDistance then
                            bestDistance = distance
                            best = part
                        end
                    end
                end
            end
        end
    end

    if self.TargetNPCs then
        if os.clock() >= self.NextNPCScan then
            self:RefreshNPCs()
        end

        for _, record in ipairs(self.NPCs) do
            if record.Humanoid
                and record.Humanoid.Parent
                and record.Humanoid.Health > 0 then

                -- NPC parts can be replaced while the model is still alive.
                -- Refresh the preferred part instead of keeping a stale Head/HRP.
                local part =
                    self:CandidatePart(record.Model)
                    or record.Part

                record.Part = part

                if part and part.Parent then
                    local point, visible =
                        camera:WorldToViewportPoint(
                            part.Position
                        )

                    if visible and point.Z > 0 then
                        local distance =
                            (
                                Vector2.new(
                                    point.X,
                                    point.Y
                                )
                                - center
                            ).Magnitude

                        if distance <= bestDistance then
                            bestDistance = distance
                            best = part
                        end
                    end
                end
            end
        end
    end

    return best
end

function Aimbot:UpdateFOV(camera)
    if not self.FOVCircle then return end

    local visible = self.ShowFOV == true

    if not visible then
        self.FOVCircle.Visible = false

        if self.FOVCenterDot then
            self.FOVCenterDot.Visible = false
        end

        for _, segment in ipairs(self.FOVSegments or {}) do
            segment.Visible = false
        end

        return
    end

    if not camera then return end

    local center = self:FOVCenter(camera)
    local radius = math.max(10, tonumber(self.FOV) or 180)
    local diameter = radius * 2

    self.FOVCircle.Visible = true
    self.FOVCircle.Size =
        UDim2.fromOffset(diameter, diameter)
    self.FOVCircle.Position =
        UDim2.fromOffset(center.X, center.Y)

    if self.FOVCenterDot then
        self.FOVCenterDot.Visible = true
        self.FOVCenterDot.Position =
            UDim2.fromOffset(center.X, center.Y)
    end

    local count = math.max(
        8,
        tonumber(self.FOVSegmentCount) or 72
    )
    local arcLength =
        math.max(
            5,
            math.floor(
                (
                    2 * math.pi * radius / count
                ) * 0.82
            )
        )

    for index, segment in ipairs(self.FOVSegments or {}) do
        local angle =
            ((index - 1) / count)
            * math.pi
            * 2

        local x = center.X + math.cos(angle) * radius
        local y = center.Y + math.sin(angle) * radius

        segment.Visible = true
        segment.Position = UDim2.fromOffset(x, y)
        segment.Size = UDim2.fromOffset(arcLength, 2)
        segment.Rotation = math.deg(angle) + 90
    end
end

function Aimbot:Step()
    local camera = workspace.CurrentCamera
    if not camera then return end

    if not self:ShouldAim() then
        self.Target = nil
        return
    end

    local part = self:FindClosestTarget(camera)
    self.Target = part

    if not part or not part.Parent then
        return
    end

    local origin = camera.CFrame.Position
    local direction = part.Position - origin

    if direction.Magnitude <= 0.01 then
        return
    end

    camera.CFrame =
        CFrame.lookAt(
            origin,
            part.Position
        )
end

function Aimbot:SetEnabled(on)
    self.Enabled = on == true
end

function Aimbot:SetSkillEnabled(on)
    self.SkillEnabled = on == true
end

function Aimbot:SetShowFOV(on)
    self.ShowFOV = on == true

    if self.FOVCircle then
        self.FOVCircle.Visible = self.ShowFOV
    end

    if self.FOVCenterDot then
        self.FOVCenterDot.Visible = self.ShowFOV
    end

    for _, segment in ipairs(self.FOVSegments or {}) do
        segment.Visible = self.ShowFOV
    end
end

function Aimbot:SetFOV(value)
    self.FOV =
        math.clamp(
            math.floor(
                tonumber(value) or 180
            ),
            50,
            500
        )
end

function Aimbot:Init(ctx)
    self.Ctx = ctx
    self.Connections = {}
    self.SkillHeld = {}
    self.NPCs = {}
    self.NextNPCScan = 0

    local playerGui =
        ctx.Player:WaitForChild("PlayerGui")

    local old =
        playerGui:FindFirstChild("MazxhubAimbotOverlay")

    if old then old:Destroy() end

    self.Gui = Instance.new("ScreenGui")
    self.Gui.Name = "MazxhubAimbotOverlay"
    self.Gui.ResetOnSpawn = false
    self.Gui.IgnoreGuiInset = true
    self.Gui.DisplayOrder = 20
    self.Gui.Parent = playerGui

    self.FOVCircle = Instance.new("Frame")
    self.FOVCircle.Name = "AimbotFOV"
    self.FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    self.FOVCircle.Size =
        UDim2.fromOffset(
            self.FOV * 2,
            self.FOV * 2
        )
    self.FOVCircle.BackgroundColor3 =
        Color3.fromRGB(150, 220, 255)
    self.FOVCircle.BackgroundTransparency = 0.985
    self.FOVCircle.Visible = self.ShowFOV
    self.FOVCircle.Active = false
    self.FOVCircle.ZIndex = 80
    self.FOVCircle.Parent = self.Gui

    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = self.FOVCircle

    local circleStroke = Instance.new("UIStroke")
    circleStroke.Color =
        Color3.fromRGB(150, 220, 255)
    circleStroke.Thickness = 2
    circleStroke.Transparency = 0
    circleStroke.ApplyStrokeMode =
        Enum.ApplyStrokeMode.Border
    circleStroke.Parent = self.FOVCircle

    -- Some clients/executors do not render UIStroke reliably on a
    -- near-transparent rounded frame. Keep a segmented ring fallback.
    self.FOVSegments = {}

    for index = 1, self.FOVSegmentCount do
        local segment = Instance.new("Frame")
        segment.Name = "FOVSeg" .. tostring(index)
        segment.AnchorPoint = Vector2.new(0.5, 0.5)
        segment.Size = UDim2.fromOffset(12, 2)
        segment.BackgroundColor3 =
            Color3.fromRGB(150, 220, 255)
        segment.BackgroundTransparency = 0.05
        segment.BorderSizePixel = 0
        segment.Visible = self.ShowFOV
        segment.Active = false
        segment.ZIndex = 81
        segment.Parent = self.Gui

        table.insert(self.FOVSegments, segment)
    end

    self.FOVCenterDot = Instance.new("Frame")
    self.FOVCenterDot.Name = "FOVCenter"
    self.FOVCenterDot.AnchorPoint =
        Vector2.new(0.5, 0.5)
    self.FOVCenterDot.Size =
        UDim2.fromOffset(4, 4)
    self.FOVCenterDot.BackgroundColor3 =
        Color3.fromRGB(150, 220, 255)
    self.FOVCenterDot.BorderSizePixel = 0
    self.FOVCenterDot.Visible = self.ShowFOV
    self.FOVCenterDot.ZIndex = 82
    self.FOVCenterDot.Parent = self.Gui

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = self.FOVCenterDot

    local input = ctx.Services.UserInputService

    table.insert(
        self.Connections,
        input.InputBegan:Connect(function(event, processed)
            -- Alt only changes the visual/selection center and should still
            -- work even while another UI is consuming keyboard input.
            if event.KeyCode == Enum.KeyCode.LeftAlt
                or event.KeyCode == Enum.KeyCode.RightAlt then
                self.AltCenter = true
            end

            if processed then return end

            if event.UserInputType ==
                Enum.UserInputType.MouseButton2 then
                self.RightMouseHeld = true
            end

            local keyName = event.KeyCode.Name

            if self.SkillKeys[keyName] then
                self.SkillHeld[keyName] = true
            end
        end)
    )

    table.insert(
        self.Connections,
        input.InputEnded:Connect(function(event)
            if event.UserInputType ==
                Enum.UserInputType.MouseButton2 then
                self.RightMouseHeld = false
            end

            if event.KeyCode == Enum.KeyCode.LeftAlt
                or event.KeyCode == Enum.KeyCode.RightAlt then
                self.AltCenter = false
            end

            local keyName = event.KeyCode.Name

            if self.SkillKeys[keyName] then
                self.SkillHeld[keyName] = nil
            end
        end)
    )
end

function Aimbot:Start()
    local ctx = self.Ctx
    if not ctx then return end

    local runService = ctx.Services.RunService

    -- Remove the old Heartbeat job if this module is hot-reloaded from
    -- an earlier modular version.
    if type(ctx.RemoveJob) == "function" then
        ctx:RemoveJob("Aimbot")
    end

    if self.FOVConnection then
        pcall(function()
            self.FOVConnection:Disconnect()
        end)
        self.FOVConnection = nil
    end

    if self.RenderName then
        pcall(function()
            runService:UnbindFromRenderStep(
                self.RenderName
            )
        end)
    end

    self.RenderName =
        "MazxhubAimbot_"
        .. tostring(ctx.Player.UserId)

    -- Keep the FOV renderer independent from aiming. The guide remains
    -- responsive even when aiming is currently inactive.
    self.FOVConnection =
        runService.RenderStepped:Connect(function()
            if self.Gui and self.Gui.Parent then
                self:UpdateFOV(
                    workspace.CurrentCamera
                )
            end
        end)

    -- Run immediately after Roblox's normal camera update. Heartbeat can
    -- be overwritten by the camera script later in the same frame.
    runService:BindToRenderStep(
        self.RenderName,
        Enum.RenderPriority.Camera.Value + 1,
        function()
            if self.Gui and self.Gui.Parent then
                self:Step()
            end
        end
    )
end

function Aimbot:Stop()
    self.Enabled = false
    self.SkillEnabled = false
    self.RightMouseHeld = false
    self.AltCenter = false
    self.SkillHeld = {}
    self.Target = nil

    local ctx = self.Ctx
    local runService =
        ctx
        and ctx.Services
        and ctx.Services.RunService

    if ctx and type(ctx.RemoveJob) == "function" then
        ctx:RemoveJob("Aimbot")
    end

    if runService and self.RenderName then
        pcall(function()
            runService:UnbindFromRenderStep(
                self.RenderName
            )
        end)
    end

    self.RenderName = nil

    if self.FOVConnection then
        pcall(function()
            self.FOVConnection:Disconnect()
        end)
        self.FOVConnection = nil
    end

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    self.Connections = {}

    if self.Gui then
        self.Gui:Destroy()
        self.Gui = nil
    end

    self.FOVCircle = nil
    self.FOVCenterDot = nil
    self.FOVSegments = {}
end

return Aimbot
]====]
BUNDLED_SOURCES["settings.lua"] = [====[
-- MazxhubModules/settings.lua
-- Low Graphics / FPS Boost migrated from hello.txt

local Settings = {
    LowGraphicsEnabled = false,
    LowGraphics = {
        Enabled = false,
        Saved = setmetatable({}, { __mode = "k" }),
        Seen = setmetatable({}, { __mode = "k" }),
        Queue = {},
        Head = 1,
        Tail = 0,
        Connections = {},
    },
}

local function low(self)
    return self.LowGraphics
end

function Settings:Save(object, property, value)
    local mode = low(self)
    pcall(function()
        local current = object[property]
        if current == value then return end

        local properties = mode.Saved[object] or {}
        if not properties[property] then
            properties[property] = {
                Original = current,
                Applied = value,
            }
        end

        object[property] = value
        mode.Saved[object] = properties
    end)
end

function Settings:Apply(object)
    if object:IsA("BasePart") then
        self:Save(object, "CastShadow", false)
        self:Save(object, "Reflectance", 0)
        self:Save(object, "Material", Enum.Material.SmoothPlastic)
    end

    if object:IsA("MeshPart") then
        self:Save(object, "TextureID", "")
        self:Save(object, "RenderFidelity", Enum.RenderFidelity.Performance)
    elseif object:IsA("SpecialMesh") then
        self:Save(object, "TextureId", "")
    elseif object:IsA("Decal") or object:IsA("Texture") then
        self:Save(object, "Transparency", 1)
    elseif object:IsA("ParticleEmitter")
        or object:IsA("Trail")
        or object:IsA("Beam")
        or object:IsA("Fire")
        or object:IsA("Smoke")
        or object:IsA("Sparkles")
        or object:IsA("PostEffect") then

        if object.Name ~= "MazxhubFullBright" then
            self:Save(object, "Enabled", false)
        end
    elseif object:IsA("Light") then
        self:Save(object, "Shadows", false)
    elseif object:IsA("Clouds") then
        self:Save(object, "Enabled", false)
    end
end

function Settings:Restore(object)
    local mode = low(self)
    local properties = mode.Saved[object]
    mode.Saved[object] = nil

    for property, saved in pairs(properties or {}) do
        pcall(function()
            if object[property] == saved.Applied then
                object[property] = saved.Original
            end
        end)
    end
end

function Settings:Enqueue(object, expand)
    local mode = low(self)
    if not mode.Enabled then return end

    mode.Tail += 1
    mode.Queue[mode.Tail] = { object, expand }
end

function Settings:Step()
    local mode = low(self)
    local deadline = os.clock() + 0.002

    for _ = 1, 80 do
        if mode.Enabled then
            local entry = mode.Queue[mode.Head]
            if not entry then break end

            mode.Queue[mode.Head] = nil
            mode.Head += 1

            local object = entry[1]

            if object and object.Parent and not mode.Seen[object] then
                mode.Seen[object] = true
                self:Apply(object)
            end

            if object and object.Parent and entry[2] then
                for _, child in ipairs(object:GetChildren()) do
                    self:Enqueue(child, true)
                end
            end
        else
            local object = next(mode.Saved)
            if not object then break end
            self:Restore(object)
        end

        if os.clock() >= deadline then
            break
        end
    end
end

function Settings:SetLowGraphics(on)
    local mode = low(self)
    on = on == true

    if mode.Enabled == on then
        self.LowGraphicsEnabled = on
        return
    end

    mode.Enabled = on
    self.LowGraphicsEnabled = on

    for _, connection in ipairs(mode.Connections) do
        connection:Disconnect()
    end
    mode.Connections = {}

    mode.Queue = {}
    mode.Head = 1
    mode.Tail = 0
    mode.Seen = setmetatable({}, { __mode = "k" })

    if on then
        self:Save(game:GetService("Lighting"), "GlobalShadows", false)

        for _, root in ipairs({
            workspace,
            game:GetService("Lighting"),
        }) do
            table.insert(
                mode.Connections,
                root.DescendantAdded:Connect(function(object)
                    self:Enqueue(object, false)
                end)
            )

            self:Enqueue(root, true)
        end
    end
end

function Settings:Init(ctx)
    self.Ctx = ctx
end

function Settings:Start()
    self.Ctx:RegisterJob("LowGraphics", 0.02, function()
        local mode = low(self)
        if mode.Enabled or next(mode.Saved) then
            self:Step()
        end
    end)
end

function Settings:Stop()
    self:SetLowGraphics(false)

    local mode = low(self)

    for _, connection in ipairs(mode.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    mode.Connections = {}

    while next(mode.Saved) do
        self:Restore(next(mode.Saved))
    end
end

return Settings
]====]
BUNDLED_SOURCES["ui.lua"] = [====[
-- MazaSpace native UI + original module callbacks.
-- This is a loader module: Init(ctx), then Start(). Use MazaSpace.lua for one-file execution.
local UI={}
function UI:Init(ctx)
    self.Ctx=ctx;self.AnimationsEnabled=true;self.BlurEnabled=false
end
function UI:Stop()
    if self.Ctx then self.Ctx:RemoveJob("UIStatus") end
    local blur=game:GetService("Lighting"):FindFirstChild("MazxhubUIBlur")
    if blur then blur:Destroy() end
    self.BlurEnabled=false
    if self.Gui then self.Gui:Destroy();self.Gui=nil end
end
function UI:Start()
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local player = self.Ctx.Player or Players.LocalPlayer
assert(player, "Run this file on the client as a LocalScript")
local playerGui = player:WaitForChild("PlayerGui")
for _, name in ipairs({"SottoroUI", "MazaSpaceUI", "MazxhubModulesUI"}) do
    local previous = playerGui:FindFirstChild(name)
    if previous then previous:Destroy() end
end

local UI=self
UI.Values={}; UI.Callbacks={}; UI.Connections={}; UI.Sections={}; UI.Pages={}; UI.Controls={}
UI.ActivePage="Main"; UI.Dropdowns={}; UI.Bindings={}; UI.SyncControls={}; UI.BossToggleSetters={}; UI.QuestSetters={}
local C = {
    Background = Color3.fromRGB(12, 12, 15), Panel = Color3.fromRGB(17, 17, 21),
    Field = Color3.fromRGB(23, 23, 28), Line = Color3.fromRGB(53, 50, 55),
    Text = Color3.fromRGB(239, 234, 237), Muted = Color3.fromRGB(188, 181, 188),
    Accent = Color3.fromRGB(202, 57, 78),
}
local translations={
    {"ใช้ Auto Quest ที่หน้า Mob Farm/Boss Farm ระบบจะไปรับเควสตามเป้าหมายแล้วกลับมาตีต่ออัตโนมัติ","Enable Auto Quest in Mob Farm or Boss Farm to accept target quests and resume farming"},
    {"ไปหา Blacksmith Togane → รับเควส Ill find the forge(Lv 65) → ไป Forge → กด T","Talk to Blacksmith Togane → Accept Ill find the forge (Lv 65) → Go to Forge → Press T"},
    {"ระบบจะตรวจมอน → ฟาร์มจนหมด → เปิดกล่อง → กด T เก็บของ → ไปจุดถัดไป","Scan monsters → Clear area → Open chest → Hold T for loot → Next point"},
    {"ตรวจวง timing และคลิกซ้ายอัตโนมัติเมื่อวงเข้าจังหวะ","Detect the timing ring and click at the correct time"},
    {"ขยายพื้นที่ตีของ BasePart ทุกชิ้นในอาวุธที่ถืออยู่","Expand the equipped weapon hitbox"},
    {"ระยะลอยเหนือ HumanoidRootPart ก่อนเข้าตำแหน่งตี","Hover height above the target before attacking"},
    {"ลดเงา เท็กซ์เจอร์ และเอฟเฟกต์ • ปิดเพื่อคืนภาพ","Reduce shadows, textures and effects; disable to restore"},
    {"เวลาประมาณจากการตาย → เกิดที่ตรวจพบในเซสชันนี้","Respawn estimates based on observations in this session"},
    {"ตัวจริงถูกซ่อน • ฝั่งผู้ใช้เห็นเป็นเงาจางๆ","Hidden character; faint local preview"},
    {"เปิดทดสอบ Hitbox • ถืออาวุธแล้วลองตีเอง","Hitbox test enabled • Equip a weapon and attack"},
    {"Bandit = สีแดง • Civilian = สีเขียว","Bandit = red • Civilian = green"},
    {"ลอยติดหัวมอน • ไม่วาปหนีเมื่อโดนตี","Hover over target; stay when hit"},
    {"หลังมอนตาย รอก่อนเลือกเป้าตัวใหม่","Wait after a kill before selecting the next target"},
    {"รัศมีส่ง Combat Service เพิ่มเติม","Additional Combat Service radius"},
    {"ขนาดพื้นที่ตีของอาวุธที่ถืออยู่","Equipped weapon hitbox size"},
    {"เปลี่ยนจุดเริ่มต้นของ Auto Raid","Change Auto Raid starting point"},
    {"ถึงเวลาประมาณแล้ว • รอตรวจพบบอส","Respawn expected • Waiting for detection"},
    {"ปิด No Clip และคืนค่าการชนแล้ว","No Clip disabled; collisions restored"},
    {"Change attack position in the Attack position card. Settings apply to mobs and bosses.","Attack while hovering over the target"},
    {"การโจมตี • รอเปิด Auto Attack","Attack • Waiting for Auto Attack"},
    {"ไม่มีผู้เล่นอื่นในเซิร์ฟเวอร์","No other players in this server"},
    {"ยังไม่พบ • ยังไม่ทราบเวลาเกิด","Not found • Respawn unknown"},
    {"ตายแล้ว • ยังไม่ทราบเวลาเกิด","Dead • Respawn unknown"},
    {"ระยะที่จะเริ่มโจมตีเป้าหมาย","Attack start distance"},
    {"WASD • Space ขึ้น • Ctrl ลง","WASD • Space up • Ctrl down"},
    {"ความถี่ในการส่งคำสั่งโจมตี","Attack request interval"},
    {"Continue หลังทำช่วง Manual","Continue after the manual step"},
    {"ขนาด hitbox ของมอนที่ล็อก","Target monster hitbox size"},
    {"เลือกผู้เล่นในเซิร์ฟเวอร์","Select server player"},
    {"ดึงผู้เล่นที่เลือกมาหาเรา","Bring selected player"},
    {"RightShift • เปิด/ปิดเมนู","Change the menu shortcut below"},
    {"Performance / ประสิทธิภาพ","Performance"},
    {"มีจุดที่บันทึกไว้ทั้งหมด ","Saved points: "},
    {"ESP บอสทั้งหมด (เปิด/ปิด)","All boss ESP"},
    {"1 request ต่อรอบโจมตี","1 request per attack cycle"},
    {"Auto Quest ตามมอน/บอส","Auto Quest by target"},
    {"ESP NPC ใน ActiveNpcs","Active NPC ESP"},
    {"เกิดแล้ว • พร้อมฟาร์ม","Alive • Ready to farm"},
    {"— ไม่มีผู้เล่นอื่น —","— No other players —"},
    {"วาปไปผู้เล่นที่เลือก","Teleport to selected player"},
    {"หน่วงก่อนตีตัวถัดไป","Next target delay"},
    {"สถานะบอส / เวลาเกิด","Boss status / Respawn"},
    {"ยังไม่พบในเซสชันนี้","Not seen this session"},
    {"รับเควสไม่สำเร็จ: ","Quest failed: "},
    {"ทดสอบ Hitbox การตี","Test weapon hitbox"},
    {"วาปไป NPC ที่เลือก","Teleport to selected NPC"},
    {"Outline สีขาวเฉพาะ","White outline only for"},
    {"ภาพต่ำ / FPS Boost","Low graphics / FPS Boost"},
    {"ความสูงก่อนวาปลงตี","Approach height"},
    {"เริ่มจากจุด 1 ใหม่","Restart from point 1"},
    {"เลือกบอสช่องที่ 1","Select primary boss"},
    {"เก็บของหลังบอสตาย","Collect loot after boss defeat"},
    {"เปิด Fly • Speed ","Fly enabled • Speed "},
    {"ระยะ Hitbox การตี","Weapon hitbox range"},
    {"ระยะไกลสุดของหมอก","Maximum fog distance"},
    {"Auto ทำปราณสายฟ้า","Auto Thunder Breathing"},
    {"ยังไม่พบข้อมูลโซน","Region not loaded"},
    {"ต้องเลือกบอสก่อน","Select a boss first"},
    {"ปิดกระโดดสูงแล้ว","High jump disabled"},
    {"ลงพื้น (Raycast)","Move to ground (Raycast)"},
    {"คาดว่าจะเกิดใน ~","Estimated respawn in ~"},
    {"เปิดกระโดดสูง: ","High jump enabled: "},
    {"ปิดทดสอบ Hitbox","Hitbox test disabled"},
    {"No Fog (ลบหมอก)","No Fog"},
    {"รอก่อนลงไปตีมอน","Wait before approaching the monster"},
    {"เริ่มตรวจจากจุด","Start point"},
    {"กำลังตรวจสอบ...","Scanning..."},
    {"เลือกแล้วกดวาป","Select a target, then teleport"},
    {"ขึ้นฟ้า (+100)","Move up (+100)"},
    {"ยังไปต่อไม่ได้","Cannot resume yet"},
    {"ESP ระยะสูงสุด","ESP maximum distance"},
    {"ยังไม่มีข้อมูล","No data yet"},
    {"รอบที่วัดได้ ~","Measured interval ~"},
    {"รับเควส Mitsu","Accept Mitsu quest"},
    {"ปิดวิ่งไวแล้ว","Walk speed disabled"},
    {"ลบ Atmosphere","Remove atmosphere"},
    {"NPCs — ทุกโซน","NPCs — All regions"},
    {"รีเซ็ตไปจุด 1","Reset to point 1"},
    {"เปิดวิ่งไว: ","Walk speed enabled: "},
    {"ความเร็ววิ่ง","Walk speed"},
    {"ปิด Fly แล้ว","Fly disabled"},
    {"เปิด No Clip","No Clip enabled"},
    {"เวลาลอยบนฟ้า","Hover duration"},
    {"เปิด No Fog","No Fog enabled"},
    {"ESP ผู้เล่น","Player ESP"},
    {"ปิด No Fog","No Fog disabled"},
    {"ปราณสายฟ้า","Thunder Breathing"},
    {"กระโดดสูง","High jump"},
    {"แรงกระโดด","Jump power"},
    {"เลือก NPC","Select NPC"},
    {"ล้มเหลว: ","Failed: "},
    {"สอบนักล่า","Hunter Exam"},
    {"ไปต่อแล้ว","Resumed"},
    {"พบล่าสุด ","Last seen "},
    {"ภาษาเมนู","Menu language"},
    {"วาปด่วน","Quick teleport"},
    {"ฟาร์ม ","Farm "},
    {"วิ่งไว","Walk speed"},
    {"อื่น ๆ","Other"},
    {"ช่อง ","Slot "},
    {" แล้ว"," completed"},
    {"พร้อม","Ready"},
    {"ภาษา","Language"},
    {" จุด"," points"},
}
UI.Language=UI.Language or "English"
UI.TextEntries={}
function UI:Translate(text)
    text=tostring(text or "")
    if self.Language~="English" then return text end
    for _,pair in ipairs(translations) do
        local pattern=pair[1]:gsub("(%W)","%%%1")
        text=text:gsub(pattern,function() return pair[2] end)
    end
    return text
end
function UI:SetLanguage(value)
    self.Language=value=="English" and "English" or "ไทย / Thai"
    for _,entry in ipairs(self.TextEntries) do entry.Paint() end
    if self.Filter then self:Filter() end
end
function UI:WatchText(obj,property)
    local entry={Raw=obj[property],Last=nil}
    function entry.Paint()
        entry.Last=self:Translate(entry.Raw)
        obj[property]=entry.Last
    end
    table.insert(self.TextEntries,entry)
    table.insert(self.Connections,obj:GetPropertyChangedSignal(property):Connect(function()
        if obj[property]==entry.Last then return end
        entry.Raw=obj[property];entry.Paint()
    end))
    entry.Paint()
end
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    if class=="TextLabel" or class=="TextButton" or class=="TextBox" then
        obj.Font=Enum.Font.Gotham
        obj.TextSize=math.max(14,props.TextSize or 14)
        if class=="TextBox" then UI:WatchText(obj,"PlaceholderText")
        else UI:WatchText(obj,"Text") end
    end
    obj.Parent = parent
    return obj
end
local function connect(signal, fn)
    local connection = signal:Connect(fn)
    table.insert(UI.Connections, connection)
    return connection
end
local function corner(obj, r)
    local shape = obj:FindFirstChildOfClass("UICorner") or make("UICorner", {}, obj)
    shape.CornerRadius = UDim.new(0, r or 4)
end
local function outline(obj) make("UIStroke", {Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, obj) end
-- Resolution-independent outline icons made from UI geometry (no emoji/assets).
local IconPaths = {
    M={{{3,21},{6,3},{12,12},{20,3},{17,21}},{{3,21},{8,21},{9,13},{12,17},{17,12}},{{7,3},{11,8}},{{17,21},{21,21}}},
    Home={{{3,11},{12,3},{21,11},{21,21},{15,21},{15,14},{9,14},{9,21},{3,21},{3,11}}},
    Main={{{4,3},{16,15}},{{3,3},{3,8},{13,18},{18,13},{8,3},{3,3}},{{15,16},{21,22}},{{3,21},{9,15}},{{15,9},{21,3}},{{17,3},{21,3},{21,7}}},
    Farm={{{5,21},{19,3}},{{8,17},{3,13},{6,10},{11,13}},{{12,12},{8,8},{11,5},{15,8}},{{14,8},{16,2},{21,2},{21,7},{18,10}},{{10,16},{15,16},{19,12},{16,10}}},
    Dungeon={{{3,21},{3,10},{7,10},{7,14},{10,14},{10,6},{14,6},{14,14},{17,14},{17,10},{21,10},{21,21},{3,21}},{{10,21},{10,17},{14,17},{14,21}},{{5,10},{5,5}},{{19,10},{19,5}}},
    Visuals={{{2,12},{6,7},{12,5},{18,7},{22,12},{18,17},{12,19},{6,17},{2,12}}},
    Player={{{5,22},{5,18},{7,15},{17,15},{19,18},{19,22}}},
    Webhook={{{4,18},{6,15},{6,9},{8,5},{12,3},{16,5},{18,9},{18,15},{20,18},{4,18}},{{10,21},{14,21}}},
    Config={{{9,2},{15,2},{16,6},{20,6},{22,11},{19,14},{20,18},{15,21},{12,18},{8,21},{4,18},{5,14},{2,11},{4,6},{8,6},{9,2}}},
    Combat={{{12,1},{12,7}},{{12,17},{12,23}},{{1,12},{7,12}},{{17,12},{23,12}}},
    Dialogue={{{3,3},{21,3},{21,18},{8,18},{3,22},{3,3}}},
    Defense={{{12,2},{21,6},{20,14},{17,19},{12,22},{7,19},{4,14},{3,6},{12,2}}},
    Training={{{2,8},{5,5},{9,9},{15,3},{19,7},{17,9},{21,13},{18,16},{14,12},{8,18},{4,14},{6,12},{2,8}}},
    Instakill={{{14,2},{4,13},{10,13},{8,22},{21,9},{14,9},{14,2}}},
    Lock={{{5,10},{19,10},{19,22},{5,22},{5,10}},{{8,10},{8,6},{10,3},{14,3},{16,6},{16,10}}},
    Market={{{3,9},{5,3},{19,3},{21,9},{18,12},{15,9},{12,12},{9,9},{6,12},{3,9}},{{5,12},{5,21},{19,21},{19,12}},{{10,21},{10,16},{15,16},{15,21}}},
    Location={{{12,23},{5,15},{3,10},{5,5},{9,2},{15,2},{19,5},{21,10},{19,15},{12,23}}},
    Performance={{{3,19},{2,13},{4,7},{8,3},{16,3},{20,7},{22,13},{21,19}},{{12,15},{17,8}}},
    Muzan={{{18,3},{12,4},{9,8},{9,13},{13,17},{18,17},{22,14},{20,19},{16,22},{10,22},{5,19},{2,14},{3,8},{7,3},{12,2}}},
    Menu={{{2,4},{22,4},{22,20},{2,20},{2,4}},{{6,9},{7,9}},{{11,9},{12,9}},{{16,9},{18,9}},{{6,13},{7,13}},{{11,13},{12,13}},{{16,13},{18,13}},{{7,17},{17,17}}},
    List={{{8,5},{22,5}},{{8,12},{22,12}},{{8,19},{22,19}},{{2,5},{3,5}},{{2,12},{3,12}},{{2,19},{3,19}}},
    Folder={{{2,20},{2,4},{9,4},{12,7},{22,7},{22,20},{2,20}}},
    Themes={{{4,15},{15,4},{20,9},{9,20},{4,15}},{{15,4},{18,1},{23,6},{20,9}},{{4,15},{2,22},{9,20}}},
    Search={{{15,15},{21,21}}},
    Chevron={{{5,8},{12,15},{19,8}}},
    Move={{{12,2},{12,22}},{{2,12},{22,12}},{{8,6},{12,2},{16,6}},{{8,18},{12,22},{16,18}},{{6,8},{2,12},{6,16}},{{18,8},{22,12},{18,16}}},
}
local function icon(parent, name, position, size, color)
    local aliases={Quests="Dialogue",["Hunter Exam"]="Defense",["Unlock Market"]="Market",["Unlock Dungeon"]="Dungeon",
        ["Mob Farm"]="Farm",["Boss Farm"]="Defense",Aimbot="Combat",Skill="Instakill",World="Location",Teleport="Location",
        Raids="Dungeon",["Combat tools"]="Main",["Character tools"]="Player",["ESP tools"]="Visuals"}
    name=aliases[name] or name
    local canvas=make("Frame",{Name="Icon_"..name,BackgroundTransparency=1,Size=UDim2.fromOffset(size,size),Position=position},parent)
    if name=="M" then
        make("TextLabel",{Name="MLogo",Text="M",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
            TextSize=size,TextColor3=color or C.Accent,TextXAlignment=Enum.TextXAlignment.Center},canvas).Font=Enum.Font.GothamBold
        return canvas
    end
    local ink=color or C.Accent
    local function line(x1,y1,x2,y2)
        local dx,dy=(x2-x1)*size/24,(y2-y1)*size/24
        local segment=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset((x1+x2)*size/48,(y1+y2)*size/48),
            Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy)+1.2,2),Rotation=math.deg(math.atan2(dy,dx)),BackgroundColor3=ink,BorderSizePixel=0},canvas)
        corner(segment,1)
    end
    local function ring(x,y,r)
        local circle=make("Frame",{BackgroundTransparency=1,BorderSizePixel=0,
            Position=UDim2.fromOffset((x-r)*size/24,(y-r)*size/24),
            Size=UDim2.fromOffset(2*r*size/24,2*r*size/24)},canvas)
        make("UICorner",{CornerRadius=UDim.new(.5,0)},circle)
        make("UIStroke",{Color=ink,Thickness=1.6,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},circle)
    end
    for _,path in ipairs(IconPaths[name] or IconPaths.List) do
        for i=2,#path do line(path[i-1][1],path[i-1][2],path[i][1],path[i][2]) end
    end
    if name=="Search" then ring(10,10,6) end
    if name=="Player" then ring(12,7,4) end
    if name=="Visuals" or name=="Config" then ring(12,12,3.5) end
    if name=="Combat" then ring(12,12,8.5) end
    if name=="Location" then ring(12,10,3) end
    return canvas
end
local SectionIcons={Status="Performance",Changelog="List",Combat="Combat",Dialogue="Dialogue",Defense="Defense",Training="Training",
    Instakill="Instakill",["Private Server"]="Lock",["Black market"]="Market",["Clan roll"]="Lock",Players="Player",Mobs="Defense",
    Character="Player",["Teleport to location"]="Location",Performance="Performance",Muzan="Muzan",["Teleport to NPC"]="Player",
    Discord="Webhook",Notifications="Webhook",["On every card"]="List",Menu="Menu",Account="Player",Themes="Themes",Configuration="Folder"}

local function pad(obj, n)
    make("UIPadding", {PaddingTop=UDim.new(0,n), PaddingBottom=UDim.new(0,n), PaddingLeft=UDim.new(0,n), PaddingRight=UDim.new(0,n)}, obj)
end
local function stack(obj, gap)
    return make("UIListLayout", {Padding=UDim.new(0,gap or 5), SortOrder=Enum.SortOrder.LayoutOrder}, obj)
end
local function label(parent, text, size)
    return make("TextLabel", {BackgroundTransparency=1, Size=size or UDim2.new(1,0,0,22), Text=text,
        TextColor3=C.Text, Font=Enum.Font.Gotham, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left}, parent)
end
local function button(parent, text, size)
    local b=make("TextButton", {Size=size or UDim2.new(1,0,0,26), BackgroundColor3=C.Field,
        BorderSizePixel=0, Text=text, TextColor3=C.Muted, Font=Enum.Font.Gotham, TextSize=14, AutoButtonColor=true}, parent)
    corner(b,3); outline(b)
    return b
end
local function textbox(parent, placeholder)
    local b=make("TextBox", {Size=UDim2.new(1,0,0,27), BackgroundColor3=C.Field, BorderSizePixel=0,
        Text="", PlaceholderText=placeholder or "", PlaceholderColor3=C.Muted, TextColor3=C.Text,
        Font=Enum.Font.Gotham, TextSize=14, ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left}, parent)
    corner(b,3); outline(b); pad(b,6)
    return b
end

UI.Gui=make("ScreenGui", {Name="MazaSpaceUI", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    DisplayOrder=20, IgnoreGuiInset=false}, playerGui)
UI.Changed=make("BindableEvent", {Name="Changed"}, UI.Gui)
local root=make("Frame", {AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5),
    Size=UDim2.fromOffset(724,604), BackgroundColor3=C.Background, BorderSizePixel=0}, UI.Gui)
corner(root,5); outline(root)
local scale=make("UIScale", {Scale=1}, root)
local top=make("Frame", {Size=UDim2.new(1,0,0,50), BackgroundColor3=C.Background, BorderSizePixel=0, Active=true}, root)
icon(top,"M",UDim2.fromOffset(28,14),23)
local brand=label(top,"MazaSpace", UDim2.fromOffset(156,50)); brand.Position=UDim2.fromOffset(62,0); brand.TextSize=19
local search=textbox(top,"Search"); search.Position=UDim2.fromOffset(226,9); search.Size=UDim2.new(1,-274,0,33)
search.TextXAlignment=Enum.TextXAlignment.Center
search:FindFirstChildOfClass("UIPadding").PaddingLeft=UDim.new(0,28)
icon(search,"Search",UDim2.fromOffset(9,8),17,C.Muted)
icon(top,"Move",UDim2.new(1,-36,0,14),23,C.Line)
local hide=button(top,"−",UDim2.fromOffset(30,28)); hide.Position=UDim2.new(1,-68,0,11); hide.Visible=false
local close=button(top,"×",UDim2.fromOffset(24,28)); close.Position=UDim2.new(1,-32,0,11); close.Visible=false
local sidebar=make("ScrollingFrame", {CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=2,ScrollBarImageColor3=C.Accent,BorderSizePixel=0,Position=UDim2.fromOffset(0,50), Size=UDim2.new(0,218,1,-76), BackgroundTransparency=1}, root)
stack(sidebar,0)
make("Frame", {Position=UDim2.fromOffset(218,0), Size=UDim2.new(0,1,1,-25), BackgroundColor3=C.Line, BorderSizePixel=0}, root)
local content=make("Frame", {Position=UDim2.fromOffset(226,58), Size=UDim2.new(1,-234,1,-90), BackgroundTransparency=1, ClipsDescendants=true}, root)
local footer=label(root,"MazaSpace · UI 2026.09.29-r4",UDim2.new(1,0,0,24)); footer.Position=UDim2.new(0,0,1,-24)
footer.TextColor3=C.Muted; footer.TextXAlignment=Enum.TextXAlignment.Center; footer.BackgroundTransparency=0; footer.BackgroundColor3=C.Field
-- Floating launcher remains available while the main window is open or hidden.
local launcherLayer=make("Frame",{Name="LauncherLayer",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
    Active=false,ZIndex=20},UI.Gui)
local reopen=button(launcherLayer,"",UDim2.fromOffset(52,52))
reopen.Name="MazaSpaceLauncher"; reopen.AnchorPoint=Vector2.new(.5,.5)
reopen.Position=UDim2.new(.5,0,0,38); reopen.ZIndex=20
reopen.BackgroundColor3=C.Panel; corner(reopen,26)
local launcherStroke=reopen:FindFirstChildOfClass("UIStroke")
launcherStroke.Color=C.Accent; launcherStroke.Thickness=1.5
local launcherIcon=icon(reopen,"M",UDim2.fromOffset(12,12),28,C.Accent)
launcherIcon.ZIndex=21
for _,part in ipairs(launcherIcon:GetDescendants()) do
    if part:IsA("GuiObject") then part.ZIndex=21 end
end
local launcherGesture
local function clampLauncher()
    local bounds=launcherLayer.AbsoluteSize
    if bounds.X<1 or bounds.Y<1 then return end
    local pos=reopen.Position
    local x=pos.X.Scale*bounds.X+pos.X.Offset
    local y=pos.Y.Scale*bounds.Y+pos.Y.Offset
    local margin=30
    x=math.clamp(x,math.min(margin,bounds.X/2),math.max(bounds.X-margin,bounds.X/2))
    y=math.clamp(y,math.min(margin,bounds.Y/2),math.max(bounds.Y-margin,bounds.Y/2))
    reopen.Position=UDim2.fromScale(x/bounds.X,y/bounds.Y)
end
connect(launcherLayer:GetPropertyChangedSignal("AbsoluteSize"),clampLauncher)
task.defer(clampLauncher)
hide.Parent=root; hide.Visible=true; hide.Size=UDim2.fromOffset(22,19); hide.Position=UDim2.new(1,-27,1,-22)
hide.Text="−"; hide.BackgroundTransparency=1; hide:FindFirstChildOfClass("UIStroke"):Destroy()
local function show(visible)
    UI.IsOpen=visible
    if not visible then UI:CloseDropdown() end
    root.Visible=visible
    reopen.BackgroundColor3=visible and C.Field or C.Panel
end
connect(hide.Activated,function() show(false) end)
connect(close.Activated,function() show(false) end)
-- Toggle only on a tap/click; releasing a drag must not toggle the window.
connect(reopen.InputBegan,function(input)
    if launcherGesture then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        local bounds=launcherLayer.AbsoluteSize
        local pos=reopen.Position
        launcherGesture={Input=input,Start=Vector2.new(input.Position.X,input.Position.Y),
            Origin=Vector2.new(pos.X.Scale*bounds.X+pos.X.Offset,pos.Y.Scale*bounds.Y+pos.Y.Offset),Moved=false}
    end
end)
connect(Input.InputChanged,function(input)
    local g=launcherGesture
    if not g then return end
    local mouse=g.Input.UserInputType==Enum.UserInputType.MouseButton1
    if (mouse and input.UserInputType==Enum.UserInputType.MouseMovement) or input==g.Input then
        local delta=Vector2.new(input.Position.X,input.Position.Y)-g.Start
        if delta.Magnitude>=6 then g.Moved=true end
        if g.Moved then
            reopen.Position=UDim2.fromOffset(g.Origin.X+delta.X,g.Origin.Y+delta.Y)
            clampLauncher()
        end
    end
end)
connect(Input.InputEnded,function(input)
    local g=launcherGesture
    if not g then return end
    local ended=input==g.Input or (g.Input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)
    if not ended then return end
    launcherGesture=nil
    local finish=Vector2.new(input.Position.X,input.Position.Y)
    local topLeft,size=reopen.AbsolutePosition,reopen.AbsoluteSize
    local inside=finish.X>=topLeft.X and finish.X<=topLeft.X+size.X and finish.Y>=topLeft.Y and finish.Y<=topLeft.Y+size.Y
    if not g.Moved and (finish-g.Start).Magnitude<6 and inside then show(not root.Visible) end
end)
connect(Input.WindowFocusReleased,function() launcherGesture=nil end)
show(true)

UI.Main=root; UI.Sidebar=sidebar; UI.SearchBox=search; UI.Fab=reopen
function UI:SetOpen(visible) show(visible==true) end
function UI:CloseDropdown()
    for _,d in ipairs(self.Dropdowns) do d.Close() end
end
function UI:On(id, callback) self.Callbacks[id]=callback end
function UI:Emit(id,value)
    self.Values[id]=value
    self.Changed:Fire(id,value)
    local fn=self.Callbacks[id]
    if not fn and string.sub(id,1,10)=="reference." then
        footer.Text="UI preview: setting saved locally (not connected)"
    end
    if fn then
        local ok,err=pcall(fn,value)
        if not ok then
            footer.Text="MazaSpace · Action error (see console)"
            warn("[MazaSpace] "..id..": "..tostring(err))
        end
    end
end
function UI:Destroy() if self.Gui.Parent then self.Gui:Destroy() end end
connect(UI.Gui.Destroying,function()
    for _,connection in ipairs(UI.Connections) do connection:Disconnect() end
    UI.Connections={}
    if UI.Ctx then UI.Ctx:RemoveJob("UIStatus") end
end)
UI.MenuKey=UI.MenuKey or Enum.KeyCode.RightShift
connect(Input.InputBegan,function(input,processed)
    if UI.CapturingMenuKey then
        if input.UserInputType~=Enum.UserInputType.Keyboard then return end
        if input.KeyCode~=Enum.KeyCode.Escape and input.KeyCode~=Enum.KeyCode.Unknown then UI.MenuKey=input.KeyCode end
        UI.CapturingMenuKey=false
        UI.MenuKeyButton.Text="Menu key: "..UI.MenuKey.Name
        return
    end
    if not processed and not Input:GetFocusedTextBox() and input.KeyCode==UI.MenuKey then show(not root.Visible) end
end)

local drag, sliding, binding
connect(top.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        drag={Input=input, Start=input.Position, Position=root.Position}
    end
end)
connect(Input.InputChanged,function(input)
    if drag and (input.UserInputType==Enum.UserInputType.MouseMovement or input==drag.Input) then
        local delta=input.Position-drag.Start
        root.Position=UDim2.new(drag.Position.X.Scale,drag.Position.X.Offset+delta.X,drag.Position.Y.Scale,drag.Position.Y.Offset+delta.Y)
    end
    if sliding and (input.UserInputType==Enum.UserInputType.MouseMovement or input==sliding.Input) then sliding.Update(input.Position.X) end
end)
connect(Input.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then drag=nil; sliding=nil end
    if drag and input==drag.Input then drag=nil end
    if sliding and input==sliding.Input then sliding=nil end
end)
local function fit()
    local camera=workspace.CurrentCamera
    if camera then scale.Scale=math.min(1, (camera.ViewportSize.X-24)/724, (camera.ViewportSize.Y-70)/604) end
end
local cameraConnection
local function watchCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    fit()
    if workspace.CurrentCamera then cameraConnection=connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit) end
end
connect(workspace:GetPropertyChangedSignal("CurrentCamera"),watchCamera); watchCamera()

local function contains(text,query) return string.find(string.lower(UI:Translate(text)),string.lower(query),1,true)~=nil end
function UI:Filter()
    local query=search.Text
    for _,s in ipairs(self.Sections) do
        local titleMatch=query~="" and contains(s.Title,query)
        local found=false
        for _,r in ipairs(s.Rows) do
            r.Node.Visible=query=="" or titleMatch or contains(r.Text,query)
            found=found or r.Node.Visible
        end
        s.Frame.Visible=query=="" or titleMatch or found
        s.Body.Visible=query~="" or not s.Collapsed
        s.Chevron.Rotation=s.Body.Visible and 0 or -90
    end
end
connect(search:GetPropertyChangedSignal("Text"),function()
    local query=search.Text
    if query~="" then
        for _,s in ipairs(UI.Sections) do
            local matches=contains(s.Title,query)
            for _,r in ipairs(s.Rows) do if contains(r.Text,query) then matches=true;break end end
            if matches then UI:SelectPage(s.Page);break end
        end
    end
    UI:Filter()
end)

local navigation={
    {Title="Overview",Items={{"Home","Home"}}},
    {Title="Combat",Items={{"Main","Main"},{"Combat tools","Combat tools"},{"Aimbot","Aimbot"},{"Skill","Skill"}}},
    {Title="Farm",Items={{"Mob Farm","Mob Farm"},{"Boss Farm","Boss Farm"}}},
    {Title="Quest",Items={{"Quests","Story quests"},{"Hunter Exam","Hunter Exam"},{"Unlock Market","Unlock Market"},{"Unlock Dungeon","Unlock Dungeon"}}},
    {Title="Instances",Items={{"Dungeon","Dungeon"},{"Raids","Raids"}}},
    {Title="World",Items={{"World","World"},{"Teleport","Teleport"}}},
    {Title="Player",Items={{"Player","Player"},{"Character tools","Character tools"},{"Visuals","Visuals"},{"ESP tools","ESP tools"}}},
    {Title="System",Items={{"Config","Settings"},{"Webhook","Webhook"}}},
}
local function page(name)
    local scroll=make("ScrollingFrame", {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, BorderSizePixel=0,
        CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=3,
        ScrollBarImageColor3=C.Accent, ScrollingDirection=Enum.ScrollingDirection.Y, Visible=false}, content)
    local columns={}
    for i=1,2 do
        columns[i]=make("Frame", {Position=UDim2.new((i-1)*.5,i==1 and 0 or 4,0,1), Size=UDim2.new(.5,-7,0,0),
            AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1},scroll)
        stack(columns[i],9)
    end
    UI.Pages[name]={Frame=scroll,Columns=columns}
    return name
end
local function buildNavigation()
    UI.NavGroups={}
    for _,group in ipairs(navigation) do
        local holder=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1},sidebar)
        stack(holder,2)
        local heading=button(holder,"  "..group.Title.."   ▾",UDim2.new(1,0,0,31))
        heading.TextXAlignment=Enum.TextXAlignment.Left;heading.BackgroundTransparency=1
        heading.TextColor3=C.Muted
        heading:FindFirstChildOfClass("UIStroke"):Destroy()
        local children=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},holder)
        stack(children,1)
        local record={Title=group.Title,Heading=heading,Body=children,Open=group.Title=="Combat" or group.Title=="Farm",Tabs={}}
        children.Visible=record.Open
        heading.Text="  "..group.Title..(record.Open and "  ▾" or "  ▸")
        table.insert(UI.NavGroups,record)
        connect(heading.Activated,function()
            record.Open=not record.Open
            children.Visible=record.Open
            heading.Text="  "..group.Title..(record.Open and "  ▾" or "  ▸")
        end)
        for _,item in ipairs(group.Items) do
            local name,text=item[1],item[2]
            local tab=button(children,"",UDim2.new(1,0,0,33));tab.BackgroundTransparency=1
            tab:FindFirstChildOfClass("UIStroke"):Destroy()
            icon(tab,({Home="Home",Main="Combat",Aimbot="Visuals",Skill="Instakill",["Mob Farm"]="Farm",["Boss Farm"]="Defense",
                Quests="List",Dungeon="Dungeon",Raids="Dungeon",World="Location",Teleport="Location",Player="Player",
                Visuals="Visuals",Config="Config",Webhook="Webhook"})[name] or name,UDim2.fromOffset(20,7),19)
            local title=label(tab,text,UDim2.new(1,-52,1,0));title.Position=UDim2.fromOffset(52,0)
            title.Font=Enum.Font.Gotham;title.TextSize=14;title.TextColor3=C.Muted
            UI.Pages[name].Tab=tab;UI.Pages[name].Title=title
            record.Tabs[name]=true
            connect(tab.Activated,function() UI:SelectPage(name) end)
        end
    end
end
function UI:SelectPage(name)
    if not self.Pages[name] then return end
    self:CloseDropdown()
    self.ActivePage=name
    for n,p in pairs(self.Pages) do
        p.Frame.Visible=n==name
        p.Tab.BackgroundTransparency=n==name and 0 or 1
        p.Title.TextColor3=n==name and C.Text or C.Muted
    end
    for _,group in ipairs(self.NavGroups or {}) do
        if group.Tabs[name] and not group.Open then
            group.Open=true;group.Body.Visible=true;group.Heading.Text="  "..group.Title.."  ▾"
        end
    end
end
local function section(pageName,column,title)
    local frame=make("Frame", {Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=C.Panel,BorderSizePixel=0},UI.Pages[pageName].Columns[column])
    frame.LayoutOrder=#UI.Sections+1
    corner(frame,4); outline(frame); stack(frame,0)
    local header=button(frame,"",UDim2.new(1,0,0,35)); header.LayoutOrder=0
    header.BackgroundTransparency=1; header:FindFirstChildOfClass("UIStroke"):Destroy()
    icon(header,SectionIcons[title] or title,UDim2.fromOffset(8,7),21)
    local heading=label(header,title,UDim2.new(1,-63,1,0)); heading.Position=UDim2.fromOffset(36,0); heading.TextTruncate=Enum.TextTruncate.AtEnd
    local arrow=icon(header,"Chevron",UDim2.new(1,-26,0,9),18,C.Text)
    make("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.Line,BorderSizePixel=0},header)
    local body=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,LayoutOrder=1},frame); pad(body,7); stack(body,5)
    local s={Page=pageName,Column=column,Frame=frame,Header=header,Body=body,Title=title,Rows={},Collapsed=false,Chevron=arrow}
    table.insert(UI.Sections,s)
    connect(header.Activated,function() s.Collapsed=not s.Collapsed; UI:Filter() end)
    return s
end
local function row(s,text,height)
    local r=make("Frame", {Size=UDim2.new(1,0,0,height or 25), BackgroundTransparency=1, LayoutOrder=#s.Rows+1},s.Body)
    table.insert(s.Rows,{Node=r,Text=text})
    return r
end
local function note(s,text)
    local r=row(s,text,0); r.AutomaticSize=Enum.AutomaticSize.Y
    local l=label(r,text,UDim2.new(1,0,0,0)); l.AutomaticSize=Enum.AutomaticSize.Y; l.TextWrapped=true; l.TextColor3=C.Muted
end
local function toggle(s,id,text,default,keybind)
    local r=row(s,text,22)
    local l=label(r,text,UDim2.new(1,keybind and -88 or -43,1,0)); l.TextTruncate=Enum.TextTruncate.AtEnd
    local b=button(r,"",UDim2.fromOffset(34,20)); b.Position=UDim2.new(1,-34,.5,-10); corner(b,10)
    local dot=make("Frame", {Size=UDim2.fromOffset(14,14),Position=UDim2.fromOffset(3,3),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},b); corner(dot,8)
    UI.Values[id]=default==true
    local function paint()
        b.BackgroundColor3=UI.Values[id] and C.Accent or C.Field
        dot.Position=UDim2.fromOffset(UI.Values[id] and 17 or 3,3)
        l.TextColor3=UI.Values[id] and C.Text or C.Muted
    end
    local function flip() UI:Emit(id,not UI.Values[id]); paint() end
    connect(b.Activated,flip); paint()
    if keybind then
        local keyButton=button(r,"None",UDim2.fromOffset(42,20)); keyButton.Position=UDim2.new(1,-82,.5,-10); keyButton.TextSize=14
        local selected
        connect(keyButton.Activated,function()
            if binding then binding.Cancel() end
            keyButton.Text="..."
            binding={Set=function(key)
                selected=key~=Enum.KeyCode.Escape and key or nil
                keyButton.Text=selected and selected.Name or "None"
            end,Cancel=function() keyButton.Text=selected and selected.Name or "None" end}
        end)
        connect(Input.InputBegan,function(input,processed)
            if not processed and not binding and not Input:GetFocusedTextBox() and selected and input.KeyCode==selected then flip() end
        end)
    end
    local function set(value,fire)
        UI.Values[id]=value==true; paint()
        if fire then UI:Emit(id,UI.Values[id]) end
    end
    UI.Controls[id]={Kind="toggle",Frame=r,Button=b,Get=function() return UI.Values[id] end,Set=set}
    return r,UI.Controls[id].Get,set
end
-- Defer key assignment so the binding keystroke does not also flip a toggle.
connect(Input.InputBegan,function(input)
    if binding and input.UserInputType==Enum.UserInputType.Keyboard then
        local pending=binding
        task.defer(function() if binding==pending then pending.Set(input.KeyCode); binding=nil end end)
    end
end)
local function action(s,id,text,callback)
    local b=button(row(s,text,26),text)
    connect(b.Activated,function()
        UI:Emit(id,true)
        if callback then callback() else footer.Text=text.." · UI only" end
    end)
end
local function field(s,id,text,placeholder)
    local r=row(s,text,51); label(r,text)
    local b=textbox(r,placeholder); b.Position=UDim2.fromOffset(0,23)
    UI.Values[id]=""
    connect(b.FocusLost,function() UI:Emit(id,b.Text) end)
    return b
end
local function slider(s,id,text,min,max,default,suffix)
    default=math.clamp(tonumber(default) or min,min,max)
    local step=min<1 and 0.1 or 1
    local r=row(s,text,46); label(r,text)
    local bar=button(r,"",UDim2.new(1,0,0,17)); corner(bar,2); bar.Position=UDim2.fromOffset(0,25); bar.ClipsDescendants=true
    local fill=make("Frame", {Size=UDim2.fromScale(0,1),BackgroundColor3=C.Accent,BorderSizePixel=0},bar)
    local value=label(bar,"",UDim2.fromScale(1,1)); value.TextXAlignment=Enum.TextXAlignment.Center; value.TextSize=14; value.ZIndex=2
    UI.Values[id]=default
    local function paint(v) fill.Size=UDim2.fromScale((v-min)/math.max(max-min,0.000001),1); value.Text=string.format("%.3g",v)..(suffix or "").." / "..max..(suffix or "") end
    local function update(x)
        local ratio=math.clamp((x-bar.AbsolutePosition.X)/math.max(1,bar.AbsoluteSize.X),0,1)
        local v=math.floor((min+(max-min)*ratio)/step+.5)*step
        v=math.clamp(v,min,max)
        UI:Emit(id,v); paint(v)
    end
    connect(bar.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            sliding={Input=input,Update=update}; update(input.Position.X)
        end
    end); paint(default)
    local function set(v,fire)
        v=math.clamp(tonumber(v) or min,min,max);UI.Values[id]=v;paint(v)
        if fire then UI:Emit(id,v) end
    end
    UI.Controls[id]={Kind="slider",Frame=r,Set=set,Bar=bar}
    return r,set
end
local function dropdown(s,id,text,options,multi,default)
    options=options or {}
    local r=row(s,text,0); r.AutomaticSize=Enum.AutomaticSize.Y; stack(r,4)
    local title=label(r,text); title.LayoutOrder=0
    local choose=button(r,"---"); choose.LayoutOrder=1; choose.TextXAlignment=Enum.TextXAlignment.Left; pad(choose,6)
    choose.TextTruncate=Enum.TextTruncate.AtEnd
    choose:FindFirstChildOfClass("UIPadding").PaddingRight=UDim.new(0,25)
    local choiceArrow=icon(choose,"Chevron",UDim2.new(1,-17,0,1),15,C.Muted)
    local panel=make("Frame",{Size=UDim2.new(1,0,0,195),BackgroundColor3=C.Background,BorderSizePixel=0,Visible=false,LayoutOrder=2},r)
    outline(panel); corner(panel,3); pad(panel,5)
    local find=textbox(panel,"Search...")
    local list=make("ScrollingFrame",{Position=UDim2.fromOffset(0,32),Size=UDim2.new(1,0,1,-32),BackgroundTransparency=1,
        BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollBarThickness=3,ScrollBarImageColor3=C.Accent},panel); stack(list,2)
    local selected={}; local optionRows={}
    if multi then for _,v in ipairs(default or {}) do selected[v]=true end else selected[default or ""]=true end
    local function refresh(emit)
        local names={}
        for _,v in ipairs(options) do if selected[v] then table.insert(names,v) end end
        local value=multi and names or names[1]
        if not multi and not value then for chosen,on in pairs(selected) do if on and chosen~="" then value=chosen;break end end end
        choose.Text=multi and (#names>0 and table.concat(names,", ") or "---") or tostring(value or "---")
        for _,entry in ipairs(optionRows) do
            entry.Button.Text=(multi and (selected[entry.Name] and "[✓] " or "[ ] ") or "")..entry.Name
            entry.Button.TextColor3=selected[entry.Name] and C.Accent or C.Muted
        end
        if emit then UI:Emit(id,value) else UI.Values[id]=value end
    end
    for _,name in ipairs(options) do
        local b=button(list,name,UDim2.new(1,-5,0,25)); b.TextXAlignment=Enum.TextXAlignment.Left; b.BackgroundTransparency=1
        b:FindFirstChildOfClass("UIStroke"):Destroy(); b.TextTruncate=Enum.TextTruncate.AtEnd
        table.insert(optionRows,{Name=name,Button=b})
        connect(b.Activated,function()
            if multi then selected[name]=not selected[name] else selected={[name]=true}; panel.Visible=false; choiceArrow.Rotation=0 end
            refresh(true)
        end)
    end
    local empty=label(list,"No results"); empty.TextColor3=C.Muted; empty.Visible=false; empty.LayoutOrder=999
    connect(find:GetPropertyChangedSignal("Text"),function()
        local count=0
        for _,entry in ipairs(optionRows) do entry.Button.Visible=contains(entry.Name,find.Text); if entry.Button.Visible then count=count+1 end end
        empty.Visible=count==0; list.CanvasPosition=Vector2.new(0,0)
    end)
    local function closeList() panel.Visible=false;choiceArrow.Rotation=0 end
    connect(choose.Activated,function()
        local opening=not panel.Visible
        UI:CloseDropdown()
        panel.Visible=opening;choiceArrow.Rotation=opening and 180 or 0
        if opening then find:CaptureFocus() end
    end)
    local function set(value,fire)
        selected={}
        if multi then for _,v in ipairs(value or {}) do selected[v]=true end
        elseif value~=nil then selected[value]=true end
        refresh(fire==true)
    end
    refresh(false)
    local control={Kind="dropdown",Frame=r,Button=choose,Search=find,Options=optionRows,Panel=panel,Close=closeList,Set=set,Get=function() return UI.Values[id] end}
    UI.Controls[id]=control;table.insert(UI.Dropdowns,control)
    return r,control.Get,set,closeList,control
end


-- Backend adapter: carries behavior from the user's modules into the native UI.
local T={Text=C.Text,Sub=C.Muted,Accent=C.Accent,Mint=C.Accent,Gold=Color3.fromRGB(216,177,135),Danger=Color3.fromRGB(245,88,108),Card=C.Field,Stroke=C.Line}
local destinations={['Mob Farm']='Mob Farm',['Boss Farm']='Boss Farm',Combat='Combat tools',Skill='Skill',Player='Character tools',Teleport='Teleport',
    World='World',Visuals='ESP tools',Settings='Config',Quests='Quests',Dungeon='Dungeon',Raids='Raids',Status='Home'}
local sectionNames={Movement='Character',['NPCs — ทุกโซน']='Teleport to NPC',Players='Teleport to player',
    ['ESP ผู้เล่น']='Players',['ESP NPC ใน ActiveNpcs']='Mobs',['Auto Skills']='Auto Skill',['Mob farm (on/off)']='Mob Farm',
    ['Performance / ประสิทธิภาพ']='Performance',Interface='Menu',['Boss Selection']='Boss selection'}
local controlNames={['วิ่งไว']='Walk speed',['ความเร็ววิ่ง']='Speed',['บิน']='Fly',['ความเร็วบิน']='Fly speed'}
local serial=0
local function nextID(handle,text)
    serial=serial+1
    return handle.Source.."/"..text.."#"..serial
end
local function attachPending(handle)
    for _,obj in ipairs(handle.Pending or {}) do
        obj.Parent=handle.Current.Body;obj.LayoutOrder=#handle.Current.Rows+1
        table.insert(handle.Current.Rows,{Node=obj,Text=tostring(obj.Text or "")})
    end
    handle.Pending={}
end
local function ensureSection(handle)
    if not handle.Current then
        handle.Current=section(handle.Page,handle.Column,handle.Heading)
        attachPending(handle)
    end
    return handle.Current
end
local function legacyNew(class,props,parent)
    local handle=type(parent)=="table" and parent.IsColumn and parent or nil
    if handle and not handle.Current and class=="TextLabel" then
        local obj=make(class,props,nil);obj.Font=Enum.Font.Gotham;obj.TextSize=14
        handle.Pending=handle.Pending or {};table.insert(handle.Pending,obj)
        return obj
    end
    local target=handle and ensureSection(handle).Body or parent
    local obj=make(class,props,target)
    if class=="TextLabel" then
        obj.TextWrapped=true
        obj.AutomaticSize=Enum.AutomaticSize.Y
    end
    if handle then
        local s=handle.Current
        obj.LayoutOrder=#s.Rows+1
        table.insert(s.Rows,{Node=obj,Text=tostring(props.Text or handle.Heading)})
        if obj:IsA("TextLabel") then obj.Font=Enum.Font.Gotham;obj.TextSize=14 end
    end
    return obj
end
local function legacyLabel(parent,text,size,color,font,position,frameSize)
    return legacyNew("TextLabel",{BackgroundTransparency=1,Text=text or "",TextSize=14,TextColor3=color or C.Text,
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Position=position or UDim2.new(),
        Size=frameSize or UDim2.fromScale(1,1)},parent)
end
local function stroke(parent,color,thickness) make("UIStroke",{Color=color or C.Line,Thickness=thickness or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},parent) end
function UI:Connect(signal,fn) return connect(signal,fn) end
function UI:CreatePage(source)
    local destination=assert(destinations[source],"Missing page mapping: "..source)
    local left={IsColumn=true,Source=source,Page=destination,Column=1,Heading=source}
    local right={IsColumn=true,Source=source,Page=destination,Column=2,Heading=source.." settings"}
    return left,right
end
function UI:CreateSection(handle,title,default,callback)
    if handle.Source=="Combat" then
        if title=="Aimbot" or title=="Targets" or title=="Aimbot Skills" then handle.Page="Aimbot"
        elseif title=="Combat" or title=="Attack Settings" then handle.Page="Combat tools" end
    end
    if title=="Quest unlock Dungeon • Lv65+" then handle.Page="Unlock Dungeon" end
    handle.Current=section(handle.Page,handle.Column,sectionNames[title] or title)
    attachPending(handle)
    if callback then
        local _,get,set=self:CreateToggle(handle,"Enabled",default,callback)
        return handle.Current.Frame,get,set
    end
    return handle.Current.Frame
end
function UI:CreateToggle(handle,title,default,callback)
    local id=nextID(handle,title)
    self:On(id,callback)
    local frame,get,set=toggle(ensureSection(handle),id,controlNames[title] or title,default,false)
    table.insert(self.Bindings,{Source=handle.Source,Title=title,Kind="toggle",ID=id})
    return frame,get,set
end
function UI:CreateSlider(handle,title,desc,min,max,default,suffix,callback)
    local id=nextID(handle,title)
    self:On(id,callback)
    local frame,set=slider(ensureSection(handle),id,controlNames[title] or title,min,max,default,suffix)
    table.insert(self.Bindings,{Source=handle.Source,Title=title,Kind="slider",ID=id})
    return frame
end
function UI:CreateDropdown(handle,title,desc,options,default,callback)
    local id=nextID(handle,title)
    self:On(id,callback)
    local frame,get,set,closeList,control=dropdown(ensureSection(handle),id,title,options,false,default or options[1])
    handle.LastDropdown=control
    if not callback then
        -- The legacy language selector never had a translation handler.
        control.Button.Active=false;control.Button.Selectable=false
        control.Button.AutoButtonColor=false;control.Button.TextColor3=C.Muted
        control.Button.Text=control.Button.Text.." (display only)"
    end
    table.insert(self.Bindings,{Source=handle.Source,Title=title,Kind="dropdown",ID=id})
    return frame,get,set,closeList
end
function UI:CreateButton(handle,text,callback)
    local id=nextID(handle,text)
    local r=row(ensureSection(handle),text,26)
    local b=button(r,text)
    self:On(id,function() if callback then callback(b) end end)
    connect(b.Activated,function() self:Emit(id,true) end)
    self.Controls[id]={Kind="button",Frame=r,Button=b}
    table.insert(self.Bindings,{Source=handle.Source,Title=text,Kind="button",ID=id})
    return b
end
function UI:CreateSearchRow(handle,placeholder,onSearch)
    -- Search lives INSIDE the new dropdown; do not recreate the legacy Search row.
    if handle.LastDropdown then
        local box=handle.LastDropdown.Search
        connect(box.FocusLost,function(enter) if enter and onSearch then onSearch(box.Text) end end)
        return box
    end
    local box=field(ensureSection(handle),nextID(handle,placeholder),placeholder,"Search...")
    connect(box.FocusLost,function(enter) if enter and onSearch then onSearch(box.Text) end end)
    return box
end
function UI:Farm()
    return self.Ctx.Modules.Farm
end

function UI:Boss()
    return self.Ctx.Modules.Boss
end

function UI:Combat()
    return self.Ctx.Modules.Combat
end

function UI:Skill()
    return self.Ctx.Modules.Skill
end

function UI:Player()
    return self.Ctx.Modules.Player
end

function UI:Teleport()
    return self.Ctx.Modules.Teleport
end

function UI:Quest()
    return self.Ctx.Modules.Quest
end

function UI:Dungeon()
    return self.Ctx.Modules.Dungeon
end

function UI:Raid()
    return self.Ctx.Modules.Raid
end

function UI:Loot()
    return self.Ctx.Modules.Loot
end

function UI:World()
    return self.Ctx.Modules.World
end

function UI:Visuals()
    return self.Ctx.Modules.Visuals
end

function UI:Aimbot()
    return self.Ctx.Modules.Aimbot
end

function UI:Settings()
    return self.Ctx.Modules.Settings
end

function UI:BuildMobFarmPage()
    local farm = self:Farm()
    local combat = self:Combat()
    local left, right = self:CreatePage("Mob Farm")

    local status = legacyLabel(
        left,
        "Ready",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 16)
    )

    local selectedMob
    local mobList =
        farm.farmListMobTypes
        and farm.farmListMobTypes()
        or {}

    selectedMob = farm.MobName or mobList[1]
    if selectedMob then
        farm:SetMob(selectedMob)
    end

    local farmSetter
    local _, _, farmSetterValue = self:CreateSection(
        left,
        "Mob farm (on/off)",
        farm.Enabled and not farm.BossEnabled,
        function(on)
            if on then
                if not selectedMob then
                    status.Text = "Select a mob first"
                    status.TextColor3 = T.Danger
                    task.defer(function()
                        if farmSetter then
                            farmSetter(false, false)
                        end
                    end)
                    return
                end

                farm:StartMob(selectedMob)
                local count = 0
                if farm.farmFindMobsByName then
                    count = #farm.farmFindMobsByName(selectedMob)
                end
                status.Text = string.format(
                    "Farming %s (%d found)",
                    selectedMob,
                    count
                )
                status.TextColor3 = T.Mint
            else
                if farm.Enabled and not farm.BossEnabled then
                    farm:Stop()
                end
                status.Text = "Mob farm stopped"
                status.TextColor3 = T.Sub
            end
        end
    )
    farmSetter = farmSetterValue

    farm.OnStateChanged = function(enabled, mode, owner)
        local mobActive =
            enabled == true
            and mode == "Mob"
            and owner == "Farm"

        farmSetter(mobActive, false)

        if not enabled and status.Parent then
            status.Text = "Mob farm stopped"
            status.TextColor3 = T.Sub
        end
    end

    local _, getMob, setMob = self:CreateDropdown(
        left,
        "Select mob",
        "",
        mobList,
        selectedMob,
        function(value)
            selectedMob = value
            farm:SetMob(value)
            status.Text = "Selected " .. value
            status.TextColor3 = T.Sub
        end
    )

    self:CreateSearchRow(left, "Search mob...", function(query)
        query = tostring(query or ""):lower()
        if query == "" then return end

        for _, name in ipairs(mobList) do
            if name:lower():find(query, 1, true) then
                selectedMob = name
                farm:SetMob(name)
                setMob(name, false)
                status.Text = "Selected " .. name
                status.TextColor3 = T.Mint
                return
            end
        end

        status.Text = "Mob not found"
        status.TextColor3 = T.Danger
    end)

    local weaponOptions = {
        "ช่อง 1",
        "ช่อง 2",
        "ช่อง 3",
        "ช่อง 4",
        "ช่อง 5",
    }

    self:CreateDropdown(
        left,
        "Farm weapon",
        "Use Item_Equip slot 1-5",
        weaponOptions,
        farm.SelectedWeapon or "ช่อง 1",
        function(value)
            farm.SelectedWeapon = value
            farm._lastHotbarSelection = nil
            farm._lastHotbarCharacter = nil
            combat.EquipReadyAt = 0
            status.Text = "Weapon: " .. value
            status.TextColor3 = T.Mint
        end
    )

    self:CreateToggle(
        left,
        "Auto quest",
        farm.AutoQuest == true,
        function(on)
            self:Quest():SetAutoQuest(on)
            status.Text = on
                and "Auto quest enabled"
                or "Auto quest disabled"
            status.TextColor3 = on and T.Gold or T.Sub
        end
    )

    self:CreateButton(
        left,
        "▣ รับเควส Mitsu Lv105",
        function()
            local ok, err = self:Quest():AcceptOnce(
                "Demon Slayer Mitsu",
                "Ill drive back the frost(Lv 105)"
            )
            status.Text = ok
                and "รับเควส Mitsu Lv105 แล้ว"
                or ("รับเควสไม่สำเร็จ: " .. tostring(err))
            status.TextColor3 = ok and T.Mint or T.Danger
        end
    )

    self:CreateButton(
        left,
        "▣ รับเควส Mitsu Lv115",
        function()
            local ok, err = self:Quest():AcceptOnce(
                "Demon Slayer Mitsu",
                "Ill put out the blaze(Lv 115)"
            )
            status.Text = ok
                and "รับเควส Mitsu Lv115 แล้ว"
                or ("รับเควสไม่สำเร็จ: " .. tostring(err))
            status.TextColor3 = ok and T.Mint or T.Danger
        end
    )

    self:CreateSlider(
        right,
        "Mob Hitbox Size",
        "ขนาด hitbox ของมอนที่ล็อก",
        5,
        40,
        farm.Hitbox or 18,
        " st",
        function(value)
            farm.Hitbox = value
        end
    )

    farm.PlayerAttackHitbox = farm.PlayerAttackHitbox or 30
    self:CreateSlider(
        right,
        "Player Attack Hitbox",
        "ขยายพื้นที่ตีของ BasePart ทุกชิ้นในอาวุธที่ถืออยู่",
        5,
        100,
        farm.PlayerAttackHitbox,
        " st",
        function(value)
            farm.PlayerAttackHitbox = value
        end
    )

    self:CreateSlider(
        right,
        "Attack range",
        "Attack trigger range; server validates hits",
        5,
        25,
        farm.AttackRange or 12,
        " st",
        function(value)
            farm.AttackRange = value
        end
    )

    local combatInfo = legacyLabel(
        right,
        "Change attack position in the Attack position card. Settings apply to mobs and bosses.",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 24)
    )
    combatInfo.TextWrapped = true

    local perf = legacyLabel(
        right,
        "FPS / การโจมตี • รอเปิด Auto Attack",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 30)
    )
    perf.TextWrapped = true

    self:CreateToggle(
        right,
        "Fast Attack",
        farm.FastAttack == true,
        function(on)
            farm.FastAttack = on
            combat.PreferredDriver = nil
            combat:Release()
            combat:ResetProgress()
            combat.NextAttackAt = 0

            if on and farm.BypassComboGate then
                combat:BindGameComboGate()
            else
                combat:UnbindGameComboGate()
            end
        end
    )

    self:CreateToggle(
        right,
        "Continuous Combo Reset",
        farm.BypassComboGate == true,
        function(on)
            farm.BypassComboGate = on
            if on then
                combat:BindGameComboGate()
                combat.NextAttackAt = 0
            else
                combat:UnbindGameComboGate()
            end
        end
    )

    self:CreateSlider(
        right,
        "Attack Interval",
        "1 request ต่อรอบโจมตี",
        20,
        200,
        (farm.AttackInterval or 0.06) * 1000,
        " ms",
        function(value)
            farm.AttackInterval = value / 1000
            combat.AdaptiveInterval = farm.AttackInterval
        end
    )

    self.MobFarmSetter = farmSetter
    self.MobDropdownGetter = getMob
end

function UI:BuildBossFarmPage()
    local farm = self:Farm()
    local boss = self:Boss()
    local loot = self:Loot()
    local left, right = self:CreatePage("Boss Farm")

    local status = legacyLabel(
        left,
        "Boss ready",
        11,
        T.Gold,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 22)
    )

    loot.OnStatus = function(text)
        status.Text = text
        status.TextColor3 = T.Mint
    end

    local bossList = boss.Names or {}
    local selected = farm.BossName or bossList[1]

    self:CreateSection(left, "Boss Farm")

    local _, getBoss = self:CreateDropdown(
        left,
        "เลือกบอสช่องที่ 1",
        "",
        bossList,
        selected,
        function(value)
            selected = value
            farm:SetBoss(value)
            status.Text = "Selected " .. value
            status.TextColor3 = T.Gold
        end
    )

    self:CreateButton(
        left,
        "▶ Start Single Boss",
        function()
            local name = getBoss and getBoss() or selected

            if not name then
                status.Text = "ต้องเลือกบอสก่อน"
                status.TextColor3 = T.Danger
                return
            end

            boss:ClearSelection()
            boss:SetSelected(name, true)

            local ok, err = boss:StartSelected()

            status.Text = ok
                and ("ฟาร์ม " .. name .. " (boss)")
                or tostring(err)

            status.TextColor3 =
                ok and T.Gold or T.Danger
        end
    )

    self:CreateToggle(
        left,
        "เก็บของหลังบอสตาย",
        loot.Enabled,
        function(on)
            loot:SetEnabled(on)
        end
    )

    self:CreateButton(left, "■ Stop Boss Farm", function()
        boss:Stop()
        status.Text = "Boss farm stopped"
        status.TextColor3 = T.Sub
    end)

    self:CreateSection(left, "Farm Boss All")

    self:CreateButton(
        left,
        "▶ Start Selected Bosses",
        function()
            local ok, err = boss:StartSelected()

            status.Text = ok
                and (
                    "Boss All • "
                    .. tostring(#boss.Order)
                    .. " selected"
                )
                or tostring(err)

            status.TextColor3 =
                ok and T.Mint or T.Danger
        end
    )

    self:CreateButton(left, "Clear Selection", function()
        boss:ClearSelection()

        for _, setter in pairs(
            self.BossToggleSetters or {}
        ) do
            setter(false, false)
        end

        status.Text = "Selection cleared"
        status.TextColor3 = T.Sub
    end)

    self:CreateSection(right, "Boss Selection")

    self.BossToggleSetters = {}

    for _, name in ipairs(bossList) do
        local bossName = name

        local _, _, setter = self:CreateToggle(
            right,
            "Boss • " .. bossName,
            boss.Selected[bossName] == true,
            function(on)
                boss:SetSelected(bossName, on)

                status.Text =
                    "Selected "
                    .. tostring(#boss.Order)
                    .. " boss(es)"

                status.TextColor3 =
                    #boss.Order > 0
                    and T.Mint
                    or T.Sub
            end
        )

        self.BossToggleSetters[bossName] = setter
    end
end


function UI:BuildCombatPage()
    local farm = self:Farm()
    local combat = self:Combat()
    local aimbot = self:Aimbot()
    local left, right = self:CreatePage("Combat")

    local aimStatus = legacyLabel(
        left,
        "Aimbot ready",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 18)
    )

    self:CreateSection(left, "Aimbot")

    self:CreateToggle(
        left,
        "Aimbot",
        aimbot.Enabled == true,
        function(on)
            aimbot:SetEnabled(on)
            aimStatus.Text = on
                and "Aimbot enabled • hold Right Mouse to lock"
                or "Aimbot disabled"
            aimStatus.TextColor3 = on and T.Mint or T.Sub
        end
    )

    self:CreateToggle(
        left,
        "Show FOV circle",
        aimbot.ShowFOV == true,
        function(on)
            aimbot:SetShowFOV(on)
        end
    )

    self:CreateSlider(
        left,
        "FOV radius",
        "Circle follows mouse • hold Left Alt = screen center",
        50,
        500,
        aimbot.FOV or 180,
        " px",
        function(value)
            aimbot:SetFOV(value)
        end
    )

    self:CreateSection(left, "Combat")

    self:CreateToggle(
        left,
        "Auto Attack",
        farm.AutoAttack == true,
        function(on)
            farm.AutoAttack = on
            if not on then
                combat:ReleaseAttack()
            end
        end
    )

    self:CreateToggle(
        left,
        "Fast Attack",
        farm.FastAttack == true,
        function(on)
            farm.FastAttack = on
            combat:ResetProgress()
        end
    )

    self:CreateToggle(
        left,
        "Continuous Combo Reset",
        farm.BypassComboGate == true,
        function(on)
            farm.BypassComboGate = on

            if on then
                combat:BindGameComboGate()
            else
                combat:UnbindGameComboGate()
            end
        end
    )

    self:CreateSection(right, "Targets")

    self:CreateToggle(
        right,
        "Aim at players",
        aimbot.TargetPlayers ~= false,
        function(on)
            aimbot.TargetPlayers = on
        end
    )

    self:CreateToggle(
        right,
        "Aim at NPCs",
        aimbot.TargetNPCs ~= false,
        function(on)
            aimbot.TargetNPCs = on
        end
    )

    self:CreateSection(right, "Aimbot Skills")

    self:CreateToggle(
        right,
        "Skill Aimbot",
        aimbot.SkillEnabled == true,
        function(on)
            aimbot:SetSkillEnabled(on)
            aimStatus.Text = on
                and "Skill aimbot enabled • Z X C V B N K"
                or "Skill aimbot disabled"
            aimStatus.TextColor3 = on and T.Mint or T.Sub
        end
    )

    local skillHint = legacyLabel(
        right,
        "Z  X  C  V  B  N  K\nHold Right Mouse + skill key to lock closest target inside FOV.",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 44)
    )
    skillHint.TextWrapped = true

    self:CreateToggle(
        right,
        "No Swing Animation",
        farm.NoSwingAnimation == true,
        function(on)
            farm.NoSwingAnimation = on

            if not on then
                combat:RestoreSwingAnimations()
            end
        end
    )

    self:CreateToggle(
        right,
        "Adaptive Fast Attack",
        farm.AdaptiveFastAttack == true,
        function(on)
            farm.AdaptiveFastAttack = on
            combat.AdaptiveInterval =
                math.clamp(
                    tonumber(farm.AttackInterval) or 0.06,
                    0.01,
                    0.08
                )
            combat.NoDamageAttempts = 0
        end
    )

    self:CreateSection(right, "Attack Settings")

    self:CreateSlider(
        right,
        "Attack Interval",
        "ความถี่ในการส่งคำสั่งโจมตี",
        20,
        200,
        (farm.AttackInterval or 0.06) * 1000,
        " ms",
        function(value)
            farm.AttackInterval = value / 1000
            combat.AdaptiveInterval = farm.AttackInterval
        end
    )

    self:CreateSlider(
        right,
        "Attack Range",
        "ระยะที่จะเริ่มโจมตีเป้าหมาย",
        5,
        25,
        farm.AttackRange or 12,
        " st",
        function(value)
            farm.AttackRange = value
        end
    )
end


function UI:BuildSkillPage()
    local skill = self:Skill()
    local left, right = self:CreatePage("Skill")

    self:CreateSection(left, "Auto Skills")
    self:CreateToggle(
        left,
        "Auto Skills",
        skill.Enabled == true,
        function(on)
            skill:SetEnabled(on)
        end
    )

    local side = left

    for index, key in ipairs(skill.Keys or {}) do
        local skillKey = key
        local setting = skill.Settings[skillKey]

        if index > math.ceil(#skill.Keys / 2) then
            side = right
        end

        self:CreateToggle(
            side,
            "Skill " .. skillKey,
            setting and setting.Enabled == true,
            function(on)
                skill:SetKeyEnabled(skillKey, on)
            end
        )

        self:CreateSlider(
            side,
            "Interval " .. skillKey,
            "Repeat interval",
            0.1,
            10,
            setting and setting.Interval or 1,
            " s",
            function(value)
                skill:SetInterval(skillKey, value)
            end
        )
    end
end

function UI:BuildPlayerPage()
    local playerModule = self:Player()
    local farm = self:Farm()
    local left, right = self:CreatePage("Player")

    local status = legacyLabel(
        left,
        "Ready",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 16)
    )

    self:CreateSection(left, "Movement")

    self:CreateToggle(left, "วิ่งไว", playerModule.SpeedEnabled, function(on)
        playerModule:SetSpeed(on)
        status.Text = on
            and ("เปิดวิ่งไว: " .. tostring(playerModule.WalkSpeed))
            or "ปิดวิ่งไวแล้ว"
        status.TextColor3 = on and T.Mint or T.Sub
    end)

    self:CreateSlider(
        left,
        "ความเร็ววิ่ง",
        "",
        16,
        150,
        playerModule.WalkSpeed,
        "",
        function(value)
            playerModule.WalkSpeed = math.floor(value + 0.5)
            if playerModule.SpeedEnabled then
                playerModule:SetSpeed(true)
            end
        end
    )

    self:CreateToggle(left, "กระโดดสูง", playerModule.JumpEnabled, function(on)
        playerModule:SetJump(on)
        status.Text = on
            and ("เปิดกระโดดสูง: " .. tostring(playerModule.JumpPower))
            or "ปิดกระโดดสูงแล้ว"
        status.TextColor3 = on and T.Mint or T.Sub
    end)

    self:CreateSlider(
        left,
        "แรงกระโดด",
        "",
        50,
        200,
        playerModule.JumpPower,
        "",
        function(value)
            playerModule.JumpPower = math.floor(value + 0.5)
            if playerModule.JumpEnabled then
                playerModule:SetJump(true)
            end
        end
    )

    self:CreateToggle(left, "Fly", playerModule.FlyEnabled, function(on)
        playerModule:SetFly(on)
        status.Text = on
            and ("เปิด Fly • Speed " .. tostring(playerModule.FlySpeed))
            or "ปิด Fly แล้ว"
        status.TextColor3 = on and T.Mint or T.Sub
    end)

    self:CreateSlider(
        left,
        "Fly Speed",
        "WASD • Space ขึ้น • Ctrl ลง",
        20,
        500,
        playerModule.FlySpeed,
        "",
        function(value)
            playerModule.FlySpeed = math.floor(value + 0.5)
        end
    )

    self:CreateSection(left, "Invisible")

    self:CreateToggle(left, "Invisible", playerModule.InvisibleEnabled, function(on)
        playerModule:SetInvisible(on)
        status.Text = on
            and "Invisible enabled • local ghost visible"
            or "Invisible disabled"
        status.TextColor3 = on and T.Mint or T.Sub
    end)

    local invisibleHint = legacyLabel(
        left,
        "ตัวจริงถูกซ่อน • ฝั่งผู้ใช้เห็นเป็นเงาจางๆ",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 30)
    )
    invisibleHint.TextWrapped = true

    self:CreateSection(right, "Hitbox")

    self:CreateToggle(
        right,
        "ทดสอบ Hitbox การตี",
        farm.PlayerHitboxTest == true,
        function(on)
            farm:SetPlayerHitboxTest(on)
            status.Text = on
                and "เปิดทดสอบ Hitbox • ถืออาวุธแล้วลองตีเอง"
                or "ปิดทดสอบ Hitbox"
            status.TextColor3 = on and T.Gold or T.Sub
        end
    )

    farm.PlayerAttackHitbox = farm.PlayerAttackHitbox or 30
    self:CreateSlider(
        right,
        "ระยะ Hitbox การตี",
        "ขนาดพื้นที่ตีของอาวุธที่ถืออยู่",
        5,
        100,
        farm.PlayerAttackHitbox,
        " st",
        function(value)
            farm.PlayerAttackHitbox = math.floor(value + 0.5)
        end
    )

    self:CreateSection(right, "Collision")

    self:CreateToggle(right, "No Clip", playerModule.NoClipEnabled, function(on)
        playerModule:SetNoClip(on)
        status.Text = on
            and "เปิด No Clip"
            or "ปิด No Clip และคืนค่าการชนแล้ว"
        status.TextColor3 = on and T.Gold or T.Sub
    end)

    self:CreateSection(right, "Environment")

    self:CreateToggle(right, "Full Bright", playerModule.FullBrightEnabled, function(on)
        playerModule:SetFullBright(on)
        status.Text = on
            and "Full Bright enabled"
            or "Full Bright disabled"
        status.TextColor3 = on and T.Mint or T.Sub
    end)

    self:CreateToggle(right, "No Fog (ลบหมอก)", playerModule.NoFogEnabled, function(on)
        playerModule:SetNoFog(on)
        status.Text = on and "เปิด No Fog" or "ปิด No Fog"
        status.TextColor3 = on and T.Mint or T.Sub
    end)

    self:CreateToggle(right, "ลบ Atmosphere", false, function(on)
        playerModule:SetAtmosphereRemoved(on)
    end)

    self:CreateSlider(
        right,
        "Fog End",
        "ระยะไกลสุดของหมอก",
        100,
        5000,
        1000,
        " st",
        function(value)
            playerModule:SetFogEnd(value)
        end
    )
end

function UI:BuildTeleportPage()
    local teleport = self:Teleport()
    local left, right = self:CreatePage("Teleport")

    local status = legacyLabel(
        left,
        "พร้อม",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 16)
    )

    self:CreateSection(left, "NPCs — ทุกโซน")

    local npcs = teleport.NPCs or {}
    local selectedNpc = npcs[1]

    local _, getNpc, setNpc = self:CreateDropdown(
        left,
        "เลือก NPC",
        "เลือกแล้วกดวาป",
        npcs,
        selectedNpc,
        function(name)
            selectedNpc = name
        end
    )

    self:CreateSearchRow(left, "Search NPC...", function(query)
        query = tostring(query or ""):lower()
        if query == "" then return end

        for _, name in ipairs(npcs) do
            if name:lower():find(query, 1, true) then
                selectedNpc = name
                setNpc(name, false)
                status.Text = "Selected " .. name
                status.TextColor3 = T.Mint
                return
            end
        end

        status.Text = "NPC not found"
        status.TextColor3 = T.Danger
    end)

    self:CreateButton(left, "⟶ วาปไป NPC ที่เลือก", function()
        local name = getNpc and getNpc() or selectedNpc
        local ok, err = teleport:GoNPC(name)
        status.Text = ok
            and ("→ " .. tostring(name))
            or ("ล้มเหลว: " .. tostring(err))
        status.TextColor3 = ok and T.Mint or T.Danger
    end)

    self:CreateSection(left, "Players")

    local playerNames = teleport:PlayerNames()
    if #playerNames == 0 then
        playerNames = { "— ไม่มีผู้เล่นอื่น —" }
    end

    local _, getPlayer = self:CreateDropdown(
        left,
        "Players",
        "เลือกผู้เล่นในเซิร์ฟเวอร์",
        playerNames,
        playerNames[1]
    )

    self:CreateButton(left, "⟶ วาปไปผู้เล่นที่เลือก", function()
        local name = getPlayer and getPlayer()
        if name == "— ไม่มีผู้เล่นอื่น —" then
            status.Text = "ไม่มีผู้เล่นอื่นในเซิร์ฟเวอร์"
            status.TextColor3 = T.Danger
            return
        end

        local ok, err = teleport:GoPlayer(name)
        status.Text = ok
            and ("→ Player: " .. tostring(name))
            or ("ล้มเหลว: " .. tostring(err))
        status.TextColor3 = ok and T.Mint or T.Danger
    end)

    self:CreateButton(left, "⇢ ดึงผู้เล่นที่เลือกมาหาเรา", function()
        local name = getPlayer and getPlayer()

        if not name
            or name == "— ไม่มีผู้เล่นอื่น —" then
            status.Text = "ไม่มีผู้เล่นอื่นในเซิร์ฟเวอร์"
            status.TextColor3 = T.Danger
            return
        end

        local ok, err = teleport:BringPlayer(name)

        status.Text = ok
            and ("Bring → " .. tostring(name))
            or ("Bring ล้มเหลว: " .. tostring(err))

        status.TextColor3 =
            ok and T.Gold or T.Danger
    end)

    self:CreateSection(right, "วาปด่วน")

    for _, npcName in ipairs({
        "Krue",
        "Betty",
        "Kazu",
        "Kona",
        "Tom",
        "Chaka",
        "Demon Slayer Mitsu",
        "Thunder Trainer Zentaro",
    }) do
        local name = npcName

        self:CreateButton(right, "⟶ " .. name, function()
            local ok, err = teleport:GoNPC(name)
            status.Text = ok
                and ("→ " .. name)
                or ("ล้มเหลว: " .. tostring(err))
            status.TextColor3 = ok and T.Mint or T.Danger
        end)
    end

    self:CreateSection(right, "อื่น ๆ")

    self:CreateButton(right, "⟶ Spawn", function()
        local ok, err = teleport:Spawn()
        status.Text = ok and "→ Spawn" or tostring(err)
        status.TextColor3 = ok and T.Mint or T.Danger
    end)

    self:CreateButton(right, "⟶ ขึ้นฟ้า (+100)", function()
        local ok, err = teleport:Sky()
        status.Text = ok and "→ Sky +100" or tostring(err)
        status.TextColor3 = ok and T.Mint or T.Danger
    end)

    self:CreateButton(right, "⟶ ลงพื้น (Raycast)", function()
        local ok, err = teleport:Ground()
        status.Text = ok and "→ Ground" or tostring(err)
        status.TextColor3 = ok and T.Mint or T.Danger
    end)
end

function UI:BuildWorldPage()
    local teleport = self:Teleport()
    local world = self:World()
    local left, right = self:CreatePage("World")

    local status = legacyLabel(
        left,
        "World ready",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 16)
    )

    world.Cup.OnStatus = function(text)
        status.Text = text
        status.TextColor3 = T.Mint
    end

    world.Thunder.OnStatus = function(text)
        status.Text = text
        status.TextColor3 = T.Gold
    end

    world.Pushups.OnStatus = function(text)
        status.Text = text
        status.TextColor3 = T.Accent
    end

    self:CreateSection(right, "Npc LV 1-7")

    self:CreateButton(right, "⟶ Krue", function()
        local ok, err = teleport:GoNPC("Krue")
        status.Text = ok and "→ Krue" or tostring(err)
        status.TextColor3 = ok and T.Mint or T.Danger
    end)

    self:CreateSection(right, "Pushups")

    self:CreateToggle(
        right,
        "Auto Pushups",
        world.Pushups.Enabled,
        function(on)
            world:SetPushupsEnabled(on)
        end
    )

    local pushHint = legacyLabel(
        right,
        "ตรวจวง timing และคลิกซ้ายอัตโนมัติเมื่อวงเข้าจังหวะ",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 42)
    )
    pushHint.TextWrapped = true

    self:CreateSection(left, "Cup Game")

    self:CreateToggle(
        left,
        "ESP Cup2",
        world.Cup.Enabled,
        function(on)
            world:SetCupEnabled(on)
        end
    )

    local cupHint = legacyLabel(
        left,
        'Outline สีขาวเฉพาะ workspace.Training["Cup Game"].Cupgame1.Cups.Cup2',
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 36)
    )
    cupHint.TextWrapped = true

    self:CreateSection(left, "ปราณสายฟ้า")

    self:CreateToggle(
        left,
        "Auto ทำปราณสายฟ้า",
        world.Thunder.Enabled,
        function(on)
            world:SetThunderEnabled(on)
        end
    )

    self:CreateButton(
        left,
        "⚡ Thunder Trainer Zentaro",
        function()
            local ok, err =
                teleport:GoNPC(
                    "Thunder Trainer Zentaro"
                )

            status.Text = ok
                and "→ Thunder Trainer Zentaro"
                or tostring(err)

            status.TextColor3 =
                ok and T.Mint or T.Danger
        end
    )
end


function UI:BuildSettingsPage()
    local settings = self:Settings()
    local visuals = self:Visuals()
    local left, right = self:CreatePage("Settings")

    self:CreateSection(left, "ภาษา")

    self:CreateDropdown(
        left,
        "ภาษาเมนู",
        "โครงภาษาเดิม • ตัวเลือก UI",
        { "ไทย / Thai", "English" },
        self.Language,
        function(value) self:SetLanguage(value) end
    )

    self:CreateSection(left,"Keyboard")
    self.MenuKeyButton=self:CreateButton(left,"Menu key: "..self.MenuKey.Name,function(b)
        self.CapturingMenuKey=true
        b.Text="Press a key (Esc cancels)"
    end)
    self:CreateButton(left,"Reset key to RightShift",function()
        self.CapturingMenuKey=false;self.MenuKey=Enum.KeyCode.RightShift
        self.MenuKeyButton.Text="Menu key: RightShift"
    end)
    self:CreateSection(left, "Player labels")

    legacyLabel(
        left,
        "RightShift • เปิด/ปิดเมนู",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 28)
    )

    self:CreateDropdown(
        left,
        "Label layout",
        "Stacking style",
        { "Stacked", "Inline", "Compact" },
        visuals.LabelLayout or "Stacked",
        function(value)
            visuals:SetLabelLayout(value)
        end
    )

    self:CreateSlider(
        left,
        "Label scale",
        "Text size multiplier",
        50,
        200,
        math.floor((visuals.LabelScale or 1) * 100),
        "%",
        function(value)
            visuals:SetLabelScale(value / 100)
        end
    )

    self:CreateToggle(
        left,
        "Show distance",
        visuals.ShowDistance ~= false,
        function(on)
            visuals:SetShowDistance(on)
        end
    )

    self:CreateToggle(
        left,
        "Hide when aiming",
        visuals.HideWhenAiming == true,
        function(on)
            visuals:SetHideWhenAiming(on)
        end
    )

    self:CreateSection(right, "Performance / ประสิทธิภาพ")

    self:CreateToggle(
        right,
        "ภาพต่ำ / FPS Boost",
        settings.LowGraphicsEnabled,
        function(on)
            settings:SetLowGraphics(on)
        end
    )

    local perfHint = legacyLabel(
        right,
        "ลดเงา เท็กซ์เจอร์ และเอฟเฟกต์ • ปิดเพื่อคืนภาพ",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 34)
    )
    perfHint.TextWrapped = true

    self:CreateSection(right, "Interface")

    self:CreateToggle(
        right,
        "Blur background",
        self.BlurEnabled == true,
        function(on)
            self.BlurEnabled = on == true

            local lighting = game:GetService("Lighting")
            local blur =
                lighting:FindFirstChild("MazxhubUIBlur")

            if self.BlurEnabled then
                if not blur then
                    blur = Instance.new("BlurEffect")
                    blur.Name = "MazxhubUIBlur"
                    blur.Size = 12
                    blur.Parent = lighting
                end
                blur.Enabled = true
            elseif blur then
                blur:Destroy()
            end
        end
    )

    self:CreateToggle(
        right,
        "Animations",
        self.AnimationsEnabled ~= false,
        function(on)
            self.AnimationsEnabled = on == true
        end
    )

    self:CreateSlider(
        right,
        "UI opacity",
        "Panel transparency",
        0,
        100,
        100,
        "%",
        function(value)
            local transparency = 1 - value / 100
            self.Main.BackgroundTransparency = transparency
            self.Sidebar.BackgroundTransparency = transparency

            if self.SidebarEdge then
                self.SidebarEdge.BackgroundTransparency = transparency
            end
        end
    )
end


function UI:BuildQuestsPage()
    local quest = self:Quest()
    local left, right = self:CreatePage("Quests")

    local entries = {
        {
            Name = "Kazu",
            Title = "Quest 1 • Kazu • Lv 1-10",
            Side = left,
        },
        {
            Name = "Betty",
            Title = "Quest 2 • Betty • Lv 10",
            Side = left,
        },
        {
            Name = "Delivery",
            Title = "Quest 3 • MoldySugar • Lv 1-10",
            Side = left,
        },
        {
            Name = "Pages",
            Title = "Quest 4 • Kona • Lv 1-10",
            Side = right,
        },
        {
            Name = "Bear",
            Title = "Quest 5 • Lucy / Tom / Bear Cub",
            Side = right,
        },
        {
            Name = "HunterExam",
            Title = "สอบนักล่า",
            Side = {IsColumn=true,Source="Quests",Page="Hunter Exam",Column=1,Heading="Hunter Exam"},
        },
    }

    self.QuestSetters = self.QuestSetters or {}

    for _, entry in ipairs(entries) do
        local questName = entry.Name
        local record = quest.Quests[questName]

        local statusLabel = legacyLabel(
            entry.Side,
            record and record.Status or (questName .. " • OFF"),
            11,
            T.Sub,
            Enum.Font.Gotham,
            nil,
            UDim2.new(1, 0, 0, 30)
        )
        statusLabel.TextWrapped = true

        if record then
            record.OnStatus = function(text)
                statusLabel.Text = text
                statusLabel.TextColor3 =
                    record.Enabled and T.Mint or T.Sub
            end
        end

        local _, _, setter = self:CreateSection(
            entry.Side,
            entry.Title,
            record and record.Enabled or false,
            function(on)
                quest:SetDedicatedEnabled(questName, on)

                if record then
                    statusLabel.Text = record.Status
                    statusLabel.TextColor3 =
                        on and T.Mint or T.Sub
                end
            end
        )

        self.QuestSetters[questName] = setter

        if questName == "HunterExam" then
            self:CreateButton(
                entry.Side,
                "▶ Continue หลังทำช่วง Manual",
                function()
                    local ok, message =
                        quest:ContinueHunterExam()

                    statusLabel.Text =
                        message or (
                            ok
                            and "สอบนักล่า • ไปต่อแล้ว"
                            or "สอบนักล่า • ยังไปต่อไม่ได้"
                        )
                    statusLabel.TextColor3 =
                        ok and T.Mint or T.Gold
                end
            )
        end

        if record then
            record.OnEnabled = function(on)
                setter(on, false)
            end
        end
    end

    self:CreateSection(right, "Auto Quest ตามมอน/บอส")

    local autoHint = legacyLabel(
        right,
        "ใช้ Auto Quest ที่หน้า Mob Farm/Boss Farm ระบบจะไปรับเควสตามเป้าหมายแล้วกลับมาตีต่ออัตโนมัติ",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 54)
    )
    autoHint.TextWrapped = true
end

function UI:BuildDungeonPage()
    local dungeon = self:Dungeon()
    local left, right = self:CreatePage("Dungeon")

    local status = legacyLabel(
        left,
        "Dungeon ready",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 20)
    )

    dungeon.Unlock.OnStatus = function(text)
        status.Text = text
        status.TextColor3 = T.Gold
    end

    self:CreateSection(left, "Auto Dungeon")

    local _, _, dungeonSetter = self:CreateToggle(
        left,
        "Auto Dungeon",
        dungeon.Enabled,
        function(on)
            dungeon:SetEnabled(on)
            status.Text = on
                and "Auto Dungeon enabled"
                or "Auto Dungeon disabled"
            status.TextColor3 = on and T.Mint or T.Sub
        end
    )

    dungeon.OnEnabled = function(on)
        dungeonSetter(on, false)
        status.Text = on
            and "Auto Dungeon enabled"
            or "Auto Dungeon disabled"
        status.TextColor3 = on and T.Mint or T.Sub
    end

    self:CreateSlider(
        left,
        "ความสูงก่อนวาปลงตี",
        "ระยะลอยเหนือ HumanoidRootPart ก่อนเข้าตำแหน่งตี",
        20,
        120,
        dungeon.ApproachSkyHeight,
        " st",
        function(value)
            dungeon.ApproachSkyHeight = value
        end
    )

    self:CreateSlider(
        left,
        "เวลาลอยบนฟ้า",
        "รอก่อนลงไปตีมอน",
        0.1,
        3,
        dungeon.ApproachDelay,
        " s",
        function(value)
            dungeon.ApproachDelay = value
        end
    )

    self:CreateSlider(
        left,
        "หน่วงก่อนตีตัวถัดไป",
        "หลังมอนตาย รอก่อนเลือกเป้าตัวใหม่",
        0.1,
        2,
        dungeon.NextTargetDelay,
        " s",
        function(value)
            dungeon.NextTargetDelay = value
        end
    )

    self:CreateSection(right, "Dungeon Combat")

    self:CreateToggle(
        right,
        "Auto Skip",
        dungeon.AutoSkip,
        function(on)
            dungeon:SetAutoSkip(on)
        end
    )

    self:CreateToggle(
        right,
        "Kill Aura",
        dungeon.KillAura,
        function(on)
            dungeon:SetKillAura(on)
        end
    )

    self:CreateSlider(
        right,
        "Kill Aura Range",
        "รัศมีส่ง Combat Service เพิ่มเติม",
        5,
        60,
        dungeon.KillAuraRadius,
        " st",
        function(value)
            dungeon.KillAuraRadius = value
        end
    )

    self:CreateSection(right, "Quest unlock Dungeon • Lv65+")

    self:CreateToggle(
        right,
        "Auto Quest Dungeon",
        dungeon.Unlock.Enabled,
        function(on)
            dungeon:SetUnlockEnabled(on)
        end
    )

    local unlockHint = legacyLabel(
        right,
        "ไปหา Blacksmith Togane → รับเควส Ill find the forge(Lv 65) → ไป Forge → กด T",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 52)
    )
    unlockHint.TextWrapped = true
end

function UI:BuildRaidsPage()
    local raid = self:Raid()
    local left, right = self:CreatePage("Raids")

    local status = legacyLabel(
        left,
        raid.Status or "Raid ready",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 34)
    )
    status.TextWrapped = true

    raid.OnStatus = function(text)
        status.Text = text
        status.TextColor3 =
            raid.Enabled and T.Mint or T.Sub
    end

    self:CreateSection(
        left,
        "Raid Chest • Auto Scan All Points"
    )

    local _, _, raidSetter = self:CreateToggle(
        left,
        "Auto Raid Chest",
        raid.Enabled,
        function(on)
            raid:SetEnabled(on)
        end
    )

    raid.OnEnabled = function(on)
        raidSetter(on, false)
        status.Text = on
            and "Raid Chest • ON"
            or "Raid Chest • OFF"
        status.TextColor3 = on and T.Mint or T.Sub
    end

    self:CreateButton(
        left,
        "เริ่มจากจุด 1 ใหม่",
        function()
            raid:SetPoint(1)
            raid.Phase = "checkMove"
            raid.NextAt = 0
            raid:SetStatus("Raid • รีเซ็ตไปจุด 1")
        end
    )

    self:CreateSection(right, "Saved Raid Points")

    local pointCount = raid:PointCount()

    legacyLabel(
        right,
        "มีจุดที่บันทึกไว้ทั้งหมด "
            .. tostring(pointCount)
            .. " จุด",
        12,
        T.Text,
        Enum.Font.GothamBold,
        nil,
        UDim2.new(1, 0, 0, 30)
    )

    self:CreateSlider(
        right,
        "เริ่มตรวจจากจุด",
        "เปลี่ยนจุดเริ่มต้นของ Auto Raid",
        1,
        math.max(pointCount, 1),
        raid.PointIndex or 1,
        "",
        function(value)
            raid:SetPoint(
                math.floor(value + 0.5)
            )
        end
    )

    local hint = legacyLabel(
        right,
        "ระบบจะตรวจมอน → ฟาร์มจนหมด → เปิดกล่อง → กด T เก็บของ → ไปจุดถัดไป",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 54)
    )
    hint.TextWrapped = true
end

function UI:BuildVisualsPage()
    local visuals = self:Visuals()
    local boss = self:Boss()
    local left, right = self:CreatePage("Visuals")

    self:CreateSection(left, "ESP ผู้เล่น")

    self:CreateToggle(
        left,
        "ESP Player",
        visuals.Enabled,
        function(on)
            visuals:SetPlayerESP(on)
        end
    )

    self:CreateToggle(
        left,
        "ESP Line",
        visuals.Lines,
        function(on)
            visuals:SetLines(on)
        end
    )

    self:CreateToggle(
        left,
        "ESP Outline",
        visuals.Outlines,
        function(on)
            visuals:SetOutlines(on)
        end
    )

    self:CreateSlider(
        left,
        "ESP ระยะสูงสุด",
        "Max render distance",
        100,
        3000,
        visuals.MaxDistance,
        " st",
        function(value)
            visuals:SetMaxDistance(value)
        end
    )

    self:CreateSection(right, "ESP NPC ใน ActiveNpcs")

    self:CreateToggle(
        right,
        "ESP Bandit",
        visuals.Bandit,
        function(on)
            visuals:SetBandit(on)
        end
    )

    self:CreateToggle(
        right,
        "ESP Civilian",
        visuals.Civilian,
        function(on)
            visuals:SetCivilian(on)
        end
    )

    legacyLabel(
        right,
        "Bandit = สีแดง • Civilian = สีเขียว",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 24)
    )

    self:CreateSection(
        right,
        "ESP บอสทั้งหมด (เปิด/ปิด)"
    )

    self:CreateToggle(
        right,
        "ESP Boss All",
        visuals.BossEnabled,
        function(on)
            visuals:SetBossEnabled(on)
        end
    )

    for _, name in ipairs(boss.Names or {}) do
        local bossName = name

        self:CreateToggle(
            right,
            "ESP " .. bossName,
            visuals.BossSelected[bossName] ~= false,
            function(on)
                visuals:SetBossSelected(
                    bossName,
                    on
                )
            end
        )
    end
end

function UI:BuildStatusPage()
    local boss = self:Boss()
    local farm = self:Farm()
    local left, right = self:CreatePage("Status")

    self:CreateSection(left, "Runtime")
    self:CreateSection(right, "Boss Spawn Status")

    self.StatusLabels = {
        Farm = legacyLabel(
            left,
            "Farm: ...",
            11,
            T.Text,
            Enum.Font.Gotham,
            nil,
            UDim2.new(1, 0, 0, 26)
        ),
        Target = legacyLabel(
            left,
            "Target: ...",
            11,
            T.Text,
            Enum.Font.Gotham,
            nil,
            UDim2.new(1, 0, 0, 26)
        ),
        Combat = legacyLabel(
            left,
            "Combat: ...",
            11,
            T.Text,
            Enum.Font.Gotham,
            nil,
            UDim2.new(1, 0, 0, 26)
        ),
        Jobs = legacyLabel(
            left,
            "Jobs: ...",
            10,
            T.Sub,
            Enum.Font.Gotham,
            nil,
            UDim2.new(1, 0, 0, 72)
        ),
        Error = legacyLabel(
            left,
            "Error: none",
            10,
            T.Gold,
            Enum.Font.Gotham,
            nil,
            UDim2.new(1, 0, 0, 52)
        ),
    }

    self.StatusLabels.Jobs.TextWrapped = true
    self.StatusLabels.Error.TextWrapped = true

    local note = legacyLabel(
        right,
        "เวลาประมาณจากการตาย → เกิดที่ตรวจพบในเซสชันนี้",
        10,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 34)
    )
    note.TextWrapped = true

    self.BossStatusRows = {}

    local split =
        math.ceil(#boss.Names / 2)

    for index, name in ipairs(boss.Names) do
        local column =
            index <= split and left or right

        if index == 1 then
            self:CreateSection(
                left,
                "สถานะบอส / เวลาเกิด"
            )
        elseif index == split + 1 then
            self:CreateSection(
                right,
                "Boss List"
            )
        end

        local row = legacyNew("Frame", {
            Size = UDim2.new(1, 0, 0, 78),
            BackgroundColor3 = T.Card,
            BorderSizePixel = 0,
        }, column)
        corner(row, 7)
        stroke(row, T.Stroke, 1)

        local nameLabel = legacyLabel(
            row,
            name,
            12,
            T.Text,
            Enum.Font.GothamBold,
            UDim2.fromOffset(10, 6),
            UDim2.new(1, -20, 0, 18)
        )

        local region =
            farm.BossRegions
            and farm.BossRegions[name]
            or "Misc"

        local regionLabel = legacyLabel(
            row,
            region,
            9,
            T.Sub,
            Enum.Font.Gotham,
            UDim2.fromOffset(10, 24),
            UDim2.new(1, -20, 0, 14)
        )

        local statusLabel = legacyLabel(
            row,
            "กำลังตรวจสอบ...",
            10,
            T.Gold,
            Enum.Font.Gotham,
            UDim2.fromOffset(10, 40),
            UDim2.new(1, -20, 0, 16)
        )

        local detailLabel = legacyLabel(
            row,
            "",
            9,
            T.Sub,
            Enum.Font.Gotham,
            UDim2.fromOffset(10, 57),
            UDim2.new(1, -20, 0, 16)
        )
        detailLabel.TextTruncate =
            Enum.TextTruncate.AtEnd

        self.BossStatusRows[name] = {
            Status = statusLabel,
            Detail = detailLabel,
            Region = regionLabel,
            Name = nameLabel,
        }
    end
end

function UI:RefreshStatus()
    local labels = self.StatusLabels
    if not labels then return end

    local farm = self:Farm()
    local combat = self:Combat()
    local boss = self:Boss()
    local state = self.Ctx.State

    labels.Farm.Text =
        string.format(
            "Farm: %s • Mode: %s",
            farm.Enabled and "ON" or "OFF",
            tostring(
                state.FarmMode
                or farm.Mode
                or "-"
            )
        )

    labels.Target.Text =
        "Target: "
        .. tostring(
            state.TargetName
            or (
                state.Target
                and state.Target.Name
            )
            or "-"
        )

    labels.Combat.Text =
        "Combat: "
        .. tostring(combat.State or "idle")

    local jobNames = {}

    for name, job in pairs(self.Ctx.Jobs) do
        table.insert(
            jobNames,
            name
                .. "="
                .. (
                    job.Enabled
                    and "ON"
                    or "OFF"
                )
        )
    end

    table.sort(jobNames)

    labels.Jobs.Text =
        "Jobs: "
        .. table.concat(jobNames, " • ")

    labels.Error.Text =
        "Error: "
        .. tostring(
            farm._lastRuntimeError
            or "none"
        )

    local colors = {
        Mint = T.Mint,
        Gold = T.Gold,
        Sub = T.Sub,
    }

    for name, row in pairs(
        self.BossStatusRows or {}
    ) do
        local stateData =
            boss.StatusStates[name]

        local statusText,
            detailText,
            colorKey =
            boss:DescribeStatus(stateData)

        row.Status.Text = statusText
        row.Status.TextColor3 =
            colors[colorKey] or T.Sub
        row.Detail.Text = detailText
    end
end

for _,group in ipairs(navigation) do for _,item in ipairs(group.Items) do page(item[1]) end end
buildNavigation()

-- Reference controls are intentionally UI-only until a callback is registered.
-- Integration API: UI:On("reference.defense.ragdoll", callback).
do
    local nativeSection,nativeToggle,nativeSlider,nativeDropdown,nativeField,nativeAction=section,toggle,slider,dropdown,field,action
    local order=-1000
    local function section(...)
        local s=nativeSection(...);s.Reference=true;s.Frame.LayoutOrder=order;order=order+1;return s
    end
    local function toggle(s,id,...) return nativeToggle(s,"reference."..id,...) end
    local function slider(s,id,...) return nativeSlider(s,"reference."..id,...) end
    local function dropdown(s,id,...) return nativeDropdown(s,"reference."..id,...) end
    local function field(s,id,...) return nativeField(s,"reference."..id,...) end
    local function action(s,id,text,callback)
        return nativeAction(s,"reference."..id,text,callback or function()
            footer.Text="UI preview: "..text.." (not connected)"
        end)
    end
local Lists={
    Locations={"Bamboo Grove","Bamboo Grove Sanctuary","Bamboo Grove Shrine","Butterfly Estate","Butterfly Estate Shrine","Dreamfall Hollow","Final Selection","Frost Veil Shrine"},
    NPCs={"Lucy","Tom","Chaka","Krue","Rin","Demon Slayer Mitsu","Zentaro","Mother Bear","Kaiden","Rengu"},
    Reputation={"Mizunoto","Mizunoe","Kanoto","Kanoe"},
    Items={"Item 1 (example)","Item 2 (example)","Item 3 (example)"},
    Clans={"Clan 1 (example)","Clan 2 (example)","Clan 3 (example)"},
}
do
    local s=section("Main",1,"Combat")
    toggle(s,"combat.killAura","Kill aura",false,true)
    toggle(s,"combat.range","Range",true)
    slider(s,"combat.radius","Range radius",0,40,20," studs")
    slider(s,"combat.slot","Weapon slot",1,9,1)
    toggle(s,"combat.ignoreBosses","Ignore bosses")
    toggle(s,"combat.civilians","Hit civilians")
    s=section("Main",1,"Instakill")
    toggle(s,"instakill.enabled","Instakill")
    slider(s,"instakill.range","Instakill range",0,1000,150," studs")
    slider(s,"instakill.health","Kill at or below",0,100,100,"% health")
    toggle(s,"instakill.civilians","Instakill civilians")
    toggle(s,"instakill.debug","Debug to console")
    s=section("Main",1,"Private Server")
    field(s,"private.owner","Owner username","Username")
    s=section("Main",2,"Dialogue"); toggle(s,"dialogue.auto","Auto dialogue")
    s=section("Main",2,"Defense")
    for _,v in ipairs({{"ragdoll","Anti ragdoll"},{"dash","No dash cooldown"},{"stamina","Infinite stamina"},{"horse","Infinite horse stamina"},
        {"climb","Infinite climb"},{"slowdown","No attack slowdown"},{"drowning","No drowning"},{"sun","No sun damage"},{"parry","Auto parry"}}) do toggle(s,"defense."..v[1],v[2]) end
    slider(s,"defense.parryRange","Parry range",0,30,15," studs")
    s=section("Main",2,"Training")
    toggle(s,"training.qte","Auto training QTE"); toggle(s,"training.instant","Instant training"); note(s,"Off")
    s=section("Main",2,"Black market")
    toggle(s,"market.auto","Auto buy from the Black Market",false,true)
    dropdown(s,"market.items","Items",Lists.Items,true); note(s,"Off")
    s=section("Main",2,"Clan roll")
    toggle(s,"clan.auto","Auto roll clan"); dropdown(s,"clan.keep","Keep",Lists.Clans,true); note(s,"Off")
end

do
    for i,name in ipairs({"Players","Mobs"}) do
        local prefix=string.lower(name)
        local s=section("Visuals",i,name)
        toggle(s,prefix..".enabled","Enabled",false,true)
        for _,v in ipairs({{"name","Name"},{"distance","Distance"},{"box","Box"},{"fill","Box fill"},{"box3d","3D box"},{"healthBar","Health bar"},
            {"healthNumber","Health number"},{"tracer","Tracer"},{"arrow","Off-screen arrow"}}) do toggle(s,prefix.."."..v[1],v[2]) end
        slider(s,prefix..".maxDistance","Max distance",0,5000,1000," studs")
        slider(s,prefix..".textSize","Text size",8,30,13)
        toggle(s,prefix..".fade","Fade with distance")
    end
end

do
    local s=section("Player",1,"Character")
    toggle(s,"character.walk","Walk speed",false,true); slider(s,"character.speed","Speed",0,150,40)
    toggle(s,"character.fly","Fly",false,true); slider(s,"character.flySpeed","Fly speed",0,200,60)
    toggle(s,"character.noclip","Noclip",false,true); toggle(s,"character.jump","Infinite jump",false,true)
    s=section("Player",1,"Teleport to location")
    dropdown(s,"teleport.location","Location",Lists.Locations)
    action(s,"teleport.go","Teleport"); action(s,"teleport.market","Teleport to the Black Marketer"); action(s,"teleport.stop","Stop travelling")
    s=section("Player",1,"Performance"); note(s,"off")
    toggle(s,"performance.optimise","Optimise"); toggle(s,"performance.rendering","Stop rendering")
    toggle(s,"performance.cap","Cap FPS"); slider(s,"performance.fps","FPS",25,120,35)
    s=section("Player",2,"Muzan")
    action(s,"muzan.teleport","Teleport to Muzan"); action(s,"muzan.lair","Teleport to Muzan's lair (Sunless)")
    action(s,"muzan.doctor","Teleport to Dr. Higoshima"); action(s,"muzan.safe","Teleport to the safe zone")
    toggle(s,"muzan.lilies","Auto spider lilies"); toggle(s,"muzan.hop","Server hop when none left"); note(s,"Off")
    toggle(s,"muzan.demon","Become a demon"); dropdown(s,"muzan.reputation","Reputation mob",Lists.Reputation,false,"Mizunoto")
    toggle(s,"muzan.blood","Drink Muzan's Blood"); note(s,"Off")
    s=section("Player",2,"Teleport to NPC")
    dropdown(s,"teleport.npc","NPC, mob or boss",Lists.NPCs)
    action(s,"teleport.npcGo","Teleport")
end

do
    local s=section("Webhook",1,"Discord")
    toggle(s,"webhook.enabled","Discord webhook")
    field(s,"webhook.url","Webhook URL","https://discord.com/api/webhooks/...")
    field(s,"webhook.user","Ping user id","Discord user id")
    toggle(s,"webhook.everyone","Ping everyone"); toggle(s,"webhook.rich","Rich layout",true)
    toggle(s,"webhook.username","Include username",true); toggle(s,"webhook.spoiler","Hide username in a spoiler",true)
    note(s,"Nothing sent yet"); action(s,"webhook.test","Send test")
    s=section("Webhook",2,"Notifications")
    dropdown(s,"webhook.events","Ping for",{"Boss killed","Item looted","Quest completed","Chest opened","Server hop"},true,{"Boss killed","Item looted"})
    s=section("Webhook",2,"On every card")
    for _,v in ipairs({{"session","Session time"},{"level","Level"},{"exp","Exp gained"},{"wen","Wen earned"},{"mobs","Mobs killed"},{"bosses","Bosses killed"},
        {"items","Items looted"},{"chests","Chests opened"},{"quests","Quests completed"},{"hops","Server hops"},{"rates","Per hour rates"}}) do toggle(s,"card."..v[1],v[2],v[1]~="hops") end
    note(s,"Session  0m 0s\nKills    0\nBosses   0\nItems    0\nChests   0")
    action(s,"webhook.reset","Reset session")
end

do
    local s=section("Config",1,"Menu")
    action(s,"menu.keyboard","Change menu key",function() UI.CapturingMenuKey=true;UI.MenuKeyButton.Text="Press a key (Esc cancels)";footer.Text="Press a keyboard key; Esc cancels" end)
    action(s,"menu.unload","Unload",function() UI.Ctx:Shutdown() end)
    toggle(s,"menu.autoSave","Auto save",true)
    s=section("Config",1,"Account"); note(s,player.DisplayName.."\n@"..player.Name)
    s=section("Config",1,"Themes")
    for _,v in ipairs({{"background","Background color","#0C0C0F"},{"main","Main color","#17171C"},{"accent","Accent color","#CA394E"},
        {"outline","Outline color","#353237"},{"font","Font color","#EFEAED"}}) do field(s,"theme."..v[1],v[2],v[3]) end
    dropdown(s,"theme.face","Font Face",{"Code","Gotham","SourceSans","RobotoMono"},false,"Gotham")
    field(s,"theme.image","Background Image","rbxassetid://...")
    dropdown(s,"theme.list","Theme list",{"Default","Dark","Soft Red"},false,"Default")
    s=section("Config",2,"Configuration")
    field(s,"config.name","Config name",""); action(s,"config.create","Create config")
    dropdown(s,"config.list","Config list",{"Default"})
    for _,v in ipairs({{"load","Load config"},{"overwrite","Overwrite config"},{"delete","Delete config"},{"refresh","Refresh list"},
        {"autoload","Set as autoload"},{"resetAutoload","Reset autoload"}}) do action(s,"config."..v[1],v[2]) end
    note(s,"Current autoload config:\nNone")
    field(s,"config.json","Config JSON","")
    action(s,"config.import","Import config"); action(s,"config.export","Export current config")
end

end

-- Native layout only: no BuildTabs, old Sidebar, old columns, or legacy page frames.
self:BuildCombatPage()
self:BuildMobFarmPage()
self:BuildBossFarmPage()
self:BuildPlayerPage()
self:BuildTeleportPage()
self:BuildDungeonPage()
self:BuildVisualsPage()
self:BuildSettingsPage()
self:BuildQuestsPage()
self:BuildRaidsPage()
self:BuildWorldPage()
self:BuildSkillPage()
self:BuildStatusPage()
note(section("Home",1,"Interface preview"),"Reference cards keep their settings in this UI. Controls without a connected callback show UI preview in the footer. Existing gameplay controls are in the tools pages.")

do
    local q=self:Quest()
    local record=q.Quests.UnlockMarket
    local s=section("Unlock Market",1,"Unlock Market • Lv 45")
    local _,_,set=toggle(s,"quest.unlockMarket","Auto Unlock Market",record and record.Enabled or false)
    self.QuestSetters.UnlockMarket=set
    self:On("quest.unlockMarket",function(on) q:SetDedicatedEnabled("UnlockMarket",on) end)
    local status=label(s.Body,record and record.Status or "Unlock Market • OFF",UDim2.new(1,0,0,0))
    status.TextWrapped=true;status.AutomaticSize=Enum.AutomaticSize.Y;status.LayoutOrder=2
    if record then
        record.OnStatus=function(text) status.Text=text end
        record.OnEnabled=function(on) set(on,false) end
    end
    note(s,"Ginzo → Accept quest → Jewelry Box1 → Hold T → Return to Ginzo")
    note(section("Unlock Market",2,"Quest details"),"Ill find the jewelry box(Lv 45)\nGinzo: 273.80, 944.00, 528.19\nBox: 1874.20, 687.75, -729.42\nOne run per activation. Check the game's unlock confirmation after turn-in.")
end


-- Shared live settings: both farming pages edit the same movement configuration.
do
    local farm=self:Farm()
    local linked={}
    local function sync()
        for _,controls in ipairs(linked) do
            controls.mode.Set(farm.AttackPosition,false)
            controls.gap.Set(farm.HeadHeight,false)
            controls.distance.Set(farm.BehindDistance,false)
            controls.height.Set(farm.BehindHeight,false)
        end
    end
    for _,pageName in ipairs({"Mob Farm","Boss Farm"}) do
        local s=section(pageName,2,"Attack position")
        s.Frame.LayoutOrder=-2000
        local prefix="attackPose."..pageName.."."
        dropdown(s,prefix.."mode","Position",{"Above head","Below feet","Behind","Above and behind"},false,farm.AttackPosition)
        slider(s,prefix.."gap","Above / below gap",.5,20,farm.HeadHeight," studs")
        slider(s,prefix.."distance","Behind distance",1,30,farm.BehindDistance," studs")
        slider(s,prefix.."height","Behind height",-10,20,farm.BehindHeight," studs")
        table.insert(linked,{mode=self.Controls[prefix.."mode"],gap=self.Controls[prefix.."gap"],distance=self.Controls[prefix.."distance"],height=self.Controls[prefix.."height"]})
        self:On(prefix.."mode",function(v) farm:SetAttackPosition(v);sync() end)
        self:On(prefix.."gap",function(v) farm:SetAttackPosition(nil,v);sync() end)
        self:On(prefix.."distance",function(v) farm:SetAttackPosition(nil,nil,v);sync() end)
        self:On(prefix.."height",function(v) farm:SetAttackPosition(nil,nil,nil,v);sync() end)
        note(s,"Shared by mob and boss farming. Changes apply immediately. Large offsets may put attacks out of range.")
    end
end

local boxESP=section("Visuals",2,"Monster hitbox ESP")
local visuals=self:Visuals()
self:On("visuals.monsterHitboxBox",function(on) visuals:SetMonsterHitboxESP(on) end)
toggle(boxESP,"visuals.monsterHitboxBox","Yellow hitbox outline",visuals.MonsterHitboxESP)
note(boxESP,"Yellow outline follows each monster HumanoidRootPart.")
local god=section("Player",2,"God Mode")
local playerModule=self:Player()
self:On("player.godMode",function(on) playerModule:SetGodMode(on) end)
toggle(god,"player.godMode","God Mode (local)",playerModule.GodModeEnabled)
note(god,"Local healing and ForceField; server damage rules may override it.")
-- The supplied backend has no webhook implementation. Keep the original tab honest.

local menu=section("Config",1,"MazaSpace")
note(menu,"Default key: RightShift (change in Settings)\nDrag the M circle to move it")
action(menu,"menu.unload","Unload",function() self.Ctx:Shutdown() end)
-- Place the familiar primary cards first while retaining every real control below them.
local order={["Monster hitbox ESP"]=-2,["God Mode"]=-2,Combat=0,Character=0,Players=0,Mobs=0,['Mob Farm']=0,['Auto Dungeon']=0}
for _,s in ipairs(self.Sections) do
    if not s.Reference and order[s.Title] then s.Frame.LayoutOrder=order[s.Title] end
end
self:SelectPage("Main")
self:Filter()
self.Ctx:RegisterJob("UIStatus",0.5,function() if self.Gui and self.Gui.Parent then self:RefreshStatus() end end)
self:RefreshStatus()
end
return UI

]====]

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
    local bundled = BUNDLED_SOURCES[name]
    if not bundled then return nil, "Missing bundled module: " .. tostring(name) end
    local chunk, err = compile(name, bundled)
    if not chunk then return nil, err end
    local ok, value = xpcall(chunk, traceback)
    if not ok then return nil, value end
    return value
end

-- Original HTTP implementation retained only as unused reference.
local function unusedRemoteLoader(base, name, retries, retryDelay)
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





