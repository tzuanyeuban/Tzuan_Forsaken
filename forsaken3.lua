local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/XUANVNPRO/Mmb/refs/heads/main/gui2.0.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Tzuan Hub | Forsaken [Beta]",
    SubTitle = "Version 2.1.0",
    Search = true,
    Icon = "rbxassetid://84950100176700",
    TabWidth = 160,
    Size = UDim2.fromOffset(480, 360),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightAlt,

    UserInfo = false,
    UserInfoTop = false,
    UserInfoTitle = game:GetService("Players").LocalPlayer.DisplayName,
    UserInfoSubtitle = "Sub & Like YTB Tzuan",
    UserInfoSubtitleColor = Color3.fromRGB(71, 123, 255)
})

local Tabs = {
    Dev = Window:AddTab({ Title = "About", Icon = "info" }),
    Farm = Window:AddTab({ Title = "Farm", Icon = "box" }),
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Event = Window:AddTab({ Title = "Event", Icon = "bell" }),
    Custom = Window:AddTab({ Title = "Custom", Icon = "brush" }),
    Player = Window:AddTab({ Title = "Player", Icon = "user" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "eye" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "menu" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

-- Phần Logic Chính

local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local ESPManager = {
    ActiveTypes = {},
    Objects = {},
    Filters = {},
    Colors = {},
    Watchers = {},
    ShowHP = {},
    _pendingCreate = {},
}

local function getPrimaryPart(model)
    if not model then return nil end
    local p = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    return p
end

function ESPManager:RegisterType(name, color, filterFn, showHP)
    self.Filters[name] = filterFn
    self.Colors[name] = color
    self.ShowHP[name] = showHP or false
    self.ActiveTypes[name] = false
end

local function disconnectConns(tbl)
    if not tbl then return end
    for _, c in pairs(tbl) do
        if c and typeof(c.Disconnect) == "function" then
            pcall(function() c:Disconnect() end)
        end
    end
end

function ESPManager:_CreateImmediate(model, typeName)
    if not model or not model.Parent then return end
    if ESPManager.Objects[model] then
        local existing = ESPManager.Objects[model]
        if existing.gui and existing.gui.Parent and existing.hl and existing.hl.Parent then
            return
        else
            ESPManager:Remove(model)
        end
    end

    local color = ESPManager.Colors[typeName]
    local part = getPrimaryPart(model)
    if not part then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_" .. typeName
    billboard.Size = UDim2.new(0, 180, 0, 35)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.MaxDistance = 600
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
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

    table.insert(conns, model.AncestryChanged:Connect(function(_, parent)
        if not model:IsDescendantOf(workspace) then
            if ESPManager.Objects[model] and ESPManager.Objects[model].type == typeName then
                ESPManager:Remove(model)
            end
            return
        end
        if ESPManager.ActiveTypes[typeName] and ESPManager.Filters[typeName](model) then
            ESPManager:_ScheduleCreate(model, typeName)
        end
    end))

    local function watchHumanoid(hum)
        if not hum then return end
        table.insert(conns, hum.Died:Connect(function()
            if ESPManager.Objects[model] and ESPManager.Objects[model].type == typeName then
                ESPManager:Remove(model)
            end
        end))
    end

    watchHumanoid(model:FindFirstChildOfClass("Humanoid"))

    table.insert(conns, model.ChildAdded:Connect(function(child)
        if child and child:IsA("Humanoid") then
            watchHumanoid(child)
            if ESPManager.ActiveTypes[typeName] and ESPManager.Filters[typeName](model) then
                ESPManager:_ScheduleCreate(model, typeName)
            end
        end
        if (child:IsA("BasePart") or child:IsA("Model")) and ESPManager.ActiveTypes[typeName] and ESPManager.Filters[typeName](model) then
            ESPManager:_ScheduleCreate(model, typeName)
        end
    end))

    ESPManager.Objects[model] = {
        type = typeName,
        gui = billboard,
        label = label,
        hl = hl,
        conns = conns,
    }
end

function ESPManager:_ScheduleCreate(model, typeName)
    if not model or not typeName then return end
    if not ESPManager.ActiveTypes[typeName] then return end
    if ESPManager._pendingCreate[model] then return end
    ESPManager._pendingCreate[model] = true

    task.delay(0.5, function()
        pcall(function()
            ESPManager._pendingCreate[model] = nil
            if not model or not model.Parent then return end
            local filterFn = ESPManager.Filters[typeName]
            if not filterFn or not filterFn(model) then return end
            ESPManager:_CreateImmediate(model, typeName)
        end)
    end)
end

function ESPManager:Remove(model)
    local data = self.Objects[model]
    if not data then return end

    if data.conns then
        disconnectConns(data.conns)
    end

    pcall(function() if data.gui then data.gui:Destroy() end end)
    pcall(function() if data.hl then data.hl:Destroy() end end)
    self.Objects[model] = nil
    self._pendingCreate[model] = nil
end

function ESPManager:StartWatcher(typeName)
    local filterFn = self.Filters[typeName]
    if not filterFn then return end
    if self.Watchers[typeName] then return end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if filterFn(obj) then
            self:_ScheduleCreate(obj, typeName)
        end
    end

    local addConn = workspace.DescendantAdded:Connect(function(obj)
        if self.ActiveTypes[typeName] and filterFn(obj) then
            self:_ScheduleCreate(obj, typeName)
        end
    end)

    local removeConn = workspace.DescendantRemoving:Connect(function(obj)
        if self.Objects[obj] and self.Objects[obj].type == typeName then
            self:Remove(obj)
        end
        self._pendingCreate[obj] = nil
    end)

    self.Watchers[typeName] = {add = addConn, rem = removeConn}
end

function ESPManager:StopWatcher(typeName)
    local w = self.Watchers[typeName]
    if w then
        if w.add then w.add:Disconnect() end
        if w.rem then w.rem:Disconnect() end
    end
    self.Watchers[typeName] = nil
end

RunService.Heartbeat:Connect(function()
    for model, data in pairs(ESPManager.Objects) do
        if not model or not model.Parent then
            ESPManager:Remove(model)
        else
            local part = getPrimaryPart(model)
            if not part then
                ESPManager:Remove(model)
            else
                local needRecreate = false
                if (not data.gui) or (not data.hl) or (not data.label) then
                    needRecreate = true
                else
                    if not data.gui.Parent then
                        needRecreate = true
                    end
                end
                if needRecreate then
                    local typeName = data.type
                    ESPManager:Remove(model)
                    ESPManager:_ScheduleCreate(model, typeName)
                else
                    local dist = (Camera.CFrame.Position - part.Position).Magnitude
                    local txt = model.Name
                    local showHP = ESPManager.ShowHP[data.type]
                    if showHP then
                        local hum = model:FindFirstChildOfClass("Humanoid")
                        if hum then
                            txt = string.format("%s | HP:%d | [%.0fm]", txt, math.floor(hum.Health), dist)
                        else
                            txt = string.format("%s [%.0fm]", txt, dist)
                        end
                    else
                        txt = string.format("%s [%.0fm]", txt, dist)
                    end
                    if data.label then
                        pcall(function() data.label.Text = txt end)
                    end
                end
            end
        end
    end
end)

function ESPManager:SetEnabled(typeName, state)
    self.ActiveTypes[typeName] = state

    if state then
        self:StartWatcher(typeName)
        local filterFn = self.Filters[typeName]
        if filterFn then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if filterFn(obj) then
                    self:_ScheduleCreate(obj, typeName)
                end
            end
        end
    else
        self:StopWatcher(typeName)
        for model, data in pairs(self.Objects) do
            if data.type == typeName then
                self:Remove(model)
            end
        end
    end
end

_G.ESPManager = ESPManager




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


-- Tab.Dev

local Options = Fluent.Options


    Tabs.Dev:AddParagraph({
        Title = "Hỗ trợ",
        Content = "Script có lỗi vui lòng vào discord để báo cáo, xin đừng giữ im lặng.\nThe script has an error. Please join the Discord to report it. Don’t stay silent."
    })

    Tabs.Dev:AddSection("↳ Links")

    Tabs.Dev:AddButton({
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



    Tabs.Dev:AddButton({
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

-- Tabs.Farm

do
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = Players.LocalPlayer

    local Active = false
    local loopRunning = false
    local CurrentTarget = nil
    local lastAttack = 0

    local KillersList = {
        ["Slasher"] = true,
        ["1x1x1x1"] = true,
        ["c00lkidd"] = true,
        ["Noli"] = true,
        ["JohnDoe"] = true,
        ["Guest 666"] = true,
        ["Sixer"] = true,
    }

    local PriorityList = {
        ["0206octavio"] = true
    }

    local SkillList = {
        "Slash", "Stab", "Punch",
        "VoidRush", "Nova",
        "CorruptEnergy", "Behead", "GashingWound",
        "MassInfection", "CorruptNature", "WalkspeedOverride", "PizzaDelivery",
        "UnstableEye", "Entanglement",
        "DigitalFootprint", "404Error",
        "RagingPace", "CarvingSlash", "DemonicPursuit",
        "InfernalCry", "BloodRush"
    }

    local SkillRemotes = {}

    local function findSkillRemoteFromButton(button)
        for _, conn in ipairs(getconnections(button.MouseButton1Click)) do
            local f = conn.Function
            if f and islclosure(f) then
                for _, v in pairs(getupvalues(f)) do
                    if typeof(v) == "Instance" and v:IsA("RemoteEvent") then
                        return v
                    end
                end
            end
        end
        return nil
    end

    local function initSkillButtons()
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        if not gui then return end
        local mainUI = gui:FindFirstChild("MainUI")
        local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
        if not container then return end

        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ImageButton") then
                local remote = findSkillRemoteFromButton(child)
                if remote then
                    SkillRemotes[child.Name] = remote
                    warn("[Skill] Found RemoteEvent for:", child.Name, remote:GetFullName())
                end
            end
        end
    end

    initSkillButtons()
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        initSkillButtons()
    end)

    local function GetPriorityTarget()
        local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
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

        local localChar = LocalPlayer.Character
        if not (localChar and localChar:FindFirstChild("HumanoidRootPart")) then return nil end
        local survivorsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
        if not survivorsFolder then return nil end

        local closest, minDist = nil, math.huge
        for _, survivor in ipairs(survivorsFolder:GetChildren()) do
            local humanoid = survivor:FindFirstChildOfClass("Humanoid")
            if survivor:IsA("Model") and survivor:FindFirstChild("HumanoidRootPart") and humanoid and humanoid.Health > 0 then
                local dist = (localChar.HumanoidRootPart.Position - survivor.HumanoidRootPart.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = survivor
                end
            end
        end
        return closest
    end

    local function KillTarget(target)
        pcall(function()
            if not target then return end
            local localChar = LocalPlayer.Character
            if not (localChar and localChar:FindFirstChild("HumanoidRootPart")) then return end

            local root = localChar.HumanoidRootPart
            local targetRoot = target:FindFirstChild("HumanoidRootPart")
            if not targetRoot then return end

            if tick() - lastAttack >= 0.05 then
                lastAttack = tick()

                for _, skillName in ipairs(SkillList) do
                    local offset = targetRoot.CFrame.LookVector * -2
                    root.CFrame = targetRoot.CFrame + offset

                    local remote = SkillRemotes[skillName]
                    if remote then
                        remote:FireServer(true)
                        task.wait(0.005)
                        remote:FireServer(false)
                    else
                        local gui = LocalPlayer:FindFirstChild("PlayerGui")
                        local mainUI = gui and gui:FindFirstChild("MainUI")
                        local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
                        if container then
                            local button = container:FindFirstChild(skillName)
                            if button and button:IsA("ImageButton") then
                                for _, conn in ipairs(getconnections(button.MouseButton1Click)) do
                                    if conn.Function then
                                        pcall(conn.Function)
                                    end
                                end
                                pcall(function() button:Activate() end)
                            end
                        end

                        local net = ReplicatedStorage:FindFirstChild("Modules")
                                    and ReplicatedStorage.Modules:FindFirstChild("Network")
                                    and ReplicatedStorage.Modules.Network:FindFirstChild("RemoteEvent")
                        if net and typeof(net.FireServer) == "function" then
                            net:FireServer("UseActorAbility", skillName)
                        end
                    end

                    task.wait(0.01)
                end
            end
        end)
    end

    local function StartLoop()
        if loopRunning then return end
        loopRunning = true
        task.spawn(function()
            while Active do
                local char = LocalPlayer.Character
                if not (char and KillersList[char.Name]) then
                    CurrentTarget = nil
                    task.wait(0.5)
                    continue
                end

                if not CurrentTarget 
                   or not CurrentTarget.Parent 
                   or not CurrentTarget:FindFirstChildOfClass("Humanoid") 
                   or CurrentTarget:FindFirstChildOfClass("Humanoid").Health <= 0 then
                    CurrentTarget = GetClosestSurvivor()
                end
                if CurrentTarget then
                    KillTarget(CurrentTarget)
                end
                task.wait(0.01)
            end
            loopRunning = false
        end)
    end

    Tabs.Farm:AddToggle("KillersFarmV2", {
        Title = "Killers Farm V2",
        Default = false,
        Callback = function(Value)
            Active = Value
            if Active then
                StartLoop()
            end
        end
    })
end




local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local solveGeneratorCooldown = false
local genDelay = 0.75 -- delay mặc định
local currentCharacter
local Spectators = {}
local isInGame, Survivor = false, false

local DangerousKillers = {
    ["Slasher"] = true,
    ["1x1x1x1"] = true,
    ["c00lkidd"] = true,
    ["Noli"] = true,
    ["JohnDoe"] = true,
    ["Guest 666"] = true,
    ["Sixer"] = true
}

local function isKillerNearGenerator(generatorPos, distance)
    local killersFolder = workspace.Players:FindFirstChild("Killers")
    if not killersFolder then return false end
    for _, killer in ipairs(killersFolder:GetChildren()) do
        if killer:IsA("Model") and killer:FindFirstChild("HumanoidRootPart") then
            if DangerousKillers[killer.Name] then
                local dist = (killer.HumanoidRootPart.Position - generatorPos).Magnitude
                if dist <= distance then
                    return true
                end
            end
        end
    end
    return false
end

local function getUnfinishedGenerators()
    local list = {}
    local map = workspace:FindFirstChild("Map") 
        and workspace.Map:FindFirstChild("Ingame") 
        and workspace.Map.Ingame:FindFirstChild("Map")
    if map then
        for _, gen in ipairs(map:GetChildren()) do
            if gen.Name == "Generator" 
                and gen:FindFirstChild("Progress") 
                and gen.Progress.Value < 100 then
                table.insert(list, gen)
            end
        end
    end

    if #list == 1 then
        genDelay = 1.5
    else
        genDelay = 0.75
    end

    return list
end

local function fixOneGenerator(gen)
    if solveGeneratorCooldown then return end
    if not currentCharacter or not currentCharacter:FindFirstChild("HumanoidRootPart") then return end

    local genCFrame = gen:GetPivot()
    local goalPos = (genCFrame * CFrame.new(0, 0, -7)).Position

    if isKillerNearGenerator(goalPos, 50) then
        print("⚠️ Bỏ qua generator vì killer nguy hiểm gần!")
        return
    end

    currentCharacter:PivotTo(CFrame.new(goalPos + Vector3.new(0, 0, 0))) -- chỉnh độ cao, độ lệch
    task.wait(0.25)

    local prompt = gen:FindFirstChild("Main") and gen.Main:FindFirstChild("Prompt")
    if prompt then
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 99999

        pcall(function()
            prompt:InputHoldBegin()
            prompt:InputHoldEnd()
        end)
    end

    if gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE") then
        gen.Remotes.RE:FireServer()
    end

    if prompt then
        task.wait(0)
        pcall(function()
            for i = 1, 3 do
                prompt:InputHoldBegin()
                task.wait(0)
                prompt:InputHoldEnd()
            end
        end)
    end

    solveGeneratorCooldown = true
    task.delay(genDelay, function()
        solveGeneratorCooldown = false
    end)
end

Tabs.Farm:AddToggle("SurvivorsAutoFarmV2", {
    Title = "Survivors Farm V2",
    Default = false
}):OnChanged(function(Value)
    _G.SurvivorsFarm = Value

    task.spawn(function()
        while _G.SurvivorsFarm do
            Spectators = {}
            for _, v in ipairs(workspace:WaitForChild("Players"):WaitForChild("Spectating"):GetChildren()) do
                table.insert(Spectators, v.Name)
            end
            isInGame = not table.find(Spectators, LP.Name)
            task.wait(0.1)
        end
    end)

    task.spawn(function()
        while _G.SurvivorsFarm do
            if workspace:FindFirstChild("Players") then
                local survivorsFolder = workspace.Players:FindFirstChild("Survivors")
                Survivor = survivorsFolder 
                    and (survivorsFolder:FindFirstChild(LP.Name) 
                    or table.find(survivorsFolder:GetChildren(), LP.Character))
            end
            task.wait(0.1)
        end
    end)

    task.spawn(function()
        local survivorsFolder = workspace.Players:WaitForChild("Survivors")
        while _G.SurvivorsFarm do
            if Survivor and isInGame then
                for _, surv in ipairs(survivorsFolder:GetChildren()) do
                    if surv:GetAttribute("Username") == LP.Name then
                        currentCharacter = surv
                        break
                    end
                end

                local gens = getUnfinishedGenerators()
                for _, gen in ipairs(gens) do
                    if not _G.SurvivorsFarm then break end
                    fixOneGenerator(gen)
                    task.wait(genDelay)
                end
            end
            task.wait(0.1)
        end
    end)
end)







    Tabs.Farm:AddSection("↳ Generator")

do
local solveGeneratorCooldown = false
local AutoFinishGen = false
local genDelay = 1.5

local function getClosestGenerator()
    local char = game.Players.LocalPlayer.Character
    if not char or not char.PrimaryPart then return nil end

    local root = char.PrimaryPart
    local closest, shortestDist = nil, math.huge

    local mapContainer = workspace:FindFirstChild("Map")
    if mapContainer then
        local ingame = mapContainer:FindFirstChild("Ingame")
        if ingame then
            local map = ingame:FindFirstChild("Map")
            if map then
                for _, obj in ipairs(map:GetChildren()) do
                    if obj.Name == "Generator" and obj:IsA("Model") and obj.PrimaryPart then
                        local dist = (root.Position - obj.PrimaryPart.Position).Magnitude
                        if dist < shortestDist then
                            closest = obj
                            shortestDist = dist
                        end
                    end
                end
            end
        end
    end
    return closest
end

Tabs.Farm:AddButton({
    Title = "Finish Generator",
    Callback = function()
        if solveGeneratorCooldown then 
            print("⏳ Please wait before trying again!") 
            return
        end
        if AutoFinishGen then
            print("❌ Please disable Auto Finish Generator first!")
            return
        end

        local gen = getClosestGenerator()
        if gen and gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE") then
            gen.Remotes.RE:FireServer()
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
        if solveGeneratorCooldown then
            print("⚠️ Please wait cooldown before enabling Auto Finish!") 
            Fluent.Options.AutoFinishGen:SetValue(false)
            return
        end

        task.spawn(function()
            while AutoFinishGen do
                local gen = getClosestGenerator()
                if gen and gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE") then
                    gen.Remotes.RE:FireServer()
                end
                solveGeneratorCooldown = true
                task.wait(genDelay)
                solveGeneratorCooldown = false
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
            -- Clamp giá trị từ 1.5 đến 10
            genDelay = math.clamp(num, 1.5, 10)
            print("⏱ Delay set to:", genDelay)
        else
            print("⚠️ Nhập số hợp lệ!")
        end
    end
})
end





    Tabs.Farm:AddSection("↳ Items")

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local function pickUpNearest()
    local map = workspace:FindFirstChild("Map") 
                and workspace.Map:FindFirstChild("Ingame") 
                and workspace.Map.Ingame:FindFirstChild("Map")
    if not map or not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end

    local oldCFrame = LP.Character.HumanoidRootPart.CFrame
    for _, item in ipairs(map:GetChildren()) do
        if item:IsA("Tool") and item:FindFirstChild("ItemRoot") 
           and item.ItemRoot:FindFirstChild("ProximityPrompt") then
            LP.Character.HumanoidRootPart.CFrame = item.ItemRoot.CFrame
            task.wait(0.3)
            fireproximityprompt(item.ItemRoot.ProximityPrompt)
            task.wait(0.4)
            LP.Character.HumanoidRootPart.CFrame = oldCFrame
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
}):OnChanged(function(Value)
    _G.PickupItem = Value
    if not Value then return end

    task.spawn(function()
        while _G.PickupItem do
            pickUpNearest()
            task.wait(0.2) -- delay giữa mỗi lần nhặt
        end
    end)
end)




-- Tabs.Main


    Tabs.Main:AddSection("↳ Eliot")

do
local toggleOn = false
local toggleFlag = Instance.new("BoolValue")
toggleFlag.Name = "EliotPizzaAim_ToggleFlag"
toggleFlag.Value = false

Tabs.Main:AddToggle("NemPizza", {
    Title = "Pizza Aimbot",
    Default = toggleOn,
}):OnChanged(function(state)
    toggleOn = state
    toggleFlag.Value = state
end)

local maxDistance = 100
Tabs.Main:AddInput("PizzaAimDistance", {
    Title = "Aim Distance",
    Default = tostring(maxDistance),
    Placeholder = "Enter Number",
}):OnChanged(function(value)
    local num = tonumber(value)
    if num then
        maxDistance = num
    end
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local survivorsFolder = workspace:WaitForChild("Players"):WaitForChild("Survivors")

local PizzaAnimation = {
    ["114155003741146"] = true,
    ["104033348426533"] = true
}

local EliotModels = {["Elliot"] = true}

local autoRotateDisabledByScript = false
local currentTarget, isLockedOn, wasPlayingAnimation = nil, false, false
local aimOffset = 2 -- lệch phải 2 studs

local function isEliot()
    local char = localPlayer.Character
    return char and EliotModels[char.Name] or false
end

local function getMyHumanoid()
    local char = localPlayer.Character
    return char and char:FindFirstChildWhichIsA("Humanoid")
end

local function restoreAutoRotate()
    local hum = getMyHumanoid()
    if hum and autoRotateDisabledByScript then
        hum.AutoRotate = true
        autoRotateDisabledByScript = false
    end
end

local function isPlayingDangerousAnimation()
    local humanoid = getMyHumanoid()
    if not humanoid then return false end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return false end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if track and track.Animation and track.Animation.AnimationId then
            local animId = tostring(track.Animation.AnimationId):match("%d+")
            if animId and PizzaAnimation[animId] then
                return true
            end
        end
    end
    return false
end

local function getWeakestSurvivor()
    local list = {}
    local myChar = localPlayer.Character
    local myHum = getMyHumanoid()
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not myHum or not myHum.MaxHealth or myHum.MaxHealth <= 0 then return nil end

    local myHpPercent = myHum.Health / myHum.MaxHealth

    for _, obj in ipairs(survivorsFolder:GetChildren()) do
        if obj:IsA("Model") and obj ~= myChar then
            local hum = obj:FindFirstChildWhichIsA("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 and hum.MaxHealth > 0 then
                local dist = (hrp.Position - myRoot.Position).Magnitude
                local hpPercent = hum.Health / hum.MaxHealth
                if dist <= maxDistance then
                    table.insert(list, {model = obj, hp = hpPercent})
                end
            end
        end
    end

    table.sort(list, function(a, b)
        return a.hp < b.hp
    end)

    if #list == 0 then return nil end
    if myHpPercent <= list[1].hp and #list > 1 then
        return list[2].model
    else
        return list[1].model
    end
end

localPlayer.CharacterAdded:Connect(function()
    task.delay(0.1, function()
        autoRotateDisabledByScript = false
    end)
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

    local myHumanoid = getMyHumanoid()
    if not myHumanoid then return end
    local myRoot = myHumanoid.Parent and myHumanoid.Parent:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local isPlaying = isPlayingDangerousAnimation()

    if isPlaying and not isLockedOn then
        currentTarget = getWeakestSurvivor()
        if currentTarget then isLockedOn = true end
    end

    if isLockedOn and currentTarget then
        local tHum = currentTarget:FindFirstChildWhichIsA("Humanoid")
        local tHrp = currentTarget:FindFirstChild("HumanoidRootPart")
        if (not tHum) or (tHum.Health <= 0) or (not tHrp) then
            currentTarget, isLockedOn = nil, false
        end
    end

    if (not isPlaying) and wasPlayingAnimation then
        currentTarget, isLockedOn = nil, false
        restoreAutoRotate()
    end
    wasPlayingAnimation = isPlaying

    if isPlaying and isLockedOn and currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
        local hrp = currentTarget.HumanoidRootPart
        local targetPos = hrp.Position
        if not autoRotateDisabledByScript then
            myHumanoid.AutoRotate = false
            autoRotateDisabledByScript = true
        end

        local vel = hrp.Velocity
        if vel and vel.Magnitude > 2 then
            targetPos = targetPos + hrp.CFrame.LookVector * 3
        end

        local offset = myRoot.CFrame.RightVector * aimOffset
        local lookAt = Vector3.new(targetPos.X, myRoot.Position.Y, targetPos.Z) + offset

        myRoot.CFrame = myRoot.CFrame:Lerp(CFrame.lookAt(myRoot.Position, lookAt), 0.99)
    end
end)
end




do
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer

    getgenv().BlinkToPizzaToggle = false
    getgenv().HPThreshold = 30

    local function getHRP()
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        return char:WaitForChild("HumanoidRootPart")
    end

    local function getHP()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then return hum.Health end
        end
        return 0
    end

    local function getPizzaCF()
        local map = Workspace:FindFirstChild("Map")
        local ingame = map and map:FindFirstChild("Ingame")
        if not ingame then return nil end

        local pizza = ingame:FindFirstChild("Pizza")
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
    end

    Tabs.Main:AddToggle("BlinkPizza_Toggle", {
        Title = "Auto Eat Pizza",
        Default = false,
    }):OnChanged(function(state)
        getgenv().BlinkToPizzaToggle = state
    end)

    Tabs.Main:AddInput("PizzaHPThreshold", {
        Title = "HP Threshold",
        Default = tostring(getgenv().HPThreshold),
        Placeholder = "30",
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num then
            getgenv().HPThreshold = num
        end
    end)

    task.spawn(function()
        while task.wait(0.9) do
            if getgenv().BlinkToPizzaToggle then
                local hrp = getHRP()
                local pizzaCF = getPizzaCF()
                if pizzaCF and getHP() <= getgenv().HPThreshold then
                    local oldCF = hrp.CFrame
                    hrp.CFrame = pizzaCF * CFrame.new(0, 1, 0)

                    if getgenv().activateRemoteHook then
                        getgenv().activateRemoteHook("UnreliableRemoteEvent", "UpdCF")
                    end

                    task.delay(0.2, function()
                        hrp.CFrame = oldCF
                        task.wait(0.3)
                        if getgenv().deactivateRemoteHook then
                            getgenv().deactivateRemoteHook("UnreliableRemoteEvent", "UpdCF")
                        end
                    end)
                end
            end
        end
    end)
end




    Tabs.Main:AddSection("↳ Chance")



do
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local active = false
local useOffset = true
local predictionMode = "Speed"
local aimMode = "Normal"
local aimDuration = 1.7
local fasterDuration = 1.5
local spinDuration = 0.5
local aimTargets = {"Slasher", "c00lkidd", "JohnDoe", "1x1x1x1", "Noli", "Guest 666", "Sixer"}

local Humanoid, HRP = nil, nil
local originalWS, originalJP, originalAutoRotate = nil, nil, nil
local aiming = false
local prevFlintVisibleAim = false
local lastTriggerTime = 0

local autoCoinflip = false
local coinflipTargetCharge = 3
local coinflipCooldown = 0.15
local lastCoinflipTime = 0

local blockCoinflipWhenClose = true
local coinflipBlockDist = 50

local RemoteEvent
pcall(function()
    RemoteEvent = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("RemoteEvent")
end)

Tabs.Main:AddDropdown("AimMode", {
    Title = "Aim Mode",
    Values = {"Normal", "Faster", "Reflex"},
    Default = "Normal",
    Callback = function(val) aimMode = val end
})

Tabs.Main:AddDropdown("PredictionMode", {
    Title = "Prediction Mode",
    Values = {"Speed", "Ping", "front", "No Lag"},
    Default = "Speed",
    Callback = function(val) predictionMode = val end
})

Tabs.Main:AddDropdown("CoinflipChargeDropdown", {
    Title = "Select Score",
    Values = {"1 Point", "2 Point", "3 Point"},
    Default = "3 Point",
}):OnChanged(function(val)
    local num = tonumber(val and val:match("%d+"))
    if num then coinflipTargetCharge = num end
end)

Tabs.Main:AddInput("CoinflipDistance", {
    Title = "Distance",
    Default = "50",
    Placeholder = "Enter studs",
    Callback = function(val)
        local num = tonumber(val)
        if num and num > 0 then
            coinflipBlockDist = num
        end
    end
})

Tabs.Main:AddToggle("BlockCoinflipToggle", {
    Title = "Safe Mode",
    Default = true,
}):OnChanged(function(state)
    blockCoinflipWhenClose = state
end)

Tabs.Main:AddToggle("OffsetToggle", {
    Title = "Enable Offset",
    Default = true,
    Callback = function(state) useOffset = state end
})

Tabs.Main:AddToggle("AimbotToggle", {
    Title = "Auto Aim Shoot",
    Default = false,
    Callback = function(state) active = state end
})

Tabs.Main:AddToggle("AutoCoinflipToggle", {
    Title = "Auto Coin Flip",
    Default = false,
}):OnChanged(function(state)
    autoCoinflip = state
end)

local function setupCharacter(char)
    Humanoid = char:WaitForChild("Humanoid")
    HRP = char:WaitForChild("HumanoidRootPart")
end
if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

local function getValidTarget()
    -- Quét tất cả Players
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local char = plr.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, targetName in ipairs(aimTargets) do
                    if char.Name:lower():find(targetName:lower()) then
                        return hrp
                    end
                end
            end
        end
    end
    return nil
end

local function getPingSeconds()
    local pingStat = Stats.Network.ServerStatsItem["Data Ping"]
    if pingStat then return pingStat:GetValue() / 1000 end
    return 0.1
end

local function isFlintlockVisible()
    if not LocalPlayer.Character then return false end
    local flint = LocalPlayer.Character:FindFirstChild("Flintlock", true)
    if not flint then return false end
    if not (flint:IsA("BasePart") or flint:IsA("MeshPart") or flint:IsA("UnionOperation")) then
        flint = flint:FindFirstChildWhichIsA("BasePart", true)
        if not flint then return false end
    end
    return flint.Transparency < 1
end

local movementThreshold = 0.5
local function getPredictedAimPosPing(targetHRP)
    local ping = getPingSeconds()
    local velocity = targetHRP.Velocity
    if velocity.Magnitude <= movementThreshold then return targetHRP.Position end
    return targetHRP.Position + (velocity * ping)
end

local function getPredictedAimPosInfrontHRPPing(targetHRP)
    local ping = getPingSeconds()
    local studs = ping * 60
    if targetHRP.Velocity.Magnitude <= movementThreshold then return targetHRP.Position end
    return targetHRP.Position + (targetHRP.CFrame.LookVector * studs)
end

local function computeAimPos(targetHRP)
    if predictionMode == "Ping" then
        return getPredictedAimPosPing(targetHRP)
    elseif predictionMode == "front" then
        return targetHRP.Position + targetHRP.CFrame.LookVector * 4
    elseif predictionMode == "No Lag" then
        return getPredictedAimPosInfrontHRPPing(targetHRP)
    else
        local velocity = targetHRP.Velocity
        if velocity.Magnitude > 0.1 then
            if useOffset and HRP then
                local ok, toTarget = pcall(function() return (targetHRP.Position - HRP.Position).Unit end)
                if not ok then return targetHRP.Position end
                local moveDir = velocity.Unit
                local dot = toTarget:Dot(moveDir)
                if math.abs(dot) < 0.85 then
                    return targetHRP.Position + velocity * (4 / 60)
                else
                    return targetHRP.Position
                end
            else
                return targetHRP.Position
            end
        else
            return targetHRP.Position
        end
    end
end

local function safeSetCFrame(newCF)
    if typeof(newCF) == "CFrame" and tostring(newCF) ~= "nan" and HRP then
        HRP.CFrame = newCF
    end
end

local function faceInstant(toPos)
    if not HRP or not toPos then return end
    local fromPos = HRP.Position
    if (toPos - fromPos).Magnitude < 0.01 then return end
    local lookAt = Vector3.new(toPos.X, fromPos.Y, toPos.Z)
    local targetCF = CFrame.new(fromPos, lookAt)
    safeSetCFrame(HRP.CFrame:Lerp(targetCF, 0.99))
end

local function getAbilityContainer()
    local ok, container = pcall(function()
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        if not gui then return nil end
        local mainUI = gui:FindFirstChild("MainUI")
        if not mainUI then return nil end
        return mainUI:FindFirstChild("AbilityContainer")
    end)
    if ok then return container end
    return nil
end

local function tryActivateButton(button)
    if not button then return false end
    pcall(function() if button.Activate then button:Activate() end end)
    local ok, conns = pcall(function()
        if type(getconnections) == "function" and button.MouseButton1Click then
            return getconnections(button.MouseButton1Click)
        end
        return nil
    end)
    if ok and conns then
        for _, conn in ipairs(conns) do
            pcall(function()
                if conn.Function then conn.Function()
                elseif conn.func then conn.func()
                elseif conn.Fire then conn.Fire() end
            end)
        end
    end
    pcall(function() if button.Activated then button.Activated:Fire() end end)
    pcall(function() if button.MouseButton1Click then button.MouseButton1Click:Fire() end end)
    return true
end

local function findAbilityButtonByName(name)
    local container = getAbilityContainer()
    if not container then return nil end
    local btn = container:FindFirstChild(name)
    if btn then return btn end
    local lname = name:lower()
    for _, child in ipairs(container:GetChildren()) do
        if child.Name and child.Name:lower():find(lname) then return child end
        local found = child:FindFirstChildWhichIsA("ImageButton") or child:FindFirstChildWhichIsA("TextButton")
        if found and found.Name and found.Name:lower():find(lname) then
            return found
        end
    end
    return nil
end

local function clickCoinflipButton()
    local tryNames = {"CoinFlip", "Coin", "Reroll"}
    for _, n in ipairs(tryNames) do
        local b = findAbilityButtonByName(n)
        if b then
            if tryActivateButton(b) then return true end
        end
    end
    return false
end

local function findRerollContainer()
    local container = getAbilityContainer()
    if not container then return nil end
    local reroll = container:FindFirstChild("Reroll") or container:FindFirstChild("RerollAbility") or nil
    if reroll then return reroll end
    for _, child in ipairs(container:GetChildren()) do
        for _, obj in ipairs(child:GetDescendants()) do
            if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and obj.Text and tostring(obj.Text):match("%d") then
                return child
            end
        end
    end
    return nil
end

local function getNearbyMaxNumber()
    local reroll = findRerollContainer()
    if not reroll then return nil end
    local maxNum = nil
    for _, obj in ipairs(reroll:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and obj.Text then
            for num in tostring(obj.Text):gmatch("%d+") do
                local n = tonumber(num)
                if n then
                    if not maxNum or n > maxNum then maxNum = n end
                end
            end
        end
    end
    return maxNum
end

RunService.RenderStepped:Connect(function()
    if active and Humanoid and HRP then
        local isVisible = isFlintlockVisible()
        if isVisible and not prevFlintVisibleAim and not aiming then
            lastTriggerTime = tick()
            aiming = true
        end
        prevFlintVisibleAim = isVisible

        if aiming then
            local elapsed = tick() - lastTriggerTime

            if aimMode == "Reflex" then
                if elapsed <= spinDuration then
                    local spinProgress = elapsed / spinDuration
                    local spinAngle = math.rad(360 * spinProgress)
                    safeSetCFrame(CFrame.new(HRP.Position) * CFrame.Angles(0, spinAngle, 0))
                elseif elapsed <= spinDuration + 0.7 then
                    if not originalWS then
                        originalWS, originalJP, originalAutoRotate = Humanoid.WalkSpeed, Humanoid.JumpPower, Humanoid.AutoRotate
                    end
                    Humanoid.AutoRotate = false
                    HRP.AssemblyAngularVelocity = Vector3.zero
                    local targetHRP = getValidTarget()
                    if targetHRP then
                        faceInstant(computeAimPos(targetHRP))
                    end
                else
                    aiming = false
                    if originalWS then
                        Humanoid.WalkSpeed, Humanoid.JumpPower, Humanoid.AutoRotate =
                            originalWS, originalJP, originalAutoRotate
                        originalWS, originalJP, originalAutoRotate = nil, nil, nil
                    end
                end
            else
                local duration = (aimMode == "Faster") and fasterDuration or aimDuration
                if elapsed <= duration then
                    if not originalWS then
                        originalWS, originalJP, originalAutoRotate = Humanoid.WalkSpeed, Humanoid.JumpPower, Humanoid.AutoRotate
                    end
                    Humanoid.AutoRotate = false
                    HRP.AssemblyAngularVelocity = Vector3.zero
                    local targetHRP = getValidTarget()
                    if targetHRP then
                        faceInstant(computeAimPos(targetHRP))
                    end
                else
                    aiming = false
                    if originalWS then
                        Humanoid.WalkSpeed, Humanoid.JumpPower, Humanoid.AutoRotate =
                            originalWS, originalJP, originalAutoRotate
                        originalWS, originalJP, originalAutoRotate = nil, nil, nil
                    end
                end
            end
        end
    end

    if autoCoinflip then
        local tooClose = false
        if blockCoinflipWhenClose then
            local targetHRP = getValidTarget()
            if targetHRP and HRP then
                if (targetHRP.Position - HRP.Position).Magnitude <= coinflipBlockDist then
                    tooClose = true
                end
            end
        end

        if not tooClose then
            local maxNum = getNearbyMaxNumber()
            if not maxNum or maxNum < coinflipTargetCharge then
                if tick() - lastCoinflipTime >= coinflipCooldown then
                    lastCoinflipTime = tick()
                    local ok = clickCoinflipButton()
                    if not ok and RemoteEvent then
                        pcall(function()
                            RemoteEvent:FireServer("UseActorAbility", "CoinFlip")
                        end)
                    end
                end
            end
        end
    end
end)
end



    Tabs.Main:AddSection("↳ Two Time")

do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local lp = Players.LocalPlayer

    local Mode = "AI Aimbot"
    local checkRadius = 18
    local backstabDelay = 0.01

    local killersFolder = workspace:WaitForChild("Players"):WaitForChild("Killers")

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
        Values = { "AI Aimbot", "Player Aimbot" },
        Default = "AI Aimbot",
    }):OnChanged(function(value)
        Mode = value
        print("🎯 Backstab Mode:", value)
    end)

    local enabled = false
    Tabs.Main:AddToggle("AutoBackstab", {
        Title = "Auto Backstab V2",
        Default = false
    }):OnChanged(function(state)
        enabled = state
        print("🔪 Auto Backstab:", state and "ON" or "OFF")
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
                print("📏 Check Radius set to:", checkRadius)
            else
                print("⚠️ Nhập số hợp lệ!")
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
                        warn("[Backstab] Found Dagger Remote:", v:GetFullName())
                        return daggerRemote
                    end
                end
            end
        end
        return nil
    end

    local function initDaggerButton()
        local gui = lp:FindFirstChild("PlayerGui")
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
    lp.CharacterAdded:Connect(function()
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

    local function getCharacter()
        local ch = lp.Character
        if ch and ch.Parent then
            local hrp = ch:FindFirstChild("HumanoidRootPart")
            local humanoid = ch:FindFirstChildOfClass("Humanoid")
            return ch, humanoid, hrp
        end
        return nil, nil, nil
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
            if plr ~= lp and plr.Character then
                local char = plr.Character
                local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
                if hrp then
                    local dist = (hrp.Position - position).Magnitude
                    if dist <= checkRadius then
                        table.insert(killers, {model = char, hrp = hrp, dist = dist})
                    end
                end
            end
        end
        return killers
    end

    local function getNearbyAIKillers(hrp)
        local killers = {}
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

    local cooldown = false
    local lastTarget = nil

    RunService.Heartbeat:Connect(function()
        if not enabled or cooldown then return end
        local char, humanoid, myHRP = getCharacter()
        if not (char and humanoid and myHRP) then return end

        if char.Name ~= "TwoTime" then return end

        if Mode == "Player Aimbot" then
            if isPlayingTargetAnimation(humanoid) then
                local killers = getNearbyKillers(myHRP.Position)
                if #killers > 0 then
                    table.sort(killers, function(a,b) return a.dist < b.dist end)
                    local target = killers[1]
                    cooldown = true

                    local start = tick()
                    local conn
                    conn = RunService.Heartbeat:Connect(function()
                        if not (char and target.hrp and char.Parent and target.hrp.Parent) then
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
        end
    end)

    lp.CharacterAdded:Connect(function()
        task.wait(1)
        print("🔄 Character respawned/changed, Auto Backstab vẫn hoạt động (nếu model = 'TwoTime').")
    end)
end



    Tabs.Main:AddSection("↳ 007n7")


do
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local running = false
    local animTrack
    local InvisibleEnabled = false

    local survivorsFolder = workspace:WaitForChild("Players"):WaitForChild("Survivors")

    local function getHumanoid()
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        return char:FindFirstChildOfClass("Humanoid"), char
    end

    local function getAnimator(humanoid)
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end
        return animator
    end

    local function playInvisibleAnim(humanoid)
        local animator = getAnimator(humanoid)
        if not animTrack or not animTrack.IsPlaying then
            local animation = Instance.new("Animation")
            animation.AnimationId = "rbxassetid://75804462760596"
            animTrack = animator:LoadAnimation(animation)
            animTrack.Looped = true
            animTrack:Play()
            animTrack:AdjustSpeed(0)
        end
    end

    local function stopInvisibleAnim()
        if animTrack and animTrack.IsPlaying then
            animTrack:Stop()
            animTrack = nil
        end
    end

    local function isSurvivorModel(char)
        if not char then return false end
        if survivorsFolder:FindFirstChild(char.Name) then
            return true
        end
        return false
    end

    local function handleToggle(enabled)
        InvisibleEnabled = enabled
        local humanoid, char = getHumanoid()
        if not humanoid or not char then return end

        if enabled then
            running = true
            task.spawn(function()
                while running and InvisibleEnabled do
                    humanoid, char = getHumanoid()
                    if not humanoid or not char then
                        task.wait(0.5)
                        continue
                    end

                    if isSurvivorModel(char) then
                        playInvisibleAnim(humanoid)
                    else
                        stopInvisibleAnim()
                    end
                    task.wait(0.5)
                end
            end)
        else
            running = false
            stopInvisibleAnim()
        end
    end

    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(1)
        if InvisibleEnabled and isSurvivorModel(char) then
            handleToggle(true)
        end
    end)

    Tabs.Main:AddToggle("InstantInvisibleV2", {
        Title = "Instant Invisible",
        Default = false
    }):OnChanged(function(Value)
        handleToggle(Value)
    end)
end



do
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local running = false
    local animTrack

    local function getHumanoid()
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        return char:FindFirstChildOfClass("Humanoid"), char
    end

    local function getAnimator(humanoid)
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end
        return animator
    end

    local function playInvisibleAnim(humanoid)
        local animator = getAnimator(humanoid)
        if not animTrack or not animTrack.IsPlaying then
            local animation = Instance.new("Animation")
            animation.AnimationId = "rbxassetid://75804462760596"
            animTrack = animator:LoadAnimation(animation)
            animTrack.Looped = true
            animTrack:Play()
            animTrack:AdjustSpeed(0)
        end
    end

    local function stopInvisibleAnim()
        if animTrack and animTrack.IsPlaying then
            animTrack:Stop()
            animTrack = nil
        end
    end

    local function handleToggle(enabled)
        local humanoid, char = getHumanoid()
        if not humanoid or not char then return end

        if enabled then
            running = true
            task.spawn(function()
                while running do
                    humanoid, char = getHumanoid()
                    if not humanoid or not char then break end

                    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                    local root = char:FindFirstChild("HumanoidRootPart")

                    if torso and torso.Transparency ~= 0 then
                        playInvisibleAnim(humanoid)
                        if root then root.Transparency = 0.4 end
                    else
                        stopInvisibleAnim()
                        if root then root.Transparency = 1 end
                    end

                    task.wait(0.5)
                end
            end)
        else
            running = false
            stopInvisibleAnim()
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.Transparency = 1
            end
        end
    end

    Tabs.Main:AddToggle("InvisibleCloneV2", {
        Title = "Invisible if cloned",
        Default = _G.InvisibleClone or false
    }):OnChanged(function(Value)
        _G.InvisibleClone = Value
        handleToggle(Value)
    end)
end


    Tabs.Main:AddSection("↳ Veeronica")

Tabs.Main:AddToggle("AutoTrick", {
    Title = "Auto Trick V2",
    Default = false,
    Callback = function(Value)
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Players = game:GetService("Players")
        local VirtualInputManager = game:GetService("VirtualInputManager")

        local player = Players.LocalPlayer
        local device = "Mobile"

        local function getBehaviorFolder()
            local ok, folder = pcall(function()
                return ReplicatedStorage.Assets.Survivors.Veeronica.Behavior
            end)
            return ok and folder
        end

        local function getSprintingButton()
            local gui = player:FindFirstChild("PlayerGui")
            if not gui then return end
            local main = gui:FindFirstChild("MainUI")
            if not main then return end
            return main:FindFirstChild("SprintingButton")
        end

        local function adorneeIsPlayerCharacter(h)
            if not h then return false end
            local adornee = h.Adornee
            local char = player.Character
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




    Tabs.Main:AddSection("↳ Guest1337")




do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local localPlayer = Players.LocalPlayer

    local Killers = {
        ["Slasher"] = true,
        ["1x1x1x1"] = true,
        ["c00lkidd"] = true,
        ["Noli"] = true,
        ["JohnDoe"] = true,
        ["Guest 666"] = true,
        ["Sixer"] = true
    }

    local function isKiller(player)
        local char = player.Character
        if not char then return false end
        return Killers[char.Name] == true
    end

    local animationIds = {
        ["83829782357897"]  = true, -- Slash, 1x1x1x1
        ["126830014841198"] = true, -- Slash, Jason
        ["126355327951215"] = true, -- Behead, Jason
        ["121086746534252"] = true, -- GashingWoundStart, Jason
        ["105458270463374"] = true, -- Slash, JohnDoe
        ["18885909645"]     = true, -- Attack, c00lkid
        ["94162446513587"]  = true, -- Slash, JohnDoe, Skin: !Joner
        ["93069721274110"]  = true, -- Slash, JohnDoe, Skin: AnnihilationJohnDoe
        ["97433060861952"]  = true, -- Slash, JohnDoe, Skin: #SK
        ["121293883585738"] = true, -- Slash, 1x1x1x1
        ["92173139187970"]  = true, -- Slash, Skin: Hacklord1x1x1x1
        ["106847695270773"] = true, -- GashingWoundStart, Jason, Skin: Subject0Jason
        ["125403313786645"] = true, -- Slash, Jason, Skin: Subject0Jason
        ["81639435858902"]  = true, -- Behead, Jason, Skin: WhitePumpkinJason
        ["137314737492715"] = true, -- GashingWoundStart, Jason, Skin: WhitePumpkinJason
        ["120112897026015"] = true, -- Slash, Jason, Skin: WhitePumpkinJason
        ["82113744478546"]  = true, -- Behead, Jason (nhiều skin)
        ["118298475669935"] = true, -- Slash, Jason (nhiều skin)
        ["126681776859538"] = true, -- Behead, Jason, Skin: PursuerJason
        ["129976080405072"] = true, -- GashingWoundStart, Jason, Skin: PursuerJason
        ["109667959938617"] = true, -- Slash, Jason, Skin: PursuerJason
        ["74707328554358"]  = true, -- Slash, Jason, Skin: #DeadRabbitsJason
        ["133336594357903"] = true, -- Behead, Jason, Skin: #DeadRabbitsJason
        ["86204001129974"]  = true, -- GashingWoundStart, Jason, Skin: #DeadRabbitsJason
        ["70371667919898"]  = true, -- Attack, c00lkidd, Skin: MafiosoC00l
        ["131543461321709"] = true, -- Attack, c00lkidd, Skin: SaviorC00l
        ["106776364623742"] = true, -- Walkspeed Overing, c00lkidd (all skins)
        ["136323728355613"] = true, -- Swing, Noli
        ["109230267448394"] = true, -- Swing, Noli (all skins)
        ["139835501033932"] = true, -- VoidRush, Noli (all skins)
        ["114356208094580"] = true, -- VoidRush2, Noli
        ["106538427162796"] = true, -- Stab, All Noli
        ["126896426760253"] = true, -- VoidRush, Noli
        ["131430497821198"] = true, -- MassInfection, 1x1x1x1
        ["100592913030351"] = true, -- MassInfection, 1x1x1x1 (Fleskhjerta/AceOfSpades/Lancer)
        ["70447634862911"]  = true, -- MassInfection, Skin: Hacklord1x1x1x1 Old
        ["83685305553364"]  = true, -- MassInfection, Skin: Hacklord1x1x1x1 New
        ["126171487400618"]  = true, -- Slash, Skin: Hacklord1x1x1x1
        ["97167027849946"]  = true, -- Noli Dash Belike
        ["99135633258223"]  = true,
        ["98456918873918"]  = true,
        ["83251433279852"]  = true,
        ["126681776859538"] = true,
        ["129976080405072"] = true,
        ["122709416391891"] = true, -- Đánh Thường Guest 666
        ["87989533095285"] = true, -- Vồ Tới Guest 666
        ["139309647473555"] = true, -- Bay Đến Mục Tiêu
        ["133363345661032"] = true, -- Chuẩn Bị Bay Đến Mục tiêu
        ["128414736976503"] = true, -- Sẵn Sàng Bay Đến
        ["77375846492436"] = true, -- Noli Aful Rework
        ["92445608014276"] = true, -- NAR
        ["100358581940485"] = true, -- NAR
        ["91758760621955"] = true, -- NAR
        ["94634594529334"] = true, -- NAR
        ["90620531468240"] = true, -- 1x slash m2-3 rework
        ["94958041603347"] = true, -- Slasher Bí ngô trắng / chém
        ["131642454238375"] = true, -- Slasher Bí Ngô trắng / Khóa skill
        ["110702884830060"] = true, -- Slasher Bí Ngô Trắng / Liên Hoàn Chém
        ["76312020299624"] = true, -- Noli Admin Void rush
        ["126654961540956"] = true, -- NAVR
        ["139613699193400"] = true, -- NAVR
        ["91509234639766"] = true, -- NA Đánh Thường
        ["105458270463374"] = true, -- John Doe M3 và M4 Đánh Thường
        ["114506382930939"] = true, -- 1x Skin Martyr Chém Thường
    }

    local delayedAnimations = {}

    local toggleOn = false
    local strictRangeOn = false
    local detectionRange = 18

    local blockRemote
    local blockButton, connections = nil, {}

    local function findBlockRemote()
        if blockRemote then return blockRemote end
        if not blockButton then return nil end
        for _, conn in ipairs(getconnections(blockButton.MouseButton1Click)) do
            local f = conn.Function
            if f and islclosure(f) then
                local upvals = getupvalues(f)
                for _, v in pairs(upvals) do
                    if typeof(v) == "Instance" and v:IsA("RemoteEvent") then
                        blockRemote = v
                        warn("[AutoBlock] Found Block Remote:", v:GetFullName())
                        return blockRemote
                    end
                end
            end
        end
        return nil
    end

    local function initBlockButton()
        local gui = localPlayer:FindFirstChild("PlayerGui")
        if not gui then return end
        local mainUI = gui:FindFirstChild("MainUI")
        local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
        blockButton = container and container:FindFirstChild("Block")
        if blockButton and blockButton:IsA("ImageButton") then
            connections = getconnections(blockButton.MouseButton1Click)
            findBlockRemote()
        end
    end

    initBlockButton()
    localPlayer.CharacterAdded:Connect(function()
        task.wait(0)
        initBlockButton()
    end)

    local function fastBlock()
        if blockRemote then
            pcall(function()
                blockRemote:FireServer(true)
                task.delay(1e-10, function()
                    blockRemote:FireServer(false)
                end)
            end)
        else
            if not blockButton or not blockButton.Visible then return end
            for _, conn in ipairs(connections) do
                pcall(function() conn:Fire() end)
            end
            pcall(function() blockButton:Activate() end)
        end
    end

    local lastTeleport = 0
    local function teleportDodge(killerChar)
        local now = tick()
        if now - lastTeleport < 5 then return end
        lastTeleport = now

        local myChar = localPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
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

    local function getBoolFlag(name, default)
        local flag = localPlayer:FindFirstChild(name)
        if not flag then
            flag = Instance.new("BoolValue")
            flag.Name = name
            flag.Value = default
            flag.Parent = localPlayer
        end
        return flag
    end

    local function getNumberFlag(name, default)
        local flag = localPlayer:FindFirstChild(name)
        if not flag then
            flag = Instance.new("NumberValue")
            flag.Name = name
            flag.Value = default
            flag.Parent = localPlayer
        end
        return flag
    end

    local toggleFlag = getBoolFlag("AutoBlockToggle", false)
    local strictFlag = getBoolFlag("AutoBlockStrictRange", false)
    local rangeFlag = getNumberFlag("AutoBlockRange", 18)

    toggleOn = toggleFlag.Value
    strictRangeOn = strictFlag.Value
    detectionRange = rangeFlag.Value

    Tabs.Main:AddToggle("AutoBlockV2", {Title = "Auto Block V3", Default = toggleOn})
        :OnChanged(function(state)
            toggleOn = state
            toggleFlag.Value = state
        end)

    Tabs.Main:AddToggle("StrictRangeCheck", {Title = "Auto Check V3", Default = strictRangeOn})
        :OnChanged(function(state)
            strictRangeOn = state
            strictFlag.Value = state
        end)

    Tabs.Main:AddInput("RangeCheckInput", {
        Title = "Range Check",
        Default = tostring(detectionRange),
        Placeholder = "Enter detection range"
    }):OnChanged(function(txt)
        local val = tonumber(txt)
        if val then
            detectionRange = val
            rangeFlag.Value = val
        end
    end)

    local playerConns = {}
    local recentBlocks = {}
    local COOLDOWN_ZERO, COOLDOWN_MISS = 0, 0

    local function cleanupPlayerConns(p)
        local tbl = playerConns[p]
        if tbl then
            for _, c in ipairs(tbl) do
                if c and c.Disconnect then c:Disconnect() end
            end
            playerConns[p] = nil
        end
        recentBlocks[p.UserId] = nil
    end

    local function shouldBlockNow(p, animId, track)
        recentBlocks[p.UserId] = recentBlocks[p.UserId] or {}
        local last = recentBlocks[p.UserId][animId] or 0
        local now = tick()
        if track.TimePosition <= 0 then
            if now - last >= COOLDOWN_ZERO then
                recentBlocks[p.UserId][animId] = now
                return true
            end
            return false
        else
            if now - last >= COOLDOWN_MISS then
                recentBlocks[p.UserId][animId] = now
                return true
            end
            return false
        end
    end

    local massInfectionIds = {
        ["131430497821198"] = true,
        ["100592913030351"] = true,
        ["70447634862911"]  = true,
        ["83685305553364"]  = true,
        ["101101433684051"] = true,
        ["109777684604906"] = true,
    }

    local function onAnimationPlayed(player, char, track)
        if not toggleOn then return end
        if not (track and track.Animation) then return end
        local animIdStr = track.Animation.AnimationId
        local id = animIdStr and string.match(animIdStr, "%d+")
        if not id or not animationIds[id] then return end

        if strictRangeOn then
            local myChar = localPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not myRoot or not root then return end
            local dist = (root.Position - myRoot.Position).Magnitude
            if dist > detectionRange then return end
        end

        if shouldBlockNow(player, id, track) then
            if massInfectionIds[id] then
                task.delay(0.5, fastBlock) -- delay 0.5s cho MassInfection
            else
                fastBlock()
            end

            if isKiller(player) and delayedAnimations[id] then
                teleportDodge(char)
            end
        end
    end

    local function monitorCharacter(player, char)
        if not player or not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        if not hum then return end
        local con = hum.AnimationPlayed:Connect(function(track)
            task.spawn(onAnimationPlayed, player, char, track)
        end)
        playerConns[player] = playerConns[player] or {}
        table.insert(playerConns[player], con)
    end

    local function onPlayerAdded(player)
        if player == localPlayer then return end
        if player.Character then monitorCharacter(player, player.Character) end
        local conCharAdded = player.CharacterAdded:Connect(function(char)
            task.wait(0)
            monitorCharacter(player, char)
        end)
        playerConns[player] = playerConns[player] or {}
        table.insert(playerConns[player], conCharAdded)
    end

    for _, p in ipairs(Players:GetPlayers()) do onPlayerAdded(p) end
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(cleanupPlayerConns)

    local circles = {}

    local function createCircleFor(player, hrp)
        if circles[player] then circles[player]:Destroy() end
        local circle = Instance.new("Part")
        circle.Anchored, circle.CanCollide = true, false
        circle.Shape = Enum.PartType.Cylinder
        circle.Size = Vector3.new(0.2, detectionRange * 2, detectionRange * 2)
        circle.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(90))
        circle.Material, circle.Transparency = Enum.Material.Neon, 0.5
        circle.Color = Color3.fromRGB(255, 0, 0)
        circle.Parent = workspace
        circles[player] = circle
    end

    local function removeCircle(player)
        if circles[player] then circles[player]:Destroy() circles[player] = nil end
    end

    RunService.Heartbeat:Connect(function()
        if not strictRangeOn then
            for _, circle in pairs(circles) do
                if circle then circle.Transparency = 1 end
            end
            return
        end
        local myChar = localPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 and isKiller(player) then
                    if not circles[player] then createCircleFor(player, hrp) end
                    local circle = circles[player]
                    circle.Size = Vector3.new(0.2, detectionRange * 2, detectionRange * 2)
                    circle.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(90))
                    local dist = (myRoot.Position - hrp.Position).Magnitude
                    circle.Color = (dist <= detectionRange) and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
                    circle.Transparency = 0.5
                else
                    removeCircle(player)
                end
            end
        end
    end)

    Players.PlayerRemoving:Connect(removeCircle)
end








do
    local autoPunchOn, aimPunch, flingPunchOn, customPunchEnabled = false, false, false, false
    local hiddenfling = false
    local flingPower = 10000
    local predictionValue = 4
    local customPunchAnimId = ""
    local Humanoid
    local lastPunchTime = 0
    local punchAnimIds = { "87259391926321" }
    local LP = game:GetService("Players").LocalPlayer
    local RunService = game:GetService("RunService")
    local PlayerGui = LP:WaitForChild("PlayerGui")

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
                    c = LP.Character
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
        local myChar = LP.Character
        if not myChar then return end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        Humanoid = myChar:FindFirstChildOfClass("Humanoid")

        if autoPunchOn then
            local gui = PlayerGui:FindFirstChild("MainUI")
            local punchBtn = gui and gui:FindFirstChild("AbilityContainer") and gui.AbilityContainer:FindFirstChild("Punch")
            local charges = punchBtn and punchBtn:FindFirstChild("Charges")

            if charges and charges.Text == "1" then
                local killerNames = {"c00lkidd", "Slasher", "JohnDoe", "1x1x1x1", "Noli", "Guest 666", "Sixer"}
                for _, name in ipairs(killerNames) do
                    local killer = workspace:FindFirstChild("Players")
                        and workspace.Players:FindFirstChild("Killers")
                        and workspace.Players.Killers:FindFirstChild(name)

                    if killer and killer:FindFirstChild("HumanoidRootPart") then
                        local root = killer.HumanoidRootPart
                        if root and myRoot and (root.Position - myRoot.Position).Magnitude <= 10 then

                            if aimPunch then
                                local humanoid = myChar:FindFirstChild("Humanoid")
                                if humanoid then humanoid.AutoRotate = false end
                                task.spawn(function()
                                    local start = tick()
                                    while tick() - start < 2 do
                                        if myRoot and root and root.Parent then
                                            local predictedPos = root.Position + (root.CFrame.LookVector * predictionValue)
                                            myRoot.CFrame = CFrame.lookAt(myRoot.Position, predictedPos)
                                        end
                                        task.wait()
                                    end
                                    if humanoid then humanoid.AutoRotate = true end
                                end)
                            end

                            for _, conn in ipairs(getconnections(punchBtn.MouseButton1Click)) do
                                pcall(function() conn:Fire() end)
                            end

                            if flingPunchOn then
                                hiddenfling = true
                                task.spawn(function()
                                    local start = tick()
                                    while tick() - start < 1 do
                                        if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and root and root.Parent then
                                            local frontPos = root.Position + (root.CFrame.LookVector * 2)
                                            LP.Character.HumanoidRootPart.CFrame = CFrame.new(frontPos, root.Position)
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
end




    Tabs.Main:AddSection("↳ Noli")

do
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local voidrushcontrol = false
    local DASH_SPEED = 80
    local ATTACK_RANGE = 6
    local ATTACK_INTERVAL = 0.2

    local survivorsFolder = workspace:WaitForChild("Players"):WaitForChild("Survivors")

    local function isPriorityTarget(p)
        if not p or not p.Character then return false end
        return survivorsFolder:FindFirstChild(p.Name) ~= nil
    end

    local isOverrideActive = false
    local connection
    local Humanoid, RootPart
    local lastState = nil
    local attackingLoop = nil

    local function setupCharacter(character)
        Humanoid = character:WaitForChild("Humanoid")
        RootPart = character:WaitForChild("HumanoidRootPart")
        Humanoid.Died:Connect(function()
            stopOverride()
        end)
    end

    if LocalPlayer.Character then
        setupCharacter(LocalPlayer.Character)
    end
    LocalPlayer.CharacterAdded:Connect(setupCharacter)

    local function validTarget(p)
        if p == LocalPlayer then return false end
        local c = p.Character
        if not c then return false end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChild("Humanoid")
        return hrp and hum and hum.Health > 0
    end

    local function getClosestTarget()
        if not RootPart then return nil end

        local closestW, distW = nil, math.huge
        local closestA, distA = nil, math.huge

        for _, p in ipairs(Players:GetPlayers()) do
            if validTarget(p) then
                local c = p.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = (hrp.Position - RootPart.Position).Magnitude
                    if isPriorityTarget(p) and d < distW then
                        distW = d
                        closestW = p
                    end
                    if d < distA then
                        distA = d
                        closestA = p
                    end
                end
            end
        end

        return closestW or closestA, distW < math.huge and distW or distA
    end

    local function attemptAttack()
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool and tool.Parent == char then
            pcall(function() tool:Activate() end)
        end
    end

    local function startOverride()
        if isOverrideActive or not Humanoid or not RootPart then return end
        isOverrideActive = true

        connection = RunService.RenderStepped:Connect(function()
            if not Humanoid or not RootPart or Humanoid.Health <= 0 then return end
            local target, dist = getClosestTarget()

            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = target.Character.HumanoidRootPart
                local dir = hrp.Position - RootPart.Position
                local horizontal = Vector3.new(dir.X, 0, dir.Z)

                if horizontal.Magnitude > 0.1 then
                    RootPart.CFrame = CFrame.new(RootPart.Position, Vector3.new(hrp.Position.X, RootPart.Position.Y, hrp.Position.Z))
                    RootPart.AssemblyLinearVelocity = horizontal.Unit * DASH_SPEED
                else
                    RootPart.AssemblyLinearVelocity = Vector3.zero
                end
            else
                RootPart.AssemblyLinearVelocity = Vector3.zero
            end
        end)

        attackingLoop = task.spawn(function()
            while isOverrideActive do
                local target, dist = getClosestTarget()
                if target and dist and dist <= ATTACK_RANGE then
                    attemptAttack()
                end
                task.wait(ATTACK_INTERVAL)
            end
        end)
    end

    function stopOverride()
        if not isOverrideActive then return end
        isOverrideActive = false
        if connection then
            connection:Disconnect()
            connection = nil
        end
        if RootPart then
            RootPart.AssemblyLinearVelocity = Vector3.zero
        end
    end

    RunService.RenderStepped:Connect(function()
        if not voidrushcontrol or not Humanoid then return end
        local state = Humanoid.Parent and Humanoid.Parent:GetAttribute("VoidRushState")
        if state ~= lastState then
            lastState = state
            if state == "Dashing" then
                startOverride()
            else
                stopOverride()
            end
        end
    end)

    Tabs.Main:AddToggle("VoidRushControl", {
        Title = "Void Rush Aimbot",
        Default = false
    }):OnChanged(function(v)
        voidrushcontrol = v
        if not v then stopOverride() end
    end)
end



    Tabs.Main:AddSection("↳ 1x1x1x1")

do
local toggleOn = false
local toggleFlag = Instance.new("BoolValue")
toggleFlag.Name = "1x1x1x1AutoAim_ToggleFlag"
toggleFlag.Value = false

local aimMode = "One Player"
local predictMovement = false

Tabs.Main:AddDropdown("AimModeDropdown", {
    Title = "Aim Mode",
    Values = {"One Player", "Multi Players", "Teleport"},
    Default = "One Player",
}):OnChanged(function(value)
    aimMode = value
end)

Tabs.Main:AddToggle("AimSkill1x1x1x1", {
    Title = "MassInfection Aimbot",
    Default = toggleOn,
}):OnChanged(function(state)
    toggleOn = state
    toggleFlag.Value = state
end)

Tabs.Main:AddToggle("PredictMovementToggle", {
    Title = "Predict Movement",
    Default = predictMovement,
}):OnChanged(function(state)
    predictMovement = state
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local workspacePlayers = workspace:WaitForChild("Players")
local survivorsFolder = workspacePlayers:WaitForChild("Survivors")

local dangerousAnimations = {
    ["131430497821198"] = true,
    ["100592913030351"] = true,
    ["70447634862911"]  = true,
    ["83685305553364"] = true,
    ["101101433684051"] = true,
    ["109777684604906"] = true
}

local killerModels = {["1x1x1x1"] = true}

local autoRotateDisabledByScript = false
local currentTarget, isLockedOn, wasPlayingAnimation = nil, false, false

local function isKiller()
    local char = localPlayer.Character
    return char and killerModels[char.Name] or false
end

local function getMyHumanoid()
    local char = localPlayer.Character
    return char and char:FindFirstChildWhichIsA("Humanoid")
end

local function restoreAutoRotate()
    local hum = getMyHumanoid()
    if hum and autoRotateDisabledByScript then
        hum.AutoRotate = true
        autoRotateDisabledByScript = false
    end
end

local function isPlayingDangerousAnimation()
    local humanoid = getMyHumanoid()
    if not humanoid then return false end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return false end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animId = tostring(track.Animation.AnimationId):match("%d+")
        if animId and dangerousAnimations[animId] then
            return true
        end
    end
    return false
end

local function getClosestSurvivor()
    local myHumanoid = getMyHumanoid()
    if not myHumanoid then return nil end
    local myRoot = myHumanoid.Parent and myHumanoid.Parent:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local closest, closestDist = nil, math.huge

    for _, obj in ipairs(survivorsFolder:GetChildren()) do
        if obj:IsA("Model") then
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            local hum = obj:FindFirstChildWhichIsA("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local dist = (hrp.Position - myRoot.Position).Magnitude
                if dist < closestDist then
                    closest = obj
                    closestDist = dist
                end
            end
        end
    end
    return closest
end

localPlayer.CharacterAdded:Connect(function()
    task.delay(0.1, function()
        autoRotateDisabledByScript = false
    end)
end)

RunService.RenderStepped:Connect(function()
    if not toggleFlag.Value then
        restoreAutoRotate()
        currentTarget, isLockedOn, wasPlayingAnimation = nil, false, false
        return
    end

    if not isKiller() then
        restoreAutoRotate()
        currentTarget, isLockedOn, wasPlayingAnimation = nil, false, false
        return
    end

    local myHumanoid = getMyHumanoid()
    if not myHumanoid then return end
    local myRoot = myHumanoid.Parent and myHumanoid.Parent:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local isPlaying = isPlayingDangerousAnimation()

    if isPlaying and not isLockedOn then
        currentTarget = getClosestSurvivor()
        if currentTarget then isLockedOn = true end
    end

    if isLockedOn and currentTarget then
        local tHum = currentTarget:FindFirstChildWhichIsA("Humanoid")
        local tHrp = currentTarget:FindFirstChild("HumanoidRootPart")
        if (not tHum) or (tHum and tHum.Health <= 0) or (not tHrp) then
            currentTarget, isLockedOn = nil, false
        end
    end

    if (not isPlaying) and wasPlayingAnimation then
        currentTarget, isLockedOn = nil, false
        restoreAutoRotate()
    end
    wasPlayingAnimation = isPlaying

    if isPlaying and isLockedOn and currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
        local hrp = currentTarget.HumanoidRootPart
        local targetPos = hrp.Position

        if not autoRotateDisabledByScript then
            myHumanoid.AutoRotate = false
            autoRotateDisabledByScript = true
        end

        if predictMovement then
            local vel = hrp.Velocity
            if vel.Magnitude > 2 then
                targetPos = targetPos + hrp.CFrame.LookVector * 3
            end
        end

        local lookAt = Vector3.new(targetPos.X, myRoot.Position.Y, targetPos.Z)

        if aimMode == "One Player" then
            myRoot.CFrame = myRoot.CFrame:Lerp(CFrame.lookAt(myRoot.Position, lookAt), 0.99)

        elseif aimMode == "Multi Players" then
            local newTarget = getClosestSurvivor()
            if newTarget then currentTarget = newTarget end
            myRoot.CFrame = myRoot.CFrame:Lerp(CFrame.lookAt(myRoot.Position, lookAt), 0.99)

        elseif aimMode == "Teleport" then
            local behindPos = hrp.Position - hrp.CFrame.LookVector * 3
            myRoot.CFrame = CFrame.new(behindPos, targetPos)
        end
    end
end)
end


-- Tabs.Event

    Tabs.Event:AddSection("↳ Halloween")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
local HRP = Character:FindFirstChild("HumanoidRootPart")

local function onCharacterAdded(char)
    Character = char
    Humanoid = Character:WaitForChild("Humanoid")
    HRP = Character:WaitForChild("HumanoidRootPart")
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

local function getHumanoidAndHRP()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hum, hrp
end

Tabs.Event:AddButton({
    Title = "TP to Shop",
    Description = "Teleport đến khu Shop",
    Callback = function()
        local _, hrp = getHumanoidAndHRP()
        if hrp then
            hrp.CFrame = CFrame.new(-3540.36, -392.73, 231.53)
        end
    end,
})

local allowedModels = {
    ["dumsek"]=true, ["toon dusek"]=true, ["dusek"]=true,
    ["umdum"]=true, ["doothsek"]=true
}
local blockedCenter = Vector3.new(-3485.02, 4.48, 217.77)
local blockedRadius = 500

local function isValidModel(model)
    if not model or not model:IsDescendantOf(workspace) then return false end
    if not allowedModels[model.Name:lower()] then return false end
    local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    if not part then return false end
    return (part.Position - blockedCenter).Magnitude > blockedRadius
end

_G.ESPManager:RegisterType("Sukkars", Color3.fromRGB(0,85,255), isValidModel, false)

local oldCreate = _G.ESPManager.Create
_G.ESPManager.Create = function(self, model, typeName)
    oldCreate(self, model, typeName)
    if typeName ~= "Sukkars" then return end

    local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    if part and not part:FindFirstChild("_TouchedFlag") then
        local flag = Instance.new("BoolValue")
        flag.Name = "_TouchedFlag"
        flag.Parent = part
        part.Touched:Connect(function(hit)
            local char = LocalPlayer.Character
            if char and hit:IsDescendantOf(char) then
                _G.ESPManager:Remove(model)
            end
        end)
    end
end

task.spawn(function()
    while task.wait(0.15) do
        local _, hrp = getHumanoidAndHRP()
        if not hrp then continue end
        for model, data in pairs(_G.ESPManager.Objects) do
            if data.type == "Sukkars" then
                local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
                if part then
                    local dist = (hrp.Position - part.Position).Magnitude
                    if dist <= 5 or dist > 1200 then
                        _G.ESPManager:Remove(model)
                    end
                else
                    _G.ESPManager:Remove(model)
                end
            end
        end
    end
end)

Tabs.Event:AddToggle("ESPSukkarsToggle", {
    Title = "ESP Sukkars",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Sukkars", state)
end)

local TargetNames = {"dumsek","toon dusek","umdum","dusek","doothsek"}
local ScanInterval = 0.5
local TeleportDelay = 0.25
local HeightSafe = 5
local IgnoreCenter = blockedCenter
local IgnoreRadius = blockedRadius

local autoTeleport = false
local visitedModels = {}
local currentTarget = nil

local function getModelCFrame(model)
    if not model or not model:IsDescendantOf(workspace) then return end
    local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if part then return part.CFrame end
    if model.GetPivot then
        local ok, pivot = pcall(function() return model:GetPivot() end)
        if ok then return pivot end
    end
end

local function isAutoValid(model)
    if not model or not model:IsDescendantOf(workspace) then return false end
    for _, name in ipairs(TargetNames) do
        if model.Name:lower() == name:lower() then
            local cf = getModelCFrame(model)
            if cf then
                return (cf.Position - IgnoreCenter).Magnitude > IgnoreRadius
            end
        end
    end
    return false
end

local function findTargets()
    local list = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and isAutoValid(obj) then
            table.insert(list, obj)
        end
    end
    return list
end

local function isTouchingTarget(target)
    local _, hrp = getHumanoidAndHRP()
    if not hrp or not target then return false end
    local targetPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    if not targetPart then return false end
    return (hrp.Position - targetPart.Position).Magnitude <= 6
end

local function teleportToNext()
    local _, hrp = getHumanoidAndHRP()
    if not hrp then return end

    -- clean visited
    for m in pairs(visitedModels) do
        if not m:IsDescendantOf(workspace) then
            visitedModels[m] = nil
        end
    end

    local allTargets = findTargets()
    local available = {}
    for _, m in ipairs(allTargets) do
        if not visitedModels[m] then table.insert(available, m) end
    end

    if #available == 0 then
        table.clear(visitedModels)
        return
    end

    table.sort(available, function(a,b)
        return (hrp.Position - getModelCFrame(a).Position).Magnitude < (hrp.Position - getModelCFrame(b).Position).Magnitude
    end)

    currentTarget = available[1]
    if currentTarget then
        local cf = getModelCFrame(currentTarget)
        if cf then
            local pos = cf.Position
            if pos.Y < -10 then pos = Vector3.new(pos.X, HeightSafe, pos.Z) end
            hrp.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
        end
    end
end

task.spawn(function()
    while task.wait(ScanInterval) do
        if autoTeleport and LocalPlayer.Character then
            if currentTarget and not currentTarget:IsDescendantOf(workspace) then
                currentTarget = nil
                task.wait(TeleportDelay)
                teleportToNext()
            elseif currentTarget and isTouchingTarget(currentTarget) then
                visitedModels[currentTarget] = true
                task.wait(TeleportDelay)
                teleportToNext()
            elseif not currentTarget then
                teleportToNext()
            end
        end
    end
end)

Tabs.Event:AddToggle("AutoFarmSukkars", {
    Title = "Auto Farm Sukkars",
    Default = false,
    Callback = function(state)
        autoTeleport = state
        if not state then
            currentTarget = nil
            table.clear(visitedModels)
        end
    end,
})


-- Tabs.Custom

local HttpService = game:GetService("HttpService")
local SaveFile = "TuTienData.json"

local Levels = {
    {name = "Phàm Nhân", time = 0, hasStage = false},
    {name = "Kết Đan", time = 10800, hasStage = true},
    {name = "Luyện Khí", time = 21600, hasStage = true},
    {name = "Trúc Cơ", time = 32400, hasStage = true},
    {name = "Kim Đan", time = 43200, hasStage = true},
    {name = "Nguyên Anh", time = 54000, hasStage = true},
    {name = "Hóa Thần", time = 64800, hasStage = true},
    {name = "Luyện Hư", time = 75600, hasStage = true},
    {name = "Hợp Thể", time = 86400, hasStage = true},
    {name = "Đại Thừa", time = 97200, hasStage = true},
    {name = "Độ Kiếp", time = 108000, hasStage = true},
    {name = "Thánh Cảnh", time = 118800, hasStage = true},
    {name = "Thánh Vương", time = 129600, hasStage = true},
    {name = "Chí Tôn", time = 140400, hasStage = true},
    {name = "Chuẩn Đế", time = 151200, hasStage = true},
    {name = "Đại Đế", time = 162000, hasStage = true},
}

local Stages = {
    "Nhất Giai",
    "Nhị Giai",
    "Tam Giai",
    "Tứ Giai",
    "Ngũ Giai",
    "Lục Giai",
    "Thất Giai",
    "Bát Giai",
    "Cửu Giai"
}

local function LoadData()
    if isfile and isfile(SaveFile) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(SaveFile))
        end)
        if success and decoded then return decoded end
    end
    return {totalTime = 0}
end

local function SaveData(data)
    if writefile then
        writefile(SaveFile, HttpService:JSONEncode(data))
    end
end

local function GetProgress(totalTime)
    for i = #Levels, 1, -1 do
        if totalTime >= Levels[i].time then
            local current = Levels[i]
            local nextLevel = Levels[i + 1]

            if not nextLevel then
                return current.name, (current.hasStage and "Cửu Giai" or nil), 1, 1
            end

            local levelDuration = 10800 -- 3h
            local elapsedInLevel = totalTime - current.time
            local percent = math.clamp(elapsedInLevel / levelDuration, 0, 1)

            local stageName, breakthroughPercent
            if current.hasStage then
                local elapsedInStage = elapsedInLevel % 1200
                local stageIndex = math.clamp(math.floor(elapsedInLevel / 1200) + 1, 1, #Stages)
                stageName = Stages[stageIndex]
                breakthroughPercent = math.clamp(elapsedInStage / 1200, 0, 1)
            else
                breakthroughPercent = 0
            end

            return current.name, stageName, percent, breakthroughPercent
        end
    end
    return "Phàm Nhân", nil, 0, 0
end

local Data = LoadData()

local Paragraph = Tabs.Custom:AddParagraph({
    Title = "Thông Tin",
    Content = "Đang khởi động..."
})

task.spawn(function()
    while task.wait(1) do
        Data.totalTime += 1
        local level, stage, percent, breakP = GetProgress(Data.totalTime)

        local content = string.format("Tu Vi: %s\n", level)
        if stage then
            content ..= string.format("Tầng: %s\n", stage)
        end
        content ..= string.format("Linh Khí: %.1f%%\n", percent * 100)

        if stage then
            content ..= string.format("Đột Phá: %.1f%%", breakP * 100)
        end

        Paragraph:SetDesc(content)

        if Data.totalTime % 10 == 0 then
            SaveData(Data)
        end

        if level == "Đại Đế" and percent >= 1 then
            Paragraph:SetDesc("Tu Vi: Đại Đế\nTầng: Cửu Giai\nLinh Khí: 100%\nĐột Phá: 100%")
            break
        end
    end
end)


    Tabs.Custom:AddSection("↳ Animation")

do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local player = Players.LocalPlayer

    local sprintModule
    pcall(function()
        sprintModule = require(ReplicatedStorage:WaitForChild("Systems").Character.Game.Sprinting)
    end)

    local KillersData = {
        ["Survivors"] = {
            ["Default"] = {
                Idle = "rbxassetid://134624270247120",
                Walk = "rbxassetid://132377038617766",
                Run  = "rbxassetid://115946474977409",
            }
        },
        ["Shasher"] = {
            ["Default"] = {
                Idle = "rbxassetid://116050994905421",
                Walk = "rbxassetid://93622022596108",
                Run  = "rbxassetid://93054787145505",
            },
            ["Pursuer"] = {
                Idle = "rbxassetid://94895464960972",
                Walk = "rbxassetid://100206079439305",
                Run  = "rbxassetid://138660433982140",
            },
            ["subject_0"] = {
                Idle = "rbxassetid://14301056458",
                Walk = "rbxassetid://122325883800612",
                Run  = "rbxassetid://97248175252805",
            }
        },
        ["Coolkidd"] = {
            ["Default"] = {
                Idle = "rbxassetid://18885903667",
                Walk = "rbxassetid://18885906143",
                Run  = "rbxassetid://96571077893813",
            }
        },
        ["John Doe"] = {
            ["Default"] = {
                Idle = "rbxassetid://105880087711722",
                Walk = "rbxassetid://81193817424328",
                Run  = "rbxassetid://132653655520682",
            },
            ["Shadow"] = {
                Idle = "rbxassetid://00000000001",
                Walk = "rbxassetid://00000000002",
                Run  = "rbxassetid://00000000003",
            }
        },
        ["Noli"] = {
            ["Default"] = {
                Idle = "rbxassetid://93841120533318",
                Walk = "rbxassetid://109700476007435",
                Run  = "rbxassetid://117451341682452",
            }
        },
        ["1x1x1x1"] = {
            ["Default"] = {
                Idle = "rbxassetid://138754221537146",
                Walk = "rbxassetid://131235528875091",
                Run  = "rbxassetid://106485518413331",
            },
            ["Hacklord [Old]"] = {
                Idle = "rbxassetid://82241652784826",
                Walk = "rbxassetid://119242164490314",
                Run  = "rbxassetid://92430101129682",
            },
            ["Hacklord [New]"] = {
                Idle = "rbxassetid://106131211773069",
                Walk = "rbxassetid://119112338263474",
                Run  = "rbxassetid://85339002634979",
            }
        },
        ["Herobrine"] = {
            ["Default"] = {
                Idle = "rbxassetid://107799240559806",
                Walk = "rbxassetid://89380107485006",
                Run  = "rbxassetid://134157363854022",
            }
        },
        ["Gubby"] = {
            ["Default"] = {
                Idle = "rbxassetid://88333702239259",
                Walk = "rbxassetid://115244584291581",
                Run  = "rbxassetid://115244584291581",
            }
        },
        ["Sancho"] = {
            ["Default"] = {
                Idle = "rbxassetid://115073581864188",
                Walk = "rbxassetid://95213748170889",
                Run  = "rbxassetid://75409814098993",
            }
        },
        ["Erlking"] = {
            ["Default"] = {
                Idle = "rbxassetid://93727662665079",
                Walk = "rbxassetid://97625643261790",
                Run  = "rbxassetid://119357938208454",
            }
        },
        ["Sukuna"] = {
            ["Default"] = {
                Idle = "rbxassetid://115268929362938",
                Walk = "rbxassetid://123678890237669",
                Run  = "rbxassetid://132086389849889",
                Music = "rbxassetid://73595818073606"
            }
        }
    }

    local enabled = false
    local selectedKiller = "Shasher"
    local selectedSkin = "Default"
    local character, humanoid, animator
    local idleAnim, walkAnim, runAnim
    local idleTrack, walkTrack, runTrack
    local _isSprinting = false
    local musicSound

    local runningConn, heartbeatConn, characterRemovingConn, inputBeganConn, inputEndedConn = nil, nil, nil, nil, nil
    local heartbeatAccumulator = 0
    local HEARTBEAT_CHECK_INTERVAL = 0.12

    local function stopAndClearTracks()
        for _, track in ipairs({idleTrack, walkTrack, runTrack}) do
            if track then pcall(function() track:Stop() end) end
        end
        idleTrack, walkTrack, runTrack = nil, nil, nil
    end

    local function stopMusic()
        if musicSound then
            pcall(function()
                musicSound:Stop()
                musicSound:Destroy()
            end)
            musicSound = nil
        end
    end

    local function playMusicIfSukuna(set)
        stopMusic()
        if selectedKiller == "Sukuna" and set and set.Music then
            local sound = Instance.new("Sound")
            sound.SoundId = set.Music
            sound.Looped = true
            sound.Volume = 2
            sound.Parent = workspace
            sound:Play()
            musicSound = sound
        end
    end

    local function disconnectListeners()
        for _, c in ipairs({runningConn, heartbeatConn, characterRemovingConn, inputBeganConn, inputEndedConn}) do
            if c then pcall(function() c:Disconnect() end) end
        end
        runningConn, heartbeatConn, characterRemovingConn, inputBeganConn, inputEndedConn = nil, nil, nil, nil, nil
    end

    local function cleanupCurrentCharacter()
        stopAndClearTracks()
        stopMusic()
        disconnectListeners()
        animator, humanoid, character = nil, nil, nil
    end

    local function loadAnimObjects(killer, skin)
        local killerTable = KillersData[killer]
        if not killerTable then
            warn("loadAnimObjects: killer không tồn tại:", tostring(killer))
            return
        end
        local set = killerTable[skin or "Default"] or killerTable["Default"]
        if not set then return end

        idleAnim, walkAnim, runAnim = Instance.new("Animation"), Instance.new("Animation"), Instance.new("Animation")
        idleAnim.Name, walkAnim.Name, runAnim.Name = "IdleAnim", "WalkAnim", "RunAnim"
        idleAnim.AnimationId, walkAnim.AnimationId, runAnim.AnimationId = set.Idle, set.Walk, set.Run

        playMusicIfSukuna(set)
    end

    local function playAnim(animObj, trackType)
        if not animator then return end

        if trackType ~= "Idle" and idleTrack then pcall(function() idleTrack:Stop() end) idleTrack=nil end
        if trackType ~= "Walk" and walkTrack then pcall(function() walkTrack:Stop() end) walkTrack=nil end
        if trackType ~= "Run" and runTrack then pcall(function() runTrack:Stop() end) runTrack=nil end

        local track
        if trackType=="Idle" and not idleTrack then idleTrack = animator:LoadAnimation(idleAnim) track=idleTrack
        elseif trackType=="Walk" and not walkTrack then walkTrack = animator:LoadAnimation(walkAnim) track=walkTrack
        elseif trackType=="Run" and not runTrack then runTrack = animator:LoadAnimation(runAnim) track=runTrack
        else track = (trackType=="Idle" and idleTrack) or (trackType=="Walk" and walkTrack) or runTrack end

        if track and not track.IsPlaying then pcall(function() track:Play() end) end
    end

    local function playIdle() playAnim(idleAnim,"Idle") end
    local function playWalk() playAnim(walkAnim,"Walk") end
    local function playRun() playAnim(runAnim,"Run") end

    local function updateMovementState()
        if not enabled or not character then return end
        local moving=false
        if humanoid and humanoid.MoveDirection then
            moving = humanoid.MoveDirection.Magnitude>0
            if not moving then
                local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
                if root and root.Velocity.Magnitude>1 then moving=true end
            end
        end
        if moving then
            local sprintingNow = (sprintModule and sprintModule.IsSprinting) or _isSprinting
            if sprintingNow then playRun() else playWalk() end
        else
            playIdle()
        end
    end

    local function setupMovementListeners()
        disconnectListeners()
        inputBeganConn = UserInputService.InputBegan:Connect(function(input,gp) if gp then return end if input.KeyCode==Enum.KeyCode.LeftShift then _isSprinting=true end end)
        inputEndedConn = UserInputService.InputEnded:Connect(function(input,gp) if gp then return end if input.KeyCode==Enum.KeyCode.LeftShift then _isSprinting=false end end)

        if humanoid and humanoid.Running then
            runningConn = humanoid.Running:Connect(function(speed) if not enabled then return end if speed>0 then updateMovementState() else playIdle() end end)
        else
            heartbeatAccumulator=0
            heartbeatConn = RunService.Heartbeat:Connect(function(dt)
                if not enabled or not character then return end
                heartbeatAccumulator+=dt
                if heartbeatAccumulator>=HEARTBEAT_CHECK_INTERVAL then
                    heartbeatAccumulator=0
                    updateMovementState()
                end
            end)
        end
    end

    local function onCharacterBound(char)
        cleanupCurrentCharacter()
        character=char
        humanoid=char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("AnimationController")
        if humanoid then
            animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
        end
        characterRemovingConn = char.AncestryChanged:Connect(function(_,parent) if not parent then cleanupCurrentCharacter() end end)
        if enabled then
            loadAnimObjects(selectedKiller, selectedSkin)
            setupMovementListeners()
            updateMovementState()
        end
    end

    player.CharacterAdded:Connect(onCharacterBound)
    if player.Character then onCharacterBound(player.Character) end

    local killerNames = {}
    for name,_ in pairs(KillersData) do table.insert(killerNames, name) end
    table.sort(killerNames)

    local SkinDropdown -- khai báo trước

    local killerDropdown = Tabs.Custom:AddDropdown("ChooseKillersDropdown", {
        Title = "Choose Killers",
        Values = killerNames,
        Default = selectedKiller,
        Multi = false,
        Callback = function(value)
            local ok, err = pcall(function()
                selectedKiller = value
                selectedSkin = "Default"

                local skins = {}
                local t = KillersData[selectedKiller] or {}
                for sName,_ in pairs(t) do table.insert(skins, sName) end
                if #skins == 0 then skins = {"Default"} end
                table.sort(skins)

                if SkinDropdown and type(SkinDropdown.SetValues)=="function" and type(SkinDropdown.SetValue)=="function" then
                    SkinDropdown:SetValues(skins)
                    pcall(function() SkinDropdown:SetValue(skins[1] or "Default") end)
                end

                if enabled and player.Character then
                    loadAnimObjects(selectedKiller, selectedSkin)
                    stopAndClearTracks()
                    updateMovementState()
                else
                    stopMusic()
                end
            end)
            if not ok then warn("ChooseKillersDropdown callback error:", err) end
        end
    })

    SkinDropdown = Tabs.Custom:AddDropdown("ChooseSkinDropdown", {
        Title = "Choose Skin",
        Values = {"Default"},
        Default = "Default",
        Multi = false,
        Callback = function(value)
            local ok, err = pcall(function()
                selectedSkin = value
                if enabled and player.Character then
                    loadAnimObjects(selectedKiller, selectedSkin)
                    stopAndClearTracks()
                    updateMovementState()
                else
                    stopMusic()
                end
            end)
            if not ok then warn("SkinDropdown callback error:", err) end
        end
    })

    Tabs.Custom:AddToggle("FakeKillersToggle", {
        Title = "Fake Killers",
        Default = false,
        Callback = function(state)
            local ok, err = pcall(function()
                enabled = state
                if enabled then
                    if player.Character then
                        loadAnimObjects(selectedKiller, selectedSkin)
                        onCharacterBound(player.Character)
                    end
                else
                    stopAndClearTracks()
                    disconnectListeners()
                    stopMusic()
                end
            end)
            if not ok then warn("FakeKillersToggle callback error:", err) end
        end
    })
end



    Tabs.Custom:AddSection("↳ Skill")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BUTTON_SIZE = 48
local FramesLocked = true
local createdFrames = {}

local function makeDraggable(frame)
    local dragging, dragStart, startPos

    frame.InputBegan:Connect(function(input)
        if not FramesLocked and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and not FramesLocked and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local function createGui(name)
    local g = Instance.new("ScreenGui")
    g.Name = name
    g.Enabled = false
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.Parent = playerGui
    return g
end

local function createButton(gui, data, pos)
    local frame = Instance.new("Frame")
    frame.Name = data.Name .. "_Frame"
    frame.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
    frame.Position = pos
    frame.BackgroundTransparency = 1
    frame.Parent = gui
    frame.Active = true

    Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("ImageButton")
    btn.Name = data.Name
    btn.Image = "rbxassetid://" .. data.ImageId
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.ScaleType = Enum.ScaleType.Fit
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    btn.MouseButton1Click:Connect(function()
        if not FramesLocked then return end

        local char = player.Character or player.CharacterAdded:Wait()
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. data.AnimationId
        animator:LoadAnimation(anim):Play()

        if data.PlayMusic and data.MusicId then
            local s = Instance.new("Sound")
            s.SoundId = "rbxassetid://" .. data.MusicId
            s.Parent = char:FindFirstChild("Head") or playerGui
            s.Volume = 1
            s:Play()
            s.Ended:Connect(function() s:Destroy() end)
        end
    end)

    makeDraggable(frame)

    btn.Visible = FramesLocked
    frame.BackgroundTransparency = FramesLocked and 1 or 0.3

    table.insert(createdFrames, frame)
end

local function loadButtonGroup(config)
    local gui = createGui(config.GuiName)

    for i, d in ipairs(config.Buttons) do
        createButton(gui, d, config.Positions[i])
    end

    Tabs.Custom:AddToggle(config.ToggleName, {
        Title = config.DisplayName,
        Default = false
    }):OnChanged(function(v)
        gui.Enabled = v
    end)

    Tabs.Custom:AddToggle(config.LockToggle, {
        Title = "Lock Buttons",
        Default = true
    }):OnChanged(function(v)
        FramesLocked = v
        for _, frame in ipairs(createdFrames) do
            local b = frame:FindFirstChildOfClass("ImageButton")
            if b then b.Visible = v end
            frame.BackgroundTransparency = v and 1 or 0.3
        end
    end)

    Tabs.Custom:AddInput(config.SizeInput, {
        Title = "Button Size",
        Default = tostring(BUTTON_SIZE),
        Numeric = true,
        Finished = true
    }):OnChanged(function(value)
        local num = tonumber(value)
        if num and num > 0 then
            BUTTON_SIZE = num
            for _, frame in ipairs(createdFrames) do
                frame.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
                local btn = frame:FindFirstChildOfClass("ImageButton")
                if btn then btn.Size = UDim2.new(1, 0, 1, 0) end
            end
        end
    end)
end

loadButtonGroup({
    GuiName = "SukunaGUI",
    ToggleName = "SukunaSkill",
    DisplayName = "Sukuna Skill",
    LockToggle = "SukunaLock",
    SizeInput = "SukunaSize",

    Buttons = {
        {Name="Btn1", AnimationId="135853087227453", PlayMusic=true, MusicId="81361259756089", ImageId="134210378382767"},
        {Name="Btn2", AnimationId="99784586201997",  PlayMusic=false, ImageId="134210378382767"},
        {Name="Btn3", AnimationId="121162477402224", PlayMusic=true, MusicId="120185817748858", ImageId="85785826985052"},
        {Name="Btn4", AnimationId="101816924844805", PlayMusic=true, MusicId="88406027536494", ImageId="85785826985052"}
    },

    Positions = {
        UDim2.new(0,80,0,200),
        UDim2.new(0,140,0,200),
        UDim2.new(0,200,0,200),
        UDim2.new(0,260,0,200),
    }
})


loadButtonGroup({
    GuiName = "Guest1337GUI",
    ToggleName = "GuestSkill",
    DisplayName = "Guest1337 Skill",
    LockToggle = "Guest1337Lock",
    SizeInput = "Guest1337Size",

    Buttons = {
        {Name="Btn1", AnimationId="72722244508749", PlayMusic=false, ImageId="87293861183080"},
        {Name="Btn2", AnimationId="96959123077498", PlayMusic=false, ImageId="87293861183080"},
        {Name="Btn3", AnimationId="87259391926321", PlayMusic=false, ImageId="87293861183080"}
    },

    Positions = {
        UDim2.new(0,80,0,200),
        UDim2.new(0,140,0,200),
        UDim2.new(0,200,0,200),
    }
})


-- Tabs.Player


local ActiveNoStun = false
local noStunLoop

Tabs.Player:AddToggle("NoStunToggle", {
    Title = "No Stun",
    Default = false,
}):OnChanged(function(value)
    ActiveNoStun = value

    if value then
        if noStunLoop then
            task.cancel(noStunLoop)
            noStunLoop = nil
        end

        noStunLoop = task.spawn(function()
            while ActiveNoStun do
                local character = game.Players.LocalPlayer.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Anchored = false
                end
                task.wait(0.1)
            end
        end)
    else

        if noStunLoop then
            task.cancel(noStunLoop)
            noStunLoop = nil
        end
    end
end)






local InfStaminaEnabled = false  
local staminaLoop  
local StaminaModule  
pcall(function()  
    local ReplicatedStorage = game:GetService("ReplicatedStorage")  
    local path = ReplicatedStorage:FindFirstChild("Systems")  
        and ReplicatedStorage.Systems:FindFirstChild("Character")  
        and ReplicatedStorage.Systems.Character:FindFirstChild("Game")  
        and ReplicatedStorage.Systems.Character.Game:FindFirstChild("Sprinting")  
    if path then  
        StaminaModule = require(path)  
    end  
end)  
-- Hàm hồi stamina an toàn  
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
    Tabs.Player:AddToggle("InfStamina", {  
        Title = "Infinite Stamina",  
        Default = false  
    }):OnChanged(function(value)
        local ok = pcall(function()  
            InfStaminaEnabled = value  
            if StaminaModule.StaminaLossDisabled ~= nil then  
                StaminaModule.StaminaLossDisabled = value  
            end  
            if value then  
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
            end  
        end)  
    end)  
else  
    warn("[InfStamina] Sprinting module not found, toggle disabled.")  
end




Tabs.Player:AddToggle("InfiniteZoom", {
    Title = "Infinite Zoom",
    Default = false,
    Callback = function(Value)
        local player = game.Players.LocalPlayer
        local camera = workspace.CurrentCamera

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



    Tabs.Player:AddSection("↳ Troller")

do
local function doBackflip()
    local plr = game.Players.LocalPlayer
    local char = plr and plr.Character
    if not char then return end

    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not (hum and hrp) then return end

    if char:FindFirstChild("Animate") then
        char.Animate.Disabled = true
    end

    if animator then
        for _, v in ipairs(animator:GetPlayingAnimationTracks()) do
            v:Stop()
        end
    end

    for _, s in ipairs({
        Enum.HumanoidStateType.FallingDown,
        Enum.HumanoidStateType.Freefall,
        Enum.HumanoidStateType.Running,
        Enum.HumanoidStateType.Seated,
        Enum.HumanoidStateType.Climbing
    }) do
        hum:SetStateEnabled(s, false)
    end
    hum:ChangeState(Enum.HumanoidStateType.Physics)

    local d, s = 0.45, 120
    local cf = hrp.CFrame
    local dir = cf.LookVector
    local up = Vector3.yAxis

    task.spawn(function()
        local t0 = tick()
        for i = 1, s do
            local t = i / s
            local y = 4 * (t - t ^ 2) * 10
            local targetPos = cf.Position + dir * (35 * t) + up * y
            local r = CFrame.Angles(math.rad(360 * t), 0, 0)

            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {char}
            rayParams.FilterType = Enum.RaycastFilterType.Blacklist

            local result = workspace:Raycast(hrp.Position, (targetPos - hrp.Position), rayParams)

            if result then
                targetPos = result.Position + result.Normal * 2
            end

            char:PivotTo(CFrame.new(targetPos) * cf.Rotation * r)

            local wt = (d / s) * i - (tick() - t0)
            if wt > 0 then task.wait(wt) end
        end

        local finalTarget = cf.Position + dir * 35
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {char}
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        local result = workspace:Raycast(hrp.Position, (finalTarget - hrp.Position), rayParams)
        if result then
            finalTarget = result.Position + result.Normal * 2
        end

        char:PivotTo(CFrame.new(finalTarget) * cf.Rotation)

        for _, s in ipairs({
            Enum.HumanoidStateType.FallingDown,
            Enum.HumanoidStateType.Freefall,
            Enum.HumanoidStateType.Running,
            Enum.HumanoidStateType.Seated,
            Enum.HumanoidStateType.Climbing
        }) do
            hum:SetStateEnabled(s, true)
        end
        hum:ChangeState(Enum.HumanoidStateType.Running)
        char.Animate.Disabled = false
    end)
end

Tabs.Player:AddButton({
    Title = "Backflip",
    Callback = doBackflip
})

local autoFlip = false
Tabs.Player:AddToggle("AutoBackflip", {
    Title = "Auto Backflip",
    Default = false,
    Callback = function(Value)
        autoFlip = Value
        if autoFlip then
            task.spawn(function()
                while autoFlip do
                    doBackflip()
                    task.wait(1.25)
                end
            end)
        end
    end
})
end







do
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer

    local fakeFixAnim = Instance.new("Animation")
    fakeFixAnim.AnimationId = "rbxassetid://82691533602949"

    local animator, fakeFixTrack

    local function getAnimator()
        local char = player.Character
        if not char then return nil end
        local humanoid = char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("AnimationController")
        if not humanoid then return nil end
        local anim = humanoid:FindFirstChildOfClass("Animator")
        if not anim then
            anim = Instance.new("Animator")
            anim.Parent = humanoid
        end
        return anim
    end

    Tabs.Player:AddToggle("FakeFixGen", {
        Title = "Fake Fix Gen",
        Default = false,
        Callback = function(state)
            animator = getAnimator()
            if not animator then return end

            if state then
                if not fakeFixTrack then
                    local ok, track = pcall(function()
                        return animator:LoadAnimation(fakeFixAnim)
                    end)
                    if ok and track then
                        fakeFixTrack = track
                        fakeFixTrack.Looped = true
                        fakeFixTrack:Play()
                    end
                end
            else
                if fakeFixTrack then
                    fakeFixTrack:Stop()
                    fakeFixTrack = nil
                end
            end
        end
    })
end




do
Tabs.Player:AddToggle("FakeDieV2", {
    Title = "Fake Die V2",
    Default = false
}):OnChanged(function(state)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")

    local plr = Players.LocalPlayer
    local char = plr.Character or plr.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")

    if not getgenv().FakeDieData then
        getgenv().FakeDieData = {track=nil, conn=nil}
    end

    if state then

        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://118795597134269"

        local track = hum:LoadAnimation(anim)
        track:Play()

        if track.Length > 0 then
            track.TimePosition = track.Length * 0.5
        end

        getgenv().FakeDieData.track = track

        local stopped = false
        local conn = RunService.Heartbeat:Connect(function()
            if track.IsPlaying and not stopped and track.Length > 0 then
                local percent = track.TimePosition / track.Length
                if percent >= 0.9 then
                    track:AdjustSpeed(0) -- pause ở 90%
                    stopped = true
                    print("FakeDie: Animation paused at 90%")
                end
            end
        end)

        getgenv().FakeDieData.conn = conn
    else
        local data = getgenv().FakeDieData
        if data.track then
            data.track:Stop()
            data.track = nil
        end
        if data.conn then
            data.conn:Disconnect()
            data.conn = nil
        end

        pcall(function()
            hum:PlayEmote("idle")
        end)
    end
end)
end





    Tabs.Player:AddSection("↳ Hitbox")


repeat task.wait() until game:IsLoaded()

local ForsakenReachEnabled = false
local NearestDist = 120

Tabs.Player:AddToggle("ForsakenReachToggle", {
    Title = "Hitbox Devil",
    Default = false,
    Save = true
}):OnChanged(function(Value)
    ForsakenReachEnabled = Value
end)

Tabs.Player:AddSlider("ForsakenReachSlider", {
    Title = "Distance",
    Default = 120,
    Min = 10,
    Max = 300,
    Rounding = 0,
    Save = true,
    Suffix = " studs"
}):OnChanged(function(Value)
    NearestDist = Value
end)

local Players = game:GetService('Players')
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

Player.CharacterAdded:Connect(function(NewCharacter)
    Character = NewCharacter
    Humanoid = Character:WaitForChild("Humanoid")
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
end)

local RNG = Random.new()

local AttackAnimations = {
    'rbxassetid://131430497821198',
    'rbxassetid://83829782357897',
    'rbxassetid://126830014841198',
    'rbxassetid://126355327951215',
    'rbxassetid://121086746534252',
    'rbxassetid://105458270463374',
    'rbxassetid://127172483138092',
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
    'rbxassetid://84426150435898',
    'rbxassetid://93069721274110',
    'rbxassetid://114620047310688',
    'rbxassetid://97433060861952',
    'rbxassetid://82183356141401',
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

local Killers = {
    ["Slasher"] = true, ["1x1x1x1"] = true, ["c00lkidd"] = true,
    ["Noli"] = true, ["JohnDoe"] = true, ["Guest 666"] = true,
    ["Sixer"] = true
}

local Survivors = {
    ["Noob"] = true, ["Guest1337"] = true, ["Elliot"] = true,
    ["Shedletsky"] = true, ["TwoTime"] = true, ["007n7"] = true,
    ["Chance"] = true, ["Builderman"] = true, ["Taph"] = true,
    ["Dusekkar"] = true, ["Veeronica"] = true
}

local function ForsakenReachLogic()
    if not ForsakenReachEnabled or not HumanoidRootPart then
        return
    end

    local Playing = false
    for _,v in Humanoid:GetPlayingAnimationTracks() do
        if table.find(AttackAnimations, v.Animation.AnimationId) and (v.TimePosition / v.Length < 0.75) then
            Playing = true
        end
    end

    if not Playing then
        return
    end

    local PlayerRole = nil -- "Killer" | "Survivor" | nil
    local myModelName = Character and Character.Name
    if myModelName and Killers[myModelName] then
        PlayerRole = "Killer"
    elseif myModelName and Survivors[myModelName] then
        PlayerRole = "Survivor"
    end

    local OppositeTable = nil
    if PlayerRole == "Killer" then
        OppositeTable = Survivors
    elseif PlayerRole == "Survivor" then
        OppositeTable = Killers
    end

    local Target = nil
    local CurrentNearestDist = NearestDist

    local OppTarget = nil
    local OppNearestDist = NearestDist

    local function loopForOpp(t)
        for _,v in pairs(t) do
            if v == Character or not v:FindFirstChild("HumanoidRootPart") or not v:FindFirstChild("Humanoid") then
                continue
            end
            local modelName = v.Name
            if OppositeTable and OppositeTable[modelName] then
                local Dist = (v.HumanoidRootPart.Position - HumanoidRootPart.Position).Magnitude
                if Dist < OppNearestDist then
                    OppNearestDist = Dist
                    OppTarget = v
                end
            end
        end
    end

    if OppositeTable then
        loopForOpp(workspace.Players:GetDescendants())
        local npcsFolder = workspace.Map:FindFirstChild("NPCs", true)
        if npcsFolder then
            loopForOpp(npcsFolder:GetChildren())
        end
    end
    local function loopAll(t)
        for _,v in pairs(t) do
            if v == Character or not v:FindFirstChild("HumanoidRootPart") or not v:FindFirstChild("Humanoid") then
                continue
            end
            local modelName = v.Name
            if PlayerRole == "Killer" and Killers[modelName] then
                continue
            end
            if PlayerRole == "Survivor" and Survivors[modelName] then
                continue
            end
            local Dist = (v.HumanoidRootPart.Position - HumanoidRootPart.Position).Magnitude
            if Dist < CurrentNearestDist then
                CurrentNearestDist = Dist
                Target = v
            end
        end
    end

    local FinalTarget = nil
    if OppTarget then
        FinalTarget = OppTarget
    else
        loopAll(workspace.Players:GetDescendants())
        local npcsFolder2 = workspace.Map:FindFirstChild("NPCs", true)
        if npcsFolder2 then
            loopAll(npcsFolder2:GetChildren())
        end
        FinalTarget = Target
    end

    if not FinalTarget then
        return
    end

    local OldVelocity = HumanoidRootPart.Velocity
    local NeededVelocity =
        (FinalTarget.HumanoidRootPart.Position + Vector3.new(
            RNG:NextNumber(-1.5, 1.5),
            0,
            RNG:NextNumber(-1.5, 1.5)
        ) + (FinalTarget.HumanoidRootPart.Velocity * (Player:GetNetworkPing() * 1.25))
            - HumanoidRootPart.Position
        ) / (Player:GetNetworkPing() * 2)

    HumanoidRootPart.Velocity = NeededVelocity
    game:GetService('RunService').RenderStepped:Wait()
    HumanoidRootPart.Velocity = OldVelocity
end

task.spawn(function()
    while true do
        task.wait(0)
        pcall(ForsakenReachLogic)
    end
end)



local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
local HRP = Character:FindFirstChild("HumanoidRootPart")

local function onCharacterAdded(char)
    Character = char
    Humanoid = Character:WaitForChild("Humanoid")
    HRP = Character:WaitForChild("HumanoidRootPart")
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

local WalkSpeed = {
    Value = 16,
    Active = false,
    Loop = nil
}

local function setWalkSpeed(speed)
    if Humanoid then
        Humanoid.WalkSpeed = speed
        Humanoid:SetAttribute("BaseSpeed", speed)
    end
end

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
        setWalkSpeed(WalkSpeed.Value)
    end
end)

Tabs.Player:AddToggle("PlayerSpeedToggle", {
    Title = "Walk Speed",
    Default = false,
}):OnChanged(function(enabled)
    WalkSpeed.Active = enabled
    if enabled then
        setWalkSpeed(WalkSpeed.Value)
        WalkSpeed.Loop = task.spawn(function()
            while WalkSpeed.Active do
                setWalkSpeed(WalkSpeed.Value)
                task.wait(0.5)
            end
        end)
    else
        WalkSpeed.Loop = nil
        setWalkSpeed(16) -- reset speed
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.1)
    if WalkSpeed.Active then
        setWalkSpeed(WalkSpeed.Value)
    end
end)

local TeleportSpeed = {
    Value = 50,
    Max = 300,
    Active = false
}

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
    if TeleportSpeed.Active and Humanoid and HRP then
        if Humanoid.MoveDirection.Magnitude > 0 then
            HRP.CFrame = HRP.CFrame + Humanoid.MoveDirection.Unit * (TeleportSpeed.Value * dt)
        end
    end
end)


     

-- Tabs.Visual

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer


local allowedModelsClone = {
    ["1x1x1x1Zombie"] = true,
    ["PizzaDeliveryRig"] = true,
    ["Mafia1"] = true,
    ["Mafia2"] = true,
    ["Mafia3"] = true,
    ["Mafia4"] = true,
}

_G.ESPManager:RegisterType("Clone", Color3.fromRGB(0, 255, 0), function(obj)
    return obj:IsA("Model") and allowedModelsClone[obj.Name]
end, false)

Tabs.Visual:AddToggle("ESPCloneToggle", {
    Title = "ESP Clone",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Clone", state)
end)


    Tabs.Visual:AddSection("↳ Player")

_G.ESPManager:RegisterType("Player", Color3.fromRGB(0, 255, 255), function(obj)
    local plr = Players:GetPlayerFromCharacter(obj)
    return plr and plr ~= LocalPlayer
end, false)

Tabs.Visual:AddToggle("ESPPlayerToggle", {
    Title = "ESP Player",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Player", state)
end)



local survivorsFolder = workspace:WaitForChild("Players"):WaitForChild("Survivors")
_G.ESPManager:RegisterType("Survivor", Color3.fromRGB(255, 255, 255), function(obj)
    return obj:IsA("Model") and obj.Parent == survivorsFolder and obj:FindFirstChildOfClass("Humanoid")
end, true)

Tabs.Visual:AddToggle("ESPModelWhiteToggle", {
    Title = "ESP Survivors",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Survivor", state)
end)



local killersFolder = workspace:WaitForChild("Players"):WaitForChild("Killers")
_G.ESPManager:RegisterType("Killer", Color3.fromRGB(255, 0, 0), function(obj)
    return obj:IsA("Model") and obj.Parent == killersFolder and obj:FindFirstChildOfClass("Humanoid")
end, true)

Tabs.Visual:AddToggle("ESPModelRedToggle", {
    Title = "ESP Killers",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Killer", state)
end)



    Tabs.Visual:AddSection("↳ Other")

_G.ESPManager:RegisterType("Generator", Color3.fromRGB(255,255,255), function(obj)
    if not (obj and obj:IsA("Model") and obj.Name == "Generator") then
        return false
    end

    local progress = obj:FindFirstChild("Progress", true)
    if not progress or not progress:IsA("NumberValue") then
        return false
    end

    if not progress:GetAttribute("ESP_Watch") then
        progress:SetAttribute("ESP_Watch", true)
        progress:GetPropertyChangedSignal("Value"):Connect(function()
            -- Nếu đạt 100% thì remove ESP ngay
            if progress.Value >= 100 then
                _G.ESPManager:Remove(obj)
            else
                -- Nếu ESP chưa có, tạo lại
                if not _G.ESPManager.Objects[obj] then
                    _G.ESPManager:_ScheduleCreate(obj, "Generator")
                end
            end
        end)
    end

    return progress.Value < 100
end, false)

Tabs.Visual:AddToggle("ESPGeneratorToggle", {
    Title = "ESP Generator",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Generator", state)
end)


_G.ESPManager:RegisterType("Item", Color3.fromRGB(255,215,0), function(obj)
    return obj:IsA("Tool") and obj.Parent and obj:IsDescendantOf(workspace:FindFirstChild("Map"))
end, false)

Tabs.Visual:AddToggle("ESPItemsToggle", {
    Title = "ESP Items",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Item", state)
end)


_G.ESPManager:RegisterType("Dispenser", Color3.fromRGB(0, 162, 255), function(obj)
    return obj:IsA("Model") and obj.Name:lower():find("dispenser")
end, false)

_G.ESPManager:RegisterType("Sentry", Color3.fromRGB(128, 128, 128), function(obj)
    return obj:IsA("Model") and obj.Name:lower():find("sentry")
end, false)

_G.ESPManager:RegisterType("Tripwire", Color3.fromRGB(255, 85, 0), function(obj)
    return obj:IsA("Model") and obj.Name:find("TaphTripwire")
end, false)

_G.ESPManager:RegisterType("Subspace", Color3.fromRGB(160, 32, 240), function(obj)
    return obj:IsA("Model") and obj.Name == "SubspaceTripmine"
end, false)

Tabs.Visual:AddSection("↳ Buildman")

Tabs.Visual:AddToggle("DispenserESP_Toggle", {
    Title = "ESP Dispenser",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Dispenser", state)
end)

Tabs.Visual:AddToggle("SentryESP_Toggle", {
    Title = "ESP Sentry",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Sentry", state)
end)

Tabs.Visual:AddSection("↳ Tapt/Trap")

Tabs.Visual:AddToggle("TripwireESP_Toggle", {
    Title = "ESP Trip Wire",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Tripwire", state)
end)

Tabs.Visual:AddToggle("SubspaceESP_Toggle", {
    Title = "ESP Bomb Trap",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Subspace", state)
end)

-- Tabs.Misc

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local fullBrightEnabled = false
local fullBrightLoop

local function applyFullBright()
    if not fullBrightEnabled then return end

    Lighting.Ambient = Color3.fromRGB(200, 200, 200) -- sáng nhẹ
    Lighting.Brightness = 4 -- giảm độ sáng từ 10 → 4
    Lighting.GlobalShadows = false
end

local function enableFullBright()
    if fullBrightLoop then fullBrightLoop:Disconnect() end
    applyFullBright()
    fullBrightLoop = Lighting:GetPropertyChangedSignal("ClockTime"):Connect(applyFullBright)
end

local function disableFullBright()
    if fullBrightLoop then
        fullBrightLoop:Disconnect()
        fullBrightLoop = nil
    end

    Lighting.Ambient = Color3.fromRGB(128, 128, 128)
    Lighting.Brightness = 1
    Lighting.GlobalShadows = true
end

local FbToggle = Tabs.Misc:AddToggle("FbToggle", {
    Title = "Auto Full Bright",
    Default = false
})
FbToggle:OnChanged(function(Value)
    fullBrightEnabled = Value
    if fullBrightEnabled then
        enableFullBright()
    else
        disableFullBright()
    end
end)

local fogEnabled = false
local fogLoop

local function removeFog()
    Lighting.FogStart = 0
    Lighting.FogEnd = 1000000

    local atmosphere = Lighting:FindFirstChild("Atmosphere")
    if atmosphere then
        atmosphere.Density = 0
        atmosphere.Offset = 0
        atmosphere.Haze = 0
        atmosphere.Color = Color3.new(1, 1, 1)
    end
end

local function restoreFog()
    Lighting.FogStart = 200
    Lighting.FogEnd = 1000

    local atmosphere = Lighting:FindFirstChild("Atmosphere")
    if atmosphere then
        atmosphere.Density = 0.3
        atmosphere.Offset = 0
        atmosphere.Haze = 0.5
        atmosphere.Color = Color3.fromRGB(200, 200, 200)
    end
end

local FogToggle = Tabs.Misc:AddToggle("FogToggle", {
    Title = "Remove Fog",
    Default = false
})
FogToggle:OnChanged(function(Value)
    fogEnabled = Value
    if fogEnabled then
        removeFog()
        fogLoop = RunService.Heartbeat:Connect(removeFog)
    else
        if fogLoop then fogLoop:Disconnect() fogLoop = nil end
        restoreFog()
    end
end)



local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local ActiveRemoveAll = false

local effectNames = {
    "BlurEffect", "ColorCorrectionEffect", "BloomEffect", "SunRaysEffect", 
    "DepthOfFieldEffect", "ScreenFlash", "HitEffect", "DamageOverlay", 
    "BloodEffect", "Vignette", "BlackScreen", "WhiteScreen", "ShockEffect",
    "Darkness", "JumpScare", "LowHealthOverlay", "Flashbang", "FadeEffect"
}

-- Danh sách class hiệu ứng trong Lighting
local effectClasses = {
    "BlurEffect",
    "BloomEffect",
    "SunRaysEffect",
    "DepthOfFieldEffect",
    "ColorCorrectionEffect"
}
local function removeAll()
    for _, obj in pairs(Lighting:GetDescendants()) do
        if table.find(effectNames, obj.Name) or table.find(effectClasses, obj.ClassName) then
            obj:Destroy()
        end
    end

    for _, obj in pairs(PlayerGui:GetDescendants()) do
        if table.find(effectNames, obj.Name) then
            obj:Destroy()
        elseif obj:IsA("ScreenGui") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
            if obj:FindFirstChildWhichIsA("ImageLabel") or obj:FindFirstChildWhichIsA("Frame") then
                if table.find(effectNames, obj.Name) or obj.Name:lower():find("overlay") or obj.Name:lower():find("effect") then
                    obj:Destroy()
                end
            end
        end
    end

    local temp = PlayerGui:FindFirstChild("TemporaryUI")
    if temp then
        local popup = temp:FindFirstChild("1x1x1x1Popup")
        if popup then
            popup:Destroy()
            warn("[Remover] 1x1x1x1Popup removed")
        end
    end
end

Tabs.Misc:AddToggle("RemoveAllBadStuff", {
    Title = "Remove Effects V2",
    Default = true,
    Callback = function(state)
        ActiveRemoveAll = state
        if state then
            task.spawn(function()
                while ActiveRemoveAll do
                    removeAll()
                    task.wait(0.5)
                end
            end)
        end
    end
})


    Tabs.Misc:AddSection("↳ Game Play")



do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    local Survivors = workspace:WaitForChild("Players"):WaitForChild("Survivors")

    local AntiSlowConfigs = {
        Slowness = {Values = {"SlowedStatus"}, Connection = nil, Enabled = false},
        Skills = {
            Values = {
                "StunningKiller", "EatFriedChicken", "GuestBlocking", "PunchAbility", "SubspaceTripmine",
                "TaphTripwire", "PlasmaBeam", "SpawnProtection", "c00lgui", "ShootingGun", 
                "TwoTimeStab", "TwoTimeCrouching", "DrinkingCola", "DrinkingSlateskin", 
                "SlateskinStatus", "EatingGhostburger"
            },
            Connection = nil, Enabled = false
        },
        Items = {Values = {"BloxyColaItem", "Medkit"}, Connection = nil, Enabled = false},
        Emotes = {Values = {"Emoting"}, Connection = nil, Enabled = false},
        Builderman = {Values = {"DispenserConstruction", "SentryConstruction"}, Connection = nil, Enabled = false}
    }

    local function hideSlownessUI()
        local mainUI = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("MainUI")
        if not mainUI then return end
        local statusContainer = mainUI:FindFirstChild("StatusContainer")
        if not statusContainer then return end
        local slownessUI = statusContainer:FindFirstChild("Slowness")
        if slownessUI then
            slownessUI.Visible = false
        end
    end

    local function handleAntiSlow(survivor, config)
        if survivor:GetAttribute("Username") ~= LocalPlayer.Name then return end

        local function onRenderStep()
            if not survivor.Parent or not config.Enabled then return end
            local speedMultipliers = survivor:FindFirstChild("SpeedMultipliers")
            if speedMultipliers then
                for _, valName in ipairs(config.Values) do
                    local val = speedMultipliers:FindFirstChild(valName)
                    if val and val:IsA("NumberValue") and val.Value ~= 1 then
                        val.Value = 1
                    end
                end
            end
            hideSlownessUI()
        end

        config.Connection = RunService.RenderStepped:Connect(onRenderStep)
    end

    local function startAllAntiSlow()
        for _, config in pairs(AntiSlowConfigs) do
            config.Enabled = true
            for _, survivor in pairs(Survivors:GetChildren()) do
                handleAntiSlow(survivor, config)
            end
            Survivors.ChildAdded:Connect(function(child)
                task.wait(0.1)
                handleAntiSlow(child, config)
            end)
        end
    end

    local function stopAllAntiSlow()
        for _, config in pairs(AntiSlowConfigs) do
            config.Enabled = false
            if config.Connection then
                config.Connection:Disconnect()
                config.Connection = nil
            end
        end
    end

    Tabs.Misc:AddToggle("AntiSlow_All", {
        Title = "Anti-Slow",
        Default = false
    }):OnChanged(function(Value)
        if Value then
            startAllAntiSlow()
        else
            stopAllAntiSlow()
        end
    end)
end




do
    local DoLoop = false
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local Workspace = game:GetService("Workspace")

    Tabs.Misc:AddToggle("AutoClosePopupV2", {
        Title = "Detele 1x Popups",
        Default = true
    }):OnChanged(function(Value)
        DoLoop = Value

        task.spawn(function()
            local Survivors = Workspace:WaitForChild("Players"):WaitForChild("Survivors")

            while DoLoop and task.wait() do

                local temp = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("TemporaryUI")
                if temp and temp:FindFirstChild("1x1x1x1Popup") then
                    temp["1x1x1x1Popup"]:Destroy()
                end

                for _, survivor in pairs(Survivors:GetChildren()) do
                    if survivor:GetAttribute("Username") == LocalPlayer.Name then
                        -- SpeedMultipliers
                        local speedMultipliers = survivor:FindFirstChild("SpeedMultipliers")
                        if speedMultipliers then
                            local val = speedMultipliers:FindFirstChild("SlowedStatus")
                            if val and val:IsA("NumberValue") then
                                val.Value = 1
                            end
                        end

                        local fovMultipliers = survivor:FindFirstChild("FOVMultipliers")
                        if fovMultipliers then
                            local val = fovMultipliers:FindFirstChild("SlowedStatus")
                            if val and val:IsA("NumberValue") then
                                val.Value = 1
                            end
                        end
                    end
                end
            end
        end)
    end)
end



    Tabs.Misc:AddSection("↳ Fix Lag")

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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



local originalLighting = {}
local originalParts = {}

local function saveLighting()
    originalLighting.QualityLevel = settings().Rendering.QualityLevel
    originalLighting.GlobalShadows = game.Lighting.GlobalShadows
    originalLighting.FogEnd = game.Lighting.FogEnd
    originalLighting.Brightness = game.Lighting.Brightness
    originalLighting.PostEffects = {}
    for _, v in ipairs(game.Lighting:GetChildren()) do
        if v:IsA("PostEffect") then
            originalLighting.PostEffects[v] = v.Enabled
        end
    end
end

local function restoreLighting()
    if not originalLighting.QualityLevel then return end
    settings().Rendering.QualityLevel = originalLighting.QualityLevel
    game.Lighting.GlobalShadows = originalLighting.GlobalShadows
    game.Lighting.FogEnd = originalLighting.FogEnd
    game.Lighting.Brightness = originalLighting.Brightness
    for effect, state in pairs(originalLighting.PostEffects) do
        if effect and effect.Parent == game.Lighting then
            effect.Enabled = state
        end
    end
end

local function simplifyModel(obj)
    if obj:IsA("BasePart") then
        if not originalParts[obj] then
            originalParts[obj] = {
                Material = obj.Material,
                Color = obj.Color,
                Reflectance = obj.Reflectance,
                CastShadow = obj.CastShadow
            }
        end
        obj.Material = Enum.Material.SmoothPlastic
        obj.Color = Color3.fromRGB(163, 162, 165)
        obj.Reflectance = 0
        obj.CastShadow = false
    elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
        obj:Destroy()
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
        obj.Enabled = false
    end
end

local function restoreParts()
    for part, data in pairs(originalParts) do
        if part and part.Parent then
            part.Material = data.Material
            part.Color = data.Color
            part.Reflectance = data.Reflectance
            part.CastShadow = data.CastShadow
        end
    end
    originalParts = {} -- reset
end

local autoThread
local connection

local AutoReduceToggle = Tabs.Misc:AddToggle("AutoReduce", {
    Title = "FPS Boost",
    Default = false,
    Callback = function(state)
        if state then
            print("🔄 Auto Reduce ON")

            saveLighting()

            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            game.Lighting.GlobalShadows = false
            game.Lighting.FogEnd = 9e9
            game.Lighting.Brightness = 1
            for _, v in ipairs(game.Lighting:GetChildren()) do
                if v:IsA("PostEffect") then
                    v.Enabled = false
                end
            end

            for _, obj in ipairs(workspace:GetDescendants()) do
                simplifyModel(obj)
            end

            connection = workspace.DescendantAdded:Connect(simplifyModel)

            autoThread = task.spawn(function()
                while AutoReduceToggle.Value do
                    task.wait(10)
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        simplifyModel(obj)
                    end
                end
            end)

        else
            print("⏹ Auto Reduce OFF")
            if connection then
                connection:Disconnect()
                connection = nil
            end

            restoreLighting()
            restoreParts()
            print("✅ Đã khôi phục đồ họa gốc")
        end
    end
})


local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local blockedAnimations = {
    ["127802146383565"] = true,
    ["82691533602949"] = true,
    ["123764169071995"] = true,
}

local BlockAnimEnabled = false
local blockConnections = {}

local function hookHumanoid(humanoid)
    if not humanoid then return end
    local conn = humanoid.AnimationPlayed:Connect(function(track)
        local id = track.Animation.AnimationId:match("%d+")
        if BlockAnimEnabled and blockedAnimations[id] then
            track:Stop()
        end
    end)
    table.insert(blockConnections, conn)
end

local function setBlockAnimations(enabled)
    BlockAnimEnabled = enabled

    for _, conn in pairs(blockConnections) do
        conn:Disconnect()
    end
    table.clear(blockConnections)

    if enabled then

        if LocalPlayer.Character then
            hookHumanoid(LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid"))
        end

        local connChar = LocalPlayer.CharacterAdded:Connect(function(char)
            char:WaitForChild("Humanoid")
            hookHumanoid(char:FindFirstChildWhichIsA("Humanoid"))
        end)
        table.insert(blockConnections, connChar)
    end
end

Tabs.Misc:AddToggle("BlockBadAnims", {
    Title = "Block Animations",
    Default = false
}):OnChanged(function(v)
    setBlockAnimations(v)
end)



    Tabs.Misc:AddSection("↳ Show")

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Camera = workspace.CurrentCamera

local ui = Instance.new("ScreenGui")
ui.Name = "FPS_Ping_Display"
ui.ResetOnSpawn = false
ui.IgnoreGuiInset = true
ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ui.Parent = game:GetService("CoreGui")

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0, 120, 0, 20)
fpsLabel.Position = UDim2.new(1, -130, 0, 5)
fpsLabel.BackgroundTransparency = 1
fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
fpsLabel.TextStrokeTransparency = 0
fpsLabel.TextSize = 16
fpsLabel.Font = Enum.Font.Code
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.Text = "FPS: ..."
fpsLabel.Parent = ui

local pingLabel = fpsLabel:Clone()
pingLabel.Position = UDim2.new(1, -130, 0, 25)
pingLabel.Text = "Ping: ..."
pingLabel.Parent = ui

local showFPS = true
local showPing = true
local fpsCounter, lastUpdate = 0, tick()

RunService.RenderStepped:Connect(function()
    fpsCounter += 1
    if tick() - lastUpdate >= 1 then
        if showFPS then
            fpsLabel.Visible = true
            fpsLabel.Text = "FPS: " .. tostring(fpsCounter)
        else
            fpsLabel.Visible = false
        end

        if showPing then
            local pingStat = Stats.Network.ServerStatsItem["Data Ping"]
            local ping = pingStat and math.floor(pingStat:GetValue()) or 0
            pingLabel.Text = "Ping: " .. ping .. " ms"
            if ping <= 60 then
                pingLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            elseif ping <= 120 then
                pingLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
            else
                pingLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
            pingLabel.Visible = true
        else
            pingLabel.Visible = false
        end

        fpsCounter = 0
        lastUpdate = tick()
    end
end)

local fpsToggle = Tabs.Misc:AddToggle("ShowFPSToggle", {
    Title = "Show FPS",
    Default = true
})
fpsToggle:OnChanged(function(val)
    showFPS = val
    fpsLabel.Visible = val
end)

local pingToggle = Tabs.Misc:AddToggle("ShowPingToggle", {
    Title = "Show Ping",
    Default = true
})
pingToggle:OnChanged(function(val)
    showPing = val
    pingLabel.Visible = val
end)




    getgenv().chatWindow = game:GetService("TextChatService"):WaitForChild("ChatWindowConfiguration")
    getgenv().chatEnabled = false
    getgenv().chatConnection = nil

    Tabs.Misc:AddToggle("ChatVisibilityToggle", {
        Title = "Show Chat",
        Default = false
    }):OnChanged(function(Value)
        getgenv().chatEnabled = Value


        if Value then
            if not getgenv().chatConnection then
                getgenv().chatConnection = game:GetService("RunService").Heartbeat:Connect(function()
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
    end)




-- Tabs.Settings


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

Fluent:Notify({ Title = "Tzuan Hub", Content = "forsaken script loaded successfully!", Duration = 5 })
SaveManager:LoadAutoloadConfig()