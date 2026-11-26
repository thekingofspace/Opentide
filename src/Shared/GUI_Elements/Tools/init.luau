--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TextService = game:GetService("TextService")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Kit = require(ReplicatedStorage.Shared.GUI_Elements.Customize.Kit)
const Bridges = require(ReplicatedStorage.Shared.Tools.Bridges)

const Style = Kit.Style
const Bridge = Bridges.Hud

const SlotSize = 132
const Gap = 12
const Count = 5

const function slotCard(View: Bridges.SlotView): Kit.Declaration
    const Fill = if View.Active then Kit.Picked elseif View.Tool then Style.CardColor else Style.PlateColor
    const Inner: Kit.Declaration = {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Fill,
        Activated = function()
            Bridge:Call("Slot", View.Slot)
        end,
        Parts.bevel(`Slot_{View.Slot}_Shine`, 3, Kit.light(Fill), Kit.dark(Fill)),

        Parts.keyBadge(tostring(View.Slot), 32, {
            Position = UDim2.fromOffset(5, 5),
            ZIndex = 4,
        }),

        Kit.text("Name", View.Name, 17, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 4, 1, -5),
            Size = UDim2.new(1, -8, 0, 22),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            FontFace = Parts.Heading,
        }),
    }
    if View.Linkable or View.Linked then
        const Linked = View.Linked
        const LinkFill = if View.Linking then Kit.Picked elseif Linked then Style.AccentColor else Style.PlateColor
        const LinkInk = if Linked and not View.Linking then Style.AccentText else Style.InkColor
        table.insert(Inner, {
            ClassName = "TextButton",
            Name = "Link",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -5, 0, 5),
            Size = UDim2.fromOffset(if Linked then 70 else 50, 26),
            BackgroundColor3 = LinkFill,
            BorderSizePixel = 0,
            AutoButtonColor = true,
            Text = if View.Linking then "pick" elseif Linked then `link {Linked}` else "link",
            FontFace = Parts.Heading,
            TextSize = 14,
            TextColor3 = LinkInk,
            ZIndex = 5,
            Activated = function()
                Bridge:Call("Link", View.Slot)
            end,
            Parts.outline(1.2),
        })
    end
    const Model = View.Model
    if Model then
        table.insert(Inner, {
            ClassName = "ViewportFrame",
            Name = "Art",
            Position = UDim2.fromOffset(8, 8),
            Size = UDim2.new(1, -16, 1, -30),
            BackgroundTransparency = 1,
            Ambient = Color3.fromRGB(170, 170, 170),
            LightColor = Color3.new(1, 1, 1),
            LightDirection = Vector3.new(-1, -1.5, -1),
            vision.ready(function(Self: Instance, _, _)
                Kit.stage(Self :: ViewportFrame, Model, false)
            end),
        })
    end
    return Parts.card(`Slot_{View.Slot}`, {
        Size = UDim2.fromOffset(SlotSize, SlotSize),
    }, Inner, 3, nil, Kit.Stroke)
end

const function hotbar(): Kit.Declaration
    return {
        ClassName = "Frame",
        Name = "Hotbar",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -10),
        Size = UDim2.fromOffset(Count * SlotSize + (Count - 1) * Gap + 36, SlotSize + 80),
        BackgroundTransparency = 1,
        Visible = false,

        { ClassName = "UIScale" },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            VisionKit.fit(Self :: GuiObject, Later, 0.6)
        end),

        vision.event("HotbarShown", false, function(Self: Instance, _, Value: boolean)
            (Self :: GuiObject).Visible = Value == true
        end),

        vision.event("HotbarOpen", true, function(Self: Instance, _, Value: boolean)
            Kit.show(Self, "Hotbar_Tray", Value)
            Kit.setButton(Self, "Hotbar_Tab", if Value then "tools  v" else "tools  ^")
            const Tab = Self:FindFirstChild("Hotbar_Tab")
            if Tab and Tab:IsA("GuiObject") then
                Tab.Position = if Value then UDim2.new(0.5, 0, 1, -(SlotSize + 38)) else UDim2.new(0.5, 0, 1, 0)
            end
        end),

        Kit.press("Hotbar_Tab", "tools  v", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -(SlotSize + 38)),
            Size = UDim2.fromOffset(170, 40),
        }, Style.HeaderColor, Style.CardColor, Bridge, "Toggle", nil, true, 18),

        {
            ClassName = "Frame",
            Name = "Hotbar_Tray",
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.fromScale(0.5, 1),
            Size = UDim2.new(1, 0, 0, SlotSize + 32),
            BackgroundColor3 = Style.BackdropColor,
            BorderSizePixel = 0,
            Parts.outline(2),
            Parts.bevel("Hotbar_Bevel", 4, Style.BevelLight, Style.BevelDark),

            {
                ClassName = "Frame",
                Name = "Hotbar_Slots",
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Destroying = function(Self: Instance)
                    Kit.clear(Self)
                end,

                {
                    ClassName = "UIListLayout",
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, Gap),
                },

                vision.event("HotbarSlots", {}, function(Self: Instance, _, Views: { Bridges.SlotView })
                    const Items: { Kit.Item } = {}
                    for _, View in Views do
                        table.insert(Items, {
                            Key = tostring(View.Slot),
                            Hash = `{View.Name}|{View.Tool or ""}|{View.Active}|{View.Linked or 0}|{View.Linking}|{View.Linkable}|{if View.Model then tostring(View.Model:GetAttribute("BuildHash")) else ""}`,
                            Build = function(): Kit.Declaration
                                return slotCard(View)
                            end,
                        })
                    end
                    Kit.sync(Self, Items)
                end),

                vision.cleanup(function(Self: Instance, _)
                    Kit.clear(Self)
                end),
            },
        },
    }
end

const ActionHeight = 54
const ActionText = 18
const ActionBadge = 30
const TrayPad = 14
const TrayHeight = ActionHeight + TrayPad * 2
const TabHeight = 36

const function widthOf(Text: string, Size: number): number
    return TextService:GetTextSize(Text, Size, Enum.Font.SpecialElite, Vector2.new(1000, 100)).X
end

const function actionWidth(View: Bridges.ActionView): number
    return widthOf(View.Label, ActionText) + (if View.Key then ActionBadge + 12 else 0) + 40
end

const function actionButton(View: Bridges.ActionView, Order: number): Kit.Declaration
    const Fill = if View.On then Style.AccentColor else Style.ButtonColor
    const Ink = if View.On then Style.AccentText else Style.InkColor
    const Badge = if View.Key then ActionBadge + 12 else 0
    const Inner: Kit.Declaration = {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Fill,
        Activated = function()
            Bridge:Call("Action", View.Id)
        end,
        Parts.bevel(`Action_{View.Id}_Shine`, 3, Kit.light(Fill), Kit.dark(Fill)),

        Kit.text("Label", View.Label, ActionText, {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, Badge + 18, 0.5, 0),
            Size = UDim2.new(1, -(Badge + 26), 0, ActionText + 6),
            FontFace = Parts.Heading,
            TextColor3 = Ink,
            TextYAlignment = Enum.TextYAlignment.Center,
        }),
    }
    if View.Key then
        table.insert(Inner, Parts.keyBadge(View.Key, ActionBadge, {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 12, 0.5, 0),
        }))
    end
    return Parts.card(`Action_{View.Id}`, {
        Size = UDim2.fromOffset(actionWidth(View), ActionHeight),
        LayoutOrder = Order,
    }, Inner, 3, nil, Kit.Stroke)
end

const function actionBar(): Kit.Declaration
    return {
        ClassName = "Frame",
        Name = "ActionBar",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 10),
        Size = UDim2.fromOffset(200, TrayHeight + TabHeight + 6),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,

        { ClassName = "UIScale" },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            VisionKit.fit(Self :: GuiObject, Later, 0.6)
        end),

        vision.event("ActionBarOpen", true, function(Self: Instance, _, Value: boolean)
            Kit.show(Self, "ActionBar_Tray", Value)
            Kit.setButton(Self, "ActionBar_Tab", if Value then "actions  ^" else "actions  v")
            const Tab = Self:FindFirstChild("ActionBar_Tab")
            if Tab and Tab:IsA("GuiObject") then
                Tab.Position = if Value then UDim2.new(0.5, 0, 0, TrayHeight + 6) else UDim2.fromScale(0.5, 0)
            end
        end),

        vision.event("ActionBar", false, function(Self: Instance, _, View: Bridges.BarView | false)
            (Self :: GuiObject).Visible = View ~= false
            const Tray = Self:FindFirstChild("ActionBar_Tray")
            const Row = if Tray then Tray:FindFirstChild("ActionBar_Row") else nil
            if not Row then
                return
            end
            if not View then
                Kit.clear(Row)
                return
            end
            local Width = TrayPad * 2
            const Items: { Kit.Item } = {}
            for Index, Action in View.Actions do
                Width += actionWidth(Action) + (if Index > 1 then 10 else 0)
                table.insert(Items, {
                    Key = Action.Id,
                    Hash = `{Action.Label}|{Action.Key or ""}|{Action.On}`,
                    Build = function(): Kit.Declaration
                        return actionButton(Action, Index)
                    end,
                })
            end
            (Self :: GuiObject).Size = UDim2.fromOffset(math.max(Width, 190), TrayHeight + TabHeight + 6)
            Kit.sync(Row, Items)
        end),

        Kit.press("ActionBar_Tab", "actions  ^", {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, TrayHeight + 6),
            Size = UDim2.fromOffset(170, TabHeight),
        }, Style.HeaderColor, Style.CardColor, Bridge, "ActionToggle", nil, true, 18),

        {
            ClassName = "Frame",
            Name = "ActionBar_Tray",
            Size = UDim2.new(1, 0, 0, TrayHeight),
            BackgroundColor3 = Style.BackdropColor,
            BorderSizePixel = 0,
            Parts.outline(2),
            Parts.bevel("ActionBar_Bevel", 4, Style.BevelLight, Style.BevelDark),

            {
                ClassName = "Frame",
                Name = "ActionBar_Row",
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Destroying = function(Self: Instance)
                    Kit.clear(Self)
                end,

                {
                    ClassName = "UIListLayout",
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 10),
                },

                vision.cleanup(function(Self: Instance, _)
                    Kit.clear(Self)
                end),
            },
        },
    }
end

return Kit.Scope:Capture({
    ClassName = "Frame",
    Name = "ToolsHud",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,

    hotbar(),
    actionBar(),
}::Frame & any)
