import os, re, subprocess, sys, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
NAME = 'LifeOnAzeroth_Market'
ADDON = os.path.join(HERE, NAME)
APP = os.path.join(HERE, 'companion')
DIST = os.path.join(HERE, 'dist')


def csc():
    win = os.environ.get('WINDIR', r'C:\Windows')
    for fw in ('Framework64', 'Framework'):
        p = os.path.join(win, 'Microsoft.NET', fw, 'v4.0.30319', 'csc.exe')
        if os.path.exists(p):
            return p
    sys.exit('csc.exe not found: the .NET Framework 4 compiler ships with Windows.')


def version():
    toc = open(os.path.join(ADDON, NAME + '.toc'), encoding='utf8').read()
    return re.search(r'^## Version:\s*(\S+)', toc, re.M).group(1)


def build_app():
    out = os.path.join(DIST, 'LifeOnAzerothCompanion.exe')
    res = ['/resource:%s,app.ico' % os.path.join(APP, 'app.ico'), '/resource:%s,logo96.png' % os.path.join(APP, 'logo96.png')]
    for f in sorted(os.listdir(ADDON)):
        res.append('/resource:%s,addon/%s' % (os.path.join(ADDON, f), f))
    cmd = [csc(), '/nologo', '/target:winexe', '/optimize+', '/platform:anycpu', '/out:' + out,
           '/win32icon:' + os.path.join(APP, 'app.ico'), '/win32manifest:' + os.path.join(APP, 'app.manifest'),
           '/r:System.dll', '/r:System.Core.dll', '/r:System.Drawing.dll', '/r:System.Windows.Forms.dll', '/r:System.Web.Extensions.dll',
           '/nowarn:0108'] + res + [os.path.join(APP, 'Program.cs'), os.path.join(APP, 'Sync.cs')]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stdout + r.stderr)
    return out


def build_zip(ver):
    out = os.path.join(DIST, '%s-%s.zip' % (NAME, ver))
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for f in sorted(os.listdir(ADDON)):
            z.write(os.path.join(ADDON, f), NAME + '/' + f)
    return out


if __name__ == '__main__':
    os.makedirs(DIST, exist_ok=True)
    ver = version()
    for p in (build_app(), build_zip(ver)):
        print('%s  %d KB' % (os.path.relpath(p, HERE), os.path.getsize(p) // 1024))
