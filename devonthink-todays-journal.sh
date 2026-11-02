#!/bin/bash
# Create/open today's Markdown journal in DEVONthink.
# Keyboard Maestro: Execute Shell Script -> /bin/bash /path/to/this/script.sh
# Run with --preview to print the Markdown without accessing DEVONthink.

set -euo pipefail

# Customize these two settings for your DEVONthink setup.
JOURNAL_DATABASE=""           # Empty = DEVONthink's current database; or enter its name.
JOURNAL_GROUP="/Journal"      # Absolute group path inside that database.

# Reuse the helper scripts from your Vimwiki configuration.
CALENDAR_SCRIPT="$HOME/Unix/src/productivity_scripts/todays-calendar.sh"
OMNIFOCUS_SCRIPT="$HOME/Unix/src/productivity_scripts/omnifocus.scpt"
JIRA_SCRIPT="$HOME/Unix/src/productivity_scripts/myjira.py"

# Keyboard Maestro often provides a minimal PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

TODAY="$(/bin/date +%Y-%m-%d)"
PREVIEW=false
if [[ "${1:-}" == "--preview" ]]; then
    PREVIEW=true
elif [[ $# -ne 0 ]]; then
    printf 'Usage: %s [--preview]\n' "$0" >&2
    exit 2
fi

if [[ "$JOURNAL_GROUP" != /* ]]; then
    printf 'JOURNAL_GROUP must begin with /: %s\n' "$JOURNAL_GROUP" >&2
    exit 2
fi

# Pass the Markdown through a temporary UTF-8 file instead of the clipboard.
# Modes: lookup = open existing journal, if found; create = create or open.
devonthink() {
    /usr/bin/osascript - "$@" <<'APPLESCRIPT'
on run argv
    set operation to item 1 of argv
    set noteName to item 2 of argv
    set groupPath to item 3 of argv
    set databaseName to item 4 of argv
    set markdownPath to item 5 of argv

    tell application id "DNtp"
        if databaseName is "" then
            set theDatabase to current database
        else
            set theDatabase to database databaseName
        end if
        if theDatabase is missing value then error "Open the journal database in DEVONthink first."

        set theGroup to get record at groupPath in theDatabase
        if theGroup is missing value then
            if operation is "lookup" then return "MISSING"
            set theGroup to create location groupPath in theDatabase
        end if
        if (record type of theGroup) is not group then error "Journal destination is not a group: " & groupPath

        -- DEVONthink supports direct access to a named child record.
        -- Avoid enumerating children: AppleScript may misresolve a loop
        -- reference as "every content" when reopening an existing note.
        set theNote to missing value
        if exists child noteName of theGroup then
            set theNote to child noteName of theGroup
        else if exists child (noteName & ".md") of theGroup then
            set theNote to child (noteName & ".md") of theGroup
        end if

        if theNote is not missing value then
            if (record type of theNote) is not markdown then
                error "Existing journal record is not Markdown: " & noteName
            end if
        end if

        if theNote is missing value then
            if operation is "lookup" then return "MISSING"
            set markdownText to (read (POSIX file markdownPath) as «class utf8»)
            set theNote to create record with {name:noteName, type:markdown, content:markdownText} in theGroup
            if theNote is missing value then error "DEVONthink did not create the journal record."
            set outcome to "CREATED"
        else
            set outcome to "EXISTS"
        end if

        activate
        open tab for record theNote
        return outcome
    end tell
end run
APPLESCRIPT
}

# For repeat invocations, don't rerun Calendar, OmniFocus, or Jira at all.
if [[ "$PREVIEW" == false ]]; then
    result="$(devonthink lookup "$TODAY" "$JOURNAL_GROUP" "$JOURNAL_DATABASE" "")"
    if [[ "$result" == "EXISTS" ]]; then
        printf 'Opened existing DEVONthink journal: %s\n' "$TODAY"
        exit 0
    fi
    if [[ "$result" != "MISSING" ]]; then
        printf 'Unexpected DEVONthink response: %s\n' "$result" >&2
        exit 1
    fi
fi

# Remove whitespace-only lines, matching Vimwiki's systemlist/filter logic.
nonempty_or_placeholder() {
    local fallback="$1"
    awk -v fallback="$fallback" 'NF { print; found = 1 } END { if (!found) print fallback }'
}

calendar_section() {
    local output status
    if [[ ! -x "$CALENDAR_SCRIPT" ]]; then
        printf '_Calendar script not executable or not found: %s_\n' "$CALENDAR_SCRIPT"
    elif output="$("$CALENDAR_SCRIPT")"; then
        printf '%s\n' "$output" | nonempty_or_placeholder '_No calendar events._'
    else
        status=$?
        printf '_Calendar unavailable (script exited with status %s)._\n' "$status"
    fi
}

omnifocus_section() {
    local output status
    if [[ ! -f "$OMNIFOCUS_SCRIPT" ]]; then
        printf '_OmniFocus script not found: %s_\n' "$OMNIFOCUS_SCRIPT"
    elif output="$(/usr/bin/osascript "$OMNIFOCUS_SCRIPT")"; then
        printf '%s\n' "$output" | awk '
            NF {
                if ($0 ~ /^[[:space:]]*([-*+][[:space:]]|#|>|[0-9]+[.)][[:space:]]|```)/)
                    print
                else
                    print "- [ ] " $0
                found = 1
            }
            END { if (!found) print "_No OmniFocus tasks._" }
        '
    else
        status=$?
        printf '_OmniFocus unavailable (script exited with status %s)._\n' "$status"
    fi
}

jira_section() {
    local output status
    if [[ ! -f "$JIRA_SCRIPT" ]]; then
        printf '_Jira script not found: %s_\n' "$JIRA_SCRIPT"
    elif output="$(JIRA_SCRIPT="$JIRA_SCRIPT" /bin/bash -c 'source "$HOME/.env" && exec python3 "$JIRA_SCRIPT"')"; then
        printf '%s\n' "$output" | nonempty_or_placeholder '_No Jira tasks._'
    else
        status=$?
        printf '_Jira unavailable (script exited with status %s)._\n' "$status"
    fi
}

TEMP_BASE="${TMPDIR:-/tmp}"
TEMP_FILE="$(/usr/bin/mktemp "${TEMP_BASE%/}/devonthink-journal.XXXXXX")"
trap 'rm -f "$TEMP_FILE"' EXIT

{
    printf '# %s\n\n## Calendar\n' "$TODAY"
    calendar_section
    printf '\n## OmniFocus\n'
    omnifocus_section
    printf '\n## Jira\n'
    jira_section
    printf '\n## Today\047s Priorities\n\n1. \n2. \n3. \n\n## Notes\n\n## End of Day\n'
} > "$TEMP_FILE"

if [[ "$PREVIEW" == true ]]; then
    cat "$TEMP_FILE"
else
    result="$(devonthink create "$TODAY" "$JOURNAL_GROUP" "$JOURNAL_DATABASE" "$TEMP_FILE")"
    case "$result" in
        CREATED) printf 'Created DEVONthink journal: %s\n' "$TODAY" ;;
        EXISTS)  printf 'Opened existing DEVONthink journal: %s\n' "$TODAY" ;;
        *)       printf 'Unexpected DEVONthink response: %s\n' "$result" >&2; exit 1 ;;
    esac
fi
