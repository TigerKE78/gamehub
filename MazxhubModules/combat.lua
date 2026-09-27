-- MazxhubModules/combat.lua
-- CombatRuntime ที่ย้ายออกจาก hello.txt
-- ใช้ Core scheduler กลาง และอ้าง Farm ผ่าน ctx.Modules.Farm

local Combat = {
    Enabled = true,
    Focused = true,
    Held = nil,
    EquipReadyAt = 0,
    EquipRetryAt = 0,
    NextAttackAt = 0,
    Character = nil,
    Humanoid = nil,
    Target = nil,
    LastHealth = nil,
    Driver = 1,
    PreferredDriver = nil,
    DriverHasDamage = false,
    AdaptiveInterval = 0.06,
    NoDamageAttempts = 0,
    State = "idle",
    Connections = {},
    HiddenTracks = setmetatable({}, { __mode = "k" }),
    BasicTurnPending = false,
    BasicTurnUntil = 0,
    PendingComboReset = false,
    PendingComboTarget = nil,
}

local SLOT_PREFIX = "ช่อง "

local function farm(self)
    return self.Ctx
        and self.Ctx.Modules
        and self.Ctx.Modules.Farm
end

local function inputBlocked(self)
    local input = self.Ctx.Services.UserInputService
    if input:GetFocusedTextBox() then
        return true
    end

    local ok, open = pcall(function()
        return game:GetService("GuiService").MenuIsOpen
    end)

    return ok and open == true
end

local function getSignal(self)
    local f = farm(self)
    if not f then return nil end

    if f._cachedSignal and f._cachedSignal.Parent then
        return f._cachedSignal
    end

    local now = os.clock()
    if now < (f._signalRetryAt or 0) then
        return nil
    end
    f._signalRetryAt = now + 0.5

    local rs = game:GetService("ReplicatedStorage")
    local ok, signal = pcall(function()
        return rs.Communication.ServerAndClient.Signals.SignalEvent.Event
    end)

    if not ok or not signal then
        local communication = rs:FindFirstChild("Communication", true)
        local signalEvent = communication
            and communication:FindFirstChild("SignalEvent", true)
        signal = signalEvent and signalEvent:FindFirstChild("Event")
    end

    if signal and signal:IsA("RemoteEvent") then
        f._cachedSignal = signal
        return signal
    end

    return nil
end

local function findTool(self)
    local player = self.Ctx.Player
    local character = player and player.Character
    local backpack = player and player:FindFirstChildOfClass("Backpack")

    local selected = farm(self).SelectedWeapon
    local selectedName =
        type(selected) == "string"
        and not selected:match("^" .. SLOT_PREFIX)
        and selected
        or nil

    for _, container in ipairs({ character, backpack }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool")
                    and (not selectedName or item.Name == selectedName) then
                    return item
                end
            end
        end
    end

    return nil
end

function Combat:SelectHotbarSlot(slot)
    local f = farm(self)
    local char = self.Ctx.Player and self.Ctx.Player.Character
    slot = math.floor(tonumber(slot) or 0)

    if not char or slot < 1 or slot > 5 then
        return false
    end

    local now = os.clock()
    if f._lastHotbarSelection == slot
        and f._lastHotbarCharacter == char then
        return now >= self.EquipReadyAt
    end

    if now < self.EquipRetryAt or f._skillHeld then
        return false
    end

    self:ReleaseAttack()

    local signal = getSignal(self)
    if not signal then
        self.EquipRetryAt = now + 1
        return false
    end

    local ok = pcall(function()
        signal:FireServer("Item_Equip", slot)
    end)

    if not ok then
        self.EquipRetryAt = now + 1
        return false
    end

    f._lastHotbarSelection = slot
    f._lastHotbarCharacter = char
    f._lastItemEquipAt = now
    self.EquipReadyAt = now + 0.2

    return false
end

function Combat:EquipSelectedWeapon()
    local f = farm(self)
    local char = self.Ctx.Player and self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not char or not hum or hum.Health <= 0 then
        return nil, false
    end

    local selectedSlot =
        type(f.SelectedWeapon) == "string"
        and tonumber(f.SelectedWeapon:match("^" .. SLOT_PREFIX .. "(%d+)"))
        or nil

    if selectedSlot then
        local ready = self:SelectHotbarSlot(selectedSlot)
        return char:FindFirstChildOfClass("Tool"), ready
    end

    local tool = findTool(self)
    if not tool then
        return nil, true
    end

    local now = os.clock()
    if tool.Parent ~= char then
        if now < self.EquipRetryAt or f._skillHeld then
            return nil, false
        end

        self:ReleaseAttack()
        self.EquipRetryAt = now + 0.5

        local ok = pcall(function()
            hum:EquipTool(tool)
        end)

        self.EquipReadyAt = now + (ok and 0.2 or 1)
        return tool, false
    end

    return tool, now >= self.EquipReadyAt
end

function Combat:TargetAlive(target)
    return self.Ctx:IsAlive(target)
end

function Combat:CombatReady()
    local f = farm(self)
    if not self.Enabled or not f or not f.Enabled or not f.AutoAttack then
        return false, "ฟาร์มยังไม่เปิด"
    end

    if f._questBusy or f._lootBusy then
        return false, "รอเควส / เก็บของ"
    end

    if inputBlocked(self) then
        return false, "รอปิดแชต / เมนูเกม"
    end

    if self.Guard and self.Guard.Holding then
        return false, "กำลังบล็อก"
    end

    local char = self.Ctx.Player and self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local target = f._attackTarget or self.Ctx.State.Target

    if not char or not hum or hum.Health <= 0 or not root then
        return false, "รอตัวละครพร้อม"
    end

    if not self:TargetAlive(target) then
        return false, "รอเป้าหมาย"
    end

    local point = f:AttackPoint(target)
    if not point then
        return false, "ไม่พบจุดโจมตี"
    end

    local range = tonumber(f.AttackRange) or 12
    if (point - root.Position).Magnitude > range then
        return false, "นอกระยะ"
    end

    return true
end

function Combat:ReleaseAttack()
    local held = self.Held
    if not held then return end

    self.Held = nil

    local f = farm(self)
    if f then f._sendingClick = false end

    pcall(function()
        if held.Tool then
            held.Tool:Deactivate()
        elseif held.Input then
            held.Input:SendMouseButtonEvent(
                held.X,
                held.Y,
                0,
                false,
                game,
                0
            )
        end
    end)
end

function Combat:RestoreSwingAnimations()
    for track, weight in pairs(self.HiddenTracks) do
        pcall(function()
            if track.IsPlaying then
                track:AdjustWeight(weight, 0.08)
            end
        end)
        self.HiddenTracks[track] = nil
    end
end

function Combat:IsBasicAttackTrack(track)
    if not track then return false end

    local animation = track.Animation
    local raw =
        tostring(track.Name or "")
        .. " "
        .. tostring(
            animation
            and animation.Name
            or ""
        )

    local name =
        raw:lower():gsub("[%s_%-]", "")

    for _, stem in ipairs({
        "m1",
        "attack",
        "basicattack",
        "lightattack",
        "slash",
        "swing",
        "punch",
        "melee",
    }) do
        if name:find(stem, 1, true) then
            return true
        end
    end

    return false
end

function Combat:HideSwingAnimation(track)
    local f = farm(self)

    if not f.NoSwingAnimation
        or f._skillHeld
        or not self:IsBasicAttackTrack(track) then
        return
    end

    pcall(function()
        if self.HiddenTracks[track] == nil then
            self.HiddenTracks[track] =
                track.WeightTarget
        end

        track:AdjustWeight(0, 0)
    end)
end

function Combat:RefreshHiddenTracks()
    local f = farm(self)

    if not f.NoSwingAnimation then
        if next(self.HiddenTracks) then
            self:RestoreSwingAnimations()
        end
        return
    end

    if f._skillHeld then return end

    local hum = self.Humanoid
    local animator =
        hum
        and hum:FindFirstChildOfClass("Animator")

    if not animator then return end

    for _, track in ipairs(
        animator:GetPlayingAnimationTracks()
    ) do
        if self:IsBasicAttackTrack(track) then
            self:HideSwingAnimation(track)
        end
    end

    for track in pairs(self.HiddenTracks) do
        pcall(function()
            if not track.IsPlaying then
                self.HiddenTracks[track] = nil
            elseif track.WeightTarget > 0 then
                track:AdjustWeight(0, 0)
            end
        end)
    end
end

function Combat:WatchAnimations()
    if self.AnimationConnection then
        self.AnimationConnection:Disconnect()
        self.AnimationConnection = nil
    end

    local hum = self.Humanoid
    local animator =
        hum
        and (
            hum:FindFirstChildOfClass("Animator")
            or hum:WaitForChild("Animator", 1)
        )

    if not animator then return end

    self.AnimationConnection =
        animator.AnimationPlayed:Connect(function(track)
            self:HideSwingAnimation(track)
        end)
end

function Combat:Release()
    self:ReleaseAttack()
    self:RestoreSwingAnimations()

    local skill = self.Ctx.Modules.Skill
    if skill and type(skill.Release) == "function" then
        pcall(function() skill:Release() end)
    end

    self.Guard:Release()
end

function Combat:ResetProgress()
    local f = farm(self)
    -- FastAttack ใช้ Signal เป็นหลัก เพื่อไม่แย่งเมาส์กับการคลิก UI/จุดอื่นในเกม.
    self.Driver = f.FastAttack and 3 or (self.PreferredDriver or 1)
    self.DriverHasDamage = false
    self.LastHealth = nil
    self.AdaptiveInterval =
        math.clamp(tonumber(f.AttackInterval) or 0.06, 0.01, 0.2)
    self.NoDamageAttempts = 0
    self.NextAttackAt = 0
end

function Combat:Dispatch(tool)
    local f = farm(self)

    if inputBlocked(self) or f._skillHeld then
        self:ReleaseAttack()
        return false
    end

    local driver = self.Focused == false and 3 or self.Driver

    -- ระหว่าง FastAttack ให้ลอง Combat_Service ก่อนเสมอ
    -- เพื่อให้ผู้เล่นคลิก UI/หน้าจอส่วนอื่นได้โดย Auto Attack ไม่หยุด.
    if f.FastAttack or driver == 3 then
        local signal = getSignal(self)

        if signal then
            local ok = pcall(function()
                signal:FireServer(
                    "Combat_Service",
                    "Combat",
                    1,
                    false,
                    0.13,
                    false,
                    nil
                )
            end)

            if ok then
                return true
            end
        end

        -- Signal ใช้ไม่ได้: fallback ไป Tool ก่อน แล้วค่อย Mouse.
        if tool and tool.Parent == self.Ctx.Player.Character then
            driver = 2
        else
            driver = 1
        end
    end

    if driver == 1 then
        local camera = workspace.CurrentCamera
        if not camera then return false end

        local input = self.Ctx.Services.VirtualInputManager
        local held = {
            Input = input,
            X = camera.ViewportSize.X * 0.5,
            Y = camera.ViewportSize.Y * 0.5,
        }

        self.Held = held
        f._sendingClick = true

        local ok = pcall(function()
            input:SendMouseButtonEvent(
                held.X,
                held.Y,
                0,
                true,
                game,
                0
            )
        end)

        if not ok then
            self:ReleaseAttack()
            return false
        end

        task.delay(f.FastAttack and 0.004 or 0.015, function()
            if self.Held == held then
                self:ReleaseAttack()
            end
        end)

        return true
    end

    if driver == 2 then
        if not tool
            or tool.Parent ~= self.Ctx.Player.Character then
            return false
        end

        local held = { Tool = tool }
        self.Held = held

        local ok = pcall(function()
            tool:Activate()
        end)

        task.delay(0.015, function()
            if self.Held == held then
                self:ReleaseAttack()
            end
        end)

        return ok
    end

    return false
end

Combat.Guard = {
    Holding = false,
    Until = 0,
    Input = nil,
}

function Combat.Guard:Begin(seconds)
    local owner = Combat
    if self.Holding then
        self.Until = math.max(self.Until, os.clock() + (seconds or 0.35))
        return
    end

    self.Input = owner.Ctx.Services.VirtualInputManager
    self.Holding = true
    self.Until = os.clock() + (seconds or 0.35)

    pcall(function()
        self.Input:SendKeyEvent(true, Enum.KeyCode.F, false, game)
    end)
end

function Combat.Guard:Release()
    if not self.Holding then return end

    self.Holding = false
    local input = self.Input
    self.Input = nil

    if input then
        pcall(function()
            input:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
    end
end

function Combat.Guard:Step()
    if self.Holding and os.clock() >= self.Until then
        self:Release()
    end
end

function Combat:UnbindGameComboGate()
    if self.ComboGateConnection then
        self.ComboGateConnection:Disconnect()
        self.ComboGateConnection = nil
    end

    self.ComboGateValue = nil
    self.PendingComboReset = false
    self.PendingComboTarget = nil
end

function Combat:BindGameComboGate()
    self:UnbindGameComboGate()

    local f = farm(self)
    if not f.FastAttack or not f.BypassComboGate then
        return
    end

    local scripts = self.Ctx.Player:FindFirstChild("PlayerScripts")
    local cu = scripts and scripts:FindFirstChild("CU")
    local combat = cu and cu:FindFirstChild("Combat")
    local combo = combat and combat:FindFirstChild("ComboValue")

    if not combo
        or not (
            combo:IsA("IntValue")
            or combo:IsA("NumberValue")
        ) then
        return
    end

    self.ComboGateValue = combo
    self.ComboGateConnection =
        combo:GetPropertyChangedSignal("Value"):Connect(function()
            local currentFarm = farm(self)
            if not currentFarm
                or not currentFarm.FastAttack
                or not currentFarm.BypassComboGate then
                return
            end

            if combo.Parent and combo.Value >= 5 then
                self.Guard:Begin(0.35)
                self.PendingComboReset = true
                self.PendingComboTarget =
                    currentFarm._attackTarget
                    or self.Ctx.State.Target
            end
        end)
end

function Combat:ConfirmComboDamage(target)
    local f = farm(self)

    if not f.FastAttack
        or not f.BypassComboGate
        or not self.PendingComboReset then
        return
    end

    if self.PendingComboTarget
        and target ~= self.PendingComboTarget then
        return
    end

    local combo = self.ComboGateValue
    if combo and combo.Parent then
        pcall(function()
            if combo.Value >= 5 then
                combo.Value = 1
            end
        end)
    end

    self.PendingComboReset = false
    self.PendingComboTarget = nil
    self.NextAttackAt = 0
end

function Combat:WatchCharacterHealth()
    if self.HealthConnection then
        self.HealthConnection:Disconnect()
        self.HealthConnection = nil
    end

    local char = self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    self.PlayerHealth = hum.Health
    self.HealthConnection = hum.HealthChanged:Connect(function(health)
        if self.PlayerHealth and health < self.PlayerHealth then
            if self.Guard.Holding then
                self.Guard.Until = math.max(
                    self.Guard.Until,
                    os.clock() + 0.65
                )
            end
        end
        self.PlayerHealth = health
    end)
end

function Combat:Step()
    self.Guard:Step()

    if self.Guard.Holding then
        self.State = "blocking"
        self:ReleaseAttack()
        return
    end

    local ready = self:CombatReady()
    if not ready then
        self.State = "waiting"
        self:ReleaseAttack()
        return
    end

    local f = farm(self)
    local now = os.clock()

    if now < self.NextAttackAt then
        return
    end

    local char = self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local target = f._attackTarget or self.Ctx.State.Target

    if char ~= self.Character or hum ~= self.Humanoid then
        self.Character = char
        self.Humanoid = hum
        self:WatchCharacterHealth()
        self:WatchAnimations()
        self:BindGameComboGate()
        self:ResetProgress()
    end

    local tool, equipped = self:EquipSelectedWeapon()
    if not equipped then
        self.State = "equipping"
        return
    end

    local targetHum =
        target and target:FindFirstChildWhichIsA("Humanoid", true)

    local serverConfirmedHit = false

    if targetHum then
        if self.Target ~= target then
            self.Target = target
            self.LastHealth = targetHum.Health
            self.PendingComboReset = false
            self.PendingComboTarget = nil
        elseif self.LastHealth
            and targetHum.Health < self.LastHealth then

            serverConfirmedHit = true
            self.DriverHasDamage = true
            self.NoDamageAttempts = 0
            self:ConfirmComboDamage(target)

            if f.FastAttack
                and f.AdaptiveFastAttack then

                self.AdaptiveInterval =
                    math.max(
                        0.01,
                        (
                            self.AdaptiveInterval
                            or f.AttackInterval
                            or 0.06
                        ) - 0.001
                    )
            end
        end

        self.LastHealth = targetHum.Health
    end

    self:RefreshHiddenTracks()

    local dispatched = self:Dispatch(tool)

    if dispatched then
        self.State = "attacking"

        if f.FastAttack
            and f.AdaptiveFastAttack
            and not serverConfirmedHit then

            self.NoDamageAttempts += 1

            if self.NoDamageAttempts >= 6 then
                self.AdaptiveInterval =
                    math.min(
                        0.08,
                        (
                            self.AdaptiveInterval
                            or f.AttackInterval
                            or 0.06
                        ) + 0.002
                    )

                self.NoDamageAttempts = 0
            end
        end
    else
        self.State = "retry"
        self.NoDamageAttempts += 1

        if not f.FastAttack
            and self.NoDamageAttempts >= 4 then

            self.Driver = self.Driver % 3 + 1
            self.NoDamageAttempts = 0
        end
    end

    local interval =
        f.FastAttack
        and f.AdaptiveFastAttack
        and self.AdaptiveInterval
        or tonumber(f.AttackInterval)
        or 0.06

    self.NextAttackAt =
        now + math.clamp(interval, 0.01, 0.2)
end

function Combat:Init(ctx)
    self.Ctx = ctx
    self:ResetProgress()

    local input = ctx.Services.UserInputService

    table.insert(
        self.Connections,
        input.WindowFocusReleased:Connect(function()
            self.Focused = false
            self:ReleaseAttack()
        end)
    )

    table.insert(
        self.Connections,
        input.WindowFocused:Connect(function()
            self.Focused = true
            self.NextAttackAt = 0
        end)
    )
end

function Combat:Start()
    local intervals =
        type(self.Ctx.Config.Intervals) == "table"
        and self.Ctx.Config.Intervals
        or {}

    self.Ctx:RegisterJob(
        "Combat",
        tonumber(intervals.Combat) or 0.03,
        function()
            self:Step()
        end
    )
end

function Combat:Stop()
    self.Enabled = false
    self:Release()
    self:UnbindGameComboGate()

    if self.HealthConnection then
        self.HealthConnection:Disconnect()
        self.HealthConnection = nil
    end

    if self.AnimationConnection then
        self.AnimationConnection:Disconnect()
        self.AnimationConnection = nil
    end

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self.Connections = {}
end

return Combat
