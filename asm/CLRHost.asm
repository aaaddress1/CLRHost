﻿;EasyCodeName=CLRHost,1
;===================================
; CLRHost.asm
; Demonstrates how to host the CLR 
; in an x86 assembly language application.
;
; Kevin Voell
; 02-17-2021
;===================================
.Const
S_OK                        equ     0
FORMAT_MESSAGE_FROM_SYSTEM  equ     00001000h
STD_OUTPUT_HANDLE           equ     -11
STD_INPUT_HANDLE            equ     -10
RUNTIMEVERSION              equ      L"v4.0.30319"

.Data
hInst                       DQ      0                       ;handle to the module instance
hout                        DQ      0                       ;handle to console output
hin                         DQ      0                       ;handle to console input
hResult                     DD      0                       ;result of the operation
bout                        DD      0                       ;byte output
bin                         DD      0                       ;byte input
inputBuff                   DD      3 DUP 0                 ;input buffer
pMetaHost                   DD      0                       ;pointer to the ICLRMetaHost struct
retVal                      DW      0                       ;return value from CLR method invocation
pInterface                  DQ      0                       ;pointer to the ICLRInterface struct
pRuntimeInfo                DQ      0                       ;pointer to the ICLRRuntimeInfo struct
pRuntimeHost                DQ      0                       ;pointer to the ICLRRuntimeHost struct
pEnumerator                 DQ      0                       ;pointer to the ICLRXXX enumerator

errorMsg                    DB      "Error occurred",0Ah,0Dh
errorMsgLen                 DD      $-errorMsg
errBuff                     DB      512 DUP 0               ;char buffer used to hold error message from WinApi
exitMsg                     DB      "Process complete",0Ah,0Dh
exitMsgLen                  DD      $-exitMsg

CLSID_CLRMetaHost           GUID    <9280188dh, 0e8eh, 4867h, <0b3h, 0ch, 07fh, 0a8h, 38h, 84h, 0e8h, 0deh>>
IID_ICLRMetaHost            GUID    <0D332DB9Eh, 0B9B3h, 4125h, <82h, 07h, 0A1h, 48h, 84h, 0F5h, 32h, 16h>>
IID_ICLRRuntimeInfo         GUID    <0BD39D1D2h, 0BA2Fh, 486ah, <89h, 0B0h, 0B4h, 0B0h, 0CBh, 46h, 68h, 91h>>
CLSID_CLRRuntimeHost        GUID    <90F1A06Eh, 7712h, 4762h, <86h, 0B5h, 7Ah, 5Eh, 0BAh, 06Bh, 0DBh, 02h>>
IID_ICLRRuntimeHost         GUID    <90F1A06Ch, 7712h, 4762h, <86h, 0B5h, 7Ah, 5Eh, 0BAh, 6Bh, 0DBh, 02h>>

.Code
start:
    Invoke GetModuleHandleA, 0
    Mov [hInst], Rax
    
    arg STD_OUTPUT_HANDLE   
    invoke GetStdHandle    
    mov [hout],eax         
    
    arg STD_INPUT_HANDLE
    invoke GetStdHandle
    mov [hin],eax
    
    Invoke Main

    invoke WriteFile,[hout],addr exitMsg,[exitMsgLen], addr bout,0
    
    invoke CloseHandle, [hout]
    invoke CloseHandle, [hInst]

    Invoke ExitProcess, 0



Main Frame    
    ;===================================
    ;Create the CLR Instance
    ;===================================
    lea r8,[pInterface]                          
    lea rdx,[IID_ICLRMetaHost]
    lea rcx,[CLSID_CLRMetaHost]
    invoke CLRCreateInstance                             ;Create the CLR instance
    cmp RAX,S_OK
    jne >displayError
    
    ;===================================
    ;Get the runtime
    ;===================================
    mov RAX, [pInterface]
    mov RAX, [RAX]
    mov RSI, ICLRMetaHostVtable.GetRuntime
    invoke [RAX+RSI],[pInterface], RUNTIMEVERSION, addr IID_ICLRRuntimeInfo, addr pRuntimeInfo 
    cmp RAX,S_OK
    jne >displayError
    
    ;===================================
    ;Get the interface
    ;===================================
    mov RAX, [pRuntimeInfo]
    mov RAX, [RAX]
    mov RSI, ICLRRuntimeInfo.GetInterface
    invoke [RAX+RSI],[pRuntimeInfo],addr CLSID_CLRRuntimeHost,addr IID_ICLRRuntimeHost,addr pRuntimeHost
    cmp RAX,S_OK
    jne >displayError
    
    ;===================================
    ;Start the runtime
    ;===================================
    mov RAX,[pRuntimeHost]
    mov RAX,[RAX]
    mov RSI,ICLRRuntimeHost.Start
    invoke [RAX+18h],[pRuntimeHost]
    cmp RAX,S_OK
    jne >displayError
    
    ;===================================
    ;Call .NET assembly
    ;===================================
    mov RAX, [pRuntimeHost]
    mov RAX, [RAX]
    mov RSI, ICLRRuntimeHost.ExecuteInDefaultAppDomain
    invoke [RAX+RSI], \
        [pRuntimeHost], \   
        L"HostedApp.exe", \                             ;.NET assembly name
        L"HostedApp.Program", \                         ;namespace containing method to invoke
        L"Test", \                                      ;name of method to invoke
        L"Hello World!", \                              ;parameter to method
        addr retVal                                     ;pointer to return value
    cmp RAX,S_OK
    jne >displayError
    
    jmp >done
    
displayError:
    invoke FormatMessageA,FORMAT_MESSAGE_FROM_SYSTEM,0,RAX,0,addr errBuff,512,0
    invoke WriteFile,[hout],addr errorMsg,[errorMsgLen], addr bout,0
    ;invoke WriteFile,[hout],RAX,8, addr bout,0
    invoke WriteFile,[hout],addr errBuff,sizeof errBuff, addr bout,0
    
done:
    ret

EndF
