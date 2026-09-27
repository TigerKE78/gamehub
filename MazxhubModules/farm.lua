-- MazxhubModules/farm.lua
-- Farm จริงที่ย้ายจาก hello.txt
-- รักษาชื่อ helper เดิมไว้ให้มากที่สุด แต่ใช้ Core scheduler แทน Heartbeat แยก

local Farm = {
    Enabled = false,
    Mode = nil,
    MobName = nil,
    BossEnabled = false,
    BossName = "Zuko",

    Hitbox = 18,
    HeadHeight = 3,
    AttackRange = 12,

    AutoAttack = true,
    AutoQuest = false,
    AutoLoot = false,
    PlayerAttackHitbox = 30,
    PlayerHitboxTest = false,
    QuestKills = 0,

    AttackInterval = 0.06,
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

local function farmMoveUnder(mob)
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

    local changedTarget =
        FarmCharacterState.HoverTarget ~= mob
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

    local range = math.max(
        1.5,
        tonumber(Farm.AttackRange) or 12
    )

    local height = math.clamp(
        tonumber(Farm.HeadHeight) or 3,
        1,
        math.max(1.1, range - 0.5)
    )

    local desiredPosition =
        targetPosition + Vector3.new(0, height, 0)

    local desired = CFrame.lookAt(
        desiredPosition,
        desiredPosition - Vector3.yAxis,
        facing
    )

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

local function farmSet(on, storyInternal)
    on = on == true

    callStopper("StopDungeonCombat")

    if not storyInternal then
        callStopper("StopDungeon")
        callStopper("StopMultiBoss")
        callStopper("StopRaidChest")
        callStopper("StopPages")
        callStopper("StopDelivery")
        callStopper("StopStory")
        callStopper("StopBear")
    end

    farmStop()

    Farm.Enabled = on

    if not Farm.Ctx then
        return
    end

    Farm.Mode =
        on and (Farm.BossEnabled and "Boss" or "Mob") or nil
    Farm.Ctx.State.FarmEnabled = on
    Farm.Ctx.State.FarmMode = Farm.Mode
    Farm.Ctx.State.TargetName =
        on and (Farm.BossEnabled and Farm.BossName or Farm.MobName) or nil

    if on then
        farmKeepCharacterVisible()
        farmStart()
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

function Farm:SetExternalMode(name, resolver, mover)
    self.ExternalMode = name
    self.ExternalResolver = resolver
    self.ExternalMover = mover
    self.BossEnabled = false
    self.Mode = name

    self._target = nil
    self._attackTarget = nil
    self._nextScanAt = 0

    self.Enabled = true
    self.Ctx.State.FarmEnabled = true
    self.Ctx.State.FarmMode = name
    self.Ctx.State.Target = nil
    self.Ctx:SetJobEnabled("Farm", true)
end

function Farm:StartMob(name)
    self:ClearExternalMode()

    local boss = self.Ctx and self.Ctx.Modules and self.Ctx.Modules.Boss
    if boss then boss.Enabled = false end

    self.BossEnabled = false
    self.Mode = "Mob"
    self.MobName = name
    self._target = nil
    self._attackTarget = nil
    farmSet(true)
end

function Farm:StartBoss(name)
    self:ClearExternalMode()
    self.BossEnabled = true
    self.Mode = "Boss"
    self.BossName = name or self.BossName
    self._target = nil
    self._attackTarget = nil
    farmSet(true, true)
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
end

return Farm
