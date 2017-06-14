#!/bin/bash

echo $SOGO_CONCURRENCY_LIMIT
echo $SOGO_TEST_ITERATIONS
echo $SOGO_SERVER_URL

test_changes() {
    for n in $(seq $SOGO_TEST_ITERATIONS); do
        ctag=$(date +%s)
	curl -s -o /dev/null --basic --user sogo1:sogo \
	     --request REPORT \
	     --header "Depth:1" \
	     --header "Content-Type:text/xml" \
	     --data @- \
	$SOGO_SERVER_URL/sogo1/Calendar/personal <<EOF
<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:">
 <D:sync-token>$ctag</D:sync-token>
 <D:limit><D:nresults>10</D:nresults></D:limit>
 <D:sync-level>1</D:sync-level>
 <D:prop>
  <D:getcontenttype />
  <D:getetag />
 </D:prop>
</D:sync-collection>
EOF
    done;
}

export -f test_changes

echo "Starting changes test..."
START=$(date +%s)

seq $SOGO_CONCURRENCY_LIMIT | parallel -j0 test_changes {}

END=$(date +%s)
DIFF=$(( $END - $START ))
echo "Completed!"
echo "It took $DIFF seconds"
