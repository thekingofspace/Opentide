--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Workspace = game:GetService("Workspace")

const vision = require(ReplicatedStorage.MainPackages.vision)
const signal = require(ReplicatedStorage.MainPackages.signal)
const Sounds = require(ReplicatedStorage.Shared.Sounds)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const PropPlacer = require(ReplicatedStorage.Shared.PropPlacer)
const Kinds = require(script.Kinds)
const Stats = require(ReplicatedStorage.Shared.Bio.Stats)
const Bridges = require(script.Bridges)
const View = require(ReplicatedStorage.Shared.GUI_Elements.Dice)

export type Kind = Kinds.Kind

export type Info = {
    Stat: string?,
    Bonus: number,
    Modifier: number,
    Total: number,
    Note: string?,
}

const Dice = {
    FolderName = "DiceModels",
    RollTime = 0.9,
    FlickerRate = 0.07,
    CameraSpot = Vector3.new(0, 1.4, 5.2),
    FieldOfView = 40,
    HeadSize = 2.2,
    HeadLift = 1.9,
    HeadRange = 120,
    HoldTime = 3.5,
    Changed = signal.new(),
    Rolled = signal.new(),
}

const Net = NetWatch.Dice

local Shown = false
local Rolling = false
local StatPick: string? = nil
local ModText = ""
local Picked: Kind? = nil
local Started = false
local Stage: ViewportFrame? = nil
local Shown3d: Model? = nil
local Spin = CFrame.identity
const Rng = Random.new()

const function modelOf(Kind: Kind): Model?
    const Folder = ReplicatedStorage:FindFirstChild(Dice.FolderName)
    const Found = if Folder then Folder:FindFirstChild(Kind.Id) else nil
    if not Found or not Found:IsA("Model") then
        warn(`[Dice] there is no premade model for {Kind.Id} in ReplicatedStorage.{Dice.FolderName}`)
        return nil
    end
    return Found:Clone()
end

const function find(Id: string): Kind?
    for _, Item in Kinds do
        if Item.Id == Id then
            return Item
        end
    end
    return nil
end

const function refresh()
    const Cards: { Bridges.DieCard } = {}
    const List = table.clone(Kinds)
    table.sort(List, function(A: Kind, B: Kind): boolean
        return A.Order < B.Order
    end)
    const Current = Picked
    for _, Item in List do
        table.insert(Cards, { Id = Item.Id, Name = Item.Name, Active = Current ~= nil and Current.Id == Item.Id })
    end
    View.DiceKinds(Cards)
    const Choices = { { Id = "none", Name = "no stat", Active = StatPick == nil } }
    for _, Def in Stats.sorted() do
        const Bonus = Stats.bonus(Def, Stats.valueOf(Players.LocalPlayer, Def))
        table.insert(Choices, { Id = Def.Id, Name = `{Def.Name} ({Stats.signed(Bonus)})`, Active = StatPick == Def.Id })
    end
    View.DiceStats(Choices)
    Dice.Changed:Fire()
end

const function show(Kind: Kind): Model?
    const Frame = Stage
    if not Frame then
        return nil
    end
    const Old = Shown3d
    if Old then
        Old:Destroy()
    end
    const Made = modelOf(Kind)
    if not Made then
        return nil
    end
    Made.Parent = Frame
    Shown3d = Made
    return Made
end

function Dice.modifier(Text: string): (number, string)
    const Number, Rest = string.match(Text, "^%s*([%+%-]?%d+)%s*(.-)%s*$")
    if not Number then
        return 0, ""
    end
    return tonumber(Number) or 0, Rest or ""
end

function Dice.describe(Kind: Kind, Result: number, Info: Info): string
    if Info.Bonus == 0 and Info.Modifier == 0 then
        return tostring(Result)
    end
    local Text = tostring(Result)
    const Stat = Stats.get(Info.Stat)
    if Info.Bonus ~= 0 or Stat then
        Text ..= ` {Stats.signed(Info.Bonus)} {if Stat then Stat.Name else "stat"}`
    end
    if Info.Modifier ~= 0 then
        Text ..= ` {Stats.signed(Info.Modifier)}{if Info.Note and Info.Note ~= "" then " " .. Info.Note else ""}`
    end
    return `{Text} = {Info.Total}`
end

const function animate(Kind: Kind, Result: number, Info: Info)
    Rolling = true
    Picked = Kind
    refresh()
    const Model = show(Kind)
    Sounds.play("DiceRoll")
    if not Model then
        Rolling = false
        View.DiceResult({ Text = `{Kind.Name}: {Dice.describe(Kind, Result, Info)}`, Big = true })
        return
    end
    const Axis = Vector3.new(Rng:NextNumber(-1, 1), Rng:NextNumber(-1, 1), Rng:NextNumber(-1, 1)).Unit
    const Speed = Rng:NextNumber(16, 24)
    local Time = 0
    local Flicker = 0
    local Link: RBXScriptConnection? = nil
    Link = RunService.RenderStepped:Connect(function(Delta: number)
        Time += Delta
        const Left = math.max(1 - Time / Dice.RollTime, 0)
        Spin = CFrame.fromAxisAngle(Axis, Speed * Left * Left * Delta) * Spin
        const Bounce = math.abs(math.sin(Time * 10)) * 0.7 * Left
        if Model.Parent then
            Model:PivotTo(CFrame.new(0, Bounce, 0) * Spin)
        end
        Flicker += Delta
        if Flicker >= Dice.FlickerRate and Left > 0 then
            Flicker = 0
            View.DiceResult({ Text = tostring(Rng:NextInteger(1, Kind.Sides)), Big = true })
        end
        if Time >= Dice.RollTime then
            const Done = Link
            if Done then
                Done:Disconnect()
            end
            Rolling = false
            View.DiceResult({ Text = `{Kind.Name}: {Dice.describe(Kind, Result, Info)}`, Big = true })
            Sounds.play("DiceResult")
        end
    end)
end

const function overhead(Player: Player, Kind: Kind, Result: number)
    const Character = Player.Character
    const Head = if Character then Character:FindFirstChild("Head") else nil
    if not Head or not Head:IsA("BasePart") then
        return
    end
    const Board = Instance.new("BillboardGui")
    Board.Name = `DiceRoll_{Player.UserId}`
    Board.Adornee = Head
    Board.Size = UDim2.fromScale(Dice.HeadSize, Dice.HeadSize)
    Board.StudsOffset = Vector3.new(0, Dice.HeadLift, 0)
    Board.LightInfluence = 0
    Board.MaxDistance = Dice.HeadRange
    Board.ResetOnSpawn = false
    Board.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") or Workspace

    const Frame = Instance.new("ViewportFrame")
    Frame.Size = UDim2.fromScale(1, 1)
    Frame.BackgroundTransparency = 1
    Frame.Ambient = Color3.fromRGB(150, 150, 150)
    Frame.LightColor = Color3.new(1, 1, 1)
    Frame.LightDirection = Vector3.new(-1, -1.4, -0.8)
    Frame.Parent = Board
    const Camera = Instance.new("Camera")
    Camera.FieldOfView = Dice.FieldOfView
    Camera.CFrame = CFrame.lookAt(Dice.CameraSpot, Vector3.zero)
    Camera.Parent = Frame
    Frame.CurrentCamera = Camera
    const Model = modelOf(Kind)
    if Model then
        Model.Parent = Frame
    end

    const Number = Instance.new("TextLabel")
    Number.AnchorPoint = Vector2.new(0.5, 0.5)
    Number.Position = UDim2.fromScale(0.5, 0.5)
    Number.Size = UDim2.fromScale(0.8, 0.5)
    Number.BackgroundTransparency = 1
    Number.TextScaled = true
    Number.Font = Enum.Font.GothamBlack
    Number.TextColor3 = Color3.new(1, 1, 1)
    Number.TextStrokeTransparency = 0
    Number.Text = ""
    Number.ZIndex = 2
    Number.Parent = Board

    const Axis = Vector3.new(Rng:NextNumber(-1, 1), Rng:NextNumber(-1, 1), Rng:NextNumber(-1, 1)).Unit
    const Speed = Rng:NextNumber(16, 24)
    local Turn = CFrame.identity
    local Landed = false
    local Time = 0
    local Link: RBXScriptConnection? = nil
    Link = RunService.RenderStepped:Connect(function(Delta: number)
        Time += Delta
        if not Head.Parent or Time >= Dice.RollTime + Dice.HoldTime then
            const Done = Link
            if Done then
                Done:Disconnect()
            end
            Board:Destroy()
            return
        end
        const Left = math.max(1 - Time / Dice.RollTime, 0)
        Turn = CFrame.fromAxisAngle(Axis, Speed * Left * Left * Delta) * Turn
        const Bounce = math.abs(math.sin(Time * 10)) * 0.7 * Left
        if Model then
            Model:PivotTo(CFrame.new(0, Bounce, 0) * Turn)
        end
        if Left <= 0 and not Landed then
            Landed = true
            Number.Text = tostring(Result)
        end
    end)
end

const function request(Kind: Kind)
    if Rolling then
        return
    end
    task.spawn(function()
        const Modifier = Dice.modifier(ModText)
        const Reply = Net:Call("@Dice/Roll", Kind.Id, StatPick, Modifier)
        if type(Reply) == "table" and not Reply.Ok and type(Reply.Error) == "string" then
            PropPlacer.toast(Reply.Error, "Info")
        end
    end)
end

function Dice.isShown(): boolean
    return Shown
end

function Dice.show(Value: boolean)
    if Shown ~= Value then
        Sounds.play(if Value then "MenuOpen" else "MenuClose")
    end
    Shown = Value
    View.DiceShown(Value)
    Dice.Changed:Fire()
end

function Dice.toggle()
    Dice.show(not Shown)
end

function Dice.roll(Id: string)
    const Kind = find(Id)
    if Kind then
        request(Kind)
    end
end

function Dice.start()
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    const Gui = vision.create({
        ClassName = "ScreenGui",
        Name = "Dice",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 5,
    }) :: ScreenGui
    Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    View:Open().Parent = Gui

    const Frame = Gui:FindFirstChild("Dice_View", true)
    if Frame and Frame:IsA("ViewportFrame") then
        const Camera = Instance.new("Camera")
        Camera.FieldOfView = Dice.FieldOfView
        Camera.CFrame = CFrame.lookAt(Dice.CameraSpot, Vector3.zero)
        Camera.Parent = Frame
        Frame.CurrentCamera = Camera
        Stage = Frame
    end

    Bridges.Dice:Bind(function(Action: string, Value: any)
        if Action == "Close" then
            Dice.show(false)
        elseif Action == "Roll" and type(Value) == "string" then
            Dice.roll(Value)
        elseif Action == "Stat" and type(Value) == "string" then
            StatPick = if Value == "none" then nil else Value
            refresh()
        elseif Action == "Modifier" and type(Value) == "string" then
            ModText = string.sub(Value, 1, 60)
        elseif Action == "Again" then
            const Last = Picked
            if Last then
                request(Last)
            end
        end
    end)
    Net:On("@Dice/Rolled", function(Player: Player, Id: string, Result: number, Raw: any)
        const Kind = find(Id)
        if not Kind or type(Result) ~= "number" then
            return
        end
        const Given = if type(Raw) == "table" then Raw else {}
        const Info: Info = {
            Stat = if type(Given.Stat) == "string" then Given.Stat else nil,
            Bonus = if type(Given.Bonus) == "number" then Given.Bonus else 0,
            Modifier = if type(Given.Modifier) == "number" then Given.Modifier else 0,
            Total = if type(Given.Total) == "number" then Given.Total else Result,
            Note = if Player == Players.LocalPlayer then select(2, Dice.modifier(ModText)) else nil,
        }
        overhead(Player, Kind, Info.Total)
        if Player == Players.LocalPlayer then
            animate(Kind, Result, Info)
        end
        task.delay(Dice.RollTime, function()
            Dice.Rolled:Fire(Player, Kind, Result, Info)
        end)
    end)
    Players.LocalPlayer.AttributeChanged:Connect(function(Name: string)
        if string.sub(Name, 1, #Stats.AttributePrefix) == Stats.AttributePrefix then
            refresh()
        end
    end)
    refresh()
end

return Dice
