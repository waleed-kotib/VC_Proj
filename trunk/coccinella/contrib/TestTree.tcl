package require tree::tree::tree .t1 -width 150 -height 300 -styleicons triangle -treecolor black  \  -yscrollcommand {.sb1 set} -selectcommand SelectCmd -sortorder decreasing  \  -highlightcolor #6363CE -highlightbackground gray87   \  -doubleclickcommand DoubleClickCmd -opencommand OpenCmd  \  -rightclickcommand RightClickCmd -buttonpresscommand PressedCmd  \  -eventlist {{<Control-Button-1> RightClickCmd}}scrollbar .sb1 -orient vertical -command {.t1 yview}pack .sb1 -side right -fill ypack .t1 -side right -fill both -expand 1::tree::tree .t2 -width 150 -height 300 -background white -pyjamascolor {}  \  -yscrollcommand {.sb2 set} -silent 1scrollbar .sb2 -orient vertical -command {.t2 yview}pack .sb2 -side right -fill ypack .t2 -fill both -expand 1foreach w {.t1 .t2} dirim [list $::tree::folderimmac $::tree::idir]   \  fileim [list $::tree::fileimmac $::tree::ifile] {    foreach z {1 2 3} {	$w newitem [list dir$z] -image $dirim	foreach x {1 2 3 4 5} {	    $w newitem [list dir$z file$x] -image $fileim -tags t$x$z	}	$w newitem [list dir$z subdir] -image $dirim -text {Text not item}	foreach y {1 2} {	    $w newitem [list dir$z subdir file$y] -tags xxx -image $fileim -style italic	}	foreach zz {1 2 3} {	    $w newitem [list dir$z subdir ssdir$zz] -image $dirim -text2 {Mats Be}	    $w newitem [list dir$z subdir ssdir$zz file1]  ;# No icon!	    $w newitem [list dir$z subdir ssdir$zz file2] -image $fileim	}    }}.t1 itemconfigure {dir3 subdir ssdir2 file1} -background gray70.t2 itemconfigure {dir1 subdir ssdir1 file1} -background lightblueproc SelectCmd {w v} {    puts "SelectCmd: w=$w, v='$v'"}proc DoubleClickCmd {w v} {    puts "DoubleClickCmd: w=$w, v='$v'"}proc RightClickCmd {w v x y} {    puts "RightClickCmd w=$w, v='$v'"}proc PressedCmd {w v x y} {    puts "PressedCmd w=$w, v='$v', x=$x, y=$y"}proc OpenCmd {w v} {    puts "OpenCmd: w=$w, v='$v'"}