fs      = require 'fs'
path    = require 'path'
{exec}  = require 'child_process'

vows    = require 'vows'
assert  = require 'assert'

resource = require '../lib/resource'

describe = (name, bat) -> vows.describe(name).addBatch(bat).export(module)
exists = fs.existsSync or path.existsSync


# Make coffeescript not return anything
# This is needed because vows topics do different things if you have a return value
t = (fn) ->
  (args...) ->
    fn.apply this, args
    return

onlyChanges = resource.onlyChanges

describe "A resource"
  "is created with resource(node, path, args)":
    topic: -> new resource({}, [], {})
    
    "which returns an object": (s) -> assert.isObject s


describe "onlyChanges"
  "on two values":
    "when the values are unequal":
      topic: -> onlyChanges 1, 2
      
      "returns the second value": (v) -> assert.equal v, 2

    "when the values are equal":
      topic: -> onlyChanges 5, 5
      
      "returns null": (v) -> assert.strictEqual v, null

  "on two arrays":
    "when the second is longer than the first":
      topic: -> onlyChanges [1,2,3,4], [1,2,3,4,5,6]
    
      "returns the second value": (v) -> assert.deepEqual v, [1,2,3,4,5,6]

    "when the second is shorter than the first":
      topic: -> onlyChanges [1,2,3,4], [1,2]
    
      "returns the second value": (v) -> assert.deepEqual v, [1,2]

    "when the second is equal to the first":
      topic: -> onlyChanges [1,2,3,4], [1,2,3,4]
    
      "returns null": (v) -> assert.strictEqual v, null

  "on two objects":
    "when there are new keys in the new object":
      topic: -> onlyChanges {a:1}, {a:1, b:2}

      "returns just the new keys": (v) -> assert.deepEqual v, {b:2}

    "when there are the same keys with changed values":
      topic: -> onlyChanges {a:1, b:2}, {a:1, b:3}
    
      "returns the keys with changed values": (v) -> assert.deepEqual v, {b:3}

    "when there are the same keys with the same values":
      topic: -> onlyChanges {a:1, b:2}, {a:1, b:2}
    
      "returns null": (v) -> assert.strictEqual v, null

    "when keys are removed in the new object":
      topic: -> onlyChanges {a:1, b:2}, {a:1}
    
      "returns null": (v) -> assert.strictEqual v, null

  "on an object containing objects":
    "when the nested objects have changes":
      topic: -> onlyChanges {a:{a:1,b:2}, b:{a:1,b:2}}, {a:{a:1,b:2}, b:{a:1,b:1}}

      "returns only the changed objects": (v) -> assert.deepEqual v, {b:{b:1}}

    "when the nested objects have no changes":
      topic: -> onlyChanges {a:{a:1,b:2}, b:{a:1,b:2}}, {a:{a:1,b:2}, b:{a:1,b:2}}

      "returns null": (v) -> assert.strictEqual v, null

  "on same-sized arrays containing objects":
    "when the nested objects have changes":
      topic: -> onlyChanges [{a:1},{b:2},{c:3}],[{a:1},{b:1},{c:3}]

      "returns only the changed objects, and fills the rest of the array with empty objects": (v) -> assert.deepEqual v, [{},{b:1},{}]

    "when the nested objects have no changes":
      topic: -> onlyChanges [{a:1},{b:2},{c:3}],[{a:1},{b:2},{c:3}]

      "returns null": (v) -> assert.strictEqual v, null

  "on same-sized arrays containing arrays":
    "when the nested arrays have changes":
      topic: -> onlyChanges [[1,2,3],[4,5,6],[7,8,9]],[[1,1,3],[4,5,6],[7,8,9]]

      "returns all elements of the array": (v) -> assert.deepEqual v, [[1,1,3],[4,5,6],[7,8,9]]

    "when the nested arrays have no changes":
      topic: -> onlyChanges [[1,2,3],[4,5,6],[7,8,9]],[[1,2,3],[4,5,6],[7,8,9]]

      "returns null": (v) -> assert.strictEqual v, null

