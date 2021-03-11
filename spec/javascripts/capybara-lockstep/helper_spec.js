describe("CapybaraLockstep", function() {

  afterEach(function(done) {
    // Wait for one task so any pending callbacks have a chance to stopWork()
    setTimeout(function() {
      CapybaraLockstep.reset()
      done()
    })
  })

  it('is defined', function() {
    expect(window.CapybaraLockstep).toBeTruthy()
  })

  describe('.startWork()', function() {

    it('makes the browser busy', function() {
      expect(CapybaraLockstep).toBeIdle()
      CapybaraLockstep.startWork('job')
      expect(CapybaraLockstep).toBeBusy()
      CapybaraLockstep.stopWork('job')
    })

  })

  describe('.stopWork()', function() {

    it('makes the browser idle', function() {
      CapybaraLockstep.startWork('job')
      expect(CapybaraLockstep).toBeBusy()
      CapybaraLockstep.stopWork('job')
      expect(CapybaraLockstep).toBeIdle()
    })

    it('must be called once for each started job until the browser is idle', function() {
      CapybaraLockstep.startWork('job')
      CapybaraLockstep.startWork('job')
      expect(CapybaraLockstep).toBeBusy()
      CapybaraLockstep.stopWork('job')
      expect(CapybaraLockstep).toBeBusy()
      CapybaraLockstep.stopWork('job')
      expect(CapybaraLockstep).toBeIdle()
    })

  })

  describe('.synchronize()', function() {

    it('runs the given callback when the browser is currently idle', function() {
      expect(CapybaraLockstep).toBeIdle()
    })

  })

})
