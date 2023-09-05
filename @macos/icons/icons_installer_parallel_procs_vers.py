#! /opt/homebrew/bin/python3

import os
from os import listdir
import subprocess
import re


if __name__ == '__main__':
    new_icons_folder_name = "icons_files"

    cwd = os.getcwd()
    cwd = cwd + "/icons_files"
    new_icons_paths = [os.path.join(cwd, f) for f in os.listdir(
        f"{cwd}") if os.path.isfile(os.path.join(cwd, f))]  # Only .icns files

    print(f"Found {len(new_icons_paths)} icons")
    reg = re.compile("_[0-9]+$")

    replaced = 0
    processes = []
    for new_icon_path in new_icons_paths:
        app_name = os.path.splitext(os.path.basename(new_icon_path))[0]

        if reg.search(app_name):
            continue
        command = f'sudo sh ./change_icon.sh'.split() + \
            [f'/Applications/{app_name}.app', f'{new_icon_path}']

        command_str = ' '.join(command)
        
        process = subprocess.Popen(command_str, shell=True)
        processes.append(process)

        # if proc.returncode == 0:
        #     print(f"Icon for {app_name}.app successfully changed")
        #     replaced = replaced + 1

    # Collect statuses
    output = [p.wait() for p in processes]

    # print()
    # print(output)

    for p in processes:
        returncode = p.wait()
        print(f"Proc {1}:")
        print(returncode)
        print(p.stdout)
        print(p.stderr)

    # print(type(output))

    os.system('rm /var/folders/*/*/*/com.apple.dock.iconcache')
    os.system('killall Dock')

    print(f"Successfully replaced {replaced} of {len(new_icons_paths)} icons")
