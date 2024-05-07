#!/usr/bin/env bats

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    PROJECT_ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
    # make executables in src/ visible to PATH
    PATH="$PROJECT_ROOT/src:$PATH"
}

function test_map_item_generation { # @test
    load bash-vamp.sh
    run makeMapItem "zoo"
    [ "$status" -eq 2 ]
    run makeMapItem 3 4 10 J
    [ "$status" -eq 0 ]
    [ "$output" = "3x4:10:J: " ]
}

function test_translate_coordinate { # @test
    load bash-vamp.sh
    run translateCoordinate 5 "toFlat" 3 2
    assert_success
    assert_output "17"
    run translateCoordinate 5 "toCartesian" "17"
    assert_success
    assert_output "3 2"
}

function test_draw_map { # @test
    load bash-vamp.sh
    local -r map="█████\n█   █\n█   █\n█   █\n█████"
    local -r entity1="1x1:1:X:"
    local -r entity2="2x2:1:O:"
    local -r endMap="█████\n█X  █\n█ O █\n█   █\n█████"

    run drawMap "$map" "5" "$entity1" "$entity2"
    assert_success
    assert_output -p "X"
    echo -e "$endMap" | assert_output --stdin

    run drawMap "$map" "5" "$entity2" "$entity1"
    assert_success
    assert_output -p "X"
    echo -e "$endMap" | assert_output --stdin
}
