--!strict
const GroupService = game:GetService("GroupService")
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const TextService = game:GetService("TextService")
const Workspace = game:GetService("Workspace")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Omni = require(ReplicatedStorage.Shared.Omni.Shared)
const Weather = require(ReplicatedStorage.Shared.Utility.Weather)
const Environment = require(script.Parent.Environment)
const Config = require(script.Config)

type Result = {
    Ok: boolean,
    Error: string?,
    Message: string?,
}

const Admin = {
    BringGap = 4,
    WeatherFade = 3,
}

const Net = NetWatch.AdminNet
local Started = false

const function fail(Message: string): Result
    return { Ok = false, Error = Message }
end

const function creator(Player: Player): boolean
    if not Config.CreatorAccess then
        return false
    end
    if game.CreatorType == Enum.CreatorType.User then
        return Player.UserId == game.CreatorId
    end
    const Ok, Info = pcall(function()
        return GroupService:GetGroupInfoAsync(game.CreatorId)
    end)
    return Ok and type(Info) == "table" and type(Info.Owner) == "table" and Info.Owner.Id == Player.UserId
end

const function privateOwner(Player: Player): boolean
    return game.PrivateServerOwnerId ~= 0 and Player.UserId == game.PrivateServerOwnerId
end

function Admin.canOmni(Player: Player): boolean
    if (Config.StudioAccess and RunService:IsStudio()) or creator(Player) or table.find(Config.OmniUsers, Player.UserId) then
        return true
    end
    return Config.PrivateServerOwnerOmni and privateOwner(Player)
end

function Admin.canModerate(Player: Player): boolean
    if (Config.StudioAccess and RunService:IsStudio()) or creator(Player) or table.find(Config.Moderators, Player.UserId) then
        return true
    end
    return Config.PrivateServerOwnerModerator and privateOwner(Player)
end

const function filter(Player: Player, Text: string): string?
    if Text == "" then
        return ""
    end
    const Ok, Result = pcall(function()
        return TextService:FilterStringAsync(Text, Player.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
    end)
    return if Ok and type(Result) == "string" then Result else nil
end

const function clean(Raw: unknown, Limit: number): string
    if type(Raw) ~= "string" then
        return ""
    end
    return string.sub(string.match(Raw, "^%s*(.-)%s*$") or "", 1, Limit)
end

const function rootOf(Player: Player): BasePart?
    const Character = Player.Character
    const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    return if Root and Root:IsA("BasePart") then Root else nil
end

const function ambient(Raw: unknown): string?
    if type(Raw) ~= "table" then
        return nil
    end
    const Given = Raw :: any
    const Made: { [string]: any } = {}
    for Key, Range in Omni.Ambient do
        const Value = Given[Key]
        if type(Value) == "number" and Value == Value then
            Made[Key] = math.clamp(Value, Range.Min, Range.Max)
        end
    end
    const Tint = Given.Tint
    if type(Tint) == "table" and #Tint == 3 then
        Made.Tint = { math.clamp(tonumber(Tint[1]) or 255, 0, 255), math.clamp(tonumber(Tint[2]) or 255, 0, 255), math.clamp(tonumber(Tint[3]) or 255, 0, 255) }
    end
    return HttpService:JSONEncode(Made)
end

const function teleport(Player: Player, Mode: unknown, Target: unknown): Result
    const Mine = rootOf(Player)
    if not Mine then
        return fail("You need to be spawned in")
    end
    if Mode == "BringAll" then
        for Index, Other in Players:GetPlayers() do
            const Body = Other.Character
            if Other ~= Player and Body and rootOf(Other) then
                const Angle = Index * 0.9
                Body:PivotTo(Mine.CFrame * CFrame.new(math.cos(Angle) * Admin.BringGap, 0, math.sin(Angle) * Admin.BringGap))
            end
        end
        return { Ok = true, Message = "Brought everyone to you" }
    end
    const Other = if type(Target) == "number" then Players:GetPlayerByUserId(Target) else nil
    const Root = if Other then rootOf(Other) else nil
    const Body = if Other then Other.Character else nil
    const Own = Player.Character
    if not Other or not Root or not Body or not Own then
        return fail("That player is not spawned in")
    end
    if Mode == "GoTo" then
        Own:PivotTo(Root.CFrame * CFrame.new(0, 0, Admin.BringGap))
        return { Ok = true, Message = `Went to {Other.DisplayName}` }
    elseif Mode == "Bring" then
        Body:PivotTo(Mine.CFrame * CFrame.new(0, 0, -Admin.BringGap))
        return { Ok = true, Message = `Brought {Other.DisplayName}` }
    end
    return fail("That is not a teleport")
end

const function act(Player: Player, Action: unknown, Value: unknown, Extra: unknown): Result
    if not Admin.canOmni(Player) then
        return fail("You can not use the omni tool")
    end
    if Action == "Weather" and type(Value) == "string" then
        return if Environment.setWeather(Value, Admin.WeatherFade) then { Ok = true, Message = `Weather set to {Value}` } else fail("That weather does not exist")
    elseif Action == "FreezeWeather" then
        Environment.freezeWeather(Value == true)
        return { Ok = true, Message = if Value == true then "Weather will stay as it is" else "Weather changes on its own again" }
    elseif Action == "Hour" and type(Value) == "number" and Value == Value then
        Environment.setHour(math.clamp(Value, 0, 24) % 24)
        return { Ok = true, Message = string.format("Time set to %02d:00", math.floor(Value) % 24) }
    elseif Action == "FreezeTime" then
        Environment.freezeTime(Value == true)
        return { Ok = true, Message = if Value == true then "Time is frozen" else "Time moves again" }
    elseif Action == "Ambient" then
        const Encoded = ambient(Value)
        if not Encoded then
            return fail("Those ambient settings are not valid")
        end
        Workspace:SetAttribute(Omni.AmbientAttribute, Encoded)
        return { Ok = true, Message = "Ambient set for everyone" }
    elseif Action == "ClearAmbient" then
        Workspace:SetAttribute(Omni.AmbientAttribute, nil)
        return { Ok = true, Message = "Ambient cleared" }
    elseif Action == "Popup" then
        const Title = filter(Player, clean(Value, 60))
        const Body = filter(Player, clean(Extra, Config.MaxPopup))
        if not Title or not Body then
            return fail("That message could not be checked right now")
        end
        if Body == "" then
            return fail("Write a message first")
        end
        Net:Broadcast("@Omni/Popup", if Title ~= "" then Title else "message", Body, Player.DisplayName)
        return { Ok = true, Message = "Popup sent" }
    elseif Action == "Pin" then
        const Text = filter(Player, clean(Value, Config.MaxPin))
        if not Text then
            return fail("That message could not be checked right now")
        end
        Workspace:SetAttribute(Omni.PinAttribute, if Text ~= "" then Text else nil)
        return { Ok = true, Message = if Text ~= "" then "Pinned to the top of the screen" else "Unpinned" }
    elseif Action == "Unpin" then
        Workspace:SetAttribute(Omni.PinAttribute, nil)
        return { Ok = true, Message = "Unpinned" }
    elseif Action == "Teleport" then
        return teleport(Player, Value, Extra)
    end
    return fail("That is not an omni action")
end

const function findPlayer(Name: string): Player?
    const Lower = string.lower(Name)
    for _, Other in Players:GetPlayers() do
        if string.lower(Other.Name) == Lower or string.lower(Other.DisplayName) == Lower then
            return Other
        end
    end
    for _, Other in Players:GetPlayers() do
        if string.sub(string.lower(Other.Name), 1, #Lower) == Lower or string.sub(string.lower(Other.DisplayName), 1, #Lower) == Lower then
            return Other
        end
    end
    return nil
end

const function userIdOf(Name: string): (number?, string)
    const Number = tonumber(Name)
    if Number then
        return Number, Name
    end
    const Online = findPlayer(Name)
    if Online then
        return Online.UserId, Online.Name
    end
    const Ok, Found = pcall(function()
        return Players:GetUserIdFromNameAsync(Name)
    end)
    return if Ok and type(Found) == "number" then Found else nil, Name
end

const function duration(Token: string?): number?
    if not Token then
        return nil
    end
    if Token == "perm" or Token == "forever" then
        return -1
    end
    const Amount, Unit = string.match(Token, "^(%d+)([smhdw])$")
    const Scale = ({ s = 1, m = 60, h = 3600, d = 86400, w = 604800 } :: { [string]: number })[Unit or ""]
    return if Amount and Scale then tonumber(Amount) :: number * Scale else nil
end

const function command(Player: Player, Text: unknown): Result
    if not Admin.canModerate(Player) then
        return fail("You can not use moderation commands")
    end
    if type(Text) ~= "string" then
        return fail("That command is empty")
    end
    const Words: { string } = {}
    for Word in string.gmatch(Text, "%S+") do
        table.insert(Words, Word)
    end
    const Stripped = string.gsub(Words[1] or "", "^[/:]", "")
    const Name = string.lower(Stripped)
    const Who = Words[2]
    if not Who then
        return fail(`Use /{Name} <player> [reason]`)
    end
    if Name == "kick" then
        const Target = findPlayer(Who)
        if not Target then
            return fail(`Nobody called {Who} is in this server`)
        end
        const Reason = table.concat(Words, " ", 3)
        Target:Kick(if Reason ~= "" then Reason else "You were kicked")
        return { Ok = true, Message = `Kicked {Target.Name}` }
    elseif Name == "ban" then
        const Id, Label = userIdOf(Who)
        if not Id then
            return fail(`Could not find a player called {Who}`)
        end
        const Length = duration(Words[3])
        const Reason = table.concat(Words, " ", if Length then 4 else 3)
        const Ok, Problem = pcall(function()
            Players:BanAsync({
                UserIds = { Id },
                ApplyToUniverse = true,
                Duration = Length or -1,
                DisplayReason = if Reason ~= "" then Reason else "You were banned",
                PrivateReason = `banned by {Player.Name} ({Player.UserId})`,
                ExcludeAltAccounts = false,
            })
        end)
        if not Ok then
            return fail(`Ban failed: {Problem}`)
        end
        return { Ok = true, Message = `Banned {Label}{if Length and Length > 0 then ` for {Words[3]}` else " forever"}` }
    elseif Name == "unban" then
        const Id, Label = userIdOf(Who)
        if not Id then
            return fail(`Could not find a player called {Who}`)
        end
        const Ok, Problem = pcall(function()
            Players:UnbanAsync({ UserIds = { Id }, ApplyToUniverse = true })
        end)
        if not Ok then
            return fail(`Unban failed: {Problem}`)
        end
        return { Ok = true, Message = `Unbanned {Label}` }
    end
    return fail(`/{Name} is not a command`)
end

function Admin.start()
    if Started then
        return
    end
    Started = true
    Net:When("@Admin/Access", function(Player: Player)
        return {
            Omni = Admin.canOmni(Player),
            Commands = Admin.canModerate(Player),
            Weathers = (function(): { string }
                const Names: { string } = {}
                for Name in Weather.list() do
                    table.insert(Names, Name)
                end
                table.sort(Names)
                return Names
            end)(),
        }
    end)
    Net:When("@Omni/Do", act)
    Net:When("@Admin/Command", command)
end

return Admin
