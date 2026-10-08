--!strict
-- Applies wrench knockback to our own character. It runs on the client because the client
-- simulates its own character's physics.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KnockbackEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Knockback") :: RemoteEvent

local STUN_SECONDS = 0.7

local Knockback = {}

local function apply(velocity: Vector3)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	task.delay(STUN_SECONDS, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function Knockback.start()
	KnockbackEvent.OnClientEvent:Connect(function(velocity: Vector3)
		if typeof(velocity) == "Vector3" then
			apply(velocity)
		end
	end)
end

return Knockback
