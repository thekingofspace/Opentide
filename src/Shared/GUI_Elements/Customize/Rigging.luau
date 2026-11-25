--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")
const vision = require(ReplicatedStorage.MainPackages.vision)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Bridges = require(ReplicatedStorage.Shared.Customize.Bridges)
const Kit = require(script.Parent.Kit)

type Drag = {
    Id: string,
    Name: string,
    Tag: string,
    Input: InputObject,
    Start: Vector2,
    Source: GuiObject,
    Ghost: vision.Vision?,
    Shade: Frame?,
    Hover: UIStroke?,
    Grab: Vector2,
}

const Style = Kit.Style
const Common = Kit.Common
const Bridge = Bridges.Rig

const Rigging = {
    RowHeight = 54,
    DropAttribute = "CustomizeDrop",
    DragDistance = 6,
    Hint = "hold a part and drag it onto another part to group them. drag it onto empty space to take it out of a group",
}

local Dragging: Drag? = nil
local Layer: ScreenGui? = nil

const function layer(): ScreenGui
    const Known = Layer
    if Known and Known.Parent then
        return Known
    end
    const Made = Instance.new("ScreenGui")
    Made.Name = "CustomizeDrag"
    Made.DisplayOrder = 60
    Made.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Made.ResetOnSpawn = false
    Made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    Layer = Made
    return Made
end

const function scaleOf(Item: Instance): number
    local Total = 1
    local Node: Instance? = Item.Parent
    while Node do
        const Scale = Node:FindFirstChildOfClass("UIScale")
        if Scale then
            Total *= Scale.Scale
        end
        Node = Node.Parent
    end
    return Total
end

const function point(Input: InputObject): Vector2
    return Vector2.new(Input.Position.X, Input.Position.Y)
end

const function targetAt(Spot: Vector2): (string?, Instance?)
    const Gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    const Above = Layer
    if not Gui then
        return nil, nil
    end
    for _, Object in Gui:GetGuiObjectsAtPosition(Spot.X, Spot.Y) do
        if Above and Object:IsDescendantOf(Above) then
            continue
        end
        local Node: Instance? = Object
        while Node and Node ~= Gui do
            const Key = Node:GetAttribute(Rigging.DropAttribute)
            if type(Key) == "string" then
                return Key, Node
            end
            Node = Node.Parent
        end
    end
    return nil, nil
end

const function hover(Current: Drag, Spot: Vector2)
    const Old = Current.Hover
    if Old then
        Old.Color = Style.InkColor
        Old.Thickness = Old:GetAttribute("BaseThickness") :: number? or Kit.Stroke
        Current.Hover = nil
    end
    const Key, Node = targetAt(Spot)
    if not Key or Key == "list" or Key == `part:{Current.Id}` or not Node then
        return
    end
    const Stroke = Node:FindFirstChildOfClass("UIStroke")
    if Stroke then
        if Stroke:GetAttribute("BaseThickness") == nil then
            Stroke:SetAttribute("BaseThickness", Stroke.Thickness)
        end
        Stroke.Color = Kit.Picked
        Stroke.Thickness = 4
        Current.Hover = Stroke
    end
end

const function ghost(Current: Drag, Width: number, Scale: number): Kit.Declaration
    return Parts.card("Ghost", {
        Size = UDim2.fromOffset(Width, Rigging.RowHeight),
        Rotation = 2,
        vision.mount(layer()),
        {
            ClassName = "UIScale",
            Scale = Scale,
        },
    }, {
        BackgroundColor3 = Kit.Picked,

        Kit.text("Name", Current.Name, 16, {
            Position = UDim2.fromOffset(14, 7),
            Size = UDim2.new(1, -28, 0, 20),
            FontFace = Parts.Heading,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextColor3 = Style.InkColor,
        }),

        Kit.text("Tag", "drop on a part or group", 12, {
            Position = UDim2.fromOffset(14, 29),
            Size = UDim2.new(1, -28, 0, 16),
            TextColor3 = Style.InkColor,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }),
    }, Kit.Depth, nil, Kit.Stroke)
end

const function lift(Current: Drag)
    const Source = Current.Source
    const Scale = scaleOf(Source)
    const Made = Kit.Scope:Capture(ghost(Current, 260, Scale))
    Made:Mount()
    Current.Grab = Vector2.new(-12, -8)
    const Root = Made:Open()
    if Root and Root:IsA("GuiObject") then
        const Corner = Current.Start - Current.Grab
        Root.Position = UDim2.fromOffset(Corner.X, Corner.Y)
    end
    Current.Ghost = Made

    const Shade = Instance.new("Frame")
    Shade.Name = "DragShade"
    Shade.Size = UDim2.fromScale(1, 1)
    Shade.BackgroundColor3 = Color3.new(0, 0, 0)
    Shade.BackgroundTransparency = 0.6
    Shade.BorderSizePixel = 0
    Shade.ZIndex = 50
    Shade.Parent = Source
    Current.Shade = Shade
end

const function follow(Current: Drag, Spot: Vector2)
    const Ghost = Current.Ghost
    if not Ghost then
        if (Spot - Current.Start).Magnitude < Rigging.DragDistance then
            return
        end
        lift(Current)
    end
    const Lifted = Current.Ghost
    const Root = if Lifted then Lifted:Open() else nil
    if Root and Root:IsA("GuiObject") then
        const Corner = Spot - Current.Grab
        Root.Position = UDim2.fromOffset(Corner.X, Corner.Y)
    end
    hover(Current, Spot)
end

const function finish(Spot: Vector2?)
    const Current = Dragging
    if not Current then
        return
    end
    Dragging = nil
    const Old = Current.Hover
    if Old then
        Old.Color = Style.InkColor
        Old.Thickness = Old:GetAttribute("BaseThickness") :: number? or Kit.Stroke
    end
    const Ghost = Current.Ghost
    const Shade = Current.Shade
    if Shade then
        Shade:Destroy()
    end
    if not Ghost then
        return
    end
    Ghost:Cleanup()
    if not Spot then
        return
    end
    const Key = targetAt(Spot)
    if Key then
        Bridge:Call("Drop", Current.Id, Key)
    end
end

const function press(Id: string, Name: string, Tag: string, Source: GuiObject, Input: InputObject)
    if Dragging then
        return
    end
    Dragging = {
        Id = Id,
        Name = Name,
        Tag = Tag,
        Input = Input,
        Start = point(Input),
        Source = Source,
        Grab = Vector2.zero,
    }
end

const function wireDrag(Later: (() -> ()) -> ())
    const Links = {
        UserInputService.InputChanged:Connect(function(Input: InputObject)
            const Current = Dragging
            if Current and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input == Current.Input) then
                follow(Current, point(Input))
            end
        end),
        UserInputService.InputEnded:Connect(function(Input: InputObject)
            const Current = Dragging
            if Current and (Input == Current.Input or Input.UserInputType == Current.Input.UserInputType) then
                finish(point(Input))
            end
        end),
    }
    Later(function()
        finish(nil)
        for _, Link in Links do
            Link:Disconnect()
        end
    end)
end

const function partRow(View: Bridges.PartRow, Order: number): Kit.Declaration
    return Parts.card(`Row_{View.Id}`, {
        Size = UDim2.new(1, 0, 0, Rigging.RowHeight),
        LayoutOrder = Order,
    }, {
        BackgroundColor3 = Common["CardColor"],
        Active = true,
        vision.ready(function(Self: Instance, _, _)
            Self:SetAttribute(Rigging.DropAttribute, `part:{View.Id}`)
        end),
        InputBegan = function(Self: Instance, _, Input: InputObject)
            const Kind = Input.UserInputType
            const Row = Self.Parent
            if (Kind == Enum.UserInputType.MouseButton1 or Kind == Enum.UserInputType.Touch) and Row and Row:IsA("GuiObject") then
                press(View.Id, View.Name, View.Tag, Row, Input)
            end
        end,

        Kit.text("Grip", "::", 20, {
            Position = UDim2.fromOffset(6, 7),
            Size = UDim2.fromOffset(26, Rigging.RowHeight - 18),
            FontFace = Parts.Heading,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            BackgroundTransparency = 0,
            BackgroundColor3 = Common["PlateColor"],
            Parts.outline(1.2),
        }),

        Kit.text("Name", View.Name, 16, {
            Position = UDim2.fromOffset(42, 7),
            Size = UDim2.new(1, -222, 0, 20),
            FontFace = Parts.Heading,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }),

        Kit.text("Tag", View.Tag, 13, {
            Position = UDim2.fromOffset(42, 28),
            Size = UDim2.new(1, -222, 0, 16),
            TextColor3 = Common["PackColor"],
        }),

        Kit.press(`Row_{View.Id}_Edit`, "edit", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -114, 0.5, 0),
            Size = UDim2.fromOffset(56, 38),
        }, Style.AccentColor, Style.AccentText, Bridge, "Edit", View.Id, true, 15),

        Kit.press(`Row_{View.Id}_Copy`, "copy", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -52, 0.5, 0),
            Size = UDim2.fromOffset(56, 38),
        }, Style.ButtonColor, Style.InkColor, Bridge, "Duplicate", View.Id, false, 15),

        Kit.close(`Row_{View.Id}_Delete`, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
        }, Bridge, "Delete", View.Id, 36),
    }, nil, nil, Kit.ItemStroke)
end

const function groupBox(View: Bridges.GroupRow, Order: number): Kit.Declaration
    const function small(Name: string, Label: string, Width: number, Fill: Color3, Ink: Color3, Action: string, Outlined: boolean): Kit.Declaration
        return Kit.press(`Group_{View.Id}_{Name}`, Label, { Size = UDim2.fromOffset(Width, 34) }, Fill, Ink, Bridge, Action, View.Id, Outlined, 14)
    end
    const Made: Kit.Declaration = {
        ClassName = "Frame",
        Name = `Group_{View.Id}`,
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Kit.GroupColor,
        BorderSizePixel = 0,
        LayoutOrder = Order,
        Parts.outline(Kit.Stroke),
        vision.ready(function(Self: Instance, _, _)
            Self:SetAttribute(Rigging.DropAttribute, `group:{View.Id}`)
            Kit.boxText(Self, `Group_{View.Id}_Name`, View.Name)
        end),

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
        },

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
        },

        Kit.text("Code", if View.Code then `share code  {View.Code}` else "", 14, {
            FontFace = Parts.Heading,
            TextColor3 = Style.SuccessColor,
            Visible = View.Code ~= nil,
            LayoutOrder = 4,
        }),

        Kit.row(`Group_{View.Id}_Head`, 34, 1, {
            Kit.input(`Group_{View.Id}_Name`, "name this group", { Size = UDim2.new(1, -96, 0, 32) }, function(Text: string)
                Bridge:Call("GroupName", View.Id, Text)
            end),
            Kit.text("Count", `{#View.Members} {if #View.Members == 1 then "part" else "parts"}`, 14, {
                Size = UDim2.fromOffset(88, 32),
                TextXAlignment = Enum.TextXAlignment.Right,
                TextYAlignment = Enum.TextYAlignment.Center,
            }),
        }),

        Kit.row(`Group_{View.Id}_Tools`, 40, 2, {
            small("Move", "move", 76, Style.AccentColor, Style.AccentText, "GroupMove", true),
            small("Copy", "copy", 76, Style.ButtonColor, Style.InkColor, "GroupDuplicate", false),
            if View.Code
                then small("Share", "unshare", 90, Style.CloseColor, Style.CloseText, "Unshare", true)
                else small("Share", "share", 76, Style.SuccessColor, Style.SuccessText, "Share", true),
        }),

        Kit.row(`Group_{View.Id}_More`, 40, 3, {
            small("Ungroup", "ungroup", 96, Style.ButtonColor, Style.InkColor, "Ungroup", false),
            small("Delete", "delete all", 110, Style.CloseColor, Style.CloseText, "GroupDelete", true),
        }),
    }
    for Index, Member in View.Members do
        table.insert(Made, partRow(Member, Index + 4))
    end
    return Made
end

const function shapeCard(View: Bridges.ShapeCard, Order: number): Kit.Declaration
    return Parts.card(`Shape_{View.Id}`, { LayoutOrder = Order }, {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Style.CardColor,
        Activated = function()
            Bridge:Call("Builtin", View.Id)
        end,

        {
            ClassName = "ViewportFrame",
            Name = "Art",
            Position = UDim2.fromOffset(6, 6),
            Size = UDim2.new(1, -12, 1, -34),
            BackgroundColor3 = Style.IconColor,
            BorderSizePixel = 0,
            Ambient = Color3.fromRGB(170, 170, 170),
            LightColor = Color3.new(1, 1, 1),
            LightDirection = Vector3.new(-1, -1.5, -1),
            Parts.outline(1.2),
            vision.ready(function(Self: Instance, _, _)
                Kit.stage(Self :: ViewportFrame, View.Model, false)
            end),
        },

        Kit.text("Name", string.lower(View.Name), 13, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 4, 1, -5),
            Size = UDim2.new(1, -8, 0, 20),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            FontFace = Parts.Heading,
        }),
    }, 3, nil, Kit.ItemStroke)
end

const function shapes(): Kit.Declaration
    const Made = Kit.grid("Rig_Shapes", Vector2.new(92, 108), 5)
    Made.Destroying = function(Self: Instance)
        Kit.clear(Self)
    end
    table.insert(Made, vision.event("RigShapes", {}, function(Self: Instance, _, Cards: { Bridges.ShapeCard })
        const Items: { Kit.Item } = {}
        for Index, View in Cards do
            table.insert(Items, {
                Key = View.Id,
                Hash = View.Name,
                Build = function(): Kit.Declaration
                    return shapeCard(View, Index)
                end,
            })
        end
        Kit.sync(Self, Items)
        Kit.setButton(Self.Parent :: Instance, "Rig_AddPart", if #Cards > 0 then "close the part list" else "+ add part")
    end))
    table.insert(Made, vision.cleanup(function(Self: Instance, _)
        Kit.clear(Self)
    end))
    return Made
end

const function list(): Kit.Declaration
    return Kit.scroller("Rig_List", {
        Size = UDim2.fromScale(1, 1),
        Destroying = function(Self: Instance)
            Kit.clear(Self)
        end,

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            Self:SetAttribute(Rigging.DropAttribute, "list")
            wireDrag(Later)
        end),

        vision.event("RigRows", { Groups = {}, Loose = {} }, function(Self: Instance, _, View: Bridges.RigView)
            const Items: { Kit.Item } = {}
            for Index, Group in View.Groups do
                const Members: { string } = {}
                for _, Member in Group.Members do
                    table.insert(Members, `{Member.Id}:{Member.Name}:{Member.Tag}`)
                end
                table.insert(Items, {
                    Key = `group:{Group.Id}`,
                    Hash = `{Group.Name}|{Group.Code or ""}|{table.concat(Members, ",")}`,
                    Build = function(): Kit.Declaration
                        return groupBox(Group, Index)
                    end,
                })
            end
            for Index, Row in View.Loose do
                table.insert(Items, {
                    Key = `part:{Row.Id}`,
                    Hash = `{Row.Name}|{Row.Tag}`,
                    Build = function(): Kit.Declaration
                        return partRow(Row, Index)
                    end,
                })
            end
            if #View.Groups == 0 and #View.Loose == 0 then
                table.insert(Items, {
                    Key = "empty",
                    Hash = "",
                    Build = function(): Kit.Declaration
                        return Kit.text("Empty", "no rig parts yet. paste an accessory id above or add a built in part", 15, {
                            Size = UDim2.new(1, 0, 0, 60),
                            TextWrapped = true,
                            TextXAlignment = Enum.TextXAlignment.Center,
                            TextColor3 = Common["OutlineColor"],
                        })
                    end,
                })
            end
            Kit.sync(Self, Items)
        end),

        vision.cleanup(function(Self: Instance, _)
            Kit.clear(Self)
        end),
    })
end

const Top = Kit.Margin + Kit.HeaderHeight + 10

function Rigging.build(): Kit.Declaration
    return Kit.panel("Rig", "rig parts", {
        Size = UDim2.fromScale(1, 1),
        Visible = false,

        vision.event("RigShared", "", function(Self: Instance, _, Code: string)
            Kit.show(Self, "Rig_Shared", Code ~= "")
            const Box = Kit.boxOf(Self, "Rig_SharedCode")
            if Box then
                Box.Text = Code
            end
        end),

        vision.event("RigInfo", { Count = "" }, function(Self: Instance, _, Info: { Count: string })
            Kit.label(Self, "Rig_Count", Info.Count)
        end),
    }, {
        Kit.text("Rig_Count", "", 15, {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -(Kit.Margin + 14), 0, Kit.Margin + 17),
            Size = UDim2.fromOffset(150, 20),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Common["InkColor"],
        }),

        {
            ClassName = "Frame",
            Name = "Rig_Content",
            Position = UDim2.fromOffset(Kit.Margin, Top),
            Size = UDim2.new(1, -Kit.Margin * 2, 1, -(Top + Kit.Margin)),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,

            {
                ClassName = "UIListLayout",
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 10),
            },

            Kit.section("Rig_Add", "add parts", 1, {
                Kit.row("Rig_Insert", 40, 1, {
                    Kit.input("Rig_InsertId", "paste an accessory id", { Size = UDim2.new(1, -96, 0, 36) }, function(Text: string)
                        Bridge:Call("Insert", Text)
                    end, function(Text: string)
                        Bridge:Call("InsertTyped", Text)
                    end),
                    Kit.press("Rig_InsertAdd", "add", { Size = UDim2.fromOffset(88, 38) }, Style.AccentColor, Style.AccentText, Bridge, "Insert", nil, true, 17),
                }),
                Kit.row("Rig_Import", 40, 2, {
                    Kit.input("Rig_ImportCode", "paste a share code", { Size = UDim2.new(1, -96, 0, 36) }, function(Text: string)
                        Bridge:Call("Import", Text)
                    end, function(Text: string)
                        Bridge:Call("ImportTyped", Text)
                    end),
                    Kit.press("Rig_ImportGet", "get", { Size = UDim2.fromOffset(88, 38) }, Style.SuccessColor, Style.SuccessText, Bridge, "Import", nil, true, 17),
                }),
                Parts.merge(Kit.row("Rig_Shared", 38, 3, {
                    Kit.text("Rig_SharedLabel", "your code", 15, {
                        Size = UDim2.fromOffset(84, 36),
                        TextYAlignment = Enum.TextYAlignment.Center,
                        FontFace = Parts.Heading,
                    }),
                    Kit.input("Rig_SharedCode", "", { Size = UDim2.new(1, -140, 0, 34) }, function() end),
                    Kit.press("Rig_SharedHide", "ok", { Size = UDim2.fromOffset(40, 36) }, Style.PlateColor, Style.InkColor, Bridge, "SharedHide", nil, false, 15),
                }), { Visible = false }),
                Kit.press("Rig_AddPart", "+ add part", { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4 }, Style.WidgetColor, Style.InkColor, Bridge, "AddMenu", nil, false, 17),
                shapes(),
            }),

            Kit.text("Rig_Hint", Rigging.Hint, 13, {
                Size = UDim2.new(1, 0, 0, 32),
                TextWrapped = true,
                TextColor3 = Common["OutlineColor"],
                LayoutOrder = 2,
            }),

            {
                ClassName = "Frame",
                Name = "Rig_Holder",
                Size = UDim2.fromScale(1, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = 3,

                {
                    ClassName = "UIFlexItem",
                    FlexMode = Enum.UIFlexMode.Fill,
                },

                list(),
            },
        },
    })
end

return Rigging
