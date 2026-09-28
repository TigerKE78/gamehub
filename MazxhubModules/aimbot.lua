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
