# ComponentExample.tcl --
# 
#       Demo of some of the functionality for components.
#       This is just a first sketch.

namespace eval ::ComponentExample:: {
    
}

proc ::ComponentExample::Init { } {

    ::Debug 2 "::ComponentExample::Init"
    
    set menuspec [list  \
      command {More Junk...} [namespace current]::Cmd normal {} {} {}]
    set popMenuSpec [list "Plugin Junk" user [namespace current]::Cmd]
    
    ::hooks::register whiteboardFixMenusWhenHook [namespace current]::FixMenu
    
    ::UI::Public::RegisterNewMenu junk "Mats Junk" $menuspec
    ::UI::Public::RegisterMenuEntry file $menuspec
    ::Jabber::UI::RegisterMenuEntry jabber $menuspec
    ::Jabber::UI::RegisterMenuEntry file $menuspec
    ::Roster::RegisterPopupEntry $popMenuSpec
    
    
    set xmlnsj "http://jabber.org/protocol/jingle"
    set subtags [list [wrapper::createtag "feature" \
	  -attrlist [list var $xmlnsj]]]
    ::Jabber::RegisterCapsExtKey jingle $subtags
    ::Jabber::AddClientXmlns $xmlnsj

    
    component::register ComponentExample  \
      "This is justa dummy example of the component mechanism."
}

proc ::ComponentExample::Cmd { } {    

    tk_messageBox -type yesno -icon info -title "Component Example" \
      -message "Hi, do you expect more fun than this?" 
}

proc ::ComponentExample::FixMenu {wmenu what} {   

    puts "::ComponentExample::FixMenu: wmenu=$wmenu, what=$what"
}

#-------------------------------------------------------------------------------