--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Flight = require(ReplicatedStorage.Shared.Tools.Throwables.Flight)
const Tools = require(script.Parent.Tools)

export type Result = {
    Ok: boolean,
    Error: string?,
}

type Entry = {
    Slot: string,
    Build: ToolBuild,
    Kind: string,
    Origin: Vector3,
    Velocity: Vector3,
    Time: number,
    Drop: number?,
    Rest: CFrame?,
}

const Throws = {
    MaxGap = 10,
    MaxSpeed = 400,
    MaxDrop = 4,
    RangeSlack = 80,
    Cooldown = 0.3,
}

const Net = NetWatch.Tools
const Thrown: { [Player]: { [string]: Entry } } = {}
const Stamps: { [Player]: number } = {}
local Started = false

const function fail(Message: string): Result
    return { Ok = false, Error = Message }
end

const function finite(Value: number): boolean
    return Value == Value and math.abs(Value) < 1e6
end

const function vector(Value: unknown): Vector3?
    if typeof(Value) ~= "Vector3" then
        return nil
    end
    return if finite(Value.X) and finite(Value.Y) and finite(Value.Z) then Value else nil
end

const function frame(Value: unknown): CFrame?
    if typeof(Value) ~= "CFrame" then
        return nil
    end
    for _, Number in { Value:GetComponents() } do
        if not finite(Number) then
            return nil
        end
    end
    return Value
end

const function rootOf(Player: Player): BasePart?
    const Character = Player.Character
    const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    return if Root and Root:IsA("BasePart") then Root else nil
end

const function payload(Player: Player, Item: Entry): { [string]: any }
    return {
        Thrower = Player,
        Slot = Item.Slot,
        Build = Item.Build,
        Kind = Item.Kind,
        Origin = Item.Origin,
        Velocity = Item.Velocity,
        Time = Item.Time,
        Drop = Item.Drop,
        Rest = Item.Rest,
    }
end

const function recall(Player: Player, Slot: string)
    const Mine = Thrown[Player]
    if not Mine or not Mine[Slot] then
        return
    end
    Mine[Slot] = nil
    Tools.hide(Player, Slot, false)
    Net:Broadcast("@Throw/Gone", Player, Slot)
end

const function recallAll(Player: Player)
    const Mine = Thrown[Player]
    if not Mine then
        return
    end
    for Slot in table.clone(Mine) do
        recall(Player, Slot)
    end
end

const function toss(Player: Player, Hand: unknown, Data: unknown): Result
    const Item, Build = Tools.held(Player, Hand)
    const Root = rootOf(Player)
    if not Item or not Build or not Root or type(Data) ~= "table" then
        return fail("You are not holding that")
    end
    const Given = Data :: { [string]: any }
    const Stats = Item.Stats
    const KindName = Stats.Throw
    if type(KindName) ~= "string" or not Flight.Kinds[KindName] or Given.Kind ~= KindName then
        return fail("That can not be thrown")
    end
    const Mine = Thrown[Player] or {}
    Thrown[Player] = Mine
    if Mine[Item.Slot] then
        return fail("That is already thrown")
    end
    const Now = os.clock()
    if Now - (Stamps[Player] or 0) < Throws.Cooldown then
        return fail("Slow down a little")
    end
    const Origin = vector(Given.Origin)
    const Velocity = vector(Given.Velocity)
    const Time = Given.Time
    const Drop = Given.Drop
    const Rest = frame(Given.Rest)
    if not Origin or not Velocity or type(Time) ~= "number" or not finite(Time) or Time <= 0 or Time > Flight.Limit + 0.01 then
        return fail("That throw did not make sense")
    end
    if Drop ~= nil and (type(Drop) ~= "number" or not finite(Drop) or Drop < 0 or Drop > Throws.MaxDrop) then
        return fail("That throw did not make sense")
    end
    if Given.Rest ~= nil and not Rest then
        return fail("That throw did not make sense")
    end
    if (Origin - Root.Position).Magnitude > Throws.MaxGap or Velocity.Magnitude < 1 or Velocity.Magnitude > Throws.MaxSpeed then
        return fail("That throw did not make sense")
    end
    const Range = Stats.ThrowRange or 100
    if Rest and (Rest.Position - Origin).Magnitude > Range + Throws.RangeSlack then
        return fail("That is too far to throw")
    end
    Stamps[Player] = Now
    const Fall = if type(Drop) == "number" then Drop else nil
    const Made: Entry = {
        Slot = Item.Slot,
        Build = Build,
        Kind = KindName,
        Origin = Origin,
        Velocity = Velocity,
        Time = Time,
        Drop = Fall,
        Rest = Rest,
    }
    Mine[Item.Slot] = Made
    Tools.hide(Player, Item.Slot, true)
    Net:BroadcastExcept(Player, "@Throw/Thrown", payload(Player, Made))
    if not Rest then
        task.delay(Time + (Fall or 0) + 0.2, function()
            const Current = Thrown[Player]
            if Current and Current[Made.Slot] == Made then
                recall(Player, Made.Slot)
            end
        end)
    end
    return { Ok = true }
end

const function retrieve(Player: Player, Slot: unknown): Result
    const Mine = Thrown[Player]
    const Item = if Mine and type(Slot) == "string" then Mine[Slot] else nil
    if not Item then
        return fail("There is nothing to get back")
    end
    recall(Player, Item.Slot)
    return { Ok = true }
end

const function list(_Player: Player): { { [string]: any } }
    const Made: { { [string]: any } } = {}
    for Owner, Mine in Thrown do
        for _, Item in Mine do
            if Item.Rest then
                table.insert(Made, payload(Owner, Item))
            end
        end
    end
    return Made
end

const function watch(Player: Player)
    Player.CharacterAdded:Connect(function()
        recallAll(Player)
    end)
end

function Throws.start()
    if Started then
        return
    end
    Started = true
    Net:When("@Throw/Toss", toss)
    Net:When("@Throw/Retrieve", retrieve)
    Net:When("@Throw/List", list)
    Tools.Changed:Connect(function(Player: Player, Slots: { string })
        for _, Slot in Slots do
            recall(Player, Slot)
        end
    end)
    Players.PlayerAdded:Connect(watch)
    for _, Player in Players:GetPlayers() do
        watch(Player)
    end
    Players.PlayerRemoving:Connect(function(Player: Player)
        recallAll(Player)
        Thrown[Player] = nil
        Stamps[Player] = nil
    end)
end

return Throws
