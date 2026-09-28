-- MazxhubModules/ui.lua
-- MazaSpace: dark / soft-red presentation, original module callbacks preserved.
-- Backend actions are routed to modular Farm/Boss/Combat/Skill modules.

local UI = {
    Pages = {},
    NavButtons = {},
    Connections = {},
    IsOpen = false,
    ActiveMenu = "Farm",
    ActiveSubTab = nil,
    AnimationsEnabled = true,
}

local TweenService = game:GetService("TweenService")

local T = {
    Bg = Color3.fromRGB(18, 18, 21),
    Sidebar = Color3.fromRGB(19, 19, 22),
    Card = Color3.fromRGB(25, 25, 29),
    CardHover = Color3.fromRGB(37, 32, 37),
    Stroke = Color3.fromRGB(54, 49, 55),
    Track = Color3.fromRGB(33, 32, 37),
    Text = Color3.fromRGB(239, 234, 237),
    Sub = Color3.fromRGB(160, 153, 160),
    Accent = Color3.fromRGB(235, 117, 130),
    AccentSoft = Color3.fromRGB(47, 31, 37),
    Ink = Color3.fromRGB(30, 16, 22),
    Mint = Color3.fromRGB(235, 145, 155),
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
    local c = parent:FindFirstChildOfClass("UICorner") or new("UICorner", {}, parent)
    c.CornerRadius = UDim.new(0, radius or 4)
    return c
end

local function stroke(parent, color, thickness)
    return new("UIStroke", {
        Color = color or T.Stroke,
        Thickness = thickness or 1,
        Transparency = 0.05,
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
    if UI.AnimationsEnabled == false then
        for key, value in pairs(props) do
            object[key] = value
        end
        return
    end

    TweenService:Create(object, TI, props):Play()
end

local IconPaths = {
    M={{{3,21},{6,3},{12,12},{20,3},{17,21}},{{3,21},{8,21},{9,13},{12,17},{17,12}},{{7,3},{11,8}},{{17,21},{21,21}}},
    Home={{{3,11},{12,3},{21,11},{21,21},{15,21},{15,14},{9,14},{9,21},{3,21},{3,11}}},
    Main={{{4,3},{16,15}},{{3,3},{3,8},{13,18},{18,13},{8,3},{3,3}},{{15,16},{21,22}},{{3,21},{9,15}},{{15,9},{21,3}},{{17,3},{21,3},{21,7}}},
    Farm={{{5,21},{19,3}},{{8,17},{3,13},{6,10},{11,13}},{{12,12},{8,8},{11,5},{15,8}},{{14,8},{16,2},{21,2},{21,7},{18,10}},{{10,16},{15,16},{19,12},{16,10}}},
    Dungeon={{{3,21},{3,10},{7,10},{7,14},{10,14},{10,6},{14,6},{14,14},{17,14},{17,10},{21,10},{21,21},{3,21}},{{10,21},{10,17},{14,17},{14,21}},{{5,10},{5,5}},{{19,10},{19,5}}},
    Visuals={{{2,12},{6,7},{12,5},{18,7},{22,12},{18,17},{12,19},{6,17},{2,12}}},
    Player={{{5,22},{5,18},{7,15},{17,15},{19,18},{19,22}}},
    Webhook={{{4,18},{6,15},{6,9},{8,5},{12,3},{16,5},{18,9},{18,15},{20,18},{4,18}},{{10,21},{14,21}}},
    Config={{{9,2},{15,2},{16,6},{20,6},{22,11},{19,14},{20,18},{15,21},{12,18},{8,21},{4,18},{5,14},{2,11},{4,6},{8,6},{9,2}}},
    Combat={{{12,1},{12,7}},{{12,17},{12,23}},{{1,12},{7,12}},{{17,12},{23,12}}},
    Dialogue={{{3,3},{21,3},{21,18},{8,18},{3,22},{3,3}}},
    Defense={{{12,2},{21,6},{20,14},{17,19},{12,22},{7,19},{4,14},{3,6},{12,2}}},
    Training={{{2,8},{5,5},{9,9},{15,3},{19,7},{17,9},{21,13},{18,16},{14,12},{8,18},{4,14},{6,12},{2,8}}},
    Instakill={{{14,2},{4,13},{10,13},{8,22},{21,9},{14,9},{14,2}}},
    Lock={{{5,10},{19,10},{19,22},{5,22},{5,10}},{{8,10},{8,6},{10,3},{14,3},{16,6},{16,10}}},
    Market={{{3,9},{5,3},{19,3},{21,9},{18,12},{15,9},{12,12},{9,9},{6,12},{3,9}},{{5,12},{5,21},{19,21},{19,12}},{{10,21},{10,16},{15,16},{15,21}}},
    Location={{{12,23},{5,15},{3,10},{5,5},{9,2},{15,2},{19,5},{21,10},{19,15},{12,23}}},
    Performance={{{3,19},{2,13},{4,7},{8,3},{16,3},{20,7},{22,13},{21,19}},{{12,15},{17,8}}},
    Muzan={{{18,3},{12,4},{9,8},{9,13},{13,17},{18,17},{22,14},{20,19},{16,22},{10,22},{5,19},{2,14},{3,8},{7,3},{12,2}}},
    Menu={{{2,4},{22,4},{22,20},{2,20},{2,4}},{{6,9},{7,9}},{{11,9},{12,9}},{{16,9},{18,9}},{{6,13},{7,13}},{{11,13},{12,13}},{{16,13},{18,13}},{{7,17},{17,17}}},
    List={{{8,5},{22,5}},{{8,12},{22,12}},{{8,19},{22,19}},{{2,5},{3,5}},{{2,12},{3,12}},{{2,19},{3,19}}},
    Folder={{{2,20},{2,4},{9,4},{12,7},{22,7},{22,20},{2,20}}},
    Themes={{{4,15},{15,4},{20,9},{9,20},{4,15}},{{15,4},{18,1},{23,6},{20,9}},{{4,15},{2,22},{9,20}}},
    Search={{{15,15},{21,21}}},
    Chevron={{{5,8},{12,15},{19,8}}},
    Move={{{12,2},{12,22}},{{2,12},{22,12}},{{8,6},{12,2},{16,6}},{{8,18},{12,22},{16,18}},{{6,8},{2,12},{6,16}},{{18,8},{22,12},{18,16}}},
}
local function icon(parent, name, position, size, color)
    local canvas=new("Frame",{Name="Icon_"..name,BackgroundTransparency=1,Size=UDim2.fromOffset(size,size),Position=position},parent)
    local ink=color or T.Accent
    local function line(x1,y1,x2,y2)
        local dx,dy=(x2-x1)*size/24,(y2-y1)*size/24
        local segment=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset((x1+x2)*size/48,(y1+y2)*size/48),
            Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy)+.5,1.6),Rotation=math.deg(math.atan2(dy,dx)),BackgroundColor3=ink,BorderSizePixel=0},canvas)
        corner(segment,1)
    end
    local function ring(x,y,r)
        for i=0,27 do
            local a,b=i*math.pi/14,(i+1)*math.pi/14
            line(x+math.cos(a)*r,y+math.sin(a)*r,x+math.cos(b)*r,y+math.sin(b)*r)
        end
    end
    for _,path in ipairs(IconPaths[name] or IconPaths.List) do
        for i=2,#path do line(path[i-1][1],path[i-1][2],path[i][1],path[i][2]) end
    end
    if name=="Search" then ring(10,10,6) end
    if name=="Player" then ring(12,7,4) end
    if name=="Visuals" or name=="Config" then ring(12,12,3.5) end
    if name=="Combat" then ring(12,12,8.5) end
    if name=="Location" then ring(12,10,3) end
    return canvas
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

function UI:Player()
    return self.Ctx.Modules.Player
end

function UI:Teleport()
    return self.Ctx.Modules.Teleport
end

function UI:Quest()
    return self.Ctx.Modules.Quest
end

function UI:Dungeon()
    return self.Ctx.Modules.Dungeon
end

function UI:Raid()
    return self.Ctx.Modules.Raid
end

function UI:Loot()
    return self.Ctx.Modules.Loot
end

function UI:World()
    return self.Ctx.Modules.World
end

function UI:Visuals()
    return self.Ctx.Modules.Visuals
end

function UI:Aimbot()
    return self.Ctx.Modules.Aimbot
end

function UI:Settings()
    return self.Ctx.Modules.Settings
end

function UI:CloseDropdown()
    if self.ActiveDropdownClose then
        local close = self.ActiveDropdownClose
        self.ActiveDropdownClose = nil
        pcall(close)
    end
end

function UI:SetOpen(state)
    self.IsOpen = state == true

    if not self.IsOpen then
        self:CloseDropdown()
    elseif self.Main then
        self:Layout(false)
    end

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
    corner(frame, 3)
    frame:SetAttribute("MazaSection", titleText)
    frame.BackgroundColor3 = T.Card
    frame.BackgroundTransparency = 0

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
    dot:Destroy()
    icon(frame,"List",UDim2.fromOffset(7,9),17,T.Accent)
    title.Position=UDim2.fromOffset(31,0)
    title.Font=Enum.Font.Code
    title.Size=UDim2.new(1,callback and -85 or -60,1,0)

    if not callback then
        return frame
    end

    local box = new("TextButton", {
        Size = UDim2.fromOffset(34, 20),
        Position = UDim2.new(1, -42, 0.5, -10),
        BackgroundColor3 = T.Track,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, frame)
    corner(box, 11)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.new(0, 3, 0.5, -7),
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
                and UDim2.new(1, -17, 0.5, -7)
                or UDim2.new(0, 3, 0.5, -7),
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
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 1,
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
        Size = UDim2.fromOffset(34, 20),
        Position = UDim2.new(1, -42, 0.5, -10),
        BackgroundColor3 = T.Track,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, frame)
    corner(box, 11)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.new(0, 3, 0.5, -7),
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
                and UDim2.new(1, -17, 0.5, -7)
                or UDim2.new(0, 3, 0.5, -7),
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
    local trackY = hasDesc and 36 or 24

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
        Size = UDim2.new(1, 0, 0, 17),
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
    knob.Visible=false
    valueLabel.Parent=track
    valueLabel.Position=UDim2.fromOffset(0,0)
    valueLabel.Size=UDim2.fromScale(1,1)
    valueLabel.TextXAlignment=Enum.TextXAlignment.Center
    valueLabel.Font=Enum.Font.Code
    valueLabel.ZIndex=3
    stroke(track,T.Stroke,1)

    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.fromOffset(0, -4),
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
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = input
            updateFromX(input.Position.X)
        end
    end)

    self:Connect(
        self.Ctx.Services.UserInputService.InputChanged,
        function(input)
            if dragging
                and (input.UserInputType == Enum.UserInputType.MouseMovement or input == dragging) then
                updateFromX(input.Position.X)
            end
        end
    )

    self:Connect(
        self.Ctx.Services.UserInputService.InputEnded,
        function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input == dragging then
                dragging = false
            end
        end
    )

    set(default, false)
    return frame
end

function UI:CreateDropdown(parent, titleText, desc, options, default, callback)
    options=options or {}
    local hasDesc=type(desc)=="string" and desc~=""
    local y=hasDesc and 36 or 22
    local frame=new("Frame",{Size=UDim2.new(1,0,0,y+29),BackgroundTransparency=1},parent)
    label(frame,titleText,12,T.Text,Enum.Font.Code,nil,UDim2.new(1,0,0,18))
    if hasDesc then label(frame,desc,10,T.Sub,Enum.Font.Gotham,UDim2.fromOffset(0,18),UDim2.new(1,0,0,16)) end
    local selected=default or options[1]
    local button=new("TextButton",{Size=UDim2.new(1,0,0,26),Position=UDim2.fromOffset(0,y),
        BackgroundColor3=T.Card,BorderSizePixel=0,Text=tostring(selected or "---"),TextColor3=T.Text,
        Font=Enum.Font.Code,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,AutoButtonColor=false},frame)
    corner(button,3); stroke(button); pad(button,0,0,7,25)
    local arrow=icon(button,"Chevron",UDim2.new(1,-15,0,5),14,T.Sub)
    local listFrame
    local function closeList()
        if listFrame then listFrame:Destroy(); listFrame=nil end
        arrow.Rotation=0
        if self.ActiveDropdownClose==closeList then self.ActiveDropdownClose=nil end
    end
    local function openList()
        self:CloseDropdown()
        local mainPos,mainSize=self.Main.AbsolutePosition,self.Main.AbsoluteSize
        local pos=button.AbsolutePosition
        local height=math.min(238,math.max(90,#options*28+44),math.max(70,mainSize.Y-16))
        local width=math.min(button.AbsoluteSize.X,mainSize.X-16)
        local x=math.clamp(pos.X-mainPos.X,8,math.max(8,mainSize.X-width-8))
        local yPos=pos.Y-mainPos.Y+button.AbsoluteSize.Y+3
        if yPos+height>mainSize.Y-8 then yPos=pos.Y-mainPos.Y-height-3 end
        yPos=math.clamp(yPos,8,math.max(8,mainSize.Y-height-8))
        listFrame=new("Frame",{Name="DropdownOverlay",Size=UDim2.fromOffset(width,height),Position=UDim2.fromOffset(x,yPos),
            BackgroundColor3=T.Sidebar,BorderSizePixel=0,ZIndex=100},self.Main)
        corner(listFrame,4); stroke(listFrame)
        local search=new("TextBox",{Size=UDim2.new(1,-12,0,28),Position=UDim2.fromOffset(6,6),Text="",PlaceholderText="Search...",
            ClearTextOnFocus=false,BackgroundColor3=T.Card,BorderSizePixel=0,TextColor3=T.Text,PlaceholderColor3=T.Sub,
            Font=Enum.Font.Code,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=101},listFrame)
        corner(search,3); pad(search,0,0,7,7)
        local scroll=new("ScrollingFrame",{Size=UDim2.new(1,-10,1,-42),Position=UDim2.fromOffset(5,38),BackgroundTransparency=1,
            BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,ScrollBarImageColor3=T.Accent,ZIndex=101},listFrame)
        new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,1)},scroll)
        local entries={}
        for i,value in ipairs(options) do
            local item=new("TextButton",{Size=UDim2.new(1,-4,0,26),LayoutOrder=i,BackgroundColor3=T.AccentSoft,
                BackgroundTransparency=value==selected and 0 or 1,BorderSizePixel=0,Text=tostring(value),TextColor3=value==selected and T.Accent or T.Sub,
                Font=Enum.Font.Code,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=102},scroll)
            pad(item,0,0,6,6)
            table.insert(entries,{Value=value,Button=item})
            item.Activated:Connect(function()
                selected=value; button.Text=tostring(value); closeList()
                if callback then callback(value) end
            end)
        end
        local empty=label(scroll,"No results",12,T.Sub,Enum.Font.Code,nil,UDim2.new(1,0,0,26))
        empty.ZIndex=102; empty.LayoutOrder=#options+1; empty.Visible=#options==0
        search:GetPropertyChangedSignal("Text"):Connect(function()
            local count=0; local query=search.Text:lower()
            for _,entry in ipairs(entries) do
                local matches=tostring(entry.Value):lower():find(query,1,true)~=nil
                entry.Button.Visible=matches
                if matches then count=count+1 end
            end
            empty.Visible=count==0; scroll.CanvasPosition=Vector2.zero
        end)
        self.ActiveDropdownClose=closeList; arrow.Rotation=180
        search:CaptureFocus()
    end
    button.Activated:Connect(function() if listFrame then closeList() else openList() end end)
    return frame,function() return selected end,function(value,fire)
        selected=value; button.Text=tostring(value or "---")
        if fire and callback then callback(value) end
    end,closeList
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
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = T.AccentSoft,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
        }, page)
        corner(column, 7)
        -- Card outlines are added per section.
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

    local farmSetter
    local _, _, farmSetterValue = self:CreateSection(
        left,
        "Mob farm (on/off)",
        farm.Enabled and not farm.BossEnabled,
        function(on)
            if on then
                if not selectedMob then
                    status.Text = "Select a mob first"
                    status.TextColor3 = T.Danger
                    task.defer(function()
                        if farmSetter then
                            farmSetter(false, false)
                        end
                    end)
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
    farmSetter = farmSetterValue

    farm.OnStateChanged = function(enabled, mode, owner)
        local mobActive =
            enabled == true
            and mode == "Mob"
            and owner == "Farm"

        farmSetter(mobActive, false)

        if not enabled and status.Parent then
            status.Text = "Mob farm stopped"
            status.TextColor3 = T.Sub
        end
    end

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
            self:Quest():SetAutoQuest(on)
            status.Text = on
                and "Auto quest enabled"
                or "Auto quest disabled"
            status.TextColor3 = on and T.Gold or T.Sub
        end
    )

    self:CreateButton(
        left,
        "▣ รับเควส Mitsu Lv105",
        function()
            local ok, err = self:Quest():AcceptOnce(
                "Demon Slayer Mitsu",
                "Ill drive back the frost(Lv 105)"
            )
            status.Text = ok
                and "รับเควส Mitsu Lv105 แล้ว"
                or ("รับเควสไม่สำเร็จ: " .. tostring(err))
            status.TextColor3 = ok and T.Mint or T.Danger
        end
    )

    self:CreateButton(
        left,
        "▣ รับเควส Mitsu Lv115",
        function()
            local ok, err = self:Quest():AcceptOnce(
                "Demon Slayer Mitsu",
                "Ill put out the blaze(Lv 115)"
            )
            status.Text = ok
                and "รับเควส Mitsu Lv115 แล้ว"
                or ("รับเควสไม่สำเร็จ: " .. tostring(err))
            status.TextColor3 = ok and T.Mint or T.Danger
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
    local loot = self:Loot()
    local left, right = self:CreatePage("Boss Farm")

    local status = label(
        left,
        "Boss ready",
        11,
        T.Gold,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 22)
    )

    loot.OnStatus = function(text)
        status.Text = text
        status.TextColor3 = T.Mint
    end

    local bossList = boss.Names or {}
    local selected = farm.BossName or bossList[1]

    self:CreateSection(left, "Boss Farm")

    local _, getBoss = self:CreateDropdown(
        left,
        "เลือกบอสช่องที่ 1",
        "",
        bossList,
        selected,
        function(value)
            selected = value
            farm:SetBoss(value)
            status.Text = "Selected " .. value
            status.TextColor3 = T.Gold
        end
    )

    self:CreateButton(
        left,
        "▶ Start Single Boss",
        function()
            local name = getBoss and getBoss() or selected

            if not name then
                status.Text = "ต้องเลือกบอสก่อน"
                status.TextColor3 = T.Danger
                return
            end

            boss:ClearSelection()
            boss:SetSelected(name, true)

            local ok, err = boss:StartSelected()

            status.Text = ok
                and ("ฟาร์ม " .. name .. " (boss)")
                or tostring(err)

            status.TextColor3 =
                ok and T.Gold or T.Danger
        end
    )

    self:CreateToggle(
        left,
        "เก็บของหลังบอสตาย",
        loot.Enabled,
        function(on)
            loot:SetEnabled(on)
        end
    )

    self:CreateButton(left, "■ Stop Boss Farm", function()
        boss:Stop()
        status.Text = "Boss farm stopped"
        status.TextColor3 = T.Sub
    end)

    self:CreateSection(left, "Farm Boss All")

    self:CreateButton(
        left,
        "▶ Start Selected Bosses",
        function()
            local ok, err = boss:StartSelected()

            status.Text = ok
                and (
                    "Boss All • "
                    .. tostring(#boss.Order)
                    .. " selected"
                )
                or tostring(err)

            status.TextColor3 =
                ok and T.Mint or T.Danger
        end
    )

    self:CreateButton(left, "Clear Selection", function()
        boss:ClearSelection()

        for _, setter in pairs(
            self.BossToggleSetters or {}
        ) do
            setter(false, false)
        end

        status.Text = "Selection cleared"
        status.TextColor3 = T.Sub
    end)

    self:CreateSection(right, "Boss Selection")

    self.BossToggleSetters = {}

    for _, name in ipairs(bossList) do
        local bossName = name

        local _, _, setter = self:CreateToggle(
            right,
            "Boss • " .. bossName,
            boss.Selected[bossName] == true,
            function(on)
                boss:SetSelected(bossName, on)

                status.Text =
                    "Selected "
                    .. tostring(#boss.Order)
                    .. " boss(es)"

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
    local aimbot = self:Aimbot()
    local left, right = self:CreatePage("Combat")

    local aimStatus = label(
        left,
        "Aimbot ready",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 18)
    )

    self:CreateSection(left, "Aimbot")

    self:CreateToggle(
        left,
        "Aimbot",
        aimbot.Enabled == true,
        function(on)
            aimbot:SetEnabled(on)
            aimStatus.Text = on
                and "Aimbot enabled • hold Right Mouse to lock"
                or "Aimbot disabled"
            aimStatus.TextColor3 = on and T.Mint or T.Sub
        end
    )

    self:CreateToggle(
        left,
        "Show FOV circle",
        aimbot.ShowFOV == true,
        function(on)
            aimbot:SetShowFOV(on)
        end
    )

    self:CreateSlider(
        left,
        "FOV radius",
        "Circle follows mouse • hold Left Alt = screen center",
        50,
        500,
        aimbot.FOV or 180,
        " px",
        function(value)
            aimbot:SetFOV(value)
        end
    )

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

    self:CreateSection(right, "Targets")

    self:CreateToggle(
        right,
        "Aim at players",
        aimbot.TargetPlayers ~= false,
        function(on)
            aimbot.TargetPlayers = on
        end
    )

    self:CreateToggle(
        right,
        "Aim at NPCs",
        aimbot.TargetNPCs ~= false,
        function(on)
            aimbot.TargetNPCs = on
        end
    )

    self:CreateSection(right, "Aimbot Skills")

    self:CreateToggle(
        right,
        "Skill Aimbot",
        aimbot.SkillEnabled == true,
        function(on)
            aimbot:SetSkillEnabled(on)
            aimStatus.Text = on
                and "Skill aimbot enabled • Z X C V B N K"
                or "Skill aimbot disabled"
            aimStatus.TextColor3 = on and T.Mint or T.Sub
        end
    )

    local skillHint = label(
        right,
        "Z  X  C  V  B  N  K\nHold Right Mouse + skill key to lock closest target inside FOV.",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 44)
    )
    skillHint.TextWrapped = true

    self:CreateToggle(
        right,
        "No Swing Animation",
        farm.NoSwingAnimation == true,
        function(on)
            farm.NoSwingAnimation = on

            if not on then
                combat:RestoreSwingAnimations()
            end
        end
    )

    self:CreateToggle(
        right,
        "Adaptive Fast Attack",
        farm.AdaptiveFastAttack == true,
        function(on)
            farm.AdaptiveFastAttack = on
            combat.AdaptiveInterval =
                math.clamp(
                    tonumber(farm.AttackInterval) or 0.06,
                    0.01,
                    0.08
                )
            combat.NoDamageAttempts = 0
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

function UI:BuildPlayerPage()
    local playerModule = self:Player()
    local farm = self:Farm()
    local left, right = self:CreatePage("Player")

    local status = label(
        left,
        "Ready",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 16)
    )

    self:CreateSection(left, "Movement")

    self:CreateToggle(left, "วิ่งไว", playerModule.SpeedEnabled, function(on)
        playerModule:SetSpeed(on)
        status.Text = on
            and ("เปิดวิ่งไว: " .. tostring(playerModule.WalkSpeed))
            or "ปิดวิ่งไวแล้ว"
        status.TextColor3 = on and T.Mint or T.Sub
    end)

    self:CreateSlider(
        left,
        "ความเร็ววิ่ง",
        "",
        16,
        150,
        playerModule.WalkSpeed,
        "",
        function(value)
            playerModule.WalkSpeed = math.floor(value + 0.5)
            if playerModule.SpeedEnabled then
                playerModule:SetSpeed(true)
            end
        end
    )

    self:CreateToggle(left, "กระโดดสูง", playerModule.JumpEnabled, function(on)
        playerModule:SetJump(on)
        status.Text = on
            and ("เปิดกระโดดสูง: " .. tostring(playerModule.JumpPower))
            or "ปิดกระโดดสูงแล้ว"
        status.TextColor3 = on and T.Mint or T.Sub
    end)

    self:CreateSlider(
        left,
        "แรงกระโดด",
        "",
        50,
        200,
        playerModule.JumpPower,
        "",
        function(value)
            playerModule.JumpPower = math.floor(value + 0.5)
            if playerModule.JumpEnabled then
                playerModule:SetJump(true)
            end
        end
    )

    self:CreateToggle(left, "Fly", playerModule.FlyEnabled, function(on)
        playerModule:SetFly(on)
        status.Text = on
            and ("เปิด Fly • Speed " .. tostring(playerModule.FlySpeed))
            or "ปิด Fly แล้ว"
        status.TextColor3 = on and T.Mint or T.Sub
    end)

    self:CreateSlider(
        left,
        "Fly Speed",
        "WASD • Space ขึ้น • Ctrl ลง",
        20,
        500,
        playerModule.FlySpeed,
        "",
        function(value)
            playerModule.FlySpeed = math.floor(value + 0.5)
        end
    )

    self:CreateSection(left, "Invisible")

    self:CreateToggle(left, "Invisible", playerModule.InvisibleEnabled, function(on)
        playerModule:SetInvisible(on)
        status.Text = on
            and "Invisible enabled • local ghost visible"
            or "Invisible disabled"
        status.TextColor3 = on and T.Mint or T.Sub
    end)

    local invisibleHint = label(
        left,
        "ตัวจริงถูกซ่อน • ฝั่งผู้ใช้เห็นเป็นเงาจางๆ",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 30)
    )
    invisibleHint.TextWrapped = true

    self:CreateSection(right, "Hitbox")

    self:CreateToggle(
        right,
        "ทดสอบ Hitbox การตี",
        farm.PlayerHitboxTest == true,
        function(on)
            farm:SetPlayerHitboxTest(on)
            status.Text = on
                and "เปิดทดสอบ Hitbox • ถืออาวุธแล้วลองตีเอง"
                or "ปิดทดสอบ Hitbox"
            status.TextColor3 = on and T.Gold or T.Sub
        end
    )

    farm.PlayerAttackHitbox = farm.PlayerAttackHitbox or 30
    self:CreateSlider(
        right,
        "ระยะ Hitbox การตี",
        "ขนาดพื้นที่ตีของอาวุธที่ถืออยู่",
        5,
        100,
        farm.PlayerAttackHitbox,
        " st",
        function(value)
            farm.PlayerAttackHitbox = math.floor(value + 0.5)
        end
    )

    self:CreateSection(right, "Collision")

    self:CreateToggle(right, "No Clip", playerModule.NoClipEnabled, function(on)
        playerModule:SetNoClip(on)
        status.Text = on
            and "เปิด No Clip"
            or "ปิด No Clip และคืนค่าการชนแล้ว"
        status.TextColor3 = on and T.Gold or T.Sub
    end)

    self:CreateSection(right, "Environment")

    self:CreateToggle(right, "Full Bright", playerModule.FullBrightEnabled, function(on)
        playerModule:SetFullBright(on)
        status.Text = on
            and "Full Bright enabled"
            or "Full Bright disabled"
        status.TextColor3 = on and T.Mint or T.Sub
    end)

    self:CreateToggle(right, "No Fog (ลบหมอก)", playerModule.NoFogEnabled, function(on)
        playerModule:SetNoFog(on)
        status.Text = on and "เปิด No Fog" or "ปิด No Fog"
        status.TextColor3 = on and T.Mint or T.Sub
    end)

    self:CreateToggle(right, "ลบ Atmosphere", false, function(on)
        playerModule:SetAtmosphereRemoved(on)
    end)

    self:CreateSlider(
        right,
        "Fog End",
        "ระยะไกลสุดของหมอก",
        100,
        5000,
        1000,
        " st",
        function(value)
            playerModule:SetFogEnd(value)
        end
    )
end

function UI:BuildTeleportPage()
    local teleport = self:Teleport()
    local left, right = self:CreatePage("Teleport")

    local status = label(
        left,
        "พร้อม",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 16)
    )

    self:CreateSection(left, "NPCs — ทุกโซน")

    local npcs = teleport.NPCs or {}
    local selectedNpc = npcs[1]

    local _, getNpc, setNpc = self:CreateDropdown(
        left,
        "เลือก NPC",
        "เลือกแล้วกดวาป",
        npcs,
        selectedNpc,
        function(name)
            selectedNpc = name
        end
    )

    self:CreateSearchRow(left, "Search NPC...", function(query)
        query = tostring(query or ""):lower()
        if query == "" then return end

        for _, name in ipairs(npcs) do
            if name:lower():find(query, 1, true) then
                selectedNpc = name
                setNpc(name, false)
                status.Text = "Selected " .. name
                status.TextColor3 = T.Mint
                return
            end
        end

        status.Text = "NPC not found"
        status.TextColor3 = T.Danger
    end)

    self:CreateButton(left, "⟶ วาปไป NPC ที่เลือก", function()
        local name = getNpc and getNpc() or selectedNpc
        local ok, err = teleport:GoNPC(name)
        status.Text = ok
            and ("→ " .. tostring(name))
            or ("ล้มเหลว: " .. tostring(err))
        status.TextColor3 = ok and T.Mint or T.Danger
    end)

    self:CreateSection(left, "Players")

    local playerNames = teleport:PlayerNames()
    if #playerNames == 0 then
        playerNames = { "— ไม่มีผู้เล่นอื่น —" }
    end

    local _, getPlayer = self:CreateDropdown(
        left,
        "Players",
        "เลือกผู้เล่นในเซิร์ฟเวอร์",
        playerNames,
        playerNames[1]
    )

    self:CreateButton(left, "⟶ วาปไปผู้เล่นที่เลือก", function()
        local name = getPlayer and getPlayer()
        if name == "— ไม่มีผู้เล่นอื่น —" then
            status.Text = "ไม่มีผู้เล่นอื่นในเซิร์ฟเวอร์"
            status.TextColor3 = T.Danger
            return
        end

        local ok, err = teleport:GoPlayer(name)
        status.Text = ok
            and ("→ Player: " .. tostring(name))
            or ("ล้มเหลว: " .. tostring(err))
        status.TextColor3 = ok and T.Mint or T.Danger
    end)

    self:CreateButton(left, "⇢ ดึงผู้เล่นที่เลือกมาหาเรา", function()
        local name = getPlayer and getPlayer()

        if not name
            or name == "— ไม่มีผู้เล่นอื่น —" then
            status.Text = "ไม่มีผู้เล่นอื่นในเซิร์ฟเวอร์"
            status.TextColor3 = T.Danger
            return
        end

        local ok, err = teleport:BringPlayer(name)

        status.Text = ok
            and ("Bring → " .. tostring(name))
            or ("Bring ล้มเหลว: " .. tostring(err))

        status.TextColor3 =
            ok and T.Gold or T.Danger
    end)

    self:CreateSection(right, "วาปด่วน")

    for _, npcName in ipairs({
        "Krue",
        "Betty",
        "Kazu",
        "Kona",
        "Tom",
        "Chaka",
        "Demon Slayer Mitsu",
        "Thunder Trainer Zentaro",
    }) do
        local name = npcName

        self:CreateButton(right, "⟶ " .. name, function()
            local ok, err = teleport:GoNPC(name)
            status.Text = ok
                and ("→ " .. name)
                or ("ล้มเหลว: " .. tostring(err))
            status.TextColor3 = ok and T.Mint or T.Danger
        end)
    end

    self:CreateSection(right, "อื่น ๆ")

    self:CreateButton(right, "⟶ Spawn", function()
        local ok, err = teleport:Spawn()
        status.Text = ok and "→ Spawn" or tostring(err)
        status.TextColor3 = ok and T.Mint or T.Danger
    end)

    self:CreateButton(right, "⟶ ขึ้นฟ้า (+100)", function()
        local ok, err = teleport:Sky()
        status.Text = ok and "→ Sky +100" or tostring(err)
        status.TextColor3 = ok and T.Mint or T.Danger
    end)

    self:CreateButton(right, "⟶ ลงพื้น (Raycast)", function()
        local ok, err = teleport:Ground()
        status.Text = ok and "→ Ground" or tostring(err)
        status.TextColor3 = ok and T.Mint or T.Danger
    end)
end

function UI:BuildWorldPage()
    local teleport = self:Teleport()
    local world = self:World()
    local left, right = self:CreatePage("World")

    local status = label(
        left,
        "World ready",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 16)
    )

    world.Cup.OnStatus = function(text)
        status.Text = text
        status.TextColor3 = T.Mint
    end

    world.Thunder.OnStatus = function(text)
        status.Text = text
        status.TextColor3 = T.Gold
    end

    world.Pushups.OnStatus = function(text)
        status.Text = text
        status.TextColor3 = T.Accent
    end

    self:CreateSection(right, "Npc LV 1-7")

    self:CreateButton(right, "⟶ Krue", function()
        local ok, err = teleport:GoNPC("Krue")
        status.Text = ok and "→ Krue" or tostring(err)
        status.TextColor3 = ok and T.Mint or T.Danger
    end)

    self:CreateSection(right, "Pushups")

    self:CreateToggle(
        right,
        "Auto Pushups",
        world.Pushups.Enabled,
        function(on)
            world:SetPushupsEnabled(on)
        end
    )

    local pushHint = label(
        right,
        "ตรวจวง timing และคลิกซ้ายอัตโนมัติเมื่อวงเข้าจังหวะ",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 42)
    )
    pushHint.TextWrapped = true

    self:CreateSection(left, "Cup Game")

    self:CreateToggle(
        left,
        "ESP Cup2",
        world.Cup.Enabled,
        function(on)
            world:SetCupEnabled(on)
        end
    )

    local cupHint = label(
        left,
        'Outline สีขาวเฉพาะ workspace.Training["Cup Game"].Cupgame1.Cups.Cup2',
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 36)
    )
    cupHint.TextWrapped = true

    self:CreateSection(left, "ปราณสายฟ้า")

    self:CreateToggle(
        left,
        "Auto ทำปราณสายฟ้า",
        world.Thunder.Enabled,
        function(on)
            world:SetThunderEnabled(on)
        end
    )

    self:CreateButton(
        left,
        "⚡ Thunder Trainer Zentaro",
        function()
            local ok, err =
                teleport:GoNPC(
                    "Thunder Trainer Zentaro"
                )

            status.Text = ok
                and "→ Thunder Trainer Zentaro"
                or tostring(err)

            status.TextColor3 =
                ok and T.Mint or T.Danger
        end
    )
end


function UI:BuildSettingsPage()
    local settings = self:Settings()
    local visuals = self:Visuals()
    local left, right = self:CreatePage("Settings")

    self:CreateSection(left, "ภาษา")

    self:CreateDropdown(
        left,
        "ภาษาเมนู",
        "โครงภาษาเดิม • ตัวเลือก UI",
        { "ไทย / Thai", "English" },
        "ไทย / Thai"
    )

    self:CreateSection(left, "Player labels")

    label(
        left,
        "RightShift • เปิด/ปิดเมนู",
        11,
        T.Sub,
        Enum.Font.Code,
        nil,
        UDim2.new(1, 0, 0, 28)
    )

    self:CreateDropdown(
        left,
        "Label layout",
        "Stacking style",
        { "Stacked", "Inline", "Compact" },
        visuals.LabelLayout or "Stacked",
        function(value)
            visuals:SetLabelLayout(value)
        end
    )

    self:CreateSlider(
        left,
        "Label scale",
        "Text size multiplier",
        50,
        200,
        math.floor((visuals.LabelScale or 1) * 100),
        "%",
        function(value)
            visuals:SetLabelScale(value / 100)
        end
    )

    self:CreateToggle(
        left,
        "Show distance",
        visuals.ShowDistance ~= false,
        function(on)
            visuals:SetShowDistance(on)
        end
    )

    self:CreateToggle(
        left,
        "Hide when aiming",
        visuals.HideWhenAiming == true,
        function(on)
            visuals:SetHideWhenAiming(on)
        end
    )

    self:CreateSection(right, "Performance / ประสิทธิภาพ")

    self:CreateToggle(
        right,
        "ภาพต่ำ / FPS Boost",
        settings.LowGraphicsEnabled,
        function(on)
            settings:SetLowGraphics(on)
        end
    )

    local perfHint = label(
        right,
        "ลดเงา เท็กซ์เจอร์ และเอฟเฟกต์ • ปิดเพื่อคืนภาพ",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 34)
    )
    perfHint.TextWrapped = true

    self:CreateSection(right, "Interface")

    self:CreateToggle(
        right,
        "Blur background",
        self.BlurEnabled == true,
        function(on)
            self.BlurEnabled = on == true

            local lighting = game:GetService("Lighting")
            local blur =
                lighting:FindFirstChild("MazxhubUIBlur")

            if self.BlurEnabled then
                if not blur then
                    blur = Instance.new("BlurEffect")
                    blur.Name = "MazxhubUIBlur"
                    blur.Size = 12
                    blur.Parent = lighting
                end
                blur.Enabled = true
            elseif blur then
                blur:Destroy()
            end
        end
    )

    self:CreateToggle(
        right,
        "Animations",
        self.AnimationsEnabled ~= false,
        function(on)
            self.AnimationsEnabled = on == true
        end
    )

    self:CreateSlider(
        right,
        "UI opacity",
        "Panel transparency",
        0,
        100,
        100,
        "%",
        function(value)
            local transparency = 1 - value / 100
            self.Main.BackgroundTransparency = transparency
            self.Sidebar.BackgroundTransparency = transparency

            if self.SidebarEdge then
                self.SidebarEdge.BackgroundTransparency = transparency
            end
        end
    )
end


function UI:BuildQuestsPage()
    local quest = self:Quest()
    local left, right = self:CreatePage("Quests")

    local entries = {
        {
            Name = "Kazu",
            Title = "Quest 1 • Kazu • Lv 1-10",
            Side = left,
        },
        {
            Name = "Betty",
            Title = "Quest 2 • Betty • Lv 10",
            Side = left,
        },
        {
            Name = "Delivery",
            Title = "Quest 3 • MoldySugar • Lv 1-10",
            Side = left,
        },
        {
            Name = "Pages",
            Title = "Quest 4 • Kona • Lv 1-10",
            Side = right,
        },
        {
            Name = "Bear",
            Title = "Quest 5 • Lucy / Tom / Bear Cub",
            Side = right,
        },
        {
            Name = "HunterExam",
            Title = "สอบนักล่า",
            Side = right,
        },
    }

    self.QuestSetters = self.QuestSetters or {}

    for _, entry in ipairs(entries) do
        local questName = entry.Name
        local record = quest.Quests[questName]

        local statusLabel = label(
            entry.Side,
            record and record.Status or (questName .. " • OFF"),
            11,
            T.Sub,
            Enum.Font.Gotham,
            nil,
            UDim2.new(1, 0, 0, 30)
        )
        statusLabel.TextWrapped = true

        if record then
            record.OnStatus = function(text)
                statusLabel.Text = text
                statusLabel.TextColor3 =
                    record.Enabled and T.Mint or T.Sub
            end
        end

        local _, _, setter = self:CreateSection(
            entry.Side,
            entry.Title,
            record and record.Enabled or false,
            function(on)
                quest:SetDedicatedEnabled(questName, on)

                if record then
                    statusLabel.Text = record.Status
                    statusLabel.TextColor3 =
                        on and T.Mint or T.Sub
                end
            end
        )

        self.QuestSetters[questName] = setter

        if questName == "HunterExam" then
            self:CreateButton(
                entry.Side,
                "▶ Continue หลังทำช่วง Manual",
                function()
                    local ok, message =
                        quest:ContinueHunterExam()

                    statusLabel.Text =
                        message or (
                            ok
                            and "สอบนักล่า • ไปต่อแล้ว"
                            or "สอบนักล่า • ยังไปต่อไม่ได้"
                        )
                    statusLabel.TextColor3 =
                        ok and T.Mint or T.Gold
                end
            )
        end

        if record then
            record.OnEnabled = function(on)
                setter(on, false)
            end
        end
    end

    self:CreateSection(right, "Auto Quest ตามมอน/บอส")

    local autoHint = label(
        right,
        "ใช้ Auto Quest ที่หน้า Mob Farm/Boss Farm ระบบจะไปรับเควสตามเป้าหมายแล้วกลับมาตีต่ออัตโนมัติ",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 54)
    )
    autoHint.TextWrapped = true
end

function UI:BuildDungeonPage()
    local dungeon = self:Dungeon()
    local left, right = self:CreatePage("Dungeon")

    local status = label(
        left,
        "Dungeon ready",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 20)
    )

    dungeon.Unlock.OnStatus = function(text)
        status.Text = text
        status.TextColor3 = T.Gold
    end

    self:CreateSection(left, "Auto Dungeon")

    local _, _, dungeonSetter = self:CreateToggle(
        left,
        "Auto Dungeon",
        dungeon.Enabled,
        function(on)
            dungeon:SetEnabled(on)
            status.Text = on
                and "Auto Dungeon enabled"
                or "Auto Dungeon disabled"
            status.TextColor3 = on and T.Mint or T.Sub
        end
    )

    dungeon.OnEnabled = function(on)
        dungeonSetter(on, false)
        status.Text = on
            and "Auto Dungeon enabled"
            or "Auto Dungeon disabled"
        status.TextColor3 = on and T.Mint or T.Sub
    end

    self:CreateSlider(
        left,
        "ความสูงก่อนวาปลงตี",
        "ระยะลอยเหนือ HumanoidRootPart ก่อนเข้าตำแหน่งตี",
        20,
        120,
        dungeon.ApproachSkyHeight,
        " st",
        function(value)
            dungeon.ApproachSkyHeight = value
        end
    )

    self:CreateSlider(
        left,
        "เวลาลอยบนฟ้า",
        "รอก่อนลงไปตีมอน",
        0.1,
        3,
        dungeon.ApproachDelay,
        " s",
        function(value)
            dungeon.ApproachDelay = value
        end
    )

    self:CreateSlider(
        left,
        "หน่วงก่อนตีตัวถัดไป",
        "หลังมอนตาย รอก่อนเลือกเป้าตัวใหม่",
        0.1,
        2,
        dungeon.NextTargetDelay,
        " s",
        function(value)
            dungeon.NextTargetDelay = value
        end
    )

    self:CreateSection(right, "Dungeon Combat")

    self:CreateToggle(
        right,
        "Auto Skip",
        dungeon.AutoSkip,
        function(on)
            dungeon:SetAutoSkip(on)
        end
    )

    self:CreateToggle(
        right,
        "Kill Aura",
        dungeon.KillAura,
        function(on)
            dungeon:SetKillAura(on)
        end
    )

    self:CreateSlider(
        right,
        "Kill Aura Range",
        "รัศมีส่ง Combat Service เพิ่มเติม",
        5,
        60,
        dungeon.KillAuraRadius,
        " st",
        function(value)
            dungeon.KillAuraRadius = value
        end
    )

    self:CreateSection(right, "Quest unlock Dungeon • Lv65+")

    self:CreateToggle(
        right,
        "Auto Quest Dungeon",
        dungeon.Unlock.Enabled,
        function(on)
            dungeon:SetUnlockEnabled(on)
        end
    )

    local unlockHint = label(
        right,
        "ไปหา Blacksmith Togane → รับเควส Ill find the forge(Lv 65) → ไป Forge → กด T",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 52)
    )
    unlockHint.TextWrapped = true
end

function UI:BuildRaidsPage()
    local raid = self:Raid()
    local left, right = self:CreatePage("Raids")

    local status = label(
        left,
        raid.Status or "Raid ready",
        11,
        T.Mint,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 34)
    )
    status.TextWrapped = true

    raid.OnStatus = function(text)
        status.Text = text
        status.TextColor3 =
            raid.Enabled and T.Mint or T.Sub
    end

    self:CreateSection(
        left,
        "Raid Chest • Auto Scan All Points"
    )

    local _, _, raidSetter = self:CreateToggle(
        left,
        "Auto Raid Chest",
        raid.Enabled,
        function(on)
            raid:SetEnabled(on)
        end
    )

    raid.OnEnabled = function(on)
        raidSetter(on, false)
        status.Text = on
            and "Raid Chest • ON"
            or "Raid Chest • OFF"
        status.TextColor3 = on and T.Mint or T.Sub
    end

    self:CreateButton(
        left,
        "เริ่มจากจุด 1 ใหม่",
        function()
            raid:SetPoint(1)
            raid.Phase = "checkMove"
            raid.NextAt = 0
            raid:SetStatus("Raid • รีเซ็ตไปจุด 1")
        end
    )

    self:CreateSection(right, "Saved Raid Points")

    local pointCount = raid:PointCount()

    label(
        right,
        "มีจุดที่บันทึกไว้ทั้งหมด "
            .. tostring(pointCount)
            .. " จุด",
        12,
        T.Text,
        Enum.Font.GothamBold,
        nil,
        UDim2.new(1, 0, 0, 30)
    )

    self:CreateSlider(
        right,
        "เริ่มตรวจจากจุด",
        "เปลี่ยนจุดเริ่มต้นของ Auto Raid",
        1,
        math.max(pointCount, 1),
        raid.PointIndex or 1,
        "",
        function(value)
            raid:SetPoint(
                math.floor(value + 0.5)
            )
        end
    )

    local hint = label(
        right,
        "ระบบจะตรวจมอน → ฟาร์มจนหมด → เปิดกล่อง → กด T เก็บของ → ไปจุดถัดไป",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 54)
    )
    hint.TextWrapped = true
end

function UI:BuildVisualsPage()
    local visuals = self:Visuals()
    local boss = self:Boss()
    local left, right = self:CreatePage("Visuals")

    self:CreateSection(left, "ESP ผู้เล่น")

    self:CreateToggle(
        left,
        "ESP Player",
        visuals.Enabled,
        function(on)
            visuals:SetPlayerESP(on)
        end
    )

    self:CreateToggle(
        left,
        "ESP Line",
        visuals.Lines,
        function(on)
            visuals:SetLines(on)
        end
    )

    self:CreateToggle(
        left,
        "ESP Outline",
        visuals.Outlines,
        function(on)
            visuals:SetOutlines(on)
        end
    )

    self:CreateSlider(
        left,
        "ESP ระยะสูงสุด",
        "Max render distance",
        100,
        3000,
        visuals.MaxDistance,
        " st",
        function(value)
            visuals:SetMaxDistance(value)
        end
    )

    self:CreateSection(right, "ESP NPC ใน ActiveNpcs")

    self:CreateToggle(
        right,
        "ESP Bandit",
        visuals.Bandit,
        function(on)
            visuals:SetBandit(on)
        end
    )

    self:CreateToggle(
        right,
        "ESP Civilian",
        visuals.Civilian,
        function(on)
            visuals:SetCivilian(on)
        end
    )

    label(
        right,
        "Bandit = สีแดง • Civilian = สีเขียว",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 24)
    )

    self:CreateSection(
        right,
        "ESP บอสทั้งหมด (เปิด/ปิด)"
    )

    self:CreateToggle(
        right,
        "ESP Boss All",
        visuals.BossEnabled,
        function(on)
            visuals:SetBossEnabled(on)
        end
    )

    for _, name in ipairs(boss.Names or {}) do
        local bossName = name

        self:CreateToggle(
            right,
            "ESP " .. bossName,
            visuals.BossSelected[bossName] ~= false,
            function(on)
                visuals:SetBossSelected(
                    bossName,
                    on
                )
            end
        )
    end
end

function UI:BuildStatusPage()
    local boss = self:Boss()
    local farm = self:Farm()
    local left, right = self:CreatePage("Status")

    self:CreateSection(left, "Runtime")
    self:CreateSection(right, "Boss Spawn Status")

    self.StatusLabels = {
        Farm = label(
            left,
            "Farm: ...",
            11,
            T.Text,
            Enum.Font.Code,
            nil,
            UDim2.new(1, 0, 0, 26)
        ),
        Target = label(
            left,
            "Target: ...",
            11,
            T.Text,
            Enum.Font.Code,
            nil,
            UDim2.new(1, 0, 0, 26)
        ),
        Combat = label(
            left,
            "Combat: ...",
            11,
            T.Text,
            Enum.Font.Code,
            nil,
            UDim2.new(1, 0, 0, 26)
        ),
        Jobs = label(
            left,
            "Jobs: ...",
            10,
            T.Sub,
            Enum.Font.Code,
            nil,
            UDim2.new(1, 0, 0, 72)
        ),
        Error = label(
            left,
            "Error: none",
            10,
            T.Gold,
            Enum.Font.Code,
            nil,
            UDim2.new(1, 0, 0, 52)
        ),
    }

    self.StatusLabels.Jobs.TextWrapped = true
    self.StatusLabels.Error.TextWrapped = true

    local note = label(
        right,
        "เวลาประมาณจากการตาย → เกิดที่ตรวจพบในเซสชันนี้",
        10,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 34)
    )
    note.TextWrapped = true

    self.BossStatusRows = {}

    local split =
        math.ceil(#boss.Names / 2)

    for index, name in ipairs(boss.Names) do
        local column =
            index <= split and left or right

        if index == 1 then
            self:CreateSection(
                left,
                "สถานะบอส / เวลาเกิด"
            )
        elseif index == split + 1 then
            self:CreateSection(
                right,
                "Boss List"
            )
        end

        local row = new("Frame", {
            Size = UDim2.new(1, 0, 0, 78),
            BackgroundColor3 = T.Card,
            BorderSizePixel = 0,
        }, column)
        corner(row, 7)
        stroke(row, T.Stroke, 1)

        local nameLabel = label(
            row,
            name,
            12,
            T.Text,
            Enum.Font.GothamBold,
            UDim2.fromOffset(10, 6),
            UDim2.new(1, -20, 0, 18)
        )

        local region =
            farm.BossRegions
            and farm.BossRegions[name]
            or "Misc"

        local regionLabel = label(
            row,
            region,
            9,
            T.Sub,
            Enum.Font.Gotham,
            UDim2.fromOffset(10, 24),
            UDim2.new(1, -20, 0, 14)
        )

        local statusLabel = label(
            row,
            "กำลังตรวจสอบ...",
            10,
            T.Gold,
            Enum.Font.Gotham,
            UDim2.fromOffset(10, 40),
            UDim2.new(1, -20, 0, 16)
        )

        local detailLabel = label(
            row,
            "",
            9,
            T.Sub,
            Enum.Font.Gotham,
            UDim2.fromOffset(10, 57),
            UDim2.new(1, -20, 0, 16)
        )
        detailLabel.TextTruncate =
            Enum.TextTruncate.AtEnd

        self.BossStatusRows[name] = {
            Status = statusLabel,
            Detail = detailLabel,
            Region = regionLabel,
            Name = nameLabel,
        }
    end
end

function UI:RefreshStatus()
    local labels = self.StatusLabels
    if not labels then return end

    local farm = self:Farm()
    local combat = self:Combat()
    local boss = self:Boss()
    local state = self.Ctx.State

    labels.Farm.Text =
        string.format(
            "Farm: %s • Mode: %s",
            farm.Enabled and "ON" or "OFF",
            tostring(
                state.FarmMode
                or farm.Mode
                or "-"
            )
        )

    labels.Target.Text =
        "Target: "
        .. tostring(
            state.TargetName
            or (
                state.Target
                and state.Target.Name
            )
            or "-"
        )

    labels.Combat.Text =
        "Combat: "
        .. tostring(combat.State or "idle")

    local jobNames = {}

    for name, job in pairs(self.Ctx.Jobs) do
        table.insert(
            jobNames,
            name
                .. "="
                .. (
                    job.Enabled
                    and "ON"
                    or "OFF"
                )
        )
    end

    table.sort(jobNames)

    labels.Jobs.Text =
        "Jobs: "
        .. table.concat(jobNames, " • ")

    labels.Error.Text =
        "Error: "
        .. tostring(
            farm._lastRuntimeError
            or "none"
        )

    local colors = {
        Mint = T.Mint,
        Gold = T.Gold,
        Sub = T.Sub,
    }

    for name, row in pairs(
        self.BossStatusRows or {}
    ) do
        local stateData =
            boss.StatusStates[name]

        local statusText,
            detailText,
            colorKey =
            boss:DescribeStatus(stateData)

        row.Status.Text = statusText
        row.Status.TextColor3 =
            colors[colorKey] or T.Sub
        row.Detail.Text = detailText
    end
end

function UI:GroupSections()
    self.Cards={}
    for _,page in pairs(self.Pages) do
        for _,column in ipairs({page.Left,page.Right}) do
            local children=column:GetChildren()
            local current
            local order=0
            for _,child in ipairs(children) do
                if child:IsA("GuiObject") then
                    local title=child:GetAttribute("MazaSection")
                    if title or not current then
                        order=order+1
                        local card=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=T.Card,
                            BorderSizePixel=0,LayoutOrder=order},column)
                        corner(card,4); stroke(card)
                        new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder},card)
                        local body=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=2},card)
                        pad(body,7,7,7,7)
                        new("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},body)
                        current={Frame=card,Body=body,Rows={},Title=title or "",Collapsed=false,Column=column}
                        table.insert(self.Cards,current)
                        if title then
                            child.Parent=card; child.LayoutOrder=1
                            local fold=new("TextButton",{Size=UDim2.fromOffset(24,28),Position=UDim2.new(1,-25,0,3),Text="",
                                BackgroundTransparency=1,ZIndex=6},child)
                            -- Toggle headers already use the right edge for their on/off switch.
                            local hasToggle=child:FindFirstChildOfClass("TextButton")~=fold
                            if hasToggle then fold.Position=UDim2.new(1,-69,0,3) end
                            local arrow=icon(fold,"Chevron",UDim2.fromOffset(3,5),16,T.Sub)
                            current.Arrow=arrow
                            local group=current
                            fold.Activated:Connect(function()
                                group.Collapsed=not group.Collapsed; self:FilterControls()
                            end)
                        end
                    end
                    if not title then
                        child.Parent=current.Body; child.LayoutOrder=#current.Rows+1
                        table.insert(current.Rows,child)
                    end
                end
            end
        end
    end
end

function UI:FilterControls()
    local query=self.SearchBox and self.SearchBox.Text:lower() or ""
    for _,group in ipairs(self.Cards or {}) do
        local heading=query~="" and group.Title:lower():find(query,1,true)~=nil
        local found=heading or query==""
        for _,row in ipairs(group.Rows) do
            local text=row:IsA("TextLabel") and row.Text or ""
            for _,node in ipairs(row:GetDescendants()) do
                if node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then text=text.." "..tostring(node.Text) end
            end
            local matches=query=="" or heading or text:lower():find(query,1,true)~=nil
            row.Visible=matches; found=found or matches
        end
        group.Frame.Visible=found
        group.Body.Visible=query~="" or not group.Collapsed
        if group.Arrow then group.Arrow.Rotation=group.Body.Visible and 0 or -90 end
    end
end

function UI:BuildPages()
    self:BuildMobFarmPage()
    self:BuildBossFarmPage()
    self:BuildQuestsPage()
    self:BuildDungeonPage()
    self:BuildRaidsPage()
    self:BuildStatusPage()

    self:BuildWorldPage()
    self:BuildTeleportPage()

    self:BuildPlayerPage()
    self:BuildCombatPage()
    self:BuildVisualsPage()
    self:BuildSkillPage()

    self:BuildSettingsPage()
end

function UI:HideAllPages()
    for _, data in pairs(self.Pages) do
        data.Frame.Visible = false
    end
end

function UI:SelectSubTab(name)
    self:CloseDropdown()
    self:HideAllPages()

    local page = self.Pages[name]
    if page then
        page.Frame.Visible = true
        page.Left.CanvasPosition = Vector2.zero
        page.Right.CanvasPosition = Vector2.zero
    end

    self.ActiveSubTab = name
    self:FilterControls()

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
    self:CloseDropdown()
    self.ActiveMenu = menuName
    self:BuildTabs(menuName)

    for name, data in pairs(self.NavButtons) do
        local active = name == menuName
        tween(data.Button, {
            BackgroundColor3 = active and T.AccentSoft or T.Sidebar,
        })
        for _,part in ipairs(data.Icon:GetDescendants()) do
            if part:IsA("Frame") then part.BackgroundColor3=active and T.Accent or T.Sub end
        end
        tween(data.Label, {
            TextColor3 = active and T.Text or T.Sub,
        })
    end
end

function UI:BuildSidebar()
    local head=new("Frame",{Size=UDim2.new(1,0,0,51),BackgroundTransparency=1},self.Sidebar)
    self.SidebarHead=head
    self.SidebarAvatar=icon(head,"M",UDim2.fromOffset(16,12),27,T.Accent)
    self.SidebarBrand=label(head,"MazaSpace",18,T.Text,Enum.Font.Code,UDim2.fromOffset(53,0),UDim2.new(1,-54,1,0))
    self.SidebarDivider=new("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.fromOffset(0,50),BackgroundColor3=T.Stroke,BorderSizePixel=0},head)
    self.Nav=new("ScrollingFrame",{Size=UDim2.new(1,0,1,-100),Position=UDim2.fromOffset(0,58),BackgroundTransparency=1,
        BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=0},self.Sidebar)
    self.NavLayout=new("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},self.Nav)
    for _,entry in ipairs({{"Farm","Farm"},{"World","Location"},{"Player","Player"},{"Setting","Config"}}) do
        local name=entry[1]
        local button=new("TextButton",{Size=UDim2.new(1,0,0,42),BackgroundColor3=T.Sidebar,BorderSizePixel=0,Text="",AutoButtonColor=false},self.Nav)
        local symbol=icon(button,entry[2],UDim2.fromOffset(15,11),20,T.Accent)
        local title=label(button,name=="Setting" and "Settings" or name,13,T.Sub,Enum.Font.Gotham,UDim2.fromOffset(46,0),UDim2.new(1,-48,1,0))
        self.NavButtons[name]={Button=button,Icon=symbol,Label=title}
        button.Activated:Connect(function() self:SelectMenu(name) end)
    end
    self.MenuHint=label(self.Sidebar,"Shift / M",11,T.Sub,Enum.Font.Code,UDim2.new(0,16,1,-31),UDim2.new(1,-32,0,20))
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
        "MazaSpace",
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

    self.SearchBox=searchBox
    searchBox:GetPropertyChangedSignal("Text"):Connect(function() self:FilterControls() end)

    self.DragHandle = new("Frame", {
        Size = UDim2.new(1, -250, 0, 48),
        Position = UDim2.fromOffset(212, 0),
        BackgroundTransparency = 1,
        Active = true,
    }, self.Top)

    tech.ZIndex = 2
    hub.ZIndex = 2
    self.TechCaption = tech
    self.HubName = hub
    self.CloseButton = close
end

function UI:LayoutFor(width, height)
    local compact = width < 700 or height < 430
    return {
        Compact = compact,
        Width = math.max(1, math.min(820, width - 24)),
        Height = math.max(1, math.min(620, height - 24)),
    }
end

function UI:ClampPoint(x, y, width, height, viewWidth, viewHeight, centered)
    local ax = centered and width * 0.5 or 0
    local ay = centered and height * 0.5 or 0
    local lowX = 4 + ax
    local lowY = 4 + ay
    local highX = math.max(lowX, viewWidth - width + ax - 4)
    local highY = math.max(lowY, viewHeight - height + ay - 4)
    return Vector2.new(
        math.clamp(x, lowX, highX),
        math.clamp(y, lowY, highY)
    )
end

function UI:ClampWindowPoint(x, y, width, height, viewWidth, viewHeight)
    local keepVisible = 44
    local halfW = width * 0.5
    local halfH = height * 0.5
    local lowX = -halfW + keepVisible
    local highX = viewWidth + halfW - keepVisible
    local lowY = -halfH + keepVisible
    local highY = viewHeight + halfH - keepVisible

    return Vector2.new(
        math.clamp(x, lowX, highX),
        math.clamp(y, lowY, highY)
    )
end

function UI:ApplyColumns()
    for _, page in pairs(self.Pages) do
        local columns = { page.Left, page.Right }

        for index, column in ipairs(columns) do
            column.Visible =
                not self.Compact
                or index == self.Column

            column.Size =
                self.Compact
                and UDim2.new(1, -24, 1, -12)
                or UDim2.new(0.5, -24, 1, -12)

            column.Position =
                self.Compact
                and UDim2.fromOffset(12, 0)
                or UDim2.new(
                    0.5 * (index - 1),
                    index == 1 and 16 or 8,
                    0,
                    0
                )
        end
    end

    if self.ColumnButton then
        self.ColumnButton.Visible = self.Compact
        self.ColumnButton.Text =
            self.Column == 1
            and "Controls →"
            or "← Settings"
    end
end

function UI:Layout(recenter)
    if not self.Surface or not self.Main then return end

    local size = self.Surface.AbsoluteSize
    if size.X < 1 or size.Y < 1 then return end

    self:CloseDropdown()

    local layout = self:LayoutFor(size.X, size.Y)
    self.Compact = layout.Compact
    self.Main.Size = UDim2.fromOffset(layout.Width, layout.Height)

    local center

    if recenter then
        center = Vector2.new(size.X * 0.5, size.Y * 0.5)
    else
        center = Vector2.new(
            self.Main.Position.X.Scale * size.X + self.Main.Position.X.Offset,
            self.Main.Position.Y.Scale * size.Y + self.Main.Position.Y.Offset
        )
        center = self:ClampWindowPoint(
            center.X,
            center.Y,
            layout.Width,
            layout.Height,
            size.X,
            size.Y
        )
    end

    self.Main.Position = UDim2.fromOffset(center.X, center.Y)

    if self.SidebarAvatar then
        self.SidebarAvatar.Visible = not self.Compact
    end
    if self.SidebarBrand then
        self.SidebarBrand.Visible = not self.Compact
    end
    if self.SidebarDivider then
        self.SidebarDivider.Visible = not self.Compact
    end
    if self.MenuHint then
        self.MenuHint.Visible = not self.Compact
    end

    self.Sidebar.Size =
        self.Compact
        and UDim2.new(1, 0, 0, 52)
        or UDim2.new(0, 184, 1, 0)

    if self.Nav then
        self.Nav.Size =
            self.Compact
            and UDim2.new(1, 0, 0, 50)
            or UDim2.new(1, 0, 1, -112)

        self.Nav.Position =
            self.Compact
            and UDim2.fromOffset(0, 2)
            or UDim2.fromOffset(0, 56)

        self.Nav.ScrollingDirection =
            self.Compact
            and Enum.ScrollingDirection.X
            or Enum.ScrollingDirection.Y

        self.Nav.AutomaticCanvasSize =
            self.Compact
            and Enum.AutomaticSize.X
            or Enum.AutomaticSize.Y
    end

    if self.NavLayout then
        self.NavLayout.FillDirection =
            self.Compact
            and Enum.FillDirection.Horizontal
            or Enum.FillDirection.Vertical
    end

    for _, data in pairs(self.NavButtons) do
        data.Button.Size =
            self.Compact
            and UDim2.fromOffset(110, 44)
            or UDim2.fromOffset(184, 42)
    end

    self.Right.Size =
        self.Compact
        and UDim2.new(1, 0, 1, -52)
        or UDim2.new(1, -184, 1, 0)

    self.Right.Position =
        self.Compact
        and UDim2.fromOffset(0, 52)
        or UDim2.fromOffset(184, 0)

    if self.Search then
        self.Search.Visible = not self.Compact
    end
    if self.TechCaption then self.TechCaption.Visible=false end
    if self.HubName then self.HubName.Visible=self.Compact end
    if self.Search then self.Search.Size=UDim2.new(1,-68,0,32); self.Search.Position=UDim2.fromOffset(12,10) end
    if self.DragHandle then self.DragHandle.Visible=false end

    self:ApplyColumns()

    local point = self:ClampPoint(
        self.Fab.Position.X.Scale * size.X + self.Fab.Position.X.Offset,
        self.Fab.Position.Y.Scale * size.Y + self.Fab.Position.Y.Offset,
        52,
        52,
        size.X,
        size.Y,
        false
    )

    self.Fab.Position = UDim2.fromOffset(point.X, point.Y)
end

function UI:BindDrag()
    local inputService=self.Ctx.Services.UserInputService
    local function bind(handle,target,launcher)
        local gesture
        handle.Active=true
        self:Connect(handle.InputBegan,function(input)
            if gesture then return end
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                gesture={Input=input,Start=input.Position,Position=target.Position,Moved=false}
                self:CloseDropdown()
            end
        end)
        self:Connect(inputService.InputChanged,function(input)
            local g=gesture
            if not g then return end
            if input==g.Input or (g.Input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement) then
                local delta=input.Position-g.Start
                if delta.Magnitude>=6 then g.Moved=true end
                if g.Moved then
                    local bounds=self.Surface.AbsoluteSize
                    local x=g.Position.X.Scale*bounds.X+g.Position.X.Offset+delta.X
                    local y=g.Position.Y.Scale*bounds.Y+g.Position.Y.Offset+delta.Y
                    local pos
                    if launcher then pos=self:ClampPoint(x,y,52,52,bounds.X,bounds.Y,false)
                    else pos=self:ClampWindowPoint(x,y,target.AbsoluteSize.X,target.AbsoluteSize.Y,bounds.X,bounds.Y) end
                    target.Position=UDim2.fromOffset(pos.X,pos.Y)
                end
            end
        end)
        self:Connect(inputService.InputEnded,function(input)
            local g=gesture
            if not g then return end
            if input==g.Input or (g.Input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1) then
                gesture=nil
                if launcher and not g.Moved and (input.Position-g.Start).Magnitude<6 then self:SetOpen(not self.IsOpen) end
            end
        end)
        self:Connect(inputService.WindowFocusReleased,function() gesture=nil end)
    end
    bind(self.SidebarHead,self.Main,false)
    local strip=new("Frame",{Size=UDim2.new(1,0,0,8),BackgroundTransparency=1,Active=true,ZIndex=25},self.Top)
    bind(strip,self.Main,false)
    bind(self.Fab,self.Fab,true)
end

function UI:Init(ctx)
    self.Ctx = ctx
    self.Pages = {}
    self.NavButtons = {}
    self.Connections = {}
    self.TabButtons = {}
    self.BossToggleSetters = {}
    self.ActiveDropdownClose = nil
    self.Compact = false
    self.Column = 1
    self.Cards = {}
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
        Image = "",
        ZIndex = 200,
    }, self.Surface)
    corner(self.Fab, 26)
    stroke(self.Fab, T.Accent, 1.5)
    local monogram=icon(self.Fab,"M",UDim2.fromOffset(11,10),30,T.Accent)
    monogram.ZIndex=201
    for _,part in ipairs(monogram:GetDescendants()) do if part:IsA("GuiObject") then part.ZIndex=201 end end

    self.Main = new("Frame", {
        Size = UDim2.fromOffset(740, 500),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = T.Bg,
        BorderSizePixel = 0,
        Visible = false,
        ClipsDescendants = false,
    }, self.Surface)
    corner(self.Main, 6)
    stroke(self.Main, T.Stroke, 1)

    self.Sidebar = new("Frame", {
        Size = UDim2.new(0, 184, 1, 0),
        BackgroundColor3 = T.Sidebar,
        BorderSizePixel = 0,
    }, self.Main)
    corner(self.Sidebar, 6)

    self.SidebarEdge = new("Frame", {
        Size = UDim2.new(0, 16, 1, 0),
        Position = UDim2.new(1, -16, 0, 0),
        BackgroundColor3 = T.Sidebar,
        BorderSizePixel = 0,
    }, self.Sidebar)

    self.Right = new("Frame", {
        Size = UDim2.new(1, -184, 1, 0),
        Position = UDim2.fromOffset(184, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
    }, self.Main)

    self.Top = new("Frame", {
        Size = UDim2.new(1, 0, 0, 94),
        BackgroundTransparency = 1,
        ZIndex = 5,
    }, self.Right)

    self.ColumnButton = new("TextButton", {
        Name = "ColumnSwitch",
        Size = UDim2.fromOffset(126, 38),
        Position = UDim2.fromOffset(8, 7),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Text = "Controls →",
        TextSize = 12,
        TextColor3 = T.Accent,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 20,
    }, self.Top)
    corner(self.ColumnButton, 8)

    self.ColumnButton.Activated:Connect(function()
        self.Column = self.Column == 1 and 2 or 1
        self:ApplyColumns()
    end)

    self:BuildSidebar()
    self:BuildTop()
    self:BuildPages()
    self:GroupSections()
    self:BindDrag()


    self:Connect(
        self.Ctx.Services.UserInputService.InputBegan,
        function(input, processed)
            if not processed
                and not self.Ctx.Services.UserInputService:GetFocusedTextBox()
                and (input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.LeftShift) then
                self:SetOpen(not self.IsOpen)
            end
        end
    )

    self:Connect(
        self.Surface:GetPropertyChangedSignal("AbsoluteSize"),
        function()
            self:Layout(false)
        end
    )
    self:SelectMenu("Farm")
    self:SetOpen(true)

    self.Ctx:RegisterJob(
        "UIStatus",
        0.5,
        function()
            self:RefreshStatus()
        end
    )

    task.defer(function()
        self:Layout(true)
        self:RefreshStatus()
    end)
end

function UI:Stop()
    local blur =
        game:GetService("Lighting"):FindFirstChild("MazxhubUIBlur")
    if blur then
        blur:Destroy()
    end
    self.BlurEnabled = false

    if self.Ctx then
        self.Ctx:RemoveJob("UIStatus")
    end

    self:CloseDropdown()

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

