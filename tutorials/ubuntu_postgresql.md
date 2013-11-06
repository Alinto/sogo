# ~~~~~~~~~~ DRAFT ~~~~~~~~~~
*[Pull Requests](https://github.com/DigitalOcean-User-Projects/Articles-and-Tutorials/pulls) gladly accepted* 
How To Install & Configure SOGo - an Open-Source Alternative to Microsoft Exchange
=====

### Introduction

SOGo is a free and modern scalable groupware server. It offers shared calendars, address books, and emails through your favourite Web browser and by using a native client such as Mozilla Thunderbird and Lightning.

SOGo is standard-compliant. It supports CalDAV, CardDAV, GroupDAV, iMIP and iTIP and reuses existing IMAP, SMTP and database servers - making the solution easy to deploy and interoperable with many applications.

## SOGo Features

* Scalable architecture suitable for deployments from dozens to many thousands of users
* Rich Web-based interface that shares the look and feel, the features and the data of Mozilla 
Thunderbird and Lightning
* Improved integration with Mozilla Thunderbird and Lightning by using the SOGo Connector and the SOGo Integrator
* Two-way synchronization support with any SyncML-capable devices (BlackBerry, Palm, Windows CE, etc.) by using the Funambol SOGo Connector

Standard protocols such as CalDAV, CardDAV, GroupDAV, HTTP, IMAP and SMTP are used to communicate with the SOGo platform or its sub-components. Mobile devices supporting the SyncML standard use the Funambol middleware to synchronize information.

To install and configure the native Microsoft Outlook compatibility layer, please refer to the [SOGo Native Microsoft Outlook Configuration Guide]().

## Prerequisites

SOGo reuses many components in an infrastructure. Thus, it requires the following:

* Database server (e.g. [MySQL](https://www.digitalocean.com/community/community_tags/mysql) or [PostgreSQL](https://www.digitalocean.com/community/community_tags/postgresql));
* LDAP server (e.g. OpenLDAP);
* SMTP server (e.g. [Postfix](https://www.digitalocean.com/community/articles/how-to-install-and-setup-postfix-on-ubuntu-12-04));
* IMAP server (e.g. Dovecot).

This guide  assumes that (i.) all of those components are running on the same server (i.e. "localhost" or "127.0.0.1") (ii.) on which you will install SOGo.

## Installation

SOGo supports the following 32-bit and 64-bit operating systems:

* Ubuntu 8.10 (Intrepid) to 12.04 (Precise)
* Community ENTerprise Operating System (CentOS) 5 and 6
* [Debian GNU/Linux 5.0 (Lenny) to 7.0 (Wheezy)](http://www.sogo.nu/english/nc/support/faq/article/how-to-install-sogo-on-debian-2.html)
* Red Hat Enterprise Linux (RHEL) Server 5 and 6

### Ubuntu Precise Pangolin (12.04)

If you are running Ubuntu, you must first add the SOGo repository to your `apt source list`, by executing the following commands:

	sudo vi /etc/apt/sources.list

Then, on your keyboard, tap on the `i` key and append the line, below, to the end of your current list:

	deb http://inverse.ca/ubuntu precise precise

Then, tap the following keystrokes: `Esc` followed by `:` and `w` and `q` and, finally, `enter`.

Next, you must add SOGo's GPG public key to Ubuntu's `apt keyring`. To do so, execute the following commands:

	sudo apt-key adv --keyserver keys.gnupg.net --recv-key 0x810273C4

Then, update your lists of available software packages, by executing:

	sudo apt-get update 

Finally, execute:

	sudo apt-get -y install sogo

Next, install the following additional packages:

	sudo apt-get -y install binutils-doc gcc-4.6-locales gcc-4.6-multilib libmudflap0-4.6-dev gcc-4.6-doc libgcc1-dbg libgomp1-dbg libquadmath0-dbg libmudflap0-dbg binutils-gold gnustep-base-doc gnustep-make-doc gobjc-4.6-multilib libobjc3-dbg glibc-doc libcache-memcached-perl nginx mysql-server

Then, create a custom nginx config file for SOGo. To do so, execute:

	sudo vi /etc/nginx/sites-enabled/sogo.yourdomain.tld

Next, copy the following and paste it into the newly-created file (replace `sogo.yourdomain.tld` with your FQDN):

	server {

		listen 80 default;
		server_name sogo.yourdomain.tld;

		# redirect http to https
		rewrite ^ https://$server_name$request_uri? permanent; 
	}
	server {

		listen 443;
		server_name sogo.yourdomain.tld; 
		root /usr/lib/GNUstep/SOGo/WebServerResources/; 
		ssl on;
		ssl_certificate /etc/nginx/sslcerts/mycertificate.crt;
		ssl_certificate_key /etc/nginx/sslcerts/mykey.key;
		location = / {
		rewrite ^ https://$server_name/SOGo; 
		allow all; 
		}
		location ^~/SOGo {
		proxy_pass http://127.0.0.1:20000; 
		proxy_redirect http://127.0.0.1:20000 default; 

		# forward user's IP address 
		proxy_set_header X-Real-IP $remote_addr; 
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; 
		proxy_set_header Host $host; 
		proxy_set_header x-webobjects-server-protocol HTTP/1.0; 
		proxy_set_header x-webobjects-remote-host 127.0.0.1; 
		proxy_set_header x-webobjects-server-name $server_name; 
		proxy_set_header x-webobjects-server-url $scheme://$host; 
		proxy_connect_timeout 90;
		proxy_send_timeout 90;
		proxy_read_timeout 90;
		proxy_buffer_size 4k;
		proxy_buffers 4 32k;
		proxy_busy_buffers_size 64k;
		proxy_temp_file_write_size 64k;
		client_max_body_size 50m;
		client_body_buffer_size 128k;
		break;
		}
		location /SOGo.woa/WebServerResources/ {
		alias /usr/lib/GNUstep/SOGo/WebServerResources/;
		allow all;
		}
		location /SOGo/WebServerResources/ {
		alias /usr/lib/GNUstep/SOGo/WebServerResources/; 
		allow all; 
		}
		location ^/SOGo/so/ControlPanel/Products/([^/]*)/Resources/(.*)$ {
		alias /usr/lib/GNUstep/SOGo/$1.SOGo/Resources/$2; 
		}
		location ^/SOGo/so/ControlPanel/Products/[^/]*UI/Resources/.*\.(jpg|png|gif|css|js)$ {
		alias /usr/lib/GNUstep/SOGo/$1.SOGo/Resources/$2; 
		}
	}

Nginx will rewrite all unsecured requests on port 80 to https on port 443. Consequently, ensure that these two ports are open if you have deployed a firewall. *See* [How to Setup a Firewall with UFW on an Ubuntu and Debian Cloud Server](https://www.digitalocean.com/community/articles/how-to-setup-a-firewall-with-ufw-on-an-ubuntu-and-debian-cloud-server); or [How To Setup a Basic IP Tables Configuration on Centos 6](https://www.digitalocean.com/community/articles/how-to-setup-a-basic-ip-tables-configuration-on-centos-6).

### RPM-based Distributions: Red Hat or CentOS

SOGo can be installed using the yum utility. To do so, first create the 
`/etc/yum.repos.d/inverse.repo` configuration file with the following content:
 
	[SOGo]
	name=Inverse SOGo Repository
	baseurl=http://inverse.ca/downloads/SOGo/RHEL6/$basearch
	gpgcheck=0

Some of the softwares on which SOGo depends are available from the repository of RepoForge (previously known as RPMforge). To add RepoForge to your packages sources, download and install the appropriate RPM package from [http://packages.sw.be/rpmforge-release/](http://packages.sw.be/rpmforge-release/). Also make sure you enabled the “rpmforge-extras” repository. For more information on using RepoForge, visit [http://repoforge.org/use/](http://repoforge.org/use/)

Once the yum configuration file has been created, you are now ready to install SOGo and its dependencies. To do so, proceed with the following command:

	yum install sogo

This will install SOGo and its dependencies such as GNUstep, the SOPE packages and memcached. Once the base packages are installed, you need to install the proper database connector suitable for your environment.

You need to install `sope49-gdl1-postgresql` for the PostgreSQL database system or `sope49-gdl1-mysql` for MySQL. The installation command will thus look like this:

	yum install sope49-gdl1-postgresql

Once completed, SOGo will be fully installed on your server. You are now ready to configure it.

## Configuration

In SOGo, users' applications settings are stored in `/etc/sogo/sogo.conf`. You can use your favorite text editor to modify the file.

## Additional Resources

* [Link1]();
* [Link2]();
* [Link3]().

# ~~~~~~~~~~ DRAFT ~~~~~~~~~~
*[Pull Requests](https://github.com/DigitalOcean-User-Projects/Articles-and-Tutorials/pulls) gladly accepted* 