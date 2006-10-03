# SlideShow.tcl --
# 
#       Slide show for whiteboard. This is just a first sketch.
#       
#  Copyright (c) 2004  Mats Bengtsson
#  
#       $Id: SlideShow.tcl,v 1.22 2006-10-03 06:57:37 matben Exp $

package require undo

namespace eval ::SlideShow:: {
    
}

proc ::SlideShow::Load { } {
    variable priv

    ::Debug 2 "::SlideShow::Load"
    
    set menuspec \
      {cascade     {Slide Show}     {}                             {} {} {
	{command   {Pick Directory} {::SlideShow::PickFolder $w}   {} {}}
	{separator}
	{command   {Previous}       {::SlideShow::Previous $w}   {} {}}
	{command   {Next}           {::SlideShow::Next $w}       {} {}}
	{command   {First}          {::SlideShow::First $w}      {} {}}
	{command   {Last}           {::SlideShow::Last $w}       {} {}}
      }
    }

    # Define all hooks needed here.
    ::hooks::register prefsInitHook                  ::SlideShow::InitPrefsHook
    ::hooks::register prefsBuildHook                 ::SlideShow::BuildPrefsHook
    ::hooks::register prefsSaveHook                  ::SlideShow::SavePrefsHook
    ::hooks::register prefsCancelHook                ::SlideShow::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook          ::SlideShow::UserDefaultsHook
    ::hooks::register prefsDestroyHook               ::SlideShow::DestroyPrefsHook
    ::hooks::register initHook                       ::SlideShow::InitHook
    ::hooks::register whiteboardBuildButtonTrayHook  ::SlideShow::BuildButtonsHook
    ::hooks::register whiteboardCloseHook            ::SlideShow::CloseHook
    ::hooks::register menuPostCommand                ::SlideShow::MenuPostHook
    
    ::UI::Public::RegisterMenuEntry file $menuspec
    
    component::register SlideShow  \
      "Slide show for the whiteboard. It starts from an image and automatically\
      saves any edits to canvas file when changing page."
        
    # PNG
    set priv(imnext) [image create photo -data {
    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
    J4S73uX037syRqkZVn5MAAAAAElFTkSuQmCC
    }]

    # PNG
    set priv(imprevious) [image create photo -data {
    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
    }]

    set priv(btdefs) [list \
      [list previous $priv(imprevious) $priv(imprevious)  {::SlideShow::Previous $w}] \
      [list next     $priv(imnext)     $priv(imnext)      {::SlideShow::Next $w}] ]
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
    
    ::PrefUtils::Add [list  \
      [list prefs(slideShow,buttons) prefs_slideShow_buttons $prefs(slideShow,buttons)] \
      [list prefs(slideShow,autosize) prefs_slideShow_autosize $prefs(slideShow,autosize)] \
      [list prefs(slideShow,dir)     prefs_slideShow_dir     $prefs(slideShow,dir)]]
}

proc ::SlideShow::BuildPrefsHook {wtree nbframe} {
    global  prefs
    variable tmpPrefs

    if {![::Preferences::HaveTableItem Whiteboard]} {
	::Preferences::NewTableItem {Whiteboard} [mc Whiteboard]
    }
    ::Preferences::NewTableItem {Whiteboard {SlideShow}} [mc {Slide Show}]
    set wpage [$nbframe page {SlideShow}]    
    
    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set lfr $wc.fr
    ttk::labelframe $lfr -text [mc {Slide Show}] \
      -padding [option get . groupSmallPadding {}]
    pack $lfr -side top -anchor w

    set tmpPrefs(slideShow,buttons)  $prefs(slideShow,buttons)
    set tmpPrefs(slideShow,autosize) $prefs(slideShow,autosize)

    ttk::checkbutton $lfr.ss -text [mc prefssbts]  \
      -variable [namespace current]::tmpPrefs(slideShow,buttons)
    ttk::checkbutton $lfr.size -text [mc prefssresize]  \
      -variable [namespace current]::tmpPrefs(slideShow,autosize)
 
    grid  $lfr.ss    -sticky w
    grid  $lfr.size  -sticky w
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

proc ::SlideShow::DestroyPrefsHook { } {
    variable tmpPrefs
    
    unset -nocomplain tmpPrefs
}

proc ::SlideShow::BuildButtonsHook {wtray} {
    global  prefs
    variable priv
    
    set w [winfo toplevel $wtray]
    set priv($w,wtray) $wtray
    if {$prefs(slideShow,buttons)} {
	foreach btdef $priv(btdefs) {
	    $wtray buttonconfigure [lindex $btdef 0] -state disabled
	}
    }
}

proc ::SlideShow::PickFolder {w} {
    global  prefs
    variable priv
    
    set opts {}
    if {[file isdirectory $prefs(slideShow,dir)]} {
	lappend opts -initialdir $prefs(slideShow,dir)
    }
    set ans [eval {
	tk_chooseDirectory -mustexist 1 -title [mc {Slide Show Folder}]} $opts]
    if {$ans ne ""} {
	
	# Check first if any useful content?
	set priv($w,dir) $ans
	LoadFolder $w
    }
}

proc ::SlideShow::LoadFolder {w} {
    variable priv
    
    set dir $priv($w,dir)
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
    OpenPage $w [lindex $pages 0]
    SetButtonState $w
}

proc ::SlideShow::GetFile {w page} {
    variable priv
    
    set rootpath [file join $priv($w,dir) $page]
    set path ""
    foreach suff $priv(suffixes) {
	if {[file exists ${rootpath}${suff}]} {
	    set path ${rootpath}${suff}
	    break
	}
    }
    return $path
}

proc ::SlideShow::OpenPage {w page} {
    variable priv
    
    set fileName [GetFile $w $page]
    OpenFile $w $fileName
    set priv($w,current) $page
}

proc ::SlideShow::OpenFile {w fileName} {
    global  prefs
    variable priv
    
    set wcan [::WB::GetCanvasFromWtop $w]

    switch -- [file extension $fileName] {
	.can {
	    ::CanvasFile::OpenCanvas $wcan $fileName
	}
	default {
	    ::CanvasCmd::DoEraseAll $wcan
	    ::undo::reset [::WB::GetUndoToken $wcan]
	    ::Import::DoImport $wcan {-coords {0 0}} -file $fileName
	}
    }
    
    # Auto resize.
    if {$prefs(slideShow,autosize)} {
	foreach {cwidth cheight} [::WB::GetCanvasSize $w] {break}
	set bbox [$wcan bbox all]
	if {[llength $bbox]} {
	    foreach {bx by bw bh} $bbox {break}
	    if {($cwidth < $bw) && ($cheight < $bh)} {
		::WB::SetCanvasSize $w $bw $bh
	    } elseif {$cwidth < $bw} {
		::WB::SetCanvasSize $w $bw $cheight
	    } elseif {$cheight < $bh} {
		::WB::SetCanvasSize $w $cwidth $bh
	    }
	}
    }
}

proc ::SlideShow::Previous {w} {    
    variable priv

    SaveCurrentCanvas $w
    set ind [lsearch -exact $priv(pages) $priv($w,current)]
    OpenPage $w [lindex $priv(pages) [expr $ind - 1]]
    SetButtonState $w
}

proc ::SlideShow::Next {w} {    
    variable priv

    SaveCurrentCanvas $w
    set ind [lsearch -exact $priv(pages) $priv($w,current)]
    OpenPage $w [lindex $priv(pages) [expr $ind + 1]]
    SetButtonState $w
}

proc ::SlideShow::First {w} {    
    variable priv

    SaveCurrentCanvas $w
    OpenPage $w [lindex $priv(pages) 0]
    SetButtonState $w
}

proc ::SlideShow::Last {w} {    
    variable priv

    SaveCurrentCanvas $w
    OpenPage $w [lindex $priv(pages) end]
    SetButtonState $w
}

proc ::SlideShow::SetButtonState {w} {
    variable priv
    
    set wtray $priv($w,wtray)
    if {[llength $priv(pages)]} {
	if {[$wtray exists next]} {
	    $wtray buttonconfigure next     -state normal
	    $wtray buttonconfigure previous -state normal
	}
    }
    if {[string equal $priv($w,current) [lindex $priv(pages) 0]]} {
	if {[$wtray exists previous]} {
	    $wtray buttonconfigure previous -state disabled
	}
    } elseif {[string equal $priv($w,current) [lindex $priv(pages) end]]} {
	if {[$wtray exists next]} {
	    $wtray buttonconfigure next -state disabled
	}
    }
}

proc ::SlideShow::SetMenuState {w} {
    global  prefs
    variable priv
    
    set wmenu [::UI::GetMenu $w "Slide Show"]
    if {[info exists priv($w,dir)] && [file isdirectory $priv($w,dir)]} {
	::UI::MenuMethod $wmenu entryconfigure First -state normal
	::UI::MenuMethod $wmenu entryconfigure Last  -state normal

	if {[llength $priv(pages)]} {
	    ::UI::MenuMethod $wmenu entryconfigure Previous -state normal
	    ::UI::MenuMethod $wmenu entryconfigure Next     -state normal
	}
	if {[string equal $priv($w,current) [lindex $priv(pages) 0]]} {
	    ::UI::MenuMethod $wmenu entryconfigure Previous -state disabled
	} elseif {[string equal $priv($w,current) [lindex $priv(pages) end]]} {
	    ::UI::MenuMethod $wmenu entryconfigure Next -state disabled
	}
    } else {
	::UI::MenuMethod $wmenu entryconfigure First -state disabled
	::UI::MenuMethod $wmenu entryconfigure Last  -state disabled
	::UI::MenuMethod $wmenu entryconfigure Previous -state disabled
	::UI::MenuMethod $wmenu entryconfigure Next     -state disabled
    }    
}

proc ::SlideShow::SaveCurrentCanvas {w} {
    variable priv

    set wcan [::WB::GetCanvasFromWtop $w]
    set fileName [file join $priv($w,dir) $priv($w,current)].can
    ::CanvasFile::SaveCanvas $wcan $fileName
}

proc ::SlideShow::MenuPostHook {type wmenu} {
    variable priv
    
    if {$type eq "whiteboard-file"} {
	if {[winfo exists [focus]]} {
	    set wtop [winfo toplevel [focus]]
	    
	    # Sander reports a bug related to this.
	    if {[winfo class $wtop] eq "TopWhiteboard"} {
		SetMenuState $wtop
	    }
	}
    }
}

proc ::SlideShow::CloseHook {w} {
    variable priv

    # Be sure to save the current page. Need to know that we have slide show?
    # SaveCurrentCanvas $w
    
    array unset priv $w,*
}

#-------------------------------------------------------------------------------
