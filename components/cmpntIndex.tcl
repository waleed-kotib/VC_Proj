# See contrib/component.tcl for explanations.
#

component::attempt AppleEvents  [file join $dir AppleEvents.tcl] ::AppleEvents::Init
component::attempt AutoUpdate   [file join $dir AutoUpdate.tcl]  ::AutoUpdate::Init
component::attempt BuddyPounce  [file join $dir BuddyPounce.tcl] ::BuddyPounce::Init
component::attempt TtkDialog    [file join $dir TtkDialog.tcl]   ::TtkDialog::Init
component::attempt GnomeMeeting [file join $dir GMeeting.tcl]    ::GMeeting::Init
component::attempt ICQ          [file join $dir ICQ.tcl]         ::ICQ::Init
component::attempt ImageMagic   [file join $dir ImageMagic.tcl]  ::ImageMagic::Init
component::attempt JivePhone    [file join $dir JivePhone.tcl]   ::JivePhone::Init
component::attempt MailtoURI    [file join $dir MailtoURI.tcl]   ::MailtoURI::Init
component::attempt Mood         [file join $dir Mood.tcl]        ::Mood::Init
component::attempt Notifier     [file join $dir Notifier.tcl]    ::Notifier::Init
component::attempt NotifyOnline [file join $dir NotifyOnline.tcl] ::NotifyOnline::Init
component::attempt ParseMeCData [file join $dir ParseMeCData.tcl] ::ParseMeCData::Init
component::attempt ParseStyledText [file join $dir ParseStyledText.tcl] ::ParseStyledText::Init
component::attempt ParseURI     [file join $dir ParseURI.tcl]    ::ParseURI::Init
component::attempt SlideShow    [file join $dir SlideShow.tcl]   ::SlideShow::Load  
component::attempt Sounds       [file join $dir Sounds.tcl]      ::Sounds::Load    
component::attempt Speech       [file join $dir Speech.tcl]      ::Speech::Load    
component::attempt SpotLight    [file join $dir SpotLight.tcl]   ::SpotLight::Init    
component::attempt URIRegistry  [file join $dir URIRegistry.tcl] ::URIRegistry::Init
component::attempt WhiteboardMK [file join $dir WhiteboardMK.tcl]  ::WhiteboardMK::Init

if {[tk windowingsystem] eq "aqua"} {
    component::attempt Carbon       [file join $dir Carbon.tcl]      ::Carbon::Init
    component::attempt Growl        [file join $dir Growl.tcl]       ::Growl::Init
}

# This is just an example plugin. Uncomment to test.
# component::attempt ComponentExample [file join $dir ComponentExample.tcl] ::ComponentExample::Init
