--!strict
export type Built = BasePart | Model

export type Piece = {
    Part: BasePart,
    Offset: CFrame,
}

const Build = {
    InnerName = "CustomizeInner",
}

function Build.part(Name: string, Size: Vector3, Color: Color3, Material: Enum.Material?, Shape: Enum.PartType?): Part
    const Made = Instance.new("Part")
    Made.Name = Name
    Made.Shape = Shape or Enum.PartType.Block
    Made.Size = Size
    Made.Color = Color
    Made.Material = Material or Enum.Material.SmoothPlastic
    Made.TopSurface = Enum.SurfaceType.Smooth
    Made.BottomSurface = Enum.SurfaceType.Smooth
    Made.Anchored = false
    Made.CanCollide = false
    Made.CanTouch = false
    Made.Massless = true
    return Made
end

function Build.ball(Name: string, Diameter: number, Color: Color3, Material: Enum.Material?): Part
    return Build.part(Name, Vector3.one * Diameter, Color, Material, Enum.PartType.Ball)
end

function Build.cylinder(Name: string, Length: number, Diameter: number, Color: Color3, Material: Enum.Material?): Part
    return Build.part(Name, Vector3.new(Length, Diameter, Diameter), Color, Material, Enum.PartType.Cylinder)
end

function Build.piece(Part: BasePart, Offset: CFrame): Piece
    return { Part = Part, Offset = Offset }
end

function Build.model(Name: string, Root: BasePart, Pieces: { Piece }?): Model
    const Made = Instance.new("Model")
    Made.Name = Name
    Root.Parent = Made
    Made.PrimaryPart = Root
    for _, Entry in Pieces or {} do
        const Weld = Instance.new("Weld")
        Weld.Name = Build.InnerName
        Weld.Part0 = Root
        Weld.Part1 = Entry.Part
        Weld.C0 = Entry.Offset
        Weld.Parent = Entry.Part
        Entry.Part.Parent = Made
    end
    return Made
end

function Build.fromTemplate(Template: Instance): Built?
    const Copy = Template:Clone()
    if not Copy then
        return nil
    end
    if Copy:IsA("BasePart") then
        return Copy
    end
    if Copy:IsA("Model") then
        const Root = Copy.PrimaryPart or Copy:FindFirstChildWhichIsA("BasePart", true)
        if not Root then
            Copy:Destroy()
            return nil
        end
        Copy.PrimaryPart = Root
        for _, Item in Copy:GetDescendants() do
            if Item:IsA("BasePart") and Item ~= Root then
                const Weld = Instance.new("Weld")
                Weld.Name = Build.InnerName
                Weld.Part0 = Root
                Weld.Part1 = Item
                Weld.C0 = Root.CFrame:ToObjectSpace(Item.CFrame)
                Weld.Parent = Item
            end
        end
        return Copy
    end
    Copy:Destroy()
    return nil
end

return Build
