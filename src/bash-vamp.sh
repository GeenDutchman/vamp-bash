#! /bin/bash

echoerr() { echo "$@" 1>&2; }

# shellcheck disable=SC2120 # optional parameter
function randomGenerator {
    local max=100
    if [[ $# -gt 0  && "$1" =~ ^0*[1-9][0-9]*$ ]]; then
        max=$1
    fi
    local result
    result=$(( RANDOM % max )) # this will do between 0-99 inclusive
    echo $result
}

# shellcheck disable=SC2120 # optional parameters
function generateMatchers { # I need this because for some reason `declare`ing them does not last through the tests
    local -r MASTER_MAP_STATE_MATCHER="MAZE_META:([[:digit:]]+)x([[:digit:]]+)y([[:digit:]]+r)?MAZE:((((█?,|@?#?V?W?M?,)*):)*)ENTITIES:(([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)*)"
    if [[ $# -eq 0 ]]; then
        selected="$MASTER_MAP_STATE_MATCHER"
        echo "$selected"
        return 0
    fi
    if [[ $# -ge 2 ]]; then
        local -n selected
    else 
        local selected
    fi
    case $1 in
        "ALLOWED_MOVES")
            selected="^[WASDwasd1234rq]$"
        ;;
        "ALLOWED_ENTITIES")
            selected="[@#VM]"
        ;;
        "ENTITY_MATCHER")
            selected="([[:digit:]]+)x([[:digit:]]+)y([[:digit:]]+)z([@#VM])"
        ;;
        "ENTITIES_LIST")
            selected="([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM]),(([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)*)"
        ;;
        "ENTITIES")
            selected="ENTITIES:(([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)?(([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)*))"
        ;;
        "MAP_META")
            selected="MAZE_META:([[:digit:]]+)x([[:digit:]]+)y([[:digit:]]+r)?"
        ;;
        "MAP_ENTRY")
            selected="█?|@?#?V?W?M?"
        ;;
        "MAP_COLS")
            selected="(█?|@?#?V?W?M?),((█?,|@?#?V?W?M?,)*):"
        ;;
        "MAP_ROWS")
            selected="((█?,|@?#?V?W?M?,)+):((((█?,|@?#?V?W?M?,)*):)*)"
        ;;
        "MAZE")
            selected="MAZE:((((█?,|@?#?V?W?M?,)*):)*)"
        ;;
        "PARTITION")
            selected="^(MAZE_META:.*)(MAZE:.*)(ENTITIES:.*)$"
        ;;
        "MAP_STATE_MATCHER")
            selected="$MASTER_MAP_STATE_MATCHER"
        ;;
        *)
            echoerr "'$1' unkown, defaulting to MAP_STATE_MATCHER"
            selected="$MASTER_MAP_STATE_MATCHER"
            return 1
        ;;
    esac

    echo "$selected"
    return 0
}

: '
    MAP_STATE is an associative array that should contain the following
    maxX: ^[[:digit:]]+$
    maxY: ^[[:digit:]]+$
    level: ^[[:digit:]]+$
    playerCount: ^[[:digit:]]+$ && > 0
    vampCount: ^[[:digit:]]+$
    mummyCount: ^[[:digit:]]+$
    goal: ^maplocation[[:digit:]]+x[[:digit:]]+y$

    And the following in the ranges:
    maplocation{0..maxX}x{0..maxY}y: ^█?|@?#?V?W?M?$
    player{0..playerCount}: ^maplocation[[:digit:]]+x[[:digit:]]+y$
    vampire{0..vampCount}: ^maplocation[[:digit:]]+x[[:digit:]]+y$
    mummy{0..mummyCount}: ^maplocation[[:digit:]]+x[[:digit:]]+y$
'
declare -A MAP_STATE

function retrieveMapState {
    declare -p MAP_STATE
}

function verifyMapState {
    if [[ ${#MAP_STATE[@]} -le 0 ]]; then
        echoerr "Map state empty, and it should not be!"
        return 1
    fi
    local -r maxX=${MAP_STATE['maxX']}
    if ! [[ "$maxX" =~ ^[[:digit:]]+$ && "$maxX" -gt 0 ]]; then
        echoerr "maxX should be a number greater than zero, not '$maxX'"
        return 1
    fi
    local -r maxY=${MAP_STATE['maxY']}
    if ! [[ "$maxY" =~ ^[[:digit:]]+$ && "$maxY" -gt 0 ]]; then
        echoerr "maxY should be a number greater than zero, not '$maxY'"
        return 1
    fi
    local -r level=${MAP_STATE['level']}
    if ! [[ "$level" =~ ^[[:digit:]] && "$level" -ge 0 ]]; then
        echoerr "level should be a number greater than or equal to zero, not '$level'"
        return 1
    fi
    local -r playerCount=${MAP_STATE['playerCount']}
    if ! [[ "$playerCount" =~ ^[[:digit:]] && "$playerCount" -gt 0 ]]; then
        echoerr "playerCount should be a number greater than, not '$playerCount'"
        return 1
    fi
    local -r vampCount=${MAP_STATE['vampCount']}
    if ! [[ "$vampCount" =~ ^[[:digit:]] && "$vampCount" -ge 0 ]]; then
        echoerr "vampCount should be a number greater than or equal to 0, not '$vampCount'"
        return 1
    fi
    local -r mummyCount=${MAP_STATE['mummyCount']}
    if ! [[ "$mummyCount" =~ ^[[:digit:]] && "$mummyCount" -ge 0 ]]; then
        echoerr "mummyCount should be a number greater than or equal to 0, not '$mummyCount'"
        return 1
    fi
    local -r location='^maplocation[[:digit:]]+x[[:digit:]]+y$'
    local -r goal=${MAP_STATE['goal']}
    if ! [[ "$goal" =~ $location ]]; then
        echoerr "goal should be present and match '$location', thus not '$goal'"
        return 1
    fi
    for (( x=0;x<maxX;x++ )); do
        for (( y=0;y<maxY;y++ )); do
            key=$( printf "maplocation%dx%dy" "$x" "$y" )
            entry=${MAP_STATE[$key]}
            if ! [[ "$entry" =~ ^█?|@?#?V?W?M?$ ]]; then
                echoerr "Map entry '$key' has the value '$entry' which is not valid like so: '^█?|@?#?V?W?M?$'"
                return 1
            fi
        done
    done
    for (( p=0;p<playerCount;p++)); do
        key=$( printf "player%d" "$p" )
        entry=${MAP_STATE[$key]}
        if ! [[ "$entry" =~ $location ]]; then
            echoerr "Player entry '$key' has the value '$entry' which is not valid like so: '$location'"
            return 1
        fi
    done
    for (( v=0;v<vampCount;v++)); do
        key=$( printf "vamp%d" "$v" )
        entry=${MAP_STATE[$key]}
        if ! [[ "$entry" =~ $location ]]; then
            echoerr "Vampire entry '$key' has the value '$entry' which is not valid like so: '$location'"
            return 1
        fi
    done
    for (( m=0;m<mummyCount;m++)); do
        key=$( printf "mummy%d" "$m" )
        entry=${MAP_STATE[$key]}
        if ! [[ "$entry" =~ $location ]]; then
            echoerr "Mummy entry '$key' has the value '$entry' which is not valid like so: '$location'"
            return 1
        fi
    done
    return 0
}


function initWalls {
    if [[ $# -lt 3 ]]; then
        echoerr "Need arguments of 'mapMaxX', 'mapMaxY', and 'fill'. They all need to be positive integers."
        return 1
    fi
    if ! [[ $1 =~ ^[[:digit:]]+$ && $2 =~ ^[[:digit:]]+$ && $3 =~ ^[[:digit:]]+$ ]]; then
        echoerr "The arguments for 'mapMaxX', 'mapMaxY', and 'fill' should be positive integers, not '$1', '$2', and '$3'"
        return 1
    fi

    local -i -t -r mapMaxX=$1
    local -i -t -r mapMaxY=$2
    local -i -t -r fill=$3
    local -r level=$( if [[ $# -ge 4 && "$4" =~ ^[[:digit:]]+$ ]]; then echo "${2}r"; else echo ""; fi )

    if [[ $# -ge 4 ]]; then
        local -n wally=$4
        wally="MAZE_META:${mapMaxX}x${mapMaxY}y${level}MAZE:"
    else
        local wally
        wally="MAZE_META:${mapMaxX}x${mapMaxY}y${level}MAZE:"
    fi
    
    local -i y; local -i x;
    for (( y = 0; y < mapMaxY; y++)); do
        for (( x = 0; x < mapMaxX; x++ )); do
            if [[ $y -eq 0 || $y -eq $(( mapMaxY - 1 )) ]]; then
                wally+="█,"
            elif [[ $x -eq 0 || $x -eq $(( mapMaxX - 1 )) ]]; then
                wally+="█,"
            elif [[ $(randomGenerator) -lt $fill ]]; then
                wally+="█,"
            else
                wally+=","
            fi
        done
        wally+=":"
    done

    wally+="ENTITIES:,"
    if ! verifyMapState "$wally"; then
        verifyMapState "$wally" --diagnose
        return 1
    fi

    if [[ $# -lt 4 ]]; then
        echo -e "$wally"
    fi
    return 0
}

function placeEntity { # placeEntity 'state' 'xDestination' 'yDestination' (--new 'code' | --move 'entity')
    local -r usageString="Usage: placeEntity 'state' 'xDestination' 'yDestination' (--new 'code' | --move 'entity')"
    if [[ $# -ne 5 ]]; then
        echoerr "$usageString"
        return 2
    fi
    if ! verifyMapState "$1" --diagnose ; then
        return 2
    fi
    local state="$1"
    if ! [[ "$state" =~ $( generateMatchers "MAP_META" ) ]]; then
        echoerr "State doesn't have xMax and yMax"
        return 2
    fi
    local -i -r xMax=${BASH_REMATCH[1]}
    local -i -r yMax=${BASH_REMATCH[2]}
    shift # past the state
    if [[ $1 -le 0 || $1 -ge $xMax || $2 -le 0 || $2 -ge $yMax ]]; then
        echoerr "'$1' and '$2' must be strictly inside the bounds of (0, $xMax) and (0, $yMax)"
        echo "$state"
        return 1
    fi
    local -i -r xCoord=$1
    local -i -r yCoord=$2
    shift
    shift

    local -r allowedEntities=$( generateMatchers "ALLOWED_ENTITIES" )
    local -r entityMatcher=$( generateMatchers "ENTITY_MATCHER" )
    local entity
    local code
    local mohs
    local -r mode="$1"
    if [[ "$1" = "--new" && "$2" =~ $allowedEntities ]]; then
        entity=$( makeMapItem "$xCoord" "$yCoord" 0 "$2" )
        local -r code="$2"
        local -r mohs=$( mohsMap "$code" )
    elif [[ "$1" = "--move" && "$2" =~ $entityMatcher ]]; then
        entity="$2"
        local -r code="${BASH_REMATCH[4]}"
        local -r mohs=$( mohsMap "$code" )
    else
        echoerr "$usageString"
        echoerr "A --new code must match '$allowedEntities' and an entity to --move must match '$entityMatcher'"
        echoerr "But your call for '$mode' provided '$2'"
        echo "$state"
        return 1
    fi

    if ! [[ "$state" =~ $( generateMatchers "MAZE" ) && ${#BASH_REMATCH[@]} -ge 2 ]]; then
        echoerr "Cannot find the maze"
        echo "$state"
        return 1
    fi
    local maze=${BASH_REMATCH[1]}
    local -a rows
    IFS=":" read -r -d '' -a rows < <( printf "%s\0" "$maze" )
    if [[ $yCoord -ge ${#rows[@]} ]]; then
        echo "$state"
        return 1
    fi

    local -a cols
    IFS="," read -r -d '' -a cols < <( printf "%s\0" "${rows[$yCoord]}" )
    if [[ $xCoord -ge ${#cols[@]} ]]; then
        echo "$state"
        return 1
    fi

    local -i -r mohsThere=$( mohsMap "${cols[$xCoord]: -1:1}" )
    if [[ $mohsThere -ge $mohs ]]; then
        echo "$state"
        return 1
    fi
    
    local -r -i zCoord=${#cols[$xCoord]}
    cols[xCoord]+="$code"
    rows[yCoord]="" # reset
    for (( xcol=0; xcol<${#cols[@]}; xcol++ )); do
        rows[yCoord]+=$( printf "%s," "${cols[$xcol]}" )
    done

    function remove {
        if [[ "$mode" = "--move" && "$entity" =~ $entityMatcher ]]; then
            local -r fromX="${BASH_REMATCH[1]}"
            local -r fromY="${BASH_REMATCH[2]}"
            local -r fromZ="${BASH_REMATCH[3]}"
            if [[ $fromX -ge $xMax || $fromY -ge $yMax || $fromX -le 0 || $fromY -le 0 || $fromZ -lt 0 ]]; then
                echoerr "Cannot remove entity '$entity' from out of bounds"
                return 1
            fi
            unset cols
            IFS="," read -r -d '' -a cols < <( printf "%s\0" "${rows[$fromY]}" )
            local replaceArea=${cols[$fromX]:0:${fromZ}+1}
            local -r replacecode=$( if [[ "$code" = "M" ]]; then echo "W"; else echo ""; fi ) # TODO: this replacement is hardcoded
            replaceArea=${replaceArea/"$code"/"$replacecode"}
            cols[fromX]=${replaceArea}${cols[$fromX]:${fromZ}+1}
            rows[fromY]="" # reset
            for (( xcol=0; xcol<${#cols[@]}; xcol++ )); do
                rows[fromY]+=$( printf "%s," "${cols[$xcol]}" )
            done
        fi
        return 0
    }
    remove;


    # # reconstruct
    local -t rebuild="MAZE_META:${xMax}x${yMax}yMAZE:"
    
    for (( yline=0 ; yline<${#rows[@]}; yline++ )); do
        rebuild+=$( printf "%s:" "${rows[$yline]}" )
    done

    if ! [[ "$state" =~ $( generateMatchers "ENTITIES" ) ]]; then
        echoerr "Cannot add entity '$entity'"
        echo "$state"
        return 1
    fi
    if [[ "$mode" = "--new" ]]; then
        entity=${entity/[[:digit:]]z/${zCoord}z}
        rebuild+="ENTITIES:${entity},${BASH_REMATCH[1]:-""}"
    elif [[ "$mode" = "--move" ]]; then
        local wholeEntities=${BASH_REMATCH[0]}
        local -r newEntity=$( makeMapItem "$xCoord" "$yCoord" "$zCoord" "$code" )
        rebuild+="${wholeEntities/${entity},/}${newEntity},"
    else
        echoerr "$usageString"
        echoerr "A --new code must match '$allowedEntities' and an entity to --move must match '$entityMatcher'"
        echo "$state"
        return 1
    fi
    
    echo "$rebuild"
    return 0
}

function mohsMap {
    if [[ $# -ne 1 ]]; then
        echo "0"
        return 1
    fi
    case $1 in
        "█")
            echo "10"
        ;;
        " ")
            echo "0"
        ;;
        "#")
            echo "2"
        ;;
        "@")
            echo "1"
        ;;
        "V")
            echo "3"
        ;;
        "M")
            echo "9"
        ;;
        "W")
            echo "8"
        ;;
        *)
            echo "0"
        ;;
    esac
    return 0
}

function makeMapItem {
    if [[ $# -ne 4 ]]; then
        echoerr "There must be at least four arguments: xCoordinate, yCoordinate, zCoordinate, and code"
        exit 2
    fi
    if ! [[ $1 =~ ^[[:digit:]]+$ ]]; then
        echoerr "The x coordinate must be a number, not '$1'"
        exit 2
    fi
    if ! [[ $2 =~ ^[[:digit:]]+$ ]]; then
        echoerr "The y coordinate must be a number, not '$2'"
        exit 2
    fi
    if ! [[ $3 =~ ^[[:digit:]]+$ ]]; then
        echoerr "The z coordinate must be a number, not '$3'"
        exit 2
    fi
    if ! [[ ${#4} -eq 1 && $4 =~ ^[[:print:]]$ ]]; then
        echoerr "The code must be only one printable character, not the ${#2} from '$2'"
        exit 2
    fi

    mapItem="${1}x${2}y${3}z${4}"
    local -r matcher=$( generateMatchers "ENTITY_MATCHER" )
    if ! [[ "$mapItem" =~ $matcher ]]; then
        echoerr "The mapItem '$mapItem' does not follow the regex '$matcher'"
        return 1
    fi
    echo "$mapItem"
    return 0
}

function drawMap() {
    if [[ $# -ne 1 ]]; then
        echoerr "Expecting only one argument that is the string of the map state"
        echoerr "But found: '$*'"
        return 1
    fi
    if ! verifyMapState "$1"; then
        echoerr "Expecting only one argument that is the string of the map state"
        verifyMapState "$1" --diagnose
        return 1
    fi
    if ! [[ "$1" =~ $( generateMatchers "MAZE" ) && ${#BASH_REMATCH[@]} -ge 2 ]]; then
        echoerr "Weird, the state was verified but cannot be captured"
        echoerr "The state was '$1'"
        return 1
    fi
    local -r mapSource=${BASH_REMATCH[1]:-""}
    local -a mazeRows
    readarray -t -d ":" mazeRows < <( echo "$mapSource" )

    local -t drawn=""
    for row in "${mazeRows[@]}"; do
        local -a cols
        readarray -t -d "," cols < <( echo "$row" )
        for col in "${cols[@]}"; do
            drawn+=$( if [[ ${#col} -eq 0 ]]; then echo " "; else echo "${col: -1:1}"; fi )
        done
        drawn+=$'\n'
    done
    echo -e "$drawn"
}

function makeSimpleMove() {
    local -r usageString="Usage: makeSimpleMove 'state' 'entityToMove' [--direction dir] 'targetEntities'... "
    local -r entityMatcher=$( generateMatchers "ENTITY_MATCHER" )
    if [[ $# -lt 2 ]]; then
        echoerr "$usageString"
        return 2
    elif ! verifyMapState "$1"; then
        echoerr "$usageString"
        verifyMapState "$1" --diagnose
        return 2
    elif ! [[ "$2" =~ $entityMatcher ]]; then
        echoerr "$usageString"
        echoerr "The argument for 'entityToMove' should match '$entityMatcher' but you provided '$2'"
        return 2
    fi
    local -r mappy="$1"
    local -r -t entity="$2"
    local -r myCode=${BASH_REMATCH[4]}
    local -r -i myX=${BASH_REMATCH[1]}
    local -r -i myY=${BASH_REMATCH[2]}
    shift
    shift

    if [[ $# -lt 1 ]]; then
        echo "$mappy"
        return 0
    elif [[ "$myCode" =~ ^[@█W]$|^[[:space:]]$ ]]; then
        echo "$mappy"
        return 1
    fi

    if [[ "$1" = "--direction" && "$2" =~ $( generateMatchers "ALLOWED_MOVES" ) ]]; then
        case "$2" in
            W|w|1)
                placeEntity "$mappy" "$myX" $(( myY - 1 )) --move "$entity"
                return $?
            ;;
            A|a|2)
                placeEntity "$mappy" $(( myX - 1 )) "$myY" --move "$entity"
                return $?
            ;;
            S|s|3)
                placeEntity "$mappy" "$myX" $(( myY + 1 )) --move "$entity"
                return $?
            ;;
            D|d|4)
                placeEntity "$mappy" $(( myX + 1 )) "$myY" --move "$entity"
                return $?
            ;;
            r)
                echo "$mappy"
                return 7
            ;;
            q)
                echo "Ending the game!"
                exit 7
            ;;
        esac
    fi

    local -t targetEntity=""
    local -t -i targetDist=-1
    local -i targetX=-1
    local -i targetY=-1

    for checkTarget in "$@"; do
        if ! [[ "$checkTarget" =~ $entityMatcher ]]; then
            continue;
        fi
        local -t checkCode=${BASH_REMATCH[4]}
        local -i checkX=${BASH_REMATCH[1]}
        local -i checkY=${BASH_REMATCH[2]}
        if [[ "$myCode" = "$checkCode" ]]; then
            continue;
        elif [[ "$myCode" = "#" && "$checkCode" != "@" ]]; then
            continue
        elif [[ "$myCode" =~ ^[VM]$ && "$checkCode" != "#" ]]; then
            continue
        fi
        local -i checkDist
        checkDist=$(( (checkX - myX)**2 + (checkY - myY)**2 )) # how far is it from the entity
        if [[ $targetDist -lt 0 || $checkDist -lt $targetDist ]]; then
            targetEntity="$checkTarget"
            targetDist=$checkDist
            targetX=$checkX
            targetY=$checkY
            if [[ $targetDist -eq 0 ]]; then
                echo "$mappy"
                return 0 # can't get much closer than zero, so leave
            fi
        fi
    done

    if [[ "$targetEntity" = "" || $targetDist -le 0 ]]; then
        echo "$mappy"
        return 0
    fi

    local -i -r xDiff=$(( targetX - myX ))
    local -i -r yDiff=$(( targetY - myY ))

    if [[ $yDiff -eq 0 ]]; then
        if [[ $xDiff -gt 0 ]]; then
            placeEntity "$mappy" $(( myX + 1 )) "$myY" --move "$entity"
            return $?
        else # should not need an -eq 0 case
            placeEntity "$mappy" $(( myX - 1 )) "$myY" --move "$entity"
            return $?
        fi
    elif [[ $xDiff -eq 0 ]]; then
        if [[ $yDiff -gt 0 ]]; then
            placeEntity "$mappy" "$myX" $(( myY + 1 )) --move "$entity"
            return $?
        else # should not need an -eq 0 case
            placeEntity "$mappy" "$myX" $(( myY - 1 )) --move "$entity"
            return $?
        fi
    else
        if [[ 0 -eq $( randomGenerator 2 ) ]]; then
            if [[ $xDiff -gt 0 ]]; then
                placeEntity "$mappy" $(( myX + 1 )) "$myY" --move "$entity"
                return $?
            else # should not need an -eq 0 case
                placeEntity "$mappy" $(( myX - 1 )) "$myY" --move "$entity"
                return $?
            fi
        else
            if [[ $yDiff -gt 0 ]]; then
                placeEntity "$mappy" "$myX" $(( myY + 1 )) --move "$entity"
                return $?
            else # should not need an -eq 0 case
                placeEntity "$mappy" "$myX" $(( myY - 1 )) --move "$entity"
                return $?
            fi
        fi
    fi    

}

function checkGoal() {
    local -r entityMatcher=$( generateMatchers "ENTITY_MATCHER" )
    if ! [[ "$1" =~ $entityMatcher ]]; then
        echoerr "Expected a single entity, and then a list of target entities, all matching '$entityMatcher'"
        echoerr "Recieved '$*'"
        return 2
    fi
    # local -r mainEntity=$1
    local -t -r code=${BASH_REMATCH[4]}
    local -i -r myX=${BASH_REMATCH[1]}
    local -i -r myY=${BASH_REMATCH[2]}
    shift

    if [[ "$code" =~ ^[@█W]$|^[[:space:]]$ ]]; then # only players and monsters care about the goals
        echo ""
        return 1
    fi

    for other in "$@"; do
        if ! [[ "$other" =~ $entityMatcher ]]; then
            continue
        fi
        local -t otherCode=${BASH_REMATCH[4]}
        local -i otherX=${BASH_REMATCH[1]}
        local -i otherY=${BASH_REMATCH[2]}
        if [[ "$code" = "$otherCode" ]]; then
            continue;
        fi
        case "$code" in
            "#")
                if [[ "$otherCode" = "@" && $myX -eq $otherX && $myY -eq $otherY ]]; then
                    echo "Player advances to next round!"
                    return 0
                fi
            ;;
            "V"|"M")
                if [[ "$otherCode" = "#" && $myX -eq $otherX && $myY -eq $otherY ]]; then
                    echo "$code got you!  Restarting level...."
                    return 0
                fi
            ;;
        esac
    done
    echo ""
    return 1
}

function makeEntitySet() {
    local -r usageString="Usage: makeEntitySet 'mapState' [level]"
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        echoerr "$usageString"
        return 1
    fi
    if ! verifyMapState "$1"; then
        echoerr "$usageString"
        verifyMapState "$1" --diagnose
        return 1
    fi
    local -t map="$1"
    if ! [[ "$map" =~ $( generateMatchers "MAP_META" ) ]]; then
        echoerr "$usageString"
        verifyMapState "$map" --diagnose
        return 1
    fi
    local -i -r mapMaxX=${BASH_REMATCH[1]}
    local -i -r mapMaxY=${BASH_REMATCH[2]}
    local -i -r forLevel=$( if [[ $# -eq 2 && "$2" -ge 0 && "$2" =~ ^[[:digit:]]$ ]]; then echo "$2"; else echo "1"; fi )
    
    local -r allowedEntities=$( generateMatchers "ALLOWED_ENTITIES" )

    function randomDraw() {
        local -n myMap=map
        if ! [[ "$1" =~ $allowedEntities ]]; then
            echoerr "'$1' is not one of the allowed entities '$allowedEntities'"
            return 1
        fi
        local -r code="$1"
        local -i attempts=7
        for (( attempts=7 ; attempts > 0; attempts-- )); do
            local -i randX; local -i randY;
            randX=$( randomGenerator $(( mapMaxX - 2 )) )+1
            randY=$( randomGenerator $(( mapMaxY - 2 )) )+1
            
            if myMap=$( placeEntity "$myMap" "$randX" "$randY" --new "$code" ); then
                return 0
            fi
        done
        if [[ $attempts -le 0 ]]; then
            echoerr "Could not place $code on the map:"
            echoerr -e "$myMap"
            return 1
        fi
    }

    for ((mum=(forLevel / 5); mum > 0; mum--)); do
        randomDraw "M"
    done

    for ((vee=forLevel; vee > 0; vee--)); do
        randomDraw "V"
    done

    if ! randomDraw "#"; then
        echoerr "${map}"
        exit 2
    fi

    if ! randomDraw "@"; then
        echoerr "${map}"
        exit 2
    fi


    echo "${map}"
    return 0
}

function playerMove() {
    local -i -r randomChoice=$( randomGenerator 4 )+1
    local -r allowedMoves='^[wasdWASD1234rq]$'
    local move=""
    while { read -r -t 60 -p "Your move:>" move; move=${move:="$randomChoice"}; ! [[ "$move" =~ $allowedMoves ]]; }; do
        echo "Your move must be one of $allowedMoves"
    done
    echo "$move"
    return 0
}

function runLevel() {
    if ! verifyMapState "$1" --diagnose ; then
        echoerr "Expecting map state, need it!"
        exit 1
    fi
    local map="$1"
    local -r entitiesMatcher=$( generateMatchers "ENTITIES" )
    local -r entityMatcher=$( generateMatchers "ENTITY_MATCHER" )
    local -a entities
    local -i round=0
    local -i -r roundMax=100

    function readEntities {
        if ! [[ "$map" =~ $entitiesMatcher && ${#BASH_REMATCH[@]} -ge 2 && ${#BASH_REMATCH[1]} -ge 0 ]]; then
            echoerr "Cannot retrieve entities from state: '$map'"
            exit 1
        fi
        IFS="," read -r -d '' -a entities < <( printf "%s\0" "${BASH_REMATCH[1]}" )
        return 0
    }

    local -i turn=0
    while readEntities && [[ 0 -lt ${#entities[@]} && $round -le $roundMax ]]; do
        if [[ $turn -eq ${#entities[@]} ]]; then
            turn=0
            round=$round+1
        fi
        local thing="${entities[$turn]}"
        if ! [[ "$thing" =~ $entityMatcher ]]; then
            echoerr "This '$thing' is somehow not an entity ( from '${BASH_REMATCH[0]}')"
            exit 1
        fi

        local code="${BASH_REMATCH[4]}"
        if [[ "$code" = "#" ]]; then
            drawMap "$map"
            move=$( playerMove )
            if [[ "$move" = "q" ]]; then
                echo "Exiting the game...thank you for playing"
                exit 8
            elif [[ "$move" = "r" ]]; then
                echo "Not yet implemented"
            else
                map=$( makeSimpleMove "$map" "$thing" --direction "$move" "${entities[@]}" )               
            fi
        else
            map=$( makeSimpleMove "$map" "$thing" "${entities[@]}" )
        fi

        if goalMessage=$( checkGoal "$thing" "${entities[@]}" ); then
            echo "$goalMessage"
            return 0
        fi

        (( turn++ ))
    done
    return 1
}


function main() {
    if [[ $# -gt 0 && "$1" = "--loadtest" ]]; then
        echo "Loading for test"
        return 0
    fi
    local -i mapMaxX=5 #50
    local -i mapMaxY=5 # 20
    local -i fill=0 #20
    local theWalls=""

    local -i level=0

    for (( level=0; level<=100; level++ )); do
        echo "Level $level ********************************************************"
        initWalls $mapMaxX $mapMaxY $fill theWalls
        theWalls=$( makeEntitySet "$theWalls" "$level" )
        runLevel "$theWalls" "$level"
    done
    echo "Congrats, you have won 100 levels!"
    return 0
}
main "$@"


# echo "'$theWalls'"
# makeMapItem "V" 2
# vee=$( makeMapItem "V" 2 )
# echo ${vee["mohs"]}