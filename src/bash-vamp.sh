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
    if [[ $# -eq 0 ]]; then
        selected="ENTITIES:([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)?(([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)*)MAZE_META:([[:digit:]]+)x([[:digit:]]+)yMAZE:((((█?,|@?#?V?W?M?,)*):)*)"
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
            selected="([@#VM])"
        ;;
        "ENTITY_MATCHER")
            selected="([[:digit:]]+)x([[:digit:]]+)y([[:digit:]]+)z([@#VM])%s"
        ;;
        "ENTITIES_LIST_MATCHER")
            selected="ENTITIES:([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)?(([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)*)"
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
            selected="ENTITIES:([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)?(([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)*)MAZE_META:([[:digit:]]+)x([[:digit:]]+)yMAZE:((((█?,|@?#?V?W?M?,)*):)*)"
        ;;
        *)
            echoerr "'$1' unkown, defaulting to MAP_STATE_MATCHER"
            selected="ENTITIES:([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)?(([[:digit:]]+x[[:digit:]]+y[[:digit:]]+z[@#VM],)*)MAZE_META:([[:digit:]]+)x([[:digit:]]+)yMAZE:((((█?,|@?#?V?W?M?,)*):)*)"
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

function placeNewEntity {
    if [[ $# -ne 4 ]]; then
        echoerr "Usage: placeNewEntity state code xCoord yCoord"
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
    shift
    if ! [[ "$1" =~ $( generateMatchers "ALLOWED_ENTITIES" ) ]]; then
        echoerr "'$1' is not an allowed entity"
        return 2
    fi
    local -r code="$1"
    local -r -i mohs=$( mohsMap "$code" )
    shift
    if [[ $1 -le 0 || $1 -ge $xMax || $2 -le 0 || $2 -ge $yMax ]]; then
        echoerr "'$1' and '$2' must be strictly inside the bounds of (0, $xMax) and (0, $yMax)"
        return 1
    fi
    local -i -r xCoord=$1
    local -i -r yCoord=$2

    local rebuild="${state/%MAZE:*}MAZE:"
    local maze=${state/#?+MAZE:/}
    local -r rowMatcher=$( generateMatchers "MAP_COLS_SEP" )
    for (( x=0;x<xCoord;x++ )); do
        if ! [[ "$maze" =~ $rowMatcher ]]; then
            echoerr "Cannot match row $x"
            return 1
        fi
        rebuild="${rebuild}${BASH_REMATCH[1]}"
        maze="${BASH_REMATCH[2]}"
    done



}

function translateCoordinate {
    local usageMessage="The first argument must be the maximum x dimension. "
    usageMessage+="Then specify either 'toFlat' or 'toCartesian' followed by two or one numbers respectively."
    if [[ $# -lt 3 ]]; then
        echoerr "$usageMessage"
        return 1
    fi
    if ! [[ $1 =~ ^[[:digit:]]+$ ]]; then
        echoerr "The maximum x dimension must be a positive integer, not '$1'"
        return 1
    fi
    local -i translateMaxX=$1
    shift

    if [[ $1 = "toFlat" && $# -ge 3 && $2 =~ ^[[:digit:]]+$ && $3 =~ ^[[:digit:]]+$ ]]; then
        local -r -i rowOffset=$(( (translateMaxX + 1) * $3 ))
        local -r -i consolidated=$(( rowOffset + $2 ))
        echo "$consolidated"
        return 0
    elif [[ $1 = "toCartesian" && $# -ge 2 && $2 =~ ^[[:digit:]]+$ ]]; then
        local -r -i yCoord=$(( $2 / (translateMaxX + 1) ))
        local -r -i xCoord=$(( $2 % (translateMaxX + 1) ))
        echo "$xCoord $yCoord"
        return 0
    else
        echoerr "$usageMessage"
        return 1
    fi
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
        echoerr "There must be at least four arguments: xCoordinate, yCoordinate, mohs, and code"
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
        echoerr "The mohs must be a number, not '$3'"
        exit 2
    fi
    if ! [[ ${#4} -eq 1 && $4 =~ ^[[:print:]]$ ]]; then
        echoerr "The code must be only one printable character, not the ${#2} from '$2'"
        exit 2
    fi
    local replace=" "
    if [[ $# -ge 5 && ${#5} -eq 1 && $5 =~ ^[[:print:]]$ ]]; then
        replace=$5
    fi
    mapItem="$1x$2:$3:$4:$replace"
    echo "$mapItem"
    return 0
}

function retriveMapItemAttribute {
    if [[ $# -lt 2 ]]; then
        echoerr "There must be at least two arguments: mapItem and attribute, not '$*'"
        return 2
    fi
    if ! [[ $1 =~ ^([[:digit:]]+)x([[:digit:]]+):([[:digit:]]+):([[:print:]]):([[:print:]]?)$ ]]; then
        echoerr "That '$1' does not match the pattern of 'xCoord:yCoord:mohs:code:replace' (with replace being optional)"
        return 2
    fi
    if [[ $2 = "code" ]]; then
        echo "${BASH_REMATCH[4]}"
        return 0
    elif [[ $2 = "mohs" ]]; then
        echo "${BASH_REMATCH[3]}"
        return 0
    elif [[ $2 = "x" || $2 = "X" ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    elif [[ $2 = "y" || $2 = "Y" ]]; then
        echo "${BASH_REMATCH[2]}"
        return 0
    elif [[ $2 = "replace" ]]; then
        local -r temp=${BASH_REMATCH[5]:-" "}
        if [[ ${#temp} -eq 0 ]]; then
            echo " "
        else
            echo "$temp"
        fi
        return 0
    else
        echoerr "Unrecognized attribute '$2' requested from '$1'"
        return 1
    fi
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
    local -r mapSource=${1#*MAZE:}
    echoerr "Maze is $mapSource"
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

function moveEntity() {
    if [[ $# -lt 2 ]]; then
        echoerr "Expecting the string of the map, the entity to move, and the x and y of the destination"
        return 1
    fi
    local -t -r mapSource=$1
    mapWidth=$(detectWidth "$mapSource") || return $?
    shift
    local -t entity=$1
    shift
    local -t -i -r nextX=$1
    shift
    local -t -i -r nextY=$1

    local -t -i entityX
    entityX=$( retriveMapItemAttribute "$entity" "x" ) || return $?
    local -t -i entityY
    entityY=$( retriveMapItemAttribute "$entity" "y" ) || return $?
    local -t -i flat
    flat=$( translateCoordinate "$mapWidth" "toFlat" "$entityX" "$entityY" ) || return $?
    local -t code
    code=$( retriveMapItemAttribute "$entity" "code" ) || return $?
    local -t -i entityMohs
    entityMohs=$( retriveMapItemAttribute "$entity" "mohs" ) || return $?


    local -t -i dest
    dest=$( translateCoordinate "$mapWidth" "toFlat" "$nextX" "$nextY" ) || return $?
    if [[ $dest -ge ${#mapSource} ]]; then
        echoerr "The destination ( '$nextX','$nextY' or '$dest' ) for the entity '$entity' is out of bounds '${#mapSource}' for '$mapSource'"
        echo "$entity"
        return 2
    fi

    local -t -i -r destMohs=$( mohsMap "$dest" )
    if [[ $destMohs -ge $entityMohs ]]; then
        echo "$entity"
        return 2 # could not move there
    fi

    local -t replacement
    replacement=$( retriveMapItemAttribute "$entity" "replace" ) || return $?
    local -t -i -r replaceMohs=$( mohsMap "$replacement" )

    local -r charThere=${mapSource:$flat:1}

    echo "${entity/${entityX}x${entityY}/${nextX}x${nextY}}"
    if [[ "$code" = "$charThere" ]]; then
        replacedItem=$(makeMapItem $entityX $entityY $replaceMohs "$replacement") || return $?
        echo "$replacedItem"
    fi
    return 0
}

function makeSimpleMove() {
    local -r mappy=$1
    shift
    local entity=$1
    shift
    local -t myCode
    local -i myX
    local -i myY
    myCode=$( retriveMapItemAttribute "$entity" "code" ) || return $?
    myX=$( retriveMapItemAttribute "$entity" "x" ) || return $?
    myY=$( retriveMapItemAttribute "$entity" "y" ) || return $?

    if [[ $# -lt 1 ]]; then
        echo "$entity"
        return 0
    fi
    local -t targetEntity=""
    local -t -i targetDist=-1
    local -i targetX=-1
    local -i targetY=-1

    for checkTarget in "$@"; do
        local -t checkCode
        checkCode=$( retriveMapItemAttribute "$checkTarget" "code" ) || continue;
        if [[ "$myCode" = "$checkCode" ]]; then
            continue;
        elif [[ "$myCode" =~ ^[@█W]$|^[[:space:]]$ ]]; then
            echo "$entity"
            return 1
        elif [[ "$myCode" = "#" && "$checkCode" != "@" ]]; then
            continue
        elif [[ "$myCode" =~ ^[VM]$ && "$checkCode" != "#" ]]; then
            continue
        fi
        local -i checkX
        local -i checkY
        local -i checkDist
        checkX=$( retriveMapItemAttribute "$checkTarget" "x" ) || continue;
        checkY=$( retriveMapItemAttribute "$checkTarget" "y" ) || continue;
        checkDist=$(( (checkX - myX)**2 + (checkY - myY)**2 )) # how far is it from the entity
        if [[ $targetDist -lt 0 || $checkDist -lt $targetDist ]]; then
            targetEntity="$checkTarget"
            targetDist=$checkDist
            targetX=$checkX
            targetY=$checkY
            if [[ $targetDist -eq 0 ]]; then
                break; # can't get much closer than 0
            fi
        fi
    done

    if [[ "$targetEntity" = "" || $targetDist -le 0 ]]; then
        echo "$entity"
        return 0
    fi

    local -i -r xDiff=$(( targetX - myX ))
    local -i -r yDiff=$(( targetY - myY ))

    if [[ $yDiff -eq 0 ]]; then
        if [[ $xDiff -gt 0 ]]; then
            moveEntity "$mappy" "$entity" $(( myX + 1 )) "$myY"
            return $?
        else # should not need an -eq 0 case
            moveEntity "$mappy" "$entity" $(( myX - 1 )) "$myY"
            return $?
        fi
    elif [[ $xDiff -eq 0 ]]; then
        if [[ $yDiff -gt 0 ]]; then
            moveEntity "$mappy" "$entity" "$myX" $(( myY + 1 ))
            return $?
        else # should not need an -eq 0 case
            moveEntity "$mappy" "$entity" "$myX" $(( myY - 1 ))
            return $?
        fi
    else
        if [[ 0 -eq $( randomGenerator 2 ) ]]; then
                    if [[ $xDiff -gt 0 ]]; then
                moveEntity "$mappy" "$entity" $(( myX + 1 )) "$myY"
                return $?
            else # should not need an -eq 0 case
                moveEntity "$mappy" "$entity" $(( myX - 1 )) "$myY"
                return $?
            fi
        else
            if [[ $yDiff -gt 0 ]]; then
                moveEntity "$mappy" "$entity" "$myX" $(( myY + 1 ))
                return $?
            else # should not need an -eq 0 case
                moveEntity "$mappy" "$entity" "$myX" $(( myY - 1 ))
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