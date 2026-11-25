--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const PropData = require(ReplicatedStorage.Shared.PropData)
const Parts = require(script.Parent.Parts)
const Images = require(ReplicatedStorage.Shared.Images)

export type Declaration = { [any]: any }

export type BarButton = {
    Id: string,
    Image: string?,
    Color: Color3?,
    press: () -> (),
}

export type BarSpec = {
    Name: string,
    Adornee: Instance,
    Mount: Instance,
    Buttons: { BarButton },
    Size: number,
    MaxDistance: number,
    Shown: boolean,
}

export type WindowSpec = {
    Name: string,
    Title: string,
    Fields: { PropData.Field },
    Values: { [string]: any },
    Position: Vector2,
    Mount: Instance,
    save: () -> (),
    close: () -> (),
    focus: (Root: GuiObject) -> (),
}

export type InfoRow = {
    Label: string,
    Value: string,
}

export type InfoSpec = {
    Name: string,
    Title: string,
    Rows: { InfoRow },
    Position: Vector2,
    Mount: Instance,
    close: () -> (),
    focus: (Root: GuiObject) -> (),
}

const Common = vision.style("Common")
const Typewriter = Parts.Typewriter
const Heading = Parts.Heading
const text = Parts.text
const card = Parts.card
const outline = Parts.outline

const PropWidget = {

    WheelHues = {
        0, 0.024, 0.05, 0.074, 0.097, 0.115, 0.132, 0.148, 0.165,
        0.216, 0.274, 0.333, 0.382, 0.426, 0.474, 0.52, 0.563,
        0.608, 0.649, 0.696, 0.743, 0.788, 0.834, 0.918, 1,
    },
}

const Width = 356
const InfoWidth = 310
const Margin = 16
const BodyPad = 6
const Inner = Width - Margin * 2 - BodyPad * 2
const HeaderHeight = 44
const LabelHeight = 22
const FieldGap = 16
const SaveHeight = 44
const MaxBody = 430
const WheelSize = 150
const ShadeWidth = 22
const InputHeight = 34
const InfoRowHeight = 46
const MinimumScale = 0.6
const ButtonGap = 0.18

const function hueAt(Turn: number): number
    const Hues = PropWidget.WheelHues
    const Spot = (Turn % 1) * (#Hues - 1)
    const Low = math.floor(Spot)
    const From = Hues[Low + 1]
    const To = Hues[math.min(Low + 2, #Hues)]
    return (From + (To - From) * (Spot - Low)) % 1
end

const function turnAt(Hue: number): number
    const Hues = PropWidget.WheelHues
    for Index = 1, #Hues - 1 do
        const From = Hues[Index]
        const To = Hues[Index + 1]
        if Hue >= From and Hue <= To then
            const Mix = if To > From then (Hue - From) / (To - From) else 0
            return (Index - 1 + Mix) / (#Hues - 1)
        end
    end
    return 0
end

const function fieldHeight(Field: PropData.Field): number
    if Field.Kind == "Color" then
        return LabelHeight + WheelSize
    elseif Field.Kind == "Custom" then
        return LabelHeight + (Field.Height or 40)
    end
    return LabelHeight + InputHeight
end

const function input(Name: string, Properties: Declaration): Declaration
    return Parts.merge({
        ClassName = "TextBox",
        Name = Name,
        Text = "",
        FontFace = Typewriter,
        TextScaled = false,
        TextSize = 17,
        TextColor3 = Common["InkColor"],
        PlaceholderColor3 = Common["MutedColor"],
        BackgroundColor3 = Common["CardColor"],
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        outline(1.6),

        {
            ClassName = "UIPadding",
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6)
        }
    }, Properties)
end

const function pointer(Input: InputObject): Vector2
    return Vector2.new(Input.Position.X, Input.Position.Y)
end

const function track(Target: GuiObject, began: (Point: Vector2) -> (), moved: (Point: Vector2) -> (), Later: (() -> ()) -> ())
    local Holding: InputObject? = nil
    const Links: { RBXScriptConnection } = {}
    table.insert(Links, Target.InputBegan:Connect(function(Input: InputObject)
        const Kind = Input.UserInputType
        if Kind ~= Enum.UserInputType.MouseButton1 and Kind ~= Enum.UserInputType.Touch then
            return
        end
        Holding = Input
        began(pointer(Input))
    end))
    table.insert(Links, UserInputService.InputChanged:Connect(function(Input: InputObject)
        const Held = Holding
        if not Held then
            return
        end
        if Held.UserInputType == Enum.UserInputType.Touch then
            if Input == Held then
                moved(pointer(Input))
            end
        elseif Input.UserInputType == Enum.UserInputType.MouseMovement then
            moved(pointer(Input))
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

const function fieldLabel(Field: PropData.Field, Extra: string?): Declaration
    return text("Label", if Extra then `{Field.Label or Field.Id}  ({Extra})` else Field.Label or Field.Id, {
        Size = UDim2.new(1, 0, 0, LabelHeight - 4),
        TextScaled = false,
        TextSize = 16,
        FontFace = Heading
    })
end

const function round(Value: number): string
    if Value == math.floor(Value) then
        return tostring(Value)
    end
    const Text = (string.gsub(string.format("%.2f", Value), "0+$", ""))
    return Text
end

const function wireColor(Root: Instance, Id: string, Values: { [string]: any }, Later: (() -> ()) -> ())
    const Wheel = Root:FindFirstChild("Wheel") :: ImageButton?
    const Shade = Root:FindFirstChild("Shade") :: ImageButton?
    const Preview = Root:FindFirstChild("Preview") :: Frame?
    const Hex = Root:FindFirstChild("Hex") :: TextBox?
    const Red = Root:FindFirstChild("Red") :: TextBox?
    const Green = Root:FindFirstChild("Green") :: TextBox?
    const Blue = Root:FindFirstChild("Blue") :: TextBox?
    if not (Wheel and Shade and Preview and Hex and Red and Green and Blue) then
        return
    end
    const Cursor = Wheel:FindFirstChild("Cursor") :: Frame?
    const Knob = Shade:FindFirstChild("Knob") :: Frame?
    const Gradient = Shade:FindFirstChildOfClass("UIGradient")
    if not (Cursor and Knob and Gradient) then
        return
    end

    const Start: Color3 = if typeof(Values[Id]) == "Color3" then Values[Id] else Color3.new(1, 1, 1)
    local Hue, Saturation, Bright = Start:ToHSV()

    const function show()
        const Color = Color3.fromHSV(Hue, Saturation, Bright)
        Values[Id] = Color
        Preview.BackgroundColor3 = Color
        Gradient.Color = ColorSequence.new(Color3.fromHSV(Hue, Saturation, 1), Color3.new(0, 0, 0))
        const Angle = turnAt(Hue) * 2 * math.pi
        Cursor.Position = UDim2.fromScale(0.5 + math.cos(Angle) * Saturation * 0.5, 0.5 - math.sin(Angle) * Saturation * 0.5)
        Knob.Position = UDim2.fromScale(0.5, 1 - Bright)
        if not Hex:IsFocused() then
            Hex.Text = `#{string.upper(Color:ToHex())}`
        end
        for Index, Box in { Red, Green, Blue } do
            if not Box:IsFocused() then
                const Channel = if Index == 1 then Color.R elseif Index == 2 then Color.G else Color.B
                Box.Text = tostring(math.round(Channel * 255))
            end
        end
    end

    const function setColor(Color: Color3)
        Hue, Saturation, Bright = Color:ToHSV()
        show()
    end

    const function pickWheel(Point: Vector2)
        const Radius = Wheel.AbsoluteSize.X / 2
        if Radius <= 0 then
            return
        end
        const Offset = Point - (Wheel.AbsolutePosition + Wheel.AbsoluteSize / 2)
        Saturation = math.clamp(Offset.Magnitude / Radius, 0, 1)
        Hue = hueAt(math.atan2(-Offset.Y, Offset.X) / (2 * math.pi))
        show()
    end

    const function pickShade(Point: Vector2)
        const Tall = Shade.AbsoluteSize.Y
        if Tall <= 0 then
            return
        end
        Bright = 1 - math.clamp((Point.Y - Shade.AbsolutePosition.Y) / Tall, 0, 1)
        show()
    end

    track(Wheel, pickWheel, pickWheel, Later)
    track(Shade, pickShade, pickShade, Later)

    Hex.FocusLost:Connect(function()
        const Clean = (string.gsub(Hex.Text, "[^%x]", ""))
        if #Clean == 6 then
            const Ok, Color = pcall(Color3.fromHex, Clean)
            if Ok then
                setColor(Color)
                return
            end
        end
        show()
    end)

    for Index, Box in { Red, Green, Blue } do
        Box.FocusLost:Connect(function()
            const Number = tonumber(Box.Text)
            if not Number then
                show()
                return
            end
            const Current = Color3.fromHSV(Hue, Saturation, Bright)
            const Channels = { Current.R * 255, Current.G * 255, Current.B * 255 }
            Channels[Index] = math.clamp(math.round(Number), 0, 255)
            setColor(Color3.fromRGB(Channels[1], Channels[2], Channels[3]))
        end)
    end

    show()
end

const function colorField(Field: PropData.Field, Values: { [string]: any }, Order: number): Declaration
    const Right = WheelSize + 10 + ShadeWidth + 14
    const Column = Inner - Right
    const Channel = math.floor((Column - 8) / 3)
    const Made: Declaration = {
        ClassName = "Frame",
        Name = `Field_{Field.Id}`,
        Size = UDim2.new(1, 0, 0, fieldHeight(Field)),
        BackgroundTransparency = 1,
        LayoutOrder = Order,

        fieldLabel(Field),

        {
            ClassName = "ImageButton",
            Name = "Wheel",
            Position = UDim2.fromOffset(0, LabelHeight),
            Size = UDim2.fromOffset(WheelSize, WheelSize),
            Image = Images.get("ColorWheel") or "",
            BackgroundTransparency = 1,
            AutoButtonColor = false,

            {
                ClassName = "Frame",
                Name = "Cursor",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(12, 12),
                BackgroundTransparency = 1,

                {
                    ClassName = "UICorner",
                    CornerRadius = UDim.new(1, 0)
                },

                {
                    ClassName = "UIStroke",
                    Color = Color3.new(1, 1, 1),
                    Thickness = 2.5
                }
            }
        },

        {
            ClassName = "ImageButton",
            Name = "Shade",
            Position = UDim2.fromOffset(WheelSize + 10, LabelHeight),
            Size = UDim2.fromOffset(ShadeWidth, WheelSize),
            Image = "",
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            outline(1.6),

            {
                ClassName = "UIGradient",
                Rotation = 90
            },

            {
                ClassName = "Frame",
                Name = "Knob",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0),
                Size = UDim2.new(1, 8, 0, 6),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                outline(1.6)
            }
        },

        {
            ClassName = "Frame",
            Name = "Preview",
            Position = UDim2.fromOffset(Right, LabelHeight),
            Size = UDim2.fromOffset(Column, 40),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            outline(1.6)
        },

        input("Hex", {
            Position = UDim2.fromOffset(Right, LabelHeight + 48),
            Size = UDim2.fromOffset(Column, InputHeight - 4),
            PlaceholderText = "#FFFFFF",
            TextXAlignment = Enum.TextXAlignment.Center
        }),

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            wireColor(Self, Field.Id, Values, Later)
        end)
    }
    for Index, Name in { "Red", "Green", "Blue" } do
        const X = Right + (Index - 1) * (Channel + 4)
        table.insert(Made, input(Name, {
            Position = UDim2.fromOffset(X, LabelHeight + 88),
            Size = UDim2.fromOffset(Channel, InputHeight - 4),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextSize = 15
        }))
        table.insert(Made, text(`{Name}_Label`, string.lower(string.sub(Name, 1, 1)), {
            Position = UDim2.fromOffset(X, LabelHeight + 122),
            Size = UDim2.fromOffset(Channel, 16),
            TextScaled = false,
            TextSize = 14,
            TextColor3 = Common["PackColor"],
            TextXAlignment = Enum.TextXAlignment.Center
        }))
    end
    return Made
end

const function textField(Field: PropData.Field, Values: { [string]: any }, Order: number): Declaration
    const Start = Values[Field.Id]
    return {
        ClassName = "Frame",
        Name = `Field_{Field.Id}`,
        Size = UDim2.new(1, 0, 0, fieldHeight(Field)),
        BackgroundTransparency = 1,
        LayoutOrder = Order,

        fieldLabel(Field, if Field.MaxLength then `max {Field.MaxLength}` else nil),

        input("Input", {
            Position = UDim2.fromOffset(0, LabelHeight),
            Size = UDim2.new(1, 0, 0, InputHeight),
            Text = if type(Start) == "string" then Start else "",
            PlaceholderText = Field.Placeholder or "",
            TextXAlignment = Enum.TextXAlignment.Left,
            PropertyChanged = {
                Text = function(Box: Instance, _, Value: string)
                    local Clean = Value
                    const Limit = Field.MaxLength
                    if Limit and #Clean > Limit then
                        Clean = string.sub(Clean, 1, Limit)
                        const Typed = Box :: TextBox
                        Typed.Text = Clean
                    end
                    Values[Field.Id] = Clean
                end
            }
        })
    }
end

const function wireNumber(Root: Instance, Field: PropData.Field, Values: { [string]: any })
    const Box = Root:FindFirstChild("Input") :: TextBox?
    const Minus = Root:FindFirstChild("Minus") :: TextButton?
    const Plus = Root:FindFirstChild("Plus") :: TextButton?
    if not (Box and Minus and Plus) then
        return
    end
    const Low = Field.Min or -math.huge
    const High = Field.Max or math.huge
    const Step = Field.Step or 1
    local Current = 0

    const function set(Value: number)
        local Next = math.clamp(Value, Low, High)
        if Field.Step then
            Next = math.clamp(math.round(Next / Step) * Step, Low, High)
        end
        Current = Next
        Values[Field.Id] = Next
        Box.Text = round(Next)
    end

    Minus.Activated:Connect(function()
        set(Current - Step)
    end)
    Plus.Activated:Connect(function()
        set(Current + Step)
    end)
    Box.FocusLost:Connect(function()
        set(tonumber(Box.Text) or Current)
    end)

    const Start = Values[Field.Id]
    set(if type(Start) == "number" then Start else if Field.Min then Field.Min else 0)
end

const function numberField(Field: PropData.Field, Values: { [string]: any }, Order: number): Declaration
    const Range = if Field.Min and Field.Max
        then `{round(Field.Min)} to {round(Field.Max)}`
        elseif Field.Min then `at least {round(Field.Min)}`
        elseif Field.Max then `at most {round(Field.Max)}`
        else nil
    const Stepper = function(Name: string, Label: string, Anchor: Vector2, Position: UDim2): Declaration
        return {
            ClassName = "TextButton",
            Name = Name,
            AnchorPoint = Anchor,
            Position = Position,
            Size = UDim2.fromOffset(InputHeight + 6, InputHeight),
            Text = Label,
            FontFace = Heading,
            TextScaled = false,
            TextSize = 22,
            TextColor3 = Common["InkColor"],
            BackgroundColor3 = Common["ButtonColor"],
            BorderSizePixel = 0,
            AutoButtonColor = true,
            outline(1.6)
        }
    end
    return {
        ClassName = "Frame",
        Name = `Field_{Field.Id}`,
        Size = UDim2.new(1, 0, 0, fieldHeight(Field)),
        BackgroundTransparency = 1,
        LayoutOrder = Order,

        fieldLabel(Field, Range),

        Stepper("Minus", "-", Vector2.zero, UDim2.fromOffset(0, LabelHeight)),

        input("Input", {
            Position = UDim2.fromOffset(InputHeight + 14, LabelHeight),
            Size = UDim2.new(1, -(InputHeight + 14) * 2, 0, InputHeight),
            TextXAlignment = Enum.TextXAlignment.Center
        }),

        Stepper("Plus", "+", Vector2.new(1, 0), UDim2.new(1, 0, 0, LabelHeight)),

        vision.ready(function(Self: Instance)
            wireNumber(Self, Field, Values)
        end)
    }
end

const function customField(Field: PropData.Field, Values: { [string]: any }, Order: number): Declaration
    const Holder: Declaration = {
        ClassName = "Frame",
        Name = "Custom",
        Position = UDim2.fromOffset(0, LabelHeight),
        Size = UDim2.new(1, 0, 0, Field.Height or 40),
        BackgroundTransparency = 1
    }
    const Build = Field.build
    if Build then
        const Context: PropData.FieldContext = {
            Id = Field.Id,
            Value = Values[Field.Id],
            get = function(): any
                return Values[Field.Id]
            end,
            set = function(Value: any)
                Values[Field.Id] = Value
            end,
        }
        const Ok, Result = pcall(Build, Context)
        if Ok and type(Result) == "table" then
            table.insert(Holder, Result)
        else
            warn(`[PropWidget] custom field "{Field.Id}" failed to build: {Result}`)
        end
    end
    return {
        ClassName = "Frame",
        Name = `Field_{Field.Id}`,
        Size = UDim2.new(1, 0, 0, fieldHeight(Field)),
        BackgroundTransparency = 1,
        LayoutOrder = Order,
        fieldLabel(Field),
        Holder
    }
end

const function field(Field: PropData.Field, Values: { [string]: any }, Order: number): Declaration
    if Field.Kind == "Color" then
        return colorField(Field, Values, Order)
    elseif Field.Kind == "Text" then
        return textField(Field, Values, Order)
    elseif Field.Kind == "Number" then
        return numberField(Field, Values, Order)
    end
    return customField(Field, Values, Order)
end

const function wireDrag(Root: GuiObject, Header: GuiObject, focus: (Root: GuiObject) -> (), Later: (() -> ()) -> ())
    local Grab = Vector2.zero
    Root.InputBegan:Connect(function(Input: InputObject)
        const Kind = Input.UserInputType
        if Kind == Enum.UserInputType.MouseButton1 or Kind == Enum.UserInputType.Touch then
            focus(Root)
        end
    end)
    track(Header, function(Point: Vector2)
        Grab = Point - Root.AbsolutePosition
    end, function(Point: Vector2)
        const Parent = Root.Parent
        const Room = if Parent and Parent:IsA("GuiBase2d") then Parent.AbsoluteSize else Vector2.new(1920, 1080)
        const Size = Root.AbsoluteSize
        const Spot = Point - Grab
        Root.Position = UDim2.fromOffset(
            math.clamp(Spot.X, 60 - Size.X, Room.X - 60),
            math.clamp(Spot.Y, 0, math.max(Room.Y - 40, 0))
        )
    end, Later)
end

const function shell(Name: string, Title: string, Size: Vector2, Position: Vector2, Mount: Instance, close: () -> (), focus: (Root: GuiObject) -> (), Children: { Declaration }): Declaration
    const Made: Declaration = {
        ClassName = "Frame",
        Name = Name,
        Position = UDim2.fromOffset(Position.X, Position.Y),
        Size = UDim2.fromOffset(Size.X, Size.Y),
        BackgroundColor3 = Common["BackdropColor"],
        BorderSizePixel = 0,
        Active = true,
        vision.mount(Mount),
        outline(2),

        {
            ClassName = "UIScale"
        },

        Parts.bevel("Widget_Bevel", 4, Common["BevelLight"], Common["BevelDark"]),

        {
            ClassName = "Frame",
            Name = "Widget_Header",
            Position = UDim2.fromOffset(Margin, Margin),
            Size = UDim2.new(1, -Margin * 2, 0, HeaderHeight - 6),
            BackgroundColor3 = Common["HeaderColor"],
            BorderSizePixel = 0,
            Active = true,
            outline(2.1),
            Parts.bevel("Widget_Header_Bevel", 3, Common["HeaderShine"], Common["HeaderShade"]),

            text("Widget_Title", Title, {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 14, 0.5, 2),
                Size = UDim2.new(1, -60, 0, 26),
                TextScaled = false,
                TextSize = 22,
                FontFace = Heading,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parts.textOutline(Color3.fromRGB(190, 184, 176), 2)
            }),

            card("Widget_Close", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -6, 0.5, 0),
                Size = UDim2.fromOffset(28, 28)
            }, {
                ClassName = "TextButton",
                Text = "X",
                FontFace = Heading,
                TextScaled = false,
                TextSize = 18,
                TextColor3 = Common["CloseText"],
                BackgroundColor3 = Common["CloseColor"],
                AutoButtonColor = true,
                Activated = function()
                    close()
                end,
                Parts.textOutline()
            }, nil, nil, 1.75)
        },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            const Root = Self :: GuiObject
            VisionKit.fit(Root, Later, MinimumScale)
            const Header = Root:FindFirstChild("Widget_Header") :: GuiObject?
            if Header then
                wireDrag(Root, Header, focus, Later)
            end
        end)
    }
    for _, Child in Children do
        table.insert(Made, Child)
    end
    return Made
end

function PropWidget.bar(Spec: BarSpec): Declaration
    const Count = #Spec.Buttons
    const Gap = Spec.Size * ButtonGap
    const Width = Count * Spec.Size + math.max(Count - 1, 0) * Gap
    const Made: Declaration = {
        ClassName = "BillboardGui",
        Name = Spec.Name,
        Adornee = Spec.Adornee,
        Size = UDim2.fromScale(Width, Spec.Size),
        AlwaysOnTop = true,
        Active = true,
        ResetOnSpawn = false,
        LightInfluence = 0,
        MaxDistance = Spec.MaxDistance,
        Enabled = Spec.Shown,
        vision.mount(Spec.Mount),

        vision.event("Shown", Spec.Shown, function(Self: Instance, _, Value: boolean)
            (Self :: BillboardGui).Enabled = Value
        end),

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(Gap / Width, 0)
        }
    }
    for Order, Button in Spec.Buttons do
        const Made2: Declaration = {
            ClassName = "TextButton",
            Name = Button.Id,
            LayoutOrder = Order,
            Size = UDim2.fromScale(Spec.Size / Width, 1),
            Text = "",
            AutoButtonColor = true,
            BackgroundColor3 = Button.Color or Common["WidgetColor"],
            BorderSizePixel = 0,
            Activated = function()
                Button.press()
            end,

            {
                ClassName = "UICorner",
                CornerRadius = UDim.new(0.3, 0)
            },

            {
                ClassName = "UIStroke",
                Color = Common["InkColor"],
                Thickness = 2,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            }
        }
        if Button.Image then
            table.insert(Made2, {
                ClassName = "ImageLabel",
                Name = "Icon",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(0.68, 0.68),
                BackgroundTransparency = 1,
                Image = Button.Image,
                ScaleType = Enum.ScaleType.Fit
            })
        end
        table.insert(Made, Made2)
    end
    return Made
end

function PropWidget.window(Spec: WindowSpec): Declaration
    local Total = 0
    for Index, Field in Spec.Fields do
        Total += fieldHeight(Field) + if Index > 1 then FieldGap else 0
    end
    const Overflow = Total > MaxBody
    const BodyHeight = math.clamp(Total, 40, MaxBody) + BodyPad * 2
    const Height = Margin + HeaderHeight + 10 + BodyHeight + 12 + SaveHeight + Margin
    const Body: Declaration = {
        ClassName = "ScrollingFrame",
        Name = "Widget_Body",
        Position = UDim2.fromOffset(Margin, Margin + HeaderHeight + 10),
        Size = UDim2.new(1, -Margin * 2, 0, BodyHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollingEnabled = Overflow,
        ScrollBarThickness = if Overflow then 6 else 0,
        ScrollBarImageTransparency = if Overflow then 0 else 1,
        ScrollBarImageColor3 = Common["OutlineColor"],

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, FieldGap)
        },

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0, BodyPad),
            PaddingBottom = UDim.new(0, BodyPad),
            PaddingLeft = UDim.new(0, BodyPad),
            PaddingRight = UDim.new(0, BodyPad + if Overflow then 8 else 0)
        }
    }
    for Order, Field in Spec.Fields do
        table.insert(Body, field(Field, Spec.Values, Order))
    end

    const Save = card("Widget_Save", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, Margin, 1, -Margin),
        Size = UDim2.new(1, -Margin * 2, 0, SaveHeight)
    }, {
        ClassName = "TextButton",
        Text = "save",
        FontFace = Heading,
        TextScaled = false,
        TextSize = 22,
        TextColor3 = Common["SuccessText"],
        BackgroundColor3 = Common["SuccessColor"],
        AutoButtonColor = true,
        Activated = function(Button: Instance)
            Spec.save()
            const Label = Button :: TextButton
            Label.Text = "saved!"
            task.delay(1, function()
                if Label.Parent then
                    Label.Text = "save"
                end
            end)
        end,
        Parts.textOutline()
    }, nil, nil, 2.1)

    return shell(Spec.Name, Spec.Title, Vector2.new(Width, Height), Spec.Position, Spec.Mount, Spec.close, Spec.focus, { Body, Save })
end

const function fillRows(Body: Instance, Rows: { InfoRow })
    for Index, Row in Rows do
        const Holder = Body:FindFirstChild(`Row_{Index}`)
        const Value = if Holder then Holder:FindFirstChild("Value") :: TextLabel? else nil
        if Value then
            Value.Text = Row.Value
        end
    end
end

function PropWidget.info(Spec: InfoSpec): Declaration
    const Height = Margin + HeaderHeight + 10 + #Spec.Rows * InfoRowHeight + BodyPad + Margin
    const Body: Declaration = {
        ClassName = "Frame",
        Name = "Widget_Body",
        Position = UDim2.fromOffset(Margin + BodyPad, Margin + HeaderHeight + 10),
        Size = UDim2.new(1, -(Margin + BodyPad) * 2, 0, #Spec.Rows * InfoRowHeight),
        BackgroundTransparency = 1,

        vision.event("Rows", Spec.Rows, function(Self: Instance, _, Rows: { InfoRow })
            fillRows(Self, Rows)
        end),

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder
        }
    }
    for Index, Row in Spec.Rows do
        table.insert(Body, {
            ClassName = "Frame",
            Name = `Row_{Index}`,
            Size = UDim2.new(1, 0, 0, InfoRowHeight),
            BackgroundTransparency = 1,
            LayoutOrder = Index,

            text("Label", Row.Label, {
                Size = UDim2.new(1, 0, 0, 16),
                TextScaled = false,
                TextSize = 14,
                TextColor3 = Common["OutlineColor"]
            }),

            text("Value", Row.Value, {
                Position = UDim2.fromOffset(0, 17),
                Size = UDim2.new(1, 0, 0, 22),
                TextScaled = false,
                TextSize = 19,
                FontFace = Heading,
                TextTruncate = Enum.TextTruncate.AtEnd
            })
        })
    end
    return shell(Spec.Name, Spec.Title, Vector2.new(InfoWidth, Height), Spec.Position, Spec.Mount, Spec.close, Spec.focus, { Body })
end

return PropWidget
