
local RunService = game:GetService("RunService")
local EspController = {}
EspController.modules = {}

function EspController:RegisterModule(moduleName, config)
    assert(typeof(moduleName) == "string", "moduleName must be a string")
    assert(typeof(config) == "table", "config must be a table")

    if config.handlerType == "event" or config.handlerType == nil then
        assert(config.targetFolder, "Event module '"..moduleName.."' requires a targetFolder.")
        assert(typeof(config.createFunction) == "function", "Event module '"..moduleName.."' requires a createFunction.")
    elseif config.handlerType == "heartbeat" then
        assert(typeof(config.updateFunction) == "function", "Heartbeat module '"..moduleName.."' requires an updateFunction.")
        assert(typeof(config.cleanupFunction) == "function", "Heartbeat module '"..moduleName.."' requires a cleanupFunction.")
    end

    self.modules[moduleName] = {
        handlerType = config.handlerType or "event",
        targetFolder = config.targetFolder,
        createFunction = config.createFunction,
        updateFunction = config.updateFunction,
        cleanupFunction = config.cleanupFunction,
        isEnabled = false,
        connections = {},
        activeObjects = {},
    }
end

function EspController:Enable(moduleName)
    local module = self.modules[moduleName]
    if not module or module.isEnabled then return end
    
    print(`Enabling '{moduleName}' module (Type: {module.handlerType})`)
    module.isEnabled = true

    if module.handlerType == "event" then

        local function onChildAdded(child)
            local success, espObject = pcall(module.createFunction, child)
            if success and espObject then
                module.activeObjects[child] = espObject
            end
        end

        local function onChildRemoved(child)
            if module.activeObjects[child] then
                if typeof(module.activeObjects[child].Destruct) == "function" then
                    module.activeObjects[child]:Destruct()
                end
                module.activeObjects[child] = nil
            end
        end

        for _, child in ipairs(module.targetFolder:GetChildren()) do onChildAdded(child) end
        module.connections.added = module.targetFolder.ChildAdded:Connect(onChildAdded)
        module.connections.removed = module.targetFolder.ChildRemoved:Connect(onChildRemoved)

    elseif module.handlerType == "heartbeat" then
        module.connections.heartbeat = RunService.Heartbeat:Connect(function()
            module.updateFunction(module.activeObjects)
        end)
    end
end

function EspController:Disable(moduleName)
    local module = self.modules[moduleName]
    if not module or not module.isEnabled then return end

    print(`Disabling '{moduleName}' module`)
    module.isEnabled = false

    for _, connection in pairs(module.connections) do
        connection:Disconnect()
    end
    module.connections = {}

    if module.handlerType == "heartbeat" and module.cleanupFunction then
        module.cleanupFunction(module.activeObjects)
    end
    
    for key, espObject in pairs(module.activeObjects) do
        if typeof(espObject.Destruct) == "function" then espObject:Destruct() end
        module.activeObjects[key] = nil
    end
end

function EspController:Toggle(moduleName)
    local module = self.modules[moduleName]
    if not module then
        warn("ESPController: Attempted to toggle non-existent module: " .. tostring(moduleName))
        return
    end
    
    if module.isEnabled then
        self:Disable(moduleName)
    else
        self:Enable(moduleName)
    end
end

return EspController
