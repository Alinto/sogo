# SOGo Stress Tests

### Requirements

 apt-get install parallel curl

### Stragegy

- set the concurrency level to the number of sogod workers you have
- use as many test users that you have sogod workers. For example, if
   you have 10 sogod works, have 10 test users
- test users MUST be named 'sogoX' and MUST have a password set to 'sogo'. If you
  have 3 test users, you should have sogo1, sogo2 and sogo3 as test
  users. Make sure you delete those users when you are done with
  stress-testing. Make also sure you delete the associated mailboxes
  as emails sent during tests will NOT be deleted
- ensure memcached is running - you can also test without memcache and
   see the performance impacts on SOGo.

### Running tests

- define your mail domain

export SOGO_MAIL_DOMAIN="example.com"

- define your SOGo server URL. Do NOT put a trailing slash

export SOGO_SERVER_URL="http://localhost/SOGo/dav"

- define the identifier of your main authentication source where your
  SOGo test users are adefined

export SOGO_AUTHENTICATION_SOURCE_ID="example.com_public"

- define your concurrency limit - a minimum of 3 is required:

export SOGO_CONCURRENCY_LIMIT=3

- define the number of test iterations

export SOGO_TEST_ITERATIONS=100
