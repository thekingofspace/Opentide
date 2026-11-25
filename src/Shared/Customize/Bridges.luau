--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const signal = require(ReplicatedStorage.MainPackages.signal)

export type ActBridge = signal.Bridge<(string, any?, any?), ()>

export type Choice = {
    Id: string,
    Name: string,
    Active: boolean,
}

export type BodyView = {
    Skin: Color3?,
    Sizes: { [string]: string },
    ScaleParts: boolean,
    Pick: string?,
    PickLabel: string,
    PickHidden: boolean,
}

export type ClothingCard = {
    Id: string,
    Name: string,
    Asset: number?,
    Active: boolean,
}

export type ClothesView = {
    Shown: boolean,
    Ids: boolean,
    Shirt: string,
    Pants: string,
}

export type PartRow = {
    Id: string,
    Name: string,
    Tag: string,
}

export type GroupRow = {
    Id: string,
    Name: string,
    Code: string?,
    Members: { PartRow },
}

export type RigView = {
    Groups: { GroupRow },
    Loose: { PartRow },
}

export type EditorView = {
    Kind: "Part" | "Group",
    Id: string,
    Name: string,
    Label: string,
    Texture: string,
    Mode: string,
    Attach: string?,
    Color: Color3?,
}

export type SlotView = {
    Name: string,
    Detail: string,
    Stamp: string,
    Filled: boolean,
    Confirm: boolean,
    ConfirmClear: boolean,
}

export type ShopCard = {
    Id: string,
    Name: string,
    Reward: string,
    Price: string,
    Model: Instance?,
    Image: string?,
    Active: boolean,
}

export type ShopDetail = {
    Id: string,
    Name: string,
    Detail: string,
    Reward: string,
    Price: string,
    Model: Instance?,
    Image: string?,
    Giftable: boolean,
    Gifting: boolean,
    Ready: boolean,
    Includes: { string },
}

export type ShapeCard = {
    Id: string,
    Name: string,
    Model: Instance?,
}

export type ToolCard = {
    Id: string,
    Name: string,
    Detail: string,
    Locked: boolean,
    Active: boolean,
}

export type ToolPartRow = {
    Path: string,
    Label: string,
    Name: string,
    Required: boolean,
    Depth: number,
}

export type SlotCard = {
    Slot: number,
    Name: string,
    Filled: boolean,
    Picked: boolean,
    Clear: boolean,
    Model: Model?,
}

export type ToolPageView = {
    Mode: string,
    Title: string,
    Name: string,
    Detail: string,
    Equipping: boolean,
}

export type SlotBarView = {
    Title: string,
    Slots: { SlotCard },
}

export type MountChoice = {
    Id: string,
    Name: string,
    Detail: string,
    Locked: boolean,
    Active: boolean,
}

export type MountView = {
    Title: string,
    Choices: { MountChoice },
}

export type StatRow = {
    Id: string,
    Name: string,
    Detail: string,
    Value: string,
    Bonus: string,
}

export type InfoView = {
    Tab: string,
    Nickname: string,
    Description: string,
    Stats: { StatRow },
}

export type HolsterView = {
    Shown: boolean,
    On: boolean,
    Attach: string,
    Size: string,
    Mode: string,
    Looking: string,
}

const Bridges: {
    read Nav: ActBridge,
    read Body: ActBridge,
    read Rig: ActBridge,
    read Editor: ActBridge,
    read Saves: ActBridge,
    read Shop: ActBridge,
    read Picker: ActBridge,
    read Clothes: ActBridge,
    read Tools: ActBridge,
    read Info: ActBridge,
} = table.freeze({
    Nav = signal.bridge() :: ActBridge,
    Body = signal.bridge() :: ActBridge,
    Rig = signal.bridge() :: ActBridge,
    Editor = signal.bridge() :: ActBridge,
    Saves = signal.bridge() :: ActBridge,
    Shop = signal.bridge() :: ActBridge,
    Picker = signal.bridge() :: ActBridge,
    Clothes = signal.bridge() :: ActBridge,
    Tools = signal.bridge() :: ActBridge,
    Info = signal.bridge() :: ActBridge,
})

return Bridges
