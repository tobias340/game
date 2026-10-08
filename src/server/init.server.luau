--!strict
-- Server entry point: builds the map, starts every service and runs the join/leave flow in order.

local Players = game:GetService("Players")

local Combat = require(script.Combat)
local ConveyorService = require(script.ConveyorService)
local DataService = require(script.DataService)
local Map = require(script.Map)
local Notify = require(script.Notify)
local PlotService = require(script.PlotService)
local StealService = require(script.StealService)

Players.RespawnTime = 3

local world = Map.build()
PlotService.start(world)
ConveyorService.start(world)
StealService.start()
Combat.start()
DataService.start(PlotService.robotIds)

local function onPlayerAdded(player: Player)
	local plot = PlotService.assign(player)
	if not plot then
		Notify.send(player, "Every base on this server is taken. Try another server!", "bad")
	elseif player.Character then
		-- Only happens in Studio when the player spawned before this script ran
		player.Character:PivotTo(plot.Parts.Spawn.CFrame * CFrame.new(0, 4, 0))
	end

	local robotIds = DataService.load(player)
	if plot and player.Parent == Players then
		PlotService.restoreRobots(plot, robotIds)
	end
end

local function onPlayerRemoving(player: Player)
	StealService.playerRemoving(player)
	local robotIds = PlotService.robotIds(player)
	PlotService.release(player)
	DataService.release(player, robotIds)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
