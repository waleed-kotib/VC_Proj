# SlideShow.tcl --
# 
#       Slide show for whiteboard. This is just a first sketch.
#       
#  Copyright (c) 2004  Mats Bengtsson
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
#       $Id: SlideShow.tcl,v 1.28 2008-05-14 14:05:35 matben Exp $

package require undo

namespace eval ::SlideShow {
    
    if {![::Jabber::HaveWhiteboard]} {
	return
    }
    component::define SlideShow "Whiteboard based slide show"
}

proc ::SlideShow::Load { } {
    variable priv
    
    if {![::Jabber::HaveWhiteboard]} {
	return
    }

    ::Debug 2 "::SlideShow::Load"

    # TRANSLATORS; whiteboard slide show menu
    set menuspec \
      {cascade     mSlideShow       {[mc "Slide Show"]} {}                           {} {} {
	{command   mOpenFolder...   {[mc "&Open Folder"]...} {::SlideShow::PickFolder $w} {} {}}
	{separator}
	{command   {Previous}       {[mc "Previous"]} {::SlideShow::Previous $w}   {} {}}
	{command   {Next}           {[mc "Next"]} {::SlideShow::Next $w}       {} {}}
	{command   {First}          {[mc "First"]} {::SlideShow::First $w}      {} {}}
	{command   {Last}           {[mc "Last"]} {::SlideShow::Last $w}       {} {}}
      }
    }

    # Define all hooks needed here.
    ::hooks::register prefsInitHook                  ::SlideShow::InitPrefsHook
    ::hooks::register prefsBuildHook                 ::SlideShow::BuildPrefsHook
    ::hooks::register prefsSaveHook                  ::SlideShow::SavePrefsHook
    ::hooks::register prefsCancelHook                ::SlideShow::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook          ::SlideShow::UserDefaultsHook
    ::hooks::register prefsDestroyHook               ::SlideShow::DestroyPrefsHook
    #::hooks::register initHook                       ::SlideShow::InitHook
    ::hooks::register afterFinalHook                 ::SlideShow::InitHook
    ::hooks::register whiteboardBuildButtonTrayHook  ::SlideShow::BuildButtonsHook
    ::hooks::register whiteboardCloseHook            ::SlideShow::CloseHook
    ::hooks::register menuPostCommand                ::SlideShow::MenuPostHook
    
    ::WB::RegisterMenuEntry file $menuspec
    
    component::register SlideShow
    
    # TODO: rewrite to use ::Theme::Find32Icon function
    set gopreviousview    [::Theme::FindIcon icons/32x32/go-previous-view]
    set gonextview        [::Theme::FindIcon icons/32x32/go-next-view]
    set gopreviousviewDis [::Theme::FindIcon icons/32x32/go-previous-view-Dis]
    set gonextviewDis     [::Theme::FindIcon icons/32x32/go-next-view-Dis]

    set priv(btdefs) [list \
      [list previous $gopreviousview     $gopreviousviewDis  {::SlideShow::Previous $w}] \
      [list next     $gonextview         $gonextviewDis      {::SlideShow::Next $w}] ]
}

proc ::SlideShow::InitHook { } {
    global  prefs
    variable priv
        
    set mimes {image/gif image/png image/jpeg}
    set priv(mimes) {}
    foreach mime $mimes {
	if {[::Media::HaveImporterForMime $mime]} {
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
	::Preferences::NewTableItem {Whiteboard} [mc "Whiteboard"]
    }
    ::Preferences::NewTableItem {Whiteboard {SlideShow}} [mc "Slide Show"]
    set wpage [$nbframe page {SlideShow}]    
    
    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set lfr $wc.fr
    ttk::frame $lfr
    pack $lfr -side top -anchor w

    set tmpPrefs(slideShow,buttons)  $prefs(slideShow,buttons)
    set tmpPrefs(slideShow,autosize) $prefs(slideShow,autosize)

    ttk::checkbutton $lfr.ss -text [mc "Show navigation buttons"] \
      -variable [namespace current]::tmpPrefs(slideShow,buttons)
    ttk::checkbutton $lfr.size -text [mc "Resize window to fit slides"]  \
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
	tk_chooseDirectory -mustexist 1 -title [mc "Open Folder"]} $opts]
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
	set flist [glob -nocomplain -directory $dir -types f -tails -- *$suff]
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
    OpenPage $w [lindex $priv(pages) [expr {$ind - 1}]]
    SetButtonState $w
}

proc ::SlideShow::Next {w} {    
    variable priv

    SaveCurrentCanvas $w
    set ind [lsearch -exact $priv(pages) $priv($w,current)]
    OpenPage $w [lindex $priv(pages) [expr {$ind + 1}]]
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
    
    set wmenu [::UI::GetMenu $w mSlideShow]
    if {[info exists priv($w,dir)] && [file isdirectory $priv($w,dir)]} {
	::UI::MenuMethod $wmenu entryconfigure First -state normal -label [mc "First"]
	::UI::MenuMethod $wmenu entryconfigure Last  -state normal -label [mc "Last"]

	if {[llength $priv(pages)]} {
	    ::UI::MenuMethod $wmenu entryconfigure Previous -state normal -label [mc "Previous"]
	    ::UI::MenuMethod $wmenu entryconfigure Next     -state normal -label [mc "Next"]
	}
	if {[string equal $priv($w,current) [lindex $priv(pages) 0]]} {
	    ::UI::MenuMethod $wmenu entryconfigure Previous -state disabled -label [mc "Previous"]
	} elseif {[string equal $priv($w,current) [lindex $priv(pages) end]]} {
	    ::UI::MenuMethod $wmenu entryconfigure Next -state disabled -label [mc "Next"]
	}
    } else {
	::UI::MenuMethod $wmenu entryconfigure First -state disabled -label [mc "First"]
	::UI::MenuMethod $wmenu entryconfigure Last  -state disabled -label [mc "Last"]
	::UI::MenuMethod $wmenu entryconfigure Previous -state disabled -label [mc "Previous"]
	::UI::MenuMethod $wmenu entryconfigure Next     -state disabled -label [mc "Next"]
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
