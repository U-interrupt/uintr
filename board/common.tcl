
if {[llength $argv] > 0} {
  set project_name [lindex $argv 0]
  set str [split $project_name -]
  set project [lindex $s 0]
  set board [lindex $s 1]
} else {
  puts "project full name is not given!"
  return 1
}

