--!strict
-- Every robot in the game. Add a robot by adding a line to Robots.List.

export type Rarity = {
	Name: string,
	Weight: number, -- how often this rarity shows up on the conveyor, relative to the others
	Color: Color3,
	Scale: number, -- model size multiplier
}

export type RobotDef = {
	Id: string, -- stored in player saves, so never rename one that has shipped
	Name: string,
	Rarity: string,
	Price: number,
	Income: number, -- cash per second while it sits on a pedestal
	Color: Color3,
}

local Robots = {}

Robots.Rarities = {
	{ Name = "Common", Weight = 60, Color = Color3.fromRGB(205, 205, 205), Scale = 1 },
	{ Name = "Uncommon", Weight = 25, Color = Color3.fromRGB(90, 225, 110), Scale = 1.1 },
	{ Name = "Rare", Weight = 10, Color = Color3.fromRGB(70, 155, 255), Scale = 1.2 },
	{ Name = "Epic", Weight = 4, Color = Color3.fromRGB(185, 95, 255), Scale = 1.35 },
	{ Name = "Legendary", Weight = 0.9, Color = Color3.fromRGB(255, 200, 40), Scale = 1.5 },
	{ Name = "Mythic", Weight = 0.1, Color = Color3.fromRGB(255, 60, 115), Scale = 1.7 },
} :: { Rarity }

-- stylua: ignore
Robots.List = {
	{ Id = "scrapbot", Name = "Scrapbot", Rarity = "Common", Price = 25, Income = 1, Color = Color3.fromRGB(150, 95, 60) },
	{ Id = "toaster_bot", Name = "Toaster Bot", Rarity = "Common", Price = 60, Income = 2, Color = Color3.fromRGB(200, 200, 210) },
	{ Id = "bolt_buddy", Name = "Bolt Buddy", Rarity = "Common", Price = 120, Income = 4, Color = Color3.fromRGB(220, 190, 80) },
	{ Id = "sweepy", Name = "Sweepy", Rarity = "Uncommon", Price = 350, Income = 10, Color = Color3.fromRGB(60, 170, 160) },
	{ Id = "beep_boop", Name = "Beep Boop", Rarity = "Uncommon", Price = 700, Income = 18, Color = Color3.fromRGB(240, 140, 50) },
	{ Id = "laser_larry", Name = "Laser Larry", Rarity = "Rare", Price = 1800, Income = 40, Color = Color3.fromRGB(200, 50, 50) },
	{ Id = "drone_o", Name = "Drone-O", Rarity = "Rare", Price = 3500, Income = 75, Color = Color3.fromRGB(40, 70, 140) },
	{ Id = "mecha_pup", Name = "Mecha Pup", Rarity = "Epic", Price = 9000, Income = 180, Color = Color3.fromRGB(230, 120, 180) },
	{ Id = "turbo_tron", Name = "Turbo Tron", Rarity = "Epic", Price = 16000, Income = 320, Color = Color3.fromRGB(130, 220, 60) },
	{ Id = "titan_x", Name = "Titan X", Rarity = "Legendary", Price = 50000, Income = 900, Color = Color3.fromRGB(230, 180, 50) },
	{ Id = "omega_core", Name = "Omega Core", Rarity = "Legendary", Price = 120000, Income = 2000, Color = Color3.fromRGB(240, 240, 255) },
	{ Id = "quantum_king", Name = "Quantum King", Rarity = "Mythic", Price = 500000, Income = 7500, Color = Color3.fromRGB(120, 40, 200) },
	{ Id = "galaxy_golem", Name = "Galaxy Golem", Rarity = "Mythic", Price = 1500000, Income = 20000, Color = Color3.fromRGB(25, 25, 60) },
} :: { RobotDef }

Robots.ById = {} :: { [string]: RobotDef }
Robots.ByRarity = {} :: { [string]: { RobotDef } }
Robots.RarityByName = {} :: { [string]: Rarity }

for _, rarity in Robots.Rarities do
	Robots.RarityByName[rarity.Name] = rarity
	Robots.ByRarity[rarity.Name] = {}
end

for _, def in Robots.List do
	assert(Robots.ById[def.Id] == nil, `Duplicate robot id "{def.Id}"`)
	assert(Robots.RarityByName[def.Rarity], `Robot "{def.Id}" has unknown rarity "{def.Rarity}"`)
	Robots.ById[def.Id] = def
	table.insert(Robots.ByRarity[def.Rarity], def)
end

-- Picks a random robot for the conveyor: first a rarity by weight, then a robot of that rarity.
function Robots.roll(rng: Random): RobotDef
	local total = 0
	for _, rarity in Robots.Rarities do
		total += rarity.Weight
	end

	local pick = rng:NextNumber() * total
	for _, rarity in Robots.Rarities do
		pick -= rarity.Weight
		local pool = Robots.ByRarity[rarity.Name]
		if pick <= 0 and #pool > 0 then
			return pool[rng:NextInteger(1, #pool)]
		end
	end
	return Robots.List[1]
end

return Robots
