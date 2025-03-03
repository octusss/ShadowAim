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
local AliveCheckEnabled = true

local AlwaysOn = false

-- Default ESP Settings
local ESPEnabled = false
local ShowNames = true
local ShowHealth = true
local ShowBoxes = true
local ESPColor = Color3.fromRGB(255, 0, 0)
local ESPVisibleColor = Color3.fromRGB(0, 0, 255) -- Default color for visible enemies (blue)
local ESPVisibleToggle = true -- Enable/disable visible ESP color

local ESPObjects = {}

-- FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 100
FOVCircle.Radius = AimFOV
FOVCircle.Color = FOVColor
FOVCircle.Filled = false
FOVCircle.Visible = VisibleFOV

-- Default Triggerbot Settings
local TriggerbotEnabled = false
local TriggerbotFOV = 50 -- FOV size for the Triggerbot
local TriggerbotFOVVisible = false -- Whether the FOV circle is visible
local TriggerbotFOVColor = Color3.fromRGB(0, 255, 0) -- Color of the FOV circle

-- Triggerbot FOV Circle
local TriggerbotFOVCircle = Drawing.new("Circle")
TriggerbotFOVCircle.Thickness = 2
TriggerbotFOVCircle.NumSides = 100
TriggerbotFOVCircle.Radius = TriggerbotFOV
TriggerbotFOVCircle.Color = TriggerbotFOVColor
TriggerbotFOVCircle.Filled = false
TriggerbotFOVCircle.Visible = TriggerbotFOVVisible


local function AimWithUserInputService(targetPos2D, mousePos)
    local delta = (targetPos2D - mousePos) * AimSmoothness
    mousemoverel(delta.X, delta.Y)
end

local function AimWithCFrame(targetPos)
    local direction = (targetPos - Camera.CFrame.Position).Unit
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + direction)
end

local AimingMethods = {
    "UserInputService",
    "CFrame"
}

local SelectedAimingMethod = "UserInputService" -- Default method


-- FUNCTION: Check if Player is Alive
local function IsAlive(player)
    if not AliveCheckEnabled then
        return true -- Skip alive check if the feature is disabled
    end

    local character = player.Character
    if not character then return false end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return false end

    return humanoid.Health > 0
end


local function IsOnSameTeam(targetPlayer)
    if not TeamCheck then
        return false -- Skip team check if the feature is disabled
    end

    if not LocalPlayer or not targetPlayer then
        return false
    end

    local localPlayerTeam = LocalPlayer.Team
    local targetPlayerTeam = targetPlayer.Team

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
        return nil
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
        if player ~= LocalPlayer and player.Character and IsAlive(player) then
            if TeamCheck and IsOnSameTeam(player) then
                -- Skip teammates if TeamCheck is enabled
            else
                local targetPart
                if HeadshotOnly then
                    -- Only target the head if HeadshotOnly is enabled
                    targetPart = player.Character:FindFirstChild("Head")
                else
                    -- Default to HumanoidRootPart if HeadshotOnly is disabled
                    targetPart = player.Character:FindFirstChild("HumanoidRootPart")
                end

                if targetPart then
                    local targetPos, onScreen
                    if PredictionEnabled then
                        local predictedPos = PredictPosition(player)
                        if predictedPos then
                            targetPos, onScreen = Camera:WorldToViewportPoint(predictedPos)
                        end
                    else
                        targetPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    end

                    if onScreen and targetPos then
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
                local predictedPos = PredictPosition(target)
                if predictedPos then
                    targetPos = predictedPos
                end
            else
                targetPos = targetPart.Position
            end

            if targetPos then
                local targetPos2D = Camera:WorldToViewportPoint(targetPos)
                local mousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

                if SelectedAimingMethod == "UserInputService" then
                    AimWithUserInputService(Vector2.new(targetPos2D.X, targetPos2D.Y), mousePos)
                elseif SelectedAimingMethod == "CFrame" then
                    AimWithCFrame(targetPos)
                end
            end
        end
    end
end

local function Triggerbot()
    if not TriggerbotEnabled then return end

    local target = GetClosestPlayer()
    if target and target.Character then
        local targetParts = target.Character:GetChildren()
        for _, part in ipairs(targetParts) do
            if part:IsA("BasePart") then
                local targetPos = part.Position
                local targetPos2D, onScreen = Camera:WorldToViewportPoint(targetPos)

                if onScreen then
                    local mousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    local distance = (Vector2.new(targetPos2D.X, targetPos2D.Y) - mousePos).magnitude

                    -- Adjusted FOV check: trigger even if the part touches the FOV
                    if distance <= TriggerbotFOV + part.Size.Magnitude then
                        mouse1press()  -- Press the mouse button
                        mouse1release()  -- Release the mouse button
                        break  -- Stop checking other parts once we press and release
                    end
                end
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

local function UpdateTriggerbotFOV()
    TriggerbotFOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    TriggerbotFOVCircle.Radius = TriggerbotFOV
    TriggerbotFOVCircle.Color = TriggerbotFOVColor
    TriggerbotFOVCircle.Visible = TriggerbotFOVVisible
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

    -- Skip dead players if AliveCheck is enabled
    if AliveCheckEnabled and not IsAlive(player) then
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

    -- Check if the player is visible
    local isVisible = IsVisible(rootPart)

    -- Set ESP color based on visibility
    local espColor = ESPColor
    if ESPVisibleToggle and isVisible then
        espColor = ESPVisibleColor
    end

    -- Update ESP box
    local size = Vector2.new(2000 / rootPos.Z, 3000 / rootPos.Z) -- Adjust box size based on distance
    espData.Box.Size = size
    espData.Box.Position = Vector2.new(rootPos.X - size.X / 2, rootPos.Y - size.Y / 2)
    espData.Box.Color = espColor
    espData.Box.Visible = ESPEnabled and ShowBoxes

    -- Update name label
    espData.NameLabel.Text = player.Name
    espData.NameLabel.Position = Vector2.new(rootPos.X, rootPos.Y - size.Y / 2 - 20)
    espData.NameLabel.Color = espColor
    espData.NameLabel.Visible = ESPEnabled and ShowNames

    -- Update health bar
    local healthPercent = humanoid.Health / humanoid.MaxHealth
    local healthBarLength = size.X * healthPercent
    espData.HealthBar.From = Vector2.new(rootPos.X - size.X / 2, rootPos.Y + size.Y / 2 + 5)
    espData.HealthBar.To = Vector2.new(rootPos.X - size.X / 2 + healthBarLength, rootPos.Y + size.Y / 2 + 5)
    espData.HealthBar.Color = espColor
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
    UpdateTriggerbotFOV() -- Update the Triggerbot FOV circle
    AimAtTarget()
    Triggerbot()
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

local Tab = Window:CreateTab("Aimbot", "mouse")
local TriggerbotTab = Window:CreateTab("Triggerbot", "crosshair") 
local ESPTab = Window:CreateTab("ESP", "eye")

Tab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = AimbotEnabled,
    Flag = "AimbotToggle",
    Callback = function(Value)
        AimbotEnabled = Value
    end
})

Tab:CreateDropdown({
    Name = "Aiming Method",
    Options = AimingMethods,
    CurrentOption = SelectedAimingMethod,
    Flag = "AimingMethodDropdown",
    Callback = function(Option)
        -- Ensure Option is a string
        if type(Option) == "table" then
            SelectedAimingMethod = Option.Text or Option[1] -- Extract the string from the table
        else
            SelectedAimingMethod = Option -- Use the string directly
        end
        print("Selected Aiming Method:", SelectedAimingMethod) -- Debug print
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

-- Enable Triggerbot Toggle
TriggerbotTab:CreateToggle({
    Name = "Enable Triggerbot",
    CurrentValue = TriggerbotEnabled,
    Flag = "TriggerbotToggle",
    Callback = function(Value)
        TriggerbotEnabled = Value
    end
})

-- Triggerbot FOV Size Slider
TriggerbotTab:CreateSlider({
    Name = "Triggerbot FOV Size",
    Range = {1, 100}, -- Adjust the range as needed
    Increment = 1,
    Suffix = "°",
    CurrentValue = TriggerbotFOV,
    Flag = "TriggerbotFOVSlider",
    Callback = function(Value)
        TriggerbotFOV = Value
        TriggerbotFOVCircle.Radius = TriggerbotFOV
    end
})

-- Triggerbot FOV Visibility Toggle
TriggerbotTab:CreateToggle({
    Name = "Show Triggerbot FOV",
    CurrentValue = TriggerbotFOVVisible,
    Flag = "TriggerbotFOVVisibleToggle",
    Callback = function(Value)
        TriggerbotFOVVisible = Value
        TriggerbotFOVCircle.Visible = TriggerbotFOVVisible
    end
})

-- Triggerbot FOV Color Picker
TriggerbotTab:CreateColorPicker({
    Name = "Triggerbot FOV Color",
    Color = TriggerbotFOVColor,
    Flag = "TriggerbotFOVColorPicker",
    Callback = function(Color)
        TriggerbotFOVColor = Color
        TriggerbotFOVCircle.Color = TriggerbotFOVColor
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


-- Add Alive Check Toggle to Rayfield GUI
Tab:CreateToggle({
    Name = "Alive Check",
    CurrentValue = AliveCheckEnabled,
    Flag = "AliveCheckToggle",
    Callback = function(Value)
        AliveCheckEnabled = Value
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

-- Add Visible ESP Color Picker
ESPTab:CreateColorPicker({
    Name = "Visible ESP Color",
    Color = ESPVisibleColor,
    Flag = "ESPVisibleColorPicker",
    Callback = function(Color)
        ESPVisibleColor = Color
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

-- Add Visible ESP Color Toggle
ESPTab:CreateToggle({
    Name = "Enable Visible ESP Color",
    CurrentValue = ESPVisibleToggle,
    Flag = "ESPVisibleToggle",
    Callback = function(Value)
        ESPVisibleToggle = Value
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
