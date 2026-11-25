--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerStorage = game:GetService("ServerStorage")

const ReplicationPP = require(ReplicatedStorage.MainPackages.ReplicationPP)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Tools = require(ReplicatedStorage.Shared.Tools)

const ToolAssets = {
    FolderName = "ToolAssets",
    MaxBatch = 64,
    Folders = {
        Tool = "Tools",
        Attachment = "Attachments",
    } :: { [string]: string },
}

const Net = NetWatch.Tools
local Started = false

function ToolAssets.get(Kind: string, Id: string): Instance?
    const Root = ServerStorage:FindFirstChild(ToolAssets.FolderName)
    const Group = ToolAssets.Folders[Kind]
    const Holder = if Root and Group then Root:FindFirstChild(Group) else nil
    const Found = if Holder then Holder:FindFirstChild(Id) else nil
    if Found then
        Found:SetAttribute(Tools.AssetAttribute, `{Kind}:{Id}`)
    end
    return Found
end

const function request(Player: Player, Keys: unknown): { Accepted: { string }, Unknown: { string } }
    const Reply = { Accepted = {} :: { string }, Unknown = {} :: { string } }
    if type(Keys) ~= "table" then
        return Reply
    end
    local Count = 0
    for _, Key in Keys :: { any } do
        Count += 1
        if Count > ToolAssets.MaxBatch or type(Key) ~= "string" then
            break
        end
        const Kind, Id = string.match(Key, "^(%a+):(.+)$")
        const Template = if Kind and Id then ToolAssets.get(Kind, Id) else nil
        if not Template then
            table.insert(Reply.Unknown, Key)
            continue
        end
        if not ReplicationPP.IsReplicated(Player, Template) and not ReplicationPP.IsPending(Player, Template) then
            ReplicationPP.ReplicateAsset(Player, Template)
        end
        table.insert(Reply.Accepted, Key)
    end
    return Reply
end

function ToolAssets.start()
    if Started then
        return
    end
    Started = true
    Tools.setSource(ToolAssets.get)
    Net:When("@Tools/Assets", request)
end

return ToolAssets
