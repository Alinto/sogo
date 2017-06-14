calculate_curl_fork_overhead() {
    local c_start=$(date +%s%N);
    for n in $(seq $(( $SOGO_CONCURRENCY_LIMIT * $SOGO_TEST_ITERATIONS )) ); do
        curl -s 2>&1 /dev/null
    done;
    local c_end=$(date +%s%N);
    echo "scale=2; $(( $c_end - $c_start )) / 1000000000" | bc -l
}
