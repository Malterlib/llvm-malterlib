#!/bin/bash

set -e

cd "$( dirname "${BASH_SOURCE[0]}" )"
echo Directory: $PWD
ScriptDir="$PWD"

SetupLibCxxDirsInclude()
{
	local XcodeLocation=$(xcode-select --print-path)
	local IncludePath="$ScriptDir/../build/$1/include/c++"
	echo "IncludePath: $IncludePath"
	mkdir -p "$IncludePath"
	if [ -L "$IncludePath/v1" ] ; then
		rm "$IncludePath/v1"
	fi
	ln -s "$XcodeLocation/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1" "$IncludePath/v1"
}

SetupLibCxxDirsLib()
{
	local XcodeLocation=$(xcode-select --print-path)
	local LibPath="$ScriptDir/../build/$1/lib/c++"
	echo "LibPath: $LibPath"
	mkdir -p "$LibPath"
	if [ -L "$LibPath/v1" ] ; then
		rm "$LibPath/v1"
	fi
	ln -s "$XcodeLocation/Toolchains/XcodeDefault.xctoolchain/usr/lib/c++/v1" "$LibPath/v1"
}

EnableAsserts=OFF
Generator=ninja
EnableLLDB=OFF
OutputDirectory=main
RunTests=OFF

BuildCompiler()
{
	#SetupLibCxxDirsInclude "$OutputDirectory"
	#SetupLibCxxDirsLib "$OutputDirectory"

	CurrentVersion=`cat ../.versiontag`

	echo CurrentVersion: $CurrentVersion

	if [ ! -e "../build/$OutputDirectory/versiontag" ] ; then
		echo New major version, deleting build directory
		rm -rf "../build/$OutputDirectory"
	fi
	if [ -e "../build/$OutputDirectory/versiontag" ] ; then
		VersionTag=`cat ../build/$OutputDirectory/versiontag`
		if [ "$VersionTag" != "$CurrentVersion" ] ; then
			echo New major version, deleting build directory
			rm -rf "../build/$OutputDirectory"
		else
			echo Same major version, keeping build directory
		fi
	fi

	mkdir -p ../build/$OutputDirectory
	echo $CurrentVersion > ../build/$OutputDirectory/versiontag
	pushd ../build/$OutputDirectory

	echo Building compiler

	local ExtraFlags=
	if [ "$EnableAsserts" == "OFF" ] ; then
		ExtraFlags="-DNDEBUG"
	fi

	local ExtraCMake=
	if [[ "$Generator" == "ninja" ]] ; then
		ExtraCMake="-G Ninja"
	elif [[ "$Generator" != "make" ]] ; then
		ExtraCMake="-G $Generator"
	fi

	local Projects="clang;lld;clang-tools-extra"
	echo Projects: $Projects

	if [ "$EnableLLDB" == "ON" ] ; then
		Projects="$Projects;lldb"
	fi

	if [[ "$MalterlibBuildSDK" == "true" ]]; then
		Projects="clang;compiler-rt;libcxx;libcxxabi;polly;libunwind"
	else
		Projects="$Projects;compiler-rt;libcxx;libcxxabi;polly;libunwind"
	fi

	ExtraCMake="$ExtraCMake -DLLVM_ENABLE_PROJECTS=$Projects -DCOMPILER_RT_INCLUDE_TESTS:BOOL=OFF"

	if [ "$(uname)" == "Darwin" ]; then
		export CC=/usr/bin/clang
		export CXX=/usr/bin/clang++;
		ExtraCMake="$ExtraCMake -DCMAKE_CXX_FLAGS:STRING=-stdlib=libc++"
	fi

	if [[ "$MalterlibBuildSDK" == "true" ]]; then
		(cmake $ExtraCMake -DLIBCLANG_BUILD_STATIC:BOOL=ON -DCMAKE_BUILD_TYPE:STRING=Release -DLLVM_ENABLE_ASSERTIONS:BOOL=$EnableAsserts -DCLANG_INCLUDE_TESTS:BOOL=$EnableAsserts "-DCMAKE_CXX_FLAGS_RELEASE:STRING=-O3 $ExtraFlags" "-DCMAKE_C_FLAGS_RELEASE:STRING=-O3 $ExtraFlags" ../../llvm-project/llvm)
	else
		(cmake $ExtraCMake -DLIBCLANG_BUILD_STATIC:BOOL=ON -DCMAKE_BUILD_TYPE:STRING=RelWithDebInfo -DLLVM_ENABLE_ASSERTIONS:BOOL=$EnableAsserts -DCLANG_INCLUDE_TESTS:BOOL=$EnableAsserts "-DCMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING=-O3 -g $ExtraFlags" "-DCMAKE_C_FLAGS_RELWITHDEBINFO:STRING=-O3 -g $ExtraFlags" ../../llvm-project/llvm)
	fi

	NCPUS=`sysctl -n hw.ncpu || nproc`
	echo Number of CPUs: ${NCPUS}

	time $Generator -j${NCPUS}

	#SetupLibCxxDirsInclude "$OutputDirectory"
	#SetupLibCxxDirsLib "$OutputDirectory"

	if [ "$RunTests" == "ON" ] ; then
		$Generator -j${NCPUS} check-all
	fi

	popd
}

if [[ $# == 0 ]]; then
	BuildCompiler
	exit
fi

while [[ $# != 0 ]]; do
    case "$1" in
        --enable-lldb)
            EnableLLDB=ON
            shift
            ;;
        --enable-asserts)
            EnableAsserts=ON
            shift
            ;;
        --run-tests)
            RunTests=ON
            shift
            ;;
        --output)
            OutputDirectory="$2"
            shift 2
            ;;
        --generator)
            Generator="$2"
            shift 2
            ;;
        --)
            echo "Unrecognized option $1"
            exit 3
            ;;
        *)
            echo "Programming error $1"
            exit 3
            ;;
    esac
done

# handle non-option arguments
if [[ $# != 0 ]]; then
    echo "$0: No input arguments supported."
    exit 4
fi

BuildCompiler
