--!strict
export type Kind = {
    Id: string,
    Name: string,
    Sides: number,
    Order: number,
}

const Kinds: { Kind } = {
    { Id = "D4", Name = "d4", Sides = 4, Order = 1 },
    { Id = "D6", Name = "d6", Sides = 6, Order = 2 },
    { Id = "D8", Name = "d8", Sides = 8, Order = 3 },
    { Id = "D10", Name = "d10", Sides = 10, Order = 4 },
    { Id = "D12", Name = "d12", Sides = 12, Order = 5 },
    { Id = "D20", Name = "d20", Sides = 20, Order = 6 },
    { Id = "D100", Name = "d100", Sides = 100, Order = 7 },
}

return Kinds
