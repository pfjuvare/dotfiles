#!/usr/bin/env python3
"""same-asset.py <dir-a> <dir-b>: exit 0 when two board asset dirs hold the same asset.

Used by test-push.sh to compare the live (pulled) version of an asset with the repo's. `weboard pull`
output isn't byte-identical to what the repo holds, so this ignores what pulling changes on its own:
- JSON (config.json): platform-only keys (globalid, tableGlobalid, thumbnail), key case
  (contenttype / contentType), and the order of lists of named entries (viewFilters come back sorted).
- Everything else (views, JS): whitespace and trailing commas (the pull reformats code). With
  $SAME_ASSET_PRETTIER (a prettier binary), JS is first reformatted on one wide line per statement on
  both sides, which also drops the parentheses prettier adds around wrapped `return` expressions.
Run with --why to print the first difference.
"""
import json
import os
import re
import subprocess
import sys

PRETTIER = os.environ.get('SAME_ASSET_PRETTIER')

PLATFORM_KEYS = {'globalid', 'tableglobalid', 'thumbnail'}


def canon(v):
    if isinstance(v, dict):
        return {k.lower(): canon(x) for k, x in v.items() if k.lower() not in PLATFORM_KEYS}
    if isinstance(v, list):
        items = [canon(x) for x in v]
        if items and all(isinstance(x, dict) and 'name' in x for x in items):
            items.sort(key=lambda x: json.dumps(x, sort_keys=True))
        return items
    return v


def norm_text(s):
    s = re.sub(r'\s+', '', s)
    return re.sub(r',(?=[}\])])', '', s)


def pretty(s):
    if not PRETTIER:
        return s
    try:
        r = subprocess.run([PRETTIER, '--stdin-filepath', 'x.js', '--print-width', '1000', '--trailing-comma', 'none'],
                           input=s, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return s
    return r.stdout if r.returncode == 0 else s


def same_file(a, b):
    try:
        x, y = open(a, encoding='utf-8', errors='replace').read(), open(b, encoding='utf-8', errors='replace').read()
    except OSError:
        return False
    if x == y:
        return True
    if a.endswith('.json'):
        try:
            return canon(json.loads(x)) == canon(json.loads(y))
        except ValueError:
            pass
    if norm_text(x) == norm_text(y):
        return True
    return a.endswith('.js') and norm_text(pretty(x)) == norm_text(pretty(y))


def files(d):
    out = {}
    for root, _, names in os.walk(d):
        for n in names:
            p = os.path.join(root, n)
            out[os.path.relpath(p, d)] = p
    return out


def main():
    args = [a for a in sys.argv[1:] if a != '--why']
    why = '--why' in sys.argv
    if len(args) != 2:
        sys.exit('usage: same-asset.py [--why] <dir-a> <dir-b>')
    fa, fb = files(args[0]), files(args[1])
    if fa.keys() != fb.keys():
        if why:
            print('files differ:', sorted(fa.keys() ^ fb.keys()))
        sys.exit(1)
    for rel in sorted(fa):
        if not same_file(fa[rel], fb[rel]):
            if why:
                print('differs:', rel)
            sys.exit(1)
    sys.exit(0)


if __name__ == '__main__':
    main()
