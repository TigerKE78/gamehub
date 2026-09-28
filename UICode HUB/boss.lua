-- MazxhubModules/boss.lua
-- Boss selection ใช้ Farm engine เดิม ไม่สร้าง Heartbeat เพิ่ม

local Boss = {
    Enabled = false,
    Selected = {},
    Order = {},
    Index = 1,
    StatusStates = {},
    StatusIndex = 1,

    Names = {
        "Zuko", "Gyorei", "Stone Trainee", "Thunder Trainee",
        "Water Trainee Sabito", "Giyen", "Yahari", "Reaper",
        "Saneri", "Shinora", "Enru", "Gyutai", "Datai",
        "Obari", "Mother Bear", "Kaiden", "Akazo",
        "Serpent Trainee", "Hoyuzo", "Zentaro", "Wind Trainee",
        "Tengai", "Sound Trainee", "Sumari", "Flame Trainee",
        "Nezura", "Fujiko", "Insect Trainee",
        "Soryu Trainee Goki", "Yeti Demon", "Rengu",
    },
}

function Boss:Init(ctx)
    self.Ctx = ctx
end

function Boss:MarkDead(state, model)
    if state.Model ~= model or state.DeadAt then
        return
    end

    state.DeadAt = os.clock()
    state.Alive = false
end

function Boss:UpdateStatus(name)
    local farm = self.Ctx.Modules.Farm

    local state = self.StatusStates[name]

    if not state then
        state = {}
        self.StatusStates[name] = state
    end

    local folder =
        farm.farmBossFolder
        and farm.farmBossFolder(name)
        or nil

    state.FolderLoaded = folder ~= nil

    local model =
        farm.farmBossModel
        and farm.farmBossModel(name, true)
        or nil

    local hum =
        model
        and model:FindFirstChildWhichIsA(
            "Humanoid",
            true
        )

    local alive =
        model ~= nil
        and (not hum or hum.Health > 0)

    if alive then
        if not state.Alive then
            if state.DeadAt then
                state.RespawnSeconds =
                    os.clock() - state.DeadAt

                state.Samples =
                    (state.Samples or 0) + 1
            end

            state.LastSeenTime =
                os.date("%H:%M:%S")

            state.DeadAt = nil
        end

        state.Alive = true

        if state.Model ~= model
            or state.Humanoid ~= hum then

            if state.DeathConnection then
                state.DeathConnection:Disconnect()
            end

            state.Model = model
            state.Humanoid = hum

            state.DeathConnection =
                hum
                and hum.HealthChanged:Connect(
                    function(health)
                        if health <= 0 then
                            self:MarkDead(
                                state,
                                model
                            )
                        end
                    end
                )
                or nil
        end
    else
        if state.Alive
            and model == state.Model
            and hum
            and hum.Health <= 0 then

            self:MarkDead(state, model)
        end

        state.Alive = false
    end

    state.DeadVisible =
        model ~= nil
        and hum ~= nil
        and hum.Health <= 0

    return state
end

function Boss:Duration(seconds)
    seconds =
        math.max(
            0,
            math.ceil(
                tonumber(seconds) or 0
            )
        )

    return string.format(
        "%02d:%02d",
        math.floor(seconds / 60),
        seconds % 60
    )
end

function Boss:DescribeStatus(state)
    if not state then
        return "กำลังตรวจสอบ...", "ยังไม่มีข้อมูล", "Gold"
    end

    local detail =
        state.LastSeenTime
        and (
            "พบล่าสุด "
            .. state.LastSeenTime
        )
        or "ยังไม่พบในเซสชันนี้"

    if state.RespawnSeconds then
        detail =
            detail
            .. " | รอบที่วัดได้ ~"
            .. self:Duration(
                state.RespawnSeconds
            )
    end

    if state.Alive then
        return "เกิดแล้ว • พร้อมฟาร์ม", detail, "Mint"
    end

    if not state.FolderLoaded then
        return "ยังไม่พบข้อมูลโซน", detail, "Sub"
    end

    if state.DeadAt
        and state.RespawnSeconds then

        local remaining =
            state.DeadAt
            + state.RespawnSeconds
            - os.clock()

        if remaining > 0 then
            return
                "คาดว่าจะเกิดใน ~"
                    .. self:Duration(remaining),
                detail,
                "Gold"
        end

        return
            "ถึงเวลาประมาณแล้ว • รอตรวจพบบอส",
            detail,
            "Gold"
    end

    if state.DeadAt
        or state.DeadVisible then

        return
            "ตายแล้ว • ยังไม่ทราบเวลาเกิด",
            detail,
            "Sub"
    end

    return
        "ยังไม่พบ • ยังไม่ทราบเวลาเกิด",
        detail,
        "Sub"
end

function Boss:StatusStep()
    if #self.Names == 0 then return end

    self.StatusIndex =
        math.clamp(
            self.StatusIndex or 1,
            1,
            #self.Names
        )

    local name =
        self.Names[self.StatusIndex]

    self:UpdateStatus(name)

    self.StatusIndex =
        self.StatusIndex % #self.Names + 1
end

function Boss:Start()
    self.Ctx:RegisterJob(
        "BossStatus",
        0.05,
        function()
            self:StatusStep()
        end
    )
end

function Boss:StopStatus()
    for _, state in pairs(self.StatusStates) do
        if state.DeathConnection then
            state.DeathConnection:Disconnect()
            state.DeathConnection = nil
        end
    end
end

function Boss:SetSelected(name, enabled)
    if not name then return end

    if enabled then
        if not self.Selected[name] then
            self.Selected[name] = true
            table.insert(self.Order, name)
        end
    else
        self.Selected[name] = nil
        for index = #self.Order, 1, -1 do
            if self.Order[index] == name then
                table.remove(self.Order, index)
            end
        end
        if self.Index > #self.Order then self.Index = 1 end
    end

    local farm = self.Ctx
        and self.Ctx.Modules
        and self.Ctx.Modules.Farm

    if self.Enabled and farm then
        farm._target = nil
        farm._attackTarget = nil
        farm._nextScanAt = 0
        self.Ctx.State.Target = nil

        if #self.Order == 0 then
            self:Stop()
            return
        end

        self.Index = math.clamp(self.Index, 1, #self.Order)
        farm:SetBoss(self.Order[self.Index])
    end
end

function Boss:ClearSelection()
    self.Selected = {}
    self.Order = {}
    self.Index = 1

    if self.Enabled then
        self:Stop()
    end
end

function Boss:StartSelected()
    if #self.Order == 0 then
        return false, "เลือกบอสอย่างน้อย 1 ตัว"
    end

    self.Enabled = true
    self.Index = math.clamp(self.Index, 1, #self.Order)
    self.Ctx.Modules.Farm:StartBoss(self.Order[self.Index])
    return true
end

function Boss:Stop()
    self.Enabled = false

    local farm = self.Ctx
        and self.Ctx.Modules
        and self.Ctx.Modules.Farm

    if farm and (
        farm.Mode == "Boss"
        or self.Ctx.State.FarmMode == "Boss"
    ) then
        farm:Stop()
    end

    if self.Ctx
        and self.Ctx.State
        and self.Ctx.State.Running == false then
        self:StopStatus()
    end
end

function Boss:ResolveSelectedTarget()
    local farm = self.Ctx.Modules.Farm
    local count = #self.Order
    if count == 0 or not farm then return nil, nil end

    for offset = 0, count - 1 do
        local index = ((self.Index - 1 + offset) % count) + 1
        local name = self.Order[index]
        local target = farm.TargetResolver("Boss", name)

        if target and self.Ctx:IsAlive(target) then
            self.Index = index
            return name, target
        end
    end

    return self.Order[self.Index], nil
end

return Boss
