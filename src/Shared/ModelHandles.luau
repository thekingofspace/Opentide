--!strict
const GuiService = game:GetService("GuiService")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

export type DragCode = "Handles" | "HitMouseTranslate" | "MouseRotate" | "None"
export type HandleKind = "Translate" | "Rotate" | "Scale"
export type Space = "World" | "Local"
export type Axis = "X" | "Y" | "Z"

export type Settings = {
	DragCode: DragCode?,
	HandleKind: HandleKind?,
	Space: Space?,
	RotateAxis: Axis?,
	TranslateIncrement: number?,
	RotateIncrement: number?,
	ScaleIncrement: number?,
	IgnoreList: { Instance }?,
	Blockers: { GuiObject }?,
	MinScale: number?,
	MaxScale: number?,
}

const DragCodes = table.freeze({
	Handles = "Handles" :: "Handles",
	HitMouseTranslate = "HitMouseTranslate" :: "HitMouseTranslate",
	MouseRotate = "MouseRotate" :: "MouseRotate",
	None = "None" :: "None",
})

const HandleKinds = table.freeze({
	Translate = "Translate" :: "Translate",
	Rotate = "Rotate" :: "Rotate",
	Scale = "Scale" :: "Scale",
})

const Spaces = table.freeze({
	World = "World" :: "World",
	Local = "Local" :: "Local",
})

const AxisNames = table.freeze({
	X = "X" :: "X",
	Y = "Y" :: "Y",
	Z = "Z" :: "Z",
})

const ModelHandles = {
	DragCodes = DragCodes,
	HandleKinds = HandleKinds,
	Spaces = Spaces,
	Axes = AxisNames,
}

const AxisVectors: { [Axis]: Vector3 } = {
	X = Vector3.xAxis,
	Y = Vector3.yAxis,
	Z = Vector3.zAxis,
}

const RayLength = 4096
const MinimumScale = 0.01
const MaxDrag = 512
const ParallelLimit = 0.02
const MinimumSize = Vector3.one * 0.05
const DialDeadzone = 6
const TrustStart = 0.15
const TrustRange = 0.25

export type Connection = {
	Connected: boolean,
	Disconnect: (Self: Connection) -> (),
}

export type ChangedSignal = {
	Connect: (Self: ChangedSignal, Callback: (Pivot: CFrame, Scale: number) -> ()) -> Connection,
	Once: (Self: ChangedSignal, Callback: (Pivot: CFrame, Scale: number) -> ()) -> Connection,
}

type Listener = {
	Callback: ((Pivot: CFrame, Scale: number) -> ())?,
	Once: boolean,
	Link: Connection,
}

const function createSignal(): (ChangedSignal, (Pivot: CFrame, Scale: number) -> (), () -> ())
	const Listeners: { Listener } = {}
	local Dead = false

	const function drop(Entry: Listener)
		Entry.Callback = nil
		Entry.Link.Connected = false
		const Index = table.find(Listeners, Entry)
		if Index then
			table.remove(Listeners, Index)
		end
	end

	const function listen(Callback: (Pivot: CFrame, Scale: number) -> (), Once: boolean): Connection
		const Entry: Listener = {
			Callback = if Dead then nil else Callback,
			Once = Once,
			Link = nil :: any,
		}
		Entry.Link = {
			Connected = not Dead,
			Disconnect = function(_: Connection)
				drop(Entry)
			end,
		}
		if not Dead then
			table.insert(Listeners, Entry)
		end
		return Entry.Link
	end

	const function fire(Pivot: CFrame, Scale: number)
		for _, Entry in table.clone(Listeners) do
			const Callback = Entry.Callback
			if Callback then
				if Entry.Once then
					drop(Entry)
				end
				task.spawn(Callback, Pivot, Scale)
			end
		end
	end

	const function clear()
		Dead = true
		for _, Entry in Listeners do
			Entry.Callback = nil
			Entry.Link.Connected = false
		end
		table.clear(Listeners)
	end

	const Signal: ChangedSignal = {
		Connect = function(_, Callback)
			return listen(Callback, false)
		end,
		Once = function(_, Callback)
			return listen(Callback, true)
		end,
	}

	return Signal, fire, clear
end

const Gizmo = {}
Gizmo.__index = Gizmo

type Fields = {
	Model: Model,
	Cube: Part,
	Gui: ScreenGui,
	DragCode: DragCode,
	HandleKind: HandleKind,
	Space: Space,
	RotateAxis: Axis,
	TranslateIncrement: number,
	RotateIncrement: number,
	ScaleIncrement: number,
	IgnoreList: { Instance },
	Blockers: { GuiObject },
	MinScale: number?,
	MaxScale: number?,
	Changed: ChangedSignal,
	FireChanged: (Pivot: CFrame, Scale: number) -> (),
	ClearChanged: () -> (),
	FinalPivot: CFrame,
	FinalScale: number,
	Params: RaycastParams,
	Handles: { [HandleKind]: { GuiBase3d } },
	Connections: { RBXScriptConnection },
	BoxOffset: CFrame,
	BoxSize: Vector3,
	BoxScale: number,
	StartPivot: CFrame,
	StartScale: number,
	StartCube: CFrame,
	StartSize: Vector3,
	Dragging: ((Gizmo, Enum.NormalId, number) -> ())?,
	DragFace: Enum.NormalId?,
	DragAxis: Vector3,
	DragOrigin: Vector3,
	DragStart: number,
	DragLast: number,
	Destroyed: boolean,
}

export type Gizmo = typeof(setmetatable({} :: Fields, Gizmo))

const function snap(Value: number, Increment: number): number
	if Increment <= 0 then
		return Value
	end
	return math.round(Value / Increment) * Increment
end

const function boxExtents(Rotation: CFrame, Size: Vector3): Vector3
	return Rotation.XVector:Abs() * Size.X + Rotation.YVector:Abs() * Size.Y + Rotation.ZVector:Abs() * Size.Z
end

const function planeAngle(Direction: Vector3, Normal: Vector3): number
	const Reference = if math.abs(Normal.Y) < 0.99 then Vector3.yAxis else Vector3.zAxis
	const U = Normal:Cross(Reference).Unit
	const V = Normal:Cross(U)
	return math.atan2(Direction:Dot(V), Direction:Dot(U))
end

const function leastAligned(Rotation: CFrame, Normal: Vector3): Vector3
	local Best = Rotation.XVector
	local BestDot = math.abs(Best:Dot(Normal))
	for _, Candidate in { Rotation.YVector, Rotation.ZVector } do
		const Dot = math.abs(Candidate:Dot(Normal))
		if Dot < BestDot then
			Best = Candidate
			BestDot = Dot
		end
	end
	return Best
end

const function rotateAbout(Pivot: CFrame, Center: Vector3, Normal: Vector3, Angle: number): CFrame
	return (CFrame.new(Center) * CFrame.fromAxisAngle(Normal, Angle) * CFrame.new(-Center) * Pivot):Orthonormalize()
end

const function snapOnSurface(Position: Vector3, Normal: Vector3, Increment: number): Vector3
	if Increment <= 0 then
		return Position
	end
	const Abs = Normal:Abs()
	const Fixed = if Abs.X >= Abs.Y and Abs.X >= Abs.Z then "X" elseif Abs.Y >= Abs.Z then "Y" else "Z"
	return Vector3.new(
		if Fixed == "X" then Position.X else snap(Position.X, Increment),
		if Fixed == "Y" then Position.Y else snap(Position.Y, Increment),
		if Fixed == "Z" then Position.Z else snap(Position.Z, Increment)
	)
end

const function mouseRay(): Ray?
	const Camera = workspace.CurrentCamera
	if not Camera then
		return nil
	end
	const Mouse = UserInputService:GetMouseLocation()
	return Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
end

const function measure(Self: Gizmo)
	const BoxFrame, BoxSize = Self.Model:GetBoundingBox()
	Self.BoxOffset = Self.Model:GetPivot():ToObjectSpace(BoxFrame)
	Self.BoxSize = BoxSize:Max(MinimumSize)
	Self.BoxScale = Self.Model:GetScale()
end

const function currentBox(Self: Gizmo): (CFrame, Vector3)
	const Pivot = Self.Model:GetPivot()
	const Ratio = Self.Model:GetScale() / Self.BoxScale
	const Offset = CFrame.new(Self.BoxOffset.Position * Ratio) * Self.BoxOffset.Rotation
	const Size = Self.BoxSize * Ratio
	return Pivot.Rotation + (Pivot * Offset).Position, boxExtents(Offset.Rotation, Size)
end

const function syncCube(Self: Gizmo)
	const Frame, Size = currentBox(Self)
	if Self.Cube.Size ~= Size then
		Self.Cube.Size = Size
	end
	if Self.Cube.CFrame ~= Frame then
		Self.Cube.CFrame = Frame
	end
end

const function refreshFilter(Self: Gizmo)
	const Filter: { Instance } = { Self.Model, Self.Cube }
	for _, Item in Self.IgnoreList do
		table.insert(Filter, Item)
	end
	Self.Params.FilterDescendantsInstances = Filter
end

const function refreshVisibility(Self: Gizmo)
	for Kind, List in Self.Handles do
		const Visible = Self.DragCode == "Handles" and Self.HandleKind == Kind
		for _, Item in List do
			if Item.Visible ~= Visible then
				Item.Visible = Visible
			end
		end
	end
end

const function applyPivot(Self: Gizmo, Pivot: CFrame)
	Self.Model:PivotTo(Pivot)
	Self.FireChanged(Pivot, Self.Model:GetScale())
end

const function beginDrag(Self: Gizmo)
	Self.StartPivot = Self.Model:GetPivot()
	Self.StartScale = Self.Model:GetScale()
	Self.StartCube = Self.Cube.CFrame
	Self.StartSize = Self.Cube.Size
end

const function dragTranslate(Self: Gizmo, Face: Enum.NormalId, Distance: number)
	const Direction = Self.StartCube:VectorToWorldSpace(Vector3.FromNormalId(Face))
	local Position = Self.StartPivot.Position + Direction * Distance
	if Self.TranslateIncrement > 0 then
		const Along = Position:Dot(Direction)
		Position += Direction * (snap(Along, Self.TranslateIncrement) - Along)
	end
	applyPivot(Self, Self.StartPivot.Rotation + Position)
end

const function dragRotate(Self: Gizmo, AxisId: Enum.Axis, Angle: number)
	const Normal = Self.StartCube:VectorToWorldSpace(Vector3.FromAxis(AxisId))
	local Delta = Angle
	if Self.RotateIncrement > 0 then
		const Start = planeAngle(leastAligned(Self.StartPivot.Rotation, Normal), Normal)
		Delta = snap(Start + Angle, math.rad(Self.RotateIncrement)) - Start
	end
	applyPivot(Self, rotateAbout(Self.StartPivot, Self.StartCube.Position, Normal, Delta))
end

const function dragScale(Self: Gizmo, Face: Enum.NormalId, Distance: number)
	const Extent = math.abs(Vector3.FromNormalId(Face):Dot(Self.StartSize))
	if Extent <= 0 then
		return
	end
	const Increment = Self.ScaleIncrement
	const Floor = if Increment > 0 then Increment else MinimumScale
	local Scale = math.max(snap(Self.StartScale * (1 + 2 * Distance / Extent), Increment), Floor)
	const Low = Self.MinScale
	const High = Self.MaxScale
	if Low then
		Scale = math.max(Scale, Low)
	end
	if High then
		Scale = math.min(Scale, High)
	end
	if math.abs(Scale - Self.Model:GetScale()) < 1e-6 then
		return
	end
	const Center = Self.StartCube.Position
	const Offset = Self.StartPivot:PointToObjectSpace(Center) * (Scale / Self.StartScale)
	const Pivot = Self.StartPivot.Rotation + (Center - Self.StartPivot:VectorToWorldSpace(Offset))
	Self.Model:ScaleTo(Scale)
	applyPivot(Self, Pivot)
end

const function followHit(Self: Gizmo)
	const MouseRay = mouseRay()
	if not MouseRay then
		return
	end
	const Result = workspace:Raycast(MouseRay.Origin, MouseRay.Direction * RayLength, Self.Params)
	if not Result then
		return
	end
	const Position = snapOnSurface(Result.Position, Result.Normal, Self.TranslateIncrement)
	const Pivot = Self.Model:GetPivot()
	if (Pivot.Position - Position).Magnitude < 1e-4 then
		return
	end
	applyPivot(Self, Pivot.Rotation + Position)
end

const function flatten(Vector: Vector3, Normal: Vector3): Vector3
	return Vector - Normal * Vector:Dot(Normal)
end

const function dialDirection(Camera: Camera, Mouse: Vector2, Center: Vector3, Normal: Vector3): Vector3?
	const Screen = Camera:WorldToViewportPoint(Center)
	if Screen.Z <= 0 then
		return nil
	end
	const Offset = Mouse - Vector2.new(Screen.X, Screen.Y)
	if Offset.Magnitude < DialDeadzone then
		return nil
	end
	const View = Camera.CFrame
	const Side = if (View.Position - Center):Dot(Normal) >= 0 then 1 else -1
	const Right = flatten(View.RightVector, Normal) + flatten(View.UpVector, Normal):Cross(Normal) * Side
	if Right.Magnitude < 1e-4 then
		return nil
	end
	const RightUnit = Right.Unit
	const UpUnit = Normal:Cross(RightUnit) * Side
	const Spin = math.atan2(-Offset.Y, Offset.X)
	return RightUnit * math.cos(Spin) + UpUnit * math.sin(Spin)
end

const function planeHit(MouseRay: Ray, Center: Vector3, Normal: Vector3): Vector3?
	const Facing = MouseRay.Direction:Dot(Normal)
	if math.abs(Facing) < 1e-3 then
		return nil
	end
	const Travel = (Center - MouseRay.Origin):Dot(Normal) / Facing
	if Travel <= 0 then
		return nil
	end
	const Hit = MouseRay.Origin + MouseRay.Direction * Travel - Center
	if Hit.Magnitude < 1e-3 then
		return nil
	end
	return Hit.Unit
end

const function followRotate(Self: Gizmo)
	const Camera = workspace.CurrentCamera
	if not Camera then
		return
	end
	const Mouse = UserInputService:GetMouseLocation()
	const MouseRay = Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
	const Pivot = Self.Model:GetPivot()
	const Center = currentBox(Self).Position
	const Normal = if Self.Space == "Local"
		then Pivot:VectorToWorldSpace(AxisVectors[Self.RotateAxis])
		else AxisVectors[Self.RotateAxis]
	const Trust = math.clamp((math.abs(MouseRay.Direction:Dot(Normal)) - TrustStart) / TrustRange, 0, 1)
	const Dial = dialDirection(Camera, Mouse, Center, Normal)
	const Hit = if Trust > 0 then planeHit(MouseRay, Center, Normal) else nil
	const Target = if Dial and Hit then Dial:Lerp(Hit, Trust) else Hit or Dial
	if not Target or Target.Magnitude < 1e-3 then
		return
	end
	const Preferred = if Self.RotateAxis == "Z" then Pivot.UpVector else Pivot.LookVector
	const Reference = if math.abs(Preferred:Dot(Normal)) > 0.95 then leastAligned(Pivot.Rotation, Normal) else Preferred
	local Wanted = planeAngle(Target, Normal)
	if Self.RotateIncrement > 0 then
		Wanted = snap(Wanted, math.rad(Self.RotateIncrement))
	end
	const Delta = (Wanted - planeAngle(Reference, Normal) + math.pi) % (2 * math.pi) - math.pi
	if math.abs(Delta) < 1e-5 then
		return
	end
	applyPivot(Self, rotateAbout(Pivot, Center, Normal, Delta))
end

const function shown(Item: GuiObject): boolean
	local Current: Instance? = Item
	while Current do
		if Current:IsA("GuiObject") and not Current.Visible then
			return false
		end
		if Current:IsA("LayerCollector") then
			return Current.Enabled
		end
		Current = Current.Parent
	end
	return false
end

const function pointerBlocked(Self: Gizmo): boolean
	if #Self.Blockers == 0 then
		return false
	end
	const Mouse = UserInputService:GetMouseLocation()
	const Inset = GuiService:GetGuiInset()
	for _, Item in Self.Blockers do
		if not shown(Item) then
			continue
		end
		const Layer = Item:FindFirstAncestorWhichIsA("ScreenGui")
		const Point = if Layer and Layer.IgnoreGuiInset then Mouse else Mouse - Inset
		const Corner = Item.AbsolutePosition
		const Far = Corner + Item.AbsoluteSize
		if Point.X >= Corner.X and Point.X <= Far.X and Point.Y >= Corner.Y and Point.Y <= Far.Y then
			return true
		end
	end
	return false
end

const function axisParam(Origin: Vector3, Axis: Vector3, MouseRay: Ray): number?
	const Direction = MouseRay.Direction.Unit
	const Facing = Axis:Dot(Direction)
	const Denominator = 1 - Facing * Facing
	if Denominator < ParallelLimit then
		return nil
	end
	const Offset = Origin - MouseRay.Origin
	const Along = Axis:Dot(Offset)
	const Ahead = Direction:Dot(Offset)
	const Depth = (Ahead - Facing * Along) / Denominator
	if Depth <= 0 then
		return nil
	end
	const Param = (Facing * Ahead - Along) / Denominator
	return if Param == Param then Param else nil
end

const function startAxisDrag(Self: Gizmo, Face: Enum.NormalId, Drag: (Gizmo, Enum.NormalId, number) -> ())
	const Axis = Self.StartCube:VectorToWorldSpace(Vector3.FromNormalId(Face))
	const Origin = Self.StartCube.Position
	const MouseRay = mouseRay()
	const Start = if MouseRay then axisParam(Origin, Axis, MouseRay) else nil
	if not Start then
		Self.Dragging = nil
		Self.DragFace = nil
		return
	end
	Self.DragAxis = Axis
	Self.DragOrigin = Origin
	Self.DragStart = Start
	Self.DragLast = 0
	Self.DragFace = Face
	Self.Dragging = Drag
end

const function stopAxisDrag(Self: Gizmo)
	Self.Dragging = nil
	Self.DragFace = nil
end

const function stepAxisDrag(Self: Gizmo)
	const Drag = Self.Dragging
	const Face = Self.DragFace
	if not Drag or not Face then
		return
	end
	if Self.DragCode ~= "Handles" then
		stopAxisDrag(Self)
		return
	end
	const MouseRay = mouseRay()
	const Param = if MouseRay then axisParam(Self.DragOrigin, Self.DragAxis, MouseRay) else nil
	if not Param then
		return
	end
	const Distance = math.clamp(Param - Self.DragStart, -MaxDrag, MaxDrag)
	if math.abs(Distance - Self.DragLast) < 1e-4 then
		return
	end
	Self.DragLast = Distance
	Drag(Self, Face, Distance)
end

const function step(Self: Gizmo)
	stepAxisDrag(Self)
	if Self.DragCode == "HitMouseTranslate" then
		if not pointerBlocked(Self) then
			followHit(Self)
		end
	elseif Self.DragCode == "MouseRotate" then
		if not pointerBlocked(Self) then
			followRotate(Self)
		end
	end
	if not Self.Destroyed then
		syncCube(Self)
	end
end

const function track(Self: Gizmo, Link: RBXScriptConnection)
	table.insert(Self.Connections, Link)
end

const function moveHandle(
	Self: Gizmo,
	Name: string,
	Sides: Faces,
	Color: Color3,
	Style: Enum.HandlesStyle,
	Drag: (Gizmo, Enum.NormalId, number) -> ()
): Handles
	const Made = Instance.new("Handles")
	Made.Name = Name
	Made.Style = Style
	Made.Faces = Sides
	Made.Color3 = Color
	Made.Adornee = Self.Cube
	Made.Visible = false
	track(
		Self,
		Made.MouseButton1Down:Connect(function(Face: Enum.NormalId)
			beginDrag(Self)
			startAxisDrag(Self, Face, Drag)
		end)
	)
	Made.Parent = Self.Gui
	return Made
end

const function rotateHandle(Self: Gizmo): ArcHandles
	const Made = Instance.new("ArcHandles")
	Made.Name = "Rotate"
	Made.Axes = Axes.new(Enum.Axis.X, Enum.Axis.Y, Enum.Axis.Z)
	Made.Adornee = Self.Cube
	Made.Visible = false
	track(
		Self,
		Made.MouseButton1Down:Connect(function()
			beginDrag(Self)
		end)
	)
	track(
		Self,
		Made.MouseDrag:Connect(function(AxisId: Enum.Axis, Angle: number)
			dragRotate(Self, AxisId, Angle)
		end)
	)
	Made.Parent = Self.Gui
	return Made
end

function ModelHandles.new(Model: Model, Options: Settings?): Gizmo
	assert(RunService:IsClient(), "ModelHandles only runs on the client")
	const Given: Settings = Options or {}
	const PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	const Cube = Instance.new("Part")
	Cube.Name = "ModelHandlesCube"
	Cube.Anchored = true
	Cube.CanCollide = false
	Cube.CanQuery = false
	Cube.CanTouch = false
	Cube.CastShadow = false
	Cube.Locked = true
	Cube.Transparency = 1
	Cube.CFrame = Model:GetPivot()

	const Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude

	const Gui = Instance.new("ScreenGui")
	Gui.Name = "ModelHandles"
	Gui.ResetOnSpawn = false

	const Changed, FireChanged, ClearChanged = createSignal()

	const Self = setmetatable({
		Model = Model,
		Cube = Cube,
		Gui = Gui,
		DragCode = Given.DragCode or "Handles",
		HandleKind = Given.HandleKind or "Translate",
		Space = Given.Space or "World",
		RotateAxis = Given.RotateAxis or "Y",
		TranslateIncrement = math.max(Given.TranslateIncrement or 0, 0),
		RotateIncrement = math.max(Given.RotateIncrement or 0, 0),
		ScaleIncrement = math.max(Given.ScaleIncrement or 0, 0),
		IgnoreList = table.clone(Given.IgnoreList or {}),
		Blockers = table.clone(Given.Blockers or {}),
		MinScale = Given.MinScale,
		MaxScale = Given.MaxScale,
		Changed = Changed,
		FireChanged = FireChanged,
		ClearChanged = ClearChanged,
		FinalPivot = CFrame.identity,
		FinalScale = 1,
		Params = Params,
		Handles = {},
		Connections = {},
		BoxOffset = CFrame.identity,
		BoxSize = Vector3.one,
		BoxScale = 1,
		StartPivot = CFrame.identity,
		StartScale = 1,
		StartCube = CFrame.identity,
		StartSize = Vector3.one,
		Dragging = nil,
		DragFace = nil,
		DragAxis = Vector3.xAxis,
		DragOrigin = Vector3.zero,
		DragStart = 0,
		DragLast = 0,
		Destroyed = false,
	} :: Fields, Gizmo)

	measure(Self)
	syncCube(Self)
	Cube.Parent = workspace
	refreshFilter(Self)

	Self.Handles = {
		Translate = {
			moveHandle(
				Self,
				"TranslateX",
				Faces.new(Enum.NormalId.Right, Enum.NormalId.Left),
				Color3.fromRGB(255, 70, 70),
				Enum.HandlesStyle.Movement,
				dragTranslate
			),
			moveHandle(
				Self,
				"TranslateY",
				Faces.new(Enum.NormalId.Top, Enum.NormalId.Bottom),
				Color3.fromRGB(80, 220, 90),
				Enum.HandlesStyle.Movement,
				dragTranslate
			),
			moveHandle(
				Self,
				"TranslateZ",
				Faces.new(Enum.NormalId.Front, Enum.NormalId.Back),
				Color3.fromRGB(70, 130, 255),
				Enum.HandlesStyle.Movement,
				dragTranslate
			),
		},
		Rotate = { rotateHandle(Self) },
		Scale = {
			moveHandle(
				Self,
				"Scale",
				Faces.new(
					Enum.NormalId.Right,
					Enum.NormalId.Left,
					Enum.NormalId.Top,
					Enum.NormalId.Bottom,
					Enum.NormalId.Front,
					Enum.NormalId.Back
				),
				Color3.fromRGB(90, 200, 255),
				Enum.HandlesStyle.Resize,
				dragScale
			),
		},
	}
	refreshVisibility(Self)
	Gui.Parent = PlayerGui

	track(
		Self,
		RunService.PreRender:Connect(function()
			step(Self)
		end)
	)
	track(
		Self,
		UserInputService.InputEnded:Connect(function(Input: InputObject)
			const Kind = Input.UserInputType
			if Kind == Enum.UserInputType.MouseButton1 or Kind == Enum.UserInputType.Touch then
				stopAxisDrag(Self)
			end
		end)
	)
	for _, Watched in { Model, Cube, Gui } :: { Instance } do
		track(
			Self,
			Watched.Destroying:Connect(function()
				Self:destroy()
			end)
		)
	end

	return Self
end

function Gizmo.setDragCode(Self: Gizmo, Code: DragCode)
	if Self.Destroyed then
		return
	end
	Self.DragCode = Code
	if Code ~= "Handles" then
		stopAxisDrag(Self)
	end
	refreshVisibility(Self)
end

function Gizmo.setHandleKind(Self: Gizmo, Kind: HandleKind)
	if Self.Destroyed then
		return
	end
	Self.HandleKind = Kind
	refreshVisibility(Self)
end

function Gizmo.setSpace(Self: Gizmo, Value: Space)
	if Self.Destroyed then
		return
	end
	Self.Space = Value
end

function Gizmo.setRotateAxis(Self: Gizmo, Value: Axis)
	if Self.Destroyed then
		return
	end
	Self.RotateAxis = Value
end

function Gizmo.setIncrement(Self: Gizmo, Kind: HandleKind, Value: number)
	if Self.Destroyed then
		return
	end
	const Clean = math.max(Value, 0)
	if Kind == "Translate" then
		Self.TranslateIncrement = Clean
	elseif Kind == "Rotate" then
		Self.RotateIncrement = Clean
	else
		Self.ScaleIncrement = Clean
	end
end

function Gizmo.setIgnoreList(Self: Gizmo, List: { Instance })
	if Self.Destroyed then
		return
	end
	Self.IgnoreList = table.clone(List)
	refreshFilter(Self)
end

function Gizmo.setBlockers(Self: Gizmo, List: { GuiObject })
	if Self.Destroyed then
		return
	end
	Self.Blockers = table.clone(List)
end

function Gizmo.setScaleLimits(Self: Gizmo, Min: number?, Max: number?)
	if Self.Destroyed then
		return
	end
	Self.MinScale = Min
	Self.MaxScale = Max
end

function Gizmo.refresh(Self: Gizmo)
	if Self.Destroyed then
		return
	end
	measure(Self)
	syncCube(Self)
end

function Gizmo.destroy(Self: Gizmo): (CFrame, number)
	if Self.Destroyed then
		return Self.FinalPivot, Self.FinalScale
	end
	Self.Destroyed = true
	Self.DragCode = "None"
	Self.FinalPivot = Self.Model:GetPivot()
	Self.FinalScale = Self.Model:GetScale()

	for _, Link in Self.Connections do
		Link:Disconnect()
	end
	table.clear(Self.Connections)
	Self.ClearChanged()

	Self.Params.FilterDescendantsInstances = {}
	for _, List in Self.Handles do
		table.clear(List)
	end
	table.clear(Self.Handles)
	table.clear(Self.IgnoreList)
	table.clear(Self.Blockers)

	Self.Gui:Destroy()
	Self.Cube:Destroy()

	const Loose = Self :: any
	Loose.Model = nil
	Loose.Cube = nil
	Loose.Gui = nil
	Loose.Params = nil
	Loose.FireChanged = nil
	Loose.ClearChanged = nil

	return Self.FinalPivot, Self.FinalScale
end

return ModelHandles
