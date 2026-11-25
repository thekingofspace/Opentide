export type RoFluxFile = {
	path: string,
	name: string,
	stem: string,
	folder: string,
	extension: string,
	source: string,
	text: string,
	className: string,
}

export type RoFluxDeclaration = { [any]: any }

export type RoFluxResult = string | RoFluxDeclaration | { RoFluxDeclaration } | nil

export type RoFluxListener = (file: RoFluxFile) -> RoFluxResult

export type RoFluxNode = {
	id: string,
	name: string,
	className: string,
	ownership: "managed" | "passthrough" | "reference",
	properties: { [string]: any },
	attributes: { [string]: any },
	tags: { string },
	children: { RoFluxNode },
	filePaths: { string },
}

export type RoFluxCompile = {
	initial: boolean,
	instances: number,
	scripts: number,
	files: number,
	added: number,
	updated: number,
	removed: number,
}

export type RoFluxSync = {
	added: number,
	updated: number,
	removed: number,
	summary: string,
	lines: { string },
	clients: number,
}

export type RoFluxStat = { size: number, modified: number, isFile: boolean, isDirectory: boolean }

export type RoFluxExec = { ok: boolean, code: number, stdout: string, stderr: string }

export type RoFluxProject = { name: string, id: string, root: string, manifest: string }

export type RoFluxContext = "server" | "client"

export type RoFluxLevel = "output" | "info" | "warning" | "error"

declare roflux: {
	on: (event: string, callback: (...any) -> ...any) -> (),
	onRead: (callback: RoFluxListener) -> (),
	onTransfer: (callback: RoFluxListener) -> (),
	onAdded: (callback: (file: RoFluxFile) -> ()) -> (),
	onRemoved: (callback: (file: RoFluxFile) -> ()) -> (),
	onChanged: (callback: (file: RoFluxFile) -> ()) -> (),
	onCompile: (callback: (info: RoFluxCompile) -> ()) -> (),
	onSync: (callback: (info: RoFluxSync) -> ()) -> (),
	onTree: (callback: (root: RoFluxNode) -> RoFluxNode?) -> (),
	onConnect: (callback: (session: string) -> ()) -> (),
	onEvent: (callback: (session: string, ...any) -> ()) -> (),
	onGameEvent: (callback: (session: string, gameSession: string, context: RoFluxContext, ...any) -> ()) -> (),
	onLog: (callback: (session: string, gameSession: string, context: RoFluxContext, message: string, level: RoFluxLevel) -> ()) -> (),
	onGameStart: (callback: (session: string, gameSession: string) -> ()) -> (),
	onGameEnd: (callback: (session: string, gameSession: string) -> ()) -> (),
	fireStudio: (...any) -> boolean,
	fireInGame: (...any) -> boolean,
	transpile: (extension: string, callback: RoFluxListener) -> (),
	defer: (callback: () -> ()) -> (),
	meta: (file: RoFluxFile | string, stub: any) -> (),

	log: (...any) -> (),
	warn: (...any) -> (),
	error: (...any) -> (),
	inspect: (value: any) -> string,

	root: () -> string,
	read: (path: string) -> string?,
	exists: (path: string) -> boolean,
	isDirectory: (path: string) -> boolean,
	list: (path: string) -> { string },
	walk: (path: string) -> { string },

	fs: {
		root: () -> string,
		read: (path: string) -> string?,
		write: (path: string, text: string) -> boolean,
		append: (path: string, text: string) -> (),
		remove: (path: string) -> boolean,
		mkdir: (path: string) -> (),
		exists: (path: string) -> boolean,
		isFile: (path: string) -> boolean,
		isDirectory: (path: string) -> boolean,
		list: (path: string) -> { string },
		walk: (path: string) -> { string },
		glob: (pattern: string) -> { string },
		stat: (path: string) -> RoFluxStat?,
	},

	json: ((path: string) -> any) & {
		read: (path: string) -> any,
		decode: (text: string) -> any,
		encode: (value: any, pretty: boolean?) -> string,
	},

	toml: {
		read: (path: string) -> any,
		decode: (text: string) -> any,
		encode: (value: any) -> string,
	},

	base64: {
		encode: (text: string) -> string,
		decode: (text: string) -> string,
	},

	hash: (text: string, algorithm: string?) -> string,

	luau: {
		literal: (value: any) -> string,
		module: (value: any) -> string,
		quote: (text: string) -> string,
		isIdentifier: (name: string) -> boolean,
	},

	new: (className: string, fields: { [any]: any }?, children: { [any]: any }?) -> RoFluxDeclaration,

	types: {
		color: (r: number, g: number, b: number) -> { number },
		rgb: (r: number, g: number, b: number) -> { number },
		hex: (value: string) -> { number },
		hsv: (h: number, s: number, v: number) -> { number },
		vector3: (x: number?, y: number?, z: number?) -> { number },
		vector2: (x: number?, y: number?) -> { number },
		udim: (scale: number?, offset: number?) -> { number },
		udim2: (xScale: number?, xOffset: number?, yScale: number?, yOffset: number?) -> { number },
		fromScale: (x: number?, y: number?) -> { number },
		fromOffset: (x: number?, y: number?) -> { number },
		cframe: (x: number?, y: number?, z: number?, ...number) -> { number },
		rect: (minX: number?, minY: number?, maxX: number?, maxY: number?) -> { number },
		range: (min: number, max: number?) -> { number },
		numberSequence: (...any) -> any,
		colorSequence: (...any) -> any,
		font: (family: string, weight: string?, style: string?) -> { family: string, weight: string?, style: string? },
		typed: (name: string, value: any) -> { [string]: any },
	},

	text: {
		trim: (value: string) -> string,
		trimStart: (value: string) -> string,
		trimEnd: (value: string) -> string,
		startsWith: (value: string, prefix: string) -> boolean,
		endsWith: (value: string, suffix: string) -> boolean,
		replace: (value: string, find: string, with: string) -> string,
		split: (value: string, separator: string?) -> { string },
		lines: (value: string) -> { string },
		indent: (value: string, prefix: string?) -> string,
		words: (value: string) -> { string },
		pascal: (value: string) -> string,
		camel: (value: string) -> string,
		snake: (value: string) -> string,
		kebab: (value: string) -> string,
		title: (value: string) -> string,
		padStart: (value: string, width: number, fill: string?) -> string,
		padEnd: (value: string, width: number, fill: string?) -> string,
	},

	path: {
		normalize: (value: string) -> string,
		join: (...string) -> string,
		dirname: (value: string) -> string,
		basename: (value: string) -> string,
		extension: (value: string) -> string,
		stem: (value: string) -> string,
		withExtension: (value: string, extension: string) -> string,
	},

	tree: {
		node: (name: string, declaration: (string | RoFluxDeclaration)?) -> RoFluxNode,
		child: (node: RoFluxNode, name: string) -> RoFluxNode?,
		find: (root: RoFluxNode, path: string) -> RoFluxNode?,
		each: (root: RoFluxNode, visit: (node: RoFluxNode, path: string) -> ()) -> (),
		add: (parent: RoFluxNode, node: RoFluxNode) -> RoFluxNode,
		remove: (root: RoFluxNode, path: string) -> RoFluxNode?,
		ensure: (root: RoFluxNode, path: string) -> RoFluxNode,
	},

	env: (name: string) -> string?,
	platform: () -> string,
	version: () -> string,
	project: () -> RoFluxProject,
	config: (key: string?) -> any,
	exec: (program: string, args: { string }?, options: { cwd: string? }?) -> RoFluxExec,

	cache: {
		get: (key: string) -> any,
		set: (key: string, value: any) -> (),
		has: (key: string) -> boolean,
		delete: (key: string) -> boolean,
		clear: () -> (),
		keys: () -> { string },
	},
}
