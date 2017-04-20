# Rubygem for 3scale Web Service Management API


[<img src="https://secure.travis-ci.org/3scale/3scale_ws_api_for_ruby.png?branch=master" alt="Build Status" />](http://travis-ci.org/3scale/3scale_ws_api_for_ruby)

3scale is an API Infrastructure service which handles API Keys, Rate Limiting, Analytics, Billing Payments and Developer Management. Includes a configurable API dashboard and developer portal CMS. More product stuff at http://www.3scale.net/, support information at http://support.3scale.net/.

### Tutorials
* Plugin Setup: https://support.3scale.net/docs/deployment-options/plugin-setup
* Rate Limiting: https://support.3scale.net/docs/access-control/rate-limits
* Analytics Setup: https://support.3scale.net/quickstarts/3scale-api-analytics

## Installation

This library is distributed as a gem, for which Ruby 2.1 or JRuby 9.1.1.0 are
minimum requirements:
```sh
gem install 3scale_client
```
Or alternatively, download the source code from github:
http://github.com/3scale/3scale_ws_api_for_ruby

If you are using Bundler, please add this to your Gemfile:

```ruby
gem '3scale_client'
```
and do a bundle install.

If you are using Rails' config.gems, put this into your config/environment.rb

```ruby
config.gem '3scale_client'
```
Otherwise, require the gem in whatever way is natural to your framework of choice.

## Usage

First, create an instance of the client:

```ruby
client = ThreeScale::Client.new(service_tokens: true)
```

> NOTE: unless you specify `service_tokens: true` you will be expected to specify
a `provider_key` parameter, which is deprecated in favor of Service Tokens:
```ruby
client = ThreeScale::Client.new(provider_key: 'your_provider_key')
```
This will comunicate with the 3scale platform SaaS default server. 

If you want to create a client with a given host and port when connecting to an on-premise instance of the 3scale platform, you can specify them when creating the instance: 
```ruby
client = ThreeScale::Client.new(service_tokens: true, host: 'service_management_api.example.com', port: 80)
```

or if you used a provider key:

```ruby
client = ThreeScale::Client.new(provider_key: 'your_provider_key', host: 'service_management_api.example.com', port: 80)
```

Because the object is stateless, you can create just one and store it globally.

Then you can perform calls in the client:

```ruby
client.authorize(service_token: 'token', service_id: '123', usage: usage)
client.report(service_token: 'token', service_id: '123', usage: usage)
```

If you had configured a (deprecated) provider key, you would instead use:

```ruby
client.authrep(service_id: '123', usage: usage)
```

> NOTE: `service_id` is mandatory since November 2016, both when using service
tokens and when using provider keys

> NOTE: You might use the option `warn_deprecated: false` to avoid deprecation
warnings. This is enabled by default.

### SSL and Persistence

Starting with version 2.4.0 you can use two more options: `secure` and `persistent` like:

```ruby
client = ThreeScale::Client.new(provider_key: '...', secure: true, persistent: true)
```

#### `secure`

Enabling secure will force all traffic going through HTTPS.
Because estabilishing SSL/TLS for every call is expensive, there is `persistent`.

#### `persistent`

Enabling persistent will use HTTP Keep-Alive to keep open connection to our servers.
This option requires installing gem `net-http-persistent`.

### Authrep

Authrep is a 'one-shot' operation to authorize an application and report the associated transaction at the same time.
The main difference between this call and the regular authorize call is that usage will be reported if the authorization is successful. Read more about authrep at the [active docs page on the 3scale's support site](https://support.3scale.net/reference/activedocs#operation/66)

You can make request to this backend operation using `service_token` and `service_id`, and an authentication pattern like `user_key`, or `app_id` with an optional key, like this:

```ruby
response = client.authrep(service_token: 'token', service_id: 'service_id', app_id: 'app_id', app_key: 'app_key')
```

Then call the `success?` method on the returned object to see if the authorization was successful.

```ruby
if response.success?
  # All fine, the usage will be reported automatically. Proceeed.
else
  # Something's wrong with this application.
end
```

The example is using the `app_id` authentication pattern, but you can also use other patterns such as `user_key`.

#### A rails example


```ruby
class ApplicationController < ActionController
  # Call the authenticate method on each request to the API
  before_filter :authenticate

  # You only need to instantiate a new Client once and store it as a global variable
  # If you used a provider key it is advisable to fetch it from the environment, as
  # it is secret.
  def create_client
    @@threescale_client ||= ThreeScale::Client.new(service_tokens: true)
  end

  # To record usage, create a new metric in your application plan. You will use the
  # "system name" that you specifed on the metric/method to pass in as the key to the usage hash.
  # The key needs to be a symbol.
  # A way to pass the metric is to add a parameter that will pass the name of the metric/method along
  #
  # Note that you don't always want to retrieve the service token and service id from
  # the parameters - this will depend on your application.
  def authenticate
    response = create_client.authrep(service_token: params['service_token']
                                     service_id: params['service_id'],
                                     app_id: params['app_id'],
                                     app_key: params['app_key'],
                                     usage: { params['metric'].to_sym => 1 })
    if response.success?
      return true
      # All fine, the usage will be reported automatically. Proceeed.
    else
      # Something's wrong with this application.
      puts "#{response.error_message}"
      # raise error
    end
  end
end
```

### Authorize

To authorize an application, call the `authorize` method passing it the `service_token` and `service_id`, as well as a supported pattern for application authentication:

```ruby
response = client.authorize(service_token: 'token', service_id: 'service_id', user_key: 'user_key')
```

Then call the `success?` method on the returned object to see if the authorization was successful.

```ruby
if response.success?
  # All fine, the usage will be reported automatically. Proceeed.
else
  # Something's wrong with this application.
end
```

If the service (provided with the token and its id, or otherwise the id if the provider key was specified at instantiation time) and the application are valid, the response object contains additional information about the application's status:

```ruby
# Returns the name of the plan the application is signed up to.
response.plan
```

If the plan has defined usage limits, the response contains details about the usage broken down by the metrics and usage limit periods.

```ruby
# The usage_reports array contains one element per each usage limit defined on the plan.
usage_report = response.usage_reports[0]

# The metric
usage_report.metric # "hits"

# The period the limit applies to
usage_report.period        # :day
usage_report.period_start  # "Wed Apr 28 00:00:00 +0200 2010"
usage_report.period_end    # "Wed Apr 28 23:59:59 +0200 2010"

# The current value the application already consumed in the period
usage_report.current_value # 8032

# The maximal value allowed by the limit in the period
usage_report.max_value     # 10000

# If the limit is exceeded, this will be true, otherwise false:
usage_report.exceeded?     # false
```

If the authorization failed, the `error_code` returns system error code and `error_message` human readable error description:

```ruby
response.error_code    # "usage_limits_exceeded"
response.error_message # "Usage limits are exceeded"
```

### OAuth Authorize

To authorize an application with OAuth, call the `oauth_authorize` method passing it the `service_token` with `service_id` and the `app_id`.

```ruby
response = client.oauth_authorize(service_token: 'token', service_id: 'service_id', app_id: 'app_id')
```

If the authorization is successful, the response will contain the `app_key` and `redirect_url` defined for this application:

```ruby
response.app_key
response.redirect_url
```

### Report

To report usage, use the `report` method. You can report multiple transactions at the same time:

```ruby
response = client.report(
  service_token: 'token',
  service_id: 'service_id',
  transactions: [{app_id: '1st app_id', usage: { 'hits' => 1 }},
                 {app_id: '2nd app_id', usage: { 'hits' => 1 }}])
```

The `app_id` and `usage` parameters are required. Additionally, you can specify a timestamp of a transaction:

```ruby
response = client.report(
  :transactions => [{app_id: 'app_id',
                     usage: { 'hits' => 1 },
                     timestamp: Time.local(2010, 4, 28, 12, 36)}])
```

The timestamp can be either a `Time` object (from ruby's standard library) or something that _quacks_ like it (for example, the `ActiveSupport::TimeWithZone` from Rails) or a string. Such string has to be in a format parseable by the `Time.parse` method. For example:

```ruby
"2010-04-28 12:38:33 +0200"
```

If the timestamp is not in UTC, you have to specify a time offset. That's the "+0200" (two hours ahead of the Universal Coordinate Time) in the example abowe.

Then call the `success?` method on the returned response object to see if the report was successful.

```ruby
  if response.success?
    # All OK.
  else
    # There was an error.
  end
```

In case of error, the `error_code` returns system error code and `error_message` human readable error description:

```ruby
response.error_code    # "provider_key_invalid"
response.error_message # "provider key \"foo\" is invalid"
```

## Rack Middleware

You can use our Rack middleware to automatically authenticate your Rack applications.

> NOTE: this is deprecated. Please observe that there is no support for multiple
services nor for service tokens.

```ruby
require '3scale/middleware'
use ThreeScale::Middleware, provider_key, :user_key # or :app_id
```
