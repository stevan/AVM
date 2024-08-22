#!perl

use v5.40;
use experimental qw[ class ];

use importer 'List::Util' => qw[ min max ];

use AVM::Assembler;
use AVM::Monitor;

use AVM::Instruction;
use AVM::Process;
use AVM::Message;

use AVM::CPU;

class AVM::MultiCore {
    use constant DEBUG => $ENV{DEBUG} // 0;

    field $monitor :param :reader = undef;

    field $num_cores     :param :reader;
    field $process_quota :param :reader;
    field $clock_slice   :param :reader;

    field @cpus  :reader;
    field @procs :reader;
    field @bus   :reader;

    field $assembler;

    field @reaped :reader;

    ADJUST {
        @cpus = map {
            AVM::CPU->new( vm => $self, id => $_ )
        } 1 .. $num_cores;
    }

    method assemble ($entry_label, $source) {
        $assembler = AVM::Assembler->new;
        $assembler->assemble($source);

        my $entry = $assembler->label_to_addr->{$entry_label};

        $_->load_code(
            $entry,
            $assembler->code,
        ) foreach @cpus;

        @procs = ();
        $self->spawn_new_process( $entry );

        $self;
    }

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

            my @ready = grep $_->is_ready, @p;

            if (scalar @ready == 1) {
                $cpus[0]->run( $ready[0], $process_quota );
            }
            else {
                $monitor->start_multi(\@cpus, \@ready) if DEBUG;

                my $quota = $process_quota;
                while ($quota && @ready) {
                    my $avail = min( $#ready, $#cpus );

                    foreach my $i ( 0 .. $avail ) {
                        if ($ready[$i]->is_ready) {
                            foreach ( 1 .. $clock_slice ) {
                                $cpus[$i]->execute( $ready[$i] );
                                last unless $ready[$i]->is_ready;
                            }
                            $monitor->slice(undef, undef) if DEBUG;
                        }
                    }

                    #warn "!!!!!!!!!!!!!!! ".scalar @ready;
                    @ready = grep $_->is_ready, @ready;
                    #warn "!!!!!!!!!!!!!!! ".scalar @ready;

                    $quota -= $clock_slice;
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
