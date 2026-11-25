--!strict
const Workspace = game:GetService("Workspace")

export type Item = {
    Id: number,
    Model: Model,
    Key: string?,
    States: { [string]: any }?,
    StartScale: number,
    Base: number,
}

export type Transform = {
    Item: Item,
    Pivot: CFrame,
    Scale: number,
}

export type Container = {
    Model: Model,
    Highlight: Highlight?,
    Items: { Item },
}

const Container = {
    Highlighted = false,
    FillTransparency = 0.75,
}

const function ghost(Root: Instance)
    for _, Item in Root:GetDescendants() do
        if Item:IsA("BasePart") then
            Item.Anchored = true
            Item.CanCollide = false
            Item.CanTouch = false
            Item.CanQuery = false
        end
    end
end

function Container.new(Name: string?, Color: Color3?): Container
    const Model = Instance.new("Model")
    Model.Name = Name or "PropContainer"

    local Highlight: Highlight? = nil
    if Container.Highlighted then
        const Tint = Color or Color3.new(0, 0, 0)
        const Made = Instance.new("Highlight")
        Made.Name = "ContainerHighlight"
        Made.FillColor = Tint
        Made.OutlineColor = Tint
        Made.FillTransparency = Container.FillTransparency
        Made.OutlineTransparency = 0
        Made.DepthMode = Enum.HighlightDepthMode.Occluded
        Made.Adornee = Model
        Made.Parent = Model
        Highlight = Made
    end

    Model.Parent = Workspace
    return {
        Model = Model,
        Highlight = Highlight,
        Items = {},
    }
end

function Container.add(Self: Container, Id: number, Model: Model, Key: string?, States: { [string]: any }?): Item
    ghost(Model)
    Model.Parent = Self.Model
    const Made: Item = {
        Id = Id,
        Model = Model,
        Key = Key,
        States = States,
        StartScale = Model:GetScale(),
        Base = Self.Model:GetScale(),
    }
    table.insert(Self.Items, Made)
    return Made
end

function Container.fit(Self: Container)
    const Model = Self.Model
    Model.WorldPivot = CFrame.new(Model.WorldPivot.Position)
    const Box, Size = Model:GetBoundingBox()
    Model.WorldPivot = CFrame.new(Box.Position - Vector3.new(0, Size.Y / 2, 0))
end

function Container.transforms(Self: Container): { Transform }
    const Current = Self.Model:GetScale()
    const Made: { Transform } = {}
    for _, Item in Self.Items do
        if Item.Model.Parent ~= Self.Model then
            continue
        end
        table.insert(Made, {
            Item = Item,
            Pivot = Item.Model:GetPivot(),
            Scale = Item.StartScale * Current / Item.Base,
        })
    end
    return Made
end

function Container.destroy(Self: Container)
    table.clear(Self.Items)
    Self.Model:Destroy()
end

return Container
