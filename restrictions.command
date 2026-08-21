#!/usr/bin/osascript

do shell script "sudo find '/Library/Managed Preferences' -mindepth 1 -delete" with administrator privileges

do shell script "sudo chflags -R schg '/Library/Managed Preferences'" with administrator privileges

do shell script "sudo chmod a+rw '/Library/Application Support/JAMF'" with administrator privileges

do shell script "sudo chmod -R a+rw '/Library/Application Support/JAMF/.jmf_settings.json'" with administrator privileges

do shell script "sudo echo '' > '/Library/Application Support/JAMF/.jmf_settings.json'" with administrator privileges

do shell script "sudo chflags schg '/Library/Application Support/JAMF/.jmf_settings.json'" with administrator privileges

do shell script "sudo mv /var/db/auth.db /var/db/auth.db.bak" with administrator privileges

display notification "most restrictions removed, check the rest of the instructions on the doc this code was on to see what else to do" with title "almost done"
