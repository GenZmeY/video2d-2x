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

InputFile=$(find "$VideoDir" -mindepth 1 -maxdepth 1 -type f | head -n 1)

if ! [[ -r "$InputFile" ]]; then
	echo "Read file error: \"$InputFile\""
	exit "$FILE_READ_ERROR"
fi

rm -rf "$FramesDir"; mkdir -p "$FramesDir"
# passthrough
ffmpeg -hide_banner -i "$InputFile" -r "$(framerate)" -f image2 -vsync vfr "$FramesDir/%06d.png"

if [[ "$?" != 0 ]]; then
	exit "$CONVERT_TO_FRAMES_ERROR"
fi
