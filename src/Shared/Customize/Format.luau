--!strict
const Config = require(script.Parent.Config)
const Catalog = require(script.Parent.Catalog)

const Format = {}

const function finite(Value: any): boolean
    return type(Value) == "number" and Value == Value and Value ~= math.huge and Value ~= -math.huge
end

const function numbers(Value: unknown, Count: number, Low: number?, High: number?): { number }?
    if type(Value) ~= "table" then
        return nil
    end
    const Made: { number } = {}
    for Index = 1, Count do
        const Number = (Value :: any)[Index]
        if not finite(Number) then
            return nil
        end
        if (Low and Number < Low) or (High and Number > High) then
            return nil
        end
        Made[Index] = Number
    end
    return Made
end

function Format.empty(): Look
    return {
        Version = Config.LookVersion,
        Swaps = {},
        Body = {},
        Parts = {},
        Groups = {},
    }
end

function Format.cleanName(Value: unknown, Limit: number?): string?
    if type(Value) ~= "string" then
        return nil
    end
    const Plain = string.gsub(Value, "%c", "")
    const Trimmed = string.match(Plain, "^%s*(.-)%s*$") or ""
    if Trimmed == "" then
        return nil
    end
    return string.sub(Trimmed, 1, Limit or Config.MaxPartName)
end

function Format.assetId(Value: unknown): number?
    if type(Value) == "string" then
        const Digits = string.match(Value, "(%d+)")
        return if Digits then Format.assetId(tonumber(Digits)) else nil
    end
    if not finite(Value) or (Value :: number) <= 0 or (Value :: number) ~= math.floor(Value :: number) then
        return nil
    end
    return Value :: number
end

function Format.clothingAllowed(Kind: Catalog.ClothingKind, Asset: number): boolean
    return Config.AllowClothingIds or Catalog.preset(Kind, Asset) ~= nil
end

function Format.limbOf(Key: string): string?
    if Catalog.Limbs[Key] then
        return Key
    end
    for Limb, Pieces in Catalog.Limbs do
        if table.find(Pieces, Key) then
            return Limb
        end
    end
    return nil
end

function Format.isBody(Name: unknown): boolean
    return type(Name) == "string" and table.find(Catalog.BodyParts, Name) ~= nil
end

function Format.material(Name: unknown): Enum.Material?
    if type(Name) ~= "string" then
        return nil
    end
    const Ok, Found = pcall(function()
        return (Enum.Material :: any)[Name]
    end)
    return if Ok and typeof(Found) == "EnumItem" then Found :: Enum.Material else nil
end

function Format.texture(Value: unknown): boolean
    if type(Value) ~= "string" then
        return false
    end
    return Value == "" or string.match(Value, "^rbxassetid://%d+$") ~= nil or string.match(Value, "^%d+$") ~= nil
end

function Format.packFrame(Frame: CFrame): { number }
    return { Frame:GetComponents() }
end

function Format.frame(Data: { number }?): CFrame
    if not Data or #Data < 12 then
        return CFrame.identity
    end
    return CFrame.new(
        Data[1], Data[2], Data[3],
        Data[4], Data[5], Data[6],
        Data[7], Data[8], Data[9],
        Data[10], Data[11], Data[12]
    ):Orthonormalize()
end

function Format.packVector(Vector: Vector3): { number }
    return { Vector.X, Vector.Y, Vector.Z }
end

function Format.vector(Data: { number }?, Fallback: Vector3): Vector3
    if not Data or #Data < 3 then
        return Fallback
    end
    return Vector3.new(Data[1], Data[2], Data[3])
end

function Format.packColor(Color: Color3): { number }
    return { Color.R, Color.G, Color.B }
end

function Format.color(Data: { number }?): Color3?
    if not Data or #Data < 3 then
        return nil
    end
    return Color3.new(Data[1], Data[2], Data[3])
end

function Format.clampOffset(Frame: CFrame): CFrame
    const Position = Frame.Position
    if Position.Magnitude <= Config.MaxOffset then
        return Frame
    end
    return CFrame.new(Position.Unit * Config.MaxOffset) * Frame.Rotation
end

function Format.clampScale(Scale: Vector3): Vector3
    return Vector3.new(
        math.clamp(Scale.X, Config.MinScale, Config.MaxScale),
        math.clamp(Scale.Y, Config.MinScale, Config.MaxScale),
        math.clamp(Scale.Z, Config.MinScale, Config.MaxScale)
    )
end

function Format.limitScale(Scale: Vector3, Bound: Vector3?): Vector3
    const Clean = Format.clampScale(Scale)
    if not Bound then
        return Clean
    end
    const function axis(Value: number, Base: number): number
        if Base <= 0 then
            return Value
        end
        return math.max(math.min(Value, Config.MaxPartSize / Base), Config.MinScale)
    end
    return Vector3.new(axis(Clean.X, Bound.X), axis(Clean.Y, Bound.Y), axis(Clean.Z, Bound.Z))
end

const function paint(Given: any, Into: any): string?
    if Given.Color ~= nil then
        const Color = numbers(Given.Color, 3, 0, 1)
        if not Color then
            return "A color is not valid"
        end
        Into.Color = Color
    end
    if Given.Material ~= nil then
        if not Format.material(Given.Material) then
            return "A material is not valid"
        end
        Into.Material = Given.Material
    end
    if Given.Texture ~= nil then
        if not Format.texture(Given.Texture) then
            return "A texture is not valid"
        end
        Into.Texture = Given.Texture
    end
    return nil
end

const function cleanPart(Given: any): (LookPart?, string?)
    if type(Given) ~= "table" then
        return nil, "A part is not valid"
    end
    const Id = Given.Id
    if type(Id) ~= "string" or #Id == 0 or #Id > Config.MaxIdLength then
        return nil, "A part id is not valid"
    end
    const Kind = Given.Kind
    if Kind ~= "Asset" and Kind ~= "Builtin" and Kind ~= "Default" then
        return nil, "A part kind is not valid"
    end
    if not Format.isBody(Given.Attach) then
        return nil, "A part is attached to something that is not a body part"
    end
    const Raw = numbers(Given.Offset, 12)
    if not Raw then
        return nil, "A part offset is not valid"
    end
    const Offset = Format.packFrame(Format.clampOffset(Format.frame(Raw)))
    const Stretch = numbers(Given.Scale, 3)
    if not Stretch then
        return nil, "A part scale is not valid"
    end
    const Scale = Format.packVector(Format.clampScale(Vector3.new(Stretch[1], Stretch[2], Stretch[3])))
    const Made: LookPart = {
        Id = Id,
        Kind = Kind,
        Attach = Given.Attach,
        Offset = Offset,
        Scale = Scale,
        Name = Format.cleanName(Given.Name),
        Group = if type(Given.Group) == "string" and #Given.Group <= Config.MaxIdLength then Given.Group else nil,
    }
    if Kind == "Asset" then
        const Asset = Given.Asset
        if not finite(Asset) or Asset <= 0 or Asset ~= math.floor(Asset) then
            return nil, "An item id is not valid"
        end
        Made.Asset = Asset
    elseif Kind == "Builtin" then
        if type(Given.Builtin) ~= "string" or not Catalog.part(Given.Builtin) then
            return nil, nil
        end
        Made.Builtin = Given.Builtin
        if type(Given.Piece) == "string" and #Given.Piece > 0 and #Given.Piece <= 60 then
            Made.Piece = Given.Piece
        end
    else
        if type(Given.Target) ~= "string" or #Given.Target == 0 or #Given.Target > 60 then
            return nil, "An accessory name is not valid"
        end
        Made.Target = Given.Target
        if Given.Removed == true then
            Made.Removed = true
        end
    end
    const Problem = paint(Given, Made)
    if Problem then
        return nil, Problem
    end
    return Made, nil
end

function Format.sanitize(Raw: unknown): (Look?, string?)
    if type(Raw) ~= "table" then
        return nil, "That look is not valid"
    end
    const Given = Raw :: any
    const Made = Format.empty()

    if Given.Skin ~= nil then
        const Skin = numbers(Given.Skin, 3, 0, 1)
        if not Skin then
            return nil, "The skin color is not valid"
        end
        Made.Skin = Skin
    end

    if Given.Swaps ~= nil then
        if type(Given.Swaps) ~= "table" then
            return nil, "The limb swaps are not valid"
        end
        for Key, Name in Given.Swaps do
            const Limb = if type(Key) == "string" then Format.limbOf(Key) else nil
            if not Limb then
                return nil, "A limb swap is not valid"
            end
            const Definition = if type(Name) == "string" then Catalog.swap(Name) else nil
            if not Definition or not table.find(Definition.Limbs, Limb) then
                return nil, `{tostring(Name)} can not go on {Key}`
            end
            Made.Swaps[Key] = Name
        end
    end

    if Given.Body ~= nil then
        if type(Given.Body) ~= "table" then
            return nil, "The body edits are not valid"
        end
        for Name, Body in Given.Body do
            if not Format.isBody(Name) or type(Body) ~= "table" then
                return nil, "A body part edit is not valid"
            end
            const Clean: LookBody = { Name = Format.cleanName(Body.Name) }
            const Problem = paint(Body, Clean)
            if Problem then
                return nil, Problem
            end
            if Body.Hidden == true then
                Clean.Hidden = true
            end
            Made.Body[Name] = Clean
        end
    end

    for Key, Range in Config.Proportions do
        const Value = Given[Key]
        if Value == nil then
            continue
        end
        if not finite(Value) or Value < Range.Min - 1e-3 or Value > Range.Max + 1e-3 then
            return nil, `The {string.lower(Key)} size is not valid`
        end
        if math.abs(Value - 1) > 1e-3 then
            (Made :: any)[Key] = Value
        end
    end

    if Given.ScaleParts == true then
        Made.ScaleParts = true
    end

    if Given.Animation ~= nil then
        if type(Given.Animation) ~= "string" or not Catalog.animation(Given.Animation) then
            return nil, "That animation set does not exist"
        end
        if Given.Animation ~= Config.DefaultAnimation then
            Made.Animation = Given.Animation
        end
    end

    for _, Kind in { "Shirt", "Pants" } :: { Catalog.ClothingKind } do
        const Value = Given[Kind]
        if Value == nil then
            continue
        end
        const Asset = Format.assetId(Value)
        if not Asset or type(Value) ~= "number" then
            return nil, `The {string.lower(Kind)} id is not valid`
        end
        if not Format.clothingAllowed(Kind, Asset) then
            return nil, `That {string.lower(Kind)} is not one of the choices`
        end
        (Made :: any)[Kind] = Asset
    end

    if Given.Groups ~= nil then
        if type(Given.Groups) ~= "table" then
            return nil, "The groups are not valid"
        end
        local Count = 0
        for Key, Group in Given.Groups do
            if type(Key) ~= "string" or #Key == 0 or #Key > Config.MaxIdLength or type(Group) ~= "table" then
                return nil, "A group is not valid"
            end
            Count += 1
            if Count > Config.MaxGroups then
                return nil, `A look can only have {Config.MaxGroups} groups`
            end
            const Code = if type(Group.Code) == "string" and string.match(Group.Code, "^%w+$") and #Group.Code <= 12 then Group.Code else nil
            Made.Groups[Key] = { Name = Format.cleanName(Group.Name) or "group", Code = Code }
        end
    end

    if Given.Parts ~= nil then
        if type(Given.Parts) ~= "table" then
            return nil, "The parts are not valid"
        end
        if #Given.Parts > Config.MaxRigParts then
            return nil, `A look can only have {Config.MaxRigParts} parts`
        end
        const Seen: { [string]: boolean } = {}
        for _, Part in Given.Parts do
            const Clean, Problem = cleanPart(Part)
            if not Clean then
                if Problem then
                    return nil, Problem
                end
                continue
            end
            if Seen[Clean.Id] then
                return nil, "Two parts share the same id"
            end
            Seen[Clean.Id] = true
            const Group = Clean.Group
            if Group and not Made.Groups[Group] then
                Clean.Group = nil
            end
            table.insert(Made.Parts, Clean)
        end
    end
    return Made, nil
end

function Format.clone(Given: Look): Look
    const Made = Format.sanitize(Given)
    return Made or Format.empty()
end

function Format.assets(Given: Look): { number }
    const Found: { number } = {}
    const Seen: { [number]: boolean } = {}
    for _, Part in Given.Parts do
        const Asset = Part.Asset
        if Part.Kind == "Asset" and Asset and not Seen[Asset] then
            Seen[Asset] = true
            table.insert(Found, Asset)
        end
    end
    return Found
end

return Format
