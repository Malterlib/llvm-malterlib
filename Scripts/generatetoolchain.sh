 #!/bin/bash

set -e

cd "$( dirname "${BASH_SOURCE[0]}" )"/..

SourceDir="$PWD"
DefaultToolchainLocation="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
MalterlibToolchainLocation="$HOME/Library/Developer/Toolchains/Malterlib.xctoolchain"

if ! [[ -d "$DefaultToolchainLocation" ]]; then
	echo "Could not find default toolchain at $DefaultToolchainLocation"
	exit 1
fi

echo "SourceDir: $SourceDir"
echo "MalterlibToolchainLocation: $MalterlibToolchainLocation"
echo "DefaultToolchainLocation: $DefaultToolchainLocation"

if [[ -e "$MalterlibToolchainLocation" ]]; then
	rm -rf "$MalterlibToolchainLocation"
fi

mkdir -p `dirname "$MalterlibToolchainLocation"`

cp -R "$DefaultToolchainLocation/" "$MalterlibToolchainLocation"

rm "$MalterlibToolchainLocation/ToolchainInfo.plist"

cat > "$MalterlibToolchainLocation/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Aliases</key>
	<array>
		<string>Malterlib</string>
	</array>
	<key>CFBundleIdentifier</key>
	<string>org.malterlib.1.0</string>
	<key>CompatibilityVersion</key>
	<integer>2</integer>
	<key>CompatibilityVersionDisplayString</key>
	<string>Xcode 8.0</string>
	<key>CreatedDate</key>
	<date>2019-01-01T10:00:00Z</date>
	<key>DisplayName</key>
	<string>Malterlib llvm</string>
	<key>OverrideBuildSettings</key>
	<dict>
		<key>ENABLE_BITCODE</key>
		<string>NO</string>
		<key>SWIFT_DEVELOPMENT_TOOLCHAIN</key>
		<string>YES</string>
		<key>SWIFT_DISABLE_REQUIRED_ARCLITE</key>
		<string>YES</string>
		<key>SWIFT_LINK_OBJC_RUNTIME</key>
		<string>YES</string>
		<key>SWIFT_USE_DEVELOPMENT_TOOLCHAIN_RUNTIME</key>
		<string>YES</string>
	</dict>
	<key>ShortDisplayName</key>
	<string>Malterlib llvm</string>
	<key>Version</key>
	<string>1.0</string>
</dict>
</plist>
EOF

function OverrideDirectory()
{
	cd "$1"

	for File in `ls "$2"`; do
		DestinationFile="$1/$File"
		if [ -e "$DestinationFile" ]; then
			#echo Deleting "$DestinationFile"
			rm -rf "$DestinationFile"
		fi

		#echo ln -s "$2/$File"
		ln -s "$2/$File"

	done
}

OverrideDirectory "$MalterlibToolchainLocation/usr/bin" "$SourceDir/build/main/bin"
OverrideDirectory "$MalterlibToolchainLocation/usr/include" "$SourceDir/build/main/include"
OverrideDirectory "$MalterlibToolchainLocation/usr/lib" "$SourceDir/build/main/lib"
OverrideDirectory "$MalterlibToolchainLocation/usr/libexec" "$SourceDir/build/main/libexec"
OverrideDirectory "$MalterlibToolchainLocation/usr/share" "$SourceDir/build/main/share"
