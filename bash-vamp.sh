#! /bin/bash

echoerr() { echo "$@" 1>&2; }

function randomGenerator {
    local max=100
    if [[ $# > 0  && "$1" =~ ^0*[1-9][0-9]*$ ]]; then
        max=$1
    fi
    result=$(( ($RANDOM % $max) )) # this will do between 0-99 inclusive
    echo $result
}

declare -i mapMaxX=50
declare -i mapMaxY=20
declare -i fill=20
declare theWalls=""

function initWalls {
    local -n wally=$1
    wally=""
    echo "Building map of $mapMaxX x $mapMaxY with a fill of $fill"
    for (( y = 0; y <= mapMaxY; y++)); do
        for (( x = 0; x <= mapMaxX; x++ )); do
            if [[ $y -eq 0 || $y -eq $mapMaxY ]]; then
                wally+="█"
            elif [[ $x -eq 0 || $x -eq $mapMaxX ]]; then
                wally+="█"
            elif [[ $fill -ge `randomGenerator` ]]; then
                wally+="█"
            else
                wally+=" "
            fi
        done
        wally+="\n"
    done
}
initWalls theWalls

echo -e "$theWalls"


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
    if [[ $1 =~ ^[[:digit:]]+$ ]]; then
        echoerr "The x coordinate must be a number, not '$1'"
        exit 2
    fi
    if [[ $2 =~ ^[[:digit:]]+$ ]]; then
        echoerr "The y coordinate must be a number, not '$2'"
        exit 2
    fi
    if [[ $3 =~ ^[[:digit:]]+$ ]]; then
        echoerr "The mohs must be a number, not '$3'"
        exit 2
    fi
    if [[ $4 =~ ^[[:print:]]$ ]]; then
        echoerr "The code must be only one printable character, not the ${#2} from '$2'"
        exit 2
    fi
    local replace=" "
    if [[ $# -ge 5 && ${#5} -eq 1 && $5 =~ ^[[:print:]]$ ]]; then
        replace=$5
    fi
    mapItem="$1:$2:$3:$replace"
    echo $mapItem
}

function retriveMapItemAttribute {
    if [[ $# -lt 2 ]]; then
        echoerr "There must be at least two arguments: mapItem and attribute, not '$@'"
        return 2
    fi
    echo "item'$1'"
    if ! [[ $1 =~ ^([[:digit:]]+):([[:digit:]]+):([[:digit:]]+):([[:print:]]):([[:print:]]?)$ ]]; then
        echoerr "That does not match the pattern of 'xCoord:yCoord:mohs:code:replace' (with replace being optional)"
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
    echo "Bad process for $@"
    return 2
}





# echo "'$theWalls'"
# makeMapItem "V" 2
# vee=$( makeMapItem "V" 2 )
# echo ${vee["mohs"]}