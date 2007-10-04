%define lfmaj 1
%define lfmin 1

Summary:      Scalable OpenGroupware.org (Inverse edition)
Name:         sogo
Version:      %{sogo_version}.%{sogo_release}
Release:      gnustep.%{dist_suffix}
Vendor:       http://www.inverse.ca/
Packager:     Wolfgang Sourdeau <wsourdeau@inverse.ca>
License:      GPL
URL:          http://www.inverse.ca/contributions/sogo.html
Group:        Productivity/Groupware
Source:       %{sogo_source}
Prefix:       %{sogo_prefix}
AutoReqProv:  off
Requires:     gnustep-base sope%{sope_major_version}%{sope_minor_version}-core httpd mod_ngobjweb sope%{sope_major_version}%{sope_minor_version}-cards
BuildRoot:    %{_tmppath}/%{name}-%{version}-%{release}
BuildPreReq:  gcc-objc gnustep-base gnustep-make sope%{sope_major_version}%{sope_minor_version}-appserver-devel sope%{sope_major_version}%{sope_minor_version}-core-devel sope%{sope_major_version}%{sope_minor_version}-ldap-devel sope%{sope_major_version}%{sope_minor_version}-mime-devel sope%{sope_major_version}%{sope_minor_version}-xml-devel sope%{sope_major_version}%{sope_minor_version}-gdl1-devel sope%{sope_major_version}%{sope_minor_version}-cards-devel

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


%package -n sope%{sope_major_version}%{sope_minor_version}-gdl1-tools
Summary:      Tools (gcs_cat/gcs_gensql/gcs_ls/gcs_mkdir/gcs_recreatequick)
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-gdl1
AutoReqProv:  off

%description -n sope%{sope_major_version}%{sope_minor_version}-gdl1-tools
Various tools around the GDLContentStore.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

########################################
%prep
rm -fr ${RPM_BUILD_ROOT}
%setup -q -n sogo

# ****************************** build ********************************
%build
. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
./configure \
            --enable-strip \
            --disable-debug \
	    --with-gnustep

make

# ****************************** install ******************************
%install
make INSTALL_ROOT_DIR=${RPM_BUILD_ROOT} \
     GNUSTEP_INSTALLATION_DIR=${RPM_BUILD_ROOT}%{prefix} \
     install
cp -a UI/WebServerResources UI/Templates ${RPM_BUILD_ROOT}%{prefix}/Library/SOGo-%{sogo_version}
mkdir -p ${RPM_BUILD_ROOT}/etc/init.d
mkdir -p ${RPM_BUILD_ROOT}/etc/httpd/conf.d
mkdir -p ${RPM_BUILD_ROOT}/usr/sbin
mkdir -p ${RPM_BUILD_ROOT}/var/run/sogo
mkdir -p ${RPM_BUILD_ROOT}/var/log/sogo
cp Apache/SOGo.conf ${RPM_BUILD_ROOT}/etc/httpd/conf.d/
cp Scripts/sogo-init.d-rhel4 ${RPM_BUILD_ROOT}/etc/init.d/sogod
cp Scripts/sogod-redhat ${RPM_BUILD_ROOT}/usr/sbin/sogod
rm -rf ${RPM_BUILD_ROOT}%{prefix}/Tools/test_quick_extract
rm -rf ${RPM_BUILD_ROOT}%{prefix}/Library/Headers/NGCards
rm -rf ${RPM_BUILD_ROOT}%{prefix}/Library/Libraries/libNGCards.*
rm -rf ${RPM_BUILD_ROOT}%{prefix}/Library/SaxDrivers-%{sope_major_version}.%{sope_minor_version}
rm -rf ${RPM_BUILD_ROOT}%{prefix}/Library/SaxMappings

# ****************************** clean ********************************
%clean
rm -fr ${RPM_BUILD_ROOT}

# ****************************** files ********************************
%files -n sogo
%defattr(-,root,root,-)

/etc/init.d/sogod
/etc/httpd/conf.d/SOGo.conf
/usr/sbin/sogod
/var/run/sogo
/var/log/sogo
%{prefix}/Tools/sogod-0.9
%{prefix}/Library/Libraries/libSOGo.so.*
%{prefix}/Library/Libraries/libSOGoUI.so.*
%{prefix}/Library/Libraries/libOGoContentStore.so*
%{prefix}/Library/SOGo-%{sogo_version}/*.SOGo
%{prefix}/Library/SOGo-%{sogo_version}/Templates
%{prefix}/Library/SOGo-%{sogo_version}/WebServerResources
%{prefix}/Library/OCSTypeModels/appointment.ocs
%{prefix}/Library/OCSTypeModels/contact.ocs
%{prefix}/Library/OCSTypeModels/appointment-oracle.ocs
%{prefix}/Library/OCSTypeModels/contact-oracle.ocs
%{prefix}/Library/WOxElemBuilders-%{sope_version}/SOGoElements.wox

%doc ChangeLog README NEWS Scripts/sql-update-20070724.sh Scripts/sql-update-20070822.sh

%files -n sogo-devel
%{prefix}/Library/Headers/SOGo
%{prefix}/Library/Headers/SOGoUI
%{prefix}/Library/Libraries/libSOGo.so
%{prefix}/Library/Libraries/libSOGoUI.so

%files -n sope%{sope_major_version}%{sope_minor_version}-gdl1-contentstore
%defattr(-,root,root,-)
%{prefix}/Library/Libraries/libGDLContentStore*.so.%{sope_version}*

%files -n sope%{sope_major_version}%{sope_minor_version}-gdl1-contentstore-devel
%{prefix}/Library/Headers/GDLContentStore
%{prefix}/Library/Libraries/libGDLContentStore*.so

%files -n sope%{sope_major_version}%{sope_minor_version}-gdl1-tools
%defattr(-,root,root,-)
%{prefix}/Tools/gcs_cat
%{prefix}/Tools/gcs_gensql
%{prefix}/Tools/gcs_ls
%{prefix}/Tools/gcs_mkdir
%{prefix}/Tools/gcs_recreatequick

# **************************** pkgscripts *****************************
%post
if ! id sogo >& /dev/null; then /usr/sbin/adduser sogo; fi
/bin/chown sogo /var/run/sogo
/bin/chown sogo /var/log/sogo

%postun
if test "$1" = "0"
then
  /usr/sbin/userdel sogo
  /usr/sbin/groupdel sogo
  /bin/rm -rf /var/run/sogo
fi

# ********************************* changelog *************************
%changelog
* Tue Oct 4 2007 Francis Lachapelle <flachapelle@inverse.ca>
- added package sope-gdl1-contentstore

* Wed Jul 18 2007 Wolfgang Sourdeau <wsourdeau@inverse.ca>
- initial build

