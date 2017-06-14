#!/bin/bash

. common_func.sh || error_out

echo -n "Estimating fork overhead... "
FORK_OVERHEAD=$(calculate_curl_fork_overhead)
echo "done!"

#
# TEST DEFINITION
#
test_authentication() {
    for n in $(seq $SOGO_TEST_ITERATIONS); do
	curl -s -o /dev/null --basic --user sogo$1:sogo \
	     --request PROPFIND \
	     --header "Depth:1" \
	     --header "Content-Type:text/xml" \
	     --data @- \
	$SOGO_SERVER_URL/sogo$1 <<EOF
<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <getcontentlength xmlns="DAV:"/>
    <getlastmodified xmlns="DAV:"/>
    <executable xmlns="http://apache.org/dav/props/"/>
    <resourcetype xmlns="DAV:"/>
    <checked-in xmlns="DAV:"/>
    <checked-out xmlns="DAV:"/>
  </prop>
</propfind>
EOF
    done;
}
export -f test_authentication

#
# TEST EXECUTION
#
echo -n "Starting authentication test... "
START=$(date +%s%N)
seq $SOGO_CONCURRENCY_LIMIT | parallel -j0 test_authentication {}
END=$(date +%s%N)

#
# TEST RESULTS
#
DIFF=$(echo "scale=2; $(( $END - $START)) / 1000000000" | bc -l)
TOTAL=$(( $SOGO_CONCURRENCY_LIMIT * $SOGO_TEST_ITERATIONS ))
DIFF_WITHOUT_FORK=$(echo "scale=2; $DIFF - $FORK_OVERHEAD" | bc -l)
THROUGHPUT=$(echo "scale=2; $TOTAL / $DIFF_WITHOUT_FORK" | bc -l)
echo "completed!"
echo "It took $DIFF seconds to run the test with the fork overhead of $FORK_OVERHEAD seconds."
echo "The real execution time for the test is $DIFF_WITHOUT_FORK seconds."
echo "Throughput achieved is $THROUGHPUT requests per second."
