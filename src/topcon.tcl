#
# Copyright (C) 2017 Zoltan Siki siki1958 (at) gmail (dot) com
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#	Read in TopCon GTS-700 Raw File Format
#
#	22 different records
#	GTS-700 vn.m	file version
#	JOB		job_name,description
#	DATE	date,time		example:14/09/99,10:54:16
#	NAME	surveyer's name
#	INST	instrument_id
#	UNITS	Meter/Feet,Degree/Gon		example:M,D
#	SCALE	grid_factor,scale_factor,elevation ???
#	ATMOS	temp,press
#	STN		ptno,instrument_height,station_id
#	XYZ		easting,northing,elevation
#	BKB		ptno,backsight_bearing,backsight_angle ???
#	BS		ptno[,target_height]
#	FS		ptno,target_height,pt_code[,string_number]
#	SS		ptno,target_height,pt_code[,string_number]
#	CTL		control_code[,pt_code2[,string_no2]]
#	HV		horizontal_angle,vertical_angle
#	SD		horizontal_angle,vertical_angle,slope_distance
#	HD		horizontal_angle,horizontal_distance,vertical_distance
#	OFFSET	radial_offset,tangential_offset,vertical_offset
#	PTL_OFF	offset_alog_reference_line,offset perpendicular_to_line,
#			vertical offset
#	NOTE	comment
#	MLM		from_point,to_point,delta_HD,delta_VD,delta_SD
#
#   RES_OBS free station obs. GPT-7000 skip
# Remarks
#	XYZ if present follows the STN record
#	BKB if present follows the XYZ or STN record
#	CTL if present follows the FS or SS header record
#	HV, SD, HD must follow a BS, FS or SS header and follows the CTL if present
#	OFFSET may follow any SD or HD record
#	@param fn path to of GTS-700 file
#	@param fa internal name of dataset
#	@return non-zero on error
proc TopCon {fn fa} {
	global reg
	global FOOT2M
	global geoEasyMsg geoCodes

	if {[string length $fa] == 0} {return -1}
	global ${fa}_geo ${fa}_coo ${fa}_ref ${fa}_par
	if {[catch {set f1 [open $fn r]}] != 0} {
		return -1       ;# cannot open input file
	}
	set lines 0             ;# number of lines in output
	set src 0               ;# input line number
	set angle_unit "D"		;# default angle unit DMS
	set dist_unit "M"		;# default distance unit M
	set obuf ""             ;# output buffer
	set ${fa}_par ""
	set last ""
	set res_obs_buf ""		;# observations from free station
	set pcode ""
    set stn ""              ;# last station id

	while {! [eof $f1]} {
		incr src	;# source line number
		if {[gets $f1 buf] == 0} continue
		set buf [string trim $buf]
		set code [string trim [string toupper [string range $buf 0 6]]]
		set buflist [split [string range $buf 8 end] ","]  ;# comma separated
		set n [llength $buflist]
		if {$n == 0} continue       ;# empty line

		switch -exact $code {
			GTS-700 {
#				lappend ${fa}_par [list 0 $buf]
			}
			JOB {
				# store job name in remark field
				lappend ${fa}_par [list 0 [lindex $buflist 0]]
			}
			DATE {
				lappend ${fa}_par [list 51 [lindex $buflist 0]]
				lappend ${fa}_par [list 52 [lindex $buflist 1]]
			}
			NAME {
				lappend ${fa}_par [list 53 [lindex $buflist 0]]
			}
			INST {
				lappend ${fa}_par [list 55 [lindex $buflist 0]]
			}
			UNITS {
				set dist_unit [lindex $buflist 0]
				set angle_unit [lindex $buflist 1]
			}
			SCALE {
			}
			ATMOS {
			}
			XYZ {
				# store coordinates
				AddCoo $fa $pn [lindex $buflist 0] [lindex $buflist 1] \
					[lindex $buflist 2] $pcode
			}
			STN -
			BKB -
			RES_OBS -
			BS -
			FS -
			SS {
				if {[llength $obuf] > 1 || [GetVal 2 $obuf] != ""} {
					foreach l $obuf {
						if {[lsearch -exact \
							{3 6 7 8 9 10 11 21 24 25 26 27 28 29 37 38 39 49} \
							[lindex $l 0]] != -1 && \
							[regexp $reg(2) [lindex $l 1]] == 0} {
							return $src
						}
					}
					if {$last == "RES_OBS"} {
						lappend res_obs_buf $obuf
					} else {
						set face2 0
						if {[string length [GetVal 2 $obuf]] == 0} {
							set li [expr {$lines - 1}]
							# look for the same point number in this station
							while {$li> 0} {
								if {[string length [GetVal 2 [set ${fa}_geo($li)]]] != 0} {
									break
								}
								if {[GetVal 5 [set ${fa}_geo($li)]] == $pn} {
									# really second face?
									set obuf1 [set ${fa}_geo($li)]
									set avgbuf [AvgFaces $obuf1 $obuf]
									if {[llength $avgbuf]} {
										set face2 1
										break
									} else {
										GeoLog1 [format $geoEasyMsg(noface2) $pn]
									}
								}
								incr li -1
							}
						}
						if {$face2} {
							#store average for 2 faces
							set ${fa}_geo($li) $avgbuf
						} else {
							set ${fa}_geo($lines) $obuf
							if {[info exists ${fa}_ref($pn)] == -1} {
								set ${fa}_ref($pn) $lines
							} else {
								lappend ${fa}_ref($pn) $lines
							}
							incr lines
						}
					}
				}
				set obuf ""
				set pcode ""
				set pn [lindex $buflist 0]
				switch -exact $code {
					STN {
                        set stn $pn
						lappend obuf [list 2 $pn]   ;# station name
						GeoLog1 "$geoCodes(2): $pn"
						lappend obuf [list 3 [lindex $buflist 1]]   ;# station height
						if {[llength $buflist] > 2} {
							set pcode [lindex $buflist 2]
							lappend obuf [list 4 $pcode]    ;# pcode
						}
						set last $code
						if {[llength $res_obs_buf]} {
							set res_obs_buf [linsert $res_obs_buf 0 $obuf]
							foreach b $res_obs_buf {
								set ${fa}_geo($lines) $b
								set p [GetVal {5 2} $b]
								if {[info exists ${fa}_ref($p)] == -1} {
									set ${fa}_ref($p) $lines
								} else {
									lappend ${fa}_ref($p) $lines
								}
								incr lines
							}
							set res_obs_buf ""
						}
					}
					BKB {
                        if {[string length $pn] > 0} {  ;# skip without point id
                            lappend obuf [list 5 $pn]
                            if {$angle_unit == "G"} {
                                lappend obuf [list 21 [Gon2Rad [lindex $buflist 2]]]
                            } else {
                                lappend obuf [list 21 [Deg2Rad [lindex $buflist 2]]]
                            }
                            set last $code
                        }
					}
					RES_OBS -
					BS -
					FS -
					SS {
                        if { ! [string equal $stn $pn]} { ;# axis 10 adds station as target
                            lappend obuf [list 5 $pn]
                            if {[llength $buflist] > 1} {
                                lappend obuf [list 6 [lindex $buflist 1]]
                            }
                            if {[llength $buflist] > 2} {
                                set pcode [lindex $buflist 2]
                                lappend obuf [list 4 $pcode]	;# pcode
                            }
                        }
						set last $code
					}
				}
			}
			CTL {
			}
			HV {
				if {$angle_unit == "G"} {
					lappend obuf [list 7 [Gon2Rad [lindex $buflist 0]]]
					lappend obuf [list 8 [Gon2Rad [lindex $buflist 1]]]
				} else {
					lappend obuf [list 7 [Deg2Rad [lindex $buflist 0]]]
					lappend obuf [list 8 [Deg2Rad [lindex $buflist 1]]]
				}
			}
			SD {
				if {$angle_unit == "G"} {
					lappend obuf [list 7 [Gon2Rad [lindex $buflist 0]]]
					lappend obuf [list 8 [Gon2Rad [lindex $buflist 1]]]
				} else {
					lappend obuf [list 7 [Deg2Rad [lindex $buflist 0]]]
					lappend obuf [list 8 [Deg2Rad [lindex $buflist 1]]]
				}
				set dis [lindex $buflist 2]
				if {$dis > 0.001} {
					if {$dist_unit == "F"} {
						lappend obuf [list 9 [expr {[lindex $buflist 2] * $FOOT2M}]]
					} else {
						lappend obuf [list 9 [lindex $buflist 2]]
					}
				}
			}
			HD {
				if {$angle_unit == "G"} {
					lappend obuf [list 7 [Gon2Rad [lindex $buflist 0]]]
				} else {
					lappend obuf [list 7 [Deg2Rad [lindex $buflist 0]]]
				}
				if {$dist_unit == "F"} {
					lappend obuf [list 11 [expr {[lindex $buflist 1] * $FOOT2M}]]
					lappend obuf [list 10 [expr {[lindex $buflist 2] * $FOOT2M}]]
				} else {
					lappend obuf [list 11 [lindex $buflist 1]]
					lappend obuf [list 10 [lindex $buflist 2]]
				}
			}
			OFFSET {
			}
			PTL_OFF {
			}
			NOTE {
			}
			MLM {
			}
			default {
				# TBD unknown code
			}
		}
	}
	if {[llength $obuf] > 1 || [GetVal 2 $obuf] != ""} {
		foreach l $obuf {
			if {[lsearch -exact \
				{3 7 8 9 10 11 21 24 25 26 27 28 29 37 38 39 49} \
				[lindex $l 0]] != -1 && \
				[regexp $reg(2) [lindex $l 1]] == 0} {
				return $src
			}
		}
		set face2 0
		set li [expr {$lines - 1}]
		# look for the same point number in this station
		while {$li> 0} {
			if {[string length [GetVal 2 [set ${fa}_geo($li)]]] != 0} {
				break
			}
			if {[GetVal 5 [set ${fa}_geo($li)]] == $pn} {
				# really second face?
				set obuf1 [set ${fa}_geo($li)]
				set avgbuf [AvgFaces $obuf1 $obuf]
				if {[llength $avgbuf]} {
					set face2 1
					break
				} else {
					GeoLog1 [format $geoEasyMsg(noface2) $pn]
				}
			}
			incr li -1
		}
		if {$face2} {
			#store average for 2 faces
			set ${fa}_geo($li) $avgbuf
		} else {
			set ${fa}_geo($lines) $obuf
			if {[info exists ${fa}_ref($pn)] == -1} {
				set ${fa}_ref($pn) $lines
			} else {
				lappend ${fa}_ref($pn) $lines
			}
			incr lines
		}
	}
	close $f1
	return 0
}

#
#	Read in TopCon GTS-700 co-ordinate file
#	Record format:
#		point_number, Easting, Northing, Elevation, point code
#	@param fn path to GTS-700 co-ordinate file
#	@param fa internal name of dataset
#	@return non-zero on error
proc TopConCoo {fn fa} {
	global reg
	global geoEasyMsg

	if {[string length $fa] == 0} {return -1}
	global ${fa}_coo
	if {[catch {set f1 [open $fn r]}] != 0} {
		return -1       ;# cannot open input file
	}
	set lineno 0             ;# input line number
	while {! [eof $f1]} {
		incr lineno
		if {[gets $f1 buf] == 0} continue
		set buflist [split [string trim $buf] ","]  ;# coma separated
		set n [llength $buflist]
		if {$n == 0} { continue }   ;# empty line
		set obuf ""                 ;# output buffer
		set x ""
		set y ""
		set z ""
		set code ""
		set pn [lindex $buflist 0]
		if {[info exists ${fa}_coo($pn)] != 0} {
			geo_dialog .msg $geoEasyMsg(warning) "$geoEasyMsg(dblPn): $pn" \
				warning 0 OK
			continue
		}
		if {[llength $buflist] > 1} {
			set x [lindex $buflist 1]
			if {[regexp $reg(2) $x] == 0} { return $lineno }
			lappend obuf [list 37 $x]
		}
		if {[llength $buflist] > 2} {
			set y [lindex $buflist 2]
			if {[regexp $reg(2) $y] == 0} { return $lineno }
			lappend obuf [list 38 $y]
		}
		if {[llength $buflist] > 3} {
			set z [lindex $buflist 3]
			if {[regexp $reg(2) $z] == 0} { return $lineno }
			lappend obuf [list 39 $z]
		}
		if {[llength $buflist] > 4} {
			set code [lindex $buflist 4]
			lappend obuf [list 4 $code]
		}
		set ${fa}_coo($pn) $obuf
	}
	close $f1
	return 0
}

#
#	Convert number string with leading zeros to number
#	@param str number with sign and leading zeros e.g. -0000234
#	@param d number of decimals e.g. 3
#	@return a number (0.234) or empty string for 000000000 or invalid number
proc Txt2Coo {str {d 1}} {
	set w [string trim $str " +"]
	set s ""	;# sign
	if {[regexp "^-" $w]} {
		set s "-"
	}
	set w [string trimleft $w "0-+"]	;# remove leading 0 and sign
#	if {[string length $w] == 0 || [regexp "^\[0-9\]*$" $w] == 0} {return "0"}
	set m [string length $w]
	while {$m <= $d} {
		set w 0$w
		set m [string length $w]
	}
	set ww [string range $w 0 [expr {$m - $d - 1}]].[string range $w [expr {$m - $d}] end]
	return $s$ww
}

#
#	Read in TopCon 210 File Format
#	File structure
#	Station
#	_'station_(code)stationheight
#
#	Distance and angles
#	_+target_ ?+slopedistancemzenithangle+direction+horizontaldistance
#	tunknown+unknown_*code_,targetheight
#
#	Angles
#	_+target_ <zenithangle+direction+unknowndunknown_*code_,targetheight
#                                   -
#	Coordinates, distance and angles
#	_+target_ W+slopedistancemzenithangle+directiond+coord+coord+unknown
#	tunknown+unknown+unknown_*code_,targetheight
#
#	Coordinates (coordinates are zero padded left)
#	_+pointnumber   _ xxcoord_ yycoord_ zzcoord
#
#	Data sent in records record start is marked by ^B, record end is marked
#	by ^C, end of file marked ^D, record length is 135 bytes
#	There is a checksum (4 digit) before end of record (^C)
#	@param fn path to TopCon210 file
#	@param fa internal name of dataset
#	@return non-zero on error
proc TopCon210 {fn fa} {
	global reg
	global geoEasyMsg
	global geoCodes

	if {[string length $fa] == 0} {return -1}
	global ${fa}_geo ${fa}_coo ${fa}_ref ${fa}_par
	if {[catch {set f1 [open $fn r]}] != 0} {
		return -1       ;# cannot open input file
	}
	set lines 0             ;# number of lines in output
	set src 0               ;# input line number
	set obuf ""             ;# output buffer
	GeoLog1 $geoEasyMsg(face2)
	GeoLog1 $geoEasyMsg(face3)
	set ${fa}_par [list [list 55 "topcon 210"]]

	set buf ""
	while {![eof $f1]} {
		gets $f1 rbuf			;# get 1 row
		if {[string range $rbuf 0 0] == "\x02"} {
			# remove control chars and checksum
			set rbuf [string range $rbuf 1 128]
			append buf $rbuf
		} elseif {[string range $rbuf 0 0] == "_"} {
			# store only data lines
			append buf $rbuf
		}
	}
	close $f1
	set buf [string trimright $buf "\x04 "]
	set stlist [split $buf "'"]	;# separate stations
	set i 1
	foreach part $stlist {
		if {$part == "_" || $part == ""} { continue }
		set p [string first "_+" $part]	;# position of first target
		if {[string range $part 0 1] != "_+"} {
			# station data
			if {$p > 0} {
				set stbuf [string range $part 0 [expr {$p - 1}]]
			} else {
				set stbuf $part
			}
			set st [split $stbuf "_"]
			set pn [string trim [lindex $st 0] "_()"]
			set obuf [list [list 2 $pn] \
				[list 4 [string trim [lindex $st 1] "_()"]] \
				[list 3 [string trim [lindex $st 2] "_()"]]]
			GeoLog1 "$geoCodes(2): $pn"
			# check numerc values
			foreach l $obuf {
				if {[lsearch -exact \
						{3 6 7 8 9 10 11 21 24 25 26 27 28 29 37 38 39 49} \
						[lindex $l 0]] != -1 && \
						[regexp $reg(2) [lindex $l 1]] == 0} {
					return $lines
				}
			}
			set face2 0
			set pnum [GetVal 5 $obuf]
			if {$pnum == ""} {      ;# station
				GeoLog1 [format "%-10s" [string range [GetVal 2 $obuf] 0 9]]
			} else {
				set li [expr {$lines - 1}]
				# look for the same point number in this station
				while {$li> 0} {
					if {[string length [GetVal 2 [set ${fa}_geo($li)]]] != 0} {
						break
					}
					if {[GetVal 5 [set ${fa}_geo($li)]] == $pnum} {
						# really second face?
						set obuf1 [set ${fa}_geo($li)]
						set avgbuf [AvgFaces $obuf1 $obuf]
						if {[llength $avgbuf]} {
							set face2 1
						} else {
							GeoLog1 [format $geoEasyMsg(noface2) \
								[GetVal 5 $obuf]]
						}
						break
					}
					incr li -1
				}
			}
			if {$face2} {
				#store average for 2 faces
				set ${fa}_geo($li) $avgbuf
			} else {
				# new first face
				set ${fa}_geo($lines) $obuf
				if {[info exists ${fa}_ref($pn)] == -1} {
					set ${fa}_ref($pn) $lines
				} else {
					lappend ${fa}_ref($pn) $lines
				}
				incr lines
			}
		}
		while {$p != -1} {
			set obuf ""
			set part [string range $part [expr {$p + 2}] end]
			set p [string first "_+" $part]
			if {$p > -1} {
				set tbuf [string range $part 0 [expr {$p - 1}]]
			} else {
				set tbuf $part
			}
			if {[regexp "x.*y.*z" $tbuf]} {
				# coordinates only
				set tbuf [string trim $tbuf "_+ "]
				set t [split $tbuf "_"]
				set pn [string trim [lindex $t 0]]
				set x [string trim [lindex $t 1] "x +"]
				set x [Txt2Coo $x 3]
				set y [string trim [lindex $t 2] "y +"]
				set y [Txt2Coo $y 3]
				set z [string trim [lindex $t 3] "z +"]
				set z [Txt2Coo $z 3]
				if {$z == 0} {set z ""}
				AddCoo $fa $pn $y $x $z
				incr lines
			} elseif {[regexp {_ \?\+} $tbuf]} {
				# observations only
				set t [split $tbuf "?"]
				set pn [string trim [lindex $t 0] "_+ "]
				set obuf [list [list 5 $pn]]	;# target point
				set t [string trim [lindex $t 1] "_"]
				set w [string range $t 1 8]		;# slope distance
				set ww [Txt2Coo $w 3]
				if {$ww > 0.001} {
					lappend obuf [list 9 $ww]
				}
				set w [string range $t 10 16]	;# zenith
				set ww [Txt2Coo $w 4]
				lappend obuf [list 8 [Deg2Rad $ww]]
				set w [string range $t 18 24]	;# direction
				set ww [Txt2Coo $w 4]
				lappend obuf [list 7 [Deg2Rad $ww]]
				set q [string last "," $t]		;# code
				set w [string range $t 47 $q]
				set w [string trim $w "_*,"]
				if {[string length $w]} {
					lappend obuf [list 4 $w]
				}
				set w [string range $t [expr {$q + 1}] end]	;# target height
				lappend obuf [list 6 $w]
			} elseif {[regexp {_ \<} $tbuf]} {
				# orientation (no distance)
				set t [split $tbuf "<"]
				set pn [string trim [lindex $t 0] "_+ "]
				set obuf [list [list 5 $pn]]	;# target point
				set t [string trim [lindex $t 1] "_"]
				set w [string range $t 0 6]		;# zenith
				set ww [Txt2Coo $w 4]
				lappend obuf [list 8 [Deg2Rad $ww]]
				set w [string range $t 8 14]	;# direction
				set ww [Txt2Coo $w 4]
				lappend obuf [list 7 [Deg2Rad $ww]]
				set q [string last "," $t]		;# code
				set w [string range $t 24 $q]
				set w [string trim $w "_*,"]
				if {[string length $w]} {
					lappend obuf [list 4 $w]
				}
				set w [string range $t [expr {$q + 1}] end]	;# target height
				lappend obuf [list 6 $w]
			} elseif {[regexp {_ W\+} $tbuf]} {
				# observations and coords
				set t [split $tbuf W]
				set pn [string trim [lindex $t 0] "_+ "]
				set obuf [list [list 5 $pn]]	;# target point
				set t [string trim [lindex $t 1] "_"]
				set w [string range $t 1 8]		;# slope distance
				set ww [Txt2Coo $w 3]
				if {$ww > 0.001} {
					lappend obuf [list 9 $ww]
				}
				set w [string range $t 11 17]	;# zenith
				set ww [Txt2Coo $w 4]
				lappend obuf [list 8 [Deg2Rad $ww]]
				set w [string range $t 20 26]	;# direction
				set ww [Txt2Coo $w 4]
				lappend obuf [list 7 [Deg2Rad $ww]]
				set q [string last "," $t]		;# code
				set w [string range $t 77 $q]
				set w [string trim $w "_*,"]
				if {[string length $w]} {
					lappend obuf [list 4 $w]
				}
				set w [string range $t [expr {$q + 1}] end]	;# target height
				lappend obuf [list 6 $w]
				set w [string range $t 29 38]	;# north
				set y [Txt2Coo $w 3]
				set w [string range $t 40 49]	;# east
				set x [Txt2Coo $w 3]
				set w [string range $t 51 60]	;# elev
				set z [Txt2Coo $w 3]
				AddCoo $fa $pn $x $y $z
			} else {
				geo_dialog .msg $geoEasyMsg(error) \
					"$geoEasyMsg(skipped) $lines" error 0 OK
			}
			if {[llength $obuf]} {
				# check numerc values
				foreach l $obuf {
					if {[lsearch -exact \
							{3 6 7 8 9 10 11 21 24 25 26 27 28 29 37 38 39 49} \
							[lindex $l 0]] != -1 && \
							[regexp $reg(2) [lindex $l 1]] == 0} {
						return $lines
					}
				}
				set face2 0
				set pnum [GetVal 5 $obuf]
				if {$pnum == ""} {      ;# station
					GeoLog1 [format "%-10s" [string range [GetVal 2 $obuf] 0 9]]
				} else {
					set li [expr {$lines - 1}]
					# look for the same point number in this station
					while {$li> 0} {
						if {[string length [GetVal 2 [set ${fa}_geo($li)]]] != 0} {
							break
						}
						if {[GetVal 5 [set ${fa}_geo($li)]] == $pnum} {
							# really second face?
							set obuf1 [set ${fa}_geo($li)]
							set avgbuf ""
							if {[GetVal {17 18 24 25} $obuf1] == ""} {
								set avgbuf [AvgFaces $obuf1 $obuf]
							}
							if {[llength $avgbuf]} {
								set face2 1
							} else {
								GeoLog1 [format $geoEasyMsg(noface2) \
									[GetVal 5 $obuf]]
							}
							break
						}
						incr li -1
					}
				}
				if {$face2} {
					#store average for 2 faces
					set ${fa}_geo($li) $avgbuf
				} else {
					# new first face
					set ${fa}_geo($lines) $obuf
					if {[info exists ${fa}_ref($pn)] == -1} {
						set ${fa}_ref($pn) $lines
					} else {
						lappend ${fa}_ref($pn) $lines
					}
					incr lines
				}
			}
		}
	}
	return 0
}

#
#	Save topcon 210 coordinate file
#	@param fn geo set name
#	@param rn output file name (.210)
#	@return 0 on success
proc Save210 {fn rn} {
	global geoEasyMsg
	global geoLoaded

    set in [GetInternalName $fn]
	global ${in}_coo

	if {[info exists geoLoaded]} {
		set pos [lsearch -exact $geoLoaded $in]
		if {$pos == -1} {
			return -8	;# geo data set not loaded
		}
	} else {
		return 0
	}
	set f [open $rn w]
	# go through coordinates dictionary order
	foreach pn [lsort -dictionary [array names ${in}_coo]] {
		set x [GetVal {37} [set ${in}_coo($pn)]]
		set y [GetVal {38} [set ${in}_coo($pn)]]
		set z [GetVal {39} [set ${in}_coo($pn)]]
		if {[string length $x] || [string length $y] || [string length $z]} {
			set buf "_+[format "%-10s" [string range $pn 0 9]]_"
			if {[string length $y] == 0} { set y 0.0 }
			append buf " x[format "%+010d" [expr {int($y * 1000.0)}]]_"
			if {[string length $x] == 0} { set x 0.0 }
			append buf " y[format "%+010d" [expr {int($x * 1000.0)}]]_"
			if {[string length $z] == 0} { set z 0.0 }
			append buf " z[format "%+010d" [expr {int($z * 1000.0)}]]"
			puts -nonewline $f $buf
		}
	}
	close $f
	return 0
}

#
#	Read Topcon DL101 digital level raw format
#	First letter in input line describes the record type
#	b - start of BF line
#	b,?,lineid,startp,elevation,datetime,??
#	c - start of BBFF line
#	c,?,lineid,?,?,,,,,,,,,,,,,,??,elevation,YYMMDDhhmmss,,,,?,
#	g - foresight treading
#	g,?,reading,distance,?,?,?,pid,?,hhmm
#	h - second foresight reading (line type "c")
#	h,?,reading,distance,?,?,?,pid,?,hhmm
#	i - foresight reading
#	i,?,reading,distance,?,?,?,pid,?,hhmm
#	j - second foresight reading (line type "c")
#	j,?,reading,distance,?,?,?,pid,?,hhmm
#	k - intersight reading
#	k,?,reading,distance,?,?,?,pid,?,hhmm
#	w - summary of line
#	w.?,lineid,...
#	t- end of line
#	t,?,lineid,?,YYMMDDhhmms,?
#	@param fn path to input file
#	@param fa internal name of dataset
#	TODO
proc TopConDL {fn fa} {
	global reg
	global geoEasyMsg geoCodes

	if {[string length $fa] == 0} {return -1}
	global ${fa}_geo ${fa}_coo ${fa}_ref ${fa}_par
	if {[catch {set fin [open $fn r]}] != 0} {
		return -1       ;# cannot open input file
	}
	set lines 0             ;# number of lines in output
	set src 0               ;# input line number
	set obuf ""             ;# output buffer
	set ${fa}_par ""
	set linetype "b"	;# default BF line
	set lineid ""
	while {! [eof $fin]} {
		incr src	;# source line number
		if {[gets $fin buf] == 0} continue
		set buf [string trim $buf]
		set buflist [split $buf ","]  ;# comma separated
		set n [llength $buflist]
		if {$n == 0} continue       ;# empty line
		set code [lindex $buflist 0]
		switch -exact $code {
			b {	;# start of BF line
				set linetype "b"
				set lineid [lindex $buflist 2]
				set startp [lindex $buflist 3]
				set startz [expr {[lindex $buflist 4] / 10000.0}]
puts "BF line id: $lineid  point: $startp $startz"
			}
			c {	;# start of BBFF line
				set linetype "c"
				set lineid [lindex $buflist 2]
				set startp [lindex $buflist 17]
				set startz [expr {[lindex $buflist 18] / 10000.0}]
puts "BBFF line id: $lineid  point: $startp $startz"
			}
			g {	;# backsight reading
				set b1 [expr {[lindex $buflist 2] / 10000.0}]
				set b1d [expr {[lindex $buflist 3] / 10000.0}]
				set bid [lindex $buflist 7]
				set b2 ""
				set f1 ""
				set f2 ""
				set b2d ""
				set f1d ""
				set f2d ""
puts "B1 $bid $b1 $b1d"
			}
			i {	;# forsight reading
				set f1 [expr {[lindex $buflist 2] / 10000.0}]
				set f1d [expr {[lindex $buflist 3] / 10000.0}]
				set fid [lindex $buflist 7]
puts "F1 $fid $f1 $f1d"
			}
			h {	;# second backsight reading
				set b2 [expr {[lindex $buflist 2] / 10000.0}]
				set b2d [expr {[lindex $buflist 3] / 10000.0}]
puts "B2 $bid $b2 $b2d"
			}
			j {	;# second foresight reading
				set f2 [expr {[lindex $buflist 2] / 10000.0}]
				set f2d [expr {[lindex $buflist 3] / 10000.0}]
puts "F2 $fid $f2 $f2d"
			}
			k {	;# intersight reading
				set k [expr {[lindex $buflist 2] / 10000.0}]
				set kd [expr {[lindex $buflist 3] / 10000.0}]
				set kid [lindex $buflist 7]
puts "K  $kid $k $kd"
			}
			w {	;# line summary
			}
			t {	;# end of line
			}
		}
	}
	close $fin
	return 0
}
