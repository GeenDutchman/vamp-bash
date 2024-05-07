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

function test_map_item_attribute { # @test
    load bash-vamp.sh
    local -r item="1x2:10:M:W"
    run retriveMapItemAttribute "$item" "x"
    assert_output "1"
    run retriveMapItemAttribute "$item" "y"
    assert_output "2"
    run retriveMapItemAttribute "$item" "mohs"
    assert_output "10"
    run retriveMapItemAttribute "$item" "code"
    assert_output "M"
    run retriveMapItemAttribute "$item" "replace"
    assert_output "W"

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
    assert_output -p "O"
    echo -e "$endMap" | assert_output --stdin

    run drawMap "$map" "5" "$entity2" "$entity1"
    assert_success
    assert_output -p "X"
    assert_output -p "O"
    echo -e "$endMap" | assert_output --stdin
}

function test_detect_width { # @test
    load bash-vamp.sh
    local -r map="█████\n█   █\n█   █\n█   █\n█████"
    local -r badmap="█████\n██\n██\n██\n█████"

    run detectWidth "$map"
    assert_success
    assert_output "5"

    run detectWidth "$badmap"
    assert_failure 2
    assert_output -p "Inconsistent"
}

function test_move_entity { # @test
    load bash-vamp.sh
    local -r walls="█████\n█   █\n█   █\n█   █\n█████"
    local -r map="█████\n█ M █\n█   █\n█   █\n█████"
    local -r preentity="2x1:9:M:W"
    local -r postentities="2x2:9:M:W\n2x1:8:W: "
    local -r postmap="█████\n█ W █\n█ M █\n█   █\n█████"

    run moveEntity "$map" "$preentity" 2 2
    assert_success
    echo -e "$postentities" | assert_output --stdin

    run drawMap "$walls" 5 "$preentity"
    echo -e "$map" | assert_output --stdin
    run drawMap "$map" 5 $(echo -e "$postentities")
    echo -e "$postmap" | assert_output --stdin
}

function test_make_simple_move_VertDown { # @test
    load bash-vamp.sh
    local -r walls="█████\n█   █\n█   █\n█   █\n█████"
    local -r startV1="1x1:3:V:"
    local -r startP1="1x3:2:#:"
    local -r endV1="1x2:3:V:"
    run drawMap "$walls" 5 "$startV1" "$startP1"
    assert_success
    assert_output -p "V"
    assert_output -p "#"
    local -r printed1="$output"
    run makeSimpleMove "$printed1" "$startV1" "$startP1"
    assert_success
    assert_output "$endV1"
}

function test_make_simple_move_VertUp { # @test
    load bash-vamp.sh
    local -r walls="█████\n█   █\n█   █\n█   █\n█████"
    local -r startV1="1x3:3:V:"
    local -r startP1="1x1:2:#:"
    local -r endV1="1x2:3:V:"
    run drawMap "$walls" 5 "$startV1" "$startP1"
    assert_success
    assert_output -p "V"
    assert_output -p "#"
    local -r printed1="$output"
    run makeSimpleMove "$printed1" "$startV1" "$startP1"
    assert_success
    assert_output "$endV1"
}

function test_make_simple_move_HorzLeft { # @test
    load bash-vamp.sh
    local -r walls="█████\n█   █\n█   █\n█   █\n█████"
    local -r startV1="1x1:3:V:"
    local -r startP1="3x1:2:#:"
    local -r endV1="2x1:3:V:"
    run drawMap "$walls" 5 "$startV1" "$startP1"
    assert_success
    assert_output -p "V"
    assert_output -p "#"
    local -r printed1="$output"
    run makeSimpleMove "$printed1" "$startV1" "$startP1"
    assert_success
    assert_output "$endV1"
}

function test_make_simple_move_HorzRight { # @test
    load bash-vamp.sh
    local -r walls="█████\n█   █\n█   █\n█   █\n█████"
    local -r startV1="3x1:3:V:"
    local -r startP1="1x1:2:#:"
    local -r endV1="2x1:3:V:"
    run drawMap "$walls" 5 "$startV1" "$startP1"
    assert_success
    assert_output -p "V"
    assert_output -p "#"
    local -r printed1="$output"
    run makeSimpleMove "$printed1" "$startV1" "$startP1"
    assert_success
    assert_output "$endV1"
}

function test_make_simple_move_Diag { # @test
    load bash-vamp.sh
    local -r walls="█████\n█   █\n█   █\n█   █\n█████"
    local -r startV1="1x1:3:V:"
    local -r startP1="3x3:2:#:"
    run drawMap "$walls" 5 "$startV1" "$startP1"
    assert_success
    assert_output -p "V"
    assert_output -p "#"
    local -r printed1="$output"
    run makeSimpleMove "$printed1" "$startV1" "$startP1"
    assert_success
    assert_output --regexp '^(1x2:3:V:)|(2x1:3:V:)$'
}
