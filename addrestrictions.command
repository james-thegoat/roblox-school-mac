-- Warning / confirmation dialog
set userChoice to button returned of (display dialog ¬
	"This script will bring back the restrictions" & return & return & ¬
	"Do you want to continue?" buttons {"Cancel", "Continue"} default button "Cancel" with icon caution)

if userChoice is "Cancel" then
	return
end if

try
	do shell script "sudo chflags -R noschg '/Library/Managed Preferences'" with administrator privileges

	do shell script "sudo chflags noschg '/Library/Application Support/JAMF/.jmf_settings.json'" with administrator privileges

    do shell script "sudo rm -rf /var/db/auth.db"

    do shell script "sudo mv /var/db/auth.db.bak /var/db/auth.db"

    do shell script "sudo jamf manage"

    do shell script "sudo jamf policy"

	display notification "Management and restrictions are being restored." with title "Restart your mac"
	
on error errMsg
	display dialog "An error occurred during restoration." & return & return & errMsg buttons {"OK"} default button "OK" with icon stop
end try
