# Changelog

## [5.4.0](https://github.com/inverse-inc/sogo/compare/SOGo-5.3.0...SOGo-5.4.0) (2021-12-16)

### Features

* **mail:** delay or disable automatic mark message as read ([4eed98d](https://github.com/inverse-inc/sogo/commit/4eed98d58dbdf14a3366749cf1d8ff22887e32ef)), closes [#1585](https://sogo.nu/bugs/view.php?id=1585)
* **mail:** enable autoreply on specific days or at a specific time ([2ecd441](https://github.com/inverse-inc/sogo/commit/2ecd441f3200862fee28a66aadf29c758f0ead24)), closes [#5328](https://sogo.nu/bugs/view.php?id=5328)

### Bug Fixes

* **addressbook(js):** custom field creation ([fc121ac](https://github.com/inverse-inc/sogo/commit/fc121acff3e0e64a11530c30dcc1e3bccb6cf40b))
* **calendar(js):** improve bi-weekly event description ([c17165d](https://github.com/inverse-inc/sogo/commit/c17165d85dd4d17c540f3b52905db3086890cc18)), closes [#5261](https://sogo.nu/bugs/view.php?id=5261)
* **calendar:** update email alarm of yearly events ([9c025f6](https://github.com/inverse-inc/sogo/commit/9c025f68713b6d07f8e6f6d4e00bf23466cc7249)), closes [#4991](https://sogo.nu/bugs/view.php?id=4991)
* **core:** avoid exception when the user's cn is null ([153c1ee](https://github.com/inverse-inc/sogo/commit/153c1eeb80b7b52d65635346d54a79f13109f48c))
* **login(js):** input focus on TOTP field ([56a6f24](https://github.com/inverse-inc/sogo/commit/56a6f246d6c3aa2f37e83d7cf5d35d470657f5e8))
* **mail(html):** ban "javascript:" prefix in href, action and formaction ([8afc80d](https://github.com/inverse-inc/sogo/commit/8afc80d82ed6e803b1c213dbbdeac729eadc7f07))
* **mail(js):** create new object instances in popup from parent's data ([a98b46a](https://github.com/inverse-inc/sogo/commit/a98b46a7a7ed47c4a6fd1f6434a7b4d3a7f8eef5))
* **mail(js):** don't allow to rename special mailboxes ([c3c9432](https://github.com/inverse-inc/sogo/commit/c3c9432cc2fe296a210d09d7ee73fe0b2d1d2b5b))
* **mail(js):** don't load mailboxes list from popup editor ([cb6b729](https://github.com/inverse-inc/sogo/commit/cb6b729c581d528413107159db624319fca69f85))
* **mail(js):** don't poll server from popup windows ([8724f90](https://github.com/inverse-inc/sogo/commit/8724f90dd159f6a6efeb2a14327a2cc9b7af1bc0), [11eb6c2](https://github.com/inverse-inc/sogo/commit/11eb6c29d4bc92ed56628269ac03814bd68f8b02))
* **mail(js):** expose all account identities in popup window ([78855be](https://github.com/inverse-inc/sogo/commit/78855be162f2f30f01bc15ed70085b890a6e35d9)), closes [#5442](https://sogo.nu/bugs/view.php?id=5442)
* **mail(js):** ignore return key in input fields of editor ([1786ec4](https://github.com/inverse-inc/sogo/commit/1786ec4d590e6d36565c57bac4108e846fe73ab5)), closes [#4666](https://sogo.nu/bugs/view.php?id=4666)
* **mail(js):** open one distinct popup for each action ([addf3c1](https://github.com/inverse-inc/sogo/commit/addf3c1c76960da191fa1e70b53611d0cc3caf93)), closes [#5431](https://sogo.nu/bugs/view.php?id=5431)
* **mail(js):** resolve draft mailbox from popup window ([25c69aa](https://github.com/inverse-inc/sogo/commit/25c69aaef48916ed07874b19528a90e4fb1a8c4a)), closes [#5442](https://sogo.nu/bugs/view.php?id=5442)
* **mail(js):** save draft after having removed an attachment ([6ef99a5](https://github.com/inverse-inc/sogo/commit/6ef99a5ec4a655323ddbc9da8955239a432e5180)), closes [#5432](https://sogo.nu/bugs/view.php?id=5432)
* **mail(js):** update unseen count when it's zero ([635b8c6](https://github.com/inverse-inc/sogo/commit/635b8c68db21666f5c5abe3d30b7a757ca90d9d9))
* **mail(web):** display emails extracted from smime certificate ([93dff69](https://github.com/inverse-inc/sogo/commit/93dff697e7aebe7ec95437b5f7b07a85f3a0bb06)), closes [#5440](https://sogo.nu/bugs/view.php?id=5440)
* **mail:** allow to directly empty junk folder ([f9ed639](https://github.com/inverse-inc/sogo/commit/f9ed6391e68dd8d52642300b16578a7808c168db)), closes [#5224](https://sogo.nu/bugs/view.php?id=5224)
* **mail:** check if smime certificate matches sender address ([e85576c](https://github.com/inverse-inc/sogo/commit/e85576cbb7514876ac72fb60fd9da2e1b7545331)), closes [#5407](https://sogo.nu/bugs/view.php?id=5407)
* **mail:** delete msgs once moved to an external account ([e0df548](https://github.com/inverse-inc/sogo/commit/e0df54838e0f16a936df942357dfb471fc26bafb))
* **mail:** don't lowercase href/action/formaction attribute value ([c4bb0de](https://github.com/inverse-inc/sogo/commit/c4bb0de11e5ea4432612c974cf238845600d3601)), closes [#5434](https://sogo.nu/bugs/view.php?id=5434)
* **mail:** only apply IMAP host constraint when SSO is enabled ([8cb5ef3](https://github.com/inverse-inc/sogo/commit/8cb5ef363a7752ad4e1aa8e747c8c8235f8c0edc)), closes [#5433](https://sogo.nu/bugs/view.php?id=5433)
* **mail:** show comment attribute of iTIP replies ([ff1eeca](https://github.com/inverse-inc/sogo/commit/ff1eecaf5a243757a70ffd190cdbddd5b8021f1b)), closes [#5410](https://sogo.nu/bugs/view.php?id=5410)
* **mail:** sign and send only if smime certificate matches sender address ([4ad2105](https://github.com/inverse-inc/sogo/commit/4ad2105543e782134743fd1fc180c5f9c8a70652)), closes [#5407](https://sogo.nu/bugs/view.php?id=5407)
* **preferences(css):** align timepicker inside input container ([2014589](https://github.com/inverse-inc/sogo/commit/201458954b9e950a721fa21e0078fb7256e4040f))
* **preferences(js):** don't alter the list of default email addresses ([bdfe1be](https://github.com/inverse-inc/sogo/commit/bdfe1be7705252c8d732d55659d638654d74ff4c)), closes [#5443](https://sogo.nu/bugs/view.php?id=5443)
* **preferences(js):** improve initialization of dates/times constraints ([46971d4](https://github.com/inverse-inc/sogo/commit/46971d47b922c1f464dc10db021653f721d00e24)), closes [#5443](https://sogo.nu/bugs/view.php?id=5443)
* **preferences(js):** set default auto mark as read delay to 5 ([cb4d555](https://github.com/inverse-inc/sogo/commit/cb4d555e4a215d452222d98e5601b318d28460aa)), closes [#5443](https://sogo.nu/bugs/view.php?id=5443)
* **preferences:** add plus sign to timezone in Sieve script ([f191231](https://github.com/inverse-inc/sogo/commit/f1912310db903455a0ab9422018278f3b36245e5), [2daeab3](https://github.com/inverse-inc/sogo/commit/2daeab3dd7391e8ca8c9b5b013ef14dba3ef10f1)), closes [#5448](https://sogo.nu/bugs/view.php?id=5448)
* **web(js):** position notifications to the bottom right ([e064e9a](https://github.com/inverse-inc/sogo/commit/e064e9af442e44f6ff7baea68bf93e8d6c9b4bf6)), closes [#5127](https://sogo.nu/bugs/view.php?id=5127) [#5423](https://sogo.nu/bugs/view.php?id=5423)
* **web:** add missing tooltips for expand/reduce buttons ([1febace](https://github.com/inverse-inc/sogo/commit/1febace83767f243ac5f3d2489ad080d1449a5e2))

### Localization

* **de:** update German translation ([b665f7e](https://github.com/inverse-inc/sogo/commit/b665f7e1c66bcff97058dfd8f0390262d24edde6), [6684784](https://github.com/inverse-inc/sogo/commit/668478476994de393eecf0fe0273598353fa255d))
* **fr:** update French translation ([6084fcd](https://github.com/inverse-inc/sogo/commit/6084fcd435883b9de8c38a3baa6df9ed5a608180), [748fd8f](https://github.com/inverse-inc/sogo/commit/748fd8fa9a3f14a2311d98583e25e4efecaa1c75))
* **hu:** update Hungarian translation ([07f2c26](https://github.com/inverse-inc/sogo/commit/07f2c2606ddfe250f6f2fbad35f291e179fa90a0))
* **pl:** update Polish translation ([3e9b8db](https://github.com/inverse-inc/sogo/commit/3e9b8db78cd7a733f8cfabbda146390c034a048e), [070f1a6](https://github.com/inverse-inc/sogo/commit/070f1a6094beee30e0d87a20aa2e9c4c17ef33f7))

## [5.3.0](https://github.com/inverse-inc/sogo/compare/SOGo-5.2.0...SOGo-5.3.0) (2021-11-18)

### Features

* **addressbook:** warn when similar contacts are found ([a14c456](https://github.com/inverse-inc/sogo/commit/a14c45680029a846759179c33743626059835520))
* **mail:** add support for UID MOVE operation ([d1fc15b](https://github.com/inverse-inc/sogo/commit/d1fc15b3a428d16819732fa500bec312ab8b61a8))
* **mail:** allow to directly empty junk folder ([6c56340](https://github.com/inverse-inc/sogo/commit/6c56340ba51d8f7a04ffb0522c1bb93a6bf9c771)), closes [#5224](https://sogo.nu/bugs/view.php?id=5224)
* **mail:** filter mailbox by flagged messages ([c2f95dc](https://github.com/inverse-inc/sogo/commit/c2f95dc56a1c4ef12a5c767e99a5a29acc74f39c)), closes [#1417](https://sogo.nu/bugs/view.php?id=1417)
* **mail:** filter mailbox by unread messages ([e5dbebb](https://github.com/inverse-inc/sogo/commit/e5dbebb10016f197d2e1646f67aeddb6ca1cd6b8)), closes [#1146](https://sogo.nu/bugs/view.php?id=1146) [#3156](https://sogo.nu/bugs/view.php?id=3156) [#4752](https://sogo.nu/bugs/view.php?id=4752)
* **mail:** filter messages by tags (labels) ([fbb7672](https://github.com/inverse-inc/sogo/commit/fbb76722e3716117ef7fdc370fc3fd583dd3b2d8), [800e21b](https://github.com/inverse-inc/sogo/commit/800e21b05d6beef6c9151b9d7f6fedbad5e8b238)), closes [#3323](https://sogo.nu/bugs/view.php?id=3323) [#3835](https://sogo.nu/bugs/view.php?id=3835) [#5338](https://sogo.nu/bugs/view.php?id=5338)
* **mail:** prioritize personal address books in autocompletion ([8065091](https://github.com/inverse-inc/sogo/commit/80650919b8fd526412a8b2a67470c936a55f84e4))

### Bug Fixes

* **addressbook(js):** load selected cards prior to display mail editor ([c6d6dc3](https://github.com/inverse-inc/sogo/commit/c6d6dc3e668826a2ef4fff21bc72bfda53cb947e))
* **addressbook(js):** sanitize fullname when using HTML ([0b0c884](https://github.com/inverse-inc/sogo/commit/0b0c8847bab6dae2040bcda54bea3a5e94706897), [ffed88c](https://github.com/inverse-inc/sogo/commit/ffed88c0696fdde8560d035eaafbeb363d93544c)), closes [#5400](https://sogo.nu/bugs/view.php?id=5400)
* **addressbook:** fix compilation warnings in UIxContactFoldersView.m ([9f38201](https://github.com/inverse-inc/sogo/commit/9f38201b6c8a356798868decda9f4331bba4768f))
* **addressbook:** generate UID when importing cards if missing ([7b5cddc](https://github.com/inverse-inc/sogo/commit/7b5cddcf2dd613e3e56668837af97f1d731e9e06)), closes [#5386](https://sogo.nu/bugs/view.php?id=5386)
* **addressbook:** properly handle unknown properties in DAV report ([4884cb3](https://github.com/inverse-inc/sogo/commit/4884cb3978c1401ff4310265ff409eb7f335f623))
* **addressbook:** reuse LDAP connection in CardDAV report ([3da633a](https://github.com/inverse-inc/sogo/commit/3da633aebf276e9919325ae18bf5a0357f57f4ea)), closes [#5355](https://sogo.nu/bugs/view.php?id=5355)
* **addressbook:** use pool to lower memory usage ([a073241](https://github.com/inverse-inc/sogo/commit/a073241e0f4ff9c761a7f6b25502a6000bb1bf89), [dec4f24](https://github.com/inverse-inc/sogo/commit/dec4f24aa44abccd9c311e9cbb440f32198ef3e2))
* **calendar:** fix weekly calculator when event has no duration ([e79b01e](https://github.com/inverse-inc/sogo/commit/e79b01ebd1d673379b3ac88e0ab7052a122f39a3))
* **calendar:** generate missing UID when importing calendar ([e43a721](https://github.com/inverse-inc/sogo/commit/e43a721f77e8388b229f23db6cd5320823ece615))
* **calendar:** send modification notifications for tasks ([4c679f1](https://github.com/inverse-inc/sogo/commit/4c679f1f7b77fe870c549ce1fd56b86a87a21293), [1ccfa86](https://github.com/inverse-inc/sogo/commit/1ccfa865bba6e2ee444a99e4899fa21476273557))
* **calendar:** truncate long UIDs to avoid SQL insert error ([8cec92e](https://github.com/inverse-inc/sogo/commit/8cec92ea87d5319b42f2c3f904bbf9111b8b4337))
* **core:** don't log error when deleting an invalid key in memcached ([0716656](https://github.com/inverse-inc/sogo/commit/0716656cd4e533f2c4fc29d662b5c54afec3fc12))
* **core:** handle null values in modules constraints of SQL sources ([f0368d0](https://github.com/inverse-inc/sogo/commit/f0368d028b7ff20f9a793d81e71e36921b3368c7))
* **doc:** add theme for asciidoctor-pdf ([f6a50bb](https://github.com/inverse-inc/sogo/commit/f6a50bb963a8d589944c008890c6e7b8183c2cb2))
* **eas:** handle attachments of type message/rfc822 when sanitize emails (fixes [#5427](https://sogo.nu/bugs/view.php?id=5427)) ([#304](https://sogo.nu/bugs/view.php?id=304)) ([33b2406](https://github.com/inverse-inc/sogo/commit/33b2406bf153da7c72bab83c1e4a6b1d99c8cd15))
* **eas:** proxy authentication in _sendMail ([f70d600](https://github.com/inverse-inc/sogo/commit/f70d60004d4c0695e9c4ba4ae7d0d9051b89028e))
* **eas:** use base64 encoding for attachments when sanitize emails + content-length ([bfcb0b9](https://github.com/inverse-inc/sogo/commit/bfcb0b923488d49a870749e63d925888e25bb3c5)), closes [#5408](https://sogo.nu/bugs/view.php?id=5408)
* **i18n(sr_RS:** fix HTML templates ([fb22c0a](https://github.com/inverse-inc/sogo/commit/fb22c0abaf122a61e040670e8d8f4ef7fd122a59)), closes [#5339](https://sogo.nu/bugs/view.php?id=5339)
* **mail(css):** add bold font to mailboxes with positive unseen count ([270bc2e](https://github.com/inverse-inc/sogo/commit/270bc2ed2ea383c806c4405a71c8c9b20bc9d3dd)), closes [#4277](https://sogo.nu/bugs/view.php?id=4277)
* **mail(css):** improve CSS sanitization of at-rules ([e714a3f](https://github.com/inverse-inc/sogo/commit/e714a3f42b3be60d3ca61bf3dc0d0a68bbdc96a3)), closes [#5387](https://sogo.nu/bugs/view.php?id=5387)
* **mail(dav):** add support for property {DAV:}getcontentlength ([9c2b3bd](https://github.com/inverse-inc/sogo/commit/9c2b3bd473f14119305bdccee148ee86a544ba97))
* **mail(dav):** fix mail-query response ([4df5e4b](https://github.com/inverse-inc/sogo/commit/4df5e4b8fc1265cc826262f5e74ea5a3c5453277))
* **mail(dav):** restore support for filtering by sent-date ([563f1d2](https://github.com/inverse-inc/sogo/commit/563f1d28429289316b85d54f452f3eb48f5aa6ed))
* **mail(html):** ban "javascript:" prefix in href, action and formaction ([e99090b](https://github.com/inverse-inc/sogo/commit/e99090b6b3260a28db166b4ed62557ea8a373cb4))
* **mail(js):** allow to add any event invitation ([56f9e3e](https://github.com/inverse-inc/sogo/commit/56f9e3e398f3baae31674e52d3a51da1dd3a0fd1))
* **mail(js):** ban all "on*" events attributes from HTML tags ([a5c315f](https://github.com/inverse-inc/sogo/commit/a5c315fd1735c9370bc135bdd088efe6900a906d))
* **mail(js):** fix height of mailboxes list items ([145f221](https://github.com/inverse-inc/sogo/commit/145f221552483512bc9790bdd741ee13d45660fc))
* **mail(js):** force search when restoring mailbox during navigation ([0eb452c](https://github.com/inverse-inc/sogo/commit/0eb452c412f3c429f2adf5ae668b3059d6ff6e43))
* **mail(js):** reload UIDs when changing sort order ([2a8d64d](https://github.com/inverse-inc/sogo/commit/2a8d64d891617cb89f67b0dc1785532982d679f7)), closes [#5385](https://sogo.nu/bugs/view.php?id=5385)
* **mail(js):** reset mailboxes state when leaving global search ([642db85](https://github.com/inverse-inc/sogo/commit/642db852c72b6f9d13e7bb8eb1f74e5baeb63edf))
* **mail(js):** reset messages list after emptying trash ([9622a1e](https://github.com/inverse-inc/sogo/commit/9622a1ea07bcf23cff0cd2e1c8dd155579fa9031)), closes [#5421](https://sogo.nu/bugs/view.php?id=5421)
* **mail(js):** show "Download all attachments" menu option ([86f08a2](https://github.com/inverse-inc/sogo/commit/86f08a2380147bf0cb1ed3f618aa90b116dc838f))
* **mail(js):** update list of labels when adding one to a message ([37d06c6](https://github.com/inverse-inc/sogo/commit/37d06c6f211fe0c61ed96a255f36bfb1b8a329b3))
* **mail(js):** update unseen count when reaching zero ([2d25e18](https://github.com/inverse-inc/sogo/commit/2d25e180f6fbc104736037c88fedf2144e433e1a)), closes [#5381](https://sogo.nu/bugs/view.php?id=5381)
* **mail(js):** use message subject as filename of .eml ([792d96b](https://github.com/inverse-inc/sogo/commit/792d96b36149c1627580cae1ca3d09b027a822d2))
* **mail(web):** improve identification of mailboxes ([7c7df9b](https://github.com/inverse-inc/sogo/commit/7c7df9b47c791cd930702390ab2c51fa1c549f88))
* **mail:** check if smime certificate matches sender address ([ab67e7d](https://github.com/inverse-inc/sogo/commit/ab67e7d27953e6bbea053bbe4fdc446cc4191329)), closes [#5407](https://sogo.nu/bugs/view.php?id=5407)
* **mail:** check if smime certificate matches sender address ([6eb5e97](https://github.com/inverse-inc/sogo/commit/6eb5e971545830d4ee8e4ebe6299d11c97ccd96b)), closes [#5407](https://sogo.nu/bugs/view.php?id=5407)
* **mail:** decode ms-tnef (winmail.dat) inside message/rfc822 part ([d181cc4](https://github.com/inverse-inc/sogo/commit/d181cc4d0644c048e25f8a24d4da91bb0923f28b)), closes [#5388](https://sogo.nu/bugs/view.php?id=5388)
* **mail:** don't encode calendar mime part twice ([2c62aaf](https://github.com/inverse-inc/sogo/commit/2c62aafe70f299a2751ab84e75aa1be9c23d7e29)), closes [#5391](https://sogo.nu/bugs/view.php?id=5391) [#5393](https://sogo.nu/bugs/view.php?id=5393)
* **mail:** don't open XML attachments in browser ([d54dca9](https://github.com/inverse-inc/sogo/commit/d54dca9a1bff08ef722fd9e2dd1d350d8ce95293))
* **mail:** encode text MIME parts in quoted-printable ([9e364c6](https://github.com/inverse-inc/sogo/commit/9e364c647ff7ed6e3e0bab1b1b19fd3bbfd9b65e)), closes [#5378](https://sogo.nu/bugs/view.php?id=5378)
* **mail:** encode text MIME parts in quoted-printable ([6cf3d99](https://github.com/inverse-inc/sogo/commit/6cf3d9912595dccaf5e148b7ea622e933f5c0a76)), closes [#5376](https://sogo.nu/bugs/view.php?id=5376)
* **mail:** fix end date of all-day event in mail notifications ([ef5820b](https://github.com/inverse-inc/sogo/commit/ef5820b49bfd8f3f53b5d6e6070bc5e2c970603b)), closes [#5384](https://sogo.nu/bugs/view.php?id=5384)
* **mail:** new action to fetch the flags of a mailbox ([175e380](https://github.com/inverse-inc/sogo/commit/175e3802b75ff1697a7631da5f60105894338250))
* **mail:** properly sort partial fetch results (modseq) ([534bea6](https://github.com/inverse-inc/sogo/commit/534bea674bb65242fc19e4184924d4d93c5103e3)), closes [#5385](https://sogo.nu/bugs/view.php?id=5385)
* **mail:** replace STATUS by LIST command when copying/moving msgs ([0765c72](https://github.com/inverse-inc/sogo/commit/0765c726163c8b1ac255efcf55d3c7f622379994)), closes [#4983](https://sogo.nu/bugs/view.php?id=4983)
* **mail:** split "l" and "r" ACL attributes for IMAP mailboxes ([08581ee](https://github.com/inverse-inc/sogo/commit/08581eefab1ce57ca2a9a2a87ec8e05351130636)), closes [#4983](https://sogo.nu/bugs/view.php?id=4983)
* **mail:** use pool to lower memory usage ([cae51dc](https://github.com/inverse-inc/sogo/commit/cae51dc4d68be6a5edde396a268be4c185974f34))
* **preferences(js):** review order of mail filter actions ([138ee06](https://github.com/inverse-inc/sogo/commit/138ee065a24cc65f5d3db1c6e2e93500f33acd92)), closes [#5325](https://sogo.nu/bugs/view.php?id=5325)
* **web(css):** print more than one page in Firefox ([ea6b699](https://github.com/inverse-inc/sogo/commit/ea6b6990944cd1b8e2733c94b859f1fa2003f323)), closes [#5375](https://sogo.nu/bugs/view.php?id=5375)
* **web(js):** reset cached users when closing subscription dialog ([38b95af](https://github.com/inverse-inc/sogo/commit/38b95af9fd26170f1e91f4b0907abcd4cfad5662))
* **web:** contextualize title in subscription dialog ([8f99965](https://github.com/inverse-inc/sogo/commit/8f999652cc1b1d65f6504a174a7cc31d700ff8c3))
* **web:** use a distinct salt for TOTP authentication ([d751ad9](https://github.com/inverse-inc/sogo/commit/d751ad99d6ef73be26b5e2cef987964dde3226e6), [d4da1fa](https://github.com/inverse-inc/sogo/commit/d4da1facf9689766df058d8db3023767c6ece12d))

### Enhancements

* **calendar(web):** initiate Web calendars reload from the frontend ([f017c42](https://github.com/inverse-inc/sogo/commit/f017c42608a71279015add6d67e12675759c4a5d)), closes [#4939](https://sogo.nu/bugs/view.php?id=4939)
* **tests:** conversion of Python integration tests to JavaScript ([1a7ba3d](https://github.com/inverse-inc/sogo/commit/1a7ba3d4efa409b53d72f1c602199f7a320d0671))

### Localization

* **bg_BG:** update Bulgarian translation ([f669b76](https://github.com/inverse-inc/sogo/commit/f669b764359acae0866cebeb6032a476424fc174))
* **cs:** update Czech translation ([f10e13b](https://github.com/inverse-inc/sogo/commit/f10e13b725f9fb2e41a0c047c37fd32ca1d51f46))
* **de:** update German translation ([5e7c9a8](https://github.com/inverse-inc/sogo/commit/5e7c9a8890ae89488520668a1f23c0c06cc55447)), closes [#5417](https://sogo.nu/bugs/view.php?id=5417)
* **de:** update German translation ([a33cf3c](https://github.com/inverse-inc/sogo/commit/a33cf3cd67861c932f299fe52d9abc4fc0d42f68))
* **pl:** update Polish translation ([b2b1237](https://github.com/inverse-inc/sogo/commit/b2b12375db0e08610417ab28db8b1a9c1e151c94))
* **pt_BR:** update Brazilian Portuguese translation ([7072319](https://github.com/inverse-inc/sogo/commit/7072319ddfb79ef0933f657f26e7055a7f798f63))
* **ru:** update Russian translation ([710fd2f](https://github.com/inverse-inc/sogo/commit/710fd2f49228efbdf3ac792494ec8a6eb438ea60))
* **uk:** update Ukrainian translation ([e77d228](https://github.com/inverse-inc/sogo/commit/e77d228b58ea50d4c82c9ebfb6565267f2686b65))

## [5.2.0](https://github.com/inverse-inc/sogo/compare/SOGo-5.1.1...SOGo-5.2.0) (2021-08-18)

### Features

* **mail:** download message as .eml file ([ef5e777](https://github.com/inverse-inc/sogo/commit/ef5e7775cdb030ecd8354cfa2c9ec934c9055909))
* **mail:** initial support for ms-tnef (winmail.dat) body part ([045f134](https://github.com/inverse-inc/sogo/commit/045f134321e220055b16a0b41e318449cdd3ef09)), closes [#2242](https://sogo.nu/bugs/view.php?id=2242) [#4503](https://sogo.nu/bugs/view.php?id=4503)
* **mail:** new parameter to disable S/MIME certificates ([545cfe5](https://github.com/inverse-inc/sogo/commit/545cfe58c6cf45032b2fc585ad1a40efc7eccf09))

### Bug Fixes

* **calendar(dav):** add method attribute to content-type of iTIP reply ([e08be0d](https://github.com/inverse-inc/sogo/commit/e08be0d00615e39906ef0c96c86dcce03782792b)), closes [#5320](https://sogo.nu/bugs/view.php?id=5320)
* **calendar(web):** search in all user's calendars for iMIP reply ([0aabd45](https://github.com/inverse-inc/sogo/commit/0aabd45c047540a7489e380a27db053918fcfd12))
* **core:** improve logged error when module is invalid ([aa59aa9](https://github.com/inverse-inc/sogo/commit/aa59aa9c47b7da6dc6d1bbcf74c7d34d4555dfe9))
* **core:** properly validate domain using "domains" keys ([a370aa7](https://github.com/inverse-inc/sogo/commit/a370aa70f29f008af85520fdfed7d7d909791885))
* **core:** remove CR, diacritical marks, variation selectors ([90752c4](https://github.com/inverse-inc/sogo/commit/90752c43822d1b9c6e034a5c40aed6bc1533f571))
* **css:** improve display of category colors (Calendar & Mail) ([322226b](https://github.com/inverse-inc/sogo/commit/322226bd81b9f8716c69e4898a3b3d7698be4fbf)), closes [#5337](https://sogo.nu/bugs/view.php?id=5337)
* **login(js):** fix domain in redirect URL ([7e63452](https://github.com/inverse-inc/sogo/commit/7e63452141eaa20eb21209fed1e7ed1555e15784))
* **mail:** add support for messages quota ([a1273f1](https://github.com/inverse-inc/sogo/commit/a1273f1097898a27c5740351ce7b73a2a7a2147c)), closes [#5365](https://sogo.nu/bugs/view.php?id=5365)
* **mail:** don't render SVG attachments ([40b570c](https://github.com/inverse-inc/sogo/commit/40b570cc12d58ae53469520c4f64384c60d7684e)), closes [#5371](https://sogo.nu/bugs/view.php?id=5371)
* **mail:** fix end date of all-day event in mail notifications ([694ffa7](https://github.com/inverse-inc/sogo/commit/694ffa74ba8989c36931f979b0e57b07493aef61)), closes [#4145](https://sogo.nu/bugs/view.php?id=4145)
* **mail:** improve performance of listing all mailboxes ([54548c5](https://github.com/inverse-inc/sogo/commit/54548c550ffa601bafe6e354f627100ecec5924e))
* **mail:** remove media event handlers from HTML messages ([69972f7](https://github.com/inverse-inc/sogo/commit/69972f725c60ce82236a7281b11a83a4a6151111)), closes [#5369](https://sogo.nu/bugs/view.php?id=5369)
* **mail:** return unseen count of mailbox in msgs operations ([a352256](https://github.com/inverse-inc/sogo/commit/a35225631a14b6663bf6e237033563e714dab232))
* **mail(css):** always show tag dots in messages list ([d13e153](https://github.com/inverse-inc/sogo/commit/d13e1534a8dfea2880c0d32c72fd7f8c00212efe))
* **mail(html):** format links in comment of Calendar invitations ([2771fe1](https://github.com/inverse-inc/sogo/commit/2771fe180e522e473e8d554b3365a318b45e39c8))
* **mail(js):** avoid using the DOM when sanitizing incoming html ([8947f29](https://github.com/inverse-inc/sogo/commit/8947f29c09594a5e139c70ef64be5cf153dcade9)), closes [#5369](https://sogo.nu/bugs/view.php?id=5369)
* **mail(js):** force reload of UIDs when cancelling search ([b969ca4](https://github.com/inverse-inc/sogo/commit/b969ca4b499c2304a085179d5f03f859745b5088))
* **mail(js):** hide sign and encrypt options if not usable ([eb46415](https://github.com/inverse-inc/sogo/commit/eb464157113021f6771b171c23bb638d9efced25))
* **mail(js):** respect thread level while loading headers ([2d16456](https://github.com/inverse-inc/sogo/commit/2d16456bb505409c6cb14ca4a2c009e7852d2dd9))
* **mail(js):** update visible msgs list when adding new msgs ([0599922](https://github.com/inverse-inc/sogo/commit/0599922016dabeb5890277e12e36fcef6312250d))
* **mail(web):** don't try to fetch headers if mailbox is empty ([9cf67d0](https://github.com/inverse-inc/sogo/commit/9cf67d0b5ca90541628ab9a6c1244e08af890b85))
* **preferences(js):** don't save locale definition ([e140bd0](https://github.com/inverse-inc/sogo/commit/e140bd0379d050f5ba2fc5bce6fd2fe6cf12a37d))
* **saml:** add XSRF-TOKEN cookie in valid SAML login ([5f6cacc](https://github.com/inverse-inc/sogo/commit/5f6cacc8592750e6fcfdaef6b3dd23c5cd4f5ce4))
* **web(js):** get filename from content-disposition header ([7d07dda](https://github.com/inverse-inc/sogo/commit/7d07ddaffdef16c8ca6c7cbf63ce7a63a5b1e66d))

### Localization

* **bg:** add Bulgarian translation ([ebf2a80](https://github.com/inverse-inc/sogo/commit/ebf2a80654c12875e31be826ed32c1758d9d8c19), [eb18249](https://github.com/inverse-inc/sogo/commit/eb18249d2b66d69356c8d59b99fac2cc74c27d27))
* **de:** update German translation ([8bdae88](https://github.com/inverse-inc/sogo/commit/8bdae88ec3189df1d5e5859033df22cfa5fb6e00))
* **fr:** update French translation ([1246469](https://github.com/inverse-inc/sogo/commit/1246469ee14c942b59f51fedb178e86c810f2c5f))
* **pl:** update Polish translation ([6b6b733](https://github.com/inverse-inc/sogo/commit/6b6b7334c202ef93aff97ef9e3a4754c4e90821e))
* **sr_SR:** add Montenegrin translation ([3cc29b4](https://github.com/inverse-inc/sogo/commit/3cc29b40183b2e3a8aad19f0a427229e9c9ed6d5))
* **sr_SR:** use sr_ME instead of cnr for Montenegrin locale ([36100b0](https://github.com/inverse-inc/sogo/commit/36100b0419a6a1828bbf9267091701af50426f57))

### Enhancements

* **doc:** replace xsltproc/fop by asciidoctor-pdf ([1345022](https://github.com/inverse-inc/sogo/commit/134502223e9edb51690672f108b29777e3b66f2c))
* **mail:** replace "Google Authenticator" with more general vocabulary ([9ae9fa0](https://github.com/inverse-inc/sogo/commit/9ae9fa094ea903c2f79bf29fe8b7f27c0170f170)), closes [#5294](https://sogo.nu/bugs/view.php?id=5294)
* **mail(js):** delay instantiation of Message objects on load ([bc58bd1](https://github.com/inverse-inc/sogo/commit/bc58bd1cb095d5901737af4f8271b364413127d0))
* **mail(js):** improvements for md-virtual-repeat ([d285411](https://github.com/inverse-inc/sogo/commit/d285411ef30bb7897ef18394b2d9f1c0f2f7daee))
* **mail(js):** various optimizations ([a9c6f09](https://github.com/inverse-inc/sogo/commit/a9c6f09273e83bb7d270569b84784c739b5b8ae1))
* **web:** replace SOGoGoogleAuthenticatorEnabled with ([20b2fd5](https://github.com/inverse-inc/sogo/commit/20b2fd5e4573392e374f465d63cb34346f17f2f6)), closes [#5294](https://sogo.nu/bugs/view.php?id=5294)

### [5.1.1](https://github.com/inverse-inc/sogo/compare/SOGo-5.1.0...SOGo-5.1.1) (2021-06-01)

### Bug Fixes

* **addressbook:** import contact lists from LDIF file ([e1d8d70](https://github.com/inverse-inc/sogo/commit/e1d8d70e288beb229628bb05ae6f1d071d40b792)), closes [#3260](https://sogo.nu/bugs/view.php?id=3260)
* **calendar(css):** enlarge categories color stripes ([bd80b6e](https://github.com/inverse-inc/sogo/commit/bd80b6ea758e945564aa1a7fcf3ec473781581a2)), closes [#5301](https://sogo.nu/bugs/view.php?id=5301)
* **calendar(css):** enlarge categories color stripes ([e5d9571](https://github.com/inverse-inc/sogo/commit/e5d957181c2218fba21d70179dcb72059750b8eb)), closes [#5301](https://sogo.nu/bugs/view.php?id=5301)
* **calendar(js):** fix URL for snoozing alarms ([d4a0b25](https://github.com/inverse-inc/sogo/commit/d4a0b25c0659f1dfacca2ed4d1ee6349529dc9bd)), closes [#5324](https://sogo.nu/bugs/view.php?id=5324)
* **calendar(js):** show conflict error inside appointment editor ([fec299f](https://github.com/inverse-inc/sogo/commit/fec299f040da27faedc4521ea51c95c718f70ddf))
* **core:** avoid appending an empty domain to uid in cache ([debcbd1](https://github.com/inverse-inc/sogo/commit/debcbd16db64cdd2fd3047d3eec2fc24ca6cd788))
* **core:** change password in user's matching source only ([da36608](https://github.com/inverse-inc/sogo/commit/da366083e93382f96338fc75dbc9a03b23010464))
* **core:** decompose LDAP nested groups, cache logins ([a83b0d8](https://github.com/inverse-inc/sogo/commit/a83b0d822ab66f81ba5ac94efc923495de665e01))
* **core:** don't bind a DN to LDAP sources with a different search base ([e0b6e22](https://github.com/inverse-inc/sogo/commit/e0b6e22fa278d3d908b17acbe5f5c284d3563773))
* **css:** adjust colors of center lists of views ([045879a](https://github.com/inverse-inc/sogo/commit/045879a1faa9efe6a4686e18927403d7fb6db2a7)), closes [#5291](https://sogo.nu/bugs/view.php?id=5291)
* **mail:** handle folders that end with a question mark ([657f00f](https://github.com/inverse-inc/sogo/commit/657f00f92be8c1ffcad4b720fd129e7f5ea95fae)), closes [#5303](https://sogo.nu/bugs/view.php?id=5303)
* **mail:** retrieve IMAP delimiter after LIST command ([189aab3](https://github.com/inverse-inc/sogo/commit/189aab3535e78bff31a5b6a4d1d74c2b1e565b5f))
* **mail:** use default signature when forcing default identity ([dc81f70](https://github.com/inverse-inc/sogo/commit/dc81f70928afeddbce0f1dbebb7552e298ff99b2))
* **mail(css):** improve HTML sanitization of background attribute ([72321ec](https://github.com/inverse-inc/sogo/commit/72321ec545ed4e7062af9c1a545616a8c4e31b1a))
* **mail(html):** add missing ARIA labels ([66afbd2](https://github.com/inverse-inc/sogo/commit/66afbd2172ecdb47c981b5f2e68a4c3e338c449e))
* **mail(js):** add CKEditor plugin pastefromgdocs ([517b888](https://github.com/inverse-inc/sogo/commit/517b8887b437c979107eb65f7415f6dc5ad8bf66)), closes [#5316](https://sogo.nu/bugs/view.php?id=5316)
* **mail(js):** add debouncing on keyup events of sgAutogrow ([d303247](https://github.com/inverse-inc/sogo/commit/d303247481fb74e296876ccc0b2654042a3bf603))
* **mail(js):** add tooltip with email of attendees in invitation ([af61752](https://github.com/inverse-inc/sogo/commit/af61752933f5f9972eebf8e2ab5ddbc3f0f01a48))
* **mail(js):** avoid updating the DOM before closing editor ([bed91ce](https://github.com/inverse-inc/sogo/commit/bed91ce95a8d53022c008381e1069ba1e969361a))
* **mail(js):** don't delay the progress indicator when loading mailbox ([049c17f](https://github.com/inverse-inc/sogo/commit/049c17f15a8dd1ad571a12f93d426d126cc4d8e1)), closes [#5278](https://sogo.nu/bugs/view.php?id=5278)
* **mail(js):** unselect all messages when changing mailbox ([bfbf43b](https://github.com/inverse-inc/sogo/commit/bfbf43b1c81eee1432f856ade9f7c44c412a7ac7)), closes [#4970](https://sogo.nu/bugs/view.php?id=4970) [#5148](https://sogo.nu/bugs/view.php?id=5148)
* **saml:** don't ignore the signature of messages ([e536365](https://github.com/inverse-inc/sogo/commit/e53636564680ac0df11ec898304bc442908ba746))
* **saml:** fix profile initialization, improve error handling ([1d88d36](https://github.com/inverse-inc/sogo/commit/1d88d36ded4246cd8b1806096601ced870b2f423)), closes [#5153](https://sogo.nu/bugs/view.php?id=5153) [#5270](https://sogo.nu/bugs/view.php?id=5270)
* **web:** allow to change expired password from login page ([bdd8e35](https://github.com/inverse-inc/sogo/commit/bdd8e3500ada76703d95ff47077f7f8ba349e323))
* **web:** allow to change expired password from login page ([8e98af0](https://github.com/inverse-inc/sogo/commit/8e98af0e9f7df219e63cd362af3282b102c53fff))
* **web:** restore support of ppolicy OpenLDAP overlay ([0c1f9fd](https://github.com/inverse-inc/sogo/commit/0c1f9fdb02559e8650fd486583bbbe11517ef4c7))
* **web(js):** don't cache users results in ACL editor ([4501b5e](https://github.com/inverse-inc/sogo/commit/4501b5e35cfe00ccd185756a80ec3d6de868d4ad))

### Localization

* **fr:** update French translation ([7bebc71](https://github.com/inverse-inc/sogo/commit/7bebc71f677d1216b145b675b5d232e49ead8f5e))
* **sk:** update Slovak translation ([376c473](https://github.com/inverse-inc/sogo/commit/376c473a5a79e9eeb4d7c81f47ace9396e766558))

### Enhancements

* **core:** cache the schema of LDAP user sources ([d0056d3](https://github.com/inverse-inc/sogo/commit/d0056d3b272a29a35108ac26bfce5038794bbe66))

## [5.1.0](https://github.com/inverse-inc/sogo/compare/SOGo-5.0.1...SOGo-5.1.0) (2021-03-30)

### Features

* **calendar(js):** allow HTML links in location field ([0509d7f](https://github.com/inverse-inc/sogo/commit/0509d7f1624a47579b3936fb364e581f44c60b24))
* **calendar(web):** allow to change the classification of an event ([4a83733](https://github.com/inverse-inc/sogo/commit/4a8373303922bb2697d5aa91b89c34b77c3af6a2))
* **eas:** Allow EAS Search operation in all parts of a message ([fab8061](https://github.com/inverse-inc/sogo/commit/fab8061766786245bdf1abc093527455e6be7bc7))
* **mail:** new option to force default identity ([fc4f5d2](https://github.com/inverse-inc/sogo/commit/fc4f5d2161b2811671dfb34052f6d97f7d5125bd))

### Bug Fixes

* **acls:** remove debugging output when searching in groups ([3722169](https://github.com/inverse-inc/sogo/commit/372216952299c9af5953667a5a90050a51fb4b95))
* **addressbook(dav):** add support for macOS 11 (Big Sur) ([b9e19c2](https://github.com/inverse-inc/sogo/commit/b9e19c2cc4c0918bf59d8180fbe9a3cc56dc21a3)), closes [#5203](https://sogo.nu/bugs/view.php?id=5203)
* **calendar:** accept HTML in repeat frequencies descriptions ([c38524a](https://github.com/inverse-inc/sogo/commit/c38524ab079a32eeef1b22f4aeea4feed6969774))
* **calendar:** avoid exception when FoldersOrder have invalid entries ([c27be0f](https://github.com/inverse-inc/sogo/commit/c27be0fbe52fc4e7b91cfbc8c9695934f5b8b944))
* **calendar:** fix all-day events in lists ([5d1ac9d](https://github.com/inverse-inc/sogo/commit/5d1ac9db5d834f0f23431ea09301a0fdcdbc5d63))
* **calendar:** try to repair VCALENDAR when parsing versit string ([9fe2de7](https://github.com/inverse-inc/sogo/commit/9fe2de753b9865b0be5d9bd0367fbcc1e1f38958))
* **calendar(js):** add attendee from search field when saving ([74acab0](https://github.com/inverse-inc/sogo/commit/74acab073806f6e9cc483f35a799102778193a60)), closes [#5185](https://sogo.nu/bugs/view.php?id=5185)
* **calendar(js):** fix exception when changing an event calendar ([0e0fc72](https://github.com/inverse-inc/sogo/commit/0e0fc72b44c8c7825ec28897aeb6983e6fba942f))
* **calendar(js):** ignore attendees when saving task ([e78eb44](https://github.com/inverse-inc/sogo/commit/e78eb44dd77a2ac6b43e23e8dd72af839434b840))
* **common(js):** improve parsing of year ([6f90977](https://github.com/inverse-inc/sogo/commit/6f90977196f13f7edc10cfe4c681bf4e96170374)), closes [#5268](https://sogo.nu/bugs/view.php?id=5268)
* **core:** fix compilation warning in NSData+Crypto ([386429e](https://github.com/inverse-inc/sogo/commit/386429e46ea177d0f466e52989a2ca7e7dbf4049))
* **core:** release alarm folder's channel immediately after being used ([41bbbfa](https://github.com/inverse-inc/sogo/commit/41bbbfacd9a63d7de53273a05a4f119ebda302ba))
* **core:** remove overstruck diacritics from sanitized strings ([7da4bc4](https://github.com/inverse-inc/sogo/commit/7da4bc465f1a87a7543fc355aa251caf1324483b))
* **core:** use "is null" instead of "= null" when building SQL ([dd326f9](https://github.com/inverse-inc/sogo/commit/dd326f9ddf9d0351b41bd9cd1c2c62f5efc165b7))
* **css:** adjust colors of center lists of views ([f64b4e1](https://github.com/inverse-inc/sogo/commit/f64b4e1a855e4dc1aa7d9e2a67edaf1d6ac2671d))
* **eas:** handle fileAs element (fixes [#5239](https://sogo.nu/bugs/view.php?id=5239)) ([dd8ebd1](https://github.com/inverse-inc/sogo/commit/dd8ebd1922a8ef0cec822bad4a7a4adce7344dff))
* **eas:** handle SENT-BY in delegated calendars ([3796009](https://github.com/inverse-inc/sogo/commit/3796009eca93b2a5c8db706aa75bedc944d67bbe))
* **eas:** improve EAS parameters parsing (fixes [#5266](https://sogo.nu/bugs/view.php?id=5266)) ([b2008cd](https://github.com/inverse-inc/sogo/commit/b2008cd30940294671c246c3b13bc9dd239b9730))
* **login:** fix localizabled strings when changing language ([a3277eb](https://github.com/inverse-inc/sogo/commit/a3277eb65a530a2596074fb5f1bbfcfae9d4f28c))
* **mail:** unsubscribe from all subfolders when deleting parent ([cb6de75](https://github.com/inverse-inc/sogo/commit/cb6de7584551cf5b2253eb1a9c057cf9c84c1c17)), closes [#5218](https://sogo.nu/bugs/view.php?id=5218)
* **mail(css):** improve visibility of buttons in invitations ([088764a](https://github.com/inverse-inc/sogo/commit/088764a3f7f7f3c89a492845c29744166696acf5)), closes [#5263](https://sogo.nu/bugs/view.php?id=5263)
* **mail(css):** limit some text formatting to attachment cards ([9dcdaed](https://github.com/inverse-inc/sogo/commit/9dcdaedb402730e7d7488d363eb9ea395790c080))
* **mail(css):** limit some text formatting to attachment cards ([e774c4c](https://github.com/inverse-inc/sogo/commit/e774c4c47484e42db75cbf466d4c40d3f7205ead))
* **mail(css):** restore scrolling of msg source when animation is off ([86ab731](https://github.com/inverse-inc/sogo/commit/86ab7312a4e6e9ae9e35ec2a90a68da3ed824cad))
* **mail(js):** add collapse button to toolbar of HTML editor ([00030ba](https://github.com/inverse-inc/sogo/commit/00030ba2fa863084c081ed7af11daf8a1750121c))
* **mail(js):** don't modify filters for automatic refresh ([f9a8d84](https://github.com/inverse-inc/sogo/commit/f9a8d8491eccad217ee216db79ecfe573993fda5)), closes [#5226](https://sogo.nu/bugs/view.php?id=5226)
* **mail(js):** improve quoted message when replying ([fa3e5e0](https://github.com/inverse-inc/sogo/commit/fa3e5e0b75a3358875410f0249a75c9a3871f9d7)), closes [#5223](https://sogo.nu/bugs/view.php?id=5223)
* **preferences(css):** improve display of some select input fields ([12047d1](https://github.com/inverse-inc/sogo/commit/12047d112f452c92e71b27a5877f436d0201c48d))
* **preferences(js):** always apply forward constraints to sieve filters ([#294](https://sogo.nu/bugs/view.php?id=294)) ([59e876d](https://github.com/inverse-inc/sogo/commit/59e876d8f7de087702a3b2d2d86a0c314f2f6f8c))
* **preferences(mail):** make sure auto-reply (vacation) text is set ([1c4ff40](https://github.com/inverse-inc/sogo/commit/1c4ff40d330290711a3a6affa56715d30145064b))
* **print:** don't print toasts ([bc77536](https://github.com/inverse-inc/sogo/commit/bc77536b5d236b0f28067d60c3e58e0690a33da0)), closes [#5207](https://sogo.nu/bugs/view.php?id=5207)

### Localization

* **cs:** update Czech translation ([9bafb57](https://github.com/inverse-inc/sogo/commit/9bafb57a797364aeb51a2670d51f0a1ef5d6f545))
* **cs:** update Czech translation ([1827a45](https://github.com/inverse-inc/sogo/commit/1827a4548a715c752a236985778957085a95f7af))
* **de:** update German translation ([cbcf6cb](https://github.com/inverse-inc/sogo/commit/cbcf6cbfdf14cb937802ecf81e7dfa8d901fbe99))
* **de:** update German translation ([c7166de](https://github.com/inverse-inc/sogo/commit/c7166de428cb3aa61ea97ba026c884aaad4c88b1))
* **fr:** update French translation ([f5b925d](https://github.com/inverse-inc/sogo/commit/f5b925d90e68b8c66aef4d26a8ee73a8aa93fdd2))
* **hu:** update Hungarian translation ([1914a35](https://github.com/inverse-inc/sogo/commit/1914a3516adf45049c5474e4e406e4cc2d31623f))
* **hu:** update Hungarian translation ([3875edd](https://github.com/inverse-inc/sogo/commit/3875eddda339594d6ba15bca693f82f8187a564a))
* **mail:** fix status for message validity ([e6088c9](https://github.com/inverse-inc/sogo/commit/e6088c9026cdbc8ce8f23d476a88505a726cf0b3)), closes [#5204](https://sogo.nu/bugs/view.php?id=5204)
* **mail:** improve generic error message for signed/encrypted messages ([e2e5e6f](https://github.com/inverse-inc/sogo/commit/e2e5e6fed9b5d44c5d02374ab73449fab6de5e47)), closes [#5204](https://sogo.nu/bugs/view.php?id=5204)
* **pl:** update Polish translation ([3662332](https://github.com/inverse-inc/sogo/commit/366233222999df1d76b6dc1f1ebbf3408be36437))
* **pl:** update Polish translation ([2ecfa70](https://github.com/inverse-inc/sogo/commit/2ecfa70e7266e64f223932ed11b16f7c3d821250))
* **pt_BR:** update Brazilian Portuguese translation ([c6fab04](https://github.com/inverse-inc/sogo/commit/c6fab04df6e6160934cf7e4e08bfb3c8ed418faf))
* **ru:** update Russian translation ([d030d1c](https://github.com/inverse-inc/sogo/commit/d030d1c4b38b6155fe9d39e744f93300db0ecfc1))
* **sk:** update Slovak translation ([b486938](https://github.com/inverse-inc/sogo/commit/b486938e4005d5292b690583544e574a38d5c194))
* **sl_SI:** update Slovenian translation ([a95964b](https://github.com/inverse-inc/sogo/commit/a95964b51f01e1bdc79948452e4d73cad0150105))
* **sr:** update Serbian and Serbian Latin translations ([8915749](https://github.com/inverse-inc/sogo/commit/8915749f758db5ae3d922a211b87900e38b9bc60))
* **sr_SR:** add Serbian (Latin) translation ([8386bb2](https://github.com/inverse-inc/sogo/commit/8386bb2c083e5f6e679c3f0afff06de6d132bbc0))
* **sr_SR:** update Serbian (Latin) translation ([822c50f](https://github.com/inverse-inc/sogo/commit/822c50ff569bd5f5336137fc5efbe4f4c6dc507c))

### [5.0.1](https://github.com/inverse-inc/sogo/compare/SOGo-5.0.0...SOGo-5.0.1) (2020-10-07)

### Bug Fixes

* **calendar:** restore UIxOccurenceDialog ([1bec216](https://github.com/inverse-inc/sogo/commit/1bec216ce6f85dd2e1bad1d4051b8b9331380964), [9af697a](https://github.com/inverse-inc/sogo/commit/9af697ae835bcf1551566de25097e9801895e8c4)), closes [#5141](https://sogo.nu/bugs/view.php?id=5141) [#5160](https://sogo.nu/bugs/view.php?id=5160)
* **calendar(dav):** check if group member is empty ([9150bdd](https://github.com/inverse-inc/sogo/commit/9150bdd768bc1ba7ef118d66c922ea7b1dc0e57d))
* **core:** decompose LDAP nested groups ([6aca61d](https://github.com/inverse-inc/sogo/commit/6aca61d8aef4f34e45b480ce3bae19318bc0e685))
* **core:** fix GCC 10 compatibility ([8507204](https://github.com/inverse-inc/sogo/commit/8507204e0d320f9ff1069b36e6d9ca35de4232ab)), closes [#5029](https://sogo.nu/bugs/view.php?id=5029)
* **core:** handle bogus CardDAV clients ([78c9277](https://github.com/inverse-inc/sogo/commit/78c9277b99368f3d85f0e0290529e07054ea1631))
* **mail:** add missing elements to Czech reply template ([0fdeee8](https://github.com/inverse-inc/sogo/commit/0fdeee8490da5fc5ed91c695e540eee3b9b07057)), closes [#5179](https://sogo.nu/bugs/view.php?id=5179)
* **mail:** add SMTP error to Exception returned by SOGOMailer ([728a006](https://github.com/inverse-inc/sogo/commit/728a006e6ed7dd77156d44374e849d97833d620e))
* **mail:** fallback to the default identity when replying/forwarding ([64a8ce4](https://github.com/inverse-inc/sogo/commit/64a8ce404879e717dd2f5e8192f7be47f3ae7504))
* **mail:** remove duplicate recipients in draft ([ec1a01e](https://github.com/inverse-inc/sogo/commit/ec1a01e316795a593ffaf0bd17ae6c151cccf6f4))
* **mail(js):** handle subfolders of Sent mailbox ([af452eb](https://github.com/inverse-inc/sogo/commit/af452eb1a755e20709a77d20ac79cb24d99dce1b)), closes [#4980](https://sogo.nu/bugs/view.php?id=4980)
* **mail(js):** keep CKEditor toolbar visible ([7163900](https://github.com/inverse-inc/sogo/commit/7163900d2496c4bb4b19f64eeee5d001920ce069))
* **preferences(js):** sanitize content of toast ([712d0f4](https://github.com/inverse-inc/sogo/commit/712d0f4ef1ec2e16fdd0a72865fe885e212e508c)), closes [#5178](https://sogo.nu/bugs/view.php?id=5178)
* **preferences(js):** sanitize mail identities when saving ([aa70679](https://github.com/inverse-inc/sogo/commit/aa706796c2920b78caa30c884125dcd92d6c2876))
* **web(js):** avoid throwing an error when disconnected ([7b9e750](https://github.com/inverse-inc/sogo/commit/7b9e75080645678e9eafdfa896ef69010626676d))

### Localization

* **cs:** update Czech translation ([7af092f](https://github.com/inverse-inc/sogo/commit/7af092f849a1344a47ece569efd4e242e22265f2))
* **de:** update German translation ([0fe73ec](https://github.com/inverse-inc/sogo/commit/0fe73ec8a7d578efa91b04c2c533c10d49f27a2a))
* **hu:** update Hungarian translation ([a594bf8](https://github.com/inverse-inc/sogo/commit/a594bf84a32cf27e3efe6967d5c20129d97b6de0))

## [5.0.0](https://github.com/inverse-inc/sogo/compare/SOGo-4.3.2...SOGo-5.0.0) (2020-08-10)

### Features

* **core:** add BLF-CRYPT scheme ([8c612fc](https://github.com/inverse-inc/sogo/commit/8c612fc0a2a2e432a27bdb66ebb05134492f72f6)), closes [#4958](https://sogo.nu/bugs/view.php?id=4958)
* **core:** add blowfish implementation from openwall ([3040c27](https://github.com/inverse-inc/sogo/commit/3040c275d8a6b17d90249401e46a8f96b3b98f1e))
* **core:** add groups support to sogo-tool manage-acl ([9c49fae](https://github.com/inverse-inc/sogo/commit/9c49fae7f40614681a640690910e7fee29cde307))
* **core:** add lookupFields attribute in LDAP source ([2784009](https://github.com/inverse-inc/sogo/commit/27840093f5c9c6b2aecd6d5ce80f1af3b65c3b42)), closes [#568](https://sogo.nu/bugs/view.php?id=568)
* **core:** add PBKDF2 support ([2e0fc3c](https://github.com/inverse-inc/sogo/commit/2e0fc3ca09c28312f487b23382bc9f31aa118627))
* **core:** allow disabling tls validation for localhost ([#286](https://sogo.nu/bugs/view.php?id=286)) ([1f98882](https://github.com/inverse-inc/sogo/commit/1f9888254ad1e59d939a9e2d00ae5161b076e386))
* **core:** handle groups when setting ACLs (fixes [#4171](https://sogo.nu/bugs/view.php?id=4171)) ([05dc51e](https://github.com/inverse-inc/sogo/commit/05dc51ec30a0519a18c813e90d461dab4d9f6616))
* **core:** initial Google Authenticator support for 2FA ([f78300a](https://github.com/inverse-inc/sogo/commit/f78300a12ec50ff27e3636a56b801465bd0df982))
* **core:** support ARGON2I/ARGON2ID password hashes ([4c27826](https://github.com/inverse-inc/sogo/commit/4c27826fb57d4b30465e6fb51fddcbc466b6147c)), closes [#4895](https://sogo.nu/bugs/view.php?id=4895)
* **core:** support smtps and STARTTLS for SMTP ([589cfaa](https://github.com/inverse-inc/sogo/commit/589cfaa2f4957b7b528e80ddc7cf7befbd890e47)), closes [#31](https://sogo.nu/bugs/view.php?id=31)
* **core(js):** improve Google Authenticator on login page, add QR code ([cd37e98](https://github.com/inverse-inc/sogo/commit/cd37e989db6ca0c6d923373637377486d21b686b) [c1acce0](https://github.com/inverse-inc/sogo/commit/c1acce072546a654aac0f5991d77a6f1872589c5) [e8f0471](https://github.com/inverse-inc/sogo/commit/e8f0471bcfe8516fdb1afb1efcc34e9c4053e9ee)), closes [#5038](https://sogo.nu/bugs/view.php?id=5038) [#2722](https://sogo.nu/bugs/view.php?id=2722)
* **mail:** handle multiple mail identities ([f8aa338](https://github.com/inverse-inc/sogo/commit/f8aa338e643653b238018a5f655c46660229b82a), [b4f76a7](https://github.com/inverse-inc/sogo/commit/b4f76a7932acf601c3beed2334a326475ce386b8) [8940651](https://github.com/inverse-inc/sogo/commit/894065158683aabc4c8a83005e8f8f2beb4d5f15) [208ee08](https://github.com/inverse-inc/sogo/commit/208ee08960910e9f708e8bcfa0f8a22f508b47de) [7972257](https://github.com/inverse-inc/sogo/commit/7972257692b786664030bc48f1f4636e8b4c0ae2) [11bbdee](https://github.com/inverse-inc/sogo/commit/11bbdee143eca65c3df564cdf6adb55fd740c841) [d930821](https://github.com/inverse-inc/sogo/commit/d930821d6b0d9fbe02300b442c99147c10a25a6e) [a8bbaf0](https://github.com/inverse-inc/sogo/commit/a8bbaf01d7812cd9097584af4beb8b46d29ea14e)), closes [#768](https://sogo.nu/bugs/view.php?id=768) [#4602](https://sogo.nu/bugs/view.php?id=4602) [#5083](https://sogo.nu/bugs/view.php?id=5083) [#5062](https://sogo.nu/bugs/view.php?id=5062) [#5117](https://sogo.nu/bugs/view.php?id=5117) [#5087](https://sogo.nu/bugs/view.php?id=5087)
* **preferences:** button to reset contacts categories to defaults ([76cbe78](https://github.com/inverse-inc/sogo/commit/76cbe7854cf25d179e3d6df738f0c4b0c09838b9))
* **web:** support desktop notifications, add global inbox polling ([87cf5b4](https://github.com/inverse-inc/sogo/commit/87cf5b473f057731fa428580b4fbece0b34d3bd5) [8205acc](https://github.com/inverse-inc/sogo/commit/8205acc5d574498cda78789fb924e60a8e049468)), closes [#1234](https://sogo.nu/bugs/view.php?id=1234) [#3382](https://sogo.nu/bugs/view.php?id=3382) [#4295](https://sogo.nu/bugs/view.php?id=4295)

### Bug Fixes

* **acl(js):** toggle rights from the ACL editor ([825fb85](https://github.com/inverse-inc/sogo/commit/825fb8590308cbce928ef8fbafaf8027e3eb844c))
* **addressbook:** handle vCard with multiple title values ([3d25b8b](https://github.com/inverse-inc/sogo/commit/3d25b8b5717f5d00fc4a02ed3fd0f6a1dbe71fad) [96c22b6](https://github.com/inverse-inc/sogo/commit/96c22b6b96d04226583e02698b969dbd95b61bc6))
* **addressbook(js):** show copy option when source is remote ([72b5db4](https://github.com/inverse-inc/sogo/commit/72b5db4e35693de5fb414dcaeade33343be91100))
* **calendar:** ensure valid identity when sending invitations ([c2d9377](https://github.com/inverse-inc/sogo/commit/c2d937746ff85c5f82686ea295dc67cc4986460c))
* **calendar:** return SOGoUser instances when expanding LDAP groups ([b8595d7](https://github.com/inverse-inc/sogo/commit/b8595d7ae6d1c961f03eaea0e870aa0f117e7b9b)), closes [#5043](https://sogo.nu/bugs/view.php?id=5043)
* **calendar:** uncondtionally adjust all-day events dates ([5e1a592](https://github.com/inverse-inc/sogo/commit/5e1a59243c6743d82992f4c39813dc6cea07138c)), closes [#5045](https://sogo.nu/bugs/view.php?id=5045)
* **calendar(css):** decrease height of calendars entries in lists ([7eac9c3](https://github.com/inverse-inc/sogo/commit/7eac9c389343c09e1928360e1c6d628a8e19e06d))
* **calendar(js):** avoid exception when adding invalid email as attendee ([4ff0791](https://github.com/inverse-inc/sogo/commit/4ff0791fafe31628a05a53e62aaee0d469a81540))
* **calendar(js):** don't handle attendees for tasks ([ff3e83f](https://github.com/inverse-inc/sogo/commit/ff3e83fd43b1cf70124b0df7120b214d78dfbb8d))
* **calendar(js):** fix event blocks width in day view ([272fa8f](https://github.com/inverse-inc/sogo/commit/272fa8f8983fadc47436d0e09bfda340cac49fa0)), closes [#5017](https://sogo.nu/bugs/view.php?id=5017)
* **calendar(js):** improve attendees editor when adding new attendees ([3d3b17a](https://github.com/inverse-inc/sogo/commit/3d3b17adb8f53bd31a360bafc12f64b7b290ef9e)), closes [#5049](https://sogo.nu/bugs/view.php?id=5049)
* **calendar(js):** improve debugging in Component factory ([8933fae](https://github.com/inverse-inc/sogo/commit/8933fae461c7c2a65f626c965b7240ffe08c47ad))
* **calendar(js):** remove unused injected module in PrintController ([5087582](https://github.com/inverse-inc/sogo/commit/5087582b7591d2caa31864a5fb29963dd0bf1492))
* **calendar(js):** show categories colors in task editor ([743cca2](https://github.com/inverse-inc/sogo/commit/743cca255f60f32e9eca3beeb953f910556e0dcb)), closes [#5116](https://sogo.nu/bugs/view.php?id=5116)
* **calendar(js):** show freebusy timeline with external-only attendees ([a5ba99c](https://github.com/inverse-inc/sogo/commit/a5ba99cf608f0b7ab866695fca5565fbdf79ef8c))
* **calendar(js):** show real selected list in print preview ([7379776](https://github.com/inverse-inc/sogo/commit/73797761c350488ac6286ebd6a88f95ba3836d68))
* **common(js):** initialize search field with pre-selected option ([1432600](https://github.com/inverse-inc/sogo/commit/1432600fae5440c82456a3fcf33e12627496475c)), closes [#5044](https://sogo.nu/bugs/view.php?id=5044)
* **core:** added back instance caching for LDAP members ([b94175c](https://github.com/inverse-inc/sogo/commit/b94175cc0c8bf47c0e63655fa2a67a010c60088f))
* **core:** added even better debugging for bogus groups ([9f55cdc](https://github.com/inverse-inc/sogo/commit/9f55cdc725440f5932491f3c829610b6366c9ab2))
* **core:** adjust syntax for Python > 2 ([798ad15](https://github.com/inverse-inc/sogo/commit/798ad1502c0bc44d1ed9cf78153e596e30edfb78))
* **core:** allow non top-level special folders and improved the doc around this ([1146038](https://github.com/inverse-inc/sogo/commit/1146038c76daf1b0cadbce602d10223aa6611612))
* **core:** always set the charset when sending IMIP replies ([6ec002f](https://github.com/inverse-inc/sogo/commit/6ec002f023431d53c8759a95fff2a1139bdb3927))
* **core:** avoid caching group members per instance ([0ff0d43](https://github.com/inverse-inc/sogo/commit/0ff0d43e1e4b302ad0b0527b8043ad9e98f9332c))
* **core:** avoid fetching quick records for non-existant users ([2be7bab](https://github.com/inverse-inc/sogo/commit/2be7bab3ed09bff70843bd02fbb5fee2fcfce2da))
* **core:** avoid pooling channels with tools (fixes [#4684](https://sogo.nu/bugs/view.php?id=4684)) ([cecf157](https://github.com/inverse-inc/sogo/commit/cecf157dca4e0748d23b871c250484092c41598b))
* **core:** disable ASM version of blowfish on i386 ([e37ae5f](https://github.com/inverse-inc/sogo/commit/e37ae5fec5b8acb25cf25f3c0d8225cd3b6968c9))
* **core:** don't synchronize defaults if no mail identity is created ([e6e994b](https://github.com/inverse-inc/sogo/commit/e6e994ba80ce5172f4ab5db8113ab9d403e57997)), closes [#5070](https://sogo.nu/bugs/view.php?id=5070)
* **core:** fix compilation of pkcs5_pbkdf2.c ([d39208e](https://github.com/inverse-inc/sogo/commit/d39208efa0f9138dfd079e463720d3f26b94c2a0))
* **core:** fixed linked and packaging for zip->libzip work ([0e95de3](https://github.com/inverse-inc/sogo/commit/0e95de31cf95879985edda774e7e2c469fe30ed1))
* **core:** improve debbuging when dealing with groups ([5b6096e](https://github.com/inverse-inc/sogo/commit/5b6096e32ce2c31b7b1d5b849b1ad7e8209c08a2))
* **core:** improve debugging on invalid group sources ([105ca88](https://github.com/inverse-inc/sogo/commit/105ca88aef04c6d0d38e6517c0d225b4bd9987a8))
* **core:** improve error log when parsing PKCS12 certificate ([6e0e678](https://github.com/inverse-inc/sogo/commit/6e0e678627a782e2c16c427d5072e6f578e5a906))
* **core:** improved debugging on bogus groups ([42587f7](https://github.com/inverse-inc/sogo/commit/42587f7422a2f4c0d0004656253fa6a326075256))
* **core:** initial compat work on libzip ([3c4b1af](https://github.com/inverse-inc/sogo/commit/3c4b1af3ba6f84f656ea9c9da80547972e36faca))
* **core:** never use zip_error_init_with_code ([f6a4dfc](https://github.com/inverse-inc/sogo/commit/f6a4dfcd04315e942ed1355b79958b712e565365))
* **core:** no need to call zip_discard, it's handled in zip_close ([1389dcf](https://github.com/inverse-inc/sogo/commit/1389dcfe6bb2e820f7f85180a64968420df93a9a))
* **core:** NSData+String: Dont mix tabs and spaces ([562f81f](https://github.com/inverse-inc/sogo/commit/562f81f21f75d74bff2db5c3279debdb7a09931f))
* **core:** NSData+String: Simplify generateSalt function ([c3a4f4a](https://github.com/inverse-inc/sogo/commit/c3a4f4aeb4f69886342d0381c11b829173bc08a0))
* **core:** require current password on password change ([#285](https://sogo.nu/bugs/view.php?id=285)) ([2300fe8](https://github.com/inverse-inc/sogo/commit/2300fe8aabca5875282f1a059c776df12af652d0)), closes [#4140](https://sogo.nu/bugs/view.php?id=4140)
* **core:** second pass at libzip compat ([67f5e5e](https://github.com/inverse-inc/sogo/commit/67f5e5e4908b978c7eaf385c0b9cbda1f69d777c))
* **eas:** avoid doing bogus truncation ([9698628](https://github.com/inverse-inc/sogo/commit/96986280ee76a1a25529c8c4db3f22321b4f7904))
* **eas:** gcc v10 compat fixes (fixes [#5029](https://sogo.nu/bugs/view.php?id=5029)) ([e469f52](https://github.com/inverse-inc/sogo/commit/e469f52dd1e47e651cbe94115458db0c8332d3b5))
* **eas:** handle noselect special folders in Dovecot ([39255b1](https://github.com/inverse-inc/sogo/commit/39255b193d077f152e559e39b32899e187d36b73))
* **mail:** add all unknown recipients to an address book ([d29c2b2](https://github.com/inverse-inc/sogo/commit/d29c2b2c7b8c27d261a5b7ee3026b035c17a342d))
* **mail:** change default search scope to "subject or from" ([#287](https://sogo.nu/bugs/view.php?id=287)) ([8642ff9](https://github.com/inverse-inc/sogo/commit/8642ff9d00d7152588c44980d7c0fbde7f9a3c1f))
* **mail:** pick proper "from" address when replying/forwarding ([c99170b](https://github.com/inverse-inc/sogo/commit/c99170b9bc7f8b89cafb17f0643a2ff39c6835f2)), closes [#5056](https://sogo.nu/bugs/view.php?id=5056)
* **mail:** use double-quotes for attributes when re-encoding HTML ([b7f0ee7](https://github.com/inverse-inc/sogo/commit/b7f0ee7228192e04990a99ec59bc4078a7fa500e))
* **mail:** use unique names for attachments ([9c391b8](https://github.com/inverse-inc/sogo/commit/9c391b8d8df97c766033f74857b5fa34076746fa)), closes [#5086](https://sogo.nu/bugs/view.php?id=5086)
* **mail(css):** add explicit expanded/collapsed mailbox status ([2545caf](https://github.com/inverse-inc/sogo/commit/2545caf2e540e80d3437060a1412b88a5506d457))
* **mail(css):** respect white spaces in plaintext messages ([f6ce265](https://github.com/inverse-inc/sogo/commit/f6ce265e7b5509612efde183a5c048ca2eeedc09)), closes [#5069](https://sogo.nu/bugs/view.php?id=5069)
* **mail(css):** yellow flags for more visibility ([94efa4d](https://github.com/inverse-inc/sogo/commit/94efa4d7d46cb1e535bfacb3f514a96de59237f8))
* **mail(js):** encode HTML entities when computing height of textarea ([964e6f0](https://github.com/inverse-inc/sogo/commit/964e6f0cb1143ac3e757c3fb5470962119ea4da6)), closes [#5020](https://sogo.nu/bugs/view.php?id=5020)
* **mail(js):** fix message(s) deletion when overquota ([35ebb7a](https://github.com/inverse-inc/sogo/commit/35ebb7aaeb2cab73cdb061ef8ade1ca4b4bc7f06))
* **mail(js):** pick proper "from" address when replying/forwarding ([f7e7612](https://github.com/inverse-inc/sogo/commit/f7e7612e05dc9fbcfba0b201138e4bec93e4061c) [8f3738b](https://github.com/inverse-inc/sogo/commit/8f3738bfef7bbbd19583c2ef7b215c0940c26633)), closes [#5072](https://sogo.nu/bugs/view.php?id=5072)
* **mail(js):** respect signature placement when switching identity ([0899352](https://github.com/inverse-inc/sogo/commit/089935297c8c3911e684824b1925353e92a61cf6))
* **mail(js):** use initial number of rows of textarea with sgAutogrow ([200c353](https://github.com/inverse-inc/sogo/commit/200c3536450a2ab87f339767cad900656d47129a))
* **packaging:** control files adjustments for old distro wrt libzip ([3b46281](https://github.com/inverse-inc/sogo/commit/3b46281ddef21f34fac65bdcc8941a0178faa8be))
* **packaging:** don't enable mfa on squeeze ([e9cc088](https://github.com/inverse-inc/sogo/commit/e9cc0881530e126c3a3cb0516455b3cb78e67a82))
* **packaging:** enable mfa on focal ([a102a94](https://github.com/inverse-inc/sogo/commit/a102a94ac507ec0ef6df5522692b6e2693d74e5c))
* **packaging:** fixed condition syntax ([d797987](https://github.com/inverse-inc/sogo/commit/d7979871bc02f59157667f780166441165c52819))
* **packaging:** fixed typo ([b4b9e62](https://github.com/inverse-inc/sogo/commit/b4b9e62d0910074612e4e5479fc3c568871b3253))
* **packaging:** fixes for centos/rhel v8 support ([7ef507b](https://github.com/inverse-inc/sogo/commit/7ef507bdb49bce51f34578d4d7846fa811dbdb19))
* **packaging:** more control file fixes ([5366522](https://github.com/inverse-inc/sogo/commit/53665222b5d0bef0411129c2366ba6f19fd373cb))
* **packaging:** Ubuntu Focal changes ([7a66818](https://github.com/inverse-inc/sogo/commit/7a6681826c153e9b9b7f88be0b6c2e4636830dae) [bf4c083](https://github.com/inverse-inc/sogo/commit/bf4c083de833b8df1ac23ac76959e5a334ef489c))
* **packaging:** Xenial control files fixes ([1a7fa0b](https://github.com/inverse-inc/sogo/commit/1a7fa0b164465b92ead85738f480785015470c4f))
* **preferences:** accept an "id" key for mail accounts ([528b758](https://github.com/inverse-inc/sogo/commit/528b7581a393da5503a82cec7115508dd52b2a26)), closes [#5091](https://sogo.nu/bugs/view.php?id=5091)
* **preferences:** improve handling of forward addresses ([7494bb3](https://github.com/inverse-inc/sogo/commit/7494bb3ae6e60ea96e81c8bc1a73472ce83e168d)), closes [#5053](https://sogo.nu/bugs/view.php?id=5053)
* **preferences(html):** add placeholders to forward addresses field ([1712a7e](https://github.com/inverse-inc/sogo/commit/1712a7e7e5f706a70c34cd01856fd0431e3b47b7)), closes [#5053](https://sogo.nu/bugs/view.php?id=5053)
* **preferences(html):** improve placeholders ([2730a91](https://github.com/inverse-inc/sogo/commit/2730a91b54d5cac924eaacfef2ecbec6798ffd67))
* **preferences(js):** automatically expand newly created mail account ([f1ff8bf](https://github.com/inverse-inc/sogo/commit/f1ff8bfe1cdf2014fd52f50e1ae2b11343bf40ab))
* **preferences(js):** conditionally sanitize forward addresses ([b78e66a](https://github.com/inverse-inc/sogo/commit/b78e66a10b470cf1db99378f8de6e5d6ff1e73c3)), closes [#5085](https://sogo.nu/bugs/view.php?id=5085)
* **preferences(js):** handle cancellation of IMAP account edition ([ee904ac](https://github.com/inverse-inc/sogo/commit/ee904ac6167447f77acb7baaf44aab68065a8017))
* **preferences(js):** honor SOGoForwardConstraints in Sieve filters ([5bb8161](https://github.com/inverse-inc/sogo/commit/5bb81614941afd8e9022d2f3e333b52f43d316fa) [85a6d8e](https://github.com/inverse-inc/sogo/commit/85a6d8e477027135001be7b65dab14854fc9660c))
* **preferences(js):** initialize Forward defaults ([f60a30c](https://github.com/inverse-inc/sogo/commit/f60a30c520d52c665d47e33c69459a8fdfa7c4b3))
* **preferences(js):** set account id before importing certificate ([566fe55](https://github.com/inverse-inc/sogo/commit/566fe55d714124a1e1581c27ff4d5f33e1c65ca4)), closes [#5084](https://sogo.nu/bugs/view.php?id=5084)
* **preferences(js):** show error when passwords don't match ([0e7ce31](https://github.com/inverse-inc/sogo/commit/0e7ce3129c675c0759c5613862f617a6e7fee0d0))
* **test:** fix for failing test in NSString+Utilities ([fc863bf](https://github.com/inverse-inc/sogo/commit/fc863bf63f33322767556c6c3789810a160a8f14))
* **web:** add icon to expandable list items ([0e5e88a](https://github.com/inverse-inc/sogo/commit/0e5e88aaf946cf9a1ca8f4ed86ebe75ced9a4d46))
* **web:** consistency in icon of expandable list items ([1c99c2c](https://github.com/inverse-inc/sogo/commit/1c99c2ca42d07ae126091620bfca45acbfea5c64))
* **web:** restore menu separators in sidenav of Calendars & Mailer ([6e2d652](https://github.com/inverse-inc/sogo/commit/6e2d652e387c533de53f351b7290e9421cc68ff5))
* **web(css):** improve mailbox expand button in sidenav ([37d3cb7](https://github.com/inverse-inc/sogo/commit/37d3cb7782f0e7b1ca5e5debef15494379da97cc))
* **web(js):** handle SAML assertion expiration ([6af5541](https://github.com/inverse-inc/sogo/commit/6af55414fb66176307c32b2dc126ab6448285636) [8692e64](https://github.com/inverse-inc/sogo/commit/8692e647bdbace44539e2ec0c9662c9eeaba176a) [433da56](https://github.com/inverse-inc/sogo/commit/433da56b23369775fe184d7fca043d3197afe178) [3ef94da](https://github.com/inverse-inc/sogo/commit/3ef94da9d6a74fa4a1db620f7a404ad59fbb6d5d))
* **web(js):** remove calls to deprecated functions in ng-material ([1cb9a83](https://github.com/inverse-inc/sogo/commit/1cb9a83f6ffd0f179dc0dee3a99cd047df8ff71a) [cd95649](https://github.com/inverse-inc/sogo/commit/cd95649f0887a38a2bc66890d2899f9b16e7c68f))

### Localization

* **ca:** update Catalan translation ([497594d](https://github.com/inverse-inc/sogo/commit/497594dfc826491560e6d5cbcb3e87ed20d6674a))
* **de:** update German translation ([d26bc18](https://github.com/inverse-inc/sogo/commit/d26bc181fdefe831e3f5ba7d887d27eaa23a6a2d))
* **pl:** update Polish translation ([b5f9861](https://github.com/inverse-inc/sogo/commit/b5f9861e16c3c3b811bcc4e74774d11c453470a0))
* **preferences:** rename "Current Time Zone" to "Time Zone" ([443a41b](https://github.com/inverse-inc/sogo/commit/443a41b77086bd858c6a849d732fe7963407749a))

### Enhancements

* **mail(js):** replace ckEditor directive by sgCkeditor component ([07c06db](https://github.com/inverse-inc/sogo/commit/07c06db69dcc7371dff07835adad89903a6a10ae))
* **preferences:** replace comma-separated list of addresses by md-chips ([7e21c6c](https://github.com/inverse-inc/sogo/commit/7e21c6c6a7c83117d0fbe42388418e86f85efc12) [4292a45](https://github.com/inverse-inc/sogo/commit/4292a45e62bf414e35e19784d618a7aa363b4d24) [8b1b938](https://github.com/inverse-inc/sogo/commit/8b1b93889928cf9ab74940f16a6d8e850a955321)), closes [#5048](https://sogo.nu/bugs/view.php?id=5048)

### [4.3.2](https://github.com/inverse-inc/sogo/compare/SOGo-4.3.1...SOGo-4.3.2) (2020-05-06)

### Bug Fixes

* **core:** LDAP group expansion must use all user sources ([7b5c787](https://github.com/inverse-inc/sogo/commit/7b5c7877182030e113bc6734f3ce9d3b09e7fec5), [8f7b2bf](https://github.com/inverse-inc/sogo/commit/8f7b2bfbed3978751011a86e764e65ee45ac2cf4))
* **core:** skip folder check during ACL subscribe ([7929fd3](https://github.com/inverse-inc/sogo/commit/7929fd394fa7da003a079872a0128b848c514876), [8a4e799](https://github.com/inverse-inc/sogo/commit/8a4e79963f4ec973f893eb6fe9d38700488dcc45))
* **web(js):** improve encoding of folder paths in XHR calls ([e7da4c1](https://github.com/inverse-inc/sogo/commit/e7da4c19b82fa9f9587f97d6ba2d4a411cc778db)), closes [#4989](https://sogo.nu/bugs/view.php?id=4989)

### [4.3.1](https://github.com/inverse-inc/sogo/compare/SOGo-4.3.0...SOGo-4.3.1) (2020-05-01)

### Bug Fixes

* **calendar:** fallback to tz found in ics ([57bbb25](https://github.com/inverse-inc/sogo/commit/57bbb255cc0f349a83d6bd83c030761120eaf174))
* **calendar:** fix first range of "busy off hours" in vFreeBusy response ([5e1f487](https://github.com/inverse-inc/sogo/commit/5e1f487e4945be3b62765d583e47861d8b6e8734))
* **calendar:** handle tz with until in rrule (fixes [#4943](https://sogo.nu/bugs/view.php?id=4943)) ([24fc9a9](https://github.com/inverse-inc/sogo/commit/24fc9a950b799ae6f8dfd4728d3503131b7b688d))
* **calendar:** use the calendar owner when generating freebusy information ([6af0058](https://github.com/inverse-inc/sogo/commit/6af0058657cb8e5ba96c4023bb673be5b6179c27))
* **calendar(core):** avoid generating empty parameters list ([62e25f6](https://github.com/inverse-inc/sogo/commit/62e25f6c13320837bdf792a8f01a67ba5e58061f))
* **calendar(core):** check for array size before looking into ([7829249](https://github.com/inverse-inc/sogo/commit/78292495bb3cdbdcab7922a3ff68df22ff58e176))
* **calendar(js):** find a free slot for a maximum of 30 days ([058df21](https://github.com/inverse-inc/sogo/commit/058df21ada3396b19db3df5f695f0b909289f0c6))
* **core:** escape quotes before sending SQL queries ([09c76b3](https://github.com/inverse-inc/sogo/commit/09c76b3649d7e58a809f4c1358f8794a446397d0), [d99bbbb](https://github.com/inverse-inc/sogo/commit/d99bbbb37ea94603831926cfbb0d9e9a25327123), [04a6217](https://github.com/inverse-inc/sogo/commit/04a6217512833b2fa04358220e5d520832b24a35)), closes [#5010](https://sogo.nu/bugs/view.php?id=5010)
* **css:** improve contrast of toolbars w/input field ([eabb40a](https://github.com/inverse-inc/sogo/commit/eabb40a0bf06a17a8f91d9b9535f500777c4bcb3))
* **eas:** fix invalid DisplayTo (fixes [#4988](https://sogo.nu/bugs/view.php?id=4988)) ([b8f3106](https://github.com/inverse-inc/sogo/commit/b8f31069ed6ad257daa666f7698a1054196c836e))
* **eas:** properly encode DisplayTo (fixes [#4995](https://sogo.nu/bugs/view.php?id=4995)) ([18ffd1a](https://github.com/inverse-inc/sogo/commit/18ffd1a7440ff69fc907d3e6a59afc61d92d14f7))
* **mail:** remove onpointerrawupdate event handler from HTML messages ([d1dbceb](https://github.com/inverse-inc/sogo/commit/d1dbceb407b37aff6563d06194189965af39cf3e)), closes [#4979](https://sogo.nu/bugs/view.php?id=4979)
* **mail:** validate IMAP ACL compliance on main mail account ([da51482](https://github.com/inverse-inc/sogo/commit/da51482ce1cd4cc15b5de3c2b203b60fa6c6ddde))
* **mail:** wrap HTML part before re-encoding content ([bc963d5](https://github.com/inverse-inc/sogo/commit/bc963d53c69ead5e06cfb3cf52f75b64582178af))
* **mail(css):** minor improvements to the mail editor ([807cefa](https://github.com/inverse-inc/sogo/commit/807cefaa39d591a0506913d4831cb99a9ff91732))
* **mail(js):** disable autogrow of textarea in popup window ([daaad93](https://github.com/inverse-inc/sogo/commit/daaad938cbfc73426f260ca95ebb9ea7e663c3cb)), closes [#4962](https://sogo.nu/bugs/view.php?id=4962)
* **mail(js):** limit number of messages to batch delete per API call ([4e2d509](https://github.com/inverse-inc/sogo/commit/4e2d5098c750eb78acee226283ecd4cc748f8ca9))
* **mail(js):** restore unseen count after deleting a mailbox ([158c5e4](https://github.com/inverse-inc/sogo/commit/158c5e45c45ad06bebf4e0841563204ecd2c4330))
* **mail(js):** skrink autogrow md-input when content is removed ([95b3e9d](https://github.com/inverse-inc/sogo/commit/95b3e9d4fa42fcd65625fefc16cb5d7b2a2a010a))
* **mail(js):** url-encode folder path to handle special characters (%) ([52bb3ba](https://github.com/inverse-inc/sogo/commit/52bb3baa8b3f5653ed6e40e1f370d341a34d7d98)), closes [#4989](https://sogo.nu/bugs/view.php?id=4989)
* **mail(js):** wrong argument to Mailbox.$_deleteMessages ([2c050d8](https://github.com/inverse-inc/sogo/commit/2c050d847e84ec35e3d27bb222b376d6e9846835)), closes [#4986](https://sogo.nu/bugs/view.php?id=4986)
* **preferences:** avoid exception when parsing PreventInvitationsWhitelist ([824b383](https://github.com/inverse-inc/sogo/commit/824b38332c4cd23bf343e8510214f0b56212721c)), closes [#5006](https://sogo.nu/bugs/view.php?id=5006)
* **preferences(html):** reject action of mail filter is now a textarea ([656410e](https://github.com/inverse-inc/sogo/commit/656410eb6b4fd54f19134ad65844dc62835ef40c))
* **web(css):** space issue with folders subscription dialog on Firefox ([860d635](https://github.com/inverse-inc/sogo/commit/860d635c9c8d0ce0862c70142304fe2c88a68f3d)), closes [#4954](https://sogo.nu/bugs/view.php?id=4954)
* **web(css):** truncate text of toolbar in multi-selection mode ([174b44e](https://github.com/inverse-inc/sogo/commit/174b44ed50415dbf2fbadc17ee19b70f08380091)), closes [#4623](https://sogo.nu/bugs/view.php?id=4623)
* **web(js):** handle SAML assertion expiration ([6446176](https://github.com/inverse-inc/sogo/commit/64461764c83ad02a8778f44d6bab64c1d965cf60), [fd063fd](https://github.com/inverse-inc/sogo/commit/fd063fd5b370c347ca5b164e8a92f2c0b4060637))

### Localization

* **ca:** update Catalan translation ([0e5e9dd](https://github.com/inverse-inc/sogo/commit/0e5e9ddb749a0ab566f0a5224ea998549e9a1030))
* **cs:** update Czech translation ([e3559d5](https://github.com/inverse-inc/sogo/commit/e3559d5ca3ddb53c1d6b514e27ecb8153dbbb50a))
* **de:** update German translation ([a41fb9e](https://github.com/inverse-inc/sogo/commit/a41fb9e1a9c2e604b14a3aaedd576f9e9da3f32d))
* **fr:** update French translation ([f75af12](https://github.com/inverse-inc/sogo/commit/f75af12db89f38c1042d6ebac792dc3b88532d22))
* **hu:** update Hungarian translation ([543abb3](https://github.com/inverse-inc/sogo/commit/543abb39d5b5a5423667f46610d457fff2efb467))
* **lv:** update Latvian translation ([e8e41f1](https://github.com/inverse-inc/sogo/commit/e8e41f15e3f2cb6d2531661f5d0b176be1a8d44e))
* **nl:** update Dutch translation ([91d193f](https://github.com/inverse-inc/sogo/commit/91d193fa0f3f2a11aae5468ba5ea9e40f552abb8))
* **pl:** update Polish translation ([7b4e4f7](https://github.com/inverse-inc/sogo/commit/7b4e4f7345c6fe0e5fe41e368cb412aaecfb977e))
* **pt_BR:** update Brazilian (Portuguese) translation ([c61fe4a](https://github.com/inverse-inc/sogo/commit/c61fe4a188f0407112cd346a483bb34a745492ab))
* **ro_RO:** update Romanian translation ([de5da7b](https://github.com/inverse-inc/sogo/commit/de5da7bd0d3264c0397703b94f07747d3b062b3e))
* **sk:** update Slovak translation ([84f3fd5](https://github.com/inverse-inc/sogo/commit/84f3fd5e1c670c196051e23b1308ed90ece4d5e7))

### Enhancements

* **web:** don't wait on Sieve server to render UIxPageFrame.wox ([3e6cd3c](https://github.com/inverse-inc/sogo/commit/3e6cd3c53cb9708f90bd3600ad948f631688a3b6))

## [4.3.0](https://github.com/inverse-inc/sogo/compare/SOGo-4.2.0...SOGo-4.3.0) (2020-01-21)

### Features

* **core:** Added AES-128-CBC password scheme for SQL authentication. ([f0980a9](https://github.com/inverse-inc/sogo/commit/f0980a9cbd14e0fab163be71e4e260bde67d7ee9))

### Bug Fixes

* **calendar:** adjust recurrent rule when importing a vEvent ([560c1dc](https://github.com/inverse-inc/sogo/commit/560c1dcd82359c7fe8ccbb985d122e532c594df9))
* **calendar:** fix monthly computation with month day mask ([aaaa16e](https://github.com/inverse-inc/sogo/commit/aaaa16ed403f77510b6c51c8a7dee8f40a91b7c9)), closes [#4915](https://sogo.nu/bugs/view.php?id=4915)
* **calendar:** restore [SOGoAppointmentObject resourceHasAutoAccepted] ([91ca8b8](https://github.com/inverse-inc/sogo/commit/91ca8b8bece8f5e30b7b89e2931f6e2a678ae090)), closes [#4923](https://sogo.nu/bugs/view.php?id=4923)
* **calendar(css):** fix padding of sort handle of calendars ([43e5662](https://github.com/inverse-inc/sogo/commit/43e56629501e8d8cdbdc1f223a2a3a6aedc0ef4e))
* **calendar(js):** allow event invitations to be moved ([001d76f](https://github.com/inverse-inc/sogo/commit/001d76fd05fbd950084a64ca111c5b983518d1d8)), closes [#4926](https://sogo.nu/bugs/view.php?id=4926)
* **eas:** additional name fields (fixes [#4929](https://sogo.nu/bugs/view.php?id=4929)) ([3f94516](https://github.com/inverse-inc/sogo/commit/3f94516e316985b040cabd12dd581fa39101fd0f))
* **eas:** avoid generating broken XML ouput (fixes [#4927](https://sogo.nu/bugs/view.php?id=4927)) ([047a98b](https://github.com/inverse-inc/sogo/commit/047a98b870e162578554a9d46e62946be15a6699))
* **eas:** make sure there is always an attendee name (fixes [#4910](https://sogo.nu/bugs/view.php?id=4910)) ([4ed2c72](https://github.com/inverse-inc/sogo/commit/4ed2c727a22bb8df3b74c34028de25658532997e))
* **eas:** sync reminder for invitation (fixes [#4911](https://sogo.nu/bugs/view.php?id=4911)) ([9221811](https://github.com/inverse-inc/sogo/commit/9221811fdc21a4dca6624f5e5714d3454a679342))
* **mail:** fix SMTP authentication when reporting spam/ham ([62f6431](https://github.com/inverse-inc/sogo/commit/62f64314c049c1b2b17ca7bc4f90bb50c2a734a2)), closes [#4941](https://sogo.nu/bugs/view.php?id=4941)
* **mail(js):** bypass autogrow feature of md-input to fix scroll jumping ([73dc86a](https://github.com/inverse-inc/sogo/commit/73dc86a6ed4a5febe640667bd8cc1f6ff4de7110))
* **tool:** fix error handling when updating Sieve script ([d6d33f9](https://github.com/inverse-inc/sogo/commit/d6d33f9f0bcf99a058955a3dfff6354ebd9c0c08))

### Localization

* **pt_BR:** update Brazilian (Portuguese) translation ([88a6755](https://github.com/inverse-inc/sogo/commit/88a675596ca6b4a635fb1cfa08216b0539f27433))

### Enhancements

* **css:** remove unused selectors for layout ([94b1716](https://github.com/inverse-inc/sogo/commit/94b171675f735d50e898b24c94e774aede1abe3f))

## [4.2.0](https://github.com/inverse-inc/sogo/compare/SOGo-4.1.1...SOGo-4.2.0) (2019-12-17)

### Features

* **core:** allow pre/appended Sieve scripts ([4475ac6](https://github.com/inverse-inc/sogo/commit/4475ac651d1d94513729d6133a70d0e70ea52b87))
* **core:** Allow the detection of external Sieve scripts ([ac91a30](https://github.com/inverse-inc/sogo/commit/ac91a303c9e688790410180e4b50afe5a0a86414))
* **mail(js):** new button to expand recipients that are LDAP groups ([46ade76](https://github.com/inverse-inc/sogo/commit/46ade7640ad45c44a36fb085357019ce3ac9b0be)), closes [#4902](https://sogo.nu/bugs/view.php?id=4902)
* **mail(js):** new button to expand recipients that are LDAP groups ([456a66b](https://github.com/inverse-inc/sogo/commit/456a66b66b85ae669009453a411f648eb1ed3e67))
* **preferences:** allow hiding of vacation the vacation period ([c2e7f6a](https://github.com/inverse-inc/sogo/commit/c2e7f6a8660b7185c4b21246e41009563aec03ea))

### Bug Fixes

* **addressbook(core):** safety check from broken URLs ([0ceccdd](https://github.com/inverse-inc/sogo/commit/0ceccdd61208a6c4501ad4c5dc6e0c57581f3a59))
* **calendar:** adjust invalid dates when importing a vEvent ([3bb40e4](https://github.com/inverse-inc/sogo/commit/3bb40e4024aae5392e0f0951b583ce315f781c8a)), closes [#4845](https://sogo.nu/bugs/view.php?id=4845)
* **calendar:** adjust invalid dates when importing a vEvent ([15d7c69](https://github.com/inverse-inc/sogo/commit/15d7c69d94b77add6c2e234ac14047db0771e2eb)), closes [#4845](https://sogo.nu/bugs/view.php?id=4845)
* **calendar:** allow fetching group members from contacts-only sources ([edc01e9](https://github.com/inverse-inc/sogo/commit/edc01e95329cc0d8a61ca9217cde20ba0744a74a))
* **calendar:** raise warning when MuiltipleBookings is set to -1 ([5923639](https://github.com/inverse-inc/sogo/commit/592363915453bbd79dca995b7a06fd9a994ff484))
* **calendar(html):** don't cache list of week days ([9aeecea](https://github.com/inverse-inc/sogo/commit/9aeecead6c40b0121e1f62c9db7256c9196ada26)), closes [#4907](https://sogo.nu/bugs/view.php?id=4907)
* **calendar(js):** avoid call to /members when expansion is disabled ([14b60cd](https://github.com/inverse-inc/sogo/commit/14b60cd75639fc3d23cf59f50d19d060c0a96c0e))
* **calendar(js):** avoid exception when adding duplicated attendee ([2048fb1](https://github.com/inverse-inc/sogo/commit/2048fb19cff4e5037d6bf0be44320721691ea05c))
* **calendar(js):** don't escape HTML characters in repeat select menu ([699849c](https://github.com/inverse-inc/sogo/commit/699849caecbd7e741dc5479445cdfaa4cbd83e94)), closes [#4875](https://sogo.nu/bugs/view.php?id=4875)
* **calendar(js):** fix refresh of attendees freebusy information ([fbdabc9](https://github.com/inverse-inc/sogo/commit/fbdabc9615faea5903afd3080ace6556ea3272a0)), closes [#4899](https://sogo.nu/bugs/view.php?id=4899)
* **core:** don't disable the current script if we aren't doing anything ([2bc24ec](https://github.com/inverse-inc/sogo/commit/2bc24eca829a6481a951c006a5bd7ec5740c2e8c))
* **mail:** wrap HTML part with HTML tags to render all content ([47075b4](https://github.com/inverse-inc/sogo/commit/47075b40a2435b24ef00847c3901fe9d31ef9db9))
* **mail(html:** expose UIxMailViewRecipientMenu in popup view ([5ccc126](https://github.com/inverse-inc/sogo/commit/5ccc12639be1cc5a88982e12223864adf52a1eb9))
* **mail(js):** add missing library to save msg from popup window ([7298022](https://github.com/inverse-inc/sogo/commit/729802222f673a319e5613701b17576539b8af28)), closes [#4879](https://sogo.nu/bugs/view.php?id=4879)
* **mail(js):** avoid exception when adding duplicated recipient ([a303011](https://github.com/inverse-inc/sogo/commit/a3030112374fef8c2e0712199dfe9894491fea69))
* **preferences:** improve error handling with Sieve server ([7180b59](https://github.com/inverse-inc/sogo/commit/7180b5988de35eee11aaa19ffc819399a86657b4))
* **preferences(js):** Lower constraints on auto-reply dates range ([70984de](https://github.com/inverse-inc/sogo/commit/70984def1fe69472ac69675adc3fac45b64a5869)), closes [#4874](https://sogo.nu/bugs/view.php?id=4874)
* **web:** improve contrast of toolbars w/input field ([e71afc9](https://github.com/inverse-inc/sogo/commit/e71afc982e93941fc749839d4b2ea4ede9ecbc5e))

### Localization

* **ca:** update Catalan translation ([e458a78](https://github.com/inverse-inc/sogo/commit/e458a78a10ffbdb01bf6422d1ce969d90e1327c8)), closes [#4878](https://sogo.nu/bugs/view.php?id=4878)
* **cs:** update Czech translation ([cd8f957](https://github.com/inverse-inc/sogo/commit/cd8f95777433e3759fe4c1bb6cf3966db00abcc1))
* **de:** remove duplicated short date formats ([f872dc5](https://github.com/inverse-inc/sogo/commit/f872dc52c690bbe5b755238f18dd15697d844c14))
* **fr:** update French translation ([bc172c5](https://github.com/inverse-inc/sogo/commit/bc172c5895934b1f2fe2bf8cedbf1fdc80918f26))
* **nl:** update Dutch translation ([ae42fd8](https://github.com/inverse-inc/sogo/commit/ae42fd869a507c8020fb5f0e59d8adf720d39562))
* **sk:** update Slovak translation ([e65e0f1](https://github.com/inverse-inc/sogo/commit/e65e0f191f55f5fea101ad8c198bad9c89ef9ca5))

### Enhancements

* **preferences:** conditionally activate the Sieve script ([5b3d84e](https://github.com/inverse-inc/sogo/commit/5b3d84ee2441c717f1cb7ce8f40a1196f3bad0cb))
* replace calls to create GMT NSTimeZone instance ([2e46e89](https://github.com/inverse-inc/sogo/commit/2e46e89d58d75f15d931b3664b12b674bfae6453))

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
