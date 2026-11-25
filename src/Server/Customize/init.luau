--!strict
const DataStoreService = game:GetService("DataStoreService")
const InsertService = game:GetService("InsertService")
const MarketplaceService = game:GetService("MarketplaceService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TextService = game:GetService("TextService")
const Workspace = game:GetService("Workspace")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Config = require(ReplicatedStorage.Shared.Customize.Config)
const Catalog = require(ReplicatedStorage.Shared.Customize.Catalog)
const Format = require(ReplicatedStorage.Shared.Customize.Format)
const Rig = require(ReplicatedStorage.Shared.Customize.Rig)
const Room = require(script.Room)
const Avatar = require(script.Parent.Avatar)
const Tools = require(script.Parent.Tools)

export type Result = {
    Ok: boolean,
    Error: string?,
    Look: Look?,
    Save: LookSave?,
    Room: CFrame?,
    Template: string?,
    Code: string?,
    Share: { Name: string, Parts: { LookPart } }?,
    Skipped: number?,
}

type Session = {
    Ghost: Model,
    Origin: CFrame,
    Character: Model,
}

type Owner = {
    Player: Player,
    Data: PlayerData,
    Stamp: number,
    Link: RBXScriptConnection?,
    Session: Look?,
    Shared: number,
    Imported: number,
}

const Customize = {
    PartWait = 10,
    AppearanceWait = 15,
    ShareStore = "CustomizeShares",
    ShareLength = 7,
    ShareAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789",
    ShareCooldown = 10,
    ImportCooldown = 2,
    ShareTries = 5,
    ImageProbe = 6,
}

const AccessoryFields: { [number]: string } = {
    [8] = "HatAccessory",
    [41] = "HairAccessory",
    [42] = "FaceAccessory",
    [43] = "NeckAccessory",
    [44] = "ShouldersAccessory",
    [45] = "FrontAccessory",
    [46] = "BackAccessory",
    [47] = "WaistAccessory",
}

const Net = NetWatch.Customize
const Owners: { [Player]: Owner } = {}
const Loaded: { [number]: Instance } = {}
const Failed: { [number]: string } = {}
const Waiting: { [number]: { thread } } = {}
const Sessions: { [Player]: Session } = {}
const Clothing: { [string]: string } = {}
const ClothingFailed: { [string]: string } = {}
const ClothingWaiting: { [string]: { thread } } = {}
const ClothingTypes: { [string]: number } = { Shirt = 11, Pants = 12 }
const Textures: { [number]: string } = {}
const ImageType = 1
const DecalType = 13
local Holder: Folder? = nil
local Ghosts: Folder? = nil
local Started = false

const function fail(Message: string): Result
    return { Ok = false, Error = Message }
end

const function folder(): Folder
    const Existing = Holder
    if Existing and Existing.Parent then
        return Existing
    end
    const Made = Instance.new("Folder")
    Made.Name = Config.AssetFolder
    Made.Parent = ReplicatedStorage
    Holder = Made
    return Made
end

const function clean(Accessory: Instance)
    for _, Item in Accessory:GetDescendants() do
        if Item:IsA("LuaSourceContainer") or Item:IsA("JointInstance") or Item:IsA("WeldConstraint") or Item:IsA("RigidConstraint") then
            Item:Destroy()
        end
    end
end

const function fromInsert(AssetId: number): Instance?
    const Ok, Model = pcall(InsertService.LoadAsset, InsertService, AssetId)
    if not Ok or not Model then
        return nil
    end
    const Found = Model:FindFirstChildWhichIsA("Accessory", true)
    if Found then
        Found.Parent = nil
    end
    Model:Destroy()
    return Found
end

const function fromDescription(AssetId: number): Instance?
    const Ok, Info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, AssetId, Enum.InfoType.Asset)
    if not Ok or type(Info) ~= "table" then
        return nil
    end
    const Field = AccessoryFields[(Info :: any).AssetTypeId]
    if not Field then
        return nil
    end
    const Description = Instance.new("HumanoidDescription")
    const Loose: any = Description
    Loose[Field] = tostring(AssetId)
    const Made, Dummy = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, Description, Enum.HumanoidRigType.R15, Enum.AssetTypeVerification.Default)
    Description:Destroy()
    if not Made or not Dummy then
        return nil
    end
    const Found = Dummy:FindFirstChildWhichIsA("Accessory")
    if Found then
        Found.Parent = nil
    end
    Dummy:Destroy()
    return Found
end

function Customize.loadAsset(AssetId: number): (Instance?, string?)
    const Known = Loaded[AssetId]
    if Known and Known.Parent then
        return Known, nil
    end
    if Failed[AssetId] then
        return nil, Failed[AssetId]
    end
    const Queue = Waiting[AssetId]
    if Queue then
        table.insert(Queue, coroutine.running())
        coroutine.yield()
        return Loaded[AssetId], Failed[AssetId]
    end
    Waiting[AssetId] = {}

    const Found = fromInsert(AssetId) or fromDescription(AssetId)
    const Handle = if Found then Found:FindFirstChild("Handle") else nil
    if Found and Found:IsA("Accessory") and Handle and Handle:IsA("BasePart") then
        clean(Found)
        Found:SetAttribute("CustomizeOriginal", Found.Name)
        Found.Name = tostring(AssetId)
        Found.Parent = folder()
        Loaded[AssetId] = Found
    else
        if Found then
            Found:Destroy()
        end
        Failed[AssetId] = `Item {AssetId} is not an accessory that can be worn`
    end

    const Sleepers = Waiting[AssetId]
    Waiting[AssetId] = nil
    for _, Thread in Sleepers do
        task.spawn(Thread)
    end
    return Loaded[AssetId], Failed[AssetId]
end

const function resolve(AssetId: number): Instance?
    return Loaded[AssetId]
end

const function templateOf(Root: Instance?, Kind: Catalog.ClothingKind): string?
    if not Root then
        return nil
    end
    const Found = if Root.ClassName == Kind then Root else Root:FindFirstChildOfClass(Kind :: any)
    if not Found then
        return nil
    end
    const Template = if Kind == "Shirt" then (Found :: Shirt).ShirtTemplate else (Found :: Pants).PantsTemplate
    return if Template ~= "" then Template else nil
end

const function clothingFromInsert(Kind: Catalog.ClothingKind, AssetId: number): string?
    const Ok, Model = pcall(InsertService.LoadAsset, InsertService, AssetId)
    if not Ok or not Model then
        return nil
    end
    const Template = templateOf(Model, Kind)
    Model:Destroy()
    return Template
end

const function clothingFromDescription(Kind: Catalog.ClothingKind, AssetId: number): string?
    const Ok, Info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, AssetId, Enum.InfoType.Asset)
    if not Ok or type(Info) ~= "table" or (Info :: any).AssetTypeId ~= ClothingTypes[Kind] then
        return nil
    end
    const Description = Instance.new("HumanoidDescription")
    const Loose: any = Description
    Loose[Kind] = AssetId
    const Made, Dummy = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, Description, Enum.HumanoidRigType.R15, Enum.AssetTypeVerification.Default)
    Description:Destroy()
    if not Made or not Dummy then
        return nil
    end
    const Template = templateOf(Dummy, Kind)
    Dummy:Destroy()
    return Template
end

function Customize.loadClothing(Kind: Catalog.ClothingKind, AssetId: number): (string?, string?)
    const Key = `{Kind}{AssetId}`
    if Clothing[Key] then
        return Clothing[Key], nil
    end
    if ClothingFailed[Key] then
        return nil, ClothingFailed[Key]
    end
    const Queue = ClothingWaiting[Key]
    if Queue then
        table.insert(Queue, coroutine.running())
        coroutine.yield()
        return Clothing[Key], ClothingFailed[Key]
    end
    ClothingWaiting[Key] = {}
    const Template = clothingFromInsert(Kind, AssetId) or clothingFromDescription(Kind, AssetId)
    if Template then
        Clothing[Key] = Template
    else
        ClothingFailed[Key] = `Item {AssetId} is not classic {if Kind == "Shirt" then "shirt" else "pants"}`
    end
    const Sleepers = ClothingWaiting[Key]
    ClothingWaiting[Key] = nil
    for _, Thread in Sleepers do
        task.spawn(Thread)
    end
    return Clothing[Key], ClothingFailed[Key]
end

const function wear(Kind: Catalog.ClothingKind, AssetId: number): string?
    return Clothing[`{Kind}{AssetId}`]
end

const function preload(Given: Look): string?
    for _, AssetId in Format.assets(Given) do
        const Found, Problem = Customize.loadAsset(AssetId)
        if not Found then
            return Problem or `Item {AssetId} could not load`
        end
    end
    for _, Kind in { "Shirt", "Pants" } :: { Catalog.ClothingKind } do
        const AssetId = (Given :: any)[Kind]
        if type(AssetId) == "number" then
            const Template, Problem = Customize.loadClothing(Kind, AssetId)
            if not Template then
                return Problem
            end
        end
    end
    return nil
end

const function waitForBody(Character: Model): boolean
    for _, Name in Catalog.BodyParts do
        if not Character:WaitForChild(Name, Customize.PartWait) then
            return false
        end
    end
    return true
end

function Customize.applyTo(Player: Player, Given: Look?)
    const Character = Player.Character
    if not Character or not Character.Parent then
        return
    end
    if Given then
        const Problem = preload(Given)
        if Problem then
            warn(`[Customize] {Player.Name}: {Problem}`)
        end
    end
    if Player.Character ~= Character then
        return
    end
    if Avatar.Enabled then
        Avatar.force(Character, Given)
        if Player.Character ~= Character or not waitForBody(Character) then
            return
        end
    end
    Rig.apply(Character, Given or Format.empty(), resolve, wear, not Avatar.Enabled)
end

const function waitForAppearance(Player: Player)
    if Player:HasAppearanceLoaded() then
        return
    end
    const Thread = coroutine.running()
    local Done = false
    const function resume()
        if not Done then
            Done = true
            task.spawn(Thread)
        end
    end
    const Link = Player.CharacterAppearanceLoaded:Connect(resume)
    const Timer = task.delay(Customize.AppearanceWait, resume)
    coroutine.yield()
    Link:Disconnect()
    if coroutine.status(Timer) == "suspended" then
        task.cancel(Timer)
    end
end

const function onCharacter(Player: Player, Character: Model)
    waitForAppearance(Player)
    if not waitForBody(Character) then
        return
    end
    task.wait()
    const Owner = Owners[Player]
    if Owner and Player.Character == Character then
        Customize.applyTo(Player, Owner.Session)
    end
end

const function slotOf(Slot: unknown): string?
    if type(Slot) ~= "number" or Slot ~= math.floor(Slot) or Slot < 1 or Slot > Config.SaveSlots then
        return nil
    end
    return tostring(Slot)
end

const function nameFor(Player: Player, Given: unknown, Slot: string): string
    const Fallback = `Look {Slot}`
    if type(Given) ~= "string" or Given == "" then
        return Fallback
    end
    const Trimmed = string.sub(Given, 1, Config.MaxName)
    const Ok, Filtered = pcall(function()
        const Result = TextService:FilterStringAsync(Trimmed, Player.UserId)
        return Result:GetNonChatStringForUserAsync(Player.UserId)
    end)
    return if Ok and type(Filtered) == "string" and Filtered ~= "" then Filtered else Fallback
end

const function push(Owner: Owner)
    Net:BroadcastTo(Owner.Player, "@Customize/State", {
        Look = Owner.Session,
        Saves = Owner.Data.LookSaves,
    })
end

const function fetchClothing(Player: Player, Kind: unknown, Raw: unknown): Result
    if not Owners[Player] then
        return fail("Your data is still loading")
    end
    if Kind ~= "Shirt" and Kind ~= "Pants" then
        return fail("Only shirts and pants can be worn")
    end
    const AssetId = Format.assetId(Raw)
    if not AssetId then
        return fail("That item id is not valid")
    end
    if not Format.clothingAllowed(Kind, AssetId) then
        return fail("Pick one of the clothes from the list")
    end
    const Template, Problem = Customize.loadClothing(Kind, AssetId)
    if not Template then
        return fail(Problem or "That item could not load")
    end
    return { Ok = true, Template = Template }
end

const function imageOf(Value: string): string?
    const Digits = string.match(Value, "id=(%d+)") or string.match(Value, "rbxassetid://(%d+)") or string.match(Value, "^(%d+)$")
    return if Digits then `rbxassetid://{Digits}` else nil
end

const function resolveTexture(Player: Player, Raw: unknown): Result
    if not Owners[Player] then
        return fail("Your data is still loading")
    end
    const AssetId = Format.assetId(Raw)
    if not AssetId then
        return fail("That id is not valid")
    end
    const Known = Textures[AssetId]
    if Known then
        return { Ok = true, Template = Known }
    end
    const Ok, Info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, AssetId, Enum.InfoType.Asset)
    const Kind = if Ok and type(Info) == "table" then (Info :: any).AssetTypeId else nil
    local Image: string? = nil
    if Kind == ImageType then
        Image = `rbxassetid://{AssetId}`
    elseif Kind == DecalType or Kind == nil then
        const Loaded, Model = pcall(InsertService.LoadAsset, InsertService, AssetId)
        if Loaded and Model then
            const Found = Model:FindFirstChildWhichIsA("Decal", true)
            if Found then
                Image = imageOf(Found.Texture)
            end
            Model:Destroy()
        end
    end
    if not Image and Kind == DecalType then
        const Creator = if type(Info) == "table" and type((Info :: any).Creator) == "table" then (Info :: any).Creator.Id else nil
        for Step = 1, Customize.ImageProbe do
            const Found, Near = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, AssetId - Step, Enum.InfoType.Asset)
            const Near2: any = if Found then Near else nil
            if type(Near2) == "table" and Near2.AssetTypeId == ImageType and (Creator == nil or type(Near2.Creator) ~= "table" or Near2.Creator.Id == Creator) then
                Image = `rbxassetid://{AssetId - Step}`
                break
            end
        end
    end
    if not Image then
        return fail("That is not an image or a decal that can be used")
    end
    Textures[AssetId] = Image
    return { Ok = true, Template = Image }
end

const function renameLook(Player: Player, Slot: unknown, Name: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const Key = slotOf(Slot)
    const Save = if Key then Owner.Data.LookSaves[Key] else nil
    if not Key or not Save then
        return fail("That save slot is empty")
    end
    Save.Name = nameFor(Player, Name, Key)
    return { Ok = true, Save = Save }
end

const Rng = Random.new()
local Shares: DataStore? = nil

const function shareStore(): DataStore
    const Known = Shares
    if Known then
        return Known
    end
    const Made = DataStoreService:GetDataStore(Customize.ShareStore)
    Shares = Made
    return Made
end

const function publicName(Player: Player, Given: unknown): string?
    const Clean = Format.cleanName(Given)
    if not Clean then
        return nil
    end
    const Ok, Filtered = pcall(function()
        const Result = TextService:FilterStringAsync(Clean, Player.UserId)
        return Result:GetNonChatStringForBroadcastAsync()
    end)
    return if Ok and type(Filtered) == "string" and Filtered ~= "" then Filtered else nil
end

const function newCode(): string
    const Letters: { string } = {}
    const Alphabet = Customize.ShareAlphabet
    for Index = 1, Customize.ShareLength do
        const Pick = Rng:NextInteger(1, #Alphabet)
        Letters[Index] = string.sub(Alphabet, Pick, Pick)
    end
    return table.concat(Letters)
end

const function cleanCode(Given: unknown): string?
    if type(Given) ~= "string" then
        return nil
    end
    const Code = string.upper((string.gsub(Given, "[%s%-]", "")))
    if #Code ~= Customize.ShareLength then
        return nil
    end
    for Index = 1, #Code do
        if not string.find(Customize.ShareAlphabet, string.sub(Code, Index, Index), 1, true) then
            return nil
        end
    end
    return Code
end

const function avatarAssets(Player: Player): { [string]: number }
    const Found: { [string]: number } = {}
    const Character = Player.Character
    const Humanoid = if Character then Character:FindFirstChildOfClass("Humanoid") else nil
    if not Humanoid then
        return Found
    end
    const Ok, Description = pcall(function()
        return Humanoid:GetAppliedDescription()
    end)
    if not Ok or not Description then
        return Found
    end
    const Listed, Accessories = pcall(function()
        return Description:GetAccessories(true)
    end)
    if not Listed or type(Accessories) ~= "table" then
        return Found
    end
    for _, Info in Accessories do
        const AssetId = if type(Info) == "table" then Info.AssetId else nil
        if type(AssetId) ~= "number" then
            continue
        end
        const Loaded = Customize.loadAsset(AssetId)
        const Original = if Loaded then Loaded:GetAttribute("CustomizeOriginal") else nil
        if type(Original) == "string" then
            Found[Original] = AssetId
        end
    end
    return Found
end

const function convertDefaults(Player: Player, Parts: { LookPart }): ({ LookPart }, number)
    local Lookup: { [string]: number }? = nil
    const Made: { LookPart } = {}
    local Skipped = 0
    for _, Record in Parts do
        if Record.Kind ~= "Default" then
            table.insert(Made, Record)
            continue
        end
        if Record.Removed or not Record.Target then
            Skipped += 1
            continue
        end
        if not Lookup then
            Lookup = avatarAssets(Player)
        end
        const AssetId = (Lookup :: { [string]: number })[Record.Target]
        if not AssetId then
            Skipped += 1
            continue
        end
        Record.Kind = "Asset"
        Record.Asset = AssetId
        Record.Target = nil
        Record.Removed = nil
        table.insert(Made, Record)
    end
    return Made, Skipped
end

const function cleanShare(Parts: unknown): { LookPart }?
    const Clean = Format.sanitize({ Version = Config.LookVersion, Parts = Parts })
    if not Clean then
        return nil
    end
    const Kept: { LookPart } = {}
    for _, Record in Clean.Parts do
        if Record.Kind ~= "Default" then
            Record.Group = nil
            table.insert(Kept, Record)
        end
    end
    return if #Kept > 0 then Kept else nil
end

const function shareGroup(Player: Player, Name: unknown, Parts: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const Now = os.clock()
    if Now - Owner.Shared < Customize.ShareCooldown then
        return fail("Wait a few seconds before sharing again")
    end
    const Clean = Format.sanitize({ Version = Config.LookVersion, Parts = Parts })
    if not Clean or #Clean.Parts == 0 then
        return fail("That group has nothing to share")
    end
    Owner.Shared = Now
    const Kept, Skipped = convertDefaults(Player, Clean.Parts)
    for _, Record in Kept do
        Record.Group = nil
    end
    if #Kept == 0 then
        return fail("None of those parts could be shared")
    end
    for _, Record in Kept do
        Record.Name = if Record.Name then publicName(Player, Record.Name) else nil
    end
    const Payload = {
        Name = publicName(Player, Name) or "shared group",
        Parts = Kept,
        Owner = Player.UserId,
        Stamp = os.time(),
    }
    const Store = shareStore()
    for _ = 1, Customize.ShareTries do
        const Code = newCode()
        const Ok, Saved = pcall(function()
            return Store:UpdateAsync(Code, function(Old: any)
                if Old ~= nil then
                    return nil
                end
                return Payload
            end)
        end)
        if Ok and Saved ~= nil then
            return { Ok = true, Code = Code, Skipped = Skipped }
        end
        if not Ok then
            warn(`[Customize] share failed: {Saved}`)
            return fail("Share codes are not working right now")
        end
    end
    return fail("A code could not be made, try again")
end

const function unshare(Player: Player, Given: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const Code = cleanCode(Given)
    if not Code then
        return fail("That code is not valid")
    end
    const Store = shareStore()
    const Ok, Data = pcall(function()
        return Store:GetAsync(Code)
    end)
    if not Ok then
        return fail("Share codes are not working right now")
    end
    if type(Data) ~= "table" then
        return { Ok = true }
    end
    if (Data :: any).Owner ~= Player.UserId then
        return fail("Only the player who shared it can remove that code")
    end
    const Removed = pcall(function()
        Store:RemoveAsync(Code)
    end)
    if not Removed then
        return fail("Share codes are not working right now")
    end
    return { Ok = true }
end

const function importShare(Player: Player, Given: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const Code = cleanCode(Given)
    if not Code then
        return fail(`Share codes are {Customize.ShareLength} letters and numbers`)
    end
    const Now = os.clock()
    if Now - Owner.Imported < Customize.ImportCooldown then
        return fail("Slow down a little")
    end
    Owner.Imported = Now
    const Ok, Data = pcall(function()
        return shareStore():GetAsync(Code)
    end)
    if not Ok then
        return fail("Share codes are not working right now")
    end
    if type(Data) ~= "table" then
        return fail("No group has that code")
    end
    const Kept = cleanShare((Data :: any).Parts)
    if not Kept then
        return fail("That code has nothing in it")
    end
    const Name = (Data :: any).Name
    return { Ok = true, Share = { Name = if type(Name) == "string" then Name else "shared group", Parts = Kept } }
end

const function fetchAsset(Player: Player, AssetId: unknown): Result
    if not Owners[Player] then
        return fail("Your data is still loading")
    end
    if type(AssetId) ~= "number" or AssetId <= 0 or AssetId ~= math.floor(AssetId) then
        return fail("That item id is not valid")
    end
    const Found, Problem = Customize.loadAsset(AssetId)
    if not Found then
        return fail(Problem or "That item could not load")
    end
    return { Ok = true }
end

const function applyLook(Player: Player, Raw: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const Now = os.clock()
    if Now - Owner.Stamp < Config.ApplyCooldown then
        return fail("Slow down a little")
    end
    Owner.Stamp = Now
    const Clean, Problem = Format.sanitize(Raw)
    if not Clean then
        return fail(Problem or "That look is not valid")
    end
    const Missing = preload(Clean)
    if Missing then
        return fail(Missing)
    end
    Owner.Data.Look = Clean
    Owner.Session = Clean
    Customize.applyTo(Player, Clean)
    return { Ok = true, Look = Clean }
end

const function resetLook(Player: Player): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    Owner.Data.Look = nil
    Owner.Session = nil
    Customize.applyTo(Player, nil)
    return { Ok = true }
end

const function saveLook(Player: Player, Slot: unknown, Raw: unknown, Name: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const Key = slotOf(Slot)
    if not Key then
        return fail(`Pick a save slot from 1 to {Config.SaveSlots}`)
    end
    const Clean, Problem = Format.sanitize(Raw)
    if not Clean then
        return fail(Problem or "That look is not valid")
    end
    const Old = Owner.Data.LookSaves[Key]
    const Made: LookSave = {
        Name = if (Name == nil or Name == "") and Old then Old.Name else nameFor(Player, Name, Key),
        Stamp = os.time(),
        Look = Clean,
        Tools = Tools.snapshot(Player),
    }
    Owner.Data.LookSaves[Key] = Made
    return { Ok = true, Save = Made }
end

const function clearLook(Player: Player, Slot: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const Key = slotOf(Slot)
    if not Key then
        return fail(`Pick a save slot from 1 to {Config.SaveSlots}`)
    end
    Owner.Data.LookSaves[Key] = nil
    return { Ok = true }
end

const function ghostFolder(): Folder
    const Existing = Ghosts
    if Existing and Existing.Parent then
        return Existing
    end
    const Made = Instance.new("Folder")
    Made.Name = "CustomizeGhosts"
    Made.Parent = Workspace
    Ghosts = Made
    return Made
end

const function finiteFrame(Value: unknown): boolean
    if typeof(Value) ~= "CFrame" then
        return false
    end
    for _, Number in { (Value :: CFrame):GetComponents() } do
        if Number ~= Number or Number == math.huge or Number == -math.huge then
            return false
        end
    end
    return true
end

const function makeGhost(Player: Player, Character: Model, Origin: CFrame, Poses: unknown): Model?
    const Was = Character.Archivable
    Character.Archivable = true
    const Ghost = Character:Clone()
    Character.Archivable = Was
    if not Ghost then
        return nil
    end
    for _, Item in Ghost:GetDescendants() do
        if Item:IsA("LuaSourceContainer") or Item:IsA("Sound") or Item:IsA("ForceField") or Item:IsA("Humanoid")
            or Item:IsA("Motor6D") or Item:IsA("AnimationConstraint") or Item:IsA("BallSocketConstraint") or Item:IsA("NoCollisionConstraint") then
            Item:Destroy()
        end
    end
    const Given = if type(Poses) == "table" then Poses :: { [any]: any } else {}
    const Anchors = { "HumanoidRootPart" }
    for _, Name in Catalog.BodyParts do
        table.insert(Anchors, Name)
    end
    for _, Name in Anchors do
        const Part = Ghost:FindFirstChild(Name)
        if not Part or not Part:IsA("BasePart") then
            continue
        end
        Part.Anchored = true
        const Pose = Given[Name]
        if finiteFrame(Pose) and ((Pose :: CFrame).Position - Origin.Position).Magnitude <= Config.PoseReach then
            Part.CFrame = Pose :: CFrame
        end
    end
    for _, Item in Ghost:GetDescendants() do
        if Item:IsA("BasePart") then
            Item.CanCollide = false
            Item.CanQuery = false
            Item.CanTouch = false
            Item.CastShadow = false
            if Item.Transparency < 1 then
                Item.Transparency = math.max(Item.Transparency, Config.GhostTransparency)
            end
        elseif Item:IsA("Decal") and Item.Transparency < 1 then
            Item.Transparency = math.max(Item.Transparency, Config.GhostTransparency)
        end
    end
    Ghost.Name = `{Player.Name}Ghost`
    Ghost:SetAttribute("CustomizeGhost", Player.UserId)
    Ghost.Parent = ghostFolder()
    return Ghost
end

const function endSession(Player: Player, Return: boolean)
    const Session = Sessions[Player]
    if not Session then
        return
    end
    Sessions[Player] = nil
    Session.Ghost:Destroy()
    const Character = Session.Character
    if not Return or Player.Character ~= Character or not Character.Parent then
        return
    end
    const Root = Character:FindFirstChild("HumanoidRootPart")
    Character:PivotTo(Session.Origin)
    if Root and Root:IsA("BasePart") then
        Root.Anchored = false
    end
end

const function enterRoom(Player: Player, Poses: unknown): Result
    if not Owners[Player] then
        return fail("Your data is still loading")
    end
    if Sessions[Player] then
        return { Ok = true, Room = Room.spot() }
    end
    const Character = Player.Character
    const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    const Humanoid = if Character then Character:FindFirstChildOfClass("Humanoid") else nil
    if not Character or not Root or not Root:IsA("BasePart") or not Humanoid or Humanoid.Health <= 0 then
        return fail("You need to be spawned in to customize")
    end
    const Origin = Root.CFrame
    const Ghost = makeGhost(Player, Character, Origin, Poses)
    if not Ghost then
        return fail("Your ghost could not be made")
    end
    Sessions[Player] = {
        Ghost = Ghost,
        Origin = Origin,
        Character = Character,
    }
    Root.Anchored = true
    Character:PivotTo(Room.hold())
    return { Ok = true, Room = Room.spot() }
end

const function leaveRoom(Player: Player): Result
    endSession(Player, true)
    return { Ok = true }
end

function Customize.attach(Player: Player, Data: PlayerData)
    if Owners[Player] then
        return
    end
    if type(Data.LookSaves) ~= "table" then
        Data.LookSaves = {}
    end
    if Data.Look ~= nil then
        Data.Look = (Format.sanitize(Data.Look))
    end
    const Owner: Owner = {
        Player = Player,
        Data = Data,
        Stamp = 0,
        Link = Player.CharacterAdded:Connect(function(Character: Model)
            endSession(Player, false)
            onCharacter(Player, Character)
        end),
        Session = if Config.ApplySavedOnJoin then Data.Look else nil,
        Shared = -math.huge,
        Imported = -math.huge,
    }
    Owners[Player] = Owner
    push(Owner)
    const Character = Player.Character
    if Character then
        task.spawn(onCharacter, Player, Character)
    end
end

function Customize.detach(Player: Player)
    endSession(Player, false)
    const Owner = Owners[Player]
    Owners[Player] = nil
    const Link = if Owner then Owner.Link else nil
    if Link then
        Link:Disconnect()
    end
end

function Customize.start()
    if Started then
        return
    end
    Started = true
    folder()
    Net:When("@Customize/Fetch", fetchAsset)
    Net:When("@Customize/Apply", applyLook)
    Net:When("@Customize/Reset", resetLook)
    Net:When("@Customize/Save", saveLook)
    Net:When("@Customize/ClearSave", clearLook)
    Net:When("@Customize/RenameSave", renameLook)
    Net:When("@Customize/Clothing", fetchClothing)
    Net:When("@Customize/Texture", resolveTexture)
    Net:When("@Customize/Share", shareGroup)
    Net:When("@Customize/Import", importShare)
    Net:When("@Customize/Unshare", unshare)
    Net:When("@Customize/Enter", enterRoom)
    Net:When("@Customize/Leave", leaveRoom)
    Room.get()
    Players.PlayerRemoving:Connect(Customize.detach)
end

return Customize
