-- MazxhubModules/raid.lua
local Raid = {
    Enabled = false,
    Phase = "idle",
    PointIndex = 1,
    SeenCount = 0,
    NextAt = 0,
    CheckUntil = 0,
    CollectUntil = 0,
    LastLootAt = 0,
    HeldPrompt = nil,
    PromptUntil = 0,
    Collected = setmetatable({}, { __mode = "k" }),
    LootRecords = setmetatable({}, { __mode = "k" }),
    StatusText = "Raid Chest • OFF",
    Status = "Raid Chest • OFF",
    OnStatus = nil,
}

local function farm(self)
    return self.Ctx.Modules.Farm
end

local function teleport(self)
    return self.Ctx.Modules.Teleport
end

function Raid:SetStatus(text)
    self.StatusText = text
    self.Status = text
    if self.Label and self.Label.Parent then self.Label.Text = text end
    if self.OnStatus then
        pcall(self.OnStatus, text)
    end
end

function Raid:Points()
    return farm(self).RaidBoxPoints or {}
end

function Raid:PointCount()
    return #self:Points()
end

function Raid:SetPoint(index)
    local points = self:Points()
    if #points == 0 then return false end
    self.PointIndex = math.clamp(math.floor(tonumber(index) or 1), 1, #points)
    self.Origin = points[self.PointIndex]
    self.MobKey = "Raid Box Point " .. tostring(self.PointIndex)
    return true
end

function Raid:PromptPosition(prompt)
    if not prompt or not prompt.Parent then return nil end
    local node = prompt.Parent
    while node and node ~= workspace do
        if node:IsA("Attachment") then return node.WorldPosition end
        if node:IsA("BasePart") then return node.Position end
        if node:IsA("Model") then return node:GetPivot().Position end
        node = node.Parent
    end
    return nil
end

function Raid:PromptIsNpc(prompt)
    local node = prompt and prompt.Parent
    while node and node ~= workspace do
        if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then return true end
        local name = node.Name:lower()
        if name == "activenpcs" or name == "stationarynpcs" then return true end
        node = node.Parent
    end
    return false
end

function Raid:NearestPrompt(root, collect)
    local best, bestPos, bestDistance
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled and not self.Collected[prompt]
            and not self:PromptIsNpc(prompt) then
            local record = self.LootRecords[prompt]
            if collect and record and os.clock() < (record.NextAt or 0) then
                continue
            end

            local pos = self:PromptPosition(prompt)
            if pos then
                local fromOrigin = self.Origin and (pos - self.Origin).Magnitude or math.huge
                local maxOrigin = collect and 90 or 20
                if fromOrigin <= maxOrigin then
                    local distance = root and (pos - root.Position).Magnitude or fromOrigin
                    if not bestDistance or distance < bestDistance then
                        best, bestPos, bestDistance = prompt, pos, distance
                    end
                end
            end
        end
    end
    return best, bestPos
end

function Raid:BeginPrompt(prompt, seconds)
    if not prompt or not prompt.Parent then return false end
    if self.HeldPrompt then pcall(function() self.HeldPrompt:InputHoldEnd() end) end
    self.HeldPrompt = prompt
    self.PromptUntil = os.clock() + math.max(tonumber(seconds) or prompt.HoldDuration or 0, 0.12)
    pcall(function() prompt:InputHoldBegin() end)
    return true
end

function Raid:FinishPrompt()
    local prompt = self.HeldPrompt
    self.HeldPrompt = nil
    self.PromptUntil = 0
    if prompt then pcall(function() prompt:InputHoldEnd() end) end
    return prompt
end

function Raid:Advance(delaySeconds)
    local f = farm(self)
    if f.Enabled then f:Stop() end
    self:FinishPrompt()
    self.SeenCount = 0
    self.Collected = setmetatable({}, { __mode = "k" })
    self.LootRecords = setmetatable({}, { __mode = "k" })
    local points = self:Points()
    if #points > 0 then self:SetPoint((self.PointIndex % #points) + 1) end
    self.Phase = "checkMove"
    self.NextAt = os.clock() + (delaySeconds or 0.15)
end

function Raid:SetEnabled(on)
    on = on == true
    if self.Enabled == on then return end
    local f = farm(self)

    if on then
        if f.Enabled then f:Stop() end
        if not self:SetPoint(1) then
            self:SetStatus("Raid Chest • ไม่มีพิกัด")
            return
        end
        self.Enabled = true
        self.Phase = "checkMove"
        self.NextAt = 0
        self.SeenCount = 0
        self.Collected = setmetatable({}, { __mode = "k" })
        self.LootRecords = setmetatable({}, { __mode = "k" })
        self:SetStatus("Raid Chest • ON")
    else
        self.Enabled = false
        self:FinishPrompt()
        if f.Enabled
            and (
                f.Mode == "RaidChest"
                or f.MobName == self.MobKey
            ) then
            f:Stop()
        end
        self.Phase = "idle"
        self:SetStatus("Raid Chest • OFF")
    end
end

function Raid:Step()
    if not self.Enabled then return end
    local now = os.clock()

    if self.HeldPrompt then
        if now < self.PromptUntil then return end
        local finished = self:FinishPrompt()

        if finished then
            self.LastLootAt = now

            if self.Phase == "collect" then
                local record =
                    self.LootRecords[finished]
                    or { Attempts = 0, NextAt = 0 }

                record.Attempts += 1
                record.NextAt = now + 0.45
                self.LootRecords[finished] = record

                if not finished.Parent
                    or not finished.Enabled
                    or record.Attempts >= 6 then
                    self.Collected[finished] = true
                end
            else
                self.Collected[finished] = true
            end
        end

        self.NextAt = now + 0.15
        return
    end

    if now < self.NextAt then return end

    local char = self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not root then
        self:SetStatus("Raid Chest • รอตัวละคร")
        return
    end

    local f = farm(self)
    local tp = teleport(self)

    if self.Phase == "checkMove" then
        tp:Go(CFrame.new(self.Origin + Vector3.new(0, 3, 0)))
        self.CheckUntil = now + 1.4
        self.Phase = "checkWait"
        self.NextAt = now + 0.35
        self:SetStatus("Raid Chest • จุด " .. tostring(self.PointIndex) .. " • ตรวจมอน")
        return
    end

    if self.Phase == "checkWait" then
        local alive = f.farmFindMobsByName and f.farmFindMobsByName(self.MobKey) or {}
        if #alive > 0 then
            self.SeenCount = #alive
            f:StartMob(self.MobKey)
            self.Phase = "fight"
            self.NextAt = now + 0.15
            return
        end
        if now >= self.CheckUntil then self:Advance(0.1) else self.NextAt = now + 0.2 end
        return
    end

    if self.Phase == "fight" then
        local alive = f.farmFindMobsByName and f.farmFindMobsByName(self.MobKey) or {}
        if #alive > 0 then
            self.SeenCount = math.max(self.SeenCount or 0, #alive)
            self.NextAt = now + 0.2
            self:SetStatus("Raid Chest • กำลังตี • เหลือ " .. tostring(#alive))
            return
        end
        f:Stop()
        if self.SeenCount > 0 then
            self.Phase = "chest"
            self.NextAt = now + 0.15
        else
            self:Advance(0.1)
        end
        return
    end

    if self.Phase == "chest" then
        tp:Go(CFrame.new(self.Origin + Vector3.new(0, 2.5, 0)))
        local prompt = self:NearestPrompt(root, false)
        if prompt then
            self:BeginPrompt(prompt, math.max(prompt.HoldDuration, 2.2))
        else
            local input = self.Ctx.Services.VirtualInputManager
            pcall(function() input:SendKeyEvent(true, Enum.KeyCode.T, false, game) end)
            task.delay(2.25, function()
                pcall(function() input:SendKeyEvent(false, Enum.KeyCode.T, false, game) end)
            end)
        end
        self.Phase = "collect"
        self.CollectUntil = now + 60
        self.LastLootAt = now
        self.NextAt = now + 2.5
        return
    end

    if self.Phase == "collect" then
        local prompt, pos = self:NearestPrompt(root, true)
        if prompt and pos then
            tp:Go(CFrame.new(pos + Vector3.new(0, 2.5, 0)))
            self:BeginPrompt(prompt, math.max(prompt.HoldDuration, 4))
            self.LastLootAt = now
            self.CollectUntil = math.max(self.CollectUntil, now + 12)
            self:SetStatus("Raid Chest • เก็บไอเทม")
            return
        end

        if now >= self.CollectUntil or now - self.LastLootAt >= 6 then
            self:Advance(0.15)
        else
            self.NextAt = now + 0.15
        end
    end
end

function Raid:Init(ctx)
    self.Ctx = ctx
end

function Raid:Start()
    self.Ctx:RegisterJob("Raid", 0.05, function()
        local ok, err = pcall(function() self:Step() end)
        if not ok then self:SetStatus("Raid Chest • ERROR: " .. tostring(err)) end
    end)
end

function Raid:Stop()
    self:SetEnabled(false)
end

return Raid
