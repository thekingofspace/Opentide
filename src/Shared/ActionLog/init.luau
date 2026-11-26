--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")
const Workspace = game:GetService("Workspace")

const vision = require(ReplicatedStorage.MainPackages.vision)
const signal = require(ReplicatedStorage.MainPackages.signal)
const Sounds = require(ReplicatedStorage.Shared.Sounds)
const PropPlacer = require(ReplicatedStorage.Shared.PropPlacer)
const ToolsClient = require(ReplicatedStorage.Shared.Tools.Client)
const Dice = require(ReplicatedStorage.Shared.Dice)
const Bridges = require(script.Bridges)
const UI = require(ReplicatedStorage.Shared.UI)
const View = UI.view("ActionLog")

type Entry = Bridges.EntryRow

const ActionLog = {
    MaxEntries = 300,
    MaxNote = 200,
    PickRange = 1000,
    Changed = signal.new(),
}

local Shown = false
local Picking = false
local Started = false
local Counter = 0
const Tracked: { [number]: Player } = {}
const Entries: { Entry } = {}

const function stamp(): string
    return os.date("%H:%M") :: string
end

const function refresh()
    const Chips: { Bridges.PlayerChip } = {}
    local Count = 0
    for Id, Player in Tracked do
        Count += 1
        table.insert(Chips, { Id = Id, Name = Player.DisplayName })
    end
    table.sort(Chips, function(A: Bridges.PlayerChip, B: Bridges.PlayerChip): boolean
        return A.Name < B.Name
    end)
    View.LogPlayers(Chips)
    View.LogState({ Picking = Picking, Count = Count })
    View.LogEntries(table.clone(Entries))
    ActionLog.Changed:Fire()
end

function ActionLog.add(Text: string, Kind: string?)
    Counter += 1
    table.insert(Entries, { Id = Counter, Time = stamp(), Text = Text, Kind = Kind or "System" })
    while #Entries > ActionLog.MaxEntries do
        table.remove(Entries, 1)
    end
    refresh()
end

const function setPicking(Value: boolean)
    Picking = Value
    ToolsClient.blockInput("ActionLog", Value)
    refresh()
end

const function playerAt(Screen: Vector2, Viewport: boolean): Player?
    const Camera = Workspace.CurrentCamera
    if not Camera then
        return nil
    end
    const Ray = if Viewport then Camera:ViewportPointToRay(Screen.X, Screen.Y) else Camera:ScreenPointToRay(Screen.X, Screen.Y)
    const Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    const Mine = Players.LocalPlayer.Character
    Params.FilterDescendantsInstances = if Mine then { Mine } else {}
    const Hit = Workspace:Raycast(Ray.Origin, Ray.Direction * ActionLog.PickRange, Params)
    local Part: Instance? = if Hit then Hit.Instance else nil
    while Part and Part ~= Workspace do
        if Part:IsA("Model") then
            const Found = Players:GetPlayerFromCharacter(Part)
            if Found then
                return Found
            end
        end
        Part = Part.Parent
    end
    return nil
end

function ActionLog.track(Player: Player)
    if Player == Players.LocalPlayer then
        PropPlacer.toast("Your own rolls are always logged", "Info")
        return
    end
    if Tracked[Player.UserId] then
        PropPlacer.toast(`{Player.DisplayName} is already in the log`, "Info")
        return
    end
    Tracked[Player.UserId] = Player
    ActionLog.add(`added {Player.DisplayName}`, "System")
    Sounds.play("Select")
end

function ActionLog.untrack(Id: number)
    const Player = Tracked[Id]
    Tracked[Id] = nil
    if Player then
        ActionLog.add(`removed {Player.DisplayName}`, "System")
    end
end

function ActionLog.isShown(): boolean
    return Shown
end

function ActionLog.show(Value: boolean)
    if Shown ~= Value then
        Sounds.play(if Value then "MenuOpen" else "MenuClose")
    end
    Shown = Value
    if not Value and Picking then
        setPicking(false)
    end
    View.LogShown(Value)
    ActionLog.Changed:Fire()
end

function ActionLog.toggle()
    ActionLog.show(not Shown)
end

function ActionLog.start()
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    const Gui = vision.create({
        ClassName = "ScreenGui",
        Name = "ActionLog",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 5,
    }) :: ScreenGui
    Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    UI.mount("ActionLog", Gui)

    Bridges.Log:Bind(function(Action: string, Value: any)
        if Action == "Close" then
            ActionLog.show(false)
        elseif Action == "Pick" then
            setPicking(not Picking)
        elseif Action == "Remove" and type(Value) == "number" then
            ActionLog.untrack(Value)
        elseif Action == "Note" and type(Value) == "string" then
            const Text = string.sub(string.match(Value, "^%s*(.-)%s*$") or "", 1, ActionLog.MaxNote)
            if Text ~= "" then
                ActionLog.add(Text, "Note")
            end
        elseif Action == "Clear" then
            table.clear(Entries)
            refresh()
        end
    end)

    UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
        if not Picking or Processed then
            return
        end
        const Kind = Input.UserInputType
        if Kind == Enum.UserInputType.MouseButton1 or Kind == Enum.UserInputType.Touch then
            const Touch = Kind == Enum.UserInputType.Touch
            const Found = playerAt(if Touch then Vector2.new(Input.Position.X, Input.Position.Y) else UserInputService:GetMouseLocation(), not Touch)
            if Found then
                setPicking(false)
                ActionLog.track(Found)
            else
                PropPlacer.toast("That is not a player, click on someone", "Info")
            end
        elseif Input.KeyCode == Enum.KeyCode.Escape then
            setPicking(false)
        end
    end)

    Dice.Rolled:Connect(function(Player: Player, Kind: Dice.Kind, Result: number, Info: Dice.Info)
        if Player == Players.LocalPlayer or Tracked[Player.UserId] then
            const Who = if Player == Players.LocalPlayer then "you" else Player.DisplayName
            const Extra = if Info.Bonus ~= 0 or Info.Modifier ~= 0 then `  ({Dice.describe(Kind, Result, Info)})` else ""
            ActionLog.add(`{Who} rolled {Info.Total} on a {Kind.Name}{Extra}`, "Roll")
        end
    end)

    Players.PlayerRemoving:Connect(function(Player: Player)
        if Tracked[Player.UserId] then
            Tracked[Player.UserId] = nil
            ActionLog.add(`{Player.DisplayName} left`, "System")
        end
    end)
    refresh()
end

return ActionLog
