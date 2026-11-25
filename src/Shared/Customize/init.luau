--!strict
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")
const Workspace = game:GetService("Workspace")

const signal = require(ReplicatedStorage.MainPackages.signal)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Config = require(script.Config)
const Catalog = require(script.Catalog)
const Format = require(script.Format)
const Rig = require(script.Rig)
const FreeCam = require(script.FreeCam)
const Gizmo = require(script.Gizmo)
const Sounds = require(ReplicatedStorage.Shared.Sounds)

export type Mode = Gizmo.Mode
export type Kind = "Body" | "Default" | "Asset" | "Builtin"
export type Space = "Local" | "World"

export type Entry = {
    Id: string,
    Name: string,
    Kind: Kind,
    Part: BasePart,
    Group: string?,
    Hidden: boolean,
}

export type GroupInfo = {
    Id: string,
    Name: string,
    Code: string?,
    Members: { string },
}

const function names(List: { string }): { [string]: string }
    const Made: { [string]: string } = {}
    for _, Name in List do
        Made[Name] = Name
    end
    return table.freeze(Made)
end

const function limbNames(): { [string]: string }
    const Made: { [string]: string } = {}
    for Name in Catalog.Limbs do
        Made[Name] = Name
    end
    return table.freeze(Made)
end

const Customize = {
    Modes = table.freeze({
        None = "None" :: "None",
        Translate = "Translate" :: "Translate",
        Rotate = "Rotate" :: "Rotate",
        Scale = "Scale" :: "Scale",
    }),
    BodyParts = names(Catalog.BodyParts),
    Limbs = limbNames(),
    Catalog = Catalog,
    Config = Config,
    DefaultPrefix = "default:",
    Changed = signal.new(),
    SelectionChanged = signal.new(),
    Exited = signal.new(),
}

const Net = NetWatch.Customize
local Active = false
local Copy: Model? = nil
local Marker: Highlight? = nil
local Current: Look = Format.empty()
local Applied: Look? = nil
local Saves: { [string]: LookSave } = {}
local Selected: string? = nil
local Mode: Mode = "None"
local Counter = 0
local Started = false
local Entering = false
local DiedLink: RBXScriptConnection? = nil
local GroupSelected: string? = nil
local Hover: Highlight? = nil
local Proxy: Part? = nil
local ProxyBase = Vector3.one
const Relative: { [string]: CFrame } = {}
const StartScale: { [string]: Vector3 } = {}
const Marks: { [string]: SelectionBox } = {}
const Templates: { [string]: string } = {}

const function changed()
    for GroupId in Current.Groups do
        local Used = false
        for _, Record in Current.Parts do
            if Record.Group == GroupId and not Record.Removed then
                Used = true
                break
            end
        end
        if not Used then
            Current.Groups[GroupId] = nil
        end
    end
    Customize.Changed:Fire()
end

const function newId(): string
    Counter += 1
    return `p{Counter}{string.sub(HttpService:GenerateGUID(false), 1, 6)}`
end

const function resolve(AssetId: number): Instance?
    const Folder = ReplicatedStorage:FindFirstChild(Config.AssetFolder)
    return if Folder then Folder:FindFirstChild(tostring(AssetId)) else nil
end

const function fetch(AssetId: number): (Instance?, string?)
    const Known = resolve(AssetId)
    if Known then
        return Known, nil
    end
    const Reply = Net:Call("@Customize/Fetch", AssetId)
    if type(Reply) ~= "table" then
        return nil, "The server did not answer"
    end
    if not Reply.Ok then
        return nil, if type(Reply.Error) == "string" then Reply.Error else "That item could not load"
    end
    const Folder = ReplicatedStorage:WaitForChild(Config.AssetFolder, Config.FetchTimeout)
    const Found = if Folder then Folder:WaitForChild(tostring(AssetId), Config.FetchTimeout) else nil
    return Found, if Found then nil else "That item took too long to load"
end

const function fetchClothing(Kind: Catalog.ClothingKind, AssetId: number): (string?, string?)
    const Key = `{Kind}{AssetId}`
    if Templates[Key] then
        return Templates[Key], nil
    end
    const Reply = Net:Call("@Customize/Clothing", Kind, AssetId)
    if type(Reply) ~= "table" then
        return nil, "The server did not answer"
    end
    if not Reply.Ok or type(Reply.Template) ~= "string" then
        return nil, if type(Reply.Error) == "string" then Reply.Error else "That item could not load"
    end
    Templates[Key] = Reply.Template
    return Reply.Template, nil
end

const function wear(Kind: Catalog.ClothingKind, AssetId: number): string?
    return Templates[`{Kind}{AssetId}`]
end

const function fetchAll(Given: Look): string?
    for _, AssetId in Format.assets(Given) do
        const Found, Problem = fetch(AssetId)
        if not Found then
            return Problem or `Item {AssetId} could not load`
        end
    end
    for _, Kind in { "Shirt", "Pants" } :: { Catalog.ClothingKind } do
        const AssetId = (Given :: any)[Kind]
        if type(AssetId) == "number" then
            const Template, Problem = fetchClothing(Kind, AssetId)
            if not Template then
                return Problem
            end
        end
    end
    return nil
end

const function isDefault(Id: string): boolean
    return string.sub(Id, 1, #Customize.DefaultPrefix) == Customize.DefaultPrefix
end

const function recordOf(Id: string): (LookPart?, number?)
    for Index, Record in Current.Parts do
        if Record.Id == Id then
            return Record, Index
        end
    end
    return nil, nil
end

const function bodyPart(Name: string): BasePart?
    const Model = Copy
    return if Model then Rig.bodyParts(Model)[Name] else nil
end

const function bodyEdit(Name: string): LookBody
    const Found = Current.Body[Name]
    if Found then
        return Found
    end
    const Made: LookBody = {}
    Current.Body[Name] = Made
    return Made
end

const function queryable(Root: Instance)
    const Items = Root:GetDescendants()
    table.insert(Items, Root)
    for _, Item in Items do
        if Item:IsA("BasePart") then
            Item.CanQuery = true
            Item.CanCollide = false
            Item.CanTouch = false
        end
    end
end

const function partOf(Id: string): BasePart?
    const Model = Copy
    if not Model then
        return nil
    end
    if Format.isBody(Id) then
        return Rig.bodyParts(Model)[Id]
    end
    if isDefault(Id) then
        const Accessory = Model:FindFirstChild(string.sub(Id, #Customize.DefaultPrefix + 1))
        const Handle = if Accessory and Accessory:IsA("Accessory") then Accessory:FindFirstChild("Handle") else nil
        return if Handle and Handle:IsA("BasePart") then Handle else nil
    end
    return Rig.rootOf(Rig.find(Model, Id))
end

const function rebuildPart(Record: LookPart)
    const Model = Copy
    if not Model then
        return
    end
    const Made = Rig.applyPart(Model, Record, resolve, Current)
    if Made then
        queryable(Made)
    end
end

const function rebuildBody()
    const Model = Copy
    if not Model then
        return
    end
    Rig.applyBody(Model, Current)
    queryable(Rig.folder(Model))
end

const function rebuildAll()
    const Model = Copy
    if not Model then
        return
    end
    Rig.apply(Model, Current, resolve, wear)
    queryable(Model)
end

const function rebuildOutfit()
    const Model = Copy
    if Model then
        Rig.applyOutfit(Model, Current, wear)
    end
end

const function refreshMarker()
    const Highlight = Marker
    if not Highlight then
        return
    end
    const Id = Selected
    const Model = Copy
    local Target: Instance? = if Id then partOf(Id) else nil
    if Id and Model and Target and not Format.isBody(Id) and not isDefault(Id) then
        Target = Rig.find(Model, Id) or Target
    end
    Highlight.Adornee = Target
    Highlight.Enabled = Target ~= nil
end

const function weldTarget(Handle: BasePart): BasePart?
    for _, Item in Handle:GetChildren() do
        if Item:IsA("JointInstance") then
            const Other = if Item.Part0 == Handle then Item.Part1 else Item.Part0
            if Other and Format.isBody(Other.Name) then
                return Other
            end
        elseif Item:IsA("RigidConstraint") then
            for _, Attachment in { Item.Attachment0, Item.Attachment1 } do
                const Owner = if Attachment then Attachment.Parent else nil
                if Owner and Owner ~= Handle and Owner:IsA("BasePart") and Format.isBody(Owner.Name) then
                    return Owner
                end
            end
        end
    end
    return nil
end

const function convertDefault(Name: string): LookPart?
    const Model = Copy
    if not Model or #Current.Parts >= Config.MaxRigParts then
        return nil
    end
    const Accessory = Model:FindFirstChild(Name)
    const Handle = if Accessory and Accessory:IsA("Accessory") then Accessory:FindFirstChild("Handle") else nil
    if not Handle or not Handle:IsA("BasePart") then
        return nil
    end
    const Target = weldTarget(Handle) or Rig.bodyParts(Model).Head
    if not Target then
        return nil
    end
    const Record: LookPart = {
        Id = newId(),
        Kind = "Default",
        Target = Name,
        Attach = Target.Name,
        Offset = Format.packFrame(Format.clampOffset(Target.CFrame:ToObjectSpace(Handle.CFrame))),
        Scale = { 1, 1, 1 },
    }
    table.insert(Current.Parts, Record)
    rebuildPart(Record)
    return Record
end

const function editable(Id: string): LookPart?
    const Found = recordOf(Id)
    if Found then
        return Found
    end
    if not isDefault(Id) then
        return nil
    end
    const Record = convertDefault(string.sub(Id, #Customize.DefaultPrefix + 1))
    if Record and Selected == Id then
        Selected = Record.Id
    end
    return Record
end

const function factorOf(Record: LookPart): Vector3
    return Rig.factor(Current, Record.Attach)
end

const function actualScale(Record: LookPart): Vector3
    return Format.vector(Record.Scale, Vector3.one) * factorOf(Record)
end

const function storeScale(Record: LookPart, Actual: Vector3)
    Record.Scale = Format.packVector(Actual / factorOf(Record))
end

const function actualFrame(Record: LookPart): CFrame
    return Rig.scaleFrame(Format.frame(Record.Offset), factorOf(Record))
end

const function setWorld(Record: LookPart, World: CFrame)
    const Model = Copy
    const Attach = bodyPart(Record.Attach)
    if not Model or not Attach then
        return
    end
    const Offset = Format.clampOffset(Attach.CFrame:ToObjectSpace(World))
    Record.Offset = Format.packFrame(Rig.scaleFrame(Offset, Vector3.one / factorOf(Record)))
    Rig.setOffset(Model, Record.Id, Offset)
end

const function membersOf(GroupId: string): { LookPart }
    const Found: { LookPart } = {}
    for _, Record in Current.Parts do
        if Record.Group == GroupId and not Record.Removed then
            table.insert(Found, Record)
        end
    end
    return Found
end

const function clearMarks()
    for Id, Box in Marks do
        Marks[Id] = nil
        Box:Destroy()
    end
end

const function dropProxy()
    const Old = Proxy
    Proxy = nil
    if Old then
        Old:Destroy()
    end
    table.clear(Relative)
    table.clear(StartScale)
end

const function setupProxy(GroupId: string): Part?
    const Model = Copy
    if not Model then
        return nil
    end
    local Low = Vector3.one * math.huge
    local High = -Vector3.one * math.huge
    const Roots: { [string]: BasePart } = {}
    for _, Record in membersOf(GroupId) do
        const Root = partOf(Record.Id)
        if not Root then
            continue
        end
        Roots[Record.Id] = Root
        const Frame = Root.CFrame
        const Half = Root.Size / 2
        const Extent = Vector3.new(
            math.abs(Frame.XVector.X) * Half.X + math.abs(Frame.YVector.X) * Half.Y + math.abs(Frame.ZVector.X) * Half.Z,
            math.abs(Frame.XVector.Y) * Half.X + math.abs(Frame.YVector.Y) * Half.Y + math.abs(Frame.ZVector.Y) * Half.Z,
            math.abs(Frame.XVector.Z) * Half.X + math.abs(Frame.YVector.Z) * Half.Y + math.abs(Frame.ZVector.Z) * Half.Z
        )
        Low = Low:Min(Frame.Position - Extent)
        High = High:Max(Frame.Position + Extent)
    end
    if next(Roots) == nil then
        return nil
    end
    local Made = Proxy
    if not Made or Made.Parent ~= Model then
        dropProxy()
        Made = Instance.new("Part")
        Made.Name = "CustomizeGroupProxy"
        Made.Anchored = true
        Made.CanCollide = false
        Made.CanQuery = false
        Made.CanTouch = false
        Made.Transparency = 1
        Made.Parent = Model
        Proxy = Made
    end
    const Part = Made :: Part
    Part.Size = (High - Low):Max(Vector3.one * 0.2)
    Part.CFrame = CFrame.new((Low + High) / 2)
    ProxyBase = Part.Size
    table.clear(Relative)
    table.clear(StartScale)
    for Id, Root in Roots do
        Relative[Id] = Part.CFrame:ToObjectSpace(Root.CFrame)
        const Record = recordOf(Id)
        StartScale[Id] = if Record then actualScale(Record) else Vector3.one
    end
    return Part
end

const function refreshGroupGizmo(GroupId: string)
    const Part = setupProxy(GroupId)
    if not Part or Mode == "None" then
        Gizmo.detach()
        return
    end
    Gizmo.attach(Part, Mode, {
        moved = function(World: CFrame)
            Part.CFrame = World
            for _, Record in membersOf(GroupId) do
                const Rel = Relative[Record.Id]
                if Rel then
                    setWorld(Record, World * Rel)
                end
            end
        end,
        sized = function(Size: Vector3, World: CFrame)
            const Model = Copy
            if not Model then
                return
            end
            const Factor = Size / ProxyBase
            Part.Size = Size
            Part.CFrame = World
            for _, Record in membersOf(GroupId) do
                const Rel = Relative[Record.Id]
                const Base = StartScale[Record.Id]
                if not Rel or not Base then
                    continue
                end
                const Made = Rig.find(Model, Record.Id)
                const Scale = Format.limitScale(Base * Factor, if Made then Rig.bound(Made) else nil)
                storeScale(Record, Scale)
                Rig.setScale(Model, Record.Id, Scale)
                setWorld(Record, World * (CFrame.new(Rel.Position * Factor) * Rel.Rotation))
            end
        end,
        finished = function()
            refreshGroupGizmo(GroupId)
            changed()
        end,
    })
end

const function refreshGizmo()
    const Group = GroupSelected
    if Active and Group then
        refreshGroupGizmo(Group)
        return
    end
    const Id = Selected
    if not Active or Mode == "None" or not Id or Format.isBody(Id) then
        Gizmo.detach()
        return
    end
    const Record = editable(Id)
    const Root = if Record then partOf(Record.Id) else nil
    if not Record or not Root then
        Gizmo.detach()
        return
    end
    refreshMarker()
    Gizmo.attach(Root, Mode, {
        moved = function(World: CFrame)
            setWorld(Record, World)
        end,
        sized = function(Size: Vector3, World: CFrame)
            const Model = Copy
            const Base = Root:GetAttribute("CustomizeBase")
            if not Model or typeof(Base) ~= "Vector3" then
                return
            end
            const Made = Rig.find(Model, Record.Id)
            const Scale = Format.limitScale(Size / Base, if Made then Rig.bound(Made) else nil)
            storeScale(Record, Scale)
            Rig.setScale(Model, Record.Id, Scale)
            setWorld(Record, World)
        end,
        finished = changed,
    })
end

const function labelOf(Record: LookPart): string
    if Record.Name then
        return Record.Name
    end
    if Record.Kind == "Builtin" and Record.Piece then
        return string.lower(Record.Piece)
    end
    if Record.Kind == "Asset" then
        return `item {Record.Asset}`
    elseif Record.Kind == "Builtin" then
        const Definition = Catalog.part(Record.Builtin)
        return if Definition then Definition.Name else "part"
    end
    return Record.Target or "accessory"
end

const function idFromHit(Hit: BasePart): string?
    const Model = Copy
    if not Model then
        return nil
    end
    const Holder = Model:FindFirstChild(Rig.FolderName)
    if Holder and Hit:IsDescendantOf(Holder) then
        local Node: Instance = Hit
        while Node.Parent and Node.Parent ~= Holder do
            Node = Node.Parent
        end
        if Node:GetAttribute("CustomizeSwap") then
            const Piece = string.match(Node.Name, "_(.+)$")
            return Piece
        end
        return Node.Name
    end
    const Parent = Hit.Parent
    if Parent and Parent:IsA("Accessory") then
        return Customize.DefaultPrefix .. Parent.Name
    end
    return if Format.isBody(Hit.Name) then Hit.Name else nil
end

function Customize.active(): boolean
    return Active
end

function Customize.rig(): Model?
    return Copy
end

const function capture(Character: Model): { [string]: CFrame }
    const Poses: { [string]: CFrame } = {}
    for Name, Part in Rig.bodyParts(Character) do
        Poses[Name] = Part.CFrame
    end
    const Root = Character:FindFirstChild("HumanoidRootPart")
    if Root and Root:IsA("BasePart") then
        Poses.HumanoidRootPart = Root.CFrame
    end
    return Poses
end

function Customize.enter(At: CFrame?): boolean
    Customize.start()
    if Active or Entering then
        return false
    end
    const Character = Players.LocalPlayer.Character
    const Home = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    if not Character or not Home or not Home:IsA("BasePart") then
        return false
    end
    Entering = true
    const Reply = Net:Call("@Customize/Enter", capture(Character))
    Entering = false
    if type(Reply) ~= "table" or not Reply.Ok then
        warn(`[Customize] could not enter: {if type(Reply) == "table" then Reply.Error else "the server did not answer"}`)
        return false
    end
    const Spot: CFrame = At or (if typeof(Reply.Room) == "CFrame" then Reply.Room else Home.CFrame)
    const Was = Character.Archivable
    Character.Archivable = true
    const Made = Character:Clone()
    Character.Archivable = Was
    if not Made then
        return false
    end
    const Held = Made:FindFirstChild("Tools")
    if Held then
        Held:Destroy()
    end
    for _, Item in Made:GetDescendants() do
        if Item:IsA("LuaSourceContainer") or Item:IsA("ForceField") or Item:IsA("Sound") then
            Item:Destroy()
        end
    end
    const Humanoid = Made:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        Humanoid.EvaluateStateMachine = false
    end
    for _, Item in Made:GetDescendants() do
        if Item:IsA("BasePart") then
            Item.CanCollide = false
            Item.CanTouch = false
        elseif Item:IsA("Motor6D") or Item:IsA("AnimationConstraint") then
            Item.Transform = CFrame.identity
        end
    end
    const Root = Made:FindFirstChild("HumanoidRootPart")
    if Root and Root:IsA("BasePart") then
        Root.Anchored = true
    end
    Made.Name = "CustomizeRig"
    Made:PivotTo(Spot)
    Made.Parent = Workspace

    const Highlight = Instance.new("Highlight")
    Highlight.Name = "CustomizeSelection"
    Highlight.FillColor = Color3.new(1, 1, 1)
    Highlight.OutlineColor = Color3.new(1, 1, 1)
    Highlight.FillTransparency = 0.75
    Highlight.OutlineTransparency = 0
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.Enabled = false
    Highlight.Parent = Made

    Copy = Made
    Marker = Highlight
    Active = true
    Selected = nil
    Mode = "None"
    Current = if Applied then Format.clone(Applied) else Format.empty()

    const RealHumanoid = Character:FindFirstChildOfClass("Humanoid")
    if RealHumanoid then
        DiedLink = RealHumanoid.Died:Connect(function()
            task.spawn(function()
                Customize.exit()
            end)
        end)
    end

    const Focus = Spot.Position + Vector3.new(0, 1, 0)
    FreeCam.enable(CFrame.lookAt(Spot.Position + Spot.LookVector * Config.CameraDistance + Vector3.new(0, 1.5, 0), Focus))

    const Missing = fetchAll(Current)
    if Missing then
        warn(`[Customize] {Missing}`)
    end
    if Copy == Made then
        rebuildAll()
    end
    Sounds.play("CustomizeEnter")
    changed()
    return true
end

function Customize.exit(Discard: boolean?): (boolean, string?)
    if not Active then
        return true, nil
    end
    Active = false
    Gizmo.detach()
    clearMarks()
    dropProxy()
    Selected = nil
    GroupSelected = nil
    Mode = "None"
    const Link = DiedLink
    DiedLink = nil
    if Link then
        Link:Disconnect()
    end
    const Model = Copy
    Copy = nil
    Marker = nil
    Hover = nil
    if Model then
        Model:Destroy()
    end
    Customize.SelectionChanged:Fire(nil)
    FreeCam.disable()
    local Ok, Problem = true, nil :: string?
    if not Discard then
        Ok, Problem = Customize.apply()
    end
    Net:Call("@Customize/Leave")
    Sounds.play("CustomizeExit")
    Customize.Exited:Fire(Ok, Problem)
    return Ok, Problem
end

function Customize.listParts(): { Entry }
    const Model = Copy
    const Made: { Entry } = {}
    if not Model then
        return Made
    end
    const Parts = Rig.bodyParts(Model)
    for _, Name in Catalog.BodyParts do
        const Part = Parts[Name]
        if Part then
            const Body = Current.Body[Name]
            const Item: Entry = {
                Id = Name,
                Name = if Body and Body.Name then Body.Name else Name,
                Kind = "Body",
                Part = Part,
                Hidden = Body ~= nil and Body.Hidden == true,
            }
            table.insert(Made, Item)
        end
    end
    const Edited: { [string]: boolean } = {}
    for _, Record in Current.Parts do
        if Record.Kind == "Default" and Record.Target then
            Edited[Record.Target] = true
        end
        if Record.Removed then
            continue
        end
        const Root = Rig.rootOf(Rig.find(Model, Record.Id))
        if Root then
            const Item: Entry = { Id = Record.Id, Name = labelOf(Record), Kind = Record.Kind, Part = Root, Group = Record.Group, Hidden = false }
            table.insert(Made, Item)
        end
    end
    for _, Child in Model:GetChildren() do
        if Child:IsA("Accessory") and not Edited[Child.Name] then
            const Handle = Child:FindFirstChild("Handle")
            if Handle and Handle:IsA("BasePart") then
                const Item: Entry = { Id = Customize.DefaultPrefix .. Child.Name, Name = Child.Name, Kind = "Default", Part = Handle, Hidden = false }
                table.insert(Made, Item)
            end
        end
    end
    return Made
end

function Customize.select(Id: string?)
    if not Active then
        return
    end
    GroupSelected = nil
    dropProxy()
    Selected = if Id and partOf(Id) then Id else nil
    if Selected then
        Sounds.play("CustomizeSelect")
    end
    refreshMarker()
    refreshGizmo()
    Customize.SelectionChanged:Fire(Selected)
end

function Customize.selected(): string?
    return Selected
end

function Customize.pickAtMouse(): string?
    const Model = Copy
    const Camera = Workspace.CurrentCamera
    if not Active or not Model or not Camera then
        return nil
    end
    const Mouse = UserInputService:GetMouseLocation()
    const Ray = Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
    const Pickable: { Instance } = {}
    for _, Entry in Customize.listParts() do
        if Entry.Kind ~= "Body" then
            table.insert(Pickable, Rig.find(Model, Entry.Id) or Entry.Part)
        end
    end
    if #Pickable == 0 then
        return nil
    end
    const Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Include
    Params.FilterDescendantsInstances = Pickable
    const Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 500, Params)
    const Hit = if Result and Result.Instance:IsA("BasePart") then Result.Instance else nil
    return if Hit then idFromHit(Hit) else nil
end

function Customize.hover(Id: string?)
    const Model = Copy
    if not Active or not Model then
        return
    end
    local Target: Instance? = nil
    if Id and Id ~= Selected then
        Target = if Format.isBody(Id) or isDefault(Id) then partOf(Id) else (Rig.find(Model, Id) or partOf(Id))
    end
    local Made = Hover
    if not Made or Made.Parent ~= Model then
        const Fresh = Instance.new("Highlight")
        Fresh.Name = "CustomizeHover"
        Fresh.FillColor = Color3.new(1, 1, 1)
        Fresh.FillTransparency = 0.88
        Fresh.OutlineColor = Color3.fromRGB(255, 214, 90)
        Fresh.OutlineTransparency = 0.35
        Fresh.DepthMode = Enum.HighlightDepthMode.Occluded
        Fresh.Enabled = false
        Fresh.Parent = Model
        Hover = Fresh
        Made = Fresh
    end
    const Light = Made :: Highlight
    if Light.Adornee ~= Target then
        Light.Adornee = Target
    end
    Light.Enabled = Target ~= nil
end

function Customize.selectAtMouse(): string?
    const Model = Copy
    const Camera = Workspace.CurrentCamera
    if not Active or not Model or not Camera then
        return nil
    end
    const Mouse = UserInputService:GetMouseLocation()
    const Ray = Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
    const Pickable: { Instance } = {}
    for _, Entry in Customize.listParts() do
        if Entry.Kind ~= "Body" then
            table.insert(Pickable, Rig.find(Model, Entry.Id) or Entry.Part)
        end
    end
    if #Pickable == 0 then
        Customize.select(nil)
        return nil
    end
    const Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Include
    Params.FilterDescendantsInstances = Pickable
    const Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 500, Params)
    const Hit = if Result and Result.Instance:IsA("BasePart") then Result.Instance else nil
    const Id = if Hit then idFromHit(Hit) else nil
    Customize.select(Id)
    return Selected
end

function Customize.setMode(Next: Mode)
    Mode = Next
    refreshGizmo()
end

function Customize.getMode(): Mode
    return Mode
end

function Customize.translate(Id: string, Delta: Vector3, Space: Space?): boolean
    const Record = editable(Id)
    const Attach = if Record then bodyPart(Record.Attach) else nil
    if not Record or not Attach then
        return false
    end
    const Frame = actualFrame(Record)
    const Moved = if Space == "World" then Frame + Attach.CFrame:VectorToObjectSpace(Delta) else Frame * CFrame.new(Delta)
    setWorld(Record, Attach.CFrame * Moved)
    changed()
    return true
end

function Customize.rotate(Id: string, Degrees: Vector3): boolean
    const Record = editable(Id)
    const Attach = if Record then bodyPart(Record.Attach) else nil
    if not Record or not Attach then
        return false
    end
    const Frame = actualFrame(Record) * CFrame.Angles(math.rad(Degrees.X), math.rad(Degrees.Y), math.rad(Degrees.Z))
    setWorld(Record, Attach.CFrame * Frame)
    changed()
    return true
end

function Customize.setScale(Id: string, Scale: Vector3): boolean
    const Record = editable(Id)
    const Model = Copy
    if not Record or not Model then
        return false
    end
    const Made = Rig.find(Model, Record.Id)
    const Clean = Format.limitScale(Scale, if Made then Rig.bound(Made) else nil)
    storeScale(Record, Clean)
    Rig.setScale(Model, Record.Id, Clean)
    changed()
    return true
end

function Customize.stretch(Id: string, Factor: Vector3): boolean
    const Record = editable(Id)
    if not Record then
        return false
    end
    return Customize.setScale(Record.Id, actualScale(Record) * Factor)
end

function Customize.attach(Id: string, Name: string, KeepWorld: boolean?): boolean
    const Record = editable(Id)
    const Target = bodyPart(Name)
    if not Record or not Target then
        return false
    end
    const Root = partOf(Record.Id)
    const World = if KeepWorld and Root then Root.CFrame else nil
    Record.Attach = Name
    if World then
        Record.Offset = Format.packFrame(Format.clampOffset(Target.CFrame:ToObjectSpace(World)))
    end
    rebuildPart(Record)
    refreshGizmo()
    changed()
    return true
end

function Customize.remove(Id: string): boolean
    if Format.isBody(Id) then
        bodyEdit(Id).Hidden = true
        rebuildBody()
    else
        const Record = editable(Id)
        if not Record then
            return false
        end
        if Record.Kind == "Default" then
            Record.Removed = true
            rebuildPart(Record)
        else
            const _, Index = recordOf(Record.Id)
            if Index then
                table.remove(Current.Parts, Index)
            end
            const Model = Copy
            if Model then
                Rig.clearPart(Model, Record.Id)
            end
        end
    end
    Sounds.play("CustomizeRemove")
    Customize.select(nil)
    changed()
    return true
end

function Customize.resetPart(Id: string): boolean
    if Format.isBody(Id) then
        Current.Body[Id] = nil
        rebuildBody()
        changed()
        return true
    end
    const Record, Index = recordOf(Id)
    if not Record or not Index then
        return false
    end
    if Record.Kind == "Default" then
        table.remove(Current.Parts, Index)
        rebuildAll()
        Customize.select(nil)
    else
        Record.Color = nil
        Record.Material = nil
        Record.Texture = nil
        Record.Scale = { 1, 1, 1 }
        rebuildPart(Record)
        refreshGizmo()
    end
    changed()
    return true
end

function Customize.addAsset(AssetId: number): (string?, string?)
    if not Active or not Copy then
        return nil, "You are not customizing"
    end
    if #Current.Parts >= Config.MaxRigParts then
        return nil, `You can only have {Config.MaxRigParts} parts`
    end
    const Source, Problem = fetch(AssetId)
    const Model = Copy
    const Handle = if Source then Source:FindFirstChild("Handle") else nil
    if not Handle or not Handle:IsA("BasePart") or not Model then
        return nil, Problem or "That item has no handle"
    end
    const Parts = Rig.bodyParts(Model)
    local Attach: BasePart? = Parts.Head
    local Offset = CFrame.new(0, 1, 0)
    for _, Child in Handle:GetChildren() do
        if not Child:IsA("Attachment") then
            continue
        end
        for _, Part in Parts do
            const Match = Part:FindFirstChild(Child.Name)
            if Match and Match:IsA("Attachment") then
                Attach = Part
                Offset = Match.CFrame * Child.CFrame:Inverse()
                break
            end
        end
        if Attach ~= Parts.Head or Offset ~= CFrame.new(0, 1, 0) then
            break
        end
    end
    if not Attach then
        return nil, "Your rig has no head"
    end
    const Record: LookPart = {
        Id = newId(),
        Kind = "Asset",
        Asset = AssetId,
        Attach = Attach.Name,
        Offset = Format.packFrame(Format.clampOffset(Offset)),
        Scale = { 1, 1, 1 },
    }
    table.insert(Current.Parts, Record)
    rebuildPart(Record)
    Sounds.play("CustomizeAdd")
    changed()
    return Record.Id, nil
end

function Customize.removeAsset(AssetId: number): number
    local Removed = 0
    for Index = #Current.Parts, 1, -1 do
        const Record = Current.Parts[Index]
        if Record.Kind == "Asset" and Record.Asset == AssetId then
            table.remove(Current.Parts, Index)
            const Model = Copy
            if Model then
                Rig.clearPart(Model, Record.Id)
            end
            if Selected == Record.Id then
                Customize.select(nil)
            end
            Removed += 1
        end
    end
    if Removed > 0 then
        changed()
    end
    return Removed
end

function Customize.hasAsset(AssetId: number): boolean
    for _, Record in Current.Parts do
        if Record.Kind == "Asset" and Record.Asset == AssetId then
            return true
        end
    end
    return false
end

function Customize.addBuiltin(Name: string): (string?, string?)
    const Definition = Catalog.part(Name)
    if not Active or not Copy then
        return nil, "You are not customizing"
    end
    if not Definition then
        return nil, `There is no built in part named {Name}`
    end
    if #Current.Parts >= Config.MaxRigParts then
        return nil, `You can only have {Config.MaxRigParts} parts`
    end
    const Base = Definition.Offset or CFrame.identity
    const Ok, Built = pcall(Definition.build)
    const Pieces: { { Name: string, Offset: CFrame } } = {}
    if Ok and Built and Built:IsA("Model") then
        const Root = Built.PrimaryPart or Built:FindFirstChildWhichIsA("BasePart", true)
        for _, Item in Built:GetDescendants() do
            if not Item:IsA("BasePart") then
                continue
            end
            local Relative = CFrame.identity
            if Item ~= Root then
                for _, Joint in Item:GetChildren() do
                    if Joint:IsA("Weld") and Joint.Part1 == Item and Joint.Part0 == Root then
                        Relative = Joint.C0
                    end
                end
            end
            table.insert(Pieces, { Name = Item.Name, Offset = Relative })
        end
    end
    if Built then
        Built:Destroy()
    end
    if #Pieces > 1 then
        if #Current.Parts + #Pieces > Config.MaxRigParts then
            return nil, `That needs {#Pieces} parts and you only have room for {Config.MaxRigParts - #Current.Parts}`
        end
        local Count = 0
        for _ in Current.Groups do
            Count += 1
        end
        if Count >= Config.MaxGroups then
            return nil, `You can only have {Config.MaxGroups} groups`
        end
        const GroupId = newId()
        Current.Groups[GroupId] = { Name = string.lower(Definition.Name) }
        for _, Piece in Pieces do
            const Record: LookPart = {
                Id = newId(),
                Kind = "Builtin",
                Builtin = Name,
                Piece = Piece.Name,
                Name = string.lower(Piece.Name),
                Group = GroupId,
                Attach = Definition.Attach,
                Offset = Format.packFrame(Format.clampOffset(Base * Piece.Offset)),
                Scale = { 1, 1, 1 },
            }
            table.insert(Current.Parts, Record)
            rebuildPart(Record)
        end
        Sounds.play("CustomizeAdd")
        changed()
        return GroupId, nil
    end
    const Record: LookPart = {
        Id = newId(),
        Kind = "Builtin",
        Builtin = Name,
        Attach = Definition.Attach,
        Offset = Format.packFrame(Format.clampOffset(Base)),
        Scale = { 1, 1, 1 },
    }
    table.insert(Current.Parts, Record)
    rebuildPart(Record)
    Sounds.play("CustomizeAdd")
    changed()
    return Record.Id, nil
end

const function paint(Id: string, Edit: (Target: any) -> ()): boolean
    if Format.isBody(Id) then
        Edit(bodyEdit(Id))
        rebuildBody()
    else
        const Record = editable(Id)
        if not Record then
            return false
        end
        Edit(Record)
        rebuildPart(Record)
        refreshGizmo()
    end
    refreshMarker()
    changed()
    return true
end

function Customize.resolveTexture(Raw: string): (string?, string?)
    const Reply = Net:Call("@Customize/Texture", Raw)
    if type(Reply) ~= "table" then
        return nil, "The server did not answer"
    end
    if not Reply.Ok or type(Reply.Template) ~= "string" then
        return nil, if type(Reply.Error) == "string" then Reply.Error else "That texture could not load"
    end
    return Reply.Template, nil
end

function Customize.setTexture(Id: string, Texture: string?): boolean
    return paint(Id, function(Target: any)
        Target.Texture = Texture or ""
    end)
end

function Customize.restoreTexture(Id: string): boolean
    return paint(Id, function(Target: any)
        Target.Texture = nil
    end)
end

function Customize.colorOf(Id: string): Color3?
    if Format.isBody(Id) then
        const Body = Current.Body[Id]
        return if Body then Format.color(Body.Color) else nil
    end
    const Record = recordOf(Id)
    if Record and Record.Color then
        return Format.color(Record.Color)
    end
    const Root = partOf(Id)
    return if Root then Root.Color else nil
end

function Customize.customColor(Id: string): Color3?
    if Format.isBody(Id) then
        const Body = Current.Body[Id]
        return if Body then Format.color(Body.Color) else nil
    end
    const Record = recordOf(Id)
    return if Record then Format.color(Record.Color) else nil
end

function Customize.clearColor(Id: string): boolean
    if Format.isBody(Id) then
        return paint(Id, function(Target: any)
            Target.Color = nil
        end)
    end
    const Record = editable(Id)
    if not Record then
        return false
    end
    Record.Color = nil
    rebuildPart(Record)
    refreshGizmo()
    refreshMarker()
    changed()
    return true
end

function Customize.setColor(Id: string, Color: Color3): boolean
    return paint(Id, function(Target: any)
        Target.Color = Format.packColor(Color)
    end)
end

function Customize.setMaterial(Id: string, Material: Enum.Material, KeepTexture: boolean?): boolean
    return paint(Id, function(Target: any)
        Target.Material = Material.Name
        if not KeepTexture then
            Target.Texture = ""
        end
    end)
end

function Customize.setSkin(Color: Color3?)
    Current.Skin = if Color then Format.packColor(Color) else nil
    rebuildBody()
    changed()
end

function Customize.swap(Key: string, Name: string?): (boolean, string?)
    const Limb = Format.limbOf(Key)
    if not Limb then
        return false, `{Key} is not a limb or body part`
    end
    if Name then
        const Definition = Catalog.swap(Name)
        if not Definition or not table.find(Definition.Limbs, Limb) then
            return false, `{Name} can not go on {Key}`
        end
    end
    if Catalog.Limbs[Key] then
        for _, Piece in Catalog.Limbs[Key] do
            Current.Swaps[Piece] = nil
        end
    end
    Current.Swaps[Key] = Name
    rebuildBody()
    refreshMarker()
    changed()
    return true, nil
end

function Customize.getSwap(Key: string): string?
    const Own = Current.Swaps[Key]
    if Own or Catalog.Limbs[Key] then
        return Own
    end
    const Limb = Format.limbOf(Key)
    return if Limb then Current.Swaps[Limb] else nil
end

function Customize.getLook(): Look
    return Format.clone(Current)
end

function Customize.getProportion(Key: string): number
    const Value = (Current :: any)[Key]
    return if type(Value) == "number" then Value else 1
end

function Customize.setProportion(Key: string, Value: number)
    const Range = Config.Proportions[Key]
    if not Range then
        return
    end
    const Clean = math.clamp(math.round(Value / Config.HeightStep) * Config.HeightStep, Range.Min, Range.Max)
    const Loose: any = Current
    Loose[Key] = if math.abs(Clean - 1) < 1e-3 then nil else Clean
    if Current.ScaleParts then
        rebuildAll()
        refreshGizmo()
    else
        rebuildOutfit()
    end
    changed()
end

function Customize.getScaleParts(): boolean
    return Current.ScaleParts == true
end

function Customize.setScaleParts(Value: boolean)
    Current.ScaleParts = if Value then true else nil
    rebuildAll()
    refreshGizmo()
    changed()
end

function Customize.getAnimation(): string
    return Current.Animation or Config.DefaultAnimation
end

function Customize.setAnimation(Id: string): boolean
    if not Catalog.animation(Id) then
        return false
    end
    Current.Animation = if Id == Config.DefaultAnimation then nil else Id
    changed()
    return true
end

function Customize.getClothing(Kind: Catalog.ClothingKind): number?
    return (Current :: any)[Kind]
end

function Customize.setClothing(Kind: Catalog.ClothingKind, Raw: (number | string)?): (boolean, string?)
    if Raw == nil then
        (Current :: any)[Kind] = nil
        rebuildOutfit()
        changed()
        return true, nil
    end
    const AssetId = Format.assetId(Raw)
    if not AssetId then
        return false, "That id is not valid"
    end
    if not Format.clothingAllowed(Kind, AssetId) then
        return false, "Pick one of the clothes from the list"
    end
    const Template, Problem = fetchClothing(Kind, AssetId)
    if not Template then
        return false, Problem
    end
    (Current :: any)[Kind] = AssetId
    rebuildOutfit()
    Sounds.play("CustomizeAdd")
    changed()
    return true, nil
end

function Customize.bodyOf(Name: string): LookBody?
    return Current.Body[Name]
end

function Customize.getSkin(): Color3?
    return Format.color(Current.Skin)
end

function Customize.setHidden(Id: string, Hidden: boolean): boolean
    if not Format.isBody(Id) then
        return if Hidden then Customize.remove(Id) else false
    end
    bodyEdit(Id).Hidden = if Hidden then true else nil
    rebuildBody()
    refreshMarker()
    changed()
    return true
end

function Customize.nameOf(Id: string): string
    if Format.isBody(Id) then
        const Body = Current.Body[Id]
        return if Body and Body.Name then Body.Name else Id
    end
    const Record = recordOf(Id)
    if Record then
        return labelOf(Record)
    end
    if isDefault(Id) then
        return string.sub(Id, #Customize.DefaultPrefix + 1)
    end
    return Id
end

function Customize.kindOf(Id: string): Kind?
    if Format.isBody(Id) then
        return "Body"
    end
    const Record = recordOf(Id)
    if Record then
        return Record.Kind
    end
    return if isDefault(Id) then "Default" else nil
end

function Customize.attachOf(Id: string): string?
    if Format.isBody(Id) then
        return Id
    end
    const Record = recordOf(Id)
    if Record then
        return Record.Attach
    end
    const Root = partOf(Id)
    const Target = if Root then weldTarget(Root) else nil
    return if Target then Target.Name else nil
end

function Customize.textureOf(Id: string): string?
    if Format.isBody(Id) then
        const Body = Current.Body[Id]
        return if Body then Body.Texture else nil
    end
    const Record = recordOf(Id)
    return if Record then Record.Texture else nil
end

function Customize.rename(Id: string, Name: string?): boolean
    const Clean = Format.cleanName(Name)
    if Format.isBody(Id) then
        bodyEdit(Id).Name = Clean
    else
        const Record = editable(Id)
        if not Record then
            return false
        end
        Record.Name = Clean
    end
    changed()
    return true
end

function Customize.groups(): { GroupInfo }
    const Made: { GroupInfo } = {}
    for Id, Group in Current.Groups do
        const Members: { string } = {}
        for _, Record in membersOf(Id) do
            table.insert(Members, Record.Id)
        end
        table.insert(Made, { Id = Id, Name = Group.Name, Code = Group.Code, Members = Members })
    end
    table.sort(Made, function(A: GroupInfo, B: GroupInfo): boolean
        return A.Name < B.Name
    end)
    return Made
end

function Customize.group(Ids: { string }, Name: string?): (string?, string?)
    if not Active then
        return nil, "You are not customizing"
    end
    local Count = 0
    for _ in Current.Groups do
        Count += 1
    end
    if Count >= Config.MaxGroups then
        return nil, `You can only have {Config.MaxGroups} groups`
    end
    const GroupId = newId()
    const Records: { LookPart } = {}
    for _, Id in Ids do
        if Format.isBody(Id) then
            continue
        end
        const Record = editable(Id)
        if Record then
            table.insert(Records, Record)
        end
    end
    if #Records == 0 then
        return nil, "Pick some rig parts first, body parts can not be grouped"
    end
    Current.Groups[GroupId] = { Name = Format.cleanName(Name) or `group {Count + 1}` }
    for _, Record in Records do
        Record.Group = GroupId
    end
    changed()
    return GroupId, nil
end

function Customize.groupOf(Id: string): string?
    const Record = recordOf(Id)
    return if Record then Record.Group else nil
end

function Customize.addToGroup(Ids: { string }, GroupId: string): boolean
    if not Current.Groups[GroupId] then
        return false
    end
    local Added = false
    for _, Id in Ids do
        if Format.isBody(Id) then
            continue
        end
        const Record = editable(Id)
        if Record then
            Record.Group = GroupId
            Added = true
        end
    end
    if Added then
        changed()
    end
    return Added
end

function Customize.leaveGroup(Id: string): boolean
    const Record = recordOf(Id)
    const GroupId = if Record then Record.Group else nil
    if not Record or not GroupId then
        return false
    end
    Record.Group = nil
    if #membersOf(GroupId) == 0 then
        Current.Groups[GroupId] = nil
        if GroupSelected == GroupId then
            Customize.select(nil)
        end
    end
    changed()
    return true
end

function Customize.ungroup(GroupId: string)
    if not Current.Groups[GroupId] then
        return
    end
    Current.Groups[GroupId] = nil
    for _, Record in Current.Parts do
        if Record.Group == GroupId then
            Record.Group = nil
        end
    end
    if GroupSelected == GroupId then
        Customize.select(nil)
    end
    changed()
end

function Customize.renameGroup(GroupId: string, Name: string?): boolean
    const Group = Current.Groups[GroupId]
    if not Group then
        return false
    end
    Group.Name = Format.cleanName(Name) or Group.Name
    changed()
    return true
end

function Customize.groupName(GroupId: string): string?
    const Group = Current.Groups[GroupId]
    return if Group then Group.Name else nil
end

function Customize.selectGroup(GroupId: string?)
    if not Active then
        return
    end
    Gizmo.detach()
    Selected = nil
    GroupSelected = if GroupId and Current.Groups[GroupId] then GroupId else nil
    dropProxy()
    refreshMarker()
    refreshGizmo()
    if GroupSelected then
        Sounds.play("CustomizeSelect")
    end
    Customize.SelectionChanged:Fire(nil)
end

function Customize.selectedGroup(): string?
    return GroupSelected
end

const function copyRecord(Record: LookPart, Group: string?, Rename: boolean): LookPart
    const Made = table.clone(Record)
    Made.Id = newId()
    Made.Offset = table.clone(Record.Offset)
    Made.Scale = table.clone(Record.Scale)
    Made.Color = if Record.Color then table.clone(Record.Color) else nil
    Made.Group = Group
    if Rename then
        Made.Name = Format.cleanName(`{labelOf(Record)} copy`)
    end
    return Made
end

function Customize.duplicate(Id: string): (string?, string?)
    if not Active or not Copy then
        return nil, "You are not customizing"
    end
    if Format.isBody(Id) then
        return nil, "Body parts can not be copied"
    end
    if #Current.Parts >= Config.MaxRigParts then
        return nil, `You can only have {Config.MaxRigParts} parts`
    end
    const Record = editable(Id)
    if not Record then
        return nil, "That part can not be copied"
    end
    const Made = copyRecord(Record, Record.Group, true)
    table.insert(Current.Parts, Made)
    rebuildPart(Made)
    Sounds.play("CustomizeAdd")
    changed()
    return Made.Id, nil
end

function Customize.duplicateGroup(GroupId: string): (string?, string?)
    if not Active or not Copy then
        return nil, "You are not customizing"
    end
    const Group = Current.Groups[GroupId]
    if not Group then
        return nil, "That group does not exist"
    end
    const Members = membersOf(GroupId)
    if #Current.Parts + #Members > Config.MaxRigParts then
        return nil, `That would go over {Config.MaxRigParts} parts`
    end
    local Count = 0
    for _ in Current.Groups do
        Count += 1
    end
    if Count >= Config.MaxGroups then
        return nil, `You can only have {Config.MaxGroups} groups`
    end
    const NewId = newId()
    Current.Groups[NewId] = { Name = Format.cleanName(`{Group.Name} copy`) or "group copy" }
    for _, Record in Members do
        const Made = copyRecord(Record, NewId, false)
        table.insert(Current.Parts, Made)
        rebuildPart(Made)
    end
    Sounds.play("CustomizeAdd")
    changed()
    return NewId, nil
end

function Customize.removeMany(Ids: { string }): number
    local Removed = 0
    for _, Id in Ids do
        if Customize.remove(Id) then
            Removed += 1
        end
    end
    return Removed
end

function Customize.removeGroup(GroupId: string): number
    const Ids: { string } = {}
    for _, Record in membersOf(GroupId) do
        table.insert(Ids, Record.Id)
    end
    Current.Groups[GroupId] = nil
    const Removed = Customize.removeMany(Ids)
    if GroupSelected == GroupId then
        Customize.select(nil)
    end
    changed()
    return Removed
end

function Customize.mark(Ids: { string })
    clearMarks()
    const Model = Copy
    if not Active or not Model then
        return
    end
    for _, Id in Ids do
        const Root = partOf(Id)
        if not Root then
            continue
        end
        const Box = Instance.new("SelectionBox")
        Box.Name = "CustomizeMark"
        Box.Adornee = if Format.isBody(Id) or isDefault(Id) then Root else (Rig.find(Model, Id) or Root) :: any
        Box.Color3 = Color3.fromRGB(255, 214, 90)
        Box.LineThickness = 0.03
        Box.SurfaceTransparency = 1
        Box.Parent = Model
        Marks[Id] = Box
    end
end

function Customize.loadLook(Given: Look): (boolean, string?)
    const Clean, Problem = Format.sanitize(Given)
    if not Clean then
        return false, Problem
    end
    const Missing = fetchAll(Clean)
    if Missing then
        return false, Missing
    end
    Current = Clean
    if Active then
        Customize.select(nil)
        rebuildAll()
    end
    changed()
    return true, nil
end

function Customize.reset()
    Current = Format.empty()
    if Active then
        Customize.select(nil)
        rebuildAll()
    end
    changed()
end

function Customize.apply(): (boolean, string?)
    const Reply = Net:Call("@Customize/Apply", Current)
    if type(Reply) ~= "table" then
        return false, "The server did not answer"
    end
    if not Reply.Ok then
        return false, if type(Reply.Error) == "string" then Reply.Error else "That look could not be applied"
    end
    Applied = Format.clone(if type(Reply.Look) == "table" then Reply.Look else Current)
    Sounds.play("CustomizeApply")
    return true, nil
end

function Customize.clearApplied(): (boolean, string?)
    const Reply = Net:Call("@Customize/Reset")
    if type(Reply) ~= "table" or not Reply.Ok then
        return false, if type(Reply) == "table" and type(Reply.Error) == "string" then Reply.Error else "That could not be reset"
    end
    Applied = nil
    return true, nil
end

function Customize.saves(): { [string]: LookSave }
    return Saves
end

function Customize.save(Slot: number, Name: string?): (boolean, string?)
    const Reply = Net:Call("@Customize/Save", Slot, Current, Name)
    if type(Reply) ~= "table" then
        return false, "The server did not answer"
    end
    if not Reply.Ok then
        return false, if type(Reply.Error) == "string" then Reply.Error else "That look could not be saved"
    end
    if type(Reply.Save) == "table" then
        Saves[tostring(Slot)] = Reply.Save
    end
    return true, nil
end

function Customize.renameSave(Slot: number, Name: string): (boolean, string?)
    const Reply = Net:Call("@Customize/RenameSave", Slot, Name)
    if type(Reply) ~= "table" or not Reply.Ok then
        return false, if type(Reply) == "table" and type(Reply.Error) == "string" then Reply.Error else "That name could not be saved"
    end
    if type(Reply.Save) == "table" then
        Saves[tostring(Slot)] = Reply.Save
    end
    return true, nil
end

function Customize.shareGroup(GroupId: string): (string?, string?)
    const Group = Current.Groups[GroupId]
    if not Group then
        return nil, "That group does not exist"
    end
    const Shared = membersOf(GroupId)
    if #Shared == 0 then
        return nil, "That group is empty"
    end
    const Reply = Net:Call("@Customize/Share", Group.Name, Shared)
    if type(Reply) ~= "table" then
        return nil, "The server did not answer"
    end
    if not Reply.Ok or type(Reply.Code) ~= "string" then
        return nil, if type(Reply.Error) == "string" then Reply.Error else "That group could not be shared"
    end
    const Skipped = if type(Reply.Skipped) == "number" then Reply.Skipped else 0
    const Still = Current.Groups[GroupId]
    if Still then
        Still.Code = Reply.Code
        changed()
    end
    return Reply.Code, if Skipped > 0 then `{Skipped} parts could not be shared` else nil
end

function Customize.unshareGroup(GroupId: string): (boolean, string?)
    const Group = Current.Groups[GroupId]
    const Code = if Group then Group.Code else nil
    if not Group or not Code then
        return false, "That group is not shared"
    end
    const Reply = Net:Call("@Customize/Unshare", Code)
    if type(Reply) ~= "table" then
        return false, "The server did not answer"
    end
    if not Reply.Ok then
        return false, if type(Reply.Error) == "string" then Reply.Error else "That code could not be removed"
    end
    const Still = Current.Groups[GroupId]
    if Still then
        Still.Code = nil
        changed()
    end
    return true, nil
end

function Customize.importCode(Code: string): (boolean, string?)
    if not Active or not Copy then
        return false, "You are not customizing"
    end
    const Reply = Net:Call("@Customize/Import", Code)
    if type(Reply) ~= "table" then
        return false, "The server did not answer"
    end
    if not Reply.Ok or type(Reply.Share) ~= "table" then
        return false, if type(Reply.Error) == "string" then Reply.Error else "That code did not work"
    end
    const Clean, Problem = Format.sanitize({
        Version = Config.LookVersion,
        Parts = Reply.Share.Parts,
        Groups = { Shared = { Name = Reply.Share.Name } },
    })
    if not Clean or #Clean.Parts == 0 then
        return false, Problem or "That code has no parts"
    end
    if #Current.Parts + #Clean.Parts > Config.MaxRigParts then
        return false, `That would go over {Config.MaxRigParts} parts`
    end
    local Count = 0
    for _ in Current.Groups do
        Count += 1
    end
    if Count >= Config.MaxGroups then
        return false, `You can only have {Config.MaxGroups} groups`
    end
    const Missing = fetchAll(Clean)
    if Missing then
        return false, Missing
    end
    if not Active then
        return false, "You stopped customizing"
    end
    const GroupId = newId()
    Current.Groups[GroupId] = { Name = Clean.Groups.Shared.Name }
    for _, Record in Clean.Parts do
        Record.Id = newId()
        Record.Group = GroupId
        table.insert(Current.Parts, Record)
        rebuildPart(Record)
    end
    Sounds.play("CustomizeAdd")
    changed()
    return true, nil
end

function Customize.loadSave(Slot: number): (boolean, string?)
    const Save = Saves[tostring(Slot)]
    if not Save then
        return false, "That save slot is empty"
    end
    return Customize.loadLook(Save.Look)
end

function Customize.clearSave(Slot: number): (boolean, string?)
    const Reply = Net:Call("@Customize/ClearSave", Slot)
    if type(Reply) ~= "table" or not Reply.Ok then
        return false, if type(Reply) == "table" and type(Reply.Error) == "string" then Reply.Error else "That slot could not be cleared"
    end
    Saves[tostring(Slot)] = nil
    return true, nil
end

function Customize.start()
    if Started then
        return
    end
    Started = true
    Net:On("@Customize/State", function(State: any)
        if type(State) ~= "table" then
            return
        end
        Applied = if type(State.Look) == "table" then (Format.sanitize(State.Look)) else nil
        table.clear(Saves)
        if type(State.Saves) == "table" then
            for Key, Save in State.Saves do
                if type(Key) == "string" and type(Save) == "table" then
                    Saves[Key] = Save
                end
            end
        end
    end)
end

return Customize
