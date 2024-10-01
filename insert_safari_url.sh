#!/bin/bash

# Run the AppleScript to get the current Safari URL
URL=$(osascript /Users/jonathan.buys/Unix/bin/get_safari_url.applescript)

# Check if the URL was successfully fetched
if [[ -z "$URL" ]]; then
    echo "Failed to get URL from Safari."
    exit 1
fi

# Insert the URL into Vim at the current cursor position
echo -n "$URL" 

