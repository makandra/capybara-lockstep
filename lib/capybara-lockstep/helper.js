window.CapybaraLockstep = (function() {
  // State and configuration
  let debug
  let jobCount
  let idleCallbacks
  let waitTasks
  let initializingAttributeObserver
  reset()

  function reset() {
    jobCount = 0
    idleCallbacks = []
    waitTasks = 0
    debug = false
  }

  function isIdle() {
    // Can't check for document.readyState or body.initializing here,
    // since the user might navigate away from the page before it finishes
    // initializing.
    return jobCount === 0
  }

  function isBusy() {
    return !isIdle()
  }

  function log(...args) {
    if (debug) {
      args[0] = '%c[capybara-lockstep] ' + args[0]
      args.splice(1, 0, 'color: #666666')
      console.log.apply(console, args)
    }
  }

  function logPositive(...args) {
    args[0] = '%c' + args[0]
    log(args[0], 'color: #117722', ...args.slice(1))
  }

  function logNegative(...args) {
    args[0] = '%c' + args[0]
    log(args[0], 'color: #cc3311', ...args.slice(1))
  }

  function startWork(tag) {
    jobCount++
    if (tag) {
      logNegative('Started work: %s [%d jobs]', tag, jobCount)
    }
  }

  function startWorkUntil(promise, tag) {
    startWork(tag)
    let taggedStopWork = stopWork.bind(this, tag)
    promise.then(taggedStopWork, taggedStopWork)
  }

  function stopWork(tag) {
    let tasksElapsed = 0

    let check = function() {
      if (tasksElapsed < waitTasks) {
        tasksElapsed++
        setTimeout(check)
      } else {
        stopWorkNow(tag)
      }
    }

    check()
  }

  function stopWorkNow(tag) {
    jobCount--

    if (tag) {
      logPositive('Finished work: %s [%d jobs]', tag, jobCount)
    }

    let idleCallback
    while (isIdle() && (idleCallback = idleCallbacks.shift())) {
      idleCallback('Finished waiting for browser')
    }
  }

  function trackFetch() {
    if (!window.fetch) {
      return
    }

    let oldFetch = window.fetch
    window.fetch = function() {
      let promise = oldFetch.apply(this, arguments)
      startWorkUntil(promise, 'fetch ' + arguments[0])
      return promise
    }
  }

  function trackXHR() {
    let oldOpen = XMLHttpRequest.prototype.open
    let oldSend = XMLHttpRequest.prototype.send

    XMLHttpRequest.prototype.open = function() {
      this.capybaraLockstepURL = arguments[1]
      return oldOpen.apply(this, arguments)
    }

    XMLHttpRequest.prototype.send = function() {
      let workTag = 'XHR to '+ this.capybaraLockstepURL
      startWork(workTag)

      try {
        this.addEventListener('readystatechange', function(event) {
          if (this.readyState === 4) { stopWork(workTag) }
        }.bind(this))
        return oldSend.apply(this, arguments)
      } catch (e) {
        // If we get a sync exception during request dispatch
        // we assume the request never went out.
        stopWork(workTag)
        throw e
      }
    }
  }

  function trackRemoteElements() {
    if (!window.MutationObserver) {
      return
    }

    // Dynamic imports or analytics snippets may insert a script element
    // that loads and executes additional JavaScript. We want to be isBusy()
    // until such scripts have loaded or errored.
    let observer = new MutationObserver(onAnyElementChanged)
    observer.observe(document, { subtree: true, childList: true })
  }

  function trackJQuery() {
    // CapybaraLockstep.track() is called as the first script in the head.
    // jQuery will be loaded after us, so we wait until DOMContentReady.
    whenReady(function() {
      if (!window.jQuery || waitTasks > 0) {
        return
      }

      // Although $.ajax() uses XHR internally, it also uses $.Deferred() which does
      // not resolve in the next microtask but in the next *task* (it makes itself
      // async using setTimoeut()). Hence we need to wait for it in addition to XHR.
      //
      // If user code also uses $.Deferred(), it is also recommended to set
      // CapybaraLockdown.waitTasks = 1 or higher.
      let oldAjax = window.jQuery.ajax
      window.jQuery.ajax = function() {
        let promise = oldAjax.apply(this, arguments)
        startWorkUntil(promise)
        return promise
      }
    })
  }

  let INITIALIZING_ATTRIBUTE = 'data-initializing'

  function trackHydration() {
    // CapybaraLockstep.track() is called as the first script in the <head>,
    // so we may not have a document.body element yet. Until we see a body element
    // on which we can observe the [data-initializing] attribute
    // we consider ourselves busy. Since we're not passing a tag argument,
    // so nothing will be logged.
    startWork()
    whenReady(function() {
      stopWorkNow()
      if (document.body.hasAttribute(INITIALIZING_ATTRIBUTE)) {
        startWork('Page initialization')
        initializingAttributeObserver = new MutationObserver(onInitializingAttributeChanged)
        initializingAttributeObserver.observe(document.body, { attributes: true, attributeFilter: [INITIALIZING_ATTRIBUTE] })
      }
    })
  }

  function onInitializingAttributeChanged() {
    if (!document.body.hasAttribute(INITIALIZING_ATTRIBUTE)) {
      stopWork('Page initialization')
      initializingAttributeObserver.disconnect()
    }
  }

  function isRemoteScript(element) {
    if (element.tagName === 'SCRIPT') {
      let src = element.getAttribute('src')
      let type = element.getAttribute('type')

      return src && (!type || /javascript/i.test(type))
    }
  }

  function isRemoteImage(element) {
    if (element.tagName === 'IMG' && !element.complete) {
      let src = element.getAttribute('src')
      let srcSet = element.getAttribute('srcset')

      let localSrcPattern = /^data:/
      let localSrcSetPattern = /(^|\s)data:/

      let hasLocalSrc = src && localSrcPattern.test(src)
      let hasLocalSrcSet = srcSet && localSrcSetPattern.test(srcSet)

      return (src && !hasLocalSrc) || (srcSet && !hasLocalSrcSet)
    }
  }

  function isRemoteInlineFrame(element) {
    if (element.tagName === 'IFRAME') {
      let src = element.getAttribute('src')
      let localSrcPattern = /^data:/
      let hasLocalSrc = src && localSrcPattern.test(src)
      return (src && !hasLocalSrc)
    }
  }

  function trackRemoteElement(element, condition, workTag) {
    if (!condition(element)) {
      return
    }

    let stopped = false

    startWork(workTag)

    let doStop = function() {
      stopped = true
      element.removeEventListener('load', doStop)
      element.removeEventListener('error', doStop)
      stopWork(workTag)
    }

    let checkCondition = function() {
      if (stopped) {
        // A `load` or `error` event has fired.
        // We can stop here. No need to schedule another check.
        return
      } else if (isDetached(element) || !condition(element)) {
        // If it is detached or if its `[src]` attribute changes to a data: URL
        // we may never get a `load` or `error` event.
        doStop()
      } else {
        scheduleCheckCondition()
      }
    }

    let scheduleCheckCondition = function() {
      setTimeout(checkCondition, 200)
    }

    element.addEventListener('load', doStop)
    element.addEventListener('error', doStop)

    // We periodically check whether we still think the element will
    // produce a `load` or `error` event.
    scheduleCheckCondition()
  }

  function onAnyElementChanged(changes) {
    changes.forEach(function(change) {
      change.addedNodes.forEach(function(addedNode) {
        if (addedNode.nodeType === Node.ELEMENT_NODE) {
          trackRemoteElement(addedNode, isRemoteScript, 'Script')
          trackRemoteElement(addedNode, isRemoteImage, 'Image')
          trackRemoteElement(addedNode, isRemoteInlineFrame, 'Inline frame')
        }
      })
    })
  }

  function isDetached(element) {
    return !document.contains(element)
  }

  function whenReady(callback) {
    // Values are "loading", "interactive" and "completed".
    // https://developer.mozilla.org/en-US/docs/Web/API/Document/readyState
    if (document.readyState !== 'loading') {
      callback()
    } else {
      document.addEventListener('DOMContentLoaded', callback)
    }
  }

  function track() {
    trackFetch()
    trackXHR()
    trackRemoteElements()
    trackJQuery()
    trackHydration()
  }

  function synchronize(callback) {
    if (isIdle()) {
      callback()
    } else {
      idleCallbacks.push(callback)
    }
  }

  return {
    track: track,
    isBusy: isBusy,
    isIdle: isIdle,
    startWork: startWork,
    stopWork: stopWork,
    synchronize: synchronize,
    reset: reset,
    set debug(value) { debug = value },
    set waitTasks(value) { waitTasks = value }
  }
})()

CapybaraLockstep.track()
