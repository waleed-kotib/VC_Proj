
# Just testing the roster stuff.

# The callback procedure to be present in the client.

proc MyRosterCallbackProc {rostName what {jid {}} args} {
    puts "---> MyRosterCallbackProc: rostName=$rostName, what=$what, jid=$jid, \
      args='$args'"
    
    switch -- $what {
	presence {
	    puts "   presence: jid=$jid, args='$args'"
	}
	remove {
	    puts "   remove: jid=$jid"
	}
	set {
	    puts "   set: jid=$jid, args='$args'"
	}
	clear {
	    puts "   clear:"
	}
    }
}

set myRoster [roster::roster MyRosterCallbackProc]

# All the "sets". To be made from jabberlib.
$myRoster setrosteritem matsbe@localhost -name {Mats Bengtsson} -group {hard}
$myRoster setrosteritem mari@localhost -name {Mari Lundberg} -group {hard}
$myRoster setrosteritem stam@localhost -name {Stam Nosstgneb} -group {ideal hard}
$myRoster setrosteritem kass@localhost -name {Kass Dalig} -group {ideal}

$myRoster setpresence matsbe@localhost home available
$myRoster setpresence mari@localhost home available

#$myRoster removeitem matsbe@localhost

# The "gets", from the client.
puts "---> getusers: [$myRoster getusers]"
puts "---> getrosteritem: [$myRoster getrosteritem mari@localhost]"
puts "---> getpresence: [$myRoster getpresence mari@localhost]"


