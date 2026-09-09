#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
cas-proxy-validate.py - CGI helper for SOGo CAS proxy validation

This script stores the PGT ID associated with a PGT IOU in memcached.
The key format must match the current SOGo implementation:
cas-pgtiou:<sha512 hex digest of PGT IOU>
"""

import hashlib
import os
import sys

try:
    from urllib.parse import parse_qs
except ImportError:
    from cgi import parse_qs  # pragma: no cover

import memcache


config = {
    "cas-addr": "127.0.0.1",
    "memcached-addrs": ["127.0.0.1:11211"],
}


class CASProxyValidator:
    def run(self):
        if "GATEWAY_INTERFACE" in os.environ:
            self._run_as_cgi()
        else:
            self._run_as_cmd()

    @staticmethod
    def _sha512_hash_ticket(ticket):
        """Return the lowercase hexadecimal SHA-512 digest used by SOGo."""
        if isinstance(ticket, str):
            ticket = ticket.encode("utf-8")
        return hashlib.sha512(ticket).hexdigest()

    @staticmethod
    def _print_cgi_response(message, code=403):
        print(
            "Status: {code}\r\n"
            "Content-Type: text/plain; charset=utf-8\r\n"
            "\r\n"
            "{message}".format(code=code, message=message)
        )

    def _cgi_checks(self):
        if os.environ.get("REQUEST_METHOD") != "GET":
            self._print_cgi_response("Only 'GET' is accepted.")
            return False

        remote_addr = os.environ.get("REMOTE_ADDR", "")
        if remote_addr != config["cas-addr"]:
            self._print_cgi_response("Who are you? ({})".format(remote_addr))
            return False

        return True

    @staticmethod
    def _get_cgi_parameters():
        # CAS sends pgtId and pgtIou in the query string for a GET callback.
        query_string = os.environ.get("QUERY_STRING", "")
        params = parse_qs(query_string, keep_blank_values=True)

        return {
            key: values[0] if values else ""
            for key, values in params.items()
        }

    def _run_as_cgi(self):
        if not self._cgi_checks():
            return

        params = self._get_cgi_parameters()

        # Preserve the historical behaviour used for certificate validation.
        if not params:
            self._print_cgi_response(
                "Empty parameters : assuming cert. validation", 200
            )
            return

        pgt_iou = params.get("pgtIou")
        pgt_id = params.get("pgtId")

        if pgt_iou is not None and pgt_id is not None:
            key = self._register_pgt_id_and_iou(pgt_iou, pgt_id)
            self._print_cgi_response(
                "'{}' set to '{}'".format(key, pgt_id), 200
            )
        else:
            self._print_cgi_response("Missing parameter.")

    def _run_as_cmd(self):
        if len(sys.argv) != 3:
            raise Exception("Missing or too many parameters.")

        pgt_iou = sys.argv[1]
        pgt_id = sys.argv[2]
        key = self._register_pgt_id_and_iou(pgt_iou, pgt_id)

        print("set '{}' to '{}'".format(key, pgt_id))

    def _register_pgt_id_and_iou(self, pgt_iou, pgt_id):
        # Must match:
        # [self sha512HashTicket: pgtIou]
        hashed_iou = self._sha512_hash_ticket(pgt_iou)
        key = "cas-pgtiou:{}".format(hashed_iou)

        mc = memcache.Client(config["memcached-addrs"])

        if not mc.set(key, pgt_id):
            raise RuntimeError(
                "Unable to store PGT mapping in memcached for key '{}'".format(key)
            )

        return key


if __name__ == "__main__":
    CASProxyValidator().run()
