--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Workspace = game:GetService("Workspace")

const ReplicationPP = require(ReplicatedStorage.MainPackages.ReplicationPP)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)

type Held = {
    Model: Instance,
    ExpiresAt: number,
    Uses: number,
}

type Reply = {
    Accepted: { number }?,
    Limited: { number }?,
    Unknown: { number }?,
    RetryIn: number?,
}

const Cache = {
    Lifetime = 60,
    BatchSize = 40,
    SweepInterval = 1,
    StaleAfter = 15,
    Home = Vector3.new(16000, 60, 16000),
}

const Entries: { [number]: Held } = {}
const Pending: { [number]: number } = {}
const Rejected: { [number]: boolean } = {}
const Waiters: { [number]: { (Instance?) -> () } } = {}
local Holder: Folder? = nil
local Arrivals: { Disconnect: (any) -> () }? = nil
local Sweeper: thread? = nil

const function home(): CFrame
    return CFrame.new(Cache.Home.X, Workspace.FallenPartsDestroyHeight + Cache.Home.Y, Cache.Home.Z)
end

const function folder(): Folder
    const Existing = Holder
    if Existing and Existing.Parent then
        return Existing
    end
    const Made = Instance.new("Folder")
    Made.Name = "PropCache"
    Made.Parent = Workspace
    Holder = Made
    return Made
end

const function partsOf(Model: Instance): { BasePart }
    const Parts: { BasePart } = {}
    if Model:IsA("BasePart") then
        table.insert(Parts, Model)
    end
    for _, Item in Model:GetDescendants() do
        if Item:IsA("BasePart") then
            table.insert(Parts, Item)
        end
    end
    return Parts
end

const function bake(Model: Instance)
    for _, Part in partsOf(Model) do
        if Part:GetAttribute("PropCanCollide") == nil then
            Part:SetAttribute("PropCanCollide", Part.CanCollide)
            Part:SetAttribute("PropCanTouch", Part.CanTouch)
            Part:SetAttribute("PropCanQuery", Part.CanQuery)
        end
        Part.Anchored = true
        Part.CanCollide = false
        Part.CanTouch = false
        Part.CanQuery = false
    end
    if Model:IsA("PVInstance") then
        Model:PivotTo(home())
    end
    Model.Parent = folder()
end

const function wake(Id: number, Value: Instance?)
    const List = Waiters[Id]
    if not List then
        return
    end
    Waiters[Id] = nil
    for _, Settle in List do
        Settle(Value)
    end
end

const function drop(Id: number, Entry: Held)
    if Entries[Id] == Entry then
        Entries[Id] = nil
    end
    Entry.Model:Destroy()
end

const function accept(Asset: Instance, Id: number)
    Pending[Id] = nil
    if Entries[Id] then
        wake(Id, Entries[Id].Model)
        return
    end

    bake(Asset)
    const Entry: Held = {
        Model = Asset,
        ExpiresAt = os.clock() + Cache.Lifetime,
        Uses = 0,
    }
    Entries[Id] = Entry
    Asset.Destroying:Once(function()
        if Entries[Id] == Entry then
            Entries[Id] = nil
        end
    end)
    wake(Id, Asset)
end

const function sweep()
    const Now = os.clock()
    for Id, Entry in Entries do
        if Entry.Uses <= 0 and Now >= Entry.ExpiresAt then
            drop(Id, Entry)
        end
    end
end

const function start()
    if Arrivals then
        return
    end
    NetWatch.PropPlacer:Init()
    Arrivals = ReplicationPP.OnReplication:Connect(function(Asset: Instance)
        const Id = tonumber(Asset.Name)
        if Id and Pending[Id] then
            accept(Asset, Id)
        end
    end)
    Sweeper = task.spawn(function()
        while true do
            task.wait(Cache.SweepInterval)
            sweep()
        end
    end)
end

local send: (Batch: { number }) -> ()

const function retry(Ids: { number }, Delay: number)
    task.delay(Delay, function()
        const Again: { number } = {}
        for _, Id in Ids do
            if Pending[Id] and not Entries[Id] then
                table.insert(Again, Id)
            end
        end
        if #Again > 0 then
            send(Again)
        end
    end)
end

send = function(Batch: { number })
    const Answer = NetWatch.PropPlacer:Call("@Props/Request", Batch) :: Reply?
    if type(Answer) ~= "table" then
        for _, Id in Batch do
            if not Entries[Id] then
                Pending[Id] = nil
                wake(Id, nil)
            end
        end
        return
    end

    for _, Id in Answer.Unknown or {} do
        Pending[Id] = nil
        Rejected[Id] = true
        wake(Id, nil)
    end

    const Limited = Answer.Limited or {}
    if #Limited > 0 then
        retry(Limited, math.max(Answer.RetryIn or 1, 0.25))
    end
end

const function touch(Entry: Held)
    Entry.ExpiresAt = math.max(Entry.ExpiresAt, os.clock() + Cache.Lifetime)
end

const function await(Id: number, Seconds: number): Instance?
    const Thread = coroutine.running()
    local Settled = false
    const function settle(Value: Instance?)
        if Settled then
            return
        end
        Settled = true
        task.spawn(Thread, Value)
    end

    const List = Waiters[Id] or {}
    Waiters[Id] = List
    table.insert(List, settle)
    const Timer = task.delay(Seconds, settle, nil)

    const Value = coroutine.yield() :: Instance?
    if coroutine.status(Timer) == "suspended" then
        task.cancel(Timer)
    end
    const Current = Waiters[Id]
    if Current then
        const At = table.find(Current, settle)
        if At then
            table.remove(Current, At)
        end
        if #Current == 0 then
            Waiters[Id] = nil
        end
    end
    return Value
end

function Cache.request(Ids: { number })
    start()
    const Now = os.clock()
    const Missing: { number } = {}
    for _, Id in Ids do
        const Entry = Entries[Id]
        if Entry then
            touch(Entry)
            continue
        end
        if Rejected[Id] then
            continue
        end
        const Since = Pending[Id]
        if Since and Now - Since < Cache.StaleAfter then
            continue
        end
        Pending[Id] = Now
        const Arrived = ReplicationPP.GetAsset(tostring(Id))
        if Arrived then
            accept(Arrived, Id)
        else
            table.insert(Missing, Id)
        end
    end

    for First = 1, #Missing, Cache.BatchSize do
        const Batch = table.move(Missing, First, math.min(First + Cache.BatchSize - 1, #Missing), 1, {})
        task.spawn(send, Batch)
    end
end

function Cache.fetch(Ids: { number }, Timeout: number?): { [number]: Instance }
    Cache.request(Ids)
    const Deadline = os.clock() + (Timeout or 5)
    const Found: { [number]: Instance } = {}
    for _, Id in Ids do
        local Entry = Entries[Id]
        while not Entry and Pending[Id] and os.clock() < Deadline do
            await(Id, Deadline - os.clock())
            Entry = Entries[Id]
        end
        if Entry then
            touch(Entry)
            Found[Id] = Entry.Model
        end
    end
    return Found
end

function Cache.get(Id: number): Instance?
    const Entry = Entries[Id]
    if not Entry then
        return nil
    end
    touch(Entry)
    return Entry.Model
end

function Cache.restore(Root: Instance)
    for _, Part in partsOf(Root) do
        const Collide = Part:GetAttribute("PropCanCollide")
        const Touch = Part:GetAttribute("PropCanTouch")
        const Query = Part:GetAttribute("PropCanQuery")
        if type(Collide) == "boolean" then
            Part.CanCollide = Collide
        end
        if type(Touch) == "boolean" then
            Part.CanTouch = Touch
        end
        if type(Query) == "boolean" then
            Part.CanQuery = Query
        end
    end
end

function Cache.spawn(Id: number): Model?
    const Source = Cache.get(Id)
    const Copy = if Source then Source:Clone() else nil
    if not Copy then
        return nil
    end
    Cache.restore(Copy)
    if Copy:IsA("Model") then
        return Copy
    end
    const Holder = Instance.new("Model")
    Holder.Name = Copy.Name
    if Copy:IsA("PVInstance") then
        Holder.WorldPivot = Copy:GetPivot()
    end
    Copy.Parent = Holder
    return Holder
end

function Cache.has(Id: number): boolean
    return Entries[Id] ~= nil
end

function Cache.use(Id: number): () -> ()
    const Entry = Entries[Id]
    if not Entry then
        return function() end
    end
    Entry.Uses += 1
    local Released = false
    return function()
        if Released then
            return
        end
        Released = true
        Entry.Uses -= 1
        if Entry.Uses <= 0 and os.clock() >= Entry.ExpiresAt then
            drop(Id, Entry)
        end
    end
end

function Cache.clear()
    for Id, Entry in Entries do
        drop(Id, Entry)
    end
    table.clear(Pending)
    table.clear(Rejected)
    for Id in Waiters do
        wake(Id, nil)
    end
end

function Cache.stop()
    const Connection = Arrivals
    Arrivals = nil
    if Connection then
        Connection:Disconnect()
    end
    const Loop = Sweeper
    Sweeper = nil
    if Loop then
        task.cancel(Loop)
    end
    Cache.clear()
end

return Cache
