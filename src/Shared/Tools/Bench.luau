--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")
const Workspace = game:GetService("Workspace")

const signal = require(ReplicatedStorage.MainPackages.signal)
const Format = require(ReplicatedStorage.Shared.Customize.Format)
const FreeCam = require(ReplicatedStorage.Shared.Customize.FreeCam)
const CommonStyle = require(ReplicatedStorage.Shared.GUI_Elements.CommonStyle)
const Tools = require(script.Parent)

const Config = Tools.Config

const Bench = {
    BindName = "ToolBenchCamera",
    PitchLimit = math.rad(80),
    MinDistance = 2,
    MaxDistance = 18,
    MountClicked = signal.new(),
    MountRemoved = signal.new(),
    Symbol = Font.fromEnum(Enum.Font.GothamBold),
}

local Active = false
local Spot = CFrame.identity
local Rig: Model? = nil
local Folder: Folder? = nil
const Marks: { BillboardGui } = {}
local Preview: Model? = nil
local Holstered: Model? = nil
local Focus = Vector3.zero
local LookAtRig = false
local Yaw = math.rad(30)
local Pitch = math.rad(-12)
local Distance = Config.OrbitDistance
local Turning = false
local Saved: CFrame? = nil
const Links: { RBXScriptConnection } = {}

const function benchSpot(): CFrame
    const Placed = Workspace:FindFirstChild(Config.BenchName)
    if Placed and Placed:IsA("BasePart") then
        return Placed.CFrame
    end
    const Model = Rig
    if Model then
        return Model:GetPivot() * CFrame.new(Config.BenchOffset)
    end
    const Camera = Workspace.CurrentCamera
    return if Camera then CFrame.new(Camera.CFrame.Position + Camera.CFrame.LookVector * 10) else CFrame.identity
end

const function step()
    const Camera = Workspace.CurrentCamera
    if not Camera then
        return
    end
    if Turning then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
    end
    const Target = if LookAtRig and Rig then (Rig :: Model):GetPivot().Position + Vector3.new(0, 0.5, 0) else Focus
    Camera.CFrame = CFrame.new(Target) * CFrame.fromEulerAnglesYXZ(Pitch, Yaw, 0) * CFrame.new(0, 0, Distance)
end

const function clearMarks()
    for _, Board in Marks do
        Board:Destroy()
    end
    table.clear(Marks)
end

const function square(Board: BillboardGui, Text: string, Fill: Color3, Ink: Color3, X: number, Pressed: () -> ())
    const Button = Instance.new("TextButton")
    Button.Size = UDim2.fromOffset(28, 28)
    Button.Position = UDim2.fromOffset(X, 0)
    Button.Text = Text
    Button.FontFace = Bench.Symbol
    Button.TextSize = 20
    Button.TextXAlignment = Enum.TextXAlignment.Center
    Button.TextYAlignment = Enum.TextYAlignment.Center
    Button.TextColor3 = Ink
    Button.BackgroundColor3 = Fill
    Button.BorderSizePixel = 0
    Button.AutoButtonColor = true
    Button.Parent = Board
    Button.Activated:Connect(function()
        Pressed()
    end)
end

const function markMounts(Model: Model)
    clearMarks()
    const Gui = Players.LocalPlayer:WaitForChild("PlayerGui")
    for _, Item in Model:GetDescendants() do
        if not Item:IsA("Attachment") then
            continue
        end
        const Path = Item:GetAttribute(Tools.MountAttribute)
        if type(Path) ~= "string" then
            continue
        end
        local Filled = false
        for _, Piece in Model:GetChildren() do
            if Piece:GetAttribute(Tools.PathAttribute) == Path then
                Filled = true
            end
        end
        const Removable = Filled and Item:GetAttribute("MountRequired") ~= true
        const Board = Instance.new("BillboardGui")
        Board.Name = `ToolMount_{Path}`
        Board.Adornee = Item
        Board.Active = true
        Board.AlwaysOnTop = true
        Board.Size = UDim2.fromOffset(if Removable then 60 else 28, 28)
        Board.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        Board.ResetOnSpawn = false
        Board.Parent = Gui
        table.insert(Marks, Board)
        square(Board, "+", if Filled then CommonStyle.WidgetColor:Lerp(Color3.new(1, 1, 1), 0.35) else CommonStyle.WidgetColor, CommonStyle.InkColor, 0, function()
            Bench.MountClicked:Fire(Path)
        end)
        if Removable then
            square(Board, "X", CommonStyle.CloseColor, CommonStyle.CloseText, 32, function()
                Bench.MountRemoved:Fire(Path)
            end)
        end
    end
end

function Bench.active(): boolean
    return Active
end

function Bench.enable(Given: Model?)
    if Active then
        return
    end
    Active = true
    Rig = Given
    Spot = benchSpot()
    Focus = Spot.Position + Vector3.new(0, 1, 0)
    LookAtRig = false
    const Camera = Workspace.CurrentCamera
    Saved = if Camera then Camera.CFrame else nil
    FreeCam.disable(true)
    if Camera then
        Camera.CameraType = Enum.CameraType.Scriptable
    end
    const Made = Instance.new("Folder")
    Made.Name = "ToolBenchPreview"
    Made.Parent = Workspace
    Folder = Made
    RunService:BindToRenderStep(Bench.BindName, Enum.RenderPriority.Camera.Value + 1, step)
    table.insert(Links, UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
        if not Processed and Input.UserInputType == Enum.UserInputType.MouseButton2 then
            Turning = true
        end
    end))
    table.insert(Links, UserInputService.InputEnded:Connect(function(Input: InputObject)
        if Input.UserInputType == Enum.UserInputType.MouseButton2 then
            Turning = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end))
    table.insert(Links, UserInputService.InputChanged:Connect(function(Input: InputObject, Processed: boolean)
        if Input.UserInputType == Enum.UserInputType.MouseWheel and not Processed then
            Distance = math.clamp(Distance - Input.Position.Z, Bench.MinDistance, Bench.MaxDistance)
        elseif Turning and Input.UserInputType == Enum.UserInputType.MouseMovement then
            const Turn = math.rad(Config.OrbitSensitivity)
            Yaw -= Input.Delta.X * Turn
            Pitch = math.clamp(Pitch - Input.Delta.Y * Turn, -Bench.PitchLimit, Bench.PitchLimit)
        end
    end))
end

function Bench.disable()
    if not Active then
        return
    end
    Active = false
    Turning = false
    RunService:UnbindFromRenderStep(Bench.BindName)
    for _, Link in Links do
        Link:Disconnect()
    end
    table.clear(Links)
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    clearMarks()
    const Old = Folder
    Folder = nil
    Preview = nil
    if Old then
        Old:Destroy()
    end
    const Worn = Holstered
    Holstered = nil
    if Worn then
        Worn:Destroy()
    end
    const Back = Saved
    Saved = nil
    if Back then
        FreeCam.enable(Back)
    end
end

function Bench.show(Build: ToolBuild?)
    if not Active then
        return
    end
    const Old = Preview
    Preview = nil
    if Old then
        Old:Destroy()
    end
    clearMarks()
    if not Build then
        return
    end
    const Made = Tools.assemble(Build)
    const Root = if Made then Made.PrimaryPart else nil
    if not Made or not Root then
        return
    end
    Root.Anchored = true
    Made:PivotTo(Spot)
    for _, Item in Made:GetDescendants() do
        if not Item:IsA("Weld") then
            continue
        end
        const From = Item.Part0
        const To = Item.Part1
        if From and To then
            To.CFrame = From.CFrame * Item.C0 * Item.C1:Inverse()
        end
    end
    Made.Parent = Folder
    Preview = Made
    const Center = Made:GetBoundingBox()
    Focus = Center.Position
    markMounts(Made)
end

function Bench.holster(Build: ToolBuild?)
    const Worn = Holstered
    Holstered = nil
    if Worn then
        Worn:Destroy()
    end
    const Model = Rig
    const Spot2 = if Build then Build.Holster else nil
    if not Active or not Model or not Build or not Spot2 or not Spot2.On then
        return
    end
    const Part = Model:FindFirstChild(Spot2.Attach)
    if not Part or not Part:IsA("BasePart") then
        return
    end
    const Made = Tools.assemble(Build)
    const Root = if Made then Made.PrimaryPart else nil
    if not Made or not Root then
        return
    end
    if math.abs(Spot2.Size - 1) > 1e-3 then
        Made:ScaleTo(Spot2.Size)
    end
    const Joint = Instance.new("Weld")
    Joint.Name = "HoldWeld"
    Joint.Part0 = Part
    Joint.Part1 = Root
    Joint.C0 = Format.frame(Spot2.Offset)
    Root.CFrame = Part.CFrame * Joint.C0
    Joint.Parent = Root
    Made.Name = "HolsterPreview"
    Made.Parent = Model
    Holstered = Made
end

function Bench.holsterParts(): (BasePart?, Weld?)
    const Worn = Holstered
    const Root = if Worn then Worn.PrimaryPart else nil
    const Joint = if Root then Root:FindFirstChild("HoldWeld") else nil
    return Root, if Joint and Joint:IsA("Weld") then Joint else nil
end

function Bench.look(Rig2: boolean)
    LookAtRig = Rig2
    Distance = if Rig2 then 8 else Config.OrbitDistance
end

function Bench.looking(): boolean
    return LookAtRig
end

return Bench
