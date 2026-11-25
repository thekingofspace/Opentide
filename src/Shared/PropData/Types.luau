--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const signal = require(ReplicatedStorage.MainPackages.signal)
const Codec = require(script.Parent.Codec)

export type Value = Codec.Value
export type States = { [string]: Value }
export type Arrival = "Placed" | "Entered"

export type StateSpec = {
    Default: Value,
    Save: boolean?,
    Public: boolean?,
    check: ((Value: Value, Player: Player?) -> boolean)?,
}

export type FieldKind = "Color" | "Text" | "Number" | "Custom"

export type FieldContext = {
    Id: string,
    Value: any,
    get: () -> any,
    set: (Value: any) -> (),
}

export type Field = {
    Id: string,
    Kind: FieldKind,
    Label: string?,
    State: string?,
    Default: any,
    Min: number?,
    Max: number?,
    Step: number?,
    Placeholder: string?,
    MaxLength: number?,
    Height: number?,
    build: ((Context: FieldContext) -> { [any]: any })?,
}

export type ServerProp = {
    Key: string,
    Id: number,
    Owner: number,
    Pivot: CFrame,
    Scale: number,
    States: { [string]: any },
}

export type ServerBox = {
    Part: BasePart,
    Rest: CFrame,
    Prop: ServerProp,
    Data: { [any]: any },
    Delta: number,
    moveTo: (Self: ServerBox, Frame: CFrame) -> (),
}

export type ServerBoxSpec = {
    Size: Vector3?,
    Offset: CFrame?,
    Shape: Enum.PartType?,
    CanCollide: boolean?,
    Visible: boolean?,
    step: ((Box: ServerBox, Now: number, Delta: number) -> ())?,
}

export type Prop = {
    Key: string,
    Id: number,
    Owner: number,
    Zone: string,
    Pivot: CFrame,
    Scale: number,
    States: States,
    Data: { [any]: any },
    Stamp: number,
    Changed: number,
    By: number,
    RestBox: CFrame,
    RestSize: Vector3,
    Arrival: Arrival,
    Model: Model?,
    Mounted: boolean,
    Hidden: boolean,
    Destroyed: boolean,
    WidgetsEnabled: boolean,
    InfoEnabled: boolean,
    Placed: signal.Signal<...any>,
    ZoneEntered: signal.Signal<...any>,
    StateChanged: signal.Signal<...any>,
    Moved: signal.Signal<...any>,
    Removed: signal.Signal<...any>,
    WidgetSaved: signal.Signal<...any>,
    WidgetPressed: signal.Signal<...any>,
    getState: (Self: Prop, Name: string) -> Value?,
    setState: (Self: Prop, Name: string, Value: Value) -> boolean,
    setPublicState: (Self: Prop, Name: string, Value: Value) -> boolean,
    isOwner: (Self: Prop) -> boolean,
    elapsed: (Self: Prop) -> number,
    enableWidgets: (Self: Prop, Enabled: boolean?) -> (),
    enableInfo: (Self: Prop, Enabled: boolean?) -> (),
}

export type WidgetButton = {
    Id: string,
    Image: string?,
    Color: Color3?,
    Public: boolean?,
    pressed: ((Prop: Prop) -> ())?,
}

export type Widget = {
    Title: string?,
    Fields: { Field }?,
    Buttons: { WidgetButton }?,
}

export type Definition = {
    Name: string,
    Pack: string?,
    Limit: number?,
    Model: string,
    Icon: CFrame?,
    MinScale: number?,
    MaxScale: number?,
    States: { [string]: StateSpec }?,
    Persist: boolean?,
    IdleRate: number?,
    Widget: Widget?,
    Info: boolean?,
    ServerBox: ServerBoxSpec?,
    onPlaced: ((Prop: Prop) -> ())?,
    onZoneEnter: ((Prop: Prop, Elapsed: number) -> ())?,
    onState: ((Prop: Prop, Name: string, Value: Value, Old: Value?) -> ())?,
    onMoved: ((Prop: Prop, Pivot: CFrame, Scale: number) -> ())?,
    onIdle: ((Prop: Prop, Delta: number) -> ())?,
    onRemoved: ((Prop: Prop) -> ())?,
    onPreview: ((Model: Model, States: States) -> ())?,
    onWidgetSave: ((Prop: Prop, Values: { [string]: any }) -> ())?,
    serialize: ((States: States, Owner: Player?) -> States)?,
    deserialize: ((Saved: States, Owner: Player?) -> States)?,
}

export type Definitions = { [number]: Definition }

return {}
