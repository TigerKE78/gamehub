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
                and record.Humanoid.Health > 0
                and record.Part
                and record.Part.Parent then

                local point, visible =
                    camera:WorldToViewportPoint(
                        record.Part.Position
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
                        best = record.Part
                    end
                end
            end
        end
    end

    return best
end

function Aimbot:UpdateFOV(camera)
    if not self.FOVCircle then return end

    local center = self:FOVCenter(camera)
    local diameter = self.FOV * 2

    self.FOVCircle.Visible = self.ShowFOV
    self.FOVCircle.Size =
        UDim2.fromOffset(diameter, diameter)

    self.FOVCircle.Position =
        UDim2.fromOffset(center.X, center.Y)

    if self.FOVCenterDot then
        self.FOVCenterDot.Visible = self.ShowFOV
        self.FOVCenterDot.Position =
            UDim2.fromOffset(center.X, center.Y)
    end
end

function Aimbot:Step()
    local camera = workspace.CurrentCamera
    if not camera then return end

    self:UpdateFOV(camera)

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
    self.FOVCircle.Parent = self.Gui

    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = self.FOVCircle

    local circleStroke = Instance.new("UIStroke")
    circleStroke.Color =
        Color3.fromRGB(150, 220, 255)
    circleStroke.Thickness = 2
    circleStroke.Transparency = 0
    circleStroke.Parent = self.FOVCircle

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
    self.FOVCenterDot.Parent = self.Gui

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = self.FOVCenterDot

    local input = ctx.Services.UserInputService

    table.insert(
        self.Connections,
        input.InputBegan:Connect(function(event, processed)
            if processed then return end

            if event.UserInputType ==
                Enum.UserInputType.MouseButton2 then
                self.RightMouseHeld = true
            end

            if event.KeyCode == Enum.KeyCode.LeftAlt
                or event.KeyCode == Enum.KeyCode.RightAlt then
                self.AltCenter = true
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
    self.Ctx:RegisterJob(
        "Aimbot",
        0.02,
        function()
            self:Step()
        end
    )
end

function Aimbot:Stop()
    self.Enabled = false
    self.SkillEnabled = false
    self.RightMouseHeld = false
    self.SkillHeld = {}
    self.Target = nil

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
end

return Aimbot
