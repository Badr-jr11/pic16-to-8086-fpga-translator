;------------------------------------------------------------------
; add_pic.asm  -  PIC16F887 test program for MPLAB (MPASM)
; Addition instructions: ADDLW and ADDWF
; The hex codes on the right are the 14-bit machine codes.
; The four addition codes are sent to the FPGA converter
; (2 bytes each, high byte first).
;------------------------------------------------------------------
        LIST    P=16F887
        #include <p16f887.inc>

        ORG     0x0000

START   CLRW                    ; W = 00h                  code 0103
        CLRF    0x20            ; f(20h) = 00h             code 01A0
        ADDLW   0x25            ; W = W + 25h = 25h        code 3E25
        ADDWF   0x20, F         ; f(20h) = f + W = 25h     code 07A0
        ADDWF   0x20, W         ; W = W + f(20h) = 4Ah     code 0720
        ADDLW   0xC0            ; W = W + C0h = 0Ah, C = 1 code 3EC0
        GOTO    $               ; stop                     code 2806

        END
