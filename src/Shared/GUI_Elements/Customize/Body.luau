--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Bridges = require(ReplicatedStorage.Shared.Customize.Bridges)
const Kit = require(script.Parent.Kit)

const Style = Kit.Style
const Common = Kit.Common
const Bridge = Bridges.Body

const Body = {
    Limbs = {
        { Id = "Head", Label = "head" },
        { Id = "Torso", Label = "torso" },
        { Id = "RightArm", Label = "right arm" },
        { Id = "LeftArm", Label = "left arm" },
        { Id = "RightLeg", Label = "right leg" },
        { Id = "LeftLeg", Label = "left leg" },
    },
    Sizes = {
        { Key = "Height", Label = "height" },
        { Key = "Width", Label = "width" },
        { Key = "Depth", Label = "depth" },
        { Key = "Head", Label = "head size" },
    },
}

const function limbColumn(): Kit.Declaration
    const Made: Kit.Declaration = {
        ClassName = "Frame",
        Name = "Body_Limbs",
        Size = UDim2.new(1, -(Kit.FigureSize.X + 12), 0, Kit.FigureSize.Y),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 2,

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 5),
        },
    }
    for Order, Limb in Body.Limbs do
        table.insert(Made, Kit.press(`Body_Limb_{Limb.Id}`, Limb.Label, {
            Size = UDim2.new(1, 0, 0, 34),
            LayoutOrder = Order,
        }, Style.ButtonColor, Style.InkColor, Bridge, "Limb", Limb.Id, false, 16))
    end
    return Made
end

const function sizes(): { Kit.Declaration }
    const Made: { Kit.Declaration } = {}
    for Order, Size in Body.Sizes do
        table.insert(Made, Kit.stepper(`Body_Size_{Size.Key}`, Size.Label, Bridge, "Size", Size.Key, Order))
    end
    return Made
end

const function fill(Root: Instance, View: Bridges.BodyView)
    Kit.setChip(Root, "Body_Skin", View.Skin)
    for _, Size in Body.Sizes do
        Kit.label(Root, `Body_Size_{Size.Key}_Value`, View.Sizes[Size.Key] or "1.00x")
    end
    Kit.setButton(Root, "Body_ScaleParts", if View.ScaleParts then "scale parts with body: on" else "scale parts with body: off", if View.ScaleParts then Style.SuccessColor else Style.ButtonColor, if View.ScaleParts then Style.SuccessText else Style.InkColor)
    Kit.label(Root, "Body_Picked", View.PickLabel)
    Kit.show(Root, "Body_PickTools", View.Pick ~= nil)
    Kit.setButton(Root, "Body_Hide", if View.PickHidden then "show it" else "hide it")
    for _, Limb in Body.Limbs do
        const On = View.Pick == `limb:{Limb.Id}`
        Kit.setButton(Root, `Body_Limb_{Limb.Id}`, nil, if On then Style.AccentColor else Style.ButtonColor, if On then Style.AccentText else Style.InkColor)
    end
end

function Body.build(): Kit.Declaration
    return Kit.panel("Body", "body", {
        Size = UDim2.fromScale(1, 1),
        Visible = false,

        vision.event("BodyState", { Sizes = {}, ScaleParts = false, PickLabel = "", PickHidden = false }, function(Self: Instance, _, View: Bridges.BodyView)
            fill(Self, View)
        end),

        vision.event("BodyFigure", {}, function(Self: Instance, _, Lit: { [string]: boolean })
            Kit.paintFigure(Self, "Body_Figure", Lit)
        end),
    }, {
        Parts.merge(Kit.body("Body_List"), {
            Kit.section("Body_SkinSection", "skin", 1, {
                Kit.colorButton("Body_Skin", "pick skin color", Bridge, "SkinPick", 1,
                    Kit.press("Body_SkinReset", "normal", { Size = UDim2.fromOffset(96, 40) }, Style.PlateColor, Style.InkColor, Bridge, "SkinReset", nil, false, 15)),
            }),

            Kit.section("Body_SizeSection", "body size", 2, (function(): { Kit.Declaration }
                const Rows = sizes()
                table.insert(Rows, Kit.press("Body_ScaleParts", "scale parts with body: off", { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 10 }, Style.ButtonColor, Style.InkColor, Bridge, "ScaleParts", nil, false, 16))
                return Rows
            end)()),

            Kit.section("Body_Animation", "animations", 3, {
                Kit.chips("Body_Animations", "BodyAnimations", Vector2.new(132, 34), Bridge, "Animation", 1),
            }),

            Kit.section("Body_Parts", "body parts", 4, {
                Kit.text("Body_Hint", "pick one part on the figure or a whole limb", 14, {
                    TextColor3 = Common["OutlineColor"],
                    LayoutOrder = 1,
                }),
                Kit.row("Body_PickRow", Kit.FigureSize.Y, 2, {
                    Kit.figure("Body_Figure", Bridge, "Pick", 1),
                    limbColumn(),
                }),
                Kit.text("Body_Picked", "nothing picked", 17, {
                    FontFace = Parts.Heading,
                    LayoutOrder = 3,
                }),
                {
                    ClassName = "Frame",
                    Name = "Body_PickTools",
                    Size = UDim2.fromScale(1, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    LayoutOrder = 4,
                    Visible = false,

                    {
                        ClassName = "UIListLayout",
                        FillDirection = Enum.FillDirection.Vertical,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0, 8),
                    },

                    Kit.row("Body_PickActions", 42, 1, {
                        Kit.press("Body_Hide", "hide it", { Size = UDim2.fromOffset(120, 40) }, Style.ButtonColor, Style.InkColor, Bridge, "Hide", nil, false, 16),
                        Kit.press("Body_PartReset", "reset it", { Size = UDim2.fromOffset(120, 40) }, Style.PlateColor, Style.InkColor, Bridge, "PartReset", nil, false, 16),
                    }),
                    Kit.chips("Body_Swaps", "BodySwaps", Vector2.new(132, 34), Bridge, "Swap", 2),
                },
            }),
        }),
    })
end

return Body
