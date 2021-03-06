; RUN: llc < %s -asm-verbose=false -O2 | FileCheck %s
; RUN: llc < %s -asm-verbose=false -O2 --filetype=obj | obj2yaml | FileCheck --check-prefix=YAML %s

; This tests pointer features that may codegen differently in wasm64.

target datalayout = "e-m:e-p:64:64-i64:64-n32:64-S128"
target triple = "wasm64-unknown-unknown"

define void @bar(i32 %n) {
entry:
  ret void
}

define void @foo(void (i32)* %fp) {
entry:
  call void %fp(i32 1)
  ret void
}

define void @test() {
entry:
  call void @foo(void (i32)* @bar)
  store void (i32)* @bar, void (i32)** @fptr
  ret void
}

@fptr = global void (i32)* @bar

; For simplicity (and compatibility with UB C/C++ code) we keep all types
; of pointers the same size, so function pointers (which are 32-bit indices
; in Wasm) are represented as 64-bit until called.

; CHECK:      .functype foo (i64) -> ()
; CHECK-NEXT: i32.const 1
; CHECK-NEXT: local.get 0
; CHECK-NEXT: i32.wrap_i64
; CHECK-NEXT: call_indirect (i32) -> ()

; CHECK:      .functype test () -> ()
; CHECK-NEXT: i64.const bar
; CHECK-NEXT: call foo


; Check we're emitting a 64-bit reloc for `i64.const bar` and the global.

; YAML:      Memory:
; YAML-NEXT:   Flags:   [ IS_64 ]
; YAML-NEXT:   Initial: 0x1

; YAML:      - Type:   CODE
; YAML:      - Type:   R_WASM_TABLE_INDEX_SLEB64
; YAML-NEXT:   Index:  0
; YAML-NEXT:   Offset: 0x16

; YAML:      - Type:   DATA
; YAML:      - Type:   R_WASM_TABLE_INDEX_I64
; YAML-NEXT:   Index:  0
; YAML-NEXT:   Offset: 0x6
