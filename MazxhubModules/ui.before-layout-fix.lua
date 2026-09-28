-- MazxhubModules/ui.lua
-- Legacy-style Mazxhub UI rebuilt from hello.txt presentation layer.
-- Backend actions are routed to modular Farm/Boss/Combat/Skill modules.

local UI = {
    Pages = {},
    NavButtons = {},
    Connections = {},
    IsOpen = false,
    ActiveMenu = "Farm",
    ActiveSubTab = nil,
}

local TweenService = game:GetService("TweenService")

local T = {
    Bg = Color3.fromRGB(17, 22, 29),
    Sidebar = Color3.fromRGB(20, 26, 34),
    Card = Color3.fromRGB(27, 34, 44),
    CardHover = Color3.fromRGB(35, 44, 55),
    Stroke = Color3.fromRGB(54, 65, 78),
    Track = Color3.fromRGB(32, 49, 65),
    Text = Color3.fromRGB(220, 226, 233),
    Sub = Color3.fromRGB(155, 168, 184),
    Accent = Color3.fromRGB(137, 178, 207),
    AccentSoft = Color3.fromRGB(41, 57, 72),
    Ink = Color3.fromRGB(5, 22, 33),
    Mint = Color3.fromRGB(140, 188, 167),
    Danger = Color3.fromRGB(190, 70, 80),
    Gold = Color3.fromRGB(198, 179, 134),
}

local TI = TweenInfo.new(
    0.20,
    Enum.EasingStyle.Quad,
    Enum.EasingDirection.Out
)

local function new(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    if parent then
        object.Parent = parent
    end
    return object
end

local function corner(parent, radius)
    return new("UICorner", {
        CornerRadius = UDim.new(0, radius or 10),
    }, parent)
end

local function stroke(parent, color, thickness)
    return new("UIStroke", {
        Color = color or T.Stroke,
        Thickness = thickness or 1,
        Transparency = 0.4,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function pad(parent, top, bottom, left, right)
    return new("UIPadding", {
        PaddingTop = UDim.new(0, top),
        PaddingBottom = UDim.new(0, bottom or top),
        PaddingLeft = UDim.new(0, left or top),
        PaddingRight = UDim.new(0, right or left or top),
    }, parent)
end

local function label(parent, text, size, color, font, position, frameSize)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        Text = text or "",
        TextSize = size or 12,
        TextColor3 = color or T.Text,
        Font = font or Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = position or UDim2.new(),
        Size = frameSize or UDim2.fromScale(1, 1),
    }, parent)
end

local function tween(object, props)
    TweenService:Create(object, TI, props):Play()
end

function UI:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.Connections, connection)
    return connection
end

function UI:Farm()
    return self.Ctx.Modules.Farm
end

function UI:Boss()
    return self.Ctx.Modules.Boss
end

function UI:Combat()
    return self.Ctx.Modules.Combat
end

function UI:Skill()
    return self.Ctx.Modules.Skill
end

function UI:SetOpen(state)
    self.IsOpen = state == true
    if self.Main then
        self.Main.Visible = self.IsOpen
    end
end

function UI:CreateSection(parent, titleText, default, callback)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = T.AccentSoft,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
    }, parent)
    corner(frame, 5)

    local title = label(
        frame,
        titleText,
        12,
        T.Text,
        Enum.Font.GothamBold,
        UDim2.fromOffset(24, 0),
        UDim2.new(1, callback and -86 or -36, 1, 0)
    )
    title.TextTruncate = Enum.TextTruncate.AtEnd

    local dot = new("Frame", {
        Size = UDim2.fromOffset(2, 12),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 11, 0.5, 0),
    }, frame)
    corner(dot, 3)

    if not callback then
        return frame
    end

    local box = new("TextButton", {
        Size = UDim2.fromOffset(42, 22),
        Position = UDim2.new(1, -52, 0.5, -11),
        BackgroundColor3 = T.Track,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, frame)
    corner(box, 11)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = T.Text,
        BorderSizePixel = 0,
    }, box)
    corner(knob, 8)

    local on = default == true

    local function render()
        tween(box, {
            BackgroundColor3 = on and T.Accent or T.Track,
        })
        tween(knob, {
            Position = on
                and UDim2.new(1, -19, 0.5, -8)
                or UDim2.new(0, 3, 0.5, -8),
        })
    end

    local function set(state, fire)
        on = state == true
        render()
        if fire then
            callback(on)
        end
    end

    local tap = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
    }, frame)

    tap.Activated:Connect(function()
        set(not on, true)
    end)

    render()

    return frame, function()
        return on
    end, function(state, fire)
        set(state, fire == true)
    end
end

function UI:CreateToggle(parent, titleText, default, callback)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 0.65,
        BorderSizePixel = 0,
    }, parent)
    corner(frame, 5)

    label(
        frame,
        titleText,
        12,
        T.Text,
        Enum.Font.GothamMedium,
        UDim2.fromOffset(12, 0),
        UDim2.new(1, -76, 1, 0)
    )

    local box = new("TextButton", {
        Size = UDim2.fromOffset(42, 22),
        Position = UDim2.new(1, -52, 0.5, -11),
        BackgroundColor3 = T.Track,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, frame)
    corner(box, 11)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = T.Text,
        BorderSizePixel = 0,
    }, box)
    corner(knob, 8)

    local on = default == true

    local function render()
        tween(box, {
            BackgroundColor3 = on and T.Accent or T.Track,
        })
        tween(knob, {
            Position = on
                and UDim2.new(1, -19, 0.5, -8)
                or UDim2.new(0, 3, 0.5, -8),
        })
    end

    local tap = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
    }, frame)

    tap.Activated:Connect(function()
        on = not on
        render()
        if callback then callback(on) end
    end)

    render()

    return frame, function()
        return on
    end, function(state, fire)
        on = state == true
        render()
        if fire and callback then callback(on) end
    end
end

function UI:CreateButton(parent, text, callback)
    local button = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = T.Text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
    }, parent)
    corner(button, 6)
    stroke(button, T.Stroke, 1)

    button.MouseEnter:Connect(function()
        tween(button, { BackgroundColor3 = T.CardHover })
    end)
    button.MouseLeave:Connect(function()
        tween(button, { BackgroundColor3 = T.Card })
    end)

    button.Activated:Connect(function()
        if callback then
            callback(button)
        end
    end)

    return button
end

function UI:CreateSlider(parent, titleText, desc, min, max, default, suffix, callback)
    local hasDesc = type(desc) == "string" and desc ~= ""
    local frameHeight = hasDesc and 58 or 44
    local trackY = hasDesc and 44 or 30

    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, frameHeight),
        BackgroundTransparency = 1,
    }, parent)

    label(
        frame,
        titleText,
        12.5,
        T.Text,
        Enum.Font.GothamBold,
        UDim2.new(),
        UDim2.new(1, -70, 0, 16)
    )

    local valueLabel = label(
        frame,
        "",
        12,
        T.Text,
        Enum.Font.GothamBold,
        UDim2.new(1, -70, 0, 0),
        UDim2.fromOffset(70, 16)
    )
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    if hasDesc then
        label(
            frame,
            desc,
            11,
            T.Sub,
            Enum.Font.Gotham,
            UDim2.fromOffset(0, 18),
            UDim2.new(1, 0, 0, 14)
        )
    end

    local track = new("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.fromOffset(0, trackY),
        BackgroundColor3 = T.Track,
        BorderSizePixel = 0,
    }, frame)
    corner(track, 3)

    local fill = new("Frame", {
        Size = UDim2.new(),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
    }, track)
    corner(fill, 3)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = T.Text,
        BorderSizePixel = 0,
    }, track)
    corner(knob, 7)

    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.fromOffset(0, -10),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, track)

    local dragging = false

    local function set(value, fire)
        value = math.clamp(value, min, max)
        local alpha = (value - min) / math.max(max - min, 0.001)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)

        if math.abs(value - math.floor(value)) < 0.001 then
            valueLabel.Text = tostring(math.floor(value)) .. (suffix or "")
        else
            valueLabel.Text = string.format("%.1f", value) .. (suffix or "")
        end

        if fire and callback then
            callback(value)
        end
    end

    local function updateFromX(x)
        local alpha = math.clamp(
            (x - track.AbsolutePosition.X)
                / math.max(track.AbsoluteSize.X, 1),
            0,
            1
        )
        set(min + (max - min) * alpha, true)
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)

    self:Connect(
        self.Ctx.Services.UserInputService.InputChanged,
        function(input)
            if dragging
                and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateFromX(input.Position.X)
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

    set(default, false)
    return frame
end

function UI:CreateDropdown(parent, titleText, desc, options, default, callback)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, desc ~= "" and 72 or 58),
        BackgroundTransparency = 1,
    }, parent)

    label(
        frame,
        titleText,
        11,
        T.Text,
        Enum.Font.GothamBold,
        UDim2.new(),
        UDim2.new(1, 0, 0, 16)
    )

    if desc ~= "" then
        label(
            frame,
            desc,
            10,
            T.Sub,
            Enum.Font.Gotham,
            UDim2.fromOffset(0, 18),
            UDim2.new(1, 0, 0, 14)
        )
    end

    local y = desc ~= "" and 36 or 22
    local button = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        Position = UDim2.fromOffset(0, y),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Text = default or options[1] or "—",
        TextColor3 = T.Text,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
    }, frame)
    corner(button, 6)
    stroke(button, T.Stroke, 1)
    pad(button, 0, 0, 12, 12)

    local arrow = label(
        button,
        "⌄",
        12,
        T.Sub,
        Enum.Font.GothamBold,
        UDim2.new(1, -24, 0, 0),
        UDim2.fromOffset(20, 34)
    )
    arrow.TextXAlignment = Enum.TextXAlignment.Center

    local selected = button.Text
    local listFrame

    local function closeList()
        if listFrame then
            listFrame:Destroy()
            listFrame = nil
        end
    end

    local function selectValue(value)
        selected = value
        button.Text = value
        closeList()
        if callback then
            callback(value)
        end
    end

    local function openList()
        closeList()

        listFrame = new("Frame", {
            Size = UDim2.new(1, 0, 0, math.min(#options * 30 + 8, 188)),
            Position = UDim2.new(0, 0, 1, 4),
            BackgroundColor3 = T.Sidebar,
            BorderSizePixel = 0,
            ZIndex = 30,
        }, button)
        corner(listFrame, 6)
        stroke(listFrame, T.Stroke, 1)

        local scroll = new("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ZIndex = 31,
        }, listFrame)
        new("UIListLayout", {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, scroll)
        pad(scroll, 4, 4, 4, 4)

        for _, option in ipairs(options) do
            local value = option
            local item = new("TextButton", {
                Size = UDim2.new(1, -8, 0, 28),
                BackgroundColor3 = T.Card,
                BackgroundTransparency = value == selected and 0 or 0.5,
                BorderSizePixel = 0,
                Text = value,
                TextColor3 = value == selected and T.Accent or T.Text,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 32,
                AutoButtonColor = false,
            }, scroll)
            corner(item, 5)
            pad(item, 0, 0, 9, 9)

            item.Activated:Connect(function()
                selectValue(value)
            end)
        end
    end

    button.Activated:Connect(function()
        if listFrame then
            closeList()
        else
            openList()
        end
    end)

    return frame, function()
        return selected
    end, function(value, fire)
        selected = value
        button.Text = value
        if fire and callback then
            callback(value)
        end
    end, closeList
end

function UI:CreateSearchRow(parent, placeholder, onSearch)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
    }, parent)

    local box = new("TextBox", {
        Size = UDim2.new(1, -94, 1, 0),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        PlaceholderText = placeholder,
        PlaceholderColor3 = T.Sub,
        Text = "",
        TextColor3 = T.Text,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, frame)
    corner(box, 6)
    stroke(box, T.Stroke, 1)
    pad(box, 0, 0, 12, 12)

    local search = new("TextButton", {
        Size = UDim2.fromOffset(86, 40),
        Position = UDim2.new(1, -86, 0, 0),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        Text = "Search",
        TextColor3 = T.Ink,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
    }, frame)
    corner(search, 7)

    search.Activated:Connect(function()
        if onSearch then
            onSearch(box.Text)
        end
    end)

    return box
end

function UI:CreatePage(name)
    local page = new("Frame", {
        Name = name,
        Visible = false,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -94),
        Position = UDim2.new(0, 0, 0, 94),
    }, self.Right)

    local columns = {}

    for index = 1, 2 do
        local column = new("ScrollingFrame", {
            Size = UDim2.new(0.5, -24, 1, -12),
            Position = UDim2.new(
                0.5 * (index - 1),
                index == 1 and 16 or 8,
                0,
                0
            ),
            BackgroundColor3 = T.Card,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = T.AccentSoft,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
        }, page)
        corner(column, 7)
        stroke(column, T.Stroke, 1)
        new("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, column)
        pad(column, 8, 16, 8, 8)
        columns[index] = column
    end

    self.Pages[name] = {
        Frame = page,
        Left = columns[1],
        Right = columns[2],
    }

    return columns[1], columns[2]
end

function UI:CreatePlaceholderPage(name, message)
    local left, right = self:CreatePage(name)
    self:CreateSection(left, name)
    local text = label(
        left,
        message or "ระบบนี้ยังไม่ได้ย้ายเข้า module ใหม่",
        12,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 54)
    )
    text.TextWrapped = true

    self:CreateSection(right, "Status")
    local state = label(
        right,
        "Legacy system pending migration",
        11,
        T.Gold,
        Enum.Font.Code,
        nil,
        UDim2.new(1, 0, 0, 34)
    )
    state.TextWrapped = true
end

function UI:BuildMobFarmPage()
    local farm = self:Farm()
    local combat = self:Combat()
    local left, right = self:CreatePage("Mob Farm")

    local status = label(
        left,
        "Ready",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 16)
    )

    local selectedMob
    local mobList =
        farm.farmListMobTypes
        and farm.farmListMobTypes()
        or {}

    selectedMob = farm.MobName or mobList[1]
    if selectedMob then
        farm:SetMob(selectedMob)
    end

    local _, _, farmSetter = self:CreateSection(
        left,
        "Mob farm (on/off)",
        farm.Enabled and not farm.BossEnabled,
        function(on)
            if on then
                if not selectedMob then
                    status.Text = "Select a mob first"
                    status.TextColor3 = T.Danger
                    return
                end

                farm:StartMob(selectedMob)
                local count = 0
                if farm.farmFindMobsByName then
                    count = #farm.farmFindMobsByName(selectedMob)
                end
                status.Text = string.format(
                    "Farming %s (%d found)",
                    selectedMob,
                    count
                )
                status.TextColor3 = T.Mint
            else
                if farm.Enabled and not farm.BossEnabled then
                    farm:Stop()
                end
                status.Text = "Mob farm stopped"
                status.TextColor3 = T.Sub
            end
        end
    )

    local _, getMob, setMob = self:CreateDropdown(
        left,
        "Select mob",
        "",
        mobList,
        selectedMob,
        function(value)
            selectedMob = value
            farm:SetMob(value)
            status.Text = "Selected " .. value
            status.TextColor3 = T.Sub
        end
    )

    self:CreateSearchRow(left, "Search mob...", function(query)
        query = tostring(query or ""):lower()
        if query == "" then return end

        for _, name in ipairs(mobList) do
            if name:lower():find(query, 1, true) then
                selectedMob = name
                farm:SetMob(name)
                setMob(name, false)
                status.Text = "Selected " .. name
                status.TextColor3 = T.Mint
                return
            end
        end

        status.Text = "Mob not found"
        status.TextColor3 = T.Danger
    end)

    local weaponOptions = {
        "ช่อง 1",
        "ช่อง 2",
        "ช่อง 3",
        "ช่อง 4",
        "ช่อง 5",
    }

    self:CreateDropdown(
        left,
        "Farm weapon",
        "Use Item_Equip slot 1-5",
        weaponOptions,
        farm.SelectedWeapon or "ช่อง 1",
        function(value)
            farm.SelectedWeapon = value
            farm._lastHotbarSelection = nil
            farm._lastHotbarCharacter = nil
            combat.EquipReadyAt = 0
            status.Text = "Weapon: " .. value
            status.TextColor3 = T.Mint
        end
    )

    self:CreateToggle(
        left,
        "Auto quest",
        farm.AutoQuest == true,
        function(on)
            farm.AutoQuest = on
            status.Text = on
                and "Auto quest UI enabled • quest module pending"
                or "Auto quest disabled"
            status.TextColor3 = on and T.Gold or T.Sub
        end
    )

    self:CreateButton(
        left,
        "▣ รับเควส Mitsu Lv115",
        function()
            status.Text = "Mitsu quest module has not been migrated yet"
            status.TextColor3 = T.Gold
        end
    )

    self:CreateSlider(
        right,
        "Mob Hitbox Size",
        "ขนาด hitbox ของมอนที่ล็อก",
        5,
        40,
        farm.Hitbox or 18,
        " st",
        function(value)
            farm.Hitbox = value
        end
    )

    farm.PlayerAttackHitbox = farm.PlayerAttackHitbox or 30
    self:CreateSlider(
        right,
        "Player Attack Hitbox",
        "ขยายพื้นที่ตีของ BasePart ทุกชิ้นในอาวุธที่ถืออยู่",
        5,
        100,
        farm.PlayerAttackHitbox,
        " st",
        function(value)
            farm.PlayerAttackHitbox = value
        end
    )

    self:CreateSlider(
        right,
        "Attack range",
        "Attack trigger range; server validates hits",
        5,
        25,
        farm.AttackRange or 12,
        " st",
        function(value)
            farm.AttackRange = value
        end
    )

    self:CreateSlider(
        right,
        "Height Above Head",
        "ลอยติดหัวมอน • ไม่วาปหนีเมื่อโดนตี",
        1,
        8,
        farm.HeadHeight or 3,
        " st",
        function(value)
            farm.HeadHeight = value
        end
    )

    local combatInfo = label(
        right,
        "โจมตีแล้วลอยติดหัวมอนและตีต่อ",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 24)
    )
    combatInfo.TextWrapped = true

    local perf = label(
        right,
        "FPS / การโจมตี • รอเปิด Auto Attack",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 30)
    )
    perf.TextWrapped = true

    self:CreateToggle(
        right,
        "Fast Attack",
        farm.FastAttack == true,
        function(on)
            farm.FastAttack = on
            combat.PreferredDriver = nil
            combat:Release()
            combat:ResetProgress()
            combat.NextAttackAt = 0

            if on and farm.BypassComboGate then
                combat:BindGameComboGate()
            else
                combat:UnbindGameComboGate()
            end
        end
    )

    self:CreateToggle(
        right,
        "Continuous Combo Reset",
        farm.BypassComboGate == true,
        function(on)
            farm.BypassComboGate = on
            if on then
                combat:BindGameComboGate()
                combat.NextAttackAt = 0
            else
                combat:UnbindGameComboGate()
            end
        end
    )

    self:CreateSlider(
        right,
        "Attack Interval",
        "1 request ต่อรอบโจมตี",
        20,
        200,
        (farm.AttackInterval or 0.06) * 1000,
        " ms",
        function(value)
            farm.AttackInterval = value / 1000
            combat.AdaptiveInterval = farm.AttackInterval
        end
    )

    self.MobFarmSetter = farmSetter
    self.MobDropdownGetter = getMob
end

function UI:BuildBossFarmPage()
    local farm = self:Farm()
    local boss = self:Boss()
    local left, right = self:CreatePage("Boss Farm")

    local status = label(
        left,
        "Select bosses to farm",
        11,
        T.Gold,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 18)
    )

    local bossList = boss.Names or {}
    local selected = bossList[1]

    self:CreateDropdown(
        left,
        "Selected boss",
        "ใช้เลือกบอสเดี่ยว / ดูรายชื่อ",
        bossList,
        selected,
        function(value)
            selected = value
            farm:SetBoss(value)
            status.Text = "Selected " .. value
            status.TextColor3 = T.Gold
        end
    )

    self:CreateButton(left, "▶ Start selected bosses", function()
        local ok, err = boss:StartSelected()
        if ok then
            status.Text = "Boss farm started"
            status.TextColor3 = T.Mint
        else
            status.Text = tostring(err)
            status.TextColor3 = T.Danger
        end
    end)

    self:CreateButton(left, "■ Stop Boss Farm", function()
        boss:Stop()
        status.Text = "Boss farm stopped"
        status.TextColor3 = T.Sub
    end)

    self:CreateButton(left, "Clear Selection", function()
        boss:ClearSelection()
        for _, setter in pairs(self.BossToggleSetters or {}) do
            setter(false, false)
        end
        status.Text = "Selection cleared"
        status.TextColor3 = T.Sub
    end)

    self:CreateSection(right, "Farm Boss All")
    self.BossToggleSetters = {}

    for _, name in ipairs(bossList) do
        local bossName = name
        local _, _, setter = self:CreateToggle(
            right,
            bossName,
            boss.Selected[bossName] == true,
            function(on)
                boss:SetSelected(bossName, on)
                status.Text = string.format(
                    "Selected %d boss(es)",
                    #boss.Order
                )
                status.TextColor3 =
                    #boss.Order > 0
                    and T.Mint
                    or T.Sub
            end
        )
        self.BossToggleSetters[bossName] = setter
    end
end

function UI:BuildCombatPage()
    local farm = self:Farm()
    local combat = self:Combat()
    local left, right = self:CreatePage("Combat")

    self:CreateSection(left, "Combat")
    self:CreateToggle(
        left,
        "Auto Attack",
        farm.AutoAttack == true,
        function(on)
            farm.AutoAttack = on
            if not on then
                combat:ReleaseAttack()
            end
        end
    )

    self:CreateToggle(
        left,
        "Fast Attack",
        farm.FastAttack == true,
        function(on)
            farm.FastAttack = on
            combat:ResetProgress()
        end
    )

    self:CreateToggle(
        left,
        "Continuous Combo Reset",
        farm.BypassComboGate == true,
        function(on)
            farm.BypassComboGate = on
            if on then
                combat:BindGameComboGate()
            else
                combat:UnbindGameComboGate()
            end
        end
    )

    self:CreateSection(right, "Attack Settings")
    self:CreateSlider(
        right,
        "Attack Interval",
        "ความถี่ในการส่งคำสั่งโจมตี",
        20,
        200,
        (farm.AttackInterval or 0.06) * 1000,
        " ms",
        function(value)
            farm.AttackInterval = value / 1000
            combat.AdaptiveInterval = farm.AttackInterval
        end
    )

    self:CreateSlider(
        right,
        "Attack Range",
        "ระยะที่จะเริ่มโจมตีเป้าหมาย",
        5,
        25,
        farm.AttackRange or 12,
        " st",
        function(value)
            farm.AttackRange = value
        end
    )
end

function UI:BuildSkillPage()
    local skill = self:Skill()
    local left, right = self:CreatePage("Skill")

    self:CreateSection(left, "Auto Skills")
    self:CreateToggle(
        left,
        "Auto Skills",
        skill.Enabled == true,
        function(on)
            skill:SetEnabled(on)
        end
    )

    local side = left

    for index, key in ipairs(skill.Keys or {}) do
        local skillKey = key
        local setting = skill.Settings[skillKey]

        if index > math.ceil(#skill.Keys / 2) then
            side = right
        end

        self:CreateToggle(
            side,
            "Skill " .. skillKey,
            setting and setting.Enabled == true,
            function(on)
                skill:SetKeyEnabled(skillKey, on)
            end
        )

        self:CreateSlider(
            side,
            "Interval " .. skillKey,
            "Repeat interval",
            0.1,
            10,
            setting and setting.Interval or 1,
            " s",
            function(value)
                skill:SetInterval(skillKey, value)
            end
        )
    end
end

function UI:BuildPages()
    self:BuildMobFarmPage()
    self:BuildBossFarmPage()
    self:CreatePlaceholderPage(
        "Quests",
        "Quest UI เดิมจะกลับมาเมื่อย้าย Quest module จาก hello.txt"
    )
    self:CreatePlaceholderPage(
        "Dungeon",
        "Dungeon system ยังอยู่ใน hello.txt และยังไม่ได้ย้าย"
    )
    self:CreatePlaceholderPage(
        "Raids",
        "Raid Chest system ยังอยู่ใน hello.txt และยังไม่ได้ย้าย"
    )
    self:CreatePlaceholderPage(
        "Status",
        "Modular core is running"
    )
    self:CreatePlaceholderPage(
        "World",
        "World tools ยังไม่ได้ย้ายเข้า module ใหม่"
    )
    self:CreatePlaceholderPage(
        "Teleport",
        "Teleport system ยังไม่ได้ย้ายเข้า module ใหม่"
    )
    self:CreatePlaceholderPage(
        "Player",
        "Player Mods ยังไม่ได้ย้ายเข้า module ใหม่"
    )
    self:BuildCombatPage()
    self:CreatePlaceholderPage(
        "Visuals",
        "Visual systems ยังไม่ได้ย้ายเข้า module ใหม่"
    )
    self:BuildSkillPage()
    self:CreatePlaceholderPage(
        "Settings",
        "Settings module จะย้ายภายหลัง"
    )
end

function UI:HideAllPages()
    for _, data in pairs(self.Pages) do
        data.Frame.Visible = false
    end
end

function UI:SelectSubTab(name)
    self:HideAllPages()

    local page = self.Pages[name]
    if page then
        page.Frame.Visible = true
        page.Left.CanvasPosition = Vector2.zero
        page.Right.CanvasPosition = Vector2.zero
    end

    self.ActiveSubTab = name

    for tabName, data in pairs(self.TabButtons or {}) do
        local active = tabName == name
        tween(data.Button, {
            BackgroundTransparency = active and 0 or 1,
        })
        tween(data.Label, {
            TextColor3 = active and T.Accent or T.Sub,
        })
        tween(data.Underline, {
            BackgroundTransparency = active and 0 or 1,
        })
    end
end

function UI:MenuTabs(menuName)
    if menuName == "Farm" then
        return {
            "Mob Farm",
            "Boss Farm",
            "Quests",
            "Dungeon",
            "Raids",
            "Status",
        }
    end

    if menuName == "World" then
        return { "World", "Teleport" }
    end

    if menuName == "Player" then
        return { "Player", "Combat", "Visuals", "Skill" }
    end

    return { "Settings" }
end

function UI:BuildTabs(menuName)
    for _, child in ipairs(self.Tabs:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    self.TabButtons = {}

    local tabs = self:MenuTabs(menuName)

    for index, name in ipairs(tabs) do
        local button = new("TextButton", {
            Size = UDim2.fromOffset(78, 31),
            BackgroundColor3 = T.Card,
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
        }, self.Tabs)
        corner(button, 8)

        local textLabel = label(
            button,
            name,
            12,
            T.Sub,
            Enum.Font.GothamMedium,
            nil,
            UDim2.fromScale(1, 1)
        )
        textLabel.TextXAlignment = Enum.TextXAlignment.Center

        local underline = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -1),
            Size = UDim2.new(1, -28, 0, 2),
            BackgroundColor3 = T.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, button)
        corner(underline, 2)

        self.TabButtons[name] = {
            Button = button,
            Label = textLabel,
            Underline = underline,
        }

        button.Activated:Connect(function()
            self:SelectSubTab(name)
        end)

        if index == 1 then
            task.defer(function()
                self:SelectSubTab(name)
            end)
        end
    end
end

function UI:SelectMenu(menuName)
    self.ActiveMenu = menuName
    self:BuildTabs(menuName)

    for name, data in pairs(self.NavButtons) do
        local active = name == menuName
        tween(data.Button, {
            BackgroundColor3 = active and T.AccentSoft or T.Sidebar,
        })
        tween(data.Icon, {
            TextColor3 = active and T.Accent or T.Sub,
        })
        tween(data.Label, {
            TextColor3 = active and T.Text or T.Sub,
        })
    end
end

function UI:BuildSidebar()
    local player = self.Ctx.Player

    local avatar = new("ImageLabel", {
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.fromOffset(25, 14),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Image =
            "rbxthumb://type=AvatarHeadShot&id="
            .. tostring(player.UserId)
            .. "&w=150&h=150",
    }, self.Sidebar)
    corner(avatar, 15)
    stroke(avatar, T.Accent, 1)

    local brand = label(
        self.Sidebar,
        "M A Z X",
        9,
        T.Accent,
        Enum.Font.Code,
        UDim2.fromOffset(19, 52),
        UDim2.fromOffset(58, 16)
    )
    brand.TextXAlignment = Enum.TextXAlignment.Center

    new("Frame", {
        Size = UDim2.new(1, -24, 0, 1),
        Position = UDim2.fromOffset(12, 74),
        BackgroundColor3 = T.Stroke,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
    }, self.Sidebar)

    local nav = new("Frame", {
        Size = UDim2.new(1, 0, 1, -112),
        Position = UDim2.fromOffset(0, 84),
        BackgroundTransparency = 1,
    }, self.Sidebar)

    new("UIListLayout", {
        Padding = UDim.new(0, 4),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, nav)

    local entries = {
        { "Farm", "⚒" },
        { "World", "⊕" },
        { "Player", "♟" },
        { "Setting", "☷" },
    }

    for _, entry in ipairs(entries) do
        local menuName = entry[1]
        local iconText = entry[2]

        local button = new("TextButton", {
            Size = UDim2.fromOffset(76, 52),
            BackgroundColor3 = T.Sidebar,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, nav)
        corner(button, 7)

        local icon = label(
            button,
            iconText,
            21,
            T.Sub,
            Enum.Font.GothamBold,
            UDim2.fromOffset(0, 4),
            UDim2.new(1, 0, 0, 24)
        )
        icon.TextXAlignment = Enum.TextXAlignment.Center

        local textLabel = label(
            button,
            menuName,
            10,
            T.Sub,
            Enum.Font.Gotham,
            UDim2.fromOffset(0, 28),
            UDim2.new(1, 0, 0, 18)
        )
        textLabel.TextXAlignment = Enum.TextXAlignment.Center

        self.NavButtons[menuName] = {
            Button = button,
            Icon = icon,
            Label = textLabel,
        }

        button.Activated:Connect(function()
            self:SelectMenu(menuName)
        end)
    end

    local hint = label(
        self.Sidebar,
        "RightShift",
        8,
        T.Sub,
        Enum.Font.Code,
        UDim2.new(0, 14, 1, -28),
        UDim2.new(1, -28, 0, 16)
    )
    hint.TextXAlignment = Enum.TextXAlignment.Center
end

function UI:BuildTop()
    self.Search = new("Frame", {
        Size = UDim2.fromOffset(192, 34),
        Position = UDim2.fromOffset(16, 14),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
    }, self.Top)
    corner(self.Search, 6)
    stroke(self.Search, T.Stroke, 1)

    local searchIcon = label(
        self.Search,
        "⌕",
        12,
        T.Sub,
        Enum.Font.GothamBold,
        UDim2.fromOffset(10, 0),
        UDim2.fromOffset(18, 34)
    )
    searchIcon.TextXAlignment = Enum.TextXAlignment.Center

    local searchBox = new("TextBox", {
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Search",
        PlaceholderColor3 = T.Sub,
        TextColor3 = T.Text,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(30, 0),
        Size = UDim2.new(1, -38, 1, 0),
        ClearTextOnFocus = false,
    }, self.Search)

    local tech = label(
        self.Top,
        "CONTROL  //  PANEL",
        10,
        T.Sub,
        Enum.Font.Code,
        UDim2.fromOffset(222, 15),
        UDim2.fromOffset(150, 30)
    )

    local hub = label(
        self.Top,
        "Mazxhub",
        16,
        T.Accent,
        Enum.Font.GothamBold,
        UDim2.new(1, -176, 0, 15),
        UDim2.fromOffset(120, 30)
    )
    hub.TextXAlignment = Enum.TextXAlignment.Right

    local close = new("TextButton", {
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.new(1, -40, 0, 13),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Text = "✕",
        TextColor3 = T.Sub,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
    }, self.Top)
    corner(close, 8)

    close.MouseEnter:Connect(function()
        tween(close, {
            BackgroundColor3 = T.Danger,
            TextColor3 = T.Text,
        })
    end)

    close.MouseLeave:Connect(function()
        tween(close, {
            BackgroundColor3 = T.Card,
            TextColor3 = T.Sub,
        })
    end)

    close.Activated:Connect(function()
        self:SetOpen(false)
    end)

    self.Tabs = new("ScrollingFrame", {
        Size = UDim2.new(1, -32, 0, 34),
        Position = UDim2.new(0, 16, 0, 54),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = T.AccentSoft,
    }, self.Top)

    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, self.Tabs)

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = searchBox.Text:lower()
        local page = self.Pages[self.ActiveSubTab]
        if not page then return end

        for _, column in ipairs({ page.Left, page.Right }) do
            for _, child in ipairs(column:GetChildren()) do
                if child:IsA("GuiObject")
                    and not child:IsA("UIListLayout")
                    and not child:IsA("UIPadding") then

                    if query == "" then
                        child.Visible = true
                    else
                        local haystack = ""
                        for _, node in ipairs(child:GetDescendants()) do
                            if node:IsA("TextLabel")
                                or node:IsA("TextButton")
                                or node:IsA("TextBox") then
                                haystack = haystack .. " " .. tostring(node.Text)
                            end
                        end
                        child.Visible =
                            haystack:lower():find(query, 1, true) ~= nil
                    end
                end
            end
        end
    end)

    self.DragHandle = new("Frame", {
        Size = UDim2.new(1, -250, 0, 48),
        Position = UDim2.fromOffset(212, 0),
        BackgroundTransparency = 1,
        Active = true,
    }, self.Top)

    tech.ZIndex = 2
    hub.ZIndex = 2
end

function UI:BindDrag()
    local inputService = self.Ctx.Services.UserInputService
    local dragging = false
    local startMouse
    local startPosition

    self.DragHandle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        dragging = true
        startMouse = input.Position
        startPosition = self.Main.Position
    end)

    self:Connect(inputService.InputChanged, function(input)
        if not dragging
            or input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local delta = input.Position - startMouse
        self.Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)

    self:Connect(inputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

function UI:Init(ctx)
    self.Ctx = ctx
    self.Pages = {}
    self.NavButtons = {}
    self.Connections = {}
    self.TabButtons = {}
    self.BossToggleSetters = {}
end

function UI:Start()
    local playerGui =
        self.Ctx.Player:WaitForChild("PlayerGui")

    local old = playerGui:FindFirstChild("MazxhubModulesUI")
    if old then old:Destroy() end

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
        BorderSizePixel = 0,
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
    stroke(self.Fab, T.Accent, 1.5)

    self.Main = new("Frame", {
        Size = UDim2.fromOffset(740, 500),
        Position = UDim2.new(0.5, -370, 0.5, -250),
        BackgroundColor3 = T.Bg,
        BorderSizePixel = 0,
        Visible = false,
    }, self.Surface)
    corner(self.Main, 8)
    stroke(self.Main, T.Stroke, 1)

    self.Sidebar = new("Frame", {
        Size = UDim2.new(0, 96, 1, 0),
        BackgroundColor3 = T.Sidebar,
        BorderSizePixel = 0,
    }, self.Main)

    new("Frame", {
        Size = UDim2.new(0, 1, 1, -20),
        Position = UDim2.new(1, 0, 0, 10),
        BackgroundColor3 = T.Stroke,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
    }, self.Sidebar)

    self.Right = new("Frame", {
        Size = UDim2.new(1, -96, 1, 0),
        Position = UDim2.fromOffset(96, 0),
        BackgroundTransparency = 1,
    }, self.Main)

    self.Top = new("Frame", {
        Size = UDim2.new(1, 0, 0, 94),
        BackgroundTransparency = 1,
    }, self.Right)

    self:BuildSidebar()
    self:BuildTop()
    self:BuildPages()
    self:BindDrag()

    self.Fab.Activated:Connect(function()
        self:SetOpen(not self.IsOpen)
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

    self:SelectMenu("Farm")
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
