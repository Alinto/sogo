import cStringIO
import httplib
import M2Crypto.httpslib
import time
import xml.sax.saxutils
import xml.dom.ext.reader.Sax2
import xml.xpath
import sys

class WebDAVClient:
    user_agent = "Mozilla/5.0"

    def __init__(self, hostname, port, username, password, forcessl = False):
        if port == "443" or forcessl:
            self.conn = M2Crypto.httpslib.HTTPSConnection(hostname, int(port),
                                                          True)
        else:
            self.conn = httplib.HTTPConnection(hostname, port, True)

        self.simpleauth_hash = (("%s:%s" % (username, password))
                                .encode('base64')[:-1])

    def prepare_headers(self, query, body):
        headers = { "User-Agent": self.user_agent,
                    "authorization": "Basic %s" % self.simpleauth_hash }
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

class HTTPQuery(HTTPSimpleQuery):
    def __init__(self, url):
        HTTPSimpleQuery.__init__(self, url)
        self.content_type = "application/octet-stream"

class HTTPPUT(HTTPQuery):
    method = "PUT"

    def __init__(self, url, content):
        HTTPQuery.__init__(self, url)
        self.content = content

    def render(self):
        return self.content

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
        self.xml_response = None
        self.xpath_namespace = { "D": "DAV:" }

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
            reader = xml.dom.ext.reader.Sax2.Reader()
            stream = cStringIO.StringIO(self.response["body"])
            dom_response = reader.fromStream(stream)
            self.response["document"] = dom_response.documentElement

    def xpath_evaluate(self, query, top_node = None):
        if top_node is None:
            top_node = self.response["document"]
        xpath_context = xml.xpath.CreateContext(top_node)
        xpath_context.setNamespaces(self.xpath_namespace)
        return xml.xpath.Evaluate(query, None, xpath_context)

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
        props = _WD_XMLTreeElement("prop")
        self.top_node.append(props)
        for prop in properties:
            prop_tag = self.render_tag(prop)
            props.append(_WD_XMLTreeElement(prop_tag))

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

class WebDAVPUT(WebDAVQuery):
    method = "PUT"

    def __init__(self, url, content):
        WebDAVQuery.__init__(self, url)
        self.content_type = "text/plain; charset=utf-8"
        self.content = content
    
    def prepare_headers(self):
        return WebDAVQuery.prepare_headers(self)

    def render(self):
        return self.content


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
        multiget_tag = self.ns_mgr.register("calendar-multiget", "urn:ietf:params:xml:ns:caldav")
        self.top_node = _WD_XMLTreeElement(multiget_tag)
        props = _WD_XMLTreeElement("prop")
        self.top_node.append(props)
        for prop in properties:
            prop_tag = self.render_tag(prop)
            props.append(_WD_XMLTreeElement(prop_tag))

        for href in hrefs:
            href_node = _WD_XMLTreeElement("href")
            self.top_node.append(href_node)
            href_node.append(_WD_XMLTreeTextNode(href))

class CalDAVCalendarQuery(WebDAVREPORT):
    def __init__(self, url, properties, component = None, timerange = None):
        WebDAVQuery.__init__(self, url)
        multiget_tag = self.ns_mgr.register("calendar-query", "urn:ietf:params:xml:ns:caldav")
        self.top_node = _WD_XMLTreeElement(multiget_tag)
        props = _WD_XMLTreeElement("prop")
        self.top_node.append(props)
        for prop in properties:
            prop_tag = self.render_tag(prop)
            props.append(_WD_XMLTreeElement(prop_tag))

        if component is not None:
            filter_tag = self.ns_mgr.register("filter",
                                              "urn:ietf:params:xml:ns:caldav")
            compfilter_tag = self.ns_mgr.register("comp-filter",
                                                  "urn:ietf:params:xml:ns:caldav")
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

class WebDAVSyncQuery(WebDAVREPORT):
    def __init__(self, url, token, properties):
        WebDAVQuery.__init__(self, url)
        self.top_node = _WD_XMLTreeElement("sync-collection")

        sync_token = _WD_XMLTreeElement("sync-token")
        self.top_node.append(sync_token)
        if token is not None:
            sync_token.append(_WD_XMLTreeTextNode(token))

        props = _WD_XMLTreeElement("prop")
        self.top_node.append(props)
        for prop in properties:
            prop_tag = self.render_tag(prop)
            props.append(_WD_XMLTreeElement(prop_tag))

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
        if namespace != "DAV:":
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
    def __init__(self, tag, attributes = {}):
        self.tag = tag
        self.children = []
        self.attributes = attributes

    def append(self, child):
        self.children.append(child)

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
