# Security Policy

## Scope

This repository is a source and lab-validation fork of `mod_proxy_msrpc` for
Apache reverse proxy deployments, including Microsoft Outlook Anywhere/RPC-HTTP
and Microsoft Remote Desktop Gateway traffic.

The repository currently contains:

- Source code for `mod_proxy_msrpc`.
- Documentation for Sophos XGS/SFOS lab installation and validation.
- A prebuilt Sophos XGS/SFOS lab test module at `module/mod_proxy_msrpc.so`.

The prebuilt module is a lab/test artifact for the verified Sophos XGS target.
Operators, vendors, and Sophos engineering should build from source in their own
target-compatible Apache/APR/APXS development environment.

## Reporting a Vulnerability

For vulnerabilities in this fork, use the GitHub Security Advisory feature for
this repository:

```text
https://github.com/Bankeybiharidassa/mod_proxy_msrpc/security/advisories/new
```

If GitHub Security Advisories are not available to you, open a private contact
path with the repository owner before publishing details.

For vulnerabilities in Sophos products that embed, derive from, or are affected
by this module, report through Sophos responsible disclosure:

```text
https://bugcrowd.com/sophos
```

Please do not disclose exploitable security issues publicly until affected
parties have had reasonable time to triage and remediate.

## What Counts as a Security Issue

Please report issues such as:

- Memory corruption, request smuggling, header injection, or unsafe parsing in
  the Apache module.
- Authentication bypass or authorization bypass introduced by module behavior.
- Cross-tenant, cross-vhost, or backend-confusion behavior in reverse proxy use.
- Denial of service caused by malformed traffic that crashes or wedges Apache.
- Incorrect tunnel handling that exposes traffic to the wrong backend.

Functional interoperability bugs are welcome as normal GitHub issues, especially
when they affect RD Gateway, Outlook Anywhere, or Apache reverse proxy behavior.
If the impact is uncertain, treat it as security-sensitive first.

## Current Lab Validation Status

The current Sophos XGS/SFOS lab module is:

```text
module/mod_proxy_msrpc.so
MD5: 0d33bea4d30d0eea5de5c064c8ae3ae7
```

Validated behavior in the June 2026 lab run:

- Existing RPC-HTTP handling remained functional.
- `RDG_IN_DATA` and `RDG_OUT_DATA` are registered as HTTP methods.
- RDGHTTP traffic is handled as HTTP tunnel traffic, not parsed as RPC PDUs.
- `RDG-Auth-Scheme: SSPI_NTLM` handling was added for RD Gateway extended auth.
- WebSocket upgrade attempts are deliberately downgraded upstream to classic
  RDGHTTP because this module does not implement a WebSocket frame tunnel.

Known caveat:

- Default MSTSC/default FreeRDP HTTP may still choose Negotiate rather than RDG
  extended `SSPI_NTLM`. The verified HTTP path is forced RDGHTTP/HTTP with
  extended SSPI_NTLM authentication. This is documented as an interoperability
  caveat, not as a confirmed module security vulnerability.

## Disclosure / Defect History

### RDG_IN_DATA / RDG_OUT_DATA Not Registered

| Field | Detail |
| --- | --- |
| Reported by | Arno van der Veen / itssecured.nl |
| Report date | April 2026 |
| Sophos case | 03152113 |
| Bugcrowd ID | 9bb5f540-c573-4a24-8476-1c10a89b51a0 |
| Severity | Functional defect: RDS Gateway unavailable through affected WAF path |

Summary:

The module originally registered only `RPC_IN_DATA` and `RPC_OUT_DATA`.
Microsoft RD Gateway clients use `RDG_IN_DATA` and `RDG_OUT_DATA`, so Apache
declined RD Gateway requests before module handling:

```text
declining due to bad method: RDG_OUT_DATA
```

Resolution in this fork:

- `RDG_IN_DATA` and `RDG_OUT_DATA` are registered via `ap_method_register()`.
- RDGHTTP methods are routed to an RDGHTTP-specific forwarding path.
- Existing RPC-HTTP behavior is preserved separately.

### RDGHTTP Treated Like RPC Tunnel Traffic

| Field | Detail |
| --- | --- |
| Investigated | June 2026 |
| Environment | Sophos XGS/SFOS 22.0.0 GA-Build411 lab |
| Impact | RD Gateway HTTP transport failed or reset through the WAF path |
| Status in this fork | Lab-fixed and validated with forced RDGHTTP/HTTP-extauth |

Summary:

Registering the RDG verbs alone was not enough. RDGHTTP is an HTTP tunnel
transport and should not be parsed as an RPC PDU stream. The lab fix added a
separate RDGHTTP forwarding path while leaving the original RPC handling intact.

## External Related Notes

### nDPI RPC_OUT_DATA Detection

An nDPI protocol-detection issue around `RPC_OUT_DATA` matching was observed
during the broader investigation. That issue is external to this Apache module
and is noted here only to avoid conflating DPI behavior with module behavior.

## References

- MS-TSGU specification:
  https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-tsgu
- MS-RPCH specification:
  https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rpch
- Apache bug 40029:
  https://issues.apache.org/bugzilla/show_bug.cgi?id=40029
