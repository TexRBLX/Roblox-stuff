-- might keep idk, relies on sense

local RunService = game:GetService("RunService")
local EspController = {}
EspController.modules = {}

function EspController:RegisterModule(moduleName: string, config: table)

    assert(typeof(moduleName) == "string", "moduleName must be a string")
    assert(typeof(config) == "table", "config must be a table")
    assert(config.targetFolder, "config.targetFolder must be provided")
    assert(typeof(config.createFunction) == "function", "config.createFunction must be a function")

    self.modules[moduleName] = {
        handlerType = config.handlerType or "event", -- Default to 'event'
        targetFolder = config.targetFolder,
        createFunction = config.createFunction,
        updateFunction = config.updateFunction, -- For heartbeat modules
        cleanupFunction = config.cleanupFunction, -- For heartbeat modules
        isEnabled = false,
        connections = {},
        activeObjects = {},
    }
end

function EspController:Enable(moduleName: string)
    local module = self.modules[moduleName]
    if not module or module.isEnabled then return end
    
    print(`Enabling '{moduleName}' module (Type: {module.handlerType})`)
    module.isEnabled = true

    if module.handlerType == "event" then
        -- EVENT-DRIVEN LOGIC
        local function onChildAdded(child: Instance) ... end
        local function onChildRemoved(child: Instance) ... end

        for _, child in ipairs(module.targetFolder:GetChildren()) do onChildAdded(child) end
        module.connections.added = module.targetFolder.ChildAdded:Connect(onChildAdded)
        module.connections.removed = module.targetFolder.ChildRemoved:Connect(onChildRemoved)

    elseif module.handlerType == "heartbeat" then
        -- HEARTBEAT-DRIVEN LOGIC
        assert(typeof(module.updateFunction) == "function", "Heartbeat modules require an updateFunction.")
        
        -- The update function will manage the activeObjects table itself
        module.connections.heartbeat = RunService.Heartbeat:Connect(function()
            module.updateFunction(module.activeObjects)
        end)
    end
end

function EspController:Disable(moduleName: string)
    local module = self.modules[moduleName]
    if not module or not module.isEnabled then return end

    print(`Disabling '{moduleName}' module`)
    module.isEnabled = false

    for _, connection in pairs(module.connections) do
        connection:Disconnect()
    end
    module.connections = {}

    -- For heartbeat modules, we need a custom cleanup function.
    -- For event modules, ChildRemoved handles cleanup one-by-one.
    if module.handlerType == "heartbeat" and module.cleanupFunction then
        module.cleanupFunction(module.activeObjects)
    end
    
    -- Final cleanup for any remaining objects
    for _, espObject in pairs(module.activeObjects) do
        if typeof(espObject.Destruct) == "function" then espObject:Destruct() end
    end
    module.activeObjects = {}
end

function EspController:Toggle(moduleName)
    local module = self.modules[moduleName]
    if not module then return end
    
    if module.isEnabled then
        self:Disable(moduleName)
    else
        self:Enable(moduleName)
    end
end

return EspController
