#! /bin/bash

echoerr() { echo "$@" 1>&2; }

# shellcheck disable=SC2120 # optional parameter
function randomGenerator {
    local max=100
    if [[ $# -gt 0  && "$1" =~ ^0*[1-9][0-9]*$ ]]; then
        max=$1
    fi
    result=$(( RANDOM % max )) # this will do between 0-99 inclusive
    echo $result
}


function initWalls {
    if [[ $# -le 3 ]]; then
        echoerr "Need arguments of 'mapMaxX', 'mapMaxY', and 'fill'. They all need to be positive integers."
        return 1
    fi
    if ! [[ $1 =~ ^[[:digit:]]+$ && $2 =~ ^[[:digit:]]+$ && $3 =~ ^[[:digit:]]+$ ]]; then
        echoerr "The arguments for 'mapMaxX', 'mapMaxY', and 'fill' should be positive integers, not '$1', '$2', and '$3'"
        return 1
    fi
    if [[ $# -ge 4 ]]; then
        local -n wally=$4
        wally=""
    else
        local wally
        wally=""
    fi
    
    for (( y = 0; y <= mapMaxY; y++)); do
        for (( x = 0; x <= mapMaxX; x++ )); do
            if [[ $y -eq 0 || $y -eq $mapMaxY ]]; then
                wally+="█"
            elif [[ $x -eq 0 || $x -eq $mapMaxX ]]; then
                wally+="█"
            elif [[ $fill -ge $(randomGenerator) ]]; then
                wally+="█"
            else
                wally+=" "
            fi
        done
        wally+="\n"
    done

    if [[ $# -lt 4 ]]; then
        echo -e "$wally"
    fi
    return 0
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
    translateMaxX=$1
    shift

    if [[ $1 = "toFlat" && $# -ge 3 && $2 =~ ^[[:digit:]]+$ && $3 =~ ^[[:digit:]]+$ ]]; then
        local -r -i rowOffset=$(( (translateMaxX + 2) * $3 ))
        local -r -i consolidated=$(( rowOffset + $2 ))
        echo "$consolidated"
        return 0
    elif [[ $1 = "toCartesian" && $# -ge 2 && $2 =~ ^[[:digit:]]+$ ]]; then
        local -r -i yCoord=$(( $2 / (translateMaxX + 2) ))
        local -r -i xCoord=$(( $2 % (translateMaxX + 2) ))
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
        echoerr "Unrecognized attribute '$2'"
        return 1
    fi
}

function drawMap() {
    if [[ $# -lt 2 ]]; then
        echoerr "Expecting the string of the map, the width of the map, and the set of entities to draw"
        return 1
    fi
    local -r mapSource=$1
    shift
    if ! [[ $1 =~ ^[[:digit:]]+$ ]]; then
        echoerr "The width of the map must be a number"
        return 1
    fi
    local -r -i mapWidth=$1
    shift

    local drawn=""
    for entity in "$@"; do
        entityX=$( retriveMapItemAttribute "$entity" "x" ) || return $?
        entityY=$( retriveMapItemAttribute "$entity" "y" ) || return $?
        flat=$( translateCoordinate $mapWidth "toFlat" "$entityX" "$entityY" ) || return $?
        code=$( retriveMapItemAttribute "$entity" "code" ) || return $?


        if [[ $flat -lt ${#drawn} ]]; then
            drawn=${drawn:0:$flat}${code}${drawn:$flat+1} # replace
        else
            drawLen=${#drawn}
            drawn+=${mapSource:$drawLen:$flat-$drawLen}${code}
        fi
        
    done

    if [[ ${#drawn} -lt ${#mapSource} ]]; then
        drawn+=${mapSource:${#drawn}:${#mapSource}-${#drawn}}
    fi

    echo -e "$drawn"
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