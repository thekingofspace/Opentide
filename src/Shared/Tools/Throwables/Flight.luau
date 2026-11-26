--!strict
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const Workspace = game:GetService("Workspace")

const Tools = require(script.Parent.Parent)

export type Kind = {
    Gravity: number,
    Spin: number,
    Speed: number,
    MinTime: number,
    MaxTime: number,
}

export type Throw = {
    Thrower: Player?,
    Slot: string,
    Build: ToolBuild,
    Kind: string,
    Origin: Vector3,
    Velocity: Vector3,
    Time: number,
    Drop: number?,
    Rest: CFrame?,
}

export type Bounds = {
    Center: Vector3,
    Size: Vector3,
}

type Visual = {
    Key: string,
    Throw: Throw,
    Started: number,
    Model: Model?,
    Bounds: Bounds?,
    Landed: boolean,
    Tried: number,
}

const Flight = {
    FolderName = "Thrown",
    TipName = "ThrowTip",
    Step = 1 / 60,
    Overlap = 0.1,
    Limit = 4,
    Blend = 0.12,
    Glance = 0.45,
    DropReach = 60,
    RetryAfter = 0.5,
    Kinds = {
        Toss = { Gravity = 20, Spin = 0, Speed = 110, MinTime = 0.03, MaxTime = 2 },
        Arc = { Gravity = 80, Spin = 14, Speed = 50, MinTime = 0.45, MaxTime = 1.5 },
    } :: { [string]: Kind },
}

const Visuals: { [string]: Visual } = {}
local Folder: Folder? = nil
local Started = false

function Flight.key(Thrower: Player?, Slot: string): string
    return `{if Thrower then Thrower.UserId else 0}:{Slot}`
end

function Flight.folder(): Folder
    const Known = Folder
    if Known and Known.Parent then
        return Known
    end
    const Made = Instance.new("Folder")
    Made.Name = Flight.FolderName
    Made.Parent = Workspace
    Folder = Made
    return Made
end

function Flight.bounds(Model: Model): Bounds
    const Box, Size = Model:GetBoundingBox()
    return {
        Center = Model:GetPivot():PointToObjectSpace(Box.Position),
        Size = Size,
    }
end

function Flight.tip(Model: Model, Bounds: Bounds): CFrame
    const Found = Model:FindFirstChild(Flight.TipName, true)
    if Found and Found:IsA("Attachment") then
        const Local: CFrame = Model:GetPivot():Inverse() * Found.WorldCFrame
        return Local
    end
    return CFrame.new(Bounds.Center + Vector3.new(0, Bounds.Size.Y / 2, 0)) * CFrame.Angles(math.rad(90), 0, 0)
end

function Flight.point(Throw: Throw, Kind: Kind, Time: number): Vector3
    return Throw.Origin + Throw.Velocity * Time + Vector3.new(0, -0.5 * Kind.Gravity * Time * Time, 0)
end

function Flight.speed(Throw: Throw, Kind: Kind, Time: number): Vector3
    return Throw.Velocity + Vector3.new(0, -Kind.Gravity * Time, 0)
end

const function sideOf(Velocity: Vector3): Vector3
    const Flat = Vector3.new(Velocity.X, 0, Velocity.Z)
    if Flat.Magnitude < 1e-3 then
        return Vector3.xAxis
    end
    return Flat.Unit:Cross(Vector3.yAxis)
end

const function along(Direction: Vector3, Side: Vector3): CFrame
    const Y = if Direction.Magnitude > 1e-4 then Direction.Unit else Vector3.yAxis
    local X = Side - Y * Side:Dot(Y)
    if X.Magnitude < 1e-4 then
        X = Y:Cross(Vector3.zAxis)
        if X.Magnitude < 1e-4 then
            X = Vector3.xAxis
        end
    end
    X = X.Unit
    return CFrame.fromMatrix(Vector3.zero, X, Y, X:Cross(Y))
end

function Flight.turn(Throw: Throw, Kind: Kind, Time: number): CFrame
    const Side = sideOf(Throw.Velocity)
    if Kind.Spin == 0 then
        return along(Flight.speed(Throw, Kind, Time), Side)
    end
    return CFrame.fromAxisAngle(Side, -Kind.Spin * Time) * along(Throw.Velocity, Side)
end

function Flight.plan(Kind: Kind, Origin: Vector3, Target: Vector3, Speed: number): Vector3
    const Gap = Target - Origin
    const Time = math.clamp(Gap.Magnitude / math.max(Speed, 1), Kind.MinTime, Kind.MaxTime)
    return (Gap - Vector3.new(0, -0.5 * Kind.Gravity * Time * Time, 0)) / Time
end

function Flight.stick(Hit: Vector3, Normal: Vector3, Direction: Vector3, Velocity: Vector3, Tip: CFrame, Embed: number, Square: number): CFrame
    local Into = Direction.Unit:Lerp(-Normal, math.clamp(Square, 0, 1))
    Into = if Into.Magnitude > 1e-4 then Into.Unit else -Normal
    if Into:Dot(-Normal) < Flight.Glance then
        Into = (Into - Normal * 1.2).Unit
    end
    const Local = Tip.LookVector
    local LocalX = Vector3.xAxis - Local * Local.X
    if LocalX.Magnitude < 1e-4 then
        LocalX = Vector3.zAxis - Local * Local.Z
    end
    LocalX = LocalX.Unit
    const Side = sideOf(Velocity)
    local WorldX = Side - Into * Side:Dot(Into)
    if WorldX.Magnitude < 1e-4 then
        WorldX = Into:Cross(Vector3.yAxis)
        if WorldX.Magnitude < 1e-4 then
            WorldX = Vector3.xAxis
        end
    end
    WorldX = WorldX.Unit
    const From = CFrame.fromMatrix(Vector3.zero, LocalX, Local, LocalX:Cross(Local))
    const To = CFrame.fromMatrix(Vector3.zero, WorldX, Into, WorldX:Cross(Into))
    const Rotation = To * From:Inverse()
    return CFrame.new(Hit + Into * Embed - Rotation:VectorToWorldSpace(Tip.Position)) * Rotation
end

function Flight.lie(Ground: Vector3, Normal: Vector3, Direction: Vector3, Bounds: Bounds): CFrame
    local Flat = Direction - Normal * Direction:Dot(Normal)
    if Flat.Magnitude < 1e-3 then
        Flat = Normal:Cross(Vector3.xAxis)
        if Flat.Magnitude < 1e-3 then
            Flat = Normal:Cross(Vector3.zAxis)
        end
    end
    Flat = Flat.Unit
    const Rotation = CFrame.fromMatrix(Vector3.zero, Normal, Flat, Normal:Cross(Flat))
    const Low = Bounds.Center.X - Bounds.Size.X / 2
    return CFrame.new(Ground - Normal * Low) * Rotation
end

const function bodyOf(Part: Instance): Model?
    local Here = Part:FindFirstAncestorOfClass("Model")
    while Here do
        if Here:FindFirstChildOfClass("Humanoid") then
            return Here
        end
        Here = Here:FindFirstAncestorOfClass("Model")
    end
    return nil
end

function Flight.solve(KindName: string, Origin: Vector3, Velocity: Vector3, Tip: CFrame, Bounds: Bounds, Skip: { Instance }, Embed: number, Square: number): (number, number?, CFrame?)
    const Kind = Flight.Kinds[KindName]
    const Probe: Throw = {
        Thrower = nil,
        Slot = "",
        Build = { Tool = "", Parts = {} },
        Kind = KindName,
        Origin = Origin,
        Velocity = Velocity,
        Time = 0,
    }
    const Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = Skip
    Params.RespectCanCollide = true
    local Last = Origin
    local Time = 0
    while Time < Flight.Limit do
        const Next = math.min(Time + Flight.Step, Flight.Limit)
        const Point = Flight.point(Probe, Kind, Next)
        const Gap = (Point - Last).Magnitude
        const Reach = if Gap > 0 then (Point - Last) * ((Gap + Flight.Overlap) / Gap) else Vector3.zero
        const Hit = if Gap > 0 then Workspace:Raycast(Last, Reach, Params) else nil
        if Hit then
            const At = Time + (Next - Time) * math.min((Hit.Position - Last).Magnitude / Gap, 1)
            const Direction = Flight.speed(Probe, Kind, At)
            const Body = bodyOf(Hit.Instance)
            if not Body then
                return At, nil, Flight.stick(Hit.Position, Hit.Normal, Direction, Velocity, Tip, Embed, Square)
            end
            const Ignore = table.clone(Skip)
            table.insert(Ignore, Body)
            for _, Other in Players:GetPlayers() do
                if Other.Character then
                    table.insert(Ignore, Other.Character)
                end
            end
            const Floor = RaycastParams.new()
            Floor.FilterType = Enum.RaycastFilterType.Exclude
            Floor.FilterDescendantsInstances = Ignore
            Floor.RespectCanCollide = true
            const From = Hit.Position - Direction.Unit * 0.3
            const Ground = Workspace:Raycast(From, Vector3.new(0, -Flight.DropReach, 0), Floor)
            if not Ground then
                return At, nil, nil
            end
            const Height = math.max(From.Y - Ground.Position.Y, 0)
            const Fall = math.max(math.sqrt(2 * Height / math.max(Workspace.Gravity, 1)), 0.1)
            return At, Fall, Flight.lie(Ground.Position, Ground.Normal, Direction, Bounds)
        end
        Last = Point
        Time = Next
    end
    return Flight.Limit, nil, nil
end

function Flight.pose(Throw: Throw, Bounds: Bounds, Elapsed: number): (CFrame, boolean)
    const Kind = Flight.Kinds[Throw.Kind] or Flight.Kinds.Toss
    const Center = Bounds.Center
    const Rest = Throw.Rest
    const function place(Point: Vector3, Turn: CFrame): CFrame
        return CFrame.new(Point) * Turn * CFrame.new(-Center)
    end
    const Drop = Throw.Drop
    if Elapsed >= Throw.Time + (Drop or 0) then
        if Rest then
            return Rest, true
        end
        return place(Flight.point(Throw, Kind, Throw.Time), Flight.turn(Throw, Kind, Throw.Time)), true
    end
    if Elapsed <= Throw.Time then
        local Point = Flight.point(Throw, Kind, Elapsed)
        local Turn = Flight.turn(Throw, Kind, Elapsed)
        if Rest and not Drop then
            const Window = math.min(Flight.Blend, Throw.Time * 0.5)
            const Alpha = if Window > 0 then math.clamp((Elapsed - (Throw.Time - Window)) / Window, 0, 1) else 1
            if Alpha > 0 then
                Point = Point:Lerp(Rest:PointToWorldSpace(Center), Alpha)
                Turn = Turn:Lerp(Rest.Rotation, Alpha)
            end
        end
        return place(Point, Turn), false
    end
    const Start = Flight.point(Throw, Kind, Throw.Time)
    const Begin = Flight.turn(Throw, Kind, Throw.Time)
    const Final = Rest or CFrame.new(Start)
    const Progress = math.clamp((Elapsed - Throw.Time) / math.max(Drop or 0, 1e-3), 0, 1)
    return place(Start:Lerp(Final:PointToWorldSpace(Center), Progress * Progress), Begin:Lerp(Final.Rotation, Progress)), false
end

const Shown: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

function Flight.conceal(Model: Model, On: boolean)
    for _, Item in Model:GetDescendants() do
        if not Item:IsA("BasePart") and not Item:IsA("Decal") then
            continue
        end
        const Piece = Item :: BasePart | Decal
        if On then
            if Shown[Piece] == nil then
                Shown[Piece] = Piece.Transparency
            end
            Piece.Transparency = 1
        elseif Shown[Piece] ~= nil then
            Piece.Transparency = Shown[Piece]
            Shown[Piece] = nil
        end
    end
end

const function build(Visual: Visual): boolean
    if Visual.Model then
        return true
    end
    const Now = os.clock()
    if Now - Visual.Tried < Flight.RetryAfter then
        return false
    end
    Visual.Tried = Now
    const Made = Tools.assemble(Visual.Throw.Build)
    const Root = if Made then Made.PrimaryPart else nil
    if not Made or not Root then
        if Made then
            Made:Destroy()
        end
        return false
    end
    Root.Anchored = true
    Made.Name = `Thrown_{Visual.Key}`
    Visual.Bounds = Flight.bounds(Made)
    Visual.Model = Made
    Made.Parent = Flight.folder()
    return true
end

const function land(Visual: Visual)
    Visual.Landed = true
    const Rest = Visual.Throw.Rest
    const Model = Visual.Model
    if not Rest then
        Visuals[Visual.Key] = nil
        if Model then
            Model:Destroy()
        end
        return
    end
    if Model then
        Model:PivotTo(Rest)
    end
end

const function step()
    const Now = os.clock()
    for _, Visual in Visuals do
        if Visual.Landed or not build(Visual) then
            continue
        end
        const Model = Visual.Model :: Model
        const Frame, Done = Flight.pose(Visual.Throw, Visual.Bounds :: Bounds, Now - Visual.Started)
        if Done then
            land(Visual)
        else
            Model:PivotTo(Frame)
        end
    end
end

function Flight.launch(Throw: Throw, Started: number)
    const Key = Flight.key(Throw.Thrower, Throw.Slot)
    Flight.remove(Throw.Thrower, Throw.Slot)
    const Visual: Visual = {
        Key = Key,
        Throw = Throw,
        Started = Started,
        Model = nil,
        Bounds = nil,
        Landed = false,
        Tried = -math.huge,
    }
    Visuals[Key] = Visual
    build(Visual)
end

function Flight.remove(Thrower: Player?, Slot: string)
    const Key = Flight.key(Thrower, Slot)
    const Visual = Visuals[Key]
    if not Visual then
        return
    end
    const Model = Visual.Model
    Visuals[Key] = nil
    if Model then
        Model:Destroy()
    end
end

function Flight.clear(Thrower: Player)
    const Prefix = `{Thrower.UserId}:`
    for Key, Visual in Visuals do
        if string.sub(Key, 1, #Prefix) == Prefix then
            Flight.remove(Thrower, Visual.Throw.Slot)
        end
    end
end

function Flight.start()
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    RunService.RenderStepped:Connect(step)
end

return Flight
