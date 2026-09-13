#!/usr/bin/env python3
"""Check cognitive complexity of all functions in the given Python files.

Usage:
    python3 check_cognitive_complexity.py --max <threshold> <file_or_dir> ...

Exit code 0 if all functions are at or below <threshold>, 1 otherwise.
"""

import argparse
import ast
import glob
import os
import sys

from cognitive_complexity.api import get_cognitive_complexity


def _collect_files(paths: list[str]) -> list[str]:
    """Expand directories into .py files and return a sorted, unique list."""
    files: set[str] = set()
    for path in paths:
        if os.path.isdir(path):
            files.update(glob.glob(os.path.join(path, '**', '*.py'), recursive=True))
        elif path.endswith('.py'):
            files.add(path)
    return sorted(files)


def _check_file(filepath: str, threshold: int) -> list[tuple[str, str, int, int]]:
    """Return a list of (file, func_name, line, score) for violations."""
    with open(filepath, encoding='utf-8') as fh:
        tree = ast.parse(fh.read(), filename=filepath)

    violations: list[tuple[str, str, int, int]] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef | ast.AsyncFunctionDef):
            score = get_cognitive_complexity(node)
            if score > threshold:
                violations.append((filepath, node.name, node.lineno, score))
    return violations


def main() -> int:
    """Entry point."""
    parser = argparse.ArgumentParser(description='Cognitive complexity checker.')
    parser.add_argument(
        '--max',
        type=int,
        default=15,
        dest='threshold',
        help='Maximum allowed cognitive complexity (default: 15)',
    )
    parser.add_argument('paths', nargs='+', help='Files or directories to check')
    args = parser.parse_args()

    files = _collect_files(args.paths)
    all_violations: list[tuple[str, str, int, int]] = []
    for filepath in files:
        all_violations.extend(_check_file(filepath, args.threshold))

    if all_violations:
        for filepath, name, line, score in all_violations:
            print(f'{filepath}:{line} {name} - cognitive_complexity={score}')
        return 1

    print(f'All functions at or below threshold ({args.threshold}).')
    return 0


if __name__ == '__main__':
    sys.exit(main())
