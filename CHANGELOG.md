# Changelog

## [2.4.1](https://github.com/inverse-inc/sogo/compare/SOGo-2.4.0...SOGo-2.4.1) (2021-06-01)

### Bug Fixes

* **addressbook(js):** handle multi-values organization field (c_o) ([69b86d3](https://github.com/inverse-inc/sogo/commit/69b86d3f9343de8364d19d5f301a3034cb4bccbd)), closes [#5312](https://www.sogo.nu/bugs/view.php?id=5312)
* **mail:** avoid exception on recent GNUstep when no filename is defined ([a2ef542](https://github.com/inverse-inc/sogo/commit/a2ef542ad4251d32444aa3ad3930ccbd12e8ee65))
* **saml:** don't ignore the signature of messages ([c0e6090](https://github.com/inverse-inc/sogo/commit/c0e60902a0cab4823323d1dd349666e7eb3781f3))
* **saml:** fix profile initialization, improve error handling ([3d1b365](https://github.com/inverse-inc/sogo/commit/3d1b365b5d8802291270824fea176ac5e1838bf9)), closes [#5153](https://www.sogo.nu/bugs/view.php?id=5153) [#5270](https://www.sogo.nu/bugs/view.php?id=5270)

## [2.4.0](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.23...SOGo-2.4.0) (2021-03-31)

### Features

* **core:** Support smtps and STARTTLS for SMTP ([cd3095e](https://github.com/inverse-inc/sogo/commit/cd3095e43b06e4a623cfc63cd990a484d6422191)), closes [#31](https://www.sogo.nu/bugs/view.php?id=31)
* **core:** Debian 10 (Buster) support for x86_64 (closes [#4775](http://sogo.nu/bugs/view.php?id=4775))

### Bug Fixes

* **addressbook(dav):** add support for macOS 11 (Big Sur) ([c65e121](https://github.com/inverse-inc/sogo/commit/c65e1212a55a79ad91f71f3d2bd48486a2c765e7)), closes [#5203](https://www.sogo.nu/bugs/view.php?id=5203)
* **addressbook(dav):** add support for macOS 11 (Big Sur) ([0057524](https://github.com/inverse-inc/sogo/commit/005752498374da5e8906e56e708b13b41254ea66)), closes [#5203](https://www.sogo.nu/bugs/view.php?id=5203)
* **calendar:** fix all-day events in lists ([1268e23](https://github.com/inverse-inc/sogo/commit/1268e2370f04f18526498fad2f259cca926dc74c))
* **web:** restored mail threads state of inbox on initial page load
* **web:** fixed and improved messages list in threads mode
* **web:** sanitize value of draft auto save timer, defaults to 5 minutes
* **core:** adjust syntax for Python > 2 ([9198fc9](https://github.com/inverse-inc/sogo/commit/9198fc9bf63a88e13cb46909ef86b7cc19e4fde9))
* **core:** synchronize database schema with v5 ([a98fe2f](https://github.com/inverse-inc/sogo/commit/a98fe2f850b04fd99f5586c374578ba4dc96ae0d))
* **tool:** sogo-tool manage-acl not working on v2 (closes [#4292](http://sogo.nu/bugs/view.php?id=4292))
* **packaging:** add dh_makeshlibs back ([0fa6947](https://github.com/inverse-inc/sogo/commit/0fa6947a743e46f047c3322c7d710308abdf9a9a))
* **packaging:** disable openchange permenantly ([0c47b63](https://github.com/inverse-inc/sogo/commit/0c47b639b20b47c8eb91f95dade4bdcf84b83174))
* **packaging:** disabled openchange some more ([2911578](https://github.com/inverse-inc/sogo/commit/2911578f4b90e97d1c5e6df3a0c3ccdf02158f36))
* **packaging:** fixed centos 7 (saml) and centos 8 builds ([47d0132](https://github.com/inverse-inc/sogo/commit/47d01326c96a2d7b7946dd9d114406b7afbea628))
* **packaging:** more openchange cleanups ([cfd4c7b](https://github.com/inverse-inc/sogo/commit/cfd4c7b9997ea58af79bda2bf782a5fb54028268))
* **packaging:** more openchange cleanups ([9a0b0cc](https://github.com/inverse-inc/sogo/commit/9a0b0ccb832fdc3b196691cb651f3aa5821672a2))
* **packaging:** remove deps on openchange ([acb2a34](https://github.com/inverse-inc/sogo/commit/acb2a34b61c172153de3b2ad5fff25159ebf5593))

### Localization

* update translations ([32bc1e8](https://github.com/inverse-inc/sogo/commit/32bc1e8ffcd90598550f34baf4070c7cd06f84f9))

### Enhancements

* replace calls to create GMT NSTimeZone instance ([2b33d45](https://github.com/inverse-inc/sogo/commit/2b33d45346fad64aa657ccf28c2aaf80640f1d42)), closes [#3757](https://www.sogo.nu/bugs/view.php?id=3757)

## [2.3.23](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.22...SOGo-2.3.23) (2017-10-18)

### Enhancements

* **web:** added Simplified Chinese (zh_CN) translation - thanks to Thomas Kuiper
* **web:** updated CKEditor to version 4.7.3

### Bug Fixes

* **core:** yearly repeating events are not shown in web calendar (closes [#4237](http://sogo.nu/bugs/view.php?id=4237))
* **core:** correctly handle "Last day of the month" recurrence rule
* **core:** fixed yearly recurrence calculator with until date
* **core:** generalized HTML sanitization to avoid encoding issues when replying/forwarding mails
* **core:** don't expose web calendars to other users (closes [#4331](http://sogo.nu/bugs/view.php?id=4331))
* **eas:** avoid sync requests for shared folders every second (closes [#4275](http://sogo.nu/bugs/view.php?id=4275))

## [2.3.22](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.21...SOGo-2.3.22) (2017-07-20)

### Features

* **eas:** initial EAS v16 and email drafts support

### Enhancements

* **web:** updated CKEditor to version 4.7.1

### Bug Fixes

* **web:** use the organizer's alarm by default when accepting IMIP messages (closes [#3934](http://sogo.nu/bugs/view.php?id=3934))
* **web:** fixed forwarding mails with attachments containing slashes in file names
* **eas:** don't include task folders if we hide them in SOGo (closes [#4164](http://sogo.nu/bugs/view.php?id=4164))
* **core:** not using cleaned data when sending mails (closes [#4199](http://sogo.nu/bugs/view.php?id=4199))
* **core:** don't update subscriptions when owner is not the active user (closes [#3988](http://sogo.nu/bugs/view.php?id=3988))
* **core:** enable S/MIME even when using GNU TLS (closes [#4201](http://sogo.nu/bugs/view.php?id=4201))
* **core:** silence verbose output for sogo-ealarms-notify (closes [#4170](http://sogo.nu/bugs/view.php?id=4170))

## [2.3.21](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.20...SOGo-2.3.21) (2017-06-01)

### Enhancements

* **core:** improved event invitation for all day events (closes [#4145](http://sogo.nu/bugs/view.php?id=4145))
* **core:** now possible to {un}subscribe to folders using sogo-tool
* **eas:** added photo support for GAL search operations
* **web:** added custom fields support from Thunderbird's address book
* **web:** updated CKEditor to version 4.7.0
* **web:** added Latvian (lv) translation - thanks to Juris Balandis

### Bug Fixes

* **core:** fixed calendar component move across collections (closes [#4116](http://sogo.nu/bugs/view.php?id=4116))
* **core:** handle properly mails using windows-1255 charset (closes [#4124](http://sogo.nu/bugs/view.php?id=4124))
* **core:** properly honor the "include in freebusy" setting (closes [#3354](http://sogo.nu/bugs/view.php?id=3354))
* **core:** make sure to use crypt scheme when encoding md5/sha256/sha512 (closes [#4137](http://sogo.nu/bugs/view.php?id=4137))
* **core:** newly subscribed calendars are excluded from freebusy (closes [#3354](http://sogo.nu/bugs/view.php?id=3354))
* **core:** strip cr during LDIF import process (closes [#4172](http://sogo.nu/bugs/view.php?id=4172))
* **web:** fixed mail delegation of pristine user accounts (closes [#4160](http://sogo.nu/bugs/view.php?id=4160))
* **web:** respect SOGoLanguage and SOGoSupportedLanguages (closes [#4169](http://sogo.nu/bugs/view.php?id=4169))
* **eas:** fixed opacity in EAS freebusy (closes [#4033](http://sogo.nu/bugs/view.php?id=4033))
* **eas:** set reply/forwarded flags when ReplaceMime is set (closes [#4133](http://sogo.nu/bugs/view.php?id=4133))
* **eas:** remove alarms over EAS if we don't want them (closes [#4059](http://sogo.nu/bugs/view.php?id=4059))
* **eas:** correctly set RSVP on event invitations
* **eas:** avoid sending IMIP request/update messages for all EAS clients (closes [#4022](http://sogo.nu/bugs/view.php?id=4022))

## [2.3.20](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.19...SOGo-2.3.20) (2017-03-10)

### Features

* **core:** new sogo-tool checkup command to make sure user's data is sane 
* **core:** new sogo-tool manage-acl command to manage calendar/address book ACLs
* **web:** use "date" extension of Sieve to enable/disable vacation auto-reply (closes [#1530](http://sogo.nu/bugs/view.php?id=1530), closes [#1949](http://sogo.nu/bugs/view.php?id=1949))

### Enhancements

* **web:** added Hebrew (he) translation - thanks to Raz Aidlitz
* **web:** updated CKEditor to version 4.6.2

### Bug Fixes

* **core:** remove all alarms before sending IMIP replies (closes [#3925](http://sogo.nu/bugs/view.php?id=3925))
* **core:** fixed handling of exdates and proper intersection for fbinfo (closes [#4051](http://sogo.nu/bugs/view.php?id=4051))
* **core:** remove attendees that have the same identity as the organizer (closes [#3905](http://sogo.nu/bugs/view.php?id=3905))
* **eas:** improved EAS parameters parsing (closes [#4003](http://sogo.nu/bugs/view.php?id=4003))
* **eas:** properly handle canceled appointments
* **web:** fixed SCAYT automatic language selection in HTML editor
* **web:** prevent 304 HTTP status code for Ajax requests on IE (closes [#4066](http://sogo.nu/bugs/view.php?id=4066))

## [2.3.19](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.18...SOGo-2.3.19) (2017-01-09)

### Enhancements

* **core:** added handling of BYSETPOS for BYDAY in recurrence rules
* **core:** improved IMIP handling from Exchange/Outlook clients
* **web:** update jQuery to version 1.12.4 and jQuery UI to version 1.11.4
* **web:** added SOGoMaximumMessageSizeLimit to limit webmail message size
* **web:** added photo support for LDIF import (closes [#1084](http://sogo.nu/bugs/view.php?id=1084))
* **web:** updated CKEditor to version 4.6.1

### Bug Fixes

* **core:** honor blocking wrong login attemps within time interval (closes [#2850](http://sogo.nu/bugs/view.php?id=2850))
* **core:** use source's domain when none defined and trying to match users (closes [#3523](http://sogo.nu/bugs/view.php?id=3523))
* **core:** properly honor the "include in freebusy" setting (closes [#3354](http://sogo.nu/bugs/view.php?id=3354))
* **core:** fix events in floating time during CalDAV's PUT operation (closes [#2865](http://sogo.nu/bugs/view.php?id=2865))
* **core:** handle rounds in sha512-crypt password hashes
* **web:** return login page for unknown users (closes [#2135](http://sogo.nu/bugs/view.php?id=2135))
* **web:** append ics file extension when importing events (closes [#2308](http://sogo.nu/bugs/view.php?id=2308))
* **web:** set a max-height so we can scroll in the attendees list (closes [#3666](http://sogo.nu/bugs/view.php?id=3666))
* **web:** set a max-height so we can scroll in the attachments list (closes [#3413](http://sogo.nu/bugs/view.php?id=3413))
* **web:** handle URI in vCard photos (closes [#2683](http://sogo.nu/bugs/view.php?id=2683))
* **web:** handle semicolon in values during LDIF import (closes [#1760](http://sogo.nu/bugs/view.php?id=1760))
* **eas:** properly escape all GAL responses (closes [#3923](http://sogo.nu/bugs/view.php?id=3923))
* **eas:** properly skip folders we don't want to synchronize (closes [#3943](http://sogo.nu/bugs/view.php?id=3943))
* **eas:** fixed 30 mins freebusy offset with S Planner
* **eas:** now correctly handles reminders on tasks (closes [#3964](http://sogo.nu/bugs/view.php?id=3964))
* **eas:** do not decode from hex the event's UID (closes [#3965](http://sogo.nu/bugs/view.php?id=3965))
* **eas:** add support for "other addresses" (closes [#3966](http://sogo.nu/bugs/view.php?id=3966))
* **eas:** provide correct response status when sending too big mails (closes [#3956](http://sogo.nu/bugs/view.php?id=3956))

## [2.3.18](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.17...SOGo-2.3.18) (2016-11-28)

### Features

* **eas:** relaxed permission requirements for subscription synchronizations (closes [#3118](http://sogo.nu/bugs/view.php?id=3118) and closes [#3180](http://sogo.nu/bugs/view.php?id=3180))

### Enhancements

* **core:** added sha256-crypt and sha512-crypt password support
* **core:** updated time zones to version 2016h
* **eas:** initial support for recurring tasks EAS
* **eas:** now support replied/forwarded flags using EAS (closes [#3796](http://sogo.nu/bugs/view.php?id=3796))
* **eas:** now also search on senders when using EAS Search ops
* **web:** updated CKEditor to version 4.6.0

### Bug Fixes

* **core:** fixed condition in weekly recurrence calculator
* **core:** always send IMIP messages using UTF-8
* **web:** fixed support for recurrent tasks
* **web:** improved validation of mail account delegators
* **web:** allow edition of a mailbox rights when user can administer mailbox
* **web:** restore attributes when rewriting base64-encoded img tags (closes [#3814](http://sogo.nu/bugs/view.php?id=3814))

## [2.3.17](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.16...SOGo-2.3.17) (2016-10-20)

### Enhancements

* **web:** allow custom email address to be one of the user's profile (closes [#3551](http://sogo.nu/bugs/view.php?id=3551))
* **web:** the left column of the attendees editor is resizable (not supported in IE) (closes [#1479](http://sogo.nu/bugs/view.php?id=1479), closes [#3667](http://sogo.nu/bugs/view.php?id=3667))

### Bug Fixes

* **eas:** make sure we don't sleep for too long when EAS processes need interruption
* **eas:** fixed recurring events with timezones for EAS (closes [#3822](http://sogo.nu/bugs/view.php?id=3822))
* **eas:** improve handling of email folders without a parent
* **eas:** never send IMIP reply when the "initiator" is Outlook 2013/2016 
* **core:** only consider SMTP addresses for AD's proxyAddresses (closes [#3842](http://sogo.nu/bugs/view.php?id=3842))

## [2.3.16](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.15...SOGo-2.3.16) (2016-09-28)

### Features

* **eas:** initial support for server-side mailbox search operations

### Enhancements

* **eas:** propagate message submission errors to EAS clients (closes [#3774](http://sogo.nu/bugs/view.php?id=3774))
* **web:** updated CKEditor to version 4.5.11
* **web:** added Serbian (sr) translation - thanks to Bogdanović Bojan

### Bug Fixes

* **web:** correctly set percent-complete for tasks from the list view (closes [#3197](http://sogo.nu/bugs/view.php?id=3197))
* **core:** fixed caching expiration of ACLs assigned to LDAP groups (closes [#2867](http://sogo.nu/bugs/view.php?id=2867))
* **core:** we now search in all domain sources for Apple Calendar
* **core:** properly handle groups in Apple Calendar's delegation
* **core:** make sure new cards always have a UID (closes [#3819](http://sogo.nu/bugs/view.php?id=3819))

## [2.3.15](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.14...SOGo-2.3.15) (2016-09-14)

### Enhancements

* **web:** don't allow a recurrence rule to end before the first occurrence

### Bug Fixes

* **eas:** properly generate the BusyStatus for normal events
* **eas:** properly escape all email and address fields
* **eas:** properly generate yearly rrule
* **core:** strip protocol value from proxyAddresses attribute (closes [#3182](http://sogo.nu/bugs/view.php?id=3182))
* **web:** handle binary content transfer encoding when displaying mails

## [2.3.14](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.13...SOGo-2.3.14) (2016-08-17)

### Features

* **eas:** added folder merging capabilities

### Enhancements

* **web:** expunge drafts mailbox when a draft is sent and deleted
* **web:** style cancelled events in Calendar module (closes [#2800](http://sogo.nu/bugs/view.php?id=2800))
* **web:** updated CKEditor to version 4.5.10

### Bug Fixes

* **eas:** fixed long GUID issue preventing sometimes synchronisation (closes [#3460](http://sogo.nu/bugs/view.php?id=3460))
* **web:** improved extraction of HTML signature in Preferences module
* **web:** really delete mailboxes being deleted from the Trash folder (closes [#595](http://sogo.nu/bugs/view.php?id=595), closes [#1189](http://sogo.nu/bugs/view.php?id=1189), closes [#641](http://sogo.nu/bugs/view.php?id=641))
* **core:** fixing sogo-tool backup with multi-domain configuration but domain-less logins
* **core:** during event scheduling, use 409 instead of 403 so Lightning doesn't fail silently
* **core:** correctly calculate recurrence exceptions when not overlapping the recurrence id
* **core:** prevent invalid SENT-BY handling during event invitations (closes [#3759](http://sogo.nu/bugs/view.php?id=3759))

## [2.3.13](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.12...SOGo-2.3.13) (2016-07-06)

### Features

* **core:** now possible to set default Sieve script (closes [#2949](http://sogo.nu/bugs/view.php?id=2949))
* **core:** new sogo-tool truncate-calendar feature (closes [#1513](http://sogo.nu/bugs/view.php?id=1513), closes [#3141](http://sogo.nu/bugs/view.php?id=3141))
* **eas:** initial Out-of-Office support in EAS

### Enhancements

* **core:** avoid showing bundle loading info when not needed (closes [#3726](http://sogo.nu/bugs/view.php?id=3726))
* **core:** when restoring data using sogo-tool, regenerate Sieve script (closes [#3029](http://sogo.nu/bugs/view.php?id=3029))
* **eas:** use the preferred email identity in EAS if valid (closes [#3698](http://sogo.nu/bugs/view.php?id=3698))
* **eas:** handle inline attachments during EAS content generation
* **web:** update jQuery File Upload library to 9.12.5

### Bug Fixes

* **web:** fixed crash when an attachment filename has no extension
* **web:** dragging a toolbar button was blocking the mail editor in Firefox
* **eas:** handle base64 EAS protocol version

## [2.3.12](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.11...SOGo-2.3.12) (2016-06-10)

### Enhancements

* **web:** updated CKEditor to version 4.5.9
* **web:** CKEditor: switched to the minimalist skin
* **web:** CKEditor: added the base64image plugin
* **web:** CKEditor: added the pastefromword plugin (closes [#2295](http://sogo.nu/bugs/view.php?id=2295), closes [#3313](http://sogo.nu/bugs/view.php?id=3313))
* **web:** added Turkish (Turkey) (tr_TR) translation - thanks to Sinan Kurşunoğlu

### Bug Fixes

* **core:** sanity checks for events with bogus timezone offsets
* **core:** strip X- tags when securing content (closes [#3695](http://sogo.nu/bugs/view.php?id=3695))
* **core:** properly handle flattened timezone definitions (closes [#2690](http://sogo.nu/bugs/view.php?id=2690))
* **eas:** when using EAS/ItemOperations, use IMAP PEEK operation
* **web:** fixed recipients when replying from a message in the Sent mailbox (closes [#2625](http://sogo.nu/bugs/view.php?id=2625))
* **web:** fixed localizable strings in Card viewer
* **web:** properly encode HTML attributes in Contacts module to avoid XSS issues
* **web:** handle c_mail field format of quick record of contacts of v3 (closes [#3443](http://sogo.nu/bugs/view.php?id=3443))
* **web:** fixed all-day events covering a timezone change (closes [#3457](http://sogo.nu/bugs/view.php?id=3457))
* **web:** fixed display of invitation with a category (closes [#3590](http://sogo.nu/bugs/view.php?id=3590))

## [2.3.11](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.10...SOGo-2.3.11) (2016-05-12)

### Bug Fixes

* properly escape organizer name when using EAS (closes [#3615](http://sogo.nu/bugs/view.php?id=3615))
* properly escape wide characters (closes [#3616](http://sogo.nu/bugs/view.php?id=3616))
* calendars list when creating a new component in a calendar in which the user can't delete components
* avoid double-appending domains in cache for multi-domain configurations (closes [#3614](http://sogo.nu/bugs/view.php?id=3614))
* encode CR in EAS payload (closes [#3626](http://sogo.nu/bugs/view.php?id=3626))
* password change during login process when using ppolicy
* correctly set answered/forwarded flags during EAS smart operations
* don't mark calendar invitations as read when fetching messages using EAS
* fixed messages archiving as zip file
* fixed multi-domain issue with non-unique ID across domains (closes [#3625](http://sogo.nu/bugs/view.php?id=3625))
* fixed bogus headers generation when stripping folded bcc header (closes [#3664](http://sogo.nu/bugs/view.php?id=3664))
* fixed issue with multi-value org units (closes [#3630](http://sogo.nu/bugs/view.php?id=3630))
* fixed sensitive range of checkboxes in appointment editor (closes [#3665](http://sogo.nu/bugs/view.php?id=3665))

## [2.3.10](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.9...SOGo-2.3.10) (2016-04-05)

### Features

* new user-based rate-limiting support for all SOGo requests (closes [#3188](http://sogo.nu/bugs/view.php?id=3188))

### Bug Fixes

* respect the LDAP attributes mapping in the list view
* handle empty body data when forwarding mails (closes [#3581](http://sogo.nu/bugs/view.php?id=3581))
* correctly set EAS message class for S/MIME messages (closes [#3576](http://sogo.nu/bugs/view.php?id=3576))
* we now handle the default classifications for tasks (closes [#3541](http://sogo.nu/bugs/view.php?id=3541))
* handle FilterType changes using EAS (closes [#3543](http://sogo.nu/bugs/view.php?id=3543))
* handle Dovecot's mail_shared_explicit_inbox parameter when using EAS
* prevent concurrent Sync ops from same EAS device (closes [#3603](http://sogo.nu/bugs/view.php?id=3603))
* handle EAS loop termination when SOGo is being shutdown (closes [#3604](http://sogo.nu/bugs/view.php?id=3604))
* avoid marking mails as read when archiving a folder (closes [#2792](http://sogo.nu/bugs/view.php?id=2792))
* now cache heartbeat interval and folders list during EAS Ping ops (closes [#3606](http://sogo.nu/bugs/view.php?id=3606))
* sanitize non-us-ascii 7bit emails when using EAS (closes [#3592](http://sogo.nu/bugs/view.php?id=3592))

## [2.3.9](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.8...SOGo-2.3.9) (2016-03-16)

### Features

* you can now limit the file upload size using the WOMaxUploadSize configuration parameter (integer value in kilobytes) (closes [#3510](http://sogo.nu/bugs/view.php?id=3510), closes [#3135](http://sogo.nu/bugs/view.php?id=3135))

### Enhancements

* allow resources to prevent invitations (closes [#3410](http://sogo.nu/bugs/view.php?id=3410))
* now support EAS MIME truncation
* added Lithuanan (lt) translation - thanks to Mantas Liobė

### Bug Fixes

* allow EAS attachments get on 2nd-level mailboxes (closes [#3505](http://sogo.nu/bugs/view.php?id=3505))
* fixed EAS bday shift (closes [#3518](http://sogo.nu/bugs/view.php?id=3518))
* prefer SOGoRefreshViewCheck to SOGoMailMessageCheck (closes [#3465](http://sogo.nu/bugs/view.php?id=3465))
* properly unfold long mail headers (closes [#3152](http://sogo.nu/bugs/view.php?id=3152))

## [2.3.8](https://github.com/inverse-inc/sogo/compare/SOGo-2.3.7...SOGo-2.3.8) (2016-02-05)

### Enhancements

* updated CKEditor to version 4.5.7

### Bug Fixes

* correctly encode filename of attachments over EAS (closes [#3491](http://sogo.nu/bugs/view.php?id=3491))
* correctly encode square brackets for IMAP folder names (closes [#3321](http://sogo.nu/bugs/view.php?id=3321))
* add shared/public namespaces in the list or returned folders

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

* unit testing for RTFHandler
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
