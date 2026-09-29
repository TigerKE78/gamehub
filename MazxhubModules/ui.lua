-- MazaSpace native UI + original module callbacks.
-- This is a loader module: Init(ctx), then Start(). Use MazaSpace.lua for one-file execution.
local UI={}
function UI:Init(ctx)
    self.Ctx=ctx;self.AnimationsEnabled=true;self.BlurEnabled=false
end
function UI:Stop()
    if self.Ctx then self.Ctx:RemoveJob("UIStatus") end
    local blur=game:GetService("Lighting"):FindFirstChild("MazxhubUIBlur")
    if blur then blur:Destroy() end
    self.BlurEnabled=false
    if self.Gui then self.Gui:Destroy();self.Gui=nil end
end
function UI:Start()
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local player = self.Ctx.Player or Players.LocalPlayer
assert(player, "Run this file on the client as a LocalScript")
local playerGui = player:WaitForChild("PlayerGui")
for _, name in ipairs({"SottoroUI", "MazaSpaceUI", "MazxhubModulesUI"}) do
    local previous = playerGui:FindFirstChild(name)
    if previous then previous:Destroy() end
end

local UI=self
UI.Values={}; UI.Callbacks={}; UI.Connections={}; UI.Sections={}; UI.Pages={}; UI.Controls={}
UI.ActivePage="Main"; UI.Dropdowns={}; UI.Bindings={}; UI.SyncControls={}; UI.BossToggleSetters={}; UI.QuestSetters={}
local C = {
    Background = Color3.fromRGB(12, 12, 15), Panel = Color3.fromRGB(17, 17, 21),
    Field = Color3.fromRGB(23, 23, 28), Line = Color3.fromRGB(53, 50, 55),
    Text = Color3.fromRGB(239, 234, 237), Muted = Color3.fromRGB(188, 181, 188),
    Accent = Color3.fromRGB(202, 57, 78),
}
local translations={
    {"ใช้ Auto Quest ที่หน้า Mob Farm/Boss Farm ระบบจะไปรับเควสตามเป้าหมายแล้วกลับมาตีต่ออัตโนมัติ","Enable Auto Quest in Mob Farm or Boss Farm to accept target quests and resume farming"},
    {"ไปหา Blacksmith Togane → รับเควส Ill find the forge(Lv 65) → ไป Forge → กด T","Talk to Blacksmith Togane → Accept Ill find the forge (Lv 65) → Go to Forge → Press T"},
    {"ระบบจะตรวจมอน → ฟาร์มจนหมด → เปิดกล่อง → กด T เก็บของ → ไปจุดถัดไป","Scan monsters → Clear area → Open chest → Hold T for loot → Next point"},
    {"ตรวจวง timing และคลิกซ้ายอัตโนมัติเมื่อวงเข้าจังหวะ","Detect the timing ring and click at the correct time"},
    {"ขยายพื้นที่ตีของ BasePart ทุกชิ้นในอาวุธที่ถืออยู่","Expand the equipped weapon hitbox"},
    {"ระยะลอยเหนือ HumanoidRootPart ก่อนเข้าตำแหน่งตี","Hover height above the target before attacking"},
    {"ลดเงา เท็กซ์เจอร์ และเอฟเฟกต์ • ปิดเพื่อคืนภาพ","Reduce shadows, textures and effects; disable to restore"},
    {"เวลาประมาณจากการตาย → เกิดที่ตรวจพบในเซสชันนี้","Respawn estimates based on observations in this session"},
    {"ตัวจริงถูกซ่อน • ฝั่งผู้ใช้เห็นเป็นเงาจางๆ","Hidden character; faint local preview"},
    {"เปิดทดสอบ Hitbox • ถืออาวุธแล้วลองตีเอง","Hitbox test enabled • Equip a weapon and attack"},
    {"Bandit = สีแดง • Civilian = สีเขียว","Bandit = red • Civilian = green"},
    {"ลอยติดหัวมอน • ไม่วาปหนีเมื่อโดนตี","Hover over target; stay when hit"},
    {"หลังมอนตาย รอก่อนเลือกเป้าตัวใหม่","Wait after a kill before selecting the next target"},
    {"รัศมีส่ง Combat Service เพิ่มเติม","Additional Combat Service radius"},
    {"ขนาดพื้นที่ตีของอาวุธที่ถืออยู่","Equipped weapon hitbox size"},
    {"เปลี่ยนจุดเริ่มต้นของ Auto Raid","Change Auto Raid starting point"},
    {"ถึงเวลาประมาณแล้ว • รอตรวจพบบอส","Respawn expected • Waiting for detection"},
    {"ปิด No Clip และคืนค่าการชนแล้ว","No Clip disabled; collisions restored"},
    {"Change attack position in the Attack position card. Settings apply to mobs and bosses.","Attack while hovering over the target"},
    {"การโจมตี • รอเปิด Auto Attack","Attack • Waiting for Auto Attack"},
    {"ไม่มีผู้เล่นอื่นในเซิร์ฟเวอร์","No other players in this server"},
    {"ยังไม่พบ • ยังไม่ทราบเวลาเกิด","Not found • Respawn unknown"},
    {"ตายแล้ว • ยังไม่ทราบเวลาเกิด","Dead • Respawn unknown"},
    {"ระยะที่จะเริ่มโจมตีเป้าหมาย","Attack start distance"},
    {"WASD • Space ขึ้น • Ctrl ลง","WASD • Space up • Ctrl down"},
    {"ความถี่ในการส่งคำสั่งโจมตี","Attack request interval"},
    {"Continue หลังทำช่วง Manual","Continue after the manual step"},
    {"ขนาด hitbox ของมอนที่ล็อก","Target monster hitbox size"},
    {"เลือกผู้เล่นในเซิร์ฟเวอร์","Select server player"},
    {"ดึงผู้เล่นที่เลือกมาหาเรา","Bring selected player"},
    {"RightShift • เปิด/ปิดเมนู","Change the menu shortcut below"},
    {"Performance / ประสิทธิภาพ","Performance"},
    {"มีจุดที่บันทึกไว้ทั้งหมด ","Saved points: "},
    {"ESP บอสทั้งหมด (เปิด/ปิด)","All boss ESP"},
    {"1 request ต่อรอบโจมตี","1 request per attack cycle"},
    {"Auto Quest ตามมอน/บอส","Auto Quest by target"},
    {"ESP NPC ใน ActiveNpcs","Active NPC ESP"},
    {"เกิดแล้ว • พร้อมฟาร์ม","Alive • Ready to farm"},
    {"— ไม่มีผู้เล่นอื่น —","— No other players —"},
    {"วาปไปผู้เล่นที่เลือก","Teleport to selected player"},
    {"หน่วงก่อนตีตัวถัดไป","Next target delay"},
    {"สถานะบอส / เวลาเกิด","Boss status / Respawn"},
    {"ยังไม่พบในเซสชันนี้","Not seen this session"},
    {"รับเควสไม่สำเร็จ: ","Quest failed: "},
    {"ทดสอบ Hitbox การตี","Test weapon hitbox"},
    {"วาปไป NPC ที่เลือก","Teleport to selected NPC"},
    {"Outline สีขาวเฉพาะ","White outline only for"},
    {"ภาพต่ำ / FPS Boost","Low graphics / FPS Boost"},
    {"ความสูงก่อนวาปลงตี","Approach height"},
    {"เริ่มจากจุด 1 ใหม่","Restart from point 1"},
    {"เลือกบอสช่องที่ 1","Select primary boss"},
    {"เก็บของหลังบอสตาย","Collect loot after boss defeat"},
    {"เปิด Fly • Speed ","Fly enabled • Speed "},
    {"ระยะ Hitbox การตี","Weapon hitbox range"},
    {"ระยะไกลสุดของหมอก","Maximum fog distance"},
    {"Auto ทำปราณสายฟ้า","Auto Thunder Breathing"},
    {"ยังไม่พบข้อมูลโซน","Region not loaded"},
    {"ต้องเลือกบอสก่อน","Select a boss first"},
    {"ปิดกระโดดสูงแล้ว","High jump disabled"},
    {"ลงพื้น (Raycast)","Move to ground (Raycast)"},
    {"คาดว่าจะเกิดใน ~","Estimated respawn in ~"},
    {"เปิดกระโดดสูง: ","High jump enabled: "},
    {"ปิดทดสอบ Hitbox","Hitbox test disabled"},
    {"No Fog (ลบหมอก)","No Fog"},
    {"รอก่อนลงไปตีมอน","Wait before approaching the monster"},
    {"เริ่มตรวจจากจุด","Start point"},
    {"กำลังตรวจสอบ...","Scanning..."},
    {"เลือกแล้วกดวาป","Select a target, then teleport"},
    {"ขึ้นฟ้า (+100)","Move up (+100)"},
    {"ยังไปต่อไม่ได้","Cannot resume yet"},
    {"ESP ระยะสูงสุด","ESP maximum distance"},
    {"ยังไม่มีข้อมูล","No data yet"},
    {"รอบที่วัดได้ ~","Measured interval ~"},
    {"รับเควส Mitsu","Accept Mitsu quest"},
    {"ปิดวิ่งไวแล้ว","Walk speed disabled"},
    {"ลบ Atmosphere","Remove atmosphere"},
    {"NPCs — ทุกโซน","NPCs — All regions"},
    {"รีเซ็ตไปจุด 1","Reset to point 1"},
    {"เปิดวิ่งไว: ","Walk speed enabled: "},
    {"ความเร็ววิ่ง","Walk speed"},
    {"ปิด Fly แล้ว","Fly disabled"},
    {"เปิด No Clip","No Clip enabled"},
    {"เวลาลอยบนฟ้า","Hover duration"},
    {"เปิด No Fog","No Fog enabled"},
    {"ESP ผู้เล่น","Player ESP"},
    {"ปิด No Fog","No Fog disabled"},
    {"ปราณสายฟ้า","Thunder Breathing"},
    {"กระโดดสูง","High jump"},
    {"แรงกระโดด","Jump power"},
    {"เลือก NPC","Select NPC"},
    {"ล้มเหลว: ","Failed: "},
    {"สอบนักล่า","Hunter Exam"},
    {"ไปต่อแล้ว","Resumed"},
    {"พบล่าสุด ","Last seen "},
    {"ภาษาเมนู","Menu language"},
    {"วาปด่วน","Quick teleport"},
    {"ฟาร์ม ","Farm "},
    {"วิ่งไว","Walk speed"},
    {"อื่น ๆ","Other"},
    {"ช่อง ","Slot "},
    {" แล้ว"," completed"},
    {"พร้อม","Ready"},
    {"ภาษา","Language"},
    {" จุด"," points"},
}
UI.Language=UI.Language or "English"
UI.TextEntries={}
function UI:Translate(text)
    text=tostring(text or "")
    if self.Language~="English" then return text end
    for _,pair in ipairs(translations) do
        local pattern=pair[1]:gsub("(%W)","%%%1")
        text=text:gsub(pattern,function() return pair[2] end)
    end
    return text
end
function UI:SetLanguage(value)
    self.Language=value=="English" and "English" or "ไทย / Thai"
    for _,entry in ipairs(self.TextEntries) do entry.Paint() end
    if self.Filter then self:Filter() end
end
function UI:WatchText(obj,property)
    local entry={Raw=obj[property],Last=nil}
    function entry.Paint()
        entry.Last=self:Translate(entry.Raw)
        obj[property]=entry.Last
    end
    table.insert(self.TextEntries,entry)
    table.insert(self.Connections,obj:GetPropertyChangedSignal(property):Connect(function()
        if obj[property]==entry.Last then return end
        entry.Raw=obj[property];entry.Paint()
    end))
    entry.Paint()
end
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    if class=="TextLabel" or class=="TextButton" or class=="TextBox" then
        obj.Font=Enum.Font.Gotham
        obj.TextSize=math.max(14,props.TextSize or 14)
        if class=="TextBox" then UI:WatchText(obj,"PlaceholderText")
        else UI:WatchText(obj,"Text") end
    end
    obj.Parent = parent
    return obj
end
local function connect(signal, fn)
    local connection = signal:Connect(fn)
    table.insert(UI.Connections, connection)
    return connection
end
local function corner(obj, r)
    local shape = obj:FindFirstChildOfClass("UICorner") or make("UICorner", {}, obj)
    shape.CornerRadius = UDim.new(0, r or 4)
end
local function outline(obj) make("UIStroke", {Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, obj) end
-- Resolution-independent outline icons made from UI geometry (no emoji/assets).
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
    local aliases={Quests="Dialogue",["Hunter Exam"]="Defense",["Unlock Market"]="Market",["Unlock Dungeon"]="Dungeon",
        ["Mob Farm"]="Farm",["Boss Farm"]="Defense",Aimbot="Combat",Skill="Instakill",World="Location",Teleport="Location",
        Raids="Dungeon",["Combat tools"]="Main",["ESP tools"]="Visuals"}
    name=aliases[name] or name
    local canvas=make("Frame",{Name="Icon_"..name,BackgroundTransparency=1,Size=UDim2.fromOffset(size,size),Position=position},parent)
    if name=="M" then
        make("TextLabel",{Name="MLogo",Text="M",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
            TextSize=size,TextColor3=color or C.Accent,TextXAlignment=Enum.TextXAlignment.Center},canvas).Font=Enum.Font.GothamBold
        return canvas
    end
    local ink=color or C.Accent
    local function line(x1,y1,x2,y2)
        local dx,dy=(x2-x1)*size/24,(y2-y1)*size/24
        local segment=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset((x1+x2)*size/48,(y1+y2)*size/48),
            Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy)+1.2,2),Rotation=math.deg(math.atan2(dy,dx)),BackgroundColor3=ink,BorderSizePixel=0},canvas)
        corner(segment,1)
    end
    local function ring(x,y,r)
        local circle=make("Frame",{BackgroundTransparency=1,BorderSizePixel=0,
            Position=UDim2.fromOffset((x-r)*size/24,(y-r)*size/24),
            Size=UDim2.fromOffset(2*r*size/24,2*r*size/24)},canvas)
        make("UICorner",{CornerRadius=UDim.new(.5,0)},circle)
        make("UIStroke",{Color=ink,Thickness=1.6,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},circle)
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
local SectionIcons={Status="Performance",Changelog="List",Combat="Combat",Dialogue="Dialogue",Defense="Defense",Training="Training",
    Instakill="Instakill",["Private Server"]="Lock",["Black market"]="Market",["Clan roll"]="Lock",Players="Player",Mobs="Defense",
    Character="Player",["Teleport to location"]="Location",Performance="Performance",Muzan="Muzan",["Teleport to NPC"]="Player",
    Discord="Webhook",Notifications="Webhook",["On every card"]="List",Menu="Menu",Account="Player",Themes="Themes",Configuration="Folder"}

local function pad(obj, n)
    make("UIPadding", {PaddingTop=UDim.new(0,n), PaddingBottom=UDim.new(0,n), PaddingLeft=UDim.new(0,n), PaddingRight=UDim.new(0,n)}, obj)
end
local function stack(obj, gap)
    return make("UIListLayout", {Padding=UDim.new(0,gap or 5), SortOrder=Enum.SortOrder.LayoutOrder}, obj)
end
local function label(parent, text, size)
    return make("TextLabel", {BackgroundTransparency=1, Size=size or UDim2.new(1,0,0,22), Text=text,
        TextColor3=C.Text, Font=Enum.Font.Gotham, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left}, parent)
end
local function button(parent, text, size)
    local b=make("TextButton", {Size=size or UDim2.new(1,0,0,26), BackgroundColor3=C.Field,
        BorderSizePixel=0, Text=text, TextColor3=C.Muted, Font=Enum.Font.Gotham, TextSize=14, AutoButtonColor=true}, parent)
    corner(b,3); outline(b)
    return b
end
local function textbox(parent, placeholder)
    local b=make("TextBox", {Size=UDim2.new(1,0,0,27), BackgroundColor3=C.Field, BorderSizePixel=0,
        Text="", PlaceholderText=placeholder or "", PlaceholderColor3=C.Muted, TextColor3=C.Text,
        Font=Enum.Font.Gotham, TextSize=14, ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left}, parent)
    corner(b,3); outline(b); pad(b,6)
    return b
end

UI.Gui=make("ScreenGui", {Name="MazaSpaceUI", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    DisplayOrder=20, IgnoreGuiInset=false}, playerGui)
UI.Changed=make("BindableEvent", {Name="Changed"}, UI.Gui)
local root=make("Frame", {AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5),
    Size=UDim2.fromOffset(724,604), BackgroundColor3=C.Background, BorderSizePixel=0}, UI.Gui)
corner(root,5); outline(root)
local scale=make("UIScale", {Scale=1}, root)
local top=make("Frame", {Size=UDim2.new(1,0,0,50), BackgroundColor3=C.Background, BorderSizePixel=0, Active=true}, root)
icon(top,"M",UDim2.fromOffset(28,14),23)
local brand=label(top,"MazaSpace", UDim2.fromOffset(156,50)); brand.Position=UDim2.fromOffset(62,0); brand.TextSize=19
local search=textbox(top,"Search"); search.Position=UDim2.fromOffset(226,9); search.Size=UDim2.new(1,-274,0,33)
search.TextXAlignment=Enum.TextXAlignment.Center
search:FindFirstChildOfClass("UIPadding").PaddingLeft=UDim.new(0,28)
icon(search,"Search",UDim2.fromOffset(9,8),17,C.Muted)
icon(top,"Move",UDim2.new(1,-36,0,14),23,C.Line)
local hide=button(top,"−",UDim2.fromOffset(30,28)); hide.Position=UDim2.new(1,-68,0,11); hide.Visible=false
local close=button(top,"×",UDim2.fromOffset(24,28)); close.Position=UDim2.new(1,-32,0,11); close.Visible=false
local sidebar=make("ScrollingFrame", {CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=2,ScrollBarImageColor3=C.Accent,BorderSizePixel=0,Position=UDim2.fromOffset(0,50), Size=UDim2.new(0,218,1,-76), BackgroundTransparency=1}, root)
stack(sidebar,0)
make("Frame", {Position=UDim2.fromOffset(218,0), Size=UDim2.new(0,1,1,-25), BackgroundColor3=C.Line, BorderSizePixel=0}, root)
local content=make("Frame", {Position=UDim2.fromOffset(226,58), Size=UDim2.new(1,-234,1,-90), BackgroundTransparency=1, ClipsDescendants=true}, root)
local footer=label(root,"MazaSpace · UI 2026.09.29-r4",UDim2.new(1,0,0,24)); footer.Position=UDim2.new(0,0,1,-24)
footer.TextColor3=C.Muted; footer.TextXAlignment=Enum.TextXAlignment.Center; footer.BackgroundTransparency=0; footer.BackgroundColor3=C.Field
-- Floating launcher remains available while the main window is open or hidden.
local launcherLayer=make("Frame",{Name="LauncherLayer",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
    Active=false,ZIndex=20},UI.Gui)
local reopen=button(launcherLayer,"",UDim2.fromOffset(52,52))
reopen.Name="MazaSpaceLauncher"; reopen.AnchorPoint=Vector2.new(.5,.5)
reopen.Position=UDim2.new(.5,0,0,38); reopen.ZIndex=20
reopen.BackgroundColor3=C.Panel; corner(reopen,26)
local launcherStroke=reopen:FindFirstChildOfClass("UIStroke")
launcherStroke.Color=C.Accent; launcherStroke.Thickness=1.5
local launcherIcon=icon(reopen,"M",UDim2.fromOffset(12,12),28,C.Accent)
launcherIcon.ZIndex=21
for _,part in ipairs(launcherIcon:GetDescendants()) do
    if part:IsA("GuiObject") then part.ZIndex=21 end
end
local launcherGesture
local function clampLauncher()
    local bounds=launcherLayer.AbsoluteSize
    if bounds.X<1 or bounds.Y<1 then return end
    local pos=reopen.Position
    local x=pos.X.Scale*bounds.X+pos.X.Offset
    local y=pos.Y.Scale*bounds.Y+pos.Y.Offset
    local margin=30
    x=math.clamp(x,math.min(margin,bounds.X/2),math.max(bounds.X-margin,bounds.X/2))
    y=math.clamp(y,math.min(margin,bounds.Y/2),math.max(bounds.Y-margin,bounds.Y/2))
    reopen.Position=UDim2.fromScale(x/bounds.X,y/bounds.Y)
end
connect(launcherLayer:GetPropertyChangedSignal("AbsoluteSize"),clampLauncher)
task.defer(clampLauncher)
hide.Parent=root; hide.Visible=true; hide.Size=UDim2.fromOffset(22,19); hide.Position=UDim2.new(1,-27,1,-22)
hide.Text="−"; hide.BackgroundTransparency=1; hide:FindFirstChildOfClass("UIStroke"):Destroy()
local function show(visible)
    UI.IsOpen=visible
    if not visible then UI:CloseDropdown() end
    root.Visible=visible
    reopen.BackgroundColor3=visible and C.Field or C.Panel
end
connect(hide.Activated,function() show(false) end)
connect(close.Activated,function() show(false) end)
-- Toggle only on a tap/click; releasing a drag must not toggle the window.
connect(reopen.InputBegan,function(input)
    if launcherGesture then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        local bounds=launcherLayer.AbsoluteSize
        local pos=reopen.Position
        launcherGesture={Input=input,Start=Vector2.new(input.Position.X,input.Position.Y),
            Origin=Vector2.new(pos.X.Scale*bounds.X+pos.X.Offset,pos.Y.Scale*bounds.Y+pos.Y.Offset),Moved=false}
    end
end)
connect(Input.InputChanged,function(input)
    local g=launcherGesture
    if not g then return end
    local mouse=g.Input.UserInputType==Enum.UserInputType.MouseButton1
    if (mouse and input.UserInputType==Enum.UserInputType.MouseMovement) or input==g.Input then
        local delta=Vector2.new(input.Position.X,input.Position.Y)-g.Start
        if delta.Magnitude>=6 then g.Moved=true end
        if g.Moved then
            reopen.Position=UDim2.fromOffset(g.Origin.X+delta.X,g.Origin.Y+delta.Y)
            clampLauncher()
        end
    end
end)
connect(Input.InputEnded,function(input)
    local g=launcherGesture
    if not g then return end
    local ended=input==g.Input or (g.Input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)
    if not ended then return end
    launcherGesture=nil
    local finish=Vector2.new(input.Position.X,input.Position.Y)
    local topLeft,size=reopen.AbsolutePosition,reopen.AbsoluteSize
    local inside=finish.X>=topLeft.X and finish.X<=topLeft.X+size.X and finish.Y>=topLeft.Y and finish.Y<=topLeft.Y+size.Y
    if not g.Moved and (finish-g.Start).Magnitude<6 and inside then show(not root.Visible) end
end)
connect(Input.WindowFocusReleased,function() launcherGesture=nil end)
show(true)

UI.Main=root; UI.Sidebar=sidebar; UI.SearchBox=search; UI.Fab=reopen
function UI:SetOpen(visible) show(visible==true) end
function UI:CloseDropdown()
    for _,d in ipairs(self.Dropdowns) do d.Close() end
end
function UI:On(id, callback) self.Callbacks[id]=callback end
function UI:Emit(id,value)
    self.Values[id]=value
    self.Changed:Fire(id,value)
    local fn=self.Callbacks[id]
    if not fn and string.sub(id,1,10)=="reference." then
        footer.Text="UI preview: setting saved locally (not connected)"
    end
    if fn then
        local ok,err=pcall(fn,value)
        if not ok then
            footer.Text="MazaSpace · Action error (see console)"
            warn("[MazaSpace] "..id..": "..tostring(err))
        end
    end
end
function UI:Destroy() if self.Gui.Parent then self.Gui:Destroy() end end
connect(UI.Gui.Destroying,function()
    for _,connection in ipairs(UI.Connections) do connection:Disconnect() end
    UI.Connections={}
    if UI.Ctx then UI.Ctx:RemoveJob("UIStatus") end
end)
UI.MenuKey=UI.MenuKey or Enum.KeyCode.RightShift
connect(Input.InputBegan,function(input,processed)
    if UI.CapturingMenuKey then
        if input.UserInputType~=Enum.UserInputType.Keyboard then return end
        if input.KeyCode~=Enum.KeyCode.Escape and input.KeyCode~=Enum.KeyCode.Unknown then UI.MenuKey=input.KeyCode end
        UI.CapturingMenuKey=false
        UI.MenuKeyButton.Text="Menu key: "..UI.MenuKey.Name
        return
    end
    if not processed and not Input:GetFocusedTextBox() and input.KeyCode==UI.MenuKey then show(not root.Visible) end
end)

local drag, sliding, binding
connect(top.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        drag={Input=input, Start=input.Position, Position=root.Position}
    end
end)
connect(Input.InputChanged,function(input)
    if drag and (input.UserInputType==Enum.UserInputType.MouseMovement or input==drag.Input) then
        local delta=input.Position-drag.Start
        root.Position=UDim2.new(drag.Position.X.Scale,drag.Position.X.Offset+delta.X,drag.Position.Y.Scale,drag.Position.Y.Offset+delta.Y)
    end
    if sliding and (input.UserInputType==Enum.UserInputType.MouseMovement or input==sliding.Input) then sliding.Update(input.Position.X) end
end)
connect(Input.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then drag=nil; sliding=nil end
    if drag and input==drag.Input then drag=nil end
    if sliding and input==sliding.Input then sliding=nil end
end)
local function fit()
    local camera=workspace.CurrentCamera
    if camera then scale.Scale=math.min(1, (camera.ViewportSize.X-24)/724, (camera.ViewportSize.Y-70)/604) end
end
local cameraConnection
local function watchCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    fit()
    if workspace.CurrentCamera then cameraConnection=connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit) end
end
connect(workspace:GetPropertyChangedSignal("CurrentCamera"),watchCamera); watchCamera()

local function contains(text,query) return string.find(string.lower(UI:Translate(text)),string.lower(query),1,true)~=nil end
function UI:Filter()
    local query=search.Text
    for _,s in ipairs(self.Sections) do
        if s.DisabledReference then
            s.Frame.Visible=false
        else
            local titleMatch=query~="" and contains(s.Title,query)
            local found=false
            for _,r in ipairs(s.Rows) do
                r.Node.Visible=query=="" or titleMatch or contains(r.Text,query)
                found=found or r.Node.Visible
            end
            s.Frame.Visible=query=="" or titleMatch or found
            s.Body.Visible=query~="" or not s.Collapsed
            s.Chevron.Rotation=s.Body.Visible and 0 or -90
        end
    end
end
connect(search:GetPropertyChangedSignal("Text"),function()
    local query=search.Text
    if query~="" then
        for _,s in ipairs(UI.Sections) do
            if not s.DisabledReference then
                local matches=contains(s.Title,query)
                for _,r in ipairs(s.Rows) do
                    if contains(r.Text,query) then matches=true;break end
                end
                if matches then UI:SelectPage(s.Page);break end
            end
        end
    end
    UI:Filter()
end)

local navigation={
    {Title="Overview",Items={{"Home","Home"}}},
    {Title="Combat",Items={{"Main","Main"},{"Combat tools","Combat tools"},{"Aimbot","Aimbot"},{"Skill","Skill"}}},
    {Title="Farm",Items={{"Mob Farm","Mob Farm"},{"Boss Farm","Boss Farm"}}},
    {Title="Quest",Items={{"Quests","Story quests"},{"Hunter Exam","Hunter Exam"},{"Unlock Market","Unlock Market"},{"Unlock Dungeon","Unlock Dungeon"}}},
    {Title="Instances",Items={{"Dungeon","Dungeon"},{"Raids","Raids"}}},
    {Title="World",Items={{"World","World"},{"Teleport","Teleport"}}},
    {Title="Player",Items={{"Player","Player"},{"Visuals","Visuals"},{"ESP tools","ESP tools"}}},
    {Title="System",Items={{"Config","Settings"},{"Webhook","Webhook"}}},
}
local function page(name)
    local scroll=make("ScrollingFrame", {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, BorderSizePixel=0,
        CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=3,
        ScrollBarImageColor3=C.Accent, ScrollingDirection=Enum.ScrollingDirection.Y, Visible=false}, content)
    local columns={}
    for i=1,2 do
        columns[i]=make("Frame", {Position=UDim2.new((i-1)*.5,i==1 and 0 or 4,0,1), Size=UDim2.new(.5,-7,0,0),
            AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1},scroll)
        stack(columns[i],9)
    end
    UI.Pages[name]={Frame=scroll,Columns=columns}
    return name
end
local function buildNavigation()
    UI.NavGroups={}
    for _,group in ipairs(navigation) do
        local holder=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1},sidebar)
        stack(holder,2)
        local heading=button(holder,"  "..group.Title.."   ▾",UDim2.new(1,0,0,31))
        heading.TextXAlignment=Enum.TextXAlignment.Left;heading.BackgroundTransparency=1
        heading.TextColor3=C.Muted
        heading:FindFirstChildOfClass("UIStroke"):Destroy()
        local children=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},holder)
        stack(children,1)
        local record={Title=group.Title,Heading=heading,Body=children,Open=true,Tabs={}}
        children.Visible=true
        heading.Text="  "..group.Title.."  ▾"
        table.insert(UI.NavGroups,record)
        connect(heading.Activated,function()
            record.Open=not record.Open
            children.Visible=record.Open
            heading.Text="  "..group.Title..(record.Open and "  ▾" or "  ▸")
        end)
        for _,item in ipairs(group.Items) do
            local name,text=item[1],item[2]
            local tab=button(children,"",UDim2.new(1,0,0,33));tab.BackgroundTransparency=1
            tab:FindFirstChildOfClass("UIStroke"):Destroy()
            icon(tab,({Home="Home",Main="Combat",Aimbot="Visuals",Skill="Instakill",["Mob Farm"]="Farm",["Boss Farm"]="Defense",
                Quests="List",Dungeon="Dungeon",Raids="Dungeon",World="Location",Teleport="Location",Player="Player",
                Visuals="Visuals",Config="Config",Webhook="Webhook"})[name] or name,UDim2.fromOffset(20,7),19)
            local title=label(tab,text,UDim2.new(1,-52,1,0));title.Position=UDim2.fromOffset(52,0)
            title.Font=Enum.Font.Gotham;title.TextSize=14;title.TextColor3=C.Muted
            UI.Pages[name].Tab=tab;UI.Pages[name].Title=title
            record.Tabs[name]=true
            connect(tab.Activated,function() UI:SelectPage(name) end)
        end
    end
end
function UI:SelectPage(name)
    if not self.Pages[name] then return end
    self:CloseDropdown()
    self.ActivePage=name
    for n,p in pairs(self.Pages) do
        p.Frame.Visible=n==name
        p.Tab.BackgroundTransparency=n==name and 0 or 1
        p.Title.TextColor3=n==name and C.Text or C.Muted
    end
    for _,group in ipairs(self.NavGroups or {}) do
        if group.Tabs[name] and not group.Open then
            group.Open=true;group.Body.Visible=true;group.Heading.Text="  "..group.Title.."  ▾"
        end
    end
end
local function section(pageName,column,title)
    local frame=make("Frame", {Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=C.Panel,BorderSizePixel=0},UI.Pages[pageName].Columns[column])
    frame.LayoutOrder=#UI.Sections+1
    corner(frame,4); outline(frame); stack(frame,0)
    local header=button(frame,"",UDim2.new(1,0,0,35)); header.LayoutOrder=0
    header.BackgroundTransparency=1; header:FindFirstChildOfClass("UIStroke"):Destroy()
    icon(header,SectionIcons[title] or title,UDim2.fromOffset(8,7),21)
    local heading=label(header,title,UDim2.new(1,-63,1,0)); heading.Position=UDim2.fromOffset(36,0); heading.TextTruncate=Enum.TextTruncate.AtEnd
    local arrow=icon(header,"Chevron",UDim2.new(1,-26,0,9),18,C.Text)
    make("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.Line,BorderSizePixel=0},header)
    local body=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,LayoutOrder=1},frame); pad(body,7); stack(body,5)
    local s={Page=pageName,Column=column,Frame=frame,Header=header,Body=body,Title=title,Rows={},Collapsed=false,Chevron=arrow}
    table.insert(UI.Sections,s)
    connect(header.Activated,function() s.Collapsed=not s.Collapsed; UI:Filter() end)
    return s
end
local function row(s,text,height)
    local r=make("Frame", {Size=UDim2.new(1,0,0,height or 25), BackgroundTransparency=1, LayoutOrder=#s.Rows+1},s.Body)
    table.insert(s.Rows,{Node=r,Text=text})
    return r
end
local function note(s,text)
    local r=row(s,text,0); r.AutomaticSize=Enum.AutomaticSize.Y
    local l=label(r,text,UDim2.new(1,0,0,0)); l.AutomaticSize=Enum.AutomaticSize.Y; l.TextWrapped=true; l.TextColor3=C.Muted
end
local function toggle(s,id,text,default,keybind)
    local r=row(s,text,22)
    local l=label(r,text,UDim2.new(1,keybind and -88 or -43,1,0)); l.TextTruncate=Enum.TextTruncate.AtEnd
    local b=button(r,"",UDim2.fromOffset(34,20)); b.Position=UDim2.new(1,-34,.5,-10); corner(b,10)
    local dot=make("Frame", {Size=UDim2.fromOffset(14,14),Position=UDim2.fromOffset(3,3),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},b); corner(dot,8)
    UI.Values[id]=default==true
    local function paint()
        b.BackgroundColor3=UI.Values[id] and C.Accent or C.Field
        dot.Position=UDim2.fromOffset(UI.Values[id] and 17 or 3,3)
        l.TextColor3=UI.Values[id] and C.Text or C.Muted
    end
    local function flip() UI:Emit(id,not UI.Values[id]); paint() end
    connect(b.Activated,flip); paint()
    if keybind then
        local keyButton=button(r,"None",UDim2.fromOffset(42,20)); keyButton.Position=UDim2.new(1,-82,.5,-10); keyButton.TextSize=14
        local selected
        connect(keyButton.Activated,function()
            if binding then binding.Cancel() end
            keyButton.Text="..."
            binding={Set=function(key)
                selected=key~=Enum.KeyCode.Escape and key or nil
                keyButton.Text=selected and selected.Name or "None"
            end,Cancel=function() keyButton.Text=selected and selected.Name or "None" end}
        end)
        connect(Input.InputBegan,function(input,processed)
            if not processed and not binding and not Input:GetFocusedTextBox() and selected and input.KeyCode==selected then flip() end
        end)
    end
    local function set(value,fire)
        UI.Values[id]=value==true; paint()
        if fire then UI:Emit(id,UI.Values[id]) end
    end
    UI.Controls[id]={Kind="toggle",Frame=r,Button=b,Get=function() return UI.Values[id] end,Set=set}
    return r,UI.Controls[id].Get,set
end
-- Defer key assignment so the binding keystroke does not also flip a toggle.
connect(Input.InputBegan,function(input)
    if binding and input.UserInputType==Enum.UserInputType.Keyboard then
        local pending=binding
        task.defer(function() if binding==pending then pending.Set(input.KeyCode); binding=nil end end)
    end
end)
local function action(s,id,text,callback)
    local b=button(row(s,text,26),text)
    connect(b.Activated,function()
        UI:Emit(id,true)
        if callback then callback() else footer.Text=text.." · UI only" end
    end)
end
local function field(s,id,text,placeholder)
    local r=row(s,text,51); label(r,text)
    local b=textbox(r,placeholder); b.Position=UDim2.fromOffset(0,23)
    UI.Values[id]=""
    connect(b.FocusLost,function() UI:Emit(id,b.Text) end)
    return b
end
local function slider(s,id,text,min,max,default,suffix)
    default=math.clamp(tonumber(default) or min,min,max)
    local step=min<1 and 0.1 or 1
    local r=row(s,text,46); label(r,text)
    local bar=button(r,"",UDim2.new(1,0,0,17)); corner(bar,2); bar.Position=UDim2.fromOffset(0,25); bar.ClipsDescendants=true
    local fill=make("Frame", {Size=UDim2.fromScale(0,1),BackgroundColor3=C.Accent,BorderSizePixel=0},bar)
    local value=label(bar,"",UDim2.fromScale(1,1)); value.TextXAlignment=Enum.TextXAlignment.Center; value.TextSize=14; value.ZIndex=2
    UI.Values[id]=default
    local function paint(v) fill.Size=UDim2.fromScale((v-min)/math.max(max-min,0.000001),1); value.Text=string.format("%.3g",v)..(suffix or "").." / "..max..(suffix or "") end
    local function update(x)
        local ratio=math.clamp((x-bar.AbsolutePosition.X)/math.max(1,bar.AbsoluteSize.X),0,1)
        local v=math.floor((min+(max-min)*ratio)/step+.5)*step
        v=math.clamp(v,min,max)
        UI:Emit(id,v); paint(v)
    end
    connect(bar.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            sliding={Input=input,Update=update}; update(input.Position.X)
        end
    end); paint(default)
    local function set(v,fire)
        v=math.clamp(tonumber(v) or min,min,max);UI.Values[id]=v;paint(v)
        if fire then UI:Emit(id,v) end
    end
    UI.Controls[id]={Kind="slider",Frame=r,Set=set,Bar=bar}
    return r,set
end
local function dropdown(s,id,text,options,multi,default)
    options=options or {}
    local r=row(s,text,0); r.AutomaticSize=Enum.AutomaticSize.Y; stack(r,4)
    local title=label(r,text); title.LayoutOrder=0
    local choose=button(r,"---"); choose.LayoutOrder=1; choose.TextXAlignment=Enum.TextXAlignment.Left; pad(choose,6)
    choose.TextTruncate=Enum.TextTruncate.AtEnd
    choose:FindFirstChildOfClass("UIPadding").PaddingRight=UDim.new(0,25)
    local choiceArrow=icon(choose,"Chevron",UDim2.new(1,-17,0,1),15,C.Muted)
    local panel=make("Frame",{Size=UDim2.new(1,0,0,195),BackgroundColor3=C.Background,BorderSizePixel=0,Visible=false,LayoutOrder=2},r)
    outline(panel); corner(panel,3); pad(panel,5)
    local find=textbox(panel,"Search...")
    local list=make("ScrollingFrame",{Position=UDim2.fromOffset(0,32),Size=UDim2.new(1,0,1,-32),BackgroundTransparency=1,
        BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollBarThickness=3,ScrollBarImageColor3=C.Accent},panel); stack(list,2)
    local selected={}; local optionRows={}
    if multi then for _,v in ipairs(default or {}) do selected[v]=true end else selected[default or ""]=true end
    local function refresh(emit)
        local names={}
        for _,v in ipairs(options) do if selected[v] then table.insert(names,v) end end
        local value=multi and names or names[1]
        if not multi and not value then for chosen,on in pairs(selected) do if on and chosen~="" then value=chosen;break end end end
        choose.Text=multi and (#names>0 and table.concat(names,", ") or "---") or tostring(value or "---")
        for _,entry in ipairs(optionRows) do
            entry.Button.Text=(multi and (selected[entry.Name] and "[✓] " or "[ ] ") or "")..entry.Name
            entry.Button.TextColor3=selected[entry.Name] and C.Accent or C.Muted
        end
        if emit then UI:Emit(id,value) else UI.Values[id]=value end
    end
    for _,name in ipairs(options) do
        local b=button(list,name,UDim2.new(1,-5,0,25)); b.TextXAlignment=Enum.TextXAlignment.Left; b.BackgroundTransparency=1
        b:FindFirstChildOfClass("UIStroke"):Destroy(); b.TextTruncate=Enum.TextTruncate.AtEnd
        table.insert(optionRows,{Name=name,Button=b})
        connect(b.Activated,function()
            if multi then selected[name]=not selected[name] else selected={[name]=true}; panel.Visible=false; choiceArrow.Rotation=0 end
            refresh(true)
        end)
    end
    local empty=label(list,"No results"); empty.TextColor3=C.Muted; empty.Visible=false; empty.LayoutOrder=999
    connect(find:GetPropertyChangedSignal("Text"),function()
        local count=0
        for _,entry in ipairs(optionRows) do entry.Button.Visible=contains(entry.Name,find.Text); if entry.Button.Visible then count=count+1 end end
        empty.Visible=count==0; list.CanvasPosition=Vector2.new(0,0)
    end)
    local function closeList() panel.Visible=false;choiceArrow.Rotation=0 end
    connect(choose.Activated,function()
        local opening=not panel.Visible
        UI:CloseDropdown()
        panel.Visible=opening;choiceArrow.Rotation=opening and 180 or 0
        if opening then find:CaptureFocus() end
    end)
    local function set(value,fire)
        selected={}
        if multi then for _,v in ipairs(value or {}) do selected[v]=true end
        elseif value~=nil then selected[value]=true end
        refresh(fire==true)
    end
    refresh(false)
    local control={Kind="dropdown",Frame=r,Button=choose,Search=find,Options=optionRows,Panel=panel,Close=closeList,Set=set,Get=function() return UI.Values[id] end}
    UI.Controls[id]=control;table.insert(UI.Dropdowns,control)
    return r,control.Get,set,closeList,control
end


-- Backend adapter: carries behavior from the user's modules into the native UI.
local T={Text=C.Text,Sub=C.Muted,Accent=C.Accent,Mint=C.Accent,Gold=Color3.fromRGB(216,177,135),Danger=Color3.fromRGB(245,88,108),Card=C.Field,Stroke=C.Line}
local destinations={['Mob Farm']='Mob Farm',['Boss Farm']='Boss Farm',Combat='Combat tools',Skill='Skill',Player='Player',Teleport='Teleport',
    World='World',Visuals='ESP tools',Settings='Config',Quests='Quests',Dungeon='Dungeon',Raids='Raids',Status='Home'}
local sectionNames={Movement='Character',['NPCs — ทุกโซน']='Teleport to NPC',Players='Teleport to player',
    ['ESP ผู้เล่น']='Players',['ESP NPC ใน ActiveNpcs']='Mobs',['Auto Skills']='Auto Skill',['Mob farm (on/off)']='Mob Farm',
    ['Performance / ประสิทธิภาพ']='Performance',Interface='Menu',['Boss Selection']='Boss selection'}
local controlNames={['วิ่งไว']='Walk speed',['ความเร็ววิ่ง']='Speed',['บิน']='Fly',['ความเร็วบิน']='Fly speed'}
local serial=0
local function nextID(handle,text)
    serial=serial+1
    return handle.Source.."/"..text.."#"..serial
end
local function attachPending(handle)
    for _,obj in ipairs(handle.Pending or {}) do
        obj.Parent=handle.Current.Body;obj.LayoutOrder=#handle.Current.Rows+1
        table.insert(handle.Current.Rows,{Node=obj,Text=tostring(obj.Text or "")})
    end
    handle.Pending={}
end
local function ensureSection(handle)
    if not handle.Current then
        handle.Current=section(handle.Page,handle.Column,handle.Heading)
        attachPending(handle)
    end
    return handle.Current
end
local function legacyNew(class,props,parent)
    local handle=type(parent)=="table" and parent.IsColumn and parent or nil
    if handle and not handle.Current and class=="TextLabel" then
        local obj=make(class,props,nil);obj.Font=Enum.Font.Gotham;obj.TextSize=14
        handle.Pending=handle.Pending or {};table.insert(handle.Pending,obj)
        return obj
    end
    local target=handle and ensureSection(handle).Body or parent
    local obj=make(class,props,target)
    if class=="TextLabel" then
        obj.TextWrapped=true
        obj.AutomaticSize=Enum.AutomaticSize.Y
    end
    if handle then
        local s=handle.Current
        obj.LayoutOrder=#s.Rows+1
        table.insert(s.Rows,{Node=obj,Text=tostring(props.Text or handle.Heading)})
        if obj:IsA("TextLabel") then obj.Font=Enum.Font.Gotham;obj.TextSize=14 end
    end
    return obj
end
local function legacyLabel(parent,text,size,color,font,position,frameSize)
    return legacyNew("TextLabel",{BackgroundTransparency=1,Text=text or "",TextSize=14,TextColor3=color or C.Text,
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Position=position or UDim2.new(),
        Size=frameSize or UDim2.fromScale(1,1)},parent)
end
local function stroke(parent,color,thickness) make("UIStroke",{Color=color or C.Line,Thickness=thickness or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},parent) end
function UI:Connect(signal,fn) return connect(signal,fn) end
function UI:CreatePage(source)
    local destination=assert(destinations[source],"Missing page mapping: "..source)
    local left={IsColumn=true,Source=source,Page=destination,Column=1,Heading=source}
    local right={IsColumn=true,Source=source,Page=destination,Column=2,Heading=source.." settings"}
    return left,right
end
function UI:CreateSection(handle,title,default,callback)
    if handle.Source=="Combat" then
        if title=="Aimbot" or title=="Targets" or title=="Aimbot Skills" then handle.Page="Aimbot"
        elseif title=="Combat" or title=="Attack Settings" then handle.Page="Combat tools" end
    end
    if title=="Quest unlock Dungeon • Lv65+" then handle.Page="Unlock Dungeon" end
    handle.Current=section(handle.Page,handle.Column,sectionNames[title] or title)
    attachPending(handle)
    if callback then
        local _,get,set=self:CreateToggle(handle,"Enabled",default,callback)
        return handle.Current.Frame,get,set
    end
    return handle.Current.Frame
end
function UI:CreateToggle(handle,title,default,callback)
    local id=nextID(handle,title)
    self:On(id,callback)
    local frame,get,set=toggle(ensureSection(handle),id,controlNames[title] or title,default,false)
    table.insert(self.Bindings,{Source=handle.Source,Title=title,Kind="toggle",ID=id})
    return frame,get,set
end
function UI:CreateSlider(handle,title,desc,min,max,default,suffix,callback)
    local id=nextID(handle,title)
    self:On(id,callback)
    local frame,set=slider(ensureSection(handle),id,controlNames[title] or title,min,max,default,suffix)
    table.insert(self.Bindings,{Source=handle.Source,Title=title,Kind="slider",ID=id})
    return frame
end
function UI:CreateDropdown(handle,title,desc,options,default,callback)
    local id=nextID(handle,title)
    self:On(id,callback)
    local frame,get,set,closeList,control=dropdown(ensureSection(handle),id,title,options,false,default or options[1])
    handle.LastDropdown=control
    if not callback then
        -- The legacy language selector never had a translation handler.
        control.Button.Active=false;control.Button.Selectable=false
        control.Button.AutoButtonColor=false;control.Button.TextColor3=C.Muted
        control.Button.Text=control.Button.Text.." (display only)"
    end
    table.insert(self.Bindings,{Source=handle.Source,Title=title,Kind="dropdown",ID=id})
    return frame,get,set,closeList
end
function UI:CreateButton(handle,text,callback)
    local id=nextID(handle,text)
    local r=row(ensureSection(handle),text,26)
    local b=button(r,text)
    self:On(id,function() if callback then callback(b) end end)
    connect(b.Activated,function() self:Emit(id,true) end)
    self.Controls[id]={Kind="button",Frame=r,Button=b}
    table.insert(self.Bindings,{Source=handle.Source,Title=text,Kind="button",ID=id})
    return b
end
function UI:CreateSearchRow(handle,placeholder,onSearch)
    -- Search lives INSIDE the new dropdown; do not recreate the legacy Search row.
    if handle.LastDropdown then
        local box=handle.LastDropdown.Search
        connect(box.FocusLost,function(enter) if enter and onSearch then onSearch(box.Text) end end)
        return box
    end
    local box=field(ensureSection(handle),nextID(handle,placeholder),placeholder,"Search...")
    connect(box.FocusLost,function(enter) if enter and onSearch then onSearch(box.Text) end end)
    return box
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

function UI:BuildMobFarmPage()
    local farm = self:Farm()
    local combat = self:Combat()
    local left, right = self:CreatePage("Mob Farm")

    local status = legacyLabel(
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

    local combatInfo = legacyLabel(
        right,
        "Change attack position in the Attack position card. Settings apply to mobs and bosses.",
        11,
        T.Sub,
        Enum.Font.Gotham,
        nil,
        UDim2.new(1, 0, 0, 24)
    )
    combatInfo.TextWrapped = true

    local perf = legacyLabel(
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

    local status = legacyLabel(
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

    local aimStatus = legacyLabel(
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

    local skillHint = legacyLabel(
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

    local status = legacyLabel(
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

    local invisibleHint = legacyLabel(
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

    local status = legacyLabel(
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

    local status = legacyLabel(
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

    local pushHint = legacyLabel(
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

    local cupHint = legacyLabel(
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
        self.Language,
        function(value) self:SetLanguage(value) end
    )

    self:CreateSection(left,"Keyboard")
    self.MenuKeyButton=self:CreateButton(left,"Menu key: "..self.MenuKey.Name,function(b)
        self.CapturingMenuKey=true
        b.Text="Press a key (Esc cancels)"
    end)
    self:CreateButton(left,"Reset key to RightShift",function()
        self.CapturingMenuKey=false;self.MenuKey=Enum.KeyCode.RightShift
        self.MenuKeyButton.Text="Menu key: RightShift"
    end)
    self:CreateSection(left, "Player labels")

    legacyLabel(
        left,
        "RightShift • เปิด/ปิดเมนู",
        11,
        T.Sub,
        Enum.Font.Gotham,
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

    local perfHint = legacyLabel(
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
            Side = {IsColumn=true,Source="Quests",Page="Hunter Exam",Column=1,Heading="Hunter Exam"},
        },
    }

    self.QuestSetters = self.QuestSetters or {}

    for _, entry in ipairs(entries) do
        local questName = entry.Name
        local record = quest.Quests[questName]

        local statusLabel = legacyLabel(
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

    local autoHint = legacyLabel(
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

    local status = legacyLabel(
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

    local unlockHint = legacyLabel(
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

    local status = legacyLabel(
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

    legacyLabel(
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

    local hint = legacyLabel(
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

    legacyLabel(
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
        Farm = legacyLabel(
            left,
            "Farm: ...",
            11,
            T.Text,
            Enum.Font.Gotham,
            nil,
            UDim2.new(1, 0, 0, 26)
        ),
        Target = legacyLabel(
            left,
            "Target: ...",
            11,
            T.Text,
            Enum.Font.Gotham,
            nil,
            UDim2.new(1, 0, 0, 26)
        ),
        Combat = legacyLabel(
            left,
            "Combat: ...",
            11,
            T.Text,
            Enum.Font.Gotham,
            nil,
            UDim2.new(1, 0, 0, 26)
        ),
        Jobs = legacyLabel(
            left,
            "Jobs: ...",
            10,
            T.Sub,
            Enum.Font.Gotham,
            nil,
            UDim2.new(1, 0, 0, 72)
        ),
        Error = legacyLabel(
            left,
            "Error: none",
            10,
            T.Gold,
            Enum.Font.Gotham,
            nil,
            UDim2.new(1, 0, 0, 52)
        ),
    }

    self.StatusLabels.Jobs.TextWrapped = true
    self.StatusLabels.Error.TextWrapped = true

    local note = legacyLabel(
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

        local row = legacyNew("Frame", {
            Size = UDim2.new(1, 0, 0, 78),
            BackgroundColor3 = T.Card,
            BorderSizePixel = 0,
        }, column)
        corner(row, 7)
        stroke(row, T.Stroke, 1)

        local nameLabel = legacyLabel(
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

        local regionLabel = legacyLabel(
            row,
            region,
            9,
            T.Sub,
            Enum.Font.Gotham,
            UDim2.fromOffset(10, 24),
            UDim2.new(1, -20, 0, 14)
        )

        local statusLabel = legacyLabel(
            row,
            "กำลังตรวจสอบ...",
            10,
            T.Gold,
            Enum.Font.Gotham,
            UDim2.fromOffset(10, 40),
            UDim2.new(1, -20, 0, 16)
        )

        local detailLabel = legacyLabel(
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

for _,group in ipairs(navigation) do for _,item in ipairs(group.Items) do page(item[1]) end end
buildNavigation()

-- Reference controls are intentionally UI-only until a callback is registered.
-- Integration API: UI:On("reference.defense.ragdoll", callback).
do
    local nativeSection,nativeToggle,nativeSlider,nativeDropdown,nativeField,nativeAction=section,toggle,slider,dropdown,field,action
    local order=-1000
    local function section(...)
        local s=nativeSection(...);s.Reference=true;s.Frame.LayoutOrder=order;order=order+1;return s
    end
    local function toggle(s,id,...) return nativeToggle(s,"reference."..id,...) end
    local function slider(s,id,...) return nativeSlider(s,"reference."..id,...) end
    local function dropdown(s,id,...) return nativeDropdown(s,"reference."..id,...) end
    local function field(s,id,...) return nativeField(s,"reference."..id,...) end
    local function action(s,id,text,callback)
        return nativeAction(s,"reference."..id,text,callback or function()
            footer.Text="UI preview: "..text.." (not connected)"
        end)
    end
local Lists={
    Locations={"Bamboo Grove","Bamboo Grove Sanctuary","Bamboo Grove Shrine","Butterfly Estate","Butterfly Estate Shrine","Dreamfall Hollow","Final Selection","Frost Veil Shrine"},
    NPCs={"Lucy","Tom","Chaka","Krue","Rin","Demon Slayer Mitsu","Zentaro","Mother Bear","Kaiden","Rengu"},
    Reputation={"Mizunoto","Mizunoe","Kanoto","Kanoe"},
    Items={"Item 1 (example)","Item 2 (example)","Item 3 (example)"},
    Clans={"Clan 1 (example)","Clan 2 (example)","Clan 3 (example)"},
}
do
    local s=section("Main",1,"Combat")
    toggle(s,"combat.killAura","Kill aura",false,true)
    toggle(s,"combat.range","Range",true)
    slider(s,"combat.radius","Range radius",0,40,20," studs")
    slider(s,"combat.slot","Weapon slot",1,9,1)
    toggle(s,"combat.ignoreBosses","Ignore bosses")
    toggle(s,"combat.civilians","Hit civilians")
    s=section("Main",1,"Instakill")
    toggle(s,"instakill.enabled","Instakill")
    slider(s,"instakill.range","Instakill range",0,1000,150," studs")
    slider(s,"instakill.health","Kill at or below",0,100,100,"% health")
    toggle(s,"instakill.civilians","Instakill civilians")
    toggle(s,"instakill.debug","Debug to console")
    s=section("Main",1,"Private Server")
    field(s,"private.owner","Owner username","Username")
    s=section("Main",2,"Dialogue"); toggle(s,"dialogue.auto","Auto dialogue")
    s=section("Main",2,"Defense")
    for _,v in ipairs({{"ragdoll","Anti ragdoll"},{"dash","No dash cooldown"},{"stamina","Infinite stamina"},{"horse","Infinite horse stamina"},
        {"climb","Infinite climb"},{"slowdown","No attack slowdown"},{"drowning","No drowning"},{"sun","No sun damage"},{"parry","Auto parry"}}) do toggle(s,"defense."..v[1],v[2]) end
    slider(s,"defense.parryRange","Parry range",0,30,15," studs")
    s=section("Main",2,"Training")
    toggle(s,"training.qte","Auto training QTE"); toggle(s,"training.instant","Instant training"); note(s,"Off")
    s=section("Main",2,"Black market")
    toggle(s,"market.auto","Auto buy from the Black Market",false,true)
    dropdown(s,"market.items","Items",Lists.Items,true); note(s,"Off")
    s=section("Main",2,"Clan roll")
    toggle(s,"clan.auto","Auto roll clan"); dropdown(s,"clan.keep","Keep",Lists.Clans,true); note(s,"Off")
end

do
    for i,name in ipairs({"Players","Mobs"}) do
        local prefix=string.lower(name)
        local s=section("Visuals",i,name)
        toggle(s,prefix..".enabled","Enabled",false,true)
        for _,v in ipairs({{"name","Name"},{"distance","Distance"},{"box","Box"},{"fill","Box fill"},{"box3d","3D box"},{"healthBar","Health bar"},
            {"healthNumber","Health number"},{"tracer","Tracer"},{"arrow","Off-screen arrow"}}) do toggle(s,prefix.."."..v[1],v[2]) end
        slider(s,prefix..".maxDistance","Max distance",0,5000,1000," studs")
        slider(s,prefix..".textSize","Text size",8,30,13)
        toggle(s,prefix..".fade","Fade with distance")
    end
end

do
    local s=section("Player",1,"Character")
    toggle(s,"character.walk","Walk speed",false,true); slider(s,"character.speed","Speed",0,150,40)
    toggle(s,"character.fly","Fly",false,true); slider(s,"character.flySpeed","Fly speed",0,200,60)
    toggle(s,"character.noclip","Noclip",false,true); toggle(s,"character.jump","Infinite jump",false,true)
    s=section("Player",1,"Teleport to location")
    dropdown(s,"teleport.location","Location",Lists.Locations)
    action(s,"teleport.go","Teleport"); action(s,"teleport.market","Teleport to the Black Marketer"); action(s,"teleport.stop","Stop travelling")
    s=section("Player",1,"Performance"); note(s,"off")
    toggle(s,"performance.optimise","Optimise"); toggle(s,"performance.rendering","Stop rendering")
    toggle(s,"performance.cap","Cap FPS"); slider(s,"performance.fps","FPS",25,120,35)
    s=section("Player",2,"Muzan")
    action(s,"muzan.teleport","Teleport to Muzan"); action(s,"muzan.lair","Teleport to Muzan's lair (Sunless)")
    action(s,"muzan.doctor","Teleport to Dr. Higoshima"); action(s,"muzan.safe","Teleport to the safe zone")
    toggle(s,"muzan.lilies","Auto spider lilies"); toggle(s,"muzan.hop","Server hop when none left"); note(s,"Off")
    toggle(s,"muzan.demon","Become a demon"); dropdown(s,"muzan.reputation","Reputation mob",Lists.Reputation,false,"Mizunoto")
    toggle(s,"muzan.blood","Drink Muzan's Blood"); note(s,"Off")
    s=section("Player",2,"Teleport to NPC")
    dropdown(s,"teleport.npc","NPC, mob or boss",Lists.NPCs)
    action(s,"teleport.npcGo","Teleport")
end

do
    local s=section("Webhook",1,"Discord")
    toggle(s,"webhook.enabled","Discord webhook")
    field(s,"webhook.url","Webhook URL","https://discord.com/api/webhooks/...")
    field(s,"webhook.user","Ping user id","Discord user id")
    toggle(s,"webhook.everyone","Ping everyone"); toggle(s,"webhook.rich","Rich layout",true)
    toggle(s,"webhook.username","Include username",true); toggle(s,"webhook.spoiler","Hide username in a spoiler",true)
    note(s,"Nothing sent yet"); action(s,"webhook.test","Send test")
    s=section("Webhook",2,"Notifications")
    dropdown(s,"webhook.events","Ping for",{"Boss killed","Item looted","Quest completed","Chest opened","Server hop"},true,{"Boss killed","Item looted"})
    s=section("Webhook",2,"On every card")
    for _,v in ipairs({{"session","Session time"},{"level","Level"},{"exp","Exp gained"},{"wen","Wen earned"},{"mobs","Mobs killed"},{"bosses","Bosses killed"},
        {"items","Items looted"},{"chests","Chests opened"},{"quests","Quests completed"},{"hops","Server hops"},{"rates","Per hour rates"}}) do toggle(s,"card."..v[1],v[2],v[1]~="hops") end
    note(s,"Session  0m 0s\nKills    0\nBosses   0\nItems    0\nChests   0")
    action(s,"webhook.reset","Reset session")
end

do
    local s=section("Config",1,"Menu")
    action(s,"menu.keyboard","Change menu key",function() UI.CapturingMenuKey=true;UI.MenuKeyButton.Text="Press a key (Esc cancels)";footer.Text="Press a keyboard key; Esc cancels" end)
    action(s,"menu.unload","Unload",function() UI.Ctx:Shutdown() end)
    toggle(s,"menu.autoSave","Auto save",true)
    s=section("Config",1,"Account"); note(s,player.DisplayName.."\n@"..player.Name)
    s=section("Config",1,"Themes")
    for _,v in ipairs({{"background","Background color","#0C0C0F"},{"main","Main color","#17171C"},{"accent","Accent color","#CA394E"},
        {"outline","Outline color","#353237"},{"font","Font color","#EFEAED"}}) do field(s,"theme."..v[1],v[2],v[3]) end
    dropdown(s,"theme.face","Font Face",{"Code","Gotham","SourceSans","RobotoMono"},false,"Gotham")
    field(s,"theme.image","Background Image","rbxassetid://...")
    dropdown(s,"theme.list","Theme list",{"Default","Dark","Soft Red"},false,"Default")
    s=section("Config",2,"Configuration")
    field(s,"config.name","Config name",""); action(s,"config.create","Create config")
    dropdown(s,"config.list","Config list",{"Default"})
    for _,v in ipairs({{"load","Load config"},{"overwrite","Overwrite config"},{"delete","Delete config"},{"refresh","Refresh list"},
        {"autoload","Set as autoload"},{"resetAutoload","Reset autoload"}}) do action(s,"config."..v[1],v[2]) end
    note(s,"Current autoload config:\nNone")
    field(s,"config.json","Config JSON","")
    action(s,"config.import","Import config"); action(s,"config.export","Export current config")
end

end

-- Native layout only: no BuildTabs, old Sidebar, old columns, or legacy page frames.
-- Hide the untouched reference/demo cards. Every visible primary page below is backed by live modules.
for _,s in ipairs(self.Sections) do
    if s.Reference then
        s.Frame.Visible=false
        s.DisabledReference=true
    end
end

self:BuildCombatPage()
self:BuildMobFarmPage()
self:BuildBossFarmPage()
self:BuildPlayerPage()
self:BuildTeleportPage()
self:BuildDungeonPage()
self:BuildVisualsPage()
self:BuildSettingsPage()
self:BuildQuestsPage()
self:BuildRaidsPage()
self:BuildWorldPage()
self:BuildSkillPage()
self:BuildStatusPage()

do
    local farm=self:Farm()
    local combat=self:Combat()
    local aimbot=self:Aimbot()
    local skill=self:Skill()
    local quest=self:Quest()
    local world=self:World()
    local playerModule=self:Player()
    local teleport=self:Teleport()
    local visuals=self:Visuals()
    local settings=self:Settings()

    local function top(s,orderValue)
        s.Frame.LayoutOrder=orderValue or -5000
        return s
    end

    -- MAIN: real quick controls.
    local s=top(section("Main",1,"Combat"),-7000)
    toggle(s,"live.main.autoAttack","Auto Attack",farm.AutoAttack==true)
    self:On("live.main.autoAttack",function(on)
        farm.AutoAttack=on
        if not on then combat:ReleaseAttack() end
    end)
    toggle(s,"live.main.fastAttack","Fast Attack",farm.FastAttack==true)
    self:On("live.main.fastAttack",function(on)
        farm.FastAttack=on
        combat:ResetProgress()
    end)
    toggle(s,"live.main.comboReset","Continuous Combo Reset",farm.BypassComboGate==true)
    self:On("live.main.comboReset",function(on)
        farm.BypassComboGate=on
        if on then combat:BindGameComboGate() else combat:UnbindGameComboGate() end
    end)
    slider(s,"live.main.attackRange","Attack range",5,25,farm.AttackRange or 12," studs")
    self:On("live.main.attackRange",function(v) farm.AttackRange=v end)
    dropdown(s,"live.main.weapon","Weapon slot",{"ช่อง 1","ช่อง 2","ช่อง 3","ช่อง 4","ช่อง 5"},false,farm.SelectedWeapon or "ช่อง 1")
    self:On("live.main.weapon",function(v)
        farm.SelectedWeapon=v
        farm._lastHotbarSelection=nil
        farm._lastHotbarCharacter=nil
        combat.EquipReadyAt=0
    end)

    s=top(section("Main",2,"Aimbot"),-7000)
    toggle(s,"live.main.aimbot","Aimbot",aimbot.Enabled==true)
    self:On("live.main.aimbot",function(on) aimbot:SetEnabled(on) end)
    toggle(s,"live.main.showFov","Show FOV circle",aimbot.ShowFOV==true)
    self:On("live.main.showFov",function(on) aimbot:SetShowFOV(on) end)
    slider(s,"live.main.fov","FOV radius",50,500,aimbot.FOV or 180," px")
    self:On("live.main.fov",function(v) aimbot:SetFOV(v) end)
    toggle(s,"live.main.skillAim","Skill Aimbot",aimbot.SkillEnabled==true)
    self:On("live.main.skillAim",function(on) aimbot:SetSkillEnabled(on) end)

    s=top(section("Main",1,"Quest"),-6900)
    toggle(s,"live.main.autoQuest","Auto Quest",farm.AutoQuest==true)
    self:On("live.main.autoQuest",function(on) quest:SetAutoQuest(on) end)
    toggle(s,"live.main.autoSkills","Auto Skills",skill.Enabled==true)
    self:On("live.main.autoSkills",function(on) skill:SetEnabled(on) end)

    s=top(section("Main",2,"Training"),-6900)
    toggle(s,"live.main.pushups","Auto Pushups",world.Pushups.Enabled==true)
    self:On("live.main.pushups",function(on) world:SetPushupsEnabled(on) end)
    toggle(s,"live.main.thunder","Auto Thunder Breathing",world.Thunder.Enabled==true)
    self:On("live.main.thunder",function(on) world:SetThunderEnabled(on) end)
    toggle(s,"live.main.cup","Cup2 ESP",world.Cup.Enabled==true)
    self:On("live.main.cup",function(on) world:SetCupEnabled(on) end)

    s=top(section("Main",2,"Defense"),-6800)
    toggle(s,"live.main.god","God Mode (local)",playerModule.GodModeEnabled==true)
    self:On("live.main.god",function(on) playerModule:SetGodMode(on) end)
    toggle(s,"live.main.noclip","No Clip",playerModule.NoClipEnabled==true)
    self:On("live.main.noclip",function(on) playerModule:SetNoClip(on) end)

    -- PLAYER is populated by BuildPlayerPage(), now mapped directly to the Player page.

    -- VISUALS: real ESP controls.
    s=top(section("Visuals",1,"Players"),-7000)
    toggle(s,"live.visuals.players","Player ESP",visuals.Enabled==true)
    self:On("live.visuals.players",function(on) visuals:SetPlayerESP(on) end)
    toggle(s,"live.visuals.lines","Tracer / ESP Line",visuals.Lines==true)
    self:On("live.visuals.lines",function(on) visuals:SetLines(on) end)
    toggle(s,"live.visuals.outlines","Outline",visuals.Outlines==true)
    self:On("live.visuals.outlines",function(on) visuals:SetOutlines(on) end)
    toggle(s,"live.visuals.distance","Show distance",visuals.ShowDistance~=false)
    self:On("live.visuals.distance",function(on) visuals:SetShowDistance(on) end)
    toggle(s,"live.visuals.hideAim","Hide when aiming",visuals.HideWhenAiming==true)
    self:On("live.visuals.hideAim",function(on) visuals:SetHideWhenAiming(on) end)
    slider(s,"live.visuals.max","Max distance",100,5000,visuals.MaxDistance or 1000," studs")
    self:On("live.visuals.max",function(v) visuals:SetMaxDistance(v) end)

    s=top(section("Visuals",2,"Mobs"),-7000)
    toggle(s,"live.visuals.bandit","ESP Bandit",visuals.Bandit==true)
    self:On("live.visuals.bandit",function(on) visuals:SetBandit(on) end)
    toggle(s,"live.visuals.civilian","ESP Civilian",visuals.Civilian==true)
    self:On("live.visuals.civilian",function(on) visuals:SetCivilian(on) end)
    toggle(s,"live.visuals.bosses","ESP Boss All",visuals.BossEnabled==true)
    self:On("live.visuals.bosses",function(on) visuals:SetBossEnabled(on) end)
    toggle(s,"live.visuals.hitbox","Monster hitbox ESP",visuals.MonsterHitboxESP==true)
    self:On("live.visuals.hitbox",function(on) visuals:SetMonsterHitboxESP(on) end)

    -- WEBHOOK: real test sender. No automatic event spam; only sends when enabled/tested.
    s=top(section("Webhook",1,"Discord"),-7000)
    toggle(s,"live.webhook.enabled","Discord webhook",false)
    field(s,"live.webhook.url","Webhook URL","https://discord.com/api/webhooks/...")
    field(s,"live.webhook.user","Ping user id","Discord user id")
    toggle(s,"live.webhook.everyone","Ping everyone",false)
    toggle(s,"live.webhook.username","Include username",true)

    local function getRequest()
        local env=type(getgenv)=="function" and getgenv() or _G
        local synTable=rawget(env,"syn")
        return (synTable and synTable.request)
            or rawget(env,"http_request")
            or rawget(env,"request")
    end

    action(s,"live.webhook.test","Send test",function()
        if UI.Values["live.webhook.enabled"]~=true then
            footer.Text="Webhook is disabled"
            return
        end

        local url=tostring(UI.Values["live.webhook.url"] or "")
        if url=="" then
            footer.Text="Webhook URL is empty"
            return
        end

        local requestFn=getRequest()
        if type(requestFn)~="function" then
            footer.Text="This executor has no HTTP request function"
            return
        end

        local content="MazaSpace webhook test"
        local userId=tostring(UI.Values["live.webhook.user"] or "")
        if UI.Values["live.webhook.everyone"]==true then
            content="@everyone "..content
        elseif userId~="" then
            content="<@"..userId.."> "..content
        end

        if UI.Values["live.webhook.username"]==true then
            content=content.." • "..player.Name
        end

        local http=game:GetService("HttpService")
        local ok,response=pcall(function()
            return requestFn({
                Url=url,
                Method="POST",
                Headers={["Content-Type"]="application/json"},
                Body=http:JSONEncode({content=content}),
            })
        end)

        local statusCode=ok and response and (response.StatusCode or response.Status) or nil
        if ok and (statusCode==nil or tonumber(statusCode)<400) then
            footer.Text="Webhook test sent"
        else
            footer.Text="Webhook test failed: "..tostring(statusCode or response)
        end
    end)

    s=top(section("Webhook",2,"Notifications"),-7000)
    note(s,"Webhook test is connected. Automatic event notifications can be added later without changing this UI.")

    -- CONFIG already has live Settings controls below; keep a short live status card at the top.
    s=top(section("Config",1,"MazaSpace"),-7000)
    note(s,"Settings on this page are connected: language, menu key, labels, FPS boost, blur and animations.")
end

note(section("Home",1,"Interface status"),"All visible primary menus are connected to live module callbacks. Detailed controls remain available in the tools pages.")

do
    local q=self:Quest()
    local record=q.Quests.UnlockMarket
    local s=section("Unlock Market",1,"Unlock Market • Lv 45")
    local _,_,set=toggle(s,"quest.unlockMarket","Auto Unlock Market",record and record.Enabled or false)
    self.QuestSetters.UnlockMarket=set
    self:On("quest.unlockMarket",function(on) q:SetDedicatedEnabled("UnlockMarket",on) end)
    local status=label(s.Body,record and record.Status or "Unlock Market • OFF",UDim2.new(1,0,0,0))
    status.TextWrapped=true;status.AutomaticSize=Enum.AutomaticSize.Y;status.LayoutOrder=2
    if record then
        record.OnStatus=function(text) status.Text=text end
        record.OnEnabled=function(on) set(on,false) end
    end
    note(s,"Ginzo → Accept quest → Jewelry Box1 → Hold T → Return to Ginzo")
    note(section("Unlock Market",2,"Quest details"),"Ill find the jewelry box(Lv 45)\nGinzo: 273.80, 944.00, 528.19\nBox: 1874.20, 687.75, -729.42\nOne run per activation. Check the game's unlock confirmation after turn-in.")
end


-- Shared live settings: both farming pages edit the same movement configuration.
do
    local farm=self:Farm()
    local linked={}
    local function sync()
        for _,controls in ipairs(linked) do
            controls.mode.Set(farm.AttackPosition,false)
            controls.gap.Set(farm.HeadHeight,false)
            controls.distance.Set(farm.BehindDistance,false)
            controls.height.Set(farm.BehindHeight,false)
        end
    end
    for _,pageName in ipairs({"Mob Farm","Boss Farm"}) do
        local s=section(pageName,2,"Attack position")
        s.Frame.LayoutOrder=-2000
        local prefix="attackPose."..pageName.."."
        dropdown(s,prefix.."mode","Position",{"Above head","Below feet","Behind","Above and behind"},false,farm.AttackPosition)
        slider(s,prefix.."gap","Above / below gap",.5,20,farm.HeadHeight," studs")
        slider(s,prefix.."distance","Behind distance",1,30,farm.BehindDistance," studs")
        slider(s,prefix.."height","Behind height",-10,20,farm.BehindHeight," studs")
        table.insert(linked,{mode=self.Controls[prefix.."mode"],gap=self.Controls[prefix.."gap"],distance=self.Controls[prefix.."distance"],height=self.Controls[prefix.."height"]})
        self:On(prefix.."mode",function(v) farm:SetAttackPosition(v);sync() end)
        self:On(prefix.."gap",function(v) farm:SetAttackPosition(nil,v);sync() end)
        self:On(prefix.."distance",function(v) farm:SetAttackPosition(nil,nil,v);sync() end)
        self:On(prefix.."height",function(v) farm:SetAttackPosition(nil,nil,nil,v);sync() end)
        note(s,"Shared by mob and boss farming. Changes apply immediately. Large offsets may put attacks out of range.")
    end
end

local boxESP=section("Visuals",2,"Monster hitbox ESP")
local visuals=self:Visuals()
self:On("visuals.monsterHitboxBox",function(on) visuals:SetMonsterHitboxESP(on) end)
toggle(boxESP,"visuals.monsterHitboxBox","Yellow hitbox outline",visuals.MonsterHitboxESP)
note(boxESP,"Yellow outline follows each monster HumanoidRootPart.")
local god=section("Player",2,"God Mode")
local playerModule=self:Player()
self:On("player.godMode",function(on) playerModule:SetGodMode(on) end)
toggle(god,"player.godMode","God Mode (local)",playerModule.GodModeEnabled)
note(god,"Local healing and ForceField; server damage rules may override it.")
-- The supplied backend has no webhook implementation. Keep the original tab honest.

local menu=section("Config",1,"MazaSpace")
note(menu,"Default key: RightShift (change in Settings)\nDrag the M circle to move it")
action(menu,"menu.unload","Unload",function() self.Ctx:Shutdown() end)
-- Place the familiar primary cards first while retaining every real control below them.
local order={["Monster hitbox ESP"]=-2,["God Mode"]=-2,Combat=0,Character=0,Players=0,Mobs=0,['Mob Farm']=0,['Auto Dungeon']=0}
for _,s in ipairs(self.Sections) do
    if not s.Reference and order[s.Title] then s.Frame.LayoutOrder=order[s.Title] end
end
self:SelectPage("Main")
self:Filter()
self.Ctx:RegisterJob("UIStatus",0.5,function() if self.Gui and self.Gui.Parent then self:RefreshStatus() end end)
self:RefreshStatus()
end
return UI



