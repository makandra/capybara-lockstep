window.CapybaraLockstep = (function() {
  let originalSetTimeout = window.setTimeout;
  let originalClearTimeout = window.clearTimeout;

  // State and configuration
  let debug
  let jobCount
  let idleCallbacks
  let finishedWorkTags
  let defaultWaitTasks
  reset()

  function reset() {
    jobCount = 0
    idleCallbacks = []
    finishedWorkTags = []
    defaultWaitTasks = 1
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

  function stopWork(tag, waitAdditionalTasks = 0) {
    let effectiveWaitTasks = defaultWaitTasks + waitAdditionalTasks
    afterWaitTasks(stopWorkNow.bind(this, tag), effectiveWaitTasks)
  }

  function stopWorkNow(tag) {
    jobCount--

    if (tag) {
      finishedWorkTags.push(tag)
      logPositive('Finished work: %s [%d jobs]', tag, jobCount)
    }

    if (isIdle()) {
      let idleCallback
      while ((idleCallback = idleCallbacks.shift())) {
        idleCallback("Finished waiting for " + finishedWorkTags.join(', '))
      }

      finishedWorkTags = []
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

  function trackHistory() {
    // Wait an additional task because some browsers seem to require additional
    // time before the URL changes.
    trackEvent(document, 'popstate', 1)
    trackEvent(document, 'hashchange', 1)

    // API: https://developer.mozilla.org/en-US/docs/Web/API/History
    for (let method of ['pushState', 'popState', 'forward', 'back', 'go']) {
      let workTag = `history.${method}()`
      let nativeImpl = history[method]
      history[method] = function(...args) {
        try {
          startWork(workTag)
          return nativeImpl.apply(history, args)
        } finally {
          stopWork(workTag, 1)
        }
      }
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
      if (!window.jQuery || defaultWaitTasks > 0) {
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

  function trackSetTimeout() {
    let timeoutIds = new Set();

    window.setTimeout = function(callback, delay, ...args) {
      let doWait = delay < 5000;

      let timeoutId;
      let wrappedCallback = () => {
        try {
          callback(...args);
        } finally {
          if (doWait) {
            stopWork('setTimeout()');
          }
          timeoutIds.delete(timeoutId);
        }
      };

      if (doWait) {
        startWork('setTimeout()');
      }
      timeoutId = originalSetTimeout(wrappedCallback, delay);
      if (doWait) {
        timeoutIds.add(timeoutId)
      }

      return timeoutId;
    };

    window.clearTimeout = function(timeoutId) {
      if (timeoutIds.delete(timeoutId)) {
        stopWork('setTimeout()');
      }
      return originalClearTimeout(timeoutId);
    };
  }

  function isRemoteScript(element) {
    return element.matches('script[src]') && !hasDataSource(element) && isTrackableScriptType(element.type)
  }

  function isTrackableImage(element) {
    return element.matches('img') &&
      !element.complete &&
      !hasDataSource(element) &&
      element.getAttribute('loading') !== 'lazy'
  }

  function isTrackableIFrame(element) {
    return element.matches('iframe[src]') &&
      !hasDataSource(element) &&
      element.getAttribute('loading') !== 'lazy'
  }

  function isTrackableScriptType(type) {
    return !type || type === 'text/javascript' || type === 'module' || type === 'application/javascript'
  }

  function hasDataSource(element) {
    // <img> can have <img src> and <img srcset>
    // <video> can have <video src> or <video><source src>
    // <audio> can have <audio src> or <audio><source src>
    return element.matches('[src*="data:"], [srcset*="data:"]') ||
      !!element.querySelector('source [src*="data:"], source [srcset*="data:"]')
  }

  function trackRemoteElement(element, condition, workTag) {
    trackLoadingElement(element, condition, workTag, 'load', 'error')

  }

  function trackLoadingElement(element, condition, workTag, loadEvent, errorEvent) {
    if (!condition(element)) {
      return
    }

    let stopped = false

    startWork(workTag)

    let doStop = function() {
      stopped = true
      element.removeEventListener(loadEvent, doStop)
      element.removeEventListener(errorEvent, doStop)
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
      originalSetTimeout(checkCondition, 150)
    }

    element.addEventListener(loadEvent, doStop)
    element.addEventListener(errorEvent, doStop)

    // We periodically check whether we still think the element will
    // produce a `load` or `error` event.
    scheduleCheckCondition()
  }

  function onAnyElementChanged(changes) {
    changes.forEach(function(change) {
      change.addedNodes.forEach(function(addedNode) {
        if (addedNode.nodeType === Node.ELEMENT_NODE) {
          trackRemoteElement(addedNode, isRemoteScript, 'Script')
          trackRemoteElement(addedNode, isTrackableImage, 'Image')
          trackRemoteElement(addedNode, isTrackableIFrame, 'Inline frame')
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

  function afterWaitTasks(fn, waitTasks = defaultWaitTasks) {
    if (waitTasks > 0) {
      // Wait 1 task and recurse
      originalSetTimeout(function() {
        afterWaitTasks(fn, waitTasks - 1)
      })
    } else {
      fn()
    }
  }

  function trackOldUnpoly() {
    // CapybaraLockstep.track() is called as the first script in the head.
    // Unpoly will be loaded after us, so we wait until DOMContentReady.
    whenReady(function() {
      // Unpoly 0.x would wait one task after DOMContentLoaded before booting.
      // There's a slim chance that Capybara can observe the page before compilers have run.
      // Unpoly 1.0+ runs compilers on DOMContentLoaded, so there's no issue.
      if (window.up?.version?.startsWith('0.')) {
        startWork('Old Unpoly')
        originalSetTimeout(function() {
          stopWork('Old Unpoly')
        })
      }
    })
  }

  function trackEvent(eventTarget, eventType, waitAdditionalTasks = 0) {
    eventTarget.addEventListener(eventType, function() {
      // Only litter the log with interaction events if we're actually going
      // to be busy for at least 1 task.
      let effectiveWaitTasks = defaultWaitTasks + waitAdditionalTasks

      if (effectiveWaitTasks > 0) {
        let tag = eventType
        startWork(tag)
        stopWork(tag, waitAdditionalTasks)
      }
    })
  }

  function track() {
    trackOldUnpoly()
    trackFetch()
    trackHistory()
    trackXHR()
    trackRemoteElements()
    trackJQuery()
    trackSetTimeout()
    trackEvent(document, 'touchstart')
    trackEvent(document, 'mousedown')
    trackEvent(document, 'click')
    trackEvent(document, 'keydown')
    trackEvent(document, 'focusin')
    trackEvent(document, 'focusout')
    trackEvent(document, 'input')
    trackEvent(document, 'change')
    trackEvent(window, 'resize', 1)
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
    set waitTasks(value) { defaultWaitTasks = value }
  }
})()

CapybaraLockstep.track()
