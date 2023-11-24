describe("CapybaraLockstep", function() {

  beforeEach(function() {
    CapybaraLockstep.debug = true
  })

  afterEach(async function() {
    // Wait for one task so any pending callbacks have a chance to stopWork()
    await waitTask()
    CapybaraLockstep.reset()
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

  describe('handling of fetch() requests', function() {

    it('is busy while the request is in flight', async function() {
      fetch('https://httpstat.us/200/cors?sleep=500')
      await waitTask()
      expect(CapybaraLockstep).toBeBusy()

      await waitTime(2500)
      expect(CapybaraLockstep).toBeIdle()
    })

    it('is idle when a request is aborted', async function() {
      let abortController = new AbortController()

      fetch('https://httpstat.us/200/cors?sleep=1000', { signal: abortController.signal })
      await waitTask()
      expect(CapybaraLockstep).toBeBusy()

      abortController.abort()
      await waitTask()
      expect(CapybaraLockstep).toBeIdle()
    })

  })

  describe('handling of XHR requests', function() {

    it('is busy while the request is in flight', async function() {
      let xhr = new XMLHttpRequest()
      xhr.open('GET', 'https://httpstat.us/200/cors?sleep=500')
      xhr.send()
      await waitTask()
      expect(CapybaraLockstep).toBeBusy()

      await waitTime(2500)
      expect(CapybaraLockstep).toBeIdle()
    })

    it('is idle when a request is aborted', async function() {
      let xhr = new XMLHttpRequest()
      xhr.open('GET', 'https://httpstat.us/200/cors?sleep=500')
      xhr.send()
      await waitTask()
      expect(CapybaraLockstep).toBeBusy()

      xhr.abort()
      await waitTask()
      expect(CapybaraLockstep).toBeIdle()
    })

  })

})
