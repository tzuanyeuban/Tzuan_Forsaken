local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local UICorner = Instance.new("UICorner")
local UIStroke = Instance.new("UIStroke")
local Title = Instance.new("TextLabel")

ScreenGui.Name = "ForsakenLoaderFix"
ScreenGui.Parent = CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Size = UDim2.new(0, 300, 0, 335)
MainFrame.ClipsDescendants = false

UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

UIStroke.Parent = MainFrame
UIStroke.Color = Color3.fromRGB(60, 60, 70)
UIStroke.Thickness = 2

Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundTransparency = 1.000
Title.Position = UDim2.new(0, 0, 0, 15)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Font = Enum.Font.GothamBlack
Title.Text = "SCRIPT LOADER"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 22.000

local function CreateButton(name, text, pos, color1, color2, callback)
	local Button = Instance.new("TextButton")
	local BtnCorner = Instance.new("UICorner")
	local BtnGradient = Instance.new("UIGradient")
	local Label = Instance.new("TextLabel") 
	
	Button.Name = name
	Button.Parent = MainFrame
	Button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Button.Position = pos
	Button.Size = UDim2.new(0, 260, 0, 50)
	Button.AutoButtonColor = false
	Button.Font = Enum.Font.SourceSans
	Button.Text = "" 
	Button.AnchorPoint = Vector2.new(0.5, 0)
	
	BtnCorner.CornerRadius = UDim.new(0, 8)
	BtnCorner.Parent = Button
	
	BtnGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0.00, color1),
		ColorSequenceKeypoint.new(1.00, color2)
	}
	BtnGradient.Parent = Button
	
	Label.Name = "TextOverlay"
	Label.Parent = Button
	Label.BackgroundTransparency = 1
	Label.Size = UDim2.new(1, 0, 1, 0)
	Label.Font = Enum.Font.GothamBold
	Label.Text = text
	Label.TextColor3 = Color3.fromRGB(255, 255, 255)
	Label.TextSize = 18
	Label.ZIndex = 2 

	Button.MouseButton1Click:Connect(function()
		TweenService:Create(Button, TweenInfo.new(0.1), {Size = UDim2.new(0, 250, 0, 45)}):Play()
		wait(0.1)
		TweenService:Create(Button, TweenInfo.new(0.1), {Size = UDim2.new(0, 260, 0, 50)}):Play()
		callback()
	end)
end

CreateButton("BtnV2.0", "ForsakenV2.0", UDim2.new(0.5, 0, 0, 60), 
	Color3.fromRGB(0, 200, 100), 
	Color3.fromRGB(0, 150, 80), 
	function()
		ScreenGui:Destroy()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/XUANVNPRO/Tzuan_Forsaken/refs/heads/main/forsaken4.lua"))()
	end
)

CreateButton("BtnV2.1", "ForsakenV2.1", UDim2.new(0.5, 0, 0, 125), 
	Color3.fromRGB(0, 170, 255), 
	Color3.fromRGB(0, 100, 200), 
	function()
		ScreenGui:Destroy()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/XUANVNPRO/Tzuan_Forsaken/refs/heads/main/forsaken3.lua"))()
	end
)

CreateButton("BtnV2.5", "ForsakenV2.5", UDim2.new(0.5, 0, 0, 190), 
	Color3.fromRGB(255, 60, 100), 
	Color3.fromRGB(200, 30, 60), 
	function()
		ScreenGui:Destroy()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/XUANVNPRO/Tzuan_Forsaken/refs/heads/main/forsaken2.lua"))()
	end
)

CreateButton("BtnDiscord", "Discord", UDim2.new(0.5, 0, 0, 255), 
	Color3.fromRGB(130, 100, 255), 
	Color3.fromRGB(90, 60, 200), 
	function()
		if setclipboard then
			setclipboard("https://discord.gg/usv255Pw4t")
		end
	end
)

MainFrame.Size = UDim2.new(0,0,0,0)
TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Size = UDim2.new(0, 300, 0, 335)}):Play()

