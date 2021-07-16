export default {
  // setup: 4 user are needed: username, superuser, attendee1, attendee1_delegate
  // superuser must be a sogo superuser...

  hostname: "localhost",
  port: "80",
  username: "myuser",
  password: "mypass",

  superuser: "super",
  superuser_password: "pass",

  // 'subscriber_username' and 'attendee1' must be the same user
  subscriber_username: "otheruser",
  subscriber_password: "otherpass",

  attendee1: "user@domain.com",
  attendee1_username: "user",
  attendee1_password: "pass",

  attendee1_delegate: "user2@domain.com",
  attendee1_delegate_username: "sogo2",
  attendee1_delegate_password: "sogo",

  resource_no_overbook: "res",
  resource_can_overbook: "res-nolimit",

  // must match attendee1
  white_listed_attendee: {
    "sogo1": "John Doe <sogo1@example.com>"
  },

  mailserver: "imaphost",

  testput_nbrdays: 30,

  sieve_server: "localhost",
  sieve_port: 4190,

  sogo_user: "sogo",
  sogo_tool_path: "/usr/local/sbin/sogo-tool",

  webCalendarURL: "http://inverse.ca/sogo-integration-tests/CanadaHolidays.ics"
}