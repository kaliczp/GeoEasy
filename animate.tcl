#
#	Initialize animation of earth
#	@param rw name of top level window
#	@return none
proc init_animate {rw} {
    global animate geoEasyMsg
	global tcl_platform
	global home

	set bmdir [file join $home bitmaps]
	set fn1 [file join $bmdir logo.gif]
	if {[file exists $fn1] == 0} {
		tk_dialog .msg $geoEasyMsg(warning) "$geoEasyMsg(image) $fn1" \
			warning 0 OK
		return
	}
	set fn2 [file join $bmdir pwrdLogo.gif]
	if {[file exists $fn2] == 0} {
		tk_dialog .msg $geoEasyMsg(warning) "$geoEasyMsg(image) $fn2" \
			warning 0 OK
		return
	}

	# check existance of image files
	for {set i 0} {$i < 30} {incr i} {
		set fn [file join $bmdir globe_]
		append fn [format %02d $i] .bmp
		if {[file exists $fn] == 0} {
			tk_dialog .msg $geoEasyMsg(warning) "$geoEasyMsg(image) $fn" \
				warning 0 OK
			return
		}
		set imgName [format "globe_%02d" $i]
		image create bitmap $imgName -file $fn \
			-maskfile [file join $bmdir gmask.bmp] \
			-foreground green -background blue
	}

	set animate(curBitmap) 0
	set animate(lastBitmap) 0

	if {$rw != "."} {
		set t $rw
	} else {
		set t ""
	}
	label $t.b -image globe_00
	image create photo f1 -file $fn1
	image create photo f2 -file $fn2
	label $t.l -image f1 -relief sunken -borderwidth 2
	label $t.tk -image f2
	if {$tcl_platform(platform) != "unix"} {
		pack $t.b $t.l -side left -pady 3 -padx 5
		pack $t.tk -side right -pady 3 -padx 5
	} else {
		pack $t.b $t.l -side left -pady 2 -padx 8
		pack $t.tk -side right -pady 2 -padx 8
	}
	Animate $t.b on
}

#
#	Turn on/off animation
#	@param w widget name
#	@param option on/off
#	@return none
proc Animate {w option} {
    global animate

    switch -exact $option {
		on {
			set animate(curBitmap) $animate(lastBitmap) 
			update
		} 
		off {
			set animate(lastBitmap) $animate(curBitmap)
			set animate(curBitmap) -1 
		}
    }
    #
    # Continue with next bitmap
    #
    if { $animate(curBitmap) >= 0 } {
		set bmap [format globe_%0.2d $animate(curBitmap)] 
		catch "$w configure -image $bmap"
		incr animate(curBitmap)
		if { $animate(curBitmap) >= 29 } {
			set animate(curBitmap) 0
		}
		after 100 Animate $w continue
    }
}
