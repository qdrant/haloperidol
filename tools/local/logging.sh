#!/bin/bash

# logfmt style logging for bash
log() {
  level=$1
  message=$2
  ts=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

  # Validate log level
  if [[ ! "$level" =~ ^(trace|debug|info|warn|error|fatal)$ ]]; then
    echo "ts=$ts level=error msg=\"Invalid log level: $level\""
    return 1
  fi

  output="ts=$ts level=$level msg=\"$message\""

  shift 2  # Skip log level and message

  # Check if the remaining arguments are even (key-value pairs)
  if (( $# % 2 != 0 )); then
    echo "ts=$ts level=error msg=\"Each key should have a value\""
    return 1
  fi

  while [[ $# -gt 0 ]]; do
    key=$1
    value=$2
    output="$output $key=\"$value\""
    shift 2
  done

  echo "$output"
}

# Test cases to run if script if run directly:
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  uri="http://example.com"
  root_api_response="404 Not Found"
  log info "message" uri "$uri" uri_response "$root_api_response" foo "bar baz"
  log warn "message" uri "$uri" uri_response "$root_api_response" foo
  log debug "debug message" key1 "value1" key2 "value2"
  log fatal "fatal message"
  log invalid "invalid message"
fi
