--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Workspace = game:GetService("Workspace")

const PropData = require(ReplicatedStorage.Shared.PropData)
const Zones = require(script.Parent.Zones)

type Held = {
    Box: PropData.ServerBox,
    Spec: PropData.ServerBoxSpec,
    Record: Zones.Record,
    Extent: Vector3,
    Offset: CFrame,
    Warned: boolean,
}

type Extent = {
    Size: Vector3,
    Offset: CFrame,
}

const Boxes = {
    FolderName = "ServerBoxes",
}

const Held: { [string]: Held } = {}
const Extents: { [number]: Extent } = {}
local Folder: Folder? = nil
local ModelOf: ((Id: number) -> Instance?)? = nil
local Started = false

const function folder(): Folder
    const Existing = Folder
    if Existing and Existing.Parent then
        return Existing
    end
    const Made = Instance.new("Folder")
    Made.Name = Boxes.FolderName
    Made.Parent = Workspace
    Folder = Made
    return Made
end

const function extentOf(Id: number): Extent
    const Known = Extents[Id]
    if Known then
        return Known
    end
    const Model = if ModelOf then ModelOf(Id) else nil
    local Made: Extent = { Size = Vector3.new(2, 2, 2), Offset = CFrame.identity }
    if Model and Model:IsA("Model") then
        const Frame, Size = Model:GetBoundingBox()
        Made = { Size = Size, Offset = Model:GetPivot():ToObjectSpace(Frame) }
    elseif Model and Model:IsA("BasePart") then
        Made = { Size = Model.Size, Offset = CFrame.identity }
    end
    Extents[Id] = Made
    return Made
end

const function restOf(Entry: Held): CFrame
    const Scale = Entry.Record.Scale
    return Entry.Record.Pivot * CFrame.new(Entry.Offset.Position * Scale) * Entry.Offset.Rotation
end

const function moveTo(Self: PropData.ServerBox, Frame: CFrame)
    const Part = Self.Part
    const Last = Part.CFrame
    Part.CFrame = Frame
    if Self.Delta > 0 then
        Part.AssemblyLinearVelocity = (Frame.Position - Last.Position) / Self.Delta
    end
end

const function create(Record: Zones.Record, Spec: PropData.ServerBoxSpec): Held
    const Extent = extentOf(Record.Id)
    const Part = Instance.new("Part")
    Part.Name = Record.Key
    Part.Anchored = true
    Part.CanCollide = Spec.CanCollide ~= false
    Part.CanTouch = true
    Part.CanQuery = false
    Part.CastShadow = false
    Part.Transparency = if Spec.Visible then 0.6 else 1
    Part.Shape = Spec.Shape or Enum.PartType.Block
    Part.TopSurface = Enum.SurfaceType.Smooth
    Part.BottomSurface = Enum.SurfaceType.Smooth
    Part:SetAttribute("PropKey", Record.Key)
    Part:SetAttribute("PropOwner", Record.Owner)
    const Box: PropData.ServerBox = {
        Part = Part :: BasePart,
        Rest = CFrame.identity,
        Prop = Record :: PropData.ServerProp,
        Data = {},
        Delta = 0,
        moveTo = moveTo,
    }
    const Made: Held = {
        Box = Box,
        Spec = Spec,
        Record = Record,
        Extent = Spec.Size or Extent.Size,
        Offset = Spec.Offset or Extent.Offset,
        Warned = false,
    }
    Held[Record.Key] = Made
    return Made
end

function Boxes.sync(Record: Zones.Record)
    const Found = PropData.definition(Record.Id)
    const Spec = if Found then Found.ServerBox else nil
    if not Spec then
        return
    end
    const Entry = Held[Record.Key] or create(Record, Spec)
    const Box = Entry.Box
    const Part = Box.Part
    const Size: Vector3 = Entry.Extent * Record.Scale
    Box.Rest = restOf(Entry)
    Part.Size = Size
    Part.CFrame = Box.Rest
    Part.AssemblyLinearVelocity = Vector3.zero
    Part:SetAttribute("PropOffset", Box.Rest:ToObjectSpace(Record.Pivot))
    if Part.Parent == nil then
        Part.Parent = folder()
    end
end

function Boxes.remove(Key: string)
    const Entry = Held[Key]
    if not Entry then
        return
    end
    Held[Key] = nil
    Entry.Box.Part:Destroy()
    table.clear(Entry.Box.Data)
end

function Boxes.get(Key: string): PropData.ServerBox?
    const Entry = Held[Key]
    return if Entry then Entry.Box else nil
end

function Boxes.start(Resolve: (Id: number) -> Instance?)
    if Started then
        return
    end
    Started = true
    ModelOf = Resolve
    RunService.Heartbeat:Connect(function(Delta: number)
        const Now = Workspace:GetServerTimeNow()
        for _, Entry in Held do
            const Step = Entry.Spec.step
            if not Step then
                continue
            end
            Entry.Box.Delta = Delta
            const Ok, Problem = pcall(Step, Entry.Box, Now, Delta)
            if not Ok and not Entry.Warned then
                Entry.Warned = true
                warn(`[ServerBox] step failed for prop {Entry.Record.Id}: {Problem}`)
            end
        end
    end)
end

return Boxes
