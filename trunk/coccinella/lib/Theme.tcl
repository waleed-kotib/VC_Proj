# Theme.tcl --
#
#       Some utitilty procedures useful when theming widgets and UI.
#       
#  Copyright (c) 2003-2005  Mats Bengtsson
#  
# $Id: Theme.tcl,v 1.25 2005-11-02 12:54:09 matben Exp $

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
    
    # Create named standard fonts.
    Fonts
    
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
    if {$themeDir ne ""} {
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
    if {$themeImageSuffixes ne ""} {
	set ind [lsearch $themeImageSuffixes .gif]
	if {$ind >= 0} {
	    set themeImageSuffixes [lreplace $themeImageSuffixes $ind $ind]
	}
    }
    set this(themeImageSuffixes) ""
    if {$themeImageSuffixes ne ""} {
	set this(themeImageSuffixes) $themeImageSuffixes
    }
    set allImageSuffixes [concat .png .gif $themeImageSuffixes]

    # Make all images used for widgets that doesn't use the Theme package.
    PreLoadImages

    # Any named fonts from any resource file must be constructed.
    PostProcessFontDefs
}

# Theme::Fonts --
# 
#       Named fonts are created and configured for each platform.

proc ::Theme::Fonts { } {
    global  tcl_platform
    
    catch {font create CociDefaultFont}
    catch {font create CociSmallFont}
    catch {font create CociSmallBoldFont}
    catch {font create CociTinyFont}
    catch {font create CociLargeFont}

    switch -- [tk windowingsystem] {
	win32 {
	    if {$tcl_platform(osVersion) >= 5.0} {
		variable family "Tahoma"
	    } else {
		variable family "MS Sans Serif"
	    }
	    variable size 8
	    variable largesize 14

	    font configure CociDefaultFont   -family $family -size $size
	    font configure CociSmallFont     -family $family -size $size
	    font configure CociSmallBoldFont -family $family -size $size -weight bold
	    font configure CociTinyFont      -family $family -size $size
	    font configure CociLargeFont     -family $family -size $largesize
	}
	aqua {
	    variable family "Lucida Grande"
	    variable size 13
	    variable viewsize 12
	    variable smallsize 11
	    variable largesize 18

	    font configure CociDefaultFont   -family $family -size $size
	    font configure CociSmallFont     -family $family -size $smallsize
	    font configure CociSmallBoldFont -family $family -size $smallsize -weight bold
	    font configure CociTinyFont      -family Geneva  -size 9
	    font configure CociLargeFont     -family $family -size $largesize
	}
	x11 {
	    if {![catch {tk::pkgconfig get fontsystem} fs] && $fs eq "xft"} {
		variable family "sans-serif"
	    } else {
		variable family "Helvetica"
	    }
	    variable size -12
	    variable smallsize -10
	    variable largesize -18

	    font configure CociDefaultFont   -family $family -size $size
	    font configure CociSmallFont     -family $family -size $smallsize
	    font configure CociSmallBoldFont -family $family -size $smallsize -weight bold
	    font configure CociTinyFont      -family $family -size $size
	    font configure CociLargeFont     -family $family -size $largesize
	}
    }
}

# Theme::PostProcessFontDefs --
# 
#       If a resource file specifies a font as:
#       
#       *fontNames:        myCoolFont ...
#       *myCoolFont:       {Helvetica 24 bold}
#       
#       then the actual font with that name is constructed here.
#       Note: Must start with LOWER case!

proc ::Theme::PostProcessFontDefs { } {
    
    foreach name [option get . fontNames {}] {
	catch {font create $name}
	set spec [option get . $name {}]
	if {$spec != {}} {
	    eval {font configure $name} [font actual $spec]
	}
    }
}

proc ::Theme::NameAndLocalePrefs { } {
    global  this prefs
    
    set prefs(themeName)     ""
    set prefs(messageLocale) ""
    
    ::PrefUtils::Add [list  \
      [list prefs(themeName)      prefs_themeName      $prefs(themeName)] \
      [list prefs(messageLocale)  prefs_messageLocale  $prefs(messageLocale)] \
      ]    

    set appName    [option get . appName {}]
    set theAppName [option get . theAppName {}]
    if {$appName ne ""} {
	set prefs(appName) $appName
    }
    if {$theAppName ne ""} {
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
#       Returns empty if not found, else the internal tk image name.
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
	set nsname ::_img::$name
    }
    set ans ""
	
    # Create only if not there already.
    if {[lsearch [image names] $nsname] == -1} {
	
	# Search dirs in order.
	foreach dir $this(imagePathList) {
	    foreach suff [concat $allImageSuffixes $argsArr(-suffixes)] {
		set f [file join $dir ${name}${suff}]
		if {[file exists $f]} {
		    if {[string equal $suff .png]} {
			image create photo $nsname -file $f -format png
		    } elseif {[string equal $suff .gif]} {
			image create photo $nsname -file $f -format gif
		    } else {
			image create photo $nsname -file $f
		    }
		    set ans $nsname
		    break
		}
	    }
	    if {$ans ne ""} {
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
    if {$imname eq ""} {

	# Call by name.
	upvar $arrName arr
	set imname $arr($name)
    }
    return $imname
}

#-------------------------------------------------------------------------------
