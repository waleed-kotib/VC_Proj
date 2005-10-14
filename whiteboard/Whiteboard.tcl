#  Whiteboard.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the actual whiteboard.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#  
# $Id: Whiteboard.tcl,v 1.48 2005-10-14 08:03:02 matben Exp $

package require anigif
package require moviecontroller
package require uriencode
package require CanvasDraw
package require CanvasText
package require CanvasUtils
package require CanvasCutCopyPaste
package require CanvasCmd
package require CanvasFile
package require FileCache
package require FilePrefs
package require GetFileIface
package require Import
package require ItemInspector
package require Plugins
package require PutFileIface
package require WBPrefs

package provide Whiteboard 1.0

namespace eval ::WB:: {
        
    # Add all event hooks.
    ::hooks::register quitAppHook         ::WB::QuitAppHook
    ::hooks::register quitAppHook         ::WB::SaveAnyState
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
    option add *Whiteboard*TRadiobutton.padding  {0}             50

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
    foreach tname [array names btName2No] {
	option add *Whiteboard.tool${tname}Image $tname         widgetDefault
    }

    # Color selector.
    option add *Whiteboard.bwrectImage          bwrect          widgetDefault
    option add *Whiteboard.colorSelectorImage   colorSelector   widgetDefault
    option add *Whiteboard.colorSelBWImage      colorSelBW      widgetDefault
    option add *Whiteboard.colorSelSwapImage    colorSelSwap    widgetDefault
    
    # Canvas selections.
    option add *Whiteboard.aSelect              2               widgetDefault
    option add *Whiteboard.fgSelectNormal       black           widgetDefault
    option add *Whiteboard.fgSelectLocked       red             widgetDefault

    # Special for X11 menus to look ok.
    if {[tk windowingsystem] eq "x11"} {
	option add *Whiteboard.Menu.borderWidth 0               50
    }

    # Keeps various geometry info.
    variable dims
    
    # @@@ BAD!!!!!!!!!!!!!!!!!!!!!!???????????????
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
    # Should text inserts be batched?
    set prefs(batchText) 1

    # Delay time in ms for batched text.
    set prefs(batchTextms) 2000

    # Want to fit all movies within canvas?
    set prefs(autoFitMovies) 1

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
#       that is inherited by instance specific 'state' array '::WB::${w}::state'

proc ::WB::InitPrefsHook { } {
    global  state prefs this
    
    ::Debug 2 "::WB::InitPrefsHook"
    
    # The tool buttons.
    set state(tool)      "point"
    set state(toolPrev)  "point"
    set state(toolCache) "point"
    
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
    ::PrefUtils::Add [list  \
      [list prefs(45)              prefs_45              $prefs(45)]             \
      [list prefs(shortsMulticastQT) prefs_shortsMulticastQT $prefs(shortsMulticastQT) userDefault] \
      [list state(tool)            state_tool            $state(tool)]           \
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
    variable btName2No
    variable wbicons
    	
    # Get icons.
    set icons(brokenImage) [image create photo -format gif  \
      -file [file join $this(imagePath) brokenImage.gif]]	

    # Make all standard icons.
    CreateToolImages
    Stuff
    
    set wbicons(barhoriz) [::WB::GetThemeImage [option get $w barhorizImage {}]]
    set wbicons(barvert)  [::WB::GetThemeImage [option get $w barvertImage {}]]

    # Drawing tool buttons.
    foreach name [array names btName2No] {
	set wbicons($name) [::WB::GetThemeImage  \
	  [option get $w tool${name}Image {}]]
    }
    
    # Color selector.
    foreach name {colorSelector colorSelBW colorSelSwap} {
	set wbicons($name) [::WB::GetThemeImage  \
	  [option get $w ${name}Image {}]]
    }
    set wbicons(bwrect)  [::WB::GetThemeImage [option get $w bwrectImage {}]]
}

proc ::WB::CreateToolImages { } {
    global  this
    variable iconsPreloaded
    variable btName2No
    
    set dir [file join $this(imagePath) tools]
    
    # Actual tools.
    foreach name [array names btName2No] {
	set iconsPreloaded($name) [image create photo \
	  -format gif -file [file join $dir ${name}.gif]]
    }
    
    # Color selector.
    foreach name {colorSelector colorSelBW colorSelSwap} {
	set iconsPreloaded($name) [image create photo \
	  -format gif -file [file join $dir ${name}.gif]]
    }
}

proc ::WB::Stuff { } {
    variable iconsPreloaded
    
    # height = 54
    set ::WB::iconsPreloaded(barvert) [image create photo -data {
	R0lGODdhCwA2ALMAAP////e1ve+cre9zhOdae+dKY94xUtYAIdDQ0M7Ozpyc
	nISEhFJSUgAAAAAAAAAAACwAAAAACwA2AAAEYjDJSauVQQzCSTGLdIzksShT
	aaIUeV7rJScAVVcMlc/VLfmTnUTI+9ksRGIRCBzqisdJM5GESqPPoNV4xWWt
	TOQXGvZqt+Wxkpc+O9FYN3VLi7/vZPtcvtRXEwiBgoOEhQgRADs=
    }]

    # height = 58
    set ::WB::iconsPreloaded(barvert) [image create photo -data {
    R0lGODdhCwA6AMQAAM7Ozve1ve+cre9zhOdae+dKY94xUoSEhNYAIZycnP//
    /1JSUtDQ0P///////////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAACwAAAAACwA6AAAFbiAgjmRpioEwECxRGIeI
    zDRyJGNt4yR9n7uTEKAgFUsLUnJYOoqco6VIynwaTVRqFQqdKqvXUReQBYvD
    36jZekamzVzsGxx3q9f1uZaZv3vxaH5ka0SBf4d0hoOCW4plAAyRkpOSCpOW
    kYJ7hGshADs=
    }]

    set ::WB::iconsPreloaded(barhoriz) [image create photo -data {
	R0lGODdhQQALAOcAAP//////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////
	/////++Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+U
	pe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe+Upe97lO97lO97lO97
	lO97lO97lO97lO97lO97lO97lO97lO97lO97lO97lO97lO97lO97lO97lO97lO97lO97lO97
	lO97lO97lO97lO97lO97lO97lO97lO97lO97lO97lNYAIdYAIdYAIdYAIdYAIdYAIdYAIdYA
	IdYAIdYAIdYAIdYAIdYAIdYAIdYAIdYAIdYAIdYAIdYAIdYAIdYAIdYAIdYAIdYAIdYAIdYA
	IdYAIdYAIdYAIdYAIdYAIdYAIc7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O
	zs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O
	zs7Ozs7OzpycnJycnJycnJycnJycnJycnJycnJycnJycnJycnJycnJycnJycnJycnJycnJyc
	nJycnJycnJycnJycnJycnJycnJycnJycnJycnJycnJycnJycnJycnJycnJycnISEhISEhISE
	hISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISE
	hISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhFJSUv//////////////////////
	////////////////////////////////////////////////////////////////////////
	/////////////////////////////////ywAAAAAQQALAAAIdwABCRxIsKDBgwgTKlzIsKHD
	hw9DIAQgkCIgixgrary4MSPHjx4tHgwBBgzCbwJRAlLJMqXLlS9bwpwpU2VBkiVNQtzJc2TO
	nD2D8gTy86fQow5/KV26dGDIjlBBRn0q9SCoq1ivEqwZsytNr1y/Ih1LtqxZhAEBADs=
    }]

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
      {command   mAboutCoccinella    {::Splash::SplashScreen} normal   {}}
    set menuDefs(main,info,aboutquicktimetcl)  \
      {command   mAboutQuickTimeTcl  {::Dialogs::AboutQuickTimeTcl}                normal   {}}

    # Only basic functionality.
    set menuDefs(main,file) {
	{command   mCloseWindow     {::UI::DoCloseWindow $w}             normal   W}
	{separator}
	{command   mOpenImage/Movie {::Import::ImportImageOrMovieDlg $w} normal  I}
	{command   mOpenURLStream   {::Multicast::OpenMulticast $w}  normal   {}}
	{separator}
	{command   mOpenCanvas      {::CanvasFile::OpenCanvasFileDlg $w} normal   {}}
	{command   mSaveCanvas      {::CanvasFile::Save $w}              normal   S}
	{separator}
	{command   mSaveAs          {::CanvasFile::SaveAsDlg $w}         normal   {}}
	{command   mSaveAsItem      {::CanvasCmd::DoSaveAsItem $w}       normal   {}}
	{command   mPageSetup       {::UserActions::PageSetup $w}        normal   {}}
	{command   mPrintCanvas     {::UserActions::DoPrintCanvas $w}    normal   P}
	{separator}
	{command   mQuit            {::UserActions::DoQuit}                 normal   Q}
    }
    if {![::Plugins::HavePackage QuickTimeTcl]} {
	lset menuDefs(main,file) 3 3 disabled
    }
	    
    # If embedded the embedding app should close us down.
    if {$this(embedded)} {
	lset menuDefs(main,file) end 3 disabled
    } else {
	package require Multicast
    }

    set menuDefs(main,edit) {    
	{command     mUndo             {::CanvasCmd::Undo $w}             normal   Z}
	{command     mRedo             {::CanvasCmd::Redo $w}             normal   {}}
	{separator}
	{command     mCut              {::UI::CutCopyPasteCmd cut}        disabled X}
	{command     mCopy             {::UI::CutCopyPasteCmd copy}       disabled C}
	{command     mPaste            {::UI::CutCopyPasteCmd paste}      disabled V}
	{command     mAll              {::CanvasCmd::SelectAll $w}        normal   A}
	{command     mEraseAll         {::CanvasCmd::DoEraseAll $w}       normal   {}}
	{separator}
	{command     mInspectItem      {::ItemInspector::ItemInspector $w selected} disabled {}}
	{separator}
	{command     mRaise            {::CanvasCmd::RaiseOrLowerItems $w raise} disabled R}
	{command     mLower            {::CanvasCmd::RaiseOrLowerItems $w lower} disabled L}
	{separator}
	{command     mLarger           {::CanvasCmd::ResizeItem $w $prefs(scaleFactor)} disabled >}
	{command     mSmaller          {::CanvasCmd::ResizeItem $w $prefs(invScaleFac)} disabled <}
	{cascade     mFlip             {}                                      disabled {} {} {
	    {command   mHorizontal     {::CanvasCmd::FlipItem $w horizontal}  normal   {} {}}
	    {command   mVertical       {::CanvasCmd::FlipItem $w vertical}    normal   {} {}}}
	}
	{command     mImageLarger      {::Import::ResizeImage $w 2 sel auto} disabled {}}
	{command     mImageSmaller     {::Import::ResizeImage $w -2 sel auto} disabled {}}
    }
    
    # These are used not only in the drop-down menus.
    set menuDefs(main,prefs,separator) 	{separator}
    set menuDefs(main,prefs,background)  \
      {command     mBackgroundColor      {::CanvasCmd::SetCanvasBgColor $w} normal   {}}
    set menuDefs(main,prefs,grid)  \
      {checkbutton mGrid             {::CanvasCmd::DoCanvasGrid $w}   normal   {} \
      {-variable ::WB::${w}::state(canGridOn)}}
    set menuDefs(main,prefs,thickness)  \
      {cascade     mThickness        {}                                    normal   {} {} {
	{radio   1                 {}                                      normal   {} \
	  {-variable ::WB::${w}::state(penThick)}}
	{radio   2                 {}                                      normal   {} \
	  {-variable ::WB::${w}::state(penThick)}}
	{radio   4                 {}                                      normal   {} \
	  {-variable ::WB::${w}::state(penThick)}}
	{radio   6                 {}                                      normal   {} \
	  {-variable ::WB::${w}::state(penThick)}}}
    }
    set menuDefs(main,prefs,brushthickness)  \
      {cascade     mBrushThickness   {}                                    normal   {} {} {
	{radio   8                 {}                                      normal   {} \
	  {-variable ::WB::${w}::state(brushThick)}}
	{radio   10                {}                                      normal   {} \
	  {-variable ::WB::${w}::state(brushThick)}}
	{radio   12                {}                                      normal   {} \
	  {-variable ::WB::${w}::state(brushThick)}}
	{radio   16                {}                                      normal   {} \
	  {-variable ::WB::${w}::state(brushThick)}}}
    }
    set menuDefs(main,prefs,fill)  \
      {checkbutton mFill             {}                                    normal   {} \
      {-variable ::WB::${w}::state(fill)}}
    set menuDefs(main,prefs,smoothness)  \
      {cascade     mLineSmoothness   {}                                    normal   {} {} {
	{radio   None              {set ::WB::${w}::state(smooth) 0}        normal   {} \
	  {-value 0 -variable ::WB::${w}::state(splinesteps)}}
	{radio   2                 {set ::WB::${w}::state(smooth) 1}        normal   {} \
	  {-value 2 -variable ::WB::${w}::state(splinesteps)}}
	{radio   4                 {set ::WB::${w}::state(smooth) 1}        normal   {} \
	  {-value 4 -variable ::WB::${w}::state(splinesteps)}}
	{radio   6                 {set ::WB::${w}::state(smooth) 1}        normal   {} \
	  {-value 6 -variable ::WB::${w}::state(splinesteps)}}
	{radio   10                {set ::WB::${w}::state(smooth) 1}        normal   {} \
	  {-value 10 -variable ::WB::${w}::state(splinesteps)}}}
    }
    set menuDefs(main,prefs,smooth)  \
      {checkbutton mLineSmoothness   {}                                    normal   {} \
      {-variable ::WB::${w}::state(smooth)}}
    set menuDefs(main,prefs,arcs)  \
      {cascade     mArcs             {}                                    normal   {} {} {
	{radio   mPieslice         {}                                      normal   {} \
	  {-value pieslice -variable ::WB::${w}::state(arcstyle)}}
	{radio   mChord            {}                                      normal   {} \
	  {-value chord -variable ::WB::${w}::state(arcstyle)}}
	{radio   mArc              {}                                      normal   {} \
	  {-value arc -variable ::WB::${w}::state(arcstyle)}}}
    }
    
    # Dashes need a special build process. Be sure not to substitute $w.
    set dashList {}
    foreach dash [lsort -decreasing [array names ::WB::dashFull2Short]] {
	set dashval $::WB::dashFull2Short($dash)
	if {[string equal " " $dashval]} {
	    set dopts {-value { } -variable ::WB::${w}::state(dash)}
	} else {
	    set dopts [format {-value %s -variable ::WB::${w}::state(dash)} $dashval]
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
	{radio   1                 {::WB::FontChanged $w size}          normal   {} \
	  {-variable ::WB::${w}::state(fontSize)}}
	{radio   2                 {::WB::FontChanged $w size}          normal   {} \
	  {-variable ::WB::${w}::state(fontSize)}}
	{radio   3                 {::WB::FontChanged $w size}          normal   {} \
	  {-variable ::WB::${w}::state(fontSize)}}
	{radio   4                 {::WB::FontChanged $w size}          normal   {} \
	  {-variable ::WB::${w}::state(fontSize)}}
	{radio   5                 {::WB::FontChanged $w size}          normal   {} \
	  {-variable ::WB::${w}::state(fontSize)}}
	{radio   6                 {::WB::FontChanged $w size}          normal   {} \
	  {-variable ::WB::${w}::state(fontSize)}}}
    }
    set menuDefs(main,prefs,fontweight)  \
      {cascade     mWeight           {}                                    normal   {} {} {
	{radio   mNormal           {::WB::FontChanged $w weight}        normal   {} \
	  {-value normal -variable ::WB::${w}::state(fontWeight)}}
	{radio   mBold             {::WB::FontChanged $w weight}        normal   {} \
	  {-value bold -variable ::WB::${w}::state(fontWeight)}}
	{radio   mItalic           {::WB::FontChanged $w weight}        normal   {} \
	  {-value italic -variable ::WB::${w}::state(fontWeight)}}}
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

proc ::WB::QuitAppHook { } {
    global  wDlgs
    
    ::UI::SaveWinPrefixGeom $wDlgs(wb) whiteboard
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
#       toplevel widget path

proc ::WB::NewWhiteboard {args} { 
    global wDlgs
    variable uidmain
    
    set w [::WB::GetNewToplevelPath]
    eval {::WB::BuildWhiteboard $w} $args
    return $w
}

proc ::WB::GetNewToplevelPath { } {
    global wDlgs
    variable uidmain
    
    return $wDlgs(wb)[incr uidmain]
}

# WB::BuildWhiteboard --
#
#       Makes the main toplevel window.
#
# Arguments:
#       w           toplevel widget path
#       args        see above
#       
# Results:
#       new instance toplevel created.

proc ::WB::BuildWhiteboard {w args} {
    global  this prefs
    
    variable dims
    variable wbicons
    variable iconsInitted
    
    Debug 2 "::WB::BuildWhiteboard w=$w, args='$args'"
    
    namespace eval ::WB::${w}:: { }
    
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::state state
    upvar ::WB::${w}::opts opts
    upvar ::WB::${w}::canvasImages canvasImages
    
    eval {::hooks::run whiteboardPreBuildHook $w} $args
    
    array set opts [list -state normal -title $prefs(theAppName) -usewingeom 0]
    array set opts $args
        
    set wfmain          $w.fmain
    set wfrleft         $wfmain.frleft
    set wfrcan          $wfmain.fc
    set wcomm           $w.fcomm
    
    # Common widget paths.
    set wapp(toplevel)  $w
    set wapp(menu)      $w.menu
    set wapp(frtop)     $w.frtop
    set wapp(tray)      $w.frtop.on.fr
    set wapp(tool)      $wfrleft.f.tool
    set wapp(buglabel)  $wfrleft.pad.f.bug
    set wapp(frcan)     $wfrcan
    set wapp(comm)      $wcomm
    set wapp(frstat)    $wcomm.st    
    set wapp(topchilds) [list $w.menu $w.frtop $w.fmain $w.fcomm]
    
    # temporary...
    set wapp(can)       $wfrcan.can
    set wapp(xsc)       $wfrcan.xsc
    set wapp(ysc)       $wfrcan.ysc
    set wapp(can,)      $wapp(can)
    
    # Having the frame with canvas + scrollbars as a sibling makes it possible
    # to pack it in a different place.
    set wapp(ccon)      $w.fmain.cc
    
    # Notebook widget path to be packed into wapp(ccon).
    set wapp(nb)        $w.fmain.nb
    
    set canvasImages {}
    
    # Init some of the state variables.
    # Inherit from the factory + preferences state.
    array set state [array get ::state]
    set state(fileName) ""
    if {$opts(-state) eq "disabled"} {
	set state(tool) "point"
    }
    set state(msg) ""
    
    ::UI::Toplevel $w -class Whiteboard -closecommand ::WB::CloseHook
    wm withdraw $w
    wm title $w $opts(-title)
    
    set iconResize [::Theme::GetImage [option get $w resizeHandleImage {}]]
    set wbicons(resizehandle) $iconResize
    if {!$iconsInitted} {
	InitIcons $w
    }
    
    # Note that the order of calls can be critical as any 'update' may trigger
    # network events to attempt drawing etc. Beware!!!
     
    # Start with menus.
    BuildWhiteboardMenus $w
	
    # Special for X11 menus to look ok.
    if {[tk windowingsystem] eq "x11"} {
	ttk::separator $w.stop -orient horizontal
	pack $w.stop -side top -fill x
    }

    # Shortcut buttons at top? Do we want the toolbar to be visible.
    CreateShortcutButtonPad $w
    if {!$state(visToolbar)} {
	ConfigShortcutButtonPad $w off
    }

    # Make the connection frame.
    ttk::frame $wcomm
    pack  $wcomm  -side bottom -fill x
    
    # Status message part.
    ttk::label $wapp(frstat) -style Small.TLabel \
      -textvariable ::WB::${w}::state(msg) -anchor w -padding {16 2}
    pack  $wapp(frstat)  -side top -fill x

    ttk::separator $wcomm.s -orient horizontal
    pack  $wcomm.s  -side top -fill x
    
    # Build the header for the actual network setup. This is where we
    # may have mode specific parts, p2p, jabber...
    ::hooks::run whiteboardBuildEntryHook $w $w $wcomm
    
    ttk::separator $w.tsep -orient horizontal
    pack  $w.tsep  -side top -fill x
    
    # Make frame for toolbar + canvas.
    frame $w.fmain
    frame $w.fmain.frleft
    frame $w.fmain.frleft.f -relief raised -borderwidth 1
    ttk::frame $w.fmain.frleft.f.tool
    frame $w.fmain.frleft.pad -relief raised -borderwidth 1
    ttk::frame $w.fmain.frleft.pad.f
    frame $w.fmain.cc -bd 1 -relief raised

    pack  $w.fmain            -side top -fill both -expand 1
    pack  $w.fmain.frleft     -side left -fill y
    pack  $w.fmain.frleft.f   -fill both
    pack  $w.fmain.frleft.f.tool -side top
    pack  $w.fmain.frleft.pad -fill both -expand 1
    pack  $w.fmain.frleft.pad.f  -fill both -expand 1
    pack  $w.fmain.cc         -fill both -expand 1 -side right
    
    # The 'Coccinella'.
    set wapp(bugImage) [::Theme::GetImage ladybug]
    ttk::label $wapp(buglabel) -borderwidth 0 -image $wapp(bugImage)
    pack $wapp(buglabel) -side bottom -fill x    
    
    # Make the tool buttons and invoke the one from the prefs file.
    CreateAllButtons $w
    
    # ...and the drawing canvas.
    NewCanvas $wapp(frcan) -background $state(bgColCan)
    set wapp(servCan) $wapp(can)
    pack $wapp(frcan) -in $wapp(ccon) -fill both -expand true -side right
    
    # Invoke tool button.
    SetToolButton $w $state(tool)

    # Add things that are defined in the prefs file and not updated else.
    ::CanvasCmd::DoCanvasGrid $w
    
    # Create the undo/redo object.
    set state(undotoken) [undo::new -command [list ::UI::UndoConfig $w]]

    # Set up paste menu if something on the clipboard.
    GetFocus $w $w
    bind $w         <FocusIn>  [list [namespace current]::GetFocus $w %W]
    bind $wapp(can) <Button-1> [list focus $wapp(can)]
        
    if {$opts(-usewingeom)} {
	::UI::SetWindowGeometry $w
    } else {
	
	# Set window position only for the first whiteboard on screen.
	# Subsequent whiteboards are placed by the window manager.
	if {[llength [GetAllWhiteboards]] == 1} {	
	    ::UI::SetWindowGeometry $w whiteboard
	}
    }
    if {$prefs(haveTkDnD)} {
	update
	InitDnD $wapp(can)
    }
    catch {wm deiconify $w}
    #raise $w     This makes the window flashing when showed (linux)
    
    # A trick to let the window manager be finished before getting the geometry.
    # An 'update idletasks' needed anyway.
    after idle ::hooks::run whiteboardSetMinsizeHook $w

    if {[info exists opts(-file)]} {
	::CanvasFile::DrawCanvasItemFromFile $w $opts(-file)
    }
    ::hooks::run whiteboardPostBuildHook $w
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
    set wcan $w.can
    set wxsc $w.xsc
    set wysc $w.ysc
    
    set bg $argsArr(-background)
    
    canvas $wcan -height $dims(hCanOri) -width $dims(wCanOri)  \
      -relief raised -bd 0 -background $bg -highlightbackground $bg \
      -scrollregion [list 0 0 $prefs(canScrollWidth) $prefs(canScrollHeight)]  \
      -xscrollcommand [list $wxsc set] -yscrollcommand [list $wysc set]	
    tuscrollbar $wxsc -command [list $wcan xview] -orient horizontal
    tuscrollbar $wysc -command [list $wcan yview] -orient vertical
    
    grid  $wcan  -row 0 -column 0 -sticky news -padx 0 -pady 0
    grid  $wysc  -row 0 -column 1 -sticky ns
    grid  $wxsc  -row 1 -column 0 -sticky ew
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure    $w 0 -weight 1

    ::CanvasText::Init $wcan
    
    bind $wcan <Control-Right> [list $wcan xview scroll  1 units]
    bind $wcan <Control-Left>  [list $wcan xview scroll -1 units]
    bind $wcan <Control-Down>  [list $wcan yview scroll  1 units]
    bind $wcan <Control-Up>    [list $wcan yview scroll -1 units]

    return $wcan
}

# Testing Pages...

proc ::WB::NewCanvasPage {w name} {
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::state state
    
    if {[string equal [winfo class [pack slaves $wapp(ccon)]] "WBCanvas"]} {
	
	# Repack the WBCanvas in notebook page.
	MoveCanvasToPage $w $name
    } else {
	set wpage [$wapp(nb) newpage $name]
	set frcan $wpage.fc
	NewCanvas $frcan -background $state(bgColCan)
	pack $frcan -fill both -expand true -side right
	set wapp(can,$name) $frcan.can
    }
}

proc ::WB::MoveCanvasToPage {w name} {
    upvar ::WB::${w}::wapp wapp
    
    # Repack the WBCanvas in notebook page.
    pack forget $wapp(frcan)
    ::mactabnotebook::mactabnotebook $wapp(nb)  \
      -selectcommand [namespace current]::SelectPageCmd  \
      -closebutton 1
    pack $wapp(nb) -in $wapp(ccon) -fill both -expand true -side right
    set wpage [$wapp(nb) newpage $name]	
    pack $wapp(frcan) -in $wpage -fill both -expand true -side right
    raise $wapp(frcan)
    set wapp(can,$name) $wapp(can,)
}

proc ::WB::DeleteCanvasPage {w name} {
    upvar ::WB::${w}::wapp wapp
    
    $wapp(nb) deletepage $name
}

proc ::WB::SelectPageCmd {wpage name} {
    
    set w [winfo toplevel $wpage]
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::state state

    Debug 3 "::WB::SelectPageCmd name=$name"
    
    set wapp(can) $wapp(can,$name)
    
    # Invoke tool button.
    SetToolButton $w $state(tool)
    ::hooks::run whiteboardSelectPage $w $name
}

proc ::WB::CloseHook {w} {
    
    if {[winfo exists $w] && [string equal [winfo class $w] "Whiteboard"]} {
	set wcan [GetCanvasFromWtop $w]
	::Plugins::DeregisterCanvasInstBinds $wcan
	::hooks::run whiteboardCloseHook $w
    }   
}

# WB::CloseWhiteboard --
#
#       Called when closing whiteboard window; cleanup etc.

proc ::WB::CloseWhiteboard {w} {
    
    Debug 3 "::WB::CloseWhiteboard w=$w"
    
    # Verify that window still exists.
    if {![winfo exists $w]} {
	return
    }
    upvar ::WB::${w}::wapp wapp
    
    # Reset and cancel all put/get file operations related to this window!
    # I think we let put operations go on.
    #::PutFileIface::CancelAllWtop $w
    ::GetFileIface::CancelAllWtop $w
    ::Import::HttpResetAll $w
    ::Import::Free $w
    DestroyMain $w
}

# WB::DestroyMain --
# 
#       Destroys toplevel whiteboard and cleans up.

proc ::WB::DestroyMain {w} {
    global  prefs
    
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::opts opts
    
    Debug 3 "::WB::DestroyMain w=$w"
        
    # Save instance specific 'state' array into generic 'state'.
    if {$opts(-usewingeom)} {
	::UI::SaveWinGeom $w
    } else {
	::UI::SaveWinGeom whiteboard $w
    }
    SaveWhiteboardState $w

    catch {destroy $w}    
    unset opts
    unset wapp
    
    # We could do some cleanup here.
    GarbageImages $w
    ::CanvasUtils::ItemFree $w
    ::UI::FreeMenu $w
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
    if {[info exists argsArr(-file)]} {
	if {[string tolower [file extension $argsArr(-file)]] eq ".gif"} {
	    set photo [::Utils::CreateGif $argsArr(-file) $name]
	} else {
	    if {$name eq ""} {
		set photo [image create photo -file $argsArr(-file)]
	    } else {
		set photo [image create photo $name -file $argsArr(-file)]
	    }
	}
    } else {
	if {$name eq ""} {
	    set photo [image create photo -data $argsArr(-data)]
	} else {
	    set photo [image create photo $name -data $argsArr(-data)]
	}
    }

    lappend canvasImages $photo
    return $photo
}

proc ::WB::AddImageToGarbageCollector {w name} {
    
    upvar ::WB::${w}::canvasImages canvasImages

    lappend canvasImages $name
}

proc ::WB::GarbageImages {w} {
    
    upvar ::WB::${w}::canvasImages canvasImages
    
    foreach name $canvasImages {
	if {[::anigif::isanigif $name]} {
	    ::anigif::delete $name
	} else {
	    if {![catch {image inuse $name}]} {
		catch {image delete $name}
	    }
	}
    }
}

# WB::SaveWhiteboardState
# 
# 

proc ::WB::SaveWhiteboardState {w} {

    upvar ::WB::${w}::wapp wapp
      
    # Read back instance specific 'state' into generic 'state'.
    array set ::state [array get ::WB::${w}::state]

    # Widget geometries:
    #::WB::SaveWhiteboardDims $w
    #::UI::SaveWinGeom whiteboard $wapp(toplevel)
}

proc ::WB::SaveAnyState { } {
    
    set win ""
    set wbs [GetAllWhiteboards]
    if {[llength $wbs]} {
	set wfocus [focus]
	if {$wfocus ne ""} {
	    set win [winfo toplevel $wfocus]
	}
	set win [lsearch -inline $wbs $wfocus]
	if {$win eq ""} {
	    set win [lindex $wbs 0]
	}
	if {$win ne ""} {
	    ::WB::SaveWhiteboardState $win
	}	
    }
}

proc ::WB::GetStateArray {w} {
    upvar ::WB::${w}::state state

    return [array get state]
}

# WB::SaveWhiteboardDims --
# 
#       Stores the present whiteboard widget geom state in 'dims' array.

proc ::WB::SaveWhiteboardDims {w} {
    global  this

    upvar ::WB::dims dims
    upvar ::WB::${w}::wapp wapp
    
    set wcan $wapp(can)
        	    
    # Update actual size values. 'Root' no menu, 'Tot' with menu.
    #set dims(wStatMess) [winfo width $wapp(statmess)]
    set dims(wStatMess) [winfo width $wapp(frstat)]
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
	if {[winfo exists $w.#menu]} {
	    set dims(hMenu) [winfo height $w.#menu]
	}
	### EAS END
    } else {
	set dims(hMenu) 0
    }
    set dims(hTot) [expr $dims(hRoot) + $dims(hMenu)]
    set dims(wCanvas) [winfo width $wcan]
    set dims(hCanvas) [winfo height $wcan]

    Debug 3 "::WB::SaveWhiteboardDims dims(hRoot)=$dims(hRoot)"
}

# BADDDDDDDD!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
# WB::SaveCleanWhiteboardDims --
# 
#       We want to save wRoot and hRoot as they would be without any connections 
#       in the communication frame. Non jabber only. Only needed when quitting
#       to get the correct dims when set from preferences when launched again.

proc ::WB::SaveCleanWhiteboardDims {w} {
    global prefs

    upvar ::WB::dims dims
    upvar ::WB::${w}::wapp wapp

    if {$w ne "."} {
	return
    }
    foreach {dims(wRoot) hRoot dims(x) dims(y)} [::UI::ParseWMGeometry [wm geometry .]] break
    set dims(hRoot) [expr $dims(hCanvas) + $dims(hStatus) +  \
      $dims(hCommClean) + $dims(hTop) + $dims(hFakeMenu)]
    incr dims(hRoot) [expr [winfo height $wapp(xsc)] + 4]
}

# WB::ConfigureMain --
#
#       Configure the options 'opts' state of a whiteboard.
#       Returns 'opts' if no arguments.

proc ::WB::ConfigureMain {w args} {
    
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::opts opts
    
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
			DisableShortcutButtonPad $w
		    }
		}
	    }
	}
    }
    eval {::hooks::run whiteboardConfigureHook $w} $args
}

proc ::WB::SetButtonTrayDefs {buttonDefs} {
    variable btShortDefs
    
    set btShortDefs $buttonDefs
}

proc ::WB::SetMenuDefs {key menuDef} {
    variable menuDefs
    
    set menuDefs(main,$key) $menuDef
}

proc ::WB::GetMenuDefs {key} {
    variable menuDefs
    
    return $menuDefs(main,$key)
}

proc ::WB::LoginHook { } {
    
    foreach w [GetAllWhiteboards] {

	# Make menus consistent.
	::hooks::run whiteboardFixMenusWhenHook $w "connect"
    }
}

proc ::WB::LogoutHook { } {
    
    # Multiinstance whiteboard UI stuff.
    foreach w [GetAllWhiteboards] {

	# If no more connections left, make menus consistent.
	::hooks::run whiteboardFixMenusWhenHook $w "disconnect"
    }   
}

# WB::SetStatusMessage --

proc ::WB::SetStatusMessage {w msg} {
    
    # Make it failsafe.
    if {![winfo exists $w]} {
	return
    }
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::state state

    set state(msg) $msg
    #$wapp(statmess) itemconfigure stattxt -text $msg
}

proc ::WB::GetServerCanvasFromWtop {w} {    
    upvar ::WB::${w}::wapp wapp
    
    return $wapp(servCan)
}

proc ::WB::GetCanvasFromWtop {w} {    
    upvar ::WB::${w}::wapp wapp
    
    return $wapp(can)
}

# WB::GetButtonState --
#
#       This is a utility function mainly for plugins to get the tool buttons 
#       state.

proc ::WB::GetButtonState {w} {
    upvar ::WB::${w}::state state

    return $state(tool)
}

proc ::WB::GetUndoToken {w} {    
    upvar ::WB::${w}::state state
    
    return $state(undotoken)
}

proc ::WB::GetButtonTray {w} {
    upvar ::WB::${w}::wapp wapp

    return $wapp(tray)
}

proc ::WB::GetMenu {w} {

    return [::UI::GetMenuFromWindow $w]
}

# WB::GetAllWhiteboards --
# 
#       Return all whiteboard's toplevel widget paths as a list. 

proc ::WB::GetAllWhiteboards { } {    
    global  wDlgs

    return [lsort -dictionary \
      [lsearch -all -inline -glob [winfo children .] $wDlgs(wb)*]]
}

# WB::ToolCmd --
# 
#       Command for radiobutton tools.

proc ::WB::ToolCmd {w} {
    upvar ::WB::${w}::state state
        
    set state(toolPrev)  $state(toolCache)
    set state(toolCache) $state(tool)

    SetToolButton $w $state(tool)
}

# WB::SetToolButton --
#
#       Uhhh...  When a tool button is clicked.
#       
# Arguments:
#       w           toplevel widget path
#       btName 
#       
# Results:
#       tool buttons created and mapped

proc ::WB::SetToolButton {w btName} {
    global  prefs wapp this
    
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::state state
    upvar ::WB::${w}::opts opts

    Debug 3 "SetToolButton:: w=$w, btName=$btName"
    
    set wcan $wapp(can)
    
    # Deselect text items.
    if {$btName ne "text"} {
	$wcan select clear
    }
    if {$btName eq "del" || $btName eq "text"} {
	::CanvasCmd::DeselectAll $w
    }
    
    # Cancel any outstanding polygon drawings.
    ::CanvasDraw::FinalizePoly $wcan -10 -10
    
    $wcan config -cursor {}
    
    RemoveAllBindings $wcan
    SetItemBinds $w $btName    
    SetFrameItemBinds $w $btName

    # This is a hook for plugins to register their own bindings.
    # Calls any registered bindings for the plugin, and deregisters old ones.
    ::Plugins::SetCanvasBinds $wcan $state(toolPrev) $btName
}

# WB::SetItemBinds --
#
#       Mainly sets all button specific bindings.
#       
# Arguments:
#       w           toplevel widget path
#       btName 
#       
# Results:
#       none

proc ::WB::SetItemBinds {w btName} {
    global  this wapp

    upvar ::WB::${w}::wapp wapp

    set wcan $wapp(can)

    # Bindings directly to the canvas widget are dealt with using bindtags.
    
    # These ones are needed to cancel selection since we compete
    # with Button-1 binding to canvas.
    switch -- $this(platform) {
	macintosh - macosx {
	    $wcan bind std <Control-ButtonRelease-1> {
		::CanvasDraw::CancelBox %W
		::CanvasDraw::CancelPoly %W
	    }
	    $wcan bind std <Control-B1-Motion> {
		::CanvasDraw::CancelBox %W
		::CanvasDraw::CancelPoly %W
	    }
	}
    }

    # Typical B3 bindings independent of tool selected.
    $wcan bind std&&!locked <<ButtonPopup>> {
	::CanvasUtils::DoItemPopup %W %X %Y 
    }
    $wcan bind std&&locked <<ButtonPopup>> {
	::CanvasUtils::DoLockedPopup %W %X %Y 
    }

    switch -- $btName {
	point {
	    bindtags $wcan  \
	      [list $wcan WhiteboardPoint WhiteboardNonText Whiteboard $w all]

	    $wcan bind std <Double-Button-1>  \
	      [list ::ItemInspector::ItemInspector $w current]

	    switch -- $this(platform) {
		macintosh - macosx {
		    $wcan bind std&&!locked <Button-1> {
			::CanvasUtils::StartTimerToPopupEx %W %X %Y \
			  ::CanvasUtils::DoItemPopup
		    }
		    $wcan bind std&&locked <Button-1> {
			::CanvasUtils::StartTimerToPopupEx %W %X %Y \
			  ::CanvasUtils::DoLockedPopup
		    }
		    $wcan bind std <ButtonRelease-1> {
			::CanvasUtils::StopTimerToPopupEx
		    }
		    SetStatusMessage $w [mc uastatpointmac]
		}
		default {
		    SetStatusMessage $w [mc uastatpoint]		      
		}
	    }
	}
	move {
	    
	    # Bindings for moving items; movies need special class.
	    # The frame with the movie gets the mouse events, not the canvas.
	    # Binds directly to canvas widget since we want to move selected 
	    # items as well.
	    # With shift constrained move.
	    bindtags $wcan  \
	      [list $wcan WhiteboardMove WhiteboardNonText Whiteboard $w all]	    

	    $wcan bind std&&!locked <Button-1> {
		::CanvasDraw::InitMoveCurrent %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wcan bind std&&!locked <B1-Motion> {
		::CanvasDraw::DragMoveCurrent %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wcan bind std&&!locked <ButtonRelease-1> {
		::CanvasDraw::FinalMoveCurrent %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wcan bind std&&!locked <Shift-B1-Motion> {
		::CanvasDraw::DragMoveCurrent %W [%W canvasx %x] [%W canvasy %y] shift
	    }
	    
	    $wcan bind tbbox&&(oval||rectangle) <Button-1> {
		::CanvasDraw::InitMoveRectPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wcan bind tbbox&&(oval||rectangle) <B1-Motion> {
		::CanvasDraw::DragMoveRectPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wcan bind tbbox&&(oval||rectangle) <ButtonRelease-1> {
		::CanvasDraw::FinalMoveRectPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wcan bind tbbox&&(oval||rectangle) <Shift-B1-Motion> {
		::CanvasDraw::DragMoveRectPoint %W [%W canvasx %x] [%W canvasy %y] shift
	    }
	    
	    $wcan bind tbbox&&(line||polygon) <Button-1> {
		::CanvasDraw::InitMovePolyLinePoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wcan bind tbbox&&(line||polygon) <B1-Motion> {
		::CanvasDraw::DragMovePolyLinePoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wcan bind tbbox&&(line||polygon) <ButtonRelease-1> {
		::CanvasDraw::FinalMovePolyLinePoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wcan bind tbbox&&(line||polygon) <Shift-B1-Motion> {
		::CanvasDraw::DragMovePolyLinePoint %W [%W canvasx %x] [%W canvasy %y] shift
	    }
	    
	    $wcan bind tbbox&&arc <Button-1> {
		::CanvasDraw::InitMoveArcPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wcan bind tbbox&&arc <B1-Motion> {
		::CanvasDraw::DragMoveArcPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wcan bind tbbox&&arc <ButtonRelease-1> {
		::CanvasDraw::FinalMoveArcPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wcan bind tbbox&&arc <Shift-B1-Motion> {
		::CanvasDraw::DragMoveArcPoint %W [%W canvasx %x] [%W canvasy %y] shift
	    }
	    
	    $wcan config -cursor fleur
	    SetStatusMessage $w [mc uastatmove]
	}
	line {
	    bindtags $wcan  \
	      [list $wcan WhiteboardLine WhiteboardNonText Whiteboard $w all]
	    SetStatusMessage $w [mc uastatline]
	}
	arrow {
	    bindtags $wcan  \
	      [list $wcan WhiteboardArrow WhiteboardNonText Whiteboard $w all]
	    SetStatusMessage $w [mc uastatarrow]
	}
	rect {
	    bindtags $wcan  \
	      [list $wcan WhiteboardRect WhiteboardNonText Whiteboard $w all]
	    SetStatusMessage $w [mc uastatrect]
	}
	oval {
	    bindtags $wcan  \
	      [list $wcan WhiteboardOval WhiteboardNonText Whiteboard $w all]
	    SetStatusMessage $w [mc uastatoval]
	}
	text {
	    bindtags $wcan  \
	      [list $wcan WhiteboardText Whiteboard $w all]
	    ::CanvasText::EditBind $wcan
	    $wcan config -cursor xterm
	    SetStatusMessage $w [mc uastattext]
	}
	del {
	    bindtags $wcan  \
	      [list $wcan WhiteboardDel WhiteboardNonText Whiteboard $w all]
	    $wcan bind std&&!locked <Button-1> {
		::CanvasDraw::DeleteCurrent %W
	    }
	}
	pen {
	    bindtags $wcan  \
	      [list $wcan WhiteboardPen WhiteboardNonText Whiteboard $w all]
	    $wcan config -cursor pencil
	    SetStatusMessage $w [mc uastatpen]
	}
	brush {
	    bindtags $wcan  \
	      [list $wcan WhiteboardBrush WhiteboardNonText Whiteboard $w all]
	    SetStatusMessage $w [mc uastatbrush]
	}
	paint {
	    bindtags $wcan  \
	      [list $wcan WhiteboardPaint WhiteboardNonText Whiteboard $w all]
	    SetStatusMessage $w [mc uastatpaint]	      
	}
	poly {
	    bindtags $wcan  \
	      [list $wcan WhiteboardPoly WhiteboardNonText Whiteboard $w all]
	    SetStatusMessage $w [mc uastatpoly]	      
	}       
	arc {
	    bindtags $wcan  \
	      [list $wcan WhiteboardArc WhiteboardNonText Whiteboard $w all]
	    SetStatusMessage $w [mc uastatarc]	      
	}
	rot {
	    bindtags $wcan  \
	      [list $wcan WhiteboardRot WhiteboardNonText Whiteboard $w all]
	    $wcan config -cursor exchange
	    SetStatusMessage $w [mc uastatrot]	      
	}
    }
    
    # Collect all common non textual bindings in one procedure.
    if {$btName ne "text"} {
	GenericNonTextBindings $w
    }
}

# WB::SetFrameItemBinds --
#
#       Binding to canvas windows (QTFrame) must be made specifically for each
#       whiteboard instance.
#       Needed in two situations:
#       1) Clicking tool button
#       2) When whiteboard gets focus
#       
# Arguments:
#       w           toplevel widget path
#       btName 
#       
# Results:
#       none

proc ::WB::SetFrameItemBinds {w btName} {
    global  this
    upvar ::WB::${w}::wapp wapp
    
    set wcan $wapp(can)
    
    bind QTFrame <Button-1> {}
    bind QTFrame <B1-Motion> {}
    bind QTFrame <ButtonRelease-1> {}
    bind QTFrame <Shift-B1-Motion> {}
    bind SnackFrame <Button-1> {}
    bind SnackFrame <B1-Motion> {}
    bind SnackFrame <ButtonRelease-1> {}
    bind SnackFrame <Shift-B1-Motion> {}

    bind QTFrame <<ButtonPopup>> {
	::CanvasUtils::DoQuickTimePopup %W %X %Y 
    }
    bind SnackFrame <<ButtonPopup>> {
	::CanvasUtils::DoWindowPopup %W %X %Y 
    }
    
    switch -- $btName {
	point {

	    switch -- $this(platform) {
		macintosh - macosx {
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
		}
	    }
	}
	move {
	    
	    # Need to substitute $wcan.
	    bind QTFrame <Button-1>  \
	      [subst {::CanvasDraw::InitMoveFrame $wcan %W %x %y}]
	    bind QTFrame <B1-Motion>  \
	      [subst {::CanvasDraw::DoMoveFrame $wcan %W %x %y}]
	    bind QTFrame <ButtonRelease-1>  \
	      [subst {::CanvasDraw::FinMoveFrame $wcan %W %x %y}]
	    bind QTFrame <Shift-B1-Motion>  \
	      [subst {::CanvasDraw::FinMoveFrame $wcan %W %x %y}]
	    
	    bind SnackFrame <Button-1>  \
	      [subst {::CanvasDraw::InitMoveFrame $wcan %W %x %y}]
	    bind SnackFrame <B1-Motion>  \
	      [subst {::CanvasDraw::DoMoveFrame $wcan %W %x %y}]
	    bind SnackFrame <ButtonRelease-1>  \
	      [subst {::CanvasDraw::FinMoveFrame $wcan %W %x %y}]
	    bind SnackFrame <Shift-B1-Motion>  \
	      [subst {::CanvasDraw::FinMoveFrame $wcan %W %x %y}]
	}
	del {
	    bind QTFrame <Button-1>  \
	      [subst {::CanvasDraw::DeleteFrame $wcan %W %x %y}]
	    bind SnackFrame <Button-1>  \
	      [subst {::CanvasDraw::DeleteFrame $wcan %W %x %y}]
	    SetStatusMessage $w [mc uastatdel]
	}
    }
}

proc ::WB::GenericNonTextBindings {w} {
    
    upvar ::WB::${w}::wapp wapp
    set wcan $wapp(can)
    
    # Various bindings.
    bind $wcan <BackSpace> [list ::CanvasDraw::DeleteSelected $wcan]
    bind $wcan <Delete>    [list ::CanvasDraw::DeleteSelected $wcan]
    bind $wcan <Control-d> [list ::CanvasDraw::DeleteSelected $wcan]
}

# WB::RemoveAllBindings --
#
#       Clears all application defined bindings in the canvas.
#       
# Arguments:
#       wcan   the canvas widget.
#       
# Results:
#       none

proc ::WB::RemoveAllBindings {wcan} {
    
    Debug 3 "::WB::RemoveAllBindings wcan=$wcan"
    
    # List all tags that we may bind to.
    foreach btag {
	all  std  std&&locked  std&&!locked  
	text  tbbox&&arc  tbbox&&(oval||rectangle)
    } {
	foreach seq [$wcan bind $btag] {
	    $wcan bind $btag $seq {}
	}
    }
    
    # Seems necessary for the arc item... More?
    bind $wcan <Shift-B1-Motion> {}
	    
    # Remove any text insertion...
    $wcan focus {}
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
	upvar ::WB::${w}::state state
	upvar ::WB::${w}::wapp wapp
	
	::Plugins::SetCanvasBinds $wapp(can) $state(toolPrev) $state(tool)
    }
}

proc ::WB::RegisterCanvasInstBinds {wcan name canvasBindList} {

    set w [winfo toplevel $wcan]
    upvar ::WB::${w}::state state

    # Register the actual bindings.
    ::Plugins::RegisterCanvasInstBinds $wcan $name $canvasBindList
    
    # Must set the bindings for this instance.
    ::Plugins::SetCanvasBinds $wcan $state(toolPrev) $state(tool)
}

# WB::BuildWhiteboardMenus --
#
#       Makes all menus for a toplevel window.
#
# Arguments:
#       w           toplevel widget path
#       
# Results:
#       menu created

proc ::WB::BuildWhiteboardMenus {w} {
    global  this wDlgs prefs dashFull2Short
    
    variable menuDefs
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::state state
    upvar ::WB::${w}::opts opts
    
    ::Debug 2 "::WB::BuildWhiteboardMenus"
	
    set wcan      $wapp(can)
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
	::UI::BuildAppleMenu $w $wmenu.apple $opts(-state)
    }
    ::UI::NewMenu $w $wmenu.file   mFile        $menuDefs(main,file)  $opts(-state)
    ::UI::NewMenu $w $wmenu.edit   mEdit        $menuDefs(main,edit)  $opts(-state)
    ::UI::NewMenu $w $wmenu.prefs  mPreferences $menuDefs(main,prefs) $opts(-state)
    ::UI::NewMenu $w $wmenu.items  mLibrary     $menuDefs(main,items) $opts(-state)
    
    # Plugin menus if any.
    ::UI::BuildPublicMenus $w $wmenu
    
    ::UI::NewMenu $w $wmenu.info mInfo $menuDefs(main,info) $opts(-state)

    # Handle '-state disabled' option. Keep Edit/Copy.
    if {$opts(-state) eq "disabled"} {
	::WB::DisableWhiteboardMenus $wmenu
    }
    
    # Use a function for this to dynamically build this menu if needed.
    ::WB::BuildFontMenu $w $prefs(canvasFonts)    

    $wmenu.edit configure -postcommand  \
      [list ::WB::EditPostCommand $w $wmenu.edit]

    # End menus; place the menubar.
    if {$prefs(haveMenus)} {
	$w configure -menu $wmenu
    } else {
	pack $wmenu -side top -fill x
    }
}

# WB::DisableWhiteboardMenus --
#
#       Handle '-state disabled' option. Sets in a readonly state.

proc ::WB::DisableWhiteboardMenus {wmenu} {
    variable menuSpecPublic
    
    ::UI::MenuDisableAllBut $wmenu.file {
	mNew mCloseWindow mSaveCanvas mPageSetup mPrintCanvas
    }
    ::UI::MenuDisableAllBut $wmenu.edit {mAll}
    $wmenu entryconfigure [mc mPreferences] -state disabled
    $wmenu entryconfigure [mc mLibrary] -state disabled
    $wmenu entryconfigure [mc mInfo] -state disabled
	
    # Handle all 'plugins'.
    foreach wpath $menuSpecPublic(wpaths) {
	set name $menuSpecPublic($wpath,name)
	$wmenu entryconfigure $name -state disabled
    }
}

proc ::WB::CreateShortcutButtonPad {w} {
    variable wbicons
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::opts opts
    upvar ::WB::${w}::state state    
    
    Debug 3 "::WB::CreateShortcutButtonPad"

    set wfrtop  $wapp(frtop)
    set wfron   $wfrtop.on
    set wonbar  $wfrtop.on.barvert
    set wonfr   $wonbar.f
    set woffbar $wfrtop.barhoriz    
    
    frame $wfrtop
    frame $wfron

    # On bar.
    frame $wonbar -bd 1 -relief raised
    ttk::frame $wonbar.f
    ttk::label $wonbar.f.l -compound image -image [::UI::GetIcon mactriangleopen]
    pack  $wonbar.f    -fill both -expand 1
    pack  $wonbar.f.l  -side top
    
    bind  $wonfr <Button-1> [list $wonbar configure -relief sunken]
    bind  $wonfr <ButtonRelease-1>  \
      [list [namespace current]::ConfigShortcutButtonPad $w "off"]	
    bind  $wonfr.l <Button-1> [list $wonbar configure -relief sunken]
    bind  $wonfr.l <ButtonRelease-1>  \
      [list [namespace current]::ConfigShortcutButtonPad $w "off"]
    
    # Off bar.
    label $woffbar -image $wbicons(barhoriz) -relief raised -borderwidth 1
    
    bind $woffbar <Button-1> [list $woffbar configure -relief sunken]
    bind $woffbar <ButtonRelease-1>   \
      [list [namespace current]::ConfigShortcutButtonPad $w "on"]

    pack  $wfrtop -side top -fill x
    pack  $wfron -fill x -side left -expand 1
    pack  $wonbar  -side left -fill y
    
    # Build the actual toolbar.
    BuildToolbar $w
    pack $wapp(tray) -side left -fill both -expand 1
    if {$opts(-state) eq "disabled"} {
	DisableShortcutButtonPad $w
    }
}

# WB::ConfigShortcutButtonPad --
#
#       Switches between 'on' and 'off' state.
#       
# Arguments:
#       w           toplevel widget path
#       what        can be "on", or "off".
#       
# Results:
#       toolbar created, or state toggled.

proc ::WB::ConfigShortcutButtonPad {w what} {
    global  this wDlgs prefs
    
    variable wbicons
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::opts opts
    upvar ::WB::${w}::state state    
    
    Debug 3 "::WB::ConfigShortcutButtonPad what=$what"

    set wfrtop  $wapp(frtop)
    set wfron   $wfrtop.on
    set wonbar  $wfrtop.on.barvert
    set woffbar $wfrtop.barhoriz
    
    wm positionfrom $w user
         
    switch -- $what {
	off {
	    pack forget $wfron
	    $wfrtop configure -bg gray75
	    pack $woffbar -side left -padx 0 -pady 0
	    $wonbar configure -relief raised
	    set state(visToolbar) 0
	}
	on {
	    pack forget $woffbar
	    pack $wfron -fill x -side left -expand 1
	    $woffbar configure -relief raised
	    set state(visToolbar) 1
	}
    }
    
    # New minsize is required.
    after idle ::hooks::run whiteboardSetMinsizeHook $w
}

namespace eval ::WB:: {
    variable extButtonDefs {}
}

# WB::BuildToolbar --
#
#       Build the actual shortcut button pad.

proc ::WB::BuildToolbar {w} {
    global  wDlgs
    variable wbicons
    variable btShortDefs
    variable extButtonDefs
    upvar ::WB::${w}::wapp wapp
    
    set wcan   $wapp(can)
    set wtray  $wapp(tray)
    set h [image height $wbicons(barvert)]

    ::ttoolbar::ttoolbar $wtray -height $h -relief raised -borderwidth 1

    # We need to substitute $wcan, $w etc specific for this wb instance.
    foreach {name cmd} $btShortDefs {
	set icon    [::Theme::GetImage [option get $w ${name}Image {}]]
	set iconDis [::Theme::GetImage [option get $w ${name}DisImage {}]]
	set cmd [subst -nocommands -nobackslashes $cmd]
	set txt [string totitle $name]
	$wtray newbutton $name -text [mc $txt] \
	  -image $icon -disabledimage $iconDis -command $cmd
    }
    
    # Extra buttons from components if any.
    foreach btdef $extButtonDefs {
	foreach {name icon iconDis cmd} $btdef {
	    set cmd [subst -nocommands -nobackslashes $cmd]
	    set txt [string totitle $name]
	    $wtray newbutton $name -text [mc $txt] \
	      -image $icon -disabledimage $iconDis -command $cmd
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

proc ::WB::DisableShortcutButtonPad {w} {
    variable btShortDefs
    upvar ::WB::${w}::wapp wapp

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
#       w           toplevel widget path
#       
# Results:
#       tool buttons created and mapped

proc ::WB::CreateAllButtons {w} {
    global  prefs this
    
    variable btNo2Name 
    variable btName2No
    variable wbicons
    upvar ::WB::${w}::state state
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::opts opts
    
    set wtool $wapp(tool)
    
    for {set icol 0} {$icol <= 1} {incr icol} {
	for {set irow 0} {$irow <= 6} {incr irow} {
	    set name $btNo2Name($irow$icol)
	    set wlabel $wtool.bt$irow$icol
	    
	    ttk::radiobutton $wlabel -style Toolbutton \
	      -variable ::WB::${w}::state(tool) -value $name \
	      -command [list [namespace current]::ToolCmd $w] \
	      -image $wbicons($name)
	    grid  $wlabel  -row $irow -column $icol -padx 0 -pady 0
	    
	    if {[string equal $opts(-state) "disabled"]} {
		$wlabel state {disabled}
	    } else {
		
		# Handle bindings to popup options.
		if {[string match "mac*" $this(platform)]} {
		    bind $wlabel <Button-1>        \
		      [list +[namespace current]::StartTimerToToolPopup $w %W $name]
		    bind $wlabel <ButtonRelease-1> \
		      [namespace current]::StopTimerToToolPopup
		}
		bind $wlabel <<ButtonPopup>> [list [namespace current]::DoToolPopup $w %W $name]
	    }
	}
    }
    
    # Make all popups.
    BuildToolPopups $w
    BuildToolPopupFontMenu $w $prefs(canvasFonts)
    
    # Color selector.
    CreateColorSelector $w 
}

proc ::WB::CreateColorSelector {w} {
    variable wbicons
    upvar ::WB::${w}::state state
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::opts opts
    
    set wtool $wapp(tool)
    set wcolsel $wtool.f.col
    set wfg     $wcolsel.fg
    set wbg1    $wcolsel.bg1
    set wbg2    $wcolsel.bg2
    set wbw     $wcolsel.bw
    set wswap   $wcolsel.swap

    set fg $state(fgCol)
    set bg $state(bgCol)

    # Need an extra frame else place gets misplaced.
    ttk::frame $wtool.f
    ttk::label $wcolsel -compound image -image $wbicons(colorSelector)
    label $wfg   -image $wbicons(bwrect) -bd 0 -width 34 -height 24 -bg $fg
    label $wbg1  -image $wbicons(bwrect) -bd 0 -width 14 -height 12 -bg $bg
    label $wbg2  -image $wbicons(bwrect) -bd 0 -width 34 -height 12 -bg $bg
    ttk::label $wbw   -image $wbicons(colorSelBW)   -width 12 -height 12
    ttk::label $wswap -image $wbicons(colorSelSwap) -width 12 -height 12
    
    # The ttk::label seems to put an extra 2 pixel border. @@@ BAD
    set off 2
    grid  $wtool.f  -  -sticky ew
    pack  $wcolsel  -side top
    place $wfg   -x [expr {6+$off}]  -y [expr {5+$off}]
    place $wbg1  -x [expr {42+$off}] -y [expr {19+$off}]
    place $wbg2  -x [expr {22+$off}] -y [expr {31+$off}]
    place $wbw   -x  4 -y 33
    place $wswap -x 46 -y  3

    if {![string equal $opts(-state) "disabled"]} {
	bind $wfg   <Button-1> [list [namespace current]::ColorSelector $w $fg]
	bind $wbw   <Button-1> [list [namespace current]::ResetColorSelector $w]
	bind $wswap <Button-1> [list [namespace current]::SwitchBgAndFgCol $w]
    }
    set wapp(colSel)    $wfg
    set wapp(colSelBg1) $wbg1
    set wapp(colSelBg2) $wbg2
}

proc ::WB::BuildToolPopups {w} {
    global  prefs
    
    variable menuDefs
    upvar ::WB::${w}::wapp wapp
    
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
	::UI::NewMenu $w $wtool.pop${name} {} $mDef($name) normal
	if {!$prefs(haveDash) && ([lsearch $menuArr($name) dash] >= 0)} {
	    ::UI::MenuMethod $wtool.pop${name} entryconfigure mDash -state disabled
	}
    }
}

# WB::StartTimerToToolPopup, StopTimerToToolPopup, DoToolPopup --
#
#       Some functions to handle the tool popup menu.

proc ::WB::StartTimerToToolPopup {w wbutton name} {
    
    variable toolPopupId
    
    if {[info exists toolPopupId]} {
	catch {after cancel $toolPopupId}
    }
    set toolPopupId [after 1000 \
      [list [namespace current]::DoToolPopup $w $wbutton $name]]
}

proc ::WB::StopTimerToToolPopup { } {
    
    variable toolPopupId

    if {[info exists toolPopupId]} {
	catch {after cancel $toolPopupId}
    }
}

proc ::WB::DoToolPopup {w wbutton name} {
    
    upvar ::WB::${w}::wapp wapp

    set wtool $wapp(tool)
    set wpop $wtool.pop${name}
    if {[winfo exists $wpop]} {
	set x [winfo rootx $w]
	set y [expr [winfo rooty $wbutton] + [winfo height $wbutton]]
	tk_popup $wpop $x $y
    }
}

proc ::WB::SwitchBgAndFgCol {w} {
    
    upvar ::WB::${w}::state state
    upvar ::WB::${w}::wapp wapp

    $wapp(colSel)    configure -bg $state(bgCol)
    $wapp(colSelBg1) configure -bg $state(fgCol)
    $wapp(colSelBg2) configure -bg $state(fgCol)
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

proc ::WB::ColorSelector {w col} {
    
    upvar ::WB::${w}::state state
    upvar ::WB::${w}::wapp wapp

    set col [tk_chooseColor -initialcolor $col]
    if {$col ne ""} {
	set state(fgCol) $col
	$wapp(colSel) configure -bg $state(fgCol)
    }
}

proc ::WB::ResetColorSelector {w} {

    upvar ::WB::${w}::state state
    upvar ::WB::${w}::wapp wapp

    $wapp(colSel)    configure -bg black
    $wapp(colSelBg1) configure -bg white
    $wapp(colSelBg2) configure -bg white
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

proc ::WB::SetBasicMinsize {w} {
    
    eval {wm minsize $w} [GetBasicWhiteboardMinsize $w]
}

# WB::GetBasicWhiteboardMinsize --
# 
#       Computes the minimum width and height of whiteboard including any menu
#       but excluding any custom made entry parts.

proc ::WB::GetBasicWhiteboardMinsize {w} {
    global  this prefs
    
    variable wbicons
    upvar ::WB::${w}::wapp wapp

    # Let the geometry manager finish before getting widget sizes.
    update idletasks
  
    # The min height.
    # If we have a custom made menubar using a frame with labels (embedded).
    if {$prefs(haveMenus)} {
	set hFakeMenu 0
	if {![string match "mac*" $this(platform)]} {
	     set hMenu 1
	     # In 8.4 it seems that .wb1.#wb1#menu is used.
	     set wmenu_ $w.#${w}#menu
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

proc ::WB::SetCanvasSize {w cw ch} {
    global  this
    upvar ::WB::${w}::wapp wapp

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

proc ::WB::GetCanvasSize {w} {
    upvar ::WB::${w}::wapp wapp

    return [list [winfo width $wapp(can)] [winfo height $wapp(can)]]
}

proc ::WB::SetScrollregion {w swidth sheight} {
    upvar ::WB::${w}::wapp wapp

    $wapp(can) configure -scrollregion [list 0 0 $swidth $sheight]
}

# WB::EditPostCommand --
# 
#       Post command for edit menu.
#       
# Arguments:
#       w           toplevel widget path
#       wmenu       the edit menu
#
# Results:

proc ::WB::EditPostCommand {w wmenu} {
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::opts opts
    
    set wfocus [focus]
    set haveFocus 0
    set haveSelection 0
    set normal 0
    if {$opts(-state) eq "normal"} {
	set normal 1
    }
    if {$wfocus ne ""} {
	set wclass [winfo class $wfocus]
	if {[lsearch {Canvas Entry Text TEntry} $wclass] >= 0} {
	    set haveFocus 1
	}
	switch -- $wclass {
	    Entry - TEntry {
		set haveSelection [$wfocus selection present]
	    }
	    Text {
		if {![catch {$wfocus get sel.first sel.last} data]} {
		    if {$data ne ""} {
			set haveSelection 1
		    }
		}
	    }
	    Canvas {
		set wcan $wapp(can)
		if {[$wcan find withtag selected] != {}} {
		    set haveSelection 1
		} elseif {[$wcan select item] != {}} {
		    set haveSelection 1
		}
	    }
	}
    }
    
    # Cut, copy and paste menu entries.
    if {$normal && $haveSelection} {
	::UI::MenuMethod $wmenu entryconfigure mCut  -state normal
	::UI::MenuMethod $wmenu entryconfigure mCopy -state normal    
    } else {
	::UI::MenuMethod $wmenu entryconfigure mCut  -state disabled
	::UI::MenuMethod $wmenu entryconfigure mCopy -state disabled    
    }
    if {[catch {selection get -sel CLIPBOARD} str]} {
	::UI::MenuMethod $wmenu entryconfigure mPaste -state disabled
    } elseif {$normal && $haveFocus && ($str ne "")} {
	::UI::MenuMethod $wmenu entryconfigure mPaste -state normal
    } else {
	::UI::MenuMethod $wmenu entryconfigure mPaste -state disabled
    }
    if {$wclass eq "Canvas"} {
	EditPostCommandCanvas $w $wmenu
    }
    
    # Workaround for mac bug.
    update idletasks
}

# WB::EditPostCommandCanvas --
# 
#       Supposed to set the specific whiteboard edit menu entries.
#       Cut, copy and paste handled elsewhere.

proc ::WB::EditPostCommandCanvas {w wmenu} {
    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::opts opts

    set wcan $wapp(can)
    set normal 0
    if {$opts(-state) eq "normal"} {
	set normal 1
    }
    set selected [$wcan find withtag selected]
    set len [llength $selected]
    set haveFlip 0
    set haveImage 0
    set haveText 0
    set haveResize 1
    set flip 0
    set resize 0
    set resizeImage 0
    
    foreach id $selected {
	switch -- [$wcan type $id] {
	    line - polygon {
		set haveFlip 1
		set haveResize 1
	    }
	    rectangle - oval {
		set haveResize 1
	    }
	    image {
		set haveImage 1
	    }
	    text {
		set haveText 1
	    }
	}
    }
    if {$len == 1} {
	if {$haveImage} {
	    set resizeImage 1
	}
	if {$haveFlip} {
	    set flip 1
	}
    }
    if {$haveResize && !$haveImage && !$haveText} {
	set resize 1
    }
    #puts "len=$len, haveFlip=$haveFlip, haveImage=$haveImage, haveText=$haveText"
    #puts "haveResize=$haveResize, flip=$flip, resize=$resize, resizeImage=$resizeImage,"

    if {!$len || !$normal} {
	
	# There is no selection in the canvas or whiteboard disabled.
	::UI::MenuMethod $wmenu entryconfigure mInspectItem -state disabled
	::UI::MenuMethod $wmenu entryconfigure mRaise -state disabled
	::UI::MenuMethod $wmenu entryconfigure mLower -state disabled
	::UI::MenuMethod $wmenu entryconfigure mLarger -state disabled
	::UI::MenuMethod $wmenu entryconfigure mSmaller -state disabled
	::UI::MenuMethod $wmenu entryconfigure mFlip -state disabled
	::UI::MenuMethod $wmenu entryconfigure mImageLarger -state disabled
	::UI::MenuMethod $wmenu entryconfigure mImageSmaller -state disabled    
    } else {	
	::UI::MenuMethod $wmenu entryconfigure mInspectItem -state normal
	::UI::MenuMethod $wmenu entryconfigure mRaise -state normal
	::UI::MenuMethod $wmenu entryconfigure mLower -state normal
	if {$flip} {
	    ::UI::MenuMethod $wmenu entryconfigure mFlip -state normal
	} else {
	    ::UI::MenuMethod $wmenu entryconfigure mFlip -state disabled
	}
	if {$resizeImage} {
	    ::UI::MenuMethod $wmenu entryconfigure mImageLarger -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mImageSmaller -state normal
	} else {
	    ::UI::MenuMethod $wmenu entryconfigure mImageLarger -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mImageSmaller -state disabled
	}	
	if {$resize} {
	    ::UI::MenuMethod $wmenu entryconfigure mLarger -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mSmaller -state normal
	} else {
	    ::UI::MenuMethod $wmenu entryconfigure mLarger -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mSmaller -state disabled
	}
    }
}

# WB::GetFocus --
#
#       Check clipboard and activate corresponding menus.    
#       
# Results:
#       updates state of menus.

proc ::WB::GetFocus {w wevent} {
    
    upvar ::WB::${w}::opts opts
    upvar ::WB::${w}::wapp wapp

    # Bind to toplevel may fire multiple times.
    if {$w != $wevent} {
	return
    }
    Debug 3 "GetFocus:: w=$w, wevent=$wevent"
    
    SetFrameItemBinds $w [GetButtonState $w]
}

# WB::FixMenusWhenCopy --     OBSOLETE ???
# 
#       Sets the correct state for menus and buttons when copy something.
#       
# Arguments:
#       wevent    the widget that contains something that is copied.
#
# Results:

proc ::WB::FixMenusWhenCopy {wevent} {

    set w [winfo toplevel $wevent]
    upvar ::WB::${w}::opts opts
    
    if {0} {
	if {$opts(-state) eq "normal"} {
	    ::UI::MenuMethod $w.menu.edit entryconfigure mPaste -state normal
	} else {
	    ::UI::MenuMethod $w.menu.edit entryconfigure mPaste -state disabled
	}
    }
        
    ::hooks::run whiteboardFixMenusWhenHook $w "copy"
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
	    set cmd {::CanvasFile::DrawCanvasItemFromFile $w}
	    lappend cmd $f
	    lappend mdef [list command $name $cmd normal {}]
	}
    }
    return $mdef
}

proc ::WB::AddItemMenu {dir} {
    
    set mdef {}
    foreach f [glob -nocomplain -directory $dir *] {
	
	# Sort out directories we shouldn't search.
	switch -- [string tolower [file tail $f]] {
	    . - resource.frk - cvs {
		continue
	    }
	}
	if {[file isdirectory $f]} {
	    set submdef [AddItemMenu $f]
	    set name [file tail $f]
	    if {[llength $submdef]} {
		lappend mdef [list cascade $name {} normal {} {} $submdef]
	    }
	} elseif {[string equal [file extension $f] ".can"]} {
	    set name [file rootname [file tail $f]]
	    set cmd {::CanvasFile::DrawCanvasItemFromFile $w}
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

proc ::WB::BuildFontMenu {w allFonts} {
    
    set mt $w.menu.prefs.mfont
    
    $mt delete 0 end
    foreach afont $allFonts {
	$mt add radio -label $afont -variable ::WB::${w}::state(font)  \
	  -command [list ::WB::FontChanged $w name]
    }
    
    # Be sure that the presently selected font family is still there,
    # else choose helvetica.
    set fontStateVar ::WB::${w}::state(font)
    if {[lsearch -exact $allFonts $fontStateVar] == -1} {
	set ::WB::${w}::state(font) {Helvetica}
    }
}

proc ::WB::BuildToolPopupFontMenu {w allFonts} {
    upvar ::WB::${w}::wapp wapp
    
    set wtool $wapp(tool)
    set mt $wtool.poptext.mfont
    
    $mt delete 0 end
    foreach afont $allFonts {
	$mt add radio -label $afont -variable ::WB::${w}::state(font)  \
	  -command [list ::WB::FontChanged $w name]
    }
}

proc ::WB::BuildAllFontMenus {allFonts} {

    # Must do this for all open whiteboards!
    foreach w [GetAllWhiteboards] {
	BuildFontMenu $w $allFonts
	BuildToolPopupFontMenu $w $allFonts
    }
}

# WB::FontChanged --
# 
#       Callback procedure for the font menu. When new font name, size or weight,
#       and we have focus on a text item, change the font spec of this item.
#
# Arguments:
#       w           toplevel widget path
#       what        name, size or weight
#       
# Results:
#       updates text item, sends to all clients.

proc ::WB::FontChanged {w what} {
    global  fontSize2Points fontPoints2Size

    upvar ::WB::${w}::wapp wapp
    upvar ::WB::${w}::state state
    
    set wcan $wapp(can)

    # If there is a focus on a text item, change the font for this item.
    set idfocus [$wcan focus]
    
    if {[string length $idfocus] > 0} {
	set theItno [::CanvasUtils::GetUtag $wcan focus]
	if {[string length $theItno] == 0} {
	    return
	}
	if {[$wcan type $theItno] ne "text"} {
	    return
	}
	set fontSpec [$wcan itemcget $theItno -font]
	if {[llength $fontSpec] > 0} {
	    array set whatToInd {name 0 size 1 weight 2}
	    array set whatToPref {name font size fontSize weight fontWeight}
	    set ind $whatToInd($what)

	    # Need to translate html size to point size.
	    if {$what eq "size"} {
		set newFontSpec [lreplace $fontSpec $ind $ind  \
		  $fontSize2Points($state($whatToPref($what)))]
	    } else {
		set newFontSpec [lreplace $fontSpec $ind $ind  \
		  $state($whatToPref($what))]
	    }
	    ::CanvasUtils::ItemConfigure $wcan $theItno -font $newFontSpec
	}
    }
}

proc ::WB::StartStopAnimatedWave {w start} {
    upvar ::WB::${w}::wapp wapp
    
    
    #set waveImage [::Theme::GetImage [option get $w waveImage {}]]  
    #::UI::StartStopAnimatedWave $wapp(statmess) $waveImage $start
}

proc ::WB::StartStopAnimatedWaveOnMain {start} {
    global  wDlgs
    
    set w [::P2P::GetMainWindow]
    upvar ::WB::${w}::wapp wapp
    
    #set waveImage [::Theme::GetImage [option get $w waveImage {}]]  
    #::UI::StartStopAnimatedWave $wapp(statmess) $waveImage $start
}

# WB::CreateBrokenImage --
# 
#       Creates an actual image with the broken symbol that matches
#       up the width and height. The image is garbage collected.

proc ::WB::CreateBrokenImage {wcan width height} {
    variable icons
    
    set w [winfo toplevel $wcan]
    upvar ::WB::${w}::canvasImages canvasImages
    
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

proc ::WB::DnDDrop {wcan data type x y} {
    global  prefs
    
    ::Debug 2 "::WB::DnDDrop data=$data, type=$type"

    set w [winfo toplevel $wcan]

    foreach f $data {
	
	# Strip off any file:// prefix.
	set f [string map {file:// ""} $f]
	set f [uriencode::decodefile $f]
	
	# Allow also .can files to be dropped.
	if {[file extension $f] eq ".can"} {
	    ::CanvasFile::DrawCanvasItemFromFile $w $f
	} else {
	    set mime [::Types::GetMimeTypeForFileName $f]
	    set haveImporter [::Plugins::HaveImporterForMime $mime]
	    if {$haveImporter} {
		set opts [list -coords [list $x $y]]
		set errMsg [::Import::DoImport $wcan $opts -file $f]
		if {$errMsg ne ""} {
		    ::UI::MessageBox -title [mc Error] -icon error -type ok \
		      -message "Failed importing: $errMsg" -parent $w
		}
		incr x $prefs(offsetCopy)
		incr y $prefs(offsetCopy)
	    } else {
		::UI::MessageBox -title [mc Error] -icon error -type ok \
		  -message [mc messfailmimeimp $mime] -parent $w
	    }
	}
    }
}

proc ::WB::DnDEnter {wcan action data type} {
    
    ::Debug 2 "::WB::DnDEnter action=$action, data=$data, type=$type"

    set act "none"
    foreach f $data {
	if {[file extension $f] eq ".can"} {
	    set haveImporter 1
	} else {
	    
	    # Require at least one file importable.
	    set haveImporter [::Plugins::HaveImporterForMime  \
	      [::Types::GetMimeTypeForFileName $f]]
	}
	if {$haveImporter} {
	    focus $wcan
	    set act $action
	    break
	}
    }
    return $act
}

proc ::WB::DnDLeave {wcan data type} {
    
    focus [winfo toplevel $wcan] 
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

proc ::WB::SendMessageList {w cmdList args} {
    
    eval {::hooks::run whiteboardSendMessageHook $w $cmdList} $args
}

# ::WB::SendGenMessageList --
# 
#       Invokes any registered send message hook. 
#       The commands in the cmdList may include any prefix.
#       The prefix shall be included in commands of the cmdList.
#       @@@ THIS IS ACTUALLY A BAD SOLUTION AND SHALL BE REMOVED LATER!!!

proc ::WB::SendGenMessageList {w cmdList args} {
    
    eval {::hooks::run whiteboardSendGenMessageHook $w $cmdList} $args
}

# ::WB::PutFile --
# 
#       Invokes any registered hook for putting a file. This is only called
#       when we want to do p2p file transports (put/get).

proc ::WB::PutFile {w fileName opts args} {
    
    eval {::hooks::run whiteboardPutFileHook $w $fileName $opts} $args
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

