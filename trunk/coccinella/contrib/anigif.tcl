# AniGif Package written in pure Tcl/Tk
#
# anigif.tcl v1.3 2002-09-09 (c) 2001-2002 Ryan Casey
#
# AniGif is distributed under the same license as Tcl/Tk.  As of
# AniGif 1.3, this license is applicable to all previous versions.
#
# Modified by Alexey Shchepin <alexey@sevcom.net>
# 
# Modified by Mats Bengtsson <matben@users.sf.net>
#
# ###############################  USAGE  #################################
#
#  ::anigif::anigif FILENAME NAME INDEX
#    FILENAME: appropriate path and file to use for the animated gif
#    INDEX:    what image to begin on (first image is 0) (Default: 0)
#
#  ::anigif::stop IMAGE
#  ::anigif::restart IMAGE INDEX
#    INDEX:    defaults to next index in loop
#  ::anigif::destroy IMAGE
#  ::anigif::delete IMAGE
#
#  NOTES:
#    There is currently a -zoom and -subsample hack to keep transparency.
#    Anigif does not handle interlaced gifs properly.  The image will look
#      distorted.
#    A delay of 0 renders as fast as possible, per the GIF specification.
#      This is currently set to 40 ms to approximate the IE default.
#    If you experience a problem with a compressed gif, try uncompressing
#      it. Search the web for gifsicle.    
#
# ############################## HISTORY #################################
#
#  1.4: Major rewrite by Mats
#  1.3: Fixed error in disposal flag handling.
#       Added handling for non-valid comment/graphic blocks.
#       Searches for actual loop control block.  If it extists, loops.
#       Added more comments.
#  1.2: Now handles single playthrough gifs or gifs with partial images
#       Fixed bug in delay time (unsigned int was being treated as signed)
#  1.1: Reads default timing instead of 100 ms or user-defined.
#       You can no longer set the delay manually.
#  1.0: Moved all anigif variables to the anigif namespace
#  0.9: Initial release
# 

package provide anigif 1.4


namespace eval ::anigif {
    variable allNames {}
    variable heartbeat
    array set heartbeat {
	ms          2000
    }

    proc anigif {fileName name {idx 0}} {
	variable allNames
	variable heartbeat

	set n 0
	set images {}
	set delay {}

	# Read image file.
	set fd [open $fileName r]
	fconfigure $fd -translation binary
	set data [read $fd [file size $fileName]]
	close $fd

	if {$name == ""} {
	    set img [image create photo]
	} else {
	    set img [image create photo $name]
	}
	lappend allNames $img
	
	set token [GetToken $img]
	upvar 0 $token state
	variable $token

	# Find Loop Record
	set start [string first "\x21\xFF\x0B" $data]

	if {$start < 0} {
	    set repeat 0
	} else {
	    set repeat 1
	}

	# Find Control Records
	set start [string first "\x21\xF9\x04" $data]
	
	set cmd [list image create photo -file $fileName \
	  -format [list gif89 -index $n]]

	while {![catch $cmd tmpname]} {
	    set stop [string first "\x00" $data [expr {$start + 1}]]
	    if {$stop < $start} {
		break
	    }
	    set record [string range $data $start $stop]
	    
	    if {[binary scan $record @4c1 thisdelay]} {

		# Change to unsigned integer
		set thisdelay [expr {$thisdelay & 0xFF}]

		# Convert hundreths to thousandths for after
		set thisdelay [expr {$thisdelay * 10}]

		# If 0, set to fastest (25 ms min to seem to match browser default)
		if {$thisdelay == 0} {
		    set thisdelay 40
		}
		lappend delay $thisdelay

		binary scan $record @2b3b3b1b1 -> disposalval userinput transflag

		lappend images $tmpname
		lappend disposal $disposalval
		incr n
	    }
	    set cmd [list image create photo -file $fileName \
	      -format [list gif89 -index $n]]

	    if {($start >= 0) && ($stop >= 0)} {
		set start [string first "\x21\xF9\x04" $data [expr {$stop + 1}]]
	    } else {
		break
	    }
	}
	
	set state(repeat)   $repeat
	set state(delay)    $delay
	set state(disposal) $disposal
	set state(current)  $img
	set state(images)   $images
	set state(idx)      $idx
	set state(runs)     1
	
	$state(current) blank
	$state(current) copy [lindex $images 0]
	
	if {![info exists heartbeat(after)]} {
	    Beat
	}
	return $img
    }
    
    proc GetToken {img} {
	
	# Protect from the case when the image name contains any ::
	# Not 100% foolproof!
	#set img [string map {- --} $img]
	return ::anigif::[string map {:: -} $img]
    }

    proc Step {token {idx 0}} {
	upvar 0 $token state
	variable $token
	
	# Need a way to detect if original image was deleted.
	# Internal error handling in tk seems inconsistent!
	if {![array exists state]} {
	    return
	}
	set img $state(current)
	if {[catch {image inuse $img}]} {
	    delete $img
	    return
	}
	if {$idx >= [llength $state(images)]} {
	    set idx 0
	    if {$state(repeat) == 0} {
		# Non-repeating GIF
		stop $img
		return
	    }
	} 
	set dispflag [lindex $state(disposal) $idx]
	
	switch -- $dispflag {
	    "000" {
		# Do nothing
	    }
	    "001" {
		# Do not dispose
	    }
	    "100" {
		# Restore to background
		if {[catch {$state(current) blank}]} {
		    delete $img
		    return
		}
	    }
	    "101" {
		# Restore to previous - not supported
		# As recommended, since this is not supported, it is set to blank
		if {[catch {$state(current) blank}]} {
		    delete $img
		    return
		}
	    }
	    default { 
		puts "no match: $dispflag" 
	    }
	}
	if {[catch {$state(current) copy [lindex $state(images) $idx]}]} {
	    delete $img
	    return
	}
	if {[lindex $state(delay) $idx] == 0} {
	    stop $img
	    return
	}
	
	# Reschedule.
	set delay [lindex $state(delay) $idx]
	set state(after) [after $delay [list ::anigif::Step $token [incr idx]]]
	set state(idx) [incr idx]
    }

    proc stop {img} {
	set token [GetToken $img]
	upvar 0 $token state
	variable $token

	catch {
	    after cancel $state(after)
	}
	set state(runs) 0
	unset -nocomplain state(after)
    }

    # TODO
    proc restart {img {idx -1}} {
	set token [GetToken $img]
	upvar 0 $token state
	variable $token

	if {$idx == -1} {
	    if {[lindex $state(delay) $idx] < 0} {
		set idx 0
	    } else {
		set idx $state(idx)
	    }
	}
	catch {
	    stop $img
	    Step $token $idx
	}
    }

    proc destroy {img} {
	delete $img
    }
    
    proc delete {img} {
	set token [GetToken $img]
	upvar 0 $token state
	variable $token
	variable allNames

	set allNames [lsearch -all -not -inline $allNames $img]
	
	catch {
	    stop $img
	    eval {image delete $state(current)} $state(images)
	    unset state
	}
    }
    
    proc isanigif {img} {
	set token [GetToken $img]
	upvar 0 $token state

	return [array exists state]
    }
    
    proc Pause {token} {
	upvar 0 $token state
	variable $token

	catch {
	    after cancel $state(after)
	}
	unset -nocomplain state(after)
    }	
    
    # Static procedure to schedule timers only when needed.
    proc Beat { } {
	variable allNames
	variable heartbeat
    
	if {$allNames == {}} {
	    catch {after cancel $heartbeat(after)}
	    unset -nocomplain heartbeat(after)
	    return
	}
	
	# This shall start and stop timers for each image when needed.
	foreach name $allNames {
	    set token [GetToken $name]
	    upvar 0 $token state
	    variable $token

	    # Need a way to detect if original image was deleted.
	    if {[catch {image inuse $name} inuse]} {
		delete $name
		continue
	    }
	    if {$inuse && ![info exists state(after)]} {
		Step $token
	    } elseif {!$inuse && [info exists state(after)]} {
		Pause [GetToken $name]
	    }
	}	
	set heartbeat(after) [after $heartbeat(ms) [namespace current]::Beat]
    }
}

