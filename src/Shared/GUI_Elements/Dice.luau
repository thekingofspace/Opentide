--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Kit = require(ReplicatedStorage.Shared.GUI_Elements.Customize.Kit)
const Bridges = require(ReplicatedStorage.Shared.Dice.Bridges)

const Style = Kit.Style
const Bridge = Bridges.Dice

const Width = 420
const Height = 760
const StageHeight = 280

const function dieButton(View: Bridges.DieCard, Order: number): Kit.Declaration
    const Fill = if View.Active then Kit.Picked else Style.ButtonColor
    return Parts.card(`Die_{View.Id}`, {
        LayoutOrder = Order,
    }, {
        ClassName = "TextButton",
        Text = View.Name,
        FontFace = Parts.Heading,
        TextScaled = false,
        TextSize = 22,
        TextColor3 = Style.InkColor,
        BackgroundColor3 = Fill,
        AutoButtonColor = true,
        Activated = function()
            Bridge:Call("Roll", View.Id)
        end,
        Parts.bevel(`Die_{View.Id}_Shine`, 3, Kit.light(Fill), Kit.dark(Fill)),
    }, Kit.Depth, nil, Kit.Stroke)
end

return Kit.Scope:Capture(Kit.panel("Dice", "roll dice", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(Width, Height),
    Visible = false,

    { ClassName = "UIScale" },

    vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
        VisionKit.fit(Self :: GuiObject, Later, 0.55)
        const Header = Self:FindFirstChild("Dice_Header")
        if Header and Header:IsA("GuiObject") then
            Header.Active = true
            Parts.draggable(Self :: GuiObject, Header, Later)
        end
    end),

    vision.event("DiceShown", false, function(Self: Instance, _, Value: boolean)
        (Self :: GuiObject).Visible = Value == true
    end),

    vision.event("DiceResult", { Text = "pick a die to roll", Big = false }, function(Self: Instance, _, View: { Text: string, Big: boolean })
        const Label = Self:FindFirstChild("Dice_Result", true)
        if Label and Label:IsA("TextLabel") then
            Label.Text = View.Text
            const Limit = Label:FindFirstChildOfClass("UITextSizeConstraint")
            if Limit then
                Limit.MaxTextSize = if View.Big then 38 else 20
            end
        end
    end),
}, {
    Kit.close("Dice_Close", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -(Kit.Margin + 10), 0, Kit.Margin + Kit.HeaderHeight / 2),
        ZIndex = 5,
    }, Bridge, "Close", nil, 36),

    Parts.merge(Kit.body("Dice_List"), {
        Kit.section("Dice_StageSection", "the table", 1, {
            {
                ClassName = "Frame",
                Name = "Dice_Well",
                Size = UDim2.new(1, 0, 0, StageHeight),
                BackgroundColor3 = Style.WellColor,
                BorderSizePixel = 0,
                LayoutOrder = 1,
                Parts.outline(Kit.ItemStroke),

                {
                    ClassName = "ViewportFrame",
                    Name = "Dice_View",
                    Size = UDim2.fromScale(1, 1),
                    BackgroundTransparency = 1,
                    Ambient = Color3.fromRGB(150, 150, 150),
                    LightColor = Color3.new(1, 1, 1),
                    LightDirection = Vector3.new(-1, -1.4, -0.8),
                },

                Kit.text("Dice_Result", "pick a die to roll", 20, {
                    AnchorPoint = Vector2.new(0.5, 1),
                    Position = UDim2.new(0.5, 0, 1, -8),
                    Size = UDim2.new(1, -20, 0, 46),
                    FontFace = Parts.Heading,
                    TextColor3 = Style.CardColor,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextYAlignment = Enum.TextYAlignment.Center,
                    TextScaled = true,
                    ZIndex = 3,
                    Parts.textOutline(Style.InkColor, 2),
                    { ClassName = "UITextSizeConstraint", MaxTextSize = 20, MinTextSize = 10 },
                }),
            },
            Kit.press("Dice_Again", "roll again", { Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 2 }, Style.SuccessColor, Style.SuccessText, Bridge, "Again", nil, true, 20),
        }),

        Kit.section("Dice_AddSection", "add to the roll", 2, {
            Kit.chips("Dice_Stats", "DiceStats", Vector2.new(170, 40), Bridge, "Stat", 1),
            Kit.input("Dice_Mod", "modifier, like -1 missing arm", {
                Size = UDim2.new(1, 0, 0, 44),
                LayoutOrder = 2,
            }, function(Text: string, _)
                Bridge:Call("Modifier", Text)
            end, function(Text: string)
                Bridge:Call("Modifier", Text)
            end),
            Kit.text("Dice_ModHint", "type a number to add or take away, words after it are just a note", 13, {
                TextWrapped = true,
                AutomaticSize = Enum.AutomaticSize.Y,
                TextColor3 = Style.OutlineColor,
                LayoutOrder = 3,
            }),
        }),

        Kit.section("Dice_PickSection", "dice", 3, {
            Parts.merge(Kit.grid("Dice_Grid", Vector2.new(108, 54), 1), {
                Destroying = function(Self: Instance)
                    Kit.clear(Self)
                end,

                vision.event("DiceKinds", {}, function(Self: Instance, _, Cards: { Bridges.DieCard })
                    const Items: { Kit.Item } = {}
                    for Index, View in Cards do
                        table.insert(Items, {
                            Key = View.Id,
                            Hash = `{View.Name}|{View.Active}`,
                            Build = function(): Kit.Declaration
                                return dieButton(View, Index)
                            end,
                        })
                    end
                    Kit.sync(Self, Items)
                end),

                vision.cleanup(function(Self: Instance, _)
                    Kit.clear(Self)
                end),
            }),
        }),
    }),
}) :: Frame & any)
