--!strict
-- Sends on-screen messages (toasts) to players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NotifyEvent = ReplicatedStorage.Remotes.Notify

export type Kind = "info" | "good" | "bad"

local Notify = {}

function Notify.send(player: Player, text: string, kind: Kind?)
	if player.Parent == Players then
		NotifyEvent:FireClient(player, text, kind or "info")
	end
end

function Notify.all(text: string, kind: Kind?)
	NotifyEvent:FireAllClients(text, kind or "info")
end

return Notify
