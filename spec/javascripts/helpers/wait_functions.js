window.waitTask = function() {
  return waitTime(0)
}

window.waitTime = function(time) {
  return new Promise(function(resolve, _reject) {
    setTimeout(resolve, time)
  })
}
