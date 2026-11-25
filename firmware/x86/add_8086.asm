; ADD_8086.ASM - Intel 8086 version of the PIC16F887 program (for TASM)
; Build in DOSBox:   tasm /l add_8086.asm
;                    tlink add_8086.obj
; The file ADD_8086.LST shows the machine code of every instruction.
; Debug:             td add_8086.exe      (F8 = one step)

.model small
.stack 100h

.data
mem     db 40h dup (0)          ; memory 0000h..003Fh, PIC register 20h = [0020h]

.code
start:
        mov ax, @data
        mov ds, ax

        mov al, 0                       ; PIC: CLRW             B0 00
        mov byte ptr ds:[0020h], 0      ; PIC: CLRF  0x20       C6 06 20 00 00
        add al, 25h                     ; PIC: ADDLW 0x25       04 25         AL = 25
        add byte ptr ds:[0020h], al     ; PIC: ADDWF 0x20,F     00 06 20 00   [0020] = 25
        add al, byte ptr ds:[0020h]     ; PIC: ADDWF 0x20,W     02 06 20 00   AL = 4A
        add al, 0C0h                    ; PIC: ADDLW 0xC0       04 C0         AL = 0A, CF = 1

        mov ax, 4C00h                   ; return to DOS
        int 21h
end start
