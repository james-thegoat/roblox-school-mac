-- Warning / confirmation dialog
set userChoice to button returned of (display dialog ¬
	"This script will:" & return & return & ¬
	"• Close chrome instantly. So save any unfinished stuff before clicking continue. " & return & ¬
	"• Unrestrict chrome. " & return & ¬
	"• Reopen Google Chrome afterwards." & return & return & ¬
	¬
		"Do you want to start it now?" buttons {"Cancel", "Continue"} default button "Cancel" with icon caution)

if userChoice is "Cancel" then
	return
end if

-- 1. Identify the folder (the '*' handles the random filename)
set enrollmentFolder to POSIX path of (path to library folder from user domain) & "Application Support/Google/Chrome Cloud Enrollment/"

try
	-- 2. Use a shell command to overwrite the file content with "google"
	-- This works even if the file name is different on every Mac
	do shell script "for f in " & quoted form of enrollmentFolder & "*; do [ -f \"$f\" ] && echo 'google' > \"$f\"; done"
	
	-- 3. Kill Chrome so it can refresh (the '|| true' ignores errors if Chrome is closed)
	do shell script "killall 'Google Chrome' || true"
	delay 1
	
	-- 4. Re-open Chrome
	do shell script "open -a 'Google Chrome'"
	
	display dialog "Done! Chrome has been unmanaged. You can now download extensions. (Note: Youtube logins are still blocked. If you want youtube login access then use the get browsers that arent managed at all folder in the drive.) You can now delete this app" buttons {"Done"} default button "Done" with title "Chrome Unrestrictor"
	
on error errMsg
	display dialog "An error occurred." & return & return & errMsg buttons {"OK"} default button "OK" with icon stop
end try
