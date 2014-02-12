%{!?sogo_major_version: %global sogo_major_version %(/bin/echo %{sogo_version} | /bin/cut -f 1 -d .)}
%if %{sogo_major_version} >= 2
%global oc_build_depends samba4 openchange
%endif

%{!?python_sys_pyver: %global python_sys_pyver %(/usr/bin/python -c "import sys; print sys.hexversion")}

%define sogo_user sogo

Summary:      SOGo
Name:         sogo
Version:      %{sogo_version}
Release:      %{dist_suffix}%{?dist}
Vendor:       http://www.inverse.ca/
Packager:     Wolfgang Sourdeau <support@inverse.ca>
License:      GPL
URL:          http://www.inverse.ca/contributions/sogo.html
Group:        Productivity/Groupware
Source:       SOGo-%{sogo_version}.tar.gz
Prefix:       /usr
AutoReqProv:  off
Requires:     gnustep-base >= 1.23, sope%{sope_major_version}%{sope_minor_version}-core, httpd, sope%{sope_major_version}%{sope_minor_version}-core, sope%{sope_major_version}%{sope_minor_version}-appserver, sope%{sope_major_version}%{sope_minor_version}-ldap, sope%{sope_major_version}%{sope_minor_version}-cards >= %{sogo_version}, sope%{sope_major_version}%{sope_minor_version}-gdl1-contentstore >= %{sogo_version}, sope%{sope_major_version}%{sope_minor_version}-sbjson, libmemcached, memcached, tmpwatch
BuildRoot:    %{_tmppath}/%{name}-%{version}-%{release}
BuildRequires:  gcc-objc gnustep-base gnustep-make sope%{sope_major_version}%{sope_minor_version}-appserver-devel sope%{sope_major_version}%{sope_minor_version}-core-devel sope%{sope_major_version}%{sope_minor_version}-ldap-devel sope%{sope_major_version}%{sope_minor_version}-mime-devel sope%{sope_major_version}%{sope_minor_version}-xml-devel sope%{sope_major_version}%{sope_minor_version}-gdl1-devel sope%{sope_major_version}%{sope_minor_version}-sbjson-devel libmemcached-devel sed %{?oc_build_depends}


# Required by MS Exchange freebusy lookups
%{?el5:Requires: curl}
%{?el5:BuildRequires: curl-devel}
%{?el6:Requires: libcurl}
%{?el6:BuildRequires: libcurl-devel}

# saml is enabled everywhere except on el5 since its glib2 is prehistoric
%define saml2_cfg_opts "--enable-saml2"
%{?el5:%define saml2_cfg_opts ""}
%{?!el5:Requires: lasso}
%{?!el5:BuildRequires: lasso-devel}

%description
SOGo is a groupware server built around OpenGroupware.org (OGo) and
the SOPE application server.  It focuses on scalability.

The Inverse edition of this project has many feature enhancements:
- CalDAV and GroupDAV compliance
- full handling of vCard as well as vCalendar/iCalendar formats
- support for folder sharing and ACLs

The Web interface has been rewritten in an AJAX fashion to provided a faster
UI for the users, consistency in look and feel with the Mozilla applications,
and to reduce the load of the transactions on the server.

%package -n sogo-tool
Summary:      Command-line toolsuite for SOGo
Group:        Productivity/Groupware
Requires:     sogo = %{sogo_version}
AutoReqProv:  off

%description -n sogo-tool
Administrative tool for SOGo that provides the following internal commands:
  backup          -- backup user folders
  restore         -- restore user folders
  remove-doubles  -- remove duplicate contacts from the user addressbooks
  check-doubles   -- list user addressbooks with duplicate contacts

%package -n sogo-slapd-sockd
Summary:      SOGo backend for slapd and back-sock
Group:        Productivity/Groupware
AutoReqProv:  off

%description -n sogo-slapd-sockd
SOGo backend for slapd and back-sock, enabling access to private addressbooks
via LDAP.

%package -n sogo-ealarms-notify
Summary:      SOGo utility for executing email alarms
Group:        Productivity/Groupware
AutoReqProv:  off

%description -n sogo-ealarms-notify
SOGo utility executed each minute via a cronjob for executing email alarms.

%package -n sogo-activesync
Summary:      SOGo module to handle ActiveSync requests
Group:        Productivity/Groupware
Requires:     libwbxml, sogo = %{sogo_version}
BuildRequires: libwbxml-devel
AutoReqProv:  off

%description -n sogo-activesync
SOGo module to handle ActiveSync requests

%package -n sogo-devel
Summary:      Development headers and libraries for SOGo
Group:        Development/Libraries/Objective C
AutoReqProv:  off

%description -n sogo-devel
Development headers and libraries for SOGo. Needed to create modules.

%package -n sope%{sope_major_version}%{sope_minor_version}-gdl1-contentstore
Summary:      Storage backend for folder abstraction.
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-gdl1
AutoReqProv:  off

%description -n sope%{sope_major_version}%{sope_minor_version}-gdl1-contentstore
The storage backend implements the "low level" folder abstraction, which is
basically an arbitary "BLOB" containing some document.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package -n sope%{sope_major_version}%{sope_minor_version}-gdl1-contentstore-devel
Summary:      Development files for the GNUstep database libraries
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-gdl1
AutoReqProv:  off

%description -n sope%{sope_major_version}%{sope_minor_version}-gdl1-contentstore-devel
This package contains the header files for SOPE's GDLContentStore library.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package -n sope%{sope_major_version}%{sope_minor_version}-cards
Summary:      SOPE versit parsing library for iCal and VCard formats
Group:        Development/Libraries/Objective C
AutoReqProv:  off

%description -n sope%{sope_major_version}%{sope_minor_version}-cards
SOPE versit parsing library for iCal and VCard formats

%package -n sope%{sope_major_version}%{sope_minor_version}-cards-devel
Summary:      SOPE versit parsing library for iCal and VCard formats
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-cards
AutoReqProv:  off

%description -n sope%{sope_major_version}%{sope_minor_version}-cards-devel
SOPE versit parsing library for iCal and VCard formats

%if %{sogo_major_version} >= 2
%package openchange-backend
Summary:      SOGo backend for OpenChange
Group:        Productivity/Groupware
AutoReqProv:  off

%description openchange-backend
SOGo backend for OpenChange
%endif

########################################
%prep
rm -fr ${RPM_BUILD_ROOT}
%setup -q -n SOGo-%{sogo_version}


# small tweak to the python script for RHEL5
# if hex(sys.hexversion) < 0x02060000
%if %{python_sys_pyver} < 33947648
  sed -i 's!/usr/bin/env python!/usr/bin/env python2.6!' Scripts/openchange_user_cleanup
%endif


# ****************************** build ********************************
%build
. /usr/share/GNUstep/Makefiles/GNUstep.sh
./configure %saml2_cfg_opts

case %{_target_platform} in
ppc64-*) 
  cc="gcc -m64";
  ldflags="-m64";; 
*)
  cc="gcc";
  ldflags="";; 
esac

make CC="$cc" LDFLAGS="$ldflags" messages=yes

# OpenChange
%if %{sogo_major_version} >= 2
(cd OpenChange; \
 LD_LIBRARY_PATH=../SOPE/NGCards/obj:../SOPE/GDLContentStore/obj \
 make GNUSTEP_INSTALLATION_DOMAIN=SYSTEM )
%endif

# ****************************** install ******************************
%install

case %{_target_platform} in
ppc64-*)
  cc="gcc -m64";
  ldflags="-m64";;
*)
  cc="gcc";
  ldflags="";;
esac

make DESTDIR=${RPM_BUILD_ROOT} \
     GNUSTEP_INSTALLATION_DOMAIN=SYSTEM \
     CC="$cc" LDFLAGS="$ldflags" \
     install
install -d  ${RPM_BUILD_ROOT}/etc/init.d
install -d  ${RPM_BUILD_ROOT}/etc/cron.d
install -d ${RPM_BUILD_ROOT}/etc/cron.daily
install -d ${RPM_BUILD_ROOT}/etc/logrotate.d
install -d ${RPM_BUILD_ROOT}/etc/sysconfig
install -d ${RPM_BUILD_ROOT}/etc/httpd/conf.d
install -d ${RPM_BUILD_ROOT}/usr/sbin
install -d ${RPM_BUILD_ROOT}/var/lib/sogo
install -d ${RPM_BUILD_ROOT}/var/log/sogo
install -d ${RPM_BUILD_ROOT}/var/run/sogo
install -d ${RPM_BUILD_ROOT}/var/spool/sogo
install -d -m 750 -o %sogo_user -g %sogo_user ${RPM_BUILD_ROOT}/etc/sogo
install -m 640 -o %sogo_user -g %sogo_user Scripts/sogo.conf ${RPM_BUILD_ROOT}/etc/sogo/
install -m 755 Scripts/openchange_user_cleanup ${RPM_BUILD_ROOT}/%{_sbindir}
cat Apache/SOGo.conf | sed -e "s@/lib/@/%{_lib}/@g" > ${RPM_BUILD_ROOT}/etc/httpd/conf.d/SOGo.conf
install -m 600 Scripts/sogo.cron ${RPM_BUILD_ROOT}/etc/cron.d/sogo
cp Scripts/tmpwatch ${RPM_BUILD_ROOT}/etc/cron.daily/sogo-tmpwatch
chmod 755 ${RPM_BUILD_ROOT}/etc/cron.daily/sogo-tmpwatch
cp Scripts/logrotate ${RPM_BUILD_ROOT}/etc/logrotate.d/sogo
cp Scripts/sogo-init.d-redhat ${RPM_BUILD_ROOT}/etc/init.d/sogod
chmod 755 ${RPM_BUILD_ROOT}/etc/init.d/sogod
cp Scripts/sogo-default ${RPM_BUILD_ROOT}/etc/sysconfig/sogo
rm -rf ${RPM_BUILD_ROOT}%{_bindir}/test_quick_extract

# OpenChange
%if %{sogo_major_version} >= 2
(cd OpenChange; \
 LD_LIBRARY_PATH=${RPM_BUILD_ROOT}%{_libdir} \
 make DESTDIR=${RPM_BUILD_ROOT} \
     GNUSTEP_INSTALLATION_DOMAIN=SYSTEM \
      CC="$cc" LDFLAGS="$ldflags" \
   install)
%endif

# ActiveSync
(cd ActiveSync; \
 LD_LIBRARY_PATH=${RPM_BUILD_ROOT}%{_libdir} \
 make DESTDIR=${RPM_BUILD_ROOT} \
     GNUSTEP_INSTALLATION_DOMAIN=SYSTEM \
      CC="$cc" LDFLAGS="$ldflags" \
   install)

# ****************************** clean ********************************
%clean
rm -fr ${RPM_BUILD_ROOT}

# ****************************** files ********************************
%files -n sogo
%defattr(-,root,root,-)

/etc/init.d/sogod
/etc/cron.daily/sogo-tmpwatch
%dir %attr(0700, %sogo_user, %sogo_user) %{_var}/lib/sogo
%dir %attr(0700, %sogo_user, %sogo_user) %{_var}/log/sogo
%dir %attr(0755, %sogo_user, %sogo_user) %{_var}/run/sogo
%dir %attr(0700, %sogo_user, %sogo_user) %{_var}/spool/sogo
%dir %attr(0750, root, %sogo_user) %{_sysconfdir}/sogo
%{_sbindir}/sogod
%{_sbindir}/openchange_user_cleanup
%{_libdir}/libSOGo.so.*
%{_libdir}/libSOGoUI.so.*
%{_libdir}/libOGoContentStore.so*
%{_libdir}/GNUstep/SOGo/AdministrationUI.SOGo
%{_libdir}/GNUstep/SOGo/Appointments.SOGo
%{_libdir}/GNUstep/SOGo/CommonUI.SOGo
%{_libdir}/GNUstep/SOGo/Contacts.SOGo
%{_libdir}/GNUstep/SOGo/ContactsUI.SOGo
%{_libdir}/GNUstep/SOGo/MailPartViewers.SOGo
%{_libdir}/GNUstep/SOGo/Mailer.SOGo
%{_libdir}/GNUstep/SOGo/MailerUI.SOGo
%{_libdir}/GNUstep/SOGo/MainUI.SOGo
%{_libdir}/GNUstep/SOGo/PreferencesUI.SOGo
%{_libdir}/GNUstep/SOGo/SchedulerUI.SOGo

%{_libdir}/GNUstep/Frameworks/SOGo.framework/Resources
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Versions/%{sogo_major_version}/libSOGo.so.*
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Versions/%{sogo_major_version}/Resources
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Versions/Current
%{_libdir}/GNUstep/SOGo/Templates
%{_libdir}/GNUstep/SOGo/WebServerResources
%{_libdir}/GNUstep/OCSTypeModels
%{_libdir}/GNUstep/WOxElemBuilders-*

%config(noreplace) %attr(0640, root, %sogo_user) %{_sysconfdir}/sogo/sogo.conf
%config(noreplace) %{_sysconfdir}/logrotate.d/sogo
%config(noreplace) %{_sysconfdir}/cron.d/sogo
%config(noreplace) %{_sysconfdir}/httpd/conf.d/SOGo.conf
%config(noreplace) %{_sysconfdir}/sysconfig/sogo
%doc ChangeLog NEWS Scripts/*sh Scripts/updates.php Apache/SOGo-apple-ab.conf

%files -n sogo-tool
%{_sbindir}/sogo-tool

%files -n sogo-ealarms-notify
%{_sbindir}/sogo-ealarms-notify

%files -n sogo-slapd-sockd
%{_sbindir}/sogo-slapd-sockd

%files -n sogo-activesync
%{_libdir}/GNUstep/SOGo/ActiveSync.SOGo
%doc ActiveSync/LICENSE ActiveSync/README

%files -n sogo-devel
%{_includedir}/SOGo
%{_includedir}/SOGoUI
%{_libdir}/libSOGo.so
%{_libdir}/libSOGoUI.so
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Headers
%{_libdir}/GNUstep/Frameworks/SOGo.framework/libSOGo.so
%{_libdir}/GNUstep/Frameworks/SOGo.framework/SOGo
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Versions/%{sogo_major_version}/Headers
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Versions/%{sogo_major_version}/libSOGo.so
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Versions/%{sogo_major_version}/SOGo

%files -n sope%{sope_major_version}%{sope_minor_version}-gdl1-contentstore
%defattr(-,root,root,-)
%{_libdir}/libGDLContentStore*.so.*

%files -n sope%{sope_major_version}%{sope_minor_version}-gdl1-contentstore-devel
%{_includedir}/GDLContentStore
%{_libdir}/libGDLContentStore*.so

%files -n sope%{sope_major_version}%{sope_minor_version}-cards
%{_libdir}/libNGCards.so.*
%{_libdir}/GNUstep/SaxDrivers-*
%{_libdir}/GNUstep/SaxMappings
%{_libdir}/GNUstep/Libraries/Resources/NGCards

%files -n sope%{sope_major_version}%{sope_minor_version}-cards-devel
%{_includedir}/NGCards
%{_libdir}/libNGCards.so

%if %{sogo_major_version} >= 2
%files openchange-backend
%defattr(-,root,root,-)
%{_libdir}/GNUstep/SOGo/*.MAPIStore
%{_libdir}/mapistore_backends/*
%endif

# **************************** pkgscripts *****************************
%pre
if ! id %sogo_user >& /dev/null; then
  /usr/sbin/useradd -d %{_var}/lib/sogo -c "SOGo daemon" -s /sbin/nologin -M -r %sogo_user
fi

%post
# update timestamp on imgs,css,js to let apache know the files changed
find %{_libdir}/GNUstep/SOGo/WebServerResources  -exec touch {} \;
/sbin/chkconfig --add sogod
/etc/init.d/sogod condrestart  >&/dev/null

%preun
if [ "$1" == "0" ]
then
  /sbin/chkconfig --del sogod
  /sbin/service sogod stop > /dev/null 2>&1
fi

%postun
if test "$1" = "0"
then
  /usr/sbin/userdel %sogo_user
  /usr/sbin/groupdel %sogo_user > /dev/null 2>&1
  /bin/rm -rf %{_var}/run/sogo
  /bin/rm -rf %{_var}/spool/sogo
  # not removing /var/lib/sogo to keep .GNUstepDefaults
fi

# ********************************* changelog *************************
%changelog
* Wed Jan 15 2014 Jean Raby <jraby@inverse.ca>
- New package: sogo-activesync
- explicitly list all *.SOGo modules in sogo package
- added dependency on sogo = %version for sogo-tool

* Thu Apr 17 2013 Jean Raby <jraby@inverse.ca>
- Install openchange_user_cleanup in sbindir instead of doc

* Wed Apr 10 2013 Jean Raby <jraby@inverse.ca>
- use %sogo_user instead of 'sogo'
- install a sample sogo.conf in /etc/sogo

* Tue Jan 22 2013 Jean Raby <jraby@inverse.ca>
- Create the sogo user as a system user
- Use %attr() to set directory permissions instead of chown/chmod

* Mon Nov 12 2012 Jean Raby <jraby@inverse.ca>
- Add missing dependency on lasso and lasso-devel

* Mon Nov 05 2012 Jean Raby <jraby@inverse.ca>
- Disable saml2 on rhel5 - glib2 too old

* Fri Nov 02 2012 Jean Raby <jraby@inverse.ca>
- Enable saml2

* Tue Aug 28 2012 Jean Raby <jraby@inverse.ca>
- Add openchange_cleanup.py and tweak it to work on RHEL5

* Tue Jul 31 2012 Jean Raby <jraby@inverse.ca>
- treat logrotate file as a config file

* Fri May 24 2012 Jean Raby <jraby@inverse.ca>
- %post: restart sogo if it was running before rpm install

* Fri Mar 16 2012 Jean Raby <jraby@inverse.ca>
- %post: update timestamp on imgs,css,js to let apache know the files changed

* Fri Feb 16 2012 Jean Raby <jraby@inverse.ca>
- Use globbing to include all sql upgrade scripts instead of listing them all

* Tue Jan 10 2012 Jean Raby <jraby@inverse.ca>
- /etc/cron.d/sogo

* Thu Oct 27 2011 Wolfgang Sourdeau <wsourdeau@inverse.ca>
- make build of sogo-openchange-backend conditional to sogo_version >= 2

* Fri Oct 14 2011 Wolfgang Sourdeau <wsourdeau@inverse.ca>
- adapted to gnustep-make 2.6
- added sogo-openchange-backend

* Tue Sep 28 2010 Wolfgang Sourdeau <wsourdeau@inverse.ca>
- removed "README" from documentation

* Fri Aug 20 2010 Wolfgang Sourdeau <wsourdeau@inverse.ca>
- added sogo-ealarms-notify package

* Tue Apr 06 2010 Wolfgang Sourdeau <wsourdeau@inverse.ca>
- added sogo-slapd-sockd package

* Thu Jul 31 2008 Wolfgang Sourdeau <wsourdeau@inverse.ca>
- added dependencies on sopeXY-appserver, -core, -gdl1-contentstore and -ldap

* Wed May 21 2008 Wolfgang Sourdeau <wsourdeau@inverse.ca>
- removed installation of template and resource files, since it is now done by the upstream package

* Tue Oct 4 2007 Francis Lachapelle <flachapelle@inverse.ca>
- added package sope-gdl1-contentstore

* Wed Jul 18 2007 Wolfgang Sourdeau <wsourdeau@inverse.ca>
- initial build
