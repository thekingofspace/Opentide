--!strict
export type Info = {
    Id: number,
    Name: string,
    Pack: string?,
    Limit: number?,
    Icon: CFrame?,
    MinScale: number?,
    MaxScale: number?,
}

export type Params = {
    Text: string?,
    Pack: string?,
    Page: number?,
    PageSize: number?,
}

export type Result = {
    Items: { Info },
    Page: number,
    Pages: number,
    Total: number,
}

type Record = {
    Info: Info,
    Name: string,
    Haystack: string,
}

type Fields = {
    Records: { Record },
    Packs: { [string]: { Record } },
    PackNames: { string },
    ById: { [number]: Info },
    Memo: { [string]: { Record } },
    MemoOrder: { string },
}

const Query = {
    PageSize = 20,
    MemoLimit = 24,
    FreeName = "free",
}

const Methods = {}
Methods.__index = Methods

export type Index = typeof(setmetatable({} :: Fields, Methods))

const function words(Text: string): { string }
    const Found = {}
    for Word in string.gmatch(string.lower(Text), "%S+") do
        table.insert(Found, Word)
    end
    return Found
end

const function remember(Self: Index, Key: string, Matched: { Record })
    const Order = Self.MemoOrder
    const At = table.find(Order, Key)
    if At then
        table.remove(Order, At)
    end
    table.insert(Order, Key)
    Self.Memo[Key] = Matched
    while #Order > Query.MemoLimit do
        const Oldest = table.remove(Order, 1)
        if Oldest then
            Self.Memo[Oldest] = nil
        end
    end
end

const function filter(Self: Index, Text: string?, Pack: string?): { Record }
    const Words = words(Text or "")
    const Normal = table.concat(Words, " ")
    const PackKey = if Pack then string.lower(Pack) else ""
    const Key = `{Normal}\0{PackKey}`

    const Cached = Self.Memo[Key]
    if Cached then
        remember(Self, Key, Cached)
        return Cached
    end

    local Pool = if PackKey ~= "" then (Self.Packs[PackKey] or {}) else Self.Records
    local Longest = -1
    for _, Other in Self.MemoOrder do
        const Split = string.find(Other, "\0", 1, true)
        if Split and string.sub(Other, Split + 1) == PackKey then
            const Earlier = string.sub(Other, 1, Split - 1)
            if #Earlier > Longest and string.sub(Normal, 1, #Earlier) == Earlier then
                Longest = #Earlier
                Pool = Self.Memo[Other]
            end
        end
    end

    if #Words == 0 then
        remember(Self, Key, Pool)
        return Pool
    end

    const Matched: { Record } = {}
    for _, Record in Pool do
        local Passes = true
        for _, Word in Words do
            if not string.find(Record.Haystack, Word, 1, true) then
                Passes = false
                break
            end
        end
        if Passes then
            table.insert(Matched, Record)
        end
    end

    remember(Self, Key, Matched)
    return Matched
end

function Query.packOf(Info: Info): string
    return Info.Pack or Query.FreeName
end

function Query.new(Catalog: { Info }): Index
    const Records: { Record } = {}
    const ById: { [number]: Info } = {}

    for _, Info in Catalog do
        if type(Info) == "table" and type(Info.Id) == "number" and type(Info.Name) == "string" and (Info.Pack == nil or type(Info.Pack) == "string") then
            const Name = string.lower(Info.Name)
            table.insert(Records, {
                Info = Info,
                Name = Name,
                Haystack = `{Name}\n{string.lower(Query.packOf(Info))}`,
            })
            ById[Info.Id] = Info
        end
    end

    table.sort(Records, function(A: Record, B: Record): boolean
        return A.Name < B.Name
    end)

    const Packs: { [string]: { Record } } = {}
    const PackNames: { string } = {}
    for _, Record in Records do
        const PackName = Query.packOf(Record.Info)
        const PackKey = string.lower(PackName)
        local List = Packs[PackKey]
        if not List then
            List = {}
            Packs[PackKey] = List
            table.insert(PackNames, PackName)
        end
        table.insert(List, Record)
    end
    table.sort(PackNames)

    return setmetatable({
        Records = Records,
        Packs = Packs,
        PackNames = PackNames,
        ById = ById,
        Memo = {},
        MemoOrder = {},
    } :: Fields, Methods)
end

function Methods.search(Self: Index, Params: Params?): Result
    const Given: Params = Params or {}
    const Size = math.max(1, math.floor(Given.PageSize or Query.PageSize))
    const Matched = filter(Self, Given.Text, Given.Pack)
    const Total = #Matched
    const Pages = math.max(1, math.ceil(Total / Size))
    const Page = math.clamp(math.floor(Given.Page or 1), 1, Pages)
    const First = (Page - 1) * Size + 1

    const Items: { Info } = {}
    for Position = First, math.min(First + Size - 1, Total) do
        table.insert(Items, Matched[Position].Info)
    end

    return {
        Items = Items,
        Page = Page,
        Pages = Pages,
        Total = Total,
    }
end

function Methods.get(Self: Index, Id: number): Info?
    return Self.ById[Id]
end

function Methods.packs(Self: Index): { string }
    return table.clone(Self.PackNames)
end

function Methods.count(Self: Index): number
    return #Self.Records
end

return Query
