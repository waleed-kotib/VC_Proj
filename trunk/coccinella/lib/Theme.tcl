# Theme.tcl --
#
#       Some utitilty procedures useful when theming widgets and UI.
#       
#  Copyright (c) 2003-2008  Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
# $Id: Theme.tcl,v 1.53 2008-05-15 14:14:57 matben Exp $

package provide Theme 1.0

namespace eval ::Theme {}

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

proc ::Theme::Init {} {
    global  this prefs
        
    # Handle theme name and locale from prefs file.
    NameAndLocalePrefs
    
    # Create named standard fonts.
    Fonts
    FontConfigSize $prefs(fontSizePlus)
    
    # Read widget resources.
    ReadResources    
}

proc ::Theme::ReadResources {} {
    global  this prefs
    
    # Priorities.
    # widgetDefault: 20
    # startupFile:   40
    # userDefault:   60
    # interactive:   80 (D)

    # Seems X11 has some system option db that must be overridden.
    if {[tk windowingsystem] eq "x11"} {
	set priority 60
    } else {
	set priority startupFile
    }

    # Read resource database files in a hierarchical order.
    # 1) always read the default rdb file.
    # 2) read rdb file for this specific platform, if exists.
    # 3) read rdb file for any theme we have chosen. Search first
    #    inside the sources and then in the alternative user directory.
    # 4) read any theme specific rdb file if exists (after tile loaded).
    option readfile [file join $this(resourcePath) default.rdb] $priority
    set f [file join $this(resourcePath) $this(platform).rdb]
    if {[file exists $f]} {
	option readfile $f $priority
    }
    
    # Any theme specific resource files.
    set dir [GetPath $prefs(themeName)]
    set rdir [file join $dir $prefs(themeName) $this(resources)]
    if {[file isdirectory $rdir]} {
	option readfile [file join $rdir default.rdb] userDefault
	set f [file join $rdir $this(platform).rdb]
	if {[file exists $f]} {
	    option readfile $f userDefault
	}
    }
}

# Theme::ReadTileResources --
# 
#       Read any standard tile theme specific resources, typically for Menu
#       and TreeCtrl.

proc ::Theme::ReadTileResources {} {
    global  this

    if {[tk windowingsystem] eq "x11"} {
	set priority 60
    } else {
	set priority startupFile
    }
    set f [file join $this(resourcePath) [GetCurrentTheme].rdb]
    if {[file exists $f]} {
	option readfile $f $priority
    }
}

# Theme::TileThemeChanged --
# 
#       This is a handler for tileutils ThemeChanged events which must be
#       invoked before widget specific handlers are.

proc ::Theme::TileThemeChanged {} {
    ReadResources
    ReadTileResources 

    # Configure any standard fonts the tile theme may have set.
    FontConfigStandard
    
    # Any named fonts from any resource file must be constructed.
    PostProcessFontDefs
}

# Theme::Fonts --
# 
#       Named fonts are created and configured for each platform.

proc ::Theme::Fonts {} {
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
		variable size -12
		variable smallsize -12
		variable largesize -22
	    } else {
		variable family "Helvetica"
		variable size -12
		variable smallsize -10
		variable largesize -18
	    }

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
		array set fontA [font actual $name]
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
    font configure CociSmallBoldFont -size $size

    if {$fontopts(size) > 0} {
	set size [expr {$fontopts(size) + $increase}]
    } else {
	set size [expr {$fontopts(size) - $increase}]
    }
    font configure CociDefaultFont -size $size
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

proc ::Theme::PostProcessFontDefs {} {
    
    foreach name [option get . fontNames {}] {
	catch {font create $name}
	set spec [option get . $name {}]
	if {$spec != {}} {
	    eval {font configure $name} [font actual $spec]
	}
    }
}

proc ::Theme::NameAndLocalePrefs {} {
    global  this prefs
    
    set prefs(themeName)     ""    ;# empty means we use this(themeDefault)
    set prefs(themeParent)   ""
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

proc ::Theme::GetAllAvailable {} {
    global  this
    
    set themes [list]
    foreach dir [list $this(themesPath) $this(altThemesPath)] {
	foreach name [glob -nocomplain -tails -types d -directory $dir *] {
	    if {$name eq "CVS"} { continue }
	    lappend themes $name
	}
    }
    
    # Exclude the default theme.
    return [lsearch -all -inline -not $themes $this(themeDefault)]
}

namespace eval ::Theme {
    variable themePaths
}

# Theme::GetPath --
#
#       Seraches for the given theme name in app bundle or prefs folder.
#       Returns sempty if not found. 
#       Internal usage only.

proc ::Theme::GetPath {theme} {
    global this
    
    set path ""
    set dir [file join $this(themesPath) $theme]
    if {[file isdirectory $dir]} {
	set path $dir
    } else {
	set dir [file join $this(altThemesPath) $theme]
	if {[file isdirectory $dir]} {
	    set path $dir
	}
    }
    return $path
}

# Theme::GetPathsForTheme --
#
#       Returns a list of paths for 'theme' and 'themeParent'.
#       Caches results.

proc ::Theme::GetPathsForTheme {theme themeParent} {
    global  this
    variable themePaths
    
    if {[info exists themePaths($theme)]} {
	set paths $themePaths($theme)
    } else {

	# Build up a list of search paths.
	set paths [list]
	if {$theme ne ""} {
	    set path [GetPath $theme]
	    if {$path ne ""} {
		lappend paths $path
	    }
	    if {$themeParent ne ""} {
		set path [GetPath $themeParent]
		if {$path ne ""} {
		    lappend paths $path
		}		
	    }
	}
	
	# This MUST always be searched for last since it is our fallback.
	lappend paths [file join $this(themesPath) $this(themeDefault)]
	set themePaths($theme) $paths
    }
    return $paths
}

proc ::Theme::GetPresentSearchPaths {} {
    global prefs
    return [GetPathsForTheme $prefs(themeName) $prefs(themeParent)]
}

# Theme::GetPathsFor --
#
#       Make a list of paths where we shall search for things like sounds
#       and emoticon sets. These are ordered so in some cases they shall
#       be searched for in reversed order.

proc ::Theme::GetPathsFor {subPath} {
    global this
    
    set paths [list]
    lappend paths [file join $this(path) $subPath]
    set path [file join $this(themesPath) $subPath]
    if {[file isdirectory $path]} {
	lappend paths $path
    }
    lappend paths [file join $this(prefsPath) $subPath]
    set path [file join $this(altThemesPath) $subPath]
    if {[file isdirectory $path]} {
	lappend paths $path
    }
    return $paths
}

# Theme::FindIcon, FindIconWithName --
#
#       Searches for image using complex dir specifier.
#       spec is typically icons/32x32/send which is a sub path to an image file
#       but without any file suffix.

proc ::Theme::FindIcon {spec} {
    
    # The image create a command as well which must be namespaced due
    # to its design flaw.
    return [FindIconWithName $spec ::theme::$spec]
}

proc ::Theme::FindIconWithName {spec name} {
    
    set image ""
#    if {$image ni [image names]}
    if {[lsearch -exact [image names] $name] < 0} {
	set paths [GetPresentSearchPaths]
	set found 0

	foreach path $paths {
	    foreach fmt {png gif} {
		set f [file join $path $spec].$fmt
		
		# We provide a single step fallback: 
		#   list-add-user-Dis -> list-add-user   etc.
		if {![file exists $f]} {
		    set tail [file tail $spec]
		    set parts [split $tail -]
		    if {[llength $parts] > 1} {
			set f [join [lrange [split $spec /] 0 end-1] /]
			append f / [join [lrange $parts 0 end-1] -]
			set f [file join $path $f].$fmt
		    }
		}
		if {[file exists $f]} {
		    image create photo $name -file $f -format $fmt
		    set image $name
		    set found 1
		    break
		}
	    }
	    if {$found} { break }
	}
    } else {
	set image $name
    }
    return $image
}

# Theme::FindExactIconFile --
# 
#       Searches the exact image name and returns its complete path if found.

proc ::Theme::FindExactIconFile {subPath} {
    
    foreach path [GetPresentSearchPaths] {
	set f [file join $path $subPath]
	if {[file exists $f]} {
	    return $f
	}
    }
    return
}

# Theme::FindIconFileWithSuffixes --
# 
#       Searches each path for matching image file with any of the suffixes.
#       Note the search order where the search paths have higher precedence
#       than the image formats.

proc ::Theme::FindIconFileWithSuffixes {spec suffL} {

    foreach path [GetPresentSearchPaths] {
	foreach suff $suffL {
	    set f [file join $path $spec$suff]
	    if {[file exists $f]} {
		return $f
	    }
	}
    }    
    return
}

proc ::Theme::FindIconSize {size name} {
    return [FindIcon icons/${size}x${size}/$name]
}

# Theme::Find16Icon, Find32Icon, Find64Icon --
#
#       Helper functions which look up images using the resource database.

proc ::Theme::Find16Icon {w resource} {    
    set rsrc [option get $w $resource {}]
    if {$rsrc ne ""} {
	return [FindIcon icons/16x16/[option get $w $resource {}]]
    } 
    return
}

proc ::Theme::Find32Icon {w resource} {    
    set rsrc [option get $w $resource {}]
    if {$rsrc ne ""} {
	return [FindIcon icons/32x32/[option get $w $resource {}]]
    } 
    return
}

proc ::Theme::Find64Icon {w resource} {    
    set rsrc [option get $w $resource {}]
    if {$rsrc ne ""} {
	return [FindIcon icons/64x64/[option get $w $resource {}]]
    } 
    return
}

proc ::Theme::Find128Icon {w resource} {    
    set rsrc [option get $w $resource {}]
    if {$rsrc ne ""} {
	return [FindIcon icons/128x128/[option get $w $resource {}]]
    } 
    return
}

proc ::Theme::Create16IconWithName {w resource} {
    set rsrc [option get $w $resource {}]
    if {$rsrc ne ""} {
	return [FindIconWithName icons/16x16/$rsrc $rsrc]
    } 
    return
}

#-------------------------------------------------------------------------------
