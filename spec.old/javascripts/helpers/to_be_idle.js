beforeEach(function() {
  jasmine.addMatchers({
    toBeIdle: function (util, customEqualityTesters) {
      return {
        compare: function(lockstep) {
          return {
            pass: lockstep.isIdle()
          }
        }
      }
    }
  })
})
