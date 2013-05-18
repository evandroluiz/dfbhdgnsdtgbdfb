##################################
#				 #
#	EPL 653 - NS-2 LABS	 #
#				 #
##################################

#
# Example Tcl script
#
# The folllowing Tcl script develops a simple network topology and
# measures the throughput of the bottleneck link


#Create a simulator object
set ns [new Simulator]

#Define different colours for data flows (for NAM)
$ns color 1 Blue
$ns color 2 Red


#Open the NAM trace file
set nam_file [open out.nam w]
$ns namtrace-all $nam_file

set tf [open out.tr w]
$ns trace-all $tf

#
#Define some important parameters - Assign values to them
#
#Simulation time
set SimTime 3.0
#Bottleneck link Bandwidth
set bw 10Mb
#Bottleneck link delay
set delay 20ms
#Bottleneck link queuetype
set queuetype DropTail
#Buffer Size
set BufferSize 50
#TCP packet size
set packetsize 1000
#TCP window size
set windowsize 80
#Initialize a variable
set old_data 0


#Create four nodes
set n0 [$ns node]
set n1 [$ns node]
set n2 [$ns node]
set n3 [$ns node]


#Connect the nodes - Create links between the nodes
$ns duplex-link $n0 $n2 10Mb 1ms DropTail
$ns duplex-link $n1 $n2 10Mb 1ms DropTail
$ns duplex-link $n2 $n3 1Mb  40ms RED 


#Set Queue size of the bottleneck link (n2-n3) to 20
$ns queue-limit $n2 $n3 $BufferSize

#Give node position (for NAM)
$ns duplex-link-op $n0 $n2 orient right-down
$ns duplex-link-op $n1 $n2 orient right-up
$ns duplex-link-op $n2 $n3 orient right

#Monitor the queue for the bottleneck link (n2-n3). (for NAM)
$ns duplex-link-op $n2 $n3 queuePos 0.5

#
#Setup a TCP connection
#
set agent_tcp [new Agent/TCP]
#Attach TCP Agent to source node n0
$ns attach-agent $n0 $agent_tcp

set agent_sink [new Agent/TCPSink]
#Attach a TCPSink Agent to destination node n3
$ns attach-agent $n3 $agent_sink

#Connect TCP Agent with TCPSink Agent
$ns connect $agent_tcp $agent_sink

#Flow Identity for TCP
$agent_tcp set fid_ 1

#Setup a FTP traffic over TCP connection
set traf_ftp [new Application/FTP]
$traf_ftp attach-agent $agent_tcp



#Setup a UDP connection
#
set agent_udp [new Agent/UDP]
#Attach UDP Agent to source node n1
$ns attach-agent $n1 $agent_udp

set agent_null [new Agent/Null]
#Attach a Null Agent to destination node n3
$ns attach-agent $n3 $agent_null

#Connect UDP Agent with NULL Agent
$ns connect $agent_udp $agent_null

#Flow Identity for UDP
$agent_udp set fid_ 2

#Setup a CBR traffic over UDP connection
set traf_cbr [new Application/Traffic/CBR]
$traf_cbr attach-agent $agent_udp

#CBR parameters
$traf_cbr set packet_size_ 100
$traf_cbr set rate_ 500Kb


#Schedule events for the FTP and CBR agents
$ns at 0.0001 "$traf_ftp start"
$ns at 0.5 "$traf_cbr start"
$ns at 4.0 "$traf_ftp stop"
$ns at 3.0 "$traf_cbr stop"


#Create file for monitoring all packets from n2 to n3
set trace_file [open trace_file.out w]
$ns at 0.0 "$ns trace-queue $n2 $n3 $trace_file"



#
#Define a 'finish' procedure
#
#This procedure also calculates the throughput at the bottleneck link in Mbit/s
proc finish {} {
        global ns old_data nam_file trace_file tf
	$ns flush-trace
 	#Close the trace file
	close $trace_file
	#Close the NAM trace file
	close $nam_file
        close $tf
	#Execute NAM
	exec nam out.nam &

        exit 0
}


#Call the procedure finish at the end of simulation
$ns at 5.5 "finish"

#Run the simulation
$ns run
