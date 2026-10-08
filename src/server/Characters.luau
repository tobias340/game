--!strict
-- Safe lookups for a player's character parts.

local Characters = {}

function Characters.rootPart(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function Characters.humanoid(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function Characters.isAlive(player: Player): boolean
	local humanoid = Characters.humanoid(player)
	return humanoid ~= nil and humanoid.Health > 0 and Characters.rootPart(player) ~= nil
end

function Characters.isNear(player: Player, position: Vector3, range: number): boolean
	local root = Characters.rootPart(player)
	return root ~= nil and (root.Position - position).Magnitude <= range
end

return Characters
