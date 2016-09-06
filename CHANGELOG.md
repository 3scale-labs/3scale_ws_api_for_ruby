# Change Log
All notable changes to this project will be documented in this file.

## [Unreleased]
### Added
- Added support for reporting to services other than the default one.
  `ThreeScale::Client#report` now accepts an optional `service_id`.
  There has been a change in the params that the method accepts. This
  change is backwards compatible but a deprecation warning is shown
  when calling the method using the old params.

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
