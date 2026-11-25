--!strict
const Catalog = require(script.Parent.Catalog)
const Config = require(script.Parent.Config)
const Format = require(script.Parent.Format)

export type Resolve = (AssetId: number) -> Instance?
export type Wear = (Kind: Catalog.ClothingKind, Asset: number) -> string?

const Rig = {
    AbsoluteScale = "CustomizeAbsoluteScale",
    FolderName = "Customize",
    WeldName = "CustomizeWeld",
    InnerName = "CustomizeInner",
}

const Kept = "CustomizeKept"
const Made = "CustomizeMade"
const Templates: { [string]: string } = { Shirt = "ShirtTemplate", Pants = "PantsTemplate" }
const BodyFields = { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }

function Rig.bodyParts(Character: Model): { [string]: BasePart }
    const Made: { [string]: BasePart } = {}
    for _, Name in Catalog.BodyParts do
        const Part = Character:FindFirstChild(Name)
        if Part and Part:IsA("BasePart") then
            Made[Name] = Part
        end
    end
    return Made
end

function Rig.folder(Character: Model): Folder
    const Existing = Character:FindFirstChild(Rig.FolderName)
    if Existing and Existing:IsA("Folder") then
        return Existing
    end
    const Made = Instance.new("Folder")
    Made.Name = Rig.FolderName
    Made.Parent = Character
    return Made
end

function Rig.rootOf(Item: Instance?): BasePart?
    if not Item then
        return nil
    end
    if Item:IsA("BasePart") then
        return Item
    end
    if Item:IsA("Model") and Item.PrimaryPart then
        return Item.PrimaryPart
    end
    return Item:FindFirstChildWhichIsA("BasePart", true)
end

function Rig.find(Character: Model, Id: string): Instance?
    const Holder = Character:FindFirstChild(Rig.FolderName)
    return if Holder then Holder:FindFirstChild(Id) else nil
end

const function partsIn(Root: Instance): { BasePart }
    const Found: { BasePart } = {}
    if Root:IsA("BasePart") then
        table.insert(Found, Root)
    end
    for _, Item in Root:GetDescendants() do
        if Item:IsA("BasePart") then
            table.insert(Found, Item)
        end
    end
    return Found
end

function Rig.textureOf(Part: BasePart): string?
    if Part:IsA("MeshPart") then
        return Part.TextureID
    end
    const Mesh = Part:FindFirstChildOfClass("SpecialMesh")
    return if Mesh then Mesh.TextureId else nil
end

const function setTexture(Part: BasePart, Texture: string)
    const Id = if string.match(Texture, "^%d+$") then `rbxassetid://{Texture}` else Texture
    if Part:IsA("MeshPart") then
        Part.TextureID = Id
        return
    end
    const Mesh = Part:FindFirstChildOfClass("SpecialMesh")
    if Mesh then
        Mesh.TextureId = Id
    end
end

const function keep(Item: Instance)
    if Item:GetAttribute(Kept) then
        return
    end
    Item:SetAttribute(Kept, true)
    if Item:IsA("BasePart") then
        Item:SetAttribute("CustomizeColor", Item.Color)
        Item:SetAttribute("CustomizeMaterial", Item.Material.Name)
        Item:SetAttribute("CustomizeTransparency", Item.Transparency)
        const Texture = Rig.textureOf(Item)
        if Texture then
            Item:SetAttribute("CustomizeTexture", Texture)
        end
    elseif Item:IsA("Decal") then
        Item:SetAttribute("CustomizeTransparency", Item.Transparency)
    elseif Item:IsA("BodyColors") then
        for _, Field in BodyFields do
            Item:SetAttribute(`Customize{Field}`, (Item :: any)[Field])
        end
    elseif Item:IsA("Shirt") then
        Item:SetAttribute("CustomizeTemplate", Item.ShirtTemplate)
    elseif Item:IsA("Pants") then
        Item:SetAttribute("CustomizeTemplate", Item.PantsTemplate)
    elseif Item:IsA("NumberValue") then
        Item:SetAttribute("CustomizeValue", Item.Value)
    end
end

const function restore(Item: Instance)
    if not Item:GetAttribute(Kept) then
        return
    end
    if Item:IsA("BasePart") then
        const Color = Item:GetAttribute("CustomizeColor")
        const Material = Format.material(Item:GetAttribute("CustomizeMaterial"))
        const Transparency = Item:GetAttribute("CustomizeTransparency")
        const Texture = Item:GetAttribute("CustomizeTexture")
        if typeof(Color) == "Color3" then
            Item.Color = Color
        end
        if Material then
            Item.Material = Material
        end
        if type(Transparency) == "number" then
            Item.Transparency = Transparency
        end
        if type(Texture) == "string" then
            setTexture(Item, Texture)
        end
    elseif Item:IsA("Decal") then
        const Transparency = Item:GetAttribute("CustomizeTransparency")
        if type(Transparency) == "number" then
            Item.Transparency = Transparency
        end
    elseif Item:IsA("BodyColors") then
        for _, Field in BodyFields do
            const Value = Item:GetAttribute(`Customize{Field}`)
            if typeof(Value) == "Color3" then
                (Item :: any)[Field] = Value
            end
        end
    elseif Item:IsA("Shirt") or Item:IsA("Pants") then
        const Template = Item:GetAttribute("CustomizeTemplate")
        if type(Template) == "string" then
            (Item :: any)[Templates[Item.ClassName]] = Template
        end
    elseif Item:IsA("NumberValue") then
        const Value = Item:GetAttribute("CustomizeValue")
        if type(Value) == "number" then
            Item.Value = Value
        end
    end
end

const function forget(Item: Instance)
    for _, Name in { Kept, "CustomizeColor", "CustomizeMaterial", "CustomizeTransparency", "CustomizeTexture", "CustomizeTemplate", "CustomizeValue" } do
        Item:SetAttribute(Name, nil)
    end
end

const function paintPart(Part: BasePart, Color: { number }?, Material: string?, Texture: string?)
    const Tint = Format.color(Color)
    if Tint then
        Part.Color = Tint
    end
    const Found = Format.material(Material)
    if Found then
        Part.Material = Found
    end
    if Texture ~= nil then
        setTexture(Part, Texture)
    end
end

const function hide(Part: BasePart)
    keep(Part)
    Part.Transparency = 1
    for _, Child in Part:GetChildren() do
        if Child:IsA("Decal") then
            keep(Child)
            Child.Transparency = 1
        end
    end
end

const function stripJoints(Root: Instance)
    for _, Item in Root:GetDescendants() do
        if Item:IsA("JointInstance") or Item:IsA("WeldConstraint") or Item:IsA("RigidConstraint") then
            if Item.Name ~= Rig.InnerName then
                Item:Destroy()
            end
        end
    end
end

const function settle(Root: Instance)
    for _, Part in partsIn(Root) do
        Part.Anchored = false
        Part.CanCollide = false
        Part.CanTouch = false
        Part.CanQuery = false
        Part.Massless = true
        if typeof(Part:GetAttribute("CustomizeBase")) ~= "Vector3" then
            Part:SetAttribute("CustomizeBase", Part.Size)
        end
        const Mesh = Part:FindFirstChildOfClass("SpecialMesh")
        if Mesh and typeof(Mesh:GetAttribute("CustomizeBase")) ~= "Vector3" then
            Mesh:SetAttribute("CustomizeBase", Mesh.Scale)
        end
    end
    for _, Item in Root:GetDescendants() do
        if Item:IsA("Weld") and Item.Name == Rig.InnerName and typeof(Item:GetAttribute("CustomizeBase")) ~= "CFrame" then
            Item:SetAttribute("CustomizeBase", Item.C0)
        end
    end
end

const function weld(Root: BasePart, Attach: BasePart, Offset: CFrame)
    const Joint = Instance.new("Weld")
    Joint.Name = Rig.WeldName
    Joint.Part0 = Attach
    Joint.Part1 = Root
    Joint.C0 = Offset
    Joint.Parent = Root
end

function Rig.bound(Root: Instance): Vector3
    local Biggest = Vector3.zero
    for _, Part in partsIn(Root) do
        const Base = Part:GetAttribute("CustomizeBase")
        Biggest = Biggest:Max(if typeof(Base) == "Vector3" then Base else Part.Size)
    end
    return Biggest
end

function Rig.stretch(Root: Instance, Given: Vector3)
    const Scale = Format.limitScale(Given, Rig.bound(Root))
    for _, Part in partsIn(Root) do
        const Base = Part:GetAttribute("CustomizeBase")
        if typeof(Base) == "Vector3" then
            Part.Size = Base * Scale
        end
        const Mesh = Part:FindFirstChildOfClass("SpecialMesh")
        const MeshBase = if Mesh then Mesh:GetAttribute("CustomizeBase") else nil
        if Mesh and typeof(MeshBase) == "Vector3" then
            Mesh.Scale = MeshBase * Scale
        end
    end
    for _, Item in Root:GetDescendants() do
        const Base = Item:GetAttribute("CustomizeBase")
        if Item:IsA("Weld") and Item.Name == Rig.InnerName and typeof(Base) == "CFrame" then
            Item.C0 = CFrame.new(Base.Position * Scale) * Base.Rotation
        end
    end
end

function Rig.setOffset(Character: Model, Id: string, Offset: CFrame)
    const Root = Rig.rootOf(Rig.find(Character, Id))
    const Joint = if Root then Root:FindFirstChild(Rig.WeldName) else nil
    if Joint and Joint:IsA("Weld") then
        Joint.C0 = Offset
    end
end

function Rig.setScale(Character: Model, Id: string, Scale: Vector3)
    const Made = Rig.find(Character, Id)
    if Made then
        Rig.stretch(Made, Scale)
    end
end

function Rig.clearPart(Character: Model, Id: string)
    const Existing = Rig.find(Character, Id)
    if Existing then
        Existing:Destroy()
    end
end

const function source(Character: Model, Record: LookPart, Resolve: Resolve): Instance?
    if Record.Kind == "Asset" then
        const Found = if Record.Asset then Resolve(Record.Asset) else nil
        const Handle = if Found then Found:FindFirstChild("Handle") else nil
        if not Handle or not Handle:IsA("BasePart") then
            return nil
        end
        const Copy = Handle:Clone()
        stripJoints(Copy)
        return Copy
    elseif Record.Kind == "Builtin" then
        const Definition = Catalog.part(Record.Builtin)
        if not Definition then
            return nil
        end
        const Ok, Built = pcall(Definition.build)
        if not Ok or not Built then
            return nil
        end
        const Piece = Record.Piece
        if not Piece or Built:IsA("BasePart") then
            return Built
        end
        const Found = Built:FindFirstChild(Piece, true)
        const Single = if Found and Found:IsA("BasePart") then Found:Clone() else nil
        Built:Destroy()
        if Single then
            stripJoints(Single)
            for _, Item in Single:GetChildren() do
                if Item:IsA("Weld") and Item.Name == Rig.InnerName then
                    Item:Destroy()
                end
            end
        end
        return Single
    end
    const Accessory = if Record.Target then Character:FindFirstChild(Record.Target) else nil
    const Handle = if Accessory and Accessory:IsA("Accessory") then Accessory:FindFirstChild("Handle") else nil
    if not Handle or not Handle:IsA("BasePart") then
        return nil
    end
    hide(Handle)
    if Record.Removed then
        return nil
    end
    const Copy = Handle:Clone()
    restore(Copy)
    forget(Copy)
    for _, Child in Copy:GetChildren() do
        if Child:IsA("Decal") then
            restore(Child)
            forget(Child)
        end
    end
    stripJoints(Copy)
    return Copy
end

function Rig.factor(Given: Look?, Attach: string): Vector3
    if not Given or not Given.ScaleParts then
        return Vector3.one
    end
    if Attach == "Head" then
        return Vector3.one * (Given.Head or 1)
    end
    return Vector3.new(Given.Width or 1, Given.Height or 1, Given.Depth or 1)
end

function Rig.scaleFrame(Frame: CFrame, Factor: Vector3): CFrame
    return CFrame.new(Frame.Position * Factor) * Frame.Rotation
end

function Rig.applyPart(Character: Model, Record: LookPart, Resolve: Resolve, Given: Look?): Instance?
    Rig.clearPart(Character, Record.Id)
    const Attach = Rig.bodyParts(Character)[Record.Attach]
    if not Attach then
        return nil
    end
    const Made = source(Character, Record, Resolve)
    const Root = Rig.rootOf(Made)
    if not Made or not Root then
        if Made then
            Made:Destroy()
        end
        return nil
    end
    Made.Name = Record.Id
    Made:SetAttribute("CustomizeId", Record.Id)
    settle(Made)
    const Factor = Rig.factor(Given, Record.Attach)
    Rig.stretch(Made, Format.vector(Record.Scale, Vector3.one) * Factor)
    for _, Part in partsIn(Made) do
        paintPart(Part, Record.Color, Record.Material, Record.Texture)
    end
    weld(Root, Attach, Rig.scaleFrame(Format.frame(Record.Offset), Factor))
    Made.Parent = Rig.folder(Character)
    return Made
end

function Rig.applyBody(Character: Model, Given: Look)
    const Holder = Rig.folder(Character)
    for _, Child in Holder:GetChildren() do
        if Child:GetAttribute("CustomizeSwap") then
            Child:Destroy()
        end
    end
    const Parts = Rig.bodyParts(Character)
    for _, Part in Parts do
        restore(Part)
        for _, Child in Part:GetChildren() do
            if Child:IsA("Decal") then
                restore(Child)
            end
        end
    end
    const Colors = Character:FindFirstChildOfClass("BodyColors")
    if Colors then
        restore(Colors)
    end

    const Skin = Format.color(Given.Skin)
    if Skin then
        if Colors then
            keep(Colors)
            for _, Field in BodyFields do
                (Colors :: any)[Field] = Skin
            end
        end
        for _, Part in Parts do
            keep(Part)
            Part.Color = Skin
        end
    end

    for Name, Body in Given.Body do
        const Part = Parts[Name]
        if not Part then
            continue
        end
        keep(Part)
        paintPart(Part, Body.Color, Body.Material, Body.Texture)
        if Body.Hidden then
            hide(Part)
        end
    end

    const Chosen: { [string]: string } = {}
    const Owners: { [string]: string } = {}
    for Key, Name in Given.Swaps do
        const Pieces = Catalog.Limbs[Key]
        if Pieces then
            for _, PieceName in Pieces do
                if not Given.Swaps[PieceName] then
                    Chosen[PieceName] = Name
                    Owners[PieceName] = Key
                end
            end
        elseif Format.isBody(Key) then
            Chosen[Key] = Name
            Owners[Key] = Key
        end
    end
    for PieceName, Name in Chosen do
        const Definition = Catalog.swap(Name)
        const Limb = Owners[PieceName]
        if not Definition then
            continue
        end
        do
            const Piece = Parts[PieceName]
            if not Piece then
                continue
            end
            hide(Piece)
            const Ok, Built = pcall(Definition.build, Piece, PieceName)
            const Root = if Ok then Rig.rootOf(Built) else nil
            if not Ok or not Built or not Root then
                continue
            end
            settle(Built)
            weld(Root, Piece, CFrame.identity)
            Built.Name = `{Limb}_{PieceName}`
            Built:SetAttribute("CustomizeSwap", Limb)
            Built.Parent = Holder
        end
    end
end

function Rig.applyOutfit(Character: Model, Given: Look, Wear: Wear?, Scales: boolean?)
    for Kind, Property in Templates do
        for _, Item in Character:GetChildren() do
            if Item.ClassName ~= Kind then
                continue
            end
            if Item:GetAttribute(Made) then
                Item:Destroy()
            else
                restore(Item)
            end
        end
        const Asset = (Given :: any)[Kind]
        const Template = if type(Asset) == "number" and Wear then Wear(Kind :: Catalog.ClothingKind, Asset) else nil
        if not Template then
            continue
        end
        local Found: Instance? = Character:FindFirstChildOfClass(Kind :: any)
        if not Found then
            const Fresh = Instance.new(Kind :: any)
            Fresh:SetAttribute(Made, true)
            Fresh.Parent = Character
            Found = Fresh
        end
        const Wearing: any = Found
        keep(Wearing)
        Wearing[Property] = Template
    end

    const Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid or Scales == false then
        return
    end
    const Absolute = Humanoid:GetAttribute(Rig.AbsoluteScale) == true
    for Key, Range in Config.Proportions do
        const Factor = (Given :: any)[Key]
        for _, Name in Range.Values do
            const Scale = Humanoid:FindFirstChild(Name)
            if not Scale or not Scale:IsA("NumberValue") then
                continue
            end
            if Absolute then
                keep(Scale)
                Scale.Value = if type(Factor) == "number" then Factor else 1
                continue
            end
            restore(Scale)
            if type(Factor) == "number" then
                keep(Scale)
                const Base = Scale:GetAttribute("CustomizeValue")
                Scale.Value = (if type(Base) == "number" then Base else Scale.Value) * Factor
            end
        end
    end
end

function Rig.clear(Character: Model)
    const Holder = Character:FindFirstChild(Rig.FolderName)
    if Holder then
        Holder:ClearAllChildren()
    end
    for _, Item in Character:GetDescendants() do
        if Item:GetAttribute(Made) then
            Item:Destroy()
        else
            restore(Item)
        end
    end
end

function Rig.apply(Character: Model, Given: Look, Resolve: Resolve, Wear: Wear?, Scales: boolean?)
    Rig.clear(Character)
    Rig.applyBody(Character, Given)
    Rig.applyOutfit(Character, Given, Wear, Scales)
    for _, Record in Given.Parts do
        Rig.applyPart(Character, Record, Resolve, Given)
    end
end

return Rig
