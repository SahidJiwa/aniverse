import json

with open(r'C:\Users\User\.gemini\antigravity\brain\8085e731-237e-4889-9e96-53f43feb7842\.system_generated\logs\overview.txt', 'r', encoding='utf-8', errors='replace') as f:
    log = f.read()

for line in log.split('\n'):
    if not line.strip():
        continue
    try:
        obj = json.loads(line)
        if obj.get('step_index') in [520, 521, 522, 523, 524, 525, 526, 527]:
            print(f"=== Step {obj.get('step_index')} ===")
            print(obj.get('content', ''))
            for tc in obj.get('tool_calls', []):
                print(f"  Tool: {tc.get('name')} -> {tc.get('args')}")
    except:
        pass
