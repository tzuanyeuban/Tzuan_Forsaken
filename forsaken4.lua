--[[

  _______                      _    _       _     
 |__   __|                    | |  | |     | |    
    | |_____   _  __ _ _ __   | |__| |_   _| |__  
    | |_  / | | |/ _` | '_ \  |  __  | | | | '_ \ 
    | |/ /| |_| | (_| | | | | | |  | | |_| | |_) |
    |_/___|\__,_|\__,_|_| |_| |_|  |_|\__,_|_.__/ 
                                                  
                                                  
                        Tzuan Hub
]]

---------------------------------------------------------------------------------

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/XUANVNPRO/Mmb/refs/heads/main/gui2.0.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Tạo cửa sổ Fluent chính
local Window = Fluent:CreateWindow({
    Title = "Tzuan Hub | Forsaken",
    SubTitle = "Version 2.0.0",
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
    UserInfoSubtitle = "Mẹo mày bé",
    UserInfoSubtitleColor = Color3.fromRGB(71, 123, 255)
})

-- Tabs
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

--// ⚙️ ESPManager v2.7 (Auto-Restore + Debounce 0.5s)
--// Tự thêm lại khi model biến mất/hiện, chết/hồi sinh, GUI/HL mất, với debounce 0.5s để tránh lag

local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local ESPManager = {
    ActiveTypes = {},    -- ["Player"] = true
    Objects = {},        -- [model] = { type, gui, hl, label, conns = {} }
    Filters = {},        -- filterFn
    Colors = {},         -- typeColor
    Watchers = {},       -- connection table
    ShowHP = {},         -- typeName -> boolean
    _pendingCreate = {}, -- [model] = true (debounce)
}

-- Helper: safe find primary part
local function getPrimaryPart(model)
    if not model then return nil end
    local p = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    return p
end

-- 🧩 Đăng ký loại ESP
function ESPManager:RegisterType(name, color, filterFn, showHP)
    self.Filters[name] = filterFn
    self.Colors[name] = color
    self.ShowHP[name] = showHP or false
    self.ActiveTypes[name] = false
end

-- internal: disconnect connections table
local function disconnectConns(tbl)
    if not tbl then return end
    for _, c in pairs(tbl) do
        if c and typeof(c.Disconnect) == "function" then
            pcall(function() c:Disconnect() end)
        end
    end
end

-- 🧱 Tạo ESP (không debounce) - gọi an toàn bên trong task.delay khi cần
function ESPManager:_CreateImmediate(model, typeName)
    if not model or not model.Parent then return end
    if ESPManager.Objects[model] then
        -- nếu tồn tại nhưng bị hỏng phần gui/hl thì dọn trước
        local existing = ESPManager.Objects[model]
        if existing.gui and existing.gui.Parent and existing.hl and existing.hl.Parent then
            return -- đã ok rồi
        else
            ESPManager:Remove(model)
        end
    end

    local color = ESPManager.Colors[typeName]
    local part = getPrimaryPart(model)
    if not part then return end

    -- Billboard
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

    -- Highlight
    local hl = Instance.new("Highlight")
    hl.Adornee = model
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.7
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = true
    hl.Parent = model

    -- Kết nối model-level watchers (để tự phục hồi khi parent thay đổi / respawn / humanoid died)
    local conns = {}

    -- nếu model bị reparent / removed -> schedule recreate (debounced)
    table.insert(conns, model.AncestryChanged:Connect(function(_, parent)
        -- nếu model không còn trong workspace, xóa ESP
        if not model:IsDescendantOf(workspace) then
            -- xóa ngay (không recreate khi user tắt loại)
            if ESPManager.Objects[model] and ESPManager.Objects[model].type == typeName then
                ESPManager:Remove(model)
            end
            return
        end
        -- nếu trở lại workspace -> debounce tạo lại
        if ESPManager.ActiveTypes[typeName] and ESPManager.Filters[typeName](model) then
            ESPManager:_ScheduleCreate(model, typeName)
        end
    end))

    -- watch humanoid death & respawn
    local function watchHumanoid(hum)
        if not hum then return end
        -- Died -> remove, rồi chờ humanoid mới
        table.insert(conns, hum.Died:Connect(function()
            if ESPManager.Objects[model] and ESPManager.Objects[model].type == typeName then
                ESPManager:Remove(model)
            end
            -- chờ humanoid mới xuất hiện (ChildAdded)
            -- scheduled create sẽ handle khi Humanoid xuất hiện
        end))
    end

    -- nếu đã có humanoid, watch nó
    watchHumanoid(model:FindFirstChildOfClass("Humanoid"))

    -- listen ChildAdded để detect humanoid respawn
    table.insert(conns, model.ChildAdded:Connect(function(child)
        if child and child:IsA("Humanoid") then
            -- humanoid mới -> schedule create
            watchHumanoid(child)
            if ESPManager.ActiveTypes[typeName] and ESPManager.Filters[typeName](model) then
                ESPManager:_ScheduleCreate(model, typeName)
            end
        end
        -- nếu PrimaryPart xuất hiện muộn cũng schedule create
        if (child:IsA("BasePart") or child:IsA("Model")) and ESPManager.ActiveTypes[typeName] and ESPManager.Filters[typeName](model) then
            -- primary part may appear later
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

-- 🧱 Public Create (debounced wrapper)
function ESPManager:_ScheduleCreate(model, typeName)
    if not model or not typeName then return end
    -- nếu loại đang tắt thì không schedule
    if not ESPManager.ActiveTypes[typeName] then return end
    -- tránh schedule nhiều lần
    if ESPManager._pendingCreate[model] then return end
    ESPManager._pendingCreate[model] = true

    -- dùng task.delay 0.5 để debounce, tránh spam tạo khi model đang mid-update
    task.delay(0.5, function()
        pcall(function()
            ESPManager._pendingCreate[model] = nil
            -- double-check điều kiện
            if not model or not model.Parent then return end
            local filterFn = ESPManager.Filters[typeName]
            if not filterFn or not filterFn(model) then return end
            -- call immediate create (safe)
            ESPManager:_CreateImmediate(model, typeName)
        end)
    end)
end

-- 🧹 Xoá ESP
function ESPManager:Remove(model)
    local data = self.Objects[model]
    if not data then return end

    -- disconnect model connections
    if data.conns then
        disconnectConns(data.conns)
    end

    pcall(function() if data.gui then data.gui:Destroy() end end)
    pcall(function() if data.hl then data.hl:Destroy() end end)
    self.Objects[model] = nil
    -- clear pending if any
    self._pendingCreate[model] = nil
end

-- ⚙️ Tạo watcher (tự động thêm/xóa ESP khi model thay đổi)
function ESPManager:StartWatcher(typeName)
    local filterFn = self.Filters[typeName]
    if not filterFn then return end
    if self.Watchers[typeName] then return end

    -- tạo ESP cho model sẵn có (debounced per model)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if filterFn(obj) then
            -- schedule create with debounce
            self:_ScheduleCreate(obj, typeName)
        end
    end

    -- theo dõi model mới (DescendantAdded) nhưng schedule create chỉ khi hợp lệ
    local addConn = workspace.DescendantAdded:Connect(function(obj)
        if self.ActiveTypes[typeName] and filterFn(obj) then
            self:_ScheduleCreate(obj, typeName)
        end
    end)

    -- khi model bị remove -> Remove ESP nếu có
    local removeConn = workspace.DescendantRemoving:Connect(function(obj)
        if self.Objects[obj] and self.Objects[obj].type == typeName then
            self:Remove(obj)
        end
        -- clear any pending create when descendant removing
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

-- ♻️ Cập nhật (1 vòng duy nhất, cực nhẹ) - CHỈ cập nhật text / kiểm tra nhanh
RunService.Heartbeat:Connect(function()
    -- Sử dụng pairs(Objects) nhỏ (chỉ những model có ESP hiện tại)
    for model, data in pairs(ESPManager.Objects) do
        -- nếu model hỏng -> dọn
        if not model or not model.Parent then
            ESPManager:Remove(model)
        else
            local part = getPrimaryPart(model)
            if not part then
                ESPManager:Remove(model)
            else
                -- nếu gui/hl bị xóa bất ngờ -> schedule recreate (debounced)
                local needRecreate = false
                if (not data.gui) or (not data.hl) or (not data.label) then
                    needRecreate = true
                else
                    -- kiểm tra parent tình trạng (nếu parent nil)
                    if not data.gui.Parent then
                        needRecreate = true
                    end
                end
                if needRecreate then
                    -- remove entry ngay (dọn) và schedule tạo lại an toàn
                    local typeName = data.type
                    ESPManager:Remove(model)
                    ESPManager:_ScheduleCreate(model, typeName)
                    -- next model
                else
                    -- cập nhật text (nhẹ)
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
                        -- label update is cheap
                        pcall(function() data.label.Text = txt end)
                    end
                end
            end
        end
    end
end)

-- ⚡ Bật/Tắt từng loại ESP
function ESPManager:SetEnabled(typeName, state)
    self.ActiveTypes[typeName] = state

    if state then
        self:StartWatcher(typeName)
        -- khi bật lại, quét nhanh toàn bộ workspace và schedule create (debounced)
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
        -- xóa toàn bộ ESP loại đó
        for model, data in pairs(self.Objects) do
            if data.type == typeName then
                self:Remove(model)
            end
        end
    end
end

_G.ESPManager = ESPManager


-- Phần Tạo Nút Gui

-- 🟢 DRAGGABLE UI BUTTON WITH ENHANCED CLICK AND HOVER ANIMATIONS
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

-- Xóa nếu có UI minimize cũ
local ExistingUI = CoreGui:FindFirstChild("TzuanHubMinimizeUI")
if ExistingUI then
    ExistingUI:Destroy()
end

-- Create Floating UI
local DragUI = Instance.new("ScreenGui")
DragUI.Name = "TzuanHubMinimizeUI"
DragUI.ResetOnSpawn = false
DragUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
DragUI.Parent = CoreGui

-- Create Circular Button
local Button = Instance.new("ImageButton")
Button.Parent = DragUI
Button.Size = UDim2.new(0, 50, 0, 50)
Button.Position = UDim2.new(0, 10, 1, -85)
Button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Button.BackgroundTransparency = 0.3
Button.BorderSizePixel = 0
Button.ClipsDescendants = true
Button.Image = "rbxassetid://84950100176700" -- Thay icon nếu muốn
Button.ScaleType = Enum.ScaleType.Fit
Button.Active = true
Button.ZIndex = 1000

-- Make UI Circular
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(1, 0)
UICorner.Parent = Button

-- Tween Info for Animations
local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- 🟢 Toggle Fluent UI trực tiếp
local function ToggleUI()
    if Window.Minimized then
        Window:Minimize(false) -- mở lại
    else
        Window:Minimize(true) -- thu nhỏ
    end
end

-- Click Animation & UI Toggle
local isDragging = false
local dragThreshold = 10

Button.MouseButton1Click:Connect(function()
    if isDragging then return end

    -- Click animation
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

-- Hover Animation
Button.MouseEnter:Connect(function()
    TweenService:Create(Button, tweenInfo, {Size = UDim2.new(0, 55, 0, 55)}):Play()
end)

Button.MouseLeave:Connect(function()
    TweenService:Create(Button, tweenInfo, {Size = UDim2.new(0, 50, 0, 50)}):Play()
end)

-- Dragging Logic for PC & Mobile
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

-- Dragging Support
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
        Title = "Note",
        Content = "Thank you for using the script!"
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
                SubContent = "", -- Optional
                Duration = 3 
            })
        end
    })



    Tabs.Dev:AddButton({
        Title = "Youtube",
        Description = "Copy link to Subscribe to Youtube channel!",
        Callback = function()
            setclipboard("https://youtube.com/@Tzuanww")
            Fluent:Notify({
                Title = "Notification",
                Content = "Successfully copied to the clipboard!",
                SubContent = "", -- Optional
                Duration = 3 
            })
        end
    })


    Tabs.Dev:AddButton({
        Title = "Tiktok",
        Description = "Copy the link and follow me on TikTok!",
        Callback = function()
            setclipboard("https://www.tiktok.com/@xuan_vp?_r=1&_t=ZS-91ACXEqUsID")
            Fluent:Notify({
                Title = "Notification",
                Content = "Successfully copied to the clipboard!",
                SubContent = "", -- Optional
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

    -- 🟥 Chỉ chạy khi là các model này
    local KillersList = {
        ["Slasher"] = true,
        ["1x1x1x1"] = true,
        ["c00lkidd"] = true,
        ["Noli"] = true,
        ["JohnDoe"] = true,
        ["Guest 666"] = true,
        ["Sixer"] = true,
    }

    -- 🟢 Danh sách ưu tiên
    local PriorityList = {
        ["0206octavio"] = true
    }

    -- 🔥 Danh sách skill (full, có thể thêm/bớt thoải mái)
    local SkillList = {
        "Slash", "Stab", "Punch",
        "VoidRush", "Nova",
        "CorruptEnergy", "Behead", "GashingWound",
        "MassInfection", "CorruptNature", "WalkspeedOverride", "PizzaDelivery",
        "UnstableEye", "Entanglement",
        "DigitalFootprint", "404Error",
        "RagingPace", "Carving Slash", "Demonic Pursuit",
        "Infernal Cry", "Blood Rush"
    }

    -- =====================
    -- 🗡️ RemoteEvent Finder
    -- =====================
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

    -- =====================
    -- 🎯 Target Finder
    -- =====================
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

    -- =====================
    -- 🗡️ Kill Logic (spam nhanh + Remote + UI Click)
    -- =====================
    local function KillTarget(target)
        pcall(function()
            if not target then return end
            local localChar = LocalPlayer.Character
            if not (localChar and localChar:FindFirstChild("HumanoidRootPart")) then return end

            local root = localChar.HumanoidRootPart
            local targetRoot = target:FindFirstChild("HumanoidRootPart")
            if not targetRoot then return end

            -- Spam skill (mỗi 0.05s)
            if tick() - lastAttack >= 0.05 then
                lastAttack = tick()

                for _, skillName in ipairs(SkillList) do
                    -- luôn cập nhật vị trí sát lưng target trước khi dùng skill
                    local offset = targetRoot.CFrame.LookVector * -2
                    root.CFrame = targetRoot.CFrame + offset

                    local remote = SkillRemotes[skillName]
                    if remote then
                        -- Cách 1: FireServer trực tiếp
                        remote:FireServer(true)
                        task.wait(0.005)
                        remote:FireServer(false)
                    else
                        -- Cách 2: Giả click nút skill trong GUI
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

                        -- fallback cuối cùng: Remote gốc trong ReplicatedStorage
                        local net = ReplicatedStorage:FindFirstChild("Modules")
                                    and ReplicatedStorage.Modules:FindFirstChild("Network")
                                    and ReplicatedStorage.Modules.Network:FindFirstChild("RemoteEvent")
                        if net and typeof(net.FireServer) == "function" then
                            net:FireServer("UseActorAbility", skillName)
                        end
                    end

                    task.wait(0.01) -- giữ nhịp nhanh
                end
            end
        end)
    end

    -- =====================
    -- 🔄 Main Loop
    -- =====================
    local function StartLoop()
        if loopRunning then return end
        loopRunning = true
        task.spawn(function()
            while Active do
                -- 🛑 Nếu không phải killer hợp lệ thì không làm gì
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

-- 🟥 Killer nguy hiểm
local DangerousKillers = {
    ["Slasher"] = true,
    ["1x1x1x1"] = true,
    ["c00lkidd"] = true,
    ["Noli"] = true,
    ["JohnDoe"] = true,
    ["Guest 666"] = true,
    ["Sixer"] = true
}

-- 🟢 Kiểm tra killer gần generator
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

-- 🟢 Tìm generator chưa xong (cập nhật genDelay luôn)
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

    -- ⚡ Nếu chỉ còn 1 generator => tăng delay để tránh bị kick
    if #list == 1 then
        genDelay = 1.5
    else
        genDelay = 0.75
    end

    return list
end

-- 🟢 Sửa 1 lần rồi nhảy sang generator khác
local function fixOneGenerator(gen)
    if solveGeneratorCooldown then return end
    if not currentCharacter or not currentCharacter:FindFirstChild("HumanoidRootPart") then return end

    local genCFrame = gen:GetPivot()
    local goalPos = (genCFrame * CFrame.new(0, 0, -7)).Position

    if isKillerNearGenerator(goalPos, 50) then
        print("⚠️ Bỏ qua generator vì killer nguy hiểm gần!")
        return
    end

    -- Teleport tới gen
    currentCharacter:PivotTo(CFrame.new(goalPos + Vector3.new(0, 0, 0))) -- chỉnh độ cao, độ lệch
    task.wait(0.25)

    local prompt = gen:FindFirstChild("Main") and gen.Main:FindFirstChild("Prompt")
    if prompt then
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 99999

        -- Ấn để sửa 1 lần
        pcall(function()
            prompt:InputHoldBegin()
            prompt:InputHoldEnd()
        end)
    end

    if gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE") then
        gen.Remotes.RE:FireServer()
    end

    -- 🔴 Spam thêm vài lần để chắc chắn thoát GUI trước khi đi gen khác
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

    -- Cooldown
    solveGeneratorCooldown = true
    task.delay(genDelay, function()
        solveGeneratorCooldown = false
    end)
end

-- 🟢 Survivors Auto Farm
Tabs.Farm:AddToggle("SurvivorsAutoFarmV2", {
    Title = "Survivors Farm V2",
    Default = false
}):OnChanged(function(Value)
    _G.SurvivorsFarm = Value

    -- Cập nhật trạng thái in-game
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

    -- Kiểm tra survivor
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

    -- Auto sửa gen
    task.spawn(function()
        local survivorsFolder = workspace.Players:WaitForChild("Survivors")
        while _G.SurvivorsFarm do
            if Survivor and isInGame then
                -- lấy nhân vật hiện tại
                for _, surv in ipairs(survivorsFolder:GetChildren()) do
                    if surv:GetAttribute("Username") == LP.Name then
                        currentCharacter = surv
                        break
                    end
                end

                -- tìm gen chưa xong và sửa 1 lần
                local gens = getUnfinishedGenerators()
                for _, gen in ipairs(gens) do
                    if not _G.SurvivorsFarm then break end
                    fixOneGenerator(gen)
                    task.wait(genDelay) -- sau khi sửa xong thì nhảy qua gen khác
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
local genDelay = 1.5 -- mặc định 1.5s

-- Hàm tìm generator gần nhất
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

-- Nút Finish generator thủ công
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

-- Toggle Auto Finish Generator
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


-- Ô nhập delay
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


do
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

-- 🔹 Cancel token cho pathfinding
local h = 0
_G.PlayerControlled = false

-- =========================
--  DANH SÁCH SURVIVORS HỢP LỆ
-- =========================
local AllowedSurvivors = {
    ["Noob"] = true, ["Guest1337"] = true, ["Elliot"] = true,
    ["Shedletsky"] = true, ["TwoTime"] = true, ["007n7"] = true, ["Veeronica"] = true,
    ["Chance"] = true, ["Builderman"] = true, ["Taph"] = true, ["Dusekkar"] = true,
}

local function isSurvivorValid()
    local char = LP.Character
    if not char then return false end
    return AllowedSurvivors[char.Name] == true
end

-- =========================
--  PHÁT HIỆN NGƯỜI CHƠI ĐIỀU KHIỂN
-- =========================
local moveKeys = {
    [Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
    [Enum.KeyCode.Up] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Right] = true,
}
local activeInputs, lastMoveTick = 0, 0
local IDLE_GRACE = 0.25

local function setControlled(flag)
    if _G.PlayerControlled ~= flag then
        _G.PlayerControlled = flag
        if flag then h = h + 1 end -- hủy path ngay khi người chơi can thiệp
    end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and moveKeys[input.KeyCode] then
        activeInputs += 1; setControlled(true)
    elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
        activeInputs += 1; setControlled(true)
    elseif input.UserInputType == Enum.UserInputType.Touch then
        local cam = workspace.CurrentCamera
        if cam and input.Position.X < cam.ViewportSize.X * 0.5 then
            activeInputs += 1; setControlled(true)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard and moveKeys[input.KeyCode] then
        activeInputs = math.max(0, activeInputs - 1)
    elseif input.UserInputType == Enum.UserInputType.Gamepad1 or input.UserInputType == Enum.UserInputType.Touch then
        activeInputs = math.max(0, activeInputs - 1)
    end
    if activeInputs == 0 then lastMoveTick = tick() end
end)

RunService.Heartbeat:Connect(function()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hum.MoveDirection.Magnitude > 0 then
        lastMoveTick = tick(); setControlled(true)
    elseif activeInputs == 0 and (tick() - lastMoveTick) >= IDLE_GRACE then
        setControlled(false)
    end
end)

-- =========================
--  PATHFINDING
-- =========================
local function pathfindTo(targetPos)
    local hNow = h
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2, AgentHeight = 5,
        AgentCanJump = false, AgentJumpHeight = 10, AgentMaxSlope = 45
    })

    local ok = pcall(function() path:ComputeAsync(root.Position, targetPos) end)
    if not ok or path.Status ~= Enum.PathStatus.Success then return end

    for _, wp in ipairs(path:GetWaypoints()) do
        if hNow ~= h or _G.PlayerControlled then return end
        if not (hum and root and root.Parent) then return end

        hum:MoveTo(wp.Position)
        repeat task.wait()
        until hNow ~= h or _G.PlayerControlled or not root.Parent
           or ((root.Position * Vector3.new(1,0,1) - wp.Position * Vector3.new(1,0,1)).Magnitude <= 2)

        if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
    end
end

-- =========================
--  HỖ TRỢ KIỂM TRA KILLER
-- =========================
local function isKillerNearGenerator(generatorPos, distance)
    local killersFolder = Workspace.Players:FindFirstChild("Killers")
    if not killersFolder then return false end
    for _, killer in ipairs(killersFolder:GetChildren()) do
        local hrp = killer:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - generatorPos).Magnitude <= distance then
            return true
        end
    end
    return false
end

-- =========================
--  TOGGLE AUTO WALK & FIX GENERATORS
-- =========================
local GenWalkToggle = Tabs.Farm:AddToggle("GenWalkToggle", {
    Title = "Walk To Generator",
    Default = false
})

GenWalkToggle:OnChanged(function(Value)
    _G.AutoGenerators = Value
    if not Value then h = h + 1 end

    -- Auto Sprint (có kiểm soát stamina)
    if Value then
        _G.alwaysSprint = true
        task.spawn(function()
            local okSprint, sprint = pcall(function() return require(ReplicatedStorage.Systems.Character.Game.Sprinting) end)
            local okStam, stamina = pcall(function() return require(ReplicatedStorage.Systems.Character.Game.StaminaHandler) end)
            if not okSprint then return end

            local LOW, HIGH, lastReset, forceStop = 10, 80, tick(), false
            local function fireSprint(flag)
                sprint.IsSprinting = flag
                pcall(function() if sprint.__sprintedEvent then sprint.__sprintedEvent:Fire(flag) end end)
            end

            while _G.alwaysSprint and _G.AutoGenerators and task.wait() do
                -- 🔒 Chỉ chạy khi là survivor hợp lệ; nếu không thì tắt sprint và chờ
                if not isSurvivorValid() then
                    if okSprint and sprint.IsSprinting then fireSprint(false) end
                    continue
                end

                if okStam and type(stamina.Value) == "number" then
                    if stamina.Value <= LOW then if sprint.IsSprinting then fireSprint(false) end; forceStop = true end
                    if forceStop and stamina.Value >= HIGH then fireSprint(true); forceStop = false; lastReset = tick() end
                end
                if not forceStop and not sprint.IsSprinting then fireSprint(true); lastReset = tick() end
                if not forceStop and tick() - lastReset >= 3 then
                    fireSprint(false); task.wait(0.1); fireSprint(true); lastReset = tick()
                end
            end
        end)
    else
        _G.alwaysSprint = false
    end

    -- Auto Generators loop
    task.spawn(function()
        while true do
            if not _G.AutoGenerators then task.wait(1); continue end
            if not isSurvivorValid() then task.wait(1); continue end -- ✅ chỉ cho phép survivors hợp lệ

            if _G.PlayerControlled then task.wait(0.1); continue end

            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then task.wait(1); continue end

            local map = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Ingame") and Workspace.Map.Ingame:FindFirstChild("Map")
            if not map then task.wait(2); continue end

            local gens = {}
            for _, gen in ipairs(map:GetChildren()) do
                if gen.Name == "Generator" and gen:FindFirstChild("Progress") and gen.Progress.Value < 100 then
                    table.insert(gens, gen)
                end
            end
            if #gens == 0 then task.wait(3); continue end

            table.sort(gens, function(a, b)
                local ca, cb = a.Positions and a.Positions:FindFirstChild("Center"), b.Positions and b.Positions:FindFirstChild("Center") -- ✅ sửa 'và' -> 'and'
                if ca and cb then
                    return (hrp.Position - ca.Position).Magnitude < (hrp.Position - cb.Position).Magnitude
                end
                return false
            end)

            local targetGen = gens[1]
            if targetGen and targetGen.Positions and targetGen.Positions:FindFirstChild("Center") then
                local center = targetGen.Positions.Center.Position
                if isKillerNearGenerator(center, 50) then task.wait(2); continue end

                if not _G.PlayerControlled then pcall(function() pathfindTo(center) end) end
                repeat task.wait(0.05)
                until not _G.AutoGenerators or _G.PlayerControlled or not hrp.Parent or (hrp.Position - center).Magnitude <= 6
                if _G.PlayerControlled then continue end

                local prompt = targetGen.Main and targetGen.Main:FindFirstChild("Prompt")
                if prompt and (hrp.Position - center).Magnitude <= 6 then
                    prompt.HoldDuration, prompt.RequiresLineOfSight, prompt.MaxActivationDistance = 0, false, 99999
                    while _G.AutoGenerators and not _G.PlayerControlled and targetGen.Parent and targetGen:FindFirstChild("Progress") and targetGen.Progress.Value < 100 do
                        if (hrp.Position - center).Magnitude > 6 then break end
                        -- 🔹 Nhấn 1 lần rồi chờ 3 giây
                        pcall(function()
                            prompt:InputHoldBegin()
                        end)
                        task.wait(0.2) -- giữ nhẹ để chắc chắn ăn lệnh
                        pcall(function()
                            prompt:InputHoldEnd()
                        end)
                        task.wait(3.0) -- nghỉ 3 giây
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end)

-- Reset path khi map mới spawn
Workspace.ChildAdded:Connect(function(child)
    if child.Name == "Map" then h = h + 1 end
end)
end



    Tabs.Farm:AddSection("↳ Items")

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- Hàm nhặt item gần nhất
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

-- Button: Pick Up Item (1 lần)
Tabs.Farm:AddButton({
    Title = "Pick Up Item",
    Callback = pickUpNearest
})

-- Toggle: Auto PickUp Item (lặp)
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

Tabs.Main:AddParagraph({
    Title = "How to Use Script :",
    Content = "1: Must adjust the slider to increase or decrease\n2: Must not be min or max because it will not work\n3: Then turn on the buttons to use those functions\n\n|| Like, Share And Subscribe For Tzuanww ||"
})



    Tabs.Main:AddSection("↳ Eliot")

do
-- 🧩 GUI Toggle + Input
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

-- khoảng cách aim (studs)
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

-- ⚙️ Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local survivorsFolder = workspace:WaitForChild("Players"):WaitForChild("Survivors")

-- 🎞️ Animation IDs
local PizzaAnimation = {
    ["114155003741146"] = true,
    ["104033348426533"] = true
}

-- 🧠 Eliot check
local EliotModels = {["Elliot"] = true}

-- 🔖 State
local autoRotateDisabledByScript = false
local currentTarget, isLockedOn, wasPlayingAnimation = nil, false, false
local aimOffset = 2 -- lệch phải 2 studs

-- ⚙️ Utils
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

-- 🎯 Lấy survivor yếu máu nhất (trong folder Survivors)
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

    -- Sắp xếp theo % máu tăng dần
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

-- 🔁 Reset khi respawn
localPlayer.CharacterAdded:Connect(function()
    task.delay(0.1, function()
        autoRotateDisabledByScript = false
    end)
end)

-- 🔂 Main loop
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

    -- 🧲 Lock target khi bắt đầu animation
    if isPlaying and not isLockedOn then
        currentTarget = getWeakestSurvivor()
        if currentTarget then isLockedOn = true end
    end

    -- ⚙️ Validate target
    if isLockedOn and currentTarget then
        local tHum = currentTarget:FindFirstChildWhichIsA("Humanoid")
        local tHrp = currentTarget:FindFirstChild("HumanoidRootPart")
        if (not tHum) or (tHum.Health <= 0) or (not tHrp) then
            currentTarget, isLockedOn = nil, false
        end
    end

    -- ⏹️ End animation -> reset
    if (not isPlaying) and wasPlayingAnimation then
        currentTarget, isLockedOn = nil, false
        restoreAutoRotate()
    end
    wasPlayingAnimation = isPlaying

    -- 🎯 Aim logic
    if isPlaying and isLockedOn and currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
        local hrp = currentTarget.HumanoidRootPart
        local targetPos = hrp.Position
        if not autoRotateDisabledByScript then
            myHumanoid.AutoRotate = false
            autoRotateDisabledByScript = true
        end

        -- dự đoán hướng di chuyển nhẹ
        local vel = hrp.Velocity
        if vel and vel.Magnitude > 2 then
            targetPos = targetPos + hrp.CFrame.LookVector * 3
        end

        -- lệch phải
        local offset = myRoot.CFrame.RightVector * aimOffset
        local lookAt = Vector3.new(targetPos.X, myRoot.Position.Y, targetPos.Z) + offset

        myRoot.CFrame = myRoot.CFrame:Lerp(CFrame.lookAt(myRoot.Position, lookAt), 0.99)
    end
end)
end



--// 🍕 Auto Eat Pizza Instantly (Fluent Toggle Style)
--// ======================================

do
    -- 🌍 Global Vars
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer

    getgenv().BlinkToPizzaToggle = false
    getgenv().HPThreshold = 30

    -- 🧩 Helper Functions
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

    -- ?? Fluent UI Section

    -- 🍕 Toggle tự ăn pizza
    Tabs.Main:AddToggle("BlinkPizza_Toggle", {
        Title = "Auto Eat Pizza",
        Default = false,
    }):OnChanged(function(state)
        getgenv().BlinkToPizzaToggle = state
    end)

    -- ❤️ Input HP Threshold
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

    -- 🔁 Auto Loop
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


    Tabs.Main:AddSection("↳ Shedletsky")


do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local lp = Players.LocalPlayer

    -- ⚙️ Variables
    local enabled = false
    local mode = "AI Aimbot"
    local cooldown = false
    local lastTarget = nil
    local maxDistance = 5
    local sliderInitialized = false

    local TELEPORT_DURATION = 0.8
    local AI_DELAY = 15 -- ⏳ Delay giữa mỗi lần teleport AI

    local killersFolder = workspace:WaitForChild("Players"):WaitForChild("Killers")

    -- 🎵 Animation IDs
    local monitoredAnimations = {
        'rbxassetid://116618003477002', 'rbxassetid://121255898612475',
        'rbxassetid://98031287364865',  'rbxassetid://119462383658044',
        'rbxassetid://77448521277146',  'rbxassetid://103741352379819',
        'rbxassetid://131696603025265', 'rbxassetid://122503338277352',
        'rbxassetid://97648548303678'
    }

    -- 🔧 Slash button + remote
    local slashButton, slashRemote, slashConnections = nil, nil, {}

    local function findSlashRemote()
        if slashRemote then return slashRemote end
        if not slashButton then return nil end
        for _, conn in ipairs(getconnections(slashButton.MouseButton1Click)) do
            local f = conn.Function
            if f and islclosure(f) then
                for _, v in pairs(getupvalues(f)) do
                    if typeof(v) == "Instance" and v:IsA("RemoteEvent") then
                        slashRemote = v
                        warn("[AutoSlash] Found Slash Remote:", v:GetFullName())
                        return slashRemote
                    end
                end
            end
        end
        return nil
    end

    local function initSlashButton()
        local gui = lp:FindFirstChild("PlayerGui")
        if not gui then return end
        local mainUI = gui:FindFirstChild("MainUI")
        local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
        slashButton = container and container:FindFirstChild("Slash")
        if slashButton and slashButton:IsA("ImageButton") then
            slashConnections = getconnections(slashButton.MouseButton1Click)
            findSlashRemote()
        end
    end

    initSlashButton()
    lp.CharacterAdded:Connect(function()
        task.wait(0.5)
        initSlashButton()
    end)

    local function useSlash()
        if slashRemote then
            pcall(function()
                slashRemote:FireServer(true)
                task.delay(0.05, function()
                    slashRemote:FireServer(false)
                end)
            end)
        elseif slashButton then
            for _, conn in ipairs(slashConnections) do
                pcall(function() conn:Fire() end)
            end
            pcall(function() slashButton:Activate() end)
        end
    end

    -- 🧭 UI
    local ModeDropdown = Tabs.Main:AddDropdown("SlashMode", {
        Title = "Slash Mode",
        Values = { "AI Aimbot", "Player Aimbot" },
        Default = "AI Aimbot"
    })
    ModeDropdown:OnChanged(function(Value)
        mode = Value
    end)

    local SlashToggle = Tabs.Main:AddToggle("SlashToggle", {
        Title = "Auto Slash",
        Default = false
    })
    SlashToggle:OnChanged(function(Value)
        enabled = Value
    end)

    local DistanceSlider = Tabs.Main:AddSlider("DistanceSlider", {
        Title = "Distance",
        Min = 1, Max = 50, Default = 5,
        Rounding = 1, ValueName = "studs"
    })
    DistanceSlider:OnChanged(function(Value)
        if not sliderInitialized then
            sliderInitialized = true
            return
        end
        maxDistance = Value
    end)

    -- ⚡ Helpers
    local function getRelativeTeleportPosition(hrp, targetHRP)
        local toTarget = (hrp.Position - targetHRP.Position).Unit
        return targetHRP.Position + (toTarget * 2)
    end

    local function teleportAndSlash(target, spam)
        if cooldown then return end
        local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        local kHRP = target:FindFirstChild("HumanoidRootPart")
        if not hrp or not kHRP then return end

        cooldown = true
        lastTarget = target

        local start = tick()
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not (lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and kHRP and kHRP.Parent) then
                if conn then conn:Disconnect() end
                cooldown = false
                lastTarget = nil
                return
            end

            if tick() - start >= TELEPORT_DURATION then
                if conn then conn:Disconnect() end
                task.delay((mode == "AI Aimbot") and AI_DELAY or TELEPORT_DURATION, function()
                    cooldown = false
                    lastTarget = nil
                end)
                return
            end

            local newPos = getRelativeTeleportPosition(hrp, kHRP)
            hrp.CFrame = CFrame.new(newPos, kHRP.Position)

            if spam then useSlash() end
        end)
    end

    -- ⚔️ AI Aimbot Mode (auto tìm trong Killers folder)
    RunService.Heartbeat:Connect(function()
        if not enabled or cooldown or mode ~= "AI Aimbot" then return end
        local char = lp.Character
        if not (char and char:FindFirstChild("HumanoidRootPart")) then return end
        local hrp = char.HumanoidRootPart

        for _, killer in ipairs(killersFolder:GetChildren()) do
            if killer:FindFirstChild("HumanoidRootPart") then
                local kHRP = killer.HumanoidRootPart
                local dist = (hrp.Position - kHRP.Position).Magnitude
                if dist <= maxDistance and killer ~= lastTarget then
                    teleportAndSlash(killer, true)
                    break
                end
            end
        end
    end)

    -- 👁️ Player Aimbot Mode
    local function attachAnimMonitor(character)
        local humanoid = character:WaitForChild("Humanoid", 5)
        if not humanoid then return end

        humanoid.AnimationPlayed:Connect(function(animTrack)
            if not enabled or mode ~= "Player Aimbot" or cooldown then return end
            local animId = animTrack.Animation and animTrack.Animation.AnimationId
            if animId and table.find(monitoredAnimations, animId) then
                for _, killer in ipairs(killersFolder:GetChildren()) do
                    if killer:FindFirstChild("HumanoidRootPart") then
                        local hrpLocal = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                        local kHRP = killer:FindFirstChild("HumanoidRootPart")
                        if hrpLocal and kHRP then
                            local dist = (kHRP.Position - hrpLocal.Position).Magnitude
                            if dist <= maxDistance * 5 then
                                teleportAndSlash(killer, false)
                                break
                            end
                        end
                    end
                end
            end
        end)
    end

    if lp.Character then
        attachAnimMonitor(lp.Character)
    end
    lp.CharacterAdded:Connect(attachAnimMonitor)
end



do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local lp = Players.LocalPlayer

    -- Vars
    local healEnabled = false
    local healHPThreshold = 50
    local healDistance = 50

    -- Heal button + remote
    local healButton, healRemote, healConnections = nil, nil, {}

    -- tìm RemoteEvent từ button Heal
    local function findHealRemote()
        if healRemote then return healRemote end
        if not healButton then return nil end
        for _, conn in ipairs(getconnections(healButton.MouseButton1Click)) do
            local f = conn.Function
            if f and islclosure(f) then
                local upvals = getupvalues(f)
                for _, v in pairs(upvals) do
                    if typeof(v) == "Instance" and v:IsA("RemoteEvent") then
                        healRemote = v
                        warn("[AutoHeal] Found Heal Remote:", v:GetFullName())
                        return healRemote
                    end
                end
            end
        end
        return nil
    end

    local function initHealButton()
        local gui = lp:FindFirstChild("PlayerGui")
        if not gui then return end
        local mainUI = gui:FindFirstChild("MainUI")
        local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
        healButton = container and container:FindFirstChild("FriedChicken")
        if healButton and healButton:IsA("ImageButton") then
            healConnections = getconnections(healButton.MouseButton1Click)
            findHealRemote()
        end
    end

    initHealButton()
    lp.CharacterAdded:Connect(function()
        task.wait(0.5)
        initHealButton()
    end)

    local function useHeal()
        if healRemote then
            pcall(function()
                healRemote:FireServer(true)
                task.delay(0.05, function()
                    healRemote:FireServer(false)
                end)
            end)
        elseif healButton then
            for _, conn in ipairs(healConnections) do
                pcall(function() conn:Fire() end)
            end
            pcall(function() healButton:Activate() end)
        end
    end

    -- UI ------------------------------------------------
    local HealToggle = Tabs.Main:AddToggle("HealToggle", {
        Title = "Auto Heal",
        Default = false
    })
    HealToggle:OnChanged(function(v) healEnabled = v end)

    local HealHPSlider = Tabs.Main:AddSlider("HealHPSlider", {
        Title = "Heal HP",
        Min = 1, Max = 100, Default = 50,
        Rounding = 0, ValueName = "HP"
    })
    HealHPSlider:OnChanged(function(v) healHPThreshold = v end)

    local HealDistanceSlider = Tabs.Main:AddSlider("HealDistanceSlider", {
        Title = "Distance",
        Min = 1, Max = 150, Default = 50,
        Rounding = 0, ValueName = "studs"
    })
    HealDistanceSlider:OnChanged(function(v) healDistance = v end)

    -- Helpers -------------------------------------------------------------
    local function getPlayersFolders()
        local pf = workspace:FindFirstChild("Players")
        if not pf then return nil, nil, nil end
        return pf, pf:FindFirstChild("Killers"), pf:FindFirstChild("Survivors")
    end

    local function belongsToMe(m)
        if not (m and m:IsA("Model")) then return false end
        if m:GetAttribute("Username") == lp.Name then return true end
        local UsernameSV = m:FindFirstChild("Username")
        if UsernameSV and typeof(UsernameSV.Value) == "string" and UsernameSV.Value == lp.Name then return true end
        local Owner = m:FindFirstChild("Owner") or m:FindFirstChild("Player")
        if Owner and Owner.Value == lp then return true end
        local uidAttr = m:GetAttribute("UserId")
        if uidAttr and tonumber(uidAttr) == lp.UserId then return true end
        if m.Name == lp.Name then return true end
        return false
    end

    local function getMyShedletsky()
        local pf, killersFolder, survivorsFolder = getPlayersFolders()
        local candidates = {}

        local function scan(container)
            if not container then return end
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("Model") and d.Name == "Shedletsky" and d:FindFirstChild("Humanoid") and d:FindFirstChild("HumanoidRootPart") then
                    if belongsToMe(d) then table.insert(candidates, d) end
                end
            end
        end

        scan(killersFolder)
        scan(survivorsFolder)
        scan(workspace)

        if #candidates == 0 then return nil, nil, nil end

        local basePos
        if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
            basePos = lp.Character.HumanoidRootPart.Position
        end

        local best, bestDist = candidates[1], math.huge
        if basePos then
            for _, m in ipairs(candidates) do
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = (hrp.Position - basePos).Magnitude
                    if d < bestDist then best, bestDist = m, d end
                end
            end
        end

        local hum = best:FindFirstChildOfClass("Humanoid")
        local hrp = best:FindFirstChild("HumanoidRootPart")
        return best, hum, hrp
    end

    local function getNearestKillerDist(fromHRP, myModel)
        local _, killersFolder = getPlayersFolders()
        if not (killersFolder and fromHRP) then return math.huge end
        local nearest = math.huge
        for _, k in ipairs(killersFolder:GetChildren()) do
            if k ~= myModel then
                local khrp = k:FindFirstChild("HumanoidRootPart")
                if khrp then
                    local d = (fromHRP.Position - khrp.Position).Magnitude
                    if d < nearest then nearest = d end
                end
            end
        end
        return nearest
    end

    -- Main loop ----------------------------------------------------------
    RunService.Heartbeat:Connect(function()
        if not healEnabled then return end

        local myModel, myHumanoid, myHRP = getMyShedletsky()
        if not (myModel and myHumanoid and myHRP) then return end
        if myHumanoid.Health <= 0 then return end

        local nearestDist = getNearestKillerDist(myHRP, myModel)

        if myHumanoid.Health <= healHPThreshold and nearestDist >= healDistance then
            useHeal()
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

-- ================= GUI =================
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

-- ================= Character Setup =================
local function setupCharacter(char)
    Humanoid = char:WaitForChild("Humanoid")
    HRP = char:WaitForChild("HumanoidRootPart")
end
if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

-- ================= Helpers =================
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

-- ================= Coinflip helpers =================
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

-- ================= Main loop =================
RunService.RenderStepped:Connect(function()
    -- AIMBOT LOGIC
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

    -- COINFLIP LOGIC
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


--// Auto Backstab Unified (AI Aimbot + Player Aimbot, tự động quét Killers Folder)
do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local lp = Players.LocalPlayer

    -- ⚙️ Config
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

    -- 🔘 UI
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

    -- =====================
    -- 🗡️ Dagger Remote Finder
    -- =====================
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

    -- =====================
    -- ⚒️ Helpers
    -- =====================
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

    -- =====================
    -- 🔄 Main Loop
    -- =====================
    local cooldown = false
    local lastTarget = nil

    RunService.Heartbeat:Connect(function()
        if not enabled or cooldown then return end
        local char, humanoid, myHRP = getCharacter()
        if not (char and humanoid and myHRP) then return end

        -- 🚨 Chỉ hoạt động nếu model là "TwoTime"
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

    -- 🔍 Tự động lấy Survivors trong workspace
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

    -- ✅ Kiểm tra nếu character là survivor (trong folder Survivors)
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

    -- 🟢 Fluent UI Toggle
    Tabs.Main:AddToggle("InstantInvisibleV2", {
        Title = "Instant Invisible",
        Default = false
    }):OnChanged(function(Value)
        handleToggle(Value)
    end)
end



do
    -- Invisible upon Cloning (sandboxed)
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

    -- ✅ Toggle dạng mới Fluent UI
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

        -- 🧩 Safe get UI & Behavior folder (cache sẵn)
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

        -- 🧠 Kiểm tra highlight có target mình không
        local function adorneeIsPlayerCharacter(h)
            if not h then return false end
            local adornee = h.Adornee
            local char = player.Character
            if not adornee or not char then return false end
            return adornee == char or adornee:IsDescendantOf(char)
        end

        -- 🧰 Hàm kích nút Sprinting (chỉ gọi 1 lần)
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

        -- 🧹 Cleanup function
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

            -- 🔍 Khi có highlight mới thêm vào
            local addConn = behaviorFolder.DescendantAdded:Connect(function(child)
                if child:IsA("Highlight") then
                    highlights[child] = true
                end
            end)

            -- 🔍 Khi highlight bị xóa
            local removeConn = behaviorFolder.DescendantRemoving:Connect(function(child)
                if child:IsA("Highlight") then
                    highlights[child] = nil
                end
            end)

            table.insert(_G.AutoTrick_Connections, addConn)
            table.insert(_G.AutoTrick_Connections, removeConn)

            -- 🚀 Vòng kiểm tra định kỳ nhẹ (0.3s/lần)
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


    Tabs.Main:AddSection("↳ Dusekkar")


--// Dusk Aim Assist (Fluent Dropdown trên Toggle) - Locked Target Version
do
-- 🧠 Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- 📍 References
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ⚙️ Config
local TargetAnimationID = "rbxassetid://77894750279891"
local Enabled = false
local Smoothness = 0.2

-- Thời gian tối đa khóa target (giây) sau khi chọn target
local LOCK_DURATION = 0.7

-- 🎛️ Fluent UI Controls
local toggleFlag = Instance.new("BoolValue")
toggleFlag.Name = "DuskAim_ToggleFlag"
toggleFlag.Value = false

-- Dropdown ở TRÊN
Tabs.Main:AddDropdown("DuskSmooth", {
    Title = "Smoothness",
    Values = {"Low", "Medium", "High"},
    Default = "Medium",
}):OnChanged(function(value)
    if value == "Low" then
        Smoothness = 0.1
    elseif value == "Medium" then
        Smoothness = 0.2
    elseif value == "High" then
        Smoothness = 0.4
    end
end)

-- Toggle ở DƯỚI
Tabs.Main:AddToggle("DuskAim", {
    Title = "Dusk Aim Assist",
    Default = false,
}):OnChanged(function(state)
    Enabled = state
    toggleFlag.Value = state
    -- reset any locked target when toggling off
    if not state then
        currentTarget = nil
        lockExpires = nil
    end
end)

-- 🎯 Find nearest player (returns HumanoidRootPart or nil)
local function getNearestPlayerRoot()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    local nearest, distance = nil, math.huge
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local root = player.Character.HumanoidRootPart
            local dist = (root.Position - myPos).Magnitude
            if dist < distance then
                distance = dist
                nearest = root
            end
        end
    end
    return nearest
end

-- Helper: check if a humanoid is currently playing the target animation
local function humanoidIsPlayingTargetAnimation(humanoid)
    if not humanoid then return false end
    for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
        if track.Animation and track.Animation.AnimationId == TargetAnimationID then
            return true
        end
    end
    return false
end

-- State for locked target
local currentTarget = nil          -- HumanoidRootPart (locked)
local currentTargetHumanoid = nil  -- Humanoid of the locked target's character
local lockExpires = nil            -- timestamp when lock can be released at earliest

-- 🔥 Aimbot logic (RenderStepped)
RunService.RenderStepped:Connect(function()
    if not Enabled then
        return
    end

    -- safety: require local character and camera
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or not Camera then
        currentTarget = nil
        currentTargetHumanoid = nil
        lockExpires = nil
        return
    end

    -- First: detect if ANY player is playing the target animation
    local anyAnimPlaying = false
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoidIsPlayingTargetAnimation(humanoid) then
                anyAnimPlaying = true
                -- If we don't have a locked target yet, lock to the nearest player NOW
                if not currentTarget then
                    local chosen = getNearestPlayerRoot()
                    if chosen then
                        currentTarget = chosen
                        currentTargetHumanoid = chosen.Parent and chosen.Parent:FindFirstChildOfClass("Humanoid") or nil
                        lockExpires = tick() + LOCK_DURATION
                    end
                end
                -- We break here optionally (we only need to know that an animation is playing).
                -- But do not break if we want to check other players' animations as well; either is fine.
                -- We'll not break so we keep checking; but one detection is enough to keep anyAnimPlaying = true.
            end
        end
    end

    -- If there is a locked target, aim at it while animation(s) are playing OR until lockExpires
    if currentTarget and currentTarget.Parent and currentTargetHumanoid then
        -- validate target: still has HumanoidRootPart and is alive
        if not currentTarget or not currentTarget.Parent or not currentTarget.Parent:FindFirstChild("HumanoidRootPart") then
            -- invalid target, release
            currentTarget = nil
            currentTargetHumanoid = nil
            lockExpires = nil
            return
        end

        -- Determine whether we should continue aiming:
        -- continue if either (a) any player is currently playing the target animation OR
        -- (b) we haven't reached lockExpires yet (ensures a short guaranteed aiming window)
        local continueAiming = anyAnimPlaying or (lockExpires and tick() < lockExpires)

        if continueAiming then
            local aimPos = currentTarget.Position
            local camCFrame = Camera.CFrame
            -- avoid zero-length direction
            local dirVec = aimPos - camCFrame.Position
            if dirVec.Magnitude > 0 then
                local direction = dirVec.Unit
                Camera.CFrame = Camera.CFrame:Lerp(
                    CFrame.new(camCFrame.Position, camCFrame.Position + direction),
                    Smoothness
                )
            end
            return
        else
            -- no animation playing and lock expired -> release target, allow new selection next detection
            currentTarget = nil
            currentTargetHumanoid = nil
            lockExpires = nil
            return
        end
    end

    -- If we get here: no locked target, but if an animation is playing we already set one above.
    -- Nothing to do otherwise.
end)
end



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
--        ["121808371053483"] = true, -- La Hét Vào Mặt :))
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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

if getgenv().emergency_stop == nil then
    getgenv().emergency_stop = false
end

-- 🔧 Chuyển studs thành độ tăng kích thước
local function StudsIntoSize(studs)
    return studs * 0.5
end

-- ⚙️ Hàm tăng hitbox người khác
local function ExtendOthersHitbox(studs, time)
    local size_increase = StudsIntoSize(studs)
    local start = tick()

    if getgenv().emergency_stop then
        getgenv().emergency_stop = false
    end

    repeat
        task.wait(0.05)
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= lp and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                for _, part in pairs(plr.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        local originalSize = part.Size
                        part.Size = Vector3.new(
                            originalSize.X + size_increase,
                            originalSize.Y,
                            originalSize.Z + size_increase
                        )
                        part.Massless = true
                        part.CanCollide = false
                    end
                end
            end
        end
    until tick() - start > tonumber(time) or getgenv().emergency_stop

    -- 🔄 Trả lại kích thước cũ
    if getgenv().emergency_stop then
        getgenv().emergency_stop = false
    end

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            for _, part in pairs(plr.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Size = Vector3.new(2, 2, 1)
                end
            end
        end
    end
end

-- 🛑 Hàm dừng
local function StopExtendingHitbox()
    getgenv().emergency_stop = true
end

-- 🟢 Nút bật/tắt hitbox extender
Tabs.Main:AddToggle("ExtendHitboxOthers", {
    Title = "Block Hitbox",
    Default = false,
    Callback = function(Value)
        if Value then
            task.spawn(function()
                while Value and not getgenv().emergency_stop do
                    ExtendOthersHitbox(1.5, 2)
                    task.wait(0)
                end
            end)
        else
            StopExtendingHitbox()
        end
    end
})
end





do
    -- Auto Punch settings
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

    -- Function: play custom punch anim
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

    -- Hidden fling coroutine
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

    -- Auto Punch loop
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
                            
                            -- Aim Punch
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

                            -- Click punch button
                            for _, conn in ipairs(getconnections(punchBtn.MouseButton1Click)) do
                                pcall(function() conn:Fire() end)
                            end

                            -- Fling Punch
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

                            -- Custom anim
                            if customPunchEnabled and customPunchAnimId ~= "" then
                                playCustomPunch(customPunchAnimId)
                            end

                            break -- chỉ đánh 1 killer mỗi vòng
                        end
                    end
                end
            end
        end
    end)

    -- === Nút cho Tabs.Main (thêm vào GUI có sẵn) ===
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

    Tabs.Main:AddSection("↳ c00lkidd")



do
    --== ⚙️ Base Globals ==--
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local Camera = Workspace.CurrentCamera
    local Player = Players.LocalPlayer

    getgenv().Remote = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("RemoteEvent")
    getgenv().walkSpeed = 100
    getgenv().connection = nil
    getgenv().blockFootstepPlayed = false

    --== 🧠 Helpers ==--
    local function getCharacter()
        return Player.Character or Player.CharacterAdded:Wait()
    end

    --== 🎯 Target list ==
    -- Thay specialTargets bằng folder Survivors tự động
    local survivorsFolder = workspace:WaitForChild("Players"):WaitForChild("Survivors")

    local function isSpecialTarget(char)
        if not char then return false end
        if survivorsFolder:FindFirstChild(char.Name) then
            return true
        end
        -- một số model có thể là child của model (cẩn thận)
        for _, child in ipairs(char:GetChildren()) do
            if survivorsFolder:FindFirstChild(child.Name) then
                return true
            end
        end
        return false
    end

    --== 🏃 Movement Logic ==--
    local stopMovement = false
    local validValues = { Timeout = true, Collide = true, Hit = true }
    local stopTimerTask = nil
    local STOP_TIMEOUT = 5

    local function startStopTimeout()
        if stopTimerTask then return end
        stopTimerTask = task.spawn(function()
            task.wait(STOP_TIMEOUT)
            stopMovement = false
            stopTimerTask = nil
        end)
    end

    local function cancelStopTimeout()
        stopTimerTask = nil
    end

    local function watchResult(result)
        local function check()
            if validValues[result.Value] then
                stopMovement = true
                startStopTimeout()
            else
                stopMovement = false
                cancelStopTimeout()
            end
        end
        pcall(check)
        local conn
        conn = result:GetPropertyChangedSignal("Value"):Connect(function()
            pcall(check)
        end)
        result.AncestryChanged:Connect(function(_, parent)
            if not parent then
                stopMovement = false
                cancelStopTimeout()
                if conn then
                    conn:Disconnect()
                    conn = nil
                end
            end
        end)
    end

    local function onCharacterAdded(character)
        local result = character:FindFirstChild("Result")
        if result and result:IsA("StringValue") then
            watchResult(result)
        end
        character.ChildAdded:Connect(function(child)
            if child.Name == "Result" and child:IsA("StringValue") then
                watchResult(child)
            end
        end)
        character.ChildRemoved:Connect(function(child)
            if child.Name == "Result" then
                stopMovement = false
                cancelStopTimeout()
            end
        end)
    end

    Player.CharacterAdded:Connect(onCharacterAdded)
    if Player.Character then
        onCharacterAdded(Player.Character)
    end

    --== 🔎 Helpers ==--
    local function getHumRoot(partOrChar)
        if not partOrChar then return nil end
        return partOrChar:FindFirstChild("HumanoidRootPart") or partOrChar:FindFirstChild("Torso") or partOrChar:FindFirstChild("UpperTorso")
    end

    --== 🔄 Movement follow camera ==--
    local function onHeartbeat()
        local char = Player.Character
        -- giữ check c00lkidd như gốc (chỉ áp dụng cho mẫu c00lkidd)
        if not char or char.Name ~= "c00lkidd" then return end
        local root = getHumRoot(char)
        local hum = char:FindFirstChildOfClass("Humanoid")
        local lv = root and root:FindFirstChild("LinearVelocity")
        if not root or not hum or not lv then return end
        lv.Enabled = false
        if stopMovement then return end

        local look = Camera and Camera.CFrame and Camera.CFrame.LookVector or nil
        if look then
            local dir = Vector3.new(look.X, 0, look.Z)
            if dir.Magnitude > 0 then
                dir = dir.Unit
                root.Velocity = Vector3.new(dir.X * getgenv().walkSpeed, root.Velocity.Y, dir.Z * getgenv().walkSpeed)
                root.CFrame = CFrame.new(root.Position, root.Position + dir)
            end
        end
    end

    --== 🧩 Hook Helpers ==--
    getgenv().createHook = function(remoteName)
        if getgenv()["original_" .. remoteName] then
            return getgenv()["original_" .. remoteName]
        end
        getgenv()["original_" .. remoteName] = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = { ... }
            if self == getgenv().Remote and method == "FireServer" then
                if args[1] == Player.Name .. remoteName then
                    return
                end
            end
            return getgenv()["original_" .. remoteName](self, ...)
        end)
        return getgenv()["original_" .. remoteName]
    end

    getgenv().enableHook = function(remoteName)
        if not getgenv()["hook_" .. remoteName] then
            getgenv()["hook_" .. remoteName] = getgenv().createHook(remoteName)
        end
        if remoteName == "DusekkarCancel" and not getgenv().isFiringDusekkar then
            getgenv().isFiringDusekkar = true
            task.spawn(function()
                task.wait(4)
                getgenv().Remote:FireServer({ Player.Name .. "DusekkarCancel" })
                getgenv().isFiringDusekkar = false
                stopMovement = false
                cancelStopTimeout()
            end)
        end
    end

    getgenv().disableHook = function(remoteName)
        if getgenv()["hook_" .. remoteName] then
            hookmetamethod(game, "__namecall", getgenv()["hook_" .. remoteName])
            getgenv()["hook_" .. remoteName] = nil
            getgenv()["original_" .. remoteName] = nil
        end
    end

    --== 👣 Footstep Hook ==--
    getgenv().HookFootstepPlayed = function(enable)
        if enable then
            if not getgenv().originalFootstepHook then
                getgenv().originalFootstepHook = hookmetamethod(game, "__namecall", function(self, ...)
                    local method = getnamecallmethod()
                    local args = { ... }
                    if method == "FireServer" and self.Name == "UnreliableRemoteEvent" then
                        if args[1] == "FootstepPlayed" and getgenv().blockFootstepPlayed then
                            return
                        end
                    end
                    return getgenv().originalFootstepHook(self, ...)
                end)
            end
            getgenv().blockFootstepPlayed = true
        else
            getgenv().blockFootstepPlayed = false
        end
    end

    --== ⚔️ Combat GUI (Fluent style) ==--
    Tabs.Main:AddToggle("WalkspeedOverride", {
        Title = "Walkspeed Override Controller",
        Default = false
    }):OnChanged(function(value)
        if value then
            stopMovement = false
            cancelStopTimeout()
            if not getgenv().connection then
                getgenv().connection = RunService.Heartbeat:Connect(onHeartbeat)
            end
        else
            if getgenv().connection then
                getgenv().connection:Disconnect()
                getgenv().connection = nil
            end
        end
    end)

    Tabs.Main:AddToggle("IgnoreC00lkidd", {
        Title = "Walkspeed Override Ignore Objectables",
        Default = false
    }):OnChanged(function(value)
        if value then
            getgenv().enableHook("C00lkiddCollision")
        else
            getgenv().disableHook("C00lkiddCollision")
        end
    end)

    Tabs.Main:AddToggle("IgnoreFootstep", {
        Title = "Block Footstep Played",
        Default = false
    }):OnChanged(function(value)
        getgenv().HookFootstepPlayed(value)
    end)

    --== 🧩 New Toggle for Dusekkar ==
    Tabs.Main:AddToggle("DusekkarMode", {
        Title = "Anti Dusekarr Attack",
        Default = false
    }):OnChanged(function(value)
        if value then
            getgenv().enableHook("DusekkarCancel")
        else
            getgenv().disableHook("DusekkarCancel")
        end
    end)

end




    Tabs.Main:AddSection("↳ Noli")

do
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- ====== CONFIG ======
    local voidrushcontrol = false
    local DASH_SPEED = 80
    local ATTACK_RANGE = 6
    local ATTACK_INTERVAL = 0.2

    -- ====== DYNAMIC PRIORITY ======
    local survivorsFolder = workspace:WaitForChild("Players"):WaitForChild("Survivors")

    local function isPriorityTarget(p)
        if not p or not p.Character then return false end
        return survivorsFolder:FindFirstChild(p.Name) ~= nil
    end

    -- ====== STATE ======
    local isOverrideActive = false
    local connection
    local Humanoid, RootPart
    local lastState = nil
    local attackingLoop = nil

    -- setup character
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

    -- tìm mục tiêu hợp lệ
    local function validTarget(p)
        if p == LocalPlayer then return false end
        local c = p.Character
        if not c then return false end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChild("Humanoid")
        return hrp and hum and hum.Health > 0
    end

    -- tìm player gần nhất (ưu tiên survivorsFolder)
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

    -- cố gắng tấn công (tool:Activate())
    local function attemptAttack()
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool and tool.Parent == char then
            pcall(function() tool:Activate() end)
        end
    end

    -- điều khiển Void Rush
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

    -- kiểm tra trạng thái void rush
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

    -- toggle GUI
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
-- 🧩 GUI Toggle + Dropdown
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

-- ⚙️ Setup
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local workspacePlayers = workspace:WaitForChild("Players")
local survivorsFolder = workspacePlayers:WaitForChild("Survivors")

local dangerousAnimations = {
    ["131430497821198"] = true,
    ["100592913030351"] = true,
    ["70447634862911"]  = true,
    ["83685305553364"] = true
}

local killerModels = {["1x1x1x1"] = true}

-- ⚡ State
local autoRotateDisabledByScript = false
local currentTarget, isLockedOn, wasPlayingAnimation = nil, false, false

-- 🧩 Utils
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

-- 🧭 Tìm survivor gần nhất trong folder "Survivors"
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

-- 🌀 Reset khi respawn
localPlayer.CharacterAdded:Connect(function()
    task.delay(0.1, function()
        autoRotateDisabledByScript = false
    end)
end)

-- 🔁 Main loop
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

    -- Lock target 1 lần khi bắt đầu animation
    if isPlaying and not isLockedOn then
        currentTarget = getClosestSurvivor()
        if currentTarget then isLockedOn = true end
    end

    -- Validate target
    if isLockedOn and currentTarget then
        local tHum = currentTarget:FindFirstChildWhichIsA("Humanoid")
        local tHrp = currentTarget:FindFirstChild("HumanoidRootPart")
        if (not tHum) or (tHum and tHum.Health <= 0) or (not tHrp) then
            currentTarget, isLockedOn = nil, false
        end
    end

    -- End animation
    if (not isPlaying) and wasPlayingAnimation then
        currentTarget, isLockedOn = nil, false
        restoreAutoRotate()
    end
    wasPlayingAnimation = isPlaying

    -- 🎯 Aim / Teleport
    if isPlaying and isLockedOn and currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
        local hrp = currentTarget.HumanoidRootPart
        local targetPos = hrp.Position

        if not autoRotateDisabledByScript then
            myHumanoid.AutoRotate = false
            autoRotateDisabledByScript = true
        end

        -- Predict movement
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


do
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- 📦 Nút Teleport riêng
    Tabs.Event:AddButton({
        Title = "TP to Shop",
        Description = "Teleport đến khu Shop",
        Callback = function()
            local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(-3540.36, -392.73, 231.53)
            end
        end,
    })
end


local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

Tabs.Event:AddButton({
    Title = "Get Skin Sixer",
    Callback = function()
        pcall(function()
            TeleportService:Teleport(139594300138069, Players.LocalPlayer)
        end)
    end
})


-- 💙 8. SUKKARS / EVENT ESP (v3.2: chạm viền sẽ ẩn ESP)
-----------------------------------------------------
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local allowedModels = {
    ["dumsek"] = true,
    ["toon dusek"] = true,
    ["dusek"] = true,
    ["umdum"] = true,
    ["doothsek"] = true,
}

local blockedCenter = Vector3.new(-3485.02, 4.48, 217.77)
local blockedRadius = 500

_G.ESPManager:RegisterType("Sukkars", Color3.fromRGB(0, 85, 255), function(obj)
    if not obj:IsA("Model") then return false end
    if not allowedModels[string.lower(obj.Name)] then return false end

    local part = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
    if not part then return false end

    local dist = (part.Position - blockedCenter).Magnitude
    if dist <= blockedRadius then return false end

    return true
end, false)

-- ⚡ Gắn .Touched 1 lần duy nhất
local oldCreate = _G.ESPManager.Create
_G.ESPManager.Create = function(self, model, typeName)
    oldCreate(self, model, typeName)

    if typeName == "Sukkars" then
        local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
        if hrp and not hrp:FindFirstChild("_TouchedFlag") then
            local flag = Instance.new("BoolValue")
            flag.Name = "_TouchedFlag"
            flag.Parent = hrp

            hrp.Touched:Connect(function(hit)
                local char = LocalPlayer.Character
                if char and hit:IsDescendantOf(char) then
                    _G.ESPManager:Remove(model)
                end
            end)
        end
    end
end

-- 💫 Ẩn ESP khi “chạm viền” (cự ly cực gần)
task.spawn(function()
    while task.wait(0.15) do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        for model, data in pairs(_G.ESPManager.Objects) do
            if data.type == "Sukkars" then
                local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
                if part then
                    local dist = (hrp.Position - part.Position).Magnitude
                    if dist <= 5 then -- 👈 khoảng cách “chạm viền”
                        _G.ESPManager:Remove(model)
                    elseif dist > 1200 then -- xa quá thì dọn ESP
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



-- 🧭 Danh sách model cần teleport tới
local TargetNames = {
    "dumsek",
    "toon dusek",
    "umdum",
    "dusek",
    "doothsek",
}

-- ⚙️ Cài đặt
local ScanInterval = 0.5
local TeleportDelay = 0.25
local HeightSafe = 5
local IgnoreCenter = Vector3.new(-3485.02, 4.48, 217.77)
local IgnoreRadius = 500

-- ⚡ Biến điều khiển
local autoTeleport = false
local visitedModels = {}
local currentTarget = nil

-- === SERVICES ===
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- === HÀM HỖ TRỢ ===
local function getHumanoid()
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	return char:FindFirstChildOfClass("Humanoid"), char
end

local function getModelCFrame(model)
	if not model or not model:IsDescendantOf(workspace) then return end
	local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if part then
		return part.CFrame
	elseif model.GetPivot then
		local ok, pivot = pcall(function()
			return model:GetPivot()
		end)
		if ok then return pivot end
	end
end

local function isValidModel(model)
	if not model or not model:IsDescendantOf(workspace) then
		return false
	end
	for _, name in ipairs(TargetNames) do
		if model.Name:lower() == name:lower() then
			local cf = getModelCFrame(model)
			if cf then
				local pos = cf.Position
				if (pos - IgnoreCenter).Magnitude > IgnoreRadius then
					return true
				end
			end
		end
	end
	return false
end

-- === TÌM CÁC MODEL HỢP LỆ ===
local function findTargets()
	local list = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and isValidModel(obj) then
			table.insert(list, obj)
		end
	end
	return list
end

-- === KIỂM TRA NHÂN VẬT ĐANG CHẠM MODEL HIỆN TẠI ===
local function isTouchingTarget(target)
	if not target or not target:IsDescendantOf(workspace) then
		return false
	end
	local char = LocalPlayer.Character
	if not char then return false end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local targetPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
	if not targetPart then return false end

	local dist = (hrp.Position - targetPart.Position).Magnitude
	return dist <= 6
end

-- === TELEPORT SANG MODEL TIẾP THEO ===
local function teleportToNext()
	local humanoid, char = getHumanoid()
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Dọn dẹp model đã biến mất khỏi danh sách
	for m in pairs(visitedModels) do
		if not m:IsDescendantOf(workspace) then
			visitedModels[m] = nil
		end
	end

	-- Lấy danh sách hợp lệ
	local allTargets = findTargets()
	local available = {}
	for _, m in ipairs(allTargets) do
		if not visitedModels[m] and m:IsDescendantOf(workspace) then
			table.insert(available, m)
		end
	end

	-- Nếu hết mục tiêu thì reset visited để quét lại
	if #available == 0 then
		table.clear(visitedModels)
		return
	end

	-- Chọn model gần nhất
	table.sort(available, function(a, b)
		local pa = getModelCFrame(a).Position
		local pb = getModelCFrame(b).Position
		return (hrp.Position - pa).Magnitude < (hrp.Position - pb).Magnitude
	end)

	local nextTarget = available[1]
	if nextTarget then
		local cf = getModelCFrame(nextTarget)
		if cf then
			local pos = cf.Position
			if pos.Y < -10 then
				pos = Vector3.new(pos.X, HeightSafe, pos.Z)
			end
			hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
			currentTarget = nextTarget
		end
	end
end

-- === VÒNG CHÍNH ===
task.spawn(function()
	while task.wait(ScanInterval) do
		if autoTeleport and LocalPlayer.Character then
			-- nếu target hiện tại biến mất, bỏ qua và chuyển model khác
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

-- === TOGGLE GUI ===
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

--// 🌌 Hệ Thống Tu Tiên (Fluent UI Paragraph v3)
-- Mỗi cấp 3h, 9 tầng (Nhất → Cửu Giai), có tiến trình Đột Phá %

local HttpService = game:GetService("HttpService")
local SaveFile = "TuTienData.json"

-- Danh sách cảnh giới (mỗi cấp = 3h = 10800s)
-- Phàm Nhân không có tầng
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

-- Các tầng (mỗi tầng = 20 phút = 1200s)
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

-- Đọc dữ liệu
local function LoadData()
    if isfile and isfile(SaveFile) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(SaveFile))
        end)
        if success and decoded then return decoded end
    end
    return {totalTime = 0}
end

-- Lưu dữ liệu
local function SaveData(data)
    if writefile then
        writefile(SaveFile, HttpService:JSONEncode(data))
    end
end

-- Tính Tu Vi, Tầng, Linh Khí %, Đột Phá %
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

-- Dữ liệu hiện tại
local Data = LoadData()

-- UI hiển thị
local Paragraph = Tabs.Custom:AddParagraph({
    Title = "Thông Tin",
    Content = "Đang khởi động..."
})

-- Vòng cập nhật
task.spawn(function()
    while task.wait(1) do
        Data.totalTime += 1
        local level, stage, percent, breakP = GetProgress(Data.totalTime)

        local content = string.format("Tu Vi: %s\n", level)
        if stage then
            content ..= string.format("Tầng: %s\n", stage)
        end
        content ..= string.format("Linh Khí: %.1f%%\n", percent * 100)

        -- Nếu có tầng thì hiện thêm Đột Phá %
        if stage then
            content ..= string.format("Đột Phá: %.1f%%", breakP * 100)
        end

        Paragraph:SetDesc(content)

        -- Lưu định kỳ
        if Data.totalTime % 10 == 0 then
            SaveData(Data)
        end

        -- Khi đạt Đại Đế full
        if level == "Đại Đế" and percent >= 1 then
            Paragraph:SetDesc("Tu Vi: Đại Đế\nTầng: Cửu Giai\nLinh Khí: 100%\nĐột Phá: 100%")
            break
        end
    end
end)


    Tabs.Custom:AddSection("↳ Animation")

--// Fake Killers Anim System (hardened)
do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local player = Players.LocalPlayer

    -- thử require sprint module (nếu có)
    local sprintModule
    pcall(function()
        sprintModule = require(ReplicatedStorage:WaitForChild("Systems").Character.Game.Sprinting)
    end)

    -- ==============================
    -- 🟢 DỮ LIỆU KILLERS + SKINS (chỉ sửa ở đây)
    -- ==============================
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
                Music = "rbxassetid://73595818073606" -- 🆕 nhạc đặc biệt
            }
        }
    }
    -- ==============================

    -- state
    local enabled = false
    local selectedKiller = "Shasher"
    local selectedSkin = "Default"
    local character, humanoid, animator
    local idleAnim, walkAnim, runAnim
    local idleTrack, walkTrack, runTrack
    local _isSprinting = false
    local musicSound -- 🆕 biến giữ Sound object

    -- conn
    local runningConn, heartbeatConn, characterRemovingConn, inputBeganConn, inputEndedConn = nil, nil, nil, nil, nil
    local heartbeatAccumulator = 0
    local HEARTBEAT_CHECK_INTERVAL = 0.12

    -- utility
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

    -- load anim objects theo killer + skin
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

        playMusicIfSukuna(set) -- 🆕 check phát nhạc nếu là Sukuna
    end

    -- play anim
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

    -- update state
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

    -- listeners
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

    -- bind character
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

    -- ===== UI =====
    local killerNames = {}
    for name,_ in pairs(KillersData) do table.insert(killerNames, name) end
    table.sort(killerNames)

    local SkinDropdown -- khai báo trước

    -- dropdown chính (Killers)
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

    -- dropdown Skin (nằm dưới Killer)
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

    -- toggle fake killers
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


do
-- LocalScript (StarterPlayerScripts)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ⚡ Config
local BUTTON_SIZE = 48
local FramesLocked = true
local screenGui
local createdFrames = {}

-- dữ liệu các nút
local buttonsData = {
    {Name = "Btn1", AnimationId = "135853087227453", PlayMusic = true, MusicId = "81361259756089", ImageId = "134210378382767"},
    {Name = "Btn2", AnimationId = "99784586201997", PlayMusic = false, ImageId = "134210378382767"},
    {Name = "Btn3", AnimationId = "121162477402224", PlayMusic = true, MusicId = "120185817748858", ImageId = "85785826985052"},
    {Name = "Btn4", AnimationId = "101816924844805", PlayMusic = true, MusicId = "88406027536494", ImageId = "85785826985052"},
}

-- vị trí ban đầu
local startPositions = {
    UDim2.new(0, 80, 0, 200),
    UDim2.new(0, 140, 0, 200),
    UDim2.new(0, 200, 0, 200),
    UDim2.new(0, 260, 0, 200),
}

-- 🌟 Drag Module
local function makeDraggable(frame)
    local dragging, dragStart, startPos

    frame.InputBegan:Connect(function(input)
        if not FramesLocked and (input.UserInputType == Enum.UserInputType.MouseButton1 
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not FramesLocked and dragging and 
            (input.UserInputType == Enum.UserInputType.MouseMovement 
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- 🔹 GUI container
screenGui = Instance.new("ScreenGui")
screenGui.Name = "CircleButtonsGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Enabled = false
screenGui.Parent = playerGui

-- 🔹 Hàm tạo frame + button
local function createFrameWithButton(data, pos)
    local frame = Instance.new("Frame")
    frame.Name = data.Name .. "_Frame"
    frame.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
    frame.Position = pos
    frame.BackgroundTransparency = 1
    frame.ZIndex = 1
    frame.Parent = screenGui
    frame.Active = true

    -- bo tròn frame
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(1, 0)
    frameCorner.Parent = frame

    local btn = Instance.new("ImageButton")
    btn.Name = data.Name
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Image = "rbxassetid://" .. data.ImageId
    btn.ZIndex = 2
    btn.Parent = frame
    btn.ScaleType = Enum.ScaleType.Fit -- giữ tỉ lệ ảnh

    -- bo tròn nút
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    -- click chạy animation/nhạc
    btn.MouseButton1Click:Connect(function()
        if FramesLocked then
            local char = player.Character or player.CharacterAdded:Wait()
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end

            local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
            local anim = Instance.new("Animation")
            anim.AnimationId = "rbxassetid://" .. data.AnimationId
            local track = animator:LoadAnimation(anim)
            track:Play()

            if data.PlayMusic and data.MusicId then
                local sound = Instance.new("Sound")
                sound.SoundId = "rbxassetid://" .. data.MusicId
                sound.Volume = 1
                sound.Parent = char:FindFirstChild("Head") or playerGui
                sound:Play()
                sound.Ended:Connect(function() sound:Destroy() end)
            end
        end
    end)

    makeDraggable(frame)

    btn.Visible = FramesLocked
    frame.BackgroundTransparency = FramesLocked and 1 or 0.3

    table.insert(createdFrames, frame)
end

-- tạo nút
for i, d in ipairs(buttonsData) do
    createFrameWithButton(d, startPositions[i])
end

-- 🌟 Tích hợp Toggle + Input
Tabs.Custom:AddToggle("SukunaSkill", {
    Title = "Sukuna Skill",
    Default = false
}):OnChanged(function(state)
    screenGui.Enabled = state
end)

Tabs.Custom:AddToggle("SukunaLockButton", {
    Title = "Lock Buttons",
    Default = true
}):OnChanged(function(state)
    FramesLocked = state
    for _, frame in ipairs(createdFrames) do
        local btn = frame:FindFirstChildOfClass("ImageButton")
        if btn then
            btn.Visible = FramesLocked
        end
        frame.BackgroundTransparency = FramesLocked and 1 or 0.3
    end
end)

Tabs.Custom:AddInput("SkunaButtonSkill", {
    Title = "Button Size",
    Default = tostring(BUTTON_SIZE),
    Placeholder = "Nhập số px",
    Numeric = true,
    Finished = true
}):OnChanged(function(value)
    local num = tonumber(value)
    if num and num > 0 then
        BUTTON_SIZE = num
        for _, frame in ipairs(createdFrames) do
            frame.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
            local btn = frame:FindFirstChildOfClass("ImageButton")
            if btn then
                btn.Size = UDim2.new(1, 0, 1, 0)
            end
        end
    end
end)
end



do
-- LocalScript (StarterPlayerScripts)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ⚡ Config
local BUTTON_SIZE = 48
local FramesLocked = true
local screenGui
local createdFrames = {}

-- dữ liệu các nút
local buttonsData = {
    {Name = "Btn1", AnimationId = "72722244508749", PlayMusic = false, ImageId = "87293861183080"},
    {Name = "Btn2", AnimationId = "96959123077498", PlayMusic = false, ImageId = "87293861183080"},
}

-- vị trí ban đầu
local startPositions = {
    UDim2.new(0, 80, 0, 200),
    UDim2.new(0, 140, 0, 200),
}

-- 🌟 Drag Module
local function makeDraggable(frame)
    local dragging, dragStart, startPos

    frame.InputBegan:Connect(function(input)
        if not FramesLocked and (input.UserInputType == Enum.UserInputType.MouseButton1 
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not FramesLocked and dragging and 
            (input.UserInputType == Enum.UserInputType.MouseMovement 
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- 🔹 GUI container
screenGui = Instance.new("ScreenGui")
screenGui.Name = "CircleButtonsGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Enabled = false
screenGui.Parent = playerGui

-- 🔹 Hàm tạo frame + button
local function createFrameWithButton(data, pos)
    local frame = Instance.new("Frame")
    frame.Name = data.Name .. "_Frame"
    frame.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
    frame.Position = pos
    frame.BackgroundTransparency = 1
    frame.ZIndex = 1
    frame.Parent = screenGui
    frame.Active = true

    -- bo tròn frame
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(1, 0)
    frameCorner.Parent = frame

    local btn = Instance.new("ImageButton")
    btn.Name = data.Name
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Image = "rbxassetid://" .. data.ImageId
    btn.ZIndex = 2
    btn.Parent = frame
    btn.ScaleType = Enum.ScaleType.Fit -- giữ tỉ lệ ảnh

    -- bo tròn nút
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    -- click chạy animation/nhạc
    btn.MouseButton1Click:Connect(function()
        if FramesLocked then
            local char = player.Character or player.CharacterAdded:Wait()
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end

            local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
            local anim = Instance.new("Animation")
            anim.AnimationId = "rbxassetid://" .. data.AnimationId
            local track = animator:LoadAnimation(anim)
            track:Play()

            if data.PlayMusic and data.MusicId then
                local sound = Instance.new("Sound")
                sound.SoundId = "rbxassetid://" .. data.MusicId
                sound.Volume = 1
                sound.Parent = char:FindFirstChild("Head") or playerGui
                sound:Play()
                sound.Ended:Connect(function() sound:Destroy() end)
            end
        end
    end)

    makeDraggable(frame)

    btn.Visible = FramesLocked
    frame.BackgroundTransparency = FramesLocked and 1 or 0.3

    table.insert(createdFrames, frame)
end

-- tạo nút
for i, d in ipairs(buttonsData) do
    createFrameWithButton(d, startPositions[i])
end

-- 🌟 Tích hợp Toggle + Input
Tabs.Custom:AddToggle("Guest1337Skill", {
    Title = "Guest1337 Skill",
    Default = false
}):OnChanged(function(state)
    screenGui.Enabled = state
end)

Tabs.Custom:AddToggle("Guest1337LockButton", {
    Title = "Lock Buttons",
    Default = true
}):OnChanged(function(state)
    FramesLocked = state
    for _, frame in ipairs(createdFrames) do
        local btn = frame:FindFirstChildOfClass("ImageButton")
        if btn then
            btn.Visible = FramesLocked
        end
        frame.BackgroundTransparency = FramesLocked and 1 or 0.3
    end
end)

Tabs.Custom:AddInput("Quest1337SkillSize", {
    Title = "Button Size",
    Default = tostring(BUTTON_SIZE),
    Placeholder = "Nhập số px",
    Numeric = true,
    Finished = true
}):OnChanged(function(value)
    local num = tonumber(value)
    if num and num > 0 then
        BUTTON_SIZE = num
        for _, frame in ipairs(createdFrames) do
            frame.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
            local btn = frame:FindFirstChildOfClass("ImageButton")
            if btn then
                btn.Size = UDim2.new(1, 0, 1, 0)
            end
        end
    end
end)
end



-- 🧠 Services
getgenv().SoundService = game:GetService("SoundService")
getgenv().RunService = game:GetService("RunService")

-- 📁 Ensure folders exist
local folderPath = "TzuanHub/Assets"
if not isfolder("TzuanHub") then makefolder("TzuanHub") end
if not isfolder(folderPath) then makefolder(folderPath) end

-- 🎵 Track list (FULL)
getgenv().tracks = {
    ["None"] = "",
    ["----------- UST -----------"] = nil,
    ["A BRAVE SOUL (MS 4 Killer VS MS 4 Survivor)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/A%20BRAVE%20SOUL%20(MS%204%20Killer%20VS%20MS%204%20Survivor).mp3",
    ["BEGGED (MS 4 Coolkidd vs MS 4 007n7)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/BEGGED%20(MS%204%20Coolkidd%20vs%20MS%204%20007n7).mp3",
    ["DOOMSPIRE (HairyTwinkle VS Pedro.EXE)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/DOOMSPIRE%20-%20(HairyTwinkle%20VS%20Pedro.EXE).mp3",
    ["ECLIPSE (xX4ce0fSpadesXx vs dragondudes3)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/ECLIPSE%20(xX4ce0fSpadesXx%20vs%20dragondudes3).mp3",
    ["ERROR 264 (Noob Cosplay VS Yourself)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/ERROR%20264%20-%20(Noob%20Cosplay%20VS%20Yourself).mp3",
    ["GODS SECOND COMING (NOLI VS. 007n7)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/GODS%20SECOND%20COMING%20(NOLI%20VS.%20007n7).mp3",
    ["Entreat (Bluudude Vs 118o8)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/Entreat%20(Bluudude%20Vs%20118o8).mp3",
    ["Implore (Comic vs Savior)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/Implore%20(Comic%20vs%20Savior)%20-%20YouTube.mp3",
    ["Leftovers (Remix Vanity Jason Vs All)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/Leftovers%20(Remix%20Vanity%20Jason%20Vs%20All).mp3",
    ["ORDER UP (Elliot VS c00lkidd)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/ORDER%20UP%20-%20(Elliot%20VS%20c00lkidd).mp3",
    ["PARADOX (Guest 666 Vs Guest 1337)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/PARADOX%20(Guest%20666%20Vs%20Guest%201337).mp3",
    ["TRUE BEAUTY (PRETTYPRINCESS vs 226w6)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/TRUE%20BEAUTY%20(PRETTYPRINCESS%20vs%20226w6).mp3",
    ["Fall of a Hero (SLASHER vs GUEST 1337)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/%5BSLASHER%20vs%20GUEST%201337%20-%20LAST%20MAN%20STANDING%5D%20Fall%20of%20a%20Hero%20-%20Forsaken%20UST.mp3",
    ["21ST CENTURY HUMOR (MLG Chance vs Hood Irony Whistle Occurrence)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/21ST%20CENTURY%20HUMOR%20-%20Last%20Man%20Standing%20(MLG%20Chance%20vs%20Hood%20Irony%20Whistle%20Occurrence)%20%20Forsaken%20UST.mp3",
    ["SHATTERED GRACE (GR1MX 1x1x1x1 vs. ANGEL SHEDLETSKY)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/SHATTERED%20GRACE%20%5BGR1MX%201x1x1x1%20vs.%20ANGEL%20SHEDLETSKY%20LAST%20MAN%20STANDING%5D%20(Roblox%20Forsaken%20UST).mp3",
    ["----------- Scrapped LMS -----------"] = nil,
    ["THE DARKNESS IN YOUR HEART (Old 1x4 Vs Shedletsky)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/THE%20DARKNESS%20IN%20YOUR%20HEART%20(Old%201x4%20Vs%20Shedletsky).mp3",
    ["MEET YOUR MAKING (c00lkidd ~ 1x4 Vs 007n7 ~ Shedletsky)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/MEET%20YOUR%20MAKING%20(c00lkidd%20~%201x4%20Vs%20007n7%20~%20Shedletsky).mp3",
    ["A Creation Of Sorrow (Hacklord vs The Heartbroken)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/A%20Creation%20Of%20Sorrow%20(Hacklord%20vs%20The%20Heartbroken).mp3",
    ["Debth (Natrasha Vs Mafioso)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/Debth%20(Natrasha%20Vs%20Mafioso).mp3",
    ["ETERNAL HOPE, ETERNAL FIGHT (Old LMS)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/ETERNAL%20HOPE,%20ETERNAL%20FIGHT%20(Old%20LMS).mp3",
    ["Receading Lifespan (Barber Jason Vs Bald Two Time)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/Receading%20Lifespan%20(Barber%20Jason%20Vs%20Bald%20Two%20Time).mp3",
    ["VIP Jason LMS (VIP Jason Vs All)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/VIP%20Jason%20LMS%20(VIP%20Jason%20Vs%20All).mp3",
    ["Jason Hate This Song"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/California%20Gurls%20%20Audio%20Edit%20-%20Neonick.mp3",
    ["----------- Official LMS -----------"] = nil,
    ["A GRAVE SOUL (NOW, RUN) [All Killers Vs All Survivors]"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/A%20GRAVE%20SOUL%20(NOW,%20RUN)%20%5BAll%20Killers%20Vs%20All%20Survivors%5D.mp3",
    ["Plead (c00lkidd Vs 007n7)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/Plead%20(c00lkidd%20Vs%20007n7).mp3",
    ["SMILE (Cupcakes Vs All)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/SMILE%20(Cupcakes%20Vs%20All)%20.mp3",
    ["Vanity (Vanity Jason Vs All)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/Vanity%20(Vanity%20Jason%20Vs%20All).mp3",
    ["Obsession (Gasharpoon Vs All)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/Obsession%20(Gasharpoon%20Vs%20All).MP3",
    ["Burnout (Diva Vs Ghoul)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/Burnout%20(Diva%20Vs%20Ghoul).mp3",
    ["Close To Me (Annihilation Vs Friend)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/Close%20To%20Me%20(Annihilation%20Vs%20Friend).mp3",
    ["Creation Of Hatred (1X4 Vs Shedletsky)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/Creation%20Of%20Hatred%20(1X4%20Vs%20Shedletsky).mp3",
    ["Through Patches of Violet (Hacklord vs The Heartbroken)"] = "https://github.com/NyansakenHub/NyansakenHub/raw/refs/heads/main/Through%20Patches%20of%20Violet%20(Hacklord%20vs%20The%20Heartbroken).mp3"
}

-- 🔽 Dropdown options
local options = {}
for k, _ in pairs(getgenv().tracks) do
    table.insert(options, k)
end

-- 🌐 Globals
getgenv().selectedSong = "None"
getgenv().customSongUrl = nil
getgenv().originalSongId = nil
getgenv().isPlaying = false
getgenv().isToggleOn = false

-- 💾 Download song (only one at a time)
local function downloadTrack(name, url)
    if not url or url == "" then return nil end
    local path = folderPath .. "/" .. name:gsub("[^%w]", "_") .. ".mp3"
    if not isfile(path) then
        local req = http_request or syn.request or request
        local res = req({Url = url, Method = "GET"})
        local data = res.Body or res.BodyRaw
        if data and #data > 0 then writefile(path, data) end
    end
    return path
end

-- 🔍 Find LastSurvivor
local function getLastSurvivor()
    local t = workspace:FindFirstChild("Themes")
    if t then return t:FindFirstChild("LastSurvivor") end
    return nil
end

-- ▶️ Set & play track
local function setLastSurvivorSong(songName)
    local ls = getLastSurvivor()
    if not ls then return end
    local url = getgenv().tracks[songName]
    if not url or url == "" then return end
    local path = downloadTrack(songName, url)
    if not path then return end
    local sound = getcustomasset(path)
    if not getgenv().originalSongId then
        getgenv().originalSongId = ls.SoundId
    end
    ls.SoundId = sound
    ls:Play()
    getgenv().isPlaying = true
end

-- 🎛️ GUI Section
Tabs.Custom:AddSection("↳ Last Man Standing")

Tabs.Custom:AddToggle("LMSReplacerSong", {
    Title = "LMS Replacer Song",
    Default = false,
    Callback = function(Value)
        getgenv().isToggleOn = Value
        local ls = getLastSurvivor()
        if not Value then
            if ls and getgenv().originalSongId then
                ls.SoundId = getgenv().originalSongId
                ls:Play()
            end
            getgenv().isPlaying = false
            getgenv().originalSongId = nil
        else
            if getgenv().selectedSong ~= "None" then
                setLastSurvivorSong(getgenv().selectedSong)
            elseif getgenv().customSongUrl then
                local path = downloadTrack("Custom_LMS_Song", getgenv().customSongUrl)
                if path then
                    local sound = getcustomasset(path)
                    if ls then
                        getgenv().originalSongId = ls.SoundId
                        ls.SoundId = sound
                        ls:Play()
                    end
                end
            end
        end
    end
})

local dropdown = Tabs.Custom:AddDropdown("CustomLMSSong", {
    Title = "Seclect LMS Song",
    Values = options,
    Multi = false,
    Default = "None",
    Callback = function(Value)
        getgenv().selectedSong = Value
        -- ❌ Gỡ bỏ dòng gây lỗi
        -- dropdown:SetValue(Value)
    end
})

Tabs.Custom:AddInput("CustomLMSSongURL", {
    Title = "Custom LMS",
    Default = "",
    Placeholder = "Enter raw MP3 URL",
    Callback = function(input)
        if input and input ~= "" then
            getgenv().customSongUrl = input
            if getgenv().isToggleOn then
                local ls = getLastSurvivor()
                if ls then
                    local path = downloadTrack("Custom_LMS_Song", input)
                    local sound = getcustomasset(path)
                    if not getgenv().originalSongId then
                        getgenv().originalSongId = ls.SoundId
                    end
                    ls.SoundId = sound
                    ls:Play()
                    getgenv().isPlaying = true
                end
            end
        end
    end
})

-- ♻️ Maintain playback
RunService.Heartbeat:Connect(function()
    local ls = getLastSurvivor()
    if getgenv().isToggleOn and ls then
        -- chỉ phát lại nếu chưa phát hoặc đã dừng
        if not ls.IsPlaying then
            setLastSurvivorSong(getgenv().selectedSong)
        end
    elseif not getgenv().isToggleOn and ls and getgenv().originalSongId and ls.SoundId ~= getgenv().originalSongId then
        -- khi tắt toggle, khôi phục nhạc gốc
        ls.SoundId = getgenv().originalSongId
        ls:Play()
        getgenv().isPlaying = false
    end
end)



Tabs.Custom:AddSection("↳ Victim")

-- HackerVibe_Toggle.lua
-- Hiệu ứng hacker thật 3D, có nút bật/tắt (Fake H4CK3R)
-- Bảo toàn sau khi chết, đổi character, không rung giật
-- Hiệu ứng hacker 3D + animation tự bật/tắt

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- ⚙️ CONFIG
local outlineColor = Color3.fromRGB(0, 255, 255)
local binarySpawnInterval = 0.12
local binaryLifetime = 1.8
local binaryRiseDistance = 5
local binaryMinScale = 0.6
local binaryMaxScale = 1.1
local maxSimultaneous = 40
local spawnRadius = 3
local animationId = "rbxassetid://86559211184601" -- 🧠 Animation Hacker

math.randomseed(tick() + player.UserId)

-- === Biến ===
local active = 0
local running = false
local folderName = "HackerFX3D"
local folder = nil
local animTrack = nil

-- === Danh sách part để spawn chữ ===
local partNames = {
	"Head","HumanoidRootPart",
	"UpperTorso","LowerTorso","Torso",
	"LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm",
	"LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg",
	"LeftHand","RightHand","LeftFoot","RightFoot"
}

local function getParts()
	character = player.Character or player.CharacterAdded:Wait()
	local list = {}
	for _, name in ipairs(partNames) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(list, part)
		end
	end
	return list
end

-- === Highlight Hacker ===
local function createHighlight()
	local old = character:FindFirstChild("HackerHighlight")
	if old then old:Destroy() end
	local h = Instance.new("Highlight")
	h.Name = "HackerHighlight"
	h.Adornee = character
	h.OutlineColor = outlineColor
	h.FillTransparency = 1
	h.OutlineTransparency = 0
	h.Parent = character
end

-- === Folder hiệu ứng ===
local function ensureFolder()
	folder = player:WaitForChild("PlayerGui"):FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = player:WaitForChild("PlayerGui")
	end
	return folder
end

-- === Hiệu ứng số bay ===
local function spawnBinary()
	if not running then return end
	if active >= maxSimultaneous then return end

	local parts = getParts()
	if #parts == 0 then return end
	local origin = parts[math.random(1, #parts)]
	if not origin then return end

	active += 1
	local s = ""
	for i = 1, math.random(1, 3) do
		s ..= tostring(math.random(0, 1))
	end

	local attach = Instance.new("Part")
	attach.Anchored = false
	attach.CanCollide = false
	attach.Transparency = 1
	attach.Size = Vector3.new(0.2, 0.2, 0.2)
	attach.Parent = ensureFolder()

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = attach
	weld.Part1 = origin
	weld.Parent = attach

	local xOff = (math.random() - 0.5) * spawnRadius
	local yOff = (math.random() - 0.5) * spawnRadius
	local zOff = (math.random() - 0.5) * spawnRadius
	attach.CFrame = origin.CFrame * CFrame.new(xOff, yOff, zOff)

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 80, 0, 30)
	bb.AlwaysOnTop = true
	bb.Adornee = attach
	bb.Parent = folder

	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency = 1
	txt.BorderSizePixel = 0
	txt.Size = UDim2.fromScale(1, 1)
	txt.Font = Enum.Font.Code
	txt.Text = s
	txt.TextColor3 = Color3.fromRGB(0, 255, 200)
	txt.TextScaled = true
	txt.TextTransparency = 0
	txt.Parent = bb
	txt.TextSize = 20 * (math.random() * (binaryMaxScale - binaryMinScale) + binaryMinScale)

	local goal = attach.Position + Vector3.new(0, binaryRiseDistance, 0)
	local moveTween = TweenService:Create(attach, TweenInfo.new(binaryLifetime, Enum.EasingStyle.Linear), {Position = goal})
	local fadeTween = TweenService:Create(txt, TweenInfo.new(binaryLifetime, Enum.EasingStyle.Linear), {TextTransparency = 1})
	moveTween:Play()
	fadeTween:Play()

	task.delay(binaryLifetime + 0.05, function()
		pcall(function()
			bb:Destroy()
			attach:Destroy()
		end)
		active = math.max(0, active - 1)
	end)
end

-- === Loop spawn chữ ===
task.spawn(function()
	while true do
		if running then
			spawnBinary()
		end
		task.wait(binarySpawnInterval)
	end
end)

-- === Khi respawn / đổi nhân vật ===
player.CharacterAdded:Connect(function(char)
	character = char
	task.wait(0.25)
	if running then
		createHighlight()

		-- 🔄 Phát lại animation nếu đang bật
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			local anim = Instance.new("Animation")
			anim.AnimationId = animationId
			animTrack = hum:LoadAnimation(anim)
			animTrack:Play()
			animTrack.Looped = true
		end
	end
end)

-- === HÀM CHÍNH BẬT / TẮT ===
local function ToggleFakeHacker(state)
	running = state

	local highlight = character:FindFirstChild("HackerHighlight")
	if not highlight and state then
		createHighlight()
	end

	if highlight then
		highlight.OutlineTransparency = state and 0 or 1
	end

	if state then
		ensureFolder().Parent = player:WaitForChild("PlayerGui")

		-- 🎬 Bắt đầu animation
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			local anim = Instance.new("Animation")
			anim.AnimationId = animationId
			animTrack = hum:LoadAnimation(anim)
			animTrack.Looped = true
			animTrack:Play()
		end
	else
		-- 🛑 Dừng animation
		if animTrack then
			animTrack:Stop()
			animTrack:Destroy()
			animTrack = nil
		end

		-- 🧹 Xóa hiệu ứng chữ
		local f = player.PlayerGui:FindFirstChild(folderName)
		if f then
			for _, v in ipairs(f:GetChildren()) do
				v:Destroy()
			end
		end
	end
end

-- === GẮN VÀO UI (ví dụ Fluent) ===
Tabs.Custom:AddToggle("FakeH4CK3R", {
	Title = "Fake H4CK3R",
	Default = false,
	Callback = function(Value)
		ToggleFakeHacker(Value)
	end
})


-- Tabs.Player



-- ======= DỊCH VỤ =======
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ======= WHITELIST =======
local AllowedPlayers = {
    ["Noob"] = true, ["Guest1337"] = true, ["Elliot"] = true,
    ["Shedletsky"] = true, ["TwoTime"] = true, ["007n7"] = true,
    ["Chance"] = true, ["Builderman"] = true, ["Taph"] = true,
    ["Dusekkar"] = true, ["Veeronica"] = true,
}

local AllowedKillers = {
    ["Slasher"] = true, ["1x1x1x1"] = true, ["c00lkidd"] = true,
    ["Noli"] = true, ["JohnDoe"] = true, ["Guest 666"] = true,
    ["Sixer"] = true,
}

-- ======= BIẾN TRẠNG THÁI =======
local AimlockPlayerEnabled = false
local AimlockKillerEnabled = false
local CurrentTarget = nil
local lastHumanoidAutoRotate = nil

-- ======= HÀM HỖ TRỢ =======
local function IsAllowed(model, list)
    return list[model.Name] == true
end

local function GetModelFromPlayer(plr, list)
    if not plr.Character then return nil end
    if IsAllowed(plr.Character, list) and plr.Character:FindFirstChildWhichIsA("Humanoid") then
        return plr.Character
    end
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChildWhichIsA("Humanoid") then
            if model:FindFirstChild("Owner") and model.Owner.Value == plr then
                if IsAllowed(model, list) then
                    return model
                end
            end
        end
    end
    return nil
end

local function GetClosestTarget(list)
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local closest, dist = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local model = GetModelFromPlayer(plr, list)
            if model and model.PrimaryPart then
                local humanoid = model:FindFirstChildWhichIsA("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local distance = (model.PrimaryPart.Position - myRoot.Position).Magnitude
                    if distance < dist then
                        dist = distance
                        closest = model
                    end
                end
            end
        end
    end
    return closest
end

local function ValidateTarget(target)
    if not target then return false end
    local humanoid = target:FindFirstChildWhichIsA("Humanoid")
    return humanoid and humanoid.Health > 0 and target.PrimaryPart ~= nil
end

-- reset khi respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    CurrentTarget = nil
    if lastHumanoidAutoRotate ~= nil then
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if hum then
            hum.AutoRotate = lastHumanoidAutoRotate
        end
        lastHumanoidAutoRotate = nil
    end
end)

-- ======= AIMBOT LOOP (fix: hướng đúng, không bị đen màn hình) =======
RunService.RenderStepped:Connect(function()
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local humanoid = myChar and myChar:FindFirstChildWhichIsA("Humanoid")

    if not myRoot then return end

    -- toggle AutoRotate
    if (AimlockPlayerEnabled or AimlockKillerEnabled) and humanoid then
        if lastHumanoidAutoRotate == nil then
            lastHumanoidAutoRotate = humanoid.AutoRotate
        end
        humanoid.AutoRotate = false
    elseif humanoid and lastHumanoidAutoRotate ~= nil then
        humanoid.AutoRotate = lastHumanoidAutoRotate
        lastHumanoidAutoRotate = nil
    end

    -- hàm xoay nhìn target (fix: dùng lookVector:Cross(up) để rightVector đúng)
    local function faceTarget(target)
        if not target or not target.PrimaryPart then return end
        local pos = myRoot.Position
        local targetPos = target.PrimaryPart.Position
        local dir = Vector3.new(targetPos.X, pos.Y, targetPos.Z) - pos
        if dir.Magnitude == 0 then return end

        local lookVector = dir.Unit
        local up = Vector3.yAxis
        local rightVector = lookVector:Cross(up) -- CHỈNH: right = look x up (không ngược)
        if rightVector.Magnitude == 0 then
            rightVector = Vector3.new(1, 0, 0)
        else
            rightVector = rightVector.Unit
        end

        -- fromMatrix(position, rightVector, up) — chỉ thay orientation, giữ nguyên vị trí
        myRoot.CFrame = CFrame.fromMatrix(pos, rightVector, up)
    end

    if AimlockPlayerEnabled then
        if not ValidateTarget(CurrentTarget) then
            CurrentTarget = GetClosestTarget(AllowedPlayers)
        end
        if ValidateTarget(CurrentTarget) then
            faceTarget(CurrentTarget)
        end
    elseif AimlockKillerEnabled then
        if not ValidateTarget(CurrentTarget) then
            CurrentTarget = GetClosestTarget(AllowedKillers)
        end
        if ValidateTarget(CurrentTarget) then
            faceTarget(CurrentTarget)
        end
    else
        CurrentTarget = nil
    end
end)

-- ======= FLUENT TOGGLES =======
Tabs.Player:AddToggle("ForsakenAimbot", {
    Title = "Aimbot Player",
    Default = false
}):OnChanged(function(v)
    AimlockPlayerEnabled = v
    if v then 
        AimlockKillerEnabled = false
        CurrentTarget = nil
    end
end)

Tabs.Player:AddToggle("ForsakenAimbot1", {
    Title = "Aimbot Killer",
    Default = false
}):OnChanged(function(v)
    AimlockKillerEnabled = v
    if v then 
        AimlockPlayerEnabled = false
        CurrentTarget = nil
    end
end)






    Tabs.Player:AddSection("↳ Cheats")

local ActiveNoStun = false
local noStunLoop

Tabs.Player:AddToggle("NoStunToggle", {
    Title = "No Stun",
    Default = false,
}):OnChanged(function(value)
    ActiveNoStun = value

    if value then
        -- Nếu có loop cũ thì dừng
        if noStunLoop then
            task.cancel(noStunLoop)
            noStunLoop = nil
        end

        -- Tạo loop mới liên tục đảm bảo HumanoidRootPart không bị anchore
        noStunLoop = task.spawn(function()
            while ActiveNoStun do
                local character = game.Players.LocalPlayer.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Anchored = false
                end
                task.wait(0.1) -- Không cần quá nhanh, tránh lag
            end
        end)
    else
        -- Tắt loop khi toggle off
        if noStunLoop then
            task.cancel(noStunLoop)
            noStunLoop = nil
        end
    end
end)






local InfStaminaEnabled = false  
local staminaLoop  
local StaminaModule  
  
-- Thử lấy module an toàn  
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
        -- Nếu module có hàm "SetStamina" thì dùng  
        if typeof(StaminaModule.SetStamina) == "function" then  
            StaminaModule:SetStamina(maxStamina)  

        -- Nếu có hàm "UpdateStamina" thì dùng  
        elseif typeof(StaminaModule.UpdateStamina) == "function" then  
            StaminaModule:UpdateStamina(maxStamina)  

        -- Nếu không có thì set trực tiếp  
        else  
            StaminaModule.Stamina = maxStamina  
        end  
    end  
end  
  
-- Chỉ tạo toggle nếu module tồn tại  
if StaminaModule then  
    Tabs.Player:AddToggle("InfStamina", {  
        Title = "Infinite Stamina",  
        Default = false  
    }):OnChanged(function(value)  
        -- luôn bọc trong pcall để Fluent không báo "Callback error"  
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
            -- Bật zoom vô hạn
            player.CameraMaxZoomDistance = math.huge
            player.CameraMinZoomDistance = 0.5
            print("[ZoomCam] Infinite Zoom Enabled ✅")
        else
            -- Tắt zoom vô hạn, trở lại bình thường
            player.CameraMaxZoomDistance = 128
            player.CameraMinZoomDistance = 0.5
            print("[ZoomCam] Infinite Zoom Disabled ❌")
        end
    end
})



    Tabs.Player:AddSection("↳ Troller")




Tabs.Player:AddButton({
    Title = "Fake Block",
    Callback = function()
        -- Tạo Animation object
        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://72722244508749"

        -- Lấy Humanoid của nhân vật
        local player = game.Players.LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if humanoid then
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if not animator then
                animator = Instance.new("Animator")
                animator.Parent = humanoid
            end

            -- Load và Play animation
            local animTrack = animator:LoadAnimation(animation)
            animTrack:Play()
        end
    end
})



Tabs.Player:AddButton({
    Title = "Fake Punch",
    Callback = function()
        -- Tạo Animation object
        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://87259391926321"

        -- Lấy Humanoid của nhân vật
        local player = game.Players.LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if humanoid then
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if not animator then
                animator = Instance.new("Animator")
                animator.Parent = humanoid
            end

            -- Load và Play animation
            local animTrack = animator:LoadAnimation(animation)
            animTrack:Play()
        end

        -- Âm thanh đầu tiên
        local sound1 = Instance.new("Sound")
        sound1.SoundId = "rbxassetid://81976396729343"
        sound1.Parent = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        sound1:Play()

        -- Sau 0.75 giây thì tắt sound1 và phát sound2
        task.delay(0.75, function()
            if sound1.IsPlaying then
                sound1:Stop()
            end
            local sound2 = Instance.new("Sound")
            sound2.SoundId = "rbxassetid://122560631718612"
            sound2.Parent = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
            sound2:Play()
        end)
    end
})




Tabs.Player:AddButton({
    Title = "Fake Punch v2",
    Callback = function()
        -- Tạo Animation object
        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://86709774283672"

        -- Lấy Humanoid của nhân vật
        local player = game.Players.LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if humanoid then
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if not animator then
                animator = Instance.new("Animator")
                animator.Parent = humanoid
            end

            -- Load và Play animation
            local animTrack = animator:LoadAnimation(animation)
            animTrack:Play()
        end

        -- Âm thanh đầu tiên
        local sound1 = Instance.new("Sound")
        sound1.SoundId = "rbxassetid://81976396729343"
        sound1.Parent = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        sound1:Play()

        -- Sau 0.5 giây thì tắt sound1 và phát sound2
        task.delay(0.5, function()
            if sound1.IsPlaying then
                sound1:Stop()
            end
            local sound2 = Instance.new("Sound")
            sound2.SoundId = "rbxassetid://122560631718612"
            sound2.Parent = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
            sound2:Play()
        end)
    end
})



do
-- Lưu callback Backflip để toggle gọi lại
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
    local dir = cf.LookVector -- ✅ bay theo hướng nhìn
    local up = Vector3.yAxis

    task.spawn(function()
        local t0 = tick()
        for i = 1, s do
            local t = i / s
            local y = 4 * (t - t ^ 2) * 10
            local targetPos = cf.Position + dir * (35 * t) + up * y
            local r = CFrame.Angles(math.rad(360 * t), 0, 0)

            -- ✅ Raycast check trước khi PivotTo
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {char}
            rayParams.FilterType = Enum.RaycastFilterType.Blacklist

            local result = workspace:Raycast(hrp.Position, (targetPos - hrp.Position), rayParams)

            if result then
                -- Nếu có tường chặn → dừng tại vị trí va chạm
                targetPos = result.Position + result.Normal * 2
            end

            char:PivotTo(CFrame.new(targetPos) * cf.Rotation * r)

            local wt = (d / s) * i - (tick() - t0)
            if wt > 0 then task.wait(wt) end
        end

        -- Kiểm tra va chạm tại điểm kết thúc
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

-- Nút Backflip
Tabs.Player:AddButton({
    Title = "Backflip",
    -- Description = "Perform a backflip",
    Callback = doBackflip
})

-- Toggle Auto Backflip
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

    -- Animation object
    local fakeFixAnim = Instance.new("Animation")
    fakeFixAnim.AnimationId = "rbxassetid://82691533602949"

    local animator, fakeFixTrack

    -- Hàm tìm animator của nhân vật
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

    -- Toggle UI
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
-- Fake Die Toggle (start at 50%, stop at 90%)
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
        -- === BẬT Fake Die ===
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://118795597134269"

        local track = hum:LoadAnimation(anim)
        track:Play()

        -- Nhảy thẳng đến 50%
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
        -- === TẮT Fake Die ===
        local data = getgenv().FakeDieData
        if data.track then
            data.track:Stop()
            data.track = nil
        end
        if data.conn then
            data.conn:Disconnect()
            data.conn = nil
        end

        -- Khôi phục animation mặc định (idle)
        pcall(function()
            hum:PlayEmote("idle")
        end)
    end
end)
end





    Tabs.Player:AddSection("↳ Hitbox")


repeat task.wait() until game:IsLoaded()

-- biến cấu hình
local ForsakenReachEnabled = false
local NearestDist = 120

-- thêm toggle + slider vào Fluent (Tabs.Player bạn đã có sẵn)
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

-- services & player setup
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

-- full danh sách animations giữ nguyên từ code 1
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
    'rbxassetid://105458270463374'
}

-- danh sách model killers và survivors (theo yêu cầu của bạn)
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

-- gom reach logic thành hàm (đã chỉnh để ưu tiên nhắm phe đối nghịch nếu bạn ở dạng model)
local function ForsakenReachLogic()
    if not ForsakenReachEnabled or not HumanoidRootPart then
        return
    end

    -- kiểm tra animation attack (giữ nguyên)
    local Playing = false
    for _,v in Humanoid:GetPlayingAnimationTracks() do
        if table.find(AttackAnimations, v.Animation.AnimationId) and (v.TimePosition / v.Length < 0.75) then
            Playing = true
        end
    end

    if not Playing then
        return
    end

    -- xác định bạn đang là model thuộc phe nào (nếu có)
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

    -- 1) Nếu bạn đang là model (có OppositeTable), ưu tiên tìm mục tiêu thuộc phe đối nghịch trước
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

    -- 2) Nếu không tìm được phe đối nghịch thì fallback về logic gốc nhưng vẫn bỏ qua model cùng phe với bạn
    local function loopAll(t)
        for _,v in pairs(t) do
            if v == Character or not v:FindFirstChild("HumanoidRootPart") or not v:FindFirstChild("Humanoid") then
                continue
            end
            local modelName = v.Name
            -- bỏ qua cùng phe nếu bạn đang ở dạng model
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

    -- nếu tìm thấy OppTarget thì dùng luôn, không cần tìm tiếp
    local FinalTarget = nil
    if OppTarget then
        FinalTarget = OppTarget
    else
        -- fallback: quét players + npcs giống trước nhưng đã loại cùng phe
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

    -- giữ nguyên phần tính velocity + áp dụng hit
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

-- vòng lặp auto gọi lại mỗi 0s (giữ nguyên)
task.spawn(function()
    while true do
        task.wait(0)
        pcall(ForsakenReachLogic)
    end
end)




    Tabs.Player:AddSection("↳ Walk Speed")


local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ValueSpeed = 16
local ActiveSpeedBoost = false
local speedLoop

local function setSpeed(speed)
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = speed
        humanoid:SetAttribute("BaseSpeed", speed)
    end
end

-- Khi respawn áp dụng lại tốc độ nếu bật
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.1)
    if ActiveSpeedBoost then
        setSpeed(ValueSpeed)
    end
end)

-- Slider chỉnh tốc độ
Tabs.Player:AddSlider("PlayerSpeedSlider", {
    Title = "Set Speed",
    Min = 0,
    Max = 40,
    Default = ValueSpeed,
    Rounding = 1,
}):OnChanged(function(value)
    ValueSpeed = value
    if ActiveSpeedBoost then
        setSpeed(ValueSpeed)
    end
end)

-- Toggle bật/tắt tốc độ và loop tăng tốc liên tục
Tabs.Player:AddToggle("PlayerSpeedToggle", {
    Title = "Walk Speed",
    Default = false,
}):OnChanged(function(value)
    ActiveSpeedBoost = value
    if value then
        setSpeed(ValueSpeed)
        -- Bắt đầu vòng lặp liên tục set tốc độ mỗi 0.5 giây
        speedLoop = task.spawn(function()
            while ActiveSpeedBoost do
                setSpeed(ValueSpeed)
                task.wait(0.5)
            end
        end)
    else
        -- Tắt vòng lặp và reset tốc độ về mặc định 16
        if speedLoop then
            speedLoop = nil
        end
        setSpeed(16)
    end
end)



    Tabs.Player:AddSection("↳ Teleport Speed")


-- === Teleport Speed Setup ===
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HRP = Character:WaitForChild("HumanoidRootPart")

local defaultSpeed = 50
local maxSpeed = 300
local currentSpeed = defaultSpeed
local teleportSpeedEnabled = false

-- Cập nhật lại khi respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = Character:WaitForChild("Humanoid")
    HRP = Character:WaitForChild("HumanoidRootPart")
end)

-- Loop để dịch chuyển (teleport speed)
RunService.Heartbeat:Connect(function(dt)
    if teleportSpeedEnabled and Humanoid and HRP then
        if Humanoid.MoveDirection.Magnitude > 0 then
            local moveDir = Humanoid.MoveDirection.Unit
            HRP.CFrame = HRP.CFrame + (moveDir * (currentSpeed * dt))
        end
    end
end)

-- === GUI Bindings ===
-- Slider Teleport Speed
Tabs.Player:AddSlider("TeleportSpeedSlider", {
    Title = "Set Speed",
    Min = 1,
    Max = maxSpeed,
    Default = defaultSpeed,
    Rounding = 1,
}):OnChanged(function(value)
    currentSpeed = value
end)

-- Toggle bật/tắt Teleport Speed
Tabs.Player:AddToggle("TeleportSpeedToggle", {
    Title = "Teleport Speed",
    Default = false,
}):OnChanged(function(enabled)
    teleportSpeedEnabled = enabled
end)

     

-- Tabs.Visual

--// ⚙️ ESP Loại: Clone, Player, Survivors, Killers, Generator, Items, Buildman
--// Tất cả đều dùng chung ESPManager (đã định nghĩa ở trên)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-----------------------------------------------------
-- 🟢 1. CLONE ESP
-----------------------------------------------------
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


-----------------------------------------------------
-- 🔵 2. PLAYER ESP
-----------------------------------------------------

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


-----------------------------------------------------
-- ⚪ 3. SURVIVORS ESP (có HP)
-----------------------------------------------------
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


-----------------------------------------------------
-- 🔴 4. KILLERS ESP (có HP)
-----------------------------------------------------
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


-----------------------------------------------------
-- ⚙️ 5. GENERATOR ESP
-----------------------------------------------------

    Tabs.Visual:AddSection("↳ Other")

_G.ESPManager:RegisterType("Generator", Color3.fromRGB(255,255,255), function(obj)
    if not (obj and obj:IsA("Model") and obj.Name == "Generator") then
        return false
    end

    local progress = obj:FindFirstChild("Progress", true)
    if not progress or not progress:IsA("NumberValue") then
        return false
    end

    -- Gắn kết một lần để theo dõi khi Progress.Value thay đổi
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

    -- Chỉ hiển thị khi chưa hoàn thành
    return progress.Value < 100
end, false)

Tabs.Visual:AddToggle("ESPGeneratorToggle", {
    Title = "ESP Generator",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Generator", state)
end)


-----------------------------------------------------
-- 🟡 6. ITEMS ESP
-----------------------------------------------------
_G.ESPManager:RegisterType("Item", Color3.fromRGB(255,215,0), function(obj)
    return obj:IsA("Tool") and obj.Parent and obj:IsDescendantOf(workspace:FindFirstChild("Map"))
end, false)

Tabs.Visual:AddToggle("ESPItemsToggle", {
    Title = "ESP Items",
    Default = false,
}):OnChanged(function(state)
    _G.ESPManager:SetEnabled("Item", state)
end)


-----------------------------------------------------
-- 🟣 7. BUILDMAN ESP
-----------------------------------------------------
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

-- ✅ FullBright Settings
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

-- ✅ Toggle: FullBright
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

-- ✅ Remove Fog Settings
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

-- ✅ Toggle: Remove Fog
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

-- Flag bật/tắt
local ActiveRemoveAll = false

-- Danh sách tên hiệu ứng thường gặp
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

-- 🌟 Hàm xoá tất cả (effects + popups)
local function removeAll()
    -- Xoá hiệu ứng trong Lighting
    for _, obj in pairs(Lighting:GetDescendants()) do
        if table.find(effectNames, obj.Name) or table.find(effectClasses, obj.ClassName) then
            obj:Destroy()
        end
    end

    -- Xoá GUI overlay
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

    -- Xoá popup 1x1x1x1
    local temp = PlayerGui:FindFirstChild("TemporaryUI")
    if temp then
        local popup = temp:FindFirstChild("1x1x1x1Popup")
        if popup then
            popup:Destroy()
            warn("[Remover] 1x1x1x1Popup removed")
        end
    end
end

-- Toggle Fluent - chỉ 1 cái
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



    Tabs.Misc:AddSection("↳ Server")


------------------------------------------------------------
-- ⚡ SERVER HOP (Mobile-friendly + Fluent Button)
------------------------------------------------------------

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 🌀 Hàm thực hiện teleport sang server mới
local function ServerHop()
    local placeId = game.PlaceId
    local jobId = game.JobId
    print("[ServerHop] Đang rời server hiện tại...")

    -- pcall để tránh lỗi Teleport crash
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


------------------------------------------------------------
-- 🧩 THÊM NÚT TRONG FLUENT UI
------------------------------------------------------------

-- Giả sử bạn có tab Dev sẵn, tương tự ví dụ của bạn:
-- Tabs.Dev:AddButton(...)

Tabs.Misc:AddButton({
    Title = "Rejoin To Fix Lag",
    Description = "Tham Gia Lại Máy Chủ Để Giảm Lag",
    Callback = function()
        -- Hiện thông báo chuẩn bị
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



-- 🌐 Server Hop Button
Tabs.Misc:AddButton({
    Title = "Server Hop To Low Player",
    Description = "Dùng Để Đổi Server Có Thể Vào Server Ít Player",
    Callback = function()
        local PlaceID = game.PlaceId
        local AllIDs = {}
        local foundAnything = ""
        local actualHour = os.date("!*t").hour

        -- Đọc file nếu có
        local File = pcall(function()
            AllIDs = game:GetService("HttpService"):JSONDecode(readfile("NotSameServers.json"))
        end)

        if not File then
            table.insert(AllIDs, actualHour)
            writefile("NotSameServers.json", game:GetService("HttpService"):JSONEncode(AllIDs))
        end

        local function TPReturner()
            local Site
            if foundAnything == "" then
                Site = game.HttpService:JSONDecode(game:HttpGet(
                    "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100"
                ))
            else
                Site = game.HttpService:JSONDecode(game:HttpGet(
                    "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. foundAnything
                ))
            end

            if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
                foundAnything = Site.nextPageCursor
            end

            local num = 0
            for _, v in pairs(Site.data) do
                local Possible, ID = true, tostring(v.id)
                if tonumber(v.maxPlayers) > tonumber(v.playing) then
                    for _, Existing in pairs(AllIDs) do
                        if num ~= 0 then
                            if ID == tostring(Existing) then
                                Possible = false
                            end
                        else
                            if tonumber(actualHour) ~= tonumber(Existing) then
                                pcall(function()
                                    delfile("NotSameServers.json")
                                    AllIDs = {}
                                    table.insert(AllIDs, actualHour)
                                end)
                            end
                        end
                        num = num + 1
                    end
                    if Possible then
                        table.insert(AllIDs, ID)
                        pcall(function()
                            writefile("NotSameServers.json", game:GetService("HttpService"):JSONEncode(AllIDs))
                            game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
                        end)
                        task.wait(4)
                    end
                end
            end
        end

        local function Teleport()
            while task.wait() do
                pcall(function()
                    TPReturner()
                    if foundAnything ~= "" then
                        TPReturner()
                    end
                end)
            end
        end

        -- Gọi để bắt đầu Server Hop
        Teleport()
    end
})




    Tabs.Misc:AddSection("↳ Bypass")

local antiAFKCons = {}

-- Chỉ tạo toggle nếu executor có getconnections
if getconnections then
    Tabs.Misc:AddToggle("AntiAFK", {
        Title = "Anti-AFK",
        Default = true
    }):OnChanged(function(state)
        local idleCons = getconnections(game.Players.LocalPlayer.Idled)
        
        if state then
            -- Lưu & disable
            for _, c in ipairs(idleCons) do
                antiAFKCons[c] = true
                c:Disable()
            end
            print("[AntiAFK] Đã bật, bạn sẽ không bị kick AFK.")
        else
            -- Enable lại
            for c,_ in pairs(antiAFKCons) do
                if c and c.Enable then
                    pcall(function() c:Enable() end)
                end
            end
            antiAFKCons = {}
            print("[AntiAFK] Đã tắt, Roblox sẽ xử lý AFK bình thường.")
        end
    end)
else
    warn("[AntiAFK] Executor không hỗ trợ getconnections, toggle bị vô hiệu.")
end






do
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local LocalizationService = game:GetService("LocalizationService")

    shared.AntiBanSafe = shared.AntiBanSafe or {running = false, hooks = {}}
    local data = shared.AntiBanSafe

    local oldNamecall, oldIndex
    local protectionThread

    local function safe(func, ...)
        local ok, res = pcall(func, ...)
        if ok then return res end
    end

    -- Disable screenshot/video flags khi bật protection
    local function disableReportFlags()
        if typeof(setfflag) == "function" then
            pcall(function()
                setfflag("AbuseReportScreenshot", "False")
                setfflag("AbuseReportScreenshotPercentage", "0") -- chỉnh về 0
                setfflag("AbuseReportEnabled", "False")
                setfflag("ReportAbuseMenu", "False")
                setfflag("EnableAbuseReportScreenshot", "False")
                setfflag("AbuseReportVideo", "False")
                setfflag("AbuseReportVideoPercentage", "0")
                setfflag("VideoCaptureEnabled", "False")
                setfflag("RecordVideo", "False")
            end)
        end
    end

    -- Restore flag về bình thường khi tắt protection
    local function setFlagsOn()
        if typeof(setfflag) == "function" then
            pcall(function()
                setfflag("AbuseReportScreenshot", "True")
                setfflag("AbuseReportScreenshotPercentage", "100")
            end)
        end
    end

    -- Hook requests (block report)
    local function hookRequests()
        if data.hooks.requestHooked then return end
        local oldRequest = (syn and syn.request) or request or http_request
        if typeof(oldRequest) == "function" and typeof(hookfunction) == "function" then
            hookfunction(oldRequest, function(req)
                if req and req.Url and tostring(req.Url):lower():find("abuse") then
                    return {StatusCode = 200, Body = "Blocked"}
                end
                return oldRequest(req)
            end)
            data.hooks.requestHooked = true
        end
    end

    -- Hook FindFirstChild (block GUI video/screenshot)
    local function hookFindFirstChild()
        if data.hooks.findHooked then return end
        local oldFind = workspace.FindFirstChild
        if typeof(oldFind) == "function" and typeof(hookfunction) == "function" then
            hookfunction(oldFind, function(self, name, ...)
                if name and tostring(name):lower():find("screenshot") then return nil end
                if name and tostring(name):lower():find("video") then return nil end
                return oldFind(self, name, ...)
            end)
            data.hooks.findHooked = true
        end
    end

    -- Safe bypass (__namecall)
    local function safeBypass()
        if getrawmetatable and hookmetamethod and newcclosure then
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            oldNamecall = oldNamecall or mt.__namecall
            oldIndex = oldIndex or mt.__index

            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}

                -- Block LocalPlayer kick/ban
                if (method == "Kick" or method == "Ban") and self == LocalPlayer then return nil end

                -- Block remote kick/ban
                if (method == "FireServer" or method == "InvokeServer") and args[1] then
                    local msg = tostring(args[1]):lower()
                    if msg:find("kick") or msg:find("ban") then return nil end
                end

                -- Block LocalizationService
                if self == LocalizationService and method == "GetCountryRegionForPlayerAsync" then
                    local success, result = pcall(function()
                        return LocalizationService:GetCountryRegionForPlayerAsync(LocalPlayer)
                    end)
                    if success then return result else return "US" end
                end

                return oldNamecall(self, ...)
            end)

            mt.__index = newcclosure(function(t, k)
                local key = tostring(k):lower()
                if key:find("kick") or key:find("ban") then return function() return nil end end
                return oldIndex(t, k)
            end)

            setreadonly(mt, true)
        end
    end

    -- Restore hooks
    local function restoreHooks()
        if getrawmetatable then
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            if oldNamecall then mt.__namecall = oldNamecall end
            if oldIndex then mt.__index = oldIndex end
            setreadonly(mt, true)
            oldNamecall, oldIndex = nil, nil
        end
    end

    -- Start protection
    local function startAntiBanSafe()
        if data.running then return end
        data.running = true

        safe(hookRequests)
        safe(hookFindFirstChild)
        safe(safeBypass)

        -- Disable screenshot/video
        protectionThread = task.spawn(function()
            while data.running do
                safe(disableReportFlags)
                task.wait(0.2)
            end
        end)

        print("[Anti-Ban Safe] 🛡️ ENABLED!")
    end

    -- Stop protection
    local function stopAntiBanSafe()
        data.running = false
        protectionThread = nil
        restoreHooks()
        setFlagsOn() -- phục hồi flag về bình thường
        print("[Anti-Ban Safe] ⚠️ DISABLED!")
    end

    -- Toggle
    Tabs.Misc:AddToggle("AntiBanV3", {
        Title = "Anti Ban V3.5",
        Default = true,
        Callback = function(state)
            if state then
                startAntiBanSafe()
            else
                stopAntiBanSafe()
            end
        end
    })
end






do
-- === SafeGenTeleport (Anti: ALL Moving Models/Parts/Effects) ===
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local SafeGenRunning = false
local SafeGenThread
local DetectRadius = 20 -- mặc định 20, có thể chỉnh bằng ô input

-- Danh sách account thật dùng V2
local AllowedPlayers = {
    ["Hu1a0_Hu9"] = true,
    ["hdksakst"] = true
}

-- Danh sách Killers
local DangerousKillers = {
    Slasher = true, ["1x1x1x1"] = true, c00lkidd = true,
    Noli = true, JohnDoe = true, ["Guest 666"] = true,
    PizzaDeliveryRig = true, Mafia1 = true, Mafia2 = true,
    ["1x1x1x1Zombie"] = true, ["Sixer"] = true
}

-- Danh sách Clones (coi như Killers)
local DangerousClones = {
    PizzaDeliveryRig = true, Mafia1 = true, Mafia2 = true,
    ["1x1x1x1Zombie"] = true
}

-- Danh sách Survivors (bạn có thể biến thành)
local Survivors = {
    Noob = true, Guest1337 = true, Elliot = true, Shedletsky = true,
    TwoTime = true, ["007n7"] = true, Chance = true,
    Builderman = true, Taph = true, Dusekkar = true
}

-- Whitelist
local SafeObjects = {Pet=true, Decoration=true, Terrain=true, Map=true}

-- Cấu hình detect
local MOVE_THRESHOLD = 0.5
local VEL_THRESHOLD  = 1
local SCAN_DELAY     = 0.12

local lastPositions = {}

local function findOwningCharacter(inst)
    local cur = inst
    while cur and cur ~= workspace and cur.Parent do
        if cur:IsA("Model") then
            local p = Players:GetPlayerFromCharacter(cur)
            if p then return cur, p end
        end
        cur = cur.Parent
    end
    return nil, nil
end

local function hasForceOnPart(part)
    if not part then return false end
    if part:FindFirstChildOfClass("BodyVelocity")
    or part:FindFirstChildOfClass("BodyPosition")
    or part:FindFirstChildOfClass("BodyForce")
    or part:FindFirstChildOfClass("BodyGyro")
    or part:FindFirstChildOfClass("LinearVelocity")
    or part:FindFirstChildOfClass("VectorForce")
    or part:FindFirstChildOfClass("AlignPosition")
    or part:FindFirstChildOfClass("AlignOrientation") then
        return true
    end
    return false
end

local function isPartMoving(part)
    if not part or not part:IsA("BasePart") then return false end
    local ok, asmVel = pcall(function() return part.AssemblyLinearVelocity end)
    local velMag = (ok and asmVel) and asmVel.Magnitude or 0
    if velMag == 0 then
        local ok2, v2 = pcall(function() return part.Velocity end)
        if ok2 and v2 then velMag = v2.Magnitude end
    end
    local last = lastPositions[part]
    local pos = part.Position
    local moved = false
    if last then
        if (pos - last).Magnitude >= MOVE_THRESHOLD then moved = true end
    else
        if velMag >= VEL_THRESHOLD or hasForceOnPart(part) then moved = true end
    end
    lastPositions[part] = pos
    if velMag >= VEL_THRESHOLD or hasForceOnPart(part) then moved = true end
    return moved
end

local function pruneLastPositions()
    for inst,_ in pairs(lastPositions) do
        if not inst or not inst.Parent then lastPositions[inst] = nil end
    end
end

-- 🔎 Phát hiện nguy hiểm gần
local function isDangerNear(position, radius)
    local killersFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers")
    if killersFolder then
        for _, killer in ipairs(killersFolder:GetChildren()) do
            local hrp = killer:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position - position).Magnitude
                if (DangerousKillers[killer.Name] or DangerousClones[killer.Name]) and dist <= radius then
                    return true, hrp.Position
                end
            end
        end
    end
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("BasePart") and not SafeObjects[inst.Name] then
            local dist = (inst.Position - position).Magnitude
            if dist <= radius and isPartMoving(inst) then
                local charModel, playerOwner = findOwningCharacter(inst)
                if playerOwner then
                    local charName = charModel and charModel.Name or ""
                    if DangerousKillers[charName] or DangerousClones[charName] then
                        return true, inst.Position
                    end
                else
                    return true, inst.Position
                end
            end
        end
    end
    pruneLastPositions()
    return false, nil
end

-- 📌 Tìm vị trí an toàn cách xa danger 7 stud
local function getSafePosFromDanger(myPos, dangerPos, safeDist)
    local dir = (myPos - dangerPos).Unit
    local target = myPos + dir * safeDist
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LP.Character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local rayResult = workspace:Raycast(myPos + Vector3.new(0,3,0), dir*safeDist, rayParams)
    if rayResult then
        local perp1 = Vector3.new(-dir.Z,0,dir.X).Unit
        local perp2 = -perp1
        if not workspace:Raycast(myPos+Vector3.new(0,3,0), perp1*safeDist, rayParams) then
            return myPos + perp1*safeDist
        elseif not workspace:Raycast(myPos+Vector3.new(0,3,0), perp2*safeDist, rayParams) then
            return myPos + perp2*safeDist
        else
            return myPos + Vector3.new(0,0,safeDist)
        end
    end
    return target
end

-- 🚀 Lùi ra xa 7 stud khỏi nguy hiểm (giữ hướng nhìn, bước nhỏ siêu nhanh)
local function teleportAwayFromDanger()
    local character = LP.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local myPos = hrp.Position
    local isNear, dangerPos = isDangerNear(myPos, DetectRadius)
    if isNear and dangerPos then
        local safePos = getSafePosFromDanger(myPos, dangerPos, 7)

        local dir = (safePos - myPos).Unit
        local totalDist = (safePos - myPos).Magnitude
        local stepSize = 1.2
        local stepDelay = 0.01
        local steps = math.ceil(totalDist / stepSize)

        for i = 1, steps do
            local stepPos = myPos + dir * (i * stepSize)
            hrp.CFrame = CFrame.new(stepPos, stepPos + hrp.CFrame.LookVector)
            task.wait(stepDelay)
        end

        print("⚠️ Né nguy hiểm bằng nhiều bước nhỏ (giữ hướng nhìn)!")
    end
end

-- === GUI Control ===
Tabs.Misc:AddToggle("SafeGenTeleport", {
    Title = "Anti Killers V7",
    Default = false
}):OnChanged(function(state)
    SafeGenRunning = state
    if state then
        SafeGenThread = task.spawn(function()
            local delayTime = SCAN_DELAY
            if AllowedPlayers[LP.Name] then
                print("🚀 V2 Mode enabled for:", LP.Name)
                delayTime = 0.000000000001
            else
                print("🐢 V1 Mode enabled for:", LP.Name)
            end
            while SafeGenRunning do
                local character = LP.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local charName = character.Name
                    if DangerousKillers[charName] or DangerousClones[charName] then
                        -- bạn là killer → không né
                    elseif Survivors[charName] or charName == LP.Name then
                        teleportAwayFromDanger()
                    end
                end
                task.wait(delayTime)
            end
        end)
    else
        SafeGenRunning = false
        SafeGenThread = nil
        print("[SafeGenTeleport] Đã tắt.")
    end
end)

-- 📝 Input box chỉnh khoảng cách DetectRadius (1 - 100, mặc định 20)
Tabs.Misc:AddInput("DetectRadiusInput", {
    Title = "Detect Radius",
    Default = "20",
    Placeholder = "1 - 100"
}):OnChanged(function(value)
    local num = tonumber(value)
    if num then
        num = math.clamp(num, 1, 100)
        DetectRadius = num
        print("🔧 DetectRadius set to:", DetectRadius)
    end
end)

end



    Tabs.Misc:AddSection("↳ Game Play")



do
    --== ⚙️ Setup ==--
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    local Survivors = workspace:WaitForChild("Players"):WaitForChild("Survivors")

    --== 💡 Cấu hình các loại Anti-Slow ==--
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

    --== 🧩 Hàm ẩn UI báo slow ==--
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

    --== 🔧 Hàm xử lý Anti-Slow ==--
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

    --== ▶️ Bật tất cả Anti-Slow ==--
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

    --== ⏹️ Tắt tất cả Anti-Slow ==--
    local function stopAllAntiSlow()
        for _, config in pairs(AntiSlowConfigs) do
            config.Enabled = false
            if config.Connection then
                config.Connection:Disconnect()
                config.Connection = nil
            end
        end
    end

    --== 🧩 Tạo Toggle Fluent UI (chỉ 1 nút tổng) ==--
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
    --== ⚙️ Auto Close 1x1x1x1 Popups + Anti Slow/FOV ==--
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
                -- 🔹 Auto Close 1x1x1x1 Popups
                local temp = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("TemporaryUI")
                if temp and temp:FindFirstChild("1x1x1x1Popup") then
                    temp["1x1x1x1Popup"]:Destroy()
                end

                -- 🔹 Anti Slow + Anti FOV Slow
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

                        -- FOVMultipliers
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

-- SCRIPT GIẢM ĐỒ HỌA TỰ ĐỘNG MỖI 10 GIÂY (CÓ TOGGLE + RESTORE)
-- Dán vào LocalScript (StarterPlayerScripts hoặc executor)
-- Siêu Fix Lag cực mạnh giúp máy bạn mượt hơn 25% khi bật

-- Lưu dữ liệu gốc
local originalLighting = {}
local originalParts = {}

-- Hàm lưu Lighting gốc
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

-- Hàm khôi phục Lighting
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

-- Hàm giảm đồ họa triệt để
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

-- Hàm khôi phục BasePart
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

-- ==============================
-- Toggle Auto Reduce (10s)
-- ==============================
local autoThread
local connection

local AutoReduceToggle = Tabs.Misc:AddToggle("AutoReduce", {
    Title = "FPS Boost",
    Default = false,
    Callback = function(state)
        if state then
            print("🔄 Auto Reduce ON")

            -- Lưu lighting gốc
            saveLighting()

            -- Giảm đồ họa lighting khi bật
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            game.Lighting.GlobalShadows = false
            game.Lighting.FogEnd = 9e9
            game.Lighting.Brightness = 1
            for _, v in ipairs(game.Lighting:GetChildren()) do
                if v:IsA("PostEffect") then
                    v.Enabled = false
                end
            end

            -- 🔥 Giảm ngay 1 lần đầu tiên
            for _, obj in ipairs(workspace:GetDescendants()) do
                simplifyModel(obj)
            end

            -- Nếu có object spawn thêm thì cũng xử lý
            connection = workspace.DescendantAdded:Connect(simplifyModel)

            -- Sau đó auto lặp mỗi 10s
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

            -- Khôi phục đồ họa gốc
            restoreLighting()
            restoreParts()
            print("✅ Đã khôi phục đồ họa gốc")
        end
    end
})



-- 🧠 Anti-FPS Spike (Cưỡng chế 60FPS + Tự chống tăng bất thường)
-- Giữ FPS luôn ổn định ở 60, ngăn vọt FPS gây đơ / giật game

local RunService = game:GetService("RunService")

Tabs.Misc:AddToggle("AntiFPSSpike", {
    Title = "Unlock FPS V2",
    Default = false
}):OnChanged(function(Value)
    _G.AntiFPSSpike = Value

    if Value then
        warn("[Anti-FPS Spike] ✅ Hệ thống cưỡng chế FPS = 60 đã bật.")

        task.spawn(function()
            local FORCE_FPS = 60          -- Luôn giữ 60 FPS
            local SPIKE_THRESHOLD = 120   -- Nếu FPS vượt ngưỡng này thì chống spike
            local MONITOR_INTERVAL = 1    -- Kiểm tra mỗi 1 giây

            local frameCount = 0
            local fps = 60

            -- Hàm cưỡng chế FPS
            local function forceCap()
                if typeof(setfpscap) == "function" then
                    setfpscap(FORCE_FPS)
                end
            end

            -- Khóa ban đầu
            forceCap()

            -- Đếm FPS thực tế
            RunService.RenderStepped:Connect(function()
                if not _G.AntiFPSSpike then return end
                frameCount += 1
            end)

            while _G.AntiFPSSpike and task.wait(MONITOR_INTERVAL) do
                fps = frameCount / MONITOR_INTERVAL
                frameCount = 0

                -- Phát hiện FPS tăng bất thường
                if fps > SPIKE_THRESHOLD then
                    warn(string.format("[⚠️ Anti-FPS Spike]: FPS tăng bất thường (%d) → ổn định lại!", math.floor(fps)))
                    forceCap()
                    task.wait(0.5)
                end

                -- Bảo vệ tránh script khác đổi cap
                if typeof(getfpscap) == "function" then
                    local currentCap = getfpscap()
                    if currentCap ~= FORCE_FPS then
                        warn("[Anti-FPS Spike]: Phát hiện thay đổi FPS cap ngoài ý muốn → ép lại 60FPS.")
                        forceCap()
                    end
                end
            end

            warn("[Anti-FPS Spike] ⛔ Hệ thống cưỡng chế FPS đã tắt.")
        end)
    else
        warn("[Anti-FPS Spike] ❌ Đã tắt.")
    end
end)



-- ======= DỊCH VỤ =======
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ======= DANH SÁCH BLOCK ANIMATION =======
local blockedAnimations = {
    ["127802146383565"] = true,
    ["82691533602949"] = true,
    ["123764169071995"] = true,
}

-- ======= BIẾN TRẠNG THÁI =======
local BlockAnimEnabled = false
local blockConnections = {}

-- ======= HÀM =======
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

    -- clear cũ
    for _, conn in pairs(blockConnections) do
        conn:Disconnect()
    end
    table.clear(blockConnections)

    if enabled then
        -- nhân vật hiện tại
        if LocalPlayer.Character then
            hookHumanoid(LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid"))
        end
        -- respawn
        local connChar = LocalPlayer.CharacterAdded:Connect(function(char)
            char:WaitForChild("Humanoid")
            hookHumanoid(char:FindFirstChildWhichIsA("Humanoid"))
        end)
        table.insert(blockConnections, connChar)
    end
end

-- ======= TOGGLE FLUENT =======
Tabs.Misc:AddToggle("BlockBadAnims", {
    Title = "Block Animations",
    Default = false
}):OnChanged(function(v)
    setBlockAnimations(v)
end)



    Tabs.Misc:AddSection("↳ Show")



--// FPS + Ping Display (Safe BillboardGui Version)
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Camera = workspace.CurrentCamera

--// UI Container
local ui = Instance.new("ScreenGui")
ui.Name = "FPS_Ping_Display"
ui.ResetOnSpawn = false
ui.IgnoreGuiInset = true
ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ui.Parent = game:GetService("CoreGui")

--// FPS Label
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

--// Ping Label
local pingLabel = fpsLabel:Clone()
pingLabel.Position = UDim2.new(1, -130, 0, 25)
pingLabel.Text = "Ping: ..."
pingLabel.Parent = ui

--// Variables
local showFPS = true
local showPing = true
local fpsCounter, lastUpdate = 0, tick()

--// Update Loop
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

--// Fluent UI Toggles
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




do
    --== 💬 Chat Visibility Controller ==--
    getgenv().chatWindow = game:GetService("TextChatService"):WaitForChild("ChatWindowConfiguration")
    getgenv().chatEnabled = false
    getgenv().chatConnection = nil

    Tabs.Misc:AddToggle("ChatVisibilityToggle", {
        Title = "Show Chat",
        Default = false
    }):OnChanged(function(Value)
        getgenv().chatEnabled = Value

        -- Nếu bật → bật chat và kết nối Heartbeat
        if Value then
            if not getgenv().chatConnection then
                getgenv().chatConnection = game:GetService("RunService").Heartbeat:Connect(function()
                    if getgenv().chatWindow then
                        getgenv().chatWindow.Enabled = true
                    end
                end)
            end
        else
            -- Nếu tắt → ngắt kết nối và ẩn chat
            if getgenv().chatConnection then
                getgenv().chatConnection:Disconnect()
                getgenv().chatConnection = nil
            end
            if getgenv().chatWindow then
                getgenv().chatWindow.Enabled = false
            end
        end
    end)
end




-- Tabs.Settings


local AexecToggle = Tabs.Settings:AddToggle("AexecToggle", {Title = "Auto Execute", Default = false })
AexecToggle:OnChanged(function(Value)
    if Value then
        task.spawn(function()
            pcall(function()
                if queue_on_teleport then
                    local TzuanHubScript1 = [[
task.wait(3)
loadstring(game:HttpGet("https://hst.sh/raw/uhuhatusop"))()
]]
                    queue_on_teleport(TzuanHubScript1)
                end
            end)
        end)
        Fluent:Notify({
            Title = "Tzuan HUB",
            Content = "Auto execute is enabled!",
            Duration = 5
        })
    else
        Fluent:Notify({
            Title = "Tzuan HUB",
            Content = "Auto execute is disabled!",
            Duration = 5
        })
    end
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

-- Ignore keys that are used by ThemeManager.
-- (we dont want configs to save themes, do we?)
SaveManager:IgnoreThemeSettings()

-- You can add indexes of elements the save manager should ignore
SaveManager:SetIgnoreIndexes({})

-- use case for doing it this way:
-- a script hub could have themes in a global folder
-- and game configs in a separate folder per game
InterfaceManager:SetFolder("Tzuan HUB")
SaveManager:SetFolder("Tzuan HUB/Forsaken")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

-- Select First Tab By Default
Window:SelectTab(1)

Fluent:Notify({ Title = "Tzuan HUB", Content = "forsaken script loaded successfully!", Duration = 5 })
SaveManager:LoadAutoloadConfig()