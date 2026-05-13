# Security Policy

## Reporting a vulnerability

If you believe you have found a security vulnerability in this repository, please report it privately so we can fix it before it becomes public.

**Do not** open a public GitHub issue for security problems.

Instead, email **security@purchasely.com** with:

- A description of the issue
- Steps to reproduce
- Affected files or commands
- Suggested fix, if you have one

We aim to acknowledge security reports within **3 business days** and to release a fix or mitigation within **30 days** for confirmed issues.

## Scope

This repository contains AI prompts, documentation, and configuration templates — no executable runtime code that handles end-user data. The most relevant security concerns are:

- **Prompt injection** in skills or reference files that could mislead an AI assistant
- **Credential leakage** in example code (we use `YOUR_API_KEY` placeholders — please report any committed real keys)
- **Malicious install script behavior** in `install.sh`
- **Supply-chain risks** if the plugin is installed via the Claude Code marketplace

For vulnerabilities in the Purchasely SDK itself (iOS, Android, React Native, Flutter, Cordova) or the Purchasely backend, please contact security@purchasely.com directly.

## Responsible disclosure

We follow coordinated disclosure: please give us reasonable time to remediate before publishing details. We will credit you in the changelog if you wish.
