# ComponentExample.tcl --
# 
#       Demo of some of the functionality for components.
#       This is just a first sketch.

namespace eval ::ComponentExample:: {
    
}

proc ::ComponentExample::Init { } {

    ::Debug 2 "::ComponentExample::Init"
    
    set menuspec {
	command {More Junk...} ::ComponentExample::Cmd  {} {}
    }
    set mDef [list command "Plugin Junk" [namespace current]::Cmd]
    set mType {"Plugin Junk" user}
    
    ::WB::RegisterNewMenu junk "Mats Junk" $menuspec
    ::WB::RegisterMenuEntry file $menuspec
    ::JUI::RegisterMenuEntry action $menuspec
    ::JUI::RegisterMenuEntry file $menuspec
    ::Roster::RegisterPopupEntry $mDef $mType
    
    ::hooks::register jabberInitHook  ::ComponentExample::JabberInitHook

    component::register ComponentExample  \
      "This is justa dummy example of the component mechanism."
}

proc ::ComponentExample::JabberInitHook {jlibname} {
    
    set xmlnsj "http://jabber.org/protocol/jingle"
    set subtags [list [wrapper::createtag "feature" \
      -attrlist [list var $xmlnsj]]]    
    $jlibname caps register jingle $subtags $xmlnsj
}

proc ::ComponentExample::Cmd { } {    

    tk_messageBox -type yesno -icon info -title "Component Example" \
      -message "Hi, do you expect more fun than this?" 
}

#-------------------------------------------------------------------------------
