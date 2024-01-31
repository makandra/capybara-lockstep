# capybara-lockstep [![Tests](https://github.com/makandra/capybara-lockstep/actions/workflows/test.yml/badge.svg)](https://github.com/makandra/capybara-lockstep/actions)

This Ruby gem synchronizes [Capybara](https://github.com/teamcapybara/capybara) commands with client-side JavaScript and AJAX requests. This greatly improves the stability of an end-to-end ("E2E") test suite, even if that suite has timing issues.

The next section explain why your test suite is flaky and how capybara-lockstep can help.\
If you don't care you may **skip to [installation instructions](#installation)**.


Why are tests flaky?
--------------------

A naively written E2E test will have [race conditions](https://makandracards.com/makandra/47336-fixing-flaky-integration-tests) between the test script and the controlled browser. How often these timing issues will fail your test depends on luck and your machine's performance. You may not see these issues for years until a colleague runs your suite on their new laptop.

Here is a typical example for a test that will fail with unlucky timing:

```ruby
scenario 'User sends a tweet' do
  visit '/'
  click_link 'New tweet' # opens form in a modal dialog
  fill_in 'text', with: 'My first tweet'
  click_button 'Send tweet'
  visit '/timeline'
  expect(page).to have_css('.tweet', text: 'My first tweet')
end
```

This test has four timing issues that may cause it to fail:

1. We click on the *New tweet* button, but the the JS event handler to open the tweet form wasn't registered yet.
2. We start filling in the form, but it wasn't loaded yet.
3. After sending the tweet we immediately navigate away, killing the form submission request that is still in flight. Hence the tweet will never appear in the next step.
4. We look for the new tweet, but the timeline wasn't loaded yet.

[Capybara will retry](https://github.com/teamcapybara/capybara#asynchronous-javascript-ajax-and-friends) individual commands or expectations when they fail.\
However, only issues **2** and **4** can be healed by retrying.

While it is [possible](https://makandracards.com/makandra/47336-fixing-flaky-integration-tests) to remove most of the timing issues above, it requires skill and discipline.\
capybara-lockstep fixes issues **1**, **2**, **3** and **4** without any changes to the test code.


### This is a JavaScript problem

The timing issues above will only manifest in an app where links, forms and buttons are handled by JavaScript.

When all you have is standard HTML links and forms, stock Capybara will not see timing issues:

- After a `visit()` Capybara/WebDriver will wait until the page is completely loaded
- When following a link Capybara/WebDriver will wait until the link destination is completely loaded
- When submitting a form Capybara/WebDriver will wait until the response is completely loaded

However, when JavaScript handles a link click, you get **zero guarantees**.\
Capybara/WebDriver **will not wait** for AJAX requests or any other async work.



How capybara-lockstep helps
---------------------------

capybara-lockstep waits until the browser is idle before moving on to the next Capybara command. This greatly relieves the pressure on [Capybara's retry logic](https://github.com/teamcapybara/capybara#asynchronous-javascript-ajax-and-friends).

capybara-lockstep synchronizes when one of the following occurs:

- Capybara looks up an element
- Capybara simulates a user interaction (clicking, typing, etc.)
- Capybara visits a new URL
- Capybara executes JavaScript

When capybara-lockstep synchronizes it will:

- wait for all document resources to load (images, CSS, fonts, frames).
- wait for client-side JavaScript to render or hydrate DOM elements.
- wait for any pending AJAX requests to finish and their callbacks to be called.
- wait for dynamically inserted `<script>`s to load (e.g. from [dynamic imports](https://webpack.js.org/guides/code-splitting/#dynamic-imports) or Analytics snippets).
- waits for dynamically inserted `<img>` or `<iframe>` elements to load.

In summary Capybara can no longer observe or interact with the page while HTTP requests are in flight.
This covers most async work that causes flaky tests.


### Limitations

Async work not synchronized by capybara-lockstep includes:

- Animations
- Websocket connections
- Media elements (`<video>`, `<audio>`)
- Service workers
- Work scheduled via `setTimeout()` or `setInterval()`.

You can configure capybara-lockstep to [wait for additional async work](#signaling-asynchronous-work).


Installation
------------

### Prerequisites

Check if your application satisfies all requirements for capybara-lockstep:

- Capybara 2.0 or higher.
- Your Capybara driver must use [selenium-webdriver](https://rubygems.org/gems/selenium-webdriver/) 3.0 or higher. capybara-lockstep deactivates itself for any other driver.
- This gem was only tested with a Selenium-controlled Chrome browser. [Chrome in headless mode](https://makandracards.com/makandra/492109-running-capybara-tests-in-headless-chrome) is recommended, but not required.
- This gem was only tested with Rails, but there's no Rails dependency.


### Installing the Ruby gem

Assuming that you're using Rails Add this line to your application's `Gemfile`:

```ruby
group :test do
  gem 'capybara-lockstep'
end
```

And then execute:

```bash
$ bundle install
```

If you're not using Rails you should also `require 'capybara-lockstep'` in your `spec_helper.rb` (RSpec), `test_helper.rb` (Minitest) or `env.rb` (Cucumber).


### Including the JavaScript snippet (required)

capybara-lockstep requires a JavaScript snippet to be embedded by the application under test. If that snippet is missing on a screen, capybara-lockstep will not be able to synchronize with the browser. In that case the test will continue without synchronization.

**If you're using Rails** you can use the `capybara_lockstep` helper to insert the snippet into your application layouts:

```erb
<%= capybara_lockstep if defined?(Capybara::Lockstep) %>
```

Ideally the snippet should be included in the `<head>` before any other `<script>` tags.

**If you're not using Rails** you can `include Capybara::Lockstep::Helper` and access the JavaScript code with `capybara_lockstep_js`.

**If you have a strict [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)** the `capybara_lockstep` Rails helper will insert a CSP nonce by default. You can also pass an explicit nonce string using the `:nonce` option.


### Including the middleware (optional)

This gem provides a Rack middleware to block Capybara while your Rails (or Rack) backend is busy.

Using the middleware is optional, as the [JavaScript snippet](#including-the-javascript-snippet-required) already for AJAX requests on the client. However, using the middleware covers some additional edge cases. For example, the middleware detects requests that were aborted on the frontend, but are still being processed by the backend.

To include the middleware in a Rails application, add the following line to `config/environments/test.rb`:

```ruby
config.middleware.insert_before 0, Capybara::Lockstep::Middleware
```

In a **non-Rails** application you should include the middleware as high up in your middleware stack as possible:

```ruby
use Capybara::Lockstep::Middleware
# Other middleware here
```

### Configuring Selenium WebDriver (recommended)

By default, webdrivers will automatically dismiss any user prompts (like alerts) when trying to perform an action.
While capybara-lockstep carefully detects alerts before synchronizing, and will skip interaction with the browser to avoid accidentally dismissing alerts, it can not synchronize around some rare race conditions.

[We recommend](https://makandracards.com/makandra/617366-how-to-configure-selenium-webdriver-to-not-automatically-close-alerts-or-other-browser-dialogs) you configure your webdriver to not automatically dismiss user prompts by setting the "unhandled prompt behavior" capability to [`ignore`](https://w3c.github.io/webdriver/#dfn-known-prompt-handling-approaches-table). Using "ignore", errors are raised like with the default behavior, but user prompts are kept open.

For example, the Chrome driver can be configured like this:
```ruby
Capybara.register_driver(:selenium) do |app|
  options = Selenium::WebDriver::Chrome::Options.new(
    unhandled_prompt_behavior: 'ignore',
    # ...
  )
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
```

### Verify successful integration

capybara-lockstep will automatically patch Capybara to wait for the browser after every command.

Run your test suite to see if integration was successful and whether stability improves. During validation we recommend to activate the [debugging log](#debugging-log) before your test:

```ruby
Capybara::Lockstep.debug = true
```

You should see messages like this in your console:

```text
[capybara-lockstep] Synchronizing
[capybara-lockstep] Finished waiting for JavaScript
[capybara-lockstep] Synchronized successfully
```

Note that you may see some failures from tests with wrong assertions, which previously passed due to lucky timing.



## Signaling asynchronous work

[By default](#how-capybara-lockstep-helps) capybara-lockstep waits until resources have loaded, AJAX requests have finished and their callbacks have been called.
There are also some [limitations](#limitations).

You can configure capybara-lockstep to wait for other async work.


### On the frontend

Let's say we have an animation that fades in a new element over 2 seconds. The following will block Capybara while the animation is running:

```js
async function fadeIn(element) {
  CapybaraLockstep?.startWork('Animation')
  startAnimation(element, 'fade-in')
  await waitForAnimationEnd(element)
  CapybaraLockstep?.stopWork('Animation')
}
```

The string argument is used for logging (when logging is enabled). It does **not** need to be unique per job. In this case you should see messages like this in your browser's JavaScript console:

```text
[capybara-lockstep] Started work: Animation [1 jobs]
[capybara-lockstep] Finished work: Animation [0 jobs]
```

You may omit the string argument, in which case nothing will be logged, but the work will still be tracked.


### On the backend

You don't need to signal work within the regular request/response cycle, as this is detected automatically. You can however signal
work that happens outside a request, e.g. in a background job or WebSocket handler.

The following will block Capybara while a [Sidekiq](https://sidekiq.org/) job is running:

```ruby
class HardJob
  include Sidekiq::Job

  def perform(name, count)
    Capybara::Lockstep.start_work('HardJob') if defined?(Capybara::Lockstep)
    # do something
  ensure
    Capybara::Lockstep.stop_work('StopWork') if defined?(Capybara::Lockstep)
  end
end
```


## Performance impact

capybara-lockstep may or may not impact the runtime of your test suite. It depends on your particular tests and how many flaky tests you're seeing in the first place.

While waiting for the browser to be idle does take a few milliseconds, Capybara no longer needs to retry failed commands. You will also save time from not needing to re-run failed tests.

In casual testing with large test suites I experienced a performance impact between +/- 10%.


## Debugging log

You can enable extensive logging. This is useful to see whether capybara-lockstep has an effect on your tests, or to debug why synchronization is taking too long.

To enable the log, say this before or during a test:

```ruby
Capybara::Lockstep.debug = true
```

You should now see messages like this on your standard output:

```
[capybara-lockstep] Synchronizing
[capybara-lockstep] Finished waiting for JavaScript
[capybara-lockstep] Synchronized successfully
```

You should also see messages like this in your browser's JavaScript console:

```
[capybara-lockstep] Started work: fetch /path [3 jobs]
[capybara-lockstep] Finished work: fetch /path [2 jobs]
```


### Using a logger

You may also configure logging to an existing logger object:

```ruby
Capybara::Lockstep.debug = Rails.logger
```

### Logging in the browser only

To enable logging in the browser console (but not STDOUT), include the [JavaScript snippet](#including-the-javascript-snippet) with `{ debug: true }`:

```ruby
capybara_lockstep(debug: true)
```

## Synchronization timeout

By default capybara-lockstep will wait `Capybara.default_max_wait_time` seconds for the page initialize and for JavaScript and AJAX request to finish.

When synchronization times out, capybara-lockstep will [log](#debugging-log):

```text
[capybara-lockstep] Could not synchronize within 3 seconds
```

You can configure a different timeout:

```ruby
Capybara::Lockstep.timeout = 5 # seconds
```

By default Capybara will **not** raise an error after a timeout. You may occasionally get a slow server response, and Capybara will retry synchronization before the next interaction or `visit`. This is often good enough.

If you want to be strict you may configure that an `Capybara::Lockstep::Timeout` error is raised after a timeout:

```ruby
Capybara::Lockstep.timeout_with = :error
```

To revert to defaults:

```ruby
Capybara::Lockstep.timeout = nil
Capybara::Lockstep.timeout_with = nil
```


## Manual synchronization

capybara-lockstep will automatically patch Capybara to wait for the browser after every command. **This should be enough for most test suites**.

For additional edge cases you may manually tell capybara-lockstep to wait. The following Ruby method will block until the browser is idle:

```ruby
Capybara::Lockstep.synchronize
```

You may also synchronize from your client-side JavaScript. The following will run the given callback once the browser is idle:

```js
CapybaraLockstep.synchronize(callback)
```


## Disabling synchronization

Sometimes you want to disable browser synchronization, e.g. to observe a loading spinner during a long-running request.

To disable automatic synchronization:

```ruby
begin
  Capybara::Lockstep.mode = :manual
  do_unsynchronized_work
ensure
  Capybara::Lockstep.mode = :auto
end
```

You can also disable automatic synchronization for the duration of a block:

```ruby
Capybara::Lockstep.with_mode(:manual) do
  do_unsynchronized_work
end
```

In the `:manual` mode you may still force synchronization by calling `Capybara::Lockstep.synchronize` manually:

```ruby
Capybara::Lockstep.with_mode(:manual) do
  do_some_work
  Capybara::Lockstep.synchronize
  do_other_work
end
```

To completely disable synchronization, even when `Capybara::Lockstep.synchronize` is called:

```ruby
Capybara::Lockstep.mode = :off
Capybara::Lockstep.synchronize # will not synchronize
```





## Handling legacy promises

Legacy promise implementations (like jQuery's `$.Deferred` and AngularJS' `$q`) work using [tasks instead of microtasks](https://jakearchibald.com/2015/tasks-microtasks-queues-and-schedules/). Their AJAX implementations (like `$.ajax()` and `$http`) use task-based promises to signal that a request is done.

This means there is a time window in which all AJAX requests have finished, but their callbacks have not yet run:

```js
$http.get('/foo').then(function() {
  // This callback runs one task after the response was received
})
```

It is theoretically possible that your test will observe the browser in that window, and expect content that has not been rendered yet. Affected code must call `then()` on a task-based promise **or** use `setTimeout()` to push work into the next task.

Any issues caused by this will usually be mitigated by Capybara's retry logic. **If** you think that this is an issue for your test suite, you can configure capybara-headless to wait additional tasks before it considers the browser to be idle:

```ruby
Capybara::Lockstep.wait_tasks = 2 # default is 1
```

If you see longer chains of `then()` or nested `setTimeout()` calls in your code, you may need to configure a higher number of tasks to wait.

Waiting additional tasks will have a negative performance impact on your test suite.



## Running code after synchronization

You can configure a proc to run after successful synchronization:

```ruby
Capybara::Lockstep.after_synchronize do
  puts "Synchronized!"
end
````


## Contributing

Pull requests are welcome on GitHub at <https://github.com/makandra/capybara-lockstep>.

After checking out the repo, run `bin/setup` to install dependencies.

Then, run `rake spec` to run the tests.

You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Manually testing a change

To test an unrelased change with a test suite, we recommend to temporarily link the local repository from your test suites's `Gemfile`:

```ruby
gem 'capybara-lockstep', path: '../capybara-lockstep'
```

As an alternative you may also install this gem onto your local machine by running `bundle exec rake install`.

### Releasing a new version

- Update the version number in `version.rb`
 - Run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).
 - If RubyGems publishing seems to freeze, try entering your OTP code.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


## Credits

Henning Koch ([@triskweline](https://twitter.com/triskweline)) from [makandra](https://makandra.com).
