# capybara-lockstep

This Ruby gem synchronizes [Capybara](https://github.com/teamcapybara/capybara) commands with client-side JavaScript and AJAX requests. This greatly improves the stability of a full-stack integration test suite, even if that suite has timing issues.


Why are tests flaky?
--------------------

A naively written integration test will have [race conditions](https://makandracards.com/makandra/47336-fixing-flaky-integration-tests) between the test script and the controlled browser. How often these timing issues will fail your test depends on luck and your machine's performance. You may not see these issues for years until a colleague runs your suite on their new laptop.

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

1. We click on the "New tweet" button, but the the JS event handler to open the tweet form wasn't registered yet.
2. We start filling in the form, but it wasn't loaded yet.
3. After sending the tweet we immediately navigate away, killing the form submission request that is still in flight. Hence the tweet will never appear in the next step.
4. We look for the new tweet, but the timeline wasn't loaded yet.

Capybara will retry individual commands or expectations when they fail. However, only issues **2** and **4** can be healed by retrying.

While it is [possible](https://makandracards.com/makandra/47336-fixing-flaky-integration-tests) to remove most of the timing issues above, it requires skill and discipline. capybara-lockstep fixes issues **1**, **2**, **3** and **4** without any changes to the test code.


How capybara-lockstep helps
---------------------------

capybara-lockstep waits until the browser is idle before moving on to the next Capybara command. This greatly relieves the pressure on Capybara's retry logic.

Whenever Capybara visits a new URL:

- capybara-lockstep waits for all document resources to load.
- capybara-lockstep waits for client-side JavaScript to render or hydrate DOM elements.
- capybara-lockstep waits for any AJAX requests.
- capybara-lockstep waits for dynamically inserted `<script>`s to load (e.g. from [dynamic imports](https://webpack.js.org/guides/code-splitting/#dynamic-imports) or Analytics snippets).

Whenever Capybara simulates a user interaction (clicking, typing, etc.):

- capybara-lockstep waits for any AJAX requests.
- capybara-lockstep waits for dynamically inserted `<script>`s to load (e.g. from [dynamic imports](https://webpack.js.org/guides/code-splitting/#dynamic-imports) or Analytics snippets).


Installation
------------

### Prerequisites

Check if your application satisfies all requirements for capybara-lockstep:

- Capybara 2 or higher.
- Your Capybara driver must use [selenium-webdriver](https://rubygems.org/gems/selenium-webdriver/). capybara-headless deactivates itself for any other driver.
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

If you're not using Rails you should also `require 'capybara-lockstep'` in your `spec_helper.rb` (RSpec) or `env.rb` (Cucumber).


### Including the JavaScript snippet

capybara-lockstep requires a JavaScript snippet to be embedded by the application under test. If that snippet is missing on a screen, capybara-lockstep will not be able to synchronize with the browser. In that case the test will continue without synchronization.

If you're using Rails you can use the `capybara_lockstep` helper to insert the snippet into your application layouts:

```erb
<%= capybara_lockstep if Rails.env.test? %>
```

Ideally the snippet should be included in the `<head>` before any other `<script>` tags. If that's impractical you will also see some benefit if you insert it later.

If you have a strict [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP), the `capybara_lockstep` helper will insert a CSP nonce by default. You can also pass a `:nonce` option.

If you're not using Rails you can `include Capybara::Lockstep::Helper` and access the JavaScript with `capybara_lockstep_script`.


### Signaling the end of page initialization

Most web applications run some JavaScript after the document was loaded. This JavaScript enhances existing DOM elements ("hydration") or renders additional element into the DOM.

capybara-lockstep needs to know when your JavaScript is done hydrating and rendering, so it can automatically wait for initialization after every Capybara `visit()`.

To signal that JavaScript is still initializing, your application layouts should render the `<body>` element with an `[data-initializing]` attribute:

```html
<body data-initializing>
```

Your application JavaScript should remove the `[data-initializing]` attribute when it is done hydrating and rendering.

More precisely, the attribute should be removed in the same [JavaScript task](https://jakearchibald.com/2015/tasks-microtasks-queues-and-schedules/) ("tick") that will finish initializing. capybara-lockstep will assume that the page will be initialized by the end of this task.

If all your initializing JavaScript runs synchronously on `DOMContentLoaded`, you can remove `[data-initializing]` in an event handler:

```js
document.addEventListener('DOMContentLoaded', function() {
  // Initialize the page here
  document.body.removeAttribute('data-initializing')
})
```

If you do any asynchronous initialization work (like lazy-loading another script) you should only remove `[data-initializing]` once that is done:

```js
document.addEventListener('DOMContentLoaded', function() {
  import('huge-library').then(function({ hugeLibrary }) {
    hugeLibrary.initialize()
    document.body.removeAttribute('data-initializing')
  })
})
```

If you call libraries during initialization, you may need to check the library code to see whether it finishes synchronously or asynchronously. E.g. if you discover that a library delays work for a task, you must also wait another task to remove `[data-initializing]`:

```js
document.addEventListener('DOMContentLoaded', function() {
  Libary.doWorkInNextTask()
  setTimeout(function() { document.body.removeAttribute('data-initializing') })
})
```

When you're using [Unpoly](https://unpoly.com/) initializing will usually happen synchronously in [compilers](https://unpoly.com/up.compiler). Hence a compiler is a good place to remove `[data-initializing]`:

```js
up.compiler('body', function(body) {
  body.removeAttribute('data-initializing')
})
```

When you're using [AngularJS 1](https://unpoly.com/) initializing will usually happen synchronously in [directives](https://docs.angularjs.org/guide/directive). Hence a directive is a good place to remove `[data-initializing]`:

```js
app.directive('body', function() {
  return {
    restrict: 'E',
    link: function() {
      document.body.removeAttribute('data-initializing')
    }
  }
})
```

### Verify successful integration

capybara-lockstep will automatically patch Capybara to wait for the browser after every command.

Run your test suite to see if integration was successful and whether stability improves.

When you run into issues or don't see an effect, try activating `Capybara::Lockstep.debug = true` in your `spec_helper.rb` (RSpec) or `env.rb` (Cucumber).

Note that you may see some failures from tests with wrong assertions, which sometimes passed due to lucky timing.


## Performance impact

capybara-lockstep may or may not impact the runtime of your test suite. It depends on your particular tests and how many flaky tests you're seeing in the first place.

While waiting for the browser to be idle does take a few milliseconds, Capybara no longer needs to retry failed commands. You will also save time from not needing to re-run failed tests.

In casual testing I experienced a negative performance impact between 0% and 10%.


## Debugging log

capybara-lockstep can print to the console whenever it waits for the browser. To enable the log:

```ruby
Capybara::Lockstep.debug = true
```

You should now see messages like this during your test runs:

```
[Capybara::Lockstep] JavaScript or AJAX requests are running
```

You may also configure logging to an existing logger object:

```ruby
Capybara::Lockstep.debug = Rails.logger
```


## Disabling synchronization

If for some reason you want to disable browser synchronization for a while, you can do it like this:

```ruby
begin
  Capybara::Lockstep.enabled = false
  do_unsynchronized_work
ensure
  Capybara::Lockstep.enabled = true
end
```


## Timeout

By default capybara-lockstep will wait up to 10 seconds for the page initialize and for JavaScript and AJAX request to finish.

You can configure a different timeout:

```ruby
Capybara::Lockstep.timeout = 5 # seconds
```




## JavaScript API

capybara-lockstep already hooks into [many JavaScript APIs](#how-capybara-lockstep-helps) like `XMLHttpRequest` or `fetch()` to mark the browser as "busy" until their work finishes. **This should be enough for most test suites**.

For additional edge cases you may interact with capybara-lockstep from your own JavaScripts.

Note that when you only load the JavaScript snippet in tests you need check before calling any API functions:

```js
if (window.CapybaraLockstep) {
  CapybaraLockstep.startWork()
}
```

### Signaling asynchronous work

If for some reason you want capybara-lockstep to consider additional asynchronous work as "busy", you can do so:

```js
CapybaraLockstep.startWork()
doAsynchronousWork().then(function() {
  CapybaraLockstep.stopWork()
})
```

### Checking if the browser is busy

You can query capybara-lockstep whether it considers the browser to be busy or idle:

```js
CapybaraLockstep.isBusy() // => false
CapybaraLockstep.isIdle() // => true
```

### Waiting until the browser is idle

```js
CapybaraLockstep.awaitIdle(callback)
```

## Ruby API

capybara-lockstep will automatically patch Capybara to wait for the browser after every command. **This should be enough for most test suites**.

For additional edge cases you may interact with capybara-lockstep from your Ruby code.


### Waiting until the browser is idle

This will block until the document was loaded and the DOM has been hydrated:

```ruby
Capybara::Lockstep.await_initialized
```

This will block while the browser is busy with JavaScript and AJAX requests:

```ruby
Capybara::Lockstep.await_idle
```

### Checking if the browser is busy

You can query capybara-lockstep whether it considers the browser to be busy or idle:

```ruby
Capybara::Lockstep.idle? # => true
Capybara::Lockstep.busy? # => false
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Pull requests are welcome on GitHub at <https://github.com/makandra/capistrano-lockstep>.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

Henning Koch ([@triskweline](https://twitter.com/triskweline)) from [makandra](https://makandra.com).
