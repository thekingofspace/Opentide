--!strict
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Config = require(ReplicatedStorage.Shared.PropData.Config)

export type Record = {
    Key: string,
    Id: number,
    Owner: number,
    Pivot: CFrame,
    Scale: number,
    States: { [string]: any },
    Stamp: number,
    Changed: number,
    By: number,
    Zone: string,
}

export type Zone = {
    Key: string,
    Center: Vector3,
    Version: string,
    Props: { [string]: Record },
    Count: number,
    Members: { [Player]: boolean },
}

export type Change = { [string]: any }

export type Move = {
    Record: Record,
    Pivot: CFrame,
    Scale: number,
    By: number,
    Stamp: number,
}

const Zones = {
    ResendCooldown = 1,
}

const Net = NetWatch.PropPlacer
const List: { [string]: Zone } = {}
const Records: { [string]: Record } = {}
const Sent: { [Player]: { [string]: string } } = {}
const Asked: { [Player]: { [string]: number } } = {}
const Pending: { [Zone]: { Change } } = {}
local Started = false

const function uuid(): string
    return HttpService:GenerateGUID(false)
end

const function room(Zone: Zone): string
    return `PropZone/{Zone.Key}`
end

const function gap(Zone: Zone, Position: Vector3): number
    const Half = Config.ZoneSize / 2
    const Outside = (Position - Zone.Center):Abs() - Vector3.new(Half, Half, Half)
    return Outside:Max(Vector3.zero).Magnitude
end

const function rootOf(Player: Player): Vector3?
    const Character = Player.Character
    const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    return if Root and Root:IsA("BasePart") then Root.Position else nil
end

const function sentTo(Player: Player): { [string]: string }
    local Known = Sent[Player]
    if not Known then
        Known = {}
        Sent[Player] = Known
    end
    return Known
end

const function snapshot(Zone: Zone): { Record }
    const Made: { Record } = {}
    for _, Item in Zone.Props do
        table.insert(Made, Item)
    end
    return Made
end

const function sendSnapshot(Player: Player, Zone: Zone)
    sentTo(Player)[Zone.Key] = Zone.Version
    Net:BroadcastTo(Player, "@Props/ZoneEnter", Zone.Key, Zone.Version, Zone.Center, snapshot(Zone))
end

const function join(Player: Player, Zone: Zone)
    if Zone.Members[Player] then
        return
    end
    Zone.Members[Player] = true
    Net:JoinRoom(room(Zone), Player)
    if sentTo(Player)[Zone.Key] == Zone.Version then
        Net:BroadcastTo(Player, "@Props/ZoneEnter", Zone.Key, Zone.Version, Zone.Center, nil)
    else
        sendSnapshot(Player, Zone)
    end
end

const function leave(Player: Player, Zone: Zone)
    if not Zone.Members[Player] then
        return
    end
    Zone.Members[Player] = nil
    Net:LeaveRoom(room(Zone), Player)
    Net:BroadcastTo(Player, "@Props/ZoneLeave", Zone.Key)
end

const function scan(Player: Player, Zone: Zone)
    const Position = rootOf(Player)
    if not Position then
        return
    end
    const Distance = gap(Zone, Position)
    if Zone.Members[Player] then
        if Distance > Config.LeaveRange then
            leave(Player, Zone)
        end
    elseif Distance <= Config.JoinRange then
        join(Player, Zone)
    end
end

const function destroy(Zone: Zone)
    if List[Zone.Key] ~= Zone then
        return
    end
    List[Zone.Key] = nil
    Pending[Zone] = nil
    table.clear(Zone.Members)
    Net:DestroyRoom(room(Zone))

    const Told: { Player } = {}
    for Player, Known in Sent do
        if Known[Zone.Key] then
            Known[Zone.Key] = nil
            table.insert(Told, Player)
        end
    end
    if #Told > 0 then
        Net:BroadcastTo(Told, "@Props/ZoneGone", Zone.Key)
    end
end

const function create(Position: Vector3): Zone
    const Zone: Zone = {
        Key = uuid(),
        Center = Position,
        Version = uuid(),
        Props = {},
        Count = 0,
        Members = {},
    }
    List[Zone.Key] = Zone
    Net:CreateRoom(room(Zone), {})
    for _, Player in Players:GetPlayers() do
        scan(Player, Zone)
    end
    return Zone
end

const function push(Zone: Zone, Change: Change)
    local Changes = Pending[Zone]
    if not Changes then
        Changes = {}
        Pending[Zone] = Changes
    end
    table.insert(Changes, Change)
end

const function attach(Item: Record, Zone: Zone, From: string?)
    Item.Zone = Zone.Key
    Zone.Props[Item.Key] = Item
    Zone.Count += 1
    Records[Item.Key] = Item
    push(Zone, { Kind = "Add", Prop = Item, From = From })
end

const function detach(Item: Record, Change: Change)
    const Zone = List[Item.Zone]
    if not Zone or Zone.Props[Item.Key] ~= Item then
        return
    end
    Zone.Props[Item.Key] = nil
    Zone.Count -= 1
    push(Zone, Change)
end

function Zones.claim(Position: Vector3): Zone
    local Best: Zone? = nil
    local Closest = math.huge
    for _, Zone in List do
        if gap(Zone, Position) <= 0 then
            const Distance = (Zone.Center - Position).Magnitude
            if Distance < Closest then
                Best = Zone
                Closest = Distance
            end
        end
    end
    return Best or create(Position)
end

function Zones.flush()
    for Zone, Changes in Pending do
        Pending[Zone] = nil
        if List[Zone.Key] ~= Zone then
            continue
        end
        const From = Zone.Version
        Zone.Version = uuid()
        for Player in Zone.Members do
            sentTo(Player)[Zone.Key] = Zone.Version
        end
        Net:SendToRoom(room(Zone), "@Props/Delta", Zone.Key, From, Zone.Version, Changes)
        if Zone.Count <= 0 then
            destroy(Zone)
        end
    end
end

function Zones.add(Items: { Record })
    for _, Item in Items do
        attach(Item, Zones.claim(Item.Pivot.Position), nil)
    end
    Zones.flush()
end

function Zones.move(Moves: { Move })
    for _, Entry in Moves do
        const Item = Entry.Record
        if Records[Item.Key] ~= Item then
            continue
        end
        Item.Pivot = Entry.Pivot
        Item.Scale = Entry.Scale
        Item.By = Entry.By
        Item.Changed = Entry.Stamp
        const Current = List[Item.Zone]
        if Current and gap(Current, Entry.Pivot.Position) <= 0 then
            push(Current, { Kind = "Move", Key = Item.Key, Pivot = Entry.Pivot, Scale = Entry.Scale, Changed = Item.Changed, By = Item.By })
        else
            const Target = Zones.claim(Entry.Pivot.Position)
            detach(Item, { Kind = "Transfer", Key = Item.Key, To = Target.Key })
            attach(Item, Target, if Current then Current.Key else nil)
        end
    end
    Zones.flush()
end

function Zones.remove(Items: { Record })
    for _, Item in Items do
        if Records[Item.Key] ~= Item then
            continue
        end
        Records[Item.Key] = nil
        detach(Item, { Kind = "Remove", Key = Item.Key })
    end
    Zones.flush()
end

function Zones.state(Item: Record, Name: string, Value: any)
    const Zone = List[Item.Zone]
    if not Zone or Records[Item.Key] ~= Item then
        return
    end
    push(Zone, { Kind = "State", Key = Item.Key, Name = Name, Value = Value, Changed = Item.Changed, By = Item.By })
    Zones.flush()
end

function Zones.record(Key: string): Record?
    return Records[Key]
end

function Zones.isMember(Player: Player, Key: string): boolean
    const Zone = List[Key]
    return Zone ~= nil and Zone.Members[Player] == true
end

function Zones.resend(Player: Player, Key: unknown)
    if type(Key) ~= "string" then
        return
    end
    const Zone = List[Key]
    if not Zone then
        Net:BroadcastTo(Player, "@Props/ZoneGone", Key)
        return
    end
    if not Zone.Members[Player] then
        return
    end
    local Times = Asked[Player]
    if not Times then
        Times = {}
        Asked[Player] = Times
    end
    const Now = os.clock()
    if Times[Key] and Now - Times[Key] < Zones.ResendCooldown then
        return
    end
    Times[Key] = Now
    sendSnapshot(Player, Zone)
end

function Zones.forget(Player: Player, Key: unknown)
    if type(Key) ~= "string" then
        return
    end
    const Zone = List[Key]
    if Zone and Zone.Members[Player] then
        return
    end
    const Known = Sent[Player]
    if Known then
        Known[Key] = nil
    end
end

function Zones.drop(Player: Player)
    for _, Zone in List do
        Zone.Members[Player] = nil
    end
    Sent[Player] = nil
    Asked[Player] = nil
end

function Zones.start()
    if Started then
        return
    end
    Started = true
    task.spawn(function()
        while true do
            task.wait(Config.MembershipInterval)
            for _, Player in Players:GetPlayers() do
                for _, Zone in List do
                    scan(Player, Zone)
                end
            end
        end
    end)
end

return Zones
