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
source "$PreviewConf"

readonly TmpFramesSrcDir="${PreviewDir}_tmpsrc"
readonly TmpFramesOutDir="${PreviewDir}_tmpout"

if ! [[ -r "$RangesList" ]]; then
	echo "Read file error: \"$RangesList\""
	exit "$FILE_READ_ERROR"
fi

if ! check_ranges; then
	exit "$RANGES_LIST_SYNTAX_ERROR"
fi

rm -rf "$PreviewDir" "$TmpFramesSrcDir" "$TmpFramesOutDir"
mkdir -p "$PreviewDir" "$TmpFramesSrcDir" "$TmpFramesOutDir"

# Prepare frames
CopyList=""
while read Line
do
	if [[ -z "$Line" ]]; then
		continue
	fi
	
	RangeInfo=($Line)
	StartFrame=$(png_num ${RangeInfo[0]})
	EndFrame=$(png_num ${RangeInfo[1]})
	TargetFrame=$((StartFrame + (EndFrame - StartFrame)/2))
	
	CopyList+="$(printf "%06d" $TargetFrame).png " # faster than copying one by one
done < <(cat "$RangesList"; echo) # make bash not skip the last line (if there is no empty line at the end)

pushd "$FramesDir" > /dev/null
cp -f $CopyList "$TmpFramesSrcDir"
popd > /dev/null

if echo "$UseRangeNumbers" | grep -qiF "True"; then
	pushd "$TmpFramesSrcDir" > /dev/null
	Index=0
	while read File
	do
		((Index+=1))
		mv "$File" "$(printf "%06d" $Index).png"
	done < <(find "$TmpFramesSrcDir" -type f -name '*.png' -printf '%f\n')
	popd > /dev/null
fi

# Upscale (scale)
if echo "$Waifu2xScalePreview" | grep -qiF "True" && [[ "$ScaleRatio" -ne 1 ]]; then
	echo "waifu2x scale"
	waifu2x-caffe-cui \
		--mode "scale" \
		--scale_ratio "$ScaleRatio" \
		--output_depth "$OutputDepth" \
		--tta "$TtaMode" \
		--gpu "$GpuNum" \
		--process "$Process" \
		--crop_size "$CropSize" \
		--batch_size "$BatchSize" \
		--model_dir "$(model_path $Model)" \
		--input_path "$TmpFramesSrcDir" \
		--output_path "$TmpFramesOutDir" \
	> /dev/null
	
	pushd "$TmpFramesOutDir" > /dev/null
	while read Filename 
	do
		NewFilename=$(echo "$Filename" | sed "s|.png|_scale${ScaleRatio}.png|")
		mv "$Filename" "$PreviewDir/$NewFilename"
	done < <(find "$TmpFramesOutDir" -type f -name '*.png' -printf "%f\n")
	popd > /dev/null
fi

# Upscale (noise_scale)
for NoiseLevel in $Waifu2xNoiseScaleList
do
	if [[ "$ScaleRatio" -eq 1 ]]; then
		UpscaleMode="noise"
	else
		UpscaleMode="noise_scale"
	fi

	echo "waifu2x $UpscaleMode $NoiseLevel"
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
		--input_path "$TmpFramesSrcDir" \
		--output_path "$TmpFramesOutDir" \
	> /dev/null
	
	pushd "$TmpFramesOutDir" > /dev/null
	while read Filename 
	do
		NewFilename=$(echo "$Filename" | sed "s|.png|_scale${ScaleRatio}_noise${NoiseLevel}.png|")
		mv "$Filename" "$PreviewDir/$NewFilename"
	done < <(find "$TmpFramesOutDir" -type f -name '*.png' -printf "%f\n")
	popd > /dev/null
done

if echo "$ResizePreivew" | grep -qiF "True"; then
	echo "scale original"
	mogrify -scale $(echo "$ScaleRatio * 100" | bc)% "$TmpFramesSrcDir"/*.png
	pushd "$TmpFramesSrcDir" > /dev/null
	mv *.png "$PreviewDir"
	popd > /dev/null
fi

rm -rf "$TmpFramesSrcDir" "$TmpFramesOutDir"