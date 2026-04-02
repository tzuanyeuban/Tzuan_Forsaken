local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/XUANVNPRO/Mmb/refs/heads/main/gui2.0.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Tzuan Hub | Forsaken [Beta]",
    SubTitle = "Version 2.5.0",
    Search = true,
    Icon = "rbxassetid://84950100176700",
    TabWidth = 160,
    Size = UDim2.fromOffset(480, 360),
    Acrylic = true,
    Theme = "Arctic",
    MinimizeKey = Enum.KeyCode.RightAlt,

    UserInfo = false,
    UserInfoTop = false,
    UserInfoTitle = game:GetService("Players").LocalPlayer.DisplayName,
    UserInfoSubtitle = "Sub & Like Ytb Tzuan",
    UserInfoSubtitleColor = Color3.fromRGB(71, 123, 255)
})

local Tabs = {
    About = Window:AddTab({ Title = "About", Icon = "info" }),
    Farm = Window:AddTab({ Title = "Farm", Icon = "box" }),
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Event = Window:AddTab({ Title = "Event", Icon = "bell" }),
    Player = Window:AddTab({ Title = "Player", Icon = "user" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "eye" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "menu" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local function getPlayerGui()
    local plr = Players.LocalPlayer
    if plr and plr:FindFirstChild("PlayerGui") then
        return plr.PlayerGui
    end
    return nil
end

local function getCamera()
    return Workspace.CurrentCamera
end

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
local HRP = Character:FindFirstChild("HumanoidRootPart")

local function updateCharacterRefs(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HRP = char:WaitForChild("HumanoidRootPart")
end

LocalPlayer.CharacterAdded:Connect(updateCharacterRefs)

local function getChar() return Character end
local function getHumanoid() return Humanoid end
local function getHRP() return HRP end

local function WaitForMap()
    local mapContainer = Workspace:FindFirstChild("Map")
    local ingame = mapContainer and mapContainer:FindFirstChild("Ingame")
    return ingame and ingame:FindFirstChild("Map") or nil
end

local MapFolder = WaitForMap()
local function RefreshMap()
    MapFolder = WaitForMap()
    return MapFolder
end

local function getSurvivorsFolder()
    return Workspace:FindFirstChild("Players") and Workspace.Players:FindFirstChild("Survivors")
end

local function getKillersFolder()
    return Workspace:FindFirstChild("Players") and Workspace.Players:FindFirstChild("Killers")
end

local function getGeneratorRemote(gen)
    return (gen and gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE")) or nil
end

AimSystem = {}

function AimSystem.RotateTo(targetCFrame, speed)
    if not HRP then return end
    speed = speed or 1

    local currentCFrame = HRP.CFrame
    local goalCFrame = CFrame.new(currentCFrame.Position, targetCFrame.Position)
    HRP.CFrame = currentCFrame:Lerp(goalCFrame, speed)
end

function AimSystem.GetTargetCFrame(targetPlayer)
    local targetChar = targetPlayer.Character
    if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
        return targetChar.HumanoidRootPart.CFrame
    end
    return nil
end

local ESPManager = {
    ActiveTypes = {},
    Objects = {},
    Filters = {},
    Colors = {},
    Watchers = {},
    ShowHP = {},
    _pendingCreate = {},
}

local Shared = getgenv().__TzuanShared
if not Shared then
    Shared = {}
    getgenv().__TzuanShared = Shared
end

Shared.ESP = ESPManager

local function getPrimaryPart(model)
    if not model then return nil end
    return model.PrimaryPart
        or model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChildWhichIsA("BasePart")
end

local function disconnectConns(tbl)
    if not tbl then return end
    for _, c in pairs(tbl) do
        if c and typeof(c) == "RBXScriptConnection" then
            pcall(function() c:Disconnect() end)
        end
    end
end

function ESPManager:RegisterType(name, color, filterFn, showHP)
    self.Filters[name] = filterFn
    self.Colors[name] = color or Color3.new(1,1,1)
    self.ShowHP[name] = showHP or false
    self.ActiveTypes[name] = false
end

function ESPManager:_CreateImmediate(model, typeName)
    if not model or not model.Parent then return end

    local existing = self.Objects[model]
    if existing then
        if existing.gui and existing.gui.Parent and existing.hl and existing.hl.Parent then
            return
        else
            self:Remove(model)
        end
    end

    local color = self.Colors[typeName] or Color3.new(1,1,1)
    local part = getPrimaryPart(model)
    if not part then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_" .. typeName
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0,3,0)
    billboard.MaxDistance = 600
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.3
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.Text = model.Name
    label.Parent = billboard

    local hl = Instance.new("Highlight")
    hl.Adornee = model
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.7
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = true
    hl.Parent = model

    local conns = {}

    table.insert(conns, RunService.RenderStepped:Connect(function()
        if not model or not model.Parent or not billboard.Parent then return end

        local finalText = model.Name

        local lp = Players.LocalPlayer
        if lp then
            local char = lp.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local objRoot = getPrimaryPart(model)

            if root and objRoot then
                local dist = math.floor((objRoot.Position - root.Position).Magnitude)
                finalText = finalText .. " | [" .. dist .. "m]"
            end
        end

        if self.ShowHP[typeName] then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum then
                finalText = finalText .. " | HP: " .. math.floor(hum.Health)
            end
        end

        label.Text = finalText
    end))

    table.insert(conns, model.AncestryChanged:Connect(function()
        if not model:IsDescendantOf(Workspace) then
            self:Remove(model)
            return
        end
        if self.ActiveTypes[typeName] and self.Filters[typeName](model) then
            self:_ScheduleCreate(model, typeName)
        end
    end))

    local function watchHumanoid(h)
        if not h then return end
        table.insert(conns, h.Died:Connect(function()
            self:Remove(model)
        end))
    end
    watchHumanoid(model:FindFirstChildOfClass("Humanoid"))

    table.insert(conns, model.ChildAdded:Connect(function(c)
        if c:IsA("Humanoid") then watchHumanoid(c) end
        if (c:IsA("BasePart") or c:IsA("Model")) 
            and self.ActiveTypes[typeName]
            and self.Filters[typeName](model) then
            self:_ScheduleCreate(model, typeName)
        end
    end))

    self.Objects[model] = {
        type = typeName,
        gui = billboard,
        label = label,
        hl = hl,
        conns = conns
    }
end

function ESPManager:_ScheduleCreate(model, typeName)
    if not model or not typeName then return end
    if not self.ActiveTypes[typeName] then return end
    if self._pendingCreate[model] then return end

    self._pendingCreate[model] = true
    task.delay(0.2, function()
        self._pendingCreate[model] = nil
        if model and model.Parent then
            local f = self.Filters[typeName]
            if f and f(model) then
                self:_CreateImmediate(model, typeName)
            end
        end
    end)
end

function ESPManager:Remove(model)
    local d = self.Objects[model]
    if not d then return end

    disconnectConns(d.conns)
    pcall(function() if d.gui then d.gui:Destroy() end end)
    pcall(function() if d.hl then d.hl:Destroy() end end)

    self.Objects[model] = nil
    self._pendingCreate[model] = nil
end

function ESPManager:StartWatcher(typeName)
    local f = self.Filters[typeName]
    if not f or self.Watchers[typeName] then return end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if f(obj) then
            self:_ScheduleCreate(obj, typeName)
        end
    end

    local add = Workspace.DescendantAdded:Connect(function(obj)
        if self.ActiveTypes[typeName] and f(obj) then
            self:_ScheduleCreate(obj, typeName)
        end
    end)

    local rem = Workspace.DescendantRemoving:Connect(function(obj)
        if self.Objects[obj] and self.Objects[obj].type == typeName then
            self:Remove(obj)
        end
        self._pendingCreate[obj] = nil
    end)

    self.Watchers[typeName] = {add = add, rem = rem}
end

function ESPManager:StopWatcher(typeName)
    local w = self.Watchers[typeName]
    if not w then return end

    pcall(function() w.add:Disconnect() end)
    pcall(function() w.rem:Disconnect() end)

    self.Watchers[typeName] = nil
end

function ESPManager:SetEnabled(typeName, state)
    if self.ActiveTypes[typeName] == nil then return end

    self.ActiveTypes[typeName] = state

    if state then
        self:StartWatcher(typeName)
    else
        for obj,data in pairs(self.Objects) do
            if data.type == typeName then
                self:Remove(obj)
            end
        end
        self:StopWatcher(typeName)
    end
end


local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local ExistingUI = CoreGui:FindFirstChild("TzuanhubMinimizeUI")
if ExistingUI then
    ExistingUI:Destroy()
end

local DragUI = Instance.new("ScreenGui")
DragUI.Name = "TzuanhubMinimizeUI"
DragUI.ResetOnSpawn = false
DragUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
DragUI.Parent = CoreGui

local Button = Instance.new("ImageButton")
Button.Parent = DragUI
Button.Size = UDim2.new(0, 50, 0, 50)
Button.Position = UDim2.new(0, 10, 1, -85)
Button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Button.BackgroundTransparency = 0.3
Button.BorderSizePixel = 0
Button.ClipsDescendants = true
Button.Image = "rbxassetid://84950100176700"
Button.ScaleType = Enum.ScaleType.Fit
Button.Active = true
Button.ZIndex = 1000

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(1, 0)
UICorner.Parent = Button

local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function ToggleUI()
    if Window.Minimized then
        Window:Minimize(false)
    else
        Window:Minimize(true)
    end
end

local isDragging = false
local dragThreshold = 10

Button.MouseButton1Click:Connect(function()
    if isDragging then return end

    TweenService:Create(Button, tweenInfo, {
        BackgroundTransparency = 0.5,
        Size = UDim2.new(0, 45, 0, 45),
        Rotation = 5
    }):Play()
    task.wait(0.1)
    TweenService:Create(Button, tweenInfo, {
        BackgroundTransparency = 0.3,
        Size = UDim2.new(0, 50, 0, 50),
        Rotation = 0
    }):Play()

    ToggleUI()
end)

Button.MouseEnter:Connect(function()
    TweenService:Create(Button, tweenInfo, {Size = UDim2.new(0, 55, 0, 55)}):Play()
end)

Button.MouseLeave:Connect(function()
    TweenService:Create(Button, tweenInfo, {Size = UDim2.new(0, 50, 0, 50)}):Play()
end)

local dragging, dragStart, startPos

local function StartDrag(input)
    isDragging = false
    dragging = true
    dragStart = input.Position
    startPos = Button.Position

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            dragging = false
        end
    end)
end

local function OnDrag(input)
    if dragging then
        local delta = (input.Position - dragStart).Magnitude
        if delta > dragThreshold then
            isDragging = true
        end
        Button.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + (input.Position.X - dragStart.X),
            startPos.Y.Scale,
            startPos.Y.Offset + (input.Position.Y - dragStart.Y)
        )
    end
end

Button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        StartDrag(input)
    end
end)

Button.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        OnDrag(input)
    end
end) 

local ESP = getgenv().__TzuanShared.ESP

local Options = Fluent.Options

    Tabs.About:AddParagraph({
        Title = "Hỗ trợ",
        Content = "Script có lỗi vui lòng vào discord để báo cáo, xin đừng giữ im lặng\nThe script has an error. Please join the Discord to report it. Don’t stay silent."
    })

    Tabs.About:AddSection("↳ Links")

    Tabs.About:AddButton({
        Title = "Discord",
        Description = "Copy the link to join the discord!",
        Callback = function()
            setclipboard("https://discord.gg/usv255Pw4t")
            Fluent:Notify({
                Title = "Notification",
                Content = "Successfully copied to the clipboard",
                SubContent = "",
                Duration = 3 
            })
        end
    })

    Tabs.About:AddButton({
        Title = "Youtube",
        Description = "Copy link to Subscribe to Youtube channel!",
        Callback = function()
            setclipboard("https://www.youtube.com/@Tzuanww")
            Fluent:Notify({
                Title = "Notification",
                Content = "Successfully copied to the clipboard!",
                SubContent = "",
                Duration = 3 
            })
        end
    })

    Tabs.About:AddSection("↳ Update")

    Tabs.About:AddParagraph({
        Title = "Version 2.5.0",
        Content = "Beta"
    })

local function PressKey(key)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, key, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, key, false, game)
    end)
end

local function ClickLMB()
    local cam = Workspace.CurrentCamera
    local vp = cam.ViewportSize
    local x, y = vp.X / 2, vp.Y / 2

    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function TriggerAllInputs()
    ClickLMB()
    PressKey(Enum.KeyCode.Q)
    PressKey(Enum.KeyCode.E)
    PressKey(Enum.KeyCode.R)
    PressKey(Enum.KeyCode.T)
end

local farmActive = false
local farmThread = nil
local lastAttack = 0
local CurrentTarget = nil

local PriorityList = {
    ["0206octavio"] = true
}

local function GetPriorityTarget()
    local survivorsFolder = getSurvivorsFolder()
    if not survivorsFolder then return nil end

    for _, survivor in ipairs(survivorsFolder:GetChildren()) do
        if survivor:IsA("Model") and survivor:FindFirstChild("HumanoidRootPart") then
            if PriorityList[survivor.Name] then
                local humanoid = survivor:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    return survivor
                end
            end
        end
    end
    return nil
end

local function GetClosestSurvivor()
    local priorityTarget = GetPriorityTarget()
    if priorityTarget then return priorityTarget end

    local hrp = getHRP()
    if not hrp then return nil end

    local closest, minDist = nil, math.huge
    local survivorsFolder = getSurvivorsFolder()
    if not survivorsFolder then return nil end

    for _, survivor in ipairs(survivorsFolder:GetChildren()) do
        local humanoid = survivor:FindFirstChildOfClass("Humanoid")
        local hrp2 = survivor:FindFirstChild("HumanoidRootPart")

        if survivor:IsA("Model") and hrp2 and humanoid and humanoid.Health > 0 then
            local dist = (hrp.Position - hrp2.Position).Magnitude
            if dist < minDist then
                minDist = dist
                closest = survivor
            end
        end
    end

    return closest
end

local function KillTarget(target)
    if not target then return end

    local hrp = getHRP()
    if not hrp then return end

    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    if tick() - lastAttack >= 0.001 then
        lastAttack = tick()

        local offset = targetRoot.CFrame.LookVector * -2
        pcall(function()
            hrp.CFrame = targetRoot.CFrame + offset
        end)

        TriggerAllInputs()
    end
end

local function StartFarmLoop()
    if farmThread then return end

    farmThread = task.spawn(function()
        while farmActive do
            local hrp = getHRP()
            local char = getChar()

            if not (char and hrp) then
                CurrentTarget = nil
                task.wait(0.5)
            else
                local isKiller = false
                local killersFolder = getKillersFolder()

                if killersFolder then
                    for _, killer in ipairs(killersFolder:GetChildren()) do
                        if killer:IsA("Model") and killer.Name == char.Name then
                            isKiller = true
                            break
                        end
                    end
                end

                if not isKiller then
                    CurrentTarget = nil
                    task.wait(0.5)
                else
                    if (not CurrentTarget)
                        or (not CurrentTarget.Parent)
                        or (not CurrentTarget:FindFirstChildOfClass("Humanoid"))
                        or (CurrentTarget:FindFirstChildOfClass("Humanoid").Health <= 0) then

                        CurrentTarget = GetClosestSurvivor()
                    end

                    if CurrentTarget then
                        KillTarget(CurrentTarget)
                    end

                    task.wait(0.01)
                end
            end
        end

        farmThread = nil
    end)
end

local function StopFarmLoop()
    farmActive = false

    if farmThread then
        pcall(function()
            task.cancel(farmThread)
        end)

        farmThread = nil
    end
end

Tabs.Farm:AddToggle("KillersFarmV2", {
    Title = "Killers Farm V2",
    Default = false,
    Callback = function(Value)
        farmActive = Value
        if farmActive then
            StartFarmLoop()
        else
            StopFarmLoop()
        end
    end
})

local survivorsFarmActive = false
local survivorsFarmThread = nil
local solveGeneratorCooldown = false
local genDelay = 2.5
local teleportThreshold = 1.5

local function isKillerNearGenerator(pos, distance)
    local killersFolder = getKillersFolder()
    if not killersFolder then return false end
    for _, killer in ipairs(killersFolder:GetChildren()) do
        local hrp = killer:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - pos).Magnitude <= distance then
            return true
        end
    end
    return false
end

local function getUnfinishedGenerators()
    local MapFolder = RefreshMap()
    local list = {}
    if MapFolder then
        for _, gen in ipairs(MapFolder:GetChildren()) do
            if gen.Name == "Generator" and gen:FindFirstChild("Progress") and gen.Progress.Value < 100 then
                table.insert(list, gen)
            end
        end
    end
    return list
end

local function fixGeneratorUntilComplete(gen)
    local char = getChar()
    local hrp = getHRP()
    if not (char and hrp) then return end
    local ok, pivot = pcall(function() return gen:GetPivot() end)
    if not ok or not pivot then return end
    local goalPos = (pivot * CFrame.new(0,0,-7)).Position
    if isKillerNearGenerator(goalPos, 50) then return end

    while gen and gen:FindFirstChild("Progress") and gen.Progress.Value < 100 and survivorsFarmActive do
        local dist = (hrp.Position - goalPos).Magnitude
        if dist > teleportThreshold then
            pcall(function() char:PivotTo(CFrame.new(goalPos)) end)
        end

        task.wait(0.25)

        local prompt = gen:FindFirstChild("Main") and gen.Main:FindFirstChild("Prompt")
        if prompt then
            pcall(function()
                prompt.HoldDuration = 0
                prompt.RequiresLineOfSight = false
                prompt.MaxActivationDistance = 99999
                prompt:InputHoldBegin()
                prompt:InputHoldEnd()
            end)
        end

        local remote = getGeneratorRemote(gen)
        if remote then
            pcall(function() remote:FireServer() end)
        end

        task.wait(1.5)
    end
end

local function StartSurvivorsFarm()
    if survivorsFarmThread then return end
    survivorsFarmThread = task.spawn(function()
        while survivorsFarmActive do
            local gens = getUnfinishedGenerators()
            for _, gen in ipairs(gens) do
                if not survivorsFarmActive then break end
                fixGeneratorUntilComplete(gen)
                task.wait(genDelay)
            end
            task.wait(0.1)
        end
        survivorsFarmThread = nil
    end)
end

local function StopSurvivorsFarm()
    survivorsFarmActive = false
    if survivorsFarmThread then
        pcall(function() task.cancel(survivorsFarmThread) end)
        survivorsFarmThread = nil
    end
end

Tabs.Farm:AddToggle("SurvivorsAutoFarmV2", {
    Title = "Survivors Farm V2",
    Default = false
}):OnChanged(function(Value)
    survivorsFarmActive = Value
    if survivorsFarmActive then
        StartSurvivorsFarm()
    else
        StopSurvivorsFarm()
    end
end)

    Tabs.Farm:AddSection("↳ Generator")

local solveGeneratorCooldown = false
local AutoFinishGen = false
local genDelay = 1.5

local function getClosestGenerator()
    local char = getChar()
    local hrp = getHRP()
    if not (char and hrp) then return nil end

    local MapFolder = RefreshMap()
    if not MapFolder then return nil end

    local closest, shortestDist = nil, math.huge
    for _, obj in ipairs(MapFolder:GetChildren()) do
        if obj.Name == "Generator" and obj:IsA("Model") and obj.PrimaryPart then
            local dist = (hrp.Position - obj.PrimaryPart.Position).Magnitude
            if dist < shortestDist then
                closest = obj
                shortestDist = dist
            end
        end
    end
    return closest
end

Tabs.Farm:AddButton({
    Title = "Finish Generator",
    Callback = function()
        if solveGeneratorCooldown or AutoFinishGen then return end

        local gen = getClosestGenerator()
        local remote = gen and getGeneratorRemote(gen)
        if remote then
            remote:FireServer()
            solveGeneratorCooldown = true
            task.delay(genDelay, function()
                solveGeneratorCooldown = false
            end)
        end
    end
})

Tabs.Farm:AddToggle("AutoFinishGen", {
    Title = "Auto Finish Generator",
    Default = false
}):OnChanged(function(state)
    AutoFinishGen = state

    if state then
        task.spawn(function()
            while AutoFinishGen do
                if solveGeneratorCooldown then
                    task.wait(0.1)
                else
                    local gen = getClosestGenerator()
                    local remote = gen and getGeneratorRemote(gen)
                    if remote then
                        remote:FireServer()
                    end
                    solveGeneratorCooldown = true
                    task.wait(genDelay)
                    solveGeneratorCooldown = false
                end
            end
        end)
    else
        solveGeneratorCooldown = false
    end
end)

Tabs.Farm:AddInput("GenDelayInput", {
    Title = "Enter Delay",
    Default = "1.5",
    Placeholder = "Write Here (1.5-10)",
    Numeric = true,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            genDelay = math.clamp(num, 1.5, 10)
        end
    end
})

    Tabs.Farm:AddSection("↳ Items")

local function pickUpNearest()
    local map = MapFolder or WaitForMap()
    if not map then return end

    local char = getChar()
    local hrp = getHRP()
    if not char or not hrp then return end

    local root = hrp
    local oldCFrame = root.CFrame

    for _, item in ipairs(map:GetChildren()) do
        if item:IsA("Tool")
            and item:FindFirstChild("ItemRoot")
            and item.ItemRoot:FindFirstChild("ProximityPrompt") then

            root.CFrame = item.ItemRoot.CFrame
            task.wait(0.3)
            
            pcall(function()
                fireproximityprompt(item.ItemRoot.ProximityPrompt)
            end)
            
            task.wait(0.4)
            root.CFrame = oldCFrame
            break
        end
    end
end

Tabs.Farm:AddButton({
    Title = "Pick Up Item",
    Callback = pickUpNearest
})

Tabs.Farm:AddToggle("ItemPick", {
    Title = "Auto PickUp Item",
    Default = false
}):OnChanged(function(state)
    _G.PickupItem = state
    if not state then return end

    task.spawn(function()
        while _G.PickupItem do
            pickUpNearest()
            task.wait(0.2)
        end
    end)
end)

    Tabs.Main:AddSection("↳ Eliot")

local toggleFlag = Instance.new("BoolValue")
toggleFlag.Name = "EliotPizzaAim_ToggleFlag"
toggleFlag.Value = false

Tabs.Main:AddToggle("NemPizza", {
    Title = "Pizza Aimbot",
    Default = false,
}):OnChanged(function(state)
    toggleFlag.Value = state
end)

local maxDistance = 100
Tabs.Main:AddInput("PizzaAimDistance", {
    Title = "Aim Distance",
    Default = tostring(maxDistance),
    Placeholder = "Enter Number",
}):OnChanged(function(v)
    local n = tonumber(v)
    if n then maxDistance = n end
end)

local PizzaAnimation = {
    ["114155003741146"] = true,
    ["104033348426533"] = true
}
local EliotModels = { ["Elliot"] = true }
local autoRotateDisabledByScript = false
local currentTarget, isLockedOn, wasPlayingAnimation = nil, false, false
local aimOffset = 2

local function getSurvivors()
    return getSurvivorsFolder() or (Workspace:FindFirstChild("Players") and Workspace.Players:FindFirstChild("Survivors"))
end

local function isEliot()
    local c = getChar()
    return c and EliotModels[c.Name] or false
end

local function restoreAutoRotate()
    local hum = getHumanoid()
    if hum and autoRotateDisabledByScript then
        hum.AutoRotate = true
        autoRotateDisabledByScript = false
    end
end

local function isPlayingDangerousAnimation()
    local hum = getHumanoid()
    if not hum then return false end
    local animator = hum:FindFirstChildWhichIsA("Animator")
    if not animator then return false end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animId = track.Animation and tostring(track.Animation.AnimationId):match("%d+")
        if animId and PizzaAnimation[animId] then
            return true
        end
    end
    return false
end

local function getWeakestSurvivor()
    local survivors = getSurvivors()
    if not survivors then return nil end
    local myChar = getChar()
    local myHum = getHumanoid()
    local myRoot = getHRP()
    if not myHum or not myRoot or not myHum.MaxHealth or myHum.MaxHealth <= 0 then return nil end

    local myHpPercent = myHum.Health / myHum.MaxHealth
    local list = {}

    for _, mdl in ipairs(survivors:GetChildren()) do
        if mdl:IsA("Model") and mdl ~= myChar then
            local hum = mdl:FindFirstChildWhichIsA("Humanoid")
            local hrp = mdl:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 and hum.MaxHealth > 0 then
                local dist = (hrp.Position - myRoot.Position).Magnitude
                if dist <= maxDistance then
                    table.insert(list, { model = mdl, hp = hum.Health / hum.MaxHealth })
                end
            end
        end
    end

    if #list == 0 then return nil end
    table.sort(list, function(a,b) return a.hp < b.hp end)

    if myHpPercent <= list[1].hp and #list > 1 then
        return list[2].model
    else
        return list[1].model
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    autoRotateDisabledByScript = false
end)

RunService.RenderStepped:Connect(function()
    if not toggleFlag.Value then
        restoreAutoRotate()
        currentTarget, isLockedOn, wasPlayingAnimation = nil, false, false
        return
    end

    if not isEliot() then
        restoreAutoRotate()
        currentTarget, isLockedOn, wasPlayingAnimation = nil, false, false
        return
    end

    local hum = getHumanoid()
    local root = getHRP()
    if not hum or not root then return end

    local playing = isPlayingDangerousAnimation()

    if playing and not isLockedOn then
        currentTarget = getWeakestSurvivor()
        if currentTarget then isLockedOn = true end
    end

    if isLockedOn and currentTarget then
        local tHum = currentTarget:FindFirstChildWhichIsA("Humanoid")
        local tRoot = currentTarget:FindFirstChild("HumanoidRootPart")
        if not (tHum and tRoot and tHum.Health > 0) then
            currentTarget, isLockedOn = nil, false
        end
    end

    if (not playing) and wasPlayingAnimation then
        currentTarget, isLockedOn = nil, false
        restoreAutoRotate()
    end
    wasPlayingAnimation = playing

    if playing and isLockedOn and currentTarget then
        local tRoot = currentTarget:FindFirstChild("HumanoidRootPart")
        if tRoot then
            if not autoRotateDisabledByScript then
                hum.AutoRotate = false
                autoRotateDisabledByScript = true
            end

            local targetCFrame = CFrame.new(Vector3.new(tRoot.Position.X, root.Position.Y, tRoot.Position.Z) + root.CFrame.RightVector * aimOffset)
            AimSystem.RotateTo(targetCFrame, 0.99)
        end
    end
end)

getgenv().BlinkToPizzaToggle = getgenv().BlinkToPizzaToggle or false
getgenv().HPThreshold = getgenv().HPThreshold or 30

Tabs.Main:AddToggle("BlinkPizza_Toggle", {
    Title = "Auto Eat Pizza",
    Default = getgenv().BlinkToPizzaToggle,
}):OnChanged(function(s)
    getgenv().BlinkToPizzaToggle = s
end)

Tabs.Main:AddInput("PizzaHPThreshold", {
    Title = "HP Threshold",
    Default = tostring(getgenv().HPThreshold),
    Placeholder = "30",
}):OnChanged(function(v)
    local n = tonumber(v)
    if n then getgenv().HPThreshold = n end
end)

local function getPizzaCF()
    local map = RefreshMap() or WaitForMap()
    if not map then return nil end

    local pizza = map:FindFirstChild("Pizza")
    if not pizza then return nil end

    if pizza:IsA("BasePart") or pizza:IsA("MeshPart") or pizza:IsA("UnionOperation") then
        return pizza.CFrame
    elseif pizza:IsA("Model") then
        local pp = pizza.PrimaryPart or pizza:FindFirstChildWhichIsA("BasePart")
        if pp then
            if not pizza.PrimaryPart then pizza.PrimaryPart = pp end
            return pp.CFrame
        end
    elseif pizza:IsA("CFrameValue") then
        return pizza.Value
    end
    return nil
end

task.spawn(function()
    while task.wait(0.9) do
        if getgenv().BlinkToPizzaToggle then
            local hrp = getHRP()
            local hum = getHumanoid()
            if hrp and hum then
                local pizzaCF = getPizzaCF()
                if pizzaCF and hum.Health <= getgenv().HPThreshold then
                    local old = hrp.CFrame
                    hrp.CFrame = pizzaCF * CFrame.new(0, 1, 0)

                    if getgenv().activateRemoteHook then
                        getgenv().activateRemoteHook("UnreliableRemoteEvent", "UpdCF")
                    end

                    task.delay(0.2, function()
                        hrp.CFrame = old
                        task.wait(0.3)
                        if getgenv().deactivateRemoteHook then
                            getgenv().deactivateRemoteHook("UnreliableRemoteEvent", "UpdCF")
                        end
                    end)
                end
            end
        end
    end
end)

Tabs.Main:AddSection("↳ Two Time")

local Mode = "AI Aimbot"
local checkRadius = 18
local backstabDelay = 0.01

local killersFolder = getKillersFolder()

local ANIM_IDS = {
    "115194624791339",
    "86545133269813",
    "89448354637442",
    "77119710693654",
    "107640065977686",
    "112902284724598",
}

Tabs.Main:AddDropdown("BackstabMode", {
    Title = "Backstab Mode",
    Values = { "AI Aimbot", "Player Aimbot", "AI Aimbot Pro" },
    Default = "AI Aimbot",
}):OnChanged(function(value)
    Mode = value
end)

local enabled = false
Tabs.Main:AddToggle("AutoBackstab", {
    Title = "Auto Backstab V2",
    Default = false
}):OnChanged(function(state)
    enabled = state
end)

Tabs.Main:AddInput("BackstabRadiusInput", {
    Title = "Check Radius",
    Default = tostring(checkRadius),
    Placeholder = "Write Here (1 - 50)",
    Numeric = true,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            checkRadius = math.clamp(num, 1, 50)
        end
    end
})

local daggerButton, daggerRemote, daggerConnections = nil, nil, {}

local function findDaggerRemote()
    if daggerRemote then return daggerRemote end
    if not daggerButton then return nil end

    for _, conn in ipairs(getconnections(daggerButton.MouseButton1Click)) do
        local f = conn.Function
        if f and islclosure(f) then
            for _, v in pairs(getupvalues(f)) do
                if typeof(v) == "Instance" and v:IsA("RemoteEvent") then
                    daggerRemote = v
                    return daggerRemote
                end
            end
        end
    end
end

local function initDaggerButton()
    local gui = getPlayerGui()
    if not gui then return end

    local mainUI = gui:FindFirstChild("MainUI")
    local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
    daggerButton = container and container:FindFirstChild("Dagger")

    if daggerButton and daggerButton:IsA("ImageButton") then
        daggerConnections = getconnections(daggerButton.MouseButton1Click)
        findDaggerRemote()
    end
end

initDaggerButton()
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    initDaggerButton()
end)

local function useDagger()
    if daggerRemote then
        pcall(function()
            daggerRemote:FireServer(true)
            task.delay(0.05, function()
                daggerRemote:FireServer(false)
            end)
        end)
    elseif daggerButton then
        for _, conn in ipairs(daggerConnections) do
            pcall(function() conn:Fire() end)
        end
        pcall(function() daggerButton:Activate() end)
    end
end

local function isPlayingTargetAnimation(humanoid)
    if not humanoid then return false end

    for _, t in ipairs(humanoid:GetPlayingAnimationTracks()) do
        local animId = tostring(t.Animation.AnimationId or "")
        for _, id in ipairs(ANIM_IDS) do
            if animId:find(id, 1, true) then
                return true
            end
        end
    end
    return false
end

local function teleportBehind(targetHRP, myHRP)
    local look = targetHRP.CFrame.LookVector
    local destPos = targetHRP.Position - look * 2
    myHRP.CFrame = CFrame.new(destPos, destPos + look)
end

local function isBehindTarget(targetHRP, myHRP)
    local look = targetHRP.CFrame.LookVector
    local dir = (myHRP.Position - targetHRP.Position).Unit
    return look:Dot(dir) < -0.5
end

local function getNearbyKillers(position)
    local killers = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position - position).Magnitude
                if dist <= checkRadius then
                    table.insert(killers, {model = plr.Character, hrp = hrp, dist = dist})
                end
            end
        end
    end
    return killers
end

local function getNearbyAIKillers(hrp)
    local killers = {}
    if not killersFolder then killersFolder = getKillersFolder() end
    if not killersFolder then return killers end

    for _, killer in ipairs(killersFolder:GetChildren()) do
        local kHRP = killer:FindFirstChild("HumanoidRootPart")
        if kHRP then
            local dist = (kHRP.Position - hrp.Position).Magnitude
            if dist <= checkRadius then
                table.insert(killers, {model = killer, hrp = kHRP, dist = dist})
            end
        end
    end
    return killers
end

local function dashBehind(targetHRP, myHumanoid, myHRP)
    if not (targetHRP and myHumanoid and myHRP) then return end
    local backOffset = targetHRP.CFrame.LookVector * 1.2
    local dest = targetHRP.Position - backOffset
    local ok = pcall(function() myHumanoid:MoveTo(dest) end)
    if not ok then
        pcall(function()
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            local dir = (dest - myHRP.Position)
            if dir.Magnitude > 0 then
                bv.Velocity = dir.Unit * 60
            else
                bv.Velocity = Vector3.new(0,0,0)
            end
            bv.Parent = myHRP
            task.delay(0.15, function() pcall(function() bv:Destroy() end) end)
        end)
    end
end

local cooldown = false
local lastTarget = nil

RunService.Heartbeat:Connect(function()
    if not enabled or cooldown then return end

    local char = getChar()
    local humanoid = getHumanoid()
    local myHRP = getHRP()
    if not (char and humanoid and myHRP) then return end

    if char.Name ~= "TwoTime" then return end

    if Mode == "Player Aimbot" then
        if isPlayingTargetAnimation(humanoid) then
            local killers = getNearbyKillers(myHRP.Position)
            if #killers > 0 then
                table.sort(killers, function(a, b) return a.dist < b.dist end)
                local target = killers[1]

                cooldown = true
                local start = tick()
                local conn
                conn = RunService.Heartbeat:Connect(function()
                    if not (char and char.Parent and target.hrp and target.hrp.Parent) then
                        if conn then conn:Disconnect() end
                        cooldown = false
                        return
                    end
                    if tick() - start >= 0.7 then
                        if conn then conn:Disconnect() end
                        task.delay(1, function() cooldown = false end)
                        return
                    end
                    teleportBehind(target.hrp, myHRP)
                    useDagger()
                end)
            end
        end

    elseif Mode == "AI Aimbot" then
        local killers = getNearbyAIKillers(myHRP)
        if #killers > 0 then
            table.sort(killers, function(a,b) return a.dist < b.dist end)
            local target = killers[1]
            if target.model ~= lastTarget and isBehindTarget(target.hrp, myHRP) then
                cooldown = true
                lastTarget = target.model
                local start = tick()
                local conn
                conn = RunService.Heartbeat:Connect(function()
                    if not (char and char.Parent and target.hrp and target.hrp.Parent) then
                        if conn then conn:Disconnect() end
                        return
                    end
                    if tick() - start >= 0.7 then
                        if conn then conn:Disconnect() end
                        task.delay(10, function()
                            cooldown = false
                            lastTarget = nil
                        end)
                        return
                    end
                    teleportBehind(target.hrp, myHRP)
                    useDagger()
                end)
            end
        end

    elseif Mode == "AI Aimbot Pro" then
        local killers = getNearbyAIKillers(myHRP)
        if #killers > 0 then
            table.sort(killers, function(a,b) return a.dist < b.dist end)
            local target = killers[1]
            if target.model ~= lastTarget and isBehindTarget(target.hrp, myHRP) then
                cooldown = true
                lastTarget = target.model

                local start = tick()
                local dashed = false
                local lastHit = 0
                local conn
                conn = RunService.Heartbeat:Connect(function(dt)
                    if not (char and char.Parent and target.hrp and target.hrp.Parent) then
                        if conn then conn:Disconnect() end
                        return
                    end
                    local elapsed = tick() - start
                    if elapsed <= 0.7 then
                        local targetCF = target.hrp.CFrame
                        local speed = math.clamp(0.9 + (dt and dt*60 or 1)*0.02, 0.1, 1)
                        AimSystem.RotateTo(targetCF, speed)
                        if not dashed then
                            dashed = true
                            pcall(function() dashBehind(target.hrp, humanoid, myHRP) end)
                        end
                        if tick() - lastHit >= backstabDelay then
                            lastHit = tick()
                            useDagger()
                        end
                    else
                        if conn then conn:Disconnect() end
                        task.delay(10, function()
                            cooldown = false
                            lastTarget = nil
                        end)
                        return
                    end
                end)
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
end)

    Tabs.Main:AddSection("↳ 007n7")

local ANIM_ID = "rbxassetid://75804462760596"
local InvisibleTrack = nil

local InstantInvisibleEnabled = false
local CloneInvisibleEnabled = false

local function getHumanoid()
    local char = getChar()
    return char and char:FindFirstChildOfClass("Humanoid"), char
end

local function getAnimator(humanoid)
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    return animator
end

local function playAnim(humanoid)
    if not humanoid then return end
    if InvisibleTrack and InvisibleTrack.IsPlaying then return end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local animator = getAnimator(humanoid)
    InvisibleTrack = animator:LoadAnimation(anim)
    InvisibleTrack.Looped = true
    InvisibleTrack:Play()
    InvisibleTrack:AdjustSpeed(0)
end

local function stopAnim()
    if InvisibleTrack then
        pcall(function()
            InvisibleTrack:Stop()
        end)
        InvisibleTrack = nil
    end
end

local function applyInstantInvisible()
    if not InstantInvisibleEnabled then return end

    local humanoid, char = getHumanoid()
    if not humanoid or not char then return end

    local survivorsFolder = getSurvivorsFolder()
    if survivorsFolder and survivorsFolder:FindFirstChild(char.Name) then
        playAnim(humanoid)
    else
        stopAnim()
    end
end

local function applyCloneInvisible()
    if not CloneInvisibleEnabled then return end

    local humanoid, char = getHumanoid()
    if not char then return end

    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if torso and torso.Transparency ~= 0 then
        if char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.Transparency = 0.4
        end
    else
        if char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.Transparency = 1
        end
    end
end

RunService.Heartbeat:Connect(function()
    applyInstantInvisible()
    applyCloneInvisible()
end)

Tabs.Main:AddToggle("InstantInvisibleV2", {
    Title = "Instant Invisible",
    Default = false,
    Callback = function(v)
        InstantInvisibleEnabled = v
        if not v then stopAnim() end
    end
})

Tabs.Main:AddToggle("InvisibleCloneV2", {
    Title = "Invisible If Cloned",
    Default = false,
    Callback = function(v)
        CloneInvisibleEnabled = v
        if not v then
            local _, char = getHumanoid()
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.Transparency = 1
            end
        end
    end
})

Tabs.Main:AddSection("↳ Veeronica")

Tabs.Main:AddToggle("AutoTrick", {
    Title = "Auto Trick V2",
    Default = false,
    Callback = function(Value)
        local device = "Mobile"

        local function getBehaviorFolder()
            local ok, folder = pcall(function()
                return ReplicatedStorage.Assets.Survivors.Veeronica.Behavior
            end)
            return ok and folder
        end

        local function getSprintingButton()
            local gui = getPlayerGui()
            if not gui then return end
            local main = gui:FindFirstChild("MainUI")
            if not main then return end
            return main:FindFirstChild("SprintingButton")
        end

        local function adorneeIsPlayerCharacter(h)
            if not h then return false end
            local adornee = h.Adornee
            local char = getChar()
            if not adornee or not char then return false end
            return adornee == char or adornee:IsDescendantOf(char)
        end

        local function triggerSprint()
            if device ~= "Mobile" then return end
            local btn = getSprintingButton()
            if not btn then return end
            local conns = getconnections(btn.MouseButton1Down)
            for _, v in pairs(conns) do
                pcall(function()
                    v:Fire()
                    if v.Function then v:Function() end
                end)
            end
        end

        local function cleanup()
            if _G.AutoTrick_Connections then
                for _, conn in ipairs(_G.AutoTrick_Connections) do
                    if conn and conn.Connected then
                        conn:Disconnect()
                    end
                end
                _G.AutoTrick_Connections = nil
            end
            if _G.AutoTrick_Loop then
                task.cancel(_G.AutoTrick_Loop)
                _G.AutoTrick_Loop = nil
            end
            print("[AutoTrick] Disabled")
        end

        if Value then
            print("[AutoTrick] Enabled")

            local behaviorFolder = getBehaviorFolder()
            if not behaviorFolder then
                warn("[AutoTrick] Behavior folder not found.")
                return
            end

            local highlights = {}
            _G.AutoTrick_Connections = {}

            local addConn = behaviorFolder.DescendantAdded:Connect(function(child)
                if child:IsA("Highlight") then
                    highlights[child] = true
                end
            end)

            local removeConn = behaviorFolder.DescendantRemoving:Connect(function(child)
                if child:IsA("Highlight") then
                    highlights[child] = nil
                end
            end)

            table.insert(_G.AutoTrick_Connections, addConn)
            table.insert(_G.AutoTrick_Connections, removeConn)

            _G.AutoTrick_Loop = task.spawn(function()
                while task.wait(0.3) do
                    if not Value then break end
                    for h in pairs(highlights) do
                        if adorneeIsPlayerCharacter(h) then
                            triggerSprint()
                            break
                        end
                    end
                end
            end)

        else
            cleanup()
        end
    end
})

Tabs.Main:AddSection("↳ Chance")

_G.AIMBOT_ACTIVE = false
_G.AIM_USE_OFFSET = true
_G.AIM_PREDICTION_MODE = "Speed"
_G.AIM_MODE = "Normal"
_G.AIM_DURATION = 1.7
_G.AIM_FASTER_DURATION = 1.5
_G.AIM_SPIN_DURATION = 0.5

_G.AIMING = false
_G.PREV_FLINT_VISIBLE = false
_G.LAST_TRIGGER = 0

_G.AUTO_COINFLIP = false
_G.COINFLIP_TARGET_CHARGE = 3
_G.COINFLIP_COOLDOWN = 0.15
_G.LAST_COINFLIP = 0

_G.BLOCK_COINFLIP_WHEN_CLOSE = true
_G.COINFLIP_BLOCK_DIST = 50

_G._AIM_REMOTE_EVENT = nil
pcall(function()
    _G._AIM_REMOTE_EVENT = ReplicatedStorage:WaitForChild("Modules")
        :WaitForChild("Network")
        :WaitForChild("RemoteEvent")
end)

function AC_GetValidTargetPart()
    local killers = getKillersFolder()
    if not killers then return nil end
    for i = 1, #killers:GetChildren() do
        local model = killers:GetChildren()[i]
        if model then
            local part = model:FindFirstChild("HumanoidRootPart")
            if part and part:IsA("BasePart") then
                return part
            end
        end
    end
    return nil
end

function AC_GetPingSeconds()
    local ok, stat = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"] end)
    if not ok or not stat then return 0.1 end
    local ok2, v = pcall(function() return stat:GetValue() end)
    if ok2 and type(v) == "number" then
        return v / 1000
    end
    return 0.1
end

function AC_IsFlintlockVisible()
    local ok, char = pcall(function() return getChar() end)
    if not ok or not char then return false end
    local success, flint = pcall(function() return char:FindFirstChild("Flintlock", true) end)
    if not success or not flint then return false end
    if not flint:IsA("BasePart") then return false end
    return flint.Transparency < 1
end

function AC_GetPredictedPos(targetHRP)
    if not targetHRP then return nil end
    local ping = AC_GetPingSeconds()

    local mode = _G.AIM_PREDICTION_MODE or "Speed"
    if mode == "Ping" then
        return targetHRP.Position + (targetHRP.Velocity or Vector3.zero) * ping
    elseif mode == "front" then
        return targetHRP.Position + (targetHRP.CFrame and targetHRP.CFrame.LookVector or Vector3.new()) * 4
    elseif mode == "No Lag" then
        return targetHRP.Position + (targetHRP.CFrame and targetHRP.CFrame.LookVector or Vector3.new()) * (ping * 60)
    else
        if _G.AIM_USE_OFFSET then
            return targetHRP.Position + (targetHRP.Velocity or Vector3.zero) * (4 / 60)
        else
            return targetHRP.Position
        end
    end
end

function AC_GetAbilityContainer()
    local ok, gui = pcall(function() return getPlayerGui() end)
    if not ok or not gui then return nil end
    local main = gui:FindFirstChild("MainUI")
    if not main then return nil end
    return main:FindFirstChild("AbilityContainer")
end

function AC_SafeClick(btn)
    if not btn then return end
    pcall(function()
        if btn.Activate then
            btn:Activate()
        end
    end)
    if pcall(function() return btn:IsA("GuiButton") end) then
        pcall(function() firesignal(btn.MouseButton1Click) end)
    end
    pcall(function()
        btn.Selectable = true
        btn.Modal = false
    end)
end

function AC_FindCoinflipButton()
    local container = AC_GetAbilityContainer()
    if not container then return nil end
    for i = 1, #container:GetDescendants() do
        local obj = container:GetDescendants()[i]
        if not obj then break end
        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
            local n = tostring(obj.Name):lower()
            local t = (pcall(function() return obj.Text end) and tostring(obj.Text):lower()) or ""
            if n:find("coin") or n:find("flip") or t:find("coin") or t:find("flip") then
                return obj
            end
        end
    end
    return nil
end

function AC_GetNearbyMaxNumber()
    local container = AC_GetAbilityContainer()
    if not container then return nil end
    local maxNum = nil
    for i = 1, #container:GetDescendants() do
        local obj = container:GetDescendants()[i]
        if not obj then break end
        if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and pcall(function() return obj.Text end) then
            local text = tostring(obj.Text):lower()
            if not text:find("s") then
                for num in text:gmatch("%d+") do
                    local n = tonumber(num)
                    if n and n >= 1 and n <= 10 then
                        if not maxNum or n > maxNum then
                            maxNum = n
                        end
                    end
                end
            end
        end
    end
    return maxNum
end

Tabs.Main:AddDropdown("AimMode", {
    Title = "Aim Mode",
    Values = {"Normal", "Faster", "Reflex"},
    Default = "Normal",
    Callback = function(val) _G.AIM_MODE = val end
})

Tabs.Main:AddDropdown("PredictionMode", {
    Title = "Prediction Mode",
    Values = {"Speed", "Ping", "front", "No Lag"},
    Default = "Speed",
    Callback = function(val) _G.AIM_PREDICTION_MODE = val end
})

Tabs.Main:AddDropdown("CoinflipChargeDropdown", {
    Title = "Select Score",
    Values = {"1 Point", "2 Point", "3 Point"},
    Default = "3 Point",
}):OnChanged(function(val)
    local num = tonumber(val:match("%d+"))
    if num then _G.COINFLIP_TARGET_CHARGE = num end
end)

Tabs.Main:AddInput("CoinflipDistance", {
    Title = "Distance",
    Default = tostring(_G.COINFLIP_BLOCK_DIST),
    Callback = function(val)
        local num = tonumber(val)
        if num then _G.COINFLIP_BLOCK_DIST = num end
    end
})

Tabs.Main:AddToggle("BlockCoinflipToggle", {
    Title = "Safe Mode",
    Default = true,
}):OnChanged(function(state) _G.BLOCK_COINFLIP_WHEN_CLOSE = state end)

Tabs.Main:AddToggle("OffsetToggle", {
    Title = "Enable Offset",
    Default = true,
    Callback = function(state) _G.AIM_USE_OFFSET = state end
})

Tabs.Main:AddToggle("AimbotToggle", {
    Title = "Auto Aim Shoot",
    Default = false,
    Callback = function(state) _G.AIMBOT_ACTIVE = state end
})

Tabs.Main:AddToggle("AutoCoinflipToggle", {
    Title = "Auto Coin Flip",
    Default = false,
}):OnChanged(function(state) _G.AUTO_COINFLIP = state end)

spawn(function()
    local POLL_RATE = 0.03
    local attackStart = 0

    while task.wait(POLL_RATE) do
        if _G.AIMBOT_ACTIVE and getHumanoid() and getHRP() then
            local visible = AC_IsFlintlockVisible()

            if visible and not _G.PREV_FLINT_VISIBLE and not _G.AIMING then
                _G.AIMING = true
                _G.LAST_TRIGGER = tick()
            end

            _G.PREV_FLINT_VISIBLE = visible

            if _G.AIMING then
                local elapsed = tick() - (_G.LAST_TRIGGER or 0)
                local duration = (_G.AIM_MODE == "Faster") and _G.AIM_FASTER_DURATION or _G.AIM_DURATION

                if _G.AIM_MODE == "Reflex" and elapsed <= _G.AIM_SPIN_DURATION then
                    local a = math.rad(360 * (elapsed / _G.AIM_SPIN_DURATION))
                    local me = getHRP()
                    if me then
                        pcall(function()
                            me.CFrame = CFrame.new(me.Position) * CFrame.Angles(0, a, 0)
                        end)
                    end

                elseif elapsed <= duration then
                    local humanoid = getHumanoid()
                    if humanoid then
                        pcall(function() humanoid.AutoRotate = false end)
                    end

                    local targetPart = AC_GetValidTargetPart()
                    if targetPart then
                        local predicted = AC_GetPredictedPos(targetPart)
                        if predicted then
                            pcall(function()
                                local cf = CFrame.new(predicted)
                                if type(AimSystem) == "table" and type(AimSystem.RotateTo) == "function" then
                                    AimSystem.RotateTo(cf, 0.99)
                                else
                                    local me = getHRP()
                                    if me then me.CFrame = CFrame.lookAt(me.Position, predicted) end
                                end
                            end)
                        end
                    end

                else
                    _G.AIMING = false
                    local humanoid = getHumanoid()
                    if humanoid then pcall(function() humanoid.AutoRotate = true end) end
                end
            end
        end

        if _G.AUTO_COINFLIP then
            local block = false
            if _G.BLOCK_COINFLIP_WHEN_CLOSE then
                local tp = AC_GetValidTargetPart()
                local me = getHRP()
                if tp and me then
                    local ok, d = pcall(function() return (tp.Position - me.Position).Magnitude end)
                    if ok and d and d <= _G.COINFLIP_BLOCK_DIST then
                        block = true
                    end
                end
            end

            if not block and tick() - (_G.LAST_COINFLIP or 0) >= _G.COINFLIP_COOLDOWN then
                local maxNum = AC_GetNearbyMaxNumber()
                if not maxNum or maxNum < (_G.COINFLIP_TARGET_CHARGE or 3) then
                    _G.LAST_COINFLIP = tick()
                    local btn = AC_FindCoinflipButton()
                    if btn then
                        AC_SafeClick(btn)
                    else
                        local re = _G._AIM_REMOTE_EVENT
                        if re then
                            pcall(function() re:FireServer("UseActorAbility", "CoinFlip") end)
                        end
                    end
                end
            end
        end
    end
end)

Tabs.Main:AddSection("↳ 1x1x1x1")

_G.MASS_AIM_MODE = "One Player"
_G.MASS_TOGGLE = false

local MASS_IDS = {
    ["131430497821198"]=true,
    ["100592913030351"]=true,
    ["70447634862911"]=true,
    ["83685305553364"]=true,
    ["101101433684051"]=true,
    ["109777684604906"]=true
}

function _G.MassAnimCheck()
    local h = getHumanoid()
    if h then
        local tr = h:GetPlayingAnimationTracks()
        for i=1,#tr do
            local a = tr[i].Animation
            if a then
                local id = string.gsub(a.AnimationId,"[^0-9]","")
                if MASS_IDS[id] then
                    return true
                end
            end
        end
    end
    return false
end

function _G.MassGetNearest()
    local folder = getSurvivorsFolder()
    if folder then
        local me = getHRP()
        if me then
            local best=nil
            local dist=999999
            local list=folder:GetChildren()
            for i=1,#list do
                local p=list[i]
                local hrp=p:FindFirstChild("HumanoidRootPart")
                local hum=p:FindFirstChild("Humanoid")
                if hrp and hum and hum.Health>0 then
                    local d=(me.Position-hrp.Position).Magnitude
                    if d<dist then
                        dist=d
                        best=p
                    end
                end
            end
            return best
        end
    end
    return nil
end

spawn(function()
    while task.wait(0.03) do
        if _G.MASS_TOGGLE == true then

            if _G.MassAnimCheck() == true then
                local t = _G.MassGetNearest()
                if t then
                    local hrp = t:FindFirstChild("HumanoidRootPart")
                    local hum = t:FindFirstChild("Humanoid")
                    local me = getHRP()

                    if hrp and hum and hum.Health>0 and me then
                        if _G.MASS_AIM_MODE == "Teleport" then
                            local back = (hrp.CFrame*CFrame.new(0,0,-3)).Position
                            me.CFrame = CFrame.lookAt(back,hrp.Position)
                        else
                            me.CFrame = CFrame.lookAt(me.Position,hrp.Position)
                        end
                    end
                end
            end

        end
    end
end)

Tabs.Main:AddDropdown("MassAimMode",{
    Title="Aim Mode",
    Values={"One Player","Multi Players","Teleport"},
    Default="One Player",
}):OnChanged(function(v)
    _G.MASS_AIM_MODE=v
end)

Tabs.Main:AddToggle("MassInfectionAimbot",{
    Title="MassInfection Aimbot",
    Default=false,
}):OnChanged(function(v)
    _G.MASS_TOGGLE=v
end)

Tabs.Main:AddSection("↳ Guest1337")

function isKiller(player)
    local ok, killersFolder = pcall(getKillersFolder)
    if not ok or not killersFolder or not player then return false end

    if killersFolder:FindFirstChild(player.Name) then return true end

    local char = player.Character
    if char and killersFolder:FindFirstChild(char.Name) then return true end
    return false
end

animationIds = {
        ["83829782357897"]  = true,
        ["126830014841198"] = true,
        ["126355327951215"] = true,
        ["121086746534252"] = true,
        ["105458270463374"] = true,
        ["18885909645"]     = true,
        ["94162446513587"]  = true,
        ["93069721274110"]  = true,
        ["97433060861952"]  = true,
        ["121293883585738"] = true,
        ["92173139187970"]  = true,
        ["106847695270773"] = true,
        ["125403313786645"] = true,
        ["81639435858902"]  = true,
        ["137314737492715"] = true,
        ["120112897026015"] = true,
        ["82113744478546"]  = true,
        ["118298475669935"] = true,
        ["126681776859538"] = true,
        ["129976080405072"] = true,
        ["109667959938617"] = true,
        ["74707328554358"]  = true,
        ["133336594357903"] = true,
        ["86204001129974"]  = true,
        ["70371667919898"]  = true,
        ["131543461321709"] = true,
        ["106776364623742"] = true,
        ["136323728355613"] = true,
        ["109230267448394"] = true,
        ["139835501033932"] = true,
        ["114356208094580"] = true,
        ["106538427162796"] = true,
        ["126896426760253"] = true,
        ["126171487400618"]  = true,
        ["97167027849946"]  = true,
        ["99135633258223"]  = true,
        ["98456918873918"]  = true,
        ["83251433279852"]  = true,
        ["126681776859538"] = true,
        ["129976080405072"] = true,
        ["122709416391891"] = true,
        ["87989533095285"] = true,
        ["139309647473555"] = true,
        ["133363345661032"] = true,
        ["128414736976503"] = true,
        ["77375846492436"] = true,
        ["92445608014276"] = true,
        ["100358581940485"] = true,
        ["91758760621955"] = true,
        ["94634594529334"] = true,
        ["90620531468240"] = true,
        ["94958041603347"] = true,
        ["131642454238375"] = true,
        ["110702884830060"] = true,
        ["76312020299624"] = true,
        ["126654961540956"] = true,
        ["139613699193400"] = true,
        ["91509234639766"] = true,
        ["105458270463374"] = true,
        ["114506382930939"] = true,
        ["82113036350227"] = true,
        ["88451353906104"] = true,
}

massInfectionIds = {
    ["131430497821198"] = true,
    ["100592913030351"] = true,
    ["70447634862911"]  = true,
    ["83685305553364"]  = true,
    ["101101433684051"] = true,
    ["109777684604906"] = true,
}

delayedAnimations = {}

toggleOn = false
strictRangeOn = false
detectionRange = 18
showCircleOn = true

blockRemote = nil
blockButton = nil
connections = {}

function findBlockRemote()
    if blockRemote then return blockRemote end
    if not blockButton then return nil end

    local ok, conns = pcall(function()
        return getconnections(blockButton.MouseButton1Click)
    end)
    if not ok or not conns then return nil end

    for i = 1, #conns do
        local conn = conns[i]
        local f = conn and conn.Function
        if f and islclosure(f) then
            local ok2, ups = pcall(getupvalues, f)
            if ok2 and ups then
                for _, v in pairs(ups) do
                    if typeof(v) == "Instance" and v:IsA("RemoteEvent") then
                        blockRemote = v
                        return blockRemote
                    end
                end
            end
        end
    end
    return nil
end

function initBlockButton()
    local gui = getPlayerGui()
    if not gui then return end

    local mainUI = gui:FindFirstChild("MainUI")
    local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
    blockButton = container and container:FindFirstChild("Block")

    if blockButton and blockButton:IsA("ImageButton") then
        pcall(function()
            connections = getconnections(blockButton.MouseButton1Click)
        end)
        findBlockRemote()
    end
end

initBlockButton()
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0)
    initBlockButton()
end)

function fastBlock()
    if blockRemote then
        pcall(function()
            blockRemote:FireServer(true)
            task.delay(1e-10, function()
                pcall(function()
                    blockRemote:FireServer(false)
                end)
            end)
        end)
    else
        if not blockButton or not blockButton.Visible then return end
        for i = 1, #connections do
            local conn = connections[i]
            pcall(function() conn:Fire() end)
        end
        pcall(function() blockButton:Activate() end)
    end
end

lastTeleport = 0
function teleportDodge(killerChar)
    local now = tick()
    if now - lastTeleport < 5 then return end
    lastTeleport = now

    local myRoot = getHRP()
    local killerRoot = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
    if not (myRoot and killerRoot) then return end

    local oldCFrame = myRoot.CFrame
    local forward = killerRoot.CFrame.LookVector
    myRoot.CFrame = killerRoot.CFrame + forward * 7.5

    task.delay(0.1, function()
        if myRoot then
            myRoot.CFrame = oldCFrame
        end
    end)
end

function getBoolFlag(name, default)
    local flag = LocalPlayer:FindFirstChild(name)
    if not flag then
        flag = Instance.new("BoolValue")
        flag.Name = name
        flag.Value = default
        flag.Parent = LocalPlayer
    end
    return flag
end

function getNumberFlag(name, default)
    local flag = LocalPlayer:FindFirstChild(name)
    if not flag then
        flag = Instance.new("NumberValue")
        flag.Name = name
        flag.Value = default
        flag.Parent = LocalPlayer
    end
    return flag
end

toggleFlag = getBoolFlag("AutoBlockToggle", false)
strictFlag = getBoolFlag("AutoBlockStrictRange", false)
rangeFlag = getNumberFlag("AutoBlockRange", 18)
circleFlag = getBoolFlag("ShowKillerCircle", false)

toggleOn = toggleFlag.Value
strictRangeOn = strictFlag.Value
detectionRange = rangeFlag.Value
showCircleOn = circleFlag.Value

Tabs.Main:AddToggle("AutoBlockV3", {Title = "Auto Block", Default = toggleOn}):OnChanged(function(state)
    toggleOn = state
    toggleFlag.Value = state
end)

Tabs.Main:AddToggle("AutoCheckV3", {Title = "Range Check", Default = strictRangeOn}):OnChanged(function(state)
    strictRangeOn = state
    strictFlag.Value = state
end)

Tabs.Main:AddToggle("ShowCircle", {Title = "Show Circle", Default = showCircleOn}):OnChanged(function(state)
    showCircleOn = state
    circleFlag.Value = state
end)

Tabs.Main:AddInput("RangeInput", {
    Title = "Detection Range",
    Default = tostring(detectionRange),
    Placeholder = "Enter range"
}):OnChanged(function(txt)
    local val = tonumber(txt)
    if val then
        detectionRange = val
        rangeFlag.Value = val
    end
end)

playerConns = {}
recentBlocks = {}

function shouldBlockNow(p, animId, track)
    recentBlocks[p.UserId] = recentBlocks[p.UserId] or {}
    local last = recentBlocks[p.UserId][animId] or 0
    local now = tick()

    if now - last >= 0 then
        recentBlocks[p.UserId][animId] = now
        return true
    end
    return false
end

function onAnimationPlayed(player, char, track)
    if not toggleOn then return end
    if not (track and track.Animation) then return end

    local animIdStr = track.Animation.AnimationId
    local id = animIdStr and string.match(animIdStr, "%d+")
    if not id then return end
    if not (animationIds[id] or massInfectionIds[id]) then return end

    if strictRangeOn then
        local myRoot = getHRP()
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not myRoot or not root then return end
        if (root.Position - myRoot.Position).Magnitude > detectionRange then return end
    end

    if shouldBlockNow(player, id, track) then
        if massInfectionIds[id] then
            task.delay(0.5, fastBlock)
        else
            fastBlock()
        end

        if isKiller(player) and delayedAnimations[id] then
            teleportDodge(char)
        end
    end
end

function monitorCharacter(player, char)
    if not player or not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if not hum then return end

    local con = hum.AnimationPlayed:Connect(function(track)
        task.spawn(onAnimationPlayed, player, char, track)
    end)

    playerConns[player] = playerConns[player] or {}
    table.insert(playerConns[player], con)
end

function onPlayerAdded(player)
    if player == LocalPlayer then return end
    if player.Character then
        monitorCharacter(player, player.Character)
    end

    local con = player.CharacterAdded:Connect(function(char)
        task.wait(0)
        monitorCharacter(player, char)
    end)

    playerConns[player] = playerConns[player] or {}
    table.insert(playerConns[player], con)
end

for i = 1, #Players:GetPlayers() do
    onPlayerAdded(Players:GetPlayers()[i])
end

Players.PlayerAdded:Connect(onPlayerAdded)

circles = {}

function createCircleFor(player, hrp)
    if circles[player] then pcall(function() circles[player]:Destroy() end) end

    local circle = Instance.new("Part")
    circle.Anchored = true
    circle.CanCollide = false
    circle.Shape = Enum.PartType.Cylinder
    circle.Size = Vector3.new(0.2, detectionRange * 2, detectionRange * 2)
    circle.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(90))
    circle.Material = Enum.Material.Neon
    circle.Transparency = 0.5
    circle.Parent = Workspace

    circles[player] = circle
end

RunService.Heartbeat:Connect(function()
    if not showCircleOn then
        for _, c in pairs(circles) do
            if c then c.Transparency = 1 end
        end
        return
    end

    local myRoot = getHRP()
    if not myRoot then return end

    local killersFolder = getKillersFolder()

    local list = Players:GetPlayers()
    for i = 1, #list do
        local player = list[i]
        if player ~= LocalPlayer then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 and killersFolder and 
               (killersFolder:FindFirstChild(player.Name) or (char and killersFolder:FindFirstChild(char.Name))) then

                if not circles[player] then
                    createCircleFor(player, hrp)
                end

                local circle = circles[player]
                circle.Size = Vector3.new(0.2, detectionRange * 2, detectionRange * 2)
                circle.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(90))

                local dist = (myRoot.Position - hrp.Position).Magnitude
                circle.Color = dist <= detectionRange and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
                circle.Transparency = 0.5
            else
                if circles[player] then
                    circles[player]:Destroy()
                    circles[player] = nil
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if circles[player] then
        circles[player]:Destroy()
        circles[player] = nil
    end
end)

local autoPunchOn, aimPunch, flingPunchOn, customPunchEnabled = false, false, false, false
local hiddenfling = false
local flingPower = 10000
local predictionValue = 4
local customPunchAnimId = ""
local lastPunchTime = 0
local punchAnimIds = { "87259391926321" }

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function playCustomPunch(animId)
    if not Humanoid then return end
    if not animId or animId == "" then return end
    local now = tick()
    if now - lastPunchTime < 1 then return end

    for _, track in ipairs(Humanoid:GetPlayingAnimationTracks()) do
        local animNum = tostring(track.Animation.AnimationId):match("%d+")
        if table.find(punchAnimIds, animNum) then
            track:Stop()
        end
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. animId
    local track = Humanoid:LoadAnimation(anim)
    track:Play()
    lastPunchTime = now
end

coroutine.wrap(function()
    local hrp, c, vel, movel = nil, nil, nil, 0.1
    while true do
        RunService.Heartbeat:Wait()
        if hiddenfling then
            while hiddenfling and not (c and c.Parent and hrp and hrp.Parent) do
                RunService.Heartbeat:Wait()
                c = getChar()
                hrp = c and c:FindFirstChild("HumanoidRootPart")
            end
            if hiddenfling then
                vel = hrp.Velocity
                hrp.Velocity = vel * flingPower + Vector3.new(0, flingPower, 0)
                RunService.RenderStepped:Wait()
                hrp.Velocity = vel
                RunService.Stepped:Wait()
                hrp.Velocity = vel + Vector3.new(0, movel, 0)
                movel = movel * -1
            end
        end
    end
end)()

RunService.RenderStepped:Connect(function()
    local myChar = getChar()
    local myRoot = getHRP()
    Humanoid = getHumanoid()
    if not myChar or not myRoot or not Humanoid then return end

    if autoPunchOn then
        local gui = PlayerGui:FindFirstChild("MainUI")
        local punchBtn = gui and gui:FindFirstChild("AbilityContainer") and gui.AbilityContainer:FindFirstChild("Punch")
        local charges = punchBtn and punchBtn:FindFirstChild("Charges")

        if charges and charges.Text == "1" then
            local killersFolder = getKillersFolder()

            if killersFolder then
                for _, killer in ipairs(killersFolder:GetChildren()) do
                    local root = killer:FindFirstChild("HumanoidRootPart")

                    if root and (root.Position - myRoot.Position).Magnitude <= 10 then

                        if aimPunch then
                            Humanoid.AutoRotate = false
                            task.spawn(function()
                                local start = tick()
                                while tick() - start < 2 do
                                    if myRoot and root and root.Parent then
                                        local predictedPos = root.Position + (root.CFrame.LookVector * predictionValue)
                                        myRoot.CFrame = CFrame.lookAt(myRoot.Position, predictedPos)
                                    end
                                    task.wait()
                                end
                                Humanoid.AutoRotate = true
                            end)
                        end

                        for _, conn in ipairs(getconnections(punchBtn.MouseButton1Click)) do
                            pcall(function()
                                conn:Fire()
                            end)
                        end

                        if flingPunchOn then
                            hiddenfling = true
                            task.spawn(function()
                                local start = tick()
                                while tick() - start < 1 do
                                    if getHRP() and root and root.Parent then
                                        local frontPos = root.Position + (root.CFrame.LookVector * 2)
                                        getHRP().CFrame = CFrame.new(frontPos, root.Position)
                                    end
                                    task.wait()
                                end
                                hiddenfling = false
                            end)
                        end

                        if customPunchEnabled and customPunchAnimId ~= "" then
                            playCustomPunch(customPunchAnimId)
                        end

                        break
                    end
                end
            end
        end
    end
end)

Tabs.Main:AddToggle("AutoPunch", { Title = "Auto Punch", Default = false })
    :OnChanged(function(val) autoPunchOn = val end)

Tabs.Main:AddToggle("AimPunch", { Title = "Punch Aimbot", Default = false })
    :OnChanged(function(val) aimPunch = val end)

Tabs.Main:AddToggle("FlingPunch", { Title = "Fling Punch", Default = false })
    :OnChanged(function(val) flingPunchOn = val end)

Tabs.Main:AddSlider("Prediction", {
    Title = "Aim Prediction",
    Min = 0, Max = 10, Default = 4, Rounding = 1,
}):OnChanged(function(val) predictionValue = val end)

Tabs.Main:AddSlider("FlingPower", {
    Title = "Fling Power",
    Min = 5000, Max = 500000, Default = 10000, Rounding = 0,
}):OnChanged(function(val) flingPower = val end)

Tabs.Main:AddInput("CustomAnim", {
    Title = "Custom Punch",
    Default = "",
    Placeholder = "Enter Animation ID"
}):OnChanged(function(txt) customPunchAnimId = txt end)

Tabs.Main:AddToggle("EnableCustomAnim", { Title = "Enable Custom Animation", Default = false })
    :OnChanged(function(val) customPunchEnabled = val end)

Tabs.Event:AddSection("↳ Halloween")

Tabs.Event:AddButton({
    Title = "TP to Shop",
    Description = "Teleport đến khu Shop",
    Callback = function()
        local hrp = getHRP()
        if hrp and hrp:IsA("BasePart") then
            local ok = pcall(function() hrp.CFrame = CFrame.new(-3540.36, -392.73, 231.53) end)
            if not ok then return end
        end
    end,
})

local allowedModels = {
    ["dumsek"]=true, ["toon dusek"]=true, ["dusek"]=true,
    ["umdum"]=true, ["doothsek"]=true
}

local blockedCenter = Vector3.new(-3485.02, 4.48, 217.77)
local blockedRadius = 500

local function safeLower(s)
    if type(s) ~= "string" then return "" end
    return s:lower()
end

local function getModelPart(model)
    if not model then return nil end
    local a = model:FindFirstChild("HumanoidRootPart")
    if a and a:IsA("BasePart") then return a end
    local b = model.PrimaryPart
    if b and b:IsA("BasePart") then return b end
    local c = model:FindFirstChildWhichIsA("BasePart")
    if c then return c end
    return nil
end

local function isValidSukkar(model)
    if not model or not model:IsA("Model") or not model:IsDescendantOf(Workspace) then
        return false
    end
    if not allowedModels[safeLower(model.Name)] then
        return false
    end
    local part = getModelPart(model)
    if not part then return false end
    local ok, mag = pcall(function() return (part.Position - blockedCenter).Magnitude end)
    if not ok or type(mag) ~= "number" then return false end
    return mag > blockedRadius
end

ESP:RegisterType("Sukkars", Color3.fromRGB(0, 85, 255), isValidSukkar, false)

Tabs.Event:AddToggle("ESPSukkarsToggle", {
    Title = "ESP Sukkars",
    Default = false,
    Callback = function(state)
        ESP:SetEnabled("Sukkars", state)
    end
})

do
    local oldCreate = ESP.Create
    ESP.Create = function(self, model, typeName)
        pcall(function() oldCreate(self, model, typeName) end)

        if typeName ~= "Sukkars" then return end
        if not model or not model:IsA("Model") then return end

        local part = getModelPart(model)
        if not part then return end

        if not part:FindFirstChild("_TouchedFlag") then
            local flag = Instance.new("BoolValue")
            flag.Name = "_TouchedFlag"
            flag.Parent = part

            part.Touched:Connect(function(hit)
                local char = getChar()
                if not char or not hit then return end
                local ok = pcall(function()
                    if hit:IsDescendantOf(char) then
                        ESP:Remove(model)
                    end
                end)
                if not ok then return end
            end)
        end
    end
end

local cleanupConn = nil
do
    local acc = 0
    local interval = 0.15

    local function runCleanup(dt)
        acc = acc + dt
        if acc < interval then return end
        acc = 0

        local hrp = getHRP()
        if not (hrp and hrp:IsA("BasePart")) then return end

        if not ESP or type(ESP.Objects) ~= "table" then return end

        local keys = {}
        for k,v in pairs(ESP.Objects) do
            keys[#keys+1] = k
        end

        for _, model in ipairs(keys) do
            local data = ESP.Objects[model]
            if data and data.type == "Sukkars" then
                local part = getModelPart(model)
                if not part then
                    pcall(function() ESP:Remove(model) end)
                else
                    local ok, dist = pcall(function() return (hrp.Position - part.Position).Magnitude end)
                    if ok and type(dist) == "number" then
                        if dist <= 5 or dist > 1200 then
                            pcall(function() ESP:Remove(model) end)
                        end
                    end
                end
            end
        end
    end

    local function start()
        if cleanupConn then return end
        cleanupConn = RunService.Heartbeat:Connect(runCleanup)
    end

    local function stop()
        if cleanupConn then
            cleanupConn:Disconnect()
            cleanupConn = nil
        end
    end

    start()
end

local autoConn = nil
local TargetNames = {"dumsek","toon dusek","umdum","dusek","doothsek"}
local ScanInterval = 0.5
local TeleportDelay = 0.25
local HeightSafe = 5

local visitedModels = {}
local currentTarget = nil
local autoEnabled = false

local function getModelCFrame(model)
    if not model then return nil end
    local part = getModelPart(model)
    if part then return part.CFrame end
    if type(model.GetPivot) == "function" then
        local ok, pivot = pcall(function() return model:GetPivot() end)
        if ok then return pivot end
    end
    return nil
end

local function isAutoValid(model)
    if not model or not model:IsA("Model") then return false end
    local low = safeLower(model.Name)
    for i = 1, #TargetNames do
        if low == TargetNames[i] then
            local cf = getModelCFrame(model)
            if not cf then return false end
            local ok, mag = pcall(function() return (cf.Position - blockedCenter).Magnitude end)
            if ok and type(mag) == "number" then
                return mag > blockedRadius
            end
            return false
        end
    end
    return false
end

local function findTargets()
    local out = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and isAutoValid(obj) then
            out[#out+1] = obj
        end
    end
    return out
end

local function isTouchingTarget(target)
    local hrp = getHRP()
    if not (hrp and hrp:IsA("BasePart")) then return false end
    if not target then return false end
    local part = getModelPart(target)
    if not part then return false end
    local ok, dist = pcall(function() return (hrp.Position - part.Position).Magnitude end)
    return ok and type(dist) == "number" and dist <= 6
end

local function teleportToNext()
    local hrp = getHRP()
    if not (hrp and hrp:IsA("BasePart")) then return end

    for k, _ in pairs(visitedModels) do
        if not (k and type(k.IsDescendantOf) == "function" and k:IsDescendantOf(Workspace)) then
            visitedModels[k] = nil
        end
    end

    local all = findTargets()
    local available = {}
    for _, m in ipairs(all) do
        if not visitedModels[m] then
            available[#available+1] = m
        end
    end

    if #available == 0 then
        for kk, _ in pairs(visitedModels) do visitedModels[kk] = nil end
        return
    end

    table.sort(available, function(a, b)
        local ca = getModelCFrame(a)
        local cb = getModelCFrame(b)
        if not ca and not cb then return false end
        if not ca then return false end
        if not cb then return true end
        local da = (hrp.Position - ca.Position).Magnitude
        local db = (hrp.Position - cb.Position).Magnitude
        return da < db
    end)

    currentTarget = available[1]
    if currentTarget then
        local cf = getModelCFrame(currentTarget)
        if cf and cf.Position then
            local pos = cf.Position
            if pos.Y < -10 then pos = Vector3.new(pos.X, HeightSafe, pos.Z) end
            pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0,3,0)) end)
        end
    end
end

do
    local acc = 0
    local function runAuto(dt)
        acc = acc + dt
        if acc < ScanInterval then return end
        acc = 0

        if not autoEnabled then return end
        if not getChar() then return end

        if currentTarget and (not (currentTarget and currentTarget:IsDescendantOf(Workspace))) then
            currentTarget = nil
            task.wait(TeleportDelay)
            teleportToNext()
            return
        end

        if currentTarget and isTouchingTarget(currentTarget) then
            visitedModels[currentTarget] = true
            task.wait(TeleportDelay)
            teleportToNext()
            return
        end

        if not currentTarget then
            teleportToNext()
            return
        end
    end

    local function startAuto()
        if autoConn then return end
        autoConn = RunService.Heartbeat:Connect(runAuto)
    end

    local function stopAuto()
        if autoConn then
            autoConn:Disconnect()
            autoConn = nil
        end
    end

    Tabs.Event:AddToggle("AutoFarmSukkars", {
        Title = "Auto Farm Sukkars",
        Default = false,
        Callback = function(state)
            autoEnabled = state and true or false
            if autoEnabled then
                startAuto()
            else
                currentTarget = nil
                for k,_ in pairs(visitedModels) do visitedModels[k] = nil end
                stopAuto()
            end
        end,
    })
end


local ActiveNoStun = false
local noStunLoop

Tabs.Player:AddToggle("NoStun", {
    Title = "No Stun",
    Default = false,
    Callback = function(Value)

        ActiveNoStun = Value

        if noStunLoop then
            task.cancel(noStunLoop)
            noStunLoop = nil
        end

        if Value then
            noStunLoop = task.spawn(function()
                while ActiveNoStun do
                    local character = LocalPlayer.Character
                    local hrp = character and character:FindFirstChild("HumanoidRootPart")

                    if hrp then
                        hrp.Anchored = false
                    end

                    task.wait(0.1)
                end
                noStunLoop = nil
            end)
        end
    end
})

local InfStaminaEnabled = false
local staminaLoop
local StaminaModule

pcall(function()
    local path =
        ReplicatedStorage:FindFirstChild("Systems")
        and ReplicatedStorage.Systems:FindFirstChild("Character")
        and ReplicatedStorage.Systems.Character:FindFirstChild("Game")
        and ReplicatedStorage.Systems.Character.Game:FindFirstChild("Sprinting")

    if path then
        StaminaModule = require(path)
    end
end)

local function restoreStamina()
    if not StaminaModule then return end

    local maxStamina = StaminaModule.MaxStamina or 100

    if StaminaModule.Stamina then
        if typeof(StaminaModule.SetStamina) == "function" then
            StaminaModule:SetStamina(maxStamina)
        elseif typeof(StaminaModule.UpdateStamina) == "function" then
            StaminaModule:UpdateStamina(maxStamina)
        else
            StaminaModule.Stamina = maxStamina
        end
    end
end

if StaminaModule then
    Tabs.Player:AddToggle("InfiniteStamina", {
        Title = "Infinite Stamina",
        Default = false,
        Callback = function(Value)

            InfStaminaEnabled = Value

            if StaminaModule.StaminaLossDisabled ~= nil then
                StaminaModule.StaminaLossDisabled = Value
            end

            if Value then
                restoreStamina()

                if not staminaLoop then
                    staminaLoop = task.spawn(function()
                        while InfStaminaEnabled do
                            task.wait(0.01)
                            restoreStamina()
                        end
                        staminaLoop = nil
                    end)
                end

            else
                if staminaLoop then
                    task.cancel(staminaLoop)
                    staminaLoop = nil
                end
            end
        end
    })
end

Tabs.Player:AddToggle("InfiniteZoom", {
    Title = "Infinite Zoom",
    Default = false,
    Callback = function(Value)
        local player = LocalPlayer
        local camera = getCamera()

        if Value then
            player.CameraMaxZoomDistance = math.huge
            player.CameraMinZoomDistance = 0.5
            print("[ZoomCam] Infinite Zoom Enabled ✅")
        else
            player.CameraMaxZoomDistance = 128
            player.CameraMinZoomDistance = 0.5
            print("[ZoomCam] Infinite Zoom Disabled ❌")
        end
    end
})

Tabs.Player:AddSection("↳ Hitbox")

repeat task.wait() until game:IsLoaded()

getgenv().ForsakenReachEnabled = getgenv().ForsakenReachEnabled or false
getgenv().NearestDist = getgenv().NearestDist or 120

Tabs.Player:AddToggle("ForsakenReachToggle", {
    Title = "Hitbox Devil",
    Default = getgenv().ForsakenReachEnabled,
    Save = true
}):OnChanged(function(Value)
    getgenv().ForsakenReachEnabled = Value
end)

Tabs.Player:AddSlider("ForsakenReachSlider", {
    Title = "Distance",
    Default = getgenv().NearestDist,
    Min = 10,
    Max = 300,
    Rounding = 0,
    Save = true,
    Suffix = " studs"
}):OnChanged(function(Value)
    getgenv().NearestDist = Value
end)

getgenv().ForsakenRNG = getgenv().ForsakenRNG or Random.new()

getgenv().ForsakenAttackAnimations = getgenv().ForsakenAttackAnimations or {
    "rbxassetid://131430497821198",
    "rbxassetid://83829782357897",
    'rbxassetid://126830014841198',
    'rbxassetid://126355327951215',
    'rbxassetid://121086746534252',
    'rbxassetid://105458270463374',
    'rbxassetid://18885919947',
    'rbxassetid://18885909645',
    'rbxassetid://87259391926321',
    'rbxassetid://106014898528300',
    'rbxassetid://87259391926321',
    'rbxassetid://86545133269813',
    'rbxassetid://89448354637442',
    'rbxassetid://90499469533503',
    'rbxassetid://116618003477002',
    'rbxassetid://106086955212611',
    'rbxassetid://107640065977686',
    'rbxassetid://77124578197357',
    'rbxassetid://101771617803133',
    'rbxassetid://134958187822107',
    'rbxassetid://111313169447787',
    'rbxassetid://71685573690338',
    'rbxassetid://129843313690921',
    'rbxassetid://97623143664485',
    'rbxassetid://129843313690921',
    'rbxassetid://136007065400978',
    'rbxassetid://136007065400978',
    'rbxassetid://86096387000557',
    'rbxassetid://108807732150251',
    'rbxassetid://138040001965654',
    'rbxassetid://73502073176819',
    'rbxassetid://129843313690921',
    'rbxassetid://97623143664485',
    'rbxassetid://129843313690921',
    'rbxassetid://97623143664485',
    'rbxassetid://86709774283672',
    'rbxassetid://106014898528300',
    'rbxassetid://87259391926321',
    'rbxassetid://140703210927645',
    'rbxassetid://96173857867228',
    'rbxassetid://121255898612475',
    'rbxassetid://98031287364865',
    'rbxassetid://119462383658044',
    'rbxassetid://77448521277146',
    'rbxassetid://77448521277146',
    'rbxassetid://103741352379819',
    'rbxassetid://119462383658044',
    'rbxassetid://131696603025265',
    'rbxassetid://122503338277352',
    'rbxassetid://97648548303678',
    'rbxassetid://94162446513587',
    'rbxassetid://93069721274110',
    'rbxassetid://97433060861952',
    'rbxassetid://100592913030351',
    'rbxassetid://121293883585738',
    'rbxassetid://100592913030351',
    'rbxassetid://121293883585738',
    'rbxassetid://100592913030351',
    'rbxassetid://121293883585738',
    'rbxassetid://70447634862911',
    'rbxassetid://92173139187970',
    'rbxassetid://106847695270773',
    'rbxassetid://125403313786645',
    'rbxassetid://81639435858902',
    'rbxassetid://137314737492715',
    'rbxassetid://120112897026015',
    'rbxassetid://82113744478546',
    'rbxassetid://118298475669935',
    'rbxassetid://82113744478546',
    'rbxassetid://118298475669935',
    'rbxassetid://126681776859538',
    'rbxassetid://129976080405072',
    'rbxassetid://109667959938617',
    'rbxassetid://74707328554358',
    'rbxassetid://133336594357903',
    'rbxassetid://86204001129974',
    'rbxassetid://82113744478546',
    'rbxassetid://118298475669935',
    'rbxassetid://124243639579224',
    'rbxassetid://70371667919898',
    'rbxassetid://131543461321709',
    'rbxassetid://136323728355613',
    'rbxassetid://109230267448394',
    'rbxassetid://139835501033932',
    'rbxassetid://106538427162796',
    'rbxassetid://109667959938617',
    'rbxassetid://126681776859538',
    'rbxassetid://129976080405072',
    'rbxassetid://110400453990786',
    'rbxassetid://83685305553364',
    'rbxassetid://126171487400618',
    'rbxassetid://122709416391891',
    'rbxassetid://87989533095285',
    'rbxassetid://119326397274934',
    'rbxassetid://140365014326125',
    'rbxassetid://139309647473555',
    'rbxassetid://133363345661032',
    'rbxassetid://128414736976503',
    'rbxassetid://121808371053483',
    'rbxassetid://77375846492436',
    'rbxassetid://92445608014276',
    'rbxassetid://100358581940485',
    'rbxassetid://91758760621955',
    'rbxassetid://94634594529334',
    'rbxassetid://101101433684051',
    'rbxassetid://90620531468240',
    'rbxassetid://94958041603347',
    'rbxassetid://131642454238375',
    'rbxassetid://110702884830060',
    'rbxassetid://76312020299624',
    'rbxassetid://126654961540956',
    'rbxassetid://139613699193400',
    'rbxassetid://91509234639766',
    'rbxassetid://105458270463374',
    'rbxassetid://109777684604906'
}

local function getSafePing()
    local ok, ping = pcall(function()
        return LocalPlayer:GetNetworkPing()
    end)
    if ok and typeof(ping) == "number" and ping > 0 then
        return ping
    end
    return 0.05
end

local function scanFolder(folder, BestDist)
    local FinalTarget = nil
    if not folder or not HRP then return nil, BestDist end

    for _, v in ipairs(folder:GetChildren()) do
        if v ~= Character then
            local hrp2 = v:FindFirstChild("HumanoidRootPart")
            local hum2 = v:FindFirstChild("Humanoid")
            if hrp2 and hum2 then
                local Dist = (hrp2.Position - HRP.Position).Magnitude
                if Dist < BestDist then
                    BestDist = Dist
                    FinalTarget = v
                end
            end
        end
    end

    return FinalTarget, BestDist
end

local function ForsakenReachLogic()
    if not getgenv().ForsakenReachEnabled then return end
    if not Humanoid or not HRP then return end

    local Playing = false
    for _, v in ipairs(Humanoid:GetPlayingAnimationTracks()) do
        if v and v.Animation and v.Animation.AnimationId then
            if table.find(getgenv().ForsakenAttackAnimations, v.Animation.AnimationId)
            and v.Length > 0
            and (v.TimePosition / v.Length < 0.75) then
                Playing = true
                break
            end
        end
    end

    if not Playing then return end

    local PlayerRole = nil
    local killersFolder = getKillersFolder()
    local survivorsFolder = getSurvivorsFolder()

    if killersFolder and killersFolder:FindFirstChild(Character.Name) then
        PlayerRole = "Killer"
    elseif survivorsFolder and survivorsFolder:FindFirstChild(Character.Name) then
        PlayerRole = "Survivor"
    end

    local OppositeFolder = nil
    if PlayerRole == "Killer" then
        OppositeFolder = survivorsFolder
    elseif PlayerRole == "Survivor" then
        OppositeFolder = killersFolder
    end

    local FinalTarget = nil
    local BestDist = getgenv().NearestDist

    FinalTarget, BestDist = scanFolder(OppositeFolder, BestDist)

    if not FinalTarget then
        local playersFolder = Workspace:FindFirstChild("Players")
        if playersFolder then
            FinalTarget, BestDist = scanFolder(playersFolder, BestDist)
        end

        if not FinalTarget then
            local mapFolder = Workspace:FindFirstChild("Map")
            if mapFolder then
                local ok, npcsFolder = pcall(function()
                    return mapFolder:FindFirstChild("NPCs", true)
                end)
                if ok and npcsFolder then
                    FinalTarget, BestDist = scanFolder(npcsFolder, BestDist)
                end
            end
        end
    end

    if not FinalTarget then return end
    if not FinalTarget:FindFirstChild("HumanoidRootPart") then return end

    local OldVelocity = HRP.Velocity
    local Ping = getSafePing()

    local rng = getgenv().ForsakenRNG
    local offset = Vector3.new(
        rng:NextNumber(-1.5, 1.5),
        0,
        rng:NextNumber(-1.5, 1.5)
    )

    local NeededVelocity =
        (FinalTarget.HumanoidRootPart.Position
        + offset
        + (FinalTarget.HumanoidRootPart.Velocity * (Ping * 1.25))
        - HRP.Position) / (Ping * 2)

    HRP.Velocity = NeededVelocity
    RunService.RenderStepped:Wait()
    HRP.Velocity = OldVelocity
end

task.spawn(function()
    while true do
        task.wait(0)
        pcall(ForsakenReachLogic)
    end
end)

local WalkSpeed = { Value = 16, Active = false, Loop = nil }

Tabs.Player:AddSection("↳ Walk Speed")

Tabs.Player:AddSlider("PlayerSpeedSlider", {
    Title = "Set Speed",
    Min = 0,
    Max = 40,
    Default = WalkSpeed.Value,
    Rounding = 1,
}):OnChanged(function(value)
    WalkSpeed.Value = value
    if WalkSpeed.Active then
        if getHumanoid() then
            getHumanoid().WalkSpeed = WalkSpeed.Value
            getHumanoid():SetAttribute("BaseSpeed", WalkSpeed.Value)
        end
    end
end)

Tabs.Player:AddToggle("PlayerSpeedToggle", {
    Title = "Walk Speed",
    Default = false,
}):OnChanged(function(enabled)
    WalkSpeed.Active = enabled
    if enabled then
        local hum = getHumanoid()
        if hum then
            hum.WalkSpeed = WalkSpeed.Value
            hum:SetAttribute("BaseSpeed", WalkSpeed.Value)
        end
        WalkSpeed.Loop = task.spawn(function()
            while WalkSpeed.Active do
                local hum = getHumanoid()
                if hum then
                    hum.WalkSpeed = WalkSpeed.Value
                    hum:SetAttribute("BaseSpeed", WalkSpeed.Value)
                end
                task.wait(0.5)
            end
        end)
    else
        WalkSpeed.Loop = nil
        local hum = getHumanoid()
        if hum then
            hum.WalkSpeed = 16
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.1)
    if WalkSpeed.Active then
        local hum = getHumanoid()
        if hum then
            hum.WalkSpeed = WalkSpeed.Value
            hum:SetAttribute("BaseSpeed", WalkSpeed.Value)
        end
    end
end)

local TeleportSpeed = { Value = 50, Max = 300, Active = false }

Tabs.Player:AddSection("↳ Teleport Speed")

Tabs.Player:AddSlider("TeleportSpeedSlider", {
    Title = "Set Speed",
    Min = 1,
    Max = TeleportSpeed.Max,
    Default = TeleportSpeed.Value,
    Rounding = 1,
}):OnChanged(function(value)
    TeleportSpeed.Value = value
end)

Tabs.Player:AddToggle("TeleportSpeedToggle", {
    Title = "Teleport Speed",
    Default = false,
}):OnChanged(function(enabled)
    TeleportSpeed.Active = enabled
end)

RunService.Heartbeat:Connect(function(dt)
    if TeleportSpeed.Active then
        local hrp = getHRP()
        local hum = getHumanoid()
        if hrp and hum and hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + hum.MoveDirection.Unit * (TeleportSpeed.Value * dt)
        end
    end
end)

local allowedModelsClone = {
    ["1x1x1x1Zombie"] = true,
    ["PizzaDeliveryRig"] = true,
    ["Mafia1"] = true,
    ["Mafia2"] = true,
    ["Mafia3"] = true,
    ["Mafia4"] = true,
}

ESP:RegisterType("Clone", Color3.fromRGB(0, 255, 0), function(obj)
    return obj:IsA("Model") and allowedModelsClone[obj.Name]
end, false)

Tabs.Visual:AddToggle("ESP_Clone", {
    Title = "ESP Clone",
    Default = false,
    Callback = function(state)
        ESP:SetEnabled("Clone", state)
    end
})

Tabs.Visual:AddSection("↳ Player")

ESP:RegisterType("Player", Color3.fromRGB(0, 255, 255), function(obj)
    local plr = Players:GetPlayerFromCharacter(obj)
    return plr and plr ~= LocalPlayer
end, false)

Tabs.Visual:AddToggle("ESP_Player", {
    Title = "ESP Player",
    Default = false,
    Callback = function(v)
        ESP:SetEnabled("Player", v)
    end
})

ESP:RegisterType("Survivor", Color3.fromRGB(255, 255, 255), function(obj)
    local survivorsFolder = getSurvivorsFolder()
    return obj:IsA("Model") and survivorsFolder and obj.Parent == survivorsFolder
        and obj:FindFirstChildOfClass("Humanoid")
end, true)

Tabs.Visual:AddToggle("ESP_Survivor", {
    Title = "ESP Survivors",
    Default = false,
    Callback = function(v)
        ESP:SetEnabled("Survivor", v)
    end
})

ESP:RegisterType("Killer", Color3.fromRGB(255, 0, 0), function(obj)
    local killersFolder = getKillersFolder()
    return obj:IsA("Model") and killersFolder and obj.Parent == killersFolder
        and obj:FindFirstChildOfClass("Humanoid")
end, true)

Tabs.Visual:AddToggle("ESP_Killers", {
    Title = "ESP Killers",
    Default = false,
    Callback = function(v)
        ESP:SetEnabled("Killer", v)
    end
})

Tabs.Visual:AddSection("↳ Other")

ESP:RegisterType("Generator", Color3.fromRGB(255,255,255), function(obj)
    if not (obj and obj:IsA("Model") and obj.Name == "Generator") then return false end

    local progress = obj:FindFirstChild("Progress", true)
    if not progress or not progress:IsA("NumberValue") then return false end

    if not progress:GetAttribute("ESP_Watch") then
        progress:SetAttribute("ESP_Watch", true)
        progress:GetPropertyChangedSignal("Value"):Connect(function()
            if progress.Value >= 100 then
                ESP:Remove(obj)
            else
                if not ESP.Objects[obj] then
                    ESP:_ScheduleCreate(obj, "Generator")
                end
            end
        end)
    end

    return progress.Value < 100
end, false)

Tabs.Visual:AddToggle("ESP_Generator", {
    Title = "ESP Generator",
    Default = false,
    Callback = function(v)
        ESP:SetEnabled("Generator", v)
    end
})

ESP:RegisterType("Item", Color3.fromRGB(255,215,0), function(obj)
    return obj:IsA("Tool") and obj.Parent and obj:IsDescendantOf(Workspace:FindFirstChild("Map"))
end, false)

Tabs.Visual:AddToggle("ESP_Items", {
    Title = "ESP Items",
    Default = false,
    Callback = function(v)
        ESP:SetEnabled("Item", v)
    end
})

ESP:RegisterType("Dispenser", Color3.fromRGB(0, 162, 255), function(obj)
    return obj:IsA("Model") and obj.Name:lower():find("dispenser")
end, false)

ESP:RegisterType("Sentry", Color3.fromRGB(128, 128, 128), function(obj)
    return obj:IsA("Model") and obj.Name:lower():find("sentry")
end, false)

Tabs.Visual:AddSection("↳ Buildman")

Tabs.Visual:AddToggle("ESP_Dispenser", {
    Title = "ESP Dispenser",
    Default = false,
    Callback = function(v)
        ESP:SetEnabled("Dispenser", v)
    end
})

Tabs.Visual:AddToggle("ESP_Sentry", {
    Title = "ESP Sentry",
    Default = false,
    Callback = function(v)
        ESP:SetEnabled("Sentry", v)
    end
})

ESP:RegisterType("Tripwire", Color3.fromRGB(255, 85, 0), function(obj)
    return obj:IsA("Model") and obj.Name:find("TaphTripwire")
end, false)

ESP:RegisterType("Subspace", Color3.fromRGB(160, 32, 240), function(obj)
    return obj:IsA("Model") and obj.Name == "SubspaceTripmine"
end, false)

Tabs.Visual:AddSection("↳ Tapt/Trap")

Tabs.Visual:AddToggle("ESP_Tripwire", {
    Title = "ESP Tripwire",
    Default = false,
    Callback = function(v)
        ESP:SetEnabled("Tripwire", v)
    end
})

Tabs.Visual:AddToggle("ESP_Subspace", {
    Title = "ESP Subspace",
    Default = false,
    Callback = function(v)
        ESP:SetEnabled("Subspace", v)
    end
})

local fullBrightEnabled = false
local fullBrightConn = nil

local function applyFullBright()
    if not fullBrightEnabled then return end
    pcall(function()
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.Brightness = 4
        Lighting.GlobalShadows = false
    end)
end

local function enableFullBright()
    if fullBrightConn then fullBrightConn:Disconnect() end
    applyFullBright()

    fullBrightConn = Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
        applyFullBright()
    end)
end

local function disableFullBright()
    if fullBrightConn then
        fullBrightConn:Disconnect()
        fullBrightConn = nil
    end

    pcall(function()
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
    end)
end

local FbToggle = Tabs.Misc:AddToggle("FbToggle", {
    Title = "Full Bright",
    Default = false
})

FbToggle:OnChanged(function(Value)
    fullBrightEnabled = Value
    if Value then
        enableFullBright()
    else
        disableFullBright()
    end
end)

local fogEnabled = false
local fogConn = nil

local function removeFog()
    pcall(function()
        Lighting.FogStart = 0
        Lighting.FogEnd = 999999

        local a = Lighting:FindFirstChild("Atmosphere")
        if a then
            a.Density = 0
            a.Offset = 0
            a.Haze = 0
            a.Color = Color3.new(1, 1, 1)
        end
    end)
end

local function restoreFog()
    pcall(function()
        Lighting.FogStart = 200
        Lighting.FogEnd = 1000

        local a = Lighting:FindFirstChild("Atmosphere")
        if a then
            a.Density = 0.3
            a.Offset = 0
            a.Haze = 0.5
            a.Color = Color3.fromRGB(200, 200, 200)
        end
    end)
end

local FogToggle = Tabs.Misc:AddToggle("FogToggle", {
    Title = "Remove Fog",
    Default = false
})

FogToggle:OnChanged(function(Value)
    fogEnabled = Value

    if fogEnabled then
        removeFog()

        if fogConn then fogConn:Disconnect() end

        fogConn = RunService.Heartbeat:Connect(function()
            removeFog()
        end)

    else
        if fogConn then
            fogConn:Disconnect()
            fogConn = nil
        end
        restoreFog()
    end
end)

Tabs.Misc:AddSection("↳ Game Play")

local antiAFKCons = {}

if getconnections then
    Tabs.Misc:AddToggle("AntiAFK", {
        Title = "Anti-AFK",
        Default = true,
        Callback = function(Value)
            local idleCons = getconnections(LocalPlayer.Idled)

            if Value then
                for _, c in ipairs(idleCons) do
                    antiAFKCons[c] = true
                    c:Disable()
                end
                print("[AntiAFK] Đã bật, bạn sẽ không bị kick AFK.")
            else
                for c,_ in pairs(antiAFKCons) do
                    if c and c.Enable then
                        pcall(function()
                            c:Enable()
                        end)
                    end
                end
                antiAFKCons = {}
                print("[AntiAFK] Đã tắt, Roblox sẽ xử lý AFK bình thường.")
            end
        end
    })
else
    warn("[Anti-AFK] Executor không hỗ trợ getconnections, toggle bị vô hiệu.")
end

local ASConfigs = {
    Slowness = {Values = {"SlowedStatus"}, Enabled = false},
    Skills = {
        Values = {
            "StunningKiller","EatFriedChicken","GuestBlocking","PunchAbility","SubspaceTripmine",
            "TaphTripwire","PlasmaBeam","SpawnProtection","c00lgui","ShootingGun",
            "TwoTimeStab","TwoTimeCrouching","DrinkingCola","DrinkingSlateskin",
            "SlateskinStatus","EatingGhostburger"
        },
        Enabled = false
    },
    Items = {Values = {"BloxyColaItem","Medkit"}, Enabled = false},
    Emotes = {Values = {"Emoting"}, Enabled = false},
    Builderman = {Values = {"DispenserConstruction","SentryConstruction"}, Enabled = false}
}

local DoAutoPopup = false

local function hideSlownessUI()
    local gui = getPlayerGui()
    if not gui then return end

    local mainUI = gui:FindFirstChild("MainUI")
    if not mainUI then return end

    local status = mainUI:FindFirstChild("StatusContainer")
    if not status then return end

    local slowUI = status:FindFirstChild("Slowness")
    if slowUI then
        slowUI.Visible = false
    end
end

local function applyAntiSlow()
    local survivors = getSurvivorsFolder()
    local char = getChar()

    if not survivors or not char then
        return
    end

    local model = survivors:FindFirstChild(char.Name)
    if not model then return end

    local speedMult = model:FindFirstChild("SpeedMultipliers")
    if not speedMult then return end

    for _, cfg in pairs(ASConfigs) do
        if cfg.Enabled then
            for _, valName in ipairs(cfg.Values) do
                local val = speedMult:FindFirstChild(valName)
                if val and val:IsA("NumberValue") and val.Value ~= 1 then
                    val.Value = 1
                end
            end
        end
    end

    hideSlownessUI()
end

local function applyAutoPopup()
    local gui = getPlayerGui()
    if gui then
        local tempUI = gui:FindFirstChild("TemporaryUI")
        if tempUI then
            local popup = tempUI:FindFirstChild("1x1x1x1Popup")
            if popup then popup:Destroy() end
        end
    end

    local survivors = getSurvivorsFolder()
    local char = getChar()
    if not survivors or not char then return end

    local model = survivors:FindFirstChild(char.Name)
    if not model then return end

    local speed = model:FindFirstChild("SpeedMultipliers")
    if speed then
        local v = speed:FindFirstChild("SlowedStatus")
        if v then v.Value = 1 end
    end

    local fov = model:FindFirstChild("FOVMultipliers")
    if fov then
        local v = fov:FindFirstChild("SlowedStatus")
        if v then v.Value = 1 end
    end
end

RunService.Heartbeat:Connect(function()
    applyAntiSlow()

    if DoAutoPopup then
        applyAutoPopup()
    end
end)

Tabs.Misc:AddToggle("AntiSlow_All", {
    Title = "Anti-Slow",
    Default = false,
    Callback = function(v)
        for _, cfg in pairs(ASConfigs) do
            cfg.Enabled = v
        end
    end
})

Tabs.Misc:AddToggle("AutoClosePopupV2", {
    Title = "Delete 1x Popups",
    Default = true,
    Callback = function(v)
        DoAutoPopup = v
    end
})

Tabs.Misc:AddSection("↳ Fix Lag")

local function ServerHop()
    local placeId = game.PlaceId
    local jobId = game.JobId
    print("[ServerHop] Đang rời server hiện tại...")

    local success, err = pcall(function()
        TeleportService:Teleport(placeId, LocalPlayer)
    end)

    if success then
        if Fluent and Fluent.Notify then
            Fluent:Notify({
                Title = "Rejoin Starting",
                Content = "Bắt Đầu Vào Máy Chủ Đã Fix Lag",
                Duration = 3
            })
        else
            print("[ServerHop] Đang chuyển server...")
        end
    else
        warn("[ServerHop] Lỗi khi Teleport:", err)
        if Fluent and Fluent.Notify then
            Fluent:Notify({
                Title = "Lỗi Teleport",
                Content = tostring(err),
                Duration = 4
            })
        end
    end
end

Tabs.Misc:AddButton({
    Title = "Rejoin To Fix Lag",
    Callback = function()
        if Fluent and Fluent.Notify then
            Fluent:Notify({
                Title = "Rejoin Settings",
                Content = "Đang Giảm Lag Cho Các Máy Chủ...",
                Duration = 2
            })
        end

        task.wait(0.3)
        ServerHop()
    end
})

getgenv().chatWindow = game:GetService("TextChatService"):WaitForChild("ChatWindowConfiguration")
getgenv().chatEnabled = false
getgenv().chatConnection = nil

Tabs.Misc:AddToggle("ShowChat", {
    Title = "Show Chat",
    Default = false,
    Callback = function(Value)
        getgenv().chatEnabled = Value

        if Value then
            if not getgenv().chatConnection then
                getgenv().chatConnection = RunService.Heartbeat:Connect(function()
                    if getgenv().chatWindow then
                        getgenv().chatWindow.Enabled = true
                    end
                end)
            end
        else
            if getgenv().chatConnection then
                getgenv().chatConnection:Disconnect()
                getgenv().chatConnection = nil
            end
            if getgenv().chatWindow then
                getgenv().chatWindow.Enabled = false
            end
        end
    end
})

local ActiveRemoveAll = false

local effectNames = {
    "BlurEffect", "ColorCorrectionEffect", "BloomEffect", "SunRaysEffect", 
    "DepthOfFieldEffect", "ScreenFlash", "HitEffect", "DamageOverlay", 
    "BloodEffect", "Vignette", "BlackScreen", "WhiteScreen", "ShockEffect",
    "Darkness", "JumpScare", "LowHealthOverlay", "Flashbang", "FadeEffect"
}

local effectClasses = {
    "BlurEffect",
    "BloomEffect",
    "SunRaysEffect",
    "DepthOfFieldEffect",
    "ColorCorrectionEffect"
}

local function safeGetPlayerGui()
    local gui = getPlayerGui()
    if gui and gui.Parent ~= nil then
        return gui
    end
    return nil
end

local function removeAll()
    for _, obj in pairs(Lighting:GetDescendants()) do
        if table.find(effectNames, obj.Name) or table.find(effectClasses, obj.ClassName) then
            obj:Destroy()
        end
    end

    local PlayerGui = safeGetPlayerGui()
    if not PlayerGui then return end

    for _, obj in pairs(PlayerGui:GetDescendants()) do
        
        if table.find(effectNames, obj.Name) then
            obj:Destroy()

        elseif (obj:IsA("ScreenGui") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui")) then
            local lower = obj.Name:lower()
            
            if obj:FindFirstChildWhichIsA("ImageLabel") 
                or obj:FindFirstChildWhichIsA("Frame") 
            then
                if table.find(effectNames, obj.Name)
                    or lower:find("overlay")
                    or lower:find("effect") 
                then
                    obj:Destroy()
                end
            end
        end
    end
end

Tabs.Misc:AddToggle("RemoveAllBadStuff", {
    Title = "Remove Effects",
    Default = true,
    Callback = function(Value)
        ActiveRemoveAll = Value

        if Value then
            task.spawn(function()
                while ActiveRemoveAll do
                    pcall(removeAll)
                    task.wait(0.5)
                end
            end)
        end
    end
})

local AexecToggle = Tabs.Settings:AddToggle("AexecToggle", {Title = "Auto Execute", Default = false })
AexecToggle:OnChanged(function(Value)
    if Value then
        task.spawn(function()
            pcall(function()
                if queue_on_teleport then
                    local TzuanhubScript1 = [[
task.wait(3)
loadstring(game:HttpGet("https://hst.sh/raw/uhuhatusop"))()
]]
                    queue_on_teleport(TzuanhubScript1)
                end
            end)
        end)
        Fluent:Notify({
            Title = "Tzuan Hub",
            Content = "Auto execute is enabled!",
            Duration = 5
        })
    else
        Fluent:Notify({
            Title = "Tzuan Hub",
            Content = "Auto execute is disabled!",
            Duration = 5
        })
    end
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()

SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("Tzuan Hub")
SaveManager:SetFolder("Tzuan Hub/Forsaken")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({ Title = "Tzuan Hub", Content = "Forsaken script loaded successfully!", Duration = 5 })
SaveManager:LoadAutoloadConfig()