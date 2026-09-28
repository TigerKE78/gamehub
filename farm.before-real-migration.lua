-- MazxhubModules/farm.lua
-- Farm engine ตัวเดียว ใช้ได้ทั้ง Mob และ Boss

local Farm = {
    Enabled = false,
    Mode = nil,
    Name = nil,
    Target = nil,
    TargetResolver = nil,
    TargetMover = nil,
}

function Farm:Init(ctx)
    self.Ctx = ctx

    -- ใส่ resolver ของเกมจริงภายหลัง:
    -- function(mode, name) -> Model | nil
    self.TargetResolver = function()
        return nil
    end

    -- ค่าเริ่มต้น: วาปไปเหนือหัวเป้าหมาย
    self.TargetMover = function(target)
        local _, humanoid, root = ctx:GetCharacter()
        if not humanoid or humanoid.Health <= 0 or not root then return false end

        local targetRoot = target and target:FindFirstChild("HumanoidRootPart", true)
        if not targetRoot or not targetRoot:IsA("BasePart") then return false end

        local height = tonumber(ctx.Config.Farm.HeightAboveHead) or 3
        root.CFrame = targetRoot.CFrame * CFrame.new(0, height, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        return true
    end
end

function Farm:SetResolver(callback)
    if type(callback) == "function" then
        self.TargetResolver = callback
    end
end

function Farm:SetMover(callback)
    if type(callback) == "function" then
        self.TargetMover = callback
    end
end

function Farm:StartMob(name)
    self.Enabled = true
    self.Mode = "Mob"
    self.Name = name
    self.Target = nil

    self.Ctx.State.FarmEnabled = true
    self.Ctx.State.FarmMode = "Mob"
    self.Ctx.State.TargetName = name
end

function Farm:StartBoss(name)
    self.Enabled = true
    self.Mode = "Boss"
    self.Name = name
    self.Target = nil

    self.Ctx.State.FarmEnabled = true
    self.Ctx.State.FarmMode = "Boss"
    self.Ctx.State.TargetName = name
end

function Farm:Stop()
    self.Enabled = false
    self.Mode = nil
    self.Name = nil
    self.Target = nil

    if self.Ctx then
        self.Ctx.State.FarmEnabled = false
        self.Ctx.State.FarmMode = nil
        self.Ctx.State.Target = nil
        self.Ctx.State.TargetName = nil
    end
end

function Farm:ResolveTarget()
    if self.Mode == "Boss" then
        local boss = self.Ctx.Modules.Boss
        if boss and boss.Enabled then
            local name, target = boss:ResolveSelectedTarget()
            if name then
                self.Name = name
                self.Ctx.State.TargetName = name
            end
            if target then return target end
        end
    end

    return self.TargetResolver(self.Mode, self.Name)
end

function Farm:Step()
    if not self.Enabled then return end

    if not self.Ctx:IsAlive(self.Target) then
        self.Target = self:ResolveTarget()
    end

    self.Ctx.State.Target = self.Target

    if self.Target and self.Ctx:IsAlive(self.Target) then
        self.TargetMover(self.Target)
    else
        self.Target = nil
        self.Ctx.State.Target = nil
    end
end

function Farm:Start()
    self.Ctx:RegisterJob(
        "Farm",
        self.Ctx.Config.Intervals.Farm,
        function() self:Step() end
    )
end

return Farm
