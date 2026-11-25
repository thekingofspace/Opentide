--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TextService = game:GetService("TextService")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Stats = require(ReplicatedStorage.Shared.Bio.Stats)

type Result = {
    Ok: boolean,
    Error: string?,
    Value: any?,
}

const Bio = {
    MaxNickname = 24,
    MaxDescription = 200,
    TagName = "Nametag",
    TagLift = 2.2,
    NicknameAttribute = "Nickname",
    DescriptionAttribute = "Description",
}

const Net = NetWatch.Bio
const Owners: { [Player]: BioData } = {}
local Started = false

const function fail(Message: string): Result
    return { Ok = false, Error = Message }
end

const function dataOf(Data: PlayerData): BioData
    local Found = Data.Bio
    if type(Found) ~= "table" then
        const Made: BioData = { Nickname = "", Description = "", Stats = {} }
        Data.Bio = Made
        Found = Made
    end
    const Bio2 = Found :: BioData
    if type(Bio2.Nickname) ~= "string" then
        Bio2.Nickname = ""
    end
    if type(Bio2.Description) ~= "string" then
        Bio2.Description = ""
    end
    if type(Bio2.Stats) ~= "table" then
        Bio2.Stats = {}
    end
    return Bio2
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

const function tag(Player: Player)
    const Character = Player.Character
    const Head = if Character then Character:FindFirstChild("Head") else nil
    const Humanoid = if Character then Character:FindFirstChildOfClass("Humanoid") else nil
    if not Head or not Head:IsA("BasePart") then
        return
    end
    const Old = Head:FindFirstChild(Bio.TagName)
    if Old then
        Old:Destroy()
    end
    const Data = Owners[Player]
    const Name = if Data then Data.Nickname else ""
    if Humanoid then
        Humanoid.DisplayDistanceType = if Name ~= "" then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer
    end
    if Name == "" then
        return
    end
    const Board = Instance.new("BillboardGui")
    Board.Name = Bio.TagName
    Board.Size = UDim2.fromOffset(220, 34)
    Board.StudsOffset = Vector3.new(0, Bio.TagLift, 0)
    Board.MaxDistance = 100
    Board.LightInfluence = 0
    const Label = Instance.new("TextLabel")
    Label.Size = UDim2.fromScale(1, 1)
    Label.BackgroundTransparency = 1
    Label.Text = Name
    Label.TextScaled = true
    Label.Font = Enum.Font.GothamBold
    Label.TextColor3 = Color3.new(1, 1, 1)
    Label.TextStrokeTransparency = 0.3
    Label.Parent = Board
    Board.Parent = Head
end

const function publish(Player: Player)
    const Data = Owners[Player]
    if not Data then
        return
    end
    Player:SetAttribute(Bio.NicknameAttribute, if Data.Nickname ~= "" then Data.Nickname else nil)
    Player:SetAttribute(Bio.DescriptionAttribute, if Data.Description ~= "" then Data.Description else nil)
    for _, Def in Stats.List do
        Player:SetAttribute(Stats.AttributePrefix .. Def.Id, Stats.clamp(Def, Data.Stats[Def.Id]))
    end
end

const function setText(Player: Player, Field: unknown, Raw: unknown): Result
    const Data = Owners[Player]
    if not Data then
        return fail("Your data is still loading")
    end
    if type(Raw) ~= "string" or (Field ~= "Nickname" and Field ~= "Description") then
        return fail("That can not be changed")
    end
    const Limit = if Field == "Nickname" then Bio.MaxNickname else Bio.MaxDescription
    local Text = string.match(Raw, "^%s*(.-)%s*$") or ""
    if Field == "Nickname" then
        Text = string.gsub(Text, "[\n\r]", " ")
    end
    if utf8.len(Text) == nil then
        return fail("That text has bad characters")
    end
    Text = string.sub(Text, 1, Limit)
    const Clean = filter(Player, Text)
    if not Clean then
        return fail("That could not be checked right now, try again")
    end
    if Field == "Nickname" then
        Data.Nickname = Clean
        tag(Player)
    else
        Data.Description = Clean
    end
    publish(Player)
    return { Ok = true, Value = Clean }
end

const function setStat(Player: Player, Id: unknown, Value: unknown): Result
    const Data = Owners[Player]
    const Def = Stats.get(Id)
    if not Data then
        return fail("Your data is still loading")
    end
    if not Def then
        return fail("That stat does not exist")
    end
    Data.Stats[Def.Id] = Stats.clamp(Def, Value)
    publish(Player)
    return { Ok = true, Value = Data.Stats[Def.Id] }
end

function Bio.attach(Player: Player, Data: PlayerData)
    Owners[Player] = dataOf(Data)
    publish(Player)
    Player.CharacterAdded:Connect(function(Character: Model)
        Character:WaitForChild("Head", 10)
        tag(Player)
        Character.ChildAdded:Connect(function(Child: Instance)
            if Child.Name == "Head" then
                task.defer(tag, Player)
            end
        end)
    end)
    if Player.Character then
        tag(Player)
    end
end

function Bio.start()
    if Started then
        return
    end
    Started = true
    Net:When("@Bio/Text", setText)
    Net:When("@Bio/Stat", setStat)
    Players.PlayerRemoving:Connect(function(Player: Player)
        Owners[Player] = nil
    end)
end

return Bio
