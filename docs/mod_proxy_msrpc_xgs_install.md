# mod_proxy_msrpc RDGHTTP test module for Sophos XGS

## Purpose

This package contains a lab build of `mod_proxy_msrpc` with RD Gateway HTTP transport handling added for Sophos XGS WAF testing.

The verified build preserves the existing RPC-HTTP path and adds support for classic RDGHTTP method forwarding:

- `RPC_IN_DATA` / `RPC_OUT_DATA`: existing MSRPC/RPC-HTTP handling, unchanged as the compatibility guard.
- `RDG_OUT_DATA` / `RDG_IN_DATA`: forwarded as RD Gateway HTTP tunnel traffic without parsing it as RPC PDUs.
- RDGHTTP with `RDG-Auth-Scheme: SSPI_NTLM`: suppresses the outer `Authorization` header toward the backend and lets RDGW handle extended auth.
- RDGHTTP WebSocket upgrade requests: downgraded upstream to classic RDGHTTP by stripping `Upgrade` / `Sec-WebSocket-*` headers and forwarding `Connection: Keep-Alive`.

The WebSocket downgrade is deliberate. The module does not implement a bidirectional WebSocket frame tunnel; forwarding a backend `101 Switching Protocols` response without full upgraded transport handling is not sufficient. FreeRDP falls back cleanly when the upgrade attempt receives classic RDGHTTP `200 OK`.

## Tested environment

- Sophos Firewall: SFOS 22.0.0 GA-Build411
- Appliance: XG_Test / SFV4C6 lab VM
- Apache module target: Apache 2.4.64, glibc 2.27 build
- Active tested module MD5: `0d33bea4d30d0eea5de5c064c8ae3ae7`
- Active tested module file in this repository: `module/mod_proxy_msrpc.so`
- WAF rule under test: rule id `8`, rule name `rdgw`
- Gateway public name under test: `remote.itsecured.nl`
- Backend RD Gateway under test: `172.16.17.30`

## Repository layout

- `src/`: source tree for the Apache module.
- `module/mod_proxy_msrpc.so`: final verified Sophos XGS/SFOS lab `.so` for installation.
- `docs/`: installation, validation, and implementation notes.
- `README.pod`: project overview, supported methods, build expectations, and caveats.

## Install on XGS

Use the Sophos console menu to reach Advanced Shell:

1. SSH to the firewall as `admin`.
2. Select `5. Device Management`.
3. Select `3. Advanced Shell`.

Do not install from the normal device console; the Advanced Shell is required for filesystem/module operations.

Copy the module to the XGS first:

```sh
scp module/mod_proxy_msrpc.so admin@192.168.45.138:/tmp/mod_proxy_msrpc.so
```

Then run the following from Advanced Shell:

```sh
set -e
cp -p /usr/apache/modules/mod_proxy_msrpc.so /usr/apache/modules/mod_proxy_msrpc.so.bak.before-rdg_ws_downgrade1.$(date +%Y%m%d%H%M%S)
cp /tmp/mod_proxy_msrpc.so /usr/apache/modules/mod_proxy_msrpc.so
chown root:root /usr/apache/modules/mod_proxy_msrpc.so
chmod 755 /usr/apache/modules/mod_proxy_msrpc.so
md5sum /usr/apache/modules/mod_proxy_msrpc.so
strings /usr/apache/modules/mod_proxy_msrpc.so | grep -E 'RDGHTTP|SSPI_NTLM|RDG_OUT_DATA|RDG_IN_DATA|WebSocket' || true
/usr/apache/bin/apachectl configtest 2>&1
/usr/apache/bin/start_waf.sh restart 2>&1 || /usr/apache/bin/start_waf.sh reload 2>&1
sleep 8
ps w | grep -E '[u]sr/apache/bin/httpd|[w]afgr' || true
```

Expected MD5:

```text
0d33bea4d30d0eea5de5c064c8ae3ae7  /usr/apache/modules/mod_proxy_msrpc.so
```

Expected string markers:

```text
RDG_IN_DATA
RDG_OUT_DATA
%s: RDGHTTP SSPI_NTLM mode, suppressing Authorization header toward backend
%s: RDGHTTP WebSocket upgrade requested; downgrading upstream request to classic HTTP transport
```

Expected Apache config test:

```text
Syntax OK
```

The lab system printed a `DocumentRoot ... does not exist` warning during `apachectl configtest`; that warning existed in the WAF configuration and did not block module loading.

## Rollback

Each install command creates a timestamped backup:

```text
/usr/apache/modules/mod_proxy_msrpc.so.bak.before-rdg_ws_downgrade1.YYYYMMDDHHMMSS
```

To roll back:

```sh
set -e
cp -p /usr/apache/modules/mod_proxy_msrpc.so /usr/apache/modules/mod_proxy_msrpc.so.bak.before-rollback.$(date +%Y%m%d%H%M%S)
cp /usr/apache/modules/mod_proxy_msrpc.so.bak.before-rdg_ws_downgrade1.YYYYMMDDHHMMSS /usr/apache/modules/mod_proxy_msrpc.so
chown root:root /usr/apache/modules/mod_proxy_msrpc.so
chmod 755 /usr/apache/modules/mod_proxy_msrpc.so
/usr/apache/bin/apachectl configtest 2>&1
/usr/apache/bin/start_waf.sh restart 2>&1 || /usr/apache/bin/start_waf.sh reload 2>&1
```

Replace `YYYYMMDDHHMMSS` with the actual backup suffix.

## Validation

The final verification used FreeRDP 3 from WSL `Ubuntu-Codex` with two forced modes:

1. Forced RPC-HTTP.
2. Forced RDGHTTP/HTTP with `extauth-sspi-ntlm`.

The helper command used in the lab:

```powershell
$env:RDP_PASS='REDACTED'
& 'D:\Users\ArnovanderVeen\Documents\Sophos XGS\tools\run_rdg_verification_cycle.ps1' `
  -Target 'sessionhost.lab.local' `
  -RpcSeconds 34 `
  -HttpSeconds 50 `
  -ScreenshotDelaySeconds 24 `
  -HttpMode http-extauth
```

Final proof from the lab was captured as FreeRDP logs and screenshots during
the June 2026 validation run. Those files are not required to build or install
the module from this source repository.

RPC success markers:

```text
TS Gateway Connection Success
CONNECTION_STATE_FINALIZATION_CLIENT_FONT_MAP --> CONNECTION_STATE_ACTIVE
```

RDGHTTP success markers:

```text
RDG_OUT_DATA authorization result: HTTP_STATUS_OK [200]
RDG_IN_DATA authorization result: HTTP_STATUS_OK [200]
CONNECTION_STATE_FINALIZATION_CLIENT_FONT_MAP --> CONNECTION_STATE_ACTIVE
```

## WAF log expectations

For forced RPC-HTTP, the WAF should show `RPC_IN_DATA` and `RPC_OUT_DATA` with initial `401` authentication responses followed by `200` tunnel traffic.

For forced RDGHTTP/HTTP-extauth, the WAF should show:

```text
method="RDG_OUT_DATA" statuscode="200"
method="RDG_IN_DATA" statuscode="200"
```

For WebSocket-capable HTTP clients using `RDG-Auth-Scheme: SSPI_NTLM`, the module should log:

```text
RDGHTTP WebSocket upgrade requested; downgrading upstream request to classic HTTP transport
RDGHTTP skipped WebSocket upgrade header [Connection: Upgrade]
RDGHTTP skipped WebSocket upgrade header [Upgrade: websocket]
RDGHTTP skipped WebSocket upgrade header [Sec-Websocket-Version: 13]
RDGHTTP skipped WebSocket upgrade header [Sec-Websocket-Key: ...]
RDGHTTP forwarding request header [Connection: Keep-Alive]
```

The expected result after downgrade is classic RDGHTTP `200 OK`, not backend `101 Switching Protocols`.

## Known caveat: default MSTSC / default FreeRDP HTTP

The verified path is forced RDGHTTP/HTTP with `extauth-sspi-ntlm`. Default clients may choose `Authorization: Negotiate` instead. In this lab that default Negotiate path still failed after the backend `401` challenge and connection reset.

This appears to be an RD Gateway/IIS authentication topology issue rather than an RPC module regression:

- FreeRDP does not switch to RDG extended SSPI_NTLM merely because the server advertises `WWW-Authenticate: SSPI_NTLM`.
- The client must opt into RDG extended auth so its binary RDG handshake also advertises `HTTP_EXTENDED_AUTH_SSPI_NTLM`.
- If TLS terminates at XGS while RDGW/IIS expects Extended Protection / channel binding tied to the original client TLS session, default Negotiate may fail or loop credentials.

For a production-quality default MSTSC path, validate RDGW certificate names, SPNs, IIS/RDG authentication providers, Extended Protection settings, and TLS termination design.

## Build notes

A normal source build uses the classic Apache module/autotools path:

```sh
./configure
make
```

The builder is responsible for using a development environment that matches the
target Apache reverse proxy. The Apache module ABI, module magic number,
APR/APR-util versions, and platform libraries must match the environment that
will load `mod_proxy_msrpc.so`.

For Sophos XGS/SFOS lab validation, this repository already includes the tested
artifact:

```text
module/mod_proxy_msrpc.so
```
