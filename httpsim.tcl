# this scripts simulates clients requesting pages from web servers.
# A dumbbell topology to connects clients and servers
#
# number of clients/servers
set maxServers 1
set maxClients 1000

# rate for bottleneck link
set linkrate 1000kb
# set qlen 20000 

# end condition 
set maxPagesDownloaded 5000

#-------------------------------------------------------------
# user/session related random variable stuff
#
# size of index object / text frame of a Web Page
set indexObjSize [new RandomVariable/Normal]
$indexObjSize set avg_ 9797
$indexObjSize set std_ 4494

# num of embedded objects in a Web Page
set numEmbeddedObj [new RandomVariable/Uniform]
$numEmbeddedObj set min_ 0
$numEmbeddedObj set max_ 10


# size of embedded objects in a Web Page
set embeddedObjSize [new RandomVariable/Exponential]
$embeddedObjSize set avg_ 9797


# inter-page time
set interPageTime [new RandomVariable/Exponential]
$interPageTime set avg_ 1000

# server selection (uniform distribution [later: something like Zipf's law etc.])
set serverSelection [new RandomVariable/Uniform]
$serverSelection set min_ 0
$serverSelection set max_ [expr $maxServers - 0.01]

# puts "serverSelection: max: [$serverSelection set max_]"

# puts "Random Variables initialized"

set numPagesGenerated 0 

# -----------------------------------------------------------
# this class models the downloaded page. This is the fraction of 
# the page which has arrived at the client side.
# The array size contains the size of the different objects:
# First text frame, then inlined objects.

Class Page


#### initialize page with a parameter on with server is was
# created. This enables to assign the index object correctly


Page instproc init { homeServer } {
    # generate the page here

    $self instvar numberOfObj_
    $self instvar numObjRequested_
    $self instvar numObjSent_
    $self instvar numObjRecvd_

    $self instvar totalSize_
    $self instvar size_
    $self instvar locationOfObj_ 
    $self instvar status_
    $self instvar id_

    # random variables
    global numEmbeddedObj
    global indexObjSize
    global embeddedObjSize
    global serverSelection
    global serverObj

    global numPagesGenerated

    incr numPagesGenerated
    set id_ $numPagesGenerated

    # the page has already been requested when created at the server
    set numObjRequested_ 1 
    set numObjSent_ 0
    set numObjRecvd_ 0

    # Indices of array: 
    # 1                 : text frame / index object
    # 2 .. numberOfObj_ : inlined objects / embedded obj.
    # status of objects from the clients view: pending, requested, received

    # determine number of objects
    set numObj [ expr 1 + int([$numEmbeddedObj value])]
    $self set numberOfObj_ $numObj

    # index object / text frame
    $self set size_(1) [expr int([$indexObjSize value])]
    if {$size_(1) < 1} {
	set size_(1) 1 
    }
    $self set totalSize_ $size_(1)
    $self set locationOfObj_(1) $homeServer

    $self set status_(1) requested 

    # puts "[[Simulator instance] now] new Page generated: $self (with $numObj objects)"
    # puts "size(1): $size_(1)"

    # embedded objects
    for { set i 2 } { $i <= $numObj } { incr i } {

	$self set size_($i) [expr int([$embeddedObjSize value])] 
	if {$size_($i) < 1} {
	    set size_($i) 1 
	}
	incr totalSize_ $size_($i) 
 	
	# determine if this object is located on the same server as
	# the index object or on another
	# -- preliminarily use a uniform distribution among all servers
	set k [ expr int([$serverSelection value])]

	$self set locationOfObj_($i) $serverObj($k)
	$self set status_($i) pending
	# puts "obj($i) -- size: $size_($i) location: $locationOfObj_($i)"
    }
}

Page instproc objRequested { num } {
    $self instvar numObjRequested_
    $self instvar status_

    set status_($num) requested
    incr numObjRequested_ 
    return $numObjRequested_
}

Page instproc allObjRequested { } {
    $self instvar numObjRequested_
    $self instvar numberOfObj_

    return [expr $numObjRequested_ >= $numberOfObj_ ]
}

Page instproc objRecvd { num } {
    $self instvar numObjRecvd_
    $self instvar status_

    set status_($num) received    
    incr numObjRecvd_
    return numObjRecvd_
}

Page instproc allObjRecvd { } {
    $self instvar numObjRecvd_
    $self instvar numberOfObj_

    return [expr $numObjRecvd_ >= $numberOfObj_ ]
}

source http.tcl

# -----------------------------------------------------------
# schedule start of some download for this client instance
Client instproc genRequests { } {
    # this method contains the main user related user/session attributes
    global ns

    global interPageTime
    global serverSelection
    global serverObj
 
    # inter-page time
    set waitingTime [$interPageTime value]

    # server selection (uniform distribution or Zipf's law)
    set i [ expr int([$serverSelection value])]

    $ns at [expr [$ns now] + $waitingTime] "$self requestPage $serverObj($i)"
}


# Client done - successfull download -> schedule new one 

Client instproc done { } {
    global ns
    global numPagesDownloaded
    global maxPagesDownloaded 
    global interPageTime
    global serverSelection
    global serverObj
    $self instvar timeOfRecpt_
    $self instvar timeOfRequest_
    $self instvar lastRecvdPage_

    set respTime [expr $timeOfRecpt_ - $timeOfRequest_]
    set totSize [$lastRecvdPage_ set totalSize_]
    set numObj [$lastRecvdPage_ set numberOfObj_]
    
    incr numPagesDownloaded

    puts "[$ns now] Client $self -- done: Download of web page # $numPagesDownloaded containing $numObj objects / $totSize Bytes in $respTime sec"
    
    if { $numPagesDownloaded >= $maxPagesDownloaded } { finish }

    # when a page is completely received
    # then wait for inter-page time
    # select a new server
    # request a page there

    set waitingTime [$interPageTime value]

    set i [ expr int([$serverSelection value])]

    $ns at [expr [$ns now] + $waitingTime] "$self requestPage $serverObj($i)"
}

# -----------------------------------------------------------

Server instproc genPage { } {
    global ns
    # "page generator"

    # puts "[$ns now] server $self generate page"
   
    set page [new Page $self]    
    return $page
}

# -----------------------------------------------------------


# -----------------------------------------------------------
proc finish {} {
    global ns
    
    puts "[$ns now] End of simulation"
    exit 0
}

# -----------------------------------------------------------
# this is a simple main to test the client/server class with
# a pair of one client and one server

# Create the simulator.
set ns [new Simulator]

puts "Start to create topology"

# the bottleneck WAN link
set router(0) [$ns node]
set router(1) [$ns node]

$ns duplex-link $router(0) $router(1) $linkrate 10ms DropTail

# - the 1:n at both sides of the dumpbell, 
#   attach nodes connected to the router
# - Create web servers/clients
for { set i 0 } { $i < $maxServers } { incr i } {
    set center_node($i) [$ns node]
    $ns duplex-link $center_node($i) $router(0) 10000Mb 0.1ms DropTail
    set serverObj($i) [new Server11 $center_node($i)]
}

for { set i 0 } { $i < $maxClients } { incr i } {
    set branch_node($i) [$ns node]
    $ns duplex-link $branch_node($i) $router(1) 10000Mb 0.1ms DropTail
    set clientObj($i) [new Client11 $branch_node($i)]
}

puts "Topology created"

# Start all Web clients to generate requests
for { set i 0 } { $i < $maxClients } { incr i } {
    $clientObj($i) genRequests
}

set numPagesDownloaded 0

$ns run
# -----------------------------------------------------------






