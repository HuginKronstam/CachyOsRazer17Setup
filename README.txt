Testing Plan:
Since you have version control on the script, here's how to test:

Fresh install CachyOS
Run updated script:

bash   chmod +x cachyos-setup.sh
   ./cachyos-setup.sh --interactive  # Or without flag for auto mode

Reboot
Verify X11 is active:

bash   echo $XDG_SESSION_TYPE  # Should show "x11"

Test gaming on native screen
Connect external monitor and test gaming - should now be smooth!
