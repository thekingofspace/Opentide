--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const WidgetTypes = require(ReplicatedStorage.Shared.UI.WidgetTypes)
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Bridges = require(ReplicatedStorage.Shared.PropPlacer.Bridges)
const Config = require(ReplicatedStorage.Shared.PropData.Config)
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

const DesignSize = Vector2.new(600, 640)
const Margin = 14
const Bevel = 5
const HeaderHeight = 54
const HeaderBevel = 4
const HintHeight = 22
const WellTop = Margin + HeaderHeight + 8 + HintHeight + 8
const WellRim = 3
const RowHeight = 86
const PlateSize = 62
const ButtonHeight = 44
const SaveWidth = 88
const LoadWidth = 88
const ClearWidth = 44
const ButtonGap = 8
const ButtonEdge = 12
const ButtonStroke = 2.1
const ItemStroke = 1.6
const ButtonText = 19
const MinimumScale = 0.55
const TitleStroke = Color3.fromRGB(190, 184, 176)
const DefaultHint = "save your placed props, then load them near you or where they were"
const FilledSave = UDim2.new(1, -(ButtonEdge + ClearWidth + LoadWidth + ButtonGap * 2), 0.5, 0)
const EmptySave = UDim2.new(1, -ButtonEdge, 0.5, 0)

export type Slot = WidgetTypes.SaveSlot

const function press(Name: string, Label: string, Outer: { [any]: any }, Fill: any, Ink: any, Action: string, Slot: number?, Outlined: boolean?): { [any]: any }
    const Inner: { [any]: any } = {
        ClassName = "TextButton",
        Text = Label,
        FontFace = Typewriter,
        TextScaled = false,
        TextSize = ButtonText,
        TextColor3 = Ink,
        BackgroundColor3 = Fill,
        AutoButtonColor = true,
        Activated = function()
            Bridges.Saves:Call(Action, Slot)
        end
    }
    if Outlined then
        table.insert(Inner, Parts.textOutline())
    end
    return card(Name, Outer, Inner, nil, nil, ButtonStroke)
end

const function row(Slot: number): { [any]: any }
    return card(`Save_Slot_{Slot}`, {
        Size = UDim2.new(1, 0, 0, RowHeight),
        LayoutOrder = Slot
    }, {
        BackgroundColor3 = Common["CardColor"],

        card(`Save_Slot_{Slot}_Plate`, {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.fromOffset(PlateSize, PlateSize)
        }, {
            BackgroundColor3 = Common["PlateColor"],

            text("Number", tostring(Slot), {
                Position = UDim2.fromOffset(0, 2),
                Size = UDim2.fromScale(1, 1),
                TextScaled = false,
                TextSize = 34,
                FontFace = Heading,
                TextXAlignment = Enum.TextXAlignment.Center
            })
        }, nil, nil, 1.75),

        {
            ClassName = "TextBox",
            Name = "Title",
            Position = UDim2.fromOffset(PlateSize + 22, 9),
            Size = UDim2.fromOffset(210, 28),
            Text = "",
            PlaceholderText = `name slot {Slot}`,
            PlaceholderColor3 = Common["MutedColor"],
            TextColor3 = Common["InkColor"],
            FontFace = Heading,
            TextScaled = false,
            TextSize = 20,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ClearTextOnFocus = false,
            BackgroundColor3 = Common["PlateColor"],
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            FocusLost = function(Box: Instance)
                Bridges.Saves:Call("Name", Slot, (Box :: TextBox).Text)
            end,
            outline(1.5),

            {
                ClassName = "UIPadding",
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6)
            }
        },

        text("Detail", "empty slot", {
            Position = UDim2.fromOffset(PlateSize + 26, 40),
            Size = UDim2.fromOffset(200, 18),
            TextScaled = false,
            TextSize = 16,
            TextColor3 = Common["PackColor"]
        }),

        text("Stamp", "", {
            Position = UDim2.fromOffset(PlateSize + 26, 60),
            Size = UDim2.fromOffset(200, 16),
            TextScaled = false,
            TextSize = 14,
            TextColor3 = Common["MutedColor"]
        }),

        press(`Save_Slot_{Slot}_Save`, "save", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = EmptySave,
            Size = UDim2.fromOffset(SaveWidth, ButtonHeight)
        }, Common["AccentColor"], Common["AccentText"], "Save", Slot, true),

        press(`Save_Slot_{Slot}_Load`, "load", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -(ButtonEdge + ClearWidth + ButtonGap), 0.5, 0),
            Size = UDim2.fromOffset(LoadWidth, ButtonHeight),
            Visible = false
        }, Common["CardColor"], Common["InkColor"], "Load", Slot),

        press(`Save_Slot_{Slot}_Clear`, "X", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -ButtonEdge, 0.5, 0),
            Size = UDim2.fromOffset(ClearWidth, ButtonHeight),
            Visible = false
        }, Common["CloseColor"], Common["CloseText"], "Clear", Slot, true)
    }, nil, nil, ItemStroke)
end

const function well(): { [any]: any }
    const List: { [any]: any } = {
        ClassName = "Frame",
        Name = "Save_List",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10)
        },

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8)
        }
    }
    for Slot = 1, Config.SaveSlots do
        table.insert(List, row(Slot))
    end
    return {
        ClassName = "Frame",
        Name = "Save_Well",
        Position = UDim2.fromOffset(Margin, WellTop),
        Size = UDim2.new(1, -Margin * 2, 1, -(WellTop + Margin)),
        BackgroundColor3 = Common["WellColor"],
        BorderSizePixel = 0,
        outline(ButtonStroke),
        Parts.bevel("Save_Well_Rim", WellRim, Common["WellShade"], Common["WellLight"]),
        List
    }
end

const function find(Root: Instance, Name: string): Instance?
    return Root:FindFirstChild(Name, true)
end

const function fillSlots(Root: Instance, Value: { [number]: Slot })
    for Slot = 1, Config.SaveSlots do
        const Info: Slot = Value[Slot] or { Name = "", Detail = "empty slot", Stamp = "", Filled = false, Confirm = false, ConfirmClear = false }
        const Body = find(Root, `Save_Slot_{Slot}_Body`) :: GuiObject?
        if not Body then
            continue
        end
        Body.BackgroundColor3 = if Info.Filled then CommonStyle.ButtonColor else CommonStyle.CardColor

        const Detail = Body:FindFirstChild("Detail") :: TextLabel?
        if Detail then
            Detail.Text = Info.Detail
        end
        const Title = Body:FindFirstChild("Title") :: TextBox?
        if Title and not Title:IsFocused() then
            Title.Text = Info.Name
        end
        const Stamp = Body:FindFirstChild("Stamp") :: TextLabel?
        if Stamp then
            Stamp.Text = Info.Stamp
        end

        const Plate = find(Body, `Save_Slot_{Slot}_Plate_Body`) :: GuiObject?
        if Plate then
            Plate.BackgroundColor3 = if Info.Filled then CommonStyle.AccentColor else CommonStyle.PlateColor
            const Number = Plate:FindFirstChild("Number") :: TextLabel?
            if Number then
                Number.TextColor3 = if Info.Filled then CommonStyle.AccentText else CommonStyle.InkColor
            end
        end

        const Save = Body:FindFirstChild(`Save_Slot_{Slot}_Save`) :: GuiObject?
        if Save then
            Save.Position = if Info.Filled then FilledSave else EmptySave
            const Button = Save:FindFirstChild(`Save_Slot_{Slot}_Save_Body`) :: TextButton?
            if Button then
                Button.Text = if Info.Confirm then "sure?" else "save"
            end
        end
        const Load = Body:FindFirstChild(`Save_Slot_{Slot}_Load`) :: GuiObject?
        if Load then
            Load.Visible = Info.Filled
        end
        const Clear = Body:FindFirstChild(`Save_Slot_{Slot}_Clear`) :: GuiObject?
        if Clear then
            Clear.Visible = Info.Filled
            const Button = Clear:FindFirstChild(`Save_Slot_{Slot}_Clear_Body`) :: TextButton?
            if Button then
                Button.Text = if Info.ConfirmClear then "?" else "X"
            end
        end
    end
end

const function option(Name: string, Label: string, Detail: string, Anchor: Vector2, Position: UDim2, Fill: any, Ink: any, Muted: any, Action: string, Outlined: boolean): { [any]: any }
    const Title = text("Option_Title", Label, {
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 26),
        TextScaled = false,
        TextSize = 24,
        FontFace = Heading,
        TextColor3 = Ink,
        TextXAlignment = Enum.TextXAlignment.Center
    })
    if Outlined then
        table.insert(Title, Parts.textOutline())
    end
    return card(Name, {
        AnchorPoint = Anchor,
        Position = Position,
        Size = UDim2.new(0.5, -26, 0, 100)
    }, {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Fill,
        Activated = function()
            Bridges.Saves:Call(Action, nil)
        end,

        Title,

        text("Option_Detail", Detail, {
            Position = UDim2.fromOffset(10, 56),
            Size = UDim2.new(1, -20, 0, 34),
            TextScaled = false,
            TextSize = 14,
            TextWrapped = true,
            TextColor3 = Muted,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Top
        })
    }, nil, nil, ButtonStroke)
end

const function ask(): { [any]: any }
    return {
        ClassName = "Frame",
        Name = "Save_Ask",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 60,

        vision.event("Ask", false, function(Self: Instance, _, Value: number | false)
            const Frame = Self :: GuiObject
            Frame.Visible = type(Value) == "number"
            const Title = find(Frame, "Save_Ask_Title") :: TextLabel?
            if Title and type(Value) == "number" then
                Title.Text = `load slot {Value}`
            end
        end),

        {
            ClassName = "Frame",
            Name = "Save_Ask_Card",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(470, 290),
            BackgroundColor3 = Common["BackdropColor"],
            BorderSizePixel = 0,
            outline(2.5),
            Parts.bevel("Save_Ask_Bevel", Bevel, Common["BevelLight"], Common["BevelDark"]),

            text("Save_Ask_Title", "load slot", {
                Position = UDim2.fromOffset(20, 20),
                Size = UDim2.new(1, -40, 0, 32),
                TextScaled = false,
                TextSize = 30,
                FontFace = Heading,
                TextXAlignment = Enum.TextXAlignment.Center,
                Parts.textOutline(TitleStroke, 2)
            }),

            text("Save_Ask_Detail", "where should the props go?", {
                Position = UDim2.fromOffset(20, 58),
                Size = UDim2.new(1, -40, 0, 20),
                TextScaled = false,
                TextSize = 16,
                TextColor3 = Common["PackColor"],
                TextXAlignment = Enum.TextXAlignment.Center
            }),

            option("Save_Ask_Here", "near me", "move them into place with the tools", Vector2.zero, UDim2.fromOffset(20, 92), Common["AccentColor"], Common["AccentText"], Common["AccentText"], "Here", true),
            option("Save_Ask_Spot", "save spot", "exactly where they were saved", Vector2.new(1, 0), UDim2.new(1, -20, 0, 92), Common["ButtonColor"], Common["InkColor"], Common["PackColor"], "Spot", false),

            press("Save_Ask_Back", "back", {
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, -20),
                Size = UDim2.fromOffset(150, ButtonHeight)
            }, Common["PlateColor"], Common["InkColor"], "Back", nil)
        }
    }
end

return Scope:Capture({
    ClassName = "Frame",
    Name = "Save_Frame",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(DesignSize.X, DesignSize.Y),
    BackgroundColor3 = Common["BackdropColor"],
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 40,
    outline(2),

    {
        ClassName = "UIScale"
    },

    vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
        VisionKit.fit(Self :: GuiObject, Later, MinimumScale)
    end),

    vision.event("Shown", false, function(Self: Instance, _, Value: boolean)
        (Self :: GuiObject).Visible = Value == true
    end),

    vision.event("Slots", {}, function(Self: Instance, _, Value: { [number]: Slot })
        fillSlots(Self, Value)
    end),

    Parts.bevel("Save_Bevel", Bevel, Common["BevelLight"], Common["BevelDark"]),

    {
        ClassName = "Frame",
        Name = "Save_Header",
        Position = UDim2.fromOffset(Margin, Margin),
        Size = UDim2.new(1, -Margin * 2, 0, HeaderHeight),
        BackgroundColor3 = Common["HeaderColor"],
        BorderSizePixel = 0,
        outline(ButtonStroke),
        Parts.bevel("Save_Header_Bevel", HeaderBevel, Common["HeaderShine"], Common["HeaderShade"]),

        text("Save_Title", "Saves", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 16, 0.5, 2),
            Size = UDim2.new(0.6, 0, 0, 34),
            TextScaled = false,
            TextSize = 32,
            FontFace = Heading,
            Parts.textOutline(TitleStroke, 2)
        }),

        press("Save_Close", "X", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(38, 38)
        }, Common["CloseColor"], Common["CloseText"], "Close", nil, true)
    },

    text("Save_Hint", DefaultHint, {
        Position = UDim2.fromOffset(Margin + 4, Margin + HeaderHeight + 8),
        Size = UDim2.new(1, -(Margin + 4) * 2, 0, HintHeight),
        TextScaled = false,
        TextSize = 14,
        TextWrapped = true,
        TextColor3 = Common["OutlineColor"],

        vision.event("Hint", DefaultHint, function(Label: Instance, _, Value: string)
            (Label :: TextLabel).Text = Value
        end)
    }),

    well(),
    ask()
}::Frame & any)
