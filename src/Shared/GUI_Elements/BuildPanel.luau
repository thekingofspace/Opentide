--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Bridges = require(ReplicatedStorage.Shared.PropPlacer.Bridges)
const Scope = vision.Scope()
const CommonStyle = require(script.Parent.CommonStyle)
const Parts = require(script.Parent.Parts)
const _MainStyle = Scope:LoadStyle(CommonStyle::vision.Declaration)

const Common = vision.style("Common")
const Typewriter = Parts.Typewriter
const Heading = Parts.Heading
const HeaderHeight = 0.072
const HeaderMargin = 9
const Bevel = 5
const HeaderBevel = 4
const ButtonStroke = 2.1
const ThinStroke = 1.75
const ItemStroke = 1.6
const IconStroke = 1.6
const DesignSize = Vector2.new(384, 864)
const PanelHeight = 0.75
const PanelWidth = 0.4
const WellRim = 3
const WellInset = 6
const ListSpacer = 6

const IconSize = 64
const ItemPadding = 10
const InfoGap = 12
const TitleSize = 22
const DetailSize = 15
const FieldOfView = 40
const ViewAngle = CFrame.Angles(0, math.rad(35), 0) * CFrame.Angles(math.rad(22), 0, 0)

const ScrollGap = 10
const ListEdge = 6
const SearchDelay = 0.4
const PreviewPageSize = 6
const ToolWidth = 136
const ToolHeight = 54
const ModeHeight = 44
const ActionHeight = 48
const ToolSpacing = 6
const ToolPadding = 10
const ToolTitle = 22
const ToolDivider = 3
const ToolBevel = 4
const ToolGap = 14
const KeySize = 22
const ToolMinimum = 0.6
const ContentWidth = DesignSize.X * 0.93

local SearchToken = 0
local LastQuery = ""
local Turning = false

const function trayHeight(Settings: number): number
    return ToolPadding * 2
        + ToolTitle
        + Settings * ToolHeight
        + ToolDivider * 2
        + ModeHeight * 3
        + ActionHeight * 2
        + (Settings + 7) * ToolSpacing
end

const function actionInner(Width: number): number
    return Width * ContentWidth * 0.92 - 4
end

const ToolColumnHeight = trayHeight(4)
const ActionText = math.min(
    30,
    Parts.fitText({ "saves" }, actionInner(0.38), 48),
    Parts.fitText({ "edit" }, actionInner(0.36), 48),
    Parts.fitText({ "exit edit" }, actionInner(0.76), 48)
)
const EditText = math.min(
    20,
    Parts.fitText({ "edit [E]", "delete [X]" }, ContentWidth * 0.9 * 0.48 - 24, 40),
    Parts.fitText({ "save selected [B]" }, ContentWidth * 0.9 - 24, 40)
)
const ToolText = math.min(21, math.floor(Parts.fitText({ "rotate", "cancel", "scale" }, ToolWidth - ToolPadding * 2 - KeySize - 24, 24) * 0.9))

const merge = Parts.merge
const outline = Parts.outline
const text = Parts.text
const edge = Parts.edge
const card = Parts.card

const function button(Name: string, Label: string, Width: number, Order: number, Fill: any, Ink: any, TextOutline: Color3?, Action: string?): { [any]: any }
    const Inner: { [any]: any } = {
        ClassName = "TextButton",
        Text = Label,
        FontFace = Typewriter,
        TextScaled = false,
        TextSize = ActionText,
        TextColor3 = Ink,
        BackgroundColor3 = Fill,
        AutoButtonColor = true,

        {
            ClassName = "UIPadding",
            PaddingLeft = UDim.new(0.04, 0),
            PaddingRight = UDim.new(0.04, 0),
            PaddingTop = UDim.new(0.08, 0),
            PaddingBottom = UDim.new(0.06, 0)
        }
    }
    if Action then
        Inner.Activated = function()
            Bridges.Action:Call(Action)
        end
    end
    if TextOutline then
        table.insert(Inner, {
            ClassName = "UIStroke",
            Name = `{Name}_TextOutline`,
            Color = TextOutline,
            Thickness = 1.5,
            LineJoinMode = Enum.LineJoinMode.Round,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        })
    end

    return card(Name, {
        Size = UDim2.fromScale(Width, 1),
        LayoutOrder = Order
    }, Inner, nil, nil, ButtonStroke)
end

const function autoCard(Name: string, Outer: { [any]: any }, Inner: { [any]: any }, Depth: Vector2?, Side: any?, Stroke: number?): { [any]: any }
    const Lift = Depth or Vector2.zero
    const Made: { [any]: any } = {
        ClassName = "Frame",
        Name = Name,
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }

    if Lift.X > 0 or Lift.Y > 0 then
        table.insert(Made, {
            ClassName = "UIPadding",
            PaddingBottom = UDim.new(0, Lift.Y)
        })
        table.insert(Made, {
            ClassName = "Frame",
            Name = `{Name}_Side`,
            Size = UDim2.new(1, 0, 1, Lift.Y),
            BackgroundColor3 = Side,
            BorderSizePixel = 0,
            ZIndex = 1,
            outline()
        })
    end

    table.insert(Made, merge({
        ClassName = "Frame",
        Name = `{Name}_Body`,
        Size = UDim2.new(1, -Lift.X, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Common["CardColor"],
        BorderSizePixel = 0,
        ZIndex = 2,
        outline(Stroke)
    }, Inner))

    return merge(Made, Outer)
end

const function bounds(Model: PVInstance): (Vector3, Vector3)
    if Model:IsA("Model") then
        const Box, Size = Model:GetBoundingBox()
        return Box.Position, Size
    elseif Model:IsA("BasePart") then
        return Model.Position, Model.Size
    end
    return Model:GetPivot().Position, Vector3.one
end

const function framing(Model: PVInstance, Offset: CFrame?): CFrame
    const Pivot = Model:GetPivot()
    if Offset then
        return Pivot * Offset
    end
    const Center, Size = bounds(Model)
    const Distance = (Size.Magnitude / 2) / math.sin(math.rad(FieldOfView / 2))
    const Direction = (Pivot.Rotation * ViewAngle).LookVector
    return CFrame.lookAt(Center + Direction * Distance, Center)
end

const function stage(View: ViewportFrame, Entry: Bridges.Entry)
    const Source = Entry.Model
    if not Source then
        return
    end
    const Copy = Source:Clone()
    if not Copy then
        return
    end
    const Camera = Instance.new("Camera")
    Camera.FieldOfView = FieldOfView
    Camera.CFrame = framing(Copy, Entry.CFrame)
    Camera.Parent = View
    View.CurrentCamera = Camera
    Copy.Parent = View
end

const function item(Entry: Bridges.Entry, Order: number, List: Instance): { [any]: any }
    const Limit = if Entry.Limit ~= nil then tostring(Entry.Limit) else "none"
    return autoCard(`Build_Item_{Order}`, {
        LayoutOrder = Order,
        vision.mount(List)
    }, {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Common["ButtonColor"],
        Activated = function()
            Bridges.Select:Call(Entry)
        end,

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0, ItemPadding),
            PaddingBottom = UDim.new(0, ItemPadding),
            PaddingLeft = UDim.new(0, ItemPadding + 1),
            PaddingRight = UDim.new(0, ItemPadding + 2)
        },

        {
            ClassName = "Frame",
            Name = "Icon_Box",
            Size = UDim2.fromOffset(IconSize, IconSize),
            BackgroundColor3 = Common["IconColor"],
            BorderSizePixel = 0,
            outline(IconStroke),

            {
                ClassName = "ViewportFrame",
                Name = "Icon",
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Ambient = Color3.fromRGB(165, 165, 165),
                LightColor = Color3.new(1, 1, 1),
                LightDirection = Vector3.new(-1, -1.5, -1),

                vision.ready(function(View: Instance, _, _)
                    stage(View :: ViewportFrame, Entry)
                end)
            }
        },

        {
            ClassName = "Frame",
            Name = "Info",
            Position = UDim2.fromOffset(IconSize + InfoGap, 0),
            Size = UDim2.new(1, -(IconSize + InfoGap), 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,

            {
                ClassName = "UIListLayout",
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 5)
            },

            text("Title", Entry.Name, {
                Size = UDim2.fromScale(1, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                TextScaled = false,
                TextSize = TitleSize,
                TextWrapped = true,
                LayoutOrder = 1
            }),

            {
                ClassName = "Frame",
                Name = "Divider",
                Size = UDim2.new(1, 0, 0, 3),
                BackgroundColor3 = Common["DividerColor"],
                BorderSizePixel = 0,
                LayoutOrder = 2
            },

            {
                ClassName = "Frame",
                Name = "Details",
                Size = UDim2.new(1, 0, 0, DetailSize + 3),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = 3,

                text("Limit", `limit: {Limit}`, {
                    Size = UDim2.new(0.42, 0, 0, DetailSize + 3),
                    TextScaled = false,
                    TextSize = DetailSize,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    TextTruncate = Enum.TextTruncate.AtEnd
                }),

                text("Pack", if Entry.Pack then `from {Entry.Pack} pack` else "free", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.fromScale(1, 0),
                    Size = UDim2.new(0.58, 0, 0, DetailSize + 3),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    TextScaled = false,
                    TextSize = DetailSize,
                    TextWrapped = true,
                    TextColor3 = Common["PackColor"],
                    TextXAlignment = Enum.TextXAlignment.Right,
                    TextYAlignment = Enum.TextYAlignment.Top
                })
            }
        }
    }, nil, nil, ItemStroke)
end

const Rendered: { [Instance]: { vision.Vision } } = {}

const function clear(List: Instance)
    const Items = Rendered[List]
    if not Items then
        return
    end
    Rendered[List] = nil
    for _, Item in Items do
        Item:Cleanup()
    end
    table.clear(Items)
end

const function render(List: Instance, Entries: { Bridges.Entry })
    clear(List)
    const Items: { vision.Vision } = {}
    for Index, Entry in Entries do
        const Item = Scope:Capture(item(Entry, Index, List))
        Item:Mount()
        table.insert(Items, Item)
    end
    Rendered[List] = Items
    if List:IsA("ScrollingFrame") then
        List.CanvasPosition = Vector2.zero
    end
end

const function gutter(List: Instance)
    const Frame = List :: ScrollingFrame
    const Padding = Frame:FindFirstChild("Build_List_Padding") :: UIPadding?
    if not Padding then
        return
    end
    const Showing = Frame.AbsoluteCanvasSize.Y > Frame.AbsoluteWindowSize.Y + 1
    const Wanted = if Showing then UDim.new(0, ScrollGap) else UDim.new(0, ListEdge)
    if Padding.PaddingRight ~= Wanted then
        Padding.PaddingRight = Wanted
    end
end

const function turn(Owner: vision.Vision, Delta: number)
    if Turning then
        return
    end
    const Current = tonumber(Owner.Page()) or 1
    Turning = true
    const Ok, Result = pcall(function()
        return Bridges.Page:Call(Current + Delta, Current)
    end)
    Turning = false
    if not Ok then
        warn(`[BuildPanel] page bridge failed: {Result}`)
    elseif type(Result) == "number" then
        Owner.Page(Result)
    end
end

const function search(Owner: vision.Vision, Query: string)
    const Clean = (string.gsub(Query, "^%s*(.-)%s*$", "%1"))
    if string.lower(Clean) == LastQuery then
        return
    end
    LastQuery = string.lower(Clean)
    const Ok, Result = pcall(function()
        return Bridges.Search:Call(Clean)
    end)
    if not Ok then
        warn(`[BuildPanel] search bridge failed: {Result}`)
    elseif type(Result) == "number" then
        Owner.Page(Result)
    end
end

const function schedule(Owner: vision.Vision, Query: string)
    SearchToken += 1
    const Token = SearchToken
    task.delay(SearchDelay, function()
        if Token == SearchToken then
            search(Owner, Query)
        end
    end)
end

const function pageButton(Label: string, Delta: number): { [any]: any }
    return {
        ClassName = "TextButton",
        Text = Label,
        FontFace = Heading,
        TextScaled = true,
        TextColor3 = Common["InkColor"],
        BackgroundColor3 = Common["ButtonColor"],
        AutoButtonColor = true,
        Activated = function(_, Owner: vision.Vision)
            turn(Owner, Delta)
        end,

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0.26, 0),
            PaddingBottom = UDim.new(0.04, 0)
        }
    }
end

type PreviewProp = {
    Name: string,
    Pack: string,
    Limit: number?,
    Color: Color3,
    Size: Vector3,
    Shape: Enum.PartType,
}

const PreviewProps: { PreviewProp } = {
    { Name = "Abandoned Shelter - Empty", Pack = "Shelter", Limit = 1, Color = Color3.fromRGB(122, 98, 74), Size = Vector3.new(6, 4, 5), Shape = Enum.PartType.Block },
    { Name = "Abandoned Shelter - Furnished, Clean", Pack = "Shelter", Limit = 1, Color = Color3.fromRGB(150, 118, 86), Size = Vector3.new(6, 4, 5), Shape = Enum.PartType.Block },
    { Name = "Bed 1", Pack = "Bedroom", Color = Color3.fromRGB(196, 92, 84), Size = Vector3.new(3, 1.4, 6), Shape = Enum.PartType.Block },
    { Name = "Bed, Sleeping Bag", Pack = "Camping", Color = Color3.fromRGB(70, 120, 92), Size = Vector3.new(2.4, 0.6, 6), Shape = Enum.PartType.Block },
    { Name = "Bench 1", Pack = "Park", Color = Color3.fromRGB(140, 100, 64), Size = Vector3.new(5, 1.2, 1.6), Shape = Enum.PartType.Block },
    { Name = "Book 1, Closed", Pack = "Library", Color = Color3.fromRGB(64, 84, 150), Size = Vector3.new(1.2, 0.3, 1.6), Shape = Enum.PartType.Block },
    { Name = "Book 1, Opened", Pack = "Library", Color = Color3.fromRGB(230, 222, 200), Size = Vector3.new(2.4, 0.2, 1.6), Shape = Enum.PartType.Block },
    { Name = "Campfire", Pack = "Camping", Limit = 2, Color = Color3.fromRGB(232, 128, 52), Size = Vector3.new(2, 2, 2), Shape = Enum.PartType.Ball },
    { Name = "Crate, Wooden", Pack = "Storage", Color = Color3.fromRGB(168, 128, 80), Size = Vector3.new(2.5, 2.5, 2.5), Shape = Enum.PartType.Block },
    { Name = "Lamp Post", Pack = "Park", Color = Color3.fromRGB(60, 62, 66), Size = Vector3.new(7, 0.8, 0.8), Shape = Enum.PartType.Cylinder },
    { Name = "Lantern", Pack = "Camping", Color = Color3.fromRGB(240, 200, 90), Size = Vector3.new(1, 1, 1), Shape = Enum.PartType.Ball },
    { Name = "Picnic Table", Pack = "Park", Color = Color3.fromRGB(150, 108, 70), Size = Vector3.new(5, 2.6, 3), Shape = Enum.PartType.Block },
    { Name = "Shelf, Tall", Pack = "Storage", Color = Color3.fromRGB(120, 86, 58), Size = Vector3.new(3, 6, 1.2), Shape = Enum.PartType.Block },
    { Name = "Table, Round", Pack = "Bedroom", Color = Color3.fromRGB(176, 136, 96), Size = Vector3.new(1, 3.6, 3.6), Shape = Enum.PartType.Cylinder },
}

local PreviewEntries: { Bridges.Entry }? = nil

const function previewEntries(): { Bridges.Entry }
    const Cached = PreviewEntries
    if Cached then
        return Cached
    end
    const Made: { Bridges.Entry } = {}
    for _, Prop in PreviewProps do
        const Part = Instance.new("Part")
        Part.Anchored = true
        Part.Shape = Prop.Shape
        Part.Size = Prop.Size
        Part.Color = Prop.Color
        Part.Material = Enum.Material.SmoothPlastic
        table.insert(Made, {
            Name = Prop.Name,
            Pack = Prop.Pack,
            Limit = Prop.Limit,
            Model = Part
        })
    end
    PreviewEntries = Made
    return Made
end

const function matches(Entry: Bridges.Entry, Needle: string): boolean
    if Needle == "" then
        return true
    end
    return string.find(string.lower(Entry.Name), Needle, 1, true) ~= nil
        or string.find(string.lower(Entry.Pack or "free"), Needle, 1, true) ~= nil
end

const function watchFit(Frame: GuiObject, Later: (() -> ()) -> ())
    const Scale = Frame:FindFirstChildOfClass("UIScale")
    if not Scale then
        return
    end
    local Watch: RBXScriptConnection? = nil

    const function refit()
        const Parent = Frame.Parent
        if not (Parent and Parent:IsA("GuiBase2d")) then
            return
        end
        const Size = Parent.AbsoluteSize
        if Size.X <= 0 or Size.Y <= 0 then
            return
        end
        const Next = math.min(Size.Y * PanelHeight / DesignSize.Y, Size.X * PanelWidth / DesignSize.X)
        if math.abs(Scale.Scale - Next) > 0.001 then
            Scale.Scale = Next
        end
        const Column = Frame:FindFirstChild("Build_Tools")
        const Boost = if Column then Column:FindFirstChildOfClass("UIScale") else nil
        if Boost and Next > 0 then
            const Room = Size.Y * 0.95 / (ToolColumnHeight * Next)
            const Wanted = math.clamp(ToolMinimum / Next, 1, math.max(Room, 1))
            if math.abs(Boost.Scale - Wanted) > 0.001 then
                Boost.Scale = Wanted
            end
        end
    end

    const function bind()
        const Old = Watch
        if Old then
            Old:Disconnect()
            Watch = nil
        end
        const Parent = Frame.Parent
        if Parent and Parent:IsA("GuiBase2d") then
            Watch = Parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
        end
        refit()
    end

    const Moved = Frame.AncestryChanged:Connect(bind)
    bind()

    Later(function()
        Moved:Disconnect()
        const Old = Watch
        if Old then
            Old:Disconnect()
            Watch = nil
        end
    end)
end

const function startPreview(Owner: vision.Vision, Later: (() -> ()) -> ())
    const All = previewEntries()
    local Shown = All

    const function showPage(Page: number): number
        const Pages = math.max(1, math.ceil(#Shown / PreviewPageSize))
        const Clamped = math.clamp(Page, 1, Pages)
        const First = (Clamped - 1) * PreviewPageSize + 1
        Owner.LoadPage(table.move(Shown, First, math.min(First + PreviewPageSize - 1, #Shown), 1, {}))
        return Clamped
    end

    const UnbindPage = Bridges.Page:Bind(function(Requested: number, _: number): number?
        return showPage(Requested)
    end)

    const UnbindSearch = Bridges.Search:Bind(function(Query: string): number?
        const Needle = string.lower(Query)
        Shown = {}
        for _, Entry in All do
            if matches(Entry, Needle) then
                table.insert(Shown, Entry)
            end
        end
        return showPage(1)
    end)

    Owner.Page(showPage(1))

    Later(function()
        UnbindPage()
        UnbindSearch()
    end)
end

const function hidden(Declaration: { [any]: any }): { [any]: any }
    Declaration.Visible = false
    return Declaration
end

const function toolButton(Name: string, Key: string, Title: string?, Value: string, Order: number, Height: number, Fill: any, Ink: any, Outlined: boolean?): { [any]: any }
    const Inner: { [any]: any } = {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Fill,
        Activated = function()
            Bridges.Tool:Call(Name)
        end,

        Parts.keyBadge(Key, KeySize, {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -5, 0, 5)
        })
    }

    const Label = if Title
        then text("Value", Value, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 9, 1, -6),
            Size = UDim2.new(1, -16, 0, 22),
            TextScaled = false,
            TextSize = 20,
            FontFace = Heading,
            TextColor3 = Ink,
            TextTruncate = Enum.TextTruncate.AtEnd
        })
        else text("Value", Value, {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 10, 0.5, 1),
            Size = UDim2.new(1, -(KeySize + 20), 0, 24),
            TextScaled = false,
            TextSize = ToolText,
            FontFace = Heading,
            TextColor3 = Ink,
            TextTruncate = Enum.TextTruncate.AtEnd
        })
    if Outlined then
        table.insert(Label, Parts.textOutline())
    end
    table.insert(Inner, Label)

    if Title then
        table.insert(Inner, text("Title", Title, {
            Position = UDim2.fromOffset(9, 7),
            Size = UDim2.new(1, -(KeySize + 18), 0, 15),
            TextScaled = false,
            TextSize = 14,
            TextColor3 = Common["PackColor"]
        }))
    end

    return card(`Build_Tool_{Name}`, {
        Size = UDim2.new(1, 0, 0, Height),
        LayoutOrder = Order
    }, Inner, nil, nil, ButtonStroke)
end

const function divider(Name: string, Order: number): { [any]: any }
    return {
        ClassName = "Frame",
        Name = Name,
        Size = UDim2.new(1, 0, 0, ToolDivider),
        BackgroundColor3 = Common["OutlineColor"],
        BorderSizePixel = 0,
        LayoutOrder = Order
    }
end

const function setTool(Tray: Instance, Name: string, Value: string?, Visible: boolean, Fill: Color3?, Ink: Color3?)
    const Holder = Tray:FindFirstChild(`Build_Tool_{Name}`, true) :: GuiObject?
    if not Holder then
        return
    end
    Holder.Visible = Visible
    const Body = Holder:FindFirstChild(`Build_Tool_{Name}_Body`) :: GuiObject?
    if not Body then
        return
    end
    if Fill then
        Body.BackgroundColor3 = Fill
    end
    const Label = Body:FindFirstChild("Value") :: TextLabel?
    if Label then
        if Ink then
            Label.TextColor3 = Ink
        end
        if Value then
            Label.Text = Value
        end
    end
end

const function showTools(Tray: Instance, View: Bridges.ToolView)
    const Frame = Tray :: GuiObject
    Frame.Visible = View.Visible
    setTool(Tray, "Increment", View.Increment, true)
    setTool(Tray, "Space", View.Space, true)
    setTool(Tray, "Control", View.Control, View.Control ~= nil)
    setTool(Tray, "Axis", View.Axis, View.Axis ~= nil)
    for _, Kind in { "Translate", "Rotate", "Scale" } do
        const Picked = View.Kind == Kind
        setTool(
            Tray,
            Kind,
            nil,
            true,
            if Picked then CommonStyle.AccentColor else CommonStyle.ButtonColor,
            if Picked then CommonStyle.AccentText else CommonStyle.InkColor
        )
    end
    setTool(Tray, "Place", if View.Busy then "wait" else "place", true)

    local Settings = 2
    if View.Control ~= nil then
        Settings += 1
    end
    if View.Axis ~= nil then
        Settings += 1
    end
    Frame.Size = UDim2.fromOffset(ToolWidth, trayHeight(Settings))
end

const function toolColumn(): { [any]: any }
    return {
        ClassName = "Frame",
        Name = "Build_Tools",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(0, -ToolGap, 0.5, 0),
        Size = UDim2.fromOffset(ToolWidth, ToolColumnHeight),
        BackgroundColor3 = Common["BackdropColor"],
        BorderSizePixel = 0,
        Visible = false,
        outline(2),

        {
            ClassName = "UIScale",
            Name = "Build_Tools_Scale"
        },

        vision.event("Tools", { Visible = false, Kind = "Translate", Increment = "", Space = "", Busy = false }, function(Tray: Instance, _, View: Bridges.ToolView)
            showTools(Tray, View)
        end),

        Parts.bevel("Build_Tools_Bevel", ToolBevel, Common["BevelLight"], Common["BevelDark"]),

        {
            ClassName = "Frame",
            Name = "Build_Tools_List",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,

            {
                ClassName = "UIPadding",
                PaddingTop = UDim.new(0, ToolPadding),
                PaddingBottom = UDim.new(0, ToolPadding),
                PaddingLeft = UDim.new(0, ToolPadding),
                PaddingRight = UDim.new(0, ToolPadding)
            },

            {
                ClassName = "UIListLayout",
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, ToolSpacing)
            },

            text("Build_Tools_Title", "tools", {
                Size = UDim2.new(1, 0, 0, ToolTitle),
                TextScaled = false,
                TextSize = 21,
                FontFace = Heading,
                TextXAlignment = Enum.TextXAlignment.Center,
                LayoutOrder = 0,
                Parts.textOutline(Color3.fromRGB(190, 184, 176), 2)
            }),

            toolButton("Increment", "Q", "snap", "free", 1, ToolHeight, Common["ButtonColor"], Common["InkColor"]),
            toolButton("Space", "L", "space", "global", 2, ToolHeight, Common["ButtonColor"], Common["InkColor"]),
            toolButton("Control", "M", "control", "mouse", 3, ToolHeight, Common["ButtonColor"], Common["InkColor"]),
            toolButton("Axis", "C", "axis", "Y", 4, ToolHeight, Common["ButtonColor"], Common["InkColor"]),
            divider("Build_Tools_Divider_Modes", 5),
            toolButton("Translate", "T", nil, "move", 6, ModeHeight, Common["AccentColor"], Common["AccentText"]),
            toolButton("Rotate", "R", nil, "rotate", 7, ModeHeight, Common["ButtonColor"], Common["InkColor"]),
            toolButton("Scale", "Y", nil, "scale", 8, ModeHeight, Common["ButtonColor"], Common["InkColor"]),
            divider("Build_Tools_Divider_Actions", 9),
            toolButton("Place", "F", nil, "place", 10, ActionHeight, Common["SuccessColor"], Common["SuccessText"], true),
            toolButton("Cancel", "X", nil, "cancel", 11, ActionHeight, Common["CloseColor"], Common["CloseText"], true)
        }
    }
end

const function editButton(Name: string, Label: string, Anchor: Vector2, Position: UDim2, Size: UDim2, Fill: any, Action: string): { [any]: any }
    return card(Name, {
        AnchorPoint = Anchor,
        Position = Position,
        Size = Size
    }, {
        ClassName = "TextButton",
        Text = Label,
        FontFace = Typewriter,
        TextScaled = false,
        TextSize = EditText,
        TextColor3 = Common["AccentText"],
        BackgroundColor3 = Fill,
        AutoButtonColor = true,
        Activated = function()
            Bridges.Action:Call(Action)
        end,
        Parts.textOutline()
    }, nil, nil, ButtonStroke)
end

const function editCard(): { [any]: any }
    return card("Build_Edit_Panel", {
        Size = UDim2.fromScale(1, 0.42),
        LayoutOrder = 2,
        Visible = false
    }, {
        BackgroundColor3 = Common["PlateColor"],

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0.04, 0),
            PaddingBottom = UDim.new(0.05, 0),
            PaddingLeft = UDim.new(0.05, 0),
            PaddingRight = UDim.new(0.05, 0)
        },

        text("Build_Edit_Count", "0 selected", {
            Size = UDim2.fromScale(1, 0.16),
            FontFace = Heading,

            vision.event("Selected", 0, function(Label: Instance, _, Value: number)
                (Label :: TextLabel).Text = `{Value} selected`
            end)
        }),

        text("Build_Edit_Help", "click the markers on your props or drag a box to select them, hold shift to add more. [Alt] leaves edit mode", {
            Position = UDim2.fromScale(0, 0.19),
            Size = UDim2.fromScale(1, 0.3),
            TextWrapped = true,
            TextColor3 = Common["PackColor"],
            TextYAlignment = Enum.TextYAlignment.Top
        }),

        editButton("Build_Edit_Save", "save selected [B]", Vector2.new(0, 1), UDim2.fromScale(0, 0.74), UDim2.fromScale(1, 0.21), Common["SuccessColor"], "SaveSelected"),
        editButton("Build_Edit_Selected", "edit [E]", Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(0.48, 0.21), Common["AccentColor"], "EditSelected"),
        editButton("Build_Edit_Delete", "delete [X]", Vector2.new(1, 1), UDim2.fromScale(1, 1), UDim2.fromScale(0.48, 0.21), Common["CloseColor"], "DeleteSelected")
    }, nil, nil, ButtonStroke)
end

const function showMode(Content: Instance, Editing: boolean)
    for _, Name in { "Build_Search", "Build_List_Well", "Build_Pages" } do
        const Item = Content:FindFirstChild(Name) :: GuiObject?
        if Item then
            Item.Visible = not Editing
        end
    end
    const Panel = Content:FindFirstChild("Build_Edit_Panel") :: GuiObject?
    if Panel then
        Panel.Visible = Editing
    end
    const Actions = Content:FindFirstChild("Build_Actions")
    if not Actions then
        return
    end
    for _, Name in { "Build_Saves", "Build_Edit" } do
        const Item = Actions:FindFirstChild(Name) :: GuiObject?
        if Item then
            Item.Visible = not Editing
        end
    end
    const Exit = Actions:FindFirstChild("Build_Exit") :: GuiObject?
    if Exit then
        Exit.Visible = Editing
    end
end

const TrueAspect, TrueScale = VisionKit.ratio(
    UDim2.fromScale(0.2, 0.8), true,
    {
        Name = "Aspect_Build"
    },
    {
        Name = "Scale_Build",
        Margin = UDim.new(0.4)
    }
)

return Scope:Capture({
    ClassName = "Frame",
    Name = "Build_Frame",
    AnchorPoint = Vector2.new(1, 0.5),
    Size = UDim2.fromOffset(DesignSize.X, DesignSize.Y),
    Position = UDim2.new(1, -16, 0.5, 0),
    BorderSizePixel = 0,
    BackgroundColor3 = vision.style("Common")["BackdropColor"],
    TrueAspect,
    TrueScale,

    vision.event("Toggle", true, function(Self: Instance, _, Value: boolean)
        (Self :: GuiObject).Visible = Value
        Bridges.Action:Call(if Value then "Opened" else "Closed")
    end),

    toolColumn(),

    vision.ready(function(Self: Instance, Owner: vision.Vision, Later: (() -> ()) -> ())
        SearchToken += 1
        LastQuery = ""
        Turning = false
        watchFit(Self :: GuiObject, Later)
        if (_G :: any).IsStudio == true then
            startPreview(Owner, Later)
        end
    end),

    {
        ClassName = "UIStroke",
        Name = "Build_Outline",
        Thickness = 2,
        Color = Common["InkColor"],
        LineJoinMode = Enum.LineJoinMode.Miter,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }::UIStroke & any,

    edge("Build_Bevel_Top", UDim2.new(1, 0, 0, Bevel), Vector2.zero, UDim2.new(), Common["BevelLight"]),
    edge("Build_Bevel_Left", UDim2.new(0, Bevel, 1, 0), Vector2.zero, UDim2.new(), Common["BevelLight"]),
    edge("Build_Bevel_Bottom", UDim2.new(1, 0, 0, Bevel), Vector2.new(0, 1), UDim2.fromScale(0, 1), Common["BevelDark"]),
    edge("Build_Bevel_Right", UDim2.new(0, Bevel, 1, 0), Vector2.new(1, 0), UDim2.fromScale(1, 0), Common["BevelDark"]),

    {
        ClassName = "Frame",
        Name = "Build_Header",
        Position = UDim2.fromOffset(HeaderMargin, HeaderMargin),
        Size = UDim2.new(1, -HeaderMargin * 2, HeaderHeight, -HeaderMargin),
        BackgroundColor3 = Common["HeaderColor"],
        BorderSizePixel = 0,
        outline(ButtonStroke),

        edge("Build_Header_Top", UDim2.new(1, 0, 0, HeaderBevel), Vector2.zero, UDim2.new(), Common["HeaderShine"]),
        edge("Build_Header_Left", UDim2.new(0, HeaderBevel, 1, 0), Vector2.zero, UDim2.new(), Common["HeaderShine"]),
        edge("Build_Header_Bottom", UDim2.new(1, 0, 0, HeaderBevel), Vector2.new(0, 1), UDim2.fromScale(0, 1), Common["HeaderShade"]),
        edge("Build_Header_Right", UDim2.new(0, HeaderBevel, 1, 0), Vector2.new(1, 0), UDim2.fromScale(1, 0), Common["HeaderShade"]),

        card("Build_Close", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.fromScale(0.975, 0.5),
            Size = UDim2.fromScale(0.2, 0.75),

            {
                ClassName = "UIAspectRatioConstraint",
                AspectRatio = 1,
                DominantAxis = Enum.DominantAxis.Height
            }
        }, {
            ClassName = "TextButton",
            Text = "X",
            FontFace = Heading,
            TextScaled = true,
            TextColor3 = Common["CloseText"],
            BackgroundColor3 = Common["CloseColor"],
            AutoButtonColor = true,
            Activated = function(_, Owner: vision.Vision)
                Owner.Toggle(false)
            end,

            {
                ClassName = "UIPadding",
                PaddingLeft = UDim.new(0.2, 0),
                PaddingRight = UDim.new(0.2, 0),
                PaddingTop = UDim.new(0.26, 0),
                PaddingBottom = UDim.new(0.12, 0)
            }
        }, nil, nil, ThinStroke),

        text("Build_Title", "Prop Placer", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromScale(0.025, 0.53),
            Size = UDim2.fromScale(0.74, 0.72),
            FontFace = Heading,

            {
                ClassName = "UIStroke",
                Name = "Build_Title_Outline",
                Color = Color3.fromRGB(190, 184, 176),
                Thickness = 2,
                LineJoinMode = Enum.LineJoinMode.Round,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
            }
        })
    }::Frame & any,

    {
        ClassName = "Frame",
        Name = "Build_Content",
        Position = UDim2.fromScale(0, HeaderHeight),
        Size = UDim2.fromScale(1, 1 - HeaderHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,

        vision.event("Mode", "Browse", function(Content: Instance, _, Value: string)
            showMode(Content, Value == "Edit")
        end),

        editCard(),

        {
            ClassName = "UIPadding",
            Name = "Build_Padding",
            PaddingLeft = UDim.new(0.035, 0),
            PaddingRight = UDim.new(0.035, 0),
            PaddingTop = UDim.new(0.02, 0),
            PaddingBottom = UDim.new(0.018, 0)
        }::UIPadding & any,

        {
            ClassName = "UIListLayout",
            Name = "Build_Layout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0.0133, 0)
        }::UIListLayout & any,

        {
            ClassName = "Frame",
            Name = "Build_Actions",
            Size = UDim2.fromScale(1, 0.12),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 1,

            {
                ClassName = "UIListLayout",
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0.02, 0)
            },

            button("Build_Saves", "saves", 0.38, 1, Common["AccentColor"], Common["AccentText"], Color3.new(0, 0, 0), "Saves"),
            button("Build_Edit", "edit", 0.36, 2, Common["ButtonColor"], Common["InkColor"], nil, "Edit"),
            hidden(button("Build_Exit", "exit edit", 0.76, 3, Common["CloseColor"], Common["CloseText"], Color3.new(0, 0, 0), "Exit")),

            card("Build_Count", {
                Size = UDim2.fromScale(0.2, 1),
                LayoutOrder = 4
            }, {
                BackgroundColor3 = Common["PlateColor"],

                text("Build_Count_Current", "0", {
                    Position = UDim2.fromScale(0.1, 0.117),
                    Size = UDim2.fromScale(0.8, 0.38),
                    TextXAlignment = Enum.TextXAlignment.Center,

                    vision.event("CountCurrent", 0, function(Label: Instance, _, Value: number)
                        (Label :: TextLabel).Text = tostring(Value)
                    end)
                }),

                {
                    ClassName = "Frame",
                    Name = "Build_Count_Line",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.new(0.7, 0, 0, 2),
                    BackgroundColor3 = Common["InkColor"],
                    BorderSizePixel = 0
                },

                text("Build_Count_Max", "110", {
                    Position = UDim2.fromScale(0.1, 0.617),
                    Size = UDim2.fromScale(0.8, 0.38),
                    TextXAlignment = Enum.TextXAlignment.Center,

                    vision.event("CountMax", 110, function(Label: Instance, _, Value: number)
                        (Label :: TextLabel).Text = tostring(Value)
                    end)
                })
            }, nil, nil, ButtonStroke)
        }::Frame & any,

        card("Build_Search", {
            Size = UDim2.fromScale(1, 0.065),
            LayoutOrder = 2
        }, {
            ClassName = "TextBox",
            Text = "",
            PlaceholderText = "[ search props here ]",
            PlaceholderColor3 = Common["MutedColor"],
            TextColor3 = Common["InkColor"],
            FontFace = Typewriter,
            TextScaled = true,
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            PropertyChanged = {
                Text = function(_, Owner: vision.Vision, Value: string)
                    schedule(Owner, Value)
                end
            },
            FocusLost = function(Box: Instance, Owner: vision.Vision, Enter: boolean)
                if Enter then
                    SearchToken += 1
                    search(Owner, (Box :: TextBox).Text)
                end
            end,

            {
                ClassName = "UIPadding",
                PaddingLeft = UDim.new(0.03, 0),
                PaddingRight = UDim.new(0.03, 0),
                PaddingTop = UDim.new(0.15, 0),
                PaddingBottom = UDim.new(0.15, 0)
            }
        }),

        {
            ClassName = "Frame",
            Name = "Build_List_Well",
            Size = UDim2.fromScale(1, 0.715),
            BackgroundColor3 = Common["WellColor"],
            BorderSizePixel = 0,
            LayoutOrder = 3,
            outline(ButtonStroke),

            edge("Build_Well_Top", UDim2.new(1, 0, 0, WellRim), Vector2.zero, UDim2.new(), Common["WellShade"]),
            edge("Build_Well_Left", UDim2.new(0, WellRim, 1, 0), Vector2.zero, UDim2.new(), Common["WellShade"]),
            edge("Build_Well_Bottom", UDim2.new(1, 0, 0, WellRim), Vector2.new(0, 1), UDim2.fromScale(0, 1), Common["WellLight"]),
            edge("Build_Well_Right", UDim2.new(0, WellRim, 1, 0), Vector2.new(1, 0), UDim2.fromScale(1, 0), Common["WellLight"]),

            {
                ClassName = "ScrollingFrame",
                Name = "Build_List",
                Position = UDim2.fromOffset(WellInset, WellInset),
                Size = UDim2.new(1, -WellInset * 2, 1, -WellInset * 2),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                ScrollBarThickness = 10,
                ScrollBarImageColor3 = Common["OutlineColor"],
                VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
                Destroying = function(List: Instance)
                    clear(List)
                end,
                PropertyChanged = {
                    AbsoluteCanvasSize = function(List: Instance)
                        gutter(List)
                    end,
                    AbsoluteWindowSize = function(List: Instance)
                        gutter(List)
                    end
                },

                vision.event("LoadPage", {}, function(List: Instance, _, Entries: { Bridges.Entry })
                    render(List, Entries)
                end),

                vision.cleanup(function(List: Instance, _)
                    clear(List)
                end),

                {
                    ClassName = "UIListLayout",
                    FillDirection = Enum.FillDirection.Vertical,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 8)
                },

                {
                    ClassName = "UIPadding",
                    Name = "Build_List_Padding",
                    PaddingRight = UDim.new(0, ListEdge),
                    PaddingLeft = UDim.new(0, ListEdge),
                    PaddingTop = UDim.new(0.01),
                    PaddingBottom = UDim.new(0, 6)
                },

                {
                    ClassName = "Frame",
                    Name = "Build_List_Spacer",
                    Size = UDim2.new(1, 0, 0, ListSpacer),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    LayoutOrder = 1000000
                }
            }::ScrollingFrame & any
        }::Frame & any,

        {
            ClassName = "Frame",
            Name = "Build_Pages",
            Size = UDim2.fromScale(1, 0.06),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 4,

            card("Build_Page_Prev", {
                Size = UDim2.fromScale(0.2, 1)
            }, pageButton("<", -1), nil, nil, ButtonStroke),

            card("Build_Page_Box", {
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.fromScale(0.5, 0),
                Size = UDim2.fromScale(0.5, 1)
            }, {
                BackgroundColor3 = Common["PlateColor"],

                text("Build_Page_Label", "page 1", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.57),
                    Size = UDim2.fromScale(0.84, 0.72),
                    TextXAlignment = Enum.TextXAlignment.Center,

                    vision.event("Page", 1, function(Label: Instance, _, Value: number)
                        (Label :: TextLabel).Text = `page {Value}`
                    end),

                    {
                        ClassName = "UIStroke",
                        Name = "Build_Page_Outline",
                        Color = Color3.fromRGB(240, 236, 230),
                        Thickness = 1.5,
                        LineJoinMode = Enum.LineJoinMode.Round,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
                    }
                })
            }, nil, nil, ButtonStroke),

            card("Build_Page_Next", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.fromScale(1, 0),
                Size = UDim2.fromScale(0.2, 1)
            }, pageButton(">", 1), nil, nil, ButtonStroke)
        }::Frame & any
    }::Frame & any

}::Frame & any)
