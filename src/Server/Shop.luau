--!strict
const MarketplaceService = game:GetService("MarketplaceService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const ShopData = require(ReplicatedStorage.Shared.Shop)
const PropConfig = require(ReplicatedStorage.Shared.PropData.Config)
const Props = require(script.Parent.Props)

export type Result = {
    Ok: boolean,
    Error: string?,
    Name: string?,
}

const Shop = {
    PurchaseCache = 100,
    LoadWait = 30,
    GiftKind = "Gift",
}

const Net = NetWatch.Shop
const Profiles: { [Player]: any } = {}
local Store: any = nil
local Started = false

const function fail(Message: string): Result
    return { Ok = false, Error = Message }
end

const function notify(Player: Player, Text: string)
    Net:BroadcastTo(Player, "@Shop/Notice", Text)
end

const function giftsOf(Data: PlayerData): { [string]: ShopGift }
    local Gifts = Data.ShopGifts
    if type(Gifts) ~= "table" then
        Gifts = {}
        Data.ShopGifts = Gifts
    end
    return Gifts :: { [string]: ShopGift }
end

const function give(Player: Player, Data: PlayerData, Item: ShopData.Item)
    if Item.Props then
        const Count = if type(Data.PropCount) == "number" then Data.PropCount else PropConfig.MaxProps
        Data.PropCount = Count + Item.Props
    end
    const Pack = Item.Pack
    if Pack then
        if type(Data.OwnedPacks) ~= "table" then
            Data.OwnedPacks = {}
        end
        Data.OwnedPacks[Pack] = true
    end
    Props.refresh(Player)
end

const function owns(Data: any, Pack: string): boolean
    return type(Data) == "table" and type(Data.OwnedPacks) == "table" and Data.OwnedPacks[Pack] == true
end

const function saved(Profile: any, PurchaseId: string): boolean
    const Last = Profile.LastSavedData
    const Cache = if type(Last) == "table" then Last.PurchaseIds else nil
    return type(Cache) == "table" and table.find(Cache, PurchaseId) ~= nil
end

const function settle(Profile: any, PurchaseId: string, Grant: () -> ()): Enum.ProductPurchaseDecision
    if not Profile:IsActive() then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    const Data = Profile.Data
    if type(Data.PurchaseIds) ~= "table" then
        Data.PurchaseIds = {}
    end
    const Cache: { string } = Data.PurchaseIds
    if not table.find(Cache, PurchaseId) then
        const Ok, Problem = pcall(Grant)
        if not Ok then
            warn(`[Shop] purchase {PurchaseId} failed: {Problem}`)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        while #Cache >= Shop.PurchaseCache do
            table.remove(Cache, 1)
        end
        table.insert(Cache, PurchaseId)
    end
    if saved(Profile, PurchaseId) then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    while Profile:IsActive() do
        const Last = Profile.LastSavedData
        Profile:Save()
        if Profile.LastSavedData == Last then
            Profile.OnAfterSave:Wait()
        end
        if saved(Profile, PurchaseId) then
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
        task.wait()
    end
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

const function sendGift(From: Player, To: number, Id: string): boolean
    const Target = Store
    if not Target then
        return false
    end
    const Ok, Sent = pcall(function()
        return Target:MessageAsync(tostring(To), {
            Kind = Shop.GiftKind,
            Item = Id,
            From = From.UserId,
            FromName = From.Name,
        })
    end)
    return Ok and Sent == true
end

const function profileOf(Player: Player): any
    local Profile = Profiles[Player]
    local Waited = 0
    while not Profile and Player.Parent == Players and Waited < Shop.LoadWait do
        Waited += task.wait(0.5)
        Profile = Profiles[Player]
    end
    return Profile
end

const function receipt(Info: any): Enum.ProductPurchaseDecision
    const Player = Players:GetPlayerByUserId(Info.PlayerId)
    if not Player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    const Profile = profileOf(Player)
    if not Profile then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    const Id, Item = ShopData.byProduct(Info.ProductId)
    if not Id or not Item then
        warn(`[Shop] product {Info.ProductId} is not in the shop`)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    const Data: PlayerData = Profile.Data
    const Key = tostring(Info.ProductId)
    return settle(Profile, tostring(Info.PurchaseId), function()
        const Gifts = giftsOf(Data)
        const Gift = Gifts[Key]
        if Gift and Gift.Item == Id then
            if not sendGift(Player, Gift.To, Id) then
                error("the gift could not be sent")
            end
            Gifts[Key] = nil
            notify(Player, `Your gift of {Item.Name} was sent`)
            return
        end
        give(Player, Data, Item)
        notify(Player, `You got {Item.Name}`)
    end)
end

const function prompt(Player: Player, Item: ShopData.Item): boolean
    const Ok, Problem = pcall(function()
        MarketplaceService:PromptProductPurchase(Player, Item.Product)
    end)
    if not Ok then
        warn(`[Shop] could not prompt {Player.Name}: {Problem}`)
    end
    return Ok
end

const function buy(Player: Player, Id: unknown): Result
    const Profile = Profiles[Player]
    if not Profile then
        return fail("Your data is still loading")
    end
    const Item = ShopData.get(Id)
    if not Item then
        return fail("That item is not in the shop")
    end
    if Item.Product <= 0 then
        return fail("That item is not for sale yet")
    end
    const Pack = Item.Pack
    if Pack and not Item.Props and owns(Profile.Data, Pack) then
        return fail(`You already own the {Pack} pack`)
    end
    giftsOf(Profile.Data)[tostring(Item.Product)] = nil
    if not prompt(Player, Item) then
        return fail("The purchase could not open")
    end
    return { Ok = true }
end

const function gift(Player: Player, Id: unknown, Username: unknown): Result
    const Profile = Profiles[Player]
    if not Profile then
        return fail("Your data is still loading")
    end
    const Item = ShopData.get(Id)
    if not Item then
        return fail("That item is not in the shop")
    end
    if not ShopData.giftable(Item) then
        return fail("That item can not be gifted")
    end
    if Item.Product <= 0 then
        return fail("That item is not for sale yet")
    end
    if type(Username) ~= "string" or #Username < 3 or #Username > ShopData.MaxUsername then
        return fail("Type the username of who it is for")
    end
    const Found, To = pcall(Players.GetUserIdFromNameAsync, Players, Username)
    if not Found or type(To) ~= "number" then
        return fail("No player has that username")
    end
    if To == Player.UserId then
        return fail("Use buy to get it for yourself")
    end
    const Pack = Item.Pack
    if Pack and not Item.Props and Store then
        const Looked, View = pcall(function()
            return Store:GetAsync(tostring(To))
        end)
        if Looked and View and owns(View.Data, Pack) then
            return fail(`They already own the {Pack} pack`)
        end
    end
    const Named, Real = pcall(Players.GetNameFromUserIdAsync, Players, To)
    giftsOf(Profile.Data)[tostring(Item.Product)] = { To = To, Item = Id :: string, Stamp = os.time() }
    if not prompt(Player, Item) then
        return fail("The purchase could not open")
    end
    return { Ok = true, Name = if Named and type(Real) == "string" then Real else Username }
end

function Shop.attach(Player: Player, Profile: any)
    if Profiles[Player] then
        return
    end
    Profiles[Player] = Profile
    giftsOf(Profile.Data)
    Profile:MessageHandler(function(Message: any, Processed: () -> ())
        if type(Message) ~= "table" or Message.Kind ~= Shop.GiftKind then
            return
        end
        const Item = ShopData.get(Message.Item)
        if Item and Profile:IsActive() then
            give(Player, Profile.Data, Item)
            const From = if type(Message.FromName) == "string" then Message.FromName else "someone"
            notify(Player, `{From} gifted you {Item.Name}`)
        end
        Processed()
    end)
end

function Shop.detach(Player: Player)
    Profiles[Player] = nil
end

function Shop.start(Given: any)
    if Started then
        return
    end
    Started = true
    Store = Given
    MarketplaceService.ProcessReceipt = receipt
    MarketplaceService.PromptProductPurchaseFinished:Connect(function(UserId: number, Product: number, Purchased: boolean)
        if Purchased then
            return
        end
        const Player = Players:GetPlayerByUserId(UserId)
        const Profile = if Player then Profiles[Player] else nil
        if Profile then
            giftsOf(Profile.Data)[tostring(Product)] = nil
        end
    end)
    Net:When("@Shop/Buy", buy)
    Net:When("@Shop/Gift", gift)
    Players.PlayerRemoving:Connect(Shop.detach)
end

return Shop
