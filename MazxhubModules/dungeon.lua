-- MazxhubModules/dungeon.lua
local Dungeon = {
    Enabled = false,
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

function Dungeon:FindTarget()
    local folder = self:ActiveFolder()
    local char = self.Ctx.Player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not folder or not myRoot then return nil end
    local radius = math.max(1, tonumber(self.Radius) or 300)
    local best, bestDistance = nil, radius
    for _, hum in ipairs(folder:GetDescendants()) do
        if hum:IsA("Humanoid") and hum.Health > 0 then
            local model = hum.Parent
            while model and model ~= folder and not model:IsA("Model") do
                model = model.Parent
            end
            if self:ValidTarget(model) then
                local root = self:TargetRoot(model)
                local distance = root and (root.Position - myRoot.Position).Magnitude or math.huge
                if distance <= bestDistance then
                    best, bestDistance = model, distance
                end
            end
        end
    end
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
        self.Current = nil
        self.ApproachTarget = nil
        self.ApproachReadyAt = 0
        self.NextTargetAt = 0
        self.Prime = setmetatable({}, { __mode = "k" })
        if f.ExternalMode == "Dungeon" then
            f:Stop()
            f:ClearExternalMode()
        end
        return
    end

    if f.Enabled then f:Stop() end
    self.Enabled = true
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
    if not self.Enabled or not self.AutoSkip then return end
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
    if f.FastAttack then return end
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
end

return Dungeon
