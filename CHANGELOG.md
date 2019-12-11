## [4.1.1](https://github.com/inverse-inc/sogo/compare/SOGo-4.1.0...SOGo-4.1.1) (2019-10-31)

### Bug Fixes

* **web:** don't allow RDATE unless already defined
* **web:** don't modify time when computing dates interval (closes [#4861](http://sogo.nu/bugs/view.php?id=4861))
* **web:** swap start-end dates when delta is negative
* **core:** use the supplied Sieve creds to fetch the IMAP4 separator (closes [#4846](http://sogo.nu/bugs/view.php?id=4846))
* **core:** fixed Apple Calendar creation (closes [#4813](http://sogo.nu/bugs/view.php?id=4813))
* **eas:** fixed EAS provisioning support for Outlook/iOS (closes [#4853](http://sogo.nu/bugs/view.php?id=4853))

## [4.1.0](https://github.com/inverse-inc/sogo/releases/tag/SOGo-4.1.0) (2019-10-24)

### Features

* **core:** Debian 10 (Buster) support for x86_64 (closes [#4775](http://sogo.nu/bugs/view.php?id=4775))
* **core:** now possible to specify which domains you can forward your mails to
* **core:** added support for S/MIME opaque signing (closes [#4582](http://sogo.nu/bugs/view.php?id=4582))
* **web:** optionally expand LDAP groups in attendees editor (closes [#2506](http://sogo.nu/bugs/view.php?id=2506))

### Enhancements

* **web:** avoid saving an empty calendar name
* **web:** prohibit duplicate contact categories in Preferences module
* **web:** improve constrat of text in toolbar with input fields
* **web:** improve labels of auto-reply date settings (closes [#4791](http://sogo.nu/bugs/view.php?id=4791))
* **web:** updated Angular Material to version 1.1.20
* **web:** updated CKEditor to version 4.13.0
* **core:** now dynamically detect and use the IMAP separator (closes [#1490](http://sogo.nu/bugs/view.php?id=1490))
* **core:** default Sieve port is now 4190 (closes [#4826](http://sogo.nu/bugs/view.php?id=4826))
* **core:** updated timezones to version 2019c

### Bug Fixes

* **web:** properly handle Windows-1256 charset (closes [#4781](http://sogo.nu/bugs/view.php?id=4781))
* **web:** fixed saving value of receipt action for main IMAP account
* **web:** fixed search results in Calendar module when targeting all events
* **web:** properly encode URL of cards from exteral sources
* **web:** restore cards selection after automatic refresh (closes [#4809](http://sogo.nu/bugs/view.php?id=4809))
* **web:** don't mark draft as deleted when SOGoMailKeepDraftsAfterSend is enabled (closes [#4830](http://sogo.nu/bugs/view.php?id=4830))
* **web:** allow single-day vacation auto-reply (closes [#4698](http://sogo.nu/bugs/view.php?id=4698))
* **web:** allow import to calendar subscriptions with creation rights
* **web:** handle DST change in Date.daysUpTo (closes [#4842](http://sogo.nu/bugs/view.php?id=4842))
* **web:** improved handling of start/end times (closes [#4497](http://sogo.nu/bugs/view.php?id=4497), closes [#4845](http://sogo.nu/bugs/view.php?id=4845))
* **web:** improved handling of vacation auto-reply activation dates (closes [#4844](http://sogo.nu/bugs/view.php?id=4844))
* **web:** added missing contact fields for sorting LDAP sources (closes [#4799](http://sogo.nu/bugs/view.php?id=4799))
* **core:** honor IMAPLoginFieldName also when setting IMAP ACLs
* **core:** honor groups when setting IMAP ACLs
* **core:** honor "any authenticated user" when setting IMAP ACLs
* **core:** avoid exceptions for RRULE with no DTSTART
* **core:** make sure we handle events occurring after RRULE's UNTIL date
* **core:** avoid changing RRULE's UNTIL date for no reason
* **core:** fixed handling of SENT-BY addresses (closes [#4583](http://sogo.nu/bugs/view.php?id=4583))
* **eas:** improve FolderSync operation (closes [#4672](http://sogo.nu/bugs/view.php?id=4672))
* **eas:** avoid incorrect truncation leading to exception (closes [#4806](http://sogo.nu/bugs/view.php?id=4806))

## [4.0.8](https://github.com/inverse-inc/sogo/releases/tag/SOGo-4.0.8) (2019-07-19)

### Enhancements

* **web:** show calendar names of subscriptions in events blocks
* **web:** show hints for mail vacation options (closes [#4462](http://sogo.nu/bugs/view.php?id=4462))
* **web:** allow to fetch unseen count of all mailboxes (closes [#522](http://sogo.nu/bugs/view.php?id=522), closes [#2776](http://sogo.nu/bugs/view.php?id=2776), closes [#4276](http://sogo.nu/bugs/view.php?id=4276))
* **web:** add rel="noopener" to external links (closes [#4764](http://sogo.nu/bugs/view.php?id=4764))
* **web:** add Indonesian (id) translation
* **web:** updated Angular Material to version 1.1.19
* **web:** replaced bower packages by npm packages
* **web:** restored mail threads (closes [#3478](http://sogo.nu/bugs/view.php?id=3478), closes [#4616](http://sogo.nu/bugs/view.php?id=4616), closes [#4735](http://sogo.nu/bugs/view.php?id=4735))
* **web:** reflect attendee type with generic icon (person/group/resource)
* **web:** reduce usage of calendar color in dialogs

### Bug Fixes

* **web:** fixed wrong translation of custom calendar categories
* **web:** fixed wrong colors assigned to default calendar categories
* **web:** lowered size of headings on small screens
* **web:** fixed scrolling in calendars list on Android
* **web:** keep center list of Calendar module visible on small screens
* **web:** check for duplicate name only if address book name is changed
* **web:** improved detection of URLs and email addresses in text mail parts
* **web:** fixed page reload with external IMAP account (closes [#4709](http://sogo.nu/bugs/view.php?id=4709))
* **web:** constrained absolute-positioned child elements of HTML mail parts
* **web:** fixed useless scrolling when deleting a message
* **web:** don't hide compose button if messages list is visible
* **web:** fixed next/previous slots with external attendees
* **web:** fixed restoration of sub mailbox when reloading page
* **web:** use matching address of attendee (closes [#4473](http://sogo.nu/bugs/view.php?id=4473))
* **core:** allow super users to modify any event (closes [#4216](http://sogo.nu/bugs/view.php?id=4216))
* **core:** correctly handle the full cert chain in S/MIME
* **core:** handle multidays events in freebusy data
* **core:** avoid exception on recent GNUstep when attached file has no filename (closes [#4702](http://sogo.nu/bugs/view.php?id=4702))
* **core:** avoid generating broken DTSTART for the freebusy.ifb file (closes [#4289](http://sogo.nu/bugs/view.php?id=4289))
* **core:** consider DAVx5 like Apple Calendar (closes [#4304](http://sogo.nu/bugs/view.php?id=4304))
* **core:** improve handling of signer certificate (closes [#4742](http://sogo.nu/bugs/view.php?id=4742))
* **core:** added safety checks in S/MIME (closes [#4745](http://sogo.nu/bugs/view.php?id=4745))
* **core:** fixed domain placeholder issue when using sogo-tool (closes [#4723](http://sogo.nu/bugs/view.php?id=4723))

## [4.0.7](https://github.com/inverse-inc/sogo/releases/tag/SOGo-4.0.7) (2019-02-27)

### Bug Fixes

* **web:** date validator now handles non-latin characters
* **web:** show the "reply all" button in more situations
* **web:** fixed CSS when printing message in popup window (closes [#4674](http://sogo.nu/bugs/view.php?id=4674))
* **i18n:** added missing subject of appointment mail reminders (closes [#4656](http://sogo.nu/bugs/view.php?id=4656))

## [4.0.6](https://github.com/inverse-inc/sogo/releases/tag/SOGo-4.0.6) (2019-02-21)

### Enhancements

* **web:** create card from sender or recipient address (closes [#3002](http://sogo.nu/bugs/view.php?id=3002), closes [#4610](http://sogo.nu/bugs/view.php?id=4610))
* **web:** updated Angular to version 1.7.7
* **web:** restored support for next/previous slot suggestion in attendees editor
* **web:** improved auto-completion display of contacts
* **web:** allow modification of attendees participation role
* **web:** updated Angular Material to version 1.1.13
* **web:** updated CKEditor to version 4.11.2
* **core:** baseDN now accept dynamic domain values (closes [#3685](http://sogo.nu/bugs/view.php?id=3685) - sponsored by iRedMail)
* **core:** we now handle optional and non-required attendee states

### Bug Fixes

* **web:** fixed all-day event dates with different timezone
* **web:** fixed display of Bcc header (closes [#4642](http://sogo.nu/bugs/view.php?id=4642))
* **web:** fixed refresh of drafts folder when saving a draft
* **web:** fixed CAS session timeout handling during XHR requests (closes [#4468](http://sogo.nu/bugs/view.php?id=4468))
* **web:** reflect active locale in HTML lang attribute (closes [#4660](http://sogo.nu/bugs/view.php?id=4660))
* **web:** allow scroll of login page on small screen (closes [#4035](http://sogo.nu/bugs/view.php?id=4035))
* **web:** fixed saving of email address for external calendar notifications (closes [#4630](http://sogo.nu/bugs/view.php?id=4630))
* **web:** sent messages cannot be replied to their BCC email addresses (closes [#4460](http://sogo.nu/bugs/view.php?id=4460))
* **core:** ignore transparent events in time conflict validation (closes [#4539](http://sogo.nu/bugs/view.php?id=4539))
* **core:** fixed yearly recurrence calculator when starting from previous year
* **core:** changes to contacts are now propagated to lists (closes [#850](http://sogo.nu/bugs/view.php?id=850), closes [#4301](http://sogo.nu/bugs/view.php?id=4301), closes [#4617](http://sogo.nu/bugs/view.php?id=4617))
* **core:** fixed bad password login interval (closes [#4664](http://sogo.nu/bugs/view.php?id=4664))

## [4.0.5](https://github.com/inverse-inc/sogo/releases/tag/SOGo-4.0.5) (2019-01-09)

### Features

* **web:** dynamic stylesheet for printing calendars (closes [#3768](http://sogo.nu/bugs/view.php?id=3768))

### Enhancements

* **web:** show source addressbook of matching contacts in appointment editor (closes [#4579](http://sogo.nu/bugs/view.php?id=4579))
* **web:** improve display of keyboard shortcuts
* **web:** show time for messages of yesterday (closes [#4599](http://sogo.nu/bugs/view.php?id=4599))
* **web:** fit month view to window size (closes [#4554](http://sogo.nu/bugs/view.php?id=4554))
* **web:** updated CKEditor to version 4.11.1
* **web:** updated Angular Material to version 1.1.12

### Bug Fixes

* **sogo-tool:** fixed "manage-acl unsubscribe" command (closes [#4591](http://sogo.nu/bugs/view.php?id=4591))
* **web:** fixed handling of collapsed/expanded mail accounts (closes [#4541](http://sogo.nu/bugs/view.php?id=4541))
* **web:** fixed handling of duplicate recipients (closes [#4597](http://sogo.nu/bugs/view.php?id=4597))
* **web:** fixed folder export when XSRF validation is enabled (closes [#4502](http://sogo.nu/bugs/view.php?id=4502))
* **web:** don't encode filename extension when exporting folders
* **web:** fixed download of HTML body parts
* **web:** catch possible exception when registering mailto protocol
* **core:** don't always fetch the sorting columns
* **eas:** strip '<>' from bodyId and when forwarding mails
* **eas:** fix search on for Outlook application (closes [#4605](http://sogo.nu/bugs/view.php?id=4605) and closes [#4607](http://sogo.nu/bugs/view.php?id=4607))
* **eas:** improve search operations and results fetching
* **eas:** better handle bogus DTStart values
* **eas:** support for basic UserInformation queries (closes [#4614](http://sogo.nu/bugs/view.php?id=4614))
* **eas:** better handle timezone changes (closes [#4624](http://sogo.nu/bugs/view.php?id=4624))

## [4.0.4](https://github.com/inverse-inc/sogo/releases/tag/SOGo-4.0.4) (2018-10-23)

### Bug Fixes

* **web:** fixed time conflict validation when not the owner
* **web:** fixed freebusy display with default theme (closes [#4578](http://sogo.nu/bugs/view.php?id=4578))

## [4.0.3](https://github.com/inverse-inc/sogo/releases/tag/SOGo-4.0.3) (2018-10-17)

### Enhancements

* **web:** prohibit subscribing a user with no rights
* **web:** new button to mark a task as completed (closes [#4531](http://sogo.nu/bugs/view.php?id=4531))
* **web:** new button to reset Calendar categories to defaults
* **web:** moved the unseen messages count to the beginning of the window's title (closes [#4553](http://sogo.nu/bugs/view.php?id=4553))
* **web:** allow export of calendars subscriptions (closes [#4560](http://sogo.nu/bugs/view.php?id=4560))
* **web:** hide compose button when reading message on mobile device
* **web:** updated Angular to version 1.7.5
* **web:** updated CKEditor to version 4.10.1

### Bug Fixes

* **web:** include mail account name in form validation (closes [#4532](http://sogo.nu/bugs/view.php?id=4532))
* **web:** calendar properties were not completely reset on cancel
* **web:** check ACLs on address book prior to delete cards
* **web:** fixed condition of copy action on cards
* **web:** fixed display of notification email in calendar properties
* **web:** fixed display of multi-days events when some weekdays are disabled
* **web:** fixed synchronisation of calendar categories
* **web:** fixed popup window detection in message viewer (closes [#4518](http://sogo.nu/bugs/view.php?id=4518))
* **web:** fixed behaviour of return receipt actions
* **web:** fixed freebusy information with all-day events
* **web:** fixed support for SOGoMaximumMessageSizeLimit
* **core:** fixed email reminders support for tasks
* **core:** fixed time conflict validation (closes [#4539](http://sogo.nu/bugs/view.php?id=4539))

## [4.0.2](https://github.com/inverse-inc/sogo/releases/tag/SOGo-4.0.2) (2018-08-24)

### Features

* **web:** move mailboxes (closes [#644](http://sogo.nu/bugs/view.php?id=644), closes [#3511](http://sogo.nu/bugs/view.php?id=3511), closes [#4479](http://sogo.nu/bugs/view.php?id=4479))

### Enhancements

* **web:** prohibit duplicate calendar categories in Preferences module
* **web:** added Romanian (ro) translation - thanks to Vasile Razvan Luca
* **web:** add security flags to cookies (HttpOnly, secure) (closes [#4525](http://sogo.nu/bugs/view.php?id=4525))
* **web:** better theming for better customization (closes [#4500](http://sogo.nu/bugs/view.php?id=4500))
* **web:** updated Angular to version 1.7.3
* **web:** updated ui-router to version 1.0.20
* **core:** enable Oracle OCI support for CentOS/RHEL v7

### Bug Fixes

* **core:** handle multi-valued mozillasecondemail attribute mapping
* **core:** avoid displaying empty signed emails when using GNU TLS (closes [#4433](http://sogo.nu/bugs/view.php?id=4433))
* **web:** improve popup window detection in message viewer (closes [#4518](http://sogo.nu/bugs/view.php?id=4518))
* **web:** enable save button when editing the members of a list
* **web:** restore caret position when replying or forwarding a message (closes [#4517](http://sogo.nu/bugs/view.php?id=4517))
* **web:** localized special mailboxes names in filter editor
* **web:** fixed saving task with reminder based on due date

## [4.0.1](https://github.com/inverse-inc/sogo/releases/tag/SOGo-4.0.1) (2018-07-10)

### Enhancements

* **web:** now possible to show events/task for the current year
* **web:** show current ordering setting in lists
* **web:** remove invalid occurrences when modifying a recurrent event
* **web:** updated Angular to version 1.7.2
* **web:** updated Angular Material to version 1.1.10
* **web:** updated CKEditor to version 4.10.0
* **web:** allow mail flag addition/edition on mobile
* **web:** added Japanese (jp) translation - thanks to Ryo Yamamoto

### Bug Fixes

* **core:** properly update the last-modified attribute (closes [#4313](http://sogo.nu/bugs/view.php?id=4313))
* **core:** fixed default data value for c_hascertificate (closes [#4442](http://sogo.nu/bugs/view.php?id=4442))
* **core:** fixed ACLs restoration with sogo-tool in single store mode (closes [#4385](http://sogo.nu/bugs/view.php?id=4385))
* **core:** fixed S/MIME code with chained certificates
* **web:** prevent deletion of special folders using del key
* **web:** fixed SAML2 session timeout handling during XHR requests
* **web:** fixed renaming a folder under iOS
* **web:** fixed download of exported folders under iOS
* **web:** improved server-side CSS sanitizer
* **web:** match recipient address when replying (closes [#4495](http://sogo.nu/bugs/view.php?id=4495))
* **eas:** improved alarms syncing with EAS devices (closes [#4351](http://sogo.nu/bugs/view.php?id=4351))
* **eas:** avoid potential cache update when breaking sync queries (closes [#4422](http://sogo.nu/bugs/view.php?id=4422))
* **eas:** fixed EAS search

## [4.0.0](https://github.com/inverse-inc/sogo/releases/tag/SOGo-4.0.0) (2018-03-07)

### Features

* **core:** full S/MIME support
* **core:** can now invite attendees to exceptions only (closes [#2561](http://sogo.nu/bugs/view.php?id=2561))
* **core:** add support for module constraints in SQL sources
* **core:** add support for listRequiresDot in SQL sources
* **web:** add support for SearchFieldNames in SQL sources
* **web:** display freebusy information of owner in appointment editor
* **web:** register SOGo as a handler for the mailto scheme (closes [#1223](http://sogo.nu/bugs/view.php?id=1223))
* **web:** new events list view where events are grouped by day
* **web:** user setting to always show mail editor inside current window or in popup window
* **web:** add support for events with recurrence dates (RDATE)

### Enhancements

* **web:** follow requested URL after user authentication
* **web:** added Simplified Chinese (zh_CN) translation - thanks to Thomas Kuiper
* **web:** now also give modify permission when selecting all calendar rights
* **web:** allow edition of IMAP flags associated to mail labels
* **web:** search scope of address book is now respected
* **web:** avoid redirection to forbidden module (via ModulesConstraints)
* **web:** lower constraints on dates range of auto-reply message (closes [#4161](http://sogo.nu/bugs/view.php?id=4161))
* **web:** sort categories in event and task editors (closes [#4349](http://sogo.nu/bugs/view.php?id=4349))
* **web:** show weekday in headers of day view
* **web:** improve display of overlapping events with categories
* **web:** updated Angular Material to version 1.1.6

### Bug Fixes

* **core:** yearly repeating events are not shown in web calendar (closes [#4237](http://sogo.nu/bugs/view.php?id=4237))
* **core:** increased column size of settings/defaults for MySQL (closes [#4260](http://sogo.nu/bugs/view.php?id=4260))
* **core:** fixed yearly recurrence calculator with until date
* **core:** generalized HTML sanitization to avoid encoding issues when replying/forwarding mails
* **core:** don't expose web calendars to other users (closes [#4331](http://sogo.nu/bugs/view.php?id=4331))
* **web:** fixed display of error when the mail editor is in a popup
* **web:** attachments are not displayed on IOS (closes [#4150](http://sogo.nu/bugs/view.php?id=4150))
* **web:** fixed parsing of pasted email addresses from Spreadsheet (closes [#4258](http://sogo.nu/bugs/view.php?id=4258))
* **web:** messages list not accessible when changing mailbox in expanded mail view (closes [#4269](http://sogo.nu/bugs/view.php?id=4269))
* **web:** only one postal address of same type is saved (closes [#4091](http://sogo.nu/bugs/view.php?id=4091))
* **web:** improve handling of email notifications of a calendar properties
* **web:** fixed XSRF cookie path when changing password (closes [#4139](http://sogo.nu/bugs/view.php?id=4139))
* **web:** spaces can now be inserted in address book names
* **web:** prevent the creation of empty contact categories
* **web:** fixed mail composition from message headers (closes [#4335](http://sogo.nu/bugs/view.php?id=4335))
* **web:** restore messages selection after automatic refresh (closes [#4330](http://sogo.nu/bugs/view.php?id=4330))
* **web:** fixed path of destination mailbox in Sieve filter editor
* **web:** force copy of dragged contacts from global address books
* **web:** removed null characters from JSON responses
* **web:** fixed advanced mailbox search when mailbox name is very long
* **web:** fixed handling of public access rights of Calendars (closes [#4344](http://sogo.nu/bugs/view.php?id=4344))
* **web:** fixed server-side CSS sanitization of messages (closes [#4366](http://sogo.nu/bugs/view.php?id=4366))
* **web:** cards list not accessible when changing address book in expanded card view
* **web:** added missing subject to junk/not junk reports
* **web:** fixed file uploader URL in mail editor
* **web:** fixed decoding of spaces in URL-encoded parameters (+)
* **web:** fixed scrolling of message with Firefox (closes [#4008](http://sogo.nu/bugs/view.php?id=4008), closes [#4282](http://sogo.nu/bugs/view.php?id=4282), closes [#4398](http://sogo.nu/bugs/view.php?id=4398))
* **web:** save original username in cookie when remembering login (closes [#4363](http://sogo.nu/bugs/view.php?id=4363))
* **web:** allow to set a reminder on a task with a due date
* **eas:** hebrew folders encoding problem using EAS (closes [#4240](http://sogo.nu/bugs/view.php?id=4240))
* **eas:** avoid sync requests for shared folders every second (closes [#4275](http://sogo.nu/bugs/view.php?id=4275))
* **eas:** we skip the organizer from the attendees list (closes [#4402](http://sogo.nu/bugs/view.php?id=4402))
* **eas:** correctly handle all-day events with EAS v16 (closes [#4397](http://sogo.nu/bugs/view.php?id=4397))
* **eas:** fixed EAS save in drafts with attachments

## [3.2.10](https://github.com/inverse-inc/sogo/compare/SOGo-3.2.9...SOGo-3.2.10) (2017-07-05)

### Features

* **web:** new images viewer in Mail module
* **web:** create list from selected cards (closes [#3561](http://sogo.nu/bugs/view.php?id=3561))
* **eas:** initial EAS v16 and email drafts support
* **core:** load-testing scripts to evaluate SOGo performance

### Enhancements

* **core:** now possible to {un}subscribe to folders using sogo-tool
* **web:** AngularJS optimizations in Mail module
* **web:** AngularJS optimization of color picker
* **web:** improve display of tasks status
* **web:** added custom fields support from Thunderbird's address book
* **web:** added Latvian (lv) translation - thanks to Juris Balandis
* **web:** expose user's defaults and settings inline
* **web:** can now discard incoming mails during vacation
* **web:** support both backspace and delete keys in Mail and Contacts modules
* **web:** improved display of appointment/task comments and card notes
* **web:** updated Angular Material to version 1.1.4
* **web:** updated CKEditor to version 4.7.1

### Bug Fixes

* **web:** respect SOGoLanguage and SOGoSupportedLanguages (closes [#4169](http://sogo.nu/bugs/view.php?id=4169))
* **web:** fixed adding list members with multiple email addresses
* **web:** fixed responsive condition of login page (960px to 1023px)
* **web:** don't throw errors when accessing nonexistent special mailboxes (closes [#4177](http://sogo.nu/bugs/view.php?id=4177))
* **core:** newly subscribed calendars are excluded from freebusy (closes [#3354](http://sogo.nu/bugs/view.php?id=3354))
* **core:** don't update subscriptions when owner is not the active user (closes [#3988](http://sogo.nu/bugs/view.php?id=3988))
* **core:** strip cr during LDIF import process (closes [#4172](http://sogo.nu/bugs/view.php?id=4172))
* **core:** email alarms are sent too many times (closes [#4100](http://sogo.nu/bugs/view.php?id=4100))
* **core:** enable S/MIME even when using GNU TLS (closes [#4201](http://sogo.nu/bugs/view.php?id=4201))
* **core:** silence verbose output for sogo-ealarms-notify (closes [#4170](http://sogo.nu/bugs/view.php?id=4170))
* **eas:** don't include task folders if we hide them in SOGo (closes [#4164](http://sogo.nu/bugs/view.php?id=4164))

## [3.2.9](https://github.com/inverse-inc/sogo/compare/SOGo-3.2.8...SOGo-3.2.9) (2017-05-09)

### Features

* **core:** email alarms now have pretty formatting (closes [#805](http://sogo.nu/bugs/view.php?id=805))

### Enhancements

* **core:** improved event invitation for all day events (closes [#4145](http://sogo.nu/bugs/view.php?id=4145))
* **web:** improved interface refresh time with external IMAP accounts
* **eas:** added photo support for GAL search operations

### Bug Fixes

* **web:** fixed attachment path when inside multiple body parts
* **web:** fixed email reminder with attendees (closes [#4115](http://sogo.nu/bugs/view.php?id=4115))
* **web:** prevented form to be marked dirty when changing password (closes [#4138](http://sogo.nu/bugs/view.php?id=4138))
* **web:** restored support for SOGoLDAPContactInfoAttribute
* **web:** avoid duplicated email addresses in LDAP-based addressbook (closes [#4129](http://sogo.nu/bugs/view.php?id=4129))
* **web:** fixed mail delegation of pristine user accounts (closes [#4160](http://sogo.nu/bugs/view.php?id=4160))
* **core:** cherry-picked comma escaping fix from v2 (closes [#3296](http://sogo.nu/bugs/view.php?id=3296))
* **core:** fix sogo-tool restore potentially crashing on corrupted data (closes [#4048](http://sogo.nu/bugs/view.php?id=4048))
* **core:** handle properly mails using windows-1255 charset (closes [#4124](http://sogo.nu/bugs/view.php?id=4124))
* **core:** fixed email reminders sent multiple times (closes [#4100](http://sogo.nu/bugs/view.php?id=4100))
* **core:** fixed LDIF to vCard conversion for non-handled multi-value attributes (closes [#4086](http://sogo.nu/bugs/view.php?id=4086))
* **core:** properly honor the "include in freebusy" setting (closes [#3354](http://sogo.nu/bugs/view.php?id=3354))
* **core:** make sure to use crypt scheme when encoding md5/sha256/sha512 (closes [#4137](http://sogo.nu/bugs/view.php?id=4137))
* **eas:** set reply/forwarded flags when ReplaceMime is set (closes [#4133](http://sogo.nu/bugs/view.php?id=4133))
* **eas:** remove alarms over EAS if we don't want them (closes [#4059](http://sogo.nu/bugs/view.php?id=4059))
* **eas:** correctly set RSVP on event invitations
* **eas:** avoid sending IMIP request/update messages for all EAS clients (closes [#4022](http://sogo.nu/bugs/view.php?id=4022))

## [3.2.8](https://github.com/inverse-inc/sogo/compare/SOGo-3.2.7...SOGo-3.2.8) (2017-03-24)

### Features

* **core:** new sogo-tool manage-acl command to manage calendar/address book ACLs

### Enhancements

* **web:** constrain event/task reminder to a positive number
* **web:** display year in day and week views
* **web:** split string on comma and semicolon when pasting multiple addresses (closes [#4097](http://sogo.nu/bugs/view.php?id=4097))
* **web:** restrict Draft/Sent/Trash/Junk mailboxes to the top level
* **web:** animations are automatically disabled under IE11
* **web:** updated Angular Material to version 1.1.3

### Bug Fixes

* **core:** handle broken CalDAV clients sending bogus SENT-BY (closes [#3992](http://sogo.nu/bugs/view.php?id=3992))
* **core:** fixed handling of exdates and proper intersection for fbinfo (closes [#4051](http://sogo.nu/bugs/view.php?id=4051))
* **core:** remove attendees that have the same identity as the organizer (closes [#3905](http://sogo.nu/bugs/view.php?id=3905))
* **web:** fixed ACL editor in admin module for Safari (closes [#4036](http://sogo.nu/bugs/view.php?id=4036))
* **web:** fixed function call when removing contact category (closes [#4039](http://sogo.nu/bugs/view.php?id=4039))
* **web:** localized mailbox names everywhere (closes [#4040](http://sogo.nu/bugs/view.php?id=4040), closes [#4041](http://sogo.nu/bugs/view.php?id=4041))
* **web:** hide fab button when printing (closes [#4038](http://sogo.nu/bugs/view.php?id=4038))
* **web:** SOGoCalendarWeekdays must now be defined before saving preferences
* **web:** fixed CAS session timeout handling during XHR requests (closes [#1456](http://sogo.nu/bugs/view.php?id=1456))
* **web:** exposed default value of SOGoMailAutoSave (closes [#4053](http://sogo.nu/bugs/view.php?id=4053))
* **web:** exposed default value of SOGoMailAddOutgoingAddresses (closes [#4064](http://sogo.nu/bugs/view.php?id=4064))
* **web:** fixed handling of contact organizations (closes [#4028](http://sogo.nu/bugs/view.php?id=4028))
* **web:** fixed handling of attachments in mail editor (closes [#4058](http://sogo.nu/bugs/view.php?id=4058), closes [#4063](http://sogo.nu/bugs/view.php?id=4063))
* **web:** fixed saving draft outside Mail module (closes [#4071](http://sogo.nu/bugs/view.php?id=4071))
* **web:** fixed SCAYT automatic language selection in HTML editor
* **web:** fixed task sorting on multiple categories
* **web:** fixed sanitisation of flags in Sieve filters (closes [#4087](http://sogo.nu/bugs/view.php?id=4087))
* **web:** fixed missing CC or BCC when specified before sending message (closes [#3944](http://sogo.nu/bugs/view.php?id=3944))
* **web:** enabled Save button after deleting attributes from a card (closes [#4095](http://sogo.nu/bugs/view.php?id=4095))
* **web:** don't show Copy To and Move To menu options when user has a single address book
* **web:** fixed display of category colors in events and tasks lists
* **eas:** fixed opacity in EAS freebusy (closes [#4033](http://sogo.nu/bugs/view.php?id=4033))

## [3.2.7](https://github.com/inverse-inc/sogo/compare/SOGo-3.2.6...SOGo-3.2.7) (2017-02-14)

### Features

* **core:** new sogo-tool checkup command to make sure user's data is sane

### Enhancements

* **web:** added Hebrew (he) translation - thanks to Raz Aidlitz

### Bug Fixes

* **core:** generalized the bcc handling code
* **web:** saving the preferences was not possible when Mail module is disabled
* **web:** ignore mouse events in scrollbars of Month view (closes [#3990](http://sogo.nu/bugs/view.php?id=3990))
* **web:** fixed public URL with special characters (closes [#3993](http://sogo.nu/bugs/view.php?id=3993))
* **web:** keep the fab button visible when the center list is hidden
* **web:** localized mail, phone, url and address types (closes [#4030](http://sogo.nu/bugs/view.php?id=4030))
* **eas:** improved EAS parameters parsing (closes [#4003](http://sogo.nu/bugs/view.php?id=4003))
* **eas:** properly handle canceled appointments

## [3.2.6a](https://github.com/inverse-inc/sogo/compare/SOGo-3.2.5...SOGo-3.2.6a) (2017-01-26)

### Bug Fixes

* **core:** fixed "include in freebusy" (reverts closes [#3354](http://sogo.nu/bugs/view.php?id=3354))
* **web:** improved ACLs handling of inactive users

## [3.2.6](https://github.com/inverse-inc/sogo/compare/SOGo-3.2.5...SOGo-3.2.6) (2017-01-23)

### Enhancements

* **web:** show locale codes beside language names in Preferences module
* **web:** fixed visual glitches in Month view with Firefox
* **web:** mail editor can now be expanded horizontally and automatically expands vertically
* **web:** compose a new message inline or in a popup window
* **web:** allow to select multiple files when uploading attachments (closes [#3999](http://sogo.nu/bugs/view.php?id=3999))
* **web:** use "date" extension of Sieve to enable/disable vacation auto-reply (closes [#1530](http://sogo.nu/bugs/view.php?id=1530), closes [#1949](http://sogo.nu/bugs/view.php?id=1949))
* **web:** updated Angular to version 1.6.1
* **web:** updated CKEditor to version 4.6.2

### Bug Fixes

* **core:** remove all alarms before sending IMIP replies (closes [#3925](http://sogo.nu/bugs/view.php?id=3925))
* **web:** fixed rendering of forwared HTML message with inline images (closes [#3981](http://sogo.nu/bugs/view.php?id=3981))
* **web:** fixed pasting images in CKEditor using Chrome (closes [#3986](http://sogo.nu/bugs/view.php?id=3986))
* **eas:** make sure we trigger a download of service-side changed events
* **eas:** now strip attendees with no email during MeetingResponse calls

## [3.2.5](https://github.com/inverse-inc/sogo/compare/SOGo-3.2.4...SOGo-3.2.5) (2017-01-10)

### Features

* **web:** download attachments of a message as a zip archive

### Enhancements

* **core:** improved IMIP handling from Exchange/Outlook clients
* **web:** prevent using localhost on additional IMAP accounts
* **web:** renamed buttons of alarm toast (closes [#3945](http://sogo.nu/bugs/view.php?id=3945))
* **web:** load photos of LDAP-based address books in contacts list (closes [#3942](http://sogo.nu/bugs/view.php?id=3942))
* **web:** added SOGoMaximumMessageSizeLimit to limit webmail message size
* **web:** added photo support for LDIF import (closes [#1084](http://sogo.nu/bugs/view.php?id=1084))
* **web:** updated CKEditor to version 4.6.1

### Bug Fixes

* **core:** honor blocking wrong login attempts within time interval (closes [#2850](http://sogo.nu/bugs/view.php?id=2850))
* **core:** better support for RFC 6638 (schedule-agent)
* **core:** use source's domain when none defined and trying to match users (closes [#3523](http://sogo.nu/bugs/view.php?id=3523))
* **core:** handle delegation with no SENT-BY set (closes [#3368](http://sogo.nu/bugs/view.php?id=3368))
* **core:** properly honor the "include in freebusy" setting (closes [#3354](http://sogo.nu/bugs/view.php?id=3354))
* **core:** properly save next email alarm in the database (closes [#3949](http://sogo.nu/bugs/view.php?id=3949))
* **core:** fix events in floating time during CalDAV's PUT operation (closes [#2865](http://sogo.nu/bugs/view.php?id=2865))
* **core:** handle rounds in sha512-crypt password hashes
* **web:** fixed confusion between owner and active user in ACLs management of Administration module
* **web:** fixed JavaScript exception after renaming an address book
* **web:** fixed Sieve folder encoding support (closes [#3904](http://sogo.nu/bugs/view.php?id=3904))
* **web:** fixed ordering of calendars when renaming or adding a calendar (closes [#3931](http://sogo.nu/bugs/view.php?id=3931))
* **web:** use the organizer's alarm by default when accepting IMIP messages (closes [#3934](http://sogo.nu/bugs/view.php?id=3934))
* **web:** switch on "Remember username" when cookie username is set
* **web:** return login page for unknown users (closes [#2135](http://sogo.nu/bugs/view.php?id=2135))
* **web:** fixed saving monthly recurrence rule with "by day" condition (closes [#3948](http://sogo.nu/bugs/view.php?id=3948))
* **web:** fixed display of message content when enabling auto-reply (closes [#3940](http://sogo.nu/bugs/view.php?id=3940))
* **web:** don't allow to create lists in a remote address book (not yet supported)
* **web:** fixed attached links in task viewer (closes [#3963](http://sogo.nu/bugs/view.php?id=3963))
* **web:** avoid duplicate mail entries in contact of LDAP-based address book (closes [#3941](http://sogo.nu/bugs/view.php?id=3941))
* **web:** append ics file extension when importing events (closes [#2308](http://sogo.nu/bugs/view.php?id=2308))
* **web:** handle URI in vCard photos (closes [#2683](http://sogo.nu/bugs/view.php?id=2683))
* **web:** handle semicolon in values during LDIF import (closes [#1760](http://sogo.nu/bugs/view.php?id=1760))
* **web:** fixed computation of week number (closes [#3973](http://sogo.nu/bugs/view.php?id=3973), closes [#3976](http://sogo.nu/bugs/view.php?id=3976))
* **web:** fixed saving of inactive calendars (closes [#3862](http://sogo.nu/bugs/view.php?id=3862), closes [#3980](http://sogo.nu/bugs/view.php?id=3980))
* **web:** fixed public URLs to Calendars (closes [#3974](http://sogo.nu/bugs/view.php?id=3974))
* **web:** fixed hotkeys in Mail module when a dialog is active (closes [#3983](http://sogo.nu/bugs/view.php?id=3983))
* **eas:** properly skip folders we don't want to synchronize (closes [#3943](http://sogo.nu/bugs/view.php?id=3943))
* **eas:** fixed 30 mins freebusy offset with S Planner
* **eas:** now correctly handles reminders on tasks (closes [#3964](http://sogo.nu/bugs/view.php?id=3964))
* **eas:** always force save events creation over EAS (closes [#3958](http://sogo.nu/bugs/view.php?id=3958))
* **eas:** do not decode from hex the event's UID (closes [#3965](http://sogo.nu/bugs/view.php?id=3965))
* **eas:** add support for "other addresses" (closes [#3966](http://sogo.nu/bugs/view.php?id=3966))
* **eas:** provide correct response status when sending too big mails (closes [#3956](http://sogo.nu/bugs/view.php?id=3956))

## [3.2.4](https://github.com/inverse-inc/sogo/compare/SOGo-3.2.3...SOGo-3.2.4) (2016-12-01)

### Features

* **core:** new sogo-tool cleanup user feature

### Enhancements

* **core:** added handling of BYSETPOS for BYDAY in recurrence rules
* **web:** added sort by start date for tasks (closes [#3840](http://sogo.nu/bugs/view.php?id=3840))

### Bug Fixes

* **web:** fixed JavaScript exception when SOGo is launched from an external link (closes [#3900](http://sogo.nu/bugs/view.php?id=3900))
* **web:** restored fetching of freebusy information of MS Exchange contacts
* **web:** fixed mail attribute when importing an LDIF file (closes [#3878](http://sogo.nu/bugs/view.php?id=3878))
* **web:** don't save empty custom auto-reply subject
* **web:** fixed detection of session expiration
* **eas:** properly escape all GAL responses (closes [#3923](http://sogo.nu/bugs/view.php?id=3923))

## [3.2.3](https://github.com/inverse-inc/sogo/compare/SOGo-3.2.2...SOGo-3.2.3) (2016-11-25)

### Features

* **core:** added photo support for LDAP-based address books (closes [#747](http://sogo.nu/bugs/view.php?id=747), closes [#2184](http://sogo.nu/bugs/view.php?id=2184))

### Enhancements

* **web:** updated CKEditor to version 4.6.0
* **web:** updated Angular to version 1.5.9

### Bug Fixes

* **web:** restore attributes when rewriting base64-encoded img tags (closes [#3814](http://sogo.nu/bugs/view.php?id=3814))
* **web:** improve alarms dialog (closes [#3909](http://sogo.nu/bugs/view.php?id=3909))
* **eas:** fixed EAS delete operation

## [3.2.2](https://github.com/inverse-inc/sogo/compare/SOGo-3.2.1...SOGo-3.2.2) (2016-11-23)

### Features

* **core:** support repetitive email alarms on tasks and events (closes [#1053](http://sogo.nu/bugs/view.php?id=1053))
* **web:** allow to hide center column on large screens (closes [#3861](http://sogo.nu/bugs/view.php?id=3861))
* **eas:** relaxed permission requirements for subscription synchronizations (closes [#3118](http://sogo.nu/bugs/view.php?id=3118), closes [#3180](http://sogo.nu/bugs/view.php?id=3180))

### Enhancements

* **core:** added sha256-crypt and sha512-crypt password support
* **core:** updated time zones to version 2016i
* **eas:** now also search on senders when using EAS Search ops
* **web:** allow multiple messages to be marked as seen (closes [#3873](http://sogo.nu/bugs/view.php?id=3873))
* **web:** use switches instead of checkboxes in Calendars module

### Bug Fixes

* **core:** fixed condition in weekly recurrence calculator
* **core:** always send IMIP messages using UTF-8
* **web:** fixed mail settings persistence when sorting by arrival date
* **web:** disable submit button while saving an event or a task (closes [#3880](http://sogo.nu/bugs/view.php?id=3880))
* **web:** disable submit button while saving a contact
* **web:** fixed computation of week number
* **web:** fixed and improved IMAP folder subscriptions manager (closes [#3865](http://sogo.nu/bugs/view.php?id=3865))
* **web:** fixed Sieve script activation when vacation start date is in the future (closes [#3885](http://sogo.nu/bugs/view.php?id=3885))
* **web:** fixed moving a component without the proper rights (closes [#3889](http://sogo.nu/bugs/view.php?id=3889))
* **web:** restored Sieve folder encoding support (closes [#3904](http://sogo.nu/bugs/view.php?id=3904))
* **web:** allow edition of a mailbox rights when user can administer mailbox

## [3.2.1](https://github.com/inverse-inc/sogo/compare/SOGo-3.2.0...SOGo-3.2.1) (2016-11-02)

### Enhancements

* **web:** add constraints to start/end dates of automatic responder (closes [#3841](http://sogo.nu/bugs/view.php?id=3841))
* **web:** allow a mailbox to be deleted immediately (closes [#3875](http://sogo.nu/bugs/view.php?id=3875))
* **web:** updated Angular to version 1.5.8
* **eas:** initial support for recurring tasks EAS
* **eas:** now support replied/forwarded flags using EAS (closes [#3796](http://sogo.nu/bugs/view.php?id=3796))
* **core:** updated time zones to version 2016h

### Bug Fixes

* **web:** fixed tasks list when some weekdays are disabled
* **web:** fixed automatic refresh of calendar view
* **web:** respect SOGoSearchMinimumWordLength in contacts list editor
* **web:** improved memory usage when importing very large address books
* **web:** fixed progress indicator while importing cards or events and tasks
* **web:** improved detection of changes in CKEditor (closes [#3839](http://sogo.nu/bugs/view.php?id=3839))
* **web:** fixed vCard generation for tags with no type (closes [#3826](http://sogo.nu/bugs/view.php?id=3826))
* **web:** only show the organizer field of an IMIP REPLY if one is defined
* **web:** fixed saving the note of a card (closes [#3849](http://sogo.nu/bugs/view.php?id=3849))
* **web:** fixed support for recurrent tasks (closes [#3864](http://sogo.nu/bugs/view.php?id=3864))
* **web:** restored support for alarms in tasks
* **web:** improved validation of mail account delegators
* **web:** fixed auto-completion of list members (closes [#3870](http://sogo.nu/bugs/view.php?id=3870))
* **web:** added missing options to subscribed addressbooks (closes [#3850](http://sogo.nu/bugs/view.php?id=3850))
* **web:** added missing options to subscribed calendars (closes [#3863](http://sogo.nu/bugs/view.php?id=3863))
* **web:** fixed resource conflict error handling (403 vs 409 HTTP code) (closes [#3837](http://sogo.nu/bugs/view.php?id=3837))
* **web:** restored immediate deletion of messages (without moving them to the trash)
* **web:** avoid mail notifications on superfluous event changes (closes [#3790](http://sogo.nu/bugs/view.php?id=3790))
* **web:** CKEditor: added the pastefromexcel plugin (closes [#3854](http://sogo.nu/bugs/view.php?id=3854))
* **eas:** improve handling of email folders without a parent
* **eas:** never send IMIP reply when the "initiator" is Outlook 2013/2016
* **core:** only consider SMTP addresses for AD's proxyAddresses (closes [#3842](http://sogo.nu/bugs/view.php?id=3842))
* **core:** sogo-tool manage-eas now works with single store mode

## [3.2.0](https://github.com/inverse-inc/sogo/releases/tag/SOGo-3.2.0) (2016-10-03)

### Features

* **web:** added IMAP folder subscriptions management (closes [#255](http://sogo.nu/bugs/view.php?id=255))
* **web:** keyboard hotkeys (closes [#1711](http://sogo.nu/bugs/view.php?id=1711), closes [#1467](http://sogo.nu/bugs/view.php?id=1467), closes [#3817](http://sogo.nu/bugs/view.php?id=3817))
* **eas:** initial support for server-side mailbox search operations

### Enhancements

* **web:** don't allow a recurrence rule to end before the first occurrence
* **web:** updated Angular Material to version 1.1.1
* **web:** show user's name upon successful login
* **web:** inserted unseen messages count and mailbox name in browser's window title
* **web:** disable JavaScript theme generation when SOGoUIxDebugEnabled is set to NO
* **web:** added Serbian (sr) translation - thanks to Bogdanović Bojan
* **web:** added sort by arrival date in Mail module (closes [#708](http://sogo.nu/bugs/view.php?id=708))
* **web:** restored "now" line in Calendar module
* **web:** updated CKEditor to version 4.5.11
* **web:** allow custom email address to be one of the user's profile (closes [#3551](http://sogo.nu/bugs/view.php?id=3551))
* **eas:** propagate message submission errors to EAS clients (closes [#3774](http://sogo.nu/bugs/view.php?id=3774))

### Bug Fixes

* **eas:** properly generate the BusyStatus for normal events
* **eas:** properly escape all email and address fields
* **eas:** properly generate yearly rrule
* **eas:** make sure we don't sleep for too long when EAS processes need interruption
* **eas:** fixed recurring events with timezones for EAS (closes [#3822](http://sogo.nu/bugs/view.php?id=3822))
* **web:** restored functionality to save unknown recipient emails to address book on send
* **web:** fixed ripple blocking the form when submitting no values (closes [#3808](http://sogo.nu/bugs/view.php?id=3808))
* **web:** fixed error handling when renaming a mailbox
* **web:** handle binary content transfer encoding when displaying mails
* **web:** removed resize grips to short events (closes [#3771](http://sogo.nu/bugs/view.php?id=3771))
* **core:** strip protocol value from proxyAddresses attribute (closes [#3182](http://sogo.nu/bugs/view.php?id=3182))
* **core:** we now search in all domain sources for Apple Calendar
* **core:** properly handle groups in Apple Calendar's delegation
* **core:** fixed caching expiration of ACLs assigned to LDAP groups (closes [#2867](http://sogo.nu/bugs/view.php?id=2867))
* **core:** make sure new cards always have a UID (closes [#3819](http://sogo.nu/bugs/view.php?id=3819))
* **core:** fixed default TRANSP value when creating event

## [3.1.5](https://github.com/inverse-inc/sogo/compare/SOGo-3.1.4...SOGo-3.1.5) (2016-08-10)

### Features

* **web:** drag'n'drop of messages in the Mail module (closes [#3497](http://sogo.nu/bugs/view.php?id=3497), closes [#3586](http://sogo.nu/bugs/view.php?id=3586), closes [#3734](http://sogo.nu/bugs/view.php?id=3734), closes [#3788](http://sogo.nu/bugs/view.php?id=3788))
* **web:** drag'n'drop of cards in the AddressBook module
* **eas:** added folder merging capabilities

### Enhancements

* **web:** improve action progress when login in or sending a message (closes [#3765](http://sogo.nu/bugs/view.php?id=3765), closes [#3761](http://sogo.nu/bugs/view.php?id=3761))
* **web:** don't allow to send the message while an upload is in progress
* **web:** notify when successfully copied or moved some messages
* **web:** restored indicator in the top banner when a vacation message (auto-reply) is active
* **web:** removed animation when dragging an event to speed up rendering
* **web:** expunge drafts mailbox when a draft is sent and deleted
* **web:** actions of Sieve filters are now sortable
* **web:** show progress indicator when refreshing events/tasks lists
* **web:** updated CKEditor to version 4.5.10

### Bug Fixes

* **web:** fixed refresh of addressbook when deleting one or many cards
* **web:** reset multiple-selection mode after deleting cards, events or tasks
* **web:** fixed exception when moving tasks to a different calendar
* **web:** fixed printing of long mail (closes [#3731](http://sogo.nu/bugs/view.php?id=3731))
* **web:** fixed position of ghost block when creating an event from DnD
* **web:** fixed avatar image in autocompletion
* **web:** restored expunge of current mailbox when leaving the Mail module
* **web:** added support for multiple description values in LDAP entries (closes [#3750](http://sogo.nu/bugs/view.php?id=3750))
* **web:** don't allow drag'n'drop of invitations
* **eas:** fixed long GUID issue preventing sometimes synchronisation (closes [#3460](http://sogo.nu/bugs/view.php?id=3460))
* **core:** fixing sogo-tool backup with multi-domain configuration but domain-less logins
* **core:** during event scheduling, use 409 instead of 403 so Lightning doesn't fail silently
* **core:** correctly calculate recurrence exceptions when not overlapping the recurrence id
* **core:** prevent invalid SENT-BY handling during event invitations (closes [#3759](http://sogo.nu/bugs/view.php?id=3759))

## [3.1.4](https://github.com/inverse-inc/sogo/compare/SOGo-3.1.3...SOGo-3.1.4) (2016-07-12)

### Features

* **core:** new sogo-tool truncate-calendar feature (closes [#1513](http://sogo.nu/bugs/view.php?id=1513), closes [#3141](http://sogo.nu/bugs/view.php?id=3141))
* **eas:** initial Out-of-Office support in EAS
* **oc:** initial support for calendar and address book sharing with OpenChange

### Enhancements

* **eas:** use the preferred email identity in EAS if valid (closes [#3698](http://sogo.nu/bugs/view.php?id=3698))
* **eas:** handle inline attachments during EAS content generation
* **web:** all batch operations can now be performed on selected messages in advanced search mode
* **web:** add date picker to change date, week, or month of current Calendar view
* **web:** style cancelled events in Calendar module
* **web:** replace sortable library for better support with Firefox
* **web:** stage-1 tuning of sgColorPicker directive
* **oc:** better handling of nested attachments with OpenChange

### Bug Fixes

* **web:** fixed crash when an attachment filename has no extension
* **web:** fixed selection of transparent all-day events (closes [#3744](http://sogo.nu/bugs/view.php?id=3744))
* **web:** leaving the dropping area while dragging a file was blocking the mail editor
* **web:** fixed scrolling of all-day events (closes [#3190](http://sogo.nu/bugs/view.php?id=3190))
* **eas:** handle base64 EAS protocol version
* **eas:** handle missing IMAP folders from a hierarchy using EAS

## [3.1.3](https://github.com/inverse-inc/sogo/compare/SOGo-3.1.2...SOGo-3.1.3) (2016-06-22)

### Features

* **core:** now possible to define default Sieve filters (closes [#2949](http://sogo.nu/bugs/view.php?id=2949))
* **core:** now possible to set vacation message start date (closes [#3679](http://sogo.nu/bugs/view.php?id=3679))
* **web:** add a header and/or footer to the vacation message (closes [#1961](http://sogo.nu/bugs/view.php?id=1961))
* **web:** specify a custom subject for the vacation message (closes [#685](http://sogo.nu/bugs/view.php?id=685), closes [#1447](http://sogo.nu/bugs/view.php?id=1447))

### Enhancements

* **core:** when restoring data using sogo-tool, regenerate Sieve script (closes [#3029](http://sogo.nu/bugs/view.php?id=3029))
* **web:** always display name of month in week view (closes [#3724](http://sogo.nu/bugs/view.php?id=3724))
* **web:** use a speed dial (instead of a dialog) for card/list creation
* **web:** use a speed dial for event/task creation
* **web:** CSS is now minified using clean-css

### Bug Fixes

* **core:** properly handle sorted/deleted calendars (closes [#3723](http://sogo.nu/bugs/view.php?id=3723))
* **core:** properly handle flattened timezone definitions (closes [#2690](http://sogo.nu/bugs/view.php?id=2690))
* **web:** fixed generic avatar in lists (closes [#3719](http://sogo.nu/bugs/view.php?id=3719))
* **web:** fixed validation in Sieve filter editor
* **web:** properly encode rawsource of events and tasks to avoid XSS issues (closes [#3718](http://sogo.nu/bugs/view.php?id=3718))
* **web:** properly encode rawsource of cards to avoid XSS issues
* **web:** fixed all-day events covering a timezone change (closes [#3457](http://sogo.nu/bugs/view.php?id=3457))
* **web:** sgTimePicker parser now respects the user's time format and language
* **web:** fixed time format when user chooses the default one
* **web:** added missing delegators identities in mail editor (closes [#3720](http://sogo.nu/bugs/view.php?id=3720))
* **web:** honour the domain default SOGoAppointmentSendEMailNotifications (closes [#3729](http://sogo.nu/bugs/view.php?id=3729))
* **web:** the login module parameter is now properly restored when set as "Last used"
* **web:** if cn isn't found for shared mailboxes, use email address (closes [#3733](http://sogo.nu/bugs/view.php?id=3733))
* **web:** fixed handling of attendees when updating an event
* **web:** show tooltips over long calendar/ab names (closes [#232](http://sogo.nu/bugs/view.php?id=232))
* **web:** one-click option to give all permissions for user (closes [#1637](http://sogo.nu/bugs/view.php?id=1637))
* **web:** never query gravatar.com when disabled

## [3.1.2](https://github.com/inverse-inc/sogo/compare/SOGo-3.1.1...SOGo-3.1.2) (2016-06-06)

### Enhancements

* **web:** updated Angular Material to version 1.1.0rc5

### Bug Fixes

* **web:** fixed error handling when renaming a mailbox
* **web:** fixed user removal from ACLs in Administration module (closes [#3713](http://sogo.nu/bugs/view.php?id=3713))
* **web:** fixed event classification icon (private/confidential) in month view (closes [#3711](http://sogo.nu/bugs/view.php?id=3711))
* **web:** CKEditor: added the pastefromword plugin (closes [#2295](http://sogo.nu/bugs/view.php?id=2295), closes [#3313](http://sogo.nu/bugs/view.php?id=3313))
* **web:** fixed loading of card from global addressbooks
* **web:** fixed negative offset when saving an all-day event (closes [#3717](http://sogo.nu/bugs/view.php?id=3717))

## [3.1.1](https://github.com/inverse-inc/sogo/compare/SOGo-3.1.0...SOGo-3.1.1) (2016-06-02)

### Enhancements

* **web:** expose all email addresses in autocompletion of message editor (closes [#3443](http://sogo.nu/bugs/view.php?id=3443))
* **web:** Gravatar service can now be disabled (closes [#3600](http://sogo.nu/bugs/view.php?id=3600))
* **web:** collapsable mail accounts (closes [#3493](http://sogo.nu/bugs/view.php?id=3493))
* **web:** show progress indicator when loading messages and cards
* **web:** display messages sizes in list of Mail module
* **web:** link event's attendees email addresses to mail composer
* **web:** respect SOGoSearchMinimumWordLength when searching for events or tasks
* **web:** updated CKEditor to version 4.5.9
* **web:** CKEditor: switched to the minimalist skin
* **web:** CKEditor: added the base64image plugin

### Bug Fixes

* **core:** strip X- tags when securing content (closes [#3695](http://sogo.nu/bugs/view.php?id=3695))
* **web:** fixed creation of chip on blur (sgTransformOnBlur directive)
* **web:** fixed composition of new messages from Contacts module
* **web:** fixed autocompletion of LDAP-based groups (closes [#3673](http://sogo.nu/bugs/view.php?id=3673))
* **web:** fixed month view when current month covers six weeks (closes [#3663](http://sogo.nu/bugs/view.php?id=3663))
* **web:** fixed negative offset when converting a regular event to an all-day event (closes [#3655](http://sogo.nu/bugs/view.php?id=3655))
* **web:** fixed event classification icon (private/confidential) in day/week/multicolumn views
* **web:** fixed display of mailboxes list on mobiles (closes [#3654](http://sogo.nu/bugs/view.php?id=3654))
* **web:** restored Catalan and Slovak translations (closes [#3687](http://sogo.nu/bugs/view.php?id=3687))
* **web:** fixed restore of mailboxes expansion state when multiple IMAP accounts are configured
* **web:** improved CSS sanitizer for HTML messages (closes [#3700](http://sogo.nu/bugs/view.php?id=3700))
* **web:** fixed toolbar of mail editor when sender address was too long (closes [#3705](http://sogo.nu/bugs/view.php?id=3705))
* **web:** fixed decoding of filename in attachments (quotes and Cyrillic characters) (closes [#2272](http://sogo.nu/bugs/view.php?id=2272))
* **web:** fixed recipients when replying from a message in the Sent mailbox (closes [#2625](http://sogo.nu/bugs/view.php?id=2625))
* **eas:** when using EAS/ItemOperations, use IMAP PEEK operation

## [3.1.0](https://github.com/inverse-inc/sogo/releases/tag/SOGo-3.1.0) (2016-05-18)

### Features

* **core:** new database structure options to make SOGo use a total of nine tables
* **core:** new user-based rate-limiting support for all SOGo requests (closes [#3188](http://sogo.nu/bugs/view.php?id=3188))
* **web:** toolbar of all-day events can be expanded to display all events
* **web:** added AngularJS's XSRF support (closes [#3246](http://sogo.nu/bugs/view.php?id=3246))
* **web:** calendars list can be reordered and filtered
* **web:** user can limit the calendars view to specific week days (closes [#1841](http://sogo.nu/bugs/view.php?id=1841))

### Enhancements

* **web:** updated Angular Material to version 1.1.0rc4
* **web:** added Lithuanan (lt) translation - thanks to Mantas Liobė
* **web:** added Turkish (Turkey) (tr_TR) translation - thanks to Sinan Kurşunoğlu
* **web:** we now "cc" delegates during invitation updates (closes [#3195](http://sogo.nu/bugs/view.php?id=3195))
* **web:** new SOGoHelpURL preference to set a custom URL for SOGo help (closes [#2768](http://sogo.nu/bugs/view.php?id=2768))
* **web:** now able to copy/move events and also duplicate them (closes [#3196](http://sogo.nu/bugs/view.php?id=3196))
* **web:** improved preferences validation and now check for unsaved changes
* **web:** display events and tasks priorities in list and day/week views (closes [#3162](http://sogo.nu/bugs/view.php?id=3162))
* **web:** style events depending on the user participation state
* **web:** style transparent events (show time as free) (closes [#3192](http://sogo.nu/bugs/view.php?id=3192))
* **web:** improved input parsing of time picker (closes [#3659](http://sogo.nu/bugs/view.php?id=3659))
* **web:** restored support for Web calendars that require authentication

### Bug Fixes

* **core:** properly escape wide characters (closes [#3616](http://sogo.nu/bugs/view.php?id=3616))
* **core:** avoid double-appending domains in cache for multi-domain configurations (closes [#3614](http://sogo.nu/bugs/view.php?id=3614))
* **core:** fixed multidomain issue with non-unique ID accross domains (closes [#3625](http://sogo.nu/bugs/view.php?id=3625))
* **core:** fixed bogus headers generation when stripping folded bcc header (closes [#3664](http://sogo.nu/bugs/view.php?id=3664))
* **core:** fixed issue with multi-value org units (closes [#3630](http://sogo.nu/bugs/view.php?id=3630))
* **core:** sanity checks for events with bogus timezone offsets
* **web:** fixed missing columns in SELECT statements (PostgreSQL)
* **web:** fixed display of ghosts when dragging events
* **web:** fixed management of mail labels in Preferences module
* **web:** respect super user privileges to create in any calendar and addressbook (closes [#3533](http://sogo.nu/bugs/view.php?id=3533))
* **web:** properly null-terminate IS8601-formatted dates (closes [#3539](http://sogo.nu/bugs/view.php?id=3539))
* **web:** display CC/BCC fields in message editor when initialized with values
* **web:** fixed message initialization in popup window (closes [#3583](http://sogo.nu/bugs/view.php?id=3583))
* **web:** create chip (recipient) on blur (closes [#3470](http://sogo.nu/bugs/view.php?id=3470))
* **web:** fixed position of warning when JavaScript is disabled (closes [#3449](http://sogo.nu/bugs/view.php?id=3449))
* **web:** respect the LDAP attributes mapping in the list view
* **web:** handle empty body data when forwarding mails (closes [#3581](http://sogo.nu/bugs/view.php?id=3581))
* **web:** show repeating events when we ask for "All" or "Future" events (#69)
* **web:** show the To instead of From when we are in the Sent folder (closes [#3547](http://sogo.nu/bugs/view.php?id=3547))
* **web:** fixed handling of mail tags in mail viewer
* **web:** avoid marking mails as read when archiving a folder (closes [#2792](http://sogo.nu/bugs/view.php?id=2792))
* **web:** fixed crash when sending a message with a special priority
* **web:** fixed saving of a custom weekly recurrence definition
* **web:** properly escape the user's display name (closes [#3617](http://sogo.nu/bugs/view.php?id=3617))
* **web:** avoid returning search results on objects without read permissions (closes [#3619](http://sogo.nu/bugs/view.php?id=3619))
* **web:** restore priority of event or task in component editor
* **web:** fixed menu content visibility when printing an email (closes [#3584](http://sogo.nu/bugs/view.php?id=3584))
* **web:** retired CSS reset so the style of HTML messages is respected (closes [#3582](http://sogo.nu/bugs/view.php?id=3582))
* **web:** fixed messages archiving as zip file
* **web:** adapted time picker to match changes of md calendar picker
* **web:** fixed sender addresses of draft when using multiple IMAP accounts (closes [#3577](http://sogo.nu/bugs/view.php?id=3577))
* **web:** create a new message when clicking on a "mailto" link (closes [#3588](http://sogo.nu/bugs/view.php?id=3588))
* **web:** fixed handling of Web calendars option "reload on login"
* **web:** add recipient chip when leaving an input field (to/cc/bcc) (closes [#3470](http://sogo.nu/bugs/view.php?id=3470))
* **dav:** we now handle the default classifications for tasks (closes [#3541](http://sogo.nu/bugs/view.php?id=3541))
* **eas:** properly unfold long mail headers (closes [#3152](http://sogo.nu/bugs/view.php?id=3152))
* **eas:** correctly set EAS message class for S/MIME messages (closes [#3576](http://sogo.nu/bugs/view.php?id=3576))
* **eas:** handle FilterType changes using EAS (closes [#3543](http://sogo.nu/bugs/view.php?id=3543))
* **eas:** handle Dovecot's mail_shared_explicit_inbox parameter
* **eas:** prevent concurrent Sync ops from same device (closes [#3603](http://sogo.nu/bugs/view.php?id=3603))
* **eas:** handle EAS loop termination when SOGo is being shutdown (closes [#3604](http://sogo.nu/bugs/view.php?id=3604))
* **eas:** now cache heartbeat interval and folders list during Ping ops (closes [#3606](http://sogo.nu/bugs/view.php?id=3606))
* **eas:** sanitize non-us-ascii 7bit emails (closes [#3592](http://sogo.nu/bugs/view.php?id=3592))
* **eas:** properly escape organizer name (closes [#3615](http://sogo.nu/bugs/view.php?id=3615))
* **eas:** correctly set answered/forwarded flags during smart operations
* **eas:** don't mark calendar invitations as read when fetching messages

## [3.0.2](https://github.com/inverse-inc/sogo/releases/tag/SOGo-3.0.2) (2016-03-04)

### Features

* **web:** show all/only this calendar
* **web:** convert a message to an appointment or a task (closes [#1722](http://sogo.nu/bugs/view.php?id=1722))
* **web:** customizable base font size for HTML messages
* [web you can now limit the file upload size using the WOMaxUploadSize configuration parameter (integer value in kilobytes) (closes [#3510](http://sogo.nu/bugs/view.php?id=3510), closes [#3135](http://sogo.nu/bugs/view.php?id=3135))

### Enhancements

* **web:** added Junk handling feature from v2
* **web:** updated Material Icons font to version 2.1.3
* **web:** don't offer forward/vacation options in filters if not enabled
* **web:** mail filters are now sortable
* **web:** now supports RFC6154 and NoInferiors IMAP flag
* **web:** improved confirm dialogs for deletions
* **web:** allow resources to prevent invitations (closes [#3410](http://sogo.nu/bugs/view.php?id=3410))
* **web:** warn when double-booking attendees and offer force save option
* **web:** list search now displays a warning regarding the minlength constraint
* **web:** loading an LDAP-based addressbook is now instantaneous when listRequiresDot is disabled (closes [#438](http://sogo.nu/bugs/view.php?id=438), closes [#3464](http://sogo.nu/bugs/view.php?id=3464))
* **web:** improve display of messages with many recipients
* **web:** colorize categories chips in event and task viewers
* **web:** initial stylesheet for printing (closes [#3484](http://sogo.nu/bugs/view.php?id=3484))
* **web:** updated lodash to version 4.6.1
* **i18n:** updated French and Finnish translations
* **eas:** now support EAS MIME truncation

### Bug Fixes

* **web:** handle birthday dates before 1970 (closes [#3567](http://sogo.nu/bugs/view.php?id=3567))
* **web:** safe-guarding against bogus value coming from the quick tables
* **web:** apply search filters when automatically reloading current mailbox (closes [#3507](http://sogo.nu/bugs/view.php?id=3507))
* **web:** fixed virtual repeater when moving up in messages list
* **web:** really delete mailboxes being deleted from the Trash folder (closes [#595](http://sogo.nu/bugs/view.php?id=595), closes [#1189](http://sogo.nu/bugs/view.php?id=1189), closes [#641](http://sogo.nu/bugs/view.php?id=641))
* **web:** fixed address autocompletion of mail editor affecting cards list of active addressbook
* **web:** fixed batched delete of components (closes [#3516](http://sogo.nu/bugs/view.php?id=3516))
* **web:** fixed mail draft autosave in preferences (closes [#3519](http://sogo.nu/bugs/view.php?id=3519))
* **web:** fixed password change (closes [#3496](http://sogo.nu/bugs/view.php?id=3496))
* **web:** fixed saving of notification email for calendar changes (closes [#3522](http://sogo.nu/bugs/view.php?id=3522))
* **web:** fixed ACL editor for authenticated users in Mail module
* **web:** fixed fab button position in Calendar module (closes [#3462](http://sogo.nu/bugs/view.php?id=3462))
* **web:** fixed default priority of sent messages (closes [#3542](http://sogo.nu/bugs/view.php?id=3542))
* **web:** removed double-quotes from Chinese (Taiwan) translations that were breaking templates
* **web:** fixed unseen count retrieval of nested IMAP folders
* **web:** properly extract the mail column values from an SQL contacts source (closes [#3544](http://sogo.nu/bugs/view.php?id=3544))
* **web:** fixed incorrect date formatting when timezone was after UTC+0 (closes [#3481](http://sogo.nu/bugs/view.php?id=3481), closes [#3494](http://sogo.nu/bugs/view.php?id=3494))
* **web:** replaced checkboxes in menu by a custom checkmark (closes [#3557](http://sogo.nu/bugs/view.php?id=3557))
* **web:** fixed attachments display when forwarding a message (closes [#3560](http://sogo.nu/bugs/view.php?id=3560))
* **web:** activate new calendar subscriptions by default
* **web:** keep specified task status when not completed (closes [#3499](http://sogo.nu/bugs/view.php?id=3499))
* **eas:** allow EAS attachments get on 2nd-level mailboxes (closes [#3505](http://sogo.nu/bugs/view.php?id=3505))
* **eas:** fix EAS bday shift (closes [#3518](http://sogo.nu/bugs/view.php?id=3518))
* **eas:** encode CR in EAS payload (closes [#3626](http://sogo.nu/bugs/view.php?id=3626))

## [3.0.1](https://github.com/inverse-inc/sogo/releases/tag/SOGo-3.0.1) (2016-02-05)

### Enhancements

* **web:** improved scrolling behavior when deleting a single message (closes [#3489](http://sogo.nu/bugs/view.php?id=3489))
* **web:** added "Move To" option for selected messages (closes [#3477](http://sogo.nu/bugs/view.php?id=3477))
* **web:** updated CKEditor to version 4.5.7
* **web:** updated Angular Material to 1.0.5
* **web/eas:** add shared/public namespaces in the list or returned folders

### Bug Fixes

* **web:** safeguard against mailboxes with no quota (closes [#3468](http://sogo.nu/bugs/view.php?id=3468))
* **web:** fixed blank calendar view when selecting "Descending Order" in the sort menu
* **web:** show active user's default email address instead of system email address (closes [#3473](http://sogo.nu/bugs/view.php?id=3473))
* **web:** fixed display of HTML tags when viewing a message raw source (closes [#3490](http://sogo.nu/bugs/view.php?id=3490))
* **web:** fixed IMIP accept/decline when there is only one MIME part
* **web:** improved handling of IMAP connection problem in Web interface
* **web:** fixed frequency parsing of recurrence rule when saving new appointment (closes [#3472](http://sogo.nu/bugs/view.php?id=3472))
* **web:** added support for %p in date formatting (closes [#3480](http://sogo.nu/bugs/view.php?id=3480))
* **web:** make sure an email is defined before trying to use it (closes [#3488](http://sogo.nu/bugs/view.php?id=3488))
* **web:** handle broken messages that have no date (closes [#3498](http://sogo.nu/bugs/view.php?id=3498))
* **web:** fixed virtual-repeater display in Webmail when a search is performed (closes [#3500](http://sogo.nu/bugs/view.php?id=3500))
* **web:** fixed drag'n'drop of all-day events in multicolumn view
* **eas:** correctly encode filename of attachments over EAS (closes [#3491](http://sogo.nu/bugs/view.php?id=3491))

## [3.0.0](https://github.com/inverse-inc/sogo/releases/tag/SOGo-3.0.0) (2016-01-27)

### Features

* complete rewrite of the JavaScript frontend using Angular and AngularMaterial
* responsive design and accessible options focused on mobile devices
* horizontal 3-pane view for a better experience on large desktop screens
* new color palette and better contrast ratio as recommended by the W3C
* improved accessibility to persons with disabilities by enabling common ARIA attributes
* use of Mozilla's Fira Sans typeface
* and many more!

## [2.3.7](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.6...SOGo-2.3.7) (2016-01-25)

### Features

* new junk/not junk capability with generic SMTP integration

### Enhancements

* newly created folders using EAS are always sync'ed by default (closes [#3454](http://sogo.nu/bugs/view.php?id=3454))
* added Croatian (hr_HR) translation - thanks to Jens Riecken

### Bug Fixes

* now always generate invitation updates when using EAS
* rewrote the string sanitization to be 32-bit Unicode safe
* do not try to decode non-wbxml responses for debug output (closes [#3444](http://sogo.nu/bugs/view.php?id=3444))

## [2.3.6](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.5...SOGo-2.3.6) (2016-01-18)

### Features

* now able to sync only default mail folders when using EAS

### Enhancements

* Unit testing for RTFHandler
* JUnit output for sogo-tests

### Bug Fixes

* don't unescape twice mail folder names (closes [#3423](http://sogo.nu/bugs/view.php?id=3423))
* don't consider mobile Outlook EAS clients as DAV ones (closes [#3431](http://sogo.nu/bugs/view.php?id=3431))
* we now follow 301 redirects when fetching ICS calendars
* when deleting an event using EAS, properly invoke the auto-scheduling code
* do not include failure attachments (really long filenames)
* fix encoding of email subjects with non-ASCII characters
* fix appointment notification mails using SOGoEnableDomainBasedUID configuration
* fix shifts in event times on Outlook

## [2.3.5](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.4...SOGo-2.3.5) (2016-01-05)

### Enhancements

* return an error to openchange if mail message delivery fails
* return the requested elements on complex requests from Outlook when downloading changes
* user sources can be loaded dynamically
* unify user sources API
* updated Russian translation (closes [#3383](http://sogo.nu/bugs/view.php?id=3383))

### Bug Fixes

* properly compute the last week number for the year (closes [#1010](http://sogo.nu/bugs/view.php?id=1010))
* share calendar, tasks and contacts folders in Outlook 2013 with editor permissions
* priorize filename in Content-Disposition against name in Content-Type to get the filename of an attachment in mail
* request all contacts when there is no filter in Contacts menu in Webmail
* personal contacts working properly on Outlook
* fixes on RTF parsing used by event/contact description and mail as RTF to read non-ASCII characters: better parsing of font table, when using a font, switch to its character set, correct parsing of escaped characters and Unicode character command word support for unicode characters greater than 32767
* no crash resolving recipients after reconnecting LDAP connection
* avoid creation of phantom contacts in SOGo from distribution list synced from Outlook.
* accepted & updated event names are now shown correctly in Outlook
* provide safe guards in mail and calendar to avoid exceptions while syncing

## [2.3.4](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.3...SOGo-2.3.4) (2015-12-15)

### Features

* initial support for EAS calendar exceptions

### Enhancements

* limit the maximum width of toolbar buttons (closes [#3381](http://sogo.nu/bugs/view.php?id=3381))
* updated CKEditor to version 4.5.6

### Bug Fixes

* JavaScript exception when printing events from calendars with no assigned color (closes [#3203](http://sogo.nu/bugs/view.php?id=3203))
* EAS fix for wrong charset being used (closes [#3392](http://sogo.nu/bugs/view.php?id=3392))
* EAS fix on qp-encoded subjects (closes [#3390](http://sogo.nu/bugs/view.php?id=3390))
* correctly handle all-day event exceptions when the master event changes
* prevent characters in calendar component UID causing issues during import process
* avoid duplicating attendees when accepting event using a different identity over CalDAV

## [2.3.3a](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.2...SOGo-2.3.3a) (2015-11-18)

### Bug Fixes

* expanded mail folders list is not saved (closes [#3386](http://sogo.nu/bugs/view.php?id=3386))
* cleanup translations

## [2.3.3](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.2...SOGo-2.3.3) (2015-11-11)

### Features

* initial S/MIME support for EAS (closes [#3327](http://sogo.nu/bugs/view.php?id=3327))
* now possible to choose which folders to sync over EAS

### Enhancements

* we no longer always entirely rewrite messages for Outlook 2013 when using EAS
* support for ghosted elements on contacts over EAS
* added Macedonian (mk_MK) translation - thanks to Miroslav Jovanovic
* added Portuguese (pt) translation - thanks to Eduardo Crispim

### Bug Fixes

* numerous EAS fixes when connections are dropped before the EAS client receives the response (closes [#3058](http://sogo.nu/bugs/view.php?id=3058), closes [#2849](http://sogo.nu/bugs/view.php?id=2849))
* correctly handle the References header over EAS (closes [#3365](http://sogo.nu/bugs/view.php?id=3365))
* make sure English is always used when generating Date headers using EAS (closes [#3356](http://sogo.nu/bugs/view.php?id=3356))
* don't escape quoted strings during versit generation
* we now return all cards when we receive an empty addressbook-query REPORT
* avoid crash when replying to a mail with no recipients (closes [#3359](http://sogo.nu/bugs/view.php?id=3359))
* inline images sent from SOGo webmail are not displayed in Mozilla Thunderbird (closes [#3271](http://sogo.nu/bugs/view.php?id=3271))
* prevent postal address showing on single line over EAS (closes [#2614](http://sogo.nu/bugs/view.php?id=2614))
* display missing events when printing working hours only
* fix corner case making server crash when syncing hard deleted messages when clear offline items was set up (Zentyal)
* avoid infinite Outlook client loops trying to set read flag when it is already set (Zentyal)
* avoid crashing when calendar metadata is missing in the cache (Zentyal)
* fix recurrence pattern event corner case created by Mozilla Thunderbird which made server crash (Zentyal)
* fix corner case that removes attachments on sending messages from Outlook (Zentyal)
* freebusy on web interface works again in multidomain environments (Zentyal)
* fix double creation of folders in Outlook when the folder name starts with a digit (Zentyal)
* avoid crashing Outlook after setting a custom view in a calendar folder (Zentyal)
* handle emails having an attachment as their content
* fixed JavaScript syntax error in attendees editor
* fixed wrong comparison of meta vs. META tag in HTML mails
* fixed popup menu position when moved to the left (closes [#3381](http://sogo.nu/bugs/view.php?id=3381))
* fixed dialog position when at the bottom of the window (closes [#2646](http://sogo.nu/bugs/view.php?id=2646), closes [#3378](http://sogo.nu/bugs/view.php?id=3378))

## [2.3.2](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.1...SOGo-2.3.2) (2015-09-16)

### Enhancements

* improved EAS speed and memory usage, avoiding many IMAP LIST commands (closes [#3294](http://sogo.nu/bugs/view.php?id=3294))
* improved EAS speed during initial syncing of large mailboxes (closes [#3293](http://sogo.nu/bugs/view.php?id=3293))
* updated CKEditor to version 4.5.3

### Bug Fixes

* fixed display of whitelisted attendees in Preferences window on Firefox (closes [#3285](http://sogo.nu/bugs/view.php?id=3285))
* non-latin subfolder names are displayed correctly on Outlook (Zentyal)
* fixed several sync issues on environments with multiple users (Zentyal)
* folders from other users will no longer appear on your Outlook (Zentyal)
* use right auth in multidomain environments in contacts and calendar from Outlook (Zentyal)
* session fix when SOGoEnableDomainBasedUID is enabled but logins are domain-less
* less sync issues when setting read flag (Zentyal)
* attachments with non-latin filenames sent by Outlook are now received (Zentyal)
* support attachments from more mail clients (Zentyal)
* avoid conflicting message on saving a draft mail (Zentyal)
* less conflicting messages in Outlook while moving messages between folders (Zentyal)
* start/end shifting by 1 hour due to timezone change on last Sunday of October 2015 (closes [#3344](http://sogo.nu/bugs/view.php?id=3344))
* fixed localization of calendar categories with empty profile (closes [#3295](http://sogo.nu/bugs/view.php?id=3295))
* fixed options availability in contextual menu of Contacts module (closes [#3342](http://sogo.nu/bugs/view.php?id=3342))

## [2.3.1](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.0...SOGo-2.3.1) (2015-07-23)

### Enhancements

* improved EAS speed, especially when fetching big attachments
* now always enforce the organizer's default identity in appointments
* improved the handling of default calendar categories/colors (closes [#3200](http://sogo.nu/bugs/view.php?id=3200))
* added support for DeletesAsMoves over EAS
* added create-folder subcommand to sogo-tool to create contact and calendar folders
* group mail addresses can be used as recipient in Outlook
* added 'ActiveSync' module constraints
* updated CKEditor to version 4.5.1
* added Slovenian translation - thanks to Jens Riecken
* added Chinese (Taiwan) translation

### Bug Fixes

* EAS's GetItemEstimate/ItemOperations now support fetching mails and empty folders
* fixed some rare cornercases in multidomain configurations
* properly escape folder after creation using EAS (closes [#3237](http://sogo.nu/bugs/view.php?id=3237))
* fixed potential organizer highjacking when using EAS (closes [#3131](http://sogo.nu/bugs/view.php?id=3131))
* properly support big characters in EAS and fix encoding QP EAS error for Outlook (closes [#3082](http://sogo.nu/bugs/view.php?id=3082))
* properly encode id of DOM elements in Address Book module (closes [#3239](http://sogo.nu/bugs/view.php?id=3239), closes [#3245](http://sogo.nu/bugs/view.php?id=3245))
* fixed multi-domain support for sogo-tool backup/restore (closes [#2600](http://sogo.nu/bugs/view.php?id=2600))
* fixed data ordering in events list of Calendar module (closes [#3261](http://sogo.nu/bugs/view.php?id=3261))
* fixed data ordering in tasks list of Calendar module (closes [#3267](http://sogo.nu/bugs/view.php?id=3267))
* Android EAS Lollipop fixes (closes [#3268](http://sogo.nu/bugs/view.php?id=3268) and closes [#3269](http://sogo.nu/bugs/view.php?id=3269))
* improved EAS email flagging handling (closes [#3140](http://sogo.nu/bugs/view.php?id=3140))
* fixed computation of GlobalObjectId (closes [#3235](http://sogo.nu/bugs/view.php?id=3235))
* fixed EAS conversation ID issues on BB10 (closes [#3152](http://sogo.nu/bugs/view.php?id=3152))
* fixed CR/LF printing in event's description (closes [#3228](http://sogo.nu/bugs/view.php?id=3228))
* optimized Calendar module in multidomain configurations

## [2.3.0](https://github.com/inverse-inc/sogo/releases/tag/SOGo-2.3.0) (2015-06-01)

### Features

* Internet headers are now shown in Outlook (Zentyal)

### Enhancements

* improved multipart handling using EAS
* added systemd startup script (PR#76)
* added Basque translation - thanks to Gorka Gonzalez
* updated Brazilian (Portuguese), Dutch, Norwegian (Bokmal), Polish, Russian, and Spanish (Spain) translations
* calendar sharing request support among different Outlook versions (Zentyal)
* improved sync speed from Outlook by non-reprocessing already downloaded unread mails (Zentyal)
* added support for sharing calendar invitations
* missing contact fields are now saved and available when sharing it (Office, Profession, Manager's name, Assistant's name, Spouse/Partner, Anniversary) (Zentyal)
* appointment color and importance work now between Outlooks (Zentyal)
* synchronize events, contacts and tasks in reverse chronological order (Zentyal)
* during login, we now extract the domain from the user to accelerate authentication requests on sources
* make sure sure email invitations can always be read by EAS clients
* now able to print event/task's description (new components only) in the list view (closes [#2881](http://sogo.nu/bugs/view.php?id=2881))
* now possible to log EAS commands using the SOGoEASDebugEnabled system defaults
* many improvements to EAS SmartReply/SmartForward commands
* event invitation response mails from Outlook are now sent
* mail subfolders created in WebMail are created when Outlook synchronises
* mail root folder created in WebMail (same level INBOX) are created on Outlook logon

### Bug Fixes

* now keep the BodyPreference for future EAS use and default to MIME if none set (closes [#3146](http://sogo.nu/bugs/view.php?id=3146))
* EAS reply fix when message/rfc822 parts are included in the original mail (closes [#3153](http://sogo.nu/bugs/view.php?id=3153))
* fixed yet an other potential crash during freebusy lookups during timezone changes
* fixed display of freebusy information in event attendees editor during timezone changes
* fixed timezone of MSExchange freebusy information
* fixed a potential EAS error with multiple email priority flags
* fixed paragraphs margins in HTML messages (closes [#3163](http://sogo.nu/bugs/view.php?id=3163))
* fixed regression when loading the inbox for the first time
* fixed serialization of the PreventInvitationsWhitelist settings
* fixed md4 support (for NTLM password changes) with GNU TLS
* fixed edition of attachment URL in event/task editor
* sent mails are not longer in Drafts folder using Outlook (Zentyal)
* deleted mails are properly synced between Outlook profiles from the same account (Zentyal)
* does not create a mail folder in other user's mailbox (Zentyal)
* fix server-side crash with invalid events (Zentyal)
* fix setting permissions for a folder with several users (Zentyal)
* fix reception of calendar event invitations on optional attendees (Zentyal)
* fix server side crash parsing rtf without color table (Zentyal)
* weekly recurring events created in SOGo web interface are now shown in Outlook (Zentyal)
* fix exception modifications import in recurrence series (Zentyal)
* fix server side crash parsing rtf emails with images (with word97 format) (Zentyal)
* fix sender on importing email messages like event invitations (Zentyal)
* fix Outlook crashes when modifying the view of a folder (Zentyal)
* fix server side crash when reading some recurrence appointments (Zentyal)
* Outlook clients can use reply all functionality on multidomain environment (Zentyal)
* optional attendes on events are now shown properly (Zentyal)
* fixed the EAS maximum response size being per-folder, and not global
* now set MeetingMessageType only for EAS 14.1
* now correctly handle external invitations using EAS
* now correctly handle multiple email addresses in the GAL over EAS (closes [#3102](http://sogo.nu/bugs/view.php?id=3102))
* now handle very large amount of participants correctly (closes [#3175](http://sogo.nu/bugs/view.php?id=3175))
* fix message bodies not shown on some EAS devices (closes [#3173](http://sogo.nu/bugs/view.php?id=3173))
* avoid appending the domain unconditionally when SOGoEnableDomainBasedUID is set to YES
* recurrent all day events are now shown properly in Outlook

## [2.2.17a](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.16...SOGo-2.2.17a) (2015-03-15)

### Bug Fixes

* avoid calling -stringByReplacingOccurrencesOfString:... for old GNUstep runtime

## [2.2.17](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.16...SOGo-2.2.17) (2015-03-24)

### Enhancements

* support for mail prority using EAS
* immediately delete mails from EAS clients when they are marked as deleted on the IMAP server
* now favor login@domain as the default email address if multiple mail: fields are specified
* enable by default HTML mails support using EAS on Windows and BB phones
* now possible to configure objectClass names for LDAP groups using GroupObjectClasses (closes [#1499](http://sogo.nu/bugs/view.php?id=1499))

### Bug Fixes

* fixed login issue after password change (closes [#2601](http://sogo.nu/bugs/view.php?id=2601))
* fixed potential encoding issue using EAS and 8-bit mails (closes [#3116](http://sogo.nu/bugs/view.php?id=3116))
* multiple collections support for GetItemEstimate using EAS
* fixed empty sync responses for EAS 2.5 and 12.0 clients
* use the correct mail body element for EAS 2.5 clients
* fixed tasks disappearing issue with RoadSync
* use the correct body element for events for EAS 2.5 clients
* SmartReply improvements for missing body attributes
* do not use syncKey from cache when davCollectionTag = -1
* use correct mail attachment elements for EAS 2.5 clients
* fixed contacts lookup by UID in freebusy
* reduced telephone number to a single value in JSON response of contacts list
* fixed freebusy data when 'busy off hours' is enabled and period starts during the weekend
* fixed fetching of freebusy data from the Web interface
* fixed EAS handling of Bcc in emails (closes [#3138](http://sogo.nu/bugs/view.php?id=3138))
* fixed Language-Region tags in Web interface (closes [#3121](http://sogo.nu/bugs/view.php?id=3121))
* properly fallback over EAS to UTF-8 and then Latin1 for messages w/o charset (closes [#3103](http://sogo.nu/bugs/view.php?id=3103))
* prevent potential freebusy lookup crashes during timezone changes with repetitive events
* improved GetItemEstimate to count all vasnished/deleted mails too
* improvements to EAS SyncKey handling to avoid missing mails (closes [#3048](http://sogo.nu/bugs/view.php?id=3048), closes [#3058](http://sogo.nu/bugs/view.php?id=3058))
* fixed EAS replies decoding from Outlook (closes [#3123](http://sogo.nu/bugs/view.php?id=3123))

## [2.2.16](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.15...SOGo-2.2.16) (2015-02-12)

### Features

* now possible for SOGo to change the sambaNTPassword/sambaLMPassword
* now possible to limit automatic forwards to internal/external domains

### Enhancements

* added support for email categories using EAS (closes [#2995](http://sogo.nu/bugs/view.php?id=2995))
* now possible to always send vacation messages (closes [#2332](http://sogo.nu/bugs/view.php?id=2332))
* added EAS best practices to the documentation
* improved fetching of text parts over EAS
* updated Czech, Finnish, French, German and Hungarian translations

### Bug Fixes

* (regression) fixed sending a message when mail module is not active (closes [#3088](http://sogo.nu/bugs/view.php?id=3088))
* mail labels with blanks are not handled correctly (closes [#3078](http://sogo.nu/bugs/view.php?id=3078))
* fixed BlackBerry issues sending multiple mails over EAS (closes [#3095](http://sogo.nu/bugs/view.php?id=3095))
* fixed plain/text mails showing on one line on Android/EAS (closes [#3055](http://sogo.nu/bugs/view.php?id=3055))
* fixed exception in sogo-tool when parsing arguments of a set operation

## [2.2.15](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.14...SOGo-2.2.15) (2015-01-30)

### Enhancements

* improved handling of EAS Push when no heartbeat is provided
* no longer need to kill Outlook 2013 when creating EAS profiles (closes [#3076](http://sogo.nu/bugs/view.php?id=3076))
* improved server-side CSS cleaner (closes [#3040](http://sogo.nu/bugs/view.php?id=3040))
* unified the logging messages in sogo.log file (closes [#2534](http://sogo.nu/bugs/view.php?id=2534)/closes [#3063](http://sogo.nu/bugs/view.php?id=3063))
* updated Brazilian (Portuguese) and Hungarian translations

## [2.2.14](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.13...SOGo-2.2.14) (2015-01-20)

### Enhancements

* MultipleBookingsFieldName can be set to -1 to show busy status when booked at least once
* handle multipart objects in EAS/ItemOperations

### Bug Fixes

* fixed calendar selection in event and task editors (closes [#3049](http://sogo.nu/bugs/view.php?id=3049), closes [#3050](http://sogo.nu/bugs/view.php?id=3050))
* check for resources existence when listing subscribed ones (closes [#3054](http://sogo.nu/bugs/view.php?id=3054))
* correctly recognize Apple Calendar on Yosemite (closes [#2960](http://sogo.nu/bugs/view.php?id=2960))
* fixed two potential autorelease pool leaks (closes [#3026](http://sogo.nu/bugs/view.php?id=3026) and closes [#3051](http://sogo.nu/bugs/view.php?id=3051))
* fixed birthday offset in EAS
* fixed From's full name over EAS
* fixed potential issue when handling multiple Add/Change/Delete/Fetch EAS commands (closes [#3057](http://sogo.nu/bugs/view.php?id=3057))
* fixed wrong timezone calculation on recurring events

## [2.2.13](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.12...SOGo-2.2.13) (2014-12-30)

### Enhancements

* initial support for empty sync request/response for EAS
* added the SOGoMaximumSyncResponseSize EAS configuration parameter to support memory-limited sync response sizes
* we now not only use the creation date for event's cutoff date (EAS)

### Bug Fixes

* fixed contact description truncation on WP8 phones (closes [#3028](http://sogo.nu/bugs/view.php?id=3028))
* fixed freebusy information not always returned
* fixed tz issue when the user one was different from the system one with EAS

## [2.2.12a](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.11...SOGo-2.2.12a) (2014-12-19)

### Bug Fixes

* fixed empty HTML mails being sent (closes [#3034](http://sogo.nu/bugs/view.php?id=3034))

## [2.2.12](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.11...SOGo-2.2.12) (2014-12-18)

### Features

* allow including or not freebusy info from subscribed calendars
* now possible to set an autosave timer for draft messages
* now possible to set alarms on event invitations (#76)

### Enhancements

* updated CKEditor to version 4.4.6 and added the 'Source Area' plugin
* avoid testing for IMAP ANNOTATION when X-GUID is available (closes [#3018](http://sogo.nu/bugs/view.php?id=3018))
* updated Czech, Dutch, Finnish, French, German, Polish and Spanish (Spain) translations

### Bug Fixes

* fixed for privacy and categories for EAS (closes [#3022](http://sogo.nu/bugs/view.php?id=3022))
* correctly set MeetingStatus for EAS on iOS devices
* Ubuntu Lucid fixes for EAS
* fixed calendar reminders for future events (closes [#3008](http://sogo.nu/bugs/view.php?id=3008))
* make sure all text parts are UTF-8 re-encoded for Outlook 2013 over EAS (closes [#3003](http://sogo.nu/bugs/view.php?id=3003))
* fixed task description truncation affecting WP8 phones over EAS (closes [#3028](http://sogo.nu/bugs/view.php?id=3028))

## [2.2.11a](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.10...SOGo-2.2.11a) (2014-12-10)

### Bug Fixes

* make sure all address books returned using EAS are GCS ones

## [2.2.11](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.10...SOGo-2.2.11) (2014-12-09)

### Features

* sogo-tool can now be used to manage EAS metadata for all devices

### Enhancements

* improved the SAML2 documentation
* radically reduced AES memory usage

### Bug Fixes

* now possible to specify the username attribute for SAML2 (SOGoSAML2LoginAttribute) (closes [#2381](http://sogo.nu/bugs/view.php?id=2381))
* added support for IdP-initiated SAML2 logout (closes [#2377](http://sogo.nu/bugs/view.php?id=2377))
* we now generate SAML2 metadata on the fly (closes [#2378](http://sogo.nu/bugs/view.php?id=2378))
* we now handle correctly the SOGo logout when using SAML (closes [#2376](http://sogo.nu/bugs/view.php?id=2376) and closes [#2379](http://sogo.nu/bugs/view.php?id=2379))
* fixed freebusy lookups going off bounds for resources (closes [#3010](http://sogo.nu/bugs/view.php?id=3010))
* fixed EAS clients moving mails between folders but disconnecting before receiving server's response (closes [#2982](http://sogo.nu/bugs/view.php?id=2982))

## [2.2.10](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.9...SOGo-2.2.10) (2014-11-21)

### Enhancements

* no longer leaking database passwords in the logs (closes [#2953](http://sogo.nu/bugs/view.php?id=2953))
* added support for multiple calendars and address books over ActiveSync
* updated timezone information (closes [#2968](http://sogo.nu/bugs/view.php?id=2968))
* updated Brazilian Portuguese, Czech, Dutch, Finnish, French, German, Hungarian, Polish, Russian, Spanish (Argentina), and Spanish (Spain) translations
* updated CKEditor to version 4.4.5

### Bug Fixes

* fixed freebusy lookup with "Show time as busy" (closes [#2930](http://sogo.nu/bugs/view.php?id=2930))
* don't escape <br>'s in a card's note field
* fixed folder's display name when subscribing to a folder
* fixed folder's display name when the active user subscribes another user to one of her/his folders
* fixed error with new user default sorting value for the mailer module (closes [#2952](http://sogo.nu/bugs/view.php?id=2952))
* fixed ActiveSync PING command flooding the server (closes [#2940](http://sogo.nu/bugs/view.php?id=2940))
* fixed many interop issues with Windows Phones over ActiveSync
* fixed automatic return receipts crash when not in the recepient list (closes [#2965](http://sogo.nu/bugs/view.php?id=2965))
* fixed support for Sieve folder encoding parameter (closes [#2622](http://sogo.nu/bugs/view.php?id=2622))
* fixed rename of subscribed addressbooks
* sanitize strings before escaping them when using EAS
* fixed handling of event invitations on iOS/EAS with no organizer (closes [#2978](http://sogo.nu/bugs/view.php?id=2978))
* fixed corrupted png files (closes [#2975](http://sogo.nu/bugs/view.php?id=2975))
* improved dramatically the BSON decoding speed
* added WindowSize support for GCS collections when using EAS
* fixed IMAP search with non-ASCII folder names
* fixed extraction of email addresses when pasting text with tabs (closes [#2945](http://sogo.nu/bugs/view.php?id=2945))
* fixed Outlook attachment corruption issues when using AES (closes [#2957](http://sogo.nu/bugs/view.php?id=2957))

## [2.2.9a](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.8...SOGo-2.2.9a) (2014-09-29)

### Bug Fixes

* correctly skip unallowed characters (closes [#2936](http://sogo.nu/bugs/view.php?id=2936))

## [2.2.9](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.8...SOGo-2.2.9) (2014-09-26)

### Features

* support for recurrent tasks (closes [#2160](http://sogo.nu/bugs/view.php?id=2160))
* support for alarms on recurrent events / tasks

### Enhancements

* alarms can now be snoozed for 1 day
* better iOS/Mac OS X Calendar compability regarding alarms (closes [#1920](http://sogo.nu/bugs/view.php?id=1920))
* force default classification over CalDAV if none is set (closes [#2326](http://sogo.nu/bugs/view.php?id=2326))
* now compliant when handling completed tasks (closes [#589](http://sogo.nu/bugs/view.php?id=589))
* better iOS invitations handling regarding part state (closes [#2852](http://sogo.nu/bugs/view.php?id=2852))
* fixed Mac OS X Calendar delegation issue (closes [#2837](http://sogo.nu/bugs/view.php?id=2837))
* converted ODT documentation to AsciiDoc format
* updated Czech, Dutch, Finnish, French, German, Hungarian, Norwegian (Bokmal), Polish, Russian, and Spanish (Spain) translations

### Bug Fixes

* fixed sending mails to multiple recipients over AS
* fixed freebusy support in iCal 7 and free/busy state changes (closes [#2878](http://sogo.nu/bugs/view.php?id=2878), closes [#2879](http://sogo.nu/bugs/view.php?id=2879))
* we now get rid of all potential control characters before sending the DAV response
* sync-token can now be returned during PROPFIND (closes [#2493](http://sogo.nu/bugs/view.php?id=2493))
* fixed calendar deletion on iOS/Mac OS Calendar (closes [#2838](http://sogo.nu/bugs/view.php?id=2838))

## [2.2.8](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.7...SOGo-2.2.8) (2014-09-10)

### Features

* new user settings for threads collapsing
* IMAP global search support (closes [#2670](http://sogo.nu/bugs/view.php?id=2670))

### Enhancements

* major refactoring of the GCS component saving code (dropped OGoContentStore)
* printing calendars in colors is now possible in all views; list, daily, weekly and multicolumns
* new option to print calendars events and tasks with a background color or with a border color
* labels tagging only make one AJAX call for all the selected messages instead of one AJAX call per message
* new option to print calendars events and tasks with a background color or with a border color
* all modules can now be automatically refreshed
* new configurable user defaults variables; SOGoRefreshViewCheck & SOGoRefreshViewIntervals. SOGoMailMessageCheck has been replaced by SOGoRefreshViewCheck and SOGoMailPollingIntervals has been replaced by SOGoRefreshViewIntervals
* updated Catalan, Czech, Dutch, Finnish, French, Hungarian, Norwegian, and Polish translations

### Bug Fixes

* fixed crasher when subscribing users to resources (closes [#2892](http://sogo.nu/bugs/view.php?id=2892))
* fixed encoding of new calendars and new subscriptions (JavaScript only)
* fixed display of users with no possible subscription
* fixed usage of SOGoSubscriptionFolderFormat domain default when the folder's name hasn't been changed
* fixed "sogo-tool restore -l" that was returning incorrect folder IDs
* fixed Can not delete mail when over quota (closes [#2812](http://sogo.nu/bugs/view.php?id=2812))
* fixed Events and tasks cannot be moved to other calendars using drag&drop (closes [#2759](http://sogo.nu/bugs/view.php?id=2759))
* fixed In "Multicolumn Day View" mouse position is not honored when creating an event (closes [#2864](http://sogo.nu/bugs/view.php?id=2864))
* fixed handling of messages labels (closes [#2902](http://sogo.nu/bugs/view.php?id=2902))
* fixed Apache > 2.3 configuration
* fixed freebusy retrieval during timezone changes (closes [#1240](http://sogo.nu/bugs/view.php?id=1240))

## [2.2.7](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.6...SOGo-2.2.7) (2014-07-30)

### Features

* new user preference to prevent event invitations

### Enhancements

* improved badges of active tasks count
* refresh draft folder after sending a message
* now possible to DnD events in the calendar list
* improved handling of SOGoSubscriptionFolderFormat
* JSON'ified folder subscription interface
* updated Finnish, French, German, and Spanish (Spain) translations
* updated CKEditor to version 4.4.3

### Bug Fixes

* fixed weekdays translation in the datepicker
* fixed event categories display
* fixed all-day events display in IE
* fixed rename of calendars
* we now correctly add the "METHOD:REPLY" when sending out ITIP messages from DAV clients
* fixed refresh of message headers when forwarding a message (closes [#2818](http://sogo.nu/bugs/view.php?id=2818))
* we now correctly escape all charset= in <meta> tags, not only in the <head>
* we now destroy cache objects of vanished folders

## [2.2.6](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.5...SOGo-2.2.6) (2014-07-02)

### Features

* add new 'multi-columns' calendar view (closes [#1948](http://sogo.nu/bugs/view.php?id=1948))

### Enhancements

* contacts photos are now synchronized using ActiveSync (closes [#2807](http://sogo.nu/bugs/view.php?id=2807))
* implemented the GetAttachment ActiveSync command (closes [#2808](http://sogo.nu/bugs/view.php?id=2808))
* implemented the Ping ActiveSync command
* added "soft deletes" support for ActiveSync (closes [#2734](http://sogo.nu/bugs/view.php?id=2734))
* now display the active tasks count next to calendar names (closes [#2760](http://sogo.nu/bugs/view.php?id=2760))

### Bug Fixes

* better handling of empty "Flag" messages over ActiveSync (closes [#2806](http://sogo.nu/bugs/view.php?id=2806))
* fixed Chinese charset handling (closes [#2809](http://sogo.nu/bugs/view.php?id=2809))
* fixed folder name (calendars and contacts) of new subscriptions (closes [#2801](http://sogo.nu/bugs/view.php?id=2801))
* fixed the reply/forward operation over ActiveSync (closes [#2805](http://sogo.nu/bugs/view.php?id=2805))
* fixed regression when attaching files to a reply
* wait 20 seconds (instead of 2) before deleting temporary download forms (closes [#2811](http://sogo.nu/bugs/view.php?id=2811))
* avoid raising exceptions when the db is down and we try to access the preferences module (closes [#2813](http://sogo.nu/bugs/view.php?id=2813))
* we now ignore the SCHEDULE-AGENT property when Thunderbird/Lightning sends it to avoid not-generating invitation responses for externally received IMIP messages
* improved charset handling over ActiveSync (closes [#2810](http://sogo.nu/bugs/view.php?id=2810))

## [2.2.5](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.4...SOGo-2.2.5) (2014-06-05)

### Enhancements

* new meta tag to tell IE to use the highest mode available
* updated Dutch, Finnish, German, and Polish translations

### Bug Fixes

* avoid crashing when we forward an email with no Subject header
* we no longer try to include attachments when replying to a mail
* fixed ActiveSync repetitive events issues with "Weekly" and "Monthly" ones
* fixed ActiveSync text/plain parts re-encoding issues for Outlook

## [2.2.4](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.3...SOGo-2.2.4) (2014-05-29)

### Features

* new print option in Calendar module
* now able to save unknown recipient emails to address book on send (closes [#1496](http://sogo.nu/bugs/view.php?id=1496))

### Enhancements

* Sieve folder encoding is now configurable (closes [#2622](http://sogo.nu/bugs/view.php?id=2622))
* SOGo version is now displayed in preferences window (closes [#2612](http://sogo.nu/bugs/view.php?id=2612))
* report Sieve error when saving preferences (closes [#1046](http://sogo.nu/bugs/view.php?id=1046))
* added the SOGoMaximumSyncWindowSize system default to overwrite the maximum number of items returned during an ActiveSync sync operation
* updated datepicker
* addressbooks properties are now accessible from a popup window
* extended events and tasks searches
* updated Czech, French, Hungarian, Polish, Russian, Slovak, Spanish (Argentina), and Spanish (Spain) translations
* added more sycned contact properties when using ActiveSync (closes [#2775](http://sogo.nu/bugs/view.php?id=2775))
* now possible to configure the default subscribed resource name using SOGoSubscriptionFolderFormat
* now handle server-side folder updates using ActiveSync (closes [#2688](http://sogo.nu/bugs/view.php?id=2688))
* updated CKEditor to version 4.4.1

### Bug Fixes

* fixed saved HTML content of draft when attaching a file
* fixed text nodes of HTML content handler by encoding HTML entities
* fixed iCal7 delegation issue with the "inbox" folder (closes [#2489](http://sogo.nu/bugs/view.php?id=2489))
* fixed birth date validity checks (closes [#1636](http://sogo.nu/bugs/view.php?id=1636))
* fixed URL handling (closes [#2616](http://sogo.nu/bugs/view.php?id=2616))
* improved folder rename operations using ActiveSync (closes [#2700](http://sogo.nu/bugs/view.php?id=2700))
* fixed SmartReply/Forward when ReplaceMime was omitted (closes [#2680](http://sogo.nu/bugs/view.php?id=2680))
* fixed wrong generation of weekly repetitive events with ActiveSync (closes [#2654](http://sogo.nu/bugs/view.php?id=2654))
* fixed incorrect XML data conversion with ActiveSync (closes [#2695](http://sogo.nu/bugs/view.php?id=2695))
* fixed display of events having a category with HTML entities (closes [#2703](http://sogo.nu/bugs/view.php?id=2703))
* fixed display of images in CSS background (closes [#2437](http://sogo.nu/bugs/view.php?id=2437))
* fixed limitation of Sieve script size (closes [#2745](http://sogo.nu/bugs/view.php?id=2745))
* fixed sync-token generation when no change was returned (closes [#2492](http://sogo.nu/bugs/view.php?id=2492))
* fixed the IMAP copy/move operation between subfolders in different accounts
* fixed synchronization of seen/unseen status of msgs in Webmail (closes [#2715](http://sogo.nu/bugs/view.php?id=2715))
* fixed focus of popup windows open through a contextual menu with Firefox on Windows 7
* fixed missing characters in shared folder names over ActiveSync (closes [#2709](http://sogo.nu/bugs/view.php?id=2709))
* fixed reply and forward mail templates for Brazilian Portuguese (closes [#2738](http://sogo.nu/bugs/view.php?id=2738))
* fixed newline in signature when forwarding a message as attachment in HTML mode (closes [#2787](http://sogo.nu/bugs/view.php?id=2787))
* fixed restoration of options (priority & return receipt) when editing a draft (closes [#193](http://sogo.nu/bugs/view.php?id=193))
* fixed update of participation status via CalDAV (closes [#2786](http://sogo.nu/bugs/view.php?id=2786))

## [2.2.3](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.2...SOGo-2.2.3) (2014-04-03)

### Enhancements

* updated Dutch, Hungarian, Russian and Spanish (Argentina) translations
* initial support for ActiveSync event reminders support (closes [#2681](http://sogo.nu/bugs/view.php?id=2681))
* updated CKEditor to version 4.3.4

### Bug Fixes

* fixed possible exception when retrieving the default event reminder value on 64bit architectures (closes [#2678](http://sogo.nu/bugs/view.php?id=2678))
* fixed calling unescapeHTML on null variables to avoid JavaScript exceptions in Contacts module
* fixed detection of IMAP flags support on the client side (closes [#2664](http://sogo.nu/bugs/view.php?id=2664))
* fixed the ActiveSync issue marking all mails as read when downloading them
* fixed ActiveSync's move operations not working for multiple selections (closes [#2691](http://sogo.nu/bugs/view.php?id=2691))
* fixed email validation regexp to allow gTLDs
* improved all-day events support for ActiveSync (closes [#2686](http://sogo.nu/bugs/view.php?id=2686))

## [2.2.2](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.1...SOGo-2.2.2) (2014-03-21)

### Enhancements

* updated French, Finnish, German and Spanish (Spain) translations
* added sanitization support for Outlook/ActiveSync to circumvent Outlook bugs (closes [#2667](http://sogo.nu/bugs/view.php?id=2667))
* updated CKEditor to version 4.3.3
* updated jQuery File Upload to version 9.5.7

### Bug Fixes

* fixed possible exception when retrieving the default event reminder value on 64bit architectures (closes [#2647](http://sogo.nu/bugs/view.php?id=2647), closes [#2648](http://sogo.nu/bugs/view.php?id=2648))
* disable file paste support in mail editor (closes [#2641](http://sogo.nu/bugs/view.php?id=2641))
* fixed copying/moving messages to a mail folder begining with a digit (closes [#2658](http://sogo.nu/bugs/view.php?id=2658))
* fixed unseen count for folders beginning with a digit and used in Sieve filters (closes [#2652](http://sogo.nu/bugs/view.php?id=2652))
* fixed decoding of HTML entities in reminder alerts (closes [#2659](http://sogo.nu/bugs/view.php?id=2659))
* fixed check for resource conflict when creating an event in the resource's calendar (closes [#2541](http://sogo.nu/bugs/view.php?id=2541))
* fixed construction of mail folders tree
* fixed parsing of ORG attribute in cards (closes [#2662](http://sogo.nu/bugs/view.php?id=2662))
* disabled ActiveSync provisioning for now (closes [#2663](http://sogo.nu/bugs/view.php?id=2663))
* fixed messages move in Outlook which would create duplicates (closes [#2650](http://sogo.nu/bugs/view.php?id=2650))
* fixed translations for OtherUsersFolderName and SharedFoldersName folders (closes [#2657](http://sogo.nu/bugs/view.php?id=2657))
* fixed handling of accentuated characters when filtering contacts (closes [#2656](http://sogo.nu/bugs/view.php?id=2656))
* fixed classification icon of events (closes [#2651](http://sogo.nu/bugs/view.php?id=2651))
* fixed ActiveSync's SendMail with client version <= 12.1 (closes [#2669](http://sogo.nu/bugs/view.php?id=2669))

## [2.2.1](https://github.com/inverse-inc/sogo/compare/SOGo-2.2.0...SOGo-2.2.1) (2014-03-07)

### Enhancements

* updated Czech, Dutch, Finnish, and Hungarian translations
* show current folder name in prompt dialog when renaming a mail folder

### Bug Fixes

* fixed an issue with ActiveSync when the number of messages in the mailbox was greater than the window-size specified by the client
* fixed sogo-tool operations on Sieve script (closes [#2617](http://sogo.nu/bugs/view.php?id=2617))
* fixed unsubscription when renaming an IMAP folder (closes [#2630](http://sogo.nu/bugs/view.php?id=2630))
* fixed sorting of events list by calendar name (closes [#2629](http://sogo.nu/bugs/view.php?id=2629))
* fixed wrong date format leading to Android email syncing issues (closes [#2609](http://sogo.nu/bugs/view.php?id=2609))
* fixed possible exception when retrieving the default event reminder value (closes [#2624](http://sogo.nu/bugs/view.php?id=2624))
* fixed encoding of mail folder name when creating a subfolder (closes [#2637](http://sogo.nu/bugs/view.php?id=2637))
* fixed returned date format for email messages in ActiveSync
* fixed missing 'name part' in address for email messages in ActiveSync
* fixed race condition when syncing huge amount of deleted messages over ActiveSync
* fixed encoding of string as CSS identifier when the string starts with a digit
* fixed auto-completion popupmenu when UID is a digit

## [2.2.0](https://github.com/inverse-inc/sogo/releases/tag/SOGo-2.2.0) (2014-02-24)

### Features

* initial implementation of Microsoft ActiveSync protocol
* it's now possible to set a default reminder for calendar components using SOGoCalendarDefaultReminder
* select multiple files to attach to a message or drag'n'drop files onto the mail editor; will also now display progress of uploads
* new popup menu to download all attachments of a mail
* move & copy messages between different accounts
* support for the Sieve 'body' extension (mail filter based on the body content)

### Enhancements

* we now automatically convert <img src=data...> into file attachments using CIDs to prevent Outlook issues
* updated French, Finnish, Polish, German, Russian, and Spanish (Spain) translations
* XMLHttpRequest.js is now loaded conditionaly (< IE9)
* format time in attendees invitation window according to the user's locale
* improved IE11 support
* respect signature placement when forwarding a message
* respect Sieve server capabilities
* encode messages in quoted-printable when content is bigger than 72 bytes
* we now use binary encoding in memcached (closes [#2587](http://sogo.nu/bugs/view.php?id=2587))
* warn user when overbooking a resource by creating an event in its calendar (closes [#2541](http://sogo.nu/bugs/view.php?id=2541))
* converted JavaScript alerts to inline CSS dialogs in appointment editor
* visually identify users with no freebusy information in autocompletion widget of attendees editor (closes [#2565](http://sogo.nu/bugs/view.php?id=2565))
* respect occurences of recurrent events when deleting selected events (closes [#1950](http://sogo.nu/bugs/view.php?id=1950))
* improved confirmation dialog box when deleting events and tasks
* moved the DN cache to SOGoCache - avoiding sogod restarts after RDN operations
* don't use the HTML editor with Internet Explorer 7
* add message-id header to appointment notifications (closes [#2535](http://sogo.nu/bugs/view.php?id=2535))
* detect URLs in popup of events
* improved display of a contact (closes [#2350](http://sogo.nu/bugs/view.php?id=2350))

### Bug Fixes

* don't load 'background' attribute (closes [#2437](http://sogo.nu/bugs/view.php?id=2437))
* fixed validation of subscribed folders (closes [#2583](http://sogo.nu/bugs/view.php?id=2583))
* fixed display of folder names in messages filter editor (closes [#2569](http://sogo.nu/bugs/view.php?id=2569))
* fixed contextual menu of the current calendar view (closes [#2557](http://sogo.nu/bugs/view.php?id=2557))
* fixed handling of the '=' character in cards/events/tasks (closes [#2505](http://sogo.nu/bugs/view.php?id=2505))
* simplify searches in the address book (closes [#2187](http://sogo.nu/bugs/view.php?id=2187))
* warn user when dnd failed because of a resource conflict (closes [#1613](http://sogo.nu/bugs/view.php?id=1613))
* respect the maximum number of bookings when viewing the freebusy information of a resource (closes [#2560](http://sogo.nu/bugs/view.php?id=2560))
* encode HTML entities when forwarding an HTML message inline in plain text composition mode (closes [#2411](http://sogo.nu/bugs/view.php?id=2411))
* encode HTML entities in JSON data (closes [#2598](http://sogo.nu/bugs/view.php?id=2598))
* fixed handling of ACLs on shared calendars with multiple groups (closes [#1854](http://sogo.nu/bugs/view.php?id=1854))
* fixed HTML formatting of appointment notifications for Outlook (closes [#2233](http://sogo.nu/bugs/view.php?id=2233))
* replace slashes by dashes in filenames of attachments to avoid a 404 return code (closes [#2537](http://sogo.nu/bugs/view.php?id=2537))
* avoid over-using LDAP connections when decomposing groups
* fixed display of a contact's birthday when not defined (closes [#2503](http://sogo.nu/bugs/view.php?id=2503))
* fixed JavaScript error when switching views in calendar module (closes [#2613](http://sogo.nu/bugs/view.php?id=2613))

## [2.1.1b](https://github.com/inverse-inc/sogo/compare/SOGo-2.1.0...SOGo-2.1.1b) (2013-12-04)

### Enhancements

* updated CKEditor to version 4.3.0 and added tab module

### Bug Fixes

* HTML formatting is now retained when forwarding/replying to a mail using the HTML editor
* put the text part before the HTML part when composing mail to fix a display issue with Thunderbird (closes [#2512](http://sogo.nu/bugs/view.php?id=2512))

## [2.1.1a](https://github.com/inverse-inc/sogo/compare/SOGo-2.1.0...SOGo-2.1.1a) (2013-11-22)

### Bug Fixes

* fixed Sieve filters editor (closes [#2504](http://sogo.nu/bugs/view.php?id=2504))
* moved missing translation to UI/Common (closes [#2499](http://sogo.nu/bugs/view.php?id=2499))
* fixed potential crasher in OpenChange

## [2.1.1](https://github.com/inverse-inc/sogo/compare/SOGo-2.1.0...SOGo-2.1.1) (2013-11-19)

### Features

* creation and modification of mail labels

### Enhancements

* the color picker is no longer a popup window

### Bug Fixes

* fixed utf8 character handling in special folder names Special folder names can now be set as UTF8 or modified UTF7 in sogo.conf
* fixed reply-to header not being set for auxiliary IMAP accounts
* fixed handling of broken/invalid email addresses

## [2.1.0](https://github.com/inverse-inc/sogo/releases/tag/SOGo-2.1.0) (2013-11-07)

### Enhancements

* improved order of user rights in calendar module (closes [#1431](http://sogo.nu/bugs/view.php?id=1431))
* increased height of alarm editor when email alarms are enabled
* added SMTP AUTH support for sogo-ealarms-notify
* added support for LDAP password change against AD/Samba4
* added Apache configuration for Apple autoconfiguration (closes [#2248](http://sogo.nu/bugs/view.php?id=2248))
* the init scripts now start 3 sogod processes by default instead of 1
* SOGo now also sends a plain/text parts when sending HTML mails (closes [#2217](http://sogo.nu/bugs/view.php?id=2217))
* SOGo now listens on 127.0.0.1:20000 by default (instead of *:20000)
* SOGo new uses the latest WebDAV sync response type (closes [#1275](http://sogo.nu/bugs/view.php?id=1275))
* updated CKEditor to version 4.2.2 and added the tables-related modules (closes [#2410](http://sogo.nu/bugs/view.php?id=2410))
* improved display of vEvents in messages

### Bug Fixes

* fixed handling of an incomplete attachment filename (closes [#2385](http://sogo.nu/bugs/view.php?id=2385))
* fixed Finnish mail reply/forward templates (closes [#2401](http://sogo.nu/bugs/view.php?id=2401))
* fixed position of red line of current time (closes [#2373](http://sogo.nu/bugs/view.php?id=2373))
* fixed crontab error (closes [#2372](http://sogo.nu/bugs/view.php?id=2372))
* avoid using too many LDAP connections while looping through LDAP results
* don't encode HTML entities in mail subject of notification (closes [#2402](http://sogo.nu/bugs/view.php?id=2402))
* fixed crash of Samba when sending an invitation (closes [#2398](http://sogo.nu/bugs/view.php?id=2398))
* fixed selection of destination calendar when saving a task or an event (closes [#2353](http://sogo.nu/bugs/view.php?id=2353))
* fixed "display remote images" preference for message in a popup (closes [#2417](http://sogo.nu/bugs/view.php?id=2417))
* avoid crash when handling malformed or non-ASCII HTTP credentials (closes [#2358](http://sogo.nu/bugs/view.php?id=2358))
* fixed crash in DAV free-busy lookups when using SQL addressbooks (closes [#2418](http://sogo.nu/bugs/view.php?id=2418))
* disabled verbose logging of SMTP sessions by default
* fixed high CPU usage when there are no available child processes and added logging when such a condition occurs
* fixed memory consumption issues when doing dav lookups with huge result set
* fixed S/MIME verification issues with certain OpenSSL versions
* worked around an issue with chunked encoding of CAS replies (closes [#2408](http://sogo.nu/bugs/view.php?id=2408))
* fixed OpenChange corruption issue regarding predecessors change list (closes [#2405](http://sogo.nu/bugs/view.php?id=2405))
* avoid unnecessary UTF-7 conversions (closes [#2318](http://sogo.nu/bugs/view.php?id=2318))
* improved RTF parser to fix vCards (closes [#2354](http://sogo.nu/bugs/view.php?id=2354))
* fixed definition of the COMPLETED attribute of vTODO (closes [#2240](http://sogo.nu/bugs/view.php?id=2240))
* fixed DAV:resource-id property when sharing calendars (closes [#2399](http://sogo.nu/bugs/view.php?id=2399))
* fixed reload of multiple external web calendars (closes [#2221](http://sogo.nu/bugs/view.php?id=2221))
* fixed display of PDF files sent from Thunderbird (closes [#2270](http://sogo.nu/bugs/view.php?id=2270))
* fixed TLS support for IMAP (closes [#2386](http://sogo.nu/bugs/view.php?id=2386))
* fixed creation of web calendar when added using sogo-tool (closes [#2007](http://sogo.nu/bugs/view.php?id=2007))
* avoid crash when parsing HTML tags of a message (closes [#2434](http://sogo.nu/bugs/view.php?id=2434))
* fixed handling of LDAP groups with no email address (closes [#1328](http://sogo.nu/bugs/view.php?id=1328))
* fixed encoding of messages with non-ASCII characters (closes [#2459](http://sogo.nu/bugs/view.php?id=2459))
* fixed compilation with clang 3.2 (closes [#2235](http://sogo.nu/bugs/view.php?id=2235))
* truncated long fields of quick records to avoid an SQL error (closes [#2461](http://sogo.nu/bugs/view.php?id=2461))
* fixed IMAP ACLs (closes [#2433](http://sogo.nu/bugs/view.php?id=2433))
* removed inline JavaScript when viewing HTML messages (closes [#2468](http://sogo.nu/bugs/view.php?id=2468))

## [2.0.7](https://github.com/inverse-inc/sogo/releases/tag/SOGo-2.0.7) (2013-07-19)

### Features

* print gridlines of calendar in 15-minute intervals
* allow the events/tasks lists to be collapsable

### Enhancements

* bubble box of events no longer overlaps the current event
* now pass the x-originating-ip using the IMAP ID extension (closes [#2366](http://sogo.nu/bugs/view.php?id=2366))
* updated BrazilianPortuguese, Czech, Dutch, German, Polish and Russian translations

### Bug Fixes

* properly handle RFC2231 everywhere
* fixed minor XSS issues
* fixed jquery-ui not bluring the active element when clicking on a draggable

## 2.0.6b (2013-06-27)

### Bug Fixes

* properly escape the foldername to avoid XSS issues
* fixed loading of MSExchangeFreeBusySOAPResponseMap

## 2.0.6a (2013-06-25)

### Bug Fixes

* documentation fixes
* added missing file for CAS single logout

## [2.0.6](https://github.com/inverse-inc/sogo/releases/tag/SOGo-2.0.6) (2013-06-21)

### Enhancements

* updated CKEditor to version 4.1.1 (closes [#2333](http://sogo.nu/bugs/view.php?id=2333))
* new failed login attemps rate-limiting options. See the new SOGoMaximumFailedLoginCount, SOGoMaximumFailedLoginInterval and SOGoFailedLoginBlockInterval defaults
* new message submissions rate-limiting options. See the new SOGoMaximumMessageSubmissionCount, SOGoMaximumRecipientCount, SOGoMaximumSubmissionInterval and SOGoMessageSubmissionBlockInterval defaults
* now possible to send or not event notifications on a per-event basis
* now possible to see who created an event/task in a delegated calendar
* multi-domain support in OpenChange (implemented using a trick)

### Bug Fixes

* fixed decoding of the charset parameter when using single quotes (closes [#2306](http://sogo.nu/bugs/view.php?id=2306))
* fixed potential crash when sending MDN from Sent folder (closes [#2209](http://sogo.nu/bugs/view.php?id=2209))
* fixed handling of unicode separators (closes [#2309](http://sogo.nu/bugs/view.php?id=2309))
* fixed public access when SOGoTrustProxyAuthentication is used (closes [#2237](http://sogo.nu/bugs/view.php?id=2237))
* fixed access right issues with import feature (closes [#2294](http://sogo.nu/bugs/view.php?id=2294))
* fixed IMAP ACL issue when SOGoForceExternalLoginWithEmail is used (closes [#2313](http://sogo.nu/bugs/view.php?id=2313))
* fixed handling of CAS logoutRequest (closes [#2346](http://sogo.nu/bugs/view.php?id=2346))
* fixed many major OpenChange stability issues

## 2.0.5a (2013-04-17)

### Bug Fixes

* fixed an issue when parsing user CN with leading or trailing spaces (closes [#2287](http://sogo.nu/bugs/view.php?id=2287))
* fixed a crash that occured when saving contacts or tasks via Outlook

## [2.0.5](https://github.com/inverse-inc/sogo/releases/tag/SOGo-2.0.5) (2013-04-11)

### Features

* new system default SOGoEncryptionKey to be used to encrypt the passwords of remote Web calendars when SOGoTrustProxyAuthentication is enabled
* activated the menu option "Mark Folder Read" in the Webmail (closes [#1473](http://sogo.nu/bugs/view.php?id=1473))

### Enhancements

* added logging of the X-Forwarded-For HTTP header (closes [#2229](http://sogo.nu/bugs/view.php?id=2229))
* now use BSON instead of GNUstep's binary format for serializing Outlook related cache files
* updated Danish, Finnish, Polish and Slovak translations
* added Arabic translation - thanks to Anass Ahmed

### Bug Fixes

* don't use the cache for password lookups from login page (closes [#2169](http://sogo.nu/bugs/view.php?id=2169))
* fixed issue with exceptions in repeating events
* avoid data truncation issue in OpenChange with mysql backend run sql-update-2.0.4b_to_2.0.5-mysql.sh to update existing tables
* avoid random crashes in OpenChange due to RTF conversion
* fixed issue when modifying/deleting exceptions of recurring events
* fixed major cache miss issue leading to slow Outlook resynchronizations
* fixed major memory corruption issue when Outlook was saving "messages"
* fixed filtering of sql contact entries when using dynamic domains (closes [#2269](http://sogo.nu/bugs/view.php?id=2269))
* sogo.conf can now be used by all tools (closes [#2226](http://sogo.nu/bugs/view.php?id=2226))
* SOPE: fixed handling of sieve capabilities after starttls (closes [#2132](http://sogo.nu/bugs/view.php?id=2132))
* OpenChange: fixed 'stuck email' problem when sending a mail
* OpenChange NTLMAuthHandler: avoid tightloop when samba isn't available.
* OpenChange NTLMAuthHandler: avoid crash while parsing cookies
* OpenChange ocsmanager: a LOT of fixes, see git log

## 2.0.4b (2013-02-04)

### Bug Fixes

* Fixed order of precedence for options (closes [#2166](http://sogo.nu/bugs/view.php?id=2166))
* first match wins 1. Command line arguments 2. .GNUstepDefaults 3. /etc/sogo/{debconf,sogo}.conf 4. SOGoDefaults.plist
* fixed handling of LDAP DN containing special characters (closes [#2152](http://sogo.nu/bugs/view.php?id=2152), closes [#2207](http://sogo.nu/bugs/view.php?id=2207))
* fixed handling of credential files for older GNUsteps (closes [#2216](http://sogo.nu/bugs/view.php?id=2216))
* fixed display of messages with control characters (closes [#2079](http://sogo.nu/bugs/view.php?id=2079), closes [#2177](http://sogo.nu/bugs/view.php?id=2177))
* fixed tooltips in contacts list (closes [#2211](http://sogo.nu/bugs/view.php?id=2211))
* fixed classification menu in component editor (closes [#2223](http://sogo.nu/bugs/view.php?id=2223))
* fixed link to ACL editor for 'any authenticated user' (closes [#2222](http://sogo.nu/bugs/view.php?id=2222), closes [#2224](http://sogo.nu/bugs/view.php?id=2224))
* fixed saving preferences when mail module is disabled
* fixed handling for long credential strings (closes [#2212](http://sogo.nu/bugs/view.php?id=2212))

## 2.0.4a (2013-01-30)

### Enhancements

* updated Czech translation
* birthday is now properly formatted in addressbook module

### Bug Fixes

* fixed handling of groups with spaces in their UID
* fixed possible infinite loop in repeatable object
* fixed until date in component editor
* fixed saving all-day event in appointment editor
* fixed handling of decoding contacts UID
* fixed support of GNUstep 1.20 / Debian Squeeze

## [2.0.4](https://github.com/inverse-inc/sogo/releases/tag/SOGo-2.0.4) (2013-01-25)

### Features

* sogo-tool: new "dump-defaults" command to easily create /etc/sogo/sogo.conf

### Enhancements

* The sogo user is now a system user.
* sogo' won't work anymore. Please use 'sudo -u sogo cmd' instead If used in scripts from cronjobs, 'requiretty' must be disabled in sudoers
* added basic support for LDAP URL in user sources
* renamed default SOGoForceIMAPLoginWithEmail to SOGoForceExternalLoginWithEmail and extended it to SMTP authentication
* updated the timezone files to the 2012j edition and removed RRDATES
* updated CKEditor to version 4.0.1
* added Finnish translation - thanks to Kari Salmu
* updated translations
* recurrence-id of all-day events is now set as a proper date with no time
* 'show completed tasks' is now persistent
* fixed memory usage consumption for remote ICS subscriptions

### Bug Fixes

* fixed usage of browser's language for the login page
* fixed partstat of attendee in her/his calendar
* fixed French templates encoding
* fixed CardDAV collections for OS X
* fixed event recurrence editor (until date)
* fixed column display for subfolders of draft & sent
* improved IE7 support
* fixed drag'n'drop of events with Safari
* fixed first day of the week in datepickers
* fixed exceptions of recurring all-day events

## [2.0.3](https://github.com/inverse-inc/sogo/releases/tag/SOGo-2.0.3) (2012-12-06)

### Features

* support for SAML2 for single sign-on, with the help of the lasso library
* added support for the "AUTHENTICATE" command and SASL mechanisms
* added domain default SieveHostFieldName
* added a search field for tasks

### Enhancements

* search the contacts for the organization attribute
* in HTML mode, optionally place answer after the quoted text
* improved memory usage of "sogo-tool restore"
* fixed invitations status in OSX iCal.app/Calendar.app (cleanup RSVP attribute)
* now uses "imap4flags" instead of the deprecated "imapflags"
* added Slovak translation - thanks to Martin Pastor
* updated translations

### Bug Fixes

* fixed LDIF import with categories
* imported events now keep their UID when possible
* fixed importation of multiple calendars
* fixed modification date when drag'n'droping events
* fixed missing 'from' header in Outlook
* fixed invitations in Outlook
* fixed JavaScript regexp for Firefox
* fixed JavaScript syntax for IE7
* fixed all-day event display in day/week view
* fixed parsing of alarm
* fixed Sieve server URL fallback
* fixed Debian cronjob (spool directory cleanup)

## 2.0.2a (2012-11-15)

### Enhancements

* improved user rights editor in calendar module
* disable alarms for newly subsribed calendars

### Bug Fixes

* fixed typos in Spanish (Spain) translation
* fixed display of raw source for tasks
* fixed title display of cards with a photo
* fixed null address in reply-to header of messages
* fixed scrolling for calendar/addressbooks lists
* fixed display of invitations on BlackBerry devices
* fixed sogo-tool rename-user for MySQL database
* fixed corrupted attachments in Webmail
* fixed parsing of URLs that can throw an exception
* fixed password encoding in user sources

## [2.0.2](https://github.com/inverse-inc/sogo/releases/tag/SOGo-2.0.2) (2012-10-24)

### Features

* added support for SMTP AUTH
* sogo configuration can now be set in /etc/sogo/sogo.conf
* added support for GNU TLS

### Enhancements

* speed up of the parsing of IMAP traffic
* minor speed up of the web interface
* speed up the scrolling of the message list in the mail module
* speed up the deletion of a large amounts of entries in the contacts module
* updated the timezone files to the 2012.g edition
* openchange backend: miscellaneous speed up of the synchronization operations
* open file descriptors are now closed when the process starts

### Bug Fixes

* the parameters included in the url of remote calendars are now taken into account
* fixed an issue occurring with timezone definitions providing multiple entries
* openchange backend: miscellaneous crashes during certain Outlook operations, which have appeared in version 2.0.0, have been fixed
* fixed issues occuring on OpenBSD and potentially other BSD flavours

## [2.0.1](https://github.com/inverse-inc/sogo/releases/tag/SOGo-2.0.1) (2012-10-10)

### Enhancements

* deletion of contacts is now performed in batch, which speeds up the operation for large numbers of items
* scalability enhancements in the OpenChange backend that enables the first synchronization of mailboxes in a more reasonable time and using less memory
* the task list is now sortable

### Bug Fixes

* improved support of IE 9

## [2.0.0](https://github.com/inverse-inc/sogo/releases/tag/SOGo-2.0.0) (2012-09-27)

### Features

* Microsoft Outlook compatibility layer

### Enhancements

* updated translations
* calendars list and mini-calendar are now always visible
* tasks list has moved to a table in a tabs view along the events list
* rows in tree view are now 4 pixels taller
* node selection in trees now highlights entire row
* new inline date picker
* improved IE8/9 support
* added support for standard/daylight timezone definition with end date
* no longer possible to send a message multilpe times
* mail editor title now reflects the current message subject
* default language is selected on login page
* mail notifications now include the calendar name

### Bug Fixes

* fixed translation of invitation replies
* fixed vacation message encoding
* fixed display of events of no duration
* fixed error when copying/moving large set of contacts
* fixed drag'n'drop of all-day events

## 1.3.18a (2012-09-04)

### Bug Fixes

* fixed display of weekly events with no day mask
* fixed parsing of mail headers
* fixed support for OS X 10.8 (Mountain Lion)

## 1.3.18 (2012-08-28)

### Enhancements

* updated Catalan, Dutch, German, Hungarian, Russian, Spanish (Argentina), and Spanish (Spain) translations
* mail filters (Sieve) are no longer conditional to each other (all filters are executed, no matter if a previous condition matches)
* improved tasks list display
* RPM packages now treat logrotate file as a config file
* completed the transition from text/plain message templates to HTML
* new packages for Debian 7.0 (Wheezy)

### Bug Fixes

* fixed passwords that would be prefixed with '{none}' when not using a password algorithm
* fixed handling of duplicated contacts in contact lists
* fixed handling of exception dates with timezones in recurrent events
* fixed validation of the interval in daily recurrent events with a day mask covering multiple days
* fixed name quoting when sending invitations

## 1.3.17 (2012-07-26)

### Features

* new contextual menu to view the raw content of events, tasks and contacts
* send and/or receive email notifications when a calendar is modified (new domain defaults SOGoNotifyOnPersonalModifications and SOGoNotifyOnExternalModifications)
* added the SOGoSearchMinimumWordLength domain default which controls the minimal length required before triggering server-side search operations for attendee completion, contact searches, etc. The default value is 2, which means search operations are trigged once the 3rd character is typed.

### Enhancements

* updated BrazilianPortuguese, Czech, Dutch, French, German, Italian, Spanish (Argentina), Spanish (Spain) translations
* all addresses from a contact are displayed in the Web interface (no longer limited to one additional address)
* improved Sieve script: vacation message is now sent after evaluating the mail filters
* updated CKEditor to version 3.6.4

### Bug Fixes

* fixed a crash when multiple mail headers of the same type were encountered
* fixed logrotate script for Debian
* fixed linking of libcurl on Ubuntu 12.04
* fixed parsing of timezones when importing .ics files
* fixed resource reservation for recurring events
* fixed display of text attachments in messages
* fixed contextual menu on newly created address books
* fixed missing sender in mail notifications to removed attendees
* improved invitations handling in iCal

## 1.3.16 (2012-06-07)

### Enhancements

* new password schemes for SQL authentication (crypt-md5, ssha (including 256/512 variants), cram-md5, smd5, crypt, crypt-md5)
* new unique names for static resources to avoid browser caching when updating SOGo
* it's no longer possible to click the "Upload" button multiple times
* allow delivery of mail with no subject, but alert the user
* updated Dutch, German, French translations

### Bug Fixes

* fixed compilation under GNU/kFreeBSD
* fixed compilation for arm architecture
* fixed exceptions under 64bit GNUstep 1.24
* fixed LDAP group expansion
* fixed exception when reading ACL of a deleted mailbox
* fixed exception when composing a mail while the database server is down
* fixed handling of all-day repeating events with exception dates
* fixed Sieve filter editor when matching all messages
* fixed creation of URLs (A-tag) in messages

## 1.3.15 (2012-05-15)

### Features

* sources address books are now exposed in Apple and iOS AddressBook app using the "directory gateway" extension of CardDAV
* sogo-tool: new "expire-sessions" command
* the all-day events container is now resized progressively
* added handling of "BYSETPOS" for "BYDAY" sets in monthly recurrence calculator
* new domain default (SOGoMailCustomFromEnabled) to allow users to change their "from" and "reply-to" headers
* access to external calendar subscriptions (.ics) with authentication
* new domain default (SOGoHideSystemEMail) to hide or not the system email. This is currently limited to CalDAV operations

### Enhancements

* updated Spanish (Argentina), German, Dutch translations
* updated CKEditor to version 3.6.3
* automatically add/remove attendees to recurrence exceptions when they are being added to the master event
* replaced the Scriptaculous Javascript framework by jQuery to improve the drag'n'drop experience
* updated timezone definition files

### Bug Fixes

* fixed wrong date validation in preferences module affecting French users
* fixed bugs in weekly recurrence calculator
* when saving a draft, fixed content-transfer-encoding to properly handle 8bit data
* escaped single-quote in HTML view of contacts
* fixed support of recurrent events with Apple iCal
* fixed overbooking handling of resources with recurrent events
* fixed auto-accept of resources when added later to an event

## 1.3.14 (2012-03-23)

### Enhancements

* when replying or inline-forwarding a message, we now prefer the HTML part over the text part when composing HTML messages
* when emptying the trash, we now unsubscribe from folders within the trash
* added CalDAV autocompletion support for iPad (iOS 5.0.x)
* improved notifications support for Apple iCal
* updated Czech translation
* updated Russian translation

### Bug Fixes

* fixed name of backup script in cronjob template
* fixed crash caused by contacts with multiple mail values
* fixed signal handlers to avoid possible hanging issues
* fixed the "user-preferences" command of sogo-tool

## 1.3.13 (2012-03-16)

### Features

* email notifications now includes a new x-sogo-message-type mail header
* added the "IMAPHostnameFieldName" parameter in SQL source to specify a different IMAP hostname for each user (was already possible for LDAP sources)
* default event & task classification can now be set from the preferences window
* contacts from LDAP sources can now be modified by privileged owners (see the "modifiers" parameter)

### Enhancements

* bundled a shell script to perform and manage backups using sogo-tool
* increased the delay before starting drag and drop in Mail and Contacts module to improve the user experience with cheap mouses
* improved contact card layout when it includes a photo
* updated German translation
* updated Spanish (Spain) translation
* updated Spanish (Argentina) translation
* updated Ukrainian translation
* updated Hungarian translation
* updated Dutch translation

### Bug Fixes

* fixed escaping issue with PostgreSQL 8.1
* fixed resizing issue when editing an HTML message
* fixed Spanish (Argentina) templates for mail reply and forward
* we no longer show public address books (from SOGoUserSources) on iOS 5.0.1
* improved support for IE

## 1.3.12c (2012-02-15)

### Bug Fixes

* fixed a possible crash when using a SQL source

## 1.3.12b (2012-02-14)

### Bug Fixes

* we now properly escape strings via the database adapator methods when saving users settings
* fixed a crash when exporting a vCard without specifying a UID
* fixed the contextual menu on newly created contacts and lists

## 1.3.12a (2012-02-13)

### Bug Fixes

* the plus sign (+) is now properly escaped in JavaScript (fixes issue when loading the mailboxes list)
* added missing migration script in Debian/Ubuntu packages

## 1.3.12 (2012-02-13)

### Features

* show end time in bubble box of events
* we now check for new mails in folders for which sieve rules are defined to file messages into
* new parameter DomainFieldName for SQL sources to dynamically determine the  domain of the user

### Enhancements

* updated Ukrainian translation
* updated Russian translation
* updated Brazilian (Portuguese) translation
* updated Italian translation
* updated Spanish (Spain) translation
* updated German translation
* updated Catalan translation
* updated Norwegian (Bokmal) translation
* now possible to use memcached over a UNIX socket
* increase size of content columns
* improved import of .ics files
* new cronjob template with commented out entries
* LDAP passwords can now be encrypted with the specified algorithm
* improved parsing of addresses when composing mail

### Bug Fixes

* fixed resizing issue of mail editor
* alarms for tasks now depend on the start date and instead of the due date
* increased the content column size in database tables to permit syncs of cards with big photos in them
* fixed intended behavior of WOSendMail
* fixed selection issue with Firefox when editing the content of a textarea
* fixed bug with daily recurrence calculator that would affect conflict detection
* fixed issue with Apple Address Book 6.1 (1083) (bundled with MacOS X 10.7.3)
* removed double line breaks in HTML mail and fixed empty tags in general

## 1.3.11 (2011-12-12)

### Features

* new experimental feature to force popup windows to appear in an iframe -- this mode can be forced by setting the cookie "SOGoWindowMode" to "single"

### Enhancements

* contacts from the email editor now appear in a pane, like in Thunderbird
* improved display of contacts in Address Book module
* "remember login" cookie now expires after one month
* added DanishDenmark translation - thanks to Altibox
* updated German translation
* updated SpanishArgentina translation
* updated SpanishSpain translation
* updated Russian translation

### Bug Fixes

* fixed encoding of headers in sogo-ealarm-notify
* fixed confirmation dialog box when deleting too many events
* fixed issue when saving associating a category to an event/task
* fixed time shift regression in Calendar module
* activated "standard conforming strings" in the PosgreSQL adapter to fixed errors with backslashes
* fixed a bug when GCSFolderDebugEnabled or GCSFolderManagerDebugEnabled were enabled

## 1.3.10 (2011-11-30)

### Features

* new migration script for SquirrelMail (address books)
* users can now set an end date to their vacation message (sysadmin must  configure sogo-tool)

### Enhancements

* splitted Norwegian translation into NorwegianBokmal and NorwegianNynorsk
* splitted Spanish translation into SpanishSpain and SpanishArgentina
* updated timezone files
* updated French translation

### Bug Fixes

* added missing Icelandic wod files
* fixed crash when the Sieve authentication failed
* fixed bug with iOS devices and UIDs containing the @ symbol
* fixed handling of commas in multi-values fields of versit strings
* fixed support of UTF-8 characters in LDAP searches
* added initial fixes for iCal 5 (Mac OS X 10.7)
* Address Book 6.1 now shows properly the personal address book
* fixed vcomponent updates for MySQL
* fixed clang/llvm and libobjc2 build

## 1.3.9 (2011-10-28)

### Features

* new user defaults SOGoDefaultCalendar to specify which calendar is used when creating an event or a task (selected, personal, first enabled)
* new user defaults SOGoBusyOffHours to specify if off-hours should be automatically added to the free-busy information
* new indicator in the link banner when a vacation message (auto-reply) is active
* new snooze function for events alarms in Web interface
* new "Remember login" checkbox on the login page
* authentication with SQL sources can now be performed on any database column using the new LoginFieldNames parameter

### Enhancements

* added support for the CalDAV move operation
* phone numbers in the contacts web module are now links (tel:)
* revamp of the modules link banner (15-pixel taller)
* updated CKEditor to version 3.6.2
* updated unread and flagged icons in Webmail module
* new dependency on GNUstep 1.23

### Bug Fixes

* fixed support for Apple iOS 5
* fixed handling of untagged IMAP responses
* fixed handling of commas in email addresses when composing a message
* fixed creation of clickable links for URLs surrounded by square brackets
* fixed behaviour of combo box for contacts categories
* fixed Swedish translation classes
* fixed bug when setting no ACL on a calendar

## 1.3.8b (2011-07-26)

### Bug Fixes

* fixed a bug with multi-domain configurations that would cause the first authentication to fail

## 1.3.8a (2011-07-19)

### Features

* new system setting SOGoEnableDomainBasedUID to enable user identification by domain

### Bug Fixes

* fixed a buffer overflow in SOPE (mainly affecting OpenBSD)

## 1.3.8 (2011-07-14)

### Features

* initial support for threaded-view in the webmail interface
* sogo-tool: new "rename-user" command that automatically updates all the references in the database after modifying a user id
* sogo-tool: new "user-preferences {get,set,unset} command to manipulate user's defaults/settings.
* groups support for IMAP ACLs
* now possible to define multiple forwarding addresses
* now possible to define to-the-minute events/tasks
* the domain can be selected from the login page when using multiple domains (SOGoLoginDomains)
* sources from one domain can be accessed from another domain when using multiple domains (SOGoDomainsVisibility)
* added Icelandic translation - thanks to Anna Jonna Armannsdottir

### Enhancements

* improved list selection and contextual menu behavior in all web modules
* the quota status bar is now updated more frequently in the webmail module
* automatically create new cards when populating a list of contacts with unknown entries
* added fade effect when displaying and hiding dialog boxes in Web interface
* updated CKEditor to version 3.6.1
* updated Russian translation

### Bug Fixes

* submenus in contextual menus splitted in multiple lists are now displayed correctly
* fixed display of cards/lists icons in public address books
* no longer accept an empty string when renaming a calendar
* fixed display of daily events that cover two days
* fixed time shift issue when editing an event title on iOS
* fixed bug when using indirect LDAP binds and bindAsCurrentUser
* fixed bugs when converting an event to an all-day one
* many small fixes related to CalDAV scheduling
* many OpenBSD-related fixes

## 1.3.7 (2011-05-03)

### Features

* IMAP namespaces are now translated and the full name of the mailbox owner is extracted under "Other Users"
* added the "authenticationFilter" parameter for SQL-based sources to limit who can authenticate to a local SOGo instance
* added the "IMAPLoginFieldName" parameter in authentication sources to specify a different value for IMAP authentication
* added support for resources like projectors, conference rooms and more which allows SOGo to avoid double-booking of them and also allows SOGo to automatically accept invitations for them

### Enhancements

* the personal calendar in iCal is now placed at the very top
* the recipients selection works more like Thunderbird when composing emails
* improved the documentation regarding groups in LDAP
* minor improvements to the webmail module
* minor improvements to the contacts web module

### Bug Fixes

* selection problems with Chrome under OS X in the webmail interface
* crash when some events had no end date

## 1.3.6 (2011-04-08)

### Features

* added Norwegian translation - thanks to Altibox

### Enhancements

* updated Italian translation
* updated Ukranian translation
* updated Spanish translation
* "check while typing" is no longer enabled by default in HTML editor
* show unread messages count in window title in the webmail interface
* updated CKEditor to version 3.5.2
* contact lists now have their own icons in the contacts web module
* added the ability to invite people and to answer invitations from the iOS Calendar
* alarms are no longer exported to DAV clients for calendars where the alarms are configured to be disabled
* IMAP connection pooling is disabled by default to avoid flooding the IMAP servers in multi-process environments (NGImap4DisableIMAP4Pooling now set to "YES" by default)
* sogo-tool: the remove-doubles command now makes use of the card complete names
* sope-appserver: added the ability to configure the minutes timeout per request after which child processes are killed, via WOWatchDogRequestTimeout (default: 10)

### Bug Fixes

* restored the automatic expunge of IMAP folders
* various mutli-domain fixes
* various timezone fixes
* fixed various issues occurring with non-ascii strings received from DAV clients
* sogo-tool: now works in multi-domain environments
* sogo-tool: now retrieves list of users from the folder info table
* sogo-tool: the remove-doubles command is now compatible with the synchronization mechanisms
* sope-mime: fixed some parsing problems occurring with dbmail
* sope-mime: fixed the fetching of mail body parts when other untagged responses are received
* sope-appserver: fixed a bug leaving child processes performing the watchdog safety belt cleanup

## 1.3.5 (2011-01-25)

### Features

* implemented secured sessions
* added SHA1 password hashing in SQL sources
* mail aliases columns can be specified for SQL sources through the configuration parameter MailFieldNames

### Enhancements

* updated CKEditor to version 3.4.3
* removed the Reply-To header in sent messages
* the event timezone is now considered when computing an event recurrence rule
* improved printing of a message with multple recipients
* the new parameter SearchFieldNames allows to specify which LDAP fields to query when filtering contacts

### Bug Fixes

* restored current time shown as a red line in calendar module
* logout button no longer appears when SOGoCASLogoutEnabled is set to NO
* fixed error when deleting freshly created addressbooks
* the mail column in SQL sources is not longer ignored
* fixed wrapping of long lines in messages with non-ASCII characters
* fixed a bug that would prevent alarms to be triggered when non-repetitive

## 1.3.4 (2010-11-17)

### Bug Fixes

* updated CKEditor to version 3.4.2
* added event details in invitation email
* fixed a bug that would prevent web calendars from being considered as such under certain circumstances
* when relevant, the "X-Forward" is added to mail headers with the client's originating IP
* added the ability to add categories to contacts as well as to configure the list of contact categories in the preferences
* improved performance of live-loading of messages in the webmail interface
* fixed a bug that would not identify which calendars must be excluded from the freebusy information
* increased the contrast ratio of input/select/textarea fields

## 1.3.3 (2010-10-19)

### Bug Fixes

* added Catalan translation, thanks to Hector Rulot
* fixed German translation
* fixed Polish translation
* fixed Italian translation
* enhanced default Apache config files
* improved groups support by caching results
* fixed base64 decoding issues in SOPE
* updated the Polish, Italian and Ukrainian translations
* added the capability of renaming subscribed address books
* acls are now cached in memcached and added a major performance improvement when listing calendar / contact folders
* fixed many small issues pertaining to DST switches
* auto complete of attendees caused an error if entered to fast
* ctrl + a (select all) was not working properly in the Calendar UI on Firefox
* calendar sync tag names and other metadata were not released when a calendar was deleted
* in the Contacts UI, clicking on the "write" toolbar button did not cause a message to be displayed when no contact were selected
* added the ability to rename a subscribed folder in the Contacts UI
* card and event fields can now contain versit separators (";" and ",")
* fixed handling of unsigned int fields with the MySQL adaptor
* improved the speed of certain IMAP operations, in particular for GMail accounts
* prevent excessing login failures with IMAP accounts
* fixed spurious creation of header fields due to an bug of auto-completion in the mail composition window
* fixed a wrong redirect when clicking "reply" or "forward" while no mail were selected
* added caching of ACLs locally and in memcached

## 1.3.2 (2010-09-21)

### Bug Fixes

* fixed various issues with some types of email address fields
* added support for Ctrl-A (select all) in all web modules
* added support for Ctrl-C/Ctrl-V (copy/paste) in the calendar web module
* now builds properly with gnustep-make >= 2.2 and gnustep-base >= 1.20
* added return receipts support in the webmail interface
* added CardDAV support (Apple AddressBook and iPhone)
* added support for multiple, external IMAP accounts
* added SSL/TLS support for IMAP accounts (system and external)
* improved and standardized alerts in all web modules
* added differentiation of public, private and confidential events
* added display of unread messages count for all mailboxes
* added support for email event reminders

## 1.3.1 (2010-08-19)

### Bug Fixes

* added migration scripts for Horde (email signatures and address books)
* added migration script for Oracle Calendar (events, tasks and access rights)
* added Polish translation
* added crypt support to SQL sources
* updated Ukrainian translation
* added the caldav-auto-schedule capability
* improved support for IE8

## 1.3.0 (2010-07-21)

### Bug Fixes

* added support for the "tentative" status in the invitation responses
* inviting a group of contacts is now possible, where each contact will be extracted when the group is resolved
* added support for modifying the role of the meeting participants
* attendees having an "RSVP" set to "FALSE" or empty will no longer need/be able to respond to invitations
* added the ability to specify which calendar is taken into account when retrieving a user's freebusy
* added the ability to publish resources to unauthenticated (anonymous) users, via the "/SOGo/dav/public" url
* we now provide ICS and XML version of a user's personal calendars when accessed from his own "Calendar" base collection
* events are now displayed with the colored stripe representing their category, if one is defined in the preferences
* fixed display of all-day events in a monthly view where the timezone differs from the current one
* the event location is now displayed in the calendar view when defined properly
* added a caching mechanism for freebusy requests, in order to accelerate the display
* added the ability to specify a time range when requesting a time slot suggestion
* added live-loading support in the webmail interface with caching support
* updated CKEditor and improved its integration with the current user language for automatic spell checking support
* added support for displaying photos from contacts
* added a Ukrainian translation
* updated the Czech translation

## 1.2.2 (2010-05-04)

### Bug Fixes

* subscribers can now rename folders that do not belong to them in their own environment
* added support for LDAP password policies
* added support for custom Sieve filters
* fixed timezone issues occurring specifically in the southern hemisphere
* updated ckeditor to version 3.2
* tabs: enabled the scrolling when overflowing
* updated Czech translation, thanks to Milos Wimmer
* updated German translation, tnanks to Alexander Greiner-Baer
* removed remaining .wo templates, thereby easing the effort for future translations
* fixed regressions with Courier IMAP and Dovecot
* added support for BYDAY with multiple values and negative positions
* added support for BYMONTHDAY with multiple values and negative positions
* added support for BYMONTH with multiple values
* added ability to delete events from a keypress
* added the "remove" command to "sogo-tool", in order to remove user data and settings
* added the ability to export address books in LDIF format from the web interface
* improved the webmail security by banning a few sensitive tags and handling "object" elements

## 1.2.1 (2010-02-19)

### Bug Fixes

* added CAS authentication support
* improved display of message size in webmail
* improved security of login cookie by specifying a path
* added drag and drop to the web calendar interface
* calendar: fixed CSS oddities and harmonized appearance of event cells in all supported browsers
* added many IMAP fixes for Courier and Dovecot

## 1.2.0 (2010-01-25)

### Bug Fixes

* improved handling of popup windows when closing the parent window
* major refresh of CSS
* added handling of preforked processes by SOPE/SOGo (a load balancer is therefore no longer needed)
* added Swedish translation, thanks to Altrusoft
* added multi-domain support
* refactored the handling of user defaults to enable fallback on default values more easily
* added sensible default configuration values
* updated ckeditor to version 3.1
* added support for iCal 4 delegation
* added support for letting the user choose which calendars should be shared with iCal delegation
* added the ability for users to subscribe other users to their resources from the ACL dialog
* added fixes for bugs in GNUstep 1.19.3 (NSURL)

## 1.1.0 (2009-10-28)

### Bug Fixes

* added backup/restore tools for all user's data (calendars, address books, preferences, etc.)
* added Web administrative interface (right now, only for ACLs)
* added the "Starred" column in the webmail module to match Thunderbird's behavior
* improved the calendar properties dialog to be able to enable/disabled calendars for synchronization
* the default module can now be set on a per-user basis
* a context menu is now available for tasks
* added the capability of creating and managing lists of contacts (same as in Thunderbird)
* added support for short date format in the calendar views
* added support for iCal delegation (iCal 3)
* added preliminary support for iCal 4
* rewrote dTree.js to include major optimizations
* added WebAuth support
* added support for remote ICS subscriptions
* added support for ICS and vCard/LDIF import
* added support for event delegation (resend an invitation to someone else)
* added initial support for checking and displaying S/MIME signed messages
* added support SQL-based authentication sources and address books
* added support for Sieve filters (Vacation and Forward)

## 1.0.4 (2009-08-12)

### Bug Fixes

* added ability to create and modify event categories in the preferences
* added contextual menu in web calendar views
* added "Reload" button to refresh the current view in the calendar module
* fixed freebusy support for Apple iCal
* added support for the calendar application of the iPhone OS v3
* added the possibility to disable alarms or tasks from Web calendars
* added support for printing cards
* added a default title when creating a new task or event
* the completion checkbox of read-only tasks is now disabled
* the event/task summary dialog is now similar to Lightning
* added the current time as a line in the calendar module
* added the necessary files to build Debian packages
* added functional tests for DAV operations and fixed some issues related to permissions
* added Hungarian translation, thanks to Sándor Kuti

## 1.0.3 (2009-07-14)

### Bug Fixes

* improved search behavior of users folders (UIxContactsUserFolders)
* the editor window in the web interface now appears directly when editing an exception occurence of a repeating event (no more dialog window, as in Lightning)
* implemented the webdav sync spec from Cyrus Daboo, in order to reduce useless payload on databases
* greatly reduced the number of SQL requests performed in many situations
* added HTML composition in the web mail module
* added drag and drop in the addressbook and mail modules
* improved the attendees modification dialog by implementing slots management and zooming
* added the capability to display the size of messages in the mail module
* added the capability of limiting the number of returned events from DAV requests
* added support for Cyrus Daboo's Webdav sync draft spec in the calendar and addressbook collections
* added unicode support in the IMAP folder names
* fixed some issues with the conversion of folder names in modified UTF-7
* component editor in web interface stores the document URL in the ATTACH property of the component, like in Lightning
* added Czech translation, thanks to Šimon Halamásek
* added Brazilian Portuguese translation, thanks to Alexandre Marcilio

## 1.0.2 (2009-06-05)

### Bug Fixes

* basic alarm implementation for the web interface
* added Welsh translation, thanks to Iona Bailey
* added Russian translation, thanks to Alex Kabakaev
* added support for Oracle RAC
* added "scope" parameter to LDAP sources
* now possible to use SSL (or TLS) for LDAP sources
* added groups support in attendees and in ACLs
* added support for user-based IMAP hostname
* added support for IMAP subscriptions in web interface
* added compatibility mode meta tag for IE8
* added support for next/previous slot buttons in attendees window of calendar module
* user's status for events in the web interface now appears like in Lightning ("needs-action" events are surrounded by a dashed line, "declined" events are lighter)
* improvements to the underlying SOGo cache infrastructure
* improved JavaScript for selection and deselection in HTML tables and lists
* improved the handling of user permissions in CalDAV and WebDAV queries pertaining to accessing and deleting elements
* fixed bug with LDAP-based address books and the entries references (ID vs UID)
* fixed week view alignment problem in IE7
* fixed LDAP and SQL injection bugs
* fixed many bugs related to the encoding and decoding of IMAP folder names

## 1.0.1 (2009-04-07)

### Bug Fixes

* now possbile to navigate using keyboard keys in the address book and mail modules
* the favicon can now be specified using the SOGoFaviconRelativeURL preference
* we now support LDAP encryption for binding and for contact lookups
* we now support LDAP scopes for various search operations
* when the status of an attendee changes, the event of an organizer is now updated correctly if it doesn't reside in the personal folder
* formatting improvements in the email invitation templates
* Dovecot IMAP fixes and speed enhancements
* code cleanups to remove most compiler warnings
* various database fixes (Oracle, connection pools, unavailability, etc.)
* init scripts improvements

## 1.0.0 (2009-03-17)

### Bug Fixes

* when double-clicking in the all-day zone (day & week views), the "All Day event" checkbox is now automatically checked
* replaced the JavaScript FastInit class by the dom:loaded event of Prototype JS
* also updated Prototype JS to fix issues with IE7
* improvements to the underlying SOGo cache infrastructure
* many improvements to DST handling
* better compatibility with nginx
* new SOGo login screen
* added MySQL support

## 1.0 rc9 (2009-01-30)

### Bug Fixes

* added quota indicator in web mail module
* improved drag handles behavior
* added support for LDAP-based configuration
* improved init script when killing proccesses
* improved behavior of recurrent events with attendees
* improved the ACL editor of the calendar web module
* fixed handling of timezones in daily and weekly events

## 1.0 rc8 (2008-08-26)

### Bug Fixes

* fixed a bug that would prevent deleted event and tasks from being removed from the events and tasks list
* fixed a bug where the search of contacts would be done in authentication-only LDAP repositories
* added the ability to transfer an event from one calendar to another
* fixed a bug where deleting a contact would leave it listed in the contact list until the next refresh
* fixed a bug where events shared among different attendees would no longer be updated automatically
* changed the look of the Calendar module to match the look of Lightning 0.9
* the event details appear when the user clicks on it
* enable module constraints to be specified as patterns
* inhibit internal links and css/javascript content from html files embedded as attachments to mails
* updated all icons to use those from Thunderbird 2 and Lightning 0.9
* fixed a bug where the cached credentials wouldn't be expired using SOGoLDAPUserManagerCleanupInterval
* fixed a bug where mail headers wouldn't be decoded correctly
* the copy/move menu items are correctly updated when IMAP folders are added, removed or renamed
* fixed a bug where the ctag of a calendar would not take the deleted events into account, and another one where the value would always take the one of the first calendar queries during the process lifetime.

## 1.0 rc7 (2008-07-29)

### Bug Fixes

* work around the situation where Courier IMAP would refuse to rename the current mailbox or move it into the trash
* fixed tab index in mail composition window
* fixed default privacy selection for new events
* fixed a bug where concurrent versions of SOGo would create the user's personal folders table twice
* added address completion in the web mail editor
* implemented support for CalDAV methods which were missing for supporting iCal 3
* added support to write to multiple contacts from the Address Book module
* added support to move and copy one or many contacts to another address book in the Address Book module
* added icons to folders in Address Book module
* fixed various bugs occuring with Safari 3.1
* fixed various bugs occuring with Firefox 3
* fixed bug where selecting the current day cell would not select the header day cell and vice-versa in the daily and weekly views
* the events are now computed in the server code again, in order to speedup the drawing of events as well as to fix the bug where events would be shifted back or forth of one day, depending on how their start time would be compared to UTC time
* implemented the handling of exceptional occurences of recurrent events
* all the calendar preferences are now taken into account
* the user defaults variable "SOGoAuthentificationMethod" has been renamed to "SOGoAuthenticationMethod"
* fixed a bug where the search of users would be done in addressbook-only LDAP repositories

## 1.0 rc6 (2008-05-20)

### Bug Fixes

* retrieving the freebusy DAV object was causing SOGo to crash
* converted to use the gnustep-make 2 build framework
* added custom DAV methods for managing user permissions from the SOGo Integrator
* pressing enter in the contact edition dialog will perform the creation/update operation
* implemented more of the CalDAV specification for compatibility with Lightning 0.8
* added Italian translation, thanks to Marco Lertora and Sauro Saltini
* added initial logic for splitting overlapping events
* improved restoration of drag handles state
* improved contextual menu handling of Address Book module
* fixed time/date control widget of attendees editor
* fixed various bugs occuring with Safari 3.1
* monthly events would not be returned properly
* bi-weekly events would appear every week instead
* weekly events with specified days of week would not appear on the correct days
* started supporting Lightning 0.8, improved general implementation of the CalDAV protocol
* added support for calendar colors, both in the web and DAV interfaces
* refactored and fixed the implementation of DAV acl, with partial support for CalDAV Scheduling extensions
* removed the limitation that prevented the user of underscore characters in usernames
* added Spanish translation, thanks to Ernesto Revilla
* added Dutch translation, thanks to Wilco Baan Hofman
* applied a patch from Wilco Baan Hofman to let SOGo works correctly through a Squid proxy

## 1.0 rc5 (2008-02-08)

### Bug Fixes

* improved validation in the custom recurrence window
* improved resiliance when parsing buggy recurrence rules
* added the ability to authenticate users and to identify their resources with an LDAP field other than the username
* the monthly view would not switch to the next or previous month if the current day of the new month was already displayed in the current view
* enabled the instant-messaging entry in the addressbook
* prevent the user from selecting disabled menu entries
* added the ability to add/remove and rename calendars in DAV
* no longer require a default domain name/imap server to work properly
* the position of the splitters is now remembered across user sessions
* improved the email notifications when creating and removing a folder
* fixed the tab handling in IE7
* improved the appearance of widgets in IE7
* dramatic improvement in the overall stability of SOGo

## 1.0 rc4 (2008-01-16)

### Bug Fixes

* improved the attendees window
* added the attendees pulldown menu in the event editor (like in Lightning)
* added the recurrence window
* a message can be composed to multiple recipients from an address book or from an event attendees menu
* many bugfixes in the Calendar module

## 1.0 rc3 (2007-12-17)

### Bug Fixes

* mail folders state is now saved
* image attachments in emails can now be saved
* the status of participants in represented with an icon
* added the option to save attached images
* fixed problems with mod_ngobjweb (part of SOPE)
* the current module can no longer be reselected from the module navigation bar
* many bugfixes in the Mail and Calendar modules
* improved handling of ACLs

## 1.0 rc2 (2007-11-27)

### Bug Fixes

* the user password is no longer transmitted in the url when logging in
* SOGo will no longer redirect the browser to the default page when a specific location is submitted before login
* it is now possible to specify a sequence of LDAP attributes/values pairs required in a user record to enable or prevent access to the Calendar and/or Mail module
* many messages can be moved or copied at the same time
* replying to mails in the Sent folder will take the recipients of the original mails into account
* complete review of the ACLs wrt to the address books, both in the Web UI and through DAV access
* invitation from Google calendar are now correctly parsed
* it is now possible to search events by title in the Calendar module
* all the writable calendars are now listed in the event edition dialog

## 1.0 rc1 (2007-11-19)

### Bug Fixes

* the user can now configure his folders as drafts, trash or sent folder
* added the ability the move and copy message across mail folders
* added the ability to label messages
* implemented cookie-based identification in the web interface
* fixed a bug where a false positive happening whenever a wrong user login was given during an indirect bind
* remove the constraint that a username can't begin with a digit
* deleting a message no longer expunges its parent folder
* implemented support for multiple calendars
* it is now possible to rename folders
* fixed search in message content
* added tooltips for toolbar buttons (English and French)
* added checkmarks in live search options popup menus
* added browser detection with recommanded alternatives
* support for resizable columns in tables
* improved support for multiple selection in tables and lists
* improved IE7 and Safari support: attendees selector, email file attachments
* updated PrototypeJS to version 1.6.0
* improved address completion and freebusy timeline in attendees selector
* changed look of message composition window to Thunderbird 2.0
* countless bugfixes

## 0.9.0 (2007-08-24)

### Bug Fixes

* added the ability to choose the default module from the application settings: "Calendars", "Contacts" or "Mail"
* added the ability to show or hide the password change dialog from the application settings
* put a work-around in the LDAP directory code to avoid fetching all the entries whenever a specific one is being requested
* added support for limiting LDAP queries with the SOGoLDAPQueryLimit and the SOGoLDAPSizeLimit settings
* fixed a bug where folders starting with digits would not be displayed
* improved IE7 and Safari support: priority menus, attendees selector, search fields, textarea sizes
* added the ability to print messages from the mailer toolbar
* added the ability to use and configure SMTP as the email transport instead of sendmail
* rewrote the handling of draft objects to comply better with the behaviour of Thunderbird
* added a German translation based on Thunderbird
