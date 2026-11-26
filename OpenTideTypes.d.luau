export type function PartialOf(Target: type, Known: type)
	assert(Target:is("table"), "Partial expects a table type")

	const Required = {}
	if Known:is("table") then
		for Key in Known:properties() do
			Required[tostring(Key:value())] = true
		end
	elseif not Known:is("never") then
		const Keys = if Known:is("union") then Known:components() else { Known }
		for _, Key in Keys do
			assert(
				Key:is("singleton"),
				'Partial expects known keys as a table like { Name: any } or string literals like "Name" | "Level"'
			)
			Required[tostring(Key:value())] = true
		end
	end

	const Result = types.newtable()
	const Seen = {}

	for Key, Property in Target:properties() do
		const Name = tostring(Key:value())
		const Keep = Required[Name] == true
		Seen[Name] = true

		const Read = if Property.read and not Keep then types.optional(Property.read) else Property.read
		const Write = if Property.write and not Keep then types.optional(Property.write) else Property.write

		if Read and Write and Property.read == Property.write then
			Result:setproperty(Key, Read)
		else
			if Read then
				Result:setreadproperty(Key, Read)
			end
			if Write then
				Result:setwriteproperty(Key, Write)
			end
		end
	end

	for Name in Required do
		assert(Seen[Name], 'Partial: "' .. Name .. '" is not a key of this table')
	end

	const Indexer = Target:indexer()
	if Indexer then
		Result:setindexer(Indexer.index, Indexer.readresult)
	end

	return Result
end

export type Partial<Target, Known = {}> = PartialOf<Target, Known>

export type Self = { read __TraitSelf: true }

export type function Trait(Definition: type)
	assert(Definition:is("table"), "Trait expects a table type")
	return Definition
end

export type function ComposeOf(Traits: type)
	assert(Traits:is("function"), "ComposeOf is internal, use Compose<Traits...>")
	const Object = types.newtable()
	const Marker = types.singleton("__TraitSelf")
	const Checked = {}
	const Swapped = {}
	const Owners = {}

	const function isSelf(Target: type): boolean
		return Target:is("table") and Target:readproperty(Marker) ~= nil
	end

	const function mentions(Target: type): boolean
		if isSelf(Target) then
			return true
		end
		const Known = Checked[Target]
		if Known ~= nil then
			return Known
		end
		Checked[Target] = false
		local Found = false
		if Target:is("union") or Target:is("intersection") then
			for _, Part in Target:components() do
				Found = Found or mentions(Part)
			end
		elseif Target:is("function") then
			for _, Pack in { Target:parameters(), Target:returns() } do
				for _, Item in Pack.head or {} do
					Found = Found or mentions(Item)
				end
				if Pack.tail then
					Found = Found or mentions(Pack.tail)
				end
			end
		elseif Target:is("table") then
			for _, Property in Target:properties() do
				if Property.read then
					Found = Found or mentions(Property.read)
				end
				if Property.write then
					Found = Found or mentions(Property.write)
				end
			end
			const Indexer = Target:indexer()
			if Indexer then
				Found = Found or mentions(Indexer.index) or mentions(Indexer.readresult)
			end
		end
		Checked[Target] = Found
		return Found
	end

	local swap: (Target: type) -> type

	const function fill(Into: type, From: type)
		for Key, Property in From:properties() do
			const Read = if Property.read then swap(Property.read) else nil
			const Write = if Property.write then swap(Property.write) else nil
			if Read and Property.read == Property.write then
				Into:setproperty(Key, Read)
			else
				if Read then
					Into:setreadproperty(Key, Read)
				end
				if Write then
					Into:setwriteproperty(Key, Write)
				end
			end
		end
		const Indexer = From:indexer()
		if Indexer then
			Into:setindexer(swap(Indexer.index), swap(Indexer.readresult))
		end
	end

	swap = function(Target: type): type
		if isSelf(Target) then
			return Object
		end
		if not mentions(Target) then
			return Target
		end
		const Done = Swapped[Target]
		if Done then
			return Done
		end
		if Target:is("union") or Target:is("intersection") then
			const Parts = {}
			for _, Part in Target:components() do
				table.insert(Parts, swap(Part))
			end
			return if Target:is("union") then types.unionof(table.unpack(Parts)) else types.intersectionof(table.unpack(Parts))
		end
		if Target:is("function") then
			const function pack(Pack: any): any
				const Head = {}
				for Index, Item in Pack.head or {} do
					Head[Index] = swap(Item)
				end
				return { head = Head, tail = if Pack.tail then swap(Pack.tail) else nil }
			end
			return types.newfunction(pack(Target:parameters()), pack(Target:returns()), Target:generics())
		end
		if Target:is("table") then
			const Copy = types.newtable()
			Swapped[Target] = Copy
			fill(Copy, Target)
			return Copy
		end
		return Target
	end

	const Parts: { type } = {}
	const function gather(Target: type)
		if Target:is("intersection") then
			for _, Inner in Target:components() do
				gather(Inner)
			end
		else
			table.insert(Parts, Target)
		end
	end
	for _, Given in Traits:parameters().head or {} do
		gather(Given)
	end

	for _, Part in Parts do
		assert(Part:is("table"), "Compose expects trait table types")
		for Key in Part:properties() do
			const Name = tostring(Key:value())
			assert(Owners[Name] == nil, 'Compose: "' .. Name .. '" comes from more than one trait')
			Owners[Name] = true
		end
		assert(not (Part:indexer() and Object:indexer()), "Compose: more than one trait has an indexer")
		fill(Object, Part)
	end

	return Object
end

export type Compose<Traits...> = ComposeOf<(Traits...) -> ()>

export type SavedProp = {
    Id: number,
    Pivot: { number },
    Scale: number,
    States: { [string]: any }?,
}

export type PropSave = {
    Name: string,
    Stamp: number,
    Props: { SavedProp },
}

export type LookPart = {
    Id: string,
    Kind: "Asset" | "Builtin" | "Default",
    Asset: number?,
    Builtin: string?,
    Target: string?,
    Attach: string,
    Offset: { number },
    Scale: { number },
    Color: { number }?,
    Material: string?,
    Texture: string?,
    Removed: boolean?,
    Name: string?,
    Group: string?,
    Piece: string?,
}

export type LookBody = {
    Color: { number }?,
    Material: string?,
    Texture: string?,
    Hidden: boolean?,
    Name: string?,
}

export type LookGroup = {
    Name: string,
    Code: string?,
}

export type Look = {
    Version: number,
    Skin: { number }?,
    Swaps: { [string]: string },
    Body: { [string]: LookBody },
    Parts: { LookPart },
    Groups: { [string]: LookGroup },
    Height: number?,
    Width: number?,
    Depth: number?,
    Head: number?,
    ScaleParts: boolean?,
    Animation: string?,
    Shirt: number?,
    Pants: number?,
}

export type LookSave = {
    Name: string,
    Stamp: number,
    Look: Look,
    Tools: { [string]: ToolBuild }?,
}

export type ToolHolster = {
    On: boolean,
    Attach: string,
    Offset: { number },
    Size: number,
}

export type ToolBuild = {
    Tool: string,
    Parts: { [string]: string },
    Holster: ToolHolster?,
}

export type BioData = {
    Nickname: string,
    Description: string,
    Stats: { [string]: number },
}

export type ToolsData = {
    Slots: { [string]: ToolBuild },
    Builds: { [string]: ToolBuild }?,
    Links: { [string]: string }?,
}

export type ShopGift = {
    To: number,
    Item: string,
    Stamp: number,
}

export type PlayerData = {
    PropCount: number,
    OwnedPacks: { [string]: boolean },
    PropSaves: { [string]: PropSave },
    BuildTool: boolean?,
    Look: Look?,
    LookSaves: { [string]: LookSave },
    Settings: { [string]: boolean | number }?,
    Playtime: number?,
    FirstJoined: number?,
    MetaVisionLast: number?,
    PurchaseIds: { string }?,
    Tools: ToolsData?,
    Bio: BioData?,
    ShopGifts: { [string]: ShopGift }?,
}