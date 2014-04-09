#!/bin/bash

# gentoo-cleaner-0.0.1.1
PWD_DIR="$(whereis gentoo-cleaner.sh | awk '{print $2}' | sed "s/\/gentoo-cleaner.sh//g")"

# User exceptions:
EXCLUDE_CONF="$PWD_DIR/user-excludes.conf"

# Paths for find system files
if [ "$(uname -m)" != "x86_64" ]
then
INCLUDE_PATH="/bin/ /etc/ /lib/ /opt/ /sbin/ /usr/"
else
INCLUDE_PATH="/bin/ /etc/ /lib32/ /lib64/ /opt/ /sbin/ /usr/"
fi

# Exclude paths (system)
EXCLUDE_PATH="
/etc/local.d/
/etc/portage/
/etc/runlevels/
/usr/local/
/usr/portage/
/usr/src/
"
if [ "$(uname -m)" != "x86_64" ]
then
    EXCLUDE_PATH+="/lib/modules/"
else
    EXCLUDE_PATH+="/lib64/modules/"
fi

# Exceptions paths (users)
USER_EXCLUDE_PATH="$(cat $EXCLUDE_CONF | grep "^/")"

# Temporarity files and directories
TMP_DIR="/tmp/garbage"
TMP_PACKAGE_FILES="package_files"
TMP_PACKAGE_FILES_SORT="package_files_sort"
if [ "$(uname -m)" = "x86_64" ]
then
TMP_PACKAGE_FILES_SORT_LIB64="package_files_sort_lib64"
TMP_PACKAGE_FILES_SORT_LIB64_USR_LIB64="package_files_sort_lib64_usr_lib64"
fi
TMP_PACKAGE_FILES_RESULT="package_files_result"
TMP_SYSTEM_FILES="system_files"
TMP_SYSTEM_FILES_SORT="system_files_sort"
TMP_RESULT="garbage.log"

# Creating temp directory
mkdir "${TMP_DIR}"

# Paths
TMP_PACKAGE_FILES="$TMP_DIR/$TMP_PACKAGE_FILES"
TMP_PACKAGE_FILES_SORT="$TMP_DIR/$TMP_PACKAGE_FILES_SORT"
if [ "$(uname -m)" = "x86_64" ]
then
TMP_PACKAGE_FILES_SORT_LIB64="$TMP_DIR/$TMP_PACKAGE_FILES_SORT_LIB64"
TMP_PACKAGE_FILES_SORT_LIB64_USR_LIB64="$TMP_DIR/$TMP_PACKAGE_FILES_SORT_LIB64_USR_LIB64"
fi
TMP_PACKAGE_FILES_RESULT="$TMP_DIR/$TMP_PACKAGE_FILES_RESULT"
TMP_SYSTEM_FILES="$TMP_DIR/$TMP_SYSTEM_FILES"
TMP_SYSTEM_FILES_SORT="$TMP_DIR/$TMP_SYSTEM_FILES_SORT"
TMP_RESULT="/var/log/$TMP_RESULT"

# Creating filelist for packages
find /var/db/pkg/ -name CONTENTS -exec cat {} \; >> "$TMP_PACKAGE_FILES"
cat "$TMP_PACKAGE_FILES" | awk '{print $2}' | grep -v "^/usr/src" | sort -u > "$TMP_PACKAGE_FILES_SORT"
# Moving /lib -> /lib64 and /usr/lib -> /usr/lib64 for x86_64, sorting
if [ "$(uname -m)" = "x86_64" ]
then
cat "$TMP_PACKAGE_FILES_SORT" | sed "s/^\/lib\//\/lib64\//g" > $TMP_PACKAGE_FILES_SORT_LIB64
cat "$TMP_PACKAGE_FILES_SORT_LIB64" | sed "s/^\/usr\/lib\//\/usr\/lib64\//g" > $TMP_PACKAGE_FILES_SORT_LIB64_USR_LIB64
cat "$TMP_PACKAGE_FILES_SORT_LIB64_USR_LIB64" | sort -u > "$TMP_PACKAGE_FILES_RESULT"
else
cp "$TMP_PACKAGE_FILES_SORT" "$TMP_PACKAGE_FILES_RESULT"
fi

# Creating system filelist according to $INCLUDE_PATH
find $INCLUDE_PATH > $TMP_SYSTEM_FILES

# Add system exceptions
TMP_SORT="cat $TMP_SYSTEM_FILES"
for E in $EXCLUDE_PATH ; do
    TMP_SORT="$TMP_SORT | grep -v \"^$E\""
done

# Add users exceptions
for E in $USER_EXCLUDE_PATH ; do
    TMP_SORT="$TMP_SORT | grep -v \"^$E\""
done

# Sorting, writing to temp file
eval "$TMP_SORT" | sort -u > $TMP_SYSTEM_FILES_SORT

# Writing to log file
diff "$TMP_SYSTEM_FILES_SORT" "$TMP_PACKAGE_FILES_RESULT" | grep "^<" | sed "s/^< //g" > "$TMP_RESULT"

# Removing temp directory
rm -rf "$TMP_DIR"
