#!/bin/bash

# Search for a video file in the current directory
video_file=$(find . -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" \) -print -quit)

# Search for a subtitle file in the current directory
subtitle_file=$(find . -maxdepth 1 -type f -iname "*.srt" -print -quit)

# Check if a video file exists
if [ -z "$video_file" ]; then
  echo "No video file found in the current directory."
  exit 1
fi

# Check if a subtitle file exists
if [ -z "$subtitle_file" ]; then
  echo "No subtitle file (.srt) found in the current directory."
  exit 1
fi

# Extract the file name without extension from the video file
video_filename=$(basename "${video_file%.*}")

# Extract the file name without extension from the subtitle file
subtitle_filename=$(basename "${subtitle_file%.*}")

# Create the output file name by combining the video and subtitle file names
output_file="${video_filename}_withsubtitle.${video_file##*.}"

# Use FFmpeg to merge the video and subtitle files
ffmpeg -i "$video_file" -i "$subtitle_file" -c copy -c:s mov_text -metadata:s:s:0 language=eng "$output_file"
