# SlideShow.tcl --
# 
#       Slide show for whiteboard. This is just a first sketch.
#       
#  Copyright (c) 2004  Mats Bengtsson
#  
#       $Id: SlideShow.tcl,v 1.5 2004-08-18 12:08:58 matben Exp $

namespace eval ::SlideShow:: {
    
}

proc ::SlideShow::Load { } {
    variable priv

    ::Debug 2 "::SlideShow::Load"
    
    set menuspec \
      {cascade     {Slide Show}     {}                              normal   {} {} {
	{command   {Pick Folder...} {::SlideShow::PickFolder $wtop} normal   {} {}}
	{separator}
	{command   {Previous}       {::SlideShow::Previous $wtop}   disabled {} {}}
	{command   {Next}           {::SlideShow::Next $wtop}       disabled {} {}}
	{command   {First}          {::SlideShow::First $wtop}      disabled {} {}}
	{command   {Last}           {::SlideShow::Last $wtop}       disabled {} {}}
      }
    }

    # Define all hooks needed here.
    ::hooks::add prefsInitHook                  ::SlideShow::InitPrefsHook
    ::hooks::add prefsBuildHook                 ::SlideShow::BuildPrefsHook
    ::hooks::add prefsSaveHook                  ::SlideShow::SavePrefsHook
    ::hooks::add prefsCancelHook                ::SlideShow::CancelPrefsHook
    ::hooks::add prefsUserDefaultsHook          ::SlideShow::UserDefaultsHook

    ::hooks::add initHook                       ::SlideShow::InitHook
    ::hooks::add whiteboardBuildButtonTrayHook  ::SlideShow::BuildButtonsHook
    ::hooks::add whiteboardCloseHook            ::SlideShow::CloseWhiteboard

    ::UI::Public::RegisterMenuEntry file $menuspec
    
    component::register SlideShow  \
      "Slide show for the whiteboard. It starts from an image and automatically\
      saves any edits to canvas file when changing page."
    
    set priv(imnext) [image create photo -data {
    R0lGODlhIAAgAPYAMfLy8vHx8fEF5PDw8O/v7+bm5uPj4+Dg4NTU1NPT09DQ
    0M/Pz87Ozs3NzcvLy8rKysnJycjIyMfHx8bGxsXFxcTExMPDw8LCwsHBwcDA
    wL+/v76+vr29vby8vLu7u7q6urm5ubi4uLe3t7a2trW1tbS0tLOzs7KysrGx
    sbCwsK+vr66urq2traysrKurq6qqqqmpqaioqKenp6WlpaSkpKOjo6GhoZ6e
    np2dnZycnJqampiYmJeXl5aWlpWVlZOTk5GRkZCQkI2NjYmJiYaGhoSEhIOD
    g4KCgoCAgH5+fnx8fAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAIA
    LAAAAAAgACAAAAf/gAKCg4SFhoeIiYqLjBgeHBaMkiQeFxQTExcaICSShyMV
    DAoLDhETFBYYGx2dngIgGwoJDRYeIiS4IyAeHiGwkiMUCQoWIiXHyMgjIyS+
    iyEUCA0dydXVKCIaihqzH9bfxyctI4kiCgrUxybg1Sky5IYZwhbJRko07Oow
    rYUkDA3GkBlhAQMJi3wqbIgwxIFYtYElTNwYcgKciRr8BFUI5aFakYPhhOQA
    JyPjKwkOAiIjAhLZCiMrrL3oMYHQCAkRSFQj0sKaCRwjk7XwgcGmhAk6k30E
    hwBDMhc/ig4CUYFCUmRFYlbrEOBBtRdBag7CgKHCiIdaj404UOBstRnwmAh1
    wACi2hEVyBQM2PDNRI6FhUZo6JgMCV4KACCwUwHEgyEPGzxcLZGkAwEE+Uoo
    RCQChMoSOAxM/sYiiONDGj6MzlwixQ4QikiAQFGRdescIaQmkt0ixbp8LHaE
    0MZohAgZL1T8TmYiYRAQGVxlwGWjRgwXLVy8mJEDiIgPrghJJqGDh48f3juL
    DV/IQocPHzawn0+/PqFAADs=
    }]
     
    set priv(imprevious) [image create photo -data {
    R0lGODlhIAAgAPYAMfLy8vHx8fEF5PDw8O/v7+bm5uPj4+Dg4NTU1NPT09DQ
    0M/Pz87Ozs3NzcvLy8rKysnJycjIyMfHx8bGxsXFxcTExMPDw8LCwsHBwcDA
    wL+/v76+vr29vby8vLu7u7q6urm5ubi4uLe3t7a2trW1tbS0tLOzs7KysrGx
    sbCwsK+vr66urq2traysrKurq6qqqqmpqaioqKenp6WlpaSkpKOjo6GhoZ6e
    np2dnZycnJqampiYmJeXl5aWlpWVlZOTk5GRkZCQkI2NjYmJiYaGhoSEhIOD
    g4KCgoCAgH5+fnx8fAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAIA
    LAAAAAAgACAAAAf/gAKCg4SFhoeIiYqLjBgeHBaMkiQeFxQTExcaICSShyMV
    DAoLDhETFBYYGx2dngIgGwoJDRYeIiS4IyAeHiGwkiMUCQoWIiXHyMgjIyS+
    iyEUCA0dydXVKCIaihqzH9bfxyctI4kiCgrU4MgmySky5IYZwhbqxzRKRskm
    MK2FJAwNjIFjgQQGi3zJVNgQYYgDMXAnhtxgd7CaiRr9BFUI5eFbDiEnkLEo
    Yk1GxlcSHAhEtsLIimosiFh70WMCoRESIpBIlgMHu2otZAL1geGmhAk7j2FA
    MJBkNRc/ig4CUYFC0mMPAqRLtsJpshdBbA7CgKHCiGojChw4yxJhshnwlwh1
    wADi24YBCpCpOGIxB8NCIzR0BAcBAIUSKpBUUwHEgyEPGzxc/YaAQIck1RYi
    EgFiJTgSBnAkYxHE8SENHybXQ5ZiBwhFJECgCLn6WIocIaQmit0ixU91LHaE
    0MZohAgZL1T8XqcwCIgMrjLgslEjhosWLl7MyAFExAdXhCST0MHDx4/unMWC
    L2Shw4cPG9bLn0+fUCAAOw==
    }]
    
    set priv(btdefs) [list \
      [list previous $priv(imprevious) $priv(imprevious)  {::SlideShow::Previous $wtop}] \
      [list next     $priv(imnext)     $priv(imnext)      {::SlideShow::Next $wtop}] ]
}

proc ::SlideShow::InitHook { } {
    global  prefs
    variable priv
        
    set mimes {image/gif image/png image/jpeg}
    set priv(mimes) {}
    foreach mime $mimes {
	if {[::Plugins::HaveImporterForMime $mime]} {
	    lappend priv(mimes) $mime
	}
    }
    set priv(suffixes) {.can}
    foreach mime $priv(mimes) {
	set priv(suffixes) [concat $priv(suffixes)  \
	  [::Types::GetSuffixListForMime $mime]]
    }
    
    if {$prefs(slideShow,buttons)} {
	::WB::RegisterShortcutButtons $priv(btdefs)
    }
}

proc ::SlideShow::InitPrefsHook { } {
    global  prefs
    
    set prefs(slideShow,dir) ""
    set prefs(slideShow,buttons) 0
    set prefs(slideShow,autosize) 0
    
    ::PreferencesUtils::Add [list  \
      [list prefs(slideShow,buttons) prefs_slideShow_buttons $prefs(slideShow,buttons)] \
      [list prefs(slideShow,autosize) prefs_slideShow_autosize $prefs(slideShow,autosize)] \
      [list prefs(slideShow,dir)     prefs_slideShow_dir     $prefs(slideShow,dir)]]
}

proc ::SlideShow::BuildPrefsHook {wtree nbframe} {
    global  prefs
    variable tmpPrefs

    $wtree newitem {Whiteboard {SlideShow}} -text [mc {Slide Show}]
    set wpage [$nbframe page {SlideShow}]    
    
    set lfr $wpage.fr
    labelframe $lfr -text [mc {Slide Show}]
    pack $lfr -side top -anchor w -padx 8 -pady 4

    set tmpPrefs(slideShow,buttons) $prefs(slideShow,buttons)
    set tmpPrefs(slideShow,autosize) $prefs(slideShow,autosize)

    checkbutton $lfr.ss -text " Show next and previous buttons"  \
      -variable [namespace current]::tmpPrefs(slideShow,buttons)
    checkbutton $lfr.size -text " Resize canvas utomatically to fit image"  \
      -variable [namespace current]::tmpPrefs(slideShow,autosize)
    pack $lfr.ss $lfr.size -side top -anchor w -padx 8 -pady 2
}

proc ::SlideShow::SavePrefsHook { } {
    global  prefs
    variable tmpPrefs
    variable priv
    
    set prefs(slideShow,buttons) $tmpPrefs(slideShow,buttons)
    set prefs(slideShow,autosize) $tmpPrefs(slideShow,autosize)
    
    if {$prefs(slideShow,buttons)} {
	::WB::RegisterShortcutButtons $priv(btdefs)
    } else {
	::WB::DeregisterShortcutButton previous
	::WB::DeregisterShortcutButton next
    }
}

proc ::SlideShow::CancelPrefsHook { } {
    global  prefs
    variable tmpPrefs

    set key slideShow,buttons
    if {![string equal $prefs($key) $tmpPrefs($key)]} {
	::Preferences::HasChanged
    }
}

proc ::SlideShow::UserDefaultsHook { } {
    global  prefs
    variable tmpPrefs

    set tmpPrefs(slideShow,buttons) $prefs(slideShow,buttons)
}

proc ::SlideShow::BuildButtonsHook {wtray} {
    global  prefs
    variable priv
    
    set wtop [::UI::GetToplevelNS $wtray]
    set priv($wtop,wtray) $wtray
    if {$prefs(slideShow,buttons)} {
	foreach btdef $priv(btdefs) {
	    $wtray buttonconfigure [lindex $btdef 0] -state disabled
	}
    }
}

proc ::SlideShow::PickFolder {wtop} {
    global  prefs
    variable priv
    
    set opts {}
    if {[file isdirectory $prefs(slideShow,dir)]} {
	lappend opts -initialdir $prefs(slideShow,dir)
    }
    set ans [eval {
	tk_chooseDirectory -mustexist 1 -title "Slide Show Folder"} $opts]
    if {$ans != ""} {
	
	# Check first if any useful content?
	set priv($wtop,dir) $ans
	set prefs(slideShow,dir) $ans
	set msshow [::UI::GetMenu $wtop "Slide Show" Next]
	::UI::MenuMethod $msshow entryconfigure First    -state normal
	::UI::MenuMethod $msshow entryconfigure Last     -state normal
	LoadFolder $wtop
    }
}

proc ::SlideShow::LoadFolder {wtop} {
    variable priv
    
    set dir $priv($wtop,dir)
    set files {}
    foreach suff $priv(suffixes) {
	set flist [glob -nocomplain -directory $dir -types f -tails *$suff]
	set files [concat $files $flist]
    }
    set pages {}
    foreach page $files {
	lappend pages [file rootname $page]
    }
    set pages [lsort -unique -dictionary $pages]
    set priv(pages) $pages
    
    # Pick first one.
    OpenPage $wtop [lindex $pages 0]
    SetMenuState $wtop
}

proc ::SlideShow::GetFile {wtop page} {
    variable priv
    
    set rootpath [file join $priv($wtop,dir) $page]
    set path ""
    foreach suff $priv(suffixes) {
	if {[file exists ${rootpath}${suff}]} {
	    set path ${rootpath}${suff}
	    break
	}
    }
    return $path
}

proc ::SlideShow::OpenPage {wtop page} {
    variable priv
    
    set fileName [GetFile $wtop $page]
    OpenFile $wtop $fileName
    set priv($wtop,current) $page
}

proc ::SlideShow::OpenFile {wtop fileName} {
    global  prefs
    variable priv
    
    set wcan [::WB::GetCanvasFromWtop $wtop]

    switch -- [file extension $fileName] {
	.can {
	    ::CanvasFile::OpenCanvas $wcan $fileName
	}
	default {
	    ::CanvasCmd::DoEraseAll $wtop     
	    ::undo::reset [::WB::GetUndoToken $wtop]
	    ::Import::DoImport $wcan {-coords {0 0}} -file $fileName
	}
    }
    if {$prefs(slideShow,autosize)} {
	foreach {width height} [::WB::GetCanvasSize $wtop] {break}
	foreach {bx by bw bh} [$wcan bbox all] {break}
	if {($width < $bw) || ($height < $bh)} {
	    ::WB::SetCanvasSize $wtop $bw $bh
	}
    }
}

proc ::SlideShow::Previous {wtop} {    
    variable priv

    SaveCurrentCanvas $wtop
    set ind [lsearch -exact $priv(pages) $priv($wtop,current)]
    OpenPage $wtop [lindex $priv(pages) [expr $ind - 1]]
    SetMenuState $wtop
}

proc ::SlideShow::Next {wtop} {    
    variable priv

    SaveCurrentCanvas $wtop
    set ind [lsearch -exact $priv(pages) $priv($wtop,current)]
    OpenPage $wtop [lindex $priv(pages) [expr $ind + 1]]
    SetMenuState $wtop
}

proc ::SlideShow::First {wtop} {    
    variable priv

    SaveCurrentCanvas $wtop
    OpenPage $wtop [lindex $priv(pages) 0]
    SetMenuState $wtop
}

proc ::SlideShow::Last {wtop} {    
    variable priv

    SaveCurrentCanvas $wtop
    OpenPage $wtop [lindex $priv(pages) end]
    SetMenuState $wtop
}

proc ::SlideShow::SetMenuState {wtop} {
    variable priv
    
    set wtray $priv($wtop,wtray)
    set msshow [::UI::GetMenu $wtop "Slide Show" Next]
    if {[llength $priv(pages)]} {
	::UI::MenuMethod $msshow entryconfigure Previous -state normal
	::UI::MenuMethod $msshow entryconfigure Next     -state normal
	if {[$wtray exists next]} {
	    $wtray buttonconfigure next     -state normal
	    $wtray buttonconfigure previous -state normal
	}
    }
    if {[string equal $priv($wtop,current) [lindex $priv(pages) 0]]} {
	::UI::MenuMethod $msshow entryconfigure Previous -state disabled
	if {[$wtray exists previous]} {
	    $wtray buttonconfigure previous -state disabled
	}
    } elseif {[string equal $priv($wtop,current) [lindex $priv(pages) end]]} {
	::UI::MenuMethod $msshow entryconfigure Next -state disabled
	if {[$wtray exists next]} {
	    $wtray buttonconfigure next -state disabled
	}
    }
}

proc ::SlideShow::SaveCurrentCanvas {wtop} {
    variable priv

    set wcan [::WB::GetCanvasFromWtop $wtop]
    set fileName [file join $priv($wtop,dir) $priv($wtop,current)].can
    ::CanvasFile::SaveCanvas $wcan $fileName
}

proc ::SlideShow::CloseWhiteboard {wtop} {
    variable priv

    array unset priv $wtop,*
}

#-------------------------------------------------------------------------------
