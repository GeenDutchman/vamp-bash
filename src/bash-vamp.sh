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

function detectWidth() {
    local -t -r toDetect=$1
    local -t -a split
    readarray -t split < <(echo -e "$toDetect")
    local -i width=${#split[0]}
    for line in "${split[@]}"; do
        if [[ ${#line} -ne $width ]]; then
            echoerr "Inconsistent widths in $toDetect"
            echo $width
            return 2
        fi
    done
    echo $width
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
    local -i myX
    local -i myY
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