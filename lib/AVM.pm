#!perl

use v5.40;
use experimental qw[ class ];

use AVM::Assembler;
use AVM::Monitor;

use AVM::Instruction;
use AVM::Process;
use AVM::Message;

use AVM::CPU;

class AVM {
    use constant DEBUG => $ENV{DEBUG} // 0;
    use constant QUOTA => 1024; # sensible default for now

    field $monitor :param :reader = undef;

    field $cpu   :reader;
    field @procs :reader;
    field @bus   :reader;

    field $assembler;

    field @reaped :reader;

    ADJUST {
        $cpu = AVM::CPU->new( vm => $self, id => 1 );
    }

    method assemble ($entry_label, $source) {
        $assembler = AVM::Assembler->new;
        $assembler->assemble($source);

        my $entry = $assembler->label_to_addr->{$entry_label};

        $cpu->load_code(
            $entry,
            $assembler->code,
        );

        @procs = ();
        $self->spawn_new_process( $entry );

        $self;
    }

    ## ... these two methods can be called from the opcodes ...

    method spawn_new_process ($entry, $parent=undef) {
        my $p = AVM::Process->new(
            entry  => $entry,
            name   => $assembler->addr_to_label->{$entry},
            parent => $parent,
        );
        push @procs => $p;
        return $p;
    }

    method create_new_message ($to, $from, $body) {
        return AVM::Message->new(
            to   => $to,
            from => $from,
            body => $body,
        );
    }

    ## ...

    method run {

        $procs[0]->ready;

        while (@procs) {
            if (DEBUG) {
                say '-' x 100;
                say "before running:\n    ".join "\n    " => map $_->dump, @procs;
                say "bus: ".join ', ' => @bus;
            }

            my @p = @procs;

            while (@bus) {
                my $msg = shift @bus;
                my $to  = $msg->to;
                $to->input->put( $msg );
                if ($to->is_yielded) {
                    $to->ready;
                }
            }

            foreach my $p (@p) {
                say "excuting process: ".$p->dump if DEBUG;
                if ($p->is_ready) {
                    $cpu->run($p, QUOTA);
                }
            }

            foreach my $p (@p) {
                if ($p->output->is_not_empty) {
                    push @bus => $p->output->flush;
                }
            }

            if (DEBUG) {
                say "bus: ".join ', ' => @bus;
                say "after running:\n    ".join "\n    " => map $_->dump, @procs;
            }

            @procs = map {
                if ($_->is_stopped) {
                    push @reaped => $_;
                    ();
                } else {
                    $_;
                }
            } @procs;
        }

        $self;
    }
}
