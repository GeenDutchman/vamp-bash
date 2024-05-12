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
    source bash-vamp.sh --loadtest
}

function test_map_item_generation { # @test
    
    run makeMapItem "zoo"
    [ "$status" -eq 2 ]
    run makeMapItem 3 4 10 V
    [ "$status" -eq 0 ]
    [ "$output" = "3x4y10zV" ]
}

function test_init_walls { # @test
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,,,█,:█,,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:,"
    run initWalls 5 5 0
    assert_success
    echo -e "$map" | assert_output --stdin
}

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
    run verifyMapState "$map" --printsuccess --diagnose
    assert_failure 1

}

function test_draw_map { # @test
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,,,█,:█,,V,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:1x1y1z#,2x2y1zV,"
    local -r endMap=$'█████\n█#  █\n█ V █\n█   █\n█████'

    run --separate-stderr drawMap "$map"
    echo "Error was:$stderr"
    assert_success
    assert_output -p "#"
    assert_output -p "V"
    echo -e "$endMap" | assert_output --stdin
}

function test_place_new_entity { # @test
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,,,█,:█,,V,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:2x2y0zV,"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,,,█,:█,,V,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:1x1y0z#,2x2y0zV,"

    run placeEntity "$map" 1 1 --new "#"
    assert_success
    echo -e "$endmap" | assert_output --stdin
}

function test_draw_map_Redraw { # @test

    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,,,█,:█,,V,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:1x1y0z#,2x2y0zV,"
    local -r endMap=$'█████\n█#  █\n█ V █\n█   █\n█████'
    
    echo "Map length is ${#map}"
    run drawMap "$map"
    assert_success
    assert_output -p "#"
    echo "First output length was ${#output}"
    echo -e "$endMap" | assert_output --stdin
    run --separate-stderr drawMap "$map"
    assert_success
    assert_output -p "#"
    assert_output -p "V"
    echo "Second output length was ${#output}"
    echo -e "$endMap" | assert_output --stdin
}

function test_move_entity { # @test
    
    local -r preventity="2x1y0zM"
    local -r postentity="2x2y0zM"
    local -r prevmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,M,,█,:█,,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:${preventity},"
    local -r postmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,W,,█,:█,,M,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:${postentity},"
    local -r prevdraw=$'█████\n█ M █\n█   █\n█   █\n█████'
    local -r postdraw=$'█████\n█ W █\n█ M █\n█   █\n█████'

    run placeEntity "$prevmap" 2 2 --move "$preventity"
    assert_success
    echo -e "$postmap" | assert_output --stdin

    run drawMap "$prevmap"
    echo -e "$prevdraw" | assert_output --stdin
    run drawMap "$postmap"
    echo -e "$postdraw" | assert_output --stdin
}

function test_make_simple_move_VertDown { # @test   
    local -r startV1="1x1y0zV"
    local -r startP1="1x3y0z#"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,V,,,█,:█,,,,█,:█,#,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startV1},"
    local -r endV1="1x2y0zV"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,,,█,:█,V,,,█,:█,#,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${endV1},"
    run makeSimpleMove "$map" "$startV1" "$startP1"
    assert_success
    assert_output -p "$endV1"
    assert_output "$endmap"
}

function test_make_simple_move_VertDown_dir { # @test   
    local -r startV1="1x1y0zV"
    local -r startP1="1x3y0z#"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,V,,,█,:█,,,,█,:█,#,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startV1},"
    local -r endV1="1x2y0zV"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,,,█,:█,V,,,█,:█,#,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${endV1},"
    run makeSimpleMove "$map" "$startV1" --direction "s" "$startP1"
    assert_success
    assert_output -p "$endV1"
    assert_output "$endmap"
}

function test_make_simple_move_VertDown_dir_only { # @test   
    local -r startV1="1x1y0zV"
    local -r startP1="1x3y0z#"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,V,,,█,:█,,,,█,:█,#,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startV1},"
    local -r endV1="1x2y0zV"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,,,█,:█,V,,,█,:█,#,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${endV1},"
    run makeSimpleMove "$map" "$startV1" --direction "s"
    assert_success
    assert_output -p "$endV1"
    assert_output "$endmap"
}

function test_make_simple_move_VertUp { # @test
    local -r startV1="1x3y0zV"
    local -r startP1="1x1y0z#"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,,,█,:█,,,,█,:█,V,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startV1},"
    local -r endV1="1x2y0zV"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,,,█,:█,V,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${endV1},"
    run makeSimpleMove "$map" "$startV1" "$startP1"
    assert_success
    assert_output -p "$endV1"
    assert_output "$endmap"
}

function test_make_simple_move_VertUp_dir { # @test
    local -r startV1="1x3y0zV"
    local -r startP1="1x1y0z#"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,,,█,:█,,,,█,:█,V,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startV1},"
    local -r endV1="1x2y0zV"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,,,█,:█,V,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${endV1},"
    run makeSimpleMove "$map" "$startV1" --direction "w" "$startP1"
    assert_success
    assert_output -p "$endV1"
    assert_output "$endmap"
}

function test_make_simple_move_HorzLeft { # @test
    local -r startV1="3x1y0zV"
    local -r startP1="1x1y0z#"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,,V,█,:█,,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startV1},"
    local -r endV1="2x1y0zV"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,V,,█,:█,,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${endV1},"
    run makeSimpleMove "$map" "$startV1" "$startP1"
    assert_success
    assert_output -p "$endV1"
    assert_output "$endmap"
}

function test_make_simple_move_HorzLeft_dir { # @test
    local -r startV1="3x1y0zV"
    local -r startP1="1x1y0z#"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,,V,█,:█,,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startV1},"
    local -r endV1="2x1y0zV"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,#,V,,█,:█,,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${endV1},"
    run makeSimpleMove "$map" "$startV1" --direction "a" "$startP1"
    assert_success
    assert_output -p "$endV1"
    assert_output "$endmap"
}

function test_make_simple_move_HorzRight { # @test
    local -r startV1="1x1y0zV"
    local -r startP1="3x1y0z#"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,V,,#,█,:█,,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startV1},"
    local -r endV1="2x1y0zV"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,V,#,█,:█,,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${endV1},"
    run makeSimpleMove "$map" "$startV1" "$startP1"
    assert_success
    assert_output -p "$endV1"
    assert_output "$endmap"
}

function test_make_simple_move_HorzRight_dir { # @test
    local -r startV1="1x1y0zV"
    local -r startP1="3x1y0z#"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,V,,#,█,:█,,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startV1},"
    local -r endV1="2x1y0zV"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,V,#,█,:█,,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${endV1},"
    run makeSimpleMove "$map" "$startV1" --direction "d" "$startP1"
    assert_success
    assert_output -p "$endV1"
    assert_output "$endmap"
}

function test_make_simple_move_Diag { # @test
    local -r startV1="1x1y0zV"
    local -r startP1="3x3y0z#"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,V,,,█,:█,,,,█,:█,,,#,█,:█,█,█,█,█,:ENTITIES:${startP1},${startV1},"

    run makeSimpleMove "$map" "$startV1" "$startP1"
    assert_success
    assert_output --regexp '(1x2y0zV)|(2x1y0zV)'
}

function test_make_simple_move_TwoTargetCloseLast { # @test
    local -r startV1="1x1y0zV"
    local -r startP1="1x3y0z#"
    local -r startP2="2x1y0z#"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,V,#,,█,:█,,,,█,:█,#,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startP2},${startV1},"
    local -r endV1="2x1y1zV"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,#V,,█,:█,,,,█,:█,#,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startP2},${endV1},"
    run makeSimpleMove "$map" "$startV1" "$startP1" "$startP2"
    assert_success
    assert_output -p "$endV1"
    assert_output "$endmap"
}

function test_make_simple_move_TwoTargetCloseFirst { # @test
    local -r startV1="1x1y0zV"
    local -r startP1="1x3y0z#"
    local -r startP2="2x1y0z#"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,V,#,,█,:█,,,,█,:█,#,,,█,:█,█,█,█,█,:ENTITIES:${startP2},${startP1},${startV1},"
    local -r endV1="2x1y1zV"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,#V,,█,:█,,,,█,:█,#,,,█,:█,█,█,█,█,:ENTITIES:${startP2},${startP1},${endV1},"
    run makeSimpleMove "$map" "$startV1" "$startP2" "$startP1"
    assert_success
    assert_output -p "$endV1"
    assert_output "$endmap"
}

function test_make_simple_move_IgnoreDistractions { # @test
    local -r startV1="1x1y0zV"
    local -r startP1="1x3y0z#"
    local -r startM1="3x1y0zM"
    local -r map="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,V,,M,█,:█,,,,█,:█,#,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startM1},${startV1},"
    local -r endV1="1x2y0zV"
    local -r endmap="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,,M,█,:█,V,,,█,:█,#,,,█,:█,█,█,█,█,:ENTITIES:${startP1},${startM1},${endV1},"
    run makeSimpleMove "$map" "$startV1" "$startP1" "$startM1"
    assert_success
    assert_output -p "$endV1"
    assert_output "$endmap"
}

function test_check_goal_PlayerMissedGoal { # @test
    
    run checkGoal "1x1y2z#" "1x2y1z@"
    assert_failure 1
    assert_output ""
}

function test_check_goal_GoalNotSeekPlayer { # @test 
    
    run checkGoal "1x1y2z@" "1x1y1z#"
    assert_failure 1
    assert_output ""
}

function test_check_goal_PlayerGetGoal { # @test
    
    run checkGoal "1x1y2z#" "1x1y1z@"
    assert_success
    assert_output "Player advances to next round!"
}

function test_check_goal_MonsterGetPlayer { # @test
    
    run checkGoal "1x1y2zV" "1x1y9zM" "1x1y1z#"
    assert_success
    assert_output "V got you!  Restarting level...."

    run checkGoal "1x1y9zM" "1x1y2zV" "1x1y1z#"
    assert_success
    assert_output "M got you!  Restarting level...."
}

function test_make_entity_set { # @test
    
    local -r walls="MAZE_META:5x5yMAZE:█,█,█,█,█,:█,,,,█,:█,,,,█,:█,,,,█,:█,█,█,█,█,:ENTITIES:,"

    run --separate-stderr makeEntitySet "$walls" 1
    echoerr -e "Output was \n$output\nStderr was \n$stderr"
    assert_output -p "@"
    assert_output -p "#"
    assert_output -p "V"
    assert_success
    run --separate-stderr drawMap "$output"
    assert_output -p "@"
    assert_output -p "#"
    assert_output -p "V"
    assert_success
    echoerr -e "Output was \n$output"

    run makeEntitySet "MAZE_META:1x1yMAZE:█,:ENTITIES:," 1
    assert_failure
    assert_output -p "Could not place"
}
