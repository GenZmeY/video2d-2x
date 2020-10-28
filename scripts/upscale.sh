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

readonly TmpFramesDir="${FramesDir}_tmp"
readonly ColumnWidth=8
readonly RowTemplate="\r%-${ColumnWidth}s%-${ColumnWidth}s%-${ColumnWidth}s%-${ColumnWidth}s\n"

function create_default_conf ()
{
	echo "\
Process=\"cudnn\"\
GpuNum=\"0\"\
ScaleRatio=\"3\"\
OutputDepth=\"16\"\
Mode=\"noise_scale\"\
CropSize=\"256\"\
BatchSize=\"1\"\
Model=\"upresnet10\"\
TtaMode=\"0\"\
" > "$Waifu2xConf"
}

function to_int () # $1: String
{
	echo "$1" | \
	sed 's|.png||' | \
	sed -r 's|0*([1-9][0-9]*)|\1|'
}

function set_range () # $@: Line
{
	StartFrame=$(to_int "$1")
	EndFrame=$(to_int "$2")
	NoiseLevel=$(to_int "$3")
	
	return $#
}

function model_path () # $1: model name
{
	echo "$(dirname $(readlink -e $(which waifu2x-caffe-cui)))/models/$1"
}

function upscale_images () # $1: InputDir, $2: OutputDir, $3: ProgressBarPID, $4: ParentPID
{
	waifu2x-caffe-cui \
		--scale_ratio "$ScaleRatio" \
		--output_depth "$OutputDepth" \
		--noise_level "$NoiseLevel" \
		--mode "$Mode" \
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

function check_ranges ()
{
	local Errors=0
	local ParamCount=0
	local LineIndex=0
	local LastEndFrame=""
	
	while read Line
	do
		((LineIndex++))
		set_range $Line
		ParamCount=$?
		if [[ "$ParamCount" -eq 0 ]]; then
			continue
		fi
		if [[ "$ParamCount" -eq 3 ]]; then
			if [[ "$StartFrame" =~ ^[0-9]+$ ]]; then
				if [[ -n "$LastEndFrame" ]] && [[ $(($LastEndFrame+1)) != $StartFrame ]]; then
					echo "ERR [$LineIndex]: StartFrame ($StartFrame) doesn't follow the previous one ($LastEndFrame)"
					((Errors++))
				fi
			else
				echo "ERR [$LineIndex]: StartFrame $StartFrame is not valid integer"
				((Errors++))
			fi
				
			if [[ "$EndFrame" =~ ^[0-9]+$ ]]; then
				LastEndFrame="$EndFrame"
			else
				LastEndFrame=""
				echo "ERR [$LineIndex]: EndFrame $EndFrame is not valid integer"
				((Errors++))
			fi
			if [[ "$NoiseLevel" =~ ^[0-9]+$ ]]; then
				if [[ "$NoiseLevel" -lt 0 ]] || [[ "$NoiseLevel" -gt 3 ]]; then
					echo "ERR [$LineIndex]: NoiseLevel $NoiseLevel incorrect value (should be in the range 0-3)"
					((Errors++))
				fi
			else
				echo "ERR [$LineIndex]: NoiseLevel $NoiseLevel is not valid integer"
				((Errors++))
			fi
		else
			echo "ERR [$LineIndex]: $ParamCount parameters received (3 expected)"
			((Errors++))
		fi
	done < <(cat "$RangesList"; echo) # make bash not skip the last line (if there is no empty line at the end)
	if [[ "$Errors" -gt 0 ]]; then
		echo "Ranges list syntax: $Errors errors"
	fi
	return "$Errors"
}

function progress_bar ()
{
	local PreviousUpscaledFrame=""
	local LastUpscaledFrame=""
	local Total=$(to_int $LastOriginalFrame)
	while [[ "$LastUpscaledFrame" != "$LastOriginalFrame" ]]
	do
		LastUpscaledFrame=$(ls "$FramesUpscaledDir" | sort | tail -n 1)
		if [[ "$PreviousUpscaledFrame" != "$LastUpscaledFrame" ]]; then
			local Done=$(to_int $LastUpscaledFrame)
			printf "\r[%3d%%] %d/%d" "$(($Done*100/$Total))" "$Done" "$Total"
			PreviousUpscaledFrame="$LastUpscaledFrame"
		fi
		sleep 1
	done
}

if ! [[ -e "$Waifu2xConf" ]]; then
	create_default_conf
fi

source "$Waifu2xConf"

if ! check_ranges; then
	exit "$RANGES_LIST_SYNTAX_ERROR"
fi

rm -rf "$TmpFramesDir"
mkdir -p "$FramesUpscaledDir"

if ! [[ -r "$RangesList" ]]; then
	echo "Read file error: \"$RangesList\""
	exit "$FILE_READ_ERROR"
fi

LastOriginalFrame=$(ls "$FramesDir" | sort | tail -n 1)
LastUpscaledFrame=$(ls "$FramesUpscaledDir" | sort | tail -n 1)

if [[ "$LastUpscaledFrame" == "$LastOriginalFrame" ]]; then
	echo "WARN: Upscaled frames already exists - skip."
	exit "$SUCCESS"
fi

LastUpscaledFrame=$(to_int "$LastUpscaledFrame")
echo "$WIDTH"
printf "${BLD}$RowTemplate${DEF}" "START" "END" "NOISE" "ACTION"
while read Line
do
	if [[ -z "$Line" ]]; then
		continue
	fi
	
	set_range $Line
	clean_line "$COLUMNS"
	if [[ -n "$LastUpscaledFrame" ]] && [[ "$LastUpscaledFrame" -ge "$EndFrame" ]]; then
		printf "$RowTemplate" "$StartFrame" "$EndFrame" "$NoiseLevel" "SKIP"
		continue
	fi
	
	if [[ -n "$LastUpscaledFrame" ]] && [[ "$StartFrame" -lt "$LastUpscaledFrame" ]]; then
		printf "$RowTemplate" "$StartFrame"        "$(($LastUpscaledFrame-1))" "$NoiseLevel" "SKIP"
		printf "$RowTemplate" "$LastUpscaledFrame" "$EndFrame"          "$NoiseLevel" "CONTINUE"
		# if waifu2x-caffe was interrupted while saving the file, a corrupted file is saved 
		# so it's better to start by overwriting the last upscaled file
		StartFrame="$LastUpscaledFrame"
	else
		printf "$RowTemplate" "$StartFrame" "$EndFrame" "$NoiseLevel"
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
	
	clean_line "$COLUMNS"
	
	(progress_bar) &
	ProgressBarPID=$!
	
	(upscale_images "$TmpFramesDir" "$FramesUpscaledDir" "$ProgressBarPID" "$$") &
	Waifu2xPID=$!

	trap "kill $ProgressBarPID 2> /dev/null; exit $WAIFU2X_ERROR" HUP
	trap "kill $Waifu2xPID $ProgressBarPID 2> /dev/null; echo -e '\nInterrupted'; exit $INTERRUPT" INT
	wait 2> /dev/null
	
	rm -rf "$TmpFramesDir"
done < <(cat "$RangesList"; echo) # make bash not skip the last line (if there is no empty line at the end)
