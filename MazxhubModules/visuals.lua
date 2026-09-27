-- MazxhubModules/visuals.lua
-- Player/NPC/Boss ESP migrated from hello.txt

local Visuals = {
    Enabled = false,
    Lines = false,
    Outlines = false,
    Color = Color3.fromRGB(139, 124, 246),
    OutlineColor = Color3.fromRGB(255, 255, 255),
    MaxDistance = 1000,

    Bandit = false,
    Civilian = false,
    BossEnabled = false,
    BossSelected = {},

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

function Visuals:Render()
    local camera = workspace.CurrentCamera
    if not camera then return end

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
                visible and self.Enabled
            data.Billboard.MaxDistance =
                self.MaxDistance
        end

        if data.Highlight then
            data.Highlight.Enabled =
                visible and self.Outlines

            data.Highlight.FillColor = self.Color
            data.Highlight.OutlineColor =
                self.OutlineColor
        end

        if data.NameLabel then
            data.NameLabel.TextColor3 = self.Color
        end

        if data.DistanceLabel and visible then
            data.DistanceLabel.Text =
                string.format(
                    "[%d studs]",
                    math.floor(distance)
                )
        end

        if data.Line then
            data.Line.BackgroundColor3 = self.Color
            self:UpdateLine(
                data.Line,
                root,
                visible and self.Lines,
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
            data.Billboard.Enabled = visible
            data.Billboard.MaxDistance =
                self.MaxDistance
        end

        if data.Highlight then
            data.Highlight.Enabled = visible
        end

        self:UpdateLine(
            data.Line,
            root,
            visible and self.Lines,
            self.MaxDistance,
            camera
        )
    end
end

function Visuals:SetPlayerESP(on)
    self.Enabled = on == true
    self.NextScanAt = 0
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

function Visuals:Step()
    local now = os.clock()

    if now >= self.NextScanAt then
        self.NextScanAt = now + 1.0
        self:RefreshPlayers()
        self:RefreshNPCs()
    end

    self:Render()
end

function Visuals:Init(ctx)
    self.Ctx = ctx
    self.PlayerCache = {}
    self.NPCCache = {}
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
