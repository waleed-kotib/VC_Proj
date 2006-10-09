#  UI.tcl ---
#  
#      This file is part of The Coccinella application. It implements user
#      interface elements.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#  
# $Id: UI.tcl,v 1.135 2006-10-09 14:18:18 matben Exp $

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
    option add *applicationImage         coccinella64   widgetDefault
    
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
    ::Theme::GetImageWithNameEx [option get . buttonOKImage {}]
    ::Theme::GetImageWithNameEx [option get . buttonCancelImage {}]
    ::Theme::GetImageWithNameEx [option get . buttonTrayImage {}]
}

proc ::UI::InitCommonBinds { } {
    global  this
    
    # Read only text widget bindings.
    # Usage: bindtags $w [linsert [bindtags $w] 0 ReadOnlyText]
    bind ReadOnlyText <Button-1> { focus %W }
    bind ReadOnlyText <Tab> { 	
	focus [tk_focusNext %W]
	break
    }
    bind ReadOnlyText <Shift-Tab> { 	
	focus [tk_focusPrev %W]
	break
    }
        
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

if {0} {
    # Read only text widget.
    pack [text .t]
    .t insert end "jfioepfhouidšs fhuldshbflds fhlds gfdskl fg"
    .t configure -state disabled
    bind .t <1> {focus %W}
    toplevel .tt
    pack [text .tt.t]
}

proc ::UI::InitVirtualEvents { } {
    global  this
      
    # Virtual events.
    event add <<CloseWindow>> <$this(modkey)-Key-w>
    event add <<ReturnEnter>> <Return> <KP_Enter>
    event add <<Find>>        <$this(modkey)-Key-f>
    event add <<FindAgain>>   <$this(modkey)-Key-g>

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
      {command   mAboutCoccinella    {::Splash::SplashScreen}   {}}
    set menuDefs(main,info,aboutquicktimetcl)  \
      {command   mAboutQuickTimeTcl  {::Dialogs::AboutQuickTimeTcl} {}}

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
	    return [::JUI::GetMainWindow]
	}
	default {
	    return [::P2P::GetMainWindow]
	}
    }
}

proc ::UI::GetMainMenu { } {
    global  prefs
    
    switch -- $prefs(protocol) {
	jabber {
	    return [::JUI::GetMainMenu]
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
    global  this
    
    if {[tk windowingsystem] eq "aqua" \
      && [info exists this(package,carbon)]  \
      && $this(package,carbon)} {
	return [expr [carbon::process current] == [carbon::process front]]
    } else {
	
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
    wm protocol $w WM_DELETE_WINDOW [list ::UI::DoCloseWindow $w "wm"]
    if {$argsArr(-allowclose)} {
	bind $w <Escape> [list ::UI::DoCloseWindow $w "command"]
    }
    if {[tk windowingsystem] eq "aqua"} {
	if {[info exists argsArr(-macclass)]} {
	    eval {::tk::unsupported::MacWindowStyle style $w} $argsArr(-macclass)
	} elseif {[info exists argsArr(-macstyle)]} {
	    ::tk::unsupported::MacWindowStyle style $w $argsArr(-macstyle)
	}
	# Unreliable!!!
	# ::UI::SetAquaProxyIcon $w
    }
    if {$argsArr(-allowclose)} {
	bind $w <<CloseWindow>> [list ::UI::DoCloseWindow $w "command"]
    }
    if {$argsArr(-usemacmainmenu)} {
	SetMenubarAcceleratorBinds $w [GetMainMenu]
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
    
    # We only want to bind to the actual toplevel window. Check in handlers.
    # @@@ This is not the most reliable way to get application activate events.
    bind $w <FocusIn>  +[list ::UI::OnFocusIn %W $w]
    bind $w <FocusOut> +[list ::UI::OnFocusOut %W $w]
    bind $w <Destroy>  +[list ::UI::OnDestroy %W $w]

    ::hooks::run newToplevelWindowHook $w
    
    return $w
}

namespace eval ::UI {
    
    variable appInFront 1
    variable closeType -
}

proc ::UI::OnFocusIn {win w} {
    variable appInFront
    
    if {$win eq $w} {
	if {!$appInFront} {
	    set appInFront 1
	    ::hooks::run appInFrontHook
	}
    }
}

proc ::UI::OnFocusOut {win w} {
    variable appInFront
    
    # We must check focus after idle.
    if {$win eq $w} {
	after idle {
	    if {[focus] eq ""} {
		set ::UI::appInFront 0
		::hooks::run appInBackgroundHook
	    }
	}
    }
}

proc ::UI::OnDestroy {win w} {
    variable topcache
    
    if {$win eq $w} {
	array unset topcache $w,*
    }
}

# @@@ Unreliable!!!
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
#       Notes: There are four ways to close a window:
#       1) from the menus Close Window command
#       2) using the menu keyboard shortcut command/control-w
#       3) using the <<CloseWindow>> virtual event
#       4) clicking the windows close button
#       
#       If any cleanup etc. is necessary all three must execute the same code.
#       In case where window must not be destroyed a hook must be registered
#       that returns stop.
#       
#       Default behaviour when no hook registered is to destroy window.
#       
# Arguments:
#       wevent
#       type:
#         command:    menu action or accelerator keys
#         wm:         window manager; user pressed windows close button.

proc ::UI::DoCloseWindow {{wevent ""} {type "command"}} {
    variable topcache
    variable closeType $type
    
    set w ""
    if {$wevent eq ""} {
	if {[winfo exists [focus]]} {
	    set w [winfo toplevel [focus]]
	}
    } else {
	set w $wevent
    }
    if {$w ne ""} {

	Debug 2 "::UI::DoCloseWindow winfo class $w=[winfo class $w], type=$type"

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
	}
    
	# Run hooks. Only the one corresponding to the $w needs to act!
	set result [::hooks::run closeWindowHook $w]    
	if {![string equal $result "stop"]} {
	    catch {destroy $w}
	}
    }
}

# UI::GetCloseWindowType --
# 
#       There are situations where we want to know why a window is getting closed:
#         command:    menu action or accelerator keys
#         wm:         window manager; user pressed windows close button.

proc ::UI::GetCloseWindowType {} {
    variable closeType
    return $closeType
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
#                   {{type name cmd accelerator opts} {{...} {...} ...}}
#       args        form ?-varName value? list that defines local variables to set.
#       
# Results:
#       $wmenu

proc ::UI::NewMenu {w wmenu label menuSpec args} {    
    variable mapWmenuToWtop
    variable cachedMenuSpec
            
    # Need to cache the complete menuSpec's since needed in MenuMethod.
    set cachedMenuSpec($w,$wmenu) $menuSpec
    set mapWmenuToWtop($wmenu)    $w

    eval {BuildMenu $w $wmenu $label $menuSpec} $args
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
#                   {{type name cmd accelerator opts} {{...} {...} ...}}
#       args        form ?-varName value? list that defines local variables to set.
#       
# Results:
#       $wmenu

proc ::UI::BuildMenu {w wmenu mLabel menuDef args} {
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
	foreach {type name cmd accel mopts subdef} $line {
	    
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
		eval {BuildMenu $w $wsubmenu $name $subdef} $args
		
		# Explicitly set any disabled state of cascade.
		MenuMethod $m entryconfigure $name
	    } else {
		
		# All variables (and commands) in menuDef's cmd shall be 
		# substituted! Be sure they are all in here.

		# BUG: [ 1340712 ] Ex90 Error when trying to start New whiteboard 
		# FIX: protect menuDefs [string map {$ \\$} $f]
		# @@@ No spaces allowed in variables!
		set cmd [subst -nocommands $cmd]
		if {[string length $accel]} {
		    lappend mopts -accelerator ${mod}+${accel}
		}
		eval {$m add $type -label $locname -command $cmd} $mopts 
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
    variable menuKeyToIndex
    
    # Be silent about nonexistent entries?
    if {[info exists menuKeyToIndex($wmenu,$key)]} {
	set mind  $menuKeyToIndex($wmenu,$key)
	eval {$wmenu $cmd $mind} $args
    }
}

# UI::SetMenubarAcceleratorBinds --
# 
#       Binds all main menu accelerator keys to window.
#       
# Arguments:
#       w
#       wmenu
#       
# Results:
#       none

proc ::UI::SetMenubarAcceleratorBinds {w wmenubar} {
    global  this
    
    variable menuKeyToIndex
    variable mapWmenuToWtop
    variable cachedMenuSpec
        
    foreach {wmenu wtop} [array get mapWmenuToWtop $wmenubar.*] {
	foreach line $cachedMenuSpec($wtop,$wmenu) {
	    
	    # {type name cmd accel mopts subdef} $line
	    # Cut, Copy & Paste handled by widgets internally!
	    set accel [lindex $line 3]
	    if {[string length $accel] && ![regexp {(X|C|V)} $accel]} {

		# Must check the actual state of menu!
		set name [lindex $line 1]
		set mind $menuKeyToIndex($wmenu,$name)
		
		# @@@ ???
		set state [$wmenu entrycget $mind -state]
		if {1 || [string equal $state "normal"]} {
		    set acckey [string map {< less > greater}  \
		      [string tolower $accel]]
		    bind $w <$this(modkey)-Key-$acckey> [lindex $line 2]
		}
	    }
	}
    }
}

# UI::SetMenuAcceleratorBinds --
# 
#       Sets the accelerator key binds to toplevel for specific menu.

proc ::UI::SetMenuAcceleratorBinds {w wmenu} {
    global  this

    variable cachedMenuSpec
    variable menuKeyToIndex
    
    foreach line $cachedMenuSpec($w,$wmenu) {
	set accel [lindex $line 3]
	if {[string length $accel]} {
	    set name [lindex $line 1]
	    set mind $menuKeyToIndex($wmenu,$name)
	    set key [string map {< less > greater} [string tolower $accel]]
	    bind $w <$this(modkey)-Key-$key> [lindex $line 2]
	}
    }
}

proc ::UI::BuildAppleMenu {w wmenuapple state} {
    variable menuDefs
    
    NewMenu $w $wmenuapple {} $menuDefs(main,apple) $state
    
    if {[tk windowingsystem] eq "aqua"} {
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

proc ::UI::MenuEnableAll {mw} {
    
    set iend [$mw index end]
    for {set i 0} {$i <= $iend} {incr i} {
	if {[$mw type $i] ne "separator"} {
	    $mw entryconfigure $i -state normal
	}
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
    
    set alertArgs  \
      [list -image [::Theme::GetImage [option get . alertImage {}]]]
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

    # Widget specific storage.
    variable $w
    upvar #0 $w state

    set state(button) 0
    
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
      -default active -command [list set $w\(button) ok]
    ttk::button $frbot.btcancel -text $btcancel  \
      -command [list set $w\(button) cancel]
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
    tkwait variable $w\(button)
    
    set entryVar [$wentry get]
    catch {grab release $w}
    catch {destroy $w}
    catch {focus $oldFocus}
    set button $state(button)
    unset -nocomplain state
    
    return $button
}

proc ::UI::MegaDlgMsgCloseCmd {w} {
    variable $w
    upvar #0 $w state
    set state(button) cancel
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

# UI::CutEvent, CopyEvent, PasteEvent --
# 
#       Used in menu commands to generate <<Cut>>, <<Copy>>, and <<Paste>>
#       virtual events for _any_ widget.

proc ::UI::CutEvent {} {
    if {[winfo exists [focus]]} {
	event generate [focus] <<Cut>>
    }	
}

proc ::UI::CopyEvent {} {
    if {[winfo exists [focus]]} {
	event generate [focus] <<Copy>>
    }	
}

proc ::UI::PasteEvent {} {
    if {[winfo exists [focus]]} {
	event generate [focus] <<Paste>>
    }	
}

proc ::UI::CloseWindowEvent {} {
    if {[winfo exists [focus]]} {
	event generate [focus] <<CloseWindow>>
    }
}

proc ::UI::FindEvent {} {
    if {[winfo exists [focus]]} {
	event generate [focus] <<Find>>
    }	
}

proc ::UI::FindAgainEvent {} {
    if {[winfo exists [focus]]} {
	event generate [focus] <<FindAgain>>
    }	
}

# UI::GenericCCPMenuStates --
# 
#       Retuns a flat array with cut, copy, and paste menu entry states when
#       any of the standard widgets TEntry, Entry, and Text have focus.
#
#       Edits are typically different from other commands in that they operate
#       on a specific widget.

proc ::UI::GenericCCPMenuStates {} {
    
    # @@@ The situation with a ttk::entry in readonly state is not understood.
    # @@@ Not sure focus is needed for selections.
    set w [focus]
    set haveFocus 1
    set haveSelection 0
    set editable 1
    
    array set ccpStateA {
	mCut    disabled
	mCopy   disabled
	mPaste  disabled
    }
    
    if {[winfo exists $w]} {

	switch -- [winfo class $w] {
	    TEntry {
		set haveSelection [$w selection present]
		set state [$w state]
		if {[lsearch $state disabled] >= 0} {
		    set editable 0
		} elseif {[lsearch $state readonly] >= 0} {
		    set editable 0
		}
	    }
	    Entry {
		set haveSelection [$w selection present]
		if {[$w cget -state] eq "disabled"} {
		    set editable 0
		}
	    }
	    Text {
		if {![catch {$w get sel.first sel.last} data]} {
		    if {$data ne ""} {
			set haveSelection 1
		    }
		}
		if {[$w cget -state] eq "disabled"} {
		    set editable 0
		}
	    }
	    default {
		set haveFocus 0
	    }
	}
    }    

    # Cut, copy and paste menu entries.
    if {$haveSelection} {
	if {$editable} {
	    set ccpStateA(mCut) normal
	}
	set ccpStateA(mCopy) normal
    }
    if {![catch {selection get -sel CLIPBOARD} str]} {
	if {$editable && $haveFocus && ($str ne "")} {
	    set ccpStateA(mPaste) normal
	}
    }
    return [array get ccpStateA]
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

