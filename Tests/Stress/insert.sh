#!/bin/bash

. common_func.sh || error_out

echo -n "Estimating fork overhead... "
FORK_OVERHEAD=$(calculate_curl_fork_overhead)
echo "done!"

#
# TEST DEFINITION
#
test_events_insert() {
    for n in $(seq $SOGO_TEST_ITERATIONS); do
        start_date=$(/bin/date -d "today +$(($n-1)) hour" "+%Y%m%dT%H%M%S")
        end_date=$(/bin/date -d "today +$n hour" "+%Y%m%dT%H%M%S")
        calendar_data=$(cat <<EOF
BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Inverse//Event Generator//EN\nCALSCALE:GREGORIAN\nBEGIN:VTIMEZONE\nTZID:America/Montreal\nBEGIN:DAYLIGHT\nTZOFFSETFROM:-0500\nTZOFFSETTO:-0400\nDTSTART:20070311T020000\nRRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU\nTZNAME:EDT\nEND:DAYLIGHT\nBEGIN:STANDARD\nTZOFFSETFROM:-0400\nTZOFFSETTO:-0500\DTSTART:20071104T020000\nRRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU\nTZNAME:EST\nEND:STANDARD\nEND:VTIMEZONE\nBEGIN:VEVENT\nSEQUENCE:1\nTRANSP:OPAQUE\nUID:$n\nSUMMARY:Event $n\nDTSTART;TZID=America/Montreal:$start_date\nDTEND;TZID=America/Montreal:$end_date\nCREATED:20170605T144440Z\nDTSTAMP:20170605T144440Z\nEND:VEVENT\nEND:VCALENDAR
EOF
)
	echo -e $calendar_data | curl -s -o /dev/null --basic --user sogo$1:sogo \
	     --request PUT \
	     --header "Content-Type: text/calendar" \
             --data-binary @- \
	     $SOGO_SERVER_URL/sogo$1/Calendar/personal/$n.ics
    done;
}

export -f test_events_insert

#
# TEST EXECUTION
#
echo "Starting events insert test..."
START=$(date +%s%N)
seq $SOGO_CONCURRENCY_LIMIT | parallel -j0 test_events_insert {}
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
test_contacts_insert() {
    for n in $(seq $SOGO_TEST_ITERATIONS); do
        card_data=$(cat <<EOF
BEGIN:VCARD\nUID:$n\nVERSION:3.0\nCLASS:PUBLIC\nPROFILE:VCARD\nN:Doe;John\nFN:John $n Doe\nEMAIL:johndoe$n@example.com\nEND:VCARD
EOF
)
	echo -e $card_data | curl -s -o /dev/null --basic --user sogo$1:sogo \
	     --request PUT \
	     --header "Content-Type: text/calendar" \
             --data-binary @- \
	     $SOGO_SERVER_URL/sogo$1/Contacts/personal/$n.ics
    done;
}

export -f test_contacts_insert

#
# TEST EXECUTION
#
echo "Starting contacts insert test..."
START=$(date +%s%N)
seq $SOGO_CONCURRENCY_LIMIT | parallel -j0 test_contacts_insert {}
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
