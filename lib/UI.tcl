#  UI.tcl ---
#  
#      This file is part of the whiteboard application. It implements user
#      interface elements.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: UI.tcl,v 1.5 2003-02-06 17:23:34 matben Exp $

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

proc LabeledFrame {wpath txt args} {
    global  sysFont
    
    pack [frame $wpath.st -borderwidth 0]  \
      -side top -fill both -pady 2 -padx 2 -expand true
    pack [frame $wpath.st.fr -relief groove -bd 2]  \
      -side top -fill both -expand true -padx 10 -pady 10 -ipadx 0 -ipady 0  \
      -in $wpath.st
    place [label $wpath.st.lbl -text $txt -font $sysFont(sb) -bd 0 -padx 6]  \
      -in $wpath.st -x 20 -y 14 -anchor sw
    return $wpath.st.fr
}

proc LabeledFrame2 {wpath txt args} {
    global  sysFont
    
    frame $wpath -borderwidth 0
    pack [frame $wpath.st -borderwidth 0]  \
      -side top -fill both -pady 2 -padx 2 -expand true
    pack [frame $wpath.st.fr -relief groove -bd 2]  \
      -side top -fill both -expand true -padx 10 -pady 10 -ipadx 0 -ipady 0  \
      -in $wpath.st
    place [label $wpath.st.lbl -text $txt -font $sysFont(sb) -bd 0 -padx 6]  \
      -in $wpath.st -x 20 -y 14 -anchor sw
    return $wpath.st.fr
}

proc LabeledFrame3 {w txt args} {
    global  sysFont
    
    frame $w -borderwidth 0
    pack [frame $w.pad] -side top
    pack [frame $w.cont -relief groove -bd 2] -side top -fill both -expand 1
    place [label $w.l -text $txt -font $sysFont(sb) -bd 0] -x 20 -y 0 -anchor nw
    set h [winfo reqheight $w.l]
    $w.pad configure -height [expr $h-4]
    return $w.cont
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
    variable idmain 2
}

# UI::Init --
# 
#       Various initializations for the UI stuff.

proc ::UI::Init {} {
    global  this prefs
    
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
    
    # Addon menus
    variable addonMenus {}
    
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
    set btShortDefs {
	connect    {::Jabber::Login::Login $wDlgs(jlogin)}
	save       {::CanvasFile::DoSaveCanvasFile $wtop}
	open       {::CanvasFile::DoOpenCanvasFile $wtop}
	import     {::ImageAndMovie::ImportImageOrMovieDlg $wtop}
	send       {::Jabber::DoSendCanvas $wtop}
	print      {::UserActions::DoPrintCanvas $wtop}
	stop       {::UserActions::CancelAllPutGetAndPendingOpen $wtop}
    }
    
    # Set commands valid for this platform and prefs. Must sync indices!
    if {($prefs(protocol) == "symmetric") || ($prefs(protocol) == "client")} {
	set btShortDefs [lreplace $btShortDefs 1 1  \
	  {::OpenConnection::OpenConnection $wDlgs(openConn)}]
	set btShortDefs [lreplace $btShortDefs 8 8  \
	  {::UserActions::DoSendCanvas $wtop}]
    }
    if {[string equal $this(platform) "unix"]} {
	set btShortDefs [lreplace $btShortDefs 11 11  \
	  {::PrintPSonUnix::PrintPSonUnix $wDlgs(print) $wCan}]
    }
    
    # Get icons.
    set icons(igelpiga) [image create photo igelpiga -format gif \
      -file [file join $this(path) images igelpiga.gif]]
    set icons(brokenImage) [image create photo -format gif  \
      -file [file join $this(path) images brokenImage.gif]]
    foreach {name cmd} $btShortDefs {
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
	btforward forward} {
	set icons($name) [image create photo -format gif  \
	  -file [file join $this(path) images ${fname}.gif]]
	set icons(${name}dis) [image create photo -format gif  \
	  -file [file join $this(path) images ${fname}Dis.gif]]
    }	
	
    foreach iconFile {resizehandle bluebox contact_off contact_on wave}  \
      name {im_handle bluebox contact_off contact_on im_wave} {
	set icons($name) [image create photo $name -format gif  \
	  -file [file join $this(path) images $iconFile.gif]]
    }
    set icons(bwrect) [image create photo bwrect -format gif  \
      -file [file join $this(path) images transparent_rect.gif]]
    
    # Icons for the mailbox.
    set readmsgdata {
R0lGODdhDgAKAKIAAP/////xsOjboMzMzHNzc2NjzjExYwAAACwAAAAADgAK
AAADJli6vFMhyinMm1NVAkPzxdZhkhh9kUmWBie8cLwZdG3XxEDsfM8nADs=}

    set unreadmsgdata {
R0lGODdhDgAKALMAAP/////xsOjboMzMzIHzeXNzc2Njzj7oGzXHFzExYwAA
AAAAAAAAAAAAAAAAAAAAACwAAAAADgAKAAAENtBIcpC8cpgQKOKgkGicB0pi
QazUUQVoUhhu/YXyZoNcugUvXsAnKBqPqYRyyVwWBoWodCqNAAA7}

    set wbicon {
R0lGODdhFQANALMAAP/////n5/9ze/9CQv8IEOfn/8bO/621/5ycnHN7/zlK
/wC9AAAQ/wAAAAAAAAAAACwAAAAAFQANAAAEWrDJSWtFDejN+27YZjAHt5wL
B2aaopAbmn4hMBYH7NGskmi5kiYwIAwCgJWNUdgkGBuBACBNhnyb4IawtWaY
QJ2GO/YCGGi0MDqtKnccohG5stgtiLx+z+8jIgA7}	

    set icons(readMsg) [image create photo -data $readmsgdata]
    set icons(unreadMsg) [image create photo -data $unreadmsgdata]
    set icons(wbicon) [image create photo -data $wbicon]
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
      {command   mAboutWhiteboard    {::SplashScreen::SplashScreen $wDlgs(splash)} normal   {}}
    set menuDefs(main,info,aboutquicktimetcl)  \
      {command   mAboutQuickTimeTcl  {AboutQuickTimeTcl}                           normal   {}}

    # Mac only.
    set menuDefs(main,apple) [list $menuDefs(main,info,aboutwhiteboard)  \
      $menuDefs(main,info,aboutquicktimetcl)]
    
    set menuDefs(main,file) {
	{command   mNew                {::UI::NewMain -sendcheckstate disabled}   normal   N}
	{command   mOpenConnection     {::UserActions::DoConnect}                 normal   O}
	{command   mCloseWindow        {::UserActions::DoCloseWindow}             normal   W}
	{command   mStartServer        {DoStartServer $prefs(thisServPort)}       normal   {}}
	{separator}
	{command   mOpenImage/Movie    {::ImageAndMovie::ImportImageOrMovieDlg $wtop} normal  I}
	{command   mOpenURLStream      {::OpenMulticast::OpenMulticast $wtop $wDlgs(openMulti)} normal {}}
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
	{command   mPageSetup          {::UserActions::PageSetup}                 normal   {}}
	{command   mPrintCanvas        {::UserActions::DoPrintCanvas $wtop}       normal   P}
	{command   mQuit               {::UserActions::DoQuit}                    normal   Q}
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
	{command     mInspectItem      {::ItemInspector::ItemInspector $wtop selected} disabled I}
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
	{command     mImageLarger      {::ImageAndMovie::ResizeImage $wtop 2 sel auto} disabled {}}
	{command     mImageSmaller     {::ImageAndMovie::ResizeImage $wtop -2 sel auto} disabled {}}
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
      {command     mPreferences...   {::Preferences::Build $wDlgs(prefs)}  normal   {}}
    
    # Build hierarchical list.
    set menuDefs(main,prefs) {}
    foreach key {background grid thickness brushthickness fill smoothness  \
      arcs dash constrain separator font fontsize fontweight separator prefs} {
	lappend menuDefs(main,prefs) $menuDefs(main,prefs,$key)
    }

    set menuDefs(main,jabber) {    
	{command     mNewAccount    {::Jabber::Register::Register $wDlgs(jreg)} normal   {}}
	{command     mLogin         {::Jabber::Login::Login $wDlgs(jlogin)} normal   {}}
	{command     mLogoutWith    {::Jabber::Logout::WithStatus .joutst}  disabled {}}
	{command     mPassword      {::Jabber::Passwd::Build .jpasswd}      disabled {}}
	{separator}
	{checkbutton mRoster/Services  {::Jabber::::RostServ::Show $wDlgs(jrostbro)}  normal   {} \
	  {-variable ::Jabber::jstate(rostBrowseVis)}}
	{checkbutton mMessageInbox  {::Jabber::MailBox::Show $wDlgs(jinbox)} normal   {} \
	  {-variable ::Jabber::jstate(inboxVis)}}
	{separator}
	{command     mSearch        {::Jabber::Search::Build .jsearch}      disabled {}}
	{command     mAddNewUser    {::Jabber::Roster::NewOrEditItem $wDlgs(jrostnewedit) new} disabled {}}
	{separator}
	{command     mSendMessage   {::Jabber::NewMsg::Build $wDlgs(jsendmsg)} disabled {}}
	{command     mChat          {::Jabber::Chat::StartThreadDlg .jchat} disabled {}}
	{cascade     mStatus        {}                                      disabled {} {} {}}
	{separator}
	{command     mEnterRoom     {::Jabber::GroupChat::EnterRoom $wDlgs(jenterroom)} disabled {}}
	{cascade     mExitRoom      {}                                    disabled {} {} {}}
	{command     mCreateRoom    {::Jabber::GroupChat::CreateRoom $wDlgs(jcreateroom)} disabled {}}
	{separator}
	{command     mvCard         {::VCard::Fetch .jvcard own}          disabled {}}
	{separator}
	{command     mRemoveAccount {::Jabber::Register::Remove}          disabled {}}	
	{separator}
	{command     mErrorLog      {::Jabber::ErrorLogDlg .jerrdlg}      normal   {}}
	{checkbutton mDebug         {::Jabber::DebugCmd}                  normal   {} \
	  {-variable ::Jabber::jstate(debugCmd)}}
    }    
    if {!$prefs(stripJabber)} {
	lset menuDefs(main,jabber) 13 6 [::Jabber::BuildStatusMenuDef]
    }

    set menuDefs(main,cam) {    
	{command     {Camera Action}     {DisplaySequenceGrabber $wtop}        normal   {}}	
	{checkbutton {Pause}             {SetVideoConfig $wtop pause}          normal   {}}	
	{command     {Picture}           {SetVideoConfig $wtop picture 1}      normal   {}}	
	{cascade     {Video Size}        {}                                    normal   {} {} {
	    {radio   Quarter             {SetVideoConfig $wtop size}           normal   {} \
	      {-variable prefs(videoSize) -value quarter}}
	    {radio   Half                {SetVideoConfig $wtop size}           normal   {} \
	      {-variable prefs(videoSize) -value half}}
	    {radio   Full                {SetVideoConfig $wtop size}           normal   {} \
	      {-variable prefs(videoSize) -value full}}}
	}
	{cascade     {Zoom}              {}                                    normal   {} {} {
	    {radio   {x 1}               {SetVideoConfig $wtop zoom}           normal   {} \
	      {-variable prefs(videoSize) -value 1.0}}
	    {radio   {x 2}               {SetVideoConfig $wtop zoom}           normal   {} \
	      {-variable prefs(videoSize) -value 2.0}}
	    {radio   {x 3}               {SetVideoConfig $wtop zoom}           normal   {} \
	      {-variable prefs(videoSize) -value 3.0}}
	    {radio   {x 4}               {SetVideoConfig $wtop zoom}           normal   {} \
	      {-variable prefs(videoSize) -value 4.0}}}
	}
	{command     {Video Settings...} {SetVideoConfig $wtop videosettings}  normal   {}}	
    }
    set menuDefs(main,info) {    
	{command     mOnServer       {ShowInfoServer $wDlgs(infoServ) \$this(ipnum)} normal {}}	
	{command     mOnClients      {::InfoClients::ShowInfoClients $wDlgs(infoClient) \$allIPnumsFrom} disabled {}}	
	{command     mOnPlugins      {InfoOnPlugins .plugs}                    normal {}}	
	{separator}
	{cascade     mHelpOn             {}                                    normal   {} {} {
	    {command mNetworkSetup       \
	      {::UI::OpenCanvasInfoFile $wtop NetworkSetup.can}                normal {}}
	    {command mServers           \
	      {::UI::OpenCanvasInfoFile $wtop Servers.can}                     normal {}}
	    {command mJabberTransport   \
	      {::UI::OpenCanvasInfoFile $wtop JabberTransport.can}             normal {}}
	    {command mSmileyLegend      \
	      {::UI::OpenCanvasInfoFile $wtop SmileyLegend.can}                normal {}}}
	}
	{separator}
	{command     mSetupAssistant {
	    package require SetupAss
	    ::SetupAss::SetupAss .setupass}                normal {}}
    }
    
    # Make platform specific things and special menus etc. Indices!!! BAD!
    if {$haveAppleMenu && !$prefs(QuickTimeTcl)} {
	lset menuDefs(main,apple) 1 3 disabled
    }
    if {![string equal $prefs(protocol) "jabber"]} {
	lset menuDefs(main,file) 0 3 disabled
    }
    if {[string equal $prefs(protocol) "client"] ||   \
      [string equal $prefs(protocol) "central"]} {
	lset menuDefs(main,file) 3 3 disabled
    }
    if {!$prefs(QuickTimeTcl)} {
	lset menuDefs(main,file) 6 3 disabled
    }
    if {!$prefs(haveDash)} {
	lset menuDefs(main,prefs) 7 3 disabled
    }
    if {!$haveAppleMenu} {
	lappend menuDefs(main,info) $menuDefs(main,info,aboutwhiteboard)
    }
    if {!$haveAppleMenu && $prefs(QuickTimeTcl)} {
	lappend menuDefs(main,info) $menuDefs(main,info,aboutquicktimetcl)
    }
	    
    # If embedded the embedding app should close us down.
    if {$prefs(embedded)} {
	lset menuDefs(main,file) end 3 disabled
    }
    
    # Menu definitions for a minimal setup. Used on mac only.
    set menuDefs(min,file) {
	{command   mNew              {::UI::BuildMain .main}               normal   N}
	{command   mOpenConnection   {::UserActions::DoConnect}            normal   O}
	{command   mStartServer      {DoStartServer $prefs(thisServPort)}  normal   {}}
	{separator}
	{command   mStopPut/Get/Open {::UserActions::CancelAllPutGetAndPendingOpen $wtop} normal {}}
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
      {command   mSaveImageAs  {::CanvasUtils::SaveImageAsFile $w $id}      normal {}}
    set menuDefs(pop,imagelarger)  \
      {command   mImageLarger  {::ImageAndMovie::ResizeImage $wtop 2 $id auto}   normal {}}
    set menuDefs(pop,imagesmaller)  \
      {command   mImageSmaller {::ImageAndMovie::ResizeImage $wtop -2 $id auto}   normal {}}
    set menuDefs(pop,exportimage)  \
      {command   mExportImage  {::CanvasUtils::ExportImageAsFile $w $id}    normal {}}
    set menuDefs(pop,exportmovie)  \
      {command   mExportMovie  {::CanvasUtils::ExportMovie $wtop $winfr}    normal {}}
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
	{radio   mBold {::CanvasUtils::SetTextItemFontWeight $w $id bold}     normal   {} \
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
	brush      {brushthickness color smoothness inspect}
	image      {saveimageas imagelarger imagesmaller exportimage inspect}
	line       {thickness dash smoothness inspect}
	oval       {thickness outline fillcolor dash inspect}
	pen        {thickness smoothness inspect}
	polygon    {thickness outline fillcolor dash smoothness inspect}
	rectangle  {thickness fillcolor dash inspect}
	text       {font fontsize fontweight color speechbubble inspect}
	qt         {inspectqt exportmovie}
	snack      {}
    }
    foreach name [array names menuArr] {
	set menuDefs(pop,$name) {}
	foreach key $menuArr($name) {
	    lappend menuDefs(pop,$name) $menuDefs(pop,$key)
	}
    }    
}

# UI::NewMain --
#
#       Makes a unique whiteboard.
#
# Arguments:
#       args    -jid
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

proc ::UI::NewMain {args} {    
    variable idmain
    
    set wtop .main[incr idmain].
    eval {::UI::BuildMain $wtop} $args
    
    return $wtop
}

# UI::BuildMain --
#
#       Makes the main toplevel window.
#
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       args        see above
#       
# Results:
#       new instance toplevel created.

proc ::UI::BuildMain {wtop args} {
    global  this state prefs sysFont localStateVars allIPnums privariaFlag
    
    variable allWhiteboards
    variable dims
    variable threadToWtop
    variable jidToWtop
    
    if {![string equal [string index $wtop end] "."]} {
	set wtop ${wtop}.
    }    
    namespace eval ::${wtop}:: "set wtop $wtop"
    
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::state statelocal
    upvar ::${wtop}::opts opts
    
    Debug 3 "::UI::BuildMain args='$args'"
    
    if {[string equal $wtop "."]} {
	set wbTitle {Coccinella (Main)}
    } else {
	set wbTitle {Coccinella}
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
    set wapp(topfr)     ${wtop}frtop.on.fr
    set wapp(servCan)   $wapp(can)
    
    # Init some of the state variables.
    if {$opts(-state) == "disabled"} {
	set state(btState) 00
    }
    foreach key $localStateVars {
	set statelocal($key) $state($key)
    }
    set statelocal(btStateOld) $statelocal(btState)
    if {![winfo exists $wtopReal] && ($wtop != ".")} {
	toplevel $wtopReal -class Whiteboard
	wm withdraw $wtopReal
    }
    lappend allWhiteboards $wtopReal
    wm title $wtopReal $opts(-title)    
     
    # Start with menus.
    if {$wtop == "."} {
	set ::SplashScreen::startMsg [::msgcat::mc splashbuildmenu]
    }
    ::UI::BuildWhiteboardMenus $wtop
        
    # Shortcut buttons at top? Do we want the toolbar to be visible.
    if {$wtop == "."} {
	set ::SplashScreen::startMsg [::msgcat::mc splashbuild]
    }
    if {$state(visToolbar)} {
	::UI::ConfigShortcutButtonPad $wtop init
    } else {
	::UI::ConfigShortcutButtonPad $wtop init off
    }
    
    # Special configuration of shortcut buttons.
    if {[info exists opts(-type)] && [string equal $opts(-type) "normal"]} {
	::UI::ButtonConfigure $wtop stop -command  \
	  [list ::ImageAndMovie::HttpResetAll $wtop]
    }
    
    # Make the tool button pad.
    pack [frame ${wtop}fmain -borderwidth 0 -bg $prefs(bgColGeneral) -relief flat] \
      -side top -fill both -expand true
    pack [frame ${wtop}fmain.frleft] -side left -fill y
    pack [frame $wapp(tool)] -side top
    pack [label ${wtop}fmain.frleft.pad -relief raised -borderwidth 1]  \
      -fill both -expand true
    
    # The 'Coccinella'.
    if {$prefs(coccinellaMovie)} {
	pack [movie ${wtop}fmain.frleft.padphoto -controller 0  \
	  -file [file join images beetle<->igelpiga.mov]]  \
	  -in ${wtop}fmain.frleft.pad -side bottom
	${wtop}fmain.frleft.padphoto palindromeloopstate 1
    } else {
	pack [label ${wtop}fmain.frleft.padphoto -borderwidth 0 -image igelpiga]  \
	  -in ${wtop}fmain.frleft.pad -side bottom
    }
    
    # ...and the drawing canvas.
    if {$prefs(haveScrollbars)} {
	set f [frame ${wtop}fmain.fc -bd 1 -relief raised]
	set wxsc $f.xsc
	set wysc $f.ysc
	
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
    
    # Make the tool buttons and invoke the one from the prefs file.
    ::UI::CreateAllButtons $wtop

    # Make the connection frame.
    pack [frame ${wtop}fcomm] -side top -fill x
    
    # Status message part.
    pack [frame ${wtop}fcomm.st -relief raised -borderwidth 1]  \
      -side top -fill x -pady 0
    pack [frame ${wtop}fcomm.stat -relief groove -bd 2]  \
      -side top -fill x -padx 10 -pady 2 -in ${wtop}fcomm.st
    pack [canvas $wapp(statmess) -bd 0 -highlightthickness 0 -height 14]  \
      -side left -pady 1 -padx 6 -fill x -expand true
    $wapp(statmess) create text 0 0 -anchor nw -text {} -font $sysFont(s) \
      -tags stattxt
    
    # Build the header for the actual network setup.
    ::UI::SetCommHead $wtop $prefs(protocol) -connected $isConnected
    pack [frame ${wtop}fcomm.pad -relief raised -borderwidth 1]  \
      -side right -fill both -expand true
    pack [label ${wtop}fcomm.pad.hand -relief flat -borderwidth 0 -image im_handle] \
      -side right -anchor sw
    
    # Do we want a persistant jabber entry?
    if {[string equal $prefs(protocol) "jabber"]} {
	::Jabber::InitWhiteboard $wtop
    	if {$prefs(jabberCommFrame)} {
	    eval {::Jabber::BuildJabberEntry $wtop} $args
    	}
    }
    
    # Invoke tool button.
    ::UI::ClickToolButton $wtop  \
      [::UI::ToolBtNumToName $statelocal(btState)]
    
    if {$wtop == "."} {
	
	# Setting the window position never hurts. Check that it fits to screen.
	if {$dims(x) > [expr [winfo vrootwidth .] - 30]} {
	    set dims(x) 30
	}
	if {$dims(y) > [expr [winfo vrootheight .] - 30]} {
	    set dims(y) 30
	}
	wm geometry $wtop +$dims(x)+$dims(y)

	# Setting total (root) size however, should only be done if set in pref file!
	# This needs to be fixed!!!!!!!!!!!!!!!!!
	if {$dims(wRoot) > 1 && $dims(hRoot) > 1} {
	    wm geometry . $dims(wRoot)x$dims(hRoot)
	}

	# If user just click the close box, be sure to save prefs first.
	wm protocol . WM_DELETE_WINDOW [list ::UserActions::DoQuit -warning 1]
	
	# Mac OS X have the Quit menu on the Apple menu instead. Catch it!
	if {[string equal $this(platform) "macosx"]} {
	    if {![catch {package require tclAE}]} {
		tclAE::installEventHandler aevt quit ::UI::AEQuitHandler
	    }
	}
	
	# A trick to let the window manager be finished before getting the geometry.
	# An 'update idletasks' needed anyway in 'FindWidgetGeometryAtLaunch'.
	after idle ::UI::FindWidgetGeometryAtLaunch .
    } else {
	    
	# The minsize when no connected clients. Is updated when connect/disconnect.
	wm minsize $wtopReal $dims(wMinTot) $dims(hMinTot)
	wm protocol $wtopReal WM_DELETE_WINDOW [list ::UI::CloseMain $wtop]
    }

    # Add things that are defined in the prefs file and not updated else.
    ::UserActions::DoCanvasGrid $wtop

    # Set up paste menu if something on the clipboard.
    ::UI::AppGetFocus $wtop $wtopReal
    bind $wtopReal <FocusIn> [list ::UI::AppGetFocus $wtop %W]

    catch {wm deiconify $wtopReal}

    # Update size info when application is resized.
    if {1 || !$prefs(haveScrollbars)} {
	bind $wapp(can) <Configure> [list ::UI::CanvasConfigureCallback "all"]
    }
    if {$isConnected} {
    	::UI::FixMenusWhen $wtop "connect"
    } elseif {0} {
    	::UI::FixMenusWhen $wtop "disconnect"
    }
    
    # Manage the undo/redo object.
    set statelocal(undotoken) [undo::new -command [list ::UI::UndoConfig $wtop]]
}

# UI::CloseMain --
#
#       Called when closing whiteboard window; cleanup etc.

proc ::UI::CloseMain {wtop} {

    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
    set topw $wapp(toplevel)
    set jtype [::UI::GetJabberType $wtop]
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
	    ::Jabber::GroupChat::Exit $opts(-jid)
	}
	default {
	    ::UI::DestroyMain $wtop
	}
    }
}

# UI::DestroyMain --
# 
#       Destroys toplevel whiteboard and cleans up.

proc ::UI::DestroyMain {wtop} {
    
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts

    set topw $wapp(toplevel)

    catch {destroy $topw}    
    unset opts
    unset wapp
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
	    if {[info exists jidToWtop($jid)]} {
		set wtop $jidToWtop($jid)
	    }	    
	}
    }
    
    # Verify that toplevel actually exists.
    if {[string length $wtop]} {
	if {[string equal $wtop "."]} {
	    set wtoplevel .
	} else {
	    set wtoplevel [string trimright $wtop "."]
	}
	if {![winfo exists $wtoplevel]} {
	    set wtop ""
	}
    }
    return $wtop
}

# UI::SetStatusMessage --

proc ::UI::SetStatusMessage {wtop msg} {
    
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

proc ::UI::GetAllWhiteboards { } {
    
    variable allWhiteboards    
    
    foreach wtop $allWhiteboards {
	if {[winfo exists $wtop]} {
	    lappend allTops $wtop
	}
    }
    set allWhiteboards $allTops
    return $allWhiteboards
}


# UI::ClickToolButton --
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

proc ::UI::ClickToolButton {wtop btName} {
    global  prefs wapp plugin this
    
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::state state
    upvar ::${wtop}::opts opts

    Debug 3 "ClickToolButton:: wtop=$wtop, btName=$btName"
    
    set wCan $wapp(can)
    set state(btState) [::UI::ToolBtNameToNum $btName]
    set irow [string index $state(btState) 0]
    set icol [string index $state(btState) 1]
    $wapp(tool).bt$irow$icol configure -image im_on$irow$icol
    if {$state(btState) != $state(btStateOld)} {
	set irow [string index $state(btStateOld) 0]
	set icol [string index $state(btStateOld) 1]
	$wapp(tool).bt$irow$icol configure -image im_off$irow$icol
    }
    set state(btStateOld) $state(btState)
    RemoveAllBindings $wCan
    
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
    
    switch -- $btName {
	point {
	    bind $wCan <Button-1> {
		::CanvasDraw::MarkBbox %W 0
		::CanvasDraw::InitBox %W [%W canvasx %x] [%W canvasy %y] rect
	    }
	    bind $wCan <Shift-Button-1>	{
		::CanvasDraw::MarkBbox %W 1
		::CanvasDraw::InitBox %W [%W canvasx %x] [%W canvasy %y] rect
	    }
	    bind $wCan <B1-Motion> {
		::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 0 rect 1
		::CanvasUtils::StopTimerToItemPopup
	    }
	    bind $wCan <ButtonRelease-1> {
		::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 0 rect 1
	    }
	    bind $wCan <Double-Button-1>  \
	      [list ::ItemInspector::ItemInspector $wtop current]

	    switch -- $this(platform) {
		macintosh - macosx {
		    $wCan bind all <Button-1> {
			
			# Global coords for popup.
			::CanvasUtils::StartTimerToItemPopup %W %X %Y 
		    }
		    $wCan bind all <ButtonRelease-1> {
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
		    $wCan bind all <Button-3> {
			
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
	    # The frame with the movie the mouse events, not the canvas.
	    # With shift constrained move.
	    bind $wCan <Button-1> {
		InitMove %W [%W canvasx %x] [%W canvasy %y]
	    }
	    bind $wCan <B1-Motion> {
		DoMove %W [%W canvasx %x] [%W canvasy %y] item
	    }
	    bind $wCan <ButtonRelease-1> {
		FinalizeMove %W [%W canvasx %x] [%W canvasy %y]
	    }
	    bind $wCan <Shift-B1-Motion> {
		DoMove %W [%W canvasx %x] [%W canvasy %y] item 1
	    }
	    
	    # Moving single coordinates.
	    $wCan bind tbbox <Button-1> {
		InitMove %W [%W canvasx %x] [%W canvasy %y] point
	    }
	    $wCan bind tbbox <B1-Motion> {
		DoMove %W [%W canvasx %x] [%W canvasy %y] point
	    }
	    $wCan bind tbbox <ButtonRelease-1> {
		FinalizeMove %W [%W canvasx %x] [%W canvasy %y] point
	    }
	    $wCan bind tbbox <Shift-B1-Motion> {
		DoMove %W [%W canvasx %x] [%W canvasy %y] point 1
	    }
		
	    # Needed this to get wCan substituted in callbacks. Note %%.
	    set scriptInitMove [format {
		InitMove %s  \
		  [%s canvasx [expr [winfo x %%W] + %%x]]  \
		  [%s canvasy [expr [winfo y %%W] + %%y]] movie
	    } $wCan $wCan $wCan]	
	    set scriptDoMove [format {
		DoMove %s  \
		  [%s canvasx [expr [winfo x %%W] + %%x]]  \
		  [%s canvasy [expr [winfo y %%W] + %%y]] movie
	    } $wCan $wCan $wCan]	
	    set scriptFinalizeMove [format {
		FinalizeMove %s  \
		  [%s canvasx [expr [winfo x %%W] + %%x]]  \
		  [%s canvasy [expr [winfo y %%W] + %%y]] movie
	    } $wCan $wCan $wCan]	
	    set scriptDoMoveCon [format {
		DoMove %s  \
		  [%s canvasx [expr [winfo x %%W] + %%x]]  \
		  [%s canvasy [expr [winfo y %%W] + %%y]] movie 1
	    } $wCan $wCan $wCan]	
	    
	    # Moving movies.
	    bind QTFrame <Button-1> $scriptInitMove
	    bind QTFrame <B1-Motion> $scriptDoMove
	    bind QTFrame <ButtonRelease-1> $scriptFinalizeMove
	    bind QTFrame <Shift-B1-Motion> $scriptDoMoveCon

	    bind SnackFrame <Button-1> $scriptInitMove
	    bind SnackFrame <B1-Motion> $scriptDoMove
	    bind SnackFrame <ButtonRelease-1> $scriptFinalizeMove
	    bind SnackFrame <Shift-B1-Motion> $scriptDoMoveCon
	    
	    # Moving sequence grabber.
	    bind SGFrame <Button-1> $scriptInitMove
	    bind SGFrame <B1-Motion> $scriptDoMove
	    bind SGFrame <ButtonRelease-1> $scriptFinalizeMove
	    bind SGFrame <Shift-B1-Motion> $scriptDoMoveCon
	    
	    $wCan config -cursor hand2
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatmove]
	}
	line {
	    bind $wCan <Button-1> {
		InitLine %W [%W canvasx %x] [%W canvasy %y]
	    }
	    bind $wCan <B1-Motion> {
		LineDrag %W [%W canvasx %x] [%W canvasy %y] 0
	    }
	    bind $wCan <Shift-B1-Motion> {
		LineDrag %W [%W canvasx %x] [%W canvasy %y] 1
	    }
	    bind $wCan <ButtonRelease-1> {
		FinalizeLine %W [%W canvasx %x] [%W canvasy %y] 0
	    }
	    bind $wCan <Shift-ButtonRelease-1> {
		FinalizeLine %W [%W canvasx %x] [%W canvasy %y] 1
	    }
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatline]
	}
	arrow {
	    bind $wCan <Button-1> {
		InitLine %W [%W canvasx %x] [%W canvasy %y] arrow
	    }
	    bind $wCan <B1-Motion> {
		LineDrag %W [%W canvasx %x] [%W canvasy %y] 0 arrow
	    }
	    bind $wCan <Shift-B1-Motion> {
		LineDrag %W [%W canvasx %x] [%W canvasy %y] 1 arrow
	    }
	    bind $wCan <ButtonRelease-1> {
		FinalizeLine %W [%W canvasx %x] [%W canvasy %y] 0 arrow
	    }
	    bind $wCan <Shift-ButtonRelease-1> {
		FinalizeLine %W [%W canvasx %x] [%W canvasy %y] 1 arrow
	    }
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatarrow]
	}
	rect {
	    
	    # Bindings for rectangle drawing.
	    bind $wCan <Button-1> {
		::CanvasDraw::InitBox %W [%W canvasx %x] [%W canvasy %y] rect
	    }
	    bind $wCan <B1-Motion> {
		::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 0 rect
	    }
	    bind $wCan <Shift-B1-Motion> {
		::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 1 rect
	    }
	    bind $wCan <ButtonRelease-1> {
		::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 0 rect
	    }
	    bind $wCan <Shift-ButtonRelease-1> {
		::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 1 rect
	    }
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatrect]
	}
	oval {
	    bind $wCan <Button-1> {
		::CanvasDraw::InitBox %W [%W canvasx %x] [%W canvasy %y] oval
	    }
	    bind $wCan <B1-Motion> {
		::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 0 oval
	    }
	    bind $wCan <Shift-B1-Motion> {
		::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 1 oval
	    }
	    bind $wCan <ButtonRelease-1> {
		::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 0 oval
	    }
	    bind $wCan <Shift-ButtonRelease-1> {
		::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 1 oval
	    }
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatoval]
	}
	text {
	    ::CanvasText::EditBind $wCan
	    $wCan config -cursor xterm
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastattext]
	}
	del {
	    bind $wCan <Button-1> {
		::CanvasDraw::DeleteItem %W [%W canvasx %x] [%W canvasy %y]
	    }
	    set scriptDeleteItem [format {
		::CanvasDraw::DeleteItem %s  \
		  [%s canvasx [expr [winfo x %%W] + %%x]]  \
		  [%s canvasy [expr [winfo y %%W] + %%y]] movie
	    } $wCan $wCan $wCan]	
	    bind QTFrame <Button-1> $scriptDeleteItem
	    bind SnackFrame <Button-1> $scriptDeleteItem
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatdel]
	}
	pen {
	    bind $wCan <Button-1> {
		InitStroke %W [%W canvasx %x] [%W canvasy %y]
	    }
	    bind $wCan <B1-Motion> {
		StrokeDrag %W [%W canvasx %x] [%W canvasy %y]
	    }
	    bind $wCan <ButtonRelease-1> {
		FinalizeStroke %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan config -cursor pencil
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatpen]
	}
	brush {
	    bind $wCan <Button-1> {
		InitStroke %W [%W canvasx %x] [%W canvasy %y]
	    }
	    bind $wCan <B1-Motion> {
		StrokeDrag %W [%W canvasx %x] [%W canvasy %y] 1
	    }
	    bind $wCan <ButtonRelease-1> {
		FinalizeStroke %W [%W canvasx %x] [%W canvasy %y] 1
	    }
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatbrush]
	}
	paint {
	    bind $wCan  <Button-1> {
		DoPaint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    bind $wCan  <Shift-Button-1> {
		DoPaint %W [%W canvasx %x] [%W canvasy %y] 1
	    }
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatpaint]	      
	}
	poly {
            bind $wCan  <Button-1> {
		PolySetPoint %W [%W canvasx %x] [%W canvasy %y]
	    }
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatpoly]	      
        }       
	arc {
	    bind $wCan <Button-1> {
		InitArc %W [%W canvasx %x] [%W canvasy %y]
	    }
	    bind $wCan <Shift-Button-1> {
		InitArc %W [%W canvasx %x] [%W canvasy %y] 1
	    }
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatarc]	      
	}
	rot {
	    bind $wCan <Button-1> {
		InitRotateItem %W [%W canvasx %x] [%W canvasy %y]
	    }
	    bind $wCan <B1-Motion> {
		DoRotateItem %W [%W canvasx %x] [%W canvasy %y] 0
	    }
	    bind $wCan <Shift-B1-Motion> {
		DoRotateItem %W [%W canvasx %x] [%W canvasy %y] 1
	    }
	    bind $wCan <ButtonRelease-1> {
		FinalizeRotate %W [%W canvasx %x] [%W canvasy %y]
	    }
	    $wCan config -cursor exchange
	    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatrot]	      
	}
    }
    
    # Collect all common non textual bindings in one procedure.
    if {$btName != "text"} {
	GenericNonTextBindings $wtop
    }

    # This is a hook for plugins to register their own bindings.
    # Call any registered bindings for the plugin.
    foreach key [array names plugin "*,bindProc"] {
	$plugin($key) $btName
    }
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
    
    Debug 3 "RemoveAllBindings::"

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
    
    bind $w <Button> {}
    bind $w <Button-1> {}
    bind $w <Button-Motion> {}
    bind $w <ButtonRelease> {}
    bind $w <Shift-Button-1> {}
    bind $w <Double-Button-1> {}
    bind $w <Any-Key> {}
    bind $w <ButtonRelease-1> {}
    bind $w <B1-Motion> {}
    bind $w <Shift-B1-Motion> {}
    bind $w <Shift-ButtonRelease-1> {}
    bind $w <BackSpace> {}
    bind $w <Control-d> {}
    bind QTFrame <Button-1> {}
    bind QTFrame <B1-Motion> {}
    bind QTFrame <ButtonRelease-1> {}
    bind SnackFrame <Button-1> {}
    bind SnackFrame <B1-Motion> {}
    bind SnackFrame <ButtonRelease-1> {}
    focus .
    
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

# UI::MakeMenu --
#
#       Make menus recursively from a hierarchical menu definition list.
#
# Arguments:
#       wtop        toplevel window. ("." or ".main2." with extra dot!)
#       wmenu       the menus widget path name (".menu.file" etc.).
#       label       its label.
#       menuDef     a hierarchical list that defines the menu content.
#       args        form ?-varName value? list that defines local variables to set.
#       
# Results:
#       $wmenu

proc ::UI::MakeMenu {wtop wmenu label menuDef args} {
    global  this wDlgs prefs dashFull2Short osprefs
    
    variable menuKeyToIndex
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
    set topw $wapp(toplevel)
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
		eval {::UI::MakeMenu $wtop ${wmenu}.${mt} $name $subdef} $args
		
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
			if {[string equal $opts(-state) "normal"]} {
			    if {[string equal $mstate "normal"]} {
				bind $topw <${mod}-Key-${key}> $cmd
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

# UI::MenuMethod --
#  
#       Utility to use instead of 'menuPath cmd index args'.

proc ::UI::MenuMethod {wmenu cmd key args} {
    global  this prefs wDlgs osprefs
    variable menuKeyToIndex
    variable menuDefs
    variable mapWmenuToMenuDefKey
    variable mapWmenuToWtop
            
    set mind $menuKeyToIndex($wmenu,$key)
    eval {$wmenu $cmd $mind} $args
    
    # Handle any menu accelerators as well. 
    # Make sure the necessary variables for the command exist here!
    if {![string equal $this(platform) "macintosh"] && \
      [info exists mapWmenuToMenuDefKey($wmenu)]} {
	set ind [lsearch $args "-state"]
	if {$ind >= 0} {
	    set mstate [lindex $args [incr ind]]
	    set menuDefKey $mapWmenuToMenuDefKey($wmenu)
	    set wtop $mapWmenuToWtop($wmenu)
    	    upvar ::${wtop}::wapp wapp
    	    
    	    set topw $wapp(toplevel)
	    set mcmd [lindex [lindex $menuDefs($menuDefKey) $mind] 2]
	    set mcmd [subst -nocommands $mcmd]
	    set acc [lindex [lindex $menuDefs($menuDefKey) $mind] 4]
	    if {[string length $acc]} {
		set key [string map {< less > greater} [string tolower $acc]]
		if {[string equal $mstate "normal"]} {
		    bind $topw <$osprefs(mod)-Key-${key}> $mcmd
		} else {
		    bind $topw <$osprefs(mod)-Key-${key}> {}
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
    
    variable addonMenus
    variable menuDefs
    variable mapWmenuToMenuDefKey
    variable mapWmenuToWtop
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
    
    # Various mappings needed for the MenuMethod.
    set mapWmenuToMenuDefKey(${wmenu}.apple) "main,apple"
    set mapWmenuToMenuDefKey(${wmenu}.file) "main,file"
    set mapWmenuToMenuDefKey(${wmenu}.edit) "main,edit"
    set mapWmenuToMenuDefKey(${wmenu}.prefs) "main,prefs"
    set mapWmenuToMenuDefKey(${wmenu}.jabber) "main,jabber"
    set mapWmenuToMenuDefKey(${wmenu}.info) "main,info"
    set mapWmenuToWtop(${wmenu}.apple) $wtop
    set mapWmenuToWtop(${wmenu}.file) $wtop
    set mapWmenuToWtop(${wmenu}.edit) $wtop
    set mapWmenuToWtop(${wmenu}.prefs) $wtop
    set mapWmenuToWtop(${wmenu}.jabber) $wtop
    set mapWmenuToWtop(${wmenu}.info) $wtop

    if {$haveAppleMenu} {
	::UI::MakeMenu $wtop ${wmenu}.apple {}         $menuDefs(main,apple)
    }
    ::UI::MakeMenu $wtop ${wmenu}.file    mFile        $menuDefs(main,file)
    ::UI::MakeMenu $wtop ${wmenu}.edit    mEdit        $menuDefs(main,edit)
    ::UI::MakeMenu $wtop ${wmenu}.prefs   mPreferences $menuDefs(main,prefs)
    
    if {!$prefs(stripJabber)} {
	::UI::MakeMenu $wtop ${wmenu}.jabber mJabber   $menuDefs(main,jabber)
	
	# The jabber stuff needs to know the "Exit Room" menu. WRONG!!!!! multinstance
	if {$wtop == "."} {
	    ::Jabber::GroupChat::SetAllRoomsMenu ${wmenu}.jabber.mexitroom
	}
	
	# Grouchat whiteboards have their own presence status sent to room.
	set jtype [::UI::GetJabberType $wtop]
	if {[string equal $jtype "groupchat"]} {
	    ::Jabber::GroupChat::ConfigWBStatusMenu $wtop
	}
    }
    
    # Item menu (temporary placement).
    ::UI::BuildItemMenu $wtop ${wmenu}.items $prefs(itemDir)
    
    if {0 && $prefs(QuickTimeTcl)} {
	::UI::MakeMenu $wtop ${wmenu}.cam {Camera/Mic }  $menuDefs(main,cam)
    }
    ::UI::MakeMenu $wtop ${wmenu}.info    mInfo     $menuDefs(main,info)
    
    # Addon menu.
    if {[llength $addonMenus]} {
	set m [menu ${wmenu}.addon -tearoff 0]
	$wmenu add cascade -label [::msgcat::mc mAddons] -menu $m
	foreach menuSpec $addonMenus {
	    ::UI::BuildAddonMenuEntry $m $menuSpec
	}
    }
    
    # Handle '-state disabled' option. Keep Edit/Copy.
    if {$opts(-state) == "disabled"} {
	::UI::DisableWhiteboardMenus $wmenu
    }
    
    # Use a function for this to dynamically build this menu if needed.
    ::UI::BuildFontMenu $wtop $prefs(canvasFonts)    
    if {!$prefs(stripJabber) && ![string equal $prefs(protocol) "jabber"]} {
	$wmenu entryconfigure *Jabber* -state disabled
    }
        
    # End menus; place the menubar.
    if {$prefs(haveMenus)} {
	$topwindow configure -menu $wmenu
    } else {
	pack $wmenu -side top -fill x
    }
}

# UI::DisableWhiteboardMenus --
#
#       Handle '-state disabled' option. Sets in a readonly state.

proc ::UI::DisableWhiteboardMenus {wmenu} {
    
    ::UI::MenuDisableAllBut ${wmenu}.file {
	mNew mCloseWindow mSaveCanvas mPageSetup mPrintCanvas mQuit
    }
    ::UI::MenuDisableAllBut ${wmenu}.edit {mAll}
    $wmenu entryconfigure [::msgcat::mc mPreferences] -state disabled
    $wmenu entryconfigure [::msgcat::mc mJabber] -state disabled
    $wmenu entryconfigure [::msgcat::mc mItems] -state disabled
    $wmenu entryconfigure [::msgcat::mc mInfo] -state disabled
        
    catch {$wmenu entryconfigure [::msgcat::mc mAddons] -state disabled}
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

# UI::RegisterAddonMenuEntry --
#
#       
# Arguments:
#       menuSpec    'type' 'label' 'command' 'opts' {subspec}
#       
# Results:
#       menu entries added.

proc ::UI::RegisterAddonMenuEntry {menuSpec} {
    
    variable addonMenus
    
    lappend addonMenus $menuSpec
}

# UI::BuildAddonMenuEntry  --
#
#       Builds a single menu entry for the addon menu.
#       Can be called recursively.

proc ::UI::BuildAddonMenuEntry {m menuSpec} {
    
    foreach {type label cmd opts submenu} $menuSpec {
	if {[llength $submenu]} {
	    set mt [menu ${m}.sub -tearoff 0]
	    $m add cascade -label $label -menu $mt
	    foreach subm $submenu {
		::UI::BuildAddonMenuEntry $mt $subm
	    }
	} else {
	    eval {$m add $type -label $label -command $cmd} $opts
	}
    }
}

# UI::UndoConfig  --
# 
#       Callback for the undo/redo object.
#       Sets the menu's states.

proc ::UI::UndoConfig {wtop token what mstate} {
        
    switch -- $what {
	undo {
	    ::UI::MenuMethod ${wtop}menu.edit entryconfigure mUndo -state $mstate
	}
	redo {
	    ::UI::MenuMethod ${wtop}menu.edit entryconfigure mRedo -state $mstate	    
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
#       what      can be "init", "on", or "off".
#       subSpec   is only valid for 'init' where it can be 'off'.
#       
# Results:
#       toolbar created, or state toggled.

proc ::UI::ConfigShortcutButtonPad {wtop what {subSpec {}}} {
    global  this wDlgs prefs
    
    variable dims
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
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
	pack [label $wonbar -image barvert -bd 1 -relief raised] \
	  -padx 0 -pady 0 -side left
	pack [frame $wapp(topfr) -relief raised -borderwidth 1]  \
	  -side left -fill both -expand 1
	label $woffbar -image barhoriz -relief raised -borderwidth 1
	bind $wonbar <Button-1> [list $wonbar configure -relief sunken]
	bind $wonbar <ButtonRelease-1>  \
	  [list ::UI::ConfigShortcutButtonPad $wtop "off"]
	
	# Build the actual shortcut button pad.
	::UI::BuildShortcutButtonPad $wtop
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
    }
}

# UI::BuildShortcutButtonPad --
#
#       Build the actual shortcut button pad.

proc ::UI::BuildShortcutButtonPad {wtop} {
    global  sysFont prefs wDlgs this
    
    variable btShortDefs
    upvar ::${wtop}::wapp wapp
    
    set wCan $wapp(can)
    set h [image height barvert]
    set inframe $wapp(topfr)
    ::UI::InitShortcutButtonPad $wtop $inframe $h
    
    # We need to substitute $wCan, $wtop etc specific for this wb instance.
    foreach {name cmd} $btShortDefs {
	set cmd [subst -nocommands -nobackslashes $cmd]
	::UI::NewButton $wtop $name bt$name bt${name}dis $cmd
    }
    if {[string equal $prefs(protocol) "server"]} {
	::UI::ButtonConfigure $wtop connect -state disabled
    }
    ::UI::ButtonConfigure $wtop send -state disabled
}

# UI::DisableShortcutButtonPad --
#
#       Sets the state of the main to "read only".

proc ::UI::DisableShortcutButtonPad {wtop} {
    variable btShortDefs

    foreach {name cmd} $btShortDefs {
	switch -- $name {
	    save - print - stop {
		continue
	    }
	    default {
		::UI::ButtonConfigure $wtop $name -state disabled
	    }
	}
    }
}

# UI::InitShortcutButtonPad --
#
#       Init a shortcut button pad.

proc ::UI::InitShortcutButtonPad {wtop inframe height} {
    global  prefs
    
    namespace eval ::UI::$wtop {
	variable locals
    }

    # Set simpler variable names.
    upvar ::UI::${wtop}::locals locals
    
    set locals(inframe) $inframe
    set locals(xoffset) 28
    set locals(yoffset) 3
    set locals(can) $inframe.can
    
    pack [canvas $locals(can) -highlightthickness 0 -height $height  \
      -bg $prefs(bgColGeneral)] \
      -fill both -expand 1
}

proc ::UI::NewButton {wtop name image imageDis cmd args} {
    global  sysFont
    
    upvar ::UI::${wtop}::locals locals
    
    set inframe $locals(inframe)
    
    set can $locals(can)
    set txt "[string toupper [string index $name 0]][string range $name 1 end]"
    set loctxt [::msgcat::mc $txt]
    set wlab [label $can.[string tolower $name] -bd 1 -relief flat \
      -image $image]
    set idlab [$can create window $locals(xoffset) $locals(yoffset) \
      -anchor n -window $wlab]
    set idtxt [$can create text $locals(xoffset) [expr $locals(yoffset) + 34] \
      -text $loctxt -font $sysFont(s) -anchor n -fill blue]
    
    set locals($name,idlab) $idlab
    set locals($name,idtxt) $idtxt
    set locals($name,wlab) $wlab
    set locals($name,image) $image
    set locals($name,imageDis) $imageDis
    set locals($name,cmd) $cmd

    ::UI::SetShortButtonBinds $wtop $name
    if {[llength $args]} {
	eval {::UI::ButtonConfigure $wtop $name} $args
    }
    incr locals(xoffset) 46
}

proc ::UI::SetShortButtonBinds {wtop name} {
    
    upvar ::UI::${wtop}::locals locals
    
    set can $locals(can)
    set wlab $locals($name,wlab)
    set idtxt $locals($name,idtxt)
    set cmd $locals($name,cmd)

    bind $wlab <Enter> "$wlab configure -relief raised;  \
      $can itemconfigure $idtxt -fill red"
    bind $wlab <Leave> "$wlab configure -relief flat;  \
      $can itemconfigure $idtxt -fill blue"
    bind $wlab <Button-1> [list $wlab configure -relief sunken]
    bind $wlab <ButtonRelease> "[list $wlab configure -relief raised]; $cmd"

    $can bind $idtxt <Enter> "$can itemconfigure $idtxt -fill red;  \
      $can configure -cursor hand2"
    $can bind $idtxt <Leave> "$can itemconfigure $idtxt -fill blue;  \
      $can configure -cursor arrow"
    $can bind $idtxt <Button-1> $cmd
}

# UI::ButtonConfigure --
#
#

proc ::UI::ButtonConfigure {wtop name args} {
    
    upvar ::UI::${wtop}::locals locals

    set wlab $locals($name,wlab)
    set idtxt $locals($name,idtxt)
    set can $locals(can)
    foreach {key value} $args {
	switch -- $key {
	    -command {
		set locals($name,cmd) $value
		::UI::SetShortButtonBinds $wtop $name
	    }
	    -state {
		if {[string equal $value normal]} {
		    $wlab configure -image $locals($name,image)
		    $can itemconfigure $idtxt -fill blue
		    ::UI::SetShortButtonBinds $wtop $name
		} else {
		    $wlab configure -image $locals($name,imageDis) -relief flat
		    $can itemconfigure $idtxt -fill gray50
		    bind $wlab <Enter> {}
		    bind $wlab <Leave> {}
		    bind $wlab <Button-1> {}
		    bind $wlab <ButtonRelease> {}
		    $can bind $idtxt <Enter> {}
		    $can bind $idtxt <Leave> {}
		    $can bind $idtxt <Button-1> {}
		}
	    }
	}
    }
}

proc ::UI::IsShortcutButtonVisable {wtop} {
    
    return [winfo ismapped ${wtop}frtop.on]
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
    bind $locals($w,wtop) <FocusIn> [list ::UI::CutCopyPasteFocusIn $w]
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

proc ::UI::CutCopyPasteCheckState {state clipState} {

    upvar ::UI::CCP::locals locals

    #puts "::UI::CutCopyPasteCheckState state=$state, clipState=$clipState"
    set tmp {}
    foreach w $locals(wccpList) {
	if {[winfo exists $w]} {
	    lappend tmp $w
	    ::UI::CutCopyPasteConfigure $w cut -state $state
	    ::UI::CutCopyPasteConfigure $w copy -state $state	    
	    ::UI::CutCopyPasteConfigure $w paste -state $clipState	    	    
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
    upvar ::${wtop}::state state
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
    set wtool $wapp(tool)
    
    for {set icol 0} {$icol <= 1} {incr icol} {
	for {set irow 0} {$irow <= 6} {incr irow} {
	    
	    # The icons are Mime coded gifs.
	    set lwi [label $wtool.bt$irow$icol -image im_off$irow$icol \
	      -borderwidth 0]
	    grid $lwi -row $irow -column $icol -padx 0 -pady 0
	    set name $btNo2Name($irow$icol)
	    
	    if {![string equal $opts(-state) "disabled"]} {
		bind $lwi <Button-1>  \
		  [list ::UI::ClickToolButton $wtop $name]
		
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
    set imheight [image height imcolor]
    set wColSel [canvas $wtool.cacol -width 56 -height $imheight  \
      -highlightthickness 0]
    $wtool.cacol create image 0 0 -anchor nw -image imcolor
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
	pen        {thickness smoothness}
	brush      {brushthickness smoothness}
	text       {font fontsize fontweight}
	poly       {thickness fill dash smoothness}
	arc        {thickness fill dash arcs}
    }
    foreach name [array names menuArr] {
	set mDef($name) {}
	foreach key $menuArr($name) {
	    lappend mDef($name) $menuDefs(main,prefs,$key)
	}
	::UI::MakeMenu $wtop ${wtool}.pop${name} {} $mDef($name)
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

# UI::FindWidgetGeometryAtLaunch --
#
#       Just after launch, find and set various geometries of the application.
#       'hRoot' excludes the menu height, 'hTot' includes it.
#       Note: [winfo height .#menu] gives the menu height when the menu is in the
#       root window; [wm geometry .] gives and sets dimensions *without* the menu;
#       [wm minsize .] gives and sets dimensions *with* the menu included.
#       EAS: TclKit w/ Tcl 8.4 returns an error "bad window path name ".#menu"
#
# dims array:
#       wRoot, hRoot:      total size of the application not including any menu.
#       wTot, hTot:        total size of the application including any menu.
#       hTop:              height of the shortcut button frame at top.
#       hMenu:             height of any menu if present in the application window.
#       hStatus:           height of the status frame.
#       hComm:             height of the communication frame including all client
#                          frames.
#       hCommClean:        height of the communication frame excluding all client 
#                          frames.
#       wStatMess:         width of the status message frame.
#       wCanvas, hCanvas:  size of the actual canvas.
#       x, y:              position of the app window.

proc ::UI::FindWidgetGeometryAtLaunch {wtop} {
    global  this prefs
    
    variable dims
    upvar ::${wtop}::wapp wapp

    # Changed to reqwidth and reqheight instead of width and height.
    # EAS: Begin
    # update idletasks
    update
    # EAS: End
    
    set wCan $wapp(can)
    
    # The actual dimensions.
    set dims(wRoot) [winfo reqwidth .]
    set dims(hRoot) [winfo reqheight .]
    set dims(hTop) 0
    if {[winfo exists .frtop]} {
	set dims(hTop) [winfo reqheight .frtop]
    }
    set dims(hTopOn) [winfo reqheight .frtop.on]
    set dims(hTopOff) [winfo reqheight .frtop.barhoriz]
    set dims(hStatus) [winfo reqheight .fcomm.st]
    set dims(hComm) [winfo reqheight $wapp(comm)]
    set dims(hCommClean) $dims(hComm)
    set dims(wStatMess) [winfo reqwidth $wapp(statmess)]
    
    # If we have a custom made menubar using a frame with labels (embedded).
    if {$prefs(haveMenus)} {
	set dims(hFakeMenu) 0
    } else {
	set dims(hFakeMenu) [winfo reqheight .menu]
    }
    if {![string match "mac*" $this(platform)]} {
	# MATS: seems to always give 1 Linux not...
        ### EAS BEGIN
        set dims(hMenu) 1
	if {[winfo exists .#menu]} {
	    set dims(hMenu) [winfo height .#menu]
	}
        ### EAS END
    } else {
	set dims(hMenu) 0
    }
    set dims(wCanvas) [winfo width $wCan]
    set dims(hCanvas) [winfo height $wCan]
    set dims(wTot) $dims(wRoot)
    set dims(hTot) [expr $dims(hRoot) + $dims(hMenu)]
    
    # Position of root window.
    set dimList [::UI::ParseWMGeometry .]
    set dims(x) [lindex $dimList 2]  
    set dims(y) [lindex $dimList 3]  

    # The minimum dimensions. Check if 'wapp(comm)' is wider than wMinCanvas!
    # Take care of the case where there is no To or From checkbutton.
    
    set wMinCommFrame [expr [winfo width $wapp(comm).comm] +  \
      [winfo width $wapp(comm).user] + [image width im_handle] + 2]
    if {[winfo exists $wapp(comm).to]} {
	incr wMinCommFrame [winfo reqwidth $wapp(comm).to]
    }
    if {[winfo exists $wapp(comm).from]} {
	incr wMinCommFrame [winfo reqwidth $wapp(comm).from]
    }
    set dims(wMinRoot) [max [expr $dims(wMinCanvas) + 56] $wMinCommFrame]
    set dims(hMinRoot) [expr $dims(hMinCanvas) + $dims(hStatus) + $dims(hComm) + \
      $dims(hTop) + $dims(hFakeMenu)]
    if {$prefs(haveScrollbars)} {
	# 2 for padding
	incr dims(wMinRoot) [expr [winfo reqwidth $wapp(ysc)] + 2]
	incr dims(hMinRoot) [expr [winfo reqheight $wapp(xsc)] + 2]
    }
    set dims(wMinTot) $dims(wMinRoot)
    set dims(hMinTot) [expr $dims(hMinRoot) + $dims(hMenu)]
    
    # The minsize when no connected clients. Is updated when connect/disconnect.
    wm minsize . $dims(wMinTot) $dims(hMinTot)
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

# UI::CanvasConfigureCallback --
#   
#       This is the callback from a canvas configure event. 
#       'CanvasSizeChange' is called delayed in an after event.
#   
# Arguments:
#       where           "all" if tell all other connected clients,
#                       0 if none, and an ip number if only this one.
# Results:
#       A 'CanvasSizeChange' call scheduled.

proc ::UI::CanvasConfigureCallback {where} {
    global  configAfterId
    
    if {[info exists configAfterId]} {
	catch {after cancel $configAfterId}
    }
    set configAfterId [after 1000 [list ::UI::CanvasSizeChange $where]]
}

# ::UI::CanvasSizeChange --
#   
#       If size change in canvas (application), then let other clients know.
#   
# Arguments:
#       where           "all" if tell all other connected clients,
#                       0 if none, and an ip number if only this one.
#       force           should we insist on telling other clients even if
#                       the canvas size not changed.

proc ::UI::CanvasSizeChange {where {force 0}} {
    global  allIPnumsToSend prefs this
    
    upvar ::.::wapp wapp
    upvar ::UI::dims dims
    
    set wCan $wapp(can)
    
    # Get new sizes.
    #update idletasks
    update
    
    # Sizes without any menu.
    set w [winfo width .]
    set h [winfo height .]
    set wCanvas [winfo width $wCan]
    set hCanvas [winfo height $wCan]
        
    # Only if size changed or if force.
    if {!$prefs(haveScrollbars) && ($where != "0") && [llength $allIPnumsToSend]} {
	if {($dims(wCanvas) != $wCanvas) || ($dims(hCanvas) != $hCanvas) || \
	  $force } {
	    set cmd "RESIZE: $wCanvas $hCanvas"
	    if {$where == "all"} {
		SendClientCommand [::UI::GetToplevelNS $wCan] $cmd
	    } else {
		
		# We must have a valid ip number.
		SendClientCommand [::UI::GetToplevelNS $wCan] $cmd -ips $where
	    }
	}
    }
    
    # Update actual size values. 'Root' no menu, 'Tot' with menu.
    set dims(wStatMess) [winfo width $wapp(statmess)]
    set dims(wRoot) $w
    set dims(hRoot) $h
    set dims(wTot) $dims(wRoot)
    if {![string match "mac*" $this(platform)]} {
	# MATS: seems to always give 1 Linux not...
        ### EAS BEGIN
        set dims(hMenu) 1
	if {[winfo exists .#menu]} {
	    set dims(hMenu) [winfo height .#menu]
	}
        ### EAS END
    } else {
	set dims(hMenu) 0
    }
    set dims(hTot) [expr $dims(hRoot) + $dims(hMenu)]
    set dims(wCanvas) $wCanvas
    set dims(hCanvas) $hCanvas
}

# ::UI::SetCanvasSize --
#
#       From the canvas size, 'cw' and 'ch', set the total application size.
#       
# Arguments:
#
# Results:

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
        
    # Note: wm minsize is *with* the menu!!!
    wm minsize $wtopReal $dims(wMinTot) $dims(hMinTot)

    # Be sure it is respected. Note: wm geometry is *without* the menu!
    foreach {wmx wmy} [::UI::ParseWMGeometry $wtopReal] { break }
    if {($wmx < $dims(wMinRoot)) || ($wmy < $dims(hMinRoot))} {
	wm geometry $wtopReal $dims(wMinRoot)x$dims(hMinRoot)
    }
    
    Debug 2 "::UI::SetNewWMMinsize:: dims(hComm)=$dims(hComm),  \
      dims(hMinRoot)=$dims(hMinRoot), dims(hMinTot)=$dims(hMinTot), \
      dims(hTop)=$dims(hTop)"
}	    

# UI::AppGetFocus --
#
#       Check clipboard and activate corresponding menus.    
#       
# Results:
#       updates state of menus.

proc ::UI::AppGetFocus {wtop w} {
    
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
    Debug 3 "AppGetFocus:: wtop=$wtop, w=$w"
    
    # Check the clipboard or selection.
    if {[catch {selection get -selection CLIPBOARD} sel]} {
	::UI::MenuMethod ${wtop}menu.edit entryconfigure mPaste -state disabled
    } elseif {($sel != "") && ($opts(-state) == "normal")} {
	::UI::MenuMethod ${wtop}menu.edit entryconfigure mPaste -state normal
    }
    
    # If any selected items canvas. Text items ???
    if {[llength [$wapp(can) find withtag selected]] > 0} {
	::UI::MenuMethod ${wtop}menu.edit entryconfigure mCut -state normal
	::UI::MenuMethod ${wtop}menu.edit entryconfigure mCopy -state normal
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
    global  prefs sysFont
    
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
    global  prefs sysFont
    
    upvar ::${wtop}::wapp wapp
    set wcomm $wapp(comm)
    
    Debug 2 "::UI::BuildCommHead"
    
    array set argsArr {-connected 0}
    array set argsArr $args
    pack [frame $wcomm -relief raised -borderwidth 1] -side left
    switch -- $type {
	jabber {
	    label $wcomm.comm -text "  [::msgcat::mc {Jabber Server}]:"  \
	      -width 18 -anchor w -font $sysFont(sb)
	    label $wcomm.user -text "  [::msgcat::mc {Jabber Id}]:"  \
	      -width 18 -anchor w -font $sysFont(sb)
	    if {$argsArr(-connected)} {
	    	label $wcomm.icon -image contact_on
	    } else {
	    	label $wcomm.icon -image contact_off
	    }
	    grid $wcomm.comm $wcomm.user -sticky nws -pady 0
	    grid $wcomm.icon -row 0 -column 3 -sticky w -pady 0
	}
	symmetric {
	    label $wcomm.comm -text {  Remote address:} -width 22 -anchor w \
	      -font $sysFont(sb)
	    label $wcomm.user -text {  User:} -width 14 -anchor w  \
	      -font $sysFont(sb)
	    label $wcomm.to -text [::msgcat::mc To] -font $sysFont(sb)
	    label $wcomm.from -text [::msgcat::mc From] -font $sysFont(sb)
	    grid $wcomm.comm $wcomm.user $wcomm.to $wcomm.from \
	      -sticky nws -pady 0
	}
	client {
	    label $wcomm.comm -text {  Remote address:} -width 22 -anchor w \
	      -font $sysFont(sb)
	    label $wcomm.user -text {  User:} -width 14 -anchor w \
	      -font $sysFont(sb)
	    label $wcomm.to -text [::msgcat::mc To] -font $sysFont(sb)
	    grid $wcomm.comm $wcomm.user $wcomm.to  \
	      -sticky nws -pady 0
	}
	server {
	    label $wcomm.comm -text {  Remote address:} -width 22 -anchor w \
	      -font $sysFont(sb)
	    label $wcomm.user -text {  User:} -width 14 -anchor w \
	      -font $sysFont(sb)
	    label $wcomm.from -text [::msgcat::mc From] -font $sysFont(sb)
	    grid $wcomm.comm $wcomm.user $wcomm.from \
	      -sticky nws -pady 0
	}
	central {
	    
	    # If this is a client connected to a central server, no 'from' 
	    # connections.
	    label $wcomm.comm -text {  Remote address:} -width 22 -anchor w
	    label $wcomm.user -text {  User:} -width 14 -anchor w
	    label $wcomm.to -text [::msgcat::mc To]
	    label $wcomm.icon -image contact_off
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
    global  prefs sysFont
    
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
    
    set n 1
    entry $wcomm.ad$n -width 16 -relief sunken -bg $prefs(bgColGeneral)
    entry $wcomm.us$n -width 22 -relief sunken -bg white
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
      -text " [::msgcat::mc {Send Live}]" -font $sysFont(sb)} $checkOpts
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
    global  allIPnumsToSend allIPnums allIPnumsTo
    
    upvar ::${wtop}::wapp wapp
    
    Debug 2 "::UI::ConfigureJabberEntry args='$args'"

    set wcomm $wapp(comm)
    set n 1
    
    foreach {key value} $args {
    	switch -- $key {
		-netstate {
		    switch -- $value {
			connect {
			    set allIPnumsTo $ipNum
			    set allIPnumsToSend $ipNum
			    set allIPnums $ipNum
			    ${wcomm}.to${n} configure -state normal
			    
			    # Update "electric plug" icon.
			    after 400 [list ${wcomm}.icon configure -image contact_on]
			}
			disconnect {
			    set allIPnumsTo {}
			    set allIPnumsToSend {}
			    set allIPnums {}
			    ${wcomm}.to${n} configure -state disabled
			    after 400 [list ${wcomm}.icon configure -image contact_off]	    
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
#       It updates all lists of type 'allIPnums...', but doesn't do anything
#       with channels.
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
    global  allIPnumsToSend allIPnums allIPnumsTo allIPnumsFrom prefs
    
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
    
    # Update 'allIPnumsTo' to contain each ip num connected to.
    set ind [lsearch $allIPnumsTo $ipNum]
    if {($ind == -1) && ($commTo($wtop,$ipNum) == 1)} {
	lappend allIPnumsTo $ipNum
    } elseif {($ind >= 0) && ($commTo($wtop,$ipNum) == 0)} {
	set allIPnumsTo [lreplace $allIPnumsTo $ind $ind]
    }
    
    # Update 'allIPnumsFrom' to contain each ip num connected to our server
    # from a remote client.
    set ind [lsearch $allIPnumsFrom $ipNum]
    if {($ind == -1) && ($commFrom($wtop,$ipNum) == 1)} {
	lappend allIPnumsFrom $ipNum
    } elseif {($ind >= 0) && ($commFrom($wtop,$ipNum) == 0)} {
	set allIPnumsFrom [lreplace $allIPnumsFrom $ind $ind]
    }
    
    # Update sending list. 
    if {[string equal $prefs(protocol) "server"]} {
	set allIPnumsToSend $allIPnumsFrom    
    } else {
	set allIPnumsToSend $allIPnumsTo
    }
    
    # Update 'allIPnums' to be the union of 'allIPnumsTo' and 'allIPnumsFrom'.
    # If both to and from 0 then remove from list.
    set allIPnums [lsort -unique [concat $allIPnumsTo $allIPnumsFrom]]
    
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
    Debug 2 "  SetCommEntry (exit):: allIPnums=$allIPnums, \
      allIPnumsToSend=$allIPnumsToSend"
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
    global  sysFont prefs ipNumTo allIPnumsTo
    
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
    
    set size [::UI::ParseWMGeometry $wtopReal]
    set n $nEnt($wtop)
    
    # Add new status line.
    if {[string equal $thisType "jabber"]} {
	entry $wcomm.ad$n -width 18 -relief sunken -bg $prefs(bgColGeneral)
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
	
	# Update "electric plug" icon if first connection.
	if {[llength $allIPnumsTo] == 1} {
	    after 400 [list $wcomm.icon configure -image contact_on]
	}
    } elseif {[string equal $thisType "symmetric"]} {
	entry $wcomm.ad$n -width 24  \
	  -relief sunken -bg $prefs(bgColGeneral)
	entry $wcomm.us$n -width 16   \
	  -textvariable ipNumTo(user,$ipNum) -relief sunken  \
	  -bg $prefs(bgColGeneral)
	checkbutton $wcomm.to$n -variable ${ns}::commTo($wtop,$ipNum)   \
	  -highlightthickness 0 -command [list ::UI::CheckCommTo $wtop $ipNum]
	checkbutton $wcomm.from$n -variable ${ns}::commFrom($wtop,$ipNum)  \
	  -highlightthickness 0 -state disabled
	grid $wcomm.ad$n $wcomm.us$n $wcomm.to$n   \
	  $wcomm.from$n -padx 4 -pady 0
	$wcomm.us$n configure -state disabled
    } elseif {[string equal $thisType "client"]} {
	entry $wcomm.ad$n -width 24   \
	  -relief sunken -bg $prefs(bgColGeneral)
	entry $wcomm.us$n -width 16    \
	  -textvariable ipNumTo(user,$ipNum) -relief sunken  \
	  -bg $prefs(bgColGeneral)
	checkbutton $wcomm.to$n -variable ${ns}::commTo($wtop,$ipNum)   \
	  -highlightthickness 0 -command [list ::UI::CheckCommTo $wtop $ipNum]
	grid $wcomm.ad$n $wcomm.us$n $wcomm.to$n -padx 4 -pady 0
	$wcomm.us$n configure -state disabled
    } elseif {[string equal $thisType "server"]} {
	entry $wcomm.ad$n -width 24   \
	  -relief sunken -bg $prefs(bgColGeneral)
	entry $wcomm.us$n -width 16    \
	  -textvariable ipNumTo(user,$ipNum) -relief sunken  \
	  -bg $prefs(bgColGeneral)
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
	    DoCloseClientConnection $ipNum
	}
    } elseif {$commTo($wtop,$ipNum) == 1} {
	
	# Open connection. Let propagateSizeToClients = true.
	DoConnect $ipNum $ipNumTo(servPort,$ipNum) 1
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
    global  prefs allIPnumsTo
    
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
    if {([string equal $prefs(protocol) "central"] || \
      [string equal $prefs(protocol) "jabber"]) &&   \
      ([llength $allIPnumsTo] == 0)} {
	after 400 [list $wcomm.icon configure -image contact_off]
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
    global  prefs wDlgs allIPnumsToSend
    
    upvar ::${wtop}::wapp wapp
    upvar ::${wtop}::opts opts
    
    switch -exact -- $what {
	connect {
	    
	    # If client only, allow only one connection, limited.
	    switch -- $prefs(protocol) {
		jabber {
		    ::UI::ButtonConfigure $wtop connect -state disabled
		    if {[string equal $opts(-state) "normal"] &&  \
		      [string equal $opts(-sendbuttonstate) "normal"]} {
			::UI::ButtonConfigure $wtop send -state normal
		    }
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mOpenConnection -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mNewAccount -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mLogin  \
		      -label [::msgcat::mc Logout] -command \
		      [list ::Jabber::DoCloseClientConnection $allIPnumsToSend]
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mLogoutWith -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mPassword -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mSearch -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mAddNewUser -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mSendMessage -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mChat -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mStatus -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mvCard -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mEnterRoom -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mExitRoom -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mCreateRoom -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mPassword -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mRemoveAccount -state normal
		}
		symmetric {
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mPutFile -state normal
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mPutCanvas -state normal
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mGetCanvas -state normal
		}
		client {
		    ::UI::ButtonConfigure $wtop connect -state disabled
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mOpenConnection -state disabled
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mPutFile -state normal
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mPutCanvas -state normal
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mGetCanvas -state normal
		}
		server {
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mPutFile -state normal
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mPutCanvas -state normal
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mGetCanvas -state normal
		}
		default {
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mOpenConnection -state disabled
		    ::UI::ButtonConfigure $wtop connect -state disabled
		}
	    }	    
	    ::UI::MenuMethod ${wtop}menu.info entryconfigure mHelpOn -state disabled
	}
	disconnect {
	    
	    switch -- $prefs(protocol) {
		jabber {
		    ::UI::ButtonConfigure $wtop connect -state normal
		    ::UI::ButtonConfigure $wtop send -state disabled
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mOpenConnection -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mNewAccount -state normal
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mLogin  \
		      -label "[::msgcat::mc Login]..." \
		      -command [list ::Jabber::Login::Login $wDlgs(jlogin)]
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mLogoutWith -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mPassword -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mSearch -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mAddNewUser -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mSendMessage -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mChat -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mStatus -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mvCard -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mEnterRoom -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mExitRoom -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mCreateRoom -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mPassword -state disabled
		    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mRemoveAccount -state disabled
		}
		client {
		    ::UI::ButtonConfigure $wtop connect -state normal
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mOpenConnection -state normal
		}
	    }
	    ::UI::MenuMethod ${wtop}menu.info entryconfigure mHelpOn -state normal
	    
	    # If no more connections left, make menus consistent.
	    if {[llength $allIPnumsToSend] == 0} {
		
		# In case we are the client in a centralized network, 
		# make sure ww can make a new connection when closed the old one.
		
		if {[string equal $prefs(protocol) "central"]} {
		    ::UI::MenuMethod ${wtop}menu.file entryconfigure mOpenConnection -state normal
		}
		::UI::MenuMethod ${wtop}menu.file entryconfigure mPutFile -state disabled
		::UI::MenuMethod ${wtop}menu.file entryconfigure mPutCanvas -state disabled
		::UI::MenuMethod ${wtop}menu.file entryconfigure mGetCanvas -state disabled
	    }
	}
	disconnectserver {
	    
	    # If no more connections left, make menus consistent.
	    if {[llength $allIPnumsToSend] == 0} {
		::UI::MenuMethod ${wtop}menu.file entryconfigure mPutFile -state disabled
		::UI::MenuMethod ${wtop}menu.file entryconfigure mPutCanvas -state disabled
		::UI::MenuMethod ${wtop}menu.file entryconfigure mGetCanvas -state disabled
	    }
	}
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
    
    set wtop [::UI::GetToplevelNS $w]
    set wClass [winfo class $w]
    set wToplevel [winfo toplevel $w]
    set wToplevelClass [winfo class $wToplevel]
    
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
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mCopy -state disabled
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mInspectItem -state disabled
	    } else {		
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mCut -state disabled
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mCopy -state disabled
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mInspectItem -state disabled
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mRaise -state disabled
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mLower -state disabled
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mLarger -state disabled
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mSmaller -state disabled
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mFlip -state disabled
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mImageLarger -state disabled
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mImageSmaller -state disabled
	    }
	} else {
	    if {$isDisabled} {
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mCopy -state normal
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mInspectItem -state normal
	    } else {		
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mCut -state normal
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mCopy -state normal
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mInspectItem -state normal
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mRaise -state normal
		::UI::MenuMethod ${wtop}menu.edit entryconfigure mLower -state normal
		if {$anyNotImageSel} {
		    ::UI::MenuMethod ${wtop}menu.edit entryconfigure mLarger -state normal
		    ::UI::MenuMethod ${wtop}menu.edit entryconfigure mSmaller -state normal
		}
		if {$anyImageSel} {
		    ::UI::MenuMethod ${wtop}menu.edit entryconfigure mImageLarger -state normal
		    ::UI::MenuMethod ${wtop}menu.edit entryconfigure mImageSmaller -state normal
		}
		if {$allowFlip} {
		    # Seems to be buggy on mac...
		    ::UI::MenuMethod ${wtop}menu.edit entryconfigure mFlip -state normal
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
	    ::UI::MenuMethod ${wtop}menu.edit entryconfigure mCut -state $setState
	    ::UI::MenuMethod ${wtop}menu.edit entryconfigure mCopy -state $setState
	    ::UI::MenuMethod ${wtop}menu.edit entryconfigure mPaste -state $haveClipState
	}
	
	# Special on the mac. Remove when multiinstance!!!
	# One menu for all...
	if {[string match mac* $this(platform)]} {
	    ::UI::MenuMethod .menu.edit entryconfigure mCut -state $setState
	    ::UI::MenuMethod .menu.edit entryconfigure mCopy -state $setState
	    ::UI::MenuMethod .menu.edit entryconfigure mPaste -state $haveClipState
	}
	
	# If we have a cut/copy/paste row of buttons need to set their state.
	::UI::CutCopyPasteCheckState $setState $haveClipState
    } 
}

proc ::UI::IsCanvasDrawCmd {cmd} {


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

    set wtop [::UI::GetToplevelNS $w]
    upvar ::${wtop}::opts opts

    if {$opts(-state) == "normal"} {
	::UI::MenuMethod ${wtop}menu.edit entryconfigure mPaste -state normal
    } else {
	::UI::MenuMethod ${wtop}menu.edit entryconfigure mPaste -state disabled
    }
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
    global  allIPnumsToSend fontSize2Points fontPoints2Size

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
#       
# Results:
#       none

proc ::UI::StartStopAnimatedWave {w start} {
    variable  animateWave
    
    # Define speed and update frequency. Pix per sec and times per sec.
    set speed 150
    set freq 16

    if {$start} {
	
	# Check if not already started.
	if {[info exists animateWave]} {
	    return
	}
	set animateWave(pix) [expr int($speed/$freq)]
	set animateWave(wait) [expr int(1000.0/$freq)]
	set animateWave(id) [$w create image 0 0 -anchor nw -image im_wave]
	$w lower $animateWave(id)
	set animateWave(x) 0
	set animateWave(dir) 1
	set animateWave(killId)   \
	  [after $animateWave(wait) [list ::UI::AnimateWave $w]]
    } elseif {[info exists animateWave(killId)]} {
	after cancel $animateWave(killId)
	$w delete $animateWave(id)
	catch {unset animateWave}
    }
}

proc ::UI::StartStopAnimatedWaveOnMain {start} {
    
    upvar ::.::wapp wapp
    
    ::UI::StartStopAnimatedWave $wapp(statmess) $start
}

proc ::UI::AnimateWave {w} {

    variable  dims 
    variable animateWave
    
    set deltax [expr $animateWave(dir) * $animateWave(pix)]
    incr animateWave(x) $deltax
    if {$animateWave(x) > [expr $dims(wStatMess) - 80]} {
	set animateWave(dir) -1
    } elseif {$animateWave(x) <= -60} {
	set animateWave(dir) 1
    }
    $w move $animateWave(id) $deltax 0
    set animateWave(killId)   \
      [after $animateWave(wait) [list ::UI::AnimateWave $w]]
}

#-------------------------------------------------------------------------------

