--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Bridges = require(ReplicatedStorage.Shared.Customize.Bridges)
const Kit = require(script.Parent.Kit)

const Style = Kit.Style
const Common = Kit.Common
const Bridge = Bridges.Shop

const Shop = {
    Width = 1020,
    Height = 660,
    DetailWidth = 350,
    Card = Vector2.new(188, 236),
}

const Top = Kit.Margin + Kit.HeaderHeight + 12

const function preview(Name: string, Model: Instance?, Image: string?, Fallback: string, Size: number, Spin: boolean): Kit.Declaration
    if Model then
        return {
            ClassName = "ViewportFrame",
            Name = Name,
            BackgroundColor3 = Style.IconColor,
            BorderSizePixel = 0,
            Ambient = Color3.fromRGB(170, 170, 170),
            LightColor = Color3.new(1, 1, 1),
            LightDirection = Vector3.new(-1, -1.5, -1),
            Parts.outline(1.6),
            vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
                const Stop = Kit.stage(Self :: ViewportFrame, Model, Spin)
                if Stop then
                    Later(Stop)
                end
            end),
        }
    end
    if Image and Image ~= "" then
        return {
            ClassName = "ImageLabel",
            Name = Name,
            BackgroundColor3 = Style.IconColor,
            BorderSizePixel = 0,
            Image = Image,
            ScaleType = Enum.ScaleType.Fit,
            Parts.outline(1.6),
        }
    end
    return Kit.text(Name, Fallback, Size, {
        BackgroundTransparency = 0,
        BackgroundColor3 = Style.IconColor,
        FontFace = Parts.Heading,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parts.outline(1.6),
        Parts.textOutline(Color3.new(1, 1, 1), 1.5),
    })
end

const function tag(Name: string, Value: string, Fill: Color3, Ink: Color3, Order: number?): Kit.Declaration
    return Kit.text(Name, Value, 14, {
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 0,
        BackgroundColor3 = Fill,
        TextColor3 = Ink,
        FontFace = Parts.Heading,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        LayoutOrder = Order,
        Parts.outline(1.2),
        { ClassName = "UIPadding", PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) },
    })
end

const function card(View: Bridges.ShopCard, Order: number): Kit.Declaration
    const Fill = if View.Active then Kit.Picked else Style.CardColor
    const Art = preview("Art", View.Model, View.Image, View.Reward, 28, false)
    Art.Position = UDim2.fromOffset(8, 8)
    Art.Size = UDim2.new(1, -16, 0, 150)
    return Parts.card(`Card_{View.Id}`, { LayoutOrder = Order }, {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Fill,
        Activated = function()
            Bridge:Call("Pick", View.Id)
        end,
        Parts.bevel(`Card_{View.Id}_Shine`, 3, Kit.light(Fill), Kit.dark(Fill)),

        Art,

        Kit.text("Name", View.Name, 16, {
            Position = UDim2.fromOffset(10, 164),
            Size = UDim2.new(1, -20, 0, 22),
            FontFace = Parts.Heading,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }),

        tag("Price", View.Price, Style.SuccessColor, Style.SuccessText, nil),
    }, Kit.Depth, nil, Kit.ItemStroke)
end

const function fixCardTag(Made: Kit.Declaration)
    const Body = Made[#Made]
    if type(Body) ~= "table" then
        return
    end
    for _, Child in Body do
        if type(Child) == "table" and Child.Name == "Price" then
            Child.Position = UDim2.fromOffset(10, 192)
        end
    end
end

const function detail(View: Bridges.ShopDetail): Kit.Declaration
    const Art = preview("Detail_Art", View.Model, View.Image, View.Reward, 34, true)
    Art.Size = UDim2.new(1, 0, 0, 210)
    Art.LayoutOrder = 1
    const Includes: Kit.Declaration = {
        ClassName = "Frame",
        Name = "Detail_Includes",
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 6,
        Visible = #View.Includes > 0,

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Horizontal,
            Wraps = true,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
        },
    }
    for Index, Name in View.Includes do
        table.insert(Includes, tag(`Include_{Index}`, Name, Style.PlateColor, Style.InkColor, Index))
    end
    const Made: Kit.Declaration = {
        ClassName = "Frame",
        Name = "Detail",
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 9),
        },

        Art,

        Kit.text("Detail_Name", View.Name, 24, {
            FontFace = Parts.Heading,
            TextWrapped = true,
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 2,
        }),

        Kit.row("Detail_Tags", 26, 3, {
            tag("Detail_Kind", View.Reward, Style.AccentColor, Style.AccentText, 1),
            tag("Detail_Price", View.Price, Style.SuccessColor, Style.SuccessText, 2),
        }),

        Kit.text("Detail_Text", View.Detail, 15, {
            TextWrapped = true,
            AutomaticSize = Enum.AutomaticSize.Y,
            TextColor3 = Style.InkColor,
            LayoutOrder = 4,
        }),

        Kit.text("Detail_IncludesTitle", "includes", 15, {
            FontFace = Parts.Heading,
            LayoutOrder = 5,
            Visible = #View.Includes > 0,
        }),

        Includes,

        Kit.press("Detail_Buy", if View.Ready then `buy for {View.Price}` else "not for sale yet", {
            Size = UDim2.new(1, 0, 0, 50),
            LayoutOrder = 7,
        }, if View.Ready then Style.SuccessColor else Style.PlateColor, if View.Ready then Style.SuccessText else Style.MutedColor, Bridge, "Buy", View.Id, View.Ready, 19),
    }
    if View.Ready and View.Giftable then
        table.insert(Made, Kit.press("Detail_Gift", if View.Gifting then "close gift" else "send as a gift", {
            Size = UDim2.new(1, 0, 0, 44),
            LayoutOrder = 8,
        }, Style.WidgetColor, Style.InkColor, Bridge, if View.Gifting then "GiftClose" else "GiftOpen", View.Id, false, 17))
    end
    if View.Ready and View.Gifting then
        table.insert(Made, Kit.row("Detail_GiftRow", 42, 9, {
            Kit.input("Detail_To", "their username", { Size = UDim2.new(1, -100, 0, 38) }, function(Text: string)
                Bridge:Call("GiftSend", View.Id, Text)
            end, function(Text: string)
                Bridge:Call("GiftTyped", Text)
            end),
            Kit.press("Detail_Send", "send", { Size = UDim2.fromOffset(92, 40) }, Style.AccentColor, Style.AccentText, Bridge, "GiftSend", View.Id, true, 17),
        }))
    end
    return Made
end

const function detailHash(View: Bridges.ShopDetail): string
    return table.concat({
        View.Id, View.Name, View.Detail, View.Reward, View.Price,
        if View.Model then "m" else "", View.Image or "",
        tostring(View.Giftable), tostring(View.Gifting), tostring(View.Ready),
        table.concat(View.Includes, ","),
    }, "|")
end

function Shop.build(): Kit.Declaration
    return Kit.panel("Shop", "shop", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(Shop.Width, Shop.Height),
        Visible = false,
        ZIndex = 10,

        {
            ClassName = "UIScale",
        },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            VisionKit.fit(Self :: GuiObject, Later, 0.5)
        end),

        vision.event("ShopShown", false, function(Self: Instance, _, Value: boolean)
            (Self :: GuiObject).Visible = Value == true
        end),
    }, {
        Kit.close("Shop_Close", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -(Kit.Margin + 12), 0, Kit.Margin + Kit.HeaderHeight / 2),
            ZIndex = 5,
        }, Bridge, "Close", nil, 38),

        Kit.text("Shop_Hint", "tap an item to see what is inside", 14, {
            Position = UDim2.fromOffset(Kit.Margin + 4, Top - 4),
            Size = UDim2.new(1, -(Shop.DetailWidth + Kit.Margin * 2 + 16), 0, 18),
            TextColor3 = Common["OutlineColor"],
        }),

        {
            ClassName = "ScrollingFrame",
            Name = "Shop_Grid",
            Position = UDim2.fromOffset(Kit.Margin, Top + 20),
            Size = UDim2.new(1, -(Shop.DetailWidth + Kit.Margin * 2 + 12), 1, -(Top + 20 + Kit.Margin)),
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
                CellSize = UDim2.fromOffset(Shop.Card.X, Shop.Card.Y),
                CellPadding = UDim2.fromOffset(12, 12),
                SortOrder = Enum.SortOrder.LayoutOrder,
            },

            {
                ClassName = "UIPadding",
                PaddingTop = UDim.new(0, 12),
                PaddingBottom = UDim.new(0, 12),
                PaddingLeft = UDim.new(0, 12),
                PaddingRight = UDim.new(0, 12),
            },

            vision.event("ShopCards", {}, function(Self: Instance, _, Cards: { Bridges.ShopCard })
                const Items: { Kit.Item } = {}
                for Index, View in Cards do
                    table.insert(Items, {
                        Key = View.Id,
                        Hash = `{View.Name}|{View.Price}|{View.Active}|{if View.Model then "m" else ""}|{View.Image or ""}|{View.Reward}`,
                        Build = function(): Kit.Declaration
                            const Made = card(View, Index)
                            fixCardTag(Made)
                            return Made
                        end,
                    })
                end
                Kit.sync(Self, Items)
            end),

            vision.cleanup(function(Self: Instance, _)
                Kit.clear(Self)
            end),
        },

        Kit.scroller("Shop_Detail", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -Kit.Margin, 0, Top),
            Size = UDim2.new(0, Shop.DetailWidth, 1, -(Top + Kit.Margin)),
            BackgroundColor3 = Kit.SheetColor,
            Destroying = function(Self: Instance)
                Kit.clear(Self)
            end,

            vision.event("ShopDetail", false, function(Self: Instance, _, View: Bridges.ShopDetail | false)
                if not View then
                    Kit.sync(Self, {
                        {
                            Key = "empty",
                            Hash = "",
                            Build = function(): Kit.Declaration
                                return Kit.text("Detail_Empty", "pick an item on the left to see what is inside", 16, {
                                    Size = UDim2.new(1, 0, 0, 80),
                                    TextWrapped = true,
                                    TextXAlignment = Enum.TextXAlignment.Center,
                                    TextYAlignment = Enum.TextYAlignment.Center,
                                    TextColor3 = Style.OutlineColor,
                                })
                            end,
                        },
                    })
                    return
                end
                Kit.sync(Self, {
                    {
                        Key = `detail:{View.Id}`,
                        Hash = detailHash(View),
                        Build = function(): Kit.Declaration
                            return detail(View)
                        end,
                    },
                })
            end),

            vision.cleanup(function(Self: Instance, _)
                Kit.clear(Self)
            end),
        }, 12),
    })
end

return Shop
