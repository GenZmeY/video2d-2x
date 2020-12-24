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

# Range list format:
# START_FRAME END_FRAME NOISE_LEVEL
# (separate line for each range)
# (NOISE_LEVEL is optional)

source "$RangeGenConf"

"$DepsDir/range-gen/range-gen.exe" -j "$Jobs" -n "$NoiseLevel" "$FramesDir" "$RangesList" "$Threshold"
