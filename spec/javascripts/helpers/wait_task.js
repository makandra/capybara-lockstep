window.waitTask = function() {
  return new Promise(function(resolve, _reject) {
    setTimeout(resolve)
  })
}
