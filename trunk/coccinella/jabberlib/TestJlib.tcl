# Test code for the JabberLib (jlib).
# Must be run with wish, or tclsh with event loop!

package require jlib

# The roster stuff...
proc MyRosterCallbackProc {rostName what {jid {}} args} {
    puts "--roster-> what=$what, jid=$jid, args='$args'"
}
set myRoster [roster::roster MyRosterCallbackProc]

# Browse stuff...
proc MyBrowseCallbackProc {browseName what jid xmllist} {
    puts "--browse-> what=$what, jid=$jid, xmllist='$xmllist'"
}
proc MyBrowseErrorProc {browseName what jid errlist} {
    puts "--browse-(error)-> what=$what, jid=$jid, errlist='$errlist'"
}
set myBrowser [browse::browse MyBrowseCallbackProc]

# The jabberlib stuff...
proc MyClientProc {jlibName cmd args} {
    puts "MyClientProc: jlibName=$jlibName, cmd=$cmd, args='$args'"
}
proc MyIqCB {jlibName type args} {
    puts "|| MyIqCB > type=$type, args=$args"
}
proc MyMsgCB {jlibName type args} {
    puts "|| MyMsgCB > type=$type, args=$args"
}
proc MyPresCB {jlibName type args} {
    puts "|| MyPresCB > type=$type, args=$args"
}
proc MyConnectProc {jlibName args} {
    puts "MyConnectProc: jlibName=$jlibName, args='$args'"
}
proc MyRegisterProc {jlibName type theQuery} {
    puts "MyRegisterProc: type=$type, theQuery='$theQuery'"
}
proc MyLoginProc {jlibname type theQuery} {
    puts "MyLoginProc: type=$type, theQuery='$theQuery'"
}
proc MySearchGetProc {jlibName type theQuery} {
    puts "MySearchGetProc: type=$type, theQuery='$theQuery'"
}
proc MySearchSetProc {jlibName type theQuery} {
    puts "MySearchSetProc: type=$type, theQuery='$theQuery'"
}
proc MyRosterResultProc {jlibName what} {
    puts "MyRosterResultProc: what=$what"
}
proc VCardSetProc {jlibName type theQuery} {
    puts "VCardSetProc: type=$type, theQuery='$theQuery'"
}
proc VCardGetProc {jlibName type theQuery} {
    puts "VCardGetProc: type=$type, theQuery='$theQuery'"
}
proc GenericIQProc {jlibName type theQuery} {
    puts "GenericIQProc: type=$type, theQuery='$theQuery'"
}

# Make an instance of jabberlib and fill in our roster object.
set theJlib [jlib::new $myRoster $myBrowser MyClientProc  \
  -iqcommand          MyIqCB  \
  -messagecommand     MyMsgCB \
  -presencecommand    MyPresCB]

# Edit this to fit your system configuration.
set ip 192.168.0.4
set theServer athlon.se
set theJud jud.$theServer
set theConference conference.$theServer
set theRoomJid myroom@$theConference
if {1} {
	set myUsername mrduck
	set myPassword xyz123
    set myRealname {Mats Bengtsson}
    set yourUsername mari
}
set myJid ${myUsername}@$theServer
set yourJid ${yourUsername}@$theServer

return
#-------------------------------------------------------------------------------
# Open and connect
set sock [socket $ip 5222]
$theJlib connect $theServer -cmd MyConnectProc -socket $sock

# Choose from the calls below. Pick the appropriate ones:
# Make a new account
$theJlib register_set $myUsername $myPassword MyRegisterProc  \
  -name $myRealname -email $myUsername@foi.se

# Query registration info
$theJlib register_get MyRegisterProc

# Send authorization info for an existing account
$theJlib send_auth $myUsername home MyLoginProc -password $myPassword

# Get my roster
$theJlib roster_get MyRosterResultProc

# Send presence information
$theJlib send_presence -type available

# Subscribe to...
$theJlib send_presence -type subscribe -to $yourJid  \
  -from $myJid

# Accept subscription from...
$theJlib send_presence -to $yourJid -type {subscribed}

# Add user to my roster
$theJlib roster_set $yourJid MyRosterResultProc

# Remove user in my roster
$theJlib roster_remove $yourJid MyRosterResultProc

# Query registration info for JUD service
$theJlib register_get MyRegisterProc -to $theJud

# Register with the JUD service
$theJlib register_set $myUsername {} MyRegisterProc  \
  -name $myRealname -email $myUsername@foi.se -to $theJud

# Retrieve search information.
$theJlib search_get $theJud MySearchGetProc

# Search.
$theJlib search_set $theJud MySearchSetProc xxx

# Send message.
$theJlib send_message $yourJid -body {Hej svejs i lingonskogen.}

# Set/get own vCard.
$theJlib vcard_set VCardSetProc -fn Mats -n_family Bengtsson \
  -n_middle G -tel_home 136114
$theJlib vcard_get $myJid VCardGetProc 

# Private/public storage space (requires version 1.4 of server)
$theJlib private_set public:coccinella MyClientProc -ip 111.111.111.111
$theJlib private_get $myJid public:coccinella {ip} MyClientProc

# Browse services available.
$theJlib browse_get $theServer MyBrowseErrorProc
$theJlib browse_get $theJud MyBrowseErrorProc
$theJlib browse_get $theConference MyBrowseErrorProc
$theJlib browse_get xxxxx.se MyBrowseErrorProc
# Check
$myBrowser get $theServer
$myBrowser getparents $theConference
$myBrowser getnamespaces $theConference
$myBrowser getconferenceservers
$myBrowser isbrowsed $theJud

# Conferencing .................................................................

# Enter room.
$theJlib conference get_enter $theRoomJid GenericIQProc
set subelements [list  \
  [wrapper::createtag {nick} -chdata nick88]]
$theJlib conference set_enter $theRoomJid $subelements GenericIQProc
$theJlib send_message $theRoomJid -type groupchat -body {Hej svejs i lingonskogen.}
# Exit
$theJlib conference exit $theRoomJid
  
# Create room. Must be $theRoomJid and NOT $theConference !!!
$theJlib conference get_create $theRoomJid GenericIQProc
# Testing...
set subelements [list  \
  [wrapper::createtag {nick} -chdata nick1] \
  [wrapper::createtag {name} -chdata MatsRoom]]
$theJlib conference set_create $theRoomJid $subelements GenericIQProc

$myBrowser getusers $theRoomJid

# Delete room.
$theJlib conf_set_delete $theRoomJid GenericIQProc

# Set user's nick.
$theJlib conf_set_user $theRoomJid myNick $theRoomJid/key GenericIQProc

#...............................................................................

# Send unavailable information
$theJlib send_presence -type unavailable -status {Gone fishing}

# Remove account.
$theJlib register_remove $theServer MyClientProc

# Disconnect
$theJlib disconnect

#--- Get stuff from our roster object ------------------------------------------
# never set values from the client!
$myRoster getusers
$myRoster getrosteritem $yourJid
$myRoster getpresence $yourJid

