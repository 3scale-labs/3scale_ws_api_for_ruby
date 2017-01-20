# Change Log
All notable changes to this project will be documented in this file.

## [2.11.0] - 2017-01-20
### Added
- Added support for (Service Tokens)[https://support.3scale.net/docs/accounts/tokens]
  Just instantiate the client with `ThreeScale::Client.new(service_tokens: true)`
  and specify in each call the `service_token` and `service_id` parameters.
- Deprecated usage of `provider_key` when instantiating the client.
- Deprecated usage of the provided Rack Auth middleware. You should write your own.
- Added optional parameter `warn_deprecated` defaulting to `true` to be able to
  opt out of deprecation warnings. It is encouraged to not turn this off unless
  you are sure you understand all deprecation warnings you get, and even so good
  practice suggests you should turn it back on each time you upgrade this client
  to check for new warnings.

## [2.10.0] - 2016-11-25
### Added
- Added support for 3scale extensions (experimental or non-standard
  features that are not part of the official API). You just need to
  add the `:extensions` symbol and the value to the hash of options that
  the client methods accept. The value is itself a hash containing the
  parameter names as keys and the parameter values as values.

## [2.9.0] - 2016-10-21
This version drops support for Ruby versions < 2.1 and JRuby < 9.1.1.0.

### Added
- Added method `ThreeScale::Client::AuthorizeResponse#limits_exceeded?`
  to check whether an authorization is denied and is so because at least
  one metric went over the limits.

## [2.8.2] - 2016-10-18
### Added
- Added support for retrieving metric hierarchies in authorize calls.
  This is an experimental feature and its support is not guaranteed for
  future releases.

## [2.8.1] - 2016-10-11
### Changed
- Improved parsing performance of the response of the authorize call.

## [2.8.0] - 2016-09-06
This version drops support for Ruby versions < 2.0.

### Added
- Added support for reporting to services other than the default one.
  `ThreeScale::Client#report` now accepts an optional `service_id`.
  There has been a change in the params that the method accepts. This
  change is backwards compatible but a deprecation warning is shown
  when calling the method using the old params.
- The two authorize calls `ThreeScale::Client#Authorize` and
  `ThreeScale::Client#oauth_authorize` now accept an optional predicted
  usage parameter.
- It is now possible to specify a port different that the default
  one for the API service management endpoint.

## [2.7.0] - 2016-08-26
### Added
- Added support for 'user_key' authentication mode in 'report' method

## [2.6.1] - 2016-01-04
### Fixed
- Fixed double escaping of post parameters (https://github.com/3scale/3scale_ws_api_for_ruby/pull/24)

## [2.6.0] - 2015-12-28

### Added
- Include 'log' field in transactions reported with 'report' method

## [2.5.0] - 2015-12-14
No changes. Stable release.

## [2.5.0.pre1] - 2015-01-29
### Added
- Native support for persistent connections (without net-http-persistent gem)
- `ThreeScale::Middleware` for Rack
