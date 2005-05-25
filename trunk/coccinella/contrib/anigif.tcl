# AniGif Package written in pure Tcl/Tk
#
# anigif.tcl v1.3 2002-09-09 (c) 2001-2002 Ryan Casey
#
# AniGif is distributed under the same license as Tcl/Tk.  As of
# AniGif 1.3, this license is applicable to all previous versions.
#
# Modified by Alexey Shchepin <alexey@sevcom.net>
#
# ###############################  USAGE  #################################
#
#  ::anigif::anigif FILENAME INDEX
#    FILENAME: appropriate path and file to use for the animated gif
#    INDEX:    what image to begin on (first image is 0) (Default: 0)
#
#  ::anigif::stop IMAGE
#  ::anigif::restart IMAGE INDEX
#    INDEX:    defaults to next index in loop
#  ::anigif::destroy IMAGE
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

namespace eval anigif {
    variable image_number 0

    proc anigif2 {img list delay {idx 0}} {
	if { $idx >= [llength $list]  } {
	    set idx 0
	    if { [set ::anigif::${img}(repeat)] == 0} {
		# Non-repeating GIF
		::anigif::stop $img
		return
	    }
	} 
	set dispflag [lindex [set ::anigif::${img}(disposal)] $idx]
	switch -- "$dispflag" {
	    "000" {
		# Do nothing
	    }
	    "001" {
		# Do not dispose
	    }
	    "100" {
		# Restore to background
		[set ::anigif::${img}(curimage)] blank
	    }
	    "101" {
		# Restore to previous - not supported
		# As recommended, since this is not supported, it is set to blank
		[set ::anigif::${img}(curimage)] blank
	    }
	    default { puts "no match: $dispflag" }
	}
	[set ::anigif::${img}(curimage)] copy [lindex $list $idx] -subsample 2 2
	if { [lindex $delay $idx] == 0 } {
	    ::anigif::stop $img
	    return
	}
	# # #    update
	set ::anigif::${img}(asdf) "::anigif::anigif2 $img [list $list]"
	set ::anigif::${img}(loop) [after [lindex $delay $idx] "[set ::anigif::${img}(asdf)] [list $delay] [expr {$idx + 1}]"]
	set ::anigif::${img}(idx) [incr idx]
    }


    proc anigif {fnam {idx 0}} {
	variable image_number

	set n 0
	set images {}
	set delay {}
	#set img anigifimage[incr image_number]
	set img [image create photo]

	set fin [open $fnam r]
	fconfigure $fin -translation binary
	set data [read $fin [file size $fnam]]
	close $fin

	# Find Loop Record
	set start [string first "\x21\xFF\x0B" $data]

	if {$start < 0} {
	    set repeat 0
	} else {
	    set repeat 1
	}

	# Find Control Records
	set start [string first "\x21\xF9\x04" $data]
	while {![catch "image create photo xpic$n$img \
                              -file ${fnam} \
                              -format \{gif89 -index $n\}"]} {
	    set stop [string first "\x00" $data [expr {$start + 1}]]
	    if {$stop < $start} {
		break
	    }
	    set record [string range $data $start $stop]
	    binary scan $record @4c1 thisdelay
	    if {[info exists thisdelay]} {

		# Change to unsigned integer
		set thisdelay [expr {$thisdelay & 0xFF}];

		binary scan $record @2b3b3b1b1 -> disposalval userinput transflag

		lappend images pic$n$img
		image create photo pic$n$img
		pic$n$img copy xpic$n$img -zoom 2 2
		image delete xpic$n$img
		lappend disposal $disposalval

		# Convert hundreths to thousandths for after
		set thisdelay [expr {$thisdelay * 10}]

		# If 0, set to fastest (25 ms min to seem to match browser default)
		if {$thisdelay == 0} {set thisdelay 40}

		lappend delay $thisdelay
		unset thisdelay

		incr n
	    }

	    if {($start >= 0) && ($stop >= 0)} {
		set start [string first "\x21\xF9\x04" $data [expr {$stop + 1}]]
	    } else {
		break
	    }
	}
	set ::anigif::${img}(repeat) $repeat
	set ::anigif::${img}(delay) $delay
	set ::anigif::${img}(disposal) $disposal
	set ::anigif::${img}(curimage) $img
	[set ::anigif::${img}(curimage)] blank
	[set ::anigif::${img}(curimage)] copy pic0${img} -subsample 2 2
	#$img configure -image [set ::anigif::${img}(curimage)]

	anigif2 $img $images $delay $idx

	return $img
    }

    proc stop {img} {
	catch {
	    after cancel [set ::anigif::${img}(loop)]
	}
    }

    # TODO
    proc restart {w {idx -1}} {
	if {$idx == -1} {
	    if { [lindex ::anigif::${w}(delay) $idx] < 0 } {
		set idx 0
	    } else {
		set idx [set ::anigif::${w}(idx)]
	    }
	}
	catch {
	    ::anigif::stop $w
	    eval "[set ::anigif::${w}(asdf)] [list [set ::anigif::${w}(delay)]] $idx"
	}
    }

    proc destroy {w} {
	catch {
	    ::anigif::stop $w
	    set wlength [string length $w]
	    foreach imagename [image names] {
		if {[string equal [string range $imagename [string first "." $imagename] end] $w]} {
		    image delete $imagename
		}
	    }
	    unset ::anigif::${w}
	}
    }
}

package provide anigif 1.3
