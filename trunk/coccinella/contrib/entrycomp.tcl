#  entrycomp.tcl ---
#  
#      This file is part of the whiteboard application. It implements an
#      entry with completion.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: entrycomp.tcl,v 1.1 2003-07-05 13:26:37 matben Exp $
#
# ########################### USAGE ############################################
#
#   NAME
#      entrycomp - an entry with input completion.
#      
#   SYNOPSIS
#      entrycomp pathName liblist ?options?
#      
#   OPTIONS
#      all entry widget options
#      
#   WIDGET COMMANDS
#      Identical to the entry widget
#
# ########################### CHANGES ##########################################
#
#       0.1      first release

package provide entrycomp 0.1

namespace eval ::entrycomp:: {

    # The public interface.
    namespace export entrycomp

    # Globals same for all instances of this widget.
    variable priv
    
    set priv(debug) 0
    set priv(initted) 0
}

proc ::entrycomp::Init { } {
    variable priv
    

    set priv(initted) 1
}

# ::entrycomp::entrycomp --
#
#       Creates an entry with pattern completion.
#       
# Arguments:
#       w           widget path
#       liblist     library list to search in
#       args        options for the entry widget
#       
# Results:
#       Wiidget path

proc ::entrycomp::entrycomp {w liblist args} {
    variable priv
    
    if {!$priv(initted)} {
	::entrycomp::Init
    }

    eval {entry $w} $args
    bind $w <KeyPress> [list ::entrycomp::Insert %W %A $liblist]
    return $w
}

# ::entrycomp::Insert --
# 
#       Callback for <KeyPress> that replaces the Entry's binding.

proc ::entrycomp::Insert {w s liblist} {
    variable priv
    
    if {[string equal $s ""]} {
	return
    }
    catch {$w delete sel.first sel.last}
    set str [$w get]
    set insert [expr [$w index insert] + 1]
    set white [string range $str 0 $insert]
    append white $s
    $w insert insert $s
    
    # Find matches in liblist.
    set mlist [lsearch -glob -inline -all $liblist ${white}*]
    if {[llength $mlist]} {
	set mstr [lindex $mlist 0]
	$w delete 0 end
	$w insert insert $mstr
	$w selection range $insert end
	$w icursor $insert
    } else {
	$w delete $insert end
    }    
    ::tk::EntrySeeInsert $w
    
    # Stop Entry class handler from executing.
    return -code break
}

# test
if {0} {
    set liblist {abcdefg abcert abczzz abc123 zzz uuu www}
    toplevel .top
    pack [::entrycomp::entrycomp .top.ent1 $liblist]
    pack [::entrycomp::entrycomp .top.ent2 $liblist]
    pack [::entrycomp::entrycomp .top.ent3 $liblist]
}
#-------------------------------------------------------------------------------
