--!strict
const ContentProvider = game:GetService("ContentProvider")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const SoundService = game:GetService("SoundService")
const Workspace = game:GetService("Workspace")

const Config = require(script.Config)

export type Entry = Config.Entry

const Sounds = {
    Config = Config,
    FolderName = "GameSounds",
    CacheName = "Cache",
    Lifetime = 10,
}

const Groups: { [string]: SoundGroup } = {}
const Templates: { [string]: Sound } = {}
local Store: Folder? = nil
local Preloaded = false
const Last: { [string]: number } = {}
const Watched: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local Folder: Folder? = nil

const function folder(): Folder
    const Existing = Folder
    if Existing and Existing.Parent then
        return Existing
    end
    const Made = Instance.new("Folder")
    Made.Name = Sounds.FolderName
    Made.Parent = SoundService
    Folder = Made
    table.clear(Groups)
    table.clear(Templates)
    Store = nil
    for Name, Volume in Config.Groups do
        const Group = Instance.new("SoundGroup")
        Group.Name = Name
        Group.Volume = Volume
        Group.Parent = Made
        Groups[Name] = Group
    end
    return Made
end

const function cache(): Folder
    const Root = folder()
    const Existing = Store
    if Existing and Existing.Parent == Root then
        return Existing
    end
    const Made = Instance.new("Folder")
    Made.Name = Sounds.CacheName
    Made.Parent = Root
    Store = Made
    return Made
end

const function resolve(Id: string): string
    return if string.match(Id, "^%d+$") then `rbxassetid://{Id}` else Id
end

function Sounds.get(Name: string): Entry?
    const Entry = Config.Sounds[Name]
    if not Entry or Entry.Id == "" then
        return nil
    end
    return Entry
end

function Sounds.id(Name: string): string?
    const Entry = Sounds.get(Name)
    if Entry then
        return resolve(Entry.Id)
    end
    if string.match(Name, "^rbxasset") or string.match(Name, "^%d+$") then
        return resolve(Name)
    end
    return nil
end

function Sounds.volume(Name: string): number
    const Entry = Sounds.get(Name)
    return if Entry then Entry.Volume or 0.5 else 0.5
end

function Sounds.setGroupVolume(Group: string, Volume: number)
    folder()
    const Found = Groups[Group]
    if Found then
        Found.Volume = Volume
    end
end

const function ready(Name: string): Entry?
    if not RunService:IsClient() then
        return nil
    end
    const Entry = Sounds.get(Name)
    if not Entry then
        return nil
    end
    const Now = os.clock()
    const Gap = Entry.Cooldown or 0
    if Gap > 0 and Last[Name] and Now - Last[Name] < Gap then
        return nil
    end
    Last[Name] = Now
    return Entry
end

const function template(Name: string, Entry: Entry): Sound
    const Holder = cache()
    const Id = resolve(Entry.Id)
    const Key = `{Name}|{Id}`
    const Known = Templates[Key]
    if Known and Known.Parent == Holder then
        return Known
    end
    const Made = Instance.new("Sound")
    Made.Name = Name
    Made.SoundId = Id
    Made.Volume = Entry.Volume or 0.5
    Made.PlaybackSpeed = Entry.Pitch or 1
    Made.SoundGroup = if Entry.Group then Groups[Entry.Group] else nil
    if Entry.Range then
        Made.RollOffMaxDistance = Entry.Range
    end
    Made.Parent = Holder
    Templates[Key] = Made
    return Made
end

const function make(Name: string, Entry: Entry, Parent: Instance): Sound
    const Made = template(Name, Entry):Clone()
    const Variance = Entry.Variance or 0
    Made.PlaybackSpeed = (Entry.Pitch or 1) * (1 + (math.random() * 2 - 1) * Variance)
    Made.Parent = Parent
    return Made
end

function Sounds.preload()
    if Preloaded or not RunService:IsClient() then
        return
    end
    Preloaded = true
    const List: { Instance } = {}
    for Name in Config.Sounds do
        const Entry = Sounds.get(Name)
        if Entry then
            table.insert(List, template(Name, Entry))
        end
    end
    if #List == 0 then
        return
    end
    task.spawn(function()
        const Ok, Problem = pcall(ContentProvider.PreloadAsync, ContentProvider, List)
        if not Ok then
            warn(`[Sounds] preload failed: {Problem}`)
        end
    end)
end

const function fire(Made: Sound, Holder: Instance?)
    Made.Ended:Once(function()
        (Holder or Made):Destroy()
    end)
    task.delay(Sounds.Lifetime, function()
        if (Holder or Made).Parent then
            (Holder or Made):Destroy()
        end
    end)
    Made:Play()
end

function Sounds.play(Name: string): Sound?
    const Entry = ready(Name)
    if not Entry then
        return nil
    end
    const Made = make(Name, Entry, folder())
    fire(Made, nil)
    return Made
end

function Sounds.playAt(Name: string, Where: Vector3 | Instance): Sound?
    const Entry = ready(Name)
    if not Entry then
        return nil
    end
    if typeof(Where) == "Instance" then
        if Where:IsA("BasePart") or Where:IsA("Attachment") then
            const Made = make(Name, Entry, Where)
            fire(Made, nil)
            return Made
        end
        return Sounds.play(Name)
    end
    const Point = Instance.new("Attachment")
    Point.Name = `Sound_{Name}`
    Point.Parent = Workspace.Terrain
    Point.WorldPosition = Where
    const Made = make(Name, Entry, Point)
    fire(Made, Point)
    return Made
end

function Sounds.loop(Name: string): Sound?
    if not RunService:IsClient() then
        return nil
    end
    const Entry: Entry? = Sounds.get(Name) or (if Sounds.id(Name) then { Id = Name, Group = "Ambience", Volume = 0.5 } else nil)
    if not Entry then
        return nil
    end
    const Made = make(Name, Entry, folder())
    Made.Looped = true
    Made.PlaybackSpeed = Entry.Pitch or 1
    Made.Volume = 0
    Made:Play()
    return Made
end

const function hook(Item: Instance)
    if not Item:IsA("GuiButton") or Watched[Item] then
        return
    end
    Watched[Item] = true
    Item.Activated:Connect(function()
        Sounds.play("Click")
    end)
end

function Sounds.watch(Root: Instance)
    if Root:IsA("GuiButton") then
        hook(Root)
    end
    for _, Item in Root:GetDescendants() do
        hook(Item)
    end
    Root.DescendantAdded:Connect(hook)
end

function Sounds.start()
    if not RunService:IsClient() then
        return
    end
    folder()
    Sounds.preload()
    const PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    Sounds.watch(PlayerGui)
end

return Sounds
