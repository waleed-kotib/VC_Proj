# SlideShow.tcl --
# 
#       Slide show for whiteboard. This is just a first sketch.
#       
#  Copyright (c) 2004  Mats Bengtsson
#  
#       $Id: SlideShow.tcl,v 1.1 2004-07-25 15:05:32 matben Exp $

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
    ::hooks::add initHook                       ::SlideShow::InitHook
    ::hooks::add whiteboardBuildButtonTrayHook  ::SlideShow::BuildButtonsHook
    ::hooks::add whiteboardCloseHook            ::SlideShow::CloseWhiteboard
    ::hooks::add quitAppHook                    ::SlideShow::QuitHook

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
    
    set priv(btdefs) {
	previous     {::SlideShow::Previous $wtop}
	next         {::SlideShow::Next $wtop}
    }
}

proc ::SlideShow::InitHook { } {
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
}

proc ::SlideShow::InitPrefsHook { } {
    global  prefs
    
    set prefs(slideShowDir) ""
    
    ::PreferencesUtils::Add [list  \
      [list prefs(slideShowDir)    prefs_slideShowDir    $prefs(slideShowDir)]]
}

proc ::SlideShow::BuildButtonsHook {wtray} {
    variable priv
    
    set wtop [::UI::GetToplevelNS $wtray]
    foreach {name cmd} $priv(btdefs) {
	set cmd [subst -nocommands -nobackslashes $cmd]
	set txt [string totitle $name]
	set icon $priv(im${name})
	$wtray newbutton $name $txt $icon $icon $cmd
    }
}

proc ::SlideShow::QuitHook { } {
    
    
}

proc ::SlideShow::PickFolder {wtop} {
    global  prefs
    variable priv
    
    set ans [tk_chooseDirectory -mustexist 1 -title "Slide Show Folder"]
    if {$ans != ""} {
	
	# Check first if any useful content?
	set priv($wtop,dir) $ans
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
    parray priv
    
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
    variable priv
    
    set wcan [::WB::GetCanvasFromWtop $wtop]

    switch -- [file extension $fileName] {
	.can {
	    ::CanvasFile::OpenCanvas $wcan $fileName
	}
	default {
	    ::CanvasCmd::DoEraseAll $wtop     
	    ::undo::reset [::WB::GetUndoToken $wtop]
	    ::Import::DoImport $wcan {} -file $fileName
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
    
    set msshow [::UI::GetMenu $wtop "Slide Show" Next]
    ::UI::MenuMethod $msshow entryconfigure Previous -state normal
    ::UI::MenuMethod $msshow entryconfigure Next     -state normal
    if {[string equal $priv($wtop,current) [lindex $priv(pages) 0]]} {
	::UI::MenuMethod $msshow entryconfigure Previous -state disabled
    } elseif {[string equal $priv($wtop,current) [lindex $priv(pages) end]]} {
	::UI::MenuMethod $msshow entryconfigure Next     -state disabled
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
