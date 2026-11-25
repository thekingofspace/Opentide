--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")
const Workspace = game:GetService("Workspace")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const PropData = require(ReplicatedStorage.Shared.PropData)
const Config = require(ReplicatedStorage.Shared.PropData.Config)
const SaveFormat = require(ReplicatedStorage.Shared.PropData.SaveFormat)
const PropPlacer = require(script.Parent)
const Cache = require(script.Parent.Cache)
const Container = require(script.Parent.Container)
const Tools = require(script.Parent.Tools)
const World = require(script.Parent.World)
const Sounds = require(ReplicatedStorage.Shared.Sounds)

export type Commit = (Target: Container.Container) -> (boolean, string?)

export type Options = {
    commit: Commit,
    finished: (() -> ())?,
    cancelled: (() -> ())?,
}

type Session = {
    Target: Container.Container,
    Options: Options,
}

const Placement = {
    FetchTimeout = 5,
    LoadTimeout = 15,
    SpawnDistance = 10,
    HiddenDepth = 50,
    RayLength = 4096,
}

local Current: Session? = nil
local Token = 0

const function finish(Session: Session): boolean
    if Current ~= Session then
        return false
    end
    Current = nil
    Tools.stop()
    Container.destroy(Session.Target)
    return true
end

const function frontPoint(): CFrame
    const Character = Players.LocalPlayer.Character
    const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    if Root and Root:IsA("BasePart") then
        return CFrame.new(Root.Position + Root.CFrame.LookVector * Placement.SpawnDistance - Vector3.new(0, 3, 0))
    end
    const Camera = Workspace.CurrentCamera
    return if Camera then CFrame.new(Camera.CFrame.Position + Camera.CFrame.LookVector * 20) else CFrame.identity
end

const function mouseHit(Ignore: { Instance }): Vector3?
    const Camera = Workspace.CurrentCamera
    if not Camera then
        return nil
    end
    const Mouse = UserInputService:GetMouseLocation()
    const Ray = Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
    const Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = Ignore
    const Result = Workspace:Raycast(Ray.Origin, Ray.Direction * Placement.RayLength, Params)
    return if Result then Result.Position else nil
end

const function spawnPoint(Target: Container.Container): CFrame
    const Ignore: { Instance } = { Target.Model }
    const Character = Players.LocalPlayer.Character
    if Character then
        table.insert(Ignore, Character)
    end
    const Hit = mouseHit(Ignore)
    if Hit then
        return CFrame.new(Hit)
    end
    if not Tools.followsMouse() then
        return frontPoint()
    end
    const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    const Spot = if Root and Root:IsA("BasePart") then Root.Position else Vector3.zero
    return CFrame.new(Spot.X, Workspace.FallenPartsDestroyHeight + Placement.HiddenDepth, Spot.Z)
end

const function commit(Session: Session)
    if Current ~= Session then
        return
    end
    Tools.setBusy(true)
    const Ran, Ok, Problem = pcall(Session.Options.commit, Session.Target)
    if Current ~= Session then
        return
    end
    if Ran and Ok then
        Sounds.play("PlaceConfirm")
        finish(Session)
        const Finished = Session.Options.finished
        if Finished then
            Finished()
        end
        return
    end
    Tools.setBusy(false)
    PropPlacer.toast(if not Ran then "Something went wrong placing that" else Problem or "That did not work")
    if not Ran then
        warn(`[Placement] commit failed: {Ok}`)
    end
end

function Placement.begin(Target: Container.Container, Given: Options)
    Placement.cancel()
    Sounds.play("PlaceStart")
    const Session: Session = {
        Target = Target,
        Options = Given,
    }
    Current = Session
    Tools.begin(Target, {
        place = function()
            commit(Session)
        end,
        cancel = function()
            if finish(Session) then
                Sounds.play("PlaceCancel")
                const Cancelled = Given.cancelled
                if Cancelled then
                    Cancelled()
                end
            end
        end,
    })
end

function Placement.cancel()
    Token += 1
    const Session = Current
    if Session and finish(Session) then
        const Cancelled = Session.Options.cancelled
        if Cancelled then
            Cancelled()
        end
    end
end

function Placement.active(): boolean
    return Current ~= nil
end

function Placement.send(Target: Container.Container): (boolean, string?)
    const Items: { SaveFormat.Item } = {}
    for _, Move in Container.transforms(Target) do
        table.insert(Items, {
            Id = Move.Item.Id,
            Pivot = Move.Pivot,
            Scale = Move.Scale,
            States = Move.Item.States,
        })
    end
    if #Items == 0 then
        return false, "There is nothing to place"
    end
    const Reply = NetWatch.PropPlacer:Call("@Props/Place", Items)
    if type(Reply) ~= "table" then
        return false, "The server did not answer, try again"
    end
    if not Reply.Ok then
        return false, if type(Reply.Error) == "string" then Reply.Error else "That could not be placed"
    end
    if type(Reply.Keys) == "table" then
        World.await(Reply.Keys, Config.ArrivalWait)
    end
    return true, nil
end

function Placement.owns(Pack: string?): boolean
    if Pack == nil or RunService:IsStudio() then
        return true
    end
    const Stats = World.stats()
    return Stats ~= nil and (Stats.AllPacks or Stats.Packs[Pack] == true)
end

function Placement.placed(Id: number): number
    const Stats = World.stats()
    return if Stats then Stats.PerId[tostring(Id)] or 0 else 0
end

function Placement.room(Id: number): (number, string?)
    const Stats = World.stats()
    if not Stats then
        return 0, "Your data is still loading"
    end
    const Info = PropData.get(Id)
    local Free = math.max(Stats.Max - Stats.Count, 0)
    if Free <= 0 then
        return 0, `You have reached your prop limit ({Stats.Count}/{Stats.Max})`
    end
    const Limit = if Info then Info.Limit else nil
    if Limit then
        const Left = math.max(Limit - Placement.placed(Id), 0)
        if Left <= 0 then
            return 0, `You already placed the most {Info and Info.Name or "of that prop"} you can ({Limit})`
        end
        Free = math.min(Free, Left)
    end
    return Free, nil
end

function Placement.place(Id: number)
    const Info = PropData.get(Id)
    if not Info then
        return
    end
    if not Placement.owns(Info.Pack) then
        PropPlacer.toast(if World.stats() then `You do not own the {Info.Pack} pack` else "Your data is still loading")
        return
    end
    const Free, Problem = Placement.room(Id)
    if Free <= 0 then
        PropPlacer.toast(Problem or "You can not place that right now")
        return
    end
    Token += 1
    const Mine = Token
    const Source = Cache.fetch({ Id }, Placement.FetchTimeout)[Id]
    if Mine ~= Token then
        return
    end
    const Model = if Source then Cache.spawn(Id) else nil
    if not Model then
        PropPlacer.toast(`{Info.Name} could not load, try again`)
        return
    end

    PropData.preview(Id, Model, nil)
    const Target = Container.new()
    Container.add(Target, Id, Model, nil, nil)
    Container.fit(Target)
    Target.Model:PivotTo(spawnPoint(Target))
    Placement.begin(Target, {
        commit = Placement.send,
    })
end

function Placement.load(Given: { SaveFormat.Item })
    Token += 1
    const Mine = Token
    const Stats = World.stats()
    if not Stats then
        PropPlacer.toast("Your data is still loading")
        return
    end
    const Items: { SaveFormat.Item } = {}
    const Ids: { number } = {}
    const Planned: { [number]: number } = {}
    local Locked = 0
    local Limited = 0
    local Free = math.max(Stats.Max - Stats.Count, 0)
    for _, Item in Given do
        const Info = PropData.get(Item.Id)
        const Limit = if Info then Info.Limit else nil
        if Info and not Placement.owns(Info.Pack) then
            Locked += 1
            continue
        end
        const Using = (Planned[Item.Id] or 0) + 1
        if Free <= 0 or (Limit and Placement.placed(Item.Id) + Using > Limit) then
            Limited += 1
            continue
        end
        Planned[Item.Id] = Using
        Free -= 1
        table.insert(Items, Item)
        table.insert(Ids, Item.Id)
    end
    if Locked > 0 then
        PropPlacer.toast(`{Locked} props are from packs you do not own and were skipped`)
    end
    if Limited > 0 then
        PropPlacer.toast(`{Limited} props would go over your limits and were skipped`)
    end
    if #Items == 0 then
        return
    end
    PropPlacer.toast(`Loading {#Items} props...`, "Info")
    const Found = Cache.fetch(Ids, Placement.LoadTimeout)
    if Mine ~= Token then
        return
    end

    const Target = Container.new()
    local Missing = 0
    for _, Item in Items do
        const Model = if Found[Item.Id] then Cache.spawn(Item.Id) else nil
        if not Model then
            Missing += 1
            continue
        end
        Model:ScaleTo(Item.Scale)
        Model:PivotTo(Item.Pivot)
        PropData.preview(Item.Id, Model, Item.States)
        Container.add(Target, Item.Id, Model, nil, Item.States)
    end
    if #Target.Items == 0 then
        Container.destroy(Target)
        PropPlacer.toast("None of those props could load")
        return
    end
    if Missing > 0 then
        PropPlacer.toast(`{Missing} props could not load and were skipped`)
    end
    Container.fit(Target)
    Target.Model:PivotTo(spawnPoint(Target))
    Placement.begin(Target, {
        commit = Placement.send,
    })
end

return Placement
