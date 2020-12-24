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

function extension_by_codec () # $1: Codec
{
	local Ext=""
	for Mux in muxer demuxer
	do
		# Where is my json?!
		Ext=$(
			ffprobe -v quiet -h $Mux="$1" | \
			grep 'Common extensions:'      | \
			sed -r 's|^.+: ([^,\.]+).+|\1|')
		if [[ -n "$Ext" ]]; then
			echo "$Ext"
			break
		fi
	done
}

function extract_attachments ()
{
	pushd "$AttachmentsDir"
	
	# Disable error checking
	# because ffmpeg always throws an error:
	# "At least one output file must be specified",
	# although it successfully saves attachments.
	set +e
	ffmpeg -hide_banner -dump_attachment:t "" -i "$InputFile"
	set -e
	
	popd
}

function extract_chapters ()
{
	# TODO: Convert $ChaptersJson to mkv-compatible format?
	echo "DUMMY"
}

if [[ -z "$1" ]]; then
	echo "You must specify the video file"
	exit "$PARAMETER_ERROR"
else
	InputFile=$(readlink -e "$1")
fi

if ! [[ -r "$InputFile" ]]; then
	echo "Read file error: \"$InputFile\""
	exit "$FILE_READ_ERROR"
fi

rm -rf "$AudioDir";       mkdir -p "$AudioDir"
rm -rf "$VideoDir";	      mkdir -p "$VideoDir"
rm -rf "$SubtitlesDir";   mkdir -p "$SubtitlesDir"
rm -rf "$ChaptersDir";    mkdir -p "$ChaptersDir"
rm -rf "$AttachmentsDir"; mkdir -p "$AttachmentsDir"

ffprobe -v quiet -print_format json -show_streams  "$InputFile" > "$StreamsJson"
ffprobe -v quiet -print_format json -show_format   "$InputFile" > "$FormatJson"
ffprobe -v quiet -print_format json -show_chapters "$InputFile" > "$ChaptersJson"

StreamCount=$(jq -r '.format.nb_streams' "$FormatJson")

for (( Index=0; Index < StreamCount; Index++ ))
do
	Type=$(jq -r ".streams[$Index].codec_type" "$StreamsJson")
	Codec=$(jq -r ".streams[$Index].codec_name" "$StreamsJson")
	Extension=$(extension_by_codec "$Codec")
	
	if [[ -z "$Extension" ]]; then
		echo "No extension for codec \"$Codec\""
		exit "$NO_EXTENSION_FOR_CODEC"
	fi
	
	case "$Type" in
		video )
			ffmpeg -hide_banner -i "$InputFile" -map "0:$Index" -c:v copy "$VideoDir/$Index.$Extension"
			if [[ "$?" != 0 ]]; then exit "$EXTRACT_AUDIO_ERROR"; fi ;;
		audio )
			ffmpeg -hide_banner -i "$InputFile" -map "0:$Index" -c:a copy "$AudioDir/$Index.$Extension"
			if [[ "$?" != 0 ]]; then exit "$EXTRACT_VIDEO_ERROR"; fi ;;
		subtitle )
			ffmpeg -hide_banner -i "$InputFile" -map "0:$Index" "$SubtitlesDir/$Index.$Extension"
			if [[ "$?" != 0 ]]; then exit "$EXTRACT_SUBTITLE_ERROR"; fi ;;
		attachment )
			continue ;;
		* )
			echo "Unknown codec type: \"$Type\""
			exit "$UNKNOWN_CODEC_TYPE_ERROR" ;;
	esac
done

extract_attachments
