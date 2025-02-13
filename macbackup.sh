#!/bin/bash


# Written by Michael Bolanos and some help from Al


# Fancy header
clear
printf "\033[1;32m"
echo "======================================\n"
echo "       📁 Mac Backup - Rsync Tool       \n"
echo "======================================\n"
printf "\033[0m"

# MacOS Notification Function
macos_notify() {
    osascript -e "display notification \"$1\" with title \"NBackup\""
}

# Function to list mounted volumes
list_volumes() {
    echo "--------------------------------------"
    echo " Available Volumes 📂"
    echo "--------------------------------------"
    local count=1
    VOLUMES=()
    for volume in /Volumes/*; do
        if [ -d "$volume" ]; then
            echo "$count) $(basename "$volume")"
            VOLUMES+=("$volume")
            ((count++))
        fi
    done
    echo "C) Cancel"
}

# Function to list directories inside the selected volume
list_dirs() {
    local parent_dir="$1"
    echo "--------------------------------------"
    echo " Folders in $(basename "$parent_dir") 📂"
    echo "--------------------------------------"
    local count=1
    DIRS=()
    for dir in "$parent_dir"/*; do
        if [ -d "$dir" ]; then
            echo "$count) $(basename "$dir")"
            DIRS+=("$dir")
            ((count++))
        fi
    done
    echo "0) Backup entire volume"
    echo "C) Cancel"
}

### SELECT SOURCE VOLUME ###
list_volumes
read -rp "Select the source volume by number (or C to cancel): " VOL_SELECTION

if [[ "$VOL_SELECTION" == "C" || "$VOL_SELECTION" == "c" ]]; then
    echo "Backup canceled."
    exit 0
fi

if ! [[ "$VOL_SELECTION" =~ ^[0-9]+$ ]] || [ "$VOL_SELECTION" -lt 1 ] || [ "$VOL_SELECTION" -gt "${#VOLUMES[@]}" ]]; then
    echo "❌ Invalid selection. Exiting..."
    exit 1
fi

SOURCE_VOLUME="${VOLUMES[$((VOL_SELECTION-1))]}"

### SELECT SOURCE DIRECTORY ###
list_dirs "$SOURCE_VOLUME"
read -rp "Select the directory to back up by number (or C to cancel): " DIR_SELECTION

if [[ "$DIR_SELECTION" == "C" || "$DIR_SELECTION" == "c" ]]; then
    echo "Backup canceled."
    exit 0
fi

if [ "$DIR_SELECTION" -eq 0 ]; then
    SOURCE_DIR="$SOURCE_VOLUME"
else
    if ! [[ "$DIR_SELECTION" =~ ^[0-9]+$ ]] || [ "$DIR_SELECTION" -lt 1 ] || [ "$DIR_SELECTION" -gt "${#DIRS[@]}" ]]; then
        echo "❌ Invalid selection. Exiting..."
        exit 1
    fi
    SOURCE_DIR="${DIRS[$((DIR_SELECTION-1))]}"
fi

### SELECT DESTINATION VOLUME ###
echo ""
echo "--------------------------------------"
echo " Select Destination Volume 🔄"
echo "--------------------------------------"
list_volumes
read -rp "Select the destination volume by number (or C to cancel): " DEST_VOL_SELECTION

if [[ "$DEST_VOL_SELECTION" == "C" || "$DEST_VOL_SELECTION" == "c" ]]; then
    echo "Backup canceled."
    exit 0
fi

if ! [[ "$DEST_VOL_SELECTION" =~ ^[0-9]+$ ]] || [ "$DEST_VOL_SELECTION" -lt 1 ] || [ "$DEST_VOL_SELECTION" -gt "${#VOLUMES[@]}" ]]; then
    echo "❌ Invalid selection. Exiting..."
    exit 1
fi

DEST_VOLUME="${VOLUMES[$((DEST_VOL_SELECTION-1))]}"

### DEFAULT TO NAS-BACKUP FOLDER ###
DEFAULT_BACKUP_DIR="NAS-Backup"
read -rp "Enter a backup folder name (default: NAS-Backup): " BACKUP_NAME
BACKUP_NAME=${BACKUP_NAME:-$DEFAULT_BACKUP_DIR}  # Use default if empty
DEST_DIR="$DEST_VOLUME/$BACKUP_NAME"

### CHOOSE BACKUP SPEED ###
echo ""
echo "--------------------------------------"
echo " 🔹 Choose Backup Speed 🔹"
echo "--------------------------------------"
echo "1) ⚡ Fast Mode (No bandwidth limit)"
echo "2) ⏳ Balanced Mode (10MB/s limit)"
echo "3) 🛡️ Safe Mode (Minimal impact on system) - 5MB/s limit"
read -rp "Select backup speed (1-3): " SPEED_OPTION

case "$SPEED_OPTION" in
    1) RSYNC_SPEED="" ;;  
    2) RSYNC_SPEED="--bwlimit=10000" ;;  
    3) RSYNC_SPEED="--bwlimit=5000" ;;  
    *) echo "❌ Invalid option. Using Balanced Mode."; RSYNC_SPEED="--bwlimit=10000" ;;
esac

### ENABLE FAST BACKUP (NO DEEP INDEXING) ###
echo ""
echo "--------------------------------------"
echo " ⚡ Skip Deep Indexing? (Faster Backups) ⚡"
echo "--------------------------------------"
echo "1) Yes - Only copy new/changed files (faster, no full re-scan)"
echo "2) No - Fully scan and verify all files (slower, more reliable)"
read -rp "Select indexing mode (1-2): " INDEX_OPTION

case "$INDEX_OPTION" in
    1) INDEX_FLAGS="--ignore-existing" ;;  # No deep indexing
    2) INDEX_FLAGS="" ;;  # Full scan
    *) echo "❌ Invalid option. Using default full scan."; INDEX_FLAGS="" ;;
esac

### KEEP TWO VERSIONS OF BACKUPS ###
if [ -d "$DEST_DIR/Backup_A" ]; then
    ACTIVE_BACKUP="$DEST_DIR/Backup_B"
    OLD_BACKUP="$DEST_DIR/Backup_A"
else
    ACTIVE_BACKUP="$DEST_DIR/Backup_A"
    OLD_BACKUP="$DEST_DIR/Backup_B"
fi

mkdir -p "$ACTIVE_BACKUP"

### START BACKUP ###
macos_notify "Backup started from $SOURCE_DIR to $ACTIVE_BACKUP."

echo "--------------------------------------"
printf "\033[1;34m 🚀 Starting Rsync Backup \033[0m\n"
echo "--------------------------------------"
echo "Source: $SOURCE_DIR"
echo "Destination: $ACTIVE_BACKUP"
echo "Backup Speed: $SPEED_OPTION"
echo "Excluding hidden files: Yes"
echo "Indexing Mode: $INDEX_OPTION"
echo "--------------------------------------"
echo "📦 Backup is now running... Please wait."

# Start rsync process with optional indexing mode
rsync -av --partial --append-verify --delete $RSYNC_SPEED $INDEX_FLAGS --exclude=".*" --progress "$SOURCE_DIR/" "$ACTIVE_BACKUP/" | tee -a "$HOME/rsync_backup.log"

echo ""
echo "✅ Backup completed successfully at $(date)!"
macos_notify "Backup 100% complete!"

### DELETE OLD BACKUP ###
if [ -d "$OLD_BACKUP" ]; then
    echo "🗑️ Removing old backup: $OLD_BACKUP"
    rm -rf "$OLD_BACKUP"
    echo "✅ Old backup removed!"
fi

macos_notify "Old backup deleted, new backup stored in $ACTIVE_BACKUP."

echo "--------------------------------------"
echo "🎉 Backup process finished! Your files are safe. 🎉"
echo "--------------------------------------"
