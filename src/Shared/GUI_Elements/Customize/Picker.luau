--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const PropWidget = require(ReplicatedStorage.Shared.GUI_Elements.PropWidget)
const Images = require(ReplicatedStorage.Shared.Images)
const Bridges = require(ReplicatedStorage.Shared.Customize.Bridges)
const Kit = require(script.Parent.Kit)

export type Request = {
    Title: string,
    Color: Color3,
}

const Style = Kit.Style
const Common = Kit.Common
const Bridge = Bridges.Picker

const Picker = {
    Width = 470,
    Height = 430,
    Wheel = 230,
    Shade = 26,
    LiveRate = 0.1,
}

const Top = Kit.Margin + Kit.HeaderHeight + 14
const Right = Kit.Margin + Picker.Wheel + 12 + Picker.Shade + 16
const Column = Picker.Width - Right - Kit.Margin

local Setter: ((Color: Color3) -> ())? = nil
local Current = Color3.new(1, 1, 1)

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

const function track(Target: GuiObject, Moved: (Point: Vector2) -> (), Released: () -> (), Later: (() -> ()) -> ())
    local Holding: InputObject? = nil
    const Links: { RBXScriptConnection } = {}
    const function point(Input: InputObject): Vector2
        return Vector2.new(Input.Position.X, Input.Position.Y)
    end
    table.insert(Links, Target.InputBegan:Connect(function(Input: InputObject)
        const Kind = Input.UserInputType
        if Kind == Enum.UserInputType.MouseButton1 or Kind == Enum.UserInputType.Touch then
            Holding = Input
            Moved(point(Input))
        end
    end))
    table.insert(Links, UserInputService.InputChanged:Connect(function(Input: InputObject)
        const Held = Holding
        if not Held then
            return
        end
        if (Held.UserInputType == Enum.UserInputType.Touch and Input == Held) or Input.UserInputType == Enum.UserInputType.MouseMovement then
            Moved(point(Input))
        end
    end))
    table.insert(Links, UserInputService.InputEnded:Connect(function(Input: InputObject)
        const Held = Holding
        if Held and (Input == Held or Input.UserInputType == Held.UserInputType) then
            Holding = nil
            Released()
        end
    end))
    Later(function()
        Holding = nil
        for _, Link in Links do
            Link:Disconnect()
        end
    end)
end

const function wire(Root: GuiObject, Later: (() -> ()) -> ())
    const Wheel = Root:FindFirstChild("Picker_Wheel", true) :: ImageButton?
    const Shade = Root:FindFirstChild("Picker_Shade", true) :: ImageButton?
    const Now = Root:FindFirstChild("Picker_Now", true) :: Frame?
    const Hex = Kit.boxOf(Root, "Picker_Hex")
    const Channels = { Kit.boxOf(Root, "Picker_R"), Kit.boxOf(Root, "Picker_G"), Kit.boxOf(Root, "Picker_B") }
    if not Wheel or not Shade or not Now or not Hex then
        return
    end
    const Cursor = Wheel:FindFirstChild("Cursor") :: Frame?
    const Knob = Shade:FindFirstChild("Knob") :: Frame?
    const Gradient = Shade:FindFirstChildOfClass("UIGradient")
    if not Cursor or not Knob or not Gradient then
        return
    end
    local Hue, Saturation, Bright = 0, 0, 1
    local Sent = 0

    const function show(Live: boolean)
        const Color = Color3.fromHSV(Hue, Saturation, Bright)
        Current = Color
        Now.BackgroundColor3 = Color
        Gradient.Color = ColorSequence.new(Color3.fromHSV(Hue, Saturation, 1), Color3.new(0, 0, 0))
        const Angle = turnAt(Hue) * 2 * math.pi
        Cursor.Position = UDim2.fromScale(0.5 + math.cos(Angle) * Saturation * 0.5, 0.5 - math.sin(Angle) * Saturation * 0.5)
        Knob.Position = UDim2.fromScale(0.5, 1 - Bright)
        if not Hex:IsFocused() then
            Hex.Text = `#{string.upper(Color:ToHex())}`
        end
        for Index, Box in Channels do
            if Box and not Box:IsFocused() then
                Box.Text = tostring(math.round((if Index == 1 then Color.R elseif Index == 2 then Color.G else Color.B) * 255))
            end
        end
        if Live and os.clock() - Sent >= Picker.LiveRate then
            Sent = os.clock()
            Bridge:Call("Live", Color)
        end
    end

    const function set(Color: Color3)
        Hue, Saturation, Bright = Color:ToHSV()
        show(false)
    end
    Setter = set

    const function release()
        Sent = 0
        Bridge:Call("Live", Current)
    end

    track(Wheel, function(Point: Vector2)
        const Radius = Wheel.AbsoluteSize.X / 2
        if Radius <= 0 then
            return
        end
        const Offset = Point - (Wheel.AbsolutePosition + Wheel.AbsoluteSize / 2)
        Saturation = math.clamp(Offset.Magnitude / Radius, 0, 1)
        Hue = hueAt(math.atan2(-Offset.Y, Offset.X) / (2 * math.pi))
        show(true)
    end, release, Later)

    track(Shade, function(Point: Vector2)
        const Tall = Shade.AbsoluteSize.Y
        if Tall > 0 then
            Bright = 1 - math.clamp((Point.Y - Shade.AbsolutePosition.Y) / Tall, 0, 1)
            show(true)
        end
    end, release, Later)

    Hex.FocusLost:Connect(function()
        const Clean = (string.gsub(Hex.Text, "[^%x]", ""))
        if #Clean == 6 then
            const Ok, Color = pcall(Color3.fromHex, Clean)
            if Ok then
                set(Color)
                release()
                return
            end
        end
        show(false)
    end)
    for Index, Box in Channels do
        if not Box then
            continue
        end
        Box.FocusLost:Connect(function()
            const Number = tonumber(Box.Text)
            if not Number then
                show(false)
                return
            end
            const Color = Color3.fromHSV(Hue, Saturation, Bright)
            const Values = { Color.R * 255, Color.G * 255, Color.B * 255 }
            Values[Index] = math.clamp(math.round(Number), 0, 255)
            set(Color3.fromRGB(Values[1], Values[2], Values[3]))
            release()
        end)
    end
    Later(function()
        if Setter == set then
            Setter = nil
        end
    end)
    show(false)
end

const function channel(Name: string, Letter: string, Index: number): Kit.Declaration
    const Width = math.floor((Column - 12) / 3)
    return Kit.input(Name, Letter, {
        Position = UDim2.fromOffset(Right + (Index - 1) * (Width + 6), Top + 126),
        Size = UDim2.fromOffset(Width, 32),
    }, function() end)
end

function Picker.build(): Kit.Declaration
    return Kit.panel("Picker", "pick a color", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(Picker.Width, Picker.Height),
        Visible = false,
        ZIndex = 20,

        {
            ClassName = "UIScale",
        },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            VisionKit.fit(Self :: GuiObject, Later, 0.55)
            wire(Self :: GuiObject, Later)
            const Header = Self:FindFirstChild("Picker_Header")
            if Header and Header:IsA("GuiObject") then
                Header.Active = true
                Parts.draggable(Self :: GuiObject, Header, Later)
            end
        end),

        vision.event("PickerOpen", false, function(Self: Instance, _, Value: Request | false)
            const Frame = Self :: GuiObject
            if not Value then
                Frame.Visible = false
                return
            end
            Frame.Visible = true
            Kit.label(Frame, "Picker_Title", Value.Title)
            const Was = Frame:FindFirstChild("Picker_Was", true)
            if Was and Was:IsA("Frame") then
                Was.BackgroundColor3 = Value.Color
            end
            const Set = Setter
            if Set then
                Set(Value.Color)
            end
        end),
    }, {
        {
            ClassName = "ImageButton",
            Name = "Picker_Wheel",
            Position = UDim2.fromOffset(Kit.Margin, Top),
            Size = UDim2.fromOffset(Picker.Wheel, Picker.Wheel),
            Image = Images.get("ColorWheel") or "",
            BackgroundTransparency = 1,
            AutoButtonColor = false,

            {
                ClassName = "Frame",
                Name = "Cursor",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(14, 14),
                BackgroundTransparency = 1,
                { ClassName = "UICorner", CornerRadius = UDim.new(1, 0) },
                { ClassName = "UIStroke", Color = Color3.new(1, 1, 1), Thickness = 3 },
            },
        },

        {
            ClassName = "ImageButton",
            Name = "Picker_Shade",
            Position = UDim2.fromOffset(Kit.Margin + Picker.Wheel + 12, Top),
            Size = UDim2.fromOffset(Picker.Shade, Picker.Wheel),
            Image = "",
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Parts.outline(Kit.ItemStroke),
            { ClassName = "UIGradient", Rotation = 90 },
            {
                ClassName = "Frame",
                Name = "Knob",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0),
                Size = UDim2.new(1, 10, 0, 7),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                Parts.outline(Kit.ItemStroke),
            },
        },

        Kit.text("Picker_NowLabel", "new", 13, {
            Position = UDim2.fromOffset(Right, Top - 2),
            Size = UDim2.fromOffset(Column / 2, 16),
            TextColor3 = Common["OutlineColor"],
        }),
        Kit.text("Picker_WasLabel", "was", 13, {
            Position = UDim2.fromOffset(Right + Column / 2, Top - 2),
            Size = UDim2.fromOffset(Column / 2, 16),
            TextColor3 = Common["OutlineColor"],
        }),
        {
            ClassName = "Frame",
            Name = "Picker_Now",
            Position = UDim2.fromOffset(Right, Top + 18),
            Size = UDim2.fromOffset(Column / 2, 54),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parts.outline(Kit.Stroke),
        },
        {
            ClassName = "Frame",
            Name = "Picker_Was",
            Position = UDim2.fromOffset(Right + Column / 2, Top + 18),
            Size = UDim2.fromOffset(Column / 2, 54),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parts.outline(Kit.Stroke),
        },

        Kit.input("Picker_Hex", "#FFFFFF", {
            Position = UDim2.fromOffset(Right, Top + 84),
            Size = UDim2.fromOffset(Column, 32),
        }, function() end),

        channel("Picker_R", "r", 1),
        channel("Picker_G", "g", 2),
        channel("Picker_B", "b", 3),

        Kit.press("Picker_Cancel", "cancel", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, Kit.Margin, 1, -Kit.Margin),
            Size = UDim2.new(0.5, -(Kit.Margin + 6), 0, 48),
        }, Style.PlateColor, Style.InkColor, Bridge, "Cancel", nil, false, 18),

        Kit.press("Picker_Use", "use color", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -Kit.Margin, 1, -Kit.Margin),
            Size = UDim2.new(0.5, -(Kit.Margin + 6), 0, 48),
        }, Style.SuccessColor, Style.SuccessText, Bridge, "Use", nil, true, 18),
    })
end

function Picker.current(): Color3
    return Current
end

return Picker
