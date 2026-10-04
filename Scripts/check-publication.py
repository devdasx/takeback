#!/usr/bin/env python3
"""Focused tracked-file hygiene and local Markdown link checks; no secret values printed."""
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote

root = Path(__file__).resolve().parents[1]
paths = [Path(p) for p in subprocess.check_output(
    ['git', 'ls-files', '-z'], cwd=root).decode().split('\0') if p]
errors = []
patterns = [
    ('private key container', re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')),
    ('GitHub token', re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})\b')),
    ('AWS access key', re.compile(r'\bAKIA[A-Z0-9]{16}\b')),
    ('local home path', re.compile('/' + r'Users/[^/\s]+/')),
    ('local volume path', re.compile('/' + r'Volumes/[^\n"\']+')),
    ('personal signing team', re.compile(r'DEVELOPMENT_TEAM\s*[=:]\s*[A-Z0-9]{10}')),
]
tracked = set(paths)
if not paths:
    errors.append('No tracked files: stage the publication files first.')
for relative in paths:
    path = root / relative
    if any(p in {'Verification', 'Docs', 'xcuserdata', '__pycache__'} for p in relative.parts) or path.name.startswith('._'):
        errors.append(f'{relative}: local-only file tracked')
    if path.suffix.lower() in {'.p12', '.p8', '.pem', '.mobileprovision', '.ipa', '.xcuserstate'}:
        errors.append(f'{relative}: generated or credential file tracked')
    if path.stat().st_size > 25 * 1024 * 1024:
        errors.append(f'{relative}: exceeds publication size budget')
    try:
        text = path.read_text(encoding='utf-8')
    except (UnicodeDecodeError, ValueError):
        continue
    for label, pattern in patterns:
        if pattern.search(text):
            errors.append(f'{relative}: {label}')
    if path.suffix.lower() != '.md':
        continue
    links = re.findall(r'\]\(([^\s)]+)(?:\s+"[^"]*")?\)', text)
    links += re.findall(r'(?:src|href)="([^"]+)"', text)
    for link in links:
        if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', link) or link.startswith('#'):
            continue
        target = (path.parent / unquote(link.split('#')[0])).resolve()
        if not target.exists():
            errors.append(f'{relative}: missing local link {link}')
        elif target.is_file():
            try:
                dest = target.relative_to(root.resolve())
            except ValueError:
                errors.append(f'{relative}: link outside repository')
                continue
            if dest not in tracked:
                errors.append(f'{relative}: link points to untracked file {dest}')
for name in ('README.md', 'LICENSE', 'SECURITY.md', 'CONTRIBUTING.md', 'THIRD_PARTY_NOTICES.md'):
    if Path(name) not in tracked:
        errors.append(f'{name}: required publication file missing')
if errors:
    print('\n'.join(errors))
    sys.exit(1)
print(f'Publication checks passed for {len(paths)} tracked files. No matching credential containers, personal paths, or broken local file links.')
