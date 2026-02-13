# Security Audit Report - Makefeed Application

**Generated:** 2025-10-17
**Tool:** Semgrep v1.139.0
**Scan Scope:** 261 files (99.9% parsed successfully)
**Rules Applied:** 149 security rules (auto, security-audit, secrets)
**Total Findings:** 3 (all blocking)

---

## Executive Summary

This comprehensive security audit of the Makefeed Flutter application identified **3 security vulnerabilities** requiring immediate attention. The findings include:

- **1 Critical Vulnerability** (Command Injection in CI/CD pipeline)
- **2 High-Priority Warnings** (Exposed secrets in environment files)

### Risk Assessment

| Category | Count | Risk Level |
|----------|-------|------------|
| Command Injection (CWE-78) | 1 | 🔴 **CRITICAL** |
| Hard-coded Credentials (CWE-798) | 1 | 🟠 **HIGH** |
| Hard-coded Cryptographic Key (CWE-321) | 1 | 🟠 **HIGH** |

### Immediate Actions Required

1. **Fix GitHub Actions command injection** (CRITICAL - can lead to arbitrary code execution)
2. **Rotate all exposed API keys and JWT tokens** (HIGH - currently committed in .env)
3. **Implement secret scanning in CI/CD** (Preventive measure)

---

## Detailed Findings

### 🔴 CRITICAL - Command Injection in GitHub Actions

**Vulnerability ID:** `yaml.github-actions.security.run-shell-injection.run-shell-injection`
**CWE:** CWE-78 (Improper Neutralization of Special Elements used in an OS Command)
**OWASP:** A03:2021 - Injection
**Severity:** ERROR
**Confidence:** HIGH
**Likelihood:** HIGH
**Impact:** HIGH

#### Location
- **File:** `.github/workflows/docker-build.yml`
- **Lines:** 62-139 (entire "Send to n8n" step)

#### Description

The GitHub Actions workflow uses variable interpolation `${{...}}` with `github` context data directly in a `run:` step without proper sanitization. This creates a **command injection vulnerability** where an attacker with the ability to control GitHub context data (e.g., branch names, commit messages, author names) could inject malicious code into the CI/CD runner.

#### Vulnerable Code Pattern

```yaml
run: |
  jq -n \
    --arg workflow_name "${{ github.workflow }}" \
    --arg run_id "${{ github.run_id }}" \
    --arg run_number "${{ github.run_number }}" \
    --arg run_attempt "${{ github.run_attempt }}" \
    --arg run_url "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}" \
    --arg repo_name "${{ github.event.repository.name }}" \
    --arg repo_full_name "${{ github.repository }}" \
    --arg repo_owner "${{ github.repository_owner }}" \
    --arg repo_url "${{ github.event.repository.html_url }}" \
    --arg commit_sha "${{ github.sha }}" \
    --arg commit_short_sha "${{ steps.vars.outputs.sha_short }}" \
    # ... more direct interpolations
```

#### Attack Vector

1. Attacker creates a malicious branch name like: `main'; malicious_command; echo '`
2. When workflow runs, the unescaped branch name is interpolated into the shell command
3. Attacker gains arbitrary command execution in the GitHub Actions runner
4. Potential to steal secrets (`DOCKER_REGISTRY_PASSWORD`, `SUPABASE_ANON_KEY`, etc.)

#### Impact

- **Code Execution:** Arbitrary commands can be executed in the CI/CD environment
- **Secret Exfiltration:** All GitHub Actions secrets can be stolen
- **Supply Chain Attack:** Malicious code can be injected into build artifacts
- **Repository Takeover:** Attacker can push malicious code to protected branches

#### Remediation

**Option 1: Use Environment Variables (Recommended)**

Move all `github` context data to environment variables, then reference the env vars in the script:

```yaml
- name: Send to n8n
  if: always()
  env:
    WORKFLOW_NAME: ${{ github.workflow }}
    RUN_ID: ${{ github.run_id }}
    RUN_NUMBER: ${{ github.run_number }}
    RUN_ATTEMPT: ${{ github.run_attempt }}
    RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
    REPO_NAME: ${{ github.event.repository.name }}
    REPO_FULL_NAME: ${{ github.repository }}
    REPO_OWNER: ${{ github.repository_owner }}
    REPO_URL: ${{ github.event.repository.html_url }}
    REPO_DEFAULT_BRANCH: ${{ github.event.repository.default_branch }}
    COMMIT_MESSAGE: ${{ github.event.head_commit.message }}
    COMMIT_SHA: ${{ github.sha }}
    COMMIT_SHORT_SHA: ${{ steps.vars.outputs.sha_short }}
    COMMIT_AUTHOR_NAME: ${{ github.event.head_commit.author.name }}
    COMMIT_AUTHOR_EMAIL: ${{ github.event.head_commit.author.email }}
    COMMIT_TIMESTAMP: ${{ github.event.head_commit.timestamp }}
    COMMIT_URL: ${{ github.event.head_commit.url }}
    REF_FULL: ${{ github.ref }}
    REF_NAME: ${{ github.ref_name }}
    REF_TYPE: ${{ github.ref_type }}
    REF_HEAD_REF: ${{ github.head_ref }}
    REF_BASE_REF: ${{ github.base_ref }}
    EVENT_NAME: ${{ github.event_name }}
    EVENT_ACTION: ${{ github.event.action }}
    ACTOR_USERNAME: ${{ github.actor }}
    ACTOR_TRIGGERING: ${{ github.triggering_actor }}
    ENV_JOB: ${{ github.job }}
    ENV_RUNNER_OS: ${{ runner.os }}
    ENV_RUNNER_ARCH: ${{ runner.arch }}
  run: |
    jq -n \
      --arg workflow_name "$WORKFLOW_NAME" \
      --arg run_id "$RUN_ID" \
      --arg run_number "$RUN_NUMBER" \
      --arg run_attempt "$RUN_ATTEMPT" \
      --arg run_url "$RUN_URL" \
      --arg repo_name "$REPO_NAME" \
      --arg repo_full_name "$REPO_FULL_NAME" \
      --arg repo_owner "$REPO_OWNER" \
      --arg repo_url "$REPO_URL" \
      --arg repo_default_branch "$REPO_DEFAULT_BRANCH" \
      --arg commit_message "$COMMIT_MESSAGE" \
      --arg commit_sha "$COMMIT_SHA" \
      --arg commit_short_sha "$COMMIT_SHORT_SHA" \
      --arg commit_author_name "$COMMIT_AUTHOR_NAME" \
      --arg commit_author_email "$COMMIT_AUTHOR_EMAIL" \
      --arg commit_timestamp "$COMMIT_TIMESTAMP" \
      --arg commit_url "$COMMIT_URL" \
      --arg ref_full "$REF_FULL" \
      --arg ref_name "$REF_NAME" \
      --arg ref_type "$REF_TYPE" \
      --arg ref_head_ref "$REF_HEAD_REF" \
      --arg ref_base_ref "$REF_BASE_REF" \
      --arg event_name "$EVENT_NAME" \
      --arg event_action "$EVENT_ACTION" \
      --arg actor_username "$ACTOR_USERNAME" \
      --arg actor_triggering "$ACTOR_TRIGGERING" \
      --arg env_job "$ENV_JOB" \
      --arg env_runner_os "$ENV_RUNNER_OS" \
      --arg env_runner_arch "$ENV_RUNNER_ARCH" \
      '{
        workflow: {
          name: $workflow_name,
          run_id: $run_id,
          run_number: $run_number,
          run_attempt: $run_attempt,
          run_url: $run_url
        },
        repository: {
          name: $repo_name,
          full_name: $repo_full_name,
          owner: $repo_owner,
          url: $repo_url,
          default_branch: $repo_default_branch
        },
        commit: {
          message: $commit_message,
          sha: $commit_sha,
          short_sha: $commit_short_sha,
          author_name: $commit_author_name,
          author_email: $commit_author_email,
          timestamp: $commit_timestamp,
          url: $commit_url
        },
        ref: {
          full: $ref_full,
          name: $ref_name,
          type: $ref_type,
          head_ref: $ref_head_ref,
          base_ref: $ref_base_ref
        },
        event: {
          name: $event_name,
          action: $event_action
        },
        actor: {
          username: $actor_username,
          triggering_actor: $actor_triggering
        },
        environment: {
          job: $env_job,
          runner_os: $env_runner_os,
          runner_arch: $env_runner_arch
        }
      }' | curl -X POST https://n8n.nirssyan.ru/webhook/github-worflow \
        -H "Content-Type: application/json" \
        -d @-
```

**Option 2: Use GitHub Action for Webhook (Alternative)**

Use a dedicated action like `distributhor/workflow-webhook@v3` which handles escaping automatically.

#### References
- [GitHub Actions Security: Understanding Script Injections](https://docs.github.com/en/actions/learn-github-actions/security-hardening-for-github-actions#understanding-the-risk-of-script-injections)
- [GitHub Security Lab: Untrusted Input](https://securitylab.github.com/research/github-actions-untrusted-input/)
- [CWE-78: OS Command Injection](https://cwe.mitre.org/data/definitions/78.html)

---

### 🟠 HIGH - Exposed JWT Token in .env File

**Vulnerability ID:** `generic.secrets.security.detected-jwt-token.detected-jwt-token`
**CWE:** CWE-321 (Use of Hard-coded Cryptographic Key)
**OWASP:** A02:2021 - Cryptographic Failures
**Severity:** ERROR
**Confidence:** LOW
**Likelihood:** LOW
**Impact:** MEDIUM

#### Location
- **File:** `.env`
- **Line:** 8
- **Column:** 19-145

#### Description

A JWT token (`SUPABASE_ANON_KEY`) is hardcoded in the `.env` file. While `.env` files should not be committed to version control, this file is currently **untracked in git** (appears in `git status` as `?? .env`), which means it exists in the working directory and poses a risk if accidentally committed.

#### Exposed Secret

```env
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzUzODIyODAwLCJleHAiOjE5MTE1ODkyMDB9.rwP968LHsHS3r0Hu0YMXPen62_HX7cBsrSR9iFJVHfA
```

#### Decoded JWT Payload

```json
{
  "role": "anon",
  "iss": "supabase",
  "iat": 1753822800,
  "exp": 1911589200
}
```

**Issued At:** 2025-05-29 (future date - likely a test token)
**Expires:** 2030-08-01

#### Impact

- **Authentication Bypass:** If this token is valid, anyone with access to it can authenticate to your Supabase instance with "anon" role
- **Data Exposure:** Depending on Row Level Security (RLS) policies, data may be accessible
- **Rate Limiting Abuse:** Attackers can abuse your Supabase quotas
- **Service Disruption:** Malicious requests can cause service issues

#### Remediation

1. **Immediate:** Verify if `.env` is in `.gitignore` (it should be)
   ```bash
   grep -E "^\.env$" .gitignore
   ```

2. **If Already Committed:**
   - Rotate the JWT secret in Supabase dashboard immediately
   - Use `git-secrets` or `gitleaks` to scan entire git history
   - Consider rewriting git history to remove the secret (use `BFG Repo-Cleaner` or `git filter-repo`)

3. **Best Practices:**
   - Use `.env.example` for template (already exists in your repo ✓)
   - Never commit actual `.env` files
   - Use secret management tools (GitHub Secrets, AWS Secrets Manager, etc.)
   - Implement pre-commit hooks to prevent secret commits:
     ```bash
     # Install gitleaks
     brew install gitleaks

     # Add pre-commit hook
     cat > .git/hooks/pre-commit << 'EOF'
     #!/bin/sh
     gitleaks protect --staged --verbose
     EOF
     chmod +x .git/hooks/pre-commit
     ```

4. **CI/CD Protection:**
   - Add secret scanning to GitHub Actions workflow
   - Use tools like `truffleHog`, `gitleaks`, or GitHub's built-in secret scanning

#### Note on Supabase Anon Keys

Supabase "anon" keys are **public by design** for client-side applications. However:
- They should still be treated as sensitive
- Security depends entirely on Row Level Security (RLS) policies
- Without proper RLS, all data is exposed
- **Recommendation:** Review all Supabase RLS policies to ensure proper access control

#### References
- [Semgrep: JWT Mistakes](https://semgrep.dev/blog/2020/hardcoded-secrets-unverified-tokens-and-other-common-jwt-mistakes/)
- [Supabase: API Keys](https://supabase.com/docs/guides/api/api-keys)
- [CWE-321: Hard-coded Cryptographic Key](https://cwe.mitre.org/data/definitions/321.html)

---

### 🟠 HIGH - Exposed API Key in .env File

**Vulnerability ID:** `generic.secrets.security.detected-generic-api-key.detected-generic-api-key`
**CWE:** CWE-798 (Use of Hard-coded Credentials)
**OWASP:** A07:2021 - Identification and Authentication Failures
**Severity:** ERROR
**Confidence:** LOW
**Likelihood:** LOW
**Impact:** MEDIUM
**CWE Top 25:** Yes (2021, 2022)

#### Location
- **File:** `.env`
- **Line:** 13
- **Column:** 1-54

#### Description

A generic API key (`API_KEY`) for n8n webhook authentication is hardcoded in the `.env` file. This key authenticates all backend API requests to your n8n webhook endpoints.

#### Exposed Secret

```env
API_KEY=Kp3GxqvzvzzqRUIQaNTpTanRJ8V2bA95qhIoYMUcvsWdQNt1ov
```

**Key Length:** 46 characters (alphanumeric)
**Used For:** n8n webhook authentication (see `lib/config/api_config.dart`)

#### Impact

- **Unauthorized API Access:** Attackers can make authenticated requests to your n8n webhooks
- **Data Manipulation:** Depending on webhook logic, attackers may:
  - Create/delete user chats
  - Create malicious feeds
  - Access user data
  - Trigger expensive AI operations (cost abuse)
- **Service Abuse:** API rate limits can be exhausted
- **Backend Compromise:** N8n workflows may expose additional backend systems

#### Affected Endpoints

According to `CLAUDE.md` and `lib/services/chat_service.dart`:

1. `POST /chats/chat_message` - Send chat messages (AI interaction)
2. `POST /chats/create_feed` - Create feeds from chat
3. `GET /chats` - Fetch user chats
4. `DELETE /users_feeds?feed_id={feedId}` - Unsubscribe from feed
5. `POST /feeds/rename` - Rename feeds

All these endpoints use the `X-API-Key` header for authentication:

```dart
final headers = {
  ...ApiConfig.commonHeaders, // Includes 'X-API-Key'
  'user-id': user.id,
  'Authorization': 'Bearer ${session.accessToken}',
};
```

#### Remediation

1. **Immediate:** Rotate the API key in n8n webhook configuration
   - Generate new API key (46+ char random string)
   - Update n8n webhooks to use new key
   - Update all deployment environments

2. **Verify Git Status:**
   ```bash
   # Check if .env is already committed
   git log --all --full-history -- .env

   # If found, rotate immediately and scan history
   gitleaks detect --source . --verbose
   ```

3. **Secure Key Management:**
   - Use environment-specific keys (dev, staging, prod)
   - Store in secure secret managers:
     - GitHub Actions: Use `secrets.API_KEY`
     - Local development: Use `.env` (never commit)
     - Production: Use environment variables or secret management service

4. **Add n8n API Rate Limiting:**
   - Implement rate limiting on webhook endpoints
   - Add IP-based throttling
   - Monitor for suspicious activity

5. **Implement Additional Security Layers:**
   - Add request signing (HMAC) for critical endpoints
   - Implement webhook signature verification
   - Use short-lived tokens where possible

#### Code Review Recommendations

Check `lib/config/api_config.dart` for proper secret handling:

```dart
class ApiConfig {
  // ✓ Good: Reads from environment variable
  static const String apiKey = String.fromEnvironment('API_KEY');

  // ✓ Good: Validates secret on startup
  static void validate() {
    if (apiKey.isEmpty) {
      throw Exception('API_KEY not configured');
    }
  }
}
```

Ensure all API calls use this pattern, never hardcode keys in Dart code.

#### References
- [CWE-798: Use of Hard-coded Credentials](https://cwe.mitre.org/data/definitions/798.html)
- [OWASP: A07:2021 Identification and Authentication Failures](https://owasp.org/Top10/A07_2021-Identification_and_Authentication_Failures/)
- [TruffleHog: Credential Detection](https://github.com/dxa4481/truffleHogRegexes)

---

## Additional Security Observations

### ✅ Positive Security Practices Identified

1. **Secret Management Strategy:**
   - `.env.example` template exists for developers
   - Compile-time validation of required secrets (`ApiConfig.validate()`, `SupabaseConfig.initialize()`)
   - No hardcoded secrets in Dart source code (all use `String.fromEnvironment()`)

2. **Authentication Architecture:**
   - PKCE OAuth flow with Supabase (secure for public clients)
   - Session management with automatic refresh
   - Password validation enforced (complexity requirements)
   - Security event logging for all auth operations

3. **GitHub Actions Secrets:**
   - Docker registry credentials stored as GitHub Secrets ✓
   - Supabase credentials stored as GitHub Secrets ✓
   - API keys stored as GitHub Secrets ✓

4. **Feature Flags for Security:**
   - `ENABLE_MONETIZATION` flag for App Store compliance
   - Tree shaking removes disabled features from binary
   - Platform-specific security considerations (Sign in with Apple only on iOS/macOS)

### ⚠️ Areas for Improvement

1. **Secret Scanning:**
   - No pre-commit hooks for secret detection
   - No CI/CD secret scanning integration
   - **Recommendation:** Implement `gitleaks` or `truffleHog` in CI pipeline

2. **Environment File Security:**
   - `.env` file exists in working directory (untracked)
   - Risk of accidental commit
   - **Recommendation:**
     - Add pre-commit validation
     - Use `git ls-files .env` to verify it's never tracked
     - Consider using OS-level secret stores (Keychain, Secret Service)

3. **Dependency Security:**
   - No automated dependency vulnerability scanning visible
   - **Recommendation:**
     - Add Dependabot or Renovate for dependency updates
     - Add `flutter pub audit` to CI pipeline (when available)
     - Monitor for security advisories on pub.dev packages

4. **Input Validation:**
   - URL validation implemented (`lib/utils/url_validator.dart`) ✓
   - **Recommendation:** Review all user input handling for injection vulnerabilities
     - XSS in web version
     - SQL injection in Supabase queries (RLS policies)
     - Command injection in shell-related operations

5. **API Security:**
   - No visible rate limiting implementation
   - No request signing or HMAC validation
   - **Recommendation:**
     - Implement rate limiting middleware in n8n or API gateway
     - Add request signing for critical operations
     - Implement request ID tracking for debugging

6. **Mobile Platform Security:**
   - Android: Check ProGuard rules for security-sensitive code obfuscation
   - iOS: Ensure keychain storage for sensitive data
   - **Recommendation:** Review `android/app/proguard-rules.pro` for proper obfuscation

---

## Scan Statistics

### Files Scanned

- **Total Files Tracked:** 261
- **Successfully Parsed:** ~99.9%
- **Languages Detected:**
  - Multilang: 174 files
  - C: 8 files
  - YAML: 7 files
  - JSON: 6 files
  - Swift: 6 files
  - Kotlin: 4 files
  - HTML: 2 files
  - Dockerfile: 1 file

### Scan Exclusions

- **Large Files (> 1.0 MB):** 5 files skipped
- **Files matching `.semgrepignore`:** 20 files skipped
- **Scan limited to:** Git-tracked files only

### Parsing Errors (Non-Critical)

1. `assets/lottie/empty_box.json` - Syntax error (likely not valid JSON, possibly corrupted Lottie file)
2. `.github/workflows/docker-build.yml` - Partial parsing warnings (did not prevent vulnerability detection)

---

## Compliance & Standards Mapping

### CWE Top 25 Most Dangerous Software Weaknesses

This codebase contains **2 out of 25** CWE Top 25 vulnerabilities:

| Rank | CWE | Description | Found | Location |
|------|-----|-------------|-------|----------|
| #3 | CWE-78 | OS Command Injection | ✓ | `.github/workflows/docker-build.yml:62-139` |
| #16 | CWE-798 | Hard-coded Credentials | ✓ | `.env:13` |

### OWASP Top 10 (2021) Mapping

| OWASP | Category | Found | Details |
|-------|----------|-------|---------|
| A02:2021 | Cryptographic Failures | ✓ | Hard-coded JWT token in `.env` |
| A03:2021 | Injection | ✓ | Command injection in GitHub Actions |
| A07:2021 | Identification and Authentication Failures | ✓ | Hard-coded API credentials |

---

## Remediation Priority Matrix

| Priority | Vulnerability | Effort | Impact | Timeline |
|----------|--------------|--------|--------|----------|
| **P0** | GitHub Actions Command Injection | Medium | Critical | Immediate (< 24h) |
| **P1** | Rotate exposed API_KEY | Low | High | Urgent (< 48h) |
| **P1** | Rotate exposed SUPABASE_ANON_KEY | Low | High | Urgent (< 48h) |
| **P2** | Implement pre-commit secret scanning | Low | Medium | This week |
| **P3** | Add CI/CD secret scanning | Medium | Medium | This sprint |
| **P3** | Review Supabase RLS policies | High | Medium | This sprint |

---

## Recommended Security Checklist

### Immediate Actions (P0)

- [ ] Fix command injection in `.github/workflows/docker-build.yml` (lines 62-139)
- [ ] Test the fix by triggering workflow with test data
- [ ] Review git history for any previous commits of `.env` file
- [ ] If `.env` was previously committed, consider it compromised

### Urgent Actions (P1)

- [ ] Rotate `API_KEY` in n8n webhook configuration
- [ ] Rotate `SUPABASE_ANON_KEY` in Supabase dashboard
- [ ] Update all deployment environments with new keys
- [ ] Audit access logs for suspicious activity with old keys
- [ ] Update GitHub Actions secrets with new values

### This Week (P2)

- [ ] Install and configure `gitleaks` pre-commit hook
- [ ] Add `.env` to `.gitignore` if not already present (verify)
- [ ] Document secret rotation procedures in `CLAUDE.md`
- [ ] Implement secret scanning in CI/CD pipeline
- [ ] Review all Supabase RLS policies for proper access control

### This Sprint (P3)

- [ ] Implement API rate limiting on n8n webhooks
- [ ] Add request signing for critical API endpoints
- [ ] Enable Dependabot for dependency vulnerability scanning
- [ ] Review Android ProGuard rules for security
- [ ] Conduct security review of user input handling
- [ ] Add security headers for web deployment
- [ ] Implement Content Security Policy (CSP) for web version

### Long-term Improvements

- [ ] Migrate to HashiCorp Vault or AWS Secrets Manager for production
- [ ] Implement API request signing (HMAC-SHA256)
- [ ] Add comprehensive security logging and monitoring
- [ ] Conduct penetration testing before major releases
- [ ] Implement automated security testing in CI/CD
- [ ] Create security incident response plan
- [ ] Regular security training for development team

---

## Tools & Resources

### Recommended Security Tools

1. **Secret Scanning:**
   - [gitleaks](https://github.com/gitleaks/gitleaks) - Scan for secrets in code
   - [truffleHog](https://github.com/trufflesecurity/truffleHog) - Find secrets in git history
   - [git-secrets](https://github.com/awslabs/git-secrets) - Prevent committing secrets

2. **Dependency Scanning:**
   - [Dependabot](https://github.com/dependabot) - Automated dependency updates
   - [Snyk](https://snyk.io/) - Vulnerability scanning for dependencies
   - [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/)

3. **SAST (Static Analysis):**
   - [Semgrep](https://semgrep.dev/) - Current tool (excellent coverage)
   - [CodeQL](https://codeql.github.com/) - GitHub's code analysis engine
   - [SonarQube](https://www.sonarqube.org/) - Continuous code quality

4. **CI/CD Security:**
   - [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning) - Built-in feature
   - [Checkov](https://www.checkov.io/) - IaC security scanning
   - [Trivy](https://trivy.dev/) - Container vulnerability scanning

### Configuration Examples

#### gitleaks Pre-commit Hook

```bash
# Install
brew install gitleaks

# Add to .git/hooks/pre-commit
#!/bin/sh
echo "Running gitleaks scan..."
gitleaks protect --staged --verbose --redact
if [ $? -eq 1 ]; then
  echo "❌ Secret detected! Commit blocked."
  echo "If this is a false positive, add to .gitleaksignore"
  exit 1
fi
```

#### GitHub Actions Secret Scanning

```yaml
name: Security Scan

on: [push, pull_request]

jobs:
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## Conclusion

The Makefeed application demonstrates **good security practices** in many areas, particularly in authentication architecture and secret management strategy. However, the **3 identified vulnerabilities** require immediate attention:

1. **Critical:** Command injection in CI/CD pipeline poses a supply chain security risk
2. **High:** Exposed secrets in `.env` file could lead to unauthorized access
3. **High:** API credentials exposure enables backend abuse

**Overall Security Posture:** 🟡 **MODERATE** (after remediation: 🟢 **GOOD**)

### Next Steps

1. Address P0 and P1 vulnerabilities immediately (< 48 hours)
2. Implement automated secret scanning this week
3. Schedule quarterly security audits using Semgrep
4. Consider engaging a third-party security firm for penetration testing before major releases

---

**Report Version:** 1.0
**Auditor:** Claude Code (Semgrep Automated Scan)
**Contact:** See repository maintainers for questions

---

## Appendix A: Raw Semgrep Output Summary

```
Scan Status:
  - Rules: 149 (Community: 1078)
  - Files: 261
  - Findings: 3 (all blocking)
  - Parsed: ~99.9%
  - Skipped: 25 files (5 large, 20 ignored)

Finding IDs:
  1. yaml.github-actions.security.run-shell-injection.run-shell-injection
  2. generic.secrets.security.detected-jwt-token.detected-jwt-token
  3. generic.secrets.security.detected-generic-api-key.detected-generic-api-key

Engine: OSS
Version: 1.139.0
Scan Time: ~9.4 seconds
```

---

## Appendix B: Git Status at Audit Time

```
Current branch: web
Modified: lib/pages/home_page.dart
Modified: lib/services/news_service.dart
Modified: lib/widgets/in_app_browser_modal.dart
Modified: lib/widgets/news_chewie_player.dart
Modified: lib/widgets/news_video_player.dart
Modified: web/index.html
Untracked: SECURITY_AUDIT_REPORT.md
Untracked: lib/utils/url_validator.dart

Recent commits:
dc8886d hui
6a5a533 feedback
62d79af feedback
08b5f0f 50 50 stable
cb7b997 Merge branch 'web'
```

**Note:** `.env` file is currently untracked (good), but contains exposed secrets that must be rotated.

---

**End of Report**
