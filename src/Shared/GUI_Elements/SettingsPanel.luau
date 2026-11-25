--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Bridges = require(ReplicatedStorage.Shared.Utility.Bridges)
const SettingsList = require(ReplicatedStorage.Shared.Utility.SettingsList)
const CommonStyle = require(script.Parent.CommonStyle)
const Parts = require(script.Parent.Parts)
const Scope = vision.Scope()
const _MainStyle = Scope:LoadStyle(table.clone(CommonStyle) :: any)

const Common = vision.style("Common")
const Typewriter = Parts.Typewriter
const Heading = Parts.Heading
const text = Parts.text
const card = Parts.card
const outline = Parts.outline

const Width = 440
const Margin = 16
const HeaderHeight = 52
const RowHeight = 48
const RowGap = 8
const FooterHeight = 48
const MinimumScale = 0.6
const Height = Margin + HeaderHeight + 12 + #SettingsList * (RowHeight + RowGap) + FooterHeight + Margin
const TitleStroke = Color3.fromRGB(190, 184, 176)

const function press(Name: string, Label: string, Outer: { [any]: any }, Fill: any, Ink: any, Action: string, Id: string?, Outlined: boolean?): { [any]: any }
    const Inner: { [any]: any } = {
        ClassName = "TextButton",
        Text = Label,
        FontFace = Heading,
        TextScaled = false,
        TextSize = 18,
        TextColor3 = Ink,
        BackgroundColor3 = Fill,
        AutoButtonColor = true,
        Activated = function()
            Bridges.Settings:Call(Action, Id)
        end
    }
    if Outlined then
        table.insert(Inner, Parts.textOutline())
    end
    return card(Name, Outer, Inner, nil, nil, 2.1)
end

const function control(Setting: SettingsList.Setting): { [any]: any }
    if Setting.Kind == "Toggle" then
        return press("Toggle", "off", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(84, 34)
        }, Common["CloseColor"], Common["CloseText"], "Toggle", Setting.Id, true)
    end
    return {
        ClassName = "Frame",
        Name = "Stepper",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(150, 34),
        BackgroundTransparency = 1,

        press("Down", "-", {
            Size = UDim2.fromOffset(34, 34)
        }, Common["ButtonColor"], Common["InkColor"], "Down", Setting.Id),

        text("Amount", tostring(Setting.Default), {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(70, 28),
            TextScaled = false,
            TextSize = 18,
            FontFace = Heading,
            TextXAlignment = Enum.TextXAlignment.Center
        }),

        press("Up", "+", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.fromScale(1, 0),
            Size = UDim2.fromOffset(34, 34)
        }, Common["ButtonColor"], Common["InkColor"], "Up", Setting.Id)
    }
end

const function row(Setting: SettingsList.Setting, Order: number): { [any]: any }
    return card(`Setting_{Setting.Id}`, {
        Size = UDim2.new(1, 0, 0, RowHeight),
        LayoutOrder = Order
    }, {
        BackgroundColor3 = Common["ButtonColor"],

        text("Name", Setting.Name, {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 14, 0.5, 1),
            Size = UDim2.new(1, -180, 0, 22),
            TextScaled = false,
            TextSize = 18,
            FontFace = Typewriter
        }),

        control(Setting)
    }, nil, nil, 1.6)
end

const function fill(Root: Instance, Values: { [string]: any })
    for _, Setting in SettingsList do
        const Row = Root:FindFirstChild(`Setting_{Setting.Id}`, true)
        const Value = Values[Setting.Id]
        if not Row or Value == nil then
            continue
        end
        if Setting.Kind == "Toggle" then
            const Button = Row:FindFirstChild("Toggle_Body", true) :: TextButton?
            if Button then
                Button.Text = if Value then "on" else "off"
                Button.BackgroundColor3 = if Value then CommonStyle.SuccessColor else CommonStyle.CloseColor
            end
        else
            const Amount = Row:FindFirstChild("Amount", true) :: TextLabel?
            if Amount then
                Amount.Text = tostring(Value)
            end
        end
    end
end

const function rows(): { [any]: any }
    const Made: { [any]: any } = {
        ClassName = "Frame",
        Name = "Settings_Rows",
        Position = UDim2.fromOffset(Margin, Margin + HeaderHeight + 12),
        Size = UDim2.new(1, -Margin * 2, 0, #SettingsList * (RowHeight + RowGap)),
        BackgroundTransparency = 1,

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, RowGap)
        }
    }
    for Order, Setting in SettingsList do
        table.insert(Made, row(Setting, Order))
    end
    return Made
end

return Scope:Capture({
    ClassName = "Frame",
    Name = "Settings_Frame",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(Width, Height),
    BackgroundColor3 = Common["BackdropColor"],
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 45,
    outline(2),

    {
        ClassName = "UIScale"
    },

    vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
        const Root = Self :: GuiObject
        VisionKit.fit(Root, Later, MinimumScale)
        const Header = Root:FindFirstChild("Settings_Header")
        if Header and Header:IsA("GuiObject") then
            Parts.draggable(Root, Header, Later)
        end
    end),

    vision.event("Shown", false, function(Self: Instance, _, Value: boolean)
        (Self :: GuiObject).Visible = Value == true
    end),

    vision.event("Values", {}, function(Self: Instance, _, Value: { [string]: any })
        fill(Self, Value)
    end),

    Parts.bevel("Settings_Bevel", 5, Common["BevelLight"], Common["BevelDark"]),

    {
        ClassName = "Frame",
        Name = "Settings_Header",
        Position = UDim2.fromOffset(Margin, Margin),
        Size = UDim2.new(1, -Margin * 2, 0, HeaderHeight),
        BackgroundColor3 = Common["HeaderColor"],
        BorderSizePixel = 0,
        Active = true,
        outline(2.1),
        Parts.bevel("Settings_Header_Bevel", 4, Common["HeaderShine"], Common["HeaderShade"]),

        text("Settings_Title", "Settings", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 16, 0.5, 2),
            Size = UDim2.new(0.6, 0, 0, 34),
            TextScaled = false,
            TextSize = 30,
            FontFace = Heading,
            Parts.textOutline(TitleStroke, 2)
        }),

        press("Settings_Close", "X", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(36, 36)
        }, Common["CloseColor"], Common["CloseText"], "Close", nil, true)
    },

    rows(),

    press("Settings_Save", "save", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, Margin, 1, -Margin),
        Size = UDim2.new(1, -Margin * 2, 0, FooterHeight)
    }, Common["SuccessColor"], Common["SuccessText"], "Save", nil, true),

    vision.event("Dirty", false, function(Self: Instance, _, Value: boolean)
        const Save = Self:FindFirstChild("Settings_Save_Body", true) :: TextButton?
        if Save then
            Save.Text = if Value then "save changes" else "saved"
        end
    end)
}::Frame & any)
