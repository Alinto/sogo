#!/bin/bash

TESTS_RET=0
SRC_SOPE=$1
SRC_SOGO=$2
TESTS_FAILED=false
TESTS_RESULTS=()
JSON_TEST_RESULTS_PATH="/tmp/tests_results.json"

export TERM=xterm

# formatting
bold=$(tput bold)
normal=$(tput sgr0)
underline=$(tput smul)
no_underline=$(tput rmul)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)

title() {
    echo "${bold}${cyan}$1${normal}"
}

subtitle() {
    echo "${magenta}$1${normal}"
}

subsubtitle() {
    echo "${cyan}$1${normal}"
}

texterror() {
  echo "${bold}${red}$1${normal}"
}

textwarning() {
  echo "${bold}${yellow}$1${normal}"
}

textsuccess() {
  echo "${bold}${green}$1${normal}"
}

stepsuccess() {
  echo -e "$1 ${bold}${green}✔ ${normal}${bold}$2${normal}"
}

steperror() {
  echo -e "$1 ${bold}${red}𐄂 ${normal}${bold}$2${normal}"
}

in_array() {
  local SEARCH_ELEMENT
  SEARCH_ELEMENT="$1"
  shift
  local ELEMENT
  for ELEMENT in "$@"; do
    if [[ "$ELEMENT" == "$SEARCH_ELEMENT" ]]; then
      return 0
    fi
  done
  return 1
}

is_in_docker() {
    if [ -f /.dockerenv ]; then
        return 0
    else
        return 1
    fi
}

get_latest_github_commit_hash() {
  REPO="$1"
  BRANCH="${2:-master}"
  TOKEN="$3"
  GITHUB_API_URL="https://api.github.com/repos/$REPO/commits/$BRANCH"
  LATEST_COMMIT_HASH=$(curl -s -k -H "Authorization: token $TOKEN" $GITHUB_API_URL | grep '"sha"' | head -n 1 | awk '{print $2}' | tr -d '",')
  
  echo "$LATEST_COMMIT_HASH"
}

build_system_header() {
  echo "${white}                                                                                          "
  echo "${white}                                                                                          "
  echo "${white}                                                                                          "
  echo "${white}                                                                       ${green}▒▒▒▒${white}               "
  echo "${white}                                                                    ${green}▒▒▒${white}    ${green}▒▒▒▒${white}           "
  echo "${white}                                                                  ${green}▒▒▒${white}   ${green}▒▒▒${white}   ${green}▒▒${white}          "
  echo "${white}                                                                 ${green}▒▒▒${white}  ${green}▒▒${white}   ${green}▒▒${white}  ${green}▒▒${white}         "
  echo "${white}           ${green}▒▒▒▒▒▒▒▒▒▒${white}       ${green}▒▒▒▒▒▒▒▒▒▒▒${white}         ${green}▒▒▒▒▒▒▒▒▒▒▒▒${white}     ${green}▒▒${white}  ${green}▒▒${white}    ${green}▒▒${white}  ${green}▒▒${white}         "
  echo "${white}          ${green}▒▒${white}       ${green}▒▒${white}     ${green}▒▒▒${white}         ${green}▒▒▒${white}      ${green}▒▒▒${white}         ${green}▒▒▒${white}    ${green}▒▒${white}  ${green}▒▒▒▒▒▒${white}  ${green}▒▒▒${white}         "
  echo "${white}          ${green}▒▒▒${white}            ${green}▒▒▒${white}           ${green}▒▒▒${white}    ${green}▒▒${white}            ${green}▒▒▒${white}    ${green}▒▒${white}        ${green}▒▒▒${white}          "
  echo "${white}           ${green}▒▒▒▒▒▒▒${white}       ${green}▒▒▒${white}            ${green}▒▒${white}   ${green}▒▒▒${white}            ${green}▒▒▒${white}      ${green}▒▒▒▒▒▒▒▒▒${white}            "
  echo "${white}                 ${green}▒▒▒▒${white}    ${green}▒▒▒${white}            ${green}▒▒${white}    ${green}▒▒${white}            ${green}▒▒▒${white}                           "
  echo "${white}                   ${green}▒▒▒${white}    ${green}▒▒${white}           ${green}▒▒▒${white}    ${green}▒▒▒${white}           ${green}▒▒${white}                            "
  echo "${white}         ${green}▒▒▒${white}       ${green}▒▒▒${white}     ${green}▒▒▒${white}        ${green}▒▒▒${white}      ${green}▒▒▒${white}        ${green}▒▒▒${white}                             "
  echo "${white}           ${green}▒▒▒▒▒▒▒▒▒${white}         ${green}▒▒▒▒▒▒▒▒▒▒${white}          ${green}▒▒▒▒▒▒▒▒▒▒${white}                               "
  echo "${white}                                                 ${green}▒▒▒${white}                                      "
  echo "${white}                                                 ${green}▒▒${white}                                       "
  echo "${white}                                               ${green}▒▒▒▒▒▒▒▒▒▒▒▒▒${white}                              "
  echo "${white}                                              ${green}▒▒▒${white}          ${green}▒▒▒${white}                            "
  echo "${white}                                              ${green}▒▒${white}            ${green}▒▒▒${white}                           "
  echo "${white}                                              ${green}▒▒${white}            ${green}▒▒${white}                            "
  echo "${white}                                               ${green}▒▒▒▒${white}       ${green}▒▒▒▒${white}                            "
  echo "${white}                                                 ${green}▒▒▒▒▒▒▒▒▒▒${white}                               "
  echo "${white}                                                                                          "
  echo "${white}                                                                      ${bold}${green}BUILD SYSTEM${normal}           "
  echo "${white}                                                                                          "
  echo ""
}


check_exit_code() {
    local EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        return $EXIT_CODE
    fi
  }

function prep_tests {
  # install node modules
  cd "$SRC_SOGO/Tests"  && \
  npm config set loglevel=error && \
  npm install > /dev/null
  RC=$?
  GRC=$(($GRC+$RC))
  if [ $RC -ne 0 ]; then
    MSG="$MSG\nError installing node modules"
    error_out
  fi

  # fixup the tests configuration
  cd "$SRC_SOGO/Tests/lib"  && \
  cat >config.js <<EOF
export default {
  hostname: "httpd",
  port: "81",
  username: "sogo-tests1",
  password: "sogo",
  superuser: "sogo-tests-super",
  superuser_password: "sogo",
  subscriber_username: "sogo-tests2",
  subscriber_password: "sogo",
  attendee1: "sogo-tests2@example.org",
  attendee1_username: "sogo-tests2",
  attendee1_password: "sogo",
  attendee1_delegate: "sogo-tests3@example.org",
  attendee1_delegate_username: "sogo-tests3",
  attendee1_delegate_password: "sogo",
  resource_no_overbook: "res",
  resource_can_overbook: "res-nolimit",
  white_listed_attendee: {
    "sogo-tests1": "John Doe <sogo-tests1@example.org>"
  },
  mailserver: "dovecot",
  testput_nbrdays: 30,
  sieve_server: "dovecot",
  sieve_port: 4190,
  sogo_user: "sogo",
  sogo_tool_path: "/usr/sbin/sogo-tool",
  webCalendarURL: "http://httpd/CanadaHolidays.ics",
  timeout: 600000
}
EOF
  RC=$?
  GRC=$(($GRC+$RC))
  if [ $RC -ne 0 ]; then
    MSG="$MSG\nError creating config.js"
    error_out
  fi

  sleep 1
}

function prep_tests_mysql {
  rm /etc/sogo/sogo.conf
  cp /etc/sogo/sogo-tests-mysql-ldap.conf /etc/sogo/sogo.conf

  TMP_FILE=$(mktemp)
  chmod 600 $TMP_FILE
  cat <<EOF > $TMP_FILE
[client]
user = sogobuild
password = sogo123
host = mariadb
EOF

  # drop the mysql database and recreate it
  echo "drop database sogo_integration_tests;"                | mysql --defaults-extra-file=$TMP_FILE -h mariadb
  echo "create database sogo_integration_tests charset=utf8;" | mysql --defaults-extra-file=$TMP_FILE -h mariadb

  rm $TMP_FILE

  RC=$?
  GRC=$(($GRC+$RC))
  if [ $RC -ne 0 ]; then
    MSG="$MSG\nError recreating MySQL database"
    error_out
  fi
}

function prep_tests_postgresql {
  rm /etc/sogo/sogo.conf
  cp /etc/sogo/sogo-tests-postgresql-ldap.conf /etc/sogo/sogo.conf

  # drop the postgresql database and recreate it
  # the env var is unsafe, i know... just easier and non sensitive anyway
  PGPASSWORD=sogo123 dropdb                -U sogobuild -h postgres sogo_integration_tests
  PGPASSWORD=sogo123 createdb -O sogobuild -U sogobuild -h postgres sogo_integration_tests
  RC=$?
  GRC=$(($GRC+$RC))
  if [ $RC -ne 0 ]; then
    MSG="$MSG\nError recreating postgresql database"
    error_out
  fi
}

function prep_tests_mysql_auth {
    rm /etc/sogo/sogo.conf
    cp /etc/sogo/sogo-tests-mysql.conf /etc/sogo/sogo.conf
}

function prep_tests_postgresql_auth {
    rm /etc/sogo/sogo.conf
    cp /etc/sogo/sogo-tests-postgresql.conf /etc/sogo/sogo.conf
}

function prep_tests_mysql_combined {
    rm /etc/sogo/sogo.conf
    cp /etc/sogo/sogo-tests-mysql-ldap-combined.conf /etc/sogo/sogo.conf
}

function prep_tests_mysql_auth_combined {
    rm /etc/sogo/sogo.conf
    cp /etc/sogo/sogo-tests-mysql-combined.conf /etc/sogo/sogo.conf
}

function prep_tests_postgresql_combined {
    rm /etc/sogo/sogo.conf
    cp /etc/sogo/sogo-tests-postgresql-ldap-combined.conf /etc/sogo/sogo.conf
}

function prep_tests_postgresql_auth_combined {
    rm /etc/sogo/sogo.conf
    cp /etc/sogo/sogo-tests-postgresql-combined.conf /etc/sogo/sogo.conf
}

function error_out {
  set +x
  echo -e "$MSG"
  exit 1
}

function check_tests {
    FAIL=$(cat /tmp/out.log | grep -m 1 -Eo "([0-9]+)\s+failure" | cut -d' ' -f 1)
    TOTAL=$(cat /tmp/out.log | grep -m 1 -Eo "([0-9]+)\s+spec" | cut -d' ' -f 1)
    NOT_EXECUTED=$(cat /tmp/out.log | grep -m 1 -Eo "([0-9]+)\s+pending" | cut -d' ' -f 1)

    # If test fail
    if [ $FAIL -gt 0 ]
    then
        TESTS_RET=1
    fi

    # Console
    echo -e "\033[1mTests results for $1\033[0m" >> "$SRC_SOGO/Tests/results/tests_results.txt"
    echo -e "Total        : $TOTAL" >> "$SRC_SOGO/Tests/results/tests_results.txt"
    if [ $FAIL -gt 0 ]
    then
        echo -e "\033[0;31mFailed       : $FAIL\033[0m" >> "$SRC_SOGO/Tests/results/tests_results.txt"
    else
        echo -e "Failed       : $FAIL" >> "$SRC_SOGO/Tests/results/tests_results.txt"
    fi
    echo -e "Not executed : $NOT_EXECUTED" >> "$SRC_SOGO/Tests/results/tests_results.txt"
    if [ $FAIL -gt 0 ]
    then
        echo -e "\033[0;31mTests failed\033[0m" >> "$SRC_SOGO/Tests/results/tests_results.txt"
    else
        echo -e "\033[0;36mTests success\033[0m" >> "$SRC_SOGO/Tests/results/tests_results.txt"
    fi
    echo "" >> "$SRC_SOGO/Tests/results/tests_results.txt"

    # HTML
    echo "<table style=\"margin-bottom: 10px;\"><tbody><tr><td colspan=\"3\" style=\"background-color: aquamarine;\"><strong>$1</strong></td></tr><tr>" >> "$SRC_SOGO/Tests/results/index.html"
    echo "<td>Total</td><td>Failed</td><td>Not executed</td></tr><tr>" >> "$SRC_SOGO/Tests/results/index.html"
    if [ $FAIL -gt 0 ]
    then
        echo "<td>$TOTAL</td><td style=\"color: red;\">$FAIL</td><td>$NOT_EXECUTED</td>" >> "$SRC_SOGO/Tests/results/index.html"
        echo "</tr><tr><td colspan=\"3\" style=\"color: red;\"><strong>Tests failed</strong></td>" >> "$SRC_SOGO/Tests/results/index.html"
    else
        echo "<td>$TOTAL</td><td>$FAIL</td><td>$NOT_EXECUTED</td>" >> "$SRC_SOGO/Tests/results/index.html"
        echo "</tr><tr><td colspan=\"3\" style=\"color: #170;\"><strong>Tests success</strong></td>" >> "$SRC_SOGO/Tests/results/index.html"
    fi
    echo "</tr><tr><td colspan=\"3\"><a href=\"$2.html\" target=\"_blank\">View test report</a></td>" >> "$SRC_SOGO/Tests/results/index.html"
    echo "</tr></tbody></table>" >> "$SRC_SOGO/Tests/results/index.html"
    if [ $TESTS_RET -eq 1 ]
    then
        echo -e "\033[0;31mFailed\033[0m"
        return 131
    else
        echo -e "\033[0;36mSuccess\033[0m"
    fi
}

function run_tests {
  RET=0
  USE_PKILL=$3

  # create empty logfile
  cat /dev/null >/tmp/out.log

  if [ "$USE_PKILL" -eq 1 ]; then
    pkill -9 sogod
  else
    service sogod stop
  fi
  # Kill residual SOGo process
  LSOF_OUT=$(lsof -i TCP@127.0.0.1 -Fp | tr -d p)
  if [ ! -z "$LSOF_OUT" ]; then
    kill -9 $LSOF_OUT
  fi


  # restart services
  if [ "$USE_PKILL" -eq 1 ]; then
    su -s /bin/bash -c "/usr/sbin/sogod -WOWorkersCount 3 -WOPidFile /var/run/sogo/sogo.pid -WOLogFile /var/log/sogo/sogo.log" sogo
  else
    service sogod start
  fi
  
  # wait for it to settle
  sleep 3

  # run the tests and gather output
  cd "$SRC_SOGO/Tests"
  RC=$?
  GRC=$(($GRC+$RC))
  if [ $RC -ne 0 ]; then
    MSG="$MSG\nCan't cd into the Tests folder..."
    error_out
  fi
  npm run test-junit 2>&1 | tee -a  /tmp/out.log

  RC=$?
  GRC=$(($GRC+$RC))
  if [ $RC -ne 0 ]; then
    MSG="$MSG\nError running the integration tests"
    error_out
  fi

  # source GNUstep.sh
#   set +x
  #. /usr/share/GNUstep/Makefiles/GNUstep.sh
#   set -x

      # teststrings
      # run only once, no point in running with all the backend
      # substitutions
      # if [[ -z ${TEST_RUN_COUNT} || ${TEST_RUN_COUNT} -lt 1 ]]; then
      #   cd Integration
      #   ./teststrings.sh 2>&1 | tee -a /tmp/out.log
      # fi

  # stop sogo when we're done
  if [ "$USE_PKILL" -eq 1 ]; then
    pkill -9 sogod
  else
    service sogod stop
  fi

  XML_FILE="$SRC_SOGO/Tests/results/$2"
  mv /tmp/results.xml "$XML_FILE"

  check_tests "$1" "$2"

  # Generate JSON
  TOTAL_TESTS=$(xmllint --xpath 'sum(//testsuite/@tests)' "$XML_FILE")
  TOTAL_FAILURES=$(xmllint --xpath 'sum(//testsuite/@failures)' "$XML_FILE")
  TOTAL_ERRORS=$(xmllint --xpath 'sum(//testsuite/@errors)' "$XML_FILE")
  TOTAL_FAILED=$(($TOTAL_FAILURES + $TOTAL_ERRORS))
  TOTAL_SUCCESS=$(($TOTAL_TESTS - $TOTAL_FAILED))
  if [ "$TOTAL_FAILED" -gt 0 ]; then
      FAILED=true
      TESTS_FAILED=true
  else
      FAILED=false
  fi
  JSON_DATA=$(jq -n \
    --argjson total_tests "$TOTAL_TESTS" \
    --argjson total_failed "$TOTAL_FAILED" \
    --argjson total_success "$TOTAL_SUCCESS" \
    --arg description "$1" \
    --arg scenario "$2" \
    --argjson failed "$FAILED" \
    '{scenario: $scenario, description: $description, total_tests: $total_tests, total_failed: $total_failed, total_success: $total_success, failed: $failed}')
  TESTS_RESULTS+=("$JSON_DATA")
}

test() {
    #set -x
    USE_PKILL=${1:-0}
    TESTS_FAILED=false
    TESTS_RESULTS=()
    rm -f "$JSON_TEST_RESULTS_PATH"
    if [ "${SKIP_TESTS:-0}" -eq 1 ]; then
      subsubtitle "Skipping tests"
      return 0;
    fi

    # INTEGRATION TESTS
    if [[ -d "$SRC_SOGO/Tests/results" ]]; then
        rm -Rf "$SRC_SOGO/Tests/results"
    fi

    mkdir -p "$SRC_SOGO/Tests/results"
    echo "" > "$SRC_SOGO/Tests/results/tests_results.txt"
    echo "<html><head><style>table, th, td {border: 1px solid darkgrey;border-collapse: collapse; width: 400px; font-family: monospace;}</style></head><body>" > "$SRC_SOGO/Tests/results/index.html"

    test_title_color="${bold}${yellow}"

    # MySQL
    echo "${test_title_color}Running tests with LDAP auth and MySQL backend${normal}"
    prep_tests
    prep_tests_mysql
    run_tests "Running tests with LDAP auth and MySQL backend" "results-mysql-ldap.xml" $USE_PKILL

    echo "${test_title_color}Running tests with MySQL auth and MySQL backend${normal}"
    prep_tests
    prep_tests_mysql
    prep_tests_mysql_auth
    run_tests "Running tests with MySQL auth and MySQL backend" "results-mysql.xml" $USE_PKILL

    echo "${test_title_color}Running tests with LDAP auth and MySQL backend, combined database tables${normal}"
    prep_tests
    prep_tests_mysql
    prep_tests_mysql_combined
    run_tests "Running tests with LDAP auth and MySQL backend, combined database tables" "results-mysql-ldap-combined.xml" $USE_PKILL

    echo "${test_title_color}Running tests with MySQL auth and MySQL backend, combined database tables${normal}"
    prep_tests
    prep_tests_mysql
    prep_tests_mysql_auth_combined
    run_tests "Running tests with MySQL auth and MySQL backend, combined database tables" "results-mysql-combined.xml" $USE_PKILL


    # PGSQL
    echo "${test_title_color}Running tests with LDAP auth and postgresql backend${normal}"
    prep_tests
    prep_tests_postgresql
    run_tests "Running tests with LDAP auth and postgresql backend" "results-postgresql-ldap.xml" $USE_PKILL

    echo "${test_title_color}Running tests with postgresql auth and postgresql backend${normal}"
    prep_tests
    prep_tests_postgresql
    prep_tests_postgresql_auth
    run_tests "Running tests with postgresql auth and postgresql backend" "results-postgresql.xml" $USE_PKILL

    echo "${test_title_color}Running tests with LDAP auth and postgresql backend, combined database tables${normal}"
    prep_tests
    prep_tests_postgresql
    prep_tests_postgresql_combined
    run_tests "Running tests with LDAP auth and postgresql backend, combined database tables" "results-postgresql-ldap-combined.xml" $USE_PKILL

    echo "${test_title_color}Running tests with postgresql auth and postgresql backend, combined database tables${normal}"
    prep_tests
    prep_tests_postgresql
    prep_tests_postgresql_auth_combined
    run_tests "Running tests with postgresql auth and postgresql backend, combined database tables" "results-postgresql-combined.xml" $USE_PKILL
    

    # set -x

    # JUnit
    for file in $SRC_SOGO/Tests/results/*.xml #$xmlfiles
    do
         xunit-viewer -r $file -c -o "$file.html"
    done
    cat "$SRC_SOGO/Tests/results/tests_results.txt"
    echo "</body>" >> "$SRC_SOGO/Tests/results/index.html"
    chown 644 -R "$SRC_SOGO/Tests/results"
    chown -R www-data:www-data "$SRC_SOGO/Tests/results"

    # Restore conf
    rm /etc/sogo/sogo.conf
    cp /etc/sogo/sogo-base.conf /etc/sogo/sogo.conf
    if [ "$USE_PKILL" -eq 1 ]; then
      pkill -9 sogod
      su -s /bin/bash -c "/usr/sbin/sogod -WOWorkersCount 3 -WOPidFile /var/run/sogo/sogo.pid -WOLogFile /var/log/sogo/sogo.log" sogo
    else
      service sogod restart > /dev/null
    fi

    # Global json results
    TESTS_RESULTS_JSON=$(printf '%s\n' "${TESTS_RESULTS[@]}" | jq -s .)
    FINAL_JSON=$(jq -n \
        --argjson tests_failed "$TESTS_FAILED" \
        --argjson tests "$TESTS_RESULTS_JSON" \
        '{failed: $tests_failed, tests: $tests}')
    echo "$FINAL_JSON" > $JSON_TEST_RESULTS_PATH
    
    result_link="${bold}${magenta}--------------------------------------------------\nTests results : https://127.0.0.1/tests/index.html${normal}"

    # If test fail
    if [ $TESTS_RET -eq 1 ]
    then
        echo -e "$result_link [${bold}${red}Failed${normal}]\n"
        return 131
    else
        echo -e "$result_link [${bold}${green}Success${normal}]\n"
        return 0
    fi
}
