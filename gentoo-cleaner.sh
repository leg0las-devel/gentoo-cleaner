#!/bin/bash

# gentoo-cleaner-0.0.1.2-r2
PWD_DIR="$(whereis gentoo-cleaner.sh | awk '{print $2}' | sed "s/\/gentoo-cleaner.sh//g")"

# User exceptions:
EXCLUDE_CONF="$PWD_DIR/user-exeptions.conf"

# Paths for find system files
if [ "$(uname -m)" != "x86_64" ]
then
INCLUDE_PATH="/bin/ /etc/ /lib/ /opt/ /sbin/ /usr/"
else
INCLUDE_PATH="/bin/ /etc/ /lib32/ /lib64/ /opt/ /sbin/ /usr/"
fi

# Exclude paths (system)
EXCLUDE_PATH="
/etc/local.d
/etc/portage
/etc/runlevels
/usr/local
/usr/portage
/usr/src
/usr/tmp
"
if [ "$(uname -m)" != "x86_64" ]
then
    EXCLUDE_PATH+="/lib/modules"
else
    EXCLUDE_PATH+="/lib64/modules"
fi

# Exceptions paths (users)
USER_EXCLUDE_PATH="$(cat $EXCLUDE_CONF | grep "^/")"

# Temporarity files and directories
TMP_DIR="/tmp/garbage"
LOG_DIR="/var/log"
TMP_PACKAGE_FILES="$TMP_DIR/package_files"
TMP_PACKAGE_FILES_SORT="$TMP_DIR/package_files_sort"
if [ "$(uname -m)" = "x86_64" ]
then
TMP_PACKAGE_FILES_SORT_LIB64="$TMP_DIR/package_files_sort_lib64"
TMP_PACKAGE_FILES_SORT_LIB64_USR_LIB64="$TMP_DIR/package_files_sort_lib64_usr_lib64"
fi
TMP_PACKAGE_FILES_RESULT="$TMP_DIR/package_files_result"
TMP_SYSTEM_FILES="$TMP_DIR/system_files"
TMP_SYSTEM_FILES_SORT="$TMP_DIR/system_files_sort"
TMP_RESULT="$TMP_DIR/garbage"
TMP_SYMLINKS="$TMP_DIR/symlinks"
TMP_SYMLINKS_SORT="$TMP_DIR/symlinks_sort"
TMP_BROKEN_SYMLINKS="$TMP_DIR/garbage_symlinks"
LOG_BROKEN_SYMLINKS="$LOG_DIR/garbage_symlinks.log"
LOG_FILES="$LOG_DIR/garbage_files.log"
LOG_ALL="$LOG_DIR/garbage_all.log"

# Creating temp directory
mkdir "${TMP_DIR}"

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

if [ "$USER_EXCLUDE_PATH" != "" ]
then
for E in $USER_EXCLUDE_PATH ; do
    TMP_SORT="$TMP_SORT | grep -v \"^$E\""
done
fi

# Sorting, writing to temp file
eval "$TMP_SORT" | sed "s/\/$//g" | sort -u > $TMP_SYSTEM_FILES_SORT

# Writing result to file (diff between system and packages filelist)
diff "$TMP_SYSTEM_FILES_SORT" "$TMP_PACKAGE_FILES_RESULT" | grep "^<" | sed "s/^< //g" > "$TMP_RESULT"

# Writing to log broken symlinks
cat "$TMP_RESULT" | while read line; do file $line | grep "broken symbolic link" | awk '{print $1}' | sed s/\://g >> $TMP_BROKEN_SYMLINKS; done
cat "$TMP_BROKEN_SYMLINKS" | sort > $LOG_BROKEN_SYMLINKS

# Removing working symbolic links
cat "$TMP_RESULT" | while read line; do file $line | grep -v "broken symbolic link" | grep "symbolic link" | awk '{print $1}' | sed s/\://g >> $TMP_SYMLINKS; done
cat "$TMP_SYMLINKS" | sort -u > $TMP_SYMLINKS_SORT

# Writing full log and files log (without symlinks)
diff "$TMP_RESULT" "$TMP_SYMLINKS_SORT" | grep "^<" | sed "s/^< //g" > "$LOG_ALL"
diff "$LOG_ALL" "$LOG_BROKEN_SYMLINKS" | grep "^<" | sed "s/^< //g" > "$LOG_FILES"

# Removing temp directory
rm -rf "$TMP_DIR"
