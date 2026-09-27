-- MazxhubModules/visual.lua
-- Player ESP / NPC ESP / Boss ESP / Aimbot migrated from hello.txt

local Visual = {
    Enabled = false,
    Lines = false,
    Outlines = false,
    MaxDistance = 1000,
    Bandit = false,
    Civilian = false,
    BossEnabled = false,
    BossSelected = {},

    ESP = {
        Enabled = false,
        Lines = false,
        Outlines = false,
        Color = Color3.fromRGB(139, 124, 246),
        OutlineColor = Color3.fromRGB(255, 255, 255),
        MaxDistance = 1000,
        Cache = {},
    },

    NPC = {
        Bandit = false,
        Civilian = false,
        BossEnabled = false,
        BossSelected = {},
        MaxDistance = 1000,
        Cache = {},
        Regions = { "Windy Peak", "Misc", "Bamboo Grove", "Temporary" },
        Colors = {
            Bandit = Color3.fromRGB(255, 90, 90),
            Civilian = Color3.fromRGB(110, 231, 183),
        },
    },

    Aimbot = {
        Enabled = false,
        SkillEnabled = false,
        ShowFOV = false,
        FOV = 180,
        TargetPlayers = true,
        TargetNPCs = true,
        AltCenter = false,
        RightMouseHeld = false,
        SkillHeld = {},
        SkillKeys = { Z=true, X=true, C=true, V=true, B=true, N=true, K=true },
        NPCs = {},
        NextNPCScan = 0,
        Target = nil,
    },

    Connections = {},
    NextScanAt = 0,
    NextRenderAt = 0,
}

local function gui(self)
    return self.Ctx
        and self.Ctx.Modules
        and self.Ctx.Modules.UI
        and self.Ctx.Modules.UI.Gui
end

local function bossNames(self)
    local boss = self.Ctx.Modules.Boss
    return boss and boss.Names or {}
end

local function clearPlayerData(self, plr)
    local data = self.ESP.Cache[plr]
    if not data then return end

    for _, item in pairs(data) do
        if typeof(item) == "Instance" then
            pcall(function() item:Destroy() end)
        end
    end

    self.ESP.Cache[plr] = nil
end

local function lineLayer(self)
    local current = gui(self)
    if not current then return nil end

    if self.LineLayer and self.LineLayer.Parent == current then
        return self.LineLayer
    end

    local layer = Instance.new("Frame")
    layer.Name = "MazxhubESPLines"
    layer.Size = UDim2.fromScale(1, 1)
    layer.BackgroundTransparency = 1
    layer.Active = false
    layer.ZIndex = 0
    layer.Parent = current

    self.LineLayer = layer
    return layer
end

local function makeLine(self, color)
    local layer = lineLayer(self)
    if not layer then return nil end

    local line = Instance.new("Frame")
    line.Name = "MazxhubESPLine"
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.BackgroundColor3 = color
    line.BorderSizePixel = 0
    line.Visible = false
    line.Active = false
    line.ZIndex = 0
    line.Parent = layer

    return line
end

local function updateLine(line, root, enabled, maxDistance, camera)
    if not line then return end
    line.Visible = false

    if not enabled or not camera or not root or not root.Parent then
        return
    end

    if (camera.CFrame.Position - root.Position).Magnitude > maxDistance then
        return
    end

    local point, onScreen = camera:WorldToViewportPoint(root.Position)
    if not onScreen or point.Z <= 0 then return end

    local origin = Vector2.new(
        camera.ViewportSize.X * 0.5,
        camera.ViewportSize.Y - 2
    )

    local target = Vector2.new(point.X, point.Y)
    local delta = target - origin
    if delta.Magnitude < 1 then return end

    local middle = (origin + target) * 0.5

    line.Position = UDim2.fromOffset(middle.X, middle.Y)
    line.Size = UDim2.fromOffset(delta.Magnitude, 2)
    line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    line.Visible = true
end

function Visual:RefreshPlayer(plr)
    if plr == self.Ctx.Player then return end

    clearPlayerData(self, plr)

    local esp = self.ESP
    if not esp.Enabled and not esp.Lines and not esp.Outlines then
        return
    end

    local char = plr.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return end

    local data = {
        Character = char,
    }

    local highlight = Instance.new("Highlight")
    highlight.Name = "MazxhubESP"
    highlight.Adornee = char
    highlight.FillColor = esp.Color
    highlight.FillTransparency = 0.75
    highlight.OutlineColor = esp.OutlineColor
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = esp.Outlines
    highlight.Parent = char
    data.Highlight = highlight

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MazxhubESPTag"
    billboard.Adornee = head
    billboard.Size = UDim2.fromOffset(200, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = esp.MaxDistance
    billboard.Enabled = esp.Enabled
    billboard.Parent = char
    data.Billboard = billboard

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Text = plr.Name
    nameLabel.TextColor3 = esp.Color
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new()
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard
    data.NameLabel = nameLabel

    local distLabel = Instance.new("TextLabel")
    distLabel.BackgroundTransparency = 1
    distLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distLabel.Text = "[0 studs]"
    distLabel.TextColor3 = Color3.fromRGB(220, 226, 233)
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new()
    distLabel.TextSize = 12
    distLabel.Font = Enum.Font.Gotham
    distLabel.Parent = billboard
    data.DistanceLabel = distLabel

    data.Line = makeLine(self, esp.Color)
    esp.Cache[plr] = data
end

function Visual:RefreshAllPlayers()
    for _, plr in ipairs(self.Ctx.Services.Players:GetPlayers()) do
        self:RefreshPlayer(plr)
    end
end

function Visual:NpcFolder(region)
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

function Visual:NpcType(root, folder)
    local node = root and root.Parent

    while node and node ~= folder do
        local lower = node.Name:lower()

        if lower == "bandit" then return "Bandit" end
        if lower == "civilian" then return "Civilian" end

        for _, bossName in ipairs(bossNames(self)) do
            if lower == bossName:lower() then
                return bossName
            end
        end

        node = node.Parent
    end

    return nil
end

function Visual:NpcEnabled(kind)
    if self.NPC.BossSelected[kind] ~= nil then
        return self.NPC.BossEnabled
            and self.NPC.BossSelected[kind]
    end

    return self.NPC[kind] == true
end

function Visual:ClearNpc(root)
    local data = self.NPC.Cache[root]
    if not data then return end

    for _, item in pairs(data) do
        if typeof(item) == "Instance" then
            pcall(function() item:Destroy() end)
        end
    end

    self.NPC.Cache[root] = nil
end

function Visual:MakeNpc(root, kind)
    if not root or not root.Parent or self.NPC.Cache[root] then
        return
    end

    local adornee =
        root.Parent:IsA("Model")
        and root.Parent
        or root

    local color =
        self.NPC.Colors[kind]
        or Color3.fromRGB(198, 179, 134)

    local highlight = Instance.new("Highlight")
    highlight.Name = "MazxhubNpcESP"
    highlight.Adornee = adornee
    highlight.FillColor = color
    highlight.FillTransparency = 0.72
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = adornee

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MazxhubNpcESPTag"
    billboard.Adornee = root
    billboard.Size = UDim2.fromOffset(180, 42)
    billboard.StudsOffset = Vector3.new(0, 3.2, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = self.NPC.MaxDistance
    billboard.Parent = root

    local textLabel = Instance.new("TextLabel")
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.fromScale(1, 1)
    textLabel.Text = kind
    textLabel.TextColor3 = color
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.new()
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Parent = billboard

    self.NPC.Cache[root] = {
        Type = kind,
        Highlight = highlight,
        Billboard = billboard,
        Label = textLabel,
        Line = makeLine(self, color),
    }
end

function Visual:RefreshNpc()
    if not self.NPC.Bandit
        and not self.NPC.Civilian
        and not self.NPC.BossEnabled then

        for root in pairs(self.NPC.Cache) do
            self:ClearNpc(root)
        end

        return
    end

    local seen = {}

    for _, region in ipairs(self.NPC.Regions) do
        local folder = self:NpcFolder(region)

        if folder then
            for _, item in ipairs(folder:GetDescendants()) do
                if item:IsA("BasePart")
                    and item.Name == "HumanoidRootPart" then

                    local kind = self:NpcType(item, folder)

                    if kind then
                        seen[item] = true

                        local hum =
                            item.Parent
                            and item.Parent:FindFirstChildWhichIsA(
                                "Humanoid",
                                true
                            )

                        if self:NpcEnabled(kind)
                            and (not hum or hum.Health > 0) then

                            if not self.NPC.Cache[item] then
                                self:MakeNpc(item, kind)
                            end
                        else
                            self:ClearNpc(item)
                        end
                    end
                end
            end
        end
    end

    for root, data in pairs(self.NPC.Cache) do
        if not root.Parent
            or not seen[root]
            or not self:NpcEnabled(data.Type) then
            self:ClearNpc(root)
        end
    end
end

function Visual:AimCenter(camera)
    if self.Aimbot.AltCenter then
        return Vector2.new(
            camera.ViewportSize.X * 0.5,
            camera.ViewportSize.Y * 0.5
        )
    end

    return self.Ctx.Services.UserInputService:GetMouseLocation()
end

function Visual:RefreshAimNPCs()
    local out = {}
    local root = workspace:FindFirstChild("Humanoids")

    if root then
        for _, hum in ipairs(root:GetDescendants()) do
            if hum:IsA("Humanoid") and hum.Health > 0 then
                local model = hum.Parent
                local my = self.Ctx.Player.Character

                local isSelf =
                    my
                    and model
                    and (
                        model == my
                        or model:IsDescendantOf(my)
                        or my:IsDescendantOf(model)
                    )

                local part =
                    not isSelf
                    and model
                    and (
                        model:FindFirstChild("Head")
                        or model:FindFirstChild("HumanoidRootPart")
                    )

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

    self.Aimbot.NPCs = out
    self.Aimbot.NextNPCScan = os.clock() + 0.5
end

function Visual:SkillAimActive()
    for key in pairs(self.Aimbot.SkillHeld) do
        if self.Aimbot.SkillKeys[key] then
            return true
        end
    end

    return false
end

function Visual:FindAimTarget(camera, center)
    local bestPart
    local bestDistance

    local function consider(part, hum)
        if not part
            or not part.Parent
            or (hum and hum.Health <= 0) then
            return
        end

        local my = self.Ctx.Player.Character

        if my and (
            part:IsDescendantOf(my)
            or (hum and hum:IsDescendantOf(my))
        ) then
            return
        end

        local point, visible =
            camera:WorldToViewportPoint(part.Position)

        if not visible or point.Z <= 0 then
            return
        end

        local distance =
            (Vector2.new(point.X, point.Y) - center).Magnitude

        if distance > self.Aimbot.FOV then
            return
        end

        if not bestDistance or distance < bestDistance then
            bestPart = part
            bestDistance = distance
        end
    end

    if self.Aimbot.TargetPlayers then
        for _, plr in ipairs(self.Ctx.Services.Players:GetPlayers()) do
            if plr ~= self.Ctx.Player then
                local char = plr.Character
                local hum =
                    char and char:FindFirstChildOfClass("Humanoid")
                local part =
                    char
                    and (
                        char:FindFirstChild("Head")
                        or char:FindFirstChild("HumanoidRootPart")
                    )

                consider(part, hum)
            end
        end
    end

    if self.Aimbot.TargetNPCs then
        if os.clock() >= self.Aimbot.NextNPCScan then
            self:RefreshAimNPCs()
        end

        for _, data in ipairs(self.Aimbot.NPCs) do
            consider(data.Part, data.Humanoid)
        end
    end

    return bestPart
end

function Visual:EnsureAimLayer()
    local current = gui(self)
    if not current then return end

    if self.AimLayer and self.AimLayer.Parent == current then
        return
    end

    local layer = Instance.new("Frame")
    layer.Name = "MazxhubAimLayer"
    layer.Size = UDim2.fromScale(1, 1)
    layer.BackgroundTransparency = 1
    layer.Active = false
    layer.ZIndex = 40
    layer.Parent = current
    self.AimLayer = layer

    local ring = Instance.new("Frame")
    ring.Name = "AimbotFOV"
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.BackgroundTransparency = 1
    ring.Visible = false
    ring.ZIndex = 80
    ring.Parent = layer
    Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)

    local outline = Instance.new("UIStroke")
    outline.Color = Color3.fromRGB(150, 220, 255)
    outline.Thickness = 2
    outline.Transparency = 0
    outline.Parent = ring

    self.FOVRing = ring
end

function Visual:RenderStep()
    local camera = workspace.CurrentCamera
    if not camera then return end

    local esp = self.ESP

    for plr, data in pairs(esp.Cache) do
        local char = plr.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local alive =
            root ~= nil
            and char == data.Character
            and (not hum or hum.Health > 0)

        local distance =
            alive
            and (camera.CFrame.Position - root.Position).Magnitude
            or math.huge

        local visible =
            alive
            and distance <= esp.MaxDistance

        if data.Billboard then
            data.Billboard.Enabled = visible and esp.Enabled
        end

        if data.Highlight then
            data.Highlight.Enabled = visible and esp.Outlines
        end

        if data.DistanceLabel and visible then
            data.DistanceLabel.Text =
                string.format("[%d studs]", math.floor(distance))
        end

        updateLine(
            data.Line,
            root,
            visible and esp.Lines,
            esp.MaxDistance,
            camera
        )
    end

    for root, data in pairs(self.NPC.Cache) do
        local visible = false

        if root.Parent then
            local hum =
                root.Parent:FindFirstChildWhichIsA("Humanoid", true)
            local distance =
                (camera.CFrame.Position - root.Position).Magnitude

            visible =
                self:NpcEnabled(data.Type)
                and distance <= self.NPC.MaxDistance
                and (not hum or hum.Health > 0)

            if data.Label then
                data.Label.Text = string.format(
                    "%s  [%d studs]",
                    data.Type,
                    math.floor(distance)
                )
            end
        end

        if data.Billboard then
            data.Billboard.Enabled = visible
        end

        if data.Highlight then
            data.Highlight.Enabled = visible
        end

        updateLine(
            data.Line,
            root,
            visible and self.ESP.Lines,
            self.NPC.MaxDistance,
            camera
        )
    end

    self:EnsureAimLayer()

    if self.FOVRing then
        self.FOVRing.Visible = self.Aimbot.ShowFOV

        if self.Aimbot.ShowFOV then
            local center = self:AimCenter(camera)
            local radius = math.max(10, self.Aimbot.FOV)

            self.FOVRing.Position =
                UDim2.fromOffset(center.X, center.Y)

            self.FOVRing.Size =
                UDim2.fromOffset(radius * 2, radius * 2)
        end
    end

    local shouldAim =
        self.Aimbot.RightMouseHeld
        and (
            self.Aimbot.Enabled
            or (
                self.Aimbot.SkillEnabled
                and self:SkillAimActive()
            )
        )

    if shouldAim then
        local center = self:AimCenter(camera)
        local target = self:FindAimTarget(camera, center)
        self.Aimbot.Target = target

        if target and target.Parent then
            camera.CFrame = CFrame.lookAt(
                camera.CFrame.Position,
                target.Position
            )
        end
    else
        self.Aimbot.Target = nil
    end
end

function Visual:SetPlayerESP(on)
    self.Enabled = on == true
    self.ESP.Enabled = self.Enabled
    self:RefreshAllPlayers()
end

function Visual:SetLines(on)
    self.Lines = on == true
    self.ESP.Lines = self.Lines
    if on then self:RefreshAllPlayers() end
end

function Visual:SetOutlines(on)
    self.Outlines = on == true
    self.ESP.Outlines = self.Outlines
    self:RefreshAllPlayers()
end

function Visual:SetNpc(kind, on)
    local enabled = on == true
    self.NPC[kind] = enabled
    self[kind] = enabled
    self:RefreshNpc()
end

function Visual:SetBandit(on)
    self:SetNpc("Bandit", on)
end

function Visual:SetCivilian(on)
    self:SetNpc("Civilian", on)
end

function Visual:SetBossESP(on)
    self.BossEnabled = on == true
    self.NPC.BossEnabled = self.BossEnabled
    self:RefreshNpc()
end

function Visual:SetBossEnabled(on)
    self:SetBossESP(on)
end

function Visual:SetBossSelected(name, on)
    local enabled = on == true
    self.NPC.BossSelected[name] = enabled
    self.BossSelected[name] = enabled
    self:RefreshNpc()
end

function Visual:SetMaxDistance(value)
    self.MaxDistance = tonumber(value) or self.MaxDistance
    self.ESP.MaxDistance = self.MaxDistance
    self.NPC.MaxDistance = self.MaxDistance
end

function Visual:Init(ctx)
    self.Ctx = ctx

    self.Enabled = self.ESP.Enabled
    self.Lines = self.ESP.Lines
    self.Outlines = self.ESP.Outlines
    self.MaxDistance = self.ESP.MaxDistance
    self.Bandit = self.NPC.Bandit
    self.Civilian = self.NPC.Civilian
    self.BossEnabled = self.NPC.BossEnabled

    for _, name in ipairs(bossNames(self)) do
        self.NPC.BossSelected[name] = true
        self.BossSelected[name] = true
        self.NPC.Colors[name] = Color3.fromRGB(198, 179, 134)
    end

    local aim = self.Aimbot
    aim._Owner = self

    function aim:SetEnabled(on)
        self.Enabled = on == true
    end

    function aim:SetShowFOV(on)
        self.ShowFOV = on == true
    end

    function aim:SetFOV(value)
        self.FOV = math.floor((tonumber(value) or self.FOV) + 0.5)
    end

    function aim:SetSkillEnabled(on)
        self.SkillEnabled = on == true
    end

    local input = ctx.Services.UserInputService

    table.insert(
        self.Connections,
        input.InputBegan:Connect(function(event, processed)
            if event.KeyCode == Enum.KeyCode.LeftAlt then
                self.Aimbot.AltCenter = true
            end

            if event.UserInputType == Enum.UserInputType.MouseButton2
                and not processed then
                self.Aimbot.RightMouseHeld = true
            end

            local name = event.KeyCode.Name

            if self.Aimbot.SkillKeys[name] and not processed then
                self.Aimbot.SkillHeld[name] = true
            end
        end)
    )

    table.insert(
        self.Connections,
        input.InputEnded:Connect(function(event)
            if event.KeyCode == Enum.KeyCode.LeftAlt then
                self.Aimbot.AltCenter = false
            end

            if event.UserInputType == Enum.UserInputType.MouseButton2 then
                self.Aimbot.RightMouseHeld = false
                self.Aimbot.Target = nil
            end

            self.Aimbot.SkillHeld[event.KeyCode.Name] = nil
        end)
    )

    table.insert(
        self.Connections,
        ctx.Services.Players.PlayerRemoving:Connect(function(plr)
            clearPlayerData(self, plr)
        end)
    )
end

function Visual:Start()
    self.Ctx:RegisterJob("VisualScan", 1.5, function()
        self:RefreshNpc()

        if self.ESP.Enabled
            or self.ESP.Lines
            or self.ESP.Outlines then

            for _, plr in ipairs(self.Ctx.Services.Players:GetPlayers()) do
                local data = self.ESP.Cache[plr]

                if plr ~= self.Ctx.Player
                    and (
                        not data
                        or data.Character ~= plr.Character
                    ) then
                    self:RefreshPlayer(plr)
                end
            end
        else
            for plr in pairs(self.ESP.Cache) do
                clearPlayerData(self, plr)
            end
        end
    end)

    self.Ctx:RegisterJob("VisualRender", 1 / 30, function()
        self:RenderStep()
    end)
end

function Visual:Stop()
    for plr in pairs(self.ESP.Cache) do
        clearPlayerData(self, plr)
    end

    for root in pairs(self.NPC.Cache) do
        self:ClearNpc(root)
    end

    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    self.Connections = {}

    if self.LineLayer then
        pcall(function() self.LineLayer:Destroy() end)
        self.LineLayer = nil
    end

    if self.AimLayer then
        pcall(function() self.AimLayer:Destroy() end)
        self.AimLayer = nil
    end
end

return Visual
