#  UI.tcl ---
#  
#      This file is part of the whiteboard application. It implements user
#      interface elements.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: UI.tcl,v 1.30 2003-12-13 17:54:41 matben Exp $

# LabeledFrame --
#
#       A small utility that makes a nice frame with a label.
#      'wpath' is the widget path of the parent (it should be a frame); 
#      the return value is the widget path to the interior of the container.
#       
# Arguments:
#       wpath     the widget path of the parent (it should be a frame).
#       txt       the text
#       args
#       
# Results:
#       frame container created

package require entrycomp

proc LabeledFrame {wpath txt args} {
    
    set fontSB [option get . fontSmallBold {}]
    
    pack [frame $wpath.st -borderwidth 0]  \
      -side top -fill both -pady 2 -padx 2 -expand true
    pack [frame $wpath.st.fr -relief groove -bd 2]  \
      -side top -fill both -expand true -padx 10 -pady 10 -ipadx 0 -ipady 0  \
      -in $wpath.st
    place [label $wpath.st.lbl -text $txt -font $fontSB -bd 0 -padx 6]  \
      -in $wpath.st -x 20 -y 14 -anchor sw
    return $wpath.st.fr
}

proc LabeledFrame2 {wpath txt args} {

    set fontSB [option get . fontSmallBold {}]
    
    frame $wpath -borderwidth 0
    pack [frame $wpath.st -borderwidth 0]  \
      -side top -fill both -pady 2 -padx 2 -expand true
    pack [frame $wpath.st.fr -relief groove -bd 2]  \
      -side top -fill both -expand true -padx 10 -pady 10 -ipadx 0 -ipady 0  \
      -in $wpath.st
    place [label $wpath.st.lbl -text $txt -font $fontSB -bd 0 -padx 6]  \
      -in $wpath.st -x 20 -y 14 -anchor sw
    return $wpath.st.fr
}

proc LabeledFrame3 {w txt args} {

    set fontSB [option get . fontSmallBold {}]
    
    frame $w -borderwidth 0
    pack [frame $w.pad] -side top
    pack [frame $w.cont -relief groove -bd 2] -side top -fill both -expand 1
    place [label $w.l -text $txt -font $fontSB -bd 0] -x 20 -y 0 -anchor nw
    set h [winfo reqheight $w.l]
    $w.pad configure -height [expr $h-4]
    return $w.cont
}

# MessageText --
#
#       Used instead of 'message' widget to handle -fill x properly.
#       
# Arguments:
#       w
#       args
#       
# Results:
#       w

proc MessageText {w args} {
    global  prefs
    
    #puts "w=$w"
    
    array set argsArr {-text ""}
    array set argsArr $args
    array set argsArr [list -borderwidth 0 -bd 0 -wrap word -width 20]
    set theText $argsArr(-text)
    unset argsArr(-text)
    catch {unset argsArr(-aspect)}
    eval {text $w} [array get argsArr]
    $w insert 1.0 $theText
    
    # Figure out number of lines.
    #set endInd [$w index end-1char]
    foreach {x y w h} [$w bbox end-1char] break
    #set dlineinfo [$w dlineinfo end-1char]
    array set fontMetrics [font metrics [$w cget -font]]
    set linespace $fontMetrics(-linespace)
    #set base [lindex $dlineinfo 3]
    #set height [expr ($y + $h)/$fontMetrics(-linespace)]
    #puts "y=$y, h=$h, linespace=$fontMetrics(-linespace)"
    set height 5
    $w configure -height $height
    return $w
}


namespace eval ::UI:: {

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
    
    variable accelBindsToMain {}
    
    # Addon stuff.
    variable fixMenusCallback {}
    variable menuSpecPublic
    set menuSpecPublic(wpaths) {}
}

# UI::Init --
# 
#       Various initializations for the UI stuff.

proc ::UI::Init {} {
    global  this prefs
    
    ::Debug 2 "::UI::Init"
    
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
    variable icons    
    variable smiley
    variable smileyExp
    variable smileyLongNames
    
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
    
    # Defines canvas binding tags suitable for each tool.
    ::CanvasUtils::DefineWhiteboardBindtags
    
    variable allWhiteboards {}

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
    set btShortDefs(this) $btShortDefs($prefs(protocol))
        
    # Get icons.
    set icons(igelpiga) [image create photo igelpiga -format gif \
      -file [file join $this(path) images igelpiga.gif]]
    set icons(brokenImage) [image create photo -format gif  \
      -file [file join $this(path) images brokenImage.gif]]
    foreach name {connect save open import send print stop inbox inboxLett} {
	set icons(bt$name) [image create photo bt$name -format gif  \
	  -file [file join $this(path) images ${name}.gif]]
	set icons(bt${name}dis) [image create photo bt${name}dis -format gif \
	  -file [file join $this(path) images ${name}Dis.gif]]
    }
    foreach {name fname} {
	btnew     newmsg 
	bttrash   trash
	btsend    send
	btquote   quote 
	btreply   reply
	btforward forward
	btnewuser newuser} {
	set icons($name) [image create photo -format gif  \
	  -file [file join $this(path) images ${fname}.gif]]
	set icons(${name}dis) [image create photo -format gif  \
	  -file [file join $this(path) images ${fname}Dis.gif]]
    }	
	
    foreach iconFile {resizehandle bluebox contact_off contact_on wave} {
	set icons($iconFile) [image create photo -format gif  \
	  -file [file join $this(path) images $iconFile.gif]]
    }
    set icons(bwrect) [image create photo bwrect -format gif  \
      -file [file join $this(path) images transparent_rect.gif]]
    
    # Icons for the mailbox.
    set icons(readMsg) [image create photo -data {
R0lGODdhDgAKAKIAAP/////xsOjboMzMzHNzc2NjzjExYwAAACwAAAAADgAK
AAADJli6vFMhyinMm1NVAkPzxdZhkhh9kUmWBie8cLwZdG3XxEDsfM8nADs=
}]
    set icons(unreadMsg) [image create photo -data {
R0lGODdhDgAKALMAAP/////xsOjboMzMzIHzeXNzc2Njzj7oGzXHFzExYwAA
AAAAAAAAAAAAAAAAAAAAACwAAAAADgAKAAAENtBIcpC8cpgQKOKgkGicB0pi
QazUUQVoUhhu/YXyZoNcugUvXsAnKBqPqYRyyVwWBoWodCqNAAA7
}]
    set icons(wbicon) [image create photo -data {
R0lGODdhFQANALMAAP/////n5/9ze/9CQv8IEOfn/8bO/621/5ycnHN7/zlK
/wC9AAAQ/wAAAAAAAAAAACwAAAAAFQANAAAEWrDJSWtFDejN+27YZjAHt5wL
B2aaopAbmn4hMBYH7NGskmi5kiYwIAwCgJWNUdgkGBuBACBNhnyb4IawtWaY
QJ2GO/YCGGi0MDqtKnccohG5stgtiLx+z+8jIgA7	
}]
    set icons(wboard) [image create photo -format gif \
      -file [file join $this(path) images wb.gif]]
    
    
    # Smiley icons. The "short" types.
    foreach {key name} {
	":-)"          classic 
	":-("          sad 
	":-0"          shocked 
	";-)"          wink
	";("           cry
	":o"           embarrassed
	":D"           grin
	"x)"           knocked
	":|"           normal
	":S"           puzzled
	":p"           silly
	":O"           shocked
	":x"           speechless} {
	    set imSmile($name) [image create photo -format gif  \
	      -file [file join $this(path) images smileys "smiley-${name}.gif"]]
	    set smiley($key) $imSmile($name)
    }
    
    # Duplicates:
    foreach {key name} {
	":)"           classic 
	";)"           wink} {
	    set smiley($key) $imSmile($name)
    }
    set smileyExp {(}
    foreach key [array names smiley] {
	append smileyExp "$key|"
    }
    set smileyExp [string trimright $smileyExp "|"]
    append smileyExp {)}
    regsub  {[)(|]} $smileyExp {\\\0} smileyExp
    
    # The "long" smileys are treated differently; only loaded when needed.
    set smileyLongNames {
	:alien:
	:angry:
	:bandit:
	:beard:
	:bored:
	:calm:
	:cat:
	:cheeky:
	:cheerful:
	:chinese:
	:confused:
	:cool:
	:cross-eye:
	:cyclops:
	:dead:
	:depressed:
	:devious:
	:disappoin:
	:ditsy:
	:dog:
	:ermm:
	:evil:
	:evolved:
	:gasmask:
	:glasses:
	:happy:
	:hurt:
	:jaguar:
	:kommie:
	:laugh:
	:lick:
	:mad:
	:nervous:
	:ninja:
	:ogre:
	:old:
	:paranoid:
	:pirate:
	:ponder:
	:puzzled:
	:rambo:
	:robot:
	:eek:
	:shocked:
	:smiley:
	:sleeping:
	:smoker:
	:surprised:
	:tired:
	:vampire:
    }
}

# UI::InitMenuDefs --
# 
#       The menu organization.

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
      {command   mAboutCoccinella    {::SplashScreen::SplashScreen $wDlgs(splash)} normal   {}}
    set menuDefs(main,info,aboutquicktimetcl)  \
      {command   mAboutQuickTimeTcl  {::Dialogs::AboutQuickTimeTcl}                normal   {}}

    # Mac only.
    set menuDefs(main,apple) [list $menuDefs(main,info,aboutwhiteboard)  \
      $menuDefs(main,info,aboutquicktimetcl)]
    
    set menuDefsMainFileJabber {
	{command   mNew                {::UI::NewWhiteboard -sendcheckstate disabled}   normal   N}
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
    if {0} {
	set menuDefs(main,prefs,straighten)  \
	  {command     mStraighten       {::CanvasUtils::ItemStraighten $w $id} normal   {} {}}
    }
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
    foreach dash [lsort -decreasing [array names ::UI::dashFull2Short]] {
	set dashval $::UI::dashFull2Short($dash)
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
	{radio   1                 {::UI::FontChanged $wtop size}          normal   {} \
	  {-variable ::${wtop}::state(fontSize)}}
	{radio   2                 {::UI::FontChanged $wtop size}          normal   {} \
	  {-variable ::${wtop}::state(fontSize)}}
	{radio   3                 {::UI::FontChanged $wtop size}          normal   {} \
	  {-variable ::${wtop}::state(fontSize)}}
	{radio   4                 {::UI::FontChanged $wtop size}          normal   {} \
	  {-variable ::${wtop}::state(fontSize)}}
	{radio   5                 {::UI::FontChanged $wtop size}          normal   {} \
	  {-variable ::${wtop}::state(fontSize)}}
	{radio   6                 {::UI::FontChanged $wtop size}          normal   {} \
	  {-variable ::${wtop}::state(fontSize)}}}
    }
    set menuDefs(main,prefs,fontweight)  \
      {cascade     mWeight           {}                                    normal   {} {} {
	{radio   mNormal           {::UI::FontChanged $wtop weight}        normal   {} \
	  {-value normal -variable ::${wtop}::state(fontWeight)}}
	{radio   mBold             {::UI::FontChanged $wtop weight}        normal   {} \
	  {-value bold -variable ::${wtop}::state(fontWeight)}}
	{radio   mItalic           {::UI::FontChanged $wtop weight}        normal   {} \
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
	{command   mNewWhiteboard    {::UI::NewWhiteboard}                       normal   N}
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
	  {-variable ::UI::popupVars(-width)}}
	{radio   2 {::CanvasUtils::ItemConfigure $w $id -width 2}          normal   {} \
	  {-variable ::UI::popupVars(-width)}}
	{radio   4 {::CanvasUtils::ItemConfigure $w $id -width 4}          normal   {} \
	  {-variable ::UI::popupVars(-width)}}
	{radio   6 {::CanvasUtils::ItemConfigure $w $id -width 6}          normal   {} \
	  {-variable ::UI::popupVars(-width)}}}
    }
    set menuDefs(pop,brushthickness)  \
      {cascade     mBrushThickness  {}                                     normal   {} {} {
	{radio   8 {::CanvasUtils::ItemConfigure $w $id -width 8}          normal   {} \
	  {-variable ::UI::popupVars(-brushwidth)}}
	{radio  10 {::CanvasUtils::ItemConfigure $w $id -width 10}         normal   {} \
	  {-variable ::UI::popupVars(-brushwidth)}}
	{radio  12 {::CanvasUtils::ItemConfigure $w $id -width 12}         normal   {} \
	  {-variable ::UI::popupVars(-brushwidth)}}
	{radio  14 {::CanvasUtils::ItemConfigure $w $id -width 14}         normal   {} \
	  {-variable ::UI::popupVars(-brushwidth)}}}
    }
    set menuDefs(pop,arcs)  \
      {cascade   mArcs             {}                                      normal   {} {} {
	{radio   mPieslice         {}                                      normal   {} \
	  {-value pieslice -variable ::UI::popupVars(-arc)}}
	{radio   mChord            {}                                      normal   {} \
	  {-value chord -variable ::UI::popupVars(-arc)}}
	{radio   mArc              {}                                      normal   {} \
	  {-value arc -variable ::UI::popupVars(-arc)}}}
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
	  {-value 0 -variable ::UI::popupVars(-smooth)}}
	{radio 2    {::CanvasUtils::ItemConfigure $w $id -smooth 1 -splinesteps  2} normal {} \
	  {-value 2 -variable ::UI::popupVars(-smooth)}}
	{radio 4    {::CanvasUtils::ItemConfigure $w $id -smooth 1 -splinesteps  4} normal {} \
	  {-value 4 -variable ::UI::popupVars(-smooth)}}
	{radio 6    {::CanvasUtils::ItemConfigure $w $id -smooth 1 -splinesteps  6} normal {} \
	  {-value 6 -variable ::UI::popupVars(-smooth)}}
	{radio 10   {::CanvasUtils::ItemConfigure $w $id -smooth 1 -splinesteps 10} normal {} \
	  {-value 10 -variable ::UI::popupVars(-smooth)}}}
    }
    set menuDefs(pop,smooth)  \
      {checkbutton mLineSmoothness   {::CanvasUtils::ItemSmooth $w $id}    normal   {} \
      {-variable ::UI::popupVars(-smooth) -offvalue 0 -onvalue 1}}
    set menuDefs(pop,straighten)  \
      {command     mStraighten       {::CanvasUtils::ItemStraighten $w $id} normal   {} {}}
    set menuDefs(pop,font)  \
      {cascade     mFont             {}                                    normal   {} {} {}}
    set menuDefs(pop,fontsize)  \
      {cascade     mSize             {}                                    normal   {} {} {
	{radio   1  {::CanvasUtils::SetTextItemFontSize $w $id 1}          normal   {} \
	  {-variable ::UI::popupVars(-fontsize)}}
	{radio   2  {::CanvasUtils::SetTextItemFontSize $w $id 2}          normal   {} \
	  {-variable ::UI::popupVars(-fontsize)}}
	{radio   3  {::CanvasUtils::SetTextItemFontSize $w $id 3}          normal   {} \
	  {-variable ::UI::popupVars(-fontsize)}}
	{radio   4  {::CanvasUtils::SetTextItemFontSize $w $id 4}          normal   {} \
	  {-variable ::UI::popupVars(-fontsize)}}
	{radio   5  {::CanvasUtils::SetTextItemFontSize $w $id 5}          normal   {} \
	  {-variable ::UI::popupVars(-fontsize)}}
	{radio   6  {::CanvasUtils::SetTextItemFontSize $w $id 6}          normal   {} \
	  {-variable ::UI::popupVars(-fontsize)}}}
    }
    set menuDefs(pop,fontweight)  \
      {cascade     mWeight           {}                                    normal   {} {} {
	{radio   mNormal {::CanvasUtils::SetTextItemFontWeight $w $id normal} normal   {} \
	  {-value normal -variable ::UI::popupVars(-fontweight)}}
	{radio   mBold {::CanvasUtils::SetTextItemFontWeight $w $id bold}  normal   {} \
	  {-value bold   -variable ::UI::popupVars(-fontweight)}}
	{radio   mItalic {::CanvasUtils::SetTextItemFontWeight $w $id italic} normal   {} \
	  {-value italic -variable ::UI::popupVars(-fontweight)}}}
    }	
    set menuDefs(pop,speechbubble)  \
      {command   mAddSpeechBubble  {::CanvasDraw::MakeSpeechBubble $w $id}   normal {}}
    
    # Dashes need a special build process.
    set dashList {}
    foreach dash [lsort -decreasing [array names ::UI::dashFull2Short]] {
	set dashval $::UI::dashFull2Short($dash)
	if {[string equal " " $dashval]} {
	    set dopts {-value { } -variable ::UI::popupVars(-dash)}
	} else {
	    set dopts [format {-value %s -variable ::UI::popupVars(-dash)} $dashval]
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

proc ::UI::GetIcon {name} {
    variable icons
    
    if {[info exists icons($name)]} {
	return $icons($name)
    } else {
	return -code error "icon named \"$name\" does not exist"
    }
}

# UI::NewWhiteboard --
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

proc ::UI::NewWhiteboard {args} {    
    variable uidmain
    
    # Need to reuse ".". Outdated!
    if {[wm state .] == "normal"} {
	set wtop .wb[incr uidmain].
    } else {
	set wtop .
    }
    eval {::UI::BuildWhiteboard $wtop} $args
    return $wtop
}

# UI::BuildWhiteboard --
#
#       Makes the main toplevel window.
#
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       args        see above
#       
# Results:
#       new instance toplevel created.

proc ::UI::BuildWhiteboard {wtop args} {
    global  this prefs privariaFlag
    
    variable allWhiteboards
    variable dims
    variable icons
    variable threadToWtop
    variable jidToWtop
    
    Debug 2 "::UI::BuildWhiteboard wtop=$wtop, args='$args'"
    
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
	set wtopReal .
    } else {
	set wtopReal [string trimright $wtop .]
    }
    
    # Common widget paths.
    if {$prefs(haveScrollbars)} {
	set wapp(can)       ${wtop}fmain.fc.can
	set wapp(xsc)       ${wtop}fmain.fc.xsc
	set wapp(ysc)       ${wtop}fmain.fc.ysc
    } else {
	set wapp(can)       ${wtop}fmain.can
    }
    set wapp(toplevel)  $wtopReal
    set wapp(tool)      ${wtop}fmain.frleft.frbt
    set wapp(comm)      ${wtop}fcomm.ent
    set wapp(statmess)  ${wtop}fcomm.stat.lbl
    set wapp(tray)      ${wtop}frtop.on.fr
    set wapp(servCan)   $wapp(can)
    set wapp(topchilds) [list ${wtop}menu ${wtop}frtop ${wtop}fmain ${wtop}fcomm]
    
    set tmpImages {}
    
    # Init some of the state variables.
    # Inherit from the factory + preferences state.
    array set state [array get ::state]
    if {$opts(-state) == "disabled"} {
	set state(btState) 00
    }
    
    if {![winfo exists $wtopReal] && ($wtop != ".")} {
	toplevel $wtopReal -class Whiteboard
	wm withdraw $wtopReal
    }
    wm title $wtopReal $opts(-title)
    wm protocol $wtopReal WM_DELETE_WINDOW [list ::UI::CloseWhiteboard $wtop]
    
    set fontS [option get . fontSmall {}]
    
    # Note that the order of calls can be criticl as any 'update' may trigger
    # network events to attempt drawing etc. Beware!!!
     
    # Start with menus.
    ::UI::BuildWhiteboardMenus $wtop
        
    # Shortcut buttons at top? Do we want the toolbar to be visible.
    if {$state(visToolbar)} {
	::UI::ConfigShortcutButtonPad $wtop init
    } else {
	::UI::ConfigShortcutButtonPad $wtop init off
    }
    
    # Special configuration of shortcut buttons.
    if {[info exists opts(-type)] && [string equal $opts(-type) "normal"]} {
	$wapp(tray) buttonconfigure stop -command  \
	  [list ::Import::HttpResetAll $wtop]
    }

    # Make the connection frame.
    pack [frame ${wtop}fcomm] -side bottom -fill x
    
    # Status message part.
    pack [frame ${wtop}fcomm.st -relief raised -borderwidth 1]  \
      -side top -fill x -pady 0
    pack [frame ${wtop}fcomm.stat -relief groove -bd 2]  \
      -side top -fill x -padx 10 -pady 2 -in ${wtop}fcomm.st
    pack [canvas $wapp(statmess) -bd 0 -highlightthickness 0 -height 14]  \
      -side left -pady 1 -padx 6 -fill x -expand true
    $wapp(statmess) create text 0 0 -anchor nw -text {} -font $fontS \
      -tags stattxt
    
    # Build the header for the actual network setup.
    ::UI::SetCommHead $wtop $prefs(protocol) -connected $isConnected
    pack [frame ${wtop}fcomm.pad -relief raised -borderwidth 1]  \
      -side right -fill both -expand true
    pack [label ${wtop}fcomm.pad.hand -relief flat -borderwidth 0  \
      -image $icons(resizehandle)] \
      -side right -anchor sw
    
    # Do we want a persistant jabber entry?
    if {[string equal $prefs(protocol) "jabber"]} {
	::Jabber::InitWhiteboard $wtop
    	if {$prefs(jabberCommFrame)} {
	    eval {::Jabber::BuildJabberEntry $wtop} $args
    	}
    }
    
    # Make the tool button pad.
    pack [frame ${wtop}fmain -borderwidth 0 -relief flat] \
      -side top -fill both -expand true
    pack [frame ${wtop}fmain.frleft] -side left -fill y
    pack [frame $wapp(tool)] -side top
    pack [frame ${wtop}fmain.frleft.pad -relief raised -borderwidth 1]  \
      -fill both -expand true
    
    # The 'Coccinella'.
    pack [label ${wtop}fmain.frleft.pad.bug -borderwidth 0 -image igelpiga]  \
      -side bottom
    
    # Make the tool buttons and invoke the one from the prefs file.
    ::UI::CreateAllButtons $wtop
    
    # ...and the drawing canvas.
    if {$prefs(haveScrollbars)} {
	set f [frame ${wtop}fmain.fc -bd 1 -relief raised]
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
    ::UI::SetToolButton $wtop [::UI::ToolBtNumToName $state(btState)]

    # Add things that are defined in the prefs file and not updated else.
    ::UserActions::DoCanvasGrid $wtop
    if {$isConnected} {
    	::UI::FixMenusWhen $wtop "connect"
    }

    # Set up paste menu if something on the clipboard.
    ::UI::WhiteboardGetFocus $wtop $wtopReal
    bind $wtopReal <FocusIn> [list ::UI::WhiteboardGetFocus $wtop %W]
    
    # Create the undo/redo object.
    set state(undotoken) [undo::new -command [list ::UI::UndoConfig $wtop]]
    
    # Set window position only for the first whiteboard on screen.
    # Subsequent whiteboards are placed by the window manager.
    if {[llength [::UI::GetAllWhiteboards]] == 0} {
	
	# Setting the window position never hurts. Check that it fits to screen.
	if {$dims(x) > [expr [winfo vrootwidth .] - 30]} {
	    set dims(x) 30
	}
	if {$dims(y) > [expr [winfo vrootheight .] - 30]} {
	    set dims(y) 30
	}

	# Setting total (root) size should only be done if set in pref file!
	# Some window managers are tricky with the 'wm geometry' command.
	if {($dims(wRoot) > 1) && ($dims(hRoot) > 1)} {
	    wm geometry $wtopReal $dims(wRoot)x$dims(hRoot)+$dims(x)+$dims(y)
	    #update
	}
    }
    catch {wm deiconify $wtopReal}
    #raise $wtopReal     This makes the window flashing when showed (linux)
    lappend allWhiteboards $wtopReal

    # A trick to let the window manager be finished before getting the geometry.
    # An 'update idletasks' needed anyway in 'FindWBGeometry'.
    after idle ::UI::FindWBGeometry $wtop
    
    if {[info exists opts(-file)]} {
	::CanvasFile::DrawCanvasItemFromFile $wtop $opts(-file)
    }
}

# UI::CloseWhiteboard --
#
#       Called when closing whiteboard window; cleanup etc.

proc ::UI::CloseWhiteboard {wtop} {
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
    set topw $wapp(toplevel)
    set jtype [::UI::GetJabberType $wtop]

    Debug 3 "::UI::CloseWhiteboard wtop=$wtop, jtype=$jtype"

    switch -- $jtype {
	chat {
	    set ans [tk_messageBox -icon info -parent $topw -type yesno \
	      -message [FormatTextForMessageBox "The complete conversation will\
	      be lost when closing this chat whiteboard.\
	      Do you actually want to end this chat?"]]
	    if {$ans != "yes"} {
		return
	    }
	    ::UI::DestroyMain $wtop
	}
	groupchat {
	    
	    # Everything handled from Jabber::GroupChat
	    set ans [::Jabber::GroupChat::Exit $opts(-jid)]
	    if {$ans != "yes"} {
		return
	    }
	}
	default {
	    ::UI::DestroyMain $wtop
	}
    }
    
    # Reset and cancel all put/get file operations related to this window!
    # I think we let put operations go on.
    #::PutFileIface::CancelAllWtop $wtop
    ::GetFileIface::CancelAllWtop $wtop
    ::Import::HttpResetAll $wtop
}

# UI::DestroyMain --
# 
#       Destroys toplevel whiteboard and cleans up.
#       The "." is just withdrawn, else we would exit (jabber only).

proc ::UI::DestroyMain {wtop} {
    global  prefs
    
    variable menuKeyToIndex
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    upvar ::${wtop}::tmpImages tmpImages

    set wcan [::UI::GetCanvasFromWtop $wtop]
    
    # The last whiteboard that is destroyed sets preference state & dims.
    if {[llength [::UI::GetAllWhiteboards]] == 1} {
	
	# Save instance specific 'state' array into generic 'state'.
	::UI::SaveWhiteboardState $wtop
    }
    
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
	array unset menuKeyToIndex "${wtop}*"
    }
    
    # We could do some cleanup here.
    eval {image delete} $tmpImages
    ::CanvasUtils::ItemFree $wtop
    ::UI::FreeMenu $wtop
}

# UI::SaveWhiteboardState
# 
# 

proc ::UI::SaveWhiteboardState {wtop} {
    global  prefs

    upvar ::UI::dims dims
    upvar ::${wtop}::wapp wapp
      
    # Read back instance specific 'state' into generic 'state'.
    array set ::state [array get ::${wtop}::state]

    # Widget geometries:
    ::UI::SaveWhiteboardDims $wtop
}

# UI::SaveWhiteboardDims --
# 
#       Stores the present whiteboard widget geom state in 'dims' array.

proc ::UI::SaveWhiteboardDims {wtop} {
    global  this

    upvar ::UI::dims dims
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

    Debug 3 "::UI::SaveWhiteboardDims dims(hRoot)=$dims(hRoot)"
}

# UI::SaveCleanWhiteboardDims --
# 
#       We want to save wRoot and hRoot as they would be without any connections 
#       in the communication frame. Non jabber only. Only needed when quitting
#       to get the correct dims when set from preferences when launched again.

proc ::UI::SaveCleanWhiteboardDims {wtop} {
    global prefs

    upvar ::UI::dims dims
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

# UI::AEQuitHandler --
#
#       Mac OS X only: callback for the quit Apple Event.

proc ::UI::AEQuitHandler {theAEDesc theReplyAE} {
    
    ::UserActions::DoQuit
}

# UI::ConfigureMain --
#
#       Configure the options 'opts' state of a whiteboard.
#       Returns 'opts' if no arguments.

proc ::UI::ConfigureMain {wtop args} {
    
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
    if {[string equal $wtop "."]} {
	set wtopReal .
    } else {
	set wtopReal [string trimright $wtop .]
    }
    if {[llength $args] == 0} {
	return [array get opts]
    } else {
    	set jentryOpts {}
	foreach {name value} $args {
	    switch -- $name {
		-title {
		    wm title $wtopReal $value    
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
	    eval {::UI::ConfigureJabberEntry $wtop {}} $jentryOpts
	}
    }
}

# UI::GetJabberType --
# 
#       Returns a typical 'type' attribute suitable for a message element.
#       If type unknown, or if "normal", return empty string.
#       Assumes that wtop exists.

proc ::UI::GetJabberType {wtop} {
    
    upvar ::${wtop}::opts opts

    set type ""
    if {[info exists opts(-type)]} {
	if {![string equal $opts(-type) "normal"]} {
	    set type $opts(-type)
	}
    }
    return $type
}

# UI::GetJabberChatThread --
# 
#       Returns the thread id for a whiteboard chat.

proc ::UI::GetJabberChatThread {wtop} {
    
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

# UI::GetWtopFromJabberType --
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

proc ::UI::GetWtopFromJabberType {type jid {thread {}}} {    
    variable threadToWtop
    variable jidToWtop

    ::Jabber::Debug 2 "::UI::GetWtopFromJabberType type=$type, jid=$jid, thread=$thread"
    
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

# UI::SetStatusMessage --

proc ::UI::SetStatusMessage {wtop msg} {
    
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

proc ::UI::GetServerCanvasFromWtop {wtop} {    
    upvar ::${wtop}::wapp wapp
    
    return $wapp(servCan)
}

proc ::UI::GetCanvasFromWtop {wtop} {    
    upvar ::${wtop}::wapp wapp
    
    return $wapp(can)
}

# UI::GetButtonState --
#
#       This is a utility function mainly for plugins to get the tool buttons 
#       state.

proc ::UI::GetButtonState {wtop} {
    upvar ::${wtop}::state state
    variable btNo2Name     

    return $btNo2Name($state(btState))
}

proc ::UI::GetUndoToken {wtop} {    
    upvar ::${wtop}::state state
    
    return $state(undotoken)
}

# UI::GetAllWhiteboards --
# 
#       Return all whiteboard's wtop as a list. 
#       Note: 'allWhiteboards' have real toplevel path.

proc ::UI::GetAllWhiteboards { } {    
    variable allWhiteboards    
    
    set allTops {}
    foreach w $allWhiteboards {
	if {[winfo exists $w] && ([wm state $w] == "normal")} {
	    lappend allTops $w
	}
    }
    set allWhiteboards [lsort -dictionary $allTops]
    return $allWhiteboards
}


# UI::SetToolButton --
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

proc ::UI::SetToolButton {wtop btName} {
    global  prefs wapp this
    
    variable icons
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::state state
    upvar ::${wtop}::opts opts

    Debug 3 "SetToolButton:: wtop=$wtop, btName=$btName"
    
    set wCan $wapp(can)
    set wtoplevel $wapp(toplevel)
    set state(btState) [::UI::ToolBtNameToNum $btName]
    set irow [string index $state(btState) 0]
    set icol [string index $state(btState) 1]
    $wapp(tool).bt$irow$icol configure -image $icons(on${irow}${icol})
    if {$state(btState) != $state(btStateOld)} {
	set irow [string index $state(btStateOld) 0]
	set icol [string index $state(btStateOld) 1]
	$wapp(tool).bt$irow$icol configure -image $icons(off${irow}${icol})
    }
    set oldButton $state(btStateOld)
    set oldBtName [::UI::ToolBtNumToName $oldButton]
    set state(btStateOld) $state(btState)
    ::UI::RemoveAllBindings $wCan
    
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
		    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatpointmac]
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
		    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatpoint]		      
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
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatmove]
	}
	line {
	    bindtags $wCan  \
	      [list $wCan WhiteboardLine WhiteboardNonText $wtoplevel all]
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatline]
	}
	arrow {
	    bindtags $wCan  \
	      [list $wCan WhiteboardArrow WhiteboardNonText $wtoplevel all]
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatarrow]
	}
	rect {
	    bindtags $wCan  \
	      [list $wCan WhiteboardRect WhiteboardNonText $wtoplevel all]
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatrect]
	}
	oval {
	    bindtags $wCan  \
	      [list $wCan WhiteboardOval WhiteboardNonText $wtoplevel all]
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatoval]
	}
	text {
	    bindtags $wCan  \
	      [list $wCan WhiteboardText $wtoplevel all]
	    ::CanvasText::EditBind $wCan
	    $wCan config -cursor xterm
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastattext]
	}
	del {
	    bindtags $wCan  \
	      [list $wCan WhiteboardDel WhiteboardNonText $wtoplevel all]
	    bind QTFrame <Button-1>  \
	      [subst {::CanvasDraw::DeleteFrame $wCan %W %x %y}]
	    bind SnackFrame <Button-1>  \
	      [subst {::CanvasDraw::DeleteFrame $wCan %W %x %y}]
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatdel]
	}
	pen {
	    bindtags $wCan  \
	      [list $wCan WhiteboardPen WhiteboardNonText $wtoplevel all]
	    $wCan config -cursor pencil
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatpen]
	}
	brush {
	    bindtags $wCan  \
	      [list $wCan WhiteboardBrush WhiteboardNonText $wtoplevel all]
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatbrush]
	}
	paint {
	    bindtags $wCan  \
	      [list $wCan WhiteboardPaint WhiteboardNonText $wtoplevel all]
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatpaint]	      
	}
	poly {
	    bindtags $wCan  \
	      [list $wCan WhiteboardPoly WhiteboardNonText $wtoplevel all]
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatpoly]	      
        }       
	arc {
	    bindtags $wCan  \
	      [list $wCan WhiteboardArc WhiteboardNonText $wtoplevel all]
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatarc]	      
	}
	rot {
	    bindtags $wCan  \
	      [list $wCan WhiteboardRot WhiteboardNonText $wtoplevel all]
	    $wCan config -cursor exchange
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatrot]	      
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

proc ::UI::GenericNonTextBindings {wtop} {
    
    upvar ::${wtop}::wapp wapp
    set wCan $wapp(can)
    
    # Various bindings.
    bind $wCan <BackSpace> [list ::CanvasDraw::DeleteItem $wCan %x %y selected]
    bind $wCan <Control-d> [list ::CanvasDraw::DeleteItem $wCan %x %y selected]
}

# UI::RemoveAllBindings --
#
#       Clears all application defined bindings in the canvas.
#       
# Arguments:
#       w      the canvas widget.
#       
# Results:
#       none

proc ::UI::RemoveAllBindings {w} {
    
    Debug 3 "::UI::RemoveAllBindings w=$w"

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

# UI::SaveWinGeom --
#
#       Call this when closing window to store its geometry. Window must exist!
#
# Arguments:
#       w           toplevel window and entry in storage array.
#       wreal       (D="") if set then $w is only entry in array, while $wreal
#                   is the actual toplevel window.
# 

proc ::UI::SaveWinGeom {w {wreal {}}} {
    global  prefs
    
    if {$wreal == ""} {
	set wreal $w
    }
    set prefs(winGeom,$w) [wm geometry $wreal]
}

# UI::SavePanePos --
#
#       Same for pane positions.

proc ::UI::SavePanePos {wtoplevel wpaned {orient horizontal}} {
    global  prefs
    
    array set infoArr [::pane::pane info $wpaned]
    if {[string equal $orient "horizontal"]} {
	set prefs(paneGeom,$wtoplevel)   \
	  [list $infoArr(-relwidth) [expr 1.0 - $infoArr(-relwidth)]]
    } else {
	
	# Vertical
	set prefs(paneGeom,$wtoplevel)   \
	  [list $infoArr(-relheight) [expr 1.0 - $infoArr(-relheight)]]
    }
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
    set mapWmenuToWtop($wmenu) $wtop

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
    global  this wDlgs prefs dashFull2Short osprefs
    
    variable menuKeyToIndex
    variable accelBindsToMain
    
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
		eval {::UI::BuildMenu $wtop ${wmenu}.${mt} $name $subdef $state} $args
		
		# Explicitly set any disabled state of cascade.
		::UI::MenuMethod $m entryconfigure $name -state $mstate
	    } else {
		
		# All variables (and commands) in menuDef's cmd shall be 
		# substituted! Be sure they are all in here.
		set cmd [subst -nocommands $cmd]
		if {[string length $accel] > 0} {
		    lappend mopts -accelerator ${mod}+${accel}
		    if {![string equal $this(platform) "macintosh"]} {
			set key [string map {< less > greater} [string tolower $accel]]
			
			if {[string equal $state "normal"]} {
			    if {[string equal $mstate "normal"]} {
				bind $topw <${mod}-Key-${key}> $cmd
				
				# Cache bindings for use in dialogs that inherit
				# main menu.
				if {$wtop == "."} {
				    lappend accelBindsToMain  \
				      [list <${mod}-Key-${key}> $cmd]
				}
			    }
			} else {
			    bind $topw <${mod}-Key-${key}> {}
			}			
		    }
		}
		eval {$m add $type -label $locname -command $cmd -state $mstate} $mopts 
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
#       Utility to use instead of 'menuPath cmd index args'.
#
# Arguments:
#       wmenu       menu's widget path
#       cmd         valid menu command
#       key         key to menus index
#       args
#       
# Results:
#       binds to toplevel changed

proc ::UI::MenuMethod {wmenu cmd key args} {
    global  this prefs wDlgs osprefs
            
    variable menuKeyToIndex
    variable mapWmenuToWtop
    variable cachedMenuSpec
        
    # Need to cache the complete menuSpec's since needed in MenuMethod.
    set wtop $mapWmenuToWtop($wmenu)
    set menuSpec $cachedMenuSpec($wtop,$wmenu)
    set mind $menuKeyToIndex($wmenu,$key)
    
    # This would be enough unless we need working accelerator keys.
    eval {$wmenu $cmd $mind} $args
    
    # Handle any menu accelerators as well. 
    # Make sure the necessary variables for the command exist here!
    if {![string equal $this(platform) "macintosh"]} {
	set ind [lsearch $args "-state"]
	if {$ind >= 0} {
	    set mstate [lindex $args [incr ind]]
	    if {$wtop == "."} {
		set topw .
	    } else {
		set topw [string trimright $wtop "."]
	    }
	    set mcmd [lindex [lindex $menuSpec $mind] 2]
	    set mcmd [subst -nocommands $mcmd]
	    set acc [lindex [lindex $menuSpec $mind] 4]
	    if {[string length $acc]} {
		set acckey [string map {< less > greater} [string tolower $acc]]
		if {[string equal $mstate "normal"]} {
		    bind $topw <$osprefs(mod)-Key-${acckey}> $mcmd
		} else {
		    bind $topw <$osprefs(mod)-Key-${acckey}> {}
		}			
	    }
	}
    }
}

# UI::BuildWhiteboardMenus --
#
#       Makes all menus for a toplevel window.
#
# Arguments:
#       wtop        toplevel window. ("." or ".main2." with extra dot!)
#       
# Results:
#       menu created

proc ::UI::BuildWhiteboardMenus {wtop} {
    global  this wDlgs prefs dashFull2Short osprefs
    
    variable menuDefs
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::state state
    upvar ::${wtop}::opts opts
        
    set topwindow $wapp(toplevel)
    set wCan $wapp(can)
    set wmenu ${wtop}menu
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
    ::UI::BuildItemMenu $wtop ${wmenu}.items $prefs(itemDir)
    
    # Addon or Plugin menus if any.
    ::UI::BuildPublicMenus $wtop $wmenu
    
    ::UI::NewMenu $wtop ${wmenu}.info mInfo $menuDefs(main,info) $opts(-state)

    # Handle '-state disabled' option. Keep Edit/Copy.
    if {$opts(-state) == "disabled"} {
	::UI::DisableWhiteboardMenus $wmenu
    }
    
    # Use a function for this to dynamically build this menu if needed.
    ::UI::BuildFontMenu $wtop $prefs(canvasFonts)    
        
    # End menus; place the menubar.
    if {$prefs(haveMenus)} {
	$topwindow configure -menu $wmenu
    } else {
	pack $wmenu -side top -fill x
    }
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

# UI::DisableWhiteboardMenus --
#
#       Handle '-state disabled' option. Sets in a readonly state.

proc ::UI::DisableWhiteboardMenus {wmenu} {
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
    # 'plugins' and 'addons'.
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

proc ::UI::Public::RegisterCallbackFixMenus {procName} {    
    upvar ::UI::fixMenusCallback fixMenusCallback
    
    lappend fixMenusCallback $procName
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

# UI::ConfigShortcutButtonPad --
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

proc ::UI::ConfigShortcutButtonPad {wtop what {subSpec {}}} {
    global  this wDlgs prefs
    
    variable dims
    variable icons
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    upvar ::${wtop}::state state    
    
    Debug 3 "::UI::ConfigShortcutButtonPad what=$what, subSpec=$subSpec"

    if {$wtop != "."} {
	set topw [string trimright $wtop .]
    } else {
	set topw $wtop
    }
    set wonbar ${wtop}frtop.on.barvert
    set woffbar ${wtop}frtop.barhoriz
    
    if {![winfo exists ${wtop}frtop]} {
	pack [frame ${wtop}frtop -relief raised -borderwidth 0] -side top -fill x
	pack [frame ${wtop}frtop.on -borderwidth 0] -fill x -side left -expand 1
	pack [label $wonbar -image $icons(barvert) -bd 1 -relief raised] \
	  -padx 0 -pady 0 -side left
	#pack [frame $wapp(tray) -relief raised -borderwidth 1]  \
	#  -side left -fill both -expand 1
	label $woffbar -image $icons(barhoriz) -relief raised -borderwidth 1
	bind $wonbar <Button-1> [list $wonbar configure -relief sunken]
	bind $wonbar <ButtonRelease-1>  \
	  [list ::UI::ConfigShortcutButtonPad $wtop "off"]
	
	# Build the actual shortcut button pad.
	::UI::BuildShortcutButtonPad $wtop
	pack $wapp(tray) -side left -fill both -expand 1
	if {$opts(-state) == "disabled"} {
	    ::UI::DisableShortcutButtonPad $wtop
	}
    }
 
    if {[string equal $what "init"]} {
    
	# Do we want the toolbar to be collapsed at initialization?
	if {[string equal $subSpec "off"]} {
	    pack forget ${wtop}frtop.on
	    ${wtop}frtop configure -bg gray75
	    pack $woffbar -side left -padx 0 -pady 0
	    bind $woffbar <ButtonRelease-1>   \
	      [list ::UI::ConfigShortcutButtonPad $wtop "on"]
	}
	
    } elseif {[string equal $what "off"]} {
	
	# Relax the min size; reset from 'SetNewWMMinsize' below.
	wm minsize $topw 0 0
	
	# New size, keep width.
	set size [::UI::ParseWMGeometry $topw]
	set newHeight [expr [lindex $size 1] - $dims(hTopOn) + $dims(hTopOff)]
	wm geometry ${topw} [lindex $size 0]x$newHeight
	pack forget ${wtop}frtop.on
	${wtop}frtop configure -bg gray75
	pack $woffbar -side left -padx 0 -pady 0
	bind $woffbar <Button-1> [list $woffbar configure -relief sunken]
	bind $woffbar <ButtonRelease-1>   \
	  [list ::UI::ConfigShortcutButtonPad $wtop "on"]
	after idle [list ::UI::SetNewWMMinsize $wtop]
	$wonbar configure -relief raised
	set state(visToolbar) 0

    } elseif {[string equal $what "on"]} {
	
	# New size, keep width.
	set size [::UI::ParseWMGeometry $topw]
	set newHeight [expr [lindex $size 1] - $dims(hTopOff) + $dims(hTopOn)]
	wm geometry ${topw} [lindex $size 0]x$newHeight
	pack forget $woffbar
	pack ${wtop}frtop.on -fill x -side left -expand 1
	$woffbar configure -relief raised
	bind $woffbar <Button-1> [list $woffbar configure -relief sunken]
	bind $woffbar <ButtonRelease-1>   \
	  [list ::UI::ConfigShortcutButtonPad $wtop "off"]
	after idle [list ::UI::SetNewWMMinsize $wtop]
	set state(visToolbar) 1
    }
}

# UI::BuildShortcutButtonPad --
#
#       Build the actual shortcut button pad.

proc ::UI::BuildShortcutButtonPad {wtop} {
    global  prefs wDlgs this
    
    variable icons
    variable btShortDefs
    upvar ::${wtop}::wapp wapp
    
    set wCan $wapp(can)
    set h [image height $icons(barvert)]
    set wtray $wapp(tray)

    ::buttontray::buttontray $wtray $h -relief raised -borderwidth 1

    # We need to substitute $wCan, $wtop etc specific for this wb instance.
    foreach {name cmd} $btShortDefs(this) {
	set cmd [subst -nocommands -nobackslashes $cmd]
	set txt [string toupper [string index $name 0]][string range $name 1 end]
	$wtray newbutton $name $txt bt$name bt${name}dis $cmd
    }
    if {[string equal $prefs(protocol) "server"]} {
	$wtray buttonconfigure connect -state disabled
    }
    $wtray buttonconfigure send -state disabled
}

# UI::DisableShortcutButtonPad --
#
#       Sets the state of the main to "read only".

proc ::UI::DisableShortcutButtonPad {wtop} {
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
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
	::UI::MacUseMainMenu $w
    } else {
	
    }
    wm title $w $title
    set finmega -1
    wm protocol $w WM_DELETE_WINDOW "set [namespace current]::finmega 0"
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] \
      -fill both -expand 1 -ipadx 4
    pack [message $w.frall.msg -width 220 -text $msg] \
      -side top -fill both -padx 4 -pady 2
    
    set wmid $w.frall.fr
    pack [frame $wmid] -side top -fill x -expand 1 -padx 6
    label $wmid.la -font $fontSB -text $label
    entry $wmid.en
    grid $wmid.la -column 0 -row 0 -sticky e -padx 2 
    grid $wmid.en -column 1 -row 0 -sticky ew -padx 2 
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack $frbot  -side bottom -fill x -padx 10 -pady 8
    pack [button $frbot.btok -text $btok -width 8  \
      -default active -command "set [namespace current]::finmega 1"] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcan -text $btcancel -width 8  \
      -command "set [namespace current]::finmega 0"]  \
      -side right -padx 5 -pady 5  
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    bind $w <Escape> [list $frbot.btcan invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $wmid.en
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finmega
    
    set entryVar [$wmid.en get]
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
#       Supposed to be a generic cut/copy/paste function.
#       
# Arguments:
#       cmd      cut/copy/paste
#       
# Results:
#       none

proc ::UI::CutCopyPasteCmd {cmd} {
    
    upvar ::UI::CCP::locals locals
    
    set wfocus [focus]
    
    ::Debug 2 "::UI::CutCopyPasteCmd cmd=$cmd, wfocus=$wfocus"
    
    if {$wfocus == ""} {
	return
    }
    set wclass [winfo class $wfocus]
    switch -glob -- $wclass {
	Text - Entry {	    
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
	Canvas - Wish* - Whiteboard {
	    
	    # Operate on the whiteboard's canvas.
	    set wtop [::UI::GetToplevelNS $wfocus]
	    upvar ::${wtop}::wapp wapp
	    switch -- $cmd {
		cut - copy {
		    ::CanvasCCP::CopySelectedToClipboard $wapp(can) $cmd		    
		}
		paste {
		    ::CanvasCCP::PasteFromClipboardTo $wapp(can)
		}
	    }
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


# UI::CreateAllButtons --
#
#       Makes the toolbar button pad for the drawing tools.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
# Results:
#       tool buttons created and mapped

proc ::UI::CreateAllButtons {wtop} {
    global  prefs this
    
    variable btNo2Name 
    variable btName2No
    variable icons
    upvar ::${wtop}::state state
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
    set wtool $wapp(tool)
    
    for {set icol 0} {$icol <= 1} {incr icol} {
	for {set irow 0} {$irow <= 6} {incr irow} {
	    
	    # The icons are Mime coded gifs.
	    set lwi [label $wtool.bt$irow$icol -image $icons(off${irow}${icol}) \
	      -borderwidth 0]
	    grid $lwi -row $irow -column $icol -padx 0 -pady 0
	    set name $btNo2Name($irow$icol)
	    
	    if {![string equal $opts(-state) "disabled"]} {
		bind $lwi <Button-1>  \
		  [list ::UI::SetToolButton $wtop $name]
		
		# Handle bindings to popup options.
		if {[string match "mac*" $this(platform)]} {
		    bind $lwi <Button-1> "+ ::UI::StartTimerToToolPopup %W $wtop $name"
		    bind $lwi <ButtonRelease-1> ::UI::StopTimerToToolPopup
		} else {
		    bind $lwi <Button-3> [list ::UI::DoToolPopup %W $wtop $name]
		}
	    }
	}
    }
    
    # Make all popups.
    ::UI::BuildToolPopups $wtop
    ::UI::BuildToolPopupFontMenu $wtop $prefs(canvasFonts)
    
    # Color selector.
    set imheight [image height $icons(imcolor)]
    set wColSel [canvas $wtool.cacol -width 56 -height $imheight  \
      -highlightthickness 0]
    $wtool.cacol create image 0 0 -anchor nw -image $icons(imcolor)
    set idColSel [$wtool.cacol create rect 7 7 33 30	\
      -fill $state(fgCol) -outline {} -tags tcolSel]
    set wapp(colSel) $wColSel
    
    # Black and white reset rectangle.
    set idBWReset [$wtool.cacol create image 4 34 -anchor nw -image bwrect]
    
    # bg and fg switching.
    set idBWSwitch [$wtool.cacol create image 38 4 -anchor nw -image bwrect]
    grid $wtool.cacol -  -padx 0 -pady 0

    if {![string equal $opts(-state) "disabled"]} {
	$wtool.cacol bind $idColSel <Button-1>  \
	  [list ::UI::ColorSelector $wtop $state(fgCol)]
	$wtool.cacol bind $idBWReset <Button-1>  \
	  "$wColSel itemconfigure $idColSel -fill black;  \
	  set ::${wtop}::state(fgCol) black; set ::${wtop}::state(bgCol) white"
	$wtool.cacol bind $idBWSwitch <Button-1> \
	  [list ::UI::SwitchBgAndFgCol $wtop]
    }
}

proc ::UI::BuildToolPopups {wtop} {
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

# UI::StartTimerToToolPopup, StopTimerToToolPopup, DoToolPopup --
#
#       Some functions to handle the tool popup menu.

proc ::UI::StartTimerToToolPopup {w wtop name} {
    
    variable toolPopupId
    
    if {[info exists toolPopupId]} {
	catch {after cancel $toolPopupId}
    }
    set toolPopupId [after 1000 [list ::UI::DoToolPopup $w $wtop $name]]
}

proc ::UI::StopTimerToToolPopup { } {
    
    variable toolPopupId

    if {[info exists toolPopupId]} {
	catch {after cancel $toolPopupId}
    }
}

proc ::UI::DoToolPopup {w wtop name} {
    
    upvar ::${wtop}::wapp wapp

    set wtool $wapp(tool)
    set wpop ${wtool}.pop${name}
    if {[winfo exists $wpop]} {
	set x [winfo rootx $w]
	set y [expr [winfo rooty $w] + [winfo height $w]]
	tk_popup $wpop $x $y
    }
}

proc ::UI::DoTopMenuPopup {w wtop wmenu} {
    
    if {[winfo exists $wmenu]} {
	set x [winfo rootx $w]
	set y [expr [winfo rooty $w] + [winfo height $w]]
	tk_popup $wmenu $x $y
    }
}

proc ::UI::SwitchBgAndFgCol {wtop} {
    
    upvar ::${wtop}::state state
    upvar ::${wtop}::wapp wapp

    $wapp(colSel) itemconfigure tcolSel -fill $state(bgCol)
    set tmp $state(fgCol)
    set state(fgCol) $state(bgCol)
    set state(bgCol) $tmp
}

# UI::ColorSelector --
#
#       Callback procedure for the color selector in the tools frame.
#       
# Arguments:
#       col      initial color value.
#       
# Results:
#       color dialog shown.

proc ::UI::ColorSelector {wtop col} {
    
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

proc ::UI::ToolBtNameToNum {name} {

    variable btName2No 
    return $btName2No($name)
}

proc ::UI::ToolBtNumToName {num} {

    variable btNo2Name     
    return $btNo2Name($num)
}

# UI::FindWBGeometry --
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

proc ::UI::FindWBGeometry {wtop} {
    global  this prefs
    
    variable dims
    variable icons
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
    
    set wCan $wapp(can)
    
    # The actual dimensions.
    set wRoot [winfo reqwidth $w]
    set hRoot [winfo reqheight $w]
    set hTop 0
    if {[winfo exists ${wtop}frtop]} {
	set hTop [winfo reqheight ${wtop}frtop]
    }
    set hTopOn [winfo reqheight ${wtop}frtop.on]
    set hTopOff [winfo reqheight ${wtop}frtop.barhoriz]
    set hStatus [winfo reqheight ${wtop}fcomm.st]
    set hComm [winfo reqheight $wapp(comm)]
    set hCommClean $hComm
    set wStatMess [winfo reqwidth $wapp(statmess)]    
    
    # If we have a custom made menubar using a frame with labels (embedded).
    if {$prefs(haveMenus)} {
	set hFakeMenu 0
    } else {
	set hFakeMenu [winfo reqheight ${wtop}menu]
    }
    if {![string match "mac*" $this(platform)]} {
	# MATS: seems to always give 1 Linux not...
	### EAS BEGIN
	set hMenu 1
	if {[winfo exists ${wtop}#menu]} {
	    set hMenu [winfo height ${wtop}#menu]
	}
	# In 8.4 it seems that .wb1.#wb1#menu is used.
	set wmenu ${wtop}#[string trim $wtop .]#menu
	if {[winfo exists $wmenu]} {
	    set hMenu [winfo height $wmenu]
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
      [winfo width $wapp(comm).user] + [image width $icons(resizehandle)] + 2]
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
    
    #::Debug 2 "::UI::FindWBGeometry"
    #::Debug 2 "[parray dims]"
    
    # The minsize when no connected clients. 
    # Is updated when connect/disconnect (Not jabber).
    wm minsize $w $wMinTot $hMinTot
}

# ::UI::ParseWMGeometry --
# 
#       Parses 'wm geometry' result into a list.
#       
# Arguments:
#       w           the (real) toplevel widget path
# Results:
#       list {width height x y}

proc ::UI::ParseWMGeometry {w} {
    
    set int_ {[0-9]+}
    set sint_ {\-?[0-9]+}
    set plus_ {\+}
    regexp "(${int_})x(${int_})${plus_}(${sint_})${plus_}(${sint_})"   \
      [wm geometry $w] match wid hei x y
    return [list $wid $hei $x $y]
}

# ::UI::SetCanvasSize --
#
#       From the canvas size, 'cw' and 'ch', set the total application size.
#       
# Arguments:
#
# Results:
#       None.

proc ::UI::SetCanvasSize {cw ch} {
    global  prefs
        
    upvar ::UI::dims dims
    upvar ::.::wapp wapp
    
    # Compute new root size from the desired canvas size.
    set wRootFinal [expr $cw + 56]
    set hRootFinal [expr $ch + $dims(hStatus) + $dims(hComm) + $dims(hTop)]
    if {$prefs(haveScrollbars)} {
	incr wRootFinal [expr [winfo reqwidth $wapp(ysc)] + 2]
	incr hRootFinal [expr [winfo reqheight $wapp(xsc)] + 2]
    }
    wm geometry . ${wRootFinal}x${hRootFinal}

    Debug 3 "::UI::SetCanvasSize:: cw=$cw, ch=$ch, hRootFinal=$hRootFinal, \
      wRootFinal=$wRootFinal"
}

# ::UI::SetNewWMMinsize --
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

proc ::UI::SetNewWMMinsize {wtop} {
    global  prefs
    
    upvar ::UI::dims dims
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
    
    Debug 2 "::UI::SetNewWMMinsize:: dims(hComm)=$dims(hComm),  \
      dims(hMinRoot)=$dims(hMinRoot), dims(hMinTot)=$dims(hMinTot), \
      dims(hTop)=$dims(hTop)"
}	    

# UI::WhiteboardGetFocus --
#
#       Check clipboard and activate corresponding menus.    
#       
# Results:
#       updates state of menus.

proc ::UI::WhiteboardGetFocus {wtop w} {
    
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
    Debug 3 "WhiteboardGetFocus:: wtop=$wtop, w=$w"
    
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

# ::UI::SetCommHead --
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
#       UI updated.

proc ::UI::SetCommHead {wtop type args} {
    global  prefs
    
    variable thisType
    variable nEnt
    upvar ::${wtop}::wapp wapp
    
    Debug 2 "::UI::SetCommHead"
    
    set thisType $type
    set nEnt($wtop) 0
    set wcomm $wapp(comm)
    
    # The labels in comm frame.
    if {![winfo exists $wcomm]} {
	eval {::UI::BuildCommHead $wtop $type} $args
    } else {
	
	# It's already there, configure it...
	destroy $wcomm
	eval {::UI::BuildCommHead $wtop $type} $args
	
	# We need to allow for resizing here if any change in height.
	after idle [list ::UI::SetNewWMMinsize $wtop]
    }
}


proc ::UI::BuildCommHead {wtop type args} {
    global  prefs
    
    variable icons
    upvar ::${wtop}::wapp wapp
    set wcomm $wapp(comm)
    
    Debug 2 "::UI::BuildCommHead"
    
    array set argsArr {-connected 0}
    array set argsArr $args
    
    set fontSB [option get . fontSmallBold {}]
    
    pack [frame $wcomm -relief raised -borderwidth 1] -side left
    
    switch -- $type {
	jabber {
	    label $wcomm.comm -text "  [::msgcat::mc {Jabber Server}]:"  \
	      -width 18 -anchor w -font $fontSB
	    label $wcomm.user -text "  [::msgcat::mc {Jabber Id}]:"  \
	      -width 18 -anchor w -font $fontSB
	    if {$argsArr(-connected)} {
	    	label $wcomm.icon -image $icons(contact_on)
	    } else {
	    	label $wcomm.icon -image $icons(contact_off)
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
	    label $wcomm.icon -image $icons(contact_off)
	    grid $wcomm.comm $wcomm.user $wcomm.to $wcomm.icon  \
	      -sticky nws -pady 0
	}
    }  
    
    # A min height was necessary here to make room for switching the icon 
    # of this row.
    grid rowconfigure $wcomm 0 -minsize 23
}

# ::UI::BuildJabberEntry --
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

proc ::UI::BuildJabberEntry {wtop args} {
    global  prefs
    
    upvar ::Jabber::jstate jstate
    upvar ::${wtop}::wapp wapp
    
    Debug 2 "::UI::BuildJabberEntry args='$args'"

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

# UI::ConfigureAllJabberEntries --

proc ::UI::ConfigureAllJabberEntries {ipNum args} {

    foreach w [::UI::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]
	eval {::UI::ConfigureJabberEntry $wtop $ipNum} $args
    }
}

# UI::ConfigureJabberEntry --
#
#       Configures the jabber entry in the communications frame that is suitable
#       for persistent display.

proc ::UI::ConfigureJabberEntry {wtop ipNum args} {
    
    variable icons
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
    Debug 2 "::UI::ConfigureJabberEntry args='$args'"
    
    set wcomm $wapp(comm)
    set n 1
    
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
			  -image $icons(contact_on)]
		    }
		    disconnect {
			${wcomm}.to${n} configure -state disabled
			after 400 [list ${wcomm}.icon configure  \
			  -image $icons(contact_off)]	    
		    }
		}
	    }
	}
    }
    eval {::Jabber::ConfigureJabberEntry $wtop} $args
}

proc ::UI::DeleteJabberEntry {wtop} {

    upvar ::${wtop}::wapp wapp
    
    set n 1
    catch {
	destroy $wcomm.ad$n
	destroy $wcomm.us$n
	destroy $wcomm.to$n
    }
}

# ::UI::SetCommEntry --
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

proc ::UI::SetCommEntry {wtop ipNum to from args} { 
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
	::UI::RemoveCommEntry $wtop $ipNum
    } elseif {!$alreadyThere} {
	eval {::UI::BuildCommEntry $wtop $ipNum} $args
    } elseif {[string equal $prefs(protocol) "jabber"]} {
	if {$commTo($wtop,$ipNum) == 0} {
	    ::UI::RemoveCommEntry $wtop $ipNum
	}
    } 
}

# ::UI::BuildCommEntry --
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

proc ::UI::BuildCommEntry {wtop ipNum args} {
    global  prefs ipNumTo
    
    variable icons
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
    if {[string equal $wtop "."]} {
	set wtopReal .
    } else {
	set wtopReal [string trimright $wtop .]
    }
    
    set bg [option get . backgroundGeneral {}]
    
    set size [::UI::ParseWMGeometry $wtopReal]
    set n $nEnt($wtop)
    
    # Add new status line.
    if {[string equal $thisType "jabber"]} {
	entry $wcomm.ad$n -width 18 -relief sunken -bg $bg
	entry $wcomm.us$n -width 22 -relief sunken -bg white
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
	after 400 [list $wcomm.icon configure -image $icons(contact_on)]
    } elseif {[string equal $thisType "symmetric"]} {
	entry $wcomm.ad$n -width 24  \
	  -relief sunken -bg $bg
	entry $wcomm.us$n -width 16   \
	  -textvariable ipNumTo(user,$ipNum) -relief sunken  \
	  -bg $bg
	checkbutton $wcomm.to$n -variable ${ns}::commTo($wtop,$ipNum)   \
	  -highlightthickness 0 -command [list ::UI::CheckCommTo $wtop $ipNum]
	checkbutton $wcomm.from$n -variable ${ns}::commFrom($wtop,$ipNum)  \
	  -highlightthickness 0 -state disabled
	grid $wcomm.ad$n $wcomm.us$n $wcomm.to$n   \
	  $wcomm.from$n -padx 4 -pady 0
	$wcomm.us$n configure -state disabled
    } elseif {[string equal $thisType "client"]} {
	entry $wcomm.ad$n -width 24   \
	  -relief sunken -bg $bg
	entry $wcomm.us$n -width 16    \
	  -textvariable ipNumTo(user,$ipNum) -relief sunken  \
	  -bg $bg
	checkbutton $wcomm.to$n -variable ${ns}::commTo($wtop,$ipNum)   \
	  -highlightthickness 0 -command [list ::UI::CheckCommTo $wtop $ipNum]
	grid $wcomm.ad$n $wcomm.us$n $wcomm.to$n -padx 4 -pady 0
	$wcomm.us$n configure -state disabled
    } elseif {[string equal $thisType "server"]} {
	entry $wcomm.ad$n -width 24   \
	  -relief sunken -bg $bg
	entry $wcomm.us$n -width 16    \
	  -textvariable ipNumTo(user,$ipNum) -relief sunken  \
	  -bg $bg
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
    after idle [list ::UI::SetNewWMMinsize $wtop]
    
    # Map ip name to nEnt.
    set ipNum2iEntry($wtop,$ipNum) $nEnt($wtop)
    
    # Step up running index. This must *never* be reused!
    incr nEnt($wtop)
}

# ::UI::CheckCommTo --
#
#       This is the callback function when the checkbutton 'To' has been trigged.
#       
# Arguments:
#       wtop 
#       ipNum       the ip number.
#       
# Results:
#       updated communication frame.

proc ::UI::CheckCommTo {wtop ipNum} {
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
	::UI::SetCommEntry $wtop $ipNum 1 -1
    }
}

# ::UI::RemoveCommEntry --
#
#       Removes the complete entry in the communication frame for 'ipNum'.
#       It should not be called by itself; only from 'SetCommEntry'.
#       
# Arguments:
#       ipNum       the ip number.
#       
# Results:
#       updated communication frame.

proc ::UI::RemoveCommEntry {wtop ipNum} {
    global  prefs
    
    variable icons
    variable commTo
    variable commFrom
    variable ipNum2iEntry
    upvar ::${wtop}::wapp wapp
    
    set wCan $wapp(can)
    set wcomm $wapp(comm)
    if {[string equal $wtop "."]} {
	set wtopReal .
    } else {
	set wtopReal [string trimright $wtop .]
    }
    
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
	after 400 [list $wcomm.icon configure -image $icons(contact_off)]
    }
    update idletasks
    
    # Organize the new geometry. First fix using wm geometry, then relax
    # canvas size.
    set newGeom [::UI::ParseWMGeometry $wtopReal]
    wm geometry $wtopReal [lindex $newGeom 0]x[lindex $newGeom 1]
    $wCan configure -height 1 -width 1
    
    # Geometry considerations. Update geometry vars and set new minsize.
    after idle [list ::UI::SetNewWMMinsize $wtop]
}

# UI::FixMenusWhen --
#       
#       Sets the correct state for menus and buttons when 'what'.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       what        "connect", "disconnect", "disconnectserver"
#
# Results:

proc ::UI::FixMenusWhen {wtop what} {
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
    variable fixMenusCallback
    
    set wtop [::UI::GetToplevelNS $w]
    set wClass [winfo class $w]
    set wToplevel [winfo toplevel $w]
    set wToplevelClass [winfo class $wToplevel]
    set medit ${wtop}menu.edit 
    
    Debug 3 "::UI::FixMenusWhenSelection w=$w,\n\twtop=$wtop, wClass=$wClass,\
      wToplevelClass=$wToplevelClass"
    
    # Do different things dependent on the type of widget.
    if {[winfo exists ${wtop}menu] && [string equal $wClass "Canvas"]} {
	
	# Respect any disabled whiteboard state.
	upvar ::${wtop}::opts opts
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
	if {[winfo exists ${wtop}menu]} {
	    
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
	::UI::CutCopyPasteCheckState $w $setState $haveClipState
    } 
    
    # Invoke any callbacks from 'addons'.
    foreach cmd $fixMenusCallback {
	eval {$cmd} ${wtop}menu "select"
    }
}

# UI::FixMenusWhenCopy --
# 
#       Sets the correct state for menus and buttons when copy something.
#       
# Arguments:
#       w       the widget that contains something that is copied.
#
# Results:

proc ::UI::FixMenusWhenCopy {w} {
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

# UI::MacUseMainMenu --
# 
#       Used on MacOSX to set accelerator keys for a toplevel that inherits
#       the menu from ".".
#       Used on all Macs to set state on edit menus.
#       
# Arguments:
#       w           toplevel widget that uses the "." menu.
#       
# Results:
#       none

proc ::UI::MacUseMainMenu {w} {
    global  this
    variable accelBindsToMain
    
    if {![string match "mac*" $this(platform)]} {
	return
    }
    ::Debug 3 "::UI::MacUseMainMenu w=$w"
        
    # Set up menu accelerators from ".".
    # Cached accelerators to ".".
    if {($w != ".") && [string equal $this(platform) "macosx"]} {
	foreach mentry $accelBindsToMain {
	    foreach {sequence cmd} $mentry {
		bind $w $sequence $cmd
	    }
	}
    }
    
    # This sets up the edit menu that we inherit from ".".
    bind $w <FocusIn> "+ ::UI::MacFocusFixEditMenu $w . %W"
    
    # If we hand over to a 3rd party toplevel window, it by default inherits
    # the "." menu bar, so we need to take precautions.
    bind $w <FocusOut> "+ ::UI::MacFocusFixEditMenu $w . %W"
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
    ::Debug 3 "MacFocusFixEditMenu: w=$w, wfocus=$wfocus"
    
    # The <FocusIn> events are sent in order, from toplevel and down
    # to the actual window with focus.
    # Any '::UI::FixMenusWhenSelection' will therefore be called after this.
    set medit ${wtopmenu}menu.edit
    ::UI::MenuMethod $medit entryconfigure mPaste -state disabled
    ::UI::MenuMethod $medit entryconfigure mCut -state disabled
    ::UI::MenuMethod $medit entryconfigure mCopy -state disabled
}

# UI::BuildItemMenu --
#
#       Creates an item menu from all files in the specified directory.
#    
# Arguments:
#       wmenu       the menus widget path name (".menu.items").
#       itemDir     The directory to search the item files in.
#       
# Results:
#       item menu with submenus built.

proc ::UI::BuildItemMenu {wtop wmenu itemDir} {
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
	bind ${wmenu}la <Button-1> [list ::UI::DoTopMenuPopup %W $wtop $m]
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

# UI::BuildFontMenu ---
# 
#       Creates the font selection menu, and removes any old.
#    
# Arguments:
#       mt         The menu path.
#       allFonts   List of names of the fonts.
#       
# Results:
#       font submenu built.

proc ::UI::BuildFontMenu {wtop allFonts} {
    
    set mt ${wtop}menu.prefs.mfont
    
    $mt delete 0 end
    foreach afont $allFonts {
	$mt add radio -label $afont -variable ::${wtop}::state(font)  \
	  -command [list ::UI::FontChanged $wtop name]
    }
    
    # Be sure that the presently selected font family is still there,
    # else choose helvetica.
    set fontStateVar ::${wtop}::state(font)
    if {[lsearch -exact $allFonts $fontStateVar] == -1} {
	set ::${wtop}::state(font) {Helvetica}
    }
}

proc ::UI::BuildToolPopupFontMenu {wtop allFonts} {
    upvar ::${wtop}::wapp wapp
    
    set wtool $wapp(tool)
    set mt ${wtool}.poptext.mfont
    
    $mt delete 0 end
    foreach afont $allFonts {
	$mt add radio -label $afont -variable ::${wtop}::state(font)  \
	  -command [list ::UI::FontChanged $wtop name]
    }
}

proc ::UI::BuildCanvasPopupFontMenu {w wmenu id allFonts} {

    set mt $wmenu    
    $mt delete 0 end
    foreach afont $allFonts {
	$mt add radio -label $afont -variable ::UI::popupVars(-fontfamily)  \
	  -command [list ::CanvasUtils::SetTextItemFontFamily $w $id $afont]
    }
}

proc ::UI::BuildAllFontMenus {allFonts} {

    # Must do this for all open whiteboards!
    foreach wtopreal [::UI::GetAllWhiteboards] {
	if {$wtopreal != "."} {
	    set wtop "${wtopreal}."
	} else {
	    set wtop $wtopreal
	}
	::UI::BuildFontMenu $wtop $allFonts
	::UI::BuildToolPopupFontMenu $wtop $allFonts
    }
}

# UI::FontChanged --
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

proc ::UI::FontChanged {wtop what} {
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
	if {0} {
	    puts "sw=$sw, sh=$sh, x=$x, y=$y, reqwidth=[winfo reqwidth $win],\
	      reqheight=[winfo reqheight $win]"
	}
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

proc ::UI::StartStopAnimatedWave {w start} {
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
	set id [$w create image 0 0 -anchor nw -image $icons(wave)]
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

proc ::UI::StartStopAnimatedWaveInWB {wtop start} {    
    upvar ::${wtop}::wapp wapp
    
    ::UI::StartStopAnimatedWave $wapp(statmess) $start
}

proc ::UI::StartStopAnimatedWaveOnMain {start} {    
    upvar ::.::wapp wapp
    
    ::UI::StartStopAnimatedWave $wapp(statmess) $start
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

# UI::CreateBrokenImage --
# 
#       Creates an actual image with the broken symbol that matches
#       up the width and height. The image is garbage collected.

proc ::UI::CreateBrokenImage {wtop width height} {
    variable icons    
    upvar ::${wtop}::tmpImages tmpImages
    
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
	    lappend tmpImages $name
	}
    }
    return $name
}

#-------------------------------------------------------------------------------

