-- || This is a modified fork of Kiriot22's ESP library ||
-- || Features from Sense ESP (3D Boxes, Health Bar, Health Text) have been integrated. ||

--Services--
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

--Settings--
--Settings--
local ESP = {
    Enabled = false,
    -- 2D Box Settings
    Boxes = true,
    BoxShift = CFrame.new(0, -1.5, 0),
    BoxSize = Vector3.new(4, 6, 0),
    FaceCamera = false,
    -- 3D Box Settings
    Boxes3D = false,
    -- Health Bar & Text Settings
    HealthBars = false,
    HealthText = false,
    -- General Settings
    Names = true,
    Tracers = false, 
    TeamColor = true,
    Thickness = 2,
    AttachShift = 1,
    TeamMates = true,
    Players = true,
    Color = Color3.fromRGB(255, 170, 0),

    Objects = setmetatable({}, { __mode = "kv" }),
    Overrides = {}
}

--Declarations--
local cam = Workspace.CurrentCamera
local plr = Players.LocalPlayer

--Functions--
local function Draw(obj, props)
    local new = Drawing.new(obj)
    props = props or {}
    for i, v in pairs(props) do
        new[i] = v
    end
    return new
end

--region Helper Functions from Sense ESP
local function getBoundingBox(parts)
    local min, max;
    for i = 1, #parts do
        local part = parts[i];
        if part:IsA("BasePart") then
            local cframe, size = part.CFrame, part.Size;
            local pos = cframe.Position
            min = min and pos:Min(min) or pos
            max = max and pos:Max(max) or pos
            min = min and (cframe - size / 2).Position:Min(min) or (cframe - size / 2).Position
            max = max and (cframe + size / 2).Position:Max(max) or (cframe + size / 2).Position
        end
    end
    if not min or not max then return end
    local center = (min + max) * 0.5
    return CFrame.new(center), max - min
end

local VERTICES = {
    Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1), Vector3.new(1, 1, -1), Vector3.new(-1, 1, -1),
    Vector3.new(-1, -1, 1), Vector3.new(1, -1, 1), Vector3.new(1, 1, 1), Vector3.new(-1, 1, 1)
}

local CUBE_EDGES = {
    1, 2, 2, 3, 3, 4, 4, 1,
    5, 6, 6, 7, 7, 8, 8, 5,
    1, 5, 2, 6, 3, 7, 4, 8
}

local function calculateCorners(cframe, size)
    if not cframe or not size then return nil end
    local worldVertices = {}
    for i = 1, #VERTICES do
        worldVertices[i] = (cframe * CFrame.new(size * VERTICES[i] / 2)).Position
    end

    local screenVertices = {}
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local allOnScreen = true

    for i, worldPos in ipairs(worldVertices) do
        local screenPos, onScreen = cam:WorldToViewportPoint(worldPos)
        if not onScreen then
            allOnScreen = false
        end
        local posVec2 = Vector2.new(screenPos.X, screenPos.Y)
        screenVertices[i] = posVec2
        minX = math.min(minX, posVec2.X)
        minY = math.min(minY, posVec2.Y)
        maxX = math.max(maxX, posVec2.X)
        maxY = math.max(maxY, posVec2.Y)
    end
    
    return {
        onScreen = allOnScreen,
        vertices = screenVertices,
        topLeft = Vector2.new(minX, minY),
        bottomRight = Vector2.new(maxX, maxY)
    }
end
--endregion

function ESP:GetTeam(p)
    local ov = self.Overrides.GetTeam
    if ov then return ov(p) end
    return p and p.Team
end

function ESP:IsTeamMate(p)
    local ov = self.Overrides.IsTeamMate
    if ov then return ov(p) end
    return (self:GetTeam(p) == self:GetTeam(plr)) or (plr.Neutral)
end

function ESP:GetColor(obj)
    local ov = self.Overrides.GetColor
    if ov then return ov(obj) end
    local p = self:GetPlrFromChar(obj)
    return p and self.TeamColor and p.Team and p.Team.TeamColor.Color or self.Color
end

function ESP:GetPlrFromChar(char)
    local ov = self.Overrides.GetPlrFromChar
    if ov then return ov(char) end
    return Players:GetPlayerFromCharacter(char)
end

function ESP:Toggle(bool)
    self.Enabled = bool
    if not bool then
        for i, v in pairs(self.Objects) do
            if v.Type == "Box" then
                if v.Temporary then
                    v:Remove()
                else
                    for i, v in pairs(v.Components) do
                        v.Visible = false
                    end
                end
            end
        end
    end
end

function ESP:GetBox(obj)
    return self.Objects[obj]
end

function ESP:AddObjectListener(parent, options)
    local function NewListener(c)
        if type(options.Type) == "string" and c:IsA(options.Type) or options.Type == nil then
            if type(options.Name) == "string" and c.Name == options.Name or options.Name == nil then
                if not options.Validator or options.Validator(c) then
                    local box = ESP:Add(c, {
                        PrimaryPart = type(options.PrimaryPart) == "string" and c:WaitForChild(options.PrimaryPart) or type(options.PrimaryPart) == "function" and options.PrimaryPart(c),
                        Color = type(options.Color) == "function" and options.Color(c) or options.Color,
                        ColorDynamic = options.ColorDynamic,
                        Name = type(options.CustomName) == "function" and options.CustomName(c) or options.CustomName,
                        IsEnabled = options.IsEnabled,
                        RenderInNil = options.RenderInNil
                    })
                    if options.OnAdded then
                        coroutine.wrap(options.OnAdded)(box)
                    end
                end
            end
        end
    end

    if options.Recursive then
        parent.DescendantAdded:Connect(NewListener)
        for i, v in pairs(parent:GetDescendants()) do
            coroutine.wrap(NewListener)(v)
        end
    else
        parent.ChildAdded:Connect(NewListener)
        for i, v in pairs(parent:GetChildren()) do
            coroutine.wrap(NewListener)(v)
        end
    end
end

local boxBase = {}
boxBase.__index = boxBase

function boxBase:Remove()
    ESP.Objects[self.Object] = nil
    for i, v in pairs(self.Components) do
        if type(v) == "table" then -- Handle nested tables like Box3D
            for _, line in ipairs(v) do
                line:Remove()
            end
        else
            v:Remove()
        end
    end
    table.clear(self.Components)
end

function boxBase:Update()
    if not self.PrimaryPart or not self.PrimaryPart.Parent then
        return self:Remove()
    end
    
    local color = self.Color or self.ColorDynamic and self:ColorDynamic() or ESP:GetColor(self.Object) or ESP.Color

    local allow = true
    if ESP.Overrides.UpdateAllow and not ESP.Overrides.UpdateAllow(self) then allow = false end
    if self.Player and not ESP.TeamMates and ESP:IsTeamMate(self.Player) then allow = false end
    if self.Player and not ESP.Players then allow = false end
    if self.IsEnabled and (type(self.IsEnabled) == "string" and not ESP[self.IsEnabled] or type(self.IsEnabled) == "function" and not self:IsEnabled()) then allow = false end
    if not Workspace:IsAncestorOf(self.PrimaryPart) and not self.RenderInNil then allow = false end

    if not allow then
        for i, v in pairs(self.Components) do
            if type(v) == "table" then
                for _, line in ipairs(v) do line.Visible = false end
            else
                v.Visible = false
            end
        end
        return
    end

    local allParts = self.Object:IsA("Model") and self.Object:GetChildren() or {self.Object}
    local cframe, size = getBoundingBox(allParts)
    local corners = calculateCorners(cframe, size)
    
    if not corners then
        for i, v in pairs(self.Components) do
            if type(v) == "table" then
                for _, line in ipairs(v) do line.Visible = false end
            else
                v.Visible = false
            end
        end
        return
    end

    local show3DBox = ESP.Boxes3D and corners.onScreen
    for i, line in ipairs(self.Components.Box3D) do
        line.Visible = show3DBox
        if show3DBox then
            line.Color = color
            local edgeStart = CUBE_EDGES[i*2-1]
            local edgeEnd = CUBE_EDGES[i*2]
            line.From = corners.vertices[edgeStart]
            line.To = corners.vertices[edgeEnd]
        end
    end

    local show2DBox = ESP.Boxes and not show3DBox and corners.onScreen
    self.Components.Quad.Visible = show2DBox
    if show2DBox then
        local cf2D = self.PrimaryPart.CFrame
        if ESP.FaceCamera then cf2D = CFrame.new(cf2D.p, cam.CFrame.p) end
        local size2D = self.Size
        local locs = {
            TopLeft = cf2D * ESP.BoxShift * CFrame.new(size2D.X / 2, size2D.Y / 2, 0),
            TopRight = cf2D * ESP.BoxShift * CFrame.new(-size2D.X / 2, size2D.Y / 2, 0),
            BottomLeft = cf2D * ESP.BoxShift * CFrame.new(size2D.X / 2, -size2D.Y / 2, 0),
            BottomRight = cf2D * ESP.BoxShift * CFrame.new(-size2D.X / 2, -size2D.Y / 2, 0),
        }
        local TopLeft, _ = cam:WorldToViewportPoint(locs.TopLeft.p)
        local TopRight, _ = cam:WorldToViewportPoint(locs.TopRight.p)
        local BottomLeft, _ = cam:WorldToViewportPoint(locs.BottomLeft.p)
        local BottomRight, _ = cam:WorldToViewportPoint(locs.BottomRight.p)
        self.Components.Quad.PointA = Vector2.new(TopRight.X, TopRight.Y)
        self.Components.Quad.PointB = Vector2.new(TopLeft.X, TopLeft.Y)
        self.Components.Quad.PointC = Vector2.new(BottomLeft.X, BottomLeft.Y)
        self.Components.Quad.PointD = Vector2.new(BottomRight.X, BottomRight.Y)
        self.Components.Quad.Color = color
    end
    
    local humanoid = self.Object and self.Object:FindFirstChildOfClass("Humanoid")
    local showHealth = ESP.HealthBars and humanoid and corners.onScreen
    self.Components.HealthBar.Visible = showHealth
    self.Components.HealthBarOutline.Visible = showHealth
    self.Components.HealthText.Visible = showHealth and ESP.HealthText

    if showHealth then
        local health, maxHealth = humanoid.Health, humanoid.MaxHealth
        local healthPercent = math.clamp(health / maxHealth, 0, 1)
        local HEALTH_BAR_OFFSET = Vector2.new(5, 0)
        local barTop = corners.topLeft - HEALTH_BAR_OFFSET
        local barBottom = Vector2.new(corners.topLeft.X, corners.bottomRight.Y) - HEALTH_BAR_OFFSET
        self.Components.HealthBarOutline.From = barTop - Vector2.new(0,1)
        self.Components.HealthBarOutline.To = barBottom + Vector2.new(0,1)
        self.Components.HealthBar.To = barBottom
        self.Components.HealthBar.From = barBottom:Lerp(barTop, healthPercent)
        self.Components.HealthBar.Color = Color3.fromHSV(0.33 * healthPercent, 1, 1) 

        if ESP.HealthText then
            local healthText = self.Components.HealthText
            healthText.Text = math.floor(health) .. " HP"
            healthText.Position = self.Components.HealthBar.From - Vector2.new(healthText.TextBounds.X + 3, healthText.TextBounds.Y/2)
            healthText.Color = color
        end
    end

    local cf = self.PrimaryPart.CFrame
    local size2D = self.Size
    local TagPos, Vis5 = cam:WorldToViewportPoint((cf * ESP.BoxShift * CFrame.new(0, size2D.Y / 2, 0)).p)
    
    self.Components.Name.Visible = ESP.Names and Vis5
    self.Components.Distance.Visible = ESP.Names and Vis5
    if ESP.Names and Vis5 then
        self.Components.Name.Position = Vector2.new(TagPos.X, TagPos.Y - 14)
        self.Components.Name.Text = self.Name
        self.Components.Name.Color = color
        
        self.Components.Distance.Position = Vector2.new(TagPos.X, TagPos.Y)
        self.Components.Distance.Text = math.floor((cam.CFrame.p - cf.p).magnitude) .. "m away"
        self.Components.Distance.Color = color
    end

    if ESP.Tracers then
        local TorsoPos, Vis6 = cam:WorldToViewportPoint((cf * ESP.BoxShift).p)
        if Vis6 then
            self.Components.Tracer.Visible = true
            self.Components.Tracer.From = Vector2.new(TorsoPos.X, TorsoPos.Y)
            self.Components.Tracer.To = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / ESP.AttachShift)
            self.Components.Tracer.Color = color
        else
            self.Components.Tracer.Visible = false
        end
    else
        self.Components.Tracer.Visible = false
    end
end

function ESP:Add(obj, options)
    if self:GetBox(obj) then self:GetBox(obj):Remove() end

    local box = setmetatable({
        Name = options.Name or obj.Name,
        Type = "Box",
        Color = options.Color,
        Size = options.Size or self.BoxSize,
        Object = obj,
        Player = options.Player or Players:GetPlayerFromCharacter(obj),
        PrimaryPart = options.PrimaryPart or obj.ClassName == "Model" and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj:IsA("BasePart") and obj,
        Components = {},
        IsEnabled = options.IsEnabled,
        Temporary = options.Temporary,
        ColorDynamic = options.ColorDynamic,
        RenderInNil = options.RenderInNil
    }, boxBase)
    
    -- Original Components
    box.Components["Quad"] = Draw("Quad", { Thickness = ESP.Thickness, Transparency = 1, Filled = false })
    box.Components["Name"] = Draw("Text", { Center = true, Outline = true, Size = 19 })
    box.Components["Distance"] = Draw("Text", { Center = true, Outline = true, Size = 19 })
    box.Components["Tracer"] = Draw("Line", { Thickness = ESP.Thickness, Transparency = 1 })
    
    -- New Components
    box.Components["HealthBar"] = Draw("Line", { Thickness = 3 })
    box.Components["HealthBarOutline"] = Draw("Line", { Thickness = 5, Color = Color3.new(0,0,0) })
    box.Components["HealthText"] = Draw("Text", { Outline = true, Size = 16 })
    box.Components["Box3D"] = {}
    for i = 1, 12 do
        table.insert(box.Components.Box3D, Draw("Line", { Thickness = ESP.Thickness }))
    end

    self.Objects[obj] = box
    
    obj.AncestryChanged:Connect(function(_, parent)
        if parent == nil and ESP.AutoRemove ~= false then box:Remove() end
    end)
    
    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            if ESP.AutoRemove ~= false then box:Remove() end
        end)
    end

    return box
end

-- Automatic Player ESP Setup
local function CharAdded(char)
    local p = Players:GetPlayerFromCharacter(char)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end
    ESP:Add(char, { Name = p.Name, Player = p, PrimaryPart = hrp })
end
local function PlayerAdded(p)
    p.CharacterAdded:Connect(CharAdded)
    if p.Character then
        coroutine.wrap(CharAdded)(p.Character)
    end
end
Players.PlayerAdded:Connect(PlayerAdded)
for i, v in pairs(Players:GetPlayers()) do
    if v ~= plr then
        PlayerAdded(v)
    end
end

-- Main Render Loop
RunService.RenderStepped:Connect(function()
    cam = Workspace.CurrentCamera
    for i, v in (ESP.Enabled and pairs or ipairs)(ESP.Objects) do
        if v.Update then
            local s, e = pcall(v.Update, v)
            if not s then warn("[ESP Fork]", e, v.Object and v.Object:GetFullName()) end
        end
    end
end)

return ESP
