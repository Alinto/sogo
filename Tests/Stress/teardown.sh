#!/bin/bash

. common_func.sh || error_out

echo -n "Estimating fork overhead... "
FORK_OVERHEAD=$(calculate_curl_fork_overhead)
echo "done!"

#
# TEST DEFINITION
#
test_teardown() {
    # Cleanup calendar test data
    for n in $(seq $SOGO_TEST_ITERATIONS); do
	curl -s -o /dev/null --basic --user sogo$1:sogo \
	     --request DELETE \
	     --header "Content-Type: text/xml" \
	$SOGO_SERVER_URL/sogo$1/Calendar/personal/$n.ics
    done;

    for n in $(seq $SOGO_TEST_ITERATIONS); do
	curl -s -o /dev/null --basic --user sogo$1:sogo \
	     --request DELETE \
	     --header "Content-Type: text/xml" \
	$SOGO_SERVER_URL/sogo$1/Calendar/personal/sogo$1-$n.ics
    done;

    # Cleanup address book test data
    for n in $(seq $SOGO_TEST_ITERATIONS); do
	curl -s -o /dev/null --basic --user sogo$1:sogo \
	     --request DELETE \
	     --header "Content-Type: text/xml" \
	$SOGO_SERVER_URL/sogo$1/Contacts/personal/$n.ics
    done;
}

export -f test_teardown

#
# TEST EXECUTION
#
echo "Starting teardown test..."
START=$(date +%s%N)
seq $SOGO_CONCURRENCY_LIMIT | parallel -j0 test_teardown {}
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
