#!perl

use v5.40;
use experimental qw[ class ];

use AVM::Instruction;

class AVM::CPU {
    use constant DEBUG => $ENV{DEBUG} // 0;

    field $vm :param :reader;

    field @code;

    field $ic :reader = 0;
    field $pc :reader = 0;
    field $ci :reader = undef;

    field $monitor;

    ADJUST {
        $monitor = $vm->monitor;
    }

    method load_code ($entry, $code) {
        @code = @$code;
        $ic   = 0;
        $pc   = $entry;
        $ci   = undef;
        $self;
    }

    method next_op { $code[$pc++] }

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
            elsif ($op == AVM::Instruction::ADD_INT) {
                my $r = $p->pop;
                my $l = $p->pop;
                $p->push( $l + $r );
            }
            elsif ($op == AVM::Instruction::SUB_INT) {
                my $r = $p->pop;
                my $l = $p->pop;
                $p->push( $l - $r );
            }
            elsif ($op == AVM::Instruction::MUL_INT) {
                my $r = $p->pop;
                my $l = $p->pop;
                $p->push( $l * $r );
            }
            elsif ($op == AVM::Instruction::DIV_INT) {
                my $r = $p->pop;
                my $l = $p->pop;
                $p->push( $l / $r );
            }
            elsif ($op == AVM::Instruction::MOD_INT) {
                my $r = $p->pop;
                my $l = $p->pop;
                $p->push( $l % $r );
            }
            # ----------------------------
            # comparisons
            # ----------------------------
            elsif ($op == AVM::Instruction::EQ_ZERO) {
                my $a = $p->pop;
                $p->push( $a == 0 ? 1 : 0 );
            }
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
            elsif ($op == AVM::Instruction::LTE_INT) {
                my $b = $p->pop;
                my $a = $p->pop;
                $p->push( $a <= $b ? 1 : 0 );
            }
            elsif ($op == AVM::Instruction::GT_INT) {
                my $b = $p->pop;
                my $a = $p->pop;
                $p->push( $a > $b ? 1 : 0 );
            }
            elsif ($op == AVM::Instruction::GTE_INT) {
                my $b = $p->pop;
                my $a = $p->pop;
                $p->push( $a >= $b ? 1 : 0 );
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
            elsif ($op == AVM::Instruction::JUMP_IF_TRUE) {
                my $a = $self->next_op;
                my $x = $p->pop;
                $pc = $a if $x;
            }
            elsif ($op == AVM::Instruction::JUMP_IF_FALSE) {
                my $a = $self->next_op;
                my $x = $p->pop;
                $pc = $a unless $x;
            }
            elsif ($op == AVM::Instruction::JUMP_IF_ZERO) {
                my $a = $self->next_op;
                my $x = $p->pop;
                $pc = $a if $x == 0;
            }
            elsif ($op == AVM::Instruction::JUMP_IF_NOT_ZERO) {
                my $a = $self->next_op;
                my $x = $p->pop;
                $pc = $a if $x == 0;
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
                $p->push( $vm->create_new_message( $to, $from, [ $body ] ) );
            }
            elsif ($op == AVM::Instruction::CREATE_MSG2) {
                my $to    = $p->pop;
                my $from  = $p->pop;
                my $body1 = $p->pop;
                my $body2 = $p->pop;
                $p->push( $vm->create_new_message( $to, $from, [ $body1, $body2 ] ) );
            }
            elsif ($op == AVM::Instruction::CREATE_MSG2) {
                my $to    = $p->pop;
                my $from  = $p->pop;
                my $body1 = $p->pop;
                my $body2 = $p->pop;
                my $body3 = $p->pop;
                $p->push( $vm->create_new_message( $to, $from, [ $body1, $body2, $body3 ] ) );
            }
            elsif ($op == AVM::Instruction::NEW_MSG) {
                my $to   = $p->pop;
                my $body = $p->pop;
                $p->push( $vm->create_new_message( $to, $p, [ $body ] ) );
            }
            elsif ($op == AVM::Instruction::NEW_MSG2) {
                my $to    = $p->pop;
                my $body1 = $p->pop;
                my $body2 = $p->pop;
                $p->push( $vm->create_new_message( $to, $p, [ $body1, $body2 ] ) );
            }
            elsif ($op == AVM::Instruction::NEW_MSG2) {
                my $to    = $p->pop;
                my $body1 = $p->pop;
                my $body2 = $p->pop;
                my $body3 = $p->pop;
                $p->push( $vm->create_new_message( $to, $p, [ $body1, $body2, $body3 ] ) );
            }
            elsif ($op == AVM::Instruction::MSG_TO) {
                my $msg = $p->pop;
                $p->push($msg->to);
            }
            elsif ($op == AVM::Instruction::MSG_FROM) {
                my $msg = $p->pop;
                $p->push($msg->from);
            }
            elsif ($op == AVM::Instruction::MSG_BODY) {
                my $msg = $p->pop;
                $p->push( $msg->body->[0] );
            }
            elsif ($op == AVM::Instruction::MSG_BODY_AT) {
                my $idx = $self->next_op;
                my $msg = $p->pop;
                $p->push( $msg->body->[$idx] );
            }
            # ----------------------------
            # ...
            # ----------------------------
            elsif ($op == AVM::Instruction::SPAWN) {
                my $entry = $self->next_op;
                my $proc  = $vm->spawn_new_process( $entry, $p );
                $p->push( $proc );
            }
            elsif ($op == AVM::Instruction::SELF) {
                $p->push( $p );
            }
            elsif ($op == AVM::Instruction::SEND) {
                my $msg = $p->pop;
                $vm->enqueue_message( $msg );
            }
            elsif ($op == AVM::Instruction::RECV) {
                if ($p->sid->is_not_empty) {
                    my $msg = $p->sid->get;
                    $p->push( $msg );
                } else {
                    $p->set_entry( $pc - 1 );
                    $p->yield;
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
