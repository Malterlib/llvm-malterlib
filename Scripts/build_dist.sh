#!/bin/bash

set -ex

cd "$( dirname "${BASH_SOURCE[0]}" )"
echo Directory: $PWD
ScriptDir="$PWD"

pushd ..

RootDir="$PWD"

pushd "$ScriptDir"

BuildCompiler()
{
	CurrentVersion=`cat $RootDir/.versiontag`

	echo CurrentVersion: $CurrentVersion

	if [ ! -e "$RootDir/build/dist_temp/versiontag" ] ; then
		echo New major version, deleting build directory
		rm -rf "$RootDir/build/dist_temp"
	fi
	if [ -e "$RootDir/build/dist_temp/versiontag" ] ; then
		VersionTag=`cat "$RootDir/build/dist_temp/versiontag"`
		if [ "$VersionTag" != "$CurrentVersion" ] ; then
			echo New major version, deleting build directory
			rm -rf "$RootDir/build/dist_temp"
		else
			echo Same major version, keeping build directory
		fi
	fi

	mkdir -p "$RootDir/build/dist_temp"
	echo $CurrentVersion > "$RootDir/build/dist_temp/versiontag"
	pushd "$RootDir/build"
		local BuildDir="$PWD"
	popd

	pushd "$BuildDir/dist_temp"
		echo Building compiler

		local ExtraFlags=

		local ExtraCMake="-G Ninja"

		local Projects="clang;lld;clang-tools-extra"
		echo Projects: $Projects

		if [[ "$MalterlibBuildSDK" == "true" ]]; then
			Projects="clang;compiler-rt;libcxx;libcxxabi;polly;libunwind"
		else
			Projects="$Projects;compiler-rt;libcxx;libcxxabi;polly;libunwind"
		fi

		(cmake $ExtraCMake -C "$RootDir/Scripts/cmake_caches/PGO.cmake" "$RootDir/llvm-project/llvm")

		NCPUS=`sysctl -n hw.ncpu || nproc`
		echo Number of CPUs: ${NCPUS}

		time ninja -j${NCPUS} stage2-instrumented
	popd

	# Generate profiling data
	pushd "$BuildDir/dist_temp/tools/clang/stage2-instrumented-bins"
		#ninja check-all || true
	popd

	pushd /opt/Source/Malterlib
		EnableArchitecture_x86=false EnableArchitecture_x64=true EnableArchitecture_arm64=true EnableReleaseConfig=true EnableReleaseTestingConfig=true \
		EnablePlatform_Linux2_6=true EnablePlatform_OSX10_7=true MalterlibDisableBuildSystemGeneration=true \
		PlatformToolsetCompiler="$BuildDir/dist_temp/tools/clang/stage2-instrumented-bins/bin/clang" \
			./mib generate --no-use-user-settings Tests --reconcile-removed=*:leave

		#./mib build "Tests" "OSX10.7" "arm64" "Release (Tests)" || true # Crashes
		./mib build "Tests" "OSX10.7" "arm64" "Debug" || true
		./mib build "Tests" "OSX10.7" "arm64" "Release Testing (Tests)" || true
		#./mib build "Tests" "OSX10.7" "x64" "Release (Tests)" || true # Crashes
		./mib build "Tests" "OSX10.7" "x64" "Debug" || true
		./mib build "Tests" "OSX10.7" "x64" "Release Testing (Tests)" || true
		#./mib build "Tests" "Linux2.6" "x64" "Release (Tests)" || true # Crashes
		./mib build "Tests" "Linux2.6" "x64" "Debug" || true
		./mib build "Tests" "Linux2.6" "x64" "Release Testing (Tests)" || true
	popd

	# Merge profiling data
	"$BuildDir/dist_temp/bin/llvm-profdata" merge "-output=$RootDir/build/merged.profdata" "$BuildDir/dist_temp/tools/clang/stage2-instrumented-bins/profiles/"*.profraw

	mkdir -p "$RootDir/build/dist_temp2"
	echo $CurrentVersion > "$RootDir/build/dist_temp2/versiontag"
	pushd "$RootDir/build/dist_temp2"
		ExtraCMake="$ExtraCMake -DBOOTSTRAP_CMAKE_INSTALL_PREFIX=$BuildDir/dist"
		ExtraCMake="$ExtraCMake -DBOOTSTRAP_LLVM_PROFDATA_FILE=$RootDir/build/merged.profdata"

		(cmake $ExtraCMake -C "$RootDir/Scripts/cmake_caches/Distribution.cmake" "$RootDir/llvm-project/llvm")

		#time ninja -j${NCPUS} stage2-distribution
		time ninja -j${NCPUS} stage2-install-distribution
	popd
}

BuildCompiler
