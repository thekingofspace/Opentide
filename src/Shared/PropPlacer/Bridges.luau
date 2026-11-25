--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const signal = require(ReplicatedStorage.MainPackages.signal)

export type Entry = {
    Id: number?,
    Name: string,
    Pack: string?,
    Limit: (number | string)?,
    Model: PVInstance?,
    CFrame: CFrame?,
}

export type ToolView = {
    Visible: boolean,
    Kind: string,
    Increment: string,
    Space: string,
    Control: string?,
    Axis: string?,
    Busy: boolean,
}

export type PageBridge = signal.Bridge<(number, number), (number?)>
export type SearchBridge = signal.Bridge<(string), (number?)>
export type SelectBridge = signal.Bridge<(Entry), ()>
export type ActionBridge = signal.Bridge<(string), ()>
export type SaveBridge = signal.Bridge<(string, number?, string?), ()>

const Bridges: {
    read Page: PageBridge,
    read Search: SearchBridge,
    read Select: SelectBridge,
    read Tool: ActionBridge,
    read Action: ActionBridge,
    read Saves: SaveBridge,
} = table.freeze({
    Page = signal.bridge() :: PageBridge,
    Search = signal.bridge() :: SearchBridge,
    Select = signal.bridge() :: SelectBridge,
    Tool = signal.bridge() :: ActionBridge,
    Action = signal.bridge() :: ActionBridge,
    Saves = signal.bridge() :: SaveBridge,
})

return Bridges
