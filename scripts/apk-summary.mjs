import { appendFile, readFile } from 'node:fs/promises';
let result;
try {
    result = JSON.parse(await readFile('reports/apk-validation.json', 'utf8'));
}
catch { }
const summary = `# نتيجة بناء دحروج لكويست\n\nالحالة: ${process.env.BUILD_RESULT}\n\nالمستودع: 3wasfnjd/Dahrooj-Quest\n\nالالتزام: ${process.env.GITHUB_SHA}\n\n${result ? `توقيع APK: تم التحقق\n\nالحجم: ${result.bytes} بايت\n\nSHA-256: \`${result.sha256}\`\n\n` : 'لم يُنتج APK مُتحقق منه. راجع أول خطوة فاشلة؛ لا توجد شهادة أو نتيجة بديلة.\n\n'}لم يتم اختبار هذه النسخة على جهاز Meta Quest حقيقي، لذلك لا يمكن اعتبارها جاهزة نهائيًا للنشر في المتجر.\n\nهذا المسار لا ينشر إلى Meta Horizon Store.\n`;
await appendFile(process.env.GITHUB_STEP_SUMMARY || 'reports/apk-summary.md', summary);
