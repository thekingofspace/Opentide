--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const PropData = require(ReplicatedStorage.Shared.PropData)

export type Declaration = { [any]: any }

export type BarButton = {
    Id: string,
    Image: string?,
    Color: Color3?,
    press: () -> (),
}

export type BarSpec = {
    Name: string,
    Adornee: Instance,
    Mount: Instance,
    Buttons: { BarButton },
    Size: number,
    MaxDistance: number,
    Shown: boolean,
}

export type WindowSpec = {
    Name: string,
    Title: string,
    Fields: { PropData.Field },
    Values: { [string]: any },
    Position: Vector2,
    Mount: Instance,
    save: () -> (),
    close: () -> (),
    focus: (Root: GuiObject) -> (),
}

export type InfoRow = {
    Label: string,
    Value: string,
}

export type InfoSpec = {
    Name: string,
    Title: string,
    Rows: { InfoRow },
    Position: Vector2,
    Mount: Instance,
    close: () -> (),
    focus: (Root: GuiObject) -> (),
}

export type SaveSlot = {
    Name: string,
    Detail: string,
    Stamp: string,
    Filled: boolean,
    Confirm: boolean,
    ConfirmClear: boolean,
}

return {}
