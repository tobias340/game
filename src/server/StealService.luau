--!strict
-- Stealing: grab a robot from someone else's base, carry it over your head (slowed down) and bring
-- it into your own base to keep it. Dying, getting bonked or the owner locking their base while
-- you're still inside makes you drop it, and it goes back to its pedestal.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Characters = require(script.Parent.Characters)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local PlotService = require(script.Parent.PlotService)

type Carry = {
	Robot: PlotService.Robot,
	Weld: WeldConstraint,
	Died: RBXScriptConnection,
}

local CARRY_HEIGHT = 3 -- studs above the thief's root part

local StealService = {}

local carries: { [Player]: Carry } = {}

local function setCarried(model: Model, carried: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = not carried
			descendant.Massless = carried
		end
	end
end

-- Ends a carry without deciding where the robot goes. Returns the carry that ended.
local function release(thief: Player): Carry?
	local carry = carries[thief]
	if not carry then
		return nil
	end
	carries[thief] = nil
	carry.Died:Disconnect()
	carry.Weld:Destroy()
	carry.Robot.CarriedBy = nil
	setCarried(carry.Robot.Model, false)

	local humanoid = Characters.humanoid(thief)
	if humanoid then
		humanoid.WalkSpeed = Config.NormalWalkSpeed
	end
	return carry
end

-- Makes the thief drop what they carry. The robot goes back to its owner's pedestal.
function StealService.drop(thief: Player, message: string?)
	local carry = release(thief)
	if not carry then
		return
	end
	local robot = carry.Robot
	if robot.Model.Parent == nil then
		return
	end
	PlotService.returnToPedestal(robot)

	if message then
		Notify.send(thief, message, "bad")
	end
	local owner = robot.Plot.Owner
	if owner then
		Notify.send(owner, `Your {robot.Def.Name} is back on its pedestal.`, "good")
	end
end

function StealService.isCarrying(player: Player): boolean
	return carries[player] ~= nil
end

local function deliver(thief: Player, plot: PlotService.Plot)
	local carry = carries[thief]
	if not carry then
		return
	end
	local pedestal = PlotService.freePedestal(plot)
	if not pedestal then
		StealService.drop(thief, "Your base is full, so the robot went back. Sell one to make room!")
		return
	end

	release(thief)
	local robot = carry.Robot
	local victim = robot.Plot.Owner
	PlotService.moveRobot(robot, plot, pedestal)

	Notify.send(thief, `You stole {robot.Def.Name}!`, "good")
	if victim then
		Notify.send(victim, `{thief.DisplayName} stole your {robot.Def.Name}!`, "bad")
	end
end

local function steal(prompt: ProximityPrompt, thief: Player)
	local robot = PlotService.robotFromPrompt(prompt)
	if not robot or robot.CarriedBy or carries[thief] then
		return
	end
	local victim = robot.Plot.Owner
	if not victim or victim == thief or not DataService.isLoaded(thief) then
		return
	end
	if PlotService.isLocked(robot.Plot) then
		Notify.send(thief, "That base is locked!", "bad")
		return
	end
	local myPlot = PlotService.getPlot(thief)
	if not myPlot then
		return
	end
	if not PlotService.freePedestal(myPlot) then
		Notify.send(thief, "Your base is full! Sell a robot before stealing another.", "bad")
		return
	end

	local root = Characters.rootPart(thief)
	local humanoid = Characters.humanoid(thief)
	local primary = robot.Model.PrimaryPart
	if not root or not humanoid or humanoid.Health <= 0 or not primary then
		return
	end
	if (root.Position - robot.Model:GetPivot().Position).Magnitude > 16 then
		return
	end

	PlotService.detach(robot)
	robot.CarriedBy = thief

	-- Move it over the thief's head, weld it on, then unanchor so it follows them around
	robot.Model:PivotTo(root.CFrame * CFrame.new(0, CARRY_HEIGHT, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = primary
	weld.Parent = primary
	setCarried(robot.Model, true)
	humanoid.WalkSpeed = Config.CarryWalkSpeed

	carries[thief] = {
		Robot = robot,
		Weld = weld,
		Died = humanoid.Died:Connect(function()
			StealService.drop(thief, `You dropped {robot.Def.Name}!`)
		end),
	}

	Notify.send(thief, "Run it back to your base!")
	Notify.send(victim, `{thief.DisplayName} is stealing your {robot.Def.Name}! Bonk them with your wrench!`, "bad")
end

local function update()
	for thief, carry in carries do
		local root = Characters.rootPart(thief)
		if carry.Robot.Model.Parent == nil then
			release(thief)
		elseif not root or carry.Weld.Part0 ~= root or not Characters.isAlive(thief) then
			StealService.drop(thief, nil)
		else
			local plot = PlotService.getPlot(thief)
			if plot and PlotService.isInside(plot, root.Position) then
				deliver(thief, plot)
			end
		end
	end
end

-- Call before the player's base is cleared, so nothing is left welded to a thief.
function StealService.playerRemoving(player: Player)
	StealService.drop(player, nil)
	for thief, carry in carries do
		if carry.Robot.Plot.Owner == player then
			StealService.drop(thief, `{player.DisplayName} left, so their robot vanished.`)
		end
	end
end

function StealService.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "StealPrompt" then
			steal(prompt, player)
		end
	end)

	PlotService.onLocked(function(plot)
		for thief, carry in carries do
			local root = Characters.rootPart(thief)
			if carry.Robot.Plot == plot and root and PlotService.isInside(plot, root.Position) then
				StealService.drop(thief, "The base locked and you dropped the robot!")
			end
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			update()
		end
	end)
end

return StealService
