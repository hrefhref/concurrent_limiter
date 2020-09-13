# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.1.1] 2020-09-13

### Added

- Telemetry events.

### Fixed

- Decrement counter when max retries has been reached.
- Ensure counter is always decremented in case of process being killed (by using "sentinel" processes that monitors).
- Fixes behaviour of `max_waiting = 0` with `max_size = 1`.

## [0.1.0] - 2020-05-16

Initial release.
