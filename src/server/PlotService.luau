--!strict
-- Player bases: who owns which base, the robots on its pedestals, cash income, collecting, selling
-- and the lock button.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Robots = require(ReplicatedStorage.Shared.Robots)
local Characters = require(script.Parent.Characters)
local DataService = require(script.Parent.DataService)
local Map = require(script.Parent.Map)
local Notify = require(script.Parent.Notify)
local RobotModel = require(script.Parent.RobotModel)

export type Pedestal = {
	Index: number,
	Stand: CFrame,
	PadGui: BillboardGui,
	PadLabel: TextLabel,
	Stored: number, -- cash waiting to be collected
	Robot: Robot?,
}

export type Robot = {
	Def: Robots.RobotDef,
	Model: Model,
	Plot: Plot,
	Pedestal: Pedestal, -- stays set while the robot is being carried, so it can go back
	CarriedBy: Player?,
}

export type Plot = {
	Index: number,
	Parts: Map.PlotParts,
	Owner: Player?,
	Pedestals: { Pedestal },
	LockedUntil: number, -- os.clock() time, 0 when unlocked
}

local LOCKED_COLOR = Color3.fromRGB(80, 200, 255)
local UNLOCKED_COLOR = Color3.fromRGB(255, 80, 80)

local PlotService = {}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}
local robotByModel: { [Model]: Robot } = {}
local lockedCallbacks: { (Plot) -> () } = {}

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

local function sellPrice(def: Robots.RobotDef): number
	return math.floor(def.Price * Config.SellRefund)
end

local function updatePad(pedestal: Pedestal)
	pedestal.PadGui.Enabled = pedestal.Stored > 0
	pedestal.PadLabel.Text = Format.money(pedestal.Stored)
end

-- Every robot on a pedestal gets a Steal prompt and a Sell prompt. The client shows Steal only to
-- other players (while the base is unlocked) and Sell only to the owner. The server re-checks both.
local function addPrompts(robot: Robot)
	local owner = robot.Plot.Owner
	local root = robot.Model.PrimaryPart
	if not owner or not root then
		return
	end

	local steal = Instance.new("ProximityPrompt")
	steal.Name = "StealPrompt"
	steal.ActionText = "Steal"
	steal.ObjectText = robot.Def.Name
	steal.HoldDuration = Config.StealHoldDuration
	steal.MaxActivationDistance = 10
	steal.RequiresLineOfSight = false
	steal:SetAttribute("OwnerUserId", owner.UserId)
	steal:SetAttribute("Locked", PlotService.isLocked(robot.Plot))
	steal:AddTag("StealPrompt")
	steal.Parent = root

	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellPrompt"
	sell.ActionText = "Sell for " .. Format.money(sellPrice(robot.Def))
	sell.ObjectText = robot.Def.Name
	sell.HoldDuration = 1
	sell.MaxActivationDistance = 10
	sell.RequiresLineOfSight = false
	sell:SetAttribute("OwnerUserId", owner.UserId)
	sell:AddTag("SellPrompt")
	sell.Parent = root
end

local function removePrompts(robot: Robot)
	local root = robot.Model.PrimaryPart
	if not root then
		return
	end
	for _, name in { "StealPrompt", "SellPrompt" } do
		local prompt = root:FindFirstChild(name)
		if prompt then
			prompt:Destroy()
		end
	end
end

local function setLockVisual(plot: Plot, locked: boolean)
	local parts = plot.Parts
	parts.LockField.Transparency = if locked then 0.3 else 1
	parts.LockButton.Color = if locked then LOCKED_COLOR else UNLOCKED_COLOR
	parts.LockLabel.Text = if locked then `LOCKED {Config.LockDuration}s` else "LOCK BASE"
	for _, pedestal in plot.Pedestals do
		local robot = pedestal.Robot
		local root = robot and robot.Model.PrimaryPart
		local prompt = root and root:FindFirstChild("StealPrompt")
		if prompt then
			prompt:SetAttribute("Locked", locked)
		end
	end
end

local function lock(plot: Plot)
	plot.LockedUntil = os.clock() + Config.LockDuration
	setLockVisual(plot, true)
	for _, callback in lockedCallbacks do
		task.spawn(callback, plot)
	end
end

local function collect(plot: Plot, pedestal: Pedestal, hit: BasePart)
	if pedestal.Stored <= 0 then
		return
	end
	local player = playerFromHit(hit)
	if not player or player ~= plot.Owner or not DataService.isLoaded(player) then
		return
	end
	DataService.addCash(player, pedestal.Stored)
	pedestal.Stored = 0
	updatePad(pedestal)
end

local function sell(prompt: ProximityPrompt, player: Player)
	local robot = PlotService.robotFromPrompt(prompt)
	if not robot or robot.CarriedBy or robot.Plot.Owner ~= player then
		return
	end
	local price = sellPrice(robot.Def)
	PlotService.removeRobot(robot)
	DataService.addCash(player, price)
	Notify.send(player, `Sold {robot.Def.Name} for {Format.money(price)}`, "good")
end

-- Once a second: pay out income into each pedestal and count down locks.
local function tick()
	for _, plot in plots do
		if plot.Owner then
			for _, pedestal in plot.Pedestals do
				local robot = pedestal.Robot
				if robot and not robot.CarriedBy then
					pedestal.Stored += robot.Def.Income
					updatePad(pedestal)
				end
			end
		end

		if plot.LockedUntil > 0 then
			local remaining = math.ceil(plot.LockedUntil - os.clock())
			if remaining <= 0 then
				plot.LockedUntil = 0
				setLockVisual(plot, false)
			else
				plot.Parts.LockLabel.Text = `LOCKED {remaining}s`
			end
		end
	end
end

-- Pushes anyone who isn't the owner out of a locked base.
local function enforceLocks()
	for _, plot in plots do
		if plot.Owner and PlotService.isLocked(plot) then
			for _, player in Players:GetPlayers() do
				local root = Characters.rootPart(player)
				local character = player.Character
				if player ~= plot.Owner and root and character and PlotService.isInside(plot, root.Position) then
					character:PivotTo(plot.Parts.CFrame * CFrame.new(0, 4, -(Map.PLOT_SIZE / 2 + 8)))
				end
			end
		end
	end
end

function PlotService.getPlot(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.isLocked(plot: Plot): boolean
	return plot.LockedUntil > os.clock()
end

function PlotService.isInside(plot: Plot, position: Vector3): boolean
	local localPosition = plot.Parts.CFrame:PointToObjectSpace(position)
	local half = Map.PLOT_SIZE / 2
	return math.abs(localPosition.X) <= half and math.abs(localPosition.Z) <= half and localPosition.Y < 40
end

function PlotService.freePedestal(plot: Plot): Pedestal?
	for _, pedestal in plot.Pedestals do
		if not pedestal.Robot then
			return pedestal
		end
	end
	return nil
end

function PlotService.robotFromPrompt(prompt: ProximityPrompt): Robot?
	local root = prompt.Parent
	local model = root and root.Parent
	return if model and model:IsA("Model") then robotByModel[model] else nil
end

-- Called with the plot whenever its owner locks it.
function PlotService.onLocked(callback: (Plot) -> ())
	table.insert(lockedCallbacks, callback)
end

-- Gives the player a free base. Returns nil when every base is taken.
function PlotService.assign(player: Player): Plot?
	for _, plot in plots do
		if not plot.Owner then
			plot.Owner = player
			plotByPlayer[player] = plot
			plot.Parts.SignLabel.Text = `{player.DisplayName}'s Base`
			player.RespawnLocation = plot.Parts.Spawn
			return plot
		end
	end
	return nil
end

-- Clears a leaving player's base so the next player gets it empty.
function PlotService.release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	for _, pedestal in plot.Pedestals do
		local robot = pedestal.Robot
		if robot then
			PlotService.removeRobot(robot)
		end
		pedestal.Stored = 0
		updatePad(pedestal)
	end
	plot.Owner = nil
	plot.LockedUntil = 0
	setLockVisual(plot, false)
	plot.Parts.SignLabel.Text = "Empty Base"
end

-- Puts a robot on a pedestal. Pass an existing model (for example from the conveyor) to reuse it.
function PlotService.placeRobot(plot: Plot, pedestal: Pedestal, def: Robots.RobotDef, existing: Model?): Robot
	local model = existing or RobotModel.build(def)
	RobotModel.setPriceVisible(model, false)
	model:PivotTo(pedestal.Stand)
	model.Parent = plot.Parts.RobotFolder

	local robot: Robot = { Def = def, Model = model, Plot = plot, Pedestal = pedestal, CarriedBy = nil }
	pedestal.Robot = robot
	robotByModel[model] = robot
	addPrompts(robot)
	return robot
end

function PlotService.removeRobot(robot: Robot)
	if robot.Pedestal.Robot == robot then
		robot.Pedestal.Robot = nil
	end
	robotByModel[robot.Model] = nil
	robot.Model:Destroy()
end

-- Takes the prompts off a robot that is about to be carried away.
function PlotService.detach(robot: Robot)
	removePrompts(robot)
end

-- Puts a carried robot back on the pedestal it was taken from.
function PlotService.returnToPedestal(robot: Robot)
	robot.Model:PivotTo(robot.Pedestal.Stand)
	addPrompts(robot)
end

-- Hands a robot over to another base (a successful steal).
function PlotService.moveRobot(robot: Robot, plot: Plot, pedestal: Pedestal)
	if robot.Pedestal.Robot == robot then
		robot.Pedestal.Robot = nil
	end
	robot.Plot = plot
	robot.Pedestal = pedestal
	pedestal.Robot = robot
	robot.Model.Parent = plot.Parts.RobotFolder
	robot.Model:PivotTo(pedestal.Stand)
	addPrompts(robot)
end

-- Puts a player's saved robots back on their pedestals.
function PlotService.restoreRobots(plot: Plot, robotIds: { string })
	for _, id in robotIds do
		local def = Robots.ById[id]
		local pedestal = PlotService.freePedestal(plot)
		if def and pedestal then
			PlotService.placeRobot(plot, pedestal, def)
		end
	end
end

-- The robot ids a player owns right now, including any being carried away from their base.
function PlotService.robotIds(player: Player): { string }
	local ids = {}
	local plot = plotByPlayer[player]
	if plot then
		for _, pedestal in plot.Pedestals do
			local robot = pedestal.Robot
			if robot then
				table.insert(ids, robot.Def.Id)
			end
		end
	end
	return ids
end

function PlotService.start(world: Map.World)
	for _, parts in world.Plots do
		local plot: Plot = { Index = parts.Index, Parts = parts, Owner = nil, Pedestals = {}, LockedUntil = 0 }

		for index, pedestalParts in parts.Pedestals do
			local pedestal: Pedestal = {
				Index = index,
				Stand = pedestalParts.Stand,
				PadGui = pedestalParts.PadGui,
				PadLabel = pedestalParts.PadLabel,
				Stored = 0,
				Robot = nil,
			}
			table.insert(plot.Pedestals, pedestal)
			pedestalParts.Pad.Touched:Connect(function(hit)
				collect(plot, pedestal, hit)
			end)
		end

		parts.LockButton.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player and player == plot.Owner and not PlotService.isLocked(plot) then
				lock(plot)
			end
		end)

		table.insert(plots, plot)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "SellPrompt" then
			sell(prompt, player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			enforceLocks()
		end
	end)
end

return PlotService
