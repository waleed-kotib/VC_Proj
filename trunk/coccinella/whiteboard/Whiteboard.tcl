#  Whiteboard.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the actual whiteboard.
#      
#  Copyright (c) 2002-2004  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Whiteboard.tcl,v 1.25 2004-10-26 12:46:52 matben Exp $

package require entrycomp
package require moviecontroller
package require uriencode
package require CanvasDraw
package require CanvasText
package require CanvasUtils
package require CanvasCutCopyPaste
package require CanvasCmd
package require CanvasFile
package require FilePrefs
package require GetFileIface
package require Import
package require ItemInspector
package require Plugins
package require PutFileIface
package require WBPrefs


package provide Whiteboard 1.0

namespace eval ::WB:: {
    global  wDlgs
        
    # Add all event hooks.
    ::hooks::register quitAppHook         \
      [list ::UI::SaveWinPrefixGeom $wDlgs(wb) whiteboard]
    ::hooks::register quitAppHook         ::WB::SaveAnyState
    ::hooks::register closeWindowHook     ::WB::CloseHook
    ::hooks::register whiteboardCloseHook ::WB::CloseWhiteboard
    ::hooks::register loginHook           ::WB::LoginHook
    ::hooks::register logoutHook          ::WB::LogoutHook
    ::hooks::register earlyInitHook       ::WB::EarlyInitHook
    ::hooks::register prefsInitHook       ::WB::InitPrefsHook

    # Tool button mappings.
    variable btNo2Name 
    variable btName2No
    array set btNo2Name	{
	00 point 01 move 10 line  11 arrow 
	20 rect  21 oval 30 pen   31 brush
	40 text  41 del  50 paint 51 poly 
	60 arc   61 rot
    }
    array set btName2No {
	point 00 move 01 line  10 arrow 11 
	rect  20 oval 21 pen   30 brush 31
	text  40 del  41 paint 50 poly  51 
	arc   60 rot  61
    }

    # Use option database for customization.
    # Shortcut buttons.
    option add *Whiteboard*connectImage         connect         widgetDefault
    option add *Whiteboard*connectDisImage      connectDis      widgetDefault
    option add *Whiteboard.saveImage            save            widgetDefault
    option add *Whiteboard.saveDisImage         saveDis         widgetDefault
    option add *Whiteboard.openImage            open            widgetDefault
    option add *Whiteboard.openDisImage         openDis         widgetDefault
    option add *Whiteboard.importImage          import          widgetDefault
    option add *Whiteboard.importDisImage       importDis       widgetDefault
    option add *Whiteboard.sendImage            send            widgetDefault
    option add *Whiteboard.sendDisImage         sendDis         widgetDefault
    option add *Whiteboard.printImage           print           widgetDefault
    option add *Whiteboard.printDisImage        printDis        widgetDefault
    option add *Whiteboard.stopImage            stop            widgetDefault
    option add *Whiteboard.stopDisImage         stopDis         widgetDefault

    # Other icons.
    option add *Whiteboard.contactOffImage      contactOff      widgetDefault
    option add *Whiteboard.contactOnImage       contactOn       widgetDefault
    option add *Whiteboard.waveImage            wave            widgetDefault
    option add *Whiteboard.resizeHandleImage    resizehandle    widgetDefault

    option add *Whiteboard.barhorizImage        barhoriz        widgetDefault
    option add *Whiteboard.barvertImage         barvert         widgetDefault

    # Drawing tool buttons.
    for {set icol 0} {$icol <= 1} {incr icol} {
	for {set irow 0} {$irow <= 6} {incr irow} {
	    set idx ${irow}${icol}
	    option add *Whiteboard.toolOff$btNo2Name($idx)Image off${idx}  widgetDefault
	    option add *Whiteboard.toolOn$btNo2Name($idx)Image  on${idx} widgetDefault
	}
    }

    # Color selector.
    option add *Whiteboard.bwrectImage          bwrect          widgetDefault
    option add *Whiteboard.imcolorImage         imcolor         widgetDefault
    
    # Keeps various geometry info.
    variable dims
    
    # BAD!!!!!!!!!!!!!!!!!!!!!!???????????????
    # Canvas size; these are also min sizes. Add new line of tools.
    set dims(wCanOri) 350
    set dims(hCanOri) [expr 328 + 28]
    # Canvas size; with border.
    set dims(wMinCanvas) [expr $dims(wCanOri) + 2]
    set dims(hMinCanvas) [expr $dims(hCanOri) + 2]
    set dims(x) 30
    set dims(y) 30
    # Total size of the application (not including menu); only temporary values.
    set dims(wRoot) 1    
    set dims(hRoot) 1
    # As above but including the menu.
    set dims(wTot) 1    
    set dims(hTot) 1   
    
    # Total screen dimension.
    set dims(screenH) [winfo vrootheight .]
    set dims(screenW) [winfo vrootwidth .]

    # Unique id for main toplevels
    variable uidmain 0
        
    # Plugin stuff.
    variable menuSpecPublic
    set menuSpecPublic(wpaths) {}
    
    variable iconsInitted 0
    
    # Prefs:
    # Side of selecting box .
    set prefs(aBBox) 2

    # Should text inserts be batched?
    set prefs(batchText) 1

    # Delay time in ms for batched text.
    set prefs(batchTextms) 2000

    # Want to fit all movies within canvas?
    set prefs(autoFitMovies) 1

    set prefs(canScrollWidth)  1800
    set prefs(canScrollHeight) 1200

    # Html sizes or point sizes when transferring text items?
    set prefs(useHtmlSizes) 1

    # Offset when duplicating canvas items and when opening images and movies.
    # Needed in ::CanvasUtils::NewImportAnchor
    set prefs(offsetCopy) 16

    # Grid spacing.
    set prefs(gridDist) 40                 
    
    # Mark bounding box (1) or each coords (0).
    set prefs(bboxOrCoords) 0
    
    # Scale factor used when scaling canvas items.
    set prefs(scaleFactor) 1.2
    set prefs(invScaleFac) [expr 1.0/$prefs(scaleFactor)]

    # Use common CG when scaling more than one item?
    set prefs(scaleCommonCG) 0

    # Fraction of points to strip when straighten.
    set prefs(straightenFrac) 0.3
    
    # Are there a working canvas dash option?
    set prefs(haveDash) 0
    if {![string match "mac*" $this(platform)]} {
	set prefs(haveDash) 1
    }
}

# WB::InitPrefsHook --
# 
#       There is a global 'state' array which contains a generic state
#       that is inherited by instance specific 'state' array '::WB::${wtop}::state'

proc ::WB::InitPrefsHook { } {
    global  state prefs this
    
    ::Debug 2 "::WB::InitPrefsHook"
    
    # The tool buttons.
    set state(btState) 00
    set state(btStateOld) 00

    # Is the toolbar visible?
    set state(visToolbar) 1
    
    # Bg color for canvas.
    set state(bgColCan) #dedede
    
    # fg and bg colors set in color selector; bgCol always white.
    set state(fgCol) black
    set state(bgCol) white
    
    # Grid on or off.
    set state(canGridOn) 0                  
    
    # Line thickness.
    set state(penThick) 1	
    
    # Brush thickness.
    set state(brushThick) 8	
    
    # Fill color for circles, polygons etc.
    set state(fill) 0
    
    # If polygons should be smoothed.
    set state(smooth) 0
    
    # Arc styles.
    set state(arcstyle) "arc"
    
    # Dash style.
    set state(dash) { }
    
    # Font prefs set in menus. Sizes according to html.
    set state(fontSize) 2
    set state(font) Helvetica
    set state(fontWeight) normal
            
    # Constrain movements to 45 degrees, else 90 degree intervals.
    set prefs(45) 1

    #----   url's for streaming live movies ----------------------------------------
    set prefs(shortsMulticastQT) {{   \
      {user specified}   \
      {Bloomberg}          \
      {Hard Radio}       \
      {NPR}  \
      {BBC World TV} } {  \
      {}  \
      www.apple.com/quicktime/showcase/radio/bloomberg/bloombergradio.mov  \
      www.apple.com/quicktime/showcase/radio/hardradio/hardradio.mov  \
      www.apple.com/quicktime/showcase/radio/npr/npr.mov  \
      www.apple.com/quicktime/favorites/bbc_world1/bbc_world1.mov}}

    # States and prefs to be stored in prefs file.
    ::PreferencesUtils::Add [list  \
      [list prefs(45)              prefs_45              $prefs(45)]             \
      [list prefs(shortsMulticastQT) prefs_shortsMulticastQT $prefs(shortsMulticastQT) userDefault] \
      [list state(btState)         state_btState         $state(btState)]        \
      [list state(bgColCan)        state_bgColCan        $state(bgColCan)]       \
      [list state(fgCol)           state_fgCol           $state(fgCol)]          \
      [list state(penThick)        state_penThick        $state(penThick)]       \
      [list state(brushThick)      state_brushThick      $state(brushThick)]     \
      [list state(fill)            state_fill            $state(fill)]           \
      [list state(arcstyle)        state_arcstyle        $state(arcstyle)]       \
      [list state(fontSize)        state_fontSize        $state(fontSize)]       \
      [list state(font)            state_font            $state(font)]           \
      [list state(fontWeight)      state_fontWeight      $state(fontWeight)]     \
      [list state(smooth)          state_smooth          $state(smooth)]         \
      [list state(dash)            state_dash            $state(dash)]           \
      [list state(canGridOn)       state_canGridOn       $state(canGridOn)]      \
      [list state(visToolbar)      state_visToolbar      $state(visToolbar)]  ]    
}

proc ::WB::EarlyInitHook { } {

    ::WB::Init
    ::WB::InitMenuDefs   
}

# WB::Init --
# 
#       Various initializations for the UI stuff.

proc ::WB::Init {} {
    global  this prefs
    variable wbicons
    
    ::Debug 2 "::WB::Init"
        
    # Dashed options. Used both for the Preference menu and ItemInspector.
    # Need to be careful not to use empty string for menu value in -variable
    # because this gives the 'value' value.
    variable dashFull2Short
    variable dashShort2Full

    array set dashFull2Short {
	none " " dotted . dash-dotted -. dashed -
    }
    array set dashShort2Full {
	" " none . dotted -. dash-dotted - dashed
    }
    set dashShort2Full() none    

    # Init canvas utils.
    ::CanvasUtils::Init
    
    # Create the mapping between Html sizes and font point sizes dynamically.
    ::CanvasUtils::CreateFontSizeMapping
        
    # Drag and Drop support...
    set prefs(haveTkDnD) 0
    if {![catch {package require tkdnd}]} {
	set prefs(haveTkDnD) 1
    }    

    variable animateWave
    
    # Defines canvas binding tags suitable for each tool.
    ::CanvasUtils::DefineWhiteboardBindtags
}

# WB::InitIcons --
# 
#       Get all standard icons using the option database with the
#       preloaded icons as fallback.

proc ::WB::InitIcons {w} {
    global  this
    
    variable icons
    variable iconsInitted 1
    variable btNo2Name 
    variable wbicons
    	
    # Get icons.
    set icons(brokenImage) [image create photo -format gif  \
      -file [file join $this(imagePath) brokenImage.gif]]	

    # Make all standard icons.
    package require WBIcons
    
    set wbicons(barhoriz) [::WB::GetThemeImage [option get $w barhorizImage {}]]
    set wbicons(barvert)  [::WB::GetThemeImage [option get $w barvertImage {}]]

    # Drawing tool buttons.
    for {set icol 0} {$icol <= 1} {incr icol} {
	for {set irow 0} {$irow <= 6} {incr irow} {
	    set idx ${irow}${icol}
	    set wbicons(off${idx}) [::WB::GetThemeImage  \
	      [option get $w toolOff$btNo2Name($idx)Image {}]]
	    set wbicons(on${idx})  [::WB::GetThemeImage  \
	      [option get $w toolOn$btNo2Name($idx)Image {}]]
	}
    }
    
    # Color selector.
    set wbicons(imcolor) [::WB::GetThemeImage [option get $w imcolorImage {}]]
    set wbicons(bwrect)  [::WB::GetThemeImage [option get $w bwrectImage {}]]
}

# WB::InitMenuDefs --
# 
#       The menu organization.

proc ::WB::InitMenuDefs { } {
    global  prefs this
    variable menuDefs
    
    ::Debug 2 "::WB::InitMenuDefs"

    if {[string match "mac*" $this(platform)] && $prefs(haveMenus)} {
	set haveAppleMenu 1
    } else {
	set haveAppleMenu 0
    }
    
    # All menu definitions for the main (whiteboard) windows as:
    #      {{type name cmd state accelerator opts} {{...} {...} ...}}
    
    # May be customized by jabber, p2p...

    set menuDefs(main,info,aboutwhiteboard)  \
      {command   mAboutCoccinella    {::SplashScreen::SplashScreen} normal   {}}
    set menuDefs(main,info,aboutquicktimetcl)  \
      {command   mAboutQuickTimeTcl  {::Dialogs::AboutQuickTimeTcl}                normal   {}}

    # Only basic functionality.
    set menuDefs(main,file) {
	{command   mCloseWindow     {::UI::DoCloseWindow}                   normal   W}
	{separator}
	{command   mOpenImage/Movie {::Import::ImportImageOrMovieDlg $wtop} normal  I}
	{command   mOpenURLStream   {::Multicast::OpenMulticast $wtop}  normal   {}}
	{separator}
	{command   mOpenCanvas      {::CanvasFile::OpenCanvasFileDlg $wtop}  normal   {}}
	{command   mSaveCanvas      {::CanvasFile::SaveCanvasFileDlg $wtop}  normal   S}
	{separator}
	{command   mSaveAs          {::CanvasCmd::SavePostscript $wtop}     normal   {}}
	{command   mSaveAsItem      {::CanvasCmd::DoSaveAsItem $wtop}       normal   {}}
	{command   mPageSetup       {::UserActions::PageSetup $wtop}        normal   {}}
	{command   mPrintCanvas     {::UserActions::DoPrintCanvas $wtop}    normal   P}
	{separator}
	{command   mQuit            {::UserActions::DoQuit}                 normal   Q}
    }
    if {![::Plugins::HavePackage QuickTimeTcl]} {
	lset menuDefs(main,file) 3 3 disabled
    }
	    
    # If embedded the embedding app should close us down.
    if {$prefs(embedded)} {
	lset menuDefs(main,file) end 3 disabled
    } else {
	package require Multicast
    }

    set menuDefs(main,edit) {    
	{command     mUndo             {::CanvasCmd::Undo $wtop}             normal   Z}
	{command     mRedo             {::CanvasCmd::Redo $wtop}             normal   {}}
	{separator}
	{command     mCut              {::UI::CutCopyPasteCmd cut}           disabled X}
	{command     mCopy             {::UI::CutCopyPasteCmd copy}          disabled C}
	{command     mPaste            {::UI::CutCopyPasteCmd paste}         disabled V}
	{command     mAll              {::CanvasCmd::SelectAll $wtop}        normal   A}
	{command     mEraseAll         {::CanvasCmd::DoEraseAll $wtop}       normal   {}}
	{separator}
	{command     mInspectItem      {::ItemInspector::ItemInspector $wtop selected} disabled {}}
	{separator}
	{command     mRaise            {::CanvasCmd::RaiseOrLowerItems $wtop raise} disabled R}
	{command     mLower            {::CanvasCmd::RaiseOrLowerItems $wtop lower} disabled L}
	{separator}
	{command     mLarger           {::CanvasCmd::ResizeItem $wtop $prefs(scaleFactor)} disabled >}
	{command     mSmaller          {::CanvasCmd::ResizeItem $wtop $prefs(invScaleFac)} disabled <}
	{cascade     mFlip             {}                                      disabled {} {} {
	    {command   mHorizontal     {::CanvasCmd::FlipItem $wtop horizontal}  normal   {} {}}
	    {command   mVertical       {::CanvasCmd::FlipItem $wtop vertical}    normal   {} {}}}
	}
	{command     mImageLarger      {::Import::ResizeImage $wtop 2 sel auto} disabled {}}
	{command     mImageSmaller     {::Import::ResizeImage $wtop -2 sel auto} disabled {}}
    }
    
    # These are used not only in the drop-down menus.
    set menuDefs(main,prefs,separator) 	{separator}
    set menuDefs(main,prefs,background)  \
      {command     mBackgroundColor      {::CanvasCmd::SetCanvasBgColor $wtop} normal   {}}
    set menuDefs(main,prefs,grid)  \
      {checkbutton mGrid             {::CanvasCmd::DoCanvasGrid $wtop}   normal   {} \
      {-variable ::WB::${wtop}::state(canGridOn)}}
    set menuDefs(main,prefs,thickness)  \
      {cascade     mThickness        {}                                    normal   {} {} {
	{radio   1                 {}                                      normal   {} \
	  {-variable ::WB::${wtop}::state(penThick)}}
	{radio   2                 {}                                      normal   {} \
	  {-variable ::WB::${wtop}::state(penThick)}}
	{radio   4                 {}                                      normal   {} \
	  {-variable ::WB::${wtop}::state(penThick)}}
	{radio   6                 {}                                      normal   {} \
	  {-variable ::WB::${wtop}::state(penThick)}}}
    }
    set menuDefs(main,prefs,brushthickness)  \
      {cascade     mBrushThickness   {}                                    normal   {} {} {
	{radio   8                 {}                                      normal   {} \
	  {-variable ::WB::${wtop}::state(brushThick)}}
	{radio   10                {}                                      normal   {} \
	  {-variable ::WB::${wtop}::state(brushThick)}}
	{radio   12                {}                                      normal   {} \
	  {-variable ::WB::${wtop}::state(brushThick)}}
	{radio   16                {}                                      normal   {} \
	  {-variable ::WB::${wtop}::state(brushThick)}}}
    }
    set menuDefs(main,prefs,fill)  \
      {checkbutton mFill             {}                                    normal   {} \
      {-variable ::WB::${wtop}::state(fill)}}
    set menuDefs(main,prefs,smoothness)  \
      {cascade     mLineSmoothness   {}                                    normal   {} {} {
	{radio   None              {set ::WB::${wtop}::state(smooth) 0}        normal   {} \
	  {-value 0 -variable ::WB::${wtop}::state(splinesteps)}}
	{radio   2                 {set ::WB::${wtop}::state(smooth) 1}        normal   {} \
	  {-value 2 -variable ::WB::${wtop}::state(splinesteps)}}
	{radio   4                 {set ::WB::${wtop}::state(smooth) 1}        normal   {} \
	  {-value 4 -variable ::WB::${wtop}::state(splinesteps)}}
	{radio   6                 {set ::WB::${wtop}::state(smooth) 1}        normal   {} \
	  {-value 6 -variable ::WB::${wtop}::state(splinesteps)}}
	{radio   10                {set ::WB::${wtop}::state(smooth) 1}        normal   {} \
	  {-value 10 -variable ::WB::${wtop}::state(splinesteps)}}}
    }
    set menuDefs(main,prefs,smooth)  \
      {checkbutton mLineSmoothness   {}                                    normal   {} \
      {-variable ::WB::${wtop}::state(smooth)}}
    set menuDefs(main,prefs,arcs)  \
      {cascade     mArcs             {}                                    normal   {} {} {
	{radio   mPieslice         {}                                      normal   {} \
	  {-value pieslice -variable ::WB::${wtop}::state(arcstyle)}}
	{radio   mChord            {}                                      normal   {} \
	  {-value chord -variable ::WB::${wtop}::state(arcstyle)}}
	{radio   mArc              {}                                      normal   {} \
	  {-value arc -variable ::WB::${wtop}::state(arcstyle)}}}
    }
    
    # Dashes need a special build process. Be sure not to substitute $wtop.
    set dashList {}
    foreach dash [lsort -decreasing [array names ::WB::dashFull2Short]] {
	set dashval $::WB::dashFull2Short($dash)
	if {[string equal " " $dashval]} {
	    set dopts {-value { } -variable ::WB::${wtop}::state(dash)}
	} else {
	    set dopts [format {-value %s -variable ::WB::${wtop}::state(dash)} $dashval]
	}
	lappend dashList [list radio $dash {} normal {} $dopts]
    }
    set menuDefs(main,prefs,dash)  \
      [list cascade   mDash          {}                                    normal   {} {} $dashList]
	
    set menuDefs(main,prefs,constrain)  \
      {cascade     mShiftConstrain   {}                                    normal   {} {} {
	{radio   mTo90degrees      {}                                      normal   {} \
	  {-variable prefs(45) -value 0}}
	{radio   mTo45degrees      {}                                      normal   {} \
	  {-variable prefs(45) -value 1}}}
    }
    set menuDefs(main,prefs,font)  \
      {cascade     mFont             {}                                    normal   {} {} {}}
    set menuDefs(main,prefs,fontsize)  \
      {cascade     mSize             {}                                    normal   {} {} {
	{radio   1                 {::WB::FontChanged $wtop size}          normal   {} \
	  {-variable ::WB::${wtop}::state(fontSize)}}
	{radio   2                 {::WB::FontChanged $wtop size}          normal   {} \
	  {-variable ::WB::${wtop}::state(fontSize)}}
	{radio   3                 {::WB::FontChanged $wtop size}          normal   {} \
	  {-variable ::WB::${wtop}::state(fontSize)}}
	{radio   4                 {::WB::FontChanged $wtop size}          normal   {} \
	  {-variable ::WB::${wtop}::state(fontSize)}}
	{radio   5                 {::WB::FontChanged $wtop size}          normal   {} \
	  {-variable ::WB::${wtop}::state(fontSize)}}
	{radio   6                 {::WB::FontChanged $wtop size}          normal   {} \
	  {-variable ::WB::${wtop}::state(fontSize)}}}
    }
    set menuDefs(main,prefs,fontweight)  \
      {cascade     mWeight           {}                                    normal   {} {} {
	{radio   mNormal           {::WB::FontChanged $wtop weight}        normal   {} \
	  {-value normal -variable ::WB::${wtop}::state(fontWeight)}}
	{radio   mBold             {::WB::FontChanged $wtop weight}        normal   {} \
	  {-value bold -variable ::WB::${wtop}::state(fontWeight)}}
	{radio   mItalic           {::WB::FontChanged $wtop weight}        normal   {} \
	  {-value italic -variable ::WB::${wtop}::state(fontWeight)}}}
    }
    set menuDefs(main,prefs,prefs)  \
      {command     mPreferences...   {::Preferences::Build}                normal   {}}
    
    # Build hierarchical list.
    set menuDefs(main,prefs) {}
    foreach key {background grid thickness brushthickness fill smooth  \
      arcs dash constrain separator font fontsize fontweight separator prefs} {
	lappend menuDefs(main,prefs) $menuDefs(main,prefs,$key)
    }

    set menuDefs(main,info) {    
	{command     mOnServer       {::Dialogs::ShowInfoServer}        normal {}}	
	{command     mOnClients      {::Dialogs::ShowInfoClients}       disabled {}}	
	{command     mOnPlugins      {::Dialogs::InfoOnPlugins}         normal {}}	
	{separator}
	{cascade     mHelpOn             {}                             normal   {} {} {}}
    }
    
    # Build "Help On" menu dynamically.
    set infoDefs {}
    set systemLocale [lindex [split $this(systemLocale) _] 0]
    foreach fen [glob -nocomplain -directory $this(docsPath) *_en.can] {
	set name [lindex [split [file tail $fen] _] 0]
	set floc [file join $this(docsPath) ${name}_${systemLocale}.can]
	if {[file exists $floc]} {
	    set f $floc
	} else {
	    set f $fen
	}
	lappend infoDefs [list \
	  command m${name} [list ::Dialogs::Canvas $f -title $name] normal {}]
    }
    lset menuDefs(main,info) end end $infoDefs
    
    # Make platform specific things and special menus etc. Indices!!! BAD!
    if {!$prefs(haveDash)} {
	lset menuDefs(main,prefs) 7 3 disabled
    }
    if {!$haveAppleMenu} {
	lappend menuDefs(main,info) $menuDefs(main,info,aboutwhiteboard)
    }
    if {!$haveAppleMenu && ![catch {package require QuickTimeTcl 3.1}]} {
	lappend menuDefs(main,info) $menuDefs(main,info,aboutquicktimetcl)
    }
	
    # Menu definitions for a minimal setup. Used on mac only.
    set menuDefs(min,file) {
	{command   mNewWhiteboard    {::WB::NewWhiteboard}                       normal   N}
	{command   mCloseWindow      {::UI::DoCloseWindow}                 normal   W}
	{separator}
	{command   mQuit             {::UserActions::DoQuit}               normal   Q}
    }	    
    set menuDefs(min,edit) {    
	{command   mCut              {::UI::CutCopyPasteCmd cut}           disabled X}
	{command   mCopy             {::UI::CutCopyPasteCmd copy}          disabled C}
	{command   mPaste            {::UI::CutCopyPasteCmd paste}         disabled V}
    }
    
    set menuDefs(main,items) [::WB::MakeItemMenuDef $this(itemPath)]
    set altItemsMenuDefs     [::WB::MakeItemMenuDef $this(altItemPath)]
    if {[llength $altItemsMenuDefs]} {
	lappend menuDefs(main,items) {separator}
	set menuDefs(main,items) [concat $menuDefs(main,items) $altItemsMenuDefs]
    }
    
    # When registering new menu entries they shall be added at:
    variable menuDefsInsertInd
    set menuDefsInsertInd(main,file)   [expr [llength $menuDefs(main,file)]-2]
    set menuDefsInsertInd(main,edit)   [expr [llength $menuDefs(main,edit)]]
    set menuDefsInsertInd(main,prefs)  [expr [llength $menuDefs(main,prefs)]]
    set menuDefsInsertInd(main,items)  [expr [llength $menuDefs(main,items)]]
    set menuDefsInsertInd(main,info)   [expr [llength $menuDefs(main,info)]-2]
}

# WB::NewWhiteboard --
#
#       Makes a unique whiteboard.
#
# Arguments:
#       args    -file fileName
#               -state normal|disabled 
#               -title name
#               -usewingeom 0|1
#               ?-key value ...? custom arguments
#       
# Results:
#       toplevel window. (.) If not "." then ".top."; extra dot!

proc ::WB::NewWhiteboard {args} { 
    global wDlgs
    variable uidmain
    
    # Need to reuse ".". Outdated!
    if {[wm state .] == "normal"} {
	set wtop [::WB::GetNewToplevelPath]
    } else {
	set wtop .
    }
    eval {::WB::BuildWhiteboard $wtop} $args
    return $wtop
}

proc ::WB::GetNewToplevelPath { } {
    global wDlgs
    variable uidmain
    
    return $wDlgs(wb)[incr uidmain].
}

# WB::BuildWhiteboard --
#
#       Makes the main toplevel window.
#
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       args        see above
#       
# Results:
#       new instance toplevel created.

proc ::WB::BuildWhiteboard {wtop args} {
    global  this prefs
    
    variable dims
    variable wbicons
    variable iconsInitted
    
    Debug 2 "::WB::BuildWhiteboard wtop=$wtop, args='$args'"
    
    if {![string equal [string index $wtop end] "."]} {
	set wtop ${wtop}.
    }    
    namespace eval ::WB::${wtop}:: { }
    
    upvar ::WB::${wtop}::wapp wapp
    upvar ::WB::${wtop}::state state
    upvar ::WB::${wtop}::opts opts
    upvar ::WB::${wtop}::canvasImages canvasImages
    
    eval {::hooks::run whiteboardPreBuildHook $wtop} $args
    
    if {[string equal $wtop "."]} {
	set wbTitle "$prefs(theAppName) (Main)"
    } else {
	set wbTitle $prefs(theAppName)
    }
    set titleString $wbTitle
    array set opts [list -state normal -title $titleString -usewingeom 0]
    array set opts $args
    
    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    
    # Common widget paths.
    set wapp(toplevel)  $w
    if {$w == "."} {
	set wall            .f
	set wapp(menu)      .menu
    } else {
	set wall            ${w}.f
	set wapp(menu)      ${w}.menu
    }
    set wapp(frall)     $wall
    set wapp(frtop)     ${wall}.frtop
    set wapp(tray)      $wapp(frtop).on.fr
    set wapp(tool)      ${wall}.fmain.frleft.frbt
    set wapp(buglabel)  ${wall}.fmain.frleft.pad.bug
    set wapp(frcan)     ${wall}.fmain.fc
    set wapp(comm)      ${wall}.fcomm
    set wcomm           $wapp(comm)
    set wapp(statmess)  ${wcomm}.stat.lbl
    set wapp(frstat)    ${wcomm}.st
    set wapp(topchilds) [list ${wall}.menu ${wall}.frtop ${wall}.fmain ${wall}.fcomm]
    
    # temporary...
    set wapp(can)       ${wall}.fmain.fc.can
    set wapp(xsc)       ${wall}.fmain.fc.xsc
    set wapp(ysc)       ${wall}.fmain.fc.ysc
    set wapp(can,)      $wapp(can)
    
    # Having the frame with canvas + scrollbars as a sibling makes it possible
    # to pack it in a different place.
    set wapp(ccon)      ${wall}.fmain.cc
    
    # Notebook widget path to be packed into wapp(ccon).
    set wapp(nb)        ${wall}.fmain.nb
    
    set canvasImages {}
    
    # Init some of the state variables.
    # Inherit from the factory + preferences state.
    array set state [array get ::state]
    if {$opts(-state) == "disabled"} {
	set state(btState) 00
    }
    
    if {![winfo exists $w] && ($wtop != ".")} {
	::UI::Toplevel $w -class Whiteboard
	wm withdraw $w
    }
    wm title $w $opts(-title)
    
    # Have an overall frame here of class Whiteboard. Needed for option db.
    frame $wall -class Whiteboard
    pack  $wall -fill both -expand 1
    
    set fontS [option get . fontSmall {}]
    set fg    black
    set iconResize [::Theme::GetImage [option get $wall resizeHandleImage {}]]
    set wbicons(resizehandle) $iconResize
    if {!$iconsInitted} {
	::WB::InitIcons $wall
    }
    
    # Note that the order of calls can be critical as any 'update' may trigger
    # network events to attempt drawing etc. Beware!!!
     
    # Start with menus.
    ::WB::BuildWhiteboardMenus $wtop
	
    # Shortcut buttons at top? Do we want the toolbar to be visible.
    if {$state(visToolbar)} {
	::WB::ConfigShortcutButtonPad $wtop init
    } else {
	::WB::ConfigShortcutButtonPad $wtop init off
    }

    # Make the connection frame.
    frame $wcomm
    pack  $wcomm -side bottom -fill x
    
    # Status message part.
    frame  $wapp(frstat) -relief raised -borderwidth 1
    frame  ${wcomm}.stat -relief groove -bd 2
    canvas $wapp(statmess) -bd 0 -highlightthickness 0 -height 14
    pack   $wapp(frstat) -side top -fill x -pady 0
    pack   ${wcomm}.stat -side top -fill x -padx 10 -pady 2 -in $wapp(frstat)
    pack   $wapp(statmess) -side left -pady 1 -padx 6 -fill x -expand true
    $wapp(statmess) create text 0 [expr 14/2] -anchor w -text {} -font $fontS \
      -tags stattxt -fill $fg
    
    # Build the header for the actual network setup. This is where we
    # may have mode specific parts, p2p, jabber...
    ::hooks::run whiteboardBuildEntryHook $wtop $wall $wcomm
    
    # Make frame for toolbar + canvas.
    frame ${wall}.fmain -borderwidth 0 -relief flat
    frame ${wall}.fmain.frleft
    frame $wapp(tool)
    frame ${wall}.fmain.frleft.pad -relief raised -borderwidth 1
    frame $wapp(ccon) -bd 1 -relief raised
    pack  ${wall}.fmain -side top -fill both -expand true
    pack  ${wall}.fmain.frleft -side left -fill y
    pack  $wapp(tool) -side top
    pack  ${wall}.fmain.frleft.pad -fill both -expand true
    pack  $wapp(ccon) -fill both -expand true -side right
    
    # The 'Coccinella'.
    set   wapp(bugImage) [::Theme::GetImage ladybug]
    label $wapp(buglabel) -borderwidth 0 -image $wapp(bugImage)
    pack  $wapp(buglabel) -side bottom
    
    # Make the tool buttons and invoke the one from the prefs file.
    ::WB::CreateAllButtons $wtop
    
    # ...and the drawing canvas.
    ::WB::NewCanvas $wapp(frcan) -background $state(bgColCan)
    set wapp(servCan) $wapp(can)
    pack $wapp(frcan) -in $wapp(ccon) -fill both -expand true -side right
    
    # Invoke tool button.
    ::WB::SetToolButton $wtop [::WB::ToolBtNumToName $state(btState)]

    # Add things that are defined in the prefs file and not updated else.
    ::CanvasCmd::DoCanvasGrid $wtop
    
    # Create the undo/redo object.
    set state(undotoken) [undo::new -command [list ::UI::UndoConfig $wtop]]

    # Set up paste menu if something on the clipboard.
    ::WB::GetFocus $wtop $w
    bind $w         <FocusIn>  [list [namespace current]::GetFocus $wtop %W]
    bind $wapp(can) <Button-1> [list focus $wapp(can)]
    
    # Cut, copy, paste commands for the canvas.
    bind $wapp(can) <<Cut>>   [list ::CanvasCCP::CutCopyPasteCmd cut]
    bind $wapp(can) <<Copy>>  [list ::CanvasCCP::CutCopyPasteCmd copy]
    bind $wapp(can) <<Paste>> [list ::CanvasCCP::CutCopyPasteCmd paste]
    
    if {$opts(-usewingeom)} {
	::UI::SetWindowGeometry $w
    } else {
	
	# Set window position only for the first whiteboard on screen.
	# Subsequent whiteboards are placed by the window manager.
	if {[llength [::WB::GetAllWhiteboards]] == 1} {	
	    ::UI::SetWindowGeometry $w whiteboard
	}
    }
    if {$prefs(haveTkDnD)} {
	update
	::WB::InitDnD $wapp(can)
    }
    catch {wm deiconify $w}
    #raise $w     This makes the window flashing when showed (linux)
    
    # A trick to let the window manager be finished before getting the geometry.
    # An 'update idletasks' needed anyway.
    after idle ::hooks::run whiteboardSetMinsizeHook $wtop

    if {[info exists opts(-file)]} {
	::CanvasFile::DrawCanvasItemFromFile $wtop $opts(-file)
    }
    ::hooks::run whiteboardPostBuildHook $wtop
}

# WB::NewCanvas --
# 
#       Makes canvas with scrollbars in own frame.

proc ::WB::NewCanvas {w args} {
    global  prefs
    variable dims
    
    array set argsArr {
	-background white
    }
    array set argsArr $args
    
    frame $w -class WBCanvas
    set wcan ${w}.can
    set wxsc ${w}.xsc
    set wysc ${w}.ysc
    
    canvas $wcan -height $dims(hCanOri) -width $dims(wCanOri)  \
      -relief raised -bd 0 -background $argsArr(-background)   \
      -scrollregion [list 0 0 $prefs(canScrollWidth) $prefs(canScrollHeight)]  \
      -xscrollcommand [list $wxsc set] -yscrollcommand [list $wysc set]	
    scrollbar $wxsc -command [list $wcan xview] -orient horizontal
    scrollbar $wysc -command [list $wcan yview] -orient vertical
    
    grid $wcan -row 0 -column 0 -sticky news -padx 0 -pady 0
    grid $wysc -row 0 -column 1 -sticky ns
    grid $wxsc -row 1 -column 0 -sticky ew
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure    $w 0 -weight 1

    ::CanvasText::Init $wcan
    
    return $wcan
}

# Testing Pages...

proc ::WB::NewCanvasPage {wtop name} {
    upvar ::WB::${wtop}::wapp wapp
    upvar ::WB::${wtop}::state state
    
    if {[string equal [winfo class [pack slaves $wapp(ccon)]] "WBCanvas"]} {
	
	# Repack the WBCanvas in notebook page.
	::WB::MoveCanvasToPage $wtop $name
    } else {
	set wpage [$wapp(nb) newpage $name]
	set frcan $wpage.fc
	::WB::NewCanvas $frcan -background $state(bgColCan)
	pack $frcan -fill both -expand true -side right
	set wapp(can,$name) $frcan.can
    }
}

proc ::WB::MoveCanvasToPage {wtop name} {
    upvar ::WB::${wtop}::wapp wapp
    
    # Repack the WBCanvas in notebook page.
    pack forget $wapp(frcan)
    ::mactabnotebook::mactabnotebook $wapp(nb)  \
      -selectcommand [namespace current]::SelectPageCmd
    pack $wapp(nb) -in $wapp(ccon) -fill both -expand true -side right
    set wpage [$wapp(nb) newpage $name]	
    pack $wapp(frcan) -in $wpage -fill both -expand true -side right
    raise $wapp(frcan)
    set wapp(can,$name) $wapp(can,)
}

proc ::WB::DeleteCanvasPage {wtop name} {
    upvar ::WB::${wtop}::wapp wapp
    
    $wapp(nb) deletepage $name
}

proc ::WB::SelectPageCmd {w name} {
    
    set wtop [winfo toplevel $w].
    upvar ::WB::${wtop}::wapp wapp
    upvar ::WB::${wtop}::state state

    Debug 3 "::WB::SelectPageCmd name=$name"
    
    set wapp(can) $wapp(can,$name)
    
    # Invoke tool button.
    ::WB::SetToolButton $wtop [::WB::ToolBtNumToName $state(btState)]
    ::hooks::run whiteboardSelectPage $wtop $name
}

proc ::WB::CloseHook {wclose} {
    global  wDlgs
    
    if {[winfo exists $wclose] && \
      [string equal [winfo class $wclose] "Whiteboard"]} {
	if {$wclose == "."} {
	    set wtop .
	} else {
	    set wtop ${wclose}.
	}
	set wcan [::WB::GetCanvasFromWtop $wtop]
	::Plugins::DeregisterCanvasInstBinds $wcan
	::hooks::run whiteboardCloseHook $wtop
    }   
}

# WB::CloseWhiteboard --
#
#       Called when closing whiteboard window; cleanup etc.

proc ::WB::CloseWhiteboard {wtop} {
    upvar ::WB::${wtop}::wapp wapp
    
    Debug 3 "::WB::CloseWhiteboard wtop=$wtop"
    
    # Verify that window still exists.
    if {$wtop != "."} {
	if {![winfo exists [string trimright $wtop .]]} {
	    return
	}
    }
    
    # Reset and cancel all put/get file operations related to this window!
    # I think we let put operations go on.
    #::PutFileIface::CancelAllWtop $wtop
    ::GetFileIface::CancelAllWtop $wtop
    ::Import::HttpResetAll $wtop
    ::WB::DestroyMain $wtop
}

# WB::DestroyMain --
# 
#       Destroys toplevel whiteboard and cleans up.

proc ::WB::DestroyMain {wtop} {
    global  prefs
    
    upvar ::WB::${wtop}::wapp wapp
    upvar ::WB::${wtop}::opts opts
    upvar ::WB::${wtop}::canvasImages canvasImages
    
    Debug 3 "::WB::DestroyMain wtop=$wtop"
    
    # Save instance specific 'state' array into generic 'state'.
    if {$opts(-usewingeom)} {
	::UI::SaveWinGeom $wapp(toplevel)
    } else {
	::UI::SaveWinGeom whiteboard $wapp(toplevel)
    }
    ::WB::SaveWhiteboardState $wtop
    
    if {$wtop == "."} {
	::UserActions::DoQuit -warning 1
    } else {
	set topw $wapp(toplevel)
	
	catch {destroy $topw}    
	unset opts
	unset wapp
    }
    
    # We could do some cleanup here.
    catch {eval {image delete} $canvasImages}
    ::CanvasUtils::ItemFree $wtop
    ::UI::FreeMenu $wtop
}

# WB::CreateImageForWtop --
# 
#       Create an image that gets garbage collected when window closed.
#       
#       name     desired image name; can be empty
#       args     -file
#                -data

proc ::WB::CreateImageForWtop {wtop name args} {
    
    upvar ::WB::${wtop}::canvasImages canvasImages

    array set argsArr $args
    set photoOpts {}
    if {[info exists argsArr(-file)]} {
	lappend photoOpts -file $argsArr(-file)
	if {[string tolower [file extension $argsArr(-file)]] == ".gif"} {
	    lappend photoOpts -format gif
	}
    } else {
	lappend photoOpts -data $argsArr(-data)
    }

    set photo [eval {image create photo} $name $photoOpts]
    lappend canvasImages $photo
    return $photo
}

proc ::WB::AddImageToGarbageCollector {wtop name} {
    
    upvar ::WB::${wtop}::canvasImages canvasImages

    lappend canvasImages $name
}

# WB::SaveWhiteboardState
# 
# 

proc ::WB::SaveWhiteboardState {wtop} {

    upvar ::WB::${wtop}::wapp wapp
      
    # Read back instance specific 'state' into generic 'state'.
    array set ::state [array get ::WB::${wtop}::state]

    # Widget geometries:
    #::WB::SaveWhiteboardDims $wtop
    #::UI::SaveWinGeom whiteboard $wapp(toplevel)
}

proc ::WB::SaveAnyState { } {
    
    set win ""
    set wbs [::WB::GetAllWhiteboards]
    if {[llength $wbs]} {
	set wfocus [focus]
	if {$wfocus != ""} {
	    set win [winfo toplevel $wfocus]
	}
	set win [lsearch -inline $wbs $wfocus]
	if {$win == ""} {
	    set win [lindex $wbs 0]
	}
	if {$win != ""} {
	    if {$win != "."} {
		set win ${win}.
	    }
	    ::WB::SaveWhiteboardState $win
	}	
    }
}

# WB::SaveWhiteboardDims --
# 
#       Stores the present whiteboard widget geom state in 'dims' array.

proc ::WB::SaveWhiteboardDims {wtop} {
    global  this

    upvar ::WB::dims dims
    upvar ::WB::${wtop}::wapp wapp
    
    set w $wapp(toplevel)
    set wCan $wapp(can)
        	    
    # Update actual size values. 'Root' no menu, 'Tot' with menu.
    set dims(wStatMess) [winfo width $wapp(statmess)]
    set dims(wRoot) [winfo width $w]
    set dims(hRoot) [winfo height $w]
    set dims(x) [winfo x $w]
    set dims(y) [winfo y $w]
    set dims(wTot) $dims(wRoot)
    
    # hMenu seems unreliable!!!
    if {![string match "mac*" $this(platform)]} {
	# MATS: seems to always give 1 Linux not...
	### EAS BEGIN
	set dims(hMenu) 1
	if {[winfo exists ${wtop}#menu]} {
	    set dims(hMenu) [winfo height ${wtop}#menu]
	}
	### EAS END
    } else {
	set dims(hMenu) 0
    }
    set dims(hTot) [expr $dims(hRoot) + $dims(hMenu)]
    set dims(wCanvas) [winfo width $wCan]
    set dims(hCanvas) [winfo height $wCan]

    Debug 3 "::WB::SaveWhiteboardDims dims(hRoot)=$dims(hRoot)"
}

# BADDDDDDDD!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
# WB::SaveCleanWhiteboardDims --
# 
#       We want to save wRoot and hRoot as they would be without any connections 
#       in the communication frame. Non jabber only. Only needed when quitting
#       to get the correct dims when set from preferences when launched again.

proc ::WB::SaveCleanWhiteboardDims {wtop} {
    global prefs

    upvar ::WB::dims dims
    upvar ::WB::${wtop}::wapp wapp

    if {$wtop != "."} {
	return
    }
    foreach {dims(wRoot) hRoot dims(x) dims(y)} [::UI::ParseWMGeometry .] break
    set dims(hRoot) [expr $dims(hCanvas) + $dims(hStatus) +  \
      $dims(hCommClean) + $dims(hTop) + $dims(hFakeMenu)]
    incr dims(hRoot) [expr [winfo height $wapp(xsc)] + 4]
}

# WB::ConfigureMain --
#
#       Configure the options 'opts' state of a whiteboard.
#       Returns 'opts' if no arguments.

proc ::WB::ConfigureMain {wtop args} {
    
    upvar ::WB::${wtop}::wapp wapp
    upvar ::WB::${wtop}::opts opts
    
    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    if {[llength $args] == 0} {
	return [array get opts]
    } else {

	foreach {name value} $args {
	    
	    switch -- $name {
		-title {
		    wm title $w $value    
		}
		-state {
		    set wmenu $wapp(menu)
		    if {[string equal $value "normal"]} {
			
		    } else {
			::WB::DisableWhiteboardMenus $wmenu
			::WB::DisableShortcutButtonPad $wtop
		    }
		}
	    }
	}
    }
    eval {::hooks::run whiteboardConfigureHook $wtop} $args
}

proc ::WB::SetButtonTrayDefs {buttonDefs} {
    variable btShortDefs
    
    set btShortDefs $buttonDefs
}

proc ::WB::SetMenuDefs {key menuDef} {
    variable menuDefs
    
    set menuDefs(main,$key) $menuDef
}

proc ::WB::LoginHook { } {
    
    foreach w [::WB::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]

	# Make menus consistent.
	::hooks::run whiteboardFixMenusWhenHook $wtop "connect"
    }
}

proc ::WB::LogoutHook { } {
    
    # Multiinstance whiteboard UI stuff.
    foreach w [::WB::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]

	# If no more connections left, make menus consistent.
	::hooks::run whiteboardFixMenusWhenHook $wtop "disconnect"
    }   
}

# WB::SetStatusMessage --

proc ::WB::SetStatusMessage {wtop msg} {
    
    # Make it failsafe.
    set w $wtop
    if {![string equal $wtop "."]} {
	set w [string trimright $wtop "."]
    }
    if {![winfo exists $w]} {
	return
    }
    upvar ::WB::${wtop}::wapp wapp
    $wapp(statmess) itemconfigure stattxt -text $msg
}

proc ::WB::GetServerCanvasFromWtop {wtop} {    
    upvar ::WB::${wtop}::wapp wapp
    
    return $wapp(servCan)
}

proc ::WB::GetCanvasFromWtop {wtop} {    
    upvar ::WB::${wtop}::wapp wapp
    
    return $wapp(can)
}

# WB::GetButtonState --
#
#       This is a utility function mainly for plugins to get the tool buttons 
#       state.

proc ::WB::GetButtonState {wtop} {
    upvar ::WB::${wtop}::state state
    variable btNo2Name     

    return $btNo2Name($state(btState))
}

proc ::WB::GetUndoToken {wtop} {    
    upvar ::WB::${wtop}::state state
    
    return $state(undotoken)
}

proc ::WB::GetButtonTray {wtop} {
    upvar ::WB::${wtop}::wapp wapp

    return $wapp(tray)
}

proc ::WB::GetMenu {wtop} {

    return ${wtop}menu
}

# WB::GetAllWhiteboards --
# 
#       Return all whiteboard's wtop as a list. 

proc ::WB::GetAllWhiteboards { } {    
    global  wDlgs

    return [lsort -dictionary \
      [lsearch -all -inline -glob [winfo children .] $wDlgs(wb)*]]
}

# WB::SetToolButton --
#
#       Uhhh...  When a tool button is clicked. Mainly sets all button specific
#       bindings.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       btName 
#       
# Results:
#       tool buttons created and mapped

proc ::WB::SetToolButton {wtop btName} {
    global  prefs wapp this
    
    variable wbicons
    upvar ::WB::${wtop}::wapp wapp
    upvar ::WB::${wtop}::state state
    upvar ::WB::${wtop}::opts opts

    Debug 3 "SetToolButton:: wtop=$wtop, btName=$btName"
    
    set wCan $wapp(can)
    set wtoplevel $wapp(toplevel)
    set state(btState) [::WB::ToolBtNameToNum $btName]
    set irow [string index $state(btState) 0]
    set icol [string index $state(btState) 1]
    $wapp(tool).bt$irow$icol configure -image $wbicons(on${irow}${icol})
    if {$state(btState) != $state(btStateOld)} {
	set irow [string index $state(btStateOld) 0]
	set icol [string index $state(btStateOld) 1]
	$wapp(tool).bt$irow$icol configure -image $wbicons(off${irow}${icol})
    }
    set oldButton $state(btStateOld)
    set oldBtName [::WB::ToolBtNumToName $oldButton]
    set state(btStateOld) $state(btState)
    ::WB::RemoveAllBindings $wCan
    
    # Deselect text items.
    if {$btName != "text"} {
	$wCan select clear
    }
    if {$btName == "del" || $btName == "text"} {
	::CanvasCmd::DeselectAll $wtop
    }
    
    # Cancel any outstanding polygon drawings.
    ::CanvasDraw::FinalizePoly $wCan -10 -10
    
    $wCan config -cursor {}
    
    # Bindings directly to the canvas widget are dealt with using bindtags.

    # Typical B3 bindings independent of tool selected.
    switch -- $this(platform) {
	macintosh - macosx {
	    $wCan bind std <Control-Button-1> {
		::CanvasUtils::DoItemPopup %W %X %Y 
	    }
	    $wCan bind std <Button-2> {
		::CanvasUtils::DoItemPopup %W %X %Y 
	    }
	    
	    # This one is needed to cancel selection since we compete
	    # with Button-1 binding to canvas.
	    $wCan bind std <Control-ButtonRelease-1> {
		::CanvasDraw::CancelBox %W
	    }
	    $wCan bind std <Control-B1-Motion> {
		::CanvasDraw::CancelBox %W
	    }
	    bind QTFrame <Control-Button-1> {
		::CanvasUtils::DoQuickTimePopup %W %X %Y 
	    }
	    bind QTFrame <Button-2> {
		::CanvasUtils::DoQuickTimePopup %W %X %Y 
	    }
	}
	default {
	    $wCan bind std <Button-3> {
		::CanvasUtils::DoItemPopup %W %X %Y 
	    }
	    bind QTFrame <Button-3> {
		::CanvasUtils::DoQuickTimePopup %W %X %Y 
	    }
	    bind SnackFrame <Button-3> {
		::CanvasUtils::DoWindowPopup %W %X %Y 
	    }
	}
    }
    
    switch -- $btName {
	point {
	    bindtags $wCan  \
	      [list $wCan WhiteboardPoint WhiteboardNonText $wtoplevel all]

	    $wCan bind std <Double-Button-1>  \
	      [list ::ItemInspector::ItemInspector $wtop current]

	    switch -- $this(platform) {
		macintosh - macosx {
		    $wCan bind std <Button-1> {
			
			# Global coords for popup.
			::CanvasUtils::StartTimerToItemPopup %W %X %Y 
		    }
		    $wCan bind std <ButtonRelease-1> {
			::CanvasUtils::StopTimerToItemPopup
		    }
		    $wCan bind std <Control-Button-1> {
			::CanvasUtils::DoItemPopup %W %X %Y 
		    }
		    
		    # This one is needed to cancel selection since we compete
		    # with Button-1 binding to canvas.
		    $wCan bind std <Control-ButtonRelease-1> {
			::CanvasDraw::CancelBox %W
		    }

		    $wCan bind std <Button-2> {
			::CanvasUtils::DoItemPopup %W %X %Y 
		    }
		    bind QTFrame <Button-1> {
			::CanvasUtils::StartTimerToPopupEx %W %X %Y \
			  ::CanvasUtils::DoQuickTimePopup
		    }
		    bind QTFrame <ButtonRelease-1> {
			::CanvasUtils::StopTimerToPopupEx
		    }
		    bind SnackFrame <Button-1> {
			::CanvasUtils::StartTimerToWindowPopup %W %X %Y 
		    }
		    bind SnackFrame <ButtonRelease-1> {
			::CanvasUtils::StopTimerToWindowPopup
		    }
		    ::WB::SetStatusMessage $wtop [mc uastatpointmac]
		}
		default {
		    $wCan bind std <Button-3> {
			
			# Global coords for popup.
			::CanvasUtils::DoItemPopup %W %X %Y 
		    }
		    bind QTFrame <Button-3> {
			::CanvasUtils::DoQuickTimePopup %W %X %Y 
		    }
		    bind SnackFrame <Button-3> {
			::CanvasUtils::DoWindowPopup %W %X %Y 
		    }
		    ::WB::SetStatusMessage $wtop [mc uastatpoint]		      
		}
	    }
	}
	move {
	    
	    # Bindings for moving items; movies need special class.
	    # The frame with the movie gets the mouse events, not the canvas.
	    # Binds directly to canvas widget since we want to move selected 
	    # items as well.
	    # With shift constrained move.
	    bindtags $wCan  \
	      [list $wCan WhiteboardMove WhiteboardNonText $wtoplevel all]	    

	    $wCan bind std <Button-1> {
		::CanvasDraw::InitMoveCurrent %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan bind std <B1-Motion> {
		::CanvasDraw::DragMoveCurrent %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan bind std <ButtonRelease-1> {
		::CanvasDraw::FinalMoveCurrent %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan bind std <Shift-B1-Motion> {
		::CanvasDraw::DragMoveCurrent %W [%W canvasx %x] [%W canvasy %y] shift
	    }
	    
	    $wCan bind tbbox&&(oval||rectangle) <Button-1> {
		::CanvasDraw::InitMoveRectPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan bind tbbox&&(oval||rectangle) <B1-Motion> {
		::CanvasDraw::DragMoveRectPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan bind tbbox&&(oval||rectangle) <ButtonRelease-1> {
		::CanvasDraw::FinalMoveRectPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan bind tbbox&&(oval||rectangle) <Shift-B1-Motion> {
		::CanvasDraw::DragMoveRectPoint %W [%W canvasx %x] [%W canvasy %y] shift
	    }
	    
	    $wCan bind tbbox&&(line||polygon) <Button-1> {
		::CanvasDraw::InitMovePolyLinePoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan bind tbbox&&(line||polygon) <B1-Motion> {
		::CanvasDraw::DragMovePolyLinePoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan bind tbbox&&(line||polygon) <ButtonRelease-1> {
		::CanvasDraw::FinalMovePolyLinePoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan bind tbbox&&(line||polygon) <Shift-B1-Motion> {
		::CanvasDraw::DragMovePolyLinePoint %W [%W canvasx %x] [%W canvasy %y] shift
	    }
	    
	    $wCan bind tbbox&&arc <Button-1> {
		::CanvasDraw::InitMoveArcPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan bind tbbox&&arc <B1-Motion> {
		::CanvasDraw::DragMoveArcPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan bind tbbox&&arc <ButtonRelease-1> {
		::CanvasDraw::FinalMoveArcPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan bind tbbox&&arc <Shift-B1-Motion> {
		::CanvasDraw::DragMoveArcPoint %W [%W canvasx %x] [%W canvasy %y] shift
	    }
		
	    # Need to substitute $wCan.
	    bind QTFrame <Button-1>  \
	      [subst {::CanvasDraw::InitMoveFrame $wCan %W %x %y}]
	    bind QTFrame <B1-Motion>  \
	      [subst {::CanvasDraw::DoMoveFrame $wCan %W %x %y}]
	    bind QTFrame <ButtonRelease-1>  \
	      [subst {::CanvasDraw::FinMoveFrame $wCan %W %x %y}]
	    bind QTFrame <Shift-B1-Motion>  \
	      [subst {::CanvasDraw::FinMoveFrame $wCan %W %x %y}]
	    
	    bind SnackFrame <Button-1>  \
	      [subst {::CanvasDraw::InitMoveFrame $wCan %W %x %y}]
	    bind SnackFrame <B1-Motion>  \
	      [subst {::CanvasDraw::DoMoveFrame $wCan %W %x %y}]
	    bind SnackFrame <ButtonRelease-1>  \
	      [subst {::CanvasDraw::FinMoveFrame $wCan %W %x %y}]
	    bind SnackFrame <Shift-B1-Motion>  \
	      [subst {::CanvasDraw::FinMoveFrame $wCan %W %x %y}]
	    
	    $wCan config -cursor hand2
	    ::WB::SetStatusMessage $wtop [mc uastatmove]
	}
	line {
	    bindtags $wCan  \
	      [list $wCan WhiteboardLine WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [mc uastatline]
	}
	arrow {
	    bindtags $wCan  \
	      [list $wCan WhiteboardArrow WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [mc uastatarrow]
	}
	rect {
	    bindtags $wCan  \
	      [list $wCan WhiteboardRect WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [mc uastatrect]
	}
	oval {
	    bindtags $wCan  \
	      [list $wCan WhiteboardOval WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [mc uastatoval]
	}
	text {
	    bindtags $wCan  \
	      [list $wCan WhiteboardText $wtoplevel all]
	    ::CanvasText::EditBind $wCan
	    $wCan config -cursor xterm
	    ::WB::SetStatusMessage $wtop [mc uastattext]
	}
	del {
	    bindtags $wCan  \
	      [list $wCan WhiteboardDel WhiteboardNonText $wtoplevel all]
	    $wCan bind std <Button-1> {
		::CanvasDraw::DeleteCurrent %W
	    }
	    bind QTFrame <Button-1>  \
	      [subst {::CanvasDraw::DeleteFrame $wCan %W %x %y}]
	    bind SnackFrame <Button-1>  \
	      [subst {::CanvasDraw::DeleteFrame $wCan %W %x %y}]
	    ::WB::SetStatusMessage $wtop [mc uastatdel]
	}
	pen {
	    bindtags $wCan  \
	      [list $wCan WhiteboardPen WhiteboardNonText $wtoplevel all]
	    $wCan config -cursor pencil
	    ::WB::SetStatusMessage $wtop [mc uastatpen]
	}
	brush {
	    bindtags $wCan  \
	      [list $wCan WhiteboardBrush WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [mc uastatbrush]
	}
	paint {
	    bindtags $wCan  \
	      [list $wCan WhiteboardPaint WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [mc uastatpaint]	      
	}
	poly {
	    bindtags $wCan  \
	      [list $wCan WhiteboardPoly WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [mc uastatpoly]	      
	}       
	arc {
	    bindtags $wCan  \
	      [list $wCan WhiteboardArc WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [mc uastatarc]	      
	}
	rot {
	    bindtags $wCan  \
	      [list $wCan WhiteboardRot WhiteboardNonText $wtoplevel all]
	    $wCan config -cursor exchange
	    ::WB::SetStatusMessage $wtop [mc uastatrot]	      
	}
    }
    
    # Collect all common non textual bindings in one procedure.
    if {$btName != "text"} {
	GenericNonTextBindings $wtop
    }

    # This is a hook for plugins to register their own bindings.
    # Calls any registered bindings for the plugin, and deregisters old ones.
    ::Plugins::SetCanvasBinds $wCan $oldBtName $btName
}

proc ::WB::GenericNonTextBindings {wtop} {
    
    upvar ::WB::${wtop}::wapp wapp
    set wCan $wapp(can)
    
    # Various bindings.
    bind $wCan <BackSpace> [list ::CanvasDraw::DeleteSelected $wCan]
    bind $wCan <Control-d> [list ::CanvasDraw::DeleteSelected $wCan]
}

# WB::RemoveAllBindings --
#
#       Clears all application defined bindings in the canvas.
#       
# Arguments:
#       w      the canvas widget.
#       
# Results:
#       none

proc ::WB::RemoveAllBindings {w} {
    
    Debug 3 "::WB::RemoveAllBindings w=$w"
    
    # List all tags that we may bind to.
    set btags {all std text tbbox&&arc tbbox&&(oval||rectangle)}
    foreach btag $btags {
	foreach seq [$w bind $btag] {
	    $w bind $btag $seq {}
	}
    }
    
    # Seems necessary for the arc item... More?
    bind $w <Shift-B1-Motion> {}
	
    bind QTFrame <Button-1> {}
    bind QTFrame <B1-Motion> {}
    bind QTFrame <ButtonRelease-1> {}
    bind SnackFrame <Button-1> {}
    bind SnackFrame <B1-Motion> {}
    bind SnackFrame <ButtonRelease-1> {}
    
    # Remove any text insertion...
    $w focus {}
}

# RegisterCanvasClassBinds, RegisterCanvasInstBinds --
# 
#       Wrapper for plugins custom canvas bindings.
#       *Class* binds to all whiteboards, 
#       *Inst* binds only to the specified instance (w).

proc ::WB::RegisterCanvasClassBinds {name canvasBindList} {
    
    # Register the actual bindings.
    ::Plugins::RegisterCanvasClassBinds $name $canvasBindList
    
    # Must set the bindings for each instance.
    foreach w [::WB::GetAllWhiteboards] {
	set wtop $w
	if {$w != "."} {
	    set wtop ${wtop}.
	}
	upvar ::WB::${wtop}::state state
	upvar ::WB::${wtop}::wapp wapp
	
	set btName    [::WB::ToolBtNumToName $state(btState)]
	set oldBtName [::WB::ToolBtNumToName $state(btStateOld)]
	::Plugins::SetCanvasBinds $wapp(can) $oldBtName $btName
    }
}

proc ::WB::RegisterCanvasInstBinds {w name canvasBindList} {

    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state

    # Register the actual bindings.
    ::Plugins::RegisterCanvasInstBinds $w $name $canvasBindList
    
    # Must set the bindings for this instance.
    set btName    [::WB::ToolBtNumToName $state(btState)]
    set oldBtName [::WB::ToolBtNumToName $state(btStateOld)]
    ::Plugins::SetCanvasBinds $w $oldBtName $btName
}

# WB::BuildWhiteboardMenus --
#
#       Makes all menus for a toplevel window.
#
# Arguments:
#       wtop        toplevel window. ("." or ".main2." with extra dot!)
#       
# Results:
#       menu created

proc ::WB::BuildWhiteboardMenus {wtop} {
    global  this wDlgs prefs dashFull2Short
    
    variable menuDefs
    upvar ::WB::${wtop}::wapp wapp
    upvar ::WB::${wtop}::state state
    upvar ::WB::${wtop}::opts opts
    
    ::Debug 2 "::WB::BuildWhiteboardMenus"
	
    set topwindow $wapp(toplevel)
    set wCan      $wapp(can)
    set wmenu     $wapp(menu)
    
    if {$prefs(haveMenus)} {
	menu $wmenu -tearoff 0
    } else {
	frame $wmenu -bd 1 -relief raised
    }
    if {[string match "mac*" $this(platform)] && $prefs(haveMenus)} {
	set haveAppleMenu 1
    } else {
	set haveAppleMenu 0
    }
    if {$haveAppleMenu} {
	::UI::BuildAppleMenu $wtop ${wmenu}.apple $opts(-state)
    }
    ::UI::NewMenu $wtop ${wmenu}.file   mFile        $menuDefs(main,file)  $opts(-state)
    ::UI::NewMenu $wtop ${wmenu}.edit   mEdit        $menuDefs(main,edit)  $opts(-state)
    ::UI::NewMenu $wtop ${wmenu}.prefs  mPreferences $menuDefs(main,prefs) $opts(-state)
    ::UI::NewMenu $wtop ${wmenu}.items  mLibrary     $menuDefs(main,items) $opts(-state)
    
    # Plugin menus if any.
    ::UI::BuildPublicMenus $wtop $wmenu
    
    ::UI::NewMenu $wtop ${wmenu}.info mInfo $menuDefs(main,info) $opts(-state)

    # Handle '-state disabled' option. Keep Edit/Copy.
    if {$opts(-state) == "disabled"} {
	::WB::DisableWhiteboardMenus $wmenu
    }
    
    # Use a function for this to dynamically build this menu if needed.
    ::WB::BuildFontMenu $wtop $prefs(canvasFonts)    
	
    # End menus; place the menubar.
    if {$prefs(haveMenus)} {
	$topwindow configure -menu $wmenu
    } else {
	pack $wmenu -side top -fill x
    }
}

# WB::DisableWhiteboardMenus --
#
#       Handle '-state disabled' option. Sets in a readonly state.

proc ::WB::DisableWhiteboardMenus {wmenu} {
    variable menuSpecPublic
    
    ::UI::MenuDisableAllBut ${wmenu}.file {
	mNew mCloseWindow mSaveCanvas mPageSetup mPrintCanvas mQuit
    }
    ::UI::MenuDisableAllBut ${wmenu}.edit {mAll}
    $wmenu entryconfigure [mc mPreferences] -state disabled
    $wmenu entryconfigure [mc mLibrary] -state disabled
    $wmenu entryconfigure [mc mInfo] -state disabled
	
    # Handle all 'plugins'.
    foreach wpath $menuSpecPublic(wpaths) {
	set name $menuSpecPublic($wpath,name)
	$wmenu entryconfigure $name -state disabled
    }
}

# WB::ConfigShortcutButtonPad --
#
#       Makes the top shortcut button pad. Switches between 'on' and 'off' state.
#       The 'subSpec' is only valid for 'init' where it can be 'off'.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       what        can be "init", "on", or "off".
#       subSpec     is only valid for 'init' where it can be 'off'.
#       
# Results:
#       toolbar created, or state toggled.

proc ::WB::ConfigShortcutButtonPad {wtop what {subSpec {}}} {
    global  this wDlgs prefs
    
    variable dims
    variable wbicons
    upvar ::WB::${wtop}::wapp wapp
    upvar ::WB::${wtop}::opts opts
    upvar ::WB::${wtop}::state state    
    
    Debug 3 "::WB::ConfigShortcutButtonPad what=$what, subSpec=$subSpec"

    if {$wtop != "."} {
	set topw [string trimright $wtop .]
    } else {
	set topw $wtop
    }
    set wfrtop  $wapp(frtop)
    set wfron   ${wfrtop}.on
    set wonbar  ${wfrtop}.on.barvert
    set woffbar ${wfrtop}.barhoriz
        
    if {![winfo exists $wfrtop]} {
	frame $wfrtop -relief raised -borderwidth 0
	frame $wfron -borderwidth 0
	label $wonbar -image $wbicons(barvert) -bd 1 -relief raised
	label $woffbar -image $wbicons(barhoriz) -relief raised -borderwidth 1
	pack  $wfrtop -side top -fill x
	pack  $wfron -fill x -side left -expand 1
	pack  $wonbar -padx 0 -pady 0 -side left
	bind  $wonbar <Button-1> [list $wonbar configure -relief sunken]
	bind  $wonbar <ButtonRelease-1>  \
	  [list [namespace current]::ConfigShortcutButtonPad $wtop "off"]
	
	# Build the actual shortcut button pad.
	::WB::BuildShortcutButtonPad $wtop
	pack $wapp(tray) -side left -fill both -expand 1
	if {$opts(-state) == "disabled"} {
	    ::WB::DisableShortcutButtonPad $wtop
	}
	
	# Cache the heights of the button tray.
	set dims(hTopOn)    [winfo reqheight $wonbar]
	set dims(hTopOff)   [winfo reqheight $woffbar]
	Debug 3 "hTopOn=$dims(hTopOn), hTopOff=$dims(hTopOff)"
    }
 
    switch -- $what {
	init {
    
	    # Do we want the toolbar to be collapsed at initialization?
	    if {[string equal $subSpec "off"]} {
		pack forget $wfron
		$wfrtop configure -bg gray75
		pack $woffbar -side left -padx 0 -pady 0
		bind $woffbar <ButtonRelease-1>   \
		  [list [namespace current]::ConfigShortcutButtonPad $wtop "on"]
	    }
	}
	off {
	    foreach {wMin hMin} [wm minsize $topw] break
	    
	    # Relax the min size.
	    wm minsize $topw 0 0
	    
	    # New size, keep width.
	    foreach {width height x y} [::UI::ParseWMGeometry $topw] break
	    set hNew    [expr $height - $dims(hTopOn) + $dims(hTopOff)]
	    set hMinNew [expr $hMin - $dims(hTopOn) + $dims(hTopOff)]
	    wm geometry $topw ${width}x${hNew}
	    pack forget $wfron
	    $wfrtop configure -bg gray75
	    pack $woffbar -side left -padx 0 -pady 0
	    bind $woffbar <Button-1> [list $woffbar configure -relief sunken]
	    bind $woffbar <ButtonRelease-1>   \
	      [list [namespace current]::ConfigShortcutButtonPad $wtop "on"]
	    $wonbar configure -relief raised
	    set state(visToolbar) 0
	    after idle [list wm minsize $topw $wMin $hMinNew]
	}
	on {
	
	    # New size, keep width.
	    foreach {wMin hMin} [wm minsize $topw] break
	    foreach {width height x y} [::UI::ParseWMGeometry $topw] break
	    set hNew    [expr $height - $dims(hTopOff) + $dims(hTopOn)]
	    set hMinNew [expr $hMin - $dims(hTopOff) + $dims(hTopOn)]
	    wm geometry $topw ${width}x${hNew}
	    pack forget $woffbar
	    pack $wfron -fill x -side left -expand 1
	    $woffbar configure -relief raised
	    bind $woffbar <Button-1> [list $woffbar configure -relief sunken]
	    bind $woffbar <ButtonRelease-1>   \
	      [list [namespace current]::ConfigShortcutButtonPad $wtop "off"]
	    set state(visToolbar) 1
	    after idle [list wm minsize $topw $wMin $hMinNew]
	}
    }
}

namespace eval ::WB:: {
    variable extButtonDefs {}
}

# WB::BuildShortcutButtonPad --
#
#       Build the actual shortcut button pad.

proc ::WB::BuildShortcutButtonPad {wtop} {
    global  wDlgs
    variable wbicons
    variable btShortDefs
    variable extButtonDefs
    upvar ::WB::${wtop}::wapp wapp
    
    set wCan   $wapp(can)
    set wtray  $wapp(tray)
    set wfrall $wapp(frall)
    set h [image height $wbicons(barvert)]

    ::buttontray::buttontray $wtray $h -relief raised -borderwidth 1

    # We need to substitute $wCan, $wtop etc specific for this wb instance.
    foreach {name cmd} $btShortDefs {
	set icon    [::Theme::GetImage [option get $wfrall ${name}Image {}]]
	set iconDis [::Theme::GetImage [option get $wfrall ${name}DisImage {}]]
	set cmd [subst -nocommands -nobackslashes $cmd]
	set txt [string totitle $name]
	$wtray newbutton $name $txt $icon $iconDis $cmd
    }
    
    # Extra buttons from components if any.
    foreach btdef $extButtonDefs {
	foreach {name icon iconDis cmd} $btdef {
	    set cmd [subst -nocommands -nobackslashes $cmd]
	    set txt [string totitle $name]
	    $wtray newbutton $name $txt $icon $iconDis $cmd
	}
    }

    # Anything special here.
    ::hooks::run whiteboardBuildButtonTrayHook $wtray
}

proc ::WB::RegisterShortcutButtons {btdefs} {
    variable extButtonDefs

    # Be sure to not have duplicates. Keep order!
    set names {}
    foreach spec $extButtonDefs {
	set name [lindex $spec 0]
	lappend names $name
	set tmpArr($name) $spec
    }
    foreach spec $btdefs {
	set name [lindex $spec 0]
	if {![info exists tmpArr($name)]} {
	    lappend names $name
	    set tmpArr($name) $spec
	}
    }
    set tmpDefs {}
    foreach name $names {
	lappend tmpDefs $tmpArr($name)
    }
    set extButtonDefs $tmpDefs
}

proc ::WB::DeregisterShortcutButton {name} {
    variable extButtonDefs

    set ind 0
    foreach btdef $extButtonDefs {
	if {[string equal [lindex $btdef 0] $name]} {
	    set extButtonDefs [lreplace $extButtonDefs $ind $ind]
	    break
	}
	incr ind
    }
}

# WB::DisableShortcutButtonPad --
#
#       Sets the state of the main to "read only".

proc ::WB::DisableShortcutButtonPad {wtop} {
    variable btShortDefs
    upvar ::WB::${wtop}::wapp wapp

    set wtray $wapp(tray)
    foreach {name cmd} $btShortDefs {

	switch -- $name {
	    save - print - stop {
		continue
	    }
	    default {
		$wtray buttonconfigure $name -state disabled
	    }
	}
    }
}

# WB::CreateAllButtons --
#
#       Makes the toolbar button pad for the drawing tools.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
# Results:
#       tool buttons created and mapped

proc ::WB::CreateAllButtons {wtop} {
    global  prefs this
    
    variable btNo2Name 
    variable btName2No
    variable wbicons
    upvar ::WB::${wtop}::state state
    upvar ::WB::${wtop}::wapp wapp
    upvar ::WB::${wtop}::opts opts
    
    set wtool $wapp(tool)
    
    for {set icol 0} {$icol <= 1} {incr icol} {
	for {set irow 0} {$irow <= 6} {incr irow} {
	    
	    # The icons are Mime coded gifs.
	    set lwi [label $wtool.bt$irow$icol -image $wbicons(off${irow}${icol}) \
	      -borderwidth 0]
	    grid $lwi -row $irow -column $icol -padx 0 -pady 0
	    set name $btNo2Name($irow$icol)
	    
	    if {![string equal $opts(-state) "disabled"]} {
		bind $lwi <Button-1>  \
		  [list [namespace current]::SetToolButton $wtop $name]
		
		# Handle bindings to popup options.
		if {[string match "mac*" $this(platform)]} {
		    bind $lwi <Button-1> "+ [namespace current]::StartTimerToToolPopup %W $wtop $name"
		    bind $lwi <ButtonRelease-1> [namespace current]::StopTimerToToolPopup
		} else {
		    bind $lwi <Button-3> [list [namespace current]::DoToolPopup %W $wtop $name]
		}
	    }
	}
    }
    
    # Make all popups.
    ::WB::BuildToolPopups $wtop
    ::WB::BuildToolPopupFontMenu $wtop $prefs(canvasFonts)
    
    # Color selector.
    set wcolsel $wtool.cacol
    set imheight [image height $wbicons(imcolor)]
    canvas $wcolsel -width 56 -height $imheight -highlightthickness 0
    $wcolsel create image 0 0 -anchor nw -image $wbicons(imcolor)
    set idColSel [$wcolsel create rectangle 7 7 33 30 \
      -fill $state(fgCol) -outline {} -tags tcolSel]
    set idBg [$wcolsel create polygon 21 32  35 32  35 22  48 22  48 44  21 44 \
      -fill $state(bgCol) -smooth 0 -outline {} -tags tbgcol] 
    set wapp(colSel) $wcolsel
    
    # Black and white reset rectangle.
    set idBWReset [$wtool.cacol create image 4 34 -anchor nw  \
      -image $wbicons(bwrect)]
    
    # bg and fg switching.
    set idBWSwitch [$wtool.cacol create image 38 4 -anchor nw  \
      -image $wbicons(bwrect)]
    grid $wtool.cacol -  -padx 0 -pady 0

    if {![string equal $opts(-state) "disabled"]} {
	$wcolsel bind $idColSel <Button-1>  \
	  [list [namespace current]::ColorSelector $wtop $state(fgCol)]
	$wcolsel bind $idBWReset <Button-1>  \
	  [list [namespace current]::ResetColorSelector $wtop]
	$wcolsel bind $idBWSwitch <Button-1> \
	  [list [namespace current]::SwitchBgAndFgCol $wtop]
    }
}

proc ::WB::BuildToolPopups {wtop} {
    global  prefs
    
    variable menuDefs
    upvar ::WB::${wtop}::wapp wapp
    
    set wtool $wapp(tool)
    
    # List of which entries where.
    array set menuArr {
	line       {thickness dash constrain}
	arrow      {thickness dash constrain}
	rect       {thickness fill dash}
	oval       {thickness fill dash}
	pen        {thickness smooth}
	brush      {brushthickness smooth}
	text       {font fontsize fontweight}
	poly       {thickness fill dash smooth}
	arc        {thickness fill dash arcs}
    }
    foreach name [array names menuArr] {
	set mDef($name) {}
	foreach key $menuArr($name) {
	    lappend mDef($name) $menuDefs(main,prefs,$key)
	}
	::UI::NewMenu $wtop ${wtool}.pop${name} {} $mDef($name) normal
	if {!$prefs(haveDash) && ([lsearch $menuArr($name) dash] >= 0)} {
	    ::UI::MenuMethod ${wtool}.pop${name} entryconfigure mDash -state disabled
	}
    }
}

# WB::StartTimerToToolPopup, StopTimerToToolPopup, DoToolPopup --
#
#       Some functions to handle the tool popup menu.

proc ::WB::StartTimerToToolPopup {w wtop name} {
    
    variable toolPopupId
    
    if {[info exists toolPopupId]} {
	catch {after cancel $toolPopupId}
    }
    set toolPopupId [after 1000 [list [namespace current]::DoToolPopup $w $wtop $name]]
}

proc ::WB::StopTimerToToolPopup { } {
    
    variable toolPopupId

    if {[info exists toolPopupId]} {
	catch {after cancel $toolPopupId}
    }
}

proc ::WB::DoToolPopup {w wtop name} {
    
    upvar ::WB::${wtop}::wapp wapp

    set wtool $wapp(tool)
    set wpop ${wtool}.pop${name}
    if {[winfo exists $wpop]} {
	set x [winfo rootx $w]
	set y [expr [winfo rooty $w] + [winfo height $w]]
	tk_popup $wpop $x $y
    }
}

proc ::WB::DoTopMenuPopup {w wtop wmenu} {
    
    if {[winfo exists $wmenu]} {
	set x [winfo rootx $w]
	set y [expr [winfo rooty $w] + [winfo height $w]]
	tk_popup $wmenu $x $y
    }
}

proc ::WB::SwitchBgAndFgCol {wtop} {
    
    upvar ::WB::${wtop}::state state
    upvar ::WB::${wtop}::wapp wapp

    $wapp(colSel) itemconfigure tcolSel -fill $state(bgCol)
    $wapp(colSel) itemconfigure tbgcol  -fill $state(fgCol)
    set tmp $state(fgCol)
    set state(fgCol) $state(bgCol)
    set state(bgCol) $tmp
}

# WB::ColorSelector --
#
#       Callback procedure for the color selector in the tools frame.
#       
# Arguments:
#       col      initial color value.
#       
# Results:
#       color dialog shown.

proc ::WB::ColorSelector {wtop col} {
    
    upvar ::WB::${wtop}::state state
    upvar ::WB::${wtop}::wapp wapp

    set col [tk_chooseColor -initialcolor $col]
    if {[string length $col] > 0} {
	set state(fgCol) $col
	$wapp(colSel) itemconfigure tcolSel -fill $state(fgCol)
	$wapp(colSel) raise tcolSel
    }
}

proc ::WB::ResetColorSelector {wtop} {

    upvar ::WB::${wtop}::state state
    upvar ::WB::${wtop}::wapp wapp

    $wapp(colSel) itemconfigure tcolSel -fill black
    $wapp(colSel) itemconfigure tbgcol  -fill white
    set state(fgCol) black
    set state(bgCol) white
}
	
# Access functions to make it possible to isolate these variables.

proc ::WB::ToolBtNameToNum {name} {

    variable btName2No 
    return $btName2No($name)
}

proc ::WB::ToolBtNumToName {num} {

    variable btNo2Name     
    return $btNo2Name($num)
}

# ::WB::SetBasicMinsize --
# 
#       Makes a wm minsize call to set the minsize of the basic whiteboard.
#       Shall only be called after idle!

proc ::WB::SetBasicMinsize {wtop} {
    
    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    
    eval {wm minsize $w} [::WB::GetBasicWhiteboardMinsize $wtop]
}

# WB::GetBasicWhiteboardMinsize --
# 
#       Computes the minimum width and height of whiteboard including any menu
#       but excluding any custom made entry parts.

proc ::WB::GetBasicWhiteboardMinsize {wtop} {
    global  this prefs
    
    variable wbicons
    upvar ::WB::${wtop}::wapp wapp

    # Let the geometry manager finish before getting widget sizes.
    update idletasks
  
    # The min height.
    # If we have a custom made menubar using a frame with labels (embedded).
    if {$prefs(haveMenus)} {
	set hFakeMenu 0
	if {![string match "mac*" $this(platform)]} {
	     set hMenu 1
	     # In 8.4 it seems that .wb1.#wb1#menu is used.
	     set wmenu_ ${wtop}#[string trim $wtop .]#menu
	     if {[winfo exists $wmenu_]} {
		 set hMenu [winfo height $wmenu_]
	     }
	 } else {
	     set hMenu 0
	 }
    } else {
	set hMenu [winfo reqheight $wapp(menu)]
    }
    set hTop 0
    if {[winfo exists $wapp(frtop)]} {
	set hTop [winfo reqheight $wapp(frtop)]
    }
    set hTool     [winfo reqheight $wapp(tool)]
    set hBugImage [image height $wapp(bugImage)]
    set hStatus   [winfo reqheight $wapp(frstat)]
    
    # The min width.
    set wBarVert  [image width $wbicons(barvert)]
    set wButtons  [$wapp(tray) minwidth]
    
    set wMin [expr $wBarVert + $wButtons]
    set hMin [expr $hMenu + $hTop + $hTool + $hBugImage + $hStatus]

    Debug 6 "::WB::GetBasicWhiteboardMinsize: (wMin=$wMin, hMin=$hMin), \
      hTop=$hTop, hTool=$hTool, hBugImage=$hBugImage, hStatus=$hStatus,\
      wButtons=$wButtons, wBarVert=$wBarVert"
    
    return [list $wMin $hMin]
}

# ::WB::SetCanvasSize --
#
#       From the canvas size, 'cw' and 'ch', set the total application size.
#       
# Arguments:
#
# Results:
#       None.

proc ::WB::SetCanvasSize {wtop cw ch} {
    global  this
    upvar ::WB::${wtop}::wapp wapp

    set w $wtop
    if {![string equal $wtop "."]} {
	set w [string trimright $wtop "."]
    }

    # Compute new root size from the desired canvas size.
    set thick [expr int([$wapp(can) cget -highlightthickness])]
    set widthtot  [expr $cw + [winfo reqwidth $wapp(tool)]]
    set heighttot [expr $ch + \
      [winfo reqheight $wapp(comm)] + \
      [winfo reqheight $wapp(frtop)]]
    incr widthtot  [expr [winfo reqwidth $wapp(ysc)] + 4 + $thick]
    incr heighttot [expr [winfo reqheight $wapp(xsc)] + 4 + $thick]
    
    # Menu is a bit tricky. Not needed since wm geometry doesn't count it!
    if {0} {
	if {![string match "mac*" $this(platform)]} {
	    # ad hoc !
	    set wmenu "${w}.#[winfo name $w]#menu"
	    if {[winfo exists $wmenu]} {
		incr heighttot [winfo height $wmenu]
	    }
	}
    }
    
    # Make sure not bigger than the screen.
    set wscreen [winfo screenwidth $w]
    set hscreen [winfo screenheight $w]
    if {$widthtot > $wscreen} {
	set widthtot $wscreen
    }
    if {$heighttot > $hscreen} {
	set heighttot $hscreen
    }
    wm geometry $w ${widthtot}x${heighttot}

    Debug 4 "::WB::SetCanvasSize:: cw=$cw, ch=$ch, heighttot=$heighttot, \
      heighttot=$heighttot"
}

proc ::WB::GetCanvasSize {wtop} {
    upvar ::WB::${wtop}::wapp wapp

    return [list [winfo width $wapp(can)] [winfo height $wapp(can)]]
}

# WB::GetFocus --
#
#       Check clipboard and activate corresponding menus.    
#       
# Results:
#       updates state of menus.

proc ::WB::GetFocus {wtop w} {
    
    upvar ::WB::${wtop}::opts opts
    upvar ::WB::${wtop}::wapp wapp

    # Bind to toplevel may fire multiple times.
    set wtopReal $wtop
    if {![string equal $wtop "."]} {
	set wtopReal [string trimright $wtop "."]
    }
    if {$wtopReal != $w} {
	return
    }
    Debug 3 "GetFocus:: wtop=$wtop, w=$w"
    
    # Can't see why this should happen?
    set medit ${wtop}menu.edit
    if {![winfo exists $medit]} {
	return
    }
    
    # Check the clipboard or selection.
    if {[catch {selection get -selection CLIPBOARD} sel]} {
	::UI::MenuMethod $medit entryconfigure mPaste -state disabled
    } elseif {($sel != "") && ($opts(-state) == "normal")} {
	::UI::MenuMethod $medit entryconfigure mPaste -state normal
    }
    
    # If any selected items canvas. Text items ???
    if {[llength [$wapp(can) find withtag selected]] > 0} {
	::UI::MenuMethod $medit entryconfigure mCut -state normal
	::UI::MenuMethod $medit entryconfigure mCopy -state normal
    }
}

# WB::FixMenusWhenCopy --
# 
#       Sets the correct state for menus and buttons when copy something.
#       
# Arguments:
#       w       the widget that contains something that is copied.
#
# Results:

proc ::WB::FixMenusWhenCopy {w} {

    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::opts opts

    if {$opts(-state) == "normal"} {
	::UI::MenuMethod ${wtop}menu.edit entryconfigure mPaste -state normal
    } else {
	::UI::MenuMethod ${wtop}menu.edit entryconfigure mPaste -state disabled
    }
        
    ::hooks::run whiteboardFixMenusWhenHook $wtop copy
}

# WB::MakeItemMenuDef --
# 
#       Makes a menuDefs list recursively for canvas files.

proc ::WB::MakeItemMenuDef {dir} {
    
    set mdef {}
    foreach f [glob -nocomplain -directory $dir *] {
	
	# Sort out directories we shouldn't search.
	switch -- [string tolower [file tail $f]] {
	    . - resource.frk - cvs {
		continue
	    }
	}
	if {[file isdirectory $f]} {
	    set submdef [MakeItemMenuDef $f]
	    set name [file tail $f]
	    if {[llength $submdef]} {
		lappend mdef [list cascade $name {} normal {} {} $submdef]
	    }
	} elseif {[string equal [file extension $f] ".can"]} {
	    set name [file rootname [file tail $f]]
	    set cmd {::CanvasFile::DrawCanvasItemFromFile $wtop}
	    lappend cmd $f
	    lappend mdef [list command $name $cmd normal {}]
	}
    }
    return $mdef
}

# WB::BuildFontMenu ---
# 
#       Creates the font selection menu, and removes any old.
#    
# Arguments:
#       mt         The menu path.
#       allFonts   List of names of the fonts.
#       
# Results:
#       font submenu built.

proc ::WB::BuildFontMenu {wtop allFonts} {
    
    set mt ${wtop}menu.prefs.mfont
    
    $mt delete 0 end
    foreach afont $allFonts {
	$mt add radio -label $afont -variable ::WB::${wtop}::state(font)  \
	  -command [list ::WB::FontChanged $wtop name]
    }
    
    # Be sure that the presently selected font family is still there,
    # else choose helvetica.
    set fontStateVar ::WB::${wtop}::state(font)
    if {[lsearch -exact $allFonts $fontStateVar] == -1} {
	set ::WB::${wtop}::state(font) {Helvetica}
    }
}

proc ::WB::BuildToolPopupFontMenu {wtop allFonts} {
    upvar ::WB::${wtop}::wapp wapp
    
    set wtool $wapp(tool)
    set mt ${wtool}.poptext.mfont
    
    $mt delete 0 end
    foreach afont $allFonts {
	$mt add radio -label $afont -variable ::WB::${wtop}::state(font)  \
	  -command [list ::WB::FontChanged $wtop name]
    }
}

proc ::WB::BuildAllFontMenus {allFonts} {

    # Must do this for all open whiteboards!
    foreach wtopreal [::WB::GetAllWhiteboards] {
	if {$wtopreal != "."} {
	    set wtop "${wtopreal}."
	} else {
	    set wtop $wtopreal
	}
	::WB::BuildFontMenu $wtop $allFonts
	::WB::BuildToolPopupFontMenu $wtop $allFonts
    }
}

# WB::FontChanged --
# 
#       Callback procedure for the font menu. When new font name, size or weight,
#       and we have focus on a text item, change the font spec of this item.
#
# Arguments:
#       wtop        toplevel window. ("." or ".main2." with extra dot!)
#       what        name, size or weight.
#       
# Results:
#       updates text item, sends to all clients.

proc ::WB::FontChanged {wtop what} {
    global  fontSize2Points fontPoints2Size

    upvar ::WB::${wtop}::wapp wapp
    upvar ::WB::${wtop}::state state
    
    set wCan $wapp(can)

    # If there is a focus on a text item, change the font for this item.
    set idfocus [$wCan focus]
    
    if {[string length $idfocus] > 0} {
	set theItno [::CanvasUtils::GetUtag $wCan focus]
	if {[string length $theItno] == 0} {
	    return
	}
	if {[$wCan type $theItno] != "text"} {
	    return
	}
	set fontSpec [$wCan itemcget $theItno -font]
	if {[llength $fontSpec] > 0} {
	    array set whatToInd {name 0 size 1 weight 2}
	    array set whatToPref {name font size fontSize weight fontWeight}
	    set ind $whatToInd($what)

	    # Need to translate html size to point size.
	    if {$what == "size"} {
		set newFontSpec [lreplace $fontSpec $ind $ind  \
		  $fontSize2Points($state($whatToPref($what)))]
	    } else {
		set newFontSpec [lreplace $fontSpec $ind $ind  \
		  $state($whatToPref($what))]
	    }
	    ::CanvasUtils::ItemConfigure $wCan $theItno -font $newFontSpec
	}
    }
}

proc ::WB::StartStopAnimatedWave {wtop start} {
    upvar ::WB::${wtop}::wapp wapp
    
    set waveImage [::Theme::GetImage [option get $wapp(frall) waveImage {}]]  
    ::UI::StartStopAnimatedWave $wapp(statmess) $waveImage $start
}

proc ::WB::StartStopAnimatedWaveOnMain {start} {    
    upvar ::WB::.::wapp wapp
    
    set waveImage [::Theme::GetImage [option get $wapp(frall) waveImage {}]]  
    ::UI::StartStopAnimatedWave $wapp(statmess) $waveImage $start
}

# WB::CreateBrokenImage --
# 
#       Creates an actual image with the broken symbol that matches
#       up the width and height. The image is garbage collected.

proc ::WB::CreateBrokenImage {wtop width height} {
    variable icons    
    upvar ::WB::${wtop}::canvasImages canvasImages
    
    if {($width == 0) || ($height == 0)} {
	set name $icons(brokenImage)
    } else {
	set zoomx [expr $width/[image width $icons(brokenImage)]]
	set zoomy [expr $height/[image height $icons(brokenImage)]]
	if {($zoomx < 1) && ($zoomy < 1)} {
	    set name $icons(brokenImage)
	} else {
	    set zoomx [expr $zoomx < 1 ? 1 : $zoomx]
	    set zoomy [expr $zoomy < 1 ? 1 : $zoomy]
	    set name [image create photo -width $width -height $height]
	    $name blank
	    $name copy $icons(brokenImage) -to 0 0 $width $height  \
	      -zoom $zoomx $zoomy -compositingrule overlay
	    lappend canvasImages $name
	}
    }
    return $name
}

proc ::WB::InitDnD {wcan} {
    
    dnd bindtarget $wcan text/uri-list <Drop>      [list ::WB::DnDDrop %W %D %T %x %y]   
    dnd bindtarget $wcan text/uri-list <DragEnter> [list ::WB::DnDEnter %W %A %D %T]   
    dnd bindtarget $wcan text/uri-list <DragLeave> [list ::WB::DnDLeave %W %D %T]       
}

proc ::WB::DnDDrop {w data type x y} {
    global  prefs
    
    ::Debug 2 "::WB::DnDDrop data=$data, type=$type"

    set wtop [winfo toplevel $w]
    if {$wtop != "."} {
	set wtop ${wtop}.
    }

    foreach f $data {
	
	# Strip off any file:// prefix.
	set f [string map {file:// ""} $f]
	set f [uriencode::decodefile $f]
	
	# Allow also .can files to be dropped.
	if {[file extension $f] == ".can"} {
	    ::CanvasFile::DrawCanvasItemFromFile $wtop $f
	} else {
	    set mime [::Types::GetMimeTypeForFileName $f]
	    set haveImporter [::Plugins::HaveImporterForMime $mime]
	    if {$haveImporter} {	   
		set errMsg [::Import::DoImport $w [list -coords [list $x $y]] -file $f]
		if {$errMsg != ""} {
		    tk_messageBox -title [mc Error] -icon error -type ok \
		      -message "Failed importing: $errMsg" -parent [winfo toplevel $w]
		}
		incr x $prefs(offsetCopy)
		incr y $prefs(offsetCopy)
	    } else {
		tk_messageBox -title [mc Error] -icon error -type ok \
		  -message [mc messfailmimeimp $mime] \
		  -parent [winfo toplevel $w]
	    }
	}
    }
}

proc ::WB::DnDEnter {w action data type} {
    
    ::Debug 2 "::WB::DnDEnter action=$action, data=$data, type=$type"

    set act "none"
    foreach f $data {
	if {[file extension $f] == ".can"} {
	    set haveImporter 1
	} else {
	    
	    # Require at least one file importable.
	    set haveImporter [::Plugins::HaveImporterForMime  \
	      [::Types::GetMimeTypeForFileName $f]]
	}
	if {$haveImporter} {
	    focus $w
	    set act $action
	    break
	}
    }
    return $act
}

proc ::WB::DnDLeave {w data type} {
    
    focus [winfo toplevel $w] 
}

# ::WB::GetThemeImage --
# 
#       This is a method to first search for any image file using
#       the standard theme engine, but use hardcoded icons as fallback.

proc ::WB::GetThemeImage {name} {
    
    return [::Theme::GetImageFromExisting $name ::WB::iconsPreloaded]
}

#       Some stuff to handle sending messages using hooks.
#       The idea is to isolate us from jabber, p2p etc.
#       It shall only deal with remote clients, local drawing must be handled
#       separately.

# ::WB::SendMessageList --
# 
#       Invokes any registered send message hook. The 'cmdList' must
#       be without the "CANVAS:" prefix!

proc ::WB::SendMessageList {wtop cmdList args} {
    
    eval {::hooks::run whiteboardSendMessageHook $wtop $cmdList} $args
}

# ::WB::SendGenMessageList --
# 
#       Invokes any registered send message hook. 
#       The commands in the cmdList may include any prefix.
#       The prefix shall be included in commands of the cmdList.
#       THIS IS ACTUALLY A BAD SOLUTION AND SHALL BE REMOVED LATER!!!

proc ::WB::SendGenMessageList {wtop cmdList args} {
    
    eval {::hooks::run whiteboardSendGenMessageHook $wtop $cmdList} $args
}

# ::WB::PutFile --
# 
#       Invokes any registered hook for putting a file. This is only called
#       when we want to do p2p file transports (put/get).

proc ::WB::PutFile {wtop fileName opts args} {
    
    eval {::hooks::run whiteboardPutFileHook $wtop $fileName $opts} $args
}

# ::WB::RegisterHandler --
# 
#       Register handlers for additional command in the protocol.

proc ::WB::RegisterHandler {prefix cmd} {
    variable handler

    set handler($prefix) $cmd
    ::hooks::run whiteboardRegisterHandlerHook $prefix $cmd
}

# ::WB::GetRegisteredHandlers --
# 
#       Code that wants to get registered handlers must call this to get
#       the present handlers, and to add the 'whiteboardRegisterHandlerHook'
#       to get subsequent handlers.

proc ::WB::GetRegisteredHandlers { } {
    variable handler

    return [array get handler]
}

#-------------------------------------------------------------------------------

