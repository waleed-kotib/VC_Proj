# Theme.tcl --
#
#       Some utitilty procedures useful when theming widgets and UI.
#       
#  Copyright (c) 2003  Mats Bengtsson
#  
# $Id: Theme.tcl,v 1.9 2004-02-12 08:48:26 matben Exp $

package provide Theme 1.0

namespace eval ::Theme:: {

}

# Theme::Init --
#
#       Reads all resource database files, also any theme rdb file.
#       Does a lot of init bookkeeping as well.
#       
# Arguments:
#       none
#       
# Results:
#       none

proc ::Theme::Init { } {
    global  this prefs
    variable allImageSuffixes
    
    ::Theme::ReadPrefsFile

    # Read resource database files in a hierarchical order.
    # 1) always read the default rdb file.
    # 2) read rdb file for this specific platform, if exists.
    # 3) read rdb file for any theme we have chosen. Search first
    #    inside the sources and then in the alternative user directory.
    option readfile [file join $this(resourcedbPath) default.rdb] startupFile
    set f [file join $this(resourcedbPath) $this(platform).rdb]
    if {[file exists $f]} {
	option readfile $f startupFile
    }
    set f [file join $this(resourcedbPath) $prefs(themeName).rdb]
    if {[file exists $f]} {
	option readfile $f startupFile
    }
    set f [file join $this(altResourcedbPath) $prefs(themeName).rdb]
    if {[file exists $f]} {
	option readfile $f startupFile
    }

    # Search for image files in this order:
    # 1) altImagePath/themeImageDir
    # 2) imagePath/themeImageDir
    # 3) imagePath/platformName
    # 4) imagePath
    set this(imagePathList) {}
    set themeDir [option get . themeImageDir {}]
    if {$themeDir != ""} {
	set dir [file join $this(altImagePath) $themeDir]
	if {[file isdirectory $dir]} {
	    lappend this(imagePathList) $dir
	}
	set dir [file join $this(imagePath) $themeDir]
	if {[file isdirectory $dir]} {
	    lappend this(imagePathList) $dir
	}
    }
    lappend this(imagePathList)  \
      [file join $this(imagePath) $this(platform)] $this(imagePath)

    # Figure out if additional image formats needed.
    set themeImageSuffixes [option get . themeImageSuffixes {}]
    if {$themeImageSuffixes != ""} {
	set ind [lsearch $themeImageSuffixes .gif]
	if {$ind >= 0} {
	    set themeImageSuffixes [lreplace $themeImageSuffixes $ind $ind]
	}
    }
    set this(themeImageSuffixes) ""
    if {$themeImageSuffixes != ""} {
	set this(themeImageSuffixes) $themeImageSuffixes
    }
    set allImageSuffixes [concat .gif $themeImageSuffixes]

    # Make all images used for widgets that doesn't use the Theme package.
    ::Theme::PreLoadImages

}

proc ::Theme::ReadPrefsFile { } {
    global  this prefs
    
    if {[file exists $this(themePrefsPath)]} {
	option readfile $this(themePrefsPath)
    }
    set themeName [option get . themeName {}] 
    if {[::Theme::CanLoadTheme $themeName]} {
	set prefs(themeName) $themeName
    } else {
	set prefs(themeName) ""
    }
    set prefs(messageLocale) [option get . messageLocale {}] 
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
    puts $fid "!\n!   User preferences for the theme name and locale."
    puts $fid "!   The data written at: [clock format [clock seconds]]\n!"
    
    puts $fid [format "%-24s\t%s" *themeName: $prefs(themeName)]
    puts $fid [format "%-24s\t%s" *messageLocale: $prefs(messageLocale)]
    
    close $fid
    if {[catch {file rename -force $tmpFile $this(themePrefsPath)} msg]} {
	tk_messageBox -type ok -message {Error renaming preferences file.}  \
	  -icon error
	return
    }
}

proc ::Theme::CanLoadTheme {themeName} {
    global  this
    
    set ans 1
    set f [file join $this(resourcedbPath) ${themeName}CanLoad.tcl]
    if {[file exists $f]} {
	set ans [source $f]
    }
    return $ans
}

proc ::Theme::GetAllAvailable { } {
    global  this
    
    set allrsrc {}
    foreach f [glob -nocomplain -tails -directory $this(resourcedbPath) *.rdb] {
	set themeName [file rootname $f]
	if {[::Theme::CanLoadTheme $themeName]} {
	    lappend allrsrc $themeName
	}
    }  
    foreach f [glob -nocomplain -tails -directory $this(altResourcedbPath) *.rdb] {
	set themeName [file rootname $f]
	if {[::Theme::CanLoadTheme $themeName]} {
	    lappend allrsrc $themeName
	}
    }  
    return $allrsrc
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
#       
#       Must have method to get .png images etc.

proc ::Theme::GetImage {name args} {
    global  this
    variable allImageSuffixes
    
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
	
    # Create only if not there already.
    if {[lsearch [image names] $nsname] == -1} {
	
	# Search dirs in order.
	foreach dir $this(imagePathList) {
	    foreach suff $allImageSuffixes {
		set f [file join $dir ${name}${suff}]
		if {[file exists $f]} {
		    if {[string equal $suff .gif]} {
			image create photo $nsname -file $f -format gif
		    } else {
			image create photo $nsname -file $f
		    }
		    set ans $nsname
		    break
		}
	    }
	    if {[string length $ans]} {
		break
	    }
	}
    } else {
	set ans $nsname
    }
    return $ans
}

#-------------------------------------------------------------------------------
