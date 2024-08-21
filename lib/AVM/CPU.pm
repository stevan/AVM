#!perl

use v5.40;
use experimental qw[ class ];

use AVM::Instruction;

class AVM::CPU {
    use constant DEBUG => $ENV{DEBUG} // 0;

    use overload '""' => \&to_string;

    field $vm :param :reader;
    field $id :param :reader;

    field $code;

    field $ic :reader = 0;
    field $ci :reader = undef;

    field $monitor;

    ADJUST {
        $monitor = $vm->monitor;
    }

    method load_code ($entry, $_code) {
        $code = $_code;
        $ic   = 0;
        $ci   = undef;
        $self;
    }

    method next_op ($p) { $code->[ $p->inc_pc ] }

    method run ($p, $quota) {

        $monitor->start($self, $p) if DEBUG;

        while ($self->execute( $p )){
            last unless --$quota;
        }

        $monitor->end($self, $p) if DEBUG;

        return $quota;
    }

    method execute ($p) {
        my $op = $self->next_op($p);

        die "EOC" unless defined $op;

        $ic++;
        $ci = $op;

        $monitor->enter($self, $p) if DEBUG;

        # ----------------------------
        # stack ops
        # ----------------------------
        if ($op == AVM::Instruction::PUSH) {
            my $v = $self->next_op($p);
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
            my $offset = $self->next_op($p);
            $p->push( $p->get_stack_at( $offset ) );
        }
        elsif ($op == AVM::Instruction::STORE) {
            my $value  = $p->pop;
            my $offset = $self->next_op($p);
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
            $p->set_pc( $self->next_op($p) );
        }
        elsif ($op == AVM::Instruction::JUMP_IF_TRUE) {
            my $a = $self->next_op($p);
            my $x = $p->pop;
            $p->set_pc( $a ) if $x;
        }
        elsif ($op == AVM::Instruction::JUMP_IF_FALSE) {
            my $a = $self->next_op($p);
            my $x = $p->pop;
            $p->set_pc( $a ) unless $x;
        }
        elsif ($op == AVM::Instruction::JUMP_IF_ZERO) {
            my $a = $self->next_op($p);
            my $x = $p->pop;
            $p->set_pc( $a ) if $x == 0;
        }
        elsif ($op == AVM::Instruction::JUMP_IF_NOT_ZERO) {
            my $a = $self->next_op($p);
            my $x = $p->pop;
            $p->set_pc( $a ) if $x == 0;
        }
        elsif ($op == AVM::Instruction::JUMP_TO) {
            my $a = $p->pop;
            $p->set_pc( $a );
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
            my $idx = $self->next_op($p);
            my $msg = $p->pop;
            $p->push( $msg->body->[$idx] );
        }
        # ----------------------------
        # ...
        # ----------------------------
        elsif ($op == AVM::Instruction::SPAWN) {
            my $entry = $self->next_op($p);
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
                $p->set_entry( $p->pc - 1 );
                $p->yield;
            }
        }
        elsif ($op == AVM::Instruction::NEXT) {
            my $addr = $self->next_op($p);
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

        return $p->is_ready;
    }


    method to_string { sprintf 'cpu(%02d)' => $id }
}
