--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Build = require(ReplicatedStorage.Shared.Customize.Catalog.Build)
const Clips = require(ReplicatedStorage.Shared.AnimationController.Clips)
const Format = require(ReplicatedStorage.Shared.Customize.Format)
const Config = require(script.Config)

export type Mount = {
    Id: string,
    Accepts: { string },
    Offset: CFrame,
    Label: string?,
    Required: boolean?,
}

export type Action = {
    Id: string,
    Label: string,
    Key: Enum.KeyCode?,
    Toggle: boolean?,
}

export type SetSpec = {
    Full: { [string]: string }?,
    Legs: { [string]: string }?,
    Body: { [string]: string }?,
}

export type ClipValue = Clips.Spec | string | number

export type ToolDef = {
    Name: string,
    Category: string,
    Pack: string?,
    Order: number?,
    Description: string?,
    Grip: CFrame?,
    Mounts: { Mount }?,
    Defaults: { [string]: string }?,
    Clips: { [string]: ClipValue }?,
    Sets: { [string]: SetSpec }?,
    Equip: string?,
    Unequip: string?,
    Actions: { Action }?,
    Stats: { [string]: any }?,
    AllowCrawl: boolean?,
    client: { [string]: any }?,
    server: { [string]: any }?,
}

export type AttachmentDef = {
    Name: string,
    Kind: string,
    Pack: string?,
    Order: number?,
    Description: string?,
    Offset: CFrame?,
    Mounts: { Mount }?,
    Mods: { [string]: any }?,
}

export type Category = {
    Id: string,
    Name: string,
    Tools: { string },
}

export type Owns = (Pack: string?) -> boolean

export type Source = (Kind: string, Id: string) -> Instance?

const Tools = {
    Config = Config,
    Build = Build,
    MountAttribute = "MountPath",
    PathAttribute = "ToolPath",
    ToolAttribute = "ToolId",
    AssetAttribute = "ToolAssetKey",
}

local Source: Source? = nil

const Items: { [string]: ToolDef } = {}
const Attachments: { [string]: AttachmentDef } = {}
local Loaded = false

const function warnBad(Kind: string, Id: unknown, Why: string)
    warn(`[Tools] {Kind} "{tostring(Id)}" {Why}`)
end

const function mountsOk(Kind: string, Id: string, Mounts: { Mount }?): boolean
    const Seen: { [string]: boolean } = {}
    for _, Mount in Mounts or {} do
        if type(Mount.Id) ~= "string" or Mount.Id == "" or string.find(Mount.Id, "/", 1, true) or Seen[Mount.Id] then
            warnBad(Kind, Id, "has a mount with a missing, repeated or bad Id")
            return false
        end
        if type(Mount.Accepts) ~= "table" or typeof(Mount.Offset) ~= "CFrame" then
            warnBad(Kind, Id, `mount "{Mount.Id}" needs Accepts and an Offset`)
            return false
        end
        Seen[Mount.Id] = true
    end
    return true
end

function Tools.add(Id: string, Def: ToolDef): boolean
    if type(Id) ~= "string" or Id == "" or Items[Id] then
        warnBad("tool", Id, "is missing or defined more than once")
        return false
    end
    if type(Def) ~= "table" or type(Def.Name) ~= "string" then
        warnBad("tool", Id, "needs a Name")
        return false
    end
    if type(Def.Category) ~= "string" then
        warnBad("tool", Id, "needs a Category")
        return false
    end
    if not mountsOk("tool", Id, Def.Mounts) then
        return false
    end
    Items[Id] = Def
    return true
end

function Tools.addAttachment(Id: string, Def: AttachmentDef): boolean
    if type(Id) ~= "string" or Id == "" or Attachments[Id] then
        warnBad("attachment", Id, "is missing or defined more than once")
        return false
    end
    if type(Def) ~= "table" or type(Def.Name) ~= "string" or type(Def.Kind) ~= "string" then
        warnBad("attachment", Id, "needs a Name and a Kind")
        return false
    end
    if not mountsOk("attachment", Id, Def.Mounts) then
        return false
    end
    Attachments[Id] = Def
    return true
end

const function loadFolder(Name: string, Add: (Id: string, Def: any) -> boolean)
    const Folder = script:FindFirstChild(Name)
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
            warn(`[Tools] {Module:GetFullName()} failed to load: {if Ok then "it must return a table" else Result}`)
            continue
        end
        for Id, Def in Result do
            Add(Id, Def)
        end
    end
end

const function load()
    if Loaded then
        return
    end
    Loaded = true
    loadFolder("Items", Tools.add)
    loadFolder("Attachments", Tools.addAttachment)
end

function Tools.get(Id: unknown): ToolDef?
    load()
    return if type(Id) == "string" then Items[Id] else nil
end

function Tools.attachment(Id: unknown): AttachmentDef?
    load()
    return if type(Id) == "string" then Attachments[Id] else nil
end

function Tools.list(): { [string]: ToolDef }
    load()
    return Items
end

function Tools.attachments(): { [string]: AttachmentDef }
    load()
    return Attachments
end

function Tools.sorted<T>(List: { [string]: T & { Name: string, Order: number? } }): { string }
    const Ids: { string } = {}
    for Id in List do
        table.insert(Ids, Id)
    end
    table.sort(Ids, function(A: string, B: string): boolean
        const First = List[A]
        const Second = List[B]
        if (First.Order or 0) ~= (Second.Order or 0) then
            return (First.Order or 0) < (Second.Order or 0)
        end
        return First.Name < Second.Name
    end)
    return Ids
end

function Tools.categories(): { Category }
    load()
    const Found: { [string]: Category } = {}
    for _, Id in Tools.sorted(Items) do
        const Def = Items[Id]
        local Entry = Found[Def.Category]
        if not Entry then
            const Known = Config.Categories[Def.Category]
            Entry = { Id = Def.Category, Name = if Known then Known.Name else string.lower(Def.Category), Tools = {} }
            Found[Def.Category] = Entry
        end
        table.insert((Entry :: Category).Tools, Id)
    end
    const Made: { Category } = {}
    for _, Entry in Found do
        table.insert(Made, Entry)
    end
    table.sort(Made, function(A: Category, B: Category): boolean
        const First = Config.Categories[A.Id]
        const Second = Config.Categories[B.Id]
        const OrderA = if First then First.Order else 99
        const OrderB = if Second then Second.Order else 99
        if OrderA ~= OrderB then
            return OrderA < OrderB
        end
        return A.Name < B.Name
    end)
    return Made
end

function Tools.accepts(Mount: Mount, Kind: string): boolean
    return table.find(Mount.Accepts, Kind) ~= nil
end

function Tools.choices(Mount: Mount): { string }
    load()
    const Made: { string } = {}
    for _, Id in Tools.sorted(Attachments) do
        if Tools.accepts(Mount, Attachments[Id].Kind) then
            table.insert(Made, Id)
        end
    end
    return Made
end

function Tools.mountAt(ToolId: string, Parts: { [string]: string }, Path: string): Mount?
    const Def = Tools.get(ToolId)
    if not Def then
        return nil
    end
    local Mounts = Def.Mounts or {}
    local Prefix = ""
    for Segment in string.gmatch(Path, "[^/]+") do
        local Found: Mount? = nil
        for _, Mount in Mounts do
            if Mount.Id == Segment then
                Found = Mount
            end
        end
        if not Found then
            return nil
        end
        const Here = Prefix .. Segment
        if Here == Path then
            return Found
        end
        const Chosen = Tools.attachment(Parts[Here])
        if not Chosen then
            return nil
        end
        Mounts = Chosen.Mounts or {}
        Prefix = Here .. "/"
    end
    return nil
end

const function cleanHolster(Raw: unknown): ToolHolster?
    if type(Raw) ~= "table" then
        return nil
    end
    const Given = Raw :: any
    const Attach = if Format.isBody(Given.Attach) then Given.Attach else "UpperTorso"
    local Offset = CFrame.identity
    if type(Given.Offset) == "table" and #Given.Offset >= 12 then
        const Frame = Format.frame(Given.Offset)
        const Position = Frame.Position
        Offset = if Position.Magnitude > Config.MaxHolsterOffset then CFrame.new(Position.Unit * Config.MaxHolsterOffset) * Frame.Rotation else Frame
    end
    const Size = if type(Given.Size) == "number" and Given.Size == Given.Size then math.clamp(Given.Size, Config.MinSize, Config.MaxSize) else 1
    return {
        On = Given.On == true,
        Attach = Attach,
        Offset = Format.packFrame(Offset),
        Size = Size,
    }
end

function Tools.clean(ToolId: string, Raw: unknown, Owns: Owns, UseDefaults: boolean?): ToolBuild?
    const Def = Tools.get(ToolId)
    if not Def then
        return nil
    end
    const Given = if type(Raw) == "table" then Raw :: any else {}
    const Wanted: { [string]: any } = if type(Given.Parts) == "table" then Given.Parts else {}
    const Defaults = Def.Defaults or {}
    const Parts: { [string]: string } = {}
    const function walk(Mounts: { Mount }?, Prefix: string, Depth: number)
        if Depth > Config.MaxDepth then
            return
        end
        for _, Mount in Mounts or {} do
            const Path = Prefix .. Mount.Id
            local Choice = Wanted[Path]
            if Choice == nil and (UseDefaults or Mount.Required) then
                Choice = Defaults[Path]
            end
            local Picked = Tools.attachment(Choice)
            if Picked and (not Tools.accepts(Mount, Picked.Kind) or not Owns(Picked.Pack)) then
                Picked = nil
            end
            if not Picked and Mount.Required then
                for _, Id in Tools.choices(Mount) do
                    const Option = Attachments[Id]
                    if Owns(Option.Pack) then
                        Choice = Id
                        Picked = Option
                        break
                    end
                end
            end
            if Picked then
                Parts[Path] = Choice
                walk(Picked.Mounts, Path .. "/", Depth + 1)
            end
        end
    end
    walk(Def.Mounts, "", 1)
    return {
        Tool = ToolId,
        Parts = Parts,
        Holster = cleanHolster(Given.Holster),
    }
end

function Tools.fresh(ToolId: string, Owns: Owns): ToolBuild?
    return Tools.clean(ToolId, nil, Owns, true)
end

function Tools.owns(Pack: string?, Packs: { [string]: boolean }?, All: boolean?): boolean
    if Pack == nil or All then
        return true
    end
    return Packs ~= nil and Packs[Pack] == true
end

const function prepare(Root: Instance)
    const Items = Root:GetDescendants()
    table.insert(Items, Root)
    for _, Item in Items do
        if Item:IsA("BasePart") then
            Item.Anchored = false
            Item.CanCollide = false
            Item.CanTouch = false
            Item.CanQuery = false
            Item.Massless = true
        end
    end
end

const function rootOf(Item: Instance): BasePart?
    if Item:IsA("BasePart") then
        return Item
    end
    if Item:IsA("Model") then
        return Item.PrimaryPart or Item:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

const function addMount(Owner: BasePart, Mount: Mount, Path: string)
    const Point = Instance.new("Attachment")
    Point.Name = `Mount_{Path}`
    Point.CFrame = Mount.Offset
    Point:SetAttribute(Tools.MountAttribute, Path)
    Point:SetAttribute("MountLabel", Mount.Label or Mount.Id)
    Point:SetAttribute("MountRequired", Mount.Required == true)
    Point.Parent = Owner
end

function Tools.setSource(Given: Source)
    Source = Given
end

const function template(Kind: string, Id: string): Instance?
    const Found = if Source then Source(Kind, Id) else nil
    return if Found then Found:Clone() else nil
end

const function ready(Given: ToolBuild): boolean
    local All = Source ~= nil and (Source :: Source)("Tool", Given.Tool) ~= nil
    for _, Id in Given.Parts do
        if Tools.attachment(Id) and not (if Source then Source("Attachment", Id) else nil) then
            All = false
        end
    end
    return All
end

function Tools.assemble(Given: ToolBuild): Model?
    const Def = Tools.get(Given.Tool)
    if not Def or not ready(Given) then
        return nil
    end
    const Made = template("Tool", Given.Tool)
    if not Made or not Made:IsA("Model") then
        warn(`[Tools] {Given.Tool} needs a premade model in ServerStorage.ToolAssets.Tools`)
        if Made then
            Made:Destroy()
        end
        return nil
    end
    const Root = rootOf(Made)
    if not Root then
        Made:Destroy()
        return nil
    end
    Made.PrimaryPart = Root
    Made.Name = Def.Name
    Made:SetAttribute(Tools.ToolAttribute, Given.Tool)
    const function attach(Owner: BasePart, Mounts: { Mount }?, Prefix: string, Depth: number)
        if Depth > Config.MaxDepth then
            return
        end
        for _, Mount in Mounts or {} do
            const Path = Prefix .. Mount.Id
            addMount(Owner, Mount, Path)
            const Picked = Tools.attachment(Given.Parts[Path])
            if not Picked or not Tools.accepts(Mount, Picked.Kind) then
                continue
            end
            const Piece = template("Attachment", Given.Parts[Path])
            const PieceRoot = if Piece then rootOf(Piece) else nil
            if not Piece or not PieceRoot then
                continue
            end
            Piece.Name = `Part_{Path}`
            Piece:SetAttribute(Tools.PathAttribute, Path)
            const Joint = Instance.new("Weld")
            Joint.Name = "ToolWeld"
            Joint.Part0 = Owner
            Joint.Part1 = PieceRoot
            Joint.C0 = Mount.Offset * (Picked.Offset or CFrame.identity)
            Joint.Parent = PieceRoot
            PieceRoot.CFrame = Owner.CFrame * Joint.C0
            Piece.Parent = Made
            attach(PieceRoot, Picked.Mounts, Path .. "/", Depth + 1)
        end
    end
    attach(Root, Def.Mounts, "", 1)
    prepare(Made)
    return Made
end

const function depth(Path: string): number
    local Count = 0
    for _ in string.gmatch(Path, "[^/]+") do
        Count += 1
    end
    return Count
end

function Tools.stats(Given: ToolBuild?): { [string]: any }
    const Def = if Given then Tools.get(Given.Tool) else nil
    const Made: { [string]: any } = if Def and Def.Stats then table.clone(Def.Stats) else {}
    if not Given then
        return Made
    end
    const Paths: { string } = {}
    for Path in Given.Parts do
        table.insert(Paths, Path)
    end
    table.sort(Paths, function(A: string, B: string): boolean
        const First = depth(A)
        const Second = depth(B)
        if First ~= Second then
            return First < Second
        end
        return A < B
    end)
    for _, Path in Paths do
        const Piece = Tools.attachment(Given.Parts[Path])
        for Key, Value in (if Piece then Piece.Mods else nil) or {} do
            const Base = string.match(Key, "^(.+)Scale$")
            if Base and type(Value) == "number" and type(Made[Base]) == "number" then
                Made[Base] *= Value
            else
                Made[Key] = Value
            end
        end
    end
    return Made
end

function Tools.grip(Def: ToolDef, Hand: BasePart): CFrame
    const Point = Hand:FindFirstChild("RightGripAttachment")
    const Position = if Point and Point:IsA("Attachment") then Point.Position else Config.GripPosition
    return CFrame.new(Position) * (Def.Grip or Config.Grip)
end

return Tools
