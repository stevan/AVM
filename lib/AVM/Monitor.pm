#!perl

use v5.40;
use experimental qw[ class ];

use importer 'Term::ReadKey' => qw[ GetTerminalSize ];
use importer 'List::Util'    => qw[ mesh ];

class AVM::Monitor {
    field $term_width  :reader;
    field $term_height :reader;

    field @used_colors;
    field $cpu_fmt;

    ADJUST {
        ($term_width, $term_height) = GetTerminalSize();

        $cpu_fmt = "\e[38;2;%d;%d;%d;m%03d\e[0m";
    }

    method start ($cpu, $p) {
        say "╭────────────────────────────────────────────────╮";
        say "│ ". sprintf('%46s', "${p} on ${cpu}")        ." │";
        say "╰─────┬──────┬────────────────────────┬──────────╯";
        say " core │ ppid │  pc #        curr inst │   [stack]";
        say " ─────┼──────┼────────────────────────┼──────────"
    }

    method start_multi ($cpus, $ps) {
        say "╭────────────────────────────────────────────────╮";
        foreach my ($cpu, $p) (mesh $cpus, $ps) {
            say "│ ". sprintf('%46s', "${p} on ${cpu}")        ." │";
        }
        say "╰─────┬──────┬────────────────────────┬──────────╯";
        say " core │ ppid │  pc #        curr inst │   [stack]";
        say " ─────┼──────┼────────────────────────┼──────────"
    }

    method enter ($cpu, $p) {
        printf "  ${cpu_fmt} │\e[0;41m %04d │ %03d > \e[0m %15s │ \e[2m[%s]\e[0m\n" =>
            $self->get_cpu_color($cpu)->@*,
            $cpu->id,
            $p->pid,
            $p->pc,
            $cpu->ci,
            join ', ' => $p->stack;
    }

    method out ($cpu, $p) {
        printf "  ${cpu_fmt} │\e[0;46m %04d │     %% \e[0m %s\n",
            $self->get_cpu_color($cpu)->@*,
            $cpu->id,
            $p->pid,
            $p->sod->peek;
    }

    method exit ($cpu, $p) {
        printf "  ${cpu_fmt} │\e[0;42m %04d │ %03d < \e[0m \e[2m%15s\e[0m │ [%s]\n" =>
            $self->get_cpu_color($cpu)->@*,
            $cpu->id,
            $p->pid,
            $p->pc,
            $cpu->ci,
            join ', ' => $p->stack;
    }

    method slice ($cpu, $p) {
        say " ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄";
    }

    method end ($cpu, $p) {
        say " ─────┴──────┴────────────────────────┴──────────";
    }

    method get_cpu_color ($cpu) {
        return $used_colors[ $cpu->id ] //= [ map { int(rand(100)) + 150 } qw[ r g b ] ];
    }

}
