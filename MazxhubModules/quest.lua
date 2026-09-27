-- MazxhubModules/quest.lua
-- Story/collection quests migrated from hello.txt.
-- Keeps one quest active at a time and reuses Farm / Teleport / Combat modules.

local Quest = {
    Active = nil,
    Connections = {},
    Quests = {},
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

local function signal(self)
    local f = farm(self)
    return f and f.GetSignal and f.GetSignal() or nil
end

local function blocked(self)
    local f = farm(self)
    return f and f.InputBlocked and f.InputBlocked() or false
end

local function aliveCharacter(self)
    local char = self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return char, hum, root
end

local function cframeOf(self, object)
    local f = farm(self)
    return f and f.CFrameOf and f.CFrameOf(object) or nil
end

function Quest:SetStatus(q, text)
    q.StatusText = text
    q.Status = text

    if q.Label and q.Label.Parent then
        q.Label.Text = text
    end

    if q.OnStatus then
        pcall(q.OnStatus, text)
    end
end

function Quest:StopAll(except)
    for name, q in pairs(self.Quests) do
        if name ~= except and q.Enabled then
            self:SetEnabled(name, false)
        end
    end
end

function Quest:GoNpc(name)
    local tp = teleport(self)
    if not tp then return false end

    local destination = tp:Destination(name)
    if not destination then return false end

    local ok = tp:Go(destination * CFrame.new(0, 0, -3))
    return ok == true
end

function Quest:Talk()
    local event = signal(self)
    if not event then return false end
    return pcall(function()
        event:FireServer("NpcTalking", "Ended")
    end)
end

function Quest:AddQuest(text)
    local event = signal(self)
    if not event then return false end
    return pcall(function()
        event:FireServer("AddQuest", text)
    end)
end

function Quest:PressT(seconds)
    local input = self.Ctx.Services.VirtualInputManager
    input:SendKeyEvent(true, Enum.KeyCode.T, false, game)
    task.delay(seconds or 1, function()
        pcall(function()
            input:SendKeyEvent(false, Enum.KeyCode.T, false, game)
        end)
    end)
end

function Quest:SetEnabled(name, on)
    local q = self.Quests[name]
    if not q then return false end

    on = on == true

    if q.Enabled == on then
        return true
    end

    if on then
        self:StopAll(name)

        local f = farm(self)
        if f.Enabled then
            f:Stop()
        end

        local c = combat(self)
        if c and c.Release then
            c:Release()
        end

        self.Active = name
    elseif self.Active == name then
        self.Active = nil
    end

    q.Enabled = on

    if q.OnEnabled then
        pcall(q.OnEnabled, on)
    end

    q.Phase = q.StartPhase or "npc"
    q.NextAt = 0
    q.Attempts = 0
    q.Character = nil
    q.Root = nil

    if name == "Pages" then
        q.Index = 1
        q.Collected = 0
        q.Current = nil
    elseif name == "Kazu" then
        q.Kills = 0
        q.Stage = q.Stage or "new"
        q.Watch = nil
    elseif name == "Bear" then
        q.Kills = 0
        q.TomRuns = 0
        q.Watch = nil
    end

    self:SetStatus(
        q,
        on
            and (q.OnText or (name .. " • ON"))
            or (name .. " • OFF")
    )

    return true
end

function Quest:BettyStep(q, now)
    local _, hum, root = aliveCharacter(self)
    if not hum or hum.Health <= 0 or not root then
        self:SetStatus(q, "Betty • รอตัวละครพร้อม")
        return
    end

    if blocked(self) then return end
    if now < q.NextAt then return end

    if q.Phase == "npc" then
        if not self:GoNpc("Betty") then
            q.NextAt = now + 1
            return
        end
        q.Phase = "talk"
        q.NextAt = now + 0.4
        self:SetStatus(q, "กำลังไปหา Betty")
        return
    end

    if q.Phase == "talk" then
        if self:Talk() then
            q.Phase = "accept"
            q.NextAt = now + 0.2
        end
        return
    end

    if q.Phase == "accept" then
        if self:AddQuest("Ill look for it(Lv 10)") then
            q.Phase = "gem"
            q.NextAt = now + 0.5
            self:SetStatus(q, "ส่งคำขอเควส Betty แล้ว")
        end
        return
    end

    local gem = workspace:FindFirstChild("Gemstone1")
    local cf = gem and cframeOf(self, gem)

    if q.Phase == "gem" then
        if not cf then
            q.NextAt = now + 1
            self:SetStatus(q, "รอ Gemstone1")
            return
        end

        q.Current = gem
        teleport(self):Go(
            CFrame.lookAt(
                cf.Position + Vector3.new(0, 2, 2),
                cf.Position
            )
        )
        q.Phase = "press"
        q.NextAt = now + 0.35
        return
    end

    if q.Phase == "press" then
        self:PressT(1)
        q.Attempts += 1
        q.Phase = "verify"
        q.NextAt = now + 1.2
        self:SetStatus(q, "กำลังเก็บ Gemstone1")
        return
    end

    if q.Phase == "verify" then
        if not q.Current
            or not q.Current.Parent
            or workspace:FindFirstChild("Gemstone1") ~= q.Current then

            q.Phase = "return"
        elseif q.Attempts >= 3 then
            q.Phase = "return"
        else
            q.Phase = "press"
        end

        q.NextAt = now + 0.4
        return
    end

    if q.Phase == "return" then
        if self:GoNpc("Betty") then
            self:Talk()
            q.Current = nil
            q.Attempts = 0
            q.Phase = "gem"
            q.NextAt = now + 1
            self:SetStatus(q, "กลับ Betty แล้ว รอ Gemstone1 ชิ้นใหม่")
        end
    end
end

function Quest:DeliveryStep(q, now)
    local _, hum = aliveCharacter(self)
    if not hum or hum.Health <= 0 then
        self:SetStatus(q, "Quest 3 • รอตัวละครพร้อม")
        return
    end

    if blocked(self) or now < q.NextAt then return end

    if q.Phase == "source" then
        if self:GoNpc("MoldySugar") then
            q.Phase = "talkSource"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "talkSource" then
        if self:Talk() then
            q.Phase = "accept"
            q.NextAt = now + 0.2
        end
        return
    end

    if q.Phase == "accept" then
        if self:AddQuest("Ill deliver the package") then
            q.Phase = "elara"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "elara" then
        if self:GoNpc("Elara") then
            q.Phase = "equip"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "equip" then
        local event = signal(self)
        if event then
            pcall(function()
                event:FireServer("Item_Equip", 2)
            end)
            q.Phase = "talkElara"
            q.NextAt = now + 0.5
        end
        return
    end

    if q.Phase == "talkElara" then
        if self:Talk() then
            q.Phase = "return"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "return" then
        if self:GoNpc("MoldySugar") then
            self:Talk()
            self:SetEnabled("Delivery", false)
            self:SetStatus(q, "กลับ MoldySugar แล้ว • DONE")
        end
    end
end

function Quest:PagesStep(q, now)
    local _, hum = aliveCharacter(self)
    if not hum or hum.Health <= 0 then
        self:SetStatus(q, "Quest 4 • รอตัวละครพร้อม")
        return
    end

    if blocked(self) or now < q.NextAt then return end

    if q.Phase == "npc" then
        if self:GoNpc("Kona") then
            q.Phase = "talk"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "talk" then
        if self:Talk() then
            q.Phase = "accept"
            q.NextAt = now + 0.2
        end
        return
    end

    if q.Phase == "accept" then
        if self:AddQuest("Ill find the pages") then
            q.Phase = "page"
            q.NextAt = now + 0.4
            self:SetStatus(q, "Quest 4 • Kona • 0/5")
        end
        return
    end

    if q.Phase == "page" then
        if q.Index > 5 then
            q.Phase = "return"
            return
        end

        local page = workspace:FindFirstChild("Lost Page" .. q.Index)
        local cf = page and cframeOf(self, page)

        if not cf then
            q.NextAt = now + 0.8
            self:SetStatus(q, "Quest 4 • รอ Lost Page" .. q.Index)
            return
        end

        q.Current = page
        teleport(self):Go(
            CFrame.lookAt(
                cf.Position + Vector3.new(0, 2, 2),
                cf.Position
            )
        )
        q.Phase = "press"
        q.NextAt = now + 0.35
        return
    end

    if q.Phase == "press" then
        self:PressT(1)
        q.Phase = "verify"
        q.NextAt = now + 1.2
        return
    end

    if q.Phase == "verify" then
        if not q.Current or not q.Current.Parent then
            q.Collected += 1
            q.Index += 1
        else
            q.Index += 1
            q.Collected += 1
        end

        q.Current = nil
        q.Phase = q.Index > 5 and "return" or "page"
        q.NextAt = now + 0.3

        self:SetStatus(
            q,
            "Quest 4 • Kona • "
                .. tostring(q.Collected)
                .. "/5"
        )
        return
    end

    if q.Phase == "return" then
        if self:GoNpc("Kona") then
            self:Talk()
            self:SetEnabled("Pages", false)
            self:SetStatus(q, "กลับ Kona แล้ว • DONE")
        end
    end
end

function Quest:WatchFarmTarget(q, required)
    local f = farm(self)
    local target = f._target or self.Ctx.State.Target

    if not target or not target.Parent then
        q.Watch = nil
        return
    end

    if q.Watch and q.Watch.Target == target then
        return
    end

    if q.Watch and q.Watch.Connection then
        q.Watch.Connection:Disconnect()
    end

    local hum = target:FindFirstChildWhichIsA("Humanoid", true)
    if not hum then return end

    local record = {
        Target = target,
        Humanoid = hum,
    }

    record.Connection = hum.Died:Connect(function()
        if not q.Enabled then return end
        q.Kills += 1
        self:SetStatus(
            q,
            tostring(q.Name or "Quest")
                .. " • "
                .. tostring(q.Kills)
                .. "/"
                .. tostring(required)
        )
    end)

    q.Watch = record
end

function Quest:KazuStep(q, now)
    if now < q.NextAt or blocked(self) then return end

    if q.Phase == "npc" then
        if self:GoNpc("Kazu") then
            q.Phase = "talk"
            q.NextAt = now + 0.35
        end
        return
    end

    if q.Phase == "talk" then
        if self:Talk() then
            self:AddQuest("Ill help clear them out")
            q.Phase = "fight"
            q.NextAt = now + 0.4
            farm(self):StartMob("*Civilian*")
            self:SetStatus(q, "Quest 1 • *Civilian* • 0/4")
        end
        return
    end

    if q.Phase == "fight" then
        self:WatchFarmTarget(q, 4)

        if q.Kills >= 4 then
            farm(self):Stop()
            q.Phase = "noote"
            q.NextAt = now + 0.3
        end
        return
    end

    if q.Phase == "noote" then
        if self:GoNpc("Noote") then
            self:Talk()
            self:AddQuest("Ill get this letter delivered")
            q.Phase = "chaka"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "chaka" then
        if self:GoNpc("Chaka") then
            self:Talk()
            q.Phase = "return"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "return" then
        if self:GoNpc("Kazu") then
            self:Talk()
            self:SetEnabled("Kazu", false)
            self:SetStatus(q, "Quest 1 • DONE")
        end
    end
end

function Quest:BearStep(q, now)
    if now < q.NextAt or blocked(self) then return end

    if q.Phase == "lucy" then
        if self:GoNpc("Lucy") then
            self:Talk()
            self:AddQuest("Ill restock the pantry(Lv 10)")
            q.Phase = "tom"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "tom" then
        if self:GoNpc("Tom") then
            self:Talk()
            self:AddQuest("Ill drive the bears back(Lv 10)")
            q.Kills = 0
            q.TomRuns += 1
            q.Phase = "fight"
            q.NextAt = now + 0.4
            farm(self):StartMob("Bear Cub")
            self:SetStatus(
                q,
                "Quest 5 • Tom รอบ "
                    .. tostring(q.TomRuns)
                    .. " • Bear Cub 0/4"
            )
        end
        return
    end

    if q.Phase == "fight" then
        self:WatchFarmTarget(q, 4)

        if q.Kills >= 4 then
            farm(self):Stop()
            q.Phase = "returnLucy"
            q.NextAt = now + 0.3
        end
        return
    end

    if q.Phase == "returnLucy" then
        if self:GoNpc("Lucy") then
            self:Talk()

            if q.TomRuns < 2 then
                q.Phase = "tom"
                q.Kills = 0
                q.NextAt = now + 0.4
            else
                self:SetEnabled("Bear", false)
                self:SetStatus(q, "Quest 5 • DONE")
            end
        end
    end
end

function Quest:DungeonUnlockStep(q, now)
    if now < q.NextAt or blocked(self) then return end

    if q.Deadline and now >= q.Deadline then
        self:SetEnabled("DungeonUnlock", false)
        self:SetStatus(q, "หมดเวลารอ Dungeon — ลองเปิดใหม่")
        return
    end

    if q.Phase == "npc" then
        if self:GoNpc("Blacksmith Togane") then
            q.Phase = "talk"
            q.NextAt = now + 0.4
        end
        return
    end

    if q.Phase == "talk" then
        if self:Talk() then
            q.Phase = "accept"
            q.NextAt = now + 0.2
        end
        return
    end

    if q.Phase == "accept" then
        if self:AddQuest("Ill find the forge(Lv 65)") then
            q.Phase = "forge"
            q.NextAt = now + 0.5
        end
        return
    end

    if q.Phase == "forge" then
        teleport(self):Go(CFrame.new(q.Forge))
        q.Phase = "press"
        q.NextAt = now + 0.6
        return
    end

    if q.Phase == "press" then
        self:PressT(1.5)
        self:SetEnabled("DungeonUnlock", false)
        self:SetStatus(q, "กด T แล้ว — ตรวจผลปลดล็อกในเกม")
    end
end

function Quest:SetAutoQuest(on)
    local f = farm(self)
    if not f then
        return false, "Farm module unavailable"
    end

    on = on == true
    f.AutoQuest = on
    f.QuestKills = 0
    f._questBusy = false
    f._questNeeded = on
    f._acceptedQuestText = nil
    f._lastQuestAt = -math.huge
    f._questReadyAt = 0
    f._target = nil
    f._attackTarget = nil

    return true
end

function Quest:AcceptOnce(npcName, questText)
    if type(npcName) ~= "string" or npcName == "" then
        return false, "NPC name missing"
    end
    if type(questText) ~= "string" or questText == "" then
        return false, "Quest text missing"
    end

    local _, hum, root = aliveCharacter(self)
    if not hum or hum.Health <= 0 or not root then
        return false, "ตัวละครยังไม่พร้อม"
    end

    local event = signal(self)
    if not event then
        return false, "ไม่พบ SignalEvent"
    end

    local tp = teleport(self)
    local destination = tp and tp:Destination(npcName)
    if not destination then
        return false, "ไม่พบ " .. npcName
    end

    local stand = destination * CFrame.new(0, 0, -3)
    local ok, err = tp:Go(CFrame.lookAt(stand.Position, destination.Position))
    if not ok then
        return false, tostring(err or "Teleport failed")
    end

    task.wait(0.30)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    pcall(function()
        event:FireServer("NpcTalking", "Ended")
    end)
    task.wait(0.12)

    local sent, sendErr = pcall(function()
        event:FireServer("AddQuest", questText)
    end)
    if not sent then
        return false, tostring(sendErr)
    end

    task.wait(0.12)
    pcall(function()
        event:FireServer("NpcTalking", "Ended")
    end)

    local f = farm(self)
    if f then
        f._acceptedQuestText = questText
        f._questNeeded = false
        f._lastQuestAt = os.clock()
    end

    return true
end

function Quest:SetDedicatedEnabled(name, on)
    return self:SetEnabled(name, on)
end

function Quest:Step()
    local name = self.Active
    if not name then return end

    local q = self.Quests[name]
    if not q or not q.Enabled then return end

    local now = os.clock()

    if name == "Betty" then
        self:BettyStep(q, now)
    elseif name == "Kazu" then
        self:KazuStep(q, now)
    elseif name == "Delivery" then
        self:DeliveryStep(q, now)
    elseif name == "Pages" then
        self:PagesStep(q, now)
    elseif name == "Bear" then
        self:BearStep(q, now)
    elseif name == "DungeonUnlock" then
        self:DungeonUnlockStep(q, now)
    end
end

function Quest:Init(ctx)
    self.Ctx = ctx

    self.Quests = {
        Kazu = {
            Name = "Quest 1 • Kazu",
            Enabled = false,
            StartPhase = "npc",
            StatusText = "Quest 1 • OFF",
            Status = "Quest 1 • OFF",
            OnText = "Quest 1 • Kazu • 0/4",
        },

        Betty = {
            Name = "Quest 2 • Betty",
            Enabled = false,
            StartPhase = "npc",
            StatusText = "Quest 2 • OFF",
            Status = "Quest 2 • OFF",
            OnText = "Auto Quest Betty • ON",
        },

        Delivery = {
            Name = "Quest 3 • MoldySugar",
            Enabled = false,
            StartPhase = "source",
            StatusText = "Quest 3 • OFF",
            Status = "Quest 3 • OFF",
            OnText = "Quest 3 • MoldySugar",
        },

        Pages = {
            Name = "Quest 4 • Kona",
            Enabled = false,
            StartPhase = "npc",
            StatusText = "Quest 4 • OFF",
            Status = "Quest 4 • OFF",
            OnText = "Quest 4 • Kona • 0/5",
            Index = 1,
            Collected = 0,
        },

        Bear = {
            Name = "Quest 5 • Lucy / Tom",
            Enabled = false,
            StartPhase = "lucy",
            StatusText = "Quest 5 • OFF",
            Status = "Quest 5 • OFF",
            OnText = "Quest 5 • เริ่มที่ Lucy",
            Kills = 0,
            TomRuns = 0,
        },

        DungeonUnlock = {
            Name = "Dungeon Unlock",
            Enabled = false,
            StartPhase = "npc",
            StatusText = "Dungeon • OFF",
            Status = "Dungeon • OFF",
            OnText = "กำลังไปหา Blacksmith Togane",
            Forge = Vector3.new(
                -1604.9444580078125,
                1002.4012451171875,
                1143.3331298828125
            ),
        },
    }
end

function Quest:Start()
    self.Ctx:RegisterJob("Quest", 0.05, function()
        local ok, err = pcall(function()
            self:Step()
        end)

        if not ok then
            local q = self.Active and self.Quests[self.Active]
            if q then
                self:SetStatus(q, "ERROR: " .. tostring(err))
                self:SetEnabled(self.Active, false)
            end
        end
    end)
end

function Quest:Stop()
    self:StopAll(nil)

    for _, q in pairs(self.Quests) do
        if q.Watch and q.Watch.Connection then
            q.Watch.Connection:Disconnect()
        end
        q.Watch = nil
    end
end

return Quest
