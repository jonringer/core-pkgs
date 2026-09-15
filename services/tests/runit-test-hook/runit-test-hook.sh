#!/usr/bin/env bash

# runit-test-hook.sh
# Setup hook for running runit-supervised services in tests
#
# This hook provides functions to start and stop runit's runsvdir
# service supervisor, allowing tests to run multiple services and
# test their interactions via localhost.
#
# Usage:
#   nativeCheckInputs = [ runitTestHook ];
#
#   preCheck = ''
#     # Setup service directory
#     export RUNIT_SERVICE_DIR="$TMPDIR/service"
#     mkdir -p "$RUNIT_SERVICE_DIR"
#
#     # Link service directories
#     ln -s ${myService} "$RUNIT_SERVICE_DIR/myservice"
#
#     # Start runit supervisor
#     runitTestStart
#
#     # Wait for service to be ready
#     runitTestWaitPort 8080
#   '';
#
#   postCheck = ''
#     # Cleanup handled automatically by hook
#   '';

# Configuration variables (can be overridden before calling runitTestStart)
: "${RUNIT_SERVICE_DIR:=$TMPDIR/service}"
: "${RUNIT_LOG_DIR:=$TMPDIR/runit-log}"
: "${RUNIT_WAIT_TIMEOUT:=30}"

# Internal state
RUNIT_PID=""
RUNIT_STARTED=""

# Start runsvdir supervisor
#
# Starts runsvdir in the background to supervise services in RUNIT_SERVICE_DIR.
# Services must be symlinked or copied to this directory before calling this function.
runitTestStart() {
    echo "=== Starting runit test environment ===" >&2

    # Create service directory if it doesn't exist
    if [ ! -d "$RUNIT_SERVICE_DIR" ]; then
        mkdir -p "$RUNIT_SERVICE_DIR"
    fi

    # Create log directory
    mkdir -p "$RUNIT_LOG_DIR"

    echo "Service directory: $RUNIT_SERVICE_DIR" >&2
    echo "Log directory: $RUNIT_LOG_DIR" >&2

    # Start runsvdir with output captured to log file
    @runitPackage@/bin/runsvdir "$RUNIT_SERVICE_DIR" > "$RUNIT_LOG_DIR/runsvdir.log" 2>&1 &

    RUNIT_PID=$!
    RUNIT_STARTED=1

    echo "runsvdir started with PID: $RUNIT_PID" >&2

    # Give runsvdir time to start services
    sleep 1

    # Verify runsvdir is still running
    if ! kill -0 "$RUNIT_PID" 2>/dev/null; then
        echo "ERROR: runsvdir failed to start" >&2
        if [ -f "$RUNIT_LOG_DIR/runsvdir.log" ]; then
            echo "runsvdir log:" >&2
            cat "$RUNIT_LOG_DIR/runsvdir.log" >&2
        fi
        return 1
    fi

    echo "=== runit test environment ready ===" >&2
}

# Stop runsvdir supervisor and all services
#
# Sends SIGTERM to runsvdir and all supervised services.
# runsvdir will shutdown services gracefully.
runitTestStop() {
    if [ -z "$RUNIT_STARTED" ]; then
        return 0
    fi

    echo "=== Stopping runit test environment ===" >&2

    if [ -n "$RUNIT_PID" ] && kill -0 "$RUNIT_PID" 2>/dev/null; then
        echo "Stopping runsvdir (PID: $RUNIT_PID)" >&2

        # Send SIGTERM to runsvdir
        kill "$RUNIT_PID" || true

        # Wait for runsvdir to exit (it will kill supervised processes)
        local timeout=10
        local elapsed=0
        while kill -0 "$RUNIT_PID" 2>/dev/null && [ $elapsed -lt $timeout ]; do
            sleep 1
            elapsed=$((elapsed + 1))
        done

        # Force kill if still running
        if kill -0 "$RUNIT_PID" 2>/dev/null; then
            echo "Force killing runsvdir" >&2
            kill -9 "$RUNIT_PID" || true
        fi
    fi

    # Kill any lingering runsv processes (in case they didn't stop)
    @procpsPackage@/bin/pkill -f "runsv $RUNIT_SERVICE_DIR" || true

    RUNIT_PID=""
    RUNIT_STARTED=""

    echo "=== runit test environment stopped ===" >&2
}

# Wait for a service to be ready by checking if a port is listening
#
# Args:
#   $1 - port number to check
#   $2 - host (default: localhost)
#   $3 - timeout in seconds (default: RUNIT_WAIT_TIMEOUT)
#
# Returns:
#   0 if port is listening, 1 if timeout
runitTestWaitPort() {
    local port="$1"
    local host="${2:-localhost}"
    local timeout="${3:-$RUNIT_WAIT_TIMEOUT}"

    echo "Waiting for port $port on $host (timeout: ${timeout}s)..." >&2

    local elapsed=0
    while [ $elapsed -lt "$timeout" ]; do
        if @netcatPackage@/bin/nc -z "$host" "$port" 2>/dev/null; then
            echo "Port $port is ready!" >&2
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    echo "ERROR: Timeout waiting for port $port" >&2
    return 1
}

# Wait for a Unix socket to exist
#
# Args:
#   $1 - socket path
#   $2 - timeout in seconds (default: RUNIT_WAIT_TIMEOUT)
#
# Returns:
#   0 if socket exists, 1 if timeout
runitTestWaitSocket() {
    local socket="$1"
    local timeout="${2:-$RUNIT_WAIT_TIMEOUT}"

    echo "Waiting for socket $socket (timeout: ${timeout}s)..." >&2

    local elapsed=0
    while [ $elapsed -lt "$timeout" ]; do
        if [ -S "$socket" ]; then
            echo "Socket $socket is ready!" >&2
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    echo "ERROR: Timeout waiting for socket $socket" >&2
    return 1
}

# Wait for a service to be supervised by checking supervise/ok file
#
# Args:
#   $1 - service name
#   $2 - timeout in seconds (default: RUNIT_WAIT_TIMEOUT)
#
# Returns:
#   0 if service is supervised, 1 if timeout
runitTestWaitService() {
    local service="$1"
    local timeout="${2:-$RUNIT_WAIT_TIMEOUT}"

    echo "Waiting for service '$service' to be supervised (timeout: ${timeout}s)..." >&2

    local elapsed=0
    while [ $elapsed -lt "$timeout" ]; do
        if [ -f "$RUNIT_SERVICE_DIR/$service/supervise/ok" ]; then
            echo "Service '$service' is supervised!" >&2
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    echo "ERROR: Timeout waiting for service '$service'" >&2
    return 1
}

# Get status of all supervised services
#
# Uses 'sv status' to check all services
runitTestStatus() {
    echo "=== Service Status ===" >&2
    for service in "$RUNIT_SERVICE_DIR"/*; do
        if [ -d "$service" ] && [ ! -L "$service" ]; then
            local svc_name=$(basename "$service")
            echo -n "$svc_name: " >&2
            @runitPackage@/bin/sv status "$service" 2>&1 || echo "not supervised" >&2
        fi
    done
}

# Register cleanup hook to stop services on exit
if [ -z "${__runitTestHookInstalled:-}" ]; then
    __runitTestHookInstalled=1

    # Add to postCheckHooks for automatic cleanup
    postCheckHooks+=(runitTestStop)

    echo "runit test hook installed" >&2
fi
