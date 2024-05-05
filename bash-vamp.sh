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
    echo "Building map of $mapMaxX x $mapMaxY with a fill of $fill"
    for (( y = 0; y <= mapMaxY; y++)); do
        for (( x = 0; x <= mapMaxX; x++ )); do
            if [[ $y -eq 0 || $y -eq $mapMaxY ]]; then
                theWalls+="█"
            elif [[ $x -eq 0 || $x -eq $mapMaxX ]]; then
                theWalls+="█"
            elif [[ $fill -ge `randomGenerator` ]]; then
                theWalls+="█"
            else
                theWalls+=" "
            fi
        done
        theWalls+="\n"
    done
}
initWalls

echo -e "$theWalls"


# declare -r CODE="code"
# declare -r MOHS="mohs"

# function makeMapItem {
#     if [[ $# -lt 4 ]]; then
#         echoerr "There must be at least four arguments: code, mohs, x, and y"
#         exit 2
#     fi
#     if [[ ${#1} -gt 1 ]]; then
#         echoerr "The code must be only one character, not the ${#1} from '$1'"
#         exit 2
#     fi
#     if [[ $2 =~ [^0-9] ]]; then
#         echoerr "The mohs must be a number, not '$2'"
#         exit 2
#     fi
#     if [[ $3 =~ [^0-9] || $4 =~ [^0-9] ]]; then
#         echoerr "The X and Y must be numbers, not '$3' and '$4'!"
#         exit 2
#     fi
#     declare -A mapItem=(["$CODE"]=$1 ["$MOHS"]=$2)
#     echo ${mapItem[@]}
# }


# echo "'$theWalls'"
# makeMapItem "V" 2
# vee=$( makeMapItem "V" 2 )
# echo ${vee["mohs"]}