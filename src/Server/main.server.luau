--!strict
------------------------------------------------------- ToplineData
const TemplateData = {
    PropCount = 110,
    OwnedPacks = {},
    PropSaves = {},
    BuildTool = false,
    LookSaves = {},
    Settings = {},
    Playtime = 0,
    PurchaseIds = {},
    ShopGifts = {},
    Tools = { Slots = {} },
    Bio = { Nickname = "", Description = "", Stats = {} },
}
------------------------------------------------------- LOADERS
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ProfileStore = require(ReplicatedStorage.MainPackages.ProfileStore)
const promise = require(ReplicatedStorage.Packages.promise)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Props = require(script.Parent.Props)
const Customize = require(script.Parent.Customize)
const Settings = require(script.Parent.Settings)
const Stats = require(script.Parent.Stats)
const Environment = require(script.Parent.Environment)
const Shop = require(script.Parent.Shop)
const Tools = require(script.Parent.Tools)
const Dice = require(script.Parent.Dice)
const Throws = require(script.Parent.Throws)
const ToolAssets = require(script.Parent.ToolAssets)
const Bio = require(script.Parent.Bio)
const HeadLook = require(script.Parent.HeadLook)
const Admin = require(script.Parent.Admin)
const MainProfile = ProfileStore.New("Player_Data", TemplateData::any)
const Loaders: { [Player]: promise.Promise } = {}
const Profiles: { [Player]: ProfileStore.Profile< Partial<PlayerData> > } = {}
------------------------------------------------------- PlayerDataLoad
const function ApplyPlayerLoader(Player:Player)
    if Player.Parent ~= Players then
        return
    end
    local Thread:thread? = nil
    const MainPromise = promise.new(function(Resolve, Reject)
        Thread = coroutine.running()
        coroutine.yield()
        const PlayerProfile:ProfileStore.Profile< Partial<PlayerData> >? = MainProfile:StartSessionAsync(tostring(Player.UserId), {
            Cancel = function()
                return not Player:IsDescendantOf(Players)
            end,
        })::any
        if not PlayerProfile then
            if Player:IsDescendantOf(Players) then
                Player:Kick("Your data failed to load, please rejoin")
            end
            Reject("No valid session able to load")
            return
        end
        if not Player:IsDescendantOf(Players) then
            PlayerProfile:EndSession()
            Reject("Player left")
            return
        end
        PlayerProfile:Reconcile()
        Resolve(PlayerProfile::ProfileStore.Profile<PlayerData>)
    end)
    Loaders[Player] = MainPromise
    ---------- REJECTION HANDLER
    const Loaded = MainPromise:catch(function(Reason)
        if Loaders[Player] == MainPromise then
            Loaders[Player] = nil
        end
        warn(`[PlayerData] {Player.Name} ({Player.UserId}) did not load: {Reason}`)
        return promise.new(function() end)
    end)
    ---------- POST LINKERS HERE
    Loaded:andThen(function(PlayerProfile:ProfileStore.Profile< Partial<PlayerData> >)
        Profiles[Player] = PlayerProfile
        PlayerProfile:AddUserId(Player.UserId)
        PlayerProfile.OnSessionEnd:Connect(function()
            if Profiles[Player] ~= PlayerProfile then
                return
            end
            Profiles[Player] = nil
            Player:Kick("Your data session ended, please rejoin")
        end)
        Props.attach(Player, PlayerProfile.Data :: any)
        Customize.attach(Player, PlayerProfile.Data :: any)
        Settings.attach(Player, PlayerProfile.Data :: any)
        Stats.attach(Player, PlayerProfile.Data :: any)
        Shop.attach(Player, PlayerProfile)
        Tools.attach(Player, PlayerProfile.Data :: any)
        Bio.attach(Player, PlayerProfile.Data :: any)
    end)

    Loaded:andThen(function(PlayerData:ProfileStore.Profile< Partial<PlayerData> >)
        NetWatch.DataNet:BroadcastTo(Player, "@Game/DataReady", PlayerData.Data) -- DO NOT PUT ANYTHING ELSE HERE THIS IS OUR SECURE LINE
        NetWatch.DataNet:Broadcast("@Game/PlayerJoinedGame", Player.UserId)
    end)
    ---------- Resume Launch
    if Thread then
        task.spawn(Thread)
    end
end

const function RemovePlayerLoader(Player:Player)
    Loaders[Player] = nil
    const PlayerProfile = Profiles[Player]
    Profiles[Player] = nil
    if PlayerProfile then
        PlayerProfile:EndSession()
    end
end

Players.PlayerAdded:Connect(ApplyPlayerLoader)
Players.PlayerRemoving:Connect(RemovePlayerLoader)
for _, Updating_Player in ipairs(Players:GetPlayers()) do
    if Updating_Player:IsDescendantOf(Players) then
        task.spawn(ApplyPlayerLoader, Updating_Player)
    end
end
------------------------------------------------------- Boot Linkers
Environment.start()
Props.start()
Customize.start()
Settings.start()
Stats.start()
Shop.start(MainProfile)
ToolAssets.start()
Bio.start()
HeadLook.start()
Admin.start()
Tools.start()
Throws.start()
Dice.start()