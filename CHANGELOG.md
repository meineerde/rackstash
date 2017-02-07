# Changelog

All notable changes to Rackstash will be documented in this file. This
project adheres to [Semantic Versioning](http://semver.org/).

## HEAD

This is a complete rewrite of Rackstash. The basic ideas are retained but the design, the technical implementation, and some of the interfaces are new.

We will attempt to provide a migration path from Rackstash 0.0.1 to 0.2 without too much pain.

### Changes

* Dropped support for Ruby < 2.1.0
* Dropped support for Rails. See [rackstash-rails](https://github.com/meineerde/rackstash-rails) for the companion gem.

* {Rackstash::Logger#<<} now emits a JSON document similar to all other logger methods. I will however add the eaw unformatted message to the `"message"` field.
* Exception backtraces are not emitted in the `error_trace` field instead of `error_backtrace`. That way, the field is shown below the error and error message in Kibana which makes a much nicer experience.

## [0.0.1]

* The first version of the Rackstash gem
