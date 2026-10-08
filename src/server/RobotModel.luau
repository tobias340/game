--!strict
-- Builds a robot model out of parts, colored by its body color and rarity.
-- The model's pivot is between its feet and it faces -Z, so PivotTo(cframe) stands it on that spot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Robots = require(ReplicatedStorage.Shared.Robots)
local Build = require(script.Parent.Build)

local INCOME_COLOR = Color3.fromRGB(110, 255, 140)
local PRICE_COLOR = Color3.fromRGB(255, 220, 90)

local RobotModel = {}

local function addInfo(head: BasePart, def: Robots.RobotDef, rarity: Robots.Rarity)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Adornee = head
	gui.Size = UDim2.new(8, 0, 3, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6 * rarity.Scale, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Parent = head

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui

	local lines = {
		{ Name = "Name", Text = def.Name, Color = Color3.new(1, 1, 1) },
		{ Name = "Rarity", Text = def.Rarity, Color = rarity.Color },
		{ Name = "Income", Text = Format.money(def.Income) .. "/s", Color = INCOME_COLOR },
		{ Name = "Price", Text = Format.money(def.Price), Color = PRICE_COLOR },
	}
	for order, line in lines do
		local label = Build.label(gui, line.Name, line.Text, line.Color)
		label.Size = UDim2.fromScale(1, 0.25)
		label.LayoutOrder = order
	end
end

function RobotModel.build(def: Robots.RobotDef): Model
	local rarity = Robots.RarityByName[def.Rarity]
	local scale = rarity.Scale
	local trim = def.Color:Lerp(Color3.new(0, 0, 0), 0.35)
	local glow = rarity.Color

	local model = Instance.new("Model")
	model.Name = def.Name
	model:SetAttribute("RobotId", def.Id)

	local function add(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
		local part = Build.part(model, name, size * scale, CFrame.new(position * scale), color, material)
		part.CanCollide = false
		part.CanTouch = false
		return part
	end

	local metal = Enum.Material.Metal
	local neon = Enum.Material.Neon
	local torso = add("Torso", Vector3.new(2.2, 2, 1.4), Vector3.new(0, 2.6, 0), def.Color, metal)
	add("LeftLeg", Vector3.new(0.8, 1.6, 0.8), Vector3.new(-0.6, 0.8, 0), trim, metal)
	add("RightLeg", Vector3.new(0.8, 1.6, 0.8), Vector3.new(0.6, 0.8, 0), trim, metal)
	add("LeftArm", Vector3.new(0.6, 1.8, 0.6), Vector3.new(-1.45, 2.5, 0), trim, metal)
	add("RightArm", Vector3.new(0.6, 1.8, 0.6), Vector3.new(1.45, 2.5, 0), trim, metal)
	add("ChestLight", Vector3.new(1, 0.5, 0.1), Vector3.new(0, 2.9, -0.71), glow, neon)
	local head = add("Head", Vector3.new(1.6, 1.3, 1.3), Vector3.new(0, 4.25, 0), def.Color, metal)
	add("LeftEye", Vector3.new(0.35, 0.35, 0.1), Vector3.new(-0.4, 4.35, -0.66), glow, neon)
	add("RightEye", Vector3.new(0.35, 0.35, 0.1), Vector3.new(0.4, 4.35, -0.66), glow, neon)
	add("Antenna", Vector3.new(0.15, 0.8, 0.15), Vector3.new(0, 5.3, 0), trim, metal)
	local bulb = add("Bulb", Vector3.new(0.45, 0.45, 0.45), Vector3.new(0, 5.85, 0), glow, neon)
	bulb.Shape = Enum.PartType.Ball

	if def.Rarity == "Legendary" or def.Rarity == "Mythic" then
		local light = Instance.new("PointLight")
		light.Color = glow
		light.Range = 10 * scale
		light.Brightness = 2
		light.Parent = bulb
	end
	if def.Rarity == "Mythic" then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(glow)
		sparkles.Rate = 6
		sparkles.Lifetime = NumberRange.new(1, 2)
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Parent = torso
	end

	-- Weld everything to the torso so the robot moves as one piece when it gets carried
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= torso then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = torso
			weld.Part1 = part
			weld.Parent = part
		end
	end

	model.PrimaryPart = torso
	model.WorldPivot = CFrame.identity
	addInfo(head, def, rarity)
	return model
end

function RobotModel.setPriceVisible(model: Model, visible: boolean)
	local price = model:FindFirstChild("Price", true)
	if price and price:IsA("TextLabel") then
		price.Visible = visible
	end
end

return RobotModel
