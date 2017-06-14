#!/bin/bash

. common_func.sh || error_out

echo -n "Estimating fork overhead... "
FORK_OVERHEAD=$(calculate_curl_fork_overhead)
echo "done!"

#
# TEST DEFINITION
#
test_invitation() {
    for n in $(seq $SOGO_TEST_ITERATIONS); do
        start_date=$(/bin/date -d "today +$(($n-1)) hour" "+%Y%m%dT%H%M%S")
        end_date=$(/bin/date -d "today +$n hour" "+%Y%m%dT%H%M%S")=
        results=($(shuf -i 1-$SOGO_CONCURRENCY_LIMIT -n 3 | grep -v "^$1\$"))
        attendee1=${results[0]}
        attendee2=${results[1]}
        
        calendar_data=$(cat <<EOF
BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Inverse//Event Generator//EN\nCALSCALE:GREGORIAN\nBEGIN:VTIMEZONE\nTZID:America/Montreal\nBEGIN:DAYLIGHT\nTZOFFSETFROM:-0500\nTZOFFSETTO:-0400\nDTSTART:20070311T020000\nRRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU\nTZNAME:EDT\nEND:DAYLIGHT\nBEGIN:STANDARD\nTZOFFSETFROM:-0400\nTZOFFSETTO:-0500\DTSTART:20071104T020000\nRRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU\nTZNAME:EST\nEND:STANDARD\nEND:VTIMEZONE\nBEGIN:VEVENT\nSEQUENCE:1\nTRANSP:OPAQUE\nUID:sogo$1-$n\nSUMMARY:Event #$n-$1 invites $attendee1 and $attendee2\nDTSTART;TZID=America/Montreal:$start_date\nDTEND;TZID=America/Montreal:$end_date\nCREATED:20170605T144440Z\nDTSTAMP:20170605T144440Z\nORGANIZER:mailto:sogo$1@$SOGO_MAIL_DOMAIN\nATTENDEE;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;ROLE=REQ-PARTICIPANT:mailto:sogo$attendee1@$SOGO_MAIL_DOMAIN\nATTENDEE;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;ROLE=REQ-PARTICIPANT:mailto:sogo$attendee2@$SOGO_MAIL_DOMAIN\nEND:VEVENT\nEND:VCALENDAR
EOF
)
	echo -e $calendar_data | curl -s -o /dev/null --basic --user sogo$1:sogo \
	     --request PUT \
	     --header "Content-Type: text/calendar" \
             --data-binary @- \
	     $SOGO_SERVER_URL/sogo$1/Calendar/personal/sogo$1-$n.ics
    done;
}

export -f test_invitation

#
# TEST EXECUTION
#
echo "Starting invitation test..."
START=$(date +%s%N)
seq $SOGO_CONCURRENCY_LIMIT | parallel -j0 test_invitation {}
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
