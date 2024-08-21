#!perl

use v5.40;
use experimental qw[ class ];

use importer 'Scalar::Util' => qw[ dualvar ];

use AVM::Port;

class AVM::Process {
    use overload '""' => \&to_string;

    use constant READY   => dualvar(1, 'READY');   # ready to do work ...
    use constant YIELDED => dualvar(2, 'YIELDED'); # it has yielded control to the system
    use constant STOPPED => dualvar(3, 'STOPPED'); # stopped entirely

    my $PID_SEQ = 0;

    field $entry  :param :reader;  # start address of process
    field $name   :param :reader;  # name of the process (aka - entry label)
    field $parent :param :reader = undef;

    field $pid    :reader;         # unique process identifier
    field $status :reader;         # one of the constants above
    field $pc     :reader;         # seperate program counter
    field @stack  :reader;         # seperate stack
    field $sp     :reader = -1;    # and stack pointer

    field $sid :reader;
    field $sod :reader;

    ADJUST {
        $status = READY;

        $sid = AVM::Port->new;
        $sod = AVM::Port->new;

        $pid = ++$PID_SEQ;
        $pc  = $entry;
    }

    method inc_pc         { $pc++ }
    method set_pc ($addr) { $pc = $addr }

    method set_entry ($e) { $entry = $e }

    method push  ($v) { push @stack => $v }
    method pop        { pop @stack        }
    method peek       { $stack[-1]        }

    method get_stack_at ($i)     { $stack[$i]      }
    method set_stack_at ($i, $v) { $stack[$i] = $v }

    method ready { $status = READY   }
    method yield { $status = YIELDED; $pc = $entry; }
    method stop  { $status = STOPPED }

    method is_ready   { $status == READY   }
    method is_yielded { $status == YIELDED }
    method is_stopped { $status == STOPPED }

    method to_string { sprintf '<%02d:%s>[%03d]' => $pid, $name, $entry }

    method dump {
        sprintf 'proc{ pid: %03d, name: %s, status: %s, entry: %03d, parent: %s }', $pid, $name, $status, $entry, $parent // '~';
    }
}
