--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Bridges = require(ReplicatedStorage.Shared.Customize.Bridges)
const Kit = require(script.Parent.Kit)

const Style = Kit.Style
const Common = Kit.Common
const Bridge = Bridges.Info

const Info = {
    Tabs = {
        { Id = "Profile", Label = "profile" },
        { Id = "Stats", Label = "stats" },
    },
}

const function hint(Name: string, Text: string, Order: number): Kit.Declaration
    return Kit.text(Name, Text, 13, {
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        TextColor3 = Common["OutlineColor"],
        LayoutOrder = Order,
    })
end

const function statRow(View: Bridges.StatRow, Order: number): Kit.Declaration
    return Parts.card(`Stat_{View.Id}`, {
        Size = UDim2.new(1, 0, 0, 74),
        LayoutOrder = Order,
    }, {
        BackgroundColor3 = Style.CardColor,

        Kit.text("Name", View.Name, 18, {
            Position = UDim2.fromOffset(12, 8),
            Size = UDim2.new(1, -150, 0, 22),
            FontFace = Parts.Heading,
        }),

        Kit.text("Detail", View.Detail, 13, {
            Position = UDim2.fromOffset(12, 32),
            Size = UDim2.new(1, -150, 0, 16),
            TextColor3 = Style.PackColor,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }),

        Kit.text("Bonus", View.Bonus, 13, {
            Position = UDim2.fromOffset(12, 50),
            Size = UDim2.new(1, -150, 0, 16),
            FontFace = Parts.Heading,
            TextColor3 = Style.AccentColor,
        }),

        Kit.press(`Stat_{View.Id}_Less`, "-", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -96, 0.5, 0),
            Size = UDim2.fromOffset(36, 36),
        }, Style.ButtonColor, Style.InkColor, Bridge, "Stat", { Id = View.Id, Step = -1 }, false, 20),

        Kit.text("Value", View.Value, 20, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -50, 0.5, 0),
            Size = UDim2.fromOffset(44, 30),
            FontFace = Parts.Heading,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
        }),

        Kit.press(`Stat_{View.Id}_More`, "+", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(36, 36),
        }, Style.ButtonColor, Style.InkColor, Bridge, "Stat", { Id = View.Id, Step = 1 }, false, 20),
    }, nil, nil, Kit.ItemStroke)
end

function Info.build(): Kit.Declaration
    const Tabs: { Kit.Declaration } = {}
    for Order, Tab in Info.Tabs do
        table.insert(Tabs, Kit.press(`Info_Tab_{Tab.Id}`, Tab.Label, { Size = UDim2.new(0.5, -4, 0, 44), LayoutOrder = Order }, Style.ButtonColor, Style.InkColor, Bridge, "Tab", Tab.Id, false, 18))
    end
    return Kit.panel("Info", "info", {
        Size = UDim2.fromScale(1, 1),
        Visible = false,

        vision.event("InfoView", { Tab = "Profile", Nickname = "", Description = "", Stats = {} }, function(Self: Instance, _, View: Bridges.InfoView)
            for _, Tab in Info.Tabs do
                const On = Tab.Id == View.Tab
                Kit.setButton(Self, `Info_Tab_{Tab.Id}`, nil, if On then Style.AccentColor else Style.ButtonColor, if On then Style.AccentText else Style.InkColor)
            end
            Kit.show(Self, "Info_NicknameSection", View.Tab == "Profile")
            Kit.show(Self, "Info_DescriptionSection", View.Tab == "Profile")
            Kit.show(Self, "Info_Save", View.Tab == "Profile")
            Kit.show(Self, "Info_StatsSection", View.Tab == "Stats")
            Kit.boxText(Self, "Info_Nickname", View.Nickname)
            Kit.boxText(Self, "Info_Description", View.Description)
            const List = Self:FindFirstChild("Info_StatRows", true)
            if List then
                const Items: { Kit.Item } = {}
                for Index, Row in View.Stats do
                    table.insert(Items, {
                        Key = Row.Id,
                        Hash = `{Row.Value}|{Row.Bonus}`,
                        Build = function(): Kit.Declaration
                            return statRow(Row, Index)
                        end,
                    })
                end
                Kit.sync(List, Items)
            end
        end),
    }, {
        Parts.merge(Kit.body("Info_List"), {
            Kit.row("Info_Tabs", 46, 0, Tabs),

            Kit.section("Info_NicknameSection", "nickname", 1, {
                Kit.input("Info_Nickname", "your nickname", {
                    Size = UDim2.new(1, 0, 0, 44),
                    LayoutOrder = 1,
                }, function(Text: string, _)
                    Bridge:Call("NicknameText", Text)
                end, function(Text: string)
                    Bridge:Call("NicknameText", Text)
                end),
                hint("Info_NicknameHint", "it shows over your head instead of your name. leave it empty to use your normal name", 2),
            }),

            Kit.section("Info_DescriptionSection", "description", 2, {
                Parts.card("Info_Description", {
                    Size = UDim2.new(1, 0, 0, 140),
                    LayoutOrder = 1,
                }, {
                    ClassName = "TextBox",
                    Text = "",
                    PlaceholderText = "write a little about yourself",
                    PlaceholderColor3 = Common["MutedColor"],
                    TextColor3 = Common["InkColor"],
                    FontFace = Parts.Typewriter,
                    TextScaled = false,
                    TextSize = 16,
                    TextWrapped = true,
                    MultiLine = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    ClearTextOnFocus = false,
                    BackgroundColor3 = Common["CardColor"],
                    PropertyChanged = {
                        Text = function(_, _, Value: string)
                            Bridge:Call("DescriptionText", Value)
                        end,
                    },

                    {
                        ClassName = "UIPadding",
                        PaddingLeft = UDim.new(0, 8),
                        PaddingRight = UDim.new(0, 8),
                        PaddingTop = UDim.new(0, 8),
                    },
                }, nil, nil, Kit.ItemStroke),
                hint("Info_DescriptionHint", "people see this on your profile", 2),
            }),

            Kit.press("Info_Save", "save profile", { Size = UDim2.new(1, 0, 0, 54), LayoutOrder = 3 }, Style.SuccessColor, Style.SuccessText, Bridge, "Save", nil, true, 20),

            Parts.merge(Kit.section("Info_StatsSection", "stats", 4, {
                hint("Info_StatsHint", "stats show on your profile and can be added to dice rolls", 1),
                {
                    ClassName = "Frame",
                    Name = "Info_StatRows",
                    Size = UDim2.fromScale(1, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    LayoutOrder = 2,
                    Destroying = function(Self: Instance)
                        Kit.clear(Self)
                    end,

                    {
                        ClassName = "UIListLayout",
                        FillDirection = Enum.FillDirection.Vertical,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0, 8),
                    },

                    vision.cleanup(function(Self: Instance, _)
                        Kit.clear(Self)
                    end),
                },
            }), { Visible = false }),
        }),
    })
end

return Info
