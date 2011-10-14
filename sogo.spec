Summary:      SOGo
Name:         sogo
Version:      %{sogo_version}
Release:      %{dist_suffix}%{?dist}
Vendor:       http://www.inverse.ca/
Packager:     Wolfgang Sourdeau <wsourdeau@inverse.ca>
License:      GPL
URL:          http://www.inverse.ca/contributions/sogo.html
Group:        Productivity/Groupware
Source:       SOGo-%{sogo_version}.tar.gz
Prefix:       /usr
AutoReqProv:  off
Requires:     gnustep-base, sope%{sope_major_version}%{sope_minor_version}-core, httpd, sope%{sope_major_version}%{sope_minor_version}-core, sope%{sope_major_version}%{sope_minor_version}-appserver, sope%{sope_major_version}%{sope_minor_version}-ldap, sope%{sope_major_version}%{sope_minor_version}-cards >= %{sogo_version}, sope%{sope_major_version}%{sope_minor_version}-gdl1-contentstore >= %{sogo_version}, sope%{sope_major_version}%{sope_minor_version}-sbjson, memcached, libmemcached
BuildRoot:    %{_tmppath}/%{name}-%{version}-%{release}
BuildPreReq:  gcc-objc gnustep-base gnustep-make sope%{sope_major_version}%{sope_minor_version}-appserver-devel sope%{sope_major_version}%{sope_minor_version}-core-devel sope%{sope_major_version}%{sope_minor_version}-ldap-devel sope%{sope_major_version}%{sope_minor_version}-mime-devel sope%{sope_major_version}%{sope_minor_version}-xml-devel sope%{sope_major_version}%{sope_minor_version}-gdl1-devel sope%{sope_major_version}%{sope_minor_version}-sbjson-devel libmemcached-devel samba openchange

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

%package openchange-backend
Summary:      SOGo backend for OpenChange
Group:        Productivity/Groupware
AutoReqProv:  off

%description openchange-backend
SOGo backend for OpenChange

########################################
%prep
rm -fr ${RPM_BUILD_ROOT}
%setup -q -n SOGo-%{sogo_version}

# ****************************** build ********************************
%build
. /usr/share/GNUstep/Makefiles/GNUstep.sh
./configure

case %{_target_platform} in
ppc64-*) 
  cc="gcc -m64";
  ldflags="-m64";; 
*)
  cc="gcc";
  ldflags="";; 
esac

make CC="$cc" LDFLAGS="$ldflags" messages=yes

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
mkdir -p ${RPM_BUILD_ROOT}/etc/init.d
mkdir -p ${RPM_BUILD_ROOT}/etc/cron.daily
mkdir -p ${RPM_BUILD_ROOT}/etc/logrotate.d
mkdir -p ${RPM_BUILD_ROOT}/etc/sysconfig
mkdir -p ${RPM_BUILD_ROOT}/etc/httpd/conf.d
mkdir -p ${RPM_BUILD_ROOT}/usr/sbin
mkdir -p ${RPM_BUILD_ROOT}/var/run/sogo
mkdir -p ${RPM_BUILD_ROOT}/var/log/sogo
mkdir -p ${RPM_BUILD_ROOT}/var/spool/sogo
cp Apache/SOGo.conf ${RPM_BUILD_ROOT}/etc/httpd/conf.d/
cp Scripts/tmpwatch ${RPM_BUILD_ROOT}/etc/cron.daily/sogo-tmpwatch
chmod 755 ${RPM_BUILD_ROOT}/etc/cron.daily/sogo-tmpwatch
cp Scripts/logrotate ${RPM_BUILD_ROOT}/etc/logrotate.d/sogo
cp Scripts/sogo-init.d-redhat ${RPM_BUILD_ROOT}/etc/init.d/sogod
chmod 755 ${RPM_BUILD_ROOT}/etc/init.d/sogod
cp Scripts/sogod-wrapper ${RPM_BUILD_ROOT}/usr/sbin/sogod-wrapper
chmod 755 ${RPM_BUILD_ROOT}/usr/sbin/sogod-wrapper
cp Scripts/sogo-default ${RPM_BUILD_ROOT}/etc/sysconfig/sogo
rm -rf ${RPM_BUILD_ROOT}%{_bindir}/test_quick_extract

# OpenChange
(cd OpenChange; \
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
/etc/logrotate.d/sogo
/usr/sbin/sogod-wrapper
/var/run/sogo
/var/log/sogo
/var/spool/sogo
%{_sbindir}/sogod
%{_libdir}/libSOGo.so.*
%{_libdir}/libSOGoUI.so.*
%{_libdir}/libOGoContentStore.so*
%{_libdir}/GNUstep/SOGo/*.SOGo

%{_libdir}/GNUstep/Frameworks/SOGo.framework/Resources
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Versions/2/libSOGo.so.*
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Versions/2/Resources
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Versions/Current
%{_libdir}/GNUstep/SOGo/Templates
%{_libdir}/GNUstep/SOGo/WebServerResources
%{_libdir}/GNUstep/OCSTypeModels
%{_libdir}/GNUstep/WOxElemBuilders-*

%config(noreplace) %{_sysconfdir}/httpd/conf.d/SOGo.conf
%config(noreplace) %{_sysconfdir}/sysconfig/sogo
%doc ChangeLog NEWS Scripts/sql-update-20070724.sh Scripts/sql-update-20070822.sh Scripts/sql-update-20080303.sh Scripts/sql-update-101_to_102.sh Scripts/sql-update-1.2.2_to_1.3.0.sh Scripts/sql-update-1.2.2_to_1.3.0-mysql.sh Scripts/sql-update-1.3.3_to_1.3.4.sh Scripts/sql-update-1.3.3_to_1.3.4-mysql.sh

%files -n sogo-tool
%{_sbindir}/sogo-tool

%files -n sogo-ealarms-notify
%{_sbindir}/sogo-ealarms-notify

%files -n sogo-slapd-sockd
%{_sbindir}/sogo-slapd-sockd

%files -n sogo-devel
%{_includedir}/SOGo
%{_includedir}/SOGoUI
%{_libdir}/libSOGo.so
%{_libdir}/libSOGoUI.so
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Headers
%{_libdir}/GNUstep/Frameworks/SOGo.framework/libSOGo.so
%{_libdir}/GNUstep/Frameworks/SOGo.framework/SOGo
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Versions/2/Headers
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Versions/2/libSOGo.so
%{_libdir}/GNUstep/Frameworks/SOGo.framework/Versions/2/SOGo

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

%files openchange-backend
%defattr(-,root,root,-)
%{_libdir}/GNUstep/SOGo/*.MAPIStore
%{_libdir}/mapistore_backends/*

# **************************** pkgscripts *****************************
%post
if ! id sogo >& /dev/null; then /usr/sbin/adduser sogo > /dev/null 2>&1; fi
/bin/chown sogo /var/run/sogo
/bin/chown sogo /var/log/sogo
/bin/chown sogo /var/spool/sogo
/bin/chmod 700 /var/spool/sogo
/sbin/chkconfig --add sogod

%preun
if [ "$1" == "0" ]
then
  /sbin/chkconfig --del sogod
  /sbin/service sogod stop > /dev/null 2>&1
fi

%postun
if test "$1" = "0"
then
  /usr/sbin/userdel sogo
  /usr/sbin/groupdel sogo > /dev/null 2>&1
  /bin/rm -rf /var/run/sogo
  /bin/rm -rf /var/spool/sogo
fi

# ********************************* changelog *************************
%changelog
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
