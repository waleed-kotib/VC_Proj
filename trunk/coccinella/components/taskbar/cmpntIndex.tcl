# See contrib/component.tcl for explanations.
#

if {$::tcl_platform(platform) == "windows"} {
    component::attempt Taskbar [file join $dir Taskbar.tcl] ::Taskbar::Load    
}
