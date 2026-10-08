--!strict
-- Shows each robot's prompts only to the right player: Steal to everyone except the owner (while the
-- base is unlocked), Sell only to the owner. The server checks both again when a prompt is used.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local localUserId = Players.LocalPlayer.UserId

local PromptFilter = {}

local function refresh(prompt: ProximityPrompt)
	local mine = prompt:GetAttribute("OwnerUserId") == localUserId
	if prompt:HasTag("StealPrompt") then
		prompt.Enabled = not mine and prompt:GetAttribute("Locked") ~= true
	else
		prompt.Enabled = mine
	end
end

local function watch(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	refresh(instance)
	instance.AttributeChanged:Connect(function()
		refresh(instance)
	end)
end

function PromptFilter.start()
	for _, tag in { "StealPrompt", "SellPrompt" } do
		for _, instance in CollectionService:GetTagged(tag) do
			watch(instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
	end
end

return PromptFilter
