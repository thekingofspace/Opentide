--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)

const Stats = {
    Interval = 30,
    DetectorName = "PlayerCard",
    DetectorRange = 48,
}

type Owner = {
    Data: PlayerData,
    Since: number,
}

const Owners: { [Player]: Owner } = {}
local Started = false

const function bank(Player: Player)
    const Owner = Owners[Player]
    if not Owner then
        return
    end
    const Now = os.clock()
    Owner.Data.Playtime = (Owner.Data.Playtime or 0) + (Now - Owner.Since)
    Owner.Since = Now
    Player:SetAttribute("Playtime", math.floor(Owner.Data.Playtime or 0))
    Player:SetAttribute("FirstJoined", Owner.Data.FirstJoined)
    Player:SetAttribute("MetaVisionLast", Owner.Data.MetaVisionLast)
end

function Stats.setMetaVision(Player: Player, On: unknown)
    const Owner = Owners[Player]
    if not Owner or type(On) ~= "boolean" then
        return
    end
    const Was = Player:GetAttribute("MetaVision") == true
    if Was == On and Player:GetAttribute("MetaVision") ~= nil then
        return
    end
    Player:SetAttribute("MetaVision", On)
    if On or Was then
        Owner.Data.MetaVisionLast = os.time()
        Player:SetAttribute("MetaVisionLast", Owner.Data.MetaVisionLast)
    end
end

const function detector(Character: Model)
    if Character:FindFirstChild(Stats.DetectorName) then
        return
    end
    const Made = Instance.new("ClickDetector")
    Made.Name = Stats.DetectorName
    Made.MaxActivationDistance = Stats.DetectorRange
    Made.Parent = Character
end

const function watch(Player: Player)
    Player.CharacterAdded:Connect(detector)
    const Character = Player.Character
    if Character then
        detector(Character)
    end
end

function Stats.attach(Player: Player, Data: PlayerData)
    if type(Data.Playtime) ~= "number" then
        Data.Playtime = 0
    end
    if type(Data.FirstJoined) ~= "number" then
        Data.FirstJoined = os.time()
    end
    Owners[Player] = {
        Data = Data,
        Since = os.clock(),
    }
    bank(Player)
end

function Stats.start()
    if Started then
        return
    end
    Started = true
    Players.PlayerAdded:Connect(watch)
    for _, Player in Players:GetPlayers() do
        watch(Player)
    end
    NetWatch.DataNet:On("@Stats/MetaVision", function(Player: Player, On: unknown)
        Stats.setMetaVision(Player, On)
    end)
    Players.PlayerRemoving:Connect(function(Player: Player)
        bank(Player)
        Owners[Player] = nil
    end)
    task.spawn(function()
        while true do
            task.wait(Stats.Interval)
            for Player in Owners do
                bank(Player)
            end
        end
    end)
end

return Stats
