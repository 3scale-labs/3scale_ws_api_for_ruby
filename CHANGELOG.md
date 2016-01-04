# Change Log
All notable changes to this project will be documented in this file.

## [Unreleased][unreleased]
### Fixed
- Fixed double escaping of post parameters (https://github.com/3scale/3scale_ws_api_for_ruby/pull/24)
### Added

## [2.6.0] - 2015-12-28

### Added
- Include 'log' field in transactions reported with 'report' method

## [2.5.0] - 2015-12-14
No changes. Stable release.

## [2.5.0.pre1] - 2015-01-29
### Added
- Native support for persistent connections (without net-http-persistent gem)
- `ThreeScale::Middleware` for Rack