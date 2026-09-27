-- MazxhubModules/skill.lua
-- AutoSkills ที่ย้ายออกจาก hello.txt
-- ใช้ Core scheduler กลาง ไม่มี Heartbeat แยก

local Skill = {
    Enabled = false,
    Focused = true,
    Keys = { "Z", "X", "C", "V", "B", "N", "K" },
    Settings = {},
    Cursor = 0,
    Held = nil,
    Running = true,
    Connections = {},
}

local function farm(self)
    return self.Ctx
        and self.Ctx.Modules
        and self.Ctx.Modules.Farm
end

local function combat(self)
    return self.Ctx
        and self.Ctx.Modules
        and self.Ctx.Modules.Combat
end

function Skill:Release()
    local held = self.Held
    local f = farm(self)

    if not held then
        if f then f._skillHeld = false end
        return
    end

    self.Held = nil

    if f then
        f._skillHeld = false
        f._skillPoseUntil =
            math.max(
                f._skillPoseUntil or 0,
                os.clock() + 0.85
            )
        f._skillReadyAt = os.clock() + 0.1
    end

    local c = combat(self)
    if c then
        c.BasicTurnPending = true
        c.BasicTurnUntil = os.clock() + 0.5
    end

    pcall(function()
        held.Input:SendKeyEvent(
            false,
            held.Key,
            false,
            game
        )
    end)
end

function Skill:CanUse()
    if not self.Running or not self.Enabled then
        return false
    end

    local c = combat(self)
    if not c then return false end

    return c:CombatReady()
end

function Skill:Step()
    if not self:CanUse() then
        self:Release()
        return
    end

    local f = farm(self)
    local c = combat(self)

    if self.Held then
        local target =
            self.Held.Target
            or f._attackTarget
            or self.Ctx.State.Target

        if target
            and target.Parent
            and f.farmMoveUnder then

            f.farmMoveUnder(target)
        end

        return
    end

    local now = os.clock()

    if now < (f._skillReadyAt or 0) then
        return
    end

    if c.BasicTurnPending then
        if now < c.BasicTurnUntil then
            return
        end
        c.BasicTurnPending = false
    end

    local _, equipped = c:EquipSelectedWeapon()
    if not equipped then
        return
    end

    for offset = 1, #self.Keys do
        local index =
            (self.Cursor + offset - 1)
            % #self.Keys
            + 1

        local key = self.Keys[index]
        local setting = self.Settings[key]

        if setting
            and setting.Enabled
            and now >= (setting.NextAt or 0) then

            c:ReleaseAttack()

            self.Cursor = index
            setting.NextAt =
                now + math.max(
                    tonumber(setting.Interval) or 1,
                    0.1
                )

            local ok = pcall(function()
                local input =
                    self.Ctx.Services.VirtualInputManager

                local target =
                    f._attackTarget
                    or self.Ctx.State.Target

                local held = {
                    Input = input,
                    Key = Enum.KeyCode[key],
                    Name = key,
                    Target = target,
                }

                self.Held = held
                f._skillHeld = true
                f._skillPoseUntil =
                    os.clock() + 1.0

                if target
                    and target.Parent
                    and f.farmMoveUnder then

                    f.farmMoveUnder(target)
                end

                input:SendKeyEvent(
                    true,
                    held.Key,
                    false,
                    game
                )

                task.delay(0.06, function()
                    if self.Held ~= held then
                        return
                    end

                    if held.Target
                        and held.Target.Parent
                        and f.farmMoveUnder then

                        f.farmMoveUnder(held.Target)
                    end

                    self:Release()

                    if held.Target
                        and held.Target.Parent
                        and f.Enabled
                        and f.farmMoveUnder then

                        f.farmMoveUnder(held.Target)
                    end
                end)
            end)

            if not ok then
                self:Release()

                for _, entry in pairs(self.Settings) do
                    entry.NextAt = now + 2
                end

                if self.OnError then
                    pcall(self.OnError)
                end
            end

            return
        end
    end
end

function Skill:SetEnabled(on)
    self.Enabled = on == true
    self:Release()

    for _, setting in pairs(self.Settings) do
        setting.NextAt = 0
    end
end

function Skill:SetKeyEnabled(key, enabled)
    local setting = self.Settings[key]
    if not setting then return end

    setting.Enabled = enabled == true
    setting.NextAt = 0

    if not setting.Enabled
        and self.Held
        and self.Held.Name == key then

        self:Release()
    end
end

function Skill:SetInterval(key, seconds)
    local setting = self.Settings[key]
    if not setting then return end

    setting.Interval =
        math.max(tonumber(seconds) or 1, 0.1)

    setting.NextAt = 0
end

function Skill:Init(ctx)
    self.Ctx = ctx
    self.Running = true
    self.Settings = {}
    self.Cursor = 0

    local configured =
        type(ctx.Config.Skill) == "table"
        and ctx.Config.Skill
        or {}

    for _, key in ipairs(self.Keys) do
        local data =
            type(configured[key]) == "table"
            and configured[key]
            or {}

        self.Settings[key] = {
            Enabled = data.Enabled == true,
            Interval =
                math.max(
                    tonumber(data.Interval) or 1,
                    0.1
                ),
            NextAt = 0,
        }
    end

    local input = ctx.Services.UserInputService

    table.insert(
        self.Connections,
        input.WindowFocusReleased:Connect(function()
            -- เหมือน hello.txt รุ่นล่าสุด:
            -- ไม่ยกเลิก skill เมื่อ Roblox เสีย focus
            self.Focused = false
        end)
    )

    table.insert(
        self.Connections,
        input.WindowFocused:Connect(function()
            self.Focused = true
        end)
    )
end

function Skill:Start()
    local intervals =
        type(self.Ctx.Config.Intervals) == "table"
        and self.Ctx.Config.Intervals
        or {}

    self.Ctx:RegisterJob(
        "Skill",
        tonumber(intervals.Skill) or 0.05,
        function()
            self:Step()
        end
    )
end

function Skill:Stop()
    self.Running = false
    self.Enabled = false
    self:Release()

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    self.Connections = {}
    self.OnError = nil
end

return Skill
