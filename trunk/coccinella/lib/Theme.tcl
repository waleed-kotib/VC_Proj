# Theme.tcl --
#
#       Some utitilty procedures useful when theming widgets and UI.
#       
#  Copyright (c) 2003-2005  Mats Bengtsson
#  
# $Id: Theme.tcl,v 1.21 2005-02-02 15:21:20 matben Exp $

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
        
    # Handle theme name and locale from prefs file.
    NameAndLocalePrefs
    
    # Priorities.
    # widgetDefault: 20
    # startupFile:   40
    # userDefault:   60
    # interactive:   80 (D)

    # Read resource database files in a hierarchical order.
    # 1) always read the default rdb file.
    # 2) read rdb file for this specific platform, if exists.
    # 3) read rdb file for any theme we have chosen. Search first
    #    inside the sources and then in the alternative user directory.
    option readfile [file join $this(resourcePath) default.rdb] startupFile
    set f [file join $this(resourcePath) $this(platform).rdb]
    if {[file exists $f]} {
	option readfile $f startupFile
    }
    set f [file join $this(resourcePath) $prefs(themeName).rdb]
    if {[file exists $f]} {
	option readfile $f userDefault
    }
    set f [file join $this(altResourcePath) $prefs(themeName).rdb]
    if {[file exists $f]} {
	option readfile $f userDefault
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
    PreLoadImages

}

proc ::Theme::NameAndLocalePrefs { } {
    global  this prefs
    
    set prefs(themeName)     ""
    set prefs(messageLocale) ""
    
    ::PreferencesUtils::Add [list  \
      [list prefs(themeName)      prefs_themeName      $prefs(themeName)] \
      [list prefs(messageLocale)  prefs_messageLocale  $prefs(messageLocale)] \
      ]    

    set appName    [option get . appName {}]
    set theAppName [option get . theAppName {}]
    if {$appName != ""} {
	set prefs(appName) $appName
    }
    if {$theAppName != ""} {
	set prefs(theAppName) $theAppName
    }
    if {![CanLoadTheme $prefs(themeName)]} {
	set prefs(themeName) ""
    }
}

proc ::Theme::CanLoadTheme {themeName} {
    global  this
    
    set ans 1
    set f [file join $this(resourcePath) ${themeName}CanLoad.tcl]
    if {[file exists $f]} {
	set ans [source $f]
    }
    return $ans
}

proc ::Theme::GetAllAvailable { } {
    global  this
    
    # Perhaps we should exclude 'default' and all platform specific ones?
    set allrsrc {}
    foreach f [glob -nocomplain -tails -directory $this(resourcePath) *.rdb] {
	set themeName [file rootname $f]
	if {[CanLoadTheme $themeName]} {
	    lappend allrsrc $themeName
	}
    }  
    foreach f [glob -nocomplain -tails -directory $this(altResourcePath) *.rdb] {
	set themeName [file rootname $f]
	if {[CanLoadTheme $themeName]} {
	    lappend allrsrc $themeName
	}
    }  
    return $allrsrc
}

proc ::Theme::PreLoadImages { } {
    
    foreach name [option get . themePreloadImages {}] {
	GetImage $name -keepname 1
    }
}

# ::Theme::GetImage --
# 
#       Searches for a gif image in a set of directories.
#       
#       Returns empty if not found, else the internal tk image name.
#       
#       Must have method to get .png images etc.
#       
# Arguments:
#       name      name of image file without suffix
#       args:
#            -keepname
#            -suffixes
#       
# Results:
#       empty or image name.

proc ::Theme::GetImage {name args} {
    global  this
    variable allImageSuffixes
    
    array set argsArr {
	-keepname 0
	-suffixes {}
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
	    foreach suff [concat $allImageSuffixes $argsArr(-suffixes)] {
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
	    if {$ans != ""} {
		break
	    }
	}
    } else {
	set ans $nsname
    }
    return $ans
}

# ::Theme::GetImageFromExisting --
# 
#       This is a method to first search for any image file using
#       the standard theme engine, but use an existing image as fallback.
#       The arrName($name) must be an existing image.

proc ::Theme::GetImageFromExisting {name arrName} {
    
    set imname [GetImage $name]
    if {$imname == ""} {

	# Call by name.
	upvar $arrName arr
	set imname $arr($name)
    }
    return $imname
}

#-------------------------------------------------------------------------------
