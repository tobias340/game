--!strict
-- Client entry point.

local Hud = require(script.Hud)
local Knockback = require(script.Knockback)
local PromptFilter = require(script.PromptFilter)

Hud.start()
PromptFilter.start()
Knockback.start()
