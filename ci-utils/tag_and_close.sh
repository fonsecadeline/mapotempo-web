#!/usr/bin/env bash

MILESTONE=$(curl -sX GET --header 'Accept: application/json' \
  --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
  https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/milestones?state=active | \
  jq -r '.[] | "{\"due\": \"\(.due_date)\", \"title\": \"\(.title)\", \"iid\": \(.iid)}"' | \
  sort | \
  head -n 1)

CURRENT_MILESTONE_ID=$(jq -r '.iid' <<< ${MILESTONE})
CURRENT_MILESTONE_LABEL=$(jq -r '.title' <<< ${MILESTONE})
echo CURRENT_MILESTONE_LABEL: ${CURRENT_MILESTONE_LABEL}
if [[ -z $CURRENT_MILESTONE_ID ]]; then exit 1; fi

# Get all closed issues of the defined milestone
RESULT=$(curl -sX GET --header 'Accept: application/json' \
  --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
  https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/issues?state=closed&iid=${CURRENT_MILESTONE_ID})
IIDS=($(jq -r '.[] .iid' <<< ${RESULT}))
LABELS=($(jq -cr '.[] .labels' <<< ${RESULT}))

# Update issues with the tag
for index in "${!IIDS[@]}"; do
  labels=$(sed -r 's/\[|\]|"//g' <<< ${LABELS[$index]})",$LABEL"
  echo "Tagging issue #${IIDS[$index]} with labels ['$labels']"
  curl -sX PUT -H "PRIVATE-TOKEN: $PRIVATE_TOKEN" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/issues/${IIDS[$index]}?labels=$labels > /dev/null
done

# Get all opened issues of the defined milestone
RESULT=$(curl -sX GET --header 'Accept: application/json' \
  --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
  https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/issues?state=opened&iid=${CURRENT_MILESTONE_ID})
IIDS=($(jq -r '.[] .iid' <<< ${RESULT}))

# Close issue if they are present in git commit logs
for index in "${!IIDS[@]}"; do
  gitlog=$(git log --pretty=format:"%s" --grep="#${IIDS[$index]}")
  if [[ -n $gitlog ]]; then
    echo "Closing issue : '$gitlog'"
    curl -sX PUT -H "PRIVATE-TOKEN: $PRIVATE_TOKEN" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/issues/${IIDS[$index]}?state_event=close > /dev/null
  fi
done