-- Warning / confirmation dialog
set userChoice to button returned of (display dialog ¬
	"This will delete homebrew" & return & return & ¬
	"Are you sure you want to proceed?" buttons {"Cancel", "Delete"} default button "Cancel" with icon caution)

if userChoice is "Cancel" then
	return
end if

-- 1. Define the target path safely using the user's Home directory
set targetFolder to POSIX path of (path to home folder) & "Downloads/.brew"

try
	-- 2. Verify if the directory actually exists before trying to delete it
	set fileExists to (do shell script "[ -d " & quoted form of targetFolder & " ] && echo 'yes' || echo 'no'")
	
	if fileExists is "yes" then
		-- 3. Delete the folder and all its contents
		do shell script "rm -rf " & quoted form of targetFolder
		
		display dialog "Done. Homebrew is now deleted" buttons {"OK"} default button "OK" with title "Clean Up Complete"
	else
		display dialog "The folder ~/Downloads/.brew could not be found." buttons {"OK"} default button "OK" with icon note
	end if
	
on error errMsg
	display dialog "An error occurred while trying to delete the folder." & return & return & errMsg buttons {"OK"} default button "OK" with icon stop
end try
