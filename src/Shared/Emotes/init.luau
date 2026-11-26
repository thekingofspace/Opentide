--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const vision = require(ReplicatedStorage.MainPackages.vision)
const signal = require(ReplicatedStorage.MainPackages.signal)
const Defaults = require(ReplicatedStorage.Shared.AnimationController.Defaults)
const LocalAnimations = require(ReplicatedStorage.Shared.AnimationController.LocalAnimations)
const ToolsClient = require(ReplicatedStorage.Shared.Tools.Client)
const PropPlacer = require(ReplicatedStorage.Shared.PropPlacer)
const Sounds = require(ReplicatedStorage.Shared.Sounds)
const UI = require(ReplicatedStorage.Shared.UI)
const Bridges = require(script.Bridges)

const Emotes = {
    Changed = signal.new(),
}

const View = UI.view("Emotes")
local Shown = false
local Started = false
local Showing: string? = nil

const function refresh()
    const Ids: { string } = {}
    for Id in Defaults.Emotes do
        table.insert(Ids, Id)
    end
    table.sort(Ids, function(A: string, B: string): boolean
        const First = Defaults.Emotes[A]
        const Second = Defaults.Emotes[B]
        if (First.Order or 99) ~= (Second.Order or 99) then
            return (First.Order or 99) < (Second.Order or 99)
        end
        return A < B
    end)
    const Now = LocalAnimations.emoting()
    const Cards: { Bridges.EmoteCard } = {}
    for _, Id in Ids do
        table.insert(Cards, { Id = Id, Name = Defaults.Emotes[Id].Label or string.lower(Id), Active = Now == Id })
    end
    View.EmoteList(Cards)
end

function Emotes.play(Id: string): boolean
    if ToolsClient.current() then
        PropPlacer.toast("Put your tool away to emote", "Info")
        return false
    end
    if LocalAnimations.emoting() == Id then
        LocalAnimations.stopEmote()
        refresh()
        return true
    end
    if not LocalAnimations.emote(Id) then
        PropPlacer.toast("Stand still to emote", "Info")
        return false
    end
    refresh()
    return true
end

function Emotes.isShown(): boolean
    return Shown
end

function Emotes.show(Value: boolean)
    if Shown ~= Value then
        Sounds.play(if Value then "MenuOpen" else "MenuClose")
    end
    Shown = Value
    View.EmotesShown(Value)
    if Value then
        refresh()
    end
    Emotes.Changed:Fire()
end

function Emotes.toggle()
    Emotes.show(not Shown)
end

function Emotes.start()
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    const Gui = vision.create({
        ClassName = "ScreenGui",
        Name = "Emotes",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 5,
    }) :: ScreenGui
    Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    UI.mount("Emotes", Gui)

    Bridges.Emotes:Bind(function(Action: string, Value: any)
        if Action == "Close" then
            Emotes.show(false)
        elseif Action == "Play" and type(Value) == "string" then
            Emotes.play(Value)
        elseif Action == "Stop" then
            LocalAnimations.stopEmote()
            refresh()
        end
    end)

    ToolsClient.Equipped:Connect(function(ToolId: string?)
        if ToolId then
            LocalAnimations.stopEmote()
        end
    end)

    RunService.Heartbeat:Connect(function()
        if not Shown then
            return
        end
        const Now = LocalAnimations.emoting()
        if Now ~= Showing then
            Showing = Now
            refresh()
        end
    end)
end

return Emotes
