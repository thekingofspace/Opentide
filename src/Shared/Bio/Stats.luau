--!strict
export type StatDef = {
    Id: string,
    Name: string,
    Description: string?,
    Order: number,
    Min: number,
    Max: number,
    Default: number,
    Center: number?,
    PerBonus: number,
    AllowNegative: boolean?,
}

const Stats = {
    AttributePrefix = "Stat_",
    List = {
        {
            Id = "Strength",
            Name = "strength",
            Description = "how strong you are",
            Order = 1,
            Min = 0,
            Max = 20,
            Default = 10,
            Center = 10,
            PerBonus = 2,
            AllowNegative = true,
        },
    } :: { StatDef },
}

function Stats.get(Id: unknown): StatDef?
    for _, Def in Stats.List do
        if Def.Id == Id then
            return Def
        end
    end
    return nil
end

function Stats.sorted(): { StatDef }
    const Made = table.clone(Stats.List)
    table.sort(Made, function(A: StatDef, B: StatDef): boolean
        return A.Order < B.Order
    end)
    return Made
end

function Stats.clamp(Def: StatDef, Value: unknown): number
    if type(Value) ~= "number" or Value ~= Value then
        return Def.Default
    end
    return math.clamp(math.floor(Value), Def.Min, Def.Max)
end

function Stats.bonus(Def: StatDef, Value: number): number
    const Raw = math.floor((Value - (Def.Center or 0)) / math.max(Def.PerBonus, 1))
    return if Def.AllowNegative then Raw else math.max(Raw, 0)
end

function Stats.valueOf(Player: Player, Def: StatDef): number
    return Stats.clamp(Def, Player:GetAttribute(Stats.AttributePrefix .. Def.Id))
end

function Stats.signed(Value: number): string
    return if Value >= 0 then `+{Value}` else tostring(Value)
end

return Stats
