--!strict
-- The conveyor down the middle of the map: spawns random robots that walk along the lane and lets
-- players buy them as they pass.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Robots = require(ReplicatedStorage.Shared.Robots)
local Characters = require(script.Parent.Characters)
local DataService = require(script.Parent.DataService)
local Map = require(script.Parent.Map)
local Notify = require(script.Parent.Notify)
local PlotService = require(script.Parent.PlotService)
local RobotModel = require(script.Parent.RobotModel)

type Entry = {
	Def: Robots.RobotDef,
	Model: Model,
	Prompt: ProximityPrompt,
	Distance: number, -- studs travelled along the lane
}

local ANNOUNCED_RARITIES = { Legendary = true, Mythic = true }

local ConveyorService = {}

local entries: { Entry } = {}
local entryByPrompt: { [ProximityPrompt]: Entry } = {}
local rng = Random.new()

local function removeEntry(entry: Entry)
	local index = table.find(entries, entry)
	if index then
		table.remove(entries, index)
	end
	entryByPrompt[entry.Prompt] = nil
end

local function spawnRobot(world: Map.World)
	local def = Robots.roll(rng)
	local model = RobotModel.build(def)
	model:PivotTo(world.LaneStart)
	model.Parent = world.ConveyorFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy " .. Format.money(def.Price)
	prompt.ObjectText = def.Name
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	local entry: Entry = { Def = def, Model = model, Prompt = prompt, Distance = 0 }
	table.insert(entries, entry)
	entryByPrompt[prompt] = entry

	if ANNOUNCED_RARITIES[def.Rarity] then
		Notify.all(`A {def.Rarity} {def.Name} is on the conveyor!`, "good")
	end
end

local function step(world: Map.World, dt: number)
	for index = #entries, 1, -1 do
		local entry = entries[index]
		entry.Distance += Config.ConveyorSpeed * dt
		if entry.Distance >= world.LaneLength then
			removeEntry(entry)
			entry.Model:Destroy()
		else
			entry.Model:PivotTo(world.LaneStart * CFrame.new(0, 0, -entry.Distance))
		end
	end
end

local function buy(prompt: ProximityPrompt, player: Player)
	local entry = entryByPrompt[prompt]
	if not entry or not Characters.isNear(player, entry.Model:GetPivot().Position, 20) then
		return
	end

	local plot = PlotService.getPlot(player)
	if not plot then
		Notify.send(player, "Every base on this server is taken, so you can't buy robots here.", "bad")
		return
	end
	local pedestal = PlotService.freePedestal(plot)
	if not pedestal then
		Notify.send(player, "Your base is full! Sell a robot to make room.", "bad")
		return
	end
	if not DataService.trySpend(player, entry.Def.Price) then
		Notify.send(player, `You need {Format.money(entry.Def.Price)} for {entry.Def.Name}.`, "bad")
		return
	end

	removeEntry(entry)
	prompt:Destroy()
	PlotService.placeRobot(plot, pedestal, entry.Def, entry.Model)
	Notify.send(player, `{entry.Def.Name} is now in your base!`, "good")
end

function ConveyorService.start(world: Map.World)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "BuyPrompt" then
			buy(prompt, player)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		step(world, dt)
	end)

	task.spawn(function()
		while true do
			spawnRobot(world)
			task.wait(Config.ConveyorSpawnInterval)
		end
	end)
end

return ConveyorService
