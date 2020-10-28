#!/bin/bash

Symbols=16

function HammingDistance () # $1: Prev, $2: Current
{
	local Dist=0
	local PrevPart
	local CurrentPart
	for (( i=1; i<=$Symbols; i++ ))
	do
		PrevPart=$((16#$(echo "$1" | cut -c "$i")))
		CurrentPart=$((16#$(echo "$2" | cut -c "$i")))
		Offset=$(echo $((PrevPart-CurrentPart)) | sed 's|-||')
		((Dist+=Offset))
	done
	echo "$Dist"
}

HashList="./hash.list"
PrevHash=$(printf "%0${Symbols}s" "")
:> "$HashList"

find "$FramesDir" -type f -printf "%f\n" | \
while read Image
do
	Hash=$(./dependencies/go-perceptualhash/go-perceptualhash.exe --bits 8 --digest -f "$FramesDir/$Image")
	Distance=$(HammingDistance "$PrevHash" "$Hash")
	PrevHash="$Hash"
	echo -e "$Image\t$Hash\t$Distance"
	echo -e "$Image\t$Hash\t$Distance" >> "$HashList"
done
