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

function Teleport:Go(cframe)
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

function Teleport:GoNPC(name)
    local destination = self:Destination(name)
    if not destination then
        return false, "ไม่พบพิกัด " .. tostring(name)
    end
    return self:Go(destination)
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
end

function Teleport:Stop()
end

return Teleport
