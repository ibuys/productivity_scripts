#!/bin/sh

ical today -o json | jq -r '
  .[] |
  "- " +
  (if .all_day then
    "All day"
  else
    (.start_date | sub("\\.[0-9]+"; "") |
      fromdateiso8601 | strflocaltime("%I:%M %p"))
  end) +
  " — " + .title
'

