snit::widget ui::toplevel {
    hulltype toplevel
    widgetclass Xxx ; # @@@ ???

    delegate option -menu    to hull
    delegate option -padding to frm

    option -geovariable
    option -title
    option -closecommand
    option -alpha        -default 1.0  \
      -configuremethod OnConfigAlpha
    
    constructor {args} {
	$self configurelist $args

	$self OnConfigAlpha -alpha $options(-alpha)
	if {[string length $options(-geovariable)]} {
	    ui::PositionClassWindow $win $options(-geovariable) "FontSelector"
	} 
	return
    }
    
    destructor {
	if {[string length $options(-closecommand)]} {
	    set code [catch {uplevel #0 $options(-closecommand)}]

	    # @@@ Can we stop destruction ???
	}
    }
    
    method OnConfigAlpha {option value} {
	array set attr [wm attributes $win]
	if {[info exists attr(-alpha)]} {
	    after idle [list wm attributes $win -alpha $value]
	}
	set options($option) $value
    }
}

#-------------------------------------------------------------------------------
