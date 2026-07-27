with open('c:/aniverse/lib/home_screen.dart', 'rb') as f:
    content = f.read()

old = b'top: 0,\r\n                    child: AnimatedHitaku(size: 520)'
new = b'top: 0,\r\n                    width: 540,\r\n                    child: AnimatedHitaku(size: 520)'

if old in content:
    content = content.replace(old, new)
    with open('c:/aniverse/lib/home_screen.dart', 'wb') as f:
        f.write(content)
    print('Fixed! Added width: 540 to AnimatedHitaku Positioned')
else:
    print('Pattern not found')
