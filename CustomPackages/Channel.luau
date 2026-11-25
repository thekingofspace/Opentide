--[=[
    @By Raikin7

    @Version 1.0.0

    @TLDR I like multithreads
]=]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local module = {}

export type PromiseState = "Pending" | "Resolved" | "Rejected"

export type Promise<T> = {
	State: PromiseState,
	Value: T?,
	Error: any,

	AndThen: (self: Promise<T>, Callback: (T) -> ()) -> Promise<T>,
	Catch: (self: Promise<T>, Callback: (any) -> ()) -> Promise<T>,
	Await: (self: Promise<T>) -> (boolean, T | any),
}

export type MultiThread = {
	ThreadSink: SharedTable,
	ID: string,
	Actor: Actor,
	Destroyed: boolean,

	Action: (self: MultiThread, Name: string, ...any) -> Promise<any>,
	Destroy: (self: MultiThread) -> (),
}

type Packet = {
	ThreadID: string,
	RequestID: string,
	Action: string,
	Args: {any},
}

type ActorBubble = {
	kids: {[string]: MultiThread},
	Actions: {[string]: (...any) -> ...any},
	Incoming: {Packet},
	Heartbeat: RBXScriptConnection?,
	Destroyed: boolean,
}

local ThreadLinker: {[Actor]: ActorBubble} = {}

local PromiseClass = {}
PromiseClass.__index = PromiseClass

type InternalPromise = {
	State: PromiseState,
	Value: any,
	Error: any,
	Callbacks: {((any) -> ())},
	RejectCallbacks: {((any) -> ())},
	Waiters: {thread},
}

local function NewPromise()
	local Promise: InternalPromise = {
		State = "Pending",
		Value = nil,
		Error = nil,
		Callbacks = {},
		RejectCallbacks = {},
		Waiters = {},
	}

	return setmetatable(Promise, PromiseClass)
end

local function Resolve(Promise: InternalPromise, Value: any)
	if Promise.State ~= "Pending" then
		return
	end

	Promise.State = "Resolved"
	Promise.Value = Value

	for _, Callback in Promise.Callbacks do
		task.spawn(Callback, Value)
	end

	table.clear(Promise.Callbacks)
	table.clear(Promise.RejectCallbacks)

	for _, WaitingThread in Promise.Waiters do
		task.spawn(function()
			task.spawn(WaitingThread)
		end)
	end

	table.clear(Promise.Waiters)
end

local function Reject(Promise: InternalPromise, Reason: any)
	if Promise.State ~= "Pending" then
		return
	end

	Promise.State = "Rejected"
	Promise.Error = Reason

	for _, Callback in Promise.RejectCallbacks do
		task.spawn(Callback, Reason)
	end

	table.clear(Promise.Callbacks)
	table.clear(Promise.RejectCallbacks)

	for _, WaitingThread in Promise.Waiters do
		task.spawn(function()
			task.spawn(WaitingThread)
		end)
	end

	table.clear(Promise.Waiters)
end

function PromiseClass:AndThen(Callback)
	if self.State == "Resolved" then
		task.spawn(Callback, self.Value)
	elseif self.State == "Pending" then
		table.insert(self.Callbacks, Callback)
	end

	return self
end

function PromiseClass:Catch(Callback)
	if self.State == "Rejected" then
		task.spawn(Callback, self.Error)
	elseif self.State == "Pending" then
		table.insert(self.RejectCallbacks, Callback)
	end

	return self
end

function PromiseClass:Await()
	if self.State == "Pending" then
		local WaitingThread = coroutine.running()

		table.insert(self.Waiters, WaitingThread)
		coroutine.yield()
	end

	if self.State == "Resolved" then
		return true, self.Value
	end

	return false, self.Error
end


local function GetRequestTable(Thread: MultiThread): SharedTable
	local Requests = Thread.ThreadSink["Requests"]

	if not Requests then
		Requests = SharedTable.new()
		Thread.ThreadSink["Requests"] = Requests
	end

	return Requests
end

local function GetResponseTable(Thread: MultiThread): SharedTable
	local Responses = Thread.ThreadSink["Responses"]

	if not Responses then
		Responses = SharedTable.new()
		Thread.ThreadSink["Responses"] = Responses
	end

	return Responses
end


local function StopBubble(Actor: Actor, Bubble: ActorBubble)
	if Bubble.Destroyed then
		return
	end

	Bubble.Destroyed = true

	if Bubble.Heartbeat then
		Bubble.Heartbeat:Disconnect()
		Bubble.Heartbeat = nil
	end

	table.clear(Bubble.Incoming)
	table.clear(Bubble.Actions)

	for _, Thread in Bubble.kids do
		Thread.Destroyed = true

		local Requests = Thread.ThreadSink["Requests"]
		local Responses = Thread.ThreadSink["Responses"]

		if Requests then
			Requests["Destroyed"] = true
		end

		if Responses then
			Responses["Destroyed"] = true
		end
	end

	table.clear(Bubble.kids)

	ThreadLinker[Actor] = nil
end

local function ProcessPacket(Bubble: ActorBubble, Packet: Packet)
	if Bubble.Destroyed then
		return
	end

	local Thread = Bubble.kids[Packet.ThreadID]

	if not Thread or Thread.Destroyed then
		return
	end

	local Requests = GetRequestTable(Thread)
	local Responses = GetResponseTable(Thread)

	local Request = Requests[Packet.RequestID]

	if not Request or Request["Status"] ~= "Pending" then
		return
	end

	local Action = Bubble.Actions[Packet.Action]

	if not Action then
		Request["Status"] = "Rejected"
		Request["Error"] = "Unknown action: " .. Packet.Action
		return
	end

	local Success, Result = pcall(Action, table.unpack(Packet.Args))

	if Thread.Destroyed or Bubble.Destroyed then
		return
	end

	if Request["Status"] ~= "Pending" then
		return
	end

	if not Success then
		Request["Status"] = "Rejected"
		Request["Error"] = tostring(Result)
		return
	end

	Responses[Packet.RequestID] = Result
	Request["Status"] = "Resolved"
end

local function ActorLink(Actor: Actor): ActorBubble
	local Existing = ThreadLinker[Actor]

	if Existing then
		return Existing
	end

	local Bubble: ActorBubble = {
		kids = {},
		Actions = {},
		Incoming = {},
		Heartbeat = nil,
		Destroyed = false,
	}

	ThreadLinker[Actor] = Bubble

	Actor:BindToMessage("MultiThreadReceived", function(Packet: Packet)
		if Bubble.Destroyed then
			return
		end

		table.insert(Bubble.Incoming, Packet)
	end)

	Bubble.Heartbeat = RunService.Heartbeat:Connect(function()
		if Bubble.Destroyed then
			return
		end

		local Incoming = Bubble.Incoming
		Bubble.Incoming = {}

		for _, Packet in Incoming do
			if Bubble.Destroyed then
				break
			end

			ProcessPacket(Bubble, Packet)
		end
	end)

	Actor.Destroying:Once(function()
		StopBubble(Actor, Bubble)
	end)

	return Bubble
end

function module.RegisterAction(
	Actor: Actor,
	Name: string,
	Callback: (...any) -> ...any
)
	assert(Name ~= "", "Action name cannot be empty")

	local Bubble = ActorLink(Actor)

	assert(not Bubble.Destroyed, "Actor bubble is destroyed")

	Bubble.Actions[Name] = Callback
end

function module.RemoveAction(Actor: Actor, Name: string): boolean
	local Bubble = ThreadLinker[Actor]

	if not Bubble or not Bubble.Actions[Name] then
		return false
	end

	Bubble.Actions[Name] = nil

	return true
end

local ThreadClass = {}
ThreadClass.__index = ThreadClass

function ThreadClass:Action(Name: string, ...: any): Promise<any>
	local Thread = self :: MultiThread

	local Promise = NewPromise()
	local Bubble = ThreadLinker[Thread.Actor]

	if Thread.Destroyed or not Bubble or Bubble.Destroyed then
		Reject(Promise, "MultiThread has been destroyed")
		return Promise
	end

	local RequestID = HttpService:GenerateGUID(false)
	local Args = {...}

	local Requests = GetRequestTable(Thread)

	Requests[RequestID] = SharedTable.new({
		Status = "Pending",
	})
	local Packet: Packet = {
		ThreadID = Thread.ID,
		RequestID = RequestID,
		Action = Name,
		Args = Args,
	}

	Thread.Actor:SendMessage("MultiThreadReceived", Packet)

	task.spawn(function()
		while not Thread.Destroyed and not Bubble.Destroyed do
			local Request = Requests[RequestID]

			if not Request then
				Reject(Promise, "Request was removed")
				return
			end

			local Status = Request["Status"]

			if Status == "Resolved" then
				local Responses = GetResponseTable(Thread)
				local Result = Responses[RequestID]

				Responses[RequestID] = nil
				Requests[RequestID] = nil

				Resolve(Promise :: any, Result)
				return
			elseif Status == "Rejected" then
				local Reason = Request["Error"]

				Requests[RequestID] = nil

				Reject(Promise :: any, Reason)
				return
			end

			task.wait()
		end

		Reject(Promise :: any, "MultiThread destroyed during request")
	end)

	return Promise :: any
end

function ThreadClass:Destroy()
	local Thread = self :: MultiThread

	if Thread.Destroyed then
		return
	end

	Thread.Destroyed = true

	local Bubble = ThreadLinker[Thread.Actor]

	if not Bubble then
		return
	end

	Bubble.kids[Thread.ID] = nil

	local Requests = Thread.ThreadSink["Requests"]
	local Responses = Thread.ThreadSink["Responses"]

	if Requests then
		Requests["Destroyed"] = true
	end

	if Responses then
		Responses["Destroyed"] = true
	end
end

function module.NewThread(TargetScript: Script | ModuleScript | LocalScript): MultiThread
	local TargetActor = TargetScript:GetActor()

	if not TargetActor then
		error("No actor found for TargetScript: " .. TargetScript:GetFullName())
	end

	local Bubble = ActorLink(TargetActor)

	if Bubble.Destroyed then
		error("Actor bubble has been destroyed")
	end

	local GUID = HttpService:GenerateGUID(false)

	local Thread = setmetatable({
		ThreadSink = SharedTable.new(),
		ID = GUID,
		Actor = TargetActor,
		Destroyed = false,
	}, ThreadClass) :: any

	Bubble.kids[GUID] = Thread

	return Thread
end


export type PoolJob = {
	ID: string,
	Action: string,
	Args: {any},
}

export type PoolWorker = {
	Thread: MultiThread,
	Busy: boolean,
	Destroyed: boolean,
}

export type ThreadPool = {
	Workers: {PoolWorker},
	Queue: {PoolJob},
	Destroyed: boolean,

	Submit: (self: ThreadPool, Action: string, ...any) -> any,
	Map: (self: ThreadPool, Action: string, Items: {any}) -> any,
	Destroy: (self: ThreadPool) -> (),
}

local PoolClass = {}
PoolClass.__index = PoolClass

local PoolPromiseClass = {}
PoolPromiseClass.__index = PoolPromiseClass

local function NewPoolPromise()
	local Event = Instance.new("BindableEvent")

	local Promise = {
		State = "Pending",
		Value = nil,
		Error = nil,
		Event = Event,
		Callbacks = {},
		Errors = {},
	}

	function Promise:Resolve(Value)
		if self.State ~= "Pending" then
			return
		end

		self.State = "Resolved"
		self.Value = Value

		for _, Callback in self.Callbacks do
			task.spawn(Callback, Value)
		end

		table.clear(self.Callbacks)
		table.clear(self.Errors)
		self.Event:Fire()
	end

	function Promise:Reject(Reason)
		if self.State ~= "Pending" then
			return
		end

		self.State = "Rejected"
		self.Error = Reason

		for _, Callback in self.Errors do
			task.spawn(Callback, Reason)
		end

		table.clear(self.Callbacks)
		table.clear(self.Errors)
		self.Event:Fire()
	end

	function Promise:AndThen(Callback)
		if self.State == "Resolved" then
			task.spawn(Callback, self.Value)
		elseif self.State == "Pending" then
			table.insert(self.Callbacks, Callback)
		end

		return self
	end

	function Promise:Catch(Callback)
		if self.State == "Rejected" then
			task.spawn(Callback, self.Error)
		elseif self.State == "Pending" then
			table.insert(self.Errors, Callback)
		end

		return self
	end

	function Promise:Await()
		while self.State == "Pending" do
			self.Event.Event:Wait()
		end

		if self.State == "Resolved" then
			return true, self.Value
		end

		return false, self.Error
	end

	return Promise
end

local function PumpPool(Pool: ThreadPool)
	if Pool.Destroyed then
		return
	end

	for _, Worker in Pool.Workers do
		if Worker.Destroyed or Worker.Busy then
			continue
		end

		local Job = table.remove(Pool.Queue, 1)

		if not Job then
			break
		end

		Worker.Busy = true

		task.spawn(function()
			local Success, Result = pcall(function()
				local Promise = Worker.Thread:Action(
					Job.Action,
					table.unpack(Job.Args)
				)

				local Resolved, Value = Promise:Await()

				if not Resolved then
					error(tostring(Value))
				end

				return Value
			end)

			Worker.Busy = false

			if Job.Promise.State == "Pending" then
				if Success then
					Job.Promise:Resolve(Result)
				else
					Job.Promise:Reject(Result)
				end
			end

			if not Pool.Destroyed then
				PumpPool(Pool)
			end
		end)
	end
end

function module.NewPool(
	TargetScripts: {Script | ModuleScript | LocalScript}
): ThreadPool
	assert(#TargetScripts > 0, "ThreadPool requires at least one worker")

	local Pool: ThreadPool = setmetatable({
		Workers = {},
		Queue = {},
		Destroyed = false,
	}, PoolClass) :: any

	for _, TargetScript in TargetScripts do
		local Thread = module.NewThread(TargetScript)

		table.insert(Pool.Workers, {
			Thread = Thread,
			Busy = false,
			Destroyed = false,
		})
	end

	return Pool
end

function PoolClass:Submit(Action: string, ...: any)
	local Pool = self :: ThreadPool

	local Promise = NewPoolPromise()

	if Pool.Destroyed then
		Promise:Reject("ThreadPool has been destroyed")
		return Promise
	end

	local Job = {
		ID = HttpService:GenerateGUID(false),
		Action = Action,
		Args = {...},
		Promise = Promise,
	}

	table.insert(Pool.Queue, Job)

	PumpPool(Pool)

	return Promise
end

function PoolClass:Map(Action: string, Items: {any})
	local Pool = self :: ThreadPool
	local ResultPromise = NewPoolPromise()

	if Pool.Destroyed then
		ResultPromise:Reject("ThreadPool has been destroyed")
		return ResultPromise
	end

	task.spawn(function()
		local Results = table.create(#Items)

		for Index, Item in Items do
			local Success, Result = Pool:Submit(Action, Item):Await()

			if not Success then
				ResultPromise:Reject(Result)
				return
			end

			Results[Index] = Result
		end

		ResultPromise:Resolve(Results)
	end)

	return ResultPromise
end

function PoolClass:Destroy()
	local Pool = self :: ThreadPool

	if Pool.Destroyed then
		return
	end

	Pool.Destroyed = true

	for _, Job in Pool.Queue do
		Job.Promise:Reject("ThreadPool destroyed before job execution")
	end

	table.clear(Pool.Queue)

	for _, Worker in Pool.Workers do
		Worker.Destroyed = true
		Worker.Thread:Destroy()
	end

	table.clear(Pool.Workers)
end

function module.GetThread(Actor: Actor, ID: string): MultiThread?
	local Bubble = ThreadLinker[Actor]

	if not Bubble or Bubble.Destroyed then
		return nil
	end

	return Bubble.kids[ID]
end

function module.DestroyActor(Actor: Actor)
	local Bubble = ThreadLinker[Actor]

	if Bubble then
		StopBubble(Actor, Bubble)
	end
end



return module