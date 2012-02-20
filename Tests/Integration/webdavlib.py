# webdavlib.py - A versatile WebDAV Python Library
#
# Copyright (C) 2009, 2010 Inverse inc.
#
# Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
#
# webdavlib is free software; you can redistribute it and/or modify it under
# the terms of the GNU Lesser General Public License as published by the Free
# Software Foundation; either version 2, or (at your option) any later
# version.
#
# webdavlib is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with webdavlib; see the file COPYING. If not, write to the Free
# Software Foundation, 59 Temple Place - Suite 330, Boston, MA 02111-1307,
# USA.

import cStringIO
import httplib
import re
import time
import xml.dom.expatbuilder
import xml.etree.ElementTree
import xml.sax.saxutils
import sys

xmlns_dav = "DAV:"
xmlns_caldav = "urn:ietf:params:xml:ns:caldav"
xmlns_carddav = "urn:ietf:params:xml:ns:carddav"
xmlns_inversedav = "urn:inverse:params:xml:ns:inverse-dav"

url_re = None

class HTTPUnparsedURL:
    def __init__(self, url):
        self._parse(url)

    def _parse(self, url):
        # ((proto)://((username(:(password)?)@)?hostname(:(port))))(path)?
#        if url_re is None:
        url_parts = url.split("?")
        alpha_match = "[a-zA-Z0-9%\._-]+"
        num_match = "[0-9]+"
        pattern = ("((%s)://(((%s)(:(%s))?@)?(%s)(:(%s))?))?(/.*)"
                   % (alpha_match, alpha_match, alpha_match,
                      alpha_match, num_match))
        url_re = re.compile(pattern)
        re_match = url_re.match(url_parts[0])
        if re_match is None:
            raise Exception, "URL expression could not be parsed: %s" % url

        (trash, self.protocol, trash, trash, self.username, trash,
         self.password, self.hostname, trash, self.port, self.path) = re_match.groups()

        self.parameters = {}
        if len(url_parts) > 1:
            param_elms = url_parts[1].split("&")
            for param_pair in param_elms:
                parameter = param_pair.split("=")
                self.parameters[parameter[0]] = parameter[1]

class WebDAVClient:
    user_agent = "Mozilla/5.0"

    def __init__(self, hostname, port, username = None, password = "",
                 forcessl = False):
        if int(port) == 443 or forcessl:
            import M2Crypto.httpslib
            self.conn = M2Crypto.httpslib.HTTPSConnection(hostname, int(port),
                                                          True)
        else:
            self.conn = httplib.HTTPConnection(hostname, port, True)

        if username is None:
            self.simpleauth_hash = None
        else:
            self.simpleauth_hash = (("%s:%s" % (username, password))
                                    .encode('base64')[:-1])

    def prepare_headers(self, query, body):
        headers = { "User-Agent": self.user_agent }
        if self.simpleauth_hash is not None:
            headers["authorization"] = "Basic %s" % self.simpleauth_hash
        if body is not None:
            headers["content-length"] = len(body)
        if query.__dict__.has_key("depth") and query.depth is not None:
            headers["depth"] = query.depth
        if query.__dict__.has_key("content_type"):
            headers["content-type"] = query.content_type
        if not query.__dict__.has_key("accept-language"):
            headers["accept-language"] = 'en-us,en;q=0.5'

        query_headers = query.prepare_headers()
        if query_headers is not None:
            for key in query_headers.keys():
                headers[key] = query_headers[key]

        return headers

    def execute(self, query):
        body = query.render()

        query.start = time.time()
        self.conn.request(query.method, query.url,
                          body, self.prepare_headers(query, body))
        query.set_response(self.conn.getresponse());
        query.duration = time.time() - query.start

class HTTPSimpleQuery:
    method = None

    def __init__(self, url):
        self.url = url
        self.response = None
        self.start = -1
        self.duration = -1

    def prepare_headers(self):
        return {}

    def render(self):
        return None

    def set_response(self, http_response):
        headers = {}
        for rk, rv in http_response.getheaders():
            k = rk.lower()
            headers[k] = rv
        self.response = { "headers": headers,
                          "status": http_response.status,
                          "version": http_response.version,
                          "body": http_response.read() }

class HTTPGET(HTTPSimpleQuery):
    method = "GET"

class HTTPOPTIONS(HTTPSimpleQuery):
    method = "OPTIONS"

class HTTPQuery(HTTPSimpleQuery):
    def __init__(self, url):
        HTTPSimpleQuery.__init__(self, url)
        self.content_type = "application/octet-stream"

class HTTPPUT(HTTPQuery):
    method = "PUT"

    def __init__(self, url, content,
                 content_type="application/octet-stream",
                 exclusive=False):
        HTTPQuery.__init__(self, url)
        self.content = content
        self.content_type = content_type
        self.exclusive = exclusive

    def render(self):
        return self.content

    def prepare_headers(self):
        headers = HTTPQuery.prepare_headers(self)
        if self.exclusive:
            headers["if-none-match"] = "*"

        return headers

class HTTPPOST(HTTPPUT):
    method = "POST"

class WebDAVQuery(HTTPQuery):
    method = None

    def __init__(self, url, depth = None):
        HTTPQuery.__init__(self, url)
        self.content_type = "application/xml; charset=\"utf-8\""
        self.depth = depth
        self.ns_mgr = _WD_XMLNS_MGR()
        self.top_node = None

    # helper for PROPFIND and REPORT (only)
    def _initProperties(self, properties):
        props = _WD_XMLTreeElement("prop")
        self.top_node.append(props)
        for prop in properties:
            prop_tag = self.render_tag(prop)
            props.append(_WD_XMLTreeElement(prop_tag))

    def render(self):
        if self.top_node is not None:
            text = ("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n%s"
                    % self.top_node.render(self.ns_mgr.render()))
        else:
            text = ""

        return text

    def render_tag(self, tag):
        cb = tag.find("}")
        if cb > -1:
            ns = tag[1:cb]
            real_tag = tag[cb+1:]
            new_tag = self.ns_mgr.register(real_tag, ns)
        else:
            new_tag = tag

        return new_tag

    def set_response(self, http_response):
        HTTPQuery.set_response(self, http_response)
        headers = self.response["headers"]
        if (headers.has_key("content-type")
            and headers.has_key("content-length")
            and (headers["content-type"].startswith("application/xml")
                 or headers["content-type"].startswith("text/xml"))
            and int(headers["content-length"]) > 0):
            tree = xml.etree.ElementTree.ElementTree()
            stream = cStringIO.StringIO(self.response["body"])
            self.response["document"] = tree.parse(stream)

class WebDAVMKCOL(WebDAVQuery):
    method = "MKCOL"

class WebDAVDELETE(WebDAVQuery):
    method = "DELETE"

class WebDAVREPORT(WebDAVQuery):
    method = "REPORT"

class WebDAVGET(WebDAVQuery):
    method = "GET"

class WebDAVPROPFIND(WebDAVQuery):
    method = "PROPFIND"

    def __init__(self, url, properties, depth = None):
        WebDAVQuery.__init__(self, url, depth)
        self.top_node = _WD_XMLTreeElement("propfind")
        if properties is not None and len(properties) > 0:
            self._initProperties(properties)

class WebDAVPROPPATCH(WebDAVQuery):
    method = "PROPPATCH"

# <x0:propertyupdate xmlns:x1="urn:ietf:params:xml:ns:caldav" xmlns:x0="DAV:"><x0:set><x0:prop>

    def __init__(self, url, properties):
        WebDAVQuery.__init__(self, url, None)
        self.top_node = _WD_XMLTreeElement("propertyupdate")
        set_node = _WD_XMLTreeElement("set")
        self.top_node.append(set_node)
        prop_node = _WD_XMLTreeElement("prop")
        set_node.append(prop_node)

        prop_node.appendSubtree(self, properties)

class WebDAVMOVE(WebDAVQuery):
    method = "MOVE"
    destination = None
    host = None

    def prepare_headers(self):
        headers = WebDAVQuery.prepare_headers(self)
        print "DESTINATION", self.destination
        if self.destination is not None:
            headers["Destination"] = self.destination
        if self.host is not None:
            headers["Host"] = self.host
        return headers

class WebDAVPrincipalPropertySearch(WebDAVREPORT):
    def __init__(self, url, properties, matches):
        WebDAVQuery.__init__(self, url)
        ppsearch_tag = self.ns_mgr.register("principal-property-search",
                                            xmlns_dav)
        self.top_node = _WD_XMLTreeElement(ppsearch_tag)
        self._initMatches(matches)
        if properties is not None and len(properties) > 0:
            self._initProperties(properties)

    def _initMatches(self, matches):
        for match in matches:
            psearch = _WD_XMLTreeElement("property-search")
            self.top_node.append(psearch)
            prop = _WD_XMLTreeElement("prop")
            psearch.append(prop)
            match_tag = self.render_tag(match[0])
            prop.append(_WD_XMLTreeElement(match_tag))
            match_tag = _WD_XMLTreeElement("match")
            psearch.append(match_tag)
            match_tag.appendSubtree(self, match[1])

class WebDAVSyncQuery(WebDAVREPORT):
    def __init__(self, url, token, properties):
        WebDAVQuery.__init__(self, url)
        self.top_node = _WD_XMLTreeElement("sync-collection")

        sync_token = _WD_XMLTreeElement("sync-token")
        self.top_node.append(sync_token)
        if token is not None:
            sync_token.append(_WD_XMLTreeTextNode(token))

        if properties is not None and len(properties) > 0:
            self._initProperties(properties)

class WebDAVExpandProperty(WebDAVREPORT):
    def _parseTag(self, tag):
        result = []

        cb = tag.find("}")
        if cb > -1:
            result.append(tag[cb+1:])
            result.append(tag[1:cb])
        else:
            result.append(tag)
            result.append("DAV:")

        return result;

    def _propElement(self, tag):
        parsedTag = self._parseTag(tag)
        parameters = { "name": parsedTag[0] }
        if len(parsedTag) > 1:
            parameters["namespace"] = parsedTag[1]

        return _WD_XMLTreeElement("property", parameters)

    def __init__(self, url, query_properties, properties):
        WebDAVQuery.__init__(self, url)
        self.top_node = _WD_XMLTreeElement("expand-property")

        for query_tag in query_properties:
            property_query = self._propElement(query_tag)
            self.top_node.append(property_query)
            for tag in properties:
                property = self._propElement(tag)
                property_query.append(property)

class CalDAVPOST(WebDAVQuery):
    method = "POST"

    def __init__(self, url, content,
                 originator = None, recipients = None):
        WebDAVQuery.__init__(self, url)
        self.content_type = "text/calendar; charset=utf-8"
        self.originator = originator
        self.recipients = recipients
        self.content = content

    def prepare_headers(self):
        headers = WebDAVQuery.prepare_headers(self)

        if self.originator is not None:
            headers["originator"] = self.originator

        if self.recipients is not None:
            headers["recipient"] = ",".join(self.recipients)

        return headers

    def render(self):
        return self.content

class CalDAVCalendarMultiget(WebDAVREPORT):
    def __init__(self, url, properties, hrefs):
        WebDAVQuery.__init__(self, url)
        multiget_tag = self.ns_mgr.register("calendar-multiget", xmlns_caldav)
        self.top_node = _WD_XMLTreeElement(multiget_tag)
        if properties is not None and len(properties) > 0:
            self._initProperties(properties)

        for href in hrefs:
            href_node = _WD_XMLTreeElement("href")
            self.top_node.append(href_node)
            href_node.append(_WD_XMLTreeTextNode(href))

class CalDAVCalendarQuery(WebDAVREPORT):
    def __init__(self, url, properties, component = None, timerange = None):
        WebDAVQuery.__init__(self, url)
        multiget_tag = self.ns_mgr.register("calendar-query", xmlns_caldav)
        self.top_node = _WD_XMLTreeElement(multiget_tag)
        if properties is not None and len(properties) > 0:
            self._initProperties(properties)

        if component is not None:
            filter_tag = self.ns_mgr.register("filter",
                                              xmlns_caldav)
            compfilter_tag = self.ns_mgr.register("comp-filter",
                                                  xmlns_caldav)
            filter_node = _WD_XMLTreeElement(filter_tag)
            cal_filter_node = _WD_XMLTreeElement(compfilter_tag,
                                                 { "name": "VCALENDAR" })
            comp_node = _WD_XMLTreeElement(compfilter_tag,
                                           { "name": component })
            ## TODO
            # if timerange is not None:
            cal_filter_node.append(comp_node)
            filter_node.append(cal_filter_node)
            self.top_node.append(filter_node)

class CardDAVAddressBookQuery(WebDAVREPORT):
    def __init__(self, url, properties, searchProperty = None, searchValue = None):
        WebDAVQuery.__init__(self, url)
        query_tag = self.ns_mgr.register("addressbook-query", xmlns_carddav)
        ns_key = self.ns_mgr.xmlns[xmlns_carddav]
        self.top_node = _WD_XMLTreeElement(query_tag)
        if properties is not None and len(properties) > 0:
            self._initProperties(properties)

        if searchProperty is not None:
            filter_node = _WD_XMLTreeElement("%s:filter" % ns_key)
            self.top_node.append(filter_node)
            propfilter_node = _WD_XMLTreeElement("%s:prop-filter" % ns_key, { "name": searchProperty })
            filter_node.append(propfilter_node)
            match_node = _WD_XMLTreeElement("%s:text-match" % ns_key,
                                            { "collation": "i;unicasemap", "match-type": "starts-with" })
            propfilter_node.append(match_node)
            match_node.appendSubtree(None, searchValue)

class MailDAVMailQuery(WebDAVREPORT):
    def __init__(self, url, properties, filters = None,
                 sort = None, ascending = True):
        WebDAVQuery.__init__(self, url)
        mailquery_tag = self.ns_mgr.register("mail-query",
                                             xmlns_inversedav)
        self.top_node = _WD_XMLTreeElement(mailquery_tag)
        if properties is not None and len(properties) > 0:
            self._initProperties(properties)

        if filters is not None and len(filters) > 0:
            self._initFilters(filters)

        if sort is not None and len(sort) > 0:
            self._initSort(sort, ascending)

    def _initFilters(self, filters):
        mailfilter_tag = self.ns_mgr.register("mail-filters",
                                              xmlns_inversedav)
        mailfilter_node = _WD_XMLTreeElement(mailfilter_tag)
        self.top_node.append(mailfilter_node)
        for filterk in filters.keys():
            filter_tag = self.ns_mgr.register(filterk,
                                              xmlns_inversedav)
            filter_node = _WD_XMLTreeElement(filter_tag,
                                             filters[filterk])
            mailfilter_node.append(filter_node)

    def _initSort(self, sort, ascending):
        sort_tag = self.ns_mgr.register("sort", xmlns_inversedav)
        if ascending:
            sort_attrs = { "order": "ascending" }
        else:
            sort_attrs = { "order": "descending" }
        sort_node = _WD_XMLTreeElement(sort_tag, sort_attrs)
        self.top_node.append(sort_node)

        for item in sort:
            sort_subnode = _WD_XMLTreeElement(self.render_tag(item))
            sort_node.append(sort_subnode)

# private classes to handle XML stuff
class _WD_XMLNS_MGR:
    def __init__(self):
        self.xmlns = {}
        self.counter = 0

    def render(self):
        text = " xmlns=\"DAV:\""
        for k in self.xmlns:
            text = text + " xmlns:%s=\"%s\"" % (self.xmlns[k], k)

        return text

    def create_key(self, namespace):
        new_nssym = "n%d" % self.counter
        self.counter = self.counter + 1
        self.xmlns[namespace] = new_nssym

        return new_nssym

    def register(self, tag, namespace):
        if namespace != xmlns_dav:
            if self.xmlns.has_key(namespace):
                key = self.xmlns[namespace]
            else:
                key = self.create_key(namespace)
        else:
            key = None

        if key is not None:
            newTag = "%s:%s" % (key, tag)
        else:
            newTag = tag

        return newTag

class _WD_XMLTreeElement:
    typeNum = type(0)
    typeStr = type("")
    typeUnicode = type(u"")
    typeList = type([])
    typeDict = type({})

    def __init__(self, tag, attributes = {}):
        self.tag = tag
        self.children = []
        self.attributes = attributes

    def append(self, child):
        self.children.append(child)

    def appendSubtree(self, query, subtree):
        if type(subtree) == self.typeNum:
            strValue = "%d" % subtree
            textNode = _WD_XMLTreeTextNode(strValue)
            self.append(textNode)
        elif type(subtree) == self.typeUnicode:
            textNode = _WD_XMLTreeTextNode(subtree.encode("utf-8"))
            self.append(textNode)
        elif type(subtree) == self.typeStr:
            textNode = _WD_XMLTreeTextNode(subtree)
            self.append(textNode)
        elif type(subtree) == self.typeList:
            for x in subtree:
                self.appendSubtree(query, x)
        elif type(subtree) == self.typeDict:
            for x in subtree.keys():
                tag = query.render_tag(x)
                node = _WD_XMLTreeElement(tag)
                node.appendSubtree(query, subtree[x])
                self.append(node)
        else:
            None

    def render(self, ns_text = None):
        text = "<" + self.tag

        if ns_text is not None:
            text = text + ns_text

        for k in self.attributes:
            text = text + " %s=\"%s\"" % (k, self.attributes[k])

        if len(self.children) > 0:
            text = text + ">"
            for child in self.children:
                text = text + child.render()
            text = text + "</" + self.tag + ">"
        else:
            text = text + "/>"

        return text

class _WD_XMLTreeTextNode:
    def __init__(self, text):
        self.text = xml.sax.saxutils.escape(text)

    def render(self):
        return self.text
