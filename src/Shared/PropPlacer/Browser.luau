--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const PropData = require(ReplicatedStorage.Shared.PropData)
const PropPlacer = require(script.Parent)
const Query = require(script.Parent.Query)
const Cache = require(script.Parent.Cache)
const Sounds = require(ReplicatedStorage.Shared.Sounds)

const Browser = {
    PageSize = 20,
    FetchTimeout = 5,
}

local Index: Query.Index? = nil
local Text = ""
local Pack: string? = nil
const Unbinds: { () -> () } = {}

function Browser.catalog(): Query.Index
    const Existing = Index
    if Existing then
        return Existing
    end
    const Made = Query.new(PropData.all())
    Index = Made
    return Made
end

function Browser.refresh()
    Index = nil
end

function Browser.show(Page: number): number
    const Result = Browser.catalog():search({
        Text = Text,
        Pack = Pack,
        Page = Page,
        PageSize = Browser.PageSize,
    })

    const Ids: { number } = {}
    for _, Info in Result.Items do
        table.insert(Ids, Info.Id)
    end
    const Models = Cache.fetch(Ids, Browser.FetchTimeout)

    const Entries: { PropPlacer.Entry } = {}
    for _, Info in Result.Items do
        table.insert(Entries, {
            Id = Info.Id,
            Name = Info.Name,
            Pack = Info.Pack,
            Limit = Info.Limit,
            Model = Models[Info.Id] :: PVInstance?,
            CFrame = Info.Icon,
        })
    end
    PropPlacer.loadEntries(Entries)
    return Result.Page
end

function Browser.setPack(Name: string?): number
    Pack = Name
    return Browser.show(1)
end

function Browser.stop()
    for _, Unbind in Unbinds do
        Unbind()
    end
    table.clear(Unbinds)
end

function Browser.start(): () -> ()
    Browser.stop()
    table.insert(Unbinds, PropPlacer.bindPage(function(Requested: number, _: number): number?
        Sounds.play("PageTurn")
        return Browser.show(Requested)
    end))
    table.insert(Unbinds, PropPlacer.bindSearch(function(Typed: string): number?
        Text = Typed
        return Browser.show(1)
    end))
    task.spawn(function()
        PropPlacer.setPage(Browser.show(1))
    end)
    return Browser.stop
end

return Browser
