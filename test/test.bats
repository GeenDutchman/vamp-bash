#!/usr/bin/env bats

@test "test something." {
    run echo "Starting"
    [ "$status" -eq 0 ]
    [ "$output" = "Starting" ]
}