--!strict
------------------------------------------------------- LOADERS
const ReplicatedFirst = game:GetService("ReplicatedFirst")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ClientLoader = require(ReplicatedFirst:WaitForChild("ClientLoader")); ClientLoader.await();
const promise = require(ReplicatedStorage.Packages.promise)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const PropPlacer = require(ReplicatedStorage.Shared.PropPlacer)
const PropBrowser = require(ReplicatedStorage.Shared.PropPlacer.Browser)
const PropControl = require(ReplicatedStorage.Shared.PropPlacer.Controller)
const LocalAnimations = require(ReplicatedStorage.Shared.AnimationController.LocalAnimations)
const Utility = require(ReplicatedStorage.Shared.Utility)
const Sounds = require(ReplicatedStorage.Shared.Sounds)
const ToolsClient = require(ReplicatedStorage.Shared.Tools.Client)
const Movement = require(ReplicatedStorage.Shared.Movement)
type ConfirmedData = Partial<PlayerData, {
	
}>
------------------------------------------------------- ClientLoad
local PromisedThread:thread? = nil
const ClientDataPromise = promise.new(function(Resolve)
	PromisedThread = coroutine.running()
	Resolve(coroutine.yield()::ConfirmedData)
end)
------------------------------------------------------- Linkers Here
ClientDataPromise:andThen(function(Data)
	Sounds.start(); PropPlacer.load(); PropBrowser.start(); PropControl.start(); LocalAnimations.start(); Utility.start(); ToolsClient.start(); Movement.start();
end)
------------------------------------------------------- Event Linkers here
----------------------- CLIENT DATA
NetWatch.DataNet:On("@Game/DataReady", function(ClientData:ConfirmedData)
	if PromisedThread then
		task.spawn(PromisedThread, ClientData)
	end
end)
------------------------------------------------------- Boot Linkers
task.defer(NetWatch.Start) -- allow client to catchup