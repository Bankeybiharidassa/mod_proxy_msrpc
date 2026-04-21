#!/usr/bin/env bash
set -euo pipefail

: "${SRC_DIR:=/src}"
: "${OUT_DIR:=/out}"
: "${WORK_DIR:=/work}"

HTTPD_VERSION=2.4.64
APR_VERSION=1.7.2
APR_UTIL_VERSION=1.6.3

HTTPD_SHA256=120b35a2ebf264f277e20f9a94f870f2063342fbff0861404660d7dd0ab1ac29
APR_SHA256=75e77cc86776c030c0a5c408dfbd0bf2a0b75eed5351e52d5439fa1e5509a43e
APR_UTIL_SHA256=a41076e3710746326c3945042994ad9a4fcac0ce0277dd8fea076fec3c9772b5

PREFIX=/opt/httpd-target
BUILD_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SHORT_SHA="$(git -C "$SRC_DIR" rev-parse --short HEAD)"
FULL_SHA="$(git -C "$SRC_DIR" rev-parse HEAD)"

mkdir -p "$WORK_DIR" "$OUT_DIR"
cd "$WORK_DIR"

fetch_and_verify() {
  local url="$1" file="$2" expected="$3"
  wget -q "$url" -O "$file"
  echo "$expected  $file" | sha256sum -c -
}

fetch_and_verify "https://archive.apache.org/dist/httpd/httpd-${HTTPD_VERSION}.tar.bz2" "httpd-${HTTPD_VERSION}.tar.bz2" "$HTTPD_SHA256"
fetch_and_verify "https://archive.apache.org/dist/apr/apr-${APR_VERSION}.tar.bz2" "apr-${APR_VERSION}.tar.bz2" "$APR_SHA256"
fetch_and_verify "https://archive.apache.org/dist/apr/apr-util-${APR_UTIL_VERSION}.tar.bz2" "apr-util-${APR_UTIL_VERSION}.tar.bz2" "$APR_UTIL_SHA256"

rm -rf "apr-${APR_VERSION}" "apr-util-${APR_UTIL_VERSION}" "httpd-${HTTPD_VERSION}"
tar -xjf "apr-${APR_VERSION}.tar.bz2"
tar -xjf "apr-util-${APR_UTIL_VERSION}.tar.bz2"
tar -xjf "httpd-${HTTPD_VERSION}.tar.bz2"

cd "$WORK_DIR/apr-${APR_VERSION}"
./configure --prefix="$PREFIX" --enable-threads
make -j"$(nproc)"
make install

cd "$WORK_DIR/apr-util-${APR_UTIL_VERSION}"
./configure --prefix="$PREFIX" --with-apr="$PREFIX" --with-expat=/usr
make -j"$(nproc)"
make install

cd "$WORK_DIR/httpd-${HTTPD_VERSION}"
./configure --prefix="$PREFIX" \
  --with-apr="$PREFIX" \
  --with-apr-util="$PREFIX" \
  --with-mpm=worker --enable-mpms-shared=worker \
  --enable-so --enable-proxy=shared \
  --with-pcre=/usr/bin/pcre-config
make -j"$(nproc)"
make install

MMN_MAJOR="$(grep -E "^#define[[:space:]]+MODULE_MAGIC_NUMBER_MAJOR[[:space:]]+[0-9]+" "$PREFIX/include/ap_mmn.h" | awk '{print $3}')"
MMN_MINOR="$(grep -E "^#define[[:space:]]+MODULE_MAGIC_NUMBER_MINOR[[:space:]]+[0-9]+" "$PREFIX/include/ap_mmn.h" | awk '{print $3}')"
if [[ "$MMN_MAJOR:$MMN_MINOR" != "20120211:141" ]]; then
  echo "ERROR: MMN mismatch; expected 20120211:141 got ${MMN_MAJOR}:${MMN_MINOR}" >&2
  exit 1
fi

"$PREFIX/bin/apxs" -q HTTPD_VERSION | grep -Fx "2.4.64" >/dev/null
"$PREFIX/bin/apxs" -q APR_VERSION | grep -Fx "1.7.2" >/dev/null

cd "$SRC_DIR"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
if [[ -x ./autogen.sh ]]; then
  ./autogen.sh
fi
APXS="$PREFIX/bin/apxs" ./configure
make -j"$(nproc)"

MODULE_SO="$(find "$SRC_DIR" -path '*/.libs/mod_proxy_msrpc.so' | head -n1)"
if [[ -z "$MODULE_SO" ]]; then
  echo "ERROR: mod_proxy_msrpc.so not found under .libs" >&2
  exit 1
fi

VERIFY_LOG="$OUT_DIR/verification.txt"
{
  echo '## file'
  file "$MODULE_SO"
  echo
  echo '## readelf -d NEEDED'
  readelf -d "$MODULE_SO" | grep NEEDED || true
  echo
  echo '## readelf -V GLIBC versions'
  readelf -V "$MODULE_SO" | grep -oE 'GLIBC_[0-9.]+' | sort -u || true
  echo
  echo '## nm -D'
  nm -D --defined-only "$MODULE_SO" | grep -Ei 'proxy_msrpc|module$' || true
  echo
  echo '## readelf -p .rodata'
  readelf -p .rodata "$MODULE_SO" | grep -E '2\.4\.64|20120211' || true
  echo
  echo '## objdump RPATH/RUNPATH'
  objdump -p "$MODULE_SO" | grep -iE 'rpath|runpath' || true
} | tee "$VERIFY_LOG"

GLIBC_MAX="$(readelf -V "$MODULE_SO" | grep -oE 'GLIBC_[0-9.]+' | sed 's/GLIBC_//' | sort -V | tail -n1)"
if [[ -n "$GLIBC_MAX" ]] && [[ "$(printf '%s\n' "$GLIBC_MAX" '2.27' | sort -V | tail -n1)" != "2.27" ]]; then
  echo "ERROR: GLIBC ceiling violated (max $GLIBC_MAX)" >&2
  exit 1
fi

mapfile -t needed < <(readelf -d "$MODULE_SO" | awk -F'[][]' '/NEEDED/ {print $2}')
<<<<<<< codex/build-sfos-source-tree-with-apache-modules-r8ge8h
allowed=(libapr-1.so.0 libaprutil-1.so.0 libpthread.so.0 libc.so.6 libdl.so.2 libcrypt.so.1 libuuid.so.1)
=======
allowed=(libapr-1.so.0 libaprutil-1.so.0 libpthread.so.0 libc.so.6 libdl.so.2 libcrypt.so.1)
>>>>>>> master
for lib in "${needed[@]}"; do
  ok=0
  for a in "${allowed[@]}"; do
    if [[ "$lib" == "$a" ]]; then
      ok=1
      break
    fi
  done
  if [[ $ok -ne 1 ]]; then
<<<<<<< codex/build-sfos-source-tree-with-apache-modules-r8ge8h
    echo "ERROR: unexpected NEEDED entry: $lib (allowed: ${allowed[*]})" >&2
=======
    echo "ERROR: unexpected NEEDED entry: $lib" >&2
>>>>>>> master
    exit 1
  fi
done

cp "$MODULE_SO" "$OUT_DIR/mod_proxy_msrpc.so"

cat > "$OUT_DIR/README.install.md" <<'README'
# mod_proxy_msrpc install instructions (SFOS 22.0.0 GA-Build411 NFR)

## 1) Find Apache module directory on appliance (TODO on box)

```sh
find /usr -name '*.so' -path '*modules*' 2>/dev/null | head
find /usr -name 'mod_proxy.so' 2>/dev/null
```

Use the directory where existing Apache modules live.

## 2) Copy module to appliance

```sh
scp mod_proxy_msrpc.so admin@<nfr-ip>:/tmp/
```

Then on appliance:

```sh
mv /tmp/mod_proxy_msrpc.so <apache-modules-dir>/mod_proxy_msrpc.so
chmod 0755 <apache-modules-dir>/mod_proxy_msrpc.so
chown root:root <apache-modules-dir>/mod_proxy_msrpc.so
```

## 3) Load module in Apache config

Add in `/usr/conf/httpd.conf` (or active WAF Apache config):

```apache
LoadModule proxy_msrpc_module modules/mod_proxy_msrpc.so
```

## 4) Minimal config snippet

```apache
ProxyPass        /rpc/ http://<exchange-backend>/rpc/
ProxyPassReverse /rpc/ http://<exchange-backend>/rpc/
OutlookAnywherePassthrough On
OutlookAnywhereUserAgent MSRPC
OutlookAnywhereUserAgent MS-RDGateway/1.0
```

(Backend URL and vhost details require environment-specific tuning.)

## 5) Reload Apache (SFOS TODO)
Try in order:

```sh
service apache2 reload
/etc/init.d/apache2 reload
apachectl -k graceful
```

## 6) Verify module load

```sh
httpd -M 2>&1 | grep msrpc
```

Expected: `proxy_msrpc_module` listed. If not, inspect `/usr/logs/error_log`.

## 7) Rollback

Comment out `LoadModule proxy_msrpc_module ...`, reload Apache, then remove `mod_proxy_msrpc.so`.
README

SO_SHA256="$(sha256sum "$OUT_DIR/mod_proxy_msrpc.so" | awk '{print $1}')"
GCC_VER="$(gcc --version | head -n1)"
PCRE_VER="$(pcre-config --version)"

cat > "$OUT_DIR/BUILD_INFO.txt" <<EOFINFO
Apache version built against: ${HTTPD_VERSION}
MMN confirmed: ${MMN_MAJOR}:${MMN_MINOR}
APR: ${APR_VERSION}
APR-util: ${APR_UTIL_VERSION}
PCRE: ${PCRE_VER}
glibc ceiling target: 2.27
Detected max GLIBC symbol in module: GLIBC_${GLIBC_MAX}
Distro: Ubuntu 18.04 (bionic)
Compiler: ${GCC_VER}
Module commit sha: ${FULL_SHA}
Build timestamp (UTC): ${BUILD_TS}
mod_proxy_msrpc.so sha256: ${SO_SHA256}
httpd-${HTTPD_VERSION}.tar.bz2 sha256: ${HTTPD_SHA256}
apr-${APR_VERSION}.tar.bz2 sha256: ${APR_SHA256}
apr-util-${APR_UTIL_VERSION}.tar.bz2 sha256: ${APR_UTIL_SHA256}
EOFINFO

TARBALL="$OUT_DIR/mod_proxy_msrpc-${HTTPD_VERSION}-glibc2.27-${SHORT_SHA}.tar.gz"
tar -C "$OUT_DIR" -czf "$TARBALL" mod_proxy_msrpc.so README.install.md BUILD_INFO.txt verification.txt

echo "Build completed: $TARBALL"
