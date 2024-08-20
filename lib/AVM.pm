#!perl

use v5.40;
use experimental qw[ class ];

use AVM::Assembler;
use AVM::Monitor;

use AVM::Instruction;
use AVM::Process;
use AVM::Message;

class AVM {
    use constant DEBUG => $ENV{DEBUG} // 0;

    field $monitor :param :reader = undef;

    field @code;
    field @procs :reader;
    field @bus   :reader;

    field $ic :reader = 0;
    field $pc :reader = 0;
    field $ci :reader = undef;

    field $assembler;

    field @reaped :reader;

    method assemble ($entry_label, $source) {
        $assembler = AVM::Assembler->new;
        $assembler->assemble($source);

        $self->load_code(
            $assembler->label_to_addr->{$entry_label},
            $assembler->code,
        );

        $self;
    }

    method spawn_new_process ($entry) {
        return AVM::Process->new(
            entry => $entry,
            name  => $assembler->addr_to_label->{$entry}
        )
    }

    method create_new_message ($to, $from, $body) {
        return AVM::Message->new(
            to   => $to,
            from => $from,
            body => $body,
        );
    }

    method load_code ($entry, $code) {
        @code  = @$code;
        @procs = $self->spawn_new_process( $entry );
        $ic    = 0;
        $pc    = $entry;
        $ci    = undef;
        $self;
    }

    method next_op { $code[$pc++] }

    method run {
        push @bus => AVM::Message->new(
            to   => $procs[0],
            from => undef,
            body => undef,
        );

        while (@procs) {
            if (DEBUG) {
                say "before running:\n    ".join "\n    " => map $_->dump, @procs;
                say "bus: ".join ', ' => @bus;
            }

            my @p = @procs;

            while (@bus) {
                my $signal = shift @bus;
                my $to     = $signal->to;
                $to->sid->put( $signal );
                if ($to->is_yielded) {
                    $to->ready;
                }
            }

            foreach my $p (@p) {
                say "excuting process: ".$p->dump if DEBUG;
                if ($p->is_ready) {
                    $self->execute($p);
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

    method execute ($p) {
        $monitor->start($self, $p) if DEBUG;

        $pc = $p->entry;

        while (true) {
            my $op = $self->next_op;

            die "EOC" unless defined $op;

            $ic++;
            $ci = $op;

            $monitor->enter($self, $p) if DEBUG;

            # ----------------------------
            # stack ops
            # ----------------------------
            if ($op == AVM::Instruction::PUSH) {
                my $v = $self->next_op;
                $p->push( $v );
            }
            elsif ($op == AVM::Instruction::POP) {
                $p->pop;
            }
            elsif ($op == AVM::Instruction::DUP) {
                $p->push( $p->peek );
            }
            elsif ($op == AVM::Instruction::SWAP) {
                my $val1 = $p->pop;
                my $val2 = $p->pop;
                $p->push( $val1 );
                $p->push( $val2 );
            }
            elsif ($op == AVM::Instruction::LOAD) {
                my $offset = $self->next_op;
                $p->push( $p->get_stack_at( $offset ) );
            }
            elsif ($op == AVM::Instruction::STORE) {
                my $value  = $p->pop;
                my $offset = $self->next_op;
                $p->set_stack_at( $offset, $value );
            }
            # ----------------------------
            # math
            # ----------------------------
            elsif ($op == AVM::Instruction::INC_INT) {
                $p->push( $p->pop + 1 );
            }
            elsif ($op == AVM::Instruction::DEC_INT) {
                $p->push( $p->pop - 1 );
            }
            # ----------------------------
            # comparisons
            # ----------------------------
            elsif ($op == AVM::Instruction::EQ_INT) {
                my $b = $p->pop;
                my $a = $p->pop;
                $p->push( $a == $b ? 1 : 0 );
            }
            elsif ($op == AVM::Instruction::LT_INT) {
                my $b = $p->pop;
                my $a = $p->pop;
                $p->push( $a < $b ? 1 : 0 );
            }
            elsif ($op == AVM::Instruction::GT_INT) {
                my $b = $p->pop;
                my $a = $p->pop;
                $p->push( $a > $b ? 1 : 0 );
            }
            # ----------------------------
            # i/0
            # ----------------------------
            elsif ($op == AVM::Instruction::PUT) {
                my $x = $p->pop;
                $p->sod->put($x);
                $monitor->out($self, $p) if DEBUG;
            }
            # ----------------------------
            # conditions
            # ----------------------------
            elsif ($op == AVM::Instruction::JUMP) {
                $pc = $self->next_op;
            }
            elsif ($op == AVM::Instruction::JUMP_IF_FALSE) {
                my $a = $self->next_op;
                my $x = $p->pop;
                $pc = $a unless $x;
            }
            elsif ($op == AVM::Instruction::JUMP_IF_TRUE) {
                my $a = $self->next_op;
                my $x = $p->pop;
                $pc = $a if $x;
            }
            elsif ($op == AVM::Instruction::JUMP_TO) {
                my $a = $p->pop;
                $pc = $a;
            }
            # ----------------------------
            # ...
            # ----------------------------
            elsif ($op == AVM::Instruction::CREATE_MSG) {
                my $to   = $p->pop;
                my $from = $p->pop;
                my $body = $p->pop;
                $p->push( $self->create_new_message( $to, $from, $body ) );
            }
            elsif ($op == AVM::Instruction::NEW_MSG) {
                my $to   = $p->pop;
                my $body = $p->pop;
                $p->push( $self->create_new_message( $to, $p, $body ) );
            }
            elsif ($op == AVM::Instruction::MSG_TO) {
                my $signal = $p->pop;
                $p->push($signal->to);
            }
            elsif ($op == AVM::Instruction::MSG_FROM) {
                my $signal = $p->pop;
                $p->push($signal->from);
            }
            elsif ($op == AVM::Instruction::MSG_BODY) {
                my $signal = $p->pop;
                $p->push($signal->body);
            }
            # ----------------------------
            # ...
            # ----------------------------
            elsif ($op == AVM::Instruction::SPAWN) {
                my $entry = $self->next_op;
                my $proc  = $self->spawn_new_process( $entry );
                push @procs => $proc;
                $p->push( $proc );
            }
            elsif ($op == AVM::Instruction::SELF) {
                $p->push( $p );
            }
            elsif ($op == AVM::Instruction::SEND) {
                my $signal = $p->pop;
                push @bus => $signal;
            }
            elsif ($op == AVM::Instruction::RECV) {
                if ($p->sid->is_not_empty) {
                    my $signal = $p->sid->get;
                    $p->push( $signal );
                } else {
                    $p->set_entry( $pc );
                    $p->yeild;
                }
            }
            elsif ($op == AVM::Instruction::NEXT) {
                my $addr = $self->next_op;
                $p->set_entry( $addr );
            }
            elsif ($op == AVM::Instruction::YIELD) {
                $p->yield;
            }
            elsif ($op == AVM::Instruction::STOP) {
                $p->stop;
            }
            else {
                die "WTF IS THIS $op";
            }

            $monitor->exit($self, $p) if DEBUG;

            last unless $p->is_ready;
        }

        $monitor->end($self, $p) if DEBUG;
    }
}
