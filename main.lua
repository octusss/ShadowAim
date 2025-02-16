local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- SETTINGS (Adjust for legit or HVH)
local AimbotEnabled = true
local AimSmoothness = 0.2  -- Lower = Faster Lock
local AimFOV = 100  -- Lock-On Range
local WallCheckEnabled = true  -- Blocks through walls
local TriggerbotEnabled = false  -- Auto-Shoot when crosshair is on enemy
local HeadshotOnly = false  -- Prioritize headshots

-- FUNCTION: Check if Target is Visible (Lightweight Wall Check)
local function IsVisible(targetPart)
    if not WallCheckEnabled then return true end
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).unit * 500
    local ignoreList = {LocalPlayer.Character, Camera}
    local hitPart = workspace:FindPartOnRayWithIgnoreList(Ray.new(origin, direction), ignoreList)
    
    return not hitPart or hitPart:IsDescendantOf(targetPart.Parent)
end

-- FUNCTION: Find Closest Visible Target
local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = AimFOV
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetPart = player.Character:FindFirstChild(HeadshotOnly and "Head" or "HumanoidRootPart")
            if targetPart then
                local targetPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local distance = (Vector2.new(targetPos.X, targetPos.Y) - Vector2.new(Mouse.X, Mouse.Y)).magnitude
                    if distance < shortestDistance and IsVisible(targetPart) then
                        closestPlayer = player
                        shortestDistance = distance
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
    
    local target = GetClosestPlayer()
    if target and target.Character then
        local targetPos = target.Character:FindFirstChild(HeadshotOnly and "Head" or "HumanoidRootPart").Position
        local direction = (targetPos - Camera.CFrame.Position).unit
        local newCFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + direction)
        
        Camera.CFrame = Camera.CFrame:Lerp(newCFrame, AimSmoothness)
    end
end

-- FUNCTION: Triggerbot (Auto-Fire on Target, No Delay, Continuous Shooting)
local function Triggerbot()
    if not TriggerbotEnabled then return end
    
    local target = GetClosestPlayer()
    if target then
        mouse1press()
    else
        mouse1release()
    end
end

-- Connect to RenderStep
RunService.RenderStepped:Connect(function()
    AimAtTarget()
    Triggerbot()
end)

print("Universal Aimbot Loaded! Toggle settings in script...")
