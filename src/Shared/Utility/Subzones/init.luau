--!strict
const CollectionService = game:GetService("CollectionService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Workspace = game:GetService("Workspace")

const QuickZone = require(ReplicatedStorage.MainPackages.QuickZone)
const signal = require(ReplicatedStorage.MainPackages.signal)
const Sounds = require(ReplicatedStorage.Shared.Sounds)
const AmbientOverride = require(script.Parent.AmbientOverride)
const Weather = require(script.Parent.Weather)

export type Context = {
    Name: string,
    Elapsed: number,
    Data: { [any]: any },
    parts: () -> { BasePart },
}

export type Definition = {
    Priority: number?,
    TweenTime: number?,
    Weather: (string | boolean)?,
    Ambient: AmbientOverride.Look?,
    Sound: string?,
    Volume: number?,
    onEnter: ((Context: Context) -> ())?,
    onExit: ((Context: Context) -> ())?,
    onIdle: ((Context: Context, Delta: number) -> ())?,
}

export type Definitions = { [string]: Definition }

type Area = {
    Name: string,
    Observer: QuickZone.Observer<Player>,
    Parts: { [BasePart]: QuickZone.Zone },
    Inside: boolean,
    Order: number,
    Context: Context,
    Sound: Sound?,
    Level: number,
}

const Subzones = {
    Tag = "ZoneArea",
    Attribute = "Zone",
    TweenTime = 2,
    Hide = true,
    Entered = signal.new(),
    Exited = signal.new(),
}

const List: Definitions = {}
const Areas: { [string]: Area } = {}
const Registered: { [BasePart]: string } = {}
const Waiting: { [Instance]: RBXScriptConnection } = {}
local Loaded = false
local Started = false
local Counter = 0
local LocalGroup: QuickZone.Group<Player>? = nil
local Holder: Folder? = nil

function Subzones.add(Name: string, Definition: Definition): boolean
    if type(Name) ~= "string" or Name == "" or List[Name] then
        warn(`[Subzones] "{tostring(Name)}" is missing or defined more than once`)
        return false
    end
    if type(Definition) ~= "table" then
        warn(`[Subzones] "{Name}" must be a table`)
        return false
    end
    List[Name] = Definition
    return true
end

const function load()
    if Loaded then
        return
    end
    Loaded = true
    const Folder = script:FindFirstChild("Zones")
    if not Folder then
        return
    end
    const Modules: { ModuleScript } = {}
    for _, Item in Folder:GetDescendants() do
        if Item:IsA("ModuleScript") then
            table.insert(Modules, Item)
        end
    end
    table.sort(Modules, function(A: ModuleScript, B: ModuleScript): boolean
        return A:GetFullName() < B:GetFullName()
    end)
    for _, Module in Modules do
        const Ok, Result = pcall((require :: any), Module)
        if not Ok or type(Result) ~= "table" then
            warn(`[Subzones] {Module:GetFullName()} failed to load: {if Ok then "it must return a table" else Result}`)
            continue
        end
        for Name, Definition in Result do
            Subzones.add(Name, Definition)
        end
    end
end

function Subzones.get(Name: string): Definition?
    load()
    return List[Name]
end

function Subzones.list(): Definitions
    load()
    return List
end

function Subzones.inside(Name: string): boolean
    const Entry = Areas[Name]
    return Entry ~= nil and Entry.Inside
end

function Subzones.current(): { string }
    const Made: { string } = {}
    for Name, Entry in Areas do
        if Entry.Inside then
            table.insert(Made, Name)
        end
    end
    return Made
end

const function key(Name: string): string
    return `Subzone_{Name}`
end

const function fade(Definition: Definition?): number
    return math.max(if Definition and Definition.TweenTime then Definition.TweenTime else Subzones.TweenTime, 0)
end

const function hook(Name: string, Label: string, Run: any, ...: any)
    if not Run then
        return
    end
    const Ok, Problem = pcall(Run, ...)
    if not Ok then
        warn(`[Subzones] {Name} {Label} failed: {Problem}`)
    end
end

const function enter(Name: string)
    const Entry = Areas[Name]
    if not Entry or Entry.Inside then
        return
    end
    Counter += 1
    Entry.Inside = true
    Entry.Order = Counter
    Entry.Context.Elapsed = 0
    const Definition = List[Name]
    if Definition then
        const Time = fade(Definition)
        const Ambient = Definition.Ambient
        if Ambient then
            AmbientOverride.push(key(Name), Ambient, { TweenTime = Time, Priority = Definition.Priority })
        end
        const Kind = Definition.Weather
        if Kind == false then
            Weather.force(key(Name), false, Definition.Priority, Time)
        elseif type(Kind) == "string" then
            Weather.force(key(Name), Kind, Definition.Priority, Time)
        end
        hook(Name, "onEnter", Definition.onEnter, Entry.Context)
    end
    Subzones.Entered:Fire(Name)
end

const function exit(Name: string)
    const Entry = Areas[Name]
    if not Entry or not Entry.Inside then
        return
    end
    Entry.Inside = false
    const Definition = List[Name]
    if Definition then
        const Time = fade(Definition)
        AmbientOverride.pop(key(Name), Time)
        Weather.release(key(Name), Time)
        hook(Name, "onExit", Definition.onExit, Entry.Context)
    end
    Subzones.Exited:Fire(Name)
end

const function group(): QuickZone.Group<Player>
    const Known = LocalGroup
    if Known then
        return Known
    end
    const Made = QuickZone.Group.localPlayer()
    LocalGroup = Made
    return Made
end

const function area(Name: string): Area
    const Known = Areas[Name]
    if Known then
        return Known
    end
    const Observer = QuickZone.Observer.new({ groups = { group() }, zones = {} })
    const Parts: { [BasePart]: QuickZone.Zone } = {}
    const Made: Area = {
        Name = Name,
        Observer = Observer,
        Parts = Parts,
        Inside = false,
        Order = 0,
        Context = {
            Name = Name,
            Elapsed = 0,
            Data = {},
            parts = function(): { BasePart }
                const Found: { BasePart } = {}
                for Part in Parts do
                    table.insert(Found, Part)
                end
                return Found
            end,
        },
        Sound = nil,
        Level = 0,
    }
    Areas[Name] = Made
    Observer:onLocalPlayerEnter(function()
        enter(Name)
    end)
    Observer:onLocalPlayerExit(function()
        exit(Name)
    end)
    return Made
end

const function hide(Part: BasePart)
    Part.Transparency = 1
    Part.CastShadow = false
    Part.CanTouch = false
    if Part.Anchored then
        Part.CanCollide = false
        if not (Part:IsA("MeshPart") or Part:IsA("PartOperation")) then
            Part.CanQuery = false
        end
    end
end

const function register(Item: Instance)
    if not Item:IsA("BasePart") or Registered[Item] then
        return
    end
    const Name = Item:GetAttribute(Subzones.Attribute)
    if type(Name) ~= "string" or Name == "" then
        if not Waiting[Item] then
            Waiting[Item] = Item:GetAttributeChangedSignal(Subzones.Attribute):Connect(function()
                const Link = Waiting[Item]
                Waiting[Item] = nil
                if Link then
                    Link:Disconnect()
                end
                if Item:HasTag(Subzones.Tag) then
                    register(Item)
                end
            end)
        end
        return
    end
    Registered[Item] = Name
    if Subzones.Hide then
        hide(Item)
    end
    const Entry = area(Name)
    const Moving = not Item.Anchored
    const Made = QuickZone.Zone.fromPart(Item, { isDynamic = Moving, autoSync = Moving, metadata = Name })
    Entry.Parts[Item] = Made
    Entry.Observer:attach(Made)
end

const function unregister(Item: Instance)
    const Link = Waiting[Item]
    if Link then
        Waiting[Item] = nil
        Link:Disconnect()
    end
    if not Item:IsA("BasePart") then
        return
    end
    const Name = Registered[Item]
    if not Name then
        return
    end
    Registered[Item] = nil
    const Entry = Areas[Name]
    if not Entry then
        return
    end
    const Made = Entry.Parts[Item]
    Entry.Parts[Item] = nil
    if Made then
        Made:destroy()
    end
end

const function folder(): Folder
    const Known = Holder
    if Known and Known.Parent then
        return Known
    end
    const Made = Instance.new("Folder")
    Made.Name = "LocalSubzones"
    Made.Parent = Workspace
    Holder = Made
    return Made
end

function Subzones.create(Name: string, At: CFrame, Size: Vector3, Shape: Enum.PartType?): Part
    const Made = Instance.new("Part")
    Made.Name = Name
    Made.Shape = Shape or Enum.PartType.Block
    Made.Size = Size
    Made.CFrame = At
    Made.Anchored = true
    Made.CanCollide = false
    Made.CanQuery = false
    Made.CanTouch = false
    Made.CastShadow = false
    Made.Transparency = 1
    Made:SetAttribute(Subzones.Attribute, Name)
    Made:AddTag(Subzones.Tag)
    Made.Parent = folder()
    return Made
end

const function winner(): string?
    local Best: string? = nil
    local BestPriority = -math.huge
    local BestOrder = -1
    for Name, Entry in Areas do
        const Definition = List[Name]
        if not Entry.Inside or not Definition or not Definition.Sound then
            continue
        end
        const Priority = Definition.Priority or 0
        if Priority > BestPriority or (Priority == BestPriority and Entry.Order > BestOrder) then
            Best = Name
            BestPriority = Priority
            BestOrder = Entry.Order
        end
    end
    return Best
end

const function sound(Entry: Area, Definition: Definition?, Goal: number, Delta: number)
    if Entry.Level == Goal and not Entry.Sound then
        return
    end
    const Time = fade(Definition)
    const Amount = if Time > 0 then Delta / Time else 1
    Entry.Level = if Goal > Entry.Level then math.min(Entry.Level + Amount, Goal) else math.max(Entry.Level - Amount, Goal)
    const Name = if Definition then Definition.Sound else nil
    local Playing = Entry.Sound
    if Entry.Level > 0 and not Playing and Name then
        Playing = Sounds.loop(Name)
        Entry.Sound = Playing
    end
    if not Playing then
        return
    end
    if Entry.Level <= 0 or not Name then
        Entry.Sound = nil
        Playing:Destroy()
        return
    end
    const Loud = if Definition and Definition.Volume then Definition.Volume else Sounds.volume(Name)
    Playing.Volume = Loud * Entry.Level
end

const function step(Delta: number)
    const Top = winner()
    for Name, Entry in Areas do
        const Definition = List[Name]
        if Entry.Inside then
            Entry.Context.Elapsed += Delta
            if Definition then
                hook(Name, "onIdle", Definition.onIdle, Entry.Context, Delta)
            end
        end
        sound(Entry, Definition, if Name == Top then 1 else 0, Delta)
    end
end

function Subzones.start()
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    load()
    for _, Item in CollectionService:GetTagged(Subzones.Tag) do
        register(Item)
    end
    CollectionService:GetInstanceAddedSignal(Subzones.Tag):Connect(register)
    CollectionService:GetInstanceRemovedSignal(Subzones.Tag):Connect(unregister)
    RunService.Heartbeat:Connect(step)
end

return Subzones
