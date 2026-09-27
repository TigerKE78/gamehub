-- MazxhubModules/core.lua
-- Core กลาง: Services + State + Scheduler เพียง Heartbeat เดียว

local Core = {}

function Core:Create(config)
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local VirtualInputManager = game:GetService("VirtualInputManager")

    local ctx = {
        Config = config,
        Modules = {},
        Jobs = {},
        Connections = {},
        State = {
            Running = true,
            FarmEnabled = false,
            FarmMode = nil,
            Target = nil,
            TargetName = nil,
        },
        Services = {
            RunService = RunService,
            Players = Players,
            UserInputService = UserInputService,
            VirtualInputManager = VirtualInputManager,
        },
        Player = Players.LocalPlayer,
    }

    function ctx:RegisterJob(name, interval, callback)
        self.Jobs[name] = {
            Enabled = true,
            Interval = math.max(tonumber(interval) or 0.1, 0.01),
            NextAt = 0,
            Callback = callback,
        }
    end

    function ctx:SetJobEnabled(name, enabled)
        local job = self.Jobs[name]
        if job then
            job.Enabled = enabled == true
            if job.Enabled then job.NextAt = 0 end
        end
    end

    function ctx:RemoveJob(name)
        self.Jobs[name] = nil
    end

    function ctx:GetCharacter()
        local character = self.Player and self.Player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        return character, humanoid, root
    end

    function ctx:IsAlive(model)
        if not model or not model.Parent then return false end
        local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
        return humanoid ~= nil and humanoid.Health > 0
    end

    function ctx:Shutdown()
        self.State.Running = false
        for _, module in pairs(self.Modules) do
            if type(module) == "table" and module.Stop then
                pcall(function() module:Stop() end)
            end
        end
        for _, connection in ipairs(self.Connections) do
            pcall(function() connection:Disconnect() end)
        end
        self.Connections = {}
        self.Jobs = {}
    end

    local heartbeat = RunService.Heartbeat:Connect(function()
        if not ctx.State.Running then return end

        local now = os.clock()
        for name, job in pairs(ctx.Jobs) do
            if job.Enabled and now >= job.NextAt then
                job.NextAt = now + job.Interval
                local ok, err = xpcall(job.Callback, function(message)
                    if debug and debug.traceback then
                        return debug.traceback(tostring(message), 2)
                    end
                    return tostring(message)
                end)
                if not ok then
                    warn("[Mazxhub/" .. tostring(name) .. "] " .. tostring(err))
                end
            end
        end
    end)

    table.insert(ctx.Connections, heartbeat)
    return ctx
end

return Core
