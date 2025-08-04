#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler
from socketserver import ThreadingMixIn
Handler = SimpleHTTPRequestHandler
Server = type('ThreadingHTTPServer', (ThreadingMixIn, HTTPServer), {})
server = Server(('0.0.0.0', 8000), Handler)
print('Serving on http://0.0.0.0:8000')
server.serve_forever()
