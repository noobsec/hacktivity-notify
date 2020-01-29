#!/bin/bash

MAIN_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
DATA_PATH="$HOME/.hacktivity-notify"

function _Logger() {
	LOG_FILE="$DATA_PATH/notifications.log"
	[[ ! -f $LOG_FILE ]] && touch $LOG_FILE

	if [[ -z $2 ]]; then
		grep -q "$1" $LOG_FILE && echo "0" || echo "1"
	else
		echo "$1" >> $LOG_FILE
	fi
}

function _notify() {
	notify-send \
		"$2 on $4" "$7 $5, by $1 at $6" \
		-i "$MAIN_PATH/assets/icons/logo.png" \
		-o "View details:xdg-open $3" \
		-o "Close:false"

	aplay "$MAIN_PATH/assets/sounds/hint.mp3"
}

function _getHacktivities() {
	[[ ! -d $DATA_PATH ]] && mkdir -p $DATA_PATH/data/
	curl -s "https://hackerone.com/graphql" \
		-H "Authority: hackerone.com" \
		-H "X-Auth-Token: ----" \
		-H "User-Agent: Mozilla/5.0 (X11; Linux i686; rv:30.0) Gecko/20100101 Firefox/30.0" \
		-H "Origin: https://hackerone.com" \
		-H "Content-Type: application/json" \
		--data-binary '{"operationName":"HacktivityPageQuery","variables":{"querystring":"","where":{"report":{"disclosed_at":{"_is_null":false}}},"orderBy":null,"secureOrderBy":{"latest_disclosable_activity_at":{"_direction":"DESC"}},"count":25,"maxShownVoters":10},"query":"query HacktivityPageQuery($querystring: String, $orderBy: HacktivityItemOrderInput, $secureOrderBy: FiltersHacktivityItemFilterOrder, $where: FiltersHacktivityItemFilterInput, $count: Int, $cursor: String, $maxShownVoters: Int) {\n  me {\n    id\n    __typename\n  }\n  hacktivity_items(first: $count, after: $cursor, query: $querystring, order_by: $orderBy, secure_order_by: $secureOrderBy, where: $where) {\n    total_count\n    ...HacktivityList\n    __typename\n  }\n}\n\nfragment HacktivityList on HacktivityItemConnection {\n  total_count\n  pageInfo {\n    endCursor\n    hasNextPage\n    __typename\n  }\n  edges {\n    node {\n      ... on HacktivityItemInterface {\n        id\n        databaseId: _id\n        ...HacktivityItem\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n  __typename\n}\n\nfragment HacktivityItem on HacktivityItemUnion {\n  type: __typename\n  ... on HacktivityItemInterface {\n    id\n    votes {\n      total_count\n      __typename\n    }\n    voters: votes(last: $maxShownVoters) {\n      edges {\n        node {\n          id\n          user {\n            id\n            username\n            __typename\n          }\n          __typename\n        }\n        __typename\n      }\n      __typename\n    }\n    upvoted: upvoted_by_current_user\n    __typename\n  }\n  ... on Undisclosed {\n    id\n    ...HacktivityItemUndisclosed\n    __typename\n  }\n  ... on Disclosed {\n    id\n    ...HacktivityItemDisclosed\n    __typename\n  }\n  ... on HackerPublished {\n    id\n    ...HacktivityItemHackerPublished\n    __typename\n  }\n}\n\nfragment HacktivityItemUndisclosed on Undisclosed {\n  id\n  reporter {\n    id\n    username\n    ...UserLinkWithMiniProfile\n    __typename\n  }\n  team {\n    handle\n    name\n    medium_profile_picture: profile_picture(size: medium)\n    url\n    id\n    ...TeamLinkWithMiniProfile\n    __typename\n  }\n  latest_disclosable_action\n  latest_disclosable_activity_at\n  requires_view_privilege\n  total_awarded_amount\n  currency\n  __typename\n}\n\nfragment TeamLinkWithMiniProfile on Team {\n  id\n  handle\n  name\n  __typename\n}\n\nfragment UserLinkWithMiniProfile on User {\n  id\n  username\n  __typename\n}\n\nfragment HacktivityItemDisclosed on Disclosed {\n  id\n  reporter {\n    id\n    username\n    ...UserLinkWithMiniProfile\n    __typename\n  }\n  team {\n    handle\n    name\n    medium_profile_picture: profile_picture(size: medium)\n    url\n    id\n    ...TeamLinkWithMiniProfile\n    __typename\n  }\n  report {\n    id\n    title\n    substate\n    url\n    __typename\n  }\n  latest_disclosable_action\n  latest_disclosable_activity_at\n  total_awarded_amount\n  severity_rating\n  currency\n  __typename\n}\n\nfragment HacktivityItemHackerPublished on HackerPublished {\n  id\n  reporter {\n    id\n    username\n    ...UserLinkWithMiniProfile\n    __typename\n  }\n  team {\n    id\n    handle\n    name\n    medium_profile_picture: profile_picture(size: medium)\n    url\n    ...TeamLinkWithMiniProfile\n    __typename\n  }\n  report {\n    id\n    url\n    title\n    substate\n    __typename\n  }\n  latest_disclosable_activity_at\n  severity_rating\n  __typename\n}\n"}' --compressed -o $DATA_PATH/data/hacktivity.json
	cat $DATA_PATH/data/hacktivity.json | jq -r '.data.hacktivity_items.edges[] | [.node.databaseId, .node.reporter.username, .node.report.title, .node.report.url, .node.team.name, .node.latest_disclosable_activity_at, .node.total_awarded_amount] | @tsv' |
		while IFS=$'\t' read -r id reporter title url team disclosed_at reward; do
			LOGGER="_Logger"
			if [[ $($LOGGER $id) -eq "1" ]]; then
				[[ ! -z $reward ]] && bounty="[\$$reward]"
				date=$(date +"%d %b %Y" -d "${disclosed_at:0:10} ${disclosed_at:11:8}")
				time=$(date +"%R" -d "${disclosed_at:0:10} ${disclosed_at:11:8}")
				_notify "$reporter" "$title" "$url" "$team" "$date" "$time" "$bounty"
				$LOGGER $id 1
			fi
		done
}

_getHacktivities