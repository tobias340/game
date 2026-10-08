--!strict
-- The wrench every player spawns with. Hitting someone knocks them back, and a thief who gets hit
-- drops the robot they're carrying.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local Characters = require(script.Parent.Characters)
local Notify = require(script.Parent.Notify)
local StealService = require(script.Parent.StealService)

local KnockbackEvent = ReplicatedStorage.Remotes.Knockback

local TOOL_NAME = "Wrench"

local Combat = {}

local lastBonk: { [Player]: number } = {}

local function buildTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = "Bonk thieves to make them drop your robot"
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, 1.2)

	local handle = Build.part(
		tool,
		"Handle",
		Vector3.new(0.35, 0.35, 3.2),
		CFrame.new(),
		Color3.fromRGB(150, 150, 160),
		Enum.Material.Metal
	)
	local head = Build.part(
		tool,
		"WrenchHead",
		Vector3.new(1.1, 0.4, 0.9),
		CFrame.new(0, 0, -1.6),
		Color3.fromRGB(110, 110, 120),
		Enum.Material.Metal
	)
	for _, part in { handle, head } do
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle

	return tool
end

local function bonk(player: Player, tool: Tool)
	local now = os.clock()
	if now - (lastBonk[player] or 0) < Config.BonkCooldown then
		return
	end
	local root = Characters.rootPart(player)
	if not root or not Characters.isAlive(player) or tool.Parent ~= player.Character then
		return
	end
	lastBonk[player] = now

	-- The default Animate script plays a slash when it sees this value inside the equipped tool
	local swing = Instance.new("StringValue")
	swing.Name = "toolanim"
	swing.Value = "Slash"
	swing.Parent = tool
	task.delay(0.5, function()
		swing:Destroy()
	end)

	for _, other in Players:GetPlayers() do
		local otherRoot = Characters.rootPart(other)
		if other ~= player and otherRoot and Characters.isAlive(other) then
			local offset = otherRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local distance = flat.Magnitude
			local inFront = distance < 3 or flat.Unit:Dot(root.CFrame.LookVector) > 0.3
			if distance <= Config.BonkRange and math.abs(offset.Y) < 8 and inFront then
				local direction = if distance > 0.01 then flat.Unit else root.CFrame.LookVector
				KnockbackEvent:FireClient(other, direction * Config.BonkKnockback + Vector3.new(0, 30, 0))

				if StealService.isCarrying(other) then
					StealService.drop(other, `{player.DisplayName} bonked you and you dropped the robot!`)
					Notify.send(player, `You stopped {other.DisplayName}!`, "good")
				end
			end
		end
	end
end

local function hookTool(player: Player, tool: Instance)
	if not tool:IsA("Tool") or tool.Name ~= TOOL_NAME or tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(function()
		bonk(player, tool)
	end)
end

local function watchBackpack(player: Player, backpack: Instance)
	for _, child in backpack:GetChildren() do
		hookTool(player, child)
	end
	backpack.ChildAdded:Connect(function(child)
		hookTool(player, child)
	end)
end

local function onPlayerAdded(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watchBackpack(player, backpack)
	end
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchBackpack(player, child)
		end
	end)
end

function Combat.start()
	buildTool().Parent = StarterPack

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastBonk[player] = nil
	end)
end

return Combat
