export default {
  // setup: 4 user are needed: username, superuser, attendee1, attendee1_delegate
  // superuser must be a sogo superuser...

  hostname: "localhost",
  port: "20000",
  username: "mysql1",
  password: "qwerty",

  superuser: "francis",
  superuser_password: "qwerty",

  // 'subscriber_username' and 'attendee1' must be the same user
  subscriber_username: "sogo2",
  subscriber_password: "sogo2",

  attendee1: "sogo2@inverse.ca",
  attendee1_username: "sogo2",
  attendee1_password: "sogo2",

  attendee1_delegate: "sogo3@inverse.ca",
  attendee1_delegate_username: "sogo3",
  attendee1_delegate_password: "qwerty",

  resource_no_overbook: "resource1",
  resource_can_overbook: "resource2",

  // must match username
  white_listed_attendee: {
    // "sogo3": "Bob <sogo3@inverse.ca>"
    //"sogo1": "Bob <sogo1@inverse.ca>"
    "mysql1": "Bob <mysql1@inverse.ca>"
  },

  mailserver: "localhost",

  testput_nbrdays: 30,

  sieve_server: "localhost",
  sieve_port: 4190,

  sogo_user: "francis",
  sogo_tool_path: "/home/francis/GNUstep/Tools/Admin/sogo-tool",

  webCalendarURL: "http://inverse.ca/sogo-integration-tests/CanadaHolidays.ics"
}
