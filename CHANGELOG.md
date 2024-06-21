All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).


# Unreleased

- We now only wait for `<script>` elements with a JavaScript type
- We only wait for `<iframe>` elements with a `[src]` attribute


# 2.2.1

- Fixed a bug that disabled most functionality for drivers with `browser: :remote`.


# 2.2.0

- We now wait for `<video>` and `<audio>` elements to load their metadata. This addresses a race condition where a media element is inserted into the DOM, but another user action deletes or renames the source before the browser could load the initial metadata frames. 
- We now wait for `<script type="module">`.
- We no longer wait for `<img loading="lazy">` or `<iframe loading="lazy">`. This prevents a deadlock where we would wait forever for an element that defers loading until it is scrolled into the viewport.


# 2.1.0

- We now synchronize for an additional [JavaScript task](https://jakearchibald.com/2015/tasks-microtasks-queues-and-schedules/) after `history.pushState()`, `history.replaceState()`, `history.forward()`, `history.back()` and `history.go()`.
- We now synchronize for an additional JavaScript task after `popstate` and `hashchange` events.
- We now synchronize for an additional JavaScript task when the window is resized.
- You can now disable automatic synchronization for the duration of a block: `Capybara::Lockstep.with_mode(:manual) { ... }`.


# 2.0.3

- Fix a bug where we wouldn't wait for an additional [JavaScript task](https://jakearchibald.com/2015/tasks-microtasks-queues-and-schedules/) after a tracked event or async job.
- Fix a bug where the `Capybara::Lockstep.wait_tasks` configuration would be ignored.
- Fix a bug where the `capybara_lockstep_js` helper (for use without Rails) would not include the current configuration. 


# 2.0.2

- Fix a bug where setting a logger object with `Capybara::Lockstep.debug = logger` would crash (by @dorianmarie).


# 2.0.1

- Don't crash when an interaction closes the window (tab).


# 2.0.0

This major release detects many additional sources of flaky tests: 
 
- We now synchronize before a user interaction. Previously we only synchronized before an observation. This could lead to race conditions when a test chained multiple interactions without [making an observation in between](https://makandracards.com/makandra/47336-fixing-flaky-e2e-tests#section-interleave-actions-and-expectations).
- We now synchronize after a user interaction (e.g. after a click). Previously we only synchronized before an observation. This could lead to race conditions when a test made assertions without going through Capybara, e.g. by accessing the database or global state variables.
- When a job ends (e.g. an AJAX request finishes) we now wait for one [JavaScript task](https://jakearchibald.com/2015/tasks-microtasks-queues-and-schedules/). This gives event listeners more time to schedule new async work.
- We now wait one JavaScript task after `touchstart`, `mousedown`, `click` and `keydown` events. This gives event listeners more time to schedule async work after a user interaction.
- You can now [wait while the backend server is busy](https://github.com/makandra/capybara-lockstep/#including-the-middleware-optional), by using `Capybara::Lockstep::Middleware` in your Rails or Rack app. We previously only waited for AJAX requests on the client, but using the middleware addresses some additional edge cases. For example, the middleware detects requests that were aborted on the frontend, but are still being processed by the backend.
- You can [signal async work from the backend](https://github.com/makandra/capybara-lockstep/#on-the-backend), e.g. for background jobs. Note that you don't need to signal work for the regular request/response cycle, as this is detected automatically.

Although we now cover a lot more edge cases, this releases will not slow down your test suite considerably.


## 1.3.1 - 2023-10-25

Now synchronizes before and after `evaluate_script`.

Previously we only synchronized around `execute_script` and `evaluate_async_script`.


## 1.3.0 - 2023-01-10

You can configure a proc to run after successful synchronization:

```ruby
Capybara::Lockstep.after_synchronize do
  puts "Synchronized!"
end
````

## 1.2.1 - 2022-09-12

- Synchronize with pages constructed from non-empty [data URLs](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/Data_URLs)

## 1.2.0 - 2022-09-12

### Synchronization around history navigation

We now synchronize before and after history navigation using the following Capybara methods:

- `page.refresh`
- `page.go_back`
- `page.go_forward`

We also synchronize before `current_url` in case running a JavaScript task wants to update the URL when done.

### Support for tests with multiple tabs or frames

capybara-lockstep now supports test that work with [multiple frames](https://makandracards.com/makandra/34015-use-capybara-commands-inside-an-iframe) or [multiple tabs or windows](https://github.com/teamcapybara/capybara#working-with-windows).
We now synchronize before and after the following Capybara methods:

- `switch_to_frame`
- `within_frame`
- `switch_to_window`
- `within_window`

### Improved logging

- Only log when we're actually synchronizing
- Log the reason why we're synchronizing (e.g. before node access)
- Log which browser work we're waiting for (e.g. XHR request, image load)

### Various changes

- Synchronize before accessing `page.html`.


## 1.1.1 - 2022-03-16

- Activate rubygems MFA

## 1.1.0

- Stop handling of `[data-initializing]` attribute. Apps that have late initialization after the `load` event can just use `CapybaraLockstep.startWork()`.
- Remove useless tracking of interaction events like `"click"` or `"focus"`. If such an event handler would start an AJAX request, it is already tracked.
- On apps with Unpoly 0.x, wait for one more task after `DOMContentLoaded`. Please upgrade to Unpoly 1.x or 2.x, as this logic will be removed in a year or so.

## 1.0.0

- First stable release.
- Replace option `Capybara::Lockstep.config` (`true`, `false`) with a more refined option `.mode` (`:auto`, `:manual`, `:off`)

## 0.7.0

- Ruby 3 compatibility.
- Fix logging.

## 0.6.0

- Synchronize around `evaluate_script` and `execute_script`.
- Improve logging.

## 0.5.0

- Allow developer to signal custom async work.
- Option to wait additional tasks, to handle legacy promise implementations.
- Debugging log can be enabled during a running test.
- Also wait for images and iframes.

## 0.4.0

- Don't fail the test when synchronization times out.
- Capybara::Lockstep.debug = true will now also enable client-side logging on the browser's JavaScript console.
- Always wait at least for `Capybara.default_max_wait_time`.

## 0.3.2

- Delay synchronization when an alert is open (instead of failing)


## 0.3.1

- Fix typo in log message

## 0.3.0

- Rework entire waiting logic to be lazy.
- There is now a single method `Capybara::Lockstep.synchronize` (no distinction between awaiting "initialization" and "idle").

## 0.2.3

- When we cannot wait for browser idle due to an open alert, wait before the next Capybara synchronize

## 0.2.2

- Fix incorrect data in gemspec.


## 0.2.1

- Internal changes.


## 0.2.0

- Initial release.
