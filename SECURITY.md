# Security Policy

## Reporting a Vulnerability

To report a security vulnerability in mod_proxy_msrpc, please use the GitHub
Security Advisory feature at:

    https://github.com/bombadil/mod_proxy_msrpc/security/advisories/new

For vulnerabilities affecting Sophos products that incorporate this module
(Sophos UTM, Sophos Firewall / SFOS), use the Sophos Responsible Disclosure
program via Bugcrowd:

    https://bugcrowd.com/sophos

Please do not disclose security vulnerabilities publicly until a fix has been
released.

---

## Disclosure History

### RDG_IN_DATA / RDG_OUT_DATA Not Registered

| Field         | Detail                                                  |
|---------------|---------------------------------------------------------|
| Reported by   | Arno van der Veen / itssecured.nl                       |
| Report date   | April 2026                                              |
| Sophos case   | 03152113                                                |
| Bugcrowd ID   | 9bb5f540-c573-4a24-8476-1c10a89b51a0                   |
| Fixed date    | 19 April 2026                                           |
| Severity      | Functional defect (denial of service for RDS Gateway)  |

**Summary:**
The module never registered the `RDG_IN_DATA` and `RDG_OUT_DATA` HTTP method
verbs used by Microsoft RDS Gateway (MS-TSGU protocol, Windows Server 2012+).
Apache therefore declined every RDS Gateway reverse-proxy request with:

    [proxy_msrpc:debug] mod_proxy_msrpc.c(604):
    declining due to bad method: RDG_OUT_DATA

**Timeline:**
- **May 2013** — Defect introduced in Sophos UTM 9.1 (initial module release)
- **April 2026** — Defect discovered and confirmed on SFOS v22.0.0 GA-Build411
  (approximately 13 years undetected)
- **17 April 2026** — Live evidence captured from production system
- **19 April 2026** — Fix implemented: `MSRPC_M_RDG_IN` and `MSRPC_M_RDG_OUT`
  added to method enum; `RDG_IN_DATA` and `RDG_OUT_DATA` registered via
  `ap_method_register()`; all handler conditionals extended to cover both
  RDG verb pairs

**Affected versions:** All versions from UTM 9.1 (May 2013) through
SFOS v22.0.0 GA-Build411 (April 2026).

**References:**
- MS-TSGU specification: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-tsgu
- MS-RPCH specification: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rpch
- Apache bug 40029: https://issues.apache.org/bugzilla/show_bug.cgi?id=40029

---

## Known Related Issues (External)

### nDPI strncmp Off-by-One for RPC_OUT_DATA

The nDPI deep packet inspection library contains an off-by-one error in its
`RPC_OUT_DATA` protocol detection: `strncmp` is called with length 11 instead
of the correct 12, resulting in a partial match against `"RPC_OUT_DAT"`.

This defect is in the nDPI library, not in mod_proxy_msrpc, and is documented
here for reference only. It does not affect the correctness of this module.
