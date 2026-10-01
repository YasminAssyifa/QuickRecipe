from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
output = root / 'dist' / 'QuickRecipe-UTS-source.zip'
output.parent.mkdir(exist_ok=True)
folders = ['lib', 'assets', 'android', 'ios', 'web', 'windows', 'macos', 'linux', 'test', 'test_driver', 'integration_test', 'tools', 'docs']
files = ['pubspec.yaml', 'pubspec.lock', 'README.md', 'analysis_options.yaml', '.gitignore', '.metadata', 'firebase.json', 'firestore.rules', 'splash.yaml']
excluded_parts = {'.git', '.gradle', '.dart_tool', 'build', '.idea', 'ephemeral', '__pycache__', '.symlinks'}
excluded_names = {'local.properties', 'key.properties', 'google-services-secret.json', '.env'}

def include(path):
    relative = path.relative_to(root)
    lower = path.name.lower()
    return path.is_file() and not excluded_parts.intersection(relative.parts) and path.name not in excluded_names and not lower.endswith(('.jks', '.keystore', '.p12', '.pem', '.pyc', '.log')) and 'service-account' not in lower and 'credentials' not in lower and not lower.startswith('.env')

with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for folder in folders:
        for path in (root / folder).rglob('*'):
            if include(path): archive.write(path, Path('quick_recipe') / path.relative_to(root))
    for name in files:
        path = root / name
        if include(path): archive.write(path, Path('quick_recipe') / name)
print(output)
