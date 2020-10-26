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

# TODO: auto-detect ranges
# compare adjacent frames using the duplicate image search algorithm
# frames that are unlike each other will be the boundaries of the ranges

# Range list format:
# START_FRAME END_FRAME NOISE_LEVEL
# (separate line for each range)

function add_range () # $1: Start frame, $2: End frame, $3: Noise level
{
	echo -e "$1\t$2\t$3" >> "$RangesList"
}

StartFrame=$(ls "$FramesDir" | sort | head -n 1 | sed 's|.png$||')
EndFrame=$(ls "$FramesDir" | sort | tail -n 1 | sed 's|.png$||')
NoiseLevel="1"

:> "$RangesList"
add_range "$StartFrame" "$EndFrame" "$NoiseLevel"
