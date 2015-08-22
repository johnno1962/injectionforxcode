#!/bin/bash -x
#
#  unhide.sh
#  unhide
#
#  Created by John Holdsworth on 15/05/2015.
#  Copyright (c) 2015 John Holdsworth. All rights reserved.
#

if [ "$CONFIGURATION" = "Debug" ]; then
    UNHIDE_LDFLAGS=${1:-$UNHIDE_LDFLAGS}
    NORMAL_ARCH_FILE="$OBJECT_FILE_DIR_normal/$CURRENT_ARCH/$PRODUCT_NAME"
    LINK_FILE_LIST="$NORMAL_ARCH_FILE.LinkFileList"
    if [[ "$CODESIGNING_FOLDER_PATH" =~ ".framework" ]]; then
        DYNAMICLIB="-dynamiclib -install_name @rpath/$PRODUCT_NAME.framework/$PRODUCT_NAME"
        VERSIONS="-Xlinker -rpath -Xlinker @loader_path/Frameworks -dead_strip -single_module -compatibility_version 1 -current_version 1"
    else
        VERSIONS="-Xlinker -objc_abi_version -Xlinker 2 -fobjc-arc -fobjc-link-runtime -Xlinker -no_implicit_dylibs"
    fi

    echo "Exporting any \"hidden\" Swift internal symbols in $PRODUCT_NAME framework" &&
    `dirname $0`/unhide "$PRODUCT_NAME" `cat "$LINK_FILE_LIST"`> /tmp/unhide_$USER.log &&

    echo "Relinking with the patched object files" &&
    cd "$PROJECT_DIR" &&

    function paths {
        cat <<'PERL' >/tmp/unhide_$USER.pl
my ($var, $option) = @ARGV;
my $value = $ENV{$var};
$value =~ s/"| $//g;
$value =~ s/(?<!\\) (?!\/)/\\ /g;
$value =~ s/(^| )(?=\/)/$1$option/g;
print $value;
PERL
        OUT=`perl /tmp/unhide_$USER.pl $1 $2`
    }

    paths LIBRARY_SEARCH_PATHS -L
    LIBRARY_SEARCH_PATHS="$OUT"
    paths FRAMEWORK_SEARCH_PATHS -F
    FRAMEWORK_SEARCH_PATHS="$OUT"

    export PATH="$PLATFORM_DEVELOPER_BIN_DIR:$SYSTEM_DEVELOPER_BIN_DIR:/usr/bin:/bin:/usr/sbin:/sbin" &&
    /bin/bash -cx "\"$DT_TOOLCHAIN_DIR/usr/bin/clang\" -arch \"$CURRENT_ARCH\" $DYNAMICLIB -isysroot \"$SDKROOT\" \
        $LIBRARY_SEARCH_PATHS $FRAMEWORK_SEARCH_PATHS \
        -L\"$TARGET_BUILD_DIR\" -F\"$TARGET_BUILD_DIR\" -filelist \"$LINK_FILE_LIST\" \
        -Xlinker -rpath -Xlinker \"@executable_path/Frameworks\" \
        -L\"$DT_TOOLCHAIN_DIR/usr/lib/swift/$PLATFORM_NAME\" \
        -Xlinker -add_ast_path -Xlinker \"$NORMAL_ARCH_FILE.swiftmodule\" \
        -miphoneos-version-min=\"$IPHONEOS_DEPLOYMENT_TARGET\" $VERSIONS \
        -Xlinker -dependency_info -Xlinker \"$LD_DEPENDENCY_INFO_FILE\" \
        `echo $OTHER_LDFLAGS | sed -e 's/"//g'` $UNHIDE_LDFLAGS \
        -F \"$CODESIGNING_FOLDER_PATH/Frameworks\" \
        -o \"$CODESIGNING_FOLDER_PATH/$PRODUCT_NAME\""
    exit $?
fi
