-- MazxhubModules/boss.lua
-- Boss selection ใช้ Farm engine เดิม ไม่สร้าง Heartbeat เพิ่ม

local Boss = {
    Enabled = false,
    Selected = {},
    Order = {},
    Index = 1,

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
