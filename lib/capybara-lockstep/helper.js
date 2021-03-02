window.CapybaraLockstep = (function() {
  var count = 0
  var idleCallbacks = []

  function isIdle() {
    // Can't check for document.readyState or body.initializing here,
    // since the user might navigate away from the page before it finishes
    // initializing.
    return count === 0
  }

  function isBusy() {
    return !isIdle()
  }

  function startWork() {
    count++
  }

  function startWorkUntil(promise) {
    startWork()
    promise.then(stopWork, stopWork)
  }

  function startWorkForTime(time) {
    startWork()
    setTimeout(stopWork, time)
  }

  function startWorkForMicrotask() {
    startWork()
    Promise.resolve().then(stopWork)
  }

  function stopWork() {
    count--

    if (isIdle()) {
      idleCallbacks.forEach(function(callback) {
        callback('JavaScript has finished')
      })
      idleCallbacks = []
    }
  }

  function trackFetch() {
    if (!window.fetch) {
      return
    }

    var oldFetch = window.fetch
    window.fetch = function() {
      var promise = oldFetch.apply(this, arguments)
      startWorkUntil(promise)
      return promise
    }
  }

  function trackXHR() {
    var oldSend = XMLHttpRequest.prototype.send

    XMLHttpRequest.prototype.send = function() {
      startWork()

      try {
        this.addEventListener('readystatechange', function(event) {
          if (this.readyState === 4) { stopWork() }
        }.bind(this))
        return oldSend.apply(this, arguments)
      } catch (e) {
        // If we get a sync exception during request dispatch
        // we assume the request never went out.
        stopWork()
        throw e
      }
    }
  }

  function trackInteraction() {
    ['click',  'mousedown', 'keydown', 'change', 'input', 'submit', 'focusin', 'focusout', 'scroll'].forEach(function(eventType) {
      // Use { useCapture: true } so we get the event before another listener
      // can prevent it from bubbling up to the document.
      document.addEventListener(eventType, onInteraction, { capture: true, passive: true })
    })
  }

  function onInteraction() {
    // We wait until the end of this task, assuming that any callback that
    // would queue an AJAX request or load additional scripts will run by then.
    startWorkForMicrotask()
  }

  function trackHistory() {
    ['popstate'].forEach(function(eventType) {
      document.addEventListener(eventType, onHistoryEvent)
    })
  }

  function onHistoryEvent() {
    // After calling history.back() or history.forward() the popstate event will *not*
    // fire synchronously. It will also not fire in the next task. Chrome sometimes fires
    // it after 10ms, but sometimes it takes longer.
    startWorkForTime(100)
  }

  function trackDynamicScripts() {
    if (!window.MutationObserver) {
      return
    }

    var observer = new MutationObserver(onMutated)
    observer.observe(document, { subtree: true, childList: true })
  }

  function trackJQuery() {
    // jQuery may be loaded after us, so we wait until DOMContentReady.
    whenReady(function() {
      if (!window.jQuery) {
        return
      }

      // Although $.ajax() uses XHR internally, it also uses $.Deferred() which does
      // not resolve in the next microtask but in the next *task* (it makes itself
      // async using setTimoeut()). Hence we need to wait for it in addition to XHR.
      var oldAjax = jQuery.ajax
      jQuery.ajax = function () {
        var promise = oldAjax.apply(this, arguments)
        startWorkUntil(promise)
        return promise
      }
    })
  }

  function isRemoteScript(node) {
    if (node.nodeType === Node.ELEMENT_NODE && node.tagName === 'SCRIPT') {
      var src = node.getAttribute('src')
      var type = node.getAttribute('type')

      return (src && (!type || /javascript/i.test(type)))
    }
  }

  function onRemoteScriptAdded(script) {
    startWork()
    // Chrome runs a remote <script> *before* the load event fires.
    script.addEventListener('load', stopWork)
    script.addEventListener('error', stopWork)
  }

  function onMutated(changes) {
    changes.forEach(function(change) {
      change.addedNodes.forEach(function(addedNode) {
        if (isRemoteScript(addedNode)) {
          onRemoteScriptAdded(addedNode)
        }
      })
    })
  }

  function whenReady(callback) {
    // Values are "loading", "interactive" and "completed".
    // https://developer.mozilla.org/en-US/docs/Web/API/Document/readyState
    if (document.readyState != 'loading') {
      callback()
    } else {
      document.addEventListener('DOMContentLoaded', callback)
    }
  }

  function track() {
    trackFetch()
    trackXHR()
    trackInteraction()
    trackHistory()
    trackDynamicScripts()
    trackJQuery()
  }

  function awaitIdle(callback) {
    if (isIdle()) {
      callback()
    } else {
      idleCallbacks.push(callback)
    }
  }

  return {
    track: track,
    startWork: startWork,
    stopWork: stopWork,
    awaitIdle: awaitIdle,
    isIdle: isIdle,
    isBusy: isBusy
  }
})()

CapybaraLockstep.track()
