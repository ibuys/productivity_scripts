# Save this script as get_safari_url.applescript
tell application "Safari"
    if (count of windows) is greater than 0 and (count of tabs of front window) is greater than 0 then
        set currentURL to URL of current tab of front window
    else
        error "No Safari window or tabs are open."
    end if
end tell
return currentURL

