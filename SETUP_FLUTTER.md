# Add to PowerShell profile for persistent Flutter access

# Method 1: Temp (current session only)
$env:PATH = "D:\flutter\bin;$env:PATH"

# Method 2: Permanent - run once in admin PowerShell:
# [Environment]::SetEnvironmentVariable("PATH", "D:\flutter\bin;$env:PATH", "Machine")

# Then use:
# flutter pub get
# flutter run
# flutter test