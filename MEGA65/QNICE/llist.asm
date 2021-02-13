; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Linked List: Simple linked list implementation for the file browser that
; is able to do a sorted insert
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in February 2021 and licensed under GPL v3
; ****************************************************************************


; Simple Linked List: Record Layout

SLL$NEXT        .EQU    0x0000                  ; pointer: next element
SLL$PREV        .EQU    0x0001                  ; pointer: previous element
SLL$DATA_SIZE   .EQU    0x0002                  ; amount of data (words)
SLL$DATA        .EQU    0x0003                  ; pointer: data

; Sorted Insert: Insert the new element at the right position
; Input
;   R8: Head of linked list, zero if this is the first element
;   R9: New element
;  R10: Pointer to a compare function that returns negative if (S0 < S1),
;       zero if (S0 == S1), positive if (S0 > S1). These semantic are
;       basically compatible with STR$CMP, but instead of expecting pointers
;       to two strings, this compare function is expecting two pointers to
;       SLL records, while the pointer to the first one is given in R8 and
;       treated as "S0" and the second one in R9 and treated as "S1".
;       R10 is overwritten by the return value
; Output:
;   R8: (New) head of linked list

SLL$S_INSERT    INCRB
                MOVE    R9, R0
                MOVE    R10, R1
                INCRB

                MOVE    R8, R0                  ; R0: head of linked list
                MOVE    R9, R1                  ; R1: new element
                MOVE    R0, R2                  ; R2: curr. elm to be checked                
                MOVE    R10, R7                 ; R7: ptr to compare func.

                ; if the new element is the first element, then we can
                ; directly return
                CMP     0, R0                   ; head = zero?
                RBRA    _SLLSI_LOOP, !Z         ; no: go on
                MOVE    R1, R8                  ; yes: return new elm has head
                RBRA    _SLLSI_RET, 1

                ; iterate through the linked list:
                ; 1. check if the new element is smaller than the existing
                ;    element and if yes, then insert it before the existing
                ;    element
                ; 2. if the existing element was the head, then set new head
_SLLSI_LOOP     MOVE    R1, R8                  ; R8: "S0", new elm
                MOVE    R2, R9                  ; R9: "S1", existing elm
                ASUB    R7, 1                   ; compare: S0 < S1?
                CMP     0, R10                  ; R10 is neg. if S0 < S1
                RBRA    _SLLSI_INSERT, V        ; yes: insert new elm here
                MOVE    R2, R3                  ; go to next element
                ADD     SLL$NEXT, R3
                MOVE    @R3, R3
                RBRA    _SLLSI_EOL, Z           ; end of list reached?
                MOVE    R3, R2                  ; no: proceed to next element
                RBRA    _SLLSI_LOOP, 1

                ; end of list reached: insert new element there and return
                ; original head
_SLLSI_EOL      MOVE    R2, R3                  ; R3: remember R2 for PREV
                ADD     SLL$NEXT, R2            ; store address of new elm..
                MOVE    R1, @R2                 ; ..as NEXT elm of R2
                MOVE    R1, R4                  ; store address of old elm..
                ADD     SLL$PREV, R4            ; as PREV elm of R1
                MOVE    R3, @R4
                MOVE    R1, R4                  ; NEXT pointer is null..
                ADD     SLL$NEXT, R4            ; ..because there is no NEXT
                MOVE    0, @R4
                MOVE    R0, R8                  ; return head
                RBRA    _SLLSI_RET, 1

                ; insert the new element before the current element and
                ; check if it is now the new head
_SLLSI_INSERT   MOVE    R2, R3                  ; add new elm as PREV of old
                ADD     SLL$PREV, R3
                MOVE    @R3, R4                 ; remember old PREV
                MOVE    R1, @R3
                MOVE    R1, R3                  ; add old elm as NEXT of new
                ADD     SLL$NEXT, R3
                MOVE    R2, @R3
                MOVE    R1, R3                  ; use old PREV as new PREV..
                ADD     SLL$PREV, R3            ; ..of new elm
                MOVE    R4, @R3
                MOVE    R4, R3                  ; use new elm as NEXT of old..
                ADD     SLL$NEXT, R3            ; ..PREV
                MOVE    R1, @R3

                CMP     R2, R0                  ; was the old elm the head?
                RBRA    _SLLSI_NEWHEAD, Z
                MOVE    R0, R8                  ; no: return the old head
                RBRA    _SLLSI_RET, 1
_SLLSI_NEWHEAD  MOVE    R1, R8                  ; yes: return the new head

_SLLSI_RET      DECRB
                MOVE    R0, R9
                MOVE    R1, R10
                DECRB
                RET
