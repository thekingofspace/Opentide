--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Stage = "Game" | "Modules" | "Ready"

const Folders = { "Packages", "MainPackages", "Shared" }

const ClientLoader = {}

local Stage: Stage = "Game"
local Loaded = false
const Waiting: { thread } = {}
const Listeners: { () -> () } = {}

const function finish()
	Loaded = true
	Stage = "Ready"
	for _, Waiter in Waiting do
		task.spawn(Waiter)
	end
	table.clear(Waiting)
	for _, Callback in Listeners do
		task.spawn(Callback)
	end
	table.clear(Listeners)
end

const function load()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	Stage = "Modules"
	for _, Name in Folders do
		ReplicatedStorage:WaitForChild(Name)
	end
	Players.LocalPlayer:WaitForChild("PlayerScripts")

	finish()
end

function ClientLoader.await()
	if Loaded then
		return
	end
	table.insert(Waiting, coroutine.running())
	coroutine.yield()
end

function ClientLoader.onLoaded(Callback: () -> ()): () -> ()
	if Loaded then
		task.spawn(Callback)
		return function() end
	end
	table.insert(Listeners, Callback)
	return function()
		const Index = table.find(Listeners, Callback)
		if Index then
			table.remove(Listeners, Index)
		end
	end
end

function ClientLoader.isLoaded(): boolean
	return Loaded
end

function ClientLoader.getStage(): Stage
	return Stage
end

task.spawn(load)

return ClientLoader
