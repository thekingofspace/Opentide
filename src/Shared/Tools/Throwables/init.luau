--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")
const Workspace = game:GetService("Workspace")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Flight = require(script.Flight)

const Throwables = {
    Flight = Flight,
    ReleaseTime = 0.2,
    SwingTime = 0.55,
    Cooldown = 0.35,
    Range = 100,
    Embed = 0.25,
    StickSquare = 0.3,
    AimReach = 300,
}

const Net = NetWatch.Tools
const Out: { [string]: boolean } = {}
const Live: { [string]: any } = {}
local Started = false

const function toast(Text: string)
    const PropPlacer = require(ReplicatedStorage.Shared.PropPlacer) :: any
    PropPlacer.toast(Text, "Error")
end

const function aim(Origin: Vector3, Range: number, Skip: { Instance }): Vector3
    const Camera = Workspace.CurrentCamera
    if not Camera then
        return Origin + Vector3.new(0, 0, -Range)
    end
    const Mouse = UserInputService:GetMouseLocation()
    const Ray = Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
    const Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = Skip
    const Reach = Range + Throwables.AimReach
    const Hit = Workspace:Raycast(Ray.Origin, Ray.Direction * Reach, Params)
    local Target = if Hit then Hit.Position else Ray.Origin + Ray.Direction * Reach
    const Gap = Target - Origin
    if Gap.Magnitude < 1 then
        Target = Origin + Ray.Direction * 4
    elseif Gap.Magnitude > Range then
        Target = Origin + Gap.Unit * Range
    end
    return Target
end

const function labels(Context: any)
    const Throw = if Out[Context.Slot] then "thrown" else "throw"
    if Context.Labels.Throw ~= Throw then
        Context.setLabel("Throw", Throw)
    end
end

function Throwables.out(Slot: string): boolean
    return Out[Slot] == true
end

const function release(Context: any, Stats: { [string]: any }, KindName: string)
    const Model: Model? = Context.model()
    const Build: ToolBuild? = Context.build()
    const Character = Players.LocalPlayer.Character
    const Kind = Flight.Kinds[KindName]
    if not Model or not Build or not Character or not Kind then
        return
    end
    const Slot: string = Context.Slot
    const Bounds = Flight.bounds(Model)
    const Origin = Model:GetPivot():PointToWorldSpace(Bounds.Center)
    const Skip: { Instance } = { Character, Flight.folder() }
    const Range = Stats.ThrowRange or Throwables.Range
    const Target = aim(Origin, Range, Skip)
    const Velocity = Flight.plan(Kind, Origin, Target, Stats.ThrowSpeed or Kind.Speed)
    const Time, Drop, Rest = Flight.solve(KindName, Origin, Velocity, Flight.tip(Model, Bounds), Bounds, Skip, Stats.Embed or Throwables.Embed, Stats.StickSquare or Throwables.StickSquare)
    Out[Slot] = true
    Flight.launch({
        Thrower = Players.LocalPlayer,
        Slot = Slot,
        Build = Build,
        Kind = KindName,
        Origin = Origin,
        Velocity = Velocity,
        Time = Time,
        Drop = Drop,
        Rest = Rest,
    }, os.clock())
    Flight.conceal(Model, true)
    Context.popSet("Held")
    labels(Context)
    task.spawn(function()
        const Reply = Net:Call("@Throw/Toss", Context.Hand, {
            Kind = KindName,
            Origin = Origin,
            Velocity = Velocity,
            Time = Time,
            Drop = Drop,
            Rest = Rest,
        })
        if type(Reply) == "table" and Reply.Ok then
            return
        end
        Out[Slot] = nil
        Flight.remove(Players.LocalPlayer, Slot)
        Flight.conceal(Model, false)
        if Context.Data.Live then
            Context.pushSet("Held")
            labels(Context)
        end
        toast(if type(Reply) == "table" and type(Reply.Error) == "string" then Reply.Error else "That throw did not go through")
    end)
end

function Throwables.swing(Context: any): boolean
    if Context.Data.Throwing or Context.Data.Swinging or Out[Context.Slot] then
        return false
    end
    const Stats: { [string]: any } = Context.stats()
    Context.Data.Swinging = true
    Context.play("Swing", { Whole = Context.Pair == nil })
    Context.send("Swing")
    task.delay(Stats.SwingTime or Throwables.SwingTime, function()
        Context.Data.Swinging = false
    end)
    return true
end

function Throwables.throw(Context: any)
    if Context.Data.Throwing or Context.Data.Swinging or Out[Context.Slot] then
        return
    end
    const Stats: { [string]: any } = Context.stats()
    const KindName = Stats.Throw
    if type(KindName) ~= "string" or not Flight.Kinds[KindName] then
        return
    end
    const Now = os.clock()
    if Now - (Context.Data.LastThrow or 0) < (Stats.ThrowCooldown or Throwables.Cooldown) then
        return
    end
    Context.Data.LastThrow = Now
    Context.Data.Throwing = true
    Context.play("Throw", { Whole = Context.Pair == nil })
    task.delay(Stats.ReleaseTime or Throwables.ReleaseTime, function()
        Context.Data.Throwing = false
        if Context.Data.Live and not Out[Context.Slot] then
            release(Context, Stats, KindName)
        end
    end)
end

function Throwables.retrieve(Slot: string)
    if not Out[Slot] then
        return
    end
    task.spawn(function()
        const Reply = Net:Call("@Throw/Retrieve", Slot)
        if type(Reply) == "table" and not Reply.Ok and type(Reply.Error) == "string" then
            toast(Reply.Error)
        end
    end)
end

function Throwables.client(): { [string]: any }
    return {
        onEquip = function(Context: any)
            Live[Context.Slot] = Context
            if not Out[Context.Slot] then
                Context.pushSet("Held")
            end
            labels(Context)
        end,
        onUnequip = function(Context: any)
            if Live[Context.Slot] == Context then
                Live[Context.Slot] = nil
            end
            Context.popSet("Held")
        end,
        onActivate = function(Context: any): boolean
            return Throwables.swing(Context)
        end,
        onAction = function(Context: any, Id: string)
            if Id == "Throw" then
                Throwables.throw(Context)
            elseif Id == "Retrieve" then
                Throwables.retrieve(Context.Slot)
            end
        end,
    }
end

const function playerOf(Value: unknown): Player?
    if typeof(Value) == "Instance" and Value:IsA("Player") then
        return Value
    end
    return nil
end

const function read(Data: any): Flight.Throw?
    if type(Data) ~= "table" or type(Data.Slot) ~= "string" or type(Data.Kind) ~= "string" or type(Data.Build) ~= "table" then
        return nil
    end
    if typeof(Data.Origin) ~= "Vector3" or typeof(Data.Velocity) ~= "Vector3" or type(Data.Time) ~= "number" then
        return nil
    end
    return {
        Thrower = playerOf(Data.Thrower),
        Slot = Data.Slot,
        Build = Data.Build,
        Kind = Data.Kind,
        Origin = Data.Origin,
        Velocity = Data.Velocity,
        Time = Data.Time,
        Drop = if type(Data.Drop) == "number" then Data.Drop else nil,
        Rest = if typeof(Data.Rest) == "CFrame" then Data.Rest else nil,
    }
end

const function returned(Slot: string)
    Out[Slot] = nil
    const Context = Live[Slot]
    if not Context or not Context.Data.Live then
        return
    end
    const Model: Model? = Context.model()
    if Model then
        Flight.conceal(Model, false)
    end
    Context.pushSet("Held")
    if Context.Def.Equip then
        Context.play(Context.Def.Equip)
    end
    labels(Context)
end

function Throwables.start()
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    Flight.start()
    Net:On("@Throw/Thrown", function(Data: any)
        const Throw = read(Data)
        if Throw and Throw.Thrower ~= Players.LocalPlayer then
            Flight.launch(Throw, os.clock())
        end
    end)
    Net:On("@Throw/Gone", function(Thrower: Player?, Slot: string)
        if type(Slot) ~= "string" then
            return
        end
        Flight.remove(Thrower, Slot)
        if Thrower == Players.LocalPlayer then
            returned(Slot)
        end
    end)
    Players.PlayerRemoving:Connect(Flight.clear)
    task.spawn(function()
        const List = Net:Call("@Throw/List")
        if type(List) ~= "table" then
            return
        end
        for _, Data in List do
            const Throw = read(Data)
            if Throw and Throw.Rest then
                if Throw.Thrower == Players.LocalPlayer then
                    Out[Throw.Slot] = true
                end
                Flight.launch(Throw, -math.huge)
            end
        end
    end)
end

return Throwables
