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
    local -r MASTER_MAP_STATE_MATCHER="MAZE_META:([[:digit:]]+)x([[:digit:]]+)yMAZE:((((█?,|@?#?V?W?M?,)*):)*)ENTITIES:(([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)*)"
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
        "ALLOWED_ENTITIES")
            selected="[@#VM]"
        ;;
        "ENTITY_MATCHER")
            selected="([[:digit:]]+)x([[:digit:]]+)y([[:digit:]]+)z([@#VM])"
        ;;
        "ENTITIES_LIST_MATCHER")
            selected="ENTITIES:(([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)?(([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)*))"
        ;;
        "MAP_META")
            selected="MAZE_META:([[:digit:]]+)x([[:digit:]]+)y"
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

function verifyMapState {
    local -i printsuccess=0
    local state=""
    if [[ $# -gt 2 || $# -lt 1 || ( $# -eq 2 && $1 != "--printsuccess" )]]; then
        echoerr "usage: [--printsuccess] state"
        return 2
    fi
    if [[ $# -eq 2 && $1 = "--printsuccess" ]]; then
        printsuccess=1
        shift
    fi
    local -r state=$1
    local matcher; matcher=$( generateMatchers "MAP_STATE_MATCHER" )
    if ! [[ "$state" =~ $matcher ]]; then
        echoerr "Failed general match"
        echoerr "Matcher: $matcher"
        echoerr "Failed in some other way:"
        for ((i=0; i < ${#BASH_REMATCH[@]}; i++)); do
            echoerr -e "\t$i: ${BASH_REMATCH[$i]}"
        done
        return 1
    fi
    if [[ $printsuccess -ne 0 ]]; then
        echo "Success!"
        echo "Success State: $state"
        echo "Success Matcher: $matcher"
        echo "Success rematch:"
        for ((i=0; i < ${#BASH_REMATCH[@]}; i++)); do
            echo -e "\t$i: ${BASH_REMATCH[$i]}"
        done
    fi
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

    if [[ $# -ge 4 ]]; then
        local -n wally=$4
        wally="ENTITIES:MAZE_META:${mapMaxX}x${mapMaxY}yMAZE:"
    else
        local wally
        wally="ENTITIES:MAZE_META:${mapMaxX}x${mapMaxY}yMAZE:"
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

    local -r matcher=$( generateMatchers )
    if ! [[ "$wally" =~ $matcher ]]; then
        echo -e "$wally"
        echoerr "Did not produce good map state"
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
    if ! verifyMapState "$1" ; then
        echoerr "Not a good state"
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
        echo "$state"
        return 1
    fi

    if ! [[ "$state" =~ $( generateMatchers "MAZE" ) && ${#BASH_REMATCH[@]} -ge 2 ]]; then
        echoerr "Cannot find the maze"
        echo "$state"
        return 1
    fi
    local maze=${BASH_REMATCH[1]}
    IFS=":" read -r -d '' -a rows < <( printf "%s\0" "$maze" )
    if [[ $yCoord -ge ${#rows[@]} ]]; then
        echo "$state"
        return 1
    fi

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
            if [[ $fromX -ge $xMax || $fromY -ge $yMax || $fromX -le 0 || $fromY -le 0 || $fromZ -le 0 ]]; then
                echoerr "Cannot remove entity '$entity' from out of bounds"
                return 1
            fi
            unset cols
            IFS="," read -r -d '' -a cols < <( printf "%s\0" "${rows[$fromY]}" )
            local replaceArea=${cols[$fromX]:0:${fromZ}+1}
            local -r replacecode=$( if [[ "$code" = "M" ]]; then echo "W"; else echo ""; fi ) # TODO: this replacement is hardcoded
            replaceArea=${replaceArea/$code/$replacecode}
            cols[fromX]=${replaceArea}${cols[$fromX]:${fromZ}+1}
            for (( xcol=0; xcol<${#cols[@]}; xcol++ )); do
                rows[yCoord]+=$( printf "%s," "${cols[$xcol]}" )
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

    if ! [[ "$state" =~ $( generateMatchers "ENTITIES_LIST_MATCHER" ) ]]; then
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
        rebuild+=${wholeEntities/"${entity}"/"${newEntity}"}
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
    if [[ $# -lt 4 ]]; then
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
    local -r matcher=$( generateMatchers "MAP_STATE_MATCHER" )
    if [[ $# -eq 1 ]]; then
        echoerr "Expecting only one argument that is the string of the map state, like the following: $matcher"
        echoerr "But found: '$*'"
        return 1
    fi
    if ! verifyMapState "$1"; then
        echoerr "Expecting the string of the map state, like the following: $matcher"
        echoerr "But found: '$*'"
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
    local -r usageString="Usage: makeSimpleMove 'state' 'entityToMove' 'targetEntities'... "
    local -r entityMatcher=$( generateMatchers "ENTITY_MATCHER" )
    if [[ $# -lt 2 ]]; then
        echoerr "$usageString"
        return 2
    elif ! verifyMapState "$1"; then
        echoerr "$usageString"
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
            moveEntity "$mappy" "$myX" $(( myY + 1 )) --move "$entity"
            return $?
        else # should not need an -eq 0 case
            moveEntity "$mappy" "$myX" $(( myY - 1 )) --move "$entity"
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
                moveEntity "$mappy" "$myX" $(( myY + 1 )) --move "$entity"
                return $?
            else # should not need an -eq 0 case
                moveEntity "$mappy" "$myX" $(( myY - 1 )) --move "$entity"
                return $?
            fi
        fi
    fi    

}

function checkGoal() {
    local -r mainEntity=$1
    shift
    local -t code
    code=$( retriveMapItemAttribute "$mainEntity" "code" ) || { echo ""; return 1; }

    if [[ "$code" =~ ^[@█W]$|^[[:space:]]$ ]]; then # only players and monsters care about the goals
        echo ""
        return 1
    fi

    local -i myX
    local -i myY
    myX=$( retriveMapItemAttribute "$mainEntity" "x" ) || { echo ""; return 1; }
    myY=$( retriveMapItemAttribute "$mainEntity" "y" ) || { echo ""; return 1; }

    for other in "$@"; do
        local -t otherCode
        otherCode=$( retriveMapItemAttribute "$other" "code" ) || continue;
        if [[ "$code" = "$otherCode" ]]; then
            continue;
        fi
        local -i otherX
        local -i otherY
        otherX=$( retriveMapItemAttribute "$other" "x" ) || continue;
        otherY=$( retriveMapItemAttribute "$other" "y" ) || continue;
        case "$code" in
            "#")
                if [[ "$otherCode" = "@" && $myX -eq $otherX && $myY -eq $otherY ]]; then
                    echo "#"
                    return 0
                fi
            ;;
            "V"|"M")
                if [[ "$otherCode" = "#" && $myX -eq $otherX && $myY -eq $otherY ]]; then
                    echo "$code"
                    return 0
                fi
            ;;
        esac
    done
    echo ""
    return 1
}

function makeEntitySet() {
    local -t map=$1
    local -i -r forLevel=$( [ "$2" -ge 0 ] && echo "$2" || echo "1" )
    local -i -r mapMaxX=$3
    local -i -r mapMaxY=$4

    local -a entities=()


    function randomDraw() {
        local -n myMap=map
        local -i -r mohs=$1
        local -r code=$2
        local -r replace=$( [[ $# -ge 3 && "$3" =~ ^[[:print:]]$ ]] && echo "$3" || echo " " )
        local -i drawn=1
        for (( drawn=7 ; drawn > 0; drawn-- )); do
            local -i randX; local -i randY;
            randX=$( randomGenerator $(( mapMaxX - 2 )) )+1
            randY=$( randomGenerator $(( mapMaxY - 2 )) )+1
            local entity
            entity=$( makeMapItem "$randX" "$randY" "$mohs" "$code" "$replace" )
            
            if entity=$( moveEntity "$map" "$entity" "$randX" "$randY" ); then
                entities+=("$entity")
                myMap=$( drawMap "$map" "$mapMaxX" "${entities[@]}" )
                break
            fi
        done
        if [[ $drawn -le 0 ]]; then
            echoerr "Could not place $code on the map:"
            echoerr -e "$myMap"
            return 1
        fi
    }

    for ((mum=(forLevel / 5); mum > 0; mum--)); do
        randomDraw 9 "M" "W"
    done

    for ((vee=forLevel; vee > 0; vee--)); do
        randomDraw 3 "V"
    done

    if ! randomDraw 2 "#"; then
        echoerr "${entities[@]}"
        exit 2
    fi

    if ! randomDraw 1 "@"; then
        echoerr "${entities[@]}"
        exit 2
    fi


    echo "${entities[@]}"
    return 0
}


function main() {
    local -i mapMaxX=50
    local -i mapMaxY=20
    local -i fill=20
    local theWalls=""

    initWalls $mapMaxX $mapMaxY $fill theWalls

    echo -e "$theWalls"
}


# echo "'$theWalls'"
# makeMapItem "V" 2
# vee=$( makeMapItem "V" 2 )
# echo ${vee["mohs"]}