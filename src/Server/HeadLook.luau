--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)

const HeadLook = {
    MinGap = 0.08,
    MaxYaw = 75,
    MaxPitch = 50,
}

const Net = NetWatch.Look
const Listening: { [Player]: boolean } = {}
const Last: { [Player]: number } = {}
local Started = false

const function update(Player: Player, Yaw: unknown, Pitch: unknown)
    if type(Yaw) ~= "number" or type(Pitch) ~= "number" or Yaw ~= Yaw or Pitch ~= Pitch then
        return
    end
    const Now = os.clock()
    if Now - (Last[Player] or 0) < HeadLook.MinGap then
        return
    end
    Last[Player] = Now
    const Targets: { Player } = {}
    for Other, On in Listening do
        if On and Other ~= Player and Other.Parent then
            table.insert(Targets, Other)
        end
    end
    if #Targets > 0 then
        Net:BroadcastTo(Targets, "@Look/Update", Player, math.clamp(math.round(Yaw), -HeadLook.MaxYaw, HeadLook.MaxYaw), math.clamp(math.round(Pitch), -HeadLook.MaxPitch, HeadLook.MaxPitch))
    end
end

function HeadLook.start()
    if Started then
        return
    end
    Started = true
    Net:On("@Look/Set", update)
    Net:On("@Look/Listen", function(Player: Player, On: unknown)
        Listening[Player] = On == true
    end)
    Players.PlayerRemoving:Connect(function(Player: Player)
        Listening[Player] = nil
        Last[Player] = nil
    end)
end

return HeadLook
