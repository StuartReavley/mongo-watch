should = require 'should'
logger = require 'ale'

QueryDelta = require '../lib/QueryDelta'

testEvent = (event, name) ->
  should.exist event
  event.should.include {
    t: 'd' # type: delta
    op: 'u'
    ns: 'test.users'
  }
  should.exist event?.o?.$set?.name, 'expected name'
  event.o.$set.name.should.eql name
  should.exist event._id, 'expected _id'

boiler 'Query Delta', ->

  it 'should receive delta event', (done) ->
    delta = new QueryDelta {stream: @watcher.stream, @collName}

    @users.update {email: @grahamEmail}, {$set: {name: 'Graham'}}, (err, status) =>
      should.not.exist err

    delta.once 'data', (event) =>
      testEvent event, 'Graham'

      done()

  it 'should filter records', (done) ->
    delta = new QueryDelta {stream: @watcher.stream, @collName, idSet: [@aliceId]}

    delta.once 'data', (event) =>
      testEvent event, 'Alice'
      done()

    @users.update {email: @grahamEmail}, {$set: {name: 'Graham'}}, (err, status) =>
      should.not.exist err
      @users.update {email: @aliceEmail}, {$set: {name: 'Alice'}}, (err, status) =>
        should.not.exist err

  it 'should select records', (done) ->
    delta = new QueryDelta {stream: @watcher.stream, @collName, select: {name: true}}

    delta.once 'data', (update) =>
      update.should.include {
        t: 'd'
        op: 'u'
        ns: 'test.users'
        o2: {_id: @aliceId}
        _id: @aliceId
      }
      should.exist update?.o?.$set, 'expected $set operation'
      update.o.$set.should.include {name: 'Alice'}
      update.o.$set.should.not.include {loginCount: 5}
      done()

    @users.update {email: @aliceEmail}, {$set: {name: 'Alice', loginCount: 5}}, (err, status) =>
      should.not.exist err

  it 'should ignore records', (done) ->
    delta = new QueryDelta {stream: @watcher.stream, @collName, select: {habitat: true}}

    triggered = null

    checkTrigger = ->
      should.not.exist triggered, 'should not have gotten delta!'
      done()

    delta.once 'data', (update) =>
      triggered = true

    @watcher.stream.once 'data', (event) ->
      process.nextTick checkTrigger

    @users.update {email: @aliceEmail}, {$set: {name: 'Alice', loginCount: 5}}, (err, status) =>
      should.not.exist err
