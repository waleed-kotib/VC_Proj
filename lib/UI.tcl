#  UI.tcl ---
#  
#      This file is part of The Coccinella application. It implements user
#      interface elements.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: UI.tcl,v 1.59 2004-06-11 07:44:44 matben Exp $

package require entrycomp


namespace eval ::UI:: {

    # Icons
    option add *buttonOKImage            buttonok       widgetDefault
    option add *buttonCancelImage        buttoncancel   widgetDefault
    
    variable wThatUseMainMenu {}

    # components stuff.
    variable menuSpecPublic
    set menuSpecPublic(wpaths) {}
}

# UI::Init --
# 
#       Various initializations for the UI stuff.

proc ::UI::Init {} {
    global  this prefs
    
    ::Debug 2 "::UI::Init"    
    
    # Standard button icons.
    ::Theme::GetImage [option get . buttonOKImage {}] -keepname 1
    ::Theme::GetImage [option get . buttonCancelImage {}] -keepname 1    
}

# UI::InitMenuDefs --
# 
#       The menu organization. Only least common parts here,
#       that is, the Apple menu.

proc ::UI::InitMenuDefs { } {
    global  prefs this
    variable menuDefs

	
    if {[string match "mac*" $this(platform)] && $prefs(haveMenus)} {
	set haveAppleMenu 1
    } else {
	set haveAppleMenu 0
    }
    
    # All menu definitions for the main (whiteboard) windows as:
    #      {{type name cmd state accelerator opts} {{...} {...} ...}}

    set menuDefs(main,info,aboutwhiteboard)  \
      {command   mAboutCoccinella    {::SplashScreen::SplashScreen} normal   {}}
    set menuDefs(main,info,aboutquicktimetcl)  \
      {command   mAboutQuickTimeTcl  {::Dialogs::AboutQuickTimeTcl}                normal   {}}

    # Mac only.
    set menuDefs(main,apple) [list \
      $menuDefs(main,info,aboutwhiteboard)  \
      $menuDefs(main,info,aboutquicktimetcl)]
    
    # Make platform specific things and special menus etc. Indices!!! BAD!
    if {$haveAppleMenu && ![::Plugins::HavePackage QuickTimeTcl]} {
	lset menuDefs(main,apple) 1 3 disabled
    }
}

#proc ::UI::GetIcon {name} {
#    
#    return [::Theme::GetImageFromExisting $name ::UI::icons]
#}

proc ::UI::GetIcon {name} {
    variable icons
    
    if {[info exists icons($name)]} {
	return $icons($name)
    } else {
	return -code error "icon named \"$name\" does not exist"
    }
}

# UI::AEQuitHandler --
#
#       Mac OS X only: callback for the quit Apple Event.

proc ::UI::AEQuitHandler {theAEDesc theReplyAE} {
    
    ::UserActions::DoQuit
}

proc ::UI::GetScreenSize { } {
    
    return [list [winfo vrootwidth .] [winfo vrootheight .]]
}

# UI::Toplevel --
# 
#       Wrapper for making a toplevel window.
#       
# Arguments:
#       w
#       args:
#       -class  
#       -macstyle:
#           macintosh (classic) and macosx
#           documentProc, dBoxProc, plainDBox, altDBoxProc, movableDBoxProc, 
#           zoomDocProc, rDocProc, floatProc, floatZoomProc, floatSideProc, 
#           or floatSideZoomProc
#       -macclass
#           macosx only; {class attributesList} 
#           class = alert moveableAlert modal moveableModal floating document
#           help toolbar
#           attributes = closeBox noActivates horizontalZoom verticalZoom 
#           collapseBox resizable sideTitlebar noUpdates noActivates
#       -usemacmainmenu

proc ::UI::Toplevel {w args} {
    global  this osprefs
    
    array set argsArr {
	-usemacmainmenu   0
    }
    array set argsArr $args
    set topopts {}
    if {[info exists argsArr(-class)]} {
	lappend topopts -class $argsArr(-class)
    }
    eval {toplevel $w} $topopts
        
    # We direct all close events through DoCloseWindow so things can
    # be handled from there.
    wm protocol $w WM_DELETE_WINDOW [list ::UI::DoCloseWindow $w]
    
    if {[string equal $this(platform) "macintosh"]} {
	foreach {key value} $args {	    
	    switch -- $key {
		-usemacmainmenu {
		    if {$argsArr(-usemacmainmenu)} {
			::UI::MacUseMainMenu $w
		    }
		}
		-macstyle {
		    eval {::tk::unsupported::MacWindowStyle style $w}  \
		      $argsArr(-macstyle)
		}
	    }
	}
    } elseif {[string equal $this(platform) "macosx"]} {
	if {[info exists argsArr(-macclass)]} {
	    eval {::tk::unsupported::MacWindowStyle style $w}  \
	      $argsArr(-macclass)
	} elseif {[info exists argsArr(-macstyle)]} {
	    ::tk::unsupported::MacWindowStyle style $w $argsArr(-macstyle)
	}
	if {$argsArr(-usemacmainmenu)} {
	    ::UI::MacUseMainMenu $w
	}
    } else {
	bind $w <$osprefs(mod)-Key-w> [list ::UI::DoCloseWindow $w]
    }
    return $w
}

# UI::DoCloseWindow --
#
#       Take special actions before a window is closed.
#       
#       Notes: There are three ways to close a window:
#       1) from the menus Close Window command
#       2) using the menu keyboard shortcut command/control-w
#       3) clicking the menus close button
#       
#       If any cleanup etc. is necessary all three must execute the same code.
#       In case where window must not be destroyed a hook must be registered
#       that returns stop.
#       Default behaviour when no hook registered is to destroy window.

proc ::UI::DoCloseWindow {{wevent {}}} {
    
    set wfocus [focus]
    if {$wfocus != ""} {
	set w [winfo toplevel [focus]]
    
	Debug 2 "::UI::DoCloseWindow winfo class $w=[winfo class $w]"
    
	# Run hooks. Only the one corresponding to the $w needs to act!
	set result [::hooks::run closeWindowHook $w]    
	if {![string equal $result "stop"]} {
	    destroy $w
	}
    }
}

# UI::GetToplevelNS --
#
#       Returns the toplevel widget from any descendent, but with an extra
#       dot appended except for ".".

proc ::UI::GetToplevelNS {w} {

    set wtop [winfo toplevel $w]
    if {[string equal $wtop "."]} {
	return $wtop
    } else {
	return "${wtop}."
    }
}

proc ::UI::GetToplevel {w} {

    if {[string equal $w "."]} {
	return $w
    } else {
	set w [string trimright $w "."]
	return [winfo toplevel $w]
    }
}

proc ::UI::ScrollSet {wscrollbar geocmd offset size} {
    
    if {($offset != 0.0) || ($size != 1.0)} {
	eval $geocmd
	$wscrollbar set $offset $size
    } else {
	set manager [lindex $geocmd 0]
	$manager forget $wscrollbar
    }
}

# UI::SaveWinGeom, SaveWinPrefixGeom --
#
#       Call this when closing window to store its geometry if exists.
#
# Arguments:
#       key         toplevel or entry in storage array.
#       w           (D="") if set then 'key' is only entry in array, while 'w'
#                   is the actual toplevel window.
# 

proc ::UI::SaveWinGeom {key {w {}}} {
    global  prefs
    
    if {$w == ""} {
	set w $key
    }
    if {[winfo exists $w]} {
	set prefs(winGeom,$key) [wm geometry $w]
    }
}

proc ::UI::SaveWinPrefixGeom {wprefix {key ""}} {
    
    if {$key == ""} {
	set key $wprefix
    }
    set win [::UI::GetFirstPrefixedToplevel $wprefix]
    if {$win != ""} {
	::UI::SaveWinGeom $key $win
    }	
}

proc ::UI::SaveWinGeomUseSize {key geom} {
    global  prefs
    
    set prefs(winGeom,$key) $geom
}

# UI::SavePanePos --
#
#       Same for pane positions.

proc ::UI::SavePanePos {key wpaned {orient horizontal}} {
    global  prefs
    
    if {[winfo exists $wpaned]} {
	array set infoArr [::pane::pane info $wpaned]
	if {[string equal $orient "horizontal"]} {
	    set prefs(paneGeom,$key)   \
	      [list $infoArr(-relheight) [expr 1.0 - $infoArr(-relheight)]]
	} else {
	    
	    # Vertical
	    set prefs(paneGeom,$key)   \
	      [list $infoArr(-relwidth) [expr 1.0 - $infoArr(-relwidth)]]
	}
    }
}

proc ::UI::SetWindowPosition {w {key ""}} {
    global  prefs
    
    if {$key == ""} {
	set key $w
    }
    if {[info exists prefs(winGeom,$key)]} {
	regexp {^[^+-]+((\+|-).+$)} $prefs(winGeom,$key) match pos
	wm geometry $w $pos
    }
}

proc ::UI::SetWindowGeometry {w {key ""}} {
    global  prefs
    
    if {$key == ""} {
	set key $w
    }
    if {[info exists prefs(winGeom,$key)]} {
	wm geometry $w $prefs(winGeom,$key)
    }
}

proc ::UI::GetFirstPrefixedToplevel {wprefix} {
    
    set win ""
    set wins [lsearch -all -inline -glob [winfo children .] ${wprefix}*]
    if {[llength $wins]} {
	
	# 1st priority, pick if on top.
	set wfocus [focus]
	if {$wfocus != ""} {
	    set win [winfo toplevel $wfocus]
	}
	set win [lsearch -inline $wins $wfocus]
	if {$win == ""} {
	    
	    # 2nd priority, just get first in list.
	    set win [lindex $wins 0]
	}
    }
    return $win
}

proc ::UI::GetPrefixedToplevels {wprefix} {
    
    return [lsort -dictionary \
      [lsearch -all -inline -glob [winfo children .] ${wprefix}*]]
}

# UI::NewMenu --
# 
#       Creates a new menu from a previously defined menu definition list.
#       
# Arguments:
#       wtop        toplevel window. ("." or ".main2." with extra dot!)
#       wmenu       the menus widget path name (".menu.file" etc.).
#       label       its label.
#       menuSpec    a hierarchical list that defines the menu content.
#                   {{type name cmd state accelerator opts} {{...} {...} ...}}
#       state       'normal' or 'disabled'.
#       args        form ?-varName value? list that defines local variables to set.
#       
# Results:
#       $wmenu

proc ::UI::NewMenu {wtop wmenu label menuSpec state args} {    
    variable mapWmenuToWtop
    variable cachedMenuSpec
        
    # Need to cache the complete menuSpec's since needed in MenuMethod.
    set cachedMenuSpec($wtop,$wmenu) $menuSpec
    set mapWmenuToWtop($wmenu)       $wtop

    eval {::UI::BuildMenu $wtop $wmenu $label $menuSpec $state} $args
}

# UI::BuildMenu --
#
#       Make menus recursively from a hierarchical menu definition list.
#       Only called from ::UI::NewMenu!
#
# Arguments:
#       wtop        toplevel window. ("." or ".main2." with extra dot!)
#       wmenu       the menus widget path name (".menu.file" etc.).
#       label       its label.
#       menuDef     a hierarchical list that defines the menu content.
#                   {{type name cmd state accelerator opts} {{...} {...} ...}}
#       state       'normal' or 'disabled'.
#       args        form ?-varName value? list that defines local variables to set.
#       
# Results:
#       $wmenu

proc ::UI::BuildMenu {wtop wmenu label menuDef state args} {
    global  this wDlgs prefs osprefs

    variable menuKeyToIndex
    
    if {$wtop == "."} {
	set topw .
    } else {
	set topw [string trimright $wtop "."]
    }
    set m [menu $wmenu -tearoff 0]
    set wparent [winfo parent $wmenu]
    
    foreach {optName value} $args {
	set varName [string trimleft $optName "-"]
	set $varName $value
    }

    # A trick to make this work for popup menus, which do not have a Menu parent.
    if {[string equal [winfo class $wparent] "Menu"]} {
	$wparent add cascade -label [::msgcat::mc $label] -menu $m
    }
    
    # If we don't have a menubar, for instance, if embedded toplevel.
    # Only for the toplevel menubar.
    if {[string equal $wparent ".menu"] &&  \
      [string equal [winfo class $wparent] "Frame"]} {
	label ${wmenu}la -text [::msgcat::mc $label]
	pack ${wmenu}la -side left -padx 4
	bind ${wmenu}la <Button-1> [list ::UI::DoTopMenuPopup %W $wtop $wmenu]
    }
    
    set mod $osprefs(mod)
    set i 0
    foreach line $menuDef {
	foreach {type name cmd mstate accel mopts subdef} $line {
	    
	    # Localized menu label.
	    set locname [::msgcat::mc $name]
	    set menuKeyToIndex($wmenu,$name) $i
	    set ampersand [string first & $locname]
	    if {$ampersand != -1} {
		regsub -all & $locname "" locname
		lappend mopts -underline $ampersand
	    }
	    if {[string match "sep*" $type]} {
		$m add separator
	    } elseif {[string equal $type "cascade"]} {
		
		# Make cascade menu recursively.
		regsub -all -- " " [string tolower $name] "" mt
		regsub -all -- {\.} $mt "" mt
		eval {::UI::BuildMenu $wtop ${wmenu}.${mt} $name $subdef $state} \
		  $args
		
		# Explicitly set any disabled state of cascade.
		::UI::MenuMethod $m entryconfigure $name -state $mstate
	    } else {
		
		# All variables (and commands) in menuDef's cmd shall be 
		# substituted! Be sure they are all in here.
		set cmd [subst -nocommands $cmd]
		if {[string length $accel]} {
		    lappend mopts -accelerator ${mod}+${accel}

		    # Cut, Copy & Paste handled by widgets internally!
		    if {![string equal $this(platform) "macintosh"] \
		      && ![regexp {(X|C|V)} $accel]} {
			set key [string map {< less > greater}  \
			  [string tolower $accel]]
			
			if {[string equal $state "normal"]} {
			    if {[string equal $mstate "normal"]} {
				bind $topw <${mod}-Key-${key}> $cmd
			    }
			} else {
			    bind $topw <${mod}-Key-${key}> {}
			}			
		    }
		}
		eval {$m add $type -label $locname -command $cmd -state $mstate} \
		  $mopts 
	    }
	}
	incr i
    }
    return $wmenu
}

proc ::UI::FreeMenu {wtop} {
    variable mapWmenuToWtop
    variable cachedMenuSpec
    variable menuKeyToIndex
    
    foreach key [array names cachedMenuSpec "$wtop,*"] {
	set wmenu [string map [list "$wtop," ""] $key]
	unset mapWmenuToWtop($wmenu)
	array unset menuKeyToIndex "$wmenu,*"
    }
    array unset cachedMenuSpec "$wtop,*"
}

# UI::MenuMethod --
#  
#       Utility to use instead of 'menuPath cmd index args' since it
#       handles menu accelerators as well.
#
# Arguments:
#       wmenu       menu's widget path
#       cmd         valid menu command
#       key         key to menus index (mOpen etc.)
#       args
#       
# Results:
#       binds to toplevel changed

proc ::UI::MenuMethod {wmenu cmd key args} {
    global  this prefs wDlgs osprefs
            
    variable menuKeyToIndex
    variable mapWmenuToWtop
    variable cachedMenuSpec
    variable wThatUseMainMenu
        
    # Need to cache the complete menuSpec's since needed in MenuMethod.
    set wtop     $mapWmenuToWtop($wmenu)
    set menuSpec $cachedMenuSpec($wtop,$wmenu)
    set mind     $menuKeyToIndex($wmenu,$key)
    
    # This would be enough unless we needed to work with accelerator keys.
    eval {$wmenu $cmd $mind} $args
    
    # Handle any menu accelerators as well. 
    # Make sure the necessary variables for the command exist here!
    if {[string equal $this(platform) "macintosh"]} {
	return
    }
    if {$wtop == "."} {
	set topw .
	
	# Handle Macs that use the main menu.
	if {[string equal $this(platform) "macosx"]} {
	    set wtmp $wThatUseMainMenu
	    set wThatUseMainMenu {}
	    foreach wmac $wtmp {
		if {[winfo exists $wmac]} {
		    lappend wThatUseMainMenu $wmac
		}
	    }
	    set topw [concat . $wThatUseMainMenu]
	}	
    } else {
	set topw [string trimright $wtop "."]
    }
	    
    foreach {key val} $args {
	    
	switch -- $key {
	    -state {
		set mcmd [lindex $menuSpec $mind 2]
		set mcmd [subst -nocommands $mcmd]
		set acc [lindex $menuSpec $mind 4]

		# Cut, Copy & Paste handled by widgets internally!
		if {[string length $acc] && ![regexp {(X|C|V)} $acc]} {
		    set acckey [string map {< less > greater}  \
		      [string tolower $acc]]
		    foreach w $topw {
			if {[string equal $val "normal"]} {
			    bind $w <$osprefs(mod)-Key-${acckey}> $mcmd
			} else {
			    bind $w <$osprefs(mod)-Key-${acckey}> {}
			}
		    }
		}
	    }
	}
    }
}

# UI::MacUseMainMenu --
# 
#       Used on MacOSX to set accelerator keys for a toplevel that inherits
#       the menu from ".".
#       
# Arguments:
#       w           toplevel widget that uses the "." menu.
#       
# Results:
#       none

proc ::UI::MacUseMainMenu {w} {
    global  this osprefs
    variable mapWmenuToWtop
    variable cachedMenuSpec
    variable menuKeyToIndex
    variable wThatUseMainMenu
    
    if {![string match "mac*" $this(platform)]} {
	return
    }
    ::Debug 3 "::UI::MacUseMainMenu w=$w"
	
    # Set up menu accelerators from ".".
    if {![string equal $w "."] && [string equal $this(platform) "macosx"]} {
	lappend wThatUseMainMenu $w
	
	set wmenuList {}
	foreach {wmenu wtop} [array get mapWmenuToWtop] {
	    if {[string equal $wtop "."]} {
		lappend wmenuList $wmenu
	    }
	}
	
	# Need to loop through all menuDefs to look for accelerators.
	foreach wmenu $wmenuList {
	    foreach line $cachedMenuSpec(.,$wmenu) {
		
		# {type name cmd mstate accel mopts subdef} $line
		# Cut, Copy & Paste handled by widgets internally!
		set accel [lindex $line 4]
		if {[string length $accel] && ![regexp {(X|C|V)} $accel]} {

		    # Must check the actual state of menu!
		    set name [lindex $line 1]
		    set mind $menuKeyToIndex($wmenu,$name)
		    set state [$wmenu entrycget $mind -state]
		    if {[string equal $state "normal"]} {
			set acckey [string map {< less > greater}  \
			  [string tolower $accel]]
			bind $w <$osprefs(mod)-Key-${acckey}> [lindex $line 2]
			#bind $w <$osprefs(mod)-Key-${acckey}> \
			 # [list $wmenu invoke $mind]
		    }
		}
	    }
	}
    }
    
    # This sets up the edit menu that we inherit from ".".
    bind $w <FocusIn> "+ ::UI::MacFocusFixEditMenu $w . %W"
    
    # If we hand over to a 3rd party toplevel window, it by default inherits
    # the "." menu bar, so we need to take precautions.
    bind $w <FocusOut> "+ ::UI::MacFocusFixEditMenu $w . %W"
}

proc ::UI::BuildAppleMenu {wtop wmenuapple state} {
    global  this wDlgs
    variable menuDefs
    
    ::UI::NewMenu $wtop $wmenuapple {} $menuDefs(main,apple) $state
    
    if {[string equal $this(platform) "macosx"]} {
	proc ::tk::mac::ShowPreferences { } {
	    ::Preferences::Build
	}
    }
}

proc ::UI::MenuDisableAllBut {mw normalList} {

    set iend [$mw index end]
    for {set i 0} {$i <= $iend} {incr i} {
	if {[$mw type $i] != "separator"} {
	    $mw entryconfigure $i -state disabled
	}
    }
    foreach name $normalList {
	::UI::MenuMethod $mw entryconfigure $name -state normal
    }
}

#--- The public interfaces -----------------------------------------------------

namespace eval ::UI::Public:: {
    
    # This is supposed to collect some "public" interfaces useful for
    # 'plugins' and 'components'.
}

# UI::Public::RegisterMenuEntry --
#
#       
# Arguments:
#       wpath       
#       name
#       menuSpec    {type label command state accelerator opts {subspec}}
#       
# Results:
#       menu entries added when whiteboard built.

proc ::UI::Public::RegisterMenuEntry {wpath name menuSpec} {    
    upvar ::UI::menuSpecPublic menuSpecPublic 
    upvar ::UI::menuDefs menuDefs 

    switch -- $wpath {
	edit {
	    
	    # Entries should go in specific positions...
	    # lappend menuDefs(main,edit)
	    
	}
	prefs - items {
	    
	}
	default {
	    if {[lsearch $menuSpecPublic(wpaths) $wpath] < 0} {
		lappend menuSpecPublic(wpaths) $wpath
	    }
	    set menuSpecPublic($wpath,name) $name
	    set menuSpecPublic($wpath,specs) [list $menuSpec]
	}
    }
}

#--- There are actually more; sort out later -----------------------------------

proc ::UI::BuildPublicMenus {wtop wmenu} {
    variable menuSpecPublic
    
    foreach wpath $menuSpecPublic(wpaths) {	
	set m [menu ${wmenu}.${wpath} -tearoff 0]
	$wmenu add cascade -label $menuSpecPublic($wpath,name) -menu $m
	foreach menuSpec $menuSpecPublic($wpath,specs) {
	    ::UI::BuildMenuEntryFromSpec $wtop $m $menuSpec
	}
    }
}

# UI::BuildMenuEntryFromSpec  --
#
#       Builds a single menu entry for a menu. Can be called recursively.
#       
# Arguments:
#       menuSpec    {type label command state accelerator opts {subspec}}
#      
# Results:
#       none

proc ::UI::BuildMenuEntryFromSpec {wtop m menuSpec} {
    
    foreach {type label cmd state accel opts submenu} $menuSpec {
	if {[llength $submenu]} {
	    set mt [menu ${m}.sub -tearoff 0]
	    $m add cascade -label $label -menu $mt
	    foreach subm $submenu {
		::UI::BuildMenuEntryFromSpec $mt $subm
	    }
	} else {
	    set cmd [subst -nocommands $cmd]
	    eval {$m add $type -label $label -command $cmd -state $state} $opts
	}
    }
}

# UI::UndoConfig  --
# 
#       Callback for the undo/redo object.
#       Sets the menu's states.

proc ::UI::UndoConfig {wtop token what mstate} {
        
    set medit ${wtop}menu.edit
    
    switch -- $what {
	undo {
	    ::UI::MenuMethod $medit entryconfigure mUndo -state $mstate
	}
	redo {
	    ::UI::MenuMethod $medit entryconfigure mRedo -state $mstate	    
	}
    }
}

proc ::UI::OpenCanvasInfoFile {wtop theFile} {
    global  this
    
    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    set ans [tk_messageBox -type yesno -icon warning -parent $w \
      -title [::msgcat::mc {Open Helpfile}]  \
      -message [FormatTextForMessageBox [::msgcat::mc messopenhelpfile]]]
    if {$ans == "yes"} {
	::CanvasFile::DoOpenCanvasFile $wtop [file join $this(path) docs $theFile]
    }
}


namespace eval ::UI:: {
    
    variable megauid 0
}

# UI::MegaDlgMsgAndEntry --
# 
#       A mega widget dialog with a message and a single entry.

proc ::UI::MegaDlgMsgAndEntry {title msg label varName btcancel btok} {
    global this
    
    variable finmega
    variable megauid
    upvar $varName entryVar
    
    set w .mega[incr megauid]
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w $title
    set finmega -1
    wm protocol $w WM_DELETE_WINDOW [list set [namespace current]::finmega 0]
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4
    pack [message $w.frall.msg -width 220 -text $msg] \
      -side top -fill both -padx 4 -pady 2
    
    set wmid $w.frall.fr
    set wentry $wmid.en
    pack [frame $wmid] -side top -fill x -expand 1 -padx 6
    label $wmid.la -font $fontSB -text $label
    entry $wentry
    grid $wmid.la -column 0 -row 0 -sticky e -padx 2 
    grid $wmid.en -column 1 -row 0 -sticky ew -padx 2 
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack $frbot  -side bottom -fill x -padx 10 -pady 8
    pack [button $frbot.btok -text $btok  \
      -default active -command [list set [namespace current]::finmega 1]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text $btcancel  \
      -command [list set [namespace current]::finmega 0]]  \
      -side right -padx 5 -pady 5  
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    bind $w <Escape> [list $frbot.btcancel invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $wentry
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finmega
    
    set entryVar [$wentry get]
    catch {grab release $w}
    catch {destroy $w}
    catch {focus $oldFocus}
    return [expr {($finmega <= 0) ? "cancel" : "ok"}]
}

#--- Cut, Copy, & Paste stuff --------------------------------------------------

namespace eval ::UI::CCP:: {
    variable locals
    
    set locals(inited) 0
    set locals(wccpList) {}
}

proc ::UI::InitCutCopyPaste { } {
    
    upvar ::UI::CCP::locals locals

    # Icons.
    set cutdata {
R0lGODdhFgAUALMAAP///97WztbWzoSEhHNra2trrWtra2trY0JCQgAAhAAA
AAAAAAAAAAAAAAAAAAAAACwAAAAAFgAUAAAEfhDISatFIOjNOx+YEAhkaZ4k
mIleqwmqKJdGqZyBOu4vsSsbmU42Eh0MAQOQtIvtiILbjSXEPK+K7IuouxJv
vCqACQ0kFAly01omJcyJ9NNZjgveZi77+u6L3mJtaYMjciJDfHlwV3RXBTNe
iGVhjBgDl5iZmpoInZ6foKGdEQA7}

    set copydata {
R0lGODdhFgAUALMAAP///97WztbWzsbGxoSExoSEhGtrrUJCQgAAhAAAQgAA
AAAAAAAAAAAAAAAAAAAAACwAAAAAFgAUAAAEhRDISas9IOjNOy+YEAhkaZ4k
mIleqwmqKCg0jZqBOgbKRLey2KhXGCgICYPSQNrpRL0JgoJA7GCYXa82lQKs
IuGMCqB9q+Anr0zrVhDh7JBcM6dD0LqbGs/sOFN1PXcrMiV7Un0bLCNojlUj
MSUjMi6KLyyGOEEYBZ6foKGhB6SlpqeopBEAOw==}

    set pastedata {
R0lGODdhFgAUAMQAAP//////AO/va97WztbWzoSExoSEhISEQoSEAHNrrXNr
a2trrWtrpWtra2trY2NjQkJCQgAAhAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAFgAUAAAFoyAgjmRpQsCgrmzLGigx
EHRt3zScym4/DzqZkCYpSnAz3Y9glAQCTYlKFpxJDg+FoKFVQA6HhlApkyAg
0aLBoBjHrIYDwjCv0x0/8sB8oEf+gBFiSSg/EnFzESURDHlvTAh9CIokEQUz
BHqHcgaKgACAKpqRfiagVI+biaCBBRGEO1ZGlIuoAEJLAwwJC7y+C7C5uMO5
OmvHyMnJEMzNzs/QzSEAOw==}

    set cutDisdata {
R0lGODdhFgAUALMAAP///+/v7+/v597WztbWzrWtra2trYSEhEJCQgAAAAAA
AAAAAAAAAAAAAAAAAAAAACwAAAAAFgAUAAAEgBDISatFYOjNOz8YMRBkaZ4k
mImdsbkcoYp0eaz3SA7q6G83UVAjDPlqhwMvd+zRfjLADbArUo+6JfPnxPqm
zxQG+0wqs9ZwU5okjrrlpFRyKI/DhoDglsulsQUZfUpXMndHMoQjEm5wP4ws
boaFXohVPBhmmpucSQifoKGio58RADs=}

    set copyDisdata {
R0lGODdhFgAUALMAAP////fv7+/v797e3t7WztbWzsbGxrWtra2trYSEhEJC
QgAAAAAAAAAAAAAAAAAAACwAAAAAFgAUAAAEjBDISatVgOjNO09YQRRkaZ4k
mInI0SIeV6gjkUxJMqKiKs4BzU3X+dF6hsQsx1T+bJhaQiCxURIwY2iUSDIz
QsPzaKNKhkqmdDvz5jJVwI0b7ZnlcuZhDl3ZmnNXAClsBAIBhzcIBowDfGRP
S4BzM1E1TwQWEj0hkTsxGpVgnjxjGJOoqAqrrK2ur6sRADs=}

    set pasteDisdata {
R0lGODdhFgAUALMAAP///+/v797WztbWzsbGxrW9tbWtra2trYSEhEJCQgAA
AAAAAAAAAAAAAAAAAAAAACwAAAAAFgAUAAAEeRDISatNQOjNO0fYIAxkaZ4k
mIncYbjeqIrDgdx4bgrqyOfAm0Y0k90sOACtRwwCV7yQ0ZlcYnzUHJT5004I
CKVMOghmNAcAAnttanEGnIZrPhAIBUIgXCbbtAIVYVFQgRNZGUUkHRYTfVA7
LDGPWZUgCZiZmpucCREAOw==}

    set cutPushdata {
R0lGODdhFgAUALMAAP///97WztbWzoSEhHNra2trrWtra2trY0JCQgAAhAAA
AAAAAAAAAAAAAAAAAAAAACwAAAAAFgAUAAAEfXDISatFI+jNOweY4I0dmIlC
qq6sYKIkaQbwaqgKO9O8JhA8xUb04qFEB0PAIEzRZjVjLifi7aIihdaHKhq/
uR4RQ8MGEoqEsxv6HhPnhNpKNssF8DN7YD/r/WMnbmqENHMubVFwc3JGUG4B
BUdfJgCWl5iZmQicnZ6foJwRADs=}

    set copyPushdata {
R0lGODdhFgAUALMAAP///97WztbWzsbGxoSExoSEhGtrrUJCQgAAhAAAQgAA
AAAAAAAAAAAAAAAAAAAAACwAAAAAFgAUAAAEhrDISas9JejNOweY4I0dmIlC
qq6sYKIkaQaoYtvt+tKBAvy2kWhWAxQGCkLCwDSkaDOe7wdAUKsI3k7ku1mp
1qwLwxNMf1YbFpGNcgHeK3hcENHOVfjN1yY/9wpfcgh0G3YbaXtVAW4oKoJX
hDsahwJsl5iMfio0MEImcqGiPwelpqeoqaURADs=}
	
    set pastePushdata {
R0lGODdhFgAUAMQAAP//////AO/va97WztbWzoSExoSEhISEQoSEAHNrrXNr
a2trrWtrpWtra2trY2NjQkJCQgAAhAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAFgAUAAAFo6AhjmRpQsagrmzLAijh
zi2cykSu7zxh47SZDzUA6iRISW/wKxaTkkAAKlENb8/DQyFocBWQw6Eha8ok
CAgVKVKUiTiJ4YAw1O92R9FmHaAPdhGCgxFkTDFOcnQGEQCOjhEMe3BPCIAI
jY8AEQWTKYlzdY2Dm4KHBkB/gZqPEVdOBIqipYMFEadGUJmsrnxGTgwJC8LE
C6esyMmOEMzNzs/QzCEAOw==}

    set printdata {
R0lGODdhFgAUAKIAAP//////ANTQyICAgEBAQAAAAAAAAAAAACwAAAAAFgAU
AAADYQi63E5AyEkrHdCKwnufWFQVjlKA2Qh45ImKE1m6Uqiy6yfYcbluQN6G
5QFydima5sREiohQyYmnrA0GUqAzWwl4pcftEFp0CauUZi0FJiuFmrhYHg9d
7/i8nsDv+/+AfAkAOw==}

    set printPushdata {
R0lGODdhFgAUAKIAAP//////ANTQyICAgEBAQAAAAAAAAAAAACwAAAAAFgAU
AAADYDi63E5DyEkrBdBqi6MuYBhK3Qec6FmQmVUA4ruyHvWm6CyUlSzCI97k
hoMJVq+WJBY7HpM13ccJHTKZS6FUslg6tZaAeAnaKa/YldC5QdJ66PJ7QzcP
ing8Yc/v+/97CQA7}

    set locals(imcut) [image create photo -format gif -data $cutdata]
    set locals(imcopy) [image create photo -format gif -data $copydata]
    set locals(impaste) [image create photo -format gif -data $pastedata]
    set locals(imcutDis) [image create photo -format gif -data $cutDisdata]
    set locals(imcopyDis) [image create photo -format gif -data $copyDisdata]
    set locals(impasteDis) [image create photo -format gif -data $pasteDisdata]
    set locals(imcutPush) [image create photo -format gif -data $cutPushdata]
    set locals(imcopyPush) [image create photo -format gif -data $copyPushdata]
    set locals(impastePush) [image create photo -format gif -data $pastePushdata]
    set locals(imprint) [image create photo -format gif -data $printdata]
    set locals(imprintPush) [image create photo -format gif -data $printPushdata]
    
    set locals(inited) 1
}

# UI::NewCutCopyPaste --
#
#       Makes a new cut/copy/paste window look-alike mega widget.
#       
# Arguments:
#       w      the cut/copy/paste widget.
#       
# Results:
#       $w

proc ::UI::NewCutCopyPaste {w} {
    
    # Set simpler variable names.
    upvar ::UI::CCP::locals locals
    
    if {!$locals(inited)} {
	::UI::InitCutCopyPaste
    }
    
    frame $w -bd 0
    foreach name {cut copy paste} {
	label $w.$name -image $locals(im$name) -borderwidth 0
    }
    pack $w.cut $w.copy $w.paste -side left -padx 0 -pady 0
    
    set locals($w,wtop) [winfo toplevel $w]
    
    # Set binding to focus to set normal/disabled correctly.
    bind $locals($w,wtop) <FocusIn> "+ ::UI::CutCopyPasteFocusIn $w"
    bind $w.cut <Button-1> [list $w.cut configure -image $locals(imcutPush)]
    bind $w.copy <Button-1> [list $w.copy configure -image $locals(imcopyPush)]
    bind $w.paste <Button-1> [list $w.paste configure -image $locals(impastePush)]

    bind $w.cut <ButtonRelease> "[list $w.cut configure -image $locals(imcut)]; \
      [list ::UI::CutCopyPasteCmd "cut"]"
    bind $w.copy <ButtonRelease> "[list $w.copy configure -image $locals(imcopy)]; \
      [list ::UI::CutCopyPasteCmd "copy"]"
    bind $w.paste <ButtonRelease> "[list $w.paste configure -image $locals(impaste)]; \
      [list ::UI::CutCopyPasteCmd "paste"]"

    # Register this thing.
    lappend locals(wccpList) $w
    
    return $w
}

# UI::CutCopyPasteCmd ---
#
#       Supposed to be a generic cut/copy/paste function for menu commands.
#       
# Arguments:
#       cmd      cut/copy/paste
#       
# Results:
#       none

proc ::UI::CutCopyPasteCmd {cmd} {
    
    set wfocus [focus]    
    ::Debug 2 "::UI::CutCopyPasteCmd cmd=$cmd, wfocus=$wfocus"
    
    if {$wfocus == ""} {
	return
    }

    switch -- $cmd {
	cut {
	    event generate $wfocus <<Cut>>
	}
	copy {
	    event generate $wfocus <<Copy>>			    
	}
	paste {
	    event generate $wfocus <<Paste>>	
	}
    }
}

proc ::UI::CutCopyPasteConfigure {w which args} {
    
    upvar ::UI::CCP::locals locals

    if {![winfo exists $w]} {
	return
    }
    array set opts {
	-state   normal
    }
    array set opts $args
    
    foreach opt [array names opts] {
	set val $opts($opt)
	switch -- $opt {
	    -state {
		if {$val == "normal"} {
		    $w.$which configure -image $locals(im$which)
		    bind $w.$which <Button-1>   \
		      [list $w.$which configure -image $locals(im${which}Push)]
		    bind $w.$which <ButtonRelease>  \
		      "[list $w.$which configure -image $locals(im$which)]; \
		      [list ::UI::CutCopyPasteCmd $which]"
		} elseif {$val == "disabled"} {
		    $w.$which configure -image $locals(im${which}Dis)
		    bind $w.$which <Button-1> {}
		    bind $w.$which <ButtonRelease> {}
		}
	    }
	}
    }
}

proc ::UI::CutCopyPasteHelpSetState {w} {
    
    upvar ::UI::CCP::locals locals
    
    set wfocus [focus]
    if {[string length $wfocus] == 0} {
	return
    }
    set wClass [winfo class $wfocus]
    set setState disabled
    if {[string equal $wClass "Entry"]} {
	if {[$wfocus selection present] == "1"} {
	    set setState normal
	}
    } elseif {[string equal $wClass "Text"]} {
	if {[string length [$wfocus tag ranges sel]] > 0} {
	    set setState normal
	}
    }
    ::UI::CutCopyPasteConfigure $w cut -state $setState
    ::UI::CutCopyPasteConfigure $w copy -state $setState
}

proc ::UI::CutCopyPasteFocusIn {w} {

    upvar ::UI::CCP::locals locals

    if {![catch {selection get -selection CLIPBOARD} _s]  &&  \
      ([string length $_s] > 0)} {
	::UI::CutCopyPasteConfigure $w paste -state normal
    } else {
	::UI::CutCopyPasteConfigure $w paste -state disabled
    }
}

proc ::UI::CutCopyPasteCheckState {w state clipState} {

    upvar ::UI::CCP::locals locals

    set wtoplevel [winfo toplevel $w]
    set tmp {}
    
    # Find any ccp widget that's in the same toplevel as 'w'.
    foreach wccp $locals(wccpList) {
	if {[winfo exists $wccp]} {
	    lappend tmp $wccp
	    if {[string equal $wtoplevel [winfo toplevel $wccp]]} {
		::UI::CutCopyPasteConfigure $wccp cut -state $state
		::UI::CutCopyPasteConfigure $wccp copy -state $state	    
		::UI::CutCopyPasteConfigure $wccp paste -state $clipState	    	    
	    }
	}
    }
    set locals(wccpList) $tmp
}

proc ::UI::NewPrint {w cmd} {
    
    # Set simpler variable names.
    upvar ::UI::CCP::locals locals
    
    if {!$locals(inited)} {
	::UI::InitCutCopyPaste
    }    
    label $w -image $locals(imprint) -borderwidth 0
    set locals($w,wtop) [winfo toplevel $w]
    
    bind $w <Button-1> [list $w configure -image $locals(imprintPush)]
    bind $w <ButtonRelease> "[list $w configure -image $locals(imprint)]; $cmd"
    
    return $w
}



# ::UI::ParseWMGeometry --
# 
#       Parses 'wm geometry' result into a list.
#       
# Arguments:
#       win         the (real) toplevel widget path
# Results:
#       list {width height x y}

proc ::UI::ParseWMGeometry {win} {
    
    regexp {([0-9]+)x([0-9]+)\+(\-?[0-9]+)\+(\-?[0-9]+)}  \
      [wm geometry $win] m w h x y
    return [list $w $h $x $y]
}

# UI::FixMenusWhenSelection --
# 
#       Sets the correct state for menus and buttons when selection.
#       Take the whiteboard's state into accounts.
#       
# Arguments:
#       w       the widget that contains something that is selected.
#
# Results:

proc ::UI::FixMenusWhenSelection {w} {
    global  this
    
    set wtop [::UI::GetToplevelNS $w]
    set wClass [winfo class $w]
    set wToplevel [winfo toplevel $w]
    set wToplevelClass [winfo class $wToplevel]
    set medit ${wtop}menu.edit 
    
    Debug 5 "::UI::FixMenusWhenSelection w=$w,\n\twtop=$wtop, wClass=$wClass,\
      wToplevelClass=$wToplevelClass"
    
    # Do different things dependent on the type of widget.
    if {[winfo exists ${wtop}menu] && [string equal $wClass "Canvas"]} {
	
	# Respect any disabled whiteboard state.
	upvar ::WB::${wtop}::opts opts
	set isDisabled 0
	if {[string equal $opts(-state) "disabled"]} {
	    set isDisabled 1
	}
	
	# Any images selected?
	set allSelected [$w find withtag selected]
	set anyImageSel 0
	set anyNotImageSel 0
	set anyTextSel 0
	set allowFlip 0	
	foreach id $allSelected {
	    set theType [$w type $id]
	    if {[string equal $theType "line"] ||  \
	      [string equal $theType "polygon"]} {
		if {[llength $allSelected] == 1} {
		    set allowFlip 1
		}
	    }
	    if {[string equal $theType "image"]} {
		set anyImageSel 1
	    } else {
		set anyNotImageSel 1
		if {[string equal $theType "text"]} {
		    set anyTextSel 1
		}
	    }
	    if {$anyImageSel && $anyNotImageSel} {
		break
	    }
	}
	if {([llength $allSelected] == 0) && \
	  ([llength [$w select item]] == 0)} {
	    
	    # There is no selection in the canvas.
	    if {$isDisabled} {
		::UI::MenuMethod $medit entryconfigure mCopy -state disabled
		::UI::MenuMethod $medit entryconfigure mInspectItem -state disabled
	    } else {		
		::UI::MenuMethod $medit entryconfigure mCut -state disabled
		::UI::MenuMethod $medit entryconfigure mCopy -state disabled
		::UI::MenuMethod $medit entryconfigure mInspectItem -state disabled
		::UI::MenuMethod $medit entryconfigure mRaise -state disabled
		::UI::MenuMethod $medit entryconfigure mLower -state disabled
		::UI::MenuMethod $medit entryconfigure mLarger -state disabled
		::UI::MenuMethod $medit entryconfigure mSmaller -state disabled
		::UI::MenuMethod $medit entryconfigure mFlip -state disabled
		::UI::MenuMethod $medit entryconfigure mImageLarger -state disabled
		::UI::MenuMethod $medit entryconfigure mImageSmaller -state disabled
	    }
	} else {
	    if {$isDisabled} {
		::UI::MenuMethod $medit entryconfigure mCopy -state normal
		::UI::MenuMethod $medit entryconfigure mInspectItem -state normal
	    } else {		
		::UI::MenuMethod $medit entryconfigure mCut -state normal
		::UI::MenuMethod $medit entryconfigure mCopy -state normal
		::UI::MenuMethod $medit entryconfigure mInspectItem -state normal
		::UI::MenuMethod $medit entryconfigure mRaise -state normal
		::UI::MenuMethod $medit entryconfigure mLower -state normal
		if {$anyNotImageSel} {
		    ::UI::MenuMethod $medit entryconfigure mLarger -state normal
		    ::UI::MenuMethod $medit entryconfigure mSmaller -state normal
		}
		if {$anyImageSel} {
		    ::UI::MenuMethod $medit entryconfigure mImageLarger -state normal
		    ::UI::MenuMethod $medit entryconfigure mImageSmaller -state normal
		}
		if {$allowFlip} {
		    # Seems to be buggy on mac...
		    ::UI::MenuMethod $medit entryconfigure mFlip -state normal
		}
	    }
	}
	
    } elseif {[string equal $wClass "Entry"] ||  \
      [string equal $wClass "Text"]} {
	set setState disabled
	
	switch -- $wClass {
	    Entry {
		if {[$w selection present] == "1"} {
		    set setState normal
		}
	    }
	    Text {
		if {[string length [$w tag ranges sel]] > 0} {
		    set setState normal
		}
	    }
	}
	
	# Check to see if there is something to paste.
	set haveClipState disabled
	if {![catch {selection get -selection CLIPBOARD} sel]} {
	    if {[string length $sel] > 0} {
		set haveClipState normal
	    }
	}	
	if {[winfo exists $medit]} {
	    
	    # We have an explicit menu for this window.
	    ::UI::MenuMethod $medit entryconfigure mCut -state $setState
	    ::UI::MenuMethod $medit entryconfigure mCopy -state $setState
	    ::UI::MenuMethod $medit entryconfigure mPaste -state $haveClipState
	} elseif {[string equal $this(platform) "macintosh"] || \
	  [string equal $this(platform) "macosx"]} {
	    
	    # Else we use the menu associated with "." since it is default one.
	    ::UI::MenuMethod .menu.edit entryconfigure mCut -state $setState
	    ::UI::MenuMethod .menu.edit entryconfigure mCopy -state $setState
	    ::UI::MenuMethod .menu.edit entryconfigure mPaste -state $haveClipState
	}
	
	# If we have a cut/copy/paste row of buttons need to set their state.
	if {[winfo exists $w]} {
	    ::UI::CutCopyPasteCheckState $w $setState $haveClipState
	}
    } 
}

# UI::MacFocusFixEditMenu --
# 
#       Called when a window using the main menubar gets focus in/out.
#       Mac only.
#       
# Arguments:
#       w           the toplevel which gets focus
#       wtopmenu    the 'wtop' which cooresponds to the menu to use (".").
#       wfocus      the %W which is either equal to $w or a children of it.
#       
# Results:
#       none

proc ::UI::MacFocusFixEditMenu {w wtopmenu wfocus} {
    
    # Binding to a toplevel is also triggered by its children.
    if {$w != $wfocus} {
	return
    }    
    ::Debug 5 "MacFocusFixEditMenu: w=$w, wfocus=$wfocus"
    
    # The <FocusIn> events are sent in order, from toplevel and down
    # to the actual window with focus.
    # Any '::UI::FixMenusWhenSelection' will therefore be called after this.
    set medit ${wtopmenu}menu.edit
    ::UI::MenuMethod $medit entryconfigure mPaste -state disabled
    ::UI::MenuMethod $medit entryconfigure mCut -state disabled
    ::UI::MenuMethod $medit entryconfigure mCopy -state disabled
}


proc ::UI::CenterWindow {win} {
    
    if {[winfo toplevel $win] != $win} {
	error "::UI::CenterWindow: $win is not a toplevel window"
    }
    after idle [format {
	update idletasks
	set win %s
	set sw [winfo screenwidth $win]
	set sh [winfo screenheight $win]
	set x [expr ($sw - [winfo reqwidth $win])/2]
	set y [expr ($sh - [winfo reqheight $win])/2]
	wm geometry $win "+$x+$y"
    } $win]
}

# ::UI::StartStopAnimatedWave, AnimateWave --
#
#       Utility routines for animating the wave in the status message frame.
#       
# Arguments:
#       w           canvas widget path (not the whiteboard)
#       
# Results:
#       none

proc ::UI::StartStopAnimatedWave {w theimage start} {
    variable icons
    variable animateWave
    
    # Define speed and update frequency. Pix per sec and times per sec.
    set speed 150
    set freq 16
    set animateWave(pix) [expr int($speed/$freq)]
    set animateWave(wait) [expr int(1000.0/$freq)]

    if {$start} {
	
	# Check if not already started.
	if {[info exists animateWave($w,id)]} {
	    return
	}
	set id [$w create image 0 0 -anchor nw -image $theimage]
	set animateWave($w,id) $id
	$w lower $id
	set animateWave($w,x) 0
	set animateWave($w,dir) 1
	set animateWave($w,killId)   \
	  [after $animateWave(wait) [list ::UI::AnimateWave $w]]
    } elseif {[info exists animateWave($w,killId)]} {
	after cancel $animateWave($w,killId)
	$w delete $animateWave($w,id)
	array unset animateWave $w,*
    }
}

proc ::UI::AnimateWave {w} {
    variable animateWave
    
    set deltax [expr $animateWave($w,dir) * $animateWave(pix)]
    incr animateWave($w,x) $deltax
    if {$animateWave($w,x) > [expr [winfo width $w] - 80]} {
	set animateWave($w,dir) -1
    } elseif {$animateWave($w,x) <= -60} {
	set animateWave($w,dir) 1
    }
    $w move $animateWave($w,id) $deltax 0
    set animateWave($w,killId)   \
      [after $animateWave(wait) [list ::UI::AnimateWave $w]]
}

#-------------------------------------------------------------------------------

