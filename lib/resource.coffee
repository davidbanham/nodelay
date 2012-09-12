EventEmitter = require('events').EventEmitter

jsondiffpatch = require 'jsondiffpatch'


onlyChanges = (older, newer) ->
  # Too hard basket
  return newer if older instanceof Array or newer instanceof Array

  obj = {}
  changed = false
  for k of older 
    if typeof older[k] is 'object' and typeof newer[k] is 'object'
      changes = onlyChanges older[k], newer[k]
      if changes
        obj[k] = changes
        changed = true
    else
      if newer[k] != older[k]
        obj[k] = newer[k]
        changed = true
  for k of newer
    unless obj[k]? or older[k]?
      obj[k] = newer[k]
      changed = true

  if changed then obj else null



deepMerge = (dst, src) ->
  #console.log "deepmerging", src, "into", dst
  for k, srcv of src
    dstv = dst[k]
    if typeof dstv is 'object' and typeof srcv is 'object'
      deepMerge dstv, srcv
    else
      dst[k] = srcv

clobber = (dst, src) ->
  delete dst[k] for k, v of dst
  dst[k] = src[k] for k, v of src



class Resource
  constructor: (@node, @path, @data) ->

  check: (path) ->
    cur = @data
    path = Array.prototype.slice.apply(arguments) if typeof path is 'string'
    for comp of path
      cur = cur[comp]
      return null unless cur?
    
    new Resource @node, @path.concat(path), cur


  sub: (path) ->
    #console.log "descending from ", @path, "into", path
    cur = @data
    #console.log "data is", @data
    #console.log "@#*@&#(@*%" if @data[0]
    path = Array.prototype.slice.apply(arguments) if typeof path is 'string'
    
    for comp in path
      cur[comp] ||= {}
      cur = cur[comp]
    
    new Resource @node, @path.concat(path), cur

  merge: (data, merge="simple") ->
    switch merge
      when "simple" then deepMerge @data, data
      when "clobber" then clobber @data, data
      else console.warn "Unknown merge type", merge

  update: (data, merge) ->
    @merge data, merge
    @sendUpdate data, merge

  snapshot: ->
    sendUpdate @data

  sendUpdate: (data, merge) ->
    # TODO: onlyChanges/diff/patch
    if merge
      @send type: "resource update", merge: merge, data: data
    else
      @send "resource update", data

  send: (type, data) ->
    msg = @node.buildMsg type, data
    msg.resource = @path
    @node.send msg

  on: (selector, cb) ->
    resMatcher = {}
    if typeof selector is 'object'
      resMatcher[k] = v for k, v of selector
    else if typeof selector is 'string'
      resMatcher.type = selector
    else
      console.warn "Invalid selector", selector

    resMatcher.resource = @path

    @node.on resMatcher, (msg) => cb this, msg

  watch: (updateCB) ->
    @updateCB = updateCB if updateCB
    @node.on {type: "resource update", resource: @path}, @handleResourceUpdate
    @node.on {type: "resource update request", resource: @path}, @handleUpReq

  scopePath: (path) ->
    for component, i in @path
     #console.log "comparing", path[i], "with", component 
     break unless path[i] == component
    path.slice(i)

  handleResourceUpdate: ({resource, merge, data}) =>
    #console.log "got resource update for path", resource, "data", data
    path = @scopePath resource
    #console.log "updated resource path", path
    res = @sub path #@scopePath resource
    #console.log "subresource path", res.path, "data", res.data
    res.merge data, merge

    @updateCB? this, @data #res, msg.data
    #console.log "node.resources", @node.resources.data
    res

  handleUpReq: ({resource, merge, data}) =>
    res = @check @scopePath resource
    res?.snapshot()


class Selector
  constructor: (@node, selector, @updateCB) ->
    matcher = {type: "resource update", data: selector}

    console.log @node.name, "listening for", matcher
    @node.on matcher, @handleMatchUpdate


    @resources = {}
    @matchedResources = {}
    @matchers = []

  handleMatchUpdate: ({resource, merge, data}) =>
    resource = [resource] if typeof resource is 'string'
    strForm = resource.join '\x1f'
    if !@matchedResources[strForm]
      console.log @node.name, "adding new resource", resource
      res = @node.resources.sub resource
      res.watch(@updateCB)
      res.handleResourceUpdate {resource, merge, data}

      @matchedResources[strForm] = res

      for {matcher, cb} in @matchers
        res.on matcher, cb

  on: (matcher, cb) ->
    @matchers.push {matcher, cb}
    for path, res of @matchedResources
      res.on matcher, cb

  each: (cb) ->
    for path, res of @matchedResources
      cb res.path, res

Resource.Selector = Selector

module.exports = Resource