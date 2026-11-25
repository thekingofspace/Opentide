--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Bridges = require(ReplicatedStorage.Shared.Customize.Bridges)
const Kit = require(script.Parent.Kit)

const Style = Kit.Style
const Common = Kit.Common
const Bridge = Bridges.Clothes

const Clothes = {
    Width = 384,
    Height = 780,
    Card = Vector2.new(104, 130),
}

const Top = Kit.Margin + Kit.HeaderHeight + 10

const function thumb(Asset: number): string
    return `rbxthumb://type=Asset&id={Asset}&w=150&h=150`
end

const function card(Kind: string, View: Bridges.ClothingCard, Order: number): Kit.Declaration
    const Fill = if View.Active then Style.AccentColor else Style.CardColor
    const Inner: Kit.Declaration = {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Fill,
        Activated = function()
            Bridge:Call("Pick", Kind, View.Id)
        end,

        Kit.text("Name", View.Name, 13, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 4, 1, -4),
            Size = UDim2.new(1, -8, 0, 30),
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextColor3 = if View.Active then Style.AccentText else Style.InkColor,
        }),
    }
    const Asset = View.Asset
    if Asset then
        table.insert(Inner, {
            ClassName = "ImageLabel",
            Name = "Thumb",
            Position = UDim2.fromOffset(6, 6),
            Size = UDim2.new(1, -12, 1, -42),
            BackgroundColor3 = Style.PlateColor,
            BorderSizePixel = 0,
            Image = thumb(Asset),
            ScaleType = Enum.ScaleType.Fit,
            Parts.outline(1.2),
        })
    else
        table.insert(Inner, Kit.text("Own", "your own", 15, {
            Position = UDim2.fromOffset(6, 6),
            Size = UDim2.new(1, -12, 1, -42),
            FontFace = Parts.Heading,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            BackgroundTransparency = 0,
            BackgroundColor3 = Style.PlateColor,
            TextColor3 = Style.InkColor,
            Parts.outline(1.2),
        }))
    end
    return Parts.card(`Card_{View.Id}`, { LayoutOrder = Order }, Inner, 3, nil, Kit.ItemStroke)
end

const function grid(Kind: string): Kit.Declaration
    return {
        ClassName = "ScrollingFrame",
        Name = `Clothes_{Kind}_Grid`,
        Position = UDim2.fromOffset(Kit.Margin, Top + 86),
        Size = UDim2.new(1, -Kit.Margin * 2, 1, -(Top + 86 + Kit.Margin)),
        BackgroundColor3 = Common["WellColor"],
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 8,
        ScrollBarImageColor3 = Common["OutlineColor"],
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        Parts.outline(Kit.Stroke),
        Destroying = function(Self: Instance)
            Kit.clear(Self)
        end,

        {
            ClassName = "UIGridLayout",
            CellSize = UDim2.fromOffset(Clothes.Card.X, Clothes.Card.Y),
            CellPadding = UDim2.fromOffset(8, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        },

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
        },

        vision.event(`Clothes{Kind}Cards`, {}, function(Self: Instance, _, Cards: { Bridges.ClothingCard })
            const Items: { Kit.Item } = {}
            for Index, View in Cards do
                table.insert(Items, {
                    Key = View.Id,
                    Hash = `{View.Name}|{View.Asset or 0}|{View.Active}`,
                    Build = function(): Kit.Declaration
                        return card(Kind, View, Index)
                    end,
                })
            end
            Kit.sync(Self, Items)
        end),

        vision.cleanup(function(Self: Instance, _)
            Kit.clear(Self)
        end),
    }
end

const function panel(Kind: string, Title: string, Outer: Kit.Declaration): Kit.Declaration
    const Lower = string.lower(Kind)
    return Kit.panel(`Clothes_{Kind}`, Title, Outer, {
        Kit.search(`Clothes_{Kind}_Search`, `search {Lower}`, {
            Position = UDim2.fromOffset(Kit.Margin, Top),
            Size = UDim2.new(1, -Kit.Margin * 2, 0, 34),
        }, function(Text: string)
            Bridge:Call("Search", Kind, Text)
        end),

        {
            ClassName = "Frame",
            Name = `Clothes_{Kind}_IdRow`,
            Position = UDim2.fromOffset(Kit.Margin, Top + 42),
            Size = UDim2.new(1, -Kit.Margin * 2, 0, 38),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,

            Kit.input(`Clothes_{Kind}_Id`, `or paste a classic {Lower} id`, {
                Size = UDim2.new(1, -96, 0, 36),
            }, function(Text: string)
                Bridge:Call("Wear", Kind, Text)
            end, function(Text: string)
                Bridge:Call("Typed", Kind, Text)
            end),

            Kit.press(`Clothes_{Kind}_Wear`, "wear", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.fromScale(1, 0),
                Size = UDim2.fromOffset(88, 38),
            }, Style.AccentColor, Style.AccentText, Bridge, `Wear{Kind}`, nil, true, 16),
        },

        grid(Kind),
    })
end

const function fill(Root: Instance, View: Bridges.ClothesView)
    (Root :: GuiObject).Visible = View.Shown
    for _, Kind in { "Shirt", "Pants" } do
        Kit.show(Root, `Clothes_{Kind}_IdRow`, View.Ids)
        Kit.boxText(Root, `Clothes_{Kind}_Id`, if Kind == "Shirt" then View.Shirt else View.Pants)
        const Grid = Root:FindFirstChild(`Clothes_{Kind}_Grid`, true)
        if Grid and Grid:IsA("GuiObject") then
            const Offset = Top + (if View.Ids then 86 else 44)
            Grid.Position = UDim2.fromOffset(Kit.Margin, Offset)
            Grid.Size = UDim2.new(1, -Kit.Margin * 2, 1, -(Offset + Kit.Margin))
        end
    end
end

function Clothes.build(): Kit.Declaration
    return {
        ClassName = "Frame",
        Name = "Clothes_Dock",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(Clothes.Width, Clothes.Height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,

        {
            ClassName = "UIScale",
        },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            VisionKit.fit(Self :: GuiObject, Later, 0.5)
        end),

        vision.event("ClothesState", { Shown = false, Ids = true, Shirt = "", Pants = "" }, function(Self: Instance, _, View: Bridges.ClothesView)
            fill(Self, View)
        end),

        panel("Shirt", "shirts", {
            Size = UDim2.new(1, 0, 0.5, -6),
        }),

        panel("Pants", "pants", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0.5, -6),
        }),
    }
end

return Clothes
