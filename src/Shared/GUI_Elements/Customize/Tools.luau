--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Bridges = require(ReplicatedStorage.Shared.Customize.Bridges)
const Kit = require(script.Parent.Kit)

const Style = Kit.Style
const Common = Kit.Common
const Bridge = Bridges.Tools

const Page = {
    Slots = 5,
    SlotSize = 96,
    HolsterWidth = 384,
    HolsterHeight = 780,
    Modes = {
        { Id = "Translate", Label = "move" },
        { Id = "Rotate", Label = "rotate" },
        { Id = "None", Label = "off" },
    },
}

const function card(Name: string, Title: string, Detail: string, Fill: Color3, DetailColor: Color3, Action: string, Value: any, Order: number): Kit.Declaration
    return Parts.card(Name, {
        Size = UDim2.new(1, 0, 0, 60),
        LayoutOrder = Order,
    }, {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Fill,
        Activated = function()
            Bridge:Call(Action, Value)
        end,
        Parts.bevel(`{Name}_Shine`, 3, Kit.light(Fill), Kit.dark(Fill)),

        Kit.text("Name", Title, 18, {
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -40, 0, 22),
            FontFace = Parts.Heading,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }),

        Kit.text("Detail", Detail, 13, {
            Position = UDim2.fromOffset(14, 33),
            Size = UDim2.new(1, -40, 0, 16),
            TextColor3 = DetailColor,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }),

        Kit.text("Arrow", ">", 22, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(20, 28),
            FontFace = Parts.Heading,
            TextXAlignment = Enum.TextXAlignment.Center,
        }),
    }, 3, nil, Kit.ItemStroke)
end

const function partRow(View: Bridges.ToolPartRow, Order: number): Kit.Declaration
    const Indent = math.max(View.Depth - 1, 0) * 18
    const Inner: Kit.Declaration = {
        BackgroundColor3 = Common["CardColor"],

        Kit.text("Label", View.Label, 13, {
            Position = UDim2.fromOffset(12 + Indent, 6),
            Size = UDim2.new(1, -(64 + Indent), 0, 16),
            TextColor3 = Style.PackColor,
        }),

        Kit.text("Name", View.Name, 16, {
            Position = UDim2.fromOffset(12 + Indent, 23),
            Size = UDim2.new(1, -(64 + Indent), 0, 20),
            FontFace = Parts.Heading,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }),
    }
    if not View.Required then
        table.insert(Inner, Kit.close(`ToolPart_{Order}_Remove`, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
        }, Bridge, "Remove", View.Path, 32))
    end
    return Parts.card(`ToolPart_{Order}`, {
        Size = UDim2.new(1, 0, 0, 50),
        LayoutOrder = Order,
    }, Inner, nil, nil, Kit.ItemStroke)
end

const function synced(Name: string, Event: string, Build: (Items: { any }) -> { Kit.Item }, Order: number?): Kit.Declaration
    return {
        ClassName = "Frame",
        Name = Name,
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = Order,
        Destroying = function(Self: Instance)
            Kit.clear(Self)
        end,

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        },

        vision.event(Event, {}, function(Self: Instance, _, Items: { any })
            Kit.sync(Self, Build(Items))
        end),

        vision.cleanup(function(Self: Instance, _)
            Kit.clear(Self)
        end),
    }
end

const function back(Name: string, Label: string, Order: number): Kit.Declaration
    return Kit.press(Name, Label, { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = Order }, Style.PlateColor, Style.InkColor, Bridge, "Back", nil, false, 16)
end

function Page.page(): Kit.Declaration
    return Kit.panel("Tools", "tools", {
        Size = UDim2.fromScale(1, 1),
        Visible = false,

        vision.event("ToolPage", { Mode = "Categories", Title = "tools", Name = "", Detail = "", Equipping = false }, function(Self: Instance, _, View: Bridges.ToolPageView)
            Kit.label(Self, "Tools_Title", View.Title)
            Kit.setButton(Self, "Tool_Equip", if View.Equipping then "cancel" else "equip", if View.Equipping then Style.CloseColor else Style.SuccessColor, if View.Equipping then Style.CloseText else Style.SuccessText)
            Kit.show(Self, "Tools_CategorySection", View.Mode == "Categories")
            Kit.show(Self, "Tools_BrowseSection", View.Mode == "Category")
            Kit.show(Self, "Tools_EditSection", View.Mode == "Edit")
            Kit.label(Self, "Tool_Name", View.Name)
            Kit.label(Self, "Tool_Detail", View.Detail)
        end),
    }, {
        Parts.merge(Kit.body("Tools_List"), {
            Kit.section("Tools_CategorySection", "pick a category", 1, {
                synced("Tools_Categories", "ToolCategoryList", function(Rows: { any }): { Kit.Item }
                    const Items: { Kit.Item } = {}
                    for Index, View in Rows :: { Bridges.ToolCard } do
                        table.insert(Items, {
                            Key = View.Id,
                            Hash = `{View.Name}|{View.Detail}`,
                            Build = function(): Kit.Declaration
                                return card(`Category_{View.Id}`, View.Name, View.Detail, Style.CardColor, Style.PackColor, "Category", View.Id, Index)
                            end,
                        })
                    end
                    return Items
                end, 1),
                Kit.text("Tools_SlotHint", "press a slot at the bottom to edit what is in it", 13, {
                    TextWrapped = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    TextColor3 = Common["OutlineColor"],
                    LayoutOrder = 2,
                }),
            }),

            Parts.merge(Kit.section("Tools_BrowseSection", "pick a tool", 2, {
                back("Tools_BrowseBack", "back to categories", 1),
                synced("Tools_Cards", "ToolCards", function(Rows: { any }): { Kit.Item }
                    const Items: { Kit.Item } = {}
                    for Index, View in Rows :: { Bridges.ToolCard } do
                        table.insert(Items, {
                            Key = View.Id,
                            Hash = `{View.Name}|{View.Detail}|{View.Locked}`,
                            Build = function(): Kit.Declaration
                                return card(`ToolCard_{View.Id}`, View.Name, View.Detail, if View.Locked then Style.PlateColor else Style.CardColor, if View.Locked then Style.CloseColor else Style.PackColor, "Pick", View.Id, Index)
                            end,
                        })
                    end
                    return Items
                end, 2),
            }), { Visible = false }),

            Parts.merge(Kit.section("Tools_EditSection", "editing", 3, {
                back("Tools_EditBack", "back, throw away changes", 1),
                Kit.text("Tool_Name", "", 21, {
                    FontFace = Parts.Heading,
                    LayoutOrder = 2,
                }),
                Kit.text("Tool_Detail", "", 14, {
                    TextWrapped = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    TextColor3 = Common["PackColor"],
                    LayoutOrder = 3,
                }),
                Kit.text("Tool_PartsHint", "press a + on the tool to add or swap a part", 13, {
                    TextWrapped = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    TextColor3 = Common["OutlineColor"],
                    LayoutOrder = 4,
                }),
                synced("Tool_Parts", "ToolParts", function(Rows: { any }): { Kit.Item }
                    const Items: { Kit.Item } = {}
                    for Index, View in Rows :: { Bridges.ToolPartRow } do
                        table.insert(Items, {
                            Key = View.Path,
                            Hash = `{View.Label}|{View.Name}|{View.Required}|{View.Depth}|{Index}`,
                            Build = function(): Kit.Declaration
                                return partRow(View, Index)
                            end,
                        })
                    end
                    return Items
                end, 5),
                Kit.press("Tool_Equip", "equip", { Size = UDim2.new(1, 0, 0, 54), LayoutOrder = 6 }, Style.SuccessColor, Style.SuccessText, Bridge, "Equip", nil, false, 22),
                Kit.text("Tool_EquipHint", "equip saves this tool into a hotbar slot", 13, {
                    TextWrapped = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    TextColor3 = Common["OutlineColor"],
                    LayoutOrder = 7,
                }),
            }), { Visible = false }),
        }),
    })
end

const function slotCard(View: Bridges.SlotCard): Kit.Declaration
    const Fill = if View.Picked then Kit.Picked elseif View.Filled then Style.CardColor else Style.PlateColor
    const Inner: Kit.Declaration = {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Fill,
        Activated = function()
            Bridge:Call("SlotPress", View.Slot)
        end,
        Parts.bevel(`ToolSlot_{View.Slot}_Shine`, 3, Kit.light(Fill), Kit.dark(Fill)),

        Parts.keyBadge(tostring(View.Slot), 24, {
            Position = UDim2.fromOffset(5, 5),
            ZIndex = 4,
        }),

        Kit.text("Name", View.Name, 13, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 4, 1, -4),
            Size = UDim2.new(1, -8, 0, 18),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            FontFace = Parts.Heading,
        }),
    }
    if View.Clear then
        table.insert(Inner, Kit.close(`ToolSlot_{View.Slot}_Clear`, {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -4, 0, 4),
            ZIndex = 5,
        }, Bridge, "SlotClear", View.Slot, 26))
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
    return Parts.card(`ToolSlot_{View.Slot}`, {
        Size = UDim2.fromOffset(Page.SlotSize, Page.SlotSize),
        LayoutOrder = View.Slot,
    }, Inner, 3, nil, Kit.Stroke)
end

function Page.slotBar(): Kit.Declaration
    const Width = Page.Slots * Page.SlotSize + (Page.Slots - 1) * 10 + 28
    return {
        ClassName = "Frame",
        Name = "ToolSlotBar",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -12),
        Size = UDim2.fromOffset(Width, Page.SlotSize + 62),
        BackgroundColor3 = Style.BackdropColor,
        BorderSizePixel = 0,
        Visible = false,
        Parts.outline(2),
        Parts.bevel("ToolSlotBar_Bevel", 4, Style.BevelLight, Style.BevelDark),

        { ClassName = "UIScale" },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            VisionKit.fit(Self :: GuiObject, Later, 0.6)
        end),

        vision.event("ToolSlotBar", false, function(Self: Instance, _, View: Bridges.SlotBarView | false)
            (Self :: GuiObject).Visible = View ~= false
            const Row = Self:FindFirstChild("ToolSlotBar_Row")
            if not View or not Row then
                return
            end
            Kit.label(Self, "ToolSlotBar_Title", View.Title)
            const Items: { Kit.Item } = {}
            for _, Slot in View.Slots do
                table.insert(Items, {
                    Key = tostring(Slot.Slot),
                    Hash = `{Slot.Name}|{Slot.Filled}|{Slot.Picked}|{Slot.Clear}|{if Slot.Model then tostring(Slot.Model:GetAttribute("BuildHash")) else ""}`,
                    Build = function(): Kit.Declaration
                        return slotCard(Slot)
                    end,
                })
            end
            Kit.sync(Row, Items)
        end),

        Kit.text("ToolSlotBar_Title", "", 16, {
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -28, 0, 22),
            FontFace = Parts.Heading,
            TextXAlignment = Enum.TextXAlignment.Center,
        }),

        {
            ClassName = "Frame",
            Name = "ToolSlotBar_Row",
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -12),
            Size = UDim2.new(1, -28, 0, Page.SlotSize),
            BackgroundTransparency = 1,
            Destroying = function(Self: Instance)
                Kit.clear(Self)
            end,

            {
                ClassName = "UIListLayout",
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 10),
            },

            vision.cleanup(function(Self: Instance, _)
                Kit.clear(Self)
            end),
        },
    }
end

function Page.ask(): Kit.Declaration
    return Kit.panel("ToolAsk", "are you sure?", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(420, 220),
        Visible = false,
        ZIndex = 30,

        { ClassName = "UIScale" },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            VisionKit.fit(Self :: GuiObject, Later, 0.6)
        end),

        vision.event("ToolAsk", false, function(Self: Instance, _, Text: string | false)
            (Self :: GuiObject).Visible = Text ~= false
            if Text then
                Kit.label(Self, "ToolAsk_Text", Text)
            end
        end),
    }, {
        Kit.text("ToolAsk_Text", "", 16, {
            Position = UDim2.fromOffset(Kit.Margin + 6, Kit.Margin + Kit.HeaderHeight + 14),
            Size = UDim2.new(1, -(Kit.Margin + 6) * 2, 0, 60),
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Top,
        }),
        Kit.press("ToolAsk_No", "no", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, Kit.Margin, 1, -Kit.Margin),
            Size = UDim2.new(0.5, -(Kit.Margin + 6), 0, 48),
        }, Style.PlateColor, Style.InkColor, Bridge, "AskNo", nil, false, 18),
        Kit.press("ToolAsk_Yes", "yes", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -Kit.Margin, 1, -Kit.Margin),
            Size = UDim2.new(0.5, -(Kit.Margin + 6), 0, 48),
        }, Style.SuccessColor, Style.SuccessText, Bridge, "AskYes", nil, true, 18),
    })
end

const function choiceCard(View: Bridges.MountChoice, Order: number): Kit.Declaration
    const Fill = if View.Active then Kit.Picked elseif View.Locked then Style.PlateColor else Style.CardColor
    return Parts.card(`Choice_{View.Id}`, {
        Size = UDim2.new(1, 0, 0, 54),
        LayoutOrder = Order,
    }, {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Fill,
        Activated = function()
            Bridge:Call("Choose", View.Id)
        end,
        Parts.bevel(`Choice_{View.Id}_Shine`, 3, Kit.light(Fill), Kit.dark(Fill)),

        Kit.text("Name", View.Name, 16, {
            Position = UDim2.fromOffset(12, 7),
            Size = UDim2.new(1, -24, 0, 20),
            FontFace = Parts.Heading,
        }),
        Kit.text("Detail", View.Detail, 13, {
            Position = UDim2.fromOffset(12, 30),
            Size = UDim2.new(1, -24, 0, 16),
            TextColor3 = if View.Locked then Style.CloseColor else Style.PackColor,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }),
    }, 3, nil, Kit.ItemStroke)
end

function Page.picker(): Kit.Declaration
    return Kit.panel("ToolMount", "pick a part", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(420, 470),
        Visible = false,
        ZIndex = 20,

        { ClassName = "UIScale" },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            VisionKit.fit(Self :: GuiObject, Later, 0.55)
            const Header = Self:FindFirstChild("ToolMount_Header")
            if Header and Header:IsA("GuiObject") then
                Header.Active = true
                Parts.draggable(Self :: GuiObject, Header, Later)
            end
        end),

        vision.event("ToolMountOpen", false, function(Self: Instance, _, View: Bridges.MountView | false)
            (Self :: GuiObject).Visible = View ~= false
            if View then
                Kit.label(Self, "ToolMount_Title", View.Title)
            end
        end),
    }, {
        Kit.close("ToolMount_Close", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -(Kit.Margin + 10), 0, Kit.Margin + Kit.HeaderHeight / 2),
            ZIndex = 5,
        }, Bridge, "MountClose", nil, 36),

        Parts.merge(Kit.body("ToolMount_List"), {
            synced("ToolMount_Choices", "ToolMountChoices", function(Choices: { any }): { Kit.Item }
                const Items: { Kit.Item } = {}
                for Index, View in Choices :: { Bridges.MountChoice } do
                    table.insert(Items, {
                        Key = View.Id,
                        Hash = `{View.Name}|{View.Detail}|{View.Locked}|{View.Active}`,
                        Build = function(): Kit.Declaration
                            return choiceCard(View, Index)
                        end,
                    })
                end
                return Items
            end),
        }),
    })
end

const function modeRow(): Kit.Declaration
    const Buttons: { Kit.Declaration } = {}
    for Order, Mode in Page.Modes do
        table.insert(Buttons, Kit.press(`Holster_Mode_{Mode.Id}`, Mode.Label, { Size = UDim2.fromOffset(92, 40), LayoutOrder = Order }, Style.ButtonColor, Style.InkColor, Bridge, "HolsterMode", Mode.Id, false, 16))
    end
    return Kit.row("Holster_Modes", 42, 4, Buttons)
end

const function sizeRow(): Kit.Declaration
    const Ink = Style.InkColor
    const Fill = Style.ButtonColor
    return Kit.row("Holster_Size", 42, 6, {
        Kit.text("Holster_SizeLabel", "size", 16, {
            Size = UDim2.fromOffset(44, 40),
            TextYAlignment = Enum.TextYAlignment.Center,
        }),
        Kit.press("Holster_SizeLess", "-", { Size = UDim2.fromOffset(40, 40) }, Fill, Ink, Bridge, "HolsterSize", { Step = -1 }, false, 22),
        Kit.text("Holster_SizeValue", "1.00x", 17, {
            Size = UDim2.fromOffset(60, 40),
            FontFace = Parts.Heading,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
        }),
        Kit.press("Holster_SizeMore", "+", { Size = UDim2.fromOffset(40, 40) }, Fill, Ink, Bridge, "HolsterSize", { Step = 1 }, false, 22),
        Kit.press("Holster_SizeNormal", "normal", { Size = UDim2.fromOffset(74, 40) }, Style.PlateColor, Ink, Bridge, "HolsterSize", { Step = 0 }, false, 14),
    })
end

function Page.holster(): Kit.Declaration
    return {
        ClassName = "Frame",
        Name = "Holster_Dock",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(Page.HolsterWidth, Page.HolsterHeight),
        BackgroundTransparency = 1,
        Visible = false,

        { ClassName = "UIScale" },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            VisionKit.fit(Self :: GuiObject, Later, 0.5)
        end),

        vision.event("HolsterState", { Shown = false, On = false, Attach = "", Size = "", Mode = "None", Looking = "" }, function(Self: Instance, _, View: Bridges.HolsterView)
            (Self :: GuiObject).Visible = View.Shown
            Kit.setButton(Self, "Holster_Toggle", if View.On then "on my rig: on" else "on my rig: off", if View.On then Style.SuccessColor else Style.ButtonColor, if View.On then Style.SuccessText else Style.InkColor)
            Kit.show(Self, "Holster_Settings", View.On)
            Kit.label(Self, "Holster_SizeValue", View.Size)
            Kit.setButton(Self, "Holster_View", View.Looking)
            for _, Mode in Page.Modes do
                const On = View.Mode == Mode.Id
                Kit.setButton(Self, `Holster_Mode_{Mode.Id}`, nil, if On then Style.AccentColor else Style.ButtonColor, if On then Style.AccentText else Style.InkColor)
            end
            const Lit: { [string]: boolean } = {}
            if View.Attach ~= "" then
                Lit[View.Attach] = true
            end
            Kit.paintFigure(Self, "Holster_Figure", Lit)
        end),

        Kit.panel("Holster", "on your rig", {
            Size = UDim2.fromScale(1, 1),
        }, {
            Parts.merge(Kit.body("Holster_List"), {
                Kit.section("Holster_Main", "show it when put away", 1, {
                    Kit.press("Holster_Toggle", "on my rig: off", { Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 1 }, Style.ButtonColor, Style.InkColor, Bridge, "HolsterToggle", nil, false, 17),
                    Kit.press("Holster_View", "look at my rig", { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 2 }, Style.PlateColor, Style.InkColor, Bridge, "View", nil, false, 16),
                }),

                Parts.merge(Kit.section("Holster_Settings", "where it sits", 2, {
                    Kit.text("Holster_FigureHint", "pick a body part to weld it to", 14, {
                        TextColor3 = Common["OutlineColor"],
                        LayoutOrder = 1,
                    }),
                    Kit.row("Holster_FigureRow", Kit.FigureSize.Y, 2, {
                        { ClassName = "Frame", Name = "Holster_FigurePad", Size = UDim2.fromOffset(52, 10), BackgroundTransparency = 1 },
                        Kit.figure("Holster_Figure", Bridge, "HolsterAttach", 2),
                    }),
                    Kit.text("Holster_ModeHint", "use the handles on your rig to move and turn it", 13, {
                        TextWrapped = true,
                        AutomaticSize = Enum.AutomaticSize.Y,
                        TextColor3 = Common["OutlineColor"],
                        LayoutOrder = 3,
                    }),
                    modeRow(),
                    Kit.text("Holster_SizeHint", "size changes the whole tool evenly, it can not be stretched", 13, {
                        TextWrapped = true,
                        AutomaticSize = Enum.AutomaticSize.Y,
                        TextColor3 = Common["OutlineColor"],
                        LayoutOrder = 5,
                    }),
                    sizeRow(),
                }), { Visible = false }),
            }),
        }),
    }
end

return Page
