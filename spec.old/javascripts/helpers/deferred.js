window.newDeferred = function() {
  let resolve, reject
  let promise = new Promise(function(resolveArg, rejectArg) {
    resolve = resolveArg
    reject = rejectArg
  })
  promise.resolve = resolve
  promise.reject = reject
  return promise
}