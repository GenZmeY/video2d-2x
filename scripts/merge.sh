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

# temporary solution.
# TODO:
# Replace with creating mkv container 
# with all resources using mkvmerge

rm -rf "$ReleaseDir"; mkdir -p "$ReleaseDir"

ffmpeg \
	-hide_banner \
	-i $(find "$VideoUpscaledDir" -type f | head -n 1) \
	-i $(find "$AudioDir" -type f | head -n 1) \
	-vcodec "copy" \
	-acodec "copy" \
	"$ReleaseDir/release.mp4"
	
if [[ $? -ne 0 ]]; then
	exit "$MERGE_RELEASE_ERROR"
fi
