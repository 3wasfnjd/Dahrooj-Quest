import { execFileSync } from 'node:child_process';
import { readFile, mkdir, appendFile } from 'node:fs/promises';
for (const key of ['GH_TOKEN', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_PASSWORD', 'ANDROID_KEY_ALIAS', 'KEY_BACKUP_PASSWORD'])
    if (!process.env[key])
        throw new Error(`Missing ${key}. Configure through GitHub Secrets, never workflow inputs.`);
if (process.env.KEY_BACKUP_PASSWORD.length < 20)
    throw new Error('Use a strong backup password of at least 20 characters.');
const secrets = JSON.parse(execFileSync('gh', ['secret', 'list', '--repo', process.env.GH_REPO, '--json', 'name'], { encoding: 'utf8' }));
if (secrets.some(s => s.name === 'ANDROID_KEYSTORE_BASE64'))
    throw new Error('A release key already exists. Refusing to replace the permanent certificate.');
const path = process.env.RUNNER_TEMP + '/bootstrap.keystore';
execFileSync('keytool', ['-genkeypair', '-keystore', path, '-storetype', 'JKS', '-alias', process.env.ANDROID_KEY_ALIAS, '-keyalg', 'RSA', '-keysize', '4096', '-validity', '36500', '-dname', 'CN=Aboden Games, O=Aboden Games', '-storepass:env', 'ANDROID_KEYSTORE_PASSWORD', '-keypass:env', 'ANDROID_KEY_PASSWORD'], { stdio: ['ignore', 'ignore', 'pipe'] });
await mkdir('release', { recursive: true });
execFileSync('gpg', ['--batch', '--yes', '--pinentry-mode', 'loopback', '--passphrase-fd', '0', '--symmetric', '--cipher-algo', 'AES256', '--output', 'release/signing-backup.gpg', path], { input: process.env.KEY_BACKUP_PASSWORD, stdio: ['pipe', 'ignore', 'pipe'] });
const key = await readFile(path);
execFileSync('gh', ['secret', 'set', 'ANDROID_KEYSTORE_BASE64', '--repo', process.env.GH_REPO], { input: key.toString('base64'), stdio: ['pipe', 'ignore', 'pipe'] });
const out = execFileSync('keytool', ['-list', '-v', '-keystore', path, '-alias', process.env.ANDROID_KEY_ALIAS, '-storepass:env', 'ANDROID_KEYSTORE_PASSWORD'], { encoding: 'utf8' }), sha = out.match(/SHA256:\s*([A-Fa-f0-9:]+)/)?.[1];
if (!sha)
    throw new Error('Certificate fingerprint unavailable');
execFileSync('gh', ['variable', 'set', 'ANDROID_CERT_SHA256', '--repo', process.env.GH_REPO, '--body', sha]);
await appendFile(process.env.GITHUB_STEP_SUMMARY, `تم إنشاء شهادة دائمة وتخزينها في GitHub Secrets.\n\nبصمة الشهادة العامة: \`${sha}\`\n\nنزّل النسخة الاحتياطية المشفرة إلى مكانين آمنين قبل انتهاء صلاحية artifact. احتفظ بكلمة مرورها منفصلة. لا تغيّر الشهادة بعد النشر. احذف رمز SIGNING_ADMIN_TOKEN بعد الإعداد.\n`);
