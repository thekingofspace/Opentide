--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Workspace = game:GetService("Workspace")

const signal = require(ReplicatedStorage.MainPackages.signal)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const PropData = require(ReplicatedStorage.Shared.PropData)
const Cache = require(script.Parent.Cache)

export type Prop = PropData.Prop
export type Value = PropData.Value

export type Record = {
    Key: string,
    Id: number,
    Owner: number,
    Pivot: CFrame,
    Scale: number,
    States: { [string]: any }?,
    Stamp: number,
    Changed: number,
    By: number?,
    Zone: string,
}

type Internal = {
    Home: Instance,
    Clock: number,
}

const PropObject = {
    FetchTimeout = 10,
    Mounted = signal.new(),
    WidgetsChanged = signal.new(),
}

const Internals: { [Prop]: Internal } = {}

const function getState(Self: Prop, Name: string): Value?
    return Self.States[Name]
end

const function isOwner(Self: Prop): boolean
    return Self.Owner == Players.LocalPlayer.UserId
end

const function elapsed(Self: Prop): number
    return math.max(Workspace:GetServerTimeNow() - Self.Stamp, 0)
end

function PropObject.touch(Self: Prop, Changed: unknown, By: unknown)
    if type(Changed) == "number" then
        Self.Changed = Changed
    end
    if type(By) == "number" then
        Self.By = By
    end
end

function PropObject.applyState(Self: Prop, Name: string, Value: Value, Changed: number?)
    if type(Changed) == "number" then
        Self.Changed = Changed
    end
    const Old = Self.States[Name]
    if Old == Value then
        return
    end
    Self.States[Name] = Value
    if not Self.Mounted then
        return
    end
    Self.StateChanged:Fire(Name, Value, Old)
    const Found = PropData.definition(Self.Id)
    const Hook = if Found then Found.onState else nil
    if Hook then
        task.spawn(Hook, Self, Name, Value, Old)
    end
end

const function send(Self: Prop, Name: string, Value: Value, Public: boolean): boolean
    if Self.Destroyed then
        return false
    end
    if not PropData.accepts(Self.Id, Name, Value, Players.LocalPlayer) then
        warn(`[PropObject] "{Name}" is not a valid state value for prop {Self.Id}`)
        return false
    end
    PropObject.applyState(Self, Name, Value)
    NetWatch.PropPlacer:Emit(if Public then "@Props/PublicState" else "@Props/State", Self.Key, Name, Value)
    return true
end

const function setState(Self: Prop, Name: string, Value: Value): boolean
    if not isOwner(Self) then
        warn(`[PropObject] only the owner can set "{Name}", use setPublicState for states marked Public`)
        return false
    end
    return send(Self, Name, Value, false)
end

const function setPublicState(Self: Prop, Name: string, Value: Value): boolean
    if not PropData.isPublic(Self.Id, Name) then
        warn(`[PropObject] "{Name}" is not marked Public on prop {Self.Id}`)
        return false
    end
    return send(Self, Name, Value, true)
end

const function enableWidgets(Self: Prop, Enabled: boolean?)
    const Next = Enabled ~= false
    if Self.Destroyed or Self.WidgetsEnabled == Next then
        return
    end
    Self.WidgetsEnabled = Next
    PropObject.WidgetsChanged:Fire(Self)
end

const function enableInfo(Self: Prop, Enabled: boolean?)
    const Next = Enabled ~= false
    if Self.Destroyed or Self.InfoEnabled == Next then
        return
    end
    Self.InfoEnabled = Next
    PropObject.WidgetsChanged:Fire(Self)
end

const function settle(Self: Prop)
    const Model = Self.Model
    const Inner = Internals[Self]
    if not Model then
        return
    end
    Model.Parent = if Self.Hidden or not Inner then nil else Inner.Home
end

const function transform(Self: Prop)
    const Model = Self.Model
    if not Model then
        return
    end
    if math.abs(Model:GetScale() - Self.Scale) > 1e-4 then
        Model:ScaleTo(Self.Scale)
    end
    Model:PivotTo(Self.Pivot)
    Self.RestBox, Self.RestSize = Model:GetBoundingBox()
end

const function mount(Self: Prop)
    const Source = Cache.fetch({ Self.Id }, PropObject.FetchTimeout)[Self.Id]
    if Self.Destroyed then
        return
    end
    const Model = if Source then Cache.spawn(Self.Id) else nil
    if not Model then
        warn(`[PropObject] prop {Self.Id} could not load its model`)
        return
    end
    const Info = PropData.get(Self.Id)
    Model.Name = if Info then Info.Name else tostring(Self.Id)
    Model:SetAttribute("PropKey", Self.Key)
    const Found = PropData.definition(Self.Id)
    if Found and Found.ServerBox then
        for _, Item in Model:GetDescendants() do
            if Item:IsA("BasePart") then
                Item.CanCollide = false
            end
        end
    end
    Self.Model = Model
    transform(Self)
    settle(Self)
    Self.Mounted = true

    if Self.Arrival == "Placed" then
        Self.Placed:Fire()
        const Hook = if Found then Found.onPlaced else nil
        if Hook then
            task.spawn(Hook, Self)
        end
    else
        const Since = elapsed(Self)
        Self.ZoneEntered:Fire(Since)
        const Hook = if Found then Found.onZoneEnter else nil
        if Hook then
            task.spawn(Hook, Self, Since)
        end
    end
    PropObject.Mounted:Fire(Self)
end

function PropObject.new(Record: Record, Arrival: PropData.Arrival, Home: Instance): Prop
    const States = PropData.defaults(Record.Id)
    if type(Record.States) == "table" then
        for Name, Value in Record.States do
            if type(Name) == "string" then
                States[Name] = Value
            end
        end
    end

    const Found = PropData.definition(Record.Id)
    const Self: Prop = {
        Key = Record.Key,
        Id = Record.Id,
        Owner = Record.Owner,
        Zone = Record.Zone,
        Pivot = Record.Pivot,
        Scale = Record.Scale,
        States = States,
        Data = {},
        Stamp = Record.Stamp,
        Changed = Record.Changed,
        By = if type(Record.By) == "number" then Record.By else Record.Owner,
        RestBox = Record.Pivot,
        RestSize = Vector3.zero,
        Arrival = Arrival,
        Model = nil,
        Mounted = false,
        Hidden = false,
        Destroyed = false,
        WidgetsEnabled = false,
        InfoEnabled = not Found or Found.Info ~= false,
        Placed = signal.new(),
        ZoneEntered = signal.new(),
        StateChanged = signal.new(),
        Moved = signal.new(),
        Removed = signal.new(),
        WidgetSaved = signal.new(),
        WidgetPressed = signal.new(),
        getState = getState,
        setState = setState,
        setPublicState = setPublicState,
        isOwner = isOwner,
        elapsed = elapsed,
        enableWidgets = enableWidgets,
        enableInfo = enableInfo,
    }
    Internals[Self] = {
        Home = Home,
        Clock = 0,
    }
    task.spawn(mount, Self)
    return Self
end

function PropObject.applyTransform(Self: Prop, Pivot: CFrame, Scale: number)
    if Self.Pivot == Pivot and Self.Scale == Scale then
        return
    end
    Self.Pivot = Pivot
    Self.Scale = Scale
    if not Self.Mounted then
        return
    end
    transform(Self)
    Self.Moved:Fire(Pivot, Scale)
    const Found = PropData.definition(Self.Id)
    const Hook = if Found then Found.onMoved else nil
    if Hook then
        task.spawn(Hook, Self, Pivot, Scale)
    end
end

function PropObject.setHome(Self: Prop, Home: Instance)
    const Inner = Internals[Self]
    if not Inner then
        return
    end
    Inner.Home = Home
    settle(Self)
end

function PropObject.setHidden(Self: Prop, Hidden: boolean)
    if Self.Destroyed then
        return
    end
    Self.Hidden = Hidden
    settle(Self)
end

function PropObject.idle(Self: Prop, Delta: number)
    if not Self.Mounted then
        return
    end
    const Found = PropData.definition(Self.Id)
    const Hook = if Found then Found.onIdle else nil
    const Inner = Internals[Self]
    if not Hook or not Found or not Inner then
        return
    end
    Inner.Clock += Delta
    if Inner.Clock < (Found.IdleRate or 0) then
        return
    end
    const Spent = Inner.Clock
    Inner.Clock = 0
    const Ok, Problem = pcall(Hook, Self, Spent)
    if not Ok then
        warn(`[PropObject] idle failed for prop {Self.Id}: {Problem}`)
    end
end

function PropObject.destroy(Self: Prop)
    if Self.Destroyed then
        return
    end
    Self.Destroyed = true
    if Self.Mounted then
        Self.Removed:Fire()
        const Found = PropData.definition(Self.Id)
        const Hook = if Found then Found.onRemoved else nil
        if Hook then
            const Ok, Problem = pcall(Hook, Self)
            if not Ok then
                warn(`[PropObject] removed hook failed for prop {Self.Id}: {Problem}`)
            end
        end
    end
    Self.Mounted = false
    Internals[Self] = nil
    const Model = Self.Model
    Self.Model = nil
    if Model then
        Model:Destroy()
    end
    for _, Event in { Self.Placed, Self.ZoneEntered, Self.StateChanged, Self.Moved, Self.Removed, Self.WidgetSaved, Self.WidgetPressed } do
        Event:Destroy()
    end
    table.clear(Self.Data)
end

return PropObject
