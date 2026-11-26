--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Bridges = require(ReplicatedStorage.Shared.Utility.Bridges)
const CommonStyle = require(script.Parent.CommonStyle)
const Parts = require(script.Parent.Parts)
const Scope = vision.Scope()
const _MainStyle = Scope:LoadStyle(table.clone(CommonStyle) :: any)

export type ButtonView = {
    Id: string,
    Text: string,
    Color: Color3,
    Ink: Color3,
    Icon: string?,
    Key: string?,
    Active: boolean,
    Toggle: boolean,
    Order: number,
}

const Common = vision.style("Common")
const Heading = Parts.Heading
const text = Parts.text
const card = Parts.card
const outline = Parts.outline

const ButtonWidth = 216
const ButtonHeight = 60
const Gap = 10
const Pad = 14
const TrayWidth = ButtonWidth + Pad * 2
const PerColumn = 8
const TabWidth = 32
const TabHeight = 84
const EdgeGap = 16
const MinimumScale = 0.8
const Bevel = 4
const Slide = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

const Rendered: { vision.Vision } = {}

const function heightFor(Count: number): number
    const Rows = math.clamp(Count, 1, PerColumn)
    return Pad * 2 + Rows * ButtonHeight + (Rows - 1) * Gap
end

const function widthFor(Count: number): number
    const Columns = math.max(math.ceil(Count / PerColumn), 1)
    return Pad * 2 + Columns * ButtonWidth + (Columns - 1) * Gap
end

const function button(View: ButtonView, List: Instance): { [any]: any }
    const Inner: { [any]: any } = {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = View.Color,
        Activated = function()
            Bridges.SidebarPress:Call(View.Id)
        end,

        Parts.bevel("Shine", Bevel, View.Color:Lerp(Color3.new(1, 1, 1), 0.35), View.Color:Lerp(Color3.new(0, 0, 0), 0.3)),

        text("Label", View.Text, {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, if View.Icon then 54 else 16, 0.5, 1),
            Size = UDim2.new(1, if View.Icon then -104 else -64, 0, 26),
            TextScaled = false,
            TextSize = 22,
            FontFace = Heading,
            TextColor3 = View.Ink,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parts.textOutline()
        })
    }
    if View.Icon then
        table.insert(Inner, {
            ClassName = "ImageLabel",
            Name = "Icon",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.fromOffset(34, 34),
            BackgroundTransparency = 1,
            Image = View.Icon,
            ScaleType = Enum.ScaleType.Fit
        })
    end
    if View.Key then
        table.insert(Inner, Parts.keyBadge(View.Key, 28, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            ZIndex = 11
        }))
    end
    return card(`Side_{View.Id}`, {
        Size = UDim2.fromOffset(ButtonWidth, ButtonHeight),
        LayoutOrder = View.Order,
        vision.mount(List)
    }, Inner, nil, nil, 2.1)
end

const function render(List: Instance, Views: { ButtonView })
    for _, Item in Rendered do
        Item:Cleanup()
    end
    table.clear(Rendered)
    for _, View in Views do
        const Item = Scope:Capture(button(View, List))
        Item:Mount()
        table.insert(Rendered, Item)
    end
    const Tray = List.Parent
    if Tray and Tray:IsA("GuiObject") then
        Tray.Size = UDim2.fromOffset(widthFor(#Views), heightFor(#Views))
    end
end

const function placement(Frame: GuiObject, Open: boolean): UDim2
    return if Open then UDim2.new(0, EdgeGap, 0.5, 0) else UDim2.new(0, -Frame.AbsoluteSize.X - 2, 0.5, 0)
end

return Scope:Capture({
    ClassName = "Frame",
    Name = "Sidebar",
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, EdgeGap, 0.5, 0),
    Size = UDim2.fromOffset(TrayWidth, heightFor(1)),
    BackgroundColor3 = Common["BackdropColor"],
    BorderSizePixel = 0,
    outline(2),

    {
        ClassName = "UIScale"
    },

    vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
        VisionKit.fit(Self :: GuiObject, Later, MinimumScale)
    end),

    PropertyChanged = {
        AbsoluteSize = function(Self: Instance)
            const Frame = Self :: GuiObject
            if Frame:GetAttribute("SidebarOpen") == false then
                Frame.Position = placement(Frame, false)
            end
        end
    },

    vision.event("Expanded", true, function(Self: Instance, _, Value: boolean)
        const Frame = Self :: GuiObject
        Frame:SetAttribute("SidebarOpen", Value)
        TweenService:Create(Frame, Slide, { Position = placement(Frame, Value) }):Play()
        const Tab = Frame:FindFirstChild("Sidebar_Tab", true)
        const Arrow = if Tab then Tab:FindFirstChild("Sidebar_Tab_Body") :: TextButton? else nil
        if Arrow then
            Arrow.Text = if Value then "<" else ">"
        end
    end),

    vision.cleanup(function()
        for _, Item in Rendered do
            Item:Cleanup()
        end
        table.clear(Rendered)
    end),

    Parts.bevel("Sidebar_Bevel", 4, Common["BevelLight"], Common["BevelDark"]),

    {
        ClassName = "Frame",
        Name = "Sidebar_List",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,

        vision.event("Buttons", {}, function(List: Instance, _, Views: { ButtonView })
            render(List, Views)
        end),

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0, Pad),
            PaddingBottom = UDim.new(0, Pad),
            PaddingLeft = UDim.new(0, Pad),
            PaddingRight = UDim.new(0, Pad)
        },

        {
            ClassName = "UIGridLayout",
            FillDirection = Enum.FillDirection.Vertical,
            FillDirectionMaxCells = PerColumn,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            SortOrder = Enum.SortOrder.LayoutOrder,
            CellSize = UDim2.fromOffset(ButtonWidth, ButtonHeight),
            CellPadding = UDim2.fromOffset(Gap, Gap)
        }
    },

    card("Sidebar_Tab", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(1, 6, 0.5, 0),
        Size = UDim2.fromOffset(TabWidth, TabHeight)
    }, {
        ClassName = "TextButton",
        Text = "<",
        FontFace = Heading,
        TextScaled = false,
        TextSize = 28,
        TextColor3 = Common["InkColor"],
        BackgroundColor3 = Common["PlateColor"],
        AutoButtonColor = true,
        Activated = function()
            Bridges.SidebarToggle:Call("Tab")
        end
    }, nil, nil, 2.1)
}::Frame & any)
