--!strict
-- Tunable numbers for the whole game. Balance the game here instead of inside the services.

local Config = {
	StartingCash = 100,

	-- Conveyor
	ConveyorSpawnInterval = 2.5, -- seconds between new robots on the conveyor
	ConveyorSpeed = 7, -- studs per second

	-- Bases
	LockDuration = 60, -- seconds a base stays locked after its owner steps on the lock button
	SellRefund = 0.5, -- share of the price you get back when selling a robot

	-- Stealing
	StealHoldDuration = 1.5, -- seconds you hold E to grab a robot
	NormalWalkSpeed = 16,
	CarryWalkSpeed = 11,

	-- Wrench
	BonkCooldown = 1,
	BonkRange = 8,
	BonkKnockback = 55,

	-- Saving
	DataStoreName = "StealARobot_v1",
	AutosaveInterval = 120,
}

return Config
