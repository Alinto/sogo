#!/bin/bash

. common_func.sh || error_out

echo -n "Estimating fork overhead... "
FORK_OVERHEAD=$(calculate_curl_fork_overhead)
echo "done!"

#
# TEST DEFINITION
#
test_gal_search() {
    for n in $(seq $SOGO_TEST_ITERATIONS); do
	curl -s -o /dev/null --basic --user sogo$1:sogo \
	     --request REPORT \
	     --header "Depth:1" \
	     --header "Content-Type:text/xml" \
	     --data @- \
	$SOGO_SERVER_URL/sogo$1/Contacts/$SOGO_AUTHENTICATION_SOURCE_ID <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<C:addressbook-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">
 <D:prop>
  <D:getetag/>
 </D:prop>
 <C:filter>
  <C:prop-filter name="mail">
   <C:text-match collation="i;unicasemap" match-type="starts-with">sogo</C:text-match>
  </C:prop-filter>
 </C:filter>
</C:addressbook-query>
EOF
    done;
}

export -f test_gal_search

#
# TEST EXECUTION
#
echo "Starting GAL search test..."
START=$(date +%s%N)
seq $SOGO_CONCURRENCY_LIMIT | parallel -j0 test_gal_search {}
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


#
# TEST DEFINITION
#
test_contacts_search() {
    for n in $(seq $SOGO_TEST_ITERATIONS); do
	curl -s -o /dev/null --basic --user sogo$1:sogo \
	     --request REPORT \
	     --header "Depth:1" \
	     --header "Content-Type:text/xml" \
	     --data @- \
	$SOGO_SERVER_URL/sogo$1/Contacts/personal/ <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<C:addressbook-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">
 <D:prop>
  <D:getetag/>
 </D:prop>
 <C:filter>
  <C:prop-filter name="mail">
   <C:text-match collation="i;unicasemap" match-type="starts-with">john$n</C:text-match>
  </C:prop-filter>
 </C:filter>
</C:addressbook-query>
EOF
    done;
}

export -f test_contacts_search

#
# TEST EXECUTION
#
echo "Starting contacts search test..."
START=$(date +%s%N)
seq $SOGO_CONCURRENCY_LIMIT | parallel -j0 test_contacts_search {}
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


#
# TEST DEFINITION
#
test_calendar_search() {
    for n in $(seq $SOGO_TEST_ITERATIONS); do
	curl -s -o /dev/null --basic --user sogo$1:sogo \
	     --request REPORT \
	     --header "Depth:1" \
	     --header "Content-Type:text/xml" \
	     --data @- \
	$SOGO_SERVER_URL/sogo$1/Calendar/personal/ <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
    <d:prop>
        <d:getetag />
    </d:prop>
     <c:filter>
       <c:comp-filter name="VCALENDAR">
         <c:comp-filter name="VEVENT">
           <c:time-range start="20000101T000000Z"
                         end="20200101T000000Z"/>
         </c:comp-filter>
       </c:comp-filter>
     </c:filter>
</c:calendar-query>
EOF
    done;
}

export -f test_calendar_search

#
# TEST EXECUTION
#
echo "Starting calendar search test..."
START=$(date +%s%N)
seq $SOGO_CONCURRENCY_LIMIT | parallel -j0 test_calendar_search {}
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
