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

function create_default_conf ()
{
	echo "\
VideoCodec=\"libx265\"
Preset=\"slow\"
PixelFormat=\"yuv420p10le\"
ConstantRateFactor=\"16\"
VideoBitrate=\"\"
x265params=\"\"
" > "$FfmpegConf"
}

function auto_x265params ()
{
	if [[ -n "$x265params" ]]; then
		echo '-x265-params' "$x265params"
	fi
}

function auto_bitrate ()
{
	if [[ -n "$ConstantRateFactor" ]]; then
		echo '-crf' "$ConstantRateFactor"
	elif [[ -n "$VideoBitrate" ]]; then
		echo '-b:v' "$VideoBitrate"
	else
		echo "You must set ConstantRateFactor or VideoBitrate in ffmpeg.conf"
		exit "$SETTINGS_ERROR"
	fi
}

if ! [[ -e "$FfmpegConf" ]]; then
	create_default_conf
fi

source "$FfmpegConf"

rm -rf "$VideoUpscaledDir"; mkdir -p "$VideoUpscaledDir"

VideoUpscaled="$VideoUpscaledDir/video.mp4"

ffmpeg \
	-hide_banner \
	-f "image2" \
	-framerate "$(framerate)" \
	-i "$FramesUpscaledDir/%06d.png" \
	-r "$(framerate)" \
	-vcodec "$VideoCodec" \
	-preset "$Preset"  \
	-pix_fmt "$PixelFormat" \
	$(auto_bitrate) \
	$(auto_x265params) \
	"$VideoUpscaled"
	
if [[ $? -ne 0 ]]; then
	exit "$CREATE_UPSCALED_VIDEO_ERROR"
fi
