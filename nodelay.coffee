Node = require './lib/node'

EventEmitter = require('events').EventEmitter
{fork} = require 'child_process'
path = require 'path'
fs = require 'fs'

forkCoffee = (script, args, options={}) ->
  coffeePath = path.join __dirname, 'node_modules/.bin/coffee'
  [oldExecPath, process.execPath] = [process.execPath, coffeePath]
  if not fs.existsSync script
    script = path.join __dirname, script
    options.cwd ?= __dirname

  child = fork script, args, options
  
  process.execPath = oldExecPath
  child

class Nodelay extends EventEmitter
  constructor: (name, init) ->
    return new Nodelay name, init if this is global

    @name = name

    @resources = {}
    @controllers = []
    @workers = []
    @monitors = []

    @proxy = {in: [], out:[]}
    @node = new Node name

    dsl =
      instance: this
      node: @node
      upstream: (host, port) => @upstream = {host, port}
      bind: (@bind, @port) =>
      proxy: (proxy) =>
        @proxy.in.push proxy.in... if proxy.in
        @proxy.out.push proxy.out... if proxy.out
      on: @on
      scope: (@scope...) =>
      workers: (@workers...) =>
      monitors: (@monitors...) =>
      controllers: (@controllers...) =>
      privkey: (privkey) =>
        @privkey = fs.readFileSync(privkey)
        @node.privkey = @privkey
      pubkey: (pubkey) =>
        @pubkey = fs.readFileSync(pubkey)
        @node.pubkey = @pubkey
        @node.auth = (msg) -> true
      resource: (name, resource) =>
        resource.name = name
        @resources[name] = resource

    init?.call dsl

    if @upstream
      @node.connect @upstream.host, @upstream.port, =>
        @emit "connected"
        if @privkey
          @node.send type: 'auth', signed: true, scope: 'link'

    @node.listen @bind, @port
    

    if @scope
      @node.parent?.on {resource: @scope}, (msg) =>
        return if msg.scope is 'link'
        
        if typeof msg?.resource is 'object' and msg instanceof Array
          for scope in @scope
            break unless msg[0] == @scope
            msg.resource.shift()

        @node.children.forward msg

      @node.parent?.outFilter = (msg) ->
        if msg.resource
          msg.resource = [msg.resource] if typeof msg.resource is 'string'                
          msg.resource.unshift @scope...

    else
      @node.parent?.on '*', (msg) => @node.children.forward msg unless msg.scope is 'link'

    @node.children.on '*', (msg) => @node.children.forward msg unless msg.scope is 'link'
    #@node.children.on 'listen', (msg) =>

    @node.children.on '*', (msg) =>
      return if msg.scope is 'link'
      msg = JSON.parse JSON.stringify msg
      if typeof msg.from is "object"
        msg.from.unshift @name
      else if typeof msg.from is "undefined"
        msg.from = @name
      else
        msg.from = [@name, msg.from]

      #if @scope and msg.resource
      #  msg.resource = [msg.resource] if typeof msg.resource is 'string'                
      #  msg.resource.unshift @scope...

      @node.parent?.forward msg

    args = if @port then [@port] else []
    forkCoffee "controllers/#{controller}.coffee", args for controller in @controllers
    forkCoffee "workers/#{worker}.coffee", args for worker in @workers
    forkCoffee "monitors/#{monitor}.coffee", args for monitor in @monitors

    setTimeout =>
      #console.log "resources:", @resources
      for name, resource of @resources
        res = @node.resource name
        res.update resource

        #@node.children?.send type: "add resource", resource: name, data: resource
        #@node.parent?.send type: "add resource", resource: [@name, name], data: resource
    , 2000


Nodelay.Node = Node
module.exports = Nodelay 
