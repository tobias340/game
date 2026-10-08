--!strict
-- Small helpers for building parts and labels from code.

local Build = {}

function Build.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function Build.label(parent: Instance, name: string, text: string, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.Parent = parent
	return label
end

-- A floating text label above a part. Size is in studs, so it scales with distance like the world does.
function Build.billboard(adornee: BasePart, name: string, size: UDim2, offset: Vector3): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = adornee
	return gui, Build.label(gui, "Text", "", Color3.new(1, 1, 1))
end

return Build
