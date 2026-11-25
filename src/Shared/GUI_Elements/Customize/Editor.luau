--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Bridges = require(ReplicatedStorage.Shared.Customize.Bridges)
const Kit = require(script.Parent.Kit)

const Style = Kit.Style
const Common = Kit.Common
const Bridge = Bridges.Editor

const Editor = {
    Width = 384,
    Modes = {
        { Id = "Translate", Label = "move", Key = "T" },
        { Id = "Rotate", Label = "rotate", Key = "R" },
        { Id = "Scale", Label = "scale", Key = "Y" },
        { Id = "None", Label = "off", Key = "Q" },
    },
}

const function modeButton(Mode: { Id: string, Label: string, Key: string }, Order: number): Kit.Declaration
    return Parts.card(`Editor_Mode_{Mode.Id}`, {
        Size = UDim2.fromOffset(68, 58),
        LayoutOrder = Order,
    }, {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Style.ButtonColor,
        Activated = function()
            Bridge:Call("Mode", Mode.Id)
        end,
        Parts.bevel(`Editor_Mode_{Mode.Id}_Shine`, 3, Kit.light(Style.ButtonColor), Kit.dark(Style.ButtonColor)),

        Kit.text("Label", Mode.Label, 15, {
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.new(1, 0, 0, 18),
            FontFace = Parts.Heading,
            TextXAlignment = Enum.TextXAlignment.Center,
        }),

        Parts.keyBadge(Mode.Key, 22, {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -6),
        }),
    }, Kit.Depth, nil, Kit.ItemStroke)
end

const function modes(): Kit.Declaration
    const Buttons: { Kit.Declaration } = {}
    for Order, Mode in Editor.Modes do
        table.insert(Buttons, modeButton(Mode, Order))
    end
    return Kit.section("Editor_Modes", "edit mode", 4, {
        Kit.row("Editor_ModeRow", 60, 1, Buttons),
    })
end

const function materials(): Kit.Declaration
    return Kit.materialList("Editor_Materials", Bridge, "Material", 2)
end

const function fill(Root: Instance, View: Bridges.EditorView)
    const Group = View.Kind == "Group"
    Kit.label(Root, "Editor_Title", if Group then "edit group" else "edit part")
    Kit.label(Root, "Editor_Heading", View.Name)
    Kit.label(Root, "Editor_Kind", View.Label)
    Kit.boxText(Root, "Editor_Name", View.Name)
    Kit.boxText(Root, "Editor_Texture", View.Texture)
    Kit.setChip(Root, "Editor_Color", View.Color)
    Kit.show(Root, "Editor_Weld", not Group)
    Kit.show(Root, "Editor_TextureSection", not Group)
    Kit.show(Root, "Editor_Ungroup", Group)
    Kit.show(Root, "Editor_Reset", not Group)
    Kit.setButton(Root, "Editor_Delete", if Group then "delete all" else "delete")
    for _, Mode in Editor.Modes do
        const On = View.Mode == Mode.Id
        Kit.setButton(Root, `Editor_Mode_{Mode.Id}`, nil, if On then Style.AccentColor else Style.ButtonColor)
        const Button = Root:FindFirstChild(`Editor_Mode_{Mode.Id}_Body`, true)
        const Text = if Button then Button:FindFirstChild("Label") else nil
        if Text and Text:IsA("TextLabel") then
            Text.TextColor3 = if On then Style.AccentText else Style.InkColor
        end
    end
    const Lit: { [string]: boolean } = {}
    if View.Attach then
        Lit[View.Attach] = true
    end
    Kit.paintFigure(Root, "Editor_Figure", Lit)
end

function Editor.build(): Kit.Declaration
    return Kit.panel("Editor", "edit part", {
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.new(0, Editor.Width, 1, 0),
        Visible = false,

        vision.event("EditorState", { Kind = "Part", Id = "", Name = "", Label = "", Texture = "", Mode = "None" }, function(Self: Instance, _, View: Bridges.EditorView)
            fill(Self, View)
        end),
    }, {
        Parts.merge(Kit.body("Editor_List"), {
            Parts.merge(Kit.section("Editor_Top", "editing", 1, {
                Kit.text("Editor_Heading", "", 20, {
                    FontFace = Parts.Heading,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    LayoutOrder = 1,
                }),
                Kit.text("Editor_Kind", "", 14, {
                    TextColor3 = Common["PackColor"],
                    LayoutOrder = 2,
                }),
                Kit.row("Editor_DoneRow", 46, 3, {
                    Kit.press("Editor_Done", "done", { Size = UDim2.fromOffset(110, 42) }, Style.SuccessColor, Style.SuccessText, Bridge, "Done", nil, true, 18),
                    Kit.text("Editor_DoneHint", "or press", 14, {
                        Size = UDim2.fromOffset(64, 42),
                        TextColor3 = Common["OutlineColor"],
                        TextXAlignment = Enum.TextXAlignment.Right,
                        TextYAlignment = Enum.TextYAlignment.Center,
                    }),
                    Parts.keyBadge("F", 28),
                }),
            }), { BackgroundColor3 = Kit.GroupColor }),

            Kit.section("Editor_NameSection", "name", 2, {
                Kit.input("Editor_Name", "give it a name", { Size = UDim2.new(1, 0, 0, 36) }, function(Text: string)
                    Bridge:Call("Name", Text)
                end),
            }),

            Kit.section("Editor_Weld", "welded to", 3, {
                Kit.text("Editor_WeldHint", "pick a body part to weld it there", 14, {
                    TextColor3 = Common["OutlineColor"],
                    LayoutOrder = 1,
                }),
                Kit.row("Editor_FigureRow", Kit.FigureSize.Y, 2, {
                    {
                        ClassName = "Frame",
                        Name = "Editor_FigurePad",
                        Size = UDim2.fromOffset(52, 10),
                        BackgroundTransparency = 1,
                    },
                    Kit.figure("Editor_Figure", Bridge, "Reweld", 2),
                }),
            }),

            modes(),

            Kit.section("Editor_Paint", "color and material", 5, {
                Kit.colorButton("Editor_Color", "pick color", Bridge, "ColorPick", 1,
                    Kit.press("Editor_ColorReset", "original", { Size = UDim2.fromOffset(96, 40) }, Style.PlateColor, Style.InkColor, Bridge, "ColorReset", nil, false, 15), 130),
                materials(),
            }),

            Kit.section("Editor_TextureSection", "texture", 6, {
                Kit.row("Editor_TextureRow", 40, 1, {
                    Kit.input("Editor_Texture", "image or decal id", { Size = UDim2.new(1, -104, 0, 36) }, function(Text: string)
                        Bridge:Call("Texture", Text)
                    end),
                    Kit.press("Editor_Restore", "restore", { Size = UDim2.fromOffset(96, 38) }, Style.PlateColor, Style.InkColor, Bridge, "Restore", nil, false, 15),
                }),
            }),

            Kit.row("Editor_Actions", 46, 7, {
                Kit.press("Editor_Reset", "reset", { Size = UDim2.fromOffset(84, 42) }, Style.PlateColor, Style.InkColor, Bridge, "Reset", nil, false, 16),
                Kit.press("Editor_Copy", "copy", { Size = UDim2.fromOffset(88, 42) }, Style.ButtonColor, Style.InkColor, Bridge, "Duplicate", nil, false, 16),
                Kit.press("Editor_Ungroup", "ungroup", { Size = UDim2.fromOffset(92, 42), Visible = false }, Style.ButtonColor, Style.InkColor, Bridge, "Ungroup", nil, false, 16),
                Kit.press("Editor_Delete", "delete", { Size = UDim2.fromOffset(100, 42) }, Style.CloseColor, Style.CloseText, Bridge, "Delete", nil, true, 16),
            }),
        }),
    })
end

return Editor
