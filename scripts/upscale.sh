#!/bin/bash

# This file is part of video2d-2x.
#
# video2d-2x is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

source "$Waifu2xConf"

readonly TmpFramesDir="${FramesDir}_tmp"
readonly RowTemplate="\r%-8s%-8s%-12s%-8s%-8s\n"

function upscale_mode () # $1: ScaleRatio, $2: NoiseLevel
{
	local ScaleRatio="$1"
	local NoiseLevel="$2"
	
	if [[ "$ScaleRatio" -ne 1 ]] && [[ -n "$NoiseLevel" ]]; then
		echo "noise_scale"
		return 0
	fi
	if [[ "$ScaleRatio" -eq 1 ]] && [[ -n "$NoiseLevel" ]]; then
		echo "noise"
		return 0
	fi
	if [[ "$ScaleRatio" -ne 1 ]] && [[ -z "$NoiseLevel" ]]; then
		echo "scale"
		return 0
	fi
	return 1
}

function upscale_images () # $1: InputDir, $2: OutputDir, $3: ProgressBarPID, $4: ParentPID
{
	waifu2x-caffe-cui \
		--mode "$UpscaleMode" \
		--scale_ratio "$ScaleRatio" \
		--output_depth "$OutputDepth" \
		--noise_level "$NoiseLevel" \
		--tta "$TtaMode" \
		--gpu "$GpuNum" \
		--process "$Process" \
		--crop_size "$CropSize" \
		--batch_size "$BatchSize" \
		--model_dir "$(model_path $Model)" \
		--input_path "$1" \
		--output_path "$2" \
		> /dev/null
	local RT=$?
	kill "$3" 2> /dev/null
	if [[ "$RT" -ne 0 ]]; then
		kill -1 "$4" 2> /dev/null
	fi
}

function progress_bar ()
{
	local PreviousUpscaledFrame=""
	local LastUpscaledFrame=""
	local Total=$(png_num $LastOriginalFrame)
	while [[ "$LastUpscaledFrame" != "$LastOriginalFrame" ]]
	do
		LastUpscaledFrame=$(ls "$FramesUpscaledDir" | sort | tail -n 1)
		if [[ "$PreviousUpscaledFrame" != "$LastUpscaledFrame" ]]; then
			local Done=$(png_num $LastUpscaledFrame)
			printf "\r[%3d%%] %d/%d" "$(($Done*100/$Total))" "$Done" "$Total"
			PreviousUpscaledFrame="$LastUpscaledFrame"
		fi
		sleep 1
	done
}

if ! [[ -r "$RangesList" ]]; then
	echo "Read file error: \"$RangesList\""
	exit "$FILE_READ_ERROR"
fi

if ! check_ranges; then
	exit "$RANGES_LIST_SYNTAX_ERROR"
fi

rm -rf "$TmpFramesDir"
mkdir -p "$FramesUpscaledDir"

LastOriginalFrame=$(ls "$FramesDir" | sort | tail -n 1)
LastUpscaledFrame=$(ls "$FramesUpscaledDir" | sort | tail -n 1)

if [[ "$LastUpscaledFrame" == "$LastOriginalFrame" ]]; then
	echo "WARN: Upscaled frames already exists - skip."
	exit "$SUCCESS"
fi

LastUpscaledFrame=$(png_num "$LastUpscaledFrame")

printf "${BLD}$RowTemplate${DEF}" "START" "END" "MODE" "NOISE" "ACTION"
while read Line
do
	if [[ -z "$Line" ]]; then
		continue
	fi
	
	RangeInfo=($Line)
	StartFrame=$(png_num ${RangeInfo[0]})
	EndFrame=$(png_num ${RangeInfo[1]})
	NoiseLevel=$(png_num ${RangeInfo[2]})

	UpscaleMode=$(upscale_mode "$ScaleRatio" "$NoiseLevel")
	
	if [[ -z "$NoiseLevel" ]]; then
		NoiseLevel="0"
		NoiseLevelDisplay="-"
	else
		NoiseLevelDisplay="$NoiseLevel"
	fi
	
	clean_line
	if [[ -n "$LastUpscaledFrame" ]] && [[ "$LastUpscaledFrame" -ge "$EndFrame" ]]; then
		printf "$RowTemplate" "$StartFrame" "$EndFrame" "$UpscaleMode" "$NoiseLevelDisplay" "SKIP"
		continue
	fi
	
	if [[ -n "$LastUpscaledFrame" ]] && [[ "$StartFrame" -lt "$LastUpscaledFrame" ]]; then
		printf "$RowTemplate" "$StartFrame"        "$(($LastUpscaledFrame-1))" "$UpscaleMode" "$NoiseLevelDisplay" "SKIP"
		printf "$RowTemplate" "$LastUpscaledFrame" "$EndFrame"                 "$UpscaleMode" "$NoiseLevelDisplay" "CONTINUE"
		# if waifu2x-caffe was interrupted while saving the file, a corrupted file is saved 
		# so it's better to start by overwriting the last upscaled file
		StartFrame="$LastUpscaledFrame"
	else
		printf "$RowTemplate" "$StartFrame" "$EndFrame" "$UpscaleMode" "$NoiseLevelDisplay"
	fi
	
	rm -rf "$TmpFramesDir"
	mkdir "$TmpFramesDir"

	echo -ne "\rCopying range..."
	CopyList=""
	for (( i=StartFrame; i <= EndFrame; i++))
	do
		CopyList+="$(printf "%06d" $i).png "
	done
	
	pushd "$FramesDir" > /dev/null
	cp $CopyList "$TmpFramesDir"
	popd > /dev/null
	
	clean_line
	
	(progress_bar) &
	ProgressBarPID=$!
	
	(upscale_images "$TmpFramesDir" "$FramesUpscaledDir" "$ProgressBarPID" "$$") &
	Waifu2xPID=$!

	trap "kill $ProgressBarPID 2> /dev/null; exit $WAIFU2X_ERROR" HUP
	trap "kill $Waifu2xPID $ProgressBarPID 2> /dev/null; echo -e '\nInterrupted'; exit $INTERRUPT" INT
	wait 2> /dev/null
	
	rm -rf "$TmpFramesDir"
done < <(cat "$RangesList"; echo) # make bash not skip the last line (if there is no empty line at the end)
