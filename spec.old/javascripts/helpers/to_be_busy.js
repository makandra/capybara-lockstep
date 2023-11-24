beforeEach(function() {
  jasmine.addMatchers({
    toBeBusy: function (util, customEqualityTesters) {
      return {
        compare: function(lockstep) {
          return {
            pass: lockstep.isBusy()
          }
        }
      }
    }
  })
})
