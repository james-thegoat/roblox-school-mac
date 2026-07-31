#!/usr/bin/osascript

do shell script "find '/Library/Managed Preferences' -mindepth 1 -delete" with administrator privileges

do shell script "chflags -R schg '/Library/Managed Preferences'" with administrator privileges

do shell script "chmod -R a+rw '/Library/Application Support/JAMF/.jmf_settings.json'" with administrator privileges

do shell script "echo '' > '/Library/Application Support/JAMF/.jmf_settings.json'" with administrator privileges

do shell script "chflags schg '/Library/Application Support/JAMF/.jmf_settings.json'" with administrator privileges

do shell script "mv /var/db/auth.db /var/db/auth.db.bak" with administrator privileges

display notification "most restrictions removed, restart your macbook then check the rest of the instructions on the doc this code was on to see what else to do" with title "almost done"
