# Theme.tcl --
#
#       Some utitilty procedures useful when theming widgets and UI.
#       
#  Copyright (c) 2003  Mats Bengtsson
#  
# $Id: Theme.tcl,v 1.2 2003-12-16 15:03:53 matben Exp $

package provide Theme 1.0

namespace eval ::Theme:: {

}


proc ::Theme::ReadPrefsFile { } {
    global  this prefs
    
    if {[file exists $this(themePrefsPath)]} {
	option readfile $this(themePrefsPath)
    }
    set prefs(themeName) [option get . themeName {}]   
}

proc ::Theme::SavePrefsFile { } {
    global  this prefs
    
    # Work on a temporary file and switch later.
    set tmpFile $this(themePrefsPath).tmp
    if {[catch {open $tmpFile w} fid]} {
	tk_messageBox -icon error -type ok -message \
	  [FormatTextForMessageBox [::msgcat::mc messerrpreffile $tmpFile]]
	return
    }
    
    # Header information.
    puts $fid "!\n!   User preferences for the theme name."
    puts $fid "!   The data written at: [clock format [clock seconds]]\n!"
    
    puts $fid [format "%-24s\t%s" *themeName: $prefs(themeName)]
    
    close $fid
    if {[catch {file rename -force $tmpFile $this(themePrefsPath)} msg]} {
	tk_messageBox -type ok -message {Error renaming preferences file.}  \
	  -icon error
	return
    }
}

proc ::Theme::PreLoadImages { } {
    global  this
    
    foreach name [option get . themePreloadImages {}] {
	::Theme::GetImage $name
    }
}

proc ::Theme::GetImage {name} {
    global  this
	
    if {[lsearch [image names] $name] == -1} {
	foreach dir $this(imagePathList) {
	    set f [file join $dir ${name}.gif]
	    if {[file exists $f]} {
		image create photo $name -file $f -format gif
		break
	    }
	}
    }
    
    # We could return a different name here. Problems when preloading...
    return $name
}

#-------------------------------------------------------------------------------
