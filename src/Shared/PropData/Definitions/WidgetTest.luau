--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const PropData = require(script.Parent.Parent)

const Gray = Color3.fromRGB(163, 162, 165)
const Ink = Color3.fromRGB(42, 38, 36)
const ToggleOff = Color3.fromRGB(214, 226, 245)
const ToggleOn = Color3.fromRGB(255, 214, 90)
const Typewriter = Font.fromEnum(Enum.Font.SpecialElite)
const FloatHeight = 1.5

const function partsOf(Model: Model): { BasePart }
    const Found: { BasePart } = {}
    for _, Item in Model:GetDescendants() do
        if Item:IsA("BasePart") then
            table.insert(Found, Item)
        end
    end
    return Found
end

const function showButtons(Prop: PropData.Prop)
    Prop:enableWidgets()
    Prop:enableInfo()
end

const function materialsOf(Prop: PropData.Prop, Model: Model): { [BasePart]: Enum.Material }
    const Known = Prop.Data.Materials
    if Known then
        return Known
    end
    const Made: { [BasePart]: Enum.Material } = {}
    for _, Part in partsOf(Model) do
        Made[Part] = Part.Material
    end
    Prop.Data.Materials = Made
    return Made
end

const function tint(Model: Model, Color: unknown, Neon: boolean, Materials: { [BasePart]: Enum.Material }?)
    const Paint = if typeof(Color) == "Color3" then Color else Gray
    for _, Part in partsOf(Model) do
        Part.Color = Paint
        const Original = if Materials then Materials[Part] else nil
        Part.Material = if Neon then Enum.Material.Neon else Original or Part.Material
    end
end

const function glow(Prop: PropData.Prop, Model: Model, Tint: Color3)
    const Strength = Prop:getState("Glow")
    const Level = if type(Strength) == "number" then Strength else 0
    local Light: PointLight? = Prop.Data.Light
    if not Light or not Light.Parent then
        if Level <= 0 then
            return
        end
        const Part = Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart", true)
        if not Part then
            return
        end
        const Made = Instance.new("PointLight")
        Made.Shadows = false
        Made.Parent = Part
        Prop.Data.Light = Made
        Light = Made
    end
    const Bulb = Light :: PointLight
    Bulb.Enabled = Level > 0
    Bulb.Brightness = Level
    Bulb.Range = 8 + Level * 1.5
    Bulb.Color = Tint
end

const function tag(Prop: PropData.Prop, Model: Model)
    const Text = Prop:getState("Tag")
    const Existing = Prop.Data.Tag
    if type(Text) ~= "string" or Text == "" then
        if Existing then
            Existing:Cleanup()
            Prop.Data.Tag = nil
        end
        return
    end
    if Existing then
        Existing.Text(Text)
        return
    end
    const Part = Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart", true)
    if not Part then
        return
    end
    const vision = require(ReplicatedStorage.MainPackages.vision)
    const _, Size = Model:GetBoundingBox()
    const Made = vision.Scope():Capture({
        ClassName = "BillboardGui",
        Name = "PaintTag",
        Adornee = Part,
        Size = UDim2.fromScale(6, 0.8),
        StudsOffset = Vector3.new(0, Size.Y / 2 + 2.8, 0),
        LightInfluence = 0,
        MaxDistance = 80,
        vision.mount(Model),

        {
            ClassName = "TextLabel",
            Name = "Tag",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = Text,
            FontFace = Typewriter,
            TextScaled = true,
            TextColor3 = Color3.new(1, 1, 1),

            vision.event("Text", Text, function(Label: Instance, _, Value: string)
                (Label :: TextLabel).Text = Value
            end),

            {
                ClassName = "UIStroke",
                Thickness = 2,
                Color = Ink
            }
        }
    }::BillboardGui & any)
    Made:Mount()
    Prop.Data.Tag = Made
end

const function paint(Prop: PropData.Prop)
    const Model = Prop.Model
    if not Model then
        return
    end
    const Color = Prop:getState("Color")
    tint(Model, Color, Prop:getState("Neon") == true, materialsOf(Prop, Model))
    glow(Prop, Model, if typeof(Color) == "Color3" then Color else Gray)
    tag(Prop, Model)
end

const function flash(Prop: PropData.Prop)
    const Model = Prop.Model
    if not Model then
        return
    end
    const Shine = Instance.new("Highlight")
    Shine.FillColor = Color3.new(1, 1, 1)
    Shine.FillTransparency = 0.4
    Shine.OutlineTransparency = 0
    Shine.DepthMode = Enum.HighlightDepthMode.Occluded
    Shine.Parent = Model
    task.delay(0.35, function()
        Shine:Destroy()
    end)
end

const function neonToggle(Context: PropData.FieldContext): { [any]: any }
    const Start = Context.Value == true
    return {
        ClassName = "TextButton",
        Name = "NeonToggle",
        Size = UDim2.fromScale(1, 1),
        Text = if Start then "neon: on" else "neon: off",
        FontFace = Typewriter,
        TextSize = 18,
        TextColor3 = Ink,
        BackgroundColor3 = if Start then ToggleOn else ToggleOff,
        BorderSizePixel = 0,
        AutoButtonColor = true,
        Activated = function(Button: Instance)
            const Next = Context.get() ~= true
            Context.set(Next)
            const Toggle = Button :: TextButton
            Toggle.Text = if Next then "neon: on" else "neon: off"
            Toggle.BackgroundColor3 = if Next then ToggleOn else ToggleOff
        end,

        {
            ClassName = "UIStroke",
            Thickness = 1.6,
            Color = Ink,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        }
    }
end

const function speedOf(States: { [string]: any }): number
    const Speed = States.Speed
    return if type(Speed) == "number" then Speed else 1
end

const Definitions: PropData.Definitions = {
    [27] = {
        Name = "Paint Crate",
        Model = "Props/Test/Paint Crate",

        States = {
            Color = {
                Default = Gray,
            },
            Tag = {
                Default = "",
                check = function(Value: PropData.Value): boolean
                    return type(Value) == "string" and #Value <= 24
                end,
            },
            Glow = {
                Default = 0,
                check = function(Value: PropData.Value): boolean
                    return type(Value) == "number" and Value >= 0 and Value <= 10
                end,
            },
            Neon = {
                Default = false,
            },
            Ping = {
                Default = 0,
                Save = false,
                Public = true,
            },
        },

        Widget = {
            Title = "Paint Crate",
            Fields = {
                { Id = "Color", Kind = "Color", Label = "color", State = "Color" },
                { Id = "Tag", Kind = "Text", Label = "name tag", State = "Tag", Placeholder = "type a name", MaxLength = 24 },
                { Id = "Glow", Kind = "Number", Label = "glow", State = "Glow", Min = 0, Max = 10, Step = 0.5 },
                { Id = "Neon", Kind = "Custom", Label = "neon (custom field)", State = "Neon", Height = 40, build = neonToggle },
            },
            Buttons = {
                {
                    Id = "Shuffle",
                    Color = Color3.fromRGB(240, 180, 60),
                    pressed = function(Prop: PropData.Prop)
                        Prop:setState("Color", Color3.fromHSV(math.random(), 0.65, 0.95))
                    end,
                },
                {
                    Id = "Wave",
                    Color = Color3.fromRGB(78, 160, 96),
                    Public = true,
                    pressed = function(Prop: PropData.Prop)
                        const Ping = Prop:getState("Ping")
                        Prop:setPublicState("Ping", (if type(Ping) == "number" then Ping else 0) + 1)
                    end,
                },
            },
        },

        onPlaced = function(Prop: PropData.Prop)
            paint(Prop)
            showButtons(Prop)
        end,

        onZoneEnter = function(Prop: PropData.Prop)
            paint(Prop)
            showButtons(Prop)
        end,

        onState = function(Prop: PropData.Prop, Name: string)
            if Name == "Ping" then
                flash(Prop)
            else
                paint(Prop)
            end
        end,

        onRemoved = function(Prop: PropData.Prop)
            const Tag = Prop.Data.Tag
            if Tag then
                Tag:Cleanup()
            end
        end,

        onPreview = function(Model: Model, States: PropData.States)
            tint(Model, States.Color, States.Neon == true, nil)
        end,

        onWidgetSave = function(Prop: PropData.Prop, Values: { [string]: any })
            for _, Name in { "Color", "Tag", "Glow", "Neon" } do
                if Values[Name] ~= nil then
                    Prop:setState(Name, Values[Name])
                end
            end
        end,
    },

    [28] = {
        Name = "Float Ball",
        Model = "Props/Test/Float Ball",
        MaxScale = 3,

        States = {
            Speed = {
                Default = 1,
                check = function(Value: PropData.Value): boolean
                    return type(Value) == "number" and Value >= 0 and Value <= 10
                end,
            },
        },

        Widget = {
            Title = "Float Ball",
            Fields = {
                { Id = "Speed", Kind = "Number", Label = "float speed", State = "Speed", Min = 0, Max = 10, Step = 0.25 },
            },
        },

        ServerBox = {
            Shape = Enum.PartType.Ball,
            step = function(Box: PropData.ServerBox, Now: number)
                const Lift = math.sin(Now * speedOf(Box.Prop.States)) * FloatHeight * Box.Prop.Scale
                Box:moveTo(Box.Rest + Vector3.new(0, Lift, 0))
            end,
        },

        onPlaced = showButtons,

        onZoneEnter = function(Prop: PropData.Prop)
            showButtons(Prop)
        end,

        onWidgetSave = function(Prop: PropData.Prop, Values: { [string]: any })
            if type(Values.Speed) == "number" then
                Prop:setState("Speed", Values.Speed)
            end
        end,
    },
}

return Definitions
