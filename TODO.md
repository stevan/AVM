<!---------------------------------------------------------------------------->
# TODO
<!---------------------------------------------------------------------------->

- come up with a better name





<!---------------------------------------------------------------------------->
## Design
<!---------------------------------------------------------------------------->

## Component Responsibility

- Async VM
    - CPU
    - loops over $n Processes
        - sequentially executed on the CPU
    - @bus -> delivers to Process input port

- CPU
    - execution engine

- Process
    - context storage
    - includes:
        - program counter
        - stack + stack pointer
        - input port
        - output port

## Calling Convention
