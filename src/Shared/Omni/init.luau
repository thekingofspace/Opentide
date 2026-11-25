--!strict
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const TextChatService = game:GetService("TextChatService")
const Workspace = game:GetService("Workspace")

const vision = require(ReplicatedStorage.MainPackages.vision)
const signal = require(ReplicatedStorage.MainPackages.signal)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Sounds = require(ReplicatedStorage.Shared.Sounds)
const PropPlacer = require(ReplicatedStorage.Shared.PropPlacer)
const AmbientOverride = require(ReplicatedStorage.Shared.Utility.AmbientOverride)
const DayNight = require(ReplicatedStorage.Shared.Utility.DayNight)
const Weather = require(ReplicatedStorage.Shared.Utility.Weather)
const Shared = require(script.Shared)
const Bridges = require(script.Bridges)
const View = require(ReplicatedStorage.Shared.GUI_Elements.Omni)

export type Access = {
    Omni: boolean,
    Commands: boolean,
    Weathers: { string },
}

const Omni = {
    LayerName = "Omni",
    Priority = 100,
    Commands = { "kick", "ban", "unban" },
    Changed = signal.new(),
}

const Net = NetWatch.AdminNet
local Access: Access = { Omni = false, Commands = false, Weathers = {} }
local Shown = false
local Started = false
local Tab = "World"
local Tint = "White"
local PopupTitle = ""
local PopupText = ""
local PinText = ""
local Waited = 0
const Draft: { [string]: number } = {}

const function toast(Text: string?, Info: boolean?)
    if Text and Text ~= "" then
        PropPlacer.toast(Text, if Info then "Info" else "Error")
    end
end

const function call(Action: string, Value: any?, Extra: any?)
    task.spawn(function()
        const Reply = Net:Call("@Omni/Do", Action, Value, Extra)
        if type(Reply) == "table" and Reply.Ok then
            toast(Reply.Message, true)
        else
            toast(if type(Reply) == "table" then Reply.Error else "The server did not answer")
        end
    end)
end

const function tintOf(Id: string): { number }
    for _, Item in Shared.Tints do
        if Item.Id == Id then
            return Item.Color
        end
    end
    return { 255, 255, 255 }
end

const function resetDraft()
    for Key, Range in Shared.Ambient do
        Draft[Key] = Range.Default
    end
    Tint = "White"
end

const function format(Key: string, Value: number): string
    const Range = Shared.Ambient[Key]
    return if Range.Step < 1 then string.format("%.2f", Value) else tostring(Value)
end

const function serverWeather(): string
    const Value = Workspace:GetAttribute(Weather.Attributes.Current)
    return if type(Value) == "string" then Value else Weather.current()
end

const function refreshWorld()
    const Hour = DayNight.hour()
    View.OmniWorld({
        Weather = serverWeather(),
        WeatherFrozen = Workspace:GetAttribute("WeatherFrozen") == true,
        Hour = string.format("%02d:%02d", math.floor(Hour), math.floor((Hour % 1) * 60)),
        TimeFrozen = type(Workspace:GetAttribute(DayNight.FrozenAttribute)) == "number",
    })
end

const function refresh()
    View.OmniTab(Tab)
    refreshWorld()
    const Weathers: { any } = {}
    const Now = serverWeather()
    for _, Name in Access.Weathers do
        table.insert(Weathers, { Id = Name, Name = string.lower(Name), Active = Name == Now })
    end
    View.OmniWeathers(Weathers)
    const Presets: { any } = {}
    for _, Item in Shared.Presets do
        table.insert(Presets, { Id = Item.Id, Name = Item.Name, Active = false })
    end
    View.OmniPresets(Presets)
    const Tints: { any } = {}
    for _, Item in Shared.Tints do
        table.insert(Tints, { Id = Item.Id, Name = Item.Name, Active = Item.Id == Tint })
    end
    View.OmniTints(Tints)
    const Labels: { [string]: string } = {}
    for Key, Value in Draft do
        Labels[Key] = format(Key, Value)
    end
    View.OmniAmbient(Labels)
    const Rows: { Bridges.PlayerRow } = {}
    for _, Player in Players:GetPlayers() do
        if Player ~= Players.LocalPlayer then
            table.insert(Rows, { Id = Player.UserId, Name = Player.DisplayName, Detail = `@{Player.Name}` })
        end
    end
    table.sort(Rows, function(A: Bridges.PlayerRow, B: Bridges.PlayerRow): boolean
        return A.Name < B.Name
    end)
    View.OmniPlayers(Rows)
end

const function applyAmbient()
    const Raw = Workspace:GetAttribute(Shared.AmbientAttribute)
    if type(Raw) ~= "string" then
        AmbientOverride.pop(Omni.LayerName)
        return
    end
    const Ok, Values = pcall(HttpService.JSONDecode, HttpService, Raw)
    if not Ok or type(Values) ~= "table" then
        AmbientOverride.pop(Omni.LayerName)
        return
    end
    AmbientOverride.push(Omni.LayerName, Shared.look(Values) :: any, { Priority = Omni.Priority })
end

const function applyPin()
    const Text = Workspace:GetAttribute(Shared.PinAttribute)
    View.OmniPin(if type(Text) == "string" and Text ~= "" then Text else false)
end

const function addCommands()
    const Folder = Instance.new("Folder")
    Folder.Name = "ModerationCommands"
    Folder.Parent = TextChatService
    for _, Name in Omni.Commands do
        const Command = Instance.new("TextChatCommand")
        Command.Name = `Command_{Name}`
        Command.PrimaryAlias = `/{Name}`
        Command.Parent = Folder
        Command.Triggered:Connect(function(_, Text: string)
            task.spawn(function()
                const Reply = Net:Call("@Admin/Command", Text)
                const Message = if type(Reply) == "table" then (if Reply.Ok then Reply.Message else Reply.Error) else "The server did not answer"
                const Channels = TextChatService:FindFirstChild("TextChannels")
                const System = if Channels then Channels:FindFirstChild("RBXSystem") else nil
                if System and System:IsA("TextChannel") then
                    System:DisplaySystemMessage(Message or "")
                else
                    toast(Message, type(Reply) == "table" and Reply.Ok)
                end
            end)
        end)
    end
end

const function onAction(Action: string, Value: any)
    if Action == "Close" then
        Omni.show(false)
        return
    elseif Action == "Tab" and type(Value) == "string" then
        Tab = Value
        Sounds.play("CustomizeSelect")
    elseif Action == "Weather" and type(Value) == "string" then
        call("Weather", Value)
    elseif Action == "FreezeWeather" then
        call("FreezeWeather", Workspace:GetAttribute("WeatherFrozen") ~= true)
    elseif Action == "Hour" and type(Value) == "number" then
        call("Hour", Value)
    elseif Action == "HourText" and type(Value) == "string" then
        const Hour = tonumber(string.match(Value, "[%d%.]+") or "")
        if Hour then
            call("Hour", Hour)
        else
            toast("Type an hour from 0 to 24")
        end
    elseif Action == "FreezeTime" then
        call("FreezeTime", type(Workspace:GetAttribute(DayNight.FrozenAttribute)) ~= "number")
    elseif Action == "Preset" and type(Value) == "string" then
        for _, Item in Shared.Presets do
            if Item.Id == Value then
                for Key, Number in Item.Values :: { [string]: number } do
                    Draft[Key] = Number
                end
                Tint = Item.Tint
            end
        end
    elseif Action == "AmbientStep" and type(Value) == "table" and type(Value.Key) == "string" then
        const Range = Shared.Ambient[Value.Key]
        if Range then
            const Step = if type(Value.Step) == "number" then Value.Step else 0
            Draft[Value.Key] = if Step == 0 then Range.Default else math.clamp((Draft[Value.Key] or Range.Default) + Step * Range.Step, Range.Min, Range.Max)
        end
    elseif Action == "Tint" and type(Value) == "string" then
        Tint = Value
    elseif Action == "ApplyAmbient" then
        const Values: { [string]: any } = table.clone(Draft)
        Values.Tint = tintOf(Tint)
        call("Ambient", Values)
    elseif Action == "ClearAmbient" then
        resetDraft()
        call("ClearAmbient")
    elseif Action == "PopupTitle" and type(Value) == "string" then
        PopupTitle = Value
        return
    elseif Action == "PopupText" and type(Value) == "string" then
        PopupText = Value
        return
    elseif Action == "SendPopup" then
        call("Popup", PopupTitle, PopupText)
    elseif Action == "PinText" and type(Value) == "string" then
        PinText = Value
        return
    elseif Action == "Pin" then
        call("Pin", PinText)
    elseif Action == "Unpin" then
        call("Unpin")
    elseif Action == "GoTo" and type(Value) == "number" then
        call("Teleport", "GoTo", Value)
    elseif Action == "Bring" and type(Value) == "number" then
        call("Teleport", "Bring", Value)
    elseif Action == "BringAll" then
        call("Teleport", "BringAll")
    elseif Action == "ClosePopup" then
        View.OmniPopup(false)
        return
    end
    refresh()
end

function Omni.access(): Access
    return Access
end

function Omni.isShown(): boolean
    return Shown
end

function Omni.show(Value: boolean)
    if not Access.Omni then
        return
    end
    if Shown ~= Value then
        Sounds.play(if Value then "MenuOpen" else "MenuClose")
    end
    Shown = Value
    View.OmniShown(Value)
    if Value then
        refresh()
    end
    Omni.Changed:Fire()
end

function Omni.toggle()
    Omni.show(not Shown)
end

function Omni.start(): Access
    if Started or not RunService:IsClient() then
        return Access
    end
    Started = true
    resetDraft()
    const Gui = vision.create({
        ClassName = "ScreenGui",
        Name = "Omni",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 8,
    }) :: ScreenGui
    Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    View:Open().Parent = Gui

    Bridges.Omni:Bind(onAction)
    Net:On("@Omni/Popup", function(Title: string, Text: string, From: string)
        if type(Title) == "string" and type(Text) == "string" then
            Sounds.play("Notify")
            View.OmniPopup({ Title = Title, Text = Text, From = if type(From) == "string" then From else "staff" })
        end
    end)
    Workspace:GetAttributeChangedSignal(Shared.AmbientAttribute):Connect(applyAmbient)
    Workspace:GetAttributeChangedSignal(Shared.PinAttribute):Connect(applyPin)
    applyAmbient()
    applyPin()

    const Reply = Net:Call("@Admin/Access")
    if type(Reply) == "table" then
        Access = {
            Omni = Reply.Omni == true,
            Commands = Reply.Commands == true,
            Weathers = if type(Reply.Weathers) == "table" then Reply.Weathers else {},
        }
    end
    if Access.Commands then
        addCommands()
    end
    if Access.Omni then
        for _, Name in { Weather.Attributes.Current, "WeatherFrozen", DayNight.FrozenAttribute } do
            Workspace:GetAttributeChangedSignal(Name):Connect(function()
                if Shown then
                    refresh()
                end
            end)
        end
        RunService.Heartbeat:Connect(function(Delta: number)
            Waited += Delta
            if Shown and Waited >= 1 then
                Waited = 0
                refreshWorld()
            end
        end)
        Players.PlayerAdded:Connect(function()
            if Shown then
                refresh()
            end
        end)
        Players.PlayerRemoving:Connect(function()
            if Shown then
                task.defer(refresh)
            end
        end)
    end
    return Access
end

return Omni
