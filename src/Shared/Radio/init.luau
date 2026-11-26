--!strict
const ContentProvider = game:GetService("ContentProvider")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const SoundService = game:GetService("SoundService")

const vision = require(ReplicatedStorage.MainPackages.vision)
const signal = require(ReplicatedStorage.MainPackages.signal)
const Sounds = require(ReplicatedStorage.Shared.Sounds)
const Channels = require(script.Channels)
const Bridges = require(script.Bridges)
const UI = require(ReplicatedStorage.Shared.UI)
const View = UI.view("Radio")

export type Clip = Channels.Clip
export type Channel = Channels.Channel

type Playing = {
    Sound: Sound,
    Base: number,
    Name: string,
}

const Radio = {
    GroupName = "Radio",
    DefaultVolume = 0.5,
    VolumeStep = 0.1,
    LoadTimeout = 10,
    BreakChance = 0.3,
    ChatterEvery = { 60, 150 },
    Duck = 0.4,
    TuneInRange = { 0.1, 0.7 },
    Changed = signal.new(),
}

local Group: SoundGroup? = nil
local Volume = Radio.DefaultVolume
local On = false
local Shown = false
local Current: Channel? = nil
local Track: Playing? = nil
local Over: Playing? = nil
local Status = ""
local Token = 0
local Started = false
const Bags: { [string]: { number } } = {}
const Rng = Random.new()

const function sorted(): { Channel }
    const List = table.clone(Channels)
    table.sort(List, function(A: Channel, B: Channel): boolean
        const First = A.Order or 99
        const Second = B.Order or 99
        if First ~= Second then
            return First < Second
        end
        return A.Name < B.Name
    end)
    return List
end

const function groupOf(): SoundGroup
    const Known = Group
    if Known and Known.Parent then
        return Known
    end
    const Made = Instance.new("SoundGroup")
    Made.Name = Radio.GroupName
    Made.Volume = Volume
    Made.Parent = SoundService
    Group = Made
    return Made
end

const function idOf(Value: number | string): string
    if type(Value) == "number" then
        return `rbxassetid://{Value}`
    end
    return if string.match(Value, "^%d+$") then `rbxassetid://{Value}` else Value
end

const function pick(List: { Clip }): Clip?
    local Total = 0
    for _, Item in List do
        Total += math.max(Item.Weight or 1, 0)
    end
    if Total <= 0 then
        return nil
    end
    local Roll = Rng:NextNumber() * Total
    for _, Item in List do
        Roll -= math.max(Item.Weight or 1, 0)
        if Roll <= 0 then
            return Item
        end
    end
    return List[#List]
end

const function nextTrack(Channel: Channel): Clip?
    const Tracks = Channel.Tracks
    if #Tracks == 0 then
        return nil
    end
    if Channel.Shuffle == false then
        const Bag = Bags[Channel.Id] or { 0 }
        Bag[1] = Bag[1] % #Tracks + 1
        Bags[Channel.Id] = Bag
        return Tracks[Bag[1]]
    end
    local Bag = Bags[Channel.Id]
    if not Bag or #Bag == 0 then
        Bag = {}
        for Index = 1, #Tracks do
            table.insert(Bag, Rng:NextInteger(1, #Bag + 1), Index)
        end
        Bags[Channel.Id] = Bag
    end
    const Index = table.remove(Bag) :: number
    return Tracks[Index]
end

const function refresh()
    const Channel = Current
    const Cards: { Bridges.ChannelCard } = {}
    for _, Item in sorted() do
        table.insert(Cards, {
            Id = Item.Id,
            Name = Item.Name,
            Detail = Item.Description or `{#Item.Tracks} {if #Item.Tracks == 1 then "song" else "songs"}`,
            Active = On and Channel ~= nil and Channel.Id == Item.Id,
        })
    end
    View.RadioChannels(Cards)
    View.RadioNow({
        On = On,
        Channel = if On and Channel then Channel.Name else "off",
        Track = if On then Status else "press on or pick a channel",
        Volume = `{math.round(Volume * 100)}%`,
        Level = Volume,
    })
    Radio.Changed:Fire()
end

const function stopSound(Item: Playing?)
    if Item then
        Item.Sound:Stop()
        Item.Sound:Destroy()
    end
end

const function stopAll()
    Token += 1
    stopSound(Track)
    stopSound(Over)
    Track = nil
    Over = nil
end

const function make(Clip: Clip, Channel: Channel): Playing
    const Sound = Instance.new("Sound")
    Sound.Name = Clip.Name
    Sound.SoundId = idOf(Clip.Id)
    Sound.PlaybackSpeed = Clip.Speed or 1
    const Base = (Clip.Volume or 1) * (Channel.Volume or 1)
    Sound.Volume = Base
    Sound.Looped = false
    Sound.SoundGroup = groupOf()
    Sound.Parent = groupOf()
    return { Sound = Sound, Base = Base, Name = Clip.Name }
end

const function ready(Sound: Sound, Mine: number): boolean
    if not Sound.IsLoaded then
        task.spawn(function()
            pcall(ContentProvider.PreloadAsync, ContentProvider, { Sound })
        end)
        const Waited = os.clock()
        while not Sound.IsLoaded and Mine == Token and os.clock() - Waited < Radio.LoadTimeout do
            task.wait(0.1)
        end
    end
    return Mine == Token and Sound.IsLoaded and Sound.TimeLength > 0
end

const function playClip(Clip: Clip, Channel: Channel, Mine: number, Label: string, Offset: number?): boolean
    const Item = make(Clip, Channel)
    Track = Item
    Status = `loading {Label}`
    refresh()
    if not ready(Item.Sound, Mine) then
        stopSound(Item)
        if Track == Item then
            Track = nil
        end
        if Mine == Token then
            warn(`[Radio] {Clip.Name} could not load`)
        end
        return Mine == Token
    end
    if Offset then
        Item.Sound.TimePosition = Item.Sound.TimeLength * Offset
    end
    if Over then
        Item.Sound.Volume = Item.Base * (Channel.Duck or Radio.Duck)
    end
    Item.Sound:Play()
    Status = Label
    refresh()
    local Done = false
    const Link = Item.Sound.Ended:Connect(function()
        Done = true
    end)
    while not Done and Mine == Token and Item.Sound.Parent do
        task.wait(0.2)
    end
    Link:Disconnect()
    stopSound(Item)
    if Track == Item then
        Track = nil
    end
    return Mine == Token
end

const function playLoop(Channel: Channel, Mine: number)
    local First = true
    while Mine == Token do
        const Clip = nextTrack(Channel)
        if not Clip then
            Status = "nothing to play"
            refresh()
            return
        end
        const Range = Radio.TuneInRange
        const Offset = if First and Channel.TuneIn ~= false then Rng:NextNumber(Range[1], Range[2]) else nil
        First = false
        if not playClip(Clip, Channel, Mine, Clip.Name, Offset) then
            return
        end
        const Breaks = Channel.Breaks
        if Breaks and #Breaks > 0 and Rng:NextNumber() < (Channel.BreakChance or Radio.BreakChance) then
            const Break = pick(Breaks)
            if Break and not playClip(Break, Channel, Mine, Break.Name) then
                return
            end
        end
    end
end

const function chatterLoop(Channel: Channel, Mine: number)
    const List = Channel.Chatter
    if not List or #List == 0 then
        return
    end
    const Every = Channel.ChatterEvery or Radio.ChatterEvery
    while Mine == Token do
        task.wait(Rng:NextNumber(Every[1], Every[2] or Every[1]))
        const Clip = pick(List)
        if Mine ~= Token or not Clip then
            return
        end
        const Item = make(Clip, Channel)
        if not ready(Item.Sound, Mine) then
            stopSound(Item)
            continue
        end
        Over = Item
        const Music = Track
        if Music then
            Music.Sound.Volume = Music.Base * (Channel.Duck or Radio.Duck)
        end
        Item.Sound:Play()
        local Done = false
        const Link = Item.Sound.Ended:Connect(function()
            Done = true
        end)
        while not Done and Mine == Token and Item.Sound.Parent do
            task.wait(0.2)
        end
        Link:Disconnect()
        stopSound(Item)
        if Over == Item then
            Over = nil
        end
        const After = Track
        if After then
            After.Sound.Volume = After.Base
        end
    end
end

function Radio.channels(): { Channel }
    return sorted()
end

function Radio.current(): Channel?
    return Current
end

function Radio.isOn(): boolean
    return On
end

function Radio.isShown(): boolean
    return Shown
end

function Radio.tune(Id: string?)
    stopAll()
    local Found: Channel? = nil
    for _, Item in Channels do
        if Item.Id == Id then
            Found = Item
        end
    end
    Current = Found or Current or sorted()[1]
    const Channel = Current
    On = Channel ~= nil
    if not Channel then
        refresh()
        return
    end
    Sounds.play("RadioTune")
    const Mine = Token
    task.spawn(playLoop, Channel, Mine)
    task.spawn(chatterLoop, Channel, Mine)
    refresh()
end

function Radio.stop()
    stopAll()
    On = false
    Status = ""
    Sounds.play("RadioOff")
    refresh()
end

function Radio.step(Direction: number)
    const List = sorted()
    if #List == 0 then
        return
    end
    local Index = 0
    const Channel = Current
    for Position, Item in List do
        if Channel and Item.Id == Channel.Id then
            Index = Position
        end
    end
    Index = (Index - 1 + Direction) % #List + 1
    Radio.tune(List[Index].Id)
end

function Radio.setVolume(Value: number)
    Volume = math.clamp(Value, 0, 1)
    groupOf().Volume = Volume
    refresh()
end

function Radio.volume(): number
    return Volume
end

function Radio.show(Value: boolean)
    if Shown ~= Value then
        Sounds.play(if Value then "MenuOpen" else "MenuClose")
    end
    Shown = Value
    View.RadioShown(Value)
    refresh()
end

function Radio.toggle()
    Radio.show(not Shown)
end

function Radio.start()
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    groupOf()
    const Gui = vision.create({
        ClassName = "ScreenGui",
        Name = "Radio",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 5,
    }) :: ScreenGui
    Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    UI.mount("Radio", Gui)

    Bridges.Radio:Bind(function(Action: string, Value: any)
        if Action == "Close" then
            Radio.show(false)
        elseif Action == "Power" then
            if On then
                Radio.stop()
            else
                Radio.tune(nil)
            end
        elseif Action == "Tune" and type(Value) == "string" then
            Radio.tune(Value)
        elseif Action == "Step" and type(Value) == "number" then
            Radio.step(Value)
        elseif Action == "Volume" and type(Value) == "number" then
            Radio.setVolume(Value)
        elseif Action == "Nudge" and type(Value) == "number" then
            Radio.setVolume(math.round((Volume + Value * Radio.VolumeStep) * 10) / 10)
        end
    end)

    RunService.Heartbeat:Connect(function()
        if not Shown then
            return
        end
        const Item = Track
        const Length = if Item then Item.Sound.TimeLength else 0
        View.RadioProgress(if Item and Length > 0 then Item.Sound.TimePosition / Length else 0)
    end)
    refresh()
end

return Radio
