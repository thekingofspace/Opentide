--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Workspace = game:GetService("Workspace")

const signal = require(ReplicatedStorage.MainPackages.signal)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Config = require(ReplicatedStorage.Shared.PropData.Config)
const PropData = require(ReplicatedStorage.Shared.PropData)
const Cache = require(script.Parent.Cache)
const PropObject = require(script.Parent.PropObject)
const Sounds = require(ReplicatedStorage.Shared.Sounds)

export type Prop = PropObject.Prop

export type Stats = {
    Count: number,
    Max: number,
    Packs: { [string]: boolean },
    AllPacks: boolean,
    CanBuild: boolean,
    PerId: { [string]: number },
}

type ZoneCache = {
    Key: string,
    Version: string,
    Center: Vector3,
    Props: { [string]: Prop },
    Inside: boolean,
}

const World = {
    ForgetInterval = 1,
    Added = signal.new(),
    Removed = signal.new(),
    Stats = signal.new(),
}

const Net = NetWatch.PropPlacer
const Zones: { [string]: ZoneCache } = {}
const Props: { [string]: Prop } = {}
local Holder: Folder? = nil
local Latest: Stats? = nil
local Started = false

function World.folder(): Folder
    const Existing = Holder
    if Existing and Existing.Parent then
        return Existing
    end
    const Made = Instance.new("Folder")
    Made.Name = "PlacedProps"
    Made.Parent = Workspace
    Holder = Made
    return Made
end

const function valid(Record: any): boolean
    return type(Record) == "table"
        and type(Record.Key) == "string"
        and type(Record.Id) == "number"
        and type(Record.Owner) == "number"
        and typeof(Record.Pivot) == "CFrame"
        and type(Record.Scale) == "number"
        and type(Record.Stamp) == "number"
        and type(Record.Changed) == "number"
end

const function gap(Zone: ZoneCache, Position: Vector3): number
    const Half = Config.ZoneSize / 2
    const Outside = (Position - Zone.Center):Abs() - Vector3.new(Half, Half, Half)
    return Outside:Max(Vector3.zero).Magnitude
end

const function rootPosition(): Vector3?
    const Character = Players.LocalPlayer.Character
    const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    return if Root and Root:IsA("BasePart") then Root.Position else nil
end

const function remove(Prop: Prop)
    if Props[Prop.Key] == Prop then
        Props[Prop.Key] = nil
    end
    const Zone = Zones[Prop.Zone]
    if Zone and Zone.Props[Prop.Key] == Prop then
        Zone.Props[Prop.Key] = nil
    end
    World.Removed:Fire(Prop)
    PropObject.destroy(Prop)
end

const function adopt(Prop: Prop, Zone: ZoneCache)
    const Old = Zones[Prop.Zone]
    if Old and Old ~= Zone and Old.Props[Prop.Key] == Prop then
        Old.Props[Prop.Key] = nil
    end
    Prop.Zone = Zone.Key
    Zone.Props[Prop.Key] = Prop
end

const function update(Prop: Prop, Record: any)
    PropObject.applyTransform(Prop, Record.Pivot, Record.Scale)
    if type(Record.States) == "table" then
        for Name, Value in Record.States do
            if type(Name) == "string" then
                PropObject.applyState(Prop, Name, Value)
            end
        end
    end
    PropObject.touch(Prop, Record.Changed, Record.By)
end

const function add(Zone: ZoneCache, Record: any, Arrival: PropData.Arrival)
    const Existing = Props[Record.Key]
    if Existing then
        adopt(Existing, Zone)
        update(Existing, Record)
        return
    end
    Record.Zone = Zone.Key
    const Prop = PropObject.new(Record, Arrival, World.folder())
    Props[Prop.Key] = Prop
    adopt(Prop, Zone)
    World.Added:Fire(Prop)
end

const function drop(Zone: ZoneCache)
    if Zones[Zone.Key] == Zone then
        Zones[Zone.Key] = nil
    end
    for _, Prop in Zone.Props do
        remove(Prop)
    end
    table.clear(Zone.Props)
end

const function enter(Key: unknown, Version: unknown, Center: unknown, List: unknown)
    if type(Key) ~= "string" or type(Version) ~= "string" or typeof(Center) ~= "Vector3" then
        return
    end
    const Known = Zones[Key]
    if List == nil then
        if Known then
            Known.Inside = true
        end
        if not Known or Known.Version ~= Version then
            Net:Emit("@Props/Snapshot", Key)
        end
        return
    end
    if type(List) ~= "table" then
        return
    end

    local Zone = Known
    if not Zone then
        const Made: ZoneCache = {
            Key = Key,
            Version = Version,
            Center = Center,
            Props = {},
            Inside = true,
        }
        Zones[Key] = Made
        Zone = Made
    end
    Zone.Inside = true
    Zone.Version = Version

    const Ids: { number } = {}
    for _, Record in List :: { any } do
        if valid(Record) then
            table.insert(Ids, Record.Id)
        end
    end
    Cache.request(Ids)

    const Seen: { [string]: boolean } = {}
    for _, Record in List :: { any } do
        if valid(Record) then
            Seen[Record.Key] = true
            add(Zone, Record, "Entered")
        end
    end
    for PropKey, Prop in Zone.Props do
        if not Seen[PropKey] then
            remove(Prop)
        end
    end
end

const function apply(Zone: ZoneCache, Change: any)
    const Kind = Change.Kind
    if Kind == "Add" then
        const Record = Change.Prop
        if valid(Record) then
            Cache.request({ Record.Id })
            if Change.From == nil and not Props[Record.Key] then
                Sounds.playAt("PropPlaced", Record.Pivot.Position)
            end
            add(Zone, Record, if Change.From ~= nil and not Props[Record.Key] then "Entered" else "Placed")
        end
        return
    end

    const Prop = if type(Change.Key) == "string" then Props[Change.Key] else nil
    if not Prop then
        return
    end
    if Kind == "Move" then
        PropObject.touch(Prop, Change.Changed, Change.By)
        if typeof(Change.Pivot) == "CFrame" and type(Change.Scale) == "number" then
            Sounds.playAt("PropMoved", Change.Pivot.Position)
            PropObject.applyTransform(Prop, Change.Pivot, Change.Scale)
        end
    elseif Kind == "State" then
        PropObject.touch(Prop, Change.Changed, Change.By)
        if type(Change.Name) == "string" then
            PropObject.applyState(Prop, Change.Name, Change.Value, Change.Changed)
        end
    elseif Kind == "Remove" then
        Sounds.playAt("PropRemoved", Prop.Pivot.Position)
        remove(Prop)
    elseif Kind == "Transfer" then
        if Prop.Zone ~= Zone.Key then
            return
        end
        const Target = if type(Change.To) == "string" then Zones[Change.To] else nil
        if Target and Target.Inside then
            adopt(Prop, Target)
        else
            remove(Prop)
        end
    end
end

const function delta(Key: unknown, From: unknown, To: unknown, Changes: unknown)
    if type(Key) ~= "string" or type(To) ~= "string" or type(Changes) ~= "table" then
        return
    end
    const Zone = Zones[Key]
    if not Zone or Zone.Version ~= From then
        Net:Emit("@Props/Snapshot", Key)
        return
    end
    Zone.Version = To
    for _, Change in Changes :: { any } do
        if type(Change) == "table" then
            apply(Zone, Change)
        end
    end
end

const function forgetFar()
    const Position = rootPosition()
    if not Position then
        return
    end
    for Key, Zone in Zones do
        if not Zone.Inside and gap(Zone, Position) > Config.ForgetRange then
            drop(Zone)
            Net:Emit("@Props/Forget", Key)
        end
    end
end

function World.get(Key: string): Prop?
    return Props[Key]
end

function World.all(): { [string]: Prop }
    return Props
end

function World.stats(): Stats?
    return Latest
end

function World.await(Keys: { string }, Timeout: number): boolean
    const Deadline = os.clock() + Timeout
    while true do
        local Ready = true
        for _, Key in Keys do
            const Prop = Props[Key]
            if not Prop or not Prop.Mounted then
                Ready = false
                break
            end
        end
        if Ready then
            return true
        end
        if os.clock() >= Deadline then
            return false
        end
        task.wait()
    end
end

function World.start()
    if Started then
        return
    end
    Started = true

    Net:On("@Props/ZoneEnter", enter)
    Net:On("@Props/Delta", delta)
    Net:On("@Props/ZoneLeave", function(Key: unknown)
        const Zone = if type(Key) == "string" then Zones[Key] else nil
        if Zone then
            Zone.Inside = false
        end
    end)
    Net:On("@Props/ZoneGone", function(Key: unknown)
        const Zone = if type(Key) == "string" then Zones[Key] else nil
        if Zone then
            drop(Zone)
        end
    end)
    Net:On("@Props/Correct", function(Key: unknown, Name: unknown, Value: any)
        const Prop = if type(Key) == "string" then Props[Key] else nil
        if Prop and type(Name) == "string" then
            PropObject.applyState(Prop, Name, Value)
        end
    end)
    Net:On("@Props/Stats", function(Given: any)
        if type(Given) == "table" and type(Given.Count) == "number" and type(Given.Max) == "number" then
            const Made: Stats = {
                Count = Given.Count,
                Max = Given.Max,
                Packs = if type(Given.Packs) == "table" then Given.Packs :: { [string]: boolean } else {},
                AllPacks = Given.AllPacks == true,
                CanBuild = Given.CanBuild == true,
                PerId = if type(Given.PerId) == "table" then Given.PerId :: { [string]: number } else {},
            }
            Latest = Made
            World.Stats:Fire(Made)
        end
    end)

    RunService.Heartbeat:Connect(function(Delta: number)
        for _, Prop in Props do
            PropObject.idle(Prop, Delta)
        end
    end)

    task.spawn(function()
        while true do
            task.wait(World.ForgetInterval)
            forgetFar()
        end
    end)
end

return World
