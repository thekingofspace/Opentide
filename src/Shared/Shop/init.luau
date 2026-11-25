--!strict
const MarketplaceService = game:GetService("MarketplaceService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)

export type Item = {
    Name: string,
    Description: string?,
    Product: number,
    Props: number?,
    Pack: string?,
    Gift: boolean?,
    Order: number?,
    Preview: { number }?,
    Image: string?,
}

export type Items = { [string]: Item }

const Shop = {
    MaxUsername = 20,
}

const List: Items = {}
const Prices: { [number]: number } = {}
local Loaded = false
local Started = false

function Shop.add(Id: string, Given: Item): boolean
    if type(Id) ~= "string" or Id == "" or List[Id] then
        warn(`[Shop] "{tostring(Id)}" is missing or defined more than once`)
        return false
    end
    if type(Given) ~= "table" or type(Given.Name) ~= "string" then
        warn(`[Shop] "{Id}" needs a Name`)
        return false
    end
    if type(Given.Product) ~= "number" or Given.Product < 0 then
        warn(`[Shop] "{Id}" needs a Product id, use 0 until it has one`)
        return false
    end
    if Given.Props == nil and Given.Pack == nil then
        warn(`[Shop] "{Id}" needs Props or a Pack to give`)
        return false
    end
    if Given.Props ~= nil and (type(Given.Props) ~= "number" or Given.Props <= 0) then
        warn(`[Shop] "{Id}" Props must be a number above 0`)
        return false
    end
    if Given.Pack ~= nil and type(Given.Pack) ~= "string" then
        warn(`[Shop] "{Id}" Pack must be a pack name`)
        return false
    end
    List[Id] = Given
    return true
end

const function load()
    if Loaded then
        return
    end
    Loaded = true
    const Folder = script:FindFirstChild("Items")
    if not Folder then
        return
    end
    const Modules: { ModuleScript } = {}
    for _, Item in Folder:GetDescendants() do
        if Item:IsA("ModuleScript") then
            table.insert(Modules, Item)
        end
    end
    table.sort(Modules, function(A: ModuleScript, B: ModuleScript): boolean
        return A:GetFullName() < B:GetFullName()
    end)
    for _, Module in Modules do
        const Ok, Result = pcall((require :: any), Module)
        if not Ok or type(Result) ~= "table" then
            warn(`[Shop] {Module:GetFullName()} failed to load: {if Ok then "it must return a table" else Result}`)
            continue
        end
        for Id, Given in Result do
            Shop.add(Id, Given)
        end
    end
end

function Shop.list(): Items
    load()
    return List
end

function Shop.get(Id: unknown): Item?
    load()
    return if type(Id) == "string" then List[Id] else nil
end

function Shop.sorted(): { string }
    load()
    const Ids: { string } = {}
    for Id in List do
        table.insert(Ids, Id)
    end
    table.sort(Ids, function(A: string, B: string): boolean
        const First = List[A]
        const Second = List[B]
        if (First.Order or 0) ~= (Second.Order or 0) then
            return (First.Order or 0) < (Second.Order or 0)
        end
        return First.Name < Second.Name
    end)
    return Ids
end

function Shop.byProduct(Product: number): (string?, Item?)
    load()
    for Id, Given in List do
        if Given.Product == Product and Product > 0 then
            return Id, Given
        end
    end
    return nil, nil
end

function Shop.giftable(Given: Item): boolean
    return Given.Gift ~= false
end

function Shop.reward(Given: Item): string
    const Parts: { string } = {}
    if Given.Props then
        table.insert(Parts, `+{Given.Props} props`)
    end
    if Given.Pack then
        table.insert(Parts, "unlocks a pack")
    end
    return table.concat(Parts, " and ")
end

function Shop.known(Given: Item): number?
    return Prices[Given.Product]
end

function Shop.price(Given: Item): number?
    if Given.Product <= 0 then
        return nil
    end
    const Known = Prices[Given.Product]
    if Known then
        return Known
    end
    const Ok, Info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, Given.Product, Enum.InfoType.Product)
    const Price = if Ok and type(Info) == "table" then (Info :: any).PriceInRobux else nil
    if type(Price) == "number" then
        Prices[Given.Product] = Price
        return Price
    end
    return nil
end

const function answer(Reply: any): (boolean, string?, string?)
    if type(Reply) ~= "table" then
        return false, "The server did not answer", nil
    end
    if not Reply.Ok then
        return false, if type(Reply.Error) == "string" then Reply.Error else "That did not work", nil
    end
    return true, nil, if type(Reply.Name) == "string" then Reply.Name else nil
end

function Shop.buy(Id: string): (boolean, string?)
    const Ok, Problem = answer(NetWatch.Shop:Call("@Shop/Buy", Id))
    return Ok, Problem
end

function Shop.gift(Id: string, Username: string): (boolean, string?, string?)
    return answer(NetWatch.Shop:Call("@Shop/Gift", Id, Username))
end

function Shop.start(Notify: (Text: string) -> ())
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    NetWatch.Shop:On("@Shop/Notice", function(Text: unknown)
        if type(Text) == "string" then
            Notify(Text)
        end
    end)
end

return Shop
