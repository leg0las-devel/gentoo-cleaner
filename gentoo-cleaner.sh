#!/bin/bash

# gentoo-cleaner-0.0.2
CONF_DIR="/etc/gentoo-cleaner"
# User exceptions:
EXCLUDE_CONF="$CONF_DIR/user-exeptions.conf"

# Paths for find system files
INCLUDE_PATH="/bin/ /etc/ /lib/ /lib64/ /opt/ /sbin/ /usr/"

# Exclude paths (system)
EXCLUDE_PATH="
/etc/local.d
/etc/portage
/etc/runlevels
/lib/modules
/usr/local
/usr/portage
/usr/share/mime
/usr/src
/usr/tmp
"

# Exceptions paths (users)
USER_EXCLUDE_PATH="$(cat $EXCLUDE_CONF | grep "^/")"

# Temporarity files and directories
TMP_DIR="/tmp/garbage"
LOG_DIR="/var/log"
TMP_PACKAGE_FILES="$TMP_DIR/package_files"
TMP_PACKAGE_FILES_SORT="$TMP_DIR/package_files_sort"
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
cat "$TMP_PACKAGE_FILES" | awk '{print $2}' | grep -v "^/usr/src" | sort -u > "$TMP_PACKAGE_FILES_RESULT"

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
