--!strict
-- Loads and saves each player's cash and robots, and owns the Cash leaderstat.
-- Nothing is saved for a player whose data failed to load, so a DataStore outage can't wipe a save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Notify = require(script.Parent.Notify)

type SaveData = {
	Cash: number,
	Robots: { string },
}

type Profile = {
	Cash: number,
	CashValue: IntValue,
	CanSave: boolean,
}

local DataService = {}

local profiles: { [Player]: Profile } = {}
local pendingSaves = 0

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn(`[DataService] DataStores are unavailable, progress will not save: {result}`)
	end
end

local function keyFor(userId: number): string
	return `player_{userId}`
end

local function read(userId: number): (boolean, any)
	local dataStore = store
	if not dataStore then
		return false, nil
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return dataStore:GetAsync(keyFor(userId))
		end)
		if ok then
			return true, result
		end
		warn(`[DataService] Load failed for {userId} (attempt {attempt}): {result}`)
		if string.find(tostring(result), "StudioAccessToApisNotAllowed", 1, true) then
			break -- Studio without API access: retrying can't help
		end
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	return false, nil
end

-- Turns whatever came out of the DataStore into valid SaveData, falling back to a fresh save.
local function sanitize(raw: any): SaveData
	local data: SaveData = { Cash = Config.StartingCash, Robots = {} }
	if type(raw) == "table" then
		if type(raw.Cash) == "number" and raw.Cash == raw.Cash then
			data.Cash = math.max(0, math.floor(raw.Cash))
		end
		if type(raw.Robots) == "table" then
			for _, id in raw.Robots do
				if type(id) == "string" then
					table.insert(data.Robots, id)
				end
			end
		end
	end
	return data
end

local function save(userId: number, profile: Profile, robotIds: { string })
	local dataStore = store
	if not dataStore or not profile.CanSave then
		return
	end
	local data: SaveData = { Cash = profile.Cash, Robots = robotIds }
	pendingSaves += 1
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(keyFor(userId), function()
				return data
			end)
		end)
		if ok then
			break
		end
		warn(`[DataService] Save failed for {userId} (attempt {attempt}): {err}`)
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	pendingSaves -= 1
end

local function setCash(profile: Profile, amount: number)
	profile.Cash = amount
	profile.CashValue.Value = amount
end

-- Loads a player's save, creates their leaderstats and returns the robot ids they own.
-- Yields while the DataStore responds.
function DataService.load(player: Player): { string }
	local ok, raw = read(player.UserId)
	if player.Parent ~= Players then
		return {}
	end
	local data = sanitize(raw)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = data.Cash
	cashValue.Parent = leaderstats
	leaderstats.Parent = player

	profiles[player] = { Cash = data.Cash, CashValue = cashValue, CanSave = ok }
	if not ok then
		Notify.send(player, "Saving is off: couldn't reach DataStores. Progress won't be kept this session.", "bad")
	end
	return data.Robots
end

-- Saves the player one last time and forgets them. Call after their robots are known.
function DataService.release(player: Player, robotIds: { string })
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	save(player.UserId, profile, robotIds)
end

function DataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.getCash(player: Player): number
	local profile = profiles[player]
	return if profile then profile.Cash else 0
end

function DataService.addCash(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		setCash(profile, profile.Cash + math.floor(amount))
	end
end

-- Takes cash if the player can afford it. Returns whether they paid.
function DataService.trySpend(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or profile.Cash < amount then
		return false
	end
	setCash(profile, profile.Cash - amount)
	return true
end

-- getRobotIds returns the robots a player currently owns, so saves always match their base.
function DataService.start(getRobotIds: (Player) -> { string })
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player, profile in profiles do
				task.spawn(save, player.UserId, profile, getRobotIds(player))
			end
		end
	end)

	game:BindToClose(function()
		for player, profile in profiles do
			task.spawn(save, player.UserId, profile, getRobotIds(player))
		end
		local deadline = os.clock() + 25
		while pendingSaves > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
