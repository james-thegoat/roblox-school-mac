-- Warning / confirmation dialog
set userChoice to button returned of (display dialog ¬
	"This script will undo the Chrome Unrestrictor by:" & return & return & ¬
	"• Closing Google Chrome instantly." & return & ¬
	"• Readding restrictions" & return & ¬
	"• Reopening Chrome" & return & return & ¬
	"Do you want to continue?" buttons {"Cancel", "Continue"} default button "Cancel" with icon caution)

if userChoice is "Cancel" then
	return
end if

-- 1. Identify the enrollment folder
set enrollmentFolder to POSIX path of (path to library folder from user domain) & "Application Support/Google/Chrome Cloud Enrollment/"

try
	-- 2. Kill Chrome first to prevent it from saving cached data
	do shell script "killall 'Google Chrome' || true"
	delay 1
	
	-- 3. Delete the modified enrollment files inside the folder
	-- (Uses 'rm' safely targeting files inside that specific path)
	do shell script "rm -f " & quoted form of enrollmentFolder & "*"
	
	-- 4. Re-open Chrome to let it pull down its official configuration again
	do shell script "open -a 'Google Chrome'"
	
	display dialog "Done. The restrictions are back now. You can undo this by running the other command in the drive." buttons {"Done"} default button "Done" with title "Chrome Restorer"
	
on error errMsg
	display dialog "An error occurred while restoring." & return & return & errMsg buttons {"OK"} default button "OK" with icon stop
end try
