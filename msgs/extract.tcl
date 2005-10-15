#!/usr/bin/tclsh
#
# Author: Vincent Ricard <vincent@magicninja.org>
# 
# Modified by Mats (::msgcat::mc -> mc)

package require fileutil

if {[llength $argv] < 1 || 3 < [llength $argv]} {
    # -v: show useless translations
    puts stderr {extract sourceDir [[-v ] translationFile]}
    exit 1
}

set sourceDir [lindex $argv 0]
set translationFile ""
if {[llength $argv] == 3 && 0 == [string compare "-v" [lindex $argv 1]]} {
    set invertMatch true
    set translationFile [lindex $argv 2]
} else {
    set invertMatch false
    set translationFile [lindex $argv 1]
}

# Read all tcl file from sourceDir
set tclFileList [::fileutil::findByPattern $sourceDir -glob -- *tcl]
foreach filename $tclFileList {
    set fd [open $filename]

    while {-1 < [gets $fd line]} {
        # Search: [::msgcat "translation key"
	if {[regexp -- {\[mc[ \t\r\n]+\"([^\"]*)\"} $line whole key]} { 
	    if {![info exists keyHash($filename)]} {
		# Create a new list (with the current key) for this file
		set keyHash($filename) [list $key]
	    } elseif {[lsearch -exact $keyHash($filename) $key]<0} {
		# key doesn't exist for this file
		lappend keyHash($filename) $key
	    }
	} elseif {[regexp -- {\[::msgcat::mc[ \t\r\n]+\"([^\"]*)\"} $line whole key]} { 
            if {![info exists keyHash($filename)]} {
                # Create a new list (with the current key) for this file
                set keyHash($filename) [list $key]
            } elseif {[lsearch -exact $keyHash($filename) $key]<0} {
                # key doesn't exist for this file
                lappend keyHash($filename) $key
            }
        }
    }
    close $fd
}

# Remove duplicated keys (through all files)
set fileList [array names keyHash]
for {set i 0} {$i < [llength $fileList]} {incr i} {
    for {set j [expr $i + 1]} {$j < [llength $fileList]} {incr j} {
        foreach k $keyHash([lindex $fileList $i]) {
            set J [lindex $fileList $j]
            set ix [lsearch -exact $keyHash($J) $k]
            if {-1 < $ix} {
                set keyHash($J) [lreplace $keyHash($J) $ix $ix]
            }
        }
    }
}

if {0 != [string compare "" $translationFile]} {
    # Read translation file
    set fd [open $translationFile]
    set translated [list]

    while {-1 < [gets $fd line]} {
        # Search: ::msgcat::mcset lang "translation key"
        if {[regexp -- {::msgcat::mcset [a-zA-Z]+[ \t\r\n]+\"([^\"]*)\"} $line whole key]} {
            lappend translated $key
        }
    }
    close $fd

    if {false == $invertMatch} {
        # Display untranslated keys
        foreach f [array names keyHash] {
            set displayFileName true
            foreach k $keyHash($f) {
                if {-1 == [lsearch -exact $translated $k] } {
                    if {true == $displayFileName} {
                        set displayFileName false
                        puts "# $f"
                    }
                    puts "\"$k\""
                }
            }
            if {false == $displayFileName} {
                puts ""
            }
        }
    } else {
        # Remove useless keys
        foreach t $translated {
            set found false
            foreach f [array names keyHash] {
                if {-1 < [lsearch -exact $keyHash($f) $t] } {
                    set found true
                }
            }
            if {false == $found} {
                puts "\"$t\""
            }
        }
    }
} else {
    # Print result
    foreach f [array names keyHash] {
        if {0 < [llength $keyHash($f)]} {
            puts "# $f"
            foreach k $keyHash($f) {
                    puts "\"$k\""
            }
            puts ""
        }
    }
}