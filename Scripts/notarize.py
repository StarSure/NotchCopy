#!/usr/bin/env python3
"""Developer ID signing and notarization using a local Keychain profile.

No Apple password, API private key, or signing key is accepted by this script.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


class NotarizationError(RuntimeError):
    pass


def run(args, *, env=None, check=True):
    result = subprocess.run([str(x) for x in args], text=True, capture_output=True, env=env)
    if check and result.returncode:
        raise NotarizationError(f"Command failed: {args[0]} {args[1] if len(args) > 1 else ''}\n{(result.stderr or result.stdout).strip()[-2000:]}")
    return result


def save_json(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    os.replace(temporary, path)


def validate_signature(report):
    lines = report.splitlines()
    developer_id = any(line.startswith('Authority=Developer ID Application:') for line in lines)
    team = re.search(r'^TeamIdentifier=[A-Z0-9]{10}$', report, re.MULTILINE)
    runtime = any(line.startswith('CodeDirectory ') and '(runtime)' in line for line in lines)
    timestamp = any(line.startswith('Timestamp=') and line.partition('=')[2].strip().lower()
                    not in ('', 'none', 'not set') for line in lines)
    if not (developer_id and team and runtime and timestamp) or 'Signature=adhoc' in report:
        raise NotarizationError('需要 Developer ID Application 正式签名、Hardened Runtime 和安全时间戳。')


def require_accepted(payload):
    status = payload.get('status', 'Unknown')
    if status != 'Accepted':
        raise NotarizationError(f'Apple 公证状态为 {status}，未生成可发布安装包。')


def complete_accepted(app, output, version, runner=run):
    """Do not produce an archive until all ticket and Gatekeeper checks pass."""
    runner(['xcrun', 'stapler', 'staple', app])
    runner(['xcrun', 'stapler', 'validate', app])
    runner(['codesign', '--verify', '--strict', app])
    runner(['spctl', '--assess', '--type', 'execute', '--verbose=2', app])
    archive = output / f'NotchCopy-v{version}-universal-notarized.zip'
    runner(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', app, archive])
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / 'SHA256SUMS.txt').write_text(f'{digest}  {archive.name}\n')
    return archive


def notarize(identity, profile, *, resume=False, timeout='15m', root=ROOT, runner=run):
    version = (root / 'VERSION').read_text().strip()
    output = root / 'dist' / 'notarized' / f'v{version}'
    output.mkdir(parents=True, exist_ok=True)
    state_file = output / 'notarization.json'
    app = output / 'NotchCopy.app'
    state = json.loads(state_file.read_text()) if state_file.exists() else None

    if resume:
        if not state or not state.get('id') or not app.is_dir():
            raise NotarizationError('没有可恢复的公证提交，请先正常提交。')
        if state['version'] != version:
            raise NotarizationError('VERSION 与待恢复提交不一致。')
        binary = app / 'Contents' / 'MacOS' / 'NotchCopy'
        if hashlib.sha256(binary.read_bytes()).hexdigest() != state['binary_sha256']:
            raise NotarizationError('待恢复的应用已变化，不能复用原提交。')
    else:
        if state and state.get('status') == 'Accepted':
            raise NotarizationError('这个版本已经公证完成；更新发布请先递增 VERSION。')
        if state and state.get('id') and state.get('status') not in ('Invalid', 'Rejected'):
            raise NotarizationError('已有提交正在处理，请使用 --resume，避免重复提交。')
        if not identity or not identity.startswith('Developer ID Application:'):
            raise NotarizationError('请用 --identity 指定 Developer ID Application 证书名称。')
        identities = runner(['security', 'find-identity', '-v', '-p', 'codesigning']).stdout
        if f'"{identity}"' not in identities:
            raise NotarizationError('本机未找到匹配的有效 Developer ID Application 签名身份。')
        print('构建并使用 Developer ID 签名…', flush=True)
        environment = dict(os.environ, CODESIGN_IDENTITY=identity)
        runner([root / 'Scripts' / 'build.sh', '--universal'], env=environment)
        if app.exists():
            shutil.rmtree(app)
        shutil.copytree(root / 'dist' / 'NotchCopy.app', app)
        report = runner(['codesign', '-dv', '--verbose=4', app]).stderr
        validate_signature(report)
        unsigned_ticket_zip = output / 'submission.zip'
        runner(['ditto', '-c', '-k', '--keepParent', app, unsigned_ticket_zip])
        print('上传 Apple 公证服务…', flush=True)
        response = runner(['xcrun', 'notarytool', 'submit', unsigned_ticket_zip,
                           '--keychain-profile', profile, '--output-format', 'json'])
        submitted = json.loads(response.stdout)
        if not submitted.get('id'):
            raise NotarizationError('Apple 未返回提交 ID，未生成发布包。')
        binary = app / 'Contents' / 'MacOS' / 'NotchCopy'
        state = dict(id=submitted['id'], version=version, status='Submitted',
                     binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest())
        save_json(state_file, state)

    submission = state['id']
    print(f'Apple 提交 ID：{submission}，等待处理…', flush=True)
    response = runner(['xcrun', 'notarytool', 'wait', submission, '--keychain-profile', profile,
                       '--timeout', timeout, '--output-format', 'json'], check=False)
    try:
        payload = json.loads(response.stdout)
    except (ValueError, TypeError):
        raise NotarizationError(f'暂未取得最终结果。提交 ID 已保存，可稍后使用 --resume：{submission}')
    state['status'] = payload.get('status', 'In Progress')
    save_json(state_file, state)
    if state['status'] in ('Accepted', 'Invalid', 'Rejected'):
        runner(['xcrun', 'notarytool', 'log', submission, '--keychain-profile', profile,
                output / 'apple-notary-log.json'])
    require_accepted(payload)
    archive = complete_accepted(app, output, version, runner)
    state['archive'] = archive.name
    save_json(state_file, state)
    print(f'公证及 Gatekeeper 验证通过：{archive}', flush=True)
    return archive


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--identity', help='完整的 Developer ID Application 证书名称')
    parser.add_argument('--profile', default='NotchCopy-Notary', help='本机 Keychain 中的 notarytool profile 名称')
    parser.add_argument('--resume', action='store_true', help='继续等待已有提交，不重新上传')
    parser.add_argument('--timeout', default='15m')
    parser.add_argument('--plan', action='store_true', help='只展示流程，不签名、联网或提交')
    args = parser.parse_args()
    if args.plan:
        print('Developer ID 签名 → 验证签名 → 提交 Apple → 仅 Accepted 后附加票据 → stapler/Gatekeeper 验收 → 重新打包 ZIP 与 SHA-256')
        return
    try:
        notarize(args.identity, args.profile, resume=args.resume, timeout=args.timeout)
    except (NotarizationError, OSError, ValueError) as error:
        print(f'公证未完成：{error}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
