import json, os

log_path = r'C:\Users\User\.gemini\antigravity\brain\783ea738-494f-4148-86ba-574499578320\.system_generated\logs\overview.txt'
with open(log_path, 'r', encoding='utf-8', errors='replace') as f:
    raw = f.read()

lines = raw.split('\n')
all_replacements = []

for line in lines:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        if obj.get('source') == 'MODEL' and 'tool_calls' in obj:
            for tc in obj['tool_calls']:
                if tc['name'] in ('replace_file_content', 'multi_replace_file_content', 'write_to_file'):
                    args = tc.get('args', {})
                    target = str(args.get('TargetFile', ''))
                    if 'profile_screen' in target:
                        code = args.get('ReplacementContent', args.get('CodeContent', ''))
                        chunks = args.get('ReplacementChunks', [])
                        if code and len(str(code)) > 100:
                            all_replacements.append({
                                'step': obj['step_index'],
                                'time': obj.get('created_at',''),
                                'name': tc['name'],
                                'code_len': len(str(code)),
                                'code': str(code)
                            })
                        for chunk in chunks:
                            c = chunk.get('ReplacementContent','')
                            if c and len(str(c)) > 100:
                                all_replacements.append({
                                    'step': obj['step_index'],
                                    'time': obj.get('created_at',''),
                                    'name': 'chunk',
                                    'code_len': len(str(c)),
                                    'code': str(c)
                                })
    except Exception as e:
        pass

print(f'Found {len(all_replacements)} replacement blocks')
for r in all_replacements:
    print(f'  Step {r["step"]} ({r["time"]}): {r["name"]} - {r["code_len"]} chars')
    print(f'    Preview: {r["code"][:120]}')
    print()

# Save all code blocks
with open('lib/recovered_blocks.txt', 'w', encoding='utf-8') as out:
    for r in all_replacements:
        out.write(f'=== STEP {r["step"]} ({r["time"]}) {r["name"]} {r["code_len"]}chars ===\n')
        # Decode escaped newlines
        code = r['code'].replace('\\n', '\n').replace('\\t', '\t')
        out.write(code)
        out.write('\n\n')

print('Saved to lib/recovered_blocks.txt')
