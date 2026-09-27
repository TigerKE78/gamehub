-- MazxhubModules/world.lua
-- Cup Game / Auto Pushups / Thunder Breathing migrated from hello.txt

local World = {
    CupGame = {
        Enabled = false,
        Highlight = nil,
        Target = nil,
        NextAt = 0,
        StatusText = "Cup2 ESP • OFF",
    },

    Pushups = {
        Enabled = false,
        NextAt = 0,
        LastClickAt = 0,
        Clicks = 0,
        Progress = 0,
        StartTried = false,
        Starting = false,
        LastStartAttempt = -math.huge,
        PromptState = setmetatable({}, { __mode = "k" }),
        RingState = setmetatable({}, { __mode = "k" }),
        StatusText = "Auto Pushups • OFF",
    },

    Thunder = {
        Enabled = false,
        Phase = "trainer",
        NextAt = 0,
        Character = nil,
        Root = nil,
        TrainingPosition = Vector3.new(
            -1885.1500244140625,
            315.2499694824219,
            34.36198425292969
        ),
        Clicks = 0,
        Armed = true,
        LastClickAt = 0,
        LastSeenAt = 0,
        NextScanAt = 0,
        LastPairKey = nil,
        Progress = 0,
        StatusText = "ปราณสายฟ้า • OFF",
    },
}

local function uiGui(self)
    local ui = self.Ctx.Modules.UI
    return ui and ui.Gui
end

local function inputBlocked(self)
    local farm = self.Ctx.Modules.Farm
    return farm
        and farm.InputBlocked
        and farm.InputBlocked()
        or false
end

local function signal(self)
    local farm = self.Ctx.Modules.Farm
    return farm and farm.GetSignal and farm.GetSignal() or nil
end

local function tele(self)
    return self.Ctx.Modules.Teleport
end

function World:SetStatus(mode, text)
    mode.StatusText = text

    if mode.Label and mode.Label.Parent then
        mode.Label.Text = text
    end

    if mode.OnStatus then
        pcall(mode.OnStatus, text)
    end
end

-- Cup Game ----------------------------------------------------

function World:Cup2()
    local training = workspace:FindFirstChild("Training")
    local gameFolder = training and training:FindFirstChild("Cup Game")
    local cupgame = gameFolder and gameFolder:FindFirstChild("Cupgame1")
    local cups = cupgame and cupgame:FindFirstChild("Cups")
    return cups and cups:FindFirstChild("Cup2") or nil
end

function World:ClearCupHighlight()
    local mode = self.CupGame

    if mode.Highlight then
        pcall(function() mode.Highlight:Destroy() end)
    end

    mode.Highlight = nil
    mode.Target = nil
end

function World:SetCupGame(on)
    local mode = self.CupGame
    on = on == true

    if mode.Enabled == on then return end

    mode.Enabled = on
    mode.NextAt = 0

    if not on then
        self:ClearCupHighlight()
        self:SetStatus(mode, "Cup2 ESP • OFF")
    else
        self:SetStatus(mode, "Cup2 ESP • รอ Cup2")
    end
end

function World:CupStep()
    local mode = self.CupGame
    if not mode.Enabled then return end

    local now = os.clock()
    if now < mode.NextAt then return end
    mode.NextAt = now + 0.08

    local target = self:Cup2()

    if not target then
        self:ClearCupHighlight()
        self:SetStatus(mode, "Cup2 ESP • รอ Cup2")
        return
    end

    if mode.Target ~= target
        or not mode.Highlight
        or not mode.Highlight.Parent then

        self:ClearCupHighlight()

        local highlight = Instance.new("Highlight")
        highlight.Name = "MazxCup2ESP"
        highlight.Adornee = target
        highlight.FillTransparency = 1
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = target

        mode.Highlight = highlight
        mode.Target = target
    end

    mode.Highlight.Enabled = true
    self:SetStatus(mode, "Cup2 ESP • Outline สีขาว")
end

-- Pushups -----------------------------------------------------

function World:PushupPrompt()
    local training = workspace:FindFirstChild("Training")
    local pushups = training and training:FindFirstChild("Pushups")
    local mat = pushups and pushups:FindFirstChild("PushupMat1")
    local root = mat and mat:FindFirstChild("Root")
    local prompt = root and root:FindFirstChild("ProximityPrompt")
    return prompt, root, pushups
end

function World:StartPushupTraining()
    local mode = self.Pushups

    if mode.Starting then
        return false, "starting"
    end

    mode.Starting = true
    mode.LastStartAttempt = os.clock()

    local prompt, promptRoot = self:PushupPrompt()

    if not prompt or not prompt:IsA("ProximityPrompt") then
        mode.Starting = false
        return false, "Pushup ProximityPrompt not found"
    end

    if not promptRoot or not promptRoot:IsA("BasePart") then
        mode.Starting = false
        return false, "PushupMat1.Root not found"
    end

    local tp = tele(self)

    if tp then
        tp:Go(promptRoot.CFrame * CFrame.new(0, 3, -2.5))
    end

    task.wait(0.25)

    local attempted = false

    pcall(function()
        if fireproximityprompt then
            attempted = true
            fireproximityprompt(prompt)
        end
    end)

    pcall(function()
        attempted = true
        prompt:InputHoldBegin()
        task.wait(
            math.max(
                0.05,
                tonumber(prompt.HoldDuration) or 0
            ) + 0.08
        )
        prompt:InputHoldEnd()
    end)

    local key = prompt.KeyboardKeyCode

    if key ~= Enum.KeyCode.Unknown then
        pcall(function()
            attempted = true
            local input = self.Ctx.Services.VirtualInputManager
            input:SendKeyEvent(true, key, false, game)
            task.wait(
                math.max(
                    0.08,
                    tonumber(prompt.HoldDuration) or 0
                ) + 0.08
            )
            input:SendKeyEvent(false, key, false, game)
        end)
    end

    mode.Starting = false

    return attempted,
        attempted
        and nil
        or "cannot trigger ProximityPrompt"
end

function World:GuiVisible(object)
    if not object
        or not object:IsA("GuiObject")
        or not object.Visible then
        return false
    end

    local ownGui = uiGui(self)

    if ownGui and object:IsDescendantOf(ownGui) then
        return false
    end

    local node = object.Parent

    while node do
        if node:IsA("GuiObject") and not node.Visible then
            return false
        end

        if node:IsA("LayerCollector") and not node.Enabled then
            return false
        end

        node = node.Parent
    end

    return object.AbsoluteSize.X > 0
        and object.AbsoluteSize.Y > 0
end

function World:GuiColor(object)
    if not object or not object:IsA("GuiObject") then
        return nil
    end

    local stroke = object:FindFirstChildOfClass("UIStroke")

    if stroke
        and stroke.Enabled
        and stroke.Transparency < 0.98 then
        return stroke.Color
    end

    if object:IsA("ImageLabel") or object:IsA("ImageButton") then
        if object.ImageTransparency < 0.98 then
            return object.ImageColor3
        end
    end

    if object.BackgroundTransparency < 0.98 then
        return object.BackgroundColor3
    end

    return nil
end

function World:IsWhite(object)
    local color = self:GuiColor(object)
    if not color then return false end

    local high = math.max(color.R, color.G, color.B)
    local low = math.min(color.R, color.G, color.B)

    return low >= 0.56
        and (high - low) <= 0.22
end

function World:IsLightTarget(object)
    local color = self:GuiColor(object)
    if not color then return false end

    local high = math.max(color.R, color.G, color.B)
    local low = math.min(color.R, color.G, color.B)

    return low >= 0.18
        and (high - low) <= 0.34
end

function World:IsRoundish(object)
    local size = object.AbsoluteSize

    if size.X < 8
        or size.Y < 8
        or size.X > 180
        or size.Y > 180 then
        return false
    end

    local ratio = size.X / math.max(size.Y, 1)

    if ratio < 0.62 or ratio > 1.38 then
        return false
    end

    return object:IsA("ImageLabel")
        or object:IsA("ImageButton")
        or object:FindFirstChildOfClass("UICorner") ~= nil
        or object:FindFirstChildOfClass("UIStroke") ~= nil
end

function World:ScanGuiObjects()
    local out = {}
    local seen = {}

    local roots = {
        self.Ctx.Player:FindFirstChildOfClass("PlayerGui"),
    }

    local _, _, pushups = self:PushupPrompt()

    if pushups then
        table.insert(roots, pushups)
    end

    if workspace.CurrentCamera then
        table.insert(roots, workspace.CurrentCamera)
    end

    local coreGui = game:GetService("CoreGui")
    if coreGui then table.insert(roots, coreGui) end

    for _, root in ipairs(roots) do
        if root then
            for _, object in ipairs(root:GetDescendants()) do
                if object:IsA("GuiObject") and not seen[object] then
                    seen[object] = true
                    table.insert(out, object)
                end
            end
        end
    end

    return out
end

function World:ReadProgress(objects)
    local best

    for _, object in ipairs(objects or self:ScanGuiObjects()) do
        if (
            object:IsA("TextLabel")
            or object:IsA("TextButton")
        ) and self:GuiVisible(object) then

            local value =
                tonumber(
                    tostring(object.Text or "")
                        :match("(%d+)%s*%%")
                )

            if value
                and value >= 0
                and value <= 100 then
                best = math.max(best or 0, value)
            end
        end
    end

    return best
end

function World:ClickObject(object)
    if not object or not object.Parent then
        return false
    end

    local position = object.AbsolutePosition
    local size = object.AbsoluteSize

    local x = math.floor(position.X + size.X * 0.5)
    local y = math.floor(position.Y + size.Y * 0.5)

    local input = self.Ctx.Services.VirtualInputManager

    return pcall(function()
        input:SendMouseMoveEvent(x, y, game)
        task.wait(0.012)
        input:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.025)
        input:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

function World:FindPushupTargets(objects)
    local camera = workspace.CurrentCamera
    if not camera then return {}, {} end

    local viewport = camera.ViewportSize
    local outers = {}
    local inners = {}
    local white = {}

    for _, object in ipairs(objects) do
        if object:IsA("GuiObject")
            and self:GuiVisible(object)
            and self:IsRoundish(object) then

            local position = object.AbsolutePosition
            local size = object.AbsoluteSize
            local cx = position.X + size.X * 0.5
            local cy = position.Y + size.Y * 0.5

            if cx >= viewport.X * 0.035
                and cx <= viewport.X * 0.965
                and cy >= viewport.Y * 0.08
                and cy <= viewport.Y * 0.88 then

                if self:IsWhite(object) then
                    table.insert(outers, object)
                    table.insert(white, object)
                end

                if self:IsLightTarget(object) then
                    table.insert(inners, object)
                end
            end
        end
    end

    local pairsFound = {}

    for _, outer in ipairs(outers) do
        local op = outer.AbsolutePosition
        local os = outer.AbsoluteSize
        local center =
            Vector2.new(
                op.X + os.X * 0.5,
                op.Y + os.Y * 0.5
            )

        local bestInner
        local bestScore

        for _, inner in ipairs(inners) do
            if inner ~= outer then
                local ip = inner.AbsolutePosition
                local isz = inner.AbsoluteSize
                local innerCenter =
                    Vector2.new(
                        ip.X + isz.X * 0.5,
                        ip.Y + isz.Y * 0.5
                    )

                local distance = (center - innerCenter).Magnitude
                local outerD = math.max(os.X, os.Y)
                local innerD = math.max(isz.X, isz.Y)
                local ratio = outerD / math.max(innerD, 1)

                if distance <= math.max(18, innerD * 0.5)
                    and ratio >= 0.65
                    and ratio <= 4.2 then

                    local score =
                        distance * 4
                        + math.abs(ratio - 1.45) * 7

                    if not bestScore or score < bestScore then
                        bestInner = inner
                        bestScore = score
                    end
                end
            end
        end

        if bestInner then
            table.insert(pairsFound, {
                Outer = outer,
                Inner = bestInner,
            })
        end
    end

    return pairsFound, white
end

function World:SetCupEnabled(on)
    return self:SetCupGame(on)
end

function World:SetPushupsEnabled(on)
    return self:SetPushups(on)
end

function World:SetThunderEnabled(on)
    return self:SetThunder(on)
end

function World:SetPushups(on)
    local mode = self.Pushups
    on = on == true

    if mode.Enabled == on then return end

    mode.Enabled = on
    mode.NextAt = 0
    mode.LastClickAt = 0
    mode.Clicks = 0
    mode.Progress = 0
    mode.StartTried = false
    mode.Starting = false
    mode.LastStartAttempt = -math.huge
    mode.PromptState = setmetatable({}, { __mode = "k" })
    mode.RingState = setmetatable({}, { __mode = "k" })

    if on then
        task.defer(function()
            if not mode.Enabled or mode.StartTried then return end

            mode.StartTried = true

            local ok, err = self:StartPushupTraining()

            if mode.Enabled then
                self:SetStatus(
                    mode,
                    ok
                        and "Auto Pushups • เปิด PushupMat1 แล้ว • รอวงกลม"
                        or ("Auto Pushups • " .. tostring(err))
                )
            end
        end)
    else
        self:SetStatus(mode, "Auto Pushups • OFF")
    end
end

function World:PushupStep()
    local mode = self.Pushups
    if not mode.Enabled then return end

    local now = os.clock()

    if now < mode.NextAt then return end
    mode.NextAt = now + 0.008

    local objects = self:ScanGuiObjects()
    local progress = self:ReadProgress(objects) or mode.Progress or 0
    mode.Progress = math.max(mode.Progress or 0, progress)

    local pairsFound, white =
        self:FindPushupTargets(objects)

    local clicked = 0

    for _, pair in ipairs(pairsFound) do
        local outer = pair.Outer
        local inner = pair.Inner

        if outer.Parent and inner.Parent then
            local outerD =
                math.max(
                    outer.AbsoluteSize.X,
                    outer.AbsoluteSize.Y
                )
            local innerD =
                math.max(
                    inner.AbsoluteSize.X,
                    inner.AbsoluteSize.Y
                )
            local diff = math.abs(outerD - innerD)

            local state = mode.PromptState[outer]

            if not state then
                state = {
                    Armed = true,
                    LastDiff = math.huge,
                    ClickedAt = 0,
                }
                mode.PromptState[outer] = state
            end

            if diff >= math.max(18, innerD * 0.38)
                or diff > state.LastDiff + 5 then
                state.Armed = true
            end

            state.LastDiff = diff

            local tolerance = math.max(8, innerD * 0.24)

            if diff <= tolerance
                and state.Armed
                and now - state.ClickedAt >= 0.10 then

                if self:ClickObject(inner) then
                    state.Armed = false
                    state.ClickedAt = now
                    mode.LastClickAt = now
                    mode.Clicks += 1
                    clicked += 1
                end
            end
        end
    end

    if #pairsFound == 0 and #white == 0 then
        if progress <= 0
            and not mode.Starting
            and now - mode.LastStartAttempt >= 3 then

            task.spawn(function()
                local ok, err = self:StartPushupTraining()

                if mode.Enabled then
                    self:SetStatus(
                        mode,
                        ok
                            and "Auto Pushups • กด Prompt แล้ว • รอวงกลม"
                            or ("Auto Pushups • " .. tostring(err))
                    )
                end
            end)
        else
            self:SetStatus(
                mode,
                "Auto Pushups • "
                    .. tostring(progress)
                    .. "% • รอวง"
            )
        end

        return
    end

    self:SetStatus(
        mode,
        clicked > 0
            and (
                "Auto Pushups • "
                .. tostring(progress)
                .. "% • CLICK #"
                .. tostring(mode.Clicks)
            )
            or (
                "Auto Pushups • "
                .. tostring(progress)
                .. "% • จับจังหวะ"
            )
    )
end

-- Thunder -----------------------------------------------------

function World:SetThunder(on)
    local mode = self.Thunder
    on = on == true

    if mode.Enabled == on then return end

    mode.Enabled = on
    mode.Phase = "trainer"
    mode.NextAt = 0
    mode.Character = nil
    mode.Root = nil
    mode.Clicks = 0
    mode.Armed = true
    mode.LastClickAt = 0
    mode.LastSeenAt = 0
    mode.NextScanAt = 0
    mode.LastPairKey = nil
    mode.Progress = 0

    self:SetStatus(
        mode,
        on
            and "ปราณสายฟ้า • ไปหา Zentaro"
            or "ปราณสายฟ้า • OFF"
    )
end

function World:FindTimingPair()
    local playerGui =
        self.Ctx.Player:FindFirstChildOfClass("PlayerGui")

    if not playerGui then return nil end

    local markers = {}
    local targets = {}

    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("GuiObject")
            and self:GuiVisible(object) then

            local color = self:GuiColor(object)

            if color then
                local size = object.AbsoluteSize
                local r, g, b = color.R, color.G, color.B

                local nearWhite =
                    r >= 0.72
                    and g >= 0.72
                    and b >= 0.72

                local yellow =
                    r >= 0.68
                    and g >= 0.52
                    and b <= 0.62
                    and r >= b + 0.10

                local blue =
                    b >= 0.58
                    and g >= 0.45
                    and b >= r + 0.04

                local cyan =
                    g >= 0.62
                    and b >= 0.62
                    and r <= math.max(g, b) - 0.04

                local markerShape =
                    size.X >= 8
                    and size.X <= 70
                    and size.Y >= 8
                    and size.Y <= 70

                if markerShape
                    and (
                        blue
                        or cyan
                        or nearWhite
                    ) then
                    table.insert(markers, object)
                end

                local thin =
                    size.X >= 1
                    and size.X <= 22
                    and size.Y >= 6
                    and size.Y <= 100

                local hitZone =
                    size.X >= 8
                    and size.X <= 150
                    and size.Y >= 4
                    and size.Y <= 45

                if (thin or hitZone)
                    and (yellow or nearWhite) then
                    table.insert(targets, object)
                end
            end
        end
    end

    local bestMarker
    local bestTarget
    local bestScore

    for _, marker in ipairs(markers) do
        local mp = marker.AbsolutePosition
        local ms = marker.AbsoluteSize
        local mx = mp.X + ms.X * 0.5
        local my = mp.Y + ms.Y * 0.5

        for _, target in ipairs(targets) do
            if target ~= marker then
                local tp = target.AbsolutePosition
                local ts = target.AbsoluteSize
                local tx = tp.X + ts.X * 0.5
                local ty = tp.Y + ts.Y * 0.5

                local dx = math.abs(mx - tx)
                local dy = math.abs(my - ty)
                local score = dy * 2 + dx * 0.004

                if dy <= math.max(38, ms.Y * 1.6)
                    and dx <= 900
                    and (
                        not bestScore
                        or score < bestScore
                    ) then
                    bestMarker = marker
                    bestTarget = target
                    bestScore = score
                end
            end
        end
    end

    return bestMarker, bestTarget
end

function World:ThunderTimingStep()
    local mode = self.Thunder
    local now = os.clock()

    if now < mode.NextScanAt then return end
    mode.NextScanAt = now + 0.008

    local progress = self:ReadProgress()
    if progress then
        mode.Progress = math.max(mode.Progress or 0, progress)
    end

    if mode.Progress >= 100 and mode.Clicks > 0 then
        self:SetThunder(false)
        self:SetStatus(mode, "ปราณสายฟ้า • 100% • DONE")
        return
    end

    local marker, target = self:FindTimingPair()

    if not marker or not target then
        if mode.LastSeenAt > 0
            and now - mode.LastSeenAt > 0.08 then

            mode.Armed = true
            mode.LastPairKey = nil
        end
        return
    end

    mode.LastSeenAt = now

    local key = tostring(marker) .. "|" .. tostring(target)

    if key ~= mode.LastPairKey then
        mode.LastPairKey = key
        mode.Armed = true
    end

    local mp = marker.AbsolutePosition
    local ms = marker.AbsoluteSize
    local tp = target.AbsolutePosition
    local ts = target.AbsoluteSize

    local markerLeft = mp.X
    local markerRight = mp.X + ms.X
    local targetLeft = tp.X
    local targetRight = tp.X + ts.X

    local tolerance =
        math.max(
            5,
            math.min(16, ms.X * 0.45)
        )

    local inside =
        markerRight >= targetLeft - tolerance
        and markerLeft <= targetRight + tolerance

    if not inside then
        mode.Armed = true
        return
    end

    if not mode.Armed
        or now - mode.LastClickAt < 0.065 then
        return
    end

    mode.Armed = false
    mode.LastClickAt = now
    mode.Clicks += 1

    self:ClickObject(target)

    self:SetStatus(
        mode,
        "ปราณสายฟ้า • "
            .. tostring(mode.Progress or 0)
            .. "% • คลิก #"
            .. tostring(mode.Clicks)
    )
end

function World:ThunderStep()
    local mode = self.Thunder
    if not mode.Enabled then return end

    local now = os.clock()

    if now < mode.NextAt then return end

    local char = self.Ctx.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if not root or not hum or hum.Health <= 0 then
        self:SetStatus(mode, "ปราณสายฟ้า • รอตัวละครพร้อม")
        return
    end

    if inputBlocked(self) then
        return
    end

    local tp = tele(self)

    if mode.Phase == "trainer" then
        local destination =
            tp
            and tp:Destination("Thunder Trainer Zentaro")

        if not destination then
            mode.NextAt = now + 1
            return
        end

        tp:Go(destination)
        mode.Phase = "talk"
        mode.NextAt = now + 0.45
        return
    end

    if mode.Phase == "talk" then
        local event = signal(self)

        if not event then
            mode.NextAt = now + 1
            return
        end

        event:FireServer("NpcTalking", "Ended")
        mode.Phase = "accept"
        mode.NextAt = now + 0.2
        return
    end

    if mode.Phase == "accept" then
        local event = signal(self)

        if not event then
            mode.NextAt = now + 1
            return
        end

        event:FireServer(
            "AddQuest",
            "Ill learn Thunder Breathing(Lv 25)"
        )

        mode.Phase = "training"
        mode.NextAt = now + 0.35
        return
    end

    if mode.Phase == "training" then
        local destination =
            tp
            and tp:Destination("Thunder Trainer Zentaro")

        if destination then
            tp:Go(destination * CFrame.new(0, 0, -5))
        end

        mode.Phase = "minigame"
        mode.NextAt = now + 0.55
        return
    end

    if mode.Phase == "minigame" then
        self:ThunderTimingStep()
    end
end

function World:Init(ctx)
    self.Ctx = ctx
    self.Cup = self.CupGame
end

function World:Start()
    self.Ctx:RegisterJob("WorldCup", 0.05, function()
        self:CupStep()
    end)

    self.Ctx:RegisterJob("WorldPushups", 0.01, function()
        self:PushupStep()
    end)

    self.Ctx:RegisterJob("WorldThunder", 0.01, function()
        self:ThunderStep()
    end)
end

function World:Stop()
    self:SetCupGame(false)
    self:SetPushups(false)
    self:SetThunder(false)
end

return World
