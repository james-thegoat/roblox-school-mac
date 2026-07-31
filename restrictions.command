#!/usr/bin/osascript

-- Delete all contents in /Library/Managed Preferences
do shell script "find '/Library/Managed Preferences' -mindepth 1 -delete" with administrator privileges

-- Lock the Managed Preferences folder with schg
do shell script "chflags -R schg '/Library/Managed Preferences'" with administrator privileges

-- Change permissions on the .jmf_settings.json file
do shell script "chmod -R a+rw '/Library/Application Support/JAMF/.jmf_settings.json'" with administrator privileges

-- Clear the content of the .jmf_settings.json file
do shell script "echo '' > '/Library/Application Support/JAMF/.jmf_settings.json'" with administrator privileges

-- Lock the .jmf_settings.json file with schg
do shell script "chflags schg '/Library/Application Support/JAMF/.jmf_settings.json'" with administrator privileges

-- Restart the JamfDaemon.app process
do shell script "killall 'JamfDaemon' 2>/dev/null || true" with administrator privileges
do shell script "open '/Library/Application Support/JAMF/Jamf.app/Contents/MacOS/JamfDaemon.app'" with administrator privileges

display notification "most restrictions removed, check the rest of the intstructions that this code was on to see what else to do" with title "Script Complete"
