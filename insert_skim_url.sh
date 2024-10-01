#!/bin/bash

# Run the AppleScript to get the current Safari URL
URL=$(osascript /Users/jonathan.buys/Unix/bin/get_skim_url.scpt)

# Check if the URL was successfully fetched
if [[ -z "$URL" ]]; then
    echo "Failed to get URL from Skim."
    exit 1
fi

# Insert the URL into Vim at the current cursor position
echo -n "$URL" 

