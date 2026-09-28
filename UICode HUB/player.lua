-- MazxhubModules/player.lua
-- Player movement / environment / invisible utilities migrated from hello.txt

local Player = {
    SpeedEnabled = false,
    JumpEnabled = false,
    NoClipEnabled = false,
    FlyEnabled = false,
    InvisibleEnabled = false,

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

function Player:Step()
    self:MovementStep()
    self:NoClipStep()
    self:FlyStep()
    self:InvisibleStep()
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
