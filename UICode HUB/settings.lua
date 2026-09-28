-- MazxhubModules/settings.lua
-- Low Graphics / FPS Boost migrated from hello.txt

local Settings = {
    LowGraphicsEnabled = false,
    LowGraphics = {
        Enabled = false,
        Saved = setmetatable({}, { __mode = "k" }),
        Seen = setmetatable({}, { __mode = "k" }),
        Queue = {},
        Head = 1,
        Tail = 0,
        Connections = {},
    },
}

local function low(self)
    return self.LowGraphics
end

function Settings:Save(object, property, value)
    local mode = low(self)
    pcall(function()
        local current = object[property]
        if current == value then return end

        local properties = mode.Saved[object] or {}
        if not properties[property] then
            properties[property] = {
                Original = current,
                Applied = value,
            }
        end

        object[property] = value
        mode.Saved[object] = properties
    end)
end

function Settings:Apply(object)
    if object:IsA("BasePart") then
        self:Save(object, "CastShadow", false)
        self:Save(object, "Reflectance", 0)
        self:Save(object, "Material", Enum.Material.SmoothPlastic)
    end

    if object:IsA("MeshPart") then
        self:Save(object, "TextureID", "")
        self:Save(object, "RenderFidelity", Enum.RenderFidelity.Performance)
    elseif object:IsA("SpecialMesh") then
        self:Save(object, "TextureId", "")
    elseif object:IsA("Decal") or object:IsA("Texture") then
        self:Save(object, "Transparency", 1)
    elseif object:IsA("ParticleEmitter")
        or object:IsA("Trail")
        or object:IsA("Beam")
        or object:IsA("Fire")
        or object:IsA("Smoke")
        or object:IsA("Sparkles")
        or object:IsA("PostEffect") then

        if object.Name ~= "MazxhubFullBright" then
            self:Save(object, "Enabled", false)
        end
    elseif object:IsA("Light") then
        self:Save(object, "Shadows", false)
    elseif object:IsA("Clouds") then
        self:Save(object, "Enabled", false)
    end
end

function Settings:Restore(object)
    local mode = low(self)
    local properties = mode.Saved[object]
    mode.Saved[object] = nil

    for property, saved in pairs(properties or {}) do
        pcall(function()
            if object[property] == saved.Applied then
                object[property] = saved.Original
            end
        end)
    end
end

function Settings:Enqueue(object, expand)
    local mode = low(self)
    if not mode.Enabled then return end

    mode.Tail += 1
    mode.Queue[mode.Tail] = { object, expand }
end

function Settings:Step()
    local mode = low(self)
    local deadline = os.clock() + 0.002

    for _ = 1, 80 do
        if mode.Enabled then
            local entry = mode.Queue[mode.Head]
            if not entry then break end

            mode.Queue[mode.Head] = nil
            mode.Head += 1

            local object = entry[1]

            if object and object.Parent and not mode.Seen[object] then
                mode.Seen[object] = true
                self:Apply(object)
            end

            if object and object.Parent and entry[2] then
                for _, child in ipairs(object:GetChildren()) do
                    self:Enqueue(child, true)
                end
            end
        else
            local object = next(mode.Saved)
            if not object then break end
            self:Restore(object)
        end

        if os.clock() >= deadline then
            break
        end
    end
end

function Settings:SetLowGraphics(on)
    local mode = low(self)
    on = on == true

    if mode.Enabled == on then
        self.LowGraphicsEnabled = on
        return
    end

    mode.Enabled = on
    self.LowGraphicsEnabled = on

    for _, connection in ipairs(mode.Connections) do
        connection:Disconnect()
    end
    mode.Connections = {}

    mode.Queue = {}
    mode.Head = 1
    mode.Tail = 0
    mode.Seen = setmetatable({}, { __mode = "k" })

    if on then
        self:Save(game:GetService("Lighting"), "GlobalShadows", false)

        for _, root in ipairs({
            workspace,
            game:GetService("Lighting"),
        }) do
            table.insert(
                mode.Connections,
                root.DescendantAdded:Connect(function(object)
                    self:Enqueue(object, false)
                end)
            )

            self:Enqueue(root, true)
        end
    end
end

function Settings:Init(ctx)
    self.Ctx = ctx
end

function Settings:Start()
    self.Ctx:RegisterJob("LowGraphics", 0.02, function()
        local mode = low(self)
        if mode.Enabled or next(mode.Saved) then
            self:Step()
        end
    end)
end

function Settings:Stop()
    self:SetLowGraphics(false)

    local mode = low(self)

    for _, connection in ipairs(mode.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    mode.Connections = {}

    while next(mode.Saved) do
        self:Restore(next(mode.Saved))
    end
end

return Settings
