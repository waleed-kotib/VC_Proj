# Theme.tcl --
#
#       Some utitilty procedures useful when theming widgets and UI.
#       
#  Copyright (c) 2003  Mats Bengtsson
#  
# $Id: Theme.tcl,v 1.5 2003-12-23 14:41:01 matben Exp $

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
    
    foreach name [option get . themePreloadImages {}] {
	::Theme::GetImage $name -keepname 1
    }
}

# ::Theme::GetImage --
# 
#       Searches for a gif image in a set of directories.
#       
#       Returns empty if not found, else the internal tk image name.

proc ::Theme::GetImage {name args} {
    global  this
    
    array set argsArr {
	-keepname 0
    }
    array set argsArr $args    
    
    # It is recommended to create images in an own namespace since they 
    # may silently overwrite any existing command!
    if {$argsArr(-keepname)} {
	set nsname $name
    } else {
	set nsname ::_img::${name}
    }
    set ans ""
	
    if {[lsearch [image names] $nsname] == -1} {
	foreach dir $this(imagePathList) {
	    set f [file join $dir ${name}.gif]
	    if {[file exists $f]} {
		image create photo $nsname -file $f -format gif
		set ans $nsname
		break
	    }
	}
    } else {
	set ans $nsname
    }
    return $ans
}

#-------------------------------------------------------------------------------
