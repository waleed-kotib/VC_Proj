#  Jabber.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the "glue" between the whiteboard and jabberlib.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: Jabber.tcl,v 1.60 2004-01-26 07:34:49 matben Exp $

package provide Jabber 1.0

package require tree
package require jlib
package require roster
package require browse
package require http 2.3
package require balloonhelp
package require combobox
package require tinyfileutils
package require uriencode
package require MailBox
package require NewMsg
package require GotMsg
package require OOB
package require Chat
package require Agents
package require Browse
package require Roster
package require GroupChat
package require MUC
package require Login
package require JUI
package require Register
package require Subscribe
package require Conference
package require Search
package require JForms
package require Profiles


namespace eval ::Jabber:: {
    global  this prefs
    
    # Add all event hooks.
    hooks::add loginHook      ::Jabber::SetPrivateData
    hooks::add quitAppHook    ::Jabber::EndSession

    # Jabber internal storage.
    variable jstate
    variable jprefs
    variable jserver
    variable jerror
        
    set jstate(debug) 0
    if {($::debugLevel > 1) && ($jstate(debug) == 0)} {
	set jstate(debug) $::debugLevel
    }
    
    # The trees 'directories' which should always be there.
    set jprefs(treedirs) {Online Offline {Subscription Pending}}
    set jprefs(closedtreedirs) {}
    
    # Our own jid, and jid/resource respectively.
    set jstate(mejid) ""
    set jstate(mejidres) ""
    
    #set jstate(alljid) {}   not implemented yet...
    set jstate(sock) {}
    set jstate(ipNum) {}
    set jstate(inroster) 0
    set jstate(status) "unavailable"
    
    # Server port actually used.
    set jstate(servPort) {}

    # Login server.
    set jserver(this) ""

    # Regexp pattern for username etc. Ascii no. 0-32 (deci) not allowed.
    set jprefs(invalsExp) {.*([\x00-\x20]|[\r\n\t@:' <>&"/])+.*}
    set jprefs(valids) {[^\x00-\x20]|[^\r\n\t@:' <>&"]}
    
    # List all iq:register personal info elements.
    set jprefs(iqRegisterElem)   \
      {first last nick email address city state phone url}
    
    # Popup menus.
    set jstate(wpopup,roster) .jpopupro
    set jstate(wpopup,browse) .jpopupbr
    set jstate(wpopup,groupchat) .jpopupgc
    set jstate(wpopup,agents) .jpopupag
    
    # Keep noncritical error text here.
    set jerror {}
    
    # Get/put ip numbers.
    variable getid 1001
    # Records any callback procs, index from 'getid'.
    variable getcmd
    
    # Array that maps 'jid' to its ip number.
    variable jidToIP
    
    # Array that acts as a data base for the public storage on the server.
    # Typically: jidPublic(matben@athlon.se,home,serverport).
    # Not used for the moment.
    variable jidPublic
    set jidPublic(haveit) 0
    
    # Mappings from <show> element to displayable text and vice versa.
    # chat away xa dnd
    variable mapShowElemToText
    variable mapShowTextToElem
    
    array set mapShowElemToText  \
      [list [::msgcat::mc mAvailable] available  \
      [::msgcat::mc mAway]            away       \
      [::msgcat::mc mChat]            chat       \
      [::msgcat::mc mDoNotDisturb]    dnd        \
      [::msgcat::mc mExtendedAway]    xa         \
      [::msgcat::mc mInvisible]       invisible  \
      [::msgcat::mc mNotAvailable]    unavailable]
    array set mapShowTextToElem  \
      [list available [::msgcat::mc mAvailable]     \
      away            [::msgcat::mc mAway]          \
      chat            [::msgcat::mc mChat]          \
      dnd             [::msgcat::mc mDoNotDisturb]  \
      xa              [::msgcat::mc mExtendedAway]  \
      invisible       [::msgcat::mc mInvisible]     \
      unavailable     [::msgcat::mc mNotAvailable]]
        
    # Array that maps namespace (ns) to a descriptive name.
    variable nsToText
    array set nsToText {
      jabber:iq:agent              {Server component properties}
      jabber:iq:agents             {Server component properties}
      jabber:iq:auth               {Client authentization}      
      jabber:iq:autoupdate         {Release information}
      jabber:iq:browse             {Browsing services}
      jabber:iq:conference         {Conferencing service}
      jabber:iq:gateway            {Gateway}
      jabber:iq:last               {Last time}
      jabber:iq:oob                {Out of band data}
      jabber:iq:private            {Store private data}
      jabber:iq:register           {Interactive registration}
      jabber:iq:roster             {Roster management}
      jabber:iq:search             {Searching user database}
      jabber:iq:time               {Client time}
      jabber:iq:version            {Client version}
      jabber:x:autoupdate          {Client update notification}
      jabber:x:conference          {Conference invitation}
      jabber:x:delay               {Object delayed}
      jabber:x:encrypted           {Encrypted message}
      jabber:x:envelope            {Message envelope}
      jabber:x:event               {Message events}
      jabber:x:expire              {Message expiration}
      jabber:x:oob                 {Out of band attachment}
      jabber:x:roster              {Roster item in message}
      jabber:x:signed              {Signed presence}
      vcard-temp                   {Business card exchange}
      http://jabber.org/protocol/muc   {Multi user chat}
      http://jabber.org/protocol/disco {Feature discovery}
    }    
    
    # XML namespaces defined here.
    variable privatexmlns
    array set privatexmlns {
	servers         http://coccinella.sourceforge.net/protocols/servers
	whiteboard      http://coccinella.sourceforge.net/protocols/whiteboard
	public          http://coccinella.sourceforge.net/protocols/private
    }
  
    # Short error names.
    variable errorCodeToShort
    array set errorCodeToShort {
      301 {Moved Permanently}
      307 {Moved Temporarily}
      400 {Bad Request}
      401 {Unauthorized}
      404 {Not Found}
      405 {Not Allowed}
      406 {Not Acceptable}
      407 {Registration Required}
      408 {Request Timeout}
    }
    
    # Jabber specific mappings from three digit error code to text.
    variable errorCodeToText
    array set errorCodeToText {\
      conf_pres,301           {The room has changed names}     \
      conf_pres,307           {This room has changed location temporarily}  \
      conf_pres,401           {An authentization step is needed at the service\
      level before you can communicate with this room}      \
      conf_pres,403           {You are being denied access to rooms at the\
      service level}     \
      conf_pres,404           {The server only allows predefined rooms, and\
      the room specified does not exist}    \
      conf_pres,405           {You are being denied access to this specific\
      room, due to being on a ban list}\
      conf_pres,407           {A registration step is needed at the service\
      level before you can communicate with this room}     \
      conf_create,301         {The server has changed addresses}   \
      conf_create,307         {This server has changed location temporarily} \
      conf_create,401         {An authorization step is needed with this\
      service before interactions can occur with it}    \
      conf_create,403         {You are not allowed to interact with this\
      service}    \
      conf_create,407         {Registration with the service is required for\
      all interactions}   \
      conf_message,400        {The message was malformed in some manner,\
      such as sending a message that was of not of type "groupchat" to a room} \
      conf_message,401        {The user is not authorized to speak in this\
      room. This may be because the user does not have voice within the room}
      conf_message,404        {The client is sending a message to a room\
	which does not exist}    \
      conf_message,406        {Additional data was forwarded through the room\
      which the room is not configured to handle}    \
      conf_message,407        {The user is not a participant within the room,\
      and the room does not allow non-participant to speak within the room}  \
      conf_message,408        {The message timed out while being sent,\
      the user may resend}   \
      conf_message_dir,400    {The message was malformed, for instance,\
      it may have had type "groupchat"}   \
      conf_message_dir,401    {The user is not authorized to send directed\
      messages in this room}   \
      conf_message_dir,404    {The user could not be found within the room,\
      or the room does not exist}  \
      conf_message_dir,405    {The conferencing service does not support\
      directed messages}   \
      conf_message_dir,406    {A required extension is stopping this message}  \
      conf_message_dir,407    {The client is required to be in the room in\
      order to send a message to its participants}   \
      conf_message_dir,408    {The message timed out while being sent,\
      the user may resend}  \
    }
  
    variable killerId 
}

proc ::Jabber::Debug {num str} {
    variable jstate
    if {$num <= $jstate(debug)} {
	puts $str
    }
}

# Jabber::FactoryDefaults --
#
#       Makes reasonable default settings for a number of variables and
#       preferences.

proc ::Jabber::FactoryDefaults { } {
    global  this env prefs wDlgs sysFont

    variable jstate
    variable jprefs
    variable jserver
    
    # Network.
    set jprefs(port) 5222
    set jprefs(sslport) 5223
    set jprefs(usessl) 0
    
    # Other
    set jprefs(defSubscribe)        1
    set jprefs(rost,rmIfUnsub)      1
    set jprefs(rost,allowSubNone)   1
    set jprefs(rost,clrLogout)      1
    set jprefs(rost,dblClk)         normal
    
    # The rosters background image is partly controlled by option database.
    set jprefs(rost,useBgImage)     1
    set jprefs(rost,bgImagePath)    ""
    set jprefs(subsc,inrost)        ask
    set jprefs(subsc,notinrost)     ask
    set jprefs(subsc,auto)          0
    set jprefs(subsc,group)         {}
    set jprefs(block,notinrost)     0
    set jprefs(block,list)          {}
    
    # Shall we query ip number directly when verified Coccinella?
    set jprefs(preGetIP) 1
	
    # Preferred groupchat protocol (gc-1.0|muc).
    # 'muc' uses 'conference' as fallback.
    set jprefs(prefgchatproto) "muc"
    
    # Automatically browse users with resource?
    set jprefs(autoBrowseUsers) 1
    
    # Show special icons for foreign IM systems?
    set jprefs(haveIMsysIcons) 0
    
    # Dialog pane positions.
    set prefs(paneGeom,$wDlgs(jchat)) {0.75 0.25}
    set prefs(paneGeom,$wDlgs(jinbox)) {0.5 0.5}
    set prefs(paneGeom,groupchatDlgVert) {0.8 0.2}
    set prefs(paneGeom,groupchatDlgHori) {0.8 0.2}
    
    # Autoupdate; be sure to use version key since a new version must not inherit.
    # Abondened!!!!!!!
    set jprefs(autoupdateCheck) 0
    set jprefs(autoupdateShow,$prefs(fullVers)) 1
        
    # Sounds.
    set jprefs(snd,online) 1
    set jprefs(snd,offline) 1
    set jprefs(snd,newmsg) 1
    set jprefs(snd,statchange) 1
    set jprefs(snd,connected) 1

    set jprefs(showMsgNewWin) 1
    set jprefs(inbox2click) "newwin"
    
    # Save inbox when quit?
    set jprefs(inboxSave) 0
    
    set jprefs(autoaway) 0
    set jprefs(xautoaway) 0
    set jprefs(awaymin) 0
    set jprefs(xawaymin) 0
    set jprefs(awaymsg) {}
    set jprefs(xawaymsg) {User has been inactive for a while}
    
    set jprefs(logoutStatus) ""
    
    # Empty here means use option database.
    set jprefs(chatFont) ""
    set jprefs(useXDataSearch) 1
    
    # Service discovery method: "agents" or "browse"
    set jprefs(agentsOrBrowse) "browse"
    
    set jstate(rosterVis) 1
    set jstate(browseVis) 0
    set jstate(rostBrowseVis) 1
    set jstate(debugCmd) 0
    
    # Personal info corresponding to the iq:register namespace.
    foreach key $jprefs(iqRegisterElem) {
	set jprefs(iq:register,$key) {}
    }
    
    # Query these jabber servers for services. Login server is automatically
    # queried.
    set jprefs(browseServers) {}
    set jprefs(agentsServers) {}
    
    # The User Info of servers.    
    set jserver(this) ""

    # New... Profiles. These are just leftovers that shall be removed later.
    set jserver(profile)  \
      {jabber.org {jabber.org myUsername myPassword home}}
    set jserver(profile,selected)  \
      [lindex $jserver(profile) 0]
    
    #
    set jprefs(urlServersList) "http://www.jabber.org/servers.php"
        
    switch $this(platform) {
	macintosh - macosx {
	    set jprefs(inboxPath) [file join $this(prefsPath) Inbox.tcl]
	}
	windows {
	    set jprefs(inboxPath) [file join $this(prefsPath) Inbox.tcl]
	}
	unix {
	    set jprefs(inboxPath) [file join $this(prefsPath) inbox.tcl]
	}
    }
    
    # Menu definitions for the Roster/services window. Collects minimal Jabber
    # stuff.
    variable menuDefs
    
    set menuDefs(min,edit) {    
	{command   mCut              {::UI::CutCopyPasteCmd cut}           disabled X}
	{command   mCopy             {::UI::CutCopyPasteCmd copy}          disabled C}
	{command   mPaste            {::UI::CutCopyPasteCmd paste}         disabled V}
    }
      
    # Templates for popup menus for the roster, browse, and groupchat windows.
    # The roster:
    variable popMenuDefs

    set popMenuDefs(roster,def) {
      mMessage       users     {::Jabber::NewMsg::Build -to &jid}
      mChat          user      {::Jabber::Chat::StartThread &jid3}
      mWhiteboard    wb        {::Jabber::WB::NewWhiteboard &jid3}
      separator      {}        {}
      mLastLogin/Activity user {::Jabber::GetLast &jid}
      mvCard         user      {::VCard::Fetch other &jid}
      mAddNewUser    any       {
	  ::Jabber::Roster::NewOrEditItem new
      }
      mEditUser      user      {
	  ::Jabber::Roster::NewOrEditItem edit -jid &jid
      }
      mVersion       user      {::Jabber::GetVersion &jid3}
      mChatHistory   user      {::Jabber::Chat::BuildHistory &jid}
      mRemoveUser    user      {::Jabber::Roster::SendRemove &jid}
      separator      {}        {}
      mStatus        any       @::Jabber::Roster::BuildPresenceMenu
      mRefreshRoster any       {::Jabber::Roster::Refresh}
    }  
      
    # Can't run our http server on macs :-(
    if {![string equal $this(platform) "macintosh"]} {
	set popMenuDefs(roster,def) [linsert $popMenuDefs(roster,def) 9  \
	  mSendFile     user      {::Jabber::OOB::BuildSet &jid}]
    }
    
    # The browse:
    set popMenuDefs(browse,def) {
      mMessage       user      {::Jabber::NewMsg::Build -to &jid}
      mChat          user      {::Jabber::Chat::StartThread &jid}
      mWhiteboard    wb        {::Jabber::WB::NewWhiteboard &jid}
      mEnterRoom     room      {
	  ::Jabber::GroupChat::EnterOrCreate enter -roomjid &jid -autoget 1
      }
      mCreateRoom    conference {::Jabber::GroupChat::EnterOrCreate create}
      separator      {}        {}
      mInfo          jid       {::Jabber::Browse::GetInfo &jid}
      mLastLogin/Activity jid  {::Jabber::GetLast &jid}
      mLocalTime     jid       {::Jabber::GetTime &jid}
      mvCard         jid       {::VCard::Fetch other &jid}
      mVersion       jid       {::Jabber::GetVersion &jid}
      separator      {}        {}
      mSearch        search    {
	  ::Jabber::Search::Build -server &jid -autoget 1
      }
      mRegister      register  {
	  ::Jabber::GenRegister::BuildRegister -server &jid -autoget 1
      }
      mUnregister    register  {::Jabber::Register::Remove &jid}
      separator      {}        {}
      mRefresh       jid       {::Jabber::Browse::Refresh &jid}
      mAddServer     any       {::Jabber::Browse::AddServer}
    }
    
    # The groupchat:
    set popMenuDefs(groupchat,def) {
      mMessage       user      {::Jabber::NewMsg::Build -to &jid}
      mChat          user      {::Jabber::Chat::StartThread &jid}
      mWhiteboard    wb        {::Jabber::WB::NewWhiteboard &jid}
    }    
    
    # The agents stuff:
    set popMenuDefs(agents,def) {
      mSearch        search    {
	  ::Jabber::Search::Build -server &jid -autoget 1
      }
      mRegister      register  {
	  ::Jabber::GenRegister::BuildRegister -server &jid -autoget 1
      }
      mUnregister    register  {::Jabber::Register::Remove &jid}
      separator      {}        {}
      mEnterRoom     groupchat {::Jabber::GroupChat::EnterOrCreate enter}
      mLastLogin/Activity jid  {::Jabber::GetLast &jid}
      mLocalTime     jid       {::Jabber::GetTime &jid}
      mVersion       jid       {::Jabber::GetVersion &jid}
   }    
}

# Jabber::SetUserPreferences --
# 
#       Set defaults in the option database for widget classes.
#       First, on all platforms...
#       Set the user preferences from the preferences file if they are there,
#       else take the hardcoded defaults.
#       'thePrefs': a list of lists where each sublist defines an item in the
#       following way:  {theVarName itsResourceName itsHardCodedDefaultValue
#                 {thePriority 20}}.

proc ::Jabber::SetUserPreferences { } {
    
    variable jstate
    variable jprefs
    variable jserver
    
    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(port)             jprefs_port              $jprefs(port)]  \
      [list ::Jabber::jprefs(sslport)          jprefs_sslport           $jprefs(sslport)]  \
      [list ::Jabber::jprefs(rost,clrLogout)   jprefs_rost_clrRostWhenOut $jprefs(rost,clrLogout)]  \
      [list ::Jabber::jprefs(rost,dblClk)      jprefs_rost_dblClk       $jprefs(rost,dblClk)]  \
      [list ::Jabber::jprefs(rost,rmIfUnsub)   jprefs_rost_rmIfUnsub    $jprefs(rost,rmIfUnsub)]  \
      [list ::Jabber::jprefs(rost,allowSubNone) jprefs_rost_allowSubNone $jprefs(rost,allowSubNone)]  \
      [list ::Jabber::jprefs(rost,useBgImage)  jprefs_rost_useBgImage   $jprefs(rost,useBgImage)]  \
      [list ::Jabber::jprefs(rost,bgImagePath) jprefs_rost_bgImagePath  $jprefs(rost,bgImagePath)]  \
      [list ::Jabber::jprefs(subsc,inrost)     jprefs_subsc_inrost      $jprefs(subsc,inrost)]  \
      [list ::Jabber::jprefs(subsc,notinrost)  jprefs_subsc_notinrost   $jprefs(subsc,notinrost)]  \
      [list ::Jabber::jprefs(subsc,auto)       jprefs_subsc_auto        $jprefs(subsc,auto)]  \
      [list ::Jabber::jprefs(subsc,group)      jprefs_subsc_group       $jprefs(subsc,group)]  \
      [list ::Jabber::jprefs(block,notinrost)  jprefs_block_notinrost   $jprefs(block,notinrost)]  \
      [list ::Jabber::jprefs(block,list)       jprefs_block_list        $jprefs(block,list)    userDefault] \
      [list ::Jabber::jprefs(agentsOrBrowse)   jprefs_agentsOrBrowse    $jprefs(agentsOrBrowse)]  \
      [list ::Jabber::jprefs(agentsServers)    jprefs_agentsServers     $jprefs(agentsServers)]  \
      [list ::Jabber::jprefs(browseServers)    jprefs_browseServers     $jprefs(browseServers)]  \
      [list ::Jabber::jprefs(showMsgNewWin)    jprefs_showMsgNewWin     $jprefs(showMsgNewWin)]  \
      [list ::Jabber::jprefs(inbox2click)      jprefs_inbox2click       $jprefs(inbox2click)]  \
      [list ::Jabber::jprefs(inboxSave)        jprefs_inboxSave         $jprefs(inboxSave)]  \
      [list ::Jabber::jprefs(prefgchatproto)   jprefs_prefgchatproto    $jprefs(prefgchatproto)]  \
      [list ::Jabber::jprefs(autoaway)         jprefs_autoaway          $jprefs(autoaway)]  \
      [list ::Jabber::jprefs(xautoaway)        jprefs_xautoaway         $jprefs(xautoaway)]  \
      [list ::Jabber::jprefs(awaymin)          jprefs_awaymin           $jprefs(awaymin)]  \
      [list ::Jabber::jprefs(xawaymin)         jprefs_xawaymin          $jprefs(xawaymin)]  \
      [list ::Jabber::jprefs(awaymsg)          jprefs_awaymsg           $jprefs(awaymsg)]  \
      [list ::Jabber::jprefs(xawaymsg)         jprefs_xawaymsg          $jprefs(xawaymsg)]  \
      [list ::Jabber::jprefs(logoutStatus)     jprefs_logoutStatus      $jprefs(logoutStatus)]  \
      [list ::Jabber::jprefs(chatFont)         jprefs_chatFont          $jprefs(chatFont)]  \
      [list ::Jabber::jprefs(haveIMsysIcons)   jprefs_haveIMsysIcons    $jprefs(haveIMsysIcons)]  \
      [list ::Jabber::jserver(profile)         jserver_profile          $jserver(profile)      userDefault] \
      [list ::Jabber::jserver(profile,selected) jserver_profile_selected $jserver(profile,selected) userDefault] \
      ]
    
	# Personal info corresponding to the iq:register namespace.
	
	set jprefsRegList {}
	foreach key $jprefs(iqRegisterElem) {
	    lappend jprefsRegList [list  \
	      ::Jabber::jprefs(iq:register,$key) jprefs_iq_register_$key   \
	      $jprefs(iq:register,$key) userDefault]
	}
	::PreferencesUtils::Add $jprefsRegList
	if {$jprefs(chatFont) != ""} {
	    set jprefs(chatFont) [::Utils::GetFontListFromName $jprefs(chatFont)]
	}
}

# Jabber::GetjprefsArray, GetjserverArray, ... --
# 
#       Accesor functions for various preference arrays.

proc ::Jabber::GetjprefsArray { } {
    variable jprefs
    
    return [array get jprefs]
}

proc ::Jabber::GetjserverArray { } {
    variable jserver
    
    return [array get jserver]
}

proc ::Jabber::SetjprefsArray {jprefsArrList} {
    variable jprefs
    
    array set jprefs $jprefsArrList
}

proc ::Jabber::GetIQRegisterElements { } {
    variable jprefs

    return $jprefs(iqRegisterElem)
}

proc ::Jabber::GetServerJid { } {
    variable jserver

    return $jserver(this)
}

proc ::Jabber::GetServerIpNum { } {
    variable jstate
    
    return $jstate(ipNum)
}

proc ::Jabber::GetMyJid {{roomjid {}}} {
    variable jstate

    set jid ""
    if {$roomjid == ""} {
	set jid $jstate(mejidres)
    } else {
	if {[$jstate(jlib) service isroom $roomjid]} {
	    set hashandnick [$jstate(jlib) service hashandnick $roomjid]
	    set jid [lindex $hashandnick 0]   
	}
    }
    return $jid
}

proc ::Jabber::InvokeJlibCmd {args} {
    variable jstate
    
    eval {$jstate(jlib)} $args
}

proc ::Jabber::IsConnected { } {
    variable jserver

    return [expr [string length $jserver(this)] == 0 ? 0 : 1]
}

# Jabber::InvokeRosterCmd, InvokeBrowseCmd --
# 
#       Access functions for invoking these commands from the outside.

proc ::Jabber::InvokeRosterCmd {args}  {
    variable jstate
    
    eval {$jstate(roster)} $args
}

proc ::Jabber::InvokeBrowseCmd {args}  {
    variable jstate
    
    eval {$jstate(browse)} $args
}

# Generic ::Jabber:: stuff -----------------------------------------------------

# Jabber::InitWhiteboard --
#
#       Initialize jabber things for this specific whiteboard instance.

proc ::Jabber::InitWhiteboard {wtop} {
    variable jstate
    
    set jstate($wtop,doSend) 0
    # The current receiver of our messages. 'textvariable' in UI entry.
    set jstate($wtop,tojid) ""
    # Identical to 'tojid' for standard chats, but a list of jid's
    # with /nick for groupchat's.
}

# Jabber::Init --
#
#       Make all the necessary initializations, create roster object,
#       jlib object etc.
#       
# Arguments:
#       
# Results:
#       none.

proc ::Jabber::Init { } {
    global  wDlgs prefs
    
    variable jstate
    variable jprefs
    variable privatexmlns
    
    # Make the roster object.
    set jstate(roster) [::roster::roster ::Jabber::Roster::PushProc]
    
    # Make the browse object.
    set jstate(browse) [::browse::browse ::Jabber::Browse::Callback]
    
    # Check if we need to set any auto away options.
    set opts {}
    if {$jprefs(autoaway) || $jprefs(xautoaway)} {
	foreach name {autoaway xautoaway awaymin xawaymin awaymsg xawaymsg} {
	    lappend opts -$name $jprefs($name)
	}
    }
    
    # Add the three element callbacks.
    lappend opts  \
      -iqcommand       ::Jabber::IqCallback       \
      -messagecommand  ::Jabber::MessageCallback  \
      -presencecommand ::Jabber::PresenceCallback

    # Make an instance of jabberlib and fill in our roster object.
    set jstate(jlib) [eval {
	::jlib::new $jstate(roster) ::Jabber::ClientProc  \
	  -browsename $jstate(browse)} $opts]

    # Register handlers for various iq elements.
    $jstate(jlib) iq_register get jabber:iq:version ::Jabber::ParseGetVersion
    $jstate(jlib) iq_register get jabber:iq:browse  ::Jabber::ParseGetBrowse
    $jstate(jlib) iq_register get $privatexmlns(servers) ::Jabber::ParseGetServers
    $jstate(jlib) iq_register set jabber:iq:oob     ::Jabber::OOB::ParseSet
    
    # Set the priority order of groupchat protocols.
    $jstate(jlib) setgroupchatpriority [list $jprefs(prefgchatproto) "gc-1.0"]
      
    if {[string equal $prefs(protocol) "jabber"]} {
	
	# Make the combined window.
	if {1 || $jstate(rostBrowseVis)} {
	    ::Jabber::UI::Show $wDlgs(jrostbro)
	} else {
	    ::Jabber::UI::Build $wDlgs(jrostbro)
	    wm withdraw $wDlgs(jrostbro)
	}
    }
}

# ::Jabber::IqCallback --
#
#       Registered callback proc for <iq> elements. Most handled elsewhere,
#       in roster, browser and registered callbacks.
#       
# Results:
#       boolean (0/1) telling if this was handled or not. Only for 'get'.

proc ::Jabber::IqCallback {jlibName type args} {
    variable jstate
    variable jprefs
    
    ::Jabber::Debug 2 "::Jabber::IqCallback type=$type, args='$args'"
    
    array set attrArr $args
    set xmlns [wrapper::getattribute $attrArr(-query) xmlns]
    set stat 0
    
    return $stat
}

# ::Jabber::MessageCallback --
#
#       Registered callback proc for <message> elements.
#       
# Arguments:
#       type        normal|chat|groupchat
#       args        ?-key value ...?
#       
# Results:
#       none.

proc ::Jabber::MessageCallback {jlibName type args} {    
    variable jstate
    variable jprefs
    variable privatexmlns
    
    ::Jabber::Debug 2 "::Jabber::MessageCallback type=$type, args='$args'"
    
    array set attrArr {-body ""}
    array set attrArr $args
    
    set from $attrArr(-from)
    
    # Check if any blockers.
    if {$jprefs(block,notinrost) && ($type == "normal")} {
	
	# Reject if not in roster.
	set allUsers [$jstate(roster) getusers]
	if {[lsearch -exact $allUsers $from] < 0} {
	    puts "Rejected message from: $from"
	    return
	}
    }
    if {[llength $jprefs(block,list)] > 0} {
	foreach blkjid $jprefs(block,list) {
	    if {[string match $blkjid $from]} {
		puts "Rejected message from: $from"
		return
	    }
	}
    }
    
    # We must check if there is an error element sent along with the
    # body element. In that case the body element shall not be processed.
    if {[string equal $type "error"] && [info exists attrArr(-error)]} {
	set errcode [lindex $attrArr(-error) 0]
	set errmsg [lindex $attrArr(-error) 1]
	
	tk_messageBox -title [::msgcat::mc Error] -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrsend $attrArr(-from) $errcode $errmsg]]  \
	  -icon error -type ok		
    } else {
	
	# Check if we've got an <x xmlns='coccinella:wb'><raw> element...
	# New: uri based namespace.
	set haveCoccinellaNS 0
	set rawElemList {}
	if {[info exists attrArr(-x)]} {
	    foreach xlist $attrArr(-x) {
		
		# Take each <x> element in turn.
		foreach {xtag xattrlist xempty xchdata xsub} $xlist break
		array set xattrArr $xattrlist
		if {![info exists xattrArr(xmlns)]} {
		    continue
		}
		switch -- $xattrArr(xmlns) {
		    "coccinella:wb" - $privatexmlns(whiteboard) {
			set haveCoccinellaNS 1
			foreach xsubtag $xsub {
			    if {[string equal [lindex $xsubtag 0] "raw"]} {
				lappend rawElemList [lindex $xsubtag 3]
			    }
			}
		    }
		    "jabber:x:conference" {
			
			# Invitation for the conference (undocumented).
		    }
		    "http://jabber.org/protocol/muc#user" {
			::Jabber::MUC::MUCMessage $from $xlist
		    }
		}
	    }
	}
		
	# If a room message sent from us we don't want to duplicate it.
	# Whiteboard only.
	set doShow 1
	if {$haveCoccinellaNS} {
	    if {[string equal $type "groupchat"]} {
		if {[regexp {^(.+@[^/]+)(/(.*))?} $attrArr(-from) match roomJid x]} {
		    foreach {meHash nick}  \
		      [$jstate(jlib) service hashandnick $roomJid] break
		    if {[string equal $meHash $attrArr(-from)]} {
			set doShow 0
		    }
		}
	    }
	}
	
	# Send message to dispatcher for 'type' and whiteboard.
	set msgArgs $args
	if {$doShow && $haveCoccinellaNS} {
	    lappend msgArgs -whiteboard $rawElemList
	}
	
	# Interpret this as an ordinary jabber message element.
	eval {::Jabber::MessageDispatcher $type $attrArr(-body)} $msgArgs    
    }
}

# ::Jabber::MessageDispatcher --
#
#       Dispatch a jabber message to either the "normal" dialog, chat window,
#       or groupchat window.
#       
# Arguments:
#       type        message type attribute
#       body        the <body> element. Empty if have -whiteboard.
#       args        -type, -from, -whiteboard, -x, -thread
#       
# Results:
#       dispatch procedure called.

proc ::Jabber::MessageDispatcher {type body args} {
    
    set iswb 0
    if {[lsearch -exact $args "-whiteboard"] >= 0} {
	set iswb 1
    }
    
    switch -- $type {
	chat {
	    if {$iswb} {
		eval {::Jabber::WB::ChatMsg} $args
		eval {::hooks::run newWBChatMessageHook} $args
	    } else {
		eval {::hooks::run newChatMessageHook $body} $args
	    }	    
	}
	groupchat {
	    if {$iswb} {
		eval {::Jabber::WB::GroupChatMsg} $args
		eval {::hooks::run newWBGroupChatMessageHook} $args
	    } else {
		eval {::hooks::run newGroupChatMessageHook $body} $args
	    }	    
	}
	default {
	
	    # Normal message. Handles whiteboard stuff as well.
	    eval {::Jabber::DispatchNormalMessage $body $iswb} $args
	}
    }
}

# ::Jabber::DispatchNormalMessage --
# 
#       Take care of commands that must be responded to, and forward rest
#       to inbox.

proc ::Jabber::DispatchNormalMessage {body iswb args} {
    variable  jstate
    
    # We need to split up whiteboard commands (messages) that must be
    # handled immediately and those destined for drawing etc. 
    # 
    # This should be removed when it runs through <iq> query!
    if {$iswb} {
	array set argsArr $args
	set restCmds {}
	foreach raw $argsArr(-whiteboard) {
	    
	    switch -glob -- $raw {
		"GET IP:*" {
		    if {[regexp {^GET IP: +([^ ]+)$} $raw m id]} {
			::Jabber::PutIPnumber $argsArr(-from) $id
		    }
		}
		"PUT IP:*" {
			
		    # We have got the requested ip number from the client.
		    if {[regexp {^PUT IP: +([^ ]+) +([^ ]+)$} $raw m id ip]} {
			::Jabber::GetIPCallback $argsArr(-from) $id $ip
		    }		
		}	
		"IDENTITY:*" - "IPS CONNECTED:*" - "CLIENT:*" -  \
		  "DISCONNECTED:*" - "RESIZE:*" {
		    
		    # Junk.
		}
		default {
		    lappend restCmds $raw
		}
	    }
	}
	if {[llength $restCmds] > 0} {
	    set argsArr(-whiteboard) $restCmds
	    eval {::hooks::run newMessageHook $body} [array get argsArr]
	}
    } else {
	eval {::hooks::run newMessageHook $body} $args
    }
}

# ::Jabber::PresenceCallback --
#
#       Registered callback proc for <presence> elements.
#       
# Arguments:
#       jlibName    Name of jabberlib instance.
#       type        the type attribute of the presence element
#       args        Is a list of '-key value' pairs.
#       
# Results:
#       none.

proc ::Jabber::PresenceCallback {jlibName type args} {
    global  wDlgs prefs
    
    variable jstate
    variable jprefs
    variable jerror
    
    ::Jabber::Debug 2 "::Jabber::PresenceCallback type=$type, args='$args'"
    
    array set attrArr $args
    set from $attrArr(-from)
    
    switch -- $type {
	subscribe {
	    
	    jlib::splitjid $from jid2 resource
	    
	    # Treat the case where the sender is a transport component.
	    # We must be indenpendent of method; agent, browse, disco
	    # The icq transports gives us subscribe from icq.host/registered
	    
	    set jidtype [$jstate(jlib) service gettype $jid2]
	    if {[string match "service/*" $jidtype]} {
		$jstate(jlib) send_presence -to $from -type "subscribed"
		
		# In the future we can collect the transports in another place.
		$jstate(jlib) roster_set $from ::Jabber::Subscribe::ResProc \
		  -groups {Transports}
		
	    } else {
		
		# Another user request to subscribe to our presence.
		# Figure out what the user's prefs are.
		set allUsers [$jstate(roster) getusers]
		if {[lsearch -exact $allUsers $from] >= 0} {
		    set key inrost
		} else {
		    set key notinrost
		}		
		
		# No resource here!
		set subState [$jstate(roster) getsubscription $from]
		set isSubscriberToMe 0
		if {[string equal $subState "from"] ||  \
		  [string equal $subState "both"]} {
		    set isSubscriberToMe 1
		}
		
		# Accept, deny, or ask depending on preferences we've set.
		set msg ""
		set autoaccepted 0
		switch -- $jprefs(subsc,$key) {
		    accept {
			$jstate(jlib) send_presence -to $from -type "subscribed"
			set autoaccepted 1
			set msg [::msgcat::mc jamessautoaccepted $from]
		    }
		    reject {
			$jstate(jlib) send_presence -to $from -type "unsubscribed"
			set msg [::msgcat::mc jamessautoreject $from]
		    }
		    ask {
			eval {::Jabber::Subscribe::Subscribe $from} $args
		    }
		}
		if {$msg != ""} {
		    tk_messageBox -title [::msgcat::mc Info] -icon info -type ok \
		      -message [FormatTextForMessageBox $msg]			      
		}
		
		# Auto subscribe to subscribers to me.
		if {$autoaccepted && $jprefs(subsc,auto)} {
		    
		    # Explicitly set the users group.
		    if {[string length $jprefs(subsc,group)]} {
			$jstate(jlib) roster_set $from ::Jabber::Subscribe::ResProc \
			  -groups [list $jprefs(subsc,group)]
		    }
		    $jstate(jlib) send_presence -to $from -type "subscribe"
		    set msg [::msgcat::mc jamessautosubs $from]
		    tk_messageBox -title [::msgcat::mc Info] -icon info -type ok \
		      -message [FormatTextForMessageBox $msg]			  
		}
	    }
	}
	subscribed {
	    tk_messageBox -title [::msgcat::mc Subscribed] -icon info -type ok  \
	      -message [FormatTextForMessageBox [::msgcat::mc jamessallowsub $from]]
	}
	unsubscribe {	    
	    if {$jprefs(rost,rmIfUnsub)} {
		
		# Remove completely from our roster.
		$jstate(jlib) roster_remove $from ::Jabber::Roster::PushProc
		tk_messageBox -title [::msgcat::mc Unsubscribe] \
		  -icon info -type ok  \
		  -message [FormatTextForMessageBox [::msgcat::mc jamessunsub $from]]
	    } else {
		
		$jstate(jlib) send_presence -to $from -type "unsubscribed"
		tk_messageBox -title [::msgcat::mc Unsubscribe] -icon info -type ok  \
		  -message [FormatTextForMessageBox [::msgcat::mc jamessunsubpres $from]]
		
		# If there is any subscription to this jid's presence.
		set sub [$jstate(roster) getsubscription $from]
		if {[string equal $sub "both"] ||  \
		  [string equal $sub "to"]} {
		    
		    set ans [tk_messageBox -title [::msgcat::mc Unsubscribed]  \
		      -icon question -type yesno -default yes \
		      -message [FormatTextForMessageBox  \
		      [::msgcat::mc jamessunsubask $from $from]]]
		    if {$ans == "yes"} {
			$jstate(jlib) roster_remove $from \
			  ::Jabber::Roster::PushProc
		    }
		}
	    }
	}
	unsubscribed {
	    
	    # If we fail to subscribe someone due to a technical reason we
	    # have sunscription='none'
	    set sub [$jstate(roster) getsubscription $from]
	    if {$sub == "none"} {
		set msg "Failed making a subscription to $from."
		if {[info exists attrArr(-status)]} {
		    append msg " Status message: $attrArr(-status)"
		}
		tk_messageBox -title "Subscription Failed"  \
		  -icon info -type ok  \
		  -message [FormatTextForMessageBox $msg]
		if {$jprefs(rost,rmIfUnsub)} {
		    
		    # Remove completely from our roster.
		    $jstate(jlib) roster_remove $from ::Jabber::Roster::PushProc
		}
	    } else {		
		tk_messageBox -title [::msgcat::mc Unsubscribed]  \
		  -icon info -type ok  \
		  -message [FormatTextForMessageBox  \
		  [::msgcat::mc jamessunsubscribed $from]]
	    }
	}
	error {
	    foreach {errcode errmsg} $attrArr(-error) break		
	    set msg [::msgcat::mc jamesserrpres $errcode $errmsg]
	    if {$prefs(talkative)} {
		tk_messageBox -icon error -type ok  \
		  -title [::msgcat::mc {Presence Error}] \
		  -message [FormatTextForMessageBox $msg]	
	    } else {
		lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
		  $from $msg]
	    }
	}
    }
}

# Jabber::ClientProc --
#
#       This is our standard client procedure for callbacks from jabberlib.
#       It is supposed to handle every event that is not the arrival of any of
#       the <iq>, <message>, or <presence> elements.
#       
# Arguments:
#       jlibName    Name of jabberlib instance.
#       what        Any of "connect", "disconnect", "xmlerror", "networkerror",
#                   "away", or "xaway"
#       args        Is a list of '-key value' pairs.
#       
# Results:
#       none.

proc ::Jabber::ClientProc {jlibName what args} {
    global  wDlgs
    
    variable jstate
    variable jprefs
    
    ::Jabber::Debug 2 "::Jabber::ClientProc: jlibName=$jlibName, what=$what, args='$args'"
    
    # For each 'what', split the argument list into the proper arguments,
    # and make the necessary calls.
    array set attrArr $args
    
    switch -- $what {
	connect {
	    
	    # We just got the <stream> element from the server.
	    # Handled via direct callback from 'jlibName connect' instead.
	}
	disconnect {	    
	    
	    # This is as a response to a </stream> element.
	    # If we close the socket and don't wait for the close element
	    # we never end up here.
	    
	    # Disconnect. This should reset both wrapper and XML parser!
	    ::Jabber::DoCloseClientConnection
	    
	    tk_messageBox -icon error -type ok  \
	      -message [::msgcat::mc jamessconnbroken]
	}
	away - xaway {
	    
	    set tm [clock format [clock seconds] -format "%H:%M:%S"]
	    set ans [tk_messageBox -icon info -type yesno -default yes \
	      -message [FormatTextForMessageBox \
	      [::msgcat::mc jamessautoawayset $tm]]
	    if {$ans == "yes"} {
		::Jabber::SetStatus available
	    }
	}
	xmlerror {
	    
	    # XML parsing error.
	    # Disconnect. This should reset both wrapper and XML parser!
	    ::Jabber::DoCloseClientConnection
	    if {[info exists attrArr(-errormsg)]} {
		set msg "Receieved a fatal XML parsing error:\
		  $attrArr(-errormsg). The connection is closed down."
	    } else {
		set msg {Receieved a fatal XML parsing error.\
		  The connection is closed down.}
	    }
	    tk_messageBox -title [::msgcat::mc {Fatal Error}] -icon error -type ok \
	      -message [FormatTextForMessageBox $msg]
	}
	networkerror {
	    
	    # Disconnect. This should reset both wrapper and XML parser!
	    ::Jabber::DoCloseClientConnection
	    tk_messageBox -title [::msgcat::mc {Network Error}] \
	      -message [FormatTextForMessageBox $attrArr(-body)] \
	      -icon error -type ok	    
	}
    }
}

# Jabber::DebugCmd --
#
#       Hides or shows console on mac and windows, sets debug for XML I/O.

proc ::Jabber::DebugCmd { } {
    global  this
    
    variable jstate
    
    if {$jstate(debugCmd)} {
	if {$this(platform) == "windows" || [string match "mac*" $this(platform)]} {
	    console show
	}
	jlib::setdebug 2
    } else {
	if {$this(platform) == "windows" || [string match "mac*" $this(platform)]} {
	    if {$jstate(debug) == 0} {
		console hide
	    }
	}
	jlib::setdebug 0
    }
}

# Jabber::ErrorLogDlg

proc ::Jabber::ErrorLogDlg { } {
    global  this wDlgs
    
    variable jerror

    set w $wDlgs(jerrdlg)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w {Error Log (noncriticals)}
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Text.
    set wtxt $w.frall.frtxt
    pack [frame $wtxt] -side top -fill both -expand 1 -padx 4 -pady 4
    set wtext $wtxt.text
    set wysc $wtxt.ysc
    text $wtext -height 12 -width 48 -wrap word \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set]
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure $wtxt 0 -weight 1
    
    set space 2
    $wtext tag configure timetag -spacing1 $space -foreground blue
    $wtext tag configure jidtag -spacing1 $space -foreground red
    $wtext tag configure msgtag -spacing1 $space -spacing3 $space   \
      -lmargin1 20 -lmargin2 30
        
    $wtext configure -state normal
    foreach line $jerror {
	foreach {tm jid msg} $line break
	$wtext insert end "<$tm>:  " timetag
	$wtext insert end "$jid   " jidtag
	$wtext insert end $msg msgtag
	$wtext insert end "\n"
    }
    $wtext configure -state disabled
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btset -text [::msgcat::mc Close] -width 8 \
      -command "destroy $w"] -side right -padx 5 -pady 5
    pack $frbot -side top -fill x -padx 8 -pady 6
}

# Jabber::IqSetGetCallback --
#
#       Generic callback procedure when sending set/get iq element.
#       
# Arguments:
#       method      description of the original call.
#       jlibName:   the instance of this jlib.
#       type:       "error" or "ok".
#       thequery:   if type="error", this is a list {errcode errmsg},
#                   else it is the query element as a xml list structure.
#       
# Results:
#       none.

proc ::Jabber::IqSetGetCallback {method jlibName type theQuery} {    
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::IqSetGetCallback, method=$method, type=$type,\
	  theQuery='$theQuery'"
	
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} $theQuery break
	switch -- $method {
	    default {
		set msg "Found an error for $method with code $errcode,\
		  and with message: $errmsg"
	    }
	}
	tk_messageBox -icon error -type ok -title [::msgcat::mc Error] -message \
	  [FormatTextForMessageBox $msg]
    }
}

# Jabber::SendWhiteboardMessage --
#
#       This is just a shortcut for sending a message. Practical in the
#       whiteboard since it hides the internal jabber vars.
#       
# Arguments:
#       wtop
#       msg
#       args        ?-key value ...?
#                   -force 0|1   (D=0) override doSend checkbutton?
#       
# Results:
#       none.

proc ::Jabber::SendWhiteboardMessage {wtop msg args} {
    variable jstate
    
    array set opts {-force 0}
    array set opts $args
    set tojid $jstate($wtop,tojid)
    
    # Here we shall decide the 'type' of message sent (normal, chat, groupchat)
    # depending on the type of whiteboard (via wtop).
    set argsList [::Jabber::SendWhiteboardArgs $wtop]
    
    if {$jstate($wtop,doSend) || $opts(-force)} {
	if {[::Jabber::VerifyJIDWhiteboard $wtop]} {
	    eval {::Jabber::SendMessage $tojid $msg} $argsList
	} else {
	    
	    # Perhaps we should give some aid here; set focus?
	}
    }
}

# Jabber::SendWhiteboardMessageList --
#
#       As above but for a list of commands.

proc ::Jabber::SendWhiteboardMessageList {wtop msgList args} {
    variable jstate
    
    array set opts {-force 0}
    array set opts $args
    set tojid $jstate($wtop,tojid)

    set argsList [::Jabber::SendWhiteboardArgs $wtop]
    if {$jstate($wtop,doSend) || $opts(-force)} {
	if {[::Jabber::VerifyJIDWhiteboard $wtop]} {
	    eval {::Jabber::SendMessageList $tojid $msgList} $argsList
	} else {
	    
	    # Perhaps we should give some aid here; set focus?
	}
    }
}

proc ::Jabber::SendWhiteboardArgs {wtop} {

    set argsList {}
    set type [::WB::GetJabberType $wtop]
    if {[llength $type] > 0} {
	lappend argsList -type $type
	if {[string equal $type "chat"]} {
		lappend argsList -thread [::WB::GetJabberChatThread $wtop]
	}
    }
    return $argsList
}

# Jabber::SendMessage --
#
#       Sends a message, typically in an <x xmlns='coccinella:wb'><raw> element.
#       
# Arguments:
#       jid
#       msg
#       args    ?-key value? list to use for 'send_message'.
#       
# Results:
#       none.

proc ::Jabber::SendMessage {jid msg args} {    
    variable jstate
    
    # Form an <x xmlns='coccinella:wb'><raw> element in message.
    set subx [list [wrapper::createtag "raw" -chdata $msg]]
    set xlist [list [wrapper::createtag x -attrlist  \
      {xmlns coccinella:wb} -subtags $subx]]
    if {[catch {
	eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
    } err]} {
	::Jabber::DoCloseClientConnection
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $err]
    }
}

# Jabber::SendMessageList --
#
#       As above but for a list of commands.

proc ::Jabber::SendMessageList {jid msgList args} {
    variable jstate
    
    # Form <x xmlns='coccinella:wb'> element with any number of <raw>
    # elements as childs.
    set subx {}
    foreach msg $msgList {
	lappend subx [wrapper::createtag "raw" -chdata $msg]
    }
    set xlist [list [wrapper::createtag x -attrlist  \
      {xmlns coccinella:wb} -subtags $subx]]
    if {[catch {
	eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
    } err]} {
	::Jabber::DoCloseClientConnection
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $err]
    }
}

# Jabber::DoSendCanvas --
# 
#       Wrapper for ::CanvasCmd::DoSendCanvas.

proc ::Jabber::DoSendCanvas {wtop} {
    global  prefs
    variable jstate

    set wtoplevel [::UI::GetToplevel $wtop]
    set jid $jstate($wtop,tojid)

    if {[::Jabber::IsWellFormedJID $jid]} {
	
	# The Classic mac can't run the http server!
	if {!$prefs(haveHttpd)} {
	    set ans [tk_messageBox -icon warning -type yesno  \
	      -parent $wtoplevel  \
	      -message [FormatTextForMessageBox "The Classic Mac can't run\
	      the internal http server which is needed for transporting any\
	      images etc. in this message.\
	      Do you want to send it anyway?"]]
	    if {$ans == "no"} {
		return
	    }
	}
	
	# If user not online no files may be sent off.
	if {![$jstate(roster) isavailable $jid]} {
	    set ans [tk_messageBox -icon warning -type yesno  \
	      -parent $wtoplevel  \
	      -message [FormatTextForMessageBox "The user you are sending to,\
	      \"$jid\", is not online, and if this message contains any images\
	      or other similar entities, this user will not get them unless\
	      you happen to be online while this message is being read.\
	      Do you want to send it anyway?"]]
	    if {$ans == "no"} {
		return
	    }
	}
	::CanvasCmd::DoSendCanvas $wtop
	::WB::CloseWhiteboard $wtop
    } else {
	tk_messageBox -icon warning -type ok -parent $wtoplevel -message \
	  [FormatTextForMessageBox [::msgcat::mc jamessinvalidjid]]
    }
}

# Jabber::UpdateAutoAwaySettings --
#
#       If changed present auto away settings, may need to configure
#       our jabber object.

proc ::Jabber::UpdateAutoAwaySettings { } {    
    variable jstate
    variable jprefs
    
    array set oldopts [$jstate(jlib) config]
    set reconfig 0
    foreach name {autoaway xautoaway awaymin xawaymin} {
	if {$oldopts(-$name) != $jprefs($name)} {
	    set reconfig 1
	    break
	}
    }
    if {$reconfig} {
	set opts {}
	if {$jprefs(autoaway) || $jprefs(xautoaway)} {
	    foreach name {autoaway xautoaway awaymin xawaymin awaymsg xawaymsg} {
		lappend opts -$name $jprefs($name)
	    }
	}
	eval {$jstate(jlib) config} $opts
    }
}

# Jabber::DoCloseClientConnection --
#
#       Handle closing down the client side connection (the 'to' part).
#       Try to be silent if called as a response to a server shutdown.
#       
# Arguments:
#       args      -status, 
#       
# Results:
#       none

proc ::Jabber::DoCloseClientConnection {args} {
    global  prefs
        
    variable jstate
    variable jserver
    variable jprefs
    
    ::Jabber::Debug 2 "::Jabber::DoCloseClientConnection"
    array set argsArr [list -status $jprefs(logoutStatus)]    
    array set argsArr $args
    
    # Ourself.
    set jstate(mejid) ""
    set jstate(meres) ""
    set jstate(mejidres) ""
    set jstate(status) "unavailable"
    set jserver(this) ""

    # Send unavailable information. Silently in case we got network error.
    set opts {}
    if {[string length $argsArr(-status)] > 0} {
	lappend opts -status $argsArr(-status)
    }
    catch {
	eval {$jstate(jlib) send_presence -type unavailable} $opts
    }
        
    # Do the actual closing.
    #       There is a potential problem if called from within a xml parser 
    #       callback which makes the subsequent parsing to fail. (after idle?)
    after idle $jstate(jlib) disconnect
    
    # Update the communication frame; remove connection 'to'.
    ::WB::ConfigureAllJabberEntries $jstate(ipNum) -netstate "disconnect"

    ::Network::DeRegisterIP $jstate(ipNum)
    
    set jstate(ipNum) ""
    
    # Run all logout hooks.
    hooks::run logoutHook
}

# Jabber::EndSession --
#
#       This is supposed to be called only when doing Quit.
#       Things are not cleaned up properly, since we kill ourselves.

proc ::Jabber::EndSession { } {    
    variable jstate
    variable jserver
    variable jprefs

    # Send unavailable information. Silently in case we got network error.
    if {[::Jabber::IsConnected]} {
	set opts {}
	if {[string length $jprefs(logoutStatus)] > 0} {
	    lappend opts -status $jprefs(logoutStatus)
	}
	catch {
	    #::Jabber::SetStatus unavailable
	    eval {$jstate(jlib) send_presence -type unavailable} $opts
	}
	
	# Do the actual closing.
	#       There is a potential problem if called from within a xml parser 
	#       callback which makes the subsequent parsing to fail. (after idle?)
	$jstate(jlib) disconnect
    }
    
    # Either save inbox or delete.
    ::Jabber::MailBox::Exit
}

# Jabber::BuildJabberEntry --
#
#       A utility procedure to build a persistant jabber entry.
#       Used to hide jabber stuff away from ::UI

proc ::Jabber::BuildJabberEntry {wtop args} {
    
    eval {::WB::BuildJabberEntry $wtop  \
      -servervariable ::Jabber::jserver(this)  \
      -jidvariable ::Jabber::jstate($wtop,tojid) \
      -dosendvariable ::Jabber::jstate($wtop,doSend)} $args
      
    eval {::Jabber::ConfigureJabberEntry $wtop} $args
}

# Jabber::ConfigureJabberEntry --
#
#       A utility procedure to configure the jabber entry.
#       Used to hide jabber stuff away from ::UI

proc ::Jabber::ConfigureJabberEntry {wtop args} {
    variable jstate

    Debug 2 "::Jabber::ConfigureJabberEntry wtop=$wtop args='$args'"
    foreach {key value} $args {
    	switch -- $key {
    	    -jid {
    	    	set jstate($wtop,tojid) $value
	    }

	}
    }
}

# Jabber::IsWellFormedJID --
#
#       Is this a well formed Jabber ID?. What abot the resource (/home) part?
#       
# Arguments:
#       jid     Jabber ID, such as 'matben@athlon.se', if well formed.
#       
# Results:
#       boolean

proc ::Jabber::IsWellFormedJID {jid args} {    
    variable jprefs
    
    array set argsArr {
	-type   user
    }
    array set argsArr $args
    
    switch -- $argsArr(-type) {
	user {
	    if {[regexp {^(.+)@([^/]+)(/(.*))?$} $jid match name host junk res]} {
		if {[regexp $jprefs(invalsExp) $name match junk]} {
		    return 0
		} elseif {[regexp $jprefs(invalsExp) $host match junk]} {
		    return 0
		}
		return 1
	    } else {
		return 0
	    }
	}
	any {
	    
	    # Be sure to remove any separators @ and /.
	    regsub -all / $jid "" jidStrip
	    regsub -all @ $jidStrip "" jidStrip
	    if {[regexp $jprefs(invalsExp) $jidStrip match]} {
		return 0
	    } else {
		return 1
	    }
	}
    }
}

# Jabber::ValidateJIDChars --
#
#       Validate entry for username etc.
#       
# Arguments:
#       str     username etc.
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::ValidateJIDChars {str} {    
    variable jprefs

    if {[regexp $jprefs(invalsExp) $str match junk]} {
	bell
	return 0
    } else {
	return 1
    }
}

# Jabber::ValidatePasswdChars --
#
#       Validate entry for password. Not so sure about this. Docs?
#       
# Arguments:
#       str     password
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::ValidatePasswdChars {str} {
    
    if {[regexp {[ ]} $str match junk]} {
	bell
	return 0
    } else {
	return 1
    }
}

# Jabber::SetStatus --
#
#       Sends presence status information. 
#       It should take care of everything (almost) when setting status.
#       
# Arguments:
#       type        any of 'available', 'unavailable', 'invisible',
#                   'away', 'dnd', 'xa'.
#       args
#                -to      sets any to='jid' attribute.
#                -notype  0|1 see XMPP 5.1
#       
# Results:
#       None.

proc ::Jabber::SetStatus {type args} {    
    variable jstate
    variable jserver
    
    array set argsArr {
	-notype         0
    }
    array set argsArr $args
    
    set presArgs {}
    foreach {key value} $args {
	switch -- $key {
	    -to - -priority {
		lappend presArgs $key $value
	    }
	}
    }
    if {!$argsArr(-notype)} {	
	switch -- $type {
	    available - invisible - unavailable {
		lappend presArgs -type $type
	    }
	    away - dnd - xa {
		lappend presArgs -type "available" -show $type
	    }
	}	
    }
    
    # Trap network errors.
    # It is somewhat unclear here if we should have a type attribute
    # when sending initial presence, see XMPP 5.1.
    if {[catch {	
	eval {$jstate(jlib) send_presence} $presArgs
    } err]} {
	
	# Close down?	
	::Jabber::DoCloseClientConnection
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $err]
    } else {
	
	# Do we target a room or the server itself?
	set toServer 0
	if {[info exists argsArr(-to)]} {
	    if {[string equal $jserver(this) $argsArr(-to)]} {
		set toServer 1
	    }
	} else {
	    set toServer 1
	}
	if {$toServer} {
	    ::Jabber::UI::WhenSetStatus $type
	    if {$type == "unavailable"} {
		::Jabber::DoCloseClientConnection
	    }
	}
    }
}

# Jabber::SetStatusWithMessage --
#
#       Dialog for setting user's status with message.
#       
# Arguments:
#       
# Results:
#       "cancel" or "set".

proc ::Jabber::SetStatusWithMessage { } {
    global  this wDlgs
    
    variable finishedStat
    variable show
    variable wtext
    variable jprefs
    variable jstate

    set w $wDlgs(jpresmsg)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w [::msgcat::mc {Set Status}]
    set finishedStat -1
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Top frame.
    set frtop $w.frall.frtop
    set fr [::mylabelframe::mylabelframe $frtop [::msgcat::mc {My Status}]]
    pack $frtop -side top -fill x -padx 4 -pady 4
    set i 0
    foreach val {available chat away xa dnd invisible} {
	label ${fr}.l${val} -image [::Jabber::Roster::GetPresenceIconFromKey $val]
	radiobutton ${fr}.${val} -text [::msgcat::mc jastat${val}]  \
	  -variable [namespace current]::show -value $val
	grid ${fr}.l${val} -sticky e -column 0 -row $i -padx 4 -pady 3
	grid ${fr}.${val} -sticky w -column 1 -row $i -padx 8 -pady 3
	incr i
    }
    
    # Set present status.
    set show $jstate(status)
    
    pack [label $w.frall.lbl -text "[::msgcat::mc {Status message}]:" \
      -font $fontSB]  \
      -side top -anchor w -padx 6 -pady 0
    set wtext $w.frall.txt
    text $wtext -height 4 -width 36 -wrap word \
      -borderwidth 1 -relief sunken
    pack $wtext -expand 1 -fill both -padx 6 -pady 4    
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [::msgcat::mc Set] -default active \
      -command [list [namespace current]::BtSetStatus $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command [list [namespace current]::SetStatusCancel $w]] \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> {}
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finishedStat <= 0) ? "cancel" : "set"}]
}

proc ::Jabber::SetStatusCancel {w} {    
    variable finishedStat

    set finishedStat 0
    destroy $w
}

proc ::Jabber::BtSetStatus {w} {
    variable finishedStat
    variable show
    variable wtext
    variable jstate
    
    set statusOpt {}
    set allText [string trim [$wtext get 1.0 end] " \n"]
    if {[string length $allText]} {
	set statusOpt [list -status $allText]
    }  
    
    # Set present status.
    set jstate(status) $show
    
    switch -- $show {
	invisible {
	    eval {$jstate(jlib) send_presence -type "invisible" -show $show} \
	      $statusOpt
	}
	default {
	    eval {$jstate(jlib) send_presence -type "available" -show $show} \
	      $statusOpt
	}
    }
    ::Jabber::UI::WhenSetStatus $show
    
    set finishedStat 1
    destroy $w
}

# Jabber::GetIPnumber / PutIPnumber --
#
#       Utilites to put/get ip numbers from clients.
#
# Arguments:
#       jid:        fully qualified "username@host/resource".
#       cmd:        (optional) callback command when gets ip number.
#       
# Results:
#       none.

proc ::Jabber::GetIPnumber {jid {cmd {}}} {    
    variable jstate
    variable getcmd
    variable getid
    variable jidToIP

    ::Jabber::Debug 2 "::Jabber::GetIPnumber:: jid=$jid, cmd='$cmd'"
    
    if {$cmd != ""} {
	set getcmd($getid) $cmd
    }
    
    # What shall we do when we already have the IP number?
    if {[info exists jidToIP($jid)]} {
	::Jabber::GetIPCallback $jid $getid $jidToIP($jid)
    } else {
	::Jabber::SendMessage $jid "GET IP: $getid"
    }
    incr getid
}

# Jabber::GetIPCallback --
#
#       This proc gets called when a requested ip number is received
#       by our server.
#
# Arguments:
#       fromjid     fully qualified  "username@host/resource"
#       id
#       ip
#       
# Results:
#       Any registered callback proc is eval'ed.

proc ::Jabber::GetIPCallback {fromjid id ip} {    
    variable jstate
    variable getcmd
    variable jidToIP

    ::Jabber::Debug 2 "::Jabber::GetIPCallback: fromjid=$fromjid, id=$id, ip=$ip"

    set jidToIP($fromjid) $ip
    if {[info exists getcmd($id)]} {
	::Jabber::Debug 2 "   getcmd($id)='$getcmd($id)'"
	eval $getcmd($id) $fromjid
	unset getcmd($id)
    }
}

proc ::Jabber::PutIPnumber {jid id} {
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::PutIPnumber:: jid=$jid, id=$id"
    
    set ip [::Network::GetThisOutsideIPAddress]
    ::Jabber::SendMessage $jid "PUT IP: $id $ip"
}

# Jabber::GetCoccinellaServers --
# 
#       Get Coccinella server ports and ip via <iq>.

proc ::Jabber::GetCoccinellaServers {jid3 {cmd {}}} {
    variable jstate
    variable privatexmlns
    
    $jstate(jlib) iq_get $privatexmlns(servers) $jid3  \
      -command [list ::Jabber::GetCoccinellaServersCallback $jid3 $cmd]
}

proc ::Jabber::GetCoccinellaServersCallback {jid3 cmd jlibname type subiq} {
    variable jidToIP
    
    # ::Jabber::GetCoccinellaServersCallback jabberlib1 ok 
    #  {query {xmlns http://coccinella.sourceforge.net/protocols/servers} 0 {} {
    #     {ip {protocol putget port 8235} 0 212.214.113.57 {}} 
    #     {ip {protocol http port 8077} 0 212.214.113.57 {}}
    #  }}
    ::Jabber::Debug 2 "::Jabber::GetCoccinellaServersCallback"

    if {$type == "error"} {
	return
    }
    set ipElements [wrapper::getchildswithtag $subiq ip]
    set ip [wrapper::getcdata [lindex $ipElements 0]]
    set jidToIP($jid3) $ip
    if {$cmd != ""} {
	eval $cmd
    }
}

# Jabber::PutFileOrSchedule --
# 
#       Handles everything needed to put a file to the jid's corresponding
#       to the 'wtop'. Users that we haven't got ip number from are scheduled
#       for delivery as a callback.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       fileName    the path to the file to be put.
#       opts        a list of '-key value' pairs, where most keys correspond 
#                   to a valid "canvas create" option, and everything is on 
#                   a single line.
#       
# Results:
#       none.

proc ::Jabber::PutFileOrSchedule {wtop fileName opts} {    
    variable jidToIP
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::PutFileOrSchedule: \
      wtop=$wtop, fileName=$fileName, opts='$opts'"
    
    # Before doing anything check that the Send checkbutton is on. ???
    if {!$jstate($wtop,doSend)} {
    	::Jabber::Debug 2 "    doSend=0 => return"
	return
    }
    
    # Verify that jid is well formed.
    if {![::Jabber::VerifyJIDWhiteboard $wtop]} {
	return
    }
    
    # This must never fail (application/octet-stream as fallback).
    set mime [::Types::GetMimeTypeForFileName $fileName]
    
    # Need to add jabber specific info to the 'optList', such as
    # -to, -from, -type, -thread etc.
    # 
    # -type and 'tojid' shall never be in conflict???
    foreach {key value} [::WB::ConfigureMain $wtop] {
	switch -- $key {
	    -type - -thread {
		lappend opts $key $value
	    }
	}
    }
    
    set tojid $jstate($wtop,tojid)
    set isRoom 0
    
    if {[regexp {^(.+)@([^/]+)/([^/]*)} $tojid match name host res]} {
	
	# The 'tojid' is already complete with resource.
	set allJid3 $tojid
    	lappend opts -from $jstate(mejidres)
    } else {
	
	# If 'tojid' is without a resource, it can be a room.
	if {[$jstate(jlib) service isroom $tojid]} {
	    set isRoom 1
	    set allJid3 [$jstate(jlib) service roomparticipants $tojid]
	    
	    # Exclude ourselves.
	    foreach {meRoomJid nick} [$jstate(jlib) service hashandnick $tojid] \
	      break
	    set ind [lsearch $allJid3 $meRoomJid]
	    if {$ind >= 0} {
		set allJid3 [lreplace $allJid3 $ind $ind]
	    }
	    
	    # Be sure to have our room jid and not the real one.
     	    lappend opts -from $meRoomJid
	} else {
	    
	    # Else put to resource with highest priority.
	    set res [$jstate(roster) gethighestresource $tojid]
	    if {$res == ""} {
		
		# This is someone we haven't got presence from.
		set allJid3 $tojid
	    } else {
		set allJid3 $tojid/$res
	    }
	    lappend opts -from $jstate(mejidres)
	}
    }
    
    ::Jabber::Debug 2 "   allJid3=$allJid3"
    
    # We shall put to all resources. Treat each in turn.
    foreach jid3 $allJid3 {
	
	# If we are in a room all must be available, else check.
	if {$isRoom} {
	    set avail 1
	} else {
	    set avail [$jstate(roster) isavailable $jid3]
	}
	
	# Each jid must get its own -to attribute.
	set optjidList [concat $opts -to $jid3]
	
	::Jabber::Debug 2 "   jid3=$jid3, avail=$avail"
	
	if {$avail} {
	    if {[info exists jidToIP($jid3)]} {
		
		# This one had already told us its ip number, good!
		::Jabber::PutFile $wtop $fileName $mime $optjidList $jid3
	    } else {
		
		# This jid is online but has not told us its ip number.
		# We need to get this jid's ip number and register the
		# PutFile as a callback when receiving this ip.
		if {1} {
		    ::Jabber::GetIPnumber $jid3 \
		      [list ::Jabber::PutFile $wtop $fileName $mime $optjidList]
		} else {
		    
		    # New through <iq> element.
		    # Switch to this with version 0.94.8 or later!
		    ::Jabber::GetCoccinellaServers $jid3  \
		      [list ::Jabber::PutFile $wtop $fileName $mime  \
		      $optjidList $jid3]
		}
	    }
	} else {
	    
	    # We need to tell this jid to get this file from a server,
	    # possibly as an OOB http transfer.
	    array set optArr $opts
	    if {[info exists optArr(-url)]} {
		$jstate(jlib) oob_set $jid3 ::Jabber::OOB::SetCallback  \
		  $optArr(-url)  \
		  -desc {This file is part of a whiteboard conversation.\
		  You were not online when I opened this file}
	    } else {
		puts "   missing optArr(-url)"
	    }
	}
    }
        
    # This is an activity that may not be registered with jabberlib's auto away
    # functions, and must therefore schedule it here. ???????
    $jstate(jlib) schedule_auto_away
}

# Jabber::PutFile --
#
#       Puts the file to the given jid provided the client has
#       told us its ip number.
#       Calls '::PutFileIface::PutFileToAll' to do the real work for us.
#
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       fileName    the path to the file to be put.
#       opts        a list of '-key value' pairs, where most keys correspond 
#                   to a valid "canvas create" option, and everything is on 
#                   a single line.
#       jid         fully qualified  "username@host/resource"
#       
# Results:

proc ::Jabber::PutFile {wtop fileName mime opts jid} {
    global  prefs
    variable jidToIP
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::PutFile: fileName=$fileName, opts='$opts', jid=$jid"
 
    if {![info exists jidToIP($jid)]} {
	puts "::Jabber::PutFile: Houston, we have a problem. \
	  jidToIP($jid) not there"
	return
    }
    
    # Check first that the user has not closed the window since this
    # call may be async.
    if {$wtop == "."} {
	set win .
    } else {
	set win [string trimright $wtop "."]
    }    
    if {![winfo exists $win]} {
	return
    }
    
    # Translate tcl type '-key value' list to 'Key: value' option list.
    set optList [::Import::GetTransportSyntaxOptsFromTcl $opts]

    ::PutFileIface::PutFile $wtop $fileName $jidToIP($jid) $optList
}

# Jabber::HandlePutRequest --
# 
#       Takes care of a PUT command from the server.
#       The problem is that we get a direct connection with
#       PUT/GET request outside the Jabber framework.

proc ::Jabber::HandlePutRequest {channel fileName opts} {
        
    # The whiteboard must exist!
    set wtop [::Jabber::WB::MakeWhiteboardExist $opts]
    
    # Be sure to strip off any path. (this(path))??? Mac bug for /file?
    set tail [file tail $fileName]
    ::GetFileIface::GetFile $wtop $channel $tail $opts
}

# Jabber::SetPrivateData --
#
#       Set ip & port of our two servers at out public space at the server
#       for others to fetch.
#       
# Arguments:
#       
# Results:
#       none.

proc ::Jabber::SetPrivateData { } {
    global  prefs
    
    variable jstate
    variable privatexmlns
    
    # Build tag and attributes lists to 'private_set'.
    set ip [::Network::GetThisOutsideIPAddress]
    $jstate(jlib) private_set $privatexmlns(public)  \
      [list ::Jabber::SetPrivateDataCallback private_set]   \
      -server [list $ip [list resource $jstate(meres)  \
      port $prefs(thisServPort)]]       \
      -httpd [list $ip [list resource $jstate(meres)   \
      port $prefs(httpdPort)]]
}

# Jabber::SetPrivateDataCallback --
#
#       Records if this was succesful or not. Be silent.

proc ::Jabber::SetPrivateDataCallback {jid jlibName what theQuery} {    
    variable jidPublic

    if {[string equal $what "error"]} {
	set jidPublic(haveit) 0
    } else {
	set jidPublic(haveit) 1
    }
}

# Jabber::GetPrivateData --
#
#       Gets ip & port of the two servers for the specified jid.
#       
# Arguments:
#       jid         get data from this jid.
#       
# Results:
#       shows window.

proc ::Jabber::GetPrivateData {jid} {
    variable jstate
    variable privatexmlns
    
    # Build tag and attributes lists to 'private_set'.
    $jstate(jlib) private_get $privatexmlns(public) {server httpd}  \
      [list ::Jabber::GetPrivateDataCallback $jid]
}

# Jabber::GetPrivateDataCallback --
#
#       Parses the callback when receiving the iq result (or error).

proc ::Jabber::GetPrivateDataCallback {jid jlibName what theQuery} {    
    variable jidPublic
    
    if {[string equal $what "error"]} {
	foreach {errcode errmsg} $theQuery {}
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrgetpublic $jid $errcode $errmsg]]
	return
    }
    
    # Parse the query element:
    # theQuery='{query {xmlns $privatexmlns(public)} 0 {} {
    #     {server {resource home port 8235} 0 192.168.0.4 {}} 
    #     {httpd {resource home port 8077} 0 192.168.0.4 {}}}}'
    set childList [lindex $theQuery 4]
    foreach {tag attrlist empty chdata c} $childList {
	foreach {name val} $attrlist {
	    set $name $val
	}
	set jidPublic($jid,$resource,$tag) $chdata
	foreach {name val} $attrlist {
	    if {[string equal $name "resource"]} {
		continue
	    }
	    
	    # Typically: jidPublic(matben@athlon.se,home,serverport).
	    set jidPublic($jid,$resource,$tag$name) $val
	}
    }
}
    
# Jabber::GetAnyDelayElem --
#
#       Takes a list of x-elements, finds any 'jabber:x:delay' x-element.
#       If no such element it returns empty.
#       
# Arguments:
#       xlist       Must be an hierarchical xml list of <x> elements.  
#       
# Results:
#       jabber:x:delay stamp attribute or empty.

proc ::Jabber::GetAnyDelayElem {xlist} {
    
    set ans ""
    foreach xelem $xlist {
	foreach {tag attrlist empty chdata sub} $xelem break
	catch {unset attrArr}
	array set attrArr $attrlist
	if {[info exists attrArr(xmlns)] &&  \
	  [string equal $attrArr(xmlns) "jabber:x:delay"]} {
	    
	    # This is ISO 8601.
	    if {[info exists attrArr(stamp)]} {
		set ans $attrArr(stamp)
		break
	    }
	}
    }
    return $ans
}

#-------------------------------------------------------------------------------
    
# Jabber::GetLast --
#
#       Makes a jabber:iq:last query.
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::GetLast {to args} {
    variable jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args    
    $jstate(jlib) get_last $to [list ::Jabber::GetLastResult $to $opts(-silent)]
}

# Jabber::GetLastResult --
#
#       Callback for '::Jabber::GetLast'.

proc ::Jabber::GetLastResult {from silent jlibname type subiq} {    
    variable jerror

    if {[string equal $type "error"]} {
	set msg [::msgcat::mc jamesserrlastactive $from [lindex $subiq 1]]
	if {$silent} {
	    lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
	      $from $msg]	    
	} else {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox $msg]
	}
    } else {
	array set attrArr [lindex $subiq 1]
	if {![info exists attrArr(seconds)]} {
	    tk_messageBox -title [::msgcat::mc {Last Activity}] -icon info  \
	      -type ok -message [FormatTextForMessageBox \
	      [::msgcat::mc jamesserrnotimeinfo $from]]
	} else {
	    set secs [expr [clock seconds] - $attrArr(seconds)]
	    set uptime [clock format $secs -format "%a %b %d %H:%M:%S"]
	    if {[lindex $subiq 3] != ""} {
		set msg "The message: [lindex $subiq 3]"
	    } else {
		set msg {}
	    }
	    
	    # Time interpreted differently for different jid types.
	    if {$from != ""} {
		if {[regexp {^[^@]+@[^/]+/.*$} $from match]} {
		    set msg1 [::msgcat::mc jamesstimeused $from]
		} elseif {[regexp {^.+@[^/]+$} $from match]} {
		    set msg1 [::msgcat::mc jamesstimeconn $from]
		} else {
		    set msg1 [::msgcat::mc jamesstimeservstart $from]
		}
	    } else {
		set msg1 [::msgcat::mc jamessuptime]
	    }
	    tk_messageBox -title [::msgcat::mc {Last Activity}] -icon info  \
	      -type ok -message \
	      [FormatTextForMessageBox "$msg1 $uptime. $msg"]
	}
    }
}

# Jabber::GetTime --
#
#       Makes a jabber:iq:time query.
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::GetTime {to args} {
    variable jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args    
    $jstate(jlib) get_time $to [list ::Jabber::GetTimeResult $to $opts(-silent)]
}

proc ::Jabber::GetTimeResult {from silent jlibname type subiq} {
    variable jerror

    if {[string equal $type "error"]} {
	if {$silent} {
	    lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
	      $from "We received an error when quering its time info.\
	      The error was: [lindex $subiq 1]"]	    
	} else {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox \
	      [::msgcat::mc jamesserrtime $from [lindex $subiq 1]]]
	}
    } else {
	
	# Display the cdata of <display>, or <utc>.
	foreach child [lindex $subiq 4] {
	    set tag [lindex $child 0]
	    set $tag [lindex $child 3]
	}
	if {[info exists display]} {
	    set msg $display
	} elseif {[info exists utc]} {
	    set msg $utc
	} elseif {[info exists tz]} {
	    set msg $tz
	} else {
	    set msg {unknown}
	}
	tk_messageBox -title [::msgcat::mc {Local Time}] -icon info -type ok -message \
	  [FormatTextForMessageBox [::msgcat::mc jamesslocaltime $from $msg]]
    }
}

namespace eval ::Jabber:: {
    
    # Running uid for dialog window path.
    variable uidvers 0
}

# Jabber::GetVersion --
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::GetVersion {to args} {
    variable jstate

    array set opts {
	-silent 0
    }
    array set opts $args    
    $jstate(jlib) get_version $to [list ::Jabber::GetVersionResult $to $opts(-silent)]
}

proc ::Jabber::GetVersionResult {from silent jlibname type subiq} {
    global  prefs this
    
    variable jerror
    variable uidvers
    
    set fontSB [option get . fontSmallBold {}]
    
    if {[string equal $type "error"]} {
	if {$silent} {
	    lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
	      $from [::msgcat::mc jamesserrvers $from [lindex $subiq 1]]]
	} else {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox \
	      [::msgcat::mc jamesserrvers $from [lindex $subiq 1]]]
	}
    } else {
	set w .jvers[incr uidvers]
	::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
	wm title $w [::msgcat::mc {Version Info}]
	pack [label $w.icon -bitmap info] -side left -anchor n -padx 10 -pady 10
	pack [label $w.msg -text [::msgcat::mc javersinfo $from] -font $fontSB] \
	  -side top -padx 8 -pady 4
	pack [frame $w.fr] -padx 10 -pady 4 -side top 
	set i 0
	foreach child [lindex $subiq 4] {
	    label $w.fr.l$i -font $fontSB -text "[lindex $child 0]:"
	    label $w.fr.lr$i -text [lindex $child 3]
	    grid $w.fr.l$i -column 0 -row $i -sticky e
	    grid $w.fr.lr$i -column 1 -row $i -sticky w
	    incr i
	}
	pack [button $w.btok -text [::msgcat::mc OK] \
	  -command "destroy $w"] -side right -padx 10 -pady 8
	wm resizable $w 0 0
	bind $w <Return> "$w.btok invoke"
    }
}

# Jabber::CacheGroupchatType --
#
#       Callback from a 'jabber:iq:version' query called from either the agent,
#       or the browse callback procs to see which protocols may be used:
#       'conference' and 'groupchat' or only 'groupchat'.
#

proc ::Jabber::CacheGroupchatType {confjid jlibname type subiq} {    
    variable jstate
    
    if {[string equal $type "error"]} {
	
	# Perhaps we should log it in our error log?
	return
    }
    
    # The conference component:
    # <query xmlns='jabber:iq:version'><name>conference</name><version>0.4</version>
    #   <os>Linux 2.4.2-2</os></query>
    
    # The MUC, Multi User Chat (MUC) component:
    # <query xmlns='jabber:iq:version'><name>MU-Conference</name><version>0.4cvs</version>
    #	<os>Linux 2.4.17</os></query>
    
    set name ""
    set version ""
    foreach child [lindex $subiq 4] {
	set tag [lindex $child 0]
	set $tag [lindex $child 3]
    }
		
    # This is a VERY rude ad hoc method of figuring out if the
    # server has a conference component.
    if {($name == "conference") && ($version != "1.0") && ($version != "1.1")} {
	set jstate(conference,$confjid) 1
	set jstate(groupchatprotocol,$confjid) "conference"
    } elseif {[string match -nocase "*mu*" $name]} {
	set jstate(groupchatprotocol,$confjid) "muc"
    }
}
    
# Jabber::ParseGetVersion --
#
#       Respond to an incoming 'jabber:iq:version' get query.

proc ::Jabber::ParseGetVersion {jlibname from subiq args} {
    global  prefs tcl_platform
    variable jstate
    
    ::Jabber::Debug 2 "Jabber::ParseGetVersion args='$args'"
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    lappend opts -to $from
   
    set os $tcl_platform(os)
    if {[info exists tcl_platform(osVersion)]} {
	append os " $tcl_platform(osVersion)"
    }
    set version $prefs(majorVers).$prefs(minorVers).$prefs(releaseVers)
    set subtags [list  \
      [wrapper::createtag name    -chdata "Coccinella"]  \
      [wrapper::createtag version -chdata $version]      \
      [wrapper::createtag os      -chdata $os]]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist {xmlns jabber:iq:version}]
     eval {$jstate(jlib) send_iq "result" $xmllist} $opts

    # Tell jlib's iq-handler that we handled the event.
    return 1
}
            
# Jabber::ParseGetBrowse --
#
#       Respond to an incoming 'jabber:iq:browse' get query.
#       
# Results:
#       boolean (0/1) telling if this was handled or not.

proc ::Jabber::ParseGetBrowse {jlibname from subiq args} {
    global  prefs    
    variable jstate
    variable privatexmlns

    ::Jabber::Debug 2 "::Jabber::ParseGetBrowse: args='$args'"
    
    array set argsArr $args
    if {![info exists argsArr(-from)]} {
	return 0
    }
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }

    # List everything this client supports. Starting with public namespaces.
    set subtags [list  \
      [wrapper::createtag "ns" -chdata "jabber:client"]         \
      [wrapper::createtag "ns" -chdata "jabber:iq:browse"]      \
      [wrapper::createtag "ns" -chdata "jabber:iq:conference"]  \
      [wrapper::createtag "ns" -chdata "jabber:iq:last"]        \
      [wrapper::createtag "ns" -chdata "jabber:iq:oob"]         \
      [wrapper::createtag "ns" -chdata "jabber:iq:roster"]      \
      [wrapper::createtag "ns" -chdata "jabber:iq:time"]        \
      [wrapper::createtag "ns" -chdata "jabber:iq:version"]     \
      [wrapper::createtag "ns" -chdata "jabber:x:data"]         \
      [wrapper::createtag "ns" -chdata "jabber:x:event"]        \
      [wrapper::createtag "ns" -chdata "coccinella:wb"]]
    
    # Adding private namespaces.
    foreach {key ns} [array get privatexmlns] {
	lappend subtags [wrapper::createtag "ns" -chdata $ns]
    }
    
    set attr [list xmlns jabber:iq:browse jid $jstate(mejidres)  \
      type client category user]
    set xmllist [wrapper::createtag "item" -subtags $subtags -attrlist $attr]
    eval {$jstate(jlib) send_iq "result" $xmllist -to $argsArr(-from)} $opts
    
    # Tell jlib's iq-handler that we handled the event.
    return 1
}

# Jabber::ParseGetServers --
# 
#       Sends something like:
#       <iq type='result' id='1012' to='matben@jabber.dk/coccinella'>
#           <query xmlns='http://coccinella.sourceforge.net/protocols/servers'>
#                <ip protocol='putget' port='8235'>212.214.113.57</ip>
#                <ip protocol='http' port='8077'>212.214.113.57</ip>
#            </query>
#       </iq>
#       

proc ::Jabber::ParseGetServers  {jlibname from subiq args} {
    global  prefs
    
    variable jstate
    variable privatexmlns
    
    # Build tag and attributes lists to 'private_set'.
    set ip [::Network::GetThisOutsideIPAddress]
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    lappend opts -to $from
    
    set attrputget [list protocol putget port $prefs(thisServPort)]
    set attrhttpd  [list protocol http port $prefs(httpdPort)]
    set subtags [list  \
      [wrapper::createtag ip -chdata $ip -attrlist $attrputget]  \
      [wrapper::createtag ip -chdata $ip -attrlist $attrhttpd]]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist [list xmlns $privatexmlns(servers)]]
     eval {$jstate(jlib) send_iq "result" $xmllist} $opts
    
     # Tell jlib's iq-handler that we handled the event.
    return 1
}

# Jabber::SetSendState --
#
#       Set from the checkbutton.

proc ::Jabber::SetSendState {wtop state} {    
    variable jstate

    set jstate($wtop,doSend) $state
}

proc ::Jabber::GetSendState {wtop} {    
    variable jstate

    return $jstate($wtop,doSend)
}

# The ::Jabber::WB:: namespace -------------------------------------------------

namespace eval ::Jabber::WB:: {
   
}

# Jabber::WB::NewWhiteboard --
#
#       Starts a new whiteboard session.
#       
# Arguments:
#       jid         jid, usually 3-tier, but should be 2-tier if groupchat.
#       args        -thread, -from, -to, -type, -x
#       
# Results:
#       $wtop; may create new toplevel whiteboard

proc ::Jabber::WB::NewWhiteboard {jid args} {
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::WB::NewWhiteboard jid=$jid, args='$args'"
    
    array set argsArr $args    
    
    # Make a fresh whiteboard window. Use any -type argument.
    # Note that the jid can belong to a room but we may still have a p2p chat.
    #    jid is room: groupchat live
    #    jid is ordinary available user: chat
    #    jid is ordinary but unavailable user: normal message
    jlib::splitjid $jid jid2 res
    set isRoom 0
    if {[info exists argsArr(-type)]} {
	if {[string equal $argsArr(-type) "groupchat"]} {
	    set isRoom 1
	}
    } elseif {[$jstate(jlib) service isroom $jid2]} {
	set isRoom 1
    }
    set isAvailable [$jstate(roster) isavailable $jid]
    
    ::Jabber::Debug 2 "\tisRoom=$isRoom, isAvailable=$isAvailable"
    
    if {$isRoom} {
	
	# Must enter room in the usual way if not there already.
	set allRooms [$jstate(jlib) service allroomsin]
	::Jabber::Debug 3 "\tallRooms=$allRooms"
	
	if {[lsearch $allRooms $jid] < 0} {
	    set ans [::Jabber::GroupChat::EnterOrCreate \
	      enter -roomjid $jid -autoget 1]
	    if {$ans == "cancel"} {
		return
	    }
	}
	set roomName [$jstate(browse) getname $jid]    
	if {[llength $roomName]} {
	    set title "Groupchat room $roomName"
	} else {
	    set title "Groupchat room $jid"
	}
	set wbOpts [list -type groupchat -title $title -jid $jid \
	  -toentrystate disabled -sendbuttonstate disabled \
	  -serverentrystate disabled]
	set sendLive 1
    } elseif {$isAvailable} {
	if {[info exists argsArr(-thread)]} {
	    set threadID $argsArr(-thread)
	} else {
	    
	    # Make unique thread id.
	    set threadID [::sha1pure::sha1 "$jstate(mejid)[clock seconds]"]
	}
	set name [$jstate(roster) getname $jid]
	if {[string length $name]} {
	    set title "Chat with $name"
	} else {
	    set title "Chat with $jid"
	}
	set wbOpts [list -type chat -thread $threadID -title $title  \
	  -toentrystate disabled -jid $jid -sendbuttonstate disabled  \
	  -serverentrystate disabled]
	set sendLive 1
    } else {
	set name [$jstate(roster) getname $jid]
	if {[string length $name]} {
	    set title "Send Message to $name"
	} else {
	    set title "Send Message to $jid"
	}
	set wbOpts [list -type normal -title $title -jid $jid  \
	  -toentrystate disabled -serverentrystate disabled]
	set sendLive 0
    }
    
    set wtop [eval {::WB::NewWhiteboard} $wbOpts]
    set jstate($wtop,doSend) $sendLive
    
    return $wtop
}

# ::Jabber::WB::ChatMsg, GroupChatMsg --
# 
#       Handles incoming chat/groupchat message aimed for a whiteboard.
#       It may not exist, for instance, if we receive a new chat thread.
#       Then create a specific whiteboard for this chat/groupchat.
#       
# Arguments:
#       args        -from, -to, -type, -thread,...

proc ::Jabber::WB::ChatMsg {args} {    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    ::Jabber::Debug 2 "::Jabber::WB::ChatMsg args='$args'"
    
    jlib::splitjid $argsArr(-from) jid2 res

    # This one returns empty if not exists.
    set wtop [::WB::GetWtopFromJabberType "chat" $argsArr(-from)  \
      $argsArr(-thread)]
    if {$wtop == ""} {
	set wtop [eval {::Jabber::WB::NewWhiteboard $argsArr(-from)} $args]
    }
    foreach line $argsArr(-whiteboard) {
	eval {ExecuteClientRequest $wtop $jstate(sock) ip port $line} $args
    }     
}

proc ::Jabber::WB::GroupChatMsg {args} {    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    ::Jabber::Debug 2 "::Jabber::WB::GroupChatMsg args='$args'"
    
    # The -from argument is either the room itself, or usually a user in
    # the room.
    if {![regexp {(^[^@]+@[^/]+)(/.*)?} $argsArr(-from) match roomjid]} {
	return -code error "The jid we got \"$argsArr(-from)\" was not well-formed!"
    }
    set wtop [::WB::GetWtopFromJabberType "groupchat" $roomjid]
    if {$wtop == ""} {
	set wtop [eval {::Jabber::WB::NewWhiteboard $roomjid} $args]
    }
    foreach line $argsArr(-whiteboard) {
	eval {ExecuteClientRequest $wtop $jstate(sock) ip port $line} $args
    } 
}

# Jabber::WB::MakeWhiteboardExist --
# 
#       Verifies that there exists a whiteboard for this message.
#       
# Arguments:
#       opts
#       
# Results:
#       $wtop; may create new toplevel whiteboard

proc ::Jabber::WB::MakeWhiteboardExist {opts} {

    array set optArr $opts
    
    ::Jabber::Debug 2 "::Jabber::WB::MakeWhiteboardExist"

    switch -- $optArr(-type) {
	chat {
	    set wtop [::WB::GetWtopFromJabberType chat $optArr(-from) \
	      $optArr(-thread)]
	    if {$wtop == ""} {
		set wtop [::Jabber::WB::NewWhiteboard $optArr(-from)  \
		  -thread $optArr(-thread)]
	    }
	}
	groupchat {
	    if {![regexp {(^[^@]+@[^/]+)(/.*)?} $optArr(-from) match roomjid]} {
		return -code error  \
		  "The jid we got \"$optArr(-from)\" was not well-formed!"
	    }
	    set wtop [::WB::GetWtopFromJabberType groupchat $optArr(-from)]
	    if {$wtop == ""} {
		set wtop [::Jabber::WB::NewWhiteboard $roomjid]
	    }
	}
	default {
	    # Normal message. Shall go in inbox ???????????
	    set wtop [::WB::GetWtopFromJabberType normal $optArr(-from)]
	}
    }
    return $wtop
}

# ::Jabber::WB::DispatchToImporter --
# 
#       Is called as a response to a GET file event. 
#       We've received a file that should be imported somewhere.
#       
# Arguments:
#       mime
#       opts
#       args        -file, -where; for importer proc.

proc ::Jabber::WB::DispatchToImporter {mime opts args} {
        
    ::Jabber::Debug 2 "::Jabber::WB::DispatchToImporter"

    array set optArr $opts

    # Creates WB if not exists.
    set wtop [::Jabber::WB::MakeWhiteboardExist $opts]

    switch -- $optArr(-type) {
	chat - groupchat {
	    set display 1
	}
	default {
	    set display 0
	}
    }
    
    if {$display && [::Plugins::HaveImporterForMime $mime]} {
	set wCan [::UI::GetCanvasFromWtop $wtop]
	eval {::Import::DoImport $wCan $opts} $args
    }
}

# The ::Jabber::Passwd:: namespace -------------------------------------------

namespace eval ::Jabber::Passwd:: {

    variable password
}

# Jabber::Passwd::Build --
#
#       Sets new password.
#
# Arguments:
#       
# Results:
#       "cancel" or "set".

proc ::Jabber::Passwd::Build { } {
    global  this wDlgs
    
    variable finished -1
    variable password
    variable validate
    upvar ::Jabber::jstate jstate
    
    set w $wDlgs(jpasswd)
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w [::msgcat::mc {New Password}]
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] \
      -fill both -expand 1 -ipadx 12 -ipady 4
    set password ""
    set validate ""
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.ll -font $fontSB -text [::msgcat::mc janewpass]
    label $frmid.le -font $fontSB -text $jstate(mejid)
    label $frmid.lserv -text "[::msgcat::mc {New password}]:" -anchor e
    entry $frmid.eserv -width 18 -show *  \
      -textvariable [namespace current]::password -validate key  \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    label $frmid.lvalid -text "[::msgcat::mc {Retype password}]:" -anchor e
    entry $frmid.evalid -width 18 -show * \
      -textvariable [namespace current]::validate -validate key  \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    grid $frmid.ll -column 0 -row 0 -sticky e
    grid $frmid.le -column 1 -row 0 -sticky w
    grid $frmid.lserv -column 0 -row 1 -sticky e
    grid $frmid.eserv -column 1 -row 1 -sticky w
    grid $frmid.lvalid -column 0 -row 2 -sticky e
    grid $frmid.evalid -column 1 -row 2 -sticky w
    pack $frmid -side top -fill both -expand 1

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [::msgcat::mc Set] -default active \
      -command [list [namespace current]::Doit $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]   \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btok invoke"
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "set"}]
}

proc ::Jabber::Passwd::Cancel {w} {
    variable finished
    
    set finished 0
    destroy $w
}

# Jabber::Passwd::Doit --
#
#       Initiates a register operation. Must be connected already!
#
# Arguments:
#       
# Results:
#       .

proc ::Jabber::Passwd::Doit {w} {
    global  errorCode prefs

    variable validate
    variable password
    variable finished
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Jabber::Debug 2 "::Jabber::Passwd::Doit"

    if {![string equal $validate $password]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox [::msgcat::mc jamesspasswddiff]]
	return
    }
    set finished 1
    regexp -- {^([^@]+)@.+$} $jstate(mejid) match username
    $jstate(jlib) register_set $username $password \
      [list [namespace current]::ResponseProc] -to $jserver(this)
    destroy $w

    # Just wait for a callback to the procedure.
}

proc ::Jabber::Passwd::ResponseProc {jlibName type theQuery} {    
    variable password
    upvar ::Jabber::jstate jstate

    if {[string equal $type "error"]} {
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	set msg 
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox  \
	  [::msgcat::mc jamesspasswderr $errcode $errmsg]] \
    } else {
		
	# Make sure the new password is stored in our profiles.
	set name [::Profiles::FindProfileNameFromJID $jstate(mejid)]
	if {$name != ""} {
	    set spec [::Profiles::GetProfile $name]
	    if {[llength $spec] > 0} {
		lset spec 2 $password
		eval {::Profiles::Set {}} $spec
	    }
	}
	tk_messageBox -title [::msgcat::mc {New Password}] -icon info -type ok \
	  -message [FormatTextForMessageBox [::msgcat::mc jamesspasswdok]]
    }
}

# Jabber::VerifyJIDWhiteboard --
#
#       Validate entry for jid.
#       
# Arguments:
#       jid     username@server
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::VerifyJIDWhiteboard {wtop} {

    upvar ::Jabber::jstate jstate
    
    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    set jid $jstate($wtop,tojid)
    if {$jstate($wtop,doSend)} {
	if {![::Jabber::IsWellFormedJID $jid]} {
	    tk_messageBox -icon warning -type ok -parent $w -message  \
	      [FormatTextForMessageBox [::msgcat::mc jamessinvalidjid]]
	    return 0
	}
    }
    return 1
}

# Jabber::LoginLogout --
# 
#       Toggle login/logout. Useful for binding in menu.

proc ::Jabber::LoginLogout { } {
    
    ::Jabber::Debug 2 "::Jabber::LoginLogout"
    if {[::Jabber::IsConnected]} {
	::Jabber::DoCloseClientConnection
    } else {
	::Jabber::Login::Login
    }    
}

# The ::Jabber::Logout:: namespace ---------------------------------------------

namespace eval ::Jabber::Logout:: { }

proc ::Jabber::Logout::WithStatus { } {
    global  prefs this wDlgs

    variable finished -1
    variable status ""
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Logout::WithStatus"

    set w $wDlgs(joutst)
    if {[winfo exists $w]} {
	return
    }
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w {Logout With Message}
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]  \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    ::headlabel::headlabel $w.frall.head -text {Logout}
    pack $w.frall.head -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill both -expand 1
    
    label $frmid.lstat -text "Status:" -font $fontSB -anchor e
    entry $frmid.estat -width 36  \
      -textvariable [namespace current]::status
    grid $frmid.lstat -column 0 -row 1 -sticky e
    grid $frmid.estat -column 1 -row 1 -sticky w
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btout -text [::msgcat::mc Logout] -width 8 \
      -default active -command [list [namespace current]::DoLogout $w]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command [list [namespace current]::DoCancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    ::UI::SetWindowPosition $w
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btout invoke"
    
    # Grab and focus.
    set oldFocus [focus]
    focus $frmid.estat
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    # Clean up.
    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "logout"}]
}

proc ::Jabber::Logout::DoCancel {w} {
    variable finished
    
    set finished 0
    destroy $w
}

proc ::Jabber::Logout::DoLogout {w} {
    variable finished
    variable status
    upvar ::Jabber::jstate jstate
    
    set finished 1
    destroy $w
    ::Jabber::DoCloseClientConnection -status $status
}


#-------------------------------------------------------------------------------
