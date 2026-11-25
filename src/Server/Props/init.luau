--!strict
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const ServerStorage = game:GetService("ServerStorage")
const TextService = game:GetService("TextService")
const Workspace = game:GetService("Workspace")

const ReplicationPP = require(ReplicatedStorage.MainPackages.ReplicationPP)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const PropData = require(ReplicatedStorage.Shared.PropData)
const Codec = require(ReplicatedStorage.Shared.PropData.Codec)
const Config = require(ReplicatedStorage.Shared.PropData.Config)
const SaveFormat = require(ReplicatedStorage.Shared.PropData.SaveFormat)
const Zones = require(script.Zones)
const Boxes = require(script.Boxes)

export type Reply = {
    Accepted: { number },
    Limited: { number },
    Unknown: { number },
    RetryIn: number,
}

export type Result = {
    Ok: boolean,
    Error: string?,
    Keys: { string }?,
    Save: PropSave?,
}

export type Stats = {
    Count: number,
    Max: number,
    Packs: { [string]: boolean },
    AllPacks: boolean,
    CanBuild: boolean,
    PerId: { [string]: number },
}

type Bucket = {
    Tokens: number,
    Stamp: number,
}

type Owner = {
    Player: Player,
    Data: PlayerData,
    Records: { [string]: Zones.Record },
    Count: number,
    PerId: { [number]: number },
    Stamps: { [string]: number },
}

const Props = {
    BucketSize = 60,
    RefillRate = 20,
    MaxBatch = 40,
}

const Net = NetWatch.PropPlacer
const Buckets: { [Player]: Bucket } = {}
const Budgets: { [Player]: Bucket } = {}
const Owners: { [Player]: Owner } = {}
const Sources: { [number]: Instance } = {}
local SourceFolder: Folder? = nil
local Started = false

const function resolve(Path: string): Instance?
    local Current: Instance = ServerStorage
    for Part in string.gmatch(Path, "[^/]+") do
        const Next = Current:FindFirstChild(Part)
        if not Next then
            return nil
        end
        Current = Next
    end
    return Current
end

function Props.model(Id: number): Instance?
    const Path = PropData.path(Id)
    return if Path then resolve(Path) else nil
end

const function sourceOf(Id: number): Instance?
    const Existing = Sources[Id]
    if Existing and Existing.Parent then
        return Existing
    end
    const Model = Props.model(Id)
    if not Model then
        return nil
    end

    local Folder = SourceFolder
    if not Folder or not Folder.Parent then
        const Made = Instance.new("Folder")
        Made.Name = "PropSources"
        Made.Parent = ServerStorage
        SourceFolder = Made
        Folder = Made
    end

    const Copy = Model:Clone()
    if not Copy then
        warn(`[Props] prop {Id} could not be cloned, make sure its model is Archivable`)
        return nil
    end
    Copy.Name = tostring(Id)
    Copy.Parent = Folder
    Sources[Id] = Copy
    return Copy
end

const function take(Player: Player, Wanted: number): number
    const Now = os.clock()
    local Held = Buckets[Player]
    if not Held then
        Held = { Tokens = Props.BucketSize, Stamp = Now }
        Buckets[Player] = Held
    end
    Held.Tokens = math.min(Props.BucketSize, Held.Tokens + (Now - Held.Stamp) * Props.RefillRate)
    Held.Stamp = Now
    const Granted = math.clamp(math.floor(Held.Tokens), 0, Wanted)
    Held.Tokens -= Granted
    return Granted
end

const function request(Player: Player, Ids: unknown): Reply
    const Answer: Reply = {
        Accepted = {},
        Limited = {},
        Unknown = {},
        RetryIn = 0,
    }
    if type(Ids) ~= "table" then
        return Answer
    end

    const Seen: { [number]: boolean } = {}
    const Fresh: { number } = {}
    local Looked = 0
    for _, Id in Ids :: { [any]: any } do
        Looked += 1
        if Looked > Props.MaxBatch * 2 or #Fresh + #Answer.Accepted >= Props.MaxBatch then
            break
        end
        if type(Id) ~= "number" or Id ~= math.floor(Id) or Seen[Id] then
            continue
        end
        Seen[Id] = true

        const Source = if PropData.get(Id) then sourceOf(Id) else nil
        if not Source then
            table.insert(Answer.Unknown, Id)
        elseif ReplicationPP.IsReplicated(Player, Source) or ReplicationPP.IsPending(Player, Source) then
            table.insert(Answer.Accepted, Id)
        else
            table.insert(Fresh, Id)
        end
    end

    const Granted = take(Player, #Fresh)
    for Position, Id in Fresh do
        if Position <= Granted then
            ReplicationPP.ReplicateAsset(Player, Sources[Id])
            table.insert(Answer.Accepted, Id)
        else
            table.insert(Answer.Limited, Id)
        end
    end

    if #Answer.Limited > 0 then
        Answer.RetryIn = math.max(#Answer.Limited / Props.RefillRate, 0.25)
    end
    return Answer
end

const function fail(Message: string): Result
    return { Ok = false, Error = Message }
end

const function allPacks(): boolean
    return Config.StudioOwnsAll and RunService:IsStudio()
end

const function owns(Owner: Owner, Pack: string?): boolean
    if Pack == nil or Config.FreePacks[Pack] or Owner.Data.OwnedPacks[Pack] == true then
        return true
    end
    return allPacks()
end

const function canBuild(Owner: Owner): boolean
    return Config.DefaultBuild or Owner.Data.BuildTool == true or RunService:IsStudio()
end

const function maxOf(Owner: Owner): number
    const Count = Owner.Data.PropCount
    return if type(Count) == "number" then Count else Config.MaxProps
end

const function perIdOf(Owner: Owner): { [string]: number }
    const Made: { [string]: number } = {}
    for Id, Count in Owner.PerId do
        if Count > 0 then
            Made[tostring(Id)] = Count
        end
    end
    return Made
end

const function statsOf(Owner: Owner): Stats
    const Packs: { [string]: boolean } = table.clone(Config.FreePacks)
    for Pack, Owned in Owner.Data.OwnedPacks do
        if Owned == true then
            Packs[Pack] = true
        end
    end
    return {
        Count = Owner.Count,
        Max = maxOf(Owner),
        Packs = Packs,
        AllPacks = allPacks(),
        CanBuild = canBuild(Owner),
        PerId = perIdOf(Owner),
    }
end

const function pushStats(Owner: Owner)
    Net:BroadcastTo(Owner.Player, "@Props/Stats", statsOf(Owner))
end

const function cooled(Owner: Owner, Action: string): boolean
    const Now = os.clock()
    const Last = Owner.Stamps[Action]
    if Last and Now - Last < Config.ActionCooldown then
        return false
    end
    Owner.Stamps[Action] = Now
    return true
end

const function spend(Player: Player): boolean
    const Now = os.clock()
    local Held = Budgets[Player]
    if not Held then
        Held = { Tokens = Config.StateBurst, Stamp = Now }
        Budgets[Player] = Held
    end
    Held.Tokens = math.min(Config.StateBurst, Held.Tokens + (Now - Held.Stamp) * Config.StateRate)
    Held.Stamp = Now
    if Held.Tokens < 1 then
        return false
    end
    Held.Tokens -= 1
    return true
end

const function rootOf(Player: Player): Vector3?
    const Character = Player.Character
    const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    return if Root and Root:IsA("BasePart") then Root.Position else nil
end

const function validPivot(Value: unknown): boolean
    return typeof(Value) == "CFrame"
        and Codec.finite(Value)
        and (Value :: CFrame).Y > Workspace.FallenPartsDestroyHeight
end

const function validScale(Value: unknown, Id: number): boolean
    if type(Value) ~= "number" or not Codec.finite(Value) then
        return false
    end
    const Min, Max = PropData.scaleRange(Id)
    return Value >= Min - 1e-4 and Value <= Max + 1e-4
end

const function scaleProblem(Id: number, Name: string): string
    const Min, Max = PropData.scaleRange(Id)
    return `{Name} can only be scaled from {Min}x to {Max}x`
end

const function builder(Player: Player): (Owner?, string?)
    const Owner = Owners[Player]
    if not Owner then
        return nil, "Your data is still loading"
    end
    if not canBuild(Owner) then
        return nil, "You do not have the build tool"
    end
    return Owner, nil
end

const function place(Player: Player, Given: any, Trusted: boolean): Result
    const Owner, Problem = builder(Player)
    if not Owner then
        return fail(Problem or "You can not build right now")
    end
    if not Trusted and not cooled(Owner, "Place") then
        return fail("Slow down a little")
    end
    if type(Given) ~= "table" or #Given == 0 then
        return fail("There is nothing to place")
    end
    if #Given > Config.MaxBatch then
        return fail("That is too many props at once")
    end
    const Origin = if Trusted then nil else rootOf(Player)
    if not Trusted and not Origin then
        return fail("You need to be spawned in to place props")
    end
    const Max = maxOf(Owner)
    if Owner.Count + #Given > Max then
        return fail(`You have reached your prop limit ({Owner.Count}/{Max})`)
    end

    const Adding: { [number]: number } = {}
    const Made: { Zones.Record } = {}
    const Now = Workspace:GetServerTimeNow()
    for _, Entry in Given do
        if type(Entry) ~= "table" then
            return fail("That placement is not valid")
        end
        const Id = Entry.Id
        const Info = if type(Id) == "number" then PropData.get(Id) else nil
        if not Info then
            return fail("That prop does not exist")
        end
        if not owns(Owner, Info.Pack) then
            return fail(`You do not own the {Info.Pack} pack`)
        end
        if not validPivot(Entry.Pivot) then
            return fail(`{Info.Name} is not in a valid spot`)
        end
        if not validScale(Entry.Scale, Info.Id) then
            return fail(scaleProblem(Info.Id, Info.Name))
        end
        const Pivot = Entry.Pivot :: CFrame
        if Origin and (Pivot.Position - Origin).Magnitude > Config.MaxReach then
            return fail(`{Info.Name} is too far away from you`)
        end
        Adding[Info.Id] = (Adding[Info.Id] or 0) + 1
        const Limit = Info.Limit
        if Limit and (Owner.PerId[Info.Id] or 0) + Adding[Info.Id] > Limit then
            return fail(`You can only place {Limit} of {Info.Name}`)
        end
        table.insert(Made, {
            Key = HttpService:GenerateGUID(false),
            Id = Info.Id,
            Owner = Player.UserId,
            Pivot = Pivot,
            Scale = Entry.Scale :: number,
            States = PropData.clean(Info.Id, Entry.States, Player),
            Stamp = Now,
            Changed = Now,
            By = Player.UserId,
            Zone = "",
        })
    end

    const Keys: { string } = {}
    for _, Record in Made do
        Owner.Records[Record.Key] = Record
        Owner.PerId[Record.Id] = (Owner.PerId[Record.Id] or 0) + 1
        Owner.Count += 1
        table.insert(Keys, Record.Key)
    end
    Zones.add(Made)
    for _, Record in Made do
        Boxes.sync(Record)
    end
    pushStats(Owner)
    return { Ok = true, Keys = Keys }
end

const function move(Player: Player, Given: any): Result
    const Owner, Problem = builder(Player)
    if not Owner then
        return fail(Problem or "You can not build right now")
    end
    if not cooled(Owner, "Move") then
        return fail("Slow down a little")
    end
    if type(Given) ~= "table" or #Given == 0 or #Given > Config.MaxBatch then
        return fail("That move is not valid")
    end
    const Origin = rootOf(Player)
    if not Origin then
        return fail("You need to be spawned in to move props")
    end

    const Moves: { Zones.Move } = {}
    for _, Entry in Given do
        if type(Entry) ~= "table" or type(Entry.Key) ~= "string" then
            return fail("That move is not valid")
        end
        const Record = Owner.Records[Entry.Key]
        if not Record then
            return fail("You can only move your own props")
        end
        if not validPivot(Entry.Pivot) then
            return fail("A prop is not in a valid spot")
        end
        if not validScale(Entry.Scale, Record.Id) then
            const Info = PropData.get(Record.Id)
            return fail(scaleProblem(Record.Id, if Info then Info.Name else "That prop"))
        end
        const Pivot = Entry.Pivot :: CFrame
        if (Pivot.Position - Origin).Magnitude > Config.MaxReach then
            return fail("A prop is too far away from you")
        end
        table.insert(Moves, {
            Record = Record,
            Pivot = Pivot,
            Scale = Entry.Scale :: number,
            By = Player.UserId,
            Stamp = Workspace:GetServerTimeNow(),
        })
    end
    Zones.move(Moves)
    for _, Move in Moves do
        Boxes.sync(Move.Record)
    end
    return { Ok = true }
end

const function delete(Player: Player, Given: any): Result
    const Owner, Problem = builder(Player)
    if not Owner then
        return fail(Problem or "You can not build right now")
    end
    if not cooled(Owner, "Delete") then
        return fail("Slow down a little")
    end
    if type(Given) ~= "table" then
        return fail("That delete is not valid")
    end

    const Doomed: { Zones.Record } = {}
    for _, Key in Given do
        const Record = if type(Key) == "string" then Owner.Records[Key] else nil
        if Record then
            Owner.Records[Key] = nil
            Owner.PerId[Record.Id] = math.max((Owner.PerId[Record.Id] or 1) - 1, 0)
            Owner.Count -= 1
            table.insert(Doomed, Record)
        end
    end
    if #Doomed == 0 then
        return fail("Those props are already gone")
    end
    Zones.remove(Doomed)
    for _, Record in Doomed do
        Boxes.remove(Record.Key)
    end
    pushStats(Owner)
    return { Ok = true }
end

const function changeState(Player: Player, Key: unknown, Name: unknown, Value: unknown, Public: boolean)
    if type(Key) ~= "string" or type(Name) ~= "string" then
        return
    end
    const Record = Zones.record(Key)
    if not Record then
        return
    end

    local Allowed = spend(Player)
    if Allowed then
        Allowed = if Public
            then PropData.isPublic(Record.Id, Name) and Zones.isMember(Player, Record.Zone)
            else Record.Owner == Player.UserId
    end
    Allowed = Allowed and PropData.accepts(Record.Id, Name, Value, Player)

    if not Allowed then
        const Current = Record.States[Name]
        if Current ~= nil then
            Net:BroadcastTo(Player, "@Props/Correct", Key, Name, Current)
        end
        return
    end
    if Record.States[Name] == Value then
        return
    end
    Record.States[Name] = Value
    Record.Changed = Workspace:GetServerTimeNow()
    Record.By = Player.UserId
    Zones.state(Record, Name, Value)
end

const function saveName(Player: Player, Given: unknown, Fallback: string): string
    if type(Given) ~= "string" then
        return Fallback
    end
    const Plain = string.gsub(Given, "%c", "")
    const Trimmed = string.sub(string.match(Plain, "^%s*(.-)%s*$") or "", 1, Config.MaxSaveName)
    if Trimmed == "" then
        return Fallback
    end
    const Ok, Filtered = pcall(function()
        const Result = TextService:FilterStringAsync(Trimmed, Player.UserId)
        return Result:GetNonChatStringForUserAsync(Player.UserId)
    end)
    return if Ok and type(Filtered) == "string" and Filtered ~= "" then Filtered else Fallback
end

const function renameSlot(Player: Player, Slot: unknown, Given: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const Name = SaveFormat.slot(Slot)
    const Save = if Name then Owner.Data.PropSaves[Name] else nil
    if not Name or not Save then
        return fail("That save slot is empty")
    end
    Save.Name = saveName(Player, Given, Save.Name)
    return { Ok = true, Save = Save }
end

const function saveSlot(Player: Player, Slot: unknown, Keys: unknown, Given: unknown): Result
    const Owner, Problem = builder(Player)
    if not Owner then
        return fail(Problem or "You can not build right now")
    end
    if not cooled(Owner, "Save") then
        return fail("Slow down a little")
    end
    const Name = SaveFormat.slot(Slot)
    if not Name then
        return fail("That save slot does not exist")
    end
    const Chosen: { Zones.Record } = {}
    if type(Keys) == "table" then
        const Seen: { [string]: boolean } = {}
        for _, Key in Keys :: { any } do
            const Record = if type(Key) == "string" and not Seen[Key] then Owner.Records[Key] else nil
            if Record then
                Seen[Key] = true
                table.insert(Chosen, Record)
            end
        end
        if #Chosen == 0 then
            return fail("None of the selected props can be saved")
        end
    else
        for _, Record in Owner.Records do
            table.insert(Chosen, Record)
        end
        if #Chosen == 0 then
            return fail("You have no props placed to save")
        end
    end
    const Items: { SaveFormat.Item } = {}
    for _, Record in Chosen do
        table.insert(Items, {
            Id = Record.Id,
            Pivot = Record.Pivot,
            Scale = Record.Scale,
            States = Record.States,
        })
    end
    const Old = Owner.Data.PropSaves[Name]
    const Made = SaveFormat.capture(Items, Player, saveName(Player, Given, if Old then Old.Name else `Slot {Name}`))
    Owner.Data.PropSaves[Name] = Made
    return { Ok = true, Save = Made }
end

const function clearSlot(Player: Player, Slot: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const Name = SaveFormat.slot(Slot)
    if not Name then
        return fail("That save slot does not exist")
    end
    Owner.Data.PropSaves[Name] = nil
    return { Ok = true }
end

const function loadSpot(Player: Player, Slot: unknown): Result
    const Owner, Problem = builder(Player)
    if not Owner then
        return fail(Problem or "You can not build right now")
    end
    if not cooled(Owner, "Load") then
        return fail("Slow down a little")
    end
    const Name = SaveFormat.slot(Slot)
    const Save = if Name then Owner.Data.PropSaves[Name] else nil
    if not Save then
        return fail("That save slot is empty")
    end
    const Items = SaveFormat.items(Save, Player)
    if #Items == 0 then
        return fail("That save has nothing to load")
    end
    return place(Player, Items, true)
end

function Props.attach(Player: Player, Data: PlayerData)
    if Owners[Player] then
        return
    end
    if type(Data.PropCount) ~= "number" then
        Data.PropCount = Config.MaxProps
    end
    if type(Data.OwnedPacks) ~= "table" then
        Data.OwnedPacks = {}
    end
    if type(Data.PropSaves) ~= "table" then
        Data.PropSaves = {}
    end
    const Owner: Owner = {
        Player = Player,
        Data = Data,
        Records = {},
        Count = 0,
        PerId = {},
        Stamps = {},
    }
    Owners[Player] = Owner
    pushStats(Owner)
    Net:BroadcastTo(Player, "@Props/Saves", Data.PropSaves)
end

function Props.detach(Player: Player)
    const Owner = Owners[Player]
    Owners[Player] = nil
    Budgets[Player] = nil
    if Owner then
        const Items: { Zones.Record } = {}
        for _, Record in Owner.Records do
            table.insert(Items, Record)
        end
        table.clear(Owner.Records)
        if #Items > 0 then
            Zones.remove(Items)
        end
        for _, Record in Items do
            Boxes.remove(Record.Key)
        end
    end
    Zones.drop(Player)
end

function Props.setBuildTool(Player: Player, Owned: boolean)
    const Owner = Owners[Player]
    if not Owner then
        return
    end
    Owner.Data.BuildTool = Owned
    pushStats(Owner)
end

function Props.refresh(Player: Player)
    const Owner = Owners[Player]
    if Owner then
        pushStats(Owner)
    end
end

function Props.stats(Player: Player): Stats?
    const Owner = Owners[Player]
    return if Owner then statsOf(Owner) else nil
end

function Props.start()
    if Started then
        return
    end
    Started = true

    for _, Info in PropData.all() do
        if not Props.model(Info.Id) then
            warn(`[Props] prop {Info.Id} "{Info.Name}" has no model at ServerStorage/{PropData.path(Info.Id)}`)
        end
    end

    Net:When("@Props/Request", function(Player: Player, Ids: unknown)
        return request(Player, Ids)
    end)
    Net:When("@Props/Place", function(Player: Player, Items: unknown)
        return place(Player, Items, false)
    end)
    Net:When("@Props/Move", move)
    Net:When("@Props/Delete", delete)
    Net:When("@Props/Save", saveSlot)
    Net:When("@Props/Rename", renameSlot)
    Net:When("@Props/ClearSave", clearSlot)
    Net:When("@Props/LoadSpot", loadSpot)
    Net:When("@Props/Saves", function(Player: Player)
        const Owner = Owners[Player]
        return if Owner then Owner.Data.PropSaves else nil
    end)
    Net:When("@Props/Stats", function(Player: Player)
        return Props.stats(Player)
    end)
    Net:On("@Props/State", function(Player: Player, Key: unknown, Name: unknown, Value: unknown)
        changeState(Player, Key, Name, Value, false)
    end)
    Net:On("@Props/PublicState", function(Player: Player, Key: unknown, Name: unknown, Value: unknown)
        changeState(Player, Key, Name, Value, true)
    end)
    Net:On("@Props/Snapshot", function(Player: Player, Key: unknown)
        Zones.resend(Player, Key)
    end)
    Net:On("@Props/Forget", function(Player: Player, Key: unknown)
        Zones.forget(Player, Key)
    end)

    Players.PlayerRemoving:Connect(function(Player: Player)
        Buckets[Player] = nil
        Props.detach(Player)
    end)
    Zones.start()
    Boxes.start(Props.model)
end

return Props
