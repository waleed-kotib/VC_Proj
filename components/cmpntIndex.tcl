# See contrib/component.tcl for explanations.
#

component::attempt AutoUpdate   [file join $dir AutoUpdate.tcl]  ::AutoUpdate::Init
component::attempt BuddyPounce  [file join $dir BuddyPounce.tcl] ::BuddyPounce::Init
component::attempt ICQ          [file join $dir ICQ.tcl]         ::ICQ::Init
component::attempt ImageMagic   [file join $dir ImageMagic.tcl]  ::ImageMagic::Init
component::attempt ParseURI     [file join $dir ParseURI.tcl]    ::ParseURI::Init
component::attempt SlideShow    [file join $dir SlideShow.tcl]   ::SlideShow::Load  
component::attempt Sounds       [file join $dir Sounds.tcl]      ::Sounds::Load    
component::attempt Speech       [file join $dir Speech.tcl]      ::Speech::Load    

if {[string equal $::tcl_platform(platform) "windows"]} {
    component::attempt URIRegistry [file join $dir URIRegistry.tcl] ::URIRegistry::Init
}

# Problem to determine if app hidden or not!
if {[string equal $::tcl_platform(platform) "unix"] && [string equal [tk windowingsystem] "aqua"]} {
    #component::attempt CarbonNotification [file join $dir CarbonNotification.tcl] ::CarbonNotification::Init
}

# This is just an example plugin. Uncomment to test.
# component::attempt ComponentExample [file join $dir ComponentExample.tcl] ::ComponentExample::Init
