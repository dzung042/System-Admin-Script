#!/usr/bin/env python3
## pip3  install aiohttp
import asyncio
from aiohttp import web


HOST = "0.0.0.0"
HTTP_PORT = 80
HTTPS_PORT = 443

# Đường dẫn cert/key cho HTTPS
CERT_FILE = "/etc/nginx/ssl/demovn.pem"
KEY_FILE  = "/etc/nginx/ssl/demo.key.pem"

REOPEN_AT_TEXT = "2026-01-16 01:30 (+07:00)"

HTML = f"""<!doctype html>
<html lang="vi">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <meta name="robots" content="noindex,nofollow" />
  <title>Website đang bảo trì</title>
  <style>
    body{{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial;background:#0b1020;color:#fff;min-height:100vh;display:grid;place-items:center}}
    .card{{width:min(920px,92vw);background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.14);border-radius:18px;padding:26px;box-shadow:0 20px 60px rgba(0,0,0,.45)}}
    h1{{margin:0 0 10px;font-size:38px;line-height:1.1}}
    p{{margin:0 0 14px;color:rgba(255,255,255,.75);line-height:1.6}}
    .row{{display:flex;gap:10px;flex-wrap:wrap;margin-top:14px}}
    a{{display:inline-block;padding:12px 14px;border-radius:12px;border:1px solid rgba(255,255,255,.18);text-decoration:none;color:#fff;background:rgba(255,255,255,.05);font-weight:600}}
    a.primary{{background:rgba(124,92,255,.9);border-color:rgba(124,92,255,.9)}}
    .hint{{margin-top:12px;font-size:13px;color:rgba(255,255,255,.6)}}
  </style>
</head>
<body>
  <div class="card">
    <h1>Website đang bảo trì</h1>
    <p>Xin lỗi vì sự bất tiện. Chúng tôi đang nâng cấp hệ thống. Vui lòng quay lại sau.</p>
    <div class="row">
      <a class="primary" href="mailto:baotri@bk.id.vn">Liên hệ hỗ trợ</a>
    </div>
    <div class="hint">Dự kiến hoạt động lại: {REOPEN_AT_TEXT}</div>
  </div>
</body>
</html>
"""

HTML_BYTES = HTML.encode("utf-8")  # encode 1 lần

async def maintenance(_request: web.Request) -> web.Response:
    return web.Response(
        body=HTML_BYTES,
        status=503,
        headers={
            "Content-Type": "text/html; charset=utf-8",
            "Cache-Control": "no-store",
            "Connection": "close",   # đóng nhanh để không bị giữ conn
            "Retry-After": "3600",
        },
    )

def make_app():
    app = web.Application(
        client_max_size=1024 * 1024,
        handler_args=None,
    )
    app.router.add_route("*", "/{tail:.*}", maintenance)
    return app

async def main():
    app_http = make_app()
    app_https = make_app()

    runner_http = web.AppRunner(app_http, access_log=None, keepalive_timeout=5)
    runner_https = web.AppRunner(app_https, access_log=None, keepalive_timeout=5)

    await runner_http.setup()
    await runner_https.setup()

    site_http = web.TCPSite(runner_http, HOST, HTTP_PORT, backlog=4096, reuse_port=True)

    ssl_ctx = None
    import ssl
    ssl_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ssl_ctx.load_cert_chain(CERT_FILE, KEY_FILE)

    site_https = web.TCPSite(runner_https, HOST, HTTPS_PORT, ssl_context=ssl_ctx, backlog=4096, reuse_port=True)

    await site_http.start()
    await site_https.start()

    print(f"[OK] HTTP  {HOST}:{HTTP_PORT}")
    print(f"[OK] HTTPS {HOST}:{HTTPS_PORT}")
    while True:
        await asyncio.sleep(3600)

if __name__ == "__main__":
    asyncio.run(main())
