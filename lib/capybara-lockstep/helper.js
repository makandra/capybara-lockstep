window.CapybaraLockstep = (function() {
  let count = 0
  let idleCallbacks = []
  let debug = false

  function isIdle() {
    // Can't check for document.readyState or body.initializing here,
    // since the user might navigate away from the page before it finishes
    // initializing.
    return count === 0
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
    count++
    if (tag) {
      logNegative('Started work: %s [%d jobs]', tag, count)
    }
  }

  function startWorkUntil(promise, tag) {
    startWork(tag)
    promise.then(stopWork, stopWork)
  }

  function startWorkForMicrotask(tag) {
    startWork(tag)
    Promise.resolve().then(stopWork.bind(this, tag))
  }

  function stopWork(tag) {
    count--

    if (tag) {
      logPositive('Finished work: %s [%d jobs]', tag, count)
    }

    if (isIdle()) {
      idleCallbacks.forEach(function(callback) {
        callback('Finished waiting for JavaScript')
      })
      idleCallbacks = []
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

  function trackInteraction() {
    // We already override all interaction methods in the Selenium browser nodes, so they
    // wait for an idle frame afterwards. However a test script might also dispatch synthetic
    // events with executate_script() to manipulate the browser in ways that are not possible
    // with the Capybara API. When we observe such an event we wait until the end of the microtask,
    // assuming any busy action will be queued by then.
    ['click',  'mousedown', 'keydown', 'change', 'input', 'submit', 'focusin', 'focusout', 'scroll'].forEach(function(eventType) {
      // Use { useCapture: true } so we get the event before another listener
      // can prevent it from bubbling up to the document.
      document.addEventListener(eventType, onInteraction, { capture: true, passive: true })
    })
  }

  function onInteraction(event) {
    // We wait until the end of this microtask, assuming that any callback that
    // would queue an AJAX request or load additional scripts will run by then.
    startWorkForMicrotask()
  }

  function trackDynamicScripts() {
    if (!window.MutationObserver) {
      return
    }

    // Dynamic imports or analytics snippets may insert a <script src>
    // tag that loads and executes additional JavaScript. We want to be isBusy()
    // until such scripts have loaded or errored.
    let observer = new MutationObserver(onAnyElementChanged)
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
    // Until we have a body on which we can observe [data-initializing]
    // we consider ourselves busy.
    startWork()
    whenReady(function() {
      stopWork()
      if (document.body.hasAttribute(INITIALIZING_ATTRIBUTE)) {
        startWork('Page initialization')
        let observer = new MutationObserver(onInitializingAttributeChanged)
        observer.observe(document.body, { attributes: true, attributeFilter: [INITIALIZING_ATTRIBUTE] })
      }
    })
  }

  function onInitializingAttributeChanged() {
    if (!document.body.hasAttribute(INITIALIZING_ATTRIBUTE)) {
      stopWork('Page initialization')
    }
  }

  function isRemoteScript(node) {
    if (node.nodeType === Node.ELEMENT_NODE && node.tagName === 'SCRIPT') {
      let src = node.getAttribute('src')
      let type = node.getAttribute('type')

      return (src && (!type || /javascript/i.test(type)))
    }
  }

  function onRemoteScriptAdded(script) {
    let workTag = 'Remote script ' + script.getAttribute('src')
    startWork(workTag)
    let taggedStopWork = stopWork.bind(this, workTag)
    // Chrome runs a remote <script> *before* the load event fires.
    script.addEventListener('load', taggedStopWork)
    script.addEventListener('error', taggedStopWork)
  }

  function onAnyElementChanged(changes) {
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
    if (document.readyState !== 'loading') {
      callback()
    } else {
      document.addEventListener('DOMContentLoaded', callback)
    }
  }

  function track() {
    trackFetch()
    trackXHR()
    trackInteraction()
    trackDynamicScripts()
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
    startWork: startWork,
    stopWork: stopWork,
    synchronize: synchronize,
    isIdle: isIdle,
    isBusy: isBusy,
    set debug(newDebug) {
      debug = newDebug
    }
  }
})()

CapybaraLockstep.track()
