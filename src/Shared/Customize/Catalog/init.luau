--!strict
const Build = require(script.Build)

export type Built = Build.Built

export type PartDef = {
    Name: string,
    Order: number?,
    Attach: string,
    Offset: CFrame?,
    build: () -> Built,
}

export type SwapDef = {
    Name: string,
    Limbs: { string },
    build: (Piece: BasePart, PieceName: string) -> Built?,
}

export type AnimationDef = {
    Name: string,
    Order: number?,
}

export type ClothingKind = "Shirt" | "Pants"

export type ClothingDef = {
    Name: string,
    Kind: ClothingKind,
    Asset: number,
    Order: number?,
}

export type Parts = { [string]: PartDef }
export type Swaps = { [string]: SwapDef }
export type Animations = { [string]: AnimationDef }
export type Clothes = { [string]: ClothingDef }

const Catalog = {
    Build = Build,
    BodyParts = {
        "Head",
        "UpperTorso",
        "LowerTorso",
        "LeftUpperArm",
        "LeftLowerArm",
        "LeftHand",
        "RightUpperArm",
        "RightLowerArm",
        "RightHand",
        "LeftUpperLeg",
        "LeftLowerLeg",
        "LeftFoot",
        "RightUpperLeg",
        "RightLowerLeg",
        "RightFoot",
    },
    Limbs = {
        Head = { "Head" },
        Torso = { "UpperTorso", "LowerTorso" },
        LeftArm = { "LeftUpperArm", "LeftLowerArm", "LeftHand" },
        RightArm = { "RightUpperArm", "RightLowerArm", "RightHand" },
        LeftLeg = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
        RightLeg = { "RightUpperLeg", "RightLowerLeg", "RightFoot" },
    } :: { [string]: { string } },
}

const PartList: Parts = {}
const SwapList: Swaps = {}
const AnimationList: Animations = {}
const ClothingList: Clothes = {}
local Loaded = false

function Catalog.addPart(Id: string, Definition: PartDef): boolean
    if type(Id) ~= "string" or Id == "" then
        warn("[Customize] built in part ids must be non empty strings")
        return false
    end
    if PartList[Id] then
        warn(`[Customize] built in part "{Id}" is defined more than once`)
        return false
    end
    if type(Definition) ~= "table" or type(Definition.Name) ~= "string" or type(Definition.build) ~= "function" then
        warn(`[Customize] built in part "{Id}" needs a Name and a build function`)
        return false
    end
    if not table.find(Catalog.BodyParts, Definition.Attach) then
        warn(`[Customize] built in part "{Id}" attaches to "{tostring(Definition.Attach)}" which is not a body part`)
        return false
    end
    PartList[Id] = Definition
    return true
end

function Catalog.addSwap(Id: string, Definition: SwapDef): boolean
    if type(Id) ~= "string" or Id == "" then
        warn("[Customize] swap ids must be non empty strings")
        return false
    end
    if SwapList[Id] then
        warn(`[Customize] swap "{Id}" is defined more than once`)
        return false
    end
    if type(Definition) ~= "table" or type(Definition.Name) ~= "string" or type(Definition.build) ~= "function" or type(Definition.Limbs) ~= "table" then
        warn(`[Customize] swap "{Id}" needs a Name, a Limbs list and a build function`)
        return false
    end
    for _, Limb in Definition.Limbs do
        if not Catalog.Limbs[Limb] then
            warn(`[Customize] swap "{Id}" lists "{tostring(Limb)}" which is not a limb`)
            return false
        end
    end
    SwapList[Id] = Definition
    return true
end

function Catalog.addAnimation(Id: string, Definition: AnimationDef): boolean
    if type(Id) ~= "string" or Id == "" or AnimationList[Id] then
        warn(`[Customize] animation set "{tostring(Id)}" is missing or defined more than once`)
        return false
    end
    if type(Definition) ~= "table" or type(Definition.Name) ~= "string" then
        warn(`[Customize] animation set "{Id}" needs a Name`)
        return false
    end
    AnimationList[Id] = Definition
    return true
end

function Catalog.addClothing(Id: string, Definition: ClothingDef): boolean
    if type(Id) ~= "string" or Id == "" or ClothingList[Id] then
        warn(`[Customize] clothing "{tostring(Id)}" is missing or defined more than once`)
        return false
    end
    if type(Definition) ~= "table" or type(Definition.Name) ~= "string" then
        warn(`[Customize] clothing "{Id}" needs a Name`)
        return false
    end
    if Definition.Kind ~= "Shirt" and Definition.Kind ~= "Pants" then
        warn(`[Customize] clothing "{Id}" needs a Kind of Shirt or Pants`)
        return false
    end
    if type(Definition.Asset) ~= "number" or Definition.Asset <= 0 then
        warn(`[Customize] clothing "{Id}" needs an Asset id`)
        return false
    end
    ClothingList[Id] = Definition
    return true
end

const function modulesIn(Name: string): { ModuleScript }
    const Folder = script:FindFirstChild(Name)
    const Found: { ModuleScript } = {}
    if not Folder then
        return Found
    end
    for _, Item in Folder:GetDescendants() do
        if Item:IsA("ModuleScript") then
            table.insert(Found, Item)
        end
    end
    table.sort(Found, function(A: ModuleScript, B: ModuleScript): boolean
        return A:GetFullName() < B:GetFullName()
    end)
    return Found
end

const function loadFolder(Name: string, Add: (Id: string, Definition: any) -> boolean)
    for _, Module in modulesIn(Name) do
        const Ok, Result = pcall((require :: any), Module)
        if not Ok then
            warn(`[Customize] {Module:GetFullName()} failed to load: {Result}`)
            continue
        end
        if type(Result) ~= "table" then
            warn(`[Customize] {Module:GetFullName()} must return a table of definitions`)
            continue
        end
        for Id, Definition in Result do
            Add(Id, Definition)
        end
    end
end

const function load()
    if Loaded then
        return
    end
    Loaded = true
    loadFolder("Parts", Catalog.addPart)
    loadFolder("Swaps", Catalog.addSwap)
    loadFolder("Animations", Catalog.addAnimation)
    loadFolder("Clothes", Catalog.addClothing)
end

function Catalog.part(Id: string?): PartDef?
    if not Id then
        return nil
    end
    load()
    return PartList[Id]
end

function Catalog.swap(Id: string?): SwapDef?
    if not Id then
        return nil
    end
    load()
    return SwapList[Id]
end

function Catalog.parts(): Parts
    load()
    return PartList
end

function Catalog.swaps(): Swaps
    load()
    return SwapList
end

function Catalog.animation(Id: string?): AnimationDef?
    if not Id then
        return nil
    end
    load()
    return AnimationList[Id]
end

function Catalog.animations(): Animations
    load()
    return AnimationList
end

function Catalog.clothing(Id: string?): ClothingDef?
    if not Id then
        return nil
    end
    load()
    return ClothingList[Id]
end

function Catalog.clothes(): Clothes
    load()
    return ClothingList
end

function Catalog.preset(Kind: ClothingKind, Asset: number): string?
    load()
    for Id, Definition in ClothingList do
        if Definition.Kind == Kind and Definition.Asset == Asset then
            return Id
        end
    end
    return nil
end

function Catalog.sorted<T>(List: { [string]: T & { Name: string, Order: number? } }): { string }
    const Ids: { string } = {}
    for Id in List do
        table.insert(Ids, Id)
    end
    table.sort(Ids, function(A: string, B: string): boolean
        const First = List[A]
        const Second = List[B]
        const OrderA = First.Order or 0
        const OrderB = Second.Order or 0
        if OrderA ~= OrderB then
            return OrderA < OrderB
        end
        return First.Name < Second.Name
    end)
    return Ids
end

return Catalog
