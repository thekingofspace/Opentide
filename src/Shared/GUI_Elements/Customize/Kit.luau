--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const vision = require(ReplicatedStorage.MainPackages.vision)
const CommonStyle = require(ReplicatedStorage.Shared.GUI_Elements.CommonStyle)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Bridges = require(ReplicatedStorage.Shared.Customize.Bridges)

export type Declaration = { [any]: any }

export type Item = {
    Key: string,
    Hash: string,
    Build: () -> Declaration,
}

type Synced = {
    Vision: vision.Vision,
    Hash: string,
}

const Scope = vision.Scope()
const _MainStyle = Scope:LoadStyle(table.clone(CommonStyle) :: any)
const Common = vision.style("Common")
const White = Color3.new(1, 1, 1)
const Black = Color3.new(0, 0, 0)

const Kit = {
    Scope = Scope,
    Common = Common,
    Style = CommonStyle,
    Stroke = 2.1,
    ItemStroke = 1.6,
    Depth = 4,
    Spin = 0.45,
    Margin = 14,
    HeaderHeight = 52,
    TitleStroke = Color3.fromRGB(190, 184, 176),
    Picked = Color3.fromRGB(255, 214, 90),
    SheetColor = CommonStyle.BackdropColor:Lerp(White, 0.62),
    GroupColor = CommonStyle.WidgetColor:Lerp(White, 0.45),
    FigureSize = Vector2.new(170, 232),
    Figure = {
        Head = { 65, 0, 40, 38 },
        UpperTorso = { 55, 42, 60, 52 },
        LowerTorso = { 55, 96, 60, 22 },
        RightUpperArm = { 31, 42, 22, 36 },
        RightLowerArm = { 31, 80, 22, 30 },
        RightHand = { 31, 112, 22, 16 },
        LeftUpperArm = { 117, 42, 22, 36 },
        LeftLowerArm = { 117, 80, 22, 30 },
        LeftHand = { 117, 112, 22, 16 },
        RightUpperLeg = { 55, 122, 28, 44 },
        RightLowerLeg = { 55, 168, 28, 40 },
        RightFoot = { 55, 210, 28, 18 },
        LeftUpperLeg = { 87, 122, 28, 44 },
        LeftLowerLeg = { 87, 168, 28, 40 },
        LeftFoot = { 87, 210, 28, 18 },
    } :: { [string]: { number } },
}

const Rendered: { [Instance]: { vision.Vision } } = {}
const Keyed: { [Instance]: { [string]: Synced } } = {}

function Kit.light(Color: Color3): Color3
    return Color:Lerp(White, 0.35)
end

function Kit.dark(Color: Color3): Color3
    return Color:Lerp(Black, 0.28)
end

function Kit.text(Name: string, Value: string, Size: number, Properties: Declaration?): Declaration
    return Parts.text(Name, Value, Parts.merge({
        TextScaled = false,
        TextSize = Size,
        Size = UDim2.new(1, 0, 0, Size + 6),
    }, Properties or {}))
end

function Kit.press(Name: string, Label: string, Outer: Declaration, Fill: Color3, Ink: Color3, Bridge: Bridges.ActBridge, Action: string, Value: any?, Outlined: boolean?, TextSize: number?): Declaration
    const Inner: Declaration = {
        ClassName = "TextButton",
        Text = Label,
        FontFace = Parts.Heading,
        TextScaled = false,
        TextSize = TextSize or 17,
        TextColor3 = Ink,
        BackgroundColor3 = Fill,
        AutoButtonColor = true,
        Activated = function()
            Bridge:Call(Action, Value)
        end,
        Parts.bevel(`{Name}_Shine`, 3, Kit.light(Fill), Kit.dark(Fill)),
    }
    if Outlined then
        table.insert(Inner, Parts.textOutline())
    end
    return Parts.card(Name, Outer, Inner, Kit.Depth, nil, Kit.Stroke)
end

function Kit.close(Name: string, Outer: Declaration, Bridge: Bridges.ActBridge, Action: string, Value: any?, Size: number?): Declaration
    const Side = Size or 38
    Outer.Size = UDim2.fromOffset(Side, Side)
    return Parts.card(Name, Outer, {
        ClassName = "TextButton",
        Text = "X",
        FontFace = Parts.Heading,
        TextScaled = false,
        TextSize = math.floor(Side * 0.5),
        TextColor3 = CommonStyle.CloseText,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        BackgroundColor3 = CommonStyle.CloseColor,
        AutoButtonColor = true,
        Activated = function()
            Bridge:Call(Action, Value)
        end,
        Parts.textOutline(),
    }, nil, nil, Kit.Stroke)
end

function Kit.setButton(Root: Instance, Name: string, Label: string?, Fill: Color3?, Ink: Color3?)
    const Button = Root:FindFirstChild(`{Name}_Body`, true)
    if not Button or not Button:IsA("TextButton") then
        return
    end
    if Label then
        Button.Text = Label
    end
    if Ink then
        Button.TextColor3 = Ink
    end
    if not Fill then
        return
    end
    Button.BackgroundColor3 = Fill
    const Shine = Button:FindFirstChild(`{Name}_Shine`)
    if not Shine then
        return
    end
    for _, Edge in Shine:GetChildren() do
        if Edge:IsA("Frame") then
            const Lit = string.match(Edge.Name, "_Top$") or string.match(Edge.Name, "_Left$")
            Edge.BackgroundColor3 = if Lit then Kit.light(Fill) else Kit.dark(Fill)
        end
    end
end

function Kit.input(Name: string, Placeholder: string, Outer: Declaration, Commit: (Text: string, Box: TextBox) -> (), Typed: ((Text: string) -> ())?): Declaration
    return Parts.card(Name, Outer, {
        ClassName = "TextBox",
        Text = "",
        PlaceholderText = Placeholder,
        PlaceholderColor3 = Common["MutedColor"],
        TextColor3 = Common["InkColor"],
        FontFace = Parts.Typewriter,
        TextScaled = false,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClearTextOnFocus = false,
        BackgroundColor3 = Common["CardColor"],
        FocusLost = function(Box: Instance, _, Enter: boolean)
            if Enter then
                Commit((Box :: TextBox).Text, Box :: TextBox)
            end
        end,
        PropertyChanged = {
            Text = function(_, _, Value: string)
                if Typed then
                    Typed(Value)
                end
            end,
        },

        {
            ClassName = "UIPadding",
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
        },
    }, nil, nil, Kit.ItemStroke)
end

function Kit.boxText(Root: Instance, Name: string, Value: string)
    const Box = Root:FindFirstChild(`{Name}_Body`, true)
    if Box and Box:IsA("TextBox") and not Box:IsFocused() then
        Box.Text = Value
    end
end

function Kit.boxOf(Root: Instance, Name: string): TextBox?
    const Box = Root:FindFirstChild(`{Name}_Body`, true)
    return if Box and Box:IsA("TextBox") then Box else nil
end

function Kit.show(Root: Instance, Name: string, Visible: boolean)
    const Found = Root:FindFirstChild(Name, true)
    if Found and Found:IsA("GuiObject") then
        Found.Visible = Visible
    end
end

function Kit.label(Root: Instance, Name: string, Value: string)
    const Found = Root:FindFirstChild(Name, true)
    if Found and (Found:IsA("TextLabel") or Found:IsA("TextButton")) then
        Found.Text = Value
    end
end

function Kit.panel(Name: string, Title: string, Outer: Declaration, Children: { any }): Declaration
    const Made: Declaration = Parts.merge({
        ClassName = "Frame",
        Name = Name,
        BackgroundColor3 = Common["BackdropColor"],
        BorderSizePixel = 0,
        Parts.outline(2),
        Parts.bevel(`{Name}_Bevel`, 5, Common["BevelLight"], Common["BevelDark"]),

        {
            ClassName = "Frame",
            Name = `{Name}_Header`,
            Position = UDim2.fromOffset(Kit.Margin, Kit.Margin),
            Size = UDim2.new(1, -Kit.Margin * 2, 0, Kit.HeaderHeight),
            BackgroundColor3 = Common["HeaderColor"],
            BorderSizePixel = 0,
            Parts.outline(Kit.Stroke),
            Parts.bevel(`{Name}_Header_Bevel`, 4, Common["HeaderShine"], Common["HeaderShade"]),

            Parts.text(`{Name}_Title`, Title, {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 14, 0.5, 2),
                Size = UDim2.new(1, -28, 0, 32),
                TextScaled = false,
                TextSize = 26,
                FontFace = Parts.Heading,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parts.textOutline(Kit.TitleStroke, 2),
            }),
        },
    }, Outer)
    for _, Child in Children do
        table.insert(Made, Child)
    end
    return Made
end

function Kit.scroller(Name: string, Outer: Declaration?, Pad: number?): Declaration
    const Inset = Pad or 10
    return Parts.merge({
        ClassName = "ScrollingFrame",
        Name = Name,
        BackgroundColor3 = Common["WellColor"],
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 8,
        ScrollBarImageColor3 = Common["OutlineColor"],
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        Parts.outline(Kit.Stroke),

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10),
        },

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0, Inset),
            PaddingBottom = UDim.new(0, Inset + 2),
            PaddingLeft = UDim.new(0, Inset),
            PaddingRight = UDim.new(0, Inset),
        },
    }, Outer or {})
end

function Kit.body(Name: string, Top: number?): Declaration
    const Offset = Top or (Kit.Margin + Kit.HeaderHeight + 10)
    return Kit.scroller(Name, {
        Position = UDim2.fromOffset(Kit.Margin, Offset),
        Size = UDim2.new(1, -Kit.Margin * 2, 1, -(Offset + Kit.Margin)),
    })
end

function Kit.section(Name: string, Title: string, Order: number, Children: { Declaration }): Declaration
    const Made: Declaration = {
        ClassName = "Frame",
        Name = Name,
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Kit.SheetColor,
        BorderSizePixel = 0,
        LayoutOrder = Order,
        Parts.outline(Kit.ItemStroke),

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        },

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 14),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
        },

        Kit.text(`{Name}_Title`, Title, 18, {
            FontFace = Parts.Heading,
            LayoutOrder = 0,
        }),
    }
    for Index, Child in Children do
        Child.LayoutOrder = Child.LayoutOrder or Index
        table.insert(Made, Child)
    end
    return Made
end

function Kit.row(Name: string, Height: number, Order: number?, Children: { Declaration }): Declaration
    const Made: Declaration = {
        ClassName = "Frame",
        Name = Name,
        Size = UDim2.new(1, 0, 0, Height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = Order,

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 8),
        },
    }
    for Index, Child in Children do
        Child.LayoutOrder = Child.LayoutOrder or Index
        table.insert(Made, Child)
    end
    return Made
end

function Kit.grid(Name: string, Cell: Vector2, Order: number?, Children: { Declaration }?): Declaration
    const Made: Declaration = {
        ClassName = "Frame",
        Name = Name,
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = Order,

        {
            ClassName = "UIGridLayout",
            CellSize = UDim2.fromOffset(Cell.X, Cell.Y),
            CellPadding = UDim2.fromOffset(7, 7),
            SortOrder = Enum.SortOrder.LayoutOrder,
        },
    }
    for _, Child in Children or {} do
        table.insert(Made, Child)
    end
    return Made
end

function Kit.colorButton(Name: string, Label: string, Bridge: Bridges.ActBridge, Action: string, Order: number?, Extra: Declaration?, Width: number?): Declaration
    const Children: { Declaration } = {
        {
            ClassName = "Frame",
            Name = `{Name}_Chip`,
            Size = UDim2.fromOffset(40, 40),
            BackgroundColor3 = White,
            BorderSizePixel = 0,
            Parts.outline(Kit.Stroke),
        },
        Kit.press(`{Name}_Pick`, Label, { Size = UDim2.fromOffset(Width or 150, 40) }, CommonStyle.AccentColor, CommonStyle.AccentText, Bridge, Action, nil, true, 16),
    }
    if Extra then
        table.insert(Children, Extra)
    end
    return Kit.row(Name, 46, Order, Children)
end

function Kit.setChip(Root: Instance, Name: string, Color: Color3?)
    const Chip = Root:FindFirstChild(`{Name}_Chip`, true)
    if Chip and Chip:IsA("Frame") then
        Chip.BackgroundColor3 = Color or White
        Chip.BackgroundTransparency = if Color then 0 else 0.55
    end
end

function Kit.stepper(Name: string, Label: string, Bridge: Bridges.ActBridge, Action: string, Key: string, Order: number?): Declaration
    const Ink = CommonStyle.InkColor
    const Fill = CommonStyle.ButtonColor
    return Kit.row(Name, 44, Order, {
        Kit.text(`{Name}_Label`, Label, 16, {
            Size = UDim2.fromOffset(92, 40),
            TextYAlignment = Enum.TextYAlignment.Center,
        }),
        Kit.press(`{Name}_Less`, "-", { Size = UDim2.fromOffset(42, 40) }, Fill, Ink, Bridge, Action, { Key = Key, Step = -1 }, false, 22),
        Kit.text(`{Name}_Value`, "1.00x", 18, {
            Size = UDim2.fromOffset(66, 40),
            FontFace = Parts.Heading,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
        }),
        Kit.press(`{Name}_More`, "+", { Size = UDim2.fromOffset(42, 40) }, Fill, Ink, Bridge, Action, { Key = Key, Step = 1 }, false, 22),
        Kit.press(`{Name}_Normal`, "normal", { Size = UDim2.fromOffset(84, 40) }, CommonStyle.PlateColor, Ink, Bridge, Action, { Key = Key, Step = 0 }, false, 15),
    })
end

function Kit.search(Name: string, Placeholder: string, Outer: Declaration, Typed: (Text: string) -> ()): Declaration
    return Kit.input(Name, Placeholder, Outer, function(Text: string)
        Typed(Text)
    end, Typed)
end

function Kit.stage(View: ViewportFrame, Source: Instance?, Spin: boolean): (() -> ())?
    View:ClearAllChildren()
    if not Source then
        return nil
    end
    const Copy = Source:Clone()
    for _, Item in Copy:GetDescendants() do
        if Item:IsA("LuaSourceContainer") or Item:IsA("Sound") then
            Item:Destroy()
        end
    end
    local Frame: CFrame, Size: Vector3
    if Copy:IsA("Model") then
        Frame, Size = Copy:GetBoundingBox()
    elseif Copy:IsA("BasePart") then
        Frame, Size = Copy.CFrame, Copy.Size
    else
        Copy:Destroy()
        return nil
    end
    const World = Instance.new("WorldModel")
    World.Parent = View
    Copy.Parent = World
    const Camera = Instance.new("Camera")
    Camera.FieldOfView = 34
    Camera.Parent = View
    View.CurrentCamera = Camera
    const Radius = math.max(Size.Magnitude / 2, 0.5)
    const Distance = Radius / math.tan(math.rad(17)) * 1.08
    const Direction = (Frame.LookVector + Frame.RightVector * 0.65 + Vector3.yAxis * 0.55).Unit
    const Focus = Frame.Position
    Camera.CFrame = CFrame.lookAt(Focus + Direction * Distance, Focus)
    if not Spin then
        return nil
    end
    local Angle = 0
    const Link = RunService.RenderStepped:Connect(function(Delta: number)
        Angle += Delta * Kit.Spin
        Camera.CFrame = CFrame.lookAt(Focus + CFrame.Angles(0, Angle, 0):VectorToWorldSpace(Direction) * Distance, Focus)
    end)
    return function()
        Link:Disconnect()
    end
end

function Kit.materials(): { string }
    const Names: { string } = {}
    for _, Item in Enum.Material:GetEnumItems() do
        if Item ~= Enum.Material.Air and Item ~= Enum.Material.Water then
            table.insert(Names, Item.Name)
        end
    end
    table.sort(Names)
    return Names
end

function Kit.materialList(Name: string, Bridge: Bridges.ActBridge, Action: string, Order: number?): Declaration
    const Made: Declaration = {
        ClassName = "ScrollingFrame",
        Name = Name,
        Size = UDim2.new(1, 0, 0, 186),
        BackgroundColor3 = Common["WellColor"],
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 8,
        ScrollBarImageColor3 = Common["OutlineColor"],
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        LayoutOrder = Order,
        Parts.outline(Kit.ItemStroke),

        {
            ClassName = "UIGridLayout",
            CellSize = UDim2.new(0.5, -5, 0, 32),
            CellPadding = UDim2.fromOffset(6, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        },

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0, 6),
            PaddingBottom = UDim.new(0, 6),
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
        },
    }
    for Index, Material in Kit.materials() do
        const Label = string.lower((string.gsub(Material, "(%l)(%u)", "%1 %2")))
        table.insert(Made, Kit.chip({ Id = Material, Name = Label, Active = false }, Index, Bridge, Action))
    end
    return Made
end

function Kit.clear(List: Instance)
    const Items = Rendered[List]
    Rendered[List] = nil
    for _, Item in Items or {} do
        Item:Cleanup()
    end
    const Known = Keyed[List]
    Keyed[List] = nil
    for _, Item in Known or {} do
        Item.Vision:Cleanup()
    end
end

function Kit.sync(List: Instance, Items: { Item })
    local Known = Keyed[List]
    if not Known then
        Known = {}
        Keyed[List] = Known
    end
    const Current = Known :: { [string]: Synced }
    const Seen: { [string]: boolean } = {}
    for Order, Item in Items do
        Seen[Item.Key] = true
        const Old = Current[Item.Key]
        if Old and Old.Hash == Item.Hash then
            const Root = Old.Vision:Open()
            if Root and Root:IsA("GuiObject") then
                Root.LayoutOrder = Order
            end
            continue
        end
        if Old then
            Old.Vision:Cleanup()
        end
        const Made = Item.Build()
        Made.LayoutOrder = Order
        table.insert(Made, vision.mount(List))
        const Built = Scope:Capture(Made)
        Built:Mount()
        Current[Item.Key] = { Vision = Built, Hash = Item.Hash }
    end
    for Key, Old in Current do
        if not Seen[Key] then
            Current[Key] = nil
            Old.Vision:Cleanup()
        end
    end
end

function Kit.render(List: Instance, Items: { Declaration })
    Kit.clear(List)
    const Made: { vision.Vision } = {}
    for _, Item in Items do
        table.insert(Item, vision.mount(List))
        const Built = Scope:Capture(Item)
        Built:Mount()
        table.insert(Made, Built)
    end
    Rendered[List] = Made
end

function Kit.chip(Choice: Bridges.Choice, Order: number, Bridge: Bridges.ActBridge, Action: string): Declaration
    const Fill = if Choice.Active then CommonStyle.AccentColor else CommonStyle.ButtonColor
    return Parts.card(`Chip_{Choice.Id}`, {
        LayoutOrder = Order,
    }, {
        ClassName = "TextButton",
        Text = Choice.Name,
        FontFace = Parts.Typewriter,
        TextScaled = false,
        TextSize = 15,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextColor3 = if Choice.Active then CommonStyle.AccentText else CommonStyle.InkColor,
        BackgroundColor3 = Fill,
        AutoButtonColor = true,
        Activated = function()
            Bridge:Call(Action, Choice.Id)
        end,
        Parts.bevel(`Chip_{Choice.Id}_Shine`, 2, Kit.light(Fill), Kit.dark(Fill)),
    }, 3, nil, Kit.ItemStroke)
end

function Kit.chips(Name: string, Event: string, Cell: Vector2, Bridge: Bridges.ActBridge, Action: string, Order: number?): Declaration
    const Made = Kit.grid(Name, Cell, Order)
    Made.Destroying = function(List: Instance)
        Kit.clear(List)
    end
    table.insert(Made, vision.event(Event, {}, function(List: Instance, _, Choices: { Bridges.Choice })
        const Items: { Item } = {}
        for Index, Choice in Choices do
            table.insert(Items, {
                Key = Choice.Id,
                Hash = `{Choice.Name}|{Choice.Active}`,
                Build = function(): Declaration
                    return Kit.chip(Choice, Index, Bridge, Action)
                end,
            })
        end
        Kit.sync(List, Items)
    end))
    table.insert(Made, vision.cleanup(function(List: Instance, _)
        Kit.clear(List)
    end))
    return Made
end

function Kit.figure(Name: string, Bridge: Bridges.ActBridge, Action: string, Order: number?): Declaration
    const Made: Declaration = {
        ClassName = "Frame",
        Name = Name,
        Size = UDim2.fromOffset(Kit.FigureSize.X, Kit.FigureSize.Y),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = Order,

        Parts.text("Right", "R", { Position = UDim2.fromOffset(4, 46), Size = UDim2.fromOffset(20, 20), TextScaled = false, TextSize = 16, TextColor3 = Common["OutlineColor"] }),
        Parts.text("Left", "L", { Position = UDim2.fromOffset(146, 46), Size = UDim2.fromOffset(20, 20), TextScaled = false, TextSize = 16, TextColor3 = Common["OutlineColor"] }),
    }
    for Part, Box in Kit.Figure do
        table.insert(Made, {
            ClassName = "TextButton",
            Name = `{Name}_{Part}`,
            Text = "",
            Position = UDim2.fromOffset(Box[1], Box[2]),
            Size = UDim2.fromOffset(Box[3], Box[4]),
            AutoButtonColor = true,
            BackgroundColor3 = Common["CardColor"],
            BorderSizePixel = 0,
            Activated = function()
                Bridge:Call(Action, Part)
            end,
            Parts.outline(Kit.ItemStroke),
        })
    end
    return Made
end

function Kit.paintFigure(Root: Instance, Name: string, Lit: { [string]: boolean }, Faded: { [string]: boolean }?)
    for Part in Kit.Figure do
        const Spot = Root:FindFirstChild(`{Name}_{Part}`, true)
        if Spot and Spot:IsA("GuiObject") then
            Spot.BackgroundColor3 = if Lit[Part] then CommonStyle.AccentColor else CommonStyle.CardColor
            Spot.BackgroundTransparency = if Faded and Faded[Part] then 0.6 else 0
        end
    end
end

return Kit
