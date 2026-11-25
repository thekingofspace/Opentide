--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const ReplicationPP = require(ReplicatedStorage.MainPackages.ReplicationPP)
const signal = require(ReplicatedStorage.MainPackages.signal)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)

const Assets = {
    Attribute = "ToolAssetKey",
    RetryAfter = 5,
    Arrived = signal.new(),
}

const Net = NetWatch.Tools
const Known: { [string]: Instance } = {}
const Asked: { [string]: number } = {}
const Missing: { [string]: boolean } = {}
local Waiting: { string } = {}
local Queued = false
local Started = false

const function remember(Asset: Instance)
    const Key = Asset:GetAttribute(Assets.Attribute)
    if type(Key) ~= "string" then
        return
    end
    Known[Key] = Asset
    Asked[Key] = nil
    Assets.Arrived:Fire(Key)
end

const function flush()
    Queued = false
    const Batch = Waiting
    Waiting = {}
    if #Batch == 0 then
        return
    end
    const Reply = Net:Call("@Tools/Assets", Batch)
    if type(Reply) ~= "table" then
        return
    end
    for _, Key in Reply.Unknown or {} do
        if type(Key) == "string" then
            Missing[Key] = true
            warn(`[Tools] there is no premade model for {Key} in ServerStorage.ToolAssets`)
        end
    end
end

function Assets.get(Kind: string, Id: string): Instance?
    const Key = `{Kind}:{Id}`
    const Found = Known[Key]
    if Found and Found.Parent then
        return Found
    end
    if Missing[Key] or not RunService:IsClient() then
        return nil
    end
    const Now = os.clock()
    if Asked[Key] and Now - Asked[Key] < Assets.RetryAfter then
        return nil
    end
    Asked[Key] = Now
    table.insert(Waiting, Key)
    if not Queued then
        Queued = true
        task.defer(flush)
    end
    return nil
end

function Assets.start()
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    for _, Asset in ReplicationPP.GetAssets() do
        remember(Asset)
    end
    ReplicationPP.OnReplication:Connect(remember)
end

return Assets
