# static-site

Terraform for the devopsblog.online static site:

- S3 origin bucket (private, OAC-only access).
- CloudFront distribution (HTTPS, HTTP/2, custom security headers).
- ACM certificate in `us-east-1` (CloudFront's required region).
- Route 53 hosted zone (NS delegated from GoDaddy — see below).

## Two-phase apply (first-time bootstrap)

The ACM certificate validates via DNS. DNS validation cannot succeed until the
Route 53 hosted zone is authoritative for `devopsblog.online`, which requires
the operator to update GoDaddy's NS records after the zone is created. Because
of this chicken-and-egg, the first apply is two-phase.

### Phase 1 — create the hosted zone, update the registrar

```bash
terraform -chdir=Infra/static-site init
terraform -chdir=Infra/static-site apply -target=aws_route53_zone.site
terraform -chdir=Infra/static-site output -raw route53_nameservers
```

Take the four nameservers from the output and paste them into GoDaddy's NS
record set for `devopsblog.online`. Allow 5–60 minutes for propagation.

Verify propagation before Phase 2:

```bash
dig NS devopsblog.online +short
# The four values should match the Route 53 nameservers exactly.
```

### Phase 2 — apply the rest

```bash
terraform -chdir=Infra/static-site apply
```

Runtime expectations:

- ACM DNS validation: usually under 5 minutes once the NS delegation is live.
- CloudFront distribution deployment: 3–10 minutes. This is the limiting step;
  the apply will appear to hang here. That's normal.
- Total first-apply: 5–15 minutes after NS propagation has completed.

After apply, `Application2/tooling/deploy.sh` can sync baked Frozen-Flask output
to the S3 origin and invalidate CloudFront in one shot.

## Deferred / known gaps

These were called out in the Pass 1 audit and deferred to a follow-up:

- **No branded 404 page.** Frozen-Flask does not bake a `/404.html`, so no
  `custom_error_response` is wired. Missing paths return the S3/CloudFront
  default 403. A future Flask route (e.g. `/404.html`) + a `custom_error_response`
  block can be added together.
- **No S3 access logging on the origin bucket** — kept off to avoid the
  recurring S3 storage cost for a first-ship.
- **No CloudFront access logging** — same rationale.
- **Cache-control header split for long-lived assets** — deferred; today all
  objects share the CachingOptimized managed policy.
- **Subresource integrity on Google Fonts** — deferred.
- **www/apex SEO canonical (redirect www -> apex or vice-versa)** — deferred;
  both hostnames currently serve the same content via CloudFront aliases.

## `prevent_destroy` map

The `prevent_destroy` lifecycle flag is scoped deliberately:

| Resource | `prevent_destroy` | Why |
|---|---|---|
| `aws_acm_certificate.site` | yes | Load-bearing viewer cert; replacement causes downtime. |
| `aws_route53_zone.site` | yes | Destroying invalidates the NS delegation; requires another registrar update + propagation wait. |
| `aws_s3_bucket.origin` | **no** | Contents are fully reproducible via `deploy.sh`. Versioning covers accidental object-level loss. |

## Security posture

- S3 origin bucket: private, public access blocked at every level, AES256 at
  rest, `BucketOwnerEnforced` ownership, `aws:SecureTransport = false` denied
  on the bucket policy (defence-in-depth — CloudFront already uses TLS).
- Bucket policy allows `s3:GetObject` ONLY from this specific CloudFront
  distribution ARN (OAC `AWS:SourceArn` condition).
- CloudFront serves with TLS 1.2+ (`TLSv1.2_2021`), HTTP redirected to HTTPS.
- Custom `aws_cloudfront_response_headers_policy` attaches HSTS (2y, preload),
  `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`,
  `Referrer-Policy: strict-origin-when-cross-origin`, and a CSP that permits
  Google Fonts + inline styles.
- CAA record restricts certificate issuance to Amazon only (no wildcards).

## Apply is operator-gated

Per `.claude/rules/infra.md`, `terraform apply` is never run by an agent
against a real AWS account. Agents write code and run `plan` at most; the
operator drives `apply`.
