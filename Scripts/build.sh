#!/bin/bash

set -e

cd "$( dirname "${BASH_SOURCE[0]}" )"
echo Directory: $PWD

SetupLibCxxDirsInclude()
{
	local XcodeLocation=$(xcode-select --print-path)
	local LibPath=../build/$1/include/c++
	mkdir -p $LibPath
	if [ -L "$LibPath/v1" ] ; then
		rm "$LibPath/v1"
	fi
	ln -s "$XcodeLocation/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1" "$LibPath/v1"
}

SetupLibCxxDirsLib()
{
	local XcodeLocation=$(xcode-select --print-path)
	local LibPath=../build/$1/lib/c++
	mkdir -p $LibPath
	if [ -L "$LibPath/v1" ] ; then
		rm "$LibPath/v1"
	fi
	ln -s "$XcodeLocation/Toolchains/XcodeDefault.xctoolchain/usr/lib/c++/v1" "$LibPath/v1"
}

EnableAsserts=OFF
Generator=make
EnableLLDB=OFF
OutputDirectory=main
RunTests=OFF

BuildCompiler()
{
	SetupLibCxxDirsInclude "$OutputDirectory"
	SetupLibCxxDirsLib "$OutputDirectory"

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
	fi

	local Projects="clang"
	echo Projects: $Projects

	if [ "$EnableLLDB" == "ON" ] ; then
		Projects="$Projects;lldb"
	fi

	#local Projects="$Projects;clang-tools-extra;compiler-rt"

	ExtraCMake="$ExtraCMake -DLLVM_ENABLE_PROJECTS=$Projects"

	(export CC=/usr/bin/clang; export CXX=/usr/bin/clang++; cmake $ExtraCMake -DLIBCLANG_BUILD_STATIC:BOOL=ON -DCMAKE_BUILD_TYPE:STRING=RelWithDebInfo -DLLVM_ENABLE_ASSERTIONS:BOOL=$EnableAsserts -DCLANG_INCLUDE_TESTS:BOOL=$EnableAsserts "-DCMAKE_CXX_FLAGS:STRING=-stdlib=libc++" "-DCMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING=-O3 -g $ExtraFlags" "-DCMAKE_C_FLAGS_RELWITHDEBINFO:STRING=-O3 -g $ExtraFlags" ../../llvm/llvm)

	NCPUS=`sysctl -n hw.ncpu`
	echo Number of CPUs: ${NCPUS}

	$Generator -j${NCPUS}
	
	if [ "$RunTests" == "ON" ] ; then
		$Generator -j${NCPUS} check-all
	fi

	popd
}

Generator=make

if [[ $# == 0 ]]; then
	BuildCompiler
	exit
fi

LongOptions='enable-lldb,enable-asserts,run-tests,output:,generator:'

# -temporarily store output to be able to check for errors
# -activate advanced mode getopt quoting e.g. via “--options”
# -pass arguments only via   -- "$@"   to separate them correctly
ParsedOptions=$(getopt --longoptions "$LongOptions" --name "$0" -- "$@")
if [[ $? -ne 0 ]]; then
    exit 2
fi

eval set -- "$ParsedOptions"

# now enjoy the options in order and nicely split until we see --
while true; do
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
            echo "Unrecognized option"
            exit 3
            ;;
        *)
            echo "Programming error"
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
