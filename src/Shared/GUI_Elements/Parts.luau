--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TextService = game:GetService("TextService")
const UserInputService = game:GetService("UserInputService")
const vision = require(ReplicatedStorage.MainPackages.vision)

export type Declaration = { [any]: any }

const Common = vision.style("Common")
const Typewriter = Font.fromEnum(Enum.Font.SpecialElite)

const Parts = {
    Typewriter = Typewriter,
    Heading = Font.new(Typewriter.Family, Enum.FontWeight.Bold),
    DefaultStroke = 2.5,
}

function Parts.merge(Base: Declaration, Extra: Declaration): Declaration
    for Key, Value in Extra do
        if type(Key) ~= "number" then
            Base[Key] = Value
        end
    end
    for _, Entry in ipairs(Extra) do
        table.insert(Base, Entry)
    end
    return Base
end

function Parts.outline(Thickness: number?): Declaration
    return {
        ClassName = "UIStroke",
        Thickness = Thickness or Parts.DefaultStroke,
        Color = Common["InkColor"],
        LineJoinMode = Enum.LineJoinMode.Miter,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }
end

function Parts.textOutline(Color: Color3?, Thickness: number?): Declaration
    return {
        ClassName = "UIStroke",
        Color = Color or Color3.new(0, 0, 0),
        Thickness = Thickness or 1.5,
        LineJoinMode = Enum.LineJoinMode.Round,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    }
end

function Parts.text(Name: string, Value: string, Properties: Declaration): Declaration
    return Parts.merge({
        ClassName = "TextLabel",
        Name = Name,
        Text = Value,
        FontFace = Typewriter,
        TextScaled = true,
        TextColor3 = Common["InkColor"],
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, Properties)
end

function Parts.edge(Name: string, Size: UDim2, Anchor: Vector2, Position: UDim2, Color: any): Declaration
    return {
        ClassName = "Frame",
        Name = Name,
        AnchorPoint = Anchor,
        Position = Position,
        Size = Size,
        BackgroundColor3 = Color,
        BorderSizePixel = 0,
        ZIndex = 10
    }
end

function Parts.bevel(Name: string, Thickness: number, Light: any, Dark: any): Declaration
    return {
        ClassName = "Frame",
        Name = Name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 10,

        Parts.edge(`{Name}_Top`, UDim2.new(1, 0, 0, Thickness), Vector2.zero, UDim2.new(), Light),
        Parts.edge(`{Name}_Left`, UDim2.new(0, Thickness, 1, 0), Vector2.zero, UDim2.new(), Light),
        Parts.edge(`{Name}_Bottom`, UDim2.new(1, 0, 0, Thickness), Vector2.new(0, 1), UDim2.fromScale(0, 1), Dark),
        Parts.edge(`{Name}_Right`, UDim2.new(0, Thickness, 1, 0), Vector2.new(1, 0), UDim2.fromScale(1, 0), Dark)
    }
end

function Parts.card(Name: string, Outer: Declaration, Inner: Declaration, Depth: (number | Vector2)?, Side: any?, Stroke: number?): Declaration
    const Lift = if typeof(Depth) == "Vector2"
        then Depth
        elseif typeof(Depth) == "number" then Vector2.new(0, Depth)
        else Vector2.zero
    const Shape = UDim2.new(1, -Lift.X, 1, -Lift.Y)
    const Vertical = typeof(Depth) == "number"
    const Made: Declaration = {
        ClassName = "Frame",
        Name = Name,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }

    if Lift.X > 0 or Lift.Y > 0 then
        table.insert(Made, {
            ClassName = "Frame",
            Name = `{Name}_Side`,
            Position = if Vertical then UDim2.fromOffset(0, Lift.Y) else UDim2.new(),
            Size = if Vertical then Shape else UDim2.fromScale(1, 1),
            BackgroundColor3 = Side or Common["ShadowColor"],
            BorderSizePixel = 0,
            ZIndex = 1,
            Parts.outline()
        })
    end

    table.insert(Made, Parts.merge({
        ClassName = "Frame",
        Name = `{Name}_Body`,
        Size = Shape,
        BackgroundColor3 = Common["CardColor"],
        BorderSizePixel = 0,
        ZIndex = 2,
        Parts.outline(Stroke)
    }, Inner))

    return Parts.merge(Made, Outer)
end

function Parts.keyBadge(Key: string, Size: number, Properties: Declaration?): Declaration
    const Wide = math.max(Size, math.ceil(#Key * Size * 0.62 * 0.62) + 12)
    return Parts.merge({
        ClassName = "Frame",
        Name = "Key",
        Size = UDim2.fromOffset(Wide, Size),
        BackgroundColor3 = Common["InkColor"],
        BorderSizePixel = 0,

        Parts.text("Key_Label", Key, {
            Size = UDim2.fromScale(1, 1),
            TextScaled = false,
            TextSize = math.floor(Size * 0.62),
            FontFace = Parts.Heading,
            TextColor3 = Common["CardColor"],
            TextXAlignment = Enum.TextXAlignment.Center
        })
    }, Properties or {})
end

function Parts.draggable(Root: GuiObject, Handle: GuiObject, Later: (() -> ()) -> ())
    local Holding: InputObject? = nil
    local Grab = Vector2.zero
    const Links: { RBXScriptConnection } = {}

    const function move(Input: InputObject)
        const Point = Vector2.new(Input.Position.X, Input.Position.Y)
        const Parent = Root.Parent
        const Room = if Parent and Parent:IsA("GuiBase2d") then Parent.AbsoluteSize else Vector2.new(1920, 1080)
        const Size = Root.AbsoluteSize
        const Corner = Point - Grab
        const Left = math.clamp(Corner.X, 60 - Size.X, Room.X - 60)
        const Top = math.clamp(Corner.Y, 0, math.max(Room.Y - 40, 0))
        Root.Position = UDim2.fromOffset(Left + Size.X * Root.AnchorPoint.X, Top + Size.Y * Root.AnchorPoint.Y)
    end

    table.insert(Links, Handle.InputBegan:Connect(function(Input: InputObject)
        const Kind = Input.UserInputType
        if Kind == Enum.UserInputType.MouseButton1 or Kind == Enum.UserInputType.Touch then
            Holding = Input
            Grab = Vector2.new(Input.Position.X, Input.Position.Y) - Root.AbsolutePosition
        end
    end))
    table.insert(Links, UserInputService.InputChanged:Connect(function(Input: InputObject)
        const Held = Holding
        if not Held then
            return
        end
        if Held.UserInputType == Enum.UserInputType.Touch then
            if Input == Held then
                move(Input)
            end
        elseif Input.UserInputType == Enum.UserInputType.MouseMovement then
            move(Input)
        end
    end))
    table.insert(Links, UserInputService.InputEnded:Connect(function(Input: InputObject)
        const Held = Holding
        if Held and (Input == Held or Input.UserInputType == Held.UserInputType) then
            Holding = nil
        end
    end))
    Later(function()
        Holding = nil
        for _, Link in Links do
            Link:Disconnect()
        end
        table.clear(Links)
    end)
end

function Parts.fitText(Texts: { string }, Width: number, Height: number): number
    local Size = math.floor(Height)
    for _, Value in Texts do
        const Bounds = TextService:GetTextSize(Value, 100, Enum.Font.SpecialElite, Vector2.new(100000, 100000))
        if Bounds.X > 0 then
            Size = math.min(Size, math.floor(100 * Width / Bounds.X))
        end
    end
    return math.max(Size, 8)
end

return Parts
