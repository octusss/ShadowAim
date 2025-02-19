local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local Mouse = LocalPlayer:GetMouse()
local UserInputService = game:GetService("UserInputService")
local Drawing = Drawing or require("Drawing")
local UserInputService = game:GetService("UserInputService")

-- Default Settings
local AimbotEnabled = true
local AimSmoothness = 0.2
local AimFOV = 100
local WallCheckEnabled = true
local HeadshotOnly = false
local VisibleFOV = false
local FOVColor = Color3.fromRGB(255, 0, 0)
local BulletSpeed = 10000 -- Adjust based on game mechanics
local TeamCheck = true
local PredictionEnabled = false
local M2Pressed = false

local AlwaysOn = false

-- Default ESP Settings
local ESPEnabled = false
local ShowNames = true
local ShowHealth = true
local ShowBoxes = true
local ESPColor = Color3.fromRGB(255, 0, 0)

local ESPObjects = {}

-- FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 100
FOVCircle.Radius = AimFOV
FOVCircle.Color = FOVColor
FOVCircle.Filled = false
FOVCircle.Visible = VisibleFOV


local function MoveMouse(deltaX, deltaY)
    -- Simulate mouse movement using UserInputService
    mousemoverel(deltaX, deltaY)
end

local function IsOnSameTeam(targetPlayer)
    if not TeamCheck then
        return false -- Skip team check if the feature is disabled
    end

    -- Ensure LocalPlayer and targetPlayer are valid and have teams
    if not LocalPlayer or not targetPlayer then
        return false
    end

    local localPlayerTeam = LocalPlayer.Team
    local targetPlayerTeam = targetPlayer.Team

    -- Ensure teams are valid before comparing
    if not localPlayerTeam or not targetPlayerTeam then
        return false
    end

    return localPlayerTeam == targetPlayerTeam
end

local function UpdateFOV()
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Radius = AimFOV
    FOVCircle.Color = FOVColor
    FOVCircle.Visible = VisibleFOV
end

-- FUNCTION: Check if Target is Visible (Lightweight Wall Check)
local function IsVisible(targetPart)
    if not WallCheckEnabled then return true end
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).unit * 500
    local ignoreList = {LocalPlayer.Character, Camera}
    local hitPart = workspace:FindPartOnRayWithIgnoreList(Ray.new(origin, direction), ignoreList)
    
    return not hitPart or hitPart:IsDescendantOf(targetPart.Parent)
end

-- FUNCTION: Predict Target Position
local function PredictPosition(target)
    if not PredictionEnabled then
        return nil -- Skip prediction if disabled
    end

    local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return nil end

    local distance = (Camera.CFrame.Position - targetRoot.Position).magnitude
    local timeToHit = distance / BulletSpeed
    local predictedPosition = targetRoot.Position + (targetRoot.Velocity * timeToHit)

    return predictedPosition
end

-- FUNCTION: Find Closest Visible Target
local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = AimFOV

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            -- Skip teammates if TeamCheck is enabled
            if TeamCheck and IsOnSameTeam(player) then
                -- Skip this iteration
            else
                local targetPart = player.Character:FindFirstChild(HeadshotOnly and "Head" or "HumanoidRootPart")
                if targetPart then
                    local targetPos
                    if PredictionEnabled then
                        -- Use prediction if enabled
                        local predictedPos = PredictPosition(player)
                        if predictedPos then
                            targetPos, onScreen = Camera:WorldToViewportPoint(predictedPos)
                        end
                    else
                        -- Use current position if prediction is disabled
                        targetPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    end

                    if onScreen then
                        local distance = (Vector2.new(targetPos.X, targetPos.Y) - Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)).magnitude
                        if distance < shortestDistance and IsVisible(targetPart) then
                            closestPlayer = player
                            shortestDistance = distance
                        end
                    end
                end
            end
        end
    end

    return closestPlayer
end


-- FUNCTION: Aimbot (Locks Aim to Target)
local function AimAtTarget()
    if not AimbotEnabled then return end
    if not AlwaysOn and not M2Pressed then return end

    local target = GetClosestPlayer()
    if target and target.Character then
        local targetPart = target.Character:FindFirstChild(HeadshotOnly and "Head" or "HumanoidRootPart")
        if targetPart then
            local targetPos
            if PredictionEnabled then
                -- Use prediction if enabled
                local predictedPos = PredictPosition(target)
                if predictedPos then
                    targetPos = predictedPos
                end
            else
                -- Use current position if prediction is disabled
                targetPos = targetPart.Position
            end

            if targetPos then
                -- Calculate the target position on the screen
                local targetPos2D = Camera:WorldToViewportPoint(targetPos)
                local mousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

                -- Convert Vector3 to Vector2 (discard Z component)
                local targetPos2D_Vector2 = Vector2.new(targetPos2D.X, targetPos2D.Y)

                -- Calculate the delta
                local delta = (targetPos2D_Vector2 - mousePos) * AimSmoothness

                -- Move the mouse towards the target
                MoveMouse(delta.X, delta.Y)
            end
        end
    end
end

local function CreateESP(player)
    if ESPObjects[player] then return end -- Skip if ESP already exists for this player

    local character = player.Character
    if not character then return end

    -- Create ESP drawing objects
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = ESPColor
    box.Thickness = 2
    box.Filled = false

    local nameLabel = Drawing.new("Text")
    nameLabel.Visible = false
    nameLabel.Color = ESPColor
    nameLabel.Size = 18
    nameLabel.Center = true
    nameLabel.Outline = true

    local healthBar = Drawing.new("Line")
    healthBar.Visible = false
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Thickness = 2

    -- Store ESP objects
    ESPObjects[player] = {
        Box = box,
        NameLabel = nameLabel,
        HealthBar = healthBar
    }
end

local function ForceHideESP()
    for player, espData in pairs(ESPObjects) do
        espData.Box.Visible = false
        espData.NameLabel.Visible = false
        espData.HealthBar.Visible = false
    end
end

local function UpdateESP(player)
    local espData = ESPObjects[player]
    if not espData then return end

    -- Hide ESP if it's disabled
    if not ESPEnabled then
        espData.Box.Visible = false
        espData.NameLabel.Visible = false
        espData.HealthBar.Visible = false
        return
    end

    -- Skip teammates if TeamCheck is enabled
    if TeamCheck and IsOnSameTeam(player) then
        espData.Box.Visible = false
        espData.NameLabel.Visible = false
        espData.HealthBar.Visible = false
        return
    end

    local character = player.Character
    if not character then
        espData.Box.Visible = false
        espData.NameLabel.Visible = false
        espData.HealthBar.Visible = false
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not rootPart or not humanoid then
        espData.Box.Visible = false
        espData.NameLabel.Visible = false
        espData.HealthBar.Visible = false
        return
    end

    -- Update ESP drawings
    local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    if not onScreen then
        espData.Box.Visible = false
        espData.NameLabel.Visible = false
        espData.HealthBar.Visible = false
        return
    end

    -- Update ESP box
    local size = Vector2.new(2000 / rootPos.Z, 3000 / rootPos.Z) -- Adjust box size based on distance
    espData.Box.Size = size
    espData.Box.Position = Vector2.new(rootPos.X - size.X / 2, rootPos.Y - size.Y / 2)
    espData.Box.Visible = ESPEnabled and ShowBoxes

    -- Update name label
    espData.NameLabel.Text = player.Name
    espData.NameLabel.Position = Vector2.new(rootPos.X, rootPos.Y - size.Y / 2 - 20)
    espData.NameLabel.Visible = ESPEnabled and ShowNames

    -- Update health bar
    local healthPercent = humanoid.Health / humanoid.MaxHealth
    local healthBarLength = size.X * healthPercent
    espData.HealthBar.From = Vector2.new(rootPos.X - size.X / 2, rootPos.Y + size.Y / 2 + 5)
    espData.HealthBar.To = Vector2.new(rootPos.X - size.X / 2 + healthBarLength, rootPos.Y + size.Y / 2 + 5)
    espData.HealthBar.Visible = ESPEnabled and ShowHealth
end

local function RemoveESP(player)
    local espData = ESPObjects[player]
    if not espData then return end

    -- Remove ESP drawing objects
    espData.Box:Remove()
    espData.NameLabel:Remove()
    espData.HealthBar:Remove()

    ESPObjects[player] = nil
end


-- Update FOV Circle
RunService.RenderStepped:Connect(function()
    UpdateFOV()
    AimAtTarget()
end)

-- Rayfield GUI
local Window = Rayfield:CreateWindow({
    Name = "Shadow Aimbot",
    LoadingTitle = "Aimbot Loaded",
    LoadingSubtitle = "by Octus",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "ShadowConfig",
        FileName = "Settings"
    },
})

local Tab = Window:CreateTab("Aimbot Settings", 4483362458)
local ESPTab = Window:CreateTab("ESP Settings", 4483362458) -- Replace with your desired icon ID

Tab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = AimbotEnabled,
    Flag = "AimbotToggle",
    Callback = function(Value)
        AimbotEnabled = Value
    end
})

Tab:CreateSlider({
    Name = "Aim Speed",
    Range = {0.1, 1},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = AimSmoothness,
    Flag = "SmoothnessSlider",
    Callback = function(Value)
        AimSmoothness = Value
    end
})

Tab:CreateSlider({
    Name = "Aim FOV",
    Range = {50, 500},
    Increment = 10,
    Suffix = "°",
    CurrentValue = AimFOV,
    Flag = "FOVSlider",
    Callback = function(Value)
        AimFOV = Value
        UpdateFOV()
    end
})

Tab:CreateSlider({
    Name = "Bullet Prediction Speed",  -- Higher values = slower speed
    Range = {50, 10000},
    Increment = 50,
    Suffix = "units/s",
    CurrentValue = BulletSpeed,
    Flag = "BulletSpeedSlider",
    Callback = function(Value)
        BulletSpeed = Value
    end
})

Tab:CreateToggle({
    Name = "Wall Check",
    CurrentValue = WallCheckEnabled,
    Flag = "WallCheckToggle",
    Callback = function(Value)
        WallCheckEnabled = Value
    end
})

Tab:CreateToggle({
    Name = "Headshot Only",
    CurrentValue = HeadshotOnly,
    Flag = "HeadshotToggle",
    Callback = function(Value)
        HeadshotOnly = Value
    end
})

Tab:CreateToggle({
    Name = "Team Check",
    CurrentValue = TeamCheck,
    Flag = "TeamCheckToggle",
    Callback = function(Value)
        TeamCheck = Value
    end
})

Tab:CreateToggle({
    Name = "Enable Prediction",
    CurrentValue = PredictionEnabled,
    Flag = "PredictionToggle",
    Callback = function(Value)
        PredictionEnabled = Value
    end
})

Tab:CreateToggle({
    Name = "Always On",
    CurrentValue = AlwaysOn,
    Flag = "AlwaysOnToggle",
    Callback = function(Value)
        AlwaysOn = Value
    end
})

Tab:CreateToggle({
    Name = "Visible FOV",
    CurrentValue = VisibleFOV,
    Flag = "VisibleFOVToggle",
    Callback = function(Value)
        VisibleFOV = Value
        UpdateFOV()
    end
})

Tab:CreateColorPicker({
    Name = "FOV Color",
    Color = FOVColor,
    Flag = "FOVColorPicker",
    Callback = function(Color)
        FOVColor = Color
        UpdateFOV()
    end
})

-- ESP Toggles
ESPTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = ESPEnabled,
    Flag = "ESPToggle",
    Callback = function(Value)
        ESPEnabled = Value
        if not ESPEnabled then
            ForceHideESP() -- Hide all ESP drawings when disabled
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Names",
    CurrentValue = ShowNames,
    Flag = "ShowNamesToggle",
    Callback = function(Value)
        ShowNames = Value
    end
})

ESPTab:CreateToggle({
    Name = "Show Health",
    CurrentValue = ShowHealth,
    Flag = "ShowHealthToggle",
    Callback = function(Value)
        ShowHealth = Value
    end
})

ESPTab:CreateToggle({
    Name = "Show Boxes",
    CurrentValue = ShowBoxes,
    Flag = "ShowBoxesToggle",
    Callback = function(Value)
        ShowBoxes = Value
    end
})

ESPTab:CreateColorPicker({
    Name = "ESP Color",
    Color = ESPColor,
    Flag = "ESPColorPicker",
    Callback = function(Color)
        ESPColor = Color
    end
})

ESPTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = TeamCheck,
    Flag = "TeamCheckToggle",
    Callback = function(Value)
        TeamCheck = Value
    end
})

RunService.RenderStepped:Connect(function()
    if not ESPEnabled then
        ForceHideESP() -- Hide all ESP drawings if ESP is disabled
        return
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreateESP(player) -- Ensure ESP objects are created
            UpdateESP(player) -- Update ESP for all players
        else
            RemoveESP(player) -- Remove ESP for local player
        end
    end
end)

-- Add Player Removal Handler
Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end -- Ignore if the game processed the input

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        M2Pressed = true
    end
end)

-- Detect M2 Key Release
UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        M2Pressed = false
    end
end)
