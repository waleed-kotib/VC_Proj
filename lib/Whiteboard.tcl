#  Whiteboard.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements the actual whiteboard.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Whiteboard.tcl,v 1.3 2003-12-19 15:47:40 matben Exp $

package require entrycomp
package require CanvasDraw
package require CanvasText
package require CanvasUtils
package require CanvasCutCopyPaste

package provide Whiteboard 1.0

namespace eval ::WB:: {
    global  wDlgs
    
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
    
    # Add all event hooks.
    hooks::add quitAppHook [list ::UI::SaveWinPrefixGeom $wDlgs(wb) whiteboard]
    hooks::add quitAppHook ::WB::SaveAnyState
    
    # Keeps various geometry info.
    variable dims
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
        
    # Addon stuff.
    variable fixMenusCallback {}
    variable menuSpecPublic
    set menuSpecPublic(wpaths) {}
    
    variable iconsInitted 0
}

# WB::Init --
# 
#       Various initializations for the UI stuff.

proc ::WB::Init {} {
    global  this prefs
    variable wbicons
    
    ::Debug 2 "::WB::Init"
    
    # Init canvas utils.
    ::CanvasUtils::Init

    # For the communication entries.
    # variables:              $wtop is used as a key in these vars.
    #       nEnt              a running counter for the communication frame entries
    #                         that is *never* reused.
    #       ipNum2iEntry:     maps ip number to the entry line (nEnt) in the connect 
    #                         panel.
    #       thisType          protocol
    variable nEnt
    variable ipNum2iEntry
    variable commTo
    variable commFrom
    variable thisType

    variable animateWave
    
    # Defines canvas binding tags suitable for each tool.
    ::CanvasUtils::DefineWhiteboardBindtags
    
    variable dashFull2Short
    variable dashShort2Full
    array set dashFull2Short {
	none " " dotted . dash-dotted -. dashed -
    }
    array set dashShort2Full {
	" " none . dotted -. dash-dotted - dashed
    }
    set dashShort2Full() none
    
    # Shortcut button names. Delayed substitution of $wtop etc.
    # Commands may be modified due to platform and prefs.
    variable btShortDefs
    set btShortDefs(jabber) {
	save       {::CanvasFile::DoSaveCanvasFile $wtop}
	open       {::CanvasFile::DoOpenCanvasFile $wtop}
	import     {::Import::ImportImageOrMovieDlg $wtop}
	send       {::Jabber::DoSendCanvas $wtop}
	print      {::UserActions::DoPrintCanvas $wtop}
	stop       {::UserActions::CancelAllPutGetAndPendingOpen $wtop}
    }
    set btShortDefs(symmetric) {
	connect    {::OpenConnection::OpenConnection $wDlgs(openConn)}
	save       {::CanvasFile::DoSaveCanvasFile $wtop}
	open       {::CanvasFile::DoOpenCanvasFile $wtop}
	import     {::Import::ImportImageOrMovieDlg $wtop}
	send       {::UserActions::DoSendCanvas $wtop}
	print      {::UserActions::DoPrintCanvas $wtop}
	stop       {::UserActions::CancelAllPutGetAndPendingOpen $wtop}
    }
    set btShortDefs(client) $btShortDefs(symmetric)
    set btShortDefs(server) $btShortDefs(symmetric)
    set btShortDefs(this)   $btShortDefs($prefs(protocol))   
}

# WB::InitIcons --
# 
#       Get all standard icons using the option database with the
#       preloaded icons as fallback.

proc ::WB::InitIcons {w} {
    
    variable iconsInitted 1
    variable btNo2Name 
    variable wbicons
    
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
    set wbicons(imcolor)  [::WB::GetThemeImage [option get $w imcolorImage {}]]
    set wbicons(bwrect)   [::WB::GetThemeImage [option get $w bwrectImage {}]]
}

# WB::InitMenuDefs --
# 
#       The menu organization.

proc ::WB::InitMenuDefs { } {
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

    set menuDefsMainFileJabber {
	{command   mNew                {::WB::NewWhiteboard -sendcheckstate disabled}   normal   N}
	{command   mCloseWindow        {::UserActions::DoCloseWindow}             normal   W}
	{separator}
	{command   mOpenImage/Movie    {::Import::ImportImageOrMovieDlg $wtop}    normal   I}
	{command   mOpenURLStream      {::OpenMulticast::OpenMulticast $wtop}     normal   {}}
	{command   mStopPut/Get/Open   {::UserActions::CancelAllPutGetAndPendingOpen $wtop} normal {}}
	{separator}
	{command   mOpenCanvas         {::CanvasFile::DoOpenCanvasFile $wtop}     normal   {}}
	{command   mSaveCanvas         {::CanvasFile::DoSaveCanvasFile $wtop}     normal   S}
	{separator}
	{command   mSaveAs             {::UserActions::SavePostscript $wtop}      normal   {}}
	{command   mPageSetup          {::UserActions::PageSetup $wtop}           normal   {}}
	{command   mPrintCanvas        {::UserActions::DoPrintCanvas $wtop}       normal   P}
	{separator}
	{command   mQuit               {::UserActions::DoQuit}                    normal   Q}
    }
    if {![::Plugins::HavePackage QuickTimeTcl]} {
	lset menuDefsMainFileJabber 4 3 disabled
    }
    set menuDefsMainFileP2P {
	{command   mOpenConnection     {::UserActions::DoConnect}                 normal   O}
	{command   mCloseWindow        {::UserActions::DoCloseWindow}             normal   W}
	{separator}
	{command   mOpenImage/Movie    {::Import::ImportImageOrMovieDlg $wtop} normal  I}
	{command   mOpenURLStream      {::OpenMulticast::OpenMulticast $wtop}     normal   {}}
	{separator}
	{command   mPutCanvas          {::UserActions::DoPutCanvasDlg $wtop}      disabled {}}
	{command   mGetCanvas          {::UserActions::DoGetCanvas $wtop}         disabled {}}
	{command   mPutFile            {::PutFileIface::PutFileDlg $wtop}         disabled {}}
	{command   mStopPut/Get/Open   {::UserActions::CancelAllPutGetAndPendingOpen $wtop} normal {}}
	{separator}
	{command   mOpenCanvas         {::CanvasFile::DoOpenCanvasFile $wtop}     normal   {}}
	{command   mSaveCanvas         {::CanvasFile::DoSaveCanvasFile $wtop}     normal   S}
	{separator}
	{command   mSaveAs             {::UserActions::SavePostscript $wtop}      normal   {}}
	{command   mPageSetup          {::UserActions::PageSetup $wtop}           normal   {}}
	{command   mPrintCanvas        {::UserActions::DoPrintCanvas $wtop}       normal   P}
	{separator}
	{command   mQuit               {::UserActions::DoQuit}                    normal   Q}
    }
    if {![::Plugins::HavePackage QuickTimeTcl]} {
	lset menuDefsMainFileP2P 4 3 disabled
    }
    if {[string equal $prefs(protocol) "jabber"]} {
	set menuDefs(main,file) $menuDefsMainFileJabber
    } else {
	set menuDefs(main,file) $menuDefsMainFileP2P
    }
	    
    # If embedded the embedding app should close us down.
    if {$prefs(embedded)} {
	lset menuDefs(main,file) end 3 disabled
    }

    set menuDefs(main,edit) {    
	{command     mUndo             {::UserActions::Undo $wtop}             normal   Z}
	{command     mRedo             {::UserActions::Redo $wtop}             normal   {}}
	{separator}
	{command     mCut              {::UI::CutCopyPasteCmd cut}             disabled X}
	{command     mCopy             {::UI::CutCopyPasteCmd copy}            disabled C}
	{command     mPaste            {::UI::CutCopyPasteCmd paste}           disabled V}
	{command     mAll              {::UserActions::SelectAll $wtop}        normal   A}
	{command     mEraseAll         {::UserActions::DoEraseAll $wtop}       normal   {}}
	{separator}
	{command     mInspectItem      {::ItemInspector::ItemInspector $wtop selected} disabled {}}
	{separator}
	{command     mRaise            {::UserActions::RaiseOrLowerItems $wtop raise} disabled R}
	{command     mLower            {::UserActions::RaiseOrLowerItems $wtop lower} disabled L}
	{separator}
	{command     mLarger           {::UserActions::ResizeItem $wtop $prefs(scaleFactor)} disabled >}
	{command     mSmaller          {::UserActions::ResizeItem $wtop $prefs(invScaleFac)} disabled <}
	{cascade     mFlip             {}                                      disabled {} {} {
	    {command   mHorizontal     {::UserActions::FlipItem $wtop horizontal}  normal   {} {}}
	    {command   mVertical       {::UserActions::FlipItem $wtop vertical}    normal   {} {}}}
	}
	{command     mImageLarger      {::Import::ResizeImage $wtop 2 sel auto} disabled {}}
	{command     mImageSmaller     {::Import::ResizeImage $wtop -2 sel auto} disabled {}}
    }
    
    # These are used not only in the drop-down menus.
    set menuDefs(main,prefs,separator) 	{separator}
    set menuDefs(main,prefs,background)  \
      {command     mBackgroundColor      {::UserActions::SetCanvasBgColor $wtop} normal   {}}
    set menuDefs(main,prefs,grid)  \
      {checkbutton mGrid             {::UserActions::DoCanvasGrid $wtop}   normal   {} \
      {-variable ::${wtop}::state(canGridOn)}}
    set menuDefs(main,prefs,thickness)  \
      {cascade     mThickness        {}                                    normal   {} {} {
	{radio   1                 {}                                      normal   {} \
	  {-variable ::${wtop}::state(penThick)}}
	{radio   2                 {}                                      normal   {} \
	  {-variable ::${wtop}::state(penThick)}}
	{radio   4                 {}                                      normal   {} \
	  {-variable ::${wtop}::state(penThick)}}
	{radio   6                 {}                                      normal   {} \
	  {-variable ::${wtop}::state(penThick)}}}
    }
    set menuDefs(main,prefs,brushthickness)  \
      {cascade     mBrushThickness   {}                                    normal   {} {} {
	{radio   8                 {}                                      normal   {} \
	  {-variable ::${wtop}::state(brushThick)}}
	{radio   10                {}                                      normal   {} \
	  {-variable ::${wtop}::state(brushThick)}}
	{radio   12                {}                                      normal   {} \
	  {-variable ::${wtop}::state(brushThick)}}
	{radio   16                {}                                      normal   {} \
	  {-variable ::${wtop}::state(brushThick)}}}
    }
    set menuDefs(main,prefs,fill)  \
      {checkbutton mFill             {}                                    normal   {} \
      {-variable ::${wtop}::state(fill)}}
    set menuDefs(main,prefs,smoothness)  \
      {cascade     mLineSmoothness   {}                                    normal   {} {} {
	{radio   None              {set ::${wtop}::state(smooth) 0}        normal   {} \
	  {-value 0 -variable ::${wtop}::state(splinesteps)}}
	{radio   2                 {set ::${wtop}::state(smooth) 1}        normal   {} \
	  {-value 2 -variable ::${wtop}::state(splinesteps)}}
	{radio   4                 {set ::${wtop}::state(smooth) 1}        normal   {} \
	  {-value 4 -variable ::${wtop}::state(splinesteps)}}
	{radio   6                 {set ::${wtop}::state(smooth) 1}        normal   {} \
	  {-value 6 -variable ::${wtop}::state(splinesteps)}}
	{radio   10                {set ::${wtop}::state(smooth) 1}        normal   {} \
	  {-value 10 -variable ::${wtop}::state(splinesteps)}}}
    }
    set menuDefs(main,prefs,smooth)  \
      {checkbutton mLineSmoothness   {}                                    normal   {} \
      {-variable ::${wtop}::state(smooth)}}
    set menuDefs(main,prefs,arcs)  \
      {cascade     mArcs             {}                                    normal   {} {} {
	{radio   mPieslice         {}                                      normal   {} \
	  {-value pieslice -variable ::${wtop}::state(arcstyle)}}
	{radio   mChord            {}                                      normal   {} \
	  {-value chord -variable ::${wtop}::state(arcstyle)}}
	{radio   mArc              {}                                      normal   {} \
	  {-value arc -variable ::${wtop}::state(arcstyle)}}}
    }
    
    # Dashes need a special build process. Be sure not to substitute $wtop.
    set dashList {}
    foreach dash [lsort -decreasing [array names ::WB::dashFull2Short]] {
	set dashval $::WB::dashFull2Short($dash)
	if {[string equal " " $dashval]} {
	    set dopts {-value { } -variable ::${wtop}::state(dash)}
	} else {
	    set dopts [format {-value %s -variable ::${wtop}::state(dash)} $dashval]
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
	  {-variable ::${wtop}::state(fontSize)}}
	{radio   2                 {::WB::FontChanged $wtop size}          normal   {} \
	  {-variable ::${wtop}::state(fontSize)}}
	{radio   3                 {::WB::FontChanged $wtop size}          normal   {} \
	  {-variable ::${wtop}::state(fontSize)}}
	{radio   4                 {::WB::FontChanged $wtop size}          normal   {} \
	  {-variable ::${wtop}::state(fontSize)}}
	{radio   5                 {::WB::FontChanged $wtop size}          normal   {} \
	  {-variable ::${wtop}::state(fontSize)}}
	{radio   6                 {::WB::FontChanged $wtop size}          normal   {} \
	  {-variable ::${wtop}::state(fontSize)}}}
    }
    set menuDefs(main,prefs,fontweight)  \
      {cascade     mWeight           {}                                    normal   {} {} {
	{radio   mNormal           {::WB::FontChanged $wtop weight}        normal   {} \
	  {-value normal -variable ::${wtop}::state(fontWeight)}}
	{radio   mBold             {::WB::FontChanged $wtop weight}        normal   {} \
	  {-value bold -variable ::${wtop}::state(fontWeight)}}
	{radio   mItalic           {::WB::FontChanged $wtop weight}        normal   {} \
	  {-value italic -variable ::${wtop}::state(fontWeight)}}}
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
	{command     mOnServer       {::Dialogs::ShowInfoServer \$this(ipnum)} normal {}}	
	{command     mOnClients      {::Dialogs::ShowInfoClients} disabled {}}	
	{command     mOnPlugins      {::Dialogs::InfoOnPlugins}         normal {}}	
	{separator}
	{cascade     mHelpOn             {}                                    normal   {} {} {}}
    }
    
    # Build "Help On" menu dynamically.
    set infoDefs {}
    foreach f [glob -nocomplain -directory [file join $this(path) docs] *.can] {
	set name [file rootname [file tail $f]]
	lappend infoDefs [list command m${name} [list ::Dialogs::Canvas $f] normal {}]
    }
    lset menuDefs(main,info) end end $infoDefs
    
    # Make platform specific things and special menus etc. Indices!!! BAD!
    if {$haveAppleMenu && ![::Plugins::HavePackage QuickTimeTcl]} {
	lset menuDefs(main,apple) 1 3 disabled
    }
    if {!$prefs(haveDash)} {
	lset menuDefs(main,prefs) 7 3 disabled
    }
    if {!$haveAppleMenu} {
	lappend menuDefs(main,info) $menuDefs(main,info,aboutwhiteboard)
    }
    if {!$haveAppleMenu && [::Plugins::HavePackage QuickTimeTcl]} {
	lappend menuDefs(main,info) $menuDefs(main,info,aboutquicktimetcl)
    }
	
    # Menu definitions for a minimal setup. Used on mac only.
    set menuDefs(min,file) {
	{command   mNewWhiteboard    {::WB::NewWhiteboard}                       normal   N}
	{command   mCloseWindow      {::UserActions::DoCloseWindow}        normal   W}
	{separator}
	{command   mQuit             {::UserActions::DoQuit}               normal   Q}
    }	    
    set menuDefs(min,edit) {    
	{command   mCut              {::UI::CutCopyPasteCmd cut}           disabled X}
	{command   mCopy             {::UI::CutCopyPasteCmd copy}          disabled C}
	{command   mPaste            {::UI::CutCopyPasteCmd paste}         disabled V}
    }
    
    # Popup menu definitions for the canvas. First definitions of individual entries.
    set menuDefs(pop,thickness)  \
      {cascade     mThickness     {}                                       normal   {} {} {
	{radio   1 {::CanvasUtils::ItemConfigure $w $id -width 1}          normal   {} \
	  {-variable ::WB::popupVars(-width)}}
	{radio   2 {::CanvasUtils::ItemConfigure $w $id -width 2}          normal   {} \
	  {-variable ::WB::popupVars(-width)}}
	{radio   4 {::CanvasUtils::ItemConfigure $w $id -width 4}          normal   {} \
	  {-variable ::WB::popupVars(-width)}}
	{radio   6 {::CanvasUtils::ItemConfigure $w $id -width 6}          normal   {} \
	  {-variable ::WB::popupVars(-width)}}}
    }
    set menuDefs(pop,brushthickness)  \
      {cascade     mBrushThickness  {}                                     normal   {} {} {
	{radio   8 {::CanvasUtils::ItemConfigure $w $id -width 8}          normal   {} \
	  {-variable ::WB::popupVars(-brushwidth)}}
	{radio  10 {::CanvasUtils::ItemConfigure $w $id -width 10}         normal   {} \
	  {-variable ::WB::popupVars(-brushwidth)}}
	{radio  12 {::CanvasUtils::ItemConfigure $w $id -width 12}         normal   {} \
	  {-variable ::WB::popupVars(-brushwidth)}}
	{radio  14 {::CanvasUtils::ItemConfigure $w $id -width 14}         normal   {} \
	  {-variable ::WB::popupVars(-brushwidth)}}}
    }
    set menuDefs(pop,arcs)  \
      {cascade   mArcs             {}                                      normal   {} {} {
	{radio   mPieslice         {}                                      normal   {} \
	  {-value pieslice -variable ::WB::popupVars(-arc)}}
	{radio   mChord            {}                                      normal   {} \
	  {-value chord -variable ::WB::popupVars(-arc)}}
	{radio   mArc              {}                                      normal   {} \
	  {-value arc -variable ::WB::popupVars(-arc)}}}
    }
    set menuDefs(pop,color)  \
      {command   mColor        {::CanvasUtils::SetItemColorDialog $w $id -fill}  normal {}}
    set menuDefs(pop,fillcolor)  \
      {command   mFillColor    {::CanvasUtils::SetItemColorDialog $w $id -fill}  normal {}}
    set menuDefs(pop,outline)  \
      {command   mOutlineColor {::CanvasUtils::SetItemColorDialog $w $id -outline}  normal {}}
    set menuDefs(pop,inspect)  \
      {command   mInspectItem  {::ItemInspector::ItemInspector $wtop $id}   normal {}}
    set menuDefs(pop,inspectqt)  \
      {command   mInspectItem  {::ItemInspector::Movie $wtop $winfr}        normal {}}
    set menuDefs(pop,saveimageas)  \
      {command   mSaveImageAs  {::Import::SaveImageAsFile $w $id}    normal {}}
    set menuDefs(pop,imagelarger)  \
      {command   mImageLarger  {::Import::ResizeImage $wtop 2 $id auto}   normal {}}
    set menuDefs(pop,imagesmaller)  \
      {command   mImageSmaller {::Import::ResizeImage $wtop -2 $id auto}   normal {}}
    set menuDefs(pop,exportimage)  \
      {command   mExportImage  {::Import::ExportImageAsFile $w $id}  normal {}}
    set menuDefs(pop,exportmovie)  \
      {command   mExportMovie  {::Import::ExportMovie $wtop $winfr}  normal {}}
    set menuDefs(pop,inspectbroken)  \
      {command   mInspectItem  {::ItemInspector::Broken $wtop $id}          normal {}}
    set menuDefs(pop,reloadimage)  \
      {command   mReloadImage  {::Import::ReloadImage $wtop $id}     normal {}}
    set menuDefs(pop,smoothness)  \
      {cascade     mLineSmoothness   {}                                    normal   {} {} {
	{radio None {::CanvasUtils::ItemConfigure $w $id -smooth 0 -splinesteps  0} normal {} \
	  {-value 0 -variable ::WB::popupVars(-smooth)}}
	{radio 2    {::CanvasUtils::ItemConfigure $w $id -smooth 1 -splinesteps  2} normal {} \
	  {-value 2 -variable ::WB::popupVars(-smooth)}}
	{radio 4    {::CanvasUtils::ItemConfigure $w $id -smooth 1 -splinesteps  4} normal {} \
	  {-value 4 -variable ::WB::popupVars(-smooth)}}
	{radio 6    {::CanvasUtils::ItemConfigure $w $id -smooth 1 -splinesteps  6} normal {} \
	  {-value 6 -variable ::WB::popupVars(-smooth)}}
	{radio 10   {::CanvasUtils::ItemConfigure $w $id -smooth 1 -splinesteps 10} normal {} \
	  {-value 10 -variable ::WB::popupVars(-smooth)}}}
    }
    set menuDefs(pop,smooth)  \
      {checkbutton mLineSmoothness   {::CanvasUtils::ItemSmooth $w $id}    normal   {} \
      {-variable ::WB::popupVars(-smooth) -offvalue 0 -onvalue 1}}
    set menuDefs(pop,straighten)  \
      {command     mStraighten       {::CanvasUtils::ItemStraighten $w $id} normal   {} {}}
    set menuDefs(pop,font)  \
      {cascade     mFont             {}                                    normal   {} {} {}}
    set menuDefs(pop,fontsize)  \
      {cascade     mSize             {}                                    normal   {} {} {
	{radio   1  {::CanvasUtils::SetTextItemFontSize $w $id 1}          normal   {} \
	  {-variable ::WB::popupVars(-fontsize)}}
	{radio   2  {::CanvasUtils::SetTextItemFontSize $w $id 2}          normal   {} \
	  {-variable ::WB::popupVars(-fontsize)}}
	{radio   3  {::CanvasUtils::SetTextItemFontSize $w $id 3}          normal   {} \
	  {-variable ::WB::popupVars(-fontsize)}}
	{radio   4  {::CanvasUtils::SetTextItemFontSize $w $id 4}          normal   {} \
	  {-variable ::WB::popupVars(-fontsize)}}
	{radio   5  {::CanvasUtils::SetTextItemFontSize $w $id 5}          normal   {} \
	  {-variable ::WB::popupVars(-fontsize)}}
	{radio   6  {::CanvasUtils::SetTextItemFontSize $w $id 6}          normal   {} \
	  {-variable ::WB::popupVars(-fontsize)}}}
    }
    set menuDefs(pop,fontweight)  \
      {cascade     mWeight           {}                                    normal   {} {} {
	{radio   mNormal {::CanvasUtils::SetTextItemFontWeight $w $id normal} normal   {} \
	  {-value normal -variable ::WB::popupVars(-fontweight)}}
	{radio   mBold {::CanvasUtils::SetTextItemFontWeight $w $id bold}  normal   {} \
	  {-value bold   -variable ::WB::popupVars(-fontweight)}}
	{radio   mItalic {::CanvasUtils::SetTextItemFontWeight $w $id italic} normal   {} \
	  {-value italic -variable ::WB::popupVars(-fontweight)}}}
    }	
    set menuDefs(pop,speechbubble)  \
      {command   mAddSpeechBubble  {::CanvasDraw::MakeSpeechBubble $w $id}   normal {}}
    
    # Dashes need a special build process.
    set dashList {}
    foreach dash [lsort -decreasing [array names ::WB::dashFull2Short]] {
	set dashval $::WB::dashFull2Short($dash)
	if {[string equal " " $dashval]} {
	    set dopts {-value { } -variable ::WB::popupVars(-dash)}
	} else {
	    set dopts [format {-value %s -variable ::WB::popupVars(-dash)} $dashval]
	}
	lappend dashList [list radio $dash {} normal {} $dopts]
    }
    set menuDefs(pop,dash)  \
      [list cascade   mDash          {}              normal   {} {} $dashList]
    
    # Now assemble menus from the individual entries above. List of which entries where.
    array set menuArr {
	arc        {thickness fillcolor outline dash arcs inspect}
	brush      {brushthickness color smooth inspect}
	image      {saveimageas imagelarger imagesmaller exportimage inspect}
	line       {thickness dash smooth straighten inspect}
	oval       {thickness outline fillcolor dash inspect}
	pen        {thickness smooth inspect}
	polygon    {thickness outline fillcolor dash smooth straighten inspect}
	rectangle  {thickness fillcolor dash inspect}
	text       {font fontsize fontweight color speechbubble inspect}
	window     {}
	qt         {inspectqt exportmovie}
	snack      {}
	broken     {inspectbroken reloadimage}
    }
    foreach name [array names menuArr] {
	set menuDefs(pop,$name) {}
	foreach key $menuArr($name) {
	    lappend menuDefs(pop,$name) $menuDefs(pop,$key)
	}
    }    
}

# WB::NewWhiteboard --
#
#       Makes a unique whiteboard.
#
# Arguments:
#       args    -file fileName
#               -jid
#               -sendbuttonstate normal|disabled
#               -sendcheckstate normal|disabled
#               -serverentrystate normal|disabled
#               -state normal|disabled 
#               -title name
#               -thread threadId
#               -toentrystate normal|disabled
#               -type normal|chat|groupchat
#       
# Results:
#       toplevel window. (.) If not "." then ".top."; extra dot!

proc ::WB::NewWhiteboard {args} { 
    global wDlgs
    variable uidmain
    
    # Need to reuse ".". Outdated!
    if {[wm state .] == "normal"} {
	set wtop $wDlgs(wb)[incr uidmain].
    } else {
	set wtop .
    }
    eval {::WB::BuildWhiteboard $wtop} $args
    return $wtop
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
    global  this prefs privariaFlag
    
    variable dims
    variable wbicons
    variable threadToWtop
    variable jidToWtop
    variable iconsInitted
    
    Debug 2 "::WB::BuildWhiteboard wtop=$wtop, args='$args'"
    
    if {![string equal [string index $wtop end] "."]} {
	set wtop ${wtop}.
    }    
    namespace eval ::${wtop}:: "set wtop $wtop"
    
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::state state
    upvar ::${wtop}::opts opts
    upvar ::${wtop}::tmpImages tmpImages
    
    if {[string equal $wtop "."]} {
	set wbTitle "Coccinella (Main)"
    } else {
	set wbTitle "Coccinella"
    }
    set titleString [expr {
	$privariaFlag ?
	{PRIVARIA Whiteboard -- The Coccinella} : $wbTitle
    }]
    array set opts [list \
      -state normal -title $titleString -sendcheckstate disabled  \
      -sendbuttonstate normal -toentrystate normal]
    array set opts $args
    if {[info exists opts(-thread)]} {
	set threadToWtop($opts(-thread)) $wtop
    }
    if {[info exists opts(-jid)]} {
	set jidToWtop($opts(-jid)) $wtop
    }
    if {[string equal $prefs(protocol) "jabber"]} {
	set isConnected [::Jabber::IsConnected]
    } else {
	set isConnected 0
    }
    
    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    
    # Common widget paths.
    set wapp(toplevel)  $w
    set wall            ${w}.f
    set wapp(menu)      ${w}.menu
    set wapp(frall)     $wall
    set wapp(frtop)     ${wall}.frtop
    if {$prefs(haveScrollbars)} {
	set wapp(can)       ${wall}.fmain.fc.can
	set wapp(xsc)       ${wall}.fmain.fc.xsc
	set wapp(ysc)       ${wall}.fmain.fc.ysc
    } else {
	set wapp(can)       ${wall}.fmain.can
    }
    set wapp(tool)      ${wall}.fmain.frleft.frbt
    set wapp(comm)      ${wall}.fcomm.ent
    set wapp(statmess)  ${wall}.fcomm.stat.lbl
    set wapp(frstat)    ${wall}.fcomm.st
    set wapp(tray)      $wapp(frtop).on.fr
    set wapp(servCan)   $wapp(can)
    set wapp(topchilds) [list ${wall}.menu ${wall}.frtop ${wall}.fmain ${wall}.fcomm]
    
    set tmpImages {}
    
    # Init some of the state variables.
    # Inherit from the factory + preferences state.
    array set state [array get ::state]
    if {$opts(-state) == "disabled"} {
	set state(btState) 00
    }
    
    if {![winfo exists $w] && ($wtop != ".")} {
	toplevel $w -class Whiteboard
	wm withdraw $w
    }
    wm title $w $opts(-title)
    wm protocol $w WM_DELETE_WINDOW [list ::WB::CloseWhiteboard $wtop]
    
    # Have an overall frame here of class Whiteboard. Needed for option db.
    frame $wapp(frall) -class Whiteboard
    pack $wapp(frall) -fill both -expand 1
    
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
    
    # Special configuration of shortcut buttons.
    if {[info exists opts(-type)] && [string equal $opts(-type) "normal"]} {
	$wapp(tray) buttonconfigure stop -command  \
	  [list ::Import::HttpResetAll $wtop]
    }

    # Make the connection frame.
    pack [frame ${wall}.fcomm] -side bottom -fill x
    
    # Status message part.
    pack [frame $wapp(frstat) -relief raised -borderwidth 1]  \
      -side top -fill x -pady 0
    pack [frame ${wall}.fcomm.stat -relief groove -bd 2]  \
      -side top -fill x -padx 10 -pady 2 -in $wapp(frstat)
    pack [canvas $wapp(statmess) -bd 0 -highlightthickness 0 -height 14]  \
      -side left -pady 1 -padx 6 -fill x -expand true
    $wapp(statmess) create text 0 [expr 14/2] -anchor w -text {} -font $fontS \
      -tags stattxt -fill $fg
    
    # Build the header for the actual network setup.
    ::WB::SetCommHead $wtop $prefs(protocol) -connected $isConnected
    pack [frame ${wall}.fcomm.pad -relief raised -borderwidth 1]  \
      -side right -fill both -expand true
    pack [label ${wall}.fcomm.pad.hand -relief flat -borderwidth 0  \
      -image $iconResize] \
      -side right -anchor sw
    
    # Do we want a persistant jabber entry?
    if {[string equal $prefs(protocol) "jabber"]} {
	::Jabber::InitWhiteboard $wtop
	if {$prefs(jabberCommFrame)} {
	    eval {::Jabber::BuildJabberEntry $wtop} $args
	}
    }
    
    # Make the tool button pad.
    pack [frame ${wall}.fmain -borderwidth 0 -relief flat] \
      -side top -fill both -expand true
    pack [frame ${wall}.fmain.frleft] -side left -fill y
    pack [frame $wapp(tool)] -side top
    pack [frame ${wall}.fmain.frleft.pad -relief raised -borderwidth 1]  \
      -fill both -expand true
    
    # The 'Coccinella'.
    pack [label ${wall}.fmain.frleft.pad.bug -borderwidth 0 \
      -image [::Theme::GetImage ladybug]]  \
      -side bottom
    
    # Make the tool buttons and invoke the one from the prefs file.
    ::WB::CreateAllButtons $wtop
    
    # ...and the drawing canvas.
    if {$prefs(haveScrollbars)} {
	set f [frame ${wall}.fmain.fc -bd 1 -relief raised]
	set wxsc ${f}.xsc
	set wysc ${f}.ysc
	
	pack $f -fill both -expand true -side right
	canvas $wapp(can) -height $dims(hCanOri) -width $dims(wCanOri)  \
	  -relief raised -bd 0 -highlightthickness 0 -background $state(bgColCan)  \
	  -scrollregion [list 0 0 $prefs(canScrollWidth) $prefs(canScrollHeight)]  \
	  -xscrollcommand [list $wxsc set]  \
	  -yscrollcommand [list $wysc set]	
	scrollbar $wxsc -orient horizontal -command [list $wapp(can) xview]
	scrollbar $wysc -orient vertical -command [list $wapp(can) yview]
	
	grid $wapp(can) -row 0 -column 0 -sticky news -padx 1 -pady 1
	grid $wysc -row 0 -column 1 -sticky ns
	grid $wxsc -row 1 -column 0 -sticky ew
	grid columnconfigure $f 0 -weight 1
	grid rowconfigure $f 0 -weight 1    	
    } else {
	canvas $wapp(can) -height $dims(hCanOri) -width $dims(wCanOri)  \
	  -relief raised -bd 1 -highlightthickness 0 -background $state(bgColCan)
	pack $wapp(can) -fill both -expand true -side right
    }
    
    # Invoke tool button.
    ::WB::SetToolButton $wtop [::WB::ToolBtNumToName $state(btState)]

    # Add things that are defined in the prefs file and not updated else.
    ::UserActions::DoCanvasGrid $wtop
    if {$isConnected} {
	::UI::FixMenusWhen $wtop "connect"
    }

    # Set up paste menu if something on the clipboard.
    ::WB::GetFocus $wtop $w
    bind $w <FocusIn>  \
      [list [namespace current]::GetFocus $wtop %W]
    
    # Create the undo/redo object.
    set state(undotoken) [undo::new -command [list ::UI::UndoConfig $wtop]]
    
    # Set window position only for the first whiteboard on screen.
    # Subsequent whiteboards are placed by the window manager.
    if {[llength [::WB::GetAllWhiteboards]] == 1} {	
	if {[info exists prefs(winGeom,whiteboard)]} {
	    wm geometry $w $prefs(winGeom,whiteboard)
	}
    }
    catch {wm deiconify $w}
    #raise $w     This makes the window flashing when showed (linux)
    
    # A trick to let the window manager be finished before getting the geometry.
    # An 'update idletasks' needed anyway in 'FindWBGeometry'.
    after idle [namespace current]::FindWBGeometry $wtop
    
    if {[info exists opts(-file)]} {
	::CanvasFile::DrawCanvasItemFromFile $wtop $opts(-file)
    }
}

# WB::CloseWhiteboard --
#
#       Called when closing whiteboard window; cleanup etc.

proc ::WB::CloseWhiteboard {wtop} {
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
    set topw $wapp(toplevel)
    set jtype [::WB::GetJabberType $wtop]

    Debug 3 "::WB::CloseWhiteboard wtop=$wtop, jtype=$jtype"
    
    switch -- $jtype {
	chat {
	    set ans [tk_messageBox -icon info -parent $topw -type yesno \
	      -message [FormatTextForMessageBox "The complete conversation will\
	      be lost when closing this chat whiteboard.\
	      Do you actually want to end this chat?"]]
	    if {$ans != "yes"} {
		return
	    }
	    ::WB::DestroyMain $wtop
	}
	groupchat {
	    
	    # Everything handled from Jabber::GroupChat
	    set ans [::Jabber::GroupChat::Exit $opts(-jid)]
	    if {$ans != "yes"} {
		return
	    }
	}
	default {
	    ::WB::DestroyMain $wtop
	}
    }
    
    # Reset and cancel all put/get file operations related to this window!
    # I think we let put operations go on.
    #::PutFileIface::CancelAllWtop $wtop
    ::GetFileIface::CancelAllWtop $wtop
    ::Import::HttpResetAll $wtop
}

# WB::DestroyMain --
# 
#       Destroys toplevel whiteboard and cleans up.
#       The "." is just withdrawn, else we would exit (jabber only).

proc ::WB::DestroyMain {wtop} {
    global  prefs
    
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    upvar ::${wtop}::tmpImages tmpImages

    set wcan [::WB::GetCanvasFromWtop $wtop]
    
    # Save instance specific 'state' array into generic 'state'.
    ::WB::SaveWhiteboardState $wtop
    ::UI::SaveWinGeom whiteboard $wapp(toplevel)
    
    if {$wtop == "."} {
	if {[string equal $prefs(protocol) "jabber"]} {
	    
	    # Destroy all content and withdraw.
	    foreach win $wapp(topchilds) {
		destroy $win                
	    }   
	    unset opts
	    wm withdraw .
	} else {	
	    ::UserActions::DoQuit -warning 1
	}
    } else {
	set topw $wapp(toplevel)
	
	catch {destroy $topw}    
	unset opts
	unset wapp
    }
    
    # We could do some cleanup here.
    eval {image delete} $tmpImages
    ::CanvasUtils::ItemFree $wtop
    ::UI::FreeMenu $wtop
}

# WB::SaveWhiteboardState
# 
# 

proc ::WB::SaveWhiteboardState {wtop} {

    upvar ::${wtop}::wapp wapp
      
    # Read back instance specific 'state' into generic 'state'.
    array set ::state [array get ::${wtop}::state]

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
    upvar ::${wtop}::wapp wapp
    
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

# WB::SaveCleanWhiteboardDims --
# 
#       We want to save wRoot and hRoot as they would be without any connections 
#       in the communication frame. Non jabber only. Only needed when quitting
#       to get the correct dims when set from preferences when launched again.

proc ::WB::SaveCleanWhiteboardDims {wtop} {
    global prefs

    upvar ::WB::dims dims
    upvar ::${wtop}::wapp wapp

    if {$wtop != "."} {
	return
    }
    foreach {dims(wRoot) hRoot dims(x) dims(y)} [::UI::ParseWMGeometry .] break
    set dims(hRoot) [expr $dims(hCanvas) + $dims(hStatus) +  \
      $dims(hCommClean) + $dims(hTop) + $dims(hFakeMenu)]
    if {$prefs(haveScrollbars)} {
	incr dims(hRoot) [expr [winfo height $wapp(xsc)] + 4]
    }   
}

# WB::ConfigureMain --
#
#       Configure the options 'opts' state of a whiteboard.
#       Returns 'opts' if no arguments.

proc ::WB::ConfigureMain {wtop args} {
    
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    if {[llength $args] == 0} {
	return [array get opts]
    } else {
	set jentryOpts {}
	foreach {name value} $args {
	    
	    switch -- $name {
		-title {
		    wm title $w $value    
		}
		-state {
		    #
		}
		-jid {
		    lappend jentryOpts $name $value
		}
	    }
	}
	array set opts $args
	if {[llength $jentryOpts] > 0} {
	    eval {::WB::ConfigureJabberEntry $wtop {}} $jentryOpts
	}
    }
}

# WB::GetJabberType --
# 
#       Returns a typical 'type' attribute suitable for a message element.
#       If type unknown, or if "normal", return empty string.
#       Assumes that wtop exists.

proc ::WB::GetJabberType {wtop} {
    
    upvar ::${wtop}::opts opts

    set type ""
    if {[info exists opts(-type)]} {
	if {![string equal $opts(-type) "normal"]} {
	    set type $opts(-type)
	}
    }
    return $type
}

# WB::GetJabberChatThread --
# 
#       Returns the thread id for a whiteboard chat.

proc ::WB::GetJabberChatThread {wtop} {
    
    upvar ::${wtop}::opts opts

    set threadid ""
    if {[info exists opts(-type)] && [string equal $opts(-type) "chat"]} {
	if {[info exists opts(-thread)]} {
	    set threadid $opts(-thread)
	}
    }
    if {[string length $threadid] == 0} {
	return -code error {Whiteboard type is not of type "chat"}
    }
    return $threadid
}

# WB::GetWtopFromJabberType --
# 
#       Return the wtop attribute for the given 'type', 'jid', and optionally,
#       'thread'. If no whiteboard exists return empty.
#       
# Arguments:
#       type        chat, groupchat, normal
#       jid         2-tier jid with no /resource
#       thread      (optional)
#       
# Results:
#       wtop specifier or empty if no whiteboard exists.

proc ::WB::GetWtopFromJabberType {type jid {thread {}}} {    
    variable threadToWtop
    variable jidToWtop

    ::Jabber::Debug 2 "::WB::GetWtopFromJabberType type=$type, jid=$jid, thread=$thread"
    
    set wtop ""
    
    switch -- $type {
	chat {
	    if {[info exists threadToWtop($thread)]} {
		set wtop $threadToWtop($thread)
	    }	    
	}
	groupchat {
	
	    # The jid is typically the 'roomjid/nickorhash' but can be the room itself.
	    regexp {(^[^@]+@[^/]+)(/.+)?} $jid match jid x
	    if {[info exists jidToWtop($jid)]} {
		set wtop $jidToWtop($jid)
	    }	    
	}
	normal {
	    # OBSOLETE!!!! Mailbox!!!
	    if {[info exists jidToWtop($jid)]} {
		set wtop $jidToWtop($jid)
	    }	    
	}
    }
    
    # Verify that toplevel actually exists.
    if {[string length $wtop]} {
	if {[string equal $wtop "."]} {
	    set w .
	} else {
	    set w [string trimright $wtop "."]
	}
	if {![winfo exists $w]} {
	    set wtop ""
	    
	    # This is due to the weird reusage of "." BAD!!!
	} elseif {0 && ![winfo ismapped $w]} {
	    set wtop ""
	}
    }
    ::Jabber::Debug 2 "\twtop=$wtop"
    return $wtop
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
    upvar ::${wtop}::wapp wapp
    $wapp(statmess) itemconfigure stattxt -text $msg
}

proc ::WB::GetServerCanvasFromWtop {wtop} {    
    upvar ::${wtop}::wapp wapp
    
    return $wapp(servCan)
}

proc ::WB::GetCanvasFromWtop {wtop} {    
    upvar ::${wtop}::wapp wapp
    
    return $wapp(can)
}

# WB::GetButtonState --
#
#       This is a utility function mainly for plugins to get the tool buttons 
#       state.

proc ::WB::GetButtonState {wtop} {
    upvar ::${wtop}::state state
    variable btNo2Name     

    return $btNo2Name($state(btState))
}

proc ::WB::GetUndoToken {wtop} {    
    upvar ::${wtop}::state state
    
    return $state(undotoken)
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
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::state state
    upvar ::${wtop}::opts opts

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
	::UserActions::DeselectAll $wtop
    }
    
    # Cancel any outstanding polygon drawings.
    ::CanvasDraw::FinalizePoly $wCan -10 -10
    
    $wCan config -cursor {}
    
    # Bindings directly to the canvas widget are dealt with using bindtags.
    # In the future we shall never bind to 'all' items since this also binds
    # to imported stuff. The item tag 'std', introduced in 0.94.6 shall be used
    # instead.
    #set stdTag std
    set stdTag all
    
    switch -- $btName {
	point {
	    bindtags $wCan  \
	      [list $wCan WhiteboardPoint WhiteboardNonText $wtoplevel all]

	    $wCan bind $stdTag <Double-Button-1>  \
	      [list ::ItemInspector::ItemInspector $wtop current]

	    switch -- $this(platform) {
		macintosh - macosx {
		    $wCan bind $stdTag <Button-1> {
			
			# Global coords for popup.
			::CanvasUtils::StartTimerToItemPopup %W %X %Y 
		    }
		    $wCan bind $stdTag <ButtonRelease-1> {
			::CanvasUtils::StopTimerToItemPopup
		    }
		    bind QTFrame <Button-1> {
			::CanvasUtils::StartTimerToWindowPopup %W %X %Y 
		    }
		    bind QTFrame <ButtonRelease-1> {
			::CanvasUtils::StopTimerToWindowPopup
		    }
		    bind SnackFrame <Button-1> {
			::CanvasUtils::StartTimerToWindowPopup %W %X %Y 
		    }
		    bind SnackFrame <ButtonRelease-1> {
			::CanvasUtils::StopTimerToWindowPopup
		    }
		    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatpointmac]
		}
		default {
		    $wCan bind $stdTag <Button-3> {
			
			# Global coords for popup.
			::CanvasUtils::DoItemPopup %W %X %Y 
		    }
		    bind QTFrame <Button-3> {
			::CanvasUtils::DoWindowPopup %W %X %Y 
		    }
		    bind SnackFrame <Button-3> {
			::CanvasUtils::DoWindowPopup %W %X %Y 
		    }
		    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatpoint]		      
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
	    
	    # Moving single coordinates.
	    $wCan bind tbbox <Button-1> {
		::CanvasDraw::InitMove %W [%W canvasx %x] [%W canvasy %y] point
	    }
	    $wCan bind tbbox <B1-Motion> {
		::CanvasDraw::DoMove %W [%W canvasx %x] [%W canvasy %y] point
	    }
	    $wCan bind tbbox <ButtonRelease-1> {
		::CanvasDraw::FinalizeMove %W [%W canvasx %x] [%W canvasy %y] point
	    }
	    $wCan bind tbbox <Shift-B1-Motion> {
		::CanvasDraw::DoMove %W [%W canvasx %x] [%W canvasy %y] point 1
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
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatmove]
	}
	line {
	    bindtags $wCan  \
	      [list $wCan WhiteboardLine WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatline]
	}
	arrow {
	    bindtags $wCan  \
	      [list $wCan WhiteboardArrow WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatarrow]
	}
	rect {
	    bindtags $wCan  \
	      [list $wCan WhiteboardRect WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatrect]
	}
	oval {
	    bindtags $wCan  \
	      [list $wCan WhiteboardOval WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatoval]
	}
	text {
	    bindtags $wCan  \
	      [list $wCan WhiteboardText $wtoplevel all]
	    ::CanvasText::EditBind $wCan
	    $wCan config -cursor xterm
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastattext]
	}
	del {
	    bindtags $wCan  \
	      [list $wCan WhiteboardDel WhiteboardNonText $wtoplevel all]
	    bind QTFrame <Button-1>  \
	      [subst {::CanvasDraw::DeleteFrame $wCan %W %x %y}]
	    bind SnackFrame <Button-1>  \
	      [subst {::CanvasDraw::DeleteFrame $wCan %W %x %y}]
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatdel]
	}
	pen {
	    bindtags $wCan  \
	      [list $wCan WhiteboardPen WhiteboardNonText $wtoplevel all]
	    $wCan config -cursor pencil
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatpen]
	}
	brush {
	    bindtags $wCan  \
	      [list $wCan WhiteboardBrush WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatbrush]
	}
	paint {
	    bindtags $wCan  \
	      [list $wCan WhiteboardPaint WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatpaint]	      
	}
	poly {
	    bindtags $wCan  \
	      [list $wCan WhiteboardPoly WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatpoly]	      
	}       
	arc {
	    bindtags $wCan  \
	      [list $wCan WhiteboardArc WhiteboardNonText $wtoplevel all]
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatarc]	      
	}
	rot {
	    bindtags $wCan  \
	      [list $wCan WhiteboardRot WhiteboardNonText $wtoplevel all]
	    $wCan config -cursor exchange
	    ::WB::SetStatusMessage $wtop [::msgcat::mc uastatrot]	      
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
    
    upvar ::${wtop}::wapp wapp
    set wCan $wapp(can)
    
    # Various bindings.
    bind $wCan <BackSpace> [list ::CanvasDraw::DeleteItem $wCan %x %y selected]
    bind $wCan <Control-d> [list ::CanvasDraw::DeleteItem $wCan %x %y selected]
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

    $w bind all <Button-1> {}
    $w bind all <B1-Motion> {}
    $w bind all <Any-Key> {}
    $w bind all <Double-Button-1> {}
    $w bind all <Button-3> {}
    
    # These shouldn't be necessary but they are...
    $w bind text <Button-1> {}
    $w bind text <B1-Motion> {}
    $w bind text <Double-Button-1> {}	

    # Remove bindings on markers on selected items.
    $w bind tbbox <Button-1> {}
    $w bind tbbox <B1-Motion> {}
    $w bind tbbox <ButtonRelease-1> {}
	
    bind QTFrame <Button-1> {}
    bind QTFrame <B1-Motion> {}
    bind QTFrame <ButtonRelease-1> {}
    bind SnackFrame <Button-1> {}
    bind SnackFrame <B1-Motion> {}
    bind SnackFrame <ButtonRelease-1> {}
    
    # Remove any text insertion...
    $w focus {}
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
    global  this wDlgs prefs dashFull2Short osprefs
    
    variable menuDefs
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::state state
    upvar ::${wtop}::opts opts
	
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
	
    # Item menu (temporary placement).
    ::WB::BuildItemMenu $wtop ${wmenu}.items $prefs(itemDir)
    
    # Addon or Plugin menus if any.
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
    $wmenu entryconfigure [::msgcat::mc mPreferences] -state disabled
    $wmenu entryconfigure [::msgcat::mc mItems] -state disabled
    $wmenu entryconfigure [::msgcat::mc mInfo] -state disabled
	
    # Handle all 'addons'.
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
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    upvar ::${wtop}::state state    
    
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
	pack [frame $wfrtop -relief raised -borderwidth 0] -side top -fill x
	pack [frame $wfron -borderwidth 0] -fill x -side left -expand 1
	pack [label $wonbar -image $wbicons(barvert) -bd 1 -relief raised] \
	  -padx 0 -pady 0 -side left
	#pack [frame $wapp(tray) -relief raised -borderwidth 1]  \
	#  -side left -fill both -expand 1
	label $woffbar -image $wbicons(barhoriz) -relief raised -borderwidth 1
	bind $wonbar <Button-1> [list $wonbar configure -relief sunken]
	bind $wonbar <ButtonRelease-1>  \
	  [list [namespace current]::ConfigShortcutButtonPad $wtop "off"]
	
	# Build the actual shortcut button pad.
	::WB::BuildShortcutButtonPad $wtop
	pack $wapp(tray) -side left -fill both -expand 1
	if {$opts(-state) == "disabled"} {
	    ::WB::DisableShortcutButtonPad $wtop
	}
    }
 
    if {[string equal $what "init"]} {
    
	# Do we want the toolbar to be collapsed at initialization?
	if {[string equal $subSpec "off"]} {
	    pack forget $wfron
	    $wfrtop configure -bg gray75
	    pack $woffbar -side left -padx 0 -pady 0
	    bind $woffbar <ButtonRelease-1>   \
	      [list [namespace current]::ConfigShortcutButtonPad $wtop "on"]
	}
	
    } elseif {[string equal $what "off"]} {
	
	# Relax the min size; reset from 'SetNewWMMinsize' below.
	wm minsize $topw 0 0
	
	# New size, keep width.
	set size [::UI::ParseWMGeometry $topw]
	set newHeight [expr [lindex $size 1] - $dims(hTopOn) + $dims(hTopOff)]
	wm geometry $topw [lindex $size 0]x$newHeight
	pack forget $wfron
	$wfrtop configure -bg gray75
	pack $woffbar -side left -padx 0 -pady 0
	bind $woffbar <Button-1> [list $woffbar configure -relief sunken]
	bind $woffbar <ButtonRelease-1>   \
	  [list [namespace current]::ConfigShortcutButtonPad $wtop "on"]
	after idle [list [namespace current]::SetNewWMMinsize $wtop]
	$wonbar configure -relief raised
	set state(visToolbar) 0

    } elseif {[string equal $what "on"]} {
	
	# New size, keep width.
	set size [::UI::ParseWMGeometry $topw]
	set newHeight [expr [lindex $size 1] - $dims(hTopOff) + $dims(hTopOn)]
	wm geometry $topw [lindex $size 0]x$newHeight
	pack forget $woffbar
	pack $wfron -fill x -side left -expand 1
	$woffbar configure -relief raised
	bind $woffbar <Button-1> [list $woffbar configure -relief sunken]
	bind $woffbar <ButtonRelease-1>   \
	  [list [namespace current]::ConfigShortcutButtonPad $wtop "off"]
	after idle [list [namespace current]::SetNewWMMinsize $wtop]
	set state(visToolbar) 1
    }
}

# WB::BuildShortcutButtonPad --
#
#       Build the actual shortcut button pad.

proc ::WB::BuildShortcutButtonPad {wtop} {
    global  prefs wDlgs this
    
    variable wbicons
    variable btShortDefs
    upvar ::${wtop}::wapp wapp
    
    set wCan   $wapp(can)
    set wtray  $wapp(tray)
    set wfrall $wapp(frall)
    set h [image height $wbicons(barvert)]

    ::buttontray::buttontray $wtray $h -relief raised -borderwidth 1

    # We need to substitute $wCan, $wtop etc specific for this wb instance.
    foreach {name cmd} $btShortDefs(this) {
	set icon    [::Theme::GetImage [option get $wfrall ${name}Image {}]]
	set iconDis [::Theme::GetImage [option get $wfrall ${name}DisImage {}]]
	set cmd [subst -nocommands -nobackslashes $cmd]
	set txt [string toupper [string index $name 0]][string range $name 1 end]
	$wtray newbutton $name $txt $icon $iconDis $cmd
    }
    if {[string equal $prefs(protocol) "server"]} {
	$wtray buttonconfigure connect -state disabled
    }
    $wtray buttonconfigure send -state disabled
}

# WB::DisableShortcutButtonPad --
#
#       Sets the state of the main to "read only".

proc ::WB::DisableShortcutButtonPad {wtop} {
    variable btShortDefs
    upvar ::${wtop}::wapp wapp

    set wtray $wapp(tray)
    foreach {name cmd} $btShortDefs(this) {

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
    upvar ::${wtop}::state state
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
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
    set imheight [image height $wbicons(imcolor)]
    set wColSel [canvas $wtool.cacol -width 56 -height $imheight  \
      -highlightthickness 0]
    $wtool.cacol create image 0 0 -anchor nw -image $wbicons(imcolor)
    set idColSel [$wtool.cacol create rect 7 7 33 30	\
      -fill $state(fgCol) -outline {} -tags tcolSel]
    set wapp(colSel) $wColSel
    
    # Black and white reset rectangle.
    set idBWReset [$wtool.cacol create image 4 34 -anchor nw  \
      -image $wbicons(bwrect)]
    
    # bg and fg switching.
    set idBWSwitch [$wtool.cacol create image 38 4 -anchor nw  \
      -image $wbicons(bwrect)]
    grid $wtool.cacol -  -padx 0 -pady 0

    if {![string equal $opts(-state) "disabled"]} {
	$wtool.cacol bind $idColSel <Button-1>  \
	  [list [namespace current]::ColorSelector $wtop $state(fgCol)]
	$wtool.cacol bind $idBWReset <Button-1>  \
	  "$wColSel itemconfigure $idColSel -fill black;  \
	  set ::${wtop}::state(fgCol) black; set ::${wtop}::state(bgCol) white"
	$wtool.cacol bind $idBWSwitch <Button-1> \
	  [list [namespace current]::SwitchBgAndFgCol $wtop]
    }
}

proc ::WB::BuildToolPopups {wtop} {
    global  prefs
    
    variable menuDefs
    upvar ::${wtop}::wapp wapp
    
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
    
    upvar ::${wtop}::wapp wapp

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
    
    upvar ::${wtop}::state state
    upvar ::${wtop}::wapp wapp

    $wapp(colSel) itemconfigure tcolSel -fill $state(bgCol)
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
    
    upvar ::${wtop}::state state
    upvar ::${wtop}::wapp wapp

    set col [tk_chooseColor -initialcolor $col]
    if {[string length $col] > 0} {
	set state(fgCol) $col
	$wapp(colSel) itemconfigure tcolSel -fill $state(fgCol)
	$wapp(colSel) raise tcolSel
    }
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

# WB::FindWBGeometry --
#
#       Just after launch, find and set various geometries of the application.
#       'hRoot' excludes the menu height, 'hTot' includes it.
#       Note: 
#       [winfo height .#menu] gives the menu height when the menu is in the
#       root window; 
#       [wm geometry .] gives and sets dimensions *without* the menu;
#       [wm minsize .] gives and sets dimensions *with* the menu included.
#       EAS: TclKit w/ Tcl 8.4 returns an error "bad window path name ".#menu"
#
# dims array:
#       wRoot, hRoot:      total size of the toplevel not including any menu.
#       wTot, hTot:        total size of the toplevel including any menu.
#       hTop:              height of the shortcut button frame at top.
#       hMenu:             height of any menu if present in the toplevel window.
#       hStatus:           height of the status frame.
#       hComm:             height of the communication frame including all client
#                          frames.
#       hCommClean:        height of the communication frame excluding all client 
#                          frames.
#       wStatMess:         width of the status message frame.
#       wCanvas, hCanvas:  size of the actual canvas.
#       x, y:              position of the app window.

proc ::WB::FindWBGeometry {wtop} {
    global  this prefs
    
    variable dims
    variable wbicons
    upvar ::UI::icons icons
    upvar ::${wtop}::wapp wapp
	
    # Changed to reqwidth and reqheight instead of width and height.
    # EAS: Begin
    # update idletasks
    update
    # EAS: End
    if {$wtop == "."} {
	set w .
    } else {
	set w [string trimright $wtop "."]
    }
    
    set wmenu   $wapp(menu)
    set wCan    $wapp(can)
    set wfrtop  $wapp(frtop)
    set wfrstat $wapp(frstat)
    
    # The actual dimensions.
    set wRoot [winfo reqwidth $w]
    set hRoot [winfo reqheight $w]
    set hTop 0
    if {[winfo exists $wfrtop]} {
	set hTop [winfo reqheight $wfrtop]
    }
    set hTopOn [winfo reqheight ${wfrtop}.on]
    set hTopOff [winfo reqheight ${wfrtop}.barhoriz]
    set hStatus [winfo reqheight $wfrstat]
    set hComm [winfo reqheight $wapp(comm)]
    set hCommClean $hComm
    set wStatMess [winfo reqwidth $wapp(statmess)]    
    
    # If we have a custom made menubar using a frame with labels (embedded).
    if {$prefs(haveMenus)} {
	set hFakeMenu 0
    } else {
	set hFakeMenu [winfo reqheight $wmenu]
    }
    if {![string match "mac*" $this(platform)]} {
	# MATS: seems to always give 1 Linux not...
	### EAS BEGIN
	set hMenu 1
	if {[winfo exists ${wtop}#menu]} {
	    set hMenu [winfo height ${wtop}#menu]
	}
	# In 8.4 it seems that .wb1.#wb1#menu is used.
	set wmenu_ ${wtop}#[string trim $wtop .]#menu
	if {[winfo exists $wmenu_]} {
	    set hMenu [winfo height $wmenu_]
	}
	### EAS END
    } else {
	set hMenu 0
    }
    
    set wCanvas [winfo width $wCan]
    set hCanvas [winfo height $wCan]
    set wTot $wRoot
    set hTot [expr $hRoot + $hMenu]
    
    # The minimum dimensions. Check if 'wapp(comm)' is wider than wMinCanvas!
    # Take care of the case where there is no To or From checkbutton.
    
    set wMinCommFrame [expr [winfo width $wapp(comm).comm] +  \
      [winfo width $wapp(comm).user] + [image width $wbicons(resizehandle)] + 2]
    if {[winfo exists $wapp(comm).to]} {
	incr wMinCommFrame [winfo reqwidth $wapp(comm).to]
    }
    if {[winfo exists $wapp(comm).from]} {
	incr wMinCommFrame [winfo reqwidth $wapp(comm).from]
    }
	
    set wMinRoot [max [expr $dims(wMinCanvas) + 56] $wMinCommFrame]
    set hMinRoot [expr $dims(hMinCanvas) + $hStatus + $hComm + $hTop + \
      $hFakeMenu]
    if {$prefs(haveScrollbars)} {
	# 2 for padding
	incr wMinRoot [expr [winfo reqwidth $wapp(ysc)] + 2]
	incr hMinRoot [expr [winfo reqheight $wapp(xsc)] + 2]
    }
    set wMinTot $wMinRoot
    set hMinTot [expr $hMinRoot + $hMenu]
	
    # Cache dims.
    foreach key {
	wRoot hRoot hTop hTopOn hTopOff hStatus hComm hCommClean wStatMess \
	  hFakeMenu hMenu wCanvas hCanvas wTot hTot wMinRoot hMinRoot \
	  wMinTot hMinTot
    } {
	set dims($key) [set $key]
    }
    
    #::Debug 2 "::WB::FindWBGeometry"
    #::Debug 2 "[parray dims]"
    
    # The minsize when no connected clients. 
    # Is updated when connect/disconnect (Not jabber).
    wm minsize $w $wMinTot $hMinTot
}

# ::WB::SetCanvasSize --
#
#       From the canvas size, 'cw' and 'ch', set the total application size.
#       
# Arguments:
#
# Results:
#       None.

proc ::WB::SetCanvasSize {cw ch} {
    global  prefs
	
    upvar ::WB::dims dims
    upvar ::.::wapp wapp
    
    # Compute new root size from the desired canvas size.
    set wRootFinal [expr $cw + 56]
    set hRootFinal [expr $ch + $dims(hStatus) + $dims(hComm) + $dims(hTop)]
    if {$prefs(haveScrollbars)} {
	incr wRootFinal [expr [winfo reqwidth $wapp(ysc)] + 2]
	incr hRootFinal [expr [winfo reqheight $wapp(xsc)] + 2]
    }
    wm geometry . ${wRootFinal}x${hRootFinal}

    Debug 3 "::WB::SetCanvasSize:: cw=$cw, ch=$ch, hRootFinal=$hRootFinal, \
      wRootFinal=$wRootFinal"
}

# ::WB::SetNewWMMinsize --
#
#       If a new entry in the communication frame is added, or the shortcut button
#       frame is collapsed or expanded, we need to set a new minsize for the
#       total application size, and update the necassary 'dims' variables.
#       It must be called 'after idle' to be sure all windows have been updated
#       properly.
#       
# Arguments:
#
# Results:

proc ::WB::SetNewWMMinsize {wtop} {
    global  prefs
    
    upvar ::WB::dims dims
    upvar ::${wtop}::wapp wapp
	
    # test...
    update idletasks
    set dims(hTop) 0
    if {[string equal $wtop "."]} {
	set wtopReal .
    } else {
	set wtopReal [string trimright $wtop .]
    }

    # Procedure ?????
    if {[winfo exists ${wtop}frtop]} {
	set dims(hTop) [winfo reqheight ${wtop}frtop]
    }
    set dims(hComm) [winfo reqheight $wapp(comm)]
    set dims(hMinRoot) [expr $dims(hMinCanvas) + $dims(hStatus) + $dims(hComm) +  \
      $dims(hTop) + $dims(hFakeMenu)]
    if {$prefs(haveScrollbars)} {
	# 2 for padding
	incr dims(hMinRoot) [expr [winfo reqheight $wapp(xsc)] + 2]
    }
    set dims(hMinTot) [expr $dims(hMinRoot) + $dims(hMenu)]
    set dims(wMinTot) $dims(wMinRoot)
	
    # Note: wm minsize is *with* the menu!!!
    wm minsize $wtopReal $dims(wMinTot) $dims(hMinTot)

    # Be sure it is respected. Note: wm geometry is *without* the menu!
    foreach {wmx wmy} [::UI::ParseWMGeometry $wtopReal] break
    if {($wmx < $dims(wMinRoot)) || ($wmy < $dims(hMinRoot))} {
	wm geometry $wtopReal $dims(wMinRoot)x$dims(hMinRoot)
    }
    
    Debug 2 "::WB::SetNewWMMinsize:: dims(hComm)=$dims(hComm),  \
      dims(hMinRoot)=$dims(hMinRoot), dims(hMinTot)=$dims(hMinTot), \
      dims(hTop)=$dims(hTop)"
}	    

# WB::GetFocus --
#
#       Check clipboard and activate corresponding menus.    
#       
# Results:
#       updates state of menus.

proc ::WB::GetFocus {wtop w} {
    
    upvar ::${wtop}::opts opts
    upvar ::${wtop}::wapp wapp

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

# A few proc that handles the communication frames at the bottom of the window.

# ::WB::SetCommHead --
#
#       Communication header created or configured.
#       If network configuration is changed, update the communication 
#       frame header. This happens if we switch between a centralized network
#       and a client connected to a central server.
#       
# Arguments:
#       wtop
#       type        any of "jabber", "symmetric", "central" 
#                   "client", or "server" (prefs(protocol))
#       
# Results:
#       WB updated.

proc ::WB::SetCommHead {wtop type args} {
    global  prefs
    
    variable thisType
    variable nEnt
    upvar ::${wtop}::wapp wapp
    
    Debug 2 "::WB::SetCommHead"
    
    set thisType $type
    set nEnt($wtop) 0
    set wcomm $wapp(comm)
    
    # The labels in comm frame.
    if {![winfo exists $wcomm]} {
	eval {::WB::BuildCommHead $wtop $type} $args
    } else {
	
	# It's already there, configure it...
	destroy $wcomm
	eval {::WB::BuildCommHead $wtop $type} $args
	
	# We need to allow for resizing here if any change in height.
	after idle [list [namespace current]::SetNewWMMinsize $wtop]
    }
}


proc ::WB::BuildCommHead {wtop type args} {
    global  prefs
    
    upvar ::${wtop}::wapp wapp
    
    set wall  $wapp(frall)
    set wcomm $wapp(comm)
    
    Debug 2 "::WB::BuildCommHead"
    
    array set argsArr {-connected 0}
    array set argsArr $args
    
    set fontSB [option get . fontSmallBold {}]
    set contactOffImage [::Theme::GetImage [option get $wall contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage [option get $wall contactOnImage {}]]
    
    pack [frame $wcomm -relief raised -borderwidth 1] -side left
    
    switch -- $type {
	jabber {
	    label $wcomm.comm -text "  [::msgcat::mc {Jabber Server}]:"  \
	      -width 18 -anchor w -font $fontSB
	    label $wcomm.user -text "  [::msgcat::mc {Jabber Id}]:"  \
	      -width 18 -anchor w -font $fontSB
	    if {$argsArr(-connected)} {
		label $wcomm.icon -image $contactOnImage
	    } else {
		label $wcomm.icon -image $contactOffImage
	    }
	    grid $wcomm.comm $wcomm.user -sticky nws -pady 0
	    grid $wcomm.icon -row 0 -column 3 -sticky w -pady 0
	}
	symmetric {
	    label $wcomm.comm -text {  Remote address:} -width 22 -anchor w \
	      -font $fontSB
	    label $wcomm.user -text {  User:} -width 14 -anchor w  \
	      -font $fontSB
	    label $wcomm.to -text [::msgcat::mc To] -font $fontSB
	    label $wcomm.from -text [::msgcat::mc From] -font $fontSB
	    grid $wcomm.comm $wcomm.user $wcomm.to $wcomm.from \
	      -sticky nws -pady 0
	}
	client {
	    label $wcomm.comm -text {  Remote address:} -width 22 -anchor w \
	      -font $fontSB
	    label $wcomm.user -text {  User:} -width 14 -anchor w \
	      -font $fontSB
	    label $wcomm.to -text [::msgcat::mc To] -font $fontSB
	    grid $wcomm.comm $wcomm.user $wcomm.to  \
	      -sticky nws -pady 0
	}
	server {
	    label $wcomm.comm -text {  Remote address:} -width 22 -anchor w \
	      -font $fontSB
	    label $wcomm.user -text {  User:} -width 14 -anchor w \
	      -font $fontSB
	    label $wcomm.from -text [::msgcat::mc From] -font $fontSB
	    grid $wcomm.comm $wcomm.user $wcomm.from \
	      -sticky nws -pady 0
	}
	central {
	    
	    # If this is a client connected to a central server, no 'from' 
	    # connections.
	    label $wcomm.comm -text {  Remote address:} -width 22 -anchor w
	    label $wcomm.user -text {  User:} -width 14 -anchor w
	    label $wcomm.to -text [::msgcat::mc To]
	    label $wcomm.icon -image $contactOffImage
	    grid $wcomm.comm $wcomm.user $wcomm.to $wcomm.icon  \
	      -sticky nws -pady 0
	}
    }  
    
    # A min height was necessary here to make room for switching the icon 
    # of this row.
    grid rowconfigure $wcomm 0 -minsize 23
}

# ::WB::BuildJabberEntry --
#
#       Builds a jabber entry in the communications frame that is suitable
#       for persistent display. It should be there already when main window
#       is built, and not added/removed when connect/disconnect from jabber 
#       server.
#     
# Arguments:
#       wtop
#       args:       ?-key value ...?
#                   -toentrystate (normal|disabled)
#                   -serverentrystate (normal|disabled)
#                   -servervariable
#                   -state (normal|disabled)
#                   -jidvariable
#                   -dosendvariable
#                   -dosendcommand
#                   -validatecommand
#                   -sendcheckstate (normal|disabled)
#       
# Results:
#       UI updated.

proc ::WB::BuildJabberEntry {wtop args} {
    global  prefs
    
    upvar ::Jabber::jstate jstate
    upvar ::${wtop}::wapp wapp
    
    Debug 2 "::WB::BuildJabberEntry args='$args'"

    array set argsArr {
	-state normal 
	-sendcheckstate disabled 
	-toentrystate normal 
	-serverentrystate normal
    }
    array set argsArr $args
    set ns [namespace current]
    set wcomm $wapp(comm)
    set wtopReal $wapp(toplevel)
    
    set fontSB [option get . fontSmallBold {}]
    set bg [option get . backgroundGeneral {}]
    
    set n 1
    set jidlist [$jstate(roster) getusers]
    entry $wcomm.ad$n -width 16 -relief sunken -bg $bg
    ::entrycomp::entrycomp $wcomm.us$n $jidlist -width 22 -relief sunken \
      -bg white
    if {[info exists argsArr(-servervariable)]} {
	$wcomm.ad$n configure -textvariable $argsArr(-servervariable)
    }
    if {[info exists argsArr(-jidvariable)]} {
	$wcomm.us$n configure -textvariable $argsArr(-jidvariable)
    }
    
    # Verfiy that the jid is well formed.
    if {[info exists argsArr(-validatecommand)]} {
	$wcomm.us$n configure -validate focusout  \
	  -validatecommand [list $argsArr(-validatecommand)]
    }
    set checkOpts {}
    if {[info exists argsArr(-dosendvariable)]} {
	set checkOpts [concat $checkOpts [list -variable $argsArr(-dosendvariable)]]
    }
    if {[info exists argsArr(-dosendcommand)]} {
	set checkOpts [concat $checkOpts [list -command $argsArr(-dosendcommand)]]
    }
    eval {checkbutton $wcomm.to$n -highlightthickness 0  \
      -state $argsArr(-sendcheckstate) \
      -text " [::msgcat::mc {Send Live}]" -font $fontSB} $checkOpts
    grid $wcomm.ad$n $wcomm.us$n -padx 4 -pady 0
    grid $wcomm.to$n -row 1 -column 2 -columnspan 2 -padx 4 -pady 0

    if {$argsArr(-state) == "disabled"} {
	$wcomm.ad$n configure -state disabled
	$wcomm.us$n configure -state disabled
    }
    if {$argsArr(-serverentrystate) == "disabled"} {
	$wcomm.ad$n configure -state disabled
    }    
    if {$argsArr(-toentrystate) == "disabled"} {
	$wcomm.us$n configure -state disabled
    }    
}

# WB::ConfigureAllJabberEntries --

proc ::WB::ConfigureAllJabberEntries {ipNum args} {

    foreach w [::WB::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]
	eval {::WB::ConfigureJabberEntry $wtop $ipNum} $args
    }
}

# WB::ConfigureJabberEntry --
#
#       Configures the jabber entry in the communications frame that is suitable
#       for persistent display.

proc ::WB::ConfigureJabberEntry {wtop ipNum args} {
    
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
    Debug 2 "::WB::ConfigureJabberEntry args='$args'"
    
    set wall  $wapp(frall)
    set wcomm $wapp(comm)
    set n 1
    set contactOffImage [::Theme::GetImage [option get $wall contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage [option get $wall contactOnImage {}]]
    
    foreach {key value} $args {
	switch -- $key {
	    -netstate {
		switch -- $value {
		    connect {
			if {$opts(-sendcheckstate) == "normal"} {
			    ${wcomm}.to${n} configure -state normal
			}
			
			# Update "electric plug" icon.
			after 400 [list ${wcomm}.icon configure  \
			  -image $contactOnImage]
		    }
		    disconnect {
			${wcomm}.to${n} configure -state disabled
			after 400 [list ${wcomm}.icon configure  \
			  -image $contactOffImage]	    
		    }
		}
	    }
	}
    }
    eval {::Jabber::ConfigureJabberEntry $wtop} $args
}

proc ::WB::DeleteJabberEntry {wtop} {

    upvar ::${wtop}::wapp wapp
    
    set n 1
    catch {
	destroy $wcomm.ad$n
	destroy $wcomm.us$n
	destroy $wcomm.to$n
    }
}

# ::WB::SetCommEntry --
#
#       Adds, removes or updates an entry in the communications frame.
#       If 'to' or 'from' is -1 then disregard this variable.
#       If neither 'to' or 'from', then remove the entry completely for this
#       specific ipNum.
#       The actual job of handling the widgets are done in 'RemoveCommEntry' 
#       and 'BuildCommEntry'.
#       
# variables:
#       nEnt              a running counter for the communication frame entries
#                         that is *never* reused.
#       ipNum2iEntry:     maps ip number to the entry line (nEnt) in the connect 
#                         panel.
#                    
# Arguments:
#       wtop
#       ipNum       the ip number.
#       to          0/1/-1 if off/on/indifferent respectively.
#       from        0/1/-1 if off/on/indifferent respectively.
#       args        '-jidvariable varName', '-validatecommand tclProc'
#                   '-dosendvariable varName'
#       
# Results:
#       updated communication frame.

proc ::WB::SetCommEntry {wtop ipNum to from args} { 
    global  prefs
    
    variable commTo
    variable commFrom
    variable thisType
    
    Debug 2 "SetCommEntry:: wtop=$wtop, ipNum=$ipNum, to=$to, from=$from, \
      args='$args'"
    
    # Need to check if already exist before adding a completely new entry.
    set alreadyThere 0
    if {[info exists commTo($wtop,$ipNum)]} {
	set alreadyThere 1
    } else {
	set commTo($wtop,$ipNum) 0		
    }
    if {[info exists commFrom($wtop,$ipNum)]} {
	set alreadyThere 1
    } else {
	set commFrom($wtop,$ipNum) 0		
    }

    Debug 2 "  SetCommEntry:: alreadyThere=$alreadyThere, ipNum=$ipNum"
    Debug 2 "     commTo($wtop,$ipNum)=$commTo($wtop,$ipNum), commFrom($wtop,$ipNum)=$commFrom($wtop,$ipNum)"

    if {$to >= 0} {
	set commTo($wtop,$ipNum) $to
    }
    if {$from >= 0} {
	set commFrom($wtop,$ipNum) $from
    }
    
    # If it is not there and shouldn't be added, just return.
    if {!$alreadyThere && ($commTo($wtop,$ipNum) == 0) &&  \
      ($commFrom($wtop,$ipNum) == 0)} {
	Debug 2 "  SetCommEntry:: it is not there and shouldnt be added"
	return
    }
    
    # Update network register to contain each ip num connected to.
    if {$commTo($wtop,$ipNum) == 1} {
	::Network::RegisterIP $ipNum to
    } elseif {$commTo($wtop,$ipNum) == 0} {
	::Network::DeRegisterIP $ipNum to
    }
    
    # Update network register to contain each ip num connected to our server
    # from a remote client.
    if {$commFrom($wtop,$ipNum) == 1} {
	::Network::RegisterIP $ipNum from
    } elseif {$commFrom($wtop,$ipNum) == 0} {
	::Network::DeRegisterIP $ipNum from
    }
	
    # Build new or remove entry line.
    if {![string equal $prefs(protocol) "jabber"] &&  \
      ($commTo($wtop,$ipNum) == 0) && ($commFrom($wtop,$ipNum) == 0)} {

	# If both 'to' and 'from' 0, and not jabber, then remove entry.
	::WB::RemoveCommEntry $wtop $ipNum
    } elseif {!$alreadyThere} {
	eval {::WB::BuildCommEntry $wtop $ipNum} $args
    } elseif {[string equal $prefs(protocol) "jabber"]} {
	if {$commTo($wtop,$ipNum) == 0} {
	    ::WB::RemoveCommEntry $wtop $ipNum
	}
    } 
}

# ::WB::BuildCommEntry --
#
#       Makes a new entry in the communications frame.
#       Should only be called from SetCommEntry'.
#       
# Arguments:
#       wtop
#       ipNum       the ip number.
#       args        '-jidvariable varName', '-validatecommand cmd',
#                   '-dosendvariable varName'
#       
# Results:
#       updated communication frame with new client.

proc ::WB::BuildCommEntry {wtop ipNum args} {
    global  prefs ipNumTo
    
    variable commTo
    variable commFrom
    variable ipNum2iEntry
    variable nEnt
    variable thisType
    upvar ::${wtop}::wapp wapp
    
    Debug 2 "BuildCommEntry:: ipNum=$ipNum, args='$args'"

    array set argsArr $args
    set ns [namespace current]
    set wcomm $wapp(comm)
    set wall  $wapp(frall)

    if {[string equal $wtop "."]} {
	set wtopReal .
    } else {
	set wtopReal [string trimright $wtop .]
    }
    set contactOffImage [::Theme::GetImage [option get $wall contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage [option get $wall contactOnImage {}]]
	
    set size [::UI::ParseWMGeometry $wtopReal]
    set n $nEnt($wtop)
    
    # Add new status line.
    if {[string equal $thisType "jabber"]} {
	entry $wcomm.ad$n -width 18 -relief sunken
	entry $wcomm.us$n -width 22 -relief sunken
	if {[info exists argsArr(-jidvariable)]} {
	    $wcomm.us$n configure -textvariable $argsArr(-jidvariable)
	}
	
	# Verfiy that the jid is well formed.
	if {[info exists argsArr(-validatecommand)]} {
	    $wcomm.us$n configure -validate focusout  \
	      -validatecommand [list $argsArr(-validatecommand)]
	}
	if {[info exists argsArr(-dosendvariable)]} {
	    set checkOpts [list -variable $argsArr(-dosendvariable)]
	} else {
	    set checkOpts {}
	}
	
	# Set the focus to this entry.
	focus $wcomm.us$n
	$wcomm.us$n icursor 0
	eval {checkbutton $wcomm.to$n -highlightthickness 0} $checkOpts
	grid $wcomm.ad$n $wcomm.us$n $wcomm.to$n -padx 4 -pady 0
	
	# Update "electric plug".
	after 400 [list $wcomm.icon configure -image $contactOnImage]
    } elseif {[string equal $thisType "symmetric"]} {
	entry $wcomm.ad$n -width 24 -relief sunken
	entry $wcomm.us$n -width 16   \
	  -textvariable ipNumTo(user,$ipNum) -relief sunken
	checkbutton $wcomm.to$n -variable ${ns}::commTo($wtop,$ipNum)   \
	  -highlightthickness 0 -command [list ::WB::CheckCommTo $wtop $ipNum]
	checkbutton $wcomm.from$n -variable ${ns}::commFrom($wtop,$ipNum)  \
	  -highlightthickness 0 -state disabled
	grid $wcomm.ad$n $wcomm.us$n $wcomm.to$n   \
	  $wcomm.from$n -padx 4 -pady 0
	$wcomm.us$n configure -state disabled
    } elseif {[string equal $thisType "client"]} {
	entry $wcomm.ad$n -width 24 -relief sunken
	entry $wcomm.us$n -width 16    \
	  -textvariable ipNumTo(user,$ipNum) -relief sunken
	checkbutton $wcomm.to$n -variable ${ns}::commTo($wtop,$ipNum)   \
	  -highlightthickness 0 -command [list ::WB::CheckCommTo $wtop $ipNum]
	grid $wcomm.ad$n $wcomm.us$n $wcomm.to$n -padx 4 -pady 0
	$wcomm.us$n configure -state disabled
    } elseif {[string equal $thisType "server"]} {
	entry $wcomm.ad$n -width 24 -relief sunken
	entry $wcomm.us$n -width 16    \
	  -textvariable ipNumTo(user,$ipNum) -relief sunken
	checkbutton $wcomm.from$n -variable ${ns}::commFrom($wtop,$ipNum)  \
	  -highlightthickness 0 -state disabled
	grid $wcomm.ad$n $wcomm.us$n $wcomm.from$n -padx 4 -pady 0
	$wcomm.us$n configure -state disabled
    }
    
	
    # If no ip name given (unknown) pick ip number instead.
    if {[string match "*unknown*" [string tolower $ipNumTo(name,$ipNum)]]} {
	$wcomm.ad$n insert end $ipNum
    } else {
	$wcomm.ad$n insert end $ipNumTo(name,$ipNum)
    }
    $wcomm.ad$n configure -state disabled
    
    # Increase application height with the correct entry height.
    set entHeight [winfo reqheight $wcomm.ad$n]
    if {[winfo exists $wcomm.to$n]} {
	set checkHeight [winfo reqheight $wcomm.to$n]
    } else {
	set checkHeight 0
    }
    set extraHeight [max $entHeight $checkHeight]
    set newHeight [expr [lindex $size 1] + $extraHeight]

    Debug 3 "  BuildCommEntry:: nEnt=$n, size=$size, \
      entHeight=$entHeight, newHeight=$newHeight, checkHeight=$checkHeight"

    wm geometry $wtopReal [lindex $size 0]x$newHeight
    
    # Geometry considerations. Update geometry vars and set new minsize.
    after idle [list [namespace current]::SetNewWMMinsize $wtop]
    
    # Map ip name to nEnt.
    set ipNum2iEntry($wtop,$ipNum) $nEnt($wtop)
    
    # Step up running index. This must *never* be reused!
    incr nEnt($wtop)
}

# ::WB::CheckCommTo --
#
#       This is the callback function when the checkbutton 'To' has been trigged.
#       
# Arguments:
#       wtop 
#       ipNum       the ip number.
#       
# Results:
#       updated communication frame.

proc ::WB::CheckCommTo {wtop ipNum} {
    global  ipNumTo
    
    variable commTo
    variable ipNum2iEntry
    variable thisType
    
    Debug 2 "CheckCommTo:: ipNum=$ipNum"

    if {$commTo($wtop,$ipNum) == 0} {
	
	# Close connection.
	set res [tk_messageBox -message [FormatTextForMessageBox \
	  "Are you sure that you want to disconnect $ipNumTo(name,$ipNum)?"] \
	  -icon warning -type yesno -default yes]
	if {$res == "no"} {
	    
	    # Reset.
	    set commTo($wtop,$ipNum) 1
	    return
	} elseif {$res == "yes"} {
	    ::OpenConnection::DoCloseClientConnection $ipNum
	}
    } elseif {$commTo($wtop,$ipNum) == 1} {
	
	# Open connection. Let propagateSizeToClients = true.
	::OpenConnection::DoConnect $ipNum $ipNumTo(servPort,$ipNum) 1
	::WB::SetCommEntry $wtop $ipNum 1 -1
    }
}

# ::WB::RemoveCommEntry --
#
#       Removes the complete entry in the communication frame for 'ipNum'.
#       It should not be called by itself; only from 'SetCommEntry'.
#       
# Arguments:
#       ipNum       the ip number.
#       
# Results:
#       updated communication frame.

proc ::WB::RemoveCommEntry {wtop ipNum} {
    global  prefs
    
    upvar ::UI::icons icons
    variable commTo
    variable commFrom
    variable ipNum2iEntry
    upvar ::${wtop}::wapp wapp
    
    set wCan  $wapp(can)
    set wcomm $wapp(comm)
    set wall  $wapp(frall)
    
    if {[string equal $wtop "."]} {
	set wtopReal .
    } else {
	set wtopReal [string trimright $wtop .]
    }
    set contactOffImage [::Theme::GetImage [option get $wall contactOffImage {}]]
    
    # Find widget paths from ipNum and remove the entries.
    set no $ipNum2iEntry($wtop,$ipNum)

    Debug 2 "RemoveCommEntry:: no=$no"
    
    # Size administration is very tricky; blood, sweat and tears...
    # Fix the canvas size to relax wm geometry. - 2 ???
    if {$prefs(haveScrollbars)} {
	$wCan configure -height [winfo height $wCan]  \
	  -width [winfo width $wCan]
    } else {
	$wCan configure -height [expr [winfo height $wCan] - 2]  \
	  -width [expr [winfo width $wCan] - 2]
    }
    
    # Switch off the geometry constraint to let resize automatically.
    wm geometry $wtopReal {}
    wm minsize $wtopReal 0 0
    
    # Remove the widgets.
    catch {grid forget $wcomm.ad$no $wcomm.us$no $wcomm.to$no   \
      $wcomm.from$no}
    catch {destroy $wcomm.ad$no $wcomm.us$no $wcomm.to$no   \
      $wcomm.from$no}
    
    # These variables must be unset to indicate that entry does not exists.
    catch {unset commTo($wtop,$ipNum)}
    catch {unset commFrom($wtop,$ipNum)}
    
    # Electric plug disconnect? Only for client only (and jabber).
    if {[string equal $prefs(protocol) "jabber"]} {
	after 400 [list $wcomm.icon configure -image $contactOffImage]
    }
    update idletasks
    
    # Organize the new geometry. First fix using wm geometry, then relax
    # canvas size.
    set newGeom [::UI::ParseWMGeometry $wtopReal]
    wm geometry $wtopReal [lindex $newGeom 0]x[lindex $newGeom 1]
    $wCan configure -height 1 -width 1
    
    # Geometry considerations. Update geometry vars and set new minsize.
    after idle [list [namespace current]::SetNewWMMinsize $wtop]
}

# WB::FixMenusWhen --
#       
#       Sets the correct state for menus and buttons when 'what'.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       what        "connect", "disconnect", "disconnectserver"
#
# Results:

proc ::WB::FixMenusWhen {wtop what} {
    global  prefs wDlgs
    
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    variable fixMenusCallback
    
    set mfile ${wtop}menu.file 
    set wtray $wapp(tray)
    
    switch -exact -- $what {
	connect {
	    
	    # If client only, allow only one connection, limited.
	    switch -- $prefs(protocol) {
		jabber {
		    if {[string equal $opts(-state) "normal"] &&  \
		      [string equal $opts(-sendbuttonstate) "normal"]} {
			$wtray buttonconfigure send -state normal
		    }
		}
		symmetric {
		    ::UI::MenuMethod $mfile entryconfigure mPutFile -state normal
		    ::UI::MenuMethod $mfile entryconfigure mPutCanvas -state normal
		    ::UI::MenuMethod $mfile entryconfigure mGetCanvas -state normal
		}
		client {
		    $wtray buttonconfigure connect -state disabled
		    ::UI::MenuMethod $mfile entryconfigure mOpenConnection -state disabled
		    ::UI::MenuMethod $mfile entryconfigure mPutFile -state normal
		    ::UI::MenuMethod $mfile entryconfigure mPutCanvas -state normal
		    ::UI::MenuMethod $mfile entryconfigure mGetCanvas -state normal
		}
		server {
		    ::UI::MenuMethod $mfile entryconfigure mPutFile -state normal
		    ::UI::MenuMethod $mfile entryconfigure mPutCanvas -state normal
		    ::UI::MenuMethod $mfile entryconfigure mGetCanvas -state normal
		}
		default {
		    ::UI::MenuMethod $mfile entryconfigure mOpenConnection -state disabled
		    $wtray buttonconfigure connect -state disabled
		}
	    }	    
	}
	disconnect {
	    
	    switch -- $prefs(protocol) {
		jabber {
		    $wtray buttonconfigure send -state disabled
		}
		client {
		    $wtray buttonconfigure connect -state normal
		    ::UI::MenuMethod $mfile entryconfigure mOpenConnection -state normal
		}
	    }
	    
	    # If no more connections left, make menus consistent.
	    if {[llength [::Network::GetIP to]] == 0} {
		::UI::MenuMethod $mfile entryconfigure mPutFile -state disabled
		::UI::MenuMethod $mfile entryconfigure mPutCanvas -state disabled
		::UI::MenuMethod $mfile entryconfigure mGetCanvas -state disabled
	    }
	}
	disconnectserver {
	    
	    # If no more connections left, make menus consistent.
	    if {[llength [::Network::GetIP to]] == 0} {
		::UI::MenuMethod $mfile entryconfigure mPutFile -state disabled
		::UI::MenuMethod $mfile entryconfigure mPutCanvas -state disabled
		::UI::MenuMethod $mfile entryconfigure mGetCanvas -state disabled
	    }
	}
    }
    
    # Invoke any callbacks from 'addons'.
    foreach cmd $fixMenusCallback {
	eval {$cmd} ${wtop}menu $what
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
    variable fixMenusCallback

    set wtop [::UI::GetToplevelNS $w]
    upvar ::${wtop}::opts opts

    if {$opts(-state) == "normal"} {
	::UI::MenuMethod ${wtop}menu.edit entryconfigure mPaste -state normal
    } else {
	::UI::MenuMethod ${wtop}menu.edit entryconfigure mPaste -state disabled
    }
    
    # Invoke any callbacks from 'addons'.
    foreach cmd $fixMenusCallback {
	eval {$cmd} ${wtop}menu "copy"
    }
}

# WB::BuildItemMenu --
#
#       Creates an item menu from all files in the specified directory.
#    
# Arguments:
#       wmenu       the menus widget path name (".menu.items").
#       itemDir     The directory to search the item files in.
#       
# Results:
#       item menu with submenus built.

proc ::WB::BuildItemMenu {wtop wmenu itemDir} {
    global  prefs
    
    upvar ::${wtop}::wapp wapp
    
    set wCan $wapp(can)
    set m [menu $wmenu -tearoff 0]
    set wparent [winfo parent $wmenu]
    
    # Use grand parents class to identify cascade.
    set wgrandparent [winfo parent $wparent]
    if {[string equal [winfo class $wgrandparent] "Menu"]} {
	set txt [file tail $itemDir]
    } else {
	set txt [::msgcat::mc mItems]
    }
    
    # A trick to make this work for popup menus, which do not have a Menu parent.
    if {[string equal [winfo class $wparent] "Menu"]} {
	$wparent add cascade -label $txt -menu $m -underline 0
    }
    
    # If we don't have a menubar, for instance, if embedded toplevel.
    # Only for the toplevel menubar.
    if {[string equal $wparent ".menu"] &&  \
      [string equal [winfo class $wparent] "Frame"]} {
	label ${wmenu}la -text $txt
	pack ${wmenu}la -side left -padx 4
	bind ${wmenu}la <Button-1>  \
	  [list [namespace current]::DoTopMenuPopup %W $wtop $m]
    }
    
    # Save old dir, and cd to the wanted one; glob works in present directory.
    set oldDir [pwd]
    cd $itemDir
    set allItemFiles [glob -nocomplain *]
    foreach itemFile $allItemFiles {
	set itemFile [string trim $itemFile :]
	
	# Keep only .can files and dirs.
	if {[string equal [file extension $itemFile] ".can"]} {
	    $m add command -label [file rootname $itemFile]  \
	      -command [list ::CanvasFile::DrawCanvasItemFromFile $wtop  \
	      [file join $itemDir $itemFile]]
	} elseif {[file isdirectory $itemFile]} {
	    
	    # Sort out directories we shouldn't search.
	    if {([string index $itemFile 0] == ".") ||  \
	      [string equal [string tolower $itemFile] "resource.frk"] || \
	      [string equal [string tolower $itemFile] "cvs"]} {
		continue
	    }
	    
	    # Skip if no *.can file.
	    if {[llength [glob -nocomplain -directory  \
	      [file join $itemDir $itemFile] *.can]] == 0} {
		continue
	    }
	    
	    # Build menus recursively. Consider: 1) large chars, 2) multi words,
	    # 3) dots.
	    regsub -all -- " " [string tolower $itemFile] "_" mt
	    regsub -all -- {\.} $mt "_" mt
	    BuildItemMenu $wtop ${wmenu}.${mt} [file join $itemDir $itemFile]
	}
    }
    cd $oldDir
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
	$mt add radio -label $afont -variable ::${wtop}::state(font)  \
	  -command [list ::WB::FontChanged $wtop name]
    }
    
    # Be sure that the presently selected font family is still there,
    # else choose helvetica.
    set fontStateVar ::${wtop}::state(font)
    if {[lsearch -exact $allFonts $fontStateVar] == -1} {
	set ::${wtop}::state(font) {Helvetica}
    }
}

proc ::WB::BuildToolPopupFontMenu {wtop allFonts} {
    upvar ::${wtop}::wapp wapp
    
    set wtool $wapp(tool)
    set mt ${wtool}.poptext.mfont
    
    $mt delete 0 end
    foreach afont $allFonts {
	$mt add radio -label $afont -variable ::${wtop}::state(font)  \
	  -command [list ::WB::FontChanged $wtop name]
    }
}

proc ::WB::BuildCanvasPopupFontMenu {w wmenu id allFonts} {

    set mt $wmenu    
    $mt delete 0 end
    foreach afont $allFonts {
	$mt add radio -label $afont -variable ::WB::popupVars(-fontfamily)  \
	  -command [list ::CanvasUtils::SetTextItemFontFamily $w $id $afont]
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

    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::state state
    
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
    upvar ::${wtop}::wapp wapp
    
    set waveImage [::Theme::GetImage [option get $wapp(frall) waveImage {}]]  
    ::UI::StartStopAnimatedWave $wapp(statmess) $waveImage $start
}

proc ::WB::StartStopAnimatedWaveOnMain {start} {    
    upvar ::.::wapp wapp
    
    set waveImage [::Theme::GetImage [option get $wapp(frall) waveImage {}]]  
    ::UI::StartStopAnimatedWave $wapp(statmess) $waveImage $start
}

# ::WB::GetThemeImage --
# 
#       This is a method to first search for any image file using
#       the standard theme engine, but use hardcoded icons as fallback.

proc ::WB::GetThemeImage {name} {
    variable iconsPreloaded
    
    set imname [::Theme::GetImage $name]
    if {$imname == ""} {
	set imname $iconsPreloaded($name)
    }
    return $imname
}

#-------------------------------------------------------------------------------

