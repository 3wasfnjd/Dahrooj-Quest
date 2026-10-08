# أدلة GitHub Actions

هذه ملفات فعلية مستخرجة من Artifacts التشغيل على الشفرة `6c592f1f524983a6969b30d1079ecc633b078b20`، وليست نسخًا من نتائج الحاوية المحلية. طابقت بصمتا أرشيفَي تقارير Web وXR البصمتين اللتين أعادهما GitHub قبل الاستخراج.

- `actions.json`: روابط التشغيل وحالته ومعرّفات Artifacts وأحجامها وبصماتها وعائق النشر.
- `unit-tests.xml`: 25 اختبار وحدة ناجحًا من Web Build.
- `xr-tests.xml`: 3 اختبارات IWER ناجحة؛ تفعيل الأنماط ليس إثبات إكمال كل تحدياتها على جهاز.
- `production-tests.json`: 8 فحوص ناجحة تشمل CSP وoffline وغياب IWER/CDN؛ 113 ملفًا في cache.
- `bundle-size.json` و`bundled-modules.json`: حجم ناتج الإنتاج ومدخلاته الفعلية.
- `mode-resources.json` و`simulator-performance.json`: قياسات المحاكي على خادم GitHub بالرسم البرمجي؛ لا تمثل أداء Quest.

تقارير HTML واللقطات الكاملة متاحة في Artifact اختبار XR المرتبط داخل `actions.json`. لم ينتج APK، ولم يحدث اختبار نظارة، ولم ينجح نشر HTTPS بسبب غياب APP_ORIGIN. ملفات `../` الأقدم تخص اختبار الحاوية المحلية الموثق منفصلًا.
