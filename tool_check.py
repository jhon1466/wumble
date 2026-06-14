import os, re
ex = open('lib/core/localization/translations.dart', encoding='utf-8').read()
existing = set(re.findall(r"^\s*'([^']+)':", re.search(r'_en = \{(.*?)\n\};', ex, re.S).group(1), re.M))
pats = [re.compile(r"Text\(\s*'([^'\\$]{3,90})'"), re.compile(r'Text\(\s*"([^"\\$]{3,90})"')]
found = set()
for root, _, files in os.walk('lib'):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        if 'localization' in os.path.join(root, fn).replace('\\', '/'):
            continue
        s = open(os.path.join(root, fn), encoding='utf-8').read()
        for p in pats:
            for m in p.finditer(s):
                v = m.group(1)
                if re.search(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]', v) and v not in existing:
                    found.add(v)
print('Text() sin traducir (no interpolados):', len(found))
for x in sorted(found):
    print(' -', x)
