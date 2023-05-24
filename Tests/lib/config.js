export default {
  hostname: "127.0.0.1",
  port: "50001",
  username: "sogo-tests1",
  password: "sogo",
  superuser: "sogo-tests-super",
  superuser_password: "sogo",
  subscriber_username: "sogo-tests2",
  subscriber_password: "sogo",
  attendee1: "sogo-tests2@example.com",
  attendee1_username: "sogo-tests2",
  attendee1_password: "sogo",
  attendee1_delegate: "sogo-tests3@example.com",
  attendee1_delegate_username: "sogo-tests3",
  attendee1_delegate_password: "sogo",
  resource_no_overbook: "res",
  resource_can_overbook: "res-nolimit",
  white_listed_attendee: {
    "sogo-tests1": "John Doe <sogo-tests1@example.com>"
  },
  mailserver: "127.0.0.1",
  testput_nbrdays: 30,
  sieve_server: "127.0.0.1",
  sieve_port: 4190,
  sogo_user: "sogo",
  sogo_tool_path: "/usr/sbin/sogo-tool",
  webCalendarURL: "http://127.0.0.1/sogo-integration-tests/CanadaHolidays.ics"
}
