from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        n=parse_qs(urlparse(self.path).query).get('n',['x'])[0]
        data=self.rfile.read(int(self.headers.get('Content-Length',0)))
        open('tools_tmp/recv/'+n+'.bin','wb').write(data)
        self.send_response(200); self.send_header('Access-Control-Allow-Origin','*'); self.end_headers()
    def do_OPTIONS(self):
        self.send_response(200)
        for k,v in [('Access-Control-Allow-Origin','*'),('Access-Control-Allow-Methods','POST'),('Access-Control-Allow-Headers','*'),('Access-Control-Allow-Private-Network','true')]: self.send_header(k,v)
        self.end_headers()
    def log_message(self,*a): pass
HTTPServer(('127.0.0.1',8765),H).serve_forever()
