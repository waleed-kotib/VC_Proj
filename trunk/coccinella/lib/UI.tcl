#  UI.tcl ---
#  
#      This file is part of The Coccinella application. It implements user
#      interface elements.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#  
# $Id: UI.tcl,v 1.122 2006-02-12 16:19:52 matben Exp $

package require alertbox
package require ui::dialog
package require ui::entryex

package provide UI 1.0

namespace eval ::UI:: {
    global  this

    # Add all event hooks.
    #::hooks::register initHook               ::UI::InitHook
    ::hooks::register firstLaunchHook         ::UI::FirstLaunchHook

    # Icons
    option add *buttonOKImage            buttonok       widgetDefault
    option add *buttonCancelImage        buttoncancel   widgetDefault
    
    option add *info64Image              info64         widgetDefault
    option add *error64Image             error64        widgetDefault
    option add *warning64Image           warning64      widgetDefault
    option add *question64Image          question64     widgetDefault

    option add *badgeImage               Coccinella     widgetDefault
    #option add *badgeImage               coccinella64   widgetDefault
    option add *applicationImage         coccinella64   widgetDefault
    
    variable wThatUseMainMenu {}

    # components stuff.
    variable menuSpecPublic
    set menuSpecPublic(wpaths) {}
    
    variable icons

    # The mac look-alike triangles.
    set icons(mactriangleopen) [image create photo -data {
	R0lGODlhCwALAPMAAP///97e3s7O/729vZyc/4yMjGNjzgAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAEALAAAAAALAAsAAAQgMMhJq7316M1P
	OEIoEkchHURKGOUwoWubsYVryZiNVREAOw==
    }]
    set icons(mactriangleclosed) [image create photo -data {
	R0lGODlhCwALAPMAAP///97e3s7O/729vZyc/4yMjGNjzgAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAEALAAAAAALAAsAAAQiMMgjqw2H3nqE
	3h3xWaEICgRhjBi6FgMpvDEpwuCBg3sVAQA7
    }]
    
    # Aqua gray arrows.
    set icons(openAqua) [image create photo -data {
	R0lGODlhCQAJAPMAMf///62trZycnJSUlIyMjISEhHNzcwAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAJAAkAAAQccJhJzZB1DlBy
	AUCQBSBHfSVApSBhECxoxKCQRgA7
    }]
    set icons(closeAqua) [image create photo -data {
	R0lGODlhCQAJAPMAMf///62trZycnJSUlIyMjISEhHNzcwAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAJAAkAAAQacAxAKzCmBHtx
	tp5HUGEolMbYYQWYbZbEUREAOw==
    }]
    
    # WinXP lool-alikes +- signs.
    set icons(openPM) [image create photo -data {
	R0lGODdhCQAJAKIAAP//////wsLCwsLCibS0tFOJwgAAAAAAACwAAAAACQAJ
	AAADHUi1XAowgiUjrYKavXOBQSh4YzkuAkEMrKI0C5EAADs=
    }]    
    set icons(closePM) [image create photo -data {
	R0lGODdhCQAJAKIAAP//////wsLCwsLCibS0tFOJwgAAAAAAACwAAAAACQAJ
	AAADIEi1XAowghVNpNACQY33XAEFRiCEp2Cki0AQQ6wozUIkADs=
    }]
    
    switch -- [tk windowingsystem] {
	aqua {
	    set imstate [list $icons(openAqua) open $icons(closeAqua) {}]
	    option add *TreeCtrl.buttonImage $imstate widgetDefault
	}
	x11 {
	    set imstate [list $icons(openPM) open $icons(closePM) {}]
	    option add *TreeCtrl.buttonImage $imstate widgetDefault
	}
    }
    
    # Dialog images.
    foreach name {info error warning question} {
	set im [::Theme::GetImage [option get . ${name}64Image {}]]
	ui::dialog::setimage $name $im
    }
    ui::dialog::setbadge [::Theme::GetImage [option get . badgeImage {}]]
    set im [::Theme::GetImage [option get . applicationImage {}]]
    ui::dialog::setimage coccinella $im
    
    # System colors.
    set wtmp [listbox ._tmp_listbox]
    set this(sysHighlight)     [$wtmp	cget -selectbackground]
    set this(sysHighlightText) [$wtmp cget -selectforeground]
    destroy $wtmp
    
    # Hardcoded configurations.
    set ::config(ui,pruneMenus) {}
}

proc ::UI::InitHook { } {
    
    # In initHook UI before hooks BAD!

    # Various initializations for canvas stuff and UI.
    #::UI::Init
    #::UI::InitMenuDefs  
}

proc ::UI::FirstLaunchHook { } {
    SetupAss
    WelcomeCanvas
}

# UI::Init --
# 
#       Various initializations for the UI stuff.

proc ::UI::Init {} {
    global  this prefs
    
    ::Debug 2 "::UI::Init"    
    
    # Standard button icons. 
    # Special solution to be able to set image via the option database.
    ::Theme::GetImage [option get . buttonOKImage {}] -keepname 1
    ::Theme::GetImage [option get . buttonCancelImage {}] -keepname 1    
    ::Theme::GetImage [option get . buttonTrayImage {}] -keepname 1    
}

proc ::UI::InitCommonBinds { } {
    global  this
    
    # A mechanism to set -state of cut/copy/paste. Not robust!!!
    # All selections are not detected (shift <- -> etc).
    # 
    # @@@ Shall be replaced with -postcommand for each window type.
    # 
    # Entry copy/paste.
    bind Entry <FocusIn>         {+ ::UI::FixMenusWhenSelection %W }
    bind Entry <ButtonRelease-1> {+ ::UI::FixMenusWhenSelection %W }
    bind Entry <<Cut>>           {+ ::UI::FixMenusWhenSelection %W }
    bind Entry <<Copy>>          {+ ::UI::FixMenusWhenSelection %W }
	
    # Text copy/paste.
    bind Text <FocusIn>         {+ ::UI::FixMenusWhenSelection %W }
    bind Text <ButtonRelease-1> {+ ::UI::FixMenusWhenSelection %W }
    bind Text <<Cut>>           {+ ::UI::FixMenusWhenSelection %W }
    bind Text <<Copy>>          {+ ::UI::FixMenusWhenSelection %W }

    if {[string equal "x11" [tk windowingsystem]]} {
	# Support for mousewheels on Linux/Unix commonly comes through mapping
	# the wheel to the extended buttons.  If you have a mousewheel, find
	# Linux configuration info at:
	#	http://www.inria.fr/koala/colas/mouse-wheel-scroll/
	bind Canvas <4> {
	    if {!$::tk_strictMotif} {
		if {![string equal [%W yview] "0 1"]} {
		    %W yview scroll -5 units
		}
	    }
	}
	bind Canvas <5> {
	    if {!$::tk_strictMotif} {
		if {![string equal [%W yview] "0 1"]} {
		    %W yview scroll 5 units
		}
	    }
	}
    } elseif {[string equal [tk windowingsystem] "aqua"]} {
	bind Canvas <MouseWheel> {
	    if {![string equal [%W yview] "0 1"]} {
		%W yview scroll [expr {- (%D)}] units
	    }
	}
	bind Canvas <Shift-MouseWheel> {
	    if {![string equal [%W xview] "0 1"]} {
		%W xview scroll [expr {- (%D)}] units
	    }
	}
    } else {
	bind Canvas <MouseWheel> {
	    if {![string equal [%W yview] "0 1"]} {
		%W yview scroll [expr {- (%D / 120) * 4}] units
	    }
	}
	bind Canvas <Shift-MouseWheel> {
	    if {![string equal [%W xview] "0 1"]} {
		%W xview scroll [expr {- (%D / 120) * 4}] units
	    }
	}
    }

    # Linux has a strange binding by default. Handled by <<Paste>>.
    if {[string equal $this(platform) "unix"]} {
	bind Text <Control-Key-v> {}
    }
}

proc ::UI::InitVirtualEvents { } {
    global  this
      
    # Virtual events.
    event add <<CloseWindow>> <$this(modkey)-Key-w>
    event add <<ReturnEnter>> <Return> <KP_Enter>

    switch -- $this(platform) {
	macintosh {
	    event add <<ButtonPopup>> <Button-2> <Control-Button-1>
	}
	macosx {
	    event add <<ButtonPopup>> <Button-2> <Control-Button-1>
	}
	unix {
	    event add <<ButtonPopup>> <Button-3>
	}
	windows {
	    event add <<CloseWindow>> <Key-F4>
	    event add <<ButtonPopup>> <Button-3>
	}
    }
}

proc ::UI::InitDlgs { } {
    global  wDlgs
    
    # Define the toplevel windows here so they don't collide.
    # Toplevel dialogs.
    array set wDlgs {
	comp            .comp
	editFonts       .edfnt
	editShorts      .tshcts
	fileAssoc       .fass
	infoClient      .infocli
	infoServ        .infoserv
	iteminsp        .iteminsp
	netSetup        .netsetup
	openConn        .opc
	openMulti       .opqtmulti
	prefs           .prefs
	print           .prt
	prog            .prog
	plugs           .plugs
	setupass        .setupass
	wb              .wb
	mainwb          .wb0
    }
    
    # Toplevel dialogs for the jabber part.
    array set wDlgs {
	jmain           .jmain
	jreg            .jreg
	jlogin          .jlogin
	jrost           .jrost
	jrostnewedit    .jrostnewedit
	jrostadduser    .jrostadduser
	jrostedituser   .jrostedituser
	jsubsc          .jsubsc
	jsendmsg        .jsendmsg
	jgotmsg         .jgotmsg
	jstartchat      .jstartchat
	jchat           .jchat
	jbrowse         .jbrowse
	jenterroom      .jenterroom
	jcreateroom     .jcreateroom
	jinbox          .jinbox
	jpresmsg        .jpresmsg
	joutst          .joutst
	jpasswd         .jpasswd
	jsearch         .jsearch
	jvcard          .jvcard
	jgcenter        .jgcenter
	jgc             .jgc
	jmucenter       .jmucenter
	jmucinvite      .jmucinvite
	jmucinfo        .jmucinfo
	jmucedit        .jmucedit
	jmuccfg         .jmuccfg
	jmucdestroy     .jmucdestroy
	jchist          .jchist
	jhist           .jhist
	jprofiles       .jprofiles
	joobs           .joobs
	jftrans         .jftrans
	jerrdlg         .jerrdlg
	jwbinbox        .jwbinbox
	jprivacy        .jprivacy
	jdirpres        .jdirpres
	jdisaddserv     .jdisaddserv
	juserinfo       .juserinfo
	jgcbmark        .jgcbmark
    }
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
      {command   mAboutCoccinella    {::Splash::SplashScreen} normal   {}}
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

# UI::SetupAss --
# 
#       Setup assistant. Must be called after initing the jabber stuff.

proc ::UI::SetupAss { } {
    global wDlgs
    
    package require SetupAss

    catch {destroy $wDlgs(splash)}
    update
    ::Jabber::SetupAss::SetupAss
    ::UI::CenterWindow $wDlgs(setupass)
    raise $wDlgs(setupass)
    tkwait window $wDlgs(setupass)
}

# UI::WelcomeCanvas --
# 
#       Is it the first time it is launched, then show the welcome canvas.

proc ::UI::WelcomeCanvas { } {
    global  this
    
    set systemLocale [lindex [split $this(systemLocale) _] 0]
    set floc [file join $this(docsPath) Welcome_${systemLocale}.can]
    if {[file exists $floc]} {
	set f $floc
    } else {
	set f [file join $this(docsPath) Welcome_en.can]
    }
    ::Dialogs::Canvas $f -title [mc {Welcome}] -encoding utf-8
}

proc ::UI::GetMainWindow { } {
    global  prefs
    
    switch -- $prefs(protocol) {
	jabber {
	    return [::Jabber::UI::GetMainWindow]
	}
	default {
	    return [::P2P::GetMainWindow]
	}
    }
}

proc ::UI::GetMainMenu { } {
    global  prefs wDlgs
    
    switch -- $prefs(protocol) {
	jabber {
	    return [::Jabber::UI::GetMainMenu]
	}
	default {
	    return [GetMenuFromWindow [::P2P::GetMainWindow]]
	}
    }
}

proc ::UI::GetMenuFromWindow {w} {
    
    return $w.menu
}

proc ::UI::GetIcon {name} {
    variable icons
    
    if {[info exists icons($name)]} {
	return $icons($name)
    } else {
	return -code error "icon named \"$name\" does not exist"
    }
}

proc ::UI::GetScreenSize { } {
    
    return [list [winfo vrootwidth .] [winfo vrootheight .]]
}

# UI::IsAppInFront --
# 
#       Tells if application is frontmost (active).
#       [focus] is not reliable so it is better called after idle.

proc ::UI::IsAppInFront { } {
    
    # The 'wm stackorder' is not reliable in sorting windows!
    # How about message boxes in front? We never get called since they block.
    set isfront 0
    set wfocus [focus]
    foreach w [wm stackorder .] {
	if {[string equal [wm state $w] "normal"]} {
	    if {($wfocus ne "") && [string equal [winfo toplevel $wfocus] $w]} {
		set isfront 1
		break
	    }
	}
    }
    return $isfront
}

proc ::UI::IsToplevelActive {w} {
    
    set front 0
    set wfocus [focus]
    if {[string equal [wm state $w] "normal"]} {
	if {($wfocus ne "") && [string equal [winfo toplevel $wfocus] $w]} {
	    set front 1
	}
    }
    return $front
}

# UI::MessageBox --
# 
#       Wrapper for the tk_messageBox.

proc ::UI::MessageBox {args} {
    
    eval {::hooks::run newMessageBox} $args
    
    array set argsArr $args
    if {[info exists argsArr(-message)]} {
	set argsArr(-message) [FormatTextForMessageBox $argsArr(-message)]
    }
    set ans [eval {tk_messageBox} [array get argsArr]]
    return $ans
}

# UI::FormatTextForMessageBox --
#
#       The tk_messageBox needs explicit newlines to format the message text.

proc ::UI::FormatTextForMessageBox {txt {width ""}} {
    global  prefs

    if {[tk windowingsystem] eq "windows"} {

	# Insert newlines to force line breaks.
	if {[string length $width] == 0} {
	    set width $prefs(msgWrapLength)
	}
	set len [string length $txt]
	set start $width
	set first 0
	set newtxt {}
	while {([set ind [tcl_wordBreakBefore $txt $start]] > 0) &&  \
	  ($start < $len)} {	    
	    append newtxt [string trim [string range $txt $first [expr $ind-1]]]
	    append newtxt "\n"
	    set start [expr $ind + $width]
	    set first $ind
	}
	append newtxt [string trim [string range $txt $first end]]
	return $newtxt
    } elseif {[tk windowingsystem] eq "x11"} {
	if {[string length $txt] < 32} {
	    append txt "             "
	}
	return $txt
    } else {
	return $txt
    }
}

# Administrative code to handle toplevels:
#       create, close, hide, show

namespace eval ::UI:: {

    variable topcache
    set topcache(state)       show
    set topcache(.,w)         .
    set topcache(.,prevstate) "normal"
}

# UI::Toplevel --
# 
#       Wrapper for making a toplevel window.
#       
# Arguments:
#       w
#       args:
#       -allowclose 0|1
#       -class  
#       -closecommand
#       -macstyle:
#           macintosh (classic) and macosx
#           documentProc, dBoxProc, plainDBox, altDBoxProc, movableDBoxProc, 
#           zoomDocProc, rDocProc, floatProc, floatZoomProc, floatSideProc, 
#           or floatSideZoomProc
#       -macclass
#           macosx only; {class attributesList} 
#           class = alert moveableAlert modal moveableModal floating document
#                   help toolbar
#           attributes = closeBox noActivates horizontalZoom verticalZoom 
#                   collapseBox resizable sideTitlebar noUpdates noActivates
#       -usemacmainmenu

proc ::UI::Toplevel {w args} {
    global  this prefs
    variable topcache
    
    array set argsArr {
	-allowclose       1
	-usemacmainmenu   0
    }
    array set argsArr $args
    set opts {}
    if {[info exists argsArr(-class)]} {
	lappend opts -class $argsArr(-class)
    }
    if {[info exists argsArr(-closecommand)]} {
	set topcache($w,-closecommand) $argsArr(-closecommand)
    }
    if {[tk windowingsystem] eq "aqua"} {
	if {$argsArr(-usemacmainmenu)} {
	    lappend opts -menu [GetMainMenu]
	}
    }
    set topcache($w,prevstate) "normal"
    set topcache($w,w) $w
    eval {toplevel $w} $opts
        
    # We direct all close events through DoCloseWindow so things can
    # be handled from there.
    wm protocol $w WM_DELETE_WINDOW [list ::UI::DoCloseWindow $w]
    if {$argsArr(-allowclose)} {
	bind $w <Escape> [list destroy $w]
    }
    if {[tk windowingsystem] eq "aqua"} {
	if {[info exists argsArr(-macclass)]} {
	    eval {::tk::unsupported::MacWindowStyle style $w}  \
	      $argsArr(-macclass)
	} elseif {[info exists argsArr(-macstyle)]} {
	    ::tk::unsupported::MacWindowStyle style $w $argsArr(-macstyle)
	}
	if {$argsArr(-usemacmainmenu)} {
	    SetMenuAcceleratorBinds $w [GetMainMenu]
	}
	# Unreliable!!!
	# ::UI::SetAquaProxyIcon $w
    } else {
	if {$argsArr(-allowclose)} {
	    bind $w <<CloseWindow>> [list ::UI::DoCloseWindow $w]
	}
    }
    if {$prefs(opacity) != 100} {
	array set attr [wm attributes $w]
	if {[info exists attr(-alpha)]} {
	    after idle [list \
	      wm attributes $w -alpha [expr {$prefs(opacity)/100.0}]]
	}
    }
    
    # This is binding for the apple menu which is created automatically.
    if {[tk windowingsystem] eq "aqua"} {
	bind $w <$this(modkey)-Key-q> { ::UserActions::DoQuit -warning 1 }
    }
    ::hooks::run newToplevelWindowHook $w
    
    return $w
}

# Unreliable!!!
proc ::UI::SetAquaProxyIcon {w} {
    
    set f [info nameofexecutable]
    if {$f ne ""} {
	set path [eval file join [lrange [file split $f] 0 end-3]]
	wm attributes $w -titlepath $path -modified 0
    }
}

# UI::DoCloseWindow --
#
#       Take special actions before a window is closed.
#       
#       Notes: There are three ways to close a window:
#       1) from the menus Close Window command
#       2) using the menu keyboard shortcut command/control-w
#       3) clicking the windows close button
#       
#       If any cleanup etc. is necessary all three must execute the same code.
#       In case where window must not be destroyed a hook must be registered
#       that returns stop.
#       Default behaviour when no hook registered is to destroy window.

proc ::UI::DoCloseWindow {{wevent ""}} {
    variable topcache
    
    set w ""
    if {$wevent eq ""} {
	set wfocus [focus]
	if {$wfocus ne ""} {
	    set w [winfo toplevel [focus]]
	}
    } else {
	set w $wevent
    }
    if {$w ne ""} {

	Debug 2 "::UI::DoCloseWindow winfo class $w=[winfo class $w]"

	# Give components a chance to intersect destruction. (Win taskbar)
	set result [::hooks::run preCloseWindowHook $w]    
	if {[string equal $result "stop"]} {
	    return
	}
	
	if {[info exists topcache($w,-closecommand)]} {
	    set result [uplevel #0 $topcache($w,-closecommand) $w]
	    if {[string equal $result "stop"]} {
		return
	    }
	    catch {destroy $w}
	    array unset topcache $w,*
	}
    
	# Run hooks. Only the one corresponding to the $w needs to act!
	set result [::hooks::run closeWindowHook $w]    
	if {![string equal $result "stop"]} {
	    catch {destroy $w}
	    array unset topcache $w,*
	}
    }
}

# UI::GetAllToplevels --
# 
#       Returns a list of all existing toplevel windows created using Toplevel.

proc ::UI::GetAllToplevels { } {
    variable topcache

    foreach {key w} [array get topcache *,w] {
	if {[winfo exists $w]} {
	    lappend tmp $w
	}
    }
    return $tmp
}

proc ::UI::WithdrawAllToplevels { } {
    variable topcache
    
    if {[string equal $topcache(state) "show"]} {
	foreach w [GetAllToplevels] {
	    set topcache($w,prevstate) [wm state $w]
	    wm withdraw $w
	}
	set topcache(state) hide
    }
}

proc ::UI::ShowAllToplevels { } {
    variable topcache
    
    if {[string equal $topcache(state) "hide"]} {
	foreach w [GetAllToplevels] {
	    if {[string equal $topcache($w,prevstate) "normal"]} {
		set topcache($w,prevstate) [wm state $w]
		wm deiconify $w
	    }
	}
	set topcache(state) show
    }
}

proc ::UI::GetToplevelState { } {
    variable topcache
    
    return $topcache(state)
}

# UI::GetToplevelFromPath --
# 
#       As 'winfo toplevel' but window need not exist.

proc ::UI::GetToplevelFromPath {w} {

    if {[string equal $w "."]} {
	return $w
    } else {
	regexp {^(\.[^.]+)} $w match wpath
	return $wpath
    }
}

# UI::Grab --
# 
# 

proc ::UI::Grab {w} {
    
    catch {grab $w}
    if {[tk windowingsystem] eq "aqua"} {
	
	# Disable menubar except Edit menu.
	set m [$w cget -menu]
	MenubarDisableBut $m edit
    }
}

proc ::UI::GrabRelease {w} {
    
    catch {grab release $w}
    if {[tk windowingsystem] eq "aqua"} {
	
	# Enable menubar.
	MenubarEnableAll [$w cget -menu]
    }
}

# UI::ScrollFrame --
# 
#       A few functions to make scrollable frames.

proc ::UI::ScrollFrame {w args} {
    
    array set opts {
	-bd         0
	-padding    {0}
	-propagate  1
	-relief     flat
	-width      0
    }
    array set opts $args
    
    frame $w -class Scrollframe -bd $opts(-bd) -relief $opts(-relief)
    ttk::scrollbar $w.ysc -command [list $w.can yview]
    if {$opts(-width)} {
	set cwidth [expr {$opts(-width) - $opts(-bd) - [winfo reqwidth $w.ysc]}]
	canvas $w.can -yscrollcommand [list $w.ysc set] -highlightthickness 0 \
	  -width $cwidth
    } else {
	canvas $w.can -yscrollcommand [list $w.ysc set] -highlightthickness 0
    }
    pack $w.ysc -side right -fill y
    pack $w.can -side left -fill both -expand 1
    
    if {!$opts(-propagate)} {
	ttk::frame $w.can.bg
	$w.can create window 0 0 -anchor nw -window $w.can.bg -tags twin
    }
    ttk::frame $w.can.f -padding $opts(-padding)
    $w.can create window 0 0 -anchor nw -window $w.can.f -tags twin
    
    if {$opts(-propagate)} {
	bind $w.can.f <Configure> [list ::UI::ScrollFrameResize $w]
    } else {
	bind $w.can.f <Configure> [list ::UI::ScrollFrameResizeScroll $w]
	bind $w.can   <Configure> [list ::UI::ScrollFrameResizeBg $w]
    }
    return $w
}

proc ::UI::ScrollFrameResize {w} {
        
    set bbox [$w.can bbox twin]
    set width [winfo width $w.can.f]
    $w.can configure -width $width -scrollregion $bbox
}

proc ::UI::ScrollFrameResizeScroll {w} {
	
    set bbox [$w.can bbox all]
    $w.can configure -scrollregion $bbox
}

proc ::UI::ScrollFrameResizeBg {w} {
    
    set bbox [$w.can bbox all]
    set width  [winfo width $w.can]
    set height [winfo height $w.can]
    #$w.can.bg configure -width $width -height [lindex $bbox 3]
    $w.can.bg configure -width $width -height $height
}

proc ::UI::ScrollFrameInterior {w} {
 
    return $w.can.f
}

# UI::ScrollSet --
# 
#       Command for auto hide/show scrollbars.

proc ::UI::ScrollSet {wscrollbar geocmd offset size} {
    
    if {($offset != 0.0) || ($size != 1.0)} {
	eval $geocmd
	$wscrollbar set $offset $size
    } else {
	set manager [lindex $geocmd 0]
	$manager forget $wscrollbar
    }
}

proc ::UI::GetPaddingWidth {padding} {
    
    switch -- [llength $padding] {
	1 {
	    return [expr {2*$padding}]
	}
	2 {
	    return [expr {2*[lindex $padding 0]}]
	}
	4 {
	    return [expr {[lindex $padding 0] + [lindex $padding 2]}]
	}
    }
}

proc ::UI::GetPaddingHeight {padding} {
    
    switch -- [llength $padding] {
	1 {
	    return [expr {2*$padding}]
	}
	2 {
	    return [expr {2*[lindex $padding 1]}]
	}
	4 {
	    return [expr {[lindex $padding 1] + [lindex $padding 3]}]
	}
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

proc ::UI::SaveWinGeom {key {w ""}} {
    global  prefs
    
    if {$w eq ""} {
	set w $key
    }
    if {[winfo exists $w]} {
	
	# If a bug somewhere we may get  1x1+563+158  which shall never be saved!
	set geom [wm geometry $w]
	lassign [ParseWMGeometry $geom] width height x y
	if {$width > 1 && $height > 1} {
	    set prefs(winGeom,$key) $geom
	}
    }
}

proc ::UI::SaveWinPrefixGeom {wprefix {key ""}} {
    
    if {$key eq ""} {
	set key $wprefix
    }
    set win [GetFirstPrefixedToplevel $wprefix]
    if {$win ne ""} {
	SaveWinGeom $key $win
    }	
}

proc ::UI::SaveWinGeomUseSize {key geom} {
    global  prefs
    
    set prefs(winGeom,$key) $geom
}

proc ::UI::SaveSashPos {key w} {
    global  prefs
    
    if {[winfo exists $w]} {
	set prefs(sashPos,$key) [$w sashpos 0]
    }
}

proc ::UI::SetWindowPosition {w {key ""}} {
    global  prefs
    
    if {$key eq ""} {
	set key $w
    }
    if {[info exists prefs(winGeom,$key)]} {

	# We shall verify that the window is not put offscreen.
	lassign [ParseWMGeometry $prefs(winGeom,$key)] width height x y

	# Protect for corrupted prefs.
	if {$width < 20}  {set width 20}
	if {$height < 20} {set height 20}

	KeepOnScreen $w x y $width $height
	wm geometry $w +${x}+${y}
    }
}

proc ::UI::SetWindowGeometry {w {key ""}} {
    global  prefs
    
    if {$key eq ""} {
	set key $w
    }
    if {[info exists prefs(winGeom,$key)]} {

	# We shall verify that the window is not put offscreen.
	lassign [ParseWMGeometry $prefs(winGeom,$key)] width height x y

	# Protect for corrupted prefs.
	if {$width < 20}  {set width 20}
	if {$height < 20} {set height 20}

	KeepOnScreen $w x y $width $height
	wm geometry $w ${width}x${height}+${x}+${y}
    }
}

# @@@ not working...

proc ::UI::SetSashPos {key w} {
    global  prefs
    
    if {[info exists prefs(sashPos,$key)]} {
	$w sashpos 0 $prefs(sashPos,$key)
    }
}

proc ::UI::KeepOnScreen {w xVar yVar width height} {
    global  this
    upvar $xVar x
    upvar $yVar y
    
    set margin 10
    set topmargin 0
    set botmargin 40
    if {[string match mac* $this(platform)]} {
	set topmargin 20
    }
    set screenwidth  [winfo vrootwidth $w]
    set screenheight [winfo vrootheight $w]
    set x2 [expr {$x + $width}]
    set y2 [expr {$y + $height}]
    if {$x < 0} {
	set x $margin
    }
    if {$x > [expr {$screenwidth - $margin}]} {
	set x [expr {$screenwidth - $width - $margin}]
    }
    if {$y < $topmargin} {
	set y $topmargin
    }
    if {$y > [expr {$screenheight - $botmargin}]} {
	set y [expr {$screenheight - $height - $botmargin}]
    }
}

proc ::UI::GetFirstPrefixedToplevel {wprefix} {
    
    set win ""
    set wins [lsearch -all -inline -glob [winfo children .] ${wprefix}*]
    if {[llength $wins]} {
	
	# 1st priority, pick if on top.
	set wfocus [focus]
	if {$wfocus ne ""} {
	    set win [winfo toplevel $wfocus]
	}
	set win [lsearch -inline $wins $wfocus]
	if {$win eq ""} {
	    
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

# @@@ All this menu code is a total mess!!! Perhaps a snidget?

# UI::NewMenu --
# 
#       Creates a new menu from a previously defined menu definition list.
#       
# Arguments:
#       w           toplevel window
#       wmenu       the menus widget path name (".menu.file" etc.).
#       label       its label.
#       menuSpec    a hierarchical list that defines the menu content.
#                   {{type name cmd state accelerator opts} {{...} {...} ...}}
#       state       'normal' or 'disabled'.
#       args        form ?-varName value? list that defines local variables to set.
#       
# Results:
#       $wmenu

proc ::UI::NewMenu {w wmenu label menuSpec state args} {    
    variable mapWmenuToWtop
    variable cachedMenuSpec
            
    # Need to cache the complete menuSpec's since needed in MenuMethod.
    set cachedMenuSpec($w,$wmenu) $menuSpec
    set mapWmenuToWtop($wmenu)    $w

    eval {BuildMenu $w $wmenu $label $menuSpec $state} $args
}

# UI::BuildMenu --
#
#       Make menus recursively from a hierarchical menu definition list.
#       Only called from ::UI::NewMenu!
#
# Arguments:
#       w           toplevel window
#       wmenu       the menus widget path name (".menu.file" etc.).
#       mLabel      its mLabel.
#       menuDef     a hierarchical list that defines the menu content.
#                   {{type name cmd state accelerator opts} {{...} {...} ...}}
#       state       'normal' or 'disabled'.
#       args        form ?-varName value? list that defines local variables to set.
#       
# Results:
#       $wmenu

proc ::UI::BuildMenu {w wmenu mLabel menuDef state args} {
    global  this wDlgs prefs

    variable menuKeyToIndex
    variable menuNameToWmenu
    variable mapWmenuToWtop
    variable cachedMenuSpec
            
    # This is also used to rebuild an existing menu.
    if {[winfo exists $wmenu]} {
	
	# The toplevel cascades must not be deleted since this changes
	# their relative order.
	# Also must be sure to delete any child cascades so they are added
	# back properly below.
	$wmenu delete 0 end
	foreach mchild [winfo children $wmenu] {
	    destroy $mchild
	}
	set m $wmenu
	array unset menuKeyToIndex  $wmenu,*
	set exists 1
    } else {
	set m [menu $wmenu -tearoff 0]
	set exists 0
    }
    set wparent [winfo parent $wmenu]
    
    foreach {optName value} $args {
	set varName [string trimleft $optName "-"]
	set $varName $value
    }

    # A trick to make this work for popup menus, which do not have a Menu parent.
    if {!$exists && [string equal [winfo class $wparent] "Menu"]} {
	$wparent add cascade -label [mc $mLabel] -menu $m
    }
    
    # If we don't have a menubar, for instance, if embedded toplevel.
    # Only for the toplevel menubar.
    if {[string equal $wparent ".menu"] &&  \
      [string equal [winfo class $wparent] "Frame"]} {
	label ${wmenu}la -text [mc $mLabel]
	pack  ${wmenu}la -side left -padx 4
	bind  ${wmenu}la <Button-1> [list ::UI::DoTopMenuPopup %W $wmenu]
    }
    
    set mod $this(modkey)
    set i 0
    foreach line $menuDef {
	foreach {type name cmd mstate accel mopts subdef} $line {
	    
	    # Localized menu label. Special for mAboutCoccinella!
	    if {$name eq "mAboutCoccinella"} {
		set locname [mc {About %s} $prefs(appName)]
	    } else {
		set locname [mc $name]
	    }
	    set menuKeyToIndex($wmenu,$name) $i
	    set menuNameToWmenu($w,$mLabel,$name) $wmenu
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
		
		set wsubmenu $wmenu.$mt
		set cachedMenuSpec($w,$wsubmenu) $subdef
		set mapWmenuToWtop($wsubmenu) $w
		eval {BuildMenu $w $wsubmenu $name $subdef $state} $args
		
		# Explicitly set any disabled state of cascade.
		MenuMethod $m entryconfigure $name -state $mstate
	    } else {
		
		# All variables (and commands) in menuDef's cmd shall be 
		# substituted! Be sure they are all in here.

		# BUG: [ 1340712 ] Ex90 Error when trying to start New whiteboard 
		# FIX: protect menuDefs [string map {$ \\$} $f]
		# @@@ No spaces allowed in variables!
		set cmd [subst -nocommands $cmd]
		if {[string length $accel]} {
		    lappend mopts -accelerator ${mod}+${accel}

		    # Cut, Copy & Paste handled by widgets internally!
		    if {![regexp {(X|C|V)} $accel]} {
			set key [string map {< less > greater}  \
			  [string tolower $accel]]
			
			if {[string equal $state "normal"]} {
			    if {[string equal $mstate "normal"]} {
				bind $w <${mod}-Key-${key}> $cmd
			    }
			} else {
			    bind $w <${mod}-Key-${key}> {}
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

proc ::UI::GetMenu {w label1 {label2 ""}} {
    variable menuNameToWmenu

    return $menuNameToWmenu($w,$label1,$label2)
}

proc ::UI::GetMenuKeyToIndex {wmenu key} {
    variable menuKeyToIndex

    return $menuKeyToIndex($wmenu,$key)
}

proc ::UI::HaveMenuEntry {wmenu mLabel} {
    variable menuKeyToIndex

    return [info exists menuKeyToIndex($wmenu,$mLabel)]
}

proc ::UI::FreeMenu {w} {
    variable mapWmenuToWtop
    variable cachedMenuSpec
    variable menuKeyToIndex
    variable menuNameToWmenu
    
    foreach key [array names cachedMenuSpec $w,*] {
	set wmenu [string map [list "$w," ""] $key]
	unset mapWmenuToWtop($wmenu)
	array unset menuKeyToIndex $wmenu,*
    }
    array unset cachedMenuSpec  $w,*
    array unset menuNameToWmenu $w,*
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
    global  this prefs wDlgs
            
    variable menuKeyToIndex
    variable mapWmenuToWtop
    variable cachedMenuSpec
    variable wThatUseMainMenu
    
    # Be silent about nonexistent entries?
    if {![info exists menuKeyToIndex($wmenu,$key)]} {
	::Debug 2 "::UI::MenuMethod missing menuKeyToIndex($wmenu,$key)"
	return
    }
    
    # Need to cache the complete menuSpec's since needed in MenuMethod.
    set w        $mapWmenuToWtop($wmenu)
    set menuSpec $cachedMenuSpec($w,$wmenu)
    set mind     $menuKeyToIndex($wmenu,$key)
    
    # This would be enough unless we needed to work with accelerator keys.
    eval {$wmenu $cmd $mind} $args
    
    # Handle any menu accelerators as well. 
    # Make sure the necessary variables for the command exist here!
    
    set wmain [GetMainWindow]
    set wlist $wmain

    if {$w == $wmain} {
	
	# Handle Macs that use (inherit) the main menu.
	if {[tk windowingsystem] eq "aqua"} {
	    set wtmp $wThatUseMainMenu
	    set wThatUseMainMenu {}
	    foreach wmac $wtmp {
		if {[winfo exists $wmac]} {
		    lappend wThatUseMainMenu $wmac
		}
	    }
	    set wlist [concat $wmain $wThatUseMainMenu]
	}	
    } else {
	set wlist $w
    }
	    
    foreach {key val} $args {
	    
	switch -- $key {
	    -state {
		set mcmd [lindex $menuSpec $mind 2]
		set mcmd [subst -nocommands $mcmd]
		set acc  [lindex $menuSpec $mind 4]

		# Cut, Copy & Paste handled by widgets internally!
		if {($acc ne "") && ![regexp {(X|C|V)} $acc]} {
		    set akey [string map {< less > greater} [string tolower $acc]]
		    foreach w $wlist {
			if {$val eq "normal"} {
			    bind $w <$this(modkey)-Key-${akey}> $mcmd
			} else {
			    bind $w <$this(modkey)-Key-${akey}> {}
			}
		    }
		}
	    }
	}
    }
}

# UI::SetMenuAcceleratorBinds --
# 
#       Used on MacOSX to set accelerator keys for a toplevel that inherits
#       the menu from 'wmenubar'.
#       
# Arguments:
#       w
#       wmenu
#       
# Results:
#       none

proc ::UI::SetMenuAcceleratorBinds {w wmenubar} {
    global  this
    
    variable menuKeyToIndex
    variable mapWmenuToWtop
    variable cachedMenuSpec
    variable wThatUseMainMenu
    
    if {![string match "mac*" $this(platform)]} {
	return
    }

    lappend wThatUseMainMenu $w

    foreach {wmenu wtop} [array get mapWmenuToWtop $wmenubar.*] {
	foreach line $cachedMenuSpec($wtop,$wmenu) {
	    
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
		    bind $w <$this(modkey)-Key-${acckey}> [lindex $line 2]
		}
	    }
	}
    }

    # This sets up the edit menu that we inherit from the main menu.
    bind $w <FocusIn> +[list ::UI::MacFocusFixEditMenu $w $wmenubar %W]
    
    # If we hand over to a 3rd party toplevel window we need to take precautions.
    bind $w <FocusOut> +[list ::UI::MacFocusFixEditMenu $w $wmenubar %W]
}

proc ::UI::BuildAppleMenu {w wmenuapple state} {
    global  this wDlgs
    variable menuDefs
    
    ::UI::NewMenu $w $wmenuapple {} $menuDefs(main,apple) $state
    
    if {[string equal $this(platform) "macosx"]} {
	proc ::tk::mac::ShowPreferences { } {
	    ::Preferences::Build
	}
    }
}

proc ::UI::MenubarDisableBut {mbar name} {

    # @@@ This doesn't fix accelerators!
    set iend [$mbar index end]
    for {set ind 0} {$ind <= $iend} {incr ind} {
	set m [$mbar entrycget $ind -menu]
	if {$name ne [winfo name $m]} {
	    $mbar entryconfigure $ind -state disabled
	}
    }
}

proc ::UI::MenubarEnableAll {mbar} {
    
    # @@@ This doesn't fix accelerators!
    set iend [$mbar index end]
    for {set ind 0} {$ind <= $iend} {incr ind} {
	$mbar entryconfigure $ind -state normal
    }    
}

proc ::UI::MenuDisableAllBut {mw normalList} {

    set iend [$mw index end]
    for {set i 0} {$i <= $iend} {incr i} {
	if {[$mw type $i] ne "separator"} {
	    $mw entryconfigure $i -state disabled
	}
    }
    foreach name $normalList {
	::UI::MenuMethod $mw entryconfigure $name -state normal
    }
}

proc ::UI::DoTopMenuPopup {w wmenu} {
    
    if {[winfo exists $wmenu]} {
	set x [winfo rootx $w]
	set y [expr [winfo rooty $w] + [winfo height $w]]
	tk_popup $wmenu $x $y
    }
}

# UI::PruneMenusFromConfig --
#
#       A method to remove specific menu entries from 'menuDefs' and
#       'menuDefsInsertInd' using an entry in the 'config' array:
#       config(ui,pruneMenus):   mInfo {mDebug mCoccinellaHome}
#
# Arguments:
#       name            the menus key label, mJabber, mEdit etc.
#       menuDefVar      *name* if the menuDef variable.
#       
# Results:
#       None

proc ::UI::PruneMenusFromConfig {name menuDefVar} {
    global  config
    upvar $menuDefVar menuDef
    
    array set pruneArr $config(ui,pruneMenus)
    
    ::Debug 4 "::UI::PruneMenusFromConfig name=$name, prune=[array get pruneArr]"
    
    if {[info exists pruneArr($name)]} {
    
	# Take each in turn and find any matching index.
	foreach mLabel $pruneArr($name) {
	    set idx [lsearch -glob $menuDef *${mLabel}*]
	    if {$idx >= 0} {
		set menuDef [lreplace $menuDef $idx $idx]
	    }
	}
    }
}

# Wrapper for alertbox package to enable png icons.
# A bit hacky!

namespace eval ::UI:: {
    
    variable alertInit 0
    variable alertArgs ""
    
    #option add *alertImage  alert  widgetDefault
    option add *alertImage  light  widgetDefault
}

proc ::UI::AlertBoxInit { } {
    variable alertInit 
    variable alertArgs
    
    if {[::Plugins::HaveImporterForMime image/png]} {
	set alertArgs [list -image  \
	  [::Theme::GetImage [option get . alertImage {}] -suffixes .png]]
    }
    set alertInit 1
}

proc ::UI::AlertBox {msg args} {
    variable alertInit 
    variable alertArgs

    if {!$alertInit} {
	::UI::AlertBoxInit
    }
    eval {::alertbox::alertbox $msg} $alertArgs $args
}

#--- The public interfaces -----------------------------------------------------

namespace eval ::UI::Public:: {
    
    # This is supposed to collect some "public" interfaces useful for
    # 'plugins' and 'components'.
}

# UI::Public::RegisterNewMenu --
#
#       
# Arguments:
#       wpath       
#       name
#       menuSpec    {type label command state accelerator opts {subspec}}
#       
# Results:
#       menu entries added when whiteboard built.

proc ::UI::Public::RegisterNewMenu {mtail name menuSpec} {    
    upvar ::UI::menuSpecPublic menuSpecPublic 
	
    # Make a new menu
    if {[lsearch $menuSpecPublic(wpaths) $mtail] < 0} {
	lappend menuSpecPublic(wpaths) $mtail
    }
    set menuSpecPublic($mtail,name) $name
    set menuSpecPublic($mtail,specs) [list $menuSpec]
}

# UI::Public::RegisterMenuEntry --
# 
#       Lets plugins/components register their own menu entry.

proc ::UI::Public::RegisterMenuEntry {mtail menuSpec} {
    upvar ::WB::menuDefs menuDefs 
    upvar ::WB::menuDefsInsertInd menuDefsInsertInd 
    
    # Keeps track of all registered menu entries.
    variable mainMenuSpec
    
    # Add these entries in a section above the bottom section.
    # Add separator to section component entries.
    
    if {![info exists mainMenuSpec($mtail)]} {

	# Add separator if this is the first addon entry.
	set menuDefs(main,$mtail) [linsert $menuDefs(main,$mtail)  \
	  $menuDefsInsertInd(main,$mtail) {separator}]
	incr menuDefsInsertInd(main,$mtail)
	set mainMenuSpec($mtail) {}
    }
    set menuDefs(main,$mtail) [linsert $menuDefs(main,$mtail)  \
      $menuDefsInsertInd(main,$mtail) $menuSpec]
    set mainMenuSpec($mtail) [concat $mainMenuSpec($mtail) $menuSpec]
}

proc ::UI::Public::GetRegisteredMenuDefs {mtail} {
    variable mainMenuSpec
    
    if {[info exists mainMenuSpec($mtail)]} {
	return $mainMenuSpec($mtail)
    } else {
	return {}
    }
}

#--- There are actually more; sort out later -----------------------------------

proc ::UI::BuildPublicMenus {w wmenu} {
    variable menuSpecPublic
    
    foreach mtail $menuSpecPublic(wpaths) {	
	set m [menu ${wmenu}.${mtail} -tearoff 0]
	$wmenu add cascade -label $menuSpecPublic($mtail,name) -menu $m
	foreach menuSpec $menuSpecPublic($mtail,specs) {
	    BuildMenuEntryFromSpec $w $m $menuSpec
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

proc ::UI::BuildMenuEntryFromSpec {w m menuSpec} {
    
    foreach {type label cmd state accel opts submenu} $menuSpec {
	if {[llength $submenu]} {
	    set mt [menu ${m}.sub -tearoff 0]
	    $m add cascade -label $label -menu $mt
	    foreach subm $submenu {
		BuildMenuEntryFromSpec $mt $subm
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

proc ::UI::UndoConfig {w token what mstate} {
        
    set medit $w.menu.edit
    
    switch -- $what {
	undo {
	    MenuMethod $medit entryconfigure mUndo -state $mstate
	}
	redo {
	    MenuMethod $medit entryconfigure mRedo -state $mstate	    
	}
    }
}

# UI::LabelButton --
# 
#       A html link type button from a label widget.

proc ::UI::LabelButton {w args} {

    array set eopts {
	-command          {}
    }
    array set lopts {
	-foreground       blue
	-activeforeground red
    }    
    foreach {key value} $args {	
	switch -- $key {
	    -command {
		set eopts($key) $value
	    }
	    default {
		set lopts($key) $value
	    }
	}
    }    
    eval {label $w} [array get lopts]
    set cursor [$w cget -cursor]
    array set fontArr [font actual [$w cget -font]]
    set fontArr(-underline) 1
    $w configure -font [array get fontArr]
    bind $w <Button-1> $eopts(-command)
    bind $w <Enter> [list $w configure -fg $lopts(-activeforeground) -cursor hand2]
    bind $w <Leave> [list $w configure -fg $lopts(-foreground) -cursor $cursor]
    return $w
}

namespace eval ::UI:: {
    
    variable megauid 0
}

# UI::MegaDlgMsgAndEntry --
# 
#       A mega widget dialog with a message and a single entry.

proc ::UI::MegaDlgMsgAndEntry {title msg label varName btcancel btok args} {
    global this
    
    variable finmega
    variable megauid
    upvar $varName entryVar
    
    set entryopts {}
    foreach {key value} $args {
	switch -- $key {
	    -show {
		lappend entryopts $key $value
	    }
	}
    }
    if {![info exists entryVar]} {
	set entryVar ""
    }
    
    set w .mega[incr megauid]
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} \
      -closecommand ::UI::MegaDlgMsgCloseCmd
    wm title $w $title
    set finmega -1
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg  \
      -padding {0 0 0 6} -wraplength 300 -justify left -text $msg
    pack $wbox.msg -side top -anchor w
    
    set wmid $wbox.m
    set wentry $wmid.e
    ttk::frame $wmid
    pack  $wmid  -side top -fill x
    
    ttk::label $wmid.l -text $label
    eval {ttk::entry $wentry} $entryopts

    grid  $wmid.l  $wmid.e
    grid  $wmid.e  -sticky ew
    grid columnconfigure $wmid 1 -weight 1
    
    $wentry insert end $entryVar
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text $btok  \
      -default active -command [list set [namespace current]::finmega 1]
    ttk::button $frbot.btcancel -text $btcancel  \
      -command [list set [namespace current]::finmega 0]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side top -fill x
    
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

proc ::UI::MegaDlgMsgCloseCmd {w} {
    variable finmega
    
    set finmega 0
    return stop
}

# UI::OkCancelButtons --
# 
# 

proc ::UI::OkCancelButtons {args} {
    
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	set i 0
	foreach spec $args {
	    set wbt [eval {ttk::button} $spec]
	    pack $wbt -side right
	    if {[expr $i & 2] == 1} {
		pack $wbt -padx $padx
	    }
	    incr i
	}
    } else {
	for {set i [expr [llength $args] - 1]} {$i >= 0} {incr i -1} {
	    set wbt [eval {ttk::button} [lindex $args $i]]
	    pack $wbt -side right
	    if {[expr $i & 2] == 1} {
		pack $wbt -padx $padx
	    }
	}
    }
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
    
    set locals($w,w) [winfo toplevel $w]
    
    # Set binding to focus to set normal/disabled correctly.
    bind $locals($w,w) <FocusIn> "+ ::UI::CutCopyPasteFocusIn $w"
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
    
    if {$wfocus eq ""} {
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
		if {$val eq "normal"} {
		    $w.$which configure -image $locals(im$which)
		    bind $w.$which <Button-1>   \
		      [list $w.$which configure -image $locals(im${which}Push)]
		    bind $w.$which <ButtonRelease>  \
		      "[list $w.$which configure -image $locals(im$which)]; \
		      [list ::UI::CutCopyPasteCmd $which]"
		} elseif {$val eq "disabled"} {
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
	if {[$wfocus selection present] eq "1"} {
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
    set locals($w,w) [winfo toplevel $w]
    
    bind $w <Button-1> [list $w configure -image $locals(imprintPush)]
    bind $w <ButtonRelease> "[list $w configure -image $locals(imprint)]; $cmd"
    
    return $w
}



# ::UI::ParseWMGeometry --
# 
#       Parses 'wm geometry' result into a list.
#       
# Arguments:
#       wmgeom      output from 'wm geometry'
#       
# Results:
#       list {width height x y}

proc ::UI::ParseWMGeometry {wmgeom} {
    regexp {([0-9]+)x([0-9]+)\+(\-?[0-9]+)\+(\-?[0-9]+)} $wmgeom - w h x y
    return [list $w $h $x $y]
}

# This is to a large extent OBSOLETE!!!
# Handled via -postcommand instead

# UI::FixMenusWhenSelection --
# 
#       Sets the correct state for menus and buttons when selection.
#       Take the whiteboard's state into accounts.
#       
# Arguments:
#       win     the widget that contains something that is selected.
#
# Results:

proc ::UI::FixMenusWhenSelection {win} {
    global  this
    
    set w      [winfo toplevel $win]
    set wClass [winfo class $win]
    set medit $w.menu.edit 
    
    Debug 6 "::UI::FixMenusWhenSelection win=$win,\n\tw=$w, wClass=$wClass"
    
    # Do different things dependent on the type of widget.
    if {[winfo exists $w.menu] && [string equal $wClass "Canvas"]} {
	
	# Respect any disabled whiteboard state.
	upvar ::WB::${w}::opts opts
	set isDisabled 0
	if {[string equal $opts(-state) "disabled"]} {
	    set isDisabled 1
	}
	
	# Any images selected?
	set allSelected [$win find withtag selected]
	set anyImageSel 0
	set anyNotImageSel 0
	set anyTextSel 0
	set allowFlip 0	
	foreach id $allSelected {
	    set theType [$win type $id]
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
	  ([llength [$win select item]] == 0)} {
	    
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
		if {[$win selection present] eq "1"} {
		    set setState normal
		}
	    }
	    Text {
		if {[string length [$win tag ranges sel]] > 0} {
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
	} elseif {[string equal $this(platform) "macosx"]} {
	    
	    # We use the menu associated with wmainmenu since it is default one.
	    set medit [GetMainMenu].edit
	    ::UI::MenuMethod $medit entryconfigure mCut -state $setState
	    ::UI::MenuMethod $medit entryconfigure mCopy -state $setState
	    ::UI::MenuMethod $medit entryconfigure mPaste -state $haveClipState
	}
	
	# If we have a cut/copy/paste row of buttons need to set their state.
	if {[winfo exists $win]} {
	    ::UI::CutCopyPasteCheckState $win $setState $haveClipState
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
#       wmenu
#       wfocus      the %W which is either equal to $w or a children of it.
#       
# Results:
#       none

proc ::UI::MacFocusFixEditMenu {w wmenu wfocus} {
    
    # Binding to a toplevel is also triggered by its children.
    if {$w != $wfocus} {
	return
    }
    
    # The <FocusIn> events are sent in order, from toplevel and down
    # to the actual window with focus.
    # Any '::UI::FixMenusWhenSelection' will therefore be called after this.
    set medit $wmenu.edit
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

