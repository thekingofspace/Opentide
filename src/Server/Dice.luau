--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Kinds = require(ReplicatedStorage.Shared.Dice.Kinds)
const Stats = require(ReplicatedStorage.Shared.Bio.Stats)

const Dice = {
    Cooldown = 2,
    MaxModifier = 99,
}

const Net = NetWatch.Dice
const Last: { [Player]: number } = {}
const Rng = Random.new()
local Started = false

const function roll(Player: Player, Id: unknown, StatId: unknown, Modifier: unknown): { Ok: boolean, Error: string?, Result: number? }
    local Found: Kinds.Kind? = nil
    for _, Kind in Kinds do
        if Kind.Id == Id then
            Found = Kind
        end
    end
    if not Found then
        return { Ok = false, Error = "That die does not exist" }
    end
    const Now = os.clock()
    if Now - (Last[Player] or 0) < Dice.Cooldown then
        return { Ok = false, Error = "Wait for your last roll to land" }
    end
    Last[Player] = Now
    const Result = Rng:NextInteger(1, Found.Sides)
    const Stat = Stats.get(StatId)
    const Bonus = if Stat then Stats.bonus(Stat, Stats.valueOf(Player, Stat)) else 0
    const Extra = if type(Modifier) == "number" and Modifier == Modifier then math.clamp(math.floor(Modifier), -Dice.MaxModifier, Dice.MaxModifier) else 0
    Net:Broadcast("@Dice/Rolled", Player, Found.Id, Result, {
        Stat = if Stat then Stat.Id else nil,
        Bonus = Bonus,
        Modifier = Extra,
        Total = Result + Bonus + Extra,
    })
    return { Ok = true, Result = Result }
end

function Dice.start()
    if Started then
        return
    end
    Started = true
    Net:When("@Dice/Roll", roll)
    Players.PlayerRemoving:Connect(function(Player: Player)
        Last[Player] = nil
    end)
end

return Dice
