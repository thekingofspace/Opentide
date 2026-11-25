--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")
const Workspace = game:GetService("Workspace")

const signal = require(ReplicatedStorage.MainPackages.signal)
const Sounds = require(ReplicatedStorage.Shared.Sounds)
const PropPlacer = require(ReplicatedStorage.Shared.PropPlacer)
const ToolsClient = require(ReplicatedStorage.Shared.Tools.Client)

const Ruler = {
    Key = Enum.KeyCode.V,
    Color = Color3.fromRGB(255, 214, 90),
    Thickness = 0.08,
    MarkerSize = 0.4,
    Range = 1000,
    Changed = signal.new(),
}

local Active = false
local Started = false
local First: Vector3? = nil
local Second: Vector3? = nil
local Folder: Folder? = nil
local Line: Part? = nil
local MarkA: Part? = nil
local MarkB: Part? = nil
local Label: TextLabel? = nil
local Step: RBXScriptConnection? = nil

const function piece(Name: string, Shape: Enum.PartType, Size: Vector3, Parent: Instance): Part
    const Made = Instance.new("Part")
    Made.Name = Name
    Made.Shape = Shape
    Made.Size = Size
    Made.Anchored = true
    Made.CanCollide = false
    Made.CanQuery = false
    Made.CanTouch = false
    Made.CastShadow = false
    Made.Material = Enum.Material.Neon
    Made.Color = Ruler.Color
    Made.Transparency = 1
    Made.Parent = Parent
    return Made
end

const function build()
    const Made = Instance.new("Folder")
    Made.Name = "Ruler"
    Made.Parent = Workspace.CurrentCamera or Workspace
    Folder = Made
    const Size = Vector3.one * Ruler.MarkerSize
    MarkA = piece("PointA", Enum.PartType.Ball, Size, Made)
    MarkB = piece("PointB", Enum.PartType.Ball, Size, Made)
    const Bar = piece("Line", Enum.PartType.Block, Vector3.new(Ruler.Thickness, Ruler.Thickness, 1), Made)
    Line = Bar

    const Board = Instance.new("BillboardGui")
    Board.Name = "Distance"
    Board.Adornee = Bar
    Board.Size = UDim2.fromOffset(170, 40)
    Board.StudsOffset = Vector3.new(0, 0.8, 0)
    Board.AlwaysOnTop = true
    Board.LightInfluence = 0
    Board.Parent = Made

    const Text = Instance.new("TextLabel")
    Text.Size = UDim2.fromScale(1, 1)
    Text.BackgroundColor3 = Color3.fromRGB(42, 38, 36)
    Text.BackgroundTransparency = 0.15
    Text.TextColor3 = Ruler.Color
    Text.TextScaled = true
    Text.Font = Enum.Font.GothamBold
    Text.Text = ""
    Text.Visible = false
    Text.Parent = Board
    const Pad = Instance.new("UIPadding")
    Pad.PaddingLeft = UDim.new(0, 8)
    Pad.PaddingRight = UDim.new(0, 8)
    Pad.PaddingTop = UDim.new(0, 5)
    Pad.PaddingBottom = UDim.new(0, 5)
    Pad.Parent = Text
    Label = Text
end

const function clear()
    const Old = Folder
    Folder = nil
    Line = nil
    MarkA = nil
    MarkB = nil
    Label = nil
    if Old then
        Old:Destroy()
    end
end

const function aim(Screen: Vector2, Viewport: boolean): Vector3?
    const Camera = Workspace.CurrentCamera
    if not Camera then
        return nil
    end
    const Ray = if Viewport then Camera:ViewportPointToRay(Screen.X, Screen.Y) else Camera:ScreenPointToRay(Screen.X, Screen.Y)
    const Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    const Skip: { Instance } = {}
    if Folder then
        table.insert(Skip, Folder :: Folder)
    end
    const Character = Players.LocalPlayer.Character
    if Character then
        table.insert(Skip, Character)
    end
    Params.FilterDescendantsInstances = Skip
    const Hit = Workspace:Raycast(Ray.Origin, Ray.Direction * Ruler.Range, Params)
    return if Hit then Hit.Position else nil
end

const function draw()
    const A = First
    const B = Second or (if A then aim(UserInputService:GetMouseLocation(), true) else nil)
    const PointA = MarkA
    const PointB = MarkB
    const Bar = Line
    const Text = Label
    if not PointA or not PointB or not Bar or not Text then
        return
    end
    PointA.Transparency = if A then 0 else 1
    PointB.Transparency = if A and B then 0 else 1
    Bar.Transparency = if A and B then 0.2 else 1
    Text.Visible = A ~= nil and B ~= nil
    if not A then
        return
    end
    PointA.Position = A
    if not B then
        return
    end
    PointB.Position = B
    const Distance = (B - A).Magnitude
    Bar.Size = Vector3.new(Ruler.Thickness, Ruler.Thickness, math.max(Distance, 0.01))
    Bar.CFrame = if Distance > 1e-3 then CFrame.lookAt((A + B) / 2, B) else CFrame.new(A)
    Text.Text = string.format("%.2f studs", Distance)
end

const function place(Point: Vector3?)
    if not Point then
        return
    end
    if not First or Second then
        First = Point
        Second = nil
    else
        Second = Point
        PropPlacer.toast(string.format("%.2f studs", (Point - (First :: Vector3)).Magnitude), "Info")
    end
    Sounds.play("Select")
    draw()
end

function Ruler.active(): boolean
    return Active
end

function Ruler.set(Value: boolean)
    if Active == Value then
        return
    end
    Active = Value
    First = nil
    Second = nil
    ToolsClient.blockInput("Ruler", Value)
    const Link = Step
    Step = nil
    if Link then
        Link:Disconnect()
    end
    if Value then
        build()
        Step = RunService.RenderStepped:Connect(function()
            if First and not Second then
                draw()
            end
        end)
        PropPlacer.toast("Ruler on, click two points to measure", "Info")
    else
        clear()
    end
    Sounds.play(if Value then "ToggleOn" else "ToggleOff")
    Ruler.Changed:Fire(Value)
end

function Ruler.toggle()
    Ruler.set(not Active)
end

function Ruler.start()
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
        if Processed then
            return
        end
        if Input.KeyCode == Ruler.Key then
            Ruler.toggle()
            return
        end
        if not Active then
            return
        end
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            place(aim(UserInputService:GetMouseLocation(), true))
        elseif Input.UserInputType == Enum.UserInputType.Touch then
            place(aim(Vector2.new(Input.Position.X, Input.Position.Y), false))
        end
    end)
end

return Ruler
