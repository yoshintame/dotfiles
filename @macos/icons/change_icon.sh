#!/bin/bash

kTHIS_NAME=${BASH_SOURCE##*/}

die() { echo "ERROR: ${1:-"ABORTING due to unexpected error."}" 1>&2; exit ${2:-1}; }
dieSyntax() { echo "ARGUMENT ERROR: ${1:-"Invalid argument(s) specified."} Use -h for help." 1>&2; exit 2; }


#  isVolumeMountPoint <folder>
isVolumeMountPoint() {
  local folder=$1
  # Must resolve to the physical underlying path, as that is what `mount` shows
  folder=$(cd -P -- "$1"; pwd)
  mount | grep -qF "on $folder (" # !! Is there a more robust way to test for mountpoints?
}

#  getFileWithIconData <fileOrFolder>
# Returns the path of the file that contains the actual icon data, based on whether the target is
#  * a file ... the file path itself
#  * a folder:
#     * regular folder: file $'Icon\r' inside that folder, with the icon data in its resource fork
#     * volume mountpoint: file '.VolumeIcon.icns' inside that folder, with the icon data inside the file.
getFileWithIconData() {
  local fileOrFolder=$1
  if [[ -f $fileOrFolder ]]; then # file
    printf '%s' "$fileOrFolder"
  elif isVolumeMountPoint "$fileOrFolder"; then # volume mountpoint
    printf '%s' "$fileOrFolder/$kFILENAME_VOLUMECUSTOMICON"
  else # regular folder
    printf '%s' "$fileOrFolder/$kFILENAME_FOLDERCUSTOMICON"
  fi
}

getTargetType() {
  local fileOrFolder=$1
  if [[ -f $fileOrFolder ]]; then # file
    printf 'file'
  elif isVolumeMountPoint "$fileOrFolder"; then # volume mountpoint
    printf 'volume'
  else # regular folder
    printf 'folder'
  fi
}


testForCustomIcon() {

  local fileOrFolder=$1 byteStr byteVal fileWithIconData hasCustomIconFlag hasIconData 

  [[ (-f $fileOrFolder || -d $fileOrFolder) && -r $fileOrFolder ]] || return 3

  # Step 1: Check if the com.apple.FinderInfo extended attribute has the custom-icon
  #         flag set. This applies to *all* target types.
  byteStr=$(getAttribByteString "$fileOrFolder" com.apple.FinderInfo 2>/dev/null) #  || return 1
  byteVal=${byteStr:2*kFI_BYTEOFFSET_CUSTOMICON:2}
  hasCustomIconFlag=$(( byteVal & kFI_VAL_CUSTOMICON ))

  fileWithIconData=$(getFileWithIconData "$fileOrFolder")
  # Step 2: Check if there's actual icon data present,
  #         via the resource fork of the file or the folder's helper file or the file content of a
  #         volume mountpoint's helper file (./.VolumeIcon.icns)
  hasIconData "$fileWithIconData" 2>/dev/null && hasIconData=1 || hasIconData=0

  # Provide a specific exit code reflecting the state.
  # !! This is used by setCustomIcon()
  if (( hasCustomIconFlag && hasIconData )); then
    return 0   # has custom icon
  elif (( ! hasCustomIconFlag && ! hasIconData  )); then
    return 1   # typical case of file/folder NOT having a custom icon
  elif (( ! hasCustomIconFlag )); then
    echo "WARNING: Custom-icon data is present, but the 'com.apple.FinderInfo' extended attribute isn't set for $(getTargetType "$fileOrFolder") '$fileOrFolder'"  >&2
    return 2   # broken state: has icons, but no custom flag
  else # (( ! hasIconData )) 
    echo "WARNING: While the 'com.apple.FinderInfo' extended attribute is set for $(getTargetType "$fileOrFolder") '$fileOrFolder', associated icon data is missing."  >&2
    return 3   # broken state: has custom flag, but no icons
  fi

}

setCustomIcon() {

  local fileOrFolder=$1 imgFile=$2 fileWithIconData

  [[ (-f $fileOrFolder || -d $fileOrFolder) && -r $fileOrFolder && -w $fileOrFolder ]] || return 3
  [[ -f $imgFile ]] || return 3

  # !! Sadly, Apple decided to remove the `-i` / `--addicon` option from the `sips` utility.
  # !! Therefore, use of *Cocoa* is required, which we do *via AppleScript* and its ObjC bridge,
  # !! which has the added advantage of creating a *set* of icons from the source image, scaling as necessary
  # !!  to create a 512 x 512 top resolution icon (whereas sips -i created a single, 128 x 128 icon).
  # !! Thanks:
  # !!  * https://apple.stackexchange.com/a/161984/28668 (Python original)
  # !!  * @scriptingosx (https://github.com/mklement0/fileicon/issues/32#issuecomment-1074124748) (AppleScript-ObjC version)
  # !! Note: We moved from Python to AppleScript when the system Python was removed in macOS 12.3

  # !! Note: The setIcon method seemingly always indicates True, even with invalid image files, so
  # !!       we attempt no error handling in the AppleScript code, and instead verify success explicitly later.
  osascript <<EOF >/dev/null || die
    use framework "Cocoa"
    set sourcePath to "$imgFile"
    set destPath to "$fileOrFolder"
    set imageData to (current application's NSImage's alloc()'s initWithContentsOfFile:sourcePath)
    (current application's NSWorkspace's sharedWorkspace()'s setIcon:imageData forFile:destPath options:2)
EOF

  # Fully verify that everything worked as intended.
  # Unfortunately, several things can go wrong.
  testForCustomIcon "$targetFileOrFolder" 2>/dev/null && return 0
  ec=$?


  return $ec
}


# Validate file operands
(( $# > 0 )) || dieSyntax "Missing operand(s)."

# Target file or folder.
targetFileOrFolder=$1 imgFile= outFile=
[[ -f $targetFileOrFolder || -d $targetFileOrFolder ]] || die "Target not found or neither file nor folder: '$targetFileOrFolder'"

# Other operands, if any, and their number.
valid=0

(( $# <= 2 )) && {
  valid=1
  # If no image file was specified, the target file is assumed to be an image file itself whose image should be self-assigned as an icon.
  (( $# == 2 )) && imgFile=$2 || imgFile=$1
  # !! Apparently, a regular file is required - a process subsitution such 
  # !! as `<(base64 -D <encoded-file.txt)` is NOT supported by NSImage.initWithContentsOfFile()
  [[ -f $imgFile && -r $imgFile ]] || die "Image file not found or not a (readable) regular file: $imgFile"
}
   

(( valid )) || dieSyntax "Unexpected number of operands."


setCustomIcon "$targetFileOrFolder" "$imgFile" 
echo "Custom icon assigned to $(getTargetType "$targetFileOrFolder") '$targetFileOrFolder' based on '$imgFile'."
    


exit 0
