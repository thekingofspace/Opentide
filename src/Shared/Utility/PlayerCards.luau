--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const WidgetTypes = require(ReplicatedStorage.Shared.UI.WidgetTypes)
const Widgets = require(ReplicatedStorage.Shared.PropPlacer.Widgets)
const Stats = require(ReplicatedStorage.Shared.Bio.Stats)

const PlayerCards = {
    DetectorName = "PlayerCard",
    LevelMinutes = 50,
    DetectorWait = 15,
}

local Started = false

function PlayerCards.level(Playtime: number): number
    return math.floor(Playtime / (PlayerCards.LevelMinutes * 60)) + 1
end

const function ago(Stamp: number): string
    const Since = math.max(os.time() - Stamp, 0)
    if Since < 60 then
        return "just now"
    elseif Since < 3600 then
        return `{math.floor(Since / 60)}m ago`
    elseif Since < 86400 then
        return `{math.floor(Since / 3600)}h ago`
    end
    return `{math.floor(Since / 86400)}d ago`
end

const function metaStatus(Player: Player): string
    if Player:GetAttribute("MetaVision") == true then
        return "using it now"
    end
    const Last = Player:GetAttribute("MetaVisionLast")
    return if type(Last) == "number" then `last used {ago(Last)}` else "never used"
end

const function played(Seconds: number): string
    const Hours = math.floor(Seconds / 3600)
    const Minutes = math.floor((Seconds % 3600) / 60)
    return if Hours > 0 then `{Hours}h {Minutes}m played` else `{Minutes}m played`
end

function PlayerCards.rows(Player: Player): { WidgetTypes.InfoRow }
    const Playtime = Player:GetAttribute("Playtime")
    const Seconds = if type(Playtime) == "number" then Playtime else 0
    const Joined = Player:GetAttribute("FirstJoined")
    const Rows: { WidgetTypes.InfoRow } = {}
    const Nickname = Player:GetAttribute("Nickname")
    if type(Nickname) == "string" and Nickname ~= "" then
        table.insert(Rows, { Label = "nickname", Value = Nickname })
    end
    table.insert(Rows, { Label = "username", Value = `@{Player.Name}` })
    const Description = Player:GetAttribute("Description")
    if type(Description) == "string" and Description ~= "" then
        table.insert(Rows, { Label = "about", Value = Description })
    end
    for _, Def in Stats.sorted() do
        const Value = Stats.valueOf(Player, Def)
        table.insert(Rows, { Label = Def.Name, Value = `{Value}  ({Stats.signed(Stats.bonus(Def, Value))} to rolls)` })
    end
    table.insert(Rows, { Label = "level", Value = `{PlayerCards.level(Seconds)}  ({played(Seconds)})` })
    table.insert(Rows, { Label = "joined", Value = if type(Joined) == "number" then string.lower(os.date("%b %d, %Y", Joined)) else "just now" })
    table.insert(Rows, { Label = "meta vision", Value = metaStatus(Player) })
    return Rows
end

function PlayerCards.show(Player: Player)
    Widgets.popup(`player_{Player.UserId}`, Player.DisplayName, PlayerCards.rows(Player))
end

const function hook(Player: Player, Character: Model)
    if Player == Players.LocalPlayer then
        return
    end
    const Detector = Character:WaitForChild(PlayerCards.DetectorName, PlayerCards.DetectorWait)
    if not Detector or not Detector:IsA("ClickDetector") then
        return
    end
    Detector.MouseClick:Connect(function(Clicker: Player)
        if Clicker == Players.LocalPlayer and Player.Parent == Players then
            PlayerCards.show(Player)
        end
    end)
end

const function watch(Player: Player)
    Player.CharacterAdded:Connect(function(Character: Model)
        hook(Player, Character)
    end)
    const Character = Player.Character
    if Character then
        task.spawn(hook, Player, Character)
    end
end

function PlayerCards.start()
    if Started then
        return
    end
    Started = true
    Players.PlayerAdded:Connect(watch)
    for _, Player in Players:GetPlayers() do
        watch(Player)
    end
end

return PlayerCards
