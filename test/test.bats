#!/usr/bin/env bats

setup() {
    bats_require_minimum_version 1.5.0
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    PROJECT_ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
    # make executables in src/ visible to PATH
    PATH="$PROJECT_ROOT/src:$PATH"
    load bash-vamp.sh
}

function test_map_item_generation { # @test
    
    run makeMapItem "zoo"
    [ "$status" -eq 2 ]
    run makeMapItem 3 4 10 J
    [ "$status" -eq 0 ]
    [ "$output" = "3x4:10:J: " ]
}

function test_init_walls { # @test
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,,,█,:█,,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:"
    run initWalls 5 5 0
    assert_success
    echo -e "$map" | assert_output --stdin
}

function test_map_item_attribute { # @test
    
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
    
    run translateCoordinate 5 "toFlat" 3 2
    assert_success
    assert_output "15"
    run translateCoordinate 5 "toCartesian" "15"
    assert_success
    assert_output "3 2"
}

# bats test_tags=bats:focus
function test_generate_matchers { # @test
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,,,█,:█,,V,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:1x1y1z#,2x2y1zV,"

    local -r stateMatcher=$( generateMatchers )
    [[ "$map" =~ $stateMatcher ]]
    echo "rematch STATE:$stateMatcher"
    for ((i=0; i < ${#BASH_REMATCH[@]}; i++)); do
        echo -e "\t$i: ${BASH_REMATCH[$i]}"
    done

    local -r mazeMatcher=$( generateMatchers "MAZE" )
    [[ "$map" =~ $mazeMatcher ]]
    echo "rematch MAZE:$mazeMatcher"
    for ((i=0; i < ${#BASH_REMATCH[@]}; i++)); do
        echo -e "\t$i: ${BASH_REMATCH[$i]}"
    done
    local -r zeroth="${BASH_REMATCH[0]}"
    assert_regex "$zeroth" "MAZE"
    refute_regex "$zeroth" "ENTITIES"

    local -i -r vampY=2
    local -r rowMatcher=$( generateMatchers "MAP_ROWS" )
    echo "Matcher MAP_ROWS:$rowMatcher"
    local maze=${map/#?+MAZE:/}
    echo "Leftover maze: $maze"
    for (( y=0;y<=$vampY;y++ )); do
        if ! [[ "$maze" =~ $rowMatcher ]]; then
            fail "How did it get to $y with $maze?"
        fi
        echo "rematch $y:"
        for ((i=0; i < ${#BASH_REMATCH[@]}; i++)); do
            echo -e "\t$i: ${BASH_REMATCH[$i]}"
        done
        maze="${BASH_REMATCH[3]}"
    done
    assert_regex "${BASH_REMATCH[1]}" "V"
}

function test_verify_map_state { # @test
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,X,,,█,:█,,O,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:1x1y1zX,2x2y1zO,"
    run verifyMapState --printsuccess "$map"
    assert_failure 1

}

function test_draw_map { # @test
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,,,█,:█,,V,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:1x1y1z#,2x2y1zV,"
    local -r endMap=$'█████\n█#  █\n█ V █\n█   █\n█████'

    run --separate-stderr drawMap "$map" "5"
    echo "Error was:$stderr"
    assert_success
    assert_output -p "#"
    assert_output -p "V"
    echo -e "$endMap" | assert_output --stdin
}

# bats test_tags=bats:focus
function test_place_new_entity { # @test
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,,,█,:█,,V,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:2x2y0zV,"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,,,█,:█,,V,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:1x1y0z#,2x2y0zV,"

    run placeNewEntity "$map" "#" 1 1
    assert_success
    echo -e "$endmap" | assert_output --stdin

}

function test_draw_map_Redraw { # @test

    local -r map=$'█████\n█   █\n█   █\n█   █\n█████'
    local -r entity1="1x1:1:X:"
    local -r midMap=$'█████\n█X  █\n█   █\n█   █\n█████'
    local -r entity2="2x2:1:O:"
    local -r endMap=$'█████\n█X  █\n█ O █\n█   █\n█████'
    
    echo "Map length is ${#map}"
    run --separate-stderr drawMap "$map" "5" "$entity1"
    echoerr -e "First error was:\n${stderr?}"
    assert_success
    assert_output -p "X"
    echo "First output length was ${#output}"
    echo -e "$midMap" | assert_output --stdin
    run --separate-stderr drawMap "$output" "5" "$entity1" "$entity2"
    echoerr -e "Second error was:\n${stderr?}"
    assert_success
    assert_output -p "X"
    assert_output -p "O"
    echo "End map length is ${#endMap}"
    echo "Second output length was ${#output}"
    echo -e "$endMap" | assert_output --stdin
}

function test_move_entity { # @test
    
    local -r walls=$'█████\n█   █\n█   █\n█   █\n█████'
    local -r map=$'█████\n█ M █\n█   █\n█   █\n█████'
    local -r preentity="2x1:9:M:W"
    local -r postentities=$'2x2:9:M:W\n2x1:8:W: '
    local -r postmap=$'█████\n█ W █\n█ M █\n█   █\n█████'

    run moveEntity "$map" "$preentity" 2 2
    assert_success
    echo -e "$postentities" | assert_output --stdin

    run drawMap "$walls" 5 "$preentity"
    echo -e "$map" | assert_output --stdin
    run drawMap "$map" 5 $(echo -e "$postentities")
    echo -e "$postmap" | assert_output --stdin
}

function test_make_simple_move_VertDown { # @test
    
    local -r walls=$'█████\n█   █\n█   █\n█   █\n█████'
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
    
    local -r walls=$'█████\n█   █\n█   █\n█   █\n█████'
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
    
    local -r walls=$'█████\n█   █\n█   █\n█   █\n█████'
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
    
    local -r walls=$'█████\n█   █\n█   █\n█   █\n█████'
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
    
    local -r walls=$'█████\n█   █\n█   █\n█   █\n█████'
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

function test_make_simple_move_TwoTargetCloseLast { # @test
    
    local -r walls=$'█████\n█   █\n█   █\n█   █\n█████'
    local -r startV1="1x1:3:V:"
    local -r startP1="1x3:2:#:"
    local -r startZ1="2x1:3:#:"
    local -r endV1="2x1:3:V:"
    run drawMap "$walls" 5 "$startV1" "$startP1" "$startZ1"
    assert_success
    assert_output -p "V"
    assert_output -p "#"
    local -r printed1="$output"
    run makeSimpleMove "$printed1" "$startV1" "$startP1" "$startZ1"
    assert_success
    assert_output "$endV1"
}

function test_make_simple_move_TwoTargetCloseFirst { # @test
    
    local -r walls=$'█████\n█   █\n█   █\n█   █\n█████'
    local -r startV1="1x1:3:V:"
    local -r startP1="1x3:2:#:"
    local -r startZ1="2x1:3:#:"
    local -r endV1="2x1:3:V:"
    run drawMap "$walls" 5 "$startV1" "$startZ1" "$startP1"
    assert_success
    assert_output -p "V"
    assert_output -p "#"
    local -r printed1="$output"
    run makeSimpleMove "$printed1" "$startV1" "$startZ1" "$startP1"
    assert_success
    assert_output "$endV1"
}

function test_make_simple_move_IgnoreDistractions { # @test
    
    local -r walls=$'█████\n█   █\n█   █\n█   █\n█████'
    local -r startV1="1x1:3:V:"
    local -r startP1="1x3:2:#:"
    local -r startZ1="3x1:3:Z:"
    local -r endV1="1x2:3:V:"
    run drawMap "$walls" 5 "$startV1" "$startP1" "$startZ1"
    assert_success
    assert_output -p "V"
    assert_output -p "#"
    assert_output -p "Z"
    local -r printed1="$output"
    run makeSimpleMove "$printed1" "$startV1" "$startP1" "$startZ1"
    assert_success
    assert_output "$endV1"
}

function test_check_goal_PlayerMissedGoal { # @test
    
    run checkGoal "1x1:2:#:" "1x2:1:@:"
    assert_failure 1
    assert_output ""
}

function test_check_goal_GoalNotSeekPlayer { # @test 
    
    run checkGoal "1x1:2:@:" "1x1:1:#:"
    assert_failure 1
    assert_output ""
}

function test_check_goal_PlayerGetGoal { # @test
    
    run checkGoal "1x1:2:#:" "1x1:1:@:"
    assert_success
    assert_output "#"
}

function test_check_goal_MonsterGetPlayer { # @test
    
    run checkGoal "1x1:2:V:" "1x1:9:M:" "1x1:1:#:"
    assert_success
    assert_output "V"

    run checkGoal "1x1:9:M:" "1x1:2:V:" "1x1:1:#:"
    assert_success
    assert_output "M"
}

function test_make_entity_set { # @test
    
    local -r walls=$'█████\n█   █\n█   █\n█   █\n█████'

    run --separate-stderr makeEntitySet "$walls" 1 5 5
    echoerr -e "Output was \n$output\nStderr was \n$stderr"
    assert_output -p "@"
    assert_output -p "#"
    assert_output -p "V"
    assert_success
    run --separate-stderr drawMap "$walls" 5 $output
    assert_output -p "@"
    assert_output -p "#"
    assert_output -p "V"
    assert_success
    echoerr -e "Output was \n$output"
    [ 2 -eq 0 ]

    run makeEntitySet "█" 1 1 1
    assert_failure
    assert_output -p "Could not place"
}
