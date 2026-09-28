-- MazxhubModules/ui.lua
-- Desktop UI สำหรับ Farm / Boss / Combat / Skill
-- UI แยกจาก logic เพื่อไม่ให้ register ของระบบหลักปนกัน

local UI = {
    Pages = {},
    Connections = {},
    IsOpen = false,
    ActivePage = nil,
}

local T = {
    Bg = Color3.fromRGB(14, 18, 24),
    Side = Color3.fromRGB(18, 24, 32),
    Card = Color3.fromRGB(25, 33, 44),
    Card2 = Color3.fromRGB(31, 41, 54),
    Text = Color3.fromRGB(230, 235, 241),
    Sub = Color3.fromRGB(145, 157, 171),
    Accent = Color3.fromRGB(115, 181, 255),
    Mint = Color3.fromRGB(100, 225, 166),
    Danger = Color3.fromRGB(255, 110, 120),
    Stroke = Color3.fromRGB(54, 67, 83),
}

local function new(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return new("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
    }, parent)
end

local function stroke(parent)
    return new("UIStroke", {
        Color = T.Stroke,
        Thickness = 1,
        Transparency = 0.3,
    }, parent)
end

local function label(parent, text, size, color, bold)
    return new("TextLabel", {
        Size = UDim2.new(1, 0, 0, size + 8),
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = color or T.Text,
        TextSize = size or 12,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

function UI:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.Connections, connection)
    return connection
end

function UI:SetOpen(state)
    self.IsOpen = state == true
    if self.Main then
        self.Main.Visible = self.IsOpen
    end
end

function UI:AddPage(name)
    local page = new("ScrollingFrame", {
        Name = name,
        Size = UDim2.new(1, -118, 1, -48),
        Position = UDim2.fromOffset(110, 48),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Accent,
        Visible = false,
    }, self.Main)

    new("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)

    new("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    }, page)

    self.Pages[name] = page

    local button = new("TextButton", {
        Size = UDim2.new(1, -12, 0, 36),
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = T.Sub,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
    }, self.Nav)

    corner(button, 7)

    button.Activated:Connect(function()
        self:SelectPage(name)
    end)

    self.NavButtons[name] = button
    return page
end

function UI:SelectPage(name)
    for pageName, page in pairs(self.Pages) do
        local active = pageName == name
        page.Visible = active

        local button = self.NavButtons[pageName]
        if button then
            button.TextColor3 = active and T.Accent or T.Sub
            button.BackgroundTransparency = active and 0 or 0.35
        end
    end

    self.ActivePage = name
end

function UI:Section(page, text)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = T.Card2,
        BorderSizePixel = 0,
    }, page)

    corner(frame, 7)

    local title = label(
        frame,
        text,
        12,
        T.Text,
        true
    )
    title.Size = UDim2.new(1, -20, 1, 0)
    title.Position = UDim2.fromOffset(10, 0)

    return frame
end

function UI:AddButton(page, text, callback)
    local button = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = T.Text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
    }, page)

    corner(button, 7)
    stroke(button)

    button.Activated:Connect(function()
        if callback then callback(button) end
    end)

    return button
end

function UI:AddToggle(page, text, default, callback)
    local enabled = default == true
    local button

    local function render()
        button.Text =
            (enabled and "●  " or "○  ")
            .. text
        button.TextColor3 =
            enabled and T.Mint or T.Text
    end

    button = self:AddButton(page, "", function()
        enabled = not enabled
        render()
        if callback then callback(enabled) end
    end)

    render()

    return button, function(state, fire)
        enabled = state == true
        render()
        if fire and callback then callback(enabled) end
    end
end

function UI:AddSlider(page, title, min, max, value, suffix, callback)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1,
    }, page)

    local titleLabel = label(frame, title, 12, T.Text, true)
    titleLabel.Size = UDim2.new(1, -80, 0, 18)

    local valueLabel = label(frame, "", 11, T.Accent, true)
    valueLabel.Size = UDim2.fromOffset(76, 18)
    valueLabel.Position = UDim2.new(1, -76, 0, 0)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local track = new("Frame", {
        Size = UDim2.new(1, 0, 0, 7),
        Position = UDim2.fromOffset(0, 34),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
    }, frame)
    corner(track, 4)

    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
    }, track)
    corner(fill, 4)

    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.fromOffset(0, -8),
        BackgroundTransparency = 1,
        Text = "",
    }, track)

    local current = value
    local dragging = false

    local function set(v)
        current = math.clamp(v, min, max)
        local alpha = (current - min) / math.max(max - min, 0.001)
        fill.Size = UDim2.new(alpha, 0, 1, 0)

        local shown =
            math.abs(current - math.floor(current)) < 0.001
            and tostring(math.floor(current))
            or string.format("%.1f", current)

        valueLabel.Text = shown .. (suffix or "")

        if callback then
            callback(current)
        end
    end

    local function move(x)
        local alpha = math.clamp(
            (x - track.AbsolutePosition.X)
                / math.max(track.AbsoluteSize.X, 1),
            0,
            1
        )
        set(min + (max - min) * alpha)
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            move(input.Position.X)
        end
    end)

    self:Connect(
        self.Ctx.Services.UserInputService.InputChanged,
        function(input)
            if dragging
                and input.UserInputType == Enum.UserInputType.MouseMovement then
                move(input.Position.X)
            end
        end
    )

    self:Connect(
        self.Ctx.Services.UserInputService.InputEnded,
        function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end
    )

    set(value)
    return frame
end

function UI:AddDropdown(page, title, options, default, callback)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1,
    }, page)

    local titleLabel = label(frame, title, 11, T.Sub, false)
    titleLabel.Size = UDim2.new(1, 0, 0, 18)

    local button = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        Position = UDim2.fromOffset(0, 22),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Text = default or options[1] or "—",
        TextColor3 = T.Text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
    }, frame)

    corner(button, 7)
    stroke(button)

    local index = table.find(options, button.Text) or 1

    button.Activated:Connect(function()
        if #options == 0 then return end
        index = index % #options + 1
        button.Text = options[index]
        if callback then callback(options[index]) end
    end)

    return button
end

function UI:BuildFarmPage()
    local f = self.Ctx.Modules.Farm
    local page = self:AddPage("Farm")

    self:Section(page, "Mob Farm")

    local mobs = f.farmListMobTypes and f.farmListMobTypes() or {}
    local selectedMob = mobs[1]

    self:AddDropdown(
        page,
        "เลือกมอน • คลิกเพื่อเปลี่ยนตัวถัดไป",
        mobs,
        selectedMob,
        function(name)
            selectedMob = name
            f:SetMob(name)
        end
    )

    self:AddButton(page, "▶ Start Mob Farm", function()
        if selectedMob then
            f:StartMob(selectedMob)
        end
    end)

    self:AddButton(page, "■ Stop Farm", function()
        f:Stop()
    end)

    self:Section(page, "Position")

    self:AddSlider(
        page,
        "Height Above Head",
        1,
        8,
        f.HeadHeight,
        " st",
        function(value)
            f.HeadHeight = value
        end
    )

    self:AddSlider(
        page,
        "Attack Range",
        5,
        25,
        f.AttackRange,
        " st",
        function(value)
            f.AttackRange = value
        end
    )
end

function UI:BuildBossPage()
    local boss = self.Ctx.Modules.Boss
    local page = self:AddPage("Boss")

    self:Section(page, "Farm Boss All")

    local status = label(
        page,
        "เลือกบอส 0 ตัว",
        11,
        T.Sub,
        false
    )

    local function updateStatus()
        status.Text =
            "เลือกบอส "
            .. tostring(#boss.Order)
            .. " ตัว"
        status.TextColor3 =
            #boss.Order > 0
            and T.Mint
            or T.Sub
    end

    local bossToggleSetters = {}

    for _, name in ipairs(boss.Names) do
        local bossName = name
        local _, setter = self:AddToggle(
            page,
            bossName,
            boss.Selected[bossName] == true,
            function(on)
                boss:SetSelected(bossName, on)
                updateStatus()
            end
        )
        bossToggleSetters[bossName] = setter
    end

    self:AddButton(page, "▶ Start Selected Bosses", function()
        local ok, err = boss:StartSelected()
        if not ok then
            status.Text = tostring(err)
            status.TextColor3 = T.Danger
        else
            updateStatus()
        end
    end)

    self:AddButton(page, "■ Stop Boss Farm", function()
        boss:Stop()
    end)

    self:AddButton(page, "Clear Selection", function()
        boss:ClearSelection()
        for _, setter in pairs(bossToggleSetters) do
            setter(false, false)
        end
        updateStatus()
    end)

    updateStatus()
end

function UI:BuildCombatPage()
    local f = self.Ctx.Modules.Farm
    local combat = self.Ctx.Modules.Combat
    local page = self:AddPage("Combat")

    self:Section(page, "Combat")

    self:AddToggle(
        page,
        "Auto Attack",
        f.AutoAttack,
        function(on)
            f.AutoAttack = on
            if not on then
                combat:ReleaseAttack()
            end
        end
    )

    self:AddToggle(
        page,
        "Fast Attack",
        f.FastAttack,
        function(on)
            f.FastAttack = on
            combat:ResetProgress()

            if on and f.BypassComboGate then
                combat:BindGameComboGate()
            else
                combat:UnbindGameComboGate()
            end
        end
    )

    self:AddToggle(
        page,
        "Continuous Combo Reset",
        f.BypassComboGate,
        function(on)
            f.BypassComboGate = on

            if on then
                combat:BindGameComboGate()
            else
                combat:UnbindGameComboGate()
            end
        end
    )

    self:AddDropdown(
        page,
        "ช่องอาวุธ",
        {
            "ช่อง 1",
            "ช่อง 2",
            "ช่อง 3",
            "ช่อง 4",
            "ช่อง 5",
        },
        f.SelectedWeapon,
        function(name)
            f.SelectedWeapon = name
            f._lastHotbarSelection = nil
            f._lastHotbarCharacter = nil
            combat.EquipReadyAt = 0
        end
    )

    self:AddSlider(
        page,
        "Attack Interval",
        20,
        200,
        f.AttackInterval * 1000,
        " ms",
        function(value)
            f.AttackInterval = value / 1000
            combat.AdaptiveInterval = f.AttackInterval
        end
    )
end

function UI:BuildSkillPage()
    local skill = self.Ctx.Modules.Skill
    local page = self:AddPage("Skill")

    self:Section(page, "Auto Skills")

    self:AddToggle(
        page,
        "Auto Skills",
        skill.Enabled,
        function(on)
            skill:SetEnabled(on)
        end
    )

    for _, key in ipairs(skill.Keys) do
        local skillKey = key
        local setting = skill.Settings[skillKey]

        self:AddToggle(
            page,
            "Skill " .. skillKey,
            setting.Enabled,
            function(on)
                skill:SetKeyEnabled(skillKey, on)
            end
        )

        self:AddSlider(
            page,
            "Interval " .. skillKey,
            0.1,
            10,
            setting.Interval,
            " s",
            function(value)
                skill:SetInterval(skillKey, value)
            end
        )
    end
end

function UI:BuildPages()
    self:BuildFarmPage()
    self:BuildBossPage()
    self:BuildCombatPage()
    self:BuildSkillPage()
    self:SelectPage("Farm")
end

function UI:BindWindowDrag()
    local input = self.Ctx.Services.UserInputService
    local dragging = false
    local startMouse
    local startPosition

    self.DragBar.InputBegan:Connect(function(event)
        if event.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        dragging = true
        startMouse = event.Position
        startPosition = self.Main.Position
    end)

    self:Connect(input.InputChanged, function(event)
        if not dragging
            or event.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local delta = event.Position - startMouse

        self.Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)

    self:Connect(input.InputEnded, function(event)
        if event.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

function UI:Init(ctx)
    self.Ctx = ctx
    self.Pages = {}
    self.Connections = {}
    self.NavButtons = {}
end

function UI:Start()
    local playerGui =
        self.Ctx.Player:WaitForChild("PlayerGui")

    self.Gui = new("ScreenGui", {
        Name = "MazxhubModulesUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 50,
    }, playerGui)

    self.Surface = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    }, self.Gui)

    self.Fab = new("ImageButton", {
        Name = "Fab",
        Size = UDim2.fromOffset(52, 52),
        Position = UDim2.new(0.5, -26, 0, 52),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Image =
            "rbxthumb://type=AvatarHeadShot&id="
            .. tostring(self.Ctx.Player.UserId)
            .. "&w=150&h=150",
    }, self.Surface)
    corner(self.Fab, 26)
    stroke(self.Fab)

    self.Main = new("Frame", {
        Size = UDim2.fromOffset(740, 500),
        Position = UDim2.new(0.5, -370, 0.5, -250),
        BackgroundColor3 = T.Bg,
        BorderSizePixel = 0,
        Visible = false,
    }, self.Surface)
    corner(self.Main, 8)
    stroke(self.Main)

    self.Nav = new("Frame", {
        Size = UDim2.new(0, 110, 1, 0),
        BackgroundColor3 = T.Side,
        BorderSizePixel = 0,
    }, self.Main)
    corner(self.Nav, 8)

    new("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, self.Nav)

    new("UIPadding", {
        PaddingTop = UDim.new(0, 54),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
    }, self.Nav)

    local title = label(
        self.Main,
        "Mazxhub Modular",
        16,
        T.Accent,
        true
    )
    title.Size = UDim2.new(1, -138, 0, 48)
    title.Position = UDim2.fromOffset(126, 0)

    self.DragBar = new("Frame", {
        Size = UDim2.new(1, -110, 0, 48),
        Position = UDim2.fromOffset(110, 0),
        BackgroundTransparency = 1,
        Active = true,
    }, self.Main)

    local close = new("TextButton", {
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(1, -38, 0, 9),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Text = "✕",
        TextColor3 = T.Sub,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
    }, self.Main)
    corner(close, 7)

    self:BuildPages()
    self:BindWindowDrag()

    self.Fab.Activated:Connect(function()
        self:SetOpen(not self.IsOpen)
    end)

    close.Activated:Connect(function()
        self:SetOpen(false)
    end)

    self:Connect(
        self.Ctx.Services.UserInputService.InputBegan,
        function(input, processed)
            if not processed
                and input.KeyCode == Enum.KeyCode.RightShift then
                self:SetOpen(not self.IsOpen)
            end
        end
    )
end

function UI:Stop()
    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self.Connections = {}

    if self.Gui then
        self.Gui:Destroy()
        self.Gui = nil
    end
end

return UI
