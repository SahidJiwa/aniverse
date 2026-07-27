import os, json

brain_root = r'C:\Users\User\.gemini\antigravity\brain'
all_codes = []

for conv_dir in sorted(os.listdir(brain_root)):
    log_file = os.path.join(brain_root, conv_dir, '.system_generated', 'logs', 'overview.txt')
    if not os.path.exists(log_file):
        continue
    size = os.path.getsize(log_file)
    with open(log_file, 'r', encoding='utf-8', errors='replace') as f:
        raw = f.read()
    
    if 'profile_screen' not in raw.lower():
        continue
    
    lines = raw.split('\n')
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
                            if code and len(str(code)) > 200:
                                all_codes.append({
                                    'conv': conv_dir[:8],
                                    'step': obj['step_index'],
                                    'time': obj.get('created_at',''),
                                    'code_len': len(str(code)),
                                    'code': str(code)
                                })
                            for chunk in chunks:
                                c = chunk.get('ReplacementContent','')
                                if c and len(str(c)) > 200:
                                    all_codes.append({
                                        'conv': conv_dir[:8],
                                        'step': obj['step_index'],
                                        'time': obj.get('created_at',''),
                                        'code_len': len(str(c)),
                                        'code': str(c)
                                    })
        except:
            pass

# Sort by time
all_codes.sort(key=lambda x: x['time'])
print(f'Found {len(all_codes)} code blocks')
total_chars = sum(r['code_len'] for r in all_codes)
print(f'Total code: {total_chars} chars')

# Save all in order
with open('lib/all_recovered.txt', 'w', encoding='utf-8') as out:
    for r in all_codes:
        out.write(f'=== CONV={r["conv"]} STEP={r["step"]} TIME={r["time"]} LEN={r["code_len"]} ===\n')
        code = r['code'].replace('\\n', '\n').replace('\\t', '\t').replace('\\"', '"')
        out.write(code)
        out.write('\n\n')

print('Saved to lib/all_recovered.txt')
for r in all_codes:
    print(f'  {r["conv"]} step={r["step"]} {r["code_len"]} chars  {r["time"][:10]}')
