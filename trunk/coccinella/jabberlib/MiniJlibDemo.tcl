# Minimal test code for the JabberLib (jlib).
# Must be run with wish, or tclsh with event loop!

lappend auto_path [tk_chooseDirectory -title "Pick jabberlib dir"]
lappend auto_path [tk_chooseDirectory -title "Pick TclXML dir"]
package require jlib

# Start here if you run it from my app "The Coccinella"
# Pick the Jabber/Debug menu to get the console window.

# The roster stuff...
proc MyRosterCallbackProc {rostName what {jid {}} args} {
    puts "--roster-> what=$what, jid=$jid, args='$args'"
}
set myRoster [roster::roster xrost2 MyRosterCallbackProc]

# Browse stuff...
proc MyBrowseCallbackProc {browseName what jid xmllist} {
    puts "--browse-> what=$what, jid=$jid, xmllist='$xmllist'"
}
set myBrowser [browse::browse xbrowse2 MyBrowseCallbackProc]

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

# Make an instance of jabberlib and fill in our roster object.
set theJlib [jlib::new xjlib2 $myRoster $myBrowser MyClientProc  \
  -iqcommand          MyIqCB  \
  -messagecommand     MyMsgCB \
  -presencecommand    MyPresCB]

# Define the server you are going to use, you user name and password.
set theServer localhost
set myUsername mrduck
set myPassword xyz123

# Open and connect
set sock [socket $theServer 5222]
$theJlib connect $theServer -cmd MyConnectProc -socket $sock

# Send authorization info for an existing account
$theJlib send_auth $myUsername home MyIqCB -password $myPassword

# Get my roster
$theJlib roster_get MyRosterResultProc

# Send presence information
$theJlib send_presence -type available

# Disconnect
$theJlib disconnect
