# Secrets and the trust boundary

Always-on. Owns the `/security-review` trigger; `CLAUDE.md` and `ship` point here. Logging rules
are `code.md`'s.

## When `/security-review` runs

Before the PR, when the branch:

- touches authentication, authorization, secrets, keys or cryptography;
- builds a path, URL, shell command or query from input the code did not write;
- parses, deserializes or renders anything a user or a network supplied;
- sends data to a destination it did not reach before;
- adds or upgrades a dependency.

Not on every branch — a check that runs on everything gets skipped on everything. Fix each finding
or decline it in the PR body; "reviewed, nothing found" is one line, silence is not acceptable.

## Secrets

- **No secret in any repo, whatever its visibility.** Private repos may hold confidential working
  material, never credentials or personal data. Visibility is not a control.
- **Never commit** a credential, token, key, connection string or `.env` file, nor paste one into
  a commit message, PR body, issue, comment or log line. When quoting a request, config dump or
  stack trace, remove the secret — don't truncate it.
- **Report a secret found already committed at once.** It needs rotating; deleting the line does
  not un-publish it.

## What may leave the machine

- Source, logs and diagnostics go only to the repo's own remote and the project's own tooling.
  Any other destination is my decision; public paste and gist services are never one.
- **My email address is for authorship and attribution only** — never in a request header, URL,
  payload or third-party service.

## Data that isn't yours

- **Production data never comes to your machine** — no dump, no scratch CSV, no fixture built from
  a real export. Reproduce from a synthetic case with the same shape.
- **Storing personal data is a decision about its purpose and lifetime.** Keeping a field "just in
  case", or because nothing deletes it, counts — say so in the PR when a change starts holding one.

## Sensitive targets

- **A host, namespace, bucket or container with `prod` or `production` as a whole word in its name
  is sensitive.** Confirm before every touch, regardless of what was approved earlier.
