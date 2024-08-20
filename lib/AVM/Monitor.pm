#!perl

use v5.40;
use experimental qw[ class ];

class AVM::Monitor {
    method start ($vm, $p) {
        say "╭────────────────────────────────────────╮";
        say "│ ".(sprintf '%-38s' => $p->to_string)." │";
        say "╰─────┬────────────────────────┬─────────╯";
        say "  ic  │  pc #        curr inst │ [stack]";
        say "──────┼────────────────────────┼──────────"
    }

    method enter ($vm, $p) {
        printf "\e[0;41m %04d │ %03d > \e[0m %15s │ \e[2m[%s]\e[0m\n" => $vm->ic, $vm->pc, $vm->ci, join ', ' => $p->stack;
    }

    method out ($vm, $p) {
        printf "\e[0;46m            %% \e[0m %s\n", ($p->sod->buffer)[-1];
    }

    method exit ($vm, $p) {
        printf "\e[0;42m %04d │ %03d < \e[0m \e[2m%15s\e[0m │ [%s]\n" => $vm->ic, $vm->pc, $vm->ci, join ', ' => $p->stack;
    }

    method end ($vm, $p) {}
}
