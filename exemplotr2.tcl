
## Exemplo para uso do arquivo trace
##
## -- 15/07/2012
## ==================================
## Carlos Marcelo Pedroso
## Universidade Federal do Paraná
## Departamento de Engenharia Elétrica
## Centro Politécnico
## CEP: 81531-990 - Curitiba - PR - Brasil
## Pequenas modificações Evandro Copercini - 10/05/13

#Define o tempo de simulação
set stoptime 160.0
#set plottime 16000.0

#Inicialização da variável ns com o comando set (Obrigatório).
set ns [new Simulator]

# Nós n0 e n1 são roteadores
set n0 [$ns node] 
set n1 [$ns node]

# Nó n2 a n6 são clientes 
set n2 [$ns node] 
set n3 [$ns node] 
set n4 [$ns node] 
set n5 [$ns node] 
set n6 [$ns node]

# O nó nservidor representa o servidor
set nservidor [$ns node]

# f será utilizado para armazenar o trace geral do NS2
set f [open out.tr w]
$ns trace-all $f
# nf será utilizado para armazenar o trace do NAM
set nf [open out.nam w]
$ns namtrace-all $nf
#Evita saidas desnecessárias.
Tracefile set debug_ 0

# f0 será utilizado para armazenar o número de pacotes perdidos
set f0 [open perda2.tr w]

# f1 será utilizado para armazenar o número de bytes transmitidos
set f1 [open bytes2.tr w]

# f2 será utilizado para armazenar o numero de pacotes na fila do agente 
set f2 [open queue2.tr w]

# Para diferenciar na animação do NAM.
$ns color 1 Blue
$ns color 2 Red
$ns color 3 Green
$ns color 4 Yellow
$ns color 5 Orange

#-------------------------------------------------------------------
# Modelo de perda de pacotes simples.
# set error_model [new ErrorModel]
# $error_model set rate_ 0.01
# $error_model set unit pkt
# $error_model set ranvar [new RandomVariable/Uniform]
# $error_model set drop-target [new Agent/Null]



# -------------------------------------------------------------------
# Gilbert-Elliot Error Model

# w1 is stationary state probability represeting the probability that transmission will be in good state
# w2 is stationary state probability that transmission will be in bad state
# w1 = q/(p+q), w2 = p/(p+q) [is a good basic exercice to prove it]
# p is transition prob. from good state to bad state
# q is transition prob. from bad state to good state
# Transition matrix is: P = { {1-p p}
#                             {q 1-q} }
# 
# Final error probability Ploss = (Pg)w1+(Pb)w2
# Pg is error prob. in good state
# Pb is error prob. in bad state


# Test - Parameters
# Pg=0, Pb=0.5
# p = 0.01, q = 0.90
# w1 = 0.98901, w2 = 0.010989
# In this case, Ploss = 0*0.98901 + 0.5*0.010989 = 0.00549 (ou 0.549%)
       
set good_state [new ErrorModel/Uniform 0 pkt]
set bad_state  [new ErrorModel/Uniform 0.5 pkt]	

# Array of states (error models)
set m_states [list $good_state $bad_state]

# Durations for each of the states, tmp, tmp1 and tmp2, respectively
# Deve fazer as contas e configurar "set m_periods[list w1 w2]

set m_periods [list  0.98901 0.010989]  ;# average value
# Transition state model matrix
set m_transmx { {0.99 0.01}  
                {0.90 0.10} }

set m_trunit pkt
# Use time-based transition
set m_sttype pkt
set m_nstates 2
set m_nstart [lindex $m_states 0]
set em [new ErrorModel/MultiState $m_states $m_periods $m_transmx $m_trunit $m_sttype $m_nstates $m_nstart]


# Fim da config do modelo Gilbert-Elliot
#----------------------------------------------------------------------------



# Link entre n0 e n1 é o bottleneck (gargalo).
$ns duplex-link $n0 $n1 10Mb 10ms DropTail

# Os clientes estão do lado do n0
$ns duplex-link $n0 $n2 10Mb 5ms DropTail
$ns duplex-link $n0 $n3 10Mb 5ms DropTail
$ns duplex-link $n0 $n4 10Mb 5ms DropTail
$ns duplex-link $n0 $n5 10Mb 5ms DropTail
$ns duplex-link $n0 $n6 10Mb 5ms DropTail

# O servidor está do outro lado
$ns duplex-link $n1 $nservidor 10Mb 5ms DropTail


# Tamanho das filas
$ns queue-limit $n0 $n1 10000
$ns queue-limit $n0 $n2 10000
$ns queue-limit $n0 $n3 10000
$ns queue-limit $n0 $n4 10000
$ns queue-limit $n0 $n5 10000
$ns queue-limit $n0 $n6 10000
$ns queue-limit $n1 $nservidor 10000

# configura o modelo de perdas entre os nós 0 e 1
$ns lossmodel $em $n1 $n0

$ns duplex-link-op $n1 $nservidor orient right
$ns duplex-link-op $n0 $n1 orient right

$ns duplex-link-op $n0 $n2 orient up
$ns duplex-link-op $n0 $n3 orient left-up
$ns duplex-link-op $n0 $n4 orient left
$ns duplex-link-op $n0 $n5 orient left-down
$ns duplex-link-op $n0 $n6 orient down

$ns duplex-link-op $n0 $n1 queuePos 0.5
$ns trace-queue $n1 $n0 $f


#########################################
## Trace files 
## 

#Abre arquivos de trace para simulacão
set tfile1 [new Tracefile]
$tfile1 filename coastguard.tracefile

set tfile2 [new Tracefile]
$tfile2 filename trace2

set tfile3 [new Tracefile]
$tfile3 filename trace3

set tfile4 [new Tracefile]
$tfile4 filename trace4

set tfile5 [new Tracefile]
$tfile5 filename trace5

#########################################
## Configura os aplicativos com tráfego configurado
## nos traces
## Protocolo é UDP, como precisamos

## Fonte 1
set s1 [new Agent/UDP]
$ns attach-agent $nservidor $s1
$s1 set fid_ 1

set null1 [new Agent/LossMonitor]
$ns attach-agent $n6 $null1

$ns connect $s1 $null1

set trace1 [new Application/Traffic/Trace]
$trace1 attach-tracefile $tfile1
$trace1 attach-agent $s1
$trace1 attach-agent $s1

## Fonte 2
set s2 [new Agent/UDP]
$ns attach-agent $nservidor $s2
$s2 set fid_ 2

set null2 [new Agent/Null]
$ns attach-agent $n2 $null2

$ns connect $s2 $null2

set trace2 [new Application/Traffic/Trace]
$trace2 attach-tracefile $tfile2
$trace2 attach-agent $s2

## Fonte 3
set s3 [new Agent/UDP]
$ns attach-agent $nservidor $s3
$s3 set fid_ 3

set null3 [new Agent/Null]
$ns attach-agent $n3 $null3

$ns connect $s3 $null3

set trace3 [new Application/Traffic/Trace]
$trace3 attach-tracefile $tfile3
$trace3 attach-agent $s3

## Fonte 4
set s4 [new Agent/UDP]
$ns attach-agent $nservidor $s4
$s4 set fid_ 4

set null4 [new Agent/Null]
$ns attach-agent $n4 $null4

$ns connect $s4 $null4

set trace4 [new Application/Traffic/Trace]
$trace4 attach-tracefile $tfile4

$trace4 attach-agent $s4

## Fonte 5
set s5 [new Agent/UDP]
$ns attach-agent $nservidor $s5
$s5 set fid_ 5

set null5 [new Agent/Null]
$ns attach-agent $n5 $null5

$ns connect $s5 $null5

set trace5 [new Application/Traffic/Trace]
$trace5 attach-tracefile $tfile5

$trace5 attach-agent $s5

#########################################
# Agenda tarefas

$ns at 0.1 "$trace1 start"
$ns at 0.1 "$trace2 start"
$ns at 0.1 "$trace3 start"
$ns at 0.1 "$trace4 start"
$ns at 0.1 "$trace5 start"
$ns at 0.0 "record"

$ns at $stoptime "$trace1 stop"
$ns at $stoptime "$trace2 stop"
$ns at $stoptime "$trace3 stop"
$ns at $stoptime "$trace4 stop"
$ns at $stoptime "$trace5 stop"

$ns at $stoptime "close $f"
$ns at $stoptime "finish tg"
$ns at $stoptime "close $f0"
$ns at $stoptime "close $f1"
$ns at $stoptime "close $f2"

proc record {} {

        global null1 f0 f1 f2 ns
  
        set time 0.1 ;#Set Sampling Time to 0.9 Sec
        set l0 [$null1 set nlost_]
        set b0 [$null1 set bytes_]
        set n0 [$null1 set npkts_]

        set now [$ns now]
       
        # Record Packet Loss Rate in File
        puts $f0 "$now [expr $l0]"

        # Record Bytes transmitted in file
        puts $f1 "$now [expr $b0]"

        # Record queue size
        puts $f2 "$now [expr $n0]"

        # Reset Variables
        $null1 set l0 0
        $ns at [expr $now+$time] "record"   ;# Schedule Record after $time interval sec
}

proc finish file {
		#Executa o trace no NAM (em uma janela).
        exec nam out.nam &
        #exec rm -f out.tr
        exit 0
}

#Roda a simulação
$ns run

exit 