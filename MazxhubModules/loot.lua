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

function Loot:NearestPrompt(root)
    if not root or not self.Origin then
        return nil
    end

    local best
    local bestPosition
    local bestDistance

    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt")
            and prompt.Enabled
            and not self.Collected[prompt]
            and not self:PromptIsNPC(prompt) then

            local position =
                self:PromptPosition(prompt)

            if position
                and (
                    position - self.Origin
                ).Magnitude <= 90 then

                local distance =
                    (
                        position - root.Position
                    ).Magnitude

                if not bestDistance
                    or distance < bestDistance then
                    best = prompt
                    bestPosition = position
                    bestDistance = distance
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
    self.CollectUntil = os.clock() + 30
    self.LastFoundAt = os.clock()
    self.Collected =
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
            self.Collected[prompt] = true
            self.LastFoundAt = now
        end

        return
    end

    local prompt, position =
        self:NearestPrompt(root)

    if prompt and position then
        teleport(self):Go(
            CFrame.new(
                position
                + Vector3.new(0, 2.5, 0)
            )
        )

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
