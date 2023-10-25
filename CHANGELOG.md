All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

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
