--!strict
-- Builds the whole map from code: the ground, the conveyor lane in the middle and the player bases on
-- both sides of it. Each base faces the lane, with its open entrance on the lane side.

local Build = require(script.Parent.Build)

export type PedestalParts = {
	Stand: CFrame, -- where a robot's feet go
	Pad: BasePart, -- step on it to collect the cash this pedestal has earned
	PadGui: BillboardGui,
	PadLabel: TextLabel,
}

export type PlotParts = {
	Index: number,
	Model: Model,
	CFrame: CFrame, -- center of the base floor, looking toward the lane
	Spawn: SpawnLocation,
	SignLabel: TextLabel,
	LockButton: BasePart,
	LockLabel: TextLabel,
	LockField: BasePart,
	RobotFolder: Folder,
	Pedestals: { PedestalParts },
}

export type World = {
	Plots: { PlotParts },
	LaneStart: CFrame, -- conveyor robots spawn here and walk along its LookVector
	LaneLength: number,
	ConveyorFolder: Folder,
}

local Map = {}

Map.PLOT_SIZE = 60
Map.PLOT_COUNT = 8

local PLOT_SPACING = 70
local PLOT_OFFSET_X = 55
local LANE_WIDTH = 14
local LANE_LENGTH = 270
local PEDESTAL_COLUMNS = { -22, -11, 0, 11, 22 }
local PEDESTAL_ROWS = { 2, 16 }

local GRASS = Color3.fromRGB(95, 165, 85)
local LANE = Color3.fromRGB(45, 45, 55)
local RAIL = Color3.fromRGB(70, 220, 255)
local FLOOR = Color3.fromRGB(205, 210, 220)
local POST = Color3.fromRGB(60, 60, 70)
local PEDESTAL = Color3.fromRGB(110, 115, 130)
local PAD = Color3.fromRGB(70, 230, 120)
local LOCK_BUTTON = Color3.fromRGB(255, 80, 80)
local LOCK_FIELD = Color3.fromRGB(80, 200, 255)
local ACCENTS = {
	Color3.fromRGB(255, 99, 99),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(250, 220, 70),
	Color3.fromRGB(110, 220, 110),
	Color3.fromRGB(70, 200, 230),
	Color3.fromRGB(90, 130, 255),
	Color3.fromRGB(180, 110, 255),
	Color3.fromRGB(255, 120, 200),
}

local function buildPlot(parent: Instance, index: number, cf: CFrame): PlotParts
	local accent = ACCENTS[(index - 1) % #ACCENTS + 1]
	local half = Map.PLOT_SIZE / 2

	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model.Parent = parent

	Build.part(model, "Floor", Vector3.new(Map.PLOT_SIZE, 1, Map.PLOT_SIZE), cf * CFrame.new(0, 0.5, 0), FLOOR)
	Build.part(model, "BackWall", Vector3.new(Map.PLOT_SIZE, 8, 1), cf * CFrame.new(0, 5, half - 0.5), accent)
	Build.part(model, "LeftWall", Vector3.new(1, 8, Map.PLOT_SIZE), cf * CFrame.new(-half + 0.5, 5, 0), accent)
	Build.part(model, "RightWall", Vector3.new(1, 8, Map.PLOT_SIZE), cf * CFrame.new(half - 0.5, 5, 0), accent)

	-- Owner sign over the entrance, readable from the lane
	for _, x in { -12.5, 12.5 } do
		Build.part(model, "SignPost", Vector3.new(1, 12, 1), cf * CFrame.new(x, 7, -half + 0.5), POST)
	end
	local sign = Build.part(model, "Sign", Vector3.new(26, 5, 0.6), cf * CFrame.new(0, 13.5, -half + 0.5), accent)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = sign
	local signLabel = Build.label(surface, "Owner", "Empty Base", Color3.new(1, 1, 1))

	-- Lock button near the entrance and the force field it turns on
	local lockButton = Build.part(
		model,
		"LockButton",
		Vector3.new(5, 0.6, 5),
		cf * CFrame.new(-half + 6, 1.3, -half + 7),
		LOCK_BUTTON,
		Enum.Material.Neon
	)
	local _, lockLabel = Build.billboard(lockButton, "LockInfo", UDim2.new(7, 0, 1.6, 0), Vector3.new(0, 2.5, 0))
	lockLabel.Text = "LOCK BASE"

	local lockField = Build.part(
		model,
		"LockField",
		Vector3.new(Map.PLOT_SIZE, 24, Map.PLOT_SIZE),
		cf * CFrame.new(0, 13, 0),
		LOCK_FIELD,
		Enum.Material.ForceField
	)
	lockField.Transparency = 1
	lockField.CanCollide = false
	lockField.CanTouch = false
	lockField.CanQuery = false
	lockField.CastShadow = false

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = cf * CFrame.new(0, 1.5, half - 6)
	spawn.Color = accent
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = model

	local pedestals: { PedestalParts } = {}
	for _, z in PEDESTAL_ROWS do
		for _, x in PEDESTAL_COLUMNS do
			Build.part(model, "Pedestal", Vector3.new(6, 2, 6), cf * CFrame.new(x, 2, z), PEDESTAL, Enum.Material.Metal)

			local pad: BasePart = Build.part(
				model,
				"CollectPad",
				Vector3.new(5, 0.3, 2.5),
				cf * CFrame.new(x, 1.15, z - 5),
				PAD,
				Enum.Material.Neon
			)
			pad.CanCollide = false

			local padGui, padLabel = Build.billboard(pad, "Stored", UDim2.new(4, 0, 1.2, 0), Vector3.new(0, 1.5, 0))
			padGui.Enabled = false
			padLabel.TextColor3 = PAD

			table.insert(pedestals, {
				Stand = cf * CFrame.new(x, 3, z),
				Pad = pad,
				PadGui = padGui,
				PadLabel = padLabel,
			})
		end
	end

	local robotFolder = Instance.new("Folder")
	robotFolder.Name = "Robots"
	robotFolder.Parent = model

	return {
		Index = index,
		Model = model,
		CFrame = cf,
		Spawn = spawn,
		SignLabel = signLabel,
		LockButton = lockButton,
		LockLabel = lockLabel,
		LockField = lockField,
		RobotFolder = robotFolder,
		Pedestals = pedestals,
	}
end

function Map.build(): World
	local root = Instance.new("Folder")
	root.Name = "StealARobot"

	Build.part(root, "Ground", Vector3.new(420, 2, 420), CFrame.new(0, -1, 0), GRASS, Enum.Material.Grass)
	Build.part(root, "Lane", Vector3.new(LANE_WIDTH, 1, LANE_LENGTH), CFrame.new(0, 0.5, 0), LANE)
	for _, x in { -LANE_WIDTH / 2 - 0.3, LANE_WIDTH / 2 + 0.3 } do
		Build.part(
			root,
			"LaneRail",
			Vector3.new(0.6, 0.6, LANE_LENGTH),
			CFrame.new(x, 1.3, 0),
			RAIL,
			Enum.Material.Neon
		)
	end

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = root

	-- Half the bases on each side of the lane, all facing it
	local perSide = Map.PLOT_COUNT // 2
	local plots = {}
	for index = 1, Map.PLOT_COUNT do
		local side = if index <= perSide then -1 else 1
		local row = (index - 1) % perSide
		local z = (row - (perSide - 1) / 2) * PLOT_SPACING
		local cf = CFrame.lookAt(Vector3.new(side * PLOT_OFFSET_X, 0, z), Vector3.new(0, 0, z))
		table.insert(plots, buildPlot(plotsFolder, index, cf))
	end

	local conveyor = Instance.new("Folder")
	conveyor.Name = "Conveyor"
	conveyor.Parent = root

	root.Parent = workspace

	local travel = LANE_LENGTH - 10
	return {
		Plots = plots,
		LaneStart = CFrame.lookAt(Vector3.new(0, 1, -travel / 2), Vector3.new(0, 1, travel / 2)),
		LaneLength = travel,
		ConveyorFolder = conveyor,
	}
end

return Map
