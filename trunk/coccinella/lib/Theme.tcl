# Theme.tcl --
#
#       Some utitilty procedures useful when theming widgets and UI.
#       
#  Copyright (c) 2003-2007  Mats Bengtsson
#  
# $Id: Theme.tcl,v 1.36 2007-04-26 14:15:45 matben Exp $

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
    variable fontopts
        
    # Handle theme name and locale from prefs file.
    NameAndLocalePrefs
    
    # Create named standard fonts.
    Fonts
    FontConfigSize $prefs(fontSizePlus)
    
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
    
    # My RH9 KDE system has some weird X rdb settings somewhere. Fix.
    if {[tk windowingsystem] eq "x11"} {
	option add *ChaseArrows.background        "#dcdad5" 60
	option add *Listbox.background            white     60
	option add *Listbox.highlightBackground   "#dcdad5" 60
	option add *Menu.background               "#dcdad5" 60
	option add *Text.background               white     60
	option add *Text.highlightBackground      "#dcdad5" 60
	option add *TreeCtrl.background           white     60
	option add *WaveLabel.background          "#dcdad5" 60
    }
    
    # Any theme specific resource files.
    foreach dir [list $this(themesPath) $this(altThemesPath)] {
	set rdir [file join $dir $prefs(themeName) $this(resources)]
	if {[file isdirectory $rdir]} {
	    option readfile [file join $rdir default.rdb] userDefault
	    set f [file join $rdir $this(platform).rdb]
	    if {[file exists $f]} {
		option readfile $f userDefault
	    }
	    break
	}
    }

    # Bug in 8.4.1 but ok in 8.4.9
    if {[regexp {^8\.4\.[0-5]$} [info patchlevel]]} {
	option add *TToolbar.styleText  Small.Plain      60
    }
	
    FontConfigStandard
    
    # Any named fonts from any resource file must be constructed.
    PostProcessFontDefs
}

# Theme::Fonts --
# 
#       Named fonts are created and configured for each platform.

proc ::Theme::Fonts { } {
    global  tcl_platform
    variable fontopts
    
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
	    variable smallsize 8
	    variable largesize 14

	    font configure CociDefaultFont   -family $family -size $size
	    font configure CociSmallFont     -family $family -size $smallsize
	    font configure CociSmallBoldFont -family $family -size $smallsize -weight bold
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
    set fontopts(family)    $family
    set fontopts(size)      $size
    set fontopts(smallsize) $smallsize
    set fontopts(largesize) $largesize
}

# Theme::FontConfigStandard --
# 
#       A resource file can override the standard font attributes as hardcoded
#       above.

proc ::Theme::FontConfigStandard {} {
    variable fontopts

    # Beware, resource names must start with lower case!
    foreach name {
	CociDefaultFont CociSmallFont CociSmallBoldFont CociTinyFont CociLargeFont
    } {
	set rname [string tolower [string index $name 0]][string range $name 1 end]
	set spec [option get . $rname {}]
	if {[string length $spec]} {
	    eval {font configure $name} $spec
	    if {$name eq "CociSmallFont"} {
		array set fontA [font configure $name]
		set fontopts(smallsize) $fontA(-size)
	    }
	}
    }
}

proc ::Theme::FontConfigSize {increase} {
    variable fontopts
    
    # @@@ Not sure how to handle the unnamed system fonts?
    if {$fontopts(smallsize) > 0} {
	set size [expr {$fontopts(smallsize) + $increase}]
    } else {
	set size [expr {$fontopts(smallsize) - $increase}]
    }
    font configure CociSmallFont -size $size
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
    set prefs(fontSizePlus)  0
    
    ::PrefUtils::Add [list  \
      [list prefs(themeName)      prefs_themeName      $prefs(themeName)] \
      [list prefs(messageLocale)  prefs_messageLocale  $prefs(messageLocale)] \
      [list prefs(fontSizePlus)   prefs_fontSizePlus   $prefs(fontSizePlus)] \
      ]    

    set appName    [option get . appName {}]
    set theAppName [option get . theAppName {}]
    if {$appName ne ""} {
	set prefs(appName) $appName
    }
    if {$theAppName ne ""} {
	set prefs(theAppName) $theAppName
    }
    
    # Check here that the theme folder still exists.
    set dir [file join $this(themesPath) $prefs(themeName)]
    if {![file isdirectory $dir]} {
	set dir [file join $this(altThemesPath) $prefs(themeName)]
	if {![file isdirectory $dir]} {
	    set prefs(themeName) ""
	}
    }
}

# ::Theme::GetAllAvailable --
# 
#       Finds all available themes.

proc ::Theme::GetAllAvailable { } {
    global  this
    
    set allThemes [list]
    foreach dir [list $this(themesPath) $this(altThemesPath)] {
	foreach name [glob -nocomplain -tails -types d -directory $dir *] {
	    switch -- $name {
		CVS {
		    # empty
		}
		KDE {
		    
		    # We can't get those fonts without 'xft'.
		    if {![catch {tk::pkgconfig get fontsystem} fs] && $fs eq "xft"} {
			lappend allThemes $name
		    }
		}
		default {
		    lappend allThemes $name
		}
	    }
	}
    }
    return $allThemes
}

# ::Theme::GetImage --
# 
#       Searches for an image file in a number of places in a well defined way:
#       
#         if themeName nonempty search any of these two:
#             coccinella/themes/themeName/subPath/
#             prefsPath/themes/themeName/subPath/
#           
#         but this is always searched and is our fallback:
#             coccinella/subPath/
#       
#       where subPath defaults to 'images'.
#       Only PNGs and GIFs are searched for, in that order. 
#       
# Arguments:
#       name      name of image file without suffix
#       subPath   sub path where to search, defaults to images
#       
# Results:
#       empty if not found, else the internal tk image name.

namespace eval ::Theme {
    
    variable iuid -1
    variable subPathMap
}

proc ::Theme::GetImage {name {subPath ""}} {
    global  prefs this
    variable subPathMap
    variable iuid
    
    if {$subPath eq ""} {
	set subPath $this(images)
    }

    # We avoid name collisions by creating a unique integer number
    # for each subPath and use this when designing the image name.
    # This keeps names much shorter.
    if {![info exists subPathMap($subPath)]} {
	set subPathMap($subPath) [incr iuid]
    }
    set nsname ::_img::$subPathMap($subPath)_$name
    set ans ""
    
    # Create only if not there already.
    if {[lsearch [image names] $nsname] == -1} {
	set theme $prefs(themeName)
	
	# Build up a list of search paths.
	set paths {}
	if {$theme ne ""} {
	    set dir [file join $this(themesPath) $theme]
	    if {[file isdirectory $dir]} {
		lappend paths [file join $dir $subPath]
	    } else {
		set dir [file join $this(altThemesPath) $theme]
		if {[file isdirectory $dir]} {
		    lappend paths [file join $dir $subPath]
		}
	    }
	}
	
	# This MUST always be searched for last since it is our fallback.
	lappend paths [file join $this(path) $subPath]
	
	set found 0
	foreach path $paths {
	    foreach fmt {png gif} {
		set f [file join $path ${name}.${fmt}]
		if {[file exists $f]} {
		    image create photo $nsname -file $f -format $fmt
		    set ans $nsname
		    set found 1
		    break
		}
	    }
	    if {$found} break
	}
    } else {
	set ans $nsname
    }
    return $ans
}

# ::Theme::GetImageWithNameEx--
# 
#       As GetImage above but keeps the image name 'name'.

proc ::Theme::GetImageWithNameEx {name {subPath ""}} {

    set imname [GetImage $name $subPath]
    if {$imname ne ""} {
	image create photo $name
	$name copy $imname
	image delete $imname
	set imname $name
    }
    return $imname
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
