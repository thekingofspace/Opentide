--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const SettingsList = require(ReplicatedStorage.Shared.Utility.SettingsList)

export type Result = {
    Ok: boolean,
    Error: string?,
}

const Settings = {
    Cooldown = 1,
}

const Net = NetWatch.DataNet
const Owners: { [Player]: PlayerData } = {}
const Stamps: { [Player]: number } = {}
const Specs: { [string]: SettingsList.Setting } = {}
local Started = false

for _, Spec in SettingsList do
    Specs[Spec.Id] = Spec
end

const function clean(Given: unknown): { [string]: boolean | number }
    const Made: { [string]: boolean | number } = {}
    if type(Given) ~= "table" then
        return Made
    end
    for Id, Value in Given :: { [any]: any } do
        const Spec = if type(Id) == "string" then Specs[Id] else nil
        if not Spec then
            continue
        end
        if Spec.Kind == "Toggle" and type(Value) == "boolean" then
            Made[Id] = Value
        elseif Spec.Kind == "Number" and type(Value) == "number" and Value == Value then
            Made[Id] = math.clamp(Value, Spec.Min or -math.huge, Spec.Max or math.huge)
        end
    end
    return Made
end

function Settings.attach(Player: Player, Data: PlayerData)
    Data.Settings = clean(Data.Settings)
    Owners[Player] = Data
    Net:BroadcastTo(Player, "@Settings/State", Data.Settings)
end

const function save(Player: Player, Given: unknown): Result
    const Data = Owners[Player]
    if not Data then
        return { Ok = false, Error = "Your data is still loading" }
    end
    const Now = os.clock()
    if Stamps[Player] and Now - Stamps[Player] < Settings.Cooldown then
        return { Ok = false, Error = "Slow down a little" }
    end
    Stamps[Player] = Now
    Data.Settings = clean(Given)
    return { Ok = true }
end

function Settings.start()
    if Started then
        return
    end
    Started = true
    Net:When("@Settings/Save", save)
    Players.PlayerRemoving:Connect(function(Player: Player)
        Owners[Player] = nil
        Stamps[Player] = nil
    end)
end

return Settings
