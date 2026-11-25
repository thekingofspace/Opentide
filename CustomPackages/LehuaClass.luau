--!strict
--!native

export type Method = (self: any, ...any) -> ...any

export type MemberTable = { [string]: any }

export type Object = { [string]: any }

export type Class = ((...any) -> Object) & { Name: string, [string]: any }

export type Interface = {
	__lehua: string,
	Name: string,
	Requires: { [string]: string },
	Extends: { Interface },
}

export type InterfaceSpec = {
	Name: string,
	Requires: { string } | { [string]: string },
	Extends: { Interface }?,
}

export type Metadata = { [any]: any }

export type Control = {
	__lehua: string,
	Get: Method?,
	Set: Method?,
}

export type ControlSpec = {
	Get: Method?,
	Set: Method?,
}

export type ValueFactory = {
	__lehua: string,
	Make: (...any) -> any,
	Args: { any },
	Count: number,
}

export type InheritPick = {
	Class: Class,
	Public: { string }?,
	Private: { string }?,
	Static: { string }?,
	Meta: { string }?,
}

export type Trait = {
	__lehua: string,
	Name: string,
	Public: MemberTable,
	Private: MemberTable,
	MergedPublic: MemberTable,
	MergedPrivate: MemberTable,
	Static: MemberTable,
	Meta: MemberTable,
	Metadata: Metadata,
	Requires: { [string]: string },
	Setups: { Method },
	Readies: { Method },
	Uses: { Trait },
}

export type TraitSpec = {
	Name: string,
	Public: MemberTable?,
	Private: MemberTable?,
	MergedPublic: MemberTable?,
	MergedPrivate: MemberTable?,
	Static: MemberTable?,
	Meta: MemberTable?,
	Requires: ({ string } | { [string]: string })?,
	Uses: { Trait }?,
	[string]: any,
}

export type TraitReport = {
	Name: string,
	Uses: { string },
	Public: { string },
	Private: { string },
	MergedPublic: { string },
	MergedPrivate: { string },
	Static: { string },
	Meta: { string },
	Requires: { [string]: string },
	Setups: number,
	Readies: number,
}

export type TraitPick = {
	Trait: Trait,
	Only: { string }?,
	Except: { string }?,
	Rename: { [string]: string }?,
}

export type DelegateSpec = {
	To: string,
	Methods: ({ string } | { [string]: string })?,
	Fields: ({ string } | { [string]: string })?,
	Getters: ({ string } | { [string]: string })?,
	Optional: boolean?,
}

export type ClassDecl = {
	Name: string,
	Private: MemberTable?,
	Public: MemberTable?,
	MergedPublic: MemberTable?,
	MergedPrivate: MemberTable?,
	Static: MemberTable?,
	Meta: MemberTable?,
	Inherits: (Class | { InheritPick })?,
	Traits: { Trait | TraitPick }?,
	Delegates: { DelegateSpec }?,
	Interfaces: { Interface }?,
	Strict: boolean?,
	Abstract: boolean?,
	Sealed: boolean?,
	[string]: any,
}

export type LehuaClassModule = {
	None: any,
	NewClassData: (decl: ClassDecl) -> Class,
	BuildClassData: (class: Class, ...any) -> Object,
	SuperGet: (class: Class, memberName: string) -> ((self: any, ...any) -> ...any),
	Interface: (spec: InterfaceSpec) -> Interface,
	Implements: (value: any, iface: Interface) -> (boolean, { string }),
	Trait: (spec: TraitSpec) -> Trait,
	Compose: (name: string, ...Trait) -> Trait,
	Delegate: (spec: DelegateSpec) -> MemberTable,
	IsTrait: (value: any) -> boolean,
	HasTrait: (value: any, traitOrName: Trait | string) -> boolean,
	TraitsOf: (value: any) -> { Trait },
	ControlSpecifier: (spec: ControlSpec) -> Control,
	IsControl: (value: any) -> boolean,
	SetValue: (factory: (...any) -> any, ...any) -> any,
	IsSetValue: (value: any) -> boolean,
	ControlsOf: (value: any) -> { [string]: string },
	Fuse: (...MemberTable) -> MemberTable,
	SourceOf: (value: any, memberName: string) -> string?,
	MergedKeys: (value: any) -> { [string]: string },
	TraitConflicts: (...Trait) -> { [string]: { string } },
	TraitInfo: (trait: Trait) -> TraitReport,
	IsA: (value: any, classOrName: Class | string) -> boolean,
	FetchClass: (value: any) -> Class?,
	GetMetaData: (value: any) -> Metadata,
	IsClass: (value: any) -> boolean,
	IsInstance: (value: any) -> boolean,
	Ref: (value: any) -> Object?,
	GetTopLevel: (value: any) -> Object,
	IsInterface: (value: any) -> boolean,
	TypeOf: (value: any) -> string,
	Inspect: (value: any) -> string,
	Globalize: (target: MemberTable?) -> LehuaClassModule,
}

type ClassDef = {
	name: string,
	strict: boolean,
	abstract: boolean,
	sealed: boolean,
	privFields: MemberTable,
	privMethods: MemberTable,
	pubFields: MemberTable,
	pubMethods: MemberTable,
	ownStatics: MemberTable,
	staticParents: { ClassDef },
	meta: MemberTable,
	construct: Method?,
	setup: Method?,
	setups: { Method },
	ready: Method?,
	readies: { Method },
	metadata: Metadata,
	ownMetadata: Metadata?,
	interfaces: { Interface },
	traits: { Trait },
	ancestors: { [any]: boolean },
	ancestorNames: { [string]: boolean },
	boundCache: MemberTable,
	privateKeySet: MemberTable,
	publicFieldSet: MemberTable,
	controls: { [string]: ControlEntry },
	mergedKeys: { [string]: string },
	memberSource: { [string]: string },
	handle: Class,
	innerMeta: any,
	outerMeta: any,
}

type ControlEntry = {
	Get: Method?,
	Set: Method?,
	Visibility: string,
	Owner: string,
}

type InstanceRecord = {
	def: ClassDef,
	fields: MemberTable,
	extraPublic: MemberTable,
	id: number,
}

type TraitDraft = {
	Meta: MemberTable,
	Metadata: Metadata,
	Setups: { Method },
	Readies: { Method },
}

type TraitFilter = {
	only: { [string]: boolean }?,
	except: { [string]: boolean }?,
	rename: { [string]: string }?,
}

type Probe = (name: string) -> (boolean, string)

local LehuaClass = {}

local INTERFACE_TAG = "LehuaClass.Interface"
local TRAIT_TAG = "LehuaClass.Trait"
local CONTROL_TAG = "LehuaClass.Control"
local SETVALUE_TAG = "LehuaClass.SetValue"

local None = table.freeze(setmetatable({}, table.freeze({
	__tostring = function()
		return "LehuaClass.None"
	end,
})))
LehuaClass.None = None

local handleToDef: { [any]: ClassDef } = setmetatable({}, { __mode = "k" }) :: any
local outerToRecord: { [any]: InstanceRecord } = setmetatable({}, { __mode = "k" }) :: any
local innerToOuter: { [any]: any } = setmetatable({}, { __mode = "kv" }) :: any
local innerToDef: { [any]: ClassDef } = setmetatable({}, { __mode = "k" }) :: any
local classesByName: { [string]: Class } = setmetatable({}, { __mode = "v" }) :: any

local instanceCounter = 0

local function wordList(t: { string }): string
	if #t == 0 then
		return "(none)"
	end
	return "'" .. table.concat(t, "', '") .. "'"
end

local function sortedKeys(map: { [string]: any }): { string }
	local keys: { string } = {}
	for k in pairs(map) do
		table.insert(keys, tostring(k))
	end
	table.sort(keys)
	return keys
end

local function deepCopy(value: any, seen: { [any]: any }): any
	if type(value) ~= "table" then
		return value
	end
	if value == None or outerToRecord[value] ~= nil or handleToDef[value] ~= nil then
		return value
	end
	local tag = rawget(value, "__lehua")
	if tag == INTERFACE_TAG or tag == TRAIT_TAG or tag == CONTROL_TAG or tag == SETVALUE_TAG then
		return value
	end
	local hit = seen[value]
	if hit ~= nil then
		return hit
	end
	local out: { [any]: any } = {}
	seen[value] = out
	for k, v in pairs(value) do
		out[deepCopy(k, seen)] = deepCopy(v, seen)
	end
	return setmetatable(out, getmetatable(value))
end

local function isSetValue(v: any): boolean
	return type(v) == "table" and rawget(v, "__lehua") == SETVALUE_TAG
end

function LehuaClass.SetValue(factory: (...any) -> any, ...: any): any
	if type(factory) ~= "function" then
		error("SetValue expects a function that produces the value", 2)
	end
	local packed = table.pack(...)
	return table.freeze({
		__lehua = SETVALUE_TAG,
		Make = factory,
		Args = table.freeze(table.move(packed, 1, packed.n, 1, {})),
		Count = packed.n,
	}) :: any
end

LehuaClass.IsSetValue = isSetValue

local function instantiateValue(v: any): any
	if v == None then
		return nil
	end
	if isSetValue(v) then
		local made = v :: ValueFactory
		return made.Make(table.unpack(made.Args, 1, made.Count))
	end
	return deepCopy(v, {})
end

local function mergeMetadata(into: Metadata, from: Metadata)
	local count = #from

	for i = 1, count do
		local value = from[i]
		local duplicate = false
		for j = 1, #into do
			if into[j] == value then
				duplicate = true
				break
			end
		end
		if not duplicate then
			table.insert(into, value)
		end
	end

	for k, v in pairs(from) do
		local isArrayEntry = type(k) == "number" and k % 1 == 0 and k >= 1 and k <= count
		if not isArrayEntry then
			local existing = into[k]
			if type(existing) == "table" and type(v) == "table" then
				local merged = {}
				mergeMetadata(merged, existing)
				mergeMetadata(merged, v)
				into[k] = merged
			else
				into[k] = v
			end
		end
	end
end

local function appendHook(list: { any }, fn: any)
	for _, existing in ipairs(list) do
		if existing == fn then
			return
		end
	end
	table.insert(list, fn)
end

local function unwrapOne(v: any): any
	if type(v) == "table" then
		local rec = outerToRecord[v]
		if rec ~= nil then
			return rec.fields
		end
	end
	return v
end

local function rewrapOne(v: any): any
	if type(v) == "table" then
		local outer = innerToOuter[v]
		if outer ~= nil then
			return outer
		end
	end
	return v
end

local function rewrapResults(...: any): ...any
	local n = select("#", ...)
	if n == 0 then
		return
	elseif n == 1 then
		return rewrapOne(...)
	end
	local out = table.create(n)
	for i = 1, n do
		out[i] = rewrapOne((select(i, ...)))
	end
	return table.unpack(out, 1, n)
end

local function resolveInstance(value: any): (ClassDef?, MemberTable?, InstanceRecord?)
	if type(value) ~= "table" then
		return nil, nil, nil
	end
	local rec = outerToRecord[value]
	if rec ~= nil then
		return rec.def, rec.fields, rec
	end
	local outer = innerToOuter[value]
	if outer ~= nil then
		rec = outerToRecord[outer]
		if rec ~= nil then
			return rec.def, rec.fields, rec
		end
	end
	local def = innerToDef[value]
	if def ~= nil then
		return def, value, nil
	end
	return nil, nil, nil
end

local function staticLookup(def: ClassDef, key: string): any
	local v = def.ownStatics[key]
	if v ~= nil then
		return v
	end
	local parents = def.staticParents
	for i = 1, #parents do
		v = staticLookup(parents[i], key)
		if v ~= nil then
			return v
		end
	end
	return nil
end

local function isControl(v: any): boolean
	return type(v) == "table" and rawget(v, "__lehua") == CONTROL_TAG
end

function LehuaClass.ControlSpecifier(spec: ControlSpec): Control
	if type(spec) ~= "table" then
		error("ControlSpecifier expects a table { Get = ..., Set = ... }", 2)
	end
	for k in pairs(spec :: any) do
		if k ~= "Get" and k ~= "Set" then
			error(("ControlSpecifier: unknown key '%s' (expected Get or Set)"):format(tostring(k)), 2)
		end
	end
	if spec.Get == nil and spec.Set == nil then
		error("ControlSpecifier needs at least a Get or a Set", 2)
	end
	if spec.Get ~= nil and type(spec.Get) ~= "function" then
		error("ControlSpecifier: Get must be a function", 2)
	end
	if spec.Set ~= nil and type(spec.Set) ~= "function" then
		error("ControlSpecifier: Set must be a function", 2)
	end

	return table.freeze({
		__lehua = CONTROL_TAG,
		Get = spec.Get,
		Set = spec.Set,
	}) :: any
end

LehuaClass.IsControl = isControl

local function readStatic(def: ClassDef, key: string): any
	local v = staticLookup(def, key)
	if isControl(v) then
		local control = v :: Control
		if control.Get == nil then
			error(("'%s.%s' is write-only"):format(def.name, key), 3)
		end
		return (control.Get :: any)()
	end
	return v
end

local function writeStatic(def: ClassDef, key: string, value: any): boolean
	local v = staticLookup(def, key)
	if not isControl(v) then
		return false
	end
	local control = v :: Control
	if control.Set == nil then
		error(("'%s.%s' is read-only"):format(def.name, key), 3)
	end
	(control.Set :: any)(value)
	return true
end

local function makeBound(def: ClassDef, name: string): Method
	return function(selfArg: any, ...): ...any
		local found = type(selfArg) == "table" and outerToRecord[selfArg] or nil
		if found == nil then
			error(
				("%s.%s is a method — call it as instance:%s(...)"):format(def.name, name, name),
				2
			)
		end
		local rec = found :: InstanceRecord
		local impl = rec.def.pubMethods[name] or def.pubMethods[name]
		return rewrapResults(impl(rec.fields, ...))
	end
end

local function getBound(def: ClassDef, name: string): Method
	local cached = def.boundCache[name]
	if cached == nil then
		cached = makeBound(def, name)
		def.boundCache[name] = cached
	end
	return cached
end

local SPECIAL_META = {
	__construct = true,
	__setup = true,
	__ready = true,
	__tostring = true,
	__type = true,
	__toconsole = true,
}

local RESERVED_META = {
	__index = true,
	__newindex = true,
	__metatable = true,
	__mode = true,
}

local function wrapMetamethod(fn: Method): Method
	return function(...)
		local n = select("#", ...)
		local args = table.create(n)
		for i = 1, n do
			args[i] = unwrapOne((select(i, ...)))
		end
		return rewrapResults(fn(table.unpack(args, 1, n)))
	end
end

local function buildOuterMeta(def: ClassDef): MemberTable
	local meta: MemberTable = {}

	meta.__index = function(proxy: any, key: string): any
		local rec = outerToRecord[proxy] :: InstanceRecord
		if def.pubMethods[key] ~= nil then
			return getBound(def, key)
		end
		local control = def.controls[key]
		if control ~= nil then
			if control.Visibility == "private" then
				error(
					("'%s.%s' is private — only %s methods can reach it through self"):format(
						def.name, tostring(key), def.name
					),
					2
				)
			end
			if control.Get == nil then
				error(("'%s.%s' is write-only"):format(def.name, tostring(key)), 2)
			end
			return rewrapResults((control.Get :: Method)(rec.fields))
		end
		if def.privateKeySet[key] then
			error(
				("'%s.%s' is private — only %s methods can reach it through self"):format(
					def.name, tostring(key), def.name
				),
				2
			)
		end
		if def.publicFieldSet[key] or rec.extraPublic[key] then
			return rec.fields[key]
		end
		if staticLookup(def, key) ~= nil then
			return readStatic(def, key)
		end
		if def.strict then
			error(
				("'%s' is not a member of class '%s' (public: %s)"):format(
					tostring(key), def.name, wordList(sortedKeys(def.publicFieldSet))
				),
				2
			)
		end
		return nil
	end

	meta.__newindex = function(proxy: any, key: string, value: any)
		local rec = outerToRecord[proxy] :: InstanceRecord
		local control = def.controls[key]
		if control ~= nil then
			if control.Visibility == "private" then
				error(("cannot write private member '%s.%s' from outside"):format(def.name, tostring(key)), 2)
			end
			if control.Set == nil then
				error(("'%s.%s' is read-only"):format(def.name, tostring(key)), 2)
			end
			(control.Set :: Method)(rec.fields, value)
			return
		end
		if def.privateKeySet[key] then
			error(("cannot write private member '%s.%s' from outside"):format(def.name, tostring(key)), 2)
		end
		if def.pubMethods[key] ~= nil then
			error(("cannot overwrite method '%s.%s' on an instance"):format(def.name, tostring(key)), 2)
		end
		if def.publicFieldSet[key] or rec.extraPublic[key] then
			rec.fields[key] = value
			return
		end
		if staticLookup(def, key) ~= nil then
			error(
				("'%s' is a static of '%s' — assign it on the class handle, not an instance"):format(
					tostring(key), def.name
				),
				2
			)
		end
		if def.strict then
			error(
				("cannot create undeclared member '%s' on strict class '%s'"):format(tostring(key), def.name),
				2
			)
		end
		rec.extraPublic[key] = true
		rec.fields[key] = value
	end

	meta.__tostring = function(proxy: any): string
		local rec = outerToRecord[proxy] :: InstanceRecord
		local custom: Method? = def.meta["__tostring"]
		if custom ~= nil then
			return tostring(custom(rec.fields))
		end
		return def.name .. "#" .. tostring(rec.id)
	end

	meta.__metatable = "The metatable is locked"

	for name, fn in pairs(def.meta) do
		if not SPECIAL_META[name] and type(fn) == "function" then
			meta[name] = wrapMetamethod(fn)
		end
	end

	return meta
end

local function buildInnerMeta(def: ClassDef): MemberTable
	return {
		__index = function(fields: any, key: string): any
			local m = def.pubMethods[key] or def.privMethods[key]
			if m ~= nil then
				return m
			end
			local control = def.controls[key]
			if control ~= nil then
				if control.Get == nil then
					error(("'%s.%s' is write-only"):format(def.name, tostring(key)), 2)
				end
				return (control.Get :: Method)(fields)
			end
			if staticLookup(def, key) ~= nil then
				return readStatic(def, key)
			end
			return nil
		end,

		__newindex = function(fields: any, key: string, value: any)
			local control = def.controls[key]
			if control ~= nil then
				if control.Set == nil then
					error(("'%s.%s' is read-only"):format(def.name, tostring(key)), 2)
				end
				(control.Set :: Method)(fields, value)
				return
			end
			if staticLookup(def, key) ~= nil then
				if writeStatic(def, key, value) then
					return
				end
				if value == nil then
					error(("class '%s': statics cannot hold nil"):format(def.name), 2)
				end
				def.ownStatics[key] = value
				return
			end
			rawset(fields, key, value)
		end,
		__tostring = function(fields: any): string
			local outer = innerToOuter[fields]
			if outer ~= nil then
				return tostring(outer)
			end
			return def.name .. "<inner>"
		end,
	}
end

function LehuaClass.Interface(spec: InterfaceSpec): Interface
	if type(spec) ~= "table" then
		error("Interface expects a table { Name = ..., Requires = ... }", 2)
	end
	if type(spec.Name) ~= "string" or spec.Name == "" then
		error("Interface requires a non-empty string Name", 2)
	end
	local ifaceName: string = spec.Name
	if type(spec.Requires) ~= "table" then
		error(("Interface '%s' requires a Requires table"):format(ifaceName), 2)
	end

	local requires: { [string]: string } = {}
	local declared: any = spec.Requires
	for k, v in pairs(declared) do
		if type(k) == "number" then
			if type(v) ~= "string" then
				error(("Interface '%s': Requires entries must be member-name strings"):format(ifaceName), 2)
			end
			requires[v] = "any"
		elseif type(k) == "string" then
			if type(v) ~= "string" then
				error(("Interface '%s': expected type for '%s' must be a string"):format(ifaceName::any, k), 2)
			end
			requires[k] = v
		else
			error(("Interface '%s': invalid Requires key of type %s"):format(ifaceName, type(k)), 2)
		end
	end

	local extends: { Interface } = {}
	if spec.Extends ~= nil then
		if type(spec.Extends) ~= "table" then
			error(("Interface '%s': Extends must be a list of interfaces"):format(ifaceName), 2)
		end
		for i, parent in ipairs(spec.Extends) do
			if type(parent) ~= "table" or parent.__lehua ~= INTERFACE_TAG then
				error(("Interface '%s': Extends[%d] is not an Interface"):format(ifaceName, i), 2)
			end
			extends[i] = parent
		end
	end

	return table.freeze({
		__lehua = INTERFACE_TAG,
		Name = ifaceName,
		Requires = table.freeze(requires),
		Extends = table.freeze(extends),
	}) :: any
end

local function isInterface(v: any): boolean
	return type(v) == "table" and rawget(v, "__lehua") == INTERFACE_TAG
end

local function gatherRequirements(iface: Interface, out: { [string]: string }, seen: { [any]: boolean }): { [string]: string }
	if seen[iface] then
		return out
	end
	seen[iface] = true
	for _, parent in ipairs(iface.Extends) do
		gatherRequirements(parent, out, seen)
	end
	for member, expected in pairs(iface.Requires) do
		out[member] = expected
	end
	return out
end

local function classProbe(def: ClassDef): Probe
	return function(name)
		if def.pubMethods[name] ~= nil then
			return true, "function"
		end
		local control = def.controls[name]
		if control ~= nil then
			return control.Visibility == "public", "any"
		end
		local fv = def.pubFields[name]
		if fv ~= nil then
			if isSetValue(fv) then
				return true, "any"
			end
			return true, fv == None and "nil" or type(fv)
		end
		local sv = staticLookup(def, name)
		if sv ~= nil then
			return true, type(sv)
		end
		local mv = def.meta[name]
		if mv ~= nil then
			return true, type(mv)
		end
		return false, "nil"
	end
end

local function instanceProbe(def: ClassDef, fields: any, rec: InstanceRecord?): Probe
	return function(name)
		if def.pubMethods[name] ~= nil then
			return true, "function"
		end
		local control = def.controls[name]
		if control ~= nil then
			if control.Visibility ~= "public" or control.Get == nil then
				return control.Visibility == "public", "any"
			end
			return true, type((control.Get :: Method)(fields))
		end
		if def.publicFieldSet[name] or (rec ~= nil and rec.extraPublic[name]) then
			return true, type(fields[name])
		end
		local sv = staticLookup(def, name)
		if sv ~= nil then
			return true, type(sv)
		end
		local mv = def.meta[name]
		if mv ~= nil then
			return true, type(mv)
		end
		return false, "nil"
	end
end

local function checkMembers(probe: Probe, requires: { [string]: string }): (boolean, { string })
	local missing: { string } = {}
	for member, expected in pairs(requires) do
		local present, valueType = probe(member)
		if not present then
			table.insert(missing, ("%s (missing)"):format(member))
		elseif expected ~= "any" and valueType ~= "any" and valueType ~= expected then
			table.insert(missing, ("%s (expected %s, got %s)"):format(member, expected, valueType))
		end
	end
	table.sort(missing)
	return #missing == 0, missing
end

local function checkInterface(probe: Probe, iface: Interface): (boolean, { string })
	return checkMembers(probe, gatherRequirements(iface, {}, {}))
end

function LehuaClass.Implements(value: any, iface: Interface): (boolean, { string })
	if not isInterface(iface) then
		error("Implements expects an Interface as its second argument", 2)
	end

	local def, fields, rec = resolveInstance(value)
	if def ~= nil then
		return checkInterface(instanceProbe(def, fields, rec), iface)
	end

	local classDef = handleToDef[value]
	if classDef ~= nil then
		return checkInterface(classProbe(classDef), iface)
	end

	if type(value) == "table" then
		return checkInterface(function(name)
			local v = value[name]
			if v == nil then
				return false, "nil"
			end
			return true, type(v)
		end, iface)
	end

	return false, { "(value is not a table, instance, or class)" }
end

local function isTrait(v: any): boolean
	return type(v) == "table" and rawget(v, "__lehua") == TRAIT_TAG
end

local function normalizeNameMap(context: string, label: string, src: any, default: string?): { [string]: string }
	local out: { [string]: string } = {}
	if src == nil then
		return out
	end
	if type(src) ~= "table" then
		error(("%s: %s must be a list of names or a { name = target } map"):format(context, label), 4)
	end
	for k, v in pairs(src) do
		if type(k) == "number" then
			if type(v) ~= "string" then
				error(("%s: %s entries must be member-name strings"):format(context, label), 4)
			end
			out[v] = default or v
		elseif type(k) == "string" then
			if type(v) ~= "string" then
				error(("%s: %s entry '%s' must map to a string"):format(context, label, k), 4)
			end
			out[k] = v
		else
			error(("%s: %s has an invalid key of type %s"):format(context, label, type(k)), 4)
		end
	end
	return out
end

local KNOWN_TRAIT_KEYS = {
	Name = true,
	Public = true,
	Private = true,
	MergedPublic = true,
	MergedPrivate = true,
	Static = true,
	Meta = true,
	Requires = true,
	Uses = true,
}

local function copyTraitMembers(traitName: string, src: any, label: string): MemberTable
	if src == nil then
		return {}
	end
	if type(src) ~= "table" then
		error(("trait '%s': %s must be a table"):format(traitName, label), 3)
	end
	local out: MemberTable = {}
	for k, v in pairs(src) do
		if type(k) ~= "string" then
			error(("trait '%s': %s member names must be strings"):format(traitName, label), 3)
		end
		if k:sub(1, 2) == "__" then
			error(
				("trait '%s': metamethod '%s' belongs at the top level of the trait, not inside %s"):format(
					traitName, k, label
				),
				3
			)
		end
		out[k] = v
	end
	return out
end

local function copyMergedMembers(traitName: string, src: any, label: string): MemberTable
	if src == nil then
		return {}
	end
	if type(src) ~= "table" then
		error(("trait '%s': %s must be a table"):format(traitName, label), 3)
	end
	local out: MemberTable = {}
	for k, v in pairs(src) do
		if type(k) ~= "string" then
			error(("trait '%s': %s member names must be strings"):format(traitName, label), 3)
		end
		if k:sub(1, 2) == "__" then
			error(
				("trait '%s': metamethod '%s' belongs at the top level of the trait, not inside %s"):format(
					traitName, k, label
				),
				3
			)
		end
		if isSetValue(v) then
			error(
				("trait '%s': %s member '%s' cannot be a SetValue — merged members fuse declared tables"):format(
					traitName, label, k
				),
				3
			)
		end
		if type(v) ~= "table" then
			error(
				("trait '%s': %s member '%s' must be a table — merged members fuse their contents"):format(
					traitName, label, k
				),
				3
			)
		end
		out[k] = v
	end
	return out
end

local function absorbTraitMeta(draft: TraitDraft, key: string, value: any, traitName: string)
	if RESERVED_META[key] then
		error(("trait '%s': metamethod '%s' is reserved by LehuaClass"):format(traitName, key), 3)
	end
	if key == "__construct" then
		error(
			("trait '%s': traits cannot define __construct — use __setup or __ready so several traits can stack"):format(
				traitName
			),
			3
		)
	end
	if key == "__setup" or key == "__ready" then
		if type(value) ~= "function" then
			error(("trait '%s': %s must be a function"):format(traitName, key), 3)
		end
		table.insert(key == "__setup" and draft.Setups or draft.Readies, value)
		return
	end
	if key == "__metadata" then
		if type(value) ~= "table" then
			error(("trait '%s': __metadata must be a table"):format(traitName), 3)
		end
		mergeMetadata(draft.Metadata, value)
		return
	end
	if key ~= "__type" and type(value) ~= "function" then
		error(("trait '%s': metamethod '%s' must be a function"):format(traitName, key), 3)
	end
	draft.Meta[key] = value
end

function LehuaClass.Trait(spec: TraitSpec): Trait
	if type(spec) ~= "table" then
		error("Trait expects a table { Name = ..., Public = { ... } }", 2)
	end
	if type(spec.Name) ~= "string" or spec.Name == "" then
		error("Trait requires a non-empty string Name", 2)
	end
	local traitName = spec.Name
	for k in pairs(spec) do
		if type(k) ~= "string" or (not KNOWN_TRAIT_KEYS[k] and k:sub(1, 2) ~= "__") then
			error(("trait '%s': unknown declaration key '%s'"):format(traitName, tostring(k)), 2)
		end
	end

	local uses: { Trait } = {}
	if spec.Uses ~= nil then
		if type(spec.Uses) ~= "table" then
			error(("trait '%s': Uses must be a list of traits"):format(traitName), 2)
		end
		for i, used in ipairs(spec.Uses) do
			if not isTrait(used) then
				error(("trait '%s': Uses[%d] is not a Trait"):format(traitName, i), 2)
			end
			uses[i] = used
		end
	end

	local draft: TraitDraft = {
		Meta = {},
		Metadata = {},
		Setups = {},
		Readies = {},
	}

	local public = copyTraitMembers(traitName, spec.Public, "Public")
	local private = copyTraitMembers(traitName, spec.Private, "Private")
	local static = copyTraitMembers(traitName, spec.Static, "Static")
	local mergedPublic = copyMergedMembers(traitName, spec.MergedPublic, "MergedPublic")
	local mergedPrivate = copyMergedMembers(traitName, spec.MergedPrivate, "MergedPrivate")

	local claimed: { [string]: string } = {}
	local function claim(name: string, where: string)
		local prior = claimed[name]
		if prior ~= nil then
			error(
				("trait '%s': member '%s' is declared in both %s and %s"):format(traitName, name, prior, where),
				3
			)
		end
		claimed[name] = where
	end
	for k in pairs(public) do claim(k, "Public") end
	for k in pairs(private) do claim(k, "Private") end
	for k in pairs(mergedPublic) do claim(k, "MergedPublic") end
	for k in pairs(mergedPrivate) do claim(k, "MergedPrivate") end

	if spec.Meta ~= nil then
		if type(spec.Meta) ~= "table" then
			error(("trait '%s': Meta must be a table"):format(traitName), 2)
		end
		for k, v in pairs(spec.Meta) do
			if type(k) ~= "string" then
				error(("trait '%s': Meta keys must be strings"):format(traitName), 2)
			end
			absorbTraitMeta(draft, k, v, traitName)
		end
	end
	for k, v in pairs(spec) do
		if type(k) == "string" and k:sub(1, 2) == "__" then
			absorbTraitMeta(draft, k, v, traitName)
		end
	end

	return table.freeze({
		__lehua = TRAIT_TAG,
		Name = traitName,
		Public = table.freeze(public),
		Private = table.freeze(private),
		MergedPublic = table.freeze(mergedPublic),
		MergedPrivate = table.freeze(mergedPrivate),
		Static = table.freeze(static),
		Meta = table.freeze(draft.Meta),
		Metadata = table.freeze(draft.Metadata),
		Requires = table.freeze(
			normalizeNameMap(("trait '%s'"):format(traitName), "Requires", spec.Requires, "any")
		),
		Setups = table.freeze(draft.Setups),
		Readies = table.freeze(draft.Readies),
		Uses = table.freeze(uses),
	}) :: any
end

function LehuaClass.Compose(name: string, ...: Trait): Trait
	if type(name) ~= "string" or name == "" then
		error("Compose expects a name followed by the traits to merge", 2)
	end
	local given = table.pack(...)
	if given.n == 0 then
		error(("Compose '%s': needs at least one trait"):format(name), 2)
	end
	local uses: { Trait } = {}
	for i = 1, given.n do
		local candidate = given[i]
		if not isTrait(candidate) then
			error(("Compose '%s': argument %d is not a Trait"):format(name, i + 1), 2)
		end
		uses[i] = candidate
	end
	return LehuaClass.Trait({
		Name = name,
		Uses = uses,
	})
end

local function flattenTrait(trait: Trait, out: { Trait }, seen: { [any]: boolean })
	if seen[trait] then
		return
	end
	seen[trait] = true
	for _, used in ipairs(trait.Uses) do
		flattenTrait(used, out, seen)
	end
	table.insert(out, trait)
end

local function traitProbe(def: ClassDef): Probe
	local public = classProbe(def)
	return function(name)
		if def.privMethods[name] ~= nil then
			return true, "function"
		end
		local fv = def.privFields[name]
		if fv ~= nil then
			if isSetValue(fv) then
				return true, "any"
			end
			return true, fv == None and "nil" or type(fv)
		end
		return public(name)
	end
end

local TRAIT_PICK_KEYS = {
	Trait = true,
	Only = true,
	Except = true,
	Rename = true,
}

local function traitEntry(className: string, entry: any, index: number): (Trait, { [string]: boolean }?, { [string]: boolean }?, { [string]: string }?)
	if isTrait(entry) then
		return entry, nil, nil, nil
	end
	if type(entry) ~= "table" then
		error(("class '%s': Traits[%d] must be a Trait or { Trait = ..., Only = {...} }"):format(className, index), 4)
	end
	for k in pairs(entry) do
		if not TRAIT_PICK_KEYS[k] then
			error(("class '%s': Traits[%d] has unknown key '%s'"):format(className, index, tostring(k)), 4)
		end
	end
	if not isTrait(entry.Trait) then
		error(("class '%s': Traits[%d].Trait is not a Trait"):format(className, index), 4)
	end

	local sets: { [string]: { [string]: boolean } } = {}
	for _, label in ipairs({ "Only", "Except" }) do
		local list = entry[label]
		if list ~= nil then
			if type(list) ~= "table" then
				error(("class '%s': Traits[%d].%s must be a list of member names"):format(className, index, label), 4)
			end
			local set: { [string]: boolean } = {}
			for _, name in ipairs(list) do
				if type(name) ~= "string" then
					error(("class '%s': Traits[%d].%s must contain strings"):format(className, index, label), 4)
				end
				set[name] = true
			end
			sets[label] = set
		end
	end

	local rename = entry.Rename
	if rename ~= nil then
		if type(rename) ~= "table" then
			error(("class '%s': Traits[%d].Rename must be a { from = to } map"):format(className, index), 4)
		end
		for from, to in pairs(rename) do
			if type(from) ~= "string" or type(to) ~= "string" then
				error(
					("class '%s': Traits[%d].Rename entries must map a member name to a member name"):format(
						className, index
					),
					4
				)
			end
		end
	end

	return entry.Trait, sets.Only, sets.Except, rename
end

local function checkFilterNames(className: string, index: number, traitName: string, available: { [string]: boolean }, names: { [string]: any }?, label: string)
	if names == nil then
		return
	end
	local wanted = names :: { [string]: any }
	for name in pairs(wanted) do
		if not available[name] then
			error(
				("class '%s': Traits[%d].%s names '%s', which trait '%s' does not provide"):format(
					className, index, label, tostring(name), traitName
				),
				4
			)
		end
	end
end

local function fuseTables(into: MemberTable, from: MemberTable): MemberTable
	local fused: MemberTable = {}
	if into ~= nil then
		mergeMetadata(fused, into)
	end
	mergeMetadata(fused, from)
	return fused
end

local function noteSource(def: ClassDef, name: string, contributor: string)
	local prior = def.memberSource[name]
	if prior == nil then
		def.memberSource[name] = contributor
	elseif prior ~= contributor and not string.find(prior, contributor, 1, true) then
		def.memberSource[name] = prior .. "+" .. contributor
	end
end

local function takeControl(def: ClassDef, className: string, name: string, value: any, visibility: string, owner: string, level: number): boolean
	if not isControl(value) then
		return false
	end

	local existing = def.controls[name]
	if existing ~= nil and existing.Visibility ~= visibility then
		error(
			("class '%s': control '%s' is %s in '%s' and %s in '%s'"):format(
				className, name, existing.Visibility, existing.Owner, visibility, owner
			),
			level
		)
	end
	if def.mergedKeys[name] ~= nil then
		error(("class '%s': '%s' is a merged member and cannot also be a control"):format(className, name), level)
	end

	local control = value :: Control
	def.controls[name] = {
		Get = control.Get,
		Set = control.Set,
		Visibility = visibility,
		Owner = owner,
	}
	def.pubFields[name] = nil
	def.privFields[name] = nil
	def.pubMethods[name] = nil
	def.privMethods[name] = nil
	noteSource(def, name, owner)
	return true
end

local function routeMergedMembers(className: string, traitName: string, src: MemberTable, filter: TraitFilter, def: ClassDef, visibility: string, owner: { [string]: string })
	local only, except, rename = filter.only, filter.except, filter.rename
	for key, value in pairs(src) do
		if (only == nil or only[key]) and (except == nil or not except[key]) then
			local name = (rename ~= nil and rename[key]) or key
			local prior = def.mergedKeys[name]

			if prior ~= nil and prior ~= visibility then
				error(
					("class '%s': merged member '%s' is public in one trait and private in another"):format(
						className, name
					),
					4
				)
			end
			if prior == nil and owner[name] ~= nil then
				error(
					("class '%s': '%s' is a plain member from trait '%s' and a merged member from trait '%s' — they cannot fuse"):format(
						className, name, owner[name], traitName
					),
					4
				)
			end

			local fieldsDst = if visibility == "public" then def.pubFields else def.privFields
			local methodsDst = if visibility == "public" then def.pubMethods else def.privMethods

			fieldsDst[name] = fuseTables(fieldsDst[name], value)
			methodsDst[name] = nil
			def.mergedKeys[name] = visibility
			noteSource(def, name, traitName)
		end
	end
end

local function routeTraitMembers(className: string, traitName: string, src: MemberTable, filter: TraitFilter, owner: { [string]: string }, fieldsDst: MemberTable, methodsDst: MemberTable?, label: string, declared: { [string]: boolean }, def: ClassDef, visibility: string?)
	local only, except, rename = filter.only, filter.except, filter.rename
	for key, value in pairs(src) do
		if (only == nil or only[key]) and (except == nil or not except[key]) then
			local name = (rename ~= nil and rename[key]) or key
			if def.mergedKeys[name] ~= nil then
				error(
					("class '%s': trait '%s' declares '%s' as a plain member, but another trait merges it"):format(
						className, traitName, name
					),
					4
				)
			end
			if visibility ~= nil and isControl(value) then
				local prior = owner[name]
				if prior ~= nil and prior ~= traitName and not declared[name] then
					error(
						("class '%s': traits '%s' and '%s' both provide control '%s' — declare '%s' on the class, or filter one with Only/Except/Rename"):format(
							className, prior, traitName, name, name
						),
						4
					)
				end
				takeControl(def, className, name, value, visibility, traitName, 4)
				owner[name] = traitName
				continue
			end
			local previous = owner[name]
			if previous ~= nil and previous ~= traitName and not declared[name] then
				error(
					("class '%s': traits '%s' and '%s' both provide %s '%s' — declare '%s' on the class, or filter one with Only/Except/Rename"):format(
						className, previous, traitName, label, name, name
					),
					4
				)
			end
			owner[name] = traitName
			if methodsDst == nil then
				fieldsDst[name] = value
			elseif type(value) == "function" then
				methodsDst[name] = value
				fieldsDst[name] = nil
			else
				fieldsDst[name] = value
				methodsDst[name] = nil
			end
		end
	end
end

local function applyTraits(def: ClassDef, decl: ClassDecl, className: string, declared: { [string]: boolean })
	if decl.Traits == nil then
		return
	end
	if type(decl.Traits) ~= "table" then
		error(("class '%s': Traits must be a list of traits"):format(className), 3)
	end
	local entries: { any } = decl.Traits :: any

	local applied: { [any]: boolean } = {}
	for _, trait in ipairs(def.traits) do
		applied[trait] = true
	end

	local memberOwner: { [string]: string } = {}
	local staticOwner: { [string]: string } = {}
	local metaOwner: { [string]: string } = {}

	for index, entry in ipairs(entries) do
		local trait, only, except, rename = traitEntry(className, entry, index)

		local group: { Trait } = {}
		flattenTrait(trait, group, {})

		if only ~= nil or except ~= nil or rename ~= nil then
			local available: { [string]: boolean } = {}
			for _, member in ipairs(group) do
				for k in pairs(member.Public) do available[k] = true end
				for k in pairs(member.Private) do available[k] = true end
				for k in pairs(member.MergedPublic) do available[k] = true end
				for k in pairs(member.MergedPrivate) do available[k] = true end
				for k in pairs(member.Static) do available[k] = true end
			end
			checkFilterNames(className, index, trait.Name, available, only, "Only")
			checkFilterNames(className, index, trait.Name, available, except, "Except")
			checkFilterNames(className, index, trait.Name, available, rename, "Rename")
		end

		local filter: TraitFilter = { only = only, except = except, rename = rename }

		for _, member in ipairs(group) do
			if not applied[member] then
				applied[member] = true
				table.insert(def.traits, member)

				routeMergedMembers(className, member.Name, member.MergedPublic, filter, def, "public", memberOwner)
				routeMergedMembers(className, member.Name, member.MergedPrivate, filter, def, "private", memberOwner)

				routeTraitMembers(className, member.Name, member.Public, filter, memberOwner, def.pubFields, def.pubMethods, "member", declared, def, "public")
				routeTraitMembers(className, member.Name, member.Private, filter, memberOwner, def.privFields, def.privMethods, "member", declared, def, "private")
				routeTraitMembers(className, member.Name, member.Static, filter, staticOwner, def.ownStatics, nil, "static", declared, def, nil)

				for key, fn in pairs(member.Meta) do
					local previous = metaOwner[key]
					if previous ~= nil and previous ~= member.Name and not declared[key] then
						error(
							("class '%s': traits '%s' and '%s' both provide metamethod '%s' — declare '%s' on the class to resolve it"):format(
								className, previous, member.Name, key, key
							),
							3
						)
					end
					metaOwner[key] = member.Name
					def.meta[key] = fn
				end

				for _, setupFn in ipairs(member.Setups) do
					appendHook(def.setups, setupFn)
				end
				for _, readyFn in ipairs(member.Readies) do
					appendHook(def.readies, readyFn)
				end
				mergeMetadata(def.metadata, member.Metadata)
			end
		end
	end
end

local DELEGATE_KEYS = {
	To = true,
	Methods = true,
	Fields = true,
	Getters = true,
	Optional = true,
}

local function makeDelegate(context: string, spec: any): MemberTable
	if type(spec) ~= "table" then
		error(("%s: Delegate expects a table { To = ..., Methods = {...} }"):format(context), 3)
	end
	for k in pairs(spec) do
		if not DELEGATE_KEYS[k] then
			error(("%s: unknown Delegate key '%s'"):format(context, tostring(k)), 3)
		end
	end
	local target = spec.To
	if type(target) ~= "string" or target == "" then
		error(("%s: Delegate requires a To member name"):format(context), 3)
	end
	local to: string = target

	local optional = spec.Optional == true
	local methods = normalizeNameMap(context, "Delegate Methods", spec.Methods, nil)
	local fields = normalizeNameMap(context, "Delegate Fields", spec.Fields, nil)
	local getters = normalizeNameMap(context, "Delegate Getters", spec.Getters, nil)

	local out: MemberTable = {}
	local function put(name: string, fn: Method)
		if out[name] ~= nil then
			error(("%s: delegate would define '%s' twice"):format(context, name), 4)
		end
		out[name] = fn
	end

	local function reach(selfArg: any, memberName: string): any
		local holder = selfArg[to]
		if holder == nil then
			if optional then
				return nil
			end
			error(("'%s' cannot run — delegate target '%s' is nil"):format(memberName, to), 3)
		end
		return holder
	end

	for exposed, remote in pairs(methods) do
		put(exposed, function(selfArg: any, ...: any): ...any
			local holder = reach(selfArg, exposed)
			if holder == nil then
				return nil
			end
			local fn = holder[remote]
			if type(fn) ~= "function" then
				error(("delegate '%s' expected a method '%s' on '%s'"):format(exposed, remote, to), 2)
			end
			return fn(holder, ...)
		end)
	end

	local function putGetter(exposed: string, remote: string)
		local getName = "Get" .. exposed
		put(getName, function(selfArg: any): any
			local holder = reach(selfArg, getName)
			if holder == nil then
				return nil
			end
			return holder[remote]
		end)
	end

	for exposed, remote in pairs(fields) do
		putGetter(exposed, remote)
		local setName = "Set" .. exposed
		put(setName, function(selfArg: any, value: any)
			local holder = reach(selfArg, setName)
			if holder ~= nil then
				holder[remote] = value
			end
		end)
	end

	for exposed, remote in pairs(getters) do
		putGetter(exposed, remote)
	end

	return out
end

function LehuaClass.Delegate(spec: DelegateSpec): MemberTable
	return makeDelegate("Delegate", spec)
end

local KNOWN_DECL_KEYS = {
	Name = true,
	Private = true,
	Public = true,
	MergedPublic = true,
	MergedPrivate = true,
	Static = true,
	Meta = true,
	Inherits = true,
	Traits = true,
	Delegates = true,
	Interfaces = true,
	Strict = true,
	Abstract = true,
	Sealed = true,
}

local function assertMemberTable(className: string, t: any, label: string): MemberTable
	if t ~= nil and type(t) ~= "table" then
		error(("class '%s': %s must be a table"):format(className, label), 3)
	end
	return t or {}
end

local function absorbMembers(className: string, src: MemberTable, fieldsDst: MemberTable, methodsDst: MemberTable, label: string, def: ClassDef, visibility: string)
	for k, v in pairs(src) do
		if type(k) ~= "string" then
			error(("class '%s': %s member names must be strings"):format(className, label), 3)
		end
		if k:sub(1, 2) == "__" then
			error(
				("class '%s': metamethod '%s' belongs at the top level of the declaration, not inside %s"):format(
					className, k, label
				),
				3
			)
		end
		if takeControl(def, className, k, v, visibility, className, 3) then
			continue
		end
		def.controls[k] = nil
		if type(v) == "function" then
			methodsDst[k] = v
			fieldsDst[k] = nil
		else
			fieldsDst[k] = v
			methodsDst[k] = nil
		end
	end
end

local function absorbMeta(def: ClassDef, key: string, value: any, className: string)
	if RESERVED_META[key] then
		error(("class '%s': metamethod '%s' is reserved by LehuaClass"):format(className, key), 3)
	end
	if key == "__construct" then
		if type(value) ~= "function" then
			error(("class '%s': __construct must be a function"):format(className), 3)
		end
		def.construct = value
		return
	end
	if key == "__setup" then
		if type(value) ~= "function" then
			error(("class '%s': __setup must be a function"):format(className), 3)
		end
		def.setup = value
		return
	end
	if key == "__ready" then
		if type(value) ~= "function" then
			error(("class '%s': __ready must be a function"):format(className), 3)
		end
		def.ready = value
		return
	end
	if key == "__metadata" then
		if type(value) ~= "table" then
			error(("class '%s': __metadata must be a table"):format(className), 3)
		end
		def.ownMetadata = value
		return
	end
	if key ~= "__type" and type(value) ~= "function" then
		error(("class '%s': metamethod '%s' must be a function"):format(className, key), 3)
	end
	def.meta[key] = value
end

local function pickMembers(className: string, parentDef: ClassDef, names: { string }?, sources: { { from: MemberTable, into: MemberTable } }, label: string)
	if names == nil then
		return
	end
	if type(names) ~= "table" then
		error(("class '%s': Inherits entry %s must be a list of member names"):format(className, label), 3)
	end
	local wanted: { string } = names :: any
	for _, name in ipairs(wanted) do
		if type(name) ~= "string" then
			error(("class '%s': Inherits entry %s must contain strings"):format(className, label), 3)
		end
		local found = false
		for _, route in ipairs(sources) do
			local v = route.from[name]
			if v ~= nil then
				route.into[name] = v
				found = true
				break
			end
		end
		if not found and parentDef.controls[name] ~= nil then
			found = true
		end
		if not found then
			error(
				("class '%s': parent '%s' has no %s member named '%s'"):format(
					className, parentDef.name, label, name
				),
				3
			)
		end
	end
end

function LehuaClass.NewClassData(decl: ClassDecl): Class
	if type(decl) ~= "table" then
		error("NewClassData expects a declaration table", 2)
	end
	if type(decl.Name) ~= "string" or decl.Name == "" then
		error("NewClassData: declaration requires a non-empty string Name", 2)
	end
	local className = decl.Name
	if classesByName[className] ~= nil then
		error(("NewClassData: a class named '%s' already exists"):format(className), 2)
	end
	for k in pairs(decl) do
		if type(k) ~= "string" or (not KNOWN_DECL_KEYS[k] and k:sub(1, 2) ~= "__") then
			error(("class '%s': unknown declaration key '%s'"):format(className, tostring(k)), 2)
		end
	end

	local def: ClassDef = {
		name = className,
		strict = decl.Strict ~= false,
		abstract = decl.Abstract == true,
		sealed = decl.Sealed == true,
		privFields = {},
		privMethods = {},
		pubFields = {},
		pubMethods = {},
		ownStatics = {},
		staticParents = {},
		meta = {},
		construct = nil,
		setup = nil,
		setups = {},
		ready = nil,
		readies = {},
		metadata = {},
		ownMetadata = nil,
		interfaces = {},
		traits = {},
		ancestors = {},
		ancestorNames = {},
		boundCache = {},
		privateKeySet = {},
		publicFieldSet = {},
		controls = {},
		mergedKeys = {},
		memberSource = {},
	} :: any

	local inherits = decl.Inherits
	if inherits ~= nil then
		local singleParent = handleToDef[inherits]
		if singleParent ~= nil then
			if singleParent.sealed then
				error(("class '%s': parent '%s' is sealed"):format(className, singleParent.name), 2)
			end
			for k, v in pairs(singleParent.privFields) do def.privFields[k] = v end
			for k, v in pairs(singleParent.privMethods) do def.privMethods[k] = v end
			for k, v in pairs(singleParent.pubFields) do def.pubFields[k] = v end
			for k, v in pairs(singleParent.pubMethods) do def.pubMethods[k] = v end
			for k, v in pairs(singleParent.meta) do def.meta[k] = v end
			def.construct = singleParent.construct
			for _, setupFn in ipairs(singleParent.setups) do
				appendHook(def.setups, setupFn)
			end
			for _, readyFn in ipairs(singleParent.readies) do
				appendHook(def.readies, readyFn)
			end
			table.insert(def.staticParents, singleParent)
			mergeMetadata(def.metadata, singleParent.metadata)
			for h in pairs(singleParent.ancestors) do def.ancestors[h] = true end
			for n in pairs(singleParent.ancestorNames) do def.ancestorNames[n] = true end
			for _, iface in ipairs(singleParent.interfaces) do
				table.insert(def.interfaces, iface)
			end
			for _, trait in ipairs(singleParent.traits) do
				table.insert(def.traits, trait)
			end
			for k, v in pairs(singleParent.mergedKeys) do def.mergedKeys[k] = v end
			for k, v in pairs(singleParent.memberSource) do def.memberSource[k] = v end
			for k, v in pairs(singleParent.controls) do def.controls[k] = v end
		elseif type(inherits) == "table" then
			local picks: { any } = inherits :: any
			for i, entry in ipairs(picks) do
				if type(entry) ~= "table" then
					error(("class '%s': Inherits[%d] must be { Class = ..., Public = {...} }"):format(className, i), 2)
				end
				if handleToDef[entry] ~= nil then
					error(
						("class '%s': Inherits[%d] is a bare class — multiple inheritance needs explicit picks: { Class = %s, Public = {...} }"):format(
							className, i, tostring(entry)
						),
						2
					)
				end
				local parentDef = handleToDef[entry.Class]
				if parentDef == nil then
					error(("class '%s': Inherits[%d].Class is not a Lehua class"):format(className, i), 2)
				end
				if parentDef.sealed then
					error(("class '%s': parent '%s' is sealed"):format(className, parentDef.name), 2)
				end
				pickMembers(className, parentDef, entry.Public, {
					{ from = parentDef.pubMethods, into = def.pubMethods },
					{ from = parentDef.pubFields, into = def.pubFields },
				}, "Public")
				pickMembers(className, parentDef, entry.Private, {
					{ from = parentDef.privMethods, into = def.privMethods },
					{ from = parentDef.privFields, into = def.privFields },
				}, "Private")
				pickMembers(className, parentDef, entry.Meta, {
					{ from = parentDef.meta, into = def.meta },
				}, "Meta")
				local function carryMerged(names: any)
					if names == nil then
						return
					end
					for _, name in ipairs(names :: { string }) do
						local visibility = parentDef.mergedKeys[name]
						if visibility ~= nil then
							def.mergedKeys[name] = visibility
						end
						local origin = parentDef.memberSource[name]
						if origin ~= nil then
							def.memberSource[name] = origin
						end
						local control = parentDef.controls[name]
						if control ~= nil then
							def.controls[name] = control
						end
					end
				end
				carryMerged(entry.Public)
				carryMerged(entry.Private)
				if entry.Static ~= nil then
					local statics: { string } = entry.Static :: any
					for _, name in ipairs(statics) do
						local v = staticLookup(parentDef, name)
						if v == nil then
							error(
								("class '%s': parent '%s' has no static named '%s'"):format(
									className, parentDef.name, name
								),
								2
							)
						end
						def.ownStatics[name] = v
					end
				end
				mergeMetadata(def.metadata, parentDef.metadata)
				for h in pairs(parentDef.ancestors) do def.ancestors[h] = true end
				for n in pairs(parentDef.ancestorNames) do def.ancestorNames[n] = true end
				for _, setupFn in ipairs(parentDef.setups) do
					appendHook(def.setups, setupFn)
				end
				for _, readyFn in ipairs(parentDef.readies) do
					appendHook(def.readies, readyFn)
				end
			end
		else
			error(("class '%s': Inherits must be a class or a list of { Class = ... } entries"):format(className), 2)
		end
	end

	local declaredKeys: { [string]: boolean } = {}
	local function noteDeclared(source: any)
		if type(source) == "table" then
			for k in pairs(source) do
				if type(k) == "string" then
					declaredKeys[k] = true
				end
			end
		end
	end
	noteDeclared(decl.Private)
	noteDeclared(decl.Public)
	noteDeclared(decl.MergedPublic)
	noteDeclared(decl.MergedPrivate)
	noteDeclared(decl.Static)
	noteDeclared(decl.Meta)
	for k in pairs(decl) do
		if type(k) == "string" and k:sub(1, 2) == "__" then
			declaredKeys[k] = true
		end
	end

	applyTraits(def, decl, className, declaredKeys)

	if decl.Delegates ~= nil then
		if type(decl.Delegates) ~= "table" then
			error(("class '%s': Delegates must be a list of delegate specs"):format(className), 2)
		end
		local delegated: { [string]: boolean } = {}
		for i, spec in ipairs(decl.Delegates) do
			local generated = makeDelegate(("class '%s': Delegates[%d]"):format(className, i), spec)
			for name, fn in pairs(generated) do
				if delegated[name] then
					error(("class '%s': Delegates[%d] redefines delegated member '%s'"):format(className, i, name), 2)
				end
				if declaredKeys[name] then
					error(
						("class '%s': '%s' is both declared on the class and delegated — remove one"):format(
							className, name
						),
						2
					)
				end
				delegated[name] = true
				def.pubMethods[name] = fn
				def.pubFields[name] = nil
				def.privFields[name] = nil
				def.privMethods[name] = nil
			end
		end
	end

	local function absorbMerged(source: any, visibility: string, label: string)
		if source == nil then
			return
		end
		if type(source) ~= "table" then
			error(("class '%s': %s must be a table"):format(className, label), 2)
		end
		local fieldsDst = if visibility == "public" then def.pubFields else def.privFields
		local methodsDst = if visibility == "public" then def.pubMethods else def.privMethods
		for name, value in pairs(source) do
			if type(name) ~= "string" then
				error(("class '%s': %s member names must be strings"):format(className, label), 2)
			end
			if isSetValue(value) then
				error(
					("class '%s': %s member '%s' cannot be a SetValue — merged members fuse declared tables"):format(
						className, label, name
					),
					2
				)
			end
			if type(value) ~= "table" then
				error(
					("class '%s': %s member '%s' must be a table — merged members fuse their contents"):format(
						className, label, name
					),
					2
				)
			end
			local prior = def.mergedKeys[name]
			if prior ~= nil and prior ~= visibility then
				error(
					("class '%s': merged member '%s' is already %s — it cannot also be %s"):format(
						className, name, prior, visibility
					),
					2
				)
			end
			fieldsDst[name] = fuseTables(fieldsDst[name], value :: MemberTable)
			methodsDst[name] = nil
			def.mergedKeys[name] = visibility
			noteSource(def, name, className)
		end
	end
	absorbMerged(decl.MergedPublic, "public", "MergedPublic")
	absorbMerged(decl.MergedPrivate, "private", "MergedPrivate")

	local function assertNotMerged(source: any, label: string)
		if type(source) ~= "table" then
			return
		end
		for k in pairs(source) do
			if type(k) == "string" and def.mergedKeys[k] ~= nil then
				error(
					("class '%s': '%s' is a merged member — declare it under %s, not %s"):format(
						className,
						k,
						if def.mergedKeys[k] == "public" then "MergedPublic" else "MergedPrivate",
						label
					),
					2
				)
			end
		end
	end
	assertNotMerged(decl.Public, "Public")
	assertNotMerged(decl.Private, "Private")

	absorbMembers(className, assertMemberTable(className, decl.Private, "Private"), def.privFields, def.privMethods, "Private", def, "private")
	absorbMembers(className, assertMemberTable(className, decl.Public, "Public"), def.pubFields, def.pubMethods, "Public", def, "public")
	for k in pairs(declaredKeys) do
		if def.mergedKeys[k] == nil then
			def.memberSource[k] = className
		end
	end

	for k, v in pairs(assertMemberTable(className, decl.Static, "Static")) do
		if type(k) ~= "string" then
			error(("class '%s': Static member names must be strings"):format(className), 2)
		end
		if isSetValue(v) then
			error(
				("class '%s': static '%s' cannot be a SetValue — statics are built once, so call the function yourself"):format(
					className, k
				),
				2
			)
		end
		def.ownStatics[k] = v
	end
	for k, v in pairs(assertMemberTable(className, decl.Meta, "Meta")) do
		absorbMeta(def, k, v, className)
	end
	for k, v in pairs(decl) do
		if type(k) == "string" and k:sub(1, 2) == "__" then
			absorbMeta(def, k, v, className)
		end
	end

	if def.setup ~= nil then
		appendHook(def.setups, def.setup)
	end
	if def.ready ~= nil then
		appendHook(def.readies, def.ready)
	end

	if def.ownMetadata ~= nil then
		mergeMetadata(def.metadata, def.ownMetadata)
	end
	table.freeze(def.metadata)

	local function collide(k: string)
		error(("class '%s': member '%s' is declared both private and public"):format(className, k), 2)
	end
	for k in pairs(def.privFields) do
		if def.pubFields[k] ~= nil or def.pubMethods[k] ~= nil then collide(k) end
	end
	for k in pairs(def.privMethods) do
		if def.pubFields[k] ~= nil or def.pubMethods[k] ~= nil then collide(k) end
	end

	def.privateKeySet = {}
	for k in pairs(def.privFields) do def.privateKeySet[k] = true end
	for k in pairs(def.privMethods) do def.privateKeySet[k] = true end
	def.publicFieldSet = {}
	for k in pairs(def.pubFields) do def.publicFieldSet[k] = true end

	if #def.traits > 0 then
		local needs = traitProbe(def)
		for _, trait in ipairs(def.traits) do
			local ok, missing = checkMembers(needs, trait.Requires)
			if not ok then
				error(
					("class '%s' is missing what trait '%s' requires: %s"):format(
						className, trait.Name, table.concat(missing, ", ")
					),
					2
				)
			end
		end
	end
	table.freeze(def.traits)

	if decl.Interfaces ~= nil then
		if type(decl.Interfaces) ~= "table" then
			error(("class '%s': Interfaces must be a list"):format(className), 2)
		end
		local seen: { [any]: boolean } = {}
		for _, iface in ipairs(def.interfaces) do
			seen[iface] = true
		end
		for i, iface in ipairs(decl.Interfaces) do
			if not isInterface(iface) then
				error(("class '%s': Interfaces[%d] is not an Interface"):format(className, i), 2)
			end
			if not seen[iface] then
				seen[iface] = true
				table.insert(def.interfaces, iface)
			end
		end
	end
	local probe = classProbe(def)
	for _, iface in ipairs(def.interfaces) do
		local ok, missing = checkInterface(probe, iface)
		if not ok then
			error(
				("class '%s' does not satisfy interface '%s': %s"):format(
					className, iface.Name, table.concat(missing, ", ")
				),
				2
			)
		end
	end

	local handle = setmetatable({}, {
		__index = function(_: any, key: string): any
			if key == "Name" then
				return def.name
			end
			if staticLookup(def, key) ~= nil then
				return readStatic(def, key)
			end
			if def.strict then
				error(
					("'%s' is not a static member of class '%s' (statics: %s)"):format(
						tostring(key), def.name, wordList(sortedKeys(def.ownStatics))
					),
					2
				)
			end
			return nil
		end,
		__newindex = function(_: any, key: string, value: any)
			if key == "Name" then
				error(("class '%s': Name is read-only"):format(def.name), 2)
			end
			if writeStatic(def, key, value) then
				return
			end
			if value == nil then
				error(("class '%s': statics cannot hold nil"):format(def.name), 2)
			end
			def.ownStatics[key] = value
		end,
		__call = function(h: any, ...: any): ...any
			return LehuaClass.BuildClassData(h, ...)
		end,
		__tostring = function(): string
			return "Class<" .. def.name .. ">"
		end,
		__metatable = "The metatable is locked",
	})

	local classHandle: Class = handle :: any
	def.handle = classHandle
	def.ancestors[classHandle] = true
	def.ancestorNames[className] = true
	def.innerMeta = buildInnerMeta(def)
	def.outerMeta = buildOuterMeta(def)

	handleToDef[classHandle] = def
	classesByName[className] = classHandle
	return classHandle
end

function LehuaClass.BuildClassData(classHandle: Class, ...: any): Object
	local def = handleToDef[classHandle]
	if def == nil then
		error("BuildClassData expects a class created by NewClassData", 2)
	end
	if def.abstract then
		error(("class '%s' is abstract and cannot be built"):format(def.name), 2)
	end

	instanceCounter += 1
	local fields = {}
	for k, v in pairs(def.privFields) do
		fields[k] = instantiateValue(v)
	end
	for k, v in pairs(def.pubFields) do
		fields[k] = instantiateValue(v)
	end

	local proxy = setmetatable({}, def.outerMeta)
	outerToRecord[proxy] = {
		def = def,
		fields = fields,
		extraPublic = {},
		id = instanceCounter,
	}
	innerToOuter[fields] = proxy
	innerToDef[fields] = def
	setmetatable(fields, def.innerMeta)

	for _, setupFn in ipairs(def.setups) do
		setupFn(fields, ...)
	end
	if def.construct ~= nil then
		def.construct(fields, ...)
	end
	for _, readyFn in ipairs(def.readies) do
		readyFn(fields, ...)
	end
	return (proxy :: any) :: Object
end

function LehuaClass.SuperGet(classHandle: Class, memberName: string): (self: any, ...any) -> ...any
	local def = handleToDef[classHandle]
	if def == nil then
		error("SuperGet expects a class as its first argument", 2)
	end
	local fn: Method?
	if memberName == "__construct" then
		fn = def.construct
		if fn == nil then
			error(("SuperGet: class '%s' has no constructor"):format(def.name), 2)
		end
	elseif memberName == "__setup" then
		fn = def.setup
		if fn == nil then
			error(("SuperGet: class '%s' has no __setup"):format(def.name), 2)
		end
	elseif memberName == "__ready" then
		fn = def.ready
		if fn == nil then
			error(("SuperGet: class '%s' has no __ready"):format(def.name), 2)
		end
	elseif def.pubMethods[memberName] ~= nil then
		fn = def.pubMethods[memberName]
	elseif type(def.meta[memberName]) == "function" then
		fn = def.meta[memberName]
	else
		error(
			("SuperGet: class '%s' has no public method or metamethod '%s' (methods: %s)"):format(
				def.name, tostring(memberName), wordList(sortedKeys(def.pubMethods))
			),
			2
		)
	end
	local impl: Method = fn :: Method
	return function(selfArg: any, ...: any): ...any
		return rewrapResults(impl(unwrapOne(selfArg), ...))
	end
end

function LehuaClass.IsA(value: any, classOrName: Class | string): boolean
	local def = resolveInstance(value) or handleToDef[value]
	if def == nil then
		return false
	end
	if type(classOrName) == "string" then
		return def.ancestorNames[classOrName] == true
	end
	if handleToDef[classOrName] == nil then
		error("IsA expects a class or class name as its second argument", 2)
	end
	return def.ancestors[classOrName] == true
end

function LehuaClass.FetchClass(value: any): Class?
	local def = resolveInstance(value)
	if def ~= nil then
		return def.handle
	end
	if handleToDef[value] ~= nil then
		return value
	end
	if type(value) == "string" then
		return classesByName[value]
	end
	return nil
end

function LehuaClass.GetMetaData(value: any): Metadata
	local def = resolveInstance(value) or handleToDef[value]
	if def == nil and type(value) == "string" then
		local named = classesByName[value]
		if named ~= nil then
			def = handleToDef[named]
		end
	end
	if def == nil then
		error("GetMetaData expects a class, an instance, or a class name", 2)
	end
	return def.metadata
end

function LehuaClass.IsClass(value: any): boolean
	return handleToDef[value] ~= nil
end

function LehuaClass.IsInstance(value: any): boolean
	return (resolveInstance(value)) ~= nil
end

function LehuaClass.Ref(value: any): Object?
	if type(value) ~= "table" then
		return nil
	end
	if outerToRecord[value] ~= nil then
		return value :: Object
	end
	local outer = innerToOuter[value]
	if outer ~= nil then
		return outer :: Object
	end
	return nil
end

function LehuaClass.GetTopLevel(value: any): Object
	if type(value) == "table" then
		if outerToRecord[value] ~= nil then
			return value :: Object
		end
		local outer = innerToOuter[value]
		if outer ~= nil then
			return outer :: Object
		end
		if innerToDef[value] ~= nil then
			error("GetTopLevel: this instance's public handle is no longer alive", 2)
		end
	end
	error("GetTopLevel expects an instance created by BuildClassData", 2)
end

LehuaClass.IsInterface = isInterface
LehuaClass.IsTrait = isTrait

function LehuaClass.HasTrait(value: any, traitOrName: Trait | string): boolean
	local def = resolveInstance(value) or handleToDef[value]
	if def == nil then
		return false
	end
	if type(traitOrName) == "string" then
		for _, trait in ipairs(def.traits) do
			if trait.Name == traitOrName then
				return true
			end
		end
		return false
	end
	if not isTrait(traitOrName) then
		error("HasTrait expects a Trait or a trait name as its second argument", 2)
	end
	for _, trait in ipairs(def.traits) do
		if trait == traitOrName then
			return true
		end
	end
	return false
end

function LehuaClass.Fuse(...: MemberTable): MemberTable
	local out: MemberTable = {}
	for i = 1, select("#", ...) do
		local piece = select(i, ...)
		if type(piece) ~= "table" then
			error(("Fuse: argument %d is not a table"):format(i), 2)
		end
		mergeMetadata(out, piece :: MemberTable)
	end
	return out
end

function LehuaClass.SourceOf(value: any, memberName: string): string?
	local def = resolveInstance(value) or handleToDef[value]
	if def == nil then
		return nil
	end
	return def.memberSource[memberName]
end

function LehuaClass.ControlsOf(value: any): { [string]: string }
	local def = resolveInstance(value) or handleToDef[value]
	if def == nil then
		return {}
	end
	local out: { [string]: string } = {}
	for name, control in pairs(def.controls) do
		local mode = if control.Get ~= nil and control.Set ~= nil
			then "get/set"
			elseif control.Get ~= nil then "get"
			else "set"
		out[name] = ("%s %s"):format(control.Visibility, mode)
	end
	return out
end

function LehuaClass.MergedKeys(value: any): { [string]: string }
	local def = resolveInstance(value) or handleToDef[value]
	if def == nil then
		return {}
	end
	return table.clone(def.mergedKeys)
end

function LehuaClass.TraitConflicts(...: Trait): { [string]: { string } }
	local flat: { Trait } = {}
	local seen: { [any]: boolean } = {}
	for i = 1, select("#", ...) do
		local trait = select(i, ...)
		if not isTrait(trait) then
			error(("TraitConflicts: argument %d is not a Trait"):format(i), 2)
		end
		flattenTrait(trait :: Trait, flat, seen)
	end

	local plain: { [string]: { string } } = {}
	local merged: { [string]: { string } } = {}

	local function note(bucket: { [string]: { string } }, name: string, traitName: string)
		local list = bucket[name]
		if list == nil then
			bucket[name] = { traitName }
			return
		end
		for _, existing in ipairs(list) do
			if existing == traitName then
				return
			end
		end
		table.insert(list, traitName)
	end

	for _, trait in ipairs(flat) do
		for name in pairs(trait.Public) do note(plain, name, trait.Name) end
		for name in pairs(trait.Private) do note(plain, name, trait.Name) end
		for name in pairs(trait.Static) do note(plain, name, trait.Name) end
		for name in pairs(trait.Meta) do note(plain, name, trait.Name) end
		for name in pairs(trait.MergedPublic) do note(merged, name, trait.Name) end
		for name in pairs(trait.MergedPrivate) do note(merged, name, trait.Name) end
	end

	local out: { [string]: { string } } = {}
	for name, list in pairs(plain) do
		local mergedList = merged[name]
		if #list > 1 or mergedList ~= nil then
			local all = table.clone(list)
			if mergedList ~= nil then
				for _, traitName in ipairs(mergedList) do
					table.insert(all, traitName)
				end
			end
			table.sort(all)
			out[name] = all
		end
	end
	return out
end

function LehuaClass.TraitInfo(trait: Trait): TraitReport
	if not isTrait(trait) then
		error("TraitInfo expects a Trait", 2)
	end

	local flat: { Trait } = {}
	flattenTrait(trait, flat, {})

	local uses: { string } = {}
	local public: MemberTable = {}
	local private: MemberTable = {}
	local mergedPublic: MemberTable = {}
	local mergedPrivate: MemberTable = {}
	local static: MemberTable = {}
	local meta: MemberTable = {}
	local requires: { [string]: string } = {}
	local setups, readies = 0, 0

	for _, member in ipairs(flat) do
		if member ~= trait then
			table.insert(uses, member.Name)
		end
		for k, v in pairs(member.Public) do public[k] = v end
		for k, v in pairs(member.Private) do private[k] = v end
		for k, v in pairs(member.MergedPublic) do mergedPublic[k] = v end
		for k, v in pairs(member.MergedPrivate) do mergedPrivate[k] = v end
		for k, v in pairs(member.Static) do static[k] = v end
		for k, v in pairs(member.Meta) do meta[k] = v end
		for k, v in pairs(member.Requires) do requires[k] = v end
		setups += #member.Setups
		readies += #member.Readies
	end

	table.sort(uses)
	return {
		Name = trait.Name,
		Uses = uses,
		Public = sortedKeys(public),
		Private = sortedKeys(private),
		MergedPublic = sortedKeys(mergedPublic),
		MergedPrivate = sortedKeys(mergedPrivate),
		Static = sortedKeys(static),
		Meta = sortedKeys(meta),
		Requires = requires,
		Setups = setups,
		Readies = readies,
	}
end

function LehuaClass.TraitsOf(value: any): { Trait }
	local def = resolveInstance(value) or handleToDef[value]
	if def == nil then
		return {}
	end
	return table.clone(def.traits)
end

function LehuaClass.TypeOf(value: any): string
	local def, fields = resolveInstance(value)
	if def ~= nil then
		local t: any = def.meta["__type"]
		if type(t) == "function" then
			return tostring((t :: Method)(fields))
		elseif t ~= nil then
			return tostring(t)
		end
		return def.name
	end
	if handleToDef[value] ~= nil then
		return "class"
	end
	if isInterface(value) then
		return "interface"
	end
	if isTrait(value) then
		return "trait"
	end
	return typeof(value)
end

function LehuaClass.Inspect(value: any): string
	local resolved, resolvedFields, rec = resolveInstance(value)
	if resolved == nil then
		return tostring(value)
	end
	local def = resolved :: ClassDef
	local fields: MemberTable = resolvedFields :: any
	local custom: Method? = def.meta["__toconsole"]
	if custom ~= nil then
		return tostring(custom(fields))
	end

	local lines: { string } = { rec ~= nil and (def.name .. "#" .. tostring(rec.id)) or def.name }
	local publicKeys: { string } = {}
	for k in pairs(def.publicFieldSet) do
		table.insert(publicKeys, k)
	end
	if rec ~= nil then
		for k in pairs(rec.extraPublic) do
			table.insert(publicKeys, k)
		end
	end
	table.sort(publicKeys)
	for _, k in ipairs(publicKeys) do
		table.insert(lines, ("  %s = %s"):format(k, tostring(fields[k])))
	end
	for _, k in ipairs(sortedKeys(def.pubMethods)) do
		table.insert(lines, ("  %s = <method>"):format(k))
	end
	for _, k in ipairs(sortedKeys(def.controls)) do
		local control = def.controls[k]
		if control.Visibility == "public" then
			local mode = if control.Get ~= nil and control.Set ~= nil
				then "get/set"
				elseif control.Get ~= nil then "get"
				else "set"
			local shown = if control.Get ~= nil
				then tostring((control.Get :: Method)(fields))
				else "(write-only)"
			table.insert(lines, ("  %s = %s <%s>"):format(k, shown, mode))
		end
	end
	for _, k in ipairs(sortedKeys(def.ownStatics)) do
		table.insert(lines, ("  %s = %s (static)"):format(k, tostring(def.ownStatics[k])))
	end
	if #def.traits > 0 then
		local names: { string } = {}
		for _, trait in ipairs(def.traits) do
			table.insert(names, trait.Name)
		end
		table.insert(lines, "  uses: " .. table.concat(names, ", "))
	end
	if #def.interfaces > 0 then
		local names: { string } = {}
		for _, iface in ipairs(def.interfaces) do
			table.insert(names, iface.Name)
		end
		table.insert(lines, "  implements: " .. table.concat(names, ", "))
	end
	return table.concat(lines, "\n")
end

local LEHUA_GLOBALS = {
	"NewClassData", "BuildClassData", "SuperGet",
	"Interface", "Implements", "IsA", "FetchClass",
	"Trait", "Compose", "Delegate", "HasTrait",
}

function LehuaClass.Globalize(target: MemberTable?): LehuaClassModule
	local into: MemberTable = target or (_G :: any)
	if type(into) ~= "table" then
		error("Globalize expects a table (or a reachable _G)", 2)
	end
	local api = LehuaClass :: MemberTable
	for _, name in ipairs(LEHUA_GLOBALS) do
		into[name] = api[name]
	end
	return (LehuaClass :: any) :: LehuaClassModule
end

return (LehuaClass :: any) :: LehuaClassModule
