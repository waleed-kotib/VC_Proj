# See contrib/component.tcl for explanations.
#

component::attempt IAX        [file join $dir Iax.tcl] ::Iax::Init
component::attempt JingleIAX  [file join $dir JingleIax.tcl] ::JingleIAX::Init
