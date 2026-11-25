--!strict
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")
const Workspace = game:GetService("Workspace")

export type Mode = "None" | "Translate" | "Rotate" | "Scale"

export type Hooks = {
    moved: (World: CFrame) -> (),
    sized: (Size: Vector3, World: CFrame) -> (),
    finished: () -> (),
}

type Drag = {
    Face: Enum.NormalId,
    Axis: Vector3,
    Origin: Vector3,
    Start: number,
    Frame: CFrame,
    Size: Vector3,
    Last: number,
}

const Gizmo = {
    MaxDrag = 64,
    MinSize = 0.05,
    ParallelLimit = 0.02,
}

const Links: { RBXScriptConnection } = {}
local Screen: ScreenGui? = nil
local Handle: GuiBase3d? = nil
local Target: BasePart? = nil
local Active: Hooks? = nil
local Current: Mode = "None"
local Dragging: Drag? = nil
local Turning: CFrame? = nil

const function screen(): ScreenGui
    const Existing = Screen
    if Existing and Existing.Parent then
        return Existing
    end
    const Made = Instance.new("ScreenGui")
    Made.Name = "CustomizeHandles"
    Made.ResetOnSpawn = false
    Made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    Screen = Made
    return Made
end

const function mouseRay(): Ray?
    const Camera = Workspace.CurrentCamera
    if not Camera then
        return nil
    end
    const Mouse = UserInputService:GetMouseLocation()
    return Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
end

const function axisParam(Origin: Vector3, Axis: Vector3, MouseRay: Ray): number?
    const Direction = MouseRay.Direction.Unit
    const Facing = Axis:Dot(Direction)
    const Denominator = 1 - Facing * Facing
    if Denominator < Gizmo.ParallelLimit then
        return nil
    end
    const Offset = Origin - MouseRay.Origin
    const Along = Axis:Dot(Offset)
    const Ahead = Direction:Dot(Offset)
    if (Ahead - Facing * Along) / Denominator <= 0 then
        return nil
    end
    const Param = (Facing * Ahead - Along) / Denominator
    return if Param == Param then Param else nil
end

const function finish()
    const Hooks = Active
    const Was = Dragging ~= nil or Turning ~= nil
    Dragging = nil
    Turning = nil
    if Was and Hooks then
        Hooks.finished()
    end
end

const function beginAxis(Face: Enum.NormalId)
    const Part = Target
    if not Part then
        return
    end
    const Frame = Part.CFrame
    const Axis = Frame:VectorToWorldSpace(Vector3.FromNormalId(Face))
    const Ray = mouseRay()
    const Start = if Ray then axisParam(Frame.Position, Axis, Ray) else nil
    if not Start then
        return
    end
    Dragging = {
        Face = Face,
        Axis = Axis,
        Origin = Frame.Position,
        Start = Start,
        Frame = Frame,
        Size = Part.Size,
        Last = 0,
    }
end

const function stepAxis()
    const Drag = Dragging
    const Hooks = Active
    if not Drag or not Hooks then
        return
    end
    const Ray = mouseRay()
    const Param = if Ray then axisParam(Drag.Origin, Drag.Axis, Ray) else nil
    if not Param then
        return
    end
    const Distance = math.clamp(Param - Drag.Start, -Gizmo.MaxDrag, Gizmo.MaxDrag)
    if math.abs(Distance - Drag.Last) < 1e-4 then
        return
    end
    Drag.Last = Distance
    if Current == "Translate" then
        Hooks.moved(Drag.Frame + Drag.Axis * Distance)
        return
    end
    const Local = Vector3.FromNormalId(Drag.Face)
    const Mask = Local:Abs()
    const Grown = Drag.Size + Mask * Distance
    const Size = Vector3.new(
        math.max(Grown.X, Gizmo.MinSize),
        math.max(Grown.Y, Gizmo.MinSize),
        math.max(Grown.Z, Gizmo.MinSize)
    )
    const Change = (Size - Drag.Size):Dot(Mask)
    Hooks.sized(Size, Drag.Frame * CFrame.new(Local * (Change / 2)))
end

function Gizmo.detach()
    finish()
    for _, Link in Links do
        Link:Disconnect()
    end
    table.clear(Links)
    const Old = Handle
    Handle = nil
    if Old then
        Old:Destroy()
    end
    Target = nil
    Active = nil
    Current = "None"
end

function Gizmo.mode(): Mode
    return Current
end

function Gizmo.busy(): boolean
    return Dragging ~= nil or Turning ~= nil
end

function Gizmo.attach(Part: BasePart, Mode: Mode, Given: Hooks)
    Gizmo.detach()
    if Mode == "None" then
        return
    end
    Target = Part
    Active = Given
    Current = Mode

    if Mode == "Rotate" then
        const Arcs = Instance.new("ArcHandles")
        Arcs.Name = "CustomizeArcs"
        Arcs.Adornee = Part
        Arcs.Parent = screen()
        Handle = Arcs
        table.insert(Links, Arcs.MouseButton1Down:Connect(function()
            Turning = Part.CFrame
        end))
        table.insert(Links, Arcs.MouseDrag:Connect(function(Axis: Enum.Axis, Angle: number)
            const Start = Turning
            const Hooks = Active
            if Start and Hooks and Angle == Angle then
                Hooks.moved(Start * CFrame.fromAxisAngle(Vector3.FromAxis(Axis), Angle))
            end
        end))
    else
        const Made = Instance.new("Handles")
        Made.Name = "CustomizeHandles"
        Made.Style = if Mode == "Scale" then Enum.HandlesStyle.Resize else Enum.HandlesStyle.Movement
        Made.Color3 = if Mode == "Scale" then Color3.fromRGB(90, 200, 255) else Color3.fromRGB(255, 196, 64)
        Made.Adornee = Part
        Made.Parent = screen()
        Handle = Made
        table.insert(Links, Made.MouseButton1Down:Connect(beginAxis))
    end

    table.insert(Links, RunService.PreRender:Connect(stepAxis))
    table.insert(Links, UserInputService.InputEnded:Connect(function(Input: InputObject)
        const Kind = Input.UserInputType
        if Kind == Enum.UserInputType.MouseButton1 or Kind == Enum.UserInputType.Touch then
            finish()
        end
    end))
end

return Gizmo
