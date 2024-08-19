
```


my $code = q[
    ping:
        LOCAL i(0)      ; stash a local variable
    ping.loop:
        RECV            ; async block until receives message and pushes onto the stack          [] => [msg]
        DUP             ; duplicate this                                                        [msg] => [msg, msg]

        GET_MSG 0       ; message decomposition 0 = message sender pushed onto the stack        [msg,msg] => [msg,sender]
        SWAP            ;                                                                       [msg,msg] => [sender,msg]
        GET_MSG 1       ; message decomposition 1 = message body pushed onto the stack          [sender,msg] => [sender,int]
        INC_INT         ; increment the top of the stack by 1 and push the result on the stack  [sender,int] => [sender,int2]
        DUP             ;                                                                       [sender,int2] => [sender,int2,int2]
        STORE_LOCAL 0   ; store the incremented int in the local storage index = 0              [sender,int2,int2] => [sender,int2]

        SELF            ; put the self reference at the top of the stack                        [sender,int2] => [sender,int2,self]
        NEW_MSG         ; create a new message with whatever is on the top of the stack         [sender,int2,self] => [sender,msg2]
                        ; 0 = sender
                        ; 1 = body
        SWAP            ;                                                                       [sender,msg2] => [msg2,sender]
        SEND            ; send message with whatever is on the top of the stack                 [msg2,sender] => []
                        ; 0 = recipient
                        ; 1 = message
        NEXT #ping.loop ; leave the continuation address on the stack                           [cont]
        YIELD           ; yield control back to the system

    main:
        SPAWN #ping    ; spawn new #ping and push to the top of the stack       [] => [#ping1]
        SPAWN #ping    ; spawn new #ping and push to the top of the stack       [#ping1] => [#ping1,#ping2]

        PUSH i(0)      ;                                                        [#ping1,#ping2] => [#ping1,#ping2,int]
        NEW_MSG        ; 0 = #ping2, 1 = i(0)                                   [[#ping1,#ping2,int] => [#ping1,msg]
        SWAP           ;                                                        [#ping1,msg] => [msg,#ping1]
        SEND           ;                                                        [msg,#ping1] => []

        YIELD          ; yield and let the processes start to flow ...

];

```
