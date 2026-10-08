--!strict
-- On-screen UI: the cash counter at the top and the toast messages under it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))

local NotifyEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local KIND_COLORS: { [string]: Color3 } = {
	info = Color3.fromRGB(255, 255, 255),
	good = Color3.fromRGB(110, 255, 140),
	bad = Color3.fromRGB(255, 115, 115),
}
local MAX_TOASTS = 4
local TOAST_SECONDS = 4

local Hud = {}

local toastList: Frame? = nil

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function Hud.toast(text: string, kind: string?)
	local list = toastList
	if not list then
		return
	end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 34)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 22
	label.TextWrapped = true
	label.TextColor3 = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	label.Text = text
	addCorner(label, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = label
	label.Parent = list

	-- Drop the oldest toasts when too many pile up
	local toasts = {}
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	for index = 1, #toasts - MAX_TOASTS do
		toasts[index]:Destroy()
	end

	task.delay(TOAST_SECONDS, function()
		if label.Parent == nil then
			return
		end
		local fade =
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
end

local function bindCash(cashLabel: TextLabel)
	local leaderstats = Players.LocalPlayer:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash") :: IntValue
	local function update()
		cashLabel.Text = Format.money(cash.Value)
	end
	update()
	cash.Changed:Connect(update)
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "Cash"
	cashLabel.AnchorPoint = Vector2.new(0.5, 0)
	cashLabel.Position = UDim2.new(0.5, 0, 0, 8)
	cashLabel.Size = UDim2.fromOffset(220, 50)
	cashLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	cashLabel.BackgroundTransparency = 0.2
	cashLabel.Font = Enum.Font.FredokaOne
	cashLabel.TextSize = 34
	cashLabel.TextColor3 = Color3.fromRGB(110, 255, 140)
	cashLabel.Text = "$..."
	addCorner(cashLabel, 12)
	cashLabel.Parent = gui

	local list = Instance.new("Frame")
	list.Name = "Toasts"
	list.AnchorPoint = Vector2.new(0.5, 0)
	list.Position = UDim2.new(0.5, 0, 0, 66)
	list.Size = UDim2.fromOffset(440, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = gui
	toastList = list

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	NotifyEvent.OnClientEvent:Connect(function(text: string, kind: string?)
		Hud.toast(text, kind)
	end)
	task.spawn(bindCash, cashLabel)

	task.delay(2, function()
		Hud.toast("Buy robots on the conveyor, then step on the green pads to collect their cash!")
	end)
end

return Hud
