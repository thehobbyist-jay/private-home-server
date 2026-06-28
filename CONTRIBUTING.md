CONTRIBUTING

Please read AGENTS.md for the full agent and workspace policies: see AGENTS.md in the repository root.

Quick summary

- Commit messages: follow Conventional Commits (e.g. feat(scope): short description).
- Branching: reuse feature branches for related changes; create new branches only for large or independent work.
- Code changes to protected branches (main) must go through a PR and an authorized reviewer.

Secrets policy

- Do NOT commit secrets (API keys, passwords, private keys, tokens, credentials) to the repository.
- Store secrets in environment variables, secret managers (GitHub Secrets, Vault, etc.), or encrypted stores.
- If you discover committed secrets, immediately notify the maintainers and rotate the credentials.

What this change did

- Removed tracked local secret files from the repository and added automated secret scanning to CI.
- If you previously committed secrets, rotating those credentials is required; removing files from the repository does not remove them from Git history.

How to add secrets locally

- Create a local .env (ignored by Git) or use your secret manager; do not commit .env or credentials files.
- Add configuration examples in a .env.example file with placeholder values.

Reporting a leak

- Create an issue and tag @maintainers (or contact the listed maintainer) with details. Do not paste the secret in the issue; instead, indicate the file path and commit hash.

Further enforcement

- This repository now includes a CI secret-scan workflow that runs on pushes and pull requests. Keep your commits clean to avoid blocked PRs.

Thanks for helping keep secrets out of version control.
