#!/bin/bash
# set -x

# logfmt style logging for bash
log() {
  local level=$1
  shift

  local message=""
  # -p /dev/stdin: Read input from stdin if it's a pipe
  # -z $STY: Temporary hack. I couldn't figure out how make it take stdin only when piped in non interactive terminal.
  if [ -p /dev/stdin ]&& [ -z "$STY" ]; then
    while IFS= read -r line; do
      message+="$line"$'\n'
    done
    message=${message%$'\n'} # Remove trailing newline
  else
    message="$1"
    shift
  fi

  local ts
  ts=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

  # Validate log level
  if [[ ! "$level" =~ ^(trace|debug|info|warn|error|fatal)$ ]]; then
    echo "ts=$ts level=error msg=\"Invalid log level: $level\""
    return 1
  fi

  # Ensure remaining arguments are key-value pairs
  if (( $# % 2 != 0 )); then
    echo "ts=$ts level=error msg=\"Each key should have a value\"" fields="\"$*\""
    return 1
  fi

  # Store key-value pairs for later use
  local kv_pairs=""
  while [[ $# -gt 0 ]]; do
    local key=$1
    local value=$2
    if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      kv_pairs="$kv_pairs $key=$value"
    elif [[ "$value" =~ ^[a-zA-Z0-9_]+$ ]]; then
      kv_pairs="$kv_pairs $key=$value"
    else
      kv_pairs="$kv_pairs $key=\"$value\""
    fi
    shift 2
  done

  # Print each line separately with the same log level
  while IFS= read -r line; do
    # Reduce multiple spaces to exactly two spaces
    line=$(echo -n "$line" | sed 's/  \+/  /g')
    echo "ts=$ts level=$level msg=\"$line\"$kv_pairs"
  done <<< "$message"
}

# Run a command and only log output if it fails
log_error() {
  local cmd_output
  local exit_code

  # Capture both stdout and stderr into a variable, while preserving exit code
  cmd_output=$(eval "$*" 2>&1)
  exit_code=$?

  if (( exit_code != 0 )); then
    log error "$cmd_output" command "$*" exit_code "$exit_code"
  fi

  return $exit_code
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

  echo "passed from stdin" | log info key1 value1 key2 value2
  kubectl get pods | log info title "hello world"

  log_error 'ls /nonexistent1 /nonexistent2 /nonexistent3'

  # Expected output:
  # ts=<ts> level=info msg="message" uri="http://example.com" uri_response="404 Not Found" foo="bar baz"
  # ts=<ts> level=error msg="Each key should have a value"
  # ts=<ts> level=debug msg="debug message" key1=value1 key2=value2
  # ts=<ts> level=fatal msg="fatal message"
  # ts=<ts> level=error msg="Invalid log level: invalid"
  # ts=<ts> level=info msg="passed from stdin" key1=value1 key2=value2
  # ts=<ts> level=info msg="NAME  READY  STATUS  RESTARTS  AGE" title="hello world"
  # ts=<ts> level=error msg="ls: cannot access '/nonexistent1': No such file or directory" command="ls /nonexistent1 /nonexistent2 /nonexistent3" exit_code=2
  # ts=<ts> level=error msg="ls: cannot access '/nonexistent2': No such file or directory" command="ls /nonexistent1 /nonexistent2 /nonexistent3" exit_code=2
  # ts=<ts> level=error msg="ls: cannot access '/nonexistent3': No such file or directory" command="ls /nonexistent1 /nonexistent2 /nonexistent3" exit_code=2
fi

# To simulate a k8s cronjob pod without ttl:
# docker run --rm -v "$(realpath kubernetes/scripts/logging.sh):/script.sh" ubuntu bash -c '/script.sh'
