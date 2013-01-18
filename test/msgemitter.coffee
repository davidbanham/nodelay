fs      = require 'fs'
path    = require 'path'
{exec}  = require 'child_process'

vows    = require 'vows'
assert  = require 'assert'

MsgEmitter = require '../lib/msgemitter'

describe = (name, bat) -> vows.describe(name).addBatch(bat).export(module)
exists = fs.existsSync or path.existsSync


# Make coffeescript not return anything
# This is needed because vows topics do different things if you have a return value
t = (fn) ->
  (args...) ->
    fn.apply this, args
    return

describe "A msg emitter"
  "is created with new MsgEmitter()":
    topic: -> new MsgEmitter
    
    "which returns an object": (s) -> assert.isObject s

  "when listening for anything": 
    topic: ->
      m = new MsgEmitter()
      m.on {}, (msg) => m.calledCount++
      m.calledCount = 0
      m

    "and a message is emitted":
      topic: (m) ->
        m.emit {asdf: 1234}
        m
      "the callback fires once": (m) ->
        assert.equal m.calledCount, 1

  "when listening for a string": 
    topic: ->
      m = new MsgEmitter()
      m.on "hello", (msg) => m.calledCount[msg.key] ||= 0; m.calledCount[msg.key]++
      m.calledCount = {}
      m

    "and a message with a type set to that string is emitted":
      topic: (m) ->
        m.emit {type: "hello", key: 1}
        m
      "the callback fires once": (m) ->
        assert.equal m.calledCount[1], 1

    "and a message with a different type is emitted":
      topic: (m) ->
        m.emit {type: "world", key: 2}
        m
      "the callback does not fire": (m) ->
        assert.equal m.calledCount[2], undefined


  "when listening for two different strings": 
    topic: ->
      m = new MsgEmitter()
      m.on "hello", (msg) => m.calledCount[msg.key] ||= 0; m.calledCount[msg.key]++
      m.on "world", (msg) => m.calledCount[msg.key] ||= 0; m.calledCount[msg.key]++
      m.calledCount = {}
      m

    "and a message with the first type is emitted":
      topic: (m) ->
        m.emit {type: "hello", key: 1}
        m
      "the callback fires once": (m) ->
        assert.equal m.calledCount[1], 1

    "and a message with the second type is emitted":
      topic: (m) ->
        m.emit {type: "world", key: 2}
        m
      "the callback fires once": (m) ->
        assert.equal m.calledCount[2], 1

    "and a message with a different type is emitted":
      topic: (m) ->
        m.emit {type: "troz", key: 3}
        m
      "the callback does not fire": (m) ->
        assert.equal m.calledCount[3], undefined

  "when listening for an object": 
    topic: ->
      m = new MsgEmitter()
      m.on {a:1, b:2}, (msg) => m.calledCount[msg.key] ||= 0; m.calledCount[msg.key]++
      m.on {a:2, b:3}, (msg) => m.calledCount[msg.key] ||= 0; m.calledCount[msg.key]++
      m.calledCount = {}
      m

    "and a message with every property in the object matching is emitted":
      topic: (m) ->
        m.emit {a:1, b:2, key: 1}
        m
      "the callback fires once": (m) ->
        assert.equal m.calledCount[1], 1

    "and a message with every property but different values is emitted":
      topic: (m) ->
        m.emit {a: 1, b: 3, key: 2}
        m
      "the callback does not fire": (m) ->
        assert.equal m.calledCount[2], undefined

    "and a message with some but not all properties is emitted":
      topic: (m) ->
        m.emit {a: 1, key: 3}
        m
      "the callback does not fire": (m) ->
        assert.equal m.calledCount[3], undefined


  "when listening for resources": 
    topic: ->
      m = new MsgEmitter()
      m.on {resource: ["hello", "world"]}, (msg) => m.calledCount[msg.key] ||= 0; m.calledCount[msg.key]++
      m.on {resource: ["goodnight", "moon"]}, (msg) => m.calledCount[msg.key] ||= 0; m.calledCount[msg.key]++
      m.calledCount = {}
      m

    "and a message with that entire resource is emitted":
      topic: (m) ->
        m.emit {resource: ["hello", "world"], key: 1}
        m
      "the callback fires once": (m) ->
        assert.equal m.calledCount[1], 1

    "and a message with a longer matching resource is emitted":
      topic: (m) ->
        m.emit {resource: ["hello", "world", "internet"], key: 2}
        m
      "the callback fires once": (m) ->
        assert.equal m.calledCount[2], 1

    "and a message with a shorter matching resource is emitted":
      topic: (m) ->
        m.emit {resource: ["hello"], key: 3}
        m
      "the callback does not fire": (m) ->
        assert.equal m.calledCount[3], undefined

    "and a message with equal but non-matching resources is emitted":
      topic: (m) ->
        m.emit {resource: ["hello", "internet"], key: 4}
        m
      "the callback does not fire": (m) ->
        assert.equal m.calledCount[4], undefined


  "when listening for an object with a scope property": 
    topic: ->
      m = new MsgEmitter()
      m.on {scope: 'link'}, (msg) => m.calledCount[msg.key] ||= 0; m.calledCount[msg.key]++
      m.on {scope: 'internet'}, (msg) => m.calledCount[msg.key] ||= 0; m.calledCount[msg.key]++
      m.calledCount = {}
      m

    "and a message with that scope is emitted":
      topic: (m) ->
        m.emit {scope: 'link', key: 1}
        m
      "the callback fires once": (m) ->
        assert.equal m.calledCount[1], 1

    "and a message with no scope is emitted":
      topic: (m) ->
        m.emit {istanbul: 'constantinople', key: 2}
        m
      "the callback does not fire": (m) ->
        assert.equal m.calledCount[2], undefined

    "and a message with a different scope is emitted":
      topic: (m) ->
        m.emit {scope: 'bees', key: 3}
        m
      "the callback does not fire": (m) ->
        assert.equal m.calledCount[3], undefined