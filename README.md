# DebugURLSession

This project, when enabled, prints every `-[NSURLSession dataTaskWithRequest:completionHandler:]` call made. This includes any imported frameworks.

Everything.

## Usage

Due to the serious privacy consequences I advise using this round about way use the code:

1. Add `DebugURLSession.m` to your project
2. Create a file `/Users/Shared/«your project».xcconfig` and add, but do **NOT** copy into your project
2. Add `GCC_PREPROCESSOR_DEFINITIONS="ENABLE_URLSESSION_DEBUGGING=1"` to `/Users/Shared/«your project».xcconfig`.
3. Add `#include? "/Users/Shared/«your project».xcconfig"` to your project config files

This will result in DebugURLSession only being enabled on your machine but never in your CI. It will never make it to the AppStore as it won't be in the binary.

### Side note

Below are the contents of my `/Users/Shared/«your project».xcconfig`. ie disable any optimisations to so you can effectively debug without effecting CI/AppStore builds.

```xcconfig
GCC_PREPROCESSOR_DEFINITIONS="ENABLE_URLSESSION_DEBUGGING=1"
GCC_OPTIMIZATION_LEVEL = 0
SWIFT_OPTIMIZATION_LEVEL = -Onone
```

