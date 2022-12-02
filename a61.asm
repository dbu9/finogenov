; A61.ASM 

.386P

; descriptor is 4 words or 8 bytes
descr   struc
limit   dw 0
base_l  dw 0
base_m  db 0
attr_1  db 0
attr_2  db 0
base_h  db 0
descr   ends

data    segment use16

; data segment starts with global descriptor table
gdt_null descr <0,0,0,0,0,0>                    ; offset 0
gdt_data descr <data_size-1,0,0,92h,0,0>        ; offset 8
gdt_code descr <code_size-1,0,0,98h,0,0>        ; offset 16
gdt_stack descr <255,0,0,92h,0,0>               ; offset 24
gdt_screen descr <4095, 8000h, 0bh, 92h, 0,0>   ; offset 32
gdt_size = $-gdt_null

; pseudo descriptor is required for lgdt command
pdescr  dq 0
; saving real mode stack pointer
real_sp dw 0
; symbol for printing in protected mode
sym     db 1
attr    db 1eh
; message to display when returned to real mode
mes     db 27,'[31;42m Returned to real mode! ',27,'[0m$';
data_size = $-gdt_null
data    ends

text    segment 'code' use16
        assume cs:text, ds:data
main    proc

        ; initing gdt_data
        mov ax, data
        mov ds, ax
        mov dl, 0
        shld dx, ax, 4
        shl ax, 4
        ; now dl:ax keeps 32 bit address of ds
        mov bx, offset gdt_data
        mov [bx].base_l, ax
        mov [bx].base_m, dl
        ; gdt_data inited

        ; initing gdt_code
        mov ax, cs
        mov dl, 0
        shld dx, ax, 4
        shl ax, 4
        mov bx, offset gdt_code
        mov [bx].base_l, ax
        mov [bx].base_m, dl
        ; gdt_code inited

        ; initing gdt_stack
        mov ax, ss
        mov dl, 0
        shld dx, ax, 4
        shl ax, 4
        mov bx, offset gdt_stack
        mov [bx].base_l, ax
        mov [bx].base_m, dl
        ; gdt_stack inited

        ; initing pseudo descritor memory field 
        mov bx, offset gdt_data
        mov ax, [bx].base_l
        mov word ptr pdescr+2, ax
        mov dl, [bx].base_m
        mov byte ptr pdescr+4, dl
        mov word ptr pdescr, gdt_size-1

        ; loading gdtr from pseudo descriptor
        lgdt pdescr

        ; RAM at [40h:67h] defines where CPU starts execution if 0Fh byte of CMOS has value 0Ah.
        mov ax, 40h
        mov es, ax
        mov word ptr es:[67h], offset return
        mov es:[69h], cs

        ; disable all maskable interrupts: we are not ready to process interupts in protected mode
        cli

        ; disable non-maskable interrupts by setting highest bit 1 (8) and select byte 0Fh
        mov al, 8fh
        out 70h, al
        jmp $+2
        
        ; write 0Ah to selected port 0Fh
        mov al, 0Ah
        out 71h, al

        ; bit 0 of MSW (machine state word) is set to 1 to switch to PM
        smsw ax
        or ax, 1
        lmsw ax

        ; switched to PM; segments of RM are invalid right now; 
        ; however, shadow register of CS is set valid even in RM, so CPU can continue to work;
        ; the following command sets CS:IP to valid PM values
        db 0eah
        dw offset continue
        dw 16

continue:
        mov ax, 8  ;index in GDT (descriptor selector)
        mov ds, ax

        mov ax, 24 ;index in GDT
        mov ss, ax

        mov ax, 32
        mov es, ax

        mov bx, 800
        mov cx, 300
        mov ax, word ptr sym

        ; doing some printing in PM
screen: mov es:[bx], ax
        add bx, 2
        inc ax
        loop screen

        ; return to real mode
        mov real_sp, sp
        ; Sending FEh to kbd controller initiates CPU reset
        ; control is transfered to BIOS which checks Fh byte, sees value Ah and 
        ; transfer code to address which is taken from [40h:67h]
        mov al, 0feh
        out 64h, al
        hlt

        ; now in real mode again
        ; BIOS leaves its own values of DS and SS:SP, so we need to restore them
return: mov ax, data
        mov ds, ax
        mov sp, real_sp
        mov ax, stk
        mov ss, ax

        sti
        mov al, 0
        out 70h, al


        mov ah, 9
        mov dx, offset mes
        int 21h
        mov ax, 4c00h
        int 21h

main    endp
code_size = $-main
text    ends

stk     segment stack 'stack' use16
        db 256 dup(0)
stk     ends

        end main
